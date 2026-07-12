class_name Player
extends CharacterBody2D
# 1-axis chassis: horizontal-only, screen-clamped movement on the bottom lane.
# Velocity + move_and_slide() (fixed-timestep _physics_process) is the PRIMARY
# driver; the post-move clampf only corrects edge escape (no physical walls).
#
# Per-ship mechanics (WAVE scope — Story 1.5): the player owns HP, i-frames, and the
# ship_depleted signal (intra-entity→parent, D8). Run-scope decisions (ship count,
# game-over) live on Arena — the player never touches RunState (AR2). Movement and
# ship_depleted both stay LOCAL — the player emits nothing to EventBus directly.

@export var tuning: PlayerTuning
# Story 2.3 — the rescue dock. docked_ship_scene mirrors FireSystem.projectile_scene (D9: the scene
# is wired in player.tscn, NEVER preload/load in gameplay code); docked_ship_tuning holds the +hitbox
# radius + the dock color (the .tres wins at runtime, D9).
@export var docked_ship_scene: PackedScene
@export var docked_ship_tuning: DockedShipTuning

@onready var _health: HealthComponent = $HealthComponent
@onready var _faction: FactionComponent = $FactionComponent
@onready var _fire_system: FireSystem = $FireSystem
@onready var _muzzle: Marker2D = $Muzzle
@onready var _visual: Node2D = $Visual
@onready var _health_bar: HealthBar = $HealthBar
# Story 2.3 — the player's two collision shapes (the body CollisionShape2D that projectiles body_enter
# + the HurtboxComponent's shape that enemy-body contact enters). The +hitbox (AC#3) grows BOTH when
# docked: swap the radius between the clean base (11) and the docked radius (DockedShipTuning).
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _hurtbox_shape: CollisionShape2D = $HurtboxComponent/CollisionShape2D

# The player.tscn base hitbox radius (keep in sync with the scene's CircleShape2D). The +hitbox swaps
# to DockedShipTuning.docked_hitbox_radius when docked, back to this when clean.
const _CLEAN_HITBOX_RADIUS: float = 11.0

# Player → Arena: "I lost a ship (HP hit 0 within the wave)." NO payload — the run host
# owns the count and decides respawn vs game-over (D8: intra-entity→parent, direct).
signal ship_depleted()

var _min_x: float = 0.0
var _max_x: float = 0.0
var _flicker_t: float = 0.0  # i-frame pulse phase (sustained invuln cue; the impact flash is JuiceCoordinator-driven)
var _captured_this_wave := false  # wave-scope capture gate (AC#3, Story 2.2); reset on wave_started.
# Story 2.3 — the docked wingman state. _docked is the capture-immune flag (FR16); _docked_ship is the
# transient visual node (NP1, NOT pooled). At most one docked ship per wave (FR14); capture is also
# once-per-wave, so try_dock_ship's "already docked" guard is defensive.
var _docked_ship: DockedShip = null
var _docked := false


