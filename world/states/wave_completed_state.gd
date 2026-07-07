class_name WaveCompletedState
extends State
# "Completed" phase (timer expired). Halts the spawner + despawns survivors (clean board), full-
# heals the player (AC2), broadcasts wave_cleared, advances the wave number (default replay
# decision — the SAME authored composition re-drips with an escalated per_tick per FR30), then
# re-enters Intro for the next wave. The heal+advance+replay moved here from Arena._on_wave_cleared
# (1.5) — the WaveController owns the wave loop now (AR2: run-scope decisions stay on Arena; the
# wave lifecycle is here).

var _controller: WaveController


func enter(_msg: Dictionary = {}) -> void:
	_controller = owner as WaveController
	if _controller == null:
		return
	if _controller.spawner != null:
		_controller.spawner.stop()  # halt drip + despawn survivors (synchronous — not a body_entered ctx)
	_controller.heal_player_to_full()  # AC2 — full HP before the next wave
	EventBus.wave_cleared.emit(_controller.wave_num)
	_controller.wave_num += 1  # advance (Open Q #1 default); per_tick(wave) escalation next wave
	_controller.to_intro()  # replay the authored wave
