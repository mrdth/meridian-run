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
# Story 2.6 (NP3) — the sacrifice-burst tuning (AR10/D9). The Arena owns run-scope enrichment
# (wing_level + threat) + computes the burst via BuildRecompute.threat_ceiling; this tuning carries
# the NP3 clamp knobs + the fixed burst shape. Wired in arena.tscn to resources/sacrifice_tuning.tres
# (the .tres wins at runtime). Fail-safe default if unassigned (AR11 — mirrors JuiceCoordinator).
@export var sacrifice_tuning: SacrificeTuning

@onready var _spawner: FormationSpawner = $FormationSpawner
@onready var _player: Player = $Player
@onready var _run_state: RunState = RunState.new()
@onready var _hud: Hud = $HUD
@onready var _wave_controller: WaveController = $WaveController

var _reload_in_flight: bool = false  # review fix: re-entrancy guard shared by _on_run_lost + F12 reset.
var _default_sacrifice_tuning: SacrificeTuning = null  # review fix: cached fallback, not reallocated per sacrifice.
var _warned_sacrifice_tuning_unassigned: bool = false  # review fix: warn once, not on every sacrifice.


func _ready() -> void:
	_run_state.begin_run()  # ships = BASE_SHIPS (3), score = 0
	# Inject refs BEFORE start_run: children's _ready fired before ours (bottom-up), so
	# _spawner/_player/_wave_controller exist. Wire run_state + the player for dive aim.
	_spawner.player = _player
	_spawner.run_state = _run_state
	# player.ship_depleted (LOCAL, D8) → run-scope decision. WaveController separately subscribes
	# to EventBus.game_over to Fail the active wave (it owns the wave lifecycle now).
	_player.ship_depleted.connect(_on_player_ship_depleted)
	# Story 2.5 (AC1) — player.sacrifice_committed (LOCAL, D8) → run-scope burst hook. The Arena (RunState
	# owner) enriches the global burst signal with wing_level (AR2 — the Player never touches RunState).
	# The Player is NOT pooled → connect ONCE (the is_connected guard is belt-and-braces, mirroring
	# captor_resolved's connect).
	if not _player.sacrifice_committed.is_connected(_on_player_sacrifice_committed):
		_player.sacrifice_committed.connect(_on_player_sacrifice_committed)
	# Story 2.5 (AC2) — player.ship_kept (LOCAL, D8) → run-scope Keep regain (add_ship(+1)). The Player is
	# NOT pooled → connect ONCE (belt-and-braces is_connected guard).
	if not _player.ship_kept.is_connected(_on_player_ship_kept):
		_player.ship_kept.connect(_on_player_ship_kept)
	# Story 2.3 — the spawner routes captor deaths here for run-scope resolution (rescue dock vs
	# failed-rescue enemy spawn). LOCAL signal (spawner→Arena, D8 intra-scene). Arena is NOT pooled →
	# connect ONCE (the is_connected guard is belt-and-braces, mirroring the player's wave_cleared).
	if not _spawner.captor_resolved.is_connected(_on_captor_resolved):
		_spawner.captor_resolved.connect(_on_captor_resolved)
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
	# Story 2.4 — also pass _run_state so the overlay's BUILD row can surface the WING track (read-only).
	if OS.is_debug_build():
		Debug.bind_arena(_player, _spawner, _wave_controller, _run_state)
	# review fix: F12 reset is debug/dev tooling (Task 8), like Debug's own debug_cheat_* actions — it
	# must not be reachable in exported/release builds. Strips _unhandled_input processing entirely
	# (mirrors systems/debug.gd's _ready gate) rather than an inline is_debug_build() check per event.
	if not OS.is_debug_build():
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	# F12 — manual run reset (back to wave 1, full lives, score 0). Read as an action (F5: actions, never
	# raw keys), keyboard-only like the debug_* actions. Debug-build only (gated in _ready above). Reuses
	# _reload_run_fresh — the SAME fresh-scene reload a run-loss auto-replay uses (a fresh Arena._ready
	# runs begin_run: ships=BASE_SHIPS, score=0 + a fresh WaveController at wave 1). Deferred so it's safe
	# from the input callback and consistent with _on_run_lost's deferred reload. The WING track resets
	# too (BuildState.reset() in begin_run).
	if event.is_action_pressed("reset"):
		_try_reload_run_fresh()


func _on_player_ship_depleted() -> void:
	# The player lost a ship (HP hit 0 within the wave). Spend a life; the run host decides
	# respawn vs game-over on the returned remaining count (RunState owns ships — AR2).
	var remaining: int = _run_state.spend_ship()
	if remaining > 0:
		_player.respawn()
		EventBus.ship_lost.emit(remaining)
	else:
		_on_run_lost()


