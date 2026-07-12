extends GutTest
# Story 2.3 (Task 8) — integration tests for the rescue / failed-rescue BRANCH routing: the captor
# computes `rescue` (dive + captured_player — F + G) and the FormationSpawner ROUTES it via the local
# captor_resolved signal (spawner → Arena, D8). Covers the prior-capture gate (F): a dive-kill WITHOUT
# a capture is a failed-rescue, NOT a rescue (closes the "safe rescue" farm).
#
# Case (a) drives a REAL capture (MockPlayer in-column during the 0.4 s window → try_capture succeeds →
# captured_player = true), then dive, then kill → captor_resolved(true, at). Cases (b)–(d) hand-drive
# the FSM + set captured_player manually (the routing is the integration point; the captor's rescue
# computation is covered by test_captor_died_signal.gd). Mirrors test_captor_capture.gd (real physics)
# + test_captor_fsm.gd (hand-driven) + test_formation_spawner.gd (the spawner fixture).

const CaptorScene := preload("res://enemies/captor/captor.tscn")
const GruntScene := preload("res://enemies/grunt.tscn")


# A lightweight stand-in for the Player: a physics body on LAYER_PLAYER (so the capture detector's
# overlap-poll finds it) exposing the duck-called capture API. Mirrors test_captor_capture.gd.MockPlayer.
class MockPlayer:
	extends CharacterBody2D
	var capture_count := 0
	var immune := false

	func is_capture_immune() -> bool:
		return immune

	func try_capture() -> bool:
		if immune:
			return false
		capture_count += 1
		return true


func before_each() -> void:
	Pool.clear()


func _test_tuning() -> CaptorTuning:
	# Tiny FSM durations (~0.1 s each). post_capture_delay_s is short here (we just need the dive to
	# land, not measure the hold — that's test_captor_capture.gd's job).
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
	t.post_capture_delay_s = 0.1
	return t


func _make_spawner() -> FormationSpawner:
	# A minimal spawner fixture: under a Node2D arena (its _ready creates the enemy container + loads
	# the formation_def), with a MockPlayer as the player_target. Only captor_scene is needed (we spawn
	# captors, not grunts, here); grunt_scene is set for _scene_for safety.
	var arena := Node2D.new()
	add_child_autofree(arena)
	var s := FormationSpawner.new()
	s.grunt_scene = GruntScene
	s.captor_scene = CaptorScene
	arena.add_child(s)  # _ready: creates _container, loads formation_def.
	var mock := MockPlayer.new()
	mock.collision_layer = Constants.LAYER_PLAYER
	mock.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	cs.shape = rect
	mock.add_child(cs)
	mock.global_position = Vector2(640.0, 680.0)
	arena.add_child(mock)
	s.player = mock
	return s


func _spawn_captor(s: FormationSpawner, player_pos_x: float = 640.0) -> Captor:
	# spawn_captor_at (connects died → _on_captor_died → captor_resolved) + override the scene tuning
	# with the fast test tuning BEFORE any physics tick.
	s.spawn_captor_at(Vector2(player_pos_x, -80.0))
	var captor: Captor = s._container.get_child(0) as Captor
	captor.tuning = _test_tuning()
	return captor


func _hand_drive_to(captor: Captor, state_name: StringName) -> void:
	# Disable the StateMachine/fire tree ticks + step until current_state_name matches (formation /
	# telegraph / capture / dive). For the manual failed-rescue cases.
	captor.get_node("StateMachine").set_physics_process(false)
	captor.get_node("EnemyFireSystem").set_physics_process(false)
	var sm: StateMachine = captor.get_node("StateMachine")
	for _i in 600:
		if captor.current_state_name == state_name:
			return
		sm._physics_process(1.0 / 60.0)
	assert_eq(captor.current_state_name, state_name, "did not reach state %s" % state_name)


