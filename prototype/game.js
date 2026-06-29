'use strict';

// ============================================================================
// CONSTANTS
// ============================================================================

const WIDTH = 800;
const HEIGHT = 600;
const PLAYER_Y = 540;
const PLAYER_HALF_W = 16;
const PLAYER_SPEED = 340;
const PLAYER_HP = 3;
const PLAYER_INVULN = 1.0;
const PLAYER_FIRE_COOLDOWN = 0.16;
const PLAYER_BULLET_SPEED = 620;
const PLAYER_BULLET_DMG = 10;

// Sacrifice buff
const BUFF_DURATION = 10.0;
const BUFF_FIRE_COOLDOWN = 0.10;      // faster fire
const BUFF_BULLETS = 3;               // triple-shot
const BUFF_SPREAD = 0.18;             // radians between buff bullets
const BUFF_DMG_BONUS = 1.5;           // 1.5x damage per bullet

// Tractor Boss
const BOSS_HP = 60;
const BOSS_SCORE = 500;
const BOSS_COLOR = '#ffd36b';
const BOSS_HALF_W = 26;
const BOSS_TELEGRAPH = 0.7;           // warning column duration
const BOSS_CAPTURE_WINDOW = 0.4;      // active capture beam duration
const BOSS_CAPTURE_HALF_W = 32;       // column width
const BOSS_DIVE_INTERVAL_MIN = 3.5;
const BOSS_DIVE_INTERVAL_MAX = 5.5;
const BOSS_ENTER_DELAY = 4.0;         // seconds after wave start
const BOSS_DIVE_SPEED = 280;
const BOSS_FORMATION_Y = 110;

const ENEMY_BULLET_SPEED = 220;

const WAVE_BREAK = 2.0;

// Regular enemy variants (no stun, no capture)
const ENEMY_TYPES = {
  grunt:    { hp: 30, score: 100, color: '#e85d2f', fireInterval: [1.2, 2.4], speed: 60 },
  shielder: { hp: 50, score: 150, color: '#4ec1ff', fireInterval: [0.9, 1.8], speed: 50 },
  bomber:   { hp: 80, score: 300, color: '#f74c8c', fireInterval: [1.6, 2.8], speed: 80 },
};

// ============================================================================
// CANVAS & INPUT
// ============================================================================

const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');
const hudHp = document.getElementById('hp');
const hudSlot = document.getElementById('slot');
const hudWave = document.getElementById('wave');
const hudScore = document.getElementById('score');
const overlay = document.getElementById('overlay');
const finalStats = document.getElementById('final');

const keys = Object.create(null);
window.addEventListener('keydown', (e) => {
  keys[e.code] = true;
  if (['ArrowLeft', 'ArrowRight', 'Space'].includes(e.code)) {
    e.preventDefault();
  }
  if (e.code === 'KeyR' && game.state === 'gameover') {
    resetGame();
  }
  if (e.code === 'KeyX' && game.state === 'playing') {
    trySacrifice();
  }
});
window.addEventListener('keyup', (e) => { keys[e.code] = false; });
window.addEventListener('blur', clearKeys);
document.addEventListener('visibilitychange', () => { if (document.hidden) clearKeys(); });

function clearKeys() {
  for (const k in keys) delete keys[k];
}

// ============================================================================
// GAME STATE
// ============================================================================

let game;

function resetGame() {
  clearKeys();
  game = {
    state: 'playing',
    time: 0,
    player: {
      x: WIDTH / 2,
      hp: PLAYER_HP,
      invuln: 0,
      lastFire: -Infinity,
      buff: { active: false, remaining: 0 },
    },
    dockedShip: null,                  // null | { alive: true }
    capturedOnBoss: false,             // is a player ship currently hostage on the boss?
    playerBullets: [],
    enemyBullets: [],
    enemies: [],
    boss: null,                        // null | boss object
    fx: [],
    wave: 1,
    score: 0,
    spawnQueue: [],                   // regular enemy spawn queue
    bossSpawnAt: BOSS_ENTER_DELAY,    // boss timer for this wave
    bossSpawned: false,               // only one boss per wave
    waveBreak: 0,
    bomberFlash: 0,                   // (unused but kept for compatibility)
  };
  queueWave(1);
}

// ============================================================================
// WAVES & SPAWNING
// ============================================================================

