---
baseline_commit: aeed867
---

# Story 2.3: Rescue & Failed Rescue

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want my timing on killing the captor to matter,
so that a clean dive-kill rescues a ship (it docks as a dual-fighter) but a lazy
formation-kill turns the captive against me (it becomes an enemy — +1 enemy, no ship-count
change) — making rescue a skill-gated reward, not a guaranteed payoff ([Ref-11]).

## Acceptance Criteria

1. **Given** the captor is in **`dive`** state **AND it captured the player this spawn**
   (`captured_player == true` — the prior-capture gate, F), **When** it is killed, **Then** a freed ship
   docks to the player — a `DockedShip` node attaches to the `Player` (the rescue). No ship-count change
   at rescue time (the captured ship was already spent at capture in 2.2; the docked fighter is the
   rescued ship returned as a combat asset). A dive-kill WITHOUT a prior capture (the player dodged) is
   a failed-rescue (AC2), not a rescue — the gate prevents the "safe rescue" farm.
2. **Given** the captor is in **`formation`** state (or any non-`dive` state, OR a `dive` state
   without a prior capture — see Dev Notes §"State coverage" + §"Prior-capture gate"), **When** it is
   killed, **Then** the captured ship turns into an enemy: an enemy spawns at the captor's death
   position (**+1 enemy**) with the distinct **turned-ship visual** (player arrowhead inverted,
   hazard-colored — E) — [Ref-11]. **No ship-count change** (the −1 ship in the epics AC / FR18 is
   relative-accounting vs the Keep +1, NOT an actual spend — see Dev Notes §"Ship-count economy (the
   corrected model)"). The player does **not** respawn.
3. **Given** rescue, **Then** the docked fighter attaches with its **hardcoded combat presence**:
   **+firepower** (a parallel bullet stream, +28 px x-offset), **+hitbox** (the docked ship extends
   the player's hittable area), and an **intrinsic first-hit absorber** (the first hit on the docked
   player destroys the docked fighter, sparing the player's HP — **no ship-count change**; the FR18
   "Absorb = −1 ship" is relative-accounting vs the Keep +1, NOT a spend). All hardcoded (E2 hardcodes
   docked stats — no premature `StatBlock`; the build engine is E3).

> *(FR15 — rescue on dive-kill, failed-rescue on formation-kill; [Ref-11]. FR7 docked stream,
> FR16 docked presence, FR17 dual-nature foreshadowed. The permanent build track + capture-immunity
> tradeoff + the four docked-ship resolutions are Stories 2.4 / 2.5 — see Scope seams.)*

---

## Tasks / Subtasks

### Task 1 — `Captor`: `captured_player` flag + `died` carries `rescue` + position (AC: #1, #2 enabler; F)

- [ ] `enemies/captor/captor.gd`: add `var captured_player: bool = false` (set by `CaptureState` on a
  successful `try_capture`; reset in `activate()`). This is the **prior-capture gate** (F) — rescue
  requires the captor to have actually captured the player this spawn.
- [ ] Reset `captured_player = false` in `activate()` (pool contract — per-spawn state resets there).
- [ ] `enemies/captor/states/capture_state.gd`: on a successful `try_capture` (where the 2.2 code sets
  `_captured = true`), ALSO set `_captor.captured_player = true`. (Keep the local `_captured` for the
  CaptureState control flow; this just mirrors it onto the entity for the death handler.)
- [ ] Change `signal died(score_value: int)` → `signal died(score_value: int, rescue: bool, at: Vector2)`.
- [ ] In `_on_died()`: compute `rescue := current_state_name == &"dive" and captured_player` and emit
  `died.emit(definition.score_value, rescue, global_position)`. The captor OWNS the rescue condition
  (dive + captured — F + G); the spawner/Arena just route the computed bool. The captor is still valid
  at emit time (`_release_to_pool` is deferred; `current_state_name` + `captured_player` are
  authoritative). Keep `_release_capture_column()` + `JuiceFx.enemy_killed` +
  `_release_to_pool.call_deferred()` unchanged (order: emit → release column → juice → defer release).
- [ ] No new `class_name` → no `--import` reindex needed for this task.

### Task 2 — `DockedShip` node: visual + hitbox (AC: #3)

- [ ] `player/docked_ship.gd` + `player/docked_ship.tscn` — `class_name DockedShip extends Node2D`.
  Parented to the `Player` (a child, offset to one side — NOT a separate world entity). Composition:
  - `Visual` — an **escort-chevron** polygon (mirrors the player-ship arrowhead family) at **~80%
    scale**, `{colors.dock}` hero-neon hue, **bright outline** (player-family — D16/UX color-safety
    core; NEVER the pellet/parallel-bar silhouette of enemy fire or the tractor). See Dev Notes
    §"DockedShip visual contract".
  - **NO hitbox on the DockedShip.** The +hitbox is the PLAYER's own hitbox growing when docked (via
    `Player.set_docked` — see Task 3), NOT a separate `AbsorbHitbox` on the docked ship. Rationale: a
    separate docked-ship `Area2D` + the player's `HurtboxComponent` would BOTH detect the same enemy
    body → `apply_hit` fires twice → the second hit damages HP after the docked ship is consumed
    (double-trigger bug). One hitbox (the player's, grown) + `apply_hit` is the clean design. See Dev
    Notes §"+hitbox = the player's hitbox grows".
- [ ] API: `setup(player: Player) -> void` (cache the player ref), `attach() -> void` (position at
  the docked offset, show), `detach() -> void` (hide + `queue_free`). NO `_physics_process` — the docked
  ship is parented to the player, so it rides the player's transform (the offset is a local
  position; it never moves independently).
- [ ] **NOT pooled** — `instantiate()` on attach, `queue_free()` on detach (NP1 pseudocode verbatim;
  the docked ship is created/destroyed at most once per wave — FR14 one-docked — so it is not a
  hot-path pooled type. Do NOT route it through `Pool`).
- [ ] Run `godot --headless --import` after adding the `DockedShip` class_name.

### Task 3 — `Player`: dock state + `try_dock_ship` + `apply_hit` absorber (AC: #1, #3)

- [ ] `player/player.gd`: add `@export var docked_ship_scene: PackedScene` (set in `player.tscn` —
  mirrors `FireSystem.projectile_scene`; NEVER `preload`/`load` in gameplay code, D9/ContentRegistry
  pattern) + `var _docked_ship: DockedShip = null` + `var _docked := false`.
- [ ] Retire the 2.2 stub: `is_capture_immune()` → `return _docked` (the guard is now wired to the
  real docked state — AC3 implies a functional docked state; FR16 docked = capture-immune). Delete
  the `# 2.4 seam` comment.
- [ ] Add `func try_dock_ship() -> bool:` — the rescue EFFECT entry (AC#1). Guards: no existing
  docked ship (FR14 one-docked). On success: instantiate + attach the `DockedShip`, set
  `_docked = true`, return true. See Dev Notes §"try_dock_ship contract".
- [ ] Add `func apply_hit(damage: int, impact_pos: Vector2, source: Node2D, heavy: bool = false) -> void:`
  — the CENTRALIZED damage route (AC#3 absorber). i-frame gate → absorber (if docked) → HP damage.
  See Dev Notes §"apply_hit / absorber contract".
- [ ] Add `func _consume_docked_ship(impact_pos: Vector2, source: Node2D) -> void:` — detach the
  docked fighter + absorber juice (the docked ship dies, sparing HP). **NO `spend_ship` — ever** (the
  FR18 "Absorb = −1 ship" is relative-accounting vs the Keep +1, NOT a spend — Mrdth-confirmed; see
  Dev Notes §"Ship-count economy (the corrected model)").
- [ ] Add `func set_docked(on: bool) -> void:` — the architecture-named write-side
  (`architecture.md:616` `set_docked(true) # capture-immune + bigger hitbox`). Sets `_docked` AND
  grows/shrinks the player's hitbox (the **+hitbox**, AC#3): swap the `CollisionShape2D` shape (body,
  for projectiles) + the `HurtboxComponent` shape (contact) between the clean radius (11) and the
  docked radius (e.g. 18, from `DockedShipTuning`). `duplicate()` the shape before resizing (shared-
  resource safety — mirrors `captor.gd:62-66`). The player has `collision_mask = 0` so growing the
  body shape only affects what body_enters it (projectiles) — no physics impact. Called by
  `try_dock_ship`/`_consume_docked_ship`/`_on_wave_cleared`. (2.4 deepens this to the formal
  [Risk-12] tradeoff + persists the track.) See Dev Notes §"+hitbox = the player's hitbox grows".
- [ ] Wave-end cleanup stub: connect `EventBus.wave_cleared` → `_on_wave_cleared` (ONCE, in `_ready`)
  to detach the docked ship (wave-scope — NP1). NO ship regain in 2.3 (the Keep outcome is 2.5). See
  Dev Notes §"Wave-end cleanup is a stub".

### Task 4 — `FireSystem`: parallel bullet stream when docked (AC: #3 +firepower)

- [ ] `player/fire_system.gd` `_spawn()`: after spawning the primary bullet, if the player is docked
  (`_player.is_docked()` — add a one-liner accessor), spawn a SECOND bullet at
  `_muzzle.global_position + Vector2(28.0, 0.0)` (hardcoded +28 px x-offset — FR7/GDD weapon table).
  Same speed/damage/cadence (the second bullet shares the cooldown — it fires in sync). See Dev Notes
  §"Parallel stream implementation".
- [ ] The `FireSystem` needs the player ref to query `is_docked()`. It already reads
  `get_parent()` (the Player) for the muzzle — cache `@onready var _player: Player = get_parent()` and
  use `_player.is_docked()`. (The FireSystem is a child of the Player — `get_parent()` is safe + cheap
  in `_ready`, never per-frame.)

### Task 5 — `FormationSpawner`: `_on_captor_died` + `captor_resolved` signal + `spawn_enemy_at` (AC: #1, #2; E)

- [ ] `world/formation_spawner.gd`: add `signal captor_resolved(rescue: bool, at: Vector2)` (LOCAL —
  spawner→Arena, D8 intra-scene; mirrors `Player.ship_depleted` → Arena).
- [ ] Flesh out `_on_captor_died(_score_value: int, rescue: bool, at: Vector2) -> void:` (the 2.1
  seam): emit `captor_resolved.emit(rescue, at)`. That's it — the captor already computed `rescue`
  (`dive + captured_player` — F + G); the spawner ROUTES, Arena RESOLVES (AR2). The handler signature
  changes from the 2.1 seam's `(_score_value)` to `(_score_value, rescue, at)` (Task 1's `died` signal
  change ripples here). See Dev Notes §"Signal boundary".
