---
baseline_commit: e43bffef4e17654331fb63e534e0cb53f7efdedd
---

# Story 2.6: Sacrifice Burst (Threat-Relative, NP3)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->
<!-- This story builds on the 2.5 SEAM (EventBus.sacrifice_burst_started(wing_level) is already
emitted, no subscriber). 2.6 adds the subscriber + the NP3 pure-logic clamp + the buff effect. -->

## Story

As a player,
I want sacrifice to grant a tide-turning power surge that scales with my investment but never trivializes the wave,
So that it's always worth considering and never a win button.

## Acceptance Criteria

1. **Given** sacrifice triggers, **Then** a temporary buff applies: triple-shot (±0.18 rad), ×1.5 damage, fast-fire (0.10 s cooldown), ~10 s.
2. **Given** the burst, **Then** it scales with rescued-ship track investment but is **clamped to current-wave threat** (`threat_ceiling` pure logic, GUT-tested) — always useful, never an insta-win.
3. **Given** the burst, **Then** it does **not** screen-clear (no large AoE).
4. **Given** sacrifice, **Then** there is **no artificial cooldown** — opportunity cost (forgoes keep→regain) is the limiter.

> *(FR19)* — see Dev Notes §"💰 Ship-count economy" for the **AC4 wording correction**.

## Tasks / Subtasks

### Task 1 — NP3 pure logic: `BuildRecompute` + `SacrificeBurst` + `SacrificeTuning`  *(AC: #2)*

