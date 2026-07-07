class_name FormationSpawner
extends Node
# Escalating pulsed-formation DRIP emitter — [Wave-2] (correct-course 2026-07-03). Emits a
# formation pulse every drip_interval_s; each pulse spawns per_tick(wave) enemies (wave-scaled,
# HARD-CAPPED per tick — the performance guardrail). NO on-screen concurrency cap: enemies enter
# → form → dive → re-enter and cycle until killed (the dive-loop), so pressure ESCALATES as pulses
# accumulate. Worst-case entities = (wave_duration / drip_interval) × max_per_tick, verified at the
# perf gate.
#
# Story 1.8 — WAVE TIMING HAS MOVED to world/wave_controller.gd (the run/wave lifecycle FSM).
# This spawner is now a PURE drip emitter: begin_wave(n) starts dripping for wave n, stop() halts
# it (+ despawns survivors for a clean board). It no longer owns wave_duration, no longer self-
# terminates, and no longer emits wave_started/wave_cleared — the WaveController does, and drives
# this spawner's begin_wave/stop at the right lifecycle transitions. (Closes the 1.5-deferred
# set_active-while-expired footgun by construction: the spawner can't re-fire a cleared wave
# because it no longer clears waves — the controller owns that, gated by its FSM state.)

@export var grunt_scene: PackedScene
@export var shielder_scene: PackedScene
@export var bomber_scene: PackedScene
@export var formation_id: StringName = &"standard"
@export var drip_interval_s: float = 10.0       # time between formation pulses.
@export var per_tick_base: int = 3              # per_tick(wave) = base + floor(wave × growth).
@export var per_tick_growth: float = 0.5
@export var max_per_tick: int = 8               # HARD per-tick cap — the performance guardrail.

# Injected (by arena.gd or a test) player ref for dive aim — NOT a cross-domain ../../Player.
var player: Node2D
# Injected by Arena/WaveController in _ready BEFORE begin_wave: the run-scope state the spawner
# routes score through (AR2/FR49 — score is run-cumulative on RunState, never spawner-owned).
var run_state: RunState
var _logged_missing_run_state: bool = false  # fail-safe log spam guard (AR11)

# Authored variant mix (Tier 1): grunt-dominant, recurring cycle (wraps at any count).
const _COMPOSITION: Array[StringName] = [
	&"grunt", &"grunt", &"grunt", &"shielder", &"grunt",
	&"grunt", &"shielder", &"grunt", &"grunt", &"bomber",
]

const _MIN_DRIP_INTERVAL_S: float = 0.05  # floor for the drip_interval_s knob (review fix).
const _MAX_PULSES_PER_FRAME: int = 4      # bounds catch-up spawning after a delta spike (review fix).

var _container: Node2D
var _formation_def: FormationDefinition
var _rng: RandomNumberGenerator
var _wave_n: int = 0
var _wave_time: float = 0.0       # drip-scheduling clock only (no longer compared to a duration).
var _next_pulse_time: float = 0.0
var _spawned: int = 0
var _slot_cursor: int = 0  # cycles formation slots across pulses


func _ready() -> void:
	# Own a world-space enemy container (parented to self: during arena.tscn setup the Arena is
	# "busy setting up children" and rejects get_parent().add_child — see enemy container note).
	_container = Node2D.new()
	_container.name = "Enemies"
	add_child(_container)
	_formation_def = ContentRegistry.get_formation_def(formation_id)
	if _formation_def == null:
		Log.err("spawner", "no FormationDefinition '%s' — spawning disabled" % formation_id)
	_rng = RandomNumberGenerator.new()
	# Deterministic placeholder seed (review fix — Dev Notes #6): SeedManager sub-streams land
	# in Story 4.1; until then this local RNG must still be seeded, not OS-random.
	_rng.seed = hash(formation_id)


func begin_wave(n: int) -> void:
	# Begin escalating drip for wave n. RESTARTABLE — WaveController calls this each wave, so it
	# must fully reset per-wave state (idempotent). First pulse fires immediately (t=0); subsequent
	# pulses every drip_interval_s until stop() is called (the WaveController owns wave-end timing).
	_wave_n = n
	_wave_time = 0.0
	_next_pulse_time = 0.0
	_spawned = 0
	_slot_cursor = 0
	_logged_missing_run_state = false  # a new wave is a fresh chance to wire run_state
	set_physics_process(true)
	Log.info("spawner", "wave %d: escalating drip every %.1fs (per_tick=%d, cap %d) — until stop()" %
		[n, drip_interval_s, per_tick(_wave_n), max_per_tick])


