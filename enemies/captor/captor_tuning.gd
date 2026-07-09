class_name CaptorTuning
extends Resource
# Data definition for the Captor's 5-state FSM + captor-specific geometry/feel — AR10 "tunable"
# tier, D9 content. The `.tres` INSTANCE lives in resources/ (flat, matching player_tuning.tres /
# juice_tuning.tres); this schema lives with the owning enemies/captor/ domain (arch: resource
# schema scripts live with their domain, only .tres instances live in resources/).
#
# Holds the FSM DURATIONS + captor-only geometry (formation row, dive track, capture-column width).
# Base combat stats (HP, fire, movement, score) live on the EnemyDefinition (resources/enemies/
# enemy_captor.tres) — the captor holds BOTH: `definition` (EnemyDefinition) + `tuning` (this).
#
# **The `.tres` overrides these `.gd` defaults at runtime** (the @export defaults are inert — they
# only document the GDD baseline). Always set real values in resources/captor_tuning.tres.
# (Gotcha: editing the .gd defaults alone has no runtime effect — see project memory.)

@export_group("FSM Durations")
# The 5 FSM state durations — ALL read from this resource (AC#5 "data, not code").
@export var enter_duration_s: float = 1.0          # off-screen descend to the formation row (AC#1).
@export var formation_duration_min_s: float = 3.5  # randomized per-spawn hold (AC#2: 3.5–5.5 s).
@export var formation_duration_max_s: float = 5.5
@export var telegraph_duration_s: float = 0.7      # the fair dodge window — column locks to player x (AC#3).
@export var capture_duration_s: float = 0.4        # active tractor (AC#4; the capture EFFECT is Story 2.2).
@export var dive_duration_s: float = 1.6           # bezier toward the player then off-screen (AC#4).

@export_group("Formation")
@export var formation_row_y: float = 150.0          # the row the captor descends to (the captor's own row).
@export var side_drift_amplitude_px: float = 130.0  # ±drift around the formation anchor x (matches standard.tres feel).
@export var side_drift_period_s: float = 3.0        # sine drift period.

@export_group("Dive")
# Reuses the grunt DiveState aim idiom: capture the player's x ONCE at dive-start, then blend toward
# the LIVE player x by dive_aim_track_factor (0 = pure once-capture, 1 = continuous tracking).
@export var dive_aim_track_factor: float = 0.3      # match standard.tres feel.
@export var dive_offscreen_margin_px: float = 48.0  # past the bottom edge → release to pool (one pass).

@export_group("Capture Column")
# The parallel-bars hazard span (world/capture_column.tscn). Hazard family → no bright outline (D16/ADR-6);
# the column reads by SHAPE only — distinct silhouette, not a neon outline.
@export var capture_column_width_px: float = 60.0   # parallel-bars span (±width/2 from the locked x).
