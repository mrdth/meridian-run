extends Node
# Debug overlay + cheat hotkeys (FR50). Gated by OS.is_debug_build() — must be
# a no-op in release exports. Overlay, visual toggles, and cheats land in
# Story 1.8 (overlay) / 3.x (hypothesis cheats).

func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
