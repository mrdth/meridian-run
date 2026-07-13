class_name JuiceTuning
extends Resource
# Data-driven FEEL knobs for the juice pass (Story 1.6 / AR10 "tunable" tier). The `.tres`
# instance in resources/ is the playtest lever — retune every shake/flash/particle value with
# zero code. Story 1.8 owns the final feel pass; these are starting values.
#
# IMMUTABLE safety caps (MAX_FLASH_HZ / MAX_SHAKE_PX) live in Constants — this file is FEEL
# only. Schema `.gd` lives with the owning juice/ domain; the `.tres` instance lives in
# resources/ (mirrors the player_tuning.gd + resources/player_tuning.tres pair from 1.2/1.5).

# --- Screen shake (px pre-_motion_scale; clamped to Constants.MAX_SHAKE_PX by the coordinator) ---
@export_group("Screen Shake")
@export var shake_enemy_hit_amount: float = 2.0   # player bullet hits enemy (sub-lethal)
@export var shake_enemy_hit_dur: float = 0.10
@export var shake_player_hit_amount: float = 6.0  # enemy bullet hits player (heavier — it's you)
@export var shake_player_hit_dur: float = 0.20
@export var shake_kill_amount: float = 4.0        # enemy killed
@export var shake_kill_dur: float = 0.15
@export var shake_heavy_mul: float = 1.5          # multiplier for Bomber/heavy hits (FR43 2 dmg)

# --- Hit flash (entity-sprite modulate; duration dampened by _motion_scale, never removed) ---
@export_group("Hit Flash")
@export var flash_enemy_color: Color = Color(0.85, 1.0, 1.0)   # near-white cyan (player-affiliated impact)
@export var flash_player_color: Color = Color(1.0, 0.45, 0.35) # hazard warm (player took damage)
@export var flash_duration: float = 0.08

# --- Particles (per-effect burst profiles; tint is caller-supplied via the signal) ---
@export_group("Particles")
@export_subgroup("Hit Spark")
@export var hit_spark_amount: int = 8
@export var hit_spark_lifetime: float = 0.30
@export var hit_spark_spread_rad: float = PI       # 180° — omnidirectional
@export var hit_spark_speed: float = 200.0
@export var hit_spark_scale: float = 0.7
@export var hit_spark_color: Color = Color(0.8, 1.0, 1.0)  # default; overridden by caller per faction

@export_subgroup("Explosion")
@export var explosion_amount: int = 18
@export var explosion_lifetime: float = 0.55
@export var explosion_spread_rad: float = PI
@export var explosion_speed: float = 280.0
@export var explosion_scale: float = 1.1
@export var explosion_color: Color = Color(1.0, 0.85, 0.55)

@export_subgroup("Muzzle")
@export var muzzle_amount: int = 5
@export var muzzle_lifetime: float = 0.12
@export var muzzle_spread_rad: float = PI * 0.25   # 45° upward cone
@export var muzzle_speed: float = 140.0
@export var muzzle_scale: float = 0.45
@export var muzzle_color: Color = Color(0.7, 1.0, 1.0)

@export_subgroup("Sacrifice Ignition")
# Story 2.6 (FR47/FR48) — the one-shot ignition burst for the sacrifice power-surge. A warm-amber blast
# (the "ignited" read) — distinct from explosion (enemy death) + muzzle (per-shot). The sustained on-ship
# glow + timer ring (Task 7) carry the readability; this is the single ignition sting at burst start.
@export var sacrifice_ignition_amount: int = 22
@export var sacrifice_ignition_lifetime: float = 0.50
@export var sacrifice_ignition_spread_rad: float = PI      # omnidirectional
@export var sacrifice_ignition_speed: float = 240.0
@export var sacrifice_ignition_scale: float = 1.2
@export var sacrifice_ignition_color: Color = Color(1.0, 0.85, 0.45, 1.0)  # warm amber ignition

@export_subgroup("Score Popup")
# Kill-juice floating "+N". Duration is NOT here — the coordinator sources it from `explosion_lifetime`
# so the popup literally matches the death blast's fade (the "same speed as the explosion" intent is
# structural, not a coincidental default). The coordinator dampens scale range + drift by
# `_motion_scale` under reduced motion (D14); duration/fade are left alone.
@export var score_popup_color: Color = Color("#FFE066")    # reward amber (= HudPalette.SCORE) — gold read
@export var score_popup_scale_from: float = 0.4   # tiny/distant start (zoom-toward-viewer)
@export var score_popup_scale_to: float = 5.0     # dramatic in-your-face peak — retune LIVE via the .tres (the runtime source of truth)
@export var score_popup_drift_px: float = 24.0    # random x/y offset radius over the popup's life

