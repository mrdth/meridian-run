extends GutTest
# PURE unit tests for HudFocusModel (arch line 545 names this file). No scene — the model is a pure
# Resource. Mirrors the test_health_component pure-logic style. Covers the canonical arch-line-321
# signature (projectiles_in_play, captors_active, hp_ratio, time_remaining), the MAX-of-axes blend,
# and the hysteresis gate that prevents focus/fade flicker.


func _make() -> HudFocusModel:
	return HudFocusModel.new()


func test_intensity_clamped_to_unit() -> void:
	var m := _make()
	assert_true(m.intensity(0, 0, 1.0, 999.0) >= 0.0)
	assert_true(m.intensity(0, 0, 1.0, 999.0) <= 1.0)
	assert_true(m.intensity(0, 0, 0.0, 0.0) <= 1.0)


func test_full_hp_and_ample_time_is_calm() -> void:
	var m := _make()
	# hp_ratio 1.0 (full) + plenty of time + no projectiles/captors → intensity 0.
	assert_eq(m.intensity(0, 0, 1.0, 60.0), 0.0)


func test_critical_hp_maxes_intensity() -> void:
	# hp_ratio at/below hp_critical_ratio (0.5) ⇒ hp_axis = 1.0 ⇒ intensity 1.0, even with ample time.
	var m := _make()
	assert_almost_eq(m.intensity(0, 0, 0.5, 60.0), 1.0, 0.001)
	assert_almost_eq(m.intensity(0, 0, 0.1, 60.0), 1.0, 0.001)
	assert_almost_eq(m.intensity(0, 0, 0.0, 60.0), 1.0, 0.001)


func test_above_critical_hp_no_hp_contribution() -> void:
	# hp_ratio 0.6 > 0.5 threshold ⇒ hp_axis 0; with ample time the overall intensity is 0.
	var m := _make()
	assert_eq(m.intensity(0, 0, 0.6, 60.0), 0.0)


func test_low_time_raises_intensity() -> void:
	var m := _make()
	var calm: float = m.intensity(0, 0, 1.0, 60.0)
	var urgent: float = m.intensity(0, 0, 1.0, 3.0)  # 3s left
	assert_true(urgent > calm)


func test_zero_time_maxes_time_axis() -> void:
	var m := _make()
	assert_almost_eq(m.intensity(0, 0, 1.0, 0.0), 1.0, 0.001)


func test_time_axis_ramps_linearly() -> void:
	# time_axis goes 0 at low_time_s (10) → 1 at 0, linear. Halfway (5s) → 0.5.
	var m := _make()
	assert_almost_eq(m.intensity(0, 0, 1.0, 10.0), 0.0, 0.001)
	assert_almost_eq(m.intensity(0, 0, 1.0, 5.0), 0.5, 0.001)


func test_projectiles_axis_forward_compat() -> void:
	# E1 passes 0, but the axis should respond when wired (E2/E8) — verify it contributes when nonzero.
	var m := _make()
	var with_shots: float = m.intensity(40, 0, 1.0, 60.0)  # 40 > projectiles_intense(24) → max
	assert_almost_eq(with_shots, 1.0, 0.001)


func test_captors_axis_forward_compat() -> void:
	var m := _make()
	var with_captors: float = m.intensity(0, 3, 1.0, 60.0)  # 3 > captor_intense(2) → max
	assert_almost_eq(with_captors, 1.0, 0.001)


func test_should_focus_enters_at_enter_threshold() -> void:
	# standard → focus at >= focus_enter_at (0.6).
	var m := _make()
	assert_false(m.should_focus(false, 0.5))
	assert_true(m.should_focus(false, 0.6))
	assert_true(m.should_focus(false, 0.9))


func test_should_focus_hysteresis_holds_in_deadband() -> void:
	# Already focused: stays focused down to focus_exit_at (0.4), not focus_enter_at (0.6).
	var m := _make()
	assert_true(m.should_focus(true, 0.5))   # 0.5 is in the deadband; stays focused
	assert_true(m.should_focus(true, 0.4))   # exactly the exit threshold
	assert_false(m.should_focus(true, 0.3))  # below exit → back to standard


func test_should_focus_no_flicker_in_deadband() -> void:
	# A value oscillating inside the deadband (0.4–0.6) never flips the state once it's set.
	var m := _make()
	assert_true(m.should_focus(false, 0.7))   # enter focus
	assert_true(m.should_focus(true, 0.5))    # deadband — stays
	assert_true(m.should_focus(true, 0.45))   # deadband — stays
	assert_false(m.should_focus(true, 0.3))   # below exit → leaves
