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
# Story 2.6 — travel direction (unit vector). Default straight up (0,-1) so existing callers that omit
# angle_rad (the primary + docked streams) are regression-free; the burst sets this via from_angle for the
# triple-shot spread (±0.18 rad). Stored as a Vector2 (not a scalar) so a future non-vertical shot needs no
# further change here.
var _direction: Vector2 = Vector2(0.0, -1.0)


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


func activate(spawn_pos: Vector2, speed: float, damage: int, angle_rad: float = 0.0) -> void:
	# Re-init entry point — the core pooled-re-init contract (AR6). Called by
	# FireSystem._spawn() right after Pool.acquire(); flips the (deactivated,
	# released) node back on and sets per-spawn state. _speed/_damage/_direction are cached
	# here and never read from an autoload per frame (NFR3 hot path). angle_rad defaults to 0.0
	# (straight up) — the primary + docked streams pass nothing (regression-free); the burst's
	# triple-shot passes ±spread. -PI/2 is "up" in screen space (Vector2.from_angle is CCW from +X).
	_speed = speed
	_damage = damage
	_direction = Vector2.from_angle(-PI / 2.0 + angle_rad)
	_consumed = false
	global_position = spawn_pos
	visible = true
	set_physics_process(true)
	monitoring = true


func _physics_process(delta: float) -> void:
	# Travel along _direction (default straight up; the burst sets an angled direction). Manual delta
	# integration is correct for an Area2D (no move_and_slide); the "never multiply by delta" rule is
	# move_and_slide()-specific. One Vector2 add per tick (the original was a single .y subtract; the
	# Vector2 is unavoidable for angled travel and is not a per-frame allocation — _direction is cached).
	global_position += _direction * _speed * delta
	# Leave-screen (top of the 720-tall field) → release back to the pool. The bullet spawns at ~660 and
	# travels up; for the ±0.18 rad spread the y-component stays negative (upward), so every shot still
	# crosses y == 0 and releases — no projectile leaks. Never queue_free().
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
	var lethal := false
	if hc != null and hc.has_method("take_damage"):
		hc.take_damage(_damage)
		lethal = hc.current_hp <= 0
	# Impact juice (Story 1.6 / AC1): emit from the impact SOURCE (Key Decision #1) — this
	# projectile knows the exact contact global_position + faction. Runs exactly once per shot
	# (after the _consumed guard). Juice is ADDED ON TOP of the damage above; the hit resolution
	# is untouched. Emitting a signal + AudioManager call from a physics callback is safe (only
	# node removal is forbidden mid-physics, and the coordinator's spawn is additive).
	# Skip the sub-lethal hit-flash on a KILLING blow (review fix): `Enemy._on_died()` fires its
	# own death juice (explosion/kill-shake/kill-SFX, no flash — the tuning table already scopes
	# a kill's flash column as "— it's exploding") and defers Pool.release() the SAME frame. A
	# flash tween started here would otherwise still be animating `modulate` when this pooled
	# Enemy node gets reacquired for a new spawn, visibly flashing an unrelated undamaged enemy.
	if not lethal:
		JuiceFx.enemy_hit(global_position, body)
	# Consume-on-hit → release. Deferred because body_entered fires DURING the
	# physics step, and removing a CollisionObject (this Area2D) synchronously inside
	# a physics callback is forbidden by the engine ("use call_deferred"). Damage
	# above is already applied synchronously; only the detach is deferred to idle.
	# (Leave-screen release in _physics_process is fine synchronous — it runs before
	# the physics step, not during a server callback.)
	Pool.release.call_deferred(self)
