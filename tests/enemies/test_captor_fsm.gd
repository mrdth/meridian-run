extends GutTest
# Integration tests for the Captor entity + its 5-state FSM (Story 2.1, Task 10). Mirrors the
# pool-fixture style of tests/enemies/test_enemy.gd. Instantiates captor.tscn with a TEST
# CaptorTuning (0.1 s durations so transitions are observable in a few frames) + a mock player_target
# Node2D, drives the StateMachine by hand, and asserts: variant wiring (layer/faction/HP), the 5
# transitions fire in order, state_changed emits in order, the capture column is active during
# telegraph + capture and released on dive, transitions honor the test-tuning durations, the dive
# releases the captor to the pool (one pass), and a kill mid-telegraph carries score 0 + releases.

const CaptorScene := preload("res://enemies/captor/captor.tscn")
const ColumnScene := preload("res://world/capture_column.tscn")


func before_each() -> void:
	Pool.clear()


func _test_tuning() -> CaptorTuning:
	# Tiny durations so each state lasts ~0.1 s (6 frames at 60 Hz) — observable without a long run.
	var t := CaptorTuning.new()
	t.enter_duration_s = 0.1
	t.formation_duration_min_s = 0.1
	t.formation_duration_max_s = 0.1
	t.telegraph_duration_s = 0.1
	t.capture_duration_s = 0.1
	t.dive_duration_s = 0.1
	t.formation_row_y = 150.0
	t.side_drift_amplitude_px = 130.0
	t.side_drift_period_s = 3.0
	t.dive_aim_track_factor = 0.3
	t.dive_offscreen_margin_px = 48.0
	t.capture_column_width_px = 60.0
	return t


func _setup(player_pos: Vector2 = Vector2(640.0, 680.0)) -> Dictionary:
	# acquire → add_child, swap in the fast test tuning, create a mock player_target. Does NOT activate
	# — split out so a test can connect to signals BEFORE activate (e.g. to catch the initial "enter").
	var container := Node2D.new()
	add_child_autofree(container)
	var captor: Captor = Pool.acquire(CaptorScene) as Captor
	container.add_child(captor)
	captor.tuning = _test_tuning()  # override the scene's captor_tuning.tres (slow GDD durations)
	var player := Node2D.new()
	add_child_autofree(player)
	player.global_position = player_pos
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	return {"captor": captor, "player": player, "rng": rng}


func _activate(s: Dictionary, spawn: Vector2 = Vector2(640.0, -80.0)) -> Captor:
	# activate + disable the StateMachine/EnemyFireSystem tree ticks so the FSM is driven by hand.
	var captor: Captor = s.captor
	captor.activate(s.player, spawn, s.rng)
	captor.get_node("StateMachine").set_physics_process(false)
	captor.get_node("EnemyFireSystem").set_physics_process(false)
	return captor


func _make(player_pos: Vector2 = Vector2(640.0, 680.0)) -> Captor:
	# acquire → add_child → activate (so @onready refs are valid in activate). Override the scene's
	# tuning with the fast test tuning + inject a mock player_target. Disable the StateMachine +
	# EnemyFireSystem tree ticks so we drive the FSM deterministically by hand (mirrors test_enemy.gd).
	return _activate(_setup(player_pos))


# --- wiring (mirror test_enemy.gd's variant checks) ---

func test_captor_on_enemy_layer_mask_zero() -> void:
	var c := _make()
	assert_eq(c.collision_layer, Constants.LAYER_ENEMY)
	assert_eq(c.collision_mask, 0)


func test_definition_wired_with_captor_stats() -> void:
	var c := _make()
	assert_eq(c.definition.id, &"captor")
	assert_eq(c.definition.max_hp, 60)
	assert_eq(c.definition.score_value, 0)  # GDD: captor score is "—"
	var hc: HealthComponent = c.get_node("HealthComponent")
	assert_eq(hc.max_hp, 60)
	assert_eq(hc.current_hp, 60)


func test_faction_is_enemy() -> void:
	var c := _make()
	var fc: FactionComponent = c.get_node("FactionComponent")
	assert_eq(fc.faction, FactionComponent.Faction.ENEMY)


