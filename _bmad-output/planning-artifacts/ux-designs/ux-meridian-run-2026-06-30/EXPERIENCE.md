---
name: 'Meridian Run'
description: 'Experience spec for Meridian Run — information architecture, HUD & diegetic UI, input schemes, game feel, accessibility, and player journeys. Owns how it works. Visual specs live in DESIGN.md, cited here by {path.to.token}.'
status: final
updated: 2026-07-01
spine: EXPERIENCE.md
design_ref: DESIGN.md
inherits: 'Godot Control nodes + action-based Input Map. EXPERIENCE.md specifies behavioral delta; visual specs live in DESIGN.md via {path.to.token} cross-references.'
---

# EXPERIENCE.md — Meridian Run (2D fixed-screen roguelite shooter · Godot 4.6)

> Distilled from `.decision-log.md` (canonical). **Spines win on conflict
> with any mock.** Component names are identical to DESIGN.md → Components.
> Prose is operational, not decorative — editorial voice lives in DESIGN.md.

---

## Foundation

- **Form-factor (P1):** PC desktop primary, targeting **Windows + Linux**.
  Steam Deck is **supported but not optimized** — no testing access; design
  for desktop, keep handheld viable, do not gold-plate Deck. Gamepad glyphs
  rendered as **Xbox-layout** (Deck default).
- **Input (F5):** keyboard + gamepad via **named Godot Input Map actions**,
  each action bound to BOTH schemes: `move_left`, `move_right`, `fire`,
  `sacrifice`, `confirm`, `back`, `pause`. Full remap UI + deadzone slider is
  a **v1.0 story (E8)**, not launch-day-critical — but the action architecture
  lands at v0.1 so remap is possible later.
- **Engine / UI:** Godot 4.6, Compatibility renderer. UI = **`Control` nodes
  on a `CanvasLayer` separate from the world tree** (F3) — the HUD must never
  obscure the 1-axis play lane. Critical errors fail-safe to menu, never
  hard-crash (F9).
- **Visual identity:** DESIGN.md is the ref. Calm base is Vector Standard
  (`{colors.primary}`); the arena escalates to Polybius Dusk
  (`{colors.climax-primary}`) as build power compounds (V3).
- **Run persistence (F6):** **no resume between sessions** — quitting a run
  abandons it. Only meta (unlocks, feats, best stats, settings) saves to
  `user://`. Quit-run needs a player-facing warning (see Interaction
  Primitives).

---

## Information Architecture

Flat, fast, gamepad-first. Nothing is deeper than two levels from the HUD.
Pause/build replaces the view; modals never stack (F9).

**Nav flow:**

```
Title ─▶ Ship-Select ─▶ Run [in-wave HUD]
                          │
                          ├─ (wave clear) ─▶ Power-Up-Select (3 offers · take/sell)
                          │                     │
                          │                     └─▶ Shop [Rearm] (4 offers · currency)
                          │                            │
                          │                            └─▶ next Run wave
                          │
                          ├─ Pause ─▶ { Resume · Codex · Settings · Quit Run }
                          │
                          └─ (all ships lost) ─▶ Game-Over / Run-Summary ─▶ Meta / Title
```

- **Title** — New Run · Settings · Quit. First-run onboarding hints fire on
  New Run (O1).
