class_name HealthComponent
extends Node
# Reusable HP holder + the i-frame damage gate. AR5/D1: per-wave HP lives here, reset
# each wave by the wave controller. Damage sources call take_damage() directly via the
# node-name convention (Story 1.4 key decision #2), so i-frames belong HERE (not on the
# player) — otherwise the hit lands in the component and must be retroactively undone.
#
# `health_changed`/`died` are LOCAL (direct) signals — D8: never route intra-entity
# comms through EventBus.

@export var max_hp: int = 3  # literal default so @export parses; mirrors Constants.BASE_HP.
# i-frame window granted after a REAL damaging hit. Default 0.0 = no i-frames, so enemies
# (which reuse this component) are unaffected and pooled-enemy re-`activate()` does not
# regress (Story 1.5 key decision #2). The player sets this from player_tuning.iframe_s.
@export var invuln_after_hit_s: float = 0.0

var current_hp: int = 0
var _is_dead: bool = false
var _invuln_timer: float = 0.0  # remaining invulnerability seconds; > 0.0 ⇒ invulnerable.

signal health_changed(current: int, maximum: int)
signal died


func _ready() -> void:
	current_hp = max_hp


func _process(delta: float) -> void:
	# i-frames are a timing window (not physics-driven); use _process to avoid
	# double-ticking when an entity's physics is disabled. Gated so enemies (timer
	# permanently 0.0) cost one branch per frame, never a subtract (NFR2/AR14).
	if _invuln_timer > 0.0:
		_invuln_timer = maxf(_invuln_timer - delta, 0.0)


func is_invulnerable() -> bool:
	# Public — the player flickers on it; debug/HUD may read it.
	return _invuln_timer > 0.0


func set_invuln(seconds: float) -> void:
	# Public so respawn can grant a window WITHOUT taking a hit (fair re-entry into
	# fire-columns). Clamps negatives to 0 (disabling the window is a valid call).
	_invuln_timer = maxf(seconds, 0.0)


func take_damage(amount: int) -> void:
	# i-frame gate: while invulnerable, the hit is FULLY ignored (no damage, no
	# health_changed, no died) — bullets still consume on contact (the projectile path),
	# they just deal 0 damage here (Story 1.5 key decision #2 — damage-immune, not intangible).
	if is_invulnerable():
		return
	# Clamp amount >= 0 (negative damage is never a heal), subtract, floor at 0,
	# emit health_changed, and emit died exactly once per "life".
	var previous_hp: int = current_hp
	var safe_amount: int = maxi(amount, 0)
	current_hp = maxi(current_hp - safe_amount, 0)
	health_changed.emit(current_hp, max_hp)
	if current_hp == 0 and not _is_dead:
		_is_dead = true
		died.emit()
	# Grant the i-frame window only on a REAL damaging hit (HP actually decreased) and
	# only if the component is configured for i-frames (enemies keep the 0.0 default).
	if current_hp < previous_hp and invuln_after_hit_s > 0.0:
		set_invuln(invuln_after_hit_s)


func heal(amount: int) -> void:
	# Pure clamp heal — no revive-from-zero (a dead ship respawns via reset_to_full() or
	# the run ends; "heal the dead ship back to life" is never an action). Revive
	# semantics resolved in Story 1.5 (deferred-work item from the 1.2 review): heal()
	# stays a pure clamp for future within-wave chip-heal (e.g. a hypothetical E3 shield
	# power-up) which must never revive.
	var safe_amount: int = maxi(amount, 0)
	current_hp = mini(current_hp + safe_amount, max_hp)
	health_changed.emit(current_hp, max_hp)


func reset_to_full() -> void:
	# Hook the wave controller calls each wave + the respawn path. Restores HP, clears the
	# dead flag (so a new life can die again — internal invariant: full HP => alive), and
	# clears any lingering i-frame window (a fresh-full ship starts vulnerable; respawn
	# grants its OWN window via set_invuln()).
	current_hp = max_hp
	_is_dead = false
	_invuln_timer = 0.0
	health_changed.emit(current_hp, max_hp)
