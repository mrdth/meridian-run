---
baseline_commit: 8959508
---

# Story 2.1: Captor Enemy & 5-State FSM

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want a tractor-beam enemy with a readable, telegraphed attack sequence,
so that capture is a fair gamble I can read and dodge — the foundation of the
entire Gamble (P2) risk-reward loop.

## Acceptance Criteria

1. **Given** a captor spawns, **When** it enters, **Then** it descends from off-screen to a formation row over ~1 s.
2. **Given** the captor is in formation, **Then** it moves side-to-side and fires periodically for 3.5–5.5 s (randomized per-spawn).
3. **Given** the captor telegraphs, **Then** a capture column locks to the player's x at telegraph start and holds for 0.7 s (the fair dodge window) — the player has 0.7 s to read it and move out of the column.
4. **Given** the capture window, **Then** 0.4 s of active tractor plays; **given** dive, **Then** a 1.6 s bezier toward the player then off-screen.
5. **Given** any timing, **Then** all five state durations (and captor-specific geometry/feel) read from `captor_tuning.tres` — data, not code.
6. **Given** the captor is a pooled, killable enemy, **Then** it can be killed by player fire (HP-based), dies with juice + pool release, and its full state cycle is drivable via a debug "spawn captor" cheat (the only spawn path in 2.1).

> *(FR13 — Captor 5-state FSM with GDD timings, data-tunable.)*

---

## Tasks / Subtasks

### Task 1 — `CaptorTuning` resource: schema + `.tres` instance (AC: #5)

- [x] Create `enemies/captor/captor_tuning.gd` — `class_name CaptorTuning extends Resource`; pure data, `@export_group` discipline mirroring `enemies/enemy_definition.gd`. Fields below (Dev Notes §"Tuning map").
- [x] Create `resources/captor_tuning.tres` — the INSTANCE (it wins at runtime; the `.gd` defaults are inert — see gotchas). Populate with the GDD timings.
- [x] Run `godot --headless --import` so the new `class_name` is indexed.

### Task 2 — `enemy_captor.tres` (EnemyDefinition — base combat stats) (AC: #1, #2, #4 enabler)

- [x] Create `resources/enemies/enemy_captor.tres` (`EnemyDefinition`) so the captor reuses `EnemyFireSystem` + `HealthComponent` like grunt/shielder/bomber. `id = &"captor"`, `max_hp = 60`, `score_value = 0` (GDD: captor score is "—"), `fires_during_dive = false`, `move_speed = 200` (snappy — see [Speed-tuning]). Auto-indexed by `ContentRegistry` (no code).

### Task 3 — Captor entity: `enemies/captor/captor.gd` + `captor.tscn` (AC: #1–#6)

- [x] `captor.gd`: `class_name Captor extends CharacterBody2D`. Compose the same components as `enemy.tscn`. See Dev Notes §"Captor entity contract" for the full member list + `activate()` signature.
- [x] `captor.tscn`: instance-style scene — root `Captor (CharacterBody2D)` with children `Visual` (Polygon2D, distinct silhouette), `CollisionShape2D` (CircleShape2D), `HealthComponent`, `FactionComponent` (faction=ENEMY), `Muzzle` (Marker2D), `StateMachine` (5 State children), `EnemyFireSystem` (projectile_scene wired). Set `@export var tuning: CaptorTuning` and `@export var definition: EnemyDefinition` in the scene. `collision_mask = 0` on the root.
- [x] Wire `@onready` state refs + `to_enter/to_formation/to_telegraph/to_capture/to_dive` transition helpers (one-liners calling `_state_machine.transition_to(_X_state)`).
- [x] Death path: `_on_died()` → `died.emit(definition.score_value)` (=0) → `JuiceFx.enemy_killed(...)` → `_release_to_pool.call_deferred()` (CharacterBody2D gotcha — see gotchas). Also release any held capture column.
- [x] `activate(...)` resets HP, arms fire (disarmed — enter state never fires), sets `global_position`, transitions to enter state. NO `_physics_process` on the entity (the StateMachine owns the tick).

### Task 4 — `CaptorEnterState` + `CaptorFormationState` (AC: #1, #2)

- [x] `enemies/captor/states/enter_state.gd` — descend from spawn (off-screen top) to `formation_row_y` over `enter_duration_s`. Procedural vertical lerp + exact-tracking velocity idiom. → `to_formation()`.
- [x] `enemies/captor/states/formation_state.gd` — side-to-side sine drift at row y + `arm_fire()` on enter; hold for `formation_duration_min/max_s × rng.randf_range(0.75,1.25)`; → `to_telegraph()` on expiry (NOT `to_dive`). Disarm fire on exit.

### Task 5 — `CaptureColumn` world entity (AC: #3 enabler)

