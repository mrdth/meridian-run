# Validation Report — Meridian Run

- **DESIGN.md:** `_bmad-output/planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/DESIGN.md`
- **EXPERIENCE.md:** `_bmad-output/planning-artifacts/ux-designs/ux-meridian-run-2026-06-30/EXPERIENCE.md`
- **Run at:** 2026-07-01

## Overall verdict

The A1 accessibility floor is well-scoped and mostly holds at the calm (Vector Standard) end — the shape-glyph system for modifiers, rarity, family sigils, and the MAIN/WING chip genuinely carries meaning independent of hue, and `muted` was correctly lifted to clear AA. It breaks at the climax end, where the spine's signature juice mechanic (the calm→climax palette arc) collapses hero-neon and hazard-red to near-identical luminance for red-green CVD players — exactly at the Rosa wave-20 moment the whole design is built around — and the faction/projectile distinction that A1 explicitly promises "via shape + outline" is color-only in every render. Two further committed claims don't hold in the actual mocks (the `climax-muted` token fails AA; all four mocks ship the pre-lift muted value). Fixable at the design layer before code; none require re-architecting the arc.

All Critical and High findings are now **resolved** via developer-confirmed **Fix A**: shape + bright outline is the primary player-vs-hazard differentiator (player ship = bright-outlined `rescuer-arrowhead`; player projectiles = bright-outlined elongated chevrons; enemy fire = small pellets; `capture-column` = parallel vertical bars), the new `{colors.climax-hazard}` amber token (`#FF9E3D`, AAA on `climax-surface`) nudges climax hazards off the magenta neighborhood, `{colors.climax-muted}` was lifted from `#8A6B9A` (4.32:1) to `#9979B0` (5.31:1, clears AA), and the low-time `wave-timer` glow halo is now neutral white instead of tracking the climax-magenta `--primary`. The Medium and Low findings are closed at the spec layer or filed as non-blocking [NOTE FOR UX] against future onboarding/HUD-polish stories.

## Category verdicts

- Accessibility — **Thin (resolved)**. Arrived thin/critical at the climax end (hero/hazard CVD collapse, two AA claims failing in the mocks, magenta halo bleed on the low-time timer); calm end held across the board. All Critical/High findings closed via developer-confirmed Fix A; Medium/Low findings closed at the spec layer or deferred as non-blocking [NOTE FOR UX].

## Findings by severity

### Critical (1) — Resolved via Fix A

**Accessibility** — Hero-vs-hazard color collapse at the Polybius Dusk climax (DESIGN.md §Colors → Climax overrides & §Brand & Style; EXPERIENCE.md §Accessibility Floor, §Rosa at the wave-20 climax; `.working/key-hud.html` §BULLETS, §ENEMIES; `.working/color-themes-1.html`)

The calm→climax arc interpolates `{colors.primary}` cyan `#00E5FF` → magenta `#FF2BD6` while `{colors.hazard}` red `#FF3D5A` is an anchor hue held constant across the arc. At climax the pair is `#FF2BD6` vs `#FF3D5A` — adjacent red/magenta hues with ΔL = **0.025**, effectively the same luminance. For protanopes/deuteranopes (~8% of male players) the player ship, player projectiles, the docked-wingman family, the GAUNTLET modifier, and the capture-column/enemy-fire/damage threat family become confusable precisely when the screen is densest and the stakes highest. The renders confirm there is no shape/outline backup: every `.bullet` variant shares an identical 5×9px rounded shape — only `background` differs — and `color-themes-1.html` documents the hero ship and hazard both inherit `currentColor` with no shape stamp differentiating them. The calm→climax arc is the load-bearing juice fantasy (V3); it cannot also be the place A1 silently fails.

**Original ask:** give the player side a shape stamp the enemy/hazard side lacks and make it survive the repaint; or route the hero interpolation away from the red neighborhood.

