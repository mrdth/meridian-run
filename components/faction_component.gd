class_name FactionComponent
extends Node
# Reusable faction tag. Single source of truth for the collision-layer bit
# (D16 family-driven rendering will later also read `faction`, not a layer bit).
# No gameplay logic beyond the accessor — strict AR5 "composition over inheritance".

enum Faction { PLAYER, ENEMY }

@export var faction: Faction = Faction.PLAYER


func get_collision_layer() -> int:
	# Return the collision-layer bitmask for this faction. Read from Constants,
	# never a magic number (NFR6 strict 2D layers).
	match faction:
		Faction.PLAYER:
			return Constants.LAYER_PLAYER
		Faction.ENEMY:
			return Constants.LAYER_ENEMY
	return 0
