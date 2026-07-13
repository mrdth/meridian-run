class_name Hud
extends CanvasLayer
# Arena-scoped in-wave HUD conductor (Story 1.7). Twin concept to JuiceCoordinator: a CanvasLayer
# child of the Arena scene, NOT an autoload (the 11-autoload registry is unchanged; menu scenes never
# include this node ⇒ "auto-disabled in menus", UX F8). Non-diegetic (UX D1) on its own CanvasLayer
# separate from the world tree (F3) — it never obscures the 1-axis play lane (all chrome lives in the
# top hud-band). The on-ship hp-bar is NOT a child of the HUD — it is world-space on the entity.
#
# Subscribes to EventBus for run/wave/theming state (AC9: signal-driven, no per-frame polling) and
# routes each signal to its readout. Owns the focus/fade FSM (reusable components/state_machine,
# arch D15) driven by a PURE HudFocusModel. The Arena injects the player ref so the model can read
# hp_ratio (read-only subscribe to the player's HealthComponent.health_changed — the HUD's display
# job, D8-clean; HP is never on the bus).

const LivesDisplayScene := preload("res://ui/hud/lives_display.tscn")
const WaveTimerScene := preload("res://ui/hud/wave_timer.tscn")
const ScoreReadoutScene := preload("res://ui/hud/score_readout.tscn")
const WaveModifierReadoutScene := preload("res://ui/hud/wave_modifier_readout.tscn")

const FOCUS_DIM_ALPHA: float = 0.32  # UX S1 — score + modifier chrome dim target (v0.1 opacity; true
                                     # ~0.5 saturation needs a shader → E8 polish, AC8).
const _HEALTH_NODE_NAME := "HealthComponent"
const _SAFE_MARGIN_PX: int = 32     # DESIGN margin-frame / title-safe inset (F4)
const _BAND_TOP_PX: float = 12.0    # top inset of the HUD band
# HUD band content height (fits score value + wave row stacked). Grew past DESIGN's original
# HudPalette.HUD_BAND_PX (58px) across the playtest layout fixes in the Change Log — 96px is the
# real, current value; HUD_BAND_PX is kept as the literal DESIGN.md token for reference only, not as
# this constant's source. Both are far under the 720px base viewport, so no functional overlap risk.
const _BAND_HEIGHT_PX: float = 96.0
const _SIDE_W: float = 220.0        # width of the left (lives) / right (score+modifier) zones
const _TIMER_W: float = 180.0       # width of the centered timer zone

@onready var _focus_fsm: StateMachine = $FocusFSM
@onready var _standard_state: State = $FocusFSM/StandardState
@onready var _focus_fade_state: State = $FocusFSM/FocusFadeState

var _lives: LivesDisplay = null
var _wave_timer: WaveTimer = null
var _score: ScoreReadout = null
var _wave_mod: WaveModifierReadout = null

var _focus_model: HudFocusModel = null
var _focus_active: bool = false
var _player: Node2D = null
var _player_health: HealthComponent = null
# Pip-row count = the lives the player actually holds (the gamble-read baseline). In E1 that is the
# starting count (BASE_SHIPS, 3); the run cap (MAX_SHIPS = 5) is NOT displayed — those would be
# phantom "un-earned" pips. Lost pips STAY (muted) so attrition reads. Ship-gain sources (E2/E3) will
# need to grow this; not wired yet (see deferred-work).
var _pip_row_count: int = Constants.BASE_SHIPS


func _ready() -> void:
	_focus_model = HudFocusModel.new()
	_build_layout()
	# Subscribe to run/wave/theming state (AC9). Each handler is a one-line route to a readout.
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.ship_lost.connect(_on_ship_count_changed)
	# Story 2.5 (AC2) — ship_gained mirrors ship_lost's shape (both carry the remaining count) → route it
	# to the SAME handler. Without this, a Keep regain (add_ship(+1)) would be invisible: the lives-pip row
	# only updated on ship_lost before 2.5, so the gamble's keep payoff wouldn't read on the HUD.
	EventBus.ship_gained.connect(_on_ship_count_changed)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.arc_t_changed.connect(_on_arc_t_changed)  # dormant in E1 (no emitter until Story 3.9)
	EventBus.game_over.connect(_on_game_over)
	_wave_timer.low_time_entered.connect(_on_low_time_entered)  # Task 6.4 — time-pressure-only trigger
	# Seed the readouts so the HUD is not blank before the first signal (ship_lost/score_changed only
	# fire on loss/kill; the wave number/timer seed from wave_started, which Arena fires on wave 1).
	_score.set_score(0)
	_lives.set_ships(Constants.BASE_SHIPS, _pip_row_count)


