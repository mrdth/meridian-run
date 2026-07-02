extends GutTest
# Story 1.1 scaffolding smoke tests. These validate the project WIRING —
# the 11 autoloads (AC2), Input Map actions w/ kb+gamepad (AC3), display (AC4),
# and main scene (AC1). AC5 = this suite running green.

const _ACTIONS: Array[String] = [
	"move_left", "move_right", "fire", "sacrifice", "confirm", "back", "pause",
]


func test_all_eleven_autoloads_loaded() -> void:
	# AC2 — all 11 autoloads present and accessible by their global name.
	assert_not_null(Constants, "Constants autoload missing")
	assert_not_null(Log, "Log autoload missing")
	assert_not_null(EventBus, "EventBus autoload missing")
	assert_not_null(Settings, "Settings autoload missing")
	assert_not_null(SeedManager, "SeedManager autoload missing")
	assert_not_null(ContentRegistry, "ContentRegistry autoload missing")
	assert_not_null(Pool, "Pool autoload missing")
	assert_not_null(SaveManager, "SaveManager autoload missing")
	assert_not_null(AudioManager, "AudioManager autoload missing")
	assert_not_null(GameManager, "GameManager autoload missing")
	assert_not_null(Debug, "Debug autoload missing")


func test_constants_base_resolution_and_layers() -> void:
	# Decision #2: base resolution = 1280x720.
	assert_eq(Constants.BASE_RESOLUTION, Vector2i(1280, 720))
	# Collision layers are distinct bitmask values (NFR6).
	assert_ne(Constants.LAYER_PLAYER, Constants.LAYER_ENEMY)
	assert_ne(Constants.LAYER_ENEMY, Constants.LAYER_PLAYER_PROJECTILE)
	assert_ne(Constants.LAYER_PLAYER_PROJECTILE, Constants.LAYER_ENEMY_PROJECTILE)
	assert_ne(Constants.LAYER_ENEMY_PROJECTILE, Constants.LAYER_PICKUP)
	assert_true(Constants.LAYER_PICKUP > 0)


func test_each_input_action_has_kb_and_gamepad() -> void:
	# AC3 — every action exists AND has >=1 keyboard AND >=1 gamepad binding.
	for action in _ACTIONS:
		assert_true(InputMap.has_action(action), "action missing: %s" % action)
		if not InputMap.has_action(action):
			continue
		var has_kb := false
		var has_pad := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				has_kb = true
			elif ev is InputEventJoypadMotion or ev is InputEventJoypadButton:
				has_pad = true
		assert_true(has_kb, "missing keyboard binding: %s" % action)
		assert_true(has_pad, "missing gamepad binding: %s" % action)


func test_display_settings() -> void:
	# AC4 — fixed base resolution + canvas scaling.
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 720)
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand")


func test_main_scene_is_arena() -> void:
	# AC1 — launches into the Arena scene.
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://world/arena.tscn")
