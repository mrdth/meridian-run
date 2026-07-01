---
name: 'Meridian Run'
description: 'Visual identity for Meridian Run — a 2D fixed-screen roguelite shooter (Godot 4.6 / Control-node UI on a CanvasLayer, Windows + Linux desktop). Owns how it looks. EXPERIENCE.md owns how it works and cites these tokens by {path.to.token}.'
status: final
updated: 2026-07-01
spine: DESIGN.md
inherits: 'Godot Control nodes (CanvasLayer-separated UI). DESIGN.md tokens reference/extend Control defaults; EXPERIENCE.md specifies only behavioral delta.'

colors:
  # ---- Vector Standard (calm / base / load-time) — V3 arc start ----
  surface:         '#060912'
  surface-alt:     '#0C1424'
  text:            '#E6F1FF'
  muted:           '#7E8DAA'   # lifted from #6B7B9A to clear WCAG-AA 4.5:1 on surface (A1)
  border:          '#1E2A44'
  primary:         '#00E5FF'   # hero neon, allied rescuer read
  primary-hover:   '#5AF7FF'
  health:          '#4ADE80'
  hazard:          '#FF3D5A'   # tractor columns, enemy fire, damage — never the player's own
  score:           '#FFE066'
  currency:        '#C084FC'   # shop-stage only; NOT displayed in the in-wave HUD (H2)
  modifier-swarm:  '#FF3D5A'
  modifier-gauntlet: '#00E5FF'
  modifier-bounty: '#FFE066'
  glow:            '#5AF7FF'
  dock:            '#5AF7FF'   # [ASSUMPTION] docked-wingman accent = primary-hover (OQ3 provisional); revisit at Shield-PU pass

  # ---- Polybius Dusk (climax / rare) — V3 arc peak, compounds with build power ----
  climax-surface:      '#0F0820'
  climax-surface-alt:  '#1A1030'
  climax-text:         '#FDE6FF'
  climax-muted:        '#9979B0'   # lifted from #8A6B9A (4.32:1) to clear WCAG-AA 4.5:1 on climax-surface (A1) — measured 5.31:1
  climax-border:       '#2E1A4A'
  climax-primary:      '#FF2BD6'
  climax-primary-hover:'#FF6BE8'
  climax-health:       '#00F0C0'
  climax-hazard:       '#FF9E3D'   # amber — climax terminus for {colors.hazard}. Hue- AND luminance-distinct from climax-primary #FF2BD6 (ΔL 0.18 vs the red-vs-magenta 0.025 collapse). Reads as "danger" without entering the magenta neighborhood. Calm hazard stays #FF3D5A (calm hero is cyan → already maximally distinct; the collapse is only climax-vs-magenta). A2.
  climax-glow:         '#FF6BE8'

typography:
  display-xl:    { fontFamily: 'Chakra Petch, "Rajdhani", "Saira Condensed", system-ui, sans-serif', fontSize: '50px', fontWeight: '700', lineHeight: '1.05', letterSpacing: '0.045em' }
  display-lg:    { fontFamily: 'Chakra Petch, "Rajdhani", "Saira Condensed", system-ui, sans-serif', fontSize: '38px', fontWeight: '700', lineHeight: '1.05', letterSpacing: '0.085em' }
  display-md:    { fontFamily: 'Chakra Petch, "Rajdhani", "Saira Condensed", system-ui, sans-serif', fontSize: '28px', fontWeight: '700', lineHeight: '1.05', letterSpacing: '0.12em' }
  display-sm:    { fontFamily: 'Chakra Petch, "Rajdhani", "Saira Condensed", system-ui, sans-serif', fontSize: '21px', fontWeight: '700', lineHeight: '1.1',  letterSpacing: '0.13em' }
  menu:          { fontFamily: 'Inter, system-ui, "Segoe UI", Roboto, sans-serif', fontSize: '21px', fontWeight: '600', lineHeight: '1.3',  letterSpacing: '0.005em' }
  body:          { fontFamily: 'Inter, system-ui, "Segoe UI", Roboto, sans-serif', fontSize: '16px', fontWeight: '400', lineHeight: '1.5',  letterSpacing: '0em' }
  body-sm:       { fontFamily: 'Inter, system-ui, "Segoe UI", Roboto, sans-serif', fontSize: '13px', fontWeight: '400', lineHeight: '1.45', letterSpacing: '0em' }
  numeric-xl:    { fontFamily: '"JetBrains Mono", ui-monospace, "Cascadia Code", "SF Mono", Menlo, Consolas, monospace', fontSize: '44px', fontWeight: '700', lineHeight: '1.0', letterSpacing: '0.01em' }
  numeric-lg:    { fontFamily: '"JetBrains Mono", ui-monospace, "Cascadia Code", "SF Mono", Menlo, Consolas, monospace', fontSize: '30px', fontWeight: '700', lineHeight: '1.0', letterSpacing: '0.02em' }
  numeric-md:    { fontFamily: '"JetBrains Mono", ui-monospace, "Cascadia Code", "SF Mono", Menlo, Consolas, monospace', fontSize: '26px', fontWeight: '500', lineHeight: '1.0', letterSpacing: '0.04em' }
  numeric-sm:    { fontFamily: '"JetBrains Mono", ui-monospace, "Cascadia Code", "SF Mono", Menlo, Consolas, monospace', fontSize: '13px', fontWeight: '600', lineHeight: '1.0', letterSpacing: '0.02em' }
  label-caps:    { fontFamily: '"JetBrains Mono", ui-monospace, "Cascadia Code", "SF Mono", Menlo, Consolas, monospace', fontSize: '11px', fontWeight: '600', lineHeight: '1.4',  letterSpacing: '0.18em' }

