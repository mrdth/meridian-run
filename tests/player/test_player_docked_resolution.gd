extends GutTest
# Story 2.5 (Task 6.1) — the four-outcomes integration test (AC4). Drives ALL FOUR docked-ship outcomes
# from a docked state at the PLAYER level and asserts resolution + ship-count economy. The run-scope
# halves (add_ship +1, sacrifice_burst_started) are Arena-level — see test_arena_captor_resolution.gd
# (Task 6.2). This file owns the Player-side combat assertions:
#   - Sacrifice (AC1): consume the fighter, HP UNCHANGED, sacrifice_committed emitted.
#   - Keep (AC2): wave-clear while docked → ship_kept emitted + fighter detached (flies off).
#   - Absorb (AC3): hit while docked → fighter consumed, HP SPARED (pinned from 2.3 in the 4-outcome ctx).
#   - Mutual exclusion / forfeit-the-regain (FR18): a consume mid-wave → NO ship_kept at wave-clear.
#
# ⌨️ INPUT-SIM NOTE (Task 6.3): the story specified driving Sacrifice via Input.action_press("sacrifice")
# + a physics tick. That does NOT work reliably under GUT in Godot 4.6.3: Input.is_action_just_pressed
# compares the action's press frame-stamp to the current physics-frame counter, and a synthetic press
# (action_press / parse_input_event) only reads true when that counter is near zero (i.e. when the test
# runs first). Later in the suite (frame counter in the hundreds) the same synthetic press reads false —
# so the consume never fires and the assertion is flaky. Awaiting a real physics_frame is off-by-one
# (the stamp lands one frame before _physics_process reads it). Verified across action_press,
# parse_input_event, set_use_accumulated_input(false), manual _physics_process, and 1–2 awaited frames.
#
# Resolution: drive Sacrifice by calling p._try_sacrifice() DIRECTLY — the exact method the input-read
# line (`if Input.is_action_just_pressed("sacrifice"): _try_sacrifice()`) dispatches to. This exercises
# the real consume path (detach + JuiceFx + sacrifice_committed emit) faithfully; the one-line input
# DISPATCH is covered by the headless smoke (Task 7.2) + the manual playtest (Task 7.3). The run-scope
# burst-hook + ship economy are covered Arena-level in Task 6.2.
#
# For pure consume/signal assertions (keep, absorb, mutual-exclusion) we call the methods / emit the
# signals directly — no physics-frame dependency (memory area-overlap-tests-need-real-physics-frames
# only governs Area2D-overlap reads, not method calls).

const PlayerScene := preload("res://player/player.tscn")


func before_each() -> void:
	# Defensive: the Pool is an autoload; start each test from a known-empty pool (mirrors test_fire_system).
	Pool.clear()


func _make() -> Player:
	# Player under a Node2D "arena" (player._ready wires FireSystem.projectile_parent to get_parent(),
	# typed Node2D). Mirrors test_player_dock._make. No movement/fire input is injected; the consume paths
	# are driven by direct method calls, so _physics_process need not run.
	var arena := Node2D.new()
	add_child_autofree(arena)
	var p: Player = PlayerScene.instantiate() as Player
	arena.add_child(p)
	return p


func _dummy_source() -> Node2D:
	# apply_hit's `source` is the flash context (apply_hit flashes the PLAYER body, not the source). A
	# dummy Node2D suffices — mirrors test_player_dock._dummy_source.
	var s := Node2D.new()
	add_child_autofree(s)
	return s


# --- AC1 — Sacrifice ---

func test_sacrifice_consumes_fighter_spares_hp_emits_signal() -> void:
	# AC1 (the headline new mechanic): docked → sacrifice → fighter consumed (is_docked false), HP
	# UNCHANGED, sacrifice_committed emitted. NO spend_ship, NO HP change (FR18 — sacrifice is
	# ship-neutral; only capture −1 + keep +1 move ships). Driven via _try_sacrifice() directly (the
	# method the input-read line dispatches to — see the header input-sim note).
	var p := _make()
	watch_signals(p)
	p.try_dock_ship()
	assert_true(p.is_docked(), "precondition: player docked")
	var hp_before: int = p._health.current_hp
	p._try_sacrifice()  # the consume path the Sacrifice input triggers.
	assert_false(p.is_docked(), "sacrifice should consume the fighter (undocked)")
	assert_null(p._docked_ship, "the docked ship should be gone after sacrifice")
	assert_eq(p._health.current_hp, hp_before, "sacrifice must NOT damage HP (ship-neutral, FR18)")
	assert_signal_emitted(p, "sacrifice_committed", "sacrifice should emit sacrifice_committed")
	await get_tree().physics_frame  # let the deferred queue_free of the fighter land before teardown.


