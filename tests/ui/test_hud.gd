extends GutTest
# Integration tests for the HUD conductor (Story 1.7 / AC9). Drives the EventBus signals the HUD
# subscribes to and asserts each readout updates; verifies the focus/fade FSM transitions on low HP
# and low time, and that the wave-timer counts down + stops. arc_t_changed is emitted to confirm the
# calm-path subscription is safe (dormant in E1). Mirrors the 1.6 GUT style (before_each Pool.clear()).

const HudScene := preload("res://ui/hud/hud.tscn")


func before_each() -> void:
	Pool.clear()


func _make_hud() -> Hud:
	var hud: Hud = HudScene.instantiate()
	add_child_autofree(hud)
	return hud


func _make_player(max_hp: int = 3) -> CharacterBody2D:
	# Minimal player stub: a CharacterBody2D with a HealthComponent child (the node-name convention
	# the HUD resolves in set_player). Real-enough for the focus model's hp_ratio input.
	var p := CharacterBody2D.new()
	p.name = "Player"
	var hc := HealthComponent.new()
	hc.name = "HealthComponent"
	hc.max_hp = max_hp
	p.add_child(hc)
	add_child_autofree(p)
	return p


func _health(of: CharacterBody2D) -> HealthComponent:
	return of.get_node("HealthComponent")


func test_hud_seeds_score_and_lives() -> void:
	var hud := _make_hud()
	assert_eq(hud._score._value_label.text, "0")
	assert_eq(hud._lives._remaining, Constants.BASE_SHIPS)  # 3
	# Pip row shows ONLY earned lives (BASE_SHIPS = 3), NOT the run cap (MAX_SHIPS = 5) — no phantom
	# "un-earned" pips.
	assert_eq(hud._lives._maximum, Constants.BASE_SHIPS)    # 3, not 5


func test_ship_lost_keeps_pip_row_count_and_dims_a_pip() -> void:
	# The pip row count stays at the starting 3 as ships are lost (the lost pip dims, it is not
	# removed) — the gamble read (UX S1) holds without showing the un-earned cap.
	var hud := _make_hud()
	assert_eq(hud._lives._maximum, 3)
	EventBus.ship_lost.emit(2)  # 2 ships remaining — lost one
	assert_eq(hud._lives._maximum, 3)      # row still shows 3 pips
	assert_eq(hud._lives._remaining, 2)    # 2 lit


func test_score_changed_updates_readout() -> void:
	var hud := _make_hud()
	EventBus.score_changed.emit(1234)
	assert_eq(hud._score._value_label.text, "1234")


func test_ship_lost_updates_lives_pips() -> void:
	var hud := _make_hud()
	EventBus.ship_lost.emit(2)  # 2 ships remaining
	assert_eq(hud._lives._remaining, 2)


func test_wave_started_seeds_timer_and_wave_number() -> void:
	var hud := _make_hud()
	EventBus.wave_started.emit(5, 30.0)
	assert_eq(hud._wave_mod._wave_label.text, "WAVE 5")
	assert_eq(hud._wave_timer._numeric_label.text, "30")  # ceil(30)
	assert_true(hud._wave_timer._running)


func test_wave_timer_counts_down_and_stops_at_zero() -> void:
	var hud := _make_hud()
	EventBus.wave_started.emit(1, 30.0)
	for _i in 60:
		hud._wave_timer._process(0.5)  # 60 × 0.5s = 30s elapsed → reaches 0
	assert_false(hud._wave_timer._running)
	assert_eq(hud._wave_timer._numeric_label.text, "0")


func test_wave_timer_low_time_shows_hazard_color_and_white_glow() -> void:
	# AC5: at low-time the numeric shifts to HAZARD with a neutral-white outline glow (not primary).
	var hud := _make_hud()
	EventBus.wave_started.emit(1, 30.0)
	for _i in 41:
		hud._wave_timer._process(0.5)  # 20.5s elapsed → ~9.5s remaining, below the 10s threshold
	var numeric: Label = hud._wave_timer._numeric_label
	assert_eq(numeric.get_theme_color("font_color"), HudPalette.HAZARD)
	assert_eq(numeric.get_theme_color("font_outline_color"), HudPalette.WHITE)


