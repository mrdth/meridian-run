extends Node
# STUB (Story 1.1). Will own the run seed → named RNG sub-streams (D3/ADR-2).
# Real API + logic land in Story 4.1; do not implement here. Returns inert
# defaults so any early caller does not crash.

var _stub_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func new_run(_seed: int) -> void:
	Log.warn("seed", "SeedManager.new_run is a stub — implemented in Story 4.1")


func stream(_name: StringName) -> RandomNumberGenerator:
	Log.warn("seed", "SeedManager.stream is a stub — implemented in Story 4.1")
	return _stub_rng # stable instance — replaced by named sub-streams in Story 4.1
