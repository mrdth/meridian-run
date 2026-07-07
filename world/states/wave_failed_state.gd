class_name WaveFailedState
extends State
# "Failed" phase (player run-lost — EventBus.game_over from Arena._on_run_lost on the last ship).
# Halts the spawner. Terminal for the E1 placeholder: Arena's deferred auto_replay_on_loss reloads
# the scene for a fresh run (the real game-over screen = Story 8.4). Reached only via
# WaveController._on_game_over while Active/Intro (guarded — never re-entered from Completed/Failed).

var _controller: WaveController


func enter(_msg: Dictionary = {}) -> void:
	_controller = owner as WaveController
	if _controller == null:
		return
	if _controller.spawner != null:
		_controller.spawner.stop()
	Log.info("wave", "run lost — wave %d failed (E1 placeholder; Arena replays)" % _controller.wave_num)
