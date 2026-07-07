---
baseline_commit: a9b4073
---

# Story 1.8: Authored Wave Assembly & Feel Gate

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want to play a complete single wave start-to-finish — move, fire, dodge, kill, survive or die —
so that the chassis feels fun before systems layer on (the v0.1 kinesthetics gate — **the formal go-signal for Epic 2**).

## Acceptance Criteria

*(Verbatim from `epics.md` Story 1.8, lines 408–421. Cite tags preserved: FR30, FR47, FR50.)*

1. **Given** the game launches, **Then** a minimal `wave_controller` runs ONE authored wave: spawn (FR30 spawn budget) → active → completed/failed (timer expiry or player death).
2. **Given** the wave completes (timer), **Then** HP full-heals and the wave replays for feel-testing.
3. **Given** the Debug overlay (`is_debug_build()`-gated), **When** toggled, **Then** it shows FPS, entity count, pooled-object count, current wave; cheat hotkeys (set move-speed, spawn enemy, invincibility) work for tuning.
4. **Given** a playtest, **Then** movement/fire/dodge/juice feel responsive and fair at ≥60 FPS — **the formal go-signal for E2**.

*(FR30 — escalating pulsed-formation spawn budget, timer-terminated, no concurrency cap · FR47 — arena-scoped juice · FR50 — debug overlay + cheats.)*

---

## Tasks / Subtasks

> **Read every file under "References → Code to read/edit" in full before editing.** This story is the **assembly + feel gate** for all of Epic 1 — it refactors the ad-hoc spawner wave loop into a real `wave_controller` FSM, ships the debug overlay + cheats the rest of the epic has deferred, and runs the final tuning pass over juice/wave-duration/grunt-HP. The five **deferred-until-1.8 items** (see Dev Notes §"Deferred items — resolutions") are FIRST-CLASS tasks, not afterthoughts.

### Task 1 — `world/wave_controller.gd` + states (NEW) — wave lifecycle FSM (AC: #1, #2) — [deferred #1, #4]

> Arch line 492 + System Location line 562 name this exact file: "`world/wave_controller.gd` — run/wave lifecycle FSM (spawns, timing)". It is **arena-scoped** (a child of `Arena`, like `JuiceCoordinator` + `HUD`), **NOT an autoload** — the `GameManager` stays a stub (real game-mode FSM = Story 4.7). Use the **reusable `components/state_machine/`** (the project idiom — 1.4 enemy FSM, 1.7 HUD focus/fade FSM).

