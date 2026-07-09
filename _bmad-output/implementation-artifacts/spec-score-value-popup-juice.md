---
title: 'Score-value death popup (Llamasoft juice)'
type: 'feature'
created: '2026-07-08'
status: 'done'
baseline_commit: 'c3f17ca549c25974f55cfd3e661179daf30b799f'
context: ['{project-root}/_bmad-output/project-context.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Enemy deaths spawn an explosion + shake + kill-sting, but the `score_value` (the reward itself) has no on-arena visual — the score just ticks up silently in the HUD, so kills read as less punchy than the Llamasoft (Tempest/Llamatron) target feel.

**Approach:** On a REAL enemy death, spawn a pooled, tween-driven floating `+N` label at the death point that zooms toward the viewer (scales up), drifts a small random x/y offset, and fades out over the explosion's lifetime. Routed through the existing EventBus juice-request channel (D8) and the arena-scoped `JuiceCoordinator`, mirroring `ParticleBurst`.

## Boundaries & Constraints

**Always:** Route via a new EventBus `score_popup_requested` signal (D8 — emitter `enemy._on_died` and consumer `JuiceCoordinator` are not in the same subtree). Pool the popup node (AR6 / hot-path: spawns on every death) — re-init via `activate()` only, self-release via a one-shot Timer → `Pool.release(self)`; never `queue_free()` (mirror `ParticleBurst`). Total lifetime = `tuning.explosion_lifetime` (literally "same speed as the explosion"). Color is a fixed gold from `JuiceTuning` (not per-enemy). Tween = parallel scale-up (`ease_out`) + x/y drift + alpha fade (`ease_in`) over that duration. Reduced-motion (D14): the coordinator dampens drift + scale-range by `_motion_scale` (dampen, don't remove); duration and fade are unaffected. Build the `Label` inline (no cross-domain font dependency — a static `+N` needs no mono face). Typed code, `@onready`-cached refs, no `print()`, no try/catch.

**Ask First:** None — feel values are tunable defaults for playtest retuning.

**Never:** No auto-scroll / runner motion. No new autoload (juice stays arena-scoped). No change to score accounting — the `died` signal → `RunState` score path is untouched; this is cosmetic only. No real z-axis / camera tricks (this is 2D — "z-zoom" means `scale`). No popup on `despawn()` (wave-end survivor cleanup — kill-only, like the explosion).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Real enemy kill | death at `(x,y)`, `score_value = N` | Gold `+N` spawns at `(x,y)`, scales up + drifts + fades to alpha 0 over `explosion_lifetime`, then returns to the pool | N/A |
| Wave-end survivor | `despawn()` | No popup spawns (kill-only) | N/A |
| Reduced motion | `Settings.reduced_motion == true` | Drift distance and scale-up range dampened ×`motion_scale_reduced`; duration and fade unchanged | N/A |
| Rapid multi-kill | several deaths same frame | Each spawns its own pooled popup (pool reuses freed instances) | N/A |

</frozen-after-approval>

## Code Map

- `systems/event_bus.gd` — add `score_popup_requested(at: Vector2, score_value: int)` in the juice-request section (D8).
- `juice/score_popup.gd` (NEW) — `ScorePopup` (Node2D) with a `Label` child; `activate(text, at, color, profile)` runs the parallel tween + arms the release Timer.
- `juice/score_popup.tscn` (NEW) — Node2D root + `Label` child, script attached.
- `juice/juice_fx.gd` — `enemy_killed` gains a `score_value: int` param and emits `score_popup_requested`.
- `enemies/enemy.gd` — `_on_died` passes `definition.score_value` into `JuiceFx.enemy_killed` (only call site).
- `juice/juice_tuning.gd` + `resources/juice_tuning.tres` — new "Score Popup" subgroup (color, scale_from, scale_to, drift_px).
- `juice/juice_coordinator.gd` — preload `score_popup.tscn`; add `_on_score_popup_requested` handler.
- `tests/juice/test_score_popup.gd` (NEW) — pool round-trip + activate + self-release (mirror `test_particle_burst`).
- `tests/juice/test_juice_coordinator.gd` — add handler + reduced-motion-dampen test.

## Tasks & Acceptance

**Execution:**
- [x] `systems/event_bus.gd` -- add `signal score_popup_requested(at: Vector2, score_value: int)` in the juice-request block -- D8 channel for the new popup.
- [x] `juice/score_popup.gd` + `juice/score_popup.tscn` -- create pooled Node2D (Label child); `activate(text, at, color, profile)` sets label text/color + `global_position = at`, runs `create_tween().set_parallel(true)` with scale `profile.scale_from`→`scale_to` (`ease_out`), `position += profile.drift`, `modulate.a` 1→0 (`ease_in`) over `profile.duration`, then arms a one-shot Timer(`duration + margin`) → `Pool.release(self)`; in `activate` kill any prior tween and stop the timer (re-arm guard) -- the pooled juice node, mirror `ParticleBurst`.
- [x] `juice/juice_tuning.gd` + `resources/juice_tuning.tres` -- add "Score Popup" subgroup: `score_popup_color` (`#FFE066` = `HudPalette.SCORE` reward amber), `score_popup_scale_from` 0.4, `score_popup_scale_to` 5.0 (retuned in-review — see Spec Change Log), `score_popup_drift_px` 24.0 -- tunable feel levers.
- [x] `juice/juice_coordinator.gd` -- `const SCORE_POPUP_SCENE := preload(...)`; connect `score_popup_requested`; in the handler roll a random drift vector within `score_popup_drift_px` radius, build the profile dict `{duration: tuning.explosion_lifetime, scale_from, scale_to, drift}` with drift + `(scale_to-scale_from)` dampened by `_motion_scale`, then `Pool.acquire` → `add_child` → `activate("+%d" % score_value, at, tuning.score_popup_color, profile)` -- arena-scoped consumer, D14 dampen.
- [x] `juice/juice_fx.gd` -- add `score_value: int` param to `enemy_killed`; emit `EventBus.score_popup_requested.emit(at, score_value)` alongside the existing explosion/shake/SFX -- kill-juice one-liner now also fires the popup.
- [x] `enemies/enemy.gd` -- pass `definition.score_value` into `JuiceFx.enemy_killed(...)` in `_on_died` -- the only call site.
- [x] `tests/juice/test_score_popup.gd` -- new: structure (Node2D + Label + `activate`), `activate` sets text/position/scale-from + arms timer, self-releases after `duration + margin`, pool round-trip reuses the same instance and re-arms -- mirror `test_particle_burst.gd`.
- [x] `tests/juice/test_juice_coordinator.gd` -- add: emitting `score_popup_requested(at, N)` spawns a `ScorePopup` child whose label reads `+N` at `at`; a second test asserts reduced-motion dampens the configured scale range -- guards the handler + D14.

**Acceptance Criteria:**
- Given a real enemy death, when `_on_died` fires, then a gold `+N` label spawns at the death point, scales up, drifts, and fades to invisible over exactly `explosion_lifetime` seconds, then returns to the pool (no `queue_free`).
- Given a wave-end survivor, when `despawn()` runs, then no score popup spawns.
- Given `Settings.reduced_motion` is on, when a popup spawns, then its drift and scale-up range are dampened by `motion_scale_reduced` while its duration is unchanged.
- Given the full GUT suite, when run headless, then all tests pass — including the new `test_score_popup.gd`, the extended `test_juice_coordinator.gd`, and the existing `test_enemy.gd` died-carries-score-value test.

## Spec Change Log

<!-- Append-only. Populated by step-04 during review loops. Each entry records: what finding
     triggered the change, what was amended, what known-bad state the amendment avoids, and any
     KEEP instructions (what worked well and must survive re-derivation). -->

- **2026-07-08 — in-review retune + review patches (3-reviewer pass: blind / edge-case / acceptance).**
  - **Retune (human-directed):** Mrdth's playtest directive during the in-review pass — "increase the scaling of scores dramatically." `score_popup_scale_to` 1.5 → **5.0** in both `juice_tuning.gd` and the runtime source-of-truth `resources/juice_tuning.tres` (the `.tres` is the live lever; editing only the `.gd` default has no runtime effect — that was the cause of an earlier "my edit changed nothing"). ~12.5× zoom from `scale_from` 0.4. Known-bad avoided: a peak too subtle to read as the intended Llamasoft score-reward zoom.
  - **Patch (acceptance + blind):** `motion_scale_reduced` schema default found corrupted to `3.3` (a leftover from playtest edits; the `.tres` still held 0.3 so runtime/tests passed) — restored to **0.3**. Known-bad avoided: the `tuning == null` fail-safe (`JuiceTuning.new()`) would have AMPLIFIED motion 3.3× under reduced motion — a D14 violation (dampen, don't remove).
  - **Patch (edge):** `"+%d"` → **`"%+d"`** in the coordinator — avoids the malformed `"+-N"` glyph if a negative `score_value` ever reaches the popup (latent; no shipped enemy triggers it). `%+d` yields `+N` for gains, `-N` for the impossible-negative case.
  - **KEEP:** the core design is unchanged and was validated by all three reviewers — pooling via `activate()`/Timer→`Pool.release` (no `queue_free`), the `score_popup_requested` EventBus signal (D8), D14 dampen logic (scale-range + drift by `_motion_scale`; duration/fade untouched), and duration sourced from `explosion_lifetime` ("same speed as the explosion"). No `intent_gap`/`bad_spec` — no loopback.

## Design Notes

- **Why a new node, not `ParticleBurst`:** `ParticleBurst` is `GPUParticles2D` — it cannot render text. A `Label`-backed `Node2D` is the minimal text popup and pools identically.
- **"z-axis zoom" in 2D = `scale`.** Toward-viewer = scale up (`ease_out`) so it reads as flying at the player; fade (`ease_in`) keeps it punchy then dissolves at peak — the Tempest/Llamasoft read.
- **Duration sourced from `tuning.explosion_lifetime`** (no separate knob) so the popup structurally matches the blast's fade — the user's "same speed as the explosion" is enforced, not a coincidental default.
- **Color in tuning, not the signal** (fixed gold `#FFE066` = `HudPalette.SCORE`), so it's one retune lever; the signal carries only the per-event data (`at`, `score_value`).
- **Reduced-motion dampens motion amplitude** (drift + scale range), mirroring how the coordinator dampens particle speed/scale; fade/duration are untouched (a fading number is not a strobe).
- **Cosmetic drift uses `randf`** (not `SeedManager`) — juice is not gameplay-deterministic; `ParticleBurst` already uses non-deterministic GPU randomness.

## Verification

**Commands:**
- `godot --headless -s addons/gut/gut_cmdln.gd` -- expected: 0 failing; includes new `test_score_popup.gd` + extended `test_juice_coordinator.gd`; no new leaked/orphan warnings beyond the expected GUT exit noise.

**Manual checks:**
- `godot --path . -e` → run the arena, kill Grunt/Shielder/Bomber: confirm gold `+100` / `+150` / `+300` zooms up, drifts, and fades in sync with the explosion; toggle reduced motion and confirm a calmer (smaller) drift and scale with the same lifetime.

## Suggested Review Order

**Entry point — the kill → popup trigger**

- Death hands `score_value` to the kill-juice helper (the only call site).
  [`enemy.gd:166`](../../enemies/enemy.gd#L166)
- Emits the popup request alongside the explosion/shake/SFX.
  [`juice_fx.gd:43`](../../juice/juice_fx.gd#L43)

**The popup node (core new artifact)**

- Pooled re-init: parallel tween (scale/drift/fade) + release Timer; mirrors `ParticleBurst`.
  [`score_popup.gd:46`](../../juice/score_popup.gd#L46)
- One-time inline Label + release-Timer setup (pool contract — runs once).
  [`score_popup.gd:30`](../../juice/score_popup.gd#L30)
- Scene: `Node2D` root + inline `Label`.
  [`score_popup.tscn:5`](../../juice/score_popup.tscn#L5)

**Arena-scoped consumer**

- Builds the profile (duration = `explosion_lifetime`, D14 dampen) and acquires/activates.
  [`juice_coordinator.gd:92`](../../juice/juice_coordinator.gd#L92)

**Signal (D8 boundary)**

- Typed juice-request signal — emitter and consumer are not in the same subtree.
  [`event_bus.gd:52`](../../systems/event_bus.gd#L52)

**Tuning (feel levers)**

- Score Popup subgroup: color / scale_from / scale_to (5.0) / drift_px.
  [`juice_tuning.gd:53`](../../juice/juice_tuning.gd#L53)
- Runtime source-of-truth values (the live playtest lever — edits here take effect).
  [`juice_tuning.tres:35`](../../resources/juice_tuning.tres#L35)

**Tests (peripherals)**

- Pool round-trip + activate re-arm (mirrors `test_particle_burst`).
  [`test_score_popup.gd:26`](../../tests/juice/test_score_popup.gd#L26)
- Handler spawns `+N` at `at`; reduced-motion dampens the scale range.
  [`test_juice_coordinator.gd:224`](../../tests/juice/test_juice_coordinator.gd#L224)