- [ ] Add `func spawn_enemy_at(pos: Vector2, id: StringName = &"grunt") -> void:` — position-based
  enemy spawn for the failed-rescue "+1 enemy" (AC#2). acquire → add_child → `activate_at` →
  `apply_turned_visual` (E — the distinct turned-ship visual; load-bearing order). See Dev Notes
  §"spawn_enemy_at + the activate-variant fork" + §"Turned-ship visual (the failed-rescue enemy)".
- [ ] Add `Enemy.activate_at(pos, rng)` + `Enemy.apply_turned_visual()` (see Dev Notes — the
  position-based activate variant + the turned-ship visual override).
- [ ] Retire the 2.1 `# Story 2.1 seam for Story 2.3` comment block in `_on_captor_died`.

### Task 6 — `Arena`: `_on_captor_resolved` (rescue + failed-rescue) (AC: #1, #2)

- [ ] `world/arena.gd`: in `_ready()`, connect `_spawner.captor_resolved → _on_captor_resolved` (ONCE).
- [ ] Add `func _on_captor_resolved(rescue: bool, at: Vector2) -> void:` — the run-scope resolution:
  - **rescue (true):** `_player.try_dock_ship()` + rescue juice at `_player.global_position`
    (pickup-style: a `particles_requested` burst in the dock color + a positive SFX — see Dev Notes
    §"Juice gaps"). No ship-count change.
  - **failed-rescue (false):** `_spawner.spawn_enemy_at(at)` (+1 enemy) + failed-rescue juice at `at`
    (hazard sting: `hit_flash_requested` on the player body in the hazard color +
    `screen_shake_requested` + a negative SFX). **No ship-count change** (the epics AC2 "−1 ship" is
    relative-accounting vs the Keep +1, NOT a spend — Mrdth-confirmed 2026-07-12). NO `_player.respawn()`,
    NO `spend_ship()`, NO `ship_lost` emit. See Dev Notes §"Ship-count economy (the corrected model)".
- [ ] No new ship-loss/game-over path in 2.3 — the only ship-count changes are capture (−1, already in
  2.2) and keep (+1, 2.5). Failed-rescue can't drop ships to 0 (it doesn't spend one).
- [ ] `juice/juice_fx.gd`: add `static func rescue(at: Vector2) -> void:` (a particle burst in the
  dock color at the player + a positive SFX — pickup-style) + `static func failed_rescue(at: Vector2,
  target: Node2D) -> void:` (a `hit_flash_requested` on the player body in the hazard color + a
  `screen_shake_requested` + a particle burst at `at` + a negative SFX — hazard sting). Mirror the
  existing `JuiceFx.player_hit` / `enemy_killed` shape (read colors/amounts from `_TUNING` + the
  palette tokens; respect the ≤3 Hz flash cap + reduced-motion via the coordinator). See Dev Notes
  §"Juice gaps". Arena calls these one-line helpers (no direct `EventBus` juice emits in Arena).

### Task 7 — `HurtboxComponent` + `enemy_projectile`: route through `apply_hit` (AC: #3 absorber)

- [ ] `components/hurtbox_component.gd` `_on_body_entered(body)`: replace the direct
  `_health.take_damage(contact_damage)` + `JuiceFx.player_hit(...)` with a duck-call to the player's
  `apply_hit`: `owner.apply_hit(contact_damage, global_position, body, false)` (the hurtbox's owner is
  the Player). Guard: `if owner.has_method("apply_hit"):` with a fallback to the old path for any
  non-player owner (defensive — the hurtbox is player-only today, but keep the fallback). See Dev
  Notes §"apply_hit / absorber contract".
- [ ] `enemies/enemy_projectile.gd` `_on_body_entered(body)`: replace
  `body.get_node_or_null("HealthComponent").take_damage(_damage)` + `JuiceFx.player_hit(...)` with a
  duck-call: `if body.has_method("apply_hit"): body.apply_hit(_damage, global_position, body, _heavy)`
  (the projectile only hits `LAYER_PLAYER` → body is the Player). Keep the `_consumed` guard + the
  deferred `Pool.release.call_deferred(self)` (unchanged). See Dev Notes §"apply_hit / absorber contract".
- [ ] `player/projectile.gd` (player bullet hitting ENEMIES) is UNCHANGED — enemies have no docked
  ship; they keep the `body.HealthComponent.take_damage()` node-name convention.

### Task 8 — Tests (GUT) (AC: all)

- [ ] `tests/enemies/test_captor_died_signal.gd` (new; extend the `test_captor_fsm.gd` idiom):
  instantiate `captor.tscn` with a test `CaptorTuning` + mock player; drive to each state; kill it
  (call `_on_died` or deal lethal damage); assert `died` emits with the correct `(score_value, rescue,
  at)` — `rescue == (state == "dive" and captured_player)`, and `at == global_position` at death. Set
  `captured_player = true` manually (or drive a real capture via the mock player) for the rescue cases.
- [ ] `tests/enemies/test_captor_rescue_branch.gd` (new; integration — covers F + G): wire a
  `FormationSpawner` + a test `captor_resolved` listener + mock player. Cases:
  (a) drive a REAL capture (mock player in-column during the 0.4 s window → `try_capture` succeeds →
  `captured_player = true`), then `to_dive()`, then kill → `captor_resolved(true, at)` (rescue).
  (b) dodge capture (mock player out-of-column for the whole window → miss → immediate dive,
  `captured_player == false`), then kill during dive → `captor_resolved(false, at)` (failed-rescue — the
  **prior-capture gate: dive-kill WITHOUT capture is NOT a rescue**).
  (c) `to_formation()` then kill → `captor_resolved(false, at)` (failed-rescue).
  (d) `to_telegraph()` / `to_capture()` (no capture) then kill → `captor_resolved(false, at)`.
  Assert `captured_player` resets to false on `activate()` (a fresh spawn starts un-captured).
- [ ] `tests/player/test_player_dock.gd` (new; mirror `test_player_capture.gd`): instantiate
  `player.tscn`; assert `try_dock_ship()` returns true + `_docked == true` + a `DockedShip` child
  exists when clean; returns false (no second dock) when already docked (FR14 one-docked);
  `is_capture_immune()` returns true after dock (retires the 2.2 stub); `apply_hit` while docked →
  docked ship consumed (detached) + HP UNCHANGED (absorber spares HP) + no `ship_depleted` emit;
  `apply_hit` while clean → HP damaged normally; `apply_hit` during i-frames → full no-op.
- [ ] `tests/world/test_arena_captor_resolution.gd` (new; integration): instantiate `arena.tscn`
  (or a minimal Arena + spawner + run_state); emit `captor_resolved(true, at)` → player gains a docked
  ship, NO ship-count change; emit `captor_resolved(false, at)` → an enemy spawns in the container
  (`_spawner.get_active_count()` +1) + **NO ship-count change** (`run_state.ships` unchanged) + **NO
  `ship_lost` emit** + **NO `game_over`** (failed-rescue doesn't spend a ship — it can't drop to 0).
  Assert NO `respawn()` call on failed-rescue (the player keeps flying — position unchanged). Assert
  the failed-rescue enemy is on `LAYER_ENEMY` + its `died` connects to `_on_enemy_died` (gives score
  when later killed) + `apply_turned_visual()` was called (its `_visual.polygon` is the inverted
  player arrowhead, not the grunt silhouette — E).
- [ ] `tests/world/test_formation_spawner_spawn_enemy_at.gd` (extend `test_formation_spawner.gd`):
  `spawn_enemy_at(pos)` spawns one enemy at `pos` (acquire → add_child → activate_at); the enemy is on
  `LAYER_ENEMY` (faction); `died` connects to `_on_enemy_died` (so the turned-enemy gives score when
  later killed). Assert the enemy's spawn position ≈ `pos`. Assert `apply_turned_visual()` was called —
  the enemy's `_visual.polygon` is the player arrowhead INVERTED (points down) + hazard color (E), not
  the grunt silhouette.
