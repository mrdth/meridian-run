---
report: implementation-readiness-assessment
project: meridian-run
date: 2026-07-01
stepsCompleted:
  - step-01-document-discovery
  - step-02-gdd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
status: complete
overallReadiness: READY
canonicalFiles:
  gdd: _bmad-output/planning-artifacts/gdds/gdd-meridian-run-2026-06-29/gdd.md
  architecture: _bmad-output/planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md
  epics: _bmad-output/planning-artifacts/epics.md
  ux: _bmad-output/planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/
---

# Implementation Readiness Assessment Report

**Date:** 2026-07-01
**Project:** meridian-run

---

## 1. Document Inventory (Step 1 — Document Discovery)

### Canonical files selected for this assessment

| Document | Status | Canonical path |
|---|---|---|
| GDD | ✅ Single, no conflict | `gdds/gdd-meridian-run-2026-06-29/gdd.md` (31 KB) |
| Architecture | ✅ Single, no conflict | `architecture/architecture-meridian-run-2026-06-29/architecture.md` (65 KB) |
| Epics (+ embedded stories) | ✅ Resolved duplicate | `epics.md` (top-level, 83.5 KB) |
| UX Design | ✅ Multi-file package | `ux-designs/ux-meridian-run-2026-06-30/` (DESIGN.md 40 KB, EXPERIENCE.md 26 KB, 3 HTML mockups, validation + accessibility review) |

### Duplicate resolved — Epics
- **Chosen:** `planning-artifacts/epics.md` (83.5 KB, modified Jul 1 10:11) — the UX-enriched, authoritative breakdown (commits `6489b07` → `5c2e120`).
- **Superseded / not assessed:** `gdds/gdd-meridian-run-2026-06-29/epics.md` (7.4 KB) — original GDD-phase dev-epics seed.
- **Recommended cleanup (non-blocking):** rename or remove the superseded 7.4 KB copy so the two don't diverge and confuse future agents.

### Stories — declared NOT a gap
- No standalone `story-*.md` files exist. Per Mrdth's direction, stories live **embedded in the canonical epics doc**; individual story spec files are generated **one-by-one during the development loop** (`gds-create-story`). This is the intended workflow, so absence of per-story files is **not** scored as a readiness failure.

### Supporting context noted (not assessed directly)
- `gdds/.../decision-log.md` (15 KB), `architecture/.../decision-log.md` (16 KB), `ux-designs/.../.decision-log.md` (18 KB) — decision logs available for traceability checks.
- `implementation-artifacts/sprint-status.yaml` (2.7 KB) + `spec-capture-sacrifice-prototype.md` — sprint planning has begun; factored into later steps.
- No `index.md` found anywhere → **no sharded documents**; all artifacts are whole-docs-in-folders.

---

## 2. GDD Analysis (Step 2 — Requirements Extraction)

> **Source of truth read:** `gdds/gdd-meridian-run-2026-06-29/gdd.md` (GDD v1.1-draft, 31 KB) **+** its `decision-log.md` (for requirement-level decisions). The GDD does **not** number its own requirements — the `FR/NFR` numbers below are this assessment's **design-source baseline enumeration**. The canonical `epics.md` carries **its own** FR scheme (FR22, FR30, … referenced in the GDD decision-log); Step 3 reconciles the two for traceability.

### Functional Requirements (design-source baseline)

**Life & Health Economy**
- **FR1** — Ships (lives) = run economy: start 3, cap 5, run ends at 0. Ships enter **only** from external sources (tier-cap floor, shop/upgrades); the capture/rescue loop is ship-neutral or ship-negative — never farmed.
- **FR2** — HP = per-ship wave-survival buffer: base 3, grows via defensive build, **fully heals between every wave**. i-frames 1 s after each hit.
- **FR3** — Damage model: standard fire = 1 dmg (flat across all tiers); heavy/elite = 2 dmg (rare, telegraphed).
- **FR4** — Capture: costs 1 ship, bypasses HP, respawn at full HP; **once per wave, clean-only** (captor tractors only when no docked ship present; special/modifier waves excepted); **max one docked ship at a time**.

**Docked-ship resolution (one active choice: Sacrifice now, or Hold)**
- **FR5** — Sacrifice (active input): consume docked ship → threat-relative burst (see FR12); build track persists; net −1 ship.
- **FR6** — Hold (passive default): resolves to **Keep** (reach wave-end alive → flies off → +1 ship, net 0) or **Absorb** (hit while holding → docked ship dies first, sparing HP, net −1).
- **FR7** — Failed rescue (failure outcome, not a choice): kill captor in formation → captured ship turns enemy (net −1 ship, +1 enemy) `[Ref-11]`.

**Capture / Rescue / Sacrifice / Safe-play**
- **FR8** — Safe-play baseline: avoid capture → no ship change + safe-play bonus (~30%) > rescue bonus (~25%); the primary farm-mitigation.
- **FR9** — Captor (Tractor) 5-state FSM: enter (~1 s) → formation (3.5–5.5 s) → telegraph (**0.7 s**, capture column locks to player x) → capture (**0.4 s**) → dive (**1.6 s** bezier toward player then off-screen).
- **FR10** — Captor onboarding cadence: appears on an early wave to teach capture/rescue, then captor-chance scales with wave number.
- **FR11** — Rescue trigger: kill captor **during dive** → freed ship docks; kill in formation → ship turns enemy.
- **FR12** — Sacrifice burst: triple-shot (±0.18 rad) / ×1.5 damage / fast-fire (0.10 s cooldown) / ~10 s; **threat-relative ceiling**; **no screen-clear** (prototype guardrail).

**Movement & Combat Chassis**
- **FR13** — 1-axis horizontal movement, fixed-screen, player locked to bottom lane; **vertical fire-columns only**; player move-speed baseline ~320 px/s (playtest-tuned).
- **FR14** — Build-axis priority: projectile behavior > on-hit modifiers > generators. Earned non-vertical generators (Brotato-style turrets) = bounded exception only.

**Controls & Input**
- **FR15** — Keyboard + gamepad via Godot **Input Map actions** (never hardcoded keys): Move (L/R), Fire, Sacrifice docked ship, plus UI (confirm/back/pause); analog stick with deadzone; **every action has both keyboard and gamepad bindings**.

