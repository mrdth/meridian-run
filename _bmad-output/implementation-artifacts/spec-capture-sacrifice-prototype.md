---
title: 'Capture/Sacrifice Loop — Playtest Prototype (SUPERSEDED)'
type: 'feature'
created: '2026-06-27'
status: 'done'
superseded_by: '{project-root}/_bmad-output/planning-artifacts/prototype-1-design-snapshot.md'
baseline_commit: 'NO_VCS'
context:
  - '{project-root}/_bmad-output/planning-artifacts/research/domain-roguelite-arcade-base-research-2026-06-27.md'
---

> **⚠️ SUPERSEDED 2026-06-27** — This spec describes the v0 capture-enemies design. Playtest revealed the loop felt off-theme and several effects broke the 1-axis fantasy. The design pivoted to the Galaga-classic rescue model. **Current design of record: [`prototype-1-design-snapshot.md`](../planning-artifacts/prototype-1-design-snapshot.md).** This file is retained for history only — do not implement from it.

---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Research recommends Galaga as the base for a roguelite, with **voluntary sacrifice for future power** as the core design verb. We have no proof yet that capture→sacrifice actually feels fun in motion — only a hypothesis.

**Approach:** Build the smallest possible browser-playable vertical slice: a Galaga-style 1-axis ship, three capturable enemy types with distinct sacrifice effects, and the capture→store→sacrifice loop running end-to-end. Primitive shapes, no assets, no meta-progression — pure mechanic validation.

## Boundaries & Constraints

**Always:**
- Vanilla HTML5 Canvas + vanilla JS. No build tools, no npm, no frameworks. Open `index.html` in a browser and it runs.
- Single-axis player movement (left/right only, Galaga constraint). Ship locked to bottom of screen. The Up arrow does NOT move the ship — it triggers the tractor pulse.
- One capture slot — player can hold exactly zero or one captured ally at a time.
- Tractor pulse (Up arrow) is a **commitment action**: during its ~0.4s active window the player **cannot fire bullets**, exposing them to other enemies. This vulnerability window is the core risk/reward of capture.
- Tractor pulse has a brief cooldown (~1s) after the active window ends.
- Sacrifice effects must be visually distinct and immediately readable (different shape/color/pattern per type).
- 60 FPS target; use `requestAnimationFrame` with delta time.
- All gameplay state lives in one JS file for prototype simplicity.

**Ask First:**
- Any addition of a fourth capture/sacrifice type.
- Any addition of meta-progression, upgrade menus, or between-run state.
- Any external asset (sprites, audio, fonts) — prototype stays shape-only.

**Never:**
- No twin-stick, no free 2D movement. The 1-axis constraint is the whole point.
- No procedural enemy patterns — fixed spawn scripts are fine; algorithmic generation is out of scope.
- No persistent storage (no localStorage, no save state). Refresh = reset.
- No audio (silent prototype — audio polish is a later decision).
- No mobile/touch controls — keyboard only.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Player moves left/right | Left/right arrow keys | Ship moves along bottom axis, clamped to screen bounds | N/A |
| Player shoots | Space held | Continuous upward bullets with cooldown | N/A |
| Enemy reduced to ≤30% HP | Bullet hits capturable enemy | Enemy enters "stunned" state: flashes, stops shooting, 1.5s capture window opens | If HP reaches 0 before capture → enemy dies normally |
| Player triggers tractor pulse | Up arrow pressed | Vertical column (~ship width) extends above ship for ~0.4s; player cannot fire bullets during this window | If pulse on cooldown → no-op, brief visual "cooldown" feedback |
| Tractor pulse catches a stunned enemy | Stunned enemy overlaps the pulse column during active window | Enemy is yanked down to ship over ~0.2s, then stored as captured ally; slot now full | If no stunned enemy in column → pulse completes with no capture; cooldown still applies |
| Tractor pulse hits a non-stunned enemy | Non-stunned enemy overlaps pulse column | No effect — only stunned enemies are capturable | N/A |
| Player attempts capture with full slot | Pulse column overlaps stunned enemy while slot full | No capture; enemy remains stunned; pulse still locks firing | Brief visual "slot full" feedback on HUD |
| Player sacrifices captured ally | X key pressed | Stored ally consumed; corresponding sacrifice effect triggers; slot empty | If slot empty → no-op, brief visual "empty" feedback |
| Player takes damage | Enemy bullet or body hits player ship | Lose 1 HP; brief invuln frames (1s); if HP=0 → game over | During invuln frames, no further damage |
| Grunt sacrifice effect | Grunt ally sacrificed | 8-way radial bullet burst from player position | N/A |
| Shielder sacrifice effect | Shielder ally sacrificed | 3-second player invulnerability + reflect enemy bullets that hit ship | N/A |
| Bomber sacrifice effect | Bomber ally sacrificed | 50 damage applied to every enemy currently on screen | N/A |
| Wave cleared | All enemies in current wave dead | 2-second breather; next wave spawns with more enemies | N/A |
| Game over | Player HP reaches 0 | Game-over overlay with final score; R key restarts | N/A |

