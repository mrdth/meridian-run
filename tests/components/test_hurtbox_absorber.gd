extends GutTest
# Story 2.3 (Task 8 / Task 7) — the contact-damage path routes through Player.apply_hit (AC#3
# absorber). The HurtboxComponent._on_body_entered duck-calls owner.apply_hit (the owner is the
# Player) instead of HealthComponent.take_damage directly, so the absorber gate runs for CONTACT damage
# too (not just projectiles). Uses REAL physics frames: Area2D body_entered reads the physics server's
# last overlap update, which only advances on a real physics tick (memory area-overlap-tests-need-real-
# physics-frames). A docked player absorbs the contact (HP spared); a clean player takes HP damage.

const PlayerScene := preload("res://player/player.tscn")


func before_each() -> void:
	Pool.clear()


func _make() -> Player:
	# Player under a Node2D arena (so _ready runs + the HurtboxComponent wires monitoring). Disable the
	# player's _physics_process (it moves on input) + the FireSystem so neither interferes with the
	# overlap timing. The HurtboxComponent Area2D keeps processing (the physics server tracks overlaps).
	var arena := Node2D.new()
	add_child_autofree(arena)
	var p: Player = PlayerScene.instantiate() as Player
	arena.add_child(p)
	p.set_physics_process(false)
	(p.get_node_or_null("FireSystem") as Node).set_physics_process(false)
	return p


func _make_enemy_body(at: Vector2) -> CharacterBody2D:
	# A minimal enemy ramming body on LAYER_ENEMY (what the player's HurtboxComponent masks) with a
	# CollisionShape2D large enough to solidly overlap the hurtbox radius (11 clean / 18 docked).
	var e := CharacterBody2D.new()
	e.collision_layer = Constants.LAYER_ENEMY
	e.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	cs.shape = shape
	e.add_child(cs)
	e.global_position = at
	add_child_autofree(e)
	return e


func test_docked_player_contact_is_absorbed() -> void:
	# AC#3 absorber on the CONTACT path: a docked player rammed by an enemy body → apply_hit (via the
	# hurtbox) → the docked ship is consumed, HP is SPARED. Positions the enemy at the player's center
	# (overlapping the hurtbox) + awaits real physics frames for body_entered to fire.
	var p := _make()
	p.try_dock_ship()
	var hp_before: int = p._health.current_hp
	var _enemy := _make_enemy_body(p.global_position)  # ramming contact at the player's center.
	# Real physics frames so the Area2D overlap registers + body_entered fires.
	for _i in 4:
		await get_tree().physics_frame
	assert_null(p._docked_ship, "the docked ship should be consumed on a contact hit (absorber via hurtbox)")
	assert_false(p.is_docked())
	assert_eq(p._health.current_hp, hp_before, "HP must be SPARED on a contact absorb")
	await get_tree().physics_frame  # let the deferred DockedShip free land before teardown.


func test_clean_player_contact_damages_hp() -> void:
	# A clean player rammed by an enemy body → apply_hit → HP damaged (the centralized route, no absorber).
	var p := _make()
	var hp_before: int = p._health.current_hp
	var _enemy := _make_enemy_body(p.global_position)
	for _i in 4:
		await get_tree().physics_frame
	assert_lt(p._health.current_hp, hp_before, "a clean player should take contact damage via apply_hit")