rounded:
  none:    '0px'
  xs:      '2px'
  sm:      '4px'
  DEFAULT: '6px'
  md:      '8px'
  lg:      '12px'
  xl:      '16px'
  full:    '9999px'

spacing:
  '1': '4px'
  '2': '8px'    # base grid unit
  '3': '12px'
  '4': '16px'
  '5': '24px'
  '6': '32px'
  '7': '48px'
  gutter:       '24px'
  margin-frame: '32px'
  hud-band:     '58px'
  lane-band:    '54px'
  title-safe:   '5%'   # canvas_items+expand; keep combat-critical HUD inside this margin (F4)

components:
  lives-display:           { icon-fill: 'transparent', icon-stroke: '{colors.primary}', icon-on-glow: '{colors.glow}', icon-off-stroke: '{colors.muted}', label: '{colors.muted}', label-font: 'label-caps' }
  wave-timer:              { numeric-font: 'numeric-lg', numeric-color: '{colors.text}', suffix-color: '{colors.primary}', glow: '{colors.primary}', low-time-numeric-color: '{colors.hazard}', low-time-glow: 'neutral-white', label: 'SURVIVE', label-color: '{colors.muted}' }
  score-readout:           { numeric-font: 'numeric-lg', numeric-color: '{colors.score}', glow: '{colors.score}', label-color: '{colors.muted}' }
  wave-modifier-readout:   { chip-font: 'label-caps', swarm-color: '{colors.modifier-swarm}', gauntlet-color: '{colors.modifier-gauntlet}', bounty-color: '{colors.modifier-bounty}', shape-first: true }
  hp-bar:                  { segment-fill: '{colors.health}', segment-empty-stroke: '{colors.muted}', segment-glow: '{colors.health}', segment-radius: '{rounded.xs}', segment-w: '10px', segment-h: '4px', gap: '3px', idiom: 'player-and-enemy-shared' }
  build-summary-rail:      { surface: '{colors.surface}', border: '{colors.border}', scrim-blur: '6px', main-accent: '{colors.primary}', wing-accent: '{colors.health}', label-font: 'label-caps' }
  capture-column:          { edge-color: '{colors.hazard}', edge-glow: '{colors.hazard}', fill-color: '{colors.hazard}', fill-alpha-low: '5%', fill-alpha-high: '22%', sweep: true, climax-edge-color: '{colors.climax-hazard}', climax-fill-color: '{colors.climax-hazard}', hazard-family: 'enemy-threat' }
  docked-wingman-indicator:{ stroke: '{colors.dock}', fill-tint: '{colors.dock}', glow: '{colors.dock}', scale: '0.8', shield-ring-stroke: '{colors.dock}', shield-reserved: 'future-shield-pu', silhouette: 'escort-chevron', bright-outline: 'true', player-family: 'true' }
  player-ship:             { stroke: '{colors.primary}', stroke-bright-outline: 'true', silhouette: 'rescuer-arrowhead', climax-stroke: '{colors.climax-primary}', climax-stroke-bright-outline: 'true', player-family: 'true' }
  player-projectile:       { silhouette: 'elongated-chevron', core-color: '{colors.text}', outline-color: '{colors.primary}', climax-outline-color: '{colors.climax-primary}', bright-outline: 'true', player-family: 'true' }
  enemy-fire:              { silhouette: 'small-pellet', fill-color: '{colors.hazard}', climax-fill-color: '{colors.climax-hazard}', hazard-family: 'enemy-threat', no-bright-outline: 'true' }
  power-up-card:           { surface: '{colors.surface-alt}', border-default: '{colors.border}', accent-default: '{colors.primary}', accent-rare: '{colors.climax-primary}', glow-default: '{colors.glow}', glow-rare: '{colors.climax-glow}', radius: '{rounded.lg}' }
  take-button:             { bg-gradient-from: '{colors.primary-hover}', bg-gradient-to: '{colors.primary}', label-color: '#04141a', glow: '{colors.primary}', font: 'display-sm' }
  sell-button:             { bg: 'transparent', border: '{colors.primary}', label-color: '{colors.primary}', gem-color: '{colors.score}', font: 'display-sm' }
  currency-readout:        { surface-tint: '{colors.primary}', border: '{colors.primary}', amount-font: 'numeric-lg', amount-color: '{colors.text}', gem-color: '{colors.primary}', unit-font: 'label-caps', unit-color: '{colors.muted}', scope: 'shop-stage-only' }
  main-wing-chip:          { main-color: '{colors.primary}', wing-color: '{colors.health}', font: 'label-caps', dot-glow: 'currentColor', text-label-required: true }
  rarity-pip:              { common-color: '{colors.muted}', common-shape: 'hollow-square', rare-color: '{colors.climax-primary}', rare-shape: 'filled-diamond', rare-glow: '{colors.climax-glow}' }
  synergy-tooltip:         { surface: '{colors.surface}', border: '{colors.primary}', label-font: 'label-caps', label-color: '{colors.primary}', body-font: 'body-sm', body-color: '{colors.text}', scrim-blur: '6px' }
  button:                  { primary-fill: '{colors.primary}', primary-label: '#04141a', secondary-border: '{colors.primary}', radius: '{rounded.md}', font: 'display-sm', min-height: '40px' }
  panel-scrim:             { fill-top: 'rgba(4,7,14,0.74)', fill-bottom: 'rgba(4,7,14,0.86)', blur: '6px', saturate: '0.85' }
  chip:                    { surface-tint: '{colors.surface}', border: '{colors.border}', font: 'label-caps', radius: '{rounded.sm}' }
  menu-item:               { resting-color: '{colors.muted}', focus-color: '{colors.primary}', focus-fill-alpha: '8%', focus-glow: '{colors.glow}', font: 'menu', radius: '{rounded.md}' }
  slider:                  { track-from: '{colors.primary}', track-to: '{colors.climax-primary}', thumb-fill: '{colors.text}', thumb-stroke: '{colors.primary}', thumb-glow: '{colors.primary}' }
  codex:                   { surface: '{colors.surface-alt}', border: '{colors.border}', body-font: 'body', body-color: '{colors.muted}', accent-color: '{colors.primary}' }
  toast:                   { surface: '{colors.surface}', border: '{colors.primary}', title-font: 'display-sm', title-color: '{colors.primary}', body-font: 'body-sm', body-color: '{colors.text}', glow: '{colors.glow}' }
