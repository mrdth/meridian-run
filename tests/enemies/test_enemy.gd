extends GutTest
# Integration tests for the Enemy entity (1.4). Mirrors the pool-fixture style of
# tests/player/test_projectile.gd. Verifies variant scenes' collision/faction/HP wiring, the
# HealthComponent death contract, pool round-trip (no stacked signal connections), the Story
# 1.3 regression guard (player projectile still hits a CharacterBody2D enemy), and the
# Enter→Formation→Dive state progression.

const GruntScene := preload("res://enemies/grunt.tscn")
const ShielderScene := preload("res://enemies/shielder.tscn")
const BomberScene := preload("res://enemies/bomber.tscn")
const StandardForm := preload("res://resources/formations/standard.tres")
const PlayerProjectileScene := preload("res://player/projectile.tscn")


func before_each() -> void:
	Pool.clear()


func _make(scene: PackedScene) -> Enemy:
	# acquire → add_child → activate (so @onready refs are valid in activate). Stationary:
	# the StateMachine + fire ticks are disabled so tests that don't care about motion get a
	# predictable enemy; movement tests drive the StateMachine by hand.
	var container := Node2D.new()
	add_child_autofree(container)
	var enemy: Enemy = Pool.acquire(scene) as Enemy
	container.add_child(enemy)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	enemy.activate(StandardForm, 0, rng)
	enemy.get_node("StateMachine").set_physics_process(false)
	enemy.get_node("EnemyFireSystem").set_physics_process(false)
	return enemy


func test_variants_on_enemy_layer_mask_zero() -> void:
	for scene in [GruntScene, ShielderScene, BomberScene]:
		var e: Enemy = _make(scene)
		assert_eq(e.collision_layer, Constants.LAYER_ENEMY)  # 2
		assert_eq(e.collision_mask, 0)


func test_health_component_named_with_variant_max_hp() -> void:
	# The HealthComponent child MUST be named exactly "HealthComponent" (the player projectile
	# looks it up by that name — the forward-compat contract from Story 1.3).
	var g: Enemy = _make(GruntScene)
	assert_not_null(g.get_node_or_null("HealthComponent"))
	assert_eq((g.get_node("HealthComponent") as HealthComponent).max_hp, 30)
	assert_eq((g.get_node("HealthComponent") as HealthComponent).current_hp, 30)
	var s: Enemy = _make(ShielderScene)
	assert_eq((s.get_node("HealthComponent") as HealthComponent).max_hp, 50)
	var b: Enemy = _make(BomberScene)
	assert_eq((b.get_node("HealthComponent") as HealthComponent).max_hp, 80)


func test_faction_is_enemy() -> void:
	# FactionComponent defaults to PLAYER — a common bug; verify the scene sets ENEMY.
	var e: Enemy = _make(GruntScene)
	var fc: FactionComponent = e.get_node("FactionComponent")
	assert_eq(fc.faction, FactionComponent.Faction.ENEMY)