func test_sacrifice_when_clean_is_silent_noop() -> void:
	# A clean player (no docked fighter) → _try_sacrifice is a silent no-op (the _docked_ship == null guard
	# gates the whole path: no consume, no emit). This is the behavior the input-read line produces when
	# the player presses Sacrifice with nothing docked.
	var p := _make()
	watch_signals(p)
	assert_false(p.is_docked(), "precondition: player clean")
	p._try_sacrifice()
	assert_signal_emit_count(p, "sacrifice_committed", 0, "a clean player's sacrifice must be a silent no-op")
	assert_false(p.is_docked(), "a clean player stays clean")


func test_sacrifice_forfeits_keep_regain() -> void:
	# AC1 / FR18 forfeit-the-regain (the sacrifice half of mutual exclusion): a player who sacrifices
	# mid-wave is NOT docked at wave-clear → _on_wave_cleared does NOT emit ship_kept (no add_ship). The
	# consume forfeits the keep regain you would have earned by holding to wave-end.
	var p := _make()
	watch_signals(p)
	p.try_dock_ship()
	p._try_sacrifice()  # consume the fighter.
	assert_signal_emit_count(p, "sacrifice_committed", 1)
	assert_false(p.is_docked(), "precondition: fighter consumed by sacrifice")
	EventBus.wave_cleared.emit(1)  # wave-end — player no longer docked
	assert_signal_emit_count(p, "ship_kept", 0, "sacrificing mid-wave must forfeit the keep regain (no ship_kept)")
	await get_tree().physics_frame


# --- AC2 — Keep ---

func test_keep_on_wave_clear_emits_ship_kept_and_detaches() -> void:
	# AC2: docked + wave-clear → ship_kept emitted (BEFORE detach) + fighter detached (flies off). The
	# add_ship(+1) + ship_gained assertion is Arena-level (Task 6.2); here we assert the Player-side
	# ship_kept emit + the detach.
	var p := _make()
	watch_signals(p)
	p.try_dock_ship()
	assert_true(p.is_docked(), "precondition: player docked")
	EventBus.wave_cleared.emit(1)
	assert_signal_emitted(p, "ship_kept", "a docked wave-clear should emit ship_kept (the Keep outcome)")
	assert_false(p.is_docked(), "the fighter should fly off (detached) on keep")
	assert_null(p._docked_ship)
	await get_tree().physics_frame


func test_no_ship_kept_when_not_docked_at_wave_clear() -> void:
	# A player who was never docked (clean) at wave-clear → no ship_kept (the `if _docked_ship != null`
	# guard gates the emit). Mirrors the forfeit invariant for the never-docked case.
	var p := _make()
	watch_signals(p)
	EventBus.wave_cleared.emit(1)
	assert_signal_emit_count(p, "ship_kept", 0, "a clean player must not emit ship_kept at wave-clear")


# --- AC3 — Absorb (pinned from 2.3; re-asserted in the four-outcomes context) ---

func test_absorb_consumes_fighter_spares_hp() -> void:
	# AC3 (DONE in 2.3, re-asserted here for the four-outcomes context): docked + hit → fighter consumed,
	# HP SPARED, is_docked false. NO ship-count change. Direct apply_hit call (no overlap dependency).
	var p := _make()
	watch_signals(p)
	p.try_dock_ship()
	var hp_before: int = p._health.current_hp
	p.apply_hit(2, p.global_position, _dummy_source(), false)
	assert_null(p._docked_ship, "the docked ship should be consumed on absorb")
	assert_false(p.is_docked(), "the player should be undocked after the absorber fires")
	assert_eq(p._health.current_hp, hp_before, "HP must be SPARED on an absorb")
	assert_signal_emit_count(p, "ship_depleted", 0)  # NO ship-count change.


func test_absorb_forfeits_keep_regain() -> void:
	# AC3 / FR18 forfeit-the-regain (the absorb half of mutual exclusion): a player who absorbs mid-wave
	# is NOT docked at wave-clear → no ship_kept (no add_ship). Pinned here for the four-outcomes context
	# (the structural guard is the same `if _docked_ship != null` in _on_wave_cleared).
	var p := _make()
	watch_signals(p)
	p.try_dock_ship()
	p.apply_hit(2, p.global_position, _dummy_source(), false)  # absorb → undocked
	assert_false(p.is_docked(), "precondition: fighter consumed by absorb")
	EventBus.wave_cleared.emit(1)
	assert_signal_emit_count(p, "ship_kept", 0, "absorbing mid-wave must forfeit the keep regain")
	await get_tree().physics_frame
