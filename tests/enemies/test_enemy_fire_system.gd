extends GutTest
# Integration tests for EnemyFireSystem (1.4), driven through the variant enemy scenes.
# Mirrors tests/player/test_fire_system.gd: disable processing, drive _physics_process by
# hand, count spawns in an injected container. Asserts on child-count / instance validity /
# cooldown bounds — never visuals.

const GruntScene := preload("res://enemies/grunt.tscn")
const BomberScene := preload("res://enemies/bomber.tscn")


func before_each() -> void:
	Pool.clear()


func _make(scene: PackedScene) -> EnemyFireSystem:
	# Enemy parented under a Node2D arena (enemy._ready assigns get_parent() to the fire
	# system's projectile_parent — typed Node2D). Override projectile_parent to a temp
	# container for clean counts; disable the StateMachine + fire ticks so we drive by hand.
	var arena := Node2D.new()
	add_child_autofree(arena)
	var enemy: Enemy = scene.instantiate() as Enemy
	arena.add_child(enemy)  # _ready fires (synchronous): wires fire.projectile_parent = arena
	var fire: EnemyFireSystem = enemy.get_node("EnemyFireSystem")
	var pp := Node2D.new()
	add_child_autofree(pp)
	fire.projectile_parent = pp  # override for clean counts
	enemy.get_node("StateMachine").set_physics_process(false)
	fire.set_physics_process(false)
	return fire


func test_disarmed_fires_nothing() -> void:
	var fire: EnemyFireSystem = _make(GruntScene)
	var rng := RandomNumberGenerator.new()
	fire.arm((fire.get_parent() as Enemy).definition, rng, false)  # disarmed
	for _i in 180:  # 3 s
		fire._physics_process(1.0 / 60.0)
	assert_eq(fire.projectile_parent.get_child_count(), 0)


func test_armed_fires_only_after_cooldown_interval() -> void:
	# arm() delays the first shot by a random interval within [min, max]. Before the min →
	# no shot; after the max → at least one. Grunt interval band 1.2–2.4 s (FR43).
	var fire: EnemyFireSystem = _make(GruntScene)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	fire.arm((fire.get_parent() as Enemy).definition, rng, true)
	for _i in 60:  # 1 s < 1.2 s min
		fire._physics_process(1.0 / 60.0)
	assert_eq(fire.projectile_parent.get_child_count(), 0)
	for _i in 180:  # +3 s, total 4 s > 2.4 s max
		fire._physics_process(1.0 / 60.0)
	assert_gt(fire.projectile_parent.get_child_count(), 0)


func test_spawned_projectiles_are_pooled_enemy_projectiles() -> void:
	var fire: EnemyFireSystem = _make(GruntScene)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	fire.arm((fire.get_parent() as Enemy).definition, rng, true)
	for _i in 240:  # 4 s
		fire._physics_process(1.0 / 60.0)
	var count: int = fire.projectile_parent.get_child_count()
	assert_gt(count, 0)
	for c in fire.projectile_parent.get_children():
		assert_true(c is EnemyProjectile)
		assert_false(c.is_queued_for_deletion())  # pooled, not freed


func test_bomber_spawns_heavy_two_damage_shot() -> void:
	# AC4 — Bomber fires a HEAVY telegraphed shot carrying fire_damage == 2.
	var fire: EnemyFireSystem = _make(BomberScene)
	var def: EnemyDefinition = (fire.get_parent() as Enemy).definition
	assert_eq(def.fire_damage, 2)
	assert_eq(def.shot_kind, EnemyDefinition.ShotKind.HEAVY)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	fire.arm(def, rng, true)
	for _i in 240:  # 4 s > 2.8 s Bomber max interval
		fire._physics_process(1.0 / 60.0)
	assert_gt(fire.projectile_parent.get_child_count(), 0)
	var proj: EnemyProjectile = fire.projectile_parent.get_child(0) as EnemyProjectile
	# Heavy → amber climax-hazard pellet (distinct from the standard red).
	var vis: Polygon2D = proj.get_node("Visual")
	assert_almost_eq(vis.color.g, 0.62, 0.02)


func test_sweep_mode_fires_at_tight_cadence() -> void:
	# SweepState arms SWEEP mode (decision-log [Sweep-state]) → the tight sweep_fire_interval_s
	# cadence (0.4 s) instead of the stock 1.2–2.4 s band, so a strafing run rakes dense fire.
	# Park the enemy high so spawned projectiles don't leave-screen during the window
	# (child_count then == shots fired, not shots still in flight).
	var fire: EnemyFireSystem = _make(GruntScene)
	var def: EnemyDefinition = (fire.get_parent() as Enemy).definition
	(fire.get_parent() as Enemy).global_position = Vector2(0.0, -1000.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	fire.arm(def, rng, true, true)  # SWEEP mode
	for _i in 300:  # 5 s
		fire._physics_process(1.0 / 60.0)
	var sweep_shots: int = fire.projectile_parent.get_child_count()

	var fire2: EnemyFireSystem = _make(GruntScene)
	(fire2.get_parent() as Enemy).global_position = Vector2(0.0, -1000.0)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 7
	fire2.arm(def, rng2, true)  # normal mode (same seed for a fair compare)
	for _i in 300:
		fire2._physics_process(1.0 / 60.0)
	var normal_shots: int = fire2.projectile_parent.get_child_count()

	# Sweep (0.4 s → ~12 shots / 5 s) far exceeds normal (1.2–2.4 s → ≤4 shots / 5 s).
	assert_gt(sweep_shots, normal_shots * 2, "sweep mode did not fire at a tighter cadence than normal")


func test_physics_process_makes_no_per_frame_allocations() -> void:
	# Runtime check (review fix — a source-text grep proved nothing about actual allocation and
	# was trivially defeated by reformatting). Drives the cooldown-accumulator hot path — the
	# code that runs every physics tick regardless of firing — for many ticks and asserts the
	# engine's live Object count doesn't grow. Disarmed (never spawns) so this isolates the
	# accumulator logic itself from _spawn()'s legitimate first-instantiate pool allocation.
	var fire: EnemyFireSystem = _make(GruntScene)
	var rng := RandomNumberGenerator.new()
	fire.arm((fire.get_parent() as Enemy).definition, rng, false)  # disarmed: never spawns
	var before: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	for _i in 600:  # 10 s of ticks through the real hot-path body
		fire._physics_process(1.0 / 60.0)
	var after: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	assert_eq(after, before, "physics_process should allocate zero objects on the hot path")