func _ready() -> void:
	assert(tuning != null, "Player: tuning not assigned")
	# Dev-invariant (AR12): the ship's HP cap must never exceed Constants.MAX_HP (grows
	# via build in E3, always 3 in E1). Scoped to the player only — HealthComponent is
	# shared with enemies, whose max_hp values are unrelated to the player's run-wide cap.
	assert(_health.max_hp <= Constants.MAX_HP, "Player: max_hp exceeds Constants.MAX_HP cap")
	# FactionComponent is the single source of truth for the collision-layer bit (AR5).
	collision_layer = _faction.get_collision_layer()
	# Compute + cache bounds once (hot-path: no per-frame work in _physics_process).
	_min_x = tuning.edge_margin
	_max_x = float(Constants.BASE_RESOLUTION.x) - tuning.edge_margin
	assert(_min_x <= _max_x, "Player: edge_margin leaves no room to move")
	global_position = Vector2(Constants.BASE_RESOLUTION.x / 2.0, tuning.lane_y)
	# Muzzle position is tuning-driven, not the scene's hardcoded default (the .tscn
	# value is just an editor preview) — this is the one-time (not per-frame) spawn
	# math that makes muzzle_offset_y an actual playtest lever (AR10).
	_muzzle.position.y = tuning.muzzle_offset_y
	# i-frame gate (Story 1.5 / AC2): the HealthComponent is the damage gate, so the
	# window lives there; the player just feeds its tuning value (GDD 108: 1 s after a
	# hit). Default 0.0 on the component keeps enemies i-frame-free — the player opts in.
	_health.invuln_after_hit_s = tuning.iframe_s
	# Connect HP=0 (within a wave) → ship_depleted ONCE (the player is NOT pooled, so no
	# re-connect concern across the run). died is a LOCAL HealthComponent signal (D8).
	if not _health.died.is_connected(_on_ship_depleted):
		_health.died.connect(_on_ship_depleted)
	# Story 2.2 — reset the per-wave capture gate when a new wave begins. Read-only LISTEN: the player
	# still EMITS nothing to the bus (ship_depleted stays local, D8). wave_started fires at Intro→Active
	# (WaveController), before any captor in that wave can capture. The player is NOT pooled → connect ONCE.
	if not EventBus.wave_started.is_connected(_on_wave_started):
		EventBus.wave_started.connect(_on_wave_started)
	# Story 2.3 — wave-end cleanup of the docked fighter (wave-scope, NP1). Read-only LISTEN: the player
	# still EMITS nothing to the bus (ship_depleted stays local, D8). The Keep outcome (regain a ship on
	# surviving the wave docked) is Story 2.5 — 2.3 just detaches so the fighter doesn't persist across
	# the wave boundary. The player is NOT pooled → connect ONCE.
	if not EventBus.wave_cleared.is_connected(_on_wave_cleared):
		EventBus.wave_cleared.connect(_on_wave_cleared)
	# Story 1.7 — bind the on-ship segmented HP bar to this entity's own HealthComponent (intra-entity,
	# D8 — HP is never on EventBus). hide_when_full=false here ⇒ the primary read is always visible.
	if _health_bar != null:
		_health_bar.bind(_health)
	# Wire FireSystem's world-space projectile container to our parent (the Arena).
	# Projectiles parent there — NOT under the Player — so they don't inherit the
	# ship's transform (Decision #8). FireSystem._ready ran before ours (children
	# first), but projectile_parent is read only on fire, never in FireSystem._ready,
	# so there is no race. The Player wires its own component (intra-entity, D8-clean).
	if _fire_system != null and _fire_system.projectile_parent == null:
		_fire_system.projectile_parent = get_parent()


func _process(delta: float) -> void:
	# Sustained i-frame VISIBILITY cue (Story 1.6 refined — the 1.5 sin-flicker placeholder is
	# retired). The IMPACT hit-flash on a damaging hit is driven by the JuiceCoordinator (it tweens
	# the player BODY's modulate via the enemy_projectile juice emit); this is the calmer, ongoing
	# alpha pulse that signals "invulnerable" across the whole window. ~1.9 Hz — well under the 3 Hz
	# photosensitive cap (which governs hit_flash_requested anyway, not this sustained modulation).
	# One cheap line while invulnerable; restores fully opaque when vulnerable (NFR2/AR14).
	if _health.is_invulnerable():
		_flicker_t += delta
		_visual.modulate.a = 0.55 + 0.35 * sin(_flicker_t * 12.0)
	else:
		_visual.modulate.a = 1.0


func _on_ship_depleted() -> void:
	# HP reached 0 within the wave → tell the run host. The Arena decides respawn vs
	# game-over (AR2: ships are run-scope). Player never calls RunState directly.
	ship_depleted.emit()