function queueWave(n) {
  const count = Math.min(4 + n, 12);
  const queue = [];
  for (let i = 0; i < count; i++) {
    let variant;
    if (n <= 1) variant = 'grunt';
    else if (n === 2) variant = i % 3 === 0 ? 'shielder' : 'grunt';
    else if (n <= 4) variant = i % 4 === 0 ? 'bomber' : (i % 4 === 1 ? 'shielder' : 'grunt');
    else variant = ['grunt', 'shielder', 'bomber'][i % 3];
    queue.push({
      variant,
      delay: i * 0.45,
      spawnX: 80 + (i * 137) % (WIDTH - 160),
    });
  }
  game.spawnQueue = queue;
  game.bossSpawnAt = BOSS_ENTER_DELAY;
  game.bossSpawned = false;
  game.boss = null;
  game.capturedOnBoss = false;
}

function spawnEnemy(variant, x) {
  const def = ENEMY_TYPES[variant];
  game.enemies.push({
    variant,
    x,
    y: -30,
    hp: def.hp,
    maxHp: def.hp,
    fireTimer: def.fireInterval[0] + Math.random() * (def.fireInterval[1] - def.fireInterval[0]),
    speed: def.speed,
    color: def.color,
    score: def.score,
    swayPhase: Math.random() * Math.PI * 2,
    entering: true,
    hitFlash: 0,
  });
}

function spawnBoss() {
  game.boss = {
    x: WIDTH / 2,
    y: -40,
    hp: BOSS_HP,
    maxHp: BOSS_HP,
    state: 'entering',                // entering → formation → telegraph → capture → dive → return
    stateTimer: 0,
    nextDiveAt: BOSS_DIVE_INTERVAL_MIN + Math.random() * (BOSS_DIVE_INTERVAL_MAX - BOSS_DIVE_INTERVAL_MIN),
    telegraphX: WIDTH / 2,            // x position of the telegraphed column
    diveStartX: 0,
    diveStartY: 0,
    diveTargetX: 0,
    capturedShip: false,              // does THIS boss hold a hostage?
    hitFlash: 0,
  };
}

// ============================================================================
// PLAYER ACTIONS
// ============================================================================

function tryFire() {
  const cd = game.player.buff.active ? BUFF_FIRE_COOLDOWN : PLAYER_FIRE_COOLDOWN;
  if (game.time - game.player.lastFire < cd) return;
  game.player.lastFire = game.time;

  const dmg = PLAYER_BULLET_DMG * (game.player.buff.active ? BUFF_DMG_BONUS : 1);

  if (game.player.buff.active) {
    // triple-shot spread
    for (let i = 0; i < BUFF_BULLETS; i++) {
      const ang = (i - (BUFF_BULLETS - 1) / 2) * BUFF_SPREAD;
      game.playerBullets.push({
        x: game.player.x,
        y: PLAYER_Y - 16,
        vx: Math.sin(ang) * PLAYER_BULLET_SPEED,
        vy: -Math.cos(ang) * PLAYER_BULLET_SPEED,
        dmg,
      });
    }
  } else {
    game.playerBullets.push({
      x: game.player.x,
      y: PLAYER_Y - 16,
      vy: -PLAYER_BULLET_SPEED,
      dmg,
    });
  }

  // docked ship fires alongside (mirrors player)
  if (game.dockedShip && game.dockedShip.alive) {
    game.playerBullets.push({
      x: game.player.x + 28,
      y: PLAYER_Y - 8,
      vy: -PLAYER_BULLET_SPEED,
      dmg: PLAYER_BULLET_DMG,
    });
  }
}

function trySacrifice() {
  if (!game.dockedShip || !game.dockedShip.alive) {
    flashHud('empty-flash');
    return;
  }
  game.dockedShip = null;
  game.player.buff.active = true;
  game.player.buff.remaining = BUFF_DURATION;
  game.fx.push({ kind: 'ring', x: game.player.x, y: PLAYER_Y, r: 8, maxR: 80, life: 0.4, color: '#ffd36b' });
}

function flashHud(cls) {
  hudSlot.classList.remove('empty-flash', 'cooldown-flash', 'slot-full-flash');
  void hudSlot.offsetWidth;
  hudSlot.classList.add(cls);
}

// ============================================================================
// DAMAGE
// ============================================================================

