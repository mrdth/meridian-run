class_name StateMachine
extends Node
# Reusable finite-state machine (D6). Holds the current State and forwards
# _physics_process/_process to it; transition_to() exits the current state and enters the
# target. GENERIC — no entity-specific logic lives here (consumers: enemy AI, the Captor
# FSM, HUD focus/fade). Each State reaches its owner via `owner` (the scene root), so this
# node needs no back-reference to the entity.
#
# Tick ownership: this node owns _physics_process and forwards to the current state. An
# entity using it should NOT also define its own _physics_process (avoids double-updating
# the current state / nondeterministic parent-vs-child processing order). When the entity
# is released to the Pool, remove_child() detaches this whole subtree — the tick stops on
# idle pooled entities without any explicit toggle.

@export var initial_state: State

var current_state: State


func _ready() -> void:
	# initial_state is the inspector-assigned starting State. Node-typed @export node refs
	# don't always resolve from a hand-authored .tscn NodePath (a Godot text-scene
	# limitation), so fall back to the first State child — a StateMachine with State
	# children always has a deterministic start. Either way, an initial state is established.
	if initial_state == null:
		for c in get_children():
			if c is State:
				initial_state = c
				break
	assert(initial_state != null, "StateMachine: no initial_state and no State children")
	current_state = initial_state
	current_state.enter()


func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_process(delta)


func _process(delta: float) -> void:
	if current_state != null:
		current_state.process(delta)


func transition_to(target: State, msg: Dictionary = {}) -> void:
	assert(target != null, "StateMachine: cannot transition to a null state")
	if current_state != null:
		current_state.exit()
	current_state = target
	target.enter(msg)
