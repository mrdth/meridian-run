class_name HealthComponent
extends Node
# Reusable HP holder. AR5/D1: per-wave HP lives here, reset each wave by the wave
# controller. BUILT REAL BUT NOT WIRED this story — damage sources (1.4/1.6),
# wave-reset callers (1.5), and ship_lost/game_over (1.5) are deferred.
#
# `health_changed`/`died` are LOCAL (direct) signals — D8: never route intra-entity
# comms through EventBus.

@export var max_hp: int = 3  # literal default so @export parses; mirrors Constants.BASE_HP.

var current_hp: int = 0
var _is_dead: bool = false

signal health_changed(current: int, maximum: int)
signal died


func _ready() -> void:
	current_hp = max_hp


func take_damage(amount: int) -> void:
	# Clamp amount >= 0 (negative damage is never a heal), subtract, floor at 0,
	# emit health_changed, and emit died exactly once per "life".
	var safe_amount: int = maxi(amount, 0)
	current_hp = maxi(current_hp - safe_amount, 0)
	health_changed.emit(current_hp, max_hp)
	if current_hp == 0 and not _is_dead:
		_is_dead = true
		died.emit()


func heal(amount: int) -> void:
	# Pure clamp heal — no revive-from-zero semantics decided here (1.5's call).
	var safe_amount: int = maxi(amount, 0)
	current_hp = mini(current_hp + safe_amount, max_hp)
	health_changed.emit(current_hp, max_hp)


func reset_to_full() -> void:
	# Hook the 1.5 wave controller calls each wave. Restores HP and clears the
	# dead flag so a new life can die again (internal invariant: full HP => alive).
	current_hp = max_hp
	_is_dead = false
	health_changed.emit(current_hp, max_hp)