function damageEnemy(e, amount) {
  e.hp -= amount;
  if (e.hp <= 0) {
    killEnemy(e, false);
    return;
  }
  e.hitFlash = 0.15;
}

function killEnemy(e) {
  const idx = game.enemies.indexOf(e);
  if (idx >= 0) game.enemies.splice(idx, 1);
  game.score += e.score;
  game.fx.push({ kind: 'pop', x: e.x, y: e.y, color: e.color, life: 0.3 });
}

function damageBoss(b, amount) {
  if (!b) return;
  b.hp -= amount;
  b.hitFlash = 0.15;
  if (b.hp <= 0) {
    onBossDeath(b);
  }
}

function onBossDeath(b) {
  // free captured ship if boss was holding one
  if (b.capturedShip) {
    game.dockedShip = { alive: true };
    game.capturedOnBoss = false;
    game.fx.push({ kind: 'ring', x: b.x, y: b.y, r: 10, maxR: 100, life: 0.5, color: '#9affc2' });
  }
  game.score += BOSS_SCORE;
  game.fx.push({ kind: 'pop', x: b.x, y: b.y, color: BOSS_COLOR, life: 0.5 });
  game.fx.push({ kind: 'ring', x: b.x, y: b.y, r: 20, maxR: 140, life: 0.6, color: BOSS_COLOR });
  game.boss = null;
}

function damagePlayer() {
  if (game.player.invuln > 0) return;
  // docked ship absorbs the first hit (fragile)
  if (game.dockedShip && game.dockedShip.alive) {
    game.dockedShip = null;
    game.fx.push({ kind: 'pop', x: game.player.x + 28, y: PLAYER_Y, color: '#9affc2', life: 0.4 });
    game.player.invuln = PLAYER_INVULN; // brief grace
    return;
  }
  game.player.hp -= 1;
  game.player.invuln = PLAYER_INVULN;
  if (game.player.hp <= 0) {
    endGame();
  }
}

function capturePlayer(b) {
  // boss captures the player's ship: lose 1 HP, mark boss as holding hostage
  if (game.player.invuln > 0) return;
  game.player.hp -= 1;
  game.player.invuln = PLAYER_INVULN;
  b.capturedShip = true;
  game.capturedOnBoss = true;
  game.fx.push({ kind: 'ring', x: game.player.x, y: PLAYER_Y, r: 8, maxR: 60, life: 0.4, color: '#ff5050' });
  if (game.player.hp <= 0) {
    endGame();
  }
}

function endGame() {
  game.state = 'gameover';
  finalStats.textContent = `WAVE ${game.wave} · SCORE ${game.score}`;
  overlay.classList.remove('hidden');
}

// ============================================================================
// UPDATE
// ============================================================================

function update(dt) {
  if (game.state !== 'playing') return;
  game.time += dt;

  updatePlayer(dt);
  updateSpawning(dt);
  updateBoss(dt);
  updateEnemies(dt);
  updateBullets(dt);
  updateFx(dt);
  checkWaveCleared(dt);
}

function updatePlayer(dt) {
  const p = game.player;
  if (p.invuln > 0) p.invuln -= dt;
  if (p.buff.active) {
    p.buff.remaining -= dt;
    if (p.buff.remaining <= 0) {
      p.buff.active = false;
    }
  }

  let dir = 0;
  if (keys['ArrowLeft']) dir -= 1;
  if (keys['ArrowRight']) dir += 1;
  p.x += dir * PLAYER_SPEED * dt;
  p.x = Math.max(PLAYER_HALF_W, Math.min(WIDTH - PLAYER_HALF_W, p.x));

  if (keys['Space']) tryFire();
}

function updateSpawning(dt) {
  const q = game.spawnQueue;
  for (let i = q.length - 1; i >= 0; i--) {
    q[i].delay -= dt;
    if (q[i].delay <= 0) {
      spawnEnemy(q[i].variant, q[i].spawnX);
      q.splice(i, 1);
    }
  }
  // boss spawn (one per wave)
  if (!game.bossSpawned) {
    game.bossSpawnAt -= dt;
    if (game.bossSpawnAt <= 0) {
      spawnBoss();
      game.bossSpawned = true;
    }
  }
}

