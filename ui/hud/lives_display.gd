class_name LivesDisplay
extends Control
# Top-left ship-icon pip row + ×N label (UX H5/H6 / DESIGN lives-display). Lit pip = hollow
# rescuer-arrowhead triangle (PRIMARY stroke + a faint GLOW halo, transparent fill); lost pip = hollow
# MUTED triangle at 55% opacity — KEPT VISIBLE so MAX_SHIPS always reads (the gamble hinges on
# knowing you're on your last ship, UX S1). Updates ONLY on set_ships — never animates the digit (it
# is a pip row, not a counting number). Stays sharp through focus/fade (the HUD never dims this node).
# arc_t_changed subscribed (calm-only in E1; recolor via queue_redraw on the event — a state change).

@export var pip_size: float = 11.0
@export var pip_gap: float = 12.0
@export var label_gap: float = 10.0
@export var lit_stroke: Color = HudPalette.PRIMARY
@export var lit_glow: Color = HudPalette.GLOW
@export var lost_stroke: Color = HudPalette.MUTED

var _remaining: int = 0
var _maximum: int = 0
var _x_label: Label = null


func _ready() -> void:
	_x_label = HudFonts.make_label("×0", HudPalette.MUTED, HudPalette.NUMERIC_SM, true)
	_x_label.name = "CountLabel"
	add_child(_x_label)
	EventBus.arc_t_changed.connect(_on_arc_t_changed)
	_layout()


func set_ships(remaining: int, maximum: int = Constants.MAX_SHIPS) -> void:
	_maximum = maxi(maximum, 0)
	_remaining = clampi(remaining, 0, _maximum)
	if _x_label != null:
		_x_label.text = "×%d" % _remaining
	_layout()


func _layout() -> void:
	# Reserve room for the pip row + the ×N label; place the label past the pips. Manual layout (the
	# pips are _draw, not container children).
	var pips_w: float = _pip_row_width()
	if _x_label != null:
		_x_label.position = Vector2(pips_w + label_gap, -2.0)
		_x_label.size = Vector2(64.0, float(HudPalette.NUMERIC_SM) + 8.0)
	custom_minimum_size = Vector2(pips_w + label_gap + 64.0, pip_size + 12.0)
	queue_redraw()


func _pip_row_width() -> float:
	if _maximum <= 0:
		return 0.0
	return float(_maximum) * pip_size + float(_maximum - 1) * pip_gap


func _draw() -> void:
	# Shape carries the ship idiom (A1) — color reinforces. Lit = hollow PRIMARY triangle + glow halo;
	# lost = hollow MUTED triangle at 55% opacity.
	var nose := Vector2(pip_size / 2.0, 0.0)
	var tail_l := Vector2(0.0, pip_size)
	var tail_r := Vector2(pip_size, pip_size)
	for i in _maximum:
		var ox: float = float(i) * (pip_size + pip_gap)
		var tri := PackedVector2Array([
			nose + Vector2(ox, 0.0),
			tail_l + Vector2(ox, 0.0),
			tail_r + Vector2(ox, 0.0),
		])
		if i < _remaining:
			draw_colored_polygon(_grow(tri, 1.5), Color(lit_glow.r, lit_glow.g, lit_glow.b, 0.30))
			draw_polyline(_closed(tri), lit_stroke, 1.5)
		else:
			var lost := Color(lost_stroke.r, lost_stroke.g, lost_stroke.b, 0.55)
			draw_polyline(_closed(tri), lost, 1.0)


func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	# Append the first point to close the triangle for draw_polyline (otherwise the base is open).
	var out: PackedVector2Array = poly.duplicate()
	out.push_back(poly[0])
	return out


func _grow(poly: PackedVector2Array, amount: float) -> PackedVector2Array:
	# Grow a polygon outward from its centroid (a cheap glow-halo approx).
	var cx: float = 0.0
	var cy: float = 0.0
	for p in poly:
		cx += p.x
		cy += p.y
	var n: float = float(poly.size())
	cx /= n
	cy /= n
	var out := PackedVector2Array()
	for p in poly:
		var d: Vector2 = p - Vector2(cx, cy)
		if d.length() > 0.001:
			d = d.normalized()
		out.push_back(p + d * amount)
	return out


func _on_arc_t_changed(_t: float) -> void:
	# Dormant in E1 (no emitter). Climax pip recolor matures with ThemeTokens (Story 3.9).
	queue_redraw()
