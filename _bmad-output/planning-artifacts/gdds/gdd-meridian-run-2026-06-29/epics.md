# Meridian Run — Development Epics

> Detailed epic + high-level-story breakdown for `gdd.md`. Each epic ends in something playable. Sequence is vertical-slice-first: chassis → gamble → build (the v0.1 hypothesis test) → run/meta → v1.0 polish → post-1.0 growth.
>
> **Milestone mapping:** v0.1 (systems-validation slice) = **Epics 1–3** · v1.0 (shipped game) = **Epics 1–5** · post-1.0 = **Epic 6** (uncommitted).
>
> Each epic: **Goal / In / Out / Depends on / Playable deliverable.**

---

## Epic 1 — Combat Chassis & Feel  *(v0.1)*

**Goal:** the 1-axis fixed-screen shooter feels good in Godot — the foundation everything proves itself on. Re-derive the prototype's feel in Godot idioms (no port), plus the new layered HP/ships economy.

**In:**
- Player ship: 1-axis horizontal movement, screen-clamped, fixed-timestep + delta-based (~320 px/s baseline).
- Vertical fire system (base shot: 10 dmg, 0.16 s cooldown, 620 px/s) that stays performant under heavy fire.
- Enemy spawn + formation + dive AI (Grunt / Shielder / Bomber); wave composition (wave N = 4+N, cap 12).
- Life & health economy: 3 ships × 3 HP, full heal per wave, 1 dmg standard / 2 dmg heavy, 1 s i-frames, respawn-at-full-HP on ship loss.
- Hit feedback / juice: hit-flash, screen-shake, particles (neon-vector).
- Basic HUD (HP, ships, wave, score).

**Out:** capture/rescue/sacrifice (Epic 2); power-ups/build (Epic 3); meta; menus; save.

**Depends on:** project scaffolding (autoloads, Input Map actions, base resolution/stretch).

**Playable deliverable:** a single wave you can survive or die in, with combat that *feels* right. Gate: the chassis is fun before layering systems on it.

---

## Epic 2 — The Gamble  *(v0.1)*

**Goal:** the full capture/rescue/sacrifice risk-reward loop — the P2 engine — playable in a wave.

**In:**
- Captor (Tractor) enemy: enter/formation/telegraph(0.7 s)/capture(0.4 s)/dive(1.6 s) state machine; capture column locked to player x.
- Capture: clean-only, once per wave, −1 ship (bypasses HP), respawn full HP; ship stored on boss.
- Rescue: kill captor during dive → docked ship; kill in formation → ship turns enemy ([Ref-11]).
- **Clean/docked tradeoff:** docked = capture-immune + +firepower + bigger hitbox; clean = gamble-on + small hitbox.
- Docked-ship resolution: absorb / sacrifice / keep(regain) / failed-rescue.
- Sacrifice burst: threat-relative buff (triple-shot / ×1.5 / fast-fire, ~10 s), no screen-clear.
- Safe-play vs rescue bonus economy (~30% vs ~25%).

**Out:** build/power-ups (Epic 3); run structure beyond a wave (Epic 4); meta.

**Depends on:** Epic 1.

**Playable deliverable:** a captor wave where the full gamble — court capture, rescue-or-sacrifice, or play safe — is a real, legible decision.

---

## Epic 3 — Build Engine  *(v0.1 hypothesis test)*

**Goal:** validate the **unvalidated** hypothesis — that the new build + gamble systems produce the godhood feel. *(Not* re-proving the rescue loop the prototype already playtested as fun.)*

**In:**
- Power-up system: Brotato-style take-or-sell on wave clear + between-wave shop; shared currency pool.
- Dual build ladder: main ship (persistent) + rescued ship (volatile); power-ups target either.
- Standard power-up pool (fire-rate, damage, shields, move-speed, +HP-cap, +ship); synergy/compounding.
- 2–3 ship types (distinct playstyles).
- A **compressed ~5-wave / 1-tier run** tuned to hit a felt power peak early.
- Cross-pollination *plumbing* (ship signature → shared pool) at mechanism level (depth is post-1.0).

**Out:** full 20-wave campaign (Epic 4); specialty pool / full fleet (Epic 5); cross-pollination full depth (post-1.0).

**Depends on:** Epics 1, 2.

**Playable deliverable:** a start-to-finish (if lean) run that demonstrably hits a **felt godhood peak** by its end. **This is the v0.1 go/no-go gate.**

---

## Epic 4 — Run Structure & Meta  *(v1.0)*

**Goal:** the complete roguelite run structure and meta skeleton.

**In:**
- 20-wave / 4-tier campaign; 5-wave tiers.
- Modifier waves (5/10/15): Swarm / Gauntlet / Bounty.
- Tier-cap escalation (modifier; +mini-boss Tier 2+).
- Wave-20 **final boss** (victory gate).
- **Endless mode:** frozen build, escalating enemies.
- Deterministic **seeded** generation (under-the-hood).
- Feat-based unlock plumbing (progression / skill / grind types); no meta-currency.
- Multi-tier loops (Tier 2, Tier 3 unlocks).

**Out:** full fleet breadth; daily/shared-seed UX (post-1.0); final balance polish (Epic 5).

**Depends on:** Epics 1–3.

**Playable deliverable:** a complete run — start → 4 tiers + boss → victory → endless — with meta unlocks functioning.

---

## Epic 5 — v1.0 Polish & Content  *(v1.0 ship)*

**Goal:** the shippable v1.0 game — the portfolio deliverable.

**In:**
- Specialty power-up pool (gated via cross-pollination); wider standard pool.
- Feat-unlocked **fleet** expansion (beyond the v0.1 2–3 ships).
- Cross-pollination mechanism complete; **balance pass** to the agreed curves (godhood peak at boss, threat-relative sacrifice ceiling, balance bands).
- Final-boss fight polish; full 20-wave balance.
- Art/audio polish (neon-vector + synthwave final pass); juice on godhood peak.
- HUD/menus/pause; **save/persistence** (`user://`); settings.
- **Win + Linux export presets** + verification; performance pass to ≥60 FPS.

**Out:** post-1.0 growth (Epic 6).

**Depends on:** Epic 4.

**Playable deliverable:** a complete, shippable roguelite on Windows + Linux — the definition of done.

---

## Epic 6 — Post-1.0 Growth  *(uncommitted, additive)*

**Goal:** the long-tail depth — additive data/content, not rewrites.

**In:**
- Full **fleet** (20+ ships) + signature mechanics.
- Cross-pollination **full depth** (the 50-hour combinatorial engine).
- Endless depth tuning; new modifier waves / captor variety.
- **Daily-challenge + shareable seed codes + leaderboards** (seed determinism already in place).
- Content-breadth deliverables from the dedicated post-systems brainstorm (full roster, specialty pool, formations, feats).

**Out:** anything requiring core-system rewrites (by design, growth is additive).

**Depends on:** v1.0 shipped (Epic 5).

**Playable deliverable:** each increment ships as additive content/depth on the live v1.0 base.

---

## Coverage check

Every GDD mechanic lands in an epic:
- 1-axis chassis / fire / economy → E1 · capture/rescue/sacrifice/gamble → E2 · build engine / dual-ladder / cross-pollination mechanism → E3 · run structure / modifier waves / boss / endless / seed / meta unlocks / multi-tier → E4 · specialty pool / fleet / balance / polish / save / export → E5 · full fleet / daily-seeds / depth → E6.
- ⏳ Content-breadth (full roster, modifier roster, formations, feats) is enumerated in a **separate post-systems brainstorm**, then lands in E5/E6.
