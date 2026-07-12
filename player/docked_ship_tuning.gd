class_name DockedShipTuning
extends Resource
# Data definition for the rescue wingman (Story 2.3) — AR10 "tunable" tier, D9 content. E2 hardcodes
# the docked-ship stats (no premature StatBlock — that's the E3 build engine); this resource holds
# the playtest KNOBS so the `.tres` instance wins at runtime (memory: tres-overrides-gd-default-for-tuning).
# Schema lives with the owning player/ domain; the `.tres` INSTANCE lives flat in resources/ (matching
# player_tuning.tres / captor_tuning.tres — the established flat convention, NOT resources/tuning/).
#
# Single-sourced +28 px: stream_offset_x (the parallel bullet offset) and dock_offset_x (the wingman's
# station beside the player) are intentionally the same value — the stream fires FROM the wingman's
# position. Keep them in sync here (or a single constant) so the bullet + the visual line up.

@export_group("Stream")
# FR7 / GDD weapon table — the parallel bullet stream the docked fighter adds (+firepower, AC#3).
# The player's FireSystem spawns a 2nd bullet at muzzle.x + stream_offset_x when docked.
@export var stream_offset_x: float = 28.0   # +28 px x-offset (the GDD-pinned value).
@export var stream_damage: int = 10          # matches the player's projectile_damage (FR7 "matches player").

@export_group("Absorber")
# FR17 — the intrinsic first-hit absorber. The docked fighter dies on the first hit, sparing HP.
# NO ship-count change (the FR18 "Absorb = −1 ship" is relative-accounting vs the Keep +1, NOT a spend).
@export var absorb_spare_hp: bool = true

@export_group("Hitbox")
# AC#3 / [Risk-12] — the +hitbox: the PLAYER's own hitbox grows when docked (the docked ship makes you a
# bigger target). This is the radius the player's body CollisionShape2D + HurtboxComponent shape swap to
# on dock (clean radius = 11, the player.tscn base). Story 2.4 formalized this clean(11)↔docked(18)
# tradeoff as the [Risk-12] self-balancing cost (the dual fighter's combat perks cost a bigger target).
@export var docked_hitbox_radius: float = 18.0

@export_group("Visual")
# The docked fighter's escort-chevron read (UX docked-wingman-indicator). Player-family — NEVER the
# grunt-triangle or the pellet hazard shapes (D16/UX color-safety — the shape+outline is load-bearing).
# dock_color is the {colors.dock} placeholder (UX OQ3 — provisional alias of primary_hover / HudPalette.PRIMARY).
@export var dock_offset_x: float = 28.0      # the wingman's station to one side of the player (= stream_offset_x).
@export var dock_scale: float = 0.8          # ~80% scale (escort-chevron, not a full second ship — UX C1).
@export var dock_color: Color = Color(0.0, 0.898, 1.0, 1.0)  # {colors.dock} — hero neon (#00E5FF = HudPalette.PRIMARY).
