extends Node2D
# Story 2.6 (Task 9.2) — headless smoke for the sacrifice burst. Run as a SCENE (autoloads register on
# the normal game-flow path, unlike a bare `-s` SceneTree script which compiles arena.gd before the
# autoloads' global names exist):
#   godot --headless tests/smoke_sacrifice_burst.tscn
#
# Confirms end-to-end in a fresh headless process that:
#   1. The "sacrifice" InputMap action is registered (the input-dispatch prerequisite).
#   2. dock → sacrifice applies the burst (the handler `_try_sacrifice`, which the 1-line input read
#      dispatches to).
#   3. The burst fire path produces a TRIPLE-SHOT (3 projectiles per fire tick).
#   4. Over 0.5 s of held fire, the count far exceeds the chassis 6.25 Hz (≈3) — confirming FAST-FIRE
#      (0.10 s) × triple-shot (≈15).
#   5. The burst expires after its duration.
#
# Also ATTEMPTS the real input dispatch line (Input.is_action_just_pressed("sacrifice")). That read is
# frame-counter-flaky outside a real loop (memory input-just-pressed-untestable-in-gut); if it doesn't
# fire, the handler is driven directly + that's logged. The full FEEL (ignition juice + glow + timer
# ring) + the real input line are the manual playtest (Task 9.3). quits the tree on completion.

const _ARENA := preload("res://world/arena.tscn")


func _ready() -> void:
	var ok: bool = true

	# 1. The sacrifice input action is registered (project.godot InputMap).
	var has_action: bool = InputMap.has_action("sacrifice")
	print("[SMOKE] InputMap.has_action('sacrifice') = %s" % has_action)
	ok = ok and has_action

	# Fresh arena; halt the spawner drip so it doesn't spawn enemies mid-smoke.
	var arena: Arena = _ARENA.instantiate() as Arena
	add_child(arena)  # _ready fires synchronously (this node is already in the tree).
	arena._spawner.set_active(false)

	var player: Player = arena._player
	var fs: FireSystem = player._fire_system
	# Override projectile_parent with a temp container for clean projectile counts (mirrors the GUT fixture).
	var pp := Node2D.new()
	add_child(pp)
	fs.projectile_parent = pp
	fs.set_physics_process(false)
	player.set_physics_process(false)

	# 2. Dock the player (enables sacrifice — _try_sacrifice guards on _docked_ship != null).
	player.try_dock_ship()
	print("[SMOKE] docked: %s" % player.is_docked())

	# 3. ATTEMPT the real input dispatch (the 1-line _physics_process read). Fresh process → may read.
	Input.action_press("sacrifice")
	player._physics_process(1.0 / 60.0)
	Input.action_release("sacrifice")
	var input_fired: bool = fs._burst != null
	print("[SMOKE] real input dispatch fired the burst: %s" % input_fired)
	if not input_fired:
		# Frame-counter timing (memory input-just-pressed-untestable-in-gut) — drive the handler directly
		# (the exact method the input-read line calls), so the burst is still verified this smoke.
		print("[SMOKE]   (input didn't read this frame — driving _try_sacrifice() directly, the handler)")
		player._try_sacrifice()

	# 4. The burst is applied.
	var burst_applied: bool = fs._burst != null
	print("[SMOKE] burst applied: %s" % burst_applied)
	if fs._burst != null:
		print("[SMOKE]   power=%.3f duration=%.1fs time_left=%.2fs" % [fs._burst.power, fs._burst.duration, fs._burst_time_left])
	ok = ok and burst_applied

	# 5. Triple-shot: ONE burst-fire tick spawns exactly 3 projectiles (AC1 / AC3 — a stat buff, not an AoE).
	Input.action_press("fire")
	fs._physics_process(1.0 / 60.0)
	Input.action_release("fire")
	var one_tick_count: int = pp.get_child_count()
	print("[SMOKE] one burst-fire tick → %d projectiles (expect 3 = triple-shot)" % one_tick_count)
	ok = ok and one_tick_count == 3

	# 6. Fast-fire: clear the container, then 0.5 s of held fire. Burst 0.10 s cadence × 3 ≈ 15; the chassis
	#    6.25 Hz single-stream would be ≈ 3 — so >= 12 confirms BOTH the triple-shot AND the fast cadence.
	for c in pp.get_children():
		pp.remove_child(c)  # synchronous removal (queue_free is deferred + would pollute the count)
		c.queue_free()
	Input.action_press("fire")
	for _i in 30:  # 0.5 s at 60 Hz
		fs._physics_process(1.0 / 60.0)
	Input.action_release("fire")
	var sustained_count: int = pp.get_child_count()
	print("[SMOKE] 0.5 s held fire during burst → %d projectiles (chassis 6.25 Hz ≈ 3; burst ≈ 15 = triple × fast-fire)" % sustained_count)
	ok = ok and sustained_count >= 12

	# 7. Expiry: step past the duration → the timer crosses 0 → the buff clears.
	var steps: int = 0
	while fs._burst != null and steps < 2000:
		fs._physics_process(1.0 / 60.0)
		steps += 1
	print("[SMOKE] burst expired after %d steps (cleared: %s)" % [steps, fs._burst == null])
	ok = ok and fs._burst == null

	print("[SMOKE] %s" % ("PASS — sacrifice burst verified headlessly" if ok else "FAIL — see lines above"))
	get_tree().quit(0 if ok else 1)