func stop() -> void:
	# Clean wave-end halt (Story 1.8): stop dripping AND collect survivors so the next wave starts
	# on a clear board. Called by WaveController's Completed/Failed states. Synchronous release is
	# safe here — this runs from the controller's FSM step (transitioned out of Active.physics_process),
	# NOT from within a body_entered/area_entered callback (the deferred-release hazard).
	set_physics_process(false)
	_despawn_survivors()


func set_active(active: bool) -> void:
	# Thin alias retained for backward compatibility (tests / legacy callers). Prefer stop() for a
	# real wave-end (which also despawns survivors). This only toggles the physics drip.
	set_physics_process(active)


func debug_spawn_pulse() -> void:
	# Debug seam (Story 1.8 / FR50 "spawn enemy" cheat). Spawns ONE formation pulse at the current
	# wave's per_tick budget. Clearly named debug_* so it reads as a debug-only affordance; the
	# Debug autoload calls this (is_debug_build()-gated). No-op if the formation def is missing.
	if _formation_def == null or _formation_def.slots.is_empty():
		return
	_spawn_pulse(per_tick(_wave_n))


func per_tick(wave: int) -> int:
	# per-tick spawn count: wave-scaled, HARD-capped. This bounds spawn RATE (perf), not the
	# on-screen count (there is no concurrency cap).
	return mini(per_tick_base + int(floor(wave * per_tick_growth)), max_per_tick)


func get_spawned_count() -> int:
	return _spawned


func get_run_score() -> int:
	# Reads through to RunState (score is run-scope now, not spawner-owned). 0 if unwired.
	return run_state.score if run_state != null else 0


func get_active_count() -> int:
	# Live enemies in the container (not yet released on death). Useful for perf/debug.
	return _container.get_child_count()


func _physics_process(delta: float) -> void:
	_wave_time += delta
	# Fire every pulse whose time has come. Interval is floored (review fix: drip_interval_s <= 0
	# would never advance _next_pulse_time — hang) and pulses-per-frame is bounded (review fix: a
	# delta spike must not catch up unbounded pulses). No duration gate — drips until stop().
	var interval: float = maxf(drip_interval_s, _MIN_DRIP_INTERVAL_S)
	var pulses_fired: int = 0
	while _wave_time >= _next_pulse_time and pulses_fired < _MAX_PULSES_PER_FRAME:
		_spawn_pulse(per_tick(_wave_n))
		_next_pulse_time += interval
		pulses_fired += 1


func _despawn_survivors() -> void:
	# Wave-end collection: survivors are not kills (no score) — just returned to the Pool so they
	# don't carry across the wave boundary. get_children() returns a snapshot Array (not a live
	# view), so releasing (which reparents out of _container) mid-loop is safe — not the
	# splice-during-iteration hazard.
	for enemy in _container.get_children():
		(enemy as Enemy).despawn()


func _spawn_pulse(count: int) -> void:
	# One formation-entry group: `count` enemies entering together, contiguous formation slots
	# (a cluster), variant from the authored composition cycle.
	if _formation_def == null or _formation_def.slots.is_empty():
		return
	for _i in count:
		var id: StringName = _COMPOSITION[_spawned % _COMPOSITION.size()]
		var slot: int = _slot_cursor % _formation_def.slots.size()
		_slot_cursor += 1
		_spawn_enemy(id, slot)


func _spawn_enemy(id: StringName, slot: int) -> void:
	var scene: PackedScene = _scene_for(id)
	if scene == null:
		return
	var enemy: Enemy = Pool.acquire(scene) as Enemy
	assert(enemy != null, "FormationSpawner: acquired node is not an Enemy")
	# acquire → add_child → activate (so @onready refs are valid in the enemy's activate).
	_container.add_child(enemy)
	enemy.player_target = player
	enemy.activate(_formation_def, slot, _rng)
	# Connect death ONCE per instance (idempotent across pool reuse — never stack duplicates).
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	_spawned += 1


func _scene_for(id: StringName) -> PackedScene:
	match id:
		&"grunt": return grunt_scene
		&"shielder": return shielder_scene
		&"bomber": return bomber_scene
	Log.err("spawner", "no scene for enemy id '%s' — grunt fallback" % id)
	return grunt_scene


func _on_enemy_died(score_value: int) -> void:
	# Score is run-cumulative on RunState; the spawner ROUTES it, never owns it (AR2/FR49).
	# D8: score_changed is the ONLY global signal enemies/waves put on the bus. Fail-safe if
	# Arena hasn't wired run_state yet (AR11) — log once, degrade, never crash.
	if run_state == null:
		if not _logged_missing_run_state:
			_logged_missing_run_state = true
			Log.err("spawner", "enemy died but run_state is null — score not recorded (Arena injects run_state before begin_wave)")
		return
	run_state.add_score(score_value)
	EventBus.score_changed.emit(run_state.score)