**Run Structure**
- **FR16** — 20 waves / 4 tiers / 5 waves per tier (Brotato model); every 5th wave = tier cap.
- **FR17** — **Wave termination = timed** (fixed, data-tuned duration in `wave_tuning.tres`), **NOT kill-count**. Wave ends when its timer expires `[Wave-1]`.
- **FR18** — Run-length ~25–45 min (feel guideline, not a hard cap); endless bounded only by player skill.
- **FR19** — In-wave spawning = **pulsed formations** via a **spawn schedule** from `RunGenerator` (ordered list of formation pulses: composition + entry timing + dive pattern + captor-presence), distributed via the `enemy_spawn` sub-stream. `4+N, cap 12` = **concurrency/spawn budget, not a kill quota** `[Wave-1]`.
- **FR20** — Waves 5/10/15 = modifier waves (randomly one of Swarm / Gauntlet / Bounty); **wave 20 = final boss** (fixed, the victory gate).
- **FR21** — Endless mode: build frozen at wave-20 state, no further power-ups, **escalating enemy threat** (~+10% enemy HP & fire-density per wave past 20, playtest-tuned).
- **FR22** — Run ends at ships = 0; full heal between waves (HP is a within-wave resource).

**Procedural Generation**
- **FR23** — Deterministic **seeded** generation: same seed → same wave composition + spawn schedule + modifier selection (player timing still varies; not frame-exact). Procedural = wave comp + spawn schedule + modifier selection; authored = wave-20 boss, captor AI, enemy stats. **v1.0: under-the-hood only** (daily/shared-seed + leaderboards = post-1.0).

**Permadeath / Progression / Meta**
- **FR24** — Permadeath-lite: run ends at last ship, in-run power lost. Persists only the feat-unlocked fleet. **No meta-currency, no between-run shop.**
- **FR25** — Meta split ~80/20 (or 90/10) variety vs raw-power; the small raw-power slice **compresses early waves** only (Hades pattern), does not raise the late-game ceiling.
- **FR26** — Pure **feat-based** unlocks (progression / skill / grind-fallback), not per-rescue. Three feat types defined; actual feats deferred (content-breadth).
- **FR27** — **Cross-pollination**: on unlocking a ship (fleet-unlock meta event), its signature mechanic is added as **one entry** to the shared power-up pool, droppable for all ships in subsequent runs. **Mechanism = v1.0; full depth (synergies, gating) = post-1.0.**
- **FR28** — Crown-jewel ship: unlock via Tier-3 victory **or** rescue-N grind (N ≈ 500, tuned to comparable effort).

**Item / Upgrade System**
- **FR29** — Two-tier power-up pool: **standard** (all ships from start) + **specialty** (gated behind fleet unlocks via cross-pollination).
- **FR30** — Dual build ladder: **main ship** (persistent core, run-long) + **rescued ship** (permanent build track; docked fighter is the consumable). Power-ups target either ladder.
- **FR31** — Acquisition (Brotato-style): wave clear → **3 power-ups, choose-1** (take or sell at ~50%); between-wave **shop offers 4 random** at currency cost; rescued-ship survival → currency multiplier + biased odds toward rescue-oriented power-ups. Target **~12–15 power-ups by wave 20**.
- **FR32** — Synergy model: godhood-defining upgrades compound **multiplicatively over current** (not additive-over-base); target **~8–12× wave-1 DPS at the final boss** (the felt godhood peak).
- **FR33** — Score = **display-only** (cumulative), **separate from currency**; currency earned per wave + rescue multiplier; score never spends. Leaderboards = post-1.0.

**Character Selection (The Fleet)**
- **FR34** — Ship types = distinct playstyles (variety > raw power). v0.1 = 2–3 ships; v1.0 = feat-unlocked fleet; post-1.0 = 20+ ships. Each ship's signature mechanic also becomes a findable power-up (cross-pollination).

**Difficulty Modifiers**
- **FR35** — Multi-tier loops: beat wave 20 → unlock a harder 1–20 tier. Tier 2 = +30% enemy HP + elite-chance any wave + denser formations; Tier 3 = ~+60% total (Brotato danger-levels / Hades heat).
- **FR36** — Modifier waves (5/10/15): **Swarm** (2× enemies, no captor) · **Gauntlet** (denser fire-columns, fewer foes) · **Bounty** (elite enemies, guaranteed power-up drops).
- **FR37** — Tier-cap escalation: Tier 1 caps = modifier only; Tier 2+ caps = modifier + mini-boss.

**Weapon Systems (prototype baselines, playtest-retuned)**
- **FR38** — Player base shot: 10 dmg, 0.16 s cooldown, straight up, 620 px/s.
- **FR39** — Sacrifice burst (buffed): ×1.5 dmg, 0.10 s cooldown, +triple-shot (±0.18 rad), ~10 s, threat-relative ceiling.
- **FR40** — Docked ship stream: 10 dmg, matches player fire cooldown, parallel bullet +28 px x-offset.
- **FR41** — Earned generators: bounded non-vertical coverage (earned exception); **no screen-clearing weapons** (large-AoE only when rare/earned/non-repeatable).

**Aiming & Combat Mechanics**
- **FR42** — Aiming = fixed vertical fire (1-axis), no twin-stick/aiming input. Hit detection = projectile (not hitscan). Dodge = 1-axis lateral, telegraphed capture column (0.7 s window). No critical/weak-point system.

**Enemy Design & AI**
- **FR43** — Enemy types (baseline): Grunt (HP30/score100/fire1.2–2.4s/speed60), Shielder (50/150/0.9–1.8s/50), Bomber (80/300/heavy 2dmg/1.6–2.8s/80), Captor (60, +50%/tier).
- **FR44** — Formation + dive AI (Galaga-lineage); wave N = 4+N enemies, cap 12; variant mix scales by tier.

