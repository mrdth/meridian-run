extends GutTest
# Story 2.3 (Task 8) — the parallel bullet stream when docked (AC#3 +firepower, FR7). The player's
# FireSystem spawns a 2nd bullet at +28 px x-offset when is_docked() (sharing the cooldown → synced
# cadence). Undocked → one bullet again. Mirrors test_fire_system.gd's fixture (Player under a Node2D
# arena, FireSystem found, projectile_parent overridden to a temp container, physics driven by hand).

const PlayerScene := preload("res://player/player.tscn")


func before_each() -> void:
	Pool.clear()


func after_each() -> void:
	Input.action_release("fire")


func _make() -> Dictionary:
	# Player under a Node2D arena (player._ready wires FireSystem.projectile_parent to get_parent()).
	# projectile_parent is overridden to a temp container we can count; physics driven by hand.
	var arena := Node2D.new()
	add_child_autofree(arena)
	var player: Player = PlayerScene.instantiate() as Player
	arena.add_child(player)
	var fs: FireSystem = player.get_node_or_null("FireSystem") as FireSystem
	var pp := Node2D.new()
	add_child_autofree(pp)
	fs.projectile_parent = pp
	player.set_physics_process(false)
	fs.set_physics_process(false)
	return {"player": player, "fs": fs, "pp": pp}


func test_clean_fire_spawns_one_bullet() -> void:
	# Baseline: a clean (undocked) player fires ONE bullet per shot.
	var s := _make()
	var fs: FireSystem = s.fs
	var pp: Node2D = s.pp
	Input.action_press("fire")
	fs._physics_process(1.0 / 60.0)
	Input.action_release("fire")
	assert_eq(pp.get_child_count(), 1, "a clean player should spawn one bullet")


func test_docked_fire_spawns_two_bullets() -> void:
	# AC#3 +firepower: a docked player fires TWO bullets per shot (the primary + the +28 px parallel stream).
	var s := _make()
	var player: Player = s.player
	var fs: FireSystem = s.fs
	var pp: Node2D = s.pp
	assert_true(player.try_dock_ship(), "precondition: dock the player")
	Input.action_press("fire")
	fs._physics_process(1.0 / 60.0)
	Input.action_release("fire")
	assert_eq(pp.get_child_count(), 2, "a docked player should spawn two bullets")


func test_docked_secondary_is_28px_offset() -> void:
	# FR7 / GDD weapon table: the secondary bullet spawns at muzzle.x + 28 px. Assert the two bullets'
	# x-offset is ~28 (the primary at the muzzle, the secondary at +28).
	var s := _make()
	var player: Player = s.player
	var fs: FireSystem = s.fs
	var pp: Node2D = s.pp
	player.try_dock_ship()
	Input.action_press("fire")
	fs._physics_process(1.0 / 60.0)
	Input.action_release("fire")
	var xs: Array[float] = []
	for c in pp.get_children():
		xs.append((c as Projectile).global_position.x)
	xs.sort()
	assert_eq(xs.size(), 2)
	assert_almost_eq(xs[1] - xs[0], 28.0, 0.5, "the parallel stream should be +28 px from the primary")


func test_undock_after_dock_returns_to_one_bullet() -> void:
	# Toggling dock state reverts the stream: dock → 2, undock → 1.
	var s := _make()
	var player: Player = s.player
	var fs: FireSystem = s.fs
	var pp: Node2D = s.pp
	player.try_dock_ship()
	# Fire once docked (2 bullets), then undock by consuming the docked ship via apply_hit (the absorber).
	Input.action_press("fire")
	fs._physics_process(1.0 / 60.0)
	Input.action_release("fire")
	assert_eq(pp.get_child_count(), 2)
	# Clear the container so the next shot's count is unambiguous.
	for c in pp.get_children():
		pp.remove_child(c)
		c.queue_free()
	player.apply_hit(1, player.global_position, player, false)  # absorb → undock (spares HP).
	assert_false(player.is_docked(), "precondition: the absorber should have undocked the player")
	# Reset the cooldown (the first fire set it; only one frame has passed) so the second shot fires.
	fs._cooldown = 0.0
	Input.action_press("fire")
	fs._physics_process(1.0 / 60.0)
	Input.action_release("fire")
	assert_eq(pp.get_child_count(), 1, "an undocked player should spawn one bullet again")
