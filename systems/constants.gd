extends Node
# Immutable constants — collision layers, base resolution, base economy.
# AR10 "immutable" tier. Accessed as the `Constants` singleton. const-only.

# --- Display (AC4) — single source of truth for the base resolution ---
const BASE_RESOLUTION := Vector2i(1280, 720)

# --- Collision layers (bitmask values, 1 << index) — NFR6 strict 2D layers ---
const LAYER_PLAYER: int = 1            # bit 0
const LAYER_ENEMY: int = 2             # bit 1
const LAYER_PLAYER_PROJECTILE: int = 4 # bit 2
const LAYER_ENEMY_PROJECTILE: int = 8  # bit 3
const LAYER_PICKUP: int = 16           # bit 4

# --- Life-economy baselines (FR8/FR10; data-tunable later via .tres tuning) ---
const BASE_SHIPS: int = 3
const MAX_SHIPS: int = 5
const BASE_HP: int = 3
