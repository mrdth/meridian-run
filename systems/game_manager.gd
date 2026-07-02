extends Node
# STUB (Story 1.1). Will own the game-mode FSM (menu → run → gameover), pause,
# and scene flow (D1). Real FSM + flow land in Story 4.7. For 1.1 the main
# scene is arena.tscn via ProjectSettings application/run/main_scene.

enum Mode { MENU, RUN, GAME_OVER }

var _mode: int = Mode.MENU


func get_mode() -> int:
	return _mode
