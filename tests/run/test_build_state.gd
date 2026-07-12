extends GutTest
# Story 2.4 (Task 4.1) — pure-logic unit tests for BuildState (no scene — it is a Resource). Mirrors the
# pure-logic style of tests/run/test_run_state.gd (separate pure logic from Node/scene code).
#
# BuildState is the dual-ladder permanent spine (MAIN + WING) of RunState (AR2). The WING track is the
# docked fighter's PERMANENT identity (NP1): it grows on rescue and is NEVER cleared by consume — only
# reset() (the new-run path) writes a decrement. These tests pin that contract.


func _make() -> BuildState:
	# Resource — no add_child needed; .new() is the runtime construction path (AR2/D1: runtime-only,
	# never a .tres). Mirrors RunState._make.
	return BuildState.new()


func test_wing_level_starts_zero() -> void:
	var bs := _make()
	assert_eq(bs.wing_level, 0, "wing_level should start flat (E2 — investment is Story 3.3)")


func test_main_level_starts_zero() -> void:
	var bs := _make()
	assert_eq(bs.main_level, 0, "main_level should start flat (E2 — investment is Story 3.3)")


func test_record_rescue_grows_wing_level() -> void:
	# record_rescue() earns the WING track: 0 → 1 → 2.
	var bs := _make()
	bs.record_rescue()
	assert_eq(bs.wing_level, 1)
	bs.record_rescue()
	assert_eq(bs.wing_level, 2)


func test_record_rescue_does_not_touch_main_level() -> void:
	# record_rescue() touches ONLY the WING track — MAIN is the primary-weapon ladder, unrelated to rescue.
	var bs := _make()
	bs.record_rescue()
	bs.record_rescue()
	assert_eq(bs.main_level, 0, "record_rescue must NOT grow the MAIN track")


func test_reset_restores_both_tracks_flat() -> void:
	# reset() is the new-run path — the ONLY legitimate clearer. Restores flat after a run earned a WING track.
	var bs := _make()
	bs.record_rescue()
	bs.record_rescue()
	bs.reset()
	assert_eq(bs.wing_level, 0, "reset must zero the WING track (new-run path)")
	assert_eq(bs.main_level, 0, "reset must zero the MAIN track (new-run path)")


# Negative existence check (documented as a comment — you cannot assert absence of a method at runtime):
# BuildState exposes NO consume-side / clear / decrement mutator. The ONLY writer that decreases or zeroes
# a track is reset() (the new-run path). There is intentionally NO clear_wing() / consume_wing() /
# decrement_wing() API — the permanence invariant (NP1: "consume never clears the track") is enforced
# STRUCTURALLY: the consume paths live on the Player, which has no RunState reference (AR2), so they
# CANNOT reach this track even if they tried. If a future story needs to touch the WING track from a
# consume path, escalate NP1 first — do not silently add a mutator here.
