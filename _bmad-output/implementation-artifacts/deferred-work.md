# Deferred Work Log

Items deferred during code reviews and story creation — to be revisited when their owning story lands.

> **Decision log:** `fire`/`confirm` share joypad button 0 (South/A) by design — GameManager will gate active contexts in Story 4.7 (2026-07-02 decision by Mrdth).

---

## Deferred from: code review of 1-1-project-scaffolding-and-core-systems (2026-07-02)

- `arena.tscn` missing `uid=` line [world/arena.tscn:1] — Godot auto-assigns UID on first editor open; no action needed unless UID churn in git becomes a nuisance
- `Settings.set_value()` sync disk I/O on every call [systems/settings.gd:27] — no real callers until E8 Settings panel; add debounce/batch save when wiring the settings UI
- No `MAX_HP` constant [systems/constants.gd] — add ceiling constant when Story 1.5 implements life/health economy
- `get_value()` `null` default may surprise typed callers [systems/settings.gd:22] — Variant return is intentional; callers must pass typed defaults; revisit if a pattern of misuse emerges
- `ship_lost(remaining: int)` parameter name is ambiguous (ships? HP?) [systems/event_bus.gd:7] — rename/clarify when first consumed in Story 1.5
- `.gutconfig.json` `log_level:1` (failures-only) may hide context in CI [.gutconfig.json:5] — revisit when CI pipeline is established; consider bumping to level 2

## Deferred from: code review of 1-2-player-movement-1-axis-chassis (2026-07-02)

- `player.tscn`/`arena.tscn` still missing/inconsistent `uid=` resource references vs `resources/player_tuning.tres` [player/player.tscn, world/arena.tscn] — echoes the 1.1-deferred `arena.tscn` uid item above (same accepted non-issue: not a functional bug, headless launch confirmed clean); recommend opening both scenes once in the Godot editor and re-saving so Godot regenerates proper `uid=` metadata rather than hand-authoring uids, if the churn ever becomes a nuisance
- Post-`move_and_slide()` corrective clamp will need re-examination once collision is enabled [player/player.gd:24] — correct and spec-mandated for 1.2 (`collision_mask = 0`), but clamping `global_position.x` directly after `move_and_slide()` may fight the physics engine's own slide resolution once 1.4/1.6 add real collision layers to the player's mask; flag for 1.4's dev pass
- `HealthComponent.heal()` doesn't clear `_is_dead` when healed above zero [components/health_component.gd:34-38] — respects the spec's own "no revive-from-zero semantics decided here; healing a dead ship is 1.5's call — keep `heal` a pure clamp for now" (Dev Notes T2); unreachable in 1.2 (heal() has no callers yet); 1.5 decides revive semantics when damage/heal sources are wired

## Deferred from: code review of 1-3-vertical-fire-system (2026-07-02)