# --- Rescue (Story 2.3) ---
# The rescue pickup burst tint = {colors.dock} — hero neon. Provisional alias of HudPalette.PRIMARY
# (UX OQ3 — {colors.dock} is unresolved; kept in sync with DockedShipTuning.dock_color). The failed-
# rescue hazard sting reuses flash_player_color (no new knob); this is the rescue REWARD color only.
@export var rescue_color: Color = Color(0.0, 0.898, 1.0, 1.0)  # #00E5FF — hero neon (= HudPalette.PRIMARY placeholder).

# --- Motion (accessibility — D14) ---
@export_group("Motion")
# Dampen factor applied to shake/flash/particle AMPLITUDE when reduced_motion is on (dampen,
# don't remove). Architecture code literal = 0.3 (Q1 — dormant in E1 since reduced_motion
# defaults false). This is the _motion_scale the coordinator propagates to its children.
@export var motion_scale_reduced: float = 0.3

# Lazily-built profile caches (read-only contract: callers MUST treat these as immutable —
# the coordinator copies into its own reused dict before applying the per-event size scale).
var _profiles: Dictionary = {}


func get_effect_profile(effect: StringName) -> Dictionary:
	# Returns the cached profile dict for a particle effect (&"hit_spark" / &"explosion" /
	# &"muzzle"). Built once on first access; subsequent calls return the same dict reference.
	# Fail-safe (AR11): an unknown effect falls back to hit_spark rather than crashing.
	if _profiles.has(effect):
		return _profiles[effect]
	var profile: Dictionary
	match effect:
		&"explosion":
			profile = _build_explosion()
		&"muzzle":
			profile = _build_muzzle()
		&"sacrifice_ignition":
			profile = _build_sacrifice_ignition()
		_:
			profile = _build_hit_spark()  # &"hit_spark" and any unknown effect
	_profiles[effect] = profile
	return profile


func get_motion_scale_reduced() -> float:
	return motion_scale_reduced


func _build_hit_spark() -> Dictionary:
	return {
		&"amount": hit_spark_amount,
		&"lifetime": hit_spark_lifetime,
		&"spread_rad": hit_spark_spread_rad,
		&"speed": hit_spark_speed,
		&"scale": hit_spark_scale,
		&"color": hit_spark_color,
		&"direction": Vector3(0.0, -1.0, 0.0),
		&"gravity": Vector3.ZERO,
	}


func _build_explosion() -> Dictionary:
	return {
		&"amount": explosion_amount,
		&"lifetime": explosion_lifetime,
		&"spread_rad": explosion_spread_rad,
		&"speed": explosion_speed,
		&"scale": explosion_scale,
		&"color": explosion_color,
		&"direction": Vector3(0.0, -1.0, 0.0),
		&"gravity": Vector3.ZERO,
	}


func _build_muzzle() -> Dictionary:
	return {
		&"amount": muzzle_amount,
		&"lifetime": muzzle_lifetime,
		&"spread_rad": muzzle_spread_rad,
		&"speed": muzzle_speed,
		&"scale": muzzle_scale,
		&"color": muzzle_color,
		&"direction": Vector3(0.0, -1.0, 0.0),  # upward (player fires up)
		&"gravity": Vector3.ZERO,
	}


func _build_sacrifice_ignition() -> Dictionary:
	# Story 2.6 — the sacrifice-burst ignition profile. Omnidirectional warm-amber blast (the "ignited"
	# power-surge read). Same dict shape as the other profiles (the coordinator copies it into its reused
	# _profile_out + applies the per-event scale + _motion_scale).
	return {
		&"amount": sacrifice_ignition_amount,
		&"lifetime": sacrifice_ignition_lifetime,
		&"spread_rad": sacrifice_ignition_spread_rad,
		&"speed": sacrifice_ignition_speed,
		&"scale": sacrifice_ignition_scale,
		&"color": sacrifice_ignition_color,
		&"direction": Vector3(0.0, -1.0, 0.0),
		&"gravity": Vector3.ZERO,
	}
