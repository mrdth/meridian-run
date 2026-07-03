extends GutTest
# Unit tests for the reusable StateMachine (D6) — pure-ish logic: enter/exit ordering on
# transitions, _physics_process forwarding, and the null-current-state guard. Uses spy
# States (inner classes extending State) so no real entity scenes are needed.

class _SpyState extends State:
	var entered: int = 0
	var exited: int = 0
	var physics_ticks: int = 0
	var enter_msg: Dictionary = {}

	func enter(msg: Dictionary = {}) -> void:
		entered += 1
		enter_msg = msg

	func exit() -> void:
		exited += 1

	func physics_process(_delta: float) -> void:
		physics_ticks += 1


func _make() -> StateMachine:
	# A StateMachine with two spy states; initial_state = a. add_child triggers _ready
	# (current_state = a, a.enter()). Processing is disabled so tests drive ticks by hand.
	var sm := StateMachine.new()
	var a := _SpyState.new()
	a.name = "A"
	var b := _SpyState.new()
	b.name = "B"
	sm.add_child(a)
	sm.add_child(b)
	sm.initial_state = a
	add_child_autofree(sm)
	sm.set_physics_process(false)
	sm.set_process(false)
	return sm


func test_initial_state_entered_on_ready() -> void:
	var sm: StateMachine = _make()
	var a: _SpyState = sm.get_node("A")
	assert_eq(sm.current_state, a)
	assert_eq(a.entered, 1)


func test_transition_exits_current_and_enters_target() -> void:
	# transition_to MUST exit the current state before entering the target (clean teardown).
	var sm: StateMachine = _make()
	var a: _SpyState = sm.get_node("A")
	var b: _SpyState = sm.get_node("B")
	sm.transition_to(b)
	assert_eq(a.exited, 1)        # old state torn down
	assert_eq(b.entered, 1)       # new state entered
	assert_eq(sm.current_state, b)


func test_transition_passes_msg_to_enter() -> void:
	var sm: StateMachine = _make()
	var b: _SpyState = sm.get_node("B")
	sm.transition_to(b, {"slot": 3})
	assert_eq(b.enter_msg.get("slot", -1), 3)


func test_physics_process_forwards_to_current_state() -> void:
	var sm: StateMachine = _make()
	var a: _SpyState = sm.get_node("A")
	sm._physics_process(1.0 / 60.0)
	sm._physics_process(1.0 / 60.0)
	assert_eq(a.physics_ticks, 2)


func test_physics_process_with_null_current_does_not_crash() -> void:
	# The null-current guard: if current_state is ever null (e.g. a state cleared before a
	# transition lands), _physics_process must be a no-op, not a crash.
	var sm: StateMachine = _make()
	sm.current_state = null
	sm._physics_process(1.0 / 60.0)  # reaching here = no crash
	assert_eq(sm.current_state, null)


func test_reentry_same_state_exits_and_re_enters() -> void:
	# Transitioning to the state already current is valid (re-entry): exit + enter again.
	var sm: StateMachine = _make()
	var a: _SpyState = sm.get_node("A")
	sm.transition_to(a)
	assert_eq(a.exited, 1)
	assert_eq(a.entered, 2)
