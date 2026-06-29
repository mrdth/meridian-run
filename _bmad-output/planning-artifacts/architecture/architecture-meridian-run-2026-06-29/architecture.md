---
title: 'Meridian Run — Game Architecture'
project: 'meridian-run'
date: '2026-06-29'
author: 'Mrdth'
version: '1.0'
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9]
status: 'complete'
engine: 'Godot 4.6.x'
platform: 'Windows + Linux (desktop)'

# Source Documents
gdd: '_bmad-output/planning-artifacts/gdds/gdd-meridian-run-2026-06-29/gdd.md'
epics: '_bmad-output/planning-artifacts/gdds/gdd-meridian-run-2026-06-29/epics.md'
brief: '_bmad-output/planning-artifacts/briefs/brief-meridian-run-2026-06-29/brief.md'
narrative: null

# Companion
decision_log: '_bmad-output/planning-artifacts/architecture/architecture-meridian-run-2026-06-29/decision-log.md'
---

# Game Architecture

## Document Status

This architecture document was created through the GDS Architecture Workflow.

**Steps Completed:** 9 of 9 (Complete)

**Purpose:** Define the technical architecture that ensures every AI agent implements Meridian Run consistently — engine systems design, project structure, implementation patterns, and cross-cutting concerns. Engine *selection* is already settled (Godot 4.6 / 2D / GDScript / Compatibility renderer, per `project-context.md`); this document owns the *systems design* built on top of it.

---

## Executive Summary

Meridian Run is a 2D fixed-screen roguelite shooter on a 1-axis *Galaga*-lineage chassis, built in Godot 4.6 (GDScript, Compatibility renderer) for Windows + Linux. Its architecture treats the project as **high systems complexity on a low-complexity engine**: a data-driven, pure-logic-separated design where content (ships/power-ups/modifiers/formations) lives as `.tres` resources and all tuning is data — so v0.1→v1.0→post-1.0 grows additively without rewrites. The build engine (recompute-from-modifiers), the Gamble state-web (docked-ship dual nature), and deterministic seeded generation are the load-bearing systems this document defines.

