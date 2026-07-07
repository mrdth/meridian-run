extends GutTest
# WaveController lifecycle FSM (Story 1.8 / AC1, AC2): Idle → Intro → Active → Completed (→ Intro
# replay) | Failed (game_over). Owns wave timing (wave_duration_s), emits wave_started/wave_cleared,
# drives the spawner's begin_wave/stop, heals the player on clear, and CLOSES the 1.5-deferred
# set_active-while-expired footgun (no double-fire of wave_cleared / no double-advance — verified by
# test_no_double_fire_on_huge_delta).

const GruntScene := preload("res://enemies/grunt.tscn")
const ShielderScene := preload("res://enemies/shielder.tscn")
const BomberScene := preload("res://enemies/bomber.tscn")
const WaveControllerScene := preload("res://world/wave_controller.tscn")
const PlayerScene := preload("res://player/player.tscn")


func before_each() -> void:
	Pool.clear()


func _make_controller() -> WaveController:
	# A WaveController wired to a real drip-only spawner under a Node2D arena. wave_duration_s is
	# short (0.5s) so tests can drive completion in a few steps. The controller's player is left
	# unset (null) — heal_player_to_full() guards; tests that need it set wc.player. The spawner is
	# added to the tree (so its _ready builds the enemy container) but is NOT stepped — only the
	# controller's StateMachine is stepped, so no enemies actually drip (clean FSM assertions).
	var arena := Node2D.new()
	add_child(arena)
	var wc: WaveController = WaveControllerScene.instantiate()
	wc.wave_duration_s = 0.5
	arena.add_child(wc)  # _ready: StateMachine auto-enters Idle, subscribes game_over
	var spawner := FormationSpawner.new()
	spawner.grunt_scene = GruntScene
	spawner.shielder_scene = ShielderScene
	spawner.bomber_scene = BomberScene
	spawner.drip_interval_s = 0.2
	spawner.per_tick_base = 1
	spawner.per_tick_growth = 0.0
	spawner.max_per_tick = 2
	arena.add_child(spawner)  # _ready: builds _container, loads formation_def
	spawner.player = Node2D.new()
	arena.add_child(spawner.player)
	spawner.run_state = RunState.new()
	spawner.run_state.begin_run()
	wc.spawner = spawner
	wc.run_state = spawner.run_state
	return wc


func test_start_run_emits_wave_started_and_enters_active() -> void:
	# start_run → Intro (emit wave_started(wave, duration)) → Active. The auto-entered Idle state
	# must NOT have emitted wave_started before start_run (the footgun-guard for premature start).
	var wc := _make_controller()
	watch_signals(EventBus)
	# Before start_run: Idle, no wave_started emitted.
	assert_eq(wc.get_state_name(), "WaveIdleState")
	assert_signal_emit_count(EventBus, "wave_started", 0)
	wc.start_run()
	assert_signal_emit_count(EventBus, "wave_started", 1)
	var params: Array = get_signal_parameters(EventBus, "wave_started")
	assert_eq(params[0], 1)      # wave number
	assert_eq(params[1], 0.5)    # countdown duration (carries to the HUD wave-timer)
	assert_eq(wc.get_state_name(), "WaveActiveState")


func test_timer_expiry_completes_and_replays() -> void:
	# Stepping past wave_duration_s → Completed (wave_cleared + heal + wave_num++) → Intro → Active
	# (wave_started again). AC2: HP full-heals and the wave replays for feel-testing.
	var wc := _make_controller()
	watch_signals(EventBus)
	wc.start_run()
	# 0.5s duration; step ~0.67s → one completion + replay into wave 2.
	for _i in 40:
		wc._state_machine._physics_process(1.0 / 60.0)
	assert_signal_emit_count(EventBus, "wave_cleared", 1)
	assert_signal_emit_count(EventBus, "wave_started", 2)  # wave 1 + replayed wave 2
	assert_eq(wc.wave_num, 2)
	assert_eq(wc.get_state_name(), "WaveActiveState")  # replayed into Active


func test_no_double_fire_on_huge_delta() -> void:
	# Deferred-#1 footgun guard: a single physics step with a delta FAR exceeding wave_duration
	# fires wave_cleared EXACTLY ONCE and advances the wave by exactly one. Active.physics_process
	# transitions out (resetting _wave_time), so the surplus delta can never stack completions.
	var wc := _make_controller()
	watch_signals(EventBus)
	wc.start_run()
	wc._state_machine._physics_process(5.0)  # 10× the 0.5s duration, in ONE step
	assert_signal_emit_count(EventBus, "wave_cleared", 1)  # not 10×
	assert_eq(wc.wave_num, 2)  # advanced exactly one wave


func test_heal_player_to_full() -> void:
	# AC2 unit: heal_player_to_full() restores the player's HealthComponent to max. The player is
	# parented under a Node2D (the real arena is Node2D — player._ready assigns
	# fire_system.projectile_parent = get_parent(), typed Node2D).
	var wc := _make_controller()
	var host := Node2D.new()
	add_child(host)
	var player: Player = PlayerScene.instantiate()
	host.add_child(player)
	wc.player = player
	var health: HealthComponent = player.get_node("HealthComponent")
	health.take_damage(1)  # 3 → 2
	assert_lt(health.current_hp, health.max_hp)
	wc.heal_player_to_full()
	assert_eq(health.current_hp, health.max_hp)


func test_game_over_transitions_to_failed_and_stops_spawner() -> void:
	# Arena emits game_over on run-loss → WaveController (subscribed in _ready) → WaveFailedState,
	# and the spawner is stopped (no dripping after death). Guarded: only transitions if mid-wave.
	var wc := _make_controller()
	wc.start_run()
	assert_eq(wc.get_state_name(), "WaveActiveState")
	assert_true(wc.spawner.is_physics_processing())  # dripping (begin_wave set it true)
	EventBus.game_over.emit()
	assert_eq(wc.get_state_name(), "WaveFailedState")
	assert_false(wc.spawner.is_physics_processing())  # stop() halted the drip


func test_failed_is_terminal_no_replay() -> void:
	# Once Failed, stepping the FSM must NOT replay or emit further wave signals (terminal for the
	# E1 placeholder; Arena's deferred reload handles the restart).
	var wc := _make_controller()
	watch_signals(EventBus)
	wc.start_run()
	EventBus.game_over.emit()
	var cleared_before: int = get_signal_emit_count(EventBus, "wave_cleared")
	var started_before: int = get_signal_emit_count(EventBus, "wave_started")
	for _i in 120:
		wc._state_machine._physics_process(1.0 / 60.0)
	assert_eq(get_signal_emit_count(EventBus, "wave_cleared"), cleared_before)
	assert_eq(get_signal_emit_count(EventBus, "wave_started"), started_before)
	assert_eq(wc.get_state_name(), "WaveFailedState")
