class_name FireSystem
extends Node
# Player fire component (1.3). Hold-to-autofire via a cooldown accumulator in
# _physics_process (Decision #2 — pure logic, no Timer node, fixed-timestep-
# deterministic). Acquires pooled Projectiles from Pool and activates them at the
# Muzzle; projectiles parent to the injected projectile_parent (world space, NOT
# the Player) so they don't inherit the ship's transform (Decision #8). Fire emits
# NO game-flow signal (fire is not game-flow), but DOES emit juice REQUEST signals
# (on-fire SFX + a light muzzle puff) via JuiceFx (Story 1.6) — juice requests are
# an allowed global channel (D8), distinct from game-flow events. Zero per-frame
# allocations (NFR3).

@export var tuning: PlayerTuning
@export var projectile_scene: PackedScene
# Story 2.6 (NP3) — the sacrifice-burst tuning (AR10/D9). Wired in player.tscn to
# resources/sacrifice_tuning.tres (the .tres wins at runtime). Carries the fast-fire cooldown + the
# triple-shot spread shape; the burst's damage SCALAR comes from the SacrificeBurst (threat-clamped by
# BuildRecompute). AR11 fail-safe: an unassigned tuning degrades (no fast-fire / no spread) rather than
# crashing — the assert-free read sites guard for null.
@export var sacrifice_tuning: SacrificeTuning

# Public var wired by player.gd._ready() to the Player's parent (the Arena). Public
# (not @export) so player.gd sets it directly and tests can inject a temp container.
# Projectiles parent here so they live in world space, not under the Player.
var projectile_parent: Node2D

# Muzzle is a sibling under the Player (FireSystem's parent); read once via @onready
# (never $/get_node per frame). Yields null if the Muzzle is absent (partial/test
# setup) — _spawn guards against that instead of erroring on lookup.
@onready var _muzzle: Marker2D = get_parent().get_node_or_null("Muzzle")
# Story 2.3 — the Player (FireSystem's parent). Read once via @onready. review fix: untyped Node +
# duck-call (has_method/call/get), not a hard `as Player` cast — mirrors the duck-call pattern used
# by hurtbox_component.gd/enemy_projectile.gd elsewhere in this diff (avoids hard Player coupling; a
# DockedShip-owned FireSystem refactor is deferred to Story 2.6 — NP1 seam; the player's FireSystem
# spawns both streams for now).
@onready var _player: Node = get_parent()

# FR7 / GDD weapon table — the parallel bullet stream's +28 px x-offset when docked (AC#3 +firepower).
# review fix: read from DockedShipTuning.stream_offset_x (the .tres wins, D9) instead of a separate
# hardcoded const — a single source of truth so retuning the .tres can't desync the bullet from the
# wingman's visual station. This fallback only applies if docked_ship_tuning is somehow unassigned.
const _FALLBACK_STREAM_OFFSET_X := 28.0

var _cooldown: float = 0.0
# Story 2.6 (NP3) — the active sacrifice burst (null when none). _burst_time_left is the buff-window
# countdown (delta-decremented in _physics_process). Both are a RefCounted ref + a scalar — cheap, no
# per-frame allocation. The burst is ENTITY-LOCAL (a FireSystem buff) → burst_ended is a LOCAL signal
# (D8: do NOT route buff start/expire through EventBus; the Player's on-ship ring + visual revert
# subscribe here). See Dev Notes §"🔗 Signal boundary".
var _burst: SacrificeBurst = null
var _burst_time_left: float = 0.0
# Story 2.6 — emitted on natural expiry (_expire_burst) + force-clear (clear_burst, when a burst was
# active). The Player connects this to revert its burst visual (glow/enlarge/timer ring). LOCAL (D8).
signal burst_ended()


func _ready() -> void:
	assert(tuning != null, "FireSystem: tuning not assigned")
	assert(projectile_scene != null, "FireSystem: projectile_scene not assigned")


func _physics_process(delta: float) -> void:
	# Cooldown accumulator (Decision #2): decrement every frame so the gun is ready
	# when needed; fire when Fire is held and the cooldown has elapsed. First press
	# fires immediately (_cooldown starts at 0); sustained hold fires at ~6.25 Hz (or ~10 Hz during a
	# burst — _effective_fire_cooldown). Zero per-frame allocations — no arrays/dicts/Vector2 here.
	_cooldown -= delta
	# Story 2.6 — the sacrifice-burst timer (NP3). Tick ONLY while a burst is active (the guard avoids a
	# per-frame subtract in the common no-burst case — NFR2). On expiry, _expire_burst nulls _burst +
	# emits burst_ended (the Player reverts its on-ship visual). A burst that expires mid-hold cleanly
	# hands the next _spawn() back to the normal fire path (_burst is null again by then).
	if _burst != null:
		_burst_time_left -= delta
		if _burst_time_left <= 0.0:
			_expire_burst()
	if Input.is_action_pressed("fire") and _cooldown <= 0.0:
		_spawn()
		_cooldown = _effective_fire_cooldown()


