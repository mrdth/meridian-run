extends GutTest
# Pure-logic unit tests for EnemyDefinition (1.4). Loads the three .tres instances and
# verifies the GDD stat baselines round-trip, then exercises ContentRegistry's real
# get_enemy_def — including the grunt fail-safe fallback (AR11). No scenes instantiated.

const _GRUNT := preload("res://resources/enemies/enemy_grunt.tres")
const _SHIELDER := preload("res://resources/enemies/enemy_shielder.tres")
const _BOMBER := preload("res://resources/enemies/enemy_bomber.tres")


func test_all_three_load_as_enemy_definitions() -> void:
	assert_true(_GRUNT is EnemyDefinition)
	assert_true(_SHIELDER is EnemyDefinition)
	assert_true(_BOMBER is EnemyDefinition)


func test_ids_match_registry_keys() -> void:
	# id is the ContentRegistry index key; formation_id points at the standard formation.
	assert_eq(_GRUNT.id, &"grunt")
	assert_eq(_SHIELDER.id, &"shielder")
	assert_eq(_BOMBER.id, &"bomber")
	assert_eq(_GRUNT.formation_id, &"standard")


func test_grunt_stats_match_gdd_baselines() -> void:
	var g: EnemyDefinition = _GRUNT
	assert_eq(g.max_hp, 30)
	assert_eq(g.score_value, 100)
	assert_eq(g.fire_damage, 1)
	assert_eq(g.shot_kind, EnemyDefinition.ShotKind.STANDARD)
	assert_eq(g.fire_interval_min_s, 1.2)
	assert_eq(g.fire_interval_max_s, 2.4)
	# move_speed raised from the GDD baseline (60) — playtest-tuned for arcade entry/dive feel.
	assert_eq(g.move_speed, 220.0)


func test_shielder_stats_match_gdd_baselines() -> void:
	var s: EnemyDefinition = _SHIELDER
	assert_eq(s.max_hp, 50)
	assert_eq(s.score_value, 150)
	assert_eq(s.fire_damage, 1)
	assert_eq(s.shot_kind, EnemyDefinition.ShotKind.STANDARD)
	assert_eq(s.fire_interval_min_s, 0.9)
	assert_eq(s.fire_interval_max_s, 1.8)
	assert_eq(s.move_speed, 180.0)  # playtest-tuned (GDD baseline 50)


func test_bomber_stats_match_gdd_baselines() -> void:
	# Bomber = HEAVY/telegraphed, 2 dmg, 300 score, 80 hp — the climax threat (FR43).
	var b: EnemyDefinition = _BOMBER
	assert_eq(b.max_hp, 80)
	assert_eq(b.score_value, 300)
	assert_eq(b.fire_damage, 2)
	assert_eq(b.shot_kind, EnemyDefinition.ShotKind.HEAVY)
	assert_eq(b.fire_interval_min_s, 1.6)
	assert_eq(b.fire_interval_max_s, 2.8)
	assert_eq(b.move_speed, 280.0)  # playtest-tuned (GDD baseline 80)


func test_sweep_movement_fields_default() -> void:
	# Schema defaults for SweepState (decision-log [Sweep-state]).
	var f := EnemyDefinition.new()
	assert_eq(f.sweep_speed_multiplier, 2.5)
	assert_eq(f.sweep_fire_interval_s, 0.4)


func test_sweep_movement_fields_authored() -> void:
	# Grunt/Shielder sweep at 2.5× speed / 0.4 s cadence; Bomber's stream is slightly slower (0.5 s)
	# so its dense raking fire stays fair.
	assert_eq(_GRUNT.sweep_speed_multiplier, 2.5)
	assert_eq(_GRUNT.sweep_fire_interval_s, 0.4)
	assert_eq(_SHIELDER.sweep_fire_interval_s, 0.4)
	assert_eq(_BOMBER.sweep_fire_interval_s, 0.5)


func test_projectile_speed_dodgeable_vs_player() -> void:
	# Task 4.3 — enemy projectile (280) must be slower than the player bullet (620).
	for d in [_GRUNT, _SHIELDER, _BOMBER]:
		assert_lt((d as EnemyDefinition).projectile_speed, 620.0)


func test_registry_returns_indexed_grunt() -> void:
	# AC1 — ContentRegistry indexes by id (real impl, no load() in gameplay code).
	var g: EnemyDefinition = ContentRegistry.get_enemy_def(&"grunt")
	assert_not_null(g)
	assert_eq(g.id, &"grunt")


func test_registry_returns_shielder_and_bomber() -> void:
	assert_eq(ContentRegistry.get_enemy_def(&"shielder").id, &"shielder")
	assert_eq(ContentRegistry.get_enemy_def(&"bomber").id, &"bomber")


func test_registry_missing_id_returns_grunt_fallback() -> void:
	# AR11 fail-safe — a missing id returns the grunt fallback, NEVER null/crash. The
	# grunt-fallback path logs an error (Log.err); mark it expected so GUT doesn't flag it.
	var fallback: EnemyDefinition = ContentRegistry.get_enemy_def(&"nonexistent")
	assert_push_error("grunt fallback")
	assert_not_null(fallback)
	assert_eq(fallback.id, &"grunt")
