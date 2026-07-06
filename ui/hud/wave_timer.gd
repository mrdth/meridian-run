class_name WaveTimer
extends Control
# Top-center survive-to-end countdown (UX H3/T1 / DESIGN wave-timer). `XXs` mono numeric (T2 — no
# digit jitter) + a `SURVIVE` eyebrow. Owns its LOCAL countdown: seeded by wave_started, decremented
# in _process (this is local integration, NOT bus polling — AC9). Label text is set ONLY when
# ceil(remaining) changes (cache _last_shown — no per-frame string alloc, NFR3). At low-time the
# numeric shifts to HAZARD with a NEUTRAL-WHITE outline glow (NOT primary — UX T1/A2; v0.1 uses a
# label outline, true glow is an E8 shader). Emits low_time_entered on every display tick while below
# threshold (throttled to the same ~1Hz cadence as the label update, not per-frame — Task 6.4's
# "light throttle" allowance) so Hud can keep recomputing focus/fade as time pressure ramps, not only
# from HP changes. A single edge-triggered emit is NOT enough: HudFocusModel's time axis ramps
# linearly across the whole low-time window, so intensity may still be below focus_enter_at right at
# the threshold and only cross it several ticks later. Stays sharp through focus/fade. arc_t_changed
# subscribed (calm-only in E1).

signal low_time_entered

@export var low_time_threshold_s: float = 10.0
@export var numeric_color: Color = HudPalette.TEXT
@export var suffix_color: Color = HudPalette.PRIMARY
@export var low_time_color: Color = HudPalette.HAZARD

var _remaining: float = 0.0
var _last_shown: int = -1
var _running: bool = false
var _numeric_label: Label = null
var _suffix_label: Label = null


func _ready() -> void:
	# Container-driven layout: VBox[HBox[numeric, suffix]] — the HUD centers this readout on screen.
	# Top-anchored (BEGIN) so the numeric lines up with the lives pips + score value (no stair-step).
	var col := VBoxContainer.new()
	col.name = "Column"
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	_numeric_label = HudFonts.make_label("0", numeric_color, HudPalette.NUMERIC_LG, true)
	_suffix_label = HudFonts.make_label("s", suffix_color, HudPalette.NUMERIC_LG, true)
	row.add_child(_numeric_label)
	row.add_child(_suffix_label)
	col.add_child(row)
	add_child(col)
	EventBus.arc_t_changed.connect(_on_arc_t_changed)
	set_process(false)  # idle until start()


func start(_wave: int, duration_s: float) -> void:
	# Seed the countdown from the wave's authored duration. The HUD conductor calls this on
	# wave_started. `_wave` is unused here (the modifier-readout shows it) but kept for signature clarity.
	_remaining = maxf(duration_s, 0.0)
	_running = true
	set_process(true)
	_update_display(true)
	if _below_threshold():
		# Defensive: a wave authored shorter than the low-time threshold starts already "low" — there's
		# no prior _process frame to detect the edge, so fire it here instead.
		low_time_entered.emit()


func stop() -> void:
	# Freeze the countdown (called by the HUD on wave_cleared / game-over).
	_running = false
	set_process(false)


func _process(delta: float) -> void:
	if not _running:
		return
	_remaining = maxf(_remaining - delta, 0.0)
	if _remaining <= 0.0:
		stop()
	# _update_display reads _remaining directly (not gated on _running) so the expiry frame itself still
	# renders as low-time — see _update_display's comment. Its return tells us whether the displayed
	# integer actually ticked, which is also the throttle for low_time_entered below.
	var ticked: bool = _update_display(false)
	if ticked and _below_threshold():
		low_time_entered.emit()


func _update_display(force: bool) -> bool:
	# Only reformat the label when the displayed integer changes — no per-frame string alloc (NFR3).
	# Returns whether it did, so _process can throttle low_time_entered to the same cadence.
	var shown: int = int(ceil(_remaining))
	if not force and shown == _last_shown:
		return false
	_last_shown = shown
	if _numeric_label != null:
		_numeric_label.text = "%d" % shown
		# Gate on _remaining alone, NOT _running: stop() (called from _process the instant _remaining
		# hits 0) flips _running to false before this runs, so gating on _running would make the timer
		# revert to its calm color at the exact moment it expires — the one instant it's most urgent.
		var low: bool = _below_threshold()
		_numeric_label.add_theme_color_override("font_color", low_time_color if low else numeric_color)
		# Neutral-white outline glow at low-time (AC5/T1) — NOT primary. Reuses the outline-as-halo idiom
		# already established by health_bar's glow rect / lives_display's lit-pip glow.
		_numeric_label.add_theme_color_override("font_outline_color", HudPalette.WHITE if low else HudPalette.SURFACE)
		if _suffix_label != null:
			_suffix_label.add_theme_color_override("font_color", HudPalette.MUTED if low else suffix_color)
	return true


func _below_threshold() -> bool:
	return _remaining <= low_time_threshold_s


func get_time_remaining() -> float:
	# Read-only accessor for the HUD focus model (combat intensity rises as time runs out).
	return _remaining


func is_running() -> bool:
	# The HUD passes the remaining value to the focus model ONLY while the timer is running, so an
	# unstarted/stopped timer (remaining == 0) does not falsely read as "time up".
	return _running


func is_low_time() -> bool:
	return _running and _below_threshold()


func _on_arc_t_changed(_t: float) -> void:
	# Dormant in E1 (no emitter). Climax low-time color → climax-hazard amber matures with 3.9.
	pass
