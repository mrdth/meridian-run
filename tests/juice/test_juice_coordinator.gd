extends GutTest
# Integration tests for the arena-scoped JuiceCoordinator (Story 1.6 / AC1, AC2, AC5). Drives the
# three EventBus juice REQUEST signals and asserts the coordinator fans them out to its
# ScreenShake / HitFlash / pooled ParticleBurst children — including the Camera2D framing
# regression (the #1 risk: adding a camera must NOT change the idle view) and reduced-motion
# dampening. Mirrors the 1.3–1.5 GUT style (before_each Pool.clear(); autofree the scene root).

const ArenaScene := preload("res://world/arena.tscn")
const Tuning := preload("res://resources/juice_tuning.tres")


func before_each() -> void:
	Pool.clear()
	# Settings is an autoload — reset reduced_motion so each test starts at _motion_scale = 1.0.
	Settings.set_reduced_motion(false)


func _make_coordinator() -> JuiceCoordinator:
	# Build the coordinator subtree by hand (more focused than the whole arena). Children must be
	# added + tuning assigned BEFORE the coordinator enters the tree so @onready + _ready resolve.
	var coord := JuiceCoordinator.new()
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position = Vector2(640, 360)
	cam.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	cam.position_smoothing_enabled = false
	var shake := ScreenShake.new()
	shake.name = "ScreenShake"
	var flash := HitFlash.new()
	flash.name = "HitFlash"
	coord.add_child(cam)
	coord.add_child(shake)
	coord.add_child(flash)
	coord.tuning = Tuning
	add_child_autofree(coord)  # _ready fires here → connects EventBus + Settings
	return coord


func test_arena_scene_has_wired_coordinator_with_tuning() -> void:
	# Task 10: the arena scene includes a JuiceCoordinator with the camera/shake/flash children and
	# the tuning .tres assigned (verifies arena.tscn integration, not just the hand-built version).
	var arena: Arena = ArenaScene.instantiate() as Arena
	add_child_autofree(arena)
	arena._spawner.set_active(false)  # halt spawning so asserts are deterministic
	var coord: JuiceCoordinator = arena.get_node_or_null("JuiceCoordinator")
	assert_not_null(coord)
	assert_not_null(coord.tuning)
	assert_not_null(coord.get_node_or_null("Camera2D"))
	assert_not_null(coord.get_node_or_null("ScreenShake"))
	assert_not_null(coord.get_node_or_null("HitFlash"))


func test_camera_idle_framing_is_unchanged() -> void:
	# AC2 / Task 10.2 — the camera must NOT shift or crop the idle view. At rest the offset is zero
	# and the screen center is the play-field center (640,360) ⇒ view spans (0,0)–(1280,720).
	var coord := _make_coordinator()
	await get_tree().process_frame  # let the camera settle as the active camera
	assert_eq(coord._camera.offset, Vector2.ZERO)
	assert_almost_eq(coord._camera.global_position.x, 640.0, 0.5)
	assert_almost_eq(coord._camera.global_position.y, 360.0, 0.5)
	var sc: Vector2 = coord._camera.get_screen_center_position()
	assert_almost_eq(sc.x, 640.0, 2.0)
	assert_almost_eq(sc.y, 360.0, 2.0)