func is_capture_immune() -> bool:
	# Story 2.3 — retired the 2.2 stub. Docked ⇒ capture-immune (FR16). The guard is real + wired to the
	# docked state (try_capture checks it). Story 2.4 formalized set_docked as the [Risk-12] clean/docked
	# tradeoff (capture-immunity + a bigger hitbox = the self-balancing cost of the dual fighter). The
	# wing_track is NOT persisted here — the Player owns only the TRANSIENT combat side; the PERMANENT
	# track lives on RunState.BuildState, written by the Arena (AR2 — the Player never touches RunState).
	return _docked


func is_docked() -> bool:
	# Story 2.3 — public read accessor. The FireSystem reads this to spawn the parallel bullet stream
	# (AC#3 +firepower); Arena/JuiceFx may read it too. Mirrors is_capture_immune (both reflect _docked).
	return _docked


func set_docked(on: bool) -> void:
	# The architecture-named write-side (architecture.md:616 `set_docked(true) # capture-immune + bigger
	# hitbox`). Flips _docked (capture-immune via is_capture_immune) AND grows/shrinks the player's hitbox
	# (the +hitbox) — together the [Risk-12] clean/docked tradeoff: the dual fighter's combat perks cost a
	# bigger target (self-balancing). Story 2.4 formalized this; the wing_track is NOT touched here (the
	# Player owns only the transient combat side — the PERMANENT track is Arena-owned, AR2). Called by
	# try_dock_ship / _consume_docked_ship / _on_wave_cleared.
	_docked = on
	_resize_hitbox(on)


func _resize_hitbox(docked: bool) -> void:
	# The +hitbox (AC#3 / [Risk-12] — the self-balancing cost of the dual fighter): the player's hitbox
	# grows when docked (a bigger target — the docked ship makes you easier to hit). Story 2.4 formalized
	# this clean(11)↔docked(18) tradeoff. Swap the body CollisionShape2D (projectiles body_enter this) +
	# the HurtboxComponent's CollisionShape2D (enemy-body contact) between the clean radius (11) and the
	# docked radius (DockedShipTuning). collision_mask = 0 ⇒ growing the body shape only affects what
	# body_enters it (projectiles) — NO move_and_slide / physics impact.
	var radius: float = _CLEAN_HITBOX_RADIUS
	if docked and docked_ship_tuning != null:
		radius = docked_ship_tuning.docked_hitbox_radius
	_swap_circle_radius(_collision_shape, radius)
	_swap_circle_radius(_hurtbox_shape, radius)


func _swap_circle_radius(shape_node: CollisionShape2D, radius: float) -> void:
	# duplicate() the shared CircleShape2D before resizing (captor.gd:62-66 idiom — a per-instance radius
	# must NEVER mutate the shared inherited shape resource in place, or every instance resizes at once).
	# set_deferred on the shape: set_docked() (dock + undock) can run inside a physics callback — dock via
	# Arena._on_captor_resolved (captor death originates in body_entered), undock via apply_hit's absorber
	# (enemy contact body_entered). Assigning CollisionShape2D.shape mid-physics-step is forbidden
	# ("Can't change this state while flushing queries"); set_deferred applies it safely at idle. The dock
	# grow + the absorber shrink are both one-time per state change (NOT per frame).
	if shape_node == null:
		return
	var shape := shape_node.shape as CircleShape2D
	if shape == null:
		return
	var dup := shape.duplicate() as CircleShape2D
	dup.radius = radius
	shape_node.set_deferred("shape", dup)


