extends Node
# Debug overlay + cheat hotkeys + visual toggles (FR50, Story 1.8). Gated by OS.is_debug_build() — a
# COMPLETE no-op in release exports (_ready disables all processing/input). The overlay is a
# CanvasLayer of read-only Labels (FPS / entity count / pooled-object count / current wave / seed /
# build), refreshed on a ~4 Hz throttle (NOT per frame — NFR3: no per-frame string format/alloc).
# Cheats + visual toggles are Input Map actions (debug_*), so no hardcoded keys in logic. Arena
# injects gameplay refs via bind_arena(); cheats/overlay no-op safely when unbound (AR11 fail-safe).
#
# 1.8 shipped the E1-relevant subset of FR50: overlay + the three named cheats (set move-speed, spawn
# enemy, invincibility) + hitboxes/formation-rows/monochrome visual toggles. Story 2.1 adds the
# spawn-captor cheat (F8) — the ONLY captor spawn path in 2.1. The remaining E3–E4 cheats (force wave
# / give currency / set seed) are still OUT of scope — they need systems that don't exist yet (arch:
# "for Epic-3 hypothesis testing").

# Overlay refresh throttle — ~4 Hz. Avoids per-frame string format/alloc (NFR3).
const _OVERLAY_UPDATE_INTERVAL_S: float = 0.25
# move-speed cheat cycle (multiplicative of the cached baseline). 0.5× / 1× (baseline) / 1.5× / 2×.
const _MOVE_SPEED_STEPS: Array[float] = [0.5, 1.0, 1.5, 2.0]
# v0.1 monochrome approximation modulate (D16): a uniform gray on the arena world tree. True hue-
# stripping needs a shader (none in-repo — deferred to 8.5); this is the sanctioned v0.1 visual.
const _MONOCHROME_MODULATE: Color = Color(0.6, 0.6, 0.6)

# Injected by Arena._ready under is_debug_build() (mirrors the 1.7 HUD injection). Null until bound.
var player: Player
var spawner: FormationSpawner
var wave_controller: WaveController

var _overlay: CanvasLayer
var _fps_label: Label
var _entities_label: Label
var _pooled_label: Label
var _wave_label: Label
var _seed_label: Label
var _build_label: Label
var _overlay_timer: float = 0.0
var _cached_wave: int = 0

var _move_speed_step: int = -1   # index into _MOVE_SPEED_STEPS; -1 = "not yet cycled" (baseline)
var _move_speed_baseline: float = -1.0   # cached player_tuning.move_speed at first cheat use
var _debug_invuln: bool = false
var _monochrome_on: bool = false
var _hitboxes_visible: bool = false


func _ready() -> void:
	if not OS.is_debug_build():
		# Release exports: strip ALL debug processing/input. The overlay is never built.
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
		return
	_build_overlay()


func _build_overlay() -> void:
	# A high-layer CanvasLayer of read-only Labels (top-left). Hidden by default (AC3 "When toggled").
	_overlay = CanvasLayer.new()
	_overlay.name = "DebugOverlay"
	_overlay.layer = 100   # above the HUD + future menus
	add_child(_overlay)
	var vbox := VBoxContainer.new()
	vbox.name = "Rows"
	vbox.position = Vector2(8, 8)
	vbox.add_theme_constant_override("separation", 2)
	_overlay.add_child(vbox)
	_fps_label = _make_row(vbox, "FPS")
	_entities_label = _make_row(vbox, "ENT")
	_pooled_label = _make_row(vbox, "POOL")
	_wave_label = _make_row(vbox, "WAVE")
	_seed_label = _make_row(vbox, "SEED")
	_build_label = _make_row(vbox, "BUILD")
	_overlay.visible = false
	# Wave row tracks wave_started (carries the wave number; the controller emits it).
	EventBus.wave_started.connect(_on_wave_started)


func _make_row(parent: Control, label: String) -> Label:
	var row := Label.new()
	row.text = "%s: --" % label
	row.add_theme_font_size_override("font_size", 12)
	parent.add_child(row)
	return row


func bind_arena(p_player: Player, p_spawner: FormationSpawner, p_wave_controller: WaveController) -> void:
	# Injected by Arena._ready under is_debug_build(). Cheats/overlay no-op safely if unbound.
	player = p_player
	spawner = p_spawner
	wave_controller = p_wave_controller


