class_name HealthBar
extends Node2D
# Reusable segmented HP bar (UX H6; arch line 470). World-space Node2D — a CHILD of the entity
# (player ship / multi-hit enemy), positioned above the sprite (y_offset). Same idiom on-ship +
# on-enemy; absent on grunts (the parent scene simply omits this child). Ring/halo is RESERVED for
# the future Shield power-up (H6) — this draws SEGMENTS ONLY.
#
# Driven by its entity's OWN HealthComponent.health_changed (intra-entity, D8 — HP is NOT on
# EventBus). bind() connects once (guarded) + syncs; the entity calls it from _ready (player) or
# activate() (pooled enemy — re-syncs each spawn). _draw() runs ONLY on change (queue_redraw from
# health_changed / arc_t_changed), never per-frame.
#
# arc_t_changed: subscribed for forward-compat with the calm→climax palette arc (UX V3, arch D13).
# No emitter in E1 (PaletteArcCoordinator = Story 3.9) ⇒ _arc_t stays 0 ⇒ calm colors only. Climax
# interpolation matures with ThemeTokens (3.9). Unlike the modulate-recolor'd HUD Labels (AC7), this
# _draw()-based node DOES queue_redraw() on arc_t_changed — but only on that event (a state change),
# never per-frame.

@export_group("Geometry")
@export var segment_w: float = 10.0   # DESIGN hp-bar.segment-w
@export var segment_h: float = 4.0    # DESIGN hp-bar.segment-h
@export var segment_gap: float = 3.0  # DESIGN hp-bar.gap
@export var y_offset: float = -34.0   # local Y above the entity sprite (ship nose ≈ -17)

@export_group("Behavior")
# Enemies: hidden until damaged (H6). Player: false — the primary read is always visible.
@export var hide_when_full: bool = false
# HP represented PER SEGMENT. The bar shows ceil(max_hp / hp_per_segment) segments, so:
#   player (hp_per_segment = 1)  ⇒ one segment per HP (3 HP = 3 segments).
#   enemy  (hp_per_segment = 10) ⇒ one segment per player shot (Shielder 50 HP = 5, Bomber 80 = 8) —
# "shots to kill", far more readable than 50–80 raw-HP segments. The enemy value mirrors the player's
# per-shot damage (player_tuning.projectile_damage = 10); update both together if damage retunes.
@export var hp_per_segment: int = 1

@export_group("Colors (calm Vector Standard — UX DESIGN.md)")
@export var fill_color: Color = Color(0.290, 0.871, 0.502)         # health #4ADE80
@export var empty_stroke_color: Color = Color(0.494, 0.553, 0.667) # muted  #7E8DAA
@export var glow_color: Color = Color(0.290, 0.871, 0.502)         # health glow #4ADE80

var _current: int = 0
var _maximum: int = 0
var _seg_filled: int = 0   # filled segment count (derived from _current / hp_per_segment)
var _seg_total: int = 0    # total segment count (derived from _maximum / hp_per_segment)
var _arc_t: float = 0.0    # derived theming state; 0 = calm. Dormant in E1 (no emitter).
var _health: HealthComponent = null


func _ready() -> void:
	position.y = y_offset  # geometry-driven placement above the sprite (y_offset is a playtest lever)
	# Forward-compat palette-arc subscription (D13). Dormant in E1 — the handler just stores _arc_t +
	# redraws; with no emitter it never fires. Connected once (the bar instance is reused across pool
	# cycles, never freed mid-run ⇒ no double-connect, no reconnect needed).
	EventBus.arc_t_changed.connect(_on_arc_t_changed)


func bind(health: HealthComponent) -> void:
	# Connect the entity's HP signal ONCE (guarded) and sync. Idempotent — safe to call every
	# activate() across pool reuse (no double-connect). HP is intra-entity (D8): never on EventBus.
	# Also safe to rebind to a DIFFERENT HealthComponent — disconnects the prior one first — even
	# though no current caller does this (every entity rebinds its own single component).
	if _health != null and _health != health and _health.health_changed.is_connected(_on_health_changed):
		_health.health_changed.disconnect(_on_health_changed)
	_health = health
	if _health != null and not _health.health_changed.is_connected(_on_health_changed):
		_health.health_changed.connect(_on_health_changed)
	_sync_from_health()


func _sync_from_health() -> void:
	if _health == null:
		return
	_maximum = _health.max_hp
	_current = _health.current_hp
	_recompute_segments()
	_apply_visibility()
	queue_redraw()


func _on_health_changed(current: int, maximum: int) -> void:
	_current = current
	_maximum = maximum
	_recompute_segments()
	_apply_visibility()
	queue_redraw()


func _recompute_segments() -> void:
	# Compress raw HP into "shots to kill" segments. ceil ⇒ a partial segment still counts (the last
	# shot finishes the enemy). Filled never exceeds total.
	var per: int = maxi(hp_per_segment, 1)
	_seg_total = ceili(float(_maximum) / float(per)) if _maximum > 0 else 0
	_seg_filled = ceili(float(_current) / float(per)) if _current > 0 else 0
	_seg_filled = mini(_seg_filled, _seg_total)


func _on_arc_t_changed(t: float) -> void:
	# Dormant in E1 (no emitter). Climax color interpolation lands with ThemeTokens (Story 3.9);
	# until then _draw uses calm colors regardless of _arc_t.
	_arc_t = t
	queue_redraw()


func _apply_visibility() -> void:
	# Enemies hide the bar at full HP (H6 — the read appears only when damaged). The player bar is
	# always visible (primary read). A 0-segment bar (unbound / degenerate) hides too.
	if _seg_total <= 0:
		visible = false
	elif hide_when_full and _seg_filled >= _seg_total:
		visible = false
	else:
		visible = true


func _draw() -> void:
	# SEGMENTS ONLY (no ring — H6 reserves that for Shield). Centered horizontally on the bar origin.
	# Filled segments: solid fill + a faint glow halo. Empty segments: transparent fill + muted outline.
	# Sharp rects are on-pattern for the neon-vector look (rounded.xs = 2px is near-square at 10×4).
	# Iterates _seg_total (shots-to-kill granularity), NOT raw HP — see hp_per_segment.
	if _seg_total <= 0:
		return
	var total_w: float = float(_seg_total) * segment_w + float(_seg_total - 1) * segment_gap
	var half_h: float = segment_h / 2.0
	for i in _seg_total:
		var rx: float = -total_w / 2.0 + float(i) * (segment_w + segment_gap)
		var seg_rect: Rect2 = Rect2(rx, -half_h, segment_w, segment_h)
		if i < _seg_filled:
			# Faint glow halo (slightly larger, low alpha) behind the filled segment.
			var glow_rect: Rect2 = seg_rect.grow(1.5)
			draw_rect(glow_rect, Color(glow_color.r, glow_color.g, glow_color.b, 0.35), true)
			draw_rect(seg_rect, fill_color, true)
		else:
			# Empty segment: muted 1px outline, transparent fill.
			draw_rect(seg_rect, empty_stroke_color, false, 1.0)
