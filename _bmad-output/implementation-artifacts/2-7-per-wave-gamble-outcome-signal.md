---
baseline_commit: 982d2adf5c27764b7d489a054ebe0a3c258a22fd
---

# Story 2.7: Per-Wave Gamble-Outcome Signal (Safe vs Courted)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->
<!-- This story is the E2 detection half of FR20, repositioned out of the old "Safe-Play vs Rescue
Bonus Economy" story by the 2026-07-13 correct-course (commit 982d2ad). The currency half is
Story 3.4. This is a SMALL, surgical signal story: one pure class + one EventBus signal + one
Arena handler + tests. Do NOT build currency / economy_tuning.tres — that is 3.4. -->

## Story

As a developer,
I want each cleared wave to record whether the player played safe or courted capture/rescue,
So that the Epic 3 economy can apply the correct currency reward without re-deriving gamble state.

## Acceptance Criteria

1. **Given** the player avoids capture for the entire wave (no capture event), **Then** the wave records a **SAFE** gamble-outcome.
2. **Given** a capture event occurs this wave (regardless of later rescue / sacrifice / absorb / failed-rescue resolution), **Then** the wave records a **COURTED** gamble-outcome.
3. **Given** wave clear, **Then** the outcome is emitted via `EventBus` (`gamble_outcome_recorded(outcome: GambleOutcome.Outcome)` — `enum Outcome { SAFE, COURTED }`) for the E3 economy to consume.
4. **Given** the signal, **Then** it carries **no currency logic** — E2 produces the classification only; the currency bonus is computed in Epic 3 (Story 3.4) from `economy_tuning.tres` (which does **not** exist yet — do not create it).
5. **Given** the classification, **Then** it is **pure logic**, GUT-tested (SAFE when no capture occurred; COURTED when a capture occurred).

