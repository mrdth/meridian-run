class_name Projectile
extends Area2D
# Pooled player projectile (1.3). Travels straight up, detects enemy bodies, and
# releases back to Pool on leave-screen OR first hit (consume-on-hit). Re-init is
# activate()-only: _ready() runs once on first tree entry and never re-fires for a
# re-acquired pooled node, so the body_entered connection is made here, exactly once.
# AR6/AR14: never queue_free() on the hot path; never _ready()-based re-init.

var _speed: float = 0.0
var _damage: int = 0
var _consumed: bool = false


func _ready() -> void:
	# Layers/masks read from Constants — never magic numbers (NFR6 strict 2D layers).
	# Set once; these are properties and persist across pool re-acquire (Pool does not
	# touch them — it only toggles processing/visibility).
	collision_layer = Constants.LAYER_PLAYER_PROJECTILE
	collision_mask = Constants.LAYER_ENEMY
	# Connect the hit signal ONCE. Connections persist across re-acquire/release
	# (_ready does not re-fire for a re-added pooled node), so reconnecting in
	# activate() would stack duplicate connections and multi-fire the hit.
	body_entered.connect(_on_body_entered)


func activate(spawn_pos: Vector2, speed: float, damage: int) -> void:
	# Re-init entry point — the core pooled-re-init contract (AR6). Called by
	# FireSystem._spawn() right after Pool.acquire(); flips the (deactivated,
	# released) node back on and sets per-spawn state. _speed/_damage are cached
	# here and never read from an autoload per frame (NFR3 hot path).
	_speed = speed
	_damage = damage
	_consumed = false
	global_position = spawn_pos
	visible = true
	set_physics_process(true)
	monitoring = true


func _physics_process(delta: float) -> void:
	# Straight up; zero allocation (single float-component update — no Vector2,
	# no velocity). Manual delta integration is correct for an Area2D (no
	# move_and_slide); the "never multiply by delta" rule is move_and_slide()-specific.
	global_position.y -= _speed * delta
	# Leave-screen (top of the 720-tall field) → release back to the pool. The
	# bullet spawns at ~660 and travels up; clearing at centre y == 0 is fine.
	# Never queue_free().
	if global_position.y <= 0.0:
		Pool.release(self)
		return


func _on_body_entered(body: Node2D) -> void:
	# Consume-on-hit guard (Decision #10 — no piercing): release is deferred (see
	# below), so `monitoring` stays true until the deferred call actually runs. If
	# two enemy bodies overlap this Area2D within the same physics step, the engine
	# can fire body_entered twice before that release lands. _consumed is a plain
	# script flag (not an engine-locked property), set synchronously here, so the
	# second call is a no-op — exactly one hit is ever applied per activate().
	if _consumed:
		return
	_consumed = true
	# Damage stub (Decision #6): apply damage to the body's conventionally-named
	# HealthComponent child if present, then consume-on-hit (release). The real
	# HurtboxComponent-mediated wiring lands in 1.4; this node-name lookup is
	# forward-compatible (1.4 enemies follow the same HealthComponent convention).
	var hc: Node = body.get_node_or_null("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.take_damage(_damage)
	# Consume-on-hit → release. Deferred because body_entered fires DURING the
	# physics step, and removing a CollisionObject (this Area2D) synchronously inside
	# a physics callback is forbidden by the engine ("use call_deferred"). Damage
	# above is already applied synchronously; only the detach is deferred to idle.
	# (Leave-screen release in _physics_process is fine synchronous — it runs before
	# the physics step, not during a server callback.)
	Pool.release.call_deferred(self)
