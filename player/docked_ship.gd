class_name DockedShip
extends Node2D
# The transient rescue wingman (Story 2.3 / NP1) — VISUAL-ONLY. Parented to the Player (a child), it
# rides the player's transform at the dock offset; it does NOT move independently (no _physics_process).
#
# NO hitbox: a separate docked-ship Area2D + the player's HurtboxComponent would BOTH detect the same
# enemy body → apply_hit fires twice → double-trigger bug. The +hitbox is the PLAYER's own hitbox
# growing via Player.set_docked; the +firepower is the player's parallel FireSystem stream; the
# intrinsic first-hit absorber is Player.apply_hit. This node is the wingman INDICATOR (rescue made
# visible) — its combat presence lives entirely on the Player.
#
# NOT pooled (NP1) — instantiate() on attach, queue_free() on detach. Created/destroyed at most once
# per wave (FR14 one-docked), so it is NOT a hot-path pooled type (do NOT route it through Pool).
# Wave-scope: Player._on_wave_cleared detaches it at wave-end (the Keep regain is Story 2.5).

@export var tuning: DockedShipTuning

@onready var _core: Polygon2D = $Visual/Core
@onready var _outline: Line2D = $Visual/Outline
@onready var _glow: Line2D = $Visual/GlowOutline

var _player: Player


func _ready() -> void:
	# The escort-chevron shape (player arrowhead family) is baked into the .tscn's polygon points; the
	# scale + dock color are applied in attach() from tuning (the .tres wins, D9). Hidden until attach.
	if tuning == null:
		tuning = DockedShipTuning.new()
	visible = false


func setup(player: Player) -> void:
	# Cache the owning player (called by Player.try_dock_ship BEFORE attach). The docked ship rides the
	# player's transform, so it doesn't strictly need the ref in 2.3 — kept for NP1's docked_ship_controller.
	_player = player


func attach() -> void:
	# Position at the dock station (local — rides the player's transform) + apply the escort-chevron
	# scale + dock color, then show. One-time per dock (FR14 one-docked ⇒ at most once per wave).
	if tuning == null:
		tuning = DockedShipTuning.new()
	position = Vector2(tuning.dock_offset_x, 0.0)
	var s: Vector2 = Vector2.ONE * tuning.dock_scale
	if _core != null:
		_core.scale = s
		_core.color = tuning.dock_color
	if _outline != null:
		_outline.scale = s
		_outline.default_color = tuning.dock_color
	if _glow != null:
		_glow.scale = s
		_glow.default_color = tuning.dock_color
	visible = true


func detach() -> void:
	# Hide + free (NOT pooled — NP1). Called DEFERRED from Player (_consume_docked_ship / _on_wave_cleared):
	# remove_child + queue_free mid-physics is forbidden, so the caller defers this no-arg method.
	# visible=false first so it vanishes this frame even though the free lands at idle.
	visible = false
	queue_free()
