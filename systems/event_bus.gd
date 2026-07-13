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
# theming state). `wave_started(wave, duration_s)` is emitted by WaveController (moved
# from FormationSpawner.begin_wave() in Story 1.8, which now owns wave timing) — symmetric
# with wave_cleared at wave-end — so the HUD gets BOTH the wave number and the countdown
# seed in one signal. `arc_t_changed(t)` is a derived, READ-ONLY theming
# broadcast (arch D13/line 420): consumers (HUD, health_bar, future world surfaces)
# never emit it. It has NO EMITTER in E1 — PaletteArcCoordinator (Story 3.9) emits
# it once the build engine exists; until then t stays ~0 (calm Vector Standard).

# --- Global game-flow events (past-tense, D8) ---
signal run_started
signal wave_started(wave: int, duration_s: float)  # Story 1.8 — WaveController emits on Intro enter
signal wave_cleared(wave: int)
signal ship_lost(ships_remaining: int)
# Story 2.5 (AC1) — the sacrifice-burst HOOK (the 2.6 seam). Global game-flow (D8): the Arena (RunState
# owner) emits it carrying the WING-track investment FR19 says the burst "scales with" — the stable
# primitive 2.6's threat_ceiling(track, threat) reads. 2.5 has NO subscriber: the event firing IS "the
# burst fires"; the buff (triple-shot / ×1.5 dmg / fast-fire / ~10 s) is Story 2.6 (NP3/FR19).
signal sacrifice_burst_started(wing_level: int)
# Story 2.5 (AC2) — a ship was regained (the Keep outcome). Global game-flow (D8): mirrors ship_lost's
# shape (both carry the remaining count) so the HUD handler is identical. Emitted by the Arena after
# add_ship(1) on a kept fighter.
signal ship_gained(ships_remaining: int)
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
# Spawn a pooled score-value popup at a world position (kill juice — a Llamasoft-style "+N" that
# zooms toward the viewer, drifts a small x/y offset, and fades over the explosion's lifetime).
# `score_value` is the points gained; the popup's color/duration/motion are fixed in JuiceTuning
# and sourced by the coordinator — only the position + value vary per event.
signal score_popup_requested(at: Vector2, score_value: int)
