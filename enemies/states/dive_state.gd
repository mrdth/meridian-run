class_name DiveState
extends State
# Dives from the slot toward the bottom of the screen along dive_curve (RELATIVE to the slot),
# bending toward the player's x (captured ONCE at dive-start from the injected player_target —
# no cross-domain node-path reach). Speed-based traversal at move_speed * dive_speed_multiplier
# + exact tracking (fast swoop, no lag). Fires during the dive if definition.fires_during_dive.
#
# **Off-screen-bottom → re-enter from the top (EnterState), NOT a release** — the Galaga
# dive-and-return loop. Enemies release to the Pool ONLY on death (HealthComponent.died). This
# makes them persistent cycling threats across the whole wave (addresses the "clear fast then
# wait" concern). The shared dive_curve is NEVER mutated: the aim offset is applied to the
# per-enemy sampled point at read time.

const _OFFSCREEN_MARGIN: float = 48.0

var _enemy: Enemy
var _t: float = 0.0
var _baked_length: float = 0.0
var _aim_offset: float = 0.0
var _logged_degenerate_curve: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_enemy = owner as Enemy
	_t = 0.0
	_logged_degenerate_curve = false
	if _enemy == null or _enemy.formation_def == null or _enemy.formation_def.dive_curve == null:
		return
	assert(_enemy.collision_mask == 0, "DiveState: exact-tracking movement requires collision_mask == 0")
	_baked_length = _enemy.formation_def.dive_curve.get_baked_length()
	# Capture the player's x ONCE at dive-start (injected player_target ref). The dive bends
	# toward where the player is now — classic Galaga dive aim.
	if _enemy.player_target != null:
		_aim_offset = _enemy.player_target.global_position.x - _enemy.slot_world_pos.x
	# Fire stays armed from FormationState unless this enemy doesn't fire during dives.
	if _enemy.definition != null and not _enemy.definition.fires_during_dive:
		_enemy.disarm_fire()


func physics_process(delta: float) -> void:
	if _enemy == null or _enemy.formation_def == null or _enemy.definition == null or delta <= 0.0:
		return
	if _baked_length <= 0.0:
		# A degenerate dive_curve would otherwise soft-lock the enemy here forever with no
		# diagnostic (review fix) — log once per state-entry so a bad FormationDefinition .tres
		# is discoverable instead of silently freezing enemies.
		if not _logged_degenerate_curve:
			Log.err("enemies", "DiveState: dive_curve has zero baked length — enemy stuck")
			_logged_degenerate_curve = true
		return
	var form: FormationDefinition = _enemy.formation_def
	var curve: Curve2D = form.dive_curve
	var speed: float = _enemy.definition.move_speed * _enemy.definition.dive_speed_multiplier
	_t += (speed * delta) / _baked_length
	var u: float = minf(_t, 1.0)
	var sampled: Vector2 = curve.sample_baked(u * _baked_length)
	# Bend toward the player gradually (offset scales with u): leaves the slot cleanly and aims
	# at the player by the bottom. Per-enemy offset — the shared curve is untouched.
	var target: Vector2 = _enemy.slot_world_pos + sampled + Vector2(_aim_offset * u, 0.0)
	_enemy.velocity = (target - _enemy.global_position) / delta
	_enemy.move_and_slide()
	# Off-screen bottom → re-enter from the top (Galaga loop). NOT a release. Death is the only
	# release (HealthComponent.died → Pool via enemy._on_died).
	if _enemy.global_position.y > Constants.BASE_RESOLUTION.y + _OFFSCREEN_MARGIN:
		_enemy.to_enter()