- [ ] `tests/player/test_fire_system_docked.gd` (new; mirror `test_fire_system.gd` if it exists, else
  the projectile idiom): dock the player; hold fire one tick; assert TWO bullets spawn (primary +
  +28 px offset secondary); undock → one bullet again. (Assert the secondary's x ≈ muzzle.x + 28.)
- [ ] `tests/components/test_hurtbox_absorber.gd` (new): a docked player + an enemy body entering the
  hurtbox → `apply_hit` → docked ship consumed, HP unchanged; a clean player + enemy body → HP damaged.
- [ ] `before_each()`: `Pool.clear()`. After adding `DockedShip` class_name, run
  `godot --headless --import`, then `godot --headless -s addons/gut/gut_cmdln.gd` — **verify the
  Scripts/Tests COUNTS** (GUT silently skips parse-failed scripts; memory `gut-classname-reindex-silent-skip`).
  Expect benign exit-leak warnings (memory `gut-exit-leak-warnings-expected`) — trust Passing/Failing.

### Task 9 — Regression, verification, housekeeping (AC: all)

- [ ] Run the full GUT suite — confirm **zero regressions** vs the 2.2 baseline (259 tests). Especially:
  `test_captor_fsm.gd` (the `died` signature change doesn't break the FSM tests — they don't connect
  `died`), `test_captor_capture.gd` (capture still works — `try_capture` is unchanged), `test_player_capture.gd`
  (the `is_capture_immune` stub retirement doesn't break the 2.2 stub test — UPDATE that test to assert
  `true` after dock instead of `false`), `test_enemy.gd` / `test_arena.gd` (the damage-route refactor —
  `apply_hit` — doesn't break enemy-death or player-hit paths), `test_capture_column.gd` (unchanged).
- [ ] **Update `tests/player/test_player_capture.gd::test_is_capture_immune_returns_false_in_2_2`** —
  rename + flip: `is_capture_immune()` now returns `_docked` (true after dock, false when clean). The
  2.2 stub test is obsolete; replace it with the docked-immunity assertion (Dev Notes §"Retiring the 2.2 stub test").
- [ ] Manual (in-editor, F8 spawn captor): let it capture you (−1 ship), then kill it during the dive
  → a docked wingman appears (rescue). DODGE the capture (move out of the column for the whole 0.4 s
  window), then kill the captor during its dive → NO docked ship (the prior-capture gate — F; it's a
  failed-rescue instead). Spawn another captor, kill it in formation → a TURNED-SHIP enemy (inverted
  player arrowhead, hazard color — E) spawns at the captor's position (failed-rescue: +1 enemy, NO
  ship-count change, no respawn). While docked, take a hit → the docked ship dies (absorbed), HP
  unchanged (NO ship-count change). While docked, fire → two bullets. **(Pending — human/GUI step; the
  mechanics are covered by automated tests but the in-editor feel-playtest could not be run headlessly.)**
- [ ] Confirm the `died` signal change + the damage-route refactor fire from physics callbacks and the
  existing deferred-release / deferred-`_end_run` paths still hold — no new physics-step free hazard
  (Dev Notes §"Physics-step safety is inherited").
- [ ] Update this file's Dev Agent Record (File List, Completion Notes). Be honest about the deferred
  Keep `add_ship(+1)` (2.5) + the Sacrifice input (2.6) — do not claim the four docked-ship outcomes
  are exercised (that's 2.5). The absorber + failed-rescue are NO ship-count change (not a deferred
  cost — the economy is correct as-is).

---

## Dev Notes

### 🔑 Key decisions (read these first — they resolve the open forks)

1. **The death branch: the captor computes `rescue`, the `died` signal carries it.** The 2.1 seam said
   "2.3's death handler reads `current_state_name`." With the prior-capture gate (F), the rescue
   condition is `current_state_name == &"dive" AND captured_player` — so the captor computes `rescue`
   at death and the `died` signal carries the bool + the death position: `died(score_value, rescue, at)`.
   The captor emits `died.emit(definition.score_value, current_state_name == &"dive" and captured_player,
   global_position)` in `_on_died` (before the deferred release — the captor is valid at emit time).
   This centralizes the rescue condition (dive + captured) on the entity that owns both, avoids the
   `Callable.bind(captor)` `is_connected` gotcha, and avoids tracking per-captor state in the spawner.
   (Alternatives considered: pass `state_name` + let the spawner branch — rejected: the captor owns
   `captured_player`, so it should own the bool; bind the captor ref — rejected on the `is_connected`
   gotcha.)

2. **The spawner ROUTES the death; Arena RESOLVES it (AR2).** `FormationSpawner._on_captor_died` does
   ONE thing: `captor_resolved.emit(rescue, at)` (passing through the captor-computed bool). Arena's
   `_on_captor_resolved` does the work: dock (via player) for rescue; spawn-enemy (via spawner) for
   failed-rescue. Neither branch touches the ship count (capture = −1 is already in 2.2; keep = +1 is
   2.5 — failed-rescue is no change). Rationale: Arena owns the run-scope coordination (AR2); the
   spawner owns the captor lifecycle + enemy spawning; the player owns the dock. A LOCAL spawner→Arena
   signal (`captor_resolved`) mirrors the existing `Player.ship_depleted` → Arena pattern (D8
   intra-scene). Do NOT add an `EventBus.captor_killed` / `rescued` signal (D8: global flow only on the
   bus; the 2.2 precedent kept `ship_depleted` local).

3. **Rescue reuses the player-as-trigger pattern (mirrors 2.2 `try_capture`).** `Player.try_dock_ship()`
   is the rescue EFFECT entry, just as `try_capture` is the capture EFFECT entry. The player owns the
   docked state (per-ship-mechanic-adjacent); Arena calls it. The player instantiates + attaches the
   `DockedShip` + sets `_docked = true`. The player never touches `RunState` (AR2 — rescue is a combat
   attach, not a ship-count change).

4. **Failed-rescue spawns an enemy but does NOT change the ship count (no −1 ship).** "The captured
   ship turns into an enemy" = **+1 enemy** (spawn at the captor's death position) — that's the entire
   consequence. The epics AC2 / FR18 "−1 ship" is **relative-accounting vs the Keep +1** (you forfeit
   the regain you'd get from keeping the docked ship to wave-end), NOT an actual `spend_ship`. The
   player's current ship is fine (they shot the captor, they weren't hit) → NO `respawn()`, NO
   `spend_ship()`, NO `ship_lost` emit. Arena just spawns the enemy + the hazard sting. See Dev Notes
   §"Ship-count economy (the corrected model)" (Mrdth-confirmed 2026-07-12).

5. **The absorber centralizes the player's damage routing via `Player.apply_hit()` (AC#3).** Both
   damage paths (enemy_projectile body_entered + HurtboxComponent body_entered) currently call
   `HealthComponent.take_damage()` directly. To make the docked ship "absorb the first hit, sparing
   HP," BOTH paths must check for a docked ship FIRST. So route both through `Player.apply_hit(damage,
   impact_pos, source, heavy)`, which gates: i-frames → absorber (if docked) → HP damage. This is the
   cleanest way to cover both contact + projectile damage. See Dev Notes §"apply_hit / absorber contract".

6. **2.3 delivers the FULL AC3 combat presence (dock + +firepower + +hitbox + absorber + capture-
   immunity); 2.4 DEEPENS (permanent track, +28 px pin, bigger-hitbox-as-tradeoff, wave-scope).** AC3
   says the docked fighter attaches WITH "+firepower, +hitbox, intrinsic absorber" — so 2.3 makes the
   docked ship FUNCTIONAL at attach time (a real parallel stream, a real absorber, a real hitbox), all
   hardcoded. 2.4 then adds the permanent `RunState.BuildState.wing_track`, pins the +28 px offset,
   formalizes the bigger-hitbox as the [Risk-12] clean/docked tradeoff, and frames the wave-scope/
   transient nature. 2.3 retires the 2.2 `is_capture_immune()` stub (wires `_docked`) because AC3's
   "intrinsic absorber" implies a functional docked state + FR16 requires docked = capture-immune. See
   Open Question B (the 2.3/2.4 boundary).

7. **The absorber spares HP with NO ship-count change — in 2.3 AND 2.5 (Mrdth-confirmed).** FR18's
   "Absorb = −1 ship" is the same relative-accounting mistake as AC2's failed-rescue "−1 ship": the
   docked ship dying forfeits the Keep +1 regain, it does NOT spend an additional ship. So `_consume_docked_ship`
   spares HP + consumes the fighter, NO `spend_ship` — not a "temporary free sponge" (the economy is
   correct as-is), and 2.5 does NOT add a −1 cost later. The docked ship is a non-counted combat asset:
   rescue doesn't add a ship, absorb/sacrifice don't spend one; the ONLY ship-count changes are capture
   (−1, 2.2) and keep (+1, 2.5). (By the same logic, 2.6's Sacrifice is also no ship-count change —
   flagged for the epics-doc correction.)

8. **State coverage: `dive + captured_player` → rescue; ALL ELSE → failed-rescue (F + G).** The AC
   specifies dive + formation; the 2.1 seam said "formation/else → failed-rescue"; F adds the
   prior-capture gate. So: rescue = `current_state_name == &"dive" AND captured_player`; everything
   else (dive-without-capture, formation/telegraph/capture/enter) → failed-rescue (+1 enemy, no
   ship-count change). Edge case: a captor killed during the `capture` state AFTER capturing (during
   the reel-in) → failed-rescue by this rule (it's not `dive`). If playtest wants that to rescue,
   change the condition to `captured_player` alone (any state) — a one-line change. Default keeps the
   literal AC1 ("dive → rescue").

9. **The prior-capture gate (F): rescue requires the captor to have captured the player this spawn.**
   This prevents the "safe rescue" farm (dodge capture + dive-kill → free docked ship → keep → +1).
   `Captor.captured_player` is set by `CaptureState` on a successful `try_capture` (the 2.2 code path)
   + reset in `activate()` (pool contract). A dive-kill WITHOUT capture (the player dodged the 0.4 s
   window — the captor's `CaptureState` miss path, which dives immediately) → `captured_player == false`
   → failed-rescue (+1 enemy), NOT a rescue. See Task 1 + §"Captor `died` signal extension". (2.8 is
   about captor spawn frequency, not the gate.)

### 📊 Tuning map — the new hardcoded values (E2 hardcodes docked stats)

E2 hardcodes docked stats (no `StatBlock` — that's E3). Add a `DockedTuning` resource for the
data-tunable knobs (the `.tres` wins at runtime — memory `tres-overrides-gd-default-for-tuning`):

```gdscript
# player/docked_ship_tuning.gd
class_name DockedShipTuning
extends Resource

@export_group("Stream")           # FR7 — the parallel bullet stream
@export var stream_offset_x: float = 28.0   # +28 px x-offset (hardcoded — GDD weapon table).
@export var stream_damage: int = 10         # matches the player's projectile_damage (FR7 "matches player").

@export_group("Absorber")
@export var absorb_spare_hp: bool = true    # the docked ship dies first, sparing HP (FR17 intrinsic absorber).

@export_group("Hitbox")                     # the +hitbox (AC#3 / [Risk-12]) — the player's hitbox grows when docked
@export var docked_hitbox_radius: float = 18.0  # the player's CollisionShape2D + HurtboxComponent shape radius when docked (clean = 11).

@export_group("Visual")
@export var dock_offset_x: float = 28.0     # the docked fighter's offset to one side of the player (~80% scale, UX docked-wingman-indicator).
@export var dock_scale: float = 0.8         # ~80% scale (UX C1).
@export var dock_color: Color = Color(0, 0.898, 1, 1)  # {colors.dock} placeholder (UX OQ3 — provisional alias of primary_hover; use HudPalette.PRIMARY if available). Player-family — NEVER the hazard hue.
```

`resources/docked_ship_tuning.tres` — the INSTANCE (flat under `resources/`, matching `player_tuning.tres`
/ `captor_tuning.tres` — the established flat convention, NOT `resources/tuning/` which doesn't exist).
The `+28 px` stream offset + the `+28 px` dock offset are intentionally the same value (the stream
fires from the docked fighter's position) — keep them in sync via the tuning or a single constant.

> If you'd rather NOT introduce a new tuning resource for two hardcoded numbers, inline them as `const`
> in `docked_ship.gd` / `fire_system.gd` (the GDD pins +28 px, so a `const` is defensible). But the
> `.tres`-wins rule (D9) prefers a tuning resource for any playtest knob. Pick one + be consistent.

### 🧩 Captor `died` signal extension — `enemies/captor/captor.gd`

```gdscript
signal died(score_value: int, rescue: bool, at: Vector2)  # direct/local (D8) — 2.3 reads the computed rescue flag + at.
# (state_changed unchanged — still emitted on every transition.)

var captured_player: bool = false  # F (prior-capture gate): set by CaptureState on a successful try_capture; reset in activate.


func _on_died() -> void:
	# Death originates in a physics callback (player projectile body_entered → take_damage → died.emit),
	# so the captor's self-release is deferred. The captor OWNS the rescue condition (F + G): rescue =
	# killed during `dive` AND it actually captured the player this spawn. A dive-kill WITHOUT capture
	# (player dodged) is NOT a rescue → failed-rescue. Emits the computed bool + the death position (the
	# failed-rescue enemy spawns at `at`). The captor is STILL VALID here (the deferred release hasn't
	# run) — current_state_name + captured_player + global_position are authoritative. Release any held
	# column BEFORE the deferred self-release so a telegraph/capture kill doesn't leave it locked.
	var rescue: bool = current_state_name == &"dive" and captured_player
	died.emit(definition.score_value, rescue, global_position)
	_release_capture_column()
	JuiceFx.enemy_killed(global_position, definition.silhouette_color, definition.silhouette_scale, definition.score_value)
	_release_to_pool.call_deferred()
```

The spawner connection (`captor.died.connect(_on_captor_died)` in `spawn_captor_at`) is UNCHANGED —
the callable is the same; only the handler signature + the emit args change. The
`if not captor.died.is_connected(_on_captor_died)` guard still works (no bind).

### 🎯 FormationSpawner — `_on_captor_died` + `captor_resolved` + `spawn_enemy_at`

```gdscript
signal captor_resolved(rescue: bool, at: Vector2)  # LOCAL (spawner→Arena, D8 intra-scene). Arena resolves.


func _on_captor_died(_score_value: int, rescue: bool, at: Vector2) -> void:
	# Story 2.3 — route the captor's death to Arena for resolution. The captor already computed `rescue`
	# (dive + captured_player — F + G); the spawner just passes it through. rescue = the freed ship docks;
	# failed-rescue (everything else) = the captured ship turns enemy (+1 enemy, NO ship-count change).
	# Arena owns the run-scope resolution (AR2); the spawner owns the captor lifecycle + enemy spawning.
	# Do NOT route a captor count to the HUD (deferred to a captor-integration follow-up — not a 2.3 AC).
	captor_resolved.emit(rescue, at)