function updateBoss(dt) {
  const b = game.boss;
  if (!b) return;

  if (b.hitFlash > 0) {
    b.hitFlash -= dt;
    if (b.hitFlash < 0) b.hitFlash = 0;
  }

  b.stateTimer += dt;

  switch (b.state) {
    case 'entering': {
      b.y += 60 * dt;
      if (b.y >= BOSS_FORMATION_Y) {
        b.y = BOSS_FORMATION_Y;
        b.state = 'formation';
        b.stateTimer = 0;
      }
      break;
    }
    case 'formation': {
      // side-to-side drift
      b.x = WIDTH / 2 + Math.sin(game.time * 0.8) * 200;
      // fire occasionally
      b.fireTimer = (b.fireTimer || 1.5) - dt;
      if (b.fireTimer <= 0) {
        b.fireTimer = 1.5 + Math.random() * 1.5;
        game.enemyBullets.push({ x: b.x, y: b.y + 24, vy: ENEMY_BULLET_SPEED });
      }
      // begin telegraph when dive timer elapses
      if (b.stateTimer >= b.nextDiveAt) {
        b.state = 'telegraph';
        b.stateTimer = 0;
        // lock telegraph column to current player position (skill-based dodge possible)
        b.telegraphX = game.player.x;
      }
      break;
    }
    case 'telegraph': {
      b.x = WIDTH / 2 + Math.sin(game.time * 0.8) * 200;
      if (b.stateTimer >= BOSS_TELEGRAPH) {
        b.state = 'capture';
        b.stateTimer = 0;
      }
      break;
    }
    case 'capture': {
      // active capture beam — check player overlap
      if (Math.abs(game.player.x - b.telegraphX) <= BOSS_CAPTURE_HALF_W) {
        capturePlayer(b);
      }
      if (b.stateTimer >= BOSS_CAPTURE_WINDOW) {
        // transition to dive
        b.state = 'dive';
        b.stateTimer = 0;
        b.diveStartX = b.x;
        b.diveStartY = b.y;
        b.diveTargetX = Math.max(80, Math.min(WIDTH - 80, game.player.x + (Math.random() - 0.5) * 200));
      }
      break;
    }
    case 'dive': {
      // dive toward player then off bottom
      const diveDuration = 1.6;
      const t = Math.min(1, b.stateTimer / diveDuration);
      // bezier-ish: down toward player then continue off screen
      b.x = b.diveStartX + (b.diveTargetX - b.diveStartX) * t;
      b.y = b.diveStartY + (HEIGHT + 80 - b.diveStartY) * (t * t);
      // body collision during dive
      const dx = b.x - game.player.x;
      const dy = b.y - PLAYER_Y;
      if (dx * dx + dy * dy < (BOSS_HALF_W + 12) * (BOSS_HALF_W + 12)) {
        damagePlayer();
      }
      if (t >= 1) {
        b.state = 'entering';
        b.stateTimer = 0;
        b.y = -40;
        b.x = WIDTH / 2;
        b.nextDiveAt = BOSS_DIVE_INTERVAL_MIN + Math.random() * (BOSS_DIVE_INTERVAL_MAX - BOSS_DIVE_INTERVAL_MIN);
      }
      break;
    }
  }
}

function updateEnemies(dt) {
  for (let i = game.enemies.length - 1; i >= 0; i--) {
    const e = game.enemies[i];

    if (e.entering) {
      e.y += e.speed * dt;
      if (e.y >= 90 + ((e.x | 0) % 60)) e.entering = false;
    } else {
      e.swayPhase += dt * 1.2;
      e.x += Math.sin(e.swayPhase) * 30 * dt;
      e.x = Math.max(40, Math.min(WIDTH - 40, e.x));
    }

    if (e.hitFlash > 0) {
      e.hitFlash -= dt;
      if (e.hitFlash < 0) e.hitFlash = 0;
    }

    e.fireTimer -= dt;
    if (e.fireTimer <= 0 && !e.entering) {
      const def = ENEMY_TYPES[e.variant];
      e.fireTimer = def.fireInterval[0] + Math.random() * (def.fireInterval[1] - def.fireInterval[0]);
      game.enemyBullets.push({ x: e.x, y: e.y + 14, vy: ENEMY_BULLET_SPEED });
    }
  }
}

