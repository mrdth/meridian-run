extends GutTest
# The ≤3 Hz flash cadence gate (Story 1.6 / AC5 — the load-bearing photosensitive-safety invariant).
# Per the UX accessibility review, the cap is enforced CENTRALLY on the coordinator's HitFlash (one
# global gate), not summed across emitters. This is the safety test — it MUST exist and pass.
#
# Two layers: (1) the pure gate seam (is_flash_allowed) for crisp boundary math, and (2) the
# integration behavior — 3 requests within 1/3s ⇒ only the first modulates; a 4th after >1/3s
# modulates again.

const MIN_INTERVAL: float = 1.0 / Constants.MAX_FLASH_HZ  # ≈0.333s


func before_each() -> void:
	Pool.clear()


func test_max_flash_hz_is_three() -> void:
	# The cap value itself (UX A1 / arch D14).
	assert_eq(Constants.MAX_FLASH_HZ, 3.0)


func test_is_flash_allowed_boundary() -> void:
	# Pure gate seam — deterministic boundary math. last_time=0; a flash is allowed iff now >= ~0.333s.
	assert_false(HitFlash.is_flash_allowed(0.0, 0.0))      # same instant
	assert_false(HitFlash.is_flash_allowed(0.0, 0.332))    # just under the window
	assert_true(HitFlash.is_flash_allowed(0.0, MIN_INTERVAL))  # exactly at the window (>=)
	assert_true(HitFlash.is_flash_allowed(0.0, 0.5))       # well after


func test_gate_drops_rapid_flashes_then_allows_after_window() -> void:
	# Integration: 3 requests within 1/3s ⇒ only the first modulates the target; a 4th after >1/3s
	# modulates again. The gate is the only thing standing between overlapping emitters and a >3Hz
	# aggregate flash rate.
	var flash := HitFlash.new()
	add_child_autofree(flash)
	var target := Polygon2D.new()
	target.modulate = Color.WHITE
	add_child_autofree(target)
	var flash_color := Color(1.0, 0.2, 0.2)

	# Flash #1 — allowed (sentinel _last_flash_time). Modulate tweens toward the color.
	flash.request(target, flash_color, 0.08)
	await get_tree().process_frame
	assert_true(target.modulate.g < 0.99, "flash #1 should modulate the target")

	# Let flash #1's tween finish (returns to white) but stay WITHIN the <1/3s gate window.
	await get_tree().create_timer(0.1).timeout  # ~0.1s elapsed; tween done; gate still closed

	# Flashes #2 and #3 — both within 1/3s of #1 ⇒ DROPPED by the gate (no new tween).
	flash.request(target, flash_color, 0.08)
	flash.request(target, flash_color, 0.08)
	await get_tree().process_frame
	assert_almost_eq(target.modulate.g, 1.0, 0.001, "flashes within the gate window must be dropped")

	# Wait beyond the 1/3s window from #1, then flash #4 — allowed again.
	await get_tree().create_timer(0.3).timeout  # total ~0.4s since #1 ⇒ past the gate window
	flash.request(target, flash_color, 0.08)
	await get_tree().process_frame
	assert_true(target.modulate.g < 0.99, "flash #4 (after the gate window) should modulate again")


func test_gate_is_unconditional_under_reduced_motion() -> void:
	# AC5 — the ≤3 Hz cap is UNCONDITIONAL (photosensitive safety is not optional); reduced_motion
	# dampens AMPLITUDE (duration), never the cadence gate. Two rapid flashes under reduced motion
	# are STILL gated — only the first modulates.
	var flash := HitFlash.new()
	flash.set_motion_scale(0.3)  # reduced motion — dampens amplitude/duration only
	add_child_autofree(flash)
	var target := Polygon2D.new()
	target.modulate = Color.WHITE
	add_child_autofree(target)
	var flash_color := Color(1.0, 0.2, 0.2)

	flash.request(target, flash_color, 0.08)  # #1 allowed (dampened duration: 0.08 * 0.3 = 0.024s)
	await get_tree().process_frame
	assert_true(target.modulate.g < 0.99)
	await get_tree().create_timer(0.1).timeout  # #1 tween done; still within the 1/3s gate window
	flash.request(target, flash_color, 0.08)   # #2 — must STILL be gated under reduced_motion
	await get_tree().process_frame
	assert_almost_eq(target.modulate.g, 1.0, 0.001, "gate must hold unconditionally under reduced_motion")