func _on_wave_started(wave: int, _duration: float) -> void:
	_cached_wave = wave


func _unhandled_input(event: InputEvent) -> void:
	# All debug actions are Input Map actions (no hardcoded keys in logic). _unhandled_input so it
	# doesn't fight gameplay input. (Gated: _ready disabled input in release builds.)
	if event.is_action_pressed("debug_toggle_overlay"):
		_overlay.visible = not _overlay.visible
	elif event.is_action_pressed("debug_cheat_move_speed"):
		_cheat_move_speed()
	elif event.is_action_pressed("debug_cheat_spawn"):
		_cheat_spawn()
	elif event.is_action_pressed("debug_cheat_spawn_captor"):
		_cheat_spawn_captor()
	elif event.is_action_pressed("debug_cheat_invuln"):
		_cheat_invuln()
	elif event.is_action_pressed("debug_toggle_hitboxes"):
		_toggle_hitboxes()
	elif event.is_action_pressed("debug_toggle_formation_rows"):
		# E1 has no dedicated formation-row guide nodes (formation rows are conceptual enemy targets,
		# not drawn nodes). Drawing them is future polish; log + no-op for now.
		Log.info("debug", "formation rows: no guide nodes in E1 (conceptual targets only)")
	elif event.is_action_pressed("debug_toggle_monochrome"):
		_toggle_monochrome()


func _process(delta: float) -> void:
	# Invuln cheat top-up (only while toggled on + a player is bound).
	if _debug_invuln and player != null:
		var h: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
		if h != null:
			h.set_invuln(0.5)   # topped each frame so it never expires while the cheat is on
	# Throttled overlay refresh (NFR3 — no per-frame string format; only when visible).
	if _overlay.visible:
		_overlay_timer += delta
		if _overlay_timer >= _OVERLAY_UPDATE_INTERVAL_S:
			_overlay_timer = 0.0
			_refresh_overlay()


func _refresh_overlay() -> void:
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	var ent_count: int = spawner.get_active_count() if spawner != null else 0
	_entities_label.text = "ENT: %d" % ent_count
	# POOL: idle/active (idle = released back to pool; active = in play).
	_pooled_label.text = "POOL: %d idle / %d active" % [Pool.get_pooled_count(), Pool.get_active_count()]
	_wave_label.text = "WAVE: %d" % _cached_wave
	# E1 has no SeedManager run stream (the spawner uses a local seeded RNG); real seeds land in E4.
	_seed_label.text = "SEED: authored"
	_build_label.text = "BUILD: n/a (E3)"   # no build engine until Epic 3


func _cheat_move_speed() -> void:
	# Cycles the player's move_speed through _MOVE_SPEED_STEPS (session-only: mutates the loaded
	# PlayerTuning instance in memory; ResourceSaver is never called, so the .tres is untouched).
	if player == null or player.tuning == null:
		return
	if _move_speed_baseline < 0.0:
		_move_speed_baseline = player.tuning.move_speed   # cache the .tres baseline on first use
	_move_speed_step = (_move_speed_step + 1) % _MOVE_SPEED_STEPS.size()
	var mul: float = _MOVE_SPEED_STEPS[_move_speed_step]
	player.tuning.move_speed = _move_speed_baseline * mul
	Log.info("debug", "cheat: move_speed ×%.1f (%.0f px/s)" % [mul, player.tuning.move_speed])


func _cheat_spawn() -> void:
	# Spawn one formation pulse at the current wave's per_tick budget (FR50 "spawn enemy"). Guarded
	# to the Active wave (not Completed/Failed/Intro) — otherwise it could inject enemies onto the
	# "clean board" WaveCompletedState assumes right before healing/advancing, or after a run-loss.
	if spawner == null:
		return
	if wave_controller != null and wave_controller.get_state_name() != "WaveActiveState":
		Log.info("debug", "cheat: spawn ignored — wave is not Active (%s)" % wave_controller.get_state_name())
		return
	spawner.debug_spawn_pulse()
	Log.info("debug", "cheat: spawned one formation pulse")