- **Ship-Select** — pick ship + tier; surfaces the `build-summary-rail`
  empty (the dual-ladder you're starting).
- **Run [HUD]** — no navigation; always-on overlay during a wave. Info
  hierarchy below.
- **Between-wave** — Power-Up-Select (every wave clear, 3 offers, take or
  sell @ ~50%, F7) → optional Shop / Rearm (4 offers at currency cost, F7).
  Both overlay a `panel-scrim`-paused arena.
- **Pause** — Resume · Codex (help) · Settings · Quit Run. One button from
  anywhere.
- **Game-Over / Run-Summary** — run stats + best; new-unlock state if earned
  (see State Patterns). Single focused CTA back to Title or New Run.
- **Meta** — unlocks, feats, best stats (no meta-currency, no between-run
  shop, F6).

**HUD info hierarchy (H4 / H5):** the primary read is **on-ship HP**
(`hp-bar`), co-located with where Rosa is looking. Then, persistent and
peripheral: **lives (`lives-display`) > timer (`wave-timer`) > score
(`score-readout`) > wave + modifier (`wave-modifier-readout`)**. Build stack
is **not** in the in-wave HUD — it surfaces on ship-select + between-wave
build screens (`build-summary-rail`), in calm moments (S1). Tier is dropped
from the in-game HUD (player chose it pre-run). All HUD lives in the top band
— never over the lane (F3).

---

## Voice and Tone

Punchy, maximal, **Llamasoft register** (M1) — flavor over neutrality, spikey
over safe. Identity cue: the player is a rescuer, never an aggressor;
sacrifice language is punchy but not sadistic. Anchors (use verbatim where
labeled):

- Wave start: `WAVE 17 — HOLD THE LINE`.
- Sacrifice prompt: `BURN THE WINGMAN?`.
- Game-over: `THE MERIDIAN GOES DARK`.
- Power-up names are flavored: `TRIPLE BROADSIDE`, `WINGMAN PROTOCOL`,
  `MERIDIAN SURGE` — never "Triple Fire" / "Drone" / "Damage Up".
- Wave modifier chips read as the shape: `SWARM` / `GAUNTLET` / `BOUNTY`.
- Internal nickname "oh-shit button" for the sacrifice action stays
  **dev-internal**; the player only ever sees `BURN THE WINGMAN?`.

Game pillars (mirror verbatim in any player-facing copy that touches them,
N1): **P1 Godhood** — *"How overpowered can I become?"* · **P2 The Gamble** —
*"How far will I push my greed?"* · **P3 The Test** — *"How far can skill
carry it?"*. Endless phase is named **the Ascender phase** (motto: *"how far
can I push it"*).

---

## Component Patterns

Behavioral spec — one row per component. Visual anatomy / color / sizing
lives in DESIGN.md → Components. Names identical.

**HUD**

- **`lives-display`** — updates only on ship loss/gain; never animates the
  digit (it's a pip row, not a counting number). Stays sharp through
  focus/fade (S1) — the gamble hinges on Rosa knowing she's on her last ship.
- **`wave-timer`** — counts down from 60s (H3, survive-to-end; final duration
  TBD in playtesting). Shifts to `{colors.hazard}` at low-time (climax:
  `{colors.climax-hazard}` amber). **The low-time glow halo goes NEUTRAL
  white** — it does NOT track the hero `{colors.primary}`, which is magenta at
  climax and would bleed red-on-magenta over the hazard numeric; equivalently
  the numeric may sit on its own opaque `{colors.surface}` chip so the hazard
  number stays crisp over a busy climax particle storm. Stays sharp through
  focus/fade (S1, T1). Format `XXs` via `numeric-md` (mono, no jitter).
- **`score-readout`** — display-only, cumulative; fed by floating kill
  popups (G1). Dims during focus/fade (S1). Currency is **never** shown
  here (H2).
- **`wave-modifier-readout`** — wave number persistent beneath the score;
  the active modifier chip sits beside it. The chip **flashes once at wave
  start** to announce the modifier (**[ASSUMPTION]**, OQ9).
- **`hp-bar`** — primary read. Player HP is per-ship, base 3, **full heal
  each wave** (H1); ships are the run-economy resource (start 3, cap 5, run
  ends at 0). Same segmented idiom renders on multi-hit/damaged enemies (H6);
  absent on 1-hit grunts. **Boss / mini-boss waves render a prominent
  top-of-screen boss HP bar** (same segmented idiom, scaled up)
  **[ASSUMPTION]**, OQ9 — communicates the boss's phase/damage progress.
- **`build-summary-rail`** — **not in-wave.** Surfaces on ship-select +
  between-wave screens (calm moments, S1). Shows the dual-ladder (MAIN/WING)
  build stack so the player sees what a new card would add to.
- **`capture-column`** — the tractor telegraph (C3), an enemy-threat element.
  Locks to player X. Expands from a single vertical line to two glowing
  `{colors.hazard}` boundaries (climax: `{colors.climax-hazard}` amber) with a
  translucent hazard fill — a **fair-dodge** cue, never a weapon. Captured foes
  are *drawn in* (rescue idiom), never harmed. **Shape stamp: two parallel
  vertical bars** — distinct from the player family's arrowhead/chevron, so the
  tractor never reads as player output even at the climax magenta repaint (A2).
  Stays readable through focus/fade.
- **`docked-wingman-indicator`** — renders when a wingman is docked (C1).
  Offset to one side of the main ship at ~80% scale. On **sacrifice**, the
  player ship gains glow + modest enlarge (C2 — power = bigger + glowier;
  enlarge kept modest so the true hitbox stays readable, N5). A
  **sacrifice-burst timer ring** renders on the ship for the burst's duration
  (**[ASSUMPTION]**, OQ9).

**Build screens**

- **`power-up-card`** — 3 states baseline (default / focus / selected-or-rare)
  + a 4th `disabled` in the shop + the rare-climax repaint = **5 visual
  states** total (see State Patterns). Gamepad focus is independent of
  rarity. Data-driven from `.tres` (F7).
- **`take-button`** — primary action: TAKE on select, BUY on shop. One per
  card. Disabled (flat, dashed) when unaffordable in shop.
- **`sell-button`** — secondary, **select-only** (shop has no sell). Sells
  the offered card for ~50% value as currency. **Quick, low-friction** —
  single press, no confirm (**[ASSUMPTION]**, OQ9 — sell is reversible-ish:
  you can always take the next card).
- **`currency-readout`** — **shop-stage only** (H2). Wave score converts to
  currency at the shop; none earned or shown mid-wave.
- **`main-wing-chip`** — the dual-ladder target indicator (I2): MAIN feeds
  the primary weapon ladder, WING feeds the allied-rescue ladder. Text label
  required (not color-alone, A1).
- **`rarity-pip`** — COMMON (hollow square) vs RARE (filled diamond, full
  Polybius Dusk repaint of the card). Shape-coded (I1).
- **`synergy-tooltip`** — appears under the focused card only; one-line
  interaction hint describing how the card stacks with the current build.
  Pointer-events none.

**General**

- **`button`** — primary (confirm/advance) and secondary (back/cancel).
  Gamepad-confirmable; mouse hover = gamepad focus equivalent.
- **`panel-scrim`** — the depth-of-field layer under all between-wave build
  UI and pause menus. Pauses the arena; signals "calm moment" (S1 inverse:
  combat dims the HUD, here the build surfaces sharp).
- **`chip`** — base anatomy reused for modifier / target / build chips.
- **`menu-item`** — vertical-menu row, gamepad-navigable top-to-bottom,
  wraps at the ends. Right-aligned kbd hint.
- **`slider`** — settings: master/music/sfx volume, gamepad deadzone,
  UI-scale, reduced-motion. The deadzone slider's track runs
  `{colors.primary}` → `{colors.climax-primary}` as a quiet call-back to the
  arc.
- **`codex`** — pause help (O1). Reference for ship stats, modifier
  meanings, the gamble. Always available from Pause.
- **`toast`** — transient notification for feat/unlock discovery
  (**[ASSUMPTION]**, OQ9). Appears **between waves, never mid-wave** (would
  violate focus/fade, S1). Auto-dismisses.

---

## State Patterns

Per IA surface, the states the player can be in:

- **`power-up-card` (5 states):** `default` · `focus` (gamepad hover) ·
  `selected` / `rare` (rare repaint counts as the selected/rare state) ·
  `disabled` (shop unaffordable). The focused + rare states can co-occur
  (a focused rare card glows magenta with a focus ring).
- **In-wave HUD:** `standard` (full HUD, calm) · `focus-fade` (S1 climax —
  score + wave/modifier chrome dim to ~32% opacity / 0.5 saturation; timer,
  on-ship `hp-bar`, and `lives-display` **stay sharp**; fire-columns denser,
  damage vignette intensifies). Inverse applies between waves: the build
  surfaces sharp over a dimmed arena.
- **`docked-wingman-indicator`:** `absent` · `docked` (idle escort) ·
  `sacrifice-burst` (glow + modest enlarge + timer ring, C2).
- **`capture-column`:** `idle` (no captor present) · `telegraph` (boundaries
  + fill + sweep) · `capturing` (active pull).
- **Game-Over / Run-Summary:** `normal` (stats + best) · `new-unlock` (a
  `toast`-style banner inline on the summary calls out the newly unlocked
  feat/ship; normal summary presents after dismissal).
- **Pause overlay:** `closed` · `open` (panel-scrim up; arena paused; Resume
  is the default-focused `menu-item`).
- **Settings:** `navigating` (gamepad moves between `slider`s / `menu-item`s)
  · `adjusting` (a focused slider accepts left/right input).
- **Controller disconnect:** auto-pause, `Reconnect controller` prompt —
  mid-combat never punishes a dropped pad (A1).

---

## Interaction Primitives

- **Move** — `move_left` / `move_right` (1-axis only; no vertical). The
  1-axis constraint is communicated by **control hints + the input itself
  (O1), not a drawn lane-line** (OQ11 dropped).
- **Fire** — `fire` (vertical column; hold to fire).
- **Sacrifice** — `sacrifice`, **hold-to-toggle** (A1): hold to burn the
  docked wingman for a power burst (prompt `BURN THE WINGMAN?`). Releasing
  before the commit cancels.
- **Confirm / Back** — `confirm` (TAKE/BUY/Resume/default focus) /
  `back` (one level up / close scrim).
- **Pause** — `pause` (one button from anywhere; opens the Pause overlay).
- **Menu navigation** — gamepad stick / D-pad or keyboard; mouse hover =
  gamepad focus equivalent. Lists wrap top↔bottom.
- **Take / Sell** — TAKE is `confirm`; SELL is a dedicated secondary key
  (e.g. `S`) on the focused card. Sell is quick, no confirm. **[ASSUMPTION]**
  (OQ9).
- **Irreversible actions use hold-to-confirm (A1):**
  - **Sacrifice** — hold-to-toggle (above).
  - **Quit Run** — **hold-to-confirm**; quitting abandons the run with no
    resume (F6). Player-facing warning surfaces in the Pause menu before the
    hold (**[ASSUMPTION]**, OQ9).
  - **Sell** — explicitly **not** hold-to-confirm (low-stakes, reversible-ish).
- **Rumble / haptic** — on hit landed, hit taken, pickup, sacrifice burst
  (light/medium/heavy impact). Respects reduced-motion (dampened, not
  removed).

---

## Accessibility Floor

Indie-serious floor (A1), all of it shipping, none optional:

- **Colorblind-safe** — palette + **shape-glyph differentiation** for every
  hue-encoded concept (HP, hazard, build family, rarity, modifier). **The
  player-vs-hazard distinction never relies on hue alone (A2):** the player
  ship / player projectiles / `docked-wingman-indicator` ALWAYS carry a
  distinct silhouette + bright outline (`rescuer-arrowhead` /
  `elongated-chevron` / `escort-chevron`) that NEVER matches enemy fire
  (`small-pellet`) or the `capture-column` tractor (parallel bars), in calm OR
  climax palette. Shape+outline carries the meaning; color reinforces. This
  survives the climax magenta repaint and a full repaint to monochrome.
- **WCAG-AA contrast** — 4.5:1 on all menu/HUD text combos at BOTH arc ends;
  see DESIGN.md → Colors → Contrast targets. `{colors.muted}` `#7E8DAA`
  (5.95:1) and `{colors.climax-muted}` `#9979B0` (5.31:1, lifted from
  `#8A6B9A` @ 4.32:1) both clear the bar on their respective surfaces.
- **Photosensitive flash cap** — hit-flash / screen-flash ≤ **3 Hz**.
- **Reduced-motion = dampen-don't-remove** — ~70% scale on shake, particles,
  hit-flash; feedback preserved; **default-on capable**. Juice auto-disabled
  in menus (F8).
- **Text-size floor + UI-scale slider** — under `canvas_items`+`expand` (F4).
- **Full input remap + gamepad deadzone slider** — v1.0 (E8). Action
  architecture lands at v0.1 so it's possible.
- **Hold-to-toggle Sacrifice** — for limited-dexterity players (A1).
- **Combat-critical labels legible** at desktop and handheld (Steam Deck,
  7-inch) distance.

---

## Key Flows

### Rosa at the wave-20 climax (named protagonist, N5)

Rosa is a roguelite build-crafter on her deepest run. Wave 20. She has **one
ship left** — if she courts capture now, there is no life left to rescue
with, and the run ends.

1. The wave starts. The arena is in calm Vector Standard; HUD reads standard.
   `lives-display` shows 1 pip lit; `wave-timer` reads `60s`.
2. By mid-wave the field is dense. The HUD enters **focus-fade (S1)**: score
   + wave/modifier chrome dim; **timer, on-ship `hp-bar`, and
   `lives-display` stay sharp** — she always knows she's on her last ship,
   and how long she has to survive.
3. A captor locks a `capture-column` on her X. It telegraphs two
   `{colors.hazard}` boundaries (climax: `{colors.climax-hazard}` amber) + a
   translucent fill — a **fair-dodge** cue. Its **parallel-bar silhouette** is
   shape-distinct from her arrowhead ship, so she reads it as *threat to
   evade*, never her own output — even with hero magenta and hazard amber both
   on screen. She dodges sideways (1-axis).
4. Her `hp-bar` drops to 2/5 segments. The damage vignette tightens;
   fire-columns are dense. She glances at the timer — `23s`.
5. **Climax:** the arena has warmed toward Polybius Dusk as her build
   compounds (V3) — `{colors.primary}` is leaning magenta, the screen reads
   as a neon altar. She holds `sacrifice` — the docked wingman burns, her
   ship gains glow + a modest enlarge (C2), a sacrifice-burst timer ring
   renders on the ship (**[ASSUMPTION]**, OQ9). Fire widens. She survives
   the last 23 seconds.
6. **Wave clear.** The HUD un-fades; the `panel-scrim` drops; **Power-Up-Select**
   surfaces over a paused arena — a rare card repaints in
   `{colors.climax-primary}`, the climax beat made literal. The
   `build-summary-rail` shows what taking it would add to her MAIN/WING
   ladders.
7. **Failure path:** if she is captured on her last ship, the run ends — no
   life to rescue with. Screen goes to **Game-Over / Run-Summary**
   (`THE MERIDIAN GOES DARK`), run stats + best, single focused CTA. If a
   feat unlocked, the `new-unlock` state surfaces a `toast`-style banner
   inline on the summary (**[ASSUMPTION]**, OQ9).

### The core build loop (every wave clear, F7)

1. Wave clears → `panel-scrim` drops, arena pauses + dims, build UI surfaces
   sharp (S1 inverse).
2. **Power-Up-Select** — 3 cards, take-or-sell @ ~50%. Rosa navigates with
   gamepad; focused card shows `synergy-tooltip` ("Stacks with PIERCE — three
   columns, each punching clean through"). She presses `confirm` (TAKE) or
   `S` (SELL — quick, no confirm).
3. Optional **Shop (Rearm)** — 4 cards at currency cost. `currency-readout`
   shows her CHIPS (shop-stage only, H2). Unaffordable cards render
   `disabled`. She BUYS or `back`s out.
4. The chosen card drops into the `build-summary-rail` on the matching
   MAIN/WING ladder.
5. Next wave starts; the arena returns to live action; HUD re-enters standard.
6. **Failure path:** if she sells everything and takes nothing, her build
   stalls — later waves out-scale her. The gamble (P2) is that greed
   (selling for currency now) trades against power (taking the card now).
   No hard block; the run just gets harder.

### First-run onboarding (O1)

Lightweight hints + learn-by-doing. **No forced tutorial.**

1. Rosa (new player) hits New Run. One-time **fading control hints** appear:
   `A / D — MOVE`, `SPACE — FIRE`. They fade after a few seconds or on first
   use. **No drawn lane-line** (OQ11 dropped) — the 1-axis constraint is
   taught by the input itself.
2. The **early captor wave** teaches court-capture / rescue / sacrifice **by
   doing**: a captor locks a `capture-column`; if Rosa is captured she loses
   the ship, but an early wave gives her a wingman back via rescue — the
   rescue loop is felt, not lectured.
3. The **`codex`** (pause help) is always available from Pause: ship stats,
   modifier meanings, the gamble explained. Rosa checks it when she needs it,
   never because the game forced her to.
4. **Failure path:** if Rosa quits mid-run, Pause → **Quit Run**
   (hold-to-confirm, F6) abandons it; meta still saves. The warning surfaces
   before the hold so she doesn't lose the run by accident.

---

## HUD & Diegetic UI

The HUD is **non-diegetic** (D1) — screens and HUD float as arcade overlays,
not as in-world/diegetic elements. No ship-cockpit framing, no holographic
character-GUI. The one deliberate diegetic-ish beat is the
`capture-column` telegraph (C3): it lives in-world (on the play-field), locked
to the player's X, expanding from a single line to two glowing boundaries —
*the world tells Rosa where the danger is.* The HUD proper (lives, timer,
score, modifier) is overlay-only, top band, never over the lane (F3).

**HUD information hierarchy (H4):** on-ship `hp-bar` (primary, co-located with
focus) > `lives-display` > `wave-timer` > `score-readout` >
`wave-modifier-readout`. Tier absent (player chose it). Build absent (surfaces
between waves). Currency absent in-wave (H2).

**What fades (S1):** during intense combat, `score-readout` +
`wave-modifier-readout` chrome dim to ~32% / 0.5 saturation. **What stays
sharp:** `wave-timer`, on-ship `hp-bar`, and `lives-display` (lives matter
most — the gamble hinges on knowing you're on your last ship, N5). Full HUD
+ `build-summary-rail` resurface in the respawn window and between waves.

**Player-vs-hazard never relies on hue alone (A2).** On the live in-wave HUD
and play-field, the player family (ship, player projectiles,
`docked-wingman-indicator`) and the hazard family (enemy fire-columns,
`capture-column`, damage flashes) co-occur at the same moment — so the N6
screen-scoped defense does not apply, and the distinction is carried by
**shape + bright outline**, not color: arrowhead/chevron + bright outline on
the player side; pellets and parallel bars (no bright outline) on the hazard
side. Color reinforces; the read survives the climax magenta repaint and a
monochrome fallback. At the climax, hazards render `{colors.climax-hazard}`
amber (hue+luminance-distinct from climax magenta), and the low-time
`wave-timer` glow goes neutral white so the hazard numeric stays crisp.

---

## Input Schemes

- **Keyboard + gamepad, both first-class (F5).** Every named action has BOTH
  bindings via the Godot Input Map. The active scheme is auto-detected;
  on-screen glyphs (Xbox-layout for gamepad, P1) swap to match.
- **Menu navigation** is gamepad-first: stick/D-pad or A/D for horizontal
  card rows, up/down for vertical menus; `confirm` (A/Enter) advances,
  `back` (B/Esc) reverses. Mouse hover = gamepad focus equivalent — both
  drive the same focus state.
- **Remap + deadzone slider** — v1.0 (E8). Conflict detection; reset-to-default
  per scheme. The deadzone slider track runs `{colors.primary}` →
  `{colors.climax-primary}`.
- **Hold-to-toggle Sacrifice** — hold `sacrifice` to burn the wingman;
  release before commit to cancel (A1).
- **Steam Deck (P1)** — treated as gamepad; Xbox-layout glyphs; verify
  text legibility at 7-inch handheld size (min ~24px effective for
  combat-critical labels). Supported, **not optimized** — no testing access.

---

## Game Feel & Juice

**Llamasoft / Jeff Minter neon-vector maximalist juice** (G1): big floating
score numbers + SFX on enemy death, particle storms, screen-shake and
hit-flash cranked at the godhood peak. Must be **tameable by a reduced-motion
toggle** (A1).

- **On enemy kill:** floating score popup (`numeric-xl` `{colors.score}`,
  monospace), particle burst, light shake, SFX sting.
- **On hit taken:** hit-flash (≤3 Hz, A1), directional screen-shake, damage
  vignette in `{colors.hazard}`, controller rumble (medium).
- **On sacrifice burst:** glow + modest ship enlarge (C2), timer ring, heavy
  rumble, particle storm.
- **At godhood peak:** the calm→climax palette arc (V3) **is itself a juice
  channel** — the arena warming to Polybius Dusk as build power compounds is
  the felt fantasy of *becoming overpowered*. Rare card repaints at the build
  screen are the literal beat.
- **Juice auto-disabled in menus (F8)** — no shake / hit-flash / particles in
  Title / Pause / Settings / build screens. The `panel-scrim` is calm by
  design (S1).
- **Reduced-motion (A1):** ~70% scale on shake, particles, hit-flash;
  feedback preserved (numbers + audio + glow remain); **default-on capable**.
  Dampen, don't remove.

---

## Inspiration & Anti-patterns

**Touchstones:** Geometry Wars · Resogun · Nova Drift (clean neon-vector
clarity, V1); Tempest 2000 / TxK / Polybius — Llamasoft lineage (maximalist
juice register, G1/M1); Brotato / Vampire Survivors / Hades / Isaac (primary
audience: roguelite build-crafters who want juice, readability, clear
power-up feedback, progression UI over shmup-purist minimalism, N4).

**Rejects:**

- **Pixel art** — cost + readability; neon-vector only (V1).
- **Shmup-purist minimalism** — the audience wants progression UI and clear
  power-up feedback, not austerity (N4).
- **Runner / auto-scroll / side-scroll parallax mechanics** — despite the
  name, Meridian Run is a *Galaga*-lineage fixed-screen roguelite. "Run" =
  roguelite run. **No auto-scroll, no one-button runner input.**
- **Diegetic / cockpit HUD** — non-diegetic overlays only (D1).
- **Drawn lane-line** — dropped (OQ11); the 1-axis constraint is taught by
  input + hints.

---

## Responsive & Platform

- **Stretch mode `canvas_items` + aspect `expand`** at a fixed base
  resolution (F4). 16:9 base (1280×720 target). HUD must survive non-uniform
  scaling and hold a 60 FPS floor (project-context perf).
- **Windows + Linux desktop** — the shipping targets (F2). Single-player, no
  mobile/touch/VR.
- **Steam Deck (P1)** — supported, **not optimized**. Handheld legibility
  pass only; no gyro / touchpad-specific gold-plating. Gamepad scheme,
  Xbox-layout glyphs.
- **HUD anchor corners stay fixed** across all viewports for muscle memory
  (H5) — lives top-left, timer top-center, score top-right, HP above ship.
  The `{spacing.title-safe}` 5% margin keeps combat-critical HUD inside the
  safe area under non-uniform scaling.
- **Localization: English-only for v1.0** (**[ASSUMPTION]**, OQ9). The
  microcopy anchors (M1) are English-flavored by design; localization is a
  post-1.0 concern, not a launch blocker.