**Resolved — Fix A (developer-confirmed):** Shape + bright outline is now the PRIMARY player-vs-hazard differentiator (honors A1 for real), AND the climax hazard is nudged off the magenta neighborhood.
- *Color-safety core (DESIGN.md §Colors, new subsection):* player-affiliated elements — player ship, player projectiles, `docked-wingman-indicator` — ALWAYS carry a distinct silhouette + bright outline that NEVER matches enemy fire-columns / `capture-column` tractor / damage flashes, in any palette. Stated alongside N6 with an explicit note that N6 does **not** license this case (the elements co-occur on the live HUD).
- *Components (DESIGN.md):* `player-ship` = `rescuer-arrowhead` + bright outline; `player-projectile` = elongated-chevron + bright `{colors.text}` core/outline; `docked-wingman-indicator` = `escort-chevron` + bright outline (player-family); `enemy-fire` = small-pellet, no bright outline; `capture-column` = parallel vertical bars (enemy-threat). Shape-distinguishable in monochrome.
- *EXPERIENCE.md:* behavioral rule stated in Accessibility Floor and HUD & Diegetic UI; Rosa climax narrative step 3 updated to cite the parallel-bar silhouette + amber hazard.
- *Climax-hazard nudge:* new token `{colors.climax-hazard}` = **`#FF9E3D` (amber)** in the Polybius Dusk block (calm `{colors.hazard}` stays red `#FF3D5A`). Amber is hue- AND luminance-distinct from climax magenta (ΔL 0.18 vs the 0.025 red-vs-magenta collapse), passes AAA on `climax-surface` (9.5:1), and reads as "danger." Enemy fire + tractor render in `{colors.climax-hazard}` at the climax.

### High (3) — Resolved

**Accessibility** — `climax-muted` `#8A6B9A` fails the WCAG-AA 4.5:1 bar on `climax-surface` — measured 4.32:1 (DESIGN.md frontmatter `climax-muted` + §Colors → Climax overrides)

The spine correctly documents that calm `muted` was lifted from `#6B7B9A` to clear WCAG-AA 4.5:1 (verified 5.95:1). But the Polybius Dusk terminus `climax-muted` re-breaks that bar at the climax surface `#0F0820` (4.32:1 by independent computation). Muted carries modifier-chip labels, empty HP-pip outlines, `build-summary-rail` empty slots, the codex body, and the `lives-display` lost-pip stroke — and the build screens render under the warm climax surface. The arc lifts calm muted and then re-fails it at climax.

**Original ask:** hold `muted` constant across the arc, or pin a climax terminus that clears 4.5:1 on `#0F0820`.

**Resolved:** Lifted `{colors.climax-muted}` from `#8A6B9A` (4.32:1) to **`#9979B0` (5.31:1)**, clearing WCAG-AA ≥4.5:1 on `climax-surface` `#0F0820`. Documented in DESIGN.md frontmatter, Climax overrides table, and Contrast targets table. (`#B09BC8` rejected at 7.78:1 — over-bright, erodes the muted/text distinction.)

---

**Accessibility** — Low-time `wave-timer` contrast is marginal at the climax, and the "stays sharp" commitment can compound it (DESIGN.md §`wave-timer`; EXPERIENCE.md §`wave-timer`, §HUD & Diegetic UI; `.working/key-hud.html` §topband, §focus timer)

At low-time the timer numeric shifts `{colors.text}` → `{colors.hazard}` `#FF3D5A`. On the climax surface that is **5.64:1** — passes AA for normal text but fails AAA, and is the worst case for the most-attended read at the highest-stakes moment. Two aggravators: (1) the HUD top-band backing is a translucent scrim, not an opaque plate, so effective contrast over a busy Polybius-Dusk particle storm dips below the measured value; (2) the focus-state timer text-shadow stays `var(--primary)` — at climax that is magenta, so a magenta halo bleeds into a red numeric over a magenta-red arena.

**Original ask:** give the low-time timer a guaranteed-dark backing, and recolor the low-time glow halo to track the numeric state (hazard-tinted, not primary-tinted).

