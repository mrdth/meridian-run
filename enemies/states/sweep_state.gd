class_name SweepState
extends State
# Edge-sweep attack run (decision-log [Sweep-state]). Peels off from formation and strafes a
# full-width path toward the FAR screen edge at formation_def.sweep_y, firing straight down at
# the tight sweep_fire_interval_s cadence (EnemyFireSystem sweep mode) so the run rakes dense
# fire across the lane — guaranteeing both screen corners are covered over a wave. This denies
# edge-camping, which straight-down formation fire alone can't: a corner camper is only hit while
# an enemy is directly overhead (~16% of a drift cycle — luck-dependent). dive_aim_track_factor
# handles campers who MOVE to an edge; this handles campers who SIT there.
#
# Geometry is procedural (no Curve2D): a param u∈[0,1] over the horizontal travel from the slot's
# x to off-screen past the far edge. Y blends from slot.y down to sweep_y over the first quarter
# (a smooth diagonal-then-strafe — no teleport pop), then holds sweep_y. Reuses the states'
# exact-tracking velocity pattern. Direction is toward the far edge (slot.x < center → sweep
# right) so every run is a LONG traverse that covers the far corner.
#
# Off-screen far edge → to_enter() (re-enter from the top, the Galaga loop). NOT a release —
# death is the only release (mirrors DiveState; preserves the persistent-cycling-threat invariant
# enforced for dives by test_dive_loops_re_enters_does_not_release).

const _OFFSCREEN_MARGIN: float = 48.0
const _DESCEND_FRACTION: float = 0.25  # descend from slot.y to sweep_y over the first 25% of the run.

var _enemy: Enemy
var _t: float = 0.0
var _start_x: float = 0.0
var _start_y: float = 0.0
var _end_x: float = 0.0
var _travel: float = 0.0
var _sweep_y: float = 0.0
var _logged_degenerate: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_enemy = owner as Enemy
	_t = 0.0
	_logged_degenerate = false
	if _enemy == null or _enemy.formation_def == null or _enemy.definition == null:
		return
	assert(_enemy.collision_mask == 0, "SweepState: exact-tracking movement requires collision_mask == 0")
	var slot: Vector2 = _enemy.slot_world_pos
	_start_x = slot.x
	_start_y = slot.y
	_sweep_y = _enemy.formation_def.sweep_y
	# Direction toward the FAR edge — a long traverse that covers the far corner every run.
	var dir: float = 1.0 if slot.x < Constants.BASE_RESOLUTION.x * 0.5 else -1.0
	_end_x = (Constants.BASE_RESOLUTION.x + _OFFSCREEN_MARGIN) if dir > 0.0 else -_OFFSCREEN_MARGIN
	_travel = absf(_end_x - _start_x)
	# Fire at the tight sweep cadence (EnemyFireSystem sweep mode) — a dense raking stream.
	_enemy.arm_sweep_fire()


func physics_process(delta: float) -> void:
	if _enemy == null or _enemy.formation_def == null or _enemy.definition == null or delta <= 0.0:
		return
	if _travel <= 0.0:
		# Degenerate (slot exactly on the exit edge — impossible with authored data, but guard so a
		# bad FormationDefinition never divide-by-zeroes or freezes the enemy here). Log once per
		# state-entry, mirroring EnterState/DiveState's degenerate-curve handling.
		if not _logged_degenerate:
			Log.err("enemies", "SweepState: zero-length traverse — enemy stuck")
			_logged_degenerate = true
		return
	var speed: float = _enemy.definition.move_speed * _enemy.definition.sweep_speed_multiplier
	_t += (speed * delta) / _travel
	var u: float = minf(_t, 1.0)
	var x: float = lerpf(_start_x, _end_x, u)
	# Descend from the slot to sweep_y over the first quarter, then hold (diagonal-then-strafe).
	var descend_u: float = minf(u / _DESCEND_FRACTION, 1.0)
	var y: float = lerpf(_start_y, _sweep_y, descend_u)
	var target: Vector2 = Vector2(x, y)
	# Exact tracking: move_and_slide translates by velocity*delta; dividing by delta cancels it →
	# the body lands on the target. Frame-rate independent, no lag (same idiom as Enter/Dive).
	_enemy.velocity = (target - _enemy.global_position) / delta
	_enemy.move_and_slide()
	# Off-screen far edge → re-enter from the top (Galaga loop). NOT a release.
	if _t >= 1.0:
		_enemy.to_enter()
