class_name Enemy
extends CharacterBody2D
# Pooled Grunt/Shielder/Bomber enemy (1.4). CharacterBody2D with collision_mask = 0 (Key
# Decision #1): the existing player-projectile body_entered hit path works UNCHANGED
# (Story 1.3); damage flows only via projectiles, never body contact. Movement is driven
# by the reusable StateMachine child (Enter/Formation/Dive states set velocity + call
# move_and_slide). This script does NOT define its own _physics_process — the StateMachine
# owns the tick (avoids double move_and_slide + parent/child processing-order hazards).
#
# Pool contract (AR6/D7): _ready is ONE-TIME setup; activate() is the pool re-init entry.
# The spawner calls acquire → add_child → activate so @onready refs are valid in activate.

@export var definition: EnemyDefinition

const _SLOT_JITTER_PX: float = 14.0  # review fix: prevents exact-overlap when a slot is reused
                                      # by a later pulse while the prior occupant is still alive.

signal died(score_value: int)  # direct local signal (D8) — the spawner connects it directly.

@onready var _health: HealthComponent = $HealthComponent
@onready var _faction: FactionComponent = $FactionComponent
@onready var _state_machine: StateMachine = $StateMachine
@onready var _fire: EnemyFireSystem = $EnemyFireSystem
@onready var _muzzle: Marker2D = $Muzzle
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Polygon2D = $Visual
@onready var _enter_state: State = $StateMachine/EnterState
@onready var _formation_state: State = $StateMachine/FormationState
@onready var _dive_state: State = $StateMachine/DiveState

# Per-spawn state (set in activate, read by the AI states via the owner reference).
var formation_def: FormationDefinition
var slot_index: int = 0
var rng: RandomNumberGenerator
var slot_world_pos: Vector2
var player_target: Node2D  # injected by the spawner; DiveState reads .global_position.x once.


func _ready() -> void:
	# One-time setup (pool contract: runs ONCE, never re-fires for re-acquired nodes).
	assert(definition != null, "Enemy: definition not assigned")
	# collision_layer from FactionComponent (single source of truth); mask 0 — no physical
	# collision (Key Decision #1). Damage is projectile-only in 1.4.
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
	# Reset the StateMachine to EnterState — re-entry exits whatever state we were in at
	# release (e.g. DiveState) and enters EnterState with the fresh per-spawn data above.
	_state_machine.transition_to(_enter_state)


# --- state-transition + fire helpers (called by the AI states via the owner reference) ---

func to_enter() -> void:
	# Re-enter from the top (the Galaga dive→return loop). EnterState re-positions at the entry
	# curve start and flies back to the slot.
	_state_machine.transition_to(_enter_state)


func to_formation() -> void:
	_state_machine.transition_to(_formation_state)


func to_dive() -> void:
	_state_machine.transition_to(_dive_state)


func arm_fire() -> void:
	if _fire != null:
		_fire.arm(definition, rng, true)


func disarm_fire() -> void:
	if _fire != null:
		_fire.arm(definition, rng, false)


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
	JuiceFx.enemy_killed(global_position, definition.silhouette_color, definition.silhouette_scale)
	# Defer a NO-ARG method on self rather than `Pool.release.call_deferred(self)`: Godot 4.6
	# fails to marshal a CharacterBody2D (PhysicsBody2D) as a typed deferred argument
	# ("Cannot convert argument 1 from Object to Object"). Deferring a parameterless method
	# sidesteps the arg conversion; it runs at idle (outside the physics callback) and
	# releases synchronously. The Area2D projectile's `Pool.release.call_deferred(self)` is
	# unaffected — this is specific to PhysicsBody2D args.
	_release_to_pool.call_deferred()


func _release_to_pool() -> void:
	Pool.release(self)