- No cast/type-guard on the `_muzzle` `@onready` assignment (`get_node_or_null` returns `Node`, assigned directly to a `Marker2D`-typed var) [player/fire_system.gd] — pre-existing pattern (mirrors 1.2), no functional impact today since `Muzzle` is always a `Marker2D` in `player.tscn`
- `Pool.release()` logs the identical warning text for a genuinely-foreign node and an already-idempotently-released node, making the two cases indistinguishable in logs [systems/pool.gd] — minor debugging-friction nit
- `Pool.release()`'s `is_queued_for_deletion()` early-return doesn't erase the corresponding `_node_paths` entry, a latent dict leak only reachable via a pooling-contract violation (calling `queue_free()` directly on a pooled node instead of `Pool.release()`) [systems/pool.gd] — non-exploitable today (Godot instance IDs aren't reused within a process)
- `_cooldown` drifts unboundedly negative while Fire is not held (decremented every physics frame regardless of input state) [player/fire_system.gd] — no functional impact today (any negative value satisfies the `<= 0.0` check), landmine only if future code (e.g. a 1.7 ammo/heat HUD) reads its magnitude
- `test_physics_process_makes_no_per_frame_allocations` verifies the AC4 "zero allocations" claim via raw source-text substring search rather than actual runtime allocation behavior [tests/player/test_fire_system.gd] — matches the accepted 1.2 structural-test precedent, not a regression

## Deferred from: code review of 1-5-life-and-health-economy (2026-07-05)

- `FormationSpawner.set_active(true)` called while `_wave_time` already exceeds `wave_duration_s` would re-fire `wave_cleared` and double-advance the wave [world/formation_spawner.gd:79-82] — no current call site triggers this (only `set_active(false)` is called in 1.5); latent footgun for Story 1.8's richer wave/pause control
- `HealthComponent.heal()` can leave `current_hp > 0` while `_is_dead == true` with no guard [components/health_component.gd] — explicitly-acknowledged landmine from this story's own Dev Notes §"Revive semantics" ("heal() stays a pure clamp... no code change needed"); only reachable once a future story (E3 shield power-up) calls `heal()` on a dead entity
- `Arena.auto_replay_on_loss` is an inspector-exposed `@export` whose sole purpose is a test-isolation seam [world/arena.gd] — explicit E1 placeholder; Story 8.4 replaces the whole game-over/replay flow with a real screen and can retire this toggle then

## Deferred from: Story 1.6 (hit-feedback-and-juice) creation analysis (2026-07-05)

- **Introduce `HitboxComponent`/`HurtboxComponent` — owned by Story 2.4 (Epic 2).** These components are listed as planned (`project-context.md:63`; architecture lines 235/468/585 — Area2D-based shared components) but were **never built**. 1.4 simplified architecture line 236 ("Enemies = health + hitbox + AI") down to the node-name `HealthComponent` lookup (`body.get_node_or_null("HealthComponent")` → `take_damage()`), and `player/projectile.gd:65-66`'s comment ("the real HurtboxComponent-mediated wiring lands in 1.4") never landed. The deferral chain is explicit: 1.4 key decision #2 ("deferred until multi-shape hitboxes are needed") → 1.5 key decision #6 (names Story 2-4 / Epic 2). **Trigger:** Story 2.4 (`2-4-docked-ship-dual-nature-and-clean-docked-tradeoff`) AC (epics.md:483) is the first gameplay need for a **shape-changing / multi-shape hitbox** — clean = small, docked = bigger ([Risk-12]); the intrinsic first-hit absorber ([Build-15]) lands in Story 2.5 (docked-ship resolution: absorb next fire-hit). **Action when creating the 2.4 story spec:** add an explicit task to (a) introduce `HitboxComponent`/`HurtboxComponent` (Area2D-based, `components/`), (b) migrate both projectile `_on_body_entered` node-name-lookup hit paths (`player/projectile.gd`, `enemies/enemy_projectile.gd`) onto the new components, and (c) delete the stale "lands in 1.4" comment — so this isn't missed a third time. **Provenance:** neither the GDD nor the Architecture names a story for the component; this ownership is *derived* from the GDD's bigger-hitbox requirement ([Risk-12]/[Build-15], decision-log:28/31) + the architecture's component plan + the 1.4/1.5 deferral decisions.

## Deferred from: code review of 1-6-hit-feedback-and-juice (2026-07-05)

- Default tuning already exceeds `MAX_SHAKE_PX`, clamp is silent [resources/juice_tuning.tres, juice/juice_coordinator.gd:46] — `shake_player_hit_amount * shake_heavy_mul = 9.0 > MAX_SHAKE_PX (8.0)`, clamped with no `Log.warn` unlike other fail-safe paths in this story; tuning values are explicitly provisional (Story 1.8 owns the feel pass)
- Two independent sources of the same `JuiceTuning` data — `juice/juice_fx.gd`'s own `preload` vs. `JuiceCoordinator`'s `@export var tuning` [juice/juice_fx.gd:15] — sanctioned as an acceptable DRY choice per Task 9.1; only a risk if/when a future scene variant (e.g. a boss arena) assigns the coordinator a different `JuiceTuning` instance, silently desyncing shake/particle values from flash duration
- `JuiceTuning.get_effect_profile()` returns a cached Dictionary by reference with no defensive copy despite a documented immutability contract [juice/juice_tuning.gd] — today's only caller (`JuiceCoordinator`) copies fields out safely; a future caller could mutate the shared cache and corrupt it for the rest of the run
- `AudioManager`'s interrupt-oldest heuristic compares raw playback position across differently-pitched streams, an imprecise proxy for "oldest" [systems/audio_manager.gd] — low-severity audio polish; no test asserts which player gets interrupted under pool overflow
- `HitFlash` cadence-gate tests use real wall-clock timers with margins close to the 333ms threshold [tests/juice/test_hit_flash.gd] — could flip under CI scheduling jitter; consider widening margins or injecting a fake clock for the pure `is_flash_allowed` seam
- Global `HitFlash` gate suppresses most flashes during dense multi-enemy combat [juice/hit_flash.gd] — this is the explicit spec-mandated design (Key Decision #7: one unconditional global gate, not per-emitter), not a defect; flagged as a feel-tension worth revisiting during Story 1.8's tuning pass
