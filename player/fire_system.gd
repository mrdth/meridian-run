class_name FireSystem
extends Node
# Player fire component (1.3). Hold-to-autofire via a cooldown accumulator in
# _physics_process (Decision #2 — pure logic, no Timer node, fixed-timestep-
# deterministic). Acquires pooled Projectiles from Pool and activates them at the
# Muzzle; projectiles parent to the injected projectile_parent (world space, NOT
# the Player) so they don't inherit the ship's transform (Decision #8). Fire is
# intra-entity (D8) — emits nothing to EventBus. Zero per-frame allocations (NFR3).

@export var tuning: PlayerTuning
@export var projectile_scene: PackedScene

# Public var wired by player.gd._ready() to the Player's parent (the Arena). Public
# (not @export) so player.gd sets it directly and tests can inject a temp container.
# Projectiles parent here so they live in world space, not under the Player.
var projectile_parent: Node2D

# Muzzle is a sibling under the Player (FireSystem's parent); read once via @onready
# (never $/get_node per frame). Yields null if the Muzzle is absent (partial/test
# setup) — _spawn guards against that instead of erroring on lookup.
@onready var _muzzle: Marker2D = get_parent().get_node_or_null("Muzzle")

var _cooldown: float = 0.0


func _ready() -> void:
	assert(tuning != null, "FireSystem: tuning not assigned")
	assert(projectile_scene != null, "FireSystem: projectile_scene not assigned")


func _physics_process(delta: float) -> void:
	# Cooldown accumulator (Decision #2): decrement every frame so the gun is ready
	# when needed; fire when Fire is held and the cooldown has elapsed. First press
	# fires immediately (_cooldown starts at 0); sustained hold fires at ~6.25 Hz.
	# Zero per-frame allocations — no arrays/dicts/Vector2 in this loop.
	_cooldown -= delta
	if Input.is_action_pressed("fire") and _cooldown <= 0.0:
		_spawn()
		_cooldown = tuning.fire_cooldown


func _spawn() -> void:
	# _muzzle resolved in @onready; projectile_parent wired by player.gd after this
	# node's _ready (no race — both are read here, on fire, never in _ready). Skip
	# cleanly if driven before wiring completes (partial test setup); a silent skip
	# surfaces as a failed count assertion rather than aborting the whole suite.
	if _muzzle == null or projectile_parent == null:
		return
	# Pool.acquire() — NEVER projectile_scene.instantiate() on the hot path (AR6).
	var p: Projectile = Pool.acquire(projectile_scene) as Projectile
	assert(p != null, "FireSystem: acquired node is not a Projectile — wrong scene?")
	p.activate(_muzzle.global_position, tuning.bullet_speed, tuning.projectile_damage)
	# Parent to the injected world-space container, NOT the Player (transform-independence).
	projectile_parent.add_child(p)
