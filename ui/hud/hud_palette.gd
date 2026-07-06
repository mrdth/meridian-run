class_name HudPalette
extends RefCounted
# Calm Vector Standard palette + spacing/typography consts for the in-wave HUD (UX DESIGN.md
# frontmatter). TEMPORARY spine — Story 3.9's ThemeTokens (juice/theme_tokens.gd) replaces this and
# drives the calm→climax lerp via arc_t; until then the HUD renders CALM-ONLY (arc_t stays ~0 in E1,
# no emitter until the PaletteArcCoordinator of Story 3.9).
#
# Colors are const Color values lifted verbatim from DESIGN.md's calm column (hex parsed by Godot's
# Color string ctor). Climax termini exist in DESIGN but are NOT used this epic — they mature with
# ThemeTokens. WCAG-AA on `surface` cleared per DESIGN contrast table.

# --- Colors (calm Vector Standard) ---
const SURFACE: Color            = Color("#060912")  # play-field void / optional HUD chip bg
const SURFACE_ALT: Color        = Color("#0C1424")
const TEXT: Color               = Color("#E6F1FF")  # timer numeric, primary ink
const MUTED: Color              = Color("#7E8DAA")  # labels, empty pip stroke, lost-pip stroke
const BORDER: Color             = Color("#1E2A44")
const PRIMARY: Color            = Color("#00E5FF")  # hero neon — lit pip stroke, timer suffix/glow
const PRIMARY_HOVER: Color      = Color("#5AF7FF")
const HEALTH: Color             = Color("#4ADE80")
const HAZARD: Color             = Color("#FF3D5A")  # low-time timer numeric (calm)
const SCORE: Color              = Color("#FFE066")  # score numeric + glow (reward amber)
const GLOW: Color               = Color("#5AF7FF")  # neon halo
const MODIFIER_SWARM: Color     = Color("#FF3D5A")  # dormant in E1 (modifiers = Epic 5)
const MODIFIER_GAUNTLET: Color  = Color("#00E5FF")
const MODIFIER_BOUNTY: Color    = Color("#FFE066")
const WHITE: Color              = Color("#FFFFFF")  # NEUTRAL-white low-time glow (UX T1 — NOT primary)

# --- Spacing (8px grid; DESIGN spacing) ---
# DESIGN.md's literal hud-band token (reference only). Hud._BAND_HEIGHT_PX (ui/hud/hud.gd) is the
# actual implemented band height (96px) — it grew past this value through the playtest layout fixes
# in this story's Change Log. Not currently read by Hud; kept here as the documented design intent.
const HUD_BAND_PX: float        = 58.0
const LANE_BAND_PX: float       = 54.0
const MARGIN_FRAME_PX: float    = 32.0
const TITLE_SAFE_FRACTION: float = 0.05

# --- Typography sizes (px; DESIGN typography scale) ---
const NUMERIC_LG: int = 30   # score value, timer numeric (numeric-lg ~30 bold)
const NUMERIC_SM: int = 13   # ×N lives label (numeric-sm ~13 bold)
const LABEL_CAPS: int = 11   # SCORE / WAVE / SURVIVE eyebrow labels (label-caps ~11)