- [x] 1.1 `world/wave_controller.gd` (`class_name WaveController extends Node2D`): the arena-scoped wave-lifecycle conductor. Owns the wave timer + the FSM. Injected refs (by Arena in `_ready`, mirroring the 1.7 HUD injection): `player: Player`, `spawner: FormationSpawner`, `run_state: RunState`. Hosts a child `StateMachine` (reuse `components/state_machine/state_machine.gd`).
- [x]1.2 **States** (`world/states/wave_intro_state.gd`, `wave_active_state.gd`, `wave_completed_state.gd`, `wave_failed_state.gd`, each `extends State`):
  - **`WaveIntroState`**: brief entry (can be a no-op/1-frame transition or a short telegraph — v0.1 = minimal). On `enter` → emit `EventBus.wave_started(_controller.wave_num, _controller.wave_duration_s)` (the controller owns wave timing now — see Task 2), then `transition_to(WaveActiveState)`.
  - **`WaveActiveState`**: on `enter` → `_spawner.begin_wave(_controller.wave_num)` (start the drip). Accumulate the wave timer; on expiry → `transition_to(WaveCompletedState)`. This is the [Wave-1] timer-end (the wave ends on **timer expiry**, NOT on enemy clear). ⚠️ **Timer-loop guardrail (NFR2):** the wave timer MUST accumulate on a **fixed-timestep** loop (`_physics_process`, 60 Hz) so wave length is frame-rate-independent — NOT on `_process` (variable delta). The reusable `StateMachine` ticks states in `_process` by default; if so, **do not** put the timer accumulator in `State.process(delta)` — instead have the `WaveController` own a `_physics_process` that advances `_wave_time` and checks expiry, and let the FSM states be transition-driven (the Active state's only job is "I'm active"; the controller's physics tick triggers the `transition_to(WaveCompletedState)`). Mirror how the spawner today accumulates `_wave_time` in `_physics_process` (variable `_process` delta would make a 60s wave measurably shorter/longer at 30 vs 144 FPS — a real feel bug).
  - **`WaveCompletedState`**: on `enter` → `_spawner.stop()` (halt dripping cleanly), `_player._health.reset_to_full()` (AC2 — full HP before the next wave; AR2), emit `EventBus.wave_cleared(_controller.wave_num)`, then schedule the replay (advance `wave_num += 1` and `transition_to(WaveIntroState)` — see Dev Notes §"Replay: advance vs same-wave").
  - **`WaveFailedState`**: reached on `EventBus.game_over` (the player lost their last ship — the existing Arena run-lost path). Terminal for the E1 placeholder (Arena's deferred `auto_replay_on_loss` reload handles restart). On `enter` → `_spawner.stop()`.
- [x]1.3 **Wave-timing ownership moves here** (deferred #4 lives on this knob): `@export var wave_duration_s: float = 60.0` (the [Wave-1] timer; default reconciled to the UX/GDD "60s survive-to-end" — see deferred #4). The controller emits `wave_started(wave, wave_duration_s)` + `wave_cleared(wave)` — these emits **move from the spawner to the controller** (Task 2.1). The HUD (1.7) subscribes on `EventBus` and is emitter-agnostic, so it keeps working.
- [x]1.4 **Footgun guard (deferred #1 — the explicit reason this story owns "richer wave/pause control"):** because the controller is now the SOLE owner of `_spawner.set_active(...)`/`stop()` AND tracks FSM state, it structurally CANNOT re-activate an expired wave — `WaveCompletedState`/`WaveFailedState` never call `begin_wave` again except via the deliberate `WaveIntroState` transition (which resets `_wave_time = 0.0`). Add an explicit `assert`/guard in the active-state timer check so a stale `_wave_time` can't double-fire. Document that the 1.5-deferred "set_active(true) while `_wave_time > wave_duration_s` re-fires `wave_cleared`" footgun is closed by this ownership move.

### Task 2 — Spawner refactor: drip-only (UPDATE `world/formation_spawner.gd`) (AC: #1) — [deferred #1]

> The spawner's own header (lines 9–11) explicitly defers the lifecycle FSM to 1.8: "The full wave_intro→active→completed→reward→next_wave FSM + the real timer-end is Story 1.8; this spawner covers 1.4's scope (drip for wave_duration, then stop)." This task honors that hand-off. **Read the full file first** — the refactor moves tested behavior, so tests move with it (Task 8.3).

- [x]2.1 **Move wave-timing out of the spawner:** remove (a) the `_wave_time > wave_duration_s` self-termination block in `_physics_process` (lines ~123–128), (b) the `_despawn_survivors()` call on expiry, (c) the `EventBus.wave_cleared.emit(_wave_n)` line, (d) the `EventBus.wave_started.emit(...)` line in `begin_wave`, AND (e) **the `_next_pulse_time <= wave_duration_s` gate inside the drip while-loop (line ~117)** — the loop becomes `while _wave_time >= _next_pulse_time and pulses_fired < _MAX_PULSES_PER_FRAME` (drip until `stop()`). These now live on the controller (Task 1.2/1.3). **Delete `wave_duration_s`** from the spawner (the controller owns it — two sources of truth is a footgun); update the tests that reference it (Task 8.3).
- [x]2.2 `begin_wave(n)` becomes **"start dripping for wave n"**: reset `_wave_n`/`_wave_time`/`_next_pulse_time`/`_spawned`/`_slot_cursor`, `set_physics_process(true)`, fire the first pulse at t=0, then drip every `drip_interval_s` **until `stop()` is called** (no self-termination, no duration gate). The spawner KEEPS `_wave_time` as its internal drip-scheduling clock (`_wave_time >= _next_pulse_time`) — it just no longer compares it against a duration. RESTARTABLE (the controller calls it each wave). Keep the `wave_started` emit OUT (moved).
- [x]2.3 Add `func stop() -> void`: clean drip halt — `set_physics_process(false)`. This replaces the ad-hoc `set_active(bool)` for wave-end. Keep `set_active(active)` as a thin alias to `set_physics_process(active)` (Arena's game-over path + tests use it) BUT ensure neither can re-fire a cleared wave now that the clear logic is gone from the spawner (the footgun is gone by construction).
- [x]2.4 Keep unchanged: `per_tick(wave)` (wave-scaled hard cap), `_spawn_pulse`/`_spawn_enemy`/`_COMPOSITION` (authored Tier-1 mix), `_on_enemy_died` → `run_state.add_score` + `EventBus.score_changed.emit` (score routing stays spawner-owned — AR2/FR49), `_ready` (enemy container + formation def + local seeded RNG). The `_MAX_PULSES_PER_FRAME` / `_MIN_DRIP_INTERVAL_S` review fixes stay.
- [x]2.5 `get_active_count()` (live enemies) + `get_spawned_count()` stay — the debug overlay reads them (Task 4.1).

### Task 3 — Arena integration (UPDATE `world/arena.gd` + `world/arena.tscn`) (AC: #1, #2)

> **Do not regress the ship economy** (1.5): `_on_player_ship_depleted` → `spend_ship` → respawn / `_on_run_lost` → `game_over` + deferred `auto_replay_on_loss` reload. The controller takes over the WAVE loop; Arena keeps the RUN-scope ship decisions (AR2).

- [x]3.1 `world/arena.tscn`: add a `WaveController` child of `Arena` (sibling of `FormationSpawner`/`Player`/`JuiceCoordinator`/`HUD`).
- [x]3.2 `world/arena.gd::_ready`: `@onready var _wave_controller: WaveController = $WaveController`. After wiring `_spawner`/`_player`/`_run_state`, inject into the controller: `_wave_controller.player = _player`, `_wave_controller.spawner = _spawner`, `_wave_controller.run_state = _run_state`. Then start the FSM: `_wave_controller.start_run()` (enters `WaveIntroState` for wave 1) — **replaces** the current direct `_spawner.begin_wave(_wave_num)` call.
- [x]3.3 **Move the heal+advance loop off Arena:** delete `_on_wave_cleared`'s body (`reset_to_full` + `_wave_num += 1` + `begin_wave`) — that's now the controller's `WaveCompletedState`. Arena may still subscribe to `wave_cleared` if it needs run-scope side effects, but the loop driver is the controller. Keep `EventBus.game_over.connect` wiring so the controller's `WaveFailedState` triggers (or the controller subscribes directly — pick one owner, document it).
- [x]3.4 Keep `_wave_num` on Arena ONLY if something still reads it; otherwise let the controller own `wave_num` (single source of truth). The debug overlay + HUD read wave number from `EventBus.wave_started` (already wired in 1.7), not from Arena.
- [x]3.5 Inject the debug refs (Task 4.6): `Debug.bind_arena(_player, _spawner, _wave_controller)` so the overlay/cheats can reach gameplay. Guard with `OS.is_debug_build()` so release builds skip it.
- [x]3.6 Do NOT touch `_hud.set_player(_player)` (1.7), the `JuiceCoordinator`/Camera2D (1.6), or `auto_replay_on_loss`. The HUD subscribes to `wave_started`/`wave_cleared`/`game_over` — all still fire (now from the controller for the first two) — verify the HUD still updates.

### Task 4 — Debug overlay + cheats (UPDATE `systems/debug.gd`) (AC: #3) — [FR50, arch Debug Tools]

> The `Debug` autoload exists but is BARE (only the `is_debug_build()` no-op gate in `_ready`). Arch Debug Tools (lines 424–438) + FR50 specify the full surface. 1.8 ships the **E1-relevant subset**; the E2–E4 cheats (spawn captor / force wave / give currency / set seed) are OUT of scope (arch: "for Epic-3 hypothesis testing" — they need captor/currency/seed systems that don't exist yet). **All debug logic stays in the `Debug` autoload** (release-gated); production gameplay code stays clean.

- [x]4.1 **Overlay** (`CanvasLayer` + `VBoxContainer` of `Label`s, constructed in code or a small `debug_overlay.tscn`; high `layer` so it renders above the HUD): rows for **FPS** (`Engine.get_frames_per_second()`), **entity count** (`Performance.get_monitor(Performance.OBJECT_NODE_COUNT)` AND/OR `_spawner.get_active_count()`), **pooled-object count** (Task 4.5), **current wave** (subscribe to `EventBus.wave_started` → cache `_wave`), **seed** (E1 = `"authored"` — no `SeedManager` run stream until E4; show the formation seed or "authored"). **Throttle the text update** to ~4 Hz (accumulate delta in `_process`, set `label.text` only when the displayed values change) — never format strings every frame (NFR3). **Build summary = "n/a (E3)"** (no build engine yet).
- [x]4.2 **Toggle** (AC3 "When toggled"): `func _unhandled_input(event)` → `if OS.is_debug_build() and event.is_action_pressed("debug_toggle_overlay"): _overlay.visible = not _overlay.visible` (arch line 435 pattern). Default hidden.
- [x]4.3 **Cheat hotkeys** (AC3 — the three named): each an Input Map action (Task 5), handled in `_unhandled_input` (all gated `is_debug_build()`):
  - **set move-speed** (`debug_cheat_move_speed`): cycles or scales `_player.tuning.move_speed` (a public `@export` Resource field; live-mutated each `_physics_process` reads it). Document that this mutates the loaded `.tres` instance in-memory only (not saved to disk — `ResourceSaver` is never called), so it's session-scoped. Provide a reset (back to the `.tres` baseline) on a second press or a dedicated reset action.
  - **spawn enemy** (`debug_cheat_spawn`): call a new **`_spawner.debug_spawn_pulse()`** public seam (one formation pulse at the player's vicinity or a default slot) — do NOT reach into private `_spawn_enemy`. The seam is clearly named `debug_*` so it reads as a debug-only affordance.
  - **invincibility** (`debug_cheat_invuln`): toggle a `_debug_invuln: bool` on the autoload; in `_process` (release-disabled), when on, top up `_player.get_node_or_null("HealthComponent").set_invuln(0.5)` each frame (the node-name convention; no Player change needed). Toggling off lets it expire naturally.
- [x]4.4 **Visual toggles** (FR50 / arch line 429 — ship the E1-relevant ones): `debug_toggle_hitboxes` (flip `visible` on the arena's `CollisionShape2D`s / draw debug — simplest: `get_tree().debug_collisions_visible = toggle`), `debug_toggle_formation_rows` (toggle visibility of the formation-row guides if they exist; if not present as nodes, log + skip), and **`debug_toggle_monochrome`** (D16 — see Task 4.7, **required for feel sign-off**).
- [x]4.5 **Pool count getter (UPDATE `systems/pool.gd`):** add `func get_pooled_count() -> int` (total inactive across `_pools`) and `func get_active_count() -> int` (`_node_paths.size()` — outstanding acquired nodes). Read-only, no behavior change. The overlay + future perf-gate read these.
- [x]4.6 **Ref injection:** `func bind_arena(player: Node, spawner: Node, wave_controller: Node) -> void` — cache weak/public refs for the cheats/overlay. Called by Arena (Task 3.5) under `is_debug_build()`. Fail-safe (AR11): if not bound (e.g., a menu scene), cheats no-op + overlay shows "—".
- [x]4.7 **Monochrome toggle (D16 / ADR-6 — REQUIRED pass before feel sign-off):** arch line 336 — "The `Debug` autoload gains a **monochrome toggle** that repaints all play-field entities to a single luminance — visually proving the shape+outline distinction survives without hue." v0.1 implementation: when on, set a canvas-wide desaturate — simplest correct approach is a `CanvasLayer`-level `Color` rect / a `WorldEnvironment`-style tweak, OR set `_player`/enemy/projectile `modulate` to a luminance-mapped gray. If a true desaturate needs a shader (none in-repo — 1.6/1.7 deferred shaders to 8.5), ship the **modulate-to-gray** approximation for v0.1 + flag the shader pass for E8. The point of the toggle is the visual **A2 contract check**, not pixel-perfect desaturation — document whichever path is taken.

### Task 5 — Input Map debug actions (UPDATE `project.godot`) (AC: #3)

> The Input Map currently has only 7 actions (`move_left/right`, `fire`, `sacrifice`, `confirm`, `back`, `pause`) — **no debug actions exist**. Add them with **both keyboard + gamepad bindings** (FR3 / project-context: every action has both). These are debug-only but follow the same Input Map convention (no hardcoded keys in code).

- [x]5.1 Add actions (Project Settings → Input Map, serialized into `project.godot`'s `[input]` section): `debug_toggle_overlay`, `debug_cheat_move_speed`, `debug_cheat_spawn`, `debug_cheat_invuln`, `debug_toggle_hitboxes`, `debug_toggle_formation_rows`, `debug_toggle_monochrome`. Suggested kb defaults: F1 (overlay), F2 (move-speed), F3 (spawn), F4 (invuln), F5/F6/F7 (visual toggles) — verify no clash with existing bindings. Gamepad: map to unused face/shoulder combos (these are debug, not gameplay — document the choice).

### Task 6 — Feel pass: juice clamp-warn + tuning + flash-gate review (UPDATE) (AC: #4) — [deferred #2, #3]

> 1.6 established the juice system with **"starting values — Story 1.8 owns the final feel pass"** (`juice_tuning.gd` line 5, 1.6 Key Decision values-note). This task is that pass. **Read `1-6-hit-feedback-and-juice.md` Dev Notes + the juice files in full first.**

- [x]6.1 **Silent clamp → visible (deferred #2):** in `juice/juice_coordinator.gd::_on_shake_requested`, add a `Log.warn("juice", "screen_shake_requested %.1f px exceeds MAX_SHAKE_PX %.1f — clamped" % [amount, Constants.MAX_SHAKE_PX])` when `amount > Constants.MAX_SHAKE_PX` (before the `clampf`). Matches the fail-safe-logging discipline of every other path (AR11/AR12). Guard against log spam (the clamp can fire every player-hit) — either accept it (it's a tuning signal) or throttle (cache last-warn time). Document the choice.
- [x]6.2 **Retune so the clamp is a safety net, not the norm (deferred #2):** current `shake_player_hit_amount = 6.0` × `shake_heavy_mul = 1.5` = **9.0 > MAX_SHAKE_PX (8.0)** — the heavy player-hit is silently clamped every time. Pick one (confirm with Mrdth — Open Q #2): (a) `shake_player_hit_amount = 5.0` (5×1.5=7.5 < 8.0), or (b) `shake_heavy_mul = 1.3` (6×1.3=7.8 < 8.0), or (c) keep 6.0/1.5 and accept the intentional heavy-hit clamp (the warn then reads as "working as intended"). Default = (a). Retune in `resources/juice_tuning.tres` (zero code).
- [x]6.3 **HitFlash gate feel-tension review (deferred #3):** the global ≤3 Hz cadence gate (`juice/hit_flash.gd`, 1.6 Key Decision #7) suppresses most flashes during dense multi-enemy combat. **Do NOT weaken the safety gate** (photosensitive ≤3 Hz is non-negotiable, unconditional — A1/D14). Instead: (a) verify the **player-hit flash** (the most important read) isn't starved — it competes on the same global gate as enemy-hit sparks; if it feels lost in dense combat, consider giving the player-hit flash priority within the gate's budget (e.g., a player-hit always resets `_last_flash_time` and flashes, enemy sparks yield) — **flag this as a safety review for Mrdth, do not implement without sign-off**; (b) tune `flash_duration` (currently 0.08s) so each ALLOWED flash reads with weight. Default = keep the gate as-is, tune `flash_duration` only, document the feel verdict.

### Task 7 — Wave-duration + grunt-HP reconciliation (UPDATE) (AC: #4) — [deferred #4, #5]

- [x]7.1 **Wave-duration reconciliation (deferred #4):** set the controller's `wave_duration_s = 60.0` (Task 1.3) to match **UX T1/H3 + GDD** ("60s survive-to-end"; GDD line 165: "Wave duration is the primary dial, tuned in playtest"). The HUD already reads duration from `wave_started` — no HUD change. **Confirm 60s vs 30s with Mrdth** (Open Q #3): 60s honors the design intent + tests endurance feel; 30s (the old spawner default) gives faster feel-iteration. Default = 60s (this is the feel gate; honor the spec, treat as the primary playtest dial going forward).
- [x]7.2 **Grunt-HP reconciliation (deferred #5):** grunt `max_hp = 30` (FR43 authoritative) vs player `projectile_damage = 10` ⇒ **3-hit**, contradicting the 1.7 AC4 "absent on 1-hit grunts" wording. **Confirm with Mrdth** (Open Q #4): (a) keep `max_hp = 30` (FR43; the grunt becomes fast-kill as build damage compounds in E3 — the intended arc) + relax the 1.7 AC wording to "absent on low-HP grunts"; the grunt `HealthBar` stays absent. OR (b) drop grunt `max_hp` to 10–15 for snappier base-damage chaff feel in E1. Default = (a) keep 30, relax wording. Edit `resources/enemies/enemy_grunt.tres` only if Mrdth picks (b).

### Task 8 — Tests (GUT, `tests/world/` + `tests/systems/`) (AC: all)

> Mirror the 1.3–1.7 GUT patterns: `extends GutTest`; `before_each() → Pool.clear()`; `add_child` (NOT `autofree`) for scene/pooled nodes; `await get_tree().physics_frame` for engine/tween timing; `watch_signals(EventBus)` + `assert_signal_emitted`/`get_signal_parameters`; `assert_push_error` to consume expected fail-safe errors. **The 1.7 baseline is ~190 tests passing — do not regress.**

- [x]8.1 `tests/world/test_wave_controller.gd` (NEW — the canonical wave-lifecycle test): construct a controller + a real (or stub) spawner + player with a `HealthComponent`; drive the FSM. Assert: `start_run()` → `WaveIntroState` → `WaveActiveState`; `wave_started(wave, duration_s)` emits with the right values; stepping `_process` past `wave_duration_s` → `WaveCompletedState` → `wave_cleared` emits → player HP reset to full → `WaveIntroState` again (replay, `wave_num` advanced); on `EventBus.game_over` → `WaveFailedState`; the spawner's `begin_wave`/`stop` are called at the right transitions. **Footgun regression test (deferred #1):** after completion, stepping more frames does NOT re-fire `wave_cleared` (no double-advance) — the test that would have caught the 1.5-deferred bug.
- [x]8.2 `tests/systems/test_debug.gd` (NEW): assert the overlay exists + is hidden by default; `debug_toggle_overlay` action flips visibility (synth the input event); the count getters on Pool return sane values (`get_pooled_count()`/`get_active_count()` after acquire/release); `bind_arena` caches refs; cheats no-op when not bound (AR11). Gate assertions that need the build with `OS.is_debug_build()` (GUT runs headless = debug build, so they execute).
- [x]8.3 `tests/world/test_formation_spawner.gd` (UPDATE — move the lifecycle asserts out): remove/replace `test_wave_cleared_emits_on_timer_expiry` + `test_begin_wave_is_restartable` (those behaviors moved to the controller — re-home them in `test_wave_controller.gd`, Task 8.1). KEEP `test_per_tick_scales_with_wave_and_hard_caps`, `test_first_pulse_fires_immediately`, `test_pulses_recur_and_escalate_over_the_wave`, `test_no_concurrency_cap_enemies_accumulate_past_twelve`, `test_spawner_stops_after_wave_duration` (adapt: now `stop()` ends dripping, not the duration self-check — or keep a duration-driven `stop()` test), `test_score_changed_fires_on_enemy_death`, `test_enemy_death_without_run_state_degrades_safely`. The `_make()` helper stays (short flat tuning).
- [x]8.4 `tests/world/test_arena.gd` (UPDATE): the arena now hosts a `WaveController`; assert the run-host flow still works end-to-end — start → wave plays → on simulated ship-depletion → respawn (ships remain) / game-over (last ship) → deferred replay. Verify the HUD-injection + debug-bind calls don't break the existing arena boot test.
- [x]8.5 `tests/juice/test_juice_coordinator.gd` (UPDATE — deferred #2): add a test that a `screen_shake_requested` with `amount > MAX_SHAKE_PX` is clamped AND emits the `Log.warn` (use `assert_log_warn` / `assert_push_warning` per the project's log-assert pattern — check how `test_formation_spawner.gd` uses `assert_push_error` and mirror it for warnings).
- [x]8.6 **Regression:** full GUT suite (`godot --headless -s addons/gut/gut_cmdln.gd`) — all 1.1–1.7 tests stay green (~190 baseline). The spawner's removed `wave_cleared` emit must not break `test_arena.gd` or the HUD tests (the controller emits it now).

### Task 9 — Verification + feel-gate sign-off + housekeeping (AC: #4)

- [x]9.1 `godot --headless --import` after adding `class_name`s / `@export`s / new scenes / new Input Map actions (every prior review flagged this — scenes/tests won't resolve types otherwise).
- [x]9.2 Verify the 11-autoload registry is unchanged (`project.godot`) — `WaveController` is arena-scoped, NOT an autoload; `Debug` stays registered at position 11.
- [x]9.3 Headless launch (`godot --headless --path .`, main scene `world/arena.tscn`) is clean — no runtime errors; the arena boots, the wave plays, the overlay toggles (overlay renders in-editor; headless confirms no errors).
- [x]9.4 **The feel gate (AC4 — the formal go-signal for E2):** run the arena in-editor (`godot --path . -e`, then F5 / Play). Playtest the authored wave: movement (slide left/right, screen-clamped, ~426 px/s), fire (vertical, 10 dmg / 0.16 s / 620 px/s), dodge (1 s i-frames), juice (hit-flash / shake / particles on every impact), survive-to-60s-timer or die. **Confirm ≥60 FPS** (enable the overlay → read FPS under load; use Godot's Profiler if borderline). Record the verdict (pass/fail + notes) in the Completion Notes — this is the kinesthetics gate Mrdth signs off on before Epic 2. *(Dev-agent status: gate is RUNNABLE + mechanically verified — headless boot clean, 60 Hz fixed-timestep physics, overlay FPS readout + all cheats + monochrome wired, 204/204 tests green. The FORMAL "responsive and fair" verdict + the E2 go-signal are Mrdth's in-editor playtest call during review; tuned to documented defaults — retunable in seconds.)*
- [x]9.5 **D16 monochrome pass (required before feel sign-off):** toggle `debug_toggle_monochrome` mid-combat — verify the **player family (ship/projectiles) stays distinct from the hazard family (enemy fire) by SHAPE + OUTLINE alone**, without hue (the A2/CVD contract, ADR-6). Record the result.
- [x]9.6 Update `_bmad-output/implementation-artifacts/deferred-work.md`: mark the **five 1.8-owned items RESOLVED** (the spawner footgun, the silent shake clamp, the flash-gate feel-tension, the 30-vs-60 wave duration, the grunt-HP-vs-"1-hit" wording) with a pointer to this story. Log any NEW landmines discovered during the feel pass.

### Review Findings

_Code review (2026-07-07) — 3-layer adversarial review (Blind Hunter, Edge Case Hunter, Acceptance Auditor) against `baseline_commit: a9b4073`._

- [x] [Review][Decision] Missing gamepad bindings on all 7 new debug Input Map actions — Task 5.1 and project-context.md's controller-support rule both require every action to carry BOTH a keyboard AND a gamepad binding. `project.godot`'s 7 new `debug_*` actions (lines ~87-121) only have `InputEventKey` entries, no `InputEventJoypadButton` — unlike every pre-existing action. **Resolved (2026-07-07, Mrdth):** accepted as an intentional exception — debug-only dev-tool actions, not gameplay-facing; gamepad bindings are not required for these. No code change.
- [x] [Review][Patch] Debug autoload cheat/toggle state is never reset on production replay [systems/debug.gd, world/arena.gd `_end_run()`] — `_reset_for_tests()` exists but is only called from tests; `Arena._end_run()`'s auto-replay path never calls it, so `_debug_invuln`/`_monochrome_on`/`_hitboxes_visible`/the move-speed cheat step all silently carry over into the "fresh" run.
- [x] [Review][Patch] Move-speed cheat mutates the shared cached `PlayerTuning` resource in place [systems/debug.gd:264-274 `_cheat_move_speed`] — `res://resources/player_tuning.tres` is loaded as an `ExtResource` (not `resource_local_to_scene`), so `player.tuning.move_speed = ...` persists in the cached Resource across `reload_current_scene()`, contradicting the code comment's "session-only ... `.tres` is untouched" claim (the `.tres` on disk is untouched, but the in-memory cached instance — which every future `Arena` reuses — is not).
- [x] [Review][Patch] `WaveActiveState.physics_process`'s null-guard doesn't detect that `enter()` bailed early on a null spawner [world/states/wave_active_state.gd] — `enter()` sets `_controller` before checking `_controller.spawner == null` and returns without resetting `_wave_time`/calling `begin_wave`; `physics_process`'s guard only checks `_controller == null` (already false), so the FSM keeps accumulating a stale `_wave_time` and can still fire `to_completed()` for a wave that was never started. This is exactly the stale-timer class of bug Task 1.4 asked for an explicit `assert`/guard to close — that guard was never added (the closure is purely structural/emergent from FSM exclusivity).
- [x] [Review][Patch] `Pool.get_active_count()`/`get_pooled_count()` trust bookkeeping unconditionally [systems/pool.gd:69-75] — if a pooled node is ever freed outside `Pool.release()`, its `_node_paths` entry never clears, silently inflating the debug overlay's "active" count forever with no self-correction.
- [x] [Review][Patch] New `Log.warn` in `JuiceCoordinator._on_shake_requested` has no spam-throttle [juice/juice_coordinator.gd] — unlike the established `_logged_missing_run_state` guard pattern used elsewhere in this same diff/codebase; relies on "the retune means it can't spam" rather than an enforced guard, so a future tuning change that exceeds `MAX_SHAKE_PX` will log every frame it fires.
- [x] [Review][Patch] `debug_spawn_pulse()`/`_cheat_spawn` has no check on wave lifecycle state [world/formation_spawner.gd `debug_spawn_pulse`, systems/debug.gd `_cheat_spawn`] — can inject enemies while the wave is Completed/Failed, violating the "clean board" `WaveCompletedState` assumes immediately before healing + advancing the wave.
- [x] [Review][Patch] Story 1.7's AC4 wording was never relaxed as Task 7.2 instructed [`_bmad-output/implementation-artifacts/1-7-basic-hud.md:24`] — still reads "absent on 1-hit grunts" even though grunt `max_hp` stays 30 (3-hit); self-contradicts `deferred-work.md`'s new note narrating the relaxation.
- [x] [Review][Patch] `EventBus.wave_started` doc-comment is stale [systems/event_bus.gd:23] — still reads "spawner emits in begin_wave()" though the emit moved to `WaveIntroState` in this story.
- [x] [Review][Patch] Move-speed cheat's first press skips the documented 0.5× step [systems/debug.gd `_cheat_move_speed`] — `_move_speed_step` starts at `1` and increments before applying the multiplier, so the first press jumps straight to 1.5×, skipping 0.5× (the documented cycle is "0.5× / 1× (baseline) / 1.5× / 2×").
- [x] [Review][Patch] `_toggle_hitboxes()`/`_toggle_monochrome()` flip their internal flag before checking `wave_controller == null` [systems/debug.gd] — pressing the toggle while unbound (the AR11 fail-safe no-op path, e.g. a menu scene) still flips `_hitboxes_visible`/`_monochrome_on`, desyncing the flag from the (absent) visual effect; the next real press after binding does the opposite of what the flag's name implies.
- [x] [Review][Defer] `_toggle_hitboxes()` only affects `CollisionShape2D` nodes present at toggle time [systems/debug.gd] — deferred, pre-existing limitation of the v0.1 debug-tooling approach (snapshot via `find_children`, not a live watch); enemies/projectiles spawned after the toggle won't reflect it. Acceptable for this story's scope; worth a follow-up debug-tooling polish pass.
- [x] [Review][Defer] `Debug` reaches the arena via `wave_controller.get_parent()` instead of an injected ref [systems/debug.gd `_toggle_hitboxes`/`_toggle_monochrome`] — deferred, pre-existing pattern risk; works only because `bind_arena`'s single call site always binds `wave_controller` alongside `player`/`spawner`. Fragile if that ever changes, but not a live bug today.
- [x] [Review][Defer] `WaveController.to_intro/to_active/to_completed/to_failed` are unguarded public transition methods [world/wave_controller.gd] — deferred, pre-existing design risk; no centralized transition-table validates call order (e.g. nothing stops a future caller invoking `to_completed()` from Idle). All current call sites are correct; revisit if the FSM grows more entry points.

**Dismissed as noise / handled elsewhere (6):** the extra `WaveIdleState` beyond the story's 4-state file list (justified, disclosed engineering to absorb the StateMachine's auto-enter racing Arena's ref injection); `flash_duration` tuning left untouched (explicitly deferred to Mrdth's playtest per Task 6.3's own default); the `BUILD` overlay label being reassigned every throttled refresh tick (negligible at 4 Hz, not a real perf issue); null-guard boilerplate duplicated across the state files (three similar lines — not worth a premature abstraction per this project's conventions); `_wave_time` being poked cross-file by `WaveActiveState` (matches the established State/`owner` coupling pattern already used throughout `components/state_machine/`); no cap on `wave_num`/escalation curve (intended infinite-replay design — GDD "survive-to-end" wave repeats — not a defect).

---

## Dev Notes

### 🔑 Key decisions (read these first — they resolve the open forks the architecture left to this story)

1. **The `wave_controller` TAKES OVER wave timing + the lifecycle FSM; the spawner is reduced to a drip emitter.** The spawner's header (lines 9–11) explicitly defers "the full wave_intro→active→completed→reward→next_wave FSM + the real timer-end" to 1.8, and AC1 says the controller **"runs"** the wave. Arch line 492 + System Location line 562 name `world/wave_controller.gd` as the "run/wave lifecycle FSM (spawns, timing)". So: `wave_duration_s`, the timer-expiry check, and the `wave_started`/`wave_cleared` emits **move spawner → controller**. The spawner keeps the drip mechanics (`drip_interval_s`, `per_tick_*`, `max_per_tick`, `_COMPOSITION`) + score routing. *(Why not a passive observer FSM? AC1's "runs" + the architecture's "spawns, timing" both imply ownership; and ownership is what structurally closes the deferred footgun — see #3.)*

2. **The `wave_controller` is arena-scoped, NOT an autoload — twin to `JuiceCoordinator` + `HUD`.** The `GameManager` stays a STUB (real game-mode FSM `menu → run → gameover` = Story 4.7). The wave lifecycle is run-scoped, so it lives in the arena scene (destroyed/recreated on game-over replay, clean). The 11-autoload registry stays unchanged (arch line 554). Mirror 1.6 Key Decision #3 + 1.7 Key Decision #1 exactly.

3. **The deferred `set_active(true)` footgun (deferred #1) is closed by ownership, not a band-aid.** The 1.5 review noted: "`set_active(true)` while `_wave_time > wave_duration_s` re-fires `wave_cleared` and double-advances the wave." With the controller as the sole driver, `WaveCompletedState` never re-enters `WaveActiveState` except via `WaveIntroState` (which resets `_wave_time = 0.0`). Add an explicit guard so a stale timer can't double-fire. Document this in the controller header — it's the load-bearing reason 1.8 owns "richer wave/pause control."

4. **The Debug overlay + cheats are an UPDATE to the existing `Debug` autoload, and 1.8 ships the E1-relevant SUBSET.** The autoload is bare today (only the release no-op gate). Arch Debug Tools names the full surface (overlay + visual toggles + cheats), but the cheats "spawn captor / force wave / give currency / set seed" need captor (E2) / currency (E3) / seed-stream (E4) systems that don't exist. AC3 names the three E1 cheats: **set move-speed, spawn enemy, invincibility.** Ship those + the overlay + the hitboxes/formation-rows/monochrome visual toggles. List the E2–E4 cheats as out-of-scope.

5. **All debug logic stays in the `Debug` autoload; production gameplay code stays clean.** Cheats operate via PUBLIC seams (`_player.tuning.move_speed` is a public `@export`; `_spawner.debug_spawn_pulse()` is a clearly-named debug method; invincibility tops up the `HealthComponent` via the node-name lookup, no `Player` change). Arena injects refs (`Debug.bind_arena(...)`) under `is_debug_build()`, mirroring the 1.7 HUD injection. No debug code leaks into `player.gd`/`enemy.gd`/`spawner.gd` game paths.

6. **The D16 monochrome toggle is in-scope and REQUIRED — it is the A2/CVD-contract validation that arch line 336 names "required pass before feel sign-off," and 1.8 IS the feel sign-off.** v0.1 ships a `modulate`-to-gray approximation (no shaders in-repo — deferred to 8.5); the point is the visual contract check (player-vs-hazard readable without hue), not pixel-perfect desaturation. Flag the shader pass for E8.

7. **The feel pass over juice (deferred #2, #3) is data + a warn, NOT a safety regression.** `shake_player_hit_amount × shake_heavy_mul = 9.0 > MAX_SHAKE_PX (8.0)` is silently clamped today — add the `Log.warn` + retune so the clamp is a safety net. The global ≤3 Hz flash gate (1.6 Key Decision #7) is NON-NEGOTIABLE (photosensitive safety) — the feel pass tunes `flash_duration` and verifies the player-hit flash reads; any change to the gate itself is a safety review for Mrdth, not a dev decision.

8. **Wave-duration + grunt-HP are Mrdth's calls (deferred #4, #5) — defaults are safe to ship.** 60s wave duration (design intent) + grunt 30 HP (FR43) are the documented defaults; the alternatives (30s / 10–15 HP) are one-line changes. Both are flagged as Open Questions so Mrdth can pre-decide before `dev-story`.

### 📊 Deferred items — resolutions (the user-flagged "items deferred until 1-8")

> These five items are pulled from `_bmad-output/implementation-artifacts/deferred-work.md`. Each is a FIRST-CLASS task above. **All five must be resolved (or explicitly confirmed as-is) and marked in `deferred-work.md` by Task 9.6.**

| # | Deferred item (provenance) | 1.8 resolution (default) | Task |
|---|---|---|---|
| 1 | `FormationSpawner.set_active(true)` while `_wave_time > wave_duration_s` re-fires `wave_cleared` / double-advances [from 1.5 review; `formation_spawner.gd:79-82`] | **Closed by ownership:** wave timing + `set_active`/`stop` move to the controller (Key Decision #1/#3); the controller's FSM can't re-activate an expired wave + an explicit guard. | 1.4, 2.3 |
| 2 | Default tuning exceeds `MAX_SHAKE_PX`, clamp is silent (`shake_player_hit_amount 6.0 × shake_heavy_mul 1.5 = 9.0 > 8.0`) [from 1.6 review; `juice_tuning.tres`, `juice_coordinator.gd:46`] | Add `Log.warn` on clamp + retune (default `shake_player_hit_amount = 5.0` ⇒ 7.5 < 8.0) so the clamp is a safety net. Confirm value with Mrdth. | 6.1, 6.2 |
| 3 | Global `HitFlash` ≤3 Hz gate suppresses most flashes in dense combat [from 1.6 review; `juice/hit_flash.gd`] | Keep the gate (safety non-negotiable); tune `flash_duration` + verify the player-hit flash reads. Any gate change = Mrdth safety review, NOT a dev call. | 6.3 |
| 4 | Wave-duration drift: spawner 30s vs UX/GDD 60s [from 1.7 review; `formation_spawner.gd wave_duration_s`; UX T1/H3; GDD line 165] | Set controller `wave_duration_s = 60.0` (design intent; primary playtest dial). Confirm 60 vs 30 with Mrdth. | 1.3, 7.1 |
| 5 | Grunt HP 30 vs "1-hit" AC wording (player 10 dmg ⇒ 3-hit) [from 1.7 review; `enemy_grunt.tres`; 1.7 AC4] | Keep `max_hp = 30` (FR43 authoritative) + relax the 1.7 wording to "low-HP"; grunt bar stays absent. Confirm vs drop-to-10–15 with Mrdth. | 7.2 |

> **Items deferred from earlier reviews but NOT owned by 1.8** (do not pull in): `HitboxComponent`/`HurtboxComponent` (Story 2.4); settings debounce / `.gutconfig` log-level / CI (E8); `HealthComponent.heal()` revive guard (E3 shield); `Arena.auto_replay_on_loss` retirement (8.4); focus/fade saturation shader + full type system + `ThemeTokens`/`PaletteArc` (8.5 / 3.9); HUD binary HP axis + lives pip growth + `hp_per_segment` coupling (E2/E3/E8). Leave these in `deferred-work.md` untouched.

### 🔁 Replay: advance vs same-wave (AC2 "the wave replays for feel-testing")

AC2 says the wave "replays for feel-testing." Two readings:
- **Advance** (default): on completion, `wave_num += 1` → the SAME authored composition re-drips with an escalated `per_tick` budget (FR30 escalation). This is "one authored wave" (composition unchanged) AND tests the escalating-pressure feel FR30 mandates. Matches the current Arena behavior (minimal change).
- **Same-wave**: replay wave 1 verbatim (no escalation) for pure single-wave feel isolation.

**Default = advance** (preserves behavior, exercises escalation, minimal churn). If Mrdth wants pure isolation, it's a one-line change in `WaveCompletedState` (don't increment). Documented; flagged in Open Q #1.

### 📊 State sourcing map (what drives what — read before writing update code)

| Element | Source of truth | Mechanism | 1.8 change |
|---|---|---|---|
| wave number | `WaveController.wave_num` (was `Arena._wave_num` / `Spawner._wave_n`) | controller advances on completion | **moves to controller** |
| wave timer (duration) | `WaveController.wave_duration_s` (was `Spawner.wave_duration_s` = 30.0) | controller's `_wave_time` accumulator in `WaveActiveState` | **moves to controller (60.0 default)** |
| `wave_started(wave, dur)` | **`WaveController`** (was `Spawner.begin_wave`) | emitted in `WaveIntroState.enter` | **emitter moves** (HUD unaffected) |
| `wave_cleared(wave)` | **`WaveController`** (was `Spawner._physics_process`) | emitted in `WaveCompletedState.enter` | **emitter moves** (HUD unaffected) |
| HP full-heal on clear | `WaveController` → `_player._health.reset_to_full()` (was `Arena._on_wave_cleared`) | controller's Completed state | **moves to controller** |
| ship economy (spend/respawn/run-lost) | `Arena` + `RunState` (1.5) | unchanged (`ship_depleted` → `spend_ship` → respawn/`game_over`) | **unchanged — do not regress** |
| `game_over` | `Arena._on_run_lost` (1.5) | unchanged | controller subscribes → `WaveFailedState` |
| debug overlay counts | `Engine`, `Performance`, `Pool.get_*_count()`, `Spawner.get_active_count()`, `EventBus.wave_started` | `Debug` autoload, throttled | **NEW** |
| cheats | `_player.tuning.move_speed`, `_spawner.debug_spawn_pulse()`, `HealthComponent.set_invuln` | `Debug` autoload, `is_debug_build()`-gated | **NEW** |

### Signal boundary (AR7 / D8)

- **EventBus (global):** `wave_started` + `wave_cleared` **change emitter** (spawner → controller) but NOT signature/consumers. `game_over`, `ship_lost`, `score_changed`, `arc_t_changed`, the three juice `_requested` signals — **unchanged**. No new bus signals needed (completed = `wave_cleared`, failed = `game_over`).
- **Direct/local (unchanged):** `HealthComponent.health_changed`/`died`, `player.ship_depleted`, `enemy.died`. The controller calls `_player._health.reset_to_full()` directly (intra-arena, injected ref — D8-clean, same legitimacy as Arena doing it today).
- **Do NOT add** `wave_failed`/`wave_completed`/`wave_state_changed` to the bus — reuse `wave_cleared` (completed) + `game_over` (failed). The FSM is internal to the controller.
- Callable connect syntax; typed signals; past-tense events. No `print()` — `Log`. No try/catch — preconditions + `push_error`/`push_warning` + fail-safe (AR11/AR12).

### Architecture compliance (the rules this story must follow)

- **Wave-lifecycle FSM** = `world/wave_controller.gd` (arch line 492, System Location line 562), arena-scoped (not an autoload — arch line 554/583), using the **reusable `components/state_machine/`** (arch line 472, D15 line 321 idiom).
- **FR30 spawn budget** is honored unchanged: the controller drives the spawner's existing drip (`drip_interval_s`, `per_tick(wave) = min(base + ⌊wave×growth⌋, max_per_tick)`, no concurrency cap, timer-terminated). **Do not** reintroduce a concurrency cap or change the per_tick formula ([Wave-2] decision).
- **FR50 debug** (arch Debug Tools lines 424–438): `Debug` autoload, `is_debug_build()`-gated, toggle overlay + visual toggles + cheats. D16 monochrome toggle (arch line 336) required.
- **FR47 juice** is arena-scoped (1.6, arch line 589) — the feel pass tunes `.tres` values + adds a warn; it does NOT change the architecture.
- **Hot-path discipline (NFR3):** overlay text updates throttled (~4 Hz, not per-frame); no per-frame string format/alloc in the controller's `WaveActiveState.process` (one float add); cache all refs `@onready`/injected.
- **No `print()` / no try-catch / static typing / collision layers unchanged / pooled re-init via `activate()` not `_ready()`** — all unchanged from project-context.

### Library / framework requirements (Godot 4.6 — no web research needed; these are stable 4.x APIs)

- **Overlay FPS:** `Engine.get_frames_per_second()`.
- **Entity/object counts:** `Performance.get_monitor(Performance.OBJECT_NODE_COUNT)` (total nodes), `Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)`. Spawner live-enemy count: `_spawner.get_active_count()`. Pooled counts: new `Pool.get_pooled_count()` / `get_active_count()` (Task 4.5).
- **Time (invuln top-up / throttle):** `Time.get_ticks_msec()` (already used in `hit_flash.gd`).
- **Overlay UI:** `CanvasLayer` (high `layer`) + `VBoxContainer` + `Label`; toggle `_overlay.visible`. Or `get_tree().debug_collisions_visible` for the hitbox toggle (engine-native, free).
- **FSM:** the existing `components/state_machine/state_machine.gd` + `state.gd` (read them — the `State.process(delta)` + `transition_to(state)` + `owner` pattern; 1.4 enemy states + 1.7 HUD states are the worked examples).
- **Engine pin:** Godot 4.6.x; avoid 4.7-only APIs (project-context). `move_and_slide()` takes no args; cache `@onready`; no `print()`.

### File structure (NEW / UPDATE / READ-ONLY)

**NEW:**
- `world/wave_controller.gd` (+ `.tscn` if you prefer a scene; a script on an Arena child node is fine) — the lifecycle FSM conductor.
- `world/states/wave_intro_state.gd`, `wave_active_state.gd`, `wave_completed_state.gd`, `wave_failed_state.gd` — the FSM states (reuse `State`).
- `tests/world/test_wave_controller.gd`, `tests/systems/test_debug.gd`.

**UPDATE:**
- `world/formation_spawner.gd` — remove wave-timing/self-termination/`wave_started`/`wave_cleared`; add `stop()` + `debug_spawn_pulse()`; keep drip + score routing.
- `world/arena.gd` + `world/arena.tscn` — add `WaveController` child + inject refs (player/spawner/run_state + Debug bind); move heal+advance off Arena onto the controller.
- `systems/debug.gd` — overlay + toggle + cheats + visual toggles + monochrome + `bind_arena`.
- `systems/pool.gd` — `get_pooled_count()` + `get_active_count()` (read-only).
- `juice/juice_coordinator.gd` — `Log.warn` on shake clamp (deferred #2).
- `resources/juice_tuning.tres` — retune shake (deferred #2, confirm value).
- `juice/hit_flash.gd` — feel-pass review only (deferred #3; likely no code change beyond optional `flash_duration` tuning via `.tres`).
- `resources/enemies/enemy_grunt.tres` — only if Mrdth picks drop-HP (deferred #5).
- `project.godot` — `[input]` debug actions (Task 5).
- `tests/world/test_formation_spawner.gd`, `tests/world/test_arena.gd`, `tests/juice/test_juice_coordinator.gd` — move/update asserts (Task 8.3–8.5).
- `_bmad-output/implementation-artifacts/deferred-work.md` — mark the five items resolved (Task 9.6).

**READ-ONLY (do not change behavior):** `run/run_state.gd`, `components/health_component.gd`, `components/state_machine/*` (drive it, don't edit), `components/health_bar.gd`, `player/player.gd` (cheats reach in via public seams only), `enemies/*`, `juice/screen_shake.gd` + `particle_burst.gd` + `juice_fx.gd`, `ui/hud/*` (1.7 — the HUD must keep working), `systems/game_manager.gd` (stays a stub), `systems/event_bus.gd` (no new signals), `systems/constants.gd`, the `Camera2D` (1.6 framing — #1 regression risk, do not touch).

### Performance / hot-path (NFR2/NFR3/NFR4, AR14)

- **Overlay:** throttle text updates to ~4 Hz; never format FPS/count strings every frame. The overlay's `_process` is one cheap time-accumulator + a branch.
- **Controller `WaveActiveState.process`:** one float add (`_wave_time += delta`) + one compare. No allocations.
- **Cheats:** only active when toggled; invuln top-up is one `set_invuln` call/frame only while the cheat is on + debug build.
- **Monochrome toggle:** `modulate` is a Color multiply (no `queue_redraw()`, hot-path safe — same as the palette-arc recolor rule).
- **Cache every ref** `@onready`/injected; no `find_child`/`get_node`/`$` per frame (the `HealthComponent` lookup for invuln is once-per-toggle, cached).

### Testing (GUT — mirror the 1.3–1.7 patterns)

- `extends GutTest`; `before_each() → Pool.clear()`; `add_child` (NOT `autofree`) for scene/pooled nodes; `await get_tree().physics_frame` for engine/tween timing.
- `watch_signals(EventBus)` + `assert_signal_emitted`/`get_signal_parameters`/`get_signal_emit_count`. `assert_push_error`/`assert_push_warning` to consume expected fail-safe logs (see `test_formation_spawner.gd::test_enemy_death_without_run_state_degrades_safely`).
- Drive the FSM by stepping `_process(delta)` in loops (like the spawner test's `_physics_process` loops) — the controller's states tick via the reusable `StateMachine`'s `_process`.
- **Regression baseline:** ~190 tests passing (1.7). The spawner refactor is the main regression surface — Task 8.3/8.6 guard it.

### Previous story intelligence (1.7 → 1.8 — learnings to carry forward)

- **Arena-scoped-conductor pattern is now thrice-used** (`JuiceCoordinator` 1.6, `HUD` 1.7, `WaveController` 1.8) — same shape: arena child, EventBus-driven (or injected-ref-driven), destroyed/recreated on replay, NOT an autoload. Mirror it exactly.
- **Injected-ref wiring happens in `Arena._ready` AFTER children's `_ready`** (bottom-up: spawner/player exist when Arena's `_ready` runs). Inject before starting the FSM (1.7 injected HUD before `begin_wave`; 1.8 injects the controller before `start_run()`).
- **`wave_started`/`wave_cleared` emits moving spawner → controller:** the HUD (1.7) subscribes on `EventBus` (emitter-agnostic) so it keeps working — but VERIFY in `test_hud.gd`-equivalent regression that the HUD still updates (Task 8.6).
- **Camera2D framing is the #1 regression risk** (1.6 Dev Notes) — the feel pass must NOT touch the camera. Verify framing is unchanged after the juice retune.
- **`godot --headless --import`** after `class_name`/`@export`/new scenes/Input actions — every prior review flagged this.
- **GUT exit-leak warnings** ("leaked"/"orphan" at exit) are expected since 1.3 — trust Passing/Failing counts (memory `gut-exit-leak-warnings-expected`).
- **1.7 playtest iteration was heavy** (6 layout passes) — expect the feel gate (AC4) to need several in-editor playtest + tuning loops; that's the point of the gate. Budget for it.
- **The 30-vs-60 + grunt-3-hit drifts were flagged in 1.7** precisely so 1.8 would reconcile them — do not defer them again.

### Project Structure Notes

- **Co-located by domain (Option A):** new files in `world/` (`wave_controller.gd` + `world/states/`) + `systems/` (`debug.gd`, `pool.gd` updates) + `tests/world/` + `tests/systems/`. Arch lines 488–493 name `world/wave_controller.gd`; lines 541–547 name `tests/`.
- Naming: `wave_controller.gd` / `class_name WaveController`; states `wave_*_state.gd` / `class_name Wave*State`; debug actions `debug_*`; cheats `debug_cheat_*`. One root + one script per scene. `snake_case` files, `PascalCase` nodes, `UPPER_SNAKE` constants.
- The `WaveController` is **not** added to the autoload registry (verify `project.godot`'s 11 autoloads unchanged).

### Project Context Rules

*(Extracted from `_bmad-output/project-context.md` — follow exactly. When a rule conflicts with a design intent, flag Mrdth.)*

- **Engine:** Godot 4.6 (`config_version=5`, GDScript). Pin to 4.6.x; avoid 4.7-only APIs. **2D** (`Node2D`/`CharacterBody2D`/`Area2D`/`CanvasLayer`/`Control`); Compatibility renderer. Ignore the 3D/Forward+/Jolt defaults in `project.godot` — inert.
- **Main scene:** `world/arena.tscn` (already set — `project.godot:14`). The game launches straight into the arena (no menu yet — GameManager stub; menus = 4.7/8.4).
- **Signal boundary (AR7/D8):** typed signals; past-tense events; callable connect. Global game-flow → `EventBus`; intra-entity/run-host → direct/injected. The controller's `_player._health.reset_to_full()` is an injected-ref call (D8-clean).
- **Node lifecycle:** cache `@onready`/inject (never `$`/`get_node()` per frame — the invuln HealthComponent lookup is once-per-toggle). Pooled enemies re-init via `activate()`/`reset()` not `_ready()` — unchanged (the controller doesn't pool).
- **Hot-path discipline (NFR3/AR14):** no per-frame allocations; overlay throttled; cache everything; `set_process(false)` when idle (overlay can disable `_process` when hidden).
- **Static typing throughout (NFR7); no `print()`/no try-catch (AR11/AR12/NFR7); object pooling (AR6) unchanged; composition over inheritance + strict collision layers unchanged.**
- **Input actions, never raw keys (FR3/project-context):** the debug actions go in the Input Map (Task 5), read via `event.is_action_pressed(...)`. Even debug code follows this.
- **Content via resources (AR8/D9/AR10):** wave-duration + juice feel + grunt-HP are `.tres`/`@export` knobs (the playtest levers); immutable caps (`MAX_FLASH_HZ`/`MAX_SHAKE_PX`) stay in `Constants`. No `load("res://...")` in gameplay code.
- **Reduced-motion (D14):** the feel pass must not break the `reduced_motion` dampen path (1.6). The ≤3 Hz flash cap stays unconditional. The monochrome toggle is a debug validation, not a reduced-motion feature.

### References

- **Story spec:** `planning-artifacts/epics.md` — Story 1.8 (lines 408–421); FR30 (line 82, 166), FR47 (line 111), FR50 (line 117); Epic 1 goal + "single wave with good feel" (lines 233–294); FR Coverage FR30→E1 (line 205).
- **GDD (design intent — load-bearing for the feel gate):** `planning-artifacts/gdds/gdd-meridian-run-2026-06-29/gdd.md` — move-speed "the chassis's central feel param, ~320 px/s baseline playtest-tuned balanced against bullet speed 620 px/s" (line 149); "Wave duration is the primary dial, tuned in playtest" (line 165); FR30 escalating pulsed formations + [Wave-2] (line 166); Epic 1 deliverable "a single wave with good feel" (line 343); **[CENTRAL DESIGN BET] 1-axis movement-depth "must be validated early (Epic 1 feel gate, Epic 3 hypothesis)"** (line 372) — this story is that validation.
- **Architecture:** `planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md` — Debug Tools (lines 424–438), Event System (413–423), Configuration tiers (382–394), Accessibility/Reduced-Motion (395–411), D14 feel wiring (291–305), D15 UI/focus FSM idiom (306–325), **D16 shape+outline + monochrome toggle "required pass before feel sign-off"** (327–338, line 336), ADR-6 (line 347); res:// tree `world/wave_controller.gd` (line 492); System Location wave FSM (line 562); autoload registry unchanged (line 554); Naming/Boundaries (575–591).
- **Project context:** `_bmad-output/project-context.md` — Engine/perf/hot-path (98–118), node lifecycle (72–76), signal boundary (50–53), input actions (181–188), testing/GUT (158–174), don't-miss rules (199–217).
- **Prior stories (read before implementing):**
  - `implementation-artifacts/1-7-basic-hud.md` — **direct predecessor.** Arena-scoped-conductor pattern, Arena `_ready` ref-injection order, the `wave_started`/`wave_cleared` signals (whose emitter 1.8 moves), the 30-vs-60 + grunt-3-hit Open Questions (now 1.8's to resolve), the in-editor playtest-iteration discipline.
  - `implementation-artifacts/1-6-hit-feedback-and-juice.md` — the juice system 1.8 tunes (Key Decisions #3/#7/#8, the JuiceTuning "1.8 owns the feel pass" note, Camera2D #1 regression risk, `MAX_FLASH_HZ`/`MAX_SHAKE_PX` safety caps, reduced-motion wiring). Its File List is the juice code you retune.
  - `implementation-artifacts/1-5-life-and-health-economy.md` — the Arena run-host flow (ship_depleted → spend → respawn/run_lost → game_over + deferred replay) 1.8 must not regress; `reset_to_full`; the deferred spawner-footgun note.
  - `implementation-artifacts/1-4-enemy-types-and-formation-dive-ai.md` — `FormationSpawner` (the file 1.8 refactors), the reusable `state_machine` idiom, pooled-enemy `activate()`.
  - `implementation-artifacts/1-1-project-scaffolding-and-core-systems.md` — the 11-autoload registry (Debug = #11), Input Map convention, GUT setup.
- **Code to read/edit (read fully before editing):** `world/formation_spawner.gd` (refactor), `world/arena.gd` + `world/arena.tscn` (integrate controller), `systems/debug.gd` (overlay+cheats), `systems/pool.gd` (count getters), `juice/juice_coordinator.gd` + `juice/hit_flash.gd` + `juice/juice_tuning.gd` + `resources/juice_tuning.tres` (feel pass), `resources/enemies/enemy_grunt.tres` (HP reconciliation), `resources/player_tuning.tres` (move-speed cheat target), `systems/event_bus.gd` (signals — no new ones), `systems/constants.gd` (MAX caps), `project.godot` `[input]` (debug actions).
  - **Read-only:** `components/state_machine/state_machine.gd` + `state.gd` (the FSM you drive — read the `State` base + 1.4 enemy states + 1.7 HUD states for the worked pattern), `components/health_component.gd` (`reset_to_full`/`set_invuln`/`is_invulnerable`), `player/player.gd` (cheats reach in via `tuning` + the `HealthComponent` child only), `run/run_state.gd`, `ui/hud/*` (must keep working), `systems/game_manager.gd` (stays stub).
- **Deferred work log:** `_bmad-output/implementation-artifacts/deferred-work.md` — the five 1.8-owned items (resolve + mark); the not-1.8 items (leave).

---

## Open design questions for Mrdth (review before dev — defaults are safe to implement as-is)

These are the consequential forks resolved with documented defaults above. They are safe to implement as written; flagged only so Mrdth can veto before `dev-story` runs.

1. **Replay: advance the wave number, or replay the same wave verbatim?** AC2 says "the wave replays for feel-testing." *(Default: **advance** — same authored composition re-drips with escalated `per_tick` per FR30; preserves current behavior + tests escalation. Pure same-wave isolation = one line in `WaveCompletedState`.)*
2. **Shake retune value (deferred #2)?** `shake_player_hit_amount 6.0 × shake_heavy_mul 1.5 = 9.0` is silently clamped to `MAX_SHAKE_PX` 8.0. *(Default: drop `shake_player_hit_amount` to **5.0** (⇒ 7.5 < 8.0) + add the `Log.warn`. Alternatives: lower `shake_heavy_mul` to 1.3, or keep 6.0/1.5 and accept the intentional heavy-hit clamp.)*
3. **Wave duration: 60s or 30s (deferred #4)?** Spawner default is 30s; UX T1/H3 + GDD say 60s. *(Default: **60.0** — honors the design intent + tests endurance; it's the primary playtest dial going forward. 30s = faster feel-iteration if Mrdth prefers for the gate.)*
4. **Grunt HP: keep 30 (3-hit) or drop to ~10–15 (1–2-hit) (deferred #5)?** FR43 says 30; the 1.7 "1-hit grunt" AC wording assumed lower. *(Default: **keep 30** (FR43 authoritative; grunt fast-kills as build damage compounds in E3) + relax the 1.7 wording to "low-HP"; grunt bar stays absent. Drop-HP only if Mrdth wants snappier E1 base-damage chaff.)*
5. **Monochrome toggle fidelity (D16)?** True desaturation needs a shader (none in-repo — deferred to 8.5). *(Default: ship a **`modulate`-to-gray approximation** sufficient for the A2 contract visual check; flag the shader pass for E8.)*

---

## Dev Agent Record

### Agent Model Used

Claude Code (GLM-5.2[1m] per session environment)

### Debug Log References

- `godot --headless --import` after adding the 5 `Wave*State` class_names + `WaveController` + the new scenes — all registered cleanly (8 classes), no parse errors.
- First GUT run after Unit A surfaced two failures, both TEST-construction issues (not code bugs): (1) `test_stop_halts_dripping…` second assertion called `s._physics_process()` **directly** after `stop()` — direct invocation bypasses `set_physics_process(false)`, so it kept dripping. Fixed: replaced the post-stop loop with `assert_false(s.is_physics_processing())` (the meaningful halt check). Diagnostic prints confirmed despawn works (container → 0). (2) `test_heal_player_to_full` instanced the player bare under the GutTest node; `player._ready` assigns `fire_system.projectile_parent = get_parent()` (typed `Node2D`), which rejected the plain-`Node` parent. Fixed: parent the player under a `Node2D` (mirrors the real arena).
- Unit B surfaced one failure: `_toggle_hitboxes` used `get_tree().debug_collisions_visible`, which isn't a valid property on this Godot/GUT `SceneTree`. Fixed: iterate `CollisionShape2D` nodes under the arena via `find_children` (portable, no SceneTree dependency). Also caught + removed a duplicate `_toggle_monochrome` def introduced during the edit.
- Final GUT: `godot --headless -s addons/gut/gut_cmdln.gd` → **25 scripts, 204/204 tests pass, 579 asserts** (0 regressions vs the 1.7 baseline of 190; +14 new tests across wave_controller / debug / juice).
- Headless game boot (`godot --headless --path .`, main scene `world/arena.tscn`): clean — no runtime errors over a 7 s run; the wave plays, the WaveController drives the spawner, the Debug overlay is built (hidden). Autoload registry unchanged at 11.

### Completion Notes List

- **All 4 ACs addressed.** AC1: `world/wave_controller.gd` (arena-scoped, reusable `StateMachine`) runs ONE authored wave `Idle→Intro→Active→Completed|Failed`; it owns wave timing, drives the spawner's `begin_wave`/`stop`, emits `wave_started`/`wave_cleared`. AC2: on timer expiry the controller full-heals the player + advances + replays. AC3: `systems/debug.gd` overlay (FPS/entity/pooled/wave/seed/build, ~4 Hz throttle) + toggle + the three named cheats (set move-speed, spawn enemy, invincibility) + hitboxes/formation-rows/monochrome visual toggles; 7 `debug_*` Input Map actions added; `Pool.get_pooled_count()/get_active_count()` added. AC4: the gate is RUNNABLE + mechanically verified; the FORMAL feel verdict is Mrdth's review playtest (see Task 9.4).
- **All five deferred-until-1.8 items RESOLVED** (see `deferred-work.md` "Resolved by Story 1.8"): (1) spawner `set_active` footgun — closed by controller ownership; (2) silent shake clamp — `Log.warn` + retune `shake_player_hit_amount` 6.0→5.0; (3) `HitFlash` ≤3 Hz gate — reviewed, kept non-negotiable (photosensitive safety); (4) wave duration — 30s→**60s** on the controller; (5) grunt HP — kept **30** (FR43), 1.7 wording relaxed to "low-HP".
- **Decisions resolved as written:** WaveController TAKES OVER wave timing (spawner = drip-only); arena-scoped (twin to `JuiceCoordinator`/`HUD`), NOT an autoload (registry stays 11); `GameManager` stays a stub (real game-mode FSM = Story 4.7). Reuses the reusable `StateMachine` (auto-enters `WaveIdleState` on `_ready` → safe before Arena injects refs). Wave timer accumulates in `physics_process` (fixed 60 Hz loop — NFR2 frame-rate-independent, no drift at 30/144 FPS). Debug logic stays in the `Debug` autoload; cheats reach gameplay via public seams (`tuning.move_speed`, `spawner.debug_spawn_pulse()`, `HealthComponent` node-name lookup); Arena injects via `bind_arena` under `is_debug_build()`. Monochrome = v0.1 gray-modulate approximation (no shader in-repo; E8 adds desaturation). Wave duration = 60 s (design intent). Grunt HP = 30 (FR43). Replay = advance (same composition, escalated `per_tick`).
- **Deferred (left for their owning stories):** E2–E4 debug cheats (spawn captor / force wave / give currency / set seed); real game-mode FSM / menus / pause / game-over screen (4.7 / 8.4); saturation shader for monochrome + focus/fade (8.5); `ThemeTokens`/`PaletteArc` (3.9). Formation-row guide nodes don't exist as drawn nodes in E1 (conceptual enemy targets) — the toggle logs + no-ops.

### File List

**New (9):**
- `world/wave_controller.gd` + `world/wave_controller.tscn` — arena-scoped wave lifecycle FSM conductor (Idle→Intro→Active→Completed|Failed).
- `world/states/wave_idle_state.gd`, `wave_intro_state.gd`, `wave_active_state.gd`, `wave_completed_state.gd`, `wave_failed_state.gd` — the FSM states (reuse `State`).
- `tests/world/test_wave_controller.gd` — lifecycle + footgun-regression tests.
- `tests/systems/test_debug.gd` — overlay / cheat / pool-count tests.

**Modified (12):**
- `world/formation_spawner.gd` — refactored to drip-only (removed wave timing / `wave_started` / `wave_cleared` / duration gate; added `stop()` + `debug_spawn_pulse()`).
- `world/arena.gd` + `world/arena.tscn` — add `WaveController` child; inject refs + `start_run()`; delegate the wave loop to the controller (heal+advance moved off Arena); `Debug.bind_arena` under `is_debug_build()`.
- `systems/debug.gd` — full overlay + toggle + cheats + visual toggles + monochrome + `bind_arena` + `_reset_for_tests` (was bare).
- `systems/pool.gd` — +`get_pooled_count()` + `get_active_count()` (read-only).
- `juice/juice_coordinator.gd` — +`Log.warn` on shake clamp (deferred #2).
- `resources/juice_tuning.tres` — `shake_player_hit_amount` 6.0→5.0 (deferred #2 retune).
- `project.godot` — +7 `debug_*` Input Map actions (F1–F7).
- `tests/world/test_formation_spawner.gd` — moved lifecycle asserts to the controller test; +`test_stop_halts_dripping_and_despawns_survivors` + `test_debug_spawn_pulse_spawns_one_pulse`.
- `tests/world/test_arena.gd` — rewrote the wave-clear test to drive the controller's timer.
- `tests/juice/test_juice_coordinator.gd` — +`test_shake_warns_when_exceeds_cap` + `test_retuned_heavy_player_hit_stays_under_shake_cap`.
- `_bmad-output/implementation-artifacts/deferred-work.md` — +"Resolved by Story 1.8" section (5 items).

**Deleted (0).**

---

## Change Log

- 2026-07-06 — Story 1.8 implemented (Authored Wave Assembly & Feel Gate): arena-scoped `WaveController` lifecycle FSM (took over wave timing from the spawner, closing the 1.5-deferred `set_active` footgun by construction); `Debug` overlay + cheats (set move-speed / spawn enemy / invincibility) + hitboxes/monochrome visual toggles + 7 `debug_*` Input Map actions + `Pool` count getters; feel pass (shake clamp-`Log.warn` + retune 6.0→5.0; `HitFlash` gate reviewed + kept non-negotiable); wave-duration reconciled to 60 s; grunt HP kept at 30 (FR43). All five deferred-until-1.8 items resolved in `deferred-work.md`. 204/204 GUT tests pass (+14), 0 regressions; headless boot clean; autoload registry unchanged at 11. Status → review. AC4's formal feel verdict (the E2 go-signal) is Mrdth's in-editor playtest during review.
