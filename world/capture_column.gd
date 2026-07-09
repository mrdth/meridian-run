class_name CaptureColumn
extends Node2D
# The captor's locked tractor-beam column (Story 2.1). A parallel-bars hazard visual — two thin
# vertical bars spanning the screen, centered on the captor's locked x. Hazard family → NO bright
# outline (D16/ADR-6): it reads by SHAPE (two distinct bars) + a calm hue, not a neon stroke. Pure
# VISUAL in 2.1 (no Area2D — in-column player detection is Story 2.2; the column only shows where
# the capture WILL land). Pooled via Pool (low volume — at most one per active captor in 2.1).
#
# Lifecycle (owned by the captor): acquire on telegraph (activate → wind-up look) → intensify on
# capture (set_active_visual(true) — the active tractor) → release on dive/death/despawn (deactivate
# → Pool). Positioned at (locked_x, screen_center_y); the two bars sit at ±width_px/2 and span the
# full screen height. width_px is set by the captor from CaptorTuning.capture_column_width_px
# (geometry from tuning — AC#5) just before activate, so a retune of the column width needs no
# scene edit.

@onready var _bar_left: Polygon2D = $BarLeft
@onready var _bar_right: Polygon2D = $BarRight

# Set by the captor from tuning before activate (geometry from tuning). Default matches the tuning default.
var width_px: float = 60.0

# Wind-up (telegraph) vs active (capture) look — alpha only (no new nodes, no per-frame cost). D16
# hazard: the shape does the reading, the alpha sells the "winding up → live" beat.
const _WINDUP_ALPHA: float = 0.45
const _ACTIVE_ALPHA: float = 1.0


func activate(locked_x: float) -> void:
	# Lock position at (locked_x, screen-center y); lay out the two bars at ±width/2; show wind-up look.
	# The root sits at screen-center y so the baked full-height bars (local y ∈ ±360) cover the viewport.
	global_position = Vector2(locked_x, Constants.BASE_RESOLUTION.y * 0.5)
	var half_w: float = width_px * 0.5
	_bar_left.position.x = -half_w
	_bar_right.position.x = half_w
	visible = true
	set_active_visual(false)  # wind-up look on lock (intensifies when CaptureState goes active)


func set_active_visual(on: bool) -> void:
	# Wind-up (telegraph): dim bars — "winding up." Active (capture): solid bars — the tractor is live.
	var a: float = _ACTIVE_ALPHA if on else _WINDUP_ALPHA
	_bar_left.color.a = a
	_bar_right.color.a = a


func deactivate() -> void:
	# Hide (the captor releases us to the pool). Idempotent — safe on an already-hidden column.
	visible = false


func _release_to_pool() -> void:
	# No-arg deferred-release entry (mirrors Enemy._release_to_pool / Captor._release_to_pool). Godot
	# 4.6 fails to marshal a typed Node arg through call_deferred ("Cannot convert argument 1 from
	# Object to Object") — this affects Node2D too, not just PhysicsBody2D (the Story-2.1 gotcha's
	# "Node2D is unaffected" claim does not hold). The captor defers THIS parameterless method instead
	# of `Pool.release.call_deferred(self)`, sidestepping the arg conversion.
	Pool.release(self)
