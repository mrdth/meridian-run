class_name EnemyDefinition
extends Resource
# Data definition for a Grunt/Shielder/Bomber enemy — AR10 "tunable" tier, D9 content.
# The `.tres` instances live in resources/enemies/ (id-indexed by ContentRegistry); this
# schema lives with the owning enemies/ domain. Adding an enemy = add a `.tres`, zero code.
#
# Holds STATS ONLY (hp, damage, shot_kind, speeds). The projectile SCENE lives on
# EnemyFireSystem (mirrors player/fire_system.gd), NOT here — stats vs scenes split.

enum ShotKind { STANDARD, HEAVY }  # HEAVY = telegraphed, Bomber-only.

@export_group("Identity")
@export var id: StringName           # registry key ("grunt" / "shielder" / "bomber").
@export var formation_id: StringName = &"standard"  # which FormationDefinition this enemy uses.

@export_group("Combat")
@export var max_hp: int = 30         # Grunt 30 / Shielder 50 / Bomber 80 (FR43).
@export var score_value: int = 100   # Grunt 100 / Shielder 150 / Bomber 300 (FR43).
@export var collision_radius: float = 14.0  # CircleShape2D radius (~12–18 px).

@export_group("Fire")
@export var fire_damage: int = 1     # Grunt/Shielder 1 / Bomber 2 (GDD damage model).
@export var shot_kind: ShotKind = ShotKind.STANDARD  # Bomber = HEAVY (telegraphed pellet).
@export var fire_interval_min_s: float = 1.2  # Grunt 1.2 / Shielder 0.9 / Bomber 1.6 (FR43).
@export var fire_interval_max_s: float = 2.4  # Grunt 2.4 / Shielder 1.8 / Bomber 2.8 (FR43).
@export var projectile_speed: float = 280.0   # SLOWER than player's 620 — dodgeable (Task 4.3).
@export var heavy_windup_s: float = 0.0       # Bomber telegraph windup; 0 for Grunt/Shielder.
@export var fires_during_dive: bool = true    # Galaga-lineage default.

@export_group("Movement")
@export var move_speed: float = 60.0          # Grunt 60 / Shielder 50 / Bomber 80 (FR43).
@export var dive_speed_multiplier: float = 2.0  # multiplies move_speed during dive (data-tunable).

@export_group("Visual")
@export var silhouette_color: Color = Color(1.0, 0.24, 0.35)  # hazard calm #FF3D5A default.
@export var silhouette_scale: float = 1.0  # Polygon2D scale = visual size (collision_radius is the hitbox; bump both to grow an enemy).
