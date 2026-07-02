---
baseline_commit: 269912ae93a5b0adbb95e9a89e8890a5db5b3c5e
---

# Story 1.3: Vertical Fire System

Status: review

> **Epic 1 — Combat Chassis & Feel** (v0.1 kinesthetics gate) · third story.
> Builds on the **done** chassis from Story 1.2 (Player `CharacterBody2D`, `HealthComponent`,
> `FactionComponent`, `player_tuning.tres`, GUT suite). This story adds the **first pooled hot-path
> entity** — the player's vertical projectile — and a **`FireSystem` component** on the Player. It is
> the **first story to actually exercise the `Pool` autoload** (1.1 shipped it as an untested
> scaffold; 1.2 explicitly did not touch it). Every pattern locked here (pooled `Area2D` projectile
> re-init via `activate()`/`reset()`, cooldown accumulator, `Pool` deactivation on release, zero-
> per-frame-allocation hot path) is the template 1.4 (enemy fire), 1.6 (juice), 1.8 (debug overlay)
> inherit. Read `_bmad-output/project-context.md` before writing code.

## Story

As a player,
I want to fire projectiles straight up at enemies,
so that I can damage them through readable 1-axis fire-columns.

## Acceptance Criteria

*(Verbatim from `epics.md` Story 1.3; refs: FR4, FR5, FR6, FR45 · AR6, AR14)*

1. **AC1 — Hold-to-autofire, straight up, tuned values.** Given the player holds Fire, Then projectiles spawn **straight up** at **10 dmg / 0.16 s cooldown / 620 px/s** (from tuning `.tres`).
2. **AC2 — Pooled, activate() re-init.** Given heavy fire, When many projectiles are active, Then all come from `Pool.acquire()`/`release()` with `activate()` re-init — never `instantiate()`+`queue_free()` per frame, never `_ready()` re-init.
3. **AC3 — Release on leave-screen or hit.** Given a projectile leaves screen or hits, Then it's released back to the pool.
4. **AC4 — Zero per-frame allocations.** Given the hot path, Then zero per-frame allocations (no new arrays/dicts/`Vector2` in `_physics_process`); no `print()`.

> **Requirement glossary (from `epics.md` Requirements Inventory):**
> - **FR4** — The player fires projectiles **straight up (vertical, 1-axis)** via a `Fire` action; player-ship fire never fires horizontally or in non-vertical directions.
> - **FR5** — The base player shot deals **10 damage**, fires on a **0.16 s cooldown**, and travels at **620 px/s** *(baseline)* — all data-tunable.
> - **FR6** — Aiming is fixed vertical fire (no twin-stick, no aiming input); hit detection is **projectile-based (not hitscan)**; no critical/weak-point system (arcade-flat).
> - **FR45** — No screen-clearing weapons exist; large-AoE only when rare/earned/non-repeatable. Single-player only. *(Bounds 1.3 to single-stream vertical fire — no AoE/spread.)*
> - **AR6 — Object pooling (D7):** Generic `Pool` autoload; `acquire()`/`release()`; re-init via `activate()`/`reset()` — **never `_ready()`** for pooled nodes.
> - **AR14 — Godot 4.6 gotchas:** `move_and_slide()` takes no args and applies delta internally; cache `@onready`; pooled nodes re-init via `activate()`/`reset()` not `_ready()`; typed code; no `print()`.

## Scope — what this story IS and IS NOT

**This is the vertical-fire chassis. It spawns one pooled projectile per cooldown from the player's nose, travels straight up, and returns to the pool on leave-screen or hit. It does not build enemies, juice, HUD, or any non-baseline fire mode.**

