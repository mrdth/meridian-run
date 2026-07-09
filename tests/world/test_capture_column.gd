extends GutTest
# Tests for the CaptureColumn world entity (Story 2.1, Task 10). Verifies activate(x) positions at x +
# makes visible, lays the two bars out at ±width/2, set_active_visual toggles the wind-up/active look,
# and deactivate hides. Direct instantiation (the column is a plain visual Node2D in these tests;
# pooling is exercised end-to-end via test_captor_fsm.gd).

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
