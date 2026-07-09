extends State
# Captor DiveState — dive_duration_s (1.6 s) bezier swoop toward the player then off-screen, then
# release to the pool (ONE pass — Open Question D default: dive off-screen ends the gamble; re-enter
# is a 2.8/playtest option). Reuses the grunt DiveState aim math: capture the player's x ONCE at
# dive-start (_captured_aim), then blend toward the LIVE player x by dive_aim_track_factor (0 =
# pure once-capture, 1 = continuous tracking). Procedural curve (no shared Curve2D/FormationDefinition):
# a quadratic ease-in on y gives the dive a "swoop" (slow start, accelerating fall — Open Question E
# default). On enter the capture column is released (the column's job ended at capture). On expiry
# (captor off-screen) → release the captor to the pool.
#
# state_changed("dive") is emitted by the captor's to_dive() transition helper.

var _captor: Captor
var _t: float = 0.0
var _start_pos: Vector2 = Vector2.ZERO
var _captured_aim: float = 0.0  # player.x - captor.x at dive-start (classic once-captured aim).


func enter(_msg: Dictionary = {}) -> void:
	_captor = owner as Captor
	_t = 0.0
	if _captor == null or _captor.tuning == null or _captor.definition == null \
			or _captor.player_target == null:
		return
	assert(_captor.collision_mask == 0, "CaptorDiveState: exact-tracking movement requires collision_mask == 0")
	_start_pos = _captor.global_position
	# Capture the player's x ONCE at dive-start (injected player_target ref) — the classic aim.
	if _captor.player_target != null:
		_captured_aim = _captor.player_target.global_position.x - _start_pos.x
	# The capture column's job ended at capture — release it (deferred to idle; safe from this tick).
	_captor._release_capture_column()
	# Defensive disarm (mirrors the grunt DiveState): the captor fires ONLY in formation (key decision
	# #6); fire is already disarmed from telegraph, but enforce it here too so the invariant holds even
	# if a future state re-arms. fires_during_dive is false on enemy_captor.tres.
	if _captor.definition != null and not _captor.definition.fires_during_dive:
		_captor.disarm_fire()


func physics_process(delta: float) -> void:
	if _captor == null or _captor.tuning == null or _captor.player_target == null or delta <= 0.0:
		return
	_t += delta / _captor.tuning.dive_duration_s
	var u: float = minf(_t, 1.0)
	# Quadratic ease-in on the descent → the dive accelerates downward (a swoop feel).
	var ue: float = u * u
	# Blend the once-captured aim toward the player's LIVE x (dive_aim_track_factor). The shared
	# tuning/curve is NEVER mutated — the aim is applied to a per-captor computed target at read time.
	var live_aim: float = _captor.player_target.global_position.x - _start_pos.x
	var aim: float = lerpf(_captured_aim, live_aim, clampf(_captor.tuning.dive_aim_track_factor, 0.0, 1.0))
	var target_x: float = _start_pos.x + aim
	var target_y: float = lerpf(_start_pos.y, Constants.BASE_RESOLUTION.y + _captor.tuning.dive_offscreen_margin_px, ue)
	var target: Vector2 = Vector2(target_x, target_y)
	# Exact tracking: velocity = (target - pos) / delta → the body lands on the target each frame.
	_captor.velocity = (target - _captor.global_position) / delta
	_captor.move_and_slide()
	# Timed completion (the captor is off-screen by u=1: target_y = BASE_RESOLUTION.y + margin). One
	# pass → release to the pool (deferred — we are mid physics tick).
	if _t >= 1.0:
		_captor._release_to_pool.call_deferred()
