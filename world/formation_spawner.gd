class_name FormationSpawner
extends Node
# Escalating pulsed-formation spawner — [Wave-2] (correct-course 2026-07-03). Emits a
# formation pulse every drip_interval_s for the whole wave duration; each pulse spawns
# per_tick(wave) enemies (wave-scaled, HARD-CAPPED per tick — the performance guardrail).
# NO on-screen concurrency cap: enemies enter → form → dive → re-enter and cycle until killed
# (the dive-loop), so pressure ESCALATES as pulses accumulate (timer-terminated waves require
# replenishment — a fixed batch clears-fast-then-waits). Worst-case entities =
# (wave_duration / drip_interval) × max_per_tick, verified at the perf gate.
# The full wave_intro→active→completed→reward→next_wave FSM + the real timer-end is Story 1.8;
# this spawner covers 1.4's scope (drip for wave_duration, then stop — survivors keep cycling).

@export var grunt_scene: PackedScene
@export var shielder_scene: PackedScene
@export var bomber_scene: PackedScene
@export var formation_id: StringName = &"standard"
@export var wave_duration_s: float = 30.0      # how long the spawner drips (the [Wave-1] timer).
@export var drip_interval_s: float = 10.0       # time between formation pulses.
@export var per_tick_base: int = 3              # per_tick(wave) = base + floor(wave × growth).
@export var per_tick_growth: float = 0.5
@export var max_per_tick: int = 8               # HARD per-tick cap — the performance guardrail.

# Injected (by arena.gd or a test) player ref for dive aim — NOT a cross-domain ../../Player.
var player: Node2D

# Authored variant mix (Tier 1): grunt-dominant, recurring cycle (wraps at any count).
const _COMPOSITION: Array[StringName] = [
	&"grunt", &"grunt", &"grunt", &"shielder", &"grunt",
	&"grunt", &"shielder", &"grunt", &"grunt", &"bomber",
]

var _container: Node2D
var _formation_def: FormationDefinition
var _rng: RandomNumberGenerator
var _run_score: int = 0
var _wave_n: int = 0
var _wave_time: float = 0.0
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
	_rng = RandomNumberGenerator.new()


func begin_wave(n: int) -> void:
	# Begin escalating drip for wave n. First pulse fires immediately (t=0); subsequent pulses
	# every drip_interval_s until wave_duration_s elapses.
	_wave_n = n
	_wave_time = 0.0
	_next_pulse_time = 0.0
	_spawned = 0
	_slot_cursor = 0
	set_physics_process(true)
	Log.info("spawner", "wave %d: escalating drip every %.1fs for %.1fs (per_tick=%d, cap %d)" %
		[n, drip_interval_s, wave_duration_s, per_tick(_wave_n), max_per_tick])


func per_tick(wave: int) -> int:
	# per-tick spawn count: wave-scaled, HARD-capped. This bounds spawn RATE (perf), not the
	# on-screen count (there is no concurrency cap).
	return mini(per_tick_base + int(floor(wave * per_tick_growth)), max_per_tick)


func get_spawned_count() -> int:
	return _spawned


func get_run_score() -> int:
	return _run_score


func get_active_count() -> int:
	# Live enemies in the container (not yet released on death). Useful for perf/debug.
	return _container.get_child_count()


func _physics_process(delta: float) -> void:
	_wave_time += delta
	# Fire every pulse whose time has come, while still inside the wave duration.
	while _wave_time >= _next_pulse_time and _next_pulse_time <= wave_duration_s:
		_spawn_pulse(per_tick(_wave_n))
		_next_pulse_time += drip_interval_s
	# Wave duration elapsed → stop spawning. Existing enemies keep cycling (dive-loop) until
	# killed; the full wave-end FSM (collect survivors, reward, next wave) is Story 1.8.
	if _wave_time > wave_duration_s:
		set_physics_process(false)


func _spawn_pulse(count: int) -> void:
	# One formation-entry group: `count` enemies entering together, contiguous formation slots
	# (a cluster), variant from the authored composition cycle.
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
	# Score is run-cumulative; publish via EventBus (D8 — score_changed is global game-flow,
	# the ONLY signal enemies/waves put on the bus).
	_run_score += score_value
	EventBus.score_changed.emit(_run_score)
