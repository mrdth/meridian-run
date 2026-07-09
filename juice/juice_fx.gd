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
