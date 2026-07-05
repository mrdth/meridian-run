class_name HitFlash
extends Node
# Entity hit-flash + the SINGLE GLOBAL ≤3 Hz cadence gate (Story 1.6 / AC5 — the load-bearing
# photosensitive-safety invariant). A Node the JuiceCoordinator owns. Per the UX accessibility
# review, a per-emitter cap could let overlapping sources stack above 3 Hz aggregate, so this
# gate drops ANY hit_flash_requested that arrives within 1/MAX_FLASH_HZ of the last one —
# UNCONDITIONALLY (not gated by reduced_motion), and BEFORE _motion_scale. Reduced motion
# separately dampens the flash DURATION (the flash still happens, just snappier), never removes it.
#
# The flash is an ENTITY-sprite flash: it modulates the hit body so the visual child inherits it.
# A separate screen-flash is OUT of scope for E1 (deferred to E8) — if added later it MUST go
# through this same gate.

const MIN_INTERVAL_S: float = 1.0 / Constants.MAX_FLASH_HZ  # ~0.333 s at MAX_FLASH_HZ = 3.0

var _last_flash_time: float = -1000.0  # sentinel ⇒ the first request always passes the gate
var _motion_scale: float = 1.0
# One live tween per target — a rapid re-hit (after the gate) KILLS the previous tween on that
# target so it replaces instead of stacking. Plain Dictionary (Node2D -> Tween) for type safety.
var _tweens_by_target: Dictionary = {}
# Per-target cached ORIGINAL modulate (don't assume white) — restored when the tween lands.
var _original_modulate: Dictionary = {}


static func is_flash_allowed(last_time: float, now: float) -> bool:
	# Pure gate logic (separable for unit testing). Returns true iff enough time has elapsed since
	# the last allowed flash. Constants.MAX_FLASH_HZ is honored here — this is the safety test seam.
	return now - last_time >= MIN_INTERVAL_S


func set_motion_scale(scale: float) -> void:
	_motion_scale = clampf(scale, 0.0, 1.0)


func get_motion_scale() -> float:
	return _motion_scale


func request(target: Node2D, color: Color, duration: float) -> void:
	# AR11 fail-safe guards: an invalid or non-CanvasItem target can't be modulated — warn + return.
	if not is_instance_valid(target) or not (target is CanvasItem):
		Log.warn("hit_flash", "flash requested on an invalid/non-CanvasItem target — ignored")
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	# Central cadence gate — UNCONDITIONAL (photosensitive safety is not optional). Applied before
	# _motion_scale so reduced motion can never raise the aggregate flash rate above 3 Hz.
	if not is_flash_allowed(_last_flash_time, now):
		return
	_last_flash_time = now

	var ci: CanvasItem = target
	# Cache the original modulate once per target so the tween can restore it exactly.
	if not _original_modulate.has(ci):
		_original_modulate[ci] = ci.modulate
	var orig: Color = _original_modulate[ci]
	# Kill any live tween on this target so a rapid re-hit replaces rather than stacks.
	if _tweens_by_target.has(ci):
		var prev: Tween = _tweens_by_target[ci]
		if is_instance_valid(prev):
			prev.kill()
		_tweens_by_target.erase(ci)

	# Dampen the DURATION under reduced motion (flash still happens, just snappier) — never remove.
	var half_dur: float = maxf(duration * _motion_scale * 0.5, 0.001)
	var tween: Tween = get_tree().create_tween()
	# Two-phase flash: orig → color → orig over `duration` (a clean flash-up then fade-back).
	tween.tween_property(ci, "modulate", color, half_dur).set_trans(Tween.TRANS_SINE)
	tween.tween_property(ci, "modulate", orig, half_dur).set_trans(Tween.TRANS_SINE)
	_tweens_by_target[ci] = tween
	tween.finished.connect(_on_tween_finished.bind(ci))


func _on_tween_finished(target: CanvasItem) -> void:
	# The tween's final tween_property already lands on `orig`, so the modulate is restored.
	# Drop the cached entries so the dicts don't retain dead refs or grow unbounded across a run.
	_tweens_by_target.erase(target)
	_original_modulate.erase(target)
