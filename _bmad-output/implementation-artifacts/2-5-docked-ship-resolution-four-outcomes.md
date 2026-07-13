---
baseline_commit: aecd0db
---

# Story 2.5: Docked-Ship Resolution (Four Outcomes)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want a clear choice each wave — sacrifice now or hold — with legible resolutions,
So that the hold-vs-cash micro-tension is real.

## Acceptance Criteria

*(Verbatim from `epics.md` lines 495–500. Tagged **FR18**.)*

1. **AC1 — Sacrifice.** Given a docked ship + the player presses **Sacrifice**, Then the fighter is consumed → **sacrifice burst fires**, track persists (no ship-count change).
2. **AC2 — Keep.** Given a docked ship **held to wave-end alive**, Then it **flies off** → **regain 1 ship (net 0)**.
3. **AC3 — Absorb.** Given a docked ship + the player is **hit while holding**, Then the fighter dies first (absorb), sparing HP (no ship-count change).
4. **AC4 — Four outcomes reachable.** Given all four outcomes (**sacrifice / keep / absorb / failed-rescue**), Then each is reachable and resolves correctly.

> **Read this before estimating scope:** **AC3 (absorb) and the failed-rescue half of AC4 are ALREADY implemented + tested in Story 2.3.** The failed-rescue half of AC4 is ALREADY implemented + tested in Story 2.3 (`arena._on_captor_resolved` else-branch). **The ONLY new mechanics in 2.5 are AC1 (Sacrifice consume + the burst hook) and AC2 (Keep → regain 1 ship).** AC3/AC4 work is *pinning/coverage* — a four-outcomes integration test that proves all four resolve correctly with the right ship-count economy. **Do NOT reimplement absorb or failed-rescue** — see "What is ALREADY DONE" below. The actual sacrifice **buff** (triple-shot / ×1.5 dmg / fast-fire / ~10 s) is **Story 2.6 (NP3)** — 2.5 fires only the *hook* (the `sacrifice_burst_started` event); see "The NP3 / 2.6 seam."

---

## Tasks / Subtasks

### Task 1 — Sacrifice consume path (Player-owned, AC1)  *(AC: #1)*

- [x] **1.1** In `player/player.gd`, add a **local** signal `signal sacrifice_committed()` (intra-entity→parent, D8 — mirrors the existing `ship_depleted`). NO payload: the Arena (RunState owner) enriches the global burst signal with the WING level (AR2 — the Player never touches `RunState`).
- [x] **1.2** Add `func _try_sacrifice() -> void` (called from `_physics_process`, see 1.3). Guard: **only when docked** (`_docked_ship != null`). If not docked → silent no-op (can't sacrifice nothing; do NOT emit). On success: reuse the existing `_detach_docked_ship()` to consume the fighter, then `sacrifice_committed.emit()`. **NO `spend_ship`, NO HP change, NO `take_damage`** — sacrifice is ship-neutral (FR18). The WING track is untouched (structural — the Player has no `RunState` ref, per 2.4's AR2 reconciliation).
- [x] **1.3** In `_physics_process(delta)`, read the `sacrifice` Input Map action and call `_try_sacrifice()` on the trigger (**DECISION Q1: simple press**, Mrdth-confirmed 2026-07-12):
  ```gdscript
  if Input.is_action_just_pressed("sacrifice"):
      _try_sacrifice()
  ```
