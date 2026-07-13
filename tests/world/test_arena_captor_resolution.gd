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


# --- Story 2.4 — the WING track permanence invariant (AC#2 / NP1, architecture line 757) ---
# The headline of this story: the docked fighter's WING track is PERMANENT — it survives both consume
# paths (absorb + wave-clear). The consume paths live on the Player, which has NO RunState reference
# (AR2), so they structurally CANNOT clear the track. These tests pin that invariant end-to-end via the
# Arena (the run host that owns RunState + writes the WING track on rescue).

func test_rescue_grows_wing_track() -> void:
	# AC#2: a successful rescue dock earns the WING track (NP1 permanent identity). Arena writes it
	# (record_rescue) inside the successful-dock block; a blocked/no-op dock earns nothing.
	var arena := _make()
	assert_eq(arena._run_state.build_state.wing_level, 0, "precondition: wing track starts flat")
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)
	assert_eq(arena._run_state.build_state.wing_level, 1, "a rescue dock should grow the WING track by 1")


func test_blocked_dock_earns_no_wing_track() -> void:
	# A no-op dock (FR14 one-docked guard blocks a 2nd dock) must NOT earn a 2nd WING level — the
	# record_rescue call is inside the `if try_dock_ship():` block, mirroring the rescue-juice gate.
	var arena := _make()
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # 1st dock → wing_level 1
	assert_eq(arena._run_state.build_state.wing_level, 1)
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # 2nd dock blocked (FR14)
	assert_eq(arena._run_state.build_state.wing_level, 1, "a blocked (no-op) dock must NOT earn a 2nd WING level")


func test_absorb_does_not_clear_wing_track() -> void:
	# AC#2 / NP1 — the ABSORB consume path: the docked fighter dies on the first hit (HP spared), but the
	# WING track is UNCHANGED. The consume path (Player._consume_docked_ship) has no RunState ref (AR2) →
	# it structurally cannot reach build_state. This is the headline permanence assertion.
	var arena := _make()
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # dock via rescue → wing_level 1
	assert_eq(arena._run_state.build_state.wing_level, 1, "precondition: rescue earned the WING track")
	assert_true(arena._player.is_docked(), "precondition: player is docked")
	# Drive the absorber: a hit while docked consumes the fighter (HP spared), undocks the player.
	arena._player.apply_hit(2, arena._player.global_position, arena._player, false)
	assert_false(arena._player.is_docked(), "the absorber should have consumed the fighter (undocked)")
	assert_eq(arena._run_state.build_state.wing_level, 1, "absorb must NOT clear the WING track (NP1)")
	await get_tree().physics_frame  # let the deferred queue_free of the fighter land before teardown.


func test_wave_clear_does_not_clear_wing_track() -> void:
	# AC#2 / NP1 — the WAVE-CLEAR consume path: wave-end detaches the fighter node (wave-scope cleanup),
	# but the WING track is UNCHANGED. The keep path (Player._on_wave_cleared) has no RunState ref (AR2).
	# wave_cleared's only other subscriber is the HUD (cosmetic) — the WaveController emits but does not
	# listen, so a manual emit here drives only the player's detach.
	var arena := _make()
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # dock via rescue → wing_level 1
	assert_eq(arena._run_state.build_state.wing_level, 1, "precondition: rescue earned the WING track")
	assert_true(arena._player.is_docked(), "precondition: player is docked")
	# Wave-clear detaches the fighter (Player._on_wave_cleared → _detach_docked_ship). set_docked(false) is
	# synchronous, so is_docked() flips immediately; the node free is deferred.
	EventBus.wave_cleared.emit(1)
	assert_false(arena._player.is_docked(), "wave-clear should have detached the fighter (undocked)")
	assert_eq(arena._run_state.build_state.wing_level, 1, "wave-clear must NOT clear the WING track (NP1)")
	await get_tree().physics_frame  # let the deferred detach (queue_free) land before teardown.