func _effective_fire_cooldown() -> float:
	# Story 2.6 (AC1 fast-fire) — the fire cooldown, burst-aware. During a burst → sacrifice_tuning's
	# 0.10 s fast-fire; otherwise the chassis tuning's 0.16 s. Read at fire time (NOT cached) so a
	# mid-hold burst start/expiry takes effect on the very next shot. AR11 fail-safe: an unassigned
	# sacrifice_tuning during a burst falls back to the chassis cooldown (the triple-shot still applies
	# via _spawn_burst; only the cadence bonus is lost).
	if _burst != null and sacrifice_tuning != null:
		return sacrifice_tuning.burst_fire_cooldown
	return tuning.fire_cooldown


func _has_burst_shape() -> bool:
	# Review fix — AR11 fail-safe: an unassigned sacrifice_tuning while a burst is active must degrade
	# (fall back to a single straight shot at normal damage) instead of crashing. _spawn_burst can only
	# be called safely when this is true; _spawn() checks it before routing to _spawn_burst.
	return sacrifice_tuning != null


func _spawn() -> void:
	# _muzzle resolved in @onready; projectile_parent wired by player.gd after this
	# node's _ready (no race — both are read here, on fire, never in _ready). Skip
	# cleanly if driven before wiring completes (partial test setup); a silent skip
	# surfaces as a failed count assertion rather than aborting the whole suite.
	if _muzzle == null or projectile_parent == null:
		return
	# Story 2.6 — the sacrifice burst OVERRIDES the fire path: a triple-shot spread (_spawn_burst) for
	# the burst's duration. The docked fighter was CONSUMED by the sacrifice before the burst applied
	# (is_docked() is false; _docked_ship is null), so suppressing the docked parallel stream here is
	# correct (defensive — it would no-op anyway). On expiry (_burst → null) this falls through to the
	# normal primary + docked path automatically.
	if _burst != null:
		if _has_burst_shape():
			_spawn_burst()
		else:
			# Review fix — AR11 fail-safe: sacrifice_tuning went unassigned mid-burst (misconfigured
			# scene). Degrade to a single straight shot at normal damage rather than crashing on
			# sacrifice_tuning dereference in _spawn_burst().
			_spawn_one(_muzzle.global_position, tuning.projectile_damage)
			JuiceFx.player_fired(_muzzle.global_position)
		return
	# Primary stream.
	_spawn_one(_muzzle.global_position, tuning.projectile_damage)
	# Story 2.3 — the parallel bullet stream when docked (AC#3 +firepower, FR7). A 2nd bullet at the
	# docked tuning's offset, sharing the cooldown (synced cadence — FR7 "matches the player's fire
	# cadence"). Open Question H default: the player's FireSystem spawns both (simpler + auto-synced);
	# a DockedShip-owned FireSystem refactor is deferred to Story 2.6 (the player's FireSystem spawns
	# both streams in 2.3/2.4).
	if _player != null and _player.has_method("is_docked") and _player.call("is_docked"):
		var dt: DockedShipTuning = _player.get("docked_ship_tuning") as DockedShipTuning
		var offset_x: float = dt.stream_offset_x if dt != null else _FALLBACK_STREAM_OFFSET_X
		var damage: int = dt.stream_damage if dt != null else tuning.projectile_damage
		_spawn_one(_muzzle.global_position + Vector2(offset_x, 0.0), damage)
	# On-fire juice (Story 1.6 / AC4): fire SFX (mandated, ±5% pitch inside play_fire) + a light
	# optional muzzle puff. ONE juice per fire press, not per bullet (the two bullets fire together).
	# Juice request signals only — no game-flow. (Story 1.3's "emits nothing to EventBus" note referred
	# to GAME-FLOW signals; juice requests are a separate, allowed channel.)
	JuiceFx.player_fired(_muzzle.global_position)


func _spawn_one(at: Vector2, damage: int, angle_rad: float = 0.0) -> void:
	# Hoist the bullet-spawn body (Pool.acquire → activate at `at` → add_child) so the primary + the
	# docked parallel stream + the burst's triple-shot share it. Zero per-frame allocations (NFR3). Parent
	# to the injected world-space container, NOT the Player (transform-independence, Decision #8).
	# `damage` lets the docked stream use DockedShipTuning.stream_damage + the burst scale via
	# burst_damage_mult; `angle_rad` (default 0 = straight up) carries the burst's ±0.18 rad spread.
	var p: Projectile = Pool.acquire(projectile_scene) as Projectile
	assert(p != null, "FireSystem: acquired node is not a Projectile — wrong scene?")
	p.activate(at, tuning.bullet_speed, damage, angle_rad)
	projectile_parent.add_child(p)


