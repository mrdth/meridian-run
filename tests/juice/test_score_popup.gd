extends GutTest
# Pool round-trip + activate tests for ScorePopup (kill-juice score popup). Mirrors test_particle_burst.gd:
# acquire → activate → (Timer self-release) → re-acquire returns the SAME instance (LIFO); activate
# re-arms the tween + release timer on a reused instance (regression guard for "never re-init via
# _ready()"). Plain add_child (NOT autofree) for self-releasing popups so GUT doesn't free a node the
# Pool holds; before_each Pool.clear() resets. Coordinator-parented popups in test_juice_coordinator.gd
# are autofreed via the coordinator; here we let them self-release to the pool for clean teardown.

const Scene := preload("res://juice/score_popup.tscn")


func before_each() -> void:
	Pool.clear()


func _profile() -> Dictionary:
	# A minimal valid profile (matches the JuiceCoordinator shape). Built per-test (tests aren't hot path).
	return {
		&"duration": 0.15,
		&"scale_from": 0.4,
		&"scale_to": 1.5,
		&"drift": Vector2(10.0, -8.0),
	}


func test_structure_is_node2d_with_label_and_activate() -> void:
	var p: ScorePopup = add_child_autofree(Scene.instantiate()) as ScorePopup
	assert_true(p is Node2D)
	assert_not_null(p.get_node_or_null("Label"))
	assert_true(p.has_method("activate"))


func test_activate_sets_text_position_and_scale_from() -> void:
	var p: ScorePopup = Pool.acquire(Scene) as ScorePopup
	add_child(p)
	p.activate("+150", Vector2(120.0, 240.0), Color("#FFE066"), _profile())
	# Right after activate (before any frame steps the tween): position is `at`, scale is scale_from,
	# the label text is set, and the tween + release timer are armed.
	assert_almost_eq(p.global_position.x, 120.0, 0.5)
	assert_almost_eq(p.global_position.y, 240.0, 0.5)
	assert_almost_eq(p.scale.x, 0.4, 0.001)
	assert_almost_eq(p.scale.y, 0.4, 0.001)
	assert_eq((p.get_node("Label") as Label).text, "+150")
	assert_almost_eq(p._scale_to, 1.5, 0.001)  # configured-value cache (testability seam)
	await get_tree().create_timer(0.4).timeout  # let it self-release to the pool (clean teardown)


func test_self_releases_to_pool_after_lifetime() -> void:
	var p: ScorePopup = Pool.acquire(Scene) as ScorePopup
	add_child(p)
	p.activate("+100", Vector2.ZERO, Color.WHITE, _profile())
	assert_not_null(p.get_parent())  # attached
	# duration(0.15) + margin(0.15) = 0.3s; await past it ⇒ Timer fires Pool.release.
	await get_tree().create_timer(0.45).timeout
	assert_eq(p.get_parent(), null)  # released ⇒ detached (never queue_free)


func test_pool_round_trip_reuses_instance_and_rearms() -> void:
	# acquire → activate → release (via Timer) → re-acquire returns the SAME node (LIFO); activate
	# re-arms the tween at scale_from on the reused instance (regression guard for "never _ready() re-init").
	var a: ScorePopup = Pool.acquire(Scene) as ScorePopup
	add_child(a)
	var id_a := a.get_instance_id()
	a.activate("+100", Vector2.ZERO, Color.WHITE, _profile())
	await get_tree().create_timer(0.4).timeout  # let it self-release to the pool
	assert_eq(a.get_parent(), null)  # pooled

	var b: ScorePopup = Pool.acquire(Scene) as ScorePopup
	assert_eq(b.get_instance_id(), id_a)  # LIFO reuse — same node, not re-instantiated
	add_child(b)
	b.activate("+300", Vector2.ZERO, Color.WHITE, _profile())
	assert_almost_eq(b.scale.x, 0.4, 0.001)  # re-armed at scale_from on the reused instance
	assert_eq((b.get_node("Label") as Label).text, "+300")
	await get_tree().create_timer(0.4).timeout  # clean teardown