func spawn_enemy_at(pos: Vector2, id: StringName = &"grunt") -> void:
	# Story 2.3 — position-based enemy spawn for the failed-rescue "+1 enemy" (the captured ship turns
	# enemy at the captor's death position). Mirrors _spawn_enemy's acquire → add_child → activate
	# order (load-bearing — @onready refs valid in activate), but spawns at a world position instead of
	# a formation slot. The turned-enemy reuses the grunt scene/behavior BUT applies the distinct
	# "turned-ship" visual (E — player arrowhead inverted, hazard color) so it reads as a captured ship
	# gone hostile, not a stock grunt. See Dev Notes §"Turned-ship visual (the failed-rescue enemy)".
	var scene: PackedScene = _scene_for(id)
	if scene == null:
		return
	var enemy: Enemy = Pool.acquire(scene) as Enemy
	assert(enemy != null, "FormationSpawner.spawn_enemy_at: acquired node is not an Enemy")
	_container.add_child(enemy)
	enemy.player_target = player
	enemy.activate_at(pos, _rng)   # the position-based activate variant (see "activate-variant fork")
	enemy.apply_turned_visual()    # E — the distinct turned-ship visual (inverted player arrowhead + hazard)
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)   # the turned-enemy gives score when later killed (route via _on_enemy_died)
```

#### spawn_enemy_at + the activate-variant fork

`Enemy.activate(p_formation_def, p_slot, p_rng)` is hard-coupled to `FormationDefinition` + `slot`
(sets `slot_world_pos = formation_def.slots[slot]`). The failed-rescue enemy spawns at a WORLD
POSITION mid-wave (no formation slot). Two valid options — **pick one + be consistent**:

- **Recommended — add `Enemy.activate_at(spawn_pos: Vector2, p_rng: RandomNumberGenerator) -> void`:**
  sets `formation_def = null` (or the standard `formation_def` — the states that read it tolerate a
  null since `slot_world_pos` is set directly), `slot_world_pos = spawn_pos`, arms fire, and
  transitions to `FormationState` directly (the enemy is already at the formation row — no EnterState
  descend needed; OR transition to `EnterState` which descends from off-screen to `slot_world_pos` =
  `spawn_pos`, giving a clean "the captive appears and forms up" beat). Reuses the full enemy lifecycle
  (formation fire → dive). This mirrors how the captor's `activate` works (position-based, not
  slot-based — the captor is NOT an Enemy variant for exactly this reason).
- Alternative — refactor `Enemy.activate` to accept an optional position. More invasive (touches the
  signature every caller uses); avoid for 2.3.

Use the `activate_at` variant. **Read `enemies/enemy.gd` + `enemies/states/enter_state.gd` +
`formation_state.gd` before implementing** — confirm the states tolerate `formation_def == null` (they
read `slot_world_pos`, not `formation_def.slots[slot]`, after `activate`). If a state reads
`formation_def`, guard it (`if formation_def != null:`).

#### Turned-ship visual (the failed-rescue enemy) — E

The failed-rescue enemy reuses grunt **behavior + stats** (the existing grunt scene + `EnemyDefinition`)
BUT applies a **distinct visual** so it reads as a "captured, turned enemy" (a player-family silhouette
gone hostile), not a stock grunt:

- **Shape:** the **player-ship arrowhead** (the player's `Visual/Core` polygon — `0,-17 / -15,10 /
  -8,14 / 0,10 / 8,14 / 15,10` from `player.tscn`), **inverted to point DOWN** (flip the y-signals, or
  set the `Visual`'s `scale.y = -1.0`). A downward-pointing rescuer-arrowhead = "your ship, turned."
  Never the grunt's silhouette, never the pellet/parallel-bar hazard shapes (D16/UX color-safety — the
  distinct silhouette is the load-bearing read).
- **Color:** hazard-family (the grunt's hazard hue / `{colors.hazard}`, NOT the player's hero-neon) —
  the inversion + color together signal "player shape but hostile." A **bright outline is OPTIONAL**
  here (it's enemy-family now); keep it readable under `debug_toggle_monochrome`.
- **Scale:** ~the player's visual scale (so it reads as a ship, not a grunt).

**Implementation — `Enemy.apply_turned_visual() -> void`** (new method on `enemies/enemy.gd`, called by
`spawn_enemy_at` after `activate_at`):
```gdscript
func apply_turned_visual() -> void:
	# E — the failed-rescue enemy: a captured ship turned hostile. Swap the grunt silhouette for the
	# player-ship arrowhead INVERTED (pointing down) + hazard color. Behavior/stats are unchanged (still
	# a grunt). The Visual is a Polygon2D (_visual) set up in _ready from definition.silhouette_*; override
	# the polygon points + color + y-flip here.
	if _visual == null:
		return
	_visual.polygon = _TURNED_SHIP_POLY   # the player arrowhead points (a const PackedVector2Array)
	_visual.scale = Vector2(_turned_scale, -_turned_scale)  # invert y → points down; x scale stays
	_visual.color = _TURNED_HAZARD_COLOR   # hazard hue (Constants/palette — NOT hero-neon)
```
`_TURNED_SHIP_POLY` = the player's arrowhead points (hardcode them — they're a design constant, not a
tuning knob). `_turned_scale` / `_TURNED_HAZARD_COLOR` — read from `Constants`/palette or
`docked_ship_tuning.tres`. Keep the turned-enemy on `LAYER_ENEMY` (its `FactionComponent` is ENEMY);
the visual change is cosmetic, the collision/faction are grunt.

> Why a method on `Enemy` (not a new scene/.tres): the turned-enemy is a one-off visual variant of the
> grunt, spawned only on failed-rescue. A `const` polygon override + a method is lighter than a new
> scene + `.tres` for a single cosmetic swap. If 2.8 adds captor variety with more turned-ship types,
> promote to a `enemy_turned.tres` then.

### 🎯 Arena — `_on_captor_resolved` (the run-scope resolution)

```gdscript
func _ready() -> void:
	# ...existing wiring...
	# Story 2.3 — the spawner routes captor deaths here for run-scope resolution (rescue dock vs
	# failed-rescue enemy spawn). LOCAL signal (spawner→Arena, D8 intra-scene).
	if not _spawner.captor_resolved.is_connected(_on_captor_resolved):
		_spawner.captor_resolved.connect(_on_captor_resolved)


func _on_captor_resolved(rescue: bool, at: Vector2) -> void:
	# The captor was killed. Arena owns the run-scope resolution (AR2). Per the Mrdth-confirmed economy
	# (2026-07-12): the ONLY ship-count changes are capture (−1, already in 2.2) and keep (+1, 2.5).
	# Rescue docks a fighter (no ship change); failed-rescue turns the captive enemy (+1 enemy, NO ship
	# change — the epics AC2 "−1 ship" is relative-accounting vs the keep +1, NOT a spend). NO respawn
	# in either branch (the player's ship is fine). Runs inside the physics step (captor death originates
	# in a body_entered callback) — see "Physics-step safety is inherited." spawn_enemy_at does
	# acquire+add_child (safe mid-physics, same as the drip _spawn_enemy); NO game-over path here
	# (failed-rescue can't drop ships to 0 — it doesn't spend one).
	if rescue:
		_player.try_dock_ship()
		# Rescue juice — pickup-style (no dedicated spec; see "Juice gaps"). One-line JuiceFx helper
		# (mirrors JuiceFx.player_hit) — a particle burst in the dock color at the player + a positive SFX.
		JuiceFx.rescue(_player.global_position)
	else:
		# Failed-rescue: the captured ship turns enemy (+1 enemy). NO ship-count change, NO respawn.
		# [Ref-11] — the "−1 ship" in the epics AC is relative-accounting, not an actual spend.
		_spawner.spawn_enemy_at(at)
		# Failed-rescue juice — hazard sting at the captor's death position. One-line JuiceFx helper:
		# a hit_flash on the player body in the hazard color + a shake + a particle burst + a negative SFX.
		JuiceFx.failed_rescue(at, _player)
```

The `JuiceFx.rescue` / `failed_rescue` helpers (Task 6) source their colors/amounts internally from
`_TUNING` (`juice_tuning.tres`) + the palette tokens — Arena calls them one-line. Do NOT hardcode
`Color(...)` literals in Arena. If a `dock` palette token doesn't exist yet (UX OQ3 — `{colors.dock}`
is a provisional alias), use `HudPalette.PRIMARY` as a placeholder + flag it. The docked ship's own
color is `DockedShipTuning.dock_color` (data-driven).

### 🎯 Player — `try_dock_ship` + `set_docked` + `apply_hit` + `_consume_docked_ship`

```gdscript
var _docked_ship: DockedShip = null
var _docked := false


func is_docked() -> bool:
	# FireSystem reads this to spawn the parallel stream (AC#3 +firepower). Public read accessor.
	return _docked


func is_capture_immune() -> bool:
	# 2.3 — retired the 2.2 stub. Docked ⇒ capture-immune (FR16). The guard is real + now wired to the
	# docked state (try_capture checks it). 2.4 deepens set_docked to also grow the hitbox ([Risk-12]).
	return _docked


func set_docked(on: bool) -> void:
	# The architecture-named write-side (architecture.md:616 `set_docked(true) # capture-immune + bigger
	# hitbox`). 2.3: flips _docked (capture-immune) AND grows/shrinks the player's hitbox (the +hitbox,
	# AC#3). 2.4 deepens this to the formal [Risk-12] tradeoff + persists the wing_track.
	_docked = on
	_resize_hitbox(on)   # swap the body CollisionShape2D + the HurtboxComponent shape (see below)


func _resize_hitbox(docked: bool) -> void:
	# The +hitbox (AC#3): the player's hitbox grows when docked (a bigger target — the docked ship makes
	# you easier to hit, [Risk-12]). Swap the body CollisionShape2D (projectiles body_enter this) + the
	# HurtboxComponent's CollisionShape2D (contact) between the clean radius (11) and the docked radius.
	# duplicate() the shared shape before resizing (mirrors captor.gd:62-66 — a per-instance radius must
	# never race on the shared inherited shape resource). collision_mask=0 ⇒ growing the body shape only
	# affects what body_enters it (projectiles) — NO physics/movement impact.
	var radius: float = docked_ship_tuning.docked_hitbox_radius if docked else _CLEAN_HITBOX_RADIUS
	_swap_circle_radius(_collision_shape, radius)
	_swap_circle_radius(_hurtbox_shape, radius)


func _swap_circle_radius(shape_node: CollisionShape2D, radius: float) -> void:
	if shape_node == null:
		return
	var shape := shape_node.shape as CircleShape2D
	if shape == null:
		return
	var dup := shape.duplicate() as CircleShape2D   # never mutate the shared resource in place
	dup.radius = radius
	shape_node.shape = dup


func try_dock_ship() -> bool:
	# The rescue EFFECT entry (AC#1). Guards: no existing docked ship (FR14 one-docked — a second
	# rescue/dock cannot occur). On success: instantiate + attach the DockedShip, set_docked(true)
	# (which grows the hitbox — the +hitbox). Returns true so Arena/juice can gate. The player never
	# touches RunState (AR2 — rescue is a combat attach, not a ship-count change; the captured ship
	# was spent at capture in 2.2).
	if _docked_ship != null:
		return false   # FR14: at most one docked ship. (Capture is once-per-wave, so this is defensive.)
	if docked_ship_scene == null:
		push_error("Player: docked_ship_scene unassigned — rescue dock ignored")
		return false
	_docked_ship = docked_ship_scene.instantiate()   # NOT pooled — once-per-wave (NP1 pseudocode verbatim).
	add_child(_docked_ship)   # child of the Player — rides the player's transform at the dock offset.
	_docked_ship.setup(self)
	_docked_ship.attach()
	set_docked(true)
	return true


