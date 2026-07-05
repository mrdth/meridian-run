extends GutTest
# Integration tests for EnemyProjectile (1.4) — mirrors tests/player/test_projectile.gd but
# INVERTED: travels DOWNWARD, on LAYER_ENEMY_PROJECTILE, masked to LAYER_PLAYER. Asserts on
# global_position / current_hp / get_parent() (never visuals, except the heavy-pellet color
# via the public Visual node). Pool discipline: a self-releasing projectile uses plain
# add_child (not add_child_autofree) so GUT does not free a node the Pool holds.

const Scene := preload("res://enemies/enemy_projectile.tscn")


func before_each() -> void:
	Pool.clear()


func test_structure_is_area2d_on_enemy_projectile_layer() -> void:
	var p: EnemyProjectile = add_child_autofree(Scene.instantiate()) as EnemyProjectile
	assert_true(p is Area2D)
	assert_eq(p.collision_layer, Constants.LAYER_ENEMY_PROJECTILE)  # 8
	assert_eq(p.collision_mask, Constants.LAYER_PLAYER)            # 1
	assert_true(p.has_method("activate"))


func test_activate_then_step_moves_downward() -> void:
	var p: EnemyProjectile = add_child_autofree(Scene.instantiate()) as EnemyProjectile
	p.activate(Vector2(100.0, 100.0), 280.0, 1)
	for _i in 3:
		p._physics_process(1.0 / 60.0)
	# 100 + 3 * (280/60) = 114
	assert_almost_eq(p.global_position.y, 114.0, 0.05)


func test_leaves_screen_and_releases_to_pool() -> void:
	var parent: Node2D = add_child_autofree(Node2D.new())
	var p: EnemyProjectile = Pool.acquire(Scene) as EnemyProjectile
	parent.add_child(p)
	p.activate(Vector2(100.0, 718.0), 280.0, 1)
	assert_eq(p.get_parent(), parent)
	p._physics_process(1.0 / 60.0)  # 718 + 280/60 ≈ 722.7 ≥ 720 → release
	assert_eq(p.get_parent(), null)


func test_standard_pellet_is_hazard_red() -> void:
	var p: EnemyProjectile = add_child_autofree(Scene.instantiate()) as EnemyProjectile
	p.activate(Vector2.ZERO, 280.0, 1, false)
	var vis: Polygon2D = p.get_node("Visual")
	assert_almost_eq(vis.color.r, 1.0, 0.01)
	assert_almost_eq(vis.color.g, 0.24, 0.01)


func test_heavy_pellet_is_climax_amber_and_larger() -> void:
	var p: EnemyProjectile = add_child_autofree(Scene.instantiate()) as EnemyProjectile
	p.activate(Vector2.ZERO, 280.0, 2, true)
	var vis: Polygon2D = p.get_node("Visual")
	assert_almost_eq(vis.color.g, 0.62, 0.02)  # amber, not red
	assert_gt(vis.scale.x, 1.0)                 # larger pellet


func test_hits_player_body_applies_damage_and_consumes() -> void:
	# Dummy player on LAYER_PLAYER with a HealthComponent sits below the spawn; the projectile
	# travels DOWN into it. body_entered fires (await real physics frames — manual stepping
	# does not raise engine signals).
	var player := _make_player_fixture(Vector2(100.0, 400.0))
	var hc: HealthComponent = player.get_node("HealthComponent")
	var p: EnemyProjectile = Pool.acquire(Scene) as EnemyProjectile
	add_child(p)  # plain add_child: p self-releases to the pool on hit
	p.activate(Vector2(100.0, 350.0), 280.0, 10)
	for _i in 12:
		await get_tree().physics_frame
	assert_eq(hc.current_hp, 90)
	assert_eq(p.get_parent(), null)  # consume-on-hit → released


func test_damage_value_flows_through_activate() -> void:
	# damage=2 (the Bomber's fire_damage) reaches take_damage — AC4 heavy-shot damage.
	var player := _make_player_fixture(Vector2(100.0, 400.0))
	var hc: HealthComponent = player.get_node("HealthComponent")
	var p: EnemyProjectile = Pool.acquire(Scene) as EnemyProjectile
	add_child(p)
	p.activate(Vector2(100.0, 350.0), 280.0, 2, true)
	for _i in 12:
		await get_tree().physics_frame
	assert_eq(hc.current_hp, 98)  # 100 - 2


func test_hit_during_iframes_does_not_fire_juice() -> void:
	# Review fix — take_damage() fully no-ops while the player is invulnerable (no damage, no
	# signals), but the juice emit ran unconditionally regardless, burning the shared ≤3Hz
	# hit-flash budget (and shake/SFX) on a hit that mechanically did nothing. Granting i-frames
	# BEFORE the hit lands must suppress the juice entirely.
	var player := _make_player_fixture(Vector2(100.0, 400.0))
	var hc: HealthComponent = player.get_node("HealthComponent")
	hc.set_invuln(5.0)  # invulnerable before the bullet arrives
	watch_signals(EventBus)
	var p: EnemyProjectile = Pool.acquire(Scene) as EnemyProjectile
	add_child(p)
	p.activate(Vector2(100.0, 350.0), 280.0, 10)
	for _i in 12:
		await get_tree().physics_frame
	assert_eq(hc.current_hp, 100)  # damage fully ignored
	assert_signal_not_emitted(EventBus, "hit_flash_requested")
	assert_signal_not_emitted(EventBus, "screen_shake_requested")
	assert_signal_not_emitted(EventBus, "particles_requested")


func _make_player_fixture(pos: Vector2) -> CharacterBody2D:
	var player := CharacterBody2D.new()
	player.collision_layer = Constants.LAYER_PLAYER
	var tshape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	tshape.shape = rect
	player.add_child(tshape)
	var hc := HealthComponent.new()
	hc.max_hp = 100
	hc.name = "HealthComponent"  # convention name the projectile looks up
	player.add_child(hc)
	player.global_position = pos
	add_child_autofree(player)
	return player
