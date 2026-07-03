---
title: 'Meridian Run — Epic & Story Breakdown'
project: 'meridian-run'
date: '2026-07-01'
author: 'Mrdth'
stepsCompleted: ['step-01', 'step-02', 'step-03', 'step-04']
status: 'complete'
epic_count: 9
story_count: 57
# Core inputs for this breakdown
inputDocuments:
  - _bmad-output/planning-artifacts/gdds/gdd-meridian-run-2026-06-29/gdd.md
  - _bmad-output/planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md
# UX spines (source of truth for all UI surfaces — completed 2026-07-01; was null at breakdown)
uxSpines:
  design: '_bmad-output/planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/DESIGN.md'
  experience: '_bmad-output/planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/EXPERIENCE.md'
  decisionLog: '_bmad-output/planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/.decision-log.md'
scopeNote: 'v0.1 = Epics 1–3 (systems-validation slice + hypothesis gate) · v0.5 = Epic 4 (true alpha) · v1.0 = Epics 5–8 (shipped game) · post-1.0 = Epic 9 (uncommitted, additive). Content breadth (full fleet, specialty pool, modifier roster, formations, feats) deferred to a post-systems brainstorm and represented as placeholder/out-of-scope stories, not enumerated.'
revisionNote: '2026-07-01: in-place UX enrichment (UX spines were null at breakdown). UI stories 1.7 / 3.4 / 3.5 / 8.4 enriched with UX specs (cited by decision-log ID, not restated); added Story 3.9 (Palette-Arc Theming Driver, V3) and Story 7.5 (Unlock & Feat Toast Notifications). Build-ladder naming reconciled to MAIN/WING (UX I2 / arch F-1). Non-diegetic stance (UX D1) + CanvasLayer-never-over-lane (UX F3) added as HUD acceptance criteria. No E1–E9 renumber/reorder.'
---

# Meridian Run - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for **Meridian Run**, decomposing the requirements from the GDD, Architecture, and the now-complete **UX spines** into implementable stories.

**Source of truth:** `gdd.md` (design), `architecture.md` (systems), the UX spines `DESIGN.md` + `EXPERIENCE.md` (UI — **completed 2026-07-01; was `null` when these epics were first written**), and the GDD's high-level `epics.md` (6-epic structure E1–E6). This document expands that structure into full, story-level detail with testable acceptance criteria.

> **UX citation convention.** UI stories reference UX decisions by their **decision-log ID** (e.g. `S1`, `H4`, `A2`, `V3`, `I2`, `M1`) and spine section — they do **not** restate full component specs. Canonical IDs live in `_bmad-output/planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/.decision-log.md`; visual anatomy in `DESIGN.md`, behavior in `EXPERIENCE.md`. **Spines win on conflict with any mock.** The architecture folds these UX systems in as D13–D16 / NP4–NP5 / ADR-5–6.

## Requirements Inventory

### Functional Requirements

> Extracted from `gdd.md` mechanics. Each is a testable gameplay/system behavior. Values marked *(baseline)* are data-tunable starting points, retuned in playtest (per GDD).

**Foundation & Combat Chassis**

- **FR1:** The player ship moves **horizontally only (1-axis)**, locked to the bottom lane of a single fixed screen, and is clamped to the visible play area. No auto-scroll, side-scroll, or vertical player movement is introduced.
- **FR2:** Player movement runs on the fixed-timestep physics loop (`CharacterBody2D` velocity + `move_and_slide()`) at a baseline ~320 px/s *(baseline)*, reading Input Map `Move` actions; analog stick movement applies a deadzone and is continuous (not digital).
- **FR3:** Every player/UI action (Move left/right, Fire, Sacrifice docked ship, Confirm/Back/Pause) is defined as an Input Map action with **both** a keyboard and a gamepad binding; gameplay code never hardcodes keys/scancodes.
- **FR4:** The player fires projectiles **straight up (vertical, 1-axis)** via a `Fire` action; player-ship fire never fires horizontally or in non-vertical directions.
- **FR5:** The base player shot deals 10 damage, fires on a 0.16 s cooldown, and travels at 620 px/s *(baseline)* — all data-tunable.
- **FR6:** Aiming is fixed vertical fire (no twin-stick, no aiming input); hit detection is projectile-based (not hitscan); there is no critical/weak-point system (arcade-flat).
- **FR7:** A docked ship, when present, fires a parallel bullet stream offset +28 px on x, matching the player's fire cadence; earned non-vertical generators (Brotato-style turrets) are a **bounded exception** for coverage (build-axis priority: projectile behavior > on-hit modifiers > generators).

**Life & Health Economy**

- **FR8:** The run tracks **Ships (lives)**, starting at 3, capped at 5; the run ends when ships reach 0.
- **FR9:** Ships enter only from external sources (tier-cap floor, shop/upgrades); the capture/rescue loop is ship-neutral or ship-negative and never grants ships via farming.
- **FR10:** Each ship has **HP** starting at base 3 (growable via build); HP fully heals between every wave (a within-wave resource — run tension lives in ship attrition, not HP attrition).
- **FR11:** Standard fire deals 1 damage; heavy/elite shots deal 2 damage (rare, telegraphed); the player has **1 s i-frames** after each hit.
- **FR12:** On ship loss, the next ship respawns at full HP; capture bypasses HP, costs 1 ship, and respawns at full HP.

**The Gamble — Capture / Rescue / Sacrifice**

- **FR13:** The **Captor (Tractor)** enemy runs a 5-state FSM with GDD timings *(data-tunable)*: enter (~1 s, descends to formation row) → formation (3.5–5.5 s, side-to-side + periodic fire) → telegraph (**0.7 s**, capture column locks to player x) → capture (**0.4 s** active) → dive (**1.6 s**, bezier toward player then off-screen).
- **FR14:** A captor can tractor the player only while **clean** (no docked ship), **once per wave** (special/modifier waves excepted), during the 0.4 s capture window; at most **one docked ship** exists at a time.
- **FR15:** **Rescue:** killing the captor **during its dive** frees a ship that docks to the player. **Failed rescue:** killing the captor **in formation** causes the captured ship to turn enemy ([Ref-11]).
- **FR16:** While **docked**, the player is capture-immune, gains dual-fighter firepower, and has a bigger hitbox ([Risk-12]); while **clean**, the hitbox is small and the gamble is available.
- **FR17:** The rescued ship is one entity with two roles: a **permanent build track** (never lost, even when the docked fighter is sacrificed or absorbed) and a **transient combat fighter** (+firepower, +hitbox, intrinsic first-hit absorber).
- **FR18:** Docked-ship resolution offers one active choice — **Sacrifice** (input) or **Hold** (passive default) — resolving to one of: Sacrifice (−1 ship, burst, build track persists), Keep (reach wave-end alive → flies off, regain 1 ship, net 0), Absorb (hit while holding → docked ship dies first sparing HP, −1 ship), or Failed-rescue (−1 ship, +1 enemy).
- **FR19:** **Sacrifice** consumes the docked ship for a threat-relative temporary buff — triple-shot (±0.18 rad), ×1.5 damage, fast-fire (0.10 s cooldown), ~10 s — that scales with the rescued-ship build track and is bounded against current-wave threat; it **never screen-clears** and needs **no artificial cooldown** (opportunity cost is the limiter, [Build-9]).
- **FR20:** **Safe play** (avoiding capture) yields a safe-play bonus (~30%); courting capture/rescue yields a rescue bonus (~25%); safe-play bonus > rescue bonus (the primary farm-mitigation).
- **FR21:** A captor appears on an **early wave to teach** capture/rescue, then captor-chance **scales with wave number** (gamble stays available without spam).

**Build Engine & Power-ups**

- **FR22:** On wave clear the player is offered **3 power-ups, chooses 1** (take or sell at ~50% value); between waves a **shop offers 4 random** power-ups at a currency cost.
- **FR23:** The build engine maintains a **dual build ladder**: main ship (persistent, run-long core identity) + rescued ship (permanent build track); power-ups target either ladder.
- **FR24:** Effective stats are computed by **recomputing** a `StatBlock` from base + all acquired `Modifier`s at run start and each wave — never by mutating stats in place.
- **FR25:** Power-up synergy is **multiplicative-over-current** (not additive-over-base), targeting ~8–12× wave-1 DPS at the final boss.
- **FR26:** The **standard pool** (fire-rate, shields, damage, move-speed, +HP-cap, +ship) is available to all ships from start; **specialty power-ups** (armor-piercing, tractor-pull, blast-columns…) are gated behind fleet unlocks via cross-pollination.
- **FR27:** Rescued-ship survival grants a currency multiplier and biased odds toward rescue-oriented power-ups; target ~12–15 power-ups acquired by wave 20.
- **FR28:** On **unlocking a ship** (fleet-unlock meta event), its signature mechanic is added as **one entry** to the shared power-up pool, droppable for all ships in subsequent runs (mechanism = v1.0; full depth = post-1.0).

**Run Structure & Procedural Generation**

- **FR29:** A standard run is **20 waves / 4 tiers / 5 waves per tier** (Brotato model); every 5th wave is a tier cap.
- **FR30:** Wave composition is procedurally generated per seed as an **escalating spawn schedule over the wave's fixed duration** [Wave-1][Wave-2]: formation pulses recur every `drip_interval_s`, each spawning `per_tick(wave) = min(per_tick_base + ⌊wave × per_tick_growth⌋, max_per_tick)` enemies — **wave-scaled and hard-capped per tick** (a performance guardrail), **with NO on-screen concurrency cap**. Enemies enter → form → dive → **re-enter and cycle until killed** (Galaga-lineage loop), so pressure escalates as pulses accumulate; the wave ends on a timer, not on clear. Variant mix scales by tier. *(Retires the prior `4+N, cap 12` concurrency cap — see decision-log [Wave-2].)*
- **FR31:** The **same seed produces the same wave layouts, spawns, and modifier selections** (deterministic); player timing varies (not a frame-exact replay).
- **FR32:** All gameplay randomness flows through `SeedManager` **named sub-streams** (wave_composition / modifier_select / enemy_spawn…), each derived from seed + salt; global `randi()`/`randf()` is never used for reproducible behavior.
- **FR33:** `RunGenerator` is **pure**: `(seed, wave, tier, run_flags) → WaveDefinition` (ordered spawns + modifier type + captor presence); authored (fixed) content = wave-20 boss, captor AI, individual enemy stats.

**Modifier Waves, Tiers & Endless**

- **FR34:** **Modifier waves** (waves 5/10/15) are randomly one of: **Swarm** (2× enemies, no captor — raw-DPS test), **Gauntlet** (denser fire-columns, fewer foes — dodge/hitbox test), or **Bounty** (elite enemies, guaranteed power-up drops — build-acceleration). *(v1.0 roster scoped in post-systems brainstorm.)*
- **FR35:** Wave 20 is a **fixed final boss** (the victory gate); beating it lets the player end the run or continue into **endless mode** with the build frozen (no further power-ups) and escalating enemy threat (~+10% enemy HP & fire-density per wave past 20).
- **FR36:** Beating wave 20 unlocks a harder 1–20 tier (**Tier 2** = +30% enemy HP, +elite-chance any wave, denser formations; **Tier 3** = Tier 2 + another step, ~+60% total).
- **FR37:** Tier-cap waves: Tier 1 caps = modifier only; Tier 2+ caps = modifier + mini-boss.

