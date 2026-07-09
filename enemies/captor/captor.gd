class_name Captor
extends CharacterBody2D
# Pooled tractor-beam enemy (Story 2.1) — its OWN entity, NOT a variant of enemy.tscn. The captor's
# 5 states (Enter→Formation→Telegraph→Capture→Dive) are captor-specific (formation→telegraph, not
# dive), and Enemy.activate() is hard-coupled to FormationDefinition+slot, which the captor does not
# use. So the captor composes the SAME reusable components (HealthComponent / FactionComponent /
# the shared StateMachine / EnemyFireSystem) itself, and reproduces the ~5-line death/pool/juice
# pattern from enemy.gd — without subclassing Enemy (which would inherit 4 unused states + a
# formation-coupled activate). Architecture mandates enemies/captor/ with its own states/.
#
# Holds TWO data resources (Dev Notes key decision #2): `definition` (EnemyDefinition — base combat
# stats; required by EnemyFireSystem.arm() + HealthComponent) + `tuning` (CaptorTuning — the 5 FSM
# durations + captor geometry). AC#5: ALL timings read from captor_tuning.tres, never code.
#
# Movement is driven by the reusable StateMachine child (the states set velocity + move_and_slide).
# This script does NOT define its own _physics_process — the StateMachine owns the tick (avoids
# double move_and_slide + parent/child processing-order hazards; matches enemy.gd).
#
# Pool contract (AR6/D7): _ready is ONE-TIME setup; activate() is the pool re-init entry. The
# spawner calls acquire → add_child → activate so @onready refs are valid in activate.

@export var definition: EnemyDefinition     # = resources/enemies/enemy_captor.tres (set in scene)
@export var tuning: CaptorTuning            # = resources/captor_tuning.tres (set in scene — wins at runtime)
@export var capture_column_scene: PackedScene  # = world/capture_column.tscn (acquired on telegraph)

signal died(score_value: int)               # direct/local (D8) — score_value = 0 (captor score is "—"). Seam for 2.3.
signal state_changed(state: StringName)     # direct/local (D8) — emitted on every transition; 2.3's rescue branch reads it.

@onready var _health: HealthComponent = $HealthComponent
@onready var _faction: FactionComponent = $FactionComponent
@onready var _state_machine: StateMachine = $StateMachine
@onready var _fire: EnemyFireSystem = $EnemyFireSystem
@onready var _muzzle: Marker2D = $Muzzle
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Polygon2D = $Visual
# HealthBar is OPTIONAL on the captor (2.1 omits it; get_node_or_null tolerates its absence).
@onready var _health_bar: HealthBar = get_node_or_null("HealthBar")
@onready var _enter_state: State = $StateMachine/EnterState
@onready var _formation_state: State = $StateMachine/FormationState
@onready var _telegraph_state: State = $StateMachine/TelegraphState
@onready var _capture_state: State = $StateMachine/CaptureState
@onready var _dive_state: State = $StateMachine/DiveState

# Per-spawn state (set in activate, read by the captor states via the owner reference).
var player_target: Node2D               # injected by the spawner; TelegraphState/DiveState read .global_position.
var rng: RandomNumberGenerator          # injected; FormationState rolls the randomized hold.
var current_state_name: StringName      # updated on each transition — 2.3's death handler reads this (dive → rescue).
var capture_column: CaptureColumn       # held during telegraph+capture; null otherwise.


func _ready() -> void:
	# One-time setup (pool contract: runs ONCE, never re-fires for re-acquired nodes).
	assert(definition != null, "Captor: definition not assigned")
	assert(tuning != null, "Captor: tuning not assigned")
	# collision_layer from FactionComponent (single source of truth; LAYER_ENEMY — what the player's
	# HurtboxComponent detects for contact damage, mirroring the grunt). mask 0 — no physical collision
	# (exact-tracking; same as Enemy — Key Decision #1 MOVEMENT half).
	collision_layer = _faction.get_collision_layer()
	collision_mask = 0
	# CircleShape2D radius from EnemyDefinition (data-driven). duplicate() so a per-variant radius never
	# races on a shared inherited shape resource.
	var shape := _collision_shape.shape as CircleShape2D
	if shape != null:
		var dup := shape.duplicate() as CircleShape2D
		dup.radius = definition.collision_radius
		_collision_shape.shape = dup
	# Visual size + color from EnemyDefinition (data-driven; the distinct captor silhouette/hue).
	if _visual != null:
		_visual.scale = Vector2.ONE * definition.silhouette_scale
		_visual.color = definition.silhouette_color
	# Muzzle is a scene-fixed Marker2D (sibling of Visual) — scale its offset so a big captor doesn't
	# fire from inside itself.
	if _muzzle != null:
		_muzzle.position *= definition.silhouette_scale
	# Connect death ONCE (persists across pool cycles — NEVER reconnect in activate).
	if not _health.died.is_connected(_on_died):
		_health.died.connect(_on_died)
	# Wire the fire system's world-space projectile container to our parent (the spawner's enemy
	# container) — transform independence (D8). Stable across re-acquire (the spawner re-parents us
	# to the same container each cycle).
	if _fire != null and _fire.projectile_parent == null:
		_fire.projectile_parent = get_parent()
	# Re-bind an on-enemy HP bar each spawn IF the scene has one (2.1's captor.tscn omits it ⇒ null).
	if _health_bar != null:
		_health_bar.bind(_health)


