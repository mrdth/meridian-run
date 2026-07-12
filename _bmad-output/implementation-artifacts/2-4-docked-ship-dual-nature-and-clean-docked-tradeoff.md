# Story 2.4: Docked Ship — Dual Nature (NP1) & Clean/Docked Tradeoff

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want the docked ship to be a real dual-fighter with a cost (bigger hitbox) and a permanent identity,
so that docking is a meaningful, lasting build choice — not a throwaway buff.

## Acceptance Criteria

*(Verbatim from `epics.md` lines 481–487. Tagged FR7 docked-stream, FR16, FR17.)*

1. **AC1 — Dual-fighter attach.** Given a docked ship attaches, Then the player gains a parallel bullet stream (**+28 px x-offset, hardcoded**) and a **bigger hitbox** ([Risk-12]), and becomes **capture-immune**.
2. **AC2 — Permanent track (the headline of this story).** Given the rescued-ship track, Then it persists in `RunState.BuildState` (**permanent**) even when the docked fighter is consumed — **the consume path never clears the track**.
3. **AC3 — Transient fighter + absorber.** Given the docked fighter, Then it's the **transient combat presence (wave scope)** + **intrinsic first-hit absorber**.

> **Read this before estimating scope:** AC1 and AC3 are **already implemented + tested in Story 2.3** (rescue). This story's only *new mechanic* is **AC2 — the permanent `RunState.BuildState` track**. AC1/AC3 work is limited to *formalizing/pinning* what 2.3 shipped (a desync-guard test + doc framing). **Do NOT reimplement the docked-ship combat presence** — see "What is ALREADY DONE (do not redo)" below.

---

## Tasks / Subtasks

### Task 1 — Create `BuildState` (the permanent dual-ladder state)  *(AC: #2)*

