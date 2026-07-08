class_name DiveState
extends State
# Dives from the slot toward the bottom of the screen along dive_curve (RELATIVE to the slot),
# converging on the player's X BY the lane (so contact + straight-down fire land on a stationary
# player — decision-log [Contact-damage]). The aim is captured ONCE at dive-start (classic Galaga) and
# then blended toward the player's LIVE x by FormationDefinition.dive_aim_track_factor (0 =
# pure capture-once, 1 = continuous tracking) — read from the injected player_target, no
# cross-domain node-path reach. Speed-based traversal at move_speed * dive_speed_multiplier +
# exact tracking (fast swoop, no lag). Fires during the dive if definition.fires_during_dive.
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
var _captured_aim: float = 0.0  # player.x - slot.x at dive-start (classic once-captured aim).
var _logged_degenerate_curve: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_enemy = owner as Enemy
	_t = 0.0
	_logged_degenerate_curve = false
	if _enemy == null or _enemy.formation_def == null or _enemy.formation_def.dive_curve == null:
		return
	assert(_enemy.collision_mask == 0, "DiveState: exact-tracking movement requires collision_mask == 0")
	_baked_length = _enemy.formation_def.dive_curve.get_baked_length()
	# Capture the player's x ONCE at dive-start (injected player_target ref) — the classic
	# Galaga dive aim. dive_aim_track_factor (physics_process) blends this toward the player's
	# LIVE x so a player who relocates to / camps a screen edge after dive-start is still pursued.
	# (SweepState is the deeper anti-camp fix for STATIONARY edge campers — decision-log [Sweep-state].)
	if _enemy.player_target != null:
		_captured_aim = _enemy.player_target.global_position.x - _enemy.slot_world_pos.x
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
	# Converge on the player's X BY THE LANE (not off-screen). yb ramps 0→1 as the diver descends
	# from the slot to the player's lane Y, then clamps. At yb=1 (the lane): target.x = slot.x +
	# aim = player.x for a stationary player → the diver crosses the player's X at the lane (contact
	# + straight-down fire both land). Early (yb≈0) it follows the swoop curve. dive_aim_track_factor
	# still blends the once-captured aim vs the LIVE x for movers. The shared curve is untouched.
	var target: Vector2
	if _enemy.player_target != null:
		var player_y: float = _enemy.player_target.global_position.y
		var denom: float = player_y - _enemy.slot_world_pos.y
		# Guard denom<=0 (player at/above the slot — impossible in play; a misconfigured test could):
		# yb→1 immediately. clampf is load-bearing — sampled.y can exceed denom → raw ratio > 1.
		var yb: float = 1.0 if denom <= 0.0 else clampf(sampled.y / denom, 0.0, 1.0)
		var live_aim: float = _enemy.player_target.global_position.x - _enemy.slot_world_pos.x
		var aim: float = lerp(_captured_aim, live_aim, clampf(form.dive_aim_track_factor, 0.0, 1.0))
		target = Vector2(_enemy.slot_world_pos.x + sampled.x * (1.0 - yb) + aim * yb,
				_enemy.slot_world_pos.y + sampled.y)
	else:
		# No player injected (some tests / defensive): pure curve-follow, as before this fix.
		target = _enemy.slot_world_pos + sampled
	_enemy.velocity = (target - _enemy.global_position) / delta
	_enemy.move_and_slide()
	# Off-screen bottom → re-enter from the top (Galaga loop). NOT a release. Death is the only
	# release (HealthComponent.died → Pool via enemy._on_died).
	if _enemy.global_position.y > Constants.BASE_RESOLUTION.y + _OFFSCREEN_MARGIN:
		_enemy.to_enter()
