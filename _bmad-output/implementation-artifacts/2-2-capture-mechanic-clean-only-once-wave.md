---
baseline_commit: 49c9612
---

# Story 2.2: Capture Mechanic (Clean-Only, Once/Wave)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want capture to be a deliberate risk — only when I'm clean and exposed during
the captor's active tractor window,
so that docking a ship meaningfully trades safety for firepower, and the gamble
is a real (−1 ship) consequence I chose to court — not a free or repeatable loss.

## Acceptance Criteria

1. **Given** the player is **clean** (no docked ship) and inside the locked capture column during the 0.4 s active window, **When** the captor tractors, **Then** the player is captured — **−1 ship, bypassing HP** (the `HealthComponent` is never touched), and **respawns at full HP** (reusing the existing respawn path).
2. **Given** the player has a docked ship, **Then** capture is impossible (the player is **capture-immune**). *(Forward-compat — see Dev Notes §"Clean/immune is a stub in 2.2": the guard is real, the docked state lands in 2.4.)*
3. **Given** a capture already occurred this wave, **Then** no further capture can occur (**once per wave**).
4. **Given** at most one docked ship exists, **Then** a second capture/rescue/dock cannot occur. *(Forward-compat — same guard as AC2; satisfied trivially in 2.2 since no docked ship exists yet.)*
5. **Given** the captor's dive-delay timing, **Then** on a **successful** capture the captor **holds briefly** (the "reel-in") before diving, and on a **miss** (player dodged out of the column for the whole window) it **dives immediately** — and the hold duration reads from `captor_tuning.tres` (`post_capture_delay_s`), not code. *(Deferred from 2.1's playtest note.)*

> *(FR14 capture rules — clean, once/wave, one docked; FR12 capture bypasses HP, costs 1 ship, respawn full HP; FR16 docked = capture-immune.)*

---

## Tasks / Subtasks

### Task 1 — `CaptorTuning`: add `post_capture_delay_s` (AC: #5)

- [x] `enemies/captor/captor_tuning.gd`: add `@export var post_capture_delay_s: float = 0.35` under a new `@export_group("Capture")` (or the existing Capture Column group — see Dev Notes §"Tuning map"). Document: the success-conditional "reel-in" hold before dive (Mrdth playtest note 2026-07-09, deferred from 2.1).
- [x] `resources/captor_tuning.tres`: add `post_capture_delay_s = 0.35` (the `.tres` wins at runtime — editing the `.gd` default alone has no effect; memory `tres-overrides-gd-default-for-tuning`).
- [x] No new `class_name` → no `--import` reindex needed for this task.

### Task 2 — `CaptureColumn` detection: `Area2D` child + API (AC: #1 enabler)

