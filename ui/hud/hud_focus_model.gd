class_name HudFocusModel
extends Resource
# PURE combat-intensity model for the HUD focus/fade FSM (UX S1; arch line 321 — canonical signature).
# intensity() maps (projectiles_in_play, captors_active, hp_ratio, time_remaining) → 0..1; the HUD's
# FSM applies HYSTERESIS via should_focus() (enter focus_fade above focus_enter_at; return to standard
# below focus_exit_at) so the chrome does not flicker at the threshold. NO node access, no side
# effects — fully GUT-testable as a pure class.
#
# E1 inputs: captors_active = 0 (Epic 2), projectiles_in_play = 0 (no central projectile counter
# yet). The load-bearing E1 inputs are hp_ratio (low HP → intense) and time_remaining (low time →
# intense). The projectiles/captors axes stay in the signature for forward-compat; E1 passes 0 and
# they contribute 0 until E2/E8 wire them.

@export_range(0.0, 1.0, 0.01) var focus_enter_at: float = 0.6   # intensity to ENTER focus_fade
@export_range(0.0, 1.0, 0.01) var focus_exit_at: float = 0.4    # intensity to RETURN to standard
@export var hp_critical_ratio: float = 0.5    # at/below this HP ratio ⇒ HP axis maxes (critical HP)
@export var low_time_s: float = 10.0          # at/below this remaining time, the time axis begins
@export var projectiles_intense: int = 24     # forward-compat: this many player shots in play → max
@export var captor_intense: int = 2           # forward-compat: this many captors active → max


func intensity(projectiles_in_play: int, captors_active: int, hp_ratio: float, time_remaining: float) -> float:
	# Each axis → a 0..1 sub-intensity; the overall is the MAX (the most pressing read wins). A pure
	# function — same inputs ⇒ same output, no state, no node access.
	var hr: float = clampf(hp_ratio, 0.0, 1.0)
	# HP axis: BINARY at hp_critical_ratio. E1's player has discrete 3 HP, so a linear ramp barely
	# contributes until death (1/3 HP ≈ 0.33 would read as near-calm on a ramp). A clean "critical HP
	# ⇒ max intensity" gate is honest for discrete HP; per-segment gradation matures at E8 polish.
	var hp_axis: float = 1.0 if hr <= hp_critical_ratio else 0.0
	# Time axis: a linear ramp 0→1 across the last low_time_s seconds (time is continuous, so the ramp
	# is meaningful). The HUD only feeds a real remaining value while the wave timer is RUNNING — an
	# unstarted/stopped timer passes a large sentinel so this axis stays 0 between waves.
	var tr: float = maxf(time_remaining, 0.0)
	var time_axis: float = 0.0
	if tr <= low_time_s and low_time_s > 0.0:
		time_axis = (low_time_s - tr) / low_time_s
	# Forward-compat axes (E1 passes 0 ⇒ these are 0 this epic).
	var proj_axis: float = clampf(float(projectiles_in_play) / float(maxi(projectiles_intense, 1)), 0.0, 1.0)
	var captor_axis: float = clampf(float(captors_active) / float(maxi(captor_intense, 1)), 0.0, 1.0)
	var raw: float = maxf(maxf(hp_axis, time_axis), maxf(proj_axis, captor_axis))
	return clampf(raw, 0.0, 1.0)


func should_focus(current_focus: bool, value: float) -> bool:
	# Hysteresis gate. Already in focus_fade → stay until value drops below focus_exit_at. In standard
	# → enter only once value reaches focus_enter_at. The gap (focus_enter_at - focus_exit_at) is the
	# no-flicker deadband.
	if current_focus:
		return value >= focus_exit_at
	return value >= focus_enter_at
