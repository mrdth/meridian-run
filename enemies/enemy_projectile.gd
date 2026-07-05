class_name EnemyProjectile
extends Area2D
# Pooled enemy projectile (1.4). Mirrors player/projectile.gd but INVERTED: travels
# DOWNWARD, on LAYER_ENEMY_PROJECTILE, masked to LAYER_PLAYER. Detects the player body
# and damages its HealthComponent via the SAME node-name convention (forward-compat from
# Story 1.3). Releases to Pool on hit (consume-on-hit) or leave-screen. activate()-only
# re-init (AR6/AR14); _ready runs once on first tree entry and never re-fires.
#
# Bomber HEAVY shots pass heavy=true → a distinct larger amber pellet (climax-hazard
# family) — "telegraphed" realized as silhouette/color in v0.1 (Dev Notes §"Bomber telegraph").

var _speed: float = 0.0
var _damage: int = 0
var _heavy: bool = false
var _consumed: bool = false
var _visual: Polygon2D  # lazy-resolved in activate (see note below).


func _ready() -> void:
	# Layers/masks from Constants — never magic numbers. Set once; persist across re-acquire.
	collision_layer = Constants.LAYER_ENEMY_PROJECTILE  # 8
	collision_mask = Constants.LAYER_PLAYER             # 1
	body_entered.connect(_on_body_entered)
	_resolve_visual()


func activate(spawn_pos: Vector2, speed: float, damage: int, heavy: bool = false) -> void:
	# Re-init entry (AR6) — same signature shape as the player projectile, +heavy for the
	# Bomber's telegraphed pellet. _speed/_damage/_heavy cached here, never read from an
	# autoload per frame (NFR3 hot path). NOTE: the fire system calls activate BEFORE
	# add_child (the player-fire_system order), so @onready has not fired on first acquire —
	# _visual is lazy-resolved here (get_node works pre-SceneTree; it walks the node's own
	# child tree, not the SceneTree).
	_resolve_visual()
	_speed = speed
	_damage = damage
	_heavy = heavy
	_consumed = false
	global_position = spawn_pos
	visible = true
	set_physics_process(true)
	monitoring = true
	# Heavy = larger amber pellet (climax-hazard); standard = hazard-calm red. Shape carries
	# the read; hue reinforces (UX A2 — never hue-alone, but here the shapes also differ in
	# the source enemies, and the heavy pellet is uniformly bigger).
	if _visual != null:
		if _heavy:
			_visual.color = Color(1.0, 0.62, 0.24)
			_visual.scale = Vector2(1.6, 1.6)
		else:
			_visual.color = Color(1.0, 0.24, 0.35)
			_visual.scale = Vector2.ONE


func _resolve_visual() -> void:
	# Cache the Visual child. Idempotent. get_node_or_null walks this node's own child tree,
	# so it resolves even before the node enters the SceneTree (activate-before-add_child).
	if _visual == null:
		_visual = get_node_or_null("Visual")


func _physics_process(delta: float) -> void:
	# Straight DOWN (toward the player's bottom lane). Manual delta integration is correct
	# for an Area2D (no move_and_slide). Leave-screen (bottom of the 720-tall field) → release.
	global_position.y += _speed * delta
	if global_position.y >= Constants.BASE_RESOLUTION.y:
		Pool.release(self)
		return


func _on_body_entered(body: Node2D) -> void:
	# Consume-on-hit (mirror player projectile). Damage the player's conventionally-named
	# HealthComponent child if present, then release. Deferred release — body_entered fires
	# DURING the physics step (engine forbids synchronous CollisionObject removal then).
	if _consumed:
		return
	_consumed = true
	var hc: Node = body.get_node_or_null("HealthComponent")
	# i-frames make take_damage() a full no-op (no damage, no signals) — capture that BEFORE the
	# call so a phantom hit doesn't burn the shared ≤3Hz hit-flash budget / shake / SFX for damage
	# that never landed (review fix: a hit during i-frames must not fire juice at all).
	var was_invulnerable: bool = hc != null and hc.has_method("is_invulnerable") and hc.is_invulnerable()
	if hc != null and hc.has_method("take_damage"):
		hc.take_damage(_damage)
	if not was_invulnerable:
		# Player-hit juice (Story 1.6 / AC1) — the inverse faction of projectile.gd. `_heavy` is in
		# scope here, so the heavy (Bomber) variant scales the shake/spark/pitch via JuiceFx. Emits
		# the impact hit-flash on the player BODY (the JuiceCoordinator tweens it); player.gd
		# separately keeps the SUSTAINED i-frame pulse. Juice is additive — the damage/i-frame path
		# is untouched.
		JuiceFx.player_hit(global_position, body, _heavy)
	Pool.release.call_deferred(self)
