extends GutTest
# Story 2.6 (Task 8) — integration tests for the sacrifice burst (AC1/AC2/AC4). Drives the FULL chain
# (dock → sacrifice → Arena._on_player_sacrifice_committed → BuildRecompute.threat_ceiling →
# Player.apply_sacrifice_burst → FireSystem buff) via the Arena fixture, plus FireSystem-level
# spawn/expiry assertions via a direct FireSystem fixture (mirrors test_fire_system.gd).
#
# The Arena owns the burst COMPUTATION + APPLICATION (it has _run_state + _spawner + sacrifice_tuning);
# a Player-only fixture cannot apply the burst (the Arena handler does), so the end-to-end tests use
# arena.tscn (mirrors test_arena_captor_resolution.gd). The FireSystem fixture is for the buff layer's
# spawn shape + expiry (no Arena needed). ⌨️ The 1-line Sacrifice input DISPATCH is untestable in GUT
# (memory input-just-pressed-untestable-in-gut); we drive _try_sacrifice() / apply_burst() DIRECTLY
# (the methods the input + Arena call), and cover the dispatch via the headless smoke + manual playtest.

const ArenaScene := preload("res://world/arena.tscn")
const PlayerScene := preload("res://player/player.tscn")


func before_each() -> void:
	# Pool is an autoload; start each test from a known-empty pool (mirrors test_fire_system / test_arena_*).
	Pool.clear()


func _make_arena() -> Arena:
	# arena.tscn wires Player + Spawner + WaveController + JuiceCoordinator; Arena._ready runs begin_run +
	# connects sacrifice_committed → _on_player_sacrifice_committed (the burst application path). Halt the
	# spawner's drip so no stray spawns perturb threat/counts (mirrors test_arena_captor_resolution._make).
	var arena: Arena = ArenaScene.instantiate() as Arena
	add_child_autofree(arena)
	arena._spawner.set_active(false)
	return arena


func _make_fs() -> FireSystem:
	# FireSystem fixture (mirrors test_fire_system._make): Player under a Node2D arena (player._ready wires
	# FireSystem.projectile_parent = get_parent(), typed Node2D), override projectile_parent with a temp
	# container for clean counts, disable physics, step manually. sacrifice_tuning is wired in player.tscn.
	var arena := Node2D.new()
	add_child_autofree(arena)
	var player: Player = PlayerScene.instantiate() as Player
	arena.add_child(player)
	var fs: FireSystem = player.get_node_or_null("FireSystem") as FireSystem
	var pp := Node2D.new()
	add_child_autofree(pp)
	fs.projectile_parent = pp
	player.set_physics_process(false)
	fs.set_physics_process(false)
	return fs


func after_each() -> void:
	# No synthetic fire input leaks between tests.
	Input.action_release("fire")


# --- AC1 / AC2 — dock → sacrifice applies a threat-clamped burst ---

func test_dock_sacrifice_applies_burst_with_duration() -> void:
	# The headline integration: dock (rescue → wing 1) → sacrifice → Arena computes threat_ceiling →
	# applies the burst to the FireSystem + arms the on-ship visual. With the spawner halted + no enemies,
	# threat = 0 → power clamps to 0 (the burst is still APPLIED — "always useful"; the fixed shape carries
	# it). duration ≈ the tuning's 10 s window.
	var arena := _make_arena()
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # rescue → dock + wing 1
	arena._player._try_sacrifice()  # consume → Arena → threat_ceiling → apply_sacrifice_burst
	var fs: FireSystem = arena._player._fire_system
	assert_not_null(fs._burst, "sacrifice should apply a burst to the FireSystem")
	assert_almost_eq(fs._burst.duration, 10.0, 0.01, "the burst window ≈ the tuning duration (10 s)")
	assert_almost_eq(fs._burst_time_left, 10.0, 0.01, "the timer starts at the full duration")
	assert_true(arena._player._burst_active, "the on-ship burst visual should arm")
	await get_tree().physics_frame  # let the deferred queue_free of the fighter land before teardown.


