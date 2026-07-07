extends GutTest
# Debug overlay + cheats + visual toggles (Story 1.8 / FR50). The Debug autoload is global, so
# before_each resets its mutable state via _reset_for_tests(). GUT runs in a debug build, so the
# overlay is built (Debug._ready ran at startup) and processing/input are enabled.

const GruntScene := preload("res://enemies/grunt.tscn")
const ShielderScene := preload("res://enemies/shielder.tscn")
const BomberScene := preload("res://enemies/bomber.tscn")
const PlayerScene := preload("res://player/player.tscn")


func before_each() -> void:
	Pool.clear()
	Debug._reset_for_tests()


func after_each() -> void:
	# Defensive: _cheat_move_speed mutates the shared/cached res://resources/player_tuning.tres in
	# memory (not resource_local_to_scene) — restore it immediately so a mutated baseline can't leak
	# into a test in a DIFFERENT file that runs before this file's next before_each.
	Debug._reset_for_tests()


func _press(action: String) -> void:
	# Synthesize a debug Input Map action press and feed it to the autoload's _unhandled_input.
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Debug._unhandled_input(ev)


func _make_spawner() -> FormationSpawner:
	# A real drip-only spawner under a Node2D (its _ready builds the enemy container + formation_def),
	# for the spawn-cheat test.
	var arena := Node2D.new()
	add_child(arena)
	var s := FormationSpawner.new()
	s.grunt_scene = GruntScene
	s.shielder_scene = ShielderScene
	s.bomber_scene = BomberScene
	s.per_tick_base = 2
	s.per_tick_growth = 0.0
	s.max_per_tick = 4
	arena.add_child(s)
	s.player = Node2D.new()
	arena.add_child(s.player)
	s.run_state = RunState.new()
	s.run_state.begin_run()
	return s


func test_overlay_hidden_by_default_and_toggles() -> void:
	# AC3: the overlay is hidden by default and the debug_toggle_overlay action flips visibility.
	assert_true(Debug._overlay != null)  # built in _ready (debug build)
	assert_false(Debug._overlay.visible)  # hidden by default
	_press("debug_toggle_overlay")
	assert_true(Debug._overlay.visible)
	_press("debug_toggle_overlay")
	assert_false(Debug._overlay.visible)


func test_pool_count_getters_track_acquire_release() -> void:
	# Story 1.8: the overlay reads Pool.get_active_count() / get_pooled_count(). Verify they track
	# acquire/release. (Acquire does NOT add the node to the tree, so _ready never runs — lightweight.)
	Pool.clear()
	assert_eq(Pool.get_active_count(), 0)
	assert_eq(Pool.get_pooled_count(), 0)
	var n: Node = Pool.acquire(GruntScene)
	assert_eq(Pool.get_active_count(), 1)  # acquired → in play
	assert_eq(Pool.get_pooled_count(), 0)  # none idle yet
	Pool.release(n)
	assert_eq(Pool.get_active_count(), 0)  # released → no longer active
	assert_eq(Pool.get_pooled_count(), 1)  # now idle in the pool


func test_cheat_spawn_spawns_one_pulse() -> void:
	# AC3 "spawn enemy": debug_cheat_spawn calls the spawner's debug_spawn_pulse() seam → enemies
	# appear. Bind a real spawner, fire the action, assert the spawn count rose by one pulse.
	var s: FormationSpawner = _make_spawner()
	Debug.bind_arena(null, s, null)
	var before: int = s.get_spawned_count()
	_press("debug_cheat_spawn")
	assert_eq(s.get_spawned_count() - before, int(s.per_tick(s._wave_n)))  # exactly one pulse


func test_move_speed_cheat_cycles_player_tuning() -> void:
	# AC3 "set move-speed": debug_cheat_move_speed mutates player.tuning.move_speed (session-only;
	# the .tres is never saved). Cycle steps are [0.5, 1.0, 1.5, 2.0] × the cached baseline.
	var host := Node2D.new()
	add_child(host)
	var player: Player = PlayerScene.instantiate()
	host.add_child(player)  # Node2D parent (player._ready assigns fire_system.projectile_parent)
	Debug.bind_arena(player, null, null)
	var baseline: float = player.tuning.move_speed
	# Default step index is -1 (not yet cycled). First press → step 0 (0.5×), matching the
	# documented cycle order.
	_press("debug_cheat_move_speed")
	assert_eq(player.tuning.move_speed, baseline * 0.5)
	_press("debug_cheat_move_speed")
	assert_eq(player.tuning.move_speed, baseline * 1.0)
	_press("debug_cheat_move_speed")
	assert_eq(player.tuning.move_speed, baseline * 1.5)


func test_invuln_cheat_toggles_flag_and_noops_unbound() -> void:
	# AC3 "invincibility": toggles the _debug_invuln flag (topped up each _process while on). With no
	# player bound, toggling must not crash (the _process top-up guards player == null).
	assert_false(Debug._debug_invuln)
	_press("debug_cheat_invuln")
	assert_true(Debug._debug_invuln)
	_press("debug_cheat_invuln")
	assert_false(Debug._debug_invuln)


func test_cheats_noop_safely_when_unbound() -> void:
	# AR11 fail-safe: with no gameplay refs bound (e.g., a menu scene), firing every debug cheat +
	# toggle must not crash. (This test passing = no crash.)
	_press("debug_cheat_move_speed")
	_press("debug_cheat_spawn")
	_press("debug_cheat_invuln")
	_press("debug_toggle_hitboxes")
	_press("debug_toggle_formation_rows")
	_press("debug_toggle_monochrome")
	assert_true(true)  # reached here without error
