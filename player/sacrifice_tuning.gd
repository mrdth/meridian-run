class_name SacrificeTuning
extends Resource
# Story 2.6 — NP3 tuning for the sacrifice burst (AR10/D9). The `.tres` INSTANCE in resources/
# overrides these @export defaults at runtime — editing the `.gd` defaults alone has NO runtime
# effect (memory tres-overrides-gd-default-for-tuning). Set real values in
# resources/sacrifice_tuning.tres. Schema lives with the owning player/ domain (only the .tres
# instance lives in resources/, mirroring captor_tuning.gd / player_tuning.gd).
#
# Mirrors the CaptorTuning schema pattern: @export_group'd knobs, .gd documents the GDD baseline,
# the .tres is the runtime/playtest source of truth.

@export_group("Scaling (NP3)")
@export var base_power: float = 1.0           # sacrifice power at wing_level 0 (→ ×1.5 damage baseline, AC1).
@export var power_per_wing: float = 0.3       # raw power added per WING-track level (investment reward).
@export var max_threat_fraction: float = 0.02 # clamp: capped = min(raw, threat * this). PLAYTEST-TUNED dial — see Dev Notes §"⚠️ max_threat_fraction calibration".

@export_group("Burst Shape (FR19)")
@export var duration: float = 10.0            # ~10 s buff window (AC1).
@export var burst_damage_base: float = 1.5    # ×1.5 at power=1.0 (AC1); scales via BuildRecompute.burst_damage_mult.
@export var burst_fire_cooldown: float = 0.10 # fast-fire 0.10 s (AC1).
@export var burst_spread_rad: float = 0.18    # triple-shot ±0.18 rad (AC1).
@export var burst_shot_count: int = 3         # triple-shot (AC1).