func test_burst_power_scales_with_threat_and_wing_level() -> void:
	# AC2 integration: the burst's power is the threat-relative clamp (NP3) computed from the LIVE wave
	# threat + the wing_level. Spawn one grunt (its HP = the wave threat), dock (wing 1), sacrifice →
	# power = min(raw, threat × max_threat_fraction). Robust to the grunt's actual HP (reads it live).
	# Review fix: read the expected raw/clamp from the WIRED sacrifice_tuning resource itself (arena.tscn's
	# resources/sacrifice_tuning.tres) instead of hardcoding 0.3/0.02 — those hardcoded values silently go
	# stale the moment the .tres is retuned (the story's own playtest-tuning pass). The pure-logic test file
	# already avoids this trap with synthetic configs; this integration test now mirrors that discipline.
	var arena := _make_arena()
	assert_true(arena._spawner.spawn_enemy_at(Vector2(500.0, 200.0)))  # +1 grunt → the wave threat
	var enemy: Enemy = arena._spawner._container.get_child(arena._spawner._container.get_child_count() - 1)
	var threat: float = float(enemy._health.max_hp)  # one grunt's HP = Σ active enemies' max HP
	var cfg: SacrificeTuning = arena.sacrifice_tuning
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # rescue → dock + wing 1
	arena._player._try_sacrifice()
	var burst: SacrificeBurst = arena._player._fire_system._burst
	assert_not_null(burst)
	var raw: float = cfg.base_power + 1.0 * cfg.power_per_wing  # wing 1: base_power + 1×power_per_wing
	var expected_power: float = minf(raw, threat * cfg.max_threat_fraction)
	assert_almost_eq(burst.power, expected_power, 0.0001, "power = min(raw, threat×max_threat_fraction) — the NP3 clamp")
	await get_tree().physics_frame


# --- AC1 / AC3 — the burst spawn path: triple-shot ±0.18 rad + scaled damage (NOT an AoE) ---

func test_burst_spawns_triple_shot_with_spread_and_scaled_damage() -> void:
	# AC1: the burst overrides the fire path with a triple-shot. AC3: it is a STAT BUFF (more bullets +
	# scaled damage), NOT an AoE — there is no area damage; just 3 pooled projectiles. Apply a burst at
	# power=1.0 (→ ×1.5 damage), hold fire, step one tick → 3 projectiles fanned ±0.18 rad about
	# straight-up, each carrying the scaled damage.
	# Review fix: compute the expected damage from the WIRED tuning resources (not hardcoded 10×1.5=15)
	# so a retune doesn't silently desync this assertion from reality — mirrors the fix above.
	var fs: FireSystem = _make_fs()
	var pp: Node2D = fs.projectile_parent
	fs.apply_burst(SacrificeBurst.new(1.0, 10.0))  # power=1.0 → ×1.5 dmg; duration 10 s.
	var expected_damage: int = int(round(fs.tuning.projectile_damage * BuildRecompute.burst_damage_mult(1.0, fs.sacrifice_tuning)))
	Input.action_press("fire")
	fs._physics_process(1.0 / 60.0)  # one burst-fire tick → the triple-shot.
	Input.action_release("fire")
	assert_eq(pp.get_child_count(), 3, "a burst-fire tick should spawn the triple-shot (3 projectiles, NOT an AoE)")
	var dirs: Array[Vector2] = []
	for c in pp.get_children():
		assert_true(c is Projectile, "burst spawns should be pooled Projectiles")
		var proj: Projectile = c as Projectile
		dirs.append(proj._direction)
		# Review fix: assert EACH projectile's damage individually (was overwriting a single `dmg` var
		# every iteration, so only the last-iterated shot was ever actually checked).
		assert_eq(proj._damage, expected_damage, "every burst projectile carries the same ×power-scaled damage")
	# One projectile travels straight up (angle 0 → (0, -1)).
	var has_straight: bool = false
	for d in dirs:
		if absf(d.x) < 0.001 and absf(d.y + 1.0) < 0.001:
			has_straight = true
	assert_true(has_straight, "one burst projectile should travel straight up (the 0 rad center shot)")
	# The side shots fan ±0.18 rad: |x| ≈ sin(0.18). Symmetric (one left, one right).
	var side_spread_x: float = sin(0.18)
	var found_left: bool = false
	var found_right: bool = false
	for d in dirs:
		if absf(d.x) < 0.001:
			continue  # the center shot
		if d.x < 0.0:
			found_left = true
		else:
			found_right = true
		assert_almost_eq(absf(d.x), side_spread_x, 0.01, "side shot x-spread ≈ sin(0.18 rad)")
	assert_true(found_left and found_right, "the burst should fan left AND right (symmetric ±0.18 rad)")