func try_dock_ship() -> bool:
	# The rescue EFFECT entry (AC#1, mirrors 2.2 try_capture). Guards: no existing docked ship (FR14
	# one-docked — a second rescue/dock cannot occur; capture is once-per-wave so this is defensive).
	# On success: instantiate + attach the DockedShip, set_docked(true) (which grows the hitbox — the
	# +hitbox). Returns true so Arena/juice can gate. The player NEVER touches RunState (AR2 — rescue is
	# a combat attach, not a ship-count change; the captured ship was spent at capture in 2.2).
	if _docked_ship != null:
		return false  # FR14: at most one docked ship.
	if docked_ship_scene == null:
		push_error("Player: docked_ship_scene unassigned — rescue dock ignored")
		return false
	# NOT pooled (NP1) — once-per-wave. Child of the Player ⇒ rides the player's transform at the dock offset.
	_docked_ship = docked_ship_scene.instantiate()
	add_child(_docked_ship)  # add_child mid-physics is safe (mirrors the spawner drip); _ready fires now.
	_docked_ship.setup(self)
	_docked_ship.attach()
	set_docked(true)
	return true


func apply_hit(damage: int, impact_pos: Vector2, source: Node2D, heavy: bool = false) -> void:
	# The CENTRALIZED damage route (AC#3 absorber). Both the enemy_projectile + the HurtboxComponent call
	# this instead of HealthComponent.take_damage directly. Gate order: i-frames (full no-op, no juice) →
	# absorber (if docked, the docked ship dies first, sparing HP) → HP damage + player-hit juice.
	#
	# Runs inside the physics step (body_entered callback) — only node REMOVAL is forbidden mid-physics;
	# _consume_docked_ship defers the docked fighter's detach (remove_child + queue_free). take_damage +
	# signal emits are safe synchronous. `source` is the flash TARGET's sibling context — the player-hit
	# juice flashes the PLAYER body (self), NOT the source (fixes the old hurtbox flashing the ramming
	# enemy instead of the player — both paths now flash the player consistently).
	if _health.is_invulnerable():
		return  # i-frames: full no-op (no damage, no juice, no absorb — the docked ship is NOT consumed).
	if _docked_ship != null:
		_consume_docked_ship(impact_pos, source)  # absorber: docked ship dies, HP spared. NO spend_ship (ever).
		return
	_health.take_damage(damage)
	JuiceFx.player_hit(impact_pos, self, heavy)


func _consume_docked_ship(impact_pos: Vector2, _source: Node2D) -> void:
	# The intrinsic first-hit absorber (AC#3 / FR17). The docked fighter dies, sparing the player's HP.
	# NO spend_ship — EVER (not 2.3, not 2.5). The FR18 "Absorb = −1 ship" is relative-accounting vs the
	# Keep +1 (you forfeit the regain), NOT a spend. The docked ship is a non-counted combat asset; the
	# ONLY ship-count changes in the Gamble are capture (−1, 2.2) and keep (+1, 2.5). See Dev Notes
	# §"Ship-count economy". detach is DEFERRED (remove_child + queue_free mid-physics is forbidden — the
	# docked ship is a child of the Player, a CanvasItem; defer a no-arg method, mirroring Pool's idiom).
	# _detach_docked_ship() flips set_docked(false) + _docked_ship = null SYNCHRONOUSLY so
	# is_docked()/is_capture_immune() update immediately — a same-frame second hit lands on the player,
	# not a consumed docked ship.
	var fighter: DockedShip = _detach_docked_ship()
	# Absorb juice — the wingman bought it (a distinct "the escort took the hit" beat). Explosion in the
	# dock color + a kill shake, NO score popup (a "+0" would be noise). Emit AFTER detach but BEFORE the
	# deferred queue_free lands (fighter.global_position is still valid this frame).
	if fighter != null:
		JuiceFx.docked_consumed(fighter.global_position, docked_ship_tuning.dock_color if docked_ship_tuning != null else Color(0.0, 0.898, 1.0))


