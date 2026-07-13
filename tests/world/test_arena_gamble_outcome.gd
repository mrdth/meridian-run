extends GutTest
# Story 2.7 (Task 6) — integration tests for the per-wave gamble-outcome signal (FR20 detection half).
# The Arena subscribes to EventBus.wave_cleared; on clear it reads Player.was_captured_this_wave(),
# classifies via GambleOutcome.classify, and emits EventBus.gamble_outcome_recorded(SAFE|COURTED) for E3
# (Story 3.4) to consume. Mirrors test_arena_captor_resolution.gd (arena.tscn + halted spawner + drive-by-
# signal). Uses the working typed-payload assertion (memory gut-payload-assertion-bug: get_signal_parameters
# + assert_eq, NOT assert_signal_emitted_with_parameters).
#
# AC1: no capture → SAFE. AC2: capture → COURTED regardless of later resolution. AC3: emitted at wave-clear.

const ArenaScene := preload("res://world/arena.tscn")


func before_each() -> void:
	Pool.clear()


func _make() -> Arena:
	# arena.tscn wires Player + spawner + WaveController; Arena._ready runs begin_run (ships=3) + connects
	# wave_cleared → _on_wave_cleared. Halt the spawner's drip so no captor/enemy noise interferes.
	# auto_replay_on_loss off so a capture-driven ship spend can't queue a deferred scene reload mid-test
	# (the field's own doc comment: tests flip it false so a deferred reload can't reset the GUT runner).
	var arena: Arena = ArenaScene.instantiate() as Arena
	add_child_autofree(arena)
	arena._spawner.set_active(false)
	arena.auto_replay_on_loss = false
	return arena


# --- AC1: no capture → SAFE ---

func test_wave_clear_with_no_capture_emits_safe() -> void:
	var arena := _make()
	watch_signals(EventBus)
	assert_false(arena._player.was_captured_this_wave(), "precondition: no capture yet")
	EventBus.wave_cleared.emit(1)
	assert_signal_emitted(EventBus, "gamble_outcome_recorded", "wave-clear should emit the gamble outcome")
	var p: Array = get_signal_parameters(EventBus, "gamble_outcome_recorded")
	assert_eq(p[0], GambleOutcome.Outcome.SAFE, "no capture this wave → SAFE")


# --- AC2: capture → COURTED ---

func test_wave_clear_after_capture_emits_courted() -> void:
	var arena := _make()
	watch_signals(EventBus)
	# try_capture() sets _captured_this_wave=true + emits ship_depleted → spend_ship (3→2) → respawn. The
	# flag survives the respawn (only wave_started resets it).
	assert_true(arena._player.try_capture(), "precondition: capture should land on a clean player")
	assert_true(arena._player.was_captured_this_wave(), "the flag is set on capture")
	EventBus.wave_cleared.emit(1)
	assert_signal_emitted(EventBus, "gamble_outcome_recorded")
	var p: Array = get_signal_parameters(EventBus, "gamble_outcome_recorded")
	assert_eq(p[0], GambleOutcome.Outcome.COURTED, "a capture occurred → COURTED")


func test_capture_then_rescue_still_emits_courted() -> void:
	# AC2 regression: "regardless of later rescue resolution." Capture, THEN dock a rescued ship — the
	# outcome must still be COURTED (the gamble was courted; the flag is held until wave_started resets it).
	var arena := _make()
	watch_signals(EventBus)
	assert_true(arena._player.try_capture(), "capture first")
	assert_true(arena._player.try_dock_ship(), "rescue docks a fighter after the capture")
	assert_true(arena._player.was_captured_this_wave(), "rescue does NOT reset the capture flag")
	EventBus.wave_cleared.emit(1)
	var p: Array = get_signal_parameters(EventBus, "gamble_outcome_recorded")
	assert_eq(p[0], GambleOutcome.Outcome.COURTED, "capture+rescue still → COURTED")


# --- reset across waves ---

func test_flag_resets_next_wave_so_a_clean_wave_emits_safe_again() -> void:
	# wave_started (the next wave's intro) resets _captured_this_wave. A capture in wave 1 (COURTED) must
	# NOT bleed into wave 2 — a clean wave 2 emits SAFE. Also pins the ordering hazard: the Arena reads the
	# flag synchronously during wave_cleared, BEFORE wave_started resets it (the COURTED read at wave 1
	# proves the read happened before the wave-2 reset).
	var arena := _make()
	watch_signals(EventBus)
	assert_true(arena._player.try_capture(), "wave 1: capture")
	EventBus.wave_cleared.emit(1)  # → COURTED (read before any reset)
	var p1: Array = get_signal_parameters(EventBus, "gamble_outcome_recorded")
	assert_eq(p1[0], GambleOutcome.Outcome.COURTED, "wave 1 (capture) → COURTED")
	# Next wave: wave_started resets the flag; no capture in wave 2.
	EventBus.wave_started.emit(2, 60.0)
	assert_false(arena._player.was_captured_this_wave(), "wave_started resets the capture gate")
	EventBus.wave_cleared.emit(2)  # → SAFE
	assert_signal_emit_count(EventBus, "gamble_outcome_recorded", 2)
	var p2: Array = get_signal_parameters(EventBus, "gamble_outcome_recorded")
	assert_eq(p2[0], GambleOutcome.Outcome.SAFE, "wave 2 (clean) → SAFE (flag reset across waves)")


# --- AC3: signal shape (emitted ONLY at wave-clear) ---

func test_signal_not_emitted_before_first_wave_clear() -> void:
	# The outcome fires ONLY at wave-clear — not on capture alone. (A capture emits ship_depleted/ship_lost,
	# never gamble_outcome_recorded.)
	var arena := _make()
	watch_signals(EventBus)
	arena._player.try_capture()  # capture alone does NOT emit the outcome
	assert_signal_emit_count(EventBus, "gamble_outcome_recorded", 0)
