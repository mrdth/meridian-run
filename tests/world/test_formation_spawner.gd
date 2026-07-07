extends GutTest
# Tests for the escalating drip-model FormationSpawner ([Wave-2], correct-course 2026-07-03; refactored
# to DRIP-ONLY in Story 1.8 — wave timing moved to WaveController). Verifies per_tick scaling + hard
# cap, immediate-first-pulse + recurring drip, NO concurrency cap (total exceeds the retired 12 on a
# long wave), stop() halts dripping + despawns survivors, begin_wave restartability, and
# score_changed on enemy death. Wave-end (wave_cleared / timer expiry) is tested in test_wave_controller.gd.

const GruntScene := preload("res://enemies/grunt.tscn")
const ShielderScene := preload("res://enemies/shielder.tscn")
const BomberScene := preload("res://enemies/bomber.tscn")


func before_each() -> void:
	Pool.clear()


func _make() -> FormationSpawner:
	# Spawner under a Node2D arena (its _ready creates the enemy container under the arena).
	# Short, flat tuning so counts are predictable. (wave_duration_s is gone — the spawner drips
	# until stop(); WaveController owns duration.)
	var arena := Node2D.new()
	add_child(arena)
	var s := FormationSpawner.new()
	s.grunt_scene = GruntScene
	s.shielder_scene = ShielderScene
	s.bomber_scene = BomberScene
	s.drip_interval_s = 1.0
	s.per_tick_base = 2
	s.per_tick_growth = 0.0   # flat per_tick = 2
	s.max_per_tick = 4
	arena.add_child(s)  # _ready: creates _container, loads formation_def
	s.player = Node2D.new()  # dummy player for dive aim
	arena.add_child(s.player)
	s.run_state = RunState.new()  # injected by Arena/WaveController before begin_wave
	s.run_state.begin_run()
	return s


func test_per_tick_scales_with_wave_and_hard_caps() -> void:
	# per_tick(wave) = base + floor(wave × growth), hard-capped at max_per_tick (the perf guard).
	var s := FormationSpawner.new()
	s.per_tick_base = 3
	s.per_tick_growth = 0.5
	s.max_per_tick = 8
	assert_eq(s.per_tick(1), 3)     # 3 + floor(0.5) = 3
	assert_eq(s.per_tick(10), 8)    # 3 + 5 = 8 (at the cap)
	assert_eq(s.per_tick(100), 8)   # capped — no unbounded growth


func test_first_pulse_fires_immediately() -> void:
	# The first pulse fires at t=0 (no waiting a full drip_interval).
	var s: FormationSpawner = _make()
	s.begin_wave(1)
	s._physics_process(0.01)  # t≈0.01
	assert_eq(s.get_spawned_count(), 2)  # per_tick (flat) = 2


func test_pulses_recur_and_escalate_over_the_wave() -> void:
	# drip_interval=1s → multiple pulses; spawned count grows over time.
	var s: FormationSpawner = _make()
	s.begin_wave(1)
	s._physics_process(0.01)
	var after_first: int = s.get_spawned_count()
	assert_eq(after_first, 2)
	for _i in 90:  # ~1.5s → second pulse fired
		s._physics_process(1.0 / 60.0)
	assert_gt(s.get_spawned_count(), after_first)  # pressure escalated


func test_no_concurrency_cap_enemies_accumulate_past_twelve() -> void:
	# [Wave-2] core: NO on-screen cap. On a long wave with no kills, total spawned EXCEEDS the
	# retired cap-12 (enemies cycle via the dive-loop and don't leave unless killed). per_tick=2
	# every 1s over ~7s → 8 pulses × 2 = 16 > 12. The spawner drips until stop() (no self-terminate).
	var s: FormationSpawner = _make()
	s.drip_interval_s = 1.0
	s.begin_wave(1)
	for _i in 450:  # 7.5s
		s._physics_process(1.0 / 60.0)
	assert_gt(s.get_spawned_count(), 12)  # exceeds the retired cap → no concurrency cap


