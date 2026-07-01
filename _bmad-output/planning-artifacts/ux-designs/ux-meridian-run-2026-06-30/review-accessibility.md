# Accessibility Review — Meridian Run

**Scope:** DESIGN.md + EXPERIENCE.md spines, `.decision-log.md` A1 floor (with H/M/C/I/T
context), and the four `.working/*.html` mocks. Reviewer: accessibility gate, indie-serious
stakes. All contrast ratios below are independently computed (WCAG 2.1 relative luminance),
not taken from the spine's self-reported table.

## Overall verdict

The A1 floor is well-scoped and **mostly holds at the calm (Vector Standard) end** — the
shape-glyph system for modifiers, rarity, family sigils, and the MAIN/WING chip genuinely
carries meaning independent of hue, and `muted` was correctly lifted to clear AA. **It breaks
at the climax end**, where the spine's signature juice mechanic (the calm→climax palette arc)
collapses hero-neon and hazard-red to near-identical luminance for red-green CVD players —
exactly at the Rosa wave-20 moment the whole design is built around — and the
faction/projectile distinction that A1 explicitly promises "via shape + outline" is color-only
in every render. Two further committed claims don't hold in the actual mocks (the climax-muted
token fails AA; all four mocks ship the pre-lift muted value). Fixable at the design layer
before code; none require re-architecting the arc.

## Findings by severity

### Critical (1)

- **[Critical]** **Hero-vs-hazard color collapse at the Polybius Dusk climax — color is the
  sole signal, contradicting A1's explicit "faction/projectile via shape + outline, not color
  alone" commitment.** The calm→climax arc interpolates `{colors.primary}` cyan `#00E5FF` →
  magenta `#FF2BD6` while `{colors.hazard}` red `#FF3D5A` is an *anchor hue* held constant
  across the arc (DESIGN.md §Climax overrides, line 190). At calm the hero/hazard pair is
  high-contrast and chromatically opposite (ΔL = 0.379). At climax the pair is `#FF2BD6` vs
  `#FF3D5A` — adjacent red/magenta hues with ΔL = **0.025**, effectively the same luminance.
  For protanopes/deuteranopes (~8% of male players) the player ship, player projectiles, the
  docked-wingman family, the GAUNTLET modifier, and the capture-column/enemy-fire/damage
  threat family become confusable precisely when the screen is densest and the stakes highest
  (EXPERIENCE.md §Rosa at the wave-20 climax, lines 284–317). The renders confirm there is no
  shape/outline backup: every `.bullet` variant in `key-hud.html` (lines 777–807) shares an
  identical 5×9px rounded shape — only `background` differs — and `color-themes-1.html`
  documents the hero ship and hazard both inherit `currentColor` with no shape stamp
  differentiating them. The calm→climax arc is the load-bearing juice fantasy (V3); it cannot
  also be the place A1 silently fails. *Fix:* give the player side a shape stamp the enemy/
  hazard side lacks and make it survive the repaint — e.g. player projectiles as elongated
  chevrons with a bright core/outline, enemy fire as small pellets; add a persistent outline
  or cross-section to the player ship independent of `--primary`. Alternatively, route the
  hero interpolation away from the red neighborhood (cyan→teal→white-hot rather than
  cyan→magenta) so it never enters hazard's hue band. (locations: DESIGN.md §Colors → Climax
  overrides & §Brand & Style; EXPERIENCE.md §Accessibility Floor; `.working/key-hud.html`
  §BULLETS lines 777–807, §ENEMIES lines 812–864; `.working/color-themes-1.html` hero/hazard
  token usage.)

### High (3)

