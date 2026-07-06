extends Node
# Global game-flow signals (typed, past-tense). D8: GLOBAL flow ONLY here;
# local/intra-entity comms use direct signals. Add signals as systems land.
#
# Story 1.6 (Hit Feedback & Juice) adds three REQUEST signals below (D8:
# imperative `_requested` for requests). Juice requests are global FEEDBACK
# requests — the emitter (projectile / enemy._on_died / fire_system) and the
# consumer (JuiceCoordinator, an arena-scene node) are NOT in the same entity
# subtree, so the bus is the correct channel (D8 explicitly blesses this). They
# are NOT game-flow events and MUST stay imperative-request shaped.
#
# Story 1.7 (Basic HUD) adds `wave_started` (game-flow) + `arc_t_changed` (derived
# theming state). `wave_started(wave, duration_s)` is emitted by FormationSpawner
# at the top of begin_wave() — symmetric with wave_cleared at wave-end — so the HUD
# gets BOTH the wave number and the countdown seed in one signal (D8: the spawner
# is the E1 wave-timing owner). `arc_t_changed(t)` is a derived, READ-ONLY theming
# broadcast (arch D13/line 420): consumers (HUD, health_bar, future world surfaces)
# never emit it. It has NO EMITTER in E1 — PaletteArcCoordinator (Story 3.9) emits
# it once the build engine exists; until then t stays ~0 (calm Vector Standard).

# --- Global game-flow events (past-tense, D8) ---
signal run_started
signal wave_started(wave: int, duration_s: float)  # Story 1.7 — spawner emits in begin_wave()
signal wave_cleared(wave: int)
signal ship_lost(ships_remaining: int)
signal build_changed
signal score_changed(score: int)
signal game_over

# --- Derived, read-only run/theming state (arch D13/line 415–420) ---
# High-fanout projections of run state, NOT game-flow commands. Consumers never emit.
# arc_t_changed stays dormant in E1 (no emitter until Story 3.9); HUD subscribes now
# so the calm→climax recolor path is built + testable, running calm-only this epic.
signal arc_t_changed(t: float)

# --- Juice feedback requests (imperative `_requested`, D8) — Story 1.6 ---
# Global shake. `amount` is px (pre-`_motion_scale`, clamped to MAX_SHAKE_PX by
# the coordinator); `duration` is seconds.
signal screen_shake_requested(amount: float, duration: float)
# Flash a specific entity's sprite (cascade-flashes its visual children via
# `modulate`). `target` MUST be a CanvasItem (player/enemy bodies are
# CharacterBody2D ✓). The coordinator's HitFlash gates this to MAX_FLASH_HZ.
signal hit_flash_requested(target: Node2D, color: Color)
# Spawn a pooled particle burst at a world position. `effect` selects the burst
# profile (&"hit_spark" / &"explosion" / &"muzzle"); `scale` multiplies the
# burst size (heavy/Bomber/death = bigger).
signal particles_requested(effect: StringName, at: Vector2, color: Color, scale: float)
