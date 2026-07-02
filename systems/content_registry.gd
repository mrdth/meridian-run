extends Node
# STUB (Story 1.1). Will load/index all .tres content (D9) — ships, power-ups,
# enemies, formations, modifier waves. Real getters + registration land with
# their content (1.4 enemies, 3.2 power-ups). No content exists yet.

func get_enemy_def(_id: String) -> Resource:
	Log.warn("content", "ContentRegistry is a stub — content lands in Story 1.4 / 3.2")
	return null


func get_power_up_def(_id: String) -> Resource:
	Log.warn("content", "ContentRegistry is a stub — content lands in Story 3.2")
	return null
