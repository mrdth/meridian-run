class_name BuildState
extends Resource
# Story 2.4 — the dual-ladder permanent build spine (AR2/D1). A sub-object of RunState (the run-scope
# spine), co-located in run/ per architecture + project-context.md (NOT build/ — that domain holds the
# E3 engine pieces: stat_block / modifier / build_recompute). RunState owns one BuildState; the Arena
# (the run host) writes it; the Player NEVER touches RunState (AR2 — the structural permanence guarantee).
#
# TWO build ladders (architecture F-1, resolved v1.1 2026-07-01 — NOT the epics' superseded
# "rescued_track" spelling):
#   - MAIN (main_level) — the primary-weapon ladder.
#   - WING (wing_level) — the allied/rescue ladder; the docked fighter's PERMANENT track (NP1).
# Both start FLAT in E2 (Epic-2 hardcodes docked stats; investment wiring is Story 3.3). E2 only needs
# "exists, grows on rescue, survives consume" — so two int counters are the whole shape here. Do NOT
# build the D2 modifier/recompute pipeline (that is E3).
#
# 🏗️ NP1 — the docked ship's DUAL NATURE (architecture lines 600–631, 757):
#   - PERMANENT build track  = THIS BuildState.wing_level — RUN scope, never cleared by consume.
#   - TRANSIENT combat fighter = the DockedShip node + on-player combat presence — WAVE scope, consumed
#     on absorb / detached at wave-clear (already exists from Story 2.3; unchanged here).
# The headline invariant: **the consume path removes the fighter node but NEVER clears the track.**
#
# 🔒 Permanence is enforced STRUCTURALLY, not by discipline: there is NO consume-side / clear / decrement
# mutator on this class. The ONLY writer that decreases or zeroes a track is reset() (the new-run path,
# called by RunState.begin_run()). The consume paths (Player._consume_docked_ship on absorb,
# Player._on_wave_cleared on keep) live on the Player, which has no RunState reference (AR2) — they
# CANNOT reach this track even if they tried. Do NOT add a clear_wing()/consume_wing() API in a future
# story without escalating NP1 first.
#
# Runtime-only — NO `.tres` (per-run mutable state, never persisted — D5/ADR-3 "no resume"). Pure data +
# methods only — NO EventBus calls, NO signals (keeps it unit-testable; the Node layer — Arena — emits
# bus signals off this state, e.g. build_changed). Mirrors RunState's pure-logic shape.

# PRIMARY-WEAPON ladder (flat in E2 — Story 3.3 wires power-up investment through the recompute pipeline).
var main_level: int = 0

# ALLIED/RESCUE ladder — the docked fighter's PERMANENT identity (NP1). Grows on a successful rescue
# dock; survives the fighter being consumed (absorb) or detached (wave-clear). Never decremented except
# by reset() (a fresh run).
var wing_level: int = 0


func record_rescue() -> void:
	# Earn the WING track (NP1). Called by Arena._on_captor_resolved on a SUCCESSFUL rescue dock (inside
	# the `if _player.try_dock_ship():` block — a blocked/no-op dock earns nothing). Grows wing_level by 1.
	# NO ship-count change (the docked fighter is a ship-in-escrow; the only ship-count changes in the
	# Gamble are capture −1 / keep +1 — see Dev Notes §"Ship-count economy"). This is the ONLY grower of
	# the WING track in E2.
	wing_level += 1


func reset() -> void:
	# Restore both tracks to flat — the ONLY legitimate clearer, called by RunState.begin_run()/reset()
	# for a FRESH RUN. The permanence invariant (NP1) hinges on this being the sole decrement/reset path:
	# consume never calls this (it can't — the Player has no RunState ref, AR2).
	main_level = 0
	wing_level = 0
