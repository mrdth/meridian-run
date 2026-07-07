class_name Arena
extends Node2D
# The E1 run host (Story 1.5). Owns the RunState spine (ships + score), wires it into the
# WaveController + spawner + player, and orchestrates RUN-SCOPE decisions: ship loss (respawn vs
# game-over) and the E1 loss→replay placeholder.
#
# The wave lifecycle (spawn → active → completed/failed, heal-on-clear, replay) is OWNED by
# WaveController as of Story 1.8 — Arena no longer drives begin_wave/wave_cleared/advance directly.
# Per-ship mechanics are the PLAYER's (wave scope); run-scope decisions are HERE (AR2). The real
# game-over/menu/restart flow is Story 8.4.

# E1 placeholder: on loss, auto-replay the scene for a fresh run (ships→3, score→0). The
# real game-over/menu/restart flow is Story 8.4 (which replaces this toggle). Default true
# in gameplay; tests flip it false so a deferred reload can't reset the GUT runner scene.
@export var auto_replay_on_loss: bool = true

@onready var _spawner: FormationSpawner = $FormationSpawner
@onready var _player: Player = $Player
@onready var _run_state: RunState = RunState.new()
@onready var _hud: Hud = $HUD
@onready var _wave_controller: WaveController = $WaveController


func _ready() -> void:
	_run_state.begin_run()  # ships = BASE_SHIPS (3), score = 0
	# Inject refs BEFORE start_run: children's _ready fired before ours (bottom-up), so
	# _spawner/_player/_wave_controller exist. Wire run_state + the player for dive aim.
	_spawner.player = _player
	_spawner.run_state = _run_state
	# player.ship_depleted (LOCAL, D8) → run-scope decision. WaveController separately subscribes
	# to EventBus.game_over to Fail the active wave (it owns the wave lifecycle now).
	_player.ship_depleted.connect(_on_player_ship_depleted)
	# Story 1.7 — inject the player ref into the HUD so its focus/fade model can read hp_ratio. The
	# HUD subscribes to the player's HealthComponent.health_changed (read-only, D8-clean).
	_hud.set_player(_player)
	# Story 1.8 — WaveController owns the wave lifecycle FSM. Inject its refs + start the run: it
	# emits wave_started/wave_cleared (the HUD consumes both), drives the spawner's begin_wave/stop,
	# full-heals the player on wave clear (AC2), and replays the authored wave. This replaces the
	# 1.5 direct _spawner.begin_wave + Arena._on_wave_cleared heal+advance loop.
	_wave_controller.player = _player
	_wave_controller.spawner = _spawner
	_wave_controller.run_state = _run_state
	_wave_controller.start_run()
	# Story 1.8 / FR50 — bind gameplay refs into the Debug autoload so the overlay + cheats can reach
	# them. Debug-build only (the autoload is a no-op in release). Mirrors the HUD injection pattern.
	if OS.is_debug_build():
		Debug.bind_arena(_player, _spawner, _wave_controller)


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
	# Last ship spent → run over. Emit game_over (WaveController hears it → WaveFailedState +
	# spawner.stop(); safe to fire synchronously — D8 global flow), then defer the replay. The reload
	# + Pool.clear MUST defer: this handler runs synchronously inside the physics step (enemy_projectile
	# ._on_body_entered → take_damage → died → ship_depleted → here, all during _physics_process);
	# freeing the tree / mutating the Pool mid-collision would corrupt the step (same gotcha as Story
	# 1.4's deferred Pool.release). call_deferred lands it at idle, outside the physics callback.
	EventBus.game_over.emit()
	if auto_replay_on_loss:
		_end_run.call_deferred()


func _end_run() -> void:
	# E1 placeholder fresh-run: empty the Pool (so it stops referencing nodes the scene reload is
	# about to free) then reload. The new Arena._ready constructs a fresh RunState (ships back to 3,
	# score 0) + a fresh WaveController (wave 1). The real restart flow is Story 8.4.
	# Debug-build only: clear cheat/toggle state (and restore any mutated PlayerTuning baseline)
	# so a debug session's cheats don't leak into the next run (Debug is an autoload — it outlives
	# the reload).
	if OS.is_debug_build():
		Debug.reset_debug_state()
	Pool.clear()
	var err: Error = get_tree().reload_current_scene()
	if err != OK:
		Log.err("arena", "reload_current_scene failed (%d) — run did not restart" % err)
