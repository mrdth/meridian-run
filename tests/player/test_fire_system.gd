extends GutTest
# Integration tests for the FireSystem component (1.3), driven through the Player
# scene. Asserts on projectile_parent child-count / instance validity / source
# structure — never visuals. Mirrors the 1.2 GUT style: set_physics_process(false)
# + direct _physics_process stepping for determinism, after_each() releases input.

const PlayerScene := preload("res://player/player.tscn")


func before_each() -> void:
	# Pool is an autoload; clear it so each test starts from a known-empty pool
	# instead of leaning on cross-test state (review fix — 1.3 D7 review).
	Pool.clear()


func _make() -> FireSystem:
	# The Player is parented under a Node2D "arena" (as in world/arena.tscn) because
	# player._ready assigns get_parent() to FireSystem.projectile_parent (typed Node2D)
	# — the GutTest root is a plain Node, so a direct add_child_autofree would fail the
	# type check. Then projectile_parent is overridden to a temp container we can count.
	# Engine processing is disabled so we can drive FireSystem._physics_process by hand.
	var arena := Node2D.new()
	add_child_autofree(arena)
	var player: Player = PlayerScene.instantiate() as Player
	arena.add_child(player)  # player freed when arena is autofree'd
	var fs: FireSystem = player.get_node_or_null("FireSystem") as FireSystem
	var pp := Node2D.new()
	add_child_autofree(pp)
	fs.projectile_parent = pp  # override the auto-wired arena parent for clean counts
	player.set_physics_process(false)
	fs.set_physics_process(false)
	return fs


func after_each() -> void:
	# No synthetic input leaks between tests.
	Input.action_release("fire")


func test_hold_fire_spawns_at_cooldown_rate() -> void:
	# AC1 — hold-to-autofire at ~6.25 shots/s (0.16 s cooldown). 0.5 s of held fire
	# yields 3 shots (0.5/0.16 ≈ 3.1). Projectiles are stepped manually so they never
	# leave-screen mid-test — the count equals shots fired.
	var fs: FireSystem = _make()
	var pp: Node2D = fs.projectile_parent
	Input.action_press("fire")
	for _i in 30:  # 0.5 s at 60 Hz
		fs._physics_process(1.0 / 60.0)
	Input.action_release("fire")
	assert_eq(pp.get_child_count(), 3)


func test_tap_fires_once_then_no_more_until_repress() -> void:
	# AC1 — a tap is a single shot; with Fire released, subsequent steps spawn nothing.
	var fs: FireSystem = _make()
	var pp: Node2D = fs.projectile_parent
	Input.action_press("fire")
	fs._physics_process(1.0 / 60.0)  # first press fires immediately (cooldown starts 0)
	Input.action_release("fire")
	assert_eq(pp.get_child_count(), 1)
	for _i in 5:
		fs._physics_process(1.0 / 60.0)  # released → no further spawns
	assert_eq(pp.get_child_count(), 1)


func test_cooldown_blocks_spawn_until_elapsed() -> void:
	# AC1 — with Fire held, no second spawn until the cooldown elapses. Two consecutive
	# steps immediately after a shot must not double-fire.
	var fs: FireSystem = _make()
	var pp: Node2D = fs.projectile_parent
	Input.action_press("fire")
	fs._physics_process(1.0 / 60.0)  # shot 1, cooldown set to 0.16
	assert_eq(pp.get_child_count(), 1)
	for _i in 5:  # ~0.083 s < 0.16 s cooldown
		fs._physics_process(1.0 / 60.0)
	assert_eq(pp.get_child_count(), 1)  # still one — cooldown blocks


func test_spawned_projectiles_are_pooled_not_freed() -> void:
	# AC2 — pooled projectiles are valid instances, never queue_free'd mid-flight
	# (release ≠ free; Pool reuse is covered by test_pool.gd).
	var fs: FireSystem = _make()
	var pp: Node2D = fs.projectile_parent
	Input.action_press("fire")
	for _i in 30:
		fs._physics_process(1.0 / 60.0)
	Input.action_release("fire")
	var count: int = pp.get_child_count()
	assert_gt(count, 1)  # spawned ≥ 2 over time
	for c in pp.get_children():
		assert_true(is_instance_valid(c))
		assert_false(c.is_queued_for_deletion())  # pooled, not freed
		assert_true(c is Projectile)


func test_physics_process_makes_no_per_frame_allocations() -> void:
	# AC4 — structural: the _physics_process body constructs no Vector2/Array/Dict/.new
	# (zero per-frame allocations on the hot path). Scoped to that method only.
	var src: String = (load("res://player/fire_system.gd") as GDScript).source_code
	var start: int = src.find("func _physics_process")
	assert_gt(start, -1, "could not find _physics_process in fire_system.gd")
	var end: int = src.find("\nfunc ", start + 1)
	if end == -1:
		end = src.length()
	var body: String = src.substr(start, end - start)
	assert_false(body.contains("Vector2("))
	assert_false(body.contains("Array("))
	assert_false(body.contains("Dictionary("))
	assert_false(body.contains(".new("))
	assert_false(body.contains(".append("))