func test_captor_has_healthbar_bound_for_dive_kill_read() -> void:
	# The captor carries a HealthBar so the player can read hits-left + time the dive-kill rescue. It
	# binds to the captor's HealthComponent (one segment per player shot: hp_per_segment=10, max_hp=60
	# ⇒ 6 segments = 6 shots to kill) + hides at full HP (H6 — the read appears once the player chips it).
	var c := _make()
	var hb: HealthBar = c.get_node_or_null("HealthBar")
	assert_not_null(hb, "the captor should have a HealthBar child")
	assert_eq(hb.hp_per_segment, 10, "one segment per player shot (projectile_damage = 10)")
	assert_true(hb.hide_when_full, "the captor bar should hide at full HP (H6)")
	assert_eq(hb._health, c.get_node("HealthComponent"), "the bar should bind to the captor's HealthComponent")
	assert_eq(hb._seg_total, 6, "60 HP / 10 per segment = 6 segments (6 shots to kill)")
	assert_false(hb.visible, "the bar should be hidden at full HP (hide_when_full)")


# --- the 5-state progression (AC#1–#4) ---

func test_fsm_progresses_through_five_states_in_order() -> void:
	var c := _make()
	var sm: StateMachine = c.get_node("StateMachine")
	var enter: State = c.get_node("StateMachine/EnterState")
	var form: State = c.get_node("StateMachine/FormationState")
	var tele: State = c.get_node("StateMachine/TelegraphState")
	var cap: State = c.get_node("StateMachine/CaptureState")
	var dive: State = c.get_node("StateMachine/DiveState")
	var seen: Array = []
	for _i in 600:
		if c.get_parent() == null:
			break  # released — should not happen mid-cycle here, but guard
		sm._physics_process(1.0 / 60.0)
		var cur: State = sm.current_state
		if seen.is_empty() or seen[-1] != cur:
			seen.append(cur)
			if cur == dive:
				break
	assert_eq(seen.size(), 5, "did not visit all 5 states")
	assert_eq(seen[0], enter)
	assert_eq(seen[1], form)
	assert_eq(seen[2], tele)
	assert_eq(seen[3], cap)
	assert_eq(seen[4], dive)


func test_state_changed_emits_in_order() -> void:
	# Connect a recorder BEFORE activate so the initial "enter" emit is captured (state_changed emits
	# on every transition via the captor's to_X() helpers: enter→formation→telegraph→capture→dive).
	var s := _setup()
	var captor: Captor = s.captor
	var sequence: Array = []
	captor.state_changed.connect(func(state: StringName) -> void: sequence.append(state))
	_activate(s)
	var sm: StateMachine = captor.get_node("StateMachine")
	var dive: State = captor.get_node("StateMachine/DiveState")
	for _i in 600:
		if captor.get_parent() == null or sm.current_state == dive:
			break
		sm._physics_process(1.0 / 60.0)
	assert_eq(sequence.size(), 5)
	assert_eq(sequence[0], &"enter")
	assert_eq(sequence[1], &"formation")
	assert_eq(sequence[2], &"telegraph")
	assert_eq(sequence[3], &"capture")
	assert_eq(sequence[4], &"dive")
	# current_state_name tracks the latest (load-bearing for 2.3's rescue branch).
	assert_eq(captor.current_state_name, &"dive")


func test_transitions_honor_tuning_durations() -> void:
	# The fair-dodge window (AC#3) is the load-bearing timing. With telegraph_duration_s = 0.1 s,
	# telegraph lasts ~6 frames at 60 Hz. Count frames-in-telegraph and assert the window is honored.
	var c := _make()
	var sm: StateMachine = c.get_node("StateMachine")
	var tele: State = c.get_node("StateMachine/TelegraphState")
	for _i in 200:  # reach telegraph (enter 6fr + formation 6fr)
		sm._physics_process(1.0 / 60.0)
		if sm.current_state == tele:
			break
	assert_eq(sm.current_state, tele)
	var frames_in_tele := 0
	for _i in 30:
		if sm.current_state != tele:
			break
		sm._physics_process(1.0 / 60.0)
		frames_in_tele += 1
	# 0.1 s / (1/60) ≈ 6 frames; allow 5–8 for the discrete step boundary.
	assert_between(frames_in_tele, 5, 8)