func _build_layout() -> void:
	# HUD corners anchored INDEPENDENTLY on a top-band Control (UX H5: lives top-left, timer
	# top-CENTER on the screen, score+modifier top-right). A single HBox with spacers failed this —
	# it centered the timer BETWEEN the side columns (unequal widths ⇒ off the screen midpoint) and
	# let the right column drift off-edge. Point-anchoring each readout (anchor left / 0.5 / right +
	# a grow direction) pins it to its corner/center at natural size: the timer is screen-centered
	# and the score column sits flush at the right margin regardless of the columns' widths.
	var safe := Control.new()
	safe.name = "Safe"
	# Top band: full width, fixed height at the top of the viewport.
	safe.anchor_left = 0.0
	safe.anchor_top = 0.0
	safe.anchor_right = 1.0
	safe.anchor_bottom = 0.0
	safe.offset_left = 0.0
	safe.offset_top = 0.0
	safe.offset_right = 0.0
	safe.offset_bottom = _BAND_TOP_PX + _BAND_HEIGHT_PX
	add_child(safe)
	# Left — lives.
	_lives = LivesDisplayScene.instantiate()
	_place_left(_lives, _SAFE_MARGIN_PX)
	safe.add_child(_lives)
	# Center — wave timer (screen-centered, not just between the side columns).
	_wave_timer = WaveTimerScene.instantiate()
	_place_center(_wave_timer)
	safe.add_child(_wave_timer)
	# Right — score over wave+modifier (a VBox stacks the two readouts at the right edge). Top-
	# anchored (BEGIN) so the column lines up with lives + timer instead of stair-stepping below them.
	var score_col := VBoxContainer.new()
	score_col.name = "ScoreColumn"
	score_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	score_col.add_theme_constant_override("separation", 2)
	_score = ScoreReadoutScene.instantiate()
	_wave_mod = WaveModifierReadoutScene.instantiate()
	score_col.add_child(_score)
	score_col.add_child(_wave_mod)
	_place_right(score_col, _SAFE_MARGIN_PX)
	safe.add_child(score_col)


func _place_left(c: Control, margin_px: float) -> void:
	# Fixed-width left zone. Explicit offset_left AND offset_right ⇒ a real-width box regardless of
	# grow behavior. Content left-aligns inside.
	_place_zone(c, 0.0, 0.0, margin_px, margin_px + _SIDE_W)


func _place_center(c: Control) -> void:
	# Fixed-width centered zone (±_TIMER_W/2 about the horizontal midpoint) ⇒ screen-centered.
	_place_zone(c, 0.5, 0.5, -_TIMER_W / 2.0, _TIMER_W / 2.0)


func _place_right(c: Control, margin_px: float) -> void:
	# Fixed-width right zone pinned to the right margin. Explicit offsets — NOT grow-direction (a
	# grow-direction VBox stayed zero-width at the anchor and its children overflowed off-screen).
	# Content right-aligns inside ⇒ the score sits flush at the right margin.
	_place_zone(c, 1.0, 1.0, -(margin_px + _SIDE_W), -margin_px)


func _place_zone(c: Control, h_anchor: float, h_anchor_right: float, off_left: float, off_right: float) -> void:
	# Common placement: a horizontally-anchored zone of DEFINITE width + a fixed-height top band.
	c.anchor_left = h_anchor
	c.anchor_top = 0.0
	c.anchor_right = h_anchor_right
	c.anchor_bottom = 0.0
	c.offset_left = off_left
	c.offset_top = _BAND_TOP_PX
	c.offset_right = off_right
	c.offset_bottom = _BAND_TOP_PX + _BAND_HEIGHT_PX


# --- Arena-injected player ref (for the focus model's hp_ratio input) ---
func set_player(p: Node2D) -> void:
	# Called by Arena._ready after the HUD enters the tree. Resolves the player's HealthComponent
	# (node-name convention) and read-only-subscribes to health_changed for the focus model. HP is
	# intra-entity (D8) — this is a display-side subscribe, never an emit.
	_player = p
	_player_health = null
	if p != null:
		var hc: Node = p.get_node_or_null(_HEALTH_NODE_NAME)
		if hc is HealthComponent:
			_player_health = hc as HealthComponent
			if not _player_health.health_changed.is_connected(_on_health_changed):
				_player_health.health_changed.connect(_on_health_changed)
	_recompute_focus()  # recompute once on bind so an already-low-HP player dims promptly


