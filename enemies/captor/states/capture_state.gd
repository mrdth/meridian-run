extends State
# Captor CaptureState — capture_duration_s (0.4 s) of ACTIVE tractor: the capture column intensifies
# (set_active_visual(true) — the bars go solid). The captor holds position over the beam. On expiry
# → DiveState.
#
# >>> SEAM for Story 2.2 (capture effect): this is where 2.2 detects "player clean AND inside the
# capture column AND not-yet-captured-this-wave" → EventBus.ship_lost + full-HP respawn. The
# CaptureColumn gains an Area2D child (monitoring OFF in 2.1) for in-column detection; the player's
# HurtboxComponent is the intended reuse (hurtbox_component.gd:9). In 2.1 this state is PURE VISUAL +
# timing — NO ship effect. <<<
#
# 2.2 ALSO owns the success-conditional dive delay (Mrdth playtest note, 2026-07-09): on a SUCCESSFUL
# capture, hold briefly before to_dive() (the captor "reels in" the ship); on a miss, dive
# immediately. 2.1 dives UNCONDITIONALLY right after the 0.4 s window (capture is non-functional, so
# the timing is a placeholder). 2.2 adds the post_capture_delay_s lever + gates it on capture success.

var _captor: Captor
var _t: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_captor = owner as Captor
	_t = 0.0
	if _captor == null or _captor.tuning == null or _captor.definition == null \
			or _captor.player_target == null:
		return
	# Intensify the column — the active-tractor look (bars go solid).
	if _captor.capture_column != null:
		_captor.capture_column.set_active_visual(true)


func physics_process(delta: float) -> void:
	if _captor == null or _captor.tuning == null or delta <= 0.0:
		return
	# Hold position over the beam during the active window.
	_captor.velocity = Vector2.ZERO
	_captor.move_and_slide()
	_t += delta / _captor.tuning.capture_duration_s
	if _t >= 1.0:
		_captor.to_dive()
