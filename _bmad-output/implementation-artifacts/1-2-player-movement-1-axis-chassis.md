---
baseline_commit: e6bb571ec32f443d9bd1c82f9a88990c0435fb66
---

# Story 1.2: Player Movement — 1-Axis Chassis

Status: review

> **Epic 1 — Combat Chassis & Feel** (v0.1 kinesthetics gate) · second story.
> Builds directly on the **done** scaffold from Story 1.1 (domain tree, 11 autoloads, Input Map,
> GUT, Arena main scene). This story creates the **first gameplay entity** — the player ship — and
> the **first reusable components** + **first `.tres` tuning resource**. Every pattern established
> here (component composition, `CharacterBody2D` + `move_and_slide()`, `@export` tuning, GUT
> integration tests) is inherited by 1.3 (fire), 1.4 (enemies), 1.5 (life economy), 1.6 (juice).
> Read `_bmad-output/project-context.md` before writing code.

## Story

As a player,
I want to glide my ship left/right along the bottom lane with responsive, screen-clamped movement,
so that the 1-axis chassis feels tight and fair.

## Acceptance Criteria

*(Verbatim from `epics.md` Story 1.2; refs: FR1, FR2, FR3 · AR5, AR6, AR14)*

1. **AC1 — Horizontal-only, screen-clamped, ~320 px/s.** Given the player in the arena, When holding Move left/right, Then the ship moves **horizontally only**, clamped to screen edges, at ~320 px/s (from `player_tuning.tres`).
2. **AC2 — Framerate-independent physics.** Given movement in `_physics_process`, When `move_and_slide()` is called, Then velocity is set directly (NOT × delta), and motion is identical at 60 and 144 FPS.
3. **AC3 — Gamepad continuous + deadzone; keyboard parity.** Given a gamepad, When the stick is tilted, Then movement is continuous with a deadzone; keyboard also works.
4. **AC4 — CharacterBody2D scene + components.** Given the player node, Then it's a `CharacterBody2D` scene with `@onready`-cached refs, a `HealthComponent`, and a `FactionComponent` (player).

> **Requirement glossary (from `epics.md` Requirements Inventory):**
> - **FR1** — Player ship moves **horizontally only (1-axis)**, locked to the bottom lane of a single fixed screen, clamped to the visible play area. No auto-scroll / side-scroll / vertical player movement.
> - **FR2** — Movement runs on the fixed-timestep physics loop (`CharacterBody2D` velocity + `move_and_slide()`) at baseline **~320 px/s**, reading Input Map Move actions; analog stick applies a deadzone and is continuous (not digital).
> - **FR3** — Every player/UI action is an Input Map action with **both** a keyboard and a gamepad binding; gameplay code never hardcodes keys/scancodes.
> - **AR5** — Composition over inheritance: entities built from component nodes (`HealthComponent`, `HitboxComponent`/`HurtboxComponent`, `FactionComponent`, `StateMachine`); strict collision layers.
> - **AR6** — Object pooling (`Pool` autoload; `acquire()`/`release()`; re-init via `activate()`/`reset()`). **N/A to this story** — the player is a single persistent entity, not pooled. Pooling is exercised by projectiles in 1.3.
> - **AR14** — Godot 4.6 gotchas: `move_and_slide()` takes **no args** and applies delta internally; cache `@onready`; typed code; no `print()`.

## Scope — what this story IS and IS NOT

**This is the player-movement chassis. It moves one ship left/right and locks in the component + tuning patterns. It does not build combat, life economy, or juice.**

