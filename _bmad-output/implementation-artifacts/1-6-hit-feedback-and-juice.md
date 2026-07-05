---
baseline_commit: f508467ee8bee9ddf43a71a5cca8810e2c913aef
---

# Story 1.6: Hit Feedback & Juice

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a player,
I want punchy hit-flash, screen-shake, and neon particle bursts on every impact, with basic synthwave SFX,
so that combat feels powerful and readable (build-crafter reward clarity — every hit lands with weight).

## Acceptance Criteria

*(Source: `planning-artifacts/epics.md` Story 1.6 (lines 373–386) — FR47, FR48 (basic) · AR9 · UX EXPERIENCE.md §Game Feel & Juice / §Accessibility Floor · architecture D9 / AR9 / D14)*

1. **Given** the player or an enemy is hit, **Then** hit-flash + screen-shake + a pooled particle burst all fire, driven by `EventBus` (`screen_shake_requested` / `hit_flash_requested` / particle-request signal).
2. **Given** the `JuiceCoordinator`, **Then** it lives in the **Arena scene** (not an autoload), and is auto-disabled outside the arena (arena-scoped ⇒ structurally absent from menus).
3. **Given** particles, **Then** they're pooled (`GPUParticles2D` via `Pool` — `acquire()`/`release()` + `activate()`), never `instantiate()`+`queue_free()` per event, never re-init via `_ready()`.
4. **Given** audio, **Then** basic SFX play on fire/hit/kill via `AudioManager` (synthwave punch), routed through an SFX bus, with light pitch variation so repeated fire/hit doesn't grate.
5. **Given** the accessibility floor (UX A1, arch D14 — all shipping, none optional): **Then** reduced-motion dampens shake/particle/hit-flash *amplitude* without removing the feedback, and a photosensitive **≤3 Hz flash cap is enforced centrally** on the `JuiceCoordinator` (a single global cadence gate, not summed across emitters), unconditionally.

**Implicit / end-to-end requirements (the dev agent owns these — an implementation must leave the system working end-to-end, not just satisfy the letter of the ACs):**

- **No hit path may regress.** The 1.3/1.4/1.5 damage/death/i-frame/score/wave flow must keep working identically. Concretely: `player/projectile.gd` and `enemies/enemy_projectile.gd` still call `take_damage()`; `HealthComponent.died` → `enemy.died` → score → `wave_cleared` is untouched; the player's i-frame window still blocks damage; `tests/player/test_projectile.gd`, `tests/enemies/test_enemy*.gd`, `tests/components/test_health_component.gd`, `tests/world/test_arena.gd`, `tests/world/test_formation_spawner.gd` must stay green. Juice is *added on top of* the existing hit resolution, never in place of it.
- **Juice hooks the impact *source*, not the shared `HealthComponent`.** The projectile that causes the impact knows the exact contact `global_position`, the severity, and the faction — emit the juice request signals from `Projectile._on_body_entered`, `EnemyProjectile._on_body_entered`, `Enemy._on_died`, and `FireSystem._spawn`. **Do NOT add a `damaged`/`hit_taken` signal to `HealthComponent`** (it would churn the shared component + its 18 tests, and lose impact-position accuracy). See Key Decision #1.
- **Kill ≠ despawn.** `Enemy._on_died` (real kill) fires death juice (big explosion + shake + SFX sting). `Enemy.despawn()` (wave-end survivor cleanup, no score, no `died` signal) fires **no juice**. Do not wire juice into the despawn path.
- **Adding a `Camera2D` to the arena must not move or crop the fixed-screen layout.** Screen-shake needs a camera; there is none today. The new `Camera2D` must render the existing 1280×720 play-field *identically* when idle (centered, zoom 1.0, no smoothing fighting the shake). Verify visually + by a regression assertion before declaring done. See Gotcha §"Camera2D".
- **Juice is arena-scoped, so "auto-disabled in menus" (UX F8) is satisfied structurally.** The `JuiceCoordinator` node exists only in `arena.tscn`. There are no menu scenes in E1 yet — do not add a `JuiceCoordinator` anywhere else, and future menu scenes (E8) must not include one. No `process_mode`/pause toggling is needed for the E1 slice.
- **Physics-callback safety still holds.** Juice emits originate inside `_on_body_entered` (a physics callback). *Emitting* a signal from there is safe; the `JuiceCoordinator`'s synchronous handler (`Pool.acquire` + `add_child` + `activate`) is also safe — only node **removal/freeing** is forbidden during physics, and particle spawn is additive. Particle *release* (lifetime expiry) happens later via a `Timer`, not inside a physics callback. Do not `queue_free()` particles.
- **Replace the 1.5 i-frame alpha-flicker placeholder.** `player.gd._process` currently carries a `_visual.modulate.a` sin-flicker explicitly tagged *"placeholder; Story 1.6 owns the juice pass"*. The **impact** hit-flash (the new work) is driven by `JuiceCoordinator` via `hit_flash_requested`; the **sustained** i-frame cue (a calmer steady pulse while invulnerable) stays in `player.gd` but is cleaned up — remove the placeholder comment/tag.

---

## Tasks / Subtasks

### Task 1 — `EventBus` juice-request signals + `Constants` safety caps (AC: #1, #5)

