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


func test_wave_cleared_heals_player_and_advances_wave() -> void:
	# AC4: on wave_cleared, per-wave HP resets to full + the minimal next-wave loop advances.
	var arena := _make()
	_clear_iframes(arena)
	arena._player._health.take_damage(2)  # 3 -> 1 (sub-lethal, observable heal target)
	assert_eq(arena._player._health.current_hp, 1)
	var wave_before: int = arena._wave_num
	EventBus.wave_cleared.emit(arena._wave_num)  # the spawner's timer-expiry signal
	assert_eq(arena._player._health.current_hp, arena._player._health.max_hp)  # full heal
	assert_eq(arena._wave_num, wave_before + 1)  # next wave began
