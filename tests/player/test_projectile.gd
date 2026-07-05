extends GutTest
# Integration tests for the Projectile scene (1.3). Instantiates projectile.tscn and
# asserts on global_position / current_hp / get_parent() — never visuals. Mirrors the
# 1.2 GUT style (add_child_autofree, assert_almost_eq for float32-vs-float64, direct
# _physics_process stepping for determinism, await physics_frame for engine signals).
#
# Pool discipline: a projectile that self-releases to the pool is added with plain
# add_child (NOT add_child_autofree) so GUT does not free a node the Pool still holds.

const ProjectileScene := preload("res://player/projectile.tscn")


func before_each() -> void:
	# Pool is an autoload; clear it so each test starts from a known-empty pool
	# instead of leaning on cross-test state (review fix — 1.3 D7 review).
	Pool.clear()


func test_structure_is_area2d_on_player_projectile_layer() -> void:
	# AC2 — Area2D on LAYER_PLAYER_PROJECTILE, masked to LAYER_ENEMY, with activate().
	var p: Projectile = add_child_autofree(ProjectileScene.instantiate()) as Projectile
	assert_true(p is Area2D)
	assert_eq(p.collision_layer, Constants.LAYER_PLAYER_PROJECTILE)  # 4
	assert_eq(p.collision_mask, Constants.LAYER_ENEMY)              # 2
	assert_true(p.has_method("activate"))


func test_activate_then_step_moves_straight_up() -> void:
	# AC1 — manual delta integration: y decreases by speed*delta each step (straight
	# up, zero allocation). global_position.y is a float32 Vector2 component, so the
	# float64 expected value is compared with epsilon.
	var p: Projectile = add_child_autofree(ProjectileScene.instantiate()) as Projectile
	p.activate(Vector2(100.0, 600.0), 620.0, 10)
	for _i in 3:
		p._physics_process(1.0 / 60.0)
	# 600 - 3 * (620/60) = 600 - 31 = 569
	assert_almost_eq(p.global_position.y, 569.0, 0.05)


func test_leaves_screen_and_releases_to_pool() -> void:
	# AC3 — when y <= 0 the projectile releases itself back to the pool (never
	# queue_free). The projectile self-releases via Pool.release(self), so it MUST be
	# Pool-acquired (as FireSystem does) — a directly-instantiated node is unknown to
	# the pool and its release is ignored. Assert it detaches on the release frame.
	var parent: Node2D = add_child_autofree(Node2D.new())
	var p: Projectile = Pool.acquire(ProjectileScene) as Projectile
	parent.add_child(p)  # plain add_child: p self-releases to the pool
	p.activate(Vector2(100.0, 5.0), 620.0, 10)
	assert_eq(p.get_parent(), parent)  # sanity: attached before the step
	# 5 - 620/60 ≈ -5.33 → <= 0 → release on this step.
	p._physics_process(1.0 / 60.0)
	assert_eq(p.get_parent(), null)  # released → detached


func test_hits_enemy_body_applies_damage_and_consumes() -> void:
	# AC3 (hit) + AC1 (damage). A dummy target on LAYER_ENEMY with a HealthComponent
	# child sits in the projectile's upward path. The engine detects the overlap and
	# fires body_entered — this CANNOT be triggered by a manual _physics_process call,
	# so we await real physics frames. Exercises the damage stub + consume-on-hit path
	# (the real HurtboxComponent wiring lands in 1.4).
	var target: CharacterBody2D = CharacterBody2D.new()
	target.collision_layer = Constants.LAYER_ENEMY
	var tshape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	tshape.shape = rect
	target.add_child(tshape)
	var hc := HealthComponent.new()
	hc.max_hp = 100
	hc.name = "HealthComponent"  # convention name the projectile looks up
	target.add_child(hc)
	target.global_position = Vector2(100.0, 200.0)
	add_child_autofree(target)

	# Spawn just below the target (target spans y 180..220); it travels up into it.
	# Pool-acquired (not instantiated) so its self-release on hit is honoured.
	var p: Projectile = Pool.acquire(ProjectileScene) as Projectile
	add_child(p)  # plain add_child: p self-releases to the pool on hit
	p.activate(Vector2(100.0, 225.0), 620.0, 10)

	for _i in 5:
		await get_tree().physics_frame

	assert_eq(hc.current_hp, 90)      # took 10 damage via the HealthComponent stub
	assert_eq(p.get_parent(), null)   # consume-on-hit → released


