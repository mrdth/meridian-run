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


func _make(scene: PackedScene, form: FormationDefinition = StandardForm) -> Enemy:
	# acquire → add_child → activate (so @onready refs are valid in activate). Stationary:
	# the StateMachine + fire ticks are disabled so tests that don't care about motion get a
	# predictable enemy; movement tests drive the StateMachine by hand. `form` defaults to the
	# authored standard.tres (sweep_chance 0.3); dive/sweep tests pass a forced-chance duplicate.
	var container := Node2D.new()
	add_child_autofree(container)
	var enemy: Enemy = Pool.acquire(scene) as Enemy
	container.add_child(enemy)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	enemy.activate(form, 0, rng)
	enemy.get_node("StateMachine").set_physics_process(false)
	enemy.get_node("EnemyFireSystem").set_physics_process(false)
	return enemy


func _form_with_sweep_chance(chance: float) -> FormationDefinition:
	# Independent duplicate so a test can force dive-only (0.0) or sweep-only (1.0) without
	# mutating the shared StandardForm preload (standard.tres now has sweep_chance = 0.3, which
	# would make the dive-path tests rng-fragile). Curves are shared (never mutated) — fine.
	var form := StandardForm.duplicate() as FormationDefinition
	form.sweep_chance = chance
	return form


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
	var e: Enemy = _make(GruntScene, _form_with_sweep_chance(0.0))  # dive-only — deterministic
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
	var e: Enemy = _make(GruntScene, _form_with_sweep_chance(0.0))  # dive-only — deterministic
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


func test_dive_tracks_player_x_when_factor_set() -> void:
	# dive_aim_track_factor (standard.tres = 0.3) blends the once-captured dive aim toward the
	# player's LIVE x. Anti-camp: a player who relocates to / camps a screen edge AFTER dive-start
	# is still pursued, instead of the diver sailing past on a stale capture-once aim.
	var e: Enemy = _make(GruntScene)  # slot 0 → slot_world_pos.x ≈ 150
	var sm: StateMachine = e.get_node("StateMachine")
	var dive: State = e.get_node("StateMachine/DiveState")
	# Fake player parked at the slot's x at dive-start → captured aim ≈ 0.
	var player := Node2D.new()
	add_child_autofree(player)
	player.global_position = Vector2(150.0, 680.0)
	e.player_target = player
	# Jump straight into DiveState (skip entry/formation timing).
	sm.transition_to(dive)
	# NOW move the player far right. With capture-once (factor 0) the diver would stay on-curve
	# (slot.x + curve_x ≤ ~265); only live tracking bends it rightward toward the moved player.
	# At factor 0.3 the bend is partial (not the ~400+ a factor of 0.7 would reach), so the bar
	# is set just above the no-tracking ceiling rather than close to the moved player's x.
	player.global_position.x = 1250.0
	for _i in 40:
		sm._physics_process(1.0 / 60.0)
	assert_gt(e.global_position.x, 320.0, "dive did not track the relocated player")
	# Sanity: the diver hasn't crossed the bottom (no re-entry) within this short window.
	assert_lt(e.global_position.y, Constants.BASE_RESOLUTION.y)


func test_formation_transitions_to_sweep_when_chance_one() -> void:
	# sweep_chance = 1.0 forces every formation-hold expiry into SweepState instead of DiveState
	# (decision-log [Sweep-state]).
	var e: Enemy = _make(GruntScene, _form_with_sweep_chance(1.0))
	var sm: StateMachine = e.get_node("StateMachine")
	var sweep: State = e.get_node("StateMachine/SweepState")
	var seen_sweep: bool = false
	for _i in 500:  # 8.3 s — entry (~2.4 s) + hold (~2.5 s) → first sweep
		sm._physics_process(1.0 / 60.0)
		if sm.current_state == sweep:
			seen_sweep = true
			break
	assert_true(seen_sweep, "never reached SweepState from formation")


func test_sweep_loops_re_enters_does_not_release() -> void:
	# A sweeper that exits the side RE-ENTERS from the top (EnterState) and returns to cycling —
	# it does NOT release. Only death releases (mirrors the dive-loop invariant). Slot 0 (x≈150
	# < center) sweeps RIGHT, exiting past BASE_RESOLUTION.x.
	var e: Enemy = _make(GruntScene, _form_with_sweep_chance(0.0))
	var sm: StateMachine = e.get_node("StateMachine")
	var sweep: State = e.get_node("StateMachine/SweepState")
	var enter: State = e.get_node("StateMachine/EnterState")
	sm.transition_to(sweep)
	var crossed_side: bool = false
	var re_entered: bool = false
	for _i in 1500:  # 25 s
		if e.get_parent() == null or not is_instance_valid(e):
			break  # released — failure (sweepers should loop, not release)
		sm._physics_process(1.0 / 60.0)
		if not crossed_side and e.global_position.x > Constants.BASE_RESOLUTION.x:
			crossed_side = true
		elif crossed_side and sm.current_state == enter:
			re_entered = true
			break
	assert_true(crossed_side, "sweeper never exited the side")
	assert_true(re_entered, "exited the side but didn't re-enter from the top (released instead of looping?)")


func test_sweep_traverses_toward_far_edge_at_sweep_y() -> void:
	# Slot 0 (x≈150 < center) sweeps RIGHT toward the far edge, descending to ≈sweep_y. Confirms
	# the run covers the lane (anti-camp) and holds the sweep altitude (decision-log [Sweep-state]).
	var e: Enemy = _make(GruntScene, _form_with_sweep_chance(0.0))
	var sm: StateMachine = e.get_node("StateMachine")
	var sweep: State = e.get_node("StateMachine/SweepState")
	sm.transition_to(sweep)
	for _i in 60:  # ~1 s at 550 px/s → from 150 to ~700 (past center, toward the far edge)
		sm._physics_process(1.0 / 60.0)
	assert_gt(e.global_position.x, Constants.BASE_RESOLUTION.x * 0.5, "sweep did not traverse toward the far edge")
	assert_almost_eq(e.global_position.y, 430.0, 5.0, "sweep did not hold sweep_y")


func test_dive_crosses_player_x_at_the_lane() -> void:
	# A STATIONARY player at center: the diver must converge to the player's X by the lane Y
	# (decision-log [Contact-damage]) so contact + straight-down fire land. Previously (aim*u) it
	# only reached player.x off-screen, passing visibly beside a stationary player.
	var e: Enemy = _make(GruntScene)
	var sm: StateMachine = e.get_node("StateMachine")
	var dive: State = e.get_node("StateMachine/DiveState")
	var player := Node2D.new()
	add_child_autofree(player)
	player.global_position = Vector2(640.0, 680.0)  # center lane
	e.player_target = player
	sm.transition_to(dive)
	# Step until the diver reaches the player's lane Y, then snapshot its X.
	var lane_x: float = -1.0
	for _i in 120:
		sm._physics_process(1.0 / 60.0)
		if e.global_position.y >= 670.0 and e.global_position.y <= 690.0:
			lane_x = e.global_position.x
			break
	assert_gt(lane_x, 0.0, "diver never reached the player's lane")
	# At the lane target.x = slot.x + aim = slot.x + (player.x - slot.x) = player.x (jitter cancels).
	assert_almost_eq(lane_x, 640.0, 25.0, "diver did not cross the player's x at the lane")


func _step(sm: StateMachine, frames: int) -> void:
	for _i in frames:
		sm._physics_process(1.0 / 60.0)
