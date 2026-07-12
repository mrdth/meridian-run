class_name FireSystem
extends Node
# Player fire component (1.3). Hold-to-autofire via a cooldown accumulator in
# _physics_process (Decision #2 — pure logic, no Timer node, fixed-timestep-
# deterministic). Acquires pooled Projectiles from Pool and activates them at the
# Muzzle; projectiles parent to the injected projectile_parent (world space, NOT
# the Player) so they don't inherit the ship's transform (Decision #8). Fire emits
# NO game-flow signal (fire is not game-flow), but DOES emit juice REQUEST signals
# (on-fire SFX + a light muzzle puff) via JuiceFx (Story 1.6) — juice requests are
# an allowed global channel (D8), distinct from game-flow events. Zero per-frame
# allocations (NFR3).

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
# Story 2.3 — the Player (FireSystem's parent). Read once via @onready. review fix: untyped Node +
# duck-call (has_method/call/get), not a hard `as Player` cast — mirrors the duck-call pattern used
# by hurtbox_component.gd/enemy_projectile.gd elsewhere in this diff (avoids hard Player coupling;
# the FireSystem's own 2.4 seam anticipates a non-Player parent — a DockedShip-owned FireSystem).
@onready var _player: Node = get_parent()

# FR7 / GDD weapon table — the parallel bullet stream's +28 px x-offset when docked (AC#3 +firepower).
# review fix: read from DockedShipTuning.stream_offset_x (the .tres wins, D9) instead of a separate
# hardcoded const — a single source of truth so retuning the .tres can't desync the bullet from the
# wingman's visual station. This fallback only applies if docked_ship_tuning is somehow unassigned.
const _FALLBACK_STREAM_OFFSET_X := 28.0

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
	# Primary stream.
	_spawn_one(_muzzle.global_position, tuning.projectile_damage)
	# Story 2.3 — the parallel bullet stream when docked (AC#3 +firepower, FR7). A 2nd bullet at the
	# docked tuning's offset, sharing the cooldown (synced cadence — FR7 "matches the player's fire
	# cadence"). Open Question H default: the player's FireSystem spawns both (simpler + auto-synced);
	# 2.4 may refactor to a DockedShip-owned FireSystem for the build track.
	if _player != null and _player.has_method("is_docked") and _player.call("is_docked"):
		var dt: DockedShipTuning = _player.get("docked_ship_tuning") as DockedShipTuning
		var offset_x: float = dt.stream_offset_x if dt != null else _FALLBACK_STREAM_OFFSET_X
		var damage: int = dt.stream_damage if dt != null else tuning.projectile_damage
		_spawn_one(_muzzle.global_position + Vector2(offset_x, 0.0), damage)
	# On-fire juice (Story 1.6 / AC4): fire SFX (mandated, ±5% pitch inside play_fire) + a light
	# optional muzzle puff. ONE juice per fire press, not per bullet (the two bullets fire together).
	# Juice request signals only — no game-flow. (Story 1.3's "emits nothing to EventBus" note referred
	# to GAME-FLOW signals; juice requests are a separate, allowed channel.)
	JuiceFx.player_fired(_muzzle.global_position)


func _spawn_one(at: Vector2, damage: int) -> void:
	# Hoist the bullet-spawn body (Pool.acquire → activate at `at` → add_child) so the primary + the
	# docked parallel stream share it. Zero per-frame allocations (NFR3). Parent to the injected
	# world-space container, NOT the Player (transform-independence, Decision #8). `damage` lets the
	# docked stream use DockedShipTuning.stream_damage (review fix — the knob was previously unused).
	var p: Projectile = Pool.acquire(projectile_scene) as Projectile
	assert(p != null, "FireSystem: acquired node is not a Projectile — wrong scene?")
	p.activate(at, tuning.bullet_speed, damage)
	projectile_parent.add_child(p)
