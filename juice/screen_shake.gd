class_name ScreenShake
extends Node
# Trauma-style 2D screen shake (Story 1.6 / AC1). A Node the JuiceCoordinator owns; it drives
# the arena Camera2D's `offset` directly (smoothing is OFF on that camera, so the offset isn't
# fought by the engine). request() accumulates trauma; _process() decays it and writes a random
# unit-direction offset scaled by trauma² · MAX_SHAKE_PX · _motion_scale. Idle ⇒ offset zeroed
# and processing disabled (NFR2/AR14 — zero cost when nothing is shaking).
#
# Squared trauma = the classic punchy decay (Squirrel screen-shake). The offset is a UNIT random
# vector scaled by amplitude, so its magnitude never exceeds MAX_SHAKE_PX regardless of direction.

const _MAX_TRAUMA: float = 1.0

var _camera: Camera2D
var _trauma: float = 0.0
# Local delta-accumulated clock (NOT wall-clock — keeps manual `_process(delta)` test-stepping
# deterministic, matching this project's GUT convention). `_decay_end_time` is the `_elapsed`
# value at which trauma should reach zero; a request only ever PUSHES it further out (never pulls
# it in), so a short/small hit landing while a bigger/longer shake is still decaying doesn't
# truncate that shake's tail (a naive `trauma / this_request's_duration` decay rate would let a
# tiny graze wipe out a big kill-shake almost instantly).
var _elapsed: float = 0.0
var _decay_end_time: float = 0.0
var _motion_scale: float = 1.0     # accessibility dampen (0.3 reduced / 1.0 full); dampen, don't remove

# One reused offset vector (NFR3 — no per-frame Vector2 alloc) + a seeded RNG (project default,
# NFR10; shake is cosmetic but a seeded RNG keeps runs reproducible-leaning).
var _offset := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 0xC0FFEE
	set_process(false)  # idle until a request arrives


func set_camera(camera: Camera2D) -> void:
	_camera = camera


func set_motion_scale(scale: float) -> void:
	_motion_scale = clampf(scale, 0.0, 1.0)


func get_motion_scale() -> float:
	return _motion_scale


func get_trauma() -> float:
	return _trauma


func request(amount: float, duration: float) -> void:
	# `amount` is pre-_motion_scale px severity; normalize to a [0..1] trauma bump clamped to 1.0.
	# Multiple near-simultaneous requests ADD (a kill + a player-hit in the same frame shakes harder).
	var bump: float = clampf(amount / Constants.MAX_SHAKE_PX, 0.0, _MAX_TRAUMA)
	_trauma = clampf(_trauma + bump, 0.0, _MAX_TRAUMA)
	# Extend (never shorten) the decay deadline — the longest-pending request governs the tail, so a
	# small quick hit landing mid-decay can't truncate a bigger shake already in flight.
	var safe_dur: float = maxf(duration, 0.001)
	_decay_end_time = maxf(_decay_end_time, _elapsed + safe_dur)
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	var remaining: float = maxf(_decay_end_time - _elapsed, 0.001)
	var decay_rate: float = _trauma / remaining
	_trauma = maxf(_trauma - decay_rate * delta, 0.0)
	if _trauma <= 0.0:
		_offset = Vector2.ZERO
		_apply_offset()
		set_process(false)
		return
	# Squared trauma ⇒ punchy decay. Unit random direction keeps |offset| == amp (≤ MAX_SHAKE_PX).
	var amp: float = _trauma * _trauma * Constants.MAX_SHAKE_PX * _motion_scale
	var rx: float = _rng.randf() * 2.0 - 1.0
	var ry: float = _rng.randf() * 2.0 - 1.0
	var len_sq: float = rx * rx + ry * ry
	if len_sq > 0.0:
		var inv: float = amp / sqrt(len_sq)
		_offset.x = rx * inv
		_offset.y = ry * inv
	else:
		_offset.x = 0.0
		_offset.y = 0.0
	_apply_offset()


func _apply_offset() -> void:
	# Null-safe (testable without a camera); the coordinator wires a real Camera2D in _ready.
	if _camera != null:
		_camera.offset = _offset
