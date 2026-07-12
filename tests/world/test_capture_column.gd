extends GutTest
# Tests for the CaptureColumn world entity (Story 2.1 + Story 2.2 detection). Verifies activate(x)
# positions at x + makes visible, lays the two bars out at ±width/2, set_active_visual toggles the
# wind-up/active look, and deactivate hides (2.1 visual). Story 2.2 adds the Area2D detection child:
# set_detection toggles monitoring, is_player_in_column() overlap-polls, and deactivate leaves
# monitoring off (stale-monitoring guard). Detection needs the column + a LAYER_PLAYER body in the tree
# + a real physics tick (has_overlapping_bodies reads the server's last overlap update).

const ColumnScene := preload("res://world/capture_column.tscn")


func _make() -> CaptureColumn:
	var col: CaptureColumn = ColumnScene.instantiate()
	add_child_autofree(col)
	return col


func test_activate_positions_at_x_and_screen_center_y() -> void:
	var col := _make()
	col.visible = false
	col.activate(400.0)
	assert_almost_eq(col.global_position.x, 400.0, 0.01)
	assert_almost_eq(col.global_position.y, Constants.BASE_RESOLUTION.y * 0.5, 0.01)  # screen center
	assert_true(col.visible, "activate should make the column visible")


func test_activate_lays_bars_at_half_width() -> void:
	# width_px (set by the captor from tuning — geometry from data, AC#5) drives the ±bar offset.
	var col := _make()
	col.width_px = 80.0
	col.activate(400.0)
	var left: Polygon2D = col.get_node("BarLeft")
	var right: Polygon2D = col.get_node("BarRight")
	assert_almost_eq(left.position.x, -40.0, 0.01)
	assert_almost_eq(right.position.x, 40.0, 0.01)


func test_deactivate_hides() -> void:
	var col := _make()
	col.activate(400.0)
	assert_true(col.visible)
	col.deactivate()
	assert_false(col.visible)


func test_set_active_visual_toggles_bar_alpha() -> void:
	# activate() starts in the wind-up (dim) look; set_active_visual(true) goes solid; false reverts.
	var col := _make()
	col.activate(400.0)
	var left: Polygon2D = col.get_node("BarLeft")
	assert_almost_eq(left.color.a, 0.45, 0.01)  # wind-up alpha
	col.set_active_visual(true)
	assert_almost_eq(left.color.a, 1.0, 0.01)   # active alpha
	col.set_active_visual(false)
	assert_almost_eq(left.color.a, 0.45, 0.01)  # back to wind-up


# --- Story 2.2: Area2D detection child (CaptureDetector) ---

func _make_player_body(pos: Vector2) -> CharacterBody2D:
	# A LAYER_PLAYER body (what the detector masks for). CharacterBody2D so it registers as a physics
	# body for has_overlapping_bodies. mask 0 so it doesn't physically collide with anything (irrelevant
	# to detection — the Area2D polls it via the layer/mask). Mirrors test_player_health._make_enemy_body.
	var body := CharacterBody2D.new()
	body.collision_layer = Constants.LAYER_PLAYER
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	cs.shape = rect
	body.add_child(cs)
	body.global_position = pos
	add_child_autofree(body)
	return body


func test_ready_configures_detector_to_detect_player_off() -> void:
	# _ready: collision_layer 0 (detects, isn't detected), mask LAYER_PLAYER, monitoring OFF.
	var col := _make()
	var det: Area2D = col.get_node("CaptureDetector")
	assert_eq(det.collision_layer, 0)
	assert_eq(det.collision_mask, Constants.LAYER_PLAYER)
	assert_false(det.monitoring, "detector monitoring should be off until set_detection(true)")


func test_set_detection_toggles_monitoring() -> void:
	var col := _make()
	col.activate(400.0)
	var det: Area2D = col.get_node("CaptureDetector")
	assert_false(det.monitoring)  # activate() starts with detection off (telegraph is wind-up)
	col.set_detection(true)
	assert_true(det.monitoring)
	col.set_detection(false)
	assert_false(det.monitoring)


func test_is_player_in_column_true_when_player_overlaps() -> void:
	var col := _make()
	col.activate(400.0)
	col.set_detection(true)
	_make_player_body(Vector2(400.0, 360.0))  # centered in the detector (x≈400±30, full height)
	for _i in 6:
		await get_tree().physics_frame  # let the physics server register the overlap
	assert_true(col.is_player_in_column(), "overlapping player body should register as in-column")


func test_is_player_in_column_false_when_no_overlap() -> void:
	var col := _make()
	col.activate(400.0)
	col.set_detection(true)
	_make_player_body(Vector2(1100.0, 360.0))  # far outside the locked column (x≈400±30)
	for _i in 6:
		await get_tree().physics_frame
	assert_false(col.is_player_in_column(), "a body outside the column should not register")


func test_is_player_in_column_false_when_detection_off() -> void:
	# Even with a body solidly overlapping, is_player_in_column() is false while detection is OFF
	# (it gates on monitoring first — the stale-overlap guard).
	var col := _make()
	col.activate(400.0)
	col.set_detection(true)
	_make_player_body(Vector2(400.0, 360.0))
	for _i in 6:
		await get_tree().physics_frame
	assert_true(col.is_player_in_column())  # sanity: overlaps while detection is on
	col.set_detection(false)
	for _i in 4:
		await get_tree().physics_frame
	assert_false(col.is_player_in_column(), "detection off ⇒ in-column reads false regardless of overlap")


func test_deactivate_leaves_monitoring_off() -> void:
	# A released/pooled column must never carry stale monitoring from a prior window.
	var col := _make()
	col.activate(400.0)
	col.set_detection(true)
	assert_true(col.get_node("CaptureDetector").monitoring)
	col.deactivate()
	assert_false(col.get_node("CaptureDetector").monitoring, "deactivate must turn detection off")