**Arena & Win/Loss**
- **FR45** — Single fixed-screen, player locked to bottom, 1-axis horizontal lane, vertical fire geometry; no cover/verticality. Power-up drops on wave clear and Bounty waves. **Single-player only** (multiplayer out of scope).
- **FR46** — Wave-20 final boss: fixed/authored fight, the victory gate. Defeating it = win → choose to end run or push endless.
- **FR47** — Win = defeat wave-20 boss (→ end or endless). Loss = lose last ship (ships = 0). *(Consolidates FR22's loss condition.)*

**Game Feel / Juice**
- **FR48** — Juice: neon glow, particle bursts, screen-shake on the godhood peak; punchy SFX on hits/pickups/sacrifice bursts. Juice must be arena-scoped and auto-disabled in menus.

**Meta Persistence / UI Flow**
- **FR49** — Persist to `user://` only: unlocked ships, feat progress, settings, best stats. **Run state is never saved** (quitting abandons the run — no resume).
- **FR50** — UI flow: title/menu system, between-wave reward + shop interludes, power-up selection UI, pause. (Operational in the core loop; detailed in the UX design package.)

**Total FRs (design-source baseline): 50**

### Non-Functional Requirements

**Performance**
- **NFR1** — **≥60 FPS floor** (minimum, not a cap); frame-budget ceiling **16.67 ms** for the worst-case frame.
- **NFR2** — Gameplay on a **fixed-timestep physics loop (60 Hz)**; all motion delta-based so it behaves identically at 60 or 144+ FPS.
- **NFR3** — **Deterministic** seeded runs (reproducible from a seed). Profile measured hotspots, not guesses.

**Platform**
- **NFR4** — **Windows + Linux desktop**; Godot 4.6, 2D, Compatibility renderer. Export preset per platform; **verify on both before release** (development on Linux).
- **NFR5** — Responsive 2D scaling: fixed base resolution, canvas-scaled (`stretch/mode = canvas_items`, `stretch/aspect = expand`).

**Input / Usability**
- **NFR6** — Input via Input Map actions + gamepad; analog movement with deadzone; every action has both keyboard and gamepad bindings.
- **NFR7** — Saves/settings via `user://` (correct per-user OS path); never `res://` or absolute paths.

**Accessibility / Readability**
- **NFR8** — 1-axis lane **readability** (neon-vector art chosen to maximize fire-column readability); dedicated accessibility review exists in the UX package.

**Reliability**
- **NFR9** — Save system integrity: persist to `user://` only; **run state never saved (no resume)**; **version the save schema** for migration.

**Testing**
- **NFR10** — **GUT** test framework (committed); separate pure logic from Node/scene code; tests under `tests/` mirroring domain layout; CI/pre-commit headless run (`godot --headless -s addons/gut/gut_cmdln.gd`).

**Maintainability / Scalability**
- **NFR11** — **Data-driven content**: ships/power-ups/enemies/formations/modifiers are `.tres` instances; adding content = add a `.tres`, zero code (additive growth post-1.0, not rewrites).

**Pacing**
- **NFR12** — Run-length budget ~25–45 min (feel guideline, not a hard cap); wave duration is the primary pacing dial.

**Total NFRs: 12**

### Additional Requirements / Constraints / Dependencies

- **[Constraint]** Solo **intermediate** dev; purpose = portfolio / skill-build (learn Godot 4.6 deeply by shipping a complete game). Commercial positioning **not** required. Scope brutally honest; finished vertical slice > breadth.
- **[Constraint]** Delivery phasing: **v0.1 = Epics 1–3** (systems-validation slice: validate build+gamble godhood feel — *not* re-proving the rescue loop); **v1.0 = Epics 1–5** (shipped game); **post-1.0 = Epic 6** (uncommitted growth).
- **[Constraint]** **JS prototype is reference-only — do NOT port.** Godot idioms only (no plain-object entities, no manual draw loops, no splice-during-iteration).
- **[Constraint — Out of Scope]** No screen-clearing bombs; no player radial/8-way fire; no mobile/touch; no meta-currency/between-run shop; no narrative/VN density; no full fleet depth at v1.0; no daily/shared-seed UX at v1.0.
- **[Constraint]** Single-player only.
- **[Assumption]** Prototype tuning values (HP 3, fire cooldown 0.16 s, bullet 620 px/s, enemy stats, captor timings) are starting **baselines**, retuned in v1.0 playtest.
- **[Assumption]** Safe-play ~30% / rescue ~25% bonuses are placeholder targets, playtest-tuned.
- **[Assumption]** Crown-jewel rescue-N ≈ 500, tuned to Tier-3-comparable effort.
- **[Dependency]** GUT test framework (committed; installs at project scaffolding / Epic 1).
- **[Dependency]** **Content-breadth brainstorm** (post-systems) for full fleet roster, specialty pool, modifier roster, formation types, and feat list.
- **[Open / Deferred — non-blocking]** Q#6 cross-pollination balance · Q#8 modifier-wave roster (v1.0 scope) · Q#9 captor variety at higher tiers · Q#10 feat-list design · Q#11 content-breadth enumeration — all deferred to the post-systems brainstorm; not phase-blocking.
- **[Reserve / not-v1.0]** `[Risk-13]` captured-firepower reserve lever — held, not committed, for late-run balance if needed.

### GDD Completeness Assessment

**Overall: STRONG — v1.1-draft is comprehensive, internally consistent, and decision-traceable.**

- ✅ **Structure complete** — every standard GDD section present (pillars, core loop, mechanics, run structure, procedural gen, progression/balance, art/audio, tech specs, epics, success metrics, risks, out-of-scope, assumptions, open questions).
- ✅ **Decision traceability** — bracketed refs (`[Ref-11]`, `[Risk-12]`, `[Wave-1]`, `[Build-9]`, `[Build-15]`, `[Var-33/34]`, `[Risk-13]`) all resolve to settled decision-log entries; no orphan refs.
- ✅ **Phase-blocking open questions resolved** — Life/Health economy (Q#1/5), seed determinism (Q#7), sacrifice ceiling (Q#3), godhood curve (Q#4), multi-rescue (Q#5) all ✅. Remaining Q#6/8/9/10/11 are content-breadth, explicitly deferred and non-blocking.
- ✅ **Wave-structure gap closed** — the `[Wave-1]` timed-duration + pulsed-formation decision (surfaced during UX planning) was propagated to `epics.md` (FR30, Stories 1.4/1.8/4.2/4.3/4.4). Good downstream propagation.
- ⏳ **Intentional breadth gaps** (deferred, not defects): full fleet roster, specialty pool, modifier roster, formation types, feat list, art/audio asset counts/budgets — all parked at the content-breadth brainstorm. Appropriate for a systems-first delivery, but Step 6 should confirm none of these is required for the v1.0 *structure* the epics commit to.
- ⚠️ **Tuning values are placeholders** — every combat/economy number is explicitly "playtest-tuned" baseline. Fine for readiness (the *structure* is what matters here), but worth flagging that no final balance exists.
- ⚠️ **Minor:FR/FR overlap** — FR22 (run ends at 0) and FR47 (win/loss) state the loss condition twice; consolidated in FR47. Cosmetic, not a gap.

**Verdict:** The GDD is a sound requirements source for epic-coverage validation. Proceeding to Step 3.

---

## 3. Epic Coverage Validation (Step 3 — Traceability)

> **Document read completely:** `planning-artifacts/epics.md` (canonical, 83.5 KB / 1201 lines). Structure: Requirements Inventory (FR1–FR50, NFR1–NFR15, AR1–AR15, UX reqs) → explicit **FR Coverage Map** → Epic List (9 epics) → 57 stories with Given/When/Then acceptance criteria. Milestone phasing: **v0.1 = E1–E3** (systems-validation slice + GO/NO-GO gate) · **v0.5 = E4** (true alpha) · **v1.0 = E5–E8** (shipped game) · **post-1.0 = E9** (uncommitted, additive). Two honest gates: **E3** (does the build engine compound?) → **E4** (does 20-wave pacing peak?).

### Epic-side FR coverage (as claimed by `epics.md`)

The epics doc carries its **own** FR inventory (FR1–FR50, re-derived from the GDD) and an explicit **FR Coverage Map** asserting all 50 map to E1–E8 (v1.0) with E9 post-1.0. My validation: **read every story's `(FRx)` tag and acceptance criteria and confirmed the map is accurate** — no FR is claimed-covered but actually missing a story.

### Coverage matrix — GDD baseline FR → epic coverage

> Both docs carry ~50 FRs but under **different numbering** (the epics re-organized by domain). The table maps my Step-2 GDD baseline → the epics' FR(s) → owning epic/story → status. **Every GDD design requirement resolves to a story.**

| GDD baseline FR (design intent) | Epics FR(s) | Owner epic(s) / story(ies) | Status |
|---|---|---|---|
| Ships (3/cap5/end@0); HP (3/heal/wave); dmg 1/2; i-frames; capture bypass | FR8–FR12 | **E1** / 1.5 | ✓ |
| 1-axis movement ~320 px/s; Input Map actions (kb+pad) | FR1–FR3 | **E1** / 1.2, 1.1 | ✓ |
| Vertical fire; base shot 10/0.16s/620px/s; no crits | FR4–FR6 | **E1** / 1.3 | ✓ |
| Docked stream +28px; build-axis priority; generators exception | FR7 | **E2** / 2.4 + **E3** / 3.7 | ✓ |
| Captor 5-state FSM; capture clean/once/wave; rescue/failed-rescue; clean/docked tradeoff; dual nature; 4-outcome resolution; sacrifice burst; safe-play bonus; onboarding cadence | FR13–FR21 | **E2** / 2.1–2.8 | ✓ (all 13 gamble FRs) |
| 3-choose-1 + shop; dual ladder; recompute StatBlock; multiplicative synergy ~8–12×; standard pool; rescue-survival bias; cross-pollination mechanism | FR22–FR28 | **E3** / 3.1–3.6 | ✓ |
| 20 waves/4 tiers/5 waves; timed termination `[Wave-1]`; pulsed spawn schedule (4+N cap 12 budget); determinism; seeded sub-streams; pure RunGenerator | FR29–FR33 | **E1** / 1.4, 1.8 + **E4** / 4.1–4.4 | ✓ (Wave-1 explicitly propagated) |
| Modifier waves (Swarm/Gauntlet/Bounty); wave-20 boss + endless; multi-tier loops; tier-cap mini-bosses | FR34–FR37 | **E5** / 5.1–5.3 + **E6** / 6.1–6.2 | ✓ |
| Permadeath-lite/persist fleet; feat unlocks (3 types); variety>power split; crown-jewel ship; meta-only versioned save | FR38–FR42 | **E4** / 4.6 + **E7** / 7.1–7.4 | ✓ |
| Enemy types (Grunt/Shielder/Bomber/Captor); formation+dive AI; fixed-screen arena; no screen-clear; single-player | FR43–FR45 | **E1** / 1.4 | ✓ |
| HUD/select/shop/menus/pause (UX-enriched); juice/feedback; audio; score display-only | FR46–FR49 | **E1** / 1.6, 1.7 + **E3** / 3.4, 3.5 + **E8** / 8.4, 8.5 | ✓ |
| Win/loss conditions | FR8, FR35 | **E1** / 1.5 + **E4** / 4.5 | ✓ |

### Requirements the epics ADDED beyond the GDD baseline (traceable, not gaps)

- **FR50 — Debug overlay + cheat hotkeys.** Not a GDD player-facing FR; driven by the architecture (`Debug` autoload) and explicitly "critical for fast Epic-3 hypothesis testing." A legitimate, well-grounded dev-tooling addition → Story 1.1 + 3.8. **Strengthens** readiness.
- **Richer NFR split** — the epics decomposed performance into NFR3 (hot-path discipline), NFR4 (pooling), NFR6 (collision culling), NFR7 (code quality) where my baseline had grouped them. All traceable to `architecture.md` / `project-context.md`.
- **AR1–AR15 (Additional Requirements)** — 15 architecture-driven infra requirements (autoload registry, state ownership, recompute engine, seeded sub-streams, composition, pooling, signal boundary, ContentRegistry, arena-scoped juice, config tiers, error handling, logging, debug, Godot gotchas, optional MCP). AR1 → Story 1.1; the rest are cross-cutting, "enforced across all epics."

### Missing / uncovered requirements

**Critical missing FRs: NONE.**

**High-priority missing FRs: NONE.**

**Soft / low-severity traceability notes (none are true coverage gaps):**

1. **Run-length budget (~25–45 min) is emergent, not discretely tested.** It is a feel *guideline* (not a hard cap) produced by timed waves + tier structure + reward interludes; no story asserts "a full run lands 25–45 min." Appropriate — it's a tuning outcome validated at the **E4 pacing gate** (Story 4.8) and E8. *Recommendation:* add "full-run duration lands in the 25–45 min feel-band" as an explicit E4.8 / E8.7 gate criterion so the budget is checked, not assumed.
2. **No preserved GDD→epic FR ID trace.** The epics re-numbered requirements, so there is no 1:1 GDD-paragraph→epic-FR matrix (only an epic→FR map). Coverage is *semantically complete* (verified above), but a future agent can't mechanically trace a GDD line to its FR. *Recommendation (low):* optionally add a GDD-section→FR provenance column. Non-blocking.
3. **Captor `+50%/tier` HP scaling** is implied by the tier system + data tuning but not called out in Story 2.1's acceptance criteria. Covered by data-driven `.tres` + tier scaling; minor.

### Coverage statistics

| Metric | Count |
|---|---|
| Total GDD-baseline FRs (Step 2) | **50** |
| FRs covered (traceable to a story) | **50** |
| **Coverage %** | **100%** |
| Epic-side FRs (FR1–FR50) all map to ≥1 epic | **50/50** ✓ |
| NFRs (15) with cross-cutting epic homes | **15/15** ✓ |
| ARs (15) with primary homes | **15/15** ✓ |
| Stories total | **57** (E1:8 · E2:8 · E3:9 · E4:8 · E5:4 · E6:3 · E7:5 · E8:7 · E9:5) |
| Stories with Given/When/Then acceptance criteria | **57/57** ✓ |

### Step 3 verdict

**Coverage is COMPLETE — 100% of GDD functional requirements trace to an implementing story, and the epics layer in additional grounded requirements (debug tooling, granular NFRs, 15 ARs) the GDD did not enumerate.** The `[Wave-1]` timed-wave decision is correctly propagated (FR30, Stories 1.4/1.8/4.2/4.3/4.4). No requirement falls through the cracks. The breakdown is milestone-phased with two honest go/no-go gates (E3 build hypothesis, E4 pacing) — exemplary discipline for a solo-dev portfolio scope.

Proceeding to Step 4 (UX alignment).

---

## 4. UX Alignment Assessment (Step 4 — UX ↔ GDD ↔ Architecture)

### UX Document Status

**FOUND — and mature.** `ux-designs/ux-meridian-run-2026-06-30/` is a complete, **finalized (2026-07-01)** UX package, not a stub:
- **`DESIGN.md`** (40 KB) — visual spine: Brand & Style, Colors (25 calm + 9 climax tokens), Color-safety core, Typography (Chakra Petch / Inter / JetBrains Mono), Layout/Spacing, Elevation, Shapes, **24 named components**, Do's & Don'ts.
- **`EXPERIENCE.md`** (26 KB) — behavioral spine: Foundation, Information Architecture, Voice & Tone, Component/State/Interaction patterns, **Accessibility Floor**, Key Flows (Rosa wave-20 climax), HUD & Diegetic UI, Input Schemes, Game Feel & Juice, Responsive & Platform.
- **`.decision-log.md`** (18 KB) — **canonical source of truth** (30 confirmed decisions F1–F9 / V1–V3 / T2 / I1–I2 / M1 / A1–A2 / O1 / H1–H6 / S1 / G1 / C1–C3 / P1 / D1; "spines win on conflict with any mock").
- **3 promoted mockups** (`key-hud`, `key-build-screens`, `key-title`) + 2 working studies; **`validation-report.md/.html`** + **`review-accessibility.md`** (self-validation with developer-confirmed resolutions).

The epics doc already treats UX as **"source of truth for all UI surfaces"** (completed 2026-07-01, was `null` at first breakdown) and cites UX decisions by ID throughout stories 1.7 / 3.4 / 3.5 / 3.9 / 7.5 / 8.4.

### UX ↔ GDD Alignment — **STRONG**

UX `F1` declares its sources = GDD + brief + epics. Every UX **Foundation** decision traces cleanly to a GDD requirement, and UX *refines* three GDD items without contradicting any:

| UX decision | GDD source | Relationship |
|---|---|---|
| F2 platform (PC, no mobile/touch) | GDD platforms + Out-of-Scope | ✓ mirror |
| F3 HUD never obscures the 1-axis lane | GDD arena / 1-axis chassis | ✓ mirror |
| F5 Input Map actions (kb+gamepad) | GDD FR15 controls | ✓ mirror |
| F6 no-resume / meta-only saves | GDD FR49 + ADR-3 | ✓ mirror (+ UX adds: "needs player-facing warning") |
| F7 3-offer take/sell + 4-offer shop | GDD FR31 acquisition | ✓ mirror |
| F8 arena-scoped juice | GDD FR48 + arch AR9 | ✓ mirror |
| **H2** score≠currency, **currency NOT shown in-wave** | GDD FR33 (refines) | ✓ **refinement** — sharpens "separate" to "shop-stage only"; encoded in Story 1.7/3.5 |
| **H3** timed waves, 60 s survive-to-end countdown | GDD FR17 `[Wave-1]` | ✓ **refinement** — UX adopted the timed-wave decision and gave the timer a HUD home |
| **V3** calm→climax palette arc | GDD godhood-peak juice (FR48/NFR11) | ✓ **enrichment** — turns the peak into a felt color channel |
| A1 accessibility floor | GDD NFR8 readability | ✓ **expansion** |
| O1 onboarding | GDD captor onboarding (FR10/21) | ✓ mirror |

**UX additions the GDD did not specify** (all consistent with GDD intent, zero contradictions): typography (T2), iconography (I1), MAIN/WING chip (I2), punchy microcopy (M1), full accessibility floor (A1), form-factor Steam-Deck stance (P1), non-diegetic UI stance (D1). These are appropriate UI-depth that a GDD legitimately leaves to UX.

**UX requirements NOT reflected back into GDD:** none problematic — the GDD retains FR46 (HUD/select/shop/menus/pause), FR47 (juice), NFR11 (neon-vector) as its UI baselines and explicitly defers detail to UX. No drift.

### UX ↔ Architecture Alignment — **STRONG**

The architecture does not merely "support" UX — it **explicitly implements every UX system** with concrete code patterns, and its own validation table records **"UX coverage (v1.1): ✅ Pass — 7 UX-driven deltas folded in."**

| UX system | Architecture home | Verified |
|---|---|---|
| Palette arc (V3) | **D13** + ADR-5 + **NP4** — arena-scoped `PaletteArcCoordinator`, pure `build_power`/`arc_t`, `ThemeTokens` resource, `arc_t_changed` on EventBus | ✓ code-pattern present |
| Accessibility floor (A1) | **D14** — `Settings` autoload (reduced_motion/ui_scale/deadzone/remap), `JuiceCoordinator` dampens ~70% + ≤3 Hz flash cap | ✓ |
| Hold-to-commit (A1) | **NP5** — pure `HoldToCommit` helper (Sacrifice, Quit Run); Sell explicitly *not* hold | ✓ |
| 24-component UI map | **D15** — Control-UI under `ui/`, in-world entities in gameplay domains; `PowerUpDefinition` gains `target_ladder/rarity/icon_family` | ✓ |
| HUD focus/fade (S1) | **D15** — reusable `state_machine` + pure `HudFocusModel` (hysteresis, throttled) | ✓ |
| Toasts (OQ9) | **D15** — `toast_manager` queued, calm-moments-only | ✓ |
| Shape+outline CVD defense (A2) | **D16** + ADR-6 — `FactionComponent`-driven vector renderer + monochrome debug toggle | ✓ |
| Naming conflict (F-1) | reconciled `main|rescued` → **MAIN|WING** across UX/arch/epics | ✓ (no code yet, free rename) |

Every UX surface maps to an implementing story: HUD→1.7 · select→3.4 · shop→3.5 · palette-arc→3.9 · toasts→7.5 · full HUD/menus/pause/settings/accessibility/title/codex→8.4.

### Findings & Warnings

**✅ Exemplary self-validation (not a gap).** The UX `validation-report` independently caught a real **climax-end CVD accessibility collapse** (the calm→climax arc collapses hero-magenta and hazard-red to ΔL 0.025 for red-green CVD players — exactly at the Rosa wave-20 climax), plus 3 High findings (climax-muted failing AA, low-time timer marginal contrast, mocks shipping pre-lift tokens). **All Critical/High were resolved** via developer-confirmed **Fix A** (shape+outline = primary differentiator → arch D16/ADR-6; `climax-hazard` amber `#FF9E3D`; `climax-muted` lifted to `#9979B0` AA-clear; neutral low-time timer halo). Medium/Low closed at spec layer or filed non-blocking. This is exactly the rigor a readiness gate wants to see.

**⚠️ LOW — 3 of 4 mocks ship stale tokens (evidence-fidelity, non-blocking).** Only `key-hud.html` was synced to the committed tokens; `key-build-screens`, `key-title`, and `type-specimen-1` still carry the pre-lift `#6B7B9A` muted (4.67:1) instead of `#7E8DAA` (5.95:1). The decision-log rule "spines win on conflict" contains the risk, but an implementer copying mock tokens would ship sub-AA values.
- *Recommendation:* when generating dev-story specs for UI stories (1.7/3.4/3.5/8.4), cite **spine tokens** (`DESIGN.md` frontmatter) as canonical, not mock CSS; refresh the 3 mocks opportunistically.

**ℹ️ NON-BLOCKING — 8 `[ASSUMPTION]` defaults (OQ9) to confirm during dev:** boss/mini-boss HP = top bar · sacrifice-burst = timer ring · modifier = chip flash at wave start · quit-run = hold-to-confirm · sell = single-press no-confirm · unlock/feat = between-wave toast · **localization = English-only for v1.0** · wave-intro/clear/tier = standard banners. Reasonable defaults; already wired into stories (8.4 etc.). Flag the English-only-v1.0 localization assumption so it isn't mistaken for an oversight.

**ℹ️ Properly deferred (non-blocking):** OQ3 docked-fighter accent color → Shield-PU pass; OQ8 ship-class glyphs → ship-select screen (post-fleet); OQ9 items above.

### Step 4 verdict

**UX alignment is STRONG.** UX is the UI source of truth; it refines (not contradicts) the GDD; the architecture implements every UX system with verified code patterns and self-validates as ✅ Pass; and every UX surface traces to an epic/story. The only actionable items are **low-severity**: refresh 3 stale-token mocks and confirm the 8 OQ9 `[ASSUMPTION]` defaults during the relevant dev-stories. **No UX requirement lacks architectural support; no architectural UI component lacks a UX spec.**

Proceeding to Step 5 (Epic Quality Review).

---

## 5. Epic Quality Review (Step 5 — Best-Practices Enforcement)

> Validation target: all **9 epics + 57 stories** in canonical `epics.md`, checked against `create-epics-and-stories` standards — player value, epic independence, story sizing/dependencies, acceptance-criteria quality, data-creation timing, greenfield setup.

### 5.1 Epic structure — player/user value focus

**All 9 epics carry an explicit player outcome; none is a bare technical milestone.**

| Epic | Player outcome (verbatim gist) | Player value alone? |
|---|---|---|
| E1 Combat Chassis & Feel | fly/fire/fight/survive-or-die a single authored wave | ✅ playable wave |
| E2 The Gamble | full capture/rescue/sacrifice loop in a wave | ✅ |
| E3 Build Engine | a compressed ~5-wave run hitting a felt godhood peak | ✅ (GO/NO-GO gate) |
| E4 Campaign Spine | complete ugly end-to-end 20-wave run → boss → win/lose | ✅ (true alpha) |
| E5 Run Variety | modifier waves + tier-cap mini-bosses | ✅ |
| E6 Run Depth | endless mode + multi-tier loops | ✅ |
| E7 Meta Progression | persistent feat unlocks + crown-jewel ship | ✅ |
| E8 v1.0 Polish & Ship | shippable game (Win+Linux) | ✅ |
| E9 Post-1.0 Growth | fleet depth, daily seeds, leaderboards | ✅ |

A handful of stories are **developer-perspective** (1.1 scaffolding, 3.1 StatBlock engine, 4.1 SeedManager, 4.2 RunGenerator) — but each sits inside a player-valued epic, enables player-visible follow-ons, and carries testable ACs. This is the *correct* greenfield pattern (the step explicitly expects an initial-setup story), **not** a technical-milestone-epic violation.

### 5.2 Epic independence — dependency chain

**Strictly forward, no cycles, no epic requires a later epic.**

```
E1 (standalone; scaffolding internal to 1.1)
 └▶ E2 (depends E1)
     └▶ E3 (depends E1, E2)
         └▶ E4 (depends E1–E3)
             └▶ E5 (depends E4) ─▶ E6 (depends E4, E5)
                                   └▶ E7 (E4–E6) ─▶ E8 (E4–E7) ─▶ E9 (E8)
```

**Independence-preserving design choice (notable):** E2 **hardcodes** docked-ship stats (+28 px stream, bigger hitbox) and starts the rescued-ship track *flat*, deliberately avoiding a premature `StatBlock` so E2 does **not** depend on E3's build engine (Story 2.4 AC + Epic 2 "Standalone" note). Sophisticated dependency management — exactly what the independence check wants.

**Split-FR progressive elaboration is not a forward dependency:** FR35 (boss/endless) → E4 functional + E6 endless + E8 polish; FR42 (save) → E4 core + E7 meta + E8 settings. Each epic delivers a usable slice; later epics elaborate, they don't gate earlier ones. ✅

### 5.3 Story quality & acceptance criteria

- **Format:** all 57 stories use **Given/When/Then** BDD. ✅
- **Testability:** concrete data-tunable values throughout (10 dmg / 0.16 s / 620 px/s / 0.7 s telegraph / ~320 px/s / 60 s timer / 4+N cap 12). ✅
- **Traceability:** every story tags its `(FRx · ARy · UX-id)` provenance. ✅
- **Feel/hypothesis gates** (1.8, 2.8, 3.8, 4.8, 5.4, 6.3) carry subjective playtest ACs — **mitigated** by pairing each with a measurable half (e.g. 3.8: "(a) engine demonstrably compounds, GUT-backed **AND** (b) playtester reports a felt peak"). ✅ good practice.
- **Within-epic ordering:** inspected all 9 epics — story N builds on story N-1 outputs, **no forward references within an epic**. (E.g. E3: 3.1 stat engine → 3.2 defs → 3.3 ladder → 3.4 select UI → …; 3.9 palette-arc's `build_power` input comes from 3.1/3.3 — correctly sequenced and explicitly flagged.) ✅
- **Cross-epic "wired in later" notes** (e.g. 7.5 toast primitive "wired in Story 8.4") are **progressive elaboration, not blocking forward deps** — 7.5 stands alone (delivers between-wave toasts); 8.4 consumes its primitive. ✅

### 5.4 Data/entity creation timing

**Data is created when first needed, not upfront.** Story 1.1 scaffolds autoloads + Input Map + GUT + display but does **not** populate content; `EnemyDefinition`s arrive in 1.4, `PowerUpDefinition`s in 3.2, `ModifierWaveDefinition`s in 5.1 — each as its system lands, via `.tres` (AR8/AR10). ✅ Correct.

### 5.5 Special checks

- **Starter template (greenfield):** architecture AR1 mandates **"build on the existing `project.godot` scaffold — no external starter template"** (avoids conflicting conventions). Story 1.1 implements exactly that (autoloads, Input Map, GUT, stretch). ✅
- **Greenfield indicators:** initial-setup story (1.1) ✅ · dev-env config (1.1 + arch §Development Environment) ✅ · build/export pipeline — **deferred to 8.6** (late, see minor #4).
- **Autoload registry:** Story 1.1 registers 6 of the 11 canonical autoloads (the rest arrive as their systems land). AC says "canonical positions" — acceptable YAGNI, **provided** later stories insert at canonical slots (see minor #3).

### 5.6 Best-practices compliance (per epic)

| Check | E1 | E2 | E3 | E4 | E5 | E6 | E7 | E8 | E9 |
|---|---|---|---|---|---|---|---|---|---|
| Player value | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Independent (forward-only) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Stories sized | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ 8.4 large | ✅ |
| No forward deps | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Data created when needed | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Clear ACs (G/W/T) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| FR traceability | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### 5.7 Findings by severity

#### 🔴 Critical Violations — **NONE**
No technical-milestone-only epics · no forward dependencies breaking independence · no epic-sized story that can't be completed.

#### 🟠 Major Issues — **1**
1. **Story 8.4 is oversized.** "Full HUD, Menus, Pause, Game-Over, Settings & Accessibility Floor" bundles title screen + full HUD polish + pause+codex + game-over/run-summary + settings panel + accessibility floor + input remap — **10 Given/When/Then blocks** in one story. Risk: too large for a single dev-cycle / hard to estimate. *Recommendation (non-blocking):* split into 2–3 sub-stories when picked up (e.g. 8.4a title+menus+pause+codex · 8.4b game-over+run-summary · 8.4c settings+accessibility+remap). Improves estimability without changing scope.

#### 🟡 Minor Concerns — **6**
1. **UI-story ACs cite UX decision IDs by reference** (S1/H4/V3/I2/A2/…) rather than restating — not self-contained; a dev needs the UX decision-log to interpret them. Intentional convention, but a documentation cross-dependency. *Recommendation:* the `gds-create-story` dev-loop output should inline or hot-link each cited UX decision into the story spec.
2. **Feel/hypothesis-gate ACs are partly subjective** (3.8 "felt peak", 1.8 "feel fair"). Mitigated by paired measurable criteria — ensure the measurable half is pinned down when each gate story is picked up.
3. **Autoload registry completeness across stories.** 1.1 registers 6/11; the other 5 (SeedManager, ContentRegistry, SaveManager, AudioManager, GameManager) land in later epics. *Recommendation:* track that each addition is inserted at its **canonical position** (not appended) to preserve load order.
4. **Export/build pipeline is late (Story 8.6)** vs the "set up early" greenfield ideal. *Recommendation (non-blocking):* add an early E1 export smoke-test on both platforms to catch renderer/path issues before they compound.
5. **Developer-perspective engine stories** (1.1, 3.1, 4.1, 4.2) — acceptable within player-valued epics, but 3.1 StatBlock is foundational to the E3 hypothesis. Already mitigated by GUT-testable pure-logic ACs. *Observation only.*
6. **No standalone story files yet** — stories are embedded in `epics.md`. Per Mrdth's Step-1 direction these are generated one-per-story in the dev loop. *Recommendation:* the dev-loop generator must carry the FR tags, UX-ID citations, and G/W/T ACs forward verbatim into each `story-X.Y.md`.

#### ✅ Exemplary practices observed
- **Two honest go/no-go gates** (E3 build-compounds? → E4 pacing-peaks?) with dual objective+subjective criteria.
- **E2 hardcodes docked stats** to stay independent of E3's build engine.
- **Full per-story traceability** (FR + AR + UX-ID tags).
- **Progressive elaboration** of split FRs without forward deps.
- **Honest milestone phasing** (v0.1 / v0.5 / v1.0 / post-1.0) realistic for one intermediate solo dev.
- **Data-driven, per-story content creation** (`.tres`, zero-code extensibility).

### 5.8 Step 5 verdict

**Epic/story quality is HIGH.** Zero critical violations; one major (Story 8.4 sizing, non-blocking with a clean split recommendation); six minor, mostly dev-loop hygiene. The breakdown demonstrates mature dependency management (forward-only, hardcoded-to-preserve-independence), rigorous BDD acceptance criteria, and exemplary scope discipline. **Ready for the final readiness assessment.**

Proceeding to Step 6 (Final Assessment).

---

## 6. Summary and Recommendations (Step 6 — Final Assessment)

### Overall Readiness Status

# ✅ **READY for implementation (Phase 4)**

The Meridian Run planning artifact set — **GDD v1.1-draft · Architecture v1.1 (UX fold-in) · UX spines finalized 2026-07-01 · Epics 9 / 57 stories** — is **exceptionally well-aligned and implementation-ready**. There are **zero blocking issues**. Every functional requirement traces to a story; the architecture implements every UX system; the epic chain is strictly forward-only with two honest go/no-go gates. The remaining items are advisory dev-loop hygiene, not readiness gaps.

### Assessment scorecard

| Step | Focus | Result |
|---|---|---|
| 1 — Document Discovery | Inventory + duplicate resolution | ✅ All 4 doc types present; epics duplicate **resolved** (canonical = top-level) |
| 2 — GDD Analysis | FR/NFR extraction | ✅ **50 FR + 12 NFR** extracted; GDD strong, all phase-blocking Qs resolved |
| 3 — Epic Coverage | FR → story traceability | ✅ **100% coverage (50/50)**; epics add grounded reqs the GDD lacked |
| 4 — UX Alignment | UX ↔ GDD ↔ Architecture | ✅ **STRONG**; arch implements every UX system (D13–D16, NP4–5, ADR-5/6); self-validates ✅ |
| 5 — Epic Quality | Best-practices enforcement | ✅ **0 critical / 1 major (non-blocking) / 6 minor**; exemplary dependency discipline |

### Critical issues requiring immediate action

**None.** No blocker prevents starting `gds-create-story` → `gds-dev-story` on Epic 1.

### Issue roll-up (across all 5 steps)

- **🔴 Critical / blockers: 0**
- **🟠 Major (non-blocking): 1** — Story 8.4 oversized (split when picked up).
- **🟡 Minor / advisory: ~12** — distributed as: 1 doc-cleanup (superseded epics file) · 3 traceability soft-notes (run-length gate, GDD→FR ID map, captor tier-scale) · 1 evidence-fidelity (3 stale-token mocks) · 8 `[ASSUMPTION]` UX defaults to confirm in dev · 6 epic-quality dev-loop items.

### Recommended next steps

**A. Optional pre-implementation tidy (all non-blocking, do any time):**
1. Rename/delete the superseded `gdds/gdd-meridian-run-2026-06-29/epics.md` (7.4 KB) so it can't drift from the canonical top-level `epics.md`.
2. Either refresh the 3 stale-token mocks (`key-build-screens`, `key-title`, `type-specimen-1`) to committed tokens, **or** ensure every UI dev-story spec cites **spine tokens** (`DESIGN.md` frontmatter) as canonical, not mock CSS.

**B. Dev-loop hygiene to apply as stories are generated:**
3. **Split Story 8.4** into 2–3 sub-stories when it's picked up (menus/pause/codex · game-over/summary · settings/accessibility/remap).
4. `gds-create-story` outputs must **inline/hot-link cited UX decisions** and carry the **FR tags + Given/When/Then ACs** verbatim into each standalone `story-X.Y.md`.
5. **Track autoload-registry canonical order** — insert each new autoload (SeedManager, ContentRegistry, SaveManager, AudioManager, GameManager) at its canonical slot, not appended.
6. Add an **early (E1) export smoke-test** on Windows + Linux to catch platform/renderer issues before E8.
7. Add **"full run lands in the 25–45 min feel-band"** as an explicit E4.8 / E8.7 gate criterion (currently emergent, not checked).

**C. Confirm during dev (the 8 OQ9 `[ASSUMPTION]` defaults):** boss/mini-boss HP bar · sacrifice-burst timer ring · modifier chip flash · quit-run hold-to-confirm · sell single-press · unlock/feat toast · **English-only localization for v1.0** (flag so it isn't read as an oversight) · wave-transition banners.

**D. Begin implementation:** `gds-create-story` (Story 1.1 — Project Scaffolding) → `gds-dev-story`. v0.1 target = Epics 1–3, with the **E3 GO/NO-GO hypothesis gate** as the first real verdict.

### Final note

This assessment identified **0 critical and 1 major (non-blocking)** issues, plus ~12 advisory items, across 5 categories — **none of which block implementation**. The planning is unusually thorough for a solo-dev portfolio scope: decision-traceable GDD, an architecture that absorbed and self-validated the UX layer, 100% requirement→story coverage, and a forward-only epic chain with honest gates. Mrdth may address any advisory items to tighten the artifacts, or proceed as-is into the v0.1 dev loop.

---

*Assessment performed by the Implementation Readiness workflow (Game Producer / Scrum Master role). Report file: `_bmad-output/planning-artifacts/implementation-readiness-report-2026-07-01.md`.*