</frozen-after-approval>

## Code Map

- `prototype/index.html` -- Canvas element, score/HUD overlay, game-over overlay, `<script>` tag loading `game.js`. No bundler.
- `prototype/game.js` -- All game logic in one file: game loop, state, player, enemies, bullets, capture/sacrifice system, rendering, input, waves.

## Tasks & Acceptance

**Execution:**
- [x] `prototype/index.html` -- Create minimal HTML shell: full-viewport canvas (800×600 or responsive), HUD area showing HP + captured-ally indicator + score, game-over overlay with restart prompt, script tag loading `game.js`.
- [x] `prototype/game.js` -- Implement game loop (`requestAnimationFrame` + delta time), input handler (Left/Right arrows, Space to fire, Up arrow for tractor pulse, X to sacrifice, R to restart), and shared state object.
- [x] `prototype/game.js` -- Implement `Player`: horizontal-only movement clamped to screen, shooting with cooldown, 3 HP, 1-second invuln frames after hit, draw as triangle primitive.
- [x] `prototype/game.js` -- Implement `Enemy` with three variants (Grunt/Shielder/Bomber): distinct shape + color per variant, HP, simple movement pattern, downward shooting, "stunned" state at ≤30% HP with flashing + capture window.
- [x] `prototype/game.js` -- Implement `Bullet` (player + enemy variants) with collision detection (AABB or circle).
- [x] `prototype/game.js` -- Implement tractor pulse system: Up arrow activates a ~0.4s vertical column above the ship; during this window, **player firing is disabled**; if a stunned enemy intersects the column, it is yanked down to the ship and stored in the capture slot (max 1). Apply ~1s cooldown after the pulse window ends. Visual: a beam/glow extends upward from the ship while active.
- [x] `prototype/game.js` -- Implement capture storage and sacrifice dispatch: captured ally stored as variant-tagged object; X key consumes it and dispatches to the matching effect handler.
- [x] `prototype/game.js` -- Implement three sacrifice effects: Grunt = 8-way radial bullet burst; Shielder = 3s invuln + bullet reflect; Bomber = 50 damage to all on-screen enemies. Each effect must read clearly differently on screen.
- [x] `prototype/game.js` -- Implement wave spawning: scripted waves with increasing enemy counts; 2-second breather between waves; endless escalation.
- [x] `prototype/game.js` -- Implement HUD: HP pips, captured-ally indicator (shows variant type + color when slot is full), score, current wave number.
- [x] `prototype/game.js` -- Implement game-over flow: overlay with final score + wave; R key restarts by resetting all state.

**Acceptance Criteria:**
- Given the prototype loaded in a modern browser, when the player presses any movement key, then the ship responds with no perceptible input lag.
- Given a capturable enemy at full HP, when the player shoots it down to 50% HP, then it does NOT enter stunned state yet — capture is only possible at ≤30%.
- Given an enemy in stunned state and the player triggers a tractor pulse, when the pulse column overlaps the stunned enemy during its ~0.4s active window, then the enemy is yanked to the ship and stored in the capture slot.
- Given an active tractor pulse, when the player holds Space during the pulse window, then NO bullets fire — firing is locked during the pulse.
- Given a tractor pulse on cooldown, when the player presses Up, then no pulse fires (brief HUD feedback).
- Given a full capture slot, when a tractor pulse overlaps a stunned enemy, then no capture occurs — slot must be emptied first.
- Given a full capture slot, when the player presses X, then the corresponding sacrifice effect triggers immediately and the slot becomes empty.
- Given the player has sacrificed a Shielder, when an enemy bullet hits the player during the 3-second window, then the player takes no damage and the bullet is reflected.
- Given three consecutive playtests, when the player attempts to differentiate the three sacrifice effects by sight alone, then each effect must be visually distinguishable (no two effects look the same).
- Given game over, when the player presses R, then a fresh game state begins within one frame.

## Design Notes

