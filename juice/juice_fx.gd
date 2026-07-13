class_name JuiceFx
extends RefCounted
# Static one-liner helpers for impact/fire/kill juice (Story 1.6 / AC1, AC4). Each helper emits
# the EventBus juice REQUEST signals (the mandated channel — D8: emitter and consumer are not in
# the same entity subtree) AND fires the AudioManager SFX, reading FEEL values from a single
# cached JuiceTuning. This keeps the projectile / enemy_projectile / enemy / fire_system emit sites
# to one line each — no scattered multi-emit, no per-entity tuning ref (the static accessor the
# story prefers over each projectile holding a JuiceTuning). The underlying mechanism is still the
# EventBus signals (AC1); this is sugar over them.
#
# Impact juice is emitted from the IMPACT SOURCE (Key Decision #1) — the projectile/enemy that
# causes the impact knows the exact contact global_position, severity, and faction. HealthComponent
# is NOT touched (no damaged/hit_taken signal churn).

const _TUNING := preload("res://resources/juice_tuning.tres")


static func enemy_hit(at: Vector2, body: Node2D) -> void:
	# Player bullet hit an enemy (sub-lethal OR lethal — the enemy's own _on_died fires the death
	# juice separately). Flash the enemy body, small shake, cyan hit-spark, hit SFX.
	EventBus.hit_flash_requested.emit(body, _TUNING.flash_enemy_color)
	EventBus.screen_shake_requested.emit(_TUNING.shake_enemy_hit_amount, _TUNING.shake_enemy_hit_dur)
	EventBus.particles_requested.emit(&"hit_spark", at, _TUNING.hit_spark_color, 1.0)
	AudioManager.play_hit(false)


static func player_hit(at: Vector2, body: Node2D, heavy: bool) -> void:
	# Enemy bullet hit the player. Heavy (Bomber, 2 dmg) ⇒ heavier shake (×shake_heavy_mul), bigger
	# spark, lower-pitch SFX. Flash the PLAYER body in the hazard color.
	var size_mul: float = _TUNING.shake_heavy_mul if heavy else 1.0
	EventBus.hit_flash_requested.emit(body, _TUNING.flash_player_color)
	EventBus.screen_shake_requested.emit(_TUNING.shake_player_hit_amount * size_mul, _TUNING.shake_player_hit_dur)
	EventBus.particles_requested.emit(&"hit_spark", at, _TUNING.flash_player_color, size_mul)
	AudioManager.play_hit(heavy)


static func enemy_killed(at: Vector2, faction_color: Color, size_scale: float, score_value: int) -> void:
	# Real enemy death (Enemy._on_died). Bigger explosion in the enemy's faction color (Bomber =
	# bigger via silhouette_scale), kill shake, kill sting, and the Llamasoft score-value popup
	# (zoom-toward-viewer +N that fades with the blast). Called on _on_died ONLY — never despawn().
	EventBus.particles_requested.emit(&"explosion", at, faction_color, size_scale)
	EventBus.screen_shake_requested.emit(_TUNING.shake_kill_amount, _TUNING.shake_kill_dur)
	EventBus.score_popup_requested.emit(at, score_value)
	AudioManager.play_kill()


static func player_fired(muzzle_pos: Vector2) -> void:
	# Player fired — fire SFX (mandated by AC4, ±5% pitch inside play_fire) + a light optional
	# muzzle puff (cheap, pooled). No shake on fire.
	AudioManager.play_fire()
	EventBus.particles_requested.emit(&"muzzle", muzzle_pos, _TUNING.muzzle_color, 0.6)


static func rescue(at: Vector2) -> void:
	# Story 2.3 — rescue (dive-kill → dock) juice, PICKUP-STYLE (no dedicated UX spec; Dev Notes §"Juice
	# gaps"). A bright dock-color burst at the player + a positive SFX. Pickup register: bright but calm
	# (NO shake — a rescue is a reward, not an impact). The dock color is {colors.dock} (provisional alias
	# of HudPalette.PRIMARY / JuiceTuning.rescue_color — UX OQ3). Open Question I default; a distinct
	# rescue SFX is the audio pass (reuses play_kill — the E1 set's closest "acquired" sting).
	EventBus.particles_requested.emit(&"explosion", at, _TUNING.rescue_color, 0.9)
	AudioManager.play_kill()


static func failed_rescue(at: Vector2, target: Node2D) -> void:
	# Story 2.3 — failed-rescue (formation-kill → ship turns enemy) juice, HAZARD STING (Dev Notes §"Juice
	# gaps"). A hit_flash on the PLAYER body (target) in the hazard color + a player-hit shake + a hazard
	# burst at the captor's death position (where the enemy appears) + a negative SFX. Mirrors player_hit's
	# hazard treatment but keyed to the captor's death position, not the player's. The coordinator's ≤3 Hz
	# flash gate applies. Open Question I default; a distinct failed-rescue SFX is the audio pass (reuses
	# play_hit(true) — the heavy/low sting).
	EventBus.hit_flash_requested.emit(target, _TUNING.flash_player_color)
	EventBus.screen_shake_requested.emit(_TUNING.shake_player_hit_amount, _TUNING.shake_player_hit_dur)
	EventBus.particles_requested.emit(&"explosion", at, _TUNING.flash_player_color, 1.0)
	AudioManager.play_hit(true)


static func docked_consumed(at: Vector2, color: Color) -> void:
	# Story 2.3 — the absorber beat: the docked fighter died sparing the player's HP (AC#3 / FR17).
	# Explosion in the dock color + a kill shake, NO score popup (a "+0" would be noise — this is distinct
	# from enemy_killed, which always pops the value). Called by Player._consume_docked_ship. Reuses the
	# kill SFX (the E1 set has no dedicated "wingman lost" sting — the audio pass adds one).
	EventBus.particles_requested.emit(&"explosion", at, color, 0.8)
	EventBus.screen_shake_requested.emit(_TUNING.shake_kill_amount, _TUNING.shake_kill_dur)
	AudioManager.play_kill()


static func sacrifice_ignited(at: Vector2) -> void:
	# Story 2.6 (FR47/FR48) — the sacrifice-burst IGNITION cue (2.5 deferred the distinct cue + reused
	# docked_consumed; this is the dedicated ignition sting). A heavy kill-grade rumble (clamped to
	# MAX_SHAKE_PX by the coordinator) + a warm-amber ignition particle burst + an SFX. The on-ship glow +
	# timer ring (Player Task 7) carry the sustained readability; this is the ONE-SHOT ignition at burst
	# start. Mirrors docked_consumed's shape (particles + shake + SFX). Reduced-motion: the coordinator's
	# _motion_scale dampens the shake/particles (~70%); the glow + ring + SFX + the buff itself remain
	# untouched (D14 — dampen motion amplitude, never the gameplay effect). NO hit_flash (the on-ship glow
	# is continuous, not a ≤3 Hz flash, so the central HitFlash gate is not needed here).
	EventBus.particles_requested.emit(&"sacrifice_ignition", at, _TUNING.sacrifice_ignition_color, 1.0)
	EventBus.screen_shake_requested.emit(_TUNING.shake_kill_amount, _TUNING.shake_kill_dur)
	AudioManager.play_kill()