- [ ] **1.1** Create `run/build_state.gd` — `class_name BuildState extends Resource` (pure data, no Node, no EventBus calls — unit-testable; mirrors `RunState`).
  - Holds the two build ladders: `main_track` (primary-weapon ladder) and `wing_track` (allied/rescue ladder — the docked fighter's permanent track). **Both start flat in E2** (Epic-2 hardcodes stats; investment wiring is Story 3.3).
  - **Minimal E2 shape (recommended):** two `int` investment counters, e.g. `var wing_level: int = 0` and `var main_level: int = 0`. (A richer `BuildTrack` Resource is fine if preferred, but E2 only needs "exists, grows on rescue, survives consume." Do NOT build the D2 modifier/recompute pipeline — that is E3.)
  - `func record_rescue() -> void` — earns the WING track (e.g. `wing_level += 1`). Called by Arena on a successful rescue dock.
  - `func reset() -> void` — restores both tracks to flat. Called by `RunState.begin_run()` / `reset()` for a **fresh run** (the ONLY legitimate clearer).
  - **CRITICAL — there must be NO `clear_wing()` / consume-side mutator.** The only writer that *decrements/resets* is `reset()` (new-run path). The permanence invariant (NP1) is enforced structurally: consume paths simply have no API to touch the track.
- [ ] **1.2** Add `class_name BuildState` to the script and run `godot --headless --import` once so GUT's class index sees it (per the GUT class_name reindex gotcha — see Dev Notes).

### Task 2 — Wire `RunState.build_state`  *(AC: #2)*

- [ ] **2.1** In `run/run_state.gd`, add `var build_state: BuildState`.
- [ ] **2.2** Construct it in `_init()` (`build_state = BuildState.new()`) so it is never null, AND reset it inside `begin_run()` (`build_state.reset()`) so a new run starts flat. (`reset()` already aliases `begin_run()` — covered for free.)
- [ ] **2.3** Update the `RunState` header comment: note that `build_state` is the dual-ladder spine (MAIN + WING), run-scope, permanent across consume, reset only on a new run.

### Task 3 — Record the WING track on rescue (Arena owns RunState)  *(AC: #2)*

- [ ] **3.1** In `world/arena.gd` `_on_captor_resolved()`, **rescue branch**: after `_player.try_dock_ship()` succeeds, call `_run_state.build_state.record_rescue()`. (Place it inside the `if _player.try_dock_ship():` block so a blocked/no-op dock does not earn a track — mirrors the existing rescue-juice gate.)
- [ ] **3.2** Optionally emit `EventBus.build_changed.emit()` after `record_rescue()` (the signal exists, has no emitter yet; the WING track changing is a build change). Keep it inside the successful-dock block. *(Low cost, forward-compat for the between-wave build-summary rail.)*
- [ ] **3.3** Do NOT add any `build_state` write to the player. **The Player never touches `RunState` (AR2).** This is the structural guarantee that consume paths cannot clear the track — see Dev Notes §"AR2 reconciliation".

### Task 4 — The permanence invariant GUT test  *(AC: #2 — architecture-mandated)*

> Architecture line 757 Consistency Rules: *"Docked ship (NP1) | consume never clears track | invariant + GUT test."* This test is **required**, not optional.

- [ ] **4.1** New `tests/run/test_build_state.gd` — pure-logic unit test (no scene; `BuildState` is a Resource):
  - `record_rescue()` grows `wing_level` (e.g. 0 → 1 → 2).
  - `reset()` restores flat (new-run path).
  - `main_level` starts 0 and is untouched by `record_rescue()`.
  - *(Negative existence check: confirm there is no public consume/clear API — documented as a comment, since you cannot assert absence of a method at runtime.)*
- [ ] **4.2** Extend `tests/run/test_run_state.gd`:
  - `build_state` is non-null after `begin_run()`.
  - `begin_run()` / `reset()` resets `build_state` (a run that earned a WING track, then `begin_run()` again, is flat).
- [ ] **4.3** Extend `tests/world/test_arena_captor_resolution.gd` — **the headline permanence test**:
  - Rescue (`captor_resolved.emit(true, …)`) grows `arena._run_state.build_state.wing_level` by 1.
  - **Absorb path does not clear the track**: dock via rescue → drive an absorber (`player.apply_hit(...)` while docked, which consumes the fighter) → assert `wing_level` is UNCHANGED.
  - **Wave-clear path does not clear the track**: dock via rescue → emit `EventBus.wave_cleared(wave)` (which detaches the fighter via `player._on_wave_cleared`) → assert `wing_level` is UNCHANGED.
  - *(If `wing_level` is the chosen field name; swap to the actual accessor.)*

### Task 5 — Pin the +28 px offset + formalize [Risk-12]  *(AC: #1 — light, mostly already done)*

- [ ] **5.1** Pin the +28 px: it is already single-sourced in `DockedShipTuning` (`stream_offset_x == dock_offset_x == 28.0`). Add a **desync-guard test** (in `tests/player/test_fire_system_docked.gd` or `test_player_dock.gd`) asserting `docked_ship_tuning.stream_offset_x == docked_ship_tuning.dock_offset_x` so the bullet origin and the wingman visual station can never drift apart via retuning. Do NOT split them into two unrelated constants.
- [ ] **5.2** [Risk-12] is already implemented + tested: `test_dock_grows_player_hitbox` asserts BOTH the body `CollisionShape2D` (projectiles) AND the `HurtboxComponent` shape (contact) swap clean(11)↔docked(18). No new mechanic needed. Refresh the code comments on `Player._resize_hitbox` / `set_docked` to explicitly cite **[Risk-12]** (self-balancing cost) and retire the old `# 2.4 seam` / `# 2.4 deepens` comments now that the work is done.
- [ ] **5.3** Refresh `player/docked_ship.gd` / `docked_ship_tuning.gd` header comments: replace "2.4 formalizes…"前瞻 wording with the realized design (transient wave-scope fighter node; permanent identity lives on `RunState.BuildState.wing_track`, not on this node).

### Task 6 — Regression gate  *(all ACs)*

- [ ] **6.1** Run `godot --headless -s addons/gut/gut_cmdln.gd`. All prior tests still pass (2.3's dock/absorb/capture/fire-stream suites are the regression surface — do not alter their behavior). Check the Scripts/Tests **counts** (not just "All passed") per the GUT silent-skip gotcha.
- [ ] **6.2** F8-spawn a captor in-game (the debug cheat), get captured (clean), dive-kill it → rescue docks → confirm the parallel stream fires, the hitbox visibly grows, and a second capture is impossible. Then take a hit (absorb) → fighter gone, HP spared, and (via debug readout or a temporary log) the WING track is still present.

---

## Dev Notes

### 🚨 START HERE — what is ALREADY DONE (do not redo)

Story 2.3 shipped the **entire combat side** of the docked ship, fully tested. AC1 and AC3 are satisfied by existing code. **Reimplementing any of this is the #1 scope-creep risk.**

| Concern | Where it lives (DONE) | Test |
|---|---|---|
| Parallel bullet stream (+28 px, 10 dmg, matches cadence, pooled) | `player/fire_system.gd::_spawn` — spawns a 2nd `Projectile` at `_muzzle.x + stream_offset_x` when `_player.is_docked()` | `tests/player/test_fire_system_docked.gd` |
| Bigger hitbox ([Risk-12]) — BOTH shapes | `player/player.gd::set_docked` → `_resize_hitbox` → `_swap_circle_radius` (body `CollisionShape2D` + `HurtboxComponent` shape; clean 11 ↔ docked 18; `set_deferred("shape", dup)`) | `tests/player/test_player_dock.gd::test_dock_grows_player_hitbox` |
| Capture-immunity (FR16) | `player/player.gd::is_capture_immune()` returns `_docked`; gated in `try_capture()` | `tests/player/test_player_dock.gd`, `tests/enemies/test_captor_capture.gd` |
| Intrinsic first-hit absorber (FR17) | `player/player.gd::apply_hit` (i-frames → absorber → HP); `_consume_docked_ship` / `_detach_docked_ship` (deferred free) | `tests/player/test_player_dock.gd`, `tests/components/test_hurtbox_absorber.gd` |
| Transient wave-scope fighter node (NP1) | `player/docked_ship.gd` (visual wingman, NOT pooled, `queue_free` on detach, detached at wave-clear) | `tests/player/test_player_dock.gd` |
| Rescue → dock routing | `world/arena.gd::_on_captor_resolved` (rescue branch → `player.try_dock_ship()`) | `tests/world/test_arena_captor_resolution.gd` |
| Tuning (.tres wins) | `resources/docked_ship_tuning.tres` + `player/docked_ship_tuning.gd` | — |

**The ONLY new mechanic in 2.4 is AC2: the permanent `RunState.BuildState` track + the Arena wiring + the permanence GUT test (Tasks 1–4).** Task 5 is just pinning/formalizing (tests + comment refresh). Task 6 is the regression gate.

### 🏗️ The docked ship's DUAL NATURE (NP1) — the mental model

The rescued ship is **one logical entity with two roles** (architecture NP1; GDD "The Rescued Ship — dual nature"):

- **Permanent build track** = `RunState.BuildState.wing_track` — **run scope**, never cleared by consume, invested in via power-ups later (E3). *This is what 2.4 creates.*
- **Transient combat fighter** = the `DockedShip` node + the on-player combat presence (+stream, +hitbox, absorber, capture-immune) — **wave scope**, consumed on absorb/sacrifice, detached at wave-clear. *Already exists from 2.3.*

The headline invariant (architecture NP1, line 608 + 757): **the consume path removes the fighter node but NEVER clears the track.** This is the thing 2.4 makes real and tests.

### ⚖️ AR2 reconciliation — who writes the track (resolves the 2.3 "seam" comment)

`player/player.gd` comments from 2.3 say things like *"2.4 deepens set_docked to … persist the wing_track."* **That wording implies the Player writes the track. It must NOT.** AR2 (state ownership): the Player **never touches `RunState`** — ships/score/build live on `RunState`, owned by the Arena (the run host). So:

- **The Player owns the transient combat side only** (`set_docked`, hitbox, capture-immune, absorber) — already done, unchanged.
- **The Arena owns the permanent track side** — Arena calls `_run_state.build_state.record_rescue()` on a successful rescue dock (Task 3).
- **The permanence invariant is then structural:** the consume paths (`Player._consume_docked_ship` on absorb, `Player._on_wave_cleared` on keep) are on the Player, which has no `RunState` reference — they *cannot* clear the track even if they tried. Update the stale `# 2.4 seam` comments in `player.gd` to reflect this resolution.

### 🧭 Naming — use `wing_track` / `MAIN | WING`, NOT `rescued_track`

The epics AC2 text says "the rescued-ship track." That is the **superseded v1.0 spelling.** Architecture conflict **F-1** (resolved v1.1, 2026-07-01) renamed it: the ladders are **MAIN** (primary weapon) and **WING** (allied/rescue track). Use `wing_track` / `main_track` in code. The enum (when E3 introduces it on `PowerUpDefinition`) is `TargetLadder.{MAIN, WING}`. *(The epics file simply hasn't been re-spelled; the architecture is canonical. This is a noted reconciliation, not a conflict to escalate.)*

### 📁 File location — `build_state.gd` lives in `run/`, NOT `build/`

Architecture (line 506) + `project-context.md` both place it under `run/`: *"`run/` — run_state + build_state + run_generator + wave_definition."* `BuildState` is a sub-object of `RunState` (the run-scope spine). The `build/` domain is for the *engine* pieces (`stat_block`, `modifier`, `build_recompute`) that arrive in E3. Test mirrors: `tests/run/test_build_state.gd`.

### 🔧 The `DockedShipController` decision (NP1) — DEFER to 2.6

Architecture NP1 pseudocode is written as `player/docked_ship_controller.gd` owning attach/detach + a `_track` ref. **Story 2.3 did NOT introduce that controller** — it put attach/detach directly on `Player` (`try_dock_ship` / `set_docked` / `_consume_docked_ship` / `_detach_docked_ship`), with an acknowledged seam.

**Recommended for 2.4: do NOT refactor to a controller now.** Keep the Player-managed combat paths (working + tested) and let the Arena own the track (AR2, above). Rationale:
- The ACs do not mandate a controller node — only attach-gives-combat-presence (done), track-persists (new), fighter-is-transient (done).
- The permanence invariant is self-enforcing under AR2 without a controller.
- The controller buys nothing until **Sacrifice** (Story 2.6) needs an active-input home (NP5 hold-to-commit). Land it there, where there is a real reason.
- Refactoring tested 2.3 code mid-story is pure regression risk for zero AC benefit.

Leave a `# NP1 seam: docked_ship_controller (2.6 sacrifice)` note where it helps the next story. *(If Mrdth prefers the architecture-faithful controller refactor now, that is Approach A — see the open question at the end of this file — but it expands this story's scope and regression surface for no AC gain.)*

### 💰 Ship-count economy (already correct — do not "fix")

The docked fighter is a **ship-in-escrow** (Mrdth-confirmed 2026-07-12). The ONLY ship-count changes in the whole Gamble are **capture (−1, Story 2.2)** and **keep (+1, Story 2.5)**. **Rescue, absorb, sacrifice, failed-rescue, and no-rescue are all NO ship-count change.** The absorber (`_consume_docked_ship`) already spares HP with no `spend_ship` — 2.3 got this right. Do not add a ship cost to anything in 2.4. (The epics' old "−1 ship" wording for absorb/sacrifice is relative-to-Keep accounting, corrected in FR18 + the GDD.)

### ⚙️ Engine / project-context rules that apply

- **`class_name BuildState` + `godot --headless --import`**: a new `class_name` is invisible to GUT until the editor reindexes. Run the import once before running GUT, and check the test **counts** (GUT silently skips parse-failed scripts → "All passed!" can be false).
- **`set_deferred("shape", dup)`**: already used correctly in 2.3's `_swap_circle_radius`. Do not regress — assigning `CollisionShape2D.shape` inside a physics callback errors ("Can't change this state while flushing queries").
- **Deferred node release**: the docked fighter is a child of the Player (a CanvasItem); `queue_free` is deferred via `detach.call_deferred()` (no-arg method — Godot 4.6 cannot marshal a typed Node through `call_deferred`). Already correct; do not change.
- **No `print()`**: route logging through `Log`. No try/catch in GDScript — preconditions + `push_error`/`assert`.
- **Pooled projectiles**: the parallel stream already uses `Pool.acquire`/`release` on the player_projectile pool. Do not introduce an un-pooled spawner.
- **Pure-logic testability**: `BuildState` is a Resource with data + methods only (no signals, no EventBus) — unit-test it without a scene, exactly like `RunState`.
- **Tuning wins at runtime**: `resources/docked_ship_tuning.tres` overrides the `.gd` defaults (AR10/D9). The +28 px / 10 dmg / 18-radius knobs live there; editing the `.gd` default has no effect.

### 🧪 GUT exit-leak warnings are expected

Every GUT run prints "leaked"/"orphan" warnings at exit (Pool nodes aren't freed). Benign since Story 1.3 — trust the Passing/Failing counts, not the leak spam.

### Open Question (confirm with Mrdth before dev-story, non-blocking)

**Q — `DockedShipController` now or in 2.6?** This story is written for **Approach B (defer)**: keep Player-managed combat + Arena-owned track, land the controller in 2.6. **Approach A** (introduce `player/docked_ship_controller.gd` now, move attach/detach/consume into it, thread the `_track` ref) is more faithful to NP1's pseudocode but is a refactor of working, tested 2.3 code with no AC benefit. Recommendation: **B.** If Mrdth wants A, expand Tasks 1–4 with a controller-introduction task and a regression pass on the 2.3 dock/absorb suites.

---

## Project Structure Notes

- **NEW file:** `run/build_state.gd` (BuildState Resource — dual-ladder MAIN+WING spine). Co-located with `run_state.gd` per architecture + `project-context.md`.
- **NEW test:** `tests/run/test_build_state.gd` (pure-logic, mirrors `tests/run/test_run_state.gd`).
- **UPDATE:** `run/run_state.gd` (+`build_state` field + `begin_run` reset).
- **UPDATE:** `world/arena.gd` (`_on_captor_resolved` rescue branch → `record_rescue()` + optional `build_changed` emit).
- **UPDATE (comments/tests only):** `player/player.gd`, `player/docked_ship.gd`, `player/docked_ship_tuning.gd`, `tests/player/test_player_dock.gd` / `test_fire_system_docked.gd`, `tests/world/test_arena_captor_resolution.gd`, `tests/run/test_run_state.gd`. No behavioral change to 2.3 combat code.
- **No new `build/` files this story.** `build/` (stat_block, modifier, build_recompute) is E3.
- **No new tuning file.** `resources/docked_ship_tuning.tres` already exists and holds every docked knob (the architecture's "hardcoded for E2" is satisfied by a flat `.tres` — it is NOT a premature StatBlock; the D2 recompute pipeline is what E3 adds). Do not delete or fork it.
- **Alignment:** naming follows `project-context.md` (snake_case files, PascalCase nodes, UPPER_SNAKE consts, `_`-private). `wing_track` / `main_track` per F-1.

## Project Context Rules

*(Extracted from `_bmad-output/project-context.md` — the rules most load-bearing for this story.)*

- **State ownership is fixed (AR2):** ships / currency / score / build-tracks → `RunState`. Per-wave HP → `HealthComponent`. Docked-ship combat = `DockedShip` node (transient, wave scope); its build track = `RunState.BuildState` (**permanent — never cleared when the fighter is consumed**). The Player never touches `RunState`.
- **Build engine = recompute, never mutate:** effective stats = base + modifiers, recomputed at run start + each wave. E2 **hardcodes** docked stats (no premature StatBlock); the WING track exists + persists but is not wired through recompute until E3.
- **Composition over inheritance; strict collision layers:** `player / enemy / player_projectile / enemy_projectile / pickup`. The docked fighter + its stream inherit the **player** faction (no separate docked layer). The +hitbox is the PLAYER's own shape growing — not a second hitbox node (a second Area2D would double-trigger `apply_hit`).
- **Communication boundary (D8):** global game-flow → `EventBus` (typed, past-tense); local intra-entity → direct signals. `RunState`/`BuildState` emit nothing — the Node layer (Arena) emits bus signals off them.
- **No `print()` / no try-catch:** `Log` autoload; preconditions + `push_error` + `assert`.
- **Pooled entities re-init via `activate()`/`reset()`, never `_ready()`.** The DockedShip is NOT pooled (once-per-wave; `instantiate()`/`queue_free()`).
- **Hot-path discipline:** no per-frame allocations; cache refs in `@onready`; gameplay in `_physics_process` (60 Hz). The parallel stream must stay pooled.
- **Testing:** GUT, pure logic separated from Node code. New `BuildState` is pure → unit-test without a scene. `godot --headless -s addons/gut/gut_cmdln.gd`.

## References

- [Source: `_bmad-output/planning-artifacts/epics.md#Story 2.4`] — ACs verbatim (lines 475–487); Epic 2 "hardcodes docked stats, track starts flat" (lines 427–428, 242); FR7 (+28 px stream, line 47), FR16 (clean/docked tradeoff, line 62), FR17 (dual nature, line 63), FR18 (four outcomes + ship-economy clarifier, line 64); Story 2.5 (four outcomes, lines 497–500), Story 3.3 (WING investable, line 592).
- [Source: `_bmad-output/planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md`] — **NP1 Docked-Ship Dual Nature** + pseudocode + invariant "consume never clears track" (lines 600–631); Consistency Rules row "invariant + GUT test" (line 757); State-ownership table — `DockedShip` wave-scope vs `RunState.BuildState` run-scope (lines 198–210); `run/build_state.gd` location (line 506); F-1 naming `wing_track`/`MAIN|WING` (line 606); `set_docked(true) # capture-immune + bigger hitbox` (line 616); resolution-economy clarifier (line 631); strict collision layers (line 237); D8 signal boundary (lines 248–252).
- [Source: `_bmad-output/planning-artifacts/architecture/.../decision-log.md`] — F-1 build-ladder naming reconciliation (line 69); absorber/resolution set (line 50).
- [Source: `_bmad-output/planning-artifacts/gdds/gdd-meridian-run-2026-06-29/gdd.md`] — "The Rescued Ship — dual nature" (lines 119–139); clean/docked tradeoff table (lines 112–118); docked-ship resolution / four outcomes (lines 126–135); weapon table "Docked ship stream 10 dmg, +28 px" (line 224); triple-lock self-balancing incl. [Risk-12] (line 82).
- [Source: `_bmad-output/planning-artifacts/gdds/.../decision-log.md`] — **[Risk-12]** dual-fighter larger hitbox (line 31); **[Build-15]** hybrid docked ship (intrinsic absorber, line 28); 2026-07-12 ship-economy correction — absorber no `spend_ship` in 2.3 AND 2.5 (line 71); capture rule (line 58).
- [Source: `_bmad-output/planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/DESIGN.md` + `EXPERIENCE.md`] — docked-wingman = escort-chevron, ~80% scale, `{colors.dock}` (#5AF7FF), bright outline, player-family (DESIGN lines 124–129, 408–416; EXPERIENCE lines 157–162, 222–223). The `{colors.dock}` ring is **reserved for future Shield semantics (H6)** — do not add a decorative ring.
- [Source: `_bmad-output/implementation-artifacts/2-3-rescue-and-failed-rescue.md`] — the 2.4 scope seam (lines 970–974, 987–988, 993–994); ship-count economy table (lines 827–839); the +hitbox-is-the-player's-shape decision (Dev Notes).
- [Source: `_bmad-output/project-context.md`] — AR2 state ownership; D8 boundary; hardcoded-stats; collision-layer discipline; pooling/testing rules.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
