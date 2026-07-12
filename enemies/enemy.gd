class_name Enemy
extends CharacterBody2D
# Pooled Grunt/Shielder/Bomber enemy (1.4). CharacterBody2D with collision_mask = 0: the enemy
# passes through everything (exact-tracking needs this — Key Decision #1, MOVEMENT half). Damage
# is dealt BOTH by projectiles (player-projectile body_entered, unchanged since Story 1.3) AND by
# enemy-body CONTACT via the player's HurtboxComponent (decision-log [Contact-damage] — reverses
# the old "projectile-only" damage half of Key Decision #1). Movement is driven
# by the reusable StateMachine child (Enter/Formation/Dive states set velocity + call
# move_and_slide). This script does NOT define its own _physics_process — the StateMachine
# owns the tick (avoids double move_and_slide + parent/child processing-order hazards).
#
# Pool contract (AR6/D7): _ready is ONE-TIME setup; activate() is the pool re-init entry.
# The spawner calls acquire → add_child → activate so @onready refs are valid in activate.

@export var definition: EnemyDefinition

const _SLOT_JITTER_PX: float = 14.0  # review fix: prevents exact-overlap when a slot is reused
                                      # by a later pulse while the prior occupant is still alive.

# Story 2.3 — the failed-rescue "turned-ship" visual (E): the captured ship gone hostile reuses grunt
# behavior/stats BUT swaps the silhouette for the PLAYER arrowhead INVERTED (pointing down) + the hazard
# hue. The arrowhead points are a design constant (the player's Visual/Core polygon, player.tscn); the
# hazard hue matches the grunt silhouette default (#FF3D5A = HudPalette.HAZARD). The SHAPE + inversion
# carry the read (a 6-point downward chevron vs the grunt's 3-point downward triangle) — D16/UX color-
# safety: never hue-alone (the distinct silhouette is the load-bearing CVD defense). Stored as a const
# Array of Vector2 (a PackedVector2Array isn't a constant expression in GDScript); built into a
# PackedVector2Array at use time in apply_turned_visual.
const _TURNED_SHIP_POINTS := [
	Vector2(0, -17), Vector2(-15, 10), Vector2(-8, 14),
	Vector2(0, 10), Vector2(8, 14), Vector2(15, 10),
]
const _TURNED_HAZARD_COLOR := Color(1.0, 0.24, 0.35, 1.0)

signal died(score_value: int)  # direct local signal (D8) — the spawner connects it directly.

@onready var _health: HealthComponent = $HealthComponent
@onready var _faction: FactionComponent = $FactionComponent
@onready var _state_machine: StateMachine = $StateMachine
@onready var _fire: EnemyFireSystem = $EnemyFireSystem
@onready var _muzzle: Marker2D = $Muzzle
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Polygon2D = $Visual
# Story 1.7 — OPTIONAL on-enemy HP bar (Shielder/Bomber only; grunts have no HealthBar child ⇒ null).
# get_node_or_null so the shared base script tolerates scenes that omit it.
@onready var _health_bar: HealthBar = get_node_or_null("HealthBar")
@onready var _enter_state: State = $StateMachine/EnterState
@onready var _formation_state: State = $StateMachine/FormationState
@onready var _dive_state: State = $StateMachine/DiveState
@onready var _sweep_state: State = $StateMachine/SweepState

# Per-spawn state (set in activate, read by the AI states via the owner reference).
var formation_def: FormationDefinition
var slot_index: int = 0
var rng: RandomNumberGenerator
var slot_world_pos: Vector2
var player_target: Node2D  # injected by the spawner; DiveState reads .global_position.x on each physics frame.
# Story 2.3 — the scene's base silhouette polygon, cached once in _ready. activate() restores it via
# _reset_visual() so a prior spawn's apply_turned_visual (the failed-rescue turned-ship) can't leak
# across pool cycles (pooled nodes re-init via activate, never _ready).
var _base_polygon: PackedVector2Array