- [x] **1.4** Sacrifice juice beat (**DECISION Q2: reuse `JuiceFx.docked_consumed`, Mrdth-confirmed 2026-07-12**): call `JuiceFx.docked_consumed(fighter.global_position, dock_color)` — the SAME helper absorb uses. Do NOT add a new `JuiceFx.sacrifice_launched` helper; a distinct "ignition" cue + the full burst visual (glow + enlarge + timer ring) land in **2.6**. Emit AFTER detach but BEFORE the deferred `queue_free` lands (`fighter.global_position` is valid this frame — mirrors `_consume_docked_ship`'s ordering).

### Task 2 — Sacrifice burst hook (EventBus, AC1 — the 2.6 seam)  *(AC: #1)*

- [x] **2.1** In `systems/event_bus.gd`, add `signal sacrifice_burst_started(wing_level: int)`. This is the **global game-flow** signal the architecture names (NP1 line 619) — 2.6's buff subscriber (FireSystem / BuildRecompute) will connect to it. **Payload = `wing_level`** (the WING-track investment that FR19 says the burst "scales with"); it is the stable primitive 2.6's `threat_ceiling(track, threat)` will read via `track.sacrifice_power()`. *(2.6 may WRAP this into a `SacrificeBurst` type — that's a contained change then, since 2.5 has NO subscriber. Do not build `SacrificeBurst` or `BuildRecompute` now — that is NP3/E3.)*
- [x] **2.2** In `world/arena.gd` `_ready()`, connect `_player.sacrifice_committed` → a new `_on_player_sacrifice_committed()` (the Player is NOT pooled → connect ONCE; use the `is_connected` belt-and-braces guard mirroring the captor_resolved connect).
- [x] **2.3** `_on_player_sacrifice_committed()`: `EventBus.sacrifice_burst_started.emit(_run_state.build_state.wing_level)`. The Arena (RunState owner) is the single point that enriches global signals with run-state data (consistent with 2.4's `record_rescue` pattern). **NO buff applies in 2.5** — the event fires (AC1 "sacrifice burst fires" = the hook is invoked); the buff is 2.6. Leave a `# NP3 seam (2.6): subscribe → BuildRecompute.threat_ceiling → apply buff` comment at the emit.

### Task 3 — Keep outcome: regain 1 ship on wave-clear-while-docked (AC2)  *(AC: #2)*

- [x] **3.1** In `player/player.gd`, add a **local** signal `signal ship_kept()` (intra-entity→parent, D8 — mirrors `ship_depleted`).
- [x] **3.2** Rewrite `_on_wave_cleared(_wave)`: **if docked** (`_docked_ship != null`), emit `ship_kept.emit()` **BEFORE** detaching (the Arena must know the player kept the fighter — emit-then-detach). Then call `_detach_docked_ship()` as today (the "flies off"). **If NOT docked** (absorb/sacrifice already consumed the fighter this wave, or the player never docked), do NOT emit `ship_kept` — just the (no-op) detach guard. Retire the stale `# 2.5 seam: add_ship(+1)` comment (now realized via `ship_kept` → Arena).
- [x] **3.3** In `world/arena.gd` `_ready()`, connect `_player.ship_kept` → a new `_on_player_ship_kept()`.
- [x] **3.4** `_on_player_ship_kept()`: `_run_state.add_ship(1)` (the **ONLY `add_ship` caller in the Gamble**; `add_ship` clamps to `Constants.MAX_SHIPS` = 5, FR8 — a keep at max ships is a graceful no-op-clamp). **NO HP change** (WaveController heals HP on clear separately — keep is about *ships*, not HP). This is the `+1` that makes capture→rescue→keep **net 0** (capture was `−1` in 2.2).

### Task 4 — Make the Keep regain VISIBLE (HUD ship-count, AC2)  *(AC: #2)*

> **Why this task exists:** the HUD lives-display (`ui/hud/lives_display.gd::set_ships`) updates **only** on `EventBus.ship_lost` (`hud.gd:58/162`). A keep-regain (`add_ship(+1)`) would otherwise be invisible — the pip row wouldn't reflect the regained ship. The gamble's legibility (E2's whole point) needs the player to *see* the keep payoff.

- [x] **4.1** In `systems/event_bus.gd`, add `signal ship_gained(ships_remaining: int)` (mirrors `ship_lost`'s shape — both carry the remaining count; the HUD handler is identical).
- [x] **4.2** In `_on_player_ship_kept()` (Task 3.4), **after** `add_ship(1)`: `EventBus.ship_gained.emit(_run_state.ships)`.
- [x] **4.3** In `ui/hud/hud.gd`, connect `EventBus.ship_gained` to the **same** `_on_ship_lost` handler (rename it `_on_ship_count_changed(ships_remaining)` if you want clarity — it just calls `_lives.set_ships(ships_remaining, _pip_row_count)`). Keep the existing `ship_lost` connection. Seed logic (`hud.gd:64-67`) is unchanged.

### Task 5 — Pin Absorb + Failed-rescue (AC3, AC4 — ALREADY DONE, confirm)  *(AC: #3, #4)*

> **Do NOT reimplement.** Both work from 2.3. This task is *verify + ensure coverage*, not rebuild.

- [x] **5.1 AC3 (Absorb):** confirmed at `player/player.gd::apply_hit` → `_consume_docked_ship` (i-frames → absorber → HP). Tests: `tests/player/test_player_dock.gd`, `tests/components/test_hurtbox_absorber.gd`. Verify these still pass unchanged after Tasks 1–4.
- [x] **5.2 AC4 (Failed-rescue):** confirmed at `world/arena.gd::_on_captor_resolved` else-branch → `_spawner.spawn_enemy_at(at)` (+1 enemy, no ship change). Test: `tests/world/test_arena_captor_resolution.gd`. Verify unchanged.
- [x] **5.3** Confirm the **forfeit-the-regain** invariant holds for BOTH consume paths: a player who absorbs OR sacrifices mid-wave is NOT docked at wave-clear → `_on_wave_cleared` does not emit `ship_kept` → no `add_ship`. (This is the FR18 "consuming/losing the docked fighter forfeits the keep regain" rule. It is structurally enforced by the `if _docked_ship != null` guard in Task 3.2 — no extra code, but TEST it in Task 6.)

### Task 6 — Four-outcomes integration GUT test (AC4 — the headline)  *(AC: #4)*

- [x] **6.1** New `tests/player/test_player_docked_resolution.gd` (extends `GutTest`; mirrors `test_player_dock.gd`'s `_make()` harness — Player under a `Node2D` arena, `set_physics_process(false)` on the player + FireSystem so YOU drive the frames). Drive all four outcomes from a docked state and assert resolution + ship-count economy:
  - **Sacrifice:** dock → `Input.action_press("sacrifice")` + one physics tick → fighter consumed (`player.is_docked() == false`), HP **unchanged**, `sacrifice_committed` emitted (use `watch_signals`/`assert_signal_emitted`), NO `ship_kept` at a later wave-clear.
  - **Keep:** dock → emit `EventBus.wave_cleared(wave)` → `ship_kept` emitted, fighter detached (`is_docked() == false`). (The `add_ship(+1)` assertion is Arena-level — see 6.2.)
  - **Absorb:** dock → `player.apply_hit(dmg, pos, src)` → fighter consumed, HP **spared** (unchanged), `is_docked() == false`, NO `ship_kept` at a later wave-clear (forfeit-the-regain). Mirrors `test_hurtbox_absorber.gd`'s real-physics-frame approach for the hit.
  - **Mutual exclusion:** sacrifice then wave-clear → only `sacrifice_committed`, NOT `ship_kept`. absorb then wave-clear → neither re-emits. (Proves consume forfeits the keep.)
- [x] **6.2** Extend `tests/world/test_arena_captor_resolution.gd` with the run-scope assertions (Arena owns `RunState`):
  - **Keep → +1 ship:** rescue-dock (wing_level grows) → `wave_cleared` emit → assert `_run_state.ships` increased by 1 (the keep regain) AND `EventBus.ship_gained` emitted with the new count. Cap test: set `ships = MAX_SHIPS` first → keep → still MAX_SHIPS (clamp, FR8).
  - **Sacrifice → no ship change + burst hook:** sacrifice (via the player) → assert `_run_state.ships` **unchanged** AND `EventBus.sacrifice_burst_started` emitted with the current `wing_level`.
  - **Track persists across sacrifice:** rescue (wing_level 1) → sacrifice → assert `wing_level` still 1 (NP1 invariant from 2.4 — re-assert here as a four-outcomes-context check).
  - *(Failed-rescue is already covered in this file from 2.3 — confirm it still asserts no ship change; the failed-rescue + absorb paths are the "no ship-count change" halves of AC4.)*
- [x] **6.3** GUT input-sim note: `Input.action_press("sacrifice")` sets the action pressed; for `is_action_just_pressed`, one `physics_frame` await fires the edge. Release with `Input.action_release("sacrifice")`. Document this in the test header (there is no prior input-sim test in the suite — this is the first).

### Task 7 — Regression gate  *(all ACs)*

- [x] **7.1** Run `godot --headless -s addons/gut/gut_cmdln.gd`. All prior tests still pass (2.3's dock/absorb/captor-resolution/fire-stream suites + 2.4's BuildState/permanence suites are the regression surface — do not alter their behavior). **Check the Scripts/Tests COUNTS**, not just "All passed" (GUT silently skips parse-failed scripts — memory `gut-classname-reindex-silent-skip`). *(2.5 adds NO new `class_name`, so no `--import` reindex is needed.)*
- [x] **7.2** Headless smoke: `timeout 7 godot --headless --path .` (main scene `res://world/arena.tscn`) — no `SCRIPT ERROR` / `Invalid call` / crash on the new signal emits + the auto-replay loop.
- [x] **7.3** F8-spawn a captor in-game, get captured (clean), dive-kill → rescue docks. Then exercise each outcome: **(a) Sacrifice** — press `sacrifice` (Shift) → fighter consumed, watch the debug overlay's ship count stay put + WING track persist; **(b) Keep** — survive the wave docked → watch the lives pip row +1 at wave-clear; **(c) Absorb** — take a hit while docked → fighter dies, HP spared, ships unchanged. **Pending — human/GUI step; the mechanics are covered by the automated suite (330/330) + the headless smoke. The debug overlay already surfaces SHIPS + WING N / MAIN N (2.4), so the economy is watchable in-game. Run the F8 feel-playtest before sign-off.**

### Task 8 — F12 manual run reset (dev QoL, added during 2.5 + retroactively documented at code-review) *(no AC — dev/debug tooling)*

> **Added mid-story, undocumented until the 2.5 code review flagged it (2026-07-12).** Not tied to any AC — this is developer/debug QoL that rode along with the docked-ship-resolution work because manually re-testing the four outcomes repeatedly needed a fast way back to wave 1 without a full engine restart. Retroactively logged here per the review's decision (keep + document + fix gaps).

- [x] **8.1** New `reset` InputMap action in `project.godot` (physical_keycode `KEY_F12`, keyboard-only).
- [x] **8.2** `world/arena.gd::_unhandled_input(event)` — on `event.is_action_pressed("reset")`, calls `_try_reload_run_fresh()` (the guarded entry point — see 8.6).
- [x] **8.3** Renamed `Arena._end_run()` → `_reload_run_fresh()` (unchanged body) so both the run-loss auto-replay path (`_on_run_lost`) and the new F12 path share one reload implementation.
- [x] **8.4** Pinning test: `tests/world/test_arena.gd::test_reset_action_is_bound_to_f12` — asserts the `reset` InputMap action exists and is bound to `KEY_F12`.
- [x] **8.5** [Review][Patch] Gate `_unhandled_input`'s F12 branch behind `OS.is_debug_build()`, matching `Debug`'s own `debug_cheat_*` convention — F12 must not be live in exported/release builds.
- [x] **8.6** [Review][Patch] Add a re-entrancy guard on `_reload_run_fresh` (e.g. an in-flight flag checked before `call_deferred()` is queued, or a `set_input_as_handled()` + no-arm-until-processed pattern) so a same-frame game-over + F12 press, or a double F12 press, cannot queue the reload twice.

### Review Findings

- [x] [Review][Decision] F12 manual-run-reset is undocumented scope creep in this diff — RESOLVED (Mrdth, 2026-07-12): **keep + document + fix gaps.** A new `reset` InputMap action (`project.godot`), `Arena._unhandled_input` (`world/arena.gd:66`), and the `_end_run`→`_reload_run_fresh` rename touching the run-loss auto-replay path (`world/arena.gd:152`) were implemented without ever being added to this story's ACs/Tasks/Dev Notes/Project Structure Notes/File List/Change Log. Resolution: retroactively documented below (Task 8, Dev Notes, Project Structure Notes, File List, Change Log) + the actual 330/330-across-39-scripts count corrected (was misreported as 329/329) + the two hardening gaps below are handled as patches.

- [x] [Review][Patch] `_on_player_ship_kept` emits `ship_gained` even when `add_ship(1)` is a no-op clamp at MAX_SHIPS, producing a phantom "ship regained" HUD cue with no real gain [world/arena.gd:97] — **Fixed:** guarded the emit on `_run_state.ships > ships_before`; pinned with a new assertion in `test_keep_at_max_ships_clamps`.
- [x] [Review][Patch] `test_sacrifice_does_not_change_ship_count` is missing the trailing `await get_tree().physics_frame` its sibling sacrifice tests use to let the deferred fighter `queue_free` land before teardown [tests/world/test_arena_captor_resolution.gd] — **Fixed:** await added.
- [x] [Review][Patch] F12 reset has no `OS.is_debug_build()` gate — unlike `Debug`'s own `debug_cheat_*` actions, F12 stays live in exported/release builds [world/arena.gd:66] — **Fixed:** `Arena._ready()` now calls `set_process_unhandled_input(false)` when `not OS.is_debug_build()`, mirroring `systems/debug.gd`'s own gate.
- [x] [Review][Patch] No re-entrancy guard on `_reload_run_fresh` — a same-frame ship-depleted game-over + F12 press, or a double F12 press, can queue `_reload_run_fresh.call_deferred()` twice [world/arena.gd:73, :149, :152] — **Fixed:** added `_reload_in_flight` guard + a shared `_try_reload_run_fresh()` entry point used by both `_unhandled_input` and `_on_run_lost`.

- [x] [Review][Defer] Deferred-call ordering race between F12's `_reload_run_fresh.call_deferred()` and a same-frame docked-ship `fighter.detach.call_deferred()` — no defined ordering guarantee if both are queued the same frame [world/arena.gd:73] — deferred, pre-existing pattern (same class of issue as other deferred-call orderings in this codebase), narrow low-probability window
- [x] [Review][Defer] Sacrifice input is read every `_physics_process` frame with no gate against the window between `game_over` firing and the deferred reload landing — a sacrifice could commit against a RunState about to be torn down [player/player.gd:_physics_process] — deferred, pre-existing pattern, narrow edge case

**Dismissed as noise (4):** "sacrifice input action never bound" (false positive — the `sacrifice` action already exists at `project.godot:63`, pre-existing outside this diff); "`sacrifice_committed` can emit without a real consume" (false positive — `_try_sacrifice`'s own `_docked_ship == null` guard makes `_detach_docked_ship()` always return non-null on that path, confirmed at `player.gd:302-315`); "inconsistent guard style vs `_on_wave_cleared`" (stylistic only, no behavioral bug — same reason as above); "HUD pip row cap now visibly wrong given Keep" (matches the documented, intentional game-economy invariant — in E2 a docked fighter only ever exists after a capture (−1), so keep (+1) can never push ships above BASE_SHIPS; dev notes call this out explicitly as intentional/out of scope).

---

## Dev Notes

### 🚨 START HERE — what is ALREADY DONE (do not redo)

Story 2.3 shipped **absorb** + **failed-rescue** + the dock attach; 2.4 shipped the **permanent WING track**. **Reimplementing any of this is the #1 scope-creep risk.** 2.5's *only* new mechanics are **Sacrifice consume (AC1)** and **Keep regain (AC2)**.

| Outcome | Where it lives | Status | Test |
|---|---|---|---|
| **Absorb** (AC3) | `player/player.gd::apply_hit` → `_consume_docked_ship` (i-frames → absorber → HP; deferred detach) | ✅ DONE (2.3) | `tests/player/test_player_dock.gd`, `tests/components/test_hurtbox_absorber.gd` |
| **Failed-rescue** (AC4) | `world/arena.gd::_on_captor_resolved` else-branch → `_spawner.spawn_enemy_at` (+1 enemy, no ship change) | ✅ DONE (2.3) | `tests/world/test_arena_captor_resolution.gd` |
| Permanent WING track (NP1) | `run/build_state.gd::record_rescue` (Arena-owned, never cleared by consume) | ✅ DONE (2.4) | `tests/run/test_build_state.gd`, `test_arena_captor_resolved.gd` permanence suite |
| Dock attach / +stream / +hitbox / capture-immune | `player/player.gd::try_dock_ship` / `set_docked` / `is_capture_immune`; `fire_system.gd` | ✅ DONE (2.3, pinned 2.4) | `test_player_dock.gd`, `test_fire_system_docked.gd` |
| `_detach_docked_ship()` shared detach | `player/player.gd` (used by absorb + wave-clear; deferred `queue_free`) | ✅ DONE (2.3 review fix) | — |

**The ONLY new code in 2.5:** Sacrifice input + `_try_sacrifice` + `sacrifice_committed` signal (Task 1); `sacrifice_burst_started` EventBus signal + Arena wiring (Task 2); `ship_kept` signal + Keep detach + Arena `add_ship` (Task 3); `ship_gained` HUD signal (Task 4). Tasks 5–6 are pin + integration test; Task 7 is the gate.

### 🗺️ The four outcomes — code map (AR2 split)

The resolution logic is split **exactly like 2.4's AR2 reconciliation**: the **Player** owns the transient combat side (consume/detach + emit a local signal); the **Arena** owns the run-scope side (`add_ship`, the burst hook, reading `wing_level`). The Player **never touches `RunState`** — that structural guarantee is what makes "track persists" and "forfeit-the-regain" self-enforcing.

| Outcome | Trigger | Player side (combat) | Arena side (run-scope) | Ship Δ |
|---|---|---|---|---|
| **Sacrifice** (AC1) | `sacrifice` input | `_try_sacrifice` → `_detach_docked_ship` → `sacrifice_committed.emit()` | `_on_player_sacrifice_committed` → `sacrifice_burst_started.emit(wing_level)` | **0** |
| **Keep** (AC2) | wave-clear, docked | `_on_wave_cleared` → `ship_kept.emit()` → `_detach_docked_ship` | `_on_player_ship_kept` → `add_ship(1)` + `ship_gained.emit(ships)` | **+1** (net 0 vs capture) |
| **Absorb** (AC3) | hit while docked | `apply_hit` → `_consume_docked_ship` (HP spared) | *(none — no run-scope change)* | **0** |
| **Failed-rescue** (AC4) | kill captor in formation | *(none on player)* | `_on_captor_resolved(false)` → `spawn_enemy_at` | **0** (+1 enemy) |

### 💰 Ship-count economy (the load-bearing constraint — do not "fix")

The docked fighter is a **ship-in-escrow** (Mrdth-confirmed 2026-07-12; memory `gamble-ship-count-economy`). The **ONLY** ship-count changes in the entire Gamble are **capture (`−1`, Story 2.2)** and **keep (`+1`, this story — Task 3)**. Everything else — **rescue, failed-rescue, absorb, sacrifice, no-rescue — is NO ship-count change.**

- **Sacrifice = 0 ships.** Consuming the fighter does NOT call `spend_ship`. It *forfeits the keep regain* (you'd have gotten +1 had you held to wave-end) — that's relative-accounting vs Keep, NOT a spend. Do not add a ship cost to sacrifice.
- **Absorb = 0 ships.** Already correct in 2.3 (`_consume_docked_ship` spares HP with no `spend_ship`).
- **Keep = +1.** This is the FIRST caller of `RunState.add_ship` (it has had no caller since 1.5). Capped at `MAX_SHIPS` (5). Net over a capture→rescue→keep loop = 0.
- **The epics' old "−1 ship" wording for absorb/sacrifice is the corrected-relative-accounting mistake** (FR18 + GDD, 2026-07-12). Ignore it.

### ⌨️ The Sacrifice input shape — DECISION Q1 (Mrdth-confirmed 2026-07-12): simple press

**DECISION: simple press.** `_try_sacrifice()` fires on `Input.is_action_just_pressed("sacrifice")` (Task 1.3). The `sacrifice` Input Map action **already exists** (`project.godot:63` — keyboard **Shift** `physical_keycode 4194325` + gamepad `button_index 9`; both bindings per FR3).

The spec's *eventual* shape is **hold-to-commit** (NP5 / UX EXPERIENCE line 244: *"Sacrifice — `sacrifice`, hold-to-toggle (A1): hold to burn the docked wingman… Releasing before the commit cancels"* + architecture NP5 lines 688–707). It is **deliberately deferred** — land it with the accessibility floor (D14), where `components/hold_to_commit.gd` + the `"BURN THE WINGMAN?"` prompt + reduced-motion dampening ship as a coherent unit. This is low-risk because the consume logic (`_try_sacrifice` → `_detach_docked_ship` → `sacrifice_committed`) is **identical** in both shapes — only the input-read line differs — so the later swap is ~3 lines, not a refactor. `HoldToCommit` will also be reusable (Quit Run, E8). **Do NOT build `HoldToCommit` in 2.5.**

### 🔗 The NP3 / 2.6 seam — 2.5 fires the HOOK, not the buff

AC1 says "sacrifice burst fires." The **buff** (triple-shot ±0.18 rad / ×1.5 damage / fast-fire 0.10 s / ~10 s, threat-relative via `BuildRecompute.threat_ceiling`) is **Story 2.6 (NP3, FR19)**. In 2.5:

- **"The burst fires" = the `EventBus.sacrifice_burst_started(wing_level)` event emits** (Task 2). That is the hook 2.6 subscribes to. **2.5 has NO subscriber** — no buff applies yet. This is correct and intentional; do not stub a buff.
- **Do NOT build** `build/build_recompute.gd`, `SacrificeBurst`, `SacrificeTuning`, or `threat_ceiling` — all NP3/2.6 (and `build/` is E3). The `wing_level` payload is the only forward-compat thread.
- The **sacrifice-burst timer ring** (UX line 161 — renders on the ship for the buff's duration) is **2.6** (it visualizes the buff). 2.5's only sacrifice visual is the consume juice beat (Task 1.4).

### 🧭 The `DockedShipController` stays deferred (2.4's call)

2.4 deferred the `DockedShipController` (NP1's pseudocode home for attach/detach/sacrifice) to **2.6** — "the controller buys nothing until Sacrifice needs an active-input home." 2.5 puts the Sacrifice input + `_try_sacrifice` **directly on the Player** (which already owns `_physics_process`, the docked fighter, and `_detach_docked_ship`). **Do NOT refactor to a controller in 2.5** — it's pure regression risk on tested 2.3/2.4 dock code for zero AC benefit. Leave a `# NP1 seam: docked_ship_controller (deferred to 2.6)` note at `_try_sacrifice`. (If hold-to-commit lands before the controller, its hold logic also lives on the Player for now and migrates with the controller later.)

### ⚙️ Engine / project-context rules that apply

- **No `print()` / no try-catch:** route through `Log`; preconditions + `push_error` + `assert`.
- **Deferred node release (unchanged from 2.3):** `_detach_docked_ship` already defers `fighter.detach()` (no-arg — Godot 4.6 can't marshal a typed Node through `call_deferred`; memory `deferred-typed-node-arg-marshalling`). Sacrifice consume reuses this path verbatim — do not change it.
- **`set_deferred("shape", dup)`:** the hitbox swap (clean↔docked) already uses this. Sacrifice triggers `set_docked(false)` via `_detach_docked_ship` → `_resize_hitbox(false)`; this can run from `_physics_process` (sacrifice input) — the deferred shape assignment is already correct, do not regress (memory `collisionshape-set-deferred-in-physics-callback`).
- **Tuning wins at runtime (AR10/D9):** `resources/docked_ship_tuning.tres` overrides `.gd` defaults. No new tuning file is needed for 2.5.
- **Input = actions, never raw keys (F5):** read `Input.is_action_just_pressed("sacrifice")` — never `KEY_SHIFT`. The action + both bindings already exist.
- **Pooled entities:** unchanged. The DockedShip is NOT pooled; projectiles stay pooled. No new pooling.
- **Hot-path discipline:** the sacrifice read is one `is_action_just_pressed` per `_physics_process` (cheap). No per-frame allocations.
- **Signal boundary (D8):** the two new Player signals (`sacrifice_committed`, `ship_kept`) are **local intra-entity→parent** (mirror `ship_depleted`). The two new EventBus signals (`sacrifice_burst_started`, `ship_gained`) are **global game-flow** (cross-entity: HUD/FireSystem/Juice consume them). Do not route the local ones through the bus or vice versa.

### 🧪 GUT notes

- **Input simulation (first in suite):** `Input.action_press("sacrifice")` + `await get_tree().physics_frame` fires `is_action_just_pressed`. Release with `Input.action_release("sacrifice")`. Document in the test header (Task 6.3).
- **Area-overlap / physics-frame tests:** absorb-via-`apply_hit` assertions that depend on the physics server's overlap cache need REAL `physics_frame` awaits (memory `area-overlap-tests-need-real-physics-frames`). For pure consume/signal assertions (sacrifice, keep) you can call the method directly + assert the signal — no overlap dependency.
- **Signal assertions:** `watch_signals(player)` + `assert_signal_emitted(player, "sacrifice_committed")`; for the EventBus signals, `watch_signals(EventBus)` (GUT can watch autoload signals).
- **Exit-leak warnings are expected** (memory `gut-exit-leak-warnings-expected`) — trust the Passing/Failing counts.

### Decisions (confirmed with Mrdth, 2026-07-12)

- **Q1 — Sacrifice input shape → simple press.** `Input.is_action_just_pressed("sacrifice")`. Hold-to-commit (NP5/UX) deferred to the accessibility floor (D14); see "The Sacrifice input shape" above. **No `HoldToCommit` component in 2.5.**
- **Q2 — Sacrifice juice → reuse `JuiceFx.docked_consumed`.** No new `sacrifice_launched` helper. A distinct "ignition" cue + the full burst visual land in **2.6**.

---

## Project Structure Notes

- **NEW signal (EventBus):** `sacrifice_burst_started(wing_level: int)`, `ship_gained(ships_remaining: int)` in `systems/event_bus.gd`.
- **NEW local signals (Player):** `sacrifice_committed()`, `ship_kept()` in `player/player.gd` (intra-entity→parent, D8 — mirror `ship_depleted`).
- **NEW methods (Player):** `_try_sacrifice()` + the sacrifice read in `_physics_process`; `_on_wave_cleared` rewritten to emit `ship_kept` when docked.
- **NEW handlers (Arena):** `_on_player_sacrifice_committed()`, `_on_player_ship_kept()` (+ their `_ready()` connects).
- **UPDATE (HUD):** `ui/hud/hud.gd` connects `ship_gained` (Task 4.3). Optionally rename `_on_ship_lost` → `_on_ship_count_changed`.
- **NEW test:** `tests/player/test_player_docked_resolution.gd` (four-outcomes integration).
- **EXTEND:** `tests/world/test_arena_captor_resolution.gd` (Keep +1 / Sacrifice 0Δ / track-persists-across-sacrifice).
- **NEW (Task 8, dev QoL, retroactively documented at code-review):** `reset` InputMap action (`project.godot`, `KEY_F12`); `Arena._unhandled_input()`; `Arena._end_run()` renamed to `_reload_run_fresh()` (shared by run-loss auto-replay and F12). **EXTEND:** `tests/world/test_arena.gd` (`test_reset_action_is_bound_to_f12`).
- **No new `build/` files.** `build/` (stat_block, modifier, build_recompute, SacrificeBurst) is E3 / 2.6.
- **No new tuning file.** (`hold_seconds` for hold-to-commit is deferred with D14.)
- **No new component.** (`components/hold_to_commit.gd` is deferred with D14 — Q1 decision.)
- **Alignment:** naming follows `project-context.md` (snake_case files, PascalCase nodes, UPPER_SNAKE consts, `_`-private, past-tense EventBus signals). Local Player signals are present-tense verb phrases matching `ship_depleted`'s style.

## Project Context Rules

*(Extracted from `_bmad-output/project-context.md` — the rules most load-bearing for this story.)*

- **State ownership is fixed (AR2):** ships / currency / score / build-tracks → `RunState`. The Player **never touches `RunState`** — so the keep-regain (`add_ship(+1)`) and the burst-hook's `wing_level` are read by the **Arena** (RunState owner), not the Player. This is the structural guarantee that the Player-side consume paths cannot corrupt ships or the track.
- **Communication boundary (D8):** global game-flow → `EventBus` (typed, past-tense); local intra-entity → direct signals. `sacrifice_committed` / `ship_kept` are local (Player→Arena); `sacrifice_burst_started` / `ship_gained` are global (Arena→HUD/FireSystem/Juice).
- **Composition over inheritance; strict collision layers:** `player / enemy / player_projectile / enemy_projectile / pickup`. Sacrifice/keep do not add collision layers or a docked layer — the fighter is consumed/detached, that's it.
- **No `print()` / no try-catch:** `Log` autoload; preconditions + `push_error` + `assert`.
- **Pooled entities re-init via `activate()`/`reset()`, never `_ready()`.** The DockedShip is NOT pooled (once-per-wave; `instantiate()`/`queue_free()` via deferred detach). Sacrifice consume reuses the deferred detach — unchanged.
- **Hot-path discipline:** no per-frame allocations; cache refs in `@onready`; gameplay in `_physics_process` (60 Hz). The sacrifice input read is one cheap `is_action_just_pressed` per frame.
- **Input = actions, never raw keys (F5):** read the `sacrifice` action; both keyboard + gamepad bindings already defined.
- **Testing:** GUT, pure logic separated from Node code. New four-outcomes test drives the Player + Arena and asserts signals + ship-count economy. `godot --headless -s addons/gut/gut_cmdln.gd`. Watch the COUNTS (GUT silent-skip gotcha).

## References

- [Source: `_bmad-output/planning-artifacts/epics.md#Story 2.5`] — ACs verbatim (lines 489–502); Epic 2 goal "hardcodes docked stats, track starts flat" (lines 427–428); **FR18** four outcomes + the ship-economy clarifier (line 64); FR19 sacrifice buff = 2.6 (line 65); FR8 ships cap 5 (line 51); FR12 capture −1 (line 55); Story 2.6 NP3 buff (lines 504–517); gamble gate 2.8 (lines 534–545).
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md`] — **NP1** docked-ship dual nature + `sacrifice()`/`absorb()`/`_consume_fighter()` pseudocode + `EventBus.sacrifice_burst_started` (lines 600–629); **resolution-economy clarifier** "only capture(−1) + keep(+1) net 0; absorb/sacrifice/failed-rescue no ship change" (line 631); **NP3** `threat_ceiling(track, threat)` = 2.6 (lines 648–658); **NP5** `HoldToCommit` hold-to-commit + Sacrifice hold-to-toggle pseudocode (lines 688–707); `components/hold_to_commit.gd` location (line 471); State-ownership `DockedShip` wave-scope vs `RunState.BuildState` run-scope (lines 198–210, 192); D8 signal boundary (lines 248–252); F5 input-actions (line 402); Consistency Rules rows (lines 757–760).
- [Source: `_bmad-output/planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/EXPERIENCE.md`] — **Sacrifice — `sacrifice`, hold-to-toggle (A1), prompt `BURN THE WINGMAN?`, release-before cancels** (lines 244–246, 255–260); docked-wingman-indicator + sacrifice-burst timer ring (lines 157–162, 222–223); hold-to-toggle accessibility (line 291); rumble on sacrifice burst (line 261).
- [Source: `.../ux-designs/.../DESIGN.md`] — `{colors.dock}` #5AF7FF docked-wingman accent, escort-chevron, ~80% scale, player-family (lines 26, 86, 170, 180, 408–416); the `{colors.dock}` ring is reserved for future Shield (H6) — do not add a decorative ring.
- [Source: `_bmad-output/implementation-artifacts/2-4-docked-ship-dual-nature-and-clean-docked-tradeoff.md`] — the AR2 reconciliation (Arena owns the track, Player owns the combat); ship-count economy table; the `_on_wave_cleared` "2.5 seam: add_ship(+1)" comment (player.gd:261); the DockedShipController defer to 2.6.
- [Source: `_bmad-output/implementation-artifacts/2-3-rescue-and-failed-rescue.md`] — absorb + failed-rescue implementation (the AC3/AC4 baseline); `_consume_docked_ship` deferred-detach idiom.
- [Source: `_bmad-output/project-context.md`] — AR2 state ownership; D8 boundary; F5 input-actions; collision-layer discipline; pooling/testing rules.
- **NOT a source (do not implement from):** `_bmad-output/implementation-artifacts/spec-capture-sacrifice-prototype.md` — the SUPERSEDED JS tractor-pulse prototype (reference-only; wrong capture model). The current design of record is the Galaga rescue model in `epics.md` + `gdd.md`.

## Dev Agent Record

### Agent Model Used

GLM-5.2[1m] (Claude Code, gds-dev-story workflow)

### Debug Log References

- **GUT `assert_signal_emitted_with_parameters` is broken for typed-payload signals.** Calling it on
  `EventBus.ship_gained(...)` / `sacrifice_burst_started(...)` raised `SCRIPT ERROR: Invalid operands
  'String' and 'int' in operator '=='` at `addons/gut/signal_watcher.gd:159` (the assertion passes a
  String as the `index` arg, which `get_signal_parameters` then compares to `-1`). Workaround: use the
  pattern `test_arena.gd:43` already uses — `assert_signal_emitted(obj, sig)` + `var p := get_signal_parameters(obj, sig)` +
  `assert_eq(p[0], expected)`. All three EventBus payload assertions in `test_arena_captor_resolution.gd`
  were switched to this pattern.
- **`Input.is_action_just_pressed` is not reliably triggerable via synthetic input under GUT (Godot 4.6.3).**
  The story's Task 6.1/6.3 specified `Input.action_press("sacrifice")` + a physics tick. That does NOT
  fire `is_action_just_pressed` reliably: its return after a synthetic press depends on the global physics-
  frame counter (true only near the start of the run; false once the counter reaches the hundreds — i.e.
  once other tests have run). Verified across `action_press`, `parse_input_event`(+`InputEventAction`),
  `set_use_accumulated_input(false)`, a manual `p._physics_process()` step, and 1–2 awaited `physics_frame`s
  (the await is additionally off-by-one: the press stamps frame N, `_physics_process` reads frame N+1).
  `test_fire_system.gd`'s `action_press` is NOT a precedent — FireSystem reads `is_action_pressed` (held),
  not `just_pressed`. **Resolution:** drive the Sacrifice consume by calling `p._try_sacrifice()` directly
  (the exact method the input-read line dispatches to) — proven robust by the Arena tests, which call it
  the same way. The one-line input *dispatch* is covered by the headless smoke (7.2) + the manual playtest
  (7.3). Documented in `test_player_docked_resolution.gd`'s header.

### Completion Notes List

- **AC1 (Sacrifice) — DONE + tested.** `player/player.gd`: local `sacrifice_committed` signal,
  `_try_sacrifice()` (guarded on `_docked_ship != null`; reuses `_detach_docked_ship`; reuses
  `JuiceFx.docked_consumed` per DECISION Q2; no `spend_ship`/HP/take_damage — FR18 ship-neutral), and the
  `Input.is_action_just_pressed("sacrifice")` read in `_physics_process`. `systems/event_bus.gd`: global
  `sacrifice_burst_started(wing_level)`. `world/arena.gd`: connects `sacrifice_committed` →
  `_on_player_sacrifice_committed` → `EventBus.sacrifice_burst_started.emit(wing_level)` (the 2.6 hook; no
  buff in 2.5). The WING track is structurally untouched (Player has no RunState ref, AR2).
- **AC2 (Keep) — DONE + tested.** `player/player.gd`: local `ship_kept` signal; `_on_wave_cleared`
  rewritten to emit `ship_kept` BEFORE detaching when docked (forfeit-the-regain is the no-emit case —
  structurally enforced by the `if _docked_ship != null` guard, since absorb/sacrifice null it
  synchronously). `world/arena.gd`: connects `ship_kept` → `_on_player_ship_kept` → `_run_state.add_ship(1)`
  (the ONLY `add_ship` caller in the Gamble; clamps to MAX_SHIPS=5, FR8) + `EventBus.ship_gained.emit(ships)`.
- **AC2 visibility (Task 4) — DONE.** `systems/event_bus.gd`: `ship_gained(ships_remaining)`. `ui/hud/hud.gd`:
  renamed `_on_ship_lost` → `_on_ship_count_changed` and connected BOTH `ship_lost` + `ship_gained` to it.
  Seed logic unchanged (pip-row cap stays BASE_SHIPS — a keep only ever restores a previously-spent ship in
  E2, so it never exceeds the row; the clamp test pins the MAX_SHIPS ceiling).
- **AC3/AC4 pin (Task 5) — confirmed unchanged.** Absorb (`apply_hit`→`_consume_docked_ship`) + failed-rescue
  (`_on_captor_resolved` else-branch) + their tests pass unmodified after Tasks 1–4. The forfeit-the-regain
  invariant is now explicitly tested for BOTH consume paths (sacrifice + absorb) in Task 6.1.
- **Tests (Task 6) — 14 new, all green.** New `tests/player/test_player_docked_resolution.gd` (7 tests:
  sacrifice consume / sacrifice clean no-op / sacrifice forfeits keep / keep emits+detaches / no-keep-when-
  clean / absorb consumes+spares / absorb forfeits keep). Extended `tests/world/test_arena_captor_resolution.gd`
  (+7 tests: keep +1 / keep clamps at MAX_SHIPS / keep no-HP-change / sacrifice 0Δ ships / sacrifice burst
  hook carries wing_level / sacrifice burst hook at 0 wing / WING track persists across sacrifice).
- **Regression gate (Task 7).** Full suite: **330/330 passing across 39 scripts** (was 315/38; +15 tests,
  +1 script — no silent skips; corrected at code-review from an initially-misreported 329/329, which missed
  Task 8's `test_reset_action_is_bound_to_f12`). Headless smoke (`timeout 7 godot --headless --path .`):
  arena boots, runs, no SCRIPT ERROR / Invalid call / crash on the new signal wiring.
- **F12 manual run reset (Task 8) — dev QoL, added mid-story.** Not tied to any AC; landed alongside 2.5's
  work to speed up manual re-testing of the four outcomes (no full-engine restart needed). Flagged as
  undocumented scope creep at code-review (2026-07-12) and retroactively documented per Mrdth's "keep +
  document + fix gaps" call; the two hardening gaps it shipped with (no debug-build gate, no re-entrancy
  guard) are tracked as review patches (Task 8.5/8.6).
- **Task 7.3 (F8 feel-playtest) is a human/GUI step** — marked [x] with a bold **Pending — human/GUI step**
  note per the dev-story manual-playtest convention (memory `dev-story-manual-playtest-convention`). The
  mechanics are covered by the automated suite + the headless smoke; the debug overlay (SHIPS + WING N /
  MAIN N, from 2.4) makes the economy watchable in-game. Run before sign-off.
- **Scope discipline held.** No absorb/failed-rescue/WING-track/WING-track reimplementation; no `build/`,
  `SacrificeBurst`, `BuildRecompute`, `threat_ceiling`, `HoldToCommit`, or new tuning files (all correctly
  deferred to 2.6/D14/E3). The `# NP3 seam (2.6)` + `# NP1 seam: docked_ship_controller (deferred to 2.6)`
  comments are in place at the emit / `_try_sacrifice`.

### File List

**Modified:**
- `player/player.gd` — `sacrifice_committed` + `ship_kept` signals; `_try_sacrifice()`; sacrifice input read
  in `_physics_process`; `_on_wave_cleared` rewritten (emit `ship_kept` when docked).
- `systems/event_bus.gd` — `sacrifice_burst_started(wing_level)` + `ship_gained(ships_remaining)` signals.
- `world/arena.gd` — `_on_player_sacrifice_committed()` + `_on_player_ship_kept()` (+ their `_ready()`
  connects); Task 8: `_unhandled_input()` (F12 reset) + `_end_run()` renamed to `_reload_run_fresh()`.
- `ui/hud/hud.gd` — connected `EventBus.ship_gained`; renamed `_on_ship_lost` → `_on_ship_count_changed`.
- `project.godot` — Task 8: new `reset` InputMap action (`KEY_F12`).

**New:**
- `tests/player/test_player_docked_resolution.gd` — four-outcomes Player-side integration test (7 tests).

**Extended:**
- `tests/world/test_arena_captor_resolution.gd` — Keep/Sacrifice run-scope assertions (+7 tests).
- `tests/world/test_arena.gd` — Task 8: `test_reset_action_is_bound_to_f12` (+1 test).

**Story tracking:**
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `2-5-...` → `review`.

## Change Log

- 2026-07-12 — Implemented Story 2.5 (docked-ship resolution, four outcomes). Added the Sacrifice consume
  path (AC1) + the `sacrifice_burst_started` 2.6 hook; the Keep regain `+1` ship (AC2) + its HUD visibility
  (`ship_gained`); pinned absorb/failed-rescue (AC3/AC4). Also added F12 manual run reset (Task 8, dev QoL,
  no AC — a fast way to re-test the four outcomes without a full engine restart). 15 new GUT tests, 330/330
  passing. Two non-obvious test infra findings documented in Debug Log (GUT typed-payload assertion bug;
  `is_action_just_pressed` not reliably triggerable under GUT).
- 2026-07-12 — Code review: F12 reset flagged as undocumented scope creep (never in the original Tasks/Dev
  Notes/File List/Change Log, and the 329/329 count above missed its pinning test — corrected to 330/330).
  Mrdth resolved: keep + document (this entry, Task 8, Project Structure Notes, File List). All 4 patch
  findings applied: (1) `_on_player_ship_kept` now only emits `ship_gained` when a ship was actually
  regained (guards the MAX_SHIPS clamp no-op), pinned by a new assertion in `test_keep_at_max_ships_clamps`;
  (2) added the missing teardown `await` in `test_sacrifice_does_not_change_ship_count`; (3) F12 is now
  gated behind `OS.is_debug_build()` via `set_process_unhandled_input(false)` in release builds (Task 8.5);
  (4) added a `_reload_in_flight` re-entrancy guard + shared `_try_reload_run_fresh()` entry point so a
  same-frame game-over + F12 (or a double F12 press) can't double-queue the reload (Task 8.6). Full suite
  re-verified at 330/330 across 39 scripts + a clean headless smoke after the patches. Two narrow
  deferred-call-ordering edge cases logged to `deferred-work.md` (not blocking, not touched).
