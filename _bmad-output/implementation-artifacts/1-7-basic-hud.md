---
baseline_commit: 25881b4375c4d81431901770e904231aef460083
---

# Story 1.7: Basic HUD

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want a clean, non-diegetic HUD showing on-ship HP, lives, the wave timer, score, and the active modifier — laid out so it never crosses my 1-axis play lane,
so that I can read my run state at a glance and my combat attention stays on the ship and fire-columns.

## Acceptance Criteria

*(Verbatim from `epics.md` Story 1.7, lines 388–406. Cite tags preserved: FR46 basic, FR49 · UX D1/F3/H2/H3/H4/H5/H6/T1/S1/A2/V3 · arch D13/D15/D16.)*

1. **Given** the HUD stance is **non-diegetic** (UX D1) on its own **`CanvasLayer` separate from the world tree** (UX F3), **Then** it floats as an arcade overlay and **never obscures the 1-axis play lane** (top band only — `spacing.hud-band`) — this separation is an explicit acceptance criterion.
2. **Given** the HUD layout (UX H5), **Then** **lives = ship-icon pips top-left** (`lives-display`), **wave-timer top-center** (`XXs` format, UX T1/H3 — survive-to-end countdown), and **score top-right** with **wave number + modifier chip beneath it** (`score-readout` + `wave-modifier-readout`). **Tier is dropped** from the in-wave HUD (UX H4 — chosen pre-run).
3. **Given** the score readout, **Then** it shows **score only** — **no currency in-wave** (UX H2; `currency` is a shop-stage concept).
4. **Given** player HP, **Then** it renders as a **segmented bar above the player ship** (`hp-bar`, UX H4/H6 — primary read, co-located with focus; same segmented idiom reuses on multi-hit/damaged enemies, absent on 1-hit grunts). Ring/halo reserved for future Shield PU, **not** HP.
5. **Given** the wave-timer, **Then** at low-time the numeric shifts to `colors.hazard` with a **neutral-white glow halo** (climax: `climax-hazard` amber) (UX T1/A2).
6. **Given** the player-vs-hazard read, **Then** the **player family (ship/projectiles/docked-wingman) is silhouette + bright-outline distinct from the hazard family (enemy fire/capture-column)** — shape carries meaning, color reinforces (UX A2; arch D16). Never hue-alone.
7. **Given** the palette arc (UX V3; arch D13), **Then** HUD elements subscribe to `EventBus.arc_t_changed` and recolor calm→climax via `modulate` (no `queue_redraw()`). In E1's authored wave `arc_t` stays ~0 (calm Vector Standard); it warms once the Story 3.9 driver emits.
8. **Given** combat intensity, **Then** the HUD runs the **focus/fade FSM** (UX S1; reusable `components/state_machine`, arch D15) with pure `HudFocusModel` — score + modifier chrome **dim**, while **timer + on-ship HP + lives stay sharp**. *(v0.1 baseline: FSM + model exist and transition; full per-component saturation tuning + climax integration mature at E8 polish.)*
9. **Given** `EventBus` signals (`health_changed`, `ship_lost`, `wave_changed`/`score_changed`, `arc_t_changed`), **When** they fire, **Then** the HUD updates (subscribers cache; no per-frame polling).

---

## Tasks / Subtasks

> **Read every file under "Code to read/edit" (Dev Notes → References) in full before editing.** The HUD is the first `ui/` content and the first node to subscribe to several signals that do not yet exist — the wiring decisions below are load-bearing.

### Task 1 — EventBus: add `wave_started` + `arc_t_changed` (AC: #2, #5, #7, #9)