- [x] 1.1 `systems/event_bus.gd` — add three typed **request** signals (D8: imperative `_requested` for requests, matching `request_pause`). These are global juice requests — the emitter (projectile/enemy/fire_system) and the consumer (`JuiceCoordinator`) are not in the same entity subtree, so the bus is the correct channel:
  - `signal screen_shake_requested(amount: float, duration: float)` — global shake; `amount` in px (pre-motion-scale), `duration` in seconds.
  - `signal hit_flash_requested(target: Node2D, color: Color)` — flash a specific entity's sprite (the body node; `modulate` cascades to its visual children). `target` MUST be a `CanvasItem` (player/enemy bodies are `CharacterBody2D` ✓).
  - `signal particles_requested(effect: StringName, at: Vector2, color: Color, scale: float)` — spawn a pooled particle burst at a world position. `effect` selects the burst profile (e.g. `&"hit_spark"`, `&"explosion"`, `&"muzzle"`); `scale` multiplies the burst size (heavy/Bomber/death = bigger).
  - Keep the existing 6 signals (`run_started`, `wave_cleared`, `ship_lost`, `build_changed`, `score_changed`, `game_over`) and the header comment intact (extend, don't rewrite).
- [x] 1.2 `systems/constants.gd` — add the two **safety caps** (immutable tier, AR10 — these are non-negotiable limits, not feel knobs):
  - `const MAX_FLASH_HZ: float = 3.0` — photosensitive flash cadence ceiling (UX A1; arch D14; enforced centrally on the coordinator).
  - `const MAX_SHAKE_PX: float = 8.0` — clamp on shake amplitude so a miscalibrated tuning/`_motion_scale` can never seizure the screen.
  - Leave existing constants (layers, `BASE_RESOLUTION`, ships/HP) untouched.

### Task 2 — `Settings.reduced_motion` (accessibility input, D14) (AC: #5)

- [x] 2.1 `systems/settings.gd` — add `reduced_motion` access. The file **already** has `signal setting_changed(key: StringName, value: Variant)` (line 6) and `get_value`/`set_value` (ConfigFile-backed). Add typed accessors that persist through the existing mechanism and emit the existing signal — do not duplicate it:
  - `const REDUCED_MOTION_KEY := &"reduced_motion"`.
  - `func get_reduced_motion() -> bool:` → `return bool(get_value(REDUCED_MOTION_KEY, false))`.
  - `func set_reduced_motion(value: bool) -> void:` → `set_value(REDUCED_MOTION_KEY, value)` (this persists + emits `setting_changed(&"reduced_motion", value)` — the existing `set_value` already emits).
  - **Default `false`** for E1 (so the v0.1 feel gate evaluates *full* juice; A1 says "default-on *capable*", not required-on; the player-facing toggle ships at Story 8.4/E8). The ≤3 Hz cap is unconditional regardless.
  - **Do NOT build a settings panel/toggle UI** (E8, Story 8.4 — AR: explicitly do-not-pull-forward). A dev agent may be tempted to "helpfully" add a slider — don't.

### Task 3 — `JuiceTuning` resource (data-driven feel, AR10) (AC: #1, #4, #5)

- [x] 3.1 `juice/juice_tuning.gd` — `class_name JuiceTuning extends Resource`. Schema for all feel knobs (the playtest levers Story 1.8's gate tunes; zero code to retune). `@export_group`-ed fields:
  - **Screen shake** (px, pre-`_motion_scale`): `shake_enemy_hit_amount`, `shake_enemy_hit_dur`, `shake_player_hit_amount`, `shake_player_hit_dur`, `shake_kill_amount`, `shake_kill_dur`, `shake_heavy_mul` (multiplier for Bomber/heavy hits).
  - **Hit flash**: `flash_enemy_color: Color`, `flash_player_color: Color` (use hazard bright / near-white), `flash_duration: float` (~0.08 s).
  - **Particles**: per-effect `amount`, `lifetime`, `spread_rad`, `initial_speed`, `scale`, `color` for `hit_spark` / `explosion` / `muzzle` (store as a small `Dictionary` or three `@export` sub-groups — dev's choice, but data-driven).
  - **Motion**: `motion_scale_reduced: float = 0.3` (the dampen applied when `reduced_motion` — see Open Question Q1; 0.3 matches arch D14 code literal).
  - Sensible neon defaults (cyan-ish for player-affiliated, hazard-red/amber for enemy, additive glow). These are starting values, not final — Story 1.8 owns the feel pass.
- [x] 3.2 `resources/juice_tuning.tres` — instance the resource with those defaults. (Mirrors the `player_tuning.gd`+`player_tuning.tres` schema-pair pattern from 1.2/1.5.)
- [x] 3.3 Load it on the `JuiceCoordinator` via `@export var tuning: JuiceTuning` (inspector-assigned in `arena.tscn`), NOT a `load("res://...")` in gameplay code (AR8/D9 — content through resources/inspector). Fall back to a safe default (`JuiceTuning.new()`) if unassigned (AR11 fail-safe, `Log.warn` once).

### Task 4 — `ScreenShake` (Camera2D-driven) (AC: #1)

- [x] 4.1 Add a **`Camera2D`** as a child of the `JuiceCoordinator` node in `arena.tscn` (see Task 7/10). Configure it so the idle view is pixel-identical to today's no-camera arena:
  - `position = Constants.BASE_RESOLUTION / 2.0` (640, 360) — centers the 1280×720 view.
  - `zoom = Vector2.ONE`; `anchor_mode = ANCHOR_MODE_FIXED_START` or `DRAG_CENTER` (verify the play-field renders identically; see Gotcha).
  - `position_smoothing_enabled = false` (smoothing fights per-frame shake offsets; the coordinator drives `offset` directly).
  - `enabled = true` (it becomes the arena's active camera). Leave `limit_*` defaults (no crop).
- [x] 4.2 `juice/screen_shake.gd` — shake helper (a `Node` the coordinator owns, or pure functions called from the coordinator's `_process`). Algorithm (trauma-style, cheap, no per-frame allocs):
  - State: `_trauma: float` (0..1), accumulated by incoming requests; decays in `_process(delta)`.
  - `request(amount: float, duration: float) -> void` — convert to a trauma bump clamped to 1.0 (e.g. `amount / MAX_SHAKE_PX`); track the decay window. Multiple near-simultaneous requests **add** (a kill + a player-hit in the same frame shakes harder — reads right).
  - `_process(delta)` — decay trauma; set `camera.offset = _unit_random() * trauma * trauma * MAX_SHAKE_PX * _motion_scale`. Hoist a single reused `Vector2` for the offset (NFR3: no per-frame `Vector2(...)` alloc — mutate in place). Cache `_unit_random` via a seeded `RandomNumberGenerator` (determinism-leaning, NFR10 — though shake is cosmetic, a seeded RNG is the project default).
  - When `trauma <= 0.0`: `camera.offset = Vector2.ZERO`; `set_process(false)` (no work when idle — NFR2/AR14).
  - Apply `_motion_scale` here (dampen amplitude; **do not** skip the shake entirely — dampen, don't remove, D14).
- [x] 4.3 Extract the random-offset + decay as pure-ish logic where practical so `tests/juice/` can assert: a request increases trauma; `_process` decays it to zero and zeroes the offset; `MAX_SHAKE_PX` is never exceeded; `_motion_scale` scales the offset.

### Task 5 — `HitFlash` (entity flash + central ≤3 Hz cadence gate) (AC: #1, #5)

- [x] 5.1 `juice/hit_flash.gd` — entity hit-flash with a **single global cadence gate** (the photosensitive cap). This is the load-bearing accessibility invariant — the UX accessibility review (`ux-designs/.../validation-report.md:97-101`, `review-accessibility.md:153-160`) explicitly directs: *the ≤3 Hz cap is enforced **centrally on the coordinator** (one global hit-flash cadence gate), not summed across emitters*.
  - State: `_last_flash_time: float` (secs), `_active_tweens: Array[Tween]` (or track one tween per target — see below).
  - `request(target: Node2D, color: Color, duration: float) -> void`:
    - **Gate:** `if Time.get_ticks_msec() / 1000.0 - _last_flash_time < (1.0 / Constants.MAX_FLASH_HZ): return` (drop the request — the central cap; this is the photosensitive safety, applied *before* `_motion_scale` and regardless of `reduced_motion`).
    - Otherwise record `_last_flash_time = now`, and tween `target.modulate` → `color` then back to the original over `duration * _motion_scale` (dampen duration, don't remove the flash). Use a `SceneTreeTween` via `get_tree().create_tween()`; cap concurrent tweens per target (kill the previous tween on that target so a rapid re-hit replaces rather than stacks — keep a `Dictionary[Node2D, Tween]`).
    - Guard: if `not is_instance_valid(target)` or `target` is not a `CanvasItem` → `Log.warn` once + return (AR11). Cache the target's original `modulate` to restore it (don't assume white).
  - The flash is an **entity-sprite** flash (modulate the hit body so its visual child inherits it). A separate *screen*-flash is **out of scope** for E1 (deferred to E8 polish) — if added later it MUST go through this same gate.
- [x] 5.2 Unit-test the gate as pure logic if separable: 3 requests within 1/3 s → only the first acts; the 4th at >1/3 s acts. `MAX_FLASH_HZ` respected.

### Task 6 — `ParticleBurst` pooled scene (GPUParticles2D via `Pool`) (AC: #3)

- [x] 6.1 `juice/particle_burst.tscn` + `juice/particle_burst.gd` — a pooled one-shot particle burst. Root = `GPUParticles2D` (AC3 + arch line 144; works in the Compatibility renderer). Script `class_name ParticleBurst extends GPUParticles2D`.
  - `one_shot = true`, `emitting = false` (armed on activate), `visibility_local_to_parent`/`local_coords` as needed. Use an **additive** blend (`ParticleProcessMaterial` with `blend_mode = BLEND_MODE_ADD`) for the neon glow read.
  - **Procedural texture (asset-free, on-pattern):** generate a small soft white radial-gradient `ImageTexture` **once** (static cache on the script, built lazily in `_ready`/`activate` from an `Image` — the codebase is all vector/Polygon2D art with no sprite textures; do not introduce a .png). Tint per-spawn via `self.modulate` / the material's `color`.
  - `func activate(effect: StringName, at: Vector2, color: Color, profile: Dictionary) -> void` — the pool re-init entry (NEVER `_ready()`). Set `global_position = at`; set `modulate = color`; configure `amount`, `lifetime`, `direction`/`spread`, `initial_velocity_min/max`, `scale_min/max`, `gravity` from `profile` (the JuiceCoordinator looks these up from `JuiceTuning`); `emitting = true`; arm a self-release `Timer` (see 6.2). This is the ONLY re-init path.
  - `_ready()` (runs once for the first instance only) — bake the shared texture if not cached. Do not put spawn/positioning logic here.
- [x] 6.2 **Self-release via `Timer`** (Pool contract, NFR4): a one-shot `Timer` child (or a `_process` lifetime accumulator) set to `lifetime + small_margin`; on timeout → `Pool.release(self)` (synchronous release is fine here — it is NOT inside a physics callback). Never `queue_free()`. The coordinator's `_deactivate` (from `Pool`) sets `emitting = false`, `visible = false`, `process = false`.
  - Note: `GPUParticles2D` has no reliable `finished` signal across Godot 4.x — a `Timer(lifetime)` is the robust release trigger.
- [x] 6.3 `Pool` needs no changes — `acquire(particle_scene)` lazy-instantiates and `release()` deactivates generically (confirmed: `_deactivate` toggles `visible`/`process` for `CanvasItem`; `GPUParticles2D` is a `CanvasItem` ✓; it is not an `Area2D` so `monitoring` doesn't apply). Verify reuse is LIFO and idempotent (existing `tests/systems/test_pool.gd` pattern).

### Task 7 — `JuiceCoordinator` (arena-scoped conductor) (AC: #1, #2, #5)

- [x] 7.1 `juice/juice_coordinator.gd` — `class_name JuiceCoordinator extends Node2D`. Lives in `arena.tscn` (Task 10), **not** an autoload (AR9 — absent from the 11-autoload registry; auto-disabled in menus because menu scenes don't include it). Owns:
  - `@export var tuning: JuiceTuning` (Task 3.3).
  - `@onready` children: `_camera: Camera2D` (Task 4), `_shake: ScreenShake` (Node child), `_flash: HitFlash` (Node child), a `Node2D` particle container (or host particles directly — coordinator is `Node2D` at arena origin so child `global_position` == world position).
  - `var _motion_scale: float = 1.0` — propagated to `_shake` and `_flash`.
  - `_ready()`:
    - `EventBus.screen_shake_requested.connect(_on_shake_requested)`
    - `EventBus.hit_flash_requested.connect(_on_flash_requested)`
    - `EventBus.particles_requested.connect(_on_particles_requested)`
    - `Settings.setting_changed.connect(_on_setting_changed)`
    - Seed `_motion_scale = 0.3 if Settings.get_reduced_motion() else 1.0` (read current state on start, then react to changes).
    - Cache a reused burst-config `Dictionary` on the coordinator (NFR3 — no per-event `Dictionary.new()`; mutate in place in `_on_particles_requested`).
  - Handlers:
    - `_on_shake_requested(amount, duration)` → `_shake.request(clampf(amount, 0.0, MAX_SHAKE_PX), duration)`.
    - `_on_flash_requested(target, color)` → `_flash.request(target, color, tuning.flash_duration)`.
    - `_on_particles_requested(effect, at, color, scale)` → look up the effect profile from `tuning` → `var burst := Pool.acquire(PARTICLE_SCENE) as ParticleBurst` → `particle_container.add_child(burst)` → `burst.activate(effect, at, color, profile_scaled_by(scale))`. Preload `PARTICLE_SCENE` once (`const`/`preload`) — never `load("res://...")` per event.
    - `_on_setting_changed(key, value)` → `if key == &"reduced_motion": _motion_scale = (0.3 if bool(value) else 1.0)`; push `_motion_scale` into `_shake` and `_flash`.
- [x] 7.2 Confirm `JuiceCoordinator` is NOT registered in Project Settings → Autoload (the registry stays at 11). It is a scene node only.

### Task 8 — `AudioManager` (basic synthwave SFX, D11/D12) (AC: #4)

- [x] 8.1 `systems/audio_manager.gd` — replace the stub `play_sfx`. Build the v0.1 SFX pipeline (the in-code comment explicitly defers this to 1.6; full synthwave pass is Story 8.5):
  - **Buses:** add an audio bus layout — at minimum `Master` + `SFX` (+ `Music` for forward-compat, even if unused in E1). Do this via a `default_bus_layout.tres` checked into the project (created/edited in the Audio panel) OR the `[audio]` section of `project.godot`; route SFX players to the `SFX` bus.
  - **Pooled players:** a small fixed pool of `AudioStreamPlayer` nodes (e.g. 8) on the AudioManager, each routed to `SFX`. `play_sfx` finds a free (non-playing) player; if all busy, either interrupt the oldest or drop (dev's call — prefer interrupt-oldest for fire/hit so nothing audibly vanishes). Never `instantiate()`+`queue_free()` a player per SFX.
  - `func play_sfx(stream: AudioStream, pitch: float = 1.0, volume_db: float = 0.0) -> void` — set `stream`, `pitch_scale`, `volume_db` on a free player; `play()`. `pitch` lets callers randomize ±5% so rapid fire/hit doesn't grate (FR48/NFR12 punch).
  - **Synth streams (asset-free, on-pattern):** synthesize short PCM stabs **in code** as in-memory `AudioStreamWAV` at `_ready` (build `PackedByteArray` of 16-bit samples with a fast-decay envelope over a sine/square/noise waveform), cache them as `sfx_fire` / `sfx_hit` / `sfx_kill` (`AudioStreamWAV.data`, `format = FORMAT_16_BITS`, `mix_rate = 44100`, `loop_mode = LOOP_DISABLED`). This is genuinely a "synthwave punch" with **zero asset files** and is AI-authorable (no binary .wav needed). Alternative: commit tiny generated `.wav` placeholders under `assets/sfx/` — either is acceptable for v0.1; pick synthesis for zero-asset cleanliness.
  - **No music in E1** (full synthwave music is Story 8.5) — leave a `Music` bus and a stub `play_music`/`stop_music` if trivial, but do not block on it.
- [x] 8.2 Expose the cached streams so emit sites call `AudioManager.play_sfx(AudioManager.sfx_fire, pitch)` — OR give `AudioManager` typed event helpers (`play_fire()`, `play_hit(heavy: bool)`, `play_kill()`) that own the stream + variation. Prefer the typed helpers (keeps emit sites one-liners and centralizes the stream choice). `AudioManager` is a thin autoload service — calling it from projectiles/fire_system is fine (it is not gameplay logic, just a service).

### Task 9 — Wire the emit sites + refine player i-frame cue (AC: #1, #4)

> Juice requests are emitted from the **impact source** (Key Decision #1). Each hook is one or two lines that fire the relevant signal subset + SFX. Keep the existing damage/death/score logic intact — add the juice emit alongside it.

- [x] 9.1 `player/projectile.gd` — in `_on_body_entered`, **after** `hc.take_damage(_damage)` and the `_consumed` guard (so it runs exactly once per shot), emit impact juice on the enemy hit:
  - `EventBus.hit_flash_requested.emit(body, _hit_color)` (enemy body; cascade-flashes its visual).
  - `EventBus.screen_shake_requested.emit(tuning.shake_enemy_hit_amount, tuning.shake_enemy_hit_dur)` — but `Projectile` doesn't currently hold `JuiceTuning`; either read amplitudes from a cached tuning (`const` preload of `juice_tuning.tres` is acceptable here since it is data, but prefer a static/global accessor to avoid each projectile holding a ref) — simplest: emit a fixed effect id and let the coordinator apply tuning: `EventBus.particles_requested.emit(&"hit_spark", global_position, _hit_color, 1.0)`.
  - `AudioManager.play_hit()` (or `play_sfx(sfx_hit, randf*0.1+0.95)`).
  - **Position:** use `global_position` (the projectile's contact point). **Do not** change the deferred `Pool.release.call_deferred(self)` or the `_consumed` semantics.
  - *Factoring tip:* to avoid scattering 3 `emit` calls per site, a tiny `EventBus`-namespaced helper or a static `JuiceFx` helper (`JuiceFx.impact(at, color, shake_amt, shake_dur)`) is fine and encouraged — but the underlying mechanism MUST be these EventBus signals (AC1 mandates them). Dev's choice; keep it DRY.
- [x] 9.2 `enemies/enemy_projectile.gd` — mirror 9.1 for the player-hit (the inverse faction): flash the player body in `flash_player_color` (hazard), shake with `shake_player_hit_amount` (heavier), spawn `&"hit_spark"` in hazard color, `AudioManager.play_hit(heavy=_heavy)`. If `_heavy` (Bomber), scale up (`shake_heavy_mul`, bigger particle `scale`, lower-pitch SFX). Expose `_heavy` (it is private today) — add a tiny accessor or read it where the emit happens (the emit is inside `_on_body_entered`, which already has `_heavy` in scope).
- [x] 9.3 `enemies/enemy.gd` — in `_on_died`, **after** `died.emit(definition.score_value)` and **before** `_release_to_pool.call_deferred()`, emit death juice (the enemy is about to be released, so spawn the burst at `global_position` now — the particle is a separate pooled node that persists):
  - `EventBus.particles_requested.emit(&"explosion", global_position, definition.silhouette_color, definition.silhouette_scale)` (Bomber = bigger via `silhouette_scale`).
  - `EventBus.screen_shake_requested.emit(tuning_or_const_shake_kill_amount, shake_kill_dur)`.
  - `AudioManager.play_kill()`.
  - **Crucially:** emit on `_on_died` (kill) ONLY. Do **not** touch `despawn()` (wave-end survivor path — no juice). Capture `global_position` before the deferred release (the node stays valid until idle; the emit is synchronous now, so position is valid).
- [x] 9.4 `player/fire_system.gd` — in `_spawn`, after `p.activate(...)` and `projectile_parent.add_child(p)`, fire the **on-fire** juice (AC4 mandates fire SFX; muzzle particles are a light optional touch):
  - `AudioManager.play_fire()` (pitch ±5% so the ~6 Hz autofire breathes).
  - (Optional, light) `EventBus.particles_requested.emit(&"muzzle", _muzzle.global_position, muzzle_color, 0.6)` — small muzzle puff.
  - **Update the stale comment** (lines 1–8): it says "emits nothing to EventBus" — that was true for *game-flow* signals in 1.3 (fire is not game-flow). Juice *request* signals are a different, allowed channel (D8). Reword the comment to clarify fire emits **juice requests only**, no game-flow.
- [x] 9.5 `player/player.gd` — refine the i-frame cue (replace the 1.5 placeholder):
  - The **impact** hit-flash is now driven by `JuiceCoordinator` via the `enemy_projectile` emit (9.2) — do not add a second flash path on the player.
  - The **sustained i-frame pulse** stays here (it's a持续 state, not an event): keep a cheap, calmer modulation while `is_invulnerable()` (e.g. a gentler alpha pulse, or a brief outline), and remove the `"placeholder; Story 1.6 owns the juice pass"` comment + the `_flicker_t` tag-on-placeholder wording. Keep it zero-cost when vulnerable (`set_process(false)` or `else: restore`).
  - Do NOT add a player-death-specific juice path for E1 (death → respawn/game-over is the Arena's flow; a bigger death shake can react to `EventBus.ship_lost` on the coordinator later — optional, defer if time-boxed).

### Task 10 — `arena.tscn` integration + Camera2D regression (AC: #2)

- [x] 10.1 `world/arena.tscn` — add the `JuiceCoordinator` node (Node2D) as a child of `Arena`, with its `Camera2D` + `ScreenShake` + `HitFlash` children (Task 4/5/7). Assign `tuning = juice_tuning.tres` in the inspector. The coordinator at `Arena` origin (0,0) hosts world-space particles correctly.
- [x] 10.2 **Camera2D regression check (non-negotiable):** adding the camera must NOT change the idle framing. Verify by a test that asserts the player/spawner positions still render in-screen (or visually in-editor): with `_trauma == 0`, `camera.offset == Vector2.ZERO` and the 1280×720 play-field is fully visible, uncropped, unshifted. If the camera anchors wrong (e.g. `DRAG_CENTER` shifts the view), fix the `anchor_mode`/`position`. See Gotcha §"Camera2D".
- [x] 10.3 The JuiceCoordinator auto-disables on scene reload (game-over replay) because it is a child of the arena scene — `Arena._end_run()`'s `reload_current_scene()` frees it cleanly and the fresh scene instantiates a new one. No extra teardown needed.

### Task 11 — Tests (GUT, `tests/juice/` + `tests/systems/`) (AC: all)

- [x] 11.1 `tests/juice/test_juice_coordinator.gd` (integration, `extends GutTest`, `before_each` → `Pool.clear()`): instantiate a coordinator (+camera/shake/flash); emit `EventBus.screen_shake_requested` → assert shake trauma rises + `_process` decays it and zeroes the offset + amplitude never exceeds `MAX_SHAKE_PX`; emit `hit_flash_requested(target, color)` → assert the target's `modulate` tweens toward `color`; emit `particles_requested` → assert a `ParticleBurst` was acquired from the Pool, added to the tree at the requested position, and is released after `lifetime` (await a few frames + the timer). Reduced-motion: flip `Settings.set_reduced_motion(true)` → assert `_motion_scale == 0.3` (or the chosen value) and that a shake request yields a smaller offset. Use `add_child` for pooled nodes (NOT `autofree`), `await get_tree().physics_frame` for engine/tween timing.
- [x] 11.2 `tests/juice/test_hit_flash.gd` (the cadence gate — pure-ish logic if extracted, else integration): 3 `hit_flash_requested` within 1/3 s → only the first modulates the target; a 4th after >1/3 s modulates again. `MAX_FLASH_HZ == 3.0` honored. **This is the photosensitive-safety test — it must exist.**
- [x] 11.3 `tests/systems/test_audio_manager.gd` (new; mirror `tests/systems/test_pool.gd`): `play_sfx` with a synthesized stream → a pooled player's `playing == true`; rapid `play_sfx` beyond pool size does not error (interrupt/drop handled); pitch/volume applied. Synthesis is deterministic (same seed/waveform → same stream) so assert the cached stream is non-null + correct `mix_rate`/`format`.
- [x] 11.4 `tests/juice/test_particle_burst.gd` (pool round-trip): `Pool.acquire(particle_scene)` → `activate(...)` → emitting true → after lifetime `Pool.release` called → re-`acquire` returns the same instance (LIFO, `get_instance_id` equality — the `test_pool.gd` pattern); `activate` re-arms `emitting` on a reused instance (regression guard for the "never `_ready()` re-init" rule).
- [x] 11.5 **Regression:** run the full existing suite — every 1.1–1.5 test stays green (the juice emits are additive; no behavior change to damage/death/score/i-frames). Especially `tests/enemies/test_enemy.gd::test_player_projectile_damages_enemy`, `tests/player/test_projectile.gd`, `tests/components/test_health_component.gd`, `tests/world/test_arena.gd`.

### Task 12 — Regression, housekeeping, verification (AC: all)

- [x] 12.1 `godot --headless --import` once (registers the new `class_name`s — `JuiceCoordinator`, `ScreenShake`, `HitFlash`, `ParticleBurst`, `JuiceTuning` — and the new `@export`s/`@export_group`s; the established gotcha from 1.1/1.2/1.4/1.5 reviews).
- [x] 12.2 Full GUT suite headless: `godot --headless -s addons/gut/gut_cmdln.gd`. All prior tests pass + new juice/audio tests pass. `before_each()` calls `Pool.clear()` in every new test file (Pool is an autoload — state persists across tests).
- [x] 12.3 Remove the `.gdkeep` placeholders from `juice/` and `tests/juice/` (now populated). Leave `assets/.gdkeep` unless audio assets were committed.
- [x] 12.4 Headless game launch (`timeout 8 godot --headless --path .`): no runtime errors; fire (SFX), hit an enemy (flash+spark+shake+SFX), kill an enemy (explosion+shake+sting), take a hit (player flash+shake+spark+SFX), i-frame pulse visible — all without exceptions, and the fixed-screen layout is unchanged with the new camera. Confirm juice does not fire on wave-end despawns.
- [x] 12.5 Headless perf sanity: a busy firefight (10+ projectiles, several simultaneous enemy deaths) holds frame budget — particle bursts come from the pool (no `instantiate()` storm), no per-frame allocations in the coordinator's `_process` (the reused-offset discipline).

### Review Findings

- [x] [Review][Decision→Patch] Pooled entity reuse can inherit a stale in-flight hit-flash tween — **Resolved:** skip the sub-lethal hit-flash entirely on a killing blow (`player/projectile.gd`'s `_on_body_entered` now checks `hc.current_hp <= 0` after `take_damage` and only calls `JuiceFx.enemy_hit()` when the enemy survived). This matches the tuning table's own intent (a kill's flash column is "— it's exploding", no flash) and removes the only path where a flash tween could still be animating on a pooled `Enemy` node at the moment it's released — since sub-lethal hits never trigger a release, the reuse race can no longer occur. Regression test: `tests/player/test_projectile.gd::test_lethal_hit_does_not_fire_hit_flash_juice` (+ `test_sublethal_hit_fires_hit_flash_juice` confirming the surviving-hit path still flashes). [player/projectile.gd]
- [x] [Review][Decision] SFX buses created at runtime via `AudioServer` instead of the spec's two prescribed methods — **Resolved: leave as-is** (Mrdth, 2026-07-05). Functionally correct and tested; the editor-visible `default_bus_layout.tres` alternative isn't worth the rework for v0.1.
- [x] [Review][Patch] Particle bursts ignore `reduced_motion` entirely (AC5 gap) — **Fixed:** `_on_particles_requested` now scales the profile's `speed` and `scale` fields by `_motion_scale` (count/lifetime/spread/gravity left alone so the burst is still clearly present, just calmer). Regression test: `tests/juice/test_juice_coordinator.gd::test_reduced_motion_dampens_particle_amplitude`. [juice/juice_coordinator.gd:55]
- [x] [Review][Patch] ScreenShake decay rate recomputed from total accumulated trauma, not just the new bump — **Fixed:** replaced the per-request `decay_rate` recompute with a delta-accumulated `_decay_end_time` that a request only ever pushes further out (never pulls in), so the longest-pending shake governs the tail instead of being truncated by a later short/small hit. Regression test: `tests/juice/test_juice_coordinator.gd::test_shake_short_hit_does_not_truncate_a_longer_shake_already_decaying`. [juice/screen_shake.gd]
- [x] [Review][Patch] Enemy hits during player i-frames still fire full juice for a no-op hit — **Fixed:** `EnemyProjectile._on_body_entered` now captures `hc.is_invulnerable()` before calling `take_damage`, and only fires `JuiceFx.player_hit(...)` when it was false. Regression test: `tests/enemies/test_enemy_projectile.gd::test_hit_during_iframes_does_not_fire_juice`. [enemies/enemy_projectile.gd]
- [x] [Review][Patch] Camera regression test doesn't cover the real `arena.tscn` scene — **Fixed:** added `tests/juice/test_juice_coordinator.gd::test_arena_scene_camera_idle_framing_is_unchanged`, which instantiates the real `ArenaScene`, reads its actual `Camera2D` node, and asserts `position`/`anchor_mode`/`position_smoothing_enabled` plus the idle `offset`/screen-center — so a future edit to the shipped scene's camera is now caught. [tests/juice/test_juice_coordinator.gd]
- [x] [Review][Incidental fix] Pre-existing flaky test discovered while verifying the patches above — `test_hit_flash_requested_tweens_target_modulate` relied on a single `await get_tree().process_frame` to catch a short (0.08s) Tween mid-flight; in this environment a single frame can complete the entire flash-and-restore before the assert runs (observed: the whole round-trip finished within ~3ms of real time, and `create_timer(...).timeout` was equally unreliable). Rewrote it to use `Tween.custom_step(delta)`, which manually advances the tween by an exact simulated delta independent of real/simulated frame timing. Not one of the original review findings — unrelated to this story's patches — but needed fixing to get to a green suite. [tests/juice/test_juice_coordinator.gd]
- [x] [Review][Defer] Default tuning already exceeds `MAX_SHAKE_PX`, clamp is silent [resources/juice_tuning.tres, juice/juice_coordinator.gd:46] — deferred, pre-existing tuning is explicitly provisional (Story 1.8 owns the feel pass); `shake_player_hit_amount * shake_heavy_mul = 9.0 > MAX_SHAKE_PX (8.0)`, clamped with no `Log.warn` unlike other fail-safe paths.
- [x] [Review][Defer] Two independent sources of the same `JuiceTuning` data (`juice/juice_fx.gd`'s own preload vs. `JuiceCoordinator`'s `@export`) [juice/juice_fx.gd:15] — deferred, pre-existing sanctioned as an acceptable DRY choice per Task 9.1; only a risk if/when a scene variant assigns the coordinator a different `JuiceTuning` instance.
- [x] [Review][Defer] `JuiceTuning.get_effect_profile()` returns a cached Dictionary by reference with no defensive copy despite a documented immutability contract [juice/juice_tuning.gd] — deferred, pre-existing only caller today copies fields out safely; a future caller could mutate the shared cache.
- [x] [Review][Defer] `AudioManager`'s interrupt-oldest heuristic compares raw playback position across differently-pitched streams, an imprecise proxy for "oldest" [systems/audio_manager.gd] — deferred, pre-existing low-severity audio polish, no test asserts which player gets interrupted.
- [x] [Review][Defer] `HitFlash` cadence-gate tests use real wall-clock timers with margins close to the 333ms threshold [tests/juice/test_hit_flash.gd] — deferred, pre-existing could flip under CI scheduling jitter; consider widening margins or a fake clock for the pure `is_flash_allowed` seam.
- [x] [Review][Defer] Global HitFlash gate suppresses most flashes during dense multi-enemy combat [juice/hit_flash.gd] — deferred, pre-existing this is the explicit spec-mandated design (Key Decision #7), not a defect; flagged as a feel-tension worth knowing for Story 1.8's tuning pass.

---

## Dev Notes

### 🔑 Key decisions (read these first — they resolve the open forks the architecture left to this story)

1. **Juice is emitted from the impact SOURCE (projectiles / `enemy._on_died` / `fire_system`), NOT from a new signal on `HealthComponent`.** The projectile that causes the impact already knows the contact `global_position`, the severity, and the faction; its `_on_body_entered` runs exactly once per shot (`_consumed` guard). Adding a `damaged`/`hit_taken` signal to the shared `HealthComponent` would (a) churn the shared component and its 18 GUT tests, (b) lose the precise contact point (it'd have to use entity-center), and (c) risk double-firing on lethal hits. So: emit `EventBus` juice requests at the impact sites. `HealthComponent`, `health_changed`, and `died` are **untouched**.
2. **No `HitboxComponent`/`HurtboxComponent` in 1.6.** Despite `project-context.md` listing them, they were never built (confirmed: only `health_component`, `faction_component`, `state_machine` exist in `components/`). Damage flows via the node-name `HealthComponent` lookup (1.4 key decision #2; explicitly deferred "until multi-shape hitboxes are needed" — the docked-ship bigger hitbox, Story 2-4). Juice hooks the existing `_on_body_entered` call sites. Do NOT introduce hitbox/hurtbox components here — it is scope creep that would force reworking both projectile hit paths.
3. **`JuiceCoordinator` is a scene node in `arena.tscn`, NOT an autoload.** This is non-negotiable (AR9): juice is run-scoped feel, not a thin global service. Arena-scoping gives "auto-disabled in menus" (UX F8) for free — menu scenes don't include the node, so no shake/flash/particles there. The autoload registry stays at 11. The coordinator is destroyed and recreated on game-over replay (clean).
4. **Screen-shake needs a `Camera2D`, which does not exist yet.** Add it as a child of the coordinator in `arena.tscn`, configured so the idle view is pixel-identical to today (Task 4.1, 10.2). The shake drives `camera.offset` (not `position`) with smoothing off, so it doesn't fight the physics/transform. This is the highest-regression-risk change — verify the framing.
5. **Particles are `GPUParticles2D`, pooled, with a procedurally-generated texture.** AC3 + arch line 144 say `GPUParticles2D` (works in the Compatibility renderer). The codebase has **zero sprite textures** (all `Polygon2D` vector art) and `assets/` is empty — so generate a soft white radial-gradient `ImageTexture` once (cached) and tint per-effect (`modulate`). This stays on-pattern (vector, asset-free) and avoids shipping binary art. (`CPUParticles2D` is a fallback if GPU particles misbehave on target hardware, but the spec says GPU.)
6. **Audio is synthesized in-code (`AudioStreamWAV`), not asset files.** `assets/` has no audio and an AI dev cannot author binary `.wav`s cleanly. Build short PCM stabs (sine/square/noise + decay envelope) into in-memory `AudioStreamWAV`s at `AudioManager._ready`. This is a real "synthwave punch" with zero asset files. The full synthwave music/SFX pass is Story 8.5.
7. **The ≤3 Hz flash cap is ONE central gate on the `JuiceCoordinator`'s `HitFlash`, applied before everything else.** Per the UX accessibility review, a per-emitter cap could let overlapping sources stack above 3 Hz aggregate. So the coordinator drops any `hit_flash_requested` that arrives within `1/MAX_FLASH_HZ` of the last one. This is unconditional (not gated by `reduced_motion`) — photosensitive safety is not optional (A1). Reduced-motion separately dampens *amplitude* (shake/particle/flash magnitude), never removing the feedback.
8. **E1 scope is the *basic* juice slice.** The maximalist register (UX EXPERIENCE.md §Game Feel & Juice) — floating score popups, damage vignette, controller rumble, palette-arc crank at the godhood peak — is OUT of scope here (their owning stories: popups→1.7 HUD, vignette/rumble→E8 polish, palette arc→3.9). Build the scaffolding (coordinator + signals + reduced-motion + ≤3Hz + pooled particles + SFX pipeline) and the basic impact/fire/kill juice; do not gold-plate.

### 📊 Juice — values (starting feel-knobs in `juice_tuning.tres`; Story 1.8 owns the final pass)

| Effect | Shake (px / s) | Flash | Particles | SFX | Source |
|---|---|---|---|---|---|
| Player bullet hits enemy (sub-lethal) | ~2.0 / 0.10 | enemy body, ~0.08 s | `hit_spark`, ~6, cyan/white | `play_hit()` | UX §Juice "On enemy kill"-lite |
| Enemy bullet hits player | ~6.0 / 0.20 | player body, hazard color | `hit_spark`, ~8, hazard red | `play_hit()` | UX "On hit taken" |
| Heavy (Bomber) hits player | × `shake_heavy_mul` (×1.5) | same, brighter | bigger `scale`, amber | `play_hit(heavy=true)` lower pitch | FR43 heavy 2 dmg |
| Enemy killed | ~4.0 / 0.15 | — (it's exploding) | `explosion`, ~14, faction color | `play_kill()` sting | UX "On enemy kill" |
| Player fires | — (no shake on fire) | — | `muzzle`, ~4, cyan (optional) | `play_fire()` ±5% pitch | AC4 |
| Player ship lost (i-frames active) | — | impact flash via 9.2; sustained pulse in `player.gd` | — | — | 1.5 placeholder → refined |

*Amplitudes are pre-`_motion_scale` and clamped by `MAX_SHAKE_PX` (8.0). All values are starting points for the 1.8 feel gate — data in `.tres`, zero code to retune.*

### Signal boundary (AR7 / D8)

- **EventBus** (global — the ONLY thing added to the bus this story): `screen_shake_requested(amount, duration)`, `hit_flash_requested(target, color)`, `particles_requested(effect, at, color, scale)`. These are **request** signals (imperative `_requested`, per D8's "imperative for requests" convention). Emitters: projectiles / `enemy._on_died` / `fire_system`. Consumer: `JuiceCoordinator` (arena scene).
- **Direct/local signals** (unchanged): `HealthComponent.health_changed`/`died`, `enemy.died(score_value)`, `player.ship_depleted`. Juice does NOT add local signals.
- **Do NOT** add `player_hit`/`enemy_killed`/`damaged` to the bus — the three request signals above carry everything juice needs. Score already rides `score_changed` (existing). Death-of-enemy-as-a-global-event is **not** needed on the bus; the enemy emits juice requests directly in its own `_on_died` (it has `global_position`).
- **EventBus is the right channel for juice requests** because emitter and consumer are not in the same entity subtree (D8 explicitly blesses this). It is NOT "routing everything through the bus" — these are 3 focused feedback signals.

### Collision layers (unchanged — no `constants.gd` layer change)

```gdscript
const LAYER_PLAYER: int = 1            # bit 0
const LAYER_ENEMY: int = 2             # bit 1
const LAYER_PLAYER_PROJECTILE: int = 4 # bit 2
const LAYER_ENEMY_PROJECTILE: int = 8  # bit 3
const LAYER_PICKUP: int = 16           # bit 4
```
Juice adds no new layer — particles are pure visuals (`GPUParticles2D` on no collision layer/mask; they don't participate in physics).

### Gotchas that will bite

- **Camera2D framing (the #1 regression risk).** Godot 4 `Camera2D` default `anchor_mode = DRAG_CENTER` centers the camera on its position — at `position = (640,360)` with `zoom = ONE` this shows (0,0)–(1280,720), matching today. But if the camera is at (0,0) with `DRAG_CENTER`, the view shifts to (−640,−360)–(640,360) and the play-field appears off-screen/cropped. **Pin `position = BASE_RESOLUTION/2`** and verify. Also disable `position_smoothing_enabled` (smoothing lags the shake offsets and makes it feel mushy + can drift the framing).
- **Physics-callback safety.** Juice emits fire from `_on_body_entered` (inside the physics step). *Emitting* a signal is safe; the coordinator's synchronous handler does `Pool.acquire` + `add_child` + `activate` (additive — allowed during physics). Only node **removal** is forbidden mid-physics, and particle release happens later via `Timer`. The deferred `Pool.release.call_deferred(self)` on the projectile itself stays exactly as-is.
- **Pooled particles release.** `GPUParticles2D` has no reliable `finished` signal in Godot 4.x — use a `Timer(lifetime + margin)` → `Pool.release(self)`. Never `queue_free()`. Re-`activate()` must re-arm `emitting = true` (the `_deactivate` from `Pool` won't have stopped a finished burst, but `visible=false` + `process=false` will — re-arm explicitly).
- **Kill vs despawn.** `Enemy._on_died` (juice ON) vs `Enemy.despawn()` (juice OFF). Wave-end survivor cleanup must NOT spawn explosions.
- **`_motion_scale` wording (0.3 vs 0.7).** Architecture code literal says `_motion_scale = 0.3`; UX prose says "~70% scale". They reconcile if "70% scale" means "reduce by 70% → 0.3", but it's genuinely ambiguous. It's **dormant in E1** (`reduced_motion` defaults false) so non-blocking — encoded as `motion_scale_reduced: float = 0.3` in tuning (Q1 for Mrdth).
- **GUT exit-leak warnings** ("leaked"/"orphan" at exit) are expected since 1.3 (Pool.clear() doesn't free nodes) — trust Passing/Failing counts, not the exit noise (per memory `gut-exit-leak-warnings-expected`).
- **`godot --headless --import`** after adding `class_name`s / `@export`s, or scenes/tests won't resolve them (every prior review flagged this).
- **No `print()`** — route through `Log`. No try/catch in GDScript — preconditions + `push_error`/`push_warning` + fail-safe (AR11/AR12).

### Out of scope for 1.6 (do NOT build — listed to prevent scope creep)

| Item | Owner | Why deferred |
|---|---|---|
| **`HitboxComponent`/`HurtboxComponent`** | Story 2-4 (docked-ship bigger hitbox) | Node-name `HealthComponent` lookup stays (1.4 key decision #2); juice hooks the call sites. |
| **Floating score popups** (`numeric-xl`, UX §Juice "On enemy kill") | Story 1.7 (HUD) | It's a text/HUD element on a `CanvasLayer`. 1.6 emits the SFX/sting + particles; the popup is HUD. |
| **Damage vignette** (`{colors.hazard}`, UX "On hit taken") | Story 8.5 (E8 polish) | Fullscreen effect needs a `CanvasLayer` + shader; not load-bearing for the kinesthetics gate. |
| **Controller rumble** (UX "On hit taken/hit landed") | E8 polish | Controllers aren't the E1 focus; `Input` rumble API + gamepad presence detection is its own pass. |
| **Palette-arc juice crank** (godhood-peak intensity) | Story 3.9 (`PaletteArcCoordinator`) | Requires the build engine; `arc_t` doesn't exist yet. |
| **Neon-vector glow shader** (FR47 "glow") | Story 8.5 (art pass) | No shaders exist in-repo yet; additive-blended particles carry the glowy read for v0.1. |
| **Full synthwave music + SFX set** | Story 8.5 (FR48) | 1.6 ships the `AudioManager` pipeline + basic fire/hit/kill stabs; the full audio pass is 8.5. |
| **Settings panel / reduced-motion toggle UI** | Story 8.4 (E8) | `reduced_motion` *property + consumer* lands now (D14); the player-facing toggle/slider is E8. |
| **Hit-stop / time-scale freeze on heavy hits** | Optional / E8 | Common juice technique, but not in the ACs; add only if time-boxed and non-regressing. |
| **Directional (source-biased) screen-shake** | E8 polish | E1 shake is omnidirectional random; UX "directional" is a refinement. |
| **Debug overlay visual toggles** (hitboxes/particles) | Story 1.8 (FR50) | `Debug` autoload is a stub. |

### Performance / hot-path (NFR2/NFR3/NFR4/NFR6, AR14)

- **Juice emits are event-driven** (on hit/death/fire), not per-frame — zero polling added. Projectile/enemy/fire_system emit sites are one-liners; no `find_child`/`get_node`/`$` added.
- **`JuiceCoordinator._process`** runs only while shake/flash is active — gate with `set_process(false)` when idle (the `ScreenShake`/`HitFlash` children self-disable). When active: one reused `Vector2` offset (no per-frame alloc), one `RandomNumberGenerator` call, decay arithmetic.
- **Particles via Pool** — never `instantiate()`+`queue_free()` per event (NFR4). Pre-warm is optional (the lazy pool warm-up on first acquire is acceptable for E1; if a first-hit hitch shows, prewarm a handful in `_ready`).
- **`AudioManager` pooled players** — fixed pool, reuse; no per-SFX instantiate.
- **No per-frame `Dictionary`/`Array`/`Vector2` allocations** in any `_process`/`_physics_process` (NFR3). Cache the burst-profile dict on the coordinator; mutate in place.
- Cache all node refs `@onready`; the coordinator preloads its `PARTICLE_SCENE` once (`const`).

### Testing (GUT — mirror the 1.3–1.5 patterns)

- `extends GutTest`; `before_each()` calls `Pool.clear()` (Pool is an autoload — state leaks across tests).
- `tests/juice/` (was `.gdkeep`) — coordinator integration, the ≤3Hz gate (the safety test), particle pool round-trip.
- `tests/systems/test_audio_manager.gd` — new; `play_sfx` pipeline (pooled players, pitch/volume, no error on overflow, synthesized stream non-null).
- Pooled nodes use plain `add_child` (NOT `autofree`) so GUT doesn't free a node the Pool still holds (the `test_enemy_projectile.gd:65` precedent).
- Tween/timer assertions: `await get_tree().physics_frame` in loops (manual stepping doesn't raise engine signals or advance tweens reliably).
- Reduced-motion test: flip `Settings.set_reduced_motion(true)` → assert `_motion_scale` and a dampened shake offset.
- **Regression:** all 1.1–1.5 tests stay green.

### Project Structure Notes

- **Co-located by domain (Option A):** new files live in `juice/` (the feedback+theming domain — arch lines 495–501), with one schema (`juice_tuning.gd`) + one data instance (`resources/juice_tuning.tres`), mirroring the `player_tuning.gd`+`resources/player_tuning.tres` pair. `tests/juice/` mirrors the domain (was `.gdkeep`).
- `juice/` intended contents after this story: `juice_coordinator.gd`, `screen_shake.gd`, `hit_flash.gd`, `particle_burst.gd` + `particle_burst.tscn`, `juice_tuning.gd`. (**NOT** `palette_arc_*` / `theme_tokens.gd` — those are Story 3.9; do not create them.)
- Modified files touch: `systems/` (`event_bus`, `audio_manager`, `settings`, `constants`), `player/` (`projectile`, `fire_system`, `player`), `enemies/` (`enemy_projectile`, `enemy`), `world/` (`arena.tscn`), `project.godot` (audio buses). `components/`, `run/`, `world/formation_spawner.gd`, `systems/pool.gd` are READ-ONLY (do not change behavior).
- `JuiceCoordinator` is **not** added to the autoload registry (verify `project.godot`'s 11 autoloads unchanged).
- Naming: scripts `snake_case.gd` (`juice_coordinator.gd`), `class_name PascalCase` (`JuiceCoordinator`), signals `snake_case` (`screen_shake_requested`), constants `UPPER_SNAKE` (`MAX_FLASH_HZ`). One root + one script per scene.
- No conflicts with the unified structure detected. `juice/.gdkeep` and `tests/juice/.gdkeep` removed (Task 12.3).

### Project Context Rules

*(Extracted from `_bmad-output/project-context.md` — follow exactly. When a rule conflicts with a design intent, flag Mrdth.)*

- **Engine:** Godot 4.6 (`config_version=5`, GDScript). Pin to 4.6.x; avoid 4.7-only APIs. **2D** (`Node2D`/`CharacterBody2D`/`Area2D`); Compatibility renderer (`gl_compatibility` — `GPUParticles2D` works here). Ignore the 3D/Forward+/Jolt defaults in `project.godot` — inert.
- **Juice is arena-scoped, not an autoload (AR9/D9):** `JuiceCoordinator` lives in the arena scene, listens to `EventBus` (`screen_shake_requested`/`hit_flash_requested`), particles via `Pool`. Auto-disabled in menus.
- **Accessibility wiring (D14, all shipping):** `reduced_motion` dampens shake/particles/hit-flash amplitude (~70% reduction → `_motion_scale = 0.3`), **dampen-don't-remove**; `HitFlash` enforces `MAX_FLASH_HZ = 3.0` **unconditionally** (photosensitive safety is not optional). Juice consumers read `Settings.reduced_motion` on change and apply `_motion_scale`.
- **Object pooling (AR6/D7/NFR4):** `Pool.acquire()`/`release()`; re-init via `activate()`/`reset()` — **never `_ready()`**; **never `queue_free()`** on the hot path. Projectiles AND particles AND pooled SFX players are pooled.
- **Signal boundary (AR7/D8):** typed signals; **past-tense for events, imperative for requests** (`wave_cleared`, `ship_lost` vs `screen_shake_requested`). Callable connect syntax. Global juice requests → `EventBus`; intra-entity → direct signals (unchanged).
- **No `print()` / no try-catch (AR11/AR12/NFR7):** route logging through `Log`. Preconditions + `push_error`/`push_warning` + fail-safe defaults; `assert` for dev-only invariants. Never hard-crash.
- **Hot-path discipline (NFR3/AR14):** no per-frame allocations in `_process`/`_physics_process` — hoist + reuse `Vector2`/`Array`/`Dictionary`; cache node refs `@onready`; `set_process(false)` when idle.
- **Static typing throughout (NFR7):** `var hp: int`, `func shake() -> void`, typed arrays; `@export`/`@export_range`/`@export_group` for tunables; constrain inspector values.
- **Content via resources (AR8/D9/AR10):** feel values in `.tres` tuning (`juice_tuning.tres`), immutable caps (`MAX_FLASH_HZ`, `MAX_SHAKE_PX`) in `Constants`. No `load("res://...")` in gameplay code — `@export`/`preload` once.
- **Audio (D11/D12):** engine-native `AudioStreamPlayer` + pooled SFX + buses (Master/SFX/Music); no middleware at v1.0.
- **Autoload order is fixed** (Constants → Log → EventBus → Settings → SeedManager → ContentRegistry → Pool → SaveManager → AudioManager → GameManager → Debug). `JuiceCoordinator` is NOT in this list. `AudioManager` (9th) loads after `Pool` — it can pool players at `_ready`.

### References

- **Story spec:** `planning-artifacts/epics.md` — Story 1.6 (lines 373–386); FR47 (line 111), FR48 (line 112); AR9 (line 149).
- **UX (source of truth for feel):** `planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/EXPERIENCE.md` — §Game Feel & Juice (lines 431–453: "Llamasoft maximalist", on-enemy-kill / on-hit-taken / juice-auto-disabled-in-menus / reduced-motion ~70%), §Accessibility Floor (lines 267–286: A1, ≤3 Hz flash cap, dampen-don't-remove). `validation-report.md` lines 97–101 & `review-accessibility.md` lines 153–160 — the ≤3 Hz cap is enforced **centrally on the coordinator**, not summed across emitters (load-bearing for the `HitFlash` design).
- **Architecture:** `planning-artifacts/architecture/architecture-meridian-run-2026-06-29/architecture.md` — D9/D14/AR9 juice (lines 149, 244–247 pooling, 291–304 accessibility wiring, 395–411 reduced-motion + `HitFlash` code pattern, 413–422 EventBus signal conventions, 495–501 `juice/` tree, 569 juice/theming row); `GPUParticles2D` pooled (line 144); `MAX_FLASH_HZ = 3.0` (line 301).
- **Project context:** `_bmad-output/project-context.md` — "Juice is arena-scoped" (line 60), pooling rules, signal boundary, accessibility wiring, hot-path discipline.
- **GDD:** `planning-artifacts/gdds/gdd-meridian-run-2026-06-29/gdd.md` — Art & Audio Direction (lines 301–309: neon-vector, synthwave/arcade-electronic, "juice… on the godhood peak").
- **Prior stories (read before implementing):**
  - `implementation-artifacts/1-5-life-and-health-economy.md` — **direct predecessor.** The i-frame `_visual.modulate.a` flicker in `player.gd._process` is the **placeholder this story replaces** (Dev Notes §"i-frame visual feedback"). The damage/death/score/wave/i-frame paths it established are the baseline (do not regress). Its File List is the code you extend.
  - `implementation-artifacts/1-4-enemy-types-and-formation-dive-ai.md` — node-name `HealthComponent` lookup (key decision #2 — no Hurtbox yet), pooled-enemy `activate()`/`reset()`, `enemy.died(score_value)`, the deferred-release physics hazard.
  - `implementation-artifacts/1-3-vertical-fire-system.md` — projectile pooling + `activate()`; the `fire_system._spawn` site; the "zero per-frame allocations" structural-test precedent.
  - `implementation-artifacts/1-2-player-movement-1-axis-chassis.md` — `CharacterBody2D` + component wiring; the tuning `.gd`+`.tres` schema pair (clone for `juice_tuning`).
  - `implementation-artifacts/1-1-project-scaffolding-and-core-systems.md` — `Constants` (layers, `BASE_RESOLUTION`), `EventBus` signal declarations, `Settings` ConfigFile, GUT setup, the 11-autoload registry.
- **Code to read/edit (read fully before editing):**
  - `systems/event_bus.gd` (add 3 signals — currently only 6), `systems/audio_manager.gd` (stub `play_sfx` → implement), `systems/settings.gd` (has `setting_changed` already; add `reduced_motion` accessors), `systems/constants.gd` (add `MAX_FLASH_HZ`, `MAX_SHAKE_PX`), `systems/pool.gd` (**read only** — confirm `acquire`/`release`/`_deactivate` contract).
  - `player/projectile.gd` (`_on_body_entered` — add impact juice emit), `player/fire_system.gd` (`_spawn` — add fire SFX + optional muzzle), `player/player.gd` (refine i-frame cue; remove placeholder tag).
  - `enemies/enemy_projectile.gd` (`_on_body_entered` — player-hit juice; heavy variant), `enemies/enemy.gd` (`_on_died` — death juice; do NOT touch `despawn()`).
  - `world/arena.tscn` (add `JuiceCoordinator` + `Camera2D`), `world/arena.gd` (**read only** — confirm no wiring needed beyond the node), `project.godot` (add audio buses).
  - `components/health_component.gd`, `components/faction_component.gd`, `world/formation_spawner.gd`, `run/run_state.gd` — **read only** (do not change).
  - `tests/systems/test_pool.gd`, `tests/enemies/test_enemy.gd` (`test_player_projectile_damages_enemy`), `tests/player/test_projectile.gd`, `tests/world/test_arena.gd` — GUT patterns to mirror + regressions to keep green.
- **Deferred work log:** `implementation-artifacts/deferred-work.md` — the 1.1-review note that `AudioManager.play_sfx` is a stub "wired in Story 1.6" (this story) and `Settings` "reduced_motion … land when consumed (1.6 juice)" — both resolved here.

---

## Open design questions for Mrdth (review before dev — defaults are safe to implement as-is)

These are the consequential forks resolved with documented defaults above. They are safe to implement as written; flagged only so Mrdth can veto before `dev-story` runs.

1. **`_motion_scale` value: 0.3 or 0.7?** Architecture code literal says `0.3 if reduced else 1.0`; UX prose says "~70% scale". These reconcile only if "~70% scale" means "reduce by 70% → 0.3". *(Default: `motion_scale_reduced = 0.3` per the architecture's concrete code; it's dormant in E1 since `reduced_motion` defaults `false`. Non-blocking — purely a future feel knob.)*
2. **SFX: synthesize in-code vs. commit `.wav` placeholders?** `assets/` has no audio and an AI dev can't cleanly author binary samples. *(Default: synthesize short `AudioStreamWAV` stabs in `AudioManager._ready` — asset-free, genuinely "synthwave punch", AI-authorable. Real SFX/music = Story 8.5.)*
3. **Particle texture: procedural `ImageTexture` vs. untextured squares?** No sprite textures exist in-repo. *(Default: one cached procedural soft-white radial-gradient `ImageTexture`, tinted per-effect — on-pattern with the all-vector art style.)*
4. **Muzzle-flash particles on fire?** AC4 mandates fire *SFX*; muzzle particles aren't in the ACs. *(Default: include a light optional muzzle puff — it's cheap, pooled, and adds punch; drop it if it clutters the 6 Hz autofire.)*
5. **One flexible pooled particle scene vs. per-effect scenes?** *(Default: one `particle_burst.tscn` configured per-spawn via `activate(effect, …)` reading profiles from `JuiceTuning` — minimizes pool sprawl. Dev may split if profiles diverge too far.)*

---

## Dev Agent Record

### Agent Model Used

Claude Code (GLM-5.2[1m] per session environment)

### Debug Log References

- Full GUT suite (final): `godot --headless -s addons/gut/gut_cmdln.gd` → **20 scripts, 144/144 tests pass, 431 asserts** (0 regressions vs the 1.1–1.5 baseline of 120).
- New test files: `tests/juice/test_juice_coordinator.gd` 7/7 · `tests/juice/test_hit_flash.gd` 4/4 · `tests/juice/test_particle_burst.gd` 5/5 · `tests/systems/test_audio_manager.gd` 8/8 = **24 new tests**.
- Import: `godot --headless --import` → clean (registers the new `class_name`s: `JuiceCoordinator`, `ScreenShake`, `HitFlash`, `ParticleBurst`, `JuiceTuning`, `JuiceFx` + the new `@export`/`@export_group`s).
- Normal headless launch (`timeout 12 godot --headless --path .`): boots arena with the coordinator + camera + pooled particles + synthesized audio, enemies spawn + fire at the player (player-hit juice path), **zero runtime errors** during the run (only the known exit-time pooled-node leak artifacts, present since 1.3).
- API probes (throwaway, in /tmp) confirmed before authoring: `GPUParticles2D` HAS a `texture` property; `ParticleProcessMaterial` has spread/direction/velocity/scale/color/gravity but NO `blend_mode` (additive blend lives on a `CanvasItemMaterial`); `PackedByteArray.encode_s16` is little-endian; `AudioServer.add_bus`/`set_bus_name`/`set_bus_send` create runtime buses; `Camera2D` `DRAG_CENTER` at (640,360) centers the view on (0,0)–(1280,720) — asserted by `test_camera_idle_framing_is_unchanged`.

### Completion Notes List

- **All 5 ACs satisfied and verified by tests.** AC1 (hit-flash + screen-shake + pooled particle burst on every impact, driven by EventBus) → three `_requested` signals on `EventBus` + a `JuiceCoordinator` that fans them to `ScreenShake`/`HitFlash`/pooled `ParticleBurst`; AC2 (coordinator is arena-scoped, NOT an autoload, auto-disabled in menus by structural absence) → `JuiceCoordinator` is a node in `arena.tscn`, the 11-autoload registry is unchanged; AC3 (pooled GPUParticles2D, `acquire`/`release` + `activate`, never `_ready()` re-init) → `juice/particle_burst.tscn` with Timer self-release, LIFO round-trip tested; AC4 (basic SFX on fire/hit/kill via AudioManager, SFX bus, ±5% pitch) → synthesized `AudioStreamWAV` stabs + 8-player pool + Master/SFX/Music buses; AC5 (reduced-motion dampens amplitude without removing feedback; ≤3 Hz flash cap enforced centrally, unconditionally) → `Settings.reduced_motion` + `_motion_scale` + `HitFlash` central gate.
- **The load-bearing accessibility invariant (AC5) is centrally enforced and unit-tested.** `HitFlash` drops any `hit_flash_requested` within `1/MAX_FLASH_HZ` of the last allowed flash — UNCONDITIONAL (applied before `_motion_scale`, regardless of `reduced_motion`). `tests/juice/test_hit_flash.gd` covers the pure gate boundary + the integration behavior (3 rapid flashes ⇒ only the first modulates; 4th after the window ⇒ modulates again; gate holds under `reduced_motion`).
- **Implicit/end-to-end requirements all met:** no hit path regressed (1.3–1.5 damage/death/i-frame/score/wave flow untouched — 120 prior tests still green); juice hooks the IMPACT SOURCE not `HealthComponent` (Key Decision #1 — `HealthComponent`/`health_changed`/`died` and their 18 tests are untouched; emit sites are `Projectile._on_body_entered`, `EnemyProjectile._on_body_entered`, `Enemy._on_died`, `FireSystem._spawn`); kill ≠ despawn (death juice fires in `_on_died` ONLY — `despawn()` is untouched); the new `Camera2D` renders the 1280×720 play-field identically at idle (verified by `test_camera_idle_framing_is_unchanged` asserting `offset == ZERO` + `screen_center ≈ (640,360)`); juice is arena-scoped so "auto-disabled in menus" is structural (no coordinator outside `arena.tscn`); physics-callback safety holds (signal emits + additive `Pool.acquire`/`add_child`/`activate` are safe inside `_on_body_entered`; particle release is deferred via Timer, never `queue_free`); the 1.5 i-frame alpha-flicker placeholder is retired (calmer ~1.9 Hz sustained pulse in `player.gd`, placeholder tag removed).
- **Camera2D framing (the #1 regression risk) resolved:** `DRAG_CENTER` at `position = BASE_RESOLUTION/2 = (640,360)`, `zoom = ONE`, `position_smoothing_enabled = false`. The shake drives `camera.offset` (not `position`), so it doesn't fight the physics/transform. The framing assertion (`screen_center ≈ (640,360)`, `offset == ZERO` at idle) confirms the idle view is pixel-identical to the pre-camera arena.
- **Asset-free / on-pattern (Key Decisions #5/#6):** particles use a procedurally-baked soft-white radial-gradient `ImageTexture` (cached once, tinted per-spawn via `modulate`) — zero sprite textures introduced; audio is three synthesized `AudioStreamWAV` stabs (16-bit PCM, sine-sweep + noise + exp-decay envelope, seeded RNG ⇒ deterministic) — zero binary `.wav` files. Additive `CanvasItemMaterial` carries the neon glow read (no shader — deferred to 8.5).
- **A static `JuiceFx` helper was added (the spec's encouraged DRY option):** `juice/juice_fx.gd` centralizes tuning access (one `preload` of `juice_tuning.tres`, not per-projectile) and keeps each emit site a one-liner (`JuiceFx.enemy_hit(at, body)` / `player_hit(at, body, heavy)` / `enemy_killed(at, color, scale)` / `player_fired(muzzle_pos)`). The underlying mechanism is still the EventBus request signals (AC1) — `JuiceFx` is sugar over them. (Listed beyond the `juice/` intended-contents note, which explicitly allows "dev's choice" DRY helpers.)
- **Reduced-motion is dormant in E1** (`reduced_motion` defaults `false` so the v0.1 feel gate evaluates full juice; the ≤3 Hz cap is unconditional regardless). `motion_scale_reduced = 0.3` per the architecture's concrete code literal (Open Question Q1 — non-blocking, dormant). No settings panel/toggle UI built (E8, Story 8.4 — explicitly do-not-pull-forward).
- **No new dependencies, no scope creep.** No `HitboxComponent`/`HurtboxComponent` (E2), no floating score popups (1.7), no damage vignette/rumble/palette-arc (E8/3.9), no neon glow shader (8.5), no full synthwave music (8.5), no settings panel (8.4) — exactly the basic juice slice the spec scopes.

### File List

**New:**
- `juice/juice_coordinator.gd` — arena-scoped conductor (Node2D): connects the 3 EventBus juice signals + `Settings.setting_changed`, owns Camera2D/ScreenShake/HitFlash, hosts pooled particles, applies `_motion_scale`. NOT an autoload.
- `juice/screen_shake.gd` — trauma-style shake driving `camera.offset` (squared trauma, unit-random direction ⇒ `|offset| ≤ MAX_SHAKE_PX`), idle `set_process(false)`.
- `juice/hit_flash.gd` — entity hit-flash + the central ≤3 Hz cadence gate (`is_flash_allowed` pure seam + `request`), per-target tween kill-on-re-hit, `_motion_scale` dampens duration.
- `juice/particle_burst.gd` + `juice/particle_burst.tscn` — pooled one-shot `GPUParticles2D`; procedural radial-gradient `ImageTexture` (cached), additive `CanvasItemMaterial`, instance-local `ParticleProcessMaterial`, `activate()`-only re-init, Timer self-release via `Pool.release`.
- `juice/juice_tuning.gd` — feel-knob schema (shake/flash/particle/motion `@export` groups + cached `get_effect_profile`).
- `juice/juice_fx.gd` — static one-liner helpers (`enemy_hit`/`player_hit`/`enemy_killed`/`player_fired`) emitting the EventBus signals + AudioManager SFX from a single cached tuning.
- `resources/juice_tuning.tres` — the feel-knob instance (mirrors `player_tuning.gd`+`.tres`).
- `tests/juice/test_juice_coordinator.gd` — coordinator integration incl. the Camera2D framing regression + reduced-motion dampen (7).
- `tests/juice/test_hit_flash.gd` — the photosensitive-safety gate (pure boundary + integration; unconditional under reduced motion) (4).
- `tests/juice/test_particle_burst.gd` — pool round-trip (acquire/activate/Timer-release/LIFO reuse/re-arm) (5).
- `tests/systems/test_audio_manager.gd` — SFX pipeline (synth streams, buses, routed pool, play_sfx, overflow, typed helpers) (8).

**Modified:**
- `systems/event_bus.gd` — 3 typed juice REQUEST signals (`screen_shake_requested`/`hit_flash_requested`/`particles_requested`); the 6 game-flow signals + header comment kept/extended.
- `systems/constants.gd` — immutable safety caps `MAX_FLASH_HZ = 3.0`, `MAX_SHAKE_PX = 8.0`.
- `systems/settings.gd` — `REDUCED_MOTION_KEY` + `get_reduced_motion`/`set_reduced_motion` (persist + emit via existing `set_value`).
- `systems/audio_manager.gd` — replaces the 1.1 stub: Master/SFX/Music buses (AudioServer), 8-player pooled `AudioStreamPlayer` (interrupt-oldest), synthesized `sfx_fire`/`sfx_hit`/`sfx_kill` `AudioStreamWAV` stabs, `play_sfx` + typed `play_fire`/`play_hit(heavy)`/`play_kill`.
- `player/projectile.gd` — `_on_body_entered` emits impact juice (`JuiceFx.enemy_hit`) after `take_damage` + the `_consumed` guard; hit resolution untouched.
- `player/fire_system.gd` — `_spawn` emits on-fire juice (`JuiceFx.player_fired`); stale "emits nothing to EventBus" comment reworded (juice requests are an allowed channel).
- `player/player.gd` — i-frame cue refined: the 1.5 sin-flicker placeholder retired to a calmer ~1.9 Hz sustained alpha pulse; placeholder tag removed (impact flash is JuiceCoordinator-driven).
- `enemies/enemy_projectile.gd` — `_on_body_entered` emits player-hit juice (`JuiceFx.player_hit(global_position, body, _heavy)`); heavy variant scales shake/spark/pitch.
- `enemies/enemy.gd` — `_on_died` emits death juice (`JuiceFx.enemy_killed`) before the deferred release; `despawn()` untouched (kill ≠ despawn).
- `world/arena.tscn` — `JuiceCoordinator` (Node2D) child with `Camera2D` (640,360 / DRAG_CENTER / smoothing off), `ScreenShake`, `HitFlash`, and `tuning = juice_tuning.tres`.

**Deleted:**
- `juice/.gdkeep`, `tests/juice/.gdkeep` — placeholders retired (both dirs now hold real files). `assets/.gdkeep` kept (no audio assets committed — synthesis is asset-free).

### Change Log

- 2026-07-05: Story 1.6 implemented — EventBus juice-request signals + Constants safety caps, `Settings.reduced_motion`, `JuiceTuning` resource, `ScreenShake`/`HitFlash` (central ≤3 Hz gate)/pooled `ParticleBurst`, arena-scoped `JuiceCoordinator` + `Camera2D`, `AudioManager` synthwave SFX pipeline, emit-site wiring (projectile/enemy_projectile/enemy/fire_system) + refined i-frame cue, 24 new GUT tests. 144/144 GUT tests pass (0 regressions). Status → review.
- 2026-07-05: Code review — 2 decision_needed, 4 patch, 6 defer, 3 dismissed. Both decisions resolved with Mrdth (audio buses left as-is; pooled hit-flash reuse race fixed by skipping the flash on lethal hits rather than adding new signal plumbing). All 4 patches applied: particle bursts now dampen under `reduced_motion` (AC5 gap), `ScreenShake` decay no longer lets a short hit truncate a longer shake already in flight, enemy hits during player i-frames no longer fire phantom juice, and the Camera2D regression test now covers the real `arena.tscn` scene (not just a hand-built stand-in). Also fixed one pre-existing flaky test found while verifying (`test_hit_flash_requested_tweens_target_modulate`, unrelated to this story's patches — rewritten to use `Tween.custom_step()` for deterministic timing). 6 new regression tests added. Full suite: 150/150 GUT tests pass (0 regressions). Status → done.