- [x] Create `build/sacrifice_burst.gd` — `class_name SacrificeBurst extends RefCounted`, pure data (`var power: float`, `var duration: float`, `_init(p_power=1.0, p_duration=10.0)`).
- [x] Create `player/sacrifice_tuning.gd` — `class_name SacrificeTuning extends Resource` with `@export` knobs (Scaling: `base_power`, `power_per_wing`, `max_threat_fraction`; Shape: `duration`, `burst_damage_base`, `burst_fire_cooldown`, `burst_spread_rad`, `burst_shot_count`). Mirror `enemies/captor/captor_tuning.gd` schema pattern.
- [x] Create `resources/sacrifice_tuning.tres` — the runtime instance (wins over `.gd` defaults).
- [x] Create `build/build_recompute.gd` — `class_name BuildRecompute extends RefCounted`, pure statics: `sacrifice_power(wing_level, cfg)`, `threat_ceiling(wing_level, threat, cfg) -> SacrificeBurst`, `burst_damage_mult(power, cfg) -> float`. Full code in Dev Notes §"🧮 NP3 pure logic spec".
- [x] Run `godot --headless --import` (new `class_name`s — GUT won't see them until imported).

### Task 2 — Arena: compute threat + burst, apply to player  *(AC: #1, #2, #4)*

- [x] `world/arena.gd`: `@export var sacrifice_tuning: SacrificeTuning`; wire it in `arena.tscn` to `resources/sacrifice_tuning.tres`.
- [x] Add `_compute_current_threat() -> float` — sum of active enemies' `_health.max_hp` over `_spawner._container.get_children()` (covers Enemy + Captor). See Dev Notes §"🎯 Threat derivation".
- [x] Extend `_on_player_sacrifice_committed()`: KEEP the existing `EventBus.sacrifice_burst_started.emit(wing_level)` (2.5 tests assert it), THEN compute `threat`, `burst = BuildRecompute.threat_ceiling(wing_level, threat, sacrifice_tuning)`, and call `_player.apply_sacrifice_burst(burst)`.
- [x] Guard the game-over/reload race: if the run is ending (`game_over` already emitted / `_player` null), skip applying (Dev Notes §"⚠️ Edge cases").
- [x] **AC4 verify**: do NOT add any sacrifice cooldown timer/flag. The bound is structural (one docked ship per wave → at most one sacrifice per wave; forfeits keep-regain).

### Task 3 — FireSystem buff layer: fast-fire + ×1.5 damage  *(AC: #1)*

- [x] `player/fire_system.gd`: `@export var sacrifice_tuning: SacrificeTuning` (wire in `player.tscn`); `var _burst: SacrificeBurst = null`; `var _burst_time_left: float = 0.0`; `signal burst_ended()`.
- [x] `_physics_process`: decrement `_burst_time_left`; on expiry call `_expire_burst()`. Read cooldown via `_effective_fire_cooldown()` (burst → `sacrifice_tuning.burst_fire_cooldown` = 0.10 s; else `tuning.fire_cooldown` = 0.16 s).
- [x] `_spawn()`: if `_burst != null` → `_spawn_burst()` (suppresses the normal primary+docked paths — the docked fighter was consumed anyway, `is_docked()` is false); else existing primary + docked-stream path.
- [x] `apply_burst(burst)` sets `_burst`/`_burst_time_left`. `_expire_burst()` nulls them + emits `burst_ended`.

### Task 4 — Triple-shot spread (±0.18 rad)  *(AC: #1, #3)*

- [x] `player/projectile.gd`: extend `activate(spawn_pos, speed, damage, angle_rad: float = 0.0)` — default 0 = straight up (no regression for existing callers). Add `var _direction: Vector2 = Vector2(0,-1)`; set `_direction = Vector2.from_angle(-PI/2 + angle_rad)`; `_physics_process` moves `global_position += _direction * _speed * delta` (replaces `y -= _speed * delta`).
- [x] `fire_system.gd::_spawn_burst()`: spawn `sacrifice_tuning.burst_shot_count` (3) projectiles at angles `{-spread, 0, +spread}` (spread = `burst_spread_rad` = 0.18), damage = `int(round(tuning.projectile_damage * BuildRecompute.burst_damage_mult(burst.power, sacrifice_tuning)))`. Reuse `_spawn_one(at, damage, angle)`.
- [x] **AC3 verify**: the burst is a stat buff on the player's fire (more bullets + damage) — NOT an AoE. Do not add any area damage / screen-wide blast. Document this in a code comment.

### Task 5 — Buff timer + expiry + edge-case clears  *(AC: #1)*

- [x] `player/player.gd`: `apply_sacrifice_burst(burst)` → `_fire_system.apply_burst(burst)` + fire ignition juice (Task 6) + set burst-visual state (Task 7).
- [x] Clear the buff on wave-clear: in `_on_wave_cleared` (existing), call `_fire_system.clear_burst()` (add method) so the burst does not persist into the next wave.
- [x] Clear the buff on player death/respawn: in the death path, call `_fire_system.clear_burst()`.
- [x] Connect `fire_system.burst_ended` (local) → Player visual revert (Task 7). No new EventBus signal needed (burst is entity-local; see Dev Notes §"🔗 Signal boundary").

### Task 6 — Ignition juice (FR47/FR48)  *(AC: #1 — feel)*

- [x] `juice/juice_tuning.gd`: add a `"sacrifice_ignition"` particle profile (amount/lifetime/spread/speed/scale/color) + `_build_sacrifice_ignition()`; extend `get_effect_profile()` match. Set values in `resources/juice_tuning.tres`.
- [x] `juice/juice_fx.gd`: add `static func sacrifice_ignited(at: Vector2)` — emits `EventBus.screen_shake_requested` (heavy rumble, clamped by `MAX_SHAKE_PX`) + `particles_requested(&"sacrifice_ignition", at, …)` + an SFX via AudioManager. Mirrors the `docked_consumed` helper shape.
- [x] Reduced-motion: the `JuiceCoordinator._motion_scale` already dampens shake/particles (~70%); the glow + timer ring + SFX + buff remain untouched. No new reduced-motion code needed. ≤3 Hz flash cap: if any ignition element flashes, route through `hit_flash_requested` (the central `HitFlash` gate); a single ignition flash or continuous glow is fine.

### Task 7 — On-ship burst visual (UX OQ9 assumption)  *(AC: #1 — readability)*

- [x] `player/player.gd` (or a small visual child): while `_burst` active — modest glow (tint toward a climax color) + modest scale enlarge (keep ≤ ~1.15× so the true hitbox stays readable, N5) + a **depleting-arc timer ring** (NOT a full halo — DESIGN.md H6 reserves the halo for the future Shield PU).
- [x] Drive the ring from `_fire_system.get_burst_remaining_ratio()` (add `-> float`, = `_burst_time_left / _burst.duration`, 0 when no burst). Revert glow/enlarge/ring on `burst_ended` and on the edge-case clears.
- [x] Keep it minimal — this is the OQ9 `[ASSUMPTION]` default, not a polish pass. A `_draw()` arc on the player (or a child `Line2D`) suffices.

### Task 8 — GUT tests  *(AC: #2)*

- [x] Create `tests/build/test_build_recompute.gd` (NEW dir) — pure-logic (no Node, no physics_frame): `sacrifice_power` scales linearly with `wing_level`; `threat_ceiling` returns correct `{power, duration}`; clamp bites when `raw > threat * max_threat_fraction`; unclamped when `raw <`; `wing_level 0` → `power = base_power`; `threat = 0` → `power = 0`; `burst_damage_mult` formula (power=0→1.0, power=1.0→1.5, power=2.0→2.0 with `burst_damage_base=1.5`).
- [x] Extend/create `tests/player/test_sacrifice_burst.gd` (integration): dock → sacrifice → assert FireSystem `_burst != null`, `_burst_time_left ≈ duration`; spawn path produces 3 projectiles at ±0.18 rad with scaled damage; expiry (`_burst_time_left` → 0) clears buff + emits `burst_ended`; wave-clear mid-burst clears buff; **sacrifice still does NOT spend_ship** (regression of FR18); **no cooldown field exists** (AC4).
- [x] Run `godot --headless --import` THEN `godot --headless -s addons/gut/gut_cmdln.gd`. **Check the Scripts/Tests COUNTS** (not just "All passed!") — new `class_name`s silently skip if not imported (memory `gut-classname-reindex-silent-skip`).

### Task 9 — Regression gate + headless smoke + manual playtest  *(all ACs)*

- [x] Full GUT suite green (baseline 330/330 across 39 scripts after 2.5 — must not regress). **→ 355/355 across 41 scripts (+25 new tests, +2 scripts; no regression).**
- [x] Headless smoke: drive a sacrifice, confirm triple-shot projectiles + fast fire rate via a logged count (the 1-line input dispatch is covered here + playtest, since `is_action_just_pressed` is untestable in GUT — memory `input-just-pressed-untestable-in-gut`). **→ `tests/smoke_sacrifice_burst.tscn` PASS: real input dispatch fired: true; one tick = 3 projectiles (triple); 0.5 s held fire = 12 projectiles (chassis ≈ 3 → fast-fire × triple); expired after 569 steps.**
- [x] Manual playtest (GUI — mark `[x]` + **"Pending — human/GUI step"** per the dev-story convention): trigger sacrifice at wing_level 0 (×1.5 + triple + fast-fire ~10s) and at wing_level ≥2 (scaled, clamped); confirm no screen-clear, no cooldown, timer ring depletes, ignition juice fires, reduced-motion dampens. Capture feel findings. **Pending — human/GUI step** (cannot run the GUI playtest headlessly; the logic/spawn/juice paths are covered by GUT + the headless smoke above; the visual feel + reduced-motion pass need a human at the controls).

### Review Findings

- [x] [Review][Patch] `_spawn_burst()` null-derefs `sacrifice_tuning` after only an `assert()` guard — `assert()` is stripped in exported/release builds, so an unassigned `FireSystem.sacrifice_tuning` crashes instead of degrading, contradicting the class's own "AR11 fail-safe" doc comment (which is only true for `_effective_fire_cooldown()`). Confirmed independently by Blind Hunter, Edge Case Hunter, and the Acceptance Auditor. No test exercises this fallback path. [player/fire_system.gd:204-213] — **Fixed:** `_spawn()` now checks a new `_has_burst_shape()` before routing to `_spawn_burst()`; when `sacrifice_tuning` is unassigned it degrades to a single straight shot at normal damage instead of dereferencing.
- [x] [Review][Patch] `_fire_system` is dereferenced with no null-guard at four call sites (`apply_sacrifice_burst`, `_draw`, `_on_wave_cleared`, `respawn`), inconsistent with the two other call sites in the same file (`_ready`, `_process`) that do guard it — low severity (an @onready ref, unreachable in practice) but worth the same defensive consistency. [player/player.gd:301,336,381,409] — **Fixed:** all four sites now null-guard `_fire_system`.
- [x] [Review][Patch] `get_burst_remaining_ratio()` divides `_burst_time_left / _burst.duration` with no zero-guard — a `SacrificeBurst` constructed/tuned with `duration = 0.0` produces a NaN ratio fed into `draw_arc`. [player/fire_system.gd:238-244] — **Fixed:** returns `0.0` when `_burst.duration <= 0.0`.
- [x] [Review][Patch] `test_burst_spawns_triple_shot_with_spread_and_scaled_damage` overwrites the loop variable `dmg` every iteration instead of asserting per-projectile — only the last-iterated shot's damage is actually checked, so a bug scaling just one of the three shots incorrectly would go undetected. [tests/player/test_sacrifice_burst.gd:105-113] — **Fixed:** asserts each projectile's damage individually inside the loop.
- [x] [Review][Patch] `test_threat_ceiling_unclamped_returns_raw_and_duration` and `test_threat_ceiling_unclamped_when_raw_below_cap` use identical inputs and assert the same thing — a duplicated test padding the count, not adding coverage. [tests/build/test_build_recompute.gd] — **Fixed:** the duplicate now covers a distinct case (non-zero wing_level, unclamped pass-through).
- [x] [Review][Patch] Integration tests hardcode numeric values derived from `resources/sacrifice_tuning.tres`/`player_tuning.tres` (e.g. `power_per_wing = 0.3`, expected damage `15`) instead of reading the resource's actual exported values — will silently assert stale numbers the moment the `.tres` is retuned during the story's own planned playtest-tuning pass. The sibling pure-logic test file explicitly avoids this exact trap. [tests/player/test_sacrifice_burst.gd:73-87,93-113] — **Fixed:** both tests now read `arena.sacrifice_tuning`/`fs.tuning`/`fs.sacrifice_tuning` live instead of hardcoding.
- [x] [Review][Patch] `test_no_sacrifice_cooldown_field_exists` greps source text for three literal substrings (`sacrifice_cooldown`/`last_sacrifice`/`sacrifice_ready`) — trivially defeated by a differently-named throttle (e.g. `_burst_lock_until`), so it enforces a naming convention rather than the AC4 behavior it claims to guard. [tests/player/test_sacrifice_burst.gd:246-255] — **Fixed:** added `test_repeated_burst_apply_is_not_throttled`, a behavioral companion asserting a second `apply_burst` immediately refreshes the window rather than being blocked.
- [x] [Review][Patch] `Log.warn(...)` for an unassigned `sacrifice_tuning` fires on every sacrifice and allocates a fresh `SacrificeTuning.new()` per call in the fallback path instead of caching one default instance. [world/arena.gd `_on_player_sacrifice_committed`] — **Fixed:** caches the fallback `SacrificeTuning` instance and warns only once per Arena instance.
- [x] [Review][Defer] `Projectile._physics_process` leave-screen check only tests `global_position.y <= 0.0`; the guarantee that angled burst shots still cross that line depends on the current small `burst_spread_rad` (±0.18 rad) tuning value, not an explicit bound — deferred, pre-existing pattern extended safely for now. [player/projectile.gd:48-59]
- [x] [Review][Defer] No lower-bound clamp on `BuildRecompute.sacrifice_power`/`burst_damage_mult` — a hypothetical negative `base_power`/`power_per_wing` tuning value would produce negative projectile damage; out of scope while tuning defaults stay positive. [build/build_recompute.gd] — deferred, pre-existing
- [x] [Review][Defer] `_spawn_burst()`'s fan formula only centers a shot at exactly 0 rad (straight up) for an odd `burst_shot_count`; nothing guards against an even value being configured, which would silently break the "one shot straight up" assumption AC1/tests rely on. Current tuning fixes `burst_shot_count = 3`. [player/fire_system.gd `_spawn_burst`] — deferred, pre-existing

## Dev Notes

### 🚨 START HERE — the 2.5 SEAM (do not redo 2.5; build on it)

Story 2.5 already implemented the **sacrifice consume path** and the **burst hook**, and intentionally stopped there. Verified current state:

- **Input** (`player/player.gd:343-344`): `if Input.is_action_just_pressed("sacrifice"): _try_sacrifice()`. The `"sacrifice"` Input Map action already exists (`project.godot:63` — keyboard + gamepad). **2.6 does NOT touch the input shape** (hold-to-commit is deferred — see §"⌨️ Input shape").
- **Consume** (`player/player.gd:245-262`, `_try_sacrifice`): guard `_docked_ship == null` (silent no-op) → `_detach_docked_ship()` (shared, `player.gd:302-315`: synchronously `set_docked(false)` + nulls `_docked_ship`, defers `fighter.detach.call_deferred()`) → `JuiceFx.docked_consumed(...)` → emits local `sacrifice_committed`. **NO buff, NO burst, NO `spend_ship`, NO HP change.**
- **The hook** (`world/arena.gd:95-102`, `_on_player_sacrifice_committed`): one line — `EventBus.sacrifice_burst_started.emit(_run_state.build_state.wing_level)`. The comment at `arena.gd:99-101` literally reads: `# NP3 seam (2.6): subscribe → BuildRecompute.threat_ceiling → apply buff`.
- **The signal** (`systems/event_bus.gd:30`): `signal sacrifice_burst_started(wing_level: int)` — **exists, NO subscriber anywhere.** 2.5 story doc: *"2.5 has NO subscriber — no buff applies yet. This is correct and intentional; do not stub a buff."*
- **What does NOT exist** (2.6 creates all of these): `build/build_recompute.gd`, `SacrificeBurst`, `SacrificeTuning`, `threat_ceiling`, any buff field on FireSystem/Player, any spread/angle on `Projectile`, any threat metric, any ignition juice helper, any on-ship burst visual, `tests/build/`.

**2.6's job in one sentence:** subscribe to `sacrifice_burst_started` (or, equivalently, extend the Arena handler that emits it) → compute `threat_ceiling(wing_level, threat, cfg)` → apply the resulting `SacrificeBurst` to the FireSystem for `burst.duration` seconds (triple-shot ±0.18 rad + ×1.5 damage + 0.10 s cooldown) → fire ignition juice + show the timer ring.

### 🧮 NP3 pure logic spec (the headline deliverable — AC2)

Architecture `NP3 — Threat-Relative Sacrifice Ceiling` (`architecture.md` lines 648-658) gives this pseudocode:

```gdscript
static func threat_ceiling(track: BuildTrack, threat: float, cfg: SacrificeTuning) -> SacrificeBurst:
    var raw := track.sacrifice_power()                          # scales w/ investment
    var capped := minf(raw, threat * cfg.max_threat_fraction)   # threat-relative clamp
    return SacrificeBurst.new(capped, cfg.duration)
```

**E2 pragmatism (divergence from the pseudocode — intentional, confirmed with Mrdth 2026-07-13):** E2 has no `BuildTrack` object (that's E3 / Story 3.1); the rescued-ship track is the flat int `BuildState.wing_level`. So 2.6's signature takes `wing_level: int` directly. E3 will evolve this to pass a `BuildTrack` with `.sacrifice_power()`. **Do not build the StatBlock/Modifier system — that is E3.** 2.6 seeds only the `threat_ceiling` slice of `BuildRecompute`.

**Implement exactly this** (`build/build_recompute.gd`):

```gdscript
class_name BuildRecompute
extends RefCounted
# NP3 — Threat-Relative Sacrifice Ceiling (architecture.md#NP3). Pure logic → GUT-tested.
# E2 SLICE: the full StatBlock/Modifier recompute engine is Story 3.1 (E3). This seeds BuildRecompute
# with just the sacrifice-burst clamp. E3 extends this class; do not block E3's design.

# The rescued-ship track's "sacrifice power" — scales linearly with wing_level (E2 track primitive).
# (Architecture calls track.sacrifice_power(); E2 has no BuildTrack, so this takes wing_level directly.)
static func sacrifice_power(wing_level: int, cfg: SacrificeTuning) -> float:
    return cfg.base_power + float(wing_level) * cfg.power_per_wing

# The NP3 clamp: raw power (from investment) capped by current-wave threat.
# Returns a SacrificeBurst carrying the clamped power + the fixed duration.
static func threat_ceiling(wing_level: int, threat: float, cfg: SacrificeTuning) -> SacrificeBurst:
    var raw := sacrifice_power(wing_level, cfg)
    var capped := minf(raw, threat * cfg.max_threat_fraction)
    return SacrificeBurst.new(capped, cfg.duration)

# Damage multiplier from the clamped power. Formula guarantees "always useful, never an insta-win":
#   power = 0  → 1.0×  (normal damage, but triple-shot + fast-fire still apply → useful)
#   power = 1.0 → 1.5× (the nominal ×1.5 at wing_level 0, AC1)
#   power > 1.0 → > 1.5× (investment reward, threat-clamped → never an insta-win)
static func burst_damage_mult(power: float, cfg: SacrificeTuning) -> float:
    return 1.0 + (cfg.burst_damage_base - 1.0) * power
```

```gdscript
# build/sacrifice_burst.gd
class_name SacrificeBurst
extends RefCounted
# NP3 output — pure data (no Node, no signals). `power` is the threat-clamped scalar; `duration` is
# the fixed buff window. The fixed burst SHAPE (spread / cooldown / shot count / damage base) lives in
# SacrificeTuning and is read by FireSystem at apply time.
var power: float
var duration: float

func _init(p_power: float = 1.0, p_duration: float = 10.0) -> void:
    power = p_power
    duration = p_duration
```

```gdscript
# player/sacrifice_tuning.gd  (schema lives with player/ domain; .tres instance in resources/)
class_name SacrificeTuning
extends Resource
# NP3 tuning for the sacrifice burst (AR10/D9). The .tres INSTANCE in resources/ overrides these
# @export defaults at runtime — editing the .gd defaults alone has NO runtime effect
# (memory tres-overrides-gd-default-for-tuning). Set real values in resources/sacrifice_tuning.tres.

@export_group("Scaling (NP3)")
@export var base_power: float = 1.0           # sacrifice power at wing_level 0 (→ ×1.5 damage baseline).
@export var power_per_wing: float = 0.3       # raw power added per WING-track level (investment reward).
@export var max_threat_fraction: float = 0.02 # clamp: capped = min(raw, threat * this). CALIBRATE to threat scale (see Threat derivation).

@export_group("Burst Shape (FR19)")
@export var duration: float = 10.0            # ~10 s buff window (AC1).
@export var burst_damage_base: float = 1.5    # ×1.5 at power=1.0 (AC1); scales via burst_damage_mult.
@export var burst_fire_cooldown: float = 0.10 # fast-fire 0.10 s (AC1).
@export var burst_spread_rad: float = 0.18    # triple-shot ±0.18 rad (AC1).
@export var burst_shot_count: int = 3         # triple-shot (AC1).
```

**⚠️ `max_threat_fraction` calibration (important):** `threat` (raw sum of enemy `max_hp`) is on the order of 100s; `raw` power is ~1.0–3.0. For the clamp to ever bite, `max_threat_fraction` must be small (~0.01–0.03) OR threat must be normalized. The GUT test uses synthetic values (e.g. `threat=100, max_threat_fraction=0.02 → clamp=2.0`) to test the *formula* independent of the real threat scale. **Tune the real value in `resources/sacrifice_tuning.tres` during the manual playtest** so the clamp bites on high-investment / low-threat waves but stays out of the way on normal play. This is a playtest-tuned dial, not a fixed constant.

### 🎯 Threat derivation (AC2 — "current-wave threat")

**There is no shared "threat" notion in the codebase** (grep confirms — the only `threat` mentions are 2.6 comments). `threat_ceiling` is a **new local concept**. The GDD says "scales against current-wave enemy HP/threat" (`gdd.md#Difficulty Curve` line 281). Derive it as:

```gdscript
# world/arena.gd
func _compute_current_threat() -> float:
    # Sum of active enemies' max HP — captures Swarm (2× enemies), tier (+30/60% HP), and Bomber-heavy
    # waves naturally. Computed once at sacrifice time (not a hot path). Enemy + Captor both expose
    # _health (HealthComponent, max_hp set from definition.max_hp at spawn — enemy.gd:118,159).
    var total: float = 0.0
    for child in _spawner._container.get_children():
        if is_instance_valid(child) and child.has_method("get"):
            var h = child.get("_health")
            if h is HealthComponent:
                total += float(h.max_hp)
    return total
```

(Verify Captor exposes `_health` — it is killable, so it has a HealthComponent; if it uses a different field name, adapt. `Enemy._health.max_hp` is set from `definition.max_hp`: Grunt 30 / Shielder 50 / Bomber 80, `enemy_definition.gd:17`.) **Confirmed with Mrdth 2026-07-13:** HP-sum — it captures wave composition (Swarm 2× enemies, tier +30/60% HP, Bomber-heavy waves) naturally. Simpler metrics (`wave_num * k`, `enemy_count * k`) were considered and rejected (they miss HP variance).

### 💰 Ship-count economy (the load-bearing constraint — do not "fix")

**⚠️ AC4 wording correction:** Story 2.6 AC4 says "opportunity cost (forgoes keep→regain **+ spends a ship**)". The "**spends a ship**" part is **stale pre-correction residue** — it contradicts the clarified economy (FR18, `gdd.md` line 135, decision-log 2026-07-12 line 71: *"The 2.6 Sacrifice story must also treat sacrifice as no ship-count change"*). 

**The correct limiter is "forgoes keep→regain" ONLY.** Sacrifice is **ship-neutral (0)**. The ONLY ship-count changes in the Gamble are capture (−1, Story 2.2) and keep (+1, Story 2.5). Verified in code: `_try_sacrifice` (`player.gd:250-252`) and `_on_player_sacrifice_committed` (`arena.gd:95-102`) perform **no `spend_ship`, no `add_ship`, no `ship_lost` emit**. **2.6 must NOT introduce a `spend_ship` on sacrifice.** The "opportunity cost" = you forfeited the Keep regain (+1) you would have earned by holding to wave-end.

**AC4's real requirement:** "no artificial cooldown" — 2.6 must NOT add a cooldown timer/flag between sacrifices. The bound is structural: one docked ship per wave (FR14) → at most one sacrifice per wave; and forfeiting the keep regain. Do not add `last_sacrifice_time`, `_sacrifice_cooldown`, etc.

### 🔗 Signal boundary (do not over-route through EventBus)

- **KEEP** `EventBus.sacrifice_burst_started(wing_level)` as-is (2.5 emits it; 2.5 tests assert its payload; it's the global game-flow hook). 2.6 *extends the Arena handler that emits it* to also compute + apply the burst — do NOT change the signal's payload (would break `test_arena_captor_resolution.gd`).
- **The burst itself is entity-local** (FireSystem buff state + timer + on-ship visual). Per project-context.md ("Global game-flow → EventBus; Local entity comms → direct signals"), do NOT route buff-start/expire through EventBus. FireSystem emits a **local** `signal burst_ended()` → Player connects it for visual revert.
- **NO new EventBus signal** is required (`sacrifice_burst_ended` is unnecessary — nothing subscribes; the on-ship ring is local). If a future HUD needs it, add it then (YAGNI).
- **Ignition juice** uses the existing EventBus juice channels (`screen_shake_requested`, `particles_requested`) via a new `JuiceFx.sacrifice_ignited(at)` static helper — no new EventBus signal.

### 🅰️ AR2 — who owns what (do not violate)

- **Player** owns transient combat (consume/detach + local `sacrifice_committed` + applying the buff to its FireSystem). Player has **NO `RunState` reference** (AR2) — this is the structural guarantee that the WING track persists and the forfeit-the-regain invariant holds. `apply_sacrifice_burst(burst)` is a method on Player that the Arena calls (injection, not a RunState ref).
- **Arena** owns run-scope enrichment: it has `_run_state` (wing_level) + `_spawner` (threat) + `_sacrifice_tuning`. It computes the burst via `BuildRecompute.threat_ceiling` and calls `_player.apply_sacrifice_burst(burst)`. This matches 2.5's pattern ("the Arena is the single point that enriches global signals with run-state data").
- **BuildRecompute** is pure (RefCounted, statics) — no Node, no signals, no EventBus. GUT-tested without instantiating scenes. `build/` currently holds only `.gdkeep`; 2.6 seeds it.

### ⌨️ Input shape — DECISION (confirmed with Mrdth 2026-07-13: keep simple press)

2.5 (Mrdth-confirmed 2026-07-12) deliberately shipped **simple press** (`is_action_just_pressed("sacrifice")`), deferring hold-to-commit (`HoldToCommit` component, NP5/UX A1, prompt `BURN THE WINGMAN?`) to the **accessibility floor (D14)**. `components/hold_to_commit.gd` does **not exist yet**; architecture NP5 (`architecture.md` lines 688-707) has the pseudocode.

**Confirmed with Mrdth 2026-07-13: keep simple press** — do not retrofit hold-to-commit (it would break 2.5's tested input line + the D14 bundle ships as a coherent unit). `HoldToCommit` (NP5/D14) stays deferred to the accessibility floor. *(If revisited later: create `components/hold_to_commit.gd`, rewire `_try_sacrifice`'s input read, add the `BURN THE WINGMAN?` prompt ring — out of scope for 2.6.)*

### 🧲 The `DockedShipController` stays deferred (2.4's call, re-affirmed in 2.5)

2.4 deferred a `DockedShipController` (architecture NP1's home for attach/detach/sacrifice) to 2.6; 2.5 put the consume logic directly on Player and noted "Do NOT refactor in 2.5." Comments at `player.gd:242`, `docked_ship.gd:41`, `fire_system.gd:28-29` reference this seam.

**Confirmed with Mrdth 2026-07-13: keep the consume logic on Player.** 2.6's scope is the **burst effect**, not a docked-ship ownership refactor. Moving tested 2.3/2.4/2.5 code into a new controller is pure regression risk and buys nothing for the burst (the buff applies via FireSystem + EventBus, not via docked-ship ownership). Leave the deferred `DockedShipController` comments in place (2.4's call stands).

### ⚙️ Engine / project-context rules that apply

- **Tuning wins at runtime (AR10/D9):** `resources/sacrifice_tuning.tres` overrides the `player/sacrifice_tuning.gd` `@export` defaults. Edit the `.tres` for tuning; editing `.gd` defaults has no runtime effect (memory `tres-overrides-gd-default-for-tuning`). Same for `resources/juice_tuning.tres`.
- **No `print()` / no try-catch:** route logging through `Log` (`Log.info/warn/err/debug`). Use preconditions + `push_error`/`push_warning` + fail-safe defaults.
- **Static typing everywhere:** `var _burst: SacrificeBurst = null`, `func apply_burst(burst: SacrificeBurst) -> void`, typed arrays. `RefCounted` for pure data (`SacrificeBurst`), `Resource` for tunable schemas (`SacrificeTuning`).
- **Pooled projectiles:** the burst's triple-shot spawns via the existing `Pool.acquire(projectile_scene)` path in `_spawn_one` — do NOT `instantiate()`/`queue_free()` per shot. Three `Pool.acquire` calls per burst-fire tick is fine (the pool absorbs it; this is not a per-frame allocation beyond the normal fire rate × 3).
- **`_physics_process` (60 Hz fixed):** the buff timer decrements here (delta-based). No `Timer` node needed (matches `FireSystem`'s existing cooldown-accumulator idiom).
- **Deferred release:** if you touch CollisionShape2D during the burst (you shouldn't need to — the burst doesn't change the player's hitbox, only its fire), use `set_deferred("shape", dup)` (memory `collisionshape-set-deferred-in-physics-callback`).
- **`@onready` / cache refs:** cache `_fire_system` on Player (if not already), `_player` on FireSystem (existing duck-call — keep it). No `$`/`get_node()` per frame.
- **Do not port the prototype:** the JS prototype's sacrifice model is reference-only. Re-derive in Godot idioms (Nodes/Resource/EventBus). The superseded prototype spec (`spec-capture-sacrifice-prototype.md`) is history — do NOT model the burst on any "Bomber = 50 damage to all on-screen enemies" AoE pattern (that was rejected; the burst is a stat buff, AC3).

### 🧪 GUT notes (critical — read before testing)

- **NEW `class_name`s (BuildRecompute, SacrificeBurst, SacrificeTuning) → run `godot --headless --import` BEFORE GUT.** GUT silently skips parse-failed/unindexed scripts, so "All tests passed!" can be false. **Check the Scripts/Tests COUNTS** in the GUT output (memory `gut-classname-reindex-silent-skip`). Baseline after 2.5: 330/330 across 39 scripts — your new tests must appear in the count AND the total must not regress existing tests.
- **`before_each(): Pool.clear()`** — start each test from a known-empty pool (autoload).
- **`add_child_autofree()`** for all test nodes; Player tests put the Player under an `add_child_autofree(Node2D)` "arena" (player._ready wires `FireSystem.projectile_parent = get_parent()`); Arena tests use `ArenaScene.instantiate()` + `arena._spawner.set_active(false)`.
- **`watch_signals(obj)` + `assert_signal_emitted`/`assert_signal_emit_count`**. For EventBus: `watch_signals(EventBus)`.
- **Typed-payload signal assertion bug** (memory `gut-payload-assertion-bug`): `assert_signal_emitted_with_parameters` is BROKEN for typed-payload signals. Use `assert_signal_emitted(obj, sig)` + `var p := get_signal_parameters(obj, sig)` + `assert_eq(p[0], expected)` — this is how 2.5 asserts `sacrifice_burst_started` carries `wing_level`.
- **`is_action_just_pressed` is untestable in GUT** (memory `input-just-pressed-untestable-in-gut`): drive `_try_sacrifice()` / `apply_sacrifice_burst()` DIRECTLY. The 1-line input dispatch is covered by headless smoke + manual playtest.
- **`await get_tree().physics_frame`** after deferred `queue_free` paths (let the fighter free land before teardown). Pure-logic tests (`test_build_recompute.gd`) need NO physics stepping.
- **Exit-leak warnings are expected** (memory `gut-exit-leak-warnings-expected`) — trust Passing/Failing counts.

### ⚠️ Edge cases

- **Sacrifice input race (deferred from 2.5 review):** sacrifice input is read every `_physics_process` with no gate against the `game_over`→reload window — a sacrifice could commit against a `RunState` about to be torn down. 2.5's hook only emitted a signal (low risk). **2.6 mutates FireSystem state** → guard in `_on_player_sacrifice_committed`: if `game_over` already emitted or `_player` invalid, skip `apply_sacrifice_burst` (still safe to emit the signal, or skip both).
- **Buff persists across wave-clear / death?** No — clear it. Wave-clear (`_on_wave_cleared`) and the death/respawn path must call `_fire_system.clear_burst()`. A burst must not carry into the next wave or past a death.
- **`wing_level` is unbounded** (deferred-work: `record_rescue()` has no ceiling; Story 3.3 owns the cap). 2.6's `threat_ceiling` is a *separate* threat-relative clamp, not a level cap — but unbounded `wing_level` feeds `sacrifice_power()`, so the threat clamp is what keeps an absurd `wing_level` from breaking the burst. The GUT test should include a high-`wing_level` case asserting the clamp bites.
- **Can a player sacrifice → re-rescue → re-sacrifice in one wave?** If FR14's "one docked ship per wave" is enforced (not just concurrent), no. **Verify** 2.5's dock-once-per-wave enforcement; if re-sacrifice is possible, that's a 2.5 economy concern to flag to Mrdth — **2.6 must NOT patch it with a cooldown** (AC4). The structural bound is the design intent.
- **Burst while docked?** Impossible by construction: sacrifice consumes the docked fighter (`_docked_ship` → null) before the burst applies. The burst's `_spawn_burst()` suppresses the docked parallel stream anyway (defensive).

### 🧠 Previous story intelligence (learnings from 2.4/2.5)

- **Ship-count economy is load-bearing — do NOT "fix":** only capture(−1)+keep(+1) change ships; sacrifice/absorb/failed-rescue/rescue are all 0. The epics' old "−1 ship" wording for absorb/sacrifice is the corrected relative-accounting mistake (memory `gamble-ship-count-economy`).
- **`_detach_docked_ship()` is the shared detach** (absorb + sacrifice + keep). It flips `set_docked(false)` + nulls `_docked_ship` **synchronously** (so `is_docked()`/`is_capture_immune()` update immediately) and defers `fighter.detach.call_deferred()` (no-arg — Godot 4.6 can't marshal a typed Node through `call_deferred`; memory `deferred-typed-node-arg-marshalling`).
- **The forfeit-the-regain invariant** = the `if _docked_ship != null:` guard in `_on_wave_cleared` before `ship_kept.emit()`. Sacrifice nulls `_docked_ship` synchronously, so a later wave-clear reads false → no `ship_kept` → no `add_ship`. 2.6 must not disturb this.
- **WING track permanence (NP1):** no consume-side mutator on `BuildState`; the consume paths live on Player (no RunState ref, AR2) → structurally cannot clear the track. 2.6's burst **reads** `wing_level` (via the Arena) but must NOT mutate it.
- **FireSystem reads `_player` via duck-call** (untyped Node + `has_method`/`call`/`get`, NOT `as Player`). Keep this; do not hard-cast (the deferred `DockedShipController` refactor would change this, but 2.6 doesn't do that refactor).
- **`JuiceFx.docked_consumed` is reused by absorb + sacrifice** (2.5 DECISION Q2). 2.6 adds a **distinct** `JuiceFx.sacrifice_ignited` for the burst start (the "ignition cue" 2.5 deferred) — do not remove `docked_consumed` (absorb still uses it).
- **Tuning `.tres` is the source of truth** — `resources/docked_ship_tuning.tres`, `resources/player_tuning.tres`, `resources/juice_tuning.tres` all override `.gd` defaults. Add `resources/sacrifice_tuning.tres` in the same flat style.

## Project Structure Notes

**Files to CREATE (all new):**
- `build/build_recompute.gd` — pure NP3 logic (seeds the `build/` domain; E3 extends). `build/` currently has only `.gdkeep`.
- `build/sacrifice_burst.gd` — pure data (`RefCounted`).
- `player/sacrifice_tuning.gd` — `Resource` schema (lives with owning `player/` domain).
- `resources/sacrifice_tuning.tres` — runtime instance (flat in `resources/`, matching `captor_tuning.tres`/`player_tuning.tres`).
- `tests/build/test_build_recompute.gd` — pure-logic GUT test (NEW `tests/build/` dir, mirrors domain layout).

**Files to MODIFY:**
- `player/projectile.gd` — extend `activate(...)` with `angle_rad` + `_direction` field (backward-compatible default = straight up).
- `player/fire_system.gd` — buff state (`_burst`/`_burst_time_left`/`sacrifice_tuning` @export), `_effective_fire_cooldown()`, `_spawn_burst()`, `apply_burst()`/`clear_burst()`/`_expire_burst()`, `signal burst_ended()`, `get_burst_remaining_ratio()`.
- `player/player.gd` — `apply_sacrifice_burst(burst)`; clear-burst calls in `_on_wave_cleared` + death path; on-ship burst visual state (glow/enlarge/timer ring).
- `player/player.tscn` — wire FireSystem `sacrifice_tuning` @export to `resources/sacrifice_tuning.tres`.
- `world/arena.gd` — `@export var sacrifice_tuning`; `_compute_current_threat()`; extend `_on_player_sacrifice_committed` (compute threat + burst + `apply_sacrifice_burst`); game-over race guard.
- `world/arena.tscn` — wire Arena `sacrifice_tuning` @export to the same `.tres`.
- `juice/juice_fx.gd` — `static func sacrifice_ignited(at)`.
- `juice/juice_tuning.gd` — `"sacrifice_ignition"` profile + `_build_sacrifice_ignition()`; extend `get_effect_profile()` match.
- `resources/juice_tuning.tres` — ignition profile values.
- `tests/player/test_sacrifice_burst.gd` (NEW) — integration test; OR extend `tests/player/test_player_docked_resolution.gd` + `tests/world/test_arena_captor_resolution.gd` (2.5 owns those — extend, don't rewrite).
- (Optional) `systems/debug.gd` — surface burst state (`BURST p/d t`) in the overlay readout (low priority; 2.5 added a BUILD row — follow that pattern if useful).

**Alignment with unified structure:** all new files land in their owning domain (`build/` for pure recompute, `player/` for the burst schema + fire/projectile changes, `resources/` for `.tres`, `tests/` mirroring domains). No conflicts with the architecture's intended layout.

## Project Context Rules

(Extracted from `_bmad-output/project-context.md` — follow exactly.)

- **Engine:** Godot 4.6, GDScript, 2D, Compatibility renderer, 2D physics server. Pin to 4.6.x (avoid 4.7-only APIs).
- **Autoloads:** thin global services only; `EventBus` for global game-flow, local signals for intra-entity. Do not route the buff through EventBus (it's entity-local).
- **Build engine = recompute, never mutate:** 2.6's `BuildRecompute.threat_ceiling` is a pure recompute (returns a new `SacrificeBurst`), consistent with this rule. (E3 will extend BuildRecompute with the full StatBlock recompute.)
- **State ownership is fixed:** ships/score/build-tracks → `RunState`; docked-ship combat → `DockedShip` (transient); the WING build track → `RunState.BuildState` (permanent — never cleared when the fighter is consumed). 2.6 reads `wing_level`, never mutates it.
- **Communication boundary:** global game-flow → `EventBus` (typed, past-tense signals); local entity comms → direct signals; testable dependencies → explicit injection (Arena calls `_player.apply_sacrifice_burst(burst)` — injection, not a RunState ref on Player).
- **No `print()` / no try-catch:** use `Log`; preconditions + `push_error`/`push_warning` + fail-safe defaults.
- **Content via ContentRegistry, not scattered loads:** `SacrificeTuning` is a tuning `.tres` (not "content" like ships/enemies), loaded via `@export` in the scene (matching `CaptorTuning`/`PlayerTuning`/`JuiceTuning`). Do not `load("res://...")` for it in gameplay code.
- **Juice is arena-scoped, not an autoload:** `JuiceCoordinator` lives in the arena scene, listens to `EventBus` juice signals. 2.6's ignition juice goes through `JuiceFx.sacrifice_ignited` → EventBus juice channels → JuiceCoordinator. Auto-disabled in menus.
- **Composition over inheritance; strict collision layers:** the burst does NOT add a component to the player (it's a buff state on FireSystem + a visual). No new collision layers. The burst doesn't change the player's hitbox (N5 readability).
- **Pooled entities re-init via `activate()`/`reset()`:** the burst's triple-shot spawns via `Pool.acquire(projectile_scene).activate(...)`. Do not `queue_free()` projectiles.
- **Hot-path discipline:** the buff timer + fire rate live in `_physics_process` (60 Hz fixed). No per-frame allocations in the spawn loop — reuse the existing `_spawn_one` path. Cache `_burst`/`_burst_time_left` (scalars, cheap).
- **Typing:** static typing everywhere (`: int`, `-> void`, `Array[X]`, typed `SacrificeBurst`/`SacrificeTuning`).
- **Testing:** GUT, pure logic separable from Node code (`BuildRecompute` is pure → unit-testable without scenes). Tests under `tests/` mirroring domains (`tests/build/`, `tests/player/`), named `test_<thing>.gd`.

## References

- [Source: epics.md#Story 2.6 (lines 504-517)] — ACs (FR19).
- [Source: epics.md#FR18 (line 64), FR19 (line 65), FR47 (line 111), FR48 (line 112)] — requirements.
- [Source: gdd.md#Capture / Rescue / Sacrifice (line 146)] — buff spec (triple ±0.18 / ×1.5 / 0.10s / ~10s).
- [Source: gdd.md#Ship-count economy (line 135), Anti-spam (line 139), Difficulty Curve (line 281), Weapon Systems (line 223, 228)] — economy, no-cooldown, threat-relative ceiling, no-screen-clear.
- [Source: gdd/decision-log.md (line 27 Build-9, line 71 2026-07-12 correction)] — sacrifice model + "2.6 must treat sacrifice as no ship-count change".
- [Source: architecture.md#NP3 (lines 648-658)] — `threat_ceiling` pseudocode.
- [Source: architecture.md#NP1 (lines 600-631)] — docked-ship dual nature + ship economy.
- [Source: architecture.md#NP5 (lines 688-707), D14 (lines 291-302)] — hold-to-commit (deferred) + accessibility floor.
- [Source: architecture.md#Build Engine D2 (lines 213-221)] — StatBlock/Modifier (E3; 2.6 does NOT build this).
- [Source: ux/EXPERIENCE.md (lines 161-162, 223, 244, 320-324, 442-451)] — timer ring (OQ9), hold-to-toggle, Rosa climax, juice recipe, reduced-motion.
- [Source: ux/DESIGN.md (C2, N5, H6)] — power = bigger+glowier (modest), hitbox readability, ring reserved for Shield PU.
- [Source: ux/review-accessibility.md (lines 153-161)] — ≤3 Hz central-clamp enforcement.
- [Source: 2-5-docked-ship-resolution-four-outcomes.md#NP3 seam (lines 161-167)] — the 2.6 seam.
- Code: `arena.gd:95-102` (the seam), `player.gd:245-262` (`_try_sacrifice`), `fire_system.gd:46-91` (fire path), `projectile.gd:26,44` (`activate`/movement), `build_state.gd` (`wing_level`), `event_bus.gd:30` (`sacrifice_burst_started`).

## Dev Agent Record

### Agent Model Used

GLM-5.2[1m] (Claude Code)

### Debug Log References

- `godot --headless --import` (after Task 1 + after all code) — `BuildRecompute`, `SacrificeBurst`, `SacrificeTuning` registered cleanly; no parse errors.
- `godot --headless -s addons/gut/gut_cmdln.gd` → **355/355 passing, 41 scripts, 986 asserts** (baseline after 2.5 was 330/330 across 39 — +25 tests, +2 scripts, no regression). First run was 354/355 (the AC4 source-grep tripped on its own "don't do this" comment token — reworded the comment; second run green).
- `godot --headless tests/smoke_sacrifice_burst.tscn` → **PASS** (see Task 9.2). The real `is_action_just_pressed("sacrifice")` dispatch read **true** in the fresh process — so even the 1-line input dispatch is covered headlessly here (bonus, beyond the GUT coverage).
- Exit-leak warnings (3 ObjectDB + 1 resource) + 1 orphan (test_formation_spawner) are pre-existing/expected (memory `gut-exit-leak-warnings-expected`).

### Completion Notes List

**What landed (NP3 — Threat-Relative Sacrifice Ceiling, end-to-end):**

1. **NP3 pure logic (AC2):** `build/build_recompute.gd` — `sacrifice_power` (linear in wing_level), `threat_ceiling` (the `min(raw, threat × max_threat_fraction)` clamp → `SacrificeBurst`), `burst_damage_mult` (`1 + (burst_damage_base − 1) × power`). Pure RefCounted statics, no Node/EventBus — GUT-tested without scenes. `build/sacrifice_burst.gd` (RefCounted pure data: power + duration). `player/sacrifice_tuning.gd` + `resources/sacrifice_tuning.tres` (the tuning schema + runtime instance; mirrors CaptorTuning's pattern). E3 will extend BuildRecompute with the full StatBlock recompute — 2.6 seeds only this slice (no D2 modifier system built).
2. **Arena application (AC1/AC2/AC4):** `world/arena.gd` — `@export sacrifice_tuning`; `_compute_current_threat()` (Σ active enemies' `_health.max_hp` over `_spawner._container` — covers Enemy + Captor; the `is HealthComponent` guard skips a held CaptureColumn); extended `_on_player_sacrifice_committed` to KEEP the 2.5 `sacrifice_burst_started` emit (2.5 tests assert it), then compute the burst via `threat_ceiling` + inject it via `_player.apply_sacrifice_burst(burst)` (injection, NOT a RunState ref on Player — AR2). Game-over/reload race guarded (`_reload_in_flight` / `is_instance_valid(_player)`). **AC4: NO cooldown field added** — the bound is structural (one docked ship per wave).
3. **FireSystem buff layer (AC1):** `player/fire_system.gd` — `_burst`/`_burst_time_left` + local `signal burst_ended()`; `_physics_process` ticks the timer → `_expire_burst()`; `_effective_fire_cooldown()` (0.10 s during burst, else 0.16 s); `_spawn()` routes to `_spawn_burst()` while a burst is active (suppresses the primary + docked stream — the fighter was consumed); `apply_burst`/`clear_burst`/`_expire_burst`/`get_burst_remaining_ratio`.
4. **Triple-shot spread (AC1/AC3):** `player/projectile.gd` — `activate(..., angle_rad=0.0)` + `_direction` field (backward-compatible default = straight up). `_spawn_burst` spawns `burst_shot_count` (3) projectiles in a symmetric fan `{−spread, 0, +spread}` = ±0.18 rad, damage scaled via `burst_damage_mult`. **AC3: a STAT BUFF (more bullets + damage), NOT an AoE** — no area damage anywhere (the rejected prototype "Bomber = 50 dmg to all" model is explicitly NOT modeled).
5. **Edge-case clears (AC1):** `player/player.gd` — `apply_sacrifice_burst(burst)` (apply + ignition juice + visual); `clear_burst()` in `_on_wave_cleared` (no persist into next wave) AND in `respawn()` (a fresh ship doesn't carry the dead ship's burst — covers BOTH ship-loss paths: HP-death + capture; game-over is scene teardown). `fire_system.burst_ended` connected → `_revert_burst_visual` (one uniform revert path for natural expiry + both force-clears; `clear_burst` emits only if a burst was active → idempotent).
6. **Ignition juice (AC1 feel / FR47/FR48):** `juice/juice_fx.gd::sacrifice_ignited(at)` (kill-grade shake clamped by MAX_SHAKE_PX + warm-amber ignition particles + SFX — mirrors `docked_consumed`). `juice/juice_tuning.gd` + `.tres` — the `sacrifice_ignition` profile + `_build_sacrifice_ignition()` + the `get_effect_profile()` match arm. Reduced-motion dampens shake/particles via the existing `_motion_scale`; no flash (the glow is continuous → no ≤3 Hz gate needed).
7. **On-ship visual (AC1 readability / OQ9):** `player/player.gd` — modest warm-tint glow + modest scale enlarge (1.12×, ≤1.15× — cosmetic, the hitbox CollisionShape2D is untouched → N5) + a depleting-arc timer ring via `_draw()` (driven by `get_burst_remaining_ratio()`; NOT a full halo — H6 reserves that for the future Shield PU). `_process` queue_redraws only while active. Kept minimal (the OQ9 `[ASSUMPTION]` default).

**Acceptance-criteria mapping:** AC1 (triple ±0.18 / ×1.5 / 0.10 s / ~10 s) → Tasks 3–7; AC2 (threat-relative clamp, pure-logic-tested) → Tasks 1–2 + `test_build_recompute.gd`; AC3 (no screen-clear) → Task 4 + the AC3 code comments + the integration test's "3 projectiles, not an AoE" assertion; AC4 (no artificial cooldown) → Task 2 AC4-verify + `test_no_sacrifice_cooldown_field_exists`.

**Key implementation notes:**
- **`max_threat_fraction` is a playtest-tuned dial** (0.02 default). With the spawner halted (smoke/GUT), threat=0 → power clamps to 0 → the burst still applies (×1.0 damage but triple + fast-fire = "always useful"). Tune the `.tres` during the manual playtest so the clamp bites on high-investment / low-threat waves but stays out of the way on normal play.
- **AC4 wording correction honored:** sacrifice is ship-neutral (no `spend_ship`); the only limiter is "forgoes keep-regain". Verified by `test_sacrifice_does_not_spend_ship`.
- **Signal boundary honored:** `EventBus.sacrifice_burst_started` unchanged (2.5 owns it); the buff is entity-local → `FireSystem.burst_ended` is a LOCAL signal (no new EventBus signal). No `DockedShipController` refactor (2.4/2.5's deferred call stands). No hold-to-commit (simple press; NP5/D14 deferred).

**Pending — human/GUI step:** the manual playtest (Task 9.3) — visual feel (glow/ring/ignition), the reduced-motion pass, and confirming the clamp feels right at wing_level 0 vs ≥2 need a human at the controls. The logic, spawn shape, juice wiring, edge-case clears, and (in the smoke) the real input dispatch are all verified headlessly.

### File List

**Created (8):**
- `build/build_recompute.gd` — NP3 pure-logic statics (sacrifice_power / threat_ceiling / burst_damage_mult). Seeds the `build/` domain.
- `build/sacrifice_burst.gd` — RefCounted pure-data (power + duration).
- `player/sacrifice_tuning.gd` — SacrificeTuning Resource schema (mirrors CaptorTuning).
- `resources/sacrifice_tuning.tres` — runtime tuning instance (wins over the `.gd` defaults).
- `tests/build/test_build_recompute.gd` — pure-logic GUT test (NEW `tests/build/` dir).
- `tests/player/test_sacrifice_burst.gd` — integration GUT test (dock → sacrifice → burst → triple-shot → expiry → clears → economy/AC4).
- `tests/smoke_sacrifice_burst.gd` — headless smoke (Task 9.2; Node2D run as a scene).
- `tests/smoke_sacrifice_burst.tscn` — the smoke scene.

**Modified (9):**
- `world/arena.gd` — `@export sacrifice_tuning`; `_compute_current_threat()`; extended `_on_player_sacrifice_committed` (threat + burst + apply + game-over race guard); AC4 no-cooldown note.
- `world/arena.tscn` — wire Arena `sacrifice_tuning` → `resources/sacrifice_tuning.tres`.
- `player/fire_system.gd` — buff layer (`_burst`/`_burst_time_left`/`signal burst_ended`/`sacrifice_tuning` @export), `_effective_fire_cooldown`, `_spawn()` burst branch, `_spawn_burst`, `apply_burst`/`clear_burst`/`_expire_burst`/`get_burst_remaining_ratio`, `_spawn_one` angle param.
- `player/projectile.gd` — `activate(..., angle_rad=0.0)` + `_direction` field + `_physics_process` direction-based movement.
- `player/player.gd` — `apply_sacrifice_burst`; `clear_burst` in `_on_wave_cleared` + `respawn`; `burst_ended` connect; on-ship visual (`_apply_burst_visual`/`_revert_burst_visual`/`_draw` ring + `_process` redraw + constants); `_burst_active` flag.
- `player/player.tscn` — wire FireSystem `sacrifice_tuning` → `resources/sacrifice_tuning.tres`.
- `juice/juice_fx.gd` — `static sacrifice_ignited(at)`.
- `juice/juice_tuning.gd` — `sacrifice_ignition` profile + `_build_sacrifice_ignition()` + `get_effect_profile()` match arm.
- `resources/juice_tuning.tres` — the ignition profile values.

## Change Log

- 2026-07-13 — Implemented Story 2.6 (Sacrifice Burst — Threat-Relative, NP3). NP3 pure logic (`BuildRecompute`/`SacrificeBurst`/`SacrificeTuning`) + Arena threat computation + FireSystem buff layer (triple-shot ±0.18 rad, ×power damage, 0.10 s fast-fire, ~10 s) + ignition juice + on-ship timer-ring visual. 25 new GUT tests (355/355 green, no regression) + a headless smoke (PASS, incl. the real input dispatch). Manual GUI playtest pending.

## Decisions (confirmed with Mrdth, 2026-07-13)

All six design decisions below are **confirmed and locked**; the story implements them as-is. See the in-line Dev Notes subsections (🧮 NP3, 🎯 Threat, ⌨️ Input, 🧲 DockedShipController) for full rationale.

1. **AC4 "spends a ship" is stale** — sacrifice is ship-neutral (FR18, decision-log line 71). 2.6 implements **no `spend_ship`**; the limiter is "forgoes keep→regain" only.
2. **Hold-to-toggle Sacrifice (NP5/D14)** — **deferred.** 2.6 keeps simple press (`is_action_just_pressed("sacrifice")`); `HoldToCommit` lands with the D14 accessibility floor.
3. **`capped` scaling** — `capped` (the threat-clamped power scalar) scales the **damage multiplier** via `1.0 + (burst_damage_base - 1.0) * power` (×1.0 at power=0, ×1.5 at wing_level 0, >×1.5 with investment, threat-clamped). Fixed shape (triple ±0.18 rad / 0.10 s / ~10 s) always applies — so the burst is always useful; the clamp prevents an insta-win.
4. **Threat derivation** — `threat = Σ active enemies' max_hp` (raw float, Arena-computed via `_spawner._container`). Captures Swarm/tier/Bomber composition.
5. **`DockedShipController`** — **deferred.** Consume logic stays on Player (2.6 = burst effect, not a docked-ship refactor).
6. **On-ship burst visual scope** — **minimal:** ignition juice + depleting-arc timer ring + modest glow/enlarge. Full OQ9 visual polish deferred.
