extends State
# Captor CaptureState — capture_duration_s (0.4 s) of ACTIVE tractor: the capture column intensifies
# (set_active_visual(true) — the bars go solid) AND turns detection ON (set_detection(true)). The
# captor holds position over the beam and, each physics frame, overlap-POLLs whether a clean player
# is still inside the locked column. On a hit it duck-calls the player's try_capture() (the capture
# EFFECT — −1 ship, bypass HP, full-HP respawn via the reused ship_depleted → Arena path).
#
# Success-conditional dive delay (AC#5, Mrdth playtest note 2026-07-09, deferred from 2.1): on a
# SUCCESSFUL capture the captor HOLDS the "reel-in" beat (post_capture_delay_s) before to_dive(); on a
# MISS (player dodged out of the column for the whole window) it dives IMMEDIATELY (no hold). The
# synchronous try_capture() return value is what lets the captor know which path to take.
#
# Detection is OFF everywhere except this state's active window: telegraph keeps it off (capture is the
# 0.4 s window only, AC#1), and dive/death release + deactivate the column (which set_detection(false)).

var _captor: Captor
var _t: float = 0.0
var _captured := false
var _post_capture_t := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_captor = owner as Captor
	_t = 0.0
	_captured = false
	_post_capture_t = 0.0
	if _captor == null or _captor.tuning == null or _captor.definition == null \
			or _captor.player_target == null:
		return
	# Intensify the column (the active-tractor look — bars go solid) + turn detection ON for the window.
	if _captor.capture_column != null:
		_captor.capture_column.set_active_visual(true)
		_captor.capture_column.set_detection(true)


func physics_process(delta: float) -> void:
	if _captor == null or _captor.tuning == null or delta <= 0.0:
		return
	# Hold position over the beam during the active window.
	_captor.velocity = Vector2.ZERO
	_captor.move_and_slide()

	if not _captured:
		# Active window — try to capture a clean player still in the column. Overlap-POLL (not
		# body_entered): the player is usually already inside at window start (the column locks to the
		# player's x at telegraph), so the enter-transition never fires.
		if _captor.capture_column != null and _captor.capture_column.is_player_in_column():
			var p: Node2D = _captor.player_target
			if p != null and p.has_method("try_capture"):
				if p.call("try_capture"):  # duck-call — player_target is typed Node2D (no Player cast)
					_captured = true
					_captor.capture_column.set_detection(false)  # stop detecting once captured
		_t += delta / _captor.tuning.capture_duration_s
		# Window expired with no capture → MISS: dive IMMEDIATELY (no reel-in hold). The `not _captured`
		# guard covers the rare same-frame edge (capture lands on the literal last window frame) so a
		# successful capture never short-circuits its hold — it falls through to the success branch next.
		if _t >= 1.0 and not _captured:
			_disable_detection()
			_captor.to_dive()
	else:
		# SUCCESS: hold the reel-in beat, then dive.
		_post_capture_t += delta
		if _post_capture_t >= _captor.tuning.post_capture_delay_s:
			_disable_detection()
			_captor.to_dive()


func _disable_detection() -> void:
	# Defensive — DiveState.enter() releases the column (deactivate → set_detection(false)) on both paths
	# too. Idempotent; also covers a mid-window transition. Belts-and-braces against stale monitoring.
	if _captor != null and _captor.capture_column != null:
		_captor.capture_column.set_detection(false)