func apply_hit(damage: int, impact_pos: Vector2, source: Node2D, heavy: bool = false) -> void:
	# The CENTRALIZED damage route (AC#3 absorber). Both enemy_projectile + HurtboxComponent call this
	# instead of HealthComponent.take_damage directly. Gate order: i-frames (full no-op, no juice) →
	# absorber (if docked, the docked ship dies first, sparing HP) → HP damage + player-hit juice.
	# Runs inside the physics step (body_entered callback) — only node REMOVAL is forbidden mid-physics;
	# _consume_docked_ship does remove_child + queue_free on the docked fighter, so DEFER that (see
	# _consume_docked_ship). take_damage + signal emits are safe synchronous.
	if _health.is_invulnerable():
		return   # i-frames: full no-op (no damage, no juice) — mirrors the old hurtbox/projectile gating.
	if _docked_ship != null:
		_consume_docked_ship(impact_pos, source)   # absorber: docked ship dies, HP spared. NO spend_ship (ever).
		return
	_health.take_damage(damage)
	JuiceFx.player_hit(impact_pos, source, heavy)


func _consume_docked_ship(impact_pos: Vector2, _source: Node2D) -> void:
	# The intrinsic first-hit absorber (AC#3 / FR17). The docked fighter dies, sparing the player's HP.
	# NO spend_ship — EVER (not 2.3, not 2.5). The FR18 "Absorb = −1 ship" is relative-accounting vs the
	# Keep +1 (you forfeit the regain), NOT a spend. The docked ship is a non-counted combat asset; the
	# ONLY ship-count changes in the Gamble are capture (−1, 2.2) and keep (+1, 2.5). See Dev Notes
	# §"Ship-count economy". detach is DEFERRED (remove_child + queue_free mid-physics is forbidden — the
	# docked ship is a child of the Player, a CanvasItem; use call_deferred on a no-arg method).
	set_docked(false)
	var fighter: DockedShip = _docked_ship
	_docked_ship = null
	# Absorb juice — the docked ship's death (a distinct "the wingman bought it" beat). Reuse enemy_killed
	# in the dock color (no score popup — score_value 0). Emit BEFORE the deferred detach (position valid).
	# dock_color from DockedShipTuning (data-driven, D9 — the docked ship's Visual uses the same color).
	JuiceFx.enemy_killed(fighter.global_position, docked_ship_tuning.dock_color, 0.8, 0)
	fighter.detach.call_deferred()   # no-arg deferred detach (mirrors the Pool deferred-release idiom).


func _on_wave_cleared(_wave: int) -> void:
	# Wave-end cleanup stub (NP1 — docked ship is wave-scope). Detach the docked fighter. NO add_ship in
	# 2.3 — the Keep outcome (survive the wave docked → add_ship(+1), net 0 over capture→rescue→keep) is
	# Story 2.5 (the ONLY add_ship in the Gamble). This stub just clears the fighter so it doesn't persist
	# across the wave boundary. Connect ONCE in _ready (player is NOT pooled).
	# 2.5 seam: add_ship(+1) — the Keep regain (only if the player survived the wave docked).
	if _docked_ship != null:
		var fighter: DockedShip = _docked_ship
		_docked_ship = null
		set_docked(false)
		fighter.detach.call_deferred()
```

`_ready()` addition (connect ONCE — the player is NOT pooled):
```gdscript
# Story 2.3 — wave-end cleanup of the docked fighter (wave-scope, NP1). The Keep outcome (regain ship)
# is 2.5; 2.3 just detaches. Read-only LISTEN (the player still EMITS nothing to the bus for this).
if not EventBus.wave_cleared.is_connected(_on_wave_cleared):
	EventBus.wave_cleared.connect(_on_wave_cleared)
```

### 🎯 apply_hit / absorber contract — routing the two damage paths

Both damage paths currently call `HealthComponent.take_damage()` directly. Route both through
`Player.apply_hit()` so the absorber gate runs:

**`components/hurtbox_component.gd`** (contact damage — owner is the Player):
```gdscript
func _on_body_entered(body: Node2D) -> void:
	# Route through the player's apply_hit (AC#3 absorber). The hurtbox's owner is the Player.
	# Fallback to the old HealthComponent path for any non-player owner (defensive — the hurtbox is
	# player-only today, but keep the fallback so a future enemy-hurtbox doesn't silently no-op).
	if owner != null and owner.has_method("apply_hit"):
		owner.call("apply_hit", contact_damage, global_position, body, false)
		return
	# ...existing fallback: _health.take_damage(contact_damage) + JuiceFx.player_hit(...) ...
```
Note: `owner.call("apply_hit", ...)` — use `call()` (duck-call) to avoid a hard `Player` type coupling
in the shared `HurtboxComponent` (mirrors the captor's `player_target.call("try_capture")` duck-call
from 2.2). The juice moves INTO `apply_hit` (so the absorber can suppress it on an absorb).

**`enemies/enemy_projectile.gd`** (projectile damage — body is the Player, masked to LAYER_PLAYER):
```gdscript
func _on_body_entered(body: Node2D) -> void:
	if _consumed:
		return
	_consumed = true
	# Route through the player's apply_hit (AC#3 absorber) — duck-call (the projectile is player-agnostic).
	if body.has_method("apply_hit"):
		body.call("apply_hit", _damage, global_position, body, _heavy)
	else:
		# Fallback (defensive — the projectile only hits LAYER_PLAYER = the Player, so this is unreachable
		# in practice; keep it for safety + for any future non-player LAYER_PLAYER body).
		var hc: Node = body.get_node_or_null("HealthComponent")
		if hc != null and hc.has_method("take_damage"):
			hc.take_damage(_damage)
	# ...the _consumed guard + the i-frame juice check are now INSIDE apply_hit (it gates i-frames)...
	Pool.release.call_deferred(self)
```
**Critical:** the old code captured `was_invulnerable` BEFORE `take_damage` to skip juice on i-frame
hits. That logic MOVES INTO `apply_hit` (it gates i-frames → no-op, no juice). So REMOVE the
`was_invulnerable` + `JuiceFx.player_hit(...)` lines from the projectile/hurtbox (they're now in
`apply_hit`). Do NOT double-emit juice.

**`player/projectile.gd`** (player bullet hitting ENEMIES) is UNCHANGED — enemies have no docked ship;
they keep `body.HealthComponent.take_damage()`.

### 🧩 +hitbox = the player's hitbox grows (NOT a docked-ship hitbox)

AC#3's "+hitbox" is the player's OWN hitbox growing when docked (the docked ship makes you a bigger
target — [Risk-12]). It is NOT a separate hitbox on the DockedShip (that would double-trigger
`apply_hit` — see the gotcha). `set_docked(on)` calls `_resize_hitbox(on)` which swaps the radius on
TWO shapes:

- The player's body `CollisionShape2D` (`$CollisionShape2D`) — enemy PROJECTILES body_enter this (the
  projectile is an `Area2D` masked to `LAYER_PLAYER`; it detects the player's `CharacterBody2D` body).
- The player's `HurtboxComponent/CollisionShape2D` — enemy-body CONTACT damage enters this.

Both grow from the clean radius (11, the current `player.tscn` value) to the docked radius
(`DockedShipTuning.docked_hitbox_radius`, e.g. 18). `duplicate()` each shape before resizing (shared-
resource safety — `captor.gd:62-66` idiom; mutating the shared `CircleShape2D` in place would resize
ALL instances). The player has `collision_mask = 0` ⇒ growing the body `CollisionShape2D` only affects
what body_enters it (projectiles) — NO `move_and_slide` / physics impact.

Add the `@onready` refs to `player.gd` (cache once, never `$` per frame):
```gdscript
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _hurtbox_shape: CollisionShape2D = $HurtboxComponent/CollisionShape2D
const _CLEAN_HITBOX_RADIUS: float = 11.0   # the player.tscn base radius (keep in sync with the scene)
```
+ `@export var docked_ship_tuning: DockedShipTuning` (set in `player.tscn`) for `docked_hitbox_radius`.
2.4 formalizes the [Risk-12] bigger-hitbox-as-tradeoff (the exact geometry + the clean/docked
tradeoff framing); 2.3 implements a basic radius grow.

### 🧩 DockedShip visual contract — `player/docked_ship.gd` + `.tscn`

- `class_name DockedShip extends Node2D`, parented to the `Player` (a child). NO `_physics_process` —
  it rides the player's transform (the dock offset is a local position).
- **Visual (escort-chevron):** a `Polygon2D` "Visual" mirroring the player-ship arrowhead family
  (the player's `Visual/Core` polygon shape) at **~80% scale** (`dock_scale`), positioned at
  `(dock_offset_x, 0)` local. **Bright outline** (a `Line2D` outline, like the player's `Outline`) +
  a faint glow (like the player's `GlowOutline`). Color = `{colors.dock}` (provisional alias of
  `{colors.primary_hover}`, UX OQ3 — use `HudPalette.PRIMARY` as a placeholder + flag it). **NEVER**
  the pellet/parallel-bar silhouette of enemy fire or the tractor (D16/UX color-safety core — the
  shape+outline is the load-bearing CVD defense, not the hue).
- **NO hitbox.** The DockedShip is visual-only (no `Area2D`, no `CollisionShape2D`). The +hitbox is
  the PLAYER's hitbox growing (see §"+hitbox = the player's hitbox grows"). A separate docked-ship
  hitbox would double-trigger `apply_hit` (the player's `HurtboxComponent` + the docked-ship hitbox
  both detect the same enemy body) — avoid.
- `setup(player: Player) -> void` — cache the player ref (for position/juice). `attach() -> void` —
  position at the dock offset, `visible = true`. `detach() -> void` — `visible = false` +
  `queue_free()` (the docked ship is NOT pooled — NP1).

### 🔌 Parallel stream implementation — `player/fire_system.gd`

The +firepower = a parallel bullet stream at +28 px x-offset (FR7/GDD weapon table). Simplest: the
player's existing `FireSystem._spawn()` spawns a SECOND bullet when docked (shares the cooldown →
synced cadence — FR7 "matches the player's fire cadence"):

```gdscript
@onready var _player: Player = get_parent()   # the FireSystem is a child of the Player.


func _spawn() -> void:
	if _muzzle == null or projectile_parent == null:
		return
	_spawn_one(_muzzle.global_position)                       # primary stream
	if _player != null and _player.is_docked():
		_spawn_one(_muzzle.global_position + Vector2(28.0, 0.0))   # docked parallel stream (+28 px, FR7)
	# On-fire juice (unchanged — one juice per fire press, not per bullet).
	JuiceFx.player_fired(_muzzle.global_position)


func _spawn_one(at: Vector2) -> void:
	# Hoist the existing bullet-spawn body (Pool.acquire → activate at `at` → add_child) here so both
	# the primary + the docked stream share it. Zero per-frame allocations (NFR3).
	var p: Projectile = Pool.acquire(projectile_scene) as Projectile
	assert(p != null, "FireSystem: acquired node is not a Projectile — wrong scene?")
	p.activate(at, tuning.bullet_speed, tuning.projectile_damage)
	projectile_parent.add_child(p)
