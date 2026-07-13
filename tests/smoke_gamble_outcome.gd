extends Node2D
# Story 2.7 (Task 7) — headless smoke for the per-wave gamble-outcome signal. Run as a SCENE (autoloads
# register on the normal game-flow path — memory headless-smoke-run-as-scene):
#   godot --headless tests/smoke_gamble_outcome.tscn
#
# Confirms end-to-end in a FRESH headless process (catches autoload/global-name wiring that GUT can mask):
#   1. A clean wave (no capture) → wave_clear emits gamble_outcome_recorded(SAFE).
#   2. A capture this wave → wave_clear emits gamble_outcome_recorded(COURTED).
#   3. wave_started resets the capture gate → the next clean wave emits SAFE again (no bleed-across-waves).
# The capture+rescue "regardless of resolution" case is covered by the GUT integration test; this smoke
# focuses on the wiring. Quits the tree on completion.

const _ARENA := preload("res://world/arena.tscn")

var _last_outcome: int = -1
var _emit_count: int = 0


func _ready() -> void:
	var ok: bool = true
	EventBus.gamble_outcome_recorded.connect(_on_outcome)

	# Fresh arena; halt the spawner drip + disable auto-replay so a capture's ship-spend can't reload.
	var arena: Arena = _ARENA.instantiate() as Arena
	add_child(arena)  # _ready fires synchronously (this node is already in the tree).
	arena._spawner.set_active(false)
	arena.auto_replay_on_loss = false
	var player: Player = arena._player

	# 1. Clean wave → SAFE.
	_emit_count = 0
	_last_outcome = -1
	EventBus.wave_cleared.emit(1)
	var safe_emitted: bool = (_emit_count == 1 and _last_outcome == GambleOutcome.Outcome.SAFE)
	print("[SMOKE] clean wave 1 → %s (expect SAFE, count=%d)" % [_name(_last_outcome), _emit_count])
	ok = ok and safe_emitted

	# 2. Capture this wave → COURTED. try_capture() spends a ship (3→2) + respawns; the flag survives.
	_emit_count = 0
	var captured: bool = player.try_capture()
	EventBus.wave_cleared.emit(2)
	var courted_emitted: bool = (_emit_count == 1 and _last_outcome == GambleOutcome.Outcome.COURTED)
	print("[SMOKE] capture (landed=%s) wave 2 → %s (expect COURTED, count=%d)" % [captured, _name(_last_outcome), _emit_count])
	ok = ok and captured and courted_emitted

	# 3. wave_started resets the gate → a clean wave emits SAFE again (no COURTED bleed across waves).
	_emit_count = 0
	EventBus.wave_started.emit(3, 60.0)
	print("[SMOKE]   capture gate after wave_started: %s (expect false)" % player.was_captured_this_wave())
	EventBus.wave_cleared.emit(3)
	var safe_again: bool = (_emit_count == 1 and _last_outcome == GambleOutcome.Outcome.SAFE)
	print("[SMOKE] clean wave 3 → %s (expect SAFE, count=%d)" % [_name(_last_outcome), _emit_count])
	ok = ok and safe_again

	print("[SMOKE] %s" % ("PASS — gamble-outcome signal verified headlessly" if ok else "FAIL — see lines above"))
	get_tree().quit(0 if ok else 1)


func _on_outcome(outcome: GambleOutcome.Outcome) -> void:
	_last_outcome = outcome
	_emit_count += 1


func _name(outcome: int) -> String:
	match outcome:
		GambleOutcome.Outcome.SAFE: return "SAFE"
		GambleOutcome.Outcome.COURTED: return "COURTED"
		_: return "(none yet)"