---

# DESIGN.md — Meridian Run (2D fixed-screen roguelite shooter · Godot 4.6)

> **Source of truth.** This spine and EXPERIENCE.md are distilled from
> `.decision-log.md` (canonical). The three key-screen mocks in `mockups/`
> (`key-hud.html`, `key-build-screens.html`, `key-title.html`) are promoted
> supporting evidence; the two selection studies (`color-themes-1.html`,
> `type-specimen-1.html`) stay in `.working/`. **Spines win on conflict
> with any mock, wireframe, or import.** Every decision is keyed
> (F/V/T/M/A/O/H/C/S/G/I/D/P prefixes) to the log; the canonical names
> below are identical in EXPERIENCE.md.

---

## Brand & Style

Meridian Run is a **neon-vector arcade** (V1) built on a *Galaga*-lineage
1-axis chassis — the player is locked to a bottom lane, fire is vertical, the
screen is fixed. The identity cue is non-negotiable and governs every visual
choice on this page: **the player reads as rescuer, never aggressor.** Capture
columns tint as `{colors.hazard}` — a *danger to dodge* — never as a weapon the
player aims. The docked wingman reads as an *allied escort* in the hero-neon
family (`{colors.dock}`), never as a hostile. Power is depicted as **bigger +
glowier** (C1 docked fighter, C2 sacrifice-burst), but the enlargement stays
modest so Rosa can always parse her true hitbox at the godhood peak (N5).

The aesthetic posture is **Llamasoft / Jeff Minter neon-vector maximalism**
(G1) — Tempest 2000, TxK, Polybius lineage — channelled through the Geometry
Wars / Resogun / Nova Drift clarity discipline. Pixel art is explicitly
**rejected** (cost + readability, V1); the look is rendered vector on the
Compatibility renderer. Tone of voice lives in EXPERIENCE.md, but it shapes
every label you see here: punchy, maximal, personality-forward (M1) —
`TRIPLE BROADSIDE`, not "Triple Fire"; `WAVE 17 — HOLD THE LINE`, not "Wave 17."

The signature structural move is the **calm→climax palette arc (V3)**: the
visual identity is not one theme, it is an *arc*. The screen opens cold and
clinical (Vector Standard, `{colors.primary}` `#00E5FF`) and escalates to a
magenta synthwave altar (Polybius Dusk, `{colors.climax-primary}` `#FF2BD6`)
as build power compounds — the palette itself is a juice channel for the
*glass-cannon-god* fantasy. Both ends carry the same shape-glyph system so the
colorblind-safety contract (A1) holds across the entire arc.

---

## Colors

Tokens are declared in **Vector Standard** (calm base / load-time) in the
frontmatter; **Polybius Dusk** overrides are declared under the `climax-*`
prefix and applied as build power compounds (rare cards repaint, the arena
warms at the godhood peak). The interpolation is per-token — every frontmatter
color has a defined climax terminus, so the arc can be driven by a single
0→1 parameter at runtime. See `.working/color-themes-1.html` for the
5-palette study (Vector Standard · Cinder Siege · Phosphor Terminal ·
Polybius Dusk · Clinical Trial) — only Vector Standard and Polybius Dusk are
load-bearing; the other three are evaluation variants, not shipped themes.

### Calm base — Vector Standard