**Meta Progression & Persistence**

- **FR38:** **Permadeath-lite:** the run ends at the last ship and in-run power is lost; the **feat-unlocked fleet** persists across runs. There is **no meta-currency and no between-run shop**.
- **FR39:** Meta unlocks are **feat-based** — three types: progression ("win with A → unlock B"), skill ("no-hit a dive", "rescue at 1 HP"), grind/accumulation ("rescue 50 total") as accessibility safety net — not per-rescue.
- **FR40:** Meta split favors variety over raw power (~80/20 or 90/10); the small raw-power slice **compresses early waves** on future runs, not raises the late-game ceiling.
- **FR41:** The **crown-jewel ship** unlocks via Tier-3 victory or rescue-N grind (N ≈ 500, tuned). Multi-tier loops (Tier 2/3) persist as unlocks.
- **FR42:** The game persists **meta-only** data to `user://` (unlocked ships, feat progress, settings, best stats); **run state is never saved** (quitting abandons the run — no resume); the save schema is versioned for migration.

**Enemies & Arena**

- **FR43:** Enemy types (data-tunable baselines, retuned per tier): Grunt (HP 30, score 100, downward cannon-fodder, fire 1.2–2.4 s, speed 60), Shielder (HP 50, score 150, tougher, fire 0.9–1.8 s, speed 50), Bomber (HP 80, score 300, heavy 2 dmg, fire 1.6–2.8 s, speed 80), Captor (HP 60 +50%/tier, 5-state FSM).
- **FR44:** The arena is a **single fixed screen** with the player locked to the bottom, a 1-axis horizontal lane, vertical fire geometry, no cover and no verticality; power-up drops occur on wave clear and on Bounty modifier waves.
- **FR45:** No screen-clearing weapons exist; large-AoE only when rare/earned/non-repeatable. Multiplayer is out of scope (single-player only).

**UI / HUD, Audio & Juice**

- **FR46:** A **HUD** (on a `CanvasLayer`, subscribing to `EventBus`) displays HP, ships, wave, and score; **power-up select + shop** are data-driven scenes reading `PowerUpDefinition`s; menus (main / pause / game-over) are provided via scene changes; **pause** is supported.
- **FR47:** **Juice/feedback** (hit-flash, screen-shake, pooled particle bursts, neon-vector glow) is arena-scoped (auto-disabled in menus), driven by `EventBus`.
- **FR48:** **Audio** is engine-native (`AudioStreamPlayer` + pooled SFX + buses): synthwave/arcade-electronic music + punchy SFX on hits/pickups/sacrifice bursts; no middleware at v1.0.
- **FR49:** Score is **cumulative and display-only**, separate from currency (score never spends); currency is earned per wave + rescue multiplier and fuels builds.

**Debug Tooling**

- **FR50:** A **debug overlay** (gated by `OS.is_debug_build()`) shows FPS / entity count / pooled-object count / current wave+seed / build summary; visual toggles (hitboxes, capture-column telegraph, formation rows, RNG-stream draws); and cheat hotkeys (spawn captor, force wave, give currency, set seed, invincibility) — critical for fast Epic-3 hypothesis testing.

### NonFunctional Requirements

- **NFR1 (Performance):** Sustain **≥60 FPS** (a floor, not a cap) on target Windows + Linux hardware; worst-case frame budget ≤16.67 ms, measured over a 10-minute combat loop.
- **NFR2 (Motion correctness):** All gameplay motion is **delta-based** and runs on the **fixed-timestep physics loop (60 Hz)** so it behaves identically at 60 or 144+ FPS.
- **NFR3 (Hot-path discipline):** Zero per-frame allocations in `_process`/`_physics_process` — no new Arrays/Dicts/objects, string concatenation, or `Vector2(...)` in tight loops; node refs cached via `@onready`.
- **NFR4 (Pooling):** Projectiles/particles/(hot-path) enemies are **pooled and reused** (`acquire`/`release` + `activate()`/`reset()`); never `instantiate()` + `queue_free()` per frame.
- **NFR5 (Determinism):** Runs are **deterministic**: same seed → same wave layouts, spawns, and modifier selections (not a frame-exact replay).
- **NFR6 (Physics culling):** Strict 2D collision **layers/masks** (`player / enemy / player_projectile / enemy_projectile / pickup`) cull broadphase pairs; simple collision shapes on dynamic bodies.
- **NFR7 (Code quality):** **Static typing** throughout; **no `print()`** in shipped code (logging via the `Log` autoload); **no try/catch** (GDScript has none — use preconditions + `push_error`/`push_warning` + fail-safe defaults).
- **NFR8 (Platform/release):** **Export presets for Windows + Linux**, both verified before release; develop on Linux, verify both.
- **NFR9 (Data paths):** All persistent data through **`user://`** (`OS.get_user_data_dir()`); never write to `res://` or absolute paths.
- **NFR10 (RNG):** All reproducible gameplay randomness uses **seeded `RandomNumberGenerator` sub-streams**, never global `randi()`/`randf()`.
- **NFR11 (Art direction):** Clean geometric **neon-vector** art (Geometry Wars / Resogun / Nova Drift touchstones) favoring **build-crafter reward clarity + 1-axis lane readability**; the **underdog-rescuer** identity governs all visual identity.
- **NFR12 (Audio direction):** **Synthwave / arcade-electronic** with punchy SFX on hits/pickups/sacrifice bursts.
- **NFR13 (Testability):** **Pure logic** (run-gen, build-recompute, stat math) is separated from Node/scene code and is **GUT-unit-testable without instantiating scenes**; tests under `tests/` mirroring the domain layout, named `test_<thing>.gd`.
- **NFR14 (Content extensibility):** Content (ships/power-ups/enemies/formations/modifiers) is **data-driven `.tres`** resources; adding content = adding a `.tres`, zero code.
- **NFR15 (Save integrity):** Saves are **meta-only and schema-versioned** for migration.

### Additional Requirements

> Technical/infrastructure requirements from `architecture.md` that shape epic/story creation. **Starter template:** build on the existing `project.godot` scaffold — **no external starter template** (risk of conflicting conventions). This drives Epic 1 Story 1.

