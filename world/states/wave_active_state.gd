class_name WaveActiveState
extends State
# "Active" phase (AC1). The spawner drips escalating formation pulses (FR30 — no concurrency cap,
# timer-terminated) while a fixed-timestep timer counts toward wave_duration_s. On expiry →
# WaveCompletedState ([Wave-1] timer-end, NOT enemy clear).
#
# The timer accumulates in physics_process (the 60 Hz fixed loop) so wave length is frame-rate-
# independent (NFR2). Do NOT move it to process() — _process delta varies, and a 60s wave would
# drift measurably between 30 and 144 FPS (a real feel bug at the feel gate).

var _controller: WaveController


func enter(_msg: Dictionary = {}) -> void:
	_controller = owner as WaveController
	if _controller == null or _controller.spawner == null:
		return
	# Reset the timer fresh each wave (the footgun guard: Intro → Active always starts at t=0, so a
	# stale _wave_time can never carry over and double-fire wave_cleared).
	_controller._wave_time = 0.0
	_controller.spawner.begin_wave(_controller.wave_num)


func physics_process(delta: float) -> void:
	# Mirror enter()'s guard: if enter() bailed early on a null spawner, _controller is still
	# non-null (only spawner was missing) — without this check the timer would keep accumulating
	# on a never-reset _wave_time and could still fire to_completed() for a wave that never started
	# (the exact stale-timer footgun this state's own header claims is closed).
	if _controller == null or _controller.spawner == null or delta <= 0.0:
		return
	_controller._wave_time += delta
	if _controller._wave_time >= _controller.wave_duration_s:
		_controller.to_completed()
