class_name Arena
extends Node2D
# The E1 run host (Story 1.5). Owns the RunState spine (ships + score), wires it into the
# spawner + player, and orchestrates RUN-SCOPE decisions: ship loss (respawn vs game-over),
# the wave-clear heal + minimal next-wave loop, and the E1 loss→replay placeholder.
#
# Per-ship mechanics are the PLAYER's (wave scope); run-scope decisions are HERE (AR2).
# The full wave-lifecycle FSM (intro/reward/shop/replay, authored feel-gate assembly) and
# the real game-over screen/menu flow are Story 1.8 / 8.4 — this is the minimal precursor
# that makes the ship economy testable end-to-end across multiple waves.

# E1 placeholder: on loss, auto-replay the scene for a fresh run (ships→3, score→0). The
# real game-over/menu/restart flow is Story 8.4 (which replaces this toggle). Default true
# in gameplay; tests flip it false so a deferred reload can't reset the GUT runner scene.
@export var auto_replay_on_loss: bool = true

@onready var _spawner: FormationSpawner = $FormationSpawner
@onready var _player: Player = $Player
@onready var _run_state: RunState = RunState.new()

var _wave_num: int = 1


func _ready() -> void:
	_run_state.begin_run()  # ships = BASE_SHIPS (3), score = 0
	# Inject refs BEFORE begin_wave: children's _ready fired before ours (bottom-up), so
	# _spawner/_player exist. Wire run_state + the player for dive aim, then start wave 1.
	_spawner.player = _player
	_spawner.run_state = _run_state
	# player.ship_depleted (LOCAL, D8) → run-scope decision. wave_cleared → heal + next wave.
	_player.ship_depleted.connect(_on_player_ship_depleted)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	_spawner.begin_wave(_wave_num)


func _on_player_ship_depleted() -> void:
	# The player lost a ship (HP hit 0 within the wave). Spend a life; the run host decides
	# respawn vs game-over on the returned remaining count (RunState owns ships — AR2).
	var remaining: int = _run_state.spend_ship()
	if remaining > 0:
		_player.respawn()
		EventBus.ship_lost.emit(remaining)
	else:
		_on_run_lost()


func _on_run_lost() -> void:
	# Last ship spent → run over. Emit game_over (safe to fire synchronously — D8 global
	# flow), freeze spawning, then defer the replay. The reload + Pool.clear MUST defer:
	# this handler runs synchronously inside the physics step (enemy_projectile._on_body_entered
	# → take_damage → died → ship_depleted → here, all during _physics_process); freeing the
	# tree / mutating the Pool mid-collision would corrupt the step (same gotcha as Story 1.4's
	# deferred Pool.release). call_deferred lands it at idle, outside the physics callback.
	EventBus.game_over.emit()
	_spawner.set_active(false)
	if auto_replay_on_loss:
		_end_run.call_deferred()


func _end_run() -> void:
	# E1 placeholder fresh-run: empty the Pool (so it stops referencing nodes the scene
	# reload is about to free) then reload. The new Arena._ready constructs a fresh RunState
	# (ships back to 3, score 0). The real restart flow is Story 8.4.
	Pool.clear()
	var err: Error = get_tree().reload_current_scene()
	if err != OK:
		Log.err("arena", "reload_current_scene failed (%d) — run did not restart" % err)


func _on_wave_cleared(_wave: int) -> void:
	# AC4: full HP before the next wave (AR2 — the wave host resets per-wave HP). Then advance
	# the minimal next-wave loop. Strict subset of Story 1.8's full lifecycle FSM (no intro /
	# reward / shop / replay interlude here).
	_player._health.reset_to_full()
	_wave_num += 1
	_spawner.begin_wave(_wave_num)
