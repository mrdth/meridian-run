class_name JuiceCoordinator
extends Node2D
# Arena-scoped juice conductor (Story 1.6 / AC1, AC2, AC5). Listens to the three EventBus juice
# REQUEST signals and drives its ScreenShake / HitFlash / pooled ParticleBurst children. Lives in
# arena.tscn — NOT an autoload (AR9): juice is run-scoped FEEL, so "auto-disabled in menus" (UX
# F8) is satisfied structurally (menu scenes never include this node). The 11-autoload registry is
# unchanged. Destroyed + recreated on game-over replay (clean).
#
# Safety caps (MAX_FLASH_HZ, MAX_SHAKE_PX) are immutable (Constants); this coordinator only FEEDS
# feel values (JuiceTuning) into its children and clamps incoming requests to those caps.

const PARTICLE_SCENE := preload("res://juice/particle_burst.tscn")
const SCORE_POPUP_SCENE := preload("res://juice/score_popup.tscn")

@export var tuning: JuiceTuning

@onready var _camera: Camera2D = $Camera2D
@onready var _shake: ScreenShake = $ScreenShake
@onready var _flash: HitFlash = $HitFlash

var _motion_scale: float = 1.0  # accessibility dampen (1.0 full / tuning.motion_scale_reduced)
var _logged_shake_clamp: bool = false  # fail-safe log spam guard (AR11) — mirrors spawner's pattern
# ONE reused burst-config dict (NFR3 — no per-event Dictionary.new(); mutated in place). The base
# profile is read from tuning (read-only); we copy the fields here and apply the per-event size scale.
var _profile_out: Dictionary = {}


func _ready() -> void:
	# AR11 fail-safe: an unassigned tuning falls back to defaults (the coordinator still works).
	# _ready runs once ⇒ this warn is naturally once.
	if tuning == null:
		tuning = JuiceTuning.new()
		Log.warn("juice", "JuiceCoordinator: tuning unassigned — using JuiceTuning defaults")
	# Wire the shake's camera + seed _motion_scale from current settings, then propagate.
	_shake.set_camera(_camera)
	_motion_scale = tuning.motion_scale_reduced if Settings.get_reduced_motion() else 1.0
	_shake.set_motion_scale(_motion_scale)
	_flash.set_motion_scale(_motion_scale)
	# Subscribe to juice requests (D8 — global feedback requests, imperative `_requested`).
	EventBus.screen_shake_requested.connect(_on_shake_requested)
	EventBus.hit_flash_requested.connect(_on_flash_requested)
	EventBus.particles_requested.connect(_on_particles_requested)
	EventBus.score_popup_requested.connect(_on_score_popup_requested)
	Settings.setting_changed.connect(_on_setting_changed)


func _on_shake_requested(amount: float, duration: float) -> void:
	# Clamp incoming amplitude to MAX_SHAKE_PX (immutable safety cap) before handing to the shake.
	# (Story 1.8 / deferred #2: warn when clamped so a miscalibrated tuning/_motion_scale is visible
	# in logs — matches the fail-safe-logging discipline of every other path. With the 1.8 retune the
	# normal player-hit shake stays under the cap, so this is silent in normal play — a genuine
	# tuning signal only when something exceeds it. Logged once per coordinator lifetime — same
	# spam guard as FormationSpawner._logged_missing_run_state — so a future mistuned multiplier
	# can't flood the log every frame it fires.)
	if amount > Constants.MAX_SHAKE_PX:
		if not _logged_shake_clamp:
			_logged_shake_clamp = true
			Log.warn("juice", "screen_shake_requested %.1f px exceeds MAX_SHAKE_PX %.1f — clamped" %
				[amount, Constants.MAX_SHAKE_PX])
	_shake.request(clampf(amount, 0.0, Constants.MAX_SHAKE_PX), duration)


func _on_flash_requested(target: Node2D, color: Color) -> void:
	# HitFlash applies its own central ≤3 Hz gate (unconditional) + the per-target tween. Duration
	# comes from tuning; HitFlash dampens it by _motion_scale internally.
	_flash.request(target, color, tuning.flash_duration)