```

Alternative (deferred to 2.4): the `DockedShip` owns its own `FireSystem` (a second FireSystem node
firing from its muzzle). More aligned with NP1 (the docked fighter has its own combat_stats) but
requires cadence-sync (the two FireSystems must fire together). For 2.3, the player's FireSystem
spawning two bullets is simpler + syncs automatically. Open Question H.

### 🚧 Ship-count economy (the corrected model — Mrdth-confirmed 2026-07-12)

The epics AC2 ("failed-rescue = −1 ship, +1 enemy") and FR18 ("Absorb = −1 ship", "Sacrifice = −1 ship")
are **relative-accounting mistakes**, not actual ship spends. The docked fighter is a **ship-in-escrow**:
you paid −1 at capture, and you get +1 back ONLY if you keep it to wave-end. Consuming it (absorb/
sacrifice) or losing it (failed-rescue, no-rescue) **forfeits the regain — it does NOT spend an
additional ship.** The ONLY real ship-count changes across the whole Gamble:

| Event | Ship count | Story |
|---|---|---|
| **Capture** (captor tractors player) | **−1** (`spend_ship`) | 2.2 ✓ |
| **Keep** (rescue + survive wave docked) | **+1** (`add_ship`) → net 0 | 2.5 |
| Rescue (dive-kill → dock) | 0 | 2.3 |
| Failed-rescue (formation-kill) | 0 (+1 enemy only) | 2.3 |
| Absorb (docked ship killed by a hit) | 0 | 2.5 |
| Sacrifice (docked ship consumed for burst) | 0 (by the same logic) | 2.6 |
| No rescue (captor escapes with the ship) | 0 (forfeit the +1 regain) | 2.3 |

**Consequences for 2.3:**
- **Failed-rescue = `spawn_enemy_at(at)` + juice. NOTHING ELSE.** No `spend_ship`, no `ship_lost`, no
  `_on_run_lost`, no `respawn`. The player keeps flying; an enemy appears at the captor's death
  position. The "sting" is the extra enemy, not a ship loss.
- **The absorber (`_consume_docked_ship`) spares HP with NO `spend_ship` — and 2.5 does NOT add a −1
  cost later.** The FR18 "Absorb = −1 ship" is the same relative-accounting mistake. (By the same
  logic, 2.6's Sacrifice is also no ship-count change — flagged for the epics-doc correction below.)
- **No new ship-loss/game-over path in 2.3.** The `Arena._on_player_ship_depleted` → `spend_ship` →
  respawn|game-over path is for CAPTURE (2.2) + HP-death only. Failed-rescue does NOT route through it
  (it doesn't spend a ship). The captor_resolved → Arena path is rescue-dock | enemy-spawn, neither of
  which touches the ship count.
- **The wave-end Keep stub (`_on_wave_cleared`)** detaches the docked fighter with NO `add_ship` in
  2.3. 2.5's Keep outcome adds the `add_ship(+1)` (the regain, net 0). Leave a `# 2.5 seam` comment.

