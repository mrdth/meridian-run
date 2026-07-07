class_name WaveIntroState
extends State
# "Spawn" phase (AC1: spawn → active → completed/failed). Broadcasts wave_started(wave, duration_s)
# — symmetric with the wave_cleared emit at wave-end — then enters Active. Carries BOTH the wave
# number (HUD wave readout) and the countdown duration (HUD wave-timer). Emitted HERE (not the
# spawner) because the WaveController owns wave timing as of Story 1.8. Thin: one broadcast + a
# transition (the spawner's drip starts in WaveActiveState.enter).

var _controller: WaveController


func enter(_msg: Dictionary = {}) -> void:
	_controller = owner as WaveController
	# Guard: the StateMachine may re-enter states during teardown/edge cases; never start without refs.
	if _controller == null or _controller.spawner == null:
		return
	EventBus.wave_started.emit(_controller.wave_num, _controller.wave_duration_s)
	_controller.to_active()
