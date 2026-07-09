extends State
# Captor FormationState — side-to-side sine drift around a fixed formation anchor x (where Enter
# ended) + armed fire (the captor fires ONLY here), then after a per-spawn randomized hold
# (formation_duration_min_s..max_s — AC#2: 3.5–5.5 s) → TelegraphState. The lock-to-player happens
# ONLY in telegraph; here the captor drifts around its own anchor so formation fire pressure lands
# where it formed up, not on the player. Exact-tracks anchor+drift (snaps each frame — smooth, no
# lag). Disarms fire on exit (telegraph/capture/dive never fire).
#
# Hold duration = randf_range(min, max) (the Dev Notes pseudo-code form — the min/max band IS the
# per-spawn randomization AC#2 calls for; the ±25% in the Task-4 prose is the grunt's single-value
# stagger pattern, redundant over an already-random band). The test tuning sets min==max for a
# deterministic hold.

var _captor: Captor
var _hold_t: float = 0.0
var _hold_duration: float = 0.0
var _anchor_x: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_captor = owner as Captor
	_hold_t = 0.0
	if _captor == null or _captor.tuning == null or _captor.definition == null \
			or _captor.rng == null or _captor.player_target == null:
		return
	assert(_captor.collision_mask == 0, "CaptorFormationState: exact-tracking movement requires collision_mask == 0")
	# Anchor = the x EnterState left us at (the captor's formation column). Drift ±amplitude around it.
	_anchor_x = _captor.global_position.x
	# Per-spawn randomized hold (AC#2: 3.5–5.5 s). Re-rolled each formation cycle.
	_hold_duration = _captor.rng.randf_range(_captor.tuning.formation_duration_min_s, _captor.tuning.formation_duration_max_s)
	# Arm fire once in formation (the captor's ONLY firing state). arm() delays the first shot so it
	# doesn't fire the instant it forms up.
	_captor.arm_fire()


func physics_process(delta: float) -> void:
	if _captor == null or _captor.tuning == null or delta <= 0.0:
		return
	if _captor.tuning.side_drift_period_s <= 0.0:
		return
	_hold_t += delta
	# Side-to-side drift anchored to the formation x (sine of elapsed time over the drift period).
	var drift_x: float = sin((_hold_t / _captor.tuning.side_drift_period_s) * TAU) * _captor.tuning.side_drift_amplitude_px
	var target: Vector2 = Vector2(_anchor_x + drift_x, _captor.tuning.formation_row_y)
	# Exact-track the drift point (velocity = (target-pos)/delta → snaps to anchor+drift).
	_captor.velocity = (target - _captor.global_position) / delta
	_captor.move_and_slide()
	if _hold_t >= _hold_duration:
		_captor.to_telegraph()


func exit() -> void:
	# Disarm fire when leaving formation (telegraph/capture/dive never fire — the threat there is the
	# COLUMN, not bullets). Defensive: _captor may be null on a teardown-time exit.
	if _captor != null:
		_captor.disarm_fire()
