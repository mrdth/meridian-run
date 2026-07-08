class_name HurtboxComponent
extends Area2D
# Reusable contact-damage receiver (decision-log [Contact-damage]). Detects bodies on a faction
# layer (collision_mask) and routes damage to the OWNER's HealthComponent — the inverse of the
# projectile pattern (enemy_projectile damages the body it ENTERS; a hurtbox damages its OWNER when
# a body enters it). This reverses the "projectile-only damage" half of Key Decision #1: enemy
# bodies now deal contact damage. The MOVEMENT half of Key Decision #1 stays — enemies keep
# collision_mask=0 so they pass through everything for exact-tracking; this Area2D detects the
# enemy body via its collision_layer. The future Captor capture mechanic reuses this component.
#
# Persistent: the player is NOT pooled, so this wires once in _ready and monitoring stays on (no
# activate()/pool toggling, unlike projectiles). i-frames are checked BEFORE take_damage so a
# contact during i-frames is a full no-op (no damage, no juice) — mirrors enemy_projectile.gd:82.

@export var contact_damage: int = 1  # a ram = a standard hit, flat (decoupled from fire_damage).

var _health: HealthComponent


func _ready() -> void:
	# Detect enemy bodies (collision_mask). collision_layer 0 — the hurtbox DETECTS, it isn't
	# detected by anything (kept off LAYER_PLAYER so enemy-projectile Area2Ds can't area-enter it;
	# they use body_entered anyway, but 0 is the conservative choice).
	collision_layer = 0
	collision_mask = Constants.LAYER_ENEMY
	monitoring = true
	# Owner = the scene root (the Player). The HealthComponent is a conventionally-named child of
	# the player — the same node-name lookup the projectiles use, resolved once here (not per-hit).
	if owner != null:
		_health = owner.get_node_or_null("HealthComponent") as HealthComponent
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# i-frames make take_damage() a full no-op — capture that BEFORE the call so a phantom contact
	# doesn't burn the shared hit-flash/shake/SFX budget for damage that never landed (same gating
	# as enemy_projectile.gd:82). `body` is the enemy CharacterBody2D (passed to JuiceFx for the
	# hit position/feedback).
	if _health == null:
		return
	var was_invulnerable: bool = _health.is_invulnerable()
	_health.take_damage(contact_damage)
	if not was_invulnerable:
		JuiceFx.player_hit(global_position, body, false)