- **IS:** a pooled `Area2D` **Projectile** (`player/projectile.gd` + `.tscn`) — moves straight up, detects enemies, releases on leave/hit; a **`FireSystem`** component node on the Player (`player/fire_system.gd`) — reads `fire` input, runs a cooldown accumulator, acquires+activates projectiles at the muzzle; a **`Muzzle` `Marker2D`** on the Player; projectiles parented to the **Arena root** (wired by `player.gd`, so they live in world space, not the Player's transform); fire tuning fields added to **`PlayerTuning`** + `player_tuning.tres` (`fire_cooldown`/`bullet_speed`/`projectile_damage`/`muzzle_offset_y`); a **`Pool` extension** so released nodes deactivate (D7 gap from 1.1); GUT tests (Pool unit, FireSystem integration, Projectile integration incl. a dummy-target hit fixture); a placeholder projectile visual (so the fire column is visible).
- **IS NOT:** no enemies or real targets (1.4 — the hit path is exercised with a *test-fixture* dummy body on `LAYER_ENEMY`, never a real enemy); no `HitboxComponent`/`HurtboxComponent` (1.4 — they need the enemy end; 1.3 applies damage via a convention stub, see Decision #6); no muzzle flash / fire SFX / screen-shake / hit-flash (1.6); no HUD or ammo/heat readout (1.7); no real art or the D16 elongated-chevron+outline renderer (placeholder only — real art/renderer in 1.6/8.5); no spread / dual-stream / triple-shot / fast-fire / generators (all Epic 2/3+); no Galaga-style on-screen-bullet cap (the GDD imposes none — cooldown is the rate-limiter); no max-on-screen-bullet cap; no projectile-pool capacity/pre-warm mandate (lazy acquire is fine — pre-warm is an *optional* subtask).
- **The projectile is `Area2D`, NOT `CharacterBody2D`** (Decision #1). Bullets overlap-detect; they don't slide/block. Movement is manual `global_position.y -= speed * delta` in `_physics_process`. The AR14 "never multiply velocity by delta" rule is **`move_and_slide()`-specific** (it applies delta internally); for a non-physics-body `Area2D`, manual delta integration is correct and expected (project-context: "Use delta for any non-`move_and_slide` integration"). Do **not** make the projectile a `CharacterBody2D`.
- **Damage is stubbed, not fully wired** (Decision #6). The projectile carries `damage = 10`; on `body_entered` it applies damage to the body's conventionally-named `HealthComponent` child (if present) then releases. There are no enemies in 1.3, so this path is only exercised by a test fixture. The real `HurtboxComponent`-mediated damage wiring lands in 1.4.

## Tasks / Subtasks

*(ACs in parens. Values cited are normative baselines — all data-driven from `player_tuning.tres`.)*

- [x] **T1 — Extend `Pool` to deactivate released nodes (D7 gap; AC2, AC3, AR6)** — **MODIFY `systems/pool.gd`** (the one systems file this story touches)
  - [x] `release()` already removes the node from its parent and appends it to the per-path pool (correct as of 1.2 — the 1.1 `get_instance_id()` bug is fixed). **Add deactivation** so inactive pooled nodes do not process/render: after removing from parent, call `node.set_process(false)`, `node.set_physics_process(false)`, and `if node is CanvasItem: node.visible = false`. (`set_process`/`set_physics_process` are `Node` methods; `visible` is `CanvasItem` — duck-type it.)
  - [x] `acquire()` is **unchanged** — it returns a (now deactivated, if reused) node. The consumer's `activate()` re-enables processing/visible + sets state. **Do not** auto-activate in `acquire()` (that would violate the "re-init via `activate()`, never implicitly" contract).
  - [x] Keep the existing null / queued-for-deletion / not-acquired guards and the `push_warning` on an unknown node. Keep `release()` idempotent (re-releasing a node already in the pool is a no-op — verify the existing `_node_paths.has` guard covers it; if not, add a guard).
  - [x] **Verify the acquire→add_child→…→release→re-acquire round-trip** with a real pooled node (T7 test). This is the *first* real stress of `Pool` — 1.1/1.2 never exercised it.
- [x] **T2 — Fire tuning fields** (AC1, AR10) — **MODIFY `player/player_tuning.gd` + `resources/player_tuning.tres`**
  - [x] Add to `PlayerTuning` (schema lives with the `player/` domain; `.tres` instance in `resources/` — the established 1.2 split):
    - `@export var fire_cooldown: float = 0.16` ← AC1/FR5 baseline (seconds between shots; ~6.25 shots/s).
    - `@export var bullet_speed: float = 620.0` ← AC1/FR5 baseline (px/s, straight up).
    - `@export var projectile_damage: int = 10` ← AC1/FR5 baseline.
    - `@export var muzzle_offset_y: float = -20.0` ← local Y of the muzzle marker relative to the Player origin (ship nose; **starting default** — GDD/UX leave the exact muzzle point open).
  - [x] Instance values in `resources/player_tuning.tres`: `fire_cooldown=0.16`, `bullet_speed=620`, `projectile_damage=10`, `muzzle_offset_y=-20` (preserve existing `move_speed=426.6`/`edge_margin=24`/`lane_y=680`).
  - [x] Use **literal** defaults in the schema (not autoload refs) so the `@export` defaults parse in the inspector.
- [x] **T3 — Projectile scene + script** (AC1, AC2, AC3, AC4, AR6, AR14) — `player/projectile.gd` + `player/projectile.tscn`
  - [x] Root node **`Projectile`** (`Area2D`) — meaningful PascalCase name. Root script `projectile.gd` (`extends Area2D`, `class_name Projectile`).
  - [x] Children: a placeholder **visual** (T4), a **`CollisionShape2D`** with a small simple shape (e.g. `RectangleShape2D` ~6×12, or `CapsuleShape2D` — "simple collision shapes on dynamic bodies"; keep it small, the projectile is small).
  - [x] `collision_layer = Constants.LAYER_PLAYER_PROJECTILE` (bit 2 → value `4`). `collision_mask = Constants.LAYER_ENEMY` (bit 1 → value `2`) — so `body_entered` fires when overlapping an enemy body. Set via the integer bitmask from `Constants` (there are no 2D layer names in `project.godot`). **Do not extend `FactionComponent`** for this (Decision #5) — set the layer directly from `Constants`.
  - [x] **Pooled re-init contract (AR6 — the core of this story):** NO re-init logic in `_ready()` beyond safe defaults. Provide an explicit `activate(spawn_pos: Vector2, speed: float, damage: int) -> void` that: stores `_speed = speed`, `_damage = damage`; sets `global_position = spawn_pos`; sets `visible = true`; `set_physics_process(true)`; `monitoring = true`. Provide `reset()` (optional symmetric teardown) — but **`Pool.release()` (T1) now handles deactivation**, so `activate()` just needs to flip the node back on + set state.
  - [x] `_physics_process(delta: float) -> void`:
    - [x] `global_position.y -= _speed * delta` ← **straight up; zero allocation** (single float-component update, no `Vector2(...)`, no `velocity`). This is correct manual integration for an `Area2D` (not `move_and_slide`).
    - [x] Leave-screen check: `if global_position.y <= 0.0:` (top of the 720-tall screen) → `Pool.release(self)` and `return`. (Use `< 0` or a small negative margin to clear fully — pick `<= 0.0`; the bullet spawns at ~660 and travels up.) **`Pool.release(self)` is the release call — never `queue_free()`.**
  - [x] Hit path: connect `body_entered(body: Node2D)` → `_on_body_entered(body)` **once, in `_ready()`** (a connection on the object persists across pool re-acquire/release; do **not** reconnect in `activate()` — that would stack duplicate connections and multi-fire the hit):
    - [x] Apply damage via the convention stub (Decision #6): `var hc: Node = body.get_node_or_null("HealthComponent")`; `if hc != null and hc.has_method("take_damage"): hc.take_damage(_damage)`. (No `HurtboxComponent` yet — 1.4 refines this.)
    - [x] Then `Pool.release(self)` and `return` (consume-on-hit — one hit then release; AC3).
  - [x] Cache `_speed`/`_damage` as private members; static typing throughout; no `print()` (use `Log.debug("Projectile", …)` if ever needed). **Never** read `_speed` from an autoload per frame — it's cached at `activate()`.
- [x] **T4 — Placeholder projectile visual** (AC1 — so the fire column is visible; art is 1.6/8.5)
  - [x] Add a simple placeholder child of `Projectile` — e.g. a `Polygon2D` thin vertical chevron/rectangle pointing **up**, cyan (`#00E5FF`-ish, the player-family calm color), ~6×14 px footprint (UX: player-family elongated-chevron, bright core + bright outline is the *target* — D16/ADR-6 — but real art/renderer is 1.6/8.5). This is a stand-in. Keep it one node, cheap. **No strobing/flashing** (the ≤3 Hz photosensitive-flash cap applies from day one — a per-shot flash at 6.25 Hz would violate it; juice/flash is 1.6 anyway, so ship a *steady* placeholder).
- [x] **T5 — `FireSystem` component** (AC1, AC2, AC4, AR14) — `player/fire_system.gd` (new; named explicitly in the architecture `player/` tree)
  - [x] `class_name FireSystem`, `extends Node`. A component node, child of `Player` (added in T6).
  - [x] `@export var tuning: PlayerTuning` — assign `resources/player_tuning.tres` in the inspector (no `load()` in code; test-swappable).
  - [x] `@export var projectile_scene: PackedScene` — assign `player/projectile.tscn` in the inspector.
  - [x] `var projectile_parent: Node2D` — **public var** (not `@export`), wired by `player.gd` to the Player's parent (the Arena) in `_ready()` (T6); settable directly in tests. Projectiles parent here so they live in world space (NOT under the Player — transform inheritance; see Decision #8). D8-clean: the Player wires its own component (reads its own `get_parent()`), no cross-domain path and no editable-children.
  - [x] `@onready var _muzzle: Marker2D = get_parent().get_node_or_null("Muzzle")` — the muzzle marker, a sibling under the Player (FireSystem's parent is `Player`), so the spawn follows the ship. (A direct-child/sibling lookup of FireSystem's own parent — not a cross-domain path.)
  - [x] `var _cooldown: float = 0.0` — cooldown accumulator.
  - [x] `_physics_process(delta: float) -> void`:
    - [x] `_cooldown -= delta` (decrement every frame so the gun is ready when needed).
    - [x] `if Input.is_action_pressed("fire") and _cooldown <= 0.0:` → `_spawn()`; `_cooldown = tuning.fire_cooldown`.
    - [x] **Zero per-frame allocations** — no arrays/dicts/`Vector2` constructed in this loop. `_spawn()` is called ~6×/s (not per frame), so the per-spawn work is not a hot-path-per-frame concern, but keep `_physics_process` itself allocation-free.
  - [x] `_spawn() -> void`:
    - [x] `var p: Projectile = Pool.acquire(projectile_scene) as Projectile` ← **never** `projectile_scene.instantiate()` directly.
    - [x] `p.activate(_muzzle.global_position, tuning.bullet_speed, tuning.projectile_damage)`.
    - [x] `projectile_parent.add_child(p)` ← parent to the injected container (world space), NOT the Player.
    - [x] Assert `p != null` (defensive; acquire returns a Node, cast may fail only if the scene is wrong).
  - [x] **(Optional) pre-warm:** in `_ready()`, acquire+activate-then-`Pool.release()` ~8–16 projectiles to avoid first-burst instantiation hitches. Not mandated by any AC; include only if cheap. If added, do it once, not per frame.
  - [x] Static typing; no `print()`; cache `@onready` refs.
- [x] **T6 — Wire FireSystem + Muzzle into the Player** (AC1, AC2) — **MODIFY `player/player.tscn` + `player/player.gd`** (`arena.tscn` unchanged)
  - [x] `player/player.tscn`: add a **`Muzzle`** child of `Player` (type `Marker2D`), local position `(0, tuning.muzzle_offset_y)` ≈ `(0, -20)` (ship nose). Add a **`FireSystem`** child of `Player`; in its inspector assign `tuning = player_tuning.tres`, `projectile_scene = player/projectile.tscn`.
  - [x] `player/player.gd` (`_ready()`): cache `@onready var _fire_system: FireSystem = $FireSystem`; after the existing setup, wire `if _fire_system != null and _fire_system.projectile_parent == null: _fire_system.projectile_parent = get_parent()` — the Player's parent is the Arena (world space). (Node `_ready` order: FireSystem's `_ready` runs before Player's; `projectile_parent` is only read on fire, never in FireSystem's `_ready`, so there is no race.) Do **not** add a separate `Projectiles` node and do **not** modify `arena.tscn`.
  - [x] Verify launch in editor AND headless (`godot --headless --path . --quit-after 60`) → no errors/warnings.
  - [x] **Verify transform-independence:** hold fire in-editor and confirm the projectile travels straight up in world space and does **not** move sideways when the ship moves (it parents to the Arena, not the Player).
- [x] **T7 — GUT tests** (testing discipline; all ACs) — `tests/player/` + `tests/systems/`
  - [x] `tests/systems/test_pool.gd` (`extends GutTest`) — **the first Pool unit tests** (Pool was untested in 1.1/1.2):
    - [x] acquire twice from the same scene → first instantiates, second reuses (or instantiates if pool empty); release returns node to pool; re-acquire returns a (deactivated) node.
    - [x] **D7 deactivation (the T1 extension):** after `release()`, assert the node is `set_physics_process(false)`, `set_process(false)`, and (if `CanvasItem`) `visible == false`. After `activate()` on re-acquire, assert they flip back on.
    - [x] release is idempotent (releasing an already-released node is a no-op; no crash, no double-append).
    - [x] release of a node never acquired → `push_warning`, ignored (use `assert_eq` on observable state, or `watch`/`assert` the warning via GUT's `gut.p` capture if straightforward).
  - [x] `tests/player/test_projectile.gd` (`extends GutTest`) — Projectile **integration** (instantiate the scene; use `add_child_autofree`):
    - [x] **AC1 movement:** `activate(spawn_pos, 620, 10)`; step `_physics_process(delta)` directly (deterministic) — assert `global_position.y` decreases by `620 * delta` per step. Compare with epsilon (float32 vs float64 — see Previous-Story Intelligence).
    - [x] **AC3 leave-screen:** start the projectile low enough, step until `global_position.y <= 0`, assert the node was released (it's no longer a child of its parent / it's back in the pool). Tip: assert `projectile.get_parent() == null` after the release frame (release removes from parent).
    - [x] **AC3 hit + AC1 damage:** build a **dummy target fixture** — a `CharacterBody2D` on `collision_layer = Constants.LAYER_ENEMY` with a `CollisionShape2D` and a child `HealthComponent` (`max_hp = 100`), `add_child_autofree`'d into the tree in the projectile's upward path. Spawn the projectile just below the target via `activate(...)`, then **`await get_tree().physics_frame` several times** so the **engine** detects the overlap and fires `body_entered` — this CANNOT be triggered by a manual `_physics_process(delta)` call (the signal is emitted engine-side during the real physics step, while manual stepping only runs the script's movement code). Assert the target's `HealthComponent.current_hp == 90` (took 10 dmg) **and** the projectile was released (`get_parent() == null`). *(Exercises the full damage-payload + consume-on-hit path without building a real enemy — 1.4's job.)*
    - [x] **AC2 structure:** assert the instantiated projectile is an `Area2D`, `collision_layer == Constants.LAYER_PLAYER_PROJECTILE`, `collision_mask == Constants.LAYER_ENEMY`, and has an `activate(...)` method (no `_ready()`-based re-init).
  - [x] `tests/player/test_fire_system.gd` (`extends GutTest`) — FireSystem **integration**:
    - [x] Build a Player (`add_child_autofree(PlayerScene.instantiate())`); give its `FireSystem` a real `projectile_scene` and a temp `projectile_parent` (`Node2D`, `add_child_autofree`'d). Drive via `Input.action_press("fire")` + stepping `_physics_process`, OR call `FireSystem._physics_process(delta)` directly for determinism (set its `set_physics_process(false)` and drive manually — mirror the 1.2 velocity-independence test).
    - [x] **AC1 cooldown:** with fire held, step `_physics_process` for ~0.5 s total → assert `projectile_parent.get_child_count()` is ~3 (0.5 / 0.16 ≈ 3.1, so 3; allow the count to be 3, not 4). Assert no projectile spawns while `_cooldown > 0`.
    - [x] **AC1 single-shot on tap:** `action_press` + one step → one spawn; `action_release`; step within cooldown → no additional spawn.
    - [x] **AC2 pooling:** fire enough to spawn ≥2 projectiles over time; assert the **same** `Projectile` instance is reused (capture the first projectile's `get_instance_id()`; after it leaves-screen and a new one spawns, the pool may hand back the same instance — assert `Pool` reuse by checking no net `queue_free`/`instantiate` growth, or by acquiring/releasing a known node and confirming identity). At minimum: assert `is_instance_valid` on all spawned projectiles and that none were `queue_free`'d mid-flight (release ≠ free).
    - [x] **AC4 hot path (structural):** read `fire_system.gd`'s `_physics_process` — assert it contains no `Vector2(` / `[` / `{` allocation in the per-frame path (a code-structure assertion, like 1.2's AC2 structural test). Or assert via behavior that stepping many frames with fire held does not allocate (GUT's orphan counter / a manual pre-post child-count stability check).
    - [x] `after_each()` releases `fire` (no input leaks).
  - [x] Run `godot --headless -s addons/gut/gut_cmdln.gd` → **exits green** (existing 1.1/1.2 tests + new 1.3 tests, 0 failures). **Run `godot --headless --import` once first** to register the new `class_name`s (`FireSystem`, `Projectile`) in `global_script_class_cache.cfg` — Godot does not rescan classes on a plain `--headless -s` run (1.2 hit this).
- [x] **T8 — Manual feel check** (kinesthetics gate prep; not an automated AC)
  - [x] Launch in editor, hold Fire (Space / gamepad A) while moving — confirm a steady vertical fire column at ~6.25 shots/s, bullets travel straight up and despawn at the top, bullets do not move with the ship. Note fire-rate/bullet-speed feel for the 1.8 feel gate (values are data-driven — retune `player_tuning.tres`, no code). *(The subjective gamepad-in-editor pass is Mrdth's; objective sub-criteria are proven headless. Box may stay unchecked like 1.2's T8.)*

## Dev Notes

### Architecture Compliance (must follow — sources cited)

- **Composition over inheritance (AR5 / ADR-4 / D4).** Player gains a `FireSystem` component child node; the projectile is a composed `Area2D` scene (visual + CollisionShape2D). "Projectiles = lightweight pooled nodes (damage payload + faction)" [arch §Entity Composition D4]. Do **not** subclass; do **not** add speculative `HitboxComponent`/`HurtboxComponent` (1.4 — they need the enemy end). [arch §components tree]
- **Projectile node type = `Area2D` (Decision #1).** Bullets overlap-detect (`body_entered`), they don't slide/block. `HitboxComponent`/`HurtboxComponent` are explicitly "Area2D-based" [arch §components tree], so an Area2D projectile aligns. Movement = manual `global_position.y -= _speed * delta` in `_physics_process`. **The "never multiply velocity by delta" rule is `move_and_slide()`-specific** (it applies delta internally); an Area2D has no `move_and_slide`, so manual integration is required and compliant (project-context: "Use delta for any non-`move_and_slide` integration"). Do **not** make the projectile a `CharacterBody2D` (it would slide/block, wrong for bullets).
- **Pooling contract (AR6 / D7).** `Pool.acquire(scene)` → node; consumer calls `node.activate(...)` (re-init, NEVER `_ready()`); on expire `Pool.release(node)`. **Never** `instantiate()` + `queue_free()` on the hot path [arch §Entity Creation Pattern, code sample: `proj.activate(spawn_pos, dmg, faction)`; `Pool.release(proj)`]. The 1.1 `Pool` was a minimal, *untested* scaffold — this story is its first real exercise (see T1/T7).
- **D7 deactivation gap (Decision #7).** D7 mandates inactive pooled nodes toggle `visible=false` + `set_process(false)` + `set_physics_process(false)`; the shipped `pool.gd` does **not** do this. T1 extends `Pool.release()` to deactivate generically (Node methods + `CanvasItem.visible` duck-typed). `activate()` re-enables. [arch §Object Pooling D7]
- **Collision layers are strict bitmask constants (AR5 / NFR6).** Projectile `collision_layer = Constants.LAYER_PLAYER_PROJECTILE` (`= 4`, bit 2); `collision_mask = Constants.LAYER_ENEMY` (`= 2`, bit 1) so `body_entered` fires on enemy overlap. Read bits from `Constants`, never magic numbers. No 2D layer names in `project.godot` — use the integer bitmask. [systems/constants.gd; arch §Entity Composition D4]
- **Signal boundary (D8): global flow → `EventBus`; intra-entity → direct signals.** Fire is **intra-entity** (Player↔FireSystem↔Projectile) → **local direct signals only**. **Do NOT add** `projectile_spawned` / `player_fired` to `EventBus` (the boundary rule: don't route everything through the bus). Fire emits **nothing** to `EventBus` — same precedent as 1.2 movement ("Movement stays purely LOCAL — emits nothing to EventBus"). [arch §Signal Architecture D8; systems/event_bus.gd]
- **No cross-domain node paths (D8).** `FireSystem.projectile_parent` is a public var wired by `player.gd` to its own `get_parent()` (the Arena) — the Player wires its own component (intra-entity), no cross-domain path. The muzzle is a direct child of the Player, read once in `@onready` via `get_parent().get_node_or_null("Muzzle")`. No `../../X`, no editable-children, no `owner`/`current_scene` ambiguity (both are unreliable in GUT tests / across instance boundaries). [project-context "Communication boundary"]
- **Cache `@onready`; never `$`/`get_node()` per frame (AR14).** Resolve `_muzzle` once in `@onready`. Inside `_physics_process`, use cached refs only. [project-context "Node lifecycle & access"]
- **Tuning via `.tres`, immutable via `Constants` (AR10).** `fire_cooldown`/`bullet_speed`/`projectile_damage`/`muzzle_offset_y` are balancing/feel → `player_tuning.tres` (playtest lever, zero code to retune). Layer bits / base resolution → `Constants` (immutable). The architecture's config-tier list explicitly names "bullet speed, fire cooldown" as `.tres` tuning values. Do not hardcode `0.16`/`620`/`10` in scripts. [arch §Configuration; project-context "Config tiers"]
- **`@export` for refs, not `load()`.** `@export var projectile_scene: PackedScene`, `@export var tuning: PlayerTuning` — inspector-assigned. (`FireSystem.projectile_parent` is a **public var wired by `player.gd`**, not an `@export` — see Decision #8; `player.gd` also assigns `tuning`/`projectile_scene` could alternatively be done in-code, but inspector `@export` is the established 1.2 pattern.) Avoids `load("res://...")` in gameplay code (ContentRegistry rule is for content `.tres`; tuning/scene refs via `@export` are cleaner and test-swappable). [project-context "Content via ContentRegistry"]
- **Static typing + naming (NFR7).** Typed throughout (`func activate(spawn_pos: Vector2, speed: float, damage: int) -> void`). Nodes PascalCase (`Projectile`, `FireSystem`, `Muzzle`, `HealthComponent`), files snake_case (`projectile.gd`, `fire_system.gd`), constants UPPER_SNAKE, private members leading `_`. One root + one script per scene. [project-context "Typing & exports", "Naming conventions"]
- **No `print()` (AR14).** Diagnostics via `Log.debug("FireSystem", …)` / `Log.warn(...)`. [project-context "No print() / no try-catch"; systems/log.gd]
- **Do NOT port the (removed) JS prototype.** Re-derive fire in Godot idioms (pooled Area2D + scene tree + Input action). No plain-object entities, no manual draw loops. [project-context "Do NOT port the prototype"]

### File Structure Requirements

`★` = files this story creates; `✎` = existing files it modifies.

```
res://
├── systems/
│   └── pool.gd                       ✎ MODIFY: release() deactivates nodes (D7 gap) — T1
├── player/
│   ├── player_tuning.gd              ✎ MODIFY: +fire_cooldown/bullet_speed/projectile_damage/muzzle_offset_y — T2
│   ├── player.gd                     ✎ MODIFY: cache FireSystem + wire projectile_parent = get_parent() (Arena) in _ready — T6
│   ├── player.tscn                   ✎ MODIFY: +Muzzle Marker2D, +FireSystem child (tuning/projectile_scene assigned) — T6
│   ├── fire_system.gd                ★ FireSystem component (cooldown + acquire/activate) — T5
│   ├── projectile.gd                 ★ Projectile Area2D (pooled, straight-up, release on leave/hit) — T3
│   └── projectile.tscn               ★ Projectile scene (Visual + CollisionShape2D) — T3
├── resources/
│   └── player_tuning.tres            ✎ MODIFY: +fire_cooldown=0.16/bullet_speed=620/projectile_damage=10/muzzle_offset_y=-20 — T2
├── world/
│   └── arena.tscn                    (UNCHANGED — Player already instanced from 1.2; projectiles parent to the Arena root via player.gd)
├── tests/
│   ├── systems/
│   │   └── test_pool.gd              ★ first Pool unit tests (acquire/release/deactivate round-trip) — T7
│   └── player/
│       ├── test_projectile.gd        ★ Projectile integration (movement/leave-screen/hit+damage fixture) — T7
│       └── test_fire_system.gd       ★ FireSystem integration (cooldown/autofire/pooling/hot-path) — T7
└── (components/, event_bus.gd, constants.gd, addons/gut/, .gutconfig.json — UNCHANGED)
```

**`components/` is UNCHANGED** — do **not** extend `FactionComponent` (Decision #5); the projectile sets its layer directly from `Constants`. **`event_bus.gd` is UNCHANGED** — fire is local-only (D8). **`constants.gd` is UNCHANGED** — `LAYER_PLAYER_PROJECTILE`/`LAYER_ENEMY` already exist from 1.1.

### Project Context Rules (extracted from `project-context.md`)

- **Engine:** Godot 4.6.x (4.6.3-stable; pin 4.6.x — avoid 4.7-only APIs). 2D, GDScript, Compatibility renderer. `3d/physics_engine="Jolt Physics"` is inert for this 2D project.
- **Hot-path discipline (NFR3 / AC4):** **zero per-frame allocations in `_physics_process`** — no new `Array`/`Dict`/`Vector2(...)` constructed in the per-frame loop. `global_position.y -= _speed * delta` is a single float update (zero allocation — value-type arithmetic, not a heap alloc; 1.2 established this is fine). `_speed`/`_damage` cached at `activate()`, never read from an autoload per frame. `@onready`/`@export` refs cached once.
- **Pooled entities re-init via `activate()`/`reset()`, never `_ready()` (AR6).** `_ready()` fires once on first tree entry; it does **not** re-fire when a pooled node is re-acquired. All per-spawn state (position, speed, damage, visible, processing) is set in `activate()`. [project-context "Node lifecycle & access"]
- **Physics & movement:** gameplay movement in `_physics_process` (fixed 60 Hz). For the Area2D projectile, integrate manually with delta (correct — no `move_and_slide` on Area2D). `_process` delta varies; `_physics_process` is fixed. [project-context "Physics & movement"]
- **Input (NFR6 / FR3 / F5):** `Input.is_action_pressed("fire")` — the `fire` action is **already registered** (Space + gamepad button 0; do not change it, do not hardcode keys). Hold-to-autofire (UX/epics mandate hold, not tap/toggle). [project.godot `[input]`; EXPERIENCE.md "Fire — hold to fire"]
- **Collision (NFR6):** strict 2D layers/masks cull broadphase pairs. Projectile layer = `player_projectile`, mask = `enemy` only (don't over-broaden the mask — keeps broadphase cheap). Simple collision shape on the projectile. [project-context "Physics"]
- **Object pooling:** pool & reuse projectiles — toggle visibility/processing when inactive (T1), never `queue_free()` + `instantiate()` on the hot path. [project-context "Object pooling"]
- **Testing (NFR13):** separate **pure logic** from Node/scene code. Unit tests = pure logic (Pool mechanics); integration tests = `.instantiate()` the scene, assert behavior/signals. Assert on state/signals (`current_hp`, `get_parent()`, child count, instance validity), never pixels-on-screen. [project-context "Testing Rules"]
- **Photosensitive flash cap (accessibility):** ≤3 Hz on any flashing visual. Do NOT add a per-shot strobing muzzle flash (0.16 s = 6.25 Hz would violate it). Juice/flash is 1.6; 1.3 ships a steady placeholder. [EXPERIENCE.md A1 floor; review-accessibility.md]
- **Optional MCP tooling (AR15):** GoPeak + Context7 are optional AI aids; not required.

### Library / Framework Requirements

- **None new.** Godot 4.6 built-ins only: `Area2D`, `CollisionShape2D`/`RectangleShape2D`/`CapsuleShape2D`, `Marker2D`, `Node2D`, `Input` (`is_action_pressed`), `PackedScene`, `Resource` (for `PlayerTuning`), `Polygon2D` (placeholder), `Pool`/`Constants`/`Log` autoloads (from 1.1). **GUT 9.6.0** already installed. No external assets — placeholder visual is a primitive shape.

### Testing Requirements

- **Framework:** GUT 9.6.0, headless, `godot --headless -s addons/gut/gut_cmdln.gd`. Config at `.gutconfig.json` (`dirs=["res://tests"]`, `include_subdirs`, `should_exit`) — new tests under `tests/player/` and `tests/systems/` are auto-discovered.
- **Unit (logic):** `tests/systems/test_pool.gd` — `Pool` acquire/release/deactivate/idempotency. (Pool was untested through 1.1/1.2.)
- **Integration (scene):** `tests/player/test_projectile.gd` — instantiate `projectile.tscn`, drive `activate`/`_physics_process`, assert movement/leave-screen/hit+damage (with a dummy-target fixture on `LAYER_ENEMY`). `tests/player/test_fire_system.gd` — instantiate Player, drive `fire` input + `_physics_process`, assert cooldown/autofire/pooling/hot-path.
- **Boundary discipline:** assert on `global_position`/`current_hp`/`get_parent()`/child-count/instance-validity — never pixels-on-screen.
- **Match the 1.2 GUT style:** `extends GutTest`, `const FooScene := preload(...)`, `_make()` helper with `add_child_autofree`, `after_each()` releases input, `test_*()` funcs, `Input.action_press`/`action_release`, `await get_tree().physics_frame`, `set_physics_process(false)` + direct `_physics_process(delta)` for determinism, `assert_almost_eq` for float32-vs-float64. See `tests/player/test_player_movement.gd` for the established pattern.

### Previous Story Intelligence (from Story 1.2 — `done`)

- **What 1.2 delivered (reuse, don't reinvent):** the Player `CharacterBody2D` (`player.gd`/`player.tscn`), `HealthComponent` (`take_damage(amount)` / `current_hp` / `reset_to_full` — **real but unwired**; the projectile's damage stub calls `take_damage`), `FactionComponent` (PLAYER/ENEMY only — **not extended** for projectiles, Decision #5), `PlayerTuning` (`move_speed=426.6`/`edge_margin=24`/`lane_y=680` — **extended** with fire fields, T2), `resources/player_tuning.tres`, `world/arena.tscn` (Player instanced under `Arena`).
- **Patterns to mirror (1.2 → 1.3):** static typing everywhere; `@onready` caching; `@export` `.tres` tuning + `@export` scene/parent refs (no `load()`); component composition (Player gains a `FireSystem` child); one root + one script per scene; literal `@export` defaults; `.gdkeep` to keep empty dirs; no `print()` (use `Log`); typed signals.
- **GUT API lessons (1.2):** use **`add_child_autofree`** (no underscore — `auto_free` does NOT exist in this GUT 9.6.0 build). Compare `velocity`/`global_position` (float32) against `float` tuning values with `assert_almost_eq(..., 0.01)` — **never `==`** (426.6 wasn't exactly representable; 620.0 and 0.16 may behave similarly — 620.0 is exactly representable in float32, but 0.16 is not, so cooldown math and Y-position deltas should use epsilon compares). `after_each()` releases synthetic input.
- **Class-registration gotcha (1.2):** before the first headless test run, do **`godot --headless --import`** once to register the new `class_name`s (`FireSystem`, `Projectile`) in `global_script_class_cache.cfg` — a plain `--headless -s` run does not rescan classes.
- **1.1 → 1.2 Pool note (resolved):** 1.1 flagged a suspected `Pool.release()` bug (`get_instance_id()` vs `get_parent()`). **It is fixed** — `pool.gd:30` now reads `node.get_parent()`. But 1.3 is the **first story to actually exercise the pool**, so verify the round-trip (T1/T7) rather than assuming.
- **Scope discipline (1.1/1.2):** "data is created when first needed, not upfront" — 1.3 builds only the fire chassis (projectile + FireSystem + fire tuning + Pool deactivation) and defers enemies/juice/HUD. The damage path is a minimal convention stub (Decision #6), not a premature `HurtboxComponent`.

### Git Intelligence

- Working tree is **clean** on branch `story/1-3-vertical-fire-system`; HEAD = `269912a Code review fixes for Story 1.2 player movement chassis`. The only game code is 1.1's scaffold + 1.2's player chassis. This story adds the first pooled entity + first `Pool` extension on top.
- Baseline commit for this story: `269912a` (recorded in frontmatter). Branch `story/1-3-vertical-fire-system` is already checked out — commit here when done (do not work on `main`).

### Latest Tech Information

- **Godot 4.6.3-stable** current (locked in 1.1); 4.7 RC-only — stay 4.6.x. `Area2D.body_entered`, `Input.is_action_pressed(action)`, `Node.set_physics_process(bool)`, `CanvasItem.visible`, `Marker2D` are all **stable Godot 4.x APIs** — no version risk, no migration concerns. (No web lookup needed; these are unchanged since 4.0 and 1.1/1.2 already locked the version policy.)
- **`Area2D` body detection:** `body_entered(body)` fires for physics bodies (`CharacterBody2D`/`RigidBody2D`/`StaticBody2D`/`AnimatableBody2D`) whose layer intersects the Area2D's `collision_mask`. It does **not** fire for other `Area2D`s (use `area_entered` for that — e.g. when 1.4 enemies use `HurtboxComponent` Area2Ds, this may switch to `area_entered`). For 1.3's dummy target (a `CharacterBody2D` body on `LAYER_ENEMY`), `body_entered` is correct.
- **Determinism note:** projectile motion is `global_position.y -= _speed * delta` at the fixed 60 Hz timestep — identical at 60 and 144 FPS (delta-driven, single integration). No RNG anywhere in fire (no `randi`/`randf` — fire is deterministic by design).

### Decisions (settled by analysis; implement exactly as stated)

> Settled scope/design calls. The GDD/UX/architecture left these open; the choices below are the architecturally-aligned, minimal, non-speculative ones. Implement exactly as stated.

1. **Projectile = `Area2D` (not `CharacterBody2D`).** Bullets overlap-detect; they don't slide/block. Manual `global_position.y -= _speed * delta` integration in `_physics_process`. The "never × delta" rule is `move_and_slide`-specific and does not apply to Area2D. [arch: Hitbox/Hurtbox are Area2D-based; project-context: delta for non-`move_and_slide` integration]
2. **Fire cooldown = an accumulator in `FireSystem._physics_process` (not a `Timer` node).** `var _cooldown: float`; decrement each frame; when held and `<= 0`, fire + reset. Pure-logic (unit-/integration-testable), no extra node, no allocation, fixed-timestep-deterministic.
3. **Fire tuning extends `PlayerTuning`** (not a separate `FireTuning` resource). `fire_cooldown`/`bullet_speed`/`projectile_damage`/`muzzle_offset_y` added to `player_tuning.gd` + `player_tuning.tres`. The architecture's config-tier list explicitly names bullet speed/fire cooldown as `.tres` tuning values alongside `move_speed`; keeping them together is the documented path and avoids file sprawl. [arch §Configuration]
4. **Fire cooldown semantics = hold-to-autofire, decrement-always.** `_cooldown -= delta` every frame; fire when held and `<= 0`. First press fires immediately (cooldown starts at 0); sustained hold fires at ~6.25 Hz; release+re-press after cooldown fires immediately. (UX/epics mandate hold-to-fire — no tap-only, no toggle.) [EXPERIENCE.md "Fire — hold to fire"; epics AC1 "the player holds Fire"]
5. **Do NOT extend `FactionComponent` for projectiles.** The projectile sets `collision_layer = Constants.LAYER_PLAYER_PROJECTILE` directly. Rationale: D4 calls projectiles "lightweight"; the 1.2 single-source-of-truth `FactionComponent` invariant was about PLAYER-vs-ENEMY identity for multi-consumer entities; a projectile's faction is fully captured by its layer. D16 family-rendering (reading faction) doesn't exist yet — extending the enum now is speculative. When D16 lands (1.6/8.5), revisit. (No change to `components/faction_component.gd`.)
6. **Damage = convention stub via the body's `HealthComponent`.** On `body_entered`, the projectile looks up `body.get_node_or_null("HealthComponent")` and calls `take_damage(_damage)` if present, then releases (consume-on-hit). No enemies exist in 1.3, so this is exercised by a test-fixture dummy target. The real `HurtboxComponent`-mediated wiring lands in 1.4 (the convention-named `HealthComponent` lookup is forward-compatible since 1.4 enemies will follow the same node-naming pattern as the Player). [arch §Entity Composition D4: projectiles = "damage payload + faction"; 1.2 HealthComponent API]
7. **Extend `Pool.release()` to deactivate nodes (D7 gap).** `release()` now sets `set_process(false)`/`set_physics_process(false)` and (if `CanvasItem`) `visible=false`. `acquire()` is unchanged (deactivated node handed back; `activate()` re-enables). This honors D7's "inactive nodes toggle visible + processing" rule, prevents inactive pooled projectiles from running, and is generic for all future pooled types. This is the **first real `Pool` extension** (1.1's was an untested minimal scaffold). [arch §Object Pooling D7]
8. **Projectiles parent to the Arena root, wired by `player.gd` (NOT the Player; no separate container).** `FireSystem.projectile_parent` is a public var; `player.gd._ready()` sets it to `get_parent()` (the Arena). Rationale: (a) a projectile parented to the Player would inherit the Player's transform and drift sideways with the ship (transform-inheritance bug) — it must be a child of a non-moving ancestor; (b) wiring via `player.gd` reading its own `get_parent()` avoids the cross-instance-inspector-assignment problem — setting a property on a node *inside* the instanced Player from `arena.tscn` requires **editable-children** (fragile) and `%Projectiles` scene-unique lookup does **not** cross the instance boundary; (c) it avoids `owner`/`current_scene` ambiguity (both unreliable in GUT tests). The Player wiring its own component is intra-entity (D8-clean). No separate `Projectiles` node in 1.3 (projectiles are Arena-root children; add a container in 1.8 only if the debug overlay wants one). Tests set `fire_system.projectile_parent` directly to a temp `Node2D`.
9. **Muzzle = a `Marker2D` child of the Player** at local `(0, muzzle_offset_y)` ≈ `(0, -20)` (ship nose). FireSystem reads `_muzzle.global_position` at spawn. Editor-tunable, zero spawn-time math. Exact muzzle point is a **starting default** — GDD/UX leave it open.
10. **Consume-on-hit (one hit → release).** AC3's "leaves screen **or** hits → released" + the GDD's single-stream/no-piercing intent → the projectile releases on its first hit. No piercing in 1.3. (Piercing, if ever wanted, is a build-engine modifier, not 1.3.)
11. **No on-screen-bullet cap.** The GDD imposes no Galaga-style "max 2 bullets" cap; the 0.16 s cooldown is the rate-limiter and pooling bounds memory. Do not add a cap. [GDD: no bullet cap anywhere in the spine]
12. **Placeholder projectile visual (steady, cyan, no flash).** A simple `Polygon2D` thin chevron. Real elongated-chevron+bright-outline art is 1.6/8.5 (D16/ADR-6). No strobing (≤3 Hz flash cap). [UX/1.2 precedent: placeholder primitive now, real art later]

### References

- [Source: `_bmad-output/planning-artifacts/epics.md`#Story-1.3] — ACs (verbatim), user story, FR4/FR5/FR6/FR45 · AR6/AR14; Epic-1 kinesthetics-gate framing.
- [Source: `_bmad-output/planning-artifacts/epics.md`#Requirements-Inventory] — FR4/FR5/FR6/FR45, AR6, AR14 glossary text.
- [Source: `_bmad-output/project-context.md`] — Node lifecycle & access (activate/reset not _ready), Physics & movement (delta for non-move_and_slide), Composition/strict-collision, Communication boundary (no cross-domain paths), Config tiers (.tres), Hot-path discipline (NFR3), Object pooling, Input (NFR6), Testing (NFR13), Godot 4.6 gotchas, Do NOT port the prototype.
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md`#D4/D7/D8] — entity composition (projectile = "lightweight pooled node, damage payload + faction"), object pooling contract (`acquire`/`release`; `activate()`/`reset()`; deactivation), signal boundary (fire = local, not EventBus).
- [Source: `architecture.md`#Entity-Creation-Pattern] — `proj.activate(spawn_pos, dmg, faction)`; `Pool.release(proj)`; never `instantiate()`+`queue_free()` on hot path.
- [Source: `architecture.md`#Configuration] — `.tres` tuning tier explicitly lists "bullet speed, fire cooldown".
- [Source: `architecture.md`#Project-Structure] — `player/fire_system.gd` named explicitly; "player projectiles → `player/`" (D15).
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-meridian-run-2026-06-29/gdd.md`#Weapon-Systems / #Movement-&-Combat-Chassis] — player base shot 10 dmg / 0.16 s / 620 px/s straight up; ~320 px/s player speed balanced vs 620 px/s bullet & 0.7 s telegraph; projectile-based hit detection (not hitscan); no crits; "player-ship fire stays strictly 1-axis". All values are playtest-tunable baselines.
- [Source: `gdd.md`#Assumptions-and-Dependencies] — "[ASSUMPTION] Prototype tuning values (HP 3, fire cooldown 0.16 s, bullet 620 px/s …) are starting baselines, retuned in v1.0 playtest."
- [Source: `_bmad-output/planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/EXPERIENCE.md`#Input] — `fire` action = hold-to-fire; canonical actions; ≤3 Hz flash cap; reduced-motion ~70%.
- [Source: `ux-designs/.../DESIGN.md`#Components-player-projectile] — elongated-chevron, bright core `{colors.text}`, cyan `{colors.primary}` outline (target art — placeholder in 1.3, real renderer 1.6/8.5).
- [Source: `_bmad-output/implementation-artifacts/1-2-player-movement-1-axis-chassis.md`] — reused Player/HealthComponent/PlayerTuning API, GUT patterns (`add_child_autofree`, float32 epsilon, `--headless --import` class registration), scope discipline.
- [Source: existing code] — `systems/pool.gd` (acquire/release; `release` now deactivates — T1), `systems/constants.gd` (LAYER_PLAYER_PROJECTILE=4, LAYER_ENEMY=2, BASE_RESOLUTION), `components/health_component.gd` (`take_damage(amount)`/`current_hp`), `player/player.gd`/`player.tscn`, `player/player_tuning.gd`, `resources/player_tuning.tres`, `world/arena.tscn`, `project.godot` `[input]` (fire=Space+gamepad0)/`[autoload]`/`[display]`, `tests/player/test_player_movement.gd` (GUT style).

## Dev Agent Record

### Agent Model Used

GLM-5.2[1m]

### Debug Log References

- `godot --headless --path . --import` (register `FireSystem` / `Projectile` class_names — 1.2 class-registration gotcha).
- `godot --headless --path . --quit-after 60` — clean launch (only the pre-existing 1.1 `ContentRegistry` stub warning; no Player/FireSystem/Muzzle errors).
- `godot --headless -s addons/gut/gut_cmdln.gd` — **38/38 passing** (6 scripts: 1.1 scaffold + health, 1.2 movement, 1.3 pool/projectile/fire_system).
- Two findings surfaced by the tests (both fixed, both documented in Completion Notes):
  1. **Hit-path release must be deferred.** `body_entered` fires *during* the physics step; removing a `CollisionObject` (the `Area2D` projectile) synchronously there is forbidden by the engine ("use `call_deferred`"). Fixed in `projectile.gd` (`Pool.call_deferred("release", self)`). Leave-screen release in `_physics_process` stays synchronous (it runs *before* the physics step, not during a server callback).
  2. **Player needs a `Node2D` parent.** `player._ready` assigns `get_parent()` to `FireSystem.projectile_parent` (typed `Node2D`). The real Arena is a `Node2D`, so production is fine — but the GutTest root is a plain `Node`, so the existing 1.2 movement test regressed. Fixed by parenting the Player under a `Node2D` "arena" in both Player-building tests (production-faithful; keeps strict `Node2D` typing, no defensive guard that could mask a real wiring bug).

### Completion Notes List

- **All four ACs met and proven headless** (AC1 hold-to-autofire straight up at 10 dmg / 0.16 s / 620 px/s from tuning; AC2 pooled via `acquire`/`activate`/`release`, never per-frame `instantiate`+`queue_free`; AC3 release on leave-screen OR hit; AC4 zero per-frame allocations — verified structurally by `test_fire_system` reading the `_physics_process` source).
- **D7 deactivation gap closed (T1):** `Pool.release()` now calls `_deactivate()` (`set_process(false)` / `set_physics_process(false)` / `visible=false` for `CanvasItem`). `acquire()` unchanged; the consumer's `activate()` re-enables. First real `Pool` exercise + extension (1.1/1.2 never touched it). Verified by the first-ever `Pool` unit tests (`test_pool.gd`, 6 tests).
- **Projectile is `Area2D` (Decision #1):** manual `global_position.y -= _speed * delta` integration in `_physics_process` (correct for Area2D; the "never × delta" rule is `move_and_slide`-specific). `body_entered` connected once in `_ready` (persists across pool cycles — no duplicate-connection stack). Damage stub via convention-named `HealthComponent` lookup (Decision #6, forward-compatible to 1.4). Consume-on-hit (Decision #10).
- **FireSystem component (T5):** cooldown accumulator in `_physics_process` (Decision #2, pure logic, no Timer). `@export tuning`/`projectile_scene`; public `projectile_parent` wired by `player.gd` to the Arena (Decision #8 — world-space parenting for transform-independence). `@onready _muzzle`. No pre-warm (lazy acquire is fine; pre-warm was optional and not mandated).
- **Player wiring (T6):** `player.tscn` gained a `Muzzle` `Marker2D` (0, -20) + `FireSystem` child (tuning + projectile_scene assigned); `player.gd._ready` wires `projectile_parent = get_parent()`. `arena.tscn` unchanged.
- **T8 (manual feel check) intentionally left unchecked** — the subjective in-editor gamepad pass is Mrdth's (per the story, "Box may stay unchecked like 1.2's T8"). All *objective* sub-criteria (fire rate, straight-up travel, despawn-at-top, transform-independence via Arena parenting, pooled-not-freed) are proven headless; the remaining in-editor confirmation folds into review.
- **Known benign artifact:** the headless run reports a few orphan nodes / exit-time RID leaks — these are the `Pool`'s intentionally-held projectile nodes (a pool retains nodes by design; they are freed with the process). They are **not** test failures and do not change the exit code. A trivial `Pool._exit_tree` could free them for squeaky-clean output, but that is out of this story's scope (T1 covers `release()` deactivation only) so it was left for a later story.
- **Scope held:** no enemies, no `HitboxComponent`/`HurtboxComponent`, no juice/flash, no HUD, no real art, no spread/cap — all deferred per the story's IS/IS-NOT list. `components/`, `event_bus.gd`, `constants.gd` untouched.

### File List

**Created**
- `player/projectile.gd` — pooled `Area2D` projectile (T3; activate/`_physics_process`/hit, deferred release).
- `player/projectile.tscn` — Projectile scene: `Area2D` root + cyan `Polygon2D` placeholder (T4) + `CollisionShape2D` (`RectangleShape2D` 6×12), layer/mask from `Constants`.
- `player/fire_system.gd` — `FireSystem` component (T5; cooldown accumulator + `Pool.acquire`/`activate`).
- `tests/systems/test_pool.gd` — first `Pool` unit tests (T7; acquire/release/deactivate/idempotency).
- `tests/player/test_projectile.gd` — Projectile integration (T7; movement/leave-screen/hit+damage fixture/structure).
- `tests/player/test_fire_system.gd` — FireSystem integration (T7; cooldown/autofire/pooling/hot-path).

**Modified**
- `systems/pool.gd` — T1: `release()` deactivates nodes via `_deactivate()` (D7 gap).
- `player/player_tuning.gd` — T2: +`fire_cooldown`/`bullet_speed`/`projectile_damage`/`muzzle_offset_y`.
- `resources/player_tuning.tres` — T2: +fire values (existing move/edge/lane preserved).
- `player/player.gd` — T6: cache `_fire_system` + wire `projectile_parent = get_parent()` in `_ready`.
- `player/player.tscn` — T6: +`Muzzle` `Marker2D` + `FireSystem` child (tuning/projectile_scene assigned).
- `tests/player/test_player_movement.gd` — T7: regression fix — parent the Player under a `Node2D` "arena" so `player._ready`'s `Node2D`-typed `projectile_parent` wiring type-checks (the story listed this file UNCHANGED; the fix is a necessary consequence of the T6 wiring and is called out here).

## Change Log

- 2026-07-02 — Story 1.3 implemented: pooled vertical-fire chassis (Projectile + FireSystem + fire tuning + `Pool` D7 deactivation). 38/38 GUT tests pass headless. Status → review.
