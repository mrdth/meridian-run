class_name HudFonts
extends RefCounted
# Lazy font cache for the in-wave HUD. The numeric face (score, timer, ×N) MUST be monospace — UX T2:
# a proportional face lets digits jitter column-to-column as values change. JetBrains Mono (OFL) is
# fetched into assets/fonts/ (Story 1.7 Task 8); if absent, fall back to Godot's default font so the
# HUD still renders — a documented v0.1 deviation (real faces finalize at the E8 art pass).
#
# Display/body labels (SCORE/WAVE caps) use Godot's default face for v0.1 — the neon read comes from
# color/size/glow, not the specific face. Chakra Petch + Inter land at E8.

const NUMERIC_BOLD_PATH := "res://assets/fonts/JetBrainsMono-Bold.ttf"
const NUMERIC_REGULAR_PATH := "res://assets/fonts/JetBrainsMono-Regular.ttf"

static var _numeric_bold: FontFile = null
static var _numeric_regular: FontFile = null
static var _probed_bold: bool = false
static var _probed_regular: bool = false


static func numeric_bold() -> FontFile:
	# Bold mono — score + timer display-weight numerics. Lazy-loaded once; null-safe fallback (caller
	# leaves the Label on Godot's default face, accepting the documented v0.1 non-mono deviation).
	if not _probed_bold:
		_probed_bold = true
		_numeric_bold = _try_load(NUMERIC_BOLD_PATH)
	return _numeric_bold


static func numeric_regular() -> FontFile:
	# Regular-weight mono — the ×N lives label.
	if not _probed_regular:
		_probed_regular = true
		_numeric_regular = _try_load(NUMERIC_REGULAR_PATH)
	return _numeric_regular


static func _try_load(path: String) -> FontFile:
	# load() (not preload) so a missing file degrades to null instead of a parse error. ResourceLoader
	# checks existence first to avoid a spammy error print on every call in the no-font fallback path.
	if not ResourceLoader.exists(path):
		return null
	return load(path) as FontFile


static func make_label(text: String, color: Color, size_px: int, mono: bool) -> Label:
	# Factory for HUD labels: applies the mono face when `mono` (numerics — T2 non-jitter), the size,
	# the color, and a thin surface-color outline so text stays legible over a busy arena (the DESIGN
	# scrim-legibility contract). Returns an unsized Label; the caller positions it.
	var l := Label.new()
	l.text = text
	if mono:
		var f := numeric_bold()
		if f != null:
			l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", HudPalette.SURFACE)
	l.add_theme_constant_override("outline_size", 4)
	return l