func _on_particles_requested(effect: StringName, at: Vector2, color: Color, scale_arg: float) -> void:
	# Look up the (cached, read-only) base profile, copy into the reused _profile_out dict applying
	# the per-event size multiplier, acquire a pooled burst, parent it here (coordinator sits at arena
	# origin ⇒ child global_position == world position), and activate. Pool.acquire + add_child +
	# activate are all additive ⇒ safe even though this handler can run inside a physics callback.
	# _motion_scale dampens SPEED + SCALE (visual amplitude) under reduced motion — AC5 — count/
	# lifetime/spread/gravity are left alone so the burst is still clearly present, just calmer.
	var base: Dictionary = tuning.get_effect_profile(effect)
	_profile_out[&"amount"] = base[&"amount"]
	_profile_out[&"lifetime"] = base[&"lifetime"]
	_profile_out[&"spread_rad"] = base[&"spread_rad"]
	_profile_out[&"direction"] = base[&"direction"]
	_profile_out[&"speed"] = float(base[&"speed"]) * _motion_scale
	_profile_out[&"scale"] = float(base[&"scale"]) * scale_arg * _motion_scale
	_profile_out[&"gravity"] = base[&"gravity"]
	var burst: ParticleBurst = Pool.acquire(PARTICLE_SCENE) as ParticleBurst
	if burst == null:
		Log.err("juice", "JuiceCoordinator: acquired node is not a ParticleBurst — wrong scene?")
		return
	add_child(burst)  # host directly under the coordinator (at arena origin)
	burst.activate(effect, at, color, _profile_out)


func _on_score_popup_requested(at: Vector2, score_value: int) -> void:
	# Build the popup profile from tuning: `duration` = explosion_lifetime (literally "same speed as
	# the explosion"), and the scale RANGE + drift are dampened by _motion_scale (D14 — dampen motion
	# AMPLITUDE, never the duration/fade). A random drift vector within the drift radius gives the
	# "small directional shift on x & y". Pool.acquire + add_child + activate are all additive ⇒ safe
	# even though this handler can run inside a physics callback (mirrors _on_particles_requested).
	var scale_from: float = tuning.score_popup_scale_from
	var scale_range: float = (tuning.score_popup_scale_to - scale_from) * _motion_scale
	var profile: Dictionary = {
		&"duration": tuning.explosion_lifetime,
		&"scale_from": scale_from,
		&"scale_to": scale_from + scale_range,
		&"drift": _rand_drift(tuning.score_popup_drift_px * _motion_scale),
	}
	var popup: ScorePopup = Pool.acquire(SCORE_POPUP_SCENE) as ScorePopup
	if popup == null:
		Log.err("juice", "JuiceCoordinator: acquired node is not a ScorePopup — wrong scene?")
		return
	add_child(popup)  # host directly under the coordinator (at arena origin ⇒ child position == world)
	# "%+d" forces the sign: "+100" for a gain, and "-50" (not "+-50") if a negative ever reaches here.
	popup.activate("%+d" % score_value, at, tuning.score_popup_color, profile)


func _rand_drift(radius: float) -> Vector2:
	# Random point within `radius` (uniform-in-disc). Pure cosmetic — juice is NOT gameplay-deterministic
	# (ParticleBurst already uses non-deterministic GPU randomness), so the global randf is on-pattern
	# here, not a SeedManager sub-stream (those are for reproducible gameplay outcomes only).
	var angle: float = randf() * TAU
	return Vector2(cos(angle), sin(angle)) * (randf() * radius)


func _on_setting_changed(key: StringName, value: Variant) -> void:
	# Reduced-motion toggles the amplitude dampen (dampen, don't remove — D14). The ≤3 Hz cap is
	# NOT affected (it lives on HitFlash, unconditional).
	if key == Settings.REDUCED_MOTION_KEY:
		_motion_scale = tuning.motion_scale_reduced if bool(value) else 1.0
		_shake.set_motion_scale(_motion_scale)
		_flash.set_motion_scale(_motion_scale)
