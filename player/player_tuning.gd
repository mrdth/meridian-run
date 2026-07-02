class_name PlayerTuning
extends Resource
# Tuning for the player chassis — AR10 "tunable" tier. The `.tres` instance in
# resources/ is the playtest lever (retune feel with zero code). Schema `.gd`
# lives with the owning player/ domain per "schema with domain, .tres in resources/".

@export var move_speed: float = 320.0  # FR2 baseline; the chassis's central feel param.
@export var edge_margin: float = 24.0  # px kept inside the left/right play-field edges (clamp inset).
@export var lane_y: float = 680.0       # fixed bottom-lane Y (~40 px above the 720 bottom).
