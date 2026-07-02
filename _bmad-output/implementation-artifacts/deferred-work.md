# Deferred Work Log

Items deferred during code reviews — to be revisited when their owning story lands.

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