> *(FR20 detection half · FR20 currency half → Story 3.4)* — repositioned by the [2026-07-13 correct-course](file:///home/mrdth/Development/Gamedev/Godot/meridian-run/_bmad-output/planning-artifacts/sprint-change-proposal-2026-07-13.md).

## Tasks / Subtasks

### Task 1 — Pure logic: `GambleOutcome` classifier  *(AC: #4, #5)*

- [x] Create `run/gamble_outcome.gd` — `class_name GambleOutcome extends RefCounted`, `enum Outcome { SAFE, COURTED }`, `static func classify(capture_occurred: bool) -> Outcome`. Full code in Dev Notes §"🧮 Pure classifier spec".
- [x] Run `godot --headless --import` (new `class_name` — GUT won't see it until imported; memory `gut-classname-reindex-silent-skip`).

### Task 2 — EventBus signal  *(AC: #3)*

- [x] `systems/event_bus.gd`: add `signal gamble_outcome_recorded(outcome: GambleOutcome.Outcome)` in the global game-flow block, slotted next to `sacrifice_burst_started` (line 30) — both are E2→E3 produce-now/consume-later seams. Provenance comment in Dev Notes §"📡 EventBus signal".

### Task 3 — Player public read accessor  *(AC: #1, #2)*

- [x] `player/player.gd`: add `func was_captured_this_wave() -> bool:` returning `_captured_this_wave`. Public read accessor (mirrors `is_docked()`/`is_capture_immune()`); the flag already exists (player.gd:61) — do NOT add a second flag.

### Task 4 — Arena wiring: classify + emit at wave clear  *(AC: #1, #2, #3)*

- [x] `world/arena.gd::_ready`: connect `EventBus.wave_cleared` → a new `_on_wave_cleared` handler (belt-and-braces `is_connected` guard, mirroring the player-signal connects at arena.gd:46-51). **Order the emit reads correctly** — see Dev Notes §"⚠️ The ordering hazard (read the flag BEFORE the reset)".
- [x] `world/arena.gd::_on_wave_cleared(_wave)`: guard the game-over/reload race (`_reload_in_flight or not is_instance_valid(_player)` → return, mirroring `_on_player_sacrifice_committed` at arena.gd:120); read `_player.was_captured_this_wave()`; `var outcome := GambleOutcome.classify(capture_occurred)`; `EventBus.gamble_outcome_recorded.emit(outcome)`.
- [x] **AC4 verify**: do NOT add `economy_tuning.tres`, do NOT compute currency, do NOT touch `RunState` for this. The handler classifies + emits, nothing else.

### Task 5 — (Optional) Debug overlay GAMBLE row  *(playtest aid)*

- [x] `systems/debug.gd`: add `_gamble_label` + `_make_row(vbox, "GAMBLE")` (mirrors the BUILD row at debug.gd:75/152-155); refresh in `_refresh_overlay()` reading `player.was_captured_this_wave()` live → `"GAMBLE: SAFE"` / `"GAMBLE: COURTED"` mid-wave (the live read shows COURTED the moment capture lands — more useful for verifying detection than the post-clear cached value). Debug is READ-ONLY (AR2). Low priority; skip if time-boxed.

### Task 6 — GUT tests  *(AC: #5 + integration #1–#4)*

- [x] Create `tests/run/test_gamble_outcome.gd` (NEW) — pure-logic (no Node, no physics_frame): `classify(false) → Outcome.SAFE`; `classify(true) → Outcome.COURTED`. Mirror `tests/run/test_build_state.gd`'s pure-logic shape.
- [x] Create `tests/world/test_arena_gamble_outcome.gd` (NEW) — integration: instantiate `arena.tscn` + halt the spawner (`arena._spawner.set_active(false)`), `watch_signals(EventBus)`. Cases: (a) no capture → `EventBus.wave_cleared.emit(1)` → assert `gamble_outcome_recorded` emitted with `GambleOutcome.Outcome.SAFE`; (b) drive `arena._player.try_capture()` first (returns true, sets the flag) → `wave_cleared.emit(1)` → assert `COURTED`; (c) **AC2 regression**: capture then dock a rescued ship (`try_capture()` then `try_dock_ship()`) → `wave_cleared.emit(1)` → still `COURTED` ("regardless of later resolution"); (d) reset across waves: `wave_started.emit(2, 60.0)` (resets the flag) → no capture → `wave_cleared.emit(2)` → `SAFE` again. Use the **working** typed-payload assertion (memory `gut-payload-assertion-bug`): `assert_signal_emitted(EventBus, "gamble_outcome_recorded")` + `var p := get_signal_parameters(EventBus, "gamble_outcome_recorded")` + `assert_eq(p[0], GambleOutcome.Outcome.SAFE)` — do NOT use `assert_signal_emitted_with_parameters`.
- [x] Run `godot --headless --import` THEN `godot --headless -s addons/gut/gut_cmdln.gd`. **Check the Scripts/Tests COUNTS** (memory `gut-classname-reindex-silent-skip`). Baseline after 2.6: **355/355 across 41 scripts** — new tests must appear AND total must not regress.

### Task 7 — Regression gate + headless smoke + manual playtest  *(all ACs)*

- [x] Full GUT suite green (355/355 + new tests, no regression). **→ 364/364 across 43 scripts (+8 tests, +2 scripts; no regression).** First run was 359/42 — `test_arena_gamble_outcome.gd` was silently skipped (parse error: `var p := get_signal_parameters(...)` fails GDScript type inference); fixed to the codebase convention `var p: Array = get_signal_parameters(...)` (memory `gut-classname-reindex-silent-skip` — checked the COUNTS, not just "All passed!").
- [x] Headless smoke: `tests/smoke_gamble_outcome.tscn` (Node2D + `_ready`, run via `godot --headless tests/smoke_gamble_outcome.tscn` — memory `headless-smoke-run-as-scene`): instantiate the player, drive `try_capture()`, emit `wave_cleared`, log the emitted outcome (COURTED); then `wave_started` reset + `wave_cleared` with no capture, log SAFE. Confirms the wiring end-to-end without GUT's watcher. **→ `tests/smoke_gamble_outcome.tscn` PASS (exit 0): clean wave 1 → SAFE; capture wave 2 → COURTED; wave_started reset → clean wave 3 → SAFE.**
- [x] Manual playtest (GUI — mark `[x]` + **"Pending — human/GUI step"** per the dev-story convention, memory `dev-story-manual-playtest-convention`): play a wave without being captured → confirm SAFE; play a wave, get captured then rescue → confirm COURTED (debug GAMBLE row, Task 5, helps). Capture feel findings. **Pending — human/GUI step** (cannot run the GUI playtest headlessly; the classification, signal emit, Arena wiring, capture/rescue/reset paths are all covered by GUT 364/364 + the headless smoke PASS. The visual debug-row read + the in-game capture→COURTED confirmation need a human at the controls).

### Review Findings

- [x] [Review][Defer] `Arena._on_wave_cleared`'s game-over/reload guard doesn't fire when `auto_replay_on_loss` is false [world/arena.gd:198] — deferred, pre-existing pattern
- [x] [Review][Defer] `gamble_outcome_recorded` is the first EventBus signal typed against a `class_name` (`GambleOutcome.Outcome`), which fails hard on a fresh checkout without `godot --headless --import` first [systems/event_bus.gd:37] — deferred, pre-existing pattern

## Dev Notes

### 🚨 START HERE — the seam (most of this story already exists)

This is an **emit-now / consume-later seam** story, the same shape as 2.5's `sacrifice_burst_started` (which 2.6 then consumed). The "capture occurred this wave" boolean **already exists** — you are NOT building detection, you are exposing + classifying + broadcasting it.

Verified current state (baseline commit `982d2ad`):

- **The per-wave capture flag ALREADY EXISTS**: `player/player.gd:61` — `var _captured_this_wave := false  # wave-scope capture gate (AC#3, Story 2.2); reset on wave_started.`
  - **Set true on capture**: `player/player.gd:357` (inside `try_capture()`, after the `is_capture_immune() or _captured_this_wave or _health._is_dead` guard at line 355).
  - **Reset false on wave start**: `player/player.gd:365` (inside `_on_wave_started`, subscribed to `EventBus.wave_started` at player.gd:99-100).
  - This flag is the **authoritative** per-wave capture gate — `try_capture` itself reads it to enforce once-per-wave. Reuse it; do NOT create a parallel flag (it would drift).
  - **Semantic match for AC2 is exact**: the flag is set the moment capture lands and stays true for the rest of the wave (only reset on the *next* wave's `wave_started`). So capture→rescue, capture→sacrifice, capture→absorb, capture→failed-rescue ALL leave it true → all classify as COURTED. ✓

- **The captor→player capture call chain** (for context; you do NOT touch it): `enemies/captor/states/capture_state.gd:50` duck-calls `player.call("try_capture")` during the 0.4 s active window → `player.try_capture()` sets the flag + emits LOCAL `ship_depleted` → `arena._on_player_ship_depleted` (arena.gd:91) → `spend_ship` + respawn/game-over. **No EventBus signal fires on capture today** — capture stays local (D8). This story does NOT add a capture signal; it reads the flag at wave-clear instead.

- **The wave-clear emit point**: `world/states/wave_completed_state.gd:20` — `EventBus.wave_cleared.emit(_controller.wave_num)`. The Arena does NOT currently subscribe to `wave_cleared` (the wave lifecycle moved to WaveController in Story 1.8; arena.gd `_ready` connects only the player/spawner LOCAL signals). This story adds the Arena's first `wave_cleared` subscription.

- **What does NOT exist** (this story creates all of these): `run/gamble_outcome.gd`, the `gamble_outcome_recorded` signal, the Arena's `_on_wave_cleared` handler, the Player's `was_captured_this_wave()` accessor, `tests/run/test_gamble_outcome.gd`, `tests/world/test_arena_gamble_outcome.gd`.

**2.7's job in one sentence:** give the existing `_captured_this_wave` flag a public accessor → add a pure `GambleOutcome.classify(bool)` → at wave-clear the Arena reads the accessor, classifies, and emits `EventBus.gamble_outcome_recorded(outcome)` for Story 3.4 to consume.

### 🧮 Pure classifier spec (the headline deliverable — AC4/AC5)

Mirror 2.6's `build/build_recompute.gd` pattern (pure `RefCounted` statics, GUT-tested without scenes). The classification is deliberately trivial — the value is the **named, typed E2→E3 contract**, not clever logic.

```gdscript
# run/gamble_outcome.gd
class_name GambleOutcome
extends RefCounted
# Story 2.7 — the per-wave gamble-outcome classification (FR20 detection half). Pure logic → GUT-tested.
# E2 (this story) PRODUCES the classification at wave-clear; E3 (Story 3.4) CONSUMES it to gate the
# safe-play currency bonus (base + safe_play_bonus_pct iff SAFE). This is the classic emit-now/consume-
# later seam — same shape as sacrifice_burst_started (2.5 emit / 2.6 consume). E2 carries NO currency
# logic (AC4); the outcome is a classification only.
#
# SAFE    = the player avoided capture for the entire wave (no capture event).
# COURTED = a capture event occurred this wave — REGARDLESS of later rescue/sacrifice/absorb/failed-rescue
#           resolution (the docked fighter may have come and gone; the gamble was courted).

enum Outcome { SAFE, COURTED }

# The classification. Trivial by design: SAFE iff no capture occurred this wave.
# `capture_occurred` is sourced from Player.was_captured_this_wave() (the existing per-wave gate).
static func classify(capture_occurred: bool) -> Outcome:
    return Outcome.COURTED if capture_occurred else Outcome.SAFE
```

**Enum-typed signal param — decision (primary + fallback):**
- **Primary:** declare the signal typed as the enum: `signal gamble_outcome_recorded(outcome: GambleOutcome.Outcome)`. Godot 4.6 supports enum-typed signal params from a `class_name`'d script (the class is registered after `godot --headless --import`, before EventBus parses). This is type-safe and matches the AC's intent.
- **Fallback (only if Godot rejects the enum-typed param on an autoload signal at parse/import):** downgrade to `signal gamble_outcome_recorded(outcome: int)` and pass `GambleOutcome.Outcome.SAFE` / `.COURTED` (stable int values SAFE=0, COURTED=1). This mirrors the codebase precedent (`sacrifice_burst_started(wing_level: int)` is an `int`). Try the typed form first; only fall back if import errors.
- Either way, the **GUT assertion** is the same working pattern (memory `gut-payload-assertion-bug`): `assert_signal_emitted` + `get_signal_parameters` + `assert_eq(p[0], GambleOutcome.Outcome.SAFE)`. Do NOT use `assert_signal_emitted_with_parameters` (broken for typed payloads).

### 📡 EventBus signal

Slot it next to `sacrifice_burst_started` (event_bus.gd:30) — both are E2→E3 produce-now/consume-later game-flow signals. Provenance comment (match the file's existing multi-line comment style):

```gdscript
# Story 2.7 (FR20 detection half) — the per-wave gamble-outcome classification. Global game-flow (D8):
# the Arena emits it at wave-clear carrying SAFE (no capture this wave) or COURTED (a capture occurred,
# regardless of later resolution). E2 PRODUCES the classification only (AC4 — NO currency logic); E3
# (Story 3.4) CONSUMES it to gate the safe-play currency bonus (base + safe_play_bonus_pct iff SAFE).
# Same emit-now/consume-later shape as sacrifice_burst_started (2.5 emit / 2.6 consume).
signal gamble_outcome_recorded(outcome: GambleOutcome.Outcome)
```

### 🔌 Arena wiring (mirror `_on_player_sacrifice_committed`)

The Arena is the established **run-scope signal enricher** (arena.gd:102-140 enriches `sacrifice_burst_started` with `wing_level`; arena.gd:177 resolves captor deaths). Adding a `wave_cleared` handler that reads player state + emits a global signal is the same pattern.

In `_ready` (after the existing player-signal connects, ~arena.gd:51):
```gdscript
# Story 2.7 — EventBus.wave_cleared (global, D8) → run-scope gamble-outcome classification. The Arena
# reads the player's per-wave capture flag, classifies it, and emits gamble_outcome_recorded for E3 to
# consume. The Arena is NOT pooled → connect ONCE (belt-and-braces is_connected guard, mirroring the
# player-signal connects above).
if not EventBus.wave_cleared.is_connected(_on_wave_cleared):
    EventBus.wave_cleared.connect(_on_wave_cleared)
```

The handler (place near `_on_player_sacrifice_committed`):
```gdscript
func _on_wave_cleared(_wave: int) -> void:
    # Story 2.7 (FR20 detection half) — classify the wave's gamble outcome and broadcast it. The Arena
    # (RunState owner) is the single point that enriches wave-clear with the per-wave capture classification
    # (AR2 — the Player never touches RunState; the Arena reads the Player's capture flag via its public
    # accessor). AC4: this carries NO currency logic — Story 3.4 consumes the outcome to compute the bonus.
    # Game-over race guard mirrors _on_player_sacrifice_committed: a failed wave (last ship spent mid-wave)
    # routes to WaveFailedState, NOT WaveCompletedState, so wave_cleared structurally implies a successful
    # wave — but guard anyway for robustness against teardown.
    if _reload_in_flight or not is_instance_valid(_player):
        return
    var outcome: GambleOutcome.Outcome = GambleOutcome.classify(_player.was_captured_this_wave())
    EventBus.gamble_outcome_recorded.emit(outcome)
```

### ⚠️ The ordering hazard (read the flag BEFORE the reset) — load-bearing

`wave_completed_state.gd:20-22` does, in order:
```gdscript
EventBus.wave_cleared.emit(_controller.wave_num)   # line 20 — ALL subscribers run synchronously HERE
_controller.wave_num += 1                          # line 21
_controller.to_intro()                             # line 22 → WaveIntroState → wave_started.emit() →
                                                   #        Player._on_wave_started → _captured_this_wave = false
```

Godot signal emission is **synchronous**: every `wave_cleared` subscriber (the Arena's new handler AND the Player's existing `_on_wave_cleared` at player.gd:368) runs to completion during line 20, **before** `to_intro()` (line 22) fires `wave_started` and resets the flag. So reading `_player.was_captured_this_wave()` inside the Arena's `_on_wave_cleared` is **safe** — the reset has not happened yet.

**Do NOT** defer the read (no `call_deferred` on the classify/emit) — a deferred read would land AFTER `wave_started` reset the flag, classifying every wave as SAFE. The classify + emit stay synchronous inside the handler.

(The Player's own `_on_wave_cleared` runs in the same synchronous window — it does the Keep outcome + detach + clear-burst. Order between the Arena's handler and the Player's handler is not guaranteed, but they are independent: the Arena reads the capture flag, the Player reads `_docked_ship`. Neither mutates the other's input. Safe.)

### 🚫 What this story does NOT do (scope fence — hard)

- **NO currency logic, NO `economy_tuning.tres`, NO `safe_play_bonus_pct`.** AC4. Currency is Story 3.4 (E3). `RunState` stays `ships` + `score` + `build_state` only.
- **NO new per-wave flag.** Reuse `Player._captured_this_wave` (player.gd:61). A second flag would drift from the real capture gate.
- **NO capture signal on EventBus.** Capture stays local (D8). The outcome is read from the flag at wave-clear, not pushed on capture.
- **NO HUD change.** The gamble-gate *legibility* (showing the player which outcome they're heading for) is Story 2.8. The optional Debug GAMBLE row (Task 5) is a dev/playtest aid, not a gameplay HUD.
- **NO `RunState` field for the outcome.** The outcome is a transient signal, not persisted state. The Arena may cache `_last_gamble_outcome` locally ONLY if Task 5's debug row wants the post-clear value (the recommended live read off `player.was_captured_this_wave()` needs no cache). RunState stays pure data (run_state.gd:16-17).

### 🔗 Signal boundary (do not over-route)

- **`gamble_outcome_recorded` IS a global game-flow signal** (D8): the producer (Arena, run-scope) and the future consumer (E3 economy, different subtree) are not parent-child → EventBus is correct. It sits alongside `wave_cleared`/`sacrifice_burst_started`.
- **The capture flag STAYS local** on the Player (`_captured_this_wave`). The Arena reads it via the public accessor — it does not promote capture to an EventBus signal.
- **The Player's existing local signals** (`ship_depleted`, `sacrifice_committed`, `ship_kept`) are unchanged. The only Player change is the new read-only accessor.

### 🅰️ AR2 — who owns what (do not violate)

- **Player** owns the per-wave capture flag (`_captured_this_wave`) + the public accessor. Player has **NO `RunState` reference** (AR2) — unchanged.
- **Arena** owns run-scope enrichment: it subscribes to `wave_cleared`, reads the Player's capture flag, classifies, and emits the global outcome. Matches 2.5/2.6's "Arena is the single point that enriches global signals" pattern.
- **GambleOutcome** is pure (RefCounted, static) — no Node, no signals, no EventBus. GUT-tested without instantiating scenes. Sibling to `RunState`/`BuildState` in `run/`.
- **RunState / BuildState** are unchanged (pure data; no new fields).

### ⚙️ Engine / project-context rules that apply

- **Tuning wins at runtime (AR10/D9):** N/A — no tuning in this story (AC4: no currency). No `.tres` created.
- **No `print()` / no try-catch:** route logging through `Log` (only if you add a warn, e.g. for the game-over guard — likely none needed). `push_error`/`assert` for dev invariants.
- **Static typing everywhere:** `var outcome: GambleOutcome.Outcome`, `func was_captured_this_wave() -> bool`, `static func classify(capture_occurred: bool) -> Outcome`. `RefCounted` for the pure class.
- **`@onready` / cache refs:** the Arena already caches `_player` (arena.gd:23). No new refs.
- **Signals:** typed, past-tense, callable syntax (`EventBus.wave_cleared.connect(_on_wave_cleared)`). The new `gamble_outcome_recorded` is past-tense (D8 convention).
- **Communication boundary (D8):** global game-flow → EventBus; local → direct. The outcome is global (Arena→E3); the capture flag is local (Player). Correct as specified.
- **Do not port the prototype:** re-derive in Godot idioms. N/A here (no prototype pattern in play).

### 🧪 GUT notes (critical — read before testing)

- **NEW `class_name` (`GambleOutcome`) → run `godot --headless --import` BEFORE GUT.** GUT silently skips unindexed scripts (memory `gut-classname-reindex-silent-skip`). **Check the Scripts/Tests COUNTS** — baseline after 2.6: **355/355 across 41 scripts**; your new tests must appear AND the total must not regress.
- **`before_each(): Pool.clear()`** — start each test from a known-empty pool.
- **Arena integration tests** instantiate `arena.tscn` + `arena._spawner.set_active(false)` (halt the drip). Drive the outcome by emitting `EventBus.wave_cleared.emit(wave_num)` directly (the Arena's handler is subscribed to the real signal) — same drive-by-signal pattern as `tests/world/test_arena_captor_resolution.gd` (which drives `arena._spawner.captor_resolved.emit(...)`).
- **`watch_signals(EventBus)`** + the **working** typed-payload assertion (memory `gut-payload-assertion-bug`): `assert_signal_emitted(EventBus, "gamble_outcome_recorded")` + `var p := get_signal_parameters(EventBus, "gamble_outcome_recorded")` + `assert_eq(p[0], GambleOutcome.Outcome.SAFE)`. Do NOT use `assert_signal_emitted_with_parameters` (broken for typed payloads).
- **Driving capture in tests:** call `arena._player.try_capture()` directly (returns `true` when it captures — sets the flag; returns `false` if immune/already-captured/dead). To test AC2's "regardless of resolution", follow it with `arena._player.try_dock_ship()` (rescue) — the flag stays true. Note `try_capture()` also emits `ship_depleted` → `arena._on_player_ship_depleted` → `spend_ship` + respawn; that is fine in-test (the Arena is live), but if the player starts at 1 ship it would game-over — start the player at ≥2 ships or assert before the respawn path. Simplest: set the flag directly via the accessor's underlying field is NOT possible (private); use `try_capture()` and accept the ship-spend side effect, OR add a tiny test-only seam only if needed (prefer not).
- **Pure-logic test** (`test_gamble_outcome.gd`) needs NO physics stepping, NO Node — just `assert_eq(GambleOutcome.classify(false), GambleOutcome.Outcome.SAFE)` etc.
- **Exit-leak warnings are expected** (memory `gut-exit-leak-warnings-expected`) — trust Passing/Failing counts.

### ⚠️ Edge cases

- **Failed wave (last ship spent mid-wave):** routes to `WaveFailedState` (WaveController hears `EventBus.game_over`), NOT `WaveCompletedState` → `wave_cleared` does NOT fire → `gamble_outcome_recorded` does NOT fire. Correct: a failed wave has no clear-reward. The Arena's `_reload_in_flight`/`is_instance_valid` guard is belt-and-braces.
- **Double wave-clear:** impossible by construction (deferred-work: `WaveController`'s FSM can't re-enter Completed except via Active, and the `test_no_double_fire_on_huge_delta` regression covers it). No new guard needed.
- **Capture the same frame wave-clear fires:** capture is once-per-wave and the capture window is mid-Active; wave-clear fires at Active-timer-expiry. A capture landing on the exact clear tick still sets the flag synchronously before the `wave_cleared` emit is processed by subscribers → COURTED. Correct.
- **Game-over/reload race:** the `_reload_in_flight or not is_instance_valid(_player)` guard mirrors `_on_player_sacrifice_committed` (arena.gd:120). Structurally unreachable (wave_cleared ⟹ successful wave), but consistent + defensive.
- **First wave (no prior capture):** `_captured_this_wave` defaults false → first clear classifies SAFE. Correct.

### 🧠 Previous story intelligence (learnings from 2.5 / 2.6)

- **Emit-now/consume-later seam pattern:** 2.5 emitted `sacrifice_burst_started(wing_level)` with NO subscriber; 2.6 added the subscriber. 2.7 emits `gamble_outcome_recorded(outcome)` with NO subscriber; Story 3.4 will subscribe. "No subscriber" is correct and intentional — do NOT stub a consumer.
- **Arena = run-scope enricher:** 2.5/2.6 established that the Arena (RunState owner) is the single point that enriches global signals with run/player data (AR2 — Player has no RunState ref). 2.7 follows: Arena reads Player's capture flag + emits the global outcome.
- **Ship-count economy is load-bearing — do NOT "fix":** only capture(−1)+keep(+1) change ships; rescue/sacrifice/absorb/failed-rescue are all 0 (memory `gamble-ship-count-economy`). 2.7 does not change ship counts at all — it only reads + classifies.
- **Reuse, don't reinvent:** the `_captured_this_wave` flag (2.2), the wave lifecycle (1.8), the Arena enricher pattern (2.5/2.6), the pure-RefCounted-statics pattern (`BuildRecompute`, 2.6) all exist. This story wires them together — it does not rebuild any of them.
- **Tuning `.tres` is the source of truth — but NOT here:** 2.7 has no tuning (AC4). Do not create `economy_tuning.tres` (that is 3.4's, with `safe_play_bonus_pct`).
- **Safe-play currency model (memory `safe-play-currency-model`):** FR20/FR27 redesigned 2026-07-13 — safe play = only currency bonus; rescue pays via the build track (biased wing-track odds), NOT currency. 2.7 is the detection half; 3.4 is the currency grant.

## Project Structure Notes

**Files to CREATE (all new):**
- `run/gamble_outcome.gd` — pure classifier (`class_name GambleOutcome`, `enum Outcome`, `static classify`). Sibling to `run/run_state.gd` / `run/build_state.gd`.
- `tests/run/test_gamble_outcome.gd` — pure-logic GUT test (mirrors `tests/run/test_build_state.gd`).
- `tests/world/test_arena_gamble_outcome.gd` — integration GUT test (mirrors `tests/world/test_arena_captor_resolution.gd`'s arena.tscn + halted-spawner + drive-by-signal pattern).
- `tests/smoke_gamble_outcome.gd` + `tests/smoke_gamble_outcome.tscn` — headless smoke (Task 7).

**Files to MODIFY:**
- `systems/event_bus.gd` — add `signal gamble_outcome_recorded(outcome: GambleOutcome.Outcome)` near line 30.
- `player/player.gd` — add `func was_captured_this_wave() -> bool` public accessor (near `is_capture_immune()`/`is_docked()`, ~player.gd:153-168).
- `world/arena.gd` — connect `EventBus.wave_cleared` in `_ready`; add `_on_wave_cleared(_wave)` handler (classify + emit + game-over race guard).
- (Optional) `systems/debug.gd` — GAMBLE overlay row (Task 5).

**Alignment with unified structure:** all new files land in their owning domain (`run/` for the pure classifier, `tests/run/` + `tests/world/` mirroring domains). No conflicts with the architecture's intended layout. No `resources/` changes (no tuning — AC4).

## Project Context Rules

(Extracted from `_bmad-output/project-context.md` — follow exactly.)

- **Engine:** Godot 4.6, GDScript, 2D, Compatibility renderer, 2D physics server. Pin to 4.6.x (avoid 4.7-only APIs).
- **Autoloads:** thin global services only; `EventBus` for global game-flow, local signals for intra-entity. The outcome is global (Arena→E3); the capture flag is local (Player).
- **State ownership is fixed:** ships/score/build-tracks → `RunState`; the WING track → `RunState.BuildState` (permanent). 2.7 adds NO state to RunState — the outcome is a transient signal.
- **Communication boundary:** global game-flow → `EventBus` (typed, past-tense signals); local entity comms → direct signals; testable deps → explicit injection. `gamble_outcome_recorded` is global past-tense; the capture flag is read via a public accessor.
- **No `print()` / no try-catch:** use `Log`; preconditions + `push_error`/`push_warning` + fail-safe defaults.
- **Composition over inheritance; strict collision layers:** N/A — no new components, no collision changes.
- **Typing:** static typing everywhere (`: int`, `-> void`, `-> GambleOutcome.Outcome`, typed `GambleOutcome`).
- **Testing:** GUT, pure logic separable from Node code (`GambleOutcome` is pure → unit-testable without scenes). Tests under `tests/` mirroring domains (`tests/run/`, `tests/world/`), named `test_<thing>.gd`.

## References

- [Source: epics.md#Story 2.7 (lines 519-533)] — ACs (FR20 detection half).
- [Source: epics.md#FR20 (line 66), FR27 (line 76), FR→epic map (line 195), Epic 3 FR coverage (line 247)] — requirements + the E2/E3 split.
- [Source: epics.md#Story 3.4 (line 615)] — the consumer contract (base + `safe_play_bonus_pct` iff SAFE).
- [Source: sprint-change-proposal-2026-07-13.md (Section 4 C5)] — the repositioning that created this story (commit 982d2ad).
- [Source: gdd.md#No-gamble baseline (line 137), Economy (lines 286-287), Pillar P2 (lines 71-72)] — safe-play currency bonus model.
- [Source: architecture.md#Communication Pattern (lines 709-719), EventBus signals (line 250), NP1 (lines 600-631)] — D8 boundary + docked-ship economy.
- Code: `player/player.gd:61,355,357,365` (the capture flag), `world/states/wave_completed_state.gd:20-22` (the ordering hazard), `world/arena.gd:102-140` (the enricher template), `systems/event_bus.gd:30` (the slot for the new signal).

## Dev Agent Record

### Agent Model Used

GLM-5.2[1m] (Claude Code)

### Debug Log References

- `godot --headless --import` (after Task 1) — `GambleOutcome` registered cleanly (`update_scripts_classes | GambleOutcome`); the typed signal param `outcome: GambleOutcome.Outcome` on the EventBus autoload parsed fine (no parse error — the primary typed-enum approach works; the documented `int` fallback was NOT needed). Exit 0.
- `godot --headless -s addons/gut/gut_cmdln.gd` → **364/364 passing, 43 scripts, 1012 asserts**. First run was **359/42** — `test_arena_gamble_outcome.gd` was **silently skipped** (parse error: `var p := get_signal_parameters(...)` fails GDScript type inference — "Cannot infer the type of 'p'"); fixed to the codebase convention `var p: Array = get_signal_parameters(...)` (matches every other `get_signal_parameters` call site in the suite). Re-ran green. Memory `gut-classname-reindex-silent-skip` — caught by checking the Scripts/Tests COUNTS, not "All tests passed!".
- `godot --headless tests/smoke_gamble_outcome.tscn` → **PASS (exit 0)**: clean wave 1 → SAFE; capture wave 2 → COURTED; `wave_started` reset → clean wave 3 → SAFE.
- Exit-leak warnings (3 ObjectDB + 1 resource) + 1 orphan (`test_formation_spawner`) are pre-existing/expected (memory `gut-exit-leak-warnings-expected`).

### Completion Notes List

**What landed (FR20 detection half — emit-now/consume-later seam, end-to-end):**

1. **Pure classifier (AC4/AC5):** `run/gamble_outcome.gd` — `class_name GambleOutcome extends RefCounted`, `enum Outcome { SAFE, COURTED }`, `static func classify(capture_occurred: bool) -> Outcome`. Pure RefCounted statics, no Node/EventBus — GUT-tested without scenes. Sibling to `BuildRecompute` (2.6) / `RunState` / `BuildState` in `run/`. E3 (Story 3.4) will consume `GambleOutcome.Outcome` to gate the safe-play currency bonus.
2. **EventBus signal (AC3):** `systems/event_bus.gd` — `signal gamble_outcome_recorded(outcome: GambleOutcome.Outcome)`, slotted next to `sacrifice_burst_started` (the other E2→E3 seam). Typed enum param parsed cleanly on the autoload. 2.7 has NO subscriber (correct — Story 3.4 subscribes; "no subscriber" is the emit-now half).
3. **Player accessor (AC1/AC2):** `player/player.gd` — `func was_captured_this_wave() -> bool` (public read over the existing private `_captured_this_wave`, player.gd:61). **NO new flag** — reuses the authoritative Story-2.2 capture gate (set on capture, held until the next `wave_started`). Mirrors `is_docked()`/`is_capture_immune()`.
4. **Arena wiring (AC1/AC2/AC3):** `world/arena.gd` — subscribes `EventBus.wave_cleared → _on_wave_cleared` in `_ready`; the handler guards the game-over/reload race (`_reload_in_flight`/`is_instance_valid`), reads `_player.was_captured_this_wave()`, classifies via `GambleOutcome.classify`, and emits `gamble_outcome_recorded`. **AC4: NO currency logic.** The synchronous read sidesteps the ordering hazard (wave_cleared subscribers run BEFORE `wave_started` resets the flag) — documented load-bearing in the handler comment.
5. **Debug overlay (playtest aid, Task 5):** `systems/debug.gd` — GAMBLE row reading `player.was_captured_this_wave()` live (flips to COURTED the moment capture lands, before wave-clear emits).

**Acceptance-criteria mapping:** AC1 (SAFE when no capture) → classifier + Arena + `test_wave_clear_with_no_capture_emits_safe`; AC2 (COURTED when capture, regardless of resolution) → accessor + Arena + `test_wave_clear_after_capture_emits_courted` + `test_capture_then_rescue_still_emits_courted`; AC3 (emitted via EventBus at wave clear) → signal + Arena emit + `test_signal_not_emitted_before_first_wave_clear`; AC4 (no currency logic) → the pure classifier carries no currency (negative-existence note in `test_gamble_outcome.gd`); AC5 (pure logic, GUT-tested) → `test_gamble_outcome.gd` (3 tests) + `test_arena_gamble_outcome.gd` (5 tests).

**Key implementation note — the silent-skip catch:** the first GUT run reported "All tests passed!" at 359/42, but the expected count was 363/43. `test_arena_gamble_outcome.gd` had been **silently skipped** on a parse error (`var p := get_signal_parameters(...)` — GDScript can't infer the return type). Fixed to `var p: Array = get_signal_parameters(...)` (the convention at every other call site). Re-ran 364/364. Exactly the `gut-classname-reindex-silent-skip` failure mode — checking the COUNTS caught it where "All tests passed!" lied.

**Pending — human/GUI step:** the manual playtest (Task 7.3) — the visual debug-row read + the in-game capture→COURTED confirmation need a human at the controls. The classification, signal emit, Arena wiring, and capture/rescue/reset paths are all verified headlessly (GUT 364/364 + smoke PASS).

### File List

**Created (5):**
- `run/gamble_outcome.gd` — pure classifier (`class_name GambleOutcome`, `enum Outcome`, `static classify`).
- `tests/run/test_gamble_outcome.gd` — pure-logic GUT test (3 tests).
- `tests/world/test_arena_gamble_outcome.gd` — integration GUT test (5 tests: SAFE / COURTED / capture+rescue / reset-across-waves / signal-shape).
- `tests/smoke_gamble_outcome.gd` — headless smoke (Task 7).
- `tests/smoke_gamble_outcome.tscn` — the smoke scene.

**Modified (4):**
- `systems/event_bus.gd` — `signal gamble_outcome_recorded(outcome: GambleOutcome.Outcome)`.
- `player/player.gd` — `func was_captured_this_wave() -> bool` public accessor.
- `world/arena.gd` — `EventBus.wave_cleared` connect in `_ready` + `_on_wave_cleared(_wave)` handler (classify + emit + game-over race guard).
- `systems/debug.gd` — GAMBLE overlay row (field + `_make_row` + `_refresh_overlay` live read).

## Change Log

- 2026-07-13 — Implemented Story 2.7 (Per-Wave Gamble-Outcome Signal — FR20 detection half). Pure `GambleOutcome` classifier + `EventBus.gamble_outcome_recorded(outcome)` signal + `Player.was_captured_this_wave()` accessor + Arena wave-clear handler (classify + emit). Reuses the existing Story-2.2 `_captured_this_wave` flag (no new detection). 8 new GUT tests (364/364 green, no regression) + a headless smoke (PASS). E3 Story 3.4 will consume the signal for the safe-play currency bonus. Manual GUI playtest pending.
