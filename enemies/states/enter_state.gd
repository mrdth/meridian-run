class_name EnterState
extends State
# Enemy flies from off-screen-above its slot to the slot along entry_curve (RELATIVE to
# the slot). Advances parametric t over entry_duration_s and pursues the sampled point at
# move_speed (Dev Notes §"Movement"). On completion → FormationState (which corrects any
# residual pursuit lag by pulling toward the slot + drift).

var _enemy: Enemy
var _t: float = 0.0
var _baked_length: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_enemy = owner as Enemy
	_t = 0.0
	# Defensive: StateMachine._ready calls enter() once before activate() sets formation_def
	# (first acquire). No-op until activate re-enters us with per-spawn data.
	if _enemy == null or _enemy.formation_def == null or _enemy.formation_def.entry_curve == null:
		return
	var curve: Curve2D = _enemy.formation_def.entry_curve
	_baked_length = curve.get_baked_length()
	# Spawn at the entry-curve start (off-screen above the slot) — one-time positioning, not
	# a per-frame .position write (AR14 allows one-time spawn placement).
	_enemy.global_position = _enemy.slot_world_pos + curve.sample_baked(0.0)


func physics_process(delta: float) -> void:
	if _enemy == null or _enemy.formation_def == null:
		return
	var curve: Curve2D = _enemy.formation_def.entry_curve
	_t += delta
	var u: float = clampf(_t / _enemy.formation_def.entry_duration_s, 0.0, 1.0)
	# Curve is relative to the slot → add slot_world_pos (per-enemy offset, shared curve
	# NEVER mutated). Sample by baked distance for an even path.
	var target: Vector2 = _enemy.slot_world_pos + curve.sample_baked(u * _baked_length)
	_enemy.velocity = (target - _enemy.global_position).normalized() * _enemy.definition.move_speed
	_enemy.move_and_slide()
	if u >= 1.0:
		_enemy.to_formation()