func test_visual_scale_driven_by_silhouette_scale() -> void:
	# silhouette_scale (.tres) drives the Visual scale; collision_radius drives the CircleShape2D
	# hitbox. Base variants 150% (1.5 / radius 21), Bomber 165% (1.65 / radius 26.4).
	var g: Enemy = _make(GruntScene)
	assert_almost_eq((g.get_node("Visual") as Polygon2D).scale.x, 1.5, 0.01)
	var gshape := (g.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	assert_almost_eq(gshape.radius, 21.0, 0.01)  # 14 * 1.5
	var b: Enemy = _make(BomberScene)
	assert_almost_eq((b.get_node("Visual") as Polygon2D).scale.x, 1.65, 0.01)
	var bshape := (b.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	assert_almost_eq(bshape.radius, 26.4, 0.01)  # 16 * 1.65


func test_take_damage_decrements_and_emits_health_changed() -> void:
	var e: Enemy = _make(GruntScene)
	var hc: HealthComponent = e.get_node("HealthComponent")
	watch_signals(hc)
	hc.take_damage(10)
	assert_eq(hc.current_hp, 20)
	assert_signal_emit_count(hc, "health_changed", 1)


func test_died_emits_exactly_once_at_zero() -> void:
	var e: Enemy = _make(GruntScene)
	var hc: HealthComponent = e.get_node("HealthComponent")
	watch_signals(hc)
	hc.take_damage(30)  # 30 - 30 = 0 → died
	assert_eq(hc.current_hp, 0)
	assert_signal_emit_count(hc, "died", 1)
	hc.take_damage(10)  # already dead → no second emit
	assert_signal_emit_count(hc, "died", 1)


func test_enemy_died_signal_carries_score_value() -> void:
	# The enemy's OWN local died signal (D8) carries score_value; the spawner reads it.
	# (watch_signals + assert_signal_emitted_with_parameters — GDScript lambdas capture
	# primitives by value, so a counter lambda wouldn't observe the value.)
	var e: Enemy = _make(BomberScene)
	watch_signals(e)
	var hc: HealthComponent = e.get_node("HealthComponent")
	hc.take_damage(80)  # bomber 80 hp → 0 → _on_died → enemy.died.emit(score_value)
	assert_signal_emitted_with_parameters(e, "died", [300])
	await get_tree().physics_frame  # let the deferred release land before teardown


func test_pool_round_trip_no_stacked_connections() -> void:
	# Acquire → activate → release → re-acquire must reuse the node with the died→_on_died
	# connection still wired EXACTLY once (made in _ready, never reconnected in activate).
	var e: Enemy = _make(GruntScene)
	var hc: HealthComponent = e.get_node("HealthComponent")
	assert_eq(hc.died.get_connections().size(), 1)
	Pool.release(e)

	var e2: Enemy = Pool.acquire(GruntScene) as Enemy
	assert_eq(e2.get_instance_id(), e.get_instance_id())  # LIFO reuse
	var container := Node2D.new()
	add_child_autofree(container)
	container.add_child(e2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	e2.activate(StandardForm, 0, rng)
	var hc2: HealthComponent = e2.get_node("HealthComponent")
	assert_eq(hc2.died.get_connections().size(), 1)  # still one — no stacking


func test_player_projectile_damages_enemy() -> void:
	# Story 1.3 regression guard: the player projectile's body_entered path must hit a
	# CharacterBody2D enemy on LAYER_ENEMY and apply take_damage to its HealthComponent.
	var e: Enemy = _make(GruntScene)
	e.global_position = Vector2(100.0, 200.0)  # stationary (_make disabled the tick)
	var hc: HealthComponent = e.get_node("HealthComponent")
	var pp: Projectile = Pool.acquire(PlayerProjectileScene) as Projectile
	e.get_parent().add_child(pp)  # share the enemy's container (world space)
	pp.activate(Vector2(100.0, 250.0), 620.0, 10)  # below the enemy, travels up into it
	for _i in 10:
		await get_tree().physics_frame
	assert_eq(hc.current_hp, 20)  # 30 - 10 via the existing hit path


func test_state_progression_enter_to_formation_to_dive() -> void:
	# Drive the StateMachine by hand. Traversal is now SPEED-based (entry ≈ baked_length /
	# move_speed ≈ 2.4 s for a grunt; formation hold ≈ 2.5 s ±25% per enemy). Rather than
	# assert frame-precise timing (fragile under variance), record the states VISITED and
	# assert the order Enter → Formation → Dive is reached within a generous window.
	var e: Enemy = _make(GruntScene)
	var sm: StateMachine = e.get_node("StateMachine")
	var enter: State = e.get_node("StateMachine/EnterState")
	var form: State = e.get_node("StateMachine/FormationState")
	var dive: State = e.get_node("StateMachine/DiveState")
	var seen_form: bool = false
	var seen_dive: bool = false
	assert_eq(sm.current_state, enter)
	for _i in 500:  # 8.3 s — enough to reach formation and the first dive
		sm._physics_process(1.0 / 60.0)
		if sm.current_state == form:
			seen_form = true
		elif sm.current_state == dive:
			seen_dive = true
	assert_true(seen_form, "never reached FormationState")
	assert_true(seen_dive, "never reached DiveState")


func test_dive_loops_re_enters_does_not_release() -> void:
	# Reworked Galaga loop: a diver that crosses the bottom RE-ENTERS from the top and returns
	# to formation — it does NOT release. Only death releases (HealthComponent.died → Pool).
	# Catches the v1 regression where divers exited the bottom and vanished.
	var e: Enemy = _make(GruntScene)
	var sm: StateMachine = e.get_node("StateMachine")
	var crossed_bottom: bool = false
	var re_entered: bool = false
	for _i in 1500:  # 25 s — entry + hold + dive + re-entry
		if e.get_parent() == null or not is_instance_valid(e):
			break  # released — failure (divers should loop, not release)
		sm._physics_process(1.0 / 60.0)
		if not crossed_bottom and e.global_position.y > Constants.BASE_RESOLUTION.y:
			crossed_bottom = true
		elif crossed_bottom and e.global_position.y < 50.0:
			re_entered = true
			break
	assert_true(crossed_bottom, "enemy never dived off the bottom")
	assert_true(re_entered, "crossed the bottom but didn't re-enter from the top (released instead of looping?)")


func _step(sm: StateMachine, frames: int) -> void:
	for _i in frames:
		sm._physics_process(1.0 / 60.0)
