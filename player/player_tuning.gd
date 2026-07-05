class_name PlayerTuning
extends Resource
# Tuning for the player chassis — AR10 "tunable" tier. The `.tres` instance in
# resources/ is the playtest lever (retune feel with zero code). Schema `.gd`
# lives with the owning player/ domain per "schema with domain, .tres in resources/".

# --- Movement chassis (1.2) ---
@export var move_speed: float = 320.0  # FR2 baseline; the chassis's central feel param.
@export var edge_margin: float = 24.0  # px kept inside the left/right play-field edges (clamp inset).
@export var lane_y: float = 680.0       # fixed bottom-lane Y (~40 px above the 720 bottom).

# --- Vertical fire (1.3 — FR5 baselines, all data-driven) ---
@export var fire_cooldown: float = 0.16      # seconds between shots (hold-to-autofire; ~6.25 shots/s).
@export var bullet_speed: float = 620.0      # px/s straight up (vertical fire-column).
@export var projectile_damage: int = 10      # base player shot damage.
@export var muzzle_offset_y: float = -20.0   # local Y of the Muzzle marker (ship nose).

# --- Life economy (1.5 — FR11/GDD 108: "i-frames 1 s after each hit") ---
@export var iframe_s: float = 1.0            # i-frame window granted after a damaging hit / on respawn.
