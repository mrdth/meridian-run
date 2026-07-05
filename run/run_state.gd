class_name RunState
extends Resource
# Run-scope state spine (AR2/D1): ships + score live here (run scope); per-wave HP
# stays on HealthComponent (reset each wave). This is the THIN E1 slice — the full
# RunState (seed/currency/build-ladders) is Epic 4 (Story 4-6); ships+score are
# load-bearing for E1's ship-economy gate (AC1/AC3/AC5), so the spine lands now.
#
# Runtime-only — NO `.tres` (it is per-run mutable state, never persisted — D5/ADR-3
# "no resume"). Owned by the Arena (the E1 run host), passed explicitly to the spawner;
# ownership migrates to GameManager when its FSM lands in Story 4-7. It is deliberately
# NOT an autoload (the registry's 11 autoloads do not include it).
#
# Pure data + methods only — NO EventBus calls, NO signals (keeps it unit-testable; the
# Node layer — Arena/Spawner — emits bus signals off this state). add_ship() is encoded
# now (forward-compat for E2/E3 ship-gain sources) but has NO E1 caller.

var ships: int = 0   # current lives (run economy). Set in begin_run().
var score: int = 0   # cumulative, display-only (FR49). Set in begin_run().


func begin_run() -> void:
	# The E1 run host (Arena) calls this on start/replay. Ships from the immutable
	# baseline; score always starts at 0 (never carried over — runs are independent).
	ships = Constants.BASE_SHIPS  # 3
	score = 0


func spend_ship() -> int:
	# Lose one ship (a player HP=0 within a wave → Arena calls this). Floors at 0 and
	# RETURNS the post-spend count so the caller decides respawn-vs-game-over on
	# `remaining == 0` (the run host owns that decision, not this spine).
	ships = maxi(ships - 1, 0)
	assert(ships >= 0, "RunState: ships must never go negative")
	return ships


func add_score(amount: int) -> void:
	# Cumulative, display-only (FR49 — score is NEVER spent). Never decrements: a
	# negative amount (a defensive guard against bad callers) is clamped to a no-op.
	score += maxi(amount, 0)


func add_ship(amount: int = 1) -> void:
	# Forward-compat for E2/E3 ship-gain sources (capture-keep regain, shop +ship,
	# tier-cap floor). Capped at MAX_SHIPS (FR8). E1 has NO caller — the path is
	# encoded and unit-tested but exercised ×0 in gameplay. Negative amounts (a
	# defensive guard against bad callers) are clamped to a no-op, mirroring add_score().
	ships = mini(ships + maxi(amount, 0), Constants.MAX_SHIPS)


func reset() -> void:
	# Alias to begin_run() semantics — clear for a fresh run (used on game-over replay).
	begin_run()
