---
baseline_commit: 38138f1bbf8fa502df76b0f76637a29254208d30
---

# Story 1.5: Life & Health Economy

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want a clear 3-ships × 3-HP system where HP heals each wave and losing my last ship ends the run,
so that tension lives in ship attrition while each wave stays survivable.

## Acceptance Criteria

*(Source: `planning-artifacts/epics.md` Story 1.5 (lines 357–371) — FR8, FR9, FR10, FR11, FR12, FR49 · AR2)*

1. **Given** a new run, **Then** the player has **3 ships (cap 5)** and **base 3 HP**; ships are only spent/bet (no farming source exists in E1).
2. **Given** the player is hit by standard enemy fire, **Then** it deals **1 damage**; heavy/elite (Bomber) shots deal **2 damage**; **after any hit, the player has 1 s i-frames** (further hits in that window are ignored).
3. **Given** the player's HP reaches 0 within a wave, **Then** the current ship is lost (**−1 ship**) and the next ship **respawns at full HP** (with a fresh i-frame window).
4. **Given** a wave is cleared (timer expires), **Then** HP **fully heals before the next wave**.
5. **Given** the player's ships reach **0**, **Then** the run **ends (loss)**; score is **cumulative and display-only** (never spent).

**Implicit / end-to-end requirements (the dev agent owns these — an implementation must leave the system working end-to-end, not just satisfy the letter of the ACs):**

- **Damage values are ALREADY wired by Story 1.4** — the existing `EnemyProjectile._on_body_entered` calls the player's `HealthComponent.take_damage(fire_damage)` (1 for Grunt/Shielder, 2 for Bomber). AC2's only *new* deliverable is the **1 s i-frame window**. Do not re-implement damage routing.
- **Score must move to a proper run-scope owner.** Story 1.4 left score as a private `_run_score` accumulator on `FormationSpawner` (an admitted placeholder — see Dev Notes). AR2 (state ownership) puts Score on `RunState`. E1 must fix this: score accumulates across waves in `RunState`, never resets mid-run, and is never spent (FR49).
- **The wave-clear heal needs a hook.** Story 1.4's `FormationSpawner` ends the wave on a timer but emits nothing and heals nothing (deferred to 1.5). E1 must wire: timer-expiry → `wave_cleared` → player HP reset → a minimal next-wave loop so the ship economy is testable across multiple waves. The full lifecycle FSM (intro/reward/shop/replay) stays in Story 1.8.
- **Story 1.3 regression guard:** the player's vertical-fire `body_entered` hit path against `CharacterBody2D` enemies on `LAYER_ENEMY` must still apply `take_damage()` to enemy `HealthComponent`s. Enemies must still damage the player. Neither hit path may regress.
- **i-frames must not regress pooled enemies.** Enemies use the same `HealthComponent`. The i-frame mechanism must default to OFF (enemies never get i-frames) and must reset correctly on pool re-`activate()`.

---

## Tasks / Subtasks

### Task 1 — `RunState` spine + Constants + EventBus clarify (AC: #1, #5)

- [x] 1.1 Create `run/run_state.gd` — `class_name RunState extends Resource` (AR2/D1: Resource-backed run state; runtime-only — **no `.tres`**, instantiated via `.new()`). **Pure data + methods, NO `EventBus` calls, NO signals** (keeps it unit-testable; the Node layer emits bus signals — see Task 4/5). Field set:
  - `var ships: int` — current lives (run economy). Initialized in `begin_run()`.
  - `var score: int` — cumulative, display-only (FR49). Initialized to 0 in `begin_run()`.
  - `func begin_run() -> void` — `ships = Constants.BASE_SHIPS` (3); `score = 0`. The E1 run-host (Arena) calls this on start/respawn-of-run.
  - `func spend_ship() -> int` — `ships = maxi(ships - 1, 0)`; **return the post-spend `ships` count** (the caller decides respawn-vs-game-over on `remaining == 0`). Floors at 0 (dev-invariant `assert(ships >= 0)`).
  - `func add_score(amount: int) -> void` — `score += maxi(amount, 0)` (never decrements — score is display-only; no `spend_score`).
  - `func add_ship(amount: int = 1) -> void` — `ships = mini(ships + amount, Constants.MAX_SHIPS)` (cap 5, FR8). **Forward-compat for E2/E3 ship-gain sources (capture-keep regain, shop +ship power-ups). E1 has NO caller** — encode the path, exercise ×0. Unit-test the cap.
  - `func reset() -> void` — alias to `begin_run()` semantics (clear for a fresh run; used on game-over replay).
  - `extends Resource` (not `RefCounted`) to match architecture line 504 ("Resource-backed run state"). It is **never persisted** (D5 — runs are in-memory, no resume), so do not add a save path.
