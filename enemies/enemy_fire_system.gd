class_name EnemyFireSystem
extends Node
# Enemy fire component (1.4). Mirrors player/fire_system.gd: a cooldown accumulator in
# _physics_process (no Timer node, fixed-timestep-deterministic), acquires pooled
# EnemyProjectiles and activates them at the Muzzle. Difference: there is no Input — the
# AI states arm/disarm firing via arm(). Projectiles parent to the injected
# projectile_parent (world space, NOT the enemy) so they don't inherit the enemy's
# transform (Decision #8). Fire is intra-entity (D8) — emits nothing to EventBus.
# Zero per-frame allocations (NFR3); _cooldown clamped at 0 (1.3-review fix).

@export var projectile_scene: PackedScene            # standard enemy projectile (all variants).
@export var heavy_projectile_scene: PackedScene       # optional Bomber heavy pellet; null → reuse standard with heavy=true.

# Public var wired by enemy.gd._ready() to the spawner's world-space enemy container
# (projectiles live in world space, not under the enemy). Public (not @export) so the
# enemy sets it directly and tests can inject a temp container.
var projectile_parent: Node2D

# Muzzle is a sibling under the Enemy (this node's parent); read once via @onready
# (never $/get_node per frame). Yields null in partial/test setup — _spawn guards.
@onready var _muzzle: Marker2D = get_parent().get_node_or_null("Muzzle")

var _definition: EnemyDefinition
var _rng: RandomNumberGenerator
var _armed: bool = false
var _sweep_armed: bool = false  # SweepState: fire at the tight sweep_fire_interval_s cadence (dense raking stream).
var _cooldown: float = 0.0
var _windup_remaining: float = -1.0  # >= 0 while telegraphing a heavy shot (review fix).


func arm(definition: EnemyDefinition, rng: RandomNumberGenerator, active: bool, sweep: bool = false) -> void:
	# Enable/disable firing per AI state (fire only in Formation/Dive/Sweep, not Enter). Sets the
	# per-spawn definition + rng. First shot is delayed by an interval so an enemy doesn't fire the
	# instant it reaches formation. `sweep` (SweepState) fires at the tight sweep_fire_interval_s
	# cadence so a strafing run rakes dense fire across the lane (decision-log [Sweep-state]).
	_definition = definition
	_rng = rng
	_armed = active
	_sweep_armed = active and sweep
	_windup_remaining = -1.0
	if _armed and _definition != null and _rng != null:
		_cooldown = _next_interval()


func _next_interval() -> float:
	# Sweep mode = tight fixed cadence (dense raking stream); otherwise the per-definition random band.
	if _sweep_armed:
		return _definition.sweep_fire_interval_s
	return _rng.randf_range(_definition.fire_interval_min_s, _definition.fire_interval_max_s)


func _physics_process(delta: float) -> void:
	if _definition == null or _rng == null:
		return
	# Sweep mode = standard raking fire: no heavy telegraph (decision-log [Sweep-state]).
	var heavy_eligible: bool = not _sweep_armed and _definition.shot_kind == EnemyDefinition.ShotKind.HEAVY and _definition.heavy_windup_s > 0.0
	# Mid-windup: hold fire until the telegraph elapses, then actually spawn (review fix —
	# heavy_windup_s was previously stored but never delayed the shot).
	if _windup_remaining >= 0.0:
		_windup_remaining -= delta
		if _windup_remaining <= 0.0:
			_windup_remaining = -1.0
			_spawn()
			_cooldown = _next_interval()
		return
	# Cooldown accumulator; clamp at 0 to avoid unbounded-negative drift (1.3 review).
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _armed and _cooldown <= 0.0:
		if heavy_eligible:
			_windup_remaining = _definition.heavy_windup_s
		else:
			_spawn()
			_cooldown = _next_interval()


func _spawn() -> void:
	if _muzzle == null or projectile_parent == null:
		return
	# HEAVY shot_kind (Bomber) → use the dedicated heavy scene if provided, else the standard
	# scene with heavy=true (the projectile recolors/scales for the telegraphed silhouette).
	# Sweep mode forces STANDARD fire — a strafing run rakes standard shots, not telegraphed heavies.
	var heavy: bool = not _sweep_armed and _definition.shot_kind == EnemyDefinition.ShotKind.HEAVY
	var scene: PackedScene = projectile_scene
	if heavy and heavy_projectile_scene != null:
		scene = heavy_projectile_scene
	if scene == null:
		Log.err("enemies", "EnemyFireSystem: projectile_scene unassigned — shot skipped")
		return
	# Pool.acquire() — NEVER instantiate() on the hot path (AR6).
	var p: EnemyProjectile = Pool.acquire(scene) as EnemyProjectile
	assert(p != null, "EnemyFireSystem: acquired node is not an EnemyProjectile — wrong scene?")
	p.activate(_muzzle.global_position, _definition.projectile_speed, _definition.fire_damage, heavy)
	# Parent to the world-space container, NOT the enemy (transform-independence).
	projectile_parent.add_child(p)
