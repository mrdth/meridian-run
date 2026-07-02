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
