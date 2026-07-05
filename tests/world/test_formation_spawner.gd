extends GutTest
# Tests for the escalating drip-model FormationSpawner ([Wave-2], correct-course 2026-07-03).
# Verifies per_tick scaling + hard cap, immediate-first-pulse + recurring drip, NO concurrency
# cap (total exceeds the retired 12 on a long wave), spawner stops after wave_duration, and
# score_changed on enemy death.

const GruntScene := preload("res://enemies/grunt.tscn")
const ShielderScene := preload("res://enemies/shielder.tscn")
const BomberScene := preload("res://enemies/bomber.tscn")


func before_each() -> void:
	Pool.clear()


func _make() -> FormationSpawner:
	# Spawner under a Node2D arena (its _ready creates the enemy container under the arena).
	# Short, flat tuning so counts are predictable.
	var arena := Node2D.new()
	add_child_autofree(arena)
	var s := FormationSpawner.new()
	s.grunt_scene = GruntScene
	s.shielder_scene = ShielderScene
	s.bomber_scene = BomberScene
	s.wave_duration_s = 3.0
	s.drip_interval_s = 1.0
	s.per_tick_base = 2
	s.per_tick_growth = 0.0   # flat per_tick = 2
	s.max_per_tick = 4
	arena.add_child(s)  # _ready: creates _container, loads formation_def
	s.player = Node2D.new()  # dummy player for dive aim
	arena.add_child(s.player)
	s.run_state = RunState.new()  # injected by Arena before begin_wave (Task 5.1)
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
	# drip_interval=1s → multiple pulses across wave_duration; spawned count grows over time.
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
	# every 1s over ~7s → 8 pulses × 2 = 16 > 12.
	var s: FormationSpawner = _make()
	s.wave_duration_s = 8.0
	s.drip_interval_s = 1.0
	s.begin_wave(1)
	for _i in 450:  # 7.5s
		s._physics_process(1.0 / 60.0)
	assert_gt(s.get_spawned_count(), 12)  # exceeds the retired cap → no concurrency cap


func test_spawner_stops_after_wave_duration() -> void:
	# After wave_duration elapses, dripping stops (existing enemies keep cycling until killed;
	# the full wave-end FSM is Story 1.8).
	var s: FormationSpawner = _make()
	s.wave_duration_s = 1.0
	s.drip_interval_s = 0.5
	s.begin_wave(1)
	for _i in 200:  # 3.3s — well past the 1s wave
		s._physics_process(1.0 / 60.0)
	var stopped_count: int = s.get_spawned_count()
	for _i in 200:  # step a lot more — no further spawns
		s._physics_process(1.0 / 60.0)
	assert_eq(s.get_spawned_count(), stopped_count)


func test_spawns_over_time_without_error() -> void:
	# Drive a full short wave; no crashes across many spawn pulses.
	var s: FormationSpawner = _make()
	s.begin_wave(1)
	for _i in 420:  # 7s
		s._physics_process(1.0 / 60.0)
	assert_gt(s.get_spawned_count(), 0)


func test_score_changed_fires_on_enemy_death() -> void:
	# enemy.died → spawner routes through RunState → EventBus.score_changed (D8 global
	# game-flow). Score now lives on RunState, not a spawner field (AR2/FR49).
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


func test_wave_cleared_emits_on_timer_expiry() -> void:
	# Wave duration elapsed → board cleared → EventBus.wave_cleared(wave) (Task 5.2 / AC4).
	var s: FormationSpawner = _make()
	s.wave_duration_s = 1.0
	s.drip_interval_s = 0.5
	watch_signals(EventBus)
	s.begin_wave(1)
	for _i in 200:  # 3.3s — well past the 1s wave
		s._physics_process(1.0 / 60.0)
	assert_signal_emitted(EventBus, "wave_cleared")
	var params: Array = get_signal_parameters(EventBus, "wave_cleared")
	assert_eq(params[0], 1)  # carries the wave number


func test_begin_wave_is_restartable() -> void:
	# Arena's wave loop calls begin_wave(n+1) on wave_cleared — it must fully reset so the
	# next wave starts clean (no stacked signals, _wave_time back to ~0).
	var s: FormationSpawner = _make()
	s.wave_duration_s = 1.0
	s.drip_interval_s = 0.5
	watch_signals(EventBus)
	s.begin_wave(1)
	for _i in 100:  # 1.67s — wave 1 ends → wave_cleared(1) emits
		s._physics_process(1.0 / 60.0)
	var cleared_after_wave1: int = get_signal_emit_count(EventBus, "wave_cleared")
	s.begin_wave(2)  # Arena's loop restarts the spawner for the next wave
	for _i in 10:  # a little into wave 2 — NOT past its duration
		s._physics_process(1.0 / 60.0)
	# No new wave_cleared yet (wave 2 hasn't elapsed) → no stacked/duplicate signal.
	assert_eq(get_signal_emit_count(EventBus, "wave_cleared"), cleared_after_wave1)
	assert_lt(s._wave_time, s.wave_duration_s)  # _wave_time reset by begin_wave(2)


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
