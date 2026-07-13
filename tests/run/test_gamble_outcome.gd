extends GutTest
# Story 2.7 (Task 6) — pure-logic unit tests for GambleOutcome (no scene — it is a RefCounted with statics).
# Mirrors the pure-logic style of tests/run/test_build_state.gd (separate pure logic from Node/scene code).
#
# GambleOutcome.classify is the FR20 detection-half classifier: SAFE iff no capture occurred this wave;
# COURTED if a capture occurred (regardless of later rescue/sacrifice/absorb/failed-rescue resolution).
# E2 PRODUCES this classification; E3 (Story 3.4) CONSUMES it to gate the safe-play currency bonus.


func test_classify_no_capture_returns_safe() -> void:
	assert_eq(GambleOutcome.classify(false), GambleOutcome.Outcome.SAFE, "no capture → SAFE")


func test_classify_capture_returns_courted() -> void:
	assert_eq(GambleOutcome.classify(true), GambleOutcome.Outcome.COURTED, "capture → COURTED")


func test_outcome_enum_values_are_stable() -> void:
	# Pin the E2→E3 contract: SAFE = 0, COURTED = 1 (stable int values — the documented int-fallback signal
	# variant would rely on these; the typed GambleOutcome.Outcome form is primary).
	assert_eq(GambleOutcome.Outcome.SAFE, 0)
	assert_eq(GambleOutcome.Outcome.COURTED, 1)


# Negative existence check (documented as a comment — you cannot assert absence of a field at runtime):
# GambleOutcome carries NO currency logic (AC4): no safe_play_bonus_pct, no currency field, no economy_tuning
# reference. It is a classification only. The currency grant lives in Story 3.4 (RunState + economy_tuning.tres).