func test_capture_column_active_during_telegraph_and_capture() -> void:
	var c := _make()  # player at x=640
	var sm: StateMachine = c.get_node("StateMachine")
	var tele: State = c.get_node("StateMachine/TelegraphState")
	var cap: State = c.get_node("StateMachine/CaptureState")
	var dive: State = c.get_node("StateMachine/DiveState")
	# Reach telegraph → the column is acquired + visible + locked to the player's x (AC#3).
	for _i in 200:
		sm._physics_process(1.0 / 60.0)
		if sm.current_state == tele:
			break
	assert_not_null(c.capture_column, "no capture column acquired on telegraph")
	assert_true(c.capture_column.visible)
	assert_almost_eq(c.capture_column.global_position.x, 640.0, 0.5, "column did not lock to the player's x")
	# Through capture → column still held.
	for _i in 30:
		sm._physics_process(1.0 / 60.0)
		if sm.current_state == cap:
			break
	assert_not_null(c.capture_column)
	# Into dive → dive-enter releases the column (ref nulled immediately; Pool return deferred).
	for _i in 40:
		sm._physics_process(1.0 / 60.0)
		if sm.current_state == dive:
			break
	assert_null(c.capture_column, "capture column not released on dive enter")


func test_dive_releases_captor_to_pool() -> void:
	# AC#4 / Open Question D (one pass): after the dive the captor releases to the pool (NOT re-enter).
	var c := _make()
	var sm: StateMachine = c.get_node("StateMachine")
	var dive: State = c.get_node("StateMachine/DiveState")
	# Step until dive is reached.
	for _i in 200:
		sm._physics_process(1.0 / 60.0)
		if sm.current_state == dive:
			break
	# Step just past dive completion (0.1 s = ~6 frames) so _t crosses 1.0 and queues the deferred
	# self-release (bounded — keeps the idempotent re-queue to a couple of frames).
	for _i in 10:
		sm._physics_process(1.0 / 60.0)
	# Await so the deferred _release_to_pool lands at idle (direct stepping doesn't run deferred calls).
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(c.get_parent(), null, "captor was not released to the pool after its dive")


func test_captor_descends_to_formation_row_on_enter() -> void:
	# AC#1: descends from off-screen to the formation row over enter_duration_s.
	var c := _make()
	var sm: StateMachine = c.get_node("StateMachine")
	var form: State = c.get_node("StateMachine/FormationState")
	# Spawn was off-screen top (y=-80). Step until formation reached.
	for _i in 200:
		sm._physics_process(1.0 / 60.0)
		if sm.current_state == form:
			break
	# On reaching formation, the captor sits at formation_row_y (150).
	assert_almost_eq(c.global_position.y, 150.0, 1.0, "captor did not descend to formation_row_y")


func test_kill_mid_telegraph_carries_zero_score_and_releases() -> void:
	# AC#6: killable by player fire (HP-based), dies with score 0 + pool release; also releases the
	# held column (so a telegraph kill doesn't leave the column locked on-screen).
	var c := _make()
	var sm: StateMachine = c.get_node("StateMachine")
	var tele: State = c.get_node("StateMachine/TelegraphState")
	watch_signals(c)
	for _i in 200:
		sm._physics_process(1.0 / 60.0)
		if sm.current_state == tele:
			break
	assert_not_null(c.capture_column)  # holding the column mid-telegraph
	var hc: HealthComponent = c.get_node("HealthComponent")
	hc.take_damage(60)  # 60 hp → 0 → _on_died → died(0, rescue, at)
	# Story 2.3 — died now carries (score_value, rescue, at). A telegraph-kill is NOT a rescue
	# (rescue = dive + captured_player; telegraph is neither) → rescue == false. The position `at`
	# equals global_position (verified in test_captor_died_signal.gd).
	assert_signal_emitted(c, "died")
	var died_params: Array = get_signal_parameters(c, "died")
	assert_eq(died_params.size(), 3, "died must emit 3 params (score_value, rescue, at)")
	assert_eq(died_params[0], 0)  # score_value = 0 (captor score is "—")
	assert_false(died_params[1], "a telegraph-kill must be failed-rescue (rescue == false)")
	assert_null(c.capture_column, "held column not released on death")
	# The self-release is deferred — await so it lands.
	await get_tree().physics_frame
	assert_eq(c.get_parent(), null, "captor not released to the pool on death")