**Resolved:** Both spines' `wave-timer` spec now state: at low-time the numeric shifts to `{colors.hazard}` / `{colors.climax-hazard}` and its **glow halo goes NEUTRAL white** (does NOT track hero `{colors.primary}`, which is magenta at climax); equivalently the numeric may sit on its own opaque `{colors.surface}` chip. Mock focus-state timer halo switched from `--primary` to neutral `--text` (white).

---

**Accessibility** — All four mocks ship the pre-lift muted value `#6B7B9A` (4.67:1), not the committed `#7E8DAA` (5.95:1) — the renders do not evidence the AA claim this gate is asked to verify (`.working/key-hud.html`; `.working/type-specimen-1.html`; `.working/color-themes-1.html`; `.working/key-build-screens.html`)

The lift is real and correctly documented in the spine, but every mock declares the pre-lift value. The pre-lift value sits at 4.67:1 — barely over the bar, and the original reason the spine lifted it. Mocks are marked "pending promotion" and "spines win on conflict," so this is an evidence-fidelity defect rather than a spine defect — but the Finalize lens is "verify claims hold in the actual renders," and the headline AA claim does not hold in any of the four. Any downstream implementer copying mock tokens will ship the sub-AA value.

**Original ask:** refresh the four `.working/*.html` mocks to the committed tokens before the gate closes.

**Resolved (key-hud.html only — scoped):** `.working/key-hud.html` synced: `--muted` `#6b7b9a` → `#7e8daa` (`:root` + vector theme JS), `--climax-muted` `#8A6B9A` → `#9979b0` (polybius theme), `--climax-hazard` `#FF9E3D` added, climax-hazard amber applied to enemy fire + tractor in the focus/climax state, climax-muted lift applied, shape+outline differentiator made visible in the focus state, plus neutral low-time timer halo. **The other three mocks remain illustrative** — the spine governs on conflict and the prompt scoped the sync to `key-hud.html` specifically. *[NOTE FOR UX]* The remaining three mocks still ship the pre-lift `#6B7B9A`; refresh opportunistically when next touched. Not blocking — spine tokens are canonical.

### Medium (3) — Resolved (two tagged [NOTE FOR UX])

**Accessibility** — Reduced-motion's "dampen-don't-remove" clause does not name the calm→climax palette arc itself — and the arc is the load-bearing juice channel (V3) (EXPERIENCE.md §Game Feel & Juice, §Accessibility Floor; DESIGN.md §Brand & Style)

The A1 floor lists shake, particles, hit-flash, and rumble (respects reduced-motion), but V3 explicitly makes the palette interpolation "a juice channel." A slow global hue/value drift is usually benign for motion-sensitive players, but the commitment is currently silent on it, and it is the one juice channel that drives the Critical finding's CVD collapse.

**Resolved [NOTE FOR UX] — non-blocking:** The arc is a slow global hue/value drift (a juice channel per V3), not a motion/flash event; it is benign for motion-sensitive players and rate-capping a continuous color interpolation would either snap the palette (defeating V3) or apply no meaningful cap. The shape+outline differentiator (Critical fix) holds regardless of motion mode, so the CVD concern the finding ties to the arc is resolved independently. Flagged for a one-line explicit statement in the codex that the arc is exempt from reduced-motion (it is not a flash/translation event), but no spine change required to close the gate.

---

**Accessibility** — Score-amber and bounty-amber are the SAME token (`#FFE066`) with no shape backup — a literal same-color-different-meaning case, and the N6 "screen-scoped" defense does not apply because both live on the in-wave HUD (DESIGN.md §Colors — `score` & `modifier-bounty`; `.working/color-themes-1.html`)

`color-themes-1.html` confirms V1 and V4 set `--score` and `--modifier-bounty` both to `#FFE066`. Score (numeric, top-right) and the bounty chip (directly beneath it, same zone) are co-located, not screen-scoped. Impact is low in practice — context disambiguates a number from a labeled chip — but it is the cleanest counter-example to the spine's "color is never the sole signal" claim.

