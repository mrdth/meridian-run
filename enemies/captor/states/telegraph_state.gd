extends State
# Captor TelegraphState — THE FAIR DODGE WINDOW (telegraph_duration_s = 0.7 s, AC#3). On enter, locks
# the capture column to the player's x ONCE (the captor's once-captured-aim idiom — the player reads
# the locked column and has 0.7 s to move out of it), acquires + activates the column (wind-up look),
# and disarms fire (the threat here is the COLUMN, not bullets). The captor holds position (the
# column is the readable threat). On expiry → CaptureState.
#
# state_changed("telegraph") is emitted by the captor's to_telegraph() transition helper (so
# current_state_name is authoritative for 2.3's rescue branch). The column locks to the player's x —
# NOT the captor's x — so the telegraph shows WHERE the capture will land regardless of where the
# captor drifted to.

var _captor: Captor
var _t: float = 0.0
var _locked_x: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_captor = owner as Captor
	_t = 0.0
	if _captor == null or _captor.tuning == null or _captor.definition == null \
			or _captor.player_target == null or _captor.rng == null:
		return
	assert(_captor.collision_mask == 0, "CaptorTelegraphState: exact-tracking movement requires collision_mask == 0")
	# Lock the column to the player's x ONCE (classic once-captured aim — the fair dodge window).
	_locked_x = _captor.player_target.global_position.x
	_captor.disarm_fire()
	# Acquire + activate the capture column at the locked x (wind-up look). The captor owns the column.
	_captor._acquire_capture_column(_locked_x)


func physics_process(delta: float) -> void:
	if _captor == null or _captor.tuning == null or delta <= 0.0:
		return
	# Hold position for the telegraph window — the captor stays put (velocity 0); the COLUMN is the
	# readable threat, not the captor's motion.
	_captor.velocity = Vector2.ZERO
	_captor.move_and_slide()
	_t += delta / _captor.tuning.telegraph_duration_s
	if _t >= 1.0:
		_captor.to_capture()