**Why the "≤30% HP → stunned → tractor pulse to capture" rule:** This produces the meaningful decision the loop is testing. The player must choose between:
- *Kill the enemy outright* — safer, no benefit, immediate score
- *Weaken then tractor-pulse to capture* — risky (pulse locks firing for ~0.4s + adds cooldown), but yields a sacrifice charge

That trade-off is the entire point of the prototype. If players don't engage with it voluntarily, the design hypothesis fails and we know early.

**Why the tractor pulse (not touch-capture):** Galaga's 1-axis movement makes "fly into the enemy" impossible — the ship can't reach enemies above it. The tractor pulse preserves the constraint while adding three skill dimensions:
1. *Positioning* — must be horizontally aligned with the stunned enemy
2. *Timing* — pulse too early, enemy isn't stunned; too late, enemy recovers from stun (1.5s window)
3. *Vulnerability* — the firing lockout during the pulse means other enemies can hit you while you commit to a capture

The firing lockout is the critical danger multiplier. Without it, capture is free; with it, every capture is a calculated risk.

**Why one capture slot:** Forces commitment. The player can't hoard all three types — they must sacrifice to make room. This produces the "when do I cash in?" tension that roguelites live on.

**Sacrifice effect visual differentiation (mandatory):**
- Grunt burst → 8 small bullets radiating outward in cardinal+diagonal directions, warm orange.
- Shielder shield → translucent cyan ring around player ship, pulses for 3 seconds.
- Bomber detonation → full-screen white flash + every enemy flashes red as it takes damage.

If two effects look the same to a first-time player, the prototype has failed its purpose.

**Why no audio:** Audio polish creates false-positive "fun" readings during mechanic validation. Stay silent so the *decision-making* is what we're testing.

## Verification

**Commands:**
- `node --check prototype/game.js` -- expected: no syntax errors (note: this only validates JS parses; full runtime test requires a browser).

**Manual checks:**
- Open `prototype/index.html` in a modern browser (Chrome/Firefox). Confirm: ship renders, moves, shoots. Spawn an enemy (waves auto-trigger after a few seconds). Confirm: enemy reaches ≤30% HP and flashes. Touch with ship. Confirm: HUD shows captured ally. Press X. Confirm: correct sacrifice effect triggers per type. Die (let enemies hit ship 3 times). Confirm: game-over overlay appears with score; R restarts.
- Play through at least 3 waves. After each sacrifice, confirm the effect matches the captured ally type (visual check).
- Hold X with empty slot: confirm a brief visual "empty slot" cue (e.g., slot flashes dim) with no other effect.

## Suggested Review Order

**Core loop & state**

- Entry point — game state shape and reset semantics (sets the stage for everything else).
  [`game.js:108`](../../prototype/game.js#L108)

- Main loop with lower-bounded dt clamp (review patch for negative-dt edge case).
  [`game.js:750`](../../prototype/game.js#L750)

**Capture/sacrifice verb (the design hypothesis under test)**

- Tractor pulse trigger — the risk/reward commitment (firing lockout, cooldown, slot-full feedback).
  [`game.js:198`](../../prototype/game.js#L198)

- Tractor pulse per-frame logic — column check, capture-on-stunned-enemy, slot gating.
  [`game.js:335`](../../prototype/game.js#L335)

- Sacrifice dispatch — three distinct effects (orange burst / violet shield / white flash).
  [`game.js:224`](../../prototype/game.js#L224)

**Combat & damage**

- damageEnemy — applies HP loss, hit-flash, stun threshold, kill transition (caller-owned iteration direction).
  [`game.js:266`](../../prototype/game.js#L266)

- Body-collision loop (iterate-backward patch to survive splice-during-iteration).
  [`game.js:478`](../../prototype/game.js#L478)

**Enemy variants & visuals**

- Variant table — HP, score, fire interval, speed, color per enemy type.
  [`game.js:35`](../../prototype/game.js#L35)

- drawEnemy — three shape primitives, stun-flicker, damage hit-flash, capture-pull animation.
  [`game.js:619`](../../prototype/game.js#L619)

- drawShieldRing — violet palette chosen to keep the three sacrifice effects visually distinct.
  [`game.js:717`](../../prototype/game.js#L717)

**Frame robustness (patches applied during review)**

- clearKeys on blur / visibilitychange / resetGame — prevents stuck-key bugs across tab-switches and restarts.
  [`game.js:98`](../../prototype/game.js#L98)

- Bomber sacrifice iterate-backward (for-of + splice was skipping every other killed enemy).
  [`game.js:244`](../../prototype/game.js#L244)