- [x] 1.2 Add `MAX_HP` to `systems/constants.gd` (deferred-work item from the 1.1 code review): `const MAX_HP: int = 3` (the HP cap; grows via build in E3's +HP-cap power-up — encode the path, exercise 3 in E1). `BASE_HP`/`BASE_SHIPS`/`MAX_SHIPS` already exist — leave them. **No i-frame constant here** (i-frame duration is a player feel-param → `player_tuning.tres`, Task 2.2).
- [x] 1.3 `systems/event_bus.gd` — rename the existing `signal ship_lost(remaining: int)` → `signal ship_lost(ships_remaining: int)` (deferred-work item: "parameter name is ambiguous — ships? HP?"). **Safe — the signal is declared but has zero emitters/listeners today.** Disambiguates ships (lives) from HP. `game_over`, `wave_cleared(wave: int)`, `score_changed(score: int)`, `run_started`, `build_changed` stay as-is.
- [x] 1.4 Unit test `tests/run/test_run_state.gd` (pure-logic, `extends GutTest`, no scene instantiation — mirrors `tests/components/test_health_component.gd`'s pure-logic style): `begin_run()` → ships==3, score==0; `spend_ship()` decrements and returns remaining; ships floors at 0 (never negative); `add_ship()` clamps at `Constants.MAX_SHIPS` (5); `add_score()` accumulates, ignores negatives; `reset()` restores to 3/0. Mirror the `before_each()` → fresh `RunState.new()` pattern.

### Task 2 — `HealthComponent` i-frames + `PlayerTuning` iframe field (AC: #2)

- [x] 2.1 Extend `components/health_component.gd` with an i-frame window. The component is the damage gate (enemy projectiles call `take_damage` directly via the node-name convention — see Story 1.4 key decision #2), so i-frames belong HERE, not on the player (otherwise the hit lands in the component and must be retroactively undone). Add:
  - `@export var invuln_after_hit_s: float = 0.0` — i-frame window granted after a damaging hit. **Default 0.0 = no i-frames** so enemies (which use this same component) are unaffected and pooled-enemy re-init does not regress.
  - `var _invuln_timer: float = 0.0` — remaining invulnerability seconds; `> 0.0` ⇒ invulnerable.
  - `func is_invulnerable() -> bool` — `return _invuln_timer > 0.0` (public — the player flickers on it; debug/HUD may read it).
  - `func set_invuln(seconds: float) -> void` — `_invuln_timer = maxf(seconds, 0.0)`; public so respawn (Task 3) can grant a window without taking a hit.
  - `_process(delta)` — decrement `_invuln_timer = maxf(_invuln_timer - delta, 0.0)`. (Use `_process`, not `_physics_process` — i-frames are a timing window, not physics-driven; this also avoids double-ticking when the entity's physics is disabled.)
  - `take_damage(amount)` — **early-return if `is_invulnerable()`** (no damage, no `health_changed` emit, no `died` — the hit is fully ignored). On a real damaging hit (HP actually decreases), grant the window: `if invuln_after_hit_s > 0.0: set_invuln(invuln_after_hit_s)`. Keep the existing clamp/floor/once-only-`died` logic intact.
  - `reset_to_full()` — also clear `_invuln_timer = 0.0` (a fresh-full ship starts vulnerable; respawn grants its own window via `set_invuln`).
  - `heal()` — unchanged (pure clamp; still no revive-from-zero — see Dev Notes §"Revive semantics").
  - Update the header comment: the "BUILT REAL BUT NOT WIRED" caveat is now satisfied — damage sources (1.4), wave-reset callers, and the i-frame window all land here.
- [x] 2.2 Add the i-frame feel-param to the player tuning pair (data-driven discipline — every tunable is a `.tres`):
  - `player/player_tuning.gd` — `@export var iframe_s: float = 1.0` (GDD line 108: "i-frames 1 s after each hit"). Group it with the existing combat fields.
  - `resources/player_tuning.tres` — set `iframe_s = 1.0`.
- [x] 2.3 Extend `tests/components/test_health_component.gd` with i-frame cases (do not regress the existing damage/heal/died/reset tests): with `invuln_after_hit_s = 1.0`, a `take_damage` that deals HP grants the window; a second `take_damage` during the window is a no-op (HP unchanged, no `health_changed`, no `died`); after the window expires (simulate via `_process(1.0)` or `set_invuln(0.0)`), damage applies again; `is_invulnerable()` tracks the timer; default `invuln_after_hit_s = 0.0` ⇒ never invulnerable (regression guard for enemies); `reset_to_full()` clears the timer. Use GUT `watch_signals` / `assert_signal_emit_count` (the existing test already uses these — GDScript lambdas capture primitives by value).

### Task 3 — Player damage/respawn wiring (AC: #2, #3)

- [x] 3.1 Wire `player/player.gd` to the ship economy. The player **owns per-ship mechanics** (wave scope); run-scope decisions (ship count, game-over) live on Arena (Task 4). Add:
  - In `_ready()`: apply the tuning i-frame to the health gate — `_health.invuln_after_hit_s = _tuning.iframe_s` (read `_tuning` the same way the existing move/fire params do; `iframe_s` from Task 2.2). Cache `_visual` (`@onready`) if not already.
  - Connect `_health.died` → `_on_ship_depleted()` **once** in `_ready()` (persists across the run; the player is NOT pooled so no re-connect concern). `_health.died` fires when HP hits 0 within a wave.
  - `signal ship_depleted()` — **local signal** (D8: intra-entity→parent comms stay direct; this is the player telling its parent "I lost a ship"). NO payload (the run host owns the count).
  - `_on_ship_depleted()` — `emit ship_depleted()` (the player's HP=0 → Arena decides respawn vs game-over). Do **not** call `RunState` from the player (AR2: ships are run-scope; the player must not own them).
  - `func respawn() -> void` — public; called by Arena when a ship is lost but `remaining > 0`. Body: `_health.reset_to_full()` (clears `_is_dead`, restores HP to `max_hp`), reposition to lane center (`global_position.x = Constants.BASE_RESOLUTION.x / 2.0`; keep `global_position.y` at the lane), and grant a fresh i-frame window (`_health.set_invuln(_tuning.iframe_s)` — fair re-entry into fire-columns). No screen-clear, no full heal of *ships* — only HP.
  - In `_process(delta)` (add if absent): minimal invuln feedback — while `_health.is_invulnerable()`, flicker `_visual.modulate.a` (e.g. `0.5 + 0.5 * sin(t * 30.0)`); else restore `modulate.a = 1.0`. **This is a placeholder — Story 1.6 owns the full hit-flash/juice pass.** One cheap line so i-frames are *visible* for testing; do not build a particle/flash system here.
- [x] 3.2 Integration test `tests/player/test_player_health.gd` (mirror `tests/player/test_projectile.gd` / `test_enemy.gd`'s fixture style): instantiate `player.tscn`; `_health.invuln_after_hit_s` is set from tuning (1.0) after `_ready`; `take_damage` below lethal → `health_changed`, no `ship_depleted`; drive HP to 0 → `died` fires once, player emits `ship_depleted` once; call `respawn()` → HP back to `max_hp`, `_is_dead == false`, `is_invulnerable() == true`, `global_position.x` at center; i-frames block a second lethal hit during the window. Use `add_child` (not `autofree`) + `await get_tree().physics_frame` where engine signals are involved.

### Task 4 — Arena run-host: ship-loss, game-over, wave loop (AC: #1, #3, #4, #5)

- [x] 4.1 Make `world/arena.gd` the **E1 run host** (it already calls `_spawner.begin_wave(1)` — extend it). It owns the `RunState` instance, wires it into the spawner + player, and orchestrates run-scope decisions. Add:
  - `@onready var _run_state: RunState = RunState.new()` (or construct in `_ready`). Call `_run_state.begin_run()` on start.
  - Inject `_run_state` into the spawner: `_spawner.run_state = _run_state` (Task 5 adds the property). The spawner routes score through it. **Inject BEFORE `_spawner.begin_wave(1)`** — children's `_ready` fires before Arena's (bottom-up), so `_spawner`/`_player` exist; wire run_state + signal connections, then start the wave.
  - Connect `_player.ship_depleted` → `_on_player_ship_depleted()`.
  - `_on_player_ship_depleted()`: `var remaining := _run_state.spend_ship()`; if `remaining > 0`: `_player.respawn()`; `EventBus.ship_lost.emit(remaining)`. Else: `_on_run_lost()`.
  - `_on_run_lost()`: `EventBus.game_over.emit()`; stop the spawner (`_spawner.set_active(false)` or equivalent — see Task 5.2); **E1 placeholder** — `_end_run.call_deferred()` where `_end_run()` does `Pool.clear()` then `get_tree().reload_current_scene()` (starts a fresh run: new `RunState` via `_ready`, ships back to 3, score 0). **🚨 CRITICAL — defer the reload + Pool.clear.** `_on_player_ship_depleted` runs synchronously inside the physics step (the chain is `enemy_projectile._on_body_entered` → `take_damage` → `died` → `ship_depleted` → here, all during `_physics_process`). Calling `reload_current_scene()` / mutating the Pool mid-physics-step frees/mutates the tree while the engine is mid-collision — **must defer to idle** via `call_deferred` (same class of gotcha as the deferred `Pool.release` in Story 1.4). `EventBus.game_over.emit()` itself is safe to fire synchronously. See Dev Notes §"Run-end & Pool on replay". **The real game-over screen / menu flow is Epic 8 (Story 8.4).**
  - Track wave number for the loop: `var _wave_num: int = 1`.
- [x] 4.2 Wire the wave-clear heal + minimal next-wave loop (AC4):
  - In `_ready()`: `EventBus.wave_cleared.connect(_on_wave_cleared)`.
  - `_on_wave_cleared(_wave: int)`: `_player._health.reset_to_full()` (full HP before the next wave — AC4); `_wave_num += 1`; `_spawner.begin_wave(_wave_num)` (restart the spawner for the next wave — Task 5.2 ensures `begin_wave` is restartable).
  - **Boundary:** this minimal heal+increment loop is a strict subset of Story 1.8's full wave-lifecycle FSM (which adds intro state, reward/shop interlude, debug cheats, authored feel-gate assembly, proper replay). 1.8 replaces Arena's loop; do not build the interlude/reward UI here.
- [x] 4.3 Integration test `tests/world/test_arena.gd` (new; mirror `tests/world/test_formation_spawner.gd`): construct Arena (or its scene), verify `_run_state.ships == 3` at start; simulate `player.ship_depleted` → with ships remaining, `respawn()` called + `EventBus.ship_lost` emitted with the right remaining count; simulate depletion until `ships == 0` → `EventBus.game_over` emitted; `EventBus.wave_cleared` → player HP reset to full + `_wave_num` incremented. Assert on state/signals (GUT `watch_signals`), not pixels. Stub `reload_current_scene` (or guard the game_over test so it doesn't actually reload mid-suite — e.g. assert `game_over` emitted, then stop).

### Task 5 — `FormationSpawner`: score→`RunState` + `wave_cleared` emit (AC: #4, #5)

- [x] 5.1 Move score ownership off the spawner. `world/formation_spawner.gd`:
  - Add `var run_state: RunState` (set by Arena in `_ready` before the wave begins — Task 4.1).
  - In `_on_enemy_died(score_value)` (the existing `enemy.died` handler): replace `_run_score += score_value` with `run_state.add_score(score_value)`; emit `EventBus.score_changed.emit(run_state.score)`. **Delete the `_run_score` field.** (Score is now run-scope/cumulative on `RunState` — AR2/FR49.) Guard `run_state == null` (Log.err once, no crash — AR11) so the spawner degrades safely if Arena hasn't wired it yet.
- [x] 5.2 Emit `wave_cleared` on timer-expiry and make `begin_wave` restartable:
  - At the existing timer-expiry point (where `_wave_time > wave_duration_s` triggers `set_physics_process(false)` + `_despawn_survivors()`): **after `_despawn_survivors()`, add `EventBus.wave_cleared.emit(_wave_num)`** (clear the board first, then signal — Arena's heal doesn't touch enemies, but starting `begin_wave(n+1)` on a clean board is safest). Cache the wave number from the `begin_wave(n)` arg as `_wave_num`.
  - Ensure `begin_wave(n: int)` is **restartable** (it is called again by Arena's wave loop, Task 4.2): it must reset `_wave_time = 0.0`, cache `_wave_num = n`, clear/reseed the pulse schedule, and re-enable `set_physics_process(true)`. **Read the existing `begin_wave` and verify/extend** — if it only runs once today, make it idempotent. Do not change the spawn-budget math (`min(per_tick_base + ⌊n × per_tick_growth⌋, max_per_tick)` — FR30) or the drip-pulse model.
  - Provide `func set_active(active: bool) -> void` (or reuse `set_physics_process`) so Arena can stop spawning on game-over (Task 4.1).
- [x] 5.3 Update `tests/world/test_formation_spawner.gd`: inject a `RunState` on the spawner; an enemy death → `run_state.score` increases + `EventBus.score_changed` fires with `run_state.score` (assert via `watch_signals`); on timer-expiry → `EventBus.wave_cleared` fires with the wave number; `begin_wave` called twice (wave 1 then 2) restarts cleanly (no stacked signals, `_wave_time` resets). Existing spawn-budget/drip assertions must still pass (regression).

### Task 6 — Regression, housekeeping, verification

- [x] 6.1 Run `godot --headless --import` once (registers the new `RunState` `class_name` + the modified `HealthComponent`/`PlayerTuning` exports) — the established gotcha from Story 1.1/1.2/1.4 reviews (new/changed `class_name`s and `@export`s need a reimport to resolve in scenes/tests).
- [x] 6.2 Run the full GUT suite headless: `godot --headless -s addons/gut/gut_cmdln.gd`. **All prior tests (1.1–1.4) must still pass** — especially `tests/player/test_projectile.gd` (player projectile still hits `CharacterBody2D` enemies), `tests/enemies/test_enemy*.gd` (enemy `HealthComponent` still damages/dies correctly with the new i-frame default = 0), and `tests/components/test_health_component.gd` (existing damage/heal/died/reset cases unchanged). `before_each()` in every new test file calls `Pool.clear()` (Pool is an autoload — state persists across tests).
- [x] 6.3 Remove the `.gdkeep` placeholder from `run/` (now populated by `run_state.gd`). Confirm `tests/run/` exists.
- [x] 6.4 Headless game launch (`timeout 8 godot --headless --path .`): no runtime errors; survive a wave → HP heals on `wave_cleared`; take 3 lethal hits across the run → on the 3rd ship loss, `EventBus.game_over` fires and the scene replays with ships back at 3. Verify the i-frame window blocks a quick second hit (no double ship-loss from one contact). No hit-flash/particles yet (Story 1.6).

### Review Findings

- [x] [Review][Patch] `Pool.clear()` leaks detached pooled nodes on every game-over replay [systems/pool.gd:54-60] — `release()` detaches nodes from the tree via `remove_child()` and keeps them alive only in `Pool._pools`'s Arrays; Godot 4 `Node` is not `RefCounted`, so `_pools.clear()` dropping the Dictionary references never frees them, and `reload_current_scene()` only frees tree-attached nodes — inactive pooled enemies/projectiles leak on every loss→replay cycle. `Pool.clear()`'s own doc comment ("test-support hook only — not called by gameplay code") is now stale since `world/arena.gd`'s `_end_run()` calls it from real gameplay. **Fixed:** `clear()` now `.free()`s every valid node in `_pools` before clearing the dicts; doc comment updated. 120/120 tests pass.
- [x] [Review][Patch] `Constants.MAX_HP` is added but never referenced or exercised anywhere [systems/constants.gd:21] — Task 1.2 said "encode the path, exercise 3 in E1" (cf. `RunState.add_ship()`, which despite having no E1 caller is still unit-tested against `Constants.MAX_SHIPS`). `HealthComponent.max_hp` still defaults to a bare literal `3`, unconnected to the new constant, and no test asserts it. **Fixed:** added a dev-invariant `assert(_health.max_hp <= Constants.MAX_HP, ...)` in `player.gd`'s `_ready()` — scoped to the player, not the shared `HealthComponent` (enemies have unrelated `max_hp` values, e.g. 100 for a Bomber; my first attempt wrongly put the assert on the shared component and broke 4 enemy tests — moved it to `player.gd` and reran the full suite clean).
- [x] [Review][Patch] `RunState.add_ship()` has no negative-amount guard, unlike its sibling `add_score()` [run/run_state.gd] — `add_score()` clamps with `maxi(amount, 0)`; `add_ship()` does not, so a future caller passing a negative amount could push `ships` below 0, silently violating `spend_ship()`'s asserted invariant. Currently unreachable (no E1 caller) but a one-line fix for a documented forward-compat API. **Fixed:** `add_ship()` now clamps its `amount` arg with `maxi(amount, 0)`; added `test_add_ship_ignores_negatives`.
- [x] [Review][Patch] `player.respawn()` doesn't reset `velocity` to zero [player/player.gd] — if the player was moving at the instant of the lethal hit, stale `CharacterBody2D.velocity` could carry into the very first post-respawn physics frame before input overwrites it. **Fixed defensively:** `velocity = Vector2.ZERO` added to `respawn()`. (Verified this specific failure mode can't currently manifest — `_physics_process` recomputes `velocity` fresh from input every frame with no inertia model — so this is a defensive/clarity addition, not a fix for an observed bug.)
- [x] [Review][Patch] `Arena._end_run()` ignores the `Error` return of `get_tree().reload_current_scene()` [world/arena.gd] — inconsistent with this same changeset's own defensive-logging pattern (e.g. the new `Pool.acquire` `is_instance_valid` guard). **Fixed:** logs via `Log.err` if the return is not `OK`.
- [x] [Review][Patch] Trailing whitespace-only diff hunk (bare blank line) appended at end of `player/player.gd` — trivial cleanup. **Fixed:** trailing blank line removed.
- [x] [Review][Defer] `FormationSpawner.set_active(true)` called while `_wave_time` already exceeds `wave_duration_s` would re-fire `wave_cleared` and double-advance the wave [world/formation_spawner.gd:79-82] — deferred, no current call site triggers this (only `set_active(false)` is called in 1.5; `set_active(true)`-after-stale-time is a latent footgun for Story 1.8's richer wave/pause control, not exploitable today).
- [x] [Review][Defer] `HealthComponent.heal()` can leave `current_hp > 0` while `_is_dead == true` with no guard [components/health_component.gd] — deferred, this is the explicitly-acknowledged landmine from Dev Notes §"Revive semantics" ("heal() stays a pure clamp... no code change needed"); real but only reachable once a future story (E3 shield power-up) calls `heal()` on a dead entity.
- [x] [Review][Defer] `Arena.auto_replay_on_loss` is an inspector-exposed `@export` whose sole purpose is a test-isolation seam [world/arena.gd] — deferred, explicitly an E1 placeholder per Dev Notes; Story 8.4 replaces the whole game-over/replay flow with a real screen and can retire this toggle then.

**Dismissed as noise/false-positive (verified, no action):** `$Visual`/`Player` cast concerns (confirmed present/valid in `player.tscn`/`arena.tscn`); the `wave_cleared` synchronous signal-reentrancy pattern (confirmed safe — no tree mutation mid-physics-step, unlike the documented Pool/reload hazard); `RunState.reset()` being unused in production (deliberate forward-compat, same precedent as `add_ship()`, for the Story 4-7 `GameManager` ownership migration); the unreachable `assert(ships >= 0)` in `spend_ship()` (matches the project's stated dev-invariant-assert convention); the `is_connected` guard's "no re-connect concern" comment (harmless defensive code, comment nitpick only); a supposed stale `Pool._node_paths` entry from the new `is_instance_valid` guard (verified not an issue — `release()` already erases that entry before the node re-enters the pool array); `set_invuln()` NaN/+INF handling (no reachable call site ever passes non-finite values); self-reported test-count/"Agent Model Used" field oddities (meta noise, not code findings); the `ship_lost` rename "safe" claim (unverifiable from this diff but out of scope — prior-story concern); `take_damage()` emitting `health_changed` on a zero/no-op hit (pre-existing behavior, not introduced by this diff); the `0.5` vs `0.05` float-tolerance convention in one new test (trivial style nit, deterministic value); i-frame duration tested via manual `_process(1.0)` at the unit level rather than real-time at integration level (adequate combined coverage — unit test proves the timer mechanics, integration test proves the tuning value is wired).

---

## Dev Notes

### 🔑 Key decisions (read these first — they resolve the open forks the architecture left to this story)

1. **Ships + score live on a thin `run/run_state.gd` (Resource) NOW — not deferred to E4, and NOT an autoload.** AR2 (state ownership) is explicit: ships/score → `RunState` (run scope); HP → `HealthComponent` (wave scope, reset each wave). The *full* `RunState` (seed/currency/build-ladders) is Epic 4 (Story 4-6), but ships+score are **load-bearing for E1's ship-economy gate** — without them, AC1/AC3/AC5 cannot be satisfied or tested. So build the thin spine now (the 1.4 precedent: "encode the path, exercise the v0.1 slice"). It is a **`Resource`, not an autoload** — `RunState` is deliberately absent from the autoload registry (architecture's registry order lists 11 autoloads; `RunState` is not among them). It is owned by the **Arena** (the E1 run host), passed explicitly to the spawner, and ownership migrates to `GameManager` when its FSM lands in Story 4-7. This also **fixes the 1.4 score smell** (score was a private `_run_score` on `FormationSpawner`).
2. **i-frames live on `HealthComponent`, gated by `@export var invuln_after_hit_s: float = 0.0`.** The component is the damage gate: enemy projectiles call `take_damage` directly via the `body.get_node_or_null("HealthComponent")` convention (Story 1.4 key decision #2). Putting i-frames on the player would mean the hit still lands in the component and the player must retroactively undo it — messy and race-prone. Default `0.0` keeps **enemies i-frame-free** (they don't need it; and pooled-enemy re-`activate()` must not regress). The player sets it from `player_tuning.iframe_s` (1.0) in `_ready()`. **Deliberate feel choice: during i-frames the player is *damage-immune*, not *intangible*** — the existing `EnemyProjectile._on_body_entered` path still consumes the bullet (`_consumed = true` → deferred release) but `take_damage` is a no-op (0 dmg). So bullets vanish on contact with an invulnerable ship rather than passing through. This is the minimal, race-free behavior; if playtest finds the "bullet vacuum" reads oddly, making the player intangible (toggle the player's `collision_mask`/layer or the projectile's consumption during the window) is a Story 1.6/1.8 refinement — **do not build intangibility in 1.5.**
3. **Player owns per-ship mechanics (wave scope); Arena owns run-scope decisions.** `HealthComponent.died` (HP=0 within a wave) is a **local** signal → the player connects it and emits a **local `ship_depleted`** signal (intra-entity→parent — D8). **Arena** listens → `_run_state.spend_ship()` → if `remaining > 0`: `player.respawn()` + `EventBus.ship_lost.emit(remaining)`; else `EventBus.game_over`. This honors AR2 (ships on `RunState`, HP on `HealthComponent`) AND D8 (`died`/`ship_depleted` local; `ship_lost`/`game_over` global on `EventBus`). The player never touches `RunState` directly.
4. **Revive semantics RESOLVED (deferred-work item from the 1.2 review): `heal()` stays a pure clamp (no revive-from-zero); revival is exclusively `reset_to_full()`** (which already clears `_is_dead`), used at respawn and wave-clear. Healing a "dead" ship is never a thing — a dead ship either respawns (new ship, full HP) or the run ends. `reset_to_full()` is correct as-is; do not add revive logic to `heal()`.
5. **`wave_cleared` + per-wave heal land in 1.5 (AC4); the full lifecycle FSM stays in 1.8.** `FormationSpawner` already detects timer-expiry and despawns survivors (Story 1.4) — add `EventBus.wave_cleared.emit(wave)` there. Arena subscribes → `player._health.reset_to_full()` → minimal next-wave loop (`begin_wave(n+1)`). Story 1.8 replaces this loop with the real `wave_controller` FSM (intro/reward/shop/replay + the feel gate). Same boundary discipline as 1.4 (minimal precursor now; full system later).
6. **Do NOT build `HurtboxComponent`/`HitboxComponent` in 1.5.** The node-name `HealthComponent` lookup stays (Story 1.4 key decision #2 — deferred "until multi-shape hitboxes are needed"). The docked-ship bigger-hitbox / first-hit absorber is **Epic 2** (Story 2-4). A dev agent may be tempted to "helpfully" introduce Area2D hitbox components here — **don't**; it is scope creep and would force reworking the established `body_entered` hit paths in both player and enemy projectiles (regressing 1.3/1.4).

### 📊 Life & Health Economy — values (GDD §"Life & Health Economy" lines 101–110 / FR8–FR12 — authoritative)

| Quantity | Value | Scope | Owner | Source |
|---|---|---|---|---|
| Ships (lives) at run start | **3** | run | `RunState.ships` | FR8 / GDD 105 |
| Ship cap | **5** | run | `Constants.MAX_SHIPS` (exists) | FR8 / GDD 105 |
| HP per ship (base) | **3** | wave | `HealthComponent.max_hp` (default = `Constants.BASE_HP`) | FR10 / GDD 106 |
| HP cap | **3** (grows via build in E3) | run | `Constants.MAX_HP` (NEW, Task 1.2) | GDD decision-log 58 |
| Standard fire damage | **1** | — | `EnemyDefinition.fire_damage` (Grunt/Shielder — already wired) | FR11 / GDD 108 |
| Heavy/elite damage | **2** | — | `EnemyDefinition.fire_damage` (Bomber — already wired) | FR11 / GDD 108 |
| i-frames after a hit | **1 s** | wave | `player_tuning.iframe_s` → `HealthComponent.invuln_after_hit_s` (NEW) | FR11 / GDD 108 |
| HP on wave clear | full heal | wave | `HealthComponent.reset_to_full()` on `wave_cleared` | FR10 / GDD 106 |
| HP on ship loss (respawn) | full heal + i-frame window | wave | `player.respawn()` | FR12 / GDD 110 |
| Run end | ships == 0 | run | `RunState.spend_ship()` → `EventBus.game_over` | FR8 / GDD 169 |

**Damage values (1/2) are ALREADY wired by Story 1.4** (`EnemyProjectile._on_body_entered` → `take_damage(fire_damage)`). Do not re-implement; AC2's only new work is the i-frame window.

### Signal boundary (AR7 / D8)

- **Direct/local signals** (declare on the owning script, connect directly):
  - `HealthComponent.health_changed(current, maximum)`, `HealthComponent.died` — already local (1.2/1.4).
  - `player.ship_depleted()` — **NEW local signal** (player → Arena; intra-entity→parent).
- **EventBus** (global game-flow only — typed, past-tense):
  - `ship_lost(ships_remaining: int)` — emitted by Arena on each ship loss (clarified param, Task 1.3).
  - `game_over` — emitted by Arena when `ships == 0` (declared since 1.1; **first emit site**).
  - `wave_cleared(wave: int)` — emitted by `FormationSpawner` on timer-expiry (declared since 1.1; **first emit site**).
  - `score_changed(score: int)` — emitted by `FormationSpawner` after `run_state.add_score` (existing; now reads `run_state.score`).
- **Do NOT add** `health_changed`/`player_died`/`respawned`/`ship_depleted` to `EventBus` (D8: don't route everything through the bus; HP/respawn are intra-entity). `health_changed` stays on `HealthComponent` for the HUD (Story 1.7) to connect directly to the player.
- Note: architecture line 421 references `EventBus.run_failed` as a *critical-engine-error* safe-fail signal — that is a **different concept** from `game_over` (player loses last ship). `run_failed` is not declared yet and is not this story's concern; use `game_over` for the loss event.

### Collision layers (unchanged — no `constants.gd` layer change)

```gdscript
const LAYER_PLAYER: int = 1            # bit 0  ← player body (is the hurtbox today)
const LAYER_ENEMY: int = 2             # bit 1
const LAYER_PLAYER_PROJECTILE: int = 4 # bit 2
const LAYER_ENEMY_PROJECTILE: int = 8  # bit 3  ← masked to LAYER_PLAYER (1)
const LAYER_PICKUP: int = 16           # bit 4
```
- Player body: `collision_layer = LAYER_PLAYER` (1); `collision_mask = 0` (player initiates no physical collisions — unchanged from 1.2).
- Enemy projectile: `collision_layer = LAYER_ENEMY_PROJECTILE` (8); `collision_mask = LAYER_PLAYER` (1) — so enemy bullets `body_enter` the player and call `take_damage`. **Already correct from 1.4.**
- The player body **is** the hurtbox (no separate `HurtboxComponent` — see Key Decision #6). i-frames are enforced inside `HealthComponent.take_damage`, so the existing `body_entered` path is untouched.

### Revive semantics (deferred-work item, resolved)

The 1.2 code review flagged: "`HealthComponent.heal()` doesn't clear `_is_dead` when healed above zero — 1.5 decides revive semantics." **Decision: `heal()` stays a pure clamp (cannot revive from 0); `reset_to_full()` is the only revive path** (clears `_is_dead`, restores HP), called at (a) respawn (new ship) and (b) wave-clear (full heal). Rationale: in this economy, HP=0 means *ship lost* — there is no "heal the dead ship back to life" action; the ship is either replaced (respawn) or, if it was the last, the run ends. `heal()` remains for future within-wave chip-heal (e.g. a hypothetical shield power-up in E3) which should never revive. No code change to `heal()` needed — it is already correct; document the decision in a comment.

### Run-end & Pool on replay (gotcha)

On `game_over`, Arena does `Pool.clear()` + `get_tree().reload_current_scene()` (E1 placeholder). **Pool is an autoload** — it holds references to pooled nodes (enemies/projectiles) that are children of the old Arena scene. `reload_current_scene()` frees the old scene tree; `Pool.clear()` first empties Pool's dicts so it stops referencing the soon-to-be-freed nodes. Pooled nodes live under the spawner's world-space container (a child of Arena), so the scene reload frees them; the fresh scene's `Pool.acquire` calls instantiate new ones. **Verify `Pool.acquire` is robust to a freshly-cleared pool** (it should be — clear just empties the dict; acquire instantiates on empty) and that no path hands a freed node back. If `Pool.acquire` lacks an `is_instance_valid` guard on reused entries, add one (defensive; matches the "fail-safe, never hard-crash" rule AR11). The real game-over/menu/restart flow is Story 8.4.

### i-frame visual feedback (boundary with Story 1.6)

i-frames are **mechanical** in 1.5 (AC2). For the dev to *test* them, they must be *visible* — so the player gets a **minimal `_visual.modulate.a` flicker** while `is_invulnerable()` (Task 3.1, one cheap line in `_process`). **Story 1.6 ("Hit Feedback & Juice") owns the polished presentation** (hit-flash, screen-shake, particle bursts via `JuiceCoordinator`/`EventBus.hit_flash_requested`). Do not build a flash/particle/shake system in 1.5 — that regresses 1.6's scope. The flicker is a placeholder 1.6 will replace/augment.

### What "respawn" means in E1 (no full lifecycle yet)

GDD line 110: "next ship respawns at full HP." In E1 there is no spawn-invulnerability state machine or death animation — respawn is **immediate**: `reset_to_full()` + reposition to lane center + grant i-frame window. No loss-of-control, no fade. Repositioning to center (not last x) is the fair default (a fire-column probably killed you where you stood); it is a playtest knob (Story 1.8 feel gate). Keep it minimal.

### Out of scope for 1.5 (do NOT build — listed to prevent scope creep)

| Item | Owner | Why deferred |
|---|---|---|
| **`HurtboxComponent`/`HitboxComponent`** | when multi-shape hitboxes needed (docked ship, E2) | Node-name `HealthComponent` lookup stays (1.4 key decision #2). |
| Capture bypasses HP / capture-respawn | Epic 2 (FR13–FR21) | The gamble loop; capture isn't in E1. |
| Docked-ship bigger hitbox / first-hit absorber | Story 2-4 (E2) | `DockedShip` entity. |
| Ship-gain sources (capture-keep regain, shop +ship, tier-cap floor) | E2/E3 | E1 has no ship-gain — `add_ship()` is encoded but uncalled. |
| HP-cap growth via build (+HP-cap power-up) | Epic 3 (FR26) | `MAX_HP` constant encoded, exercised at 3. |
| Full wave-lifecycle FSM (intro/reward/shop/replay), authored feel-gate assembly | Story 1.8 | 1.5 adds the minimal heal+next-wave loop only. |
| Hit-flash, screen-shake, particle bursts | Story 1.6 | Juice. The 1.5 i-frame flicker is a placeholder. |
| HUD (HP bar, lives pips, score readout, wave timer) | Story 1.7 | 1.5 emits the signals (`health_changed`, `ship_lost`, `score_changed`, `wave_cleared`); the HUD subscribes in 1.7. |
| `game_over` screen / menu / restart flow | Story 8.4 (E8) | 1.5 emits `game_over` + replays the scene as an E1 placeholder. |
| Debug "invincibility" cheat | Story 1.8 / 3.x | `Debug` autoload is a stub. The `HealthComponent.set_invuln()` API makes a quick god-mode trivial to add later if wanted. |
| `SeedManager` real impl, `RunGenerator`, `run_state.seed` | Epic 4 | E1 is authored; `RunState` holds ships+score only. |

### Performance / hot-path (NFR2/NFR3/NFR6, AR14)

- `HealthComponent._process` decrements one float — negligible; the player has one `HealthComponent`. (Enemies use the same component but `invuln_after_hit_s = 0` ⇒ the timer stays 0 ⇒ `_process` is a subtract-and-clamp. If enemy `_process` cost is a concern at 12 enemies, gate the decrement behind `if _invuln_timer > 0.0` — one branch.)
- `player._process` flicker: one `sin` + `modulate` write while invulnerable only — not per-frame when vulnerable.
- Arena/spawner additions are event-driven (`ship_depleted`, `wave_cleared`, `enemy.died`) — **zero per-frame polling added**. No `find_child`/`get_node`/`$` per frame; cache `_run_state` (Arena already holds it) and `_player`/`_spawner` via `@onready`.
- No new per-frame allocations. No `print()` (use `Log`).

### Testing (GUT — mirror the 1.4 patterns)

- `extends GutTest`; `const Scene := preload(...)`; `before_each()` calls `Pool.clear()` where pooled nodes are involved (Pool is an autoload — state persists across tests).
- **Pure-logic unit test** (`tests/run/test_run_state.gd`): no scene instantiation — `RunState` is a `Resource`; assert ships/score/cap/floor math directly.
- **Component test** (`tests/components/test_health_component.gd` extend): `HealthComponent` is a `Node` — add via `add_child`; drive `_process(delta)` directly with a fixed delta for the i-frame expiry; use `watch_signals`/`assert_signal_emit_count`/`assert_signal_emitted_with_parameters` (GDScript lambdas capture primitives by value).
- **Integration tests** (`tests/player/test_player_health.gd`, `tests/world/test_arena.gd`): instantiate scenes via `.instantiate()`; `await get_tree().physics_frame` for engine signals; assert on state/signals, never pixels. Self-releasing pooled nodes use plain `add_child` (not `autofree`).
- GUT flags `push_error`/`push_warning` during a test as failures → expected-error paths (e.g. spawner with `run_state == null`) use `assert_push_error(...)`.
- Float compares: `assert_almost_eq(..., 0.05)`.

### Project Structure Notes

- **Co-located by domain** (Option A): `run/run_state.gd` lives under `run/` (the roguelite-spine domain — architecture line 503–504). It is the first real file in `run/` (was `.gdkeep`); `build_state.gd`/`run_generator.gd` join it in E3/E4. `tests/run/test_run_state.gd` mirrors the domain.
- `RunState` is a runtime `Resource` instance — **no `.tres`** under `resources/` (it is not content; it is per-run mutable state, never persisted — D5). This is consistent: `resources/` holds *content* data instances; run state is runtime-only.
- New/modified files touch: `run/`, `components/`, `player/`, `world/`, `systems/`, `tests/{run,components,player,world}/` — all existing domains. No new top-level folder.
- Naming: scripts `snake_case.gd` (`run_state.gd`), root/script `class_name RunState` (PascalCase), signals `snake_case` (`ship_depleted`), constants `UPPER_SNAKE` (`MAX_HP`). One root + one script per entity scene (unchanged).
- No conflicts with the unified structure detected. The `run/` `.gdkeep` is removed (Task 6.3).

### Project Context Rules

*(Extracted from `_bmad-output/project-context.md` — follow exactly. When a rule conflicts with a design intent, flag Mrdth.)*

- **Engine:** Godot 4.6 (`config_version=5`, GDScript). Pin to 4.6.x; avoid 4.7-only APIs. **2D** (`Node2D`/`CharacterBody2D`/`Area2D`); Compatibility renderer. Ignore the 3D defaults in `project.godot` (`Forward Plus`, `Jolt`) — inert.
- **State ownership is fixed (AR2):** Ships/Score → `RunState` (run); per-wave HP → `HealthComponent` (reset each wave by the wave host). Docked-ship combat = `DockedShip` node (transient); its build track = `RunState.BuildState` (permanent) — both E2/E3, not this story.
- **Composition over inheritance (AR5/ADR-4/D4):** the player is `CharacterBody2D` + component children (`HealthComponent`, `FactionComponent`, …) — no deep inheritance. `HealthComponent` is reused by player and enemies (i-frames default-off keeps that safe).
- **Signals (AR7/D8):** typed, past-tense for events (`ship_lost`, `wave_cleared`, `game_over`), imperative for requests; callable connect syntax. Global flow → `EventBus`; intra-entity → direct signals (`HealthComponent.died`, `player.ship_depleted`). Don't route HP/respawn through the bus.
- **No `print()` / no try-catch (AR11/AR12):** route logging through `Log`. Preconditions + `push_error`/`push_warning` + fail-safe defaults (e.g. spawner with `run_state == null` degrades safely); `assert` for dev-only invariants (`ships >= 0`). Never hard-crash.
- **Cache `@onready`; never `$`/`get_node()` per frame.** `move_and_slide()` takes no args and applies delta internally — don't multiply velocity by delta (player movement unchanged from 1.2).
- **Autoload order is fixed** (Constants → Log → EventBus → Settings → SeedManager → ContentRegistry → Pool → SaveManager → AudioManager → GameManager → Debug). **`RunState` is NOT an autoload** — it is a `Resource` instance owned by Arena. Do not add it to the registry.
- **Data-driven tuning (D9):** i-frame duration is `player_tuning.iframe_s` (`.tres`), not a magic number. `MAX_HP`/`BASE_HP`/`BASE_SHIPS`/`MAX_SHIPS` are immutable `Constants` (game-wide baselines, not feel knobs).

### References

- **Story spec:** `planning-artifacts/epics.md` — Story 1.5 (lines 357–371); FR8–FR12 (lines 51–55), FR49 (line 113); AR2 (state ownership — readiness report line 240).
- **GDD:** `planning-artifacts/gdds/gdd-meridian-run-2026-06-29/gdd.md` — Life & Health Economy (lines 101–110), Run Structure / timed-wave termination (lines 163–169), Permadeath (line 180). Decision log: "Life & Health Economy resolved (Ships × HP model)" (line 58) — confirms ships start 3/cap 5, HP base 3/full-heal-every-wave, dmg 1/2, i-frames 1s, capture −1 ship.
- **Architecture:** `planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md` — D1 state mgmt + `RunState` Resource (lines 189–192), state-ownership table (lines 200–206), D8 signal boundary + EventBus signal list (lines 250–252, 415–422), `run/run_state.gd` file (line 504), wave_controller (line 492), ADR-3 no-resume (line 344).
- **Project context:** `_bmad-output/project-context.md` — authoritative engine/perf/code-org/testing/state-ownership rules.
- **Prior stories (read before implementing):**
  - `implementation-artifacts/1-4-enemy-types-and-formation-dive-ai.md` — **direct predecessor.** Key decisions #1–#2 (enemy `CharacterBody2D` mask 0; node-name `HealthComponent` lookup, no Hurtbox yet), HP wiring on pooled enemy (`activate()` → `reset_to_full()`), signal boundary (D8), the out-of-scope table line that defers i-frames/ship-loss/respawn/run-end **to this story**, and the `formation_spawner` minimal-precursor-to-1.8 boundary. The File List (what 1.4 created) is the baseline you extend.
  - `implementation-artifacts/1-3-vertical-fire-system.md` — projectile pooling + `activate()` pattern; the forward-compat node-name-lookup note at `player/projectile.gd:65–68`.
  - `implementation-artifacts/1-2-player-movement-1-axis-chassis.md` — `CharacterBody2D` + `HealthComponent`/`FactionComponent` wiring; tuning `.tres`+`.gd` schema pair (clone for `iframe_s`).
  - `implementation-artifacts/1-1-project-scaffolding-and-core-systems.md` — `Constants` (collision layers, BASE_SHIPS/MAX_SHIPS/BASE_HP), `EventBus` signal declarations, GUT setup.
- **Code to read/edit (read fully before editing):**
  - `components/health_component.gd` — **the file you extend with i-frames** (47 lines; full source quoted in this story's analysis). `take_damage`/`heal`/`reset_to_full` + `health_changed`/`died` already correct.
  - `player/player.gd` + `player.tscn` — wire `died`→`ship_depleted`, `respawn()`, iframe tuning, flicker.
  - `player/player_tuning.gd` + `resources/player_tuning.tres` — add `iframe_s`.
  - `world/arena.gd` + `world/arena.tscn` — become the E1 run host (own `RunState`, ship-loss/game-over, wave loop).
  - `world/formation_spawner.gd` — score→`RunState`, emit `wave_cleared`, restartable `begin_wave`, `set_active`.
  - `systems/event_bus.gd` (rename `ship_lost` param), `systems/constants.gd` (add `MAX_HP`), `systems/pool.gd` (verify `acquire` robustness on cleared pool).
  - `enemies/enemy_projectile.gd` — **read only** (confirm the existing `take_damage` path; do not change).
  - `tests/components/test_health_component.gd`, `tests/world/test_formation_spawner.gd`, `tests/player/test_projectile.gd` — GUT patterns to mirror + regressions to keep green.
- **Deferred work log:** `implementation-artifacts/deferred-work.md` — three items explicitly deferred **to this story**: add `MAX_HP` constant; clarify `ship_lost` param; decide `heal()` revive semantics (all resolved above).

---

## Open design questions for Mrdth (review before dev — defaults are safe to implement as-is)

These are the consequential forks resolved with documented defaults above. They are safe to implement as written; flagged only so Mrdth can veto before `dev-story` runs.

1. **`RunState` scope in E1** — building a thin `run/run_state.gd` (ships + score) now, owned by Arena, rather than deferring the whole `RunState` to Epic 4 or tracking ships ad-hoc on the player/arena. *(Default: build it — matches AR2 + the 1.4 "encode-the-path" precedent + fixes the score smell.)*
2. **`game_over` E1 behavior** — emit `game_over` + `Pool.clear()` + `reload_current_scene()` (auto-replay for feel-testing) vs. emit + stop + wait for manual relaunch. *(Default: auto-replay; the real game-over screen is Story 8.4.)*
3. **Respawn position** — lane center (fair re-entry) vs. in-place. *(Default: center; playtest knob for 1.8.)*

---

## Dev Agent Record

### Agent Model Used

Claude Code (GLM-5.2[1m] per session environment)

### Debug Log References

- Full GUT suite (final): `godot --headless -s addons/gut/gut_cmdln.gd` → **16 scripts, 119/119 tests pass, 332 asserts** (0 regressions vs the 1.1–1.4 baseline).
- Per-task runs: `test_run_state` 7/7 · `test_health_component` 18/18 (9 existing + 9 i-frame) · `test_player_health` 5/5 · `test_formation_spawner` 10/10 (6 existing + 4 new) · `test_arena` 4/4 · `test_pool` 6/6.
- Import: `godot --headless --import` → clean (registers `RunState` `class_name` + the new `@export`s).
- Headless game launch (`timeout 8 godot --headless --path .`): boots, content indexes, wave 1 drip spawns, **zero runtime errors/warnings** during the run (only the known exit-time pooled-node leak artifacts, present since 1.3).

### Completion Notes List

- **All 5 ACs satisfied and verified by tests.** AC1 (3 ships cap 5, base 3 HP) → `RunState.begin_run()` + `Constants.{BASE_SHIPS,MAX_SHIPS,BASE_HP,MAX_HP}`; AC2 (1/2 dmg already wired by 1.4; **1 s i-frame window** new) → `HealthComponent` i-frame gate + `player_tuning.iframe_s=1.0`; AC3 (ship loss → −1 ship, respawn full HP + fresh i-frames) → `player.respawn()` + Arena `spend_ship()`; AC4 (wave clear → full heal) → `wave_cleared` → `reset_to_full()`; AC5 (0 ships → loss; score cumulative, display-only) → `RunState.score` + `game_over`.
- **Implicit/end-to-end requirements all met:** score moved off `FormationSpawner._run_score` onto `RunState` (fixes the 1.4 smell, AR2/FR49); `wave_cleared` hook wired (spawner emits on timer-expiry → Arena heals + advances the minimal next-wave loop, strict subset of 1.8); 1.3/1.4 hit paths unchanged (no HurtboxComponent introduced — Key Decision #6 honored); i-frames default-OFF so pooled-enemy re-`activate()` does not regress.
- **Signal boundary (AR7/D8) honored:** `HealthComponent.died` + `player.ship_depleted` are LOCAL (intra-entity→parent); `ship_lost(ships_remaining)`, `game_over`, `wave_cleared(wave)`, `score_changed` are on `EventBus`. The player never touches `RunState` (AR2).
- **Deferred-work items resolved (all three from prior reviews):** `MAX_HP` constant added (1.1 review); `ship_lost` param clarified to `ships_remaining` (1.1 review); `heal()` revive semantics decided — stays a pure clamp, `reset_to_full()` is the only revive path, documented in-code (1.2 review).
- **Task ordering note:** implemented as 1 → 2 → 3 → **5 → 4** → 6 (not the literal 1–6 listing). Task 4.1 explicitly depends on Task 5's deliverables ("Inject `_spawner.run_state` (**Task 5 adds the property**)"; Task 4.2 relies on Task 5.2's `wave_cleared` emit + restartable `begin_wave`). Doing 5 before 4 keeps each task green and the system end-to-end at every step — the ACs demand a working end-to-end system, not just letter-of-AC boxes.
- **Game-over replay safety (the critical gotcha):** `_on_run_lost` runs synchronously inside the physics step (`enemy_projectile._on_body_entered` → `take_damage` → `died` → `ship_depleted` → handler), so `Pool.clear()` + `reload_current_scene()` are **deferred to idle** via `call_deferred` (same class of hazard as Story 1.4's deferred `Pool.release`). `EventBus.game_over.emit()` + `_spawner.set_active(false)` fire synchronously (safe). Added `auto_replay_on_loss` (default true) as the E1 placeholder toggle — the testability seam the spec requested ("guard the game_over test so it doesn't reload mid-suite"); 8.4's real game-over screen replaces it.
- **Defensive `Pool.acquire` guard added** (Dev Notes "Run-end & Pool on replay" directive, AR11): an `is_instance_valid` check on reused pool entries so an out-of-band-freed node is never handed back to a consumer (supports the clear+reload path). `test_pool` still 6/6.
- **i-frame feel choice (Key Decision #2):** invulnerable = damage-immune, NOT intangible — bullets still consume on contact (`EnemyProjectile._on_body_entered` unchanged), `take_damage` is a 0-dmg no-op. No collision-layer toggling in 1.5 (a 1.6/1.8 refinement if playtest reads oddly).
- **No new dependencies, no scope creep.** No `HurtboxComponent`/`HitboxComponent` (E2), no ship-gain callers (E2/E3), no full wave FSM (1.8), no HUD/juice (1.6/1.7) — `add_ship()` encoded + unit-tested but uncalled, exactly as specified.

### File List

**New:**
- `run/run_state.gd` — `RunState` Resource spine (ships + score, begin_run/spend_ship/add_score/add_ship/reset).
- `tests/run/test_run_state.gd` — pure-logic unit tests (7).
- `tests/player/test_player_health.gd` — player ship-economy integration tests (5).
- `tests/world/test_arena.gd` — Arena run-host integration tests (4).

**Modified:**
- `components/health_component.gd` — i-frame window (`invuln_after_hit_s`, `_invuln_timer`, `is_invulnerable`/`set_invuln`, `_process` decrement, `take_damage` early-return + grant-on-real-hit, `reset_to_full` clears timer).
- `player/player.gd` — `_ready` feeds iframe tuning + connects `died`→`ship_depleted`; local `ship_depleted` signal; `respawn()` (reset_to_full + center + i-frames); `_process` flicker (1.6 placeholder).
- `player/player_tuning.gd` — `@export var iframe_s: float = 1.0`.
- `resources/player_tuning.tres` — `iframe_s = 1.0`.
- `world/arena.gd` — E1 run host: owns `RunState`, injects into spawner, wires `ship_depleted`→respawn/ship_lost/game_over, `wave_cleared`→heal+next wave, deferred clear+reload on loss.
- `world/formation_spawner.gd` — `run_state` property + score routing (deleted `_run_score`), `wave_cleared` emit on timer-expiry, restartable `begin_wave`, `set_active()`, null-`run_state` fail-safe.
- `systems/constants.gd` — `const MAX_HP: int = 3`.
- `systems/event_bus.gd` — `signal ship_lost(ships_remaining: int)` (param rename).
- `systems/pool.gd` — `is_instance_valid` guard on reused `acquire()` entries (AR11 defensive).
- `tests/components/test_health_component.gd` — +9 i-frame cases (no regression to the 9 existing).
- `tests/world/test_formation_spawner.gd` — `RunState` injection, `wave_cleared`/restartable/null-state cases (+4).

**Deleted:**
- `run/.gdkeep`, `tests/run/.gdkeep` — placeholders retired (both dirs now hold real files).

### Change Log

- 2026-07-05: Story 1.5 implemented — RunState ship/score spine, HealthComponent i-frames, player respawn/ship_depleted, Arena E1 run host (ship-loss/game-over/wave-loop), FormationSpawner score→RunState + wave_cleared. 119/119 GUT tests pass. Status → review.

