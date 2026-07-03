class_name Arena
extends Node2D
# Thin arena script (1.4): wires the FormationSpawner's player ref and starts the E1 wave.
# The full wave-lifecycle FSM (wave_intro→active→completed→reward→next_wave, timer-end,
# HP heal, replay) is Story 1.8; this is the minimal precursor that exercises the spawner.

@onready var _spawner: FormationSpawner = $FormationSpawner
@onready var _player: Node2D = $Player


func _ready() -> void:
	# Inject the player into the spawner for dive aim (no cross-domain ../../Player from enemies).
	_spawner.player = _player
	_spawner.begin_wave(1)  # E1 authored wave
