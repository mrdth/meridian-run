class_name WaveIdleState
extends State
# Initial no-op (Story 1.8). The reusable StateMachine auto-enters `initial_state` on its _ready,
# which fires BEFORE Arena injects the WaveController's player/spawner/run_state refs (children
# run _ready bottom-up, before Arena._ready). WaveIdleState absorbs that auto-enter safely so the
# wave does NOT start until Arena calls WaveController.start_run() → Intro → Active.


func enter(_msg: Dictionary = {}) -> void:
	pass