# === Story 2.6 — Sacrifice Burst (NP3) ===
# The buff layer: a threat-clamped SacrificeBurst (computed by BuildRecompute in the Arena) drives a
# fixed ~10 s window of triple-shot ±0.18 rad (AC1) + ×power-scaled damage + 0.10 s fast-fire (AC1).
# AC3: this is a STAT BUFF on the player's fire (more bullets + damage) — NOT an AoE / screen-clear;
# there is deliberately no area damage anywhere in this layer (the rejected prototype "Bomber = 50 dmg
# to all" AoE model is NOT modeled here — see Dev Notes "Do not port the prototype").

func apply_burst(burst: SacrificeBurst) -> void:
	# Apply a threat-clamped sacrifice burst (called by Player.apply_sacrifice_burst, which the Arena
	# calls after BuildRecompute.threat_ceiling). Sets the active burst + its timer window. Re-entrant
	# safe: a burst already active is simply replaced (a 2nd sacrifice mid-burst refreshes the window —
	# structurally rare: one docked ship per wave → at most one sacrifice per wave, AC4). duration comes
	# from the burst (the fixed ~10 s window); the timer ticks down in _physics_process.
	_burst = burst
	_burst_time_left = burst.duration


func _spawn_burst() -> void:
	# AC1 / AC3 — the sacrifice burst's triple-shot spread. AC3: a STAT BUFF (more bullets + scaled
	# damage), NOT an AoE — no area damage / screen-wide blast (deliberate; see the story AC3). Spawns
	# sacrifice_tuning.burst_shot_count (3) pooled projectiles in a SYMMETRIC fan about straight-up:
	# angle_i = (i − (count−1)/2) × spread → count=3 gives {−spread, 0, +spread} = ±0.18 rad (AC1). Each
	# carries the threat-scaled damage (tuning.projectile_damage × burst_damage_mult(power)). Reuses the
	# pooled _spawn_one path (NFR3 — no instantiate/queue_free per shot; a few Pool.acquire calls per
	# burst-fire tick is fine, the pool absorbs it). player_fired juice fires ONCE per tick (one SFX/muzzle).
	assert(_burst != null, "FireSystem._spawn_burst called with no active burst")
	assert(sacrifice_tuning != null, "FireSystem._spawn_burst called with no sacrifice_tuning")
	var spread: float = sacrifice_tuning.burst_spread_rad
	var count: int = maxi(sacrifice_tuning.burst_shot_count, 1)
	var damage: int = int(round(tuning.projectile_damage * BuildRecompute.burst_damage_mult(_burst.power, sacrifice_tuning)))
	var at: Vector2 = _muzzle.global_position
	for i in count:
		var angle: float = (float(i) - float(count - 1) / 2.0) * spread
		_spawn_one(at, damage, angle)
	JuiceFx.player_fired(at)


func _expire_burst() -> void:
	# Natural expiry (the timer hit 0 in _physics_process). Null the burst + emit burst_ended so the
	# Player reverts its on-ship visual (glow/enlarge/timer ring). Called from _physics_process only;
	# clear_burst() is the force-clear variant for wave-clear / death.
	_burst = null
	_burst_time_left = 0.0
	burst_ended.emit()


func clear_burst() -> void:
	# Force-clear the buff (wave-clear + death paths call this so a burst never persists into the next
	# wave or past a death). Emits burst_ended ONLY when a burst was actually active — so the Player's
	# connected visual-revert runs uniformly for ALL clears (natural expiry + wave-clear + death go
	# through the SAME revert path), and a clear with no active burst is a silent no-op (idempotent —
	# safe to call every wave-clear / death regardless of burst state).
	var had_burst: bool = _burst != null
	_burst = null
	_burst_time_left = 0.0
	if had_burst:
		burst_ended.emit()


func get_burst_remaining_ratio() -> float:
	# Story 2.6 (OQ9) — the depleting-arc timer ring reads this (Task 7). 1.0 at burst start → 0.0 at
	# expiry; 0.0 when no burst (the Player hides the ring). clampf guards a delta-spike underflow
	# producing a negative ratio in the frame between the timer crossing 0 and _expire_burst running.
	# Review fix — a zero/negative burst.duration (misconfigured tuning) would otherwise divide by
	# zero and feed a NaN ratio into _draw()'s draw_arc.
	if _burst == null or _burst.duration <= 0.0:
		return 0.0
	return clampf(_burst_time_left / _burst.duration, 0.0, 1.0)
