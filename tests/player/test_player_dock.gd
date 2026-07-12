extends GutTest
# Story 2.3 (Task 8) — integration tests for the Player's rescue dock + the intrinsic absorber (AC#1,
# AC#3). try_dock_ship() is the rescue EFFECT entry (mirrors 2.2 try_capture): instantiate + attach the
# DockedShip + set_docked(true) (which grows the hitbox — the +hitbox). is_docked()/is_capture_immune()
# reflect _docked (retires the 2.2 stub). apply_hit is the CENTRALIZED damage route: i-frames → absorber
# (if docked) → HP damage. The absorber spares HP with NO ship-count change (FR18 "−1 ship" is relative-
# accounting, NOT a spend). Mirrors test_player_capture.gd (the player is NOT pooled → parent under a
# Node2D "arena" so _ready runs).

const PlayerScene := preload("res://player/player.tscn")


func _make() -> Player:
	# Parent under a Node2D "arena" (player._ready wires FireSystem.projectile_parent to get_parent(),
	# typed Node2D). Mirrors test_player_capture._make.
	var arena := Node2D.new()
	add_child_autofree(arena)
	var p: Player = PlayerScene.instantiate() as Player
	arena.add_child(p)
	return p


func _dummy_source() -> Node2D:
	# apply_hit's `source` is the flash context (apply_hit flashes the PLAYER body, not the source). A
	# dummy Node2D suffices — it's unused by the absorber path beyond being passed through.
	var s := Node2D.new()
	add_child_autofree(s)
	return s


func test_try_dock_ship_clean_docks_and_returns_true() -> void:
	# AC#1: a clean player → try_dock_ship returns true + _docked == true + a DockedShip child exists.
	var p := _make()
	var ok: bool = p.try_dock_ship()
	assert_true(ok, "a clean player's try_dock_ship should return true")
	assert_true(p.is_docked(), "is_docked() should be true after a dock")
	assert_true(p.is_capture_immune(), "is_capture_immune() should be true after a dock (FR16)")
	assert_not_null(p._docked_ship, "the DockedShip node should be attached")
	assert_true(p._docked_ship is DockedShip)


func test_try_dock_ship_blocked_when_already_docked() -> void:
	# FR14 one-docked: a second try_dock_ship returns false (no second wingman). Capture is also
	# once-per-wave, so this guard is defensive.
	var p := _make()
	assert_true(p.try_dock_ship())
	var ok2: bool = p.try_dock_ship()
	assert_false(ok2, "a second dock should be blocked (FR14 one-docked)")


func test_is_capture_immune_reflects_docked_state() -> void:
	# 2.3 retires the 2.2 stub (which always returned false). Now: false when clean, true after dock.
	var p := _make()
	assert_false(p.is_capture_immune(), "a clean player should NOT be capture-immune")
	p.try_dock_ship()
	assert_true(p.is_capture_immune(), "a docked player should be capture-immune (FR16)")


func test_apply_hit_clean_damages_hp() -> void:
	# AC#3 centralized route: a clean, vulnerable player → apply_hit damages HP normally.
	var p := _make()
	var hp_before: int = p._health.current_hp
	p.apply_hit(1, p.global_position, _dummy_source(), false)
	assert_eq(p._health.current_hp, hp_before - 1, "apply_hit on a clean player should damage HP")


func test_apply_hit_while_docked_consumes_docked_ship_and_spares_hp() -> void:
	# AC#3 / FR17 intrinsic absorber: apply_hit while docked → the docked fighter dies, HP is SPARED.
	# NO ship-count change (no ship_depleted emit). set_docked(false) + _docked_ship=null are synchronous
	# (a same-frame second hit lands on the player, not a consumed fighter); the node free is deferred.
	var p := _make()
	watch_signals(p)
	p.try_dock_ship()
	var hp_before: int = p._health.current_hp
	p.apply_hit(2, p.global_position, _dummy_source(), false)
	assert_null(p._docked_ship, "the docked ship should be consumed (detached) on absorb")
	assert_false(p.is_docked(), "the player should be undocked after the absorber fires")
	assert_eq(p._health.current_hp, hp_before, "HP must be SPARED on an absorb (the absorber's job)")
	assert_signal_emit_count(p, "ship_depleted", 0)  # NO ship-count change (not a spend).
	await get_tree().physics_frame  # let the deferred queue_free of the DockedShip land.


