---
project_name: 'meridian-run'
user_name: 'Mrdth'
date: '2026-06-29'
sections_completed: ['technology_stack', 'architecture_rules', 'engine_specific_rules', 'performance_rules', 'code_organization', 'testing_rules', 'platform_build', 'critical_rules']
existing_patterns_found: 0
status: 'complete'
rule_count: 78
revision_note: '2026-06-29: + Architecture & Systems Rules (autoload registry, build-engine recompute, seeded sub-streams, fixed state ownership, no-resume meta-only saves, EventBus boundary, ContentRegistry, juice domain, composition-over-inheritance) folded in from the completed architecture doc.'
optimized_for_llm: true
---

# Project Context for AI Agents

_This file contains critical rules and patterns that AI agents must follow when implementing game code in this project. Focus on unobvious details that agents might otherwise miss._

---

## Technology Stack & Versions

- **Game Engine:** Godot 4.6 (`config_version=5`; GDScript)
- **Version Policy:** Pin to the **4.6.x** line — avoid 4.7-only APIs for now. A migration to **4.7** is planned once Linux packages are widely available (development happens on Linux). Write forward-compatible code; do not depend on 4.6 APIs that 4.7 removes.
- **Dimensionality:** **2D** game (Node2D / CanvasItem / `Vector2` world)
- **Renderer:** Compatibility (`renderer/rendering_method = "gl_compatibility"`) — chosen for pure 2D; 2D renders identically across all Godot renderers, so Compatibility gives the lightest footprint
- **Scripting Language:** GDScript (no C# project / `.csproj` present)
- **Physics:** Godot's built-in **2D** physics server — `CharacterBody2D` / `RigidBody2D` / `Area2D`. (Note: `3d/physics_engine = "Jolt Physics"` in `project.godot` is a 3D-only default and has **no effect** on this 2D project.)
- **Genre:** 2D **fixed-screen roguelite shooter** — *Galaga*-lineage 1-axis chassis (player locked to a bottom lane, vertical fire-columns). "Run" in the title = *roguelite run*, not an endless-runner. Do **not** introduce auto-scroll / side-scroll / one-button runner input.
- **Target Platforms:** Windows + Linux desktop (see Platform & Build Rules)

## Architecture & Systems Rules

_Source: `planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md`. Systems-level conventions agents must follow._

**Autoload registry (load order matters)**
- Register autoloads in this exact order in Project Settings → Autoload (leaf services first, so dependents can use them at `_ready`): **Constants → Log → EventBus → Settings → SeedManager → ContentRegistry → Pool → SaveManager → AudioManager → GameManager → Debug**.
- Autoloads are **thin global services only — no gameplay logic**; delegate logic to pure/testable classes.

**Build engine = recompute, never mutate**
- Effective stats = `StatBlock` (base) + a list of `Modifier`/`Behavior` `.tres`, **recomputed** at run start and each wave. Never apply/remove a modifier by mutating stats in place — it drifts. Power-ups declare a target ladder (main ship / rescued-ship track).

**Determinism = seeded sub-streams (not the global RNG)**
- All gameplay randomness flows through `SeedManager` **named sub-streams** (wave_composition / modifier_select / enemy_spawn…), each derived from run seed + salt. Never use global `randi()`/`randf()` for reproducible behavior. `RunGenerator` is pure: `(seed, wave, tier) → WaveDefinition`.

**State ownership is fixed**
- Ships / currency / score / build-tracks → `RunState`. Per-wave HP → `HealthComponent` (reset each wave by the wave controller). Docked-ship combat = `DockedShip` node (transient); its build track = `RunState.BuildState` (**permanent — never cleared when the fighter is consumed**).

**Saves are meta-only; runs are in-memory**
- Persist to `user://` only: unlocked ships, feat progress, settings, best stats. **Run state is never saved — quitting abandons the run (no resume).** Version the save schema for migration.

**Communication boundary**
- Global game-flow → `EventBus` (typed, past-tense signals). Local entity comms → direct signals. Testable dependencies → explicit injection. Don't route everything through the bus; don't cross domains with node paths (`../../X`).

**No `print()` / no try-catch**
- Route all logging through the `Log` autoload (`Log.info/warn/err/debug`, `[LEVEL][system] msg`). GDScript has **no try/catch** — use preconditions + `push_error`/`push_warning` + fail-safe defaults; `assert` for dev-only invariants; critical errors fail-safe to menu, never hard-crash.

**Content via ContentRegistry, not scattered loads**
- Ships/power-ups/enemies/formations/modifiers are `.tres` in `resources/`; their schema `.gd` scripts live with the owning domain (`build/`, `enemies/`, `run/`) — `resources/` holds **`.tres` instances only**. Access content through `ContentRegistry`, never `load("res://...")` in gameplay code. Adding content = add a `.tres`, zero code.

**Juice is arena-scoped, not an autoload**
- `juice/JuiceCoordinator` lives in the arena scene, listens to `EventBus` (`screen_shake_requested`, `hit_flash_requested`); particles via `Pool`. Auto-disabled in menus.

**Composition over inheritance; strict collision layers**
- Build entities from component nodes (`HealthComponent`, `HitboxComponent`/`HurtboxComponent`, `FactionComponent`, `StateMachine`) — no deep inheritance. Collision layers: `player / enemy / player_projectile / enemy_projectile / pickup`.

**Pooled entities re-init via `activate()`/`reset()`, never `_ready()`**
- Projectiles/particles (and hot-path enemies) come from `Pool.acquire()`/`Pool.release()`; never `instantiate()` + `queue_free()` per frame.

## Critical Implementation Rules

### Engine-Specific Rules (Godot 4.6 / 2D)

**Node lifecycle & access**
- Cache node references in `@onready var` (resolved just before `_ready`); NEVER call `$` / `get_node()` inside `_process` / `_physics_process` (string lookups per frame are costly).
- `_ready()` fires once, after the node and all its children enter the tree. For pooled nodes, do NOT put re-init logic in `_ready` (it won't re-fire) — use an explicit `activate()` / `reset()` method, or pair `_enter_tree()` / `_exit_tree()`.
- Prefer scene-unique nodes (`%Name`) over fragile relative paths (`../../X`).
- Build entities as SCENES (`.tscn`), not bare scripts. Instantiate via `preload(...).instantiate()`; don't use `.new()` on a script when a scene defines the setup.

**Physics & movement**
- Gameplay movement lives in `_physics_process(delta)` (fixed timestep, 60 Hz).
- `CharacterBody2D`: set `velocity` then call `move_and_slide()`. It applies delta internally — do NOT multiply velocity by delta yourself (common bug).
- Do not move a physics body by writing `.position` each frame — drive it via `velocity` (or `move_and_collide(vel * delta)`).
- `_process` delta varies; `_physics_process` delta is fixed. Use delta for any non-`move_and_slide` integration.

**Signals**
- Declare typed signals: `signal health_changed(new_value: int)`.
- Connect with the callable syntax: `node.sig.connect(_on_sig)`, not the legacy string form `connect("sig", self, "meth")`.
- Prefer signals over direct cross-node calls for decoupling; use an EventBus autoload for cross-scene/global events.
- Boundary: global game-flow → `EventBus` autoload; local / intra-entity → direct signals (see Architecture & Systems Rules).

**Typing & exports**
- Use static typing everywhere: `var hp: int`, `func hit() -> void`, typed arrays `Array[Node2D]`. It catches errors early and runs faster.
- `@export` for inspector-tunable values; constrain with `@export_range`, `@export_enum`, `@export_group`.
- `@tool` ONLY when an editor preview is needed — it executes in the editor; keep it side-effect-free.

**RNG**
- For reproducible/deterministic behaviour, use a `RandomNumberGenerator` instance with a fixed seed rather than the global `randi()` / `randf()`.

### Performance Rules

**Frame budget & profiling**
- **≥60 FPS is a floor (minimum), not a cap** — the game may render faster on high-refresh displays. Frame-budget ceiling is 16.67 ms for the worst-case frame; design so the heaviest target scene still holds 60.
- Gameplay runs on the fixed-timestep `_physics_process` (60 Hz); rendering via `_process` is uncapped. All motion MUST be delta-based so it behaves identically at 60 or 144+ FPS.
- Optimize measured hotspots, not guesses — use Godot's built-in Profiler / Monitor.

**Hot-path discipline (`_process` / `_physics_process`)**
- No per-frame allocations: avoid creating new Arrays/Dicts, new objects, string concatenation, or `Vector2(...)` inside tight loops every frame. Hoist and reuse.
- Cache everything: node refs (`@onready`), arrays, computed values.
- Avoid `find_child()` / `get_node()` / `find_children()` per frame.
- Disable processing for inactive/off-screen entities: `set_process(false)` / `set_physics_process(false)`, or `process_mode = PROCESS_MODE_DISABLED` for paused subtrees.

**Object pooling**
- Pool & reuse frequently spawned/destroyed entities (projectiles, particles, enemies). Don't `queue_free()` + `instantiate()` on a hot path — toggle visibility/processing or add/remove from the tree instead.

**Rendering (2D)**
- Use `TileMapLayer` for level tiles — not thousands of individual Sprite2D nodes.
- Minimize CanvasItem count and draw calls; batch where possible.
- For custom `_draw()`, call `queue_redraw()` only when state actually changes.
- Put UI/HUD on a `CanvasLayer`, separate from the world tree.

**Physics**
- Keep collision shapes simple (`CircleShape2D` / `RectangleShape2D`) on dynamic bodies; avoid concave shapes on moving bodies.
- Use collision layers/masks to cull unnecessary broadphase pairs.
- Keep `_on_body_entered` / area callbacks cheap — they can fire repeatedly.

### Code Organization Rules

**Structure — co-located by domain (Option A)**
- Each system keeps its scene(s) + script(s) + art together under its own folder. A domain's specific art lives with the domain; only shared/cross-domain assets go in `assets/`.
- `systems/` holds the **11 autoloads** in registry order (see Architecture & Systems Rules), registered under Project Settings → Autoload.
- `resources/` holds `.tres` data **instances only** (content, level definitions, tuning). Resource **schema scripts** (`.gd`) live with their owning domain — adding content = add a `.tres`, zero code.

```
res://
  systems/     autoloads (11, in registry order — see Architecture & Systems Rules)
  components/  reusable component nodes (health/hitbox/faction/state_machine)
  player/      player + fire_system + docked_ship + art
  enemies/     enemy scenes + captor/ (5-state FSM) + enemy_definition + art
  world/       arena + background + wave_controller + art
  run/         run_state + build_state + run_generator + wave_definition
  build/       stat_block + modifier + ship/power_up_definition + behaviors + build_recompute
  ui/          hud + power_up_select + shop + menus/
  juice/       juice_coordinator + screen_shake + hit_flash
  resources/   .tres data only (ships/power_ups/enemies/formations/modifier_waves/tuning)
  assets/      shared fonts/shaders/sfx/music
  tests/       GUT, mirrors domains
```

**Naming conventions**
- Scripts: `snake_case.gd` (`player_controller.gd`)
- Scenes: `snake_case.tscn` (`player.tscn`)
- Node names: `PascalCase` (`PlayerBody`); give root nodes meaningful names, not the type default (`Node2D`).
- Identifiers (functions, variables, signals): `snake_case` (`health_changed`)
- Constants: `UPPER_SNAKE_CASE`; enums `PascalCase` with `UPPER_SNAKE` members
- Private members/methods: leading underscore (`_compute_velocity()`)
- Asset files: `snake_case` (`player_run_01.png`)
- One root node + one script per entity scene; root script named to match its scene.

### Testing Rules

**Framework**
- Automated testing uses **GUT** (Godot Unit Test) — the committed framework. Install under `addons/gut/`. Run headless via `godot --headless -s addons/gut/gut_cmdln.gd` for CI / pre-commit checks.

**Testability principle**
- Separate PURE LOGIC (calculations, state, rules) from NODE/scene code where practical. Pure classes with no scene-tree dependency are cheap to unit-test; keep `Node2D` / `CharacterBody2D` scripts thin and delegate to logic helpers.
- Pure-logic classes specific to this project (`RunGenerator`, `BuildRecompute`, `StatBlock` math) live in their domain (`run/`, `build/`) with thin Node wrappers — unit-test these without instantiating scenes.

**Organization**
- Tests live under a top-level `tests/` folder mirroring the domain layout (`tests/player/`, `tests/world/`, …).
- Test scripts: `test_<thing>.gd` (`test_player_controller.gd`), one GUT test class per system under test.

**Boundaries**
- Unit tests: pure logic & data classes (no scene instantiation).
- Integration tests: instantiate scenes in code via `.instantiate()`; assert node behaviour, signals, physics outcomes.
- Assert on signals/state, not on visual/manual checks.

### Platform & Build Rules

**Target platforms**
- **Windows + Linux desktop.** Compatibility renderer (OpenGL3) supports both. Create an export preset for each in Project → Export (`export_presets.cfg`). Verify on both before release (development happens on Linux).

**Input handling**
- NEVER hardcode keys/scancodes in gameplay code. Define all input as ACTIONS in Project Settings → Input Map; read via `Input.is_action_pressed("move_right")`, `Input.is_action_just_pressed("jump")`, `Input.get_vector("left","right","up","down")`.
- This makes rebinding, controller support, and remap menus trivial — the single most impactful convention for a fixed-screen action game.

**Controller support**
- Each action has BOTH a keyboard/mouse binding AND a gamepad binding in the Input Map.
- Use `Input.get_vector(...)` for analog movement (joysticks) so input is continuous, not digital; apply a deadzone.
- Design gameplay around actions, not devices — controller vs keyboard "just works."

**User data & saves**
- All persistent data (saves, settings) MUST go through `user://` (`OS.get_user_data_dir()`), the correct per-user OS path. NEVER write to `res://` (read-only after export) or absolute filesystem paths.

**Platform-conditional code**
- Use feature tags / `OS.has_feature("windows")` / `"linux"` for platform-specific behaviour; keep these branches small and rare.

**Window & display scaling**
- Set stretch mode in Project Settings → Display/Window: `stretch/mode = "canvas_items"` + `stretch/aspect = "expand"` so the 2D view scales across resolutions without distortion. Design at a fixed base resolution; let the canvas scale.

### Critical Don't-Miss Rules

**Do NOT port the prototype**
- Meridian Run originated from a JS/Canvas prototype. JS patterns DO NOT transfer to Godot: no plain-object "entities" (use Nodes / `Resource`), no `splice`/index removal during iteration (mutate a copy or iterate backwards), no manual canvas draw loops (use the scene tree + Node2D). Re-derive every behaviour in Godot idioms.

**Godot 4.6 gotchas to avoid**
- Do NOT multiply `velocity` by `delta` with `move_and_slide()` — it applies delta internally.
- `move_and_slide()` takes NO arguments in Godot 4 (it uses the body's `velocity`) — don't pass anything to it.
- Do NOT call `get_node()` / `$` / `find_child()` every frame — cache in `@onready`.
- Do NOT put re-init logic for pooled nodes in `_ready()` (fires once) — use an explicit reset method.
- Do NOT instantiate + `queue_free()` on a hot path (projectiles/particles) — pool & reuse.
- Do NOT write saves/settings to `res://` or absolute paths — use `user://`.
- Do NOT hardcode input keys — use Input Map actions.
- Do NOT use the global `randi()` / `randf()` for anything needing determinism — use a seeded `RandomNumberGenerator`.

**Godot 4.6 specifics**
- Use `TileMapLayer` for tiles — the legacy multi-layer `TileMap` is deprecated (4.3+).
- Prefer typed code (`: int`, `-> void`, `Array[X]`); avoid untyped `Variant` except where engine APIs require it.
- No `print()` in shipped code — route through a logging helper.

---

## Usage Guidelines

**For AI Agents:**
- Read this file BEFORE implementing any game code in this project.
- Follow ALL rules exactly as documented; when in doubt, choose the more restrictive option.
- If a rule conflicts with a design intent, flag it to Mrdth rather than silently overriding.
- Update this file when new patterns or conventions emerge.

**For Humans (Mrdth):**
- Keep this file lean and focused on agent needs — remove rules that become obvious over time.
- Update when the technology stack changes (e.g., the planned Godot 4.7 migration).
- Review periodically for outdated rules.

Last Updated: 2026-06-29