func test_burst_overrides_normal_fire_path() -> void:
	# AC1: while the burst is active, _spawn routes to _spawn_burst (3 shots) — NOT the primary + docked
	# path (1 shot + the docked stream). The docked fighter was consumed by the sacrifice anyway.
	var fs: FireSystem = _make_fs()
	var pp: Node2D = fs.projectile_parent
	fs.apply_burst(SacrificeBurst.new(1.0, 10.0))
	Input.action_press("fire")
	fs._physics_process(1.0 / 60.0)
	Input.action_release("fire")
	assert_eq(pp.get_child_count(), 3, "a burst-fire tick spawns 3 (the triple-shot), not 1 (the primary)")


func test_normal_fire_resumes_after_burst_expires() -> void:
	# After the burst expires, _spawn falls back to the normal primary path (1 projectile per tick). Pins
	# that the burst branch is gated on _burst != null and clears cleanly.
	var fs: FireSystem = _make_fs()
	var pp: Node2D = fs.projectile_parent
	fs.apply_burst(SacrificeBurst.new(1.0, 10.0))
	# Expire the burst by stepping past its duration.
	while fs._burst != null:
		fs._physics_process(1.0 / 60.0)
	assert_null(fs._burst, "precondition: burst expired")
	Input.action_press("fire")
	fs._physics_process(1.0 / 60.0)  # normal fire → 1 projectile.
	Input.action_release("fire")
	assert_eq(pp.get_child_count(), 1, "after expiry, normal fire resumes (1 projectile per tick, not 3)")


# --- AC1 — expiry clears the buff + emits burst_ended ---

func test_burst_expires_clears_buff_and_emits_signal() -> void:
	var fs: FireSystem = _make_fs()
	watch_signals(fs)
	fs.apply_burst(SacrificeBurst.new(1.0, 10.0))
	assert_not_null(fs._burst)
	# Step past the duration → the timer crosses 0 → _expire_burst → _burst null + burst_ended emitted.
	var steps: int = 0
	while fs._burst != null and steps < 2000:
		fs._physics_process(1.0 / 60.0)
		steps += 1
	assert_null(fs._burst, "the buff should be cleared on expiry")
	assert_eq(fs._burst_time_left, 0.0, "the timer is zeroed on expiry")
	assert_signal_emitted(fs, "burst_ended", "expiry should emit burst_ended (the visual-revert trigger)")


func test_clear_burst_is_silent_when_no_burst_active() -> void:
	# clear_burst (wave-clear / death) must be a silent no-op when no burst is active — idempotent, safe
	# to call every wave-clear/death. It must NOT emit a spurious burst_ended.
	var fs: FireSystem = _make_fs()
	watch_signals(fs)
	fs.clear_burst()
	assert_null(fs._burst)
	assert_signal_emit_count(fs, "burst_ended", 0, "clear_burst with no active burst must not emit burst_ended")


# --- AC1 — edge-case clears: wave-clear + the reload race ---

func test_wave_clear_mid_burst_clears_buff() -> void:
	# Dev Notes §"⚠️ Edge cases": a burst must NOT persist into the next wave. wave_cleared mid-burst →
	# Player._on_wave_cleared → clear_burst → buff cleared + the visual reverts (burst_ended → revert).
	var arena := _make_arena()
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # rescue → dock + wing 1
	arena._player._try_sacrifice()  # burst applies
	assert_not_null(arena._player._fire_system._burst, "precondition: burst active")
	EventBus.wave_cleared.emit(1)  # wave-clear mid-burst → Player._on_wave_cleared → clear_burst.
	assert_null(arena._player._fire_system._burst, "wave-clear must clear an active burst")
	assert_false(arena._player._burst_active, "wave-clear must revert the burst visual")
	await get_tree().physics_frame


