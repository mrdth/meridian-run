---
baseline_commit: fdd88655fc43e52e781f47f89925b69948c67d9e
---

# Story 1.4: Enemy Types & Formation/Dive AI

Status: in-progress

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want Grunt/Shielder/Bomber enemies to enter in formations and dive,
so that each wave is a readable, escalating threat.

## Acceptance Criteria

*(Source: `planning-artifacts/epics.md` Story 1.4 — FR30, FR43, FR44, FR45 · AR5, AR6, AR8)*

1. **Given** `EnemyDefinition` `.tres` for Grunt/Shielder/Bomber, **When** a wave spawns, **Then** each enemy loads its GDD stats via `ContentRegistry` (no `load("res://...")` in gameplay code).
2. **Given** a wave, **When** enemies enter, **Then** they fly to formation rows then execute dive patterns (Galaga-lineage) via **the shared state/pattern system**, on `enemy`/`enemy_projectile` collision layers.
3. **Given** wave N, **Then** it spawns 4+N enemies (capped at 12) as formation pulses across the wave's duration — a spawn budget, not a kill quota (FR30; the wave ends on a timer [Wave-1]).
4. **Given** enemies fire, **Then** Grunt/Shielder fire standard (1 dmg) shots; Bomber fires heavy (2 dmg) telegraphed shots.

**Implicit / end-to-end requirements (the dev agent owns these — an implementation must leave the system working, not just satisfy the letter of the ACs):**
- The existing player vertical-fire system (Story 1.3) must still kill these enemies: the player projectile's `body_entered` hit path must detect a `CharacterBody2D` enemy on `LAYER_ENEMY` and apply `take_damage()` to its `HealthComponent`. Do **not** regress Story 1.3.
- Enemies must be killable by player fire, must damage the player with their own fire, and must return to the `Pool` on death/off-screen — never `queue_free()`.

---

## Tasks / Subtasks

### Task 1 — `EnemyDefinition` schema + real `ContentRegistry` (AC: #1)