- [x] `world/capture_column.gd` + `world/capture_column.tscn` — `class_name CaptureColumn extends Node2D`. A `parallel-bars` hazard visual (hazard family, **no bright outline** — D16/ADR-6). API: `activate(locked_x: float)`, `set_active_visual(on: bool)`, `deactivate()`. Pure visual in 2.1 (no Area2D — that's 2.2).
- [x] Pooled via `Pool` (low-volume). The captor acquires on telegraph, positions at `(locked_x, screen_center_y)`, releases on dive.

### Task 6 — `CaptorTelegraphState` + `CaptorCaptureState` (AC: #3, #4)

- [x] `enemies/captor/states/telegraph_state.gd` — on enter: **capture player.x ONCE** (`_locked_x = player_target.global_position.x`), acquire + activate the capture column at `_locked_x`, disarm fire, emit `state_changed(&"telegraph")`. Hold 0.7 s. → `to_capture()`.
- [x] `enemies/captor/states/capture_state.gd` — 0.4 s active tractor: column `set_active_visual(true)` (bars intensify/animate). Hold position. → `to_dive()`. **No ship effect in 2.1** — leave a clearly-marked seam for 2.2 (see Dev Notes §"Scope seams").

### Task 7 — `CaptorDiveState` (AC: #4)

- [x] `enemies/captor/states/dive_state.gd` — 1.6 s bezier toward the player then off-screen. Reuse the grunt `DiveState` aim math (`_captured_aim` captured once + `dive_aim_track_factor` blend + `yb` lane convergence — Dev Notes §"Dive math"). Procedural curve (no shared `FormationDefinition`). On exit: release the capture column, then on off-screen → release captor to pool (one pass — see Open Question D). Emit `state_changed(&"dive")`.

### Task 8 — Spawn path: `FormationSpawner.spawn_captor_at()` + wiring (AC: #6 enabler)

- [x] `world/formation_spawner.gd`: add `@export var captor_scene: PackedScene` + `func spawn_captor_at(pos: Vector2) -> void` (acquire → `_container.add_child` → inject `player_target` → `activate(player, pos, _rng)` → connect `died` once). Mirror `_spawn_enemy` exactly (acquire→add_child→activate ordering is load-bearing).
- [x] `world/arena.tscn`: wire `FormationSpawner.captor_scene = res://enemies/captor/captor.tscn`.

### Task 9 — Debug "spawn captor" cheat (FR50; AC: #6 enabler)

- [x] `project.godot`: add input action `debug_cheat_spawn_captor` → physical_keycode `F8` (F7 is monochrome).
- [x] `systems/debug.gd`: add `_cheat_spawn_captor()` (guarded to `WaveActiveState`, mirroring `_cheat_spawn`), calling `_spawner.spawn_captor_at(pos)` where `pos = player_target.global_position + Vector2(0, -OFFSCREEN)` (descends from above the player). Remove/replace the debug.gd:11 "deferred to E2" comment.

### Task 10 — Tests (GUT) (AC: all)

- [x] `tests/enemies/test_captor_fsm.gd` (integration, mirror `tests/enemies/test_enemy.gd`): instantiate `captor.tscn` with a **test** `CaptorTuning` (tiny durations, e.g. 0.1 s each) + a mock `player_target` Node2D; drive physics frames; assert the 5 transitions fire in order, `state_changed` emits in order, the capture column is active during telegraph+capture, and transitions honor the test-tuning durations.
- [x] `tests/world/test_capture_column.gd`: assert `activate(x)` positions at x + makes visible; `deactivate()` hides.
- [x] `tests/enemies/test_captor_tuning.gd` (unit/pure): assert `CaptorTuning` loads + a `.tres` override is honored.
- [x] `before_each()`: call `Pool.clear()` (test hook). Run `godot --headless --import` after adding `class_name`s, then `godot --headless -s addons/gut/gut_cmdln.gd` — **verify the Scripts/Tests COUNTS** (not just "All tests passed!").

### Task 11 — Regression, verification, housekeeping (AC: all)

- [x] Run full GUT suite — confirm no E1 regressions (grunt/shielder/bomber FSM, spawner, HUD).
- [x] Manual: F8 spawns a captor; watch enter→formation(fire)→telegraph(column locks to player x for 0.7s)→capture(0.4s active)→dive(bezier off-screen)→release. Tune feel via `captor_tuning.tres` only.
- [x] Confirm captor is collectable on wave-end (`spawner.stop()` → `_despawn_survivors()` must handle a captor child — see gotchas).
- [x] Update this file's Dev Agent Record (File List, Completion Notes).

### Review Findings

**Patch (4):**

- [x] [Review][Patch] `capture_column_width_px` tuning never wired to the spawned column — always renders at the hardcoded default (60.0), silently ignoring AC#5 geometry retunes [enemies/captor/captor.gd:169-180] — fixed: `_acquire_capture_column` now sets `column.width_px` from tuning before `activate()`
- [x] [Review][Patch] `CaptorFormationState` divides by `tuning.side_drift_period_s` with no zero-guard, unlike the sibling grunt `FormationState` which explicitly guards this exact case — a 0 value produces NaN velocity [enemies/captor/states/formation_state.gd:41] — fixed: added the matching `<= 0.0` guard
- [x] [Review][Patch] `FormationSpawner.get_active_count()` (debug overlay) overcounts by 1 while any captor holds a `CaptureColumn`, since the column is parented as a sibling under `_container` [world/formation_spawner.gd:143] — fixed: now counts only `Enemy`/`Captor` children
- [x] [Review][Patch] No test exercises a captor despawned mid-telegraph/capture while holding a `CaptureColumn` — `despawn()`'s column-release path is unverified [tests/world/test_formation_spawner.gd:176-185] — fixed: added `test_stop_releases_a_held_capture_column_when_despawned_mid_telegraph`

**Defer (3):**

- [x] [Review][Defer] Asymmetric null-guards between `enter()`/`physics_process()` across all 5 captor states — not currently reachable (activate() always populates fields before any post-Enter state runs) but a latent inconsistency [enemies/captor/states/*.gd] — deferred, pre-existing style pattern, low priority cleanup
- [x] [Review][Defer] Dead/redundant null-checks in `dive_state.gd`'s `enter()` — the opening guard already covers `player_target`/`definition`, making the later inline checks unreachable-false; harmless copy-paste from the grunt idiom where the guard is looser [enemies/captor/states/dive_state.gd:28,35] — deferred, cosmetic simplification only
- [x] [Review][Defer] `capture_column.tscn` bars are baked to a hardcoded 720px height, decoupled from `Constants.BASE_RESOLUTION.y` (currently numerically equal, so correct today) [world/capture_column.tscn:8-14] — deferred, would only break on a future resolution change

**Dismissed as noise (13):** silent-skip in `_despawn_survivors` (container only ever holds duck-typed despawnable children), `FormationState` hold-duration formula vs. stale Task-4 checklist prose (intentional, AC2 still satisfied), cross-class call to `CaptureColumn._release_to_pool` (documented, mirrors the project's own deferred-release workaround), `_cheat_spawn_captor` guard-comment wording (mirrors the pre-existing `_cheat_spawn` sibling pattern verbatim), inert `formation_id = &"standard"` on `enemy_captor.tres` (unused field left at schema default), redundant `collision_mask = 0` in both scene and `_ready()` (matches the existing `enemy.tscn`/`enemy.gd` convention), "GLM-5.2" Agent Model Used provenance line (doc metadata, zero code impact), `_on_captor_died()` no-op stub (documented 2.3 seam), `state_changed` emission centralized in `_transition_to()` vs. inline-per-state Dev Notes idiom (documented, superset behavior), `CaptorDiveState`'s idempotent re-queued deferred release (acknowledged in tests, harmless), the story's own now-corrected `CaptureColumn`/Node2D gotcha text (informational — the code fix is correct), unguarded negative `telegraph_duration_s`/`capture_duration_s` in telegraph/capture states (designer-authored tuning data, not a reachable player-facing path).

---

## Dev Notes

### 🔑 Key decisions (read these first — they resolve the open forks)

1. **Captor is its own entity, NOT a variant of `enemy.tscn`.** `class_name Captor extends CharacterBody2D`. Architecture mandates `enemies/captor/` with its own `states/` (architecture.md:485); the captor's states are captor-specific (formation→telegraph, not dive), and `Enemy.activate()` is hard-coupled to `FormationDefinition`+slot, which the captor does not use. The captor **reuses the shared `components/state_machine/` State/StateMachine base** (D6: "no bespoke FSMs") and **reuses `EnemyFireSystem` + `HealthComponent` + `FactionComponent`** — but composes them itself. It reproduces the ~5-line death/pool/juice pattern from `enemy.gd` (do NOT subclass `Enemy` — you'd inherit 4 unused states + formation-coupled `activate`).

2. **Two data resources, split by concern.** `resources/enemies/enemy_captor.tres` (`EnemyDefinition`) holds base combat stats (HP, fire, movement, score) — required because `EnemyFireSystem.arm()` + `HealthComponent` take an `EnemyDefinition`. `resources/captor_tuning.tres` (`CaptorTuning`) holds the 5 FSM durations + captor-specific geometry/feel. The captor holds BOTH (`@export var definition` + `@export var tuning`), set in `captor.tscn`. This directly satisfies AC#5 ("all timings from `captor_tuning.tres`") while maximizing component reuse.

3. **Capture column locks x ONCE at telegraph start** (not continuously). `_locked_x = player_target.global_position.x` is captured in `TelegraphState.enter()` and held static for 0.7 s — this *is* the "fair dodge window." The player reads the locked column and moves out of it. (Mirrors the grunt `DiveState._captured_aim` once-capture idiom.)

4. **2.1 builds the FSM + telegraph visual ONLY.** The capture *effect* (−1 ship, clean-only, once/wave, bypass HP) is **Story 2.2**. Rescue/failed-rescue on captor death is **Story 2.3**. Captor wave integration (captor-presence in the drip) is **Story 2.8**. 2.1 leaves clean seams (Dev Notes §"Scope seams") — do NOT pre-build 2.2/2.3 mechanics.

5. **One gamble pass (default).** After dive off-screen → release captor to pool (NOT re-enter). Matches "once per wave" capture semantics and the "appears, gambles, leaves" cadence. Re-entering is a tuning/playtest option for 2.8 (Open Question D).

6. **Captor fires ONLY in formation.** Disarm fire on telegraph enter; stays disarmed through capture + dive (`fires_during_dive = false`). During telegraph/capture the threat is the COLUMN, not bullets — keeps the gamble legible.

### 📊 Tuning map — `CaptorTuning` schema (`captor_tuning.gd`)

Pure data, `@export_group` discipline. Defaults = GDD values; **the `.tres` wins at runtime** so always set them in `resources/captor_tuning.tres`.

```gdscript
class_name CaptorTuning
extends Resource

@export_group("FSM Durations")
@export var enter_duration_s: float = 1.0
@export var formation_duration_min_s: float = 3.5
@export var formation_duration_max_s: float = 5.5
@export var telegraph_duration_s: float = 0.7
@export var capture_duration_s: float = 0.4
@export var dive_duration_s: float = 1.6

@export_group("Formation")
@export var formation_row_y: float = 150.0          # the row the captor descends to
@export var side_drift_amplitude_px: float = 130.0  # match standard.tres feel
@export var side_drift_period_s: float = 3.0

@export_group("Dive")
@export var dive_aim_track_factor: float = 0.3      # 0=once-capture, 1=live-track (match standard.tres)
@export var dive_offscreen_margin_px: float = 48.0

@export_group("Capture Column")
@export var capture_column_width_px: float = 60.0   # parallel-bars span
```

`enemy_captor.tres` (EnemyDefinition) — set: `id=&"captor"`, `max_hp=60`, `score_value=0`, `collision_radius≈18`, `fire_damage=1`, `shot_kind=STANDARD`, `fire_interval_min_s=1.5`, `fire_interval_max_s=2.5`, `projectile_speed=280`, `fires_during_dive=false`, `move_speed=200`, `dive_speed_multiplier=2.5`, `silhouette_color=<distinct captor hue, hazard family>`, `silhouette_scale≈1.6`. `move_speed=200` follows the [Speed-tuning] lesson (snappy; between shielder 180 / grunt 220) — do NOT use the prototype's sluggish 60 baseline.

### 🧩 Captor entity contract — `captor.gd`

```gdscript
class_name Captor
extends CharacterBody2D

@export var definition: EnemyDefinition     # = enemy_captor.tres (set in scene)
@export var tuning: CaptorTuning            # = captor_tuning.tres (set in scene)
@export var capture_column_scene: PackedScene  # = world/capture_column.tscn

signal died(score_value: int)               # direct/local (D8) — score_value = 0
signal state_changed(state: StringName)     # direct/local (D8) — named in architecture.md:250

# @onready refs (mirror enemy.gd): _health, _faction, _state_machine, _fire, _muzzle,
#   _collision_shape, _visual, and the 5 state refs (_enter_state ... _dive_state).
# HealthBar optional via get_node_or_null("HealthBar") — add one if you want a visible HP bar.

# per-spawn state (set in activate, read by states via `owner as Captor`):
var player_target: Node2D
var rng: RandomNumberGenerator
var current_state_name: StringName          # updated on each transition (read by 2.3's death handler)
var capture_column: CaptureColumn           # held during telegraph+capture (null otherwise)

func activate(p_player_target: Node2D, p_spawn_pos: Vector2, p_rng: RandomNumberGenerator) -> void
# to_enter / to_formation / to_telegraph / to_capture / to_dive  (one-liners)
# arm_fire() / disarm_fire()   (delegate to _fire.arm(definition, rng, active))
# _on_died() / _release_to_pool()   (death path — NO score, juice + deferred release)
# _acquire_capture_column(locked_x) / _release_capture_column()   (Pool acquire/deactivate)
```

`activate()` MUST end with `_state_machine.transition_to(_enter_state)` (the FSM reset on respawn — pool contract). `global_position = p_spawn_pos` before the transition (enter state descends from it). `_ready()` = one-time setup only (collision layer from faction, mask=0, radius, visual, `health.died→_on_died` connect **once**). **Never reconnect signals in `activate()`** (they persist across pool cycles — you'd stack duplicates).

### 🎯 State math (the exact idioms to reuse)

**Every captor state** (mirror `enemies/states/*.gd`):
- `var _captor: Captor` cached in `enter()` as `_captor = owner as Captor`. Never `get_parent()`/`$` per frame (AR5/AR14).
- **Defensive null-guard** at top of `enter()`: `if _captor == null or _captor.tuning == null or _captor.definition == null: return` (the machine's `_ready` calls `enter()` before `activate()` populates per-spawn data).
- `assert(_captor.collision_mask == 0, "<State>: exact-tracking movement requires collision_mask == 0")` for any state using the velocity idiom.
- **Exact-tracking velocity idiom:** `_captor.velocity = (target - _captor.global_position) / delta; _captor.move_and_slide()`. Requires `collision_mask == 0`. Never write `.position` per frame (AR14) — only the one-time spawn placement.
- Timing via `_t += delta / <duration>; if _t >= 1.0: _captor.to_X()`.
- Transitions via the captor's `to_X()` helpers (called from `physics_process`), NOT string lookups.

**EnterState** — vertical descend:
```gdscript
# enter(): _start_y = _captor.global_position.y; _target_y = _captor.tuning.formation_row_y
# physics_process:
_t += delta / _captor.tuning.enter_duration_s
var u := minf(_t, 1.0)
var target := Vector2(_captor.global_position.x, lerpf(_start_y, _target_y, u))
_captor.velocity = (target - _captor.global_position) / delta
_captor.move_and_slide()
if _t >= 1.0: _captor.to_formation()
```
(`_captor.disarm_fire()` in enter.)

**FormationState** — sine drift + fire, then telegraph:
```gdscript
# enter(): _hold_t = 0.0; _hold_duration = rng.randf_range(min,max); _captor.arm_fire()
# physics_process:
_hold_t += delta
var drift_x := sin((_hold_t / side_drift_period_s) * TAU) * side_drift_amplitude_px
var target := Vector2(_captor.player_target.global_position.x if <center-on-player?> else <anchor_x> + drift_x, formation_row_y)
# simplest: anchor at the captor's formation x (its enter-end x); drift around it.
_captor.velocity = (target - _captor.global_position) / delta; _captor.move_and_slide()
if _hold_t >= _hold_duration: _captor.to_telegraph()
# exit() / on transition: _captor.disarm_fire()
```
Pick a formation anchor x (the x where enter ended) and drift ±amplitude around it. Do NOT drift around the live player x in formation (the lock happens in telegraph).

**TelegraphState** — lock column to player x ONCE, hold 0.7 s:
```gdscript
# enter():
_locked_x = _captor.player_target.global_position.x      # ONCE
_captor.disarm_fire()
_captor._acquire_capture_column(_locked_x)               # pool acquire + activate + visible
_captor.capture_column.set_active_visual(false)          # "winding up" look
state_changed.emit(&"telegraph")                         # _captor emits; update current_state_name
# physics_process:
_t += delta / telegraph_duration_s
if _t >= 1.0: _captor.to_capture()
# (captor holds position — no movement, or minimal drift)
```

**CaptureState** — 0.4 s active tractor (no ship effect in 2.1):
```gdscript
# enter(): _captor.capture_column.set_active_visual(true)   # bars intensify/animate
#          >>> SEAM for 2.2: detect clean player in column → ship_lost (NOT in 2.1) <<<
# physics_process:
_t += delta / capture_duration_s
if _t >= 1.0: _captor.to_dive()
```

**DiveState** — bezier toward player then off-screen (reuse grunt DiveState aim math):
```gdscript
# enter():
#   _captured_aim = player_target.global_position.x - _captor.global_position.x   # ONCE
#   _start_pos = _captor.global_position
#   _captor._release_capture_column()   # column done; release to pool (deferred if from physics)
# physics_process:
_t += delta / dive_duration_s
var u := minf(_t, 1.0)
# blend captured-aim vs live player x (dive_aim_track_factor), converge to lane:
var live_aim := _captor.player_target.global_position.x - _start_pos.x
var aim := lerpf(_captured_aim, live_aim, clampf(_captor.tuning.dive_aim_track_factor, 0.0, 1.0))
var target_x := _start_pos.x + aim
var target_y := lerpf(_start_pos.y, Constants.BASE_RESOLUTION.y + _captor.tuning.dive_offscreen_margin_px, u)
# add a bezier arc on y if you want the "swoop" (optional quadratic; u-based)
_captor.velocity = (Vector2(target_x, target_y) - _captor.global_position) / delta
_captor.move_and_slide()
if _captor.global_position.y > Constants.BASE_RESOLUTION.y + dive_offscreen_margin_px:
    _captor._release_to_pool.call_deferred()   # one pass (Open Question D)
```

### 🎨 Capture column — `world/capture_column.gd`

- `class_name CaptureColumn extends Node2D`, pooled. Child: a `parallel-bars` visual (two vertical `Polygon2D`/`Line2D` bars at ±`capture_column_width_px/2`, full screen height, centered on the column x). **Hazard family → no bright outline** (D16/ADR-6) — distinct silhouette only. Must stay readable under the existing `debug_toggle_monochrome` (validation pass, not new build).
- `activate(locked_x: float)`: `global_position = Vector2(locked_x, Constants.BASE_RESOLUTION.y * 0.5)`, `visible = true`.
- `set_active_visual(on: bool)`: wind-up vs active look (e.g. bar alpha/width, no new nodes).
- `deactivate()`: `visible = false`. Released via `Pool.release(...)` (Node2D is a CanvasItem → `Pool.release` duck-types fine; from a physics tick use `Pool.release.call_deferred(column)`).

### 🔌 Spawn path — `FormationSpawner.spawn_captor_at()`

Mirror `_spawn_enemy` (formation_spawner.gd:161–174) verbatim in shape:
```gdscript
func spawn_captor_at(pos: Vector2) -> void:
    var captor := Pool.acquire(captor_scene) as Captor
    assert(captor != null, "FormationSpawner: acquired node is not a Captor")
    _container.add_child(captor)                 # acquire → add_child → activate (load-bearing order)
    captor.activate(player, pos, _rng)            # player_target injected here, NOT via node-path
    if not captor.died.is_connected(_on_captor_died):
        captor.died.connect(_on_captor_died)      # seam for 2.3 rescue (no-op score in 2.1)
```
`_on_captor_died(score_value: int)` — in 2.1 score_value is 0; leave the handler as the seam for 2.3 (do NOT route a captor count to the HUD yet — deferred, see Out of Scope).

### 🚧 Scope seams (hand off cleanly to 2.2 / 2.3)

- **2.2 seam (capture effect):** `CaptorCaptureState` runs the 0.4 s window with a clearly-marked TODO. 2.2 adds: `if player clean AND inside capture column AND not-yet-captured-this-wave → EventBus.ship_lost + respawn`. The `CaptureColumn` gains an `Area2D` child (monitoring OFF in 2.1) for in-column detection; the player's `HurtboxComponent` (built post-1.8) is the intended reuse per its code comment.
- **2.3 seam (rescue/failed-rescue):** the captor exposes `current_state_name` (updated every transition) + emits `state_changed`. 2.3's death handler reads it: killed in `dive` → rescue (freed ship docks); killed in `formation`/else → failed-rescue (ship turns enemy). Build the accessor now; do NOT branch on it in 2.1.

### Signal boundary (D8 — do not violate)

- **Direct/local (this entity):** `Captor.died(score_value)`, `Captor.state_changed(state)`, `HealthComponent.health_changed/died`. The spawner connects `Captor.died` directly.
- **EventBus (global):** do NOT add `captor_*` / `captured_*` / `capture_column_*` signals in 2.1. (Capture's `ship_lost` ride-along is 2.2.) Per D8, the bus is for global game-flow only.

### Gotchas that will bite

- **`Pool.release.call_deferred(self)` FAILS for `CharacterBody2D`** (PhysicsBody2D typed-arg marshalling bug in 4.6). Use a **no-arg deferred method** `_release_to_pool.call_deferred()` — exactly as `enemy.gd` does. The Area2D/Node2D capture column is unaffected (`Pool.release.call_deferred(column)` is fine).
- **`@export var initial_state: State` does NOT auto-resolve from a hand-authored `.tscn`** under headless/text-scene use — `StateMachine._ready` falls back to its first `State` child. Put `EnterState` first in tree order under the captor's `StateMachine`. (Hard-won 1.4 lesson.)
- **No `_physics_process` on `Captor`** — the StateMachine child owns the tick (double-`move_and_slide` + nondeterministic order hazard). On `Pool.release`, `remove_child` detaches the subtree → tick stops automatically.
- **Shared resources are NEVER mutated.** The captor's dive aim is applied to a per-captor computed target at read time — never mutate a shared `Curve2D`/`CaptorTuning`.
- **`.tres` overrides `.gd` defaults at runtime** (memory: `tres-overrides-gd-default-for-tuning`). You MUST create `resources/captor_tuning.tres` with real values — editing `captor_tuning.gd` defaults alone has no runtime effect.
- **`godot --headless --import` after adding `class_name`s** (`Captor`, `CaptorTuning`, `CaptureColumn`, the 5 states) — GUT silently skips parse-failed scripts, so "All tests passed!" can be false. **Verify the Scripts/Tests COUNTS.** (memory: `gut-classname-reindex-silent-skip`.)
- **Wave-end cleanup:** the spawner's `_despawn_survivors()` calls `enemy.despawn()` on `_container` children. A surviving captor must also despawn cleanly — give `Captor` a `despawn()` that releases the capture column (if held) + `Pool.release(self)` synchronously (wave-end is non-physics context). Mirror `Enemy.despawn()`.
- **Do NOT port the prototype.** Re-derive tractor/capture in Godot idioms (memory: `prototype-is-reference-only`).

### Out of scope for 2.1 (do NOT build — prevents scope creep)

- **The capture EFFECT** (−1 ship, clean-only, once/wave, HP-bypass, full-HP respawn) — Story 2.2.
- **Rescue / failed-rescue** (dive-kill vs formation-kill resolution, freed-ship dock, ship-turns-enemy) — Story 2.3.
- **Docked ship / dual-fighter** — Stories 2.4–2.5.
- **Captor-presence in the procedural wave drip / onboarding cadence / captor-chance scaling** — Story 2.8 (2.1 spawns captors ONLY via the debug cheat).
- **`captors_active` HUD focus/fade feed** — the `hud_focus_model.gd` hook exists (E1 passes 0) but wiring a captor count needs a new signal/boundary call; defer to a captor-integration follow-up. (Not a 2.1 AC.)
- **Capture-column Area2D detection** (in-column player check) — 2.2.
- **Captor variety at higher tiers** (GDD Q#9) — post-systems.
- **Capture-column-telegraph debug *toggle*** (architecture.md:429) — the column is visible-by-default in 2.1, so a separate show/hide toggle is optional/low-value; build only if playtest wants it subtle.

### Performance / hot-path (NFR2, AR14)

- All captor motion in `_physics_process` (fixed 60 Hz), delta-based. Cache `_captor` in `enter()`; no per-frame allocations or `get_node()`. The capture column is the only extra CanvasItem per active captor — trivial count in 2.1 (debug-spawned, one at a time). Captor + column are pooled.

### Testing (GUT — mirror `tests/enemies/test_enemy.gd`)

- The captor FSM is Node-based (states read `owner`), so tests are **integration** (instantiate `captor.tscn`, add to tree, drive frames) — matching the established pattern, not pure-logic unit tests.
- Use a **test `CaptorTuning`** with tiny durations (0.1 s) so transitions are observable in a few frames; assert ordering + `state_changed` sequence + that the column activates during telegraph/capture and is released by dive.
- `before_each()`: `Pool.clear()`. Expect the benign exit-leak warnings (memory: `gut-exit-leak-warnings-expected`) — trust Passing/Failing counts.
- Mock `player_target` as a plain `Node2D` at a known position; assert the telegraph locks the column to that x.

### Project Structure Notes

- New folder `enemies/captor/` with `captor.gd`, `captor.tscn`, `captor_tuning.gd`, `states/{enter,formation,telegraph,capture,dive}_state.gd` — architecture.md:485 mandated, intentionally absent in 1.4.
- `world/capture_column.gd` + `.tscn` — architecture.md:493 (world domain, hazard family).
- `resources/captor_tuning.tres` — placed **flat under `resources/`** to match the established actual convention (`resources/player_tuning.tres`, `resources/juice_tuning.tres`); the schema `.gd` lives with the domain (`enemies/captor/`). NOTE: architecture.md:537 names `resources/tuning/` but that folder does not exist and migrating the two existing tuning files is out of scope — flat placement avoids a one-off inconsistency (Open Question A).
- `resources/enemies/enemy_captor.tres` — matches the `enemy_<id>.tres` convention; auto-indexed by `ContentRegistry`.
- Tests under `tests/enemies/` + `tests/world/` — mirrors domain layout.

### Project Context Rules

- **Engine:** Godot 4.6, GDScript, 2D, Compatibility renderer. Pin to 4.6.x (write forward-compatible code; no 4.7-only APIs).
- **2D physics:** `CharacterBody2D` + `move_and_slide()` (takes no args, applies delta internally — do NOT multiply velocity by delta). `collision_mask = 0` for exact-tracking enemies.
- **No bespoke FSMs (D6):** reuse `components/state_machine/` State/StateMachine.
- **Composition over inheritance:** `HealthComponent`/`FactionComponent`/`StateMachine`/`EnemyFireSystem` as child Nodes — no deep inheritance.
- **Data over code (D9):** all tunables in `.tres`; the `.tres` wins at runtime.
- **No `print()` / no try-catch:** route logging via `Log.err("enemies", msg)` (log once per state-entry via a `_logged_*` guard, not per-frame); use `assert`/`push_error` + fail-safe defaults.
- **Signal boundary (D8):** global flow → EventBus; local entity → direct signals. `captor.state_changed` + `captor.died` are LOCAL.
- **Pooled entities re-init via `activate()`, never `_ready()`.** Connections made in `_ready()` persist across pool cycles.
- **Collision layers (fixed, from `Constants`):** player=1 / enemy=2 / player_projectile=4 / enemy_projectile=8 / pickup=16. Captor body = `LAYER_ENEMY` via `FactionComponent`; mask=0. Captor projectile (formation fire) = `LAYER_ENEMY_PROJECTILE` masked to `LAYER_PLAYER` (inherited from `EnemyFireSystem`).
- **Strict collision layers/masks** to cull broadphase; keep `_on_body_entered`/area callbacks cheap.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.1] — ACs (FR13).
- [Source: _bmad-output/planning-artifacts/gdds/gdd-meridian-run-2026-06-29/gdd.md#Capture/Rescue/Sacrifice] — FSM timings, fair-dodge window (0.7 s telegraph), capture rules, captor stat row (HP 60, score "—").
- [Source: _bmad-output/planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md] — D6 (FSM), D8 (signal boundary, `captor.state_changed`), D16/ADR-6 (shape+outline, `parallel-bars` hazard), line 485 (`enemies/captor/`), line 493 (`world/capture_column`), line 387 (captor timings = `.tres`), line 424–438 (debug spawn-captor cheat), line 321 (HUD focus/fade captor hook).
- [Source: _bmad-output/implementation-artifacts/1-4-enemy-types-and-formation-dive-ai.md] — closest prior work; StateMachine contract, pooling contract, 10 hard-won Godot 4.6 gotchas, the "Captor = Story 2.1" out-of-scope note.
- [Source: enemies/enemy.gd, enemies/states/{enter,formation,dive,sweep}_state.gd] — verbatim patterns to mirror (state host-ref, exact-tracking idiom, dive aim math, sweep procedural template).
- [Source: components/state_machine/{state,state_machine}.gd] — the reusable FSM (built in 1.4, pre-named the Captor as next consumer).
- [Source: world/formation_spawner.gd] — `_spawn_enemy` (lines 161–174) = the spawn API to mirror in `spawn_captor_at`.
- [Source: systems/debug.gd:11] — the "spawn captor deferred to E2" comment 2.1 retires.
- [Source: components/hurtbox_component.gd:9] — code comment: "the future Captor capture mechanic reuses this component" (that's 2.2).

---

## Open design questions for Mrdth (review before dev — defaults are safe to implement as-is)

**A. `captor_tuning.tres` location — flat `resources/` vs `resources/tuning/`?**
Default (recommended): **flat `resources/captor_tuning.tres`** — matches the actual existing convention (`player_tuning.tres`, `juice_tuning.tres`) and avoids migrating those two files. Architecture names `resources/tuning/`; if you'd rather establish it now (and move the other two later), say so.

**B. Captor silhouette shape/color?**
Default: a **distinct captor hue** (e.g. violet/magenta, vs grunt red / shielder / bomber amber) and a recognizable silhouette (e.g. a "claw"/downward-arrow polygon). Hazard family → no bright outline. Confirm a color, or let the dev pick a readable one and you retune in `enemy_captor.tres`.

**C. Formation drift anchor — fixed x vs follow player?**
Default: **drift around a fixed formation x** (where enter ended), ±`side_drift_amplitude_px`. The lock-to-player happens only in telegraph. (If you'd prefer the captor shadows the player's x during formation, flag it — but that muddies the telegraph "lock.")

**D. One gamble pass vs re-enter loop after dive?**
Default: **one pass** — dive off-screen → release to pool. Matches "once per wave" capture + simpler. Re-entering (Galaga-style repeated passes, only the first capture can succeed) is a 2.8/playtest tuning option.

**E. Dive visual — straight convergence vs bezier swoop?**
Default: **bezier swoop** (a quadratic arc on y) for a satisfying tractor run; the aim math is the same either way. Straight-line convergence is simpler if you'd rather.

---

## Change Log

- 2026-07-09: Story created (ready-for-dev). Ultimate context-engine analysis completed — comprehensive developer guide built from epics, GDD, architecture, Story 1.4 learnings, and the live enemy/spawner/state-machine codebase (verbatim patterns extracted).
- 2026-07-09: Story 2.1 implemented (Captor Enemy & 5-State FSM). New `Captor` entity (its own `enemies/captor/` domain — NOT an `Enemy` variant) composing the shared `StateMachine`/`HealthComponent`/`FactionComponent`/`EnemyFireSystem` + a 5-state FSM (Enter→Formation→Telegraph→Capture→Dive) driven entirely by `captor_tuning.tres` (AC#5). New `CaptureColumn` world hazard (parallel-bars, hazard family, no bright outline) locked to the player's x for the 0.7 s fair-dodge window. Two data resources split by concern: `enemy_captor.tres` (EnemyDefinition — HP 60, score 0) + `captor_tuning.tres` (the 5 FSM durations + geometry). Spawn path `FormationSpawner.spawn_captor_at()` + F8 debug cheat (the ONLY captor spawn path in 2.1). Wave-end `_despawn_survivors` made duck-typed so a surviving captor collects cleanly. 244/244 GUT tests pass (+20 new: 10 captor FSM / 4 column / 3 tuning / 3 spawn+debug), 0 regressions vs the 224 baseline; headless boot clean; autoload registry unchanged at 11. Clean seams left for 2.2 (capture effect) + 2.3 (rescue). Status → review. The formal F8 in-editor playtest is Mrdth's review step.
- 2026-07-09: Playtest note — the captor dives immediately after the capture window. The success-conditional post-capture dive delay (hold on success, immediate on miss) deferred to Story 2.2 per Mrdth (capture is non-functional in 2.1, so dive timing is a placeholder until 2.2's detection lands). Recorded in the `CaptureState` seam comment + the Deferred notes; no 2.1 behavior change.

---

## Dev Agent Record

### Agent Model Used

Claude Code (GLM-5.2[1m] per session environment)

### Debug Log References

- `godot --headless --import` after adding the `Captor` / `CaptorTuning` / `CaptureColumn` class_names + the new scenes/states — all three indexed cleanly (verified in `.godot/global_script_class_cache.cfg`); the 5 captor states intentionally have NO class_name (referenced by path in `captor.tscn`, avoiding a collision with the grunt states' global `EnterState`/`FormationState`/`DiveState`).
- First GUT run surfaced 2 failures, both resolved:
  1. `test_state_changed_emits_in_order` — misused GUT's `get_signal_parameters` (it returns the LAST emit's params, not all emits). Rewrote to a recorder lambda connected BEFORE `activate` so the initial "enter" emit is captured (refactored `_make` into `_setup`/`_activate` to allow a pre-activate signal connect).
  2. `test_dive_releases_captor_to_pool` — the CharacterBody2D deferred-release marshalling bug ("Cannot convert argument 1 from Object to Object") ALSO hits the Node2D `CaptureColumn`, contradicting the Story-2.1 gotcha's "Node2D is unaffected" claim. Fixed by adding a no-arg `_release_to_pool()` to `CaptureColumn` and deferring THAT (mirrors `Enemy`/`Captor`'s own release) instead of `Pool.release.call_deferred(column)`. Corrected the gotcha note in both `captor.gd` and `capture_column.gd`.
- Final GUT: `godot --headless -s addons/gut/gut_cmdln.gd` → **29 scripts, 244/244 tests pass, 704 asserts** (0 regressions vs the 224 baseline; +20 new tests across captor FSM / capture-column / captor-tuning / spawn-path / debug-cheat). Verified the Scripts/Tests COUNTS (not just "All tests passed!") — GUT's silent-skip trap is clear.
- Headless game boot (`godot --headless --path .`, main scene `world/arena.tscn`, 6 s run): clean — no ERROR / SCRIPT ERROR / captor / parse lines; the arena boots, the wave plays, the `captor_scene` wiring resolves. Autoload registry unchanged at 11.

### Completion Notes List

- **All 6 ACs addressed.** AC1: `CaptorEnterState` descends from the off-screen-top spawn to `formation_row_y` over `enter_duration_s` (1.0 s) — verified by `test_captor_descends_to_formation_row_on_enter`. AC2: `CaptorFormationState` side-to-side sine drift around a fixed formation anchor + armed fire, randomized hold `formation_duration_min_s..max_s` (3.5–5.5 s) → telegraph. AC3: `CaptorTelegraphState` locks the `CaptureColumn` to the player's x ONCE and holds `telegraph_duration_s` (0.7 s) — the fair-dodge window — verified by `test_capture_column_active_during_telegraph_and_capture`. AC4: `CaptorCaptureState` runs `capture_duration_s` (0.4 s) of active tractor (column intensifies); `CaptorDiveState` runs a `dive_duration_s` (1.6 s) bezier swoop (quadratic ease-in on y) reusing the grunt once-captured-aim + `dive_aim_track_factor` blend, then releases to the pool (one pass). AC5: every state duration + geometry reads from `captor_tuning.tres` — verified by `test_captor_tuning` (the `.tres` carries the GDD values; the `.gd` defaults are inert). AC6: pooled + HP-based killable (60 HP), death = local `died(0)` + `JuiceFx.enemy_killed` + deferred pool release (no-arg method — the PhysicsBody2D marshalling workaround) + held-column release; the ONLY spawn path is the F8 debug cheat (`debug_cheat_spawn_captor`).
- **Decisions resolved as written:** Captor is its OWN entity (NOT an `Enemy` variant — `Enemy.activate` is formation-coupled; subclassing would inherit 4 unused states); reuses the shared `components/state_machine/` + `EnemyFireSystem`/`HealthComponent`/`FactionComponent`. Two data resources split by concern (`EnemyDefinition` for combat stats + `CaptorTuning` for FSM/geometry). Column locks x ONCE at telegraph (the fair-dodge window). 2.1 ships the FSM + telegraph visual ONLY (clean seams for 2.2 capture effect + 2.3 rescue). One gamble pass (dive off-screen → release). Fires ONLY in formation (disarmed enter/telegraph/capture/dive). Bezier swoop dive (Open Q E default). Tuning `.tres` placed flat under `resources/` (Open Q A default — matches `player_tuning.tres`/`juice_tuning.tres`). Violet distinct silhouette + downward-arrow polygon (Open Q B). Formation drifts around a fixed anchor x, NOT the live player (Open Q C).
- **`current_state_name` is authoritative + `state_changed` emits on EVERY transition** (enter→formation→telegraph→capture→dive) via the captor's `to_X()` transition helpers — cleaner than emitting inline in 2 states, and load-bearing for the 2.3 rescue branch (dive-kill → rescue). Verified by `test_state_changed_emits_in_order`.
- **Wave-end cleanup fixed:** `_despawn_survivors` is now duck-typed (`child.has_method("despawn")`) so a surviving captor (not an `Enemy`) collects cleanly instead of crashing on the old `(child as Enemy).despawn()` cast — verified by `test_stop_despawns_a_surviving_captor`.
- **Deferred (left for their owning stories):** the capture EFFECT (−1 ship, clean-only, once/wave, HP-bypass) = 2.2 (marked seam in `CaptorCaptureState`); the **success-conditional post-capture dive delay** (Mrdth playtest note 2026-07-09: on a successful capture, hold briefly before the dive — the captor "reels in"; on a miss, dive immediately) = 2.2, flagged in the `CaptureState` seam — 2.1 dives unconditionally right after the 0.4 s window because capture is non-functional; rescue/failed-rescue = 2.3 (the `current_state_name` accessor + `_on_captor_died` seam are built now, not branched on); captor-presence in the wave drip / onboarding cadence = 2.8 (2.1 spawns ONLY via the debug cheat); `CaptureColumn` Area2D in-column detection = 2.2; `captors_active` HUD feed = a captor-integration follow-up (not a 2.1 AC).
- **The formal F8 in-editor playtest (Task 11.2) is Mrdth's review step** — the FSM is mechanically verified (transitions, timing, column, release, death) via GUT + a clean headless boot, but the "readable/fair/dodgeable" feel verdict is the in-editor playtest call (mirrors how 1.8's feel-gate was Mrdth's).

### File List

**New (15)** (Godot's auto-generated `*.uid` sidecars not counted):
- `enemies/captor/captor.gd` + `enemies/captor/captor.tscn` — the Captor entity (CharacterBody2D) + its instance-style scene (composes the shared components + the 5-state StateMachine; holds `definition` + `tuning` + `capture_column_scene`).
- `enemies/captor/captor_tuning.gd` — `CaptorTuning` resource schema (the 5 FSM durations + captor geometry; `@export_group` discipline).
- `enemies/captor/states/enter_state.gd`, `formation_state.gd`, `telegraph_state.gd`, `capture_state.gd`, `dive_state.gd` — the 5 captor FSM states (no class_name; referenced by path; reuse the exact-tracking velocity idiom + the grunt dive-aim math).
- `world/capture_column.gd` + `world/capture_column.tscn` — the `CaptureColumn` pooled world hazard (parallel-bars, hazard family; `activate`/`set_active_visual`/`deactivate`/`_release_to_pool`).
- `resources/captor_tuning.tres` — the `CaptorTuning` INSTANCE (GDD timings; wins at runtime).
- `resources/enemies/enemy_captor.tres` — the `EnemyDefinition` for the captor (id `captor`, HP 60, score 0, `fires_during_dive=false`, move_speed 200; auto-indexed by ContentRegistry).
- `tests/enemies/test_captor_fsm.gd`, `tests/enemies/test_captor_tuning.gd`, `tests/world/test_capture_column.gd` — the GUT tests (integration + unit).

**Modified (6)** (plus `sprint-status.yaml` status + this story file's own record):
- `world/formation_spawner.gd` — +`captor_scene` @export + `spawn_captor_at(pos)` + `_on_captor_died` (2.3 seam); `_despawn_survivors` duck-typed so a surviving captor collects cleanly.
- `world/arena.tscn` — wire `FormationSpawner.captor_scene = res://enemies/captor/captor.tscn`.
- `systems/debug.gd` — +`_cheat_spawn_captor()` (F8, guarded to WaveActiveState, spawns off-screen above the player) + the `_unhandled_input` branch; retired the "spawn captor deferred to E2" comment.
- `project.godot` — +`debug_cheat_spawn_captor` Input Map action (F8 / physical_keycode 4194339; keyboard-only — the review-accepted debug-action exception).
- `tests/world/test_formation_spawner.gd` — +`test_spawn_captor_at_activates_and_connects_died` + `test_stop_despawns_a_surviving_captor`.
- `tests/systems/test_debug.gd` — +`test_cheat_spawn_captor_spawns_one_captor_above_player`; `debug_cheat_spawn_captor` added to the unbound-noop test.

**Deleted (0).**