# --- EventBus signal handlers (route to readouts; AC9) ---
func _on_score_changed(value: int) -> void:
	_score.set_score(value)


func _on_ship_count_changed(ships_remaining: int) -> void:
	# Routes BOTH ship_lost (a ship spent) AND ship_gained (a ship regained, Story 2.5 Keep) to the pip
	# row — both carry the remaining count, so one handler covers both. set_ships clamps the lit count to
	# _pip_row_count (BASE_SHIPS, 3 in E2): a keep over the cap is a graceful no-op-clamp visually (RunState
	# still clamps to MAX_SHIPS = 5; the HUD cap is display-only and out of scope for 2.5).
	_lives.set_ships(ships_remaining, _pip_row_count)


func _on_wave_started(wave: int, duration_s: float) -> void:
	_wave_mod.set_wave(wave)
	_wave_timer.start(wave, duration_s)
	_exit_focus()  # a fresh wave is a calm moment — drop out of focus_fade


func _on_wave_cleared(_wave: int) -> void:
	_wave_timer.stop()
	_exit_focus()  # between-wave is calm


func _on_arc_t_changed(_t: float) -> void:
	# Dormant in E1 (no emitter until Story 3.9). Each readout subscribes independently for its own
	# recolor; the conductor has no arc_t work this epic.
	pass


func _on_health_changed(_current: int, _maximum: int) -> void:
	# Player HP changed — recompute focus (low HP raises intensity). The on-ship health_bar handles
	# its own redraw; this drives only the focus model's hp_ratio input.
	_recompute_focus()


func _on_low_time_entered() -> void:
	# Edge-triggered by WaveTimer crossing low_time_threshold_s — the time-pressure half of AC8/Task
	# 6.4 that HP changes alone cannot cover (a clean wave with no damage never fires health_changed).
	_recompute_focus()


func _on_game_over() -> void:
	# Run ended — freeze the countdown and drop out of focus_fade so neither keeps advancing during
	# the (possibly non-immediate, e.g. auto_replay_on_loss = false in tests) window before teardown.
	_wave_timer.stop()
	_exit_focus()


# --- Focus/fade FSM (UX S1 / arch D15) ---
func set_focus_dimmed(dimmed: bool) -> void:
	# Called by the focus/fade states on enter(). Dim score + modifier chrome; timer + lives stay
	# sharp (the on-ship HP bar is never dimmed — it's not a HUD child). Null-guarded: the FSM's
	# initial enter() fires (child _ready) before this conductor builds the readouts (_ready), and the
	# standard state requests dimmed=false whose target alpha == the default (1.0) ⇒ a no-op skip is
	# correct. By the time focus_fade could ever engage, the readouts exist.
	if _score == null or _wave_mod == null:
		return
	var a: float = FOCUS_DIM_ALPHA if dimmed else 1.0
	_score.modulate.a = a
	_wave_mod.modulate.a = a


func _recompute_focus() -> void:
	# Event-driven (health_changed, wave start/clear, player bind) — NOT per-frame (AC9, arch D15
	# "on events / a throttle, not per-frame"). E1 passes 0 for the forward-compat axes
	# (projectiles/captors — no central counter / no captors until Epic 2).
	if _focus_model == null or _wave_timer == null:
		return
	var hr: float = _hp_ratio()
	# Feed the remaining time ONLY while the wave timer is running — an unstarted/stopped timer has
	# _remaining == 0, which would otherwise read as "time up" and force focus_fade between waves.
	var tr: float = _wave_timer.get_time_remaining() if _wave_timer.is_running() else 999.0
	var value: float = _focus_model.intensity(0, 0, hr, tr)
	var want: bool = _focus_model.should_focus(_focus_active, value)
	if want != _focus_active:
		_focus_active = want
		_focus_fsm.transition_to(_focus_fade_state if want else _standard_state)


func _exit_focus() -> void:
	if _focus_active:
		_focus_active = false
		_focus_fsm.transition_to(_standard_state)


func _hp_ratio() -> float:
	if _player_health == null or _player_health.max_hp <= 0:
		return 1.0  # unknown ⇒ treat as healthy (no spurious focus_fade)
	return float(_player_health.current_hp) / float(_player_health.max_hp)
