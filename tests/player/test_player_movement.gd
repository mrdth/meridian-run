extends GutTest
# Integration tests for the Player scene (1-axis chassis). Instantiates player.tscn,
# simulates input, and asserts on global_position/velocity/structure — never visuals.
# Mirrors the 1.1 GUT style. Covers AC1-AC4.

const PlayerScene := preload("res://player/player.tscn")


func _make() -> Player:
	var p: Player = PlayerScene.instantiate() as Player
	add_child_autofree(p)
	return p


func after_each() -> void:
	# No synthetic input leaks between tests.
	Input.action_release("move_left")
	Input.action_release("move_right")


func test_player_is_characterbody_with_components() -> void:
	# AC4 — structure: CharacterBody2D on LAYER_PLAYER with Health/Faction children.
	var p := _make()
	assert_true(p is CharacterBody2D)
	assert_eq(p.collision_layer, Constants.LAYER_PLAYER)
	var health: Node = p.get_node_or_null("HealthComponent")
	var faction: Node = p.get_node_or_null("FactionComponent")
	assert_not_null(health)
	assert_not_null(faction)
	assert_true(health is HealthComponent)
	assert_true(faction is FactionComponent)


func test_starts_centered_on_lane() -> void:
	# _ready centers the ship on the bottom lane.
	var p := _make()
	assert_almost_eq(p.global_position.x, Constants.BASE_RESOLUTION.x / 2.0, 0.5)
	assert_eq(p.global_position.y, p.tuning.lane_y)


func test_move_actions_exist() -> void:
	# AC3 — both move actions present (kb+gamepad parity; bindings checked in 1.1).
	assert_true(InputMap.has_action("move_left"))
	assert_true(InputMap.has_action("move_right"))


func test_velocity_independent_of_delta() -> void:
	# AC2 — velocity is axis*move_speed with NO *delta. Stepping at two different
	# deltas must yield the same per-call velocity (the enforceable AC2 guarantee).
	# NOTE: velocity.x is a 32-bit Vector2 component; tuning.move_speed is a 64-bit
	# float, so values not exactly representable in float32 (e.g. 426.6) differ by
	# ~1e-4 — compare with epsilon. The delta-independence check (v60==v144) stays
	# exact because both read the same float32 velocity.
	var p := _make()
	p.set_physics_process(false)  # drive manually for determinism
	Input.action_press("move_right")
	p._physics_process(1.0 / 60.0)
	var v60: float = p.velocity.x
	p._physics_process(1.0 / 144.0)
	var v144: float = p.velocity.x
	Input.action_release("move_right")
	assert_almost_eq(v60, p.tuning.move_speed, 0.01)
	assert_almost_eq(v144, p.tuning.move_speed, 0.01)
	assert_eq(v60, v144)


func test_clamps_at_right_edge() -> void:
	# AC1 — holding right clamps at _max_x = BASE_RESOLUTION.x - edge_margin.
	var p := _make()
	var max_x: float = float(Constants.BASE_RESOLUTION.x) - p.tuning.edge_margin
	p.global_position.x = max_x - 2.0
	Input.action_press("move_right")
	for _i in range(10):
		await get_tree().physics_frame
	Input.action_release("move_right")
	assert_eq(p.global_position.x, max_x)


func test_clamps_at_left_edge() -> void:
	# AC1 — holding left clamps at _min_x = edge_margin.
	var p := _make()
	var min_x: float = p.tuning.edge_margin
	p.global_position.x = min_x + 2.0
	Input.action_press("move_left")
	for _i in range(10):
		await get_tree().physics_frame
	Input.action_release("move_left")
	assert_eq(p.global_position.x, min_x)


func test_movement_is_horizontal_only() -> void:
	# AC1 — y never leaves lane_y while moving (1-axis lock).
	var p := _make()
	var lane_y: float = p.tuning.lane_y
	Input.action_press("move_right")
	for _i in range(10):
		await get_tree().physics_frame
	Input.action_release("move_right")
	assert_eq(p.global_position.y, lane_y)


func test_move_right_advances_position() -> void:
	# Sanity — holding right actually moves the ship rightward before clamping.
	var p := _make()
	var start_x: float = p.global_position.x
	Input.action_press("move_right")
	for _i in range(5):
		await get_tree().physics_frame
	Input.action_release("move_right")
	assert_gt(p.global_position.x, start_x)