func test_sublethal_hit_fires_hit_flash_juice() -> void:
	# Sub-lethal impact juice (Story 1.6 / AC1) — a surviving hit must still flash the enemy.
	var target: CharacterBody2D = CharacterBody2D.new()
	target.collision_layer = Constants.LAYER_ENEMY
	var tshape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	tshape.shape = rect
	target.add_child(tshape)
	var hc := HealthComponent.new()
	hc.max_hp = 100
	hc.name = "HealthComponent"
	target.add_child(hc)
	target.global_position = Vector2(100.0, 200.0)
	add_child_autofree(target)

	watch_signals(EventBus)
	var p: Projectile = Pool.acquire(ProjectileScene) as Projectile
	add_child(p)
	p.activate(Vector2(100.0, 225.0), 620.0, 10)  # 10 damage on 100 hp ⇒ survives

	for _i in 5:
		await get_tree().physics_frame

	assert_eq(hc.current_hp, 90)
	assert_signal_emitted(EventBus, "hit_flash_requested")


func test_lethal_hit_does_not_fire_hit_flash_juice() -> void:
	# Review fix — a killing blow must NOT also fire the sub-lethal hit-flash. `Enemy._on_died()`
	# owns death juice (explosion/kill-shake/kill-SFX — no flash; the tuning table scopes a kill's
	# flash column as "— it's exploding") and defers `Pool.release()` the SAME frame a flash tween
	# started here would still be animating `modulate`, so a reacquired pooled node for an unrelated
	# new spawn could visibly flash. Skipping the flash on a lethal hit removes the race entirely.
	var target: CharacterBody2D = CharacterBody2D.new()
	target.collision_layer = Constants.LAYER_ENEMY
	var tshape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	tshape.shape = rect
	target.add_child(tshape)
	var hc := HealthComponent.new()
	hc.max_hp = 5
	hc.name = "HealthComponent"
	target.add_child(hc)
	target.global_position = Vector2(100.0, 200.0)
	add_child_autofree(target)

	watch_signals(EventBus)
	var p: Projectile = Pool.acquire(ProjectileScene) as Projectile
	add_child(p)
	p.activate(Vector2(100.0, 225.0), 620.0, 10)  # 10 damage on 5 hp ⇒ lethal

	for _i in 5:
		await get_tree().physics_frame

	assert_eq(hc.current_hp, 0)
	assert_signal_not_emitted(EventBus, "hit_flash_requested")


func test_second_body_entered_before_release_is_ignored() -> void:
	# Review fix (Decision #10, consume-on-hit / no piercing): release on hit is
	# deferred (the engine forbids synchronous removal during a physics callback),
	# so `monitoring` stays true until that deferred call lands. If two enemy bodies
	# overlap the projectile within the same physics step, body_entered can fire
	# twice before the release detaches it. Only the FIRST hit should apply damage —
	# calling _on_body_entered directly twice (bypassing physics) simulates that
	# same-step double-fire deterministically.
	var target_a := CharacterBody2D.new()
	var hc_a := HealthComponent.new()
	hc_a.max_hp = 100
	hc_a.name = "HealthComponent"
	target_a.add_child(hc_a)
	add_child_autofree(target_a)

	var target_b := CharacterBody2D.new()
	var hc_b := HealthComponent.new()
	hc_b.max_hp = 100
	hc_b.name = "HealthComponent"
	target_b.add_child(hc_b)
	add_child_autofree(target_b)

	var p: Projectile = Pool.acquire(ProjectileScene) as Projectile
	add_child(p)  # plain add_child: p self-releases to the pool on hit
	p.activate(Vector2(100.0, 300.0), 620.0, 10)

	p._on_body_entered(target_a)
	p._on_body_entered(target_b)  # simulated same-step second overlap

	assert_eq(hc_a.current_hp, 90)   # first hit applies damage
	assert_eq(hc_b.current_hp, 100)  # second hit ignored — no piercing

	await get_tree().physics_frame  # let the deferred release land before teardown