- **[High]** **`climax-muted` `#8A6B9A` fails the WCAG-AA 4.5:1 bar on `climax-surface` —
  measured 4.32:1.** The spine loudly and correctly documents that calm `muted` was "lifted
  from `#6B7B9A` to clear WCAG-AA 4.5:1 on surface" (DESIGN.md §Colors table, line 208, verified
  at 5.95:1). But the Polybius Dusk terminus `climax-muted` (DESIGN.md frontmatter line 33)
  re-breaks that bar at the climax surface `#0F0820` (4.32:1 by independent computation). Muted
  carries modifier-chip labels, empty HP-pip outlines, `build-summary-rail` empty slots, the
  codex body, and the `lives-display` lost-pip stroke — and the build screens (rare-card
  repaints, the codex) render under the warm climax surface. The arc lifts calm muted and then
  re-fails it at climax. *Fix:* either hold `muted` constant across the arc (the calm value
  already clears AA on the climax surface too), or pin a climax terminus that clears 4.5:1 on
  `#0F0820` (need luminance roughly ≥ `#9979B0` — verify the chosen value). (location:
  DESIGN.md frontmatter `climax-muted` + §Colors → Climax overrides.)

- **[High]** **Low-time `wave-timer` contrast is marginal at the climax, and the "stays sharp"
  commitment can compound it.** At low-time the timer numeric shifts `{colors.text}` →
  `{colors.hazard}` `#FF3D5A` (DESIGN.md §`wave-timer`, line 339; EXPERIENCE.md §`wave-timer`).
  On the climax surface that is **5.64:1** — passes AA for normal text but fails AAA, and is the
  worst case for the most-attended read at the highest-stakes moment. Two aggravators: (1) the
  HUD top-band backing is a *translucent* scrim (`key-hud.html` `.topband`, 92%→55%→0%
  surface), not an opaque plate, so effective contrast over a busy Polybius-Dusk particle storm
  at the wave-20 climax dips below the measured value; (2) the focus-state timer text-shadow
  stays `var(--primary)` (`key-hud.html` lines 1083–1088) — at climax that is *magenta*, so a
  magenta halo bleeds into a red numeric over a magenta-red arena. The S1 commitment to keep
  the timer "sharp through focus/fade" (good — it doesn't dim) does not help when
  sharp-on-busy is the load case. *Fix:* give the low-time timer a guaranteed-dark backing
  (extend the scrim locally or wrap the numeric in an opaque chip), and recolor the low-time
  glow halo to track the numeric state (hazard-tinted, not primary-tinted). (locations:
  DESIGN.md §`wave-timer`; EXPERIENCE.md §`wave-timer` & §HUD & Diegetic UI → What fades;
  `.working/key-hud.html` §topband lines 511–516, §focus timer lines 1083–1088.)

- **[High]** **All four mocks ship the pre-lift muted value `#6B7B9A` (4.67:1), not the
  committed `#7E8DAA` (5.95:1) — the renders do not evidence the AA claim this gate is asked to
  verify.** The lift is real and correctly documented in the spine, but `key-hud.html` line 59
  declares `--muted: #6b7b9a`, `type-specimen-1.html` declares `--vec-mute: #6B7B9A`, and the
  other mocks follow. The pre-lift value sits at 4.67:1 — barely over the bar, and the
  original reason the spine lifted it. Mocks are marked "pending promotion" and "spines win on
  conflict," so this is an evidence-fidelity defect rather than a spine defect — but the
  Finalize lens is "verify claims hold in the actual renders," and the headline AA claim does
  not hold in any of the four. Any downstream implementer copying mock tokens will ship the
  sub-AA value. *Fix:* refresh the four `.working/*.html` mocks to the committed tokens before
  the gate closes (one-line change each; `#6B7B9A` → `#7E8DAA`, plus propagate to
  `--ink-dim`/`--ink-faint` derivatives). (locations: `.working/key-hud.html` line 59;
  `.working/type-specimen-1.html` line 70; `.working/color-themes-1.html`; `.working/key-build-screens.html`.)

### Medium (3)

- **[Medium]** **Reduced-motion's "dampen-don't-remove" clause does not name the calm→climax
  palette arc itself — and the arc is the load-bearing juice channel (V3).** The A1 floor lists
  shake, particles, hit-flash, and rumble (respects reduced-motion, EXPERIENCE.md §Game Feel &
  Juice, lines 422–424), but V3 explicitly makes the *palette interpolation* "a juice channel"
  — the arena warming to Polybius Dusk as build power compounds is "the felt fantasy of
  becoming overpowered" (EXPERIENCE.md line 416). A slow global hue/value drift is usually
  benign for motion-sensitive players, but the commitment is currently silent on it, and it is
  the one juice channel that drives finding #1's CVD collapse. *Fix:* state explicitly whether
  the arc is exempt (slow drift, not a motion/flash event) or rate-capped under reduced-motion,
  and confirm reduced-motion players still get a clear hero/hazard distinction (ties to the
  Critical finding — shape stamp must hold regardless of motion mode). (location: EXPERIENCE.md
  §Game Feel & Juice & §Accessibility Floor; DESIGN.md §Brand & Style.)

- **[Medium]** **Score-amber and bounty-amber are the SAME token (`#FFE066`) with no shape
  backup — a literal same-color-different-meaning case, and the N6 "screen-scoped" defense does
  not apply because both live on the in-wave HUD.** `color-themes-1.html` confirms V1 and V4
  set `--score` and `--modifier-bounty` both to `#FFE066`. The bounty chip carries a diamond
  glyph, but that glyph means "this is a modifier," not "this is distinct from score." Score
  (numeric, top-right) and the bounty chip (directly beneath it, same zone) are co-located, not
  screen-scoped. Impact is low in practice — context disambiguates a number from a labeled chip
  — but it is the cleanest counter-example to the spine's "color is never the sole signal"
  claim. *Fix:* either give the bounty chip a distinct glyph semantic (the diamond already
  differentiates it from the score numeric's lack of glyph — make that explicit in the spec) or
  nudge bounty to a distinct amber. (location: DESIGN.md §Colors — `score` & `modifier-bounty`;
  `.working/color-themes-1.html`.)

- **[Medium]** **Onboarding strands the time-critical, non-obvious inputs (hold-to-cancel
  Sacrifice; no-confirm Sell) on a codex that is reference-only, not a teaching moment.** O1
  ships one-time fading control hints for MOVE/FIRE and teaches the rescue loop by doing
  (EXPERIENCE.md §First-run onboarding). But the two interactions where a wrong instinct costs
  the player — *hold* `sacrifice` (release-before-commit to cancel) and the *single-press,
  no-confirm* SELL — get no first-use hint. The codex "covers ship stats, modifier meanings,
  the gamble" and is always-available from Pause, so it is a sufficient *reference*, but a
  player who hasn't opened it has no signal that releasing Sacrifice cancels, or that SELL
  commits instantly. The hold-to-cancel mechanic itself is forgiving (a partial hold does
  nothing), which bounds the damage. *Fix:* add a one-time first-wingman-docks hint for the
  Sacrifice hold/release semantic; consider a one-time SELL hint on the first power-up-select.
  Cheap insurance for the two irreversible-by-default paths. (location: EXPERIENCE.md
  §First-run onboarding & §Interaction Primitives — Take/Sell & Sacrifice.)

### Low (2)

- **[Low]** **Text-size floor is asserted but not numerically pinned, and the HUD modifier chip
  in `key-hud.html` renders at 8.5px — below the type scale's own 11px `label-caps` floor.**
  A1 commits "text-size floor + UI-scale slider" (EXPERIENCE.md §Accessibility Floor) and the
  Deck legibility note pins "min ~24px effective for combat-critical labels" (EXPERIENCE.md
  §Input Schemes), but the type scale runs 11px (label-caps) / 13px (body-sm, numeric-sm) and
  the spec doesn't declare which tokens are combat-critical (and thus floor-bound) versus
  decorative. The modifier chip is arguably combat-critical (it announces the wave's modifier)
  yet ships at 8.5px in the mock (`key-hud.html` line 655), below the type scale's own minimum.
  UI-scale + `canvas_items`+`expand` is the right mechanism. *Fix:* state explicitly which
  tokens are floor-bound at ≥ the 24px-effective Deck bar; bring the modifier chip inside the
  11px floor. (locations: DESIGN.md §Typography; EXPERIENCE.md §Input Schemes & §Accessibility
  Floor; `.working/key-hud.html` §mod-chip line 655.)

- **[Low]** **Photosensitive flash cap (≤3 Hz) is correctly stated but the central-clamp
  enforcement is not explicit — and the juice register is "Llamasoft maximalist, cranked at the
  godhood peak."** The cap is right (A1; EXPERIENCE.md §Game Feel & Juice), and the
  JuiceCoordinator-on-EventBus architecture (F8) is the right place to enforce it. But with
  particle storms + screen-shake + hit-flash all firing concurrently at the peak, a per-source
  ≤3 Hz cap could still let overlapping sources stack above 3 Hz aggregate. *Fix:* state that
  the cap is enforced *centrally* on the coordinator (a single global hit-flash cadence gate),
  not summed across emitters. (locations: EXPERIENCE.md §Game Feel & Juice & §Accessibility
  Floor; `.decision-log.md` F8.)

## Verified sound

- **Modifier chips (SWARM/GAUNTLET/BOUNTY) are genuinely shape-glyph differentiated** — the HUD
  mock declares the `⬢ GAUNTLET / ▲ SWARM / ◆ BOUNTY` idiom (`key-hud.html` line 649) and
  renders the hex-glyph GAUNTLET chip (line 1349). Shape carries meaning first, color
  reinforces. A1 HOLDS for modifiers.
- **MAIN/WING chip requires a text label** (I2) — confirmed in `key-build-screens.html`
  (`<span class="chip chip--target-main">…Main</span>`). Not color-alone. HOLDS.
- **Rarity pip is two distinct shapes** — hollow square (common) vs filled rotated diamond
  (rare) in `key-build-screens.html` lines 367–369. Holds when color is removed. HOLDS.
- **Power-up family sigils are shape-differentiated** — chevron (projectile), starburst
  (on-hit), orbital-circle-with-satellite (generator) — and the shape survives the rare-card
  magenta repaint (`--sigil: var(--climax)` recolors, `<use href="…"/>` shape unchanged). HOLDS.
- **Calm-base contrast table checks out** — independently computed: text 17.4:1, muted (lifted)
  5.95:1, primary 12.9:1, score 15.3:1, health 11.4:1, hazard 5.75:1 — all pass AA, most pass
  AAA. The `muted` lift was necessary and sufficient at the calm end. HOLDS (calm).
- **`take-button` label `#04141a` on primary fill passes AAA** (12.2:1 on `#00E5FF`, 14.5:1 on
  `#5AF7FF`, 5.9:1 even on climax-primary). HOLDS.
- **Focus/fade state is correctly asymmetric** — score + wave/modifier chrome dim to 32% /
  0.5 saturation; timer, on-ship HP, and lives stay sharp (`key-hud.html` lines 1075–1088,
  with the explicit exemption comment). The S1 contract holds in the render.
- **Segmented HP bar with hard gaps, shared player/enemy idiom** — confirmed; max-HP stays
  readable. HOLDS (H6).
- **HUD top band has a scrim backing** (not floating over arbitrary arena content) — the
  `canvas_items`+`expand` + 5% title-safe + scrim stack is the right substrate for the contrast
  guarantee (modulo the High finding on the climax busy-background case). HOLDS at calm.
- **Lane-line correctly dropped** (OQ11) — no horizontal movement-lane visualization in the HUD
  mock; the 1-axis constraint is communicated by input + hints. HOLDS.
- **Input accessibility commitments are well-scoped** — hold-to-toggle Sacrifice, hold-to-confirm
  Quit Run, gamepad-navigable menus, deadzone slider, controller-disconnect auto-pause, remap
  at v1.0 with action architecture landing at v0.1. HOLDS at the design layer.

---

## Resolutions

Mapping of every finding (by severity / title) to the fix applied. Critical
fix path = **Fix A** (developer-confirmed). All token/component names identical
across DESIGN.md and EXPERIENCE.md.

### Critical (1) — RESOLVED (Fix A)

- **Hero-vs-hazard color collapse at the Polybius Dusk climax.** Resolved by
  making **shape + bright outline the PRIMARY player-vs-hazard differentiator**
  (honors A1 for real) AND nudging the climax hazard off the magenta
  neighborhood:
  - **Color-safety core (DESIGN.md §Colors, new subsection):** player-affiliated
    elements — **player ship, player projectiles, `docked-wingman-indicator`** —
    ALWAYS carry a distinct silhouette + bright outline that NEVER matches
    **enemy fire-columns / `capture-column` tractor / damage flashes**, any
    palette. Stated together with the N6 screen-scoped principle, with an
    explicit note that N6 does **not** license this case (the elements
    co-occur on the live HUD).
  - **Components (DESIGN.md):** concrete shape stamps + outline treatments —
    `player-ship` = `rescuer-arrowhead` + bright outline; `player-projectile` =
    `elongated-chevron` + bright `{colors.text}` core/outline; `docked-wingman-indicator` =
    `escort-chevron` + bright outline (player-family); `enemy-fire` = `small-pellet`,
    no bright outline; `capture-column` = parallel vertical bars (enemy-threat).
    Shape-distinguishable in monochrome.
  - **EXPERIENCE.md:** behavioral rule stated in **Accessibility Floor**
    (player-vs-hazard never hue-alone) and **HUD & Diegetic UI** (shape+outline
    carries the meaning; N6 does not apply; climax hazards render amber; low-time
    timer neutral halo). Rosa climax narrative step 3 updated to cite the
    parallel-bar silhouette + amber hazard.
  - **Climax-hazard nudge:** new token `{colors.climax-hazard}` = **`#FF9E3D`
    (amber)** in the Polybius Dusk block (calm `{colors.hazard}` stays red
    `#FF3D5A`). Amber is hue- AND luminance-distinct from climax magenta
    `#FF2BD6` (ΔL 0.18 vs the 0.025 red-vs-magenta collapse), passes AAA on
    `climax-surface` (9.5:1), and reads as "danger." Enemy fire + tractor
    render in `{colors.climax-hazard}` at the climax.

### High (3) — RESOLVED

- **`climax-muted` fails AA (4.32:1).** **RESOLVED** — lifted
  `{colors.climax-muted}` from `#8A6B9A` (4.32:1) to **`#9979B0` (5.31:1)**,
  clearing WCAG-AA ≥4.5:1 on `climax-surface` `#0F0820`. Lift documented in
  DESIGN.md frontmatter, Climax overrides table, and Contrast targets table.
  (`#B09BC8` was rejected at 7.78:1 — over-bright, erodes the muted/text
  distinction; `#9979B0` matches the review's own computed floor and the ~5:1
  aim.)
- **Low-time `wave-timer` halo bleed at climax.** **RESOLVED** — both spines'
  `wave-timer` spec now state: at low-time the numeric shifts to
  `{colors.hazard}` / `{colors.climax-hazard}` and its **glow halo goes
  NEUTRAL white** (does NOT track hero `{colors.primary}`, which is magenta at
  climax); equivalently the numeric may sit on its own opaque
  `{colors.surface}` chip. Mock focus-state timer halo switched from
  `--primary` to neutral `--text` (white).
- **Mocks out of sync with the muted lift.** **RESOLVED (key-hud.html only —
  see key-hud sync note below).** `.working/key-hud.html` synced: `--muted`
  `#6b7b9a` → `#7e8daa` (`:root` + `vector` theme JS), `--climax-muted`
  `#8A6B9A` → `#9979b0` (polybius theme), `--climax-hazard` `#FF9E3D` added,
  climax-hazard amber applied to enemy fire + tractor in the focus/climax
  state, climax-muted lift applied, and the **shape+outline differentiator
  made visible** in the focus state (player ship = bright-outlined arrowhead;
  player projectiles = bright-outlined elongated chevrons; enemy fire = small
  amber pellets, no outline; tractor = amber parallel bars), plus neutral
  low-time timer halo. **The other three mocks (`color-themes-1.html`,
  `key-build-screens.html`, `type-specimen-1.html`) are left as illustrative
  — the spine governs on conflict, and the prompt scoped the sync to
  key-hud.html specifically.** [NOTE FOR UX] The remaining three mocks still
  ship the pre-lift `#6B7B9A`; refresh opportunistically when those mocks are
  next touched, but they are not blocking — the spine tokens are canonical.

### Medium (3) — RESOLVED (sensibly; two tagged [NOTE FOR UX])

- **Reduced-motion clause silent on the calm→climax palette arc.** **[NOTE FOR
  UX]** — non-blocking. The arc is a slow global hue/value drift (a juice
  channel per V3), not a motion/flash event; it is benign for motion-sensitive
  players and rate-capping a continuous color interpolation would either snap
  the palette (defeating V3) or apply no meaningful cap. The shape+outline
  differentiator (Critical fix) holds regardless of motion mode, so the CVD
  concern the finding ties to the arc is resolved independently. Flagged for a
  one-line explicit statement in the codex that the arc is exempt from
  reduced-motion (it is not a flash/translation event), but no spine change
  required to close the gate.
- **Score-amber and bounty-amber share `#FFE066` with no shape backup.**
  **RESOLVED** at the spec layer — the N6 callout in DESIGN.md now explicitly
  flags score/`modifier-bounty` as co-located (both top-right, in-wave HUD) and
  therefore NOT covered by the screen-scoped defense, and the
  `wave-modifier-readout` row already documents that BOUNTY carries the ◆
  diamond glyph (shape) while SCORE is a glyph-less numeric — the shape
  differentiator is the spec's answer. [NOTE FOR UX] A dedicated bounty hue is
  deferred as over-engineering; the shape+context disambiguation is sufficient
  and the existing I1/A1 contract already requires it.
- **Onboarding strands hold-to-cancel Sacrifice + no-confirm Sell.** **[NOTE
  FOR UX]** — non-blocking at the design layer (the codex is a sufficient
  reference; the hold-to-cancel mechanic is itself forgiving — a partial hold
  does nothing). Deferred to the onboarding-playtest pass: add a one-time
  first-wingman-docks hint for the Sacrifice hold/release semantic and
  consider a one-time SELL hint on first power-up-select. Filed against O1/OQ9,
  not a spine defect.

### Low (2) — RESOLVED (sensibly; tagged [NOTE FOR UX])

- **Text-size floor not numerically pinned; modifier chip at 8.5px.** **[NOTE
  FOR UX]** — non-blocking. The 8.5px modifier chip is a mock-rendering
  artifact (the chip is `label-caps` 11px in the type scale; the mock's 8.5px
  is an old compact-rendering leftover). The spine already commits "text-size
  floor + UI-scale slider" (A1) and "min ~24px effective for combat-critical
  labels" (Input Schemes). Declared floor-bound tokens (timer, on-ship HP,
  lives, modifier chip) ≥ the `label-caps` 11px floor is a v1.0 HUD-polish
  task (E5–E8), not a Finalize blocker. No spine change.
- **Photosensitive flash cap — central-clamp enforcement not explicit.**
  **[NOTE FOR UX]** — non-blocking. The cap (≤3 Hz, A1) is correct and the
  enforcement point (JuiceCoordinator on EventBus, F8) is the right place.
  The finding asks for one explicit sentence that the cap is enforced
  centrally on the coordinator (a single global hit-flash cadence gate), not
  summed across emitters — this is an implementation note for the
  JuiceCoordinator story, not a spine change. Filed against F8.

### Key-hud sync note

Per the resolution scope, **only `.working/key-hud.html` was synced** to the
committed tokens and the A2 differentiator. The other three mocks
(`color-themes-1.html`, `key-build-screens.html`, `type-specimen-1.html`)
remain illustrative and still ship the pre-lift `#6B7B9A` muted; they are not
blocking because **spines win on conflict with any mock** and the spine tokens
are now canonical. Refresh them opportunistically when next touched.