func _kill_and_get_resolution(s: FormationSpawner, captor: Captor) -> Array:
	# Listen to the spawner's captor_resolved, then deal lethal damage. Returns [rescue, at] (or [] if
	# captor_resolved did not fire). Uses append (mutation) — GDScript lambdas don't write reassignment
	# back to the captured outer var (mirrors test_captor_fsm's sequence.append idiom).
	var recorded: Array = []
	s.captor_resolved.connect(func(rescue: bool, at: Vector2) -> void:
		recorded.append(rescue)
		recorded.append(at))
	captor.get_node("HealthComponent").take_damage(100000)
	return recorded


# --- case (a): a REAL capture → dive-kill → rescue (F + G) ---

func test_real_capture_then_dive_kill_is_rescue() -> void:
	# AC#1 + F: a clean player in-column is captured (captured_player → true), then the captor dives,
	# then a dive-kill → captor_resolved(true, at). Uses REAL physics frames (the capture overlap-poll
	# needs them, per memory area-overlap-tests-need-real-physics-frames).
	var s := _make_spawner()
	var captor := _spawn_captor(s)
	captor.get_node("EnemyFireSystem").set_physics_process(false)  # no projectile clutter
	var sm: StateMachine = captor.get_node("StateMachine")
	var dive: State = captor.get_node("StateMachine/DiveState")
	# Drive real physics frames through capture (the real capture lands) into dive.
	for _i in 240:
		await get_tree().physics_frame
		if captor.current_state_name == &"dive" or sm.current_state == dive:
			break
	assert_eq(captor.current_state_name, &"dive", "did not reach dive after a real capture")
	assert_true(captor.captured_player, "the real capture did not set captured_player (F gate)")
	var rec := _kill_and_get_resolution(s, captor)
	assert_eq(rec.size(), 2, "captor_resolved did not emit (rescue, at)")
	assert_true(rec[0], "a dive-kill after a real capture should route as rescue (true)")


# --- cases (b)–(d): hand-driven failed-rescue (the prior-capture gate + non-dive states) ---

func test_dive_kill_without_capture_is_failed_rescue() -> void:
	# F (the gate): a dive-kill WITHOUT a prior capture (player dodged) → captor_resolved(false).
	var s := _make_spawner()
	var captor := _spawn_captor(s)
	_hand_drive_to(captor, &"dive")
	# captured_player stays false (no capture this spawn — the player dodged).
	var rec := _kill_and_get_resolution(s, captor)
	assert_eq(rec.size(), 2)
	assert_false(rec[0], "a dive-kill without a capture must route as failed-rescue (the gate)")


func test_formation_kill_is_failed_rescue_even_if_captured() -> void:
	# AC#2: killed during `formation` → failed-rescue regardless of a prior capture.
	var s := _make_spawner()
	var captor := _spawn_captor(s)
	_hand_drive_to(captor, &"formation")
	captor.captured_player = true  # even with a capture, a non-dive kill is a failed-rescue.
	var rec := _kill_and_get_resolution(s, captor)
	assert_eq(rec.size(), 2)
	assert_false(rec[0], "a formation-kill must route as failed-rescue even if captured")


func test_telegraph_kill_is_failed_rescue() -> void:
	# AC#2: killed during `telegraph` → failed-rescue.
	var s := _make_spawner()
	var captor := _spawn_captor(s)
	_hand_drive_to(captor, &"telegraph")
	var rec := _kill_and_get_resolution(s, captor)
	assert_eq(rec.size(), 2)
	assert_false(rec[0], "a telegraph-kill must route as failed-rescue")


# --- pool contract: captured_player resets on activate ---

func test_captured_player_resets_on_activate() -> void:
	# F reset (pool contract): a fresh activate() starts un-captured, so a stale captured_player can't
	# grant a free rescue on pool reuse.
	var s := _make_spawner()
	var captor := _spawn_captor(s)
	captor.captured_player = true
	# Re-activate (simulating a pool re-acquire): activate() resets captured_player = false.
	captor.activate(s.player, Vector2(640.0, -80.0), RandomNumberGenerator.new())
	assert_false(captor.captured_player, "captured_player must reset to false on activate (pool contract)")
