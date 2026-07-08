class_name FormationDefinition
extends Resource
# Data-driven formation + dive choreography (D9). One FormationDefinition serves EVERY
# slot: entry_curve/dive_curve are RELATIVE to the slot origin, so each enemy adds its own
# slot_world_pos (and a per-enemy player-aim x on dive) to the sampled point at read time.
# The shared Curve2D resources are NEVER mutated — mutating them corrupts every enemy
# sharing the curve (Dev Notes §"Movement"). Adding a formation = add a .tres in
# resources/formations/, zero code.

@export var id: StringName = &"standard"  # ContentRegistry key (EnemyDefinition.formation_id).

@export_group("Slots")
@export var slots: Array[Vector2] = []  # absolute world positions of the formation grid.

@export_group("Curves")
@export var entry_curve: Curve2D  # relative: off-screen-above the slot → slot origin (0,0).
@export var dive_curve: Curve2D   # relative: slot origin (0,0) → off-screen-below (+y).

@export_group("Dive")
# 0 = classic Galaga: aim captured ONCE at dive-start (bends toward where the player was).
# 1 = continuously re-aim at the player's LIVE x each frame (a diver follows a player who
# relocates to / camps a screen edge after dive-start). Blended between the two per-frame.
# Anti-camp lever: the core coverage fix is formation fire (slots + drift); this makes dives
# feel responsive rather than dumb against a moving target.
@export var dive_aim_track_factor: float = 0.0

@export_group("Timing")
@export var entry_duration_s: float = 1.5  # fly-in duration (curve traversal budget).
@export var dive_duration_s: float = 2.0   # dive duration.
@export var formation_hold_s: float = 4.0  # time in formation before diving (3.5–5.5 band).

@export_group("Drift")
@export var side_drift_amplitude_px: float = 24.0  # side-to-side drift magnitude (Galaga-lineage).
@export var side_drift_period_s: float = 3.0       # drift oscillation period.

@export_group("Sweep")
# Edge-sweep attack (SweepState) — a periodic full-width strafing run that rakes straight-down
# fire across BOTH screen corners, denying edge-camping. Straight-down formation fire alone is
# luck-dependent at the edges (a corner camper is hit only while an enemy is directly overhead),
# so sweeps guarantee corner coverage every run. See decision-log [Sweep-state].
@export var sweep_chance: float = 0.0  # P(a formation-hold expiry triggers a sweep instead of a dive). 0 = dives-only (legacy).
@export var sweep_y: float = 430.0     # world Y the sweeper holds while traversing (above the player lane at y=680).