func try_capture() -> bool:
	# The captor's capture EFFECT entry (AC#1). Guards: clean (no docked ship) + once-per-wave + not
	# already dead this frame (an HP-death and a capture landing the same physics tick must not spend
	# two ships for one hit — Story 2.2 review). On success: flag consumed + emit ship_depleted →
	# Arena._on_player_ship_depleted → spend_ship → respawn (full HP via reset_to_full) | game_over.
	# Capture BYPASSES HP — HealthComponent is NEVER
	# touched (no take_damage); respawn's reset_to_full() restores full HP. Returns true so the captor
	# can gate its success-conditional dive delay (AC#5). The player never touches RunState (AR2).
	if is_capture_immune() or _captured_this_wave or _health._is_dead:
		return false
	_captured_this_wave = true
	ship_depleted.emit()  # LOCAL (D8) — reuses Arena's entire ship-loss/respawn/game-over path (AR2)
	return true


func _on_wave_started(_wave: int, _duration_s: float) -> void:
	# Read-only LISTEN (Story 2.2): reset the per-wave capture gate when a new wave begins. The player
	# still EMITS nothing to the bus (ship_depleted stays local, D8).
	_captured_this_wave = false


func _on_wave_cleared(_wave: int) -> void:
	# Story 2.3 — wave-end cleanup stub (NP1 — the docked ship is wave-scope). Detach the docked fighter
	# so it doesn't persist across the wave boundary. NO add_ship in 2.3 — the Keep outcome (survive the
	# wave docked → add_ship(+1), net 0 over capture→rescue→keep) is Story 2.5 (the ONLY add_ship in the
	# Gamble). Runs from WaveController's FSM transition (NOT a physics callback), but the detach is
	# deferred anyway for consistency with _consume_docked_ship's mid-physics-safe idiom.
	# 2.5 seam: add_ship(+1) — the Keep regain (only if the player survived the wave docked).
	_detach_docked_ship()


func _detach_docked_ship() -> DockedShip:
	# review fix: shared detach sequence for _consume_docked_ship (absorb) + _on_wave_cleared (wave-end)
	# — previously duplicated with inconsistent statement ordering between the two call sites. Flips
	# set_docked(false) + _docked_ship = null SYNCHRONOUSLY (is_docked()/is_capture_immune() must update
	# immediately); the node free is DEFERRED (remove_child + queue_free mid-physics is forbidden — the
	# docked ship is a child of the Player, a CanvasItem). Returns the detached fighter (still valid this
	# frame, e.g. for juice at its position) or null if nothing was docked.
	if _docked_ship == null:
		return null
	var fighter: DockedShip = _docked_ship
	_docked_ship = null
	set_docked(false)
	fighter.detach.call_deferred()  # no-arg deferred detach (mirrors the Pool deferred-release idiom).
	return fighter


func respawn() -> void:
	# Called by Arena when a ship is lost but ships remain. New ship, full HP, centered
	# on the lane (fair re-entry — a fire-column probably killed you where you stood),
	# and a fresh i-frame window so re-entry isn't an instant re-death. No screen-clear,
	# no loss-of-control, no fade — E1 respawn is immediate (full lifecycle is 1.8).
	_health.reset_to_full()
	global_position.x = Constants.BASE_RESOLUTION.x / 2.0
	velocity = Vector2.ZERO  # defensive: _physics_process recomputes velocity from input
	# every frame regardless, but a teleport shouldn't carry a stale pre-death velocity.
	_health.set_invuln(tuning.iframe_s)


func _physics_process(_delta: float) -> void:
	# One call covers keyboard (digital -1/0/1) AND gamepad (continuous -1..1 with
	# the per-action deadzone applied automatically) — AC3.
	var axis: float = Input.get_axis("move_left", "move_right")
	# Velocity set directly; y explicitly 0 (1-axis lock). Do NOT multiply by delta
	# — move_and_slide() applies it internally (AC2, AR14).
	velocity = Vector2(axis * tuning.move_speed, 0.0)
	move_and_slide()  # no args; Godot applies delta internally.
	# Corrective screen-clamp to the base-resolution play field (AC1, Decision #2).
	global_position.x = clampf(global_position.x, _min_x, _max_x)
