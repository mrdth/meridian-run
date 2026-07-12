extends GutTest
# Integration tests for the Player's capture entry (Story 2.2). Capture reuses the existing
# ship-loss path: try_capture() emits the LOCAL ship_depleted (intra-entity→parent, D8) — the same
# signal HP-death emits — so the Arena's spend_ship/respawn/game-over path handles the effect. Capture
# BYPASSES HP (HealthComponent is never touched). Guards: clean (is_capture_immune, a 2.2 stub → false)
# + once-per-wave (_captured_this_wave, reset on EventBus.wave_started). Mirrors test_player_health.gd.
#
# The player is NOT pooled — parent it under an autofreed Node2D "arena" so _ready runs (it connects
# the wave_started listen) and the subtree is freed cleanly each test.

const PlayerScene := preload("res://player/player.tscn")


func _make() -> Player:
	# Parent under a Node2D "arena" (player._ready wires FireSystem.projectile_parent to get_parent(),
	# typed Node2D). Mirrors test_player_health._make.
	var arena := Node2D.new()
	add_child_autofree(arena)
	var p: Player = PlayerScene.instantiate() as Player
	arena.add_child(p)
	return p


func test_try_capture_clean_emits_ship_depleted_once_and_returns_true() -> void:
	# AC#1: a clean player (first capture of the wave) → try_capture returns true + emits ship_depleted.
	var p := _make()
	watch_signals(p)
	var ok: bool = p.try_capture()
	assert_true(ok, "a clean player's try_capture should return true")
	assert_signal_emit_count(p, "ship_depleted", 1)


func test_try_capture_blocked_after_first_in_wave() -> void:
	# AC#3: once-per-wave — a second try_capture in the same wave is blocked (no second ship loss).
	var p := _make()
	watch_signals(p)
	assert_true(p.try_capture())  # first succeeds
	var ok2: bool = p.try_capture()  # second in the same wave → blocked
	assert_false(ok2, "a second capture in the same wave should be blocked")
	assert_signal_emit_count(p, "ship_depleted", 1)  # still exactly one


func test_is_capture_immune_returns_false_when_clean() -> void:
	# Story 2.3 — retired the 2.2 stub. is_capture_immune() now returns _docked: a CLEAN player is NOT
	# immune (capturable — the capture context); a docked player IS immune (FR16, covered in
	# test_player_dock.gd). The guard is real (try_capture checks it). Replaces the 2.2 "always false"
	# stub test — now it asserts the clean state specifically.
	var p := _make()
	assert_false(p.is_capture_immune(), "a clean player should NOT be capture-immune")


func test_wave_started_resets_capture_gate() -> void:
	# AC#3 reset: EventBus.wave_started (Intro→Active) clears _captured_this_wave, so a new wave's
	# first capture succeeds again. The player only LISTENS to the bus (read-only; ship_depleted stays
	# local, D8).
	var p := _make()
	watch_signals(p)
	assert_true(p.try_capture())  # wave 1 capture
	assert_signal_emit_count(p, "ship_depleted", 1)
	EventBus.wave_started.emit(2, 30.0)  # new wave begins → gate reset
	assert_true(p.try_capture(), "a new wave's first capture should succeed again")
	assert_signal_emit_count(p, "ship_depleted", 2)


func test_try_capture_does_not_touch_hp() -> void:
	# AC#1 bypass: capture costs a SHIP, not HP — the HealthComponent is never touched by try_capture
	# (no take_damage; no death flag). Full HP is restored later by respawn()'s reset_to_full().
	var p := _make()
	var hp_before: int = p._health.current_hp
	p.try_capture()
	assert_eq(p._health.current_hp, hp_before, "try_capture must not change HP (capture bypasses HP)")
	assert_false(p._health._is_dead, "try_capture must not set the death flag (no HP path)")


func test_try_capture_blocked_when_already_dead_this_frame() -> void:
	# Review fix (Story 2.2): an HP-death and a capture landing the same physics tick must not spend
	# two ships for one hit. If _health._is_dead is already true (HP hit 0 earlier this frame), a
	# same-frame try_capture() must be blocked — not emit a second ship_depleted.
	var p := _make()
	p._health._is_dead = true
	watch_signals(p)
	var ok: bool = p.try_capture()
	assert_false(ok, "try_capture should be blocked when the player already died this frame")
	assert_signal_emit_count(p, "ship_depleted", 0)
