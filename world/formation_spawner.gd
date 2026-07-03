class_name FormationSpawner
extends Node
# Minimal formation spawner for E1 (1.4). Emits the 4+N-capped (max 12) formation pulses
# across wave_duration_s — a SPAWN BUDGET, not a kill quota (FR30; the wave ends on a timer
# in Story 1.8). Enemies enter → form → dive → release off-screen (self-clearing). The full
# wave_intro→active→completed→reward→next_wave FSM is 1.8; this is its minimal precursor.
#
# Wave composition is authored DATA (a composition pattern + pulse structure), not hardcoded
# spawn() calls — Story 4.x's RunGenerator will emit the same shape. Variant order is
# Grunt-first, Shielder next, Bomber rare (matches Bomber's 300-score/2-dmg weight).

@export var grunt_scene: PackedScene
@export var shielder_scene: PackedScene
@export var bomber_scene: PackedScene
@export var formation_id: StringName = &"standard"
@export var wave_duration_s: float = 8.0
@export var pulses_per_wave: int = 3
@export var max_enemies: int = 12

# Injected (by arena.gd or a test) player ref for dive aim — NOT a cross-domain ../../Player.
# DiveState reads player_target.global_position.x once at dive-start.
var player: Node2D

# Authored E1 composition: variant in spawn order. The budget (min(4+N, 12)) indexes in.
const _COMPOSITION: Array[StringName] = [
	&"grunt", &"grunt", &"grunt", &"grunt",
	&"shielder", &"shielder",
	&"grunt", &"shielder", &"grunt", &"shielder",
	&"bomber", &"bomber",
]

var _container: Node2D
var _formation_def: FormationDefinition
var _rng: RandomNumberGenerator
var _run_score: int = 0
var _budget: int = 0
var _schedule: Array[Dictionary] = []  # [{time_s, id, slot}], spawned in time order.
var _next_event: int = 0
var _wave_time: float = 0.0
var _spawned: int = 0


func _ready() -> void:
	# Own a world-space enemy container. Parent it to SELF (not get_parent()): during a
	# scene's initial setup the Arena is "busy setting up children" and rejects add_child,
	# so get_parent().add_child() fails when arena.tscn loads (the game path — GUT adds the
	# spawner to an already-set-up arena, which hid this). A Node2D under this Node inherits
	# the Arena's transform (the spawner is under Arena), so enemies still live in world space.
	_container = Node2D.new()
	_container.name = "Enemies"
	add_child(_container)
	_formation_def = ContentRegistry.get_formation_def(formation_id)
	_rng = RandomNumberGenerator.new()


func begin_wave(n: int) -> void:
	# Compute the spawn budget (FR30: 4+N capped at 12) and build the pulse schedule.
	_budget = mini(4 + n, max_enemies)
	_build_schedule()
	_next_event = 0
	_wave_time = 0.0
	_spawned = 0
	set_physics_process(true)
	Log.info("spawner", "wave %d: budget %d enemies across %.1fs" % [n, _budget, wave_duration_s])


func get_spawned_count() -> int:
	return _spawned


func get_run_score() -> int:
	return _run_score


func _build_schedule() -> void:
	# Distribute _budget enemies into pulses_per_wave pulses evenly spaced over wave_duration.
	# Variant from the authored composition; slot cycles through the formation grid. Built
	# once per wave (no per-frame allocations here).
	_schedule.clear()
	assert(_formation_def != null, "FormationSpawner: no formation_def for '%s'" % formation_id)
	var per_pulse: int = maxi(int(ceil(float(_budget) / float(pulses_per_wave))), 1)
	var pulse_spacing: float = wave_duration_s / float(maxi(pulses_per_wave, 1))
	for i in _budget:
		var pulse_index: int = i / per_pulse
		var id: StringName = _COMPOSITION[mini(i, _COMPOSITION.size() - 1)]
		var slot: int = i % _formation_def.slots.size()
		_schedule.append({"time_s": pulse_index * pulse_spacing, "id": id, "slot": slot})


func _physics_process(delta: float) -> void:
	_wave_time += delta
	# Spawn events whose pulse time has elapsed (cheap Dict reads; the loop only runs while
	# events are due — it stops once all are spawned).
	while _next_event < _schedule.size() and _schedule[_next_event]["time_s"] <= _wave_time:
		_spawn_enemy(_schedule[_next_event]["id"], _schedule[_next_event]["slot"])
		_next_event += 1
	# All events spawned → stop ticking (enemies self-release on dive-off-screen).
	if _next_event >= _schedule.size():
		set_physics_process(false)


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