func test_apply_hit_during_iframes_is_full_noop() -> void:
	# The absorber must NOT fire during i-frames (the gate): apply_hit while invulnerable is a full
	# no-op — no damage, no juice, no absorb (the docked ship is NOT consumed by an i-frame hit).
	var p := _make()
	p.try_dock_ship()
	p._health.set_invuln(1.0)  # i-frames on.
	var hp_before: int = p._health.current_hp
	p.apply_hit(2, p.global_position, _dummy_source(), false)
	assert_eq(p._health.current_hp, hp_before, "an i-frame hit must deal no damage")
	assert_not_null(p._docked_ship, "an i-frame hit must NOT consume the docked ship (the gate)")
	assert_true(p.is_docked(), "the player stays docked through an i-frame hit")


func test_apply_hit_second_hit_after_absorb_lands_on_player() -> void:
	# The synchronous _docked_ship=null flip means a same-frame second hit lands on the PLAYER (HP),
	# not a consumed fighter (no double-absorb). Models two enemy bodies entering the same physics tick.
	var p := _make()
	p.try_dock_ship()
	var hp_before: int = p._health.current_hp
	p.apply_hit(2, p.global_position, _dummy_source(), false)  # absorbed (HP spared).
	p.apply_hit(2, p.global_position, _dummy_source(), false)  # second hit → HP (no docked ship left).
	assert_eq(p._health.current_hp, hp_before - 2, "the second hit after an absorb must damage HP")


func test_dock_grows_player_hitbox() -> void:
	# AC#3 +hitbox: docking grows the player's hitbox — the body CollisionShape2D (projectiles) + the
	# HurtboxComponent shape (contact) — from the clean radius (11) to the docked radius (DockedShipTuning).
	# The swap is deferred (set_deferred — safe inside a physics callback); await a frame for it to land.
	var p := _make()
	var docked_radius: float = p.docked_ship_tuning.docked_hitbox_radius
	var body_shape: CollisionShape2D = p.get_node("CollisionShape2D")
	var hurtbox_shape: CollisionShape2D = p.get_node("HurtboxComponent/CollisionShape2D")
	# Clean: both shapes at the base radius (11).
	assert_almost_eq((body_shape.shape as CircleShape2D).radius, 11.0, 0.01, "clean body shape should be the base radius")
	assert_almost_eq((hurtbox_shape.shape as CircleShape2D).radius, 11.0, 0.01, "clean hurtbox shape should be the base radius")
	p.try_dock_ship()
	await get_tree().physics_frame  # let the set_deferred shape swap land.
	# Docked: both shapes grown to the docked radius (the +hitbox — a bigger target, [Risk-12]).
	assert_almost_eq((body_shape.shape as CircleShape2D).radius, docked_radius, 0.01, "body shape should grow to the docked radius")
	assert_almost_eq((hurtbox_shape.shape as CircleShape2D).radius, docked_radius, 0.01, "hurtbox shape should grow to the docked radius")


# --- Story 2.4 (Task 5.1) — the +28 px single-source desync guard ---

func test_stream_and_dock_offset_are_single_sourced() -> void:
	# Desync guard (AC#1): the parallel bullet's x-offset (stream_offset_x) and the wingman visual's
	# station (dock_offset_x) are intentionally the SAME value — the stream fires FROM the wingman's
	# position, so the bullet origin and the visual must never drift apart via retuning. Pin them equal
	# against the runtime .tres (loaded via player.tscn) so a future retune that changes only one is
	# caught. Do NOT split them into two unrelated constants (the +28 px is single-sourced).
	var p := _make()
	assert_almost_eq(p.docked_ship_tuning.stream_offset_x, p.docked_ship_tuning.dock_offset_x, 0.001,
		"stream_offset_x and dock_offset_x must stay in sync (the stream fires from the wingman's station)")