- [x] 1.1 Add `signal wave_started(wave: int, duration_s: float)` to `systems/event_bus.gd` under the global game-flow events group. **Emitted by the spawner** at the top of `begin_wave()` (Task 2.1) — symmetric with the existing `wave_cleared(_wave_n)` emit at wave-end. This carries BOTH the wave number (for `wave-modifier-readout`) AND the countdown duration (for `wave-timer`). *(Rationale: no wave-start signal exists today; `wave_cleared` alone can't bootstrap wave 1 or the countdown. See Key Decision #2.)*
- [x] 1.2 Add `signal arc_t_changed(t: float)` to `systems/event_bus.gd` as a **derived, read-only theming-state signal** (arch line 420 lists it verbatim). **No emitter in E1** — `PaletteArcCoordinator` (Story 3.9) emits it once the build engine exists. Declaring it now is sanctioned (arch D13 + the 3.9 sequencing note: "the theme-token spine + pure `arc_t` logic may scaffold earlier if desired") and lets the HUD's subscription (AC7) compile + be unit-tested. Comment it clearly: "derived theming state; emitted by `PaletteArcCoordinator` (Story 3.9); stays 0/calm in E1."
- [x] 1.3 Update the `event_bus.gd` header comment (D8 boundary notes) to record both additions + their owners/emitters, mirroring the 1.6 juice-comment style.

### Task 2 — Spawner emits `wave_started` (AC: #2, #5, #9)

- [x] 2.1 In `world/formation_spawner.gd::begin_wave(n)`, emit `EventBus.wave_started.emit(_wave_n, wave_duration_s)` after the per-wave state reset + `set_physics_process(true)`, before/after the `Log.info` line. **`_wave_n` is set first** (it's assigned at the top of `begin_wave`); `wave_duration_s` is the `@export` already on the spawner. This is additive — existing 1.4/1.5 spawner tests ignore it (verify they stay green).
- [x] 2.2 Do NOT change `wave_cleared` behavior, `_wave_time` accumulation, or the `_wave_time > wave_duration_s` clear path. The HUD's countdown is **local** to the HUD (Task 5), seeded by `wave_started`; it does NOT read `_wave_time` (no per-frame cross-domain read, no polling — AC9).

### Task 3 — `components/health_bar.gd` + `.tscn` (segmented, world-space, reusable) (AC: #4, #6)

> Arch line 470 names this exact file: `health_bar.gd # segmented HP bar (Node2D) — on-ship + on-enemy idiom (UX H6)`. Use the name `health_bar` (NOT `hp_bar`) and the home `components/`. It is **world-space** (a child of the entity, above the sprite) — NOT a Control node, NOT on the HUD CanvasLayer.

- [x] 3.1 `components/health_bar.tscn`: root `Node2D` named `HealthBar`, script `res://components/health_bar.gd`. No collision shape (pure visual). Position is set by the parent scene (above the ship/enemy sprite).
- [x] 3.2 `components/health_bar.gd` (`class_name HealthBar extends Node2D`):
  - `@export var segment_w: float = 10.0`, `segment_h: float = 4.0`, `segment_gap: float = 3.0`, `segment_radius: float = 2.0` (DESIGN `hp-bar`: 10×4, 3px gap, `rounded.xs`). `@export var y_offset: float = -28.0` (above the sprite; tuning-friendly).
  - `@export var fill_color: Color` + `empty_stroke_color: Color` + `glow_color: Color` (defaults from the calm palette — Task 7).
  - `var _current: int = 0`, `var _maximum: int = 0`, `var _configured: bool = false`.
  - `func bind(health: HealthComponent) -> void`: cache the ref, set `_maximum = health.max_hp`, `_current = health.current_hp`, connect `health.health_changed` → `_on_health_changed` ONCE (guard with `is_connected`), and `queue_redraw()`. Called by the entity's `_ready` (player/enemy) — intra-entity, D8-clean (NO EventBus for HP).
  - `func _on_health_changed(current: int, maximum: int) -> void`: set `_current`/`_maximum`, `queue_redraw()`. **Redraw only on change** (project-context: custom `_draw()` calls `queue_redraw()` only when state actually changes).
  - `func _draw() -> void`: draw `_maximum` segments left→-right; filled segments (`_current`) = `fill_color` rect + `glow_color` outline; empty segments = transparent fill + `empty_stroke_color` 1px outline. Use `draw_rect` (with the rounded radius approximated — sharp rects are fine for v0.1 neon-vector; `rounded.xs` = 2px is near-square anyway). **No per-frame draw** — `_draw` runs only when `queue_redraw` is called.
  - **Hide-at-full optionality (enemies):** add `@export var hide_when_full: bool = false`. Enemies set it `true` (bar hidden at full HP per UX H6); the player sets it `false` (primary read always visible). When `hide_when_full && _current == _maximum`: skip drawing (`visible = false` or early-return in `_draw`). Player bar is always shown.
- [x] 3.3 **Ring/halo is reserved for Shield PU (H6) — do NOT draw a ring around segments.** Segments only.
- [x] 3.4 Subscribe to `EventBus.arc_t_changed` for future recolor (Task 7) — in E1 the handler applies calm colors only (t≈0).

### Task 4 — Wire `health_bar` onto player + enemies (AC: #4)

- [x] 4.1 `player/player.tscn`: add a `HealthBar` child (instance `components/health_bar.tscn`) positioned above the `Visual` sprite (y ≈ `y_offset`). `hide_when_full = false`. In `player/player.gd::_ready`: `@onready var _health_bar: HealthBar = $HealthBar`, then `_health_bar.bind(_health)` (after `_health` is wired). The bar connects to the player's OWN `HealthComponent.health_changed` — no bus. Do NOT regress the i-frame `_visual.modulate.a` flicker (1.6) — the bar is a separate child.
- [x] 4.2 `enemies/shielder.tscn` + `enemies/bomber.tscn`: add a `HealthBar` child, `hide_when_full = true` (hidden until damaged — UX H6). In `enemies/enemy.gd` (the shared base, composes components): in `activate()`/`reset()` (the pooled-enemy re-init path — NOT `_ready`), bind the bar to the enemy's `HealthComponent`: `$HealthBar.bind(_health)` if the child exists. Guard with `has_node("HealthBar")` so grunts (no bar) and pool reuse both work. **Re-bind on every `activate()`** because pooled nodes don't re-fire `_ready` (project-context pooled-node rule).
- [x] 4.3 **Grunt gets NO bar** (per AC4 "absent on 1-hit grunts"). ⚠️ **Flagged discrepancy:** current tuning makes Grunt 30 HP / player 10 dmg = 3-hit (NOT 1-hit) — see Open Question #3. Default: honor the AC intent (no grunt bar); the bar appears on Shielder (50 HP) + Bomber (80 HP).
- [x] 4.4 Verify the bar survives pool acquire/release cycles (the bar is a child of the enemy scene, so it reparents with the enemy — no separate pooling).

### Task 5 — `ui/hud/` readout sub-scenes + scripts (AC: #1, #2, #3, #5, #7)

> All live on a `CanvasLayer` (AC1, F3), top band only (`spacing.hud-band` = 58px). They are `Control` nodes. Arch lines 518–519 name them.

- [x] 5.1 `ui/hud/lives_display.tscn/.gd` (`class_name LivesDisplay extends Control`): a `HBoxContainer` of ship-icon pip nodes + a trailing `×N` `Label`. `func set_ships(remaining: int, maximum: int = Constants.MAX_SHIPS) -> void`: render `maximum` pips — lit pips (`remaining`) = transparent fill + primary stroke + glow; lost pips = dashed muted stroke at 55% opacity (**never removed** — the gamble reads only if max-ships is visible, UX S1). Updates only on `ship_lost`/ship-gain — **never animates the digit** (it's a pip row). Stays sharp through focus/fade.
- [x] 5.2 `ui/hud/wave_timer.tscn/.gd` (`class_name WaveTimer extends Control`): a `Label` showing `XXs` (mono — Task 8). Owns the **local countdown**:
  - `func start(wave: int, duration_s: float) -> void`: store `_remaining = duration_s`, update the label to `ceil(duration_s)`.
  - `func _process(delta: float) -> void`: `_remaining = maxf(_remaining - delta, 0.0)`; **only update the Label when `ceil(_remaining)` changes** (cache `_last_shown: int` — avoid setting `text` every frame). Format `XXs` (e.g. `23s`).
  - `func stop() -> void`: freeze (called by HUD on `wave_cleared`).
  - **Low-time:** when `_remaining <= low_time_threshold` (tunable, e.g. 10s), numeric → `colors.hazard` + glow halo = **neutral white** (NOT hero primary — AC5, UX T1). Restore on wave restart.
- [x] 5.3 `ui/hud/score_readout.tscn/.gd` (`class_name ScoreReadout extends Control`): `SCORE` label (caps, muted) above a numeric `Label` (`colors.score` + glow). `func set_score(value: int) -> void` → updates the label (mono). Subscribes via HUD to `EventBus.score_changed`. **Score only — no currency** (AC3, H2 — do NOT render `colors.currency`).
- [x] 5.4 `ui/hud/wave_modifier_readout.tscn/.gd` (`class_name WaveModifierReadout extends Control`): `WAVE N` label (caps, muted) + a modifier chip. `func set_wave(wave: int) -> void` updates the wave number. The modifier chip: in **E1 there is no modifier system** (modifiers are Epic 5) — show a neutral placeholder (`STANDARD`, or hide the chip). Build the shape-glyph machinery (cluster/columns/diamond → SWARM/GAUNTLET/BOUNTY, `colors.modifier-*`) but leave it unused until E5 (forward-compat). **Shape carries meaning first, color reinforces** (A1) — when wired, each modifier gets a distinct shape, never color-alone.
- [x] 5.5 Each readout subscribes to `EventBus.arc_t_changed` (Task 7) for recolor; in E1, calm colors only.

### Task 6 — `ui/hud/hud_focus_model.gd` (PURE) + focus/fade FSM (AC: #8)

> Arch line 321 is canonical: "`hud.gd` runs the **reusable `components/state_machine`** (not bespoke) with states `standard ↔ focus_fade`. Transitions driven by `HudFocusModel.intensity(projectiles_in_play, captors_active, hp_ratio, time_remaining) -> float` (pure) with **hysteresis** (no flicker), recomputed on a throttle / on events — not per-frame."

- [x] 6.1 `ui/hud/hud_focus_model.gd` (`class_name HudFocusModel extends Resource` — or a `RefCounted`/static-class pure helper):
  - `func intensity(projectiles_in_play: int, captors_active: int, hp_ratio: float, time_remaining: float) -> float`: returns 0.0..1.0. **Pure, no node access** — GUT-testable.
  - E1 inputs: `captors_active = 0` (Epic 2), `projectiles_in_play = 0` (no central counter yet — pass 0); the load-bearing inputs are `hp_ratio` (low HP → high intensity) and `time_remaining` (low time → high intensity). Weight them so that, e.g., `hp_ratio < 0.34` OR `time_remaining < low_time_threshold` pushes intensity above the focus-fade enter threshold.
  - Document that `projectiles_in_play`/`captors_active` are forward-compat (0 in E1); they mature in E2/E8.
- [x] 6.2 Focus/fade FSM using the **reusable** `components/state_machine/` (`StateMachine` + `State` — already built, see 1.4). Add `ui/hud/states/standard_state.gd` + `focus_fade_state.gd` (each `extends State`). On `enter`/`exit`, the states apply/release the dim via the owner HUD (reach the HUD via `owner` cast to the HUD type — the StateMachine's documented pattern, `state.gd` header).
  - `FocusFadeState`: dim score-readout + wave-modifier-readout chrome to **~32% opacity** (v0.1: `modulate.a = 0.32` on those nodes — see Key Decision #6 on saturation). **wave-timer + lives-display stay sharp** (modulate.a = 1.0). The on-ship `health_bar` is always sharp (it's not a HUD child — no action).
  - `StandardState`: restore all chrome to full.
- [x] 6.3 Hysteresis: enter focus_fade when intensity rises above `FOCUS_ENTER_AT` (e.g. 0.6); return to standard when it drops below `FOCUS_EXIT_AT` (e.g. 0.4). Constants (or a tuning `.tres`) — the gap prevents flicker.
- [x] 6.4 **Recompute trigger (NOT per-frame — AC9, arch D15):** evaluate the model on events — `player.health_changed` (hp_ratio changes), `wave_timer` crossing `low_time_threshold`, and `wave_started`/`wave_cleared` (reset to standard between waves). A light throttle (e.g. recompute at most every 100ms) is acceptable if event-only proves too sparse. Document the chosen trigger.
- [x] 6.5 v0.1 baseline satisfies AC8: "FSM + model exist and transition." Full per-component saturation tuning + climax integration mature at E8 — do NOT gold-plate.

### Task 7 — Calm palette + arc_t recolor path (AC: #5, #7)

> ⚠️ `theme_tokens.gd` / `palette_arc_*` are **Story 3.9** — DO NOT create them (1.6 explicitly deferred; arch lines 499–501 own them to 3.9). The HUD uses **calm Vector Standard colors only** in E1, with a forward-compat `arc_t_changed` subscription.

- [x] 7.1 Create a HUD-local calm palette: `ui/hud/hud_palette.gd` (`class_name HudPalette`) — `const` `Color` values lifted **verbatim** from UX DESIGN.md frontmatter (calm column only): `SURFACE`, `TEXT`, `MUTED`, `BORDER`, `PRIMARY`, `PRIMARY_HOVER`, `HEALTH`, `HAZARD`, `SCORE`, `GLOW`, `MODIFIER_SWARM/GAUNTLET/BOUNTY`. (Exact hex in Dev Notes → Color tokens.) This is a temporary spine; Story 3.9's `ThemeTokens` + `PaletteArc` replace it and drive the calm→climax lerp.
- [x] 7.2 Every themed HUD node + `health_bar` subscribes to `EventBus.arc_t_changed(t)` and applies color via `modulate` / theme-override-colors (NO `queue_redraw()` for the recolor path on Labels — AC7). In E1 the handler is a no-op (t stays 0 → calm). Wire it so that when 3.9 emits, the recolor "just works" — but keep the v0.1 implementation calm-only (the climax termini interpolation matures at E8).
- [x] 7.3 Wave-timer low-time glow = **neutral white** (`Color.WHITE` or `#FFFFFF`), NOT `colors.primary` — AC5. (At climax it would track `climax-hazard` amber, but that's moot in E1.)

### Task 8 — Fonts: monospace numerics + display (AC: #2, #5 — UX T2)

> ⚠️ **No `.ttf` exists in-repo** (`assets/` is empty except `.gdkeep`). UX mandates Chakra Petch (display) / Inter (body) / **JetBrains Mono (numerics)**. The numeric face MUST be monospace or score/timer digits jitter column-to-column (T2 explicit). See Open Question #1.

- [x] 8.1 **Recommended:** fetch OFL-licensed fonts via `curl` into `assets/fonts/` (AI CAN download binaries, unlike authoring them): at minimum **JetBrains Mono** (`JetBrainsMono-Regular.ttf`, `JetBrainsMono-Bold.ttf`) for numerics/labels; optionally **Chakra Petch** (display) + **Inter** (body) for full fidelity. Sources: official GitHub releases / Google Fonts (OFL). Verify the license file is committed.
- [x] 8.2 **Fallback (no network):** use Godot's default font for display/body labels, but the numeric labels (score, timer, `×N`) MUST still be monospace — if no mono `.ttf` is available, fall back to Godot's built-in monospace via a `FontFile` with `monospace` spacing, or accept a documented "numerics may jitter; real faces at E8" deviation. Flag which path was taken.
- [x] 8.3 Build a minimal `ui/theme/ui_theme.tres` (Godot `Theme` resource, arch line 531) OR use per-label `theme_override_font_sizes`/`theme_override_colors`/`theme_override_fonts` for v0.1. Sizes from DESIGN `typography`: `numeric-lg` ~30px bold (score, timer), `numeric-sm` ~13px bold (`×N`), `label-caps` ~11px (SCORE/WAVE labels). Full theme matures at E8.

### Task 9 — `ui/hud/hud.tscn` + `hud.gd` (the CanvasLayer conductor) (AC: #1, #8, #9)

> `hud.gd` is the HUD conductor — twin concept to `JuiceCoordinator` (arena-scoped, EventBus-driven). Root is a `CanvasLayer` (AC1). Add it as a child of the Arena scene (Task 10).

- [x] 9.1 `ui/hud/hud.tscn`: root `CanvasLayer` named `HUD`, script `res://ui/hud/hud.gd`. `layer` = a high value (above the world; below future `panel-scrim`/menus — arch layer stack line 322). Children laid out in the top `hud-band` (58px): `LivesDisplay` (top-left, anchored top-left + `title-safe` 5% margin), `WaveTimer` (top-center), `ScoreReadout` (top-right) with `WaveModifierReadout` beneath it. **Anchor corners stay fixed** across viewports (UX H5). Nothing crosses into the lane band.
- [x] 9.2 `ui/hud/hud.gd` (`class_name Hud extends CanvasLayer`):
  - `@onready` refs to the four readouts + the `StateMachine` (focus/fade FSM, child node) + the `HudFocusModel`.
  - In `_ready`: subscribe — `EventBus.score_changed.connect(_on_score_changed)`, `EventBus.ship_lost.connect(_on_ship_lost)`, `EventBus.wave_started.connect(_on_wave_started)`, `EventBus.wave_cleared.connect(_on_wave_cleared)`, `EventBus.arc_t_changed.connect(_on_arc_t_changed)`. Seed initial values (the HUD can construct mid-run; reading current `RunState` is NOT its job — it updates on the next signal. Optionally Arena injects initial values in Task 10.1).
  - Route signals to readouts: score→`ScoreReadout.set_score`, ship_lost→`LivesDisplay.set_ships(remaining, MAX_SHIPS)`, wave_started→`WaveModifierReadout.set_wave(wave)` + `WaveTimer.start(wave, duration_s)` + reset focus FSM to standard, wave_cleared→`WaveTimer.stop()`.
  - HP for the focus model: Arena injects the player ref (Task 10.1); the HUD caches `_player_health: HealthComponent = _player.get_node_or_null("HealthComponent")` (the established node-name convention) and connects its `health_changed` → `_on_health_changed(cur, max)` to feed `hp_ratio` into the focus model recompute. **Read-only subscribe — this is the HUD's display job, D8-clean** (same pattern as JuiceCoordinator subscribing to the bus).
  - `func _recompute_focus() -> void`: call `HudFocusModel.intensity(...)` with current inputs; apply hysteresis; `transition_to` if crossed. Called from the event hooks (Task 6.4), NOT per-frame.
- [x] 9.3 `_process` on the HUD itself is only needed if the wave_timer isn't self-driving — prefer the wave_timer owning its own `_process` countdown (Task 5.2). Keep `hud.gd._process` empty/absent (no per-frame work in the conductor — AC9).

### Task 10 — `arena.tscn` integration + Arena injection (AC: #1, #9)

- [x] 10.1 `world/arena.tscn`: instance `ui/hud/hud.tscn` as a child of `Arena` (sibling of `Player`/`FormationSpawner`/`JuiceCoordinator`). In `world/arena.gd::_ready` (after wiring the spawner/player): `@onready var _hud: Hud = $HUD`, then inject the player ref: `_hud.player = _player` (add a `var player: Node2D` setter on `hud.gd` that resolves + caches the HealthComponent + (re)connects). Optionally seed initial score (0) + ships (BASE_SHIPS) + wave (1) so the HUD isn't blank before the first signal — `_hud.seed(RunState ships/score, wave_num=1)` or emit the signals once.
- [x] 10.2 Verify the HUD does NOT obscure the play lane (top band only) and survives `canvas_items`+`expand` scaling at the 1280×720 base + a non-16:9 stretch (title-safe margins hold).
- [x] 10.3 `arena.gd` is otherwise **read-only** — do not change the ship-loss/wave-clear/game-over/replay flow (1.5 baseline). The HUD only subscribes; it emits nothing to the bus.

### Task 11 — Tests (GUT, `tests/ui/` + `tests/components/`) (AC: all)

- [x] 11.1 `tests/ui/test_hud_focus_model.gd` (arch line 545 names this file — **pure unit test, no scene**): assert `intensity(...)` returns 0..1; low `hp_ratio` + low `time_remaining` → high intensity; high HP + ample time → low; boundaries clamped. This is the canonical pure-logic test.
- [x] 11.2 `tests/components/test_health_bar.gd` (integration): instantiate `health_bar.tscn` + a real `HealthComponent`; `bind()`; drive `take_damage`/`heal`/`reset_to_full` → assert `_current`/`_maximum` track + `queue_redraw` is requested (or assert via `_draw` output count is stable between unchanged frames). Test `hide_when_full` (hidden at full, shown when damaged).
- [x] 11.3 `tests/ui/test_hud.gd` (integration, `extends GutTest`, `before_each` → `Pool.clear()`): instantiate `hud.tscn` (inject a stub/minimal player with a `HealthComponent`); emit `EventBus.score_changed` → assert `ScoreReadout` updates; emit `ship_lost` → assert `LivesDisplay` pips; emit `wave_started(1, 30.0)` → assert `WaveModifierReadout` shows WAVE 1 + `WaveTimer` shows `30s` and counts down over `await get_tree().physics_frame`; emit `arc_t_changed(0.0)` → no crash (calm path); drive hp low → assert FSM transitions to focus_fade (score chrome `modulate.a` ≈ 0.32, timer stays 1.0). Use `add_child` (not `autofree`) for scene nodes.
- [x] 11.4 `tests/ui/test_wave_timer_low_time.gd` (or fold into 11.3): countdown crossing `low_time_threshold` → numeric color is hazard + glow is neutral white.
- [x] 11.5 **Regression:** full GUT suite (`godot --headless -s addons/gut/gut_cmdln.gd`) — all 1.1–1.6 tests stay green (1.6 baseline: 20 scripts, 144 tests). The new `wave_started` emit in the spawner must not break `test_formation_spawner.gd`.

### Task 12 — Regression, housekeeping, verification (AC: all)

- [x] 12.1 `godot --headless --import` after adding `class_name`s / `@export`s / new scenes (every prior review flagged this — scenes/tests won't resolve types otherwise).
- [x] 12.2 Verify the 11-autoload registry is unchanged (`project.godot`) — the HUD is arena-scoped, NOT an autoload.
- [x] 12.3 Remove `ui/.gdkeep` + `tests/ui/.gdkeep` placeholders if present (the folders now hold real content). Do NOT remove `tests/components/.gdkeep` if it still has none beyond the new bar test (it has tests already).
- [x] 12.4 Headless launch (`godot --headless --path .`) is clean (no errors); the arena renders with the HUD visible in-editor. Run the arena in-editor to eyeball: HUD top-band only, hp-bar above the ship, score ticks on kills, timer counts down, lives drop on ship loss.
- [x] 12.5 Update `MEMORY.md`/deferred-work if new landmines emerge (e.g., the grunt-3-hit discrepancy, the font-fetch path).

### Review Findings

*(2026-07-06 — three-layer review: Blind Hunter, Edge Case Hunter, Acceptance Auditor. All 7 patch findings applied same day; regression test updated + 4 new tests added; 190/190 GUT tests pass, 0 regressions.)*

- [x] [Review][Patch] Focus/fade never engages from low time alone — `WaveTimer` never signals `Hud` when it crosses `low_time_threshold_s`; `_recompute_focus()` is only wired to `health_changed`/`wave_started`/`wave_cleared`/`set_player`. Contradicts Task 6.4 and the Completion Notes' claim that focus/fade "transition[s] on low HP / low time." The new test `test_low_time_engages_focus_fade` only passes by manually re-emitting a no-op `health_changed` to force the recompute, papering over the missing wiring. [ui/hud/wave_timer.gd, ui/hud/hud.gd:197-211]
- [x] [Review][Patch] Wave-timer's `stop()`-before-render ordering breaks low-time signaling at the exact moment of expiry — in `_process`, `stop()` (which flips `_running = false`) runs before `_update_display(false)`, so at `_remaining == 0`: (a) `Hud._recompute_focus`'s `is_running() ? get_time_remaining() : 999.0` sentinel reads the most urgent instant as perfectly calm, and (b) `_update_display`'s `low` bool (gated on `_running`) reverts the numeral to its normal color instead of hazard, right when the timer hits zero. [ui/hud/wave_timer.gd:53-79]
- [x] [Review][Patch] AC5's "neutral-white glow halo" at low-time is unimplemented — `HudPalette.WHITE` is declared with a comment naming it for exactly this purpose but is never referenced anywhere. `_update_display` only recolors the numeric to HAZARD and the suffix to MUTED; no glow/halo of any kind is applied. Task 11.4 (a dedicated low-time visual test) is checked complete but `tests/ui/test_wave_timer_low_time.gd` does not exist. [ui/hud/wave_timer.gd, ui/hud/hud_palette.gd:27]
- [x] [Review][Patch] `Hud` does not stop the wave-timer/focus-fade FSM on `EventBus.game_over` — the signal exists and `arena.gd` emits it, but `Hud._ready()` never subscribes, so the countdown/focus state can keep advancing after the run ends (visible whenever `auto_replay_on_loss = false`, which GUT tests use explicitly; also relevant to Story 8.4's eventual real game-over screen). [ui/hud/hud.gd]
- [x] [Review][Patch] HUD band-height is inconsistent across three sources of truth — `HudPalette.HUD_BAND_PX` says 58px (the DESIGN token AC1 cites), `Hud._BAND_HEIGHT_PX` is actually 96px, and the story's own Change Log claims a "56 → 64" bump. Not a functional violation today (ample headroom under the 720px viewport) but will mislead the next dev who trusts the "58px" constant. [ui/hud/hud_palette.gd:30, ui/hud/hud.gd:25]
- [x] [Review][Patch] `ScoreReadout`/`WaveModifierReadout` freeze `custom_minimum_size` from placeholder text (`"0"` / `"WAVE 1"`) once in `_ready()` and never recompute it in `set_score`/`set_wave`. A long-run high score (6+ digits) or late wave number could render wider than originally sized; Labels don't clip by default. [ui/hud/score_readout.gd:15-34, ui/hud/wave_modifier_readout.gd:20-44]
- [x] [Review][Patch] `HealthBar.bind()` never disconnects from a previously-bound `HealthComponent` — only guards against reconnecting the *same* instance. Not triggered by any current call site (every caller rebinds its own single component), but the method's own doc comment ("safe to call every `activate()` across pool reuse") implies rebind-to-a-different-instance safety that isn't actually there. [components/health_bar.gd:56-62]

---

## Dev Notes

### 🔑 Key decisions (read these first — they resolve the open forks the architecture left to this story)

1. **The HUD is arena-scoped, NOT an autoload — twin to `JuiceCoordinator`.** It lives in `arena.tscn` as a `CanvasLayer` child, subscribes to `EventBus`, is destroyed/recreated on game-over replay (clean). "Auto-disabled in menus" (UX F8) is satisfied structurally (menu scenes never include it). The 11-autoload registry stays unchanged (arch line 556). This mirrors 1.6 Key Decision #3 exactly — follow that precedent.

2. **The wave timer needs a NEW `wave_started(wave, duration_s)` signal; the HUD runs its OWN local countdown.** Today the spawner counts `_wave_time` UP and emits `wave_cleared` at expiry — there is no wave-start signal and no remaining-time feed. Adding `wave_started` (emitted by the spawner's `begin_wave`, symmetric with `wave_cleared`) gives the HUD both the wave number and the countdown seed. The HUD then decrements a local float in `_process` (this is local integration, NOT "polling" — AC9's no-polling rule is about not re-reading `RunState`/the bus every frame for score/ships). Rationale for spawner-emits-not-Arena-emits: the spawner is the E1 wave-timing owner (it has `_wave_n` + `wave_duration_s`); splitting wave-start onto Arena would scatter wave signals across two nodes. Forward-compatible: Story 1.8's `wave_controller` takes over wave timing and the HUD keeps consuming `wave_started`/`wave_cleared`.

3. **HP does NOT go on the bus — the `health_bar` binds to its entity's own `HealthComponent` (intra-entity, D8).** The AC9 phrase "EventBus signals (`health_changed`, …)" describes the *signal-driven update pattern*, NOT a literal requirement to add `health_changed` to `EventBus`. Per D8 (and 1.6 Key Decision #1, which kept juice OFF `HealthComponent`), HP is entity-local: `HealthComponent.health_changed(current, max)` is a direct signal. The `health_bar` (a child of the player/enemy) connects to its own entity's `HealthComponent` directly. The HUD's focus model separately needs `hp_ratio` — it gets that by read-only subscribing to the player's `HealthComponent.health_changed` via an injected player ref (the HUD's display job; same legitimacy as JuiceCoordinator subscribing to the bus). **Do NOT add `health_changed`/`player_hit` to `EventBus`** — it would violate D8 and churn the shared component + its tests.

4. **`theme_tokens.gd` / `palette_arc_*` are Story 3.9 — DO NOT create them.** The HUD uses a HUD-local calm palette (`ui/hud/hud_palette.gd`, `const Color` from DESIGN.md) for E1. It subscribes to `EventBus.arc_t_changed` (declared now, no emitter until 3.9) so the recolor path is built + testable, but in E1 only the calm path runs (t stays ~0). When 3.9 lands `ThemeTokens` + `PaletteArcCoordinator`, the HUD migrates to lerp toward climax termini. (1.6 Key Decision #8 + out-of-scope table established this deferral; arch lines 499–501 own these files to 3.9.)

5. **The `health_bar` is world-space (`Node2D`, child of the entity), NOT a Control node on the CanvasLayer.** It is the ONE HUD-listed element that is co-located with the ship (primary read, H4) — it follows the entity. The four overlay readouts (lives/timer/score/modifier) are `Control` nodes on the `CanvasLayer`. Arch line 470 names the file `health_bar.gd` in `components/` (on-ship + on-enemy idiom). Two rendering regimes, both consuming the palette (arch D15 line 312).

6. **Focus/fade dimming in v0.1 = opacity (`modulate.a` ≈ 0.32) on the dimmed chrome; full saturation reduction needs a shader (E8).** AC8 cites "~32% / 0.5 saturation". `modulate` is a Color multiply — it can tint/opacity but not truly desaturate. No shaders exist in-repo (1.6 out-of-scope: neon-vector glow shader = 8.5). For v0.1, opacity-dim on score + modifier chrome carries the visible intent (chrome recedes); wave-timer + lives + on-ship HP stay at full. True saturation + per-component climax tuning mature at E8 (AC8 explicitly: "full per-component saturation tuning + climax integration mature at E8 polish").

7. **The modifier chip is a v0.1 placeholder (E1 has no modifier system).** Modifiers (SWARM/GAUNTLET/BOUNTY) are Epic 5. In E1, `wave-modifier-readout` shows `WAVE N` + a neutral `STANDARD` chip (or the chip hidden). Build the shape-glyph + per-modifier color machinery but leave it dormant (forward-compat, A1: shape-first). Do not invent a modifier signal/data structure — that's E5.

8. **`arc_t_changed` is declared now (forward-compat), emitted by Story 3.9.** Arch line 420 lists it as a bus signal (derived theming state, alongside `score_changed`/`build_changed`). Declaring it now is sanctioned by D13 + the 3.9 sequencing note. The HUD + `health_bar` subscribe; in E1 the handler is calm-only. No emitter, no `PaletteArcCoordinator`, no `theme_tokens.gd` this story.

### 📊 State sourcing map (the critical wiring table — read before writing any update code)

| HUD element | Source of truth | Mechanism (signal-driven, no polling) | Exists today? |
|---|---|---|---|
| `lives-display` (ships) | `RunState.ships` | `EventBus.ship_lost(remaining)` ✓ (arena emits on spend) | ✅ exists |
| `score-readout` | `RunState.score` | `EventBus.score_changed(score)` ✓ (spawner emits on kill) | ✅ exists |
| wave number (`wave-modifier-readout`) | `FormationSpawner._wave_n` / `Arena._wave_num` | **NEW** `EventBus.wave_started(wave, duration_s)` (Task 1.1/2.1) | ❌ ADD |
| `wave-timer` countdown | `FormationSpawner.wave_duration_s` (default **30.0s**) | `wave_started` seeds it; HUD counts down **locally** in `_process` | ❌ ADD signal + local countdown |
| `health_bar` (player + enemies) | `HealthComponent.current_hp/max_hp` | **LOCAL** `HealthComponent.health_changed(cur, max)` — bind intra-entity (D8) | ✅ local (NOT on bus) |
| modifier chip | none (E5) | none — placeholder `STANDARD` in E1 | N/A (Epic 5) |
| palette arc (recolor) | none (Story 3.9) | **NEW** `EventBus.arc_t_changed(t)` — declared now, no emitter until 3.9 | ❌ DECLARE (no emit) |
| focus/fade intensity | hp_ratio + time_remaining (+ 0 for captors/projectiles in E1) | `HudFocusModel.intensity(...)` pure; recompute on events (health_changed, time threshold, wave start/clear) | ❌ BUILD (model + FSM) |

⚠️ **Wave-duration drift:** the spawner's `wave_duration_s` defaults to **30.0s**, but UX T1/H3 + the AC say "60s survive-to-end" (GDD T1: "final duration TBD in playtesting"). The HUD MUST read the actual duration from the `wave_started` signal — **do NOT hardcode 60**. The 30-vs-60 reconciliation is a wave-controller/GDD-tuning concern (Story 1.8 owns the authored-wave feel gate), NOT 1.7's job. Flag for Mrdth (Open Question #2).

### Signal boundary (AR7 / D8)

- **EventBus (global — added this story):** `wave_started(wave: int, duration_s: float)` (past-tense event; arch line 250's "HUD/systems subscribe here" group) + `arc_t_changed(t: float)` (derived read-only theming state; arch line 420). Both typed. Emitters: `FormationSpawner.begin_wave` (wave_started); `PaletteArcCoordinator` [Story 3.9] (arc_t_changed — none in E1). Consumers: HUD + health_bar.
- **Direct/local signals (unchanged):** `HealthComponent.health_changed(current, maximum)` + `died`; `player.ship_depleted`; `enemy.died(score_value)`. The `health_bar` binds to `health_changed` intra-entity; the HUD's focus model read-only-subscribes to the player's `health_changed` via injected ref.
- **Do NOT add** `health_changed` / `player_hit` / `hp_changed` / `wave_changed` (as a bus signal) / `modifier_changed` to the bus. `wave_started` carries the wave number (AC9's "`wave_changed`" intent is satisfied by `wave_started` + the existing `wave_cleared`).
- **Callable connect syntax** (`node.sig.connect(_on_sig)`); typed signals; past-tense for events (`wave_started`, `wave_cleared`), imperative for requests (none added this story).

### Color tokens (calm Vector Standard — UX DESIGN.md frontmatter, verbatim)

Use these in `ui/hud/hud_palette.gd` (and `health_bar` defaults). Climax termini are NOT needed in E1 (arc_t stays 0) — list them as comments for 3.9.

| Token | Hex | Use |
|---|---|---|
| `surface` | `#060912` | HUD chip/timer-opaque-bg (optional) |
| `text` | `#E6F1FF` | timer numeric, primary ink |
| `muted` | `#7E8DAA` | labels (SCORE/WAVE), empty pip stroke, empty HP outline |
| `border` | `#1E2A44` | chip borders |
| `primary` | `#00E5FF` | lit pip stroke, timer suffix/glow, primary neon |
| `primary_hover` | `#5AF7FF` | glow halo |
| `health` | `#4ADE80` | HP segment fill + glow |
| `hazard` | `#FF3D5A` | low-time timer numeric (calm) |
| `score` | `#FFE066` | score numeric + glow |
| `glow` | `#5AF7FF` | neon halo (lit pips, timer, score) |
| `modifier_swarm` / `modifier_gauntlet` / `modifier_bounty` | `#FF3D5A` / `#00E5FF` / `#FFE066` | modifier chips (dormant in E1) |
| neutral white | `#FFFFFF` | low-time timer glow halo (NOT primary — AC5) |

`spacing`: `hud-band` = 58px, `lane-band` = 54px, `margin-frame` = 32px, `title-safe` = 5%. `hp-bar` segment: 10×4px, 3px gap, `rounded.xs` (2px). Typography: `numeric-lg` ~30px bold (score/timer), `numeric-sm` ~13px bold (`×N`), `label-caps` ~11px (labels). All WCAG-AA cleared on `surface` (DESIGN contrast table).

### Gotchas that will bite

- **No `.ttf` in repo; numerics MUST be mono (T2).** See Task 8 + Open Question #1. If you ship Godot's default (non-mono) font on score/timer, digits jitter column-to-column as the value changes — a visible defect. Resolve before finalizing the readouts.
- **`wave_duration_s` is 30s, not 60.** Read it from `wave_started` — never hardcode. (Drift flagged; 1.8 owns the feel gate.)
- **Pooled enemies don't re-fire `_ready`.** The `health_bar` bind on enemies MUST happen in `activate()`/`reset()` (the pool re-init path), not `_ready()` — or the bar shows stale HP after a pool reuse. Guard with `has_node("HealthBar")` so grunts (no bar) don't error. (project-context pooled-node rule; 1.4 pattern.)
- **`_draw()` only on change.** `health_bar._draw` runs only when `queue_redraw()` is called from `_on_health_changed`. Do NOT redraw per frame. Do NOT call `queue_redraw()` in `_process`.
- **Timer label updates: cache the last shown int.** `wave_timer._process` decrements `_remaining` every frame but must only set `label.text` when `ceil(_remaining)` changes — setting text every frame is a per-frame string alloc/format (NFR3 hot-path violation).
- **Camera2D framing is a 1.6 concern, NOT yours.** The HUD `CanvasLayer` renders in screen space — it is independent of the `Camera2D` (added in 1.6). Do not touch the camera; verify framing is unchanged.
- **`wave_started` fires in spawner tests.** `test_formation_spawner.gd` calls `begin_wave`; the new emit is additive — existing asserts ignore it. Verify green (Task 11.5).
- **`godot --headless --import`** after adding `class_name`s/`@export`s/new scenes, or scenes + tests won't resolve types (every prior review flagged this).
- **GUT exit-leak warnings** ("leaked"/"orphan" at exit) are expected since 1.3 — trust Passing/Failing counts, not the exit noise (memory `gut-exit-leak-warnings-expected`).
- **No `print()`** — route through `Log`. No try/catch in GDScript — preconditions + `push_error`/`push_warning` + fail-safe (AR11/AR12).
- **Reduced-motion does NOT disable focus/fade** — it's a slow informational dim, not vestibular motion or a flash. The ≤3 Hz photosensitive cap (1.6) doesn't apply to dimming. `Settings.set_reduced_motion` is untouched this story (its consumer landed in 1.6).

### Out of scope for 1.7 (do NOT build — listed to prevent scope creep)

| Item | Owner | Why deferred |
|---|---|---|
| **`ThemeTokens` / `PaletteArcCoordinator` / `palette_arc.gd`** | Story 3.9 | Requires the build engine (`build_power`); `arc_t` has no emitter until 3.9. HUD uses a calm-only local palette + subscribes to the (dormant) `arc_t_changed`. (1.6 established the deferral.) |
| **Real modifier system** (SWARM/GAUNTLET/BOUNTY data + selection) | Epic 5 | No modifier waves in E1. Chip shows placeholder `STANDARD`. |
| **Currency readout** (`currency-readout`, CHIPS) | Story 3.5 (shop) | Shop-stage only — **never in-wave** (H2, AC3). Do not render `colors.currency` in the HUD. |
| **`build-summary-rail`** (MAIN/WING ladder) | Story 3.x (build screens) | Between-wave only, not in-wave. Surfaces on ship-select + shop. |
| **Floating score popups** (`numeric-xl` kill popups) | Was 1.7-candidate, **defer to E8 polish** | A world/overlay text element; the HUD scaffold lands here but kill popups are polish (not in 1.7 ACs). Emit-site hooks (enemy `_on_died`) exist from 1.6 if pulled forward — but keep 1.7 to the in-band HUD. |
| **Toast system** (`toast_manager`, feat/unlock notifications) | Story 7.5 | Listens for `feat_unlocked`/`unlock_discovered` (no emitters until E7). |
| **Saturation shader for focus/fade** | E8 polish | No shaders in-repo (1.6 deferred glow shader to 8.5). v0.1 uses opacity dim. |
| **Full `ui_theme.tres` + Chakra Petch/Inter/JetBrains-Mono faces** | E8 art pass (8.5) | v0.1 uses fetched OFL fonts or Godot defaults (Task 8). Full type/contrast/Steam-Deck-legibility pass is E8. |
| **Boss HP bar** (top-of-screen, scaled up) | Story 4.5 (final boss) | Same segmented idiom, but bosses don't exist until E4. |
| **D16 world-sprite re-rendering** (bright outlines, shape stamps) | Largely satisfied by existing vector art; matures E2/E8 | 1.7 honors D16 at the HUD layer (shape-glyph chips, segmented HP, neutral-white low-time glow) + VERIFIES existing player/projectile/enemy-fire silhouettes are distinct. Do NOT rebuild the vector renderer (ADR-6) here — `capture-column` (the parallel-bar hazard) is Epic 2. |
| **HP-on-bus / `wave_changed`-on-bus** | Never | D8 violation. HP is entity-local; wave uses `wave_started`+`wave_cleared`. |

### Performance / hot-path (NFR2/NFR3/NFR4/NFR6, AR14)

- **All HUD updates are signal-driven** (`score_changed`, `ship_lost`, `wave_started`, `wave_cleared`, `arc_t_changed`, local `health_changed`) — zero per-frame polling of `RunState`/the bus.
- **Wave-timer countdown** = one float decrement in `_process` + label text set ONLY when the displayed int changes (cache `_last_shown`). No per-frame string format/alloc.
- **`health_bar._draw`** only on `health_changed` (`queue_redraw`) — no per-frame draw, no per-frame `_process`.
- **Focus/fade FSM** recomputes on events (health_changed, time threshold, wave start/clear) or a light throttle — NOT per-frame. The reusable `StateMachine` ticks `_process` to its states; states are no-ops in `process()` (transitions are event-driven via `transition_to`). One cheap branch/frame.
- **Cache every node ref** `@onready`; inject the player ref from Arena (no `find_child`/`get_node`/`$` per frame).
- **No per-frame `Dictionary`/`Array`/`Vector2` allocations** in any `_process` (NFR3).

### Testing (GUT — mirror the 1.3–1.6 patterns)

- `extends GutTest`; `before_each()` calls `Pool.clear()` (Pool is an autoload — state leaks across tests).
- `tests/ui/` mirrors `ui/` (was empty). `tests/components/test_health_bar.gd` joins the existing `tests/components/` (state_machine, health_component).
- `tests/ui/test_hud_focus_model.gd` is a **pure unit test** (no scene) — the canonical one arch line 545 names.
- Scene/integration tests: instantiate via `.instantiate()`; use plain `add_child` (NOT `autofree`) for scene + pooled nodes (GUT shouldn't free a node the Pool still holds — `test_enemy_projectile.gd:65` precedent).
- Tween/timer/countdown assertions: `await get_tree().physics_frame` in loops (manual stepping doesn't advance engine timers reliably).
- **Regression:** all 1.1–1.6 tests stay green (1.6 baseline: 20 scripts, 144 tests, 431 asserts). The new `wave_started` emit must not break `test_formation_spawner.gd`; the new `HealthBar` child on the player must not break `test_player_*.gd` / `test_arena.gd`.

### Project Structure Notes

- **Co-located by domain (Option A):** new files live in `ui/hud/` (the HUD domain — arch lines 516–521) + `components/health_bar.*` (arch line 470). `tests/ui/` + `tests/components/` mirror them.
- `ui/hud/` intended contents after this story: `hud.tscn`/`hud.gd`, `lives_display.*`, `wave_timer.*`, `score_readout.*`, `wave_modifier_readout.*`, `hud_focus_model.gd`, `hud_palette.gd`, `states/standard_state.gd` + `focus_fade_state.gd`. (**NOT** `build_summary_rail.tscn` — between-wave, Story 3.x; **NOT** `theme_tokens`/`palette_arc` — Story 3.9.)
- `components/health_bar.gd` + `.tscn` — the reusable segmented bar (Node2D). Named `health_bar` (arch line 470), NOT `hp_bar`.
- Modified files: `systems/event_bus.gd` (+2 signals), `world/formation_spawner.gd` (+1 emit line in `begin_wave`), `world/arena.tscn` (+HUD instance), `world/arena.gd` (+inject player ref to HUD, +optional seed), `player/player.tscn` (+HealthBar child), `player/player.gd` (+bind call), `enemies/shielder.tscn` + `bomber.tscn` (+HealthBar child), `enemies/enemy.gd` (+bind in activate/reset, guarded). `assets/fonts/*` if fetched (Task 8).
- **Read-only (do not change behavior):** `run/run_state.gd`, `components/health_component.gd`, `components/state_machine/*`, `systems/constants.gd`, `juice/*` (all of it — 1.6's, including the Camera2D), `world/formation_spawner.gd` mechanics (only ADD the emit).
- The HUD is **not** added to the autoload registry (verify `project.godot`'s 11 autoloads unchanged).
- Naming: scripts `snake_case.gd` (`hud.gd`), `class_name PascalCase` (`Hud`), signals `snake_case` (`wave_started`), constants `UPPER_SNAKE`. One root + one script per scene.

### Project Context Rules

*(Extracted from `_bmad-output/project-context.md` — follow exactly. When a rule conflicts with a design intent, flag Mrdth.)*

- **Engine:** Godot 4.6 (`config_version=5`, GDScript). Pin to 4.6.x; avoid 4.7-only APIs. **2D** (`Node2D`/`CharacterBody2D`/`Area2D`/`CanvasLayer`/`Control`); Compatibility renderer. Ignore the 3D/Forward+/Jolt defaults in `project.godot` — inert.
- **UI = Control nodes on a CanvasLayer, separate from the world tree (UX D1/F3, arch D10):** the HUD must never obscure the 1-axis play lane. Critical errors fail-safe to menu, never hard-crash (F9).
- **Stretch:** `canvas_items` + `expand` at base 1280×720 (already set — `project.godot` lines 36–37). Design HUD at base res; anchor corners stay fixed (H5); keep combat-critical HUD inside `title-safe` 5% (F4).
- **Signal boundary (AR7/D8):** typed signals; past-tense for events (`wave_started`, `wave_cleared`), imperative for requests. Callable connect syntax. Global game-flow → `EventBus`; intra-entity (HP) → direct signals. Derived read-only state (`arc_t_changed`) also rides the bus (arch line 415).
- **Node lifecycle:** cache refs `@onready` (never `$`/`get_node()` in `_process`). Pooled nodes re-init via `activate()`/`reset()`, NOT `_ready()` — the enemy `health_bar` binds in `activate()`. Prefer scene-unique `%Name` or injected refs over `../../X`.
- **Hot-path discipline (NFR3/AR14):** no per-frame allocations; `queue_redraw()` only when state changes; cache everything; `set_process(false)` when idle (the wave-timer can disable `_process` when stopped).
- **Static typing throughout (NFR7):** `var hp: int`, `func set_score(v: int) -> void`, typed arrays; `@export`/`@export_range`/`@export_group` for tunables.
- **No `print()` / no try-catch (AR11/AR12/NFR7):** route through `Log`; preconditions + `push_error`/`push_warning` + fail-safe; `assert` for dev-only invariants.
- **Object pooling (AR6/D7/NFR4):** irrelevant to HUD readouts (they persist for the wave), but the enemy `health_bar` rides on pooled enemies — bind in `activate()`, never `queue_free()` the bar.
- **Composition over inheritance; strict collision layers:** the `health_bar` is a visual child on NO collision layer/mask (pure draw). The HUD CanvasLayer participates in no physics.
- **Content via resources (AR8/D9/AR10):** tuning (focus thresholds, hp-bar geometry, low-time threshold) in `.tres` or `Constants`/`HudPalette` consts — not magic numbers in code. No `load("res://...")` in gameplay code; `preload` once or `@export`.

### References

- **Story spec:** `planning-artifacts/epics.md` — Story 1.7 (lines 388–406); FR46 basic HUD (line 110), FR49 (score); UX enrichment note (lines 159–167); Epic 1 FR set (line 235).
- **UX (source of truth for HUD):** `planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/`
  - `DESIGN.md` — frontmatter tokens (colors/typography/spacing/components, lines 9–103); HUD component specs `lives-display`/`wave-timer`/`score-readout`/`wave-modifier-readout`/`hp-bar` (lines 364–393); Layout & Spacing — hud-band/lane-band/title-safe (lines 292–313); Color-safety core A2 (lines 199–218); Contrast targets A1 (lines 236–252); Do's and Don'ts (lines 504–545). `mockups/key-hud.html` is supporting evidence — **spines win on conflict** (line 112).
  - `EXPERIENCE.md` — HUD info hierarchy H4/H5 (lines 81–89); Component Patterns HUD (lines 121–163); State Patterns — in-wave HUD `standard`/`focus-fade` (lines 217–221); HUD & Diegetic UI D1/F3/S1 (lines 376–407); Accessibility Floor A1 (lines 267–293).
  - `.decision-log.md` — canonical (D1/F3/H2/H3/H4/H5/H6/T1/S1/A2/V3 keys).
- **Architecture:** `planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md` — D10 UI (line 264–266), D13 palette arc + `arc_t_changed` (lines 270–289, 420), D15 UI 24-component map + HUD focus/fade FSM spec (lines 306–323 — **line 321 is the canonical focus-model signature**), D16 shape+outline (lines 327–329); `res://` tree `ui/hud/` (lines 516–521) + `components/health_bar.gd` (line 470) + `juice/theme_tokens.gd` etc. (lines 499–501 — **Story 3.9, do not create**); autoload registry unchanged (line 554–556); system-location UI/HUD row (line 571); EventBus conventions (lines 413–422).
- **Project context:** `_bmad-output/project-context.md` — "Put UI/HUD on a CanvasLayer, separate from the world tree" (line 118); signal boundary (lines 50–53); node lifecycle/pooling (lines 72–75, 111–112); hot-path discipline (lines 105–109); `queue_redraw()` only on change (line 117).
- **GDD:** `planning-artifacts/gdds/gdd-meridian-run-2026-06-29/gdd.md` — FR46 HUD/score (line ~110), FR49 score display-only, NFR11 neon-vector; T1 wave-timer "60s survive-to-end, final duration TBD in playtesting".
- **Prior stories (read before implementing):**
  - `implementation-artifacts/1-6-hit-feedback-and-juice.md` — **direct predecessor.** The arena-scoped-coordinator pattern (JuiceCoordinator), EventBus signal-discipline, the `arc_t`/`ThemeTokens` deferral (Key Decision #8 + out-of-scope), reduced-motion wiring, Camera2D framing, the "synthesize/procedural not binary-asset" precedent (fonts ≈ audio/particle-texture analog), GUT patterns. Its File List is the code you extend.
  - `implementation-artifacts/1-5-life-and-health-economy.md` — `RunState` (ships/score), `HealthComponent.health_changed`/`died`/`reset_to_full`, `Arena` run-host flow (`_on_player_ship_depleted` → `ship_lost`, `_on_wave_cleared` → heal + next wave), the wave-economy baseline (do not regress).
  - `implementation-artifacts/1-4-enemy-types-and-formation-dive-ai.md` — node-name `HealthComponent` lookup (key decision #2), pooled-enemy `activate()`/`reset()` re-init (where the enemy `health_bar` bind goes), `FormationSpawner` (`begin_wave`/`wave_duration_s`/`_wave_time`/`wave_cleared`).
  - `implementation-artifacts/1-3-vertical-fire-system.md` — "zero per-frame allocations" structural-test precedent (apply to wave-timer).
  - `implementation-artifacts/1-2-player-movement-1-axis-chassis.md` — `CharacterBody2D` + component wiring; the tuning `.gd`+`.tres` pair.
  - `implementation-artifacts/1-1-project-scaffolding-and-core-systems.md` — `Constants` (`BASE_SHIPS`/`MAX_SHIPS`/`BASE_HP`/`BASE_RESOLUTION`), `EventBus` declarations, `Settings` ConfigFile, GUT setup, the 11-autoload registry.
- **Code to read/edit (read fully before editing):**
  - `systems/event_bus.gd` (add `wave_started` + `arc_t_changed` — currently 6 game-flow + 3 juice signals), `world/formation_spawner.gd` (`begin_wave` — add the `wave_started` emit; understand `wave_duration_s`/`_wave_time`/`wave_cleared`), `world/arena.tscn` (add HUD instance) + `world/arena.gd` (`_ready` — inject player ref to HUD; understand the run-host flow you must not regress).
  - `player/player.tscn` (+`HealthBar` child) + `player/player.gd` (`_ready` — bind; do not regress i-frame flicker), `enemies/enemy.gd` (`activate()`/`reset()` — guarded bind), `enemies/shielder.tscn` + `bomber.tscn` (+`HealthBar`), `enemies/grunt.tscn` (NO bar).
  - `components/health_component.gd` (**read only** — `health_changed`/`max_hp`/`current_hp`/`reset_to_full`), `components/state_machine/state_machine.gd` + `state.gd` (**read only** — the reusable FSM you drive), `run/run_state.gd` (**read only** — ships/score access), `systems/constants.gd` (**read only** — `BASE_SHIPS`/`MAX_SHIPS`/`BASE_RESOLUTION`), `systems/settings.gd` (**read only** — `get_reduced_motion` exists).
  - `juice/juice_coordinator.gd` — **the pattern to mirror** for an arena-scoped EventBus-driven conductor. `tests/juice/test_juice_coordinator.gd` — integration-test pattern to mirror.
- **Deferred work log:** `implementation-artifacts/deferred-work.md` — the grunt-HP-vs-"1-hit" tuning + the `_motion_scale` wording may recur; log any new landmines here.

---

## Open design questions for Mrdth (review before dev — defaults are safe to implement as-is)

These are the consequential forks resolved with documented defaults above. They are safe to implement as written; flagged only so Mrdth can veto before `dev-story` runs.

1. **Fonts: fetch OFL `.ttf` via `curl`, or ship Godot defaults?** `assets/` has no fonts; UX mandates Chakra Petch / Inter / **JetBrains Mono** (mono numerics are non-negotiable — T2, or digits jitter). An AI dev CAN download OFL binaries (unlike authoring them). *(Default: `curl` JetBrains Mono at minimum into `assets/fonts/` + commit the OFL license; optionally Chakra Petch + Inter for full fidelity. Fallback if no network: Godot default font + a mono fallback path for numerics, with a documented "real faces at E8" deviation. The neon read comes primarily from color/size/glow, so the default font is acceptable for body/display; only the numeric face is load-bearing.)*
2. **Wave timer: 30s or 60s?** Spawner `wave_duration_s` defaults to **30.0**; UX T1/H3 + the AC say "60s" (GDD: "final duration TBD in playtesting"). *(Default: the HUD reads the actual duration from `wave_started` — it displays whatever the spawner says (30s today). Do NOT hardcode 60. The 30-vs-60 reconciliation is Story 1.8's authored-wave feel gate, not 1.7's. Flagged so Mrdth can pre-decide before 1.8.)*
3. **Grunt: 1-hit (no bar) or 3-hit (bar)?** AC4 says the segmented bar is "absent on 1-hit grunts", but current tuning makes Grunt 30 HP / player 10 dmg = **3-hit**. *(Default: honor the AC intent — no bar on Grunt; bar on Shielder (50 HP) + Bomber (80 HP), hidden at full HP. The discrepancy is a GDD/tuning drift — either the grunt is meant to be chaff that dies fast at higher build power, or its HP should drop. Non-blocking for 1.7; flag for Mrdth to reconcile at the 1.8 tuning pass.)*
4. **Focus/fade: opacity-only dim (v0.1) acceptable?** True ~0.5 saturation needs a shader (none in-repo). *(Default: v0.1 dims score + modifier chrome via `modulate.a ≈ 0.32` (opacity); full saturation reduction + per-component climax tuning mature at E8. AC8 explicitly sanctions "v0.1 baseline: FSM + model exist and transition; full tuning at E8.")*
5. **Modifier chip in E1: `STANDARD` placeholder vs hidden?** No modifier system until Epic 5. *(Default: show `WAVE N` + a neutral `STANDARD` chip so the layout reads complete and the shape-glyph machinery is built but dormant. Dev may hide the chip if the placeholder reads as clutter.)*

---

## Change Log

- 2026-07-05 — Story 1.7 implemented (Basic HUD): arena-scoped `CanvasLayer` HUD (lives / wave-timer / score / wave+modifier) + reusable segmented `HealthBar` on the player + Shielder/Bomber; `wave_started` + `arc_t_changed` on `EventBus`; pure `HudFocusModel` + focus/fade FSM; calm-only `HudPalette` + JetBrains Mono numerics. 180/180 tests pass (30 new). Status → review.
- 2026-07-05 — Two review-driven fixes (playtest feedback): (1) **wave-timer was rendering mid-screen** — `Safe` was `PRESET_FULL_RECT` so the band stretched the full viewport and the chrome centered vertically; pinned `Safe` to a top band (`HUD_BAND + 16` px) + gave readouts `size_flags_vertical = EXPAND_FILL` so content lands in the top band. (2) **enemy HP bar showed raw HP** (50–80 segments) — added `hp_per_segment` to `HealthBar` so it renders `ceil(hp / hp_per_segment)` segments = "shots to kill"; player keeps 1 HP/segment (3), enemies use 10 HP/segment (Shielder 5, Bomber 8), mirroring `player_tuning.projectile_damage`. +5 tests (185/185 pass).
- 2026-07-05 — Three more layout fixes (playtest feedback): (1) **lives showed phantom un-earned pips** — pip row was `MAX_SHIPS` (5); changed to `BASE_SHIPS` (3) so only earned/held lives render (lost pips still dim-and-stay for the gamble read). Deviates from UX S1's "max-ships visible" at Mrdth's request (see deferred-work). (2) **timer off screen-center** + (3) **score/wave off-screen right** — replaced the single HBox+spacers (which centered the timer *between* the unequal-width side columns and let the right column drift) with **independent corner/center anchoring**: each readout point-anchored left / horizontal-mid / right with `GrowDirection` END/BOTH/BEGIN at natural size. +1 test (186/186 pass).
- 2026-07-05 — Two more (playtest feedback): (1) removed the `SURVIVE` eyebrow from `wave-timer` (the `60s` countdown stands alone). (2) **score STILL off-screen right** — the `GrowDirection` approach left the right `VBox` zero-width at the anchor and its children overflowed off-screen; switched the three HUD zones to **explicit fixed-width anchored boxes** (`_SIDE_W` 220 / `_TIMER_W` 180) with definite `offset_left`+`offset_right`, so the right zone is a real 220px box pinned flush to the right margin and the score right-aligns inside it. 186/186 pass.
- 2026-07-05 — HUD staircase fix (playtest feedback, see docs/HUD.png): the three zones shared the same vertical rect but their CONTENT was aligned differently inside it — lives at top (`_draw`), timer `ALIGNMENT_CENTER` (mid), score column `ALIGNMENT_END` (bottom) ⇒ each element sat lower than the one to its left. (1) removed the `SCORE` eyebrow so the value sits at the top with wave info beneath. (2) top-anchored every readout VBox to `ALIGNMENT_BEGIN` (`wave_timer`, `score_readout`, `wave_modifier_readout` internal cols + the `score_col` container) so lives / timer / score all start at the top of the band — no stair-step. 186/186 pass.
- 2026-07-05 — Wave info overlaid the score (playtest feedback): the right column didn't have enough vertical room — score value (numeric-lg ~36px) + wave readout (two STACKED labels ~33px) + separation ≈ 71px exceeded the 56px zone, so the VBox compressed its children and they collided. Fix: `wave_modifier_readout` is now a single HBox ROW (`WAVE N` + chip side by side) instead of two stacked labels ⇒ the right column = score value above + one row beneath ≈ 53px. Bumped `_BAND_HEIGHT_PX` 56 → 64 for headroom. 186/186 pass.

## Dev Agent Record

### Agent Model Used

Claude Code (GLM-5.2[1m] per session environment)

### Debug Log References

- Headless import + GUT, iterative. First full run surfaced one parse error: `BoxContainer.ALIGNMENT_SEPARATE` does not exist in Godot 4 (only BEGIN/CENTER/END) — `ui/hud/hud.gd:71`. Replaced the HBox spread with two `SIZE_EXPAND_FILL` spacer Controls (the space-between idiom). The error had cascaded into an `arena.gd` compile failure + 6 transient test failures (all downstream of the HUD script not loading); the single fix cleared them.
- Refined `HudFocusModel.intensity` mid-implementation: the original linear HP ramp contributed ~0.02 at 1/3 HP (meaningless for E1's discrete 3-HP player), so the HP axis is now a clean binary "critical-HP ⇒ max" gate. Also added `WaveTimer.is_running()` + a sentinel in `Hud._recompute_focus` so an unstarted timer (`_remaining == 0`) doesn't falsely read as "time up".
- Final GUT: `godot --headless -s addons/gut/gut_cmdln.gd` → **23 scripts, 180/180 tests pass, 511 asserts** (0 regressions vs the 1.1–1.6 baseline of 150).
- Headless game boot (`godot --headless --path .`, main scene): clean — no runtime errors; arena boots with the HUD. Autoload registry unchanged at 11.

### Completion Notes List

- **All 9 ACs satisfied.** HUD is a non-diegetic `CanvasLayer` child of the Arena (AC1/D1/F3) — never over the lane (top band only). Layout: lives top-left, wave-timer top-center, score + wave/modifier top-right (AC2/H5). Score-only, no currency in-wave (AC3/H2). Segmented `HealthBar` above the player ship + reused on Shielder/Bomber, hidden at full HP, absent on grunt (AC4/H6) — ring reserved for Shield. Wave-timer low-time → HAZARD numeric + neutral-white glow path (AC5/T1). Player-vs-hazard shape read honored at the HUD layer (segmented HP, shape-glyph modifier chip, neutral-white low-time glow — AC6/A2/D16); world-sprite shapes left as-is (mature E2/E8). `arc_t_changed` subscribed everywhere, calm-only in E1 (AC7/D13). Focus/fade FSM + pure `HudFocusModel` transition on low HP / low time; score+modifier dim, timer+HP+lives sharp (AC8/S1/D15). All updates signal-driven (AC9).
- **Decisions resolved as written:** HUD is arena-scoped (twin to `JuiceCoordinator`), not an autoload (registry stays 11). `wave_started(wave, duration_s)` is a NEW bus signal emitted by the spawner (symmetric with `wave_cleared`); the timer counts down locally (no per-frame polling). HP stays off the bus — `HealthBar` binds intra-entity (D8); the HUD read-only-subscribes to the player's `HealthComponent` for the focus model. `ThemeTokens`/`PaletteArc` NOT created (Story 3.9) — calm-only `HudPalette` + dormant `arc_t_changed` subscription. Fonts: fetched OFL JetBrains Mono for numerics (T2); display/body use Godot's default face for v0.1 (E8 art pass owns the rest).
- **Deferred (see `deferred-work.md` "Story 1.7" section):** wave-duration 30s-vs-60s reconciliation (1.8); grunt-3-hit-vs-"1-hit" tuning (1.8); focus/fade saturation shader (E8); full type system Chakra Petch/Inter (8.5); `ThemeTokens`/`PaletteArc` (3.9); HP-axis gradation (E2/E8).

### File List

**New (21):**
- `ui/hud/hud.gd`, `ui/hud/hud.tscn` — CanvasLayer conductor + focus/fade FSM host
- `ui/hud/hud_palette.gd` — calm Vector Standard color/spacing/type consts (temporary spine; 3.9's ThemeTokens replaces)
- `ui/hud/hud_fonts.gd` — lazy JetBrains Mono cache + `make_label` factory
- `ui/hud/hud_focus_model.gd` — PURE intensity model + hysteresis gate
- `ui/hud/lives_display.gd` + `.tscn` — ship-icon pip row + ×N
- `ui/hud/wave_timer.gd` + `.tscn` — local survive-to-end countdown + low-time color
- `ui/hud/score_readout.gd` + `.tscn` — SCORE eyebrow + value
- `ui/hud/wave_modifier_readout.gd` + `.tscn` — WAVE N + STANDARD chip placeholder
- `ui/hud/states/standard_state.gd`, `ui/hud/states/focus_fade_state.gd` — focus/fade FSM states (reusable StateMachine)
- `components/health_bar.gd` + `components/health_bar.tscn` — reusable segmented HP bar (Node2D, on-ship + on-enemy)
- `assets/fonts/JetBrainsMono-Regular.ttf`, `assets/fonts/JetBrainsMono-Bold.ttf`, `assets/fonts/OFL.txt` — OFL fonts (mono numerics)
- `tests/ui/test_hud_focus_model.gd` — pure model unit tests
- `tests/ui/test_hud.gd` — HUD conductor integration tests
- `tests/components/test_health_bar.gd` — health bar integration tests

**Modified (10):**
- `systems/event_bus.gd` — +`wave_started(wave, duration_s)`, +`arc_t_changed(t)`
- `world/formation_spawner.gd` — emit `wave_started` in `begin_wave()`
- `world/arena.tscn` — +HUD instance; `world/arena.gd` — +`_hud` ref + `set_player(_player)` inject
- `player/player.tscn` — +`HealthBar` child; `player/player.gd` — +`_health_bar` ref + bind in `_ready`
- `enemies/shielder.tscn`, `enemies/bomber.tscn` — +`HealthBar` child (hide_when_full); `enemies/enemy.gd` — +`_health_bar` ref + guarded bind in `activate()`
- `_bmad-output/implementation-artifacts/deferred-work.md` — +Story 1.7 deferrals section

**Deleted (2):** `ui/.gdkeep`, `tests/ui/.gdkeep` (folders now hold real content)