func _cheat_spawn_captor() -> void:
	# Story 2.1 / FR50 "spawn captor" cheat — the ONLY captor spawn path in 2.1 (captor-presence in
	# the wave drip is Story 2.8). Spawns a captor off-screen above the player; EnterState descends it
	# onto the player's column. Guarded to the Active wave (mirrors _cheat_spawn) so it can't inject a
	# captor onto the clean board WaveCompletedState assumes at wave-end, or after a run-loss.
	if spawner == null or player == null:
		return
	if wave_controller != null and wave_controller.get_state_name() != "WaveActiveState":
		Log.info("debug", "cheat: spawn captor ignored — wave is not Active (%s)" % wave_controller.get_state_name())
		return
	# One screen-height above the player → off-screen-top spawn (EnterState descends from here).
	var pos := Vector2(player.global_position.x, player.global_position.y - Constants.BASE_RESOLUTION.y)
	spawner.spawn_captor_at(pos)
	Log.info("debug", "cheat: spawned captor above the player")


func _cheat_invuln() -> void:
	# Toggle permanent invincibility. ON: _process tops up the player's i-frames each frame. OFF:
	# let the current window expire naturally (the player becomes vulnerable again).
	_debug_invuln = not _debug_invuln
	Log.info("debug", "cheat: invincibility %s" % ("ON" if _debug_invuln else "OFF"))


func _toggle_hitboxes() -> void:
	# Visualize collision shapes by flipping every CollisionShape2D's `visible` under the arena.
	# (Godot 4 has no portable runtime SceneTree flag across headless/editor builds, so iterate the
	# shapes directly. The editor's "Visible Collision Shapes" remains the authoritative debug view.)
	# Guard BEFORE flipping the flag (not after): if unbound (AR11 fail-safe no-op), nothing visual
	# happens, so the flag must not flip either — otherwise it desyncs from the (absent) effect and
	# the next real press (once bound) does the opposite of what the flag's name implies.
	if wave_controller == null:
		return
	var arena: Node = wave_controller.get_parent()
	if arena == null:
		return
	_hitboxes_visible = not _hitboxes_visible
	for shape: CollisionShape2D in arena.find_children("*", "CollisionShape2D", true, false):
		shape.visible = _hitboxes_visible
	Log.info("debug", "hitboxes: %s" % ("on" if _hitboxes_visible else "off"))


func _toggle_monochrome() -> void:
	# D16 (A2/CVD contract check): repaint the play-field to a single luminance to verify the
	# player/hazard read survives without hue. v0.1 approximation (no shader in-repo) — modulate the
	# arena world tree to gray. The HUD CanvasLayer is NOT affected (CanvasLayers ignore ancestor
	# CanvasItem modulate), so the overlay reads correctly against a grayed play-field. True per-pixel
	# desaturation matures at E8 (8.5 shader pass). Required visual check before feel sign-off.
	# Guard BEFORE flipping the flag — same desync reasoning as _toggle_hitboxes() above.
	if wave_controller == null:
		return
	var arena: CanvasItem = wave_controller.get_parent() as CanvasItem
	if arena == null:
		return
	_monochrome_on = not _monochrome_on
	arena.modulate = _MONOCHROME_MODULATE if _monochrome_on else Color.WHITE
	Log.info("debug", "monochrome: %s (v0.1 gray-modulate approximation; E8 adds a desaturate shader)" %
		("on" if _monochrome_on else "off"))


func reset_debug_state() -> void:
	# Called by Arena BEFORE a run reload (auto-replay on game-over) so cheats/toggles don't leak
	# into the next run. Restores the move-speed baseline first: _cheat_move_speed mutates the
	# loaded PlayerTuning Resource in memory (it's an ExtResource, not resource_local_to_scene, so
	# Godot's ResourceCache hands the SAME instance to every future Player) — without this restore
	# the multiplier would persist into runs where the cheat was never touched.
	if player != null and player.tuning != null and _move_speed_baseline >= 0.0:
		player.tuning.move_speed = _move_speed_baseline
	player = null
	spawner = null
	wave_controller = null
	_debug_invuln = false
	_monochrome_on = false
	_hitboxes_visible = false
	_move_speed_step = -1
	_move_speed_baseline = -1.0
	_cached_wave = 0
	if _overlay != null:
		_overlay.visible = false


# --- test seam (used by tests to reset autoload state between cases) ---
func _reset_for_tests() -> void:
	# GUT: the Debug autoload persists across tests; reset mutable state so cases are independent.
	reset_debug_state()
