class_name CaptureColumn
extends Node2D
# The captor's locked tractor-beam column (Story 2.1). A parallel-bars hazard visual — two thin
# vertical bars spanning the screen, centered on the captor's locked x. Hazard family → NO bright
# outline (D16/ADR-6): it reads by SHAPE (two distinct bars) + a calm hue, not a neon stroke.
#
# Story 2.1 made this PURE VISUAL (the column only shows where the capture will land). Story 2.2 adds
# an invisible Area2D "CaptureDetector" child — an overlap-POLL (is_player_in_column) that reports
# whether a clean player is inside the locked column during the 0.4 s active window, so the captor's
# CaptureState can fire the capture effect. Detection is OFF outside that window (telegraph/dive/pool).
# Pooled via Pool (low volume — at most one per active captor).
#
# Lifecycle (owned by the captor): acquire on telegraph (activate → wind-up look, detection OFF) →
# intensify on capture (set_active_visual(true) — the active tractor) → release on dive/death/despawn
# (deactivate → Pool). Positioned at (locked_x, screen_center_y); the two bars sit at ±width_px/2 and
# span the full screen height. width_px is set by the captor from CaptorTuning.capture_column_width_px
# (geometry from tuning — AC#5) just before activate, so a retune of the column width needs no
# scene edit.

@onready var _bar_left: Polygon2D = $BarLeft
@onready var _bar_right: Polygon2D = $BarRight
# The capture-effect detector (Story 2.2). Detects the player body on LAYER_PLAYER (mask); it is NOT
# detected itself (collision_layer 0 — mirrors hurtbox_component.gd:24-26). monitoring stays OFF until
# set_detection(true) (called by CaptureState.enter for the active window only).
@onready var _detector: Area2D = $CaptureDetector
@onready var _detector_shape: CollisionShape2D = $CaptureDetector/CollisionShape2D

# Set by the captor from tuning before activate (geometry from tuning). Default matches the tuning default.
var width_px: float = 60.0

# Wind-up (telegraph) vs active (capture) look — alpha only (no new nodes, no per-frame cost). D16
# hazard: the shape does the reading, the alpha sells the "winding up → live" beat.
const _WINDUP_ALPHA: float = 0.45
const _ACTIVE_ALPHA: float = 1.0


func _ready() -> void:
	# Detect the player body on LAYER_PLAYER (mask). collision_layer 0 — the detector DETECTS, it isn't
	# detected (mirrors hurtbox_component.gd:24-26). monitoring OFF until set_detection(true) — the
	# telegraph is a wind-up, not a capture. Runs ONCE (pooled nodes re-init via activate, never here).
	if _detector != null:
		_detector.collision_layer = 0
		_detector.collision_mask = Constants.LAYER_PLAYER
		_detector.monitoring = false


func activate(locked_x: float) -> void:
	# Lock position at (locked_x, screen-center y); lay out the two bars at ±width/2; show wind-up look.
	# The root sits at screen-center y so the baked full-height bars (local y ∈ ±360) cover the viewport.
	global_position = Vector2(locked_x, Constants.BASE_RESOLUTION.y * 0.5)
	var half_w: float = width_px * 0.5
	_bar_left.position.x = -half_w
	_bar_right.position.x = half_w
	# Resize the detector to match the column width (geometry from tuning — AC#5). duplicate() the shared
	# RectangleShape2D first so per-instance sizing never races on the pooled shared resource (same idiom
	# as captor.gd:62-66's collision shape).
	if _detector_shape != null:
		var shape := _detector_shape.shape as RectangleShape2D
		if shape != null:
			var dup := shape.duplicate() as RectangleShape2D
			dup.size = Vector2(width_px, float(Constants.BASE_RESOLUTION.y))
			_detector_shape.shape = dup
	visible = true
	set_active_visual(false)  # wind-up look on lock (intensifies when CaptureState goes active)
	set_detection(false)  # wind-up: detection OFF in telegraph (capture is the 0.4 s window only)


func set_active_visual(on: bool) -> void:
	# Wind-up (telegraph): dim bars — "winding up." Active (capture): solid bars — the tractor is live.
	var a: float = _ACTIVE_ALPHA if on else _WINDUP_ALPHA
	_bar_left.color.a = a
	_bar_right.color.a = a


func set_detection(on: bool) -> void:
	# Toggle the detector's monitoring. ON only during the active capture window (CaptureState.enter);
	# OFF otherwise (telegraph, dive, idle in pool). A released/pooled column must never carry stale
	# monitoring from a prior telegraph (see Dev Notes §"Stale-monitoring gotcha").
	if _detector != null:
		_detector.monitoring = on


func is_player_in_column() -> bool:
	# Overlap-POLL (not body_entered). The player is usually already inside the column at window start
	# (the column locks to the player's x at telegraph), so body_entered's enter-transition never fires.
	# Only the player is on LAYER_PLAYER, so any overlapping body IS the player. Reads the physics
	# server's last overlap update (needs monitoring=true + a physics tick to have run).
	if _detector == null or not _detector.monitoring:
		return false
	return _detector.has_overlapping_bodies()


func deactivate() -> void:
	# Hide (the captor releases us to the pool). Idempotent — safe on an already-hidden column.
	set_detection(false)  # a released/pooled column must never carry stale monitoring
	visible = false


func _release_to_pool() -> void:
	# No-arg deferred-release entry (mirrors Enemy._release_to_pool / Captor._release_to_pool). Godot
	# 4.6 fails to marshal a typed Node arg through call_deferred ("Cannot convert argument 1 from
	# Object to Object") — this affects Node2D too, not just PhysicsBody2D (the Story-2.1 gotcha's
	# "Node2D is unaffected" claim does not hold). The captor defers THIS parameterless method instead
	# of `Pool.release.call_deferred(self)`, sidestepping the arg conversion.
	Pool.release(self)
