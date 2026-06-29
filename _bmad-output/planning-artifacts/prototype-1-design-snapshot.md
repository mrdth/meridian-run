---
title: 'Prototype v1 Design Snapshot — Galaga Rescue Roguelite'
type: 'design-snapshot'
created: '2026-06-27'
status: 'validated'
supersedes: '../implementation-artifacts/spec-capture-sacrifice-prototype.md'
intended_use: 'Input for next planning phase (gds-brainstorm-game → gds-create-game-brief → gds-gdd)'
---

# Prototype v1 Design Snapshot

**Build date:** 2026-06-27
**Status:** Playtested and validated — core loop feels fun
**Stack:** Vanilla HTML5 Canvas + JS, two files (`prototype/index.html`, `prototype/game.js`)
**To run:** Open `prototype/index.html` in any modern browser.

---

## 1. How We Got Here — The Pivot

### v0 design (abandoned)
The original prototype (spec: `spec-capture-sacrifice-prototype.md`) tested **player captures enemies**: shoot enemies to ≤30% HP, tractor-pulse to capture, sacrifice for one of three effects (Grunt = 8-way radial burst, Shielder = shield + reflect, Bomber = 50 damage to all on-screen enemies).

### What playtest revealed
Three real issues:

1. **8-way radial burst broke the 1-axis fantasy.** Bullets traveled into space the player can't reach or aim toward. The whole point of choosing Galaga was the 1-axis constraint; effects that ignore it dilute the identity.
2. **Bomber screen-clear was overpowered.** At current enemy HP (30/50/80), a single button press wiped most waves, removing the dodge-and-position skill that is the entire gameplay loop.
3. **The loop felt too easy and off-theme.** Capturing enemies made the player the aggressor, discarding the dramatic rescue moment that makes Galaga memorable.

### The pivot
Return to the classic Galaga fantasy: **the player gets captured, then rescues**. The risk/reward shifts from "should I capture this enemy?" to two layered decisions:

- **Rescue risk** — do I expose myself to grab the captured ship?
- **Sacrifice vs. keep** — cash in the rescued ship for power now, or hold it to regain the lost life at wave end?

The "regain lost life by surviving the wave with rescued ship" rule is the **central roguelite hook** — it converts permadeath from a binary loss into a recoverable gamble. That single mechanic justifies the game's existence.

---

## 2. Core Loop

```
WAVE START
  ├─ regular enemies spawn over ~2-3s
  ├─ ~4s in: Tractor Boss enters
  │
  ├─ Boss formation → telegraphs red column (locks to player's current x)
  │   ├─ dodge sideways → no capture
  │   └─ caught in column during 0.4s active window → lose 1 HP, ship stored on boss
  │
  ├─ Boss dive-bombs player
  │   ├─ dodge → boss returns to formation, repeats
  │   └─ shoot boss down during dive → freed ship docks as wingman
  │
  ├─ With docked ship:
  │   ├─ X = sacrifice → 10s buff (triple-shot, 1.5× dmg, faster fire)
  │   └─ keep through wave end → regain 1 HP, ship flies off
  │
WAVE CLEAR (all enemies + boss dead) → 2s break → next wave
```

---

## 3. Mechanics — Final State

