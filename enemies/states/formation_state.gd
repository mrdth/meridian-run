class_name FormationState
extends State
# Holds the formation slot with side-to-side drift (Galaga-lineage), arms the fire system,
# then after a **per-enemy randomized** formation hold transitions to DiveState. The ±25% hold
# variance STAGGERS dives so enemies peel off one/few-at-a-time (Galaga rhythm), not all at
# once. Exact-tracks slot+drift (snaps to the drift point each frame — smooth, no lag).

var _enemy: Enemy
var _hold_t: float = 0.0
var _hold_duration: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_enemy = owner as Enemy
	_hold_t = 0.0
	if _enemy == null or _enemy.formation_def == null or _enemy.definition == null:
		return
	# Per-enemy hold variance staggers dives. Re-rolled each formation cycle (re-entry) for
	# naturalistic timing.
	_hold_duration = _enemy.formation_def.formation_hold_s * _enemy.rng.randf_range(0.75, 1.25)
	# Arm fire once in formation (never during Enter). arm() delays the first shot by a random
	# interval so the enemy doesn't fire the instant it forms up.
	_enemy.arm_fire()


func physics_process(delta: float) -> void:
	if _enemy == null or _enemy.formation_def == null or _enemy.definition == null or delta <= 0.0:
		return
	var form: FormationDefinition = _enemy.formation_def
	_hold_t += delta
	# Side-to-side drift anchored to the slot (sine of elapsed time over the drift period).
	var drift_x: float = sin((_hold_t / form.side_drift_period_s) * TAU) * form.side_drift_amplitude_px
	var target: Vector2 = _enemy.slot_world_pos + Vector2(drift_x, 0.0)
	# Exact-track the drift point (velocity = (target-pos)/delta → snaps to slot+drift).
	_enemy.velocity = (target - _enemy.global_position) / delta
	_enemy.move_and_slide()
	if _hold_t >= _hold_duration:
		_enemy.to_dive()