**Key architectural decisions:**
- **D2 Build engine** — `StatBlock` + `Modifier`/`Behavior` `.tres`, recomputed from modifiers each wave (ADR-1) — the architectural heart.
- **D3 Deterministic seeded generation** — `SeedManager` → named RNG sub-streams + pure `RunGenerator` (ADR-2).
- **NP1 Docked-ship dual nature** — permanent build track split from a transient combat fighter (the Gamble's core).
- **D5 No resume** — `user://` meta-only; in-memory runs (ADR-3); **D4 composition over inheritance** (ADR-4).

**Project structure:** co-located by domain — 12 core systems across `systems/` (11 autoloads) + `components/` + 6 gameplay domains + `resources/` (`.tres`) + `assets/` + `tests/` (GUT).

**Implementation patterns:** 9 (6 standard + 3 novel) ensuring AI-agent consistency.

**Ready for:** epic implementation (Epics 1–6).

---

## Project Context

### Game Overview

**Meridian Run** — a build-crafter roguelite on a Galaga-lineage 1-axis fixed-screen chassis. Build a ship into absurd compounding power across a 20-wave / 4-tier campaign, then test how far skill can carry that greed in endless mode. The glass-cannon god: firepower and hitbox grow together.

### Technical Scope

**Platform:** Windows + Linux desktop (both first-class; develop on Linux, verify both)
**Engine:** Godot 4.6, 2D, GDScript, Compatibility renderer
**Genre:** fixed-screen 1-axis roguelite shooter (single-player)
**Project level:** HIGH systems complexity on a LOW-complexity engine — risk is in systems + data architecture, not engine mechanics. No networking.

### Core Systems

| System | Complexity | Notes |
|--------|-----------|-------|
| Combat chassis (move/fire/pool) | Medium | 1-axis; vertical-fire hot path |
| Enemy AI (formation/dive; Captor FSM) | Medium-High | Captor = 5-state timed machine |
| Life economy (Ships×HP) | Medium | run vs within-wave resource split |
| The Gamble (capture/rescue/sacrifice) | High | docked-ship dual nature; novel |
| Build engine (dual-ladder/synergy) | High | data-driven effect composition |
| Cross-pollination mechanism | Medium | signature→shared-pool injection |
| Run structure + seeded procgen | Medium-High | deterministic seed pipeline |
| Meta/progression (feats/fleet) | Medium | no meta-currency |
| Save/persistence | Low-Medium | user:// only |
| UI/HUD/menus | Medium | power-up select + shop are data-driven |
| Juice/feedback | Medium | pooled particles, screen-shake |
| Audio | Low-Medium | synthwave autoload |

### Technical Requirements

- ≥60 FPS floor (16.67 ms worst-case); fixed-timestep physics 60 Hz; delta-based motion.
- Deterministic seeded runs (reproducible from a seed; not frame-exact replay).
- Fixed base resolution, canvas-scaled (`canvas_items` + `expand`).
- Windows + Linux exports verified; Input Map actions (kb + gamepad); saves via `user://`.

### Complexity Drivers

- **Build engine + dual-ladder + multiplicative synergy** — needs a composable, data-driven effect/modifier model (the architectural heart).
- **The Gamble state web** — docked ship's dual nature (permanent track + consumable fighter) + 4 resolution outcomes; novel, unproven.
- **Deterministic seeded generation pipeline** — all RNG flows from the run seed through deterministic streams.
- **Hot-path pooling** — zero per-frame allocations for projectiles/particles/enemies.
- **Additive content growth** — ships/power-ups/modifiers/formations as `.tres` resources so v0.1→v1.0→post-1.0 never rewrites core systems.

### Technical Risks

- 1-axis movement-depth bet → chassis feel must be parametric/data-driven for retuning.
- Unproven build/gamble/cross-pollination → must be independently unit-testable (pure-logic separation); Epic 3 is the go/no-go gate.
- Scope vs solo dev → data-driven content enables staged additive growth.
- Godhood-peak tuning → all tuning values are data, not code.
- State-ownership clarity → single clear owners for Ships/HP/docked-ship/build/run state.

## Engine & Framework

### Selected Engine

**Godot 4.6.x** (GDScript, 2D, Compatibility renderer) — pinned to the 4.6.x line.

**Rationale:** settled in `project-context.md`; ideal for a pure-2D fixed-screen arcade roguelite — lightweight renderer, first-class 2D physics, data-driven `.tres` resources, no networking needed. Chosen over Unity/Unreal (3D-first, heavier) and Phaser (web-only; desktop export not a strength).

**Version status (verified 2026-06):** 4.6.3-stable (2026-05-20) is current. Godot 4.7 is Release Candidate only — **not** yet stable. Stay on 4.6.x; write forward-compatible code; migrate to 4.7 once stable + Linux packages ship. The 3D defaults in `project.godot` (`Forward Plus`, `Jolt`, `d3d12`) are inert for this 2D/Compatibility project.

### Project Initialization

Build from the existing scaffold (`project.godot`) + `project-context.md` conventions. No external starter template (would risk conflicting conventions).

### Engine-Provided Architecture

| Component | Solution | Notes |
|-----------|----------|-------|
| Rendering | Compatibility (OpenGL3) | lightest footprint for 2D |
| Physics | 2D server: CharacterBody2D/RigidBody2D/Area2D | `move_and_slide()`, no args |
| Audio | AudioServer + AudioStreamPlayer | synthwave |
| Input | Input Map actions + Input singleton | kb+gamepad, `get_vector()` |
| Scene mgmt | SceneTree + PackedScene (`.tscn`) | `preload().instantiate()` |
| Scripting | GDScript, static typing | |
| UI | Control + CanvasLayer | HUD on separate layer |
| Resources | Resource / `.tres` | data-driven content backbone |
| Particles | GPUParticles2D | pooled |
| Save | `user://` + FileAccess/ConfigFile | |
| Export | export_presets.cfg | Win + Linux presets |
| Profile/debug | built-in Profiler/Monitor | measure hotspots, not guesses |

### AI Tooling (MCP Servers)

Optional MCP servers for AI-assisted development (documented in Development Environment):

- **GoPeak** (`HaD0Yun/Gopeak-godot-mcp`) — Godot 4.x MCP; ~95+ tools covering edit→run→inspect→fix; one-command `npx -y gopeak` launch; **no Godot plugin required**; supports Claude Code. Requirements: Godot 4.x, Node.js.
- **Context7** (`upstash/context7`) — version-specific Godot docs lookup so the AI uses current APIs, not training-data recall. Install: `claude mcp add context7 -- npx -y @upstash/context7-mcp`.

Install per their repos; verify compatibility before each major Godot version bump.

### Remaining Architectural Decisions

Owned by this document (Steps 4–8): autoload/state-ownership; pooling; build-engine effect model; dual-ladder state; Gamble FSM; deterministic seeded generation; scene composition; EventBus boundaries; content-data architecture; run/wave FSM; save/persistence model; GUT testing architecture; logging strategy; full `res://` tree.

## Architectural Decisions

### Decision Summary

| # | Category | Decision | Rationale |
|---|----------|----------|-----------|
| D1 | State mgmt | Thin autoload singletons + game/wave FSMs + Resource-backed `RunState` | global services + explicit flow + serializable, testable |
| D2 | Build engine | `StatBlock` + `Modifier`/`Behavior` `.tres`; recompute pipeline | composable multiplicative synergy; additive content; pure-logic tested |
| D3 | Procgen/seed | `SeedManager` → named RNG sub-streams + pure `RunGenerator` → `WaveDefinition` | deterministic per-concern isolation; reproducible; testable |
| D4 | Entity composition | Composition over inheritance (component nodes) | modular, reusable, Godot-idiomatic |
| D5 | Save/persist | `user://` versioned meta only; in-memory `RunState`; **no resume** | roguelike permadeath + meta (runs short; endless is opt-in) |
| D6 | AI | FSMs via reusable `StateMachine`/`State` pattern; Captor = 5-state FSM | matches GDD timings; right-sized |
| D7 | Pooling | Generic `ObjectPool` autoload; acquire/release; `activate()`/`reset()` | hot-path discipline, no per-frame alloc |
| D8 | Signals | `EventBus` (global flow) + direct signals (local); boundary rule | decoupled, no hidden god-bus |
| D9 | Content data | `.tres` Resources + `ContentRegistry` | additive growth; cross-pollination = data registration |
| D10 | UI | Godot `Control` + `CanvasLayer` HUD + data-driven select/shop | engine-native; reads EventBus |
| D11 | Audio | Engine-native `AudioStreamPlayer` + pooled SFX + buses | no middleware at v1.0 |
| D12 | Asset loading | `preload` core, lazy-load rest; threaded only if measured | small fixed-screen scope |

*All decisions are Godot-native (version = Godot 4.6.x, §Engine & Framework); no per-decision external dependencies.*

### State Management (D1)

**Approach:** hybrid — thin autoload singletons + explicit FSMs + a Resource-backed `RunState`.

- **Autoloads (global services only, kept thin):** `GameManager` (mode/scene flow, pause), `EventBus`, `AudioManager`, `SaveManager`, `SeedManager`, `Pool`. Autoloads own state but **delegate logic to testable pure classes**.
- **`RunState`** (RefCounted/Resource): the current run's data — ships, currency, score, seed, and both build ladders (`BuildState`). Serializable in principle, but **not persisted** (D5 — no resume). Passed explicitly where feasible to keep it testable.
- **FSMs:** top-level **game-mode FSM** (`menu → run → gameover`) and a **run/wave lifecycle FSM** (`wave_intro → wave_active → wave_cleared → reward/shop → next_wave`). The Captor is its own FSM (D6).
- *Rejected:* pure-ECS (overkill for ~dozen entity types on a fixed screen; node-tree composition already gives modularity); singleton god-objects (untestable).

**State-ownership table** (prevents AI-agent conflicts):

| State | Owner | Scope |
|---|---|---|
| Ships (run economy) | `RunState` | run |
| HP (per-wave buffer) | `HealthComponent` (reset each wave by wave controller) | wave |
| Docked ship (combat fighter) | `DockedShip` entity on Player | wave |
| Rescued-ship build track (permanent) | `RunState.BuildState` | run |
| Main-ship build track | `RunState.BuildState` | run |
| Currency / Score | `RunState` | run |
| Wave/run progression | wave controller ↔ `RunState` | run |
| Seed / RNG streams | `SeedManager` | run |
| Meta (unlocks/feats/settings) | `SaveManager` → `user://` | cross-run |

*The docked ship's **dual nature** is captured by splitting it: combat presence = `DockedShip` entity (transient); build track = `RunState.BuildState` (permanent).*

### Build Engine (D2)

The architectural heart. **Approach:** data-driven `StatBlock` + `Modifier`/`Behavior` Resources, recomputed each wave.

- **`StatBlock`** (Resource): named typed stats (`fire_cooldown`, `damage_mult`, `move_speed`, `projectile_count`, `spread_angle`, `hp_cap`, …). Each = `base + Σ modifiers`.
- **`PowerUpDefinition`** (`.tres`): list of `Modifier { target_stat, op: ADD|MULT|SET, value, target_ladder: main|rescued, tags }` + optional `Behavior` refs + cost/value + pool tier.
- **Recompute pipeline:** rebuild the effective `StatBlock` from base + all acquired modifiers at run start and each wave (recompute, not incremental mutation → drift-proof). Multiplicative-over-current synergy (the ~8–12× godhood curve) falls out naturally.
- **Behavioral effects** (triple-shot, tractor-pull, blast-columns) = `Behavior` Resources the weapon system queries, honoring the GDD build-axis priority: *projectile behavior > on-hit modifiers > generators*.
- **Pure logic → fully GUT-testable** (assert recomputation from a modifier list).
- *Rejected:* ad-hoc flag/branch model (collapses under compound builds); PoE-style tag-query (overkill for v1.0).

### Procedural Generation & Seed (D3)

**Approach:** `SeedManager` → deterministic named RNG sub-streams + a pure `RunGenerator`.

- Master seed spawns **named sub-streams** (`wave_composition`, `modifier_select`, `enemy_spawn`, …), each derived deterministically from seed + salt. Isolating concerns prevents one generator's logic change from shifting another's RNG — the classic determinism pitfall.
- **`RunGenerator`** is **pure**: `(seed, wave, tier, run_flags) → WaveDefinition` (ordered spawns + modifier type + captor presence). Same seed → same `WaveDefinition`. Player timing stays non-deterministic (not a frame-exact replay — per GDD).
- Honors the authored/procedural split: procedural = wave composition + modifier pick; authored = boss, captor AI, enemy stats (referenced by id, not generated).

### Entity Composition (D4)

**Composition over inheritance.** Entities are scenes composed of reusable component child-nodes:

- Shared components: `HealthComponent`, `HitboxComponent`/`HurtboxComponent` (Area2D-based), `FactionComponent`, `StatBlock` holder, `StateMachine`.
- Player = movement + fire + health + docked-ship-slot + statblock. Enemies = health + hitbox + AI. Projectiles = lightweight pooled nodes (damage payload + faction).
- **Collision layers (strict):** `player / enemy / player_projectile / enemy_projectile / pickup`.
- *Rejected:* deep inheritance (brittle across the fleet roster).

### AI (D6)

**FSMs** via a reusable `StateMachine`/`State` node pattern (template in `project-context.md` lineage). Grunt/Shielder/Bomber = small FSMs / scripted formation+dive patterns; **Captor = the 5-state timed FSM** (`enter → formation → telegraph 0.7s → capture 0.4s → dive 1.6s`) straight from the GDD. No behavior trees / GOAP / LimboAI (overkill; available if later complexity demands).

### Object Pooling (D7)

Generic **`ObjectPool`** (autoload `Pool`), per-type pools. `acquire()`/`release()` API; inactive nodes toggle `visible` + `set_process(false)`/`set_physics_process(false)`; re-init via explicit **`activate()`/`reset()`** — never `_ready()` (per project-context). Projectiles are the priority; particles use efficient `GPUParticles2D`.

### Signal Architecture (D8)

- **`EventBus`** for **global game-flow only**: `run_started`, `wave_cleared`, `ship_lost`, `build_changed`, `score_changed`, `game_over`. HUD/systems subscribe here.
- **Direct signals** for local entity comms: `HealthComponent.health_changed`, `enemy.died`, `captor.state_changed`. Callable-syntax connects.
- **Boundary rule:** global flow/state → `EventBus`; intra-entity / parent-child → direct signals. Don't route everything through the bus (it becomes a hidden god-object).

### Content Data Architecture (D9)

All content is `.tres` `Resource` subclasses under `resources/`, indexed by a **`ContentRegistry`**: `ShipDefinition`, `PowerUpDefinition`, `EnemyDefinition`, `FormationDefinition`, `ModifierWaveDefinition`. This is the **additive-growth enabler** — v0.1→v1.0→post-1.0 ships content as data files, not code — and makes **cross-pollination** a data-registration step (ship signature → shared pool entry on fleet unlock).

### Data Persistence (D5)

- **Meta only** to `user://`: unlocked ships, feat progress, settings, best stats. Versioned JSON (via `FileAccess`) or `ConfigFile`; schema-versioned for migration.
- **Run state is in-memory only** — **no resume-mid-run** (Mrdth: runs are short; endless is an opt-in continuation; permadeath stays clean). Quitting abandons the run.
- No cloud saves (single-player, portfolio scope, no backend).

### UI / Audio / Asset Loading (D10–D12)

- **UI:** Godot `Control` nodes; HUD on a `CanvasLayer` (subscribes to `EventBus`); power-up select + shop = data-driven scenes reading `PowerUpDefinition`s. Menus via scene changes.
- **Audio:** engine-native `AudioStreamPlayer`; small pooled SFX-player set; buses (master/music/sfx). No middleware at v1.0 (FMOD/Wwise = post-1.0 only if needed).
- **Assets:** `preload()` core, lazy-load the rest; `ResourceLoader.load_threaded_*` only if a measured hitch demands it. Small fixed-screen scope → no streaming/addressables.

### Architecture Decision Records (ADRs)

- **ADR-1 — Build engine = recompute-from-modifiers (not incremental mutation).** *Context:* compound multiplicative builds must hit ~8–12× DPS without drift. *Decision:* recompute effective `StatBlock` from base + modifier list each wave. *Consequence:* O(modifiers) rebuild per wave (trivial), zero drift, pure-logic testable.
- **ADR-2 — Determinism via named RNG sub-streams.** *Context:* seeded reproducibility; one logic change must not cascade RNG shifts. *Decision:* salted named sub-streams per concern. *Consequence:* generators are independently evolvable; `RunGenerator` is pure/testable.
- **ADR-3 — No resume-mid-run (in-memory `RunState`).** *Context:* roguelite permadeath feel; short runs; endless is opt-in. *Decision:* persist meta only; runs are abandoned on quit. *Consequence:* simpler save surface, purer stakes; revisit if long sessions become friction.
- **ADR-4 — Composition over inheritance for entities.** *Context:* fleet roster + component reuse. *Decision:* component-node composition; strict collision layers. *Consequence:* highly reusable, testable; slight per-entity setup cost (acceptable).

## Cross-cutting Concerns

These patterns apply to **all systems** and must be followed by every implementation. *(Note: GDScript has no `try/catch` — error handling uses Godot idioms below.)*

### Error Handling

**Strategy:** preconditions + `push_error`/`push_warning` + fail-safe defaults; `assert` for invariants (dev-only, no-op in release); critical errors route through `EventBus` to the game-mode FSM for safe-fail.

- **Recoverable** (missing optional asset, malformed save line) → log + graceful fallback; invisible to the player.
- **Critical** (corrupt core data, nil where required) → log + fail-safe the run/scene back to the menu; **never** hard-crash the engine.

```gdscript
func get_enemy_def(id: String) -> EnemyDefinition:
    var def := _registry.get(id)
    if def == null:
        Log.err("enemies", "missing EnemyDefinition '%s' — grunt fallback" % id)
        return _grunt_fallback
    return def

assert(ship_count >= 0, "ships cannot go negative")   # dev-only invariant
```

### Logging

**Format:** `[LEVEL][system] message` (plain text). **Destination:** editor Output **+ rotating `user://logs/` file** (playtest bug-report trail). **Levels:** ERROR / WARN / INFO / DEBUG (TRACE optional). Release = WARN+; dev = DEBUG. A `Log` autoload wraps `push_error`/`push_warning`/`print` with level filtering (no `print()` in shipped code — `project-context.md`).

```gdscript
Log.info("run", "wave %d cleared" % wave)
Log.warn("pool", "projectile pool exhausted — expanding")
if Log.is_debug():                                    # guard avoids building the string
    Log.debug("rng", "wave_comp draw = %d" % roll)
```

### Configuration

**Approach:** three tiers.

- **Immutable constants** → `const` / `Constants` autoload (collision-layer names, base resolution).
- **Balancing values** → **`.tres` tuning Resources** (move-speed, bullet speed, fire cooldown, captor timings, economy, tier scaling) — the playtest lever; zero code changes (per D9).
- **Player settings** → `ConfigFile` → `user://` via a `Settings` autoload (volume, input remap, etc.).

```gdscript
@export var move_speed: float = 320.0                 # in player_tuning.tres — data, not code
Settings.set_volume(0.8)                              # persisted to user://
```

### Event System

**Pattern:** `EventBus` (global flow) + direct signals (local entity) — see D8. Conventions: **typed signals**; **past-tense for events, imperative for requests** (`wave_cleared`, `ship_lost` vs `request_pause`); **synchronous** execution with `call_deferred` where ordering matters. No event-history/replay at v1.0 (determinism lives in the seed — D3).

```gdscript
signal wave_cleared(wave: int, bonus: float)
signal ship_lost(remaining: int)
EventBus.run_failed.connect(_return_to_menu)          # critical error → safe-fail
```

### Debug Tools

**Activation:** a `Debug` autoload, gated by `OS.is_debug_build()` (no-op/stripped in release exports). **Interface:** hotkeys + a toggle overlay (no full debug console — lighter).

- **Overlay** (toggled): FPS, entity count, pooled-object count, current wave/seed, build summary.
- **Visual toggles:** hitboxes/hurtboxes, capture-column telegraph, formation rows, RNG-stream draws.
- **Cheat commands** (hotkeys): spawn captor, force wave, give currency, set seed, invincibility — critical for fast Epic-3 hypothesis testing.
- Performance via Godot's built-in Profiler/Monitor.

```gdscript
func _input(event: InputEvent) -> void:
    if OS.is_debug_build() and event.is_action_pressed("debug_toggle_overlay"):
        _overlay.visible = not _overlay.visible
```

## Project Structure

### Organization Pattern

**Pattern:** co-located by domain (Option A, from `project-context.md`) — each system keeps its scenes + scripts + art together; shared/cross-domain assets in `assets/`; autoloads in `systems/`; `.tres` data in `resources/`.

**Rationale:** keeps related files together (easy to find/move), makes content addition a data-only change, and matches the engine's node-tree composition model.

### Directory Structure

```
res://
├── project.godot, icon.svg
├── addons/gut/                       # GUT test framework (installs at Epic 1)
│
├── systems/                          # AUTOLOADS — global services only, thin
│   ├── constants.gd                  #   immutable (layer names, base resolution)
│   ├── log.gd                        #   logging helper (no print() in shipped code)
│   ├── event_bus.gd                  #   global game-flow signals
│   ├── settings.gd                   #   player prefs → user:// ConfigFile
│   ├── seed_manager.gd               #   run seed → named RNG sub-streams
│   ├── content_registry.gd           #   loads/indexes all .tres content
│   ├── pool.gd                       #   generic ObjectPool
│   ├── save_manager.gd               #   meta persistence → user://
│   ├── audio_manager.gd              #   music + pooled SFX
│   ├── game_manager.gd               #   game-mode FSM, pause, scene flow
│   └── debug.gd                      #   overlay + cheats (is_debug_build-gated)
│
├── components/                       # REUSABLE cross-domain component nodes
│   ├── health_component, hitbox_component, hurtbox_component (Area2D)
│   ├── faction_component             #   player/enemy → collision layer
│   └── state_machine/                #   reusable FSM (state_machine.gd + state.gd)
│
├── player/                           # PLAYER domain
│   ├── player.tscn / player.gd
│   ├── fire_system.gd                #   vertical-fire logic
│   ├── docked_ship.tscn / docked_ship.gd   # dual-fighter entity (transient)
│   └── art/                          # player-specific sprites
│
├── enemies/                          # ENEMIES domain
│   ├── enemy.tscn / enemy.gd         # base (composes components)
│   ├── grunt.tscn, shielder.tscn, bomber.tscn
│   ├── enemy_definition.gd           # EnemyDefinition schema
│   ├── captor/ (captor.tscn + states/: enter/formation/telegraph/capture/dive)
│   ├── formation_definition.gd       # entry/dive pattern schema
│   └── art/
│
├── world/                            # WORLD domain
│   ├── arena.tscn                    # fixed-screen arena
│   ├── background.tscn
│   ├── wave_controller.gd            # run/wave lifecycle FSM (spawns, timing)
│   └── art/
│
├── juice/                            # FEEDBACK domain (arena-scoped, not autoload)
│   ├── juice_coordinator.gd          #   in arena scene; EventBus-driven
│   ├── screen_shake.gd               #   Camera2D shake effect
│   └── hit_flash.gd                  #   entity hit-flash
│
├── run/                              # RUN domain — roguelite spine
│   ├── run_state.gd                  # Resource-backed run state (ships/currency/score/seed)
│   ├── build_state.gd                # dual-ladder tracks (main + rescued)
│   ├── run_generator.gd              # PURE: (seed, wave, tier) → WaveDefinition
│   ├── wave_definition.gd / modifier_wave_definition.gd
│
├── build/                            # BUILD ENGINE domain — the heart (D2)
│   ├── stat_block.gd                 # StatBlock resource (named stats + Σ modifiers)
│   ├── modifier.gd                   # Modifier resource (ADD/MULT/SET)
│   ├── ship_definition.gd / power_up_definition.gd
│   ├── behaviors/                    # Behavior resources (triple_shot, tractor_pull, …)
│   └── build_recompute.gd            # PURE recompute pipeline
│
├── ui/                               # UI domain
│   ├── hud.tscn / hud.gd             # CanvasLayer; subscribes to EventBus
│   ├── power_up_select.tscn / shop.tscn   # data-driven (read PowerUpDefinition)
│   └── menus/ (main_menu, pause_menu, game_over)
│
├── resources/                        # .tres DATA instances only (D9)
│   ├── ships/ · power_ups/ · enemies/ · formations/ · modifier_waves/
│   └── tuning/                       # player_tuning.tres, economy_tuning.tres, …
│
├── assets/                           # SHARED/cross-domain art + audio only
│   └── fonts/ · shaders/ · sfx/ · music/
│
└── tests/                            # GUT — mirrors domains
    ├── run/ (test_run_generator, test_build_state)
    ├── build/ (test_stat_block, test_build_recompute)
    └── enemies/ (test_captor_fsm) · components/ (integration)
```

### Autoload Registry

Registered in Project Settings → Autoload in this order (leaf services first so dependents can use them at `_ready`):

1. `Constants` → 2. `Log` → 3. `EventBus` → 4. `Settings` → 5. `SeedManager` → 6. `ContentRegistry` → 7. `Pool` → 8. `SaveManager` → 9. `AudioManager` → 10. `GameManager` → 11. `Debug`

### System Location Mapping

| System | Location | Responsibility |
|---|---|---|
| Game-mode / wave FSMs | `systems/game_manager.gd`, `world/wave_controller.gd` | flow + wave lifecycle |
| Build engine | `build/` | StatBlock, modifiers, recompute |
| Procgen / seed | `run/`, `systems/seed_manager.gd` | deterministic WaveDefinition |
| Entity components | `components/` | reusable health/hitbox/faction/FSM |
| Player / enemies / world | `player/`, `enemies/`, `world/` | co-located domains |
| Content data | `resources/` (`.tres`) + `ContentRegistry` | ships/powerups/enemies/formations/tuning |
| Cross-cutting | `systems/` (autoloads) | log/settings/save/pool/audio/debug |
| Juice / feedback | `juice/` (arena-scoped `JuiceCoordinator`) + EventBus | screen-shake, pooled particles, hit-flash |
| Tests | `tests/` (mirrors domains) | pure-logic + integration (GUT) |

### Naming Conventions

**Files:** scripts `snake_case.gd` · scenes `snake_case.tscn` · assets `snake_case` · resource files type-prefixed (`ship_*`, `power_up_*`, `enemy_*`, `modifier_wave_*`).

**Code:** nodes `PascalCase` (meaningful root names) · identifiers `snake_case` · constants `UPPER_SNAKE` · enums `PascalCase` / members `UPPER_SNAKE` · private members leading `_` · one root + one script per scene. Events past-tense snake_case (`wave_cleared`) / requests imperative (`request_pause`). Autoloads accessed by registered name.

### Architectural Boundaries

- **`systems/` autoloads** = global services only, thin — no gameplay logic.
- **Domains** own scenes + scripts + art + their pure logic; domains communicate via **`EventBus` or explicit injection, never cross-domain node paths** (`../../X`).
- **`components/`** = reusable cross-domain nodes with no single-domain owner.
- **`resources/`** = `.tres` **instances only**; Resource **schema scripts** live with their owning domain (`build/`, `enemies/`, `run/`) → adding content = add a `.tres`, zero code.
- **`assets/`** = shared/cross-domain art+audio **only**; domain art stays in its domain.
- **Pure-logic separation:** gameplay rules (run-gen, build-recompute, stat math) are pure classes with thin Node wrappers → GUT-testable without the scene tree.
- **Juice/feedback:** arena-scoped `JuiceCoordinator` (in `juice/`, placed in the arena scene — **not** an autoload, so auto-disabled in menus) driven by `EventBus` events (`screen_shake_requested`, `hit_flash_requested`); particles via `Pool`.

## Implementation Patterns

These patterns ensure consistent implementation across all AI agents. The recompute build pipeline (ADR-1) and named-seed sub-streams (ADR-2) are documented in Step 4; this section covers the gameplay-level novel patterns + standard conventions.

### Novel Patterns

#### NP1 — Docked-Ship Dual Nature

**Purpose:** the rescued ship is one logical entity with two roles — a **permanent build track** (never lost, scales sacrifice) **and a transient combat fighter** (firepower + bigger hitbox + first-hit absorber, consumed on absorb/sacrifice). Capture-immune while present; resolves to absorb/sacrifice/keep/failed-rescue.

**Components:** permanent track = `RunState.BuildState.rescued_track` (run scope); transient fighter = `DockedShip` node on Player (wave scope); `DockedShipController` (on Player) manages attach/detach + resolution.

**Invariant:** the consume path removes the fighter node but **never clears the track**.

```gdscript
# player/docked_ship_controller.gd
func attach(track: BuildTrack) -> void:
    _track = track                                  # permanent — never cleared here
    _fighter = DockedShipScene.instantiate()
    _fighter.setup(_track.combat_stats()); add_child(_fighter)
    _player.set_docked(true)                        # capture-immune + bigger hitbox

func sacrifice(threat: float) -> void:              # active input
    EventBus.sacrifice_burst_started.emit(BuildRecompute.threat_ceiling(_track, threat))
    _consume_fighter(); RunState.spend_ship()

func absorb() -> void:                              # intrinsic — on hit while docked
    _consume_fighter(); RunState.spend_ship()

func _consume_fighter() -> void:
    if _fighter: remove_child(_fighter); _fighter.queue_free()
    _fighter = null; _player.set_docked(false)
    # NOTE: _track is NOT cleared — persists for future sacrifice scaling
```

**Resolution outcomes:** *sacrifice* (input) → burst, −1 ship; *absorb* (on hit) → fighter dies first spares HP, −1 ship; *keep* (wave-end alive) → flies off, regain ship, net 0; *failed-rescue* (kill captor in formation) → ship turns enemy, −1 ship.

#### NP2 — Cross-Pollination Injection

**Purpose:** on fleet unlock, a ship's signature mechanic enters the shared power-up pool for *all* ships — additive (no per-ship code), weighted.

```gdscript
# systems/content_registry.gd
func build_shared_pool(unlocked: Array[String]) -> Array[PowerUpDefinition]:
    var pool := _standard_pool.duplicate()
    for sid in unlocked:
        var ship := _ships[sid]
        if ship.signature != null:
            pool.append(ship.signature_as_powerup())   # signature → one shared entry
    return pool   # feat unlock → SaveManager flag → pool rebuilds; zero code added
```

#### NP3 — Threat-Relative Sacrifice Ceiling

**Purpose:** burst scales with track investment but is clamped to current-wave threat — always useful, never an insta-win. Pure logic → unit-testable.

```gdscript
# build/build_recompute.gd  (pure)
static func threat_ceiling(track: BuildTrack, threat: float, cfg: SacrificeTuning) -> SacrificeBurst:
    var raw := track.sacrifice_power()                          # scales w/ investment
    var capped := minf(raw, threat * cfg.max_threat_fraction)   # threat-relative clamp
    return SacrificeBurst.new(capped, cfg.duration)
```

### Communication Pattern

**Triad:** `EventBus` (global flow) + direct signals (local entity) + explicit injection (testable deps).

```gdscript
EventBus.wave_cleared.connect(_on_wave_cleared)   # global → EventBus
enemy.died.connect(_on_enemy_died)                # local entity → direct signal
func _ready(): _gen = RunGenerator.new(seed)      # testable deps → explicit injection
```

**Rule:** prefer **explicit injection** for anything unit-testable; reach autoloads only for truly-global state.

### Entity Creation Pattern

**Factory + Pool.** Pooled types (projectiles/particles) acquired/released; re-init via `activate()`, never `_ready()`.

```gdscript
var proj := Pool.acquire(ProjectileScene) as Projectile
proj.activate(spawn_pos, dmg, faction)            # reset(), not _ready()
# ... on expire:
Pool.release(proj)
```

**Rule:** pooled hot-path types **never** `instantiate()` + `queue_free()` per frame.

### State Pattern

**Shared `components/state_machine` FSM** for discrete-state entities (captor, game-mode, wave lifecycle). **Rule:** no bespoke per-entity FSMs — one reusable pattern.

### Data Access Pattern

**Resources via single registry:** content through `ContentRegistry` (single source of truth); prefs via `Settings`; tuning read from `.tres`.

```gdscript
var grunt := ContentRegistry.get_enemy_def("grunt")   # not load("res://...")
var speed := player_tuning.move_speed                 # .tres data
```

**Rule:** no scattered `load("res://...")` in gameplay code.

### Consistency Rules

| Pattern | Convention | Enforcement |
|---|---|---|
| Communication | EventBus(global) / signal(local) / injection(testable) | code review; injection for unit-tested logic |
| Entity creation | Factory + `Pool.acquire/release`; `activate()` reset | no `queue_free()` on pooled hot paths |
| State | shared `components/state_machine` FSM | no bespoke FSMs |
| Data access | via `ContentRegistry` / `Settings` / `.tres` | no direct `load()` in gameplay code |
| Docked ship (NP1) | consume never clears track | invariant + GUT test |
| Cross-pollination (NP2) | pool rebuilt from unlock flags | additive only — no per-ship code |

## Architecture Validation

### Validation Summary

| Check | Result | Notes |
|---|---|---|
| Decision compatibility | ✅ Pass | all decisions Godot-native & mutually consistent |
| GDD coverage | ✅ Pass | 12/12 systems mapped (juice/feedback home added) |
| Pattern completeness | ✅ Pass | 6 standard + 3 novel, all with examples |
| Epic mapping | ✅ Pass | E1–E6 all mapped to locations |
| Document completeness | ✅ Pass | exec summary, no placeholders, version note added |

### Coverage Report

- **Systems covered:** 12/12
- **Patterns defined:** 9 (6 standard + 3 novel)
- **Decisions made:** 12 (D1–D12) + 4 ADRs + 5 cross-cutting concerns

### Issues Resolved (Step 8)

1. Stale "Steps Completed" body counter corrected.
2. Juice/feedback given an architectural home (`juice/` domain, arena-scoped `JuiceCoordinator`, EventBus-driven).
3. Executive Summary section added.
4. Decision Summary version note added (Godot-native; engine version in §Engine).

### Validation Date

2026-06-29

## Development Environment

### Prerequisites

- **Godot 4.6.x** (4.6.3-stable current; pin 4.6.x, migrate to 4.7 once stable + Linux packages ship) — on PATH as `godot`.
- **GDScript** with static typing throughout.
- **Node.js 18+** — only if using MCP tooling.
- Target platforms: Windows + Linux desktop (develop on Linux, verify both before release).

### AI Tooling (MCP Servers)

Selected during architecture to enhance AI-assisted development:

| MCP Server | Purpose | Install |
|---|---|---|
| **GoPeak** (`HaD0Yun/Gopeak-godot-mcp`) | ~95+ tools: scene/GDScript edit, resource/shader work, LSP diagnostics, live scene-tree inspection, input injection | `npx -y gopeak` (no Godot plugin); point at the Godot executable + a tool profile (compact/full/legacy) |
| **Context7** (`upstash/context7`) | Current, version-specific Godot docs lookup (no training-data recall) | `claude mcp add context7 -- npx -y @upstash/context7-mcp` |

These give the AI assistant direct access to the Godot project for scene inspection, asset queries, and context-aware code generation. Verify compatibility before each major Godot version bump.

### Setup Commands

```bash
# Open the project in the editor
godot --path . -e

# Run headless (CI / scripted checks)
godot --headless --path .

# Run the GUT test suite (once addons/gut/ is installed at Epic 1)
godot --headless -s addons/gut/gut_cmdln.gd
```

### First Steps

1. Scaffold the autoloads + `components/` + Input Map actions + base resolution/stretch (Epic 1 prerequisite).
2. Install GUT under `addons/gut/` and stand up the `tests/` mirror.
3. Configure GoPeak + Context7 MCP servers per above (optional but recommended).
4. Begin Epic 1 (Combat Chassis & Feel) — the feel gate everything else proves itself on.

---

_Generated by GDS Game Architecture Workflow · 2026-06-29 · For: Mrdth_
