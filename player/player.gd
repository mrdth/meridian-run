class_name Player
extends CharacterBody2D
# 1-axis chassis: horizontal-only, screen-clamped movement on the bottom lane.
# Velocity + move_and_slide() (fixed-timestep _physics_process) is the PRIMARY
# driver; the post-move clampf only corrects edge escape (no physical walls).
#
# Per-ship mechanics (WAVE scope — Story 1.5): the player owns HP, i-frames, and the
# ship_depleted signal (intra-entity→parent, D8). Run-scope decisions (ship count,
# game-over) live on Arena — the player never touches RunState (AR2). Movement and
# ship_depleted both stay LOCAL — the player emits nothing to EventBus directly.

@export var tuning: PlayerTuning

@onready var _health: HealthComponent = $HealthComponent
@onready var _faction: FactionComponent = $FactionComponent
@onready var _fire_system: FireSystem = $FireSystem
@onready var _muzzle: Marker2D = $Muzzle
@onready var _visual: Polygon2D = $Visual

# Player → Arena: "I lost a ship (HP hit 0 within the wave)." NO payload — the run host
# owns the count and decides respawn vs game-over (D8: intra-entity→parent, direct).
signal ship_depleted()

var _min_x: float = 0.0
var _max_x: float = 0.0
var _flicker_t: float = 0.0  # i-frame flicker phase (placeholder; Story 1.6 owns the juice pass).


func _ready() -> void:
	assert(tuning != null, "Player: tuning not assigned")
	# Dev-invariant (AR12): the ship's HP cap must never exceed Constants.MAX_HP (grows
	# via build in E3, always 3 in E1). Scoped to the player only — HealthComponent is
	# shared with enemies, whose max_hp values are unrelated to the player's run-wide cap.
	assert(_health.max_hp <= Constants.MAX_HP, "Player: max_hp exceeds Constants.MAX_HP cap")
	# FactionComponent is the single source of truth for the collision-layer bit (AR5).
	collision_layer = _faction.get_collision_layer()
	# Compute + cache bounds once (hot-path: no per-frame work in _physics_process).
	_min_x = tuning.edge_margin
	_max_x = float(Constants.BASE_RESOLUTION.x) - tuning.edge_margin
	assert(_min_x <= _max_x, "Player: edge_margin leaves no room to move")
	global_position = Vector2(Constants.BASE_RESOLUTION.x / 2.0, tuning.lane_y)
	# Muzzle position is tuning-driven, not the scene's hardcoded default (the .tscn
	# value is just an editor preview) — this is the one-time (not per-frame) spawn
	# math that makes muzzle_offset_y an actual playtest lever (AR10).
	_muzzle.position.y = tuning.muzzle_offset_y
	# i-frame gate (Story 1.5 / AC2): the HealthComponent is the damage gate, so the
	# window lives there; the player just feeds its tuning value (GDD 108: 1 s after a
	# hit). Default 0.0 on the component keeps enemies i-frame-free — the player opts in.
	_health.invuln_after_hit_s = tuning.iframe_s
	# Connect HP=0 (within a wave) → ship_depleted ONCE (the player is NOT pooled, so no
	# re-connect concern across the run). died is a LOCAL HealthComponent signal (D8).
	if not _health.died.is_connected(_on_ship_depleted):
		_health.died.connect(_on_ship_depleted)
	# Wire FireSystem's world-space projectile container to our parent (the Arena).
	# Projectiles parent there — NOT under the Player — so they don't inherit the
	# ship's transform (Decision #8). FireSystem._ready ran before ours (children
	# first), but projectile_parent is read only on fire, never in FireSystem._ready,
	# so there is no race. The Player wires its own component (intra-entity, D8-clean).
	if _fire_system != null and _fire_system.projectile_parent == null:
		_fire_system.projectile_parent = get_parent()


func _process(delta: float) -> void:
	# Minimal i-frame VISIBILITY (Story 1.5 placeholder so i-frames are testable). Story
	# 1.6 ("Hit Feedback & Juice") owns the polished presentation (hit-flash, shake,
	# particles via JuiceCoordinator). One cheap flicker line while invulnerable; nothing
	# per-frame while vulnerable (NFR2/AR14).
	if _health.is_invulnerable():
		_flicker_t += delta
		_visual.modulate.a = 0.5 + 0.5 * sin(_flicker_t * 30.0)
	else:
		_visual.modulate.a = 1.0


func _on_ship_depleted() -> void:
	# HP reached 0 within the wave → tell the run host. The Arena decides respawn vs
	# game-over (AR2: ships are run-scope). Player never calls RunState directly.
	ship_depleted.emit()


func respawn() -> void:
	# Called by Arena when a ship is lost but ships remain. New ship, full HP, centered
	# on the lane (fair re-entry — a fire-column probably killed you where you stood),
	# and a fresh i-frame window so re-entry isn't an instant re-death. No screen-clear,
	# no loss-of-control, no fade — E1 respawn is immediate (full lifecycle is 1.8).
	_health.reset_to_full()
	global_position.x = Constants.BASE_RESOLUTION.x / 2.0
	velocity = Vector2.ZERO  # defensive: _physics_process recomputes velocity from input
	# every frame regardless, but a teleport shouldn't carry a stale pre-death velocity.
	_health.set_invuln(tuning.iframe_s)


func _physics_process(_delta: float) -> void:
	# One call covers keyboard (digital -1/0/1) AND gamepad (continuous -1..1 with
	# the per-action deadzone applied automatically) — AC3.
	var axis: float = Input.get_axis("move_left", "move_right")
	# Velocity set directly; y explicitly 0 (1-axis lock). Do NOT multiply by delta
	# — move_and_slide() applies it internally (AC2, AR14).
	velocity = Vector2(axis * tuning.move_speed, 0.0)
	move_and_slide()  # no args; Godot applies delta internally.
	# Corrective screen-clamp to the base-resolution play field (AC1, Decision #2).
	global_position.x = clampf(global_position.x, _min_x, _max_x)