func test_wave_timer_stays_hazard_colored_at_expiry() -> void:
	# Regression: stop() (called the instant _remaining hits 0) must not revert the numeral to its
	# calm color on the same frame it expires — the moment of maximum urgency.
	var hud := _make_hud()
	EventBus.wave_started.emit(1, 30.0)
	for _i in 60:
		hud._wave_timer._process(0.5)  # reaches exactly 0
	var numeric: Label = hud._wave_timer._numeric_label
	assert_eq(numeric.get_theme_color("font_color"), HudPalette.HAZARD)
	assert_eq(numeric.get_theme_color("font_outline_color"), HudPalette.WHITE)


func test_wave_cleared_stops_timer() -> void:
	var hud := _make_hud()
	EventBus.wave_started.emit(1, 30.0)
	assert_true(hud._wave_timer._running)
	EventBus.wave_cleared.emit(1)
	assert_false(hud._wave_timer._running)


func test_arc_t_changed_does_not_crash_calm_path() -> void:
	# Dormant in E1 — emitting it (as Story 3.9 will) must be safe; the HUD stays calm.
	var hud := _make_hud()
	EventBus.arc_t_changed.emit(0.0)
	EventBus.arc_t_changed.emit(0.5)
	assert_true(is_instance_valid(hud))


func test_low_hp_engages_focus_fade_and_dims_chrome() -> void:
	var hud := _make_hud()
	var p := _make_player(3)
	hud.set_player(p)
	assert_false(hud._focus_active)  # full HP (3/3) → standard
	# Drop to 1/3 HP (ratio 0.33 ≤ hp_critical_ratio 0.5) ⇒ hp_axis 1.0 ⇒ intensity 1.0 ≥ enter.
	var hc: HealthComponent = _health(p)
	hc.current_hp = 1
	hc.health_changed.emit(1, 3)
	assert_true(hud._focus_active)
	# Score + modifier chrome dim; timer + lives stay sharp (S1).
	assert_almost_eq(hud._score.modulate.a, Hud.FOCUS_DIM_ALPHA, 0.01)
	assert_almost_eq(hud._wave_mod.modulate.a, Hud.FOCUS_DIM_ALPHA, 0.01)
	assert_almost_eq(hud._wave_timer.modulate.a, 1.0, 0.01)
	assert_almost_eq(hud._lives.modulate.a, 1.0, 0.01)


func test_heal_back_drops_out_of_focus() -> void:
	var hud := _make_hud()
	var p := _make_player(3)
	hud.set_player(p)
	var hc: HealthComponent = _health(p)
	hc.current_hp = 1
	hc.health_changed.emit(1, 3)
	assert_true(hud._focus_active)
	# Heal to full ⇒ hp_ratio 1.0 ⇒ intensity 0 < exit ⇒ standard.
	hc.current_hp = 3
	hc.health_changed.emit(3, 3)
	assert_false(hud._focus_active)
	assert_almost_eq(hud._score.modulate.a, 1.0, 0.01)


func test_low_time_engages_focus_fade() -> void:
	# With the timer running and time low, the time axis alone drives focus at full HP — no HP change
	# involved. WaveTimer.low_time_entered (Task 6.4) fires the recompute directly; ticking the timer
	# down through the threshold is the only trigger needed.
	var hud := _make_hud()
	var p := _make_player(3)
	hud.set_player(p)
	EventBus.wave_started.emit(1, 30.0)
	for _i in 54:
		hud._wave_timer._process(0.5)  # 27s elapsed → ~3s remaining (time_axis 0.7 ≥ enter 0.6)
	assert_true(hud._focus_active)


func test_game_over_stops_timer_and_exits_focus() -> void:
	var hud := _make_hud()
	var p := _make_player(3)
	hud.set_player(p)
	EventBus.wave_started.emit(1, 30.0)
	var hc: HealthComponent = _health(p)
	hc.current_hp = 1
	hc.health_changed.emit(1, 3)
	assert_true(hud._focus_active)
	EventBus.game_over.emit()
	assert_false(hud._wave_timer._running)
	assert_false(hud._focus_active)
