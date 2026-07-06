class_name WaveModifierReadout
extends Control
# Wave number, then the modifier chip beneath it — a SEPARATE row each, beneath the score value
# (UX H5 / DESIGN wave-modifier-readout: "wave number + modifier chip beneath the score"). In E1
# there is NO modifier system (modifiers = Epic 5) ⇒ the chip stays a neutral `STANDARD` placeholder
# and is HIDDEN (a chip that always reads "STANDARD" is noise, not information). The shape-glyph
# machinery (cluster/columns/diamond → SWARM/GAUNTLET/BOUNTY, colors.modifier-*) is built but
# DORMANT — shape carries meaning first (A1); it wires when Epic 5 supplies modifier data. Dims
# during focus/fade (S1). arc_t_changed subscribed (calm-only in E1).

const _STANDARD_MODIFIER := "STANDARD"

@export var wave_label_color: Color = HudPalette.MUTED
@export var chip_color: Color = HudPalette.MUTED

var _wave_label: Label = null
var _chip_label: Label = null
var _col: VBoxContainer = null


func _ready() -> void:
	# VBox[wave, chip], each row right-aligned, top-anchored. Full-rect so it fills the readout.
	_col = VBoxContainer.new()
	_col.name = "Column"
	_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	_col.add_theme_constant_override("separation", 2)
	_col.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wave_label = HudFonts.make_label("WAVE 1", wave_label_color, HudPalette.LABEL_CAPS, false)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chip_label = HudFonts.make_label(_STANDARD_MODIFIER, chip_color, HudPalette.LABEL_CAPS, false)
	_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chip_label.visible = false  # STANDARD is a placeholder, not information — hidden until Epic 5
	_col.add_child(_wave_label)
	_col.add_child(_chip_label)
	add_child(_col)
	# A plain Control reports (0,0) minimum size to its parent container by default. Without this, the
	# outer score-column VBoxContainer (hud.gd) collapses this readout to zero height and stacks it
	# right on top of the score value above it (see score_readout.gd for the same fix).
	custom_minimum_size = _col.get_combined_minimum_size()
	EventBus.arc_t_changed.connect(_on_arc_t_changed)


func set_wave(wave: int) -> void:
	if _wave_label != null:
		_wave_label.text = "WAVE %d" % maxi(wave, 1)
		# Recompute — a later/wider wave number than the "WAVE 1" placeholder used at _ready() would
		# otherwise overflow the frozen box (Labels don't clip by default).
		custom_minimum_size = _col.get_combined_minimum_size()


func _on_arc_t_changed(_t: float) -> void:
	# Dormant in E1. Per-modifier chip shape/color (SWARM/GAUNTLET/BOUNTY) wires with Epic 5 data.
	pass
