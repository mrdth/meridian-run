extends GutTest
# Pool round-trip tests for ParticleBurst (Story 1.6 / AC3). Mirrors the test_pool.gd /
# test_enemy_projectile.gd pooled-node pattern: acquire → activate → (Timer self-release) →
# re-acquire returns the SAME instance (LIFO); activate re-arms `emitting` on a reused instance
# (the regression guard for "never re-init via _ready()"). Plain add_child (NOT autofree) for
# self-releasing bursts so GUT doesn't free a node the Pool holds; before_each Pool.clear() resets.

const Scene := preload("res://juice/particle_burst.tscn")


func before_each() -> void:
	Pool.clear()


func _profile() -> Dictionary:
	# A minimal valid profile (matches the JuiceTuning shape). Built per-test (tests aren't hot path).
	return {
		&"amount": 6,
		&"lifetime": 0.15,
		&"spread_rad": PI,
		&"speed": 200.0,
		&"scale": 0.7,
		&"direction": Vector3(0.0, -1.0, 0.0),
		&"gravity": Vector3.ZERO,
	}


func test_structure_is_gpuparticles2d_with_activate() -> void:
	var b: ParticleBurst = add_child_autofree(Scene.instantiate()) as ParticleBurst
	assert_true(b is GPUParticles2D)
	assert_true(b.has_method("activate"))
	assert_true(b.one_shot)


func test_activate_emits_and_positions_at_world_point() -> void:
	var b: ParticleBurst = Pool.acquire(Scene) as ParticleBurst
	add_child(b)
	b.activate(&"hit_spark", Vector2(120.0, 240.0), Color.CYAN, _profile())
	assert_true(b.emitting)
	assert_eq(b.amount, 6)
	assert_almost_eq(b.global_position.x, 120.0, 0.5)
	assert_almost_eq(b.global_position.y, 240.0, 0.5)
	# Additive blend carries the neon glow read (CanvasItemMaterial on the node).
	assert_true(b.material is CanvasItemMaterial)
	assert_eq((b.material as CanvasItemMaterial).blend_mode, CanvasItemMaterial.BLEND_MODE_ADD)
	# Let it self-release before the test ends so it lands in the pool (clean teardown).
	await get_tree().create_timer(0.4).timeout


func test_self_releases_to_pool_after_lifetime() -> void:
	var b: ParticleBurst = Pool.acquire(Scene) as ParticleBurst
	add_child(b)
	b.activate(&"hit_spark", Vector2.ZERO, Color.WHITE, _profile())
	assert_not_null(b.get_parent())  # attached
	# lifetime(0.15) + margin(0.15) = 0.3s; await past it ⇒ Timer fires Pool.release.
	await get_tree().create_timer(0.45).timeout
	assert_eq(b.get_parent(), null)  # released ⇒ detached (never queue_free)


func test_pool_round_trip_reuses_instance_and_rearms() -> void:
	# acquire → activate → release (via Timer) → re-acquire returns the SAME node (LIFO); activate
	# re-arms `emitting` on the reused instance (regression guard for "never _ready() re-init").
	var a: ParticleBurst = Pool.acquire(Scene) as ParticleBurst
	add_child(a)
	var id_a := a.get_instance_id()
	a.activate(&"hit_spark", Vector2.ZERO, Color.WHITE, _profile())
	await get_tree().create_timer(0.4).timeout  # let it self-release to the pool
	assert_eq(a.get_parent(), null)  # pooled

	var b: ParticleBurst = Pool.acquire(Scene) as ParticleBurst
	assert_eq(b.get_instance_id(), id_a)  # LIFO reuse — same node, not re-instantiated
	add_child(b)
	b.activate(&"explosion", Vector2.ZERO, Color.WHITE, _profile())
	assert_true(b.emitting)  # re-armed on the reused instance
	await get_tree().create_timer(0.4).timeout  # clean teardown


func test_texture_is_procedural_and_cached() -> void:
	# The procedural radial-gradient texture is baked once (static cache) — non-null + shared.
	var b: ParticleBurst = add_child_autofree(Scene.instantiate()) as ParticleBurst
	assert_not_null(b.texture)
	var b2: ParticleBurst = add_child_autofree(Scene.instantiate()) as ParticleBurst
	assert_eq(b2.texture.get_rid(), b.texture.get_rid())  # same shared ImageTexture instance