- **IS:** `player.tscn`/`player.gd` (`CharacterBody2D`, 1-axis movement, screen-clamp); the first reusable **components** (`HealthComponent`, `FactionComponent`) — real, minimal, unit-tested; the first **`.tres` tuning resource** (`player_tuning.tres`, `move_speed = 320`); a placeholder ship visual (so movement is visible for the feel gate); the Player instanced into `arena.tscn`; GUT tests (pure-logic unit + scene integration).
- **IS NOT:** no firing/projectiles (1.3); no enemies or anything for the player to collide with/take damage from (1.4); no wave-heal / ship-loss / game-over economy wiring (1.5 — `HealthComponent` exists but is **not** wired to damage sources, the wave controller, or `RunState`/`EventBus.ship_lost`); no hit-flash/screen-shake/movement juice (1.6); no HUD or on-ship HP bar (1.7); no real art or the D16 shape+outline renderer (placeholder only — real art/renderer in 1.6/8.5); no `HurtboxComponent` yet (nothing deals damage until 1.4/1.6); no input remap/deadzone **slider** UI (E8 8.4 — the action *architecture* already supports it, that's all 1.2 needs).
- **`HealthComponent` is built real but not wired** (Decision #1). The component holds HP + `take_damage()`/`heal()`/`reset()` + `health_changed`/`died` signals and is unit-tested in isolation. What's deferred to its owning systems: damage **sources** (1.4/1.6), per-wave **reset by the wave controller** (1.5), and **ship-loss → `EventBus.ship_lost`/`game_over`** (1.5). AC4 requires the component *present*; this satisfies it honestly without bleeding 1.5's economy into 1.2.
- **`FactionComponent` is built real but rendering-deferred.** It declares `faction = PLAYER` and exposes the collision-layer bit. The D16 family-driven vector renderer (bright outline, rescuer-arrowhead) is juice/art (1.6/8.5); 1.2 uses a static placeholder shape.

## Tasks / Subtasks

*(ACs in parens. Values cited are normative — see Dev Notes for the why.)*

- [x] **T1 — `FactionComponent`** (AC4, AR5) — `components/faction_component.gd`
  - [x] `class_name FactionComponent`, `extends Node`. `enum Faction { PLAYER, ENEMY }`.
  - [x] `@export var faction: Faction = Faction.PLAYER`.
  - [x] `func get_collision_layer() -> int` → returns `Constants.LAYER_PLAYER` / `Constants.LAYER_ENEMY` based on `faction` (single source of truth for the layer bit; D16 will later also read `faction` for rendering family).
  - [x] No gameplay logic beyond the accessor. (The D16 shape/outline renderer is deferred.)
- [x] **T2 — `HealthComponent`** (AC4, AR5) — `components/health_component.gd`
  - [x] `class_name HealthComponent`, `extends Node`.
  - [x] `@export var max_hp: int = 3` (mirrors `Constants.BASE_HP` = 3; use a **literal** default, not an autoload reference, so the `@export` default parses).
  - [x] `var current_hp: int`; in `_ready()` set `current_hp = max_hp`.
  - [x] `signal health_changed(current: int, maximum: int)`; `signal died`.
  - [x] `func take_damage(amount: int) -> void` — clamps `amount ≥ 0`, subtracts, clamps `current_hp ≥ 0`, emits `health_changed`; if `current_hp == 0` and not already dead, emits `died` (guard against double-`died`).
  - [x] `func heal(amount: int) -> void` — clamps, emits `health_changed` (no revive-from-zero semantics decided here; healing a dead ship is 1.5's call — keep `heal` a pure clamp for now).
  - [x] `func reset_to_full() -> void` — `current_hp = max_hp`; emit `health_changed`. (This is the hook the 1.5 wave controller will call each wave — D1.)
  - [x] **Deferred (do NOT build here):** no damage sources call `take_damage` yet; no wave-reset wiring; no `EventBus.ship_lost` emission; no death-respawn. The component is a complete, tested building block awaiting its callers.
- [x] **T3 — Player tuning resource** (AC1, AR10) — schema + `.tres` instance
  - [x] `player/player_tuning.gd`: `class_name PlayerTuning`, `extends Resource`.
  - [x] `@export var move_speed: float = 320.0` ← **the AC1-mandated value** (FR2 baseline; "the chassis's central feel param" per GDD).
  - [x] `@export var edge_margin: float = 24.0` ← px kept inside the left/right play-field edges (clamp inset). **Starting default for the feel gate** — GDD/UX leave the exact margin open.
  - [x] `@export var lane_y: float = 680.0` ← fixed bottom-lane Y (≈40 px above the 720 bottom). **Starting default** — GDD/UX leave the exact lane Y open; mockup shows ship ~14 px from bottom in a 54 px lane band.
  - [x] `resources/player_tuning.tres` — instance of `PlayerTuning` with `move_speed=320`, `edge_margin=24`, `lane_y=680`. (Schema script lives with the `player/` domain; the `.tres` instance lives in `resources/` — per "schema `.gd` with owning domain, `.tres` instances only in `resources/`".)
- [x] **T4 — Player scene + script** (AC1, AC2, AC3, AC4, AR5, AR14) — `player/player.gd` + `player/player.tscn`
  - [x] Root node **`Player`** (`CharacterBody2D`) — meaningful PascalCase name, not the type default. Root script `player.gd` (`extends CharacterBody2D`).
  - [x] Children: a placeholder **visual** (T5), a **`CollisionShape2D`** (simple `CircleShape2D` or `CapsuleShape2D`, radius ~10–12 px — the "clean small hitbox" per GDD; required so `move_and_slide()` has a valid body and to silence Godot's no-shape warning), a **`HealthComponent`** node, a **`FactionComponent`** node (`faction = PLAYER`).
  - [x] `collision_layer = Constants.LAYER_PLAYER` (bit 0 → value `1`). `collision_mask = 0` for now — nothing exists for the player to collide with; 1.4/1.6 will add `LAYER_ENEMY` | `LAYER_ENEMY_PROJECTILE` to the mask when damage lands. (Set layer via the integer bitmask; there are no 2D layer names in `project.godot`.)
  - [x] `@export var tuning: PlayerTuning` — assign `resources/player_tuning.tres` in the inspector. **No `load("res://...")` in code** (avoids scattered loads; inspector-assigned, trivially swapped in tests).
  - [x] `@onready`-cache child refs: `@onready var _health: HealthComponent = $HealthComponent`, `@onready var _faction: FactionComponent = $FactionComponent`. (AC4: `@onready`-cached refs. Never `$`/`get_node()` per frame.)
  - [x] Compute + cache bounds once in `_ready()`: `_min_x = tuning.edge_margin`; `_max_x = float(Constants.BASE_RESOLUTION.x) - tuning.edge_margin`. Set `global_position = Vector2(Constants.BASE_RESOLUTION.x / 2.0, tuning.lane_y)` (centered, on the lane).
  - [x] `_physics_process(_delta: float) -> void`:
    - [x] `var axis: float = Input.get_axis("move_left", "move_right")` ← **one call covers keyboard (−1/0/1) and gamepad (−1..1 with the action deadzone applied)** (AC3).
    - [x] **Set the `move_left`/`move_right` per-action `deadzone` to ~0.25** in the Input Map (`project.godot` `[input]` data change — the current default 0.5 is too high for arcade feel; see Decision #3). The user-facing deadzone **slider** remains E8 (8.4).
    - [x] `velocity = Vector2(axis * tuning.move_speed, 0.0)` ← **velocity set directly, y explicitly 0** (1-axis lock). Do **NOT** multiply by delta.
    - [x] `move_and_slide()` ← **no arguments**; Godot applies delta internally (AC2, AR14).
    - [x] `global_position.x = clampf(global_position.x, _min_x, _max_x)` ← corrective screen-clamp (AC1). Motion is still *driven* by velocity + `move_and_slide()`; the clamp only prevents edge escape (see Dev Notes — this is the compliant pattern, not "moving a body by writing `.position` as the primary driver").
  - [x] Static typing throughout; no `print()` (use `Log.debug("Player", …)` if needed).
- [x] **T5 — Placeholder ship visual** (AC1 — so movement is visible; art is 1.6/8.5)
  - [x] Add a simple placeholder child of `Player` — e.g. a `Polygon2D` triangle pointing **up** (rescuer-arrowhead silhouette target), cyan (`#00E5FF`-ish), ~34×34 px footprint (UX mockup target). A `ColorRect` or `Sprite2D` is also acceptable. This is a stand-in, **not** the D16 renderer. Keep it one node, cheap.
- [x] **T6 — Instance Player into the Arena** (AC1) — **MODIFY `world/arena.tscn`** (the one UPDATE file this story touches)
  - [x] Instance `player.tscn` as a child of `Arena`, node named `Player`. (Single persistent entity → pre-placed in the scene, no runtime spawner needed. No `arena.gd` required yet — arena logic/wave controller lands in 1.8/4.4.)
  - [x] Verify launch in editor AND headless (`godot --headless --path . --quit-after 60`) → no errors/warnings, ship visible at bottom-center.
- [x] **T7 — GUT tests** (testing discipline; all ACs) — `tests/player/` + `tests/components/` (both dirs exist from 1.1 with `.gdkeep`)
  - [x] `tests/components/test_health_component.gd` (`extends GutTest`) — **pure-logic unit tests** (no scene): instantiate `HealthComponent`, `add_child` it, assert `take_damage`/`heal` clamp correctly, `health_changed` emits expected `(current, maximum)`, `died` emits exactly once at 0 and not again, `reset_to_full` restores. (Delegates to testable logic — project-context testing rule.)
  - [x] `tests/player/test_player_movement.gd` (`extends GutTest`) — **integration tests** (instantiate the scene):
    - [x] `var p := preload("res://player/player.tscn").instantiate(); add_child(p)` (auto-free via `add_child(auto_free(p))` or `teardown`).
    - [x] **AC1 clamp:** simulate holding right via `Input.action_press("move_right")`, step physics (`await get_tree().physics_frame` a few times, or call `p._physics_process(delta)` directly for determinism), assert `global_position.x` increases then **clamps at `_max_x`** (start the ship near the right edge to exercise the clamp). `Input.action_release("move_right")` to clean up.
    - [x] **AC1 horizontal-only:** assert `global_position.y` never leaves `lane_y` (±epsilon) after stepping with left/right held.
    - [x] **AC3 keyboard + gamepad parity:** `action_press("move_right")` moves right (keyboard-strength path); also assert `InputMap.has_action` for both move actions (already covered by 1.1's scaffold test, but a focused movement assertion here is the AC3 proof).
    - [x] **AC2 framerate-independence (structural):** assert the player sets `velocity` from `axis * move_speed` with **no `* delta`** and calls `move_and_slide()` with no args. (A literal 60-vs-144 displacement test is impractical headless; the code-structure assertion is the enforceable guarantee — and stepping `_physics_process` twice at different `delta` args must yield the same per-call velocity since velocity ignores delta.)
    - [x] **AC4 structure:** assert the instantiated player has `HealthComponent` and `FactionComponent` children, is a `CharacterBody2D`, and `collision_layer == Constants.LAYER_PLAYER`.
  - [x] Run `godot --headless -s addons/gut/gut_cmdln.gd` → **exits green** (existing 1.1 scaffold tests + new 1.2 tests, 0 failures).
- [ ] **T8 — Manual feel check** (kinesthetics gate prep; not an automated AC)
  - [ ] Launch in editor, move with keyboard (A/D, ←/→) and gamepad (stick, D-pad) — confirm continuous, clamped, ~320 px/s. Note any deadzone/edge feel issues for the 1.8 feel gate. (The v0.1 kinesthetics verdict is Story 1.8; 1.2 just needs to *feel plausible* and be tunable via `player_tuning.tres`.)
    > **Dev status (2026-07-02):** objective sub-criteria verified headless — continuous analog input via `Input.get_axis`, screen-clamp tests at both edges (green), `velocity.x == 426.6` independent of delta, `move_left`/`move_right` deadzone lowered to 0.25 (Decision #3, done under T4), kb+gamepad bindings inherited from 1.1. The **subjective gamepad-in-editor feel pass is the one item the dev agent cannot perform** — deferred to Mrdth during review / before the 1.8 feel gate. Box intentionally left unchecked.

## Dev Notes

### Architecture Compliance (must follow — sources cited)

- **Composition over inheritance (AR5 / ADR-4 / D4).** Player = a `CharacterBody2D` scene composed of reusable component child-nodes (`HealthComponent`, `FactionComponent`). No deep inheritance. `HitboxComponent`/`HurtboxComponent`/`StateMachine` land with their owning stories (1.4/1.6) — do **not** build them speculatively here. [arch §Entity Composition D4; project-context "Composition over inheritance"]
- **Player node type is `CharacterBody2D`** (AC4) — movement via `velocity` + `move_and_slide()` in `_physics_process` (fixed 60 Hz timestep). [project-context "Physics & movement"; decision-log inherited rules]
- **`move_and_slide()` — no args, internal delta (AR14).** Set `velocity`, call `move_and_slide()` (takes nothing, applies delta itself). **Never** multiply velocity by delta. This is what makes motion identical at 60 and 144 FPS (AC2). [project-context "Godot 4.6 gotchas"; decision-log]
- **Drive motion via `velocity`, clamp correctively.** Project-context warns "do not move a physics body by writing `.position` each frame — drive it via `velocity`." Here velocity + `move_and_slide()` is the **primary** driver; the post-`move_and_slide()` `global_position.x = clampf(...)` is a **corrective** screen-bound (standard pattern for fixed-screen shooters with no physical walls). Do **not** replace `move_and_slide()` with manual `position += velocity * delta`. [project-context "Physics & movement"]
- **1-axis only (FR1).** Set `velocity = Vector2(axis * speed, 0.0)` — y explicitly `0` so no vertical drift. Do not introduce vertical input, auto-scroll, or side-scroll. [GDD §Movement & Combat Chassis; CLAUDE.md gotcha]
- **Collision layers are strict bitmask constants (AR5).** Player `collision_layer = Constants.LAYER_PLAYER` (`= 1`, bit 0). Read the bit from `Constants`, never a magic number. `collision_mask = 0` this story (no collidables yet). There are **no 2D layer names** in `project.godot` — use the integer bitmask. [systems/constants.gd; arch §Entity Composition D4]
- **Signal boundary (D8): global flow → `EventBus`; intra-entity → direct signals.** Player **movement stays purely local** — it emits **nothing** to `EventBus` (no `ship_lost`/`game_over` until 1.5; no position broadcast). `HealthComponent`'s `health_changed`/`died` are **direct (local)** signals — do not route them through `EventBus`. [arch §Signal Architecture D8; project-context "Communication boundary"]
- **No cross-domain node paths.** Player does **not** reach into the Arena via `get_parent()`/`%Arena`/`../../X`. Bounds come from `Constants.BASE_RESOLUTION` + the player's own `tuning` resource. Domains communicate via `EventBus` or injection, never node paths. [project-context "Communication boundary"; arch §Architectural Boundaries]
- **Cache `@onready`; never `$`/`get_node()` per frame (AR14).** Resolve child refs once in `@onready`. Inside `_physics_process`, use the cached vars only. [project-context "Node lifecycle & access"]
- **Tuning via `.tres`, immutable via `Constants` (AR10).** `move_speed`/`edge_margin`/`lane_y` are balancing/feel → `player_tuning.tres` (the playtest lever, zero code to retune). `BASE_RESOLUTION` is immutable → `Constants`. Do not hardcode `320` or `1280` in `player.gd`. [arch §Cross-cutting Configuration; project-context "Config tiers"]
- **`@export` for the tuning ref, not `load()`.** `@export var tuning: PlayerTuning`, assigned in the inspector. Avoids `load("res://...")` in gameplay code (ContentRegistry rule applies to content; tuning via `@export` is cleaner and test-swappable). [project-context "Content via ContentRegistry"; arch §Naming/exports]
- **Static typing + naming (NFR7).** `var axis: float`, `func _physics_process(_delta: float) -> void`, typed where possible. Nodes `PascalCase` (`Player`, `HealthComponent`), files `snake_case` (`player.gd`, `health_component.gd`), constants `UPPER_SNAKE`, private members leading `_`. One root + one script per scene. [project-context "Typing & exports", "Naming conventions"]
- **No `print()` (AR14).** Any diagnostics via `Log.debug("Player", msg)` / `Log.warn(...)`. [project-context "No print() / no try-catch"; systems/log.gd]
- **Do NOT port the (removed) JS prototype.** Re-derive movement in Godot idioms (`CharacterBody2D` + `move_and_slide()`, scene tree, `Input.get_axis`). No plain-object entities, no manual draw loops. [project-context "Do NOT port the prototype"]

### File Structure Requirements

`★` = files this story creates; `✎` = the one existing file it modifies. Other domain dirs already exist from 1.1 with `.gdkeep` (remove the `.gdkeep` when a dir gets real content).

```
res://
├── components/                      ★ health_component.gd, faction_component.gd  (was .gdkeep)
├── player/                          ★ player.gd, player.tscn, player_tuning.gd   (was .gdkeep)
├── resources/                       ★ player_tuning.tres                         (was .gdkeep)
├── world/
│   └── arena.tscn                   ✎ MODIFY: add Player instance as child of Arena
├── tests/
│   ├── components/                  ★ test_health_component.gd                  (was .gdkeep)
│   └── player/                      ★ test_player_movement.gd                   (was .gdkeep)
└── (systems/, addons/gut/, .gutconfig.json — UNCHANGED from 1.1)
```

**No changes to `systems/`** — `Constants.BASE_RESOLUTION` and `Constants.LAYER_PLAYER` already exist from 1.1; movement/lane values live in `player_tuning.tres`, not `Constants`.

### Project Context Rules (extracted from `project-context.md`)

- **Engine:** Godot 4.6.x (4.6.3-stable current; pin 4.6.x — avoid 4.7-only APIs). 2D, GDScript, Compatibility renderer. The `3d/physics_engine="Jolt Physics"` line is inert for this 2D project.
- **Hot-path discipline (NFR3):** zero per-frame allocations in `_physics_process` — no new `Array`/`Dict`/`Vector2` in the loop. The `Vector2(axis * speed, 0.0)` assignment is fine (it's a stack value, not a heap allocation to hoist), but do not allocate collections per frame. `@onready`/`@export` refs are cached; `_min_x`/`_max_x` computed once in `_ready()`.
- **Input (NFR6 / F5):** ALL input via Input Map **actions** read through `Input.*` — `Input.get_axis("move_left", "move_right")`. Never hardcode keys/scancodes. Each action already has both a kb and a gamepad binding (set in 1.1). This is "the single most impactful convention for a fixed-screen action game."
- **Physics & movement:** gameplay movement in `_physics_process` (fixed 60 Hz); `CharacterBody2D` → set `velocity`, call `move_and_slide()` (no args, internal delta). `_process` delta varies; `_physics_process` is fixed.
- **Display/window scaling (F4):** `stretch/mode="canvas_items"` + `stretch/aspect="expand"` at base 1280×720 — **already set**. Implication for clamping: with `expand`, wider-than-16:9 windows show extra horizontal canvas. Decision #2 picks the clamp target.
- **Testing (NFR13):** separate **pure logic** (`HealthComponent` math) from Node/scene code so it's GUT-testable without scenes. Unit tests = pure logic (no scene instantiation); integration tests = `.instantiate()` the scene, assert behavior/signals. Assert on state/signals, never visuals.
- **Optional MCP tooling (AR15):** GoPeak + Context7 are optional AI aids; not required.

### Library / Framework Requirements

- **None new.** Godot 4.6 built-ins only: `CharacterBody2D`, `CollisionShape2D`/`CircleShape2D`, `Input` (`get_axis`), `Resource` (for `PlayerTuning`), `Polygon2D`/`ColorRect` (placeholder). **GUT 9.6.0** already installed (1.1) for tests. No external assets — placeholder visual is a primitive shape.

### Testing Requirements

- **Framework:** GUT 9.6.0, headless, `godot --headless -s addons/gut/gut_cmdln.gd`. Config at project-root `.gutconfig.json` (`dirs=["res://tests"]`, `include_subdirs`, `should_exit`) — new tests under `tests/player/` and `tests/components/` are auto-discovered.
- **Unit (pure logic):** `tests/components/test_health_component.gd` — `HealthComponent` damage/heal/reset + signal correctness, no scene.
- **Integration (scene):** `tests/player/test_player_movement.gd` — instantiate `player.tscn`, simulate input via `Input.action_press`/`action_release`, step physics, assert clamp/horizontal-lock/structure. Use `auto_free`/`teardown` so instantiated nodes are freed between tests.
- **Boundary discipline:** movement tests assert on `global_position`/`velocity`/node structure — never on pixels-on-screen.
- **Match the 1.1 GUT style:** `extends GutTest`, `test_*()` functions, `assert_eq`/`assert_true`/`assert_not_null`, system strings for `Log` calls. See `tests/systems/test_scaffold.gd` for the established pattern.

### Previous Story Intelligence (from Story 1.1 — `done`)

- **What 1.1 delivered (reuse, don't reinvent):** 11 autoloads in canonical order; `Constants` (`BASE_RESOLUTION=Vector2i(1280,720)`, `LAYER_*=1/2/4/8/16`, `BASE_HP=3`); `EventBus` (signals: `run_started`, `wave_cleared(wave)`, `ship_lost(remaining)`, `build_changed`, `score_changed(score)`, `game_over` — **none needed by 1.2 movement**); `Pool` (`acquire(scene)->Node` / `release(node)` — **player is NOT pooled**; pool is for 1.3 projectiles); `Log` (`info/warn/err/debug(system, msg)`); `GameManager` (stub FSM `enum Mode{MENU,RUN,GAME_OVER}`, `get_mode()` — no player hooks yet); Input Map with `move_left`/`move_right` (kb `A`/`D` + arrows via `physical_keycode`; gamepad left-stick axis 0 ±1 + DPad `JoyButton` 13/14; per-action `deadzone=0.5`); `world/arena.tscn` (bare `Node2D` root `Arena`); GUT scaffold `tests/systems/test_scaffold.gd`.
- **Patterns to mirror:** static typing everywhere; `@onready` caching; no `print()` (use `Log`); typed arrays; PascalCase nodes / snake_case files; `.tres` for tuning, `Constants` for immutables; one root + one script per scene; `.gdkeep` to keep empty dirs.
- **1.1 review corrections to honor:** Godot 4 joypad indices were corrected in 1.1 (`LB=9`, `Start=6`, `DPad-L/R=13/14`) — already baked into the Input Map, so 1.2 just reads the actions. `Pool.release()` was rewritten to a `_node_paths` tracking dict (acquire stores path at acquire-time; release looks it up) with double-release + queued-for-deletion guards — **1.2 does not touch `Pool`**, but if you read it, that's the current shape.
- **Observed (not blocking 1.2):** `Pool.release()` appears to compute `var parent: Node = node.get_instance_id()` (looks like it should be `node.get_parent()`). This is in 1.1's DONE scope and is **not exercised by the player** (the player isn't pooled). Do **not** fix it in 1.2 — flag it to Mrdth; it becomes relevant when 1.3 projectiles actually stress the pool.
- **Scope discipline from 1.1:** "data is created when first needed, not upfront" — that's why 1.2 builds only `HealthComponent`/`FactionComponent` (AC4-required) and `player_tuning.tres` (AC1-required), and defers everything else.

### Git Intelligence

- Working tree is **clean** on `main`; HEAD = `e6bb571 Code review fixes for Story 1.1 scaffolding`. Recent commits are the 1.1 implementation + review fixes; before that, planning artifacts (epics, architecture, UX, readiness report, sprint-status). The only game code in the repo is 1.1's scaffold — this story adds the first gameplay entity on top of it.
- Branch before committing if you start work on `main` (per repo convention).

### Latest Tech Information

- **Godot 4.6.3-stable** is current (established in 1.1); 4.7 is RC-only — stay 4.6.x. `CharacterBody2D.move_and_slide()` (no-arg, internally-delta'd) and `Input.get_axis(neg, pos)` are **stable Godot 4.x APIs** — no version risk, no migration concerns. (No web lookup needed; these APIs are unchanged since 4.0 and 1.1 already locked the version policy.)
- **`Input.get_axis("move_left","move_right")`** returns a `float` in `[−1, 1]`, applying each action's configured deadzone to joypad axes automatically — one call satisfies AC3 for both keyboard (digital ±1/0) and gamepad (continuous).

### Decisions (confirmed by Mrdth)

> Settled scope/design calls. Implement exactly as stated.

1. **`HealthComponent` = real component, deferred wiring.** AC4 requires the component *present*; build it real + unit-tested (not an empty stub) — it's the honest fulfillment and gives 1.5 a stable, tested building block (architecture D1 pins "HP → `HealthComponent`, reset each wave by wave controller"). **Deferred to owning stories:** damage sources (1.4/1.6), wave-reset + ship-loss→`game_over` (1.5), on-ship HP bar (1.7).
2. **Clamp target = base-resolution play field (not dynamic viewport).** With `stretch/aspect=expand`, wider windows show extra horizontal canvas; clamping to `Constants.BASE_RESOLUTION.x` (1280) keeps the dodge lane **fair and identical** across window aspects (P3 "The Test" wants a consistent lane), and extra `expand` width reads as background margin. Clamp to `_max_x = BASE_RESOLUTION.x − edge_margin`, **not** `get_viewport_rect().size`.
3. **Lower the gamepad deadzone to ~0.25 for `move_left`/`move_right`.** The InputMap default of 0.5 means 50% stick travel before response — too laggy for arcade feel. Set the per-action `deadzone` to ~0.25 in the Input Map (a `project.godot` data change, not code). The user-facing deadzone **slider** is still E8 (8.4); this is just a better starting value for the feel gate.
4. **Placeholder visual only.** Use a primitive shape (e.g. cyan upward `Polygon2D`, ~34×34) so movement is visible. The real rescuer-arrowhead art + D16 shape/outline renderer lands in 1.6/8.5.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md`#Story-1.2] — ACs (verbatim), user story, FR1/FR2/FR3 · AR5/AR6/AR14.
- [Source: `_bmad-output/planning-artifacts/epics.md`#Epic-1] — kinesthetics-gate framing, cross-story context (1.3 fire reuses the Player node/components; 1.5 wires HealthComponent).
- [Source: `_bmad-output/project-context.md`] — Physics & movement, Node lifecycle, Composition/strict-collision, Communication boundary, Config tiers, Hot-path discipline, Input (NFR6), Testing (NFR13), Naming, Godot 4.6 gotchas.
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md`#D4/D8/D1] — entity composition, signal boundary, state ownership (HP→HealthComponent).
- [Source: `_bmad-output/planning-artifacts/architecture/.../architecture.md`#Project-Structure] — directory tree (player/, components/, resources/), naming, "schema `.gd` with domain, `.tres` in resources/".
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-meridian-run-2026-06-29/gdd.md`#Movement-&-Combat-Chassis] — 1-axis chassis, ~320 px/s baseline ("central feel param"), balanced vs 620 px/s bullet / 0.7 s telegraph; pillars (P3 The Test); clean=small hitbox.
- [Source: `_bmad-output/planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/EXPERIENCE.md`#Input] — canonical `move_left`/`move_right`, kb+gamepad parity, held-input continuous; deadzone slider = E8.
- [Source: `_bmad-output/planning-artifacts/ux-designs/.../mockups/key-hud.html`] — ship ~34×34, bottom lane (~54 px band, ~14 px from bottom), pointing up, cyan→magenta with bright outline (target for later art).
- [Source: `_bmad-output/implementation-artifacts/1-1-project-scaffolding-and-core-systems.md`] — reused autoloads/APIs, GUT pattern, scope discipline ("data created when first needed").
- [Source: existing code] — `systems/constants.gd` (BASE_RESOLUTION, LAYER_*, BASE_HP), `systems/event_bus.gd`, `systems/log.gd`, `world/arena.tscn`, `project.godot` [input]/[autoload]/[display], `tests/systems/test_scaffold.gd`.

## Dev Agent Record

### Agent Model Used

GLM-5.2 (Claude Code, gds-dev-story workflow) — 2026-07-02.

### Debug Log References

- **Headless arena launch:** `godot --headless --path . --quit-after 60` → clean (only the expected 1.1 `ContentRegistry is a stub` `Log.warn` from `content_registry.gd:_ready`; no 1.2 errors/warnings). Required a one-time `godot --headless --import` first to register the new `class_name`s (`FactionComponent`, `HealthComponent`, `Player`, `PlayerTuning`) in `global_script_class_cache.cfg` — Godot does not rescan classes on a plain `--headless -s` run.
- **GUT suite:** `godot --headless -s addons/gut/gut_cmdln.gd` → **23/23 passing, 80 asserts, 0 failures** (5 scaffold + 10 health-component unit + 8 player-movement integration).
- **One correction during dev:** the first test draft used `add_child(auto_free(p))`; this GUT 9.6.0 build exposes `autofree()` / `add_child_autofree()` (no underscore). Fixed in both test files; `auto_free` does not exist here. (Story T7 subtask text suggested `auto_free`; the API call site note is now `add_child_autofree`.)
- **Float32 vs float64 (surfaced during the feel pass):** after `move_speed` was bumped `320 → 426.6`, `test_velocity_independent_of_delta` failed with `426.600006103516 != 426.6` — `velocity` is a `Vector2` (32-bit `real_t`), `tuning.move_speed` is a 64-bit `float`, and 426.6 isn't exactly representable in float32 (320.0 *is*, which is why it only surfaced now). Switched the `move_speed`-comparison asserts to `assert_almost_eq(..., 0.01)`; the delta-independence check (`v60 == v144`) stays exact since both read the same float32 velocity. **Lesson for future tests:** compare `velocity`/`global_position` (float32) against `float` tuning values with epsilon — never `==`.

### Completion Notes List

- **First gameplay entity shipped.** Built the player 1-axis chassis on top of the 1.1 scaffold with zero changes to `systems/`. Every pattern here (component composition, `CharacterBody2D` + `move_and_slide()`, `@export` `.tres` tuning, `@onready` caching, GUT pure-logic vs integration split) is the template 1.3–1.6 inherit.
- **AC1 (horizontal-only, screen-clamped, ~320 px/s):** `velocity = Vector2(axis * tuning.move_speed, 0)` drives motion; post-`move_and_slide()` `clampf(global_position.x, _min_x, _max_x)` is a corrective bound to the **base-resolution** play field (Decision #2 — fair lane across window aspects, not viewport). `move_speed=426.6` in `player_tuning.tres` (~3.0 s to cross the 1280 px playfield; tuned up from the 320 baseline — see Change Log). Clamp proven at both edges; y-lock proven (`global_position.y == lane_y`).
- **AC2 (framerate-independent physics):** velocity set directly (never × delta); `move_and_slide()` called with no args (internal delta). Enforced structurally: stepping `_physics_process` at 1/60 and 1/144 yields identical `velocity.x == 426.6`.
- **AC3 (gamepad continuous + deadzone; keyboard parity):** single `Input.get_axis("move_left","move_right")` covers both; analog is continuous with each action's deadzone auto-applied. Deadzone lowered 0.5 → **0.25** for both move actions (Decision #3, `project.godot` data change). User-facing slider stays E8.
- **AC4 (CharacterBody2D + components):** `Player` is `CharacterBody2D` on `collision_layer = LAYER_PLAYER`, `collision_mask = 0` (no collidables yet). `HealthComponent` + `FactionComponent` are real, minimal, unit-tested child nodes; refs `@onready`-cached.
- **`HealthComponent` built real, NOT wired (Decision #1 honored):** full `take_damage`/`heal`/`reset_to_full` + `health_changed`/`died` signals, double-`died` guard, single-emit lifecycle. **Deviation noted:** `reset_to_full()` also clears the `_is_dead` flag (spec listed only `current_hp` + emit) so a new life can die again — a pure internal-invariant fix (full HP ⇒ alive), not the deferred 1.5 "revive a dead ship mid-run" flow decision. Verified by `test_reset_to_full_allows_dying_again`.
- **`take_damage` follows the spec's literal algorithm** (clamp→subtract→floor→emit `health_changed`→conditionally emit `died`); it does **not** early-return when dead, so `health_changed` still fires on post-death damage while `died` stays single-emit.
- **`FactionComponent` built real, rendering-deferred:** declares faction + exposes `get_collision_layer()`; D16 family renderer is juice/art (1.6/8.5).
- **No cross-domain coupling:** movement emits nothing to `EventBus`; bounds come from `Constants` + own `tuning`. No `$`/`get_node()` per frame. No `print()`. No `load()` in gameplay code (tuning is `@export`/inspector-assigned). Static typing throughout.
- **Scope held:** no firing (1.3), no enemies/damage sources (1.4), no economy/ship-loss wiring (1.5), no juice (1.6), no HUD (1.7), no HurtboxComponent, no real art. `HealthComponent`/`FactionComponent` are the only components; both are AC4-required.
- **`.gdkeep` placeholders removed** from the 5 dirs that now hold real content (`components/`, `player/`, `resources/`, `tests/components/`, `tests/player/`); other empty domain dirs keep theirs.
- **T8 (manual feel check) — DEFERRED to Mrdth:** all *objective* feel sub-criteria are proven headless (continuous analog input, both-edge clamp, velocity==426.6, deadzone 0.25, kb+gamepad bindings). The *subjective* gamepad-in-editor pass requires a human + physical gamepad and feeds the 1.8 kinesthetics gate; it is explicitly "not an automated AC." Box left intentionally unchecked.

### File List

**Created (★):**
- `components/faction_component.gd` — `FactionComponent` (faction tag + collision-layer accessor)
- `components/health_component.gd` — `HealthComponent` (HP + signals, real but unwired)
- `player/player_tuning.gd` — `PlayerTuning` resource schema (`move_speed`/`edge_margin`/`lane_y`)
- `player/player.gd` — `Player` `CharacterBody2D` chassis script (1-axis move + clamp)
- `player/player.tscn` — Player scene (Visual + CollisionShape2D + Health + Faction)
- `resources/player_tuning.tres` — `PlayerTuning` instance (`426.6 / 24 / 680`; `move_speed` tuned up from the 320 baseline — see Change Log)
- `tests/components/test_health_component.gd` — pure-logic unit tests (10 tests)
- `tests/player/test_player_movement.gd` — integration tests (8 tests)

**Modified (✎):**
- `world/arena.tscn` — instance `player.tscn` as `Player` child of `Arena`
- `project.godot` — `move_left`/`move_right` per-action `deadzone` 0.5 → 0.25 (Decision #3)

**Deleted:**
- `components/.gdkeep`, `player/.gdkeep`, `resources/.gdkeep`, `tests/components/.gdkeep`, `tests/player/.gdkeep` (dirs now hold real content)

**Auto-generated by Godot (tracked alongside their scripts):**
- `*.gd.uid` for each new `.gd`; no `.import` artifacts (no image/audio in this story).

### Change Log

- 2026-07-02 — Story 1.2 implemented: first gameplay entity (player 1-axis chassis), two real-but-unwired components (`HealthComponent`, `FactionComponent`), first `.tres` tuning resource (`player_tuning.tres`), placeholder ship visual, Player instanced into `Arena`. 23/23 GUT tests green. Move-action deadzones lowered to 0.25. T8 subjective feel pass deferred to Mrdth.
- 2026-07-02 — **Tuning (feel pass, Mrdth):** `player_tuning.tres` `move_speed` **320 (GDD baseline) → 426.6** (~3.0 s to cross the 1280 px playfield; raw locomotion felt slow at 320). 320 was a "starting default, left open" per Dev Notes, so this is the intended first tuning pass — AC1's operative clause is "(from `player_tuning.tres`)", the value is data-driven. `edge_margin`/`lane_y` re-instated explicitly in the `.tres`. Expect a re-tune after 1.3/1.4 (player speed is balanced against the 620 px/s bullet / ~0.7 s telegraphs per GDD). GUT still 23/23 green.