func _on_player_sacrifice_committed() -> void:
	# Story 2.5 (AC1) — the sacrifice-burst HOOK. The Arena (RunState owner) is the single point that
	# enriches global signals with run-state data (consistent with 2.4's record_rescue pattern). Payload =
	# wing_level (the WING-track investment FR19 says the burst "scales with"); the Player has no RunState
	# ref (AR2). The signal emit stays FIRST + unchanged — 2.5's tests assert sacrifice_burst_started carries
	# wing_level; the global game-flow hook is the same.
	# Story 2.6 (NP3) — now ALSO computes the threat-clamped burst and applies it to the player's FireSystem.
	# AC4: there is NO artificial cooldown between sacrifices — the bound is structural (one docked ship per
	# wave → at most one sacrifice per wave; forfeits keep-regain). Do NOT add a sacrifice cooldown (a last-
	# press timestamp, a readiness flag, etc.) — those would violate AC4.
	var wing_level: int = _run_state.build_state.wing_level
	EventBus.sacrifice_burst_started.emit(wing_level)
	# Story 2.6 — guard the game_over/reload race (Dev Notes §"⚠️ Edge cases"): sacrifice input is read every
	# _physics_process with no gate against the game_over→reload window, so a sacrifice can commit against a
	# RunState about to be torn down. 2.5 only emitted a signal (low risk); 2.6 MUTATES FireSystem state, so
	# skip the apply when the run is ending. _reload_in_flight mirrors "game_over already emitted + reload
	# queued" (_on_run_lost emits game_over THEN queues the reload); the signal emit above is harmless either
	# way (no subscriber mutates run state). The is_instance_valid guard is belt-and-braces against teardown.
	if _reload_in_flight or not is_instance_valid(_player):
		return
	# AR11 fail-safe: an unassigned sacrifice_tuning falls back to defaults (mirrors JuiceCoordinator's
	# tuning fallback) so a misconfigured scene degrades instead of crashing on cfg dereference. Review
	# fix: cache the fallback instance (was allocating a fresh SacrificeTuning every sacrifice) and warn
	# only once per Arena instance (was logging on every sacrifice while misconfigured).
	var cfg: SacrificeTuning = sacrifice_tuning
	if cfg == null:
		if _default_sacrifice_tuning == null:
			_default_sacrifice_tuning = SacrificeTuning.new()
		cfg = _default_sacrifice_tuning
		if not _warned_sacrifice_tuning_unassigned:
			_warned_sacrifice_tuning_unassigned = true
			Log.warn("arena", "sacrifice_tuning unassigned — using SacrificeTuning defaults (wire resources/sacrifice_tuning.tres in arena.tscn)")
	# NP3 — the threat-relative clamp. threat = Σ active enemies' max HP (captures Swarm/tier/Bomber
	# composition); threat_ceiling caps raw power at threat * max_threat_fraction → "always useful (fixed
	# triple/fast-fire shape), never an insta-win (damage mult clamped)". Injection, NOT a RunState ref on
	# Player (AR2 — the Arena owns RunState + the burst computation; the Player just applies the result).
	var threat: float = _compute_current_threat()
	var burst: SacrificeBurst = BuildRecompute.threat_ceiling(wing_level, threat, cfg)
	_player.apply_sacrifice_burst(burst)


func _compute_current_threat() -> float:
	# Story 2.6 (NP3 / AC2) — the "current-wave threat" the burst is clamped against. Sum of active
	# enemies' max HP — captures Swarm (2× enemies), tier (+30/60% HP), and Bomber-heavy waves naturally
	# (a plain enemy_count or wave_num×k would miss HP variance — confirmed with Mrdth 2026-07-13). Both
	# Enemy + Captor expose `_health` (HealthComponent, max_hp set from definition.max_hp at activate —
	# enemy.gd / captor.gd); a held CaptureColumn has no `_health`, so the `is HealthComponent` guard skips
	# it. Computed once at sacrifice time (NOT a hot path — one loop over the enemy container). Returns 0.0
	# if the spawner/container is unassigned (fail-safe — a threat of 0 clamps power to 0, still useful).
	if _spawner == null or _spawner._container == null:
		return 0.0
	var total: float = 0.0
	for child in _spawner._container.get_children():
		if not is_instance_valid(child):
			continue
		var h = child.get("_health")
		if h is HealthComponent:
			total += float(h.max_hp)
	return total


func _on_player_ship_kept() -> void:
	# Story 2.5 (AC2) — the Keep regain: the ONLY add_ship caller in the Gamble. add_ship clamps to
	# MAX_SHIPS (5, FR8) — a keep at max ships is a graceful no-op-clamp. NO HP change (WaveController
	# heals HP on clear separately — keep is about ships, not HP). This +1 makes capture→rescue→keep net 0
	# (capture was −1 in 2.2). Then ship_gained so the HUD lives-pip row reflects the regained ship (Task
	# 4 — without it the regain would be invisible; the HUD updated only on ship_lost before 2.5).
	# review fix: only emit ship_gained if a ship was ACTUALLY regained — at MAX_SHIPS, add_ship(1) is a
	# no-op clamp, and emitting ship_gained anyway would flash a phantom "ship regained" HUD cue.
	var ships_before: int = _run_state.ships
	_run_state.add_ship(1)
	if _run_state.ships > ships_before:
		EventBus.ship_gained.emit(_run_state.ships)


