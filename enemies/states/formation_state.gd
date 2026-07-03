class_name FormationState
extends State
# Holds the formation slot with side-to-side drift (Galaga-lineage), arms the fire system,
# and after formation_hold_s transitions to DiveState. Drift is a sine offset around the
# slot; the enemy pursues slot+drift at move_speed (pulls in any residual entry lag).

var _enemy: Enemy
var _hold_t: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_enemy = owner as Enemy
	_hold_t = 0.0
	if _enemy == null or _enemy.formation_def == null or _enemy.definition == null:
		return
	# Arm fire only once in formation (never during Enter). arm() delays the first shot by a
	# random interval.
	_enemy.arm_fire()


func physics_process(delta: float) -> void:
	if _enemy == null or _enemy.formation_def == null or _enemy.definition == null:
		return
	var form: FormationDefinition = _enemy.formation_def
	_hold_t += delta
	# Side-to-side drift anchored to the slot (sine of elapsed time over the drift period).
	var drift_x: float = sin((_hold_t / form.side_drift_period_s) * TAU) * form.side_drift_amplitude_px
	var target: Vector2 = _enemy.slot_world_pos + Vector2(drift_x, 0.0)
	_enemy.velocity = (target - _enemy.global_position).normalized() * _enemy.definition.move_speed
	_enemy.move_and_slide()
	if _hold_t >= form.formation_hold_s:
		_enemy.to_dive()