**Epics-doc correction to flag (not in scope to fix here — the epics.md text is the source of truth for
the ACs):** AC2's "−1 ship", FR18's "Absorb (−1 ship)", and FR18's "Sacrifice (−1 ship)" should read as
relative-to-Keep accounting (you forfeit the +1 regain), NOT as `spend_ship` calls. Mrdth to confirm
the Sacrifice implication (the model implies it's also no-change; the epics text says −1).

### 🚧 Wave-end cleanup is a stub (be honest)

2.3's `_on_wave_cleared` detaches the docked fighter (wave-scope, NP1) with NO `add_ship`. The Keep
outcome (survive the wave docked → `add_ship(+1)`, net 0 over capture→rescue→keep) is Story 2.5. So in
2.3, a docked ship held to wave-end just detaches (no regain — the +1 is the 2.5 Keep outcome, the ONLY
`add_ship` in the Gamble). Do NOT claim the Keep outcome is exercised — that's 2.5. Leave a
`# 2.5 seam: add_ship(+1) — the Keep regain` comment in `_on_wave_cleared`.

### 🚧 Retiring the 2.2 stub test

`tests/player/test_player_capture.gd::test_is_capture_immune_returns_false_in_2_2` asserted the 2.2
stub (`is_capture_immune() == false`). 2.3 retires the stub (`is_capture_immune() == _docked`). UPDATE
that test: rename it (e.g. `test_is_capture_immune_reflects_docked_state`) + assert `false` when clean,
`true` after `try_dock_ship()`. Do NOT leave the 2.2 stub test asserting `false` — it will fail.

### 🔌 Signal boundary (D8 — do not violate)

- **Direct/local (unchanged):** `Captor.died`, `Captor.state_changed`, `Player.ship_depleted`,
  `HealthComponent.*`. The captor's `died` now carries `(score_value, state_name, at)` — still local.
- **NEW local signal:** `FormationSpawner.captor_resolved(rescue, at)` — spawner→Arena (intra-scene,
  D8). Mirrors `Player.ship_depleted` → Arena. Arena connects + resolves.
- **EventBus (read-only listens — the one expansion):** the Player SUBSCRIBES to `EventBus.wave_cleared`
  (to detach the docked fighter on wave-end). The player still EMITS nothing to the bus (`ship_depleted`
  stays local). `wave_cleared` is an existing global game-flow signal (WaveController emits it).
- **Do NOT add** `EventBus.rescued` / `failed_rescue` / `docked_ship_attached` — the local
  `captor_resolved` signal covers the routing. Failed-rescue emits NO `ship_lost` (no ship-count
  change — see Dev Notes §"Ship-count economy"). The 2.2 precedent kept `ship_depleted` local; 2.3
  mirrors it.

### ⚡ Physics-step safety is inherited

The captor's `_on_died` runs in a physics callback (player projectile `body_entered` → `take_damage` →
`died.emit`). So `_on_captor_died` (spawner) → `captor_resolved.emit()` → `Arena._on_captor_resolved`
all run inside the physics step. The resolution does:
- `try_dock_ship()` — `instantiate()` + `add_child` (the DockedShip). `add_child` mid-physics is safe
  (the node's `_ready` fires; it processes next frame). The existing `_spawn_enemy` drip runs in
  `_physics_process` (acquire + add_child mid-physics is already done). ✓
- `spawn_enemy_at(at)` — `Pool.acquire` + `add_child` + `activate_at`. Same as the drip. ✓
- **No `spend_ship` / `ship_lost` / `_on_run_lost` in either branch** — failed-rescue doesn't spend a
  ship (the Mrdth-confirmed economy), so there's no game-over path here. The only ship-count change in
  the Gamble is capture (−1, 2.2, via `ship_depleted` → Arena) and keep (+1, 2.5). ✓
- `_consume_docked_ship()` — `remove_child` + `queue_free` on the docked fighter. This is a node
  REMOVAL mid-physics → **DEFER it** (`fighter.detach.call_deferred()`). The `set_docked(false)` +
  `_docked_ship = null` + juice emit are synchronous (safe); only the detach is deferred. ✓

No new synchronous tree-free. The `apply_hit` path (enemy_projectile/hurtbox → `apply_hit` →
`take_damage`/`_consume_docked_ship`) inherits the existing physics-step safety (`take_damage` is
sync-safe; the docked-ship detach is deferred).

### Gotchas that will bite

- **`is_connected` + bound callables.** Do NOT use `captor.died.connect(_on_captor_died.bind(captor))`
  — bound callables compare unreliably in `is_connected` across pool cycles, so the
  `if not captor.died.is_connected(...)` guard breaks (double-connect → duplicate emits). Have the
  `died` signal carry the computed `rescue` bool + `at` instead (Key Decision #1) — the captor owns
  `captured_player` + `current_state_name`, so it computes `rescue` and the spawner just routes the
  bool. The un-bound `captor.died.connect(_on_captor_died)` guard works correctly.
- **The `died` signature change ripples to the spawner handler.** `_on_captor_died(_score_value: int)`
  → `_on_captor_died(_score_value: int, rescue: bool, at: Vector2)`. The connection itself
  (`captor.died.connect(_on_captor_died)`) is unchanged. GUT tests that connect to `captor.died`
  (if any — `test_captor_fsm.gd` connects `state_changed`, not `died`) must update their handler
  signature. Verify the FSM tests don't break (they shouldn't — they don't connect `died`).
- **Double juice on the absorber.** The old hurtbox/projectile emitted `JuiceFx.player_hit()` AFTER
  `take_damage`. With `apply_hit`, the juice moves INSIDE `apply_hit` (so the absorber can suppress it
  on an absorb). REMOVE the `was_invulnerable` + `JuiceFx.player_hit(...)` lines from the
  hurtbox/projectile — do NOT double-emit. The absorber emits its OWN juice (`enemy_killed` in the dock
  color via `_consume_docked_ship`), NOT `player_hit`.
- **The absorber must NOT fire during i-frames.** `apply_hit` gates i-frames FIRST (`if
  _health.is_invulnerable(): return`). A hit during i-frames is a full no-op (no absorb, no damage, no
  juice) — so the docked ship is NOT consumed by an i-frame hit. (Mirrors the old gating — a hit during
  i-frames must not burn the absorber.)
- **The docked ship is NOT pooled.** `instantiate()` + `queue_free()` (NP1 pseudocode verbatim). It's
  created/destroyed at most once per wave (FR14 one-docked). Do NOT route it through `Pool` — the
  pooling rule (D7) is for hot-path types (projectiles/particles/enemies), not the once-per-wave
  docked fighter.
- **The docked ship is parented to the Player.** So its `global_position` rides the player's transform
  + the dock offset. Do NOT give it a `_physics_process` (it doesn't move independently). It is visual-
  only (NO hitbox — the +hitbox is the player's own hitbox growing via `set_docked`).
- **`remove_child` + `queue_free` mid-physics is forbidden.** `_consume_docked_ship` defers the detach
  (`fighter.detach.call_deferred()`). The `set_docked(false)` + `_docked_ship = null` are synchronous
  (so `is_docked()` / `is_capture_immune()` flip immediately — a same-frame second hit lands on the
  player, not a consumed docked ship). The juice emits BEFORE the deferred detach (position valid).
- **`.tres` overrides `.gd` defaults at runtime** (memory `tres-overrides-gd-default-for-tuning`). If
  you add `DockedShipTuning`, create `resources/docked_ship_tuning.tres` with real values — editing
  only the `.gd` defaults has no runtime effect.
- **GUT silent-skip trap.** After adding the `DockedShip` class_name, run `godot --headless --import`
  before GUT, and **verify the Scripts/Tests COUNTS** (memory `gut-classname-reindex-silent-skip`).
- **The failed-rescue enemy needs `player_target`.** `spawn_enemy_at` sets `enemy.player_target =
  player` (so the turned-enemy's DiveState can aim at the player). Mirrors `_spawn_enemy`.
- **Do NOT port the prototype.** The JS prototype's capture/rescue storage is a different design.
  Meridian Run's rescue is the captor's dive-kill → dock; failed-rescue is the formation-kill → ship-
  turns-enemy. Re-derive in Godot idioms (memory `prototype-is-reference-only`).
- **The `apply_hit` duck-call.** `owner.call("apply_hit", ...)` / `body.call("apply_hit", ...)` — use
  `call()` (duck-call) to avoid hard `Player` type coupling in the shared `HurtboxComponent` + the
  `enemy_projectile` (mirrors the captor's `player_target.call("try_capture")` from 2.2). The fallback
  to `HealthComponent.take_damage` is for safety (non-player owners).
- **The 2.2 `try_capture` same-frame guard.** `try_capture()` checks `_health._is_dead` (the 2.2
  review fix for the same-frame double ship-loss race). `apply_hit` is the NEW central damage route —
  ensure `try_capture`'s guard still holds (capture + an HP-hit in the same frame must not spend two
  ships). `apply_hit` calls `_health.take_damage`, which sets `_is_dead` + emits `died` →
  `_on_ship_depleted` → `ship_depleted`. `try_capture` checks `_health._is_dead` BEFORE emitting
  `ship_depleted`. So the guard is preserved (verify with a test: a captor capture + an HP-hit in the
  same frame → one ship spent, not two).

### Scope seams (hand off cleanly to 2.4 / 2.5 / 2.8)

- **2.4 seam (docked dual nature / permanent track / tradeoff):** `Player.set_docked()` is the write-
  side (2.3 flips `_docked`; 2.4 deepens to grow the hitbox per [Risk-12] + persist
  `RunState.BuildState.wing_track`). `is_capture_immune()` is retired (returns `_docked`). The +28 px
  stream offset + the dock offset are hardcoded in 2.3 (or `DockedShipTuning`); 2.4 pins them + adds
  the bigger-hitbox-as-tradeoff. Leave a `# 2.4 seam` comment in `set_docked` for the track + hitbox.
- **2.5 seam (four docked-ship outcomes):** 2.3 implements the dock + the absorber MECHANIC (spare HP,
  no ship-count change) + the wave-end detach stub (no `add_ship`). 2.5 adds: **Keep** (survive wave
  docked → `add_ship(+1)`, net 0 — the ONLY `add_ship` in the Gamble) + the Sacrifice input + the
  four-outcomes integration gate. **Absorb + Sacrifice are NO ship-count change** (the FR18 "−1 ship"
  for both is relative-accounting vs the Keep +1, NOT a spend — Mrdth-confirmed). Leave a
  `# 2.5 seam: add_ship(+1) — the Keep regain` comment in `_on_wave_cleared`.
- **2.8 seam (captor wave integration):** captors still spawn ONLY via the F8 debug cheat in 2.3
  (captor-presence in the wave drip is 2.8). The rescue/failed-rescue branch is state-driven + works
  for any captor (debug-spawned now, drip-spawned in 2.8).

### Out of scope for 2.3 (do NOT build — prevents scope creep)

- **The permanent `RunState.BuildState.wing_track`** — Story 2.4 (the dual-nature persistence; "the
  consume path never clears the track").
- **The Sacrifice burst + the Sacrifice/Keep/Absorb resolutions** — Story 2.5 / 2.6. (2.3's absorber
  spares HP with NO ship-count change; 2.5 adds the Keep `add_ship(+1)` + the Sacrifice input + the
  four-outcomes gate. Absorb + Sacrifice are NO ship-count change — the FR18 "−1 ship" is relative-
  accounting, NOT a spend.)
- **The bigger-hitbox-as-tradeoff ([Risk-12])** — Story 2.4 (2.3's +hitbox is a basic contact-damage
  extension; 2.4 formalizes the tradeoff for both contact + projectile).
- **Captor presence in the wave drip / onboarding cadence / captor-chance scaling** — Story 2.8 (2.3
  spawns captors ONLY via F8).
- **A distinct "turned-ship" enemy visual** — 2.3 reuses the grunt scene (hazard family). A bespoke
  "captured ship turned enemy" visual (player silhouette recolored hazard) is a 2.8/polish follow-up.
- **A `captors_active` HUD feed / a rescue-or-failed-rescue toast** — not an AC; rescue/failed-rescue
  is communicated diegetically (the docked wingman appears on rescue / an enemy appears on failed-
  rescue). Failed-rescue does NOT change the lives display (no ship-count change). Toasts are between-
  wave only (UX).
- **A new `EventBus.rescued` / `failed_rescue` signal** — the local `captor_resolved` signal covers
  the routing (D8). Failed-rescue emits NO `ship_lost` (no ship-count change).

### Performance / hot-path (NFR2, AR14)

- `_on_captor_died` → `captor_resolved.emit()` → `_on_captor_resolved` runs only on a captor death
  (rare; at most one debug-spawned captor at a time in 2.3). Trivial cost.
- `apply_hit` runs on every player hit (contact + projectile) — one `is_invulnerable()` + one
  `_docked_ship != null` check + the existing `take_damage`. Negligible overhead (two branch checks).
- The parallel bullet stream spawns one extra `Projectile` per fire when docked — pooled (acquire +
  release), same cost as the primary bullet. The fire cooldown is shared (no rate change). ✓
- The +hitbox grows the player's existing `CollisionShape2D` + `HurtboxComponent` shape (a `duplicate()`
  + radius swap on dock/undock — one-time per dock state change, NOT per frame). No extra `Area2D`. ✓
- All in `_physics_process` (fixed 60 Hz) or signal callbacks. No per-frame allocations in the hot
  path (`apply_hit` reuses cached refs; `_spawn_one` is hoisted). ✓

### Testing (GUT)

- **Captor died signal** = integration (instantiate `captor.tscn`, drive to a state, kill). Mirror
  `test_captor_fsm.gd`'s physics-driving.
- **Rescue branch** = integration (spawner + captor + a `captor_resolved` listener). Assert the branch
  keys off `current_state_name` (dive → rescue, else → failed-rescue).
- **Player dock + absorber** = integration (instantiate `player.tscn`; assert `try_dock_ship`,
  `is_capture_immune`, `apply_hit` absorber spares HP, i-frames no-op).
- **Arena resolution** = integration (arena + spawner + run_state; emit `captor_resolved` → assert
  dock / enemy-spawn + ship-loss / game-over).
- **FireSystem docked** = integration (dock the player; fire; assert two bullets at +28 px).
- `before_each()`: `Pool.clear()`. Expect benign exit-leak warnings (memory
  `gut-exit-leak-warnings-expected`); trust Passing/Failing.

### Project Structure Notes

- `enemies/captor/captor.gd` — +`captured_player` flag (F), extends `died` to carry the computed `rescue` bool + `at` (AC#1/#2 enabler; the captor owns the `dive + captured_player` rescue condition).
- `player/docked_ship.gd` + `.tscn` — NEW (the transient docked fighter: visual-only — no hitbox; the
  +hitbox is the player's own hitbox growing via `set_docked`). Lives in `player/`
  (architecture.md:477 `docked_ship.tscn / docked_ship.gd`).
- `player/docked_ship_tuning.gd` + `resources/docked_ship_tuning.tres` — NEW (the hardcoded
  docked stats: +28 px stream/dock offset, docked hitbox radius, scale, dock color, absorber flag).
  Flat under `resources/` (matches `player_tuning.tres` / `captor_tuning.tres`).
- `player/player.gd` — +`_docked_ship`/`_docked`, retires `is_capture_immune` stub, +`try_dock_ship`/
  `set_docked`/`apply_hit`/`_consume_docked_ship`/`_on_wave_cleared`, +`wave_cleared` listen.
- `player/fire_system.gd` — +the parallel bullet stream when docked (hoist `_spawn_one`).
- `world/formation_spawner.gd` — +`captor_resolved` signal, flesh out `_on_captor_died`, +`spawn_enemy_at`.
- `world/arena.gd` — +`_on_captor_resolved` (rescue/failed-rescue) + the `captor_resolved` connect.
- `components/hurtbox_component.gd` — routes to `apply_hit` (duck-call + fallback).
- `enemies/enemy_projectile.gd` — routes to `apply_hit` (duck-call + fallback).
- `enemies/enemy.gd` — +`activate_at(pos, rng)` (the position-based activate variant) + `apply_turned_visual()` (E — the inverted-player-arrowhead + hazard visual override for the failed-rescue enemy).
- `enemies/captor/states/capture_state.gd` — on a successful `try_capture`, set `_captor.captured_player = true` (F — the prior-capture gate flag; mirrors the existing local `_captured`).
- `juice/juice_fx.gd` — +`rescue(at)` + `failed_rescue(at, target)` static helpers (the rescue/failed-rescue juice).
- `player/player.tscn` — wire `docked_ship_scene` + `docked_ship_tuning` @exports.
- Tests under `tests/enemies/`, `tests/player/`, `tests/world/`, `tests/components/` — mirror domain
  layout. No new folders.

### Project Context Rules

- **Engine:** Godot 4.6, GDScript, 2D, Compatibility renderer. Pin to 4.6.x; no 4.7-only APIs.
- **2D physics:** `CharacterBody2D` + `move_and_slide()` (no args, applies delta internally). `Area2D`
  `body_entered` fires during the physics step — node removal mid-callback is forbidden (defer it).
- **Collision layers (from `Constants`):** player=1 / enemy=2 / player_projectile=4 / enemy_projectile=8
  / pickup=16. The player's `HurtboxComponent` masks `LAYER_ENEMY` (contact). The enemy_projectile masks
  `LAYER_PLAYER` (the player body). The failed-rescue enemy is `LAYER_ENEMY` (via FactionComponent).
  The DockedShip has NO collision (visual-only — the +hitbox grows the player's existing shapes).
- **Signal boundary (D8):** global flow → EventBus; local → direct signals. `captor_resolved` is a
  LOCAL spawner→Arena signal. The player only LISTENSs to `wave_cleared` (read-only). No new bus signal.
- **State ownership (AR2):** ships run-scope on `RunState`/Arena. The rescue dock is player-domain; the
  failed-rescue ship-loss is Arena; the enemy spawn is spawner-domain. The player never touches
  `RunState` (rescue is a combat attach, not a ship-count change).
- **Data over code (D9):** the +28 px offsets + dock scale in `DockedShipTuning.tres` (the `.tres` wins).
- **No `print()` / no try-catch:** route logging via `Log.*`; `assert`/`push_error` + fail-safe defaults.
- **Pooled entities re-init via `activate()`, never `_ready()`.** The DockedShip is NOT pooled (NP1 —
  `instantiate`/`queue_free`, once-per-wave). The failed-rescue enemy IS pooled (`spawn_enemy_at` →
  `Pool.acquire` → `activate_at`).
- **No bespoke FSMs (D6):** unchanged — the DockedShip has no FSM (it's a static child).
- **Composition over inheritance:** the DockedShip is a Visual-only node (no hitbox, no inheritance).
  The absorber is a method on the Player (`apply_hit`), not a component. The +hitbox grows the
  player's existing `CollisionShape2D`/`HurtboxComponent` shapes (no new component).
- **Shape+outline (D16/UX color-safety):** the DockedShip is player-family (escort-chevron + bright
  outline, `{colors.dock}`); the failed-rescue enemy is hazard-family (grunt silhouette, no bright
  outline). NEVER confuse the two — the shape+outline is the load-bearing CVD defense.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.3] — ACs (FR15 rescue on dive-kill, failed-rescue on formation-kill, [Ref-11]).
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 2] — "E2 hardcodes the docked-ship +firepower/+hitbox (no premature StatBlock)" (line 427/242). Story 2.4 ACs (the +28 px stream, bigger hitbox, capture-immunity, permanent track — line 483–485). Story 2.5 ACs (the four outcomes — line 497–500).
- [Source: _bmad-output/planning-artifacts/gdds/gdd-meridian-run-2026-06-29/gdd.md#Capture/Rescue/Sacrifice] — FR15, [Ref-11] ("kill boss during dive to rescue; kill in formation = ship turns against you"), the docked-ship dual nature (+firepower, +hitbox, intrinsic first-hit absorber), the +28 px stream (weapon table line 222).
- [Source: _bmad-output/planning-artifacts/gdds/gdd-meridian-run-2026-06-29/decision-log.md] — [Ref-11] (line 30), [Risk-12] (line 31), [Build-15] hybrid docked ship (intrinsic absorber).
- [Source: _bmad-output/planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md] — D8 signal boundary (line 248–252); AR2 state ownership (line 142, 198–210); NP1 Docked-Ship Dual Nature + `docked_ship_controller.gd` + `set_docked(true) # capture-immune + bigger hitbox` (line 600–631, 616); `docked_ship.tscn/.gd` in `player/` (line 477); D16 shape+outline (line 333–334); captor FSM (line 240–242, 485).
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/DESIGN.md] — `docked-wingman-indicator` (escort-chevron, ~80% scale, `{colors.dock}`, bright outline, player-family — line 408–416); `lives-display` (line 364–369); `capture-column` hazard-family (line 399–407).
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/EXPERIENCE.md] — `docked-wingman-indicator` states (line 222–224); juice register (line 432–453); accessibility floor (line 284–287).
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/review-accessibility.md] — the hero-vs-hazard shape+outline CVD defense (line 24–48, 203–232); the failed-rescue enemy MUST be hazard-family.
- [Source: _bmad-output/implementation-artifacts/2-1-captor-enemy-and-5-state-fsm.md] — the captor FSM + the authoritative `current_state_name` + the explicit "2.3 seam: reads current_state_name (dive → rescue, formation/else → failed-rescue)" (line 296–297).
- [Source: _bmad-output/implementation-artifacts/2-2-capture-mechanic-clean-only-once-wave.md] — the `try_capture` pattern (player-as-trigger), the `is_capture_immune()` stub (`# 2.4 seam: return _docked`), the "reuse the ship-loss path" design, the `_health._is_dead` same-frame guard, the duck-call idiom, the physics-step safety inheritance.
- [Source: enemies/captor/captor.gd:26-48, 199-215] — the `died`/`state_changed` signals, `current_state_name`, `_on_died` (the emit + release order this story extends).
- [Source: world/formation_spawner.gd:108-125, 229-235] — `spawn_captor_at` + the `_on_captor_died` seam (the exact method this story fleshes out).
- [Source: player/player.gd:23, 88-113, 94-98] — `ship_depleted`, `_on_ship_depleted`, `try_capture`, `is_capture_immune` (the 2.2 stub this story retires), `respawn`.
- [Source: world/arena.gd:50-70] — `_on_player_ship_depleted` (the capture/HP-death ship-loss path — 2.3 does NOT route failed-rescue through it; failed-rescue is no ship-count change).
- [Source: run/run_state.gd:28-34, 43-48] — `spend_ship() -> int` (the −1 ship), `add_ship()` (forward-compat, unused — the Keep regain is 2.5).
- [Source: components/health_component.gd:37-66, 80-88] — `is_invulnerable`, `take_damage`, `_is_dead`, `reset_to_full` (the i-frame gate + damage path `apply_hit` centralizes).
- [Source: components/hurtbox_component.gd:35-45] — the contact-damage path this story routes through `apply_hit`.
- [Source: enemies/enemy_projectile.gd:71-92] — the projectile-damage path this story routes through `apply_hit`.
- [Source: enemies/enemy.gd:79-110, 157-177] — `activate` (the formation-coupled slot-based activate — why `activate_at` is needed), `_on_died`, `_release_to_pool`.
- [Source: player/fire_system.gd:45-61] — `_spawn` (the bullet-spawn body this story hoists + extends for the parallel stream).
- [Source: systems/event_bus.gd:23-28] — `wave_cleared`, `ship_lost`, `game_over` (the reused signals).
- [Source: systems/constants.gd:9-13] — `LAYER_PLAYER`/`LAYER_ENEMY`/`LAYER_ENEMY_PROJECTILE` (the hurtbox + projectile masks).
- [Source: juice/juice_fx.gd:27-44] — `player_hit`, `enemy_killed` (the juice helpers reused for the absorber + failed-rescue sting).

---

## Open design questions for Mrdth

**A. ✅ RESOLVED (2026-07-12) — Failed-rescue: NO ship-count change.**
Failed-rescue (formation-kill) = `spawn_enemy_at(at)` + juice ONLY. No `spend_ship`, no `ship_lost`,
no respawn. The epics AC2 "−1 ship" is relative-accounting vs the Keep +1, NOT a spend. (See Dev Notes
§"Ship-count economy".) The `no-respawn` + `no-double-count` questions are moot — there's no ship loss.

**B. ✅ CONFIRMED (2026-07-12) — 2.3 delivers the FULL AC3 combat presence.**
2.3 = dock + +firepower parallel stream + +hitbox (the player's hitbox grows) + intrinsic absorber +
capture-immunity via `set_docked`, all hardcoded/basic. 2.4 deepens (permanent `wing_track`, +28 px
pin, bigger-hitbox-as-[Risk-12]-tradeoff, wave-scope/transient framing).

**C. ✅ RESOLVED (2026-07-12) — The absorber spares HP with NO −1 ship, in 2.3 AND 2.5; Sacrifice (2.6) is also no ship-count change.**
The FR18 "Absorb = −1 ship" + "Sacrifice = −1 ship" are the relative-accounting mistake (forfeit the
Keep +1, NOT a spend). 2.5/2.6 do NOT add a −1 cost. Mrdth confirmed the Sacrifice implication
(2026-07-12). The epics FR18 + the GDD docked-ship-resolution section are corrected to match.

**D. ✅ CONFIRMED (2026-07-12) — 2.3 retires the 2.2 `is_capture_immune()` stub.**
`is_capture_immune()` returns `_docked` (wired via `set_docked`). The once-per-wave gate covers the
debug-spawned captors; immunity is also wired for correctness (FR16).

**E. ✅ CONFIRMED (2026-07-12) — Failed-rescue enemy = grunt behavior + a distinct "turned-ship" visual.**
The failed-rescue enemy reuses grunt behavior/stats BUT uses a **distinct visual: the player-ship
arrowhead INVERTED (pointing down) + hazard-colored** — to read as a "captured, turned enemy" (a player-
family silhouette gone hostile), NOT a stock grunt. This is a 2.3 deliverable (the visual distinction is
required for readability). See Dev Notes §"Turned-ship visual (the failed-rescue enemy)".

**F. ✅ CONFIRMED (2026-07-12) — Rescue requires a prior capture (the gate).**
Rescue (dive-kill → dock) happens ONLY if the captor actually captured the player this spawn
(`captured_player == true`) — prevents the "safe rescue" farm (dodge capture + dive-kill → free docked
ship → keep → +1). The captor tracks `captured_player` (set by `CaptureState` on a successful
`try_capture`, reset in `activate`); the rescue condition is `current_state_name == &"dive" AND
captured_player`. A dive-kill WITHOUT capture (player dodged) → failed-rescue (+1 enemy), NOT a rescue.
See Dev Notes §"Prior-capture gate (the rescue condition)". (2.8 is about captor spawn frequency, not
the gate.)

**G. ✅ CONFIRMED (2026-07-12) — `dive + captured` → rescue; ALL ELSE → failed-rescue.**
Combined with F: rescue = `dive AND captured_player`; everything else (dive-without-capture,
formation/telegraph/capture/enter) → failed-rescue (+1 enemy, no ship-count change). Edge case noted: a
captor killed during the `capture` state AFTER capturing (during the reel-in) → failed-rescue by this
rule (it's not `dive`). If playtest wants that to rescue, change the condition to `captured_player`
(any state) — a one-line change. Default keeps the literal AC1 ("dive → rescue").

**H. ✅ CONFIRMED (2026-07-12) — the player's FireSystem spawns the 2nd bullet at +28 px.**
Shares the cooldown → synced cadence. 2.4 may refactor to a DockedShip-owned FireSystem (for the build
track); 2.3 keeps it simple.

**I. ✅ CONFIRMED (2026-07-12) — rescue = pickup-style juice; failed-rescue = hazard sting.**
No dedicated UX spec exists; the defaults reuse the existing `JuiceFx`/EventBus juice channels + respect
the ≤3 Hz flash cap + reduced-motion. (Distinct rescue/failed-rescue SFX can be added in the audio pass.)

---

## Change Log

- 2026-07-12: Story created (ready-for-dev). Ultimate context-engine analysis completed — comprehensive
  developer guide built from epics (FR15/[Ref-11]), the architecture (NP1 docked-ship dual nature, D8
  signal boundary, AR2 state ownership), Story 2.1's explicit 2.3 seam (`current_state_name` +
  `_on_captor_died`), Story 2.2's `try_capture`/`is_capture_immune` stub + "reuse the ship-loss path"
  design, the UX/accessibility shape+outline contracts, and the live captor/player/arena/spawner/
  fire_system/hurtbox/enemy_projectile codebase (verbatim contracts extracted).
- 2026-07-12: **Economy correction (Mrdth-confirmed).** The epics AC2 ("failed-rescue = −1 ship, +1
  enemy") + FR18 ("Absorb = −1 ship", "Sacrifice = −1 ship") are **relative-accounting mistakes**, not
  actual ship spends. The ONLY ship-count changes in the Gamble are capture (−1, 2.2) and keep (+1,
  2.5). Failed-rescue is now `spawn_enemy_at` + juice ONLY (no `spend_ship`, no `ship_lost`, no
  respawn, no game-over). The absorber spares HP with NO `spend_ship` in 2.3 AND 2.5 (not a deferred
  cost). Sacrifice (2.6) is also no ship-count change (Mrdth-confirmed). Open Questions A + C resolved;
  B + D confirmed. **The epics.md (FR18, Story 2.3 AC2, Story 2.5 ACs) + the GDD (docked-ship
  resolution section, sacrifice-burst ceiling) are corrected to match** so the mistake can't re-derive.
- 2026-07-12: **Remaining open questions resolved (E–I, Mrdth-confirmed).** **E** — failed-rescue enemy
  = grunt behavior + a distinct "turned-ship" visual (player arrowhead inverted, hazard color); new
  `Enemy.apply_turned_visual()` method called from `spawn_enemy_at`. **F** — rescue requires a prior
  capture (the gate): new `Captor.captured_player` flag (set by `CaptureState`, reset in `activate`);
  the rescue condition is `dive AND captured_player`; the `died` signal now carries the computed
  `rescue` bool (not `state_name`) — the captor owns the condition, the spawner routes, Arena resolves.
  A dive-kill WITHOUT capture → failed-rescue (closes the "safe rescue" farm). **G/H/I** — confirmed
  the defaults (`dive+captured` → rescue, else failed-rescue; player-FireSystem 2nd bullet at +28px;
  pickup-style rescue juice + hazard failed-rescue sting). Open Questions A–I all closed.

---

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List
