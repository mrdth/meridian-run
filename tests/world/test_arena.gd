extends GutTest
# Integration tests for the Arena run host (Story 1.5 / AC1, AC3, AC4, AC5). Instantiates
# arena.tscn, drives the player to HP=0 (the real died→ship_depleted→handler chain), and
# asserts on RunState + EventBus signals. Mirrors the 1.4 GUT style.

const ArenaScene := preload("res://world/arena.tscn")


func before_each() -> void:
	Pool.clear()


func _make() -> Arena:
	# arena.tscn wires FormationSpawner + Player; Arena._ready runs begin_run, injects refs,
	# and starts wave 1. Halt the spawner so handler tests are deterministic (no enemies
	# spawning in the background while we assert on the ship economy).
	var arena: Arena = ArenaScene.instantiate() as Arena
	add_child_autofree(arena)
	arena._spawner.set_active(false)
	return arena


func _clear_iframes(arena: Arena) -> void:
	# Respawn / post-hit grants a 1s i-frame window; sequential lethal hits in a test need
	# the window cleared between them so the next hit actually lands.
	arena._player._health.set_invuln(0.0)


func test_run_starts_with_three_ships_and_zero_score() -> void:
	var arena := _make()
	assert_eq(arena._run_state.ships, Constants.BASE_SHIPS)  # 3
	assert_eq(arena._run_state.score, 0)


func test_first_ship_loss_respawns_and_emits_ship_lost() -> void:
	# HP=0 within the wave → player.ship_depleted → Arena spends a ship, respawns the player,
	# and broadcasts ship_lost(remaining). Drives the REAL died→ship_depleted chain.
	var arena := _make()
	watch_signals(EventBus)
	var max_hp: int = arena._player._health.max_hp
	arena._player._health.take_damage(max_hp)  # lethal → died → ship_depleted → handler
	assert_signal_emitted(EventBus, "ship_lost")
	var params: Array = get_signal_parameters(EventBus, "ship_lost")
	assert_eq(params[0], 2)  # 3 -> 2 remaining
	# Respawned: full HP + a fresh i-frame window for fair re-entry.
	assert_eq(arena._player._health.current_hp, max_hp)
	assert_true(arena._player._health.is_invulnerable())
	assert_eq(arena._run_state.ships, 2)


func test_losing_last_ship_emits_game_over() -> void:
	# Three sequential ship losses → ships hit 0 → EventBus.game_over (no reload: the test
	# guards the E1 auto-replay so it can't reset the GUT runner scene mid-suite).
	var arena := _make()
	arena.auto_replay_on_loss = false
	watch_signals(EventBus)
	for _i in 3:
		_clear_iframes(arena)  # drop the respawn window so the next lethal hit lands
		arena._player._health.take_damage(arena._player._health.max_hp)
	assert_signal_emitted(EventBus, "game_over")
	assert_eq(arena._run_state.ships, 0)


func test_wave_controller_heals_and_advances_on_timer_expiry() -> void:
	# AC2 (integration): the WaveController (wired by Arena in _ready) owns the wave lifecycle now —
	# on its timer expiry it full-heals the player and advances the wave (was Arena._on_wave_cleared
	# in 1.5). Drives the controller's FSM directly; the spawner is halted by _make() for determinism.
	var arena := _make()
	_clear_iframes(arena)
	arena._player._health.take_damage(2)  # 3 -> 1 (sub-lethal, observable heal target)
	assert_eq(arena._player._health.current_hp, 1)
	var wc: WaveController = arena._wave_controller
	var wave_before: int = wc.wave_num
	# Step the controller's FSM past wave_duration_s in one delta (the controller default is 60s;
	# one big step fires exactly one completion — the deferred-#1 footgun guard).
	wc._state_machine._physics_process(wc.wave_duration_s + 0.1)
	assert_eq(arena._player._health.current_hp, arena._player._health.max_hp)  # AC2 full heal
	assert_eq(wc.wave_num, wave_before + 1)  # advanced to the next wave


# --- F12 manual run reset ---

func test_reset_action_is_bound_to_f12() -> void:
	# F12 resets the run to wave 1 / full lives (Arena._unhandled_input → _reload_run_fresh). Pin the
	# InputMap binding so a future retune can't silently detach F12. The fresh-scene reload itself is the
	# SAME path a run-loss auto-replay uses (_reload_run_fresh, covered by the run-loss tests above with
	# auto_replay_on_loss=false) — not re-tested here, since reload_current_scene mid-test would reload the
	# GUT runner scene.
	assert_true(InputMap.has_action("reset"), "the 'reset' action must be defined (F12 reset)")
	var has_f12: bool = false
	for ev in InputMap.action_get_events("reset"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_F12:
			has_f12 = true
	assert_true(has_f12, "'reset' must be bound to F12 (physical_keycode KEY_F12)")