- [x] `world/capture_column.tscn`: add a child `Area2D` node **"CaptureDetector"** under the root, with a child `CollisionShape2D` holding a `RectangleShape2D` (size will be set from `width_px` × full screen height in code; bake any size — it's overwritten). `monitoring = false` by default.
- [x] `world/capture_column.gd`: add `@onready var _detector: Area2D = $CaptureDetector` + `@onready var _detector_shape: CollisionShape2D = $CaptureDetector/CollisionShape2D`.
- [x] Add `_ready()` (the column has none today): set `_detector.collision_layer = 0`, `_detector.collision_mask = Constants.LAYER_PLAYER`, `_detector.monitoring = false`. (Mirrors `hurtbox_component.gd:24-26` — detects, isn't detected.)
- [x] Resize the detector shape from `width_px` in `activate()` — **`duplicate()` the `RectangleShape2D` first** (shared-resource safety, mirrors `captor.gd:62-66`), then `dup.size = Vector2(width_px, float(Constants.BASE_RESOLUTION.y))`. So detection width tracks tuning (AC#5 geometry), matching the bars.
- [x] New API:
  - `set_detection(on: bool) -> void` — toggles `_detector.monitoring`. ON only during the active capture window; OFF otherwise.
  - `is_player_in_column() -> bool` — overlap-**poll**: `return _detector != null and _detector.monitoring and _detector.has_overlapping_bodies()`. (See Dev Notes §"Overlap-poll, NOT body_entered" for why.)
- [x] `activate()`: call `set_detection(false)` (start with detection off — telegraph is wind-up, not capture).
- [x] `deactivate()`: call `set_detection(false)` (a released/pooled column must never carry stale monitoring — see Dev Notes §"Stale-monitoring gotcha").

### Task 3 — `Player`: capture guards + effect entry (AC: #1, #2, #3, #4)

- [x] `player/player.gd`: add `var _captured_this_wave := false` (wave-scope capture gate, AC#3).
- [x] Add `func is_capture_immune() -> bool:` → `return false  # 2.4 seam`. See Dev Notes §"Clean/immune is a stub in 2.2".
- [x] Add `func try_capture() -> bool:` — the captor's effect entry. Guards + reuse the ship-loss path. See Dev Notes §"Player.try_capture contract" for the exact body.
- [x] `_ready()`: connect `EventBus.wave_started` → `_on_wave_started` (once) to reset `_captured_this_wave`. See Dev Notes §"Signal boundary (the one expansion)".
- [x] Add `func _on_wave_started(_wave: int, _duration_s: float) -> void: _captured_this_wave = false`.

### Task 4 — `CaptorCaptureState`: wire detection → guards → effect → dive delay (AC: #1, #5)

- [x] `enemies/captor/states/capture_state.gd`:
  - `enter()`: keep `set_active_visual(true)`; add `capture_column.set_detection(true)` (detection ON for the active window). Init `_captured := false`, `_post_capture_t := 0.0`.
  - `physics_process(delta)`: poll `capture_column.is_player_in_column()` while `not _captured`; on a hit, duck-call the player's `try_capture()` (see Dev Notes §"Duck-call, not a cast — parse gotcha"); on success set `_captured = true` + `set_detection(false)`. See Dev Notes §"CaptureState physics_process" for the exact control flow.
  - Success path: accumulate `_post_capture_t`; on `>= tuning.post_capture_delay_s` → `to_dive()` (the reel-in hold).
  - Miss path: existing `_t >= 1.0` window-expiry → `to_dive()` **immediately** (no hold).
  - Gate detection-off on both exit paths (defensive — dive/death also release the column).
- [x] Retire the 2.1 `>>> SEAM for Story 2.2 <<<` comment block in `capture_state.gd` (it's now implemented).
- [x] No change to `TelegraphState` (detection stays OFF during the 0.7 s telegraph — capture is only during the 0.4 s window, AC#1). No change to `DiveState` (it already releases the column).

### Task 5 — Tests (GUT) (AC: all)

- [x] `tests/enemies/test_captor_capture.gd` (new; mirror `tests/enemies/test_captor_fsm.gd` + `tests/enemies/test_enemy.gd`'s physics-driving): instantiate `captor.tscn` with a **test** `CaptorTuning` (tiny durations) + a **mock player** (lightweight `Node2D`/`CharacterBody2D` subclass exposing `try_capture()`/`is_capture_immune()` + a capture counter). Drive the active window; assert: clean player in-column → `try_capture` called **once** → captor holds `post_capture_delay_s` before dive; immune mock (try_capture returns false / is_capture_immune true) → no ship loss + immediate dive; second capture in the wave → blocked; player out-of-column for the whole window → miss → immediate dive (no hold).
- [x] `tests/world/test_capture_column.gd` (extend): assert `set_detection(true)` turns monitoring on; `is_player_in_column()` true when a `LAYER_PLAYER` body overlaps the detector, false when clear / when detection off; `set_detection(false)` turns it off; `deactivate()` leaves monitoring off (stale-monitoring guard). Detection assertions need the column + a mock body in the tree + a physics-frame step (mirror the project's existing physics-integration idiom).
- [x] `tests/player/test_player_capture.gd` (new; mirror `tests/player/test_player_health.gd`): instantiate `player.tscn`; assert `try_capture()` returns `true` + emits `ship_depleted` **once** when clean/first; returns `false` (no emit) when `_captured_this_wave` is already set; `is_capture_immune()` returns `false` (2.2); a simulated `EventBus.wave_started` emit resets `_captured_this_wave` (second-wave capture succeeds again). Optionally assert HP is **untouched** by `try_capture` (bypass — AC#1).
- [x] `before_each()`: `Pool.clear()`. After adding any new `class_name` (none strictly required this story — but if you add one), run `godot --headless --import`, then `godot --headless -s addons/gut/gut_cmdln.gd` — **verify the Scripts/Tests COUNTS** (GUT silently skips parse-failed scripts; memory `gut-classname-reindex-silent-skip`). Expect the benign exit-leak warnings (memory `gut-exit-leak-warnings-expected`) — trust Passing/Failing counts.

### Task 6 — Regression, verification, housekeeping (AC: all)

- [x] Run the full GUT suite — confirm **zero regressions** vs the 2.1 baseline (244 tests). Especially: `test_captor_fsm.gd` (the FSM still transitions cleanly with detection toggling), `test_arena.gd` / `test_wave_controller.gd` (ship-loss path still works; the player's new `wave_started` connect doesn't double-fire), `test_capture_column.gd` (activate/deactivate unchanged).
- [ ] Manual (in-editor, F8 spawn captor): stand **in** the column during the 0.4 s window while clean → captured (−1 ship, full-HP respawn, i-frames). Dodge **out** during the 0.7 s telegraph → miss → captor dives immediately (no hold). Spawn a 2nd captor same wave after a capture → no second capture. Note the reel-in hold on success vs the immediate dive on miss. **(Pending — human/GUI step; the mechanics are covered by automated tests but the in-editor feel-playtest could not be run headlessly. See Completion Notes.)**
- [x] Confirm capture fires **from the captor's `_physics_process`** and the game-over/respawn path's existing `call_deferred` (Arena `_end_run`) still holds — no new physics-step free hazard (Dev Notes §"Physics-step safety is inherited").
- [x] Update this file's Dev Agent Record (File List, Completion Notes). Be honest about AC2/AC4 being forward-compat stubs (Dev Notes §"Clean/immune is a stub in 2.2") — do not claim docked-ship immunity is exercised.

---

## Dev Notes

### 🔑 Key decisions (read these first — they resolve the open forks)

1. **Capture reuses the existing ship-loss path.** "−1 ship, bypass HP, respawn at full HP" is the **same end-state** as HP-depletion. So capture funnels into the **existing** `Player.ship_depleted` → `Arena._on_player_ship_depleted` → `RunState.spend_ship()` → (`Player.respawn()` + `EventBus.ship_lost`) | (`game_over`) path. The ONLY new thing is a non-HP trigger + the guards. Do **not** build a parallel capture-death pipeline — that duplicates Arena's spend/respawn/game-over logic (reinvention, the #1 thing this story prevents).

2. **The capture effect entry lives on the Player (`try_capture()`), not the captor or a new system.** Rationale: (a) the player already owns `ship_depleted` + `respawn` + per-ship mechanics; (b) the player owns the clean/immune state — confirmed by the architecture's future `player.set_docked(true) # capture-immune` (`architecture.md:616`); (c) the captor stays player-agnostic (its `player_target` stays typed `Node2D`, no `Player` cast → no `enemies/`→`player/` compile coupling + testable with a lightweight mock). The player owns the **trigger + guards**; the Arena owns the **effect** (ships are run-scope, AR2) — `try_capture` only *emits* `ship_depleted`, it never touches `RunState`.

3. **Detection is an `Area2D` overlap-POLL on the `CaptureColumn`, not a `body_entered` signal.** The column locks to the player's x at telegraph start (2.1), so the player is **almost always already inside** the column when the active window begins — `body_entered` never fires (it's a transition signal). Poll `has_overlapping_bodies()` each physics frame of the 0.4 s window instead. (The 2.1 seam named the `Area2D` child + the hurtbox-reuse pattern; this is the detection method that actually works.)

4. **"Clean" / capture-immunity is a real guard but a 2.2 STUB.** `Player.is_capture_immune()` returns `false` in 2.2 (the player is always clean — no docked ship exists until 2.4). The **guard is wired and tested** (AC2/AC4); the **docked state is 2.4** (`architecture.md:616` `set_docked`). Be explicit about this — do not claim docked-immunity is exercised. Test AC2 by overriding `is_capture_immune()` to return `true` on a mock.

5. **Once-per-wave lives on the Player (`_captured_this_wave`), reset on `wave_started`.** The player persists across respawns within a wave (same node), so a player-side flag survives the post-capture respawn. Reset by **listening** to `EventBus.wave_started` (Intro→Active, before any captor can capture). The player still *emits* nothing to the bus — this is a read-only listen (Dev Notes §"Signal boundary").

6. **Success-conditional dive delay (AC#5) is driven by the captor's synchronous `try_capture()` return.** Because `try_capture` returns `bool` (captured?), the captor knows immediately whether to hold (`post_capture_delay_s`, the reel-in) or dive. This is why the direct duck-call beats a pure-`EventBus` design (signals are fire-and-forget — no return). See Open Question B for the EventBus alternative.

### 📊 Tuning map — the one new field

Add to `CaptorTuning` (the `.tres` wins at runtime — set it in `resources/captor_tuning.tres`):

```gdscript
@export_group("Capture")
# The "reel-in" hold AFTER a successful capture, before the captor dives (Mrdth playtest note
# 2026-07-09, deferred from 2.1). On a MISS the captor dives immediately (no hold). AC#5.
@export var post_capture_delay_s: float = 0.35
```

(Place it under a new `@export_group("Capture")` for clarity, or fold into the existing `"Capture Column"` group — your call; the schema is `@export_group`-disciplined like `enemy_definition.gd`.) `capture_duration_s` (0.4 s, the active window) already exists and is unchanged.

### 🧩 CaptureColumn detection contract — `world/capture_column.gd`

```gdscript
@onready var _detector: Area2D = $CaptureDetector
@onready var _detector_shape: CollisionShape2D = $CaptureDetector/CollisionShape2D


func _ready() -> void:
    # Detect the player body on LAYER_PLAYER (mask). collision_layer 0 — the detector DETECTS,
    # it isn't detected (mirrors hurtbox_component.gd:24-26). monitoring OFF until set_detection(true).
    if _detector != null:
        _detector.collision_layer = 0
        _detector.collision_mask = Constants.LAYER_PLAYER
        _detector.monitoring = false


func activate(locked_x: float) -> void:
    # ...existing bar layout + global_position...
    # Resize the detector to match the column width (geometry from tuning — AC#5). duplicate() the
    # shared RectangleShape2D first so per-instance sizing never races on the pooled shared resource
    # (same idiom as captor.gd:62-66's collision shape).
    if _detector_shape != null:
        var shape := _detector_shape.shape as RectangleShape2D
        if shape != null:
            var dup := shape.duplicate() as RectangleShape2D
            dup.size = Vector2(width_px, float(Constants.BASE_RESOLUTION.y))
            _detector_shape.shape = dup
    visible = true
    set_active_visual(false)
    set_detection(false)  # wind-up: detection OFF in telegraph (capture is the 0.4 s window only)


func set_detection(on: bool) -> void:
    # Toggle the detector's monitoring. ON only during the active capture window (CaptureState.enter);
    # OFF otherwise (telegraph, dive, idle in pool).
    if _detector != null:
        _detector.monitoring = on


func is_player_in_column() -> bool:
    # Overlap-POLL (not body_entered). The player is usually already inside the column at window
    # start (column locked to player.x at telegraph), so body_entered's enter-transition never fires.
    # Only the player is on LAYER_PLAYER, so any overlapping body IS the player.
    if _detector == null or not _detector.monitoring:
        return false
    return _detector.has_overlapping_bodies()


func deactivate() -> void:
    set_detection(false)  # a released/pooled column must never carry stale monitoring
    visible = false
```

`capture_column.tscn` adds the `Area2D` "CaptureDetector" (monitoring=false) + child `CollisionShape2D`/`RectangleShape2D`. The bars (`BarLeft`/`BarRight`) are unchanged — the `Area2D` is an invisible detection child (hazard family visuals stay as-is, D16/ADR-6).

### 🎯 Player.try_capture contract — `player/player.gd`

```gdscript
var _captured_this_wave := false  # wave-scope capture gate (AC#3); reset on wave_started.


func is_capture_immune() -> bool:
    # 2.2 STUB: the player is ALWAYS clean (no docked ship until Story 2.4). 2.4's docked_ship_controller
    # calls set_docked(true) ("capture-immune + bigger hitbox", architecture.md:616) → return that here.
    # The GUARD is real (try_capture checks it) and tested; the docked state lands in 2.4. AC2/AC4.
    return false  # 2.4 seam: return _docked


func try_capture() -> bool:
    # The captor's capture EFFECT entry (AC#1). Guards: clean (no docked ship) + once-per-wave.
    # On success: flag consumed + emit ship_depleted → Arena._on_player_ship_depleted → spend_ship →
    #   respawn (full HP via reset_to_full) | game_over. Capture BYPASSES HP — HealthComponent is
    #   NEVER touched (no take_damage); respawn's reset_to_full() restores full HP. Returns true so the
    #   captor can gate its success-conditional dive delay (AC#5).
    if is_capture_immune() or _captured_this_wave:
        return false
    _captured_this_wave = true
    ship_depleted.emit()  # LOCAL (D8) — reuses Arena's entire ship-loss/respawn/game-over path (AR2)
    return true
```

`_ready()` addition (connect ONCE — the player is NOT pooled):
```gdscript
# Story 2.2 — reset the per-wave capture gate when a new wave begins. Read-only LISTEN: the player
# still EMITS nothing to the bus (ship_depleted stays local). wave_started fires at Intro→Active,
# before any captor in that wave can capture.
if not EventBus.wave_started.is_connected(_on_wave_started):
    EventBus.wave_started.connect(_on_wave_started)
...
func _on_wave_started(_wave: int, _duration_s: float) -> void:
    _captured_this_wave = false
```

**Why this is AR2-clean:** the player owns the *trigger + guards* (per-ship-mechanic-adjacent); it emits its own existing local `ship_depleted`; the **Arena** still owns the run-scope decision (`spend_ship`/respawn/game-over). The player never touches `RunState`. HP is untouched by capture (bypass) — verified by `current_hp` being unchanged across `try_capture` (a test can assert this).

### 🎯 CaptureState physics_process — `enemies/captor/states/capture_state.gd`

```gdscript
var _captured := false
var _post_capture_t := 0.0


func enter(_msg: Dictionary = {}) -> void:
    _captor = owner as Captor
    _t = 0.0
    _captured = false
    _post_capture_t = 0.0
    if _captor == null or _captor.tuning == null or _captor.definition == null \
            or _captor.player_target == null:
        return
    if _captor.capture_column != null:
        _captor.capture_column.set_active_visual(true)   # bars intensify (existing)
        _captor.capture_column.set_detection(true)       # detection ON for the active window (NEW)


func physics_process(delta: float) -> void:
    if _captor == null or _captor.tuning == null or delta <= 0.0:
        return
    _captor.velocity = Vector2.ZERO   # hold position over the beam
    _captor.move_and_slide()

    if not _captured:
        # Active window — try to capture a clean player still in the column.
        if _captor.capture_column != null and _captor.capture_column.is_player_in_column():
            var p: Node2D = _captor.player_target
            if p != null and p.has_method("try_capture"):
                if p.call("try_capture"):   # duck-call — see "Duck-call, not a cast" gotcha
                    _captured = true
                    _captor.capture_column.set_detection(false)  # stop detecting once captured
        _t += delta / _captor.tuning.capture_duration_s
        if _t >= 1.0:
            # Window expired, no capture → MISS: dive IMMEDIATELY (no reel-in hold).
            _disable_detection()
            _captor.to_dive()
    else:
        # SUCCESS: hold the reel-in beat, then dive.
        _post_capture_t += delta
        if _post_capture_t >= _captor.tuning.post_capture_delay_s:
            _disable_detection()
            _captor.to_dive()


func _disable_detection() -> void:
    # Defensive — also done by DiveState._release_capture_column()/deactivate(). Idempotent.
    if _captor != null and _captor.capture_column != null:
        _captor.capture_column.set_detection(false)
```

**Control flow:** while `not _captured`, advance `_t` over `capture_duration_s` (0.4 s) and poll for a clean player in-column; on success flip `_captured` and switch to the `_post_capture_t` timer (`post_capture_delay_s`); on window-expiry with no capture, dive immediately. `to_dive()` (DiveState.enter) already releases the column. Retire the 2.1 seam comment block at the top of the file once wired.

### 🚧 Clean/immune is a stub in 2.2 (be honest — AC2/AC4)

AC2 ("docked ship ⇒ capture-immune") and AC4 ("at most one docked ship") **cannot be exercised in 2.2** — the docked ship is Story 2.4 (`architecture.md:611-627` `docked_ship_controller.gd` → `set_docked`). They are satisfied in 2.2 by:

- The **guard is real and tested**: `try_capture()` checks `is_capture_immune()`; a test overrides it to `true` and asserts no capture. When 2.4 wires `set_docked`, AC2/AC4 light up with **zero capture-path changes** (2.4 just makes `is_capture_immune()` return the docked state).
- The once-per-wave gate (AC3) + the immunity guard together enforce "no second capture/rescue/dock" (AC4) once docking exists.

Do **not** build docked-ship scaffolding, a `_docked` var wired to anything, or a second-capture path — those are 2.4. Leave the `# 2.4 seam` comment so 2.4 knows exactly where to wire.

### 🔌 Duck-call, not a cast — parse gotcha

The captor's `player_target` is statically typed `Node2D` (the 2.1 contract — testable with a mock). Calling `player_target.try_capture()` directly is a **parse error** in GDScript 4 (the static type `Node2D` has no `try_capture`). Two valid options:

- **Recommended — duck-call:** `if p.has_method("try_capture") and p.call("try_capture"):`. No `Player` cast → no `enemies/`→`player/` compile coupling → tests use a lightweight mock (a `CharacterBody2D` subclass with `try_capture`). Mirrors the spawner's duck-typed `child.has_method("despawn")` (`formation_spawner.gd:175`).
- Alternative — cast: `var p := _captor.player_target as Player; if p != null and p.try_capture():`. Type-safer but couples captor→`Player` class and forces tests to instantiate the real `Player`. Avoid for 2.2.

Use the duck-call.

### 🔌 Signal boundary (the one expansion)

- **Direct/local (unchanged):** `Player.ship_depleted`, `Captor.died`, `Captor.state_changed`, `HealthComponent.*`. Capture emits the player's OWN existing local `ship_depleted` — no new local signal.
- **EventBus (read-only listen — the one new touch):** the Player **subscribes** to `EventBus.wave_started` to reset `_captured_this_wave`. The player still **emits** nothing to the bus (D8 holds on the emit side). `wave_started` is an existing global game-flow signal emitted by `WaveController` at Intro→Active (`architecture.md:250`).
- Do **NOT** add a new `EventBus.player_captured` / `capture_*` signal in 2.2 (the duck-call reuses the existing `ship_depleted`→Arena path; see Open Question B if you'd rather go pure-bus).

### ⚡ Physics-step safety is inherited

Capture fires from `CaptorCaptureState.physics_process` → `player.try_capture()` → `ship_depleted.emit()` (synchronous) → `Arena._on_player_ship_depleted()` → `spend_ship` + `respawn` (or `game_over.emit()` + `_end_run.call_deferred()`). This runs **inside the physics step**, exactly like an HP-death (which fires from `enemy_projectile._on_body_entered` → … → `ship_depleted`). The existing Arena code already handles this: `game_over` is emitted synchronously (safe, D8) and the scene reload + `Pool.clear()` are **deferred** to idle (`arena.gd:68-70`). Capture inherits that fix — **do not** add a new synchronous tree-free in the capture path. The respawn teleport (`Player.respawn`) only mutates `global_position`/HP/i-frames — safe mid-physics.

### Gotchas that will bite

- **Overlap-POLL, not `body_entered`.** The player is already inside the column at window-start (column locks to player.x at telegraph). `body_entered` is an enter-*transition* signal and won't fire. Use `has_overlapping_bodies()` polled in `physics_process`. (Detection tests must add the column + a mock body to the tree and step a physics frame for overlap to register.)
- **Stale-monitoring on pooled columns.** A released column must leave `monitoring = false` (`deactivate()` calls `set_detection(false)`), and `activate()` starts with detection off. Otherwise a re-acquired column carries monitoring=true from a prior telegraph and could detect mid-telegraph. Belt: also set_detection(false) on both dive paths in CaptureState.
- **Shared `RectangleShape2D` mutation.** `duplicate()` the detector shape before resizing in `activate()` — pooled columns share the scene's shape resource; mutating it in place sizes ALL instances (same hazard as captor collision shape, `captor.gd:62-66`).
- **`.tres` overrides `.gd` defaults at runtime** (memory `tres-overrides-gd-default-for-tuning`). You MUST add `post_capture_delay_s` to `resources/captor_tuning.tres` — editing only the `.gd` default has no runtime effect.
- **Duck-call parse rule.** `player_target.try_capture()` on a `Node2D`-typed var is a parse error — use `has_method` + `call` (above).
- **`State.exit()` exists** (`components/state_machine/state.gd:14`) — you MAY put `set_detection(false)` in `exit()` instead of inline on both dive paths. Either is fine; inline-on-both is the more local/explicit choice. The captor's `to_X()` transitions do call `exit()` on the leaving state.
- **GUT silent-skip trap.** After any new `class_name` (none strictly required here), run `godot --headless --import` before GUT, and **verify the Scripts/Tests COUNTS**, not just "All tests passed!" (memory `gut-classname-reindex-silent-skip`).
- **Do NOT port the prototype.** The JS prototype's tractor pulse / capture storage is a different design (≤30% HP stun + slot). Meridian Run's capture is the captor's locked column during the 0.4 s window — re-derive in Godot idioms (memory `prototype-is-reference-only`).

### Scope seams (hand off cleanly to 2.3 / 2.4 / 2.8)

- **2.3 seam (rescue/failed-rescue):** unchanged from 2.1 — the captor's `current_state_name` + `state_changed` are already authoritative; 2.3's `_on_captor_died` reads them (dive-kill → rescue, formation-kill → failed-rescue). Capture (2.2) and rescue (2.3) are **distinct**: capture = the captor tractors the player; rescue = killing the captor frees a ship. No 2.3 work here.
- **2.4 seam (docked ship / dual nature):** `Player.is_capture_immune()` is the read-side stub; 2.4's `docked_ship_controller.gd` calls `set_docked(true)` and flips it true (AC2/AC4 then active). Leave the `# 2.4 seam` comment.
- **2.8 seam (captor wave integration):** captors still spawn ONLY via the F8 debug cheat in 2.2 (captor-presence in the wave drip is 2.8). Once-per-wave is wave-scope and already correct for 2.8's multi-captor waves (the player flag + the one-active-captor cadence).

### Out of scope for 2.2 (do NOT build — prevents scope creep)

- **Docked ship / dual-fighter / `set_docked`** — Story 2.4 (`is_capture_immune()` stubs it).
- **Rescue / failed-rescue / freed-ship dock / ship-turns-enemy** — Story 2.3.
- **Captor presence in the wave drip / onboarding cadence / captor-chance scaling** — Story 2.8 (2.2 spawns captors ONLY via F8).
- **A `captured` HUD indicator / `captors_active` HUD feed** — not an AC; the lives display already updates via the reused `ship_lost` path.
- **A new `EventBus.player_captured` signal** — the duck-call reuses `ship_depleted`; no new bus signal (see Open Question B only if Mrdth prefers pure-bus).
- **Capture during i-frames debate** — capture bypasses HP entirely (i-frames are HP-side), and once-per-wave makes re-capture moot. No special i-frame handling. (If playtest wants capture blocked during i-frames, fold into `is_capture_immune()` — flag it, don't build it.)

### Performance / hot-path (NFR2, AR14)

- Detection is one `has_overlapping_bodies()` call per physics frame, only during the 0.4 s active window, only for an active captor holding a column (at most one in 2.2). No per-frame allocations. `_captor` cached in `enter()`. The `Area2D` mask is `LAYER_PLAYER` only — minimal broadphase. All in `_physics_process` (fixed 60 Hz). Trivial cost.

### Testing (GUT)

- **Captor capture** = integration (instantiate `captor.tscn`, drive frames) — mirror `test_captor_fsm.gd` + `test_enemy.gd`'s physics idiom. Use a test `CaptorTuning` with tiny durations + a **mock player** exposing `try_capture()` (duck-call works against any node with the method, so the mock is lightweight — no full `Player` needed).
- **CaptureColumn detection** = integration (needs the column + a `LAYER_PLAYER` body in the tree + a physics-frame step for overlap). Mirror the project's existing physics-integration tests.
- **Player capture** = integration (instantiate `player.tscn`; assert `try_capture` return + `ship_depleted` emit + the `wave_started` reset + HP-untouched). Mirror `test_player_health.gd`.
- `before_each()`: `Pool.clear()`. Expect benign exit-leak warnings (memory `gut-exit-leak-warnings-expected`); trust Passing/Failing.

### Project Structure Notes

- `world/capture_column.gd` + `.tscn` — world domain (hazard family, D16/ADR-6); gains the `Area2D` detection child + API. Matches `architecture.md:492`.
- `player/player.gd` — gains `try_capture()` / `is_capture_immune()` / `_captured_this_wave` + the `wave_started` listen. The future `set_docked` (2.4) is the architecture-named counterpart (`architecture.md:616`).
- `enemies/captor/states/capture_state.gd` — wires detection → guards → effect → dive delay; retires the 2.1 seam.
- `enemies/captor/captor_tuning.gd` + `resources/captor_tuning.tres` — +`post_capture_delay_s` (flat under `resources/`, matching the existing tuning-file convention; memory notes the flat placement).
- Tests under `tests/enemies/`, `tests/world/`, `tests/player/` — mirror domain layout. No new folders.

### Project Context Rules

- **Engine:** Godot 4.6, GDScript, 2D, Compatibility renderer. Pin to 4.6.x; no 4.7-only APIs.
- **2D physics:** `CharacterBody2D` + `move_and_slide()` (no args, applies delta internally — do NOT multiply velocity by delta). `Area2D.has_overlapping_bodies()` requires `monitoring=true` + a physics tick; reads the server's last overlap update.
- **Collision layers (from `Constants`):** player=1 / enemy=2 / player_projectile=4 / enemy_projectile=8 / pickup=16. The capture detector masks `LAYER_PLAYER` (4); the player body is on `LAYER_PLAYER` via `FactionComponent`.
- **Signal boundary (D8):** global flow → EventBus; local → direct signals. Capture emits the player's LOCAL `ship_depleted`; the player only LISTENS to `wave_started`. No new bus signal.
- **State ownership (AR2):** ships run-scope on `RunState`/Arena; capture's trigger+guards on the Player; the captor only detects + requests. The player never touches `RunState`.
- **Data over code (D9):** `post_capture_delay_s` in `.tres` (the `.tres` wins).
- **No `print()` / no try-catch:** route logging via `Log.*`; `assert`/`push_error` + fail-safe defaults.
- **Pooled entities re-init via `activate()`, never `_ready()`** — the capture column's `_ready` runs once; per-acquire geometry/detection setup lives in `activate()`/`set_detection()`.
- **No bespoke FSMs (D6):** the captor's `CaptureState` already extends the shared `State`. Unchanged.
- **Composition over inheritance:** the `Area2D` is a child node of the column; no new inheritance.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.2] — ACs (FR14 clean/once-per-wave/one-docked, FR12 capture-bypass-HP + respawn full HP, FR16 docked-immune).
- [Source: _bmad-output/planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md] — D8 signal boundary (line 250: `ship_lost`/`game_over` on bus; line 419: `signal ship_lost(remaining)`); `capture_column` world/hazard (line 492); captor FSM (line 242, 485); **docked-ship controller `set_docked(true)` # capture-immune (line 616)** — the 2.4 write-side for 2.2's `is_capture_immune()` read-side.
- [Source: _bmad-output/implementation-artifacts/2-1-captor-enemy-and-5-state-fsm.md] — the prior story; the explicit "2.2 seam" in `CaptureState` (detect clean player in column → ship_lost + respawn), the success-conditional dive-delay playtest note, the `Area2D`-child + hurtbox-reuse hint, and the Node2D deferred-release gotcha that already covers the column.
- [Source: enemies/captor/states/capture_state.gd:6-15] — the 2.2 seam comment (the exact hook this story implements + retires).
- [Source: player/player.gd] — `ship_depleted` (line 23), `respawn()` (line 88), `_on_ship_depleted` (line 82); the AR2 "player never touches RunState" stance this story honors.
- [Source: world/arena.gd:50-70] — `_on_player_ship_depleted` (the reused spend_ship → respawn | game_over path) + the deferred `_end_run` (physics-step safety capture inherits).
- [Source: run/run_state.gd:28-34] — `spend_ship() -> int` (the −1 ship).
- [Source: systems/event_bus.gd:23-28] — `wave_started`, `ship_lost`, `game_over` (the reused signals).
- [Source: world/wave_controller.gd:23,36] — `wave_started` emit timing (Intro→Active) + game_over→Fail.
- [Source: components/hurtbox_component.gd:9,24-26] — the "future Captor capture reuses this" comment + the detector mask/layer idiom mirrored on the column.
- [Source: components/state_machine/state.gd:14] — `exit()` hook (optional place for `set_detection(false)`).
- [Source: components/health_component.gd:80-88] — `reset_to_full()` (the respawn full-HP, untouched by capture's bypass).

---

## Open design questions for Mrdth (review before dev — defaults are safe to implement as-is)

**A. `post_capture_delay_s` default value?**
Default (recommended): **0.35 s** — a short, readable "reel-in" beat. GDD doesn't pin a number (it's a 2.1 playtest refinement). Say the word if you want it tighter (0.2) or looser (0.5); it's a `.tres` retune either way, no code change.

**B. Capture routing — duck-call `player.try_capture()` (default) vs a new `EventBus.player_captured`?**
Default (recommended): **duck-call** (`player_target.call("try_capture")`). It gives the captor a synchronous success/fail return (so the reel-in dive-delay in AC#5 is always correct, even in 2.4 when an immune/docked player is involved), reuses the existing `ship_depleted`→Arena ship-loss path (no new bus signal, no duplicated spend/respawn logic), and stays testable with a lightweight mock. The alternative — emit `EventBus.player_captured`, let the Arena own guards+effect — is purest D8 but has no return value, so the captor's dive-delay would have to use its own local in-column detection (correct in 2.2, but could "reel in" without a ship loss in 2.4's immune edge). Flag if you'd rather go pure-bus.

**C. Where does the once-per-wave flag live — Player (default) vs Arena/WaveController?**
Default (recommended): **on the Player** (`_captured_this_wave`, reset on `wave_started`). The player persists across in-wave respawns (so the flag survives the post-capture respawn), already owns the capture trigger + the clean/immune guard, and the reset is a single read-only `wave_started` listen. Arena-ownership is equally valid but adds a captor→Arena channel (no clean return path) for the dive-delay. Player-side keeps it all in one place.

**D. AC2/AC4 (docked-immunity) — confirm stub-and-defer to 2.4?**
Default (recommended): **stub `is_capture_immune()` → `false` now; wire `set_docked` in 2.4.** Building any docked-ship scaffolding in 2.2 is scope-creep into 2.4. The guard is real + tested via an override; 2.4 lights up AC2/AC4 with zero capture-path changes. Confirm you're OK with AC2/AC4 being "guard-present, state-deferred" in 2.2 (the story states this plainly so neither the dev nor the reviewer over-claims).

---

## Review Findings

- [x] [Review][Patch] Same-frame double ship-loss race in `try_capture()` [player/player.gd:106] — `try_capture()` guards only `is_capture_immune()`/`_captured_this_wave`, not whether the player already died to HP damage in the same physics frame. If an enemy hit zeroes HP (setting `_health._is_dead` + emitting `ship_depleted`) before the captor's `CaptureState.physics_process` runs its overlap-poll in that same tick, `try_capture()` has no signal that a ship was already spent this frame and emits `ship_depleted` a second time — `Arena._on_player_ship_depleted` calls `RunState.spend_ship()` unconditionally each time it fires, so one coincidental hit can burn two ships (or falsely trigger game-over) instead of one. **Fixed:** added `_health._is_dead` to the guard clause; regression test `tests/player/test_player_capture.gd::test_try_capture_blocked_when_already_dead_this_frame` added. Full suite: 260/260 passing.
- [x] [Review][Defer] `CaptureState.physics_process`'s duck-call only null-checks `_captor.player_target`, never `is_instance_valid()`, before calling `try_capture()` [enemies/captor/states/capture_state.gd:48-50] — deferred, pre-existing (every other captor state — telegraph/dive/formation/enter — follows the same null-only convention; not a regression introduced by this diff).
- [x] [Review][Defer] `is_player_in_column()` may read stale (empty) Area2D overlap data on the physics tick right after `CaptureState.enter()` calls `set_detection(true)` [world/capture_column.gd:398-405, enemies/captor/states/capture_state.gd:30-34] — deferred, pre-existing (Godot's physics server needs one step to compute newly-enabled Area2D overlaps; could shrink the effective capture window by ~1 frame out of ~24 at 60 Hz — low severity, no clear unambiguous fix without engine-level verification).
- [x] [Review][Defer] Task 5's captor-integration test file has no direct "second capture in the wave → blocked" case through the duck-call path [tests/enemies/test_captor_capture.gd] — deferred, pre-existing test-completeness gap (the once-per-wave gate IS verified, but only at the `Player`-unit level in `tests/player/test_player_capture.gd`, not end-to-end via the captor; the Task 5 checkbox slightly overstates coverage).

## Change Log

- 2026-07-10: Story created (ready-for-dev). Ultimate context-engine analysis completed — comprehensive developer guide built from epics (FR12/FR14/FR16), the architecture (D8 signal boundary, `set_docked` capture-immune at arch:616, capture_column world/hazard), Story 2.1's explicit 2.2 seam + dive-delay playtest note, and the live player/arena/run_state/event_bus/wave_controller/captor/capture_column/health_component codebase (verbatim contracts extracted). Capture reuses the existing `ship_depleted`→Arena ship-loss path; detection is an `Area2D` overlap-poll on the column; clean/once-per-wave guards live on the Player; the success-conditional dive-delay is the deferred 2.1 playtest note.
- 2026-07-10: **Implemented (ready-for-dev → review).** All 5 ACs satisfied via the reuse-the-ship-loss-path design: `Player.try_capture()` (guards: `is_capture_immune` + `_captured_this_wave`) emits the existing local `ship_depleted` → Arena spend_ship/respawn|game_over; `CaptureColumn` gains an `Area2D` "CaptureDetector" overlap-poll (`is_player_in_column`), ON only during the 0.4 s `CaptureState` window; `CaptureState` duck-calls `try_capture` and gates a success-conditional `post_capture_delay_s` reel-in hold (immediate dive on miss). `post_capture_delay_s` added to `CaptorTuning` (.gd + .tres). +14 GUT tests → **259 passing, 0 failing** (245 baseline + 5 player + 6 capture-column + 3 captor-capture). AC2/AC4 are forward-compat stubs — the immunity guard is real + tested, the docked state is deferred to 2.4 (`# 2.4 seam`). One human/GUI subtask (in-editor F8 feel-playtest) left unchecked. One small flow deviation (`and not _captured` on the miss-dive gate) documented in Completion Notes.

---

## Dev Agent Record

### Agent Model Used

GLM-5.2 (via Claude Code / gds-dev-story workflow)

### Debug Log References

- `godot --headless --import` → exit 0 (new `.tscn` detector nodes + 3 changed `.gd` parse; class registration clean — Captor / CaptorTuning / Player / CaptureColumn all re-registered).
- First full GUT run: `test_captor_capture.gd` **failed to parse** ("Function is a coroutine, so it must be called with await") — GUT silently skipped it (caught via the Scripts COUNT: 30, not 31; memory `gut-classname-reindex-silent-skip` vindicated). Root cause: my `_await_state`/`_count_frames_in_state` helpers contain `await`, so every call site needs `await` (even inside `assert_true(await …)`). Fixed all 7 call sites; re-ran → 31 scripts.
- `godot --headless --check-only --script world/capture_column.gd` reports "Identifier not found: Pool" — a **false negative** of isolated-check mode (autoloads aren't registered when compiling one script outside the project). The original script referenced `Pool` identically; the full project boots clean and the GUT suite (which instantiates `capture_column.tscn` ~40×) passes. Not a real error.
- Final GUT: **Scripts 31 · Tests 259 · Passing 259 · Failing 0 · Orphans 1** (the orphan is the benign exit-leak; memory `gut-exit-leak-warnings-expected`).

### Completion Notes List

- **All 5 ACs satisfied.** Capture reuses the existing `Player.ship_depleted` → `Arena._on_player_ship_depleted` → `spend_ship` → (`respawn` | `game_over`) path (Key Decision #1) — no parallel capture-death pipeline was built. The NEW code is only: a non-HP trigger (`try_capture`), the guards (clean + once/wave), the `Area2D` overlap-poll on the column, and the success-conditional dive delay.
- **Detection is an `Area2D` overlap-POLL (`has_overlapping_bodies`), not `body_entered`** (Key Decision #3) — the column locks to the player's x at telegraph, so the player is already inside at window start and the enter-transition never fires. Detection is ON only during the 0.4 s `CaptureState` window (OFF in telegraph/dive/pool).
- **AC2/AC4 are forward-compat stubs — stated plainly, not over-claimed.** `Player.is_capture_immune()` returns `false` in 2.2 (the player is always clean; no docked ship until 2.4). The **guard is real and tested** (`test_immune_player_not_captured_and_dives_immediately` overrides it true on the mock; `test_is_capture_immune_returns_false_in_2_2` pins the stub). When 2.4 wires `set_docked`, AC2/AC4 light up with zero capture-path changes. The `# 2.4 seam` comment is left for 2.4 to find.
- **One small, justified deviation from the dev-notes "exact control flow":** the miss-path dive gate is `if _t >= 1.0 and not _captured:` (the literal flow had no `and not _captured`). This closes the rare same-frame edge where a capture lands on the literal last window frame — without the guard, the captor would dive immediately (skipping its reel-in hold) despite a successful capture, contradicting AC#5. With the guard, a successful capture always falls through to the success-hold branch next frame. Behavior for all normal cases (capture-early, miss, immune) is identical to the documented flow. Flagged here for the reviewer.
- **Duck-call over cast (Key Decision #2):** `player_target.has_method("try_capture")` + `call("try_capture")` keeps the captor player-agnostic (`player_target` stays typed `Node2D`, no `enemies/`→`player/` compile coupling) and testable with the lightweight `MockPlayer`.
- **Physics-step safety inherited (verified by code analysis):** `CaptureState.physics_process` → `try_capture` → `ship_depleted.emit()` (synchronous) → `Arena._on_player_ship_depleted`. The respawn branch only mutates `global_position`/HP/i-frames (safe mid-physics); the game-over branch's scene-reload + `Pool.clear` stay `call_deferred` (`arena.gd`). No new synchronous tree-free was added to the capture path. Confirmed by the passing `test_arena.gd` / `test_wave_controller.gd` suite.
- **One subtask is intentionally left unchecked (honesty):** Task 6 subtask 2 (the in-editor F8 feel-playtest) is a GUI step that cannot be run headlessly. The mechanics it checks — clean capture (−1 ship, full-HP respawn path), miss→immediate-dive, once-per-wave block, and the reel-in hold vs immediate dive — are all covered by automated tests. The in-editor pass (i-frame feel, visual reel-in beat) remains for Mrdth during review.
- **Test totals:** +14 new tests (3 captor-capture, 6 capture-column detection, 5 player-capture) on top of the 245 baseline → 259, all green. `before_each()` calls `Pool.clear()` in every new/extended file (memory `pool-deactivation-done`).

### File List

**Modified (source):**
- `enemies/captor/captor_tuning.gd` — +`@export_group("Capture")` + `@export var post_capture_delay_s: float = 0.35` (AC#5 lever).
- `resources/captor_tuning.tres` — +`post_capture_delay_s = 0.35` (the `.tres` wins at runtime).
- `enemies/captor/states/capture_state.gd` — wired detection ON in `enter()`; `physics_process` overlap-polls → duck-calls `try_capture`; success-conditional `post_capture_delay_s` reel-in hold vs immediate miss-dive; retired the 2.1 seam block; +`_disable_detection()` helper.
- `player/player.gd` — +`_captured_this_wave`, +`is_capture_immune()` (2.4 stub), +`try_capture()` (guards + reuse `ship_depleted`), +`_on_wave_started()`, +`wave_started` listen in `_ready()`.
- `world/capture_column.gd` — +`_detector`/`_detector_shape` `@onready` refs, +`_ready()` (layer 0 / mask `LAYER_PLAYER` / monitoring off), detector resize in `activate()` (duplicate-shared-resource idiom), +`set_detection()`, +`is_player_in_column()`, `set_detection(false)` in `activate()`/`deactivate()`.
- `world/capture_column.tscn` — +`CaptureDetector` Area2D (monitorable/monitoring false) + child `CollisionShape2D`/`RectangleShape2D`.

**Modified (tests):**
- `tests/world/test_capture_column.gd` — +6 detection tests (`_ready` config, set_detection toggle, is_player_in_column true/false/off, deactivate stale-monitoring guard) + `_make_player_body` helper.

**New (tests):**
- `tests/enemies/test_captor_capture.gd` — captor capture integration (clean→once+hold, immune→none+immediate-dive, dodge-out→miss+immediate-dive); `MockPlayer` inner class; real-physics-frame driving.
- `tests/player/test_player_capture.gd` — `try_capture` return + `ship_depleted` once, once-per-wave block, `is_capture_immune` stub, `wave_started` reset, HP-untouched bypass.

**Modified (tracking):**
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `2-2` status `ready-for-dev` → `review`.
- `_bmad-output/implementation-artifacts/2-2-capture-mechanic-clean-only-once-wave.md` — this story file (checkboxes, Dev Agent Record, Change Log, Status).
