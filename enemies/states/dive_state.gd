class_name DiveState
extends State
# Dives from the slot toward the bottom of the screen along dive_curve (RELATIVE to the
# slot), bending toward the player's x (captured ONCE at dive-start from the injected
# player_target — no cross-domain node-path reach). Moves at move_speed * dive_speed_multiplier.
# Fires during the dive if definition.fires_during_dive. Releases to the Pool when off-screen
# bottom — a departure, NOT a death (no score). The shared dive_curve is NEVER mutated: the
# aim offset is applied to the per-enemy sampled point at read time.

const _OFFSCREEN_MARGIN: float = 32.0

var _enemy: Enemy
var _t: float = 0.0
var _baked_length: float = 0.0
var _aim_offset: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_enemy = owner as Enemy
	_t = 0.0
	if _enemy == null or _enemy.formation_def == null or _enemy.formation_def.dive_curve == null:
		return
	_baked_length = _enemy.formation_def.dive_curve.get_baked_length()
	# Capture the player's x ONCE at dive-start (injected player_target ref). The dive bends
	# toward where the player is now — classic Galaga dive aim.
	if _enemy.player_target != null:
		_aim_offset = _enemy.player_target.global_position.x - _enemy.slot_world_pos.x
	# Fire stays armed from FormationState unless this enemy doesn't fire during dives.
	if _enemy.definition != null and not _enemy.definition.fires_during_dive:
		_enemy.disarm_fire()


func physics_process(delta: float) -> void:
	if _enemy == null or _enemy.formation_def == null or _enemy.definition == null:
		return
	var form: FormationDefinition = _enemy.formation_def
	var curve: Curve2D = form.dive_curve
	_t += delta
	var u: float = clampf(_t / form.dive_duration_s, 0.0, 1.0)
	var sampled: Vector2 = curve.sample_baked(u * _baked_length)
	# Bend toward the player gradually (offset scales with u): leaves the slot cleanly and
	# aims at the player by the bottom. Per-enemy offset — the shared curve is untouched.
	var target: Vector2 = _enemy.slot_world_pos + sampled + Vector2(_aim_offset * u, 0.0)
	var dive_speed: float = _enemy.definition.move_speed * _enemy.definition.dive_speed_multiplier
	_enemy.velocity = (target - _enemy.global_position).normalized() * dive_speed
	_enemy.move_and_slide()
	# Off-screen bottom → release (departure, not death). _physics_process runs BEFORE the
	# physics step, so synchronous release is fine (mirrors the player projectile leave-screen).
	if _enemy.global_position.y > Constants.BASE_RESOLUTION.y + _OFFSCREEN_MARGIN:
		Pool.release(_enemy)