func test_wing_track_survives_absorb_then_wave_clear() -> void:
	# Combined path: rescue → absorb (fighter consumed) → a 2nd rescue re-docks → wave-clear detaches.
	# The WING track only ever GROWS via rescue; neither consume path touches it. wing_level ends at 2.
	var arena := _make()
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # dock → wing_level 1
	arena._player.apply_hit(2, arena._player.global_position, arena._player, false)  # absorb → undocked, wing_level still 1
	assert_eq(arena._run_state.build_state.wing_level, 1, "wing track survives the absorb")
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # 2nd rescue re-docks → wing_level 2
	assert_eq(arena._run_state.build_state.wing_level, 2, "a 2nd rescue grows the WING track again")
	assert_true(arena._player.is_docked(), "precondition: re-docked before wave-clear")
	EventBus.wave_cleared.emit(1)  # wave-clear detaches the 2nd fighter
	assert_eq(arena._run_state.build_state.wing_level, 2, "wave-clear must NOT clear the accumulated WING track")
	await get_tree().physics_frame


# --- Story 2.5 (Task 6.2) — the run-scope halves of the four outcomes (AC4) ---
# The Player-side consume/signal assertions live in test_player_docked_resolution.gd (Task 6.1). Here we
# assert the ARENA-owned run-scope side: Keep → add_ship(+1) + ship_gained; Sacrifice → no ship change +
# the sacrifice_burst_started hook (the 2.6 seam); the WING track persists across sacrifice (NP1, four-
# outcome context). The Arena owns RunState (AR2) — it is the single point that enriches global signals
# with run-state data (wing_level, ships).

# --- AC2 — Keep: the ONLY add_ship caller in the Gamble (+1, net 0 vs capture) ---

func test_keep_regains_one_ship_on_wave_clear() -> void:
	# AC2 (run-scope): rescue-dock (wing_level grows, NO ship change) → wave-clear while docked →
	# ship_kept → Arena._on_player_ship_kept → add_ship(+1) (the ONLY add_ship in the Gamble) AND
	# EventBus.ship_gained emitted carrying the new remaining count (so the HUD pip row reflects it).
	var arena := _make()
	watch_signals(EventBus)
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # rescue → dock + wing_level 1
	assert_true(arena._player.is_docked(), "precondition: player docked")
	var ships_before: int = arena._run_state.ships
	EventBus.wave_cleared.emit(1)  # wave-clear while docked → ship_kept → add_ship(+1) + ship_gained.
	assert_eq(arena._run_state.ships, ships_before + 1, "keep should regain exactly 1 ship (+1)")
	assert_signal_emitted(EventBus, "ship_gained", "keep should emit ship_gained (HUD pip row reflects the regain)")
	var gained_params: Array = get_signal_parameters(EventBus, "ship_gained")
	assert_eq(gained_params[0], ships_before + 1, "ship_gained should carry the new remaining count")
	await get_tree().physics_frame


func test_keep_at_max_ships_clamps() -> void:
	# FR8 cap: a keep at MAX_SHIPS is a graceful no-op-clamp (add_ship clamps to MAX_SHIPS = 5). No overflow.
	var arena := _make()
	watch_signals(EventBus)
	arena._run_state.ships = Constants.MAX_SHIPS  # at the run cap.
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # dock (no ship change)
	assert_true(arena._player.is_docked())
	EventBus.wave_cleared.emit(1)  # keep → add_ship(+1) clamped at MAX_SHIPS.
	assert_eq(arena._run_state.ships, Constants.MAX_SHIPS, "keep at MAX_SHIPS must clamp (no overflow)")
	# review fix: a clamped no-op keep must NOT emit ship_gained — nothing was actually regained, so the
	# HUD must not flash a phantom "ship regained" cue.
	assert_signal_emit_count(EventBus, "ship_gained", 0, "a clamped keep at MAX_SHIPS must not emit ship_gained")
	await get_tree().physics_frame


func test_keep_does_not_change_hp() -> void:
	# Keep is about SHIPS, not HP (WaveController heals HP on clear separately — not re-tested here). The
	# add_ship path must not touch HealthComponent. Pinned against a future regression that wires HP into
	# the keep path.
	var arena := _make()
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # dock
	var hp_before: int = arena._player._health.current_hp
	EventBus.wave_cleared.emit(1)  # keep
	assert_eq(arena._player._health.current_hp, hp_before, "keep must NOT change the player's HP")
	await get_tree().physics_frame