func test_arena_scene_camera_idle_framing_is_unchanged() -> void:
	# Review fix — Task 10.2's "non-negotiable" regression check was only ever exercised against a
	# hand-built stand-in (test_camera_idle_framing_is_unchanged above), so a future edit to the
	# REAL arena.tscn Camera2D node could break the idle framing without any test catching it. This
	# asserts directly on the shipped scene: the actual node's configured values, AND (as a live
	# behavioral check, not just config) that the arena's camera renders (0,0)–(1280,720) uncropped.
	var arena: Arena = ArenaScene.instantiate() as Arena
	add_child_autofree(arena)
	arena._spawner.set_active(false)  # halt spawning so asserts are deterministic
	var cam: Camera2D = arena.get_node("JuiceCoordinator/Camera2D")
	assert_eq(cam.position, Vector2(640.0, 360.0))
	assert_eq(cam.anchor_mode, Camera2D.ANCHOR_MODE_DRAG_CENTER)
	assert_false(cam.position_smoothing_enabled)
	await get_tree().process_frame  # let the camera settle as the active camera
	assert_eq(cam.offset, Vector2.ZERO)
	var sc: Vector2 = cam.get_screen_center_position()
	assert_almost_eq(sc.x, 640.0, 2.0)
	assert_almost_eq(sc.y, 360.0, 2.0)


func test_shake_request_rises_trauma_and_decays_to_zero() -> void:
	# AC1 — screen_shake_requested ⇒ trauma rises, _process decays it to 0, and the offset zeroes.
	var coord := _make_coordinator()
	EventBus.screen_shake_requested.emit(Constants.MAX_SHAKE_PX, 0.2)  # trauma = 1.0
	assert_eq(coord._shake.get_trauma(), 1.0)
	# Step _process past the 0.2s decay window (direct calls are deterministic; no engine double-tick
	# since there is no await in the loop).
	for _i in 20:
		coord._shake._process(0.016)  # 20 * 0.016 = 0.32s > 0.2s ⇒ fully decayed
	assert_eq(coord._shake.get_trauma(), 0.0)
	assert_eq(coord._camera.offset, Vector2.ZERO)


func test_shake_offset_never_exceeds_max_shake_px() -> void:
	# AC5 — amplitude is clamped to Constants.MAX_SHAKE_PX regardless of direction/trauma.
	var coord := _make_coordinator()
	EventBus.screen_shake_requested.emit(Constants.MAX_SHAKE_PX, 0.5)  # trauma = 1.0
	for _i in 12:
		coord._shake._process(0.016)
		assert_true(coord._camera.offset.length() <= Constants.MAX_SHAKE_PX + 0.001,
			"shake offset must never exceed MAX_SHAKE_PX")


func test_reduced_motion_dampens_shake_amplitude() -> void:
	# AC5 / D14 — reduced_motion dampens AMPLITUDE (dampen, don't remove). _motion_scale = 0.3 ⇒
	# peak offset ≤ MAX_SHAKE_PX * 0.3.
	var coord := _make_coordinator()
	Settings.set_reduced_motion(true)  # emits setting_changed → coordinator re-derives _motion_scale
	assert_almost_eq(coord._shake.get_motion_scale(), 0.3, 0.001)
	EventBus.screen_shake_requested.emit(Constants.MAX_SHAKE_PX, 0.5)
	for _i in 8:
		coord._shake._process(0.016)
	assert_true(coord._camera.offset.length() <= Constants.MAX_SHAKE_PX * 0.3 + 0.001)


func test_shake_short_hit_does_not_truncate_a_longer_shake_already_decaying() -> void:
	# Review fix — decay must not be rederived from total trauma / the NEWEST request's duration
	# alone (that model lets a tiny short-duration bump wipe out a big, longer shake's tail within
	# a handful of frames). The decay deadline only ever extends, so a small quick hit landing
	# mid-decay must not collapse a bigger shake already in flight.
	var coord := _make_coordinator()
	coord._shake.request(Constants.MAX_SHAKE_PX, 1.0)  # big, long shake: trauma = 1.0, deadline = 1.0s
	for _i in 10:
		coord._shake._process(0.016)  # ~0.16s into a 1.0s decay window
	coord._shake.request(1.0, 0.05)  # small, short graze shortly after
	for _i in 4:
		coord._shake._process(0.016)  # a naive `trauma / 0.05s` decay rate would zero this out here
	assert_true(coord._shake.get_trauma() > 0.5,
		"a short/small hit must not truncate a longer shake already in flight")


