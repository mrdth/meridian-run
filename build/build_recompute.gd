class_name BuildRecompute
extends RefCounted
# Story 2.6 — NP3 "Threat-Relative Sacrifice Ceiling" (architecture.md#NP3, lines 648–658). Pure
# logic → GUT-tested without instantiating any scene. No Node, no signals, no EventBus (the build
# engine is a recompute, never a mutator — project-context.md "Build engine = recompute, never
# mutate").
#
# E2 SLICE: the full StatBlock/Modifier recompute engine is Story 3.1 (E3, architecture.md D2 lines
# 213–221). 2.6 seeds BuildRecompute with ONLY the sacrifice-burst clamp — the slice NP3 needs.
# E3 will extend this class with the real track/StatBlock recompute; do NOT block E3's design.
#
# E2 pragmatism (Mrdth-confirmed 2026-07-13): E2 has no BuildTrack object (that is E3 / Story 3.1);
# the rescued-ship track is the flat int BuildState.wing_level. So these signatures take wing_level
# directly. E3 will evolve them to pass a BuildTrack with a .sacrifice_power() method.


# The rescued-ship track's "sacrifice power" — scales linearly with wing_level (the E2 track primitive).
# (Architecture calls track.sacrifice_power(); E2 has no BuildTrack, so this takes wing_level directly.)
static func sacrifice_power(wing_level: int, cfg: SacrificeTuning) -> float:
	return cfg.base_power + float(wing_level) * cfg.power_per_wing


# The NP3 clamp: raw power (from investment) capped by current-wave threat. Returns a SacrificeBurst
# carrying the clamped power + the fixed duration. "Always useful, never an insta-win": the fixed
# burst SHAPE (triple ±0.18 rad / 0.10 s fast-fire / ~10 s) always applies, so even a threat-clamped
# (power → 0) burst is still a triple-shot fast-fire window (useful); the clamp only reins in the
# damage multiplier (never an insta-win).
static func threat_ceiling(wing_level: int, threat: float, cfg: SacrificeTuning) -> SacrificeBurst:
	var raw := sacrifice_power(wing_level, cfg)
	var capped := minf(raw, threat * cfg.max_threat_fraction)
	return SacrificeBurst.new(capped, cfg.duration)


# Damage multiplier from the (clamped) power. Formula:
#   power = 0   → 1.0×  (normal damage, but triple-shot + fast-fire still apply → useful)
#   power = 1.0 → 1.5×  (the nominal ×1.5 at wing_level 0, AC1)
#   power > 1.0 → > 1.5× (investment reward, threat-clamped → never an insta-win)
static func burst_damage_mult(power: float, cfg: SacrificeTuning) -> float:
	return 1.0 + (cfg.burst_damage_base - 1.0) * power
