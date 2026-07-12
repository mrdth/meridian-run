extends GutTest
# Story 2.3 (Task 8) — tests for the Captor's extended `died` signal: died(score_value, rescue, at).
# The captor OWNS the rescue condition (F + G): rescue = killed during `dive` AND captured_player.
# A dive-kill WITHOUT a prior capture (player dodged) is NOT a rescue → failed-rescue. The signal
# carries the computed bool + the death position (the failed-rescue enemy spawns at `at`). Mirrors the
# test_captor_fsm.gd idiom (fast test tuning, FSM driven by hand). captured_player is set manually for
# the rescue case (or via a real capture — manual is sufficient for the signal contract).

const CaptorScene := preload("res://enemies/captor/captor.tscn")


func before_each() -> void:
	Pool.clear()


func _test_tuning() -> CaptorTuning:
	# Tiny durations (mirrors test_captor_fsm.gd) so each state lasts ~0.1 s — observable in a few frames.
	var t := CaptorTuning.new()
	t.enter_duration_s = 0.1
	t.formation_duration_min_s = 0.1
	t.formation_duration_max_s = 0.1
	t.telegraph_duration_s = 0.1
	t.capture_duration_s = 0.1
	t.dive_duration_s = 0.1
	t.formation_row_y = 150.0
	t.side_drift_amplitude_px = 130.0
	t.side_drift_period_s = 3.0
	t.dive_aim_track_factor = 0.3
	t.dive_offscreen_margin_px = 48.0
	t.capture_column_width_px = 60.0
	return t


func _make() -> Captor:
	# acquire → add_child → activate, fast tuning, mock player_target, FSM + fire driven by hand.
	var container := Node2D.new()
	add_child_autofree(container)
	var captor: Captor = Pool.acquire(CaptorScene) as Captor
	container.add_child(captor)
	captor.tuning = _test_tuning()
	var player := Node2D.new()
	add_child_autofree(player)
	player.global_position = Vector2(640.0, 680.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	captor.activate(player, Vector2(640.0, -80.0), rng)
	captor.get_node("StateMachine").set_physics_process(false)
	captor.get_node("EnemyFireSystem").set_physics_process(false)
	return captor


func _drive_to_state(captor: Captor, state_name: StringName) -> void:
	# Step the FSM until current_state_name matches (formation / telegraph / capture / dive).
	var sm: StateMachine = captor.get_node("StateMachine")
	for _i in 600:
		if captor.current_state_name == state_name:
			return
		sm._physics_process(1.0 / 60.0)
	assert_eq(captor.current_state_name, state_name, "did not reach state %s" % state_name)


func _kill_and_capture_died(captor: Captor) -> Array:
	# Connect a recorder BEFORE the kill, then deal lethal damage. Returns [score_value, rescue, at].
	# Uses append (mutation) — GDScript lambdas don't write reassignment (`recorded = [...]`) back to the
	# captured outer var, but mutation (append) does (mirrors test_captor_fsm's sequence.append idiom).
	var recorded: Array = []
	captor.died.connect(func(sv: int, rescue: bool, at: Vector2) -> void:
		recorded.append(sv)
		recorded.append(rescue)
		recorded.append(at))
	var pos_at_death: Vector2 = captor.global_position
	captor.get_node("HealthComponent").take_damage(100000)  # 60 hp → 0 → _on_died → died.emit
	assert_eq(recorded.size(), 3, "died did not emit with 3 params (score_value, rescue, at)")
	# `at` must equal the captor's global_position at death (captured BEFORE the deferred release).
	assert_almost_eq((recorded[2] as Vector2).distance_to(pos_at_death), 0.0, 0.5, "died `at` != global_position")
	return recorded


func test_dive_kill_with_capture_emits_rescue_true() -> void:
	# AC#1 / F + G: killed during `dive` AND captured_player → rescue == true.
	var c := _make()
	_drive_to_state(c, &"dive")
	c.captured_player = true  # F — the prior-capture gate (a real capture would set this).
	var rec := _kill_and_capture_died(c)
	assert_eq(rec[0], 0, "captor score_value should be 0")
	assert_true(rec[1], "a dive-kill WITH a prior capture should be a rescue (rescue == true)")


func test_dive_kill_without_capture_emits_rescue_false() -> void:
	# AC#2 / F: a dive-kill WITHOUT a prior capture (player dodged) is NOT a rescue → failed-rescue.
	# This is the prior-capture gate that closes the "safe rescue" farm.
	var c := _make()
	_drive_to_state(c, &"dive")
	# captured_player stays false (no capture this spawn).
	var rec := _kill_and_capture_died(c)
	assert_false(rec[1], "a dive-kill WITHOUT a prior capture must NOT be a rescue (the gate)")


func test_formation_kill_emits_rescue_false() -> void:
	# AC#2: killed during `formation` (any non-dive state) → failed-rescue, regardless of capture.
	var c := _make()
	_drive_to_state(c, &"formation")
	c.captured_player = true  # even WITH a capture, a formation-kill is NOT a rescue.
	var rec := _kill_and_capture_died(c)
	assert_false(rec[1], "a formation-kill must be a failed-rescue (rescue == false) even if captured")


func test_telegraph_kill_emits_rescue_false() -> void:
	# AC#2: killed during `telegraph` → failed-rescue.
	var c := _make()
	_drive_to_state(c, &"telegraph")
	var rec := _kill_and_capture_died(c)
	assert_false(rec[1], "a telegraph-kill must be a failed-rescue")


func test_died_carries_death_position() -> void:
	# The failed-rescue enemy spawns at the captor's death position — `at` must be global_position.
	# (_kill_and_capture_died already asserts at == global_position; this pins it explicitly at a
	# known position so a future regression to e.g. Vector2.ZERO is caught.)
	var c := _make()
	_drive_to_state(c, &"formation")
	c.global_position = Vector2(999.0, 123.0)
	var rec := _kill_and_capture_died(c)
	assert_almost_eq((rec[2] as Vector2).x, 999.0, 0.5)
	assert_almost_eq((rec[2] as Vector2).y, 123.0, 0.5)
