class_name ScoreReadout
extends Control
# Top-right score VALUE (UX H5/H2 / DESIGN score-readout). Display-only, cumulative — fed by
# EventBus.score_changed via the HUD conductor. SCORE ONLY in-wave — currency is NEVER shown here
# (H2; AC3). Right-aligned within its HUD zone; the wave+modifier readout sits beneath it. Top-
# anchored (ALIGNMENT_BEGIN) so it lines up with the lives pips + timer numeric, not stair-stepped
# below them. Dims during focus/fade (S1). arc_t_changed subscribed (calm-only in E1 — score amber
# is an anchor hue that holds across the arc, so even when 3.9 lands this node need not recolor).

@export var value_color: Color = HudPalette.SCORE

var _value_label: Label = null
var _col: VBoxContainer = null


func _ready() -> void:
	# VBox[value], right-aligned, top-anchored.
	_col = VBoxContainer.new()
	_col.name = "Column"
	_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	_col.set_anchors_preset(Control.PRESET_FULL_RECT)
	_value_label = HudFonts.make_label("0", value_color, HudPalette.NUMERIC_LG, true)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_col.add_child(_value_label)
	add_child(_col)
	# A plain Control reports (0,0) minimum size to its parent container by default. Without this, the
	# outer score-column VBoxContainer (hud.gd) collapses this readout to zero height and stacks the
	# wave-modifier readout beneath it right on top of the score value.
	custom_minimum_size = _col.get_combined_minimum_size()
	EventBus.arc_t_changed.connect(_on_arc_t_changed)


func set_score(value: int) -> void:
	if _value_label != null:
		_value_label.text = "%d" % maxi(value, 0)
		# Recompute — a longer score (more digits) than the "0" placeholder used at _ready() would
		# otherwise overflow the frozen box (Labels don't clip by default).
		custom_minimum_size = _col.get_combined_minimum_size()


func _on_arc_t_changed(_t: float) -> void:
	# Dormant in E1. Score amber (#FFE066) is an anchor hue — holds across the calm→climax arc (V3).
	pass