function updateBullets(dt) {
  // player bullets
  for (let i = game.playerBullets.length - 1; i >= 0; i--) {
    const b = game.playerBullets[i];
    if (b.vx) b.x += b.vx * dt;
    b.y += b.vy * dt;
    if (b.y < -20 || b.x < -20 || b.x > WIDTH + 20) {
      game.playerBullets.splice(i, 1);
      continue;
    }
    let consumed = false;
    // hit boss
    if (game.boss) {
      const dx = game.boss.x - b.x;
      const dy = game.boss.y - b.y;
      if (dx * dx + dy * dy < BOSS_HALF_W * BOSS_HALF_W) {
        damageBoss(game.boss, b.dmg);
        consumed = true;
      }
    }
    // hit regular enemies
    if (!consumed) {
      for (const e of game.enemies) {
        const dx = e.x - b.x;
        const dy = e.y - b.y;
        if (dx * dx + dy * dy < 22 * 22) {
          damageEnemy(e, b.dmg);
          consumed = true;
          break;
        }
      }
    }
    if (consumed) game.playerBullets.splice(i, 1);
  }

  // enemy bullets
  for (let i = game.enemyBullets.length - 1; i >= 0; i--) {
    const b = game.enemyBullets[i];
    b.y += b.vy * dt;
    if (b.y > HEIGHT + 20) { game.enemyBullets.splice(i, 1); continue; }

    // hit player
    const dx = b.x - game.player.x;
    const dy = b.y - PLAYER_Y;
    if (dx * dx + dy * dy < 14 * 14) {
      game.enemyBullets.splice(i, 1);
      damagePlayer();
    }
  }

  // enemy body collision with player
  for (let i = game.enemies.length - 1; i >= 0; i--) {
    const e = game.enemies[i];
    if (e.entering) continue;
    const dx = e.x - game.player.x;
    const dy = e.y - PLAYER_Y;
    if (dx * dx + dy * dy < 26 * 26) {
      damagePlayer();
      killEnemy(e);
    }
  }
}

function updateFx(dt) {
  for (let i = game.fx.length - 1; i >= 0; i--) {
    const f = game.fx[i];
    f.life -= dt;
    if (f.kind === 'ring') {
      f.r += (f.maxR - f.r) * Math.min(1, dt * 8);
    }
    if (f.life <= 0) game.fx.splice(i, 1);
  }
}

function checkWaveCleared(dt) {
  const allClear = game.spawnQueue.length === 0
                && game.enemies.length === 0
                && game.boss === null;
  if (!allClear) return;

  if (game.waveBreak <= 0) {
    // wave just cleared — resolve life recovery
    if (game.dockedShip && game.dockedShip.alive) {
      // player kept the docked ship through wave end → regain 1 HP
      if (game.player.hp < PLAYER_HP) {
        game.player.hp += 1;
        game.fx.push({ kind: 'ring', x: game.player.x, y: PLAYER_Y, r: 8, maxR: 60, life: 0.5, color: '#9affc2' });
      }
      game.dockedShip = null;  // ship flies off after delivering the life
    }
    game.waveBreak = WAVE_BREAK;
  } else {
    game.waveBreak -= dt;
    if (game.waveBreak <= 0) {
      game.wave += 1;
      queueWave(game.wave);
    }
  }
}

// ============================================================================
// RENDER
// ============================================================================

function render() {
  ctx.fillStyle = '#06060e';
  ctx.fillRect(0, 0, WIDTH, HEIGHT);
  drawGrid();

  for (const b of game.playerBullets) drawPlayerBullet(b);
  for (const b of game.enemyBullets) drawEnemyBullet(b);

  if (game.boss) drawBoss(game.boss);
  for (const e of game.enemies) drawEnemy(e);

  for (const f of game.fx) drawFx(f);

  drawPlayer();

  updateHud();
}

function drawGrid() {
  ctx.strokeStyle = 'rgba(40, 50, 80, 0.18)';
  ctx.lineWidth = 1;
  for (let x = 0; x <= WIDTH; x += 50) {
    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, HEIGHT); ctx.stroke();
  }
  for (let y = 0; y <= HEIGHT; y += 50) {
    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(WIDTH, y); ctx.stroke();
  }
}