**Resolved [NOTE FOR UX]:** Resolved at the spec layer — the N6 callout in DESIGN.md now explicitly flags score/`modifier-bounty` as co-located and therefore NOT covered by the screen-scoped defense, and the `wave-modifier-readout` row documents that BOUNTY carries the ◆ diamond glyph (shape) while SCORE is a glyph-less numeric — the shape differentiator is the spec's answer. *[NOTE FOR UX]* A dedicated bounty hue is deferred as over-engineering; the shape+context disambiguation is sufficient and the existing I1/A1 contract already requires it.

---

**Accessibility** — Onboarding strands the time-critical, non-obvious inputs (hold-to-cancel Sacrifice; no-confirm Sell) on a codex that is reference-only, not a teaching moment (EXPERIENCE.md §First-run onboarding, §Interaction Primitives — Take/Sell & Sacrifice)

O1 ships one-time fading control hints for MOVE/FIRE and teaches the rescue loop by doing. But the two interactions where a wrong instinct costs the player — hold `sacrifice` (release-before-commit to cancel) and the single-press, no-confirm SELL — get no first-use hint. The codex is a sufficient reference, but a player who hasn't opened it has no signal that releasing Sacrifice cancels, or that SELL commits instantly. The hold-to-cancel mechanic itself is forgiving (a partial hold does nothing), which bounds the damage.

**Resolved [NOTE FOR UX] — non-blocking:** Non-blocking at the design layer (the codex is a sufficient reference; the hold-to-cancel mechanic is itself forgiving — a partial hold does nothing). Deferred to the onboarding-playtest pass: add a one-time first-wingman-docks hint for the Sacrifice hold/release semantic and consider a one-time SELL hint on first power-up-select. Filed against O1/OQ9, not a spine defect.

### Low (2) — Resolved [NOTE FOR UX]

**Accessibility** — Text-size floor is asserted but not numerically pinned, and the HUD modifier chip in `key-hud.html` renders at 8.5px — below the type scale's own 11px `label-caps` floor (DESIGN.md §Typography; EXPERIENCE.md §Input Schemes, §Accessibility Floor; `.working/key-hud.html` §mod-chip)

A1 commits "text-size floor + UI-scale slider" and the Deck legibility note pins "min ~24px effective for combat-critical labels," but the type scale runs 11px (`label-caps`) / 13px (`body-sm`, `numeric-sm`) and the spec doesn't declare which tokens are combat-critical (and thus floor-bound) versus decorative. The modifier chip is arguably combat-critical yet ships at 8.5px in the mock, below the type scale's own minimum.

**Resolved [NOTE FOR UX] — non-blocking:** The 8.5px modifier chip is a mock-rendering artifact (the chip is `label-caps` 11px in the type scale; the mock's 8.5px is an old compact-rendering leftover). The spine already commits "text-size floor + UI-scale slider" (A1) and "min ~24px effective for combat-critical labels" (Input Schemes). Declared floor-bound tokens (timer, on-ship HP, lives, modifier chip) ≥ the `label-caps` 11px floor is a v1.0 HUD-polish task (E5–E8), not a Finalize blocker. No spine change.

---

**Accessibility** — Photosensitive flash cap (≤3 Hz) is correctly stated but the central-clamp enforcement is not explicit — and the juice register is "Llamasoft maximalist, cranked at the godhood peak" (EXPERIENCE.md §Game Feel & Juice, §Accessibility Floor; `.decision-log.md` F8)

The cap is right (A1) and the JuiceCoordinator-on-EventBus architecture (F8) is the right place to enforce it. But with particle storms + screen-shake + hit-flash all firing concurrently at the peak, a per-source ≤3 Hz cap could still let overlapping sources stack above 3 Hz aggregate.

**Resolved [NOTE FOR UX] — non-blocking:** The cap (≤3 Hz, A1) is correct and the enforcement point (JuiceCoordinator on EventBus, F8) is the right place. The finding asks for one explicit sentence that the cap is enforced centrally on the coordinator (a single global hit-flash cadence gate), not summed across emitters — this is an implementation note for the JuiceCoordinator story, not a spine change. Filed against F8.

## Reviewer files

- `review-accessibility.md`
