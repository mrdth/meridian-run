extends GutTest
# Integration tests for the FormationSpawner (1.4). Verifies the FR30 spawn budget (4+N
# capped at 12), pulsed spawning across the wave duration (not instantaneous), clean
# progression through Enter/Formation/Dive, and score_changed on enemy death (D8).

const GruntScene := preload("res://enemies/grunt.tscn")
const ShielderScene := preload("res://enemies/shielder.tscn")
const BomberScene := preload("res://enemies/bomber.tscn")


func before_each() -> void:
	Pool.clear()


func _make() -> FormationSpawner:
	# Spawner under a Node2D arena (its _ready creates the enemy container under the arena).
	var arena := Node2D.new()
	add_child_autofree(arena)
	var s := FormationSpawner.new()
	s.grunt_scene = GruntScene
	s.shielder_scene = ShielderScene
	s.bomber_scene = BomberScene
	s.wave_duration_s = 3.0  # short for test pacing
	s.group_size = 4
	arena.add_child(s)  # _ready: creates _container, loads formation_def
	s.player = Node2D.new()  # dummy player for dive aim
	arena.add_child(s.player)  # freed with the autofree'd arena
	return s


func test_wave_one_spawns_five_enemies() -> void:
	# FR30 — wave N=1 → 4+1 = 5 enemies.
	var s: FormationSpawner = _make()
	s.begin_wave(1)
	for _i in 220:  # 3.67s > 3.0s wave
		s._physics_process(1.0 / 60.0)
	assert_eq(s.get_spawned_count(), 5)


func test_high_wave_capped_at_twelve() -> void:
	# FR30 — wave N=8 → min(4+8, 12) = 12 (the cap).
	var s: FormationSpawner = _make()
	s.begin_wave(8)
	for _i in 220:
		s._physics_process(1.0 / 60.0)
	assert_eq(s.get_spawned_count(), 12)


func test_budget_caps_even_for_very_high_waves() -> void:
	var s: FormationSpawner = _make()
	s.begin_wave(50)
	for _i in 220:
		s._physics_process(1.0 / 60.0)
	assert_eq(s.get_spawned_count(), 12)


func test_spawns_arrive_as_pulses_not_all_at_once() -> void:
	# AC3 — spawns are pulsed across the duration, not instantaneous. Wave 1 (5) with
	# group_size 4 → 2 pulses (3 + 2); at t≈0 only the first group (3) has spawned, not all 5.
	var s: FormationSpawner = _make()
	s.begin_wave(1)
	s._physics_process(0.01)  # t≈0.01 — only pulse 0 (time 0) is due
	var early: int = s.get_spawned_count()
	assert_lt(early, 5)  # not all at once
	assert_gte(early, 1)  # at least the first group fired


func test_enemies_progress_through_states_without_error() -> void:
	# Step long enough for entry + formation hold + dive start; no crashes across the cycle.
	var s: FormationSpawner = _make()
	s.begin_wave(1)
	for _i in 420:  # 7s — past wave (3s) + into dives
		s._physics_process(1.0 / 60.0)
	# Reaching here = no crash across Enter → Formation → Dive for every spawned enemy.
	assert_eq(s.get_spawned_count(), 5)


func test_score_changed_fires_on_enemy_death() -> void:
	# enemy.died → spawner accumulates → EventBus.score_changed (D8 global game-flow).
	var s: FormationSpawner = _make()
	s.begin_wave(1)
	for _i in 60:  # 1s — pulse-0 enemies spawned and still on-screen (mid-entry)
		s._physics_process(1.0 / 60.0)
	watch_signals(EventBus)
	var enemy: Enemy = s._container.get_child(0) as Enemy
	var expected_score: int = enemy.definition.score_value
	enemy.get_node("HealthComponent").take_damage(1000)  # kill → died → score_changed
	assert_signal_emitted(EventBus, "score_changed")
	assert_eq(s.get_run_score(), expected_score)
	await get_tree().physics_frame  # let the deferred death-release land before teardown
