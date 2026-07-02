---
baseline_commit: 151907cf93adcef5a084e071310c79845d040c20
---

# Story 1.1: Project Scaffolding & Core Systems

Status: done

> **Epic 1 — Combat Chassis & Feel** (v0.1 kinesthetics gate) · first story of the project.
> This story is **greenfield** — there is no game code yet (no `.gd`, no `.tscn`, no `addons/`).
> Everything you establish here becomes the pattern every later story inherits. Read
> `_bmad-output/project-context.md` before writing a line of code.

## Story

As the developer (Mrdth),
I want the project scaffolded with the domain folder structure, Input Map, core autoloads, and GUT,
so that every later story builds on a consistent, testable foundation.

## Acceptance Criteria

*(Verbatim from `epics.md` Story 1.1; refs: FR3, FR50 · AR1, AR14)*

1. **AC1 — Launches into Arena.** Given the project is opened in Godot 4.6, When run, Then the game launches into an **Arena scene** without errors.
2. **AC2 — Core autoloads registered, canonical positions, thin.** Given Project Settings → Autoload, Then **Constants, Log, EventBus, Settings, Pool, and Debug** are registered (in canonical positions), each thin (no gameplay logic).
3. **AC3 — Input Map, kb + gamepad, no hardcoded keys.** Given the Input Map, Then `move_left`, `move_right`, `fire`, `sacrifice`, `confirm`, `back`, `pause` each have **both** a keyboard and a gamepad binding; no hardcoded keys/scancodes in code.
4. **AC4 — Display scaling.** Given Display settings, Then stretch = `canvas_items`, aspect = `expand`, fixed base resolution.
5. **AC5 — GUT green.** Given GUT under `addons/gut/`, When `godot --headless -s addons/gut/gut_cmdln.gd` runs, Then the suite passes (placeholder tests OK).