func activate(p_player_target: Node2D, p_spawn_pos: Vector2, p_rng: RandomNumberGenerator) -> void:
	# Pool re-init entry (AR6). ALL per-spawn state lives here — never in _ready.
	player_target = p_player_target
	rng = p_rng
	assert(definition != null, "Captor: activate without definition")
	assert(tuning != null, "Captor: activate without tuning")
	# Defensive: if the prior cycle was interrupted (e.g. wave-end despawn mid-telegraph left a column
	# held), release it so a re-acquired captor never starts holding a stale column.
	_release_capture_column()
	# Spawn placement (one-time — AR14 allows one-time spawn positioning, not per-frame .position writes).
	# The debug cheat spawns the captor off-screen above the player; EnterState descends from here.
	global_position = p_spawn_pos
	# HP wiring: max_hp is per-EnemyDefinition; restore per spawn.
	_health.max_hp = definition.max_hp
	_health.reset_to_full()
	# Fire disarmed until FormationState arms it (the captor NEVER fires during enter/telegraph/capture/dive-
	# during-telegraph the threat is the COLUMN, not bullets; dive disarms too via fires_during_dive=false).
	if _fire != null:
		_fire.arm(definition, rng, false)
	visible = true
	# Re-bind the on-enemy HP bar each spawn if present (idempotent; re-syncs from the just-reset HP).
	if _health_bar != null:
		_health_bar.bind(_health)
	# Reset the StateMachine to EnterState — the FSM reset on respawn (pool contract). Sets
	# current_state_name + emits "enter" (the first state_changed of this spawn).
	to_enter()


# --- state-transition helpers (called by the captor states via the owner reference) ---
# Each sets current_state_name + emits state_changed AFTER the transition, so current_state_name is
# always authoritative (load-bearing for 2.3's dive-vs-formation rescue branch) and state_changed
# emits a clean ordered sequence (enter → formation → telegraph → capture → dive).

func to_enter() -> void:
	_transition_to(_enter_state, &"enter")


func to_formation() -> void:
	_transition_to(_formation_state, &"formation")


func to_telegraph() -> void:
	_transition_to(_telegraph_state, &"telegraph")


func to_capture() -> void:
	_transition_to(_capture_state, &"capture")


func to_dive() -> void:
	_transition_to(_dive_state, &"dive")


func _transition_to(target: State, state_name: StringName) -> void:
	_state_machine.transition_to(target)
	current_state_name = state_name
	state_changed.emit(state_name)


func arm_fire() -> void:
	# FormationState arms fire on enter (delegate to the fire system, same idiom as Enemy).
	if _fire != null:
		_fire.arm(definition, rng, true)


func disarm_fire() -> void:
	# Enter/Telegraph/Capture/Dive disarm fire (the threat in telegraph/capture is the COLUMN).
	if _fire != null:
		_fire.arm(definition, rng, false)


func despawn() -> void:
	# Wave-end collection (mirror Enemy.despawn). A survivor captor is collected, not killed: no score,
	# no `died` signal. Called from a non-physics context (spawner's _despawn_survivors via stop()), so a
	# synchronous self-release is safe. Drop any held capture column first so it doesn't linger.
	_release_capture_column()
	Pool.release(self)


# --- capture-column lifecycle (the captor owns the column it locks) ---

func _acquire_capture_column(locked_x: float) -> void:
	# TelegraphState.enter: acquire a pooled CaptureColumn, parent it to our container (world-space,
	# NOT under the captor — a sibling so the captor's motion never drags the locked column), and
	# activate it at the locked x. acquire → add_child → activate (so the column's @onready refs are
	# valid in activate — the established pool order).
	if capture_column_scene == null:
		return
	var column: CaptureColumn = Pool.acquire(capture_column_scene) as CaptureColumn
	assert(column != null, "Captor: acquired node is not a CaptureColumn — wrong scene?")
	get_parent().add_child(column)
	# Geometry from tuning (AC#5) — set BEFORE activate so activate()'s bar layout uses it.
	column.width_px = tuning.capture_column_width_px
	column.activate(locked_x)
	capture_column = column


func _release_capture_column() -> void:
	# Telegraph→capture→dive hands off; dive-enter, death, and despawn all release the held column.
	# Idempotent (no-op if not holding one). The column is hidden immediately (deactivate) so it
	# vanishes the frame dive/death starts; the pool return is DEFERRED via the column's no-arg
	# _release_to_pool (Godot 4.6 can't marshal a typed Node arg through call_deferred — affects
	# Node2D too, not just PhysicsBody2D; the no-arg method sidesteps it, same as our own release).
	if capture_column == null:
		return
	var column: CaptureColumn = capture_column
	capture_column = null
	column.deactivate()
	column._release_to_pool.call_deferred()


func _on_died() -> void:
	# Death originates in a physics callback (player projectile body_entered → take_damage → died.emit),
	# so the captor's self-release is deferred (engine forbids synchronous removal then) — exactly as
	# enemy.gd. Emits the local died signal carrying score_value = 0 (D8; the spawner's _on_captor_died
	# seam routes nothing to the HUD in 2.1). Release any held column BEFORE the deferred self-release
	# so a telegraph/capture kill doesn't leave the column locked on-screen. Death juice (explosion +
	# score popup) emits BEFORE the release, capturing global_position now.
	died.emit(definition.score_value)
	_release_capture_column()
	JuiceFx.enemy_killed(global_position, definition.silhouette_color, definition.silhouette_scale, definition.score_value)
	# Defer a NO-ARG method on self rather than `Pool.release.call_deferred(self)`: Godot 4.6 fails to
	# marshal a CharacterBody2D (PhysicsBody2D) as a typed deferred arg. Same workaround as enemy.gd.
	_release_to_pool.call_deferred()


func _release_to_pool() -> void:
	Pool.release(self)
