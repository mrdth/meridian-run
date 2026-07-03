class_name EnterState
extends State
# Enemy flies from off-screen-above its slot to the slot along entry_curve (RELATIVE to the
# slot). **Speed-based traversal** (faster variants enter faster — preserves GDD move_speed
# differentiation) + **exact tracking** (velocity = (target - pos) / delta; with collision_mask=0
# the body snaps to the sampled point each frame — NO pursuit lag, the v1 defect). Fire is
# disarmed here (enemies fire only in formation/dive). On completion → FormationState.
#
# Re-entered after every dive (the Galaga loop): DiveState off-screen-bottom → here →
# Formation → Dive → …, releasing to the Pool ONLY on death.

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
	# Spawn/re-enter at the curve start (off-screen above the slot) — one-time positioning, not
	# a per-frame .position write (AR14 allows one-time spawn placement).
	_enemy.global_position = _enemy.slot_world_pos + curve.sample_baked(0.0)
	# No firing while (re-)entering — FormationState arms fire once the enemy is in the grid.
	_enemy.disarm_fire()


func physics_process(delta: float) -> void:
	if _enemy == null or _enemy.formation_def == null or delta <= 0.0 or _baked_length <= 0.0:
		return
	var curve: Curve2D = _enemy.formation_def.entry_curve
	# Advance t by actual movement (speed-based traversal — variants differ in entry speed).
	_t += (_enemy.definition.move_speed * delta) / _baked_length
	var u: float = minf(_t, 1.0)
	# Curve is relative to the slot → add slot_world_pos (per-enemy offset; the shared curve is
	# NEVER mutated). Sample by baked distance for an even path.
	var target: Vector2 = _enemy.slot_world_pos + curve.sample_baked(u * _baked_length)
	# Exact tracking: move_and_slide translates by velocity*delta; velocity = (target-pos)/delta
	# cancels delta → the body lands on the sampled point. Frame-rate independent, no lag.
	_enemy.velocity = (target - _enemy.global_position) / delta
	_enemy.move_and_slide()
	if _t >= 1.0:
		_enemy.to_formation()