- **AR1 — Project scaffolding (Epic 1 prerequisite):** Register the **11 autoloads in canonical order**: Constants → Log → EventBus → Settings → SeedManager → ContentRegistry → Pool → SaveManager → AudioManager → GameManager → Debug. Autoloads are **thin global services only — no gameplay logic**; delegate logic to pure/testable classes. Install **GUT** under `addons/gut/` + `tests/` mirror; configure Input Map actions (kb+gamepad) + base resolution/stretch (`canvas_items` + `expand`).
- **AR2 — Fixed state ownership:** Ships/currency/score/build-tracks → `RunState`; per-wave HP → `HealthComponent` (reset each wave); docked-ship combat → `DockedShip` node (transient); its build track → `RunState.BuildState` (**permanent — never cleared**). Single clear owners prevent AI-agent conflicts.
- **AR3 — Build engine = recompute (ADR-1):** `StatBlock` (base) + list of `Modifier`/`Behavior` `.tres`, **recomputed** at run start and each wave; never mutate stats in place (drift-proof, pure-logic testable).
- **AR4 — Determinism = seeded sub-streams (ADR-2):** All RNG via `SeedManager` named sub-streams; `RunGenerator` is pure `(seed, wave, tier, run_flags) → WaveDefinition`.
- **AR5 — Composition over inheritance (ADR-4):** Entities built from component nodes (`HealthComponent`, `HitboxComponent`/`HurtboxComponent`, `FactionComponent`, `StateMachine`); strict collision layers.
- **AR6 — Object pooling (D7):** Generic `Pool` autoload; `acquire()`/`release()`; re-init via `activate()`/`reset()` — **never `_ready()`** for pooled nodes.
- **AR7 — Signal boundary (D8):** `EventBus` (global game-flow, typed, **past-tense**) + direct signals (local entity) + explicit injection (testable deps). Don't route everything through the bus; don't cross domains via node paths (`../../X`).
- **AR8 — Content via ContentRegistry (D9):** No scattered `load("res://...")` in gameplay code; content accessed through `ContentRegistry`; cross-pollination = data registration.
- **AR9 — Juice is arena-scoped:** `JuiceCoordinator` lives in the **arena scene** (not an autoload), `EventBus`-driven, **auto-disabled in menus**; particles via `Pool`.
- **AR10 — Config tiers:** immutable constants (`Constants` autoload); balancing values in **`.tres` tuning resources** (the playtest lever, zero code); player settings via `ConfigFile` → `user://` (`Settings` autoload).
- **AR11 — Error handling (no try/catch):** preconditions + `push_error`/`push_warning` + fail-safe defaults; `assert` for dev-only invariants; critical errors **fail-safe to menu, never hard-crash**.
- **AR12 — Logging:** `Log` autoload; format `[LEVEL][system] msg`; editor Output **+ rotating `user://logs/`**; levels ERROR/WARN/INFO/DEBUG.
- **AR13 — Debug tools:** `Debug` autoload gated by `OS.is_debug_build()`; overlay + visual toggles + cheat hotkeys (see FR50).
- **AR14 — Godot 4.6 gotchas to honor:** `move_and_slide()` takes **no args** and applies delta internally (don't multiply velocity by delta); cache `@onready` (no `$`/`get_node()` per frame); pooled nodes re-init via `activate()`/`reset()` not `_ready()`; use `TileMapLayer` for tiles; typed code; no `print()`.
- **AR15 — Optional MCP tooling:** GoPeak (Godot MCP) + Context7 (version-specific docs) — optional AI dev tooling; verify per Godot version.

### UX Design Requirements

> **UX spines completed 2026-07-01** (`ux-designs/ux-meridian-run-2026-06-30/`: `DESIGN.md` visual, `EXPERIENCE.md` behavioral, `.decision-log.md` canonical). They are now the **source of truth for every UI surface**; UI requirements are no longer carried by the GDD alone. GDD-carried UI baselines remain as **FR46** (HUD/select/shop/menus/pause), **FR47** (juice/feedback), and **NFR11** (neon-vector direction); the UX spines refine all three.
>
> **Where the UX requirements live in this breakdown** (cited by decision-log ID, not restated):
> - **Basic HUD** → Story **1.7** (layout H5, on-ship segmented HP H4/H6, timer T1/H3, no in-wave currency H2, shape+outline A2, palette-arc V3, focus/fade S1, CanvasLayer F3, non-diegetic D1).
> - **Power-Up Select** → Story **3.4** (5-state card, MAIN/WING chip I2, family iconography I1, take/sell F7/M1, synergy tooltip, build-summary-rail).
> - **Shop / Rearm** → Story **3.5** (4-card currency screen, currency-readout H2, unaffordable=disabled, shared card idiom + build rail).
> - **Palette-arc theming driver** → Story **3.9** (build_power → calm→climax re-theme, V3; pairs with the build engine).
> - **Unlock/feat toasts** → Story **7.5** (between-wave toast, OQ9).
> - **Full HUD / menus / pause / game-over / settings + accessibility floor** → Story **8.4** (A1 floor, title N3, codex O1, game-over M1 + new-unlock state).
> - **Cross-cutting UX systems** (palette arc D13, accessibility D14, UI map/focus-fade/toasts D15, shape+outline D16) are owned by `architecture.md` (folded in at v1.1); stories reference them, they are not re-specified here.

### FR Coverage Map

> All 50 FRs map to the 9-epic structure (E1–E8 → v1.0; E9 post-1.0). NFRs and ARs are cross-cutting — primary homes noted at the end.

| FR | Epic(s) | Coverage |
|---|---|---|
| FR1 | E1 | 1-axis horizontal movement, screen-clamped |
| FR2 | E1 | Fixed-timestep movement, ~320 px/s, Input Map |
| FR3 | E1 | Input Map actions (kb+gamepad) |
| FR4 | E1 | Vertical fire only |
| FR5 | E1 | Base shot (10 dmg, 0.16 s, 620 px/s) |
| FR6 | E1 | Fixed vertical aim, projectile hit, no crits |
| FR7 | E2 + E3 | Docked stream, hardcoded (E2); generators exception (E3) |
| FR8 | E1 | Ships (3, cap 5), run ends at 0 |
| FR9 | E1 | Ships from external sources only |
| FR10 | E1 | HP (3, full heal/wave) |
| FR11 | E1 | Damage model (1/2 dmg, 1 s i-frames) |
| FR12 | E1 | Respawn full HP; capture bypasses HP (capture flow → E2) |
| FR13 | E2 | Captor 5-state FSM |
| FR14 | E2 | Capture rules (clean, once/wave, one docked) |
| FR15 | E2 | Rescue / failed-rescue |
| FR16 | E2 | Clean/docked tradeoff |
| FR17 | E2 | Rescued-ship dual nature (permanent track + transient fighter) |
| FR18 | E2 | Docked-ship resolution (4 outcomes) |
| FR19 | E2 | Sacrifice burst (threat-relative, no screen-clear) |
| FR20 | E2 | Safe-play vs rescue bonus |
| FR21 | E2 | Captor onboarding cadence |
| FR22 | E3 | 3-choose-1 + shop |
| FR23 | E3 | Dual build ladder |
| FR24 | E3 | Recompute StatBlock |
| FR25 | E3 | Multiplicative synergy (~8–12×) |
| FR26 | E3 + E8 | Standard pool (E3); specialty pool full (E8) |
| FR27 | E3 | Rescued-ship survival bias + target count |
| FR28 | E3 + E8 + E9 | Plumbing (E3); complete+balance (E8); full depth (E9) |
| FR29 | E4 | 20 waves / 4 tiers / 5 waves |
| FR30 | E1 | Wave-composition formula (4+N, cap 12) *(seeded pipeline → E4)* |
| FR31 | E4 | Determinism (same seed → same waves) |
| FR32 | E4 | Seeded sub-streams (SeedManager) *(autoload in E1 scaffolding)* |
| FR33 | E4 | Pure `RunGenerator` |
| FR34 | E5 + E9 | Swarm/Gauntlet/Bounty (E5); more (E9) |
| FR35 | E4 + E6 + E8 | Functional boss (E4); endless (E6); boss polish (E8) |
| FR36 | E6 | Multi-tier loops (Tier 2/3) |
| FR37 | E5 (+E6) | Tier-cap modifier+mini-boss content (E5); fully exercised with multi-tier (E6) |
| FR38 | E4 + E7 | Persist skeleton (E4); full meta (E7) |
| FR39 | E7 | Feat-based unlocks (3 types) |
| FR40 | E7 | Variety > power meta split |
| FR41 | E7 (+E6) | Crown-jewel ship (E7); multi-tier persistence (E6) |
| FR42 | E4 + E7 + E8 | Core save (E4); meta persist (E7); settings/versioning (E8) |
| FR43 | E1 + E2 | Enemy baselines (E1); Captor FSM (E2) |
| FR44 | E1 | Fixed-screen arena; drops |
| FR45 | E1 | Design constraints (no screen-clear, single-player) |
| FR46 | E1 + E3 + E8 | Basic HUD (E1); select/shop (E3); menus/pause/full HUD (E8) |
| FR47 | E1 | Juice/feedback |
| FR48 | E8 | Final audio *(AudioManager autoload in E1; basic SFX hooks in E1)* |
| FR49 | E1 + E3 | Score display (E1); currency economy (E3) |
| FR50 | E1 + E3 | Debug overlay (E1); cheats for hypothesis (E3) |

**NFR / AR cross-cutting homes:** hot-path / pooling / typing / collision (NFR3/4/6/7, AR6/14) → **E1**; determinism / seeded-RNG (NFR5/10, AR4) → **E4**; testability / pure-logic (NFR13, AR3) → **E3** + **E4**; `.tres` extensibility / ContentRegistry (NFR14, AR8/10) → **E3**; exports / perf (NFR1/8) → **E8**; scaffolding / state-ownership / errors / logging / debug (AR1/2/11/12/13) → **E1**, enforced across all epics; data-paths / save-integrity (NFR9/15) → **E4/E7/E8**.

## Epic List

> **Milestones:** v0.1 (systems-validation slice + hypothesis gate) = **E1–E3** · **v0.5** (true alpha — complete game loop) = **E4** · v1.0 (shipped game) = **E5–E8** · post-1.0 = **E9** (uncommitted, additive). **Two honest gates:** E3 (does the build *engine* compound?) → E4 (does the 20-wave *pacing* peak?).

### Epic 1: Combat Chassis & Feel  *(v0.1 — kinesthetics gate)*
**Player outcome:** Fly a ship in a 1-axis fixed-screen lane, fire vertically, fight Grunt/Shielder/Bomber enemies in formation+dive, manage the 3-ships × 3-HP life economy, and feel the neon-vector juice — surviving or dying in a single authored wave. The *kinesthetics* gate (movement/fire/juice feel right); the 1-axis lane-depth verdict deliberately defers to E2.
**FRs covered:** FR1–FR6, FR8–FR12, FR30, FR43, FR44, FR45, FR46 (basic HUD), FR47, FR49, FR50
**Standalone:** ✅ Authored single wave — independent of seeded procgen (E4) and the build engine (E3).
**Depends on:** Project scaffolding (AR1) → folded into Story 1.1.

### Epic 2: The Gamble  *(v0.1)*
**Player outcome:** On a captor wave, face the full risk-reward loop — court capture or play safe; rescue for a docked dual-fighter or sacrifice for a threat-relative burst; manage the clean/docked hitbox tradeoff and the four docked-ship resolutions. This is where the 1-axis lane-depth verdict lands.
**FRs covered:** FR7 (docked stream, hardcoded), FR13–FR21
**Standalone:** ✅ Depends only on E1. **Hardcodes** the docked-ship +firepower/+hitbox (no premature `StatBlock`); the rescued-ship track starts flat — the full build engine to *invest in* it arrives in E3.
**Depends on:** Epic 1.

### Epic 3: Build Engine  *(v0.1 — GO/NO-GO hypothesis gate)*
**Player outcome:** Run a start-to-finish (lean, ~5-wave/1-tier) roguelite — take/sell/shop power-ups across a dual build ladder, compound multiplicative synergies. **"Engine honest, feel approximate":** validates the real recompute engine + synergy math on a compressed, aggressively-scaled run. This is the v0.1 go/no-go gate.
**FRs covered:** FR7 (generators exception), FR22–FR28 (mechanism), FR46 (select/shop UI), FR49 (currency), FR50 (cheats)
**Standalone:** ✅ Builds on E1+E2; delivers a complete compressed run.
**Depends on:** Epics 1, 2.

### Epic 4: Campaign Spine & Seeded Procgen  *(v0.5 — true alpha)*
**Player outcome:** Play a complete, ugly, end-to-end roguelite — start → 20 waves (4 tiers, deterministic seeded variety) → functional wave-20 final boss → win/lose → core persistence. A true alpha you can hand to a friend. **The 20-wave pacing verdict lands here** (does the curve peak?).
**FRs covered:** FR29, FR31–FR33, FR35 (functional boss), FR38 (persist skeleton), FR42 (core meta-save)
**Standalone:** ✅ Depends on E1–E3; full game loop, unpolished. Modifier waves and endless are NOT here (E5/E6).
**Depends on:** Epics 1–3.

### Epic 5: Run Variety  *(v1.0 track)*
**Player outcome:** Each run feels different — modifier waves (Swarm/Gauntlet/Bounty) at waves 5/10/15 and tier-cap mini-bosses (Tier 2+) break up the rhythm with raw-DPS, dodge, and build-acceleration tests.
**FRs covered:** FR34, FR37 (tier-cap modifier+mini-boss content)
**Standalone:** ✅ Depends on E4; bolts variety onto the alpha spine.
**Depends on:** Epic 4.

### Epic 6: Run Depth  *(v1.0 track)*
**Player outcome:** After beating the boss, push endless mode (frozen build vs escalating threat) and climb multi-tier loops (Tier 2, Tier 3) — the **Test pillar** ("how far can skill carry it?").
**FRs covered:** FR35 (endless), FR36 (multi-tier Tier 2/3)
**Standalone:** ✅ Depends on E4 (+ E5 for tier-cap content); the post-victory depth layer.
**Depends on:** Epics 4, 5.

### Epic 7: Meta Progression  *(v1.0 track)*
**Player outcome:** Unlocks persist and reward mastery — the full feat system (progression/skill/grind types, no meta-currency), the variety-over-power meta split, and the crown-jewel ship, all carried by robust meta persistence.
**FRs covered:** FR38 (full meta), FR39, FR40, FR41 (crown-jewel), FR42 (meta persistence)
**Standalone:** ✅ Depends on E4 (core save) + E1–E6; the meta layer.
**Depends on:** Epics 4–6.

### Epic 8: v1.0 Polish & Ship  *(v1.0 — portfolio deliverable)*
**Player outcome:** The shippable v1.0 — specialty power-up pool + expanded fleet via cross-pollination, balanced to the agreed curves, final boss polish, full HUD/menus/pause, settings + save polish, neon-vector/synthwave final pass, verified Windows + Linux exports at ≥60 FPS.
**FRs covered:** FR26 (specialty pool full), FR28 (cross-pollination complete+balance), FR35 (boss polish), FR42 (settings/versioning), FR46 (menus/pause/full HUD), FR48 (final audio), NFR1 (perf), NFR8 (exports) + content-breadth placeholders
**Standalone:** ✅ Depends on E4–E7; the portfolio-ready v1.0.
**Depends on:** Epics 4–7.

### Epic 9: Post-1.0 Growth  *(uncommitted, additive)*
**Player outcome:** Long-tail depth — 20+ ship fleet w/ signature mechanics, full cross-pollination depth (the 50-hour combinatorial engine), endless depth tuning, new modifier waves/captor variety, daily-challenge + shareable seeds + leaderboards — all additive on the live v1.0 base.
**FRs covered:** FR28 (full depth), FR34 (new modifiers), FR39 (expanded feats) + content-breadth deliverables (full roster/formations/specialty pool/feat list) from the post-systems brainstorm
**Standalone:** ✅ Additive only, no core rewrites.
**Depends on:** Epic 8 (v1.0 shipped).

<!-- Epic detail + per-story acceptance criteria are produced in Step 3. Each epic ends in a playable deliverable. Sequence: E1 chassis → E2 gamble → E3 build (v0.1 GO/NO-GO) → E4 spine+procgen (v0.5 alpha) → E5 variety → E6 depth → E7 meta → E8 polish/ship (v1.0) → E9 post-1.0 growth. -->

---

## Epic 1: Combat Chassis & Feel

**Goal:** the 1-axis fixed-screen shooter feels good in Godot — re-derive the prototype's feel in Godot idioms (no port), plus the layered HP/ships economy. Deliverable: a single authored wave you can survive or die in, where movement/fire/juice feel right. *(The lane-depth verdict deliberately defers to E2.)*
**FRs:** FR1–FR6, FR8–FR12, FR30, FR43, FR44, FR45, FR46, FR47, FR49, FR50 · **Milestone:** v0.1 (kinesthetics gate)

### Story 1.1: Project Scaffolding & Core Systems

As the developer (Mrdth),
I want the project scaffolded with the domain folder structure, Input Map, core autoloads, and GUT,
So that every later story builds on a consistent, testable foundation.

**Acceptance Criteria:**

- **Given** the project is opened in Godot 4.6, **When** run, **Then** the game launches into an Arena scene without errors.
- **Given** Project Settings → Autoload, **Then** Constants, Log, EventBus, Settings, Pool, and Debug are registered (canonical positions), each thin (no gameplay logic).
- **Given** the Input Map, **Then** Move(left/right), Fire, Sacrifice, Confirm, Back, Pause each have **both** a keyboard and a gamepad binding; no hardcoded keys/scancodes in code.
- **Given** Display settings, **Then** stretch = `canvas_items`, aspect = `expand`, fixed base resolution.
- **Given** GUT under `addons/gut/`, **When** `godot --headless -s addons/gut/gut_cmdln.gd` runs, **Then** the suite passes (placeholder tests OK).

*(FR3, FR50 · AR1, AR14)*

### Story 1.2: Player Movement (1-Axis Chassis)

As a player,
I want to glide my ship left/right along the bottom lane with responsive, screen-clamped movement,
So that the 1-axis chassis feels tight and fair.

**Acceptance Criteria:**

- **Given** the player in the arena, **When** holding Move left/right, **Then** the ship moves **horizontally only**, clamped to screen edges, at ~320 px/s (from `player_tuning.tres`).
- **Given** movement in `_physics_process`, **When** `move_and_slide()` is called, **Then** velocity is set directly (NOT × delta), and motion is identical at 60 and 144 FPS.
- **Given** a gamepad, **When** the stick is tilted, **Then** movement is continuous with a deadzone; keyboard also works.
- **Given** the player node, **Then** it's a `CharacterBody2D` scene with `@onready`-cached refs, a `HealthComponent`, and a `FactionComponent` (player).

*(FR1, FR2, FR3 · AR5, AR6, AR14)*

### Story 1.3: Vertical Fire System

As a player,
I want to fire projectiles straight up at enemies,
So that I can damage them through readable 1-axis fire-columns.

**Acceptance Criteria:**

- **Given** the player holds Fire, **Then** projectiles spawn **straight up** at 10 dmg / 0.16 s cooldown / 620 px/s (from tuning `.tres`).
- **Given** heavy fire, **When** many projectiles are active, **Then** all come from `Pool.acquire()`/`release()` with `activate()` re-init — never `instantiate()`+`queue_free()` per frame, never `_ready()` re-init.
- **Given** a projectile leaves screen or hits, **Then** it's released back to the pool.
- **Given** the hot path, **Then** zero per-frame allocations (no new arrays/dicts/`Vector2` in `_physics_process`); no `print()`.

*(FR4, FR5, FR6, FR45 · AR6, AR14)*

### Story 1.4: Enemy Types & Formation/Dive AI

As a player,
I want Grunt/Shielder/Bomber enemies to enter in formations and dive,
So that each wave is a readable, escalating threat.

**Acceptance Criteria:**

- **Given** `EnemyDefinition` `.tres` for Grunt/Shielder/Bomber, **When** a wave spawns, **Then** each enemy loads its GDD stats via `ContentRegistry` (no `load("res://...")` in gameplay code).
- **Given** a wave, **When** enemies enter, **Then** they fly to formation rows then execute dive patterns (Galaga-lineage) via the shared state/pattern system, on `enemy`/`enemy_projectile` layers.
- **Given** wave N, **Then** formation pulses recur every `drip_interval_s` across the wave's duration, each spawning `per_tick(N)` enemies (wave-scaled, hard-capped per tick; **no concurrency cap**) — enemies enter → form → dive → re-enter and cycle until killed, so pressure escalates as pulses accumulate (FR30; timer-terminated [Wave-1][Wave-2]).
- **Given** enemies fire, **Then** Grunt/Shielder fire standard (1 dmg) shots; Bomber fires heavy (2 dmg) telegraphed shots.

*(FR30, FR43, FR44, FR45 · AR5, AR6, AR8)*

### Story 1.5: Life & Health Economy

As a player,
I want a clear 3-ships × 3-HP system where HP heals each wave and losing my last ship ends the run,
So that tension lives in ship attrition while each wave stays survivable.

**Acceptance Criteria:**

- **Given** a new run, **Then** the player has 3 ships (cap 5) and base 3 HP; ships are only spent/bet (no farming source in E1).
- **Given** hit by standard fire, **Then** 1 damage; heavy/elite shots deal 2; after any hit, 1 s i-frames.
- **Given** HP reaches 0 in a wave, **Then** the current ship is lost (−1 ship) and the next respawns at full HP.
- **Given** a wave is cleared, **Then** HP fully heals before the next wave.
- **Given** ships reach 0, **Then** the run ends (loss); score is cumulative/display-only.

*(FR8, FR9, FR10, FR11, FR12, FR49 · AR2)*

### Story 1.6: Hit Feedback & Juice

As a player,
I want punchy hit-flash, screen-shake, and neon particle bursts on every impact,
So that combat feels powerful and readable (build-crafter reward clarity).

**Acceptance Criteria:**

- **Given** player or enemy is hit, **Then** hit-flash + screen-shake + pooled particle burst fire, driven by `EventBus` (`hit_flash_requested`/`screen_shake_requested`).
- **Given** the `JuiceCoordinator`, **Then** it lives in the **Arena scene** (not an autoload), auto-disabled outside the arena.
- **Given** particles, **Then** they're pooled (`GPUParticles2D` via Pool), not instantiated/freed per event.
- **Given** audio, **Then** basic SFX play on fire/hit via `AudioManager` (synthwave punch).

*(FR47, FR48 basic · AR9)*

### Story 1.7: Basic HUD (UX-enriched)

As a player,
I want a clean, non-diegetic HUD showing on-ship HP, lives, the wave timer, score, and the active modifier — laid out so it never crosses my 1-axis play lane,
So that I can read my run state at a glance and my combat attention stays on the ship and fire-columns.

**Acceptance Criteria:**

- **Given** the HUD stance is **non-diegetic** (UX D1) on its own **`CanvasLayer` separate from the world tree** (UX F3), **Then** it floats as an arcade overlay and **never obscures the 1-axis play lane** (top band only — `spacing.hud-band`) — this separation is an explicit acceptance criterion.
- **Given** the HUD layout (UX H5), **Then** **lives = ship-icon pips top-left** (`lives-display`), **wave-timer top-center** (`XXs` format, UX T1/H3 — 60 s survive-to-end countdown), and **score top-right** with **wave number + modifier chip beneath it** (`score-readout` + `wave-modifier-readout`). **Tier is dropped** from the in-wave HUD (UX H4 — chosen pre-run).
- **Given** the score readout, **Then** it shows **score only** — **no currency in-wave** (UX H2; `currency` is a shop-stage concept).
- **Given** player HP, **Then** it renders as a **segmented bar above the player ship** (`hp-bar`, UX H4/H6 — primary read, co-located with focus; same segmented idiom reuses on multi-hit/damaged enemies, absent on 1-hit grunts). Ring/halo reserved for future Shield PU, **not** HP.
- **Given** the wave-timer, **Then** at low-time the numeric shifts to `colors.hazard` with a **neutral-white glow halo** (climax: `climax-hazard` amber) (UX T1/A2).
- **Given** the player-vs-hazard read, **Then** the **player family (ship/projectiles/docked-wingman) is silhouette + bright-outline distinct from the hazard family (enemy fire/capture-column)** — shape carries meaning, color reinforces (UX A2; arch D16). Never hue-alone.
- **Given** the palette arc (UX V3; arch D13), **Then** HUD elements subscribe to `EventBus.arc_t_changed` and recolor calm→climax via `modulate` (no `queue_redraw()`). In E1's authored wave `arc_t` stays ~0 (calm Vector Standard); it warms once the Story 3.9 driver emits.
- **Given** combat intensity, **Then** the HUD runs the **focus/fade FSM** (UX S1; reusable `components/state_machine`, arch D15) with pure `HudFocusModel` — score + modifier chrome **dim**, while **timer + on-ship HP + lives stay sharp**. *(v0.1 baseline: FSM + model exist and transition; full per-component saturation tuning + climax integration mature at E8 polish.)*
- **Given** `EventBus` signals (`health_changed`, `ship_lost`, `wave_changed`/`score_changed`, `arc_t_changed`), **When** they fire, **Then** the HUD updates (subscribers cache; no per-frame polling).

*(FR46 basic, FR49 · UX D1/F3/H2/H3/H4/H5/H6/T1/S1/A2/V3 · arch D13/D15/D16)*

### Story 1.8: Authored Wave Assembly & Feel Gate

As a player,
I want to play a complete single wave start-to-finish — move, fire, dodge, kill, survive or die —
So that the chassis feels fun before systems layer on (the v0.1 kinesthetics gate).

**Acceptance Criteria:**

- **Given** the game launches, **Then** a minimal `wave_controller` runs ONE authored wave: spawn (FR30 spawn budget) → active → completed/failed (timer expiry or player death).
- **Given** the wave completes (timer), **Then** HP full-heals and the wave replays for feel-testing.
- **Given** the Debug overlay (`is_debug_build()`-gated), **When** toggled, **Then** it shows FPS, entity count, pooled-object count, current wave; cheat hotkeys (set move-speed, spawn enemy, invincibility) work for tuning.
- **Given** a playtest, **Then** movement/fire/dodge/juice feel responsive and fair at ≥60 FPS — **the formal go-signal for E2**.

*(FR30, FR47, FR50)*

---

## Epic 2: The Gamble

**Goal:** the full capture/rescue/sacrifice risk-reward loop — the P2 engine — playable in a wave. **Where the 1-axis lane-depth verdict lands.** Per design decision, E2 **hardcodes** the docked-ship stats (no premature `StatBlock`); the rescued-ship build track starts flat and is invested in later (E3).
**FRs:** FR7 (docked stream, hardcoded), FR13–FR21 · **Milestone:** v0.1

### Story 2.1: Captor Enemy & 5-State FSM

As a player,
I want a tractor-beam enemy with a readable attack sequence,
So that capture is a fair, telegraphed gamble I can dodge.

**Acceptance Criteria:**

- **Given** a captor spawns, **When** it enters, **Then** it descends to a formation row (~1 s).
- **Given** formation phase, **Then** it moves side-to-side + fires periodically (3.5–5.5 s).
- **Given** telegraph, **Then** the capture column **locks to the player's x** for 0.7 s (the fair dodge window).
- **Given** capture window, **Then** 0.4 s of active tractor; **given** dive, **Then** 1.6 s bezier toward the player then off-screen.
- **Given** timings, **Then** all read from `captor_tuning.tres` (data, not code).

*(FR13)*

### Story 2.2: Capture Mechanic (Clean-Only, Once/Wave)

As a player,
I want capture to be a deliberate risk — only when I'm clean and exposed,
So that docking a ship meaningfully trades safety for firepower.

**Acceptance Criteria:**

- **Given** the player is **clean** (no docked ship) and inside the locked capture column during the 0.4 s window, **When** the captor tractors, **Then** the player is captured (−1 ship), bypassing HP, and respawns at full HP.
- **Given** the player has a docked ship, **Then** capture is impossible (capture-immune).
- **Given** a capture already occurred this wave, **Then** no further capture (once per wave).
- **Given** at most one docked ship, **Then** a second capture/rescue/dock cannot occur.

*(FR14, FR12 capture-bypass, FR16 immunity)*

### Story 2.3: Rescue & Failed Rescue

As a player,
I want my timing on killing the captor to matter,
So that a clean dive-kill rescues a ship but a lazy formation-kill turns it against me.

**Acceptance Criteria:**

- **Given** the captor is in **dive** state, **When** killed, **Then** a freed ship docks to the player.
- **Given** the captor is in **formation** state, **When** killed, **Then** the captured ship turns into an enemy (−1 ship, +1 enemy) — [Ref-11].
- **Given** rescue, **Then** the docked fighter attaches with its hardcoded combat presence (+firepower, +hitbox, intrinsic absorber).

*(FR15)*

### Story 2.4: Docked Ship — Dual Nature (NP1) & Clean/Docked Tradeoff

As a player,
I want the docked ship to be a real dual-fighter with a cost (bigger hitbox) and a permanent identity,
So that docking is a meaningful, lasting build choice — not a throwaway buff.

**Acceptance Criteria:**

- **Given** a docked ship attaches, **Then** the player gains a parallel bullet stream (+28 px x-offset, **hardcoded**) and a **bigger hitbox** ([Risk-12]), and becomes capture-immune.
- **Given** the rescued-ship track, **Then** it persists in `RunState.BuildState` (permanent) even when the docked fighter is consumed — **the consume path never clears the track**.
- **Given** the docked fighter, **Then** it's the transient combat presence (wave scope) + intrinsic first-hit absorber.

*(FR7 docked-stream, FR16, FR17)*

### Story 2.5: Docked-Ship Resolution (Four Outcomes)

As a player,
I want a clear choice each wave — sacrifice now or hold — with legible resolutions,
So that the hold-vs-cash micro-tension is real.

**Acceptance Criteria:**

- **Given** a docked ship + the player presses **Sacrifice**, **Then** the fighter is consumed → sacrifice burst fires, −1 ship, track persists.
- **Given** a docked ship **held to wave-end alive**, **Then** it flies off → regain 1 ship (net 0).
- **Given** a docked ship + the player is **hit while holding**, **Then** the fighter dies first (absorb), sparing HP, −1 ship.
- **Given** all four outcomes (sacrifice / keep / absorb / failed-rescue), **Then** each is reachable and resolves correctly.

*(FR18)*

### Story 2.6: Sacrifice Burst (Threat-Relative, NP3)

As a player,
I want sacrifice to grant a tide-turning power surge that scales with my investment but never trivializes the wave,
So that it's always worth considering and never a win button.

**Acceptance Criteria:**

- **Given** sacrifice triggers, **Then** a temporary buff applies: triple-shot (±0.18 rad), ×1.5 damage, fast-fire (0.10 s cooldown), ~10 s.
- **Given** the burst, **Then** it scales with rescued-ship track investment but is **clamped to current-wave threat** (`threat_ceiling` pure logic, GUT-tested) — always useful, never an insta-win.
- **Given** the burst, **Then** it does **not** screen-clear (no large AoE).
- **Given** sacrifice, **Then** there is **no artificial cooldown** — opportunity cost (forgoes keep→regain + spends a ship) is the limiter.

*(FR19)*

### Story 2.7: Safe-Play vs Rescue Bonus Economy

As a player,
I want playing safe to pay slightly more currency while capture/rescue pays in ship benefits,
So that the gamble is a genuine tradeoff, not a solved optimum.

**Acceptance Criteria:**

- **Given** the player avoids capture all wave (safe play), **Then** wave-clear grants a **safe-play bonus (~30%)**.
- **Given** the player courts capture / rescues, **Then** wave-clear grants a **rescue bonus (~25%)**.
- **Given** the two, **Then** safe-play bonus > rescue bonus (the primary farm-mitigation).
- **Given** bonus values, **Then** they read from `economy_tuning.tres`.

*(FR20)*

### Story 2.8: Captor Wave Integration & Gamble Gate

As a player,
I want captors to appear early to teach the loop, then scale in frequency,
So that the gamble stays available without spamming every wave.

**Acceptance Criteria:**

- **Given** an early wave, **Then** a captor appears to **teach** capture/rescue.
- **Given** wave number increases, **Then** captor-chance scales with wave (gamble stays available, not spammy).
- **Given** a captor wave, **Then** the full gamble — court capture, rescue-or-sacrifice, or play safe — is a real, legible decision (**the gamble gate**).

*(FR21)*

---

## Epic 3: Build Engine

**Goal:** validate the **unvalidated** hypothesis — that the new build + gamble systems produce the godhood feel. **"Engine honest, feel approximate":** the real recompute engine + synergy math on a compressed, aggressively-scaled ~5-wave run. *Pass = the math compounds measurably AND a playtester feels the peak → greenlight E4+. Fail = stop and redesign before the long v1.0 climb.*
**FRs:** FR7 (generators), FR22–FR28 (mechanism), FR46 (select/shop UI), FR49 (currency), FR50 · **Milestone:** v0.1 (GO/NO-GO gate)

### Story 3.1: StatBlock & Build Recompute Engine (the heart)

As a developer,
I want a drift-proof, fully-testable stat engine,
So that compound multiplicative builds can reach ~8–12× DPS without ever drifting.

**Acceptance Criteria:**

- **Given** a `StatBlock` (base) + a list of `Modifier` `.tres`, **When** `BuildRecompute` runs, **Then** it produces the effective `StatBlock` (base + Σ modifiers) **recomputed from scratch** (never mutated in place).
- **Given** `MULT` modifiers, **Then** synergy is **multiplicative-over-current** (not additive-over-base).
- **Given** recompute, **Then** it's **pure logic**, GUT-tested (assert recomputation from a modifier list, incl. MULT compounding toward ~8–12×).
- **Given** the pipeline, **Then** it runs at run start and each wave.

*(FR24, FR25 · AR3)*

### Story 3.2: Power-Up Definitions & Standard Pool

As a player,
I want a baseline set of power-ups available from the start,
So that every run has a common build vocabulary before unlocks expand it.

**Acceptance Criteria:**

- **Given** the `PowerUpDefinition` schema, **Then** each `.tres` holds its `Modifier` list + optional `Behavior` refs + cost/value + pool tier + `target_ladder` (**MAIN|WING** — UX I2; arch D15/F-1) + `rarity {COMMON,RARE}` + `icon_family {PROJECTILE,ON_HIT,GENERATOR}` (UX I1 — drives the card's chip/pip/sigil; arch D15).
- **Given** the standard pool, **Then** fire-rate / shields / damage / move-speed / +HP-cap / +ship exist as `.tres`, available to all ships from start.
- **Given** content, **Then** it's accessed via `ContentRegistry` (add a `.tres` = new power-up, zero code).

*(FR26 standard pool · AR8)*

### Story 3.3: Dual Build Ladder

As a player,
I want to invest in both my main ship and my rescued-ship track,
So that the gamble's permanent track actually grows and feeds my sacrifice.

**Acceptance Criteria:**

- **Given** `BuildState`, **Then** it holds the **MAIN track** (primary-weapon ladder, persistent, run-long) + the **WING track** (allied/rescue ladder, permanent, from E2 NP1 — now investable). *(Naming reconciled `main|rescued` → **MAIN|WING** per UX I2 / arch F-1 — no game code yet, rename is free.)*
- **Given** a power-up with `target_ladder`, **When** acquired, **Then** it applies to the correct track (**MAIN or WING**).
- **Given** both tracks, **Then** `BuildRecompute` produces the player's effective stats from both — and `BuildRecompute.build_power()` summarizes build strength (feeds the Story 3.9 palette arc, arch D13).
- **Given** the WING track, **Then** investing in it now **scales sacrifice beyond E2's flat baseline** (FR19 functional).

*(FR23, FR17)*

### Story 3.4: Wave-Clear Reward — Take-or-Sell (3 choose 1) (UX-enriched)

As a player,
I want to pick from three offered power-ups after each wave over a paused arena, taking or selling,
So that every clear is a legible build decision.

**Acceptance Criteria:**

- **Given** wave clear, **Then** a `panel-scrim` pauses + dims the arena and **3 `power-up-card`s** surface (data-driven from `PowerUpDefinition`s; UX F7), with the `build-summary-rail` docked at the bottom showing the current MAIN/WING stack (UX H4 — calm moment).
- **Given** a card, **Then** it renders the 5-state `power-up-card` idiom (UX `power-up-card` / EXPERIENCE State Patterns): `default · focus · selected/rare · disabled`, with gamepad **focus independent of rarity**; a **rare** card repaints wholesale to Polybius Dusk (UX I1).
- **Given** a card, **Then** it shows a **`main-wing-chip`** (MAIN or WING target — UX I2; **text label required, never color-alone**), family **iconography/sigil** (projectile/on-hit/generator — UX I1), and a shape-coded **`rarity-pip`** (hollow square vs filled diamond — UX I1).
- **Given** the focused card, **Then** a one-line **`synergy-tooltip`** describes how it stacks with the current build (pointer-events none).
- **Given** an offered card, **Then** the player can **TAKE** (`confirm`) — applies to its target ladder — or **SELL** (dedicated secondary key) for **~50% value → currency** (UX F7). **Sell is quick, single-press, no confirm** (low-stakes, reversible-ish — explicitly *not* hold-to-commit; UX OQ9 / arch NP5).
- **Given** the microcopy, **Then** power-up names + labels read in the **punchy Llamasoft register** (UX M1 — e.g. `TRIPLE BROADSIDE`, not "Triple Fire").
- **Given** the screen, **Then** it is non-diegetic overlay UI on a CanvasLayer (UX D1), gamepad-navigable with mouse-hover = focus (UX F5).

*(FR22, FR46 select UI · UX D1/F5/F7/H4/I1/I2/M1/OQ9 · arch D15/NP5)*

### Story 3.5: Between-Wave Shop / Rearm (UX-enriched)

As a player,
I want a shop between waves offering random power-ups for currency,
So that I can spend my earnings to steer my build.

**Acceptance Criteria:**

- **Given** between waves (after Power-Up-Select), **Then** the shop offers **4 random power-ups at a currency cost** (UX F7), over the same `panel-scrim`-paused arena, reusing the `power-up-card` idiom (denser ~16 px gutter) + `build-summary-rail` (UX H4).
- **Given** currency, **Then** a **`currency-readout`** shows CHIPS (**shop-stage only — never in the in-wave HUD**, UX H2). Currency = wave score converted at the shop (earned per wave + rescue/safe bonuses).
- **Given** an unaffordable card, **Then** it renders **`disabled`** (50% opacity / saturation .35; `take-button` flat + dashed) and cannot be bought (UX `power-up-card` disabled state).
- **Given** a BUY (`confirm`), **Then** the power-up applies to its MAIN/WING ladder and the spend updates `RunState`. The shop has **no sell** (select-only); the player `back`s out to advance.
- **Given** the shop UI, **Then** it's a data-driven scene reading `PowerUpDefinition`s, non-diegetic overlay on a CanvasLayer (UX D1), gamepad-navigable (UX F5).

*(FR22 shop, FR49, FR46 shop UI · UX D1/F5/F7/H2 · arch D15)*

### Story 3.6: Cross-Pollination Plumbing (mechanism)

As a player who unlocks a new ship,
I want its signature mechanic to enter the shared power-up pool for all my ships,
So that the fleet grows the build space for everyone.

**Acceptance Criteria:**

- **Given** a ship with a signature mechanic, **When** unlocked (fleet-unlock meta event), **Then** its signature is added as **one entry** to the shared pool for all ships.
- **Given** `build_shared_pool`, **Then** it's additive (standard + unlocked signatures), weighted; unlock flag → pool rebuilds, **zero per-ship code**.
- **Given** v1.0 scope, **Then** the mechanism works; full depth (synergies, specialty gating) is post-1.0.

*(FR28 mechanism · AR8, NP2)*

### Story 3.7: Earned Generators (bounded exception)

As a player,
I want to occasionally earn a non-vertical turret for coverage,
So that builds can patch blind spots without abandoning the 1-axis fire identity.

**Acceptance Criteria:**

- **Given** an earned generator power-up, **When** acquired, **Then** it spawns a non-vertical turret for bounded coverage.
- **Given** player-ship fire, **Then** it stays **strictly 1-axis** (generators are the only non-vertical exception).
- **Given** the build-axis priority, **Then** projectile behaviors apply before on-hit modifiers before generators.

*(FR7 generators)*

### Story 3.8: Compressed Run & Godhood Hypothesis Gate

As a player,
I want a short but escalating run that demonstrably hits a power peak,
So that the build fantasy is proven before building the full 20-wave campaign.

**Acceptance Criteria:**

- **Given** a compressed ~5-wave / 1-tier run, **Then** the build compounds across waves via take/sell/shop + dual ladder.
- **Given** aggressive scaling, **Then** the run **approximates** a felt godhood peak (~8–12× wave-1 DPS target) despite compression.
- **Given** the target ~12–15 power-ups by run end, **Then** the acquisition rate supports it in the compressed run.
- **Given** the **hypothesis gate**, **Then** (a) the engine demonstrably compounds (measurable, GUT-backed) **AND** (b) a playtester reports a felt power peak — **the GO/NO-GO signal for E4+**. Debug cheats (give power-up, set currency, force wave) support fast iteration.

*(FR25 target, FR27, FR50)*

### Story 3.9: Palette-Arc Theming Driver (V3)

As a player,
I want the arena to warm from calm cyan toward climax magenta as my build compounds,
So that "becoming overpowered" is *felt* — the palette itself is the godhood-peak juice channel.

**Acceptance Criteria:**

- **Given** the arena scene, **Then** an arena-scoped **`PaletteArcCoordinator`** (in `juice/`, **not** an autoload — twin to `JuiceCoordinator`) listens to `EventBus.build_changed`/`run_started`, reads build power, and broadcasts a single derived `EventBus.arc_t_changed(t: float)` (UX V3; arch D13/ADR-5/NP4).
- **Given** pure logic, **Then** `BuildRecompute.build_power(state)` and `PaletteArc.arc_t(power, curve)` are **pure + GUT-tested** (steep late ramp → godhood reads as earned).
- **Given** color termini, **Then** a `ThemeTokens` resource (`resources/themes/theme_tokens.tres`) holds the calm↔climax pair per token from `DESIGN.md` and exposes `lerp_token(token, t)`.
- **Given** a build change, **Then** `arc_t` is **smoothed toward target** (tween — warming is felt, not snapped); consumers subscribe once, cache `t`, apply via `modulate`/`self_modulate` (**no `queue_redraw()`, no per-frame polling**).
- **Given** the v0.1 minimal consumer set, **Then** arena background (`surface→climax-surface`), HUD primary recolor (Story 1.7), and `JuiceCoordinator` intensity crank respond to `arc_t`.
- **Given** menus, **Then** **no coordinator ⇒ no warming** (menus stay calm Vector Standard; arch D13/ADR-5).
- **Given** the godhood peak, **Then** the warming is part of the Story 3.8 felt-peak signal (the arena warming to Polybius Dusk as the build compounds).

*(UX V3/G1 · arch D13/D14/ADR-5/NP4 · DESIGN.md Colors → Climax overrides)*

> **Sequencing note (flagged):** this driver's input — `build_power` — does not exist until the build engine (this epic), so it lands in **E3** (v0.1), not E1. The theme-token spine + pure `arc_t` logic may scaffold earlier if desired, but the working driver pairs with the build engine here. Per-token interpolation across all 24 components matures through HUD polish (E8); the spine + minimal consumers are v0.1.

---

## Epic 4: Campaign Spine & Seeded Procgen

**Goal:** ship a complete, ugly, end-to-end roguelite a friend can play — start → 20 seeded waves → functional boss → win/lose → persistence. **Real `RunGenerator`** (not hand-authored waves). **The 20-wave pacing verdict lands here** — does the curve actually peak at the boss?
**FRs:** FR29, FR31–FR33, FR35 (functional boss), FR38 (persist skeleton), FR42 (core meta-save) · **Milestone:** v0.5 (true alpha)

### Story 4.1: SeedManager & Named Sub-Streams

As a developer,
I want all gameplay RNG to flow through isolated seeded sub-streams,
So that runs are reproducible and one generator's changes don't cascade into another's.

**Acceptance Criteria:**

- **Given** a run seed, **Then** `SeedManager` derives named sub-streams (`wave_composition`, `modifier_select`, `enemy_spawn`, …), each from seed + salt.
- **Given** the same seed, **Then** each sub-stream produces identical sequences (deterministic).
- **Given** reproducible randomness, **Then** it flows **only** through `SeedManager` — never global `randi()`/`randf()`.
- **Given** sub-stream isolation, **Then** changing one generator's logic doesn't shift another's RNG.

*(FR32 · AR4, NFR5/10)*

### Story 4.2: Pure RunGenerator (seed, wave, tier → WaveDefinition)

As a developer,
I want a pure, testable wave generator,
So that any wave is reproducible from its inputs without running the scene tree.

**Acceptance Criteria:**

- **Given** `(seed, wave, tier, run_flags)`, **Then** `RunGenerator` produces a deterministic `WaveDefinition` — a **spawn schedule**: formation pulses (composition + entry-timing + dive-pattern + captor-presence) distributed across the wave's fixed duration [Wave-1] — plus modifier type.
- **Given** the same inputs, **Then** the `WaveDefinition` is identical (reproducible runs).
- **Given** authored content, **Then** boss / captor-AI / enemy-stats are **referenced by id** (not generated) — authored/procedural split honored.
- **Given** `RunGenerator`, **Then** it's pure logic, GUT-tested.

*(FR33, FR31 · AR4)*

### Story 4.3: 20-Wave / 4-Tier Campaign Structure

As a player,
I want a full campaign with rising tier stakes,
So that the run has a real arc from warm-up to climax.

**Acceptance Criteria:**

- **Given** a campaign, **Then** it's 20 waves / 4 tiers / 5 waves per tier (Brotato model).
- **Given** every 5th wave, **Then** it's a tier cap (modifier at Tier 1; Tier 2+ mini-boss deferred to E5/E6).
- **Given** the run/wave lifecycle FSM, **Then** waves flow `wave_intro → active → completed → reward → next_wave` (a wave ends on **timer expiry** [Wave-1], not on enemy clear).
- **Given** wave 20, **Then** it's the final-boss gate (victory condition).

*(FR29)*

### Story 4.4: Wave Controller — Procedural Spawning

As a player,
I want each wave to be procedurally composed from the seed,
So that runs vary and replay stays fresh (replacing E1's authored single wave).

**Acceptance Criteria:**

- **Given** the `wave_controller`, **Then** it spawns each wave from the `RunGenerator`'s `WaveDefinition` (real procgen, not the E1 authored wave) and **ends the wave on timer expiry** [Wave-1] (not on enemy clear).
- **Given** a regular wave, **Then** it spawns the composition as formation pulses (4+N, cap 12 spawn budget, variant mix by tier) across the duration via the `enemy_spawn` sub-stream.
- **Given** a captor wave, **Then** a captor spawns (captor presence from `WaveDefinition`) — the gamble is available across the campaign.
- **Given** the campaign, **Then** 20 distinct seeded waves play through.

*(FR29, FR31, FR30 real pipeline)*

### Story 4.5: Functional Final Boss

As a player,
I want a real final-boss fight at wave 20,
So that the campaign has a climactic victory gate (not a placeholder).

**Acceptance Criteria:**

- **Given** wave 20, **Then** the final boss spawns (authored fight, **functional**).
- **Given** the boss is defeated, **Then** the run is won (victory) — the campaign victory gate.
- **Given** victory, **Then** the player can end the run (endless-continuation hook reserved for E6).
- **Given** boss defeat, **Then** it's a real fight (unpolished — polish in E8).

*(FR35 functional boss)*

### Story 4.6: Run State & Core Meta-Save

As a player,
I want my unlocks and best stats to survive between runs (but not a half-finished run),
So that meta progress accrues while permadeath stays clean.

**Acceptance Criteria:**

- **Given** a run ends (win or loss), **Then** meta persists to `user://` (unlocked-ships skeleton, feat-progress skeleton, best stats).
- **Given** run state, **Then** it's **in-memory only** — quitting abandons the run (no resume) — D5.
- **Given** the save schema, **Then** it's **versioned** for migration.
- **Given** saves, **Then** all data goes through `user://` (never `res://` or absolute paths).

*(FR38 persist skeleton, FR42 core save · D5, NFR9/15)*

### Story 4.7: Game-Mode FSM & Scene Flow

As a player,
I want to start, finish, and restart runs from a menu,
So that the alpha is a complete loop I can hand to someone.

**Acceptance Criteria:**

- **Given** the `GameManager`, **Then** it runs the game-mode FSM (`menu → run → gameover`).
- **Given** a run ends, **Then** the player returns to menu / can start a new seeded run.
- **Given** the flow, **Then** a complete alpha loop is playable: menu → 20-wave run → boss → win/lose → persist → menu.
- **Given** pause, **Then** a basic pause works (full pause menu in E8).

*(FR38 lifecycle)*

### Story 4.8: v0.5 Alpha Assembly & Pacing Gate

As a player/tester,
I want to play a complete start-to-boss run,
So that the 20-wave pacing curve can be judged — does power actually peak at the boss?

**Acceptance Criteria:**

- **Given** the assembled alpha, **Then** a player plays a complete run: start → 20 seeded waves → boss → win/lose → persist.
- **Given** the **pacing verdict**, **Then** the 20-wave compounding curve is evaluated: does power peak at the boss (not coast, not trivialize)? — **the second gate**.
- **Given** determinism, **Then** a seed is shareable/reproducible for testing.
- **Given** debug, **Then** set-seed / force-wave cheats support pacing tuning.

*(FR29, FR31–33 integration, FR50)*

---

## Epic 5: Run Variety

**Goal:** each run feels different — modifier waves (Swarm/Gauntlet/Bounty) at waves 5/10/15 and tier-cap mini-bosses (Tier 2+) break up the rhythm with raw-DPS, dodge, and build-acceleration tests. Bolts variety onto the E4 alpha spine.
**FRs:** FR34 (modifier waves), FR37 (tier-cap modifier+mini-boss) · **Milestone:** v1.0 track

### Story 5.1: Modifier Wave Framework & Selection

As a developer,
I want a data-driven modifier-wave system the generator selects deterministically,
So that variety waves appear at the right cadence without code changes per type.

**Acceptance Criteria:**

- **Given** the `ModifierWaveDefinition` schema, **Then** each modifier type is a `.tres` (data-driven).
- **Given** waves 5/10/15, **Then** `RunGenerator` selects one modifier type via the `modifier_select` sub-stream (deterministic).
- **Given** a modifier wave, **Then** it replaces/augments the regular wave composition.
- **Given** content, **Then** adding a modifier type = adding a `.tres` (zero code).

*(FR34 framework)*

### Story 5.2: Swarm, Gauntlet & Bounty Modifiers

As a player,
I want three distinct modifier-wave flavors,
So that the campaign tests different skills (DPS, dodge, build).

**Acceptance Criteria:**

- **Given** a **Swarm** wave, **Then** it spawns 2× enemies, no captor (raw-DPS test).
- **Given** a **Gauntlet** wave, **Then** it spawns denser fire-columns with fewer foes (dodge/hitbox test).
- **Given** a **Bounty** wave, **Then** it spawns elite enemies with guaranteed power-up drops (build-acceleration).
- **Given** each type, **Then** it's selectable at modifier waves via the sub-stream and integrates with the E3 reward flow.

*(FR34 types, FR44 drops)*

### Story 5.3: Tier-Cap Mini-Bosses (Tier 2+)

As a player,
I want higher tiers to gate with a mini-boss on top of the modifier,
So that tier progression feels like a real escalation.

**Acceptance Criteria:**

- **Given** a Tier 1 tier-cap wave, **Then** it's **modifier only** (no mini-boss).
- **Given** a Tier 2+ tier-cap wave, **Then** it's **modifier + mini-boss**.
- **Given** the mini-boss, **Then** it's a tougher authored fight gating the tier (referenced by id).
- **Given** tier-cap content, **Then** it's data-driven.

*(FR37)*

### Story 5.4: Run Variety Integration & Gate

As a player,
I want modifier waves and mini-bosses to show up across the campaign,
So that runs feel varied run-to-run.

**Acceptance Criteria:**

- **Given** a full campaign, **Then** modifier waves appear at 5/10/15 and Tier 2+ caps add mini-bosses.
- **Given** different seeds, **Then** the modifier-type selections vary run-to-run (replay variety).
- **Given** a playtest, **Then** variety waves are readable and don't break the pacing curve (variety gate).

*(FR34, FR37 integration)*

---

## Epic 6: Run Depth

**Goal:** after beating the boss, push endless mode (frozen build vs escalating threat) and climb multi-tier loops (Tier 2, Tier 3). **The Test pillar** — "how far can skill carry the greed you built?"
**FRs:** FR35 (endless), FR36 (multi-tier Tier 2/3) · **Milestone:** v1.0 track

### Story 6.1: Endless Mode (Frozen Build, Escalating Threat)

As a player,
I want to keep playing past the boss with my build frozen against rising threat,
So that mastery — not more power — is what's tested (the Ascender phase).

**Acceptance Criteria:**

- **Given** boss victory, **Then** the player can continue into endless mode with the **build frozen** (no further power-ups).
- **Given** endless waves past 20, **Then** enemy threat escalates (~+10% enemy HP & fire-density per wave, data-tunable).
- **Given** the frozen build, **Then** there's no growth — pure skill vs escalating threat.
- **Given** endless, **Then** it ends when ships reach 0 (the Test pillar: how far can skill carry it?).

*(FR35 endless)*

### Story 6.2: Multi-Tier Loops (Tier 2, Tier 3)

As a player who's beaten the campaign,
I want harder 1–20 loops to climb,
So that mastery has a longer ladder (Brotato danger-levels / Hades heat).

**Acceptance Criteria:**

- **Given** beating wave 20, **Then** Tier 2 unlocks (a harder 1–20 loop).
- **Given** Tier 2, **Then** +30% enemy HP, +elite-chance any wave, denser formations.
- **Given** Tier 3 (Tier 2 + another step), **Then** ~+60% total enemy threat.
- **Given** multi-tier, **Then** tier selection persists as a meta-unlock (full persistence plumbing in E7).

*(FR36)*

### Story 6.3: Run Depth Integration & Test-Pillar Gate

As a player,
I want endless and multi-tier to flow naturally from victory,
So that the post-campaign depth is a real, engaging endgame.

**Acceptance Criteria:**

- **Given** endless + multi-tier, **Then** both are reachable from the post-victory flow.
- **Given** the **Test pillar**, **Then** a playtest confirms skill-vs-escalating-threat is engaging (Test gate).
- **Given** scaling, **Then** all values are data-tunable (`.tres` — the playtest lever).

*(FR35, FR36 integration)*

---

## Epic 7: Meta Progression

**Goal:** unlocks persist and reward mastery — the full feat system (no meta-currency), the variety-over-power meta split, and the crown-jewel ship, all carried by robust meta persistence.
**FRs:** FR38 (full meta), FR39, FR40, FR41, FR42 (meta persist) · **Milestone:** v1.0 track

### Story 7.1: Feat System (Three Types)

As a player,
I want unlocks driven by feats (progression, skill, grind) — not a shop,
So that the fleet is earned through play, not grind-currency.

**Acceptance Criteria:**

- **Given** a feat definition (data-driven), **Then** it tracks its condition (progression / skill / grind).
- **Given** a **progression** feat ("win with A → unlock B"), **Then** completing it unlocks B.
- **Given** a **skill** feat ("no-hit a dive", "rescue at 1 HP"), **Then** meeting the condition triggers it.
- **Given** a **grind** feat ("rescue 50 total"), **Then** accumulation counts toward it (accessibility safety net).
- **Given** an unlock, **Then** it fires cross-pollination (E3) / a fleet unlock.

*(FR39)*

### Story 7.2: Variety-over-Power Meta Split

As a returning player,
I want unlocks to mostly add *variety* (new playstyles) and only lightly compress early waves,
So that the meta rewards breadth without raising the ceiling or forcing grind.

**Acceptance Criteria:**

- **Given** meta unlocks, **Then** ~80/20 (or 90/10) are **variety** (new ships/playstyles) vs raw power.
- **Given** the raw-power slice, **Then** it **compresses early waves** on future runs (skip mastered content), not raise the late-game ceiling (Hades pattern).
- **Given** the meta model, **Then** there is **no meta-currency and no between-run shop**.
- **Given** unlocks, **Then** they're skill/feat-driven (grind only as accessibility fallback).

*(FR40, FR38 no-meta-currency)*

### Story 7.3: Crown-Jewel Ship Unlock

As a mastery player,
I want a prestigious top-tier ship unlockable by skill (Tier 3) or persistence (rescue-N),
So that the top of the fleet is reachable by different player types.

**Acceptance Criteria:**

- **Given** **Tier-3 victory**, **Then** the crown-jewel ship unlocks (prestige/skill path).
- **Given** **rescue-N grind** (N ≈ 500, tuned to comparable effort), **Then** the crown-jewel ship unlocks (accessibility path).
- **Given** the crown-jewel, **Then** it's the top-tier fleet unlock.

*(FR41)*

### Story 7.4: Robust Meta Persistence

As a player,
I want my unlocks and progress to reliably survive between sessions,
So that nothing I earned is lost to a bad save.

**Acceptance Criteria:**

- **Given** meta state (unlocks / feats / best stats / multi-tier), **Then** it persists fully to `user://` across runs.
- **Given** a save from an older schema version, **Then** it **migrates** correctly (versioned schema).
- **Given** a corrupt/missing save, **Then** it **fail-safes to defaults** (never hard-crashes) — AR11.
- **Given** persistence, **Then** it extends the E4 core save (not replaces it).

*(FR42 meta persist, FR38 full meta · AR11)*

### Story 7.5: Unlock & Feat Toast Notifications (UX OQ9)

As a player,
I want new unlocks and feats surfaced as a clean between-wave toast — never mid-wave,
So that progression rewards land without breaking combat focus.

**Acceptance Criteria:**

- **Given** a feat unlock or ship-unlock discovery, **Then** a `toast_manager` (in the HUD CanvasLayer) listens for `EventBus.feat_unlocked`/`unlock_discovered`, **queues** notifications, and shows them **only in calm moments** (between waves / game-over summary) — **never mid-wave** (UX OQ9/S1; arch D15).
- **Given** the `toast` primitive (UX `toast` component), **Then** it renders title (`display-sm`) + body (`body-sm`), auto-dismisses, and respects reduced-motion (arch D14).
- **Given** a queued toast during combat, **Then** it waits until the next calm moment (no focus/fade violation).
- **Given** the game-over `new-unlock` state, **Then** the same `toast` idiom renders inline on the run-summary (reused — arch D15; wired in Story 8.4).

*(UX OQ9/S1 · arch D15)*

---

## Epic 8: v1.0 Polish & Ship

**Goal:** the shippable v1.0 — specialty pool + expanded fleet via cross-pollination, balanced to the agreed curves, final boss polish, full HUD/menus/pause, settings + save polish, neon-vector/synthwave final pass, verified Windows + Linux exports at ≥60 FPS. The portfolio deliverable.
**FRs:** FR26, FR28, FR35 (boss polish), FR42 (settings/versioning), FR46, FR48 · **NFRs:** NFR1 (perf), NFR8 (exports) · **Milestone:** v1.0 (ship)

### Story 8.1: Specialty Power-Up Pool

As a player,
I want power-ups gated behind fleet unlocks (armor-piercing, tractor-pull, blast-columns),
So that unlocking ships meaningfully expands everyone's build space.

**Acceptance Criteria:**

- **Given** specialty power-ups (`.tres`), **Then** armor-piercing / tractor-pull / blast-columns etc. exist, **gated behind fleet unlocks via cross-pollination**.
- **Given** the full pool, **Then** standard + specialty are both available; cross-pollination is **complete** (not just E3 plumbing).
- **Given** v1.0 breadth, **Then** a satisfying (if not exhaustive) specialty roster ships; full breadth is post-1.0.

*(FR26 specialty full, FR28 complete)*

### Story 8.2: Fleet Expansion & Balance Pass

As a player,
I want more ships and a build curve that peaks at the boss without breaking,
So that the godhood fantasy lands across the whole roster.

**Acceptance Criteria:**

- **Given** the fleet, **Then** it expands beyond the v0.1 2–3 ships (feat-unlocked, content-breadth scoped).
- **Given** the balance pass, **Then** the build compounds to ~8–12× at the boss (godhood peak lands), the sacrifice ceiling stays threat-relative, and balance bands hold across the roster.
- **Given** cross-pollination, **Then** signature→shared-pool entries are **tuned** (not just functional).

*(FR28 balance · content-breadth fleet)*

### Story 8.3: Final Boss Polish & 20-Wave Balance

As a player,
I want a climactic, fair final boss and a campaign that peaks right at the finish,
So that the victory feels earned and the run never coasts or trivializes.

**Acceptance Criteria:**

- **Given** the final boss, **Then** the fight is polished (readable, climactic, fair).
- **Given** the 20-wave campaign, **Then** the full balance pass holds (pacing peaks at the boss, no trivialization).

*(FR35 boss polish)*

### Story 8.4: Full HUD, Menus, Pause, Game-Over, Settings & Accessibility Floor (UX-enriched)

As a player,
I want a complete title screen, full HUD polish, pause with codex, a game-over/run-summary, and a real settings + accessibility panel,
So that the game feels like a finished product I can control and configure to my needs.

**Acceptance Criteria:**

- **Given** the HUD, **Then** it's fully polished — full focus/fade tuning (UX S1), full per-token palette-arc interpolation across all HUD components (UX V3, arch D13), and combat-critical labels legible at desktop + Steam-Deck distance (UX A1).
- **Given** first launch, **Then** a **title screen** surfaces (New Run · Settings · Quit) carrying the **meridian brand motif** (UX N3 — line-through-poles 1-axis geometry + peak/ascent; see `mockups/key-title.html`); first-run onboarding hints fire on New Run (UX O1).
- **Given** pause (`pause`, one button from anywhere), **Then** a full **pause overlay** over `panel-scrim` offers **Resume · Codex · Settings · Quit Run**, with **Resume** default-focused (UX EXPERIENCE IA / State Patterns). The **Codex** (UX `codex`, O1) is always-available help covering ship stats / modifier meanings / the gamble.
- **Given** Quit Run, **Then** it is **hold-to-confirm** with a player-facing **no-resume warning surfaced before the hold** (UX F6/OQ9; arch NP5 — quitting abandons the run).
- **Given** all ships lost, **Then** the **Game-Over / Run-Summary** screen reads `THE MERIDIAN GOES DARK` (UX M1), shows run stats + best + a build recap, and a **`new-unlock` state** surfaces a `toast`-style inline banner for any newly unlocked feat/ship (UX EXPERIENCE State Patterns; arch D15; toast primitive from Story 7.5). Single focused CTA back to Title / New Run.
- **Given** settings, **Then** a settings UI persists prefs to `user://` (UX EXPERIENCE; arch D14): **volume** (master/music/sfx), **input remap** (per-action, both schemes, conflict detection, reset-to-default), **gamepad deadzone slider**, **UI-scale slider**, **reduced-motion toggle**. Save schema finalized/versioned; best-stats persist.
- **Given** the **accessibility floor (UX A1)**, **Then** the panel ships: **reduced-motion = dampen-don't-remove** (~70% scale on shake/particles/hit-flash, feedback preserved, default-on capable), **WCAG-AA contrast** at both arc ends, **full input remap + deadzone**, **UI-scale**, **photosensitive ≤3 Hz flash cap** (enforced unconditionally), and **hold-to-toggle Sacrifice / hold-to-confirm Quit Run**. *(The floor's juice/input consumers — `_motion_scale`, `HitFlash` cap, `HoldToCommit` — land early at v0.1 E1–E3; this story ships the **player-facing settings panel + remap UI** = v1.0 per F5 — not pulled forward.)*
- **Given** menus/settings, **Then** they are non-diegetic overlay UI on CanvasLayers (UX D1), gamepad-navigable with mouse-hover = focus (UX F5); modals never stack (UX F9).

*(FR46 full HUD/menus/pause, FR42 settings/versioning · UX A1/D1/F5/F6/F9/M1/N3/O1/S1/V3 · arch D14/D15/NP5)*

### Story 8.5: Art/Audio Final Pass & Juice on Godhood Peak

As a player,
I want the game to look and sound like a polished neon-vector arcade roguelite, with the climax juiced to the max.

**Acceptance Criteria:**

- **Given** art, **Then** the neon-vector final pass lands (readability, underdog-rescuer identity).
- **Given** audio, **Then** the full synthwave/arcade soundtrack + pooled SFX ship (buses: master/music/sfx).
- **Given** the godhood peak, **Then** juice (screen-shake / particles / flash) is cranked for the climax.

*(FR48 final audio, FR47 juice · NFR11/12)*

### Story 8.6: Windows + Linux Exports & Performance Pass

As a developer,
I want verified exports on both platforms holding 60 FPS,
So that the v1.0 actually ships where it's targeted.

**Acceptance Criteria:**

- **Given** export presets (`export_presets.cfg`), **Then** Windows + Linux presets exist.
- **Given** both platforms, **Then** the game runs and is **verified** on each before release.
- **Given** performance, **Then** ≥60 FPS sustained over a 10-minute combat loop (16.67 ms worst-case), profiled on measured hotspots (not guesses).

*(NFR1, NFR8)*

### Story 8.7: v1.0 Ship Gate

As the developer,
I want a complete, shippable v1.0 — the portfolio deliverable,
So that the project's definition of done is met.

**Acceptance Criteria:**

- **Given** the assembled v1.0, **Then** the complete game is playable end-to-end with all systems, content, and polish.
- **Given** the portfolio bar, **Then** it's a complete shippable roguelite on Windows + Linux (**definition of done**).
- **Given** a final playtest, **Then** v1.0 success metrics are met (felt godhood peak, gamble engaged, "one more run" pull).

*(integration — v1.0 ship gate)*

---

## Epic 9: Post-1.0 Growth

**Goal:** the long-tail depth — additive data/content, never rewrites. ⚠️ **Uncommitted roadmap** — lighter stories pending the dedicated post-systems content-breadth brainstorm (full roster, specialty pool, formations, feats). Each increment ships additively on the live v1.0 base.
**FRs:** FR28 (full depth), FR34 (new modifiers), FR39 (expanded feats) + content-breadth deliverables · **Milestone:** post-1.0 (uncommitted)

### Story 9.1: Full Fleet Depth (20+ Ships & Signatures)

As a returning player,
I want a deep roster of distinct ships,
So that the variety and replay value keeps growing.

**Acceptance Criteria:**

- **Given** post-1.0, **Then** the fleet expands to **20+ ships** with distinct signature mechanics (variety > raw power).
- **Given** new ships, **Then** each signature enters the shared pool via cross-pollination (additive `.tres`, zero core rewrite).

*(FR28 full depth · content-breadth roster)*

### Story 9.2: Cross-Pollination Full Depth (the 50-hour engine)

As a build-crafter,
I want signature synergies and specialty gating to compound deeply,
So that the build space sustains dozens of hours.

**Acceptance Criteria:**

- **Given** cross-pollination depth, **Then** signature synergies + specialty gating create the **50-hour combinatorial build space**.
- **Given** depth, **Then** it's additive on the v1.0 base (no core rewrites).

*(FR28 full depth)*

### Story 9.3: Daily-Challenge, Shareable Seeds & Leaderboards

As a competitive player,
I want daily challenges and shareable seeds with leaderboards,
So that there's a reason to keep playing (and the score finally means something).

**Acceptance Criteria:**

- **Given** seed determinism (E4), **Then** daily-challenge + shareable seed codes + leaderboards ship.
- **Given** leaderboards, **Then** score (display-only in v1.0) becomes competitive.

*(post-1.0 UX)*

### Story 9.4: New Modifier Waves & Captor Variety

As a veteran,
I want fresh modifier-wave types and varied captors at high tiers,
So that late-game runs stay surprising.

**Acceptance Criteria:**

- **Given** post-1.0, **Then** new modifier-wave types ship beyond Swarm/Gauntlet/Bounty (additive `.tres`).
- **Given** captor variety, **Then** higher tiers get varied captor behaviors (resolves open Q#9).

*(FR34 new modifiers, FR43 captor variety)*

### Story 9.5: Expanded Feats & Content-Breadth Deliverables

As a player,
I want the full feat list and breadth content promised by the post-systems brainstorm,
So that the game realizes its complete vision.

**Acceptance Criteria:**

- **Given** the post-systems content-breadth brainstorm, **Then** its deliverables (full roster, specialty pool, formations, feats) land as additive content.
- **Given** feats, **Then** the expanded feat list (beyond v1.0) ships.

*(FR39 expanded feats · content-breadth)*