- [x] 1.1 Create `enemies/enemy_definition.gd` — `class_name EnemyDefinition extends Resource`. Field set (with literal `@export` defaults — no autoload refs in defaults so the inspector parses; mirror `player/player_tuning.gd`):
  - `@export var id: StringName` — registry key (`"grunt"` / `"shielder"` / `"bomber"`)
  - `@export var max_hp: int = 30` (Grunt 30 / Shielder 50 / Bomber 80)
  - `@export var score_value: int = 100` (Grunt 100 / Shielder 150 / Bomber 300)
  - `@export var fire_damage: int = 1` (Grunt/Shielder 1 / Bomber **2**)
  - `@export var shot_kind: ShotKind = ShotKind.STANDARD` — `enum ShotKind { STANDARD, HEAVY }` (HEAVY = telegraphed, Bomber only)
  - `@export var fire_interval_min_s: float = 1.2` (Grunt 1.2 / Shielder 0.9 / Bomber 1.6)
  - `@export var fire_interval_max_s: float = 2.4` (Grunt 2.4 / Shielder 1.8 / Bomber 2.8)
  - `@export var move_speed: float = 60.0` (Grunt 60 / Shielder 50 / Bomber 80 — formation drift + dive base)
  - `@export var dive_speed_multiplier: float = 2.0` (data-tunable; multiplies `move_speed` during dive)
  - `@export var heavy_windup_s: float = 0.0` (Bomber telegraph windup; 0 for Grunt/Shielder — see Dev Notes §"Bomber telegraph")
  - `@export var fires_during_dive: bool = true` (data flag — Galaga-lineage default)
  - `@export var formation_id: StringName = &"standard"` (which `FormationDefinition` this enemy uses)
  - `@export var projectile_speed: float = 280.0` (data-tunable — **slower than the player's 620 px/s so fire is dodgeable**; see Task 4.3)
  - `@export var silhouette_color: Color = Color(1.0, 0.24, 0.35)` (hazard calm `#FF3D5A` default; data-tunable per UX)
  - **Do NOT put `projectile_scene` here** — the projectile scene refs belong on `EnemyFireSystem` (Task 4.2), mirroring `player/fire_system.gd`. The definition holds *stats* (damage, shot_kind, speed), the fire system holds *scenes*.
  - `@export var collision_radius: float = 14.0` (CircleShape2D radius — data-tunable, ~12–18 px)
  - Group exports with `@export_group` headers (Identity / Combat / Fire / Movement / Visual), mirroring `player_tuning.gd`'s section-comment style.
- [x] 1.2 Create `.tres` instances in `resources/enemies/` — `grunt.tres`, `shielder.tres`, `bomber.tres` — each `script_class="EnemyDefinition"`, with the GDD stat values above. **Filename prefix `enemy_*` is the project convention** (arch line 577) — name them `enemy_grunt.tres` / `enemy_shielder.tres` / `enemy_bomber.tres`. Set each `id` to match its registry key. **Do not hand-author `uid=`** — let Godot regenerate on first editor open (accepted non-issue from 1.1/1.2 reviews).
- [x] 1.3 Implement the real `systems/content_registry.gd` `get_enemy_def(id)`. Replace the stub (`get_enemy_def` currently returns `null`). Pattern (arch lines 361–367, AR11 fail-safe):
  - At `_ready()`: scan `res://resources/enemies/` via `DirAccess`, load each `*.tres` as `EnemyDefinition`, index by `definition.id` into a `Dictionary`. Cache a grunt fallback (load `enemy_grunt.tres` once into `_grunt_fallback`).
  - `func get_enemy_def(id: StringName) -> EnemyDefinition:` → return indexed def; on miss, `Log.err("enemies", "missing EnemyDefinition '%s' — grunt fallback" % id)` and return `_grunt_fallback`. Never return `null`, never hard-crash (AR11).
  - Change the stub's return type from `Resource` to `EnemyDefinition`; drop the `_ready()` "stub" warning.
- [x] 1.4 Unit test `tests/enemies/test_enemy_definition.gd` (pure-logic): `.tres` load round-trip for all three; `id` matches filename; stats equal GDD baselines; `get_enemy_def("grunt")` returns non-null; `get_enemy_def("nonexistent")` returns the grunt fallback (not null).

### Task 2 — Reusable `StateMachine` + `FormationDefinition` (the "shared state/pattern system") (AC: #2)

- [x] 2.1 Build the reusable FSM under `components/state_machine/`:
  - `components/state_machine/state.gd` — `class_name State extends Node`. API: `func enter(_msg: Dictionary = {}) -> void`, `func exit() -> void`, `func physics_process(_delta: float) -> void`, `func process(_delta: float) -> void`. States read their owner via a typed reference set on enter (e.g. `var enemy: Enemy`), NOT via `get_parent()` string lookups.
  - `components/state_machine/state_machine.gd` — `class_name StateMachine extends Node`. API: `@export var initial_state: State`; `var current_state: State`; in `_ready()` validate `initial_state != null`, set `current_state`, call `current_state.enter()`; `_physics_process(delta)` forwards to `current_state.physics_process(delta)`; `func transition_to(target: State, msg: Dictionary = {}) -> void` (exit current → set → enter target). Cache states if needed; do **not** `find_child` per frame.
  - This pattern is reused by Captor FSM (Story 2.1) and HUD focus/fade (Story 1.7, UX S1) — build it cleanly and generically; no enemy-specific logic here.
- [x] 2.2 Create `enemies/formation_definition.gd` — `class_name FormationDefinition extends Resource`. Data-driven formation + dive choreography (fields not pinned in arch — derive from GDD §Run Structure line 166 + FR30):
  - `@export var slots: Array[Vector2]` — formation positions (relative to a formation anchor / row). Author a small grid (e.g. 2 rows × 4 cols). **Formation row Y/spacing are NOT in the GDD** (the prototype's `y=110` is reference-only) — author as data here; tune in playtest.
  - `@export var entry_curve: Curve2D` — entry path (off-screen top → formation slot). Bezier.
  - `@export var dive_curve: Curve2D` — dive path (formation slot → off-screen bottom), bezier, Galaga-lineage arc.
  - `@export var formation_hold_s: float` — time in formation before diving (3.5–5.5 s band, per captor's formation-phase precedent).
  - `@export var side_drift_amplitude_px: float` / `@export var side_drift_period_s: float` — side-to-side drift in formation (Galaga-lineage).
  - `@export var entry_duration_s: float` / `@export var dive_duration_s: float`.
- [x] 2.3 Create `.tres` instance `resources/formations/standard.tres` with sane v0.1 values (one formation pattern for E1's authored wave). Adding formations later = add a `.tres`, zero code (D9).
- [x] 2.4 Unit test the StateMachine (pure-ish logic: transition enter/exit ordering, no crash on null guard) and `FormationDefinition` (load round-trip, slot count, curve non-empty). Use `tests/components/test_state_machine.gd` and `tests/enemies/test_formation_definition.gd`.

### Task 3 — Enemy scene, script, AI states, pooling, death (AC: #1, #2)

- [x] 3.1 Create `enemies/enemy.tscn` + `enemies/enemy.gd` — **`CharacterBody2D`** root (`class_name Enemy`), meaningful name per variant scene (`Grunt`/`Shielder`/`Bomber`). Child composition (mirror `player/player.tscn`):
  - `Visual : Polygon2D` — neon-vector silhouette, **hazard family: NO bright outline** (D16/ADR-6). Color from `EnemyDefinition.silhouette_color`.
  - `CollisionShape2D` — `CircleShape2D` radius from `EnemyDefinition.collision_radius`.
  - `HealthComponent : Node` — script `health_component.gd`. **The node MUST be named exactly `HealthComponent`** (the player projectile looks it up via `body.get_node_or_null("HealthComponent")` — the forward-compat contract from Story 1.3, `projectile.gd:65–68`).
  - `FactionComponent : Node` — `faction = Faction.ENEMY` set in the inspector (defaults to PLAYER — easy bug; verify in tests).
  - `Muzzle : Marker2D` — enemy fire origin (below the silhouette, facing the player).
  - `StateMachine : Node` — script `state_machine.gd`, `initial_state = EnterState`.
  - `EnemyFireSystem : Node` — script `enemy_fire_system.gd` (Task 4).
  - State children: `EnterState`, `FormationState`, `DiveState` (each `State`).
  - `collision_layer` set in `enemy.gd._ready()` via `collision_layer = _faction.get_collision_layer()` (= `Constants.LAYER_ENEMY` = 2 — single source of truth, mirror `player.gd:23`). `collision_mask = 0` (enemies don't physically collide/block — see Dev Notes §"Why CharacterBody2D + mask 0").
- [x] 3.2 `enemy.gd` public API + pooling re-init (mirror `player/projectile.gd`'s `activate()` pattern exactly):
  - `@export var definition: EnemyDefinition` (inspector-assigned per variant).
  - `signal died(score_value: int)` — direct local signal (D8: entity-local signals stay direct, NOT on EventBus).
  - `_ready()` (runs ONCE — one-time setup only): cache `@onready var _health: HealthComponent = $HealthComponent`, `_faction: FactionComponent = $FactionComponent`, `_state_machine: StateMachine = $StateMachine`, `_fire: EnemyFireSystem = $EnemyFireSystem`, `_muzzle: Marker2D = $Muzzle`; set `collision_layer`; connect `_health.died` to `_on_died` ONCE (persists across pool cycles — never reconnect in `activate()`).
  - `func activate(formation_def: FormationDefinition, slot_index: int, rng: RandomNumberGenerator) -> void` — **the pool re-init entry**. Resets per-spawn state: `current_hp` (via `_health.reset_to_full()` then set `_health.max_hp`? — see Dev Notes §"HP wiring"), re-enable `set_physics_process(true)`/`visible = true`, pass `definition`/`formation_def`/`slot`/`rng` into the states + fire system, reset the StateMachine to `EnterState`. All per-spawn state lives here — never in `_ready()`.
  - `_physics_process(delta)` — delegate movement to the current State (the State computes a target position from the active `Curve2D`/drift and the enemy sets `velocity` then `move_and_slide()`, OR for curve-following sets `velocity` toward the sampled point — see Dev Notes §"Movement: curve-following with velocity"). Do NOT write `.position` directly (AR14: drive physics bodies via velocity).
  - `_on_died()` — emit `died(definition.score_value)`; `Pool.release.call_deferred(self)` (deferred — death originates in a physics callback).
- [x] 3.3 The three AI states (each `extends State`, in `enemies/states/`):
  - `enter_state.gd` — `enter()`: capture formation slot position; advance parametric `t` over `entry_duration_s`; set enemy velocity toward `entry_curve.sample_baked(t)`; on completion → `transition_to(formation_state)`.
  - `formation_state.gd` — `enter()`: arm fire system (pass `rng`, `definition.fire_interval_*`); start `formation_hold_s` timer (accumulate in `physics_process`, no Timer node — mirror `fire_system.gd` cooldown). Apply side-to-side drift (sine of elapsed time × `side_drift_amplitude` / `period`) anchored to the slot. On `formation_hold_s` elapsed → `transition_to(dive_state)`.
  - `dive_state.gd` — `enter()`: capture player x ONCE at dive-start (read from the formation spawner / injected player ref — do NOT reach across domains via node paths); compute a per-enemy horizontal aim offset and apply it when sampling `dive_curve` (see Dev Notes §"Movement" — **do NOT mutate the shared curve**); advance `t` over `dive_duration_s`; set velocity along the curve at `move_speed * dive_speed_multiplier`. Fire during dive if `definition.fires_during_dive`. When the enemy passes off-screen bottom (`global_position.y > Constants.BASE_RESOLUTION.y + margin`) → `Pool.release.call_deferred(self)` (left the screen, not a death — no score).
- [x] 3.4 Variant scenes `enemies/grunt.tscn`, `shielder.tscn`, `bomber.tscn` — inherit `enemy.tscn`; set `definition` to the matching `EnemyDefinition` `.tres`; customize `Visual` silhouette per type (distinct hazard-family shapes — see Dev Notes §"Silhouettes"); set `FactionComponent.faction = ENEMY`.
- [x] 3.5 Integration test `tests/enemies/test_enemy.gd` (mirror `tests/player/test_projectile.gd`'s pool-fixture style): each variant scene has `collision_layer == Constants.LAYER_ENEMY`; `HealthComponent` child named exactly `"HealthComponent"` with correct `max_hp`; `FactionComponent.faction == Faction.ENEMY`; `take_damage()` decrements HP, emits `health_changed`, emits `died` exactly once at 0; pool round-trip (`acquire` → `activate` → release → re-`acquire` works, no stacked signal connections); a dummy player projectile hitting the enemy applies damage via the existing `body_entered` path (regression guard for Story 1.3).

### Task 4 — Enemy fire system + enemy projectile (AC: #4)

- [x] 4.1 Create `enemies/enemy_projectile.tscn` + `enemies/enemy_projectile.gd` — `Area2D`, `class_name EnemyProjectile`. **Clone the structure of `player/projectile.gd`/`.tscn`** but invert layer/mask + direction:
  - `collision_layer = Constants.LAYER_ENEMY_PROJECTILE` (= 8); `collision_mask = Constants.LAYER_PLAYER` (= 1).
  - `activate(spawn_pos, speed, damage)` (same signature shape); `_physics_process(delta)`: `global_position.y += _speed * delta` (DOWNWARD); despawn when `global_position.y >= Constants.BASE_RESOLUTION.y` → `Pool.release(self)`.
  - `_on_body_entered(body)`: `_consumed` guard → `body.get_node_or_null("HealthComponent")` → `take_damage(_damage)` → `Pool.release.call_deferred(self)`. (Symmetric to the player projectile — the Player has a `HealthComponent` child, so this works without touching the player.)
  - `Visual : Polygon2D` — `small-pellet` silhouette, hazard family, NO bright outline (UX). Bomber's heavy shot = a distinct larger pellet in `colors.climax-hazard` (amber) — realize via a second visual or a `heavy` bool on the projectile; keep it in the hazard family.
- [x] 4.2 Create `enemies/enemy_fire_system.gd` — `class_name EnemyFireSystem extends Node`. **Mirror `player/fire_system.gd`** (cooldown accumulator in `_physics_process`, NO Timer node, `Pool.acquire` + `activate`):
  - `@export var projectile_scene: PackedScene` (the **standard** enemy projectile scene — owns the scene refs, NOT `EnemyDefinition`). `@export var heavy_projectile_scene: PackedScene` (optional — the Bomber's heavy/telegraphed pellet; if null, the standard scene is reused with a heavy flag). Public `var projectile_parent: Node2D` wired by `enemy.gd._ready()` to the world-space container (NOT under the enemy — transform independence, Decision #8 from Story 1.3).
  - `func arm(definition: EnemyDefinition, rng: RandomNumberGenerator, active: bool) -> void` — enable/disable firing per AI state (fire only in Formation/Dive, not Enter).
  - `_physics_process(delta)`: decrement `_cooldown`; clamp at 0 (avoid the unbounded-negative drift flagged in 1.3 review); when armed and `_cooldown <= 0`: `_spawn()`; set `_cooldown = rng.randf_range(definition.fire_interval_min_s, definition.fire_interval_max_s)`.
  - `_spawn()`: `var p := Pool.acquire(projectile_scene) as EnemyProjectile`; `p.activate(_muzzle.global_position, definition's projectile_speed, definition.fire_damage)`; `projectile_parent.add_child(p)`. For Bomber HEAVY shots, pass the heavy flag/windup.
- [x] 4.3 `projectile_speed` already lives on `EnemyDefinition` (Task 1.1, default 280 px/s). The fire system reads `definition.projectile_speed` when activating each projectile. Confirm it's dodgeable relative to the player's 620 px/s in playtest.
- [x] 4.4 Integration tests `tests/enemies/test_enemy_projectile.gd` + `tests/enemies/test_enemy_fire_system.gd`: projectile `collision_layer == LAYER_ENEMY_PROJECTILE`, `collision_mask == LAYER_PLAYER`; moves DOWNWARD; despawns off-screen; damages a dummy player fixture via `HealthComponent`; pool round-trip; fire system respects cooldown interval bounds; Bomber heavy shot carries `fire_damage == 2`.

### Task 5 — Minimal formation spawner (AC: #2, #3) — *full wave lifecycle is Story 1.8*

- [x] 5.1 Create `world/formation_spawner.gd` (+ minimal node in `arena.tscn`, or instantiate from a thin `arena.gd`). Responsibilities (1.4 scope only):
  - Owns a world-space enemy container (`Node2D` added under Arena) — enemies and enemy projectiles parent here, NOT under the spawner (transform independence). Mirror the projectile-parent pattern from Story 1.3.
  - Given wave N: compute spawn budget `min(4 + N, 12)` (FR30). Distribute as **formation pulses** across a configurable `wave_duration_s` (data-tunable; the actual timer-expiry wave-end is Story 1.8 — here just demonstrate the budget spans a duration, not all-at-once).
  - Per pulse: pick enemy variant scenes by an authored mix (data: early pulses Grunt-only, introduce Shielder, Bomber rare — matches Bomber's 300-score/2-dmg weight), `Pool.acquire` each variant scene, `activate(formation_def, slot_index, rng)`, add to container.
  - Provide the player x to diving enemies via injection (the spawner holds a player ref or reads player position and passes it into `dive_state` on dive-start) — do NOT have enemies reach across domains with `../../Player`.
- [x] 5.2 Connect enemy `died(score_value)` → accumulate run score → `EventBus.score_changed(total)` (score is a derived read-only state signal, D8). Collect/despawn any surviving enemies when the authored wave ends (minimal — the full `wave_intro → active → completed → reward → next_wave` FSM is Story 1.8).
- [x] 5.3 Author the E1 wave as **data** (a small pulse schedule), not hardcoded spawn calls — so Story 4.x's `RunGenerator` can later produce the same shape. Keep it minimal but shaped like the GDD pulse schema (composition + entry timing + dive pattern).
- [x] 5.4 Integration test `tests/world/test_formation_spawner.gd`: wave N=1 → 5 enemies; N=8+ → capped at 12; spawns arrive as pulses across the duration (not instantaneous); each spawned enemy enters → forms → dives without errors; `score_changed` fires on enemy death.

### Task 6 — Regression, housekeeping, verification

- [x] 6.1 Run `godot --headless --import` once (registers new `class_name`s: `EnemyDefinition`, `FormationDefinition`, `StateMachine`, `State`, `Enemy`, `EnemyProjectile`, `EnemyFireSystem`) — the established gotcha from Story 1.1/1.2 reviews.
- [x] 6.2 Run the full GUT suite headless: `godot --headless -s addons/gut/gut_cmdln.gd`. All prior tests (1.1–1.3) must still pass — especially `tests/player/test_projectile.gd` (the player projectile must still hit a `CharacterBody2D` enemy). `before_each()` in every new enemy test file calls `Pool.clear()`.
- [x] 6.3 Remove the `.gdkeep` placeholders from `enemies/` and `tests/enemies/` (now populated). Confirm `components/state_machine/` and `resources/enemies/`, `resources/formations/` exist.
- [x] 6.4 Manual/visual check in the editor: launch the Arena, confirm enemies enter in formation, drift, dive off-screen, fire downward; player fire kills them; enemy fire damages the player's HP. (No hit-flash/particles yet — those are Story 1.6.)

---

## Dev Notes

### 🔑 Key decisions (read these first — they resolve the open forks the architecture left to this story)

1. **Enemy body = `CharacterBody2D`, `collision_mask = 0`.** The existing player projectile detects targets via `body_entered` (`projectile.gd:23`), which fires for `CharacterBody2D`/`RigidBody2D` bodies but **NOT for `Area2D`**. Making enemies `Area2D` would force reworking the player projectile to `area_entered` — a regression to Story 1.3 and scope creep. `CharacterBody2D` keeps the existing hit path working untouched. `collision_mask = 0` means the enemy body neither pushes nor is pushed (like the player today) — it doesn't physically collide with the player, so it won't fight the player's post-`move_and_slide` clamp (the 1.2-deferred concern). Damage in 1.4 flows **only via projectiles**, not body contact.
2. **No `HitboxComponent`/`HurtboxComponent` in 1.4.** Keep the existing name-based `HealthComponent` lookup (`body.get_node_or_null("HealthComponent")` → `take_damage()`). This is explicitly forward-compatible per Story 1.3 dev notes (`projectile.gd:65–68`: "the real HurtboxComponent-mediated wiring lands in 1.4; this node-name lookup is forward-compatible"). The formal Area2D hitbox components defer to when multi-shape hitboxes are needed. **Enemy projectiles use the identical convention against the player.**
3. **Build the reusable `components/state_machine/` now.** Story 1.4 AC2 names "**the** shared state/pattern system" (definite article = a specific named system). Arch rule (line 735): *"no bespoke per-entity FSMs — one reusable pattern"*, listing consumers: Captor (Story 2.1), wave lifecycle, HUD focus/fade (Story 1.7). Building it now serves three stories and avoids throwaway code. Grunt/Shielder/Bomber each compose `EnterState`/`FormationState`/`DiveState` from it; the Captor later adds `TelegraphState`/`CaptureState` to the same pattern with zero rework.
4. **Movement patterns = `Curve2D` resources** (pure data, sampled in `_physics_process`), NOT `Path2D`/`PathFollow2D` (which couple movement to scene-tree Path nodes and don't compose with pooled many-enemy scenarios or the velocity discipline) and NOT `Tween`s (one-shot, not reusable/data-driven). `Curve2D`s live in `FormationDefinition` `.tres` (data-driven, D9), each pooled enemy holds its own parametric `t`.
5. **1.4 builds a minimal `world/formation_spawner.gd`; the full wave lifecycle FSM is Story 1.8.** 1.4 needs *something* that emits the 4+N-capped formation pulses to satisfy AC3. 1.8 wraps it in the real `wave_controller` lifecycle (`wave_intro → active → completed → reward → next_wave`, timer-expiry end, HP heal, replay). Name it `formation_spawner` (not `wave_controller`) to keep the boundary clean.
6. **E1 is authored, not procgen.** `SeedManager` is a stub (real API is Story 4.1). Do **NOT** call `SeedManager.stream("enemy_spawn")` — it logs a warning and returns a stub RNG. Pass a local `RandomNumberGenerator` (seeded deterministically by the spawner) into each enemy's `activate()` for fire-interval variance and dive curve selection. Never use global `randi()`/`randf()` (AR4, even while SeedManager is stubbed). Real seeded variance lands in 4.1.

### 📊 Enemy stat table (GDD §"Enemy Design and AI" lines 240–244 / FR43 — authoritative)

| Field | Grunt | Shielder | Bomber | Source |
|---|---|---|---|---|
| `max_hp` | 30 | 50 | 80 | FR43 / GDD 240 |
| `score_value` | 100 | 150 | 300 | FR43 / GDD 240 |
| `fire_damage` | 1 | 1 | **2** | GDD 108 (damage model) + FR43 |
| `shot_kind` | STANDARD | STANDARD | **HEAVY** (telegraphed) | GDD 108 |
| `fire_interval_min_s` | 1.2 | 0.9 | 1.6 | FR43 |
| `fire_interval_max_s` | 2.4 | 1.8 | 2.8 | FR43 |
| `move_speed` (px/s) | 60 | 50 | 80 | FR43 |
| Formation drift behavior | side-to-side + periodic fire (same for all three — Galaga-lineage) | | | GDD 141 (captor formation-phase precedent) |

**Damage/HP scaling is intentional — do NOT "fix" it.** The player projectile deals **10 dmg** (set in Story 1.3, `resources/player_tuning.tres`). Enemy HP is 30/50/80. So Grunt = 3 hits, Shielder = 5 hits, Bomber = 8 hits. This 10× scaling (vs the prototype's 1 dmg / 3 HP) preserves the prototype's 3-hit-kill feel while giving integer tuning headroom. Enemy HP = GDD baselines; player damage stays 10. No reconciliation needed.

### Bomber telegraph

GDD says Bomber fires "heavy (2 dmg) telegraphed" but commits **no duration** — the 0.7 s telegraph in the GDD is the **Captor capture-column** only (GDD line 141), NOT a Bomber shot. For v0.1: add the data field `heavy_windup_s` (default 0 for Grunt/Shielder; a small tunable value for Bomber), and realize "telegraphed" primarily as a **distinct projectile silhouette/color** (larger pellet, `colors.climax-hazard` amber) per the UX hazard family. Do NOT conflate with the captor's capture-column telegraph. Revisit the windup window in playtest.

### Movement: curve-following with velocity

Enemies are `CharacterBody2D` (AR14: drive via `velocity` + `move_and_slide()`, never write `.position` per frame, never multiply velocity by delta — `move_and_slide` applies it internally). For curve-following: each frame, sample the active `Curve2D` at the advanced parametric `t` to get a target point, set `velocity = (target_point - global_position).normalized() * speed`, then `move_and_slide()`. With `collision_mask = 0` there's nothing to slide against, so the body simply translates — no fighting the physics engine. Formation drift = sine offset around the slot (set `velocity.x` accordingly). All movement lives in `_physics_process(delta)` (60 Hz fixed timestep, NFR2).

**🚫 Do NOT mutate shared `Curve2D` / `FormationDefinition` resources.** `FormationDefinition` and its `Curve2D`s are shared `Resource`s — many enemies (and the spawner) reference the same instance. "Aim the dive at the player's x" must be done by **offsetting/transforming the sampled point per-enemy at read time** (e.g. `var p := dive_curve.sample_baked(t); p.x += _aim_x_offset`), or by giving each enemy its own `Curve2D` **copy** (`dive_curve.duplicate()` in `activate()`). Never call `set_point_in/out_position` / `bake()` on the shared resource — it corrupts every other enemy diving on the same curve.

### HP wiring on a pooled enemy

`HealthComponent._ready()` sets `current_hp = max_hp` once (on first instantiation). For a pooled enemy re-acquired later, `_ready()` does NOT re-fire. So `enemy.gd.activate()` must restore HP per spawn: set `_health.max_hp = definition.max_hp` then `_health.reset_to_full()` (which clears `_is_dead` and re-emits `health_changed`). `max_hp` is per-`EnemyDefinition`, so it's set at `activate()` time, not in the scene. (Tier-2/3 HP multipliers are E6 — encode the path but exercise only ×1.0 in E1.)

### Silhouettes (D16 / UX)

Enemies are **hazard family**: neon-vector `Polygon2D`, **NO bright outline** (D16/ADR-6 — outline is reserved for the player family). Use distinct geometric shapes per type so shape carries meaning (UX A2: never hue-alone). **Do NOT port the prototype's enemy colors** (its cyan Shielder clashes with the player-family primary cyan; its diamond Bomber clashes with the rarity-pip glyph). Derive new silhouettes in the hazard palette (`colors.hazard #FF3D5A` calm → `colors.climax-hazard #FF9E3D` climax). Suggested v0.1 shapes: Grunt = downward triangle, Shielder = hexagon, Bomber = wide diamond/chevron — distinct from the player's upward arrowhead. The formal family-driven renderer matures later (D16); for 1.4 a plain `Polygon2D` per the silhouette_color is sufficient. **The segmented on-enemy HP bar (UX H6) is Story 1.7's deliverable** — do NOT build it in 1.4 (it reuses this `HealthComponent`).

### Out of scope for 1.4 (do NOT build — listed to prevent scope creep)

| Item | Owner | Why deferred |
|---|---|---|
| **Captor enemy + 5-state FSM** (enter/formation/telegraph/capture/dive) | Story 2.1 (E2) | FR43 splits "Enemy baselines (E1); Captor FSM (E2)". 1.4 builds only the shared machinery the Captor hooks into. |
| Capture column, tractor beam, capture/rescue/sacrifice, docked ship | Epic 2 (FR13–FR21) | The gamble loop. |
| Hit-flash, screen-shake, particle bursts | Story 1.6 | Juice is arena-scoped via EventBus. 1.4 emits `enemy.died` only. |
| Segmented HP bar visual, full HUD | Story 1.7 | Reuses this HealthComponent. |
| i-frames, ship-loss, respawn, contact (body-to-body) damage economy | Story 1.5 | Life/health economy. In 1.4 the player takes damage but has no i-frames (acceptable for the kinesthetics slice). |
| Full wave lifecycle FSM (timer-end, HP heal, reward, replay) | Story 1.8 | 1.4's `formation_spawner` is the minimal precursor. |
| `SeedManager` real impl, `RunGenerator`, procedural waves, tier scaling exercise | Epic 4 / E6 | E1 wave is authored. Encode the tier-multiplier plumbing but exercise ×1.0 only. |
| Debug "spawn enemy" cheat overlay | Story 1.8 / 3.x | `Debug` autoload is a stub. |

### Pooling contract recap (AR6 / D7 — mirror `player/projectile.gd` exactly)

- Acquire via `Pool.acquire(scene)`; re-init per-spawn state in `activate(...)` (never `_ready()` — it runs once).
- `_ready()` does one-time setup only (layer/mask from Constants, signal connections, child caching). Connections made in `_ready()` persist across pool cycles — **never reconnect in `activate()`** or you stack duplicates.
- Release via `Pool.release(self)`; if releasing from inside a physics callback (`body_entered`, death during physics) use **`Pool.release.call_deferred(self)`** (typed form — NOT the stringly `Pool.call_deferred("release", self)`). Off-screen release in `_physics_process` (before the physics step) is fine synchronous.
- **Never `queue_free()`** a pooled node (leaves the pool holding a dead reference). Enemies are pooled (arch lists enemies as pooled entities; concurrency is bounded at 12).
- `Pool._deactivate()` generically clears `set_process`/`set_physics_process`/`visible`/`monitoring`/`monitorable` — works for `CharacterBody2D` enemies and `Area2D` projectiles alike.

### Signal boundary (AR7 / D8)

- **Direct/local signals** (declare on the enemy script, connect directly): `enemy.died(score_value: int)`, `HealthComponent.health_changed`/`died`. The formation spawner connects `enemy.died` directly.
- **EventBus** (global game-flow only): `score_changed(score: int)` — the spawner catches `enemy.died`, accumulates score, publishes `score_changed`. Do **NOT** add `enemy_spawned`/`enemy_died`/`enemy_despawned` to EventBus (D8: don't route everything through the bus).
- Typed signals, past-tense for events, callable connect syntax (`enemy.died.connect(_on_enemy_died)`).

### Collision layers (already complete — no `constants.gd` change needed)

```gdscript
const LAYER_PLAYER: int = 1            # bit 0
const LAYER_ENEMY: int = 2             # bit 1   ← enemy bodies
const LAYER_PLAYER_PROJECTILE: int = 4 # bit 2
const LAYER_ENEMY_PROJECTILE: int = 8  # bit 3   ← enemy fire
const LAYER_PICKUP: int = 16           # bit 4
```
- Enemy body: `collision_layer = LAYER_ENEMY` (2, via `FactionComponent.get_collision_layer()`); `collision_mask = 0`.
- Enemy projectile: `collision_layer = LAYER_ENEMY_PROJECTILE` (8); `collision_mask = LAYER_PLAYER` (1).
- Read bits from `Constants` — never magic numbers (tests assert against `Constants.LAYER_*`).

### Performance / hot-path (NFR2/NFR3/NFR6, AR14)

- All AI movement + fire cooldowns in `_physics_process(delta)` (60 Hz). No per-frame allocations (no new Arrays/Dicts/`Vector2(...)` in the loop — hoist). Cache all node refs in `@onready` / `activate()`. No `find_child`/`get_node`/`$` per frame. No `print()` (use `Log`).
- Fire cooldown = a plain `_cooldown: float` decremented by delta (no Timer node) — clamp at 0 (avoid the unbounded-negative drift flagged in the 1.3 review).
- Worst case 12 enemies × `_physics_process` — keep each enemy's per-frame work tiny.

### Testing (GUT — mirror `tests/player/test_projectile.gd`)

- `extends GutTest`; `const Scene := preload(...)`; `before_each()` calls `Pool.clear()` (Pool is an autoload — state persists across tests).
- Self-releasing pooled nodes: use plain `add_child` (NOT `add_child_autofree`) so GUT doesn't free a node the Pool holds. Acquire via `Pool.acquire(scene)`.
- Engine signals (`body_entered`/`area_entered`): `await get_tree().physics_frame` (manual `_physics_process(delta)` does NOT fire them). For deterministic motion, call `_physics_process(delta)` directly with fixed delta.
- Float compares: `assert_almost_eq(..., 0.05)` (float32 vs float64).
- Assert on state/signals/layers — never on pixels-on-screen.
- Pure-logic unit tests (`EnemyDefinition`, `FormationDefinition`, `StateMachine`) vs scene integration tests (`enemy.gd`, spawner) — keep `Node2D`/`CharacterBody2D` scripts thin.

### Project Structure Notes

- **Co-located by domain** (Option A): enemy scenes + scripts + `enemy_definition.gd` + `formation_definition.gd` + `states/` + `art/` live under `enemies/`. `.tres` **instances only** live under `resources/enemies/` and `resources/formations/` (D9: schema `.gd` with the domain, `.tres` in `resources/`).
- New shared component: `components/state_machine/{state_machine.gd, state.gd}` (reusable — also serves Story 1.7 + E2).
- `tests/enemies/` mirrors the domain (currently a `.gdkeep` placeholder).
- Naming: scripts `snake_case.gd`, scenes `snake_case.tscn`, root nodes PascalCase (`Grunt`/`Shielder`/`Bomber`), `.tres` prefixed `enemy_*` / `formation_*`, one root + one script per scene.
- No conflicts with the unified structure detected. The `captor/` subfolder is intentionally NOT created (E2).

### Project Context Rules

*(Extracted from `_bmad-output/project-context.md` — follow exactly. When a rule conflicts with a design intent, flag to Mrdth.)*

- **Engine:** Godot 4.6 (`config_version=5`, GDScript). Pin to 4.6.x; avoid 4.7-only APIs. **2D** (`Node2D`/`CharacterBody2D`/`Area2D`); Compatibility renderer. Ignore the 3D defaults in `project.godot` (`Forward Plus`, `Jolt`) — inert for this project.
- **Do NOT port the prototype.** Re-derive every behavior in Godot idioms: no plain-object "entities" (use Nodes/`Resource`), no `splice`-during-iteration, no manual draw loops. The prototype's enemy colors/shapes are reference-only and partially clash with the UX spine — do not copy them.
- **Fixed-screen shooter, not a runner.** No auto-scroll / side-scroll / one-button input. Enemies move within the fixed screen (formation rows in the upper band, dives toward the bottom lane).
- **Composition over inheritance (AR5/ADR-4/D4).** Enemies are built from component child nodes (`HealthComponent`, `FactionComponent`, `StateMachine`), not deep inheritance. Strict collision layers.
- **Content via ContentRegistry (AR8/D9).** No `load("res://...")` in gameplay code — enemies/stats/formations come through `ContentRegistry`. Adding an enemy or formation = add a `.tres`, zero code.
- **No `print()` / no try-catch (AR11/AR12).** Route logging through `Log`. Use preconditions + `push_error`/`push_warning` + fail-safe defaults (grunt fallback on missing EnemyDefinition). `assert` for dev-only invariants. Never hard-crash.
- **RNG (AR4):** seeded `RandomNumberGenerator` instances (injected by the spawner), never global `randi()`/`randf()`. SeedManager real impl is Story 4.1.
- **Cache `@onready`; never `$`/`get_node()` per frame. Pooled nodes re-init via `activate()`/`reset()`, never `_ready()`.** `move_and_slide()` takes no args and applies delta internally — don't multiply velocity by delta.
- **Autoload order is fixed:** Constants → Log → EventBus → Settings → SeedManager → **ContentRegistry** → Pool → SaveManager → AudioManager → GameManager → Debug. ContentRegistry can use `Log` (earlier in order). Do not change the registry.

### References

- **Story spec:** `planning-artifacts/epics.md` — Story 1.4 (lines 342–355); FR30 (line 82), FR43 (line 104), FR44 (line 105), FR45 (line 106); AR5/AR6/AR8 (lines 145–148).
- **GDD:** `planning-artifacts/gdds/gdd-meridian-run-2026-06-29/gdd.md` — Enemy Design & AI (lines 240–247), Run Structure / pulsed formations (line 166), Difficulty/tier (lines 205–207), damage model (line 108). Decision log `[Wave-1]` (spawn budget, timer end).
- **Architecture:** `planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md` — D4 composition (237), D6 AI/StateMachine (242), D7 pooling (246), D8 signals (250–252), D9 content/ContentRegistry (256, 361–367, 739–744), D16 faction renderer (333–335), shared StateMachine rule (735), enemy folder layout (480–486), wave_controller (493).
- **Project context:** `_bmad-output/project-context.md` — authoritative engine/perf/code-org/testing rules.
- **Prior stories (read before implementing):**
  - `implementation-artifacts/1-3-vertical-fire-system.md` — projectile pooling + `activate()`/`HealthComponent`-name-lookup pattern (the contract enemies satisfy); the forward-compat note at `player/projectile.gd:65–68`.
  - `implementation-artifacts/1-2-player-movement-1-axis-chassis.md` — `CharacterBody2D` + `HealthComponent`/`FactionComponent` wiring; tuning `.tres`+`.gd` schema pair pattern.
  - `implementation-artifacts/1-1-project-scaffolding-and-core-systems.md` — autoloads, `Constants` (collision layers), Input Map, GUT setup.
- **Code to clone/mirror (read fully before editing):**
  - `player/projectile.gd` + `projectile.tscn` — clone for `enemy_projectile` (invert layer/mask + direction).
  - `player/fire_system.gd` — clone for `enemy_fire_system` (drop `Input`, fire on AI state).
  - `player/player.gd` + `player.tscn` — entity-composition pattern (`CharacterBody2D` + component children).
  - `player/player_tuning.gd` + `resources/player_tuning.tres` — schema/instance pair to clone for `EnemyDefinition`.
  - `systems/pool.gd`, `systems/content_registry.gd` (stub to implement), `systems/constants.gd`, `systems/event_bus.gd`, `components/health_component.gd`, `components/faction_component.gd`.
  - `tests/player/test_projectile.gd` — GUT pool-fixture style to mirror in `tests/enemies/`.
- **Deferred work log:** `implementation-artifacts/deferred-work.md` — note the player post-`move_and_slide` clamp re-examination (mitigated: enemies use `collision_mask = 0`).

### Decisions confirmed by Mrdth (2026-07-03)

The open design forks above are **settled as chosen** — implement the defaults; do not re-litigate:

1. **Reusable `StateMachine` scope** → build the reusable `components/state_machine/` in 1.4 (as specified).
2. **1.4 vs 1.8 spawner boundary** → minimal `formation_spawner` in 1.4; full wave lifecycle FSM in 1.8.
3. **Bomber telegraph window** → distinct heavy-shot silhouette/color + `heavy_windup_s` (default 0).
4. **Enemy projectile speed** → data-tunable, default ~280 px/s (dodgeable vs the player's 620).

The data-tunable values (#3 windup, #4 projectile speed, plus formation row Y/spacing, drift amplitudes, dive-curve shapes) are **playtest knobs revisited in Story 1.8** (the feel gate) — ship sane v0.1 defaults now, tune by feel then.

---

## Dev Agent Record

### Agent Model Used

Claude (gds-dev-story workflow)

### Implementation Plan

Key non-obvious design decisions (resolved from the story's open forks + Dev Notes):

1. **Enemy body = `CharacterBody2D`, `collision_mask = 0`** (Key Decision #1). Keeps the
   Story 1.3 player-projectile `body_entered` hit path untouched; damage flows only via
   projectiles, never body contact.
2. **Reusable `components/state_machine/` is generic** — base `State`/`StateMachine` carry
   no enemy-specific logic. Concrete states resolve their owning entity via the inherited
   `owner` property (the scene root) cast to `Enemy` in `enter()` — no `get_parent()` string
   lookups, no per-frame `$`. Honors "build it cleanly; Captor/HUD reuse it" (Key Decision #3).
3. **`StateMachine` owns `_physics_process`** and forwards to `current_state.physics_process`.
   Each AI state sets `_enemy.velocity` toward a sampled target and calls `_enemy.move_and_slide()`.
   The `Enemy` script does **not** define its own `_physics_process` (avoids double
   `move_and_slide` + nondeterministic parent/child processing order). Release → `remove_child`
   detaches the whole subtree, stopping the StateMachine tick on idle pooled enemies.
4. **Movement = curve-following via velocity** (Dev Notes). `FormationDefinition` curves are
   **relative to the slot origin** — one shared `FormationDefinition` serves all 8 slots; each
   enemy adds its `slot_world_pos` (+ a per-enemy player-aim `x` offset on dive) to the sampled
   point at read time. Shared `Curve2D`/`FormationDefinition` resources are NEVER mutated.
5. **Curve traversal = duration-driven `t` + constant-speed pursuit** (Dev Notes pattern):
   `u = _t / duration`; `velocity = (sampled_target - global_position).normalized() * speed`;
   `move_and_slide()`. Transition at `u >= 1.0`; `FormationState` corrects any residual lag by
   pulling toward `slot + drift`. This honors "advance t over entry/dive_duration" AND preserves
   distinct `move_speed` per variant. `entry_duration_s`/`dive_duration_s`/`move_speed`/
   `dive_speed_multiplier` are all playtest knobs (Story 1.8 feel gate).
6. **HP wiring on pooled enemy** (Dev Notes): `activate()` sets `_health.max_hp = definition.max_hp`
   then `_health.reset_to_full()` (clears `_is_dead`, re-emits `health_changed`). `_ready()` runs
   once; the spawner does `acquire → add_child → activate` so `@onready` refs are valid in `activate`.
7. **`ContentRegistry` gains `get_formation_def`** too (scans `resources/formations/`) — the
   `FormationSpawner` needs its formation through the registry (AR8: no `load()` in gameplay code).
8. **Signal boundary** (D8): `enemy.died(score_value)` is a direct local signal (spawner connects
   it directly); only `score_changed` rides `EventBus`. No `enemy_spawned`/`enemy_died` on the bus.

### Debug Log References

- GUT: `godot --headless -s addons/gut/gut_cmdln.gd` → **90/90 passing, 260 asserts** (28 new
  tests across 7 files). Full 1.1–1.4 suite green; `tests/player/test_projectile.gd` (Story 1.3
  regression) still passes.
- Headless game launch (`timeout 7 godot --headless --path .`) → **no runtime errors**;
  ContentRegistry indexes 3 enemies + 1 formation; spawner emits wave-1 budget-5 pulses;
  enemies enter → form → fire → dive → release through the full cycle.

### Completion Notes List

- **All 6 tasks complete; all 4 ACs + both implicit/end-to-end requirements satisfied.**
- AC1: Grunt/Shielder/Bomber `.tres` load via `ContentRegistry` (grunt fallback on miss, AR11).
- AC2: enemies fly to formation rows then dive via the reusable `components/state_machine/`
  (the "shared state/pattern system"); enemy body on `LAYER_ENEMY` (mask 0), enemy projectile
  on `LAYER_ENEMY_PROJECTILE` masked to `LAYER_PLAYER`.
- AC3: `FormationSpawner` emits `min(4+N, 12)` enemies as pulses across `wave_duration_s`
  (a spawn budget, not a kill quota); verified for N=1 (5), N=8 (12, capped), N=50 (12).
- AC4: Grunt/Shielder fire standard 1-dmg pellets; Bomber fires 2-dmg HEAVY telegraphed
  (amber, larger) pellets. Enemy projectile speed 280 px/s (dodgeable vs the player's 620).
- Implicit: player projectile still kills `CharacterBody2D` enemies via the unchanged
  `body_entered` → `HealthComponent` path (regression test); enemies damage the player's
  `HealthComponent` with their fire; enemies return to the `Pool` on death/off-screen
  (never `queue_free()`).

**Godot 4.6 gotchas discovered & resolved (documented in code comments):**

1. **Node-typed `@export` NodePath does NOT auto-resolve** from a hand-authored `.tscn`
   (returns `null` even for the base scene — confirmed via probe). `StateMachine._ready`
   falls back to its first `State` child. The `@export var initial_state: State` + NodePath
   are kept for the inspector; the fallback is the reliable path under headless/text-scene use.
2. **`Pool.release.call_deferred(self)` fails for `CharacterBody2D`** ("Cannot convert
   argument 1 from Object to Object") — a PhysicsBody2D + typed-`call_deferred` marshalling
   limitation in 4.6; the `Area2D` projectile's identical call is unaffected. The enemy's
   death release uses a **no-arg deferred method** (`_release_to_pool.call_deferred()`) to
   sidestep the arg conversion (deferred method runs at idle, outside the physics callback).
3. **The fire system calls `activate()` BEFORE `add_child()`** (the player-fire_system order),
   so the enemy projectile's `@onready _visual` is `null` on first acquire → `_visual` is
   **lazy-resolved in `activate()`** (`get_node_or_null` walks the node's own child tree, so it
   works pre-SceneTree). The enemy entity itself uses acquire→add_child→activate so its
   `@onready` refs ARE valid in `activate`.
4. **The spawner's enemy container can't be added to the Arena during `arena.tscn` setup**
   ("Parent node is busy setting up children") → it parents to the **spawner itself** (still
   world-space — the spawner is under Arena). GUT missed this (it adds the spawner to an
   already-set-up arena); the **headless game launch caught it** (the value of Task 6.4).
5. **GUT flags `push_error`/`push_warning` during a test as failures** → expected-error paths
   (grunt fallback, missing formation) use `assert_push_error(...)` to mark the error consumed.
   GDScript lambdas capture **primitives by value**, so signal-count tests use GUT's
   `watch_signals` / `assert_signal_emit_count` / `assert_signal_emitted_with_parameters`.

**Spec extensions (documented):** `FormationDefinition` gained an `id: StringName` field
(ContentRegistry key, parallel to `EnemyDefinition.id`); `ContentRegistry` gained
`get_formation_def` (AR8 — the spawner must fetch its formation via the registry, not `load()`).
The `standard.tres` `Curve2D`s were generated via a throwaway `ResourceSaver` script (then
deleted) to guarantee correct serialization rather than hand-authoring the binary `_data` format.

**6.4 visual:** verified functionally via the headless launch (above) + GUT integration tests.
The in-editor **visual** confirmation (formation/drift/dive *appearance*) is recommended for
Mrdth; the actual feel tuning (curve shapes, durations, drift, dive aim) is the Story 1.8 feel
gate — sane v0.1 defaults shipped now.

**Orphans:** 69 at suite exit — the pre-existing Pool-retain pattern (`Pool.clear()` clears the
dicts without freeing nodes; pooled enemies/projectiles add to it). Same shape as the
pre-existing `test_pool`/`test_projectile` orphans; not a regression.

### File List

**New — game code:**
- `components/state_machine/state.gd`, `components/state_machine/state_machine.gd` (reusable FSM — D6; also serves Story 2.1 Captor + 1.7 HUD).
- `enemies/enemy_definition.gd`, `enemies/formation_definition.gd` (content schemas).
- `enemies/enemy.gd`, `enemies/enemy.tscn` (CharacterBody2D entity + component composition).
- `enemies/enemy_projectile.gd`, `enemies/enemy_projectile.tscn` (pooled, downward, inverted layers).
- `enemies/enemy_fire_system.gd` (cooldown accumulator, arm/disarm per AI state).
- `enemies/states/enter_state.gd`, `formation_state.gd`, `dive_state.gd` (the three AI states).
- `enemies/grunt.tscn`, `enemies/shielder.tscn`, `enemies/bomber.tscn` (variant scenes, inherit `enemy.tscn`).
- `resources/enemies/enemy_grunt.tres`, `enemy_shielder.tres`, `enemy_bomber.tres` (GDD stat instances).
- `resources/formations/standard.tres` (E1 formation — slots + relative entry/dive Curve2Ds).
- `world/formation_spawner.gd` (minimal precursor to Story 1.8's wave-controller FSM).
- `world/arena.gd` (thin: wires spawner.player + `begin_wave(1)`).

**New — tests:**
- `tests/components/test_state_machine.gd`
- `tests/enemies/test_enemy_definition.gd`, `test_formation_definition.gd`, `test_enemy.gd`, `test_enemy_projectile.gd`, `test_enemy_fire_system.gd`
- `tests/world/test_formation_spawner.gd`

**Modified:**
- `systems/content_registry.gd` — real `get_enemy_def` (DirAccess scan + grunt fallback) + new `get_formation_def`; stub removed.
- `world/arena.tscn` — `arena.gd` script + `FormationSpawner` node (w/ the three variant scenes); dropped the non-standard `unique_id=` node attributes from the original scaffolding.

**Deleted:**
- `enemies/.gdkeep`, `tests/enemies/.gdkeep`, `tests/world/.gdkeep` (dirs now populated).

### Change Log

- 2026-07-03: Story 1.4 implemented — Grunt/Shielder/Bomber enemies with formation-entry + dive
  AI via a reusable StateMachine, enemy fire system + projectiles (standard + Bomber heavy),
  minimal formation spawner (FR30 spawn budget, pulsed), and the real ContentRegistry. Reusable
  `components/state_machine/` built for Captor (2.1) + HUD (1.7) reuse. 90/90 GUT tests pass;
  headless game launch clean.
- 2026-07-03: **Rework started (status → in-progress).** Mrdth playtest found the entry/dive
  FEEL is broken (slow drift, no spiral entry, divers exit-and-vanish — no Galaga re-entry loop)
  and that formation choreography was wrongly deferred to 1.8. Decision: **option A** — keep the
  GDD's cap-12, deliver the Galaga feel within it. v1 committed as a checkpoint on branch
  `1-4-formation-rework` before rework. Full findings + the deferred cap-12 revisit (option B)
  are in `1-4-formation-feel-findings.md`.
- 2026-07-03: **Rework complete (option A), awaiting Mrdth playtest.** Changes: (1) movement
  switched to **exact curve tracking** — `velocity = (target - pos) / delta` with speed-based
  parametric advance, so enemies traverse curves crisply at `move_speed` (no pursuit lag);
  `move_speed` now actually differentiates variants in entry/dive. (2) **Dive → re-enter from
  top → return to formation loop** added (DiveState off-screen-bottom → EnterState); enemies
  release to the Pool **only on death**, not on diving off-screen — persistent cycling threats.
  (3) **Spiraling/swooping `Curve2D` entry** + sweep dive (regenerated, Catmull-Rom-smoothed),
  replacing v1's straight lines. (4) **Coherent formation groups** — `group_size` drives pulse
  count (`ceil(budget/group_size)`), each pulse a cluster entering together. (5) Per-enemy
  ±25% formation-hold variance staggers dives. **Speed tuning deviation:** `move_speed` raised
  from the GDD FR43 baseline (60/50/80) to 220/180/280 (~3.5×, ratios/ordering preserved) —
  the baseline was too slow for arcade feel; GDD says "playtest-tuned," revisit at the 1.8 feel
  gate. `dive_speed_multiplier` 2.0 → 2.5. 90/90 GUT pass (new dive-loop + state-progression
  tests); headless launch clean. **Status remains in-progress until Mrdth confirms the feel in
  the editor.** Not yet committed (rework sits uncommitted on `1-4-formation-rework` atop the
  v1 checkpoint `82f235d`).