> **Note on AC2 scope:** the literal AC enumerates 6 autoloads, but this story registers **all 11** as thin stubs to lock the full canonical load order from day 1 (Decision #1 below). The 6 named autoloads are present, in canonical positions — AC2 is satisfied (and exceeded).

## Scope — what this story IS and IS NOT

**This is a scaffolding story. It wires the foundation; it does not build gameplay.**

- **IS:** domain folder tree; **11 autoload scripts (thin stubs)**; Input Map actions (kb+gamepad); display/stretch + base resolution; GUT installed + `tests/` mirror with a passing placeholder; a minimal Arena scene set as main scene.
- **IS NOT:** no content `.tres` (EnemyDefinition→1.4, PowerUpDefinition→3.2, ModifierWaveDefinition→5.1); no player/enemy/projectile scenes (1.2–1.4); no juice/HUD systems (1.6/1.7); no debug overlay UI (1.8); no Settings panel UI (8.4). "Data is created when first needed, not upfront."
- **Autoloads:** registers **all 11 as thin stubs** in canonical order — locking the load order from day 1 (see "Decisions (resolved)" + Architecture Compliance). Each stub is `extends Node`, no gameplay logic; real behavior lands with its owning story.

## Tasks / Subtasks

*(ACs in parens. Exact values are normative — see Dev Notes for the why.)*

- [x] **T1 — Domain folder tree** (AC1, structure)
  - [x] Create the full `res://` domain tree per architecture.md §Project Structure (see File Structure Requirements). Use `.gdkeep` to preserve empty domain folders in git.
  - [x] Create `world/arena.tscn`: root `Node2D` named **`Arena`** (meaningful name, not the type default). Empty placeholder — gameplay comes in 1.2+.
- [x] **T2 — Main scene** (AC1)
  - [x] Set `application/run/main_scene = "res://world/arena.tscn"` in `project.godot`.
  - [x] Verify launch in editor AND headless (`godot --headless --path .`) → no errors.
- [x] **T3 — 11 autoload scripts (thin stubs)** (AC2; registers all 11 to lock load order — Decision #1) — `systems/*.gd`, one root + one script each, `extends Node`, **static typing throughout**, **no `print()`** (route through `Log`). Each below is minimal for 1.1; real logic lands with its owning story.
  - [x] `systems/constants.gd` — immutable values: `BASE_RESOLUTION`, collision-layer enum/bits (`PLAYER, ENEMY, PLAYER_PROJECTILE, ENEMY_PROJECTILE, PICKUP`), base ships/HP if convenient. `const` only.
  - [x] `systems/log.gd` — `info/warn/err/debug(system: String, msg)` + `is_debug() -> bool`; wraps `push_warning`/`push_error`/`print_rich`; LEVEL filtering (dev=DEBUG, release=WARN+). **Only place `print` family calls may live.**
  - [x] `systems/event_bus.gd` — typed **past-tense** signals only. 1.1 minimal set: `run_started`, `wave_cleared(wave: int)`, `ship_lost(remaining: int)`, `build_changed`, `score_changed(score: int)`, `game_over`. (Add `arc_t_changed` etc. when their systems land.) No logic.
  - [x] `systems/settings.gd` — `ConfigFile` → `user://settings.cfg` load/save **skeleton** + `setting_changed(key: StringName, value)` signal. Do **not** add reduced_motion/ui_scale/deadzone/remap properties yet (those land in 1.6/E8 when consumed).
  - [x] `systems/seed_manager.gd` — **stub.** Will hold run seed → named RNG sub-streams (D3). Placeholder API only (e.g. `new_run(seed)`, `stream(name)`); no real logic (Story 4.1).
  - [x] `systems/content_registry.gd` — **stub.** Will load/index all `.tres` content (D9). Placeholder getters; loads nothing yet — no content exists (Story 3.2 / 1.4).
  - [x] `systems/pool.gd` — generic `ObjectPool` **API skeleton**: `acquire(scene: PackedScene) -> Node`, `release(node: Node)`, per-type pool map. Minimal working impl fine; exercised/tested in 1.3.
  - [x] `systems/save_manager.gd` — **stub.** Will persist META to `user://` (unlocks/feats/best stats — D5), distinct from `Settings` (prefs). Load/save skeleton only (Story 4.6).
  - [x] `systems/audio_manager.gd` — **stub.** Will own music + pooled SFX (D11). Optional `play_sfx()` placeholder; no audio assets yet (basic SFX in 1.6, full in 8.5).
  - [x] `systems/game_manager.gd` — **stub.** Will own the game-mode FSM (menu→run→gameover), pause, scene flow (D1). FSM skeleton only; main scene is still `arena.tscn` via `main_scene` (Story 4.7).
  - [x] `systems/debug.gd` — gated by `OS.is_debug_build()`. 1.1 = stub (overlay, toggles, cheats all come in 1.8/3.x). Must no-op in release exports.
- [x] **T4 — Register autoloads in canonical order** (AC2)
  - [x] Project Settings → Autoload, registered in THIS order (all 11): **Constants → Log → EventBus → Settings → SeedManager → ContentRegistry → Pool → SaveManager → AudioManager → GameManager → Debug** (Singleton, enabled, Global Variable on). Script/node name = the PascalCase autoload name.
  - [x] Verify order at startup (optional): each autoload's `_ready()` may `Log.debug(<name>, "ready")` so the dev log confirms the canonical sequence.
- [x] **T5 — Input Map actions** (AC3) — add to `[input]` in `project.godot` (or via editor). Each action gets **both** a keyboard and a gamepad event. Default binding table (all tunable/remappable; lives in Input Map, not code):
  | Action | Keyboard | Gamepad |
  |---|---|---|
  | `move_left` | `A`, `←` | L-stick ← (`JoypadMotion` axis 0, −1), DPad ← |
  | `move_right` | `D`, `→` | L-stick →, DPad → |
  | `fire` | `Space` | `JoyButton 0` (A / Cross) |
  | `sacrifice` | `Left Shift` | `JoyButton 4` (LB / L1) |
  | `confirm` | `Enter` | `JoyButton 0` (A) |
  | `back` | `Esc` | `JoyButton 1` (B / Circle) |
  | `pause` | `P` | `JoyButton 7` (Start / Options) |
  - [x] *(Note for continuity: `move_left`/`move_right` are 1-axis only — no vertical. Movement CODE is Story 1.2, which will read `Input.get_axis("move_left","move_right")` + deadzone. `debug_toggle_overlay` and cheat actions arrive with 1.8/3.x.)*
- [x] **T6 — Display / window / stretch** (AC4) — set in `project.godot`:
  - [x] `display/window/size/width = 1280`, `height = 720` (base resolution; Decision #2).
  - [x] `display/window/stretch/mode = "canvas_items"`, `display/window/stretch/aspect = "expand"`.
  - [x] Reference the same `BASE_RESOLUTION` from `Constants` in any code that needs it (single source of truth).
- [x] **T7 — Install GUT 9.6.0** (AC5)
  - [x] Download GUT **9.6.0** (the release pinned to Godot 4.6) from [github.com/bitwes/Gut](https://github.com/bitwes/Gut) releases; place `addons/gut/` into project root. Enable the plugin in Project Settings.
  - [x] Add `tests/.gutconfig.json` (dirs = `["res://tests"]`, log_level as desired) if the default invocation needs config.
- [x] **T8 — tests/ mirror + placeholder** (AC5)
  - [x] Create `tests/` mirroring domains (`tests/player/`, `tests/build/`, …) with `.gdkeep`; create `tests/test_scaffold.gd` (`extends GutTest`) with 1–2 trivial asserts that prove the autoloads loaded (e.g. `assert_not_null(Constants)`, `assert_not_null(EventBus)`).
  - [x] Run `godot --headless -s addons/gut/gut_cmdln.gd` → **exits green** (0 failures).

## Dev Notes

### Architecture Compliance (must follow — sources cited)

- **Autoload registry order is load-bearing.** Register all 11 in canonical order: `Constants → Log → EventBus → Settings → SeedManager → ContentRegistry → Pool → SaveManager → AudioManager → GameManager → Debug` [arch §Autoload Registry; project-context "Autoload registry"]. Leaf services first so dependents can use them at `_ready`. All 11 land as thin stubs now (Decision #1) — load order locked from day 1, no later reordering.
- **Autoloads are thin global services only — no gameplay logic** [arch D1; project-context]. Delegate real logic to pure/testable classes (e.g., `RunGenerator`, `BuildRecompute` — later stories). Stubs that do nothing beyond `_ready` are correct for this story.
- **Communication boundary** [D8]: global game-flow → `EventBus` (typed, past-tense); local → direct signals; testable deps → explicit injection. Don't cross domains via node paths (`../../X`); prefer scene-unique `%Name`.
- **No `print()` / no try-catch** [project-context]: all logging via `Log`; GDScript has no try/catch — use preconditions + `push_error`/`push_warning` + fail-safe defaults; `assert` for dev-only invariants.
- **`move_and_slide()` (Godot 4) takes NO args and applies delta internally** — do NOT multiply velocity by delta [AR14; project-context]. (Player code is 1.2, but establish the habit now; no per-frame `$`/`get_node()` — cache `@onready`.)
- **Static typing everywhere** [NFR7; project-context]: `var x: int`, `func f() -> void`, typed arrays `Array[Node]`. Constants `UPPER_SNAKE`; nodes `PascalCase`; files/scripts/scenes `snake_case`.
- **Pooled nodes re-init via `activate()`/`reset()`, never `_ready()`** [D7; project-context] — for when `Pool` gets real use in 1.3. `_ready()` fires once.
- **3D defaults in `project.godot` are inert** [project-context gotcha]: `config/features=…Forward Plus` and `3d/physics_engine="Jolt Physics"` are engine defaults that have **no effect** on this 2D / Compatibility project. Leave the Jolt line; the renderer is already `gl_compatibility`. Optionally clean `Forward Plus` out of `config/features` (cosmetic metadata only — not an AC).
- **Do NOT port the (removed) JS prototype** [project-context]: re-derive every behavior in Godot idioms (Nodes/Resources, scene tree, no `splice`-during-iteration). N/A to gameplay in this story, but governs every later one.

### File Structure Requirements

Create this tree (architecture.md §Directory Structure). `★` = files this story creates; others are `.gdkeep` placeholders so the structure exists in git.

```
res://
├── project.godot  (edit: main_scene, autoloads, input, display/window)
├── addons/gut/                      ★ GUT 9.6.0 (T7)
├── systems/                         ★ 11 autoloads, canonical order (T3)
│   ├── constants.gd  log.gd  event_bus.gd  settings.gd  seed_manager.gd
│   ├── content_registry.gd  pool.gd  save_manager.gd  audio_manager.gd
│   └── game_manager.gd  debug.gd
├── components/                      (.gdkeep — health/hitbox/faction/state_machine land later)
├── player/                          (.gdkeep)
├── enemies/                         (.gdkeep)
├── world/                           ★ arena.tscn (T1)
├── juice/                           (.gdkeep — JuiceCoordinator/PaletteArc land in 1.6/3.9)
├── run/                             (.gdkeep)
├── build/                           (.gdkeep)
├── ui/                              (.gdkeep — HUD lands in 1.7)
├── resources/                       (.gdkeep — .tres content lands with its system)
├── assets/                          (.gdkeep — shared fonts/shaders/sfx/music)
└── tests/                           ★ test_scaffold.gd + .gutconfig.json + domain mirrors (T8)
```

### Project Context Rules (extracted from `project-context.md`)

- **Engine:** Godot 4.6.x (4.6.3-stable current; pin 4.6.x — avoid 4.7-only APIs until 4.7 is stable + Linux packages ship). 2D, GDScript, Compatibility renderer.
- **Hot-path discipline (NFR3):** zero per-frame allocations in `_process`/`_physics_process` — no new Arrays/Dicts/`Vector2` in tight loops; cache `@onready` refs. Establish the caching habit from story one.
- **Input (NFR6 / F5):** ALL input via Input Map **actions** read through `Input.*` — never hardcode keys/scancodes. Each action has both a kb and a gamepad binding. This is "the single most impactful convention for a fixed-screen action game."
- **Display/window scaling (F4):** `stretch/mode="canvas_items"` + `stretch/aspect="expand"`; design at a fixed base resolution, let the canvas scale.
- **Data paths (NFR9):** all persistent data → `user://` (`OS.get_user_data_dir()`); never write to `res://` (read-only post-export) or absolute paths. `Settings` must use `user://settings.cfg`.
- **Config tiers (AR10):** immutable → `Constants` autoload; balancing → `.tres` tuning (later); player prefs → `Settings` autoload → `user://`.
- **Testing (NFR13):** separate **pure logic** from Node/scene code so it's GUT-testable without instantiating scenes. Tests under `tests/` mirroring domains, named `test_<thing>.gd`. This story's test is a placeholder; real pure-logic tests begin in E3/E4.
- **Optional MCP tooling (AR15):** GoPeak (Godot MCP) + Context7 (version-specific docs) are optional AI aids. Not required for this story; install later if desired.

### Library / Framework Requirements

- **GUT 9.6.0** — the Godot Unit Test framework, version pinned to **Godot 4.6** (do not pull an older 9.x that targets 4.5; do not pull a dev branch). Source: [github.com/bitwes/Gut](https://github.com/bitwes/Gut) · [Godot Asset Library](https://godotengine.org/asset-library/asset/1709) · [GUT docs](https://gut.readthedocs.io/). Install = drop `addons/gut/` into the project, enable plugin. Run = `godot --headless -s addons/gut/gut_cmdln.gd`.
- **No other dependencies.** No external starter template (AR1: build on the existing `project.godot` scaffold). No C# / `.csproj`. Engine-native audio/UI/persistence only.

### Testing Requirements

- **Framework:** GUT, headless, run via `godot --headless -s addons/gut/gut_cmdln.gd` (CI / pre-commit command).
- **This story's tests:** `tests/test_scaffold.gd` (`extends GutTest`) — smoke asserts that the autoloads exist and Constants exposes `BASE_RESOLUTION`. This proves the wiring; it is explicitly a placeholder.
- **Test layout:** `tests/` mirrors domains; one `test_<thing>.gd` GUT class per system under test. Empty domain test dirs get `.gdkeep`.
- **Boundary discipline (for later, set up now):** unit tests = pure logic/data classes (no scene instantiation); integration tests = `.instantiate()` scenes. Assert on signals/state, never on visuals.

### Latest Tech Information

- **Godot 4.6.3-stable (2026-05-20)** is current; **4.7 is RC only — not stable** → stay on 4.6.x. The `project.godot` 3D defaults (`Forward Plus`, `Jolt`, `d3d12`) are inert for this 2D/Compatibility project.
- **GUT 9.6.0** is the release that matches Godot 4.6 (GUT has had Godot-4 breaking changes across its 9.x line — pin the version, don't assume an older checkout works).

### Git Intelligence

- Recent commits are **all docs/planning** (GDD, architecture, epics, UX, readiness report, sprint-status). There is **no existing game code** — this story writes the first `.gd`/`.tscn`. No prior code patterns to mirror; you are *establishing* the patterns above for every future story to follow.

### Decisions (resolved — Mrdth, this session)

> Surfaced per the project rule "flag conflicts to Mrdth rather than silently override." Both confirmed.

1. **Autoload scope = all 11 as thin stubs now** (flipped from the readiness-report's 6-of-11 YAGNI default). Locking the full canonical load order from day 1 avoids any later autoload reordering (Godot load order is positional); each stub is `extends Node` with no gameplay logic, real behavior landing with its owning story. The literal AC2 (6 named autoloads) is satisfied and exceeded.
2. **Base resolution = 1280×720 (16:9).** Confirmed. Lives as a single `Constants.BASE_RESOLUTION` value + `project.godot` window size (trivially changed later).

### References

- [Source: `_bmad-output/planning-artifacts/epics.md`#Story-1.1] — ACs (verbatim), FR3/FR50.
- [Source: `_bmad-output/planning-artifacts/epics.md`#AR1] — scaffolding mandate (11 autoloads canonical order, GUT, Input Map, stretch).
- [Source: `_bmad-output/project-context.md`] — Technology Stack, Architecture & Systems Rules, Critical Implementation Rules, Code Organization, Testing, Platform & Build, Critical Don't-Miss.
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md`#Project-Structure] — directory tree, autoload registry, naming, boundaries.
- [Source: `_bmad-output/planning-artifacts/architecture/.../architecture.md`#D1/D8] — state mgmt (thin autoloads), signal boundary.
- [Source: `_bmad-output/planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/EXPERIENCE.md`#Input] — canonical action names `move_left/move_right/fire/sacrifice/confirm/back/pause` (1-axis).
- [Source: `_bmad-output/planning-artifacts/implementation-readiness-report-2026-07-01.md`#L401,L426,L484] — autoload-registry analysis (overridden to 11-stubs by Decision #1) + "data created when first needed."
- [Source: GUT 9.6.0 / Godot 4.6.3] — [bitwes/Gut](https://github.com/bitwes/Gut) · [GUT docs](https://gut.readthedocs.io/) · [Godot Asset Library](https://godotengine.org/asset-library/asset/1709).

## Dev Agent Record

### Agent Model Used
GLM-5.2 (via Claude Code harness)

### Debug Log References
- `godot --headless -s addons/gut/gut_cmdln.gd` → **5/5 tests pass, 43 asserts, 0 failures** (GUT 9.6.0 on Godot 4.6.3). Validates AC1 (main scene), AC2 (11 autoloads), AC3 (input), AC4 (display).
- `godot --headless --path . --quit-after 60` → **exit 0, no errors/warnings** (AC1: launches into Arena clean).
- `project.godot` `[autoload]` order verified canonical by file inspection: Constants→Log→EventBus→Settings→SeedManager→ContentRegistry→Pool→SaveManager→AudioManager→GameManager→Debug.

### Completion Notes List
- **All 5 ACs satisfied and verified.**
- **Autoloads (Decision #1 = 11 stubs):** all 11 registered in canonical order as thin `extends Node` stubs — Constants/Log/EventBus/Settings/Pool have minimal working scaffolds; SeedManager/ContentRegistry/SaveManager/AudioManager/GameManager are inert stubs tagged with the story that fills them; Debug no-ops in release. Load order locked from day 1 — no later reordering.
- **project.godot generated programmatically** via a throwaway `extends SceneTree` script (`configure_project.gd`, run once then deleted) that set autoloads/input/display through `ProjectSettings` and let Godot serialize its own `[input]` `Object(...)` format — avoiding error-prone hand-serialization. Canonical `[autoload]` order was preserved through the saved file (verified).
- **Input (AC3):** Godot 4 `JoyButton` indices corrected from the story's approximate table — **LB = 9** (not 4), **Start = 6** (not 7), **DPad-L/R = 13/14**. Keys bound via `physical_keycode` (layout-independent). Each of the 7 actions has ≥1 keyboard + ≥1 gamepad event.
- **Display (AC4, Decision #2):** `viewport_width/height = 1280/720`, `stretch/mode = canvas_items`, `stretch/aspect = expand`; mirrored as `Constants.BASE_RESOLUTION`.
- **GUT 9.6.0** installed at `addons/gut/` (pinned to Godot 4.6). `.gutconfig.json` placed at **project root** (GUT's default lookup path) with `should_exit: true` so the bare AC5 command works without `-gconfig`/`-gdir` args (minor deviation from the story's "tests/.gutconfig.json" suggestion — root placement makes the documented command work as-is).
- **Smoke test** `tests/test_scaffold.gd` asserts all 11 autoloads, base resolution, collision layers, every input action has kb+gamepad, display settings, and main scene — the red-green net that empirically caught/would-catch any project.godot format error.
- The 3D defaults (`Forward Plus`, `Jolt`, `d3d12`) in `project.godot` are left in place — inert for this 2D/Compatibility project (project-context gotcha).
- Optional per-`_ready` `Log.debug` order-check (T4) was **not** added (would hit a Constants-before-Log load-order snag); canonical order verified instead via the `[autoload]` section + the GUT "all autoloads loaded" test.

### File List
**Modified:**
- `project.godot` — main_scene, 11 autoloads, display (1280×720 + canvas_items/expand), 7 Input Map actions
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — story status transitions (ready-for-dev → in-progress → review)

**New (game source):**
- `systems/` — 11 autoloads: `constants.gd`, `log.gd`, `event_bus.gd`, `settings.gd`, `seed_manager.gd`, `content_registry.gd`, `pool.gd`, `save_manager.gd`, `audio_manager.gd`, `game_manager.gd`, `debug.gd` (+ Godot `.gd.uid`)
- `world/arena.tscn` — minimal Arena (Node2D), main scene
- `tests/test_scaffold.gd` — GUT smoke suite (5 tests / 43 asserts) (+ `.gd.uid`)
- `.gutconfig.json` — GUT config (root; `should_exit`, dirs=`res://tests`)
- `.gdkeep` markers — domain dirs: `components/`, `player/`, `enemies/`, `juice/`, `run/`, `build/`, `ui/`, `resources/`, `assets/`; test mirrors: `tests/{player,enemies,world,build,run,juice,ui,components}/`

**Third-party installed (wholesale):**
- `addons/gut/` — GUT 9.6.0 (248 files; github.com/bitwes/Gut tag v9.6.0)

**Removed (throwaway):**
- `configure_project.gd` — one-shot `ProjectSettings` configurator; deleted after `project.godot` was generated

### Review Findings

*(Code review 2026-07-02 — 3 layers: Blind Hunter · Edge Case Hunter · Acceptance Auditor)*

**Decision needed (resolve before patching):**
- [x] [Review][Decision] `fire` and `confirm` share joypad button_index 0 (South/A) — **RESOLVED: keep shared binding**. GameManager will gate active action contexts (menu vs. run) in Story 4.7; shared button is acceptable for an arcade-lineage game.

**Patches (unambiguous fixes):**
- [x] [Review][Patch] Typo `LAYER_EPLAYER_PROJECTILE` breaks entire test suite — **FALSE POSITIVE: committed code was correct; dismissed**
- [x] [Review][Patch] `_min_level` name is misleading — **DISMISSED by Mrdth: name is intentional and explicit**
- [x] [Review][Patch] Pool release uses `get_scene_file_path()` for key but acquire uses `resource_path` — **FIXED: pool rewritten with `_node_paths` tracking dict; acquire stores path at acquire time, release looks it up** [systems/pool.gd]
- [x] [Review][Patch] Pool double-release guard missing — **FIXED: `_node_paths.has(instance_id)` check prevents double-release** [systems/pool.gd]
- [x] [Review][Patch] Pool release of queued-for-deletion node — **FIXED: `is_queued_for_deletion()` guard added** [systems/pool.gd]
- [x] [Review][Patch] `Settings.set_value()` emits `setting_changed` before disk save — **FIXED: save now runs before emit** [systems/settings.gd:27]
- [x] [Review][Patch] Settings corrupted config file leaves `_config` in partial parse state — **FIXED: `_config.clear()` added on non-FILE_NOT_FOUND load error** [systems/settings.gd:19]
- [x] [Review][Patch] `SeedManager.stream()` returns a new unseeded RNG on every call — **FIXED: `_stub_rng` module-level instance returned on all calls** [systems/seed_manager.gd]
- [x] [Review][Patch] `Debug` missing `set_process_unhandled_input(false)` in release — **FIXED** [systems/debug.gd:10]
- [x] [Review][Patch] `log.gd` uses `print()` not `print_rich()` — **FIXED: changed to `print_rich()`** [systems/log.gd:31]
- [x] [Review][Patch] `pool.gd` uses untyped `Array` — **FIXED: `Array[Node]` throughout** [systems/pool.gd]
- [x] [Review][Patch] `constants.gd` const values lack explicit `: int` type annotations — **FIXED** [systems/constants.gd]
- [x] [Review][Patch] `game_manager.gd` `_mode` and `get_mode()` typed as `int` not `Mode` — **FIXED: `var _mode: Mode`, `get_mode() -> Mode`** [systems/game_manager.gd]
- [x] [Review][Patch] `tests/systems/` mirror directory missing — **FIXED: `tests/systems/` created with `.gdkeep`; `test_scaffold.gd` moved to `tests/systems/`** [tests/systems/]
- [x] [Review][Patch] `ContentRegistry` stubs call `Log.warn()` on every accessor call — **FIXED: one-time warn in `_ready()`, accessors return null silently** [systems/content_registry.gd]

**Deferred (pre-existing or belongs in future story):**
- [x] [Review][Defer] `arena.tscn` missing `uid=` line [world/arena.tscn:1] — deferred, Godot auto-assigns UID on first editor open; not a code issue
- [x] [Review][Defer] `Settings.set_value()` sync disk I/O on every call [systems/settings.gd:27] — deferred, no real callers until E8 Settings panel; debounce/batch fix belongs there
- [x] [Review][Defer] No `MAX_HP` constant [systems/constants.gd] — deferred, HP ceiling belongs in Story 1.5 life/health economy
- [x] [Review][Defer] `get_value()` `null` default may surprise typed callers [systems/settings.gd:22] — deferred, caller's responsibility; Variant return is intentional for a config API
- [x] [Review][Defer] `ship_lost(remaining: int)` parameter name is ambiguous (ships? HP?) [systems/event_bus.gd:7] — deferred, disambiguate when signal is consumed in Story 1.5
- [x] [Review][Defer] `.gutconfig.json` `log_level:1` (failures-only) may hide context in CI [.gutconfig.json:5] — deferred, revisit when CI pipeline is established

### Change Log
- 2026-07-01: Implemented Story 1.1 — project scaffolding. Domain folder tree, 11 thin autoload stubs (canonical order), 7 Input Map actions (kb+gamepad), display 1280×720 + canvas_items/expand, GUT 9.6.0, Arena main scene. All ACs verified: GUT 5/5 (43 asserts) + clean headless launch (exit 0, no errors). Story → review.
- 2026-07-02: Code review complete. 1 decision, 15 patches, 6 deferred, 5 dismissed. Story → in-progress.
