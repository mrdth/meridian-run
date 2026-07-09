extends GutTest
# Unit tests for CaptorTuning (Story 2.1, Task 10). Pure data — no scene instantiation. Verifies the
# .tres loads with the GDD timings, the .tres wins over the .gd defaults (the gotcha: editing the
# .gd defaults has no runtime effect), and every FSM duration field is present + positive.

const TuningRes := preload("res://resources/captor_tuning.tres")
const TuningScript := preload("res://enemies/captor/captor_tuning.gd")


func test_tuning_loads_with_gdd_timings() -> void:
	var t: CaptorTuning = TuningRes
	assert_not_null(t)
	# AC#5: the GDD FSM timings (these are the .tres values — the .tres overrides the .gd defaults).
	assert_eq(t.enter_duration_s, 1.0)
	assert_eq(t.formation_duration_min_s, 3.5)
	assert_eq(t.formation_duration_max_s, 5.5)
	assert_eq(t.telegraph_duration_s, 0.7)   # the fair-dodge window (AC#3).
	assert_eq(t.capture_duration_s, 0.4)     # AC#4.
	assert_eq(t.dive_duration_s, 1.6)        # AC#4.


func test_tres_instance_is_independent_of_gd_default() -> void:
	# The .gd default enter_duration_s is 1.0; a fresh .new() instance gets the .gd default. Mutating
	# it must NOT affect the loaded .tres instance (the cached .tres is a separate instance).
	var fresh: CaptorTuning = TuningScript.new()
	assert_eq(fresh.telegraph_duration_s, 0.7)  # .gd default
	fresh.telegraph_duration_s = 0.123
	assert_eq(fresh.telegraph_duration_s, 0.123)
	assert_eq(TuningRes.telegraph_duration_s, 0.7)  # the .tres is unaffected


func test_all_fsm_durations_present_and_positive() -> void:
	var t: CaptorTuning = TuningRes
	for d: float in [t.enter_duration_s, t.formation_duration_min_s, t.formation_duration_max_s,
			t.telegraph_duration_s, t.capture_duration_s, t.dive_duration_s]:
		assert_gt(d, 0.0)
	assert_gt(t.formation_duration_max_s, t.formation_duration_min_s)
	# Geometry fields present + sane (the captor + CaptureColumn read these).
	assert_gt(t.formation_row_y, 0.0)
	assert_gt(t.capture_column_width_px, 0.0)