func _ready() -> void:
	# One-time setup (pool contract: runs ONCE, never re-fires for re-acquired nodes).
	assert(definition != null, "Enemy: definition not assigned")
	# collision_layer from FactionComponent (single source of truth; LAYER_ENEMY — what the
	# player's HurtboxComponent detects for contact damage). mask 0 — no physical collision
	# (exact-tracking; Key Decision #1 MOVEMENT half). See decision-log [Contact-damage].
	collision_layer = _faction.get_collision_layer()  # LAYER_ENEMY
	collision_mask = 0
	# CircleShape2D radius from EnemyDefinition (data-driven). duplicate() so per-variant
	# radii never race on a shared inherited shape resource.
	var shape := _collision_shape.shape as CircleShape2D
	if shape != null:
		var dup := shape.duplicate() as CircleShape2D
		dup.radius = definition.collision_radius
		_collision_shape.shape = dup
	# Visual size from EnemyDefinition.silhouette_scale (data-driven, separate from the hitbox
	# so visual size and collision can be tuned independently for fairness).
	if _visual != null:
		_visual.scale = Vector2.ONE * definition.silhouette_scale
		_visual.color = definition.silhouette_color
		# Story 2.3 — cache the scene's base silhouette so activate()'s _reset_visual() can restore it
		# (a prior spawn's apply_turned_visual must not leak across pool cycles). Cached once (first
		# acquire); _ready does not re-fire on re-acquire, so this persists correctly.
		_base_polygon = _visual.polygon
	# The Muzzle is a scene-fixed Marker2D (sibling of Visual), so it does NOT follow
	# silhouette_scale — scale its offset to match, or big enemies fire from inside themselves.
	if _muzzle != null:
		_muzzle.position *= definition.silhouette_scale
	# Connect death ONCE (persists across pool cycles — NEVER reconnect in activate).
	if not _health.died.is_connected(_on_died):
		_health.died.connect(_on_died)
	# Wire the fire system's world-space projectile container to our parent (the spawner's
	# enemy container) — transform independence (D8/Decision #8). Stable across re-acquire:
	# the spawner always parents us to the same container.
	if _fire != null and _fire.projectile_parent == null:
		_fire.projectile_parent = get_parent()


func activate(p_formation_def: FormationDefinition, p_slot_index: int, p_rng: RandomNumberGenerator) -> void:
	# Pool re-init entry (AR6). ALL per-spawn state lives here — never in _ready.
	formation_def = p_formation_def
	slot_index = p_slot_index
	rng = p_rng
	assert(formation_def != null, "Enemy: activate without formation_def")
	assert(slot_index >= 0 and slot_index < formation_def.slots.size(), "Enemy: slot_index out of range")
	slot_world_pos = formation_def.slots[slot_index]
	# Jitter (review fix): the drip model has no on-screen concurrency cap, so a later pulse can
	# reuse a slot still held by a living enemy from an earlier pulse. A small random offset keeps
	# co-occupants from exactly overlapping without imposing a hard slot cap.
	if rng != null:
		slot_world_pos += Vector2(
			rng.randf_range(-_SLOT_JITTER_PX, _SLOT_JITTER_PX),
			rng.randf_range(-_SLOT_JITTER_PX, _SLOT_JITTER_PX)
		)
	# HP wiring (Dev Notes §"HP wiring"): max_hp is per-EnemyDefinition; restore per spawn.
	_health.max_hp = definition.max_hp
	_health.reset_to_full()
	# Fire disarmed until FormationState arms it (never fire during Enter).
	if _fire != null:
		_fire.arm(definition, rng, false)
	visible = true
	# Story 1.7 — re-bind the on-enemy HP bar each spawn (Shielder/Bomber only; grunts have no
	# HealthBar child ⇒ _health_bar is null). bind() is idempotent (guarded connect) + re-syncs the
	# segments from the just-reset_to_full() HP. hide_when_full (set on the enemy scenes) hides it
	# until the enemy is damaged (UX H6).
	if _health_bar != null:
		_health_bar.bind(_health)
	# Story 2.3 — restore the base silhouette: a prior spawn's apply_turned_visual (the failed-rescue
	# turned-ship) must NOT leak across pool cycles (pooled nodes re-init via activate, never _ready).
	_reset_visual()
	# Reset the StateMachine to EnterState — re-entry exits whatever state we were in at
	# release (e.g. DiveState) and enters EnterState with the fresh per-spawn data above.
	_state_machine.transition_to(_enter_state)


func activate_at(spawn_pos: Vector2, p_rng: RandomNumberGenerator) -> void:
	# Story 2.3 — position-based activate variant for the failed-rescue "+1 enemy" (the captured ship
	# turned hostile spawns at the captor's death position mid-wave — no formation slot). Same setup as
	# activate() (HP, fire disarm, visible) but: formation_def = the standard formation (via the
	# ContentRegistry — the states read it for drift/hold/dive params + tolerate a real def cleanly),
	# slot_world_pos = spawn_pos (the drift anchor), and it transitions DIRECTLY to FormationState (the
	# enemy appears AT the position — no off-screen EnterState descend for a mid-wave appearance). The
	# full grunt lifecycle (formation drift → fire → dive) reuses unchanged; slot_index is unused by the
	# states (they read slot_world_pos + formation_def), so it stays default. apply_turned_visual() is
	# called by the spawner AFTER this to swap the silhouette (E).
	rng = p_rng
	formation_def = ContentRegistry.get_formation_def(&"standard")
	# review fix: assert parity with activate() — a missing/misregistered "standard" FormationDefinition
	# is a genuine content-config error (ContentRegistry logs it), not a state this enemy can run in.
	assert(formation_def != null, "Enemy: activate_at without a registered 'standard' FormationDefinition")
	slot_world_pos = spawn_pos
	# One-time spawn positioning (AR14; mirrors Captor.activate): FormationState reads slot_world_pos
	# as the drift ANCHOR but never sets the initial position (EnterState does that for the normal path),
	# so a mid-wave spawn must place itself at spawn_pos directly — the enemy appears AT the captor's
	# death position immediately (no off-screen descend).
	global_position = spawn_pos
	_health.max_hp = definition.max_hp
	_health.reset_to_full()
	if _fire != null:
		_fire.arm(definition, rng, false)  # disarmed — FormationState.enter arms it on the next transition.
	visible = true
	if _health_bar != null:
		_health_bar.bind(_health)
	_state_machine.transition_to(_formation_state)