# --- AC1 — Sacrifice: no ship change + the burst hook (the 2.6 seam) ---

func test_sacrifice_does_not_change_ship_count() -> void:
	# AC1 (run-scope): sacrifice → _run_state.ships UNCHANGED. Sacrifice is ship-neutral (FR18 — the ONLY
	# ship-count changes in the Gamble are capture −1 and keep +1). The consume forfeits the keep regain
	# (relative vs Keep), it does NOT spend a ship. Driven via the player's real consume path (_try_sacrifice
	# — the same method the input read calls), which emits sacrifice_committed → Arena → the burst hook.
	var arena := _make()
	watch_signals(EventBus)
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # dock
	var ships_before: int = arena._run_state.ships
	arena._player._try_sacrifice()  # consume the fighter (mirrors input → _try_sacrifice).
	assert_eq(arena._run_state.ships, ships_before, "sacrifice must NOT change the ship count (FR18)")
	assert_false(arena._player.is_docked(), "the fighter should be consumed")
	await get_tree().physics_frame  # let the deferred queue_free of the fighter land before teardown.


func test_sacrifice_fires_burst_hook_with_wing_level() -> void:
	# AC1 (run-scope — the 2.6 seam): sacrifice → EventBus.sacrifice_burst_started emitted with the current
	# wing_level (the WING-track investment FR19 says the burst "scales with"; the stable primitive 2.6's
	# threat_ceiling reads). 2.5 has NO subscriber — the emit firing IS "the burst fires".
	var arena := _make()
	watch_signals(EventBus)
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # dock → wing_level 1
	assert_eq(arena._run_state.build_state.wing_level, 1)
	arena._player._try_sacrifice()  # consume → sacrifice_committed → Arena → sacrifice_burst_started(1).
	assert_signal_emitted(EventBus, "sacrifice_burst_started")
	var burst_params: Array = get_signal_parameters(EventBus, "sacrifice_burst_started")
	assert_eq(burst_params[0], 1, "sacrifice_burst_started should carry the current wing_level (1 after one rescue)")
	await get_tree().physics_frame


func test_sacrifice_at_zero_wing_emits_hook_with_zero() -> void:
	# The burst hook fires (and carries 0) even with NO prior rescue — wing_level is 0 until a rescue grows
	# it. Pins the payload's origin (build_state.wing_level, NOT a hardcoded value) at the floor.
	var arena := _make()
	watch_signals(EventBus)
	# Dock directly on the player (bypass rescue so wing_level stays 0 — the Arena's record_rescue is the
	# ONLY grower). try_dock_ship is the rescue EFFECT entry; it docks without growing the track.
	assert_true(arena._player.try_dock_ship())
	assert_eq(arena._run_state.build_state.wing_level, 0, "precondition: no rescue → wing_level still 0")
	arena._player._try_sacrifice()
	assert_signal_emitted(EventBus, "sacrifice_burst_started")
	var burst_params: Array = get_signal_parameters(EventBus, "sacrifice_burst_started")
	assert_eq(burst_params[0], 0, "sacrifice_burst_started should carry 0 when no rescue grew the track")
	await get_tree().physics_frame


# --- AC4 / NP1 — the WING track persists across the sacrifice consume (four-outcome context) ---

func test_wing_track_persists_across_sacrifice() -> void:
	# NP1 (re-asserted from the sacrifice consume path, four-outcomes context): a sacrifice consumes the
	# fighter but does NOT clear the WING track. The consume path (Player._try_sacrifice) has no RunState
	# ref (AR2) → it structurally cannot reach build_state. Mirrors the absorb/wave-clear permanence suite.
	var arena := _make()
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # wing_level 1
	assert_eq(arena._run_state.build_state.wing_level, 1)
	arena._player._try_sacrifice()  # consume
	assert_false(arena._player.is_docked(), "precondition: fighter consumed")
	assert_eq(arena._run_state.build_state.wing_level, 1, "sacrifice must NOT clear the WING track (NP1)")
	await get_tree().physics_frame
