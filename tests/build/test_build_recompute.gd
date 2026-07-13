extends GutTest
# Story 2.6 (Task 8 / AC2) — PURE-LOGIC tests for BuildRecompute (NP3 — Threat-Relative Sacrifice
# Ceiling). NO Node, NO physics_frame, NO scene instantiation: these exercise the recompute formulas
# directly (the build engine is pure logic — project-context.md "separate pure logic from Node code").
# Deterministic: each test builds a SacrificeTuning with KNOWN values (NOT the .tres, which is the
# runtime/playtest source of truth and may be retuned — memory tres-overrides-gd-default-for-tuning).
# assert_almost_eq for the float arithmetic (1.0 + 0.3 is not exactly 1.3 in binary).

const _EPS := 0.0001


func _cfg(
	base_power: float = 1.0,
	power_per_wing: float = 0.3,
	max_threat_fraction: float = 0.02,
	duration: float = 10.0,
	burst_damage_base: float = 1.5,
) -> SacrificeTuning:
	# Build a tuning with KNOWN values for deterministic pure-logic assertions (NOT the .tres instance,
	# which is the runtime source of truth and may drift during playtest tuning).
	var c := SacrificeTuning.new()
	c.base_power = base_power
	c.power_per_wing = power_per_wing
	c.max_threat_fraction = max_threat_fraction
	c.duration = duration
	c.burst_damage_base = burst_damage_base
	return c


# --- sacrifice_power (linear in wing_level) ---

func test_sacrifice_power_at_zero_wing_is_base() -> void:
	# wing_level 0 → base_power (the floor; AC1's nominal ×1.5 lives at power=1.0).
	var c := _cfg()
	assert_almost_eq(BuildRecompute.sacrifice_power(0, c), 1.0, _EPS)


func test_sacrifice_power_scales_linearly_with_wing() -> void:
	# Linear: power = base_power + wing_level × power_per_wing (1.0 + n×0.3).
	var c := _cfg()
	assert_almost_eq(BuildRecompute.sacrifice_power(1, c), 1.3, _EPS)   # 1.0 + 1×0.3
	assert_almost_eq(BuildRecompute.sacrifice_power(2, c), 1.6, _EPS)   # 1.0 + 2×0.3
	assert_almost_eq(BuildRecompute.sacrifice_power(10, c), 4.0, _EPS)  # 1.0 + 10×0.3


func test_sacrifice_power_uses_power_per_wing_knob() -> void:
	# A different power_per_wing slopes the line (pins the knob is read, not hardcoded 0.3).
	var c := _cfg(1.0, 0.5, 0.02, 10.0, 1.5)
	assert_almost_eq(BuildRecompute.sacrifice_power(4, c), 3.0, _EPS)   # 1.0 + 4×0.5


# --- threat_ceiling (the NP3 clamp: min(raw, threat × max_threat_fraction)) ---

func test_threat_ceiling_unclamped_returns_raw_and_duration() -> void:
	# raw < cap → no clamp. wing_level=0 (raw=1.0), threat=100, cap=100×0.02=2.0 → power=1.0, duration=10.
	var c := _cfg()
	var b: SacrificeBurst = BuildRecompute.threat_ceiling(0, 100.0, c)
	assert_almost_eq(b.power, 1.0, _EPS)
	assert_almost_eq(b.duration, 10.0, _EPS)


func test_threat_ceiling_clamps_when_raw_exceeds_cap() -> void:
	# raw > cap → clamp to cap. wing_level=10 (raw=4.0), threat=100, cap=2.0 → power=2.0.
	var c := _cfg()
	var b: SacrificeBurst = BuildRecompute.threat_ceiling(10, 100.0, c)
	assert_almost_eq(b.power, 2.0, _EPS, "raw 4.0 must clamp to the threat ceiling 2.0")