func test_reduced_motion_dampens_particle_amplitude() -> void:
	# Review fix (AC5 gap) — reduced_motion must dampen particle SPEED/SCALE amplitude too, not
	# just shake/flash. Compare the material the coordinator configures on a burst with motion on
	# vs. reduced.
	var coord := _make_coordinator()
	EventBus.particles_requested.emit(&"hit_spark", Vector2(50.0, 50.0), Color.CYAN, 1.0)
	await get_tree().physics_frame
	var full_burst: ParticleBurst = null
	for c in coord.get_children():
		if c is ParticleBurst:
			full_burst = c
	assert_not_null(full_burst)
	var full_speed_max: float = full_burst._mat.initial_velocity_max
	var full_scale_max: float = full_burst._mat.scale_max

	Settings.set_reduced_motion(true)
	EventBus.particles_requested.emit(&"hit_spark", Vector2(60.0, 60.0), Color.CYAN, 1.0)
	await get_tree().physics_frame
	var reduced_burst: ParticleBurst = null
	for c in coord.get_children():
		if c is ParticleBurst and c != full_burst:
			reduced_burst = c
	assert_not_null(reduced_burst)
	assert_true(reduced_burst._mat.initial_velocity_max < full_speed_max,
		"reduced motion must dampen particle speed")
	assert_true(reduced_burst._mat.scale_max < full_scale_max,
		"reduced motion must dampen particle scale")
	assert_true(reduced_burst._mat.initial_velocity_max > 0.0,
		"reduced motion must dampen, not remove, the particle burst")


func test_hit_flash_requested_tweens_target_modulate() -> void:
	# AC1 — hit_flash_requested(target, color) ⇒ the target's modulate tweens toward the color.
	# Test-stability fix: neither `await get_tree().process_frame` nor `create_timer(...).timeout`
	# reliably catch a short (0.08s) Tween mid-flight in this headless environment — a single frame
	# can complete the ENTIRE flash-and-restore before the assert ever runs (observed: the whole
	# round-trip finished within ~3ms of real time). `Tween.custom_step(delta)` manually advances
	# the tween by an EXACT delta with zero dependency on frame/wall-clock timing, so it's
	# deterministic regardless of how fast/slow real frames happen to elapse here.
	var coord := _make_coordinator()
	var target := Polygon2D.new()
	target.modulate = Color.WHITE
	add_child_autofree(target)
	EventBus.hit_flash_requested.emit(target, Color(1.0, 0.2, 0.2))
	var tween: Tween = coord._flash._tweens_by_target[target]
	tween.custom_step(0.01)  # partway into phase 1 (half_dur = 0.04s) — short of the flash color
	# The white target's g-channel (1.0) tweens toward the flash color's g (0.2) ⇒ drops.
	assert_true(target.modulate.g < 0.99, "hit_flash should tween the target's modulate toward the color")


func test_particles_requested_acquires_activates_and_releases() -> void:
	# AC3 / AC1 — particles_requested ⇒ a pooled ParticleBurst is acquired, added under the
	# coordinator at the requested position, emitting, and released after its lifetime.
	var coord := _make_coordinator()
	EventBus.particles_requested.emit(&"hit_spark", Vector2(100.0, 200.0), Color.CYAN, 1.0)
	await get_tree().physics_frame  # let add_child + activate settle
	var burst: ParticleBurst = null
	for c in coord.get_children():
		if c is ParticleBurst:
			burst = c
			break
	assert_not_null(burst)
	assert_almost_eq(burst.global_position.x, 100.0, 0.5)
	assert_true(burst.emitting)
	# hit_spark lifetime (0.3) + margin (0.15) = 0.45s; await past it ⇒ the Timer self-releases.
	var lifetime: float = coord.tuning.get_effect_profile(&"hit_spark")[&"lifetime"]
	await get_tree().create_timer(lifetime + 0.3).timeout
	assert_eq(burst.get_parent(), null)  # released ⇒ detached
