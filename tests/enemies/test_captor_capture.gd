extends GutTest
# Integration tests for the Captor capture mechanic (Story 2.2). Instantiates captor.tscn with a TEST
# CaptorTuning (tiny durations + a clearly-longer post_capture_delay_s) + a MockPlayer — a
# CharacterBody2D on LAYER_PLAYER exposing the duck-called try_capture()/is_capture_immune() + a
# capture counter. The StateMachine ticks on REAL physics frames (NOT disabled, unlike test_captor_fsm)
# so the CaptureColumn's Area2D overlap-poll registers: has_overlapping_bodies() reads the physics
# server's last overlap update, which only advances on a real physics tick — manual _physics_process
# stepping would leave overlaps stale. EnemyFireSystem is disabled (no projectile clutter).
#
# Asserts: a clean player in the locked column is captured once (try_capture called exactly once) and
# the captor HOLDS post_capture_delay_s (the reel-in) before diving; an immune player is never
# captured and the captor dives immediately on window expiry (no hold); a player who dodges out of the
# column for the whole window is a MISS → immediate dive (no hold).

const CaptorScene := preload("res://enemies/captor/captor.tscn")


# A lightweight stand-in for the Player: a physics body on LAYER_PLAYER (so the capture detector's
# overlap-poll finds it) exposing the duck-called capture API. No full Player needed — the captor's
# player_target is typed Node2D, and it calls try_capture() via has_method/call (no Player cast).
class MockPlayer:
	extends CharacterBody2D
	var capture_count := 0
	var immune := false

	func is_capture_immune() -> bool:
		return immune

	func try_capture() -> bool:
		# Mirrors the real Player's contract: returns true on a successful capture (incrementing the
		# counter), false when immune. Idempotent on repeated calls (the captor polls each frame).
		if immune:
			return false
		capture_count += 1
		return true


func before_each() -> void:
	Pool.clear()


func _test_tuning() -> CaptorTuning:
	# Tiny FSM durations (each state ~0.1 s ≈ 6 frames). post_capture_delay_s is set MUCH longer than
	# the capture window so the success-hold (≈18 frames) is cleanly distinguishable from a miss
	# (≈6 frames) by frame count.
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
	t.post_capture_delay_s = 0.3  # the reel-in hold (≈18 frames — well past the ≈6-frame miss window)
	return t


func _make_mock_player(pos: Vector2, immune: bool) -> MockPlayer:
	var p := MockPlayer.new()
	p.immune = immune
	p.collision_layer = Constants.LAYER_PLAYER
	p.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)  # solidly overlaps the locked column (±30) for an unambiguous poll
	cs.shape = rect
	p.add_child(cs)
	p.global_position = pos
	add_child_autofree(p)
	return p


func _make_captor(player_pos: Vector2, immune: bool) -> Dictionary:
	# acquire → add_child → activate (so @onready refs are valid in activate). Override the scene tuning
	# with the fast test tuning + inject the MockPlayer as player_target. The StateMachine ticks
	# NATURALLY on real physics frames (detection needs it); EnemyFireSystem is disabled.
	var container := Node2D.new()
	add_child_autofree(container)
	var captor: Captor = Pool.acquire(CaptorScene) as Captor
	container.add_child(captor)
	captor.tuning = _test_tuning()
	var mock := _make_mock_player(player_pos, immune)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	captor.activate(mock, Vector2(player_pos.x, -80.0), rng)
	captor.get_node("EnemyFireSystem").set_physics_process(false)
	return {"captor": captor, "mock": mock}


func _await_state(sm: Node, target: State, max_frames: int) -> bool:
	# Step real physics frames until the FSM reaches `target` (or max_frames). Returns true if reached.
	for _i in max_frames:
		await get_tree().physics_frame
		if sm.current_state == target:
			return true
	return sm.current_state == target


func _count_frames_in_state(sm: Node, target: State, max_frames: int) -> int:
	# Count real physics frames spent in `target` until the FSM leaves it. Pre-condition: already in target.
	var frames := 0
	for _i in max_frames:
		if sm.current_state != target:
			break
		await get_tree().physics_frame
		frames += 1
	return frames


func test_clean_player_in_column_captured_once_and_held() -> void:
	# AC#1 + AC#5 (success path): a clean player standing in the locked column during the 0.4 s window
	# is captured once, and the captor HOLDS post_capture_delay_s (the reel-in) before diving.
	var s := _make_captor(Vector2(640.0, 680.0), false)
	var captor: Captor = s.captor
	var mock: MockPlayer = s.mock
	var sm: Node = captor.get_node("StateMachine")
	var cap: State = captor.get_node("StateMachine/CaptureState")
	var dive: State = captor.get_node("StateMachine/DiveState")
	# Reach the capture state (enter + formation + telegraph ≈ 18 frames at 0.1 s each).
	assert_true(await _await_state(sm, cap, 90), "did not reach CaptureState")
	# Count frames in capture until the dive transition.
	var frames_in_capture := await _count_frames_in_state(sm, cap, 90)
	assert_eq(mock.capture_count, 1, "try_capture was not called exactly once")
	assert_eq(sm.current_state, dive, "did not transition to DiveState after the reel-in hold")
	# The reel-in hold (≈18 frames) keeps the captor in CaptureState well past the miss window (≈6).
	assert_gt(frames_in_capture, 12, "captor did not hold the reel-in beat after a successful capture")
	for _i in 4:
		await get_tree().physics_frame  # let the dive + deferred pool-release settle


func test_immune_player_not_captured_and_dives_immediately() -> void:
	# AC2 guard: an immune player (is_capture_immune → true; try_capture returns false) is never
	# captured, and the captor dives immediately on window expiry — NO reel-in hold.
	var s := _make_captor(Vector2(640.0, 680.0), true)
	var captor: Captor = s.captor
	var mock: MockPlayer = s.mock
	var sm: Node = captor.get_node("StateMachine")
	var cap: State = captor.get_node("StateMachine/CaptureState")
	assert_true(await _await_state(sm, cap, 90), "did not reach CaptureState")
	var frames_in_capture := await _count_frames_in_state(sm, cap, 90)
	assert_eq(mock.capture_count, 0, "an immune player should never be captured")
	assert_lt(frames_in_capture, 12, "captor held on an immune player (should dive immediately, no hold)")


func test_player_dodges_out_of_column_misses_and_dives_immediately() -> void:
	# AC#5 (miss path): a player who dodges OUT of the locked column before the window opens is a MISS
	# — try_capture is never called, and the captor dives immediately on window expiry (no hold).
	var s := _make_captor(Vector2(640.0, 680.0), false)
	var captor: Captor = s.captor
	var mock: MockPlayer = s.mock
	var sm: Node = captor.get_node("StateMachine")
	var tele: State = captor.get_node("StateMachine/TelegraphState")
	var cap: State = captor.get_node("StateMachine/CaptureState")
	# Reach telegraph (the column locks to the player's x=640 here), then dodge the player OUT of the
	# locked column before the capture window opens.
	assert_true(await _await_state(sm, tele, 90), "did not reach TelegraphState")
	mock.global_position.x = 1100.0  # dodge out of the locked column (±30 of 640)
	# Now reach the capture window — the player is no longer in the column.
	assert_true(await _await_state(sm, cap, 30), "did not reach CaptureState")
	var frames_in_capture := await _count_frames_in_state(sm, cap, 90)
	assert_eq(mock.capture_count, 0, "try_capture was called on a player outside the column")
	assert_lt(frames_in_capture, 12, "captor held on a miss (should dive immediately, no reel-in)")
