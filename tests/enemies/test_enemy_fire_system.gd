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


func test_physics_process_makes_no_per_frame_allocations() -> void:
	# Structural: the _physics_process body constructs no Vector2/Array/Dict/.new (zero
	# per-frame allocations on the hot path). Scoped to that method only.
	var src: String = (load("res://enemies/enemy_fire_system.gd") as GDScript).source_code
	var start: int = src.find("func _physics_process")
	assert_gt(start, -1, "could not find _physics_process in enemy_fire_system.gd")
	var end: int = src.find("\nfunc ", start + 1)
	if end == -1:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_false(body.contains("Vector2("))
	assert_false(body.contains("Array("))
	assert_false(body.contains("Dictionary("))
	assert_false(body.contains(".new("))