func test_stop_halts_dripping_and_despawns_survivors() -> void:
	# Story 1.8: stop() (called by WaveController at wave-end) halts dripping AND despawns survivors
	# for a clean board. The spawner no longer self-terminates on a duration.
	var s: FormationSpawner = _make()
	s.begin_wave(1)
	s._physics_process(0.01)  # first pulse
	assert_gt(s.get_active_count(), 0)  # enemies in the container
	assert_true(s.is_physics_processing())  # dripping (begin_wave enabled it)
	s.stop()
	assert_eq(s.get_active_count(), 0)  # survivors despawned (clean board)
	# stop() disabled the physics drip — the engine won't tick _physics_process. (We can't verify
	# "no new spawns" by calling s._physics_process directly: direct invocation bypasses the
	# set_physics_process(false) gate. is_physics_processing() is the meaningful halt check.)
	assert_false(s.is_physics_processing())


func test_spawns_over_time_without_error() -> void:
	# Drive a full short wave; no crashes across many spawn pulses.
	var s: FormationSpawner = _make()
	s.begin_wave(1)
	for _i in 420:  # 7s
		s._physics_process(1.0 / 60.0)
	assert_gt(s.get_spawned_count(), 0)


func test_score_changed_fires_on_enemy_death() -> void:
	# enemy.died → spawner routes through RunState → EventBus.score_changed (D8 global
	# game-flow). Score lives on RunState, not a spawner field (AR2/FR49).
	var s: FormationSpawner = _make()
	s.begin_wave(1)
	for _i in 60:  # 1s — first pulse spawned, an enemy is on-screen
		s._physics_process(1.0 / 60.0)
	watch_signals(EventBus)
	var enemy: Enemy = s._container.get_child(0) as Enemy
	var expected: int = enemy.definition.score_value
	enemy.get_node("HealthComponent").take_damage(100000)  # kill → died → score_changed
	assert_signal_emitted(EventBus, "score_changed")
	assert_eq(s.run_state.score, expected)  # run-scope owner holds the cumulative score
	assert_eq(s.get_run_score(), expected)  # reads through to RunState
	# score_changed broadcasts RunState.score (not a private spawner accumulator).
	var params: Array = get_signal_parameters(EventBus, "score_changed")
	assert_eq(params[0], expected)
	await get_tree().physics_frame  # let the deferred death-release land before teardown


func test_begin_wave_is_restartable() -> void:
	# begin_wave(n) fully resets per-wave state so the next wave starts clean (WaveController calls
	# it each wave). _wave_time + _spawned + _slot_cursor reset; no stale carryover.
	var s: FormationSpawner = _make()
	s.drip_interval_s = 1.0
	s.begin_wave(1)
	s._physics_process(0.01)
	assert_gt(s.get_spawned_count(), 0)
	s.begin_wave(2)  # restart (the controller re-enters Active each wave)
	assert_eq(s._wave_time, 0.0)  # drip clock reset
	s._physics_process(0.01)  # first pulse of wave 2
	assert_eq(s.get_spawned_count(), int(s.per_tick(2)))  # fresh count from 0 (per_tick(2)=2)


func test_debug_spawn_pulse_spawns_one_pulse() -> void:
	# Story 1.8 debug seam (FR50 "spawn enemy" cheat): debug_spawn_pulse() spawns one formation
	# pulse at the current wave's per_tick budget, without needing the drip timer.
	var s: FormationSpawner = _make()
	var before: int = s.get_spawned_count()
	s.begin_wave(1)
	s.set_physics_process(false)  # halt the drip so we isolate the debug pulse
	s.debug_spawn_pulse()
	assert_eq(s.get_spawned_count() - before, int(s.per_tick(1)))  # exactly one pulse (per_tick=2)


func test_enemy_death_without_run_state_degrades_safely() -> void:
	# AR11 fail-safe: if Arena hasn't wired run_state, an enemy death must not crash — it
	# logs (once) and skips the score broadcast. The push_error is an EXPECTED error here.
	var s: FormationSpawner = _make()
	s.run_state = null  # simulate Arena not having injected it yet
	s.begin_wave(1)
	for _i in 60:  # 1s — first pulse spawned
		s._physics_process(1.0 / 60.0)
	watch_signals(EventBus)
	var enemy: Enemy = s._container.get_child(0) as Enemy
	enemy.get_node("HealthComponent").take_damage(100000)  # kill → died → null-guard
	assert_push_error("run_state is null")  # consume the expected degradation error
	assert_signal_emit_count(EventBus, "score_changed", 0)  # no broadcast without run_state
	await get_tree().physics_frame
