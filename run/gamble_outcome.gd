class_name GambleOutcome
extends RefCounted
# Story 2.7 — the per-wave gamble-outcome classification (FR20 detection half). Pure logic → GUT-tested
# without instantiating scenes (RefCounted statics, no Node, no EventBus). Mirrors the pure-logic shape of
# build/build_recompute.gd (2.6) and run/run_state.gd / build_state.gd.
#
# E2 (this story) PRODUCES the classification at wave-clear; E3 (Story 3.4) CONSUMES it to gate the
# safe-play currency bonus (base + safe_play_bonus_pct iff SAFE). This is the classic emit-now/consume-
# later seam — same shape as sacrifice_burst_started (2.5 emit / 2.6 consume). E2 carries NO currency
# logic (AC4); the outcome is a classification only.
#
# SAFE    = the player avoided capture for the entire wave (no capture event).
# COURTED = a capture event occurred this wave — REGARDLESS of later rescue/sacrifice/absorb/failed-rescue
#           resolution (the docked fighter may have come and gone; the gamble was courted). The source
#           truth is Player._captured_this_wave (set on capture, held until the next wave_started reset).

enum Outcome { SAFE, COURTED }


# The classification. Trivial by design: SAFE iff no capture occurred this wave. The value of giving this
# a named type + pure function is the explicit, typed E2→E3 contract (and a unit-testable seam), not logic.
# `capture_occurred` is sourced from Player.was_captured_this_wave() at wave-clear.
static func classify(capture_occurred: bool) -> Outcome:
	return Outcome.COURTED if capture_occurred else Outcome.SAFE
