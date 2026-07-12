extends GutTest
# Story 2.3 (Task 8) — integration tests for Arena._on_captor_resolved (the run-scope rescue /
# failed-rescue resolution, AC#1 + AC#2). The spawner routes captor deaths via the local captor_resolved
# signal; Arena resolves: rescue → player.try_dock_ship (NO ship-count change); failed-rescue →
# spawner.spawn_enemy_at (+1 enemy, NO ship-count change — the epics AC2 "−1 ship" is relative-accounting
# vs the Keep +1, NOT a spend; Mrdth-confirmed). NO respawn, NO ship_lost, NO game_over on failed-rescue.
# Mirrors test_arena.gd (arena.tscn + halted spawner). Emits captor_resolved directly to drive Arena.

const ArenaScene := preload("res://world/arena.tscn")


func before_each() -> void:
	Pool.clear()


func _make() -> Arena:
	# arena.tscn wires FormationSpawner + Player; Arena._ready runs begin_run + connects captor_resolved.
	# Halt the spawner's drip so the only enemy spawns are the ones we drive via captor_resolved.
	var arena: Arena = ArenaScene.instantiate() as Arena
	add_child_autofree(arena)
	arena._spawner.set_active(false)
	return arena


# --- rescue (AC#1): dock a fighter, NO ship-count change ---

func test_rescue_docks_a_docked_ship() -> void:
	# captor_resolved(true, at) → player.try_dock_ship → _docked == true + a DockedShip child.
	var arena := _make()
	assert_false(arena._player.is_docked(), "precondition: player starts clean")
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)
	assert_true(arena._player.is_docked(), "rescue should dock a wingman")
	assert_not_null(arena._player._docked_ship)


func test_rescue_does_not_change_ship_count() -> void:
	# The ONLY ship-count changes are capture (−1, 2.2) + keep (+1, 2.5). Rescue docks a fighter — NO
	# ship-count change, NO ship_lost emit.
	var arena := _make()
	watch_signals(EventBus)
	var ships_before: int = arena._run_state.ships
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)
	assert_eq(arena._run_state.ships, ships_before, "rescue must NOT change the ship count")
	assert_signal_emit_count(EventBus, "ship_lost", 0)


# --- failed-rescue (AC#2): +1 enemy, NO ship-count change, NO respawn ---

func test_failed_rescue_spawns_one_enemy() -> void:
	# captor_resolved(false, at) → spawn_enemy_at(at) → +1 enemy in the container.
	var arena := _make()
	var before: int = arena._spawner.get_active_count()
	arena._spawner.captor_resolved.emit(false, Vector2(500.0, 200.0))
	assert_eq(arena._spawner.get_active_count(), before + 1, "failed-rescue should spawn exactly one enemy")


func test_failed_rescue_does_not_change_ship_count_or_emit_loss() -> void:
	# Failed-rescue is NO ship-count change (relative-accounting, not a spend). NO ship_lost, NO game_over.
	var arena := _make()
	arena.auto_replay_on_loss = false
	watch_signals(EventBus)
	var ships_before: int = arena._run_state.ships
	arena._spawner.captor_resolved.emit(false, Vector2(500.0, 200.0))
	assert_eq(arena._run_state.ships, ships_before, "failed-rescue must NOT spend a ship")
	assert_signal_emit_count(EventBus, "ship_lost", 0)
	assert_signal_emit_count(EventBus, "game_over", 0)


func test_failed_rescue_does_not_respawn_player() -> void:
	# The player's ship is fine (they shot the captor, they weren't hit) → NO respawn. The player keeps
	# flying — position unchanged + HP unchanged.
	var arena := _make()
	var pos_before: Vector2 = arena._player.global_position
	var hp_before: int = arena._player._health.current_hp
	arena._spawner.captor_resolved.emit(false, Vector2(500.0, 200.0))
	assert_eq(arena._player.global_position, pos_before, "failed-rescue must NOT respawn (reposition) the player")
	assert_eq(arena._player._health.current_hp, hp_before, "failed-rescue must NOT change the player's HP")


# --- the failed-rescue enemy: faction, score-on-kill, turned visual (E) ---

func test_failed_rescue_enemy_is_on_enemy_layer() -> void:
	# The turned enemy is LAYER_ENEMY (via FactionComponent) — collision/faction stay grunt; the visual
	# change is cosmetic.
	var arena := _make()
	arena._spawner.captor_resolved.emit(false, Vector2(500.0, 200.0))
	var enemy: Enemy = arena._spawner._container.get_child(arena._spawner._container.get_child_count() - 1) as Enemy
	assert_not_null(enemy)
	assert_eq(enemy.collision_layer, Constants.LAYER_ENEMY)


func test_failed_rescue_enemy_gives_score_when_killed() -> void:
	# The turned enemy's died connects to _on_enemy_died → RunState.add_score + score_changed.
	var arena := _make()
	arena._spawner.captor_resolved.emit(false, Vector2(500.0, 200.0))
	watch_signals(EventBus)
	var enemy: Enemy = arena._spawner._container.get_child(arena._spawner._container.get_child_count() - 1) as Enemy
	var score_value: int = enemy.definition.score_value
	var score_before: int = arena._run_state.score
	enemy.get_node("HealthComponent").take_damage(100000)  # kill → died → _on_enemy_died → score.
	assert_eq(arena._run_state.score, score_before + score_value)
	assert_signal_emitted(EventBus, "score_changed")
	await get_tree().physics_frame  # let the deferred death-release land before teardown.


func test_failed_rescue_enemy_has_turned_ship_visual() -> void:
	# E — the turned enemy applies apply_turned_visual: the player arrowhead INVERTED (6-point chevron,
	# not the grunt's 3-point triangle) + scale.y < 0 (pointing down) + hazard color.
	var arena := _make()
	arena._spawner.captor_resolved.emit(false, Vector2(500.0, 200.0))
	var enemy: Enemy = arena._spawner._container.get_child(arena._spawner._container.get_child_count() - 1) as Enemy
	var visual: Polygon2D = enemy.get_node_or_null("Visual") as Polygon2D
	assert_not_null(visual)
	assert_eq(visual.polygon.size(), 6, "the turned enemy should use the 6-point player arrowhead, not the 3-point grunt triangle")
	assert_lt(visual.scale.y, 0.0, "the turned arrowhead should be inverted (pointing down)")
	# The grunt base is 3 points; a non-turned grunt (re-acquired normally) would be 3 + scale.y > 0.
	# This pins the turned-visual override applied by spawn_enemy_at.


func test_failed_rescue_enemy_died_connected_to_on_enemy_died() -> void:
	# The turned enemy's died connects to the spawner's _on_enemy_died (so it gives score when killed).
	var arena := _make()
	arena._spawner.captor_resolved.emit(false, Vector2(500.0, 200.0))
	var enemy: Enemy = arena._spawner._container.get_child(arena._spawner._container.get_child_count() - 1) as Enemy
	assert_true(enemy.died.is_connected(arena._spawner._on_enemy_died))
