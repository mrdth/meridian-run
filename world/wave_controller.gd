class_name WaveController
extends Node2D
# Arena-scoped run/wave lifecycle conductor (Story 1.8 / AC1, AC2). Owns the wave timer + a reusable
# StateMachine (Idle → Intro → Active → Completed | Failed). Drives FormationSpawner.begin_wave/stop
# at the right transitions, full-heals the player on wave completion, and broadcasts wave_started/
# wave_cleared on EventBus (the HUD + future systems subscribe). Lives in arena.tscn — NOT an autoload
# (twin to JuiceCoordinator + HUD; GameManager stays a stub — real game-mode FSM = Story 4.7).
#
# Closes the 1.5-deferred set_active-while-expired footgun BY CONSTRUCTION: this controller is the
# SOLE owner of the spawner's wave-end (Completed/Failed → stop()), and the FSM cannot re-enter
# Active except via Intro (which resets _wave_time = 0.0). A stale timer can therefore never
# double-fire wave_cleared or double-advance the wave — the latent 1.5 footgun required 1.8's
# "richer wave/pause control" to close.

@export var wave_duration_s: float = 60.0   # the [Wave-1] timer (1.8 reconciled to UX/GDD "60s survive-to-end").

# Injected by Arena._ready BEFORE start_run() (mirrors the 1.7 HUD injection pattern).
var player: Player
var spawner: FormationSpawner
var run_state: RunState   # forward-compat: unused in E1 (wave rewards land in E3); Arena injects it.

var wave_num: int = 1
var _wave_time: float = 0.0   # advanced by WaveActiveState.physics_process (fixed loop); read by tests.

@onready var _state_machine: StateMachine = $StateMachine
@onready var _idle_state: State = $StateMachine/WaveIdleState
@onready var _intro_state: State = $StateMachine/WaveIntroState
@onready var _active_state: State = $StateMachine/WaveActiveState
@onready var _completed_state: State = $StateMachine/WaveCompletedState
@onready var _failed_state: State = $StateMachine/WaveFailedState


func _ready() -> void:
	# The StateMachine auto-entered WaveIdleState on its _ready (child-first) — a safe no-op before
	# Arena injects refs + calls start_run(). Subscribe to game_over so the wave Fails on run-loss.
	EventBus.game_over.connect(_on_game_over)


func start_run() -> void:
	# Called by Arena._ready AFTER injecting player/spawner/run_state. Resets to wave 1 and begins.
	wave_num = 1
	_wave_time = 0.0
	_state_machine.transition_to(_intro_state)


# --- transition helpers (the states reach these via `owner as WaveController`) ---
func to_intro() -> void:
	_state_machine.transition_to(_intro_state)


func to_active() -> void:
	_state_machine.transition_to(_active_state)


func to_completed() -> void:
	_state_machine.transition_to(_completed_state)


func to_failed() -> void:
	_state_machine.transition_to(_failed_state)


func heal_player_to_full() -> void:
	# AC2 — full HP before the next wave (AR2; was Arena._on_wave_cleared in 1.5). Reaches the
	# injected player's HealthComponent directly — same legitimacy as Arena's prior direct call.
	if player != null and player._health != null:
		player._health.reset_to_full()


func _on_game_over() -> void:
	# Player lost their last ship → the wave is Failed. Guard: only transition if mid-wave
	# (Active/Intro); never re-enter Failed from a terminal state. Synchronous — D8 global flow.
	var cur: State = _state_machine.current_state
	if cur == _active_state or cur == _intro_state:
		to_failed()


func get_state_name() -> String:
	# Debug overlay / tests read the current lifecycle phase (e.g. "WaveActiveState").
	var cur: State = _state_machine.current_state
	return cur.name if cur != null else ""
