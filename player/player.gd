class_name Player
extends CharacterBody2D
# 1-axis chassis: horizontal-only, screen-clamped movement on the bottom lane.
# Velocity + move_and_slide() (fixed-timestep _physics_process) is the PRIMARY
# driver; the post-move clampf only corrects edge escape (no physical walls).
# Movement stays purely LOCAL — emits nothing to EventBus (no ship_lost/game_over
# until 1.5). Bounds come from Constants + own tuning, never cross-domain paths.

@export var tuning: PlayerTuning

@onready var _health: HealthComponent = $HealthComponent
@onready var _faction: FactionComponent = $FactionComponent

var _min_x: float = 0.0
var _max_x: float = 0.0


func _ready() -> void:
	# Compute + cache bounds once (hot-path: no per-frame work in _physics_process).
	_min_x = tuning.edge_margin
	_max_x = float(Constants.BASE_RESOLUTION.x) - tuning.edge_margin
	global_position = Vector2(Constants.BASE_RESOLUTION.x / 2.0, tuning.lane_y)


func _physics_process(_delta: float) -> void:
	# One call covers keyboard (digital -1/0/1) AND gamepad (continuous -1..1 with
	# the per-action deadzone applied automatically) — AC3.
	var axis: float = Input.get_axis("move_left", "move_right")
	# Velocity set directly; y explicitly 0 (1-axis lock). Do NOT multiply by delta
	# — move_and_slide() applies it internally (AC2, AR14).
	velocity = Vector2(axis * tuning.move_speed, 0.0)
	move_and_slide()  # no args; Godot applies delta internally.
	# Corrective screen-clamp to the base-resolution play field (AC1, Decision #2).
	global_position.x = clampf(global_position.x, _min_x, _max_x)