func test_respawn_clears_burst() -> void:
	# Dev Notes §"⚠️ Edge cases": a fresh ship does NOT carry the dead ship's burst. respawn() (called by
	# the Arena on both ship-loss paths: HP-death + capture) calls clear_burst → buff cleared + visual
	# reverts. Driven directly via respawn() (the Arena's respawn entry).
	var arena := _make_arena()
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)
	arena._player._try_sacrifice()  # burst applies
	assert_not_null(arena._player._fire_system._burst, "precondition: burst active")
	arena._player.respawn()  # the fresh-ship entry → clear_burst.
	assert_null(arena._player._fire_system._burst, "respawn must clear an active burst")
	assert_false(arena._player._burst_active, "respawn must revert the burst visual")


func test_sacrifice_during_reload_does_not_apply_burst() -> void:
	# Dev Notes §"⚠️ Edge cases" (the game_over/reload race): a sacrifice committing against a RunState
	# about to be torn down must NOT apply the burst (FireSystem mutation). The Arena's _reload_in_flight
	# guard skips the apply (the signal emit is harmless — nothing subscribes that mutates run state).
	var arena := _make_arena()
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # dock
	arena._reload_in_flight = true  # simulate "game_over emitted + reload queued".
	arena._player._try_sacrifice()  # consume → Arena handler → guard skips the apply.
	assert_null(arena._player._fire_system._burst, "a sacrifice during the reload window must NOT apply a burst")
	await get_tree().physics_frame


# --- AC4 — no ship spend (FR18) + no artificial cooldown ---

func test_sacrifice_does_not_spend_ship() -> void:
	# FR18 regression (AC4 economy): sacrifice is ship-neutral. The burst applies but ships UNCHANGED —
	# only capture (−1) + keep (+1) move ships. The burst is the reward, not a ship spend.
	var arena := _make_arena()
	watch_signals(EventBus)
	arena._spawner.captor_resolved.emit(true, arena._player.global_position)  # dock
	var ships_before: int = arena._run_state.ships
	arena._player._try_sacrifice()  # sacrifice → burst applies, NO spend_ship.
	assert_not_null(arena._player._fire_system._burst, "precondition: the burst applied")
	assert_eq(arena._run_state.ships, ships_before, "sacrifice must NOT spend a ship (FR18)")
	assert_signal_emit_count(EventBus, "ship_lost", 0, "sacrifice emits no ship_lost")
	await get_tree().physics_frame


func test_no_sacrifice_cooldown_field_exists() -> void:
	# AC4: NO artificial cooldown between sacrifices — the limiter is structural (one docked ship per wave
	# → at most one sacrifice per wave; forfeits keep-regain). Structural source assertion (mirrors
	# test_fire_system's no-per-frame-allocations grep): the Player + Arena scripts have no cooldown-ish
	# field for sacrifice. Do NOT add last_sacrifice_time / _sacrifice_cooldown etc.
	for path in ["res://player/player.gd", "res://world/arena.gd"]:
		var src: String = (load(path) as GDScript).source_code
		assert_false(src.containsn("sacrifice_cooldown"), "%s: AC4 — no sacrifice cooldown field" % path)
		assert_false(src.containsn("last_sacrifice"), "%s: AC4 — no last-sacrifice timestamp" % path)
		assert_false(src.containsn("sacrifice_ready"), "%s: AC4 — no sacrifice readiness flag" % path)


func test_repeated_burst_apply_is_not_throttled() -> void:
	# Review fix: the source-grep above only pins a NAMING convention (trivially defeated by a
	# differently-named throttle, e.g. `_burst_lock_until`). This is the BEHAVIORAL companion — apply_burst
	# is documented as "re-entrant safe: a burst already active is simply replaced" (AC4). Immediately
	# re-applying (zero elapsed time, as a back-to-back sacrifice would) must refresh the window rather
	# than being blocked/ignored by any hidden throttle.
	var fs: FireSystem = _make_fs()
	fs.apply_burst(SacrificeBurst.new(1.0, 10.0))
	fs._physics_process(1.0 / 60.0)  # tick once while the first burst is active.
	fs.apply_burst(SacrificeBurst.new(2.0, 10.0))  # a second "sacrifice", no elapsed cooldown.
	assert_not_null(fs._burst, "the second burst must apply, not be throttled")
	assert_almost_eq(fs._burst.power, 2.0, 0.0001, "the second burst's power takes effect immediately")
	assert_almost_eq(fs._burst_time_left, 10.0, 0.01, "the second burst refreshes the full duration window")
