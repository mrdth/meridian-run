extends GutTest
# Unit tests for FormationDefinition (1.4). Loads standard.tres and verifies the data
# round-trips (slots, curves present + non-empty, timing fields), then exercises
# ContentRegistry.get_formation_def (the spawner's content path, AR8).

const _FORM := preload("res://resources/formations/standard.tres")


func test_loads_as_formation_definition() -> void:
	assert_true(_FORM is FormationDefinition)


func test_id_is_standard() -> void:
	assert_eq(_FORM.id, &"standard")


func test_has_eight_slots() -> void:
	# 2 rows × 4 cols authored for E1's wave (budget caps at 12).
	assert_eq(_FORM.slots.size(), 8)


func test_entry_and_dive_curves_present_and_non_empty() -> void:
	assert_not_null(_FORM.entry_curve)
	assert_not_null(_FORM.dive_curve)
	assert_gt(_FORM.entry_curve.get_point_count(), 1)
	assert_gt(_FORM.dive_curve.get_point_count(), 1)


func test_entry_curve_starts_above_slot_ends_at_slot() -> void:
	# Curves are RELATIVE to the slot. Entry: from off-screen-above (negative y) to slot (0,0).
	var baked_len: float = _FORM.entry_curve.get_baked_length()
	assert_gt(baked_len, 0.0)
	var start: Vector2 = _FORM.entry_curve.sample_baked(0.0)
	var end: Vector2 = _FORM.entry_curve.sample_baked(baked_len)
	assert_lt(start.y, 0.0)  # starts above the slot
	assert_almost_eq(end.x, 0.0, 0.5)
	assert_almost_eq(end.y, 0.0, 0.5)


func test_dive_curve_goes_downward_off_screen() -> void:
	# Dive: slot (0,0) → far below (+y, off-screen-bottom).
	var baked_len: float = _FORM.dive_curve.get_baked_length()
	var start: Vector2 = _FORM.dive_curve.sample_baked(0.0)
	var end: Vector2 = _FORM.dive_curve.sample_baked(baked_len)
	assert_almost_eq(start.y, 0.0, 0.5)
	assert_gt(end.y, 720.0)  # exits below the 720-tall field


func test_dive_aim_track_factor_default_is_capture_once() -> void:
	# Schema default 0.0 = classic aim captured once at dive-start (preserves prior behavior
	# for any formation that doesn't opt into live tracking).
	var f := FormationDefinition.new()
	assert_eq(f.dive_aim_track_factor, 0.0)


func test_dive_aim_track_factor_authored() -> void:
	# standard.tres opts into continuous dive aim tracking (anti-camp: divers follow a player
	# who relocates to a screen edge after dive-start, instead of missing on a stale aim).
	assert_almost_eq(_FORM.dive_aim_track_factor, 0.3, 0.001)


func test_sweep_fields_default_to_dives_only() -> void:
	# Schema defaults: sweep_chance 0.0 (dives-only legacy), sweep_y 430 (decision-log [Sweep-state]).
	var f := FormationDefinition.new()
	assert_eq(f.sweep_chance, 0.0)
	assert_eq(f.sweep_y, 430.0)


func test_sweep_fields_authored() -> void:
	# standard.tres opts into sweeps (0.3 of post-hold attacks) at sweep_y 430.
	assert_almost_eq(_FORM.sweep_chance, 0.3, 0.001)
	assert_almost_eq(_FORM.sweep_y, 430.0, 0.001)


func test_registry_returns_standard_formation() -> void:
	# AR8 — the spawner fetches formations through ContentRegistry, not load().
	var f: FormationDefinition = ContentRegistry.get_formation_def(&"standard")
	assert_not_null(f)
	assert_eq(f.id, &"standard")


func test_registry_missing_formation_returns_null() -> void:
	# No formation fallback (unlike enemies); a miss is a config error surfaced as null +
	# a logged error (assert_push_error marks it expected so GUT doesn't flag it).
	assert_null(ContentRegistry.get_formation_def(&"nonexistent"))
	assert_push_error("missing FormationDefinition")