| Token | Hex | Story |
|---|---|---|
| `{colors.surface}` | `#060912` | The play-field void. Deep near-black with a cold blue undertone — never pure black, never warm. |
| `{colors.surface-alt}` | `#0C1424` | One step up: panels, cards, the build-screens shell. Same hue family as surface so layering reads as depth, not a different material. |
| `{colors.text}` | `#E6F1FF` | Primary HUD and menu ink. Cold-white — matches the surface undertone so type never looks pasted-on. |
| `{colors.muted}` | `#7E8DAA` | Secondary labels, dividers, micro-copy. **Lifted from `#6B7B9A` specifically to clear WCAG-AA 4.5:1 on surface** (A1) — the original mock value was contrast-borderline. |
| `{colors.border}` | `#1E2A44` | Panel edges, cell dividers, the lane track, dashed empty-pip outlines. Stays in the cold blue family. |
| `{colors.primary}` | `#00E5FF` | **The hero neon.** Allied hero-channel: player ship stroke, primary buttons, focus rings, docked-wingman family, GAUNTLET modifier, engine glow. Never used for the player's own damage. |
| `{colors.primary-hover}` | `#5AF7FF` | Brighter variant — TAKE buttons, focused card border, currency-readout tint, timer suffix. The "lit up" state. |
| `{colors.health}` | `#4ADE80` | HP segments (player + multi-hit enemies share the idiom, H6) and the WING track / allied-rescue family (C1). |
| `{colors.hazard}` | `#FF3D5A` | **The dodge signal.** Tractor/capture column edges + fill, enemy fire-columns, damage vignette, SWARM modifier. The player reads this hue as *threat to evade*, never as their own output. Calm value held constant; at the climax this token interpolates to `{colors.climax-hazard}` amber `#FF9E3D` (hue+luminance-distinct from climax magenta — see Climax overrides). |
| `{colors.score}` | `#FFE066` | Score numerics, damage popups, SELL gem color, BOUNTY modifier. Warm amber — the only warm hue in the calm base, reserved for *player reward*. |
| `{colors.currency}` | `#C084FC` | CHIPS / shop-stage only. **NOT displayed in the in-wave HUD** (H2) — wave score converts to currency at the shop. Kept in the palette so grunt/mag-bullet accents still track it. |
| `{colors.modifier-swarm}` | `#FF3D5A` | SWARM chip — shape glyph: scattered cluster. Reinforces `{colors.hazard}` (swarm = many threats). |
| `{colors.modifier-gauntlet}` | `#00E5FF` | GAUNTLET chip — shape glyph: vertical columns. Reinforces `{colors.primary}` (columnar fire = player's own idiom inverted). |
| `{colors.modifier-bounty}` | `#FFE066` | BOUNTY chip — shape glyph: single diamond. Reinforces `{colors.score}` (bounty = reward). |
| `{colors.glow}` | `#5AF7FF` | Neon halo used on every glowing element (focus rings, ship engine, numerics shadows). Pairs with `{colors.primary}`. |
| `{colors.dock}` | `#5AF7FF` | **[ASSUMPTION]** Docked-wingman accent (OQ3 provisional). Aliased to `{colors.primary-hover}` so the escort reads allied-hero, not aggressor. Revisit at the Shield-PU pass — a dedicated non-aggressor dock token + ring/halo affordance may be wanted; the ring visual is **reserved** for future Shield semantics (H6). |

### Climax overrides — Polybius Dusk (V3 peak)

As build power compounds, the same token set interpolates toward these
termini. The arc is a **color change, not a face change** (T2) — typography
and shape language hold; only hue shifts. One rare card per build screen
repaints wholesale (sigil included) to `{colors.climax-primary}` `#FF2BD6`.

| Climax token | Hex | Delta from calm |
|---|---|---|
| `{colors.climax-surface}` / `-surface-alt` / `-border` | `#0F0820` / `#1A1030` / `#2E1A4A` | Hue rotates from cold blue to magenta dusk; value held. |
| `{colors.climax-primary}` / `-primary-hover` | `#FF2BD6` / `#FF6BE8` | Hero neon cyan → magenta. |
| `{colors.climax-health}` | `#00F0C0` | HP green → teal — stays cool/green-family so the rescuer read holds. |
| `{colors.climax-glow}` | `#FF6BE8` | Halo tracks the new hero. |
| `{colors.climax-muted}` | `#9979B0` | Lifted from `#8A6B9A` (4.32:1) to **clear WCAG-AA on `climax-surface`** — measured 5.31:1 (A1). The calm `muted` already cleared AA on both surfaces, but the climax terminus re-failed it; pinned here so muted labels (modifier chips, empty HP-pip outlines, `build-summary-rail` empty slots, codex body, lost-pip stroke) hold at the peak. |
| `{colors.climax-hazard}` | `#FF9E3D` | **Amber** — the climax terminus for `{colors.hazard}`. Calm hazard stays red `#FF3D5A` (calm hero is cyan → already maximally distinct); the red-vs-magenta collapse only happens at climax vs `{colors.climax-primary}`. Amber is hue- AND luminance-distinct from climax magenta (`ΔL 0.18` vs the `0.025` collapse) and reads as "danger" without entering the magenta neighborhood. Enemy fire-columns + the `capture-column` tractor render in `{colors.climax-hazard}` at the climax. (A2.) |
| `{colors.score}` | unchanged | Score is an **anchor hue** — `#FFE066` holds across the arc so reward stays legible at the peak. |

### Color-safety core (A1, N6) — shape+outline carries the meaning, color reinforces

**Player-vs-hazard is never hue-alone.** The player-affiliated family — the
**player ship, the player's own projectiles, the `docked-wingman-indicator`** —
ALWAYS carries a distinct **silhouette + a bright outline** that NEVER matches
**enemy fire-columns / the `capture-column` tractor / damage flashes**,
regardless of arc palette (calm Vector Standard or Polybius Dusk climax).
Color reinforces the read; **shape + outline carries the meaning.** This is
the load-bearing CVD defense: at the climax, hero `{colors.climax-primary}`
magenta and `{colors.hazard}` red collapse to near-identical luminance for
red-green CVD players (~8% of male players) — exactly at the densest,
highest-stakes moment (Rosa wave-20). The shape+outline differentiator makes
the player/hazard distinction survive the repaint even in monochrome. (A2.)
See **Components** for the concrete treatments, and **Do's and Don'ts** for
the rule stated as a constraint.

This generalizes to every hue-encoded concept (HP, hazard, build family,
rarity, modifier): **color is never the sole signal** — every one is
reinforced by **shape + glyph + outline** (I1, A1). The shape-glyph system
holds across the entire calm→climax arc.

### Color meaning is screen-scoped (N6)

The same hue may carry different meanings on different screens **as long as
those screens never co-occur.** Generator-green `{colors.health}` on a build
card (the GENERATOR family) vs HP-green in the in-wave HUD — no conflict,
because build screens overlay a *paused* arena, never the live HUD. This
justifies keeping build-family colors on existing tokens (I1) without
conflation risk. See **Do's and Don'ts**.

> **N6 does NOT license the player-vs-hazard case** (the color-safety core
> above): player ship/projectiles/wingman and enemy fire/tractor DO co-occur
> on the live in-wave HUD, on the same screen, at the same moment. They are
> therefore exempt from the screen-scoped defense and MUST be shape+outline
> differentiated (A2). Score-amber and bounty-amber are likewise co-located
> (both in the in-wave HUD top-right) — see `score` / `modifier-bounty`.

### Contrast targets (A1 — WCAG-AA 4.5:1)

Load-bearing combos, measured against the calm-base surface (and, for climax
tokens, against `climax-surface`):

| Foreground | Background | Ratio | Verdict |
|---|---|---|---|
| `{colors.text}` `#E6F1FF` | `{colors.surface}` `#060912` | ≈ 17:1 | Pass AAA |
| `{colors.muted}` `#7E8DAA` | `{colors.surface}` `#060912` | ≈ 5.95:1 | Pass AA (the lift from `#6B7B9A` was required for this) |
| `{colors.primary}` `#00E5FF` | `{colors.surface}` `#060912` | ≈ 12.9:1 | Pass AAA |
| `{colors.score}` `#FFE066` | `{colors.surface}` `#060912` | ≈ 15:1 | Pass AAA |
| `{colors.health}` `#4ADE80` / `{colors.hazard}` `#FF3D5A` | `{colors.surface}` `#060912` | ≈ 11:1 / ≈ 5.75:1 | Pass AAA / Pass AA |
| `{colors.climax-muted}` `#9979B0` | `{colors.climax-surface}` `#0F0820` | ≈ 5.31:1 | Pass AA (lifted from `#8A6B9A` @ 4.32:1 — the calm muted lift re-failed at the climax; pinned to clear AA) |
| `{colors.climax-hazard}` `#FF9E3D` | `{colors.climax-surface}` `#0F0820` | ≈ 9.5:1 | Pass AAA (amber — hue+ luminance-distinct from climax magenta; the climax terminus for `{colors.hazard}`) |
| HUD numerics (`{colors.text}`, `{colors.score}`) | `panel-scrim` effective bg (~`#040714` at 80% over arena) | ≥ 14:1 | Pass AAA |
| `{colors.muted}` modifier-chip label on tinted chip fill | chip fill @ 6–12% token alpha over surface | ≥ 5:1 | Pass AA |

---

## Typography

Three roles, one scale. Direction is locked (T2): **condensed-techno display,
clean grotesk body, monospace numerics.** Final face pick is Chakra Petch /
Inter / JetBrains Mono (coach lean, specimen-confirmed); each stack carries
robust techno/sans/mono fallbacks so the look degrades cleanly if a face
fails to load. Faces import as `.ttf` in Godot. See
`.working/type-specimen-1.html` for the side-by-side specimen under both ends
of the arc.

- **Display — Chakra Petch** (`typography.display-*`). Condensed-techno with
  squared apertures → the *neon-sign / tactical-HUD* read (Geometry-Wars
  vector, not sport-stripe). Used for the game logo, wave banners, sacrifice
  prompts, power-up names, card names, button labels, screen headers. Weight
  `700`, tracking `+0.045em–+0.13em` (wider tracking at smaller display sizes).
- **Body — Inter** (`typography.menu`, `body`, `body-sm`). Clean grotesk;
  lowest visual noise at small sizes for menus, tooltips, codex prose, card
  effect copy. Weights `400` (body/tooltip/codex) and `600` (menu items,
  selected row).
- **Numerics — JetBrains Mono** (`typography.numeric-*`,
  `typography.label-caps`). Fixed-width → digits hold their columns as
  score/HP/timer/currency change, so a counting value **never jitters**
  digit-to-digit. Damage popups at `numeric-xl` `700`; score at `numeric-lg`
  `700`; timer at `numeric-md` `500` (calm) shifting to `{colors.hazard}` at
  low-time; small stat reads at `numeric-sm` `600`. Small-caps labels
  (`label-caps`) are also mono — chips, modifier readouts, section eyebrows.

**Scale** is a perfect fourth, **1.333 from a 16px base** — `16 / 21 / 28 /
38 / 50`. The same ramp serves all three roles; only the family swaps.

**Climax is a color change, not a face change.** Polybius Dusk does not swap
or stretch the type; it recolors the display hero from `{colors.primary}` to
`{colors.climax-primary}`. A face that shines at calm but smears at climax
would be the wrong pick — the specimen tests both ends deliberately.

---

## Layout & Spacing

**8px base grid** (`spacing.'2'`). Every dimension snaps to a 4px half-grid at
minimum. The grid is the rhythm of the whole UI — panel padding, card gaps,
HUD zone padding, segment gaps all resolve to multiples of 4.

- **HUD top band** — all in-wave HUD lives in a single `{spacing.hud-band}`
  (58px) band across the top of the 16:9 frame (H5): lives zone left, timer
  zone center, score+wave+modifier zone right. **Nothing in-wave ever crosses
  into the 1-axis play lane** (`{spacing.lane-band}`, 54px at the bottom) —
  F3.
- **Build screens** — a paused, dimmed arena under a `panel-scrim`; the build
  UI floats on top with `{spacing.margin-frame}` (32px) frame padding, a
  `topline` row, a centered cards row (3 cards select / 4 cards shop), and
  the `build-summary-rail` docked at the bottom (H4 — build surfaces in calm
  moments, S1).
- **Title-safe** — `{spacing.title-safe}` (5%) margin kept around
  combat-critical HUD under `canvas_items`+`expand` stretching (F4), so the
  HUD survives non-uniform scaling on Steam Deck without clipping (P1).
- **Gutters** between cards: `{spacing.gutter}` (24px) for 3-card select,
  ~16px for 4-card shop (denser, same anatomy).

---

## Elevation & Depth

Depth is **tonal + neon**, not material. There are no thick card shadows
mimicking paper.

- **Layer stack** (z, low → high): play-field (world tree) → in-wave HUD on a
  separate **CanvasLayer** (F3) → `panel-scrim` (paused-arena depth-of-field)
  → build / menu UI → transient `toast` / `synergy-tooltip` layer.
- **Neon glow** (`{colors.glow}`, `{colors.climax-glow}`) is the primary
  depth cue on the play-field: focused elements gain an outer halo + a
  brighter stroke, never a drop-shadow. Numerics carry a colored
  `text-shadow` halo (`{colors.score}` on score, `{colors.primary}` on timer).
- **Scrim depth** — `panel-scrim` is a translucent dark gradient
  (`rgba(4,7,14,.74→.86)`) **plus a 6px backdrop-blur at 0.85 saturation**.
  That blur is the "calm moment" signal (S1): the arena is paused, the build
  surfaces sharp.
- **Cards** lift via a tight ambient shadow (`0 18px 40px -22px rgba(0,0,0,.85)`)
  plus a 1px inset top highlight — they read as glass panels, not paper.
  Rare cards add a magenta halo (`{colors.climax-glow}`).
- **No nested modals** — pause/build replaces the view; never stacks (F9
  fail-safe).

---

## Shapes

**Near-zero radii** — the neon-vector look demands sharp geometry. The scale
runs from `{rounded.none}` (0px, sigil internals, HP segment tops) through
`{rounded.xs}` (2px, HP pips, tiny chips) and `{rounded.sm}`–`{rounded.md}`
(4–8px, chips, buttons, currency readout, sigil plate) up to
`{rounded.lg}`–`{rounded.xl}` (12–16px, cards, panels, windows). Pill
(`{rounded.full}`) is reserved for the rarest accents (modifier chips in the
HUD-corner variant, circular shield ring) — the default chip on build screens
is `{rounded.sm}`, not a pill. HP bars are always **segmented with hard gaps**
(`hp-bar` idiom) — never a smooth fill — so segment count is readable at a
glance (H6). The **ring/halo** shape is **reserved for future Shield
power-up semantics** (H6) and is not used for HP.

---

## Components

Each row is the visual spec; behavior lives in EXPERIENCE.md → Component
Patterns. Names are identical across both files.

**HUD** — full anatomy, calm and focus/fade states, illustrated in
`mockups/key-hud.html` (standard + Rosa W20 climax windows).

- **`lives-display`** — ship-icon pips top-left (`{spacing.hud-band}`). Lit
  pip: transparent fill + `{colors.primary}` stroke + `{colors.glow}`
  drop-shadow. Lost pip: dashed `{colors.muted}` stroke at 55% opacity (never
  removed — the gamble reads only if max-ships is visible, S1). Trailing
  `×N` label in `numeric-sm` `{colors.muted}`. Ship name above in `label-caps`
  `{colors.primary}`.
- **`wave-timer`** — top-center, the prominent survive-to-end read (T1/H3).
  `{numeric-lg}` `{colors.text}` with `{colors.primary}` glow halo; `s` suffix
  in `{colors.primary}`; `SURVIVE` label in `label-caps` `{colors.muted}`. At
  low-time the numeric shifts to `{colors.hazard}` (climax: `{colors.climax-hazard}`)
  and **its glow halo goes NEUTRAL white** — it does NOT track the hero
  `{colors.primary}` (which is magenta at climax and would bleed red-on-magenta).
  Equivalently the numeric may sit on its own opaque `{colors.surface}` chip so
  the hazard number stays crisp over a busy Polybius-Dusk particle storm. **Stays
  sharp through focus/fade** (S1).
- **`score-readout`** — top-right. Label `SCORE` (`label-caps`
  `{colors.muted}`) above a `{numeric-lg}` `{colors.score}` value with
  `{colors.score}` glow. **Score only in-wave** — currency never shown (H2).
- **`wave-modifier-readout`** — small persistent readout under the score:
  `WAVE 17` (`label-caps` `{colors.muted}`) + a modifier chip (`⬢ GAUNTLET`
  / cluster SWARM / ◆ BOUNTY). **Shape carries meaning first**, color
  reinforces (A1): cluster = `{colors.modifier-swarm}`, columns =
  `{colors.modifier-gauntlet}`, diamond = `{colors.modifier-bounty}`. Chip
  fill at ~6% token alpha, border at ~55%, on `{rounded.sm}`.
- **`hp-bar`** — segmented bar **above the player ship** (H4, primary read).
  Segments: 10×4px, `{rounded.xs}`, 3px gap, fill `{colors.health}` +
  `{colors.health}` glow; empty segments are transparent with a
  `{colors.muted}` 1px outline. **Same idiom on multi-hit / damaged enemies**
  (shielders, captors, bosses; hidden at full HP, absent on 1-hit grunts —
  H6). Ring/halo reserved for future Shield PU, **not** HP.
- **`build-summary-rail`** — **not in the in-wave HUD.** Surfaces on
  ship-select + between-wave build screens (calm moments, S1/H4). Two ladder
  rows (MAIN `{colors.primary}` / WING `{colors.health}`) of `chip`-style
  build chips with sigil + name; empty slots dashed `{colors.muted}`.
  Right-side econ column hosts `currency-readout` + a `label-caps` hint.
- **`capture-column`** — the tractor telegraph (C3), locked to player X, an
  **enemy-threat** element (`hazard-family`). Two glowing boundary edges
  (`{colors.hazard}`, `{colors.hazard}` glow; climax: `{colors.climax-hazard}` amber)
  with a translucent `{colors.hazard}` fill between (**~5% at the ends → ~22% in
  the body** — coach-refined down from 80–90% so the ship inside stays
  readable); climax fill renders `{colors.climax-hazard}`. Optional vertical
  `sweep` animation. **Shape stamp: two parallel vertical bars** — never the
  arrowhead/chevron silhouette used by the player family. **Stays sharp through
  focus/fade** — fair-dodge telegraph must stay readable at the climax.
- **`docked-wingman-indicator`** — the docked dual-fighter (C1), offset to
  one side of the main ship at **~80% scale** (slight overlap → pair reads as
  one unit), a **player-family** element. Stroke + tint `{colors.dock}`
  (provisional alias of `{colors.primary-hover}`, OQ3) with a **bright outline**
  so it reads allied-hero even at the climax magenta repaint. **Shape stamp:
  escort-chevron** (mirrors the player-ship arrowhead family), never the pellet/
  parallel-bar silhouette of enemy fire or the tractor. A `{colors.dock}` ring
  at 55% alpha surrounds it — **the ring is reserved for Shield semantics**
  (first-hit-absorber affordance), consistent with the `hp-bar` reservation (H6).
- **`player-ship`** — the hero arrowhead (player-family). Stroke
  `{colors.primary}` (climax: `{colors.climax-primary}`) over a **bright
  `{colors.text}` core + a bright outer outline** that survives the climax
  repaint. **Shape stamp: rescuer-arrowhead** — pointed nose, splayed tail —
  a silhouette shared with the docked wingman, never matched by enemy fire
  (pellets) or the `capture-column` (parallel bars). The bright outline is
  what holds the player/hazard distinction in monochrome (A2).
- **`player-projectile`** — the player's own fire (player-family).
  **Shape stamp: elongated chevron** with a bright `{colors.text}` core and a
  `{colors.primary}` (climax: `{colors.climax-primary}`) bright outline —
  visibly longer and outlined vs the small pellet of `enemy-fire`. The
  elongation + outline is the CVD-safe signal; color reinforces. (A2.)
- **`enemy-fire`** — enemy fire-columns (enemy-threat, `hazard-family`).
  **Shape stamp: small pellet** (compact rounded dot), fill `{colors.hazard}`
  (climax: `{colors.climax-hazard}`), **no bright outline** — visually lighter
  and unoutlined next to the player's elongated, outlined chevrons. Never
  shares the arrowhead/chevron silhouette. (A2.)

**Build screens**

- **`power-up-card`** — anatomy: `sigil-plate` (78px, `{rounded.md}`,
  sigil-colored radial tint) → `card__name` (`display-sm` `{colors.text}`
  with accent glow) → `card__effect` (`body-sm` `{colors.text}`) → `meta` row
  (`main-wing-chip` + `rarity-pip`) → `card__foot` actions. Surface
  `{colors.surface-alt}` with a faint accent-tinted gradient; border at ~32%
  accent; `{rounded.lg}`. **States** (5): `default` · `focus` (gamepad hover:
  `{colors.primary-hover}` ring, corner brackets, -7px lift, accent halo —
  independent of rarity) · `selected`/`rare` (whole-card repaint to
  `{colors.climax-primary}` family, sigil included; shape still holds) ·
  `disabled` (shop unaffordable: 50% opacity, saturation .35, brightness .85;
  shape still readable). See `mockups/key-build-screens.html`.
- **`take-button`** — primary action (TAKE on select / BUY on shop). Solid
  gradient fill (`{colors.primary-hover}` → `{colors.primary}`), label
  `#04141a` on `{display-sm}`, `{colors.primary}` outer glow, `{rounded.md}`,
  min-height 40px. On `disabled`: flat `{colors.surface-alt}` + dashed
  `{colors.border}` + `{colors.muted}` label.
- **`sell-button`** — secondary, select-only. Transparent bg, 1px
  `{colors.primary}` border, `{colors.primary}` label, SELL gem glyph in
  `{colors.score}`. Same `{display-sm}` / `{rounded.md}`.
- **`currency-readout`** — CHIPS, **shop-stage only** (H2). Pill on
  `{colors.surface}`: `{colors.primary}` border + 8% tint + glow, ◆ gem in
  `{colors.primary}`, amount in `{numeric-lg}` `{colors.text}`, `CHIPS` unit
  in `label-caps` `{colors.muted}`. Never rendered in the in-wave HUD.
- **`main-wing-chip`** — the dual-ladder target chip (I2). MAIN variant:
  `{colors.primary}` text + border + tint + glowing dot. WING variant:
  `{colors.health}` (allied/rescue family, ties C1). `label-caps` font.
  **Text label required** (MAIN/WING) — never color-alone (A1).
- **`rarity-pip`** — shape-coded rarity marker (I1). COMMON: hollow square
  (`{colors.muted}` stroke, `{rounded.xs}`). RARE: filled diamond
  (`{colors.climax-primary}` fill, rotated 45°, `{colors.climax-glow}` halo).
  Shape holds when color is removed.
- **`synergy-tooltip`** — one-line interaction hint under the focused card.
  `{colors.surface}` at 90% alpha + `{colors.primary}` border + 6px blur;
  `SYNERGY` label (`label-caps` `{colors.primary}`) over `body-sm`
  `{colors.text}` prose. Pointer-events none.

**General**

- **`button`** — primary (TAKE/BUY/CONFIRM) per `take-button` anatomy;
  secondary (BACK/SELL) per `sell-button`. All `{display-sm}` `{rounded.md}`
  min-height 40px. The menu variant uses `menu-item` styling instead.
- **`panel-scrim`** — the paused-arena depth-of-field layer. Linear gradient
  `rgba(4,7,14,.74)` → `rgba(4,7,14,.86)`, **6px backdrop-blur, 0.85
  saturation**. Hosts all between-wave build UI and pause menus.
- **`chip`** — base anatomy for modifier, target, and build chips.
  `{colors.surface}` tint + `{colors.border}` + `label-caps` + `{rounded.sm}`.
  Variants set their own accent color (modifier / MAIN / WING).
- **`menu-item`** — vertical-menu row. Resting: `{colors.muted}` on
  transparent. Focus: `{colors.primary}` text + 8% `{colors.primary}` fill +
  `{colors.glow}` halo + `{colors.primary}` border at 40%, on `{rounded.md}`.
  Right-aligned kbd-hint in `numeric-sm` `{colors.muted}` inside a
  `{colors.border}` `{rounded.xs}` key cap.
- **`slider`** — settings (volume, deadzone, UI-scale, reduced-motion).
  Track gradient `{colors.primary}` → `{colors.climax-primary}` (signals the
  calm→climax axis on the deadzone slider), thumb a `{colors.text}` disc with
  `{colors.primary}` stroke + `{colors.primary}` glow.
- **`codex`** — pause help (O1). `{colors.surface-alt}` panel,
  `{colors.border}` 1px, `body` prose in `{colors.muted}` with key terms in
  `{colors.text}`, accent rule `{colors.primary}`. Covers ship stats,
  modifier meanings, the gamble.
- **`toast`** — transient unlock / feat notification (**[ASSUMPTION]**,
  OQ9). `{colors.surface}` + `{colors.primary}` border + `{colors.glow}`
  halo; title `display-sm` `{colors.primary}`, body `body-sm`
  `{colors.text}`. Appears between waves, never mid-wave.

---

## Do's and Don'ts

- **Do** keep combat-critical HUD (timer, on-ship HP, lives) in the same
  place, always — muscle memory is the contract (H4, H5).
- **Do** treat the calm→climax arc as a single 0→1 parameter; never hand-tune
  per-screen palettes (V3).
- **Do** differentiate by **shape first, color second** — every hue-encoded
  concept needs a shape/glyph fallback (A1, I1).
- **Do** keep the **player-vs-hazard distinction shape+outline-coded, not
  hue-coded** (color-safety core, A2): the player ship / player projectiles /
  `docked-wingman-indicator` ALWAYS carry a distinct **silhouette + bright
  outline** (`rescuer-arrowhead` / `elongated-chevron` / `escort-chevron`) that
  NEVER matches enemy fire-columns (`small-pellet`) or the `capture-column`
  tractor (parallel bars), in any arc palette. This is the load-bearing CVD
  defense and it survives a full repaint to monochrome. The N6 screen-scoped
  defense does **not** apply here — these elements co-occur on the live HUD.
- **Do** interpolate `{colors.hazard}` → `{colors.climax-hazard}` amber
  `#FF9E3D` across the arc (calm hazard stays red — calm hero is cyan, already
  maximally distinct; the collapse only happens at climax vs magenta). Amber
  is hue- AND luminance-distinct from climax magenta and reads as "danger."
- **Do** lift muted to clear WCAG-AA on its surface at BOTH arc ends — calm
  `{colors.muted}` `#7E8DAA` (5.95:1) and climax `{colors.climax-muted}`
  `#9979B0` (5.31:1, lifted from `#8A6B9A` @ 4.32:1).
- **Do** keep the `hp-bar` segmented with hard gaps; max-HP must always be
  readable (H6).
- **Do** keep the build-family colors on the existing tokens — color meaning
  is screen-scoped (N6), so generator-green on a build card does not conflict
  with HP-green in the live HUD because those screens never co-occur.
- **Don't** render `{colors.currency}` in the in-wave HUD (H2). It is a
  shop-stage concept only.
- **Don't** animate numeric digits with a proportional font — use the
  `numeric-*` (JetBrains Mono) tokens so digits hold their columns (T2).
- **Don't** use the ring/halo shape for HP — it is reserved for future Shield
  power-up semantics (H6).
- **Don't** tint capture columns, enemy fire, or the damage vignette with the
  player's hero `{colors.primary}` / `{colors.climax-primary}` — the player
  reads as rescuer, never aggressor (V1). Threats are `{colors.hazard}` (calm)
  / `{colors.climax-hazard}` amber (climax) — and even so, the player/hazard
  distinction never relies on hue alone (color-safety core, A2).
- **Don't** stack modals — `panel-scrim` replaces the view (F9).
- **Don't** rely on color alone for rarity — the `rarity-pip` shape (hollow
  square vs filled diamond) must hold when color is removed (A1, I1).