func test_threat_ceiling_unclamped_passes_through_nonzero_wing_investment() -> void:
	# Review fix: this was a byte-for-byte duplicate of test_threat_ceiling_unclamped_returns_raw_and_duration
	# (same wing_level/threat/cfg). Replaced with a distinct case: raw < cap at a NON-zero wing_level, so
	# the unclamped pass-through is verified for an actual investment value, not just the wing=0 floor.
	# wing_level=3 (raw=1.0+3×0.3=1.9), threat=1000, cap=1000×0.02=20.0 → power=1.9 (well under the cap).
	var c := _cfg()
	var b: SacrificeBurst = BuildRecompute.threat_ceiling(3, 1000.0, c)
	assert_almost_eq(b.power, 1.9, _EPS, "raw 1.9 must pass through unclamped when well under the cap")


func test_threat_ceiling_zero_threat_clamps_power_to_zero() -> void:
	# threat=0 → cap=0 → power=0 (the burst is still APPLIED — "always useful" via the fixed shape — but
	# the damage multiplier floors at ×1.0; this is the "never an insta-win" backstop).
	var c := _cfg()
	var b: SacrificeBurst = BuildRecompute.threat_ceiling(5, 0.0, c)
	assert_almost_eq(b.power, 0.0, _EPS)
	assert_almost_eq(b.duration, 10.0, _EPS, "duration is the fixed window even at zero threat")


func test_threat_ceiling_high_wing_level_clamp_bites() -> void:
	# Edge case (Dev Notes §"⚠️ Edge cases" — unbounded wing_level): an absurd wing_level is reined in by
	# the threat clamp — the guarantee that unbounded wing_level can't break the burst. wing_level=100
	# (raw=31.0), threat=50, cap=50×0.02=1.0 → power=1.0.
	var c := _cfg()
	var b: SacrificeBurst = BuildRecompute.threat_ceiling(100, 50.0, c)
	assert_almost_eq(b.power, 1.0, _EPS, "the threat clamp must bite on an absurd wing_level")


func test_threat_ceiling_at_exact_boundary() -> void:
	# raw == cap → min returns cap (boundary is clean/inclusive). wing_level=0 (raw=1.0); threat=50 →
	# cap=50×0.02=1.0 == raw.
	var c := _cfg()
	var b: SacrificeBurst = BuildRecompute.threat_ceiling(0, 50.0, c)
	assert_almost_eq(b.power, 1.0, _EPS)


# --- burst_damage_mult (the "always useful, never an insta-win" formula: 1 + (base−1)×power) ---

func test_burst_damage_mult_power_zero_is_one() -> void:
	# power=0 → 1.0× (normal damage — but triple-shot + fast-fire still make the burst useful).
	var c := _cfg()
	assert_almost_eq(BuildRecompute.burst_damage_mult(0.0, c), 1.0, _EPS)


func test_burst_damage_mult_power_one_is_base() -> void:
	# power=1.0 → ×1.5 (the nominal AC1 baseline at wing_level 0).
	var c := _cfg()
	assert_almost_eq(BuildRecompute.burst_damage_mult(1.0, c), 1.5, _EPS)


func test_burst_damage_mult_power_two_is_double_bonus() -> void:
	# power=2.0 → ×2.0 (investment reward — threat-clamped in practice so it never reaches insta-win).
	var c := _cfg()
	assert_almost_eq(BuildRecompute.burst_damage_mult(2.0, c), 2.0, _EPS)


func test_burst_damage_mult_scales_with_burst_damage_base_knob() -> void:
	# A different burst_damage_base slopes the bonus (pins the knob is read, not hardcoded 1.5).
	var c := _cfg(1.0, 0.3, 0.02, 10.0, 2.0)  # burst_damage_base = 2.0
	assert_almost_eq(BuildRecompute.burst_damage_mult(1.0, c), 2.0, _EPS)   # 1.0 + (2.0−1.0)×1.0
	assert_almost_eq(BuildRecompute.burst_damage_mult(0.5, c), 1.5, _EPS)   # 1.0 + 1.0×0.5