function drawPlayer() {
  const p = game.player;
  if (p.invuln > 0 && Math.floor(p.invuln * 16) % 2 === 0) return;

  ctx.save();
  ctx.translate(p.x, PLAYER_Y);

  // buff aura
  if (p.buff.active) {
    const a = Math.min(1, p.buff.remaining / BUFF_DURATION);
    ctx.strokeStyle = `rgba(255, 211, 107, ${0.3 + 0.2 * Math.sin(game.time * 12)})`;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(0, 0, 24 + Math.sin(game.time * 8) * 2, 0, Math.PI * 2);
    ctx.stroke();
  }

  ctx.fillStyle = '#9affc2';
  ctx.strokeStyle = '#d8ffe8';
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(0, -14);
  ctx.lineTo(-PLAYER_HALF_W, 10);
  ctx.lineTo(0, 4);
  ctx.lineTo(PLAYER_HALF_W, 10);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  ctx.fillStyle = '#ffb070';
  ctx.beginPath();
  ctx.moveTo(-4, 10);
  ctx.lineTo(0, 16 + Math.random() * 4);
  ctx.lineTo(4, 10);
  ctx.closePath();
  ctx.fill();

  ctx.restore();

  // docked ship (wingman)
  if (game.dockedShip && game.dockedShip.alive) {
    ctx.save();
    ctx.translate(p.x + 28, PLAYER_Y + 4);
    ctx.fillStyle = '#9affc2';
    ctx.strokeStyle = '#d8ffe8';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, -10);
    ctx.lineTo(-10, 8);
    ctx.lineTo(0, 3);
    ctx.lineTo(10, 8);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();
  }
}

function drawPlayerBullet(b) {
  ctx.fillStyle = '#fff5b0';
  if (b.vx) {
    ctx.beginPath();
    ctx.arc(b.x, b.y, 3.5, 0, Math.PI * 2);
    ctx.fill();
  } else {
    ctx.fillRect(b.x - 2, b.y - 8, 4, 12);
  }
}

function drawEnemyBullet(b) {
  ctx.fillStyle = '#ff7c7c';
  ctx.beginPath();
  ctx.arc(b.x, b.y, 4, 0, Math.PI * 2);
  ctx.fill();
}

function drawEnemy(e) {
  ctx.save();
  ctx.translate(e.x, e.y);

  let color = e.color;
  let stroke = '#ffffff';
  if (e.hitFlash > 0) {
    color = '#ff5050';
  }

  ctx.fillStyle = color;
  ctx.strokeStyle = stroke;
  ctx.lineWidth = 1.5;

  if (e.variant === 'grunt') {
    ctx.beginPath();
    ctx.moveTo(0, 14);
    ctx.lineTo(-12, -10);
    ctx.lineTo(12, -10);
    ctx.closePath();
    ctx.fill(); ctx.stroke();
  } else if (e.variant === 'shielder') {
    ctx.beginPath();
    for (let i = 0; i < 6; i++) {
      const a = (i / 6) * Math.PI * 2 - Math.PI / 2;
      const px = Math.cos(a) * 14;
      const py = Math.sin(a) * 14;
      if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
    }
    ctx.closePath();
    ctx.fill(); ctx.stroke();
  } else if (e.variant === 'bomber') {
    ctx.beginPath();
    ctx.moveTo(0, -14);
    ctx.lineTo(14, 0);
    ctx.lineTo(0, 14);
    ctx.lineTo(-14, 0);
    ctx.closePath();
    ctx.fill(); ctx.stroke();
  }

  if (e.hp < e.maxHp) {
    const w = 24;
    const pct = Math.max(0, e.hp / e.maxHp);
    ctx.fillStyle = 'rgba(0,0,0,0.6)';
    ctx.fillRect(-w / 2, -22, w, 3);
    ctx.fillStyle = '#9affc2';
    ctx.fillRect(-w / 2, -22, w * pct, 3);
  }

  ctx.restore();
}