func apply_turned_visual() -> void:
	# Story 2.3 / E — the failed-rescue enemy: a captured ship turned hostile. Swap the grunt silhouette
	# for the player-ship arrowhead INVERTED (pointing down) + the hazard hue. Behavior/stats are
	# unchanged (still a grunt — same HP, fire, dive). The Visual is the Polygon2D (_visual) set up in
	# _ready from definition.silhouette_*; override the polygon points + y-flip + color here. Called by
	# FormationSpawner.spawn_enemy_at AFTER activate_at. activate()'s _reset_visual() inverts this on the
	# next normal formation spawn (pool-reuse safety). Collision/faction stay grunt (LAYER_ENEMY via
	# FactionComponent); the change is cosmetic.
	if _visual == null:
		return
	_visual.polygon = PackedVector2Array(_TURNED_SHIP_POINTS)
	# Preserve the definition's x-scale (grunt = 1.0); invert y → the upward arrowhead points down.
	var sx: float = definition.silhouette_scale if definition != null else 1.0
	_visual.scale = Vector2(sx, -sx)
	_visual.color = _TURNED_HAZARD_COLOR


func _reset_visual() -> void:
	# Restore the base silhouette (polygon + scale + color) — the inverse of apply_turned_visual. Called
	# in activate() so a prior failed-rescue spawn's turned-ship look can't leak onto a normal grunt
	# (pooled nodes re-init via activate, never _ready; _ready cached the base polygon once).
	if _visual == null:
		return
	_visual.polygon = _base_polygon
	var sx: float = definition.silhouette_scale if definition != null else 1.0
	_visual.scale = Vector2.ONE * sx
	if definition != null:
		_visual.color = definition.silhouette_color


# --- state-transition + fire helpers (called by the AI states via the owner reference) ---

func to_enter() -> void:
	# Re-enter from the top (the Galaga dive→return loop). EnterState re-positions at the entry
	# curve start and flies back to the slot.
	_state_machine.transition_to(_enter_state)


func to_formation() -> void:
	_state_machine.transition_to(_formation_state)


func to_dive() -> void:
	_state_machine.transition_to(_dive_state)


func to_sweep() -> void:
	_state_machine.transition_to(_sweep_state)


func arm_fire() -> void:
	if _fire != null:
		_fire.arm(definition, rng, true)


func disarm_fire() -> void:
	if _fire != null:
		_fire.arm(definition, rng, false)


func arm_sweep_fire() -> void:
	# SweepState: arm fire in SWEEP mode (tight sweep_fire_interval_s cadence — a dense raking
	# stream while strafing). See decision-log [Sweep-state].
	if _fire != null:
		_fire.arm(definition, rng, true, true)


func despawn() -> void:
	# Wave-end collection (Task 5.2, review fix) — a survivor is collected, not killed: no score,
	# no `died` signal. Called from a non-physics context (spawner's _physics_process, but not
	# from within a body_entered callback), so a synchronous release is safe here.
	Pool.release(self)


func _on_died() -> void:
	# Death originates in a physics callback (player projectile's body_entered → take_damage
	# → died.emit), so the release is deferred (engine forbids synchronous removal then).
	# Emits the local died signal carrying score_value (D8); the spawner accumulates score.
	died.emit(definition.score_value)
	# Death juice (Story 1.6 / AC1) — emit BEFORE the deferred release, capturing global_position
	# NOW (the node is still valid this frame; the emit is synchronous). Kill ≠ despawn: this fires
	# on REAL death ONLY — despawn() (wave-end survivor cleanup) emits NO juice. The explosion
	# particle is a separate pooled node that persists after this enemy returns to the pool.
	JuiceFx.enemy_killed(global_position, definition.silhouette_color, definition.silhouette_scale, definition.score_value)
	# Defer a NO-ARG method on self rather than `Pool.release.call_deferred(self)`: Godot 4.6
	# fails to marshal a CharacterBody2D (PhysicsBody2D) as a typed deferred argument
	# ("Cannot convert argument 1 from Object to Object"). Deferring a parameterless method
	# sidesteps the arg conversion; it runs at idle (outside the physics callback) and
	# releases synchronously. The Area2D projectile's `Pool.release.call_deferred(self)` is
	# unaffected — this is specific to PhysicsBody2D args.
	_release_to_pool.call_deferred()


func _release_to_pool() -> void:
	Pool.release(self)
