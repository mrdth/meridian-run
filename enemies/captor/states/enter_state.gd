extends State
# Captor EnterState — descends from the spawn point (off-screen above the player) to formation_row_y
# over enter_duration_s (data-tunable — AC#1: ~1 s). Procedural vertical lerp + the exact-tracking
# velocity idiom (mirrors the grunt EnterState, but a STRAIGHT vertical descent — no shared Curve2D;
# the captor uses no FormationDefinition). Fire disarmed on enter (the captor fires ONLY in
# formation). On completion → FormationState.
#
# The captor host is reached via `owner as Captor` (AR5/AR14 — no get_parent()/$ per frame). No
# class_name: this state is referenced by path in captor.tscn (avoids colliding with the grunt
# enemies/states/enter_state.gd's `EnterState`).

var _captor: Captor
var _t: float = 0.0
var _start_y: float = 0.0
var _target_y: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_captor = owner as Captor
	_t = 0.0
	# Defensive: StateMachine._ready calls enter() once before activate() populates per-spawn data (first
	# acquire / pool reuse). No-op until activate re-enters us with player_target + rng set.
	if _captor == null or _captor.tuning == null or _captor.definition == null \
			or _captor.player_target == null or _captor.rng == null:
		return
	assert(_captor.collision_mask == 0, "CaptorEnterState: exact-tracking movement requires collision_mask == 0")
	# _start_y is the spawn y set by activate (off-screen top). _target_y is the captor's formation row.
	_start_y = _captor.global_position.y
	_target_y = _captor.tuning.formation_row_y
	_captor.disarm_fire()


func physics_process(delta: float) -> void:
	if _captor == null or _captor.tuning == null or _captor.player_target == null or delta <= 0.0:
		return
	_t += delta / _captor.tuning.enter_duration_s
	var u: float = minf(_t, 1.0)
	var target: Vector2 = Vector2(_captor.global_position.x, lerpf(_start_y, _target_y, u))
	# Exact tracking: velocity = (target - pos) / delta cancels move_and_slide's internal delta → the
	# body lands on the target. Frame-rate independent, no lag (same idiom as the grunt states).
	_captor.velocity = (target - _captor.global_position) / delta
	_captor.move_and_slide()
	if _t >= 1.0:
		_captor.to_formation()