function drawBoss(b) {
  // telegraph column (warning)
  if (b.state === 'telegraph' || b.state === 'capture') {
    const intensity = b.state === 'capture' ? 1 : (b.stateTimer / BOSS_TELEGRAPH);
    const alpha = (0.2 + 0.4 * intensity) * (0.6 + 0.4 * Math.sin(game.time * 20));
    ctx.fillStyle = `rgba(255, 80, 80, ${alpha})`;
    ctx.fillRect(b.telegraphX - BOSS_CAPTURE_HALF_W, 0, BOSS_CAPTURE_HALF_W * 2, HEIGHT);
    ctx.strokeStyle = `rgba(255, 200, 200, ${0.6 + 0.4 * intensity})`;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(b.telegraphX - BOSS_CAPTURE_HALF_W, 0);
    ctx.lineTo(b.telegraphX - BOSS_CAPTURE_HALF_W, HEIGHT);
    ctx.moveTo(b.telegraphX + BOSS_CAPTURE_HALF_W, 0);
    ctx.lineTo(b.telegraphX + BOSS_CAPTURE_HALF_W, HEIGHT);
    ctx.stroke();
  }

  ctx.save();
  ctx.translate(b.x, b.y);

  let color = BOSS_COLOR;
  if (b.hitFlash > 0) color = '#ffffff';

  // body — large hexagon
  ctx.fillStyle = color;
  ctx.strokeStyle = '#ffffff';
  ctx.lineWidth = 2;
  ctx.beginPath();
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2;
    const px = Math.cos(a) * BOSS_HALF_W;
    const py = Math.sin(a) * BOSS_HALF_W;
    if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
  }
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  // core
  ctx.fillStyle = '#ff5050';
  ctx.beginPath();
  ctx.arc(0, 0, 8 + Math.sin(game.time * 6) * 2, 0, Math.PI * 2);
  ctx.fill();

  // captured ship mounted on belly
  if (b.capturedShip) {
    ctx.fillStyle = '#9affc2';
    ctx.beginPath();
    ctx.moveTo(0, 18);
    ctx.lineTo(-10, 32);
    ctx.lineTo(0, 28);
    ctx.lineTo(10, 32);
    ctx.closePath();
    ctx.fill();
  }

  ctx.restore();

  // boss HP bar (top of screen)
  const barW = 200;
  const barX = (WIDTH - barW) / 2;
  const barY = 36;
  ctx.fillStyle = 'rgba(0,0,0,0.6)';
  ctx.fillRect(barX - 2, barY - 2, barW + 4, 8);
  ctx.fillStyle = BOSS_COLOR;
  ctx.fillRect(barX, barY, barW * Math.max(0, b.hp / b.maxHp), 4);
  ctx.fillStyle = '#888aa8';
  ctx.font = '10px ui-monospace';
  ctx.textAlign = 'center';
  ctx.fillText('TRACTOR BOSS', WIDTH / 2, barY - 6);
}

function drawFx(f) {
  if (f.kind === 'ring') {
    const a = Math.max(0, Math.min(1, f.life / 0.5));
    ctx.strokeStyle = f.color;
    ctx.globalAlpha = a;
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(f.x, f.y, f.r, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = 1;
  } else if (f.kind === 'pop') {
    const a = Math.max(0, Math.min(1, f.life / 0.3));
    ctx.fillStyle = f.color;
    ctx.globalAlpha = a;
    ctx.beginPath();
    ctx.arc(f.x, f.y, 6 + (1 - a) * 12, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
  }
}

// ============================================================================
// HUD
// ============================================================================

function updateHud() {
  const p = game.player;
  hudHp.textContent = 'HP ' + '●'.repeat(Math.max(0, p.hp)) + '○'.repeat(Math.max(0, PLAYER_HP - p.hp));

  let slotText, slotClass;
  if (p.buff.active) {
    slotText = `BUFF ${p.buff.remaining.toFixed(1)}s`;
    slotClass = 'full';
  } else if (game.dockedShip && game.dockedShip.alive) {
    slotText = 'RESCUED — X=SACRIFICE';
    slotClass = 'full';
  } else if (game.capturedOnBoss) {
    slotText = 'SHIP CAPTURED — KILL BOSS';
    slotClass = '';
  } else {
    slotText = 'NO ALLY';
    slotClass = '';
  }
  hudSlot.textContent = slotText;
  hudSlot.classList.toggle('full', slotClass === 'full');

  hudWave.textContent = 'WAVE ' + game.wave;
  hudScore.textContent = 'SCORE ' + game.score;
}

// ============================================================================
// MAIN LOOP
// ============================================================================

let lastTime = performance.now();
function loop(now) {
  const dt = Math.max(0, Math.min(0.05, (now - lastTime) / 1000));
  lastTime = now;
  update(dt);
  render();
  requestAnimationFrame(loop);
}

resetGame();
overlay.classList.add('hidden');
requestAnimationFrame(loop);