### Tractor Boss
- Spawns once per wave, ~4 seconds after wave start
- HP: 60 (top-center HP bar appears when alive)
- Color: gold (#ffd36b), large hexagon body with red pulsing core
- State machine: `entering → formation → telegraph → capture → dive → loop`

| State | Duration | Behavior |
|---|---|---|
| entering | ~1s | descends from top to formation row (y=110) |
| formation | 3.5–5.5s (random) | side-to-side drift, periodic downward bullets |
| telegraph | 0.7s | red column locks to player's current x position (gives dodge window) |
| capture | 0.4s | active beam — player in column = captured (-1 HP, hostage stored on boss) |
| dive | 1.6s | bezier toward player x then off-screen; body collision damages player; returns to entering |

**Skill-based dodge:** the telegraph locks the column to the player's position at telegraph-start. Player has 0.7s to slide out of the column.

### Capture (player-loses-ship event)
- Player HP −1
- Brief 1s invulnerability
- Boss's `capturedShip` flag set — small green ship rendered under the boss belly
- HUD reads `SHIP CAPTURED — KILL BOSS`

### Rescue
- Triggered automatically when the boss dies while holding a hostage
- Freed ship docks as the player's wingman
- Rescued ship appears at `player.x + 28`, `PLAYER_Y + 4`, mirroring player fire

### Docked ship (wingman)
- Fragile — absorbs the next player-hit, then is gone (effectively a 1-hit shield + extra damage during its lifetime)
- Adds a parallel bullet stream to player fire (extra bullet at +28 x offset, straight up)
- State tracked at `game.dockedShip = { alive: true }` or `null`

### Sacrifice (X key, requires docked ship)
- Consumes the docked ship
- Applies a 10-second buff:
  - **Triple-shot spread** — 3 bullets per fire, ±0.18 rad spread
  - **1.5× damage per bullet**
  - **Faster fire cooldown** — 0.10s vs. base 0.16s
- Visual: gold aura ring around player ship, pulses for buff duration
- HUD reads `BUFF 8.3s` (countdown)

### Life recovery (the roguelite hook)
- At wave-clear: if the docked ship is still alive (not sacrificed, not destroyed) → player regains 1 HP (up to max), then docked ship flies off
- The player's central strategic decision: cash in for power now, or hold for the life later

### Player
- 3 HP
- Horizontal-only movement, clamped to screen edges
- 1-second invulnerability after any hit
- Fire cooldown: 0.16s (0.10s during buff)
- Standard bullet: 10 dmg, straight up, 620 px/s

### Regular enemies (no capture, no stun)
Same three variants as before, but unstunnable and uncapturable — pure cannon fodder + fire threats.

| Variant | HP | Score | Color | Shape | Fire interval | Speed |
|---|---|---|---|---|---|---|
| Grunt | 30 | 100 | #e85d2f | downward triangle | 1.2–2.4s | 60 |
| Shielder | 50 | 150 | #4ec1ff | hexagon | 0.9–1.8s | 50 |
| Bomber | 80 | 300 | #f74c8c | diamond | 1.6–2.8s | 80 |

### Wave composition
- Wave N: 4 + N regular enemies (capped at 12)
- Variant mix scales with wave number (wave 1: grunt-only; later waves add shielder, then bomber)
- All enemies + the single boss must be cleared for the wave to end

### Controls
| Key | Action |
|---|---|
| `← →` | Move |
| `SPACE` | Fire |
| `X` | Sacrifice docked ship for buff |
| `R` | Restart (game-over only) |

---

## 4. Playtest Findings

### What works
- **The rescue fantasy lands.** Player reports "actually enjoyed playing a couple games" — the loop feels fun.
- **The keep-vs-sacrifice tension reads.** Players have to actively choose between immediate power and long-term life recovery.
- **The 1-axis constraint holds up.** Once effects stopped fighting it (no more radial bursts), the dodge-and-position gameplay feels coherent.
- **Boss telegraph gives fair dodge window.** 0.7s is enough to react, not so much that it feels trivial.

### Tuning notes (not bugs, just values to revisit)
- **Boss every wave** — chosen for playtest intensity. May feel too busy in longer sessions; consider every-3rd-wave for shipped game.
- **10s buff duration** — feels right but not yet stressed under sustained combat.
- **Boss HP (60)** — about 6 player-bullets worth, drops fast under buff. Could scale up on later waves.

### Bugs found and fixed during playtest
1. Original capture-enemies stun threshold (30%) was unreachable with 10-dmg bullets — Grunt HP visits were 30→20→10→0, never landing in the ≤9 HP band. Widened to 40%.
2. `for-of` + `splice` mid-iteration in bomber-sacrifice and body-collision loops skipped every other killed enemy. Switched to backward-indexed loops.
3. `flashSlotEmpty()` triggered 60×/s via forced reflow while Up was held. Moved tractor pulse to edge-triggered keydown.
4. `keys` object not cleared on resetGame → held keys carried across restart. Added `clearKeys()` to blur / visibilitychange / resetGame.
5. Negative `dt` from tab-refocus clock skew propagated backward through all timers. Added `Math.max(0, ...)` to dt clamp.
6. Pop fx with `life > 0.3` (boss death used 0.5) produced `a > 1` → negative radius → canvas API crash. Clamped alpha to `[0, 1]`.
7. Boss respawn gate (`game.boss === null`) re-triggered every frame after boss death, causing infinite boss spawning. Added per-wave `bossSpawned` flag.

---

## 5. Design Principles Established

These emerged from playtest feedback and should govern all future design choices:

1. **Effects must respect the 1-axis geometry.** No radial/omni-directional patterns. Player-triggered effects amplify the x-axis fantasy (forward barrage, vertical column, temporary buffs) — never invent new dimensions.
2. **No common screen-clearing bombs.** Large-AoE effects are acceptable only when rare (gated by rescue opportunity), earned (require setup/risk), and not repeatable within a wave.
3. **The rescue fantasy is the identity.** The player is the underdog, not the aggressor. Mechanic proposals should weight against this — if it doesn't serve the rescue fantasy or the recoverable-life tension, it's likely off-theme.

---

## 6. Open Questions for the Next Phase

These are the design decisions the brainstorm/brief/GDD phases should resolve:

### Boss & capture
- Should boss HP scale per wave (60 → 80 → 100...) to keep the rescue challenge meaningful?
- Multiple bosses per wave at higher levels? Branching boss types?
- Should a captured ship be losable in a non-boss way (e.g., if the player dies while docked, is the docked ship also lost)?

### Docked ship
- Is 1-hit fragility the right dial, or should the docked ship have its own HP?
- Could the docked ship be upgradeable via meta-progression (more damage, slight homing, etc.)?
- Should the player be able to have multiple docked ships (multiple rescues per wave)?

### Sacrifice effect
- Is the temporary damage buff the only sacrifice payout, or should there be alternatives (e.g., a strong forward beam, time-slow, bullet-clear)?
- Should the sacrifice effect change based on which boss the ship was rescued from?

### Meta-progression (out of prototype scope, critical for full game)
- What unlocks between runs? (new ship types, starting buffs, boss-shield upgrades, extra starting HP, ...)
- Currency system? (score-as-currency, or separate capture/sacrifice currency)
- How does meta-progression interact with the life-recovery rule? (e.g., upgrades that improve life-recovery yield)

### Run structure
- How long is a run? (endless with leaderboards? fixed-length with a final boss? act-based?)
- What terminates a run? (HP = 0, or a specific fail state?)
- Is there a victory state, or is it score-attack only?

### Roguelite variance
- Procedural wave composition? (currently scripted by wave number)
- Build variety within runs (item drops, in-run upgrades)?
- Modifier waves (e.g., "no boss this wave, but double enemies")?

---

## 7. Files

| Path | Role |
|---|---|
| `prototype/index.html` | HTML shell, HUD overlays, controls hint |
| `prototype/game.js` | All game logic in one file (~890 lines) |
| `_bmad-output/implementation-artifacts/spec-capture-sacrifice-prototype.md` | v0 spec — **SUPERSEDED** by this doc |
| `_bmad-output/planning-artifacts/research/domain-roguelite-arcade-base-research-2026-06-27.md` | Original candidate comparison research (Galaga recommended) |
| `_bmad-output/planning-artifacts/prototype-1-design-snapshot.md` | This document |

---

## 8. Recommended Next Steps

1. **`gds-brainstorm-game`** — Facilitated session to explore the open questions in §6, especially meta-progression and run structure. The rescue loop is the seed; brainstorm what grows around it.
2. **`gds-create-game-brief`** — Formalize the vision (one-pager) before committing to a GDD.
3. **`gds-gdd`** — Full Game Design Document once the brief is locked.

The prototype has done its job — it validated the core loop. Don't keep adding features to it. Move to design artifacts.
