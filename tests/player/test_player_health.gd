extends GutTest
# Integration tests for the Player's ship-economy wiring (Story 1.5 / AC2, AC3).
# Instantiates player.tscn, drives HealthComponent.take_damage directly (the same path
# EnemyProjectile._on_body_entered calls), and asserts on HP state + the LOCAL
# ship_depleted signal (intra-entity→parent, D8). Mirrors the 1.3/1.4 GUT style.
#
# The player is NOT a self-releasing pooled node — parent it under an autofreed arena
# (as test_player_movement does) so the subtree is freed cleanly each test.

const PlayerScene := preload("res://player/player.tscn")


func _make() -> Player:
	# Parent under a Node2D "arena" (as in world/arena.tscn). player._ready wires
	# FireSystem.projectile_parent to get_parent() (typed Node2D), so the parent must
	# be a Node2D — the GutTest root is a plain Node.
	var arena := Node2D.new()
	add_child_autofree(arena)
	var p: Player = PlayerScene.instantiate() as Player
	arena.add_child(p)
	return p


func test_iframe_window_set_from_tuning() -> void:
	# _ready feeds tuning.iframe_s into the HealthComponent gate (the player opts in to
	# i-frames; enemies keep the 0.0 default).
	var p := _make()
	assert_eq(p._health.invuln_after_hit_s, p.tuning.iframe_s)
	assert_eq(p._health.invuln_after_hit_s, 1.0)


func test_sub_lethal_hit_emits_health_changed_not_ship_depleted() -> void:
	var p := _make()
	watch_signals(p._health)  # health_changed is the HealthComponent's LOCAL signal (D8)
	watch_signals(p)         # ship_depleted is the Player's LOCAL signal
	p._health.take_damage(1)  # 3 -> 2, still alive
	assert_eq(p._health.current_hp, 2)
	assert_signal_emitted(p._health, "health_changed")
	assert_signal_emit_count(p, "ship_depleted", 0)


func test_lethal_hit_emits_ship_depleted_once() -> void:
	# HP=0 within the wave → HealthComponent.died (LOCAL) → player.ship_depleted (LOCAL).
	var p := _make()
	watch_signals(p)
	p._health.take_damage(3)  # 3 -> 0, died
	assert_eq(p._health.current_hp, 0)
	assert_true(p._health._is_dead)
	assert_signal_emit_count(p, "ship_depleted", 1)
	# A further hit does not stack another ship_depleted (the once-only died guard).
	p._health.set_invuln(0.0)  # clear the post-hit window so the hit is not i-frame-gated
	p._health.take_damage(5)
	assert_signal_emit_count(p, "ship_depleted", 1)


func test_respawn_restores_full_hp_center_and_iframes() -> void:
	var p := _make()
	p._health.take_damage(3)  # lose the ship
	p.respawn()
	assert_eq(p._health.current_hp, p._health.max_hp)
	assert_false(p._health._is_dead)  # cleared by reset_to_full — a new life can die again
	assert_true(p._health.is_invulnerable())  # fresh i-frame window for fair re-entry
	assert_almost_eq(p.global_position.x, Constants.BASE_RESOLUTION.x / 2.0, 0.5)  # lane center


func test_iframes_block_lethal_hit_during_respawn_window() -> void:
	# After respawn grants a window, a lethal hit during it is fully ignored — no second
	# ship loss from a single contact window (AC2).
	var p := _make()
	p._health.take_damage(3)  # -> ship_depleted (1)
	p.respawn()
	watch_signals(p)
	p._health.take_damage(3)  # within the respawn i-frame window — blocked
	assert_eq(p._health.current_hp, p._health.max_hp)  # HP unchanged
	assert_signal_emit_count(p, "ship_depleted", 0)


func _make_enemy_body(pos: Vector2) -> CharacterBody2D:
	# Dummy enemy body on LAYER_ENEMY (what the player's HurtboxComponent detects). Mirrors
	# test_enemy_projectile.gd::_make_player_fixture, inverted to the enemy faction. mask 0 so it
	# doesn't physically collide with the player body (irrelevant to damage — the Area2D detects it).
	var body := CharacterBody2D.new()
	body.collision_layer = Constants.LAYER_ENEMY
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 16.0
	cs.shape = circ
	body.add_child(cs)
	body.global_position = pos
	add_child_autofree(body)
	return body


func test_enemy_body_contact_damages_player() -> void:
	# An enemy body overlapping the player's HurtboxComponent deals contact_damage (decision-log
	# [Contact-damage]). body_entered can't be raised by a manual _physics_process step — await
	# real physics frames for the engine overlap.
	var p := _make()
	var hp_before := p._health.current_hp  # 3
	_make_enemy_body(p.global_position)  # fully overlapping the player
	for _i in 12:
		await get_tree().physics_frame
	assert_eq(p._health.current_hp, hp_before - 1)  # contact_damage defaults to 1


func test_contact_respects_iframes() -> void:
	# After a contact grants the i-frame window, a second overlapping body during it deals no
	# further damage; after the window expires, a new contact damages again (no double-loss from
	# one window). The i-frame timer ticks in HealthComponent._process (not _physics_process).
	var p := _make()
	var body := _make_enemy_body(p.global_position)
	for _i in 12:
		await get_tree().physics_frame
	assert_eq(p._health.current_hp, 2)  # first contact landed
	assert_true(p._health.is_invulnerable())  # i-frame window active
	body.queue_free()
	_make_enemy_body(p.global_position)  # fresh overlap — still within i-frames
	for _i in 12:
		await get_tree().physics_frame
	assert_eq(p._health.current_hp, 2)  # i-framed — no further damage
	p._health.set_invuln(0.0)  # expire the window
	_make_enemy_body(p.global_position)
	for _i in 12:
		await get_tree().physics_frame
	assert_eq(p._health.current_hp, 1)  # window expired — damage applies again