func _on_captor_resolved(rescue: bool, at: Vector2) -> void:
	# Story 2.3 — the captor was killed. Arena owns the run-scope resolution (AR2). Per the Mrdth-confirmed
	# economy (2026-07-12): the ONLY ship-count changes in the Gamble are capture (−1, 2.2) and keep (+1,
	# 2.5). Rescue docks a fighter (NO ship change); failed-rescue turns the captive enemy (+1 enemy, NO
	# ship change — the epics AC2 "−1 ship" is relative-accounting vs the keep +1, NOT a spend). NO
	# respawn in either branch (the player's ship is fine — they shot the captor, they weren't hit).
	#
	# Runs inside the physics step (captor death originates in a body_entered callback). try_dock_ship
	# (instantiate + add_child) + spawn_enemy_at (Pool.acquire + add_child + activate_at) are both
	# ADDITIVE mid-physics (same as the drip _spawn_enemy). NO game-over path here — failed-rescue can't
	# drop ships to 0 (it doesn't spend one); the only ship-count changes are capture (−1, via
	# ship_depleted above) and keep (+1, 2.5). The JuiceFx helpers source colors/amounts from _TUNING +
	# the palette (Arena calls them one-line — no EventBus juice emits directly here).
	if rescue:
		# review fix: gate the rescue juice on an actual dock (try_dock_ship returns false if FR14's
		# one-docked guard blocks it — no misleading reward cue for a no-op dock).
		if _player.try_dock_ship():  # the rescue EFFECT entry — docks a fighter, no ship-count change.
			# Story 2.4 — earn the WING track (NP1 permanent identity). Arena owns RunState (AR2); the Player
			# never touches it, so the consume paths (absorb/wave-clear, which live on the Player) structurally
			# cannot clear this track. Inside the dock block so a blocked/no-op dock earns nothing (mirrors the
			# rescue-juice gate above). NO ship-count change — the docked fighter is a ship-in-escrow.
			_run_state.build_state.record_rescue()
			# The WING track changed → a build change. build_changed had no emitter before 2.4; this is its
			# first (forward-compat for the between-wave build-summary rail). Still inside the dock block.
			EventBus.build_changed.emit()
			JuiceFx.rescue(_player.global_position)  # pickup-style: a dock-color burst at the player + a positive SFX.
	else:
		# review fix: gate the failed-rescue juice on an actual spawn (spawn_enemy_at returns false if
		# the spawner is misconfigured — no hazard sting for an enemy that never appeared).
		if _spawner.spawn_enemy_at(at):  # +1 enemy at the captor's death position. NO ship-count change, NO respawn.
			JuiceFx.failed_rescue(at, _player)  # hazard sting: player-body flash + shake + a burst at `at` + a negative SFX.


func _on_run_lost() -> void:
	# Last ship spent → run over. Emit game_over (WaveController hears it → WaveFailedState +
	# spawner.stop(); safe to fire synchronously — D8 global flow), then defer the replay. The reload
	# + Pool.clear MUST defer: this handler runs synchronously inside the physics step (enemy_projectile
	# ._on_body_entered → take_damage → died → ship_depleted → here, all during _physics_process);
	# freeing the tree / mutating the Pool mid-collision would corrupt the step (same gotcha as Story
	# 1.4's deferred Pool.release). call_deferred lands it at idle, outside the physics callback.
	EventBus.game_over.emit()
	if auto_replay_on_loss:
		_try_reload_run_fresh()


func _try_reload_run_fresh() -> void:
	# review fix: the shared entry point for BOTH reload triggers (_on_run_lost's auto-replay AND F12's
	# manual reset). Without this guard, a same-frame game-over + F12 press (or a double F12 press before
	# the first deferred call lands) would queue _reload_run_fresh.call_deferred() twice — double-running
	# Pool.clear() + the scene reload. _reload_in_flight is never reset: the Arena instance is about to be
	# freed by the reload it queues, so there is nothing to re-arm.
	if _reload_in_flight:
		return
	_reload_in_flight = true
	_reload_run_fresh.call_deferred()


func _reload_run_fresh() -> void:
	# The shared fresh-run reload — used by BOTH a run-loss auto-replay (_on_run_lost) AND the F12 manual
	# reset (_unhandled_input). E1 placeholder: empty the Pool (so it stops referencing nodes the scene
	# reload is about to free) then reload. The new Arena._ready constructs a fresh RunState (ships back
	# to BASE_SHIPS=3, score 0, BuildState flat) + a fresh WaveController (wave 1). The real restart flow
	# is Story 8.4. Debug-build only: clear cheat/toggle state (and restore any mutated PlayerTuning
	# baseline) so a debug session's cheats don't leak into the next run (Debug is an autoload — it
	# outlives the reload).
	if OS.is_debug_build():
		Debug.reset_debug_state()
	Pool.clear()
	var err: Error = get_tree().reload_current_scene()
	if err != OK:
		Log.err("arena", "reload_current_scene failed (%d) — run did not restart" % err)
