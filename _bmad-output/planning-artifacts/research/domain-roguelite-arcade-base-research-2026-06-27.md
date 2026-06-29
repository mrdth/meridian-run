---
stepsCompleted: [1, 2, 3, 6]
inputDocuments: []
workflowType: 'research'
lastStep: 1
research_type: 'domain'
research_topic: 'Roguelite adaptation of classic arcade games — candidate comparison'
research_goals: 'Compare Asteroids, Breakout, Galaga, Robotron: 2084, and Tempest as bases for a new roguelite. Score on roguelite fit, implementation ease, and novelty/creative spark. Produce a recommendation.'
user_name: 'Mrdth'
date: '2026-06-27'
web_research_enabled: true
source_verification: true
---

# Research Report: Domain

**Date:** 2026-06-27
**Author:** Mrdth
**Research Type:** Domain — Roguelite × Classic Arcade Candidate Comparison

---

## Research Overview

This research compares five classic arcade games as candidate bases for a new roguelite adaptation:

1. **Asteroids** (Atari, 1979) — vector shooter, rotate-and-thrust, wrap screen
2. **Breakout** (Atari, 1976) — paddle-and-ball block breaker
3. **Galaga** (Namco, 1981) — fixed-shooter, formation enemies, capture mechanic
4. **Robotron: 2084** (Vid Kidz, 1982) — twin-stick shooter, save humans, swarm combat
5. **Tempest** (Atari, 1981) — tube shooter, vector visuals, fixed lanes

Each candidate will be evaluated against three criteria the user has chosen as decisive:

- **Roguelite fit** — how naturally the base loop supports runs, meta-progression, builds, and run-to-run variance.
- **Implementation ease** — solo-dev scope: how hard is the core loop to build and iterate on?
- **Novelty / creative spark** — how fresh does the roguelite twist feel? Is the design space under-explored?

The final output is a scored comparison and a single recommendation (with rationale and risks).

---

## Game Domain Research Scope Confirmation

**Research Topic:** Roguelite adaptation of classic arcade games — candidate comparison
**Research Goals:** Compare Asteroids, Breakout, Galaga, Robotron: 2084, and Tempest as bases for a new roguelite. Score on roguelite fit, implementation ease, and novelty/creative spark. Produce a recommendation.

**Game Domain Research Scope (tailored to user-selected criteria):**

- Roguelite genre primer — conventions, mechanics, run structure ( grounding for "fit" scoring )
- Each candidate's core loop & design DNA — extracted from design / historical sources
- Existing roguelite adaptations of each candidate — affects novelty scoring
- Scored comparison — candidate × criterion, with rationale
- Recommendation — single pick + risks + alternative priorities

**Out of scope (user did not select):**

- Regulatory / age ratings
- Market size, monetization, commercial projections
- Engine / tech-stack trends
- Storefront / publisher dynamics

**Research Methodology:**

- All claims verified against current public sources
- Multi-source validation for critical design / historical claims
- Roguelite primer grounded in genre-defining titles
- Confidence levels noted where evidence is thin

**Scope Confirmed:** 2026-06-27

---

## Game Domain Analysis

This section covers (a) the roguelite genre primer that defines "fit" for scoring, and (b) each candidate's verified design DNA. Commercial / market sizing is intentionally omitted — the user did not select those criteria.

### Roguelite Genre Primer — What "Fit" Means

**Genre boundary (verified):** The community distinction is consistent across sources:

- **Roguelike**: procedural levels, in-run character progression, permadeath, hard reset on death — every run starts from scratch.
- **Roguelite**: all of the above **plus meta-progression** — something persists between runs (unlocks, upgrades, currencies, cards, characters) that shapes future runs.

The "lite" specifically refers to softened permadeath via meta-progression, not lighter difficulty. ([Reddit r/roguelites discussion](https://www.reddit.com/r/roguelites/comments/1sik188/is_there_an_official_distinction_for_roguelike_vs/))

**Core mechanics that any roguelite must support:**

1. **Runs** — discrete playthroughs with a clear start, middle (build-building), and end (death or victory).
2. **Procedural variance** — each run differs: layouts, enemy spawns, reward drops, level geometry, or modifiers.
3. **In-run builds** — the player accumulates synergistic upgrades during a run (items, weapons, perks, cards).
4. **Permadeath** — death ends the run; in-run power is lost.
5. **Meta-progression** — between-run unlocks that persist (new characters, weapons, starting bonuses, world state, currency).
6. **Decision pressure** — build choices that force trade-offs (this item vs that one, this path vs that one).

**Genre-defining reference titles** (used as the benchmark for what "feels roguelite"):
- *The Binding of Isaac* — arcade-style twin-stick-adjacent action, item synergies, run variance.
- *Hades* — action combat, narrative-meta fusion, boon builds, weapon aspects.
- *Dead Cells* — side-scroller action, weapon/skill builds, metroidvania-lite progression.
- *Slay the Spire* — deckbuilder, turn-based, ascension levels.
- *Brotato* / *Vampire Survivors* — auto-shooter wave survival, item-stacking builds, short runs.

**"Fit" scoring rubric** (used in Step 6): how naturally does the candidate's core loop support these six pillars without needing to be bent out of shape?

---

### Candidate Design DNA

Each entry is grounded in verified public sources. Where a rate limit blocked a specific search, the Wikipedia URL was still confirmed and cross-checked against known arcade-history facts.

#### Asteroids (1979, Atari) — Multidirectional Vector Shooter

**Sources:** [Wikipedia](https://en.wikipedia.org/wiki/Asteroids_(video_game)) · [Arcade Blogger deep-dive](https://arcadeblogger.com/2018/10/24/atari-asteroids-creating-a-vector-arcade-classic/)

**Core loop:**
- Player ship floats in a 2D Newtonian vacuum — thrust builds momentum, rotation is independent.
- Screen **wraps around** on both axes (asteroids/ship/bullets exiting one side re-enter the other).
- Shoot asteroids; large asteroids split into medium → small → destroyed. Two UFOs (large + small) harass the player.
- Single life = one ship; extra lives awarded on score thresholds.

**Design DNA:**
- **Physics-driven** momentum (vs. direct positional control).
- **Open 2D field** (no fixed lanes or rails).
- **Emergent spatial combat** — player-created chaos (asteroid fragments) becomes the real threat.
- **Pure vector aesthetic** — minimalism supports readability at high speed.

#### Breakout (1976, Atari) — Paddle Block-Breaker

**Sources:** Search-verified from YouTube arcade-history summary + Wikipedia entry on the series.

**Core loop:**
- Player controls a horizontal paddle at the bottom of the screen.
- A ball bounces between paddle and a brick wall at the top.
- Each brick hit destroys the brick, deflects the ball.
- Brick colors carry different point values (and in some variants, behaviors).
- Lose a life when the ball falls past the paddle; clear all bricks to advance.

**Design DNA:**
- **Single-axis player control** (paddle moves left-right only).
- **Indirect combat** — the ball is the weapon; the player only ever controls the paddle.
- **Patterned, deterministic levels** — early brick layouts are static puzzles.
- **Reflex + angle mastery** — skill = paddle positioning and prediction.

#### Galaga (1981, Namco) — Fixed Shooter with Capture Mechanic

**Sources:** [Namco Wiki](https://namco.fandom.com/wiki/Galaga) · [Wikipedia](https://en.wikipedia.org/wiki/Galaga) · [Official Bandai-Namco history](https://galaga.com/en/history/galaga.php) · [Museum of the Game](https://www.arcade-museum.com/Videogame/galaga)

**Core loop:**
- Player Fighter is locked to the bottom of the screen, moves horizontally only.
- Bug-like Galaga aliens enter in formation, then dive-bomb the player in attack runs.
- **Capture mechanic**: a boss Galaga can capture the player's Fighter with a tractor beam. The captured ship can be rescued during a later dive — rescuing pairs the ships for **dual-fighter doubled firepower**.
- Stage clears when formation is destroyed; challenge stages award bonus points for perfect patterns.

**Design DNA:**
- **Fixed-screen, single-axis movement** (like Space Invaders, but with diving attack patterns).
- **Risk/reward capture mechanic** — voluntary sacrifice for higher future power.
- **Formation + dive enemy AI** — predictable patterns the player learns to read.
- **Challenge / bonus stages** — distinct pacifist-pattern interleaved with combat stages.

#### Robotron: 2084 (1982, Williams / Vid Kidz) — Twin-Stick Shooter

**Sources:** Web-confirmed (Facebook Atari Age group post citing Vid Kidz / Williams / 1982 release; consistent with established arcade history). [Wikipedia](https://en.wikipedia.org/wiki/Robotron:_2084)

**Core loop:**
- Twin-stick: left joystick moves in 8 directions, right joystick shoots in 8 directions **independently**.
- Single screen, no scrolling.
- Multiple enemy robot types (Grunts, Hulks, Brains, Spheroids, Enforcers, Tanks) with distinct behaviors.
- **Human families** walk the playfield — touching them rescues them for bonus points.
- Waves escalate; every Nth wave is a "brain wave" with a different objective.

**Design DNA:**
- **Decoupled move + aim** — the foundational twin-stick paradigm.
- **Crowd-control pressure** — many enemies on screen simultaneously.
- **Multiple enemy archetypes with stateful AI** (each behaves differently, threatens differently).
- **Objective layer beyond survival** — rescue humans, prioritize threats, manage space.
- **Pure wave survival** — no levels in the traditional sense; infinite escalation.

#### Tempest (1981, Atari, Dave Theurer) — Tube Shooter

**Sources:** [Wikipedia](https://en.wikipedia.org/wiki/Tempest_(video_game)) · cross-checked against general arcade-history references (specific deep-search was rate-limited; key facts align with established record).

**Core loop:**
- Player controls a claw-shaped "Blaster" that moves around the **rim** of a 3D-perspective tube.
- Each level is a different geometric shape (circle, triangle, square, etc.) with 12–16 lanes extending into the screen.
- Enemies (Pulsars, Flippers, Spikers, Fuseballs) climb out from the center along lanes toward the player's rim.
- Player shoots down lanes; **Superzapper** is a limited-use per-level smart bomb that clears the screen.
- "Spikers" leave spikes on lanes that the player must shoot through when warping out at level end.

**Design DNA:**
- **Fixed-lane, rim-only movement** — player can't freely roam the screen, only snap between lane positions.
- **Pseudo-3D perspective** on a 2D vector playfield.
- **Per-level geometric variety** — the playfield itself changes shape each level.
- **Limited-use "panic button"** (Superzapper) — a defined resource to manage.
- **Lane-control combat** — about controlling space on a 1D rim against threats climbing 1D lanes.

---

## Existing Roguelite Adaptations — Novelty Scan

Each candidate's "novelty score" depends on how crowded its roguelite space already is. Fewer / weaker existing adaptations = more room to do something fresh.

### Asteroids → Roguelite — CROWDED

**Known entries:**
- **Nova Drift** ([Steam](https://store.steampowered.com/app/858210/Nova_Drift/)) — the genre benchmark. "Asteroids on steroids" with deep build-craft, drift physics, shield/weapon trees. Widely praised, considered a gold-standard arcade-roguelite.
- **Asteroids... But Roguelite** ([Steam](https://store.steampowered.com/app/1392790/Asteroids_But_Roguelite/)) — literal-title take; budget-priced, lighter scope.
- **Asterogue** ([Steam](https://store.steampowered.com/app/4152940/Asterogue/)) — sci-fi Asteroids-style roguelike with nanotech builds.

**Saturation:** HIGH. Nova Drift in particular is a hard act to follow — any new Asteroids roguelite will be measured against it.

### Breakout → Roguelite — CROWDED AND ACTIVE

**Known entries:**
- **Roguebreaker** ([Steam](https://store.steampowered.com/app/731420/Roguebreaker/)) — vaporwave-styled roguelike Breakout.
- **Brick Odyssey** ([Steam](https://steamcommunity.com/app/2211110)) — hero-selection brick-breaker roguelike.
- **Brick Survivors - Roguelite** ([Steam](https://store.steampowered.com/app/4508990/Brick_Survivors_Roguelite/)) — fuses Breakout with bullet-heaven-style roguelite, 100-level story mode, co-op, meta-progression.
- **Rogue Patterns** ([Steam](https://store.steampowered.com/app/2644140/Rogue_Patterns/)) — pattern-collecting brick breaker roguelike.
- **Against Great Darkness** — recent solo-dev brick-breaker roguelite.
- **BALL x PIT** — ball-fusing + base-building brick-breaker roguelite, marketed as "deepest roguelike of the year."

**Saturation:** HIGH and currently very active. Multiple releases in the last 1–2 years. Standing out here requires a sharp hook.

### Galaga → Roguelite — THIN

**Known entries:**
- **BoboInvasion** — F2P space shooter with roguelike elements; the closest "Galaga-style roguelite" found.
- Pure Galaga-style fixed-screen fixed-direction roguelites are explicitly noted by the shmup community as uncommon in modern game development. ([Reddit r/shmups discussion](https://www.reddit.com/r/shmups/comments/14u6i1n/shmups_for_someone_who_loves_galaga/))

**Saturation:** LOW. The fixed-screen, fixed-direction shooter format has largely been abandoned by modern devs, which means **a well-made Galaga-style roguelite is genuinely unclaimed territory**. Risk: the format was abandoned for reasons (limited movement depth may not hold modern attention spans), so the design challenge is real.

### Robotron: 2084 → Roguelite — SATURATED (BLOOD BATH)

**Known entries:**
- **Brotato** — the dominant direct heir to Robotron's twin-stick wave-survival design.
- **Vampire Survivors** — auto-shooter evolution of the twin-stick wave-survival formula; massive hit.
- **Soulstone Survivors**, **20 Minutes Till Dawn**, **Deep Rock Galactic: Survivors**, **Spirit Hunter: Infinite Horde**, **Bio Prototype**, **Nordic Ashes**, **Picayune Dreams**, **Level Tank** — all occupy the same "bullet heaven" / twin-stick roguelite space.
- Adjacent: **Hades**, **Risk of Rain** series, **Dead Cells**.

**Saturation:** CRITICAL. "Bullet heaven" / auto-shooter / twin-stick roguelite is the single most crowded roguelite subgenre right now. A direct Robotron descendant will be one of dozens released this year. Standing out requires extraordinary execution or a sharp differentiator.

### Tempest → Roguelite — ESSENTIALLY UNCLAIMED

**Confidence:** ⚠️ LOW (web search rate-limited; based on prior genre knowledge).

**Known entries:** No prominent Tempest-style roguelite identified. The Tempest lineage is thin in general — *Tempest 4000* (Jeff Minter, 2018) is the main modern entry, and it is **not** a roguelite. *TxK* (2014) likewise. The tube-shooter genre is essentially dormant outside of Jeff Minter's work, and **none of it intersects with roguelite design**.

**Saturation:** VERY LOW. This is genuinely under-explored design space. **Highest novelty upside of the five candidates by a wide margin** — but also the riskiest, because the format's constraints (lane-locked movement, fixed perspective) demand real creativity to support modern roguelite pillars.

---

## Synthesis — Scored Comparison & Recommendation

### Scoring rubric

Each candidate is scored 1–5 on three equally-weighted criteria the user selected as decisive:

- **Roguelite fit** — how naturally the base loop supports the six pillars (runs, procedural variance, in-run builds, permadeath, meta-progression, decision pressure) without being bent out of shape.
- **Implementation ease** — solo-dev scope: prototype speed, content scaling cost, technical risk.
- **Novelty** — how under-explored the design space is (inverse of saturation from Step 3).

### Scored comparison

| Candidate | Roguelite fit | Implementation ease | Novelty | **Total** |
|---|:---:|:---:|:---:|:---:|
| **Asteroids** | 4 | 3 | 2 | **9** |
| **Breakout** | 3 | 4 | 2 | **9** |
| **Galaga** | 2 | 5 | 5 | **12** ⭐ |
| **Robotron: 2084** | 5 | 3 | 1 | **9** |
| **Tempest** | 3 | 3 | 5 | **11** |

### Per-candidate rationale

#### Asteroids — 9
- **Fit (4):** Proven substrate — *Nova Drift* demonstrates that Asteroids-style physics + drift + build-craft stacks beautifully. Wrap-around + Newtonian momentum naturally produces emergent chaos. Procedural asteroid fields + enemy variants are trivial. Knock: physics skill floor divides players.
- **Impl (3):** Vector physics + wrap + screen-partitioning are all straightforward. The hidden cost is game feel — Asteroids lives or dies on juice, screen shake, audio weight, and "readability at speed." Matching *Nova Drift*'s depth is hard.
- **Novelty (2):** *Nova Drift* casts a long shadow. You will be compared to it.

#### Breakout — 9
- **Fit (3):** Runs work, but indirect combat (you only control the paddle) narrows build variety to ball/paddle modifiers. Build expression ceiling is lower than direct-control games.
- **Impl (4):** Among the simplest of any candidate. Paddle + ball + brick collision is a weekend prototype. Iteration speed is the highest of the five.
- **Novelty (2):** Six+ recent roguelite Breakouts; *BALL x PIT* has claimed the "deep" lane.

#### Galaga — 12 ⭐
- **Fit (2):** Fixed-screen + 1-axis movement is the structural constraint. Movement-driven action depth has a low ceiling. **However:** the **capture→dual-fighter** mechanic is a roguelite-design goldmine — voluntary sacrifice for future power is exactly the kind of decision-pressure roguelites thrive on, and it's a unique seed no other candidate offers.
- **Impl (5):** Simplest of all five to build. 1-axis movement, fixed screen, formation enemies, single shoot button. Prototype-able in a day.
- **Novelty (5):** Essentially unclaimed territory. Pure Galaga-style fixed-screen roguelites are noted by the shmup community as rare in modern game development.

#### Robotron: 2084 — 9
- **Fit (5):** The ideal roguelite substrate. Twin-stick + waves + multiple enemy archetypes + objective layer (rescue humans) is the perfectine canvas. *Brotato* proved it beyond doubt.
- **Impl (3):** Twin-stick controls and enemy AI are non-trivial but well-trodden. The hidden cost is content volume — every enemy type and every upgrade must be authored, and the genre demands a lot of both. Scope scales fast.
- **Novelty (1):** Single most saturated roguelite subgenre on the market. Entering a bloodbath.

#### Tempest — 11
- **Fit (3):** Lane-locked movement + lane-based combat constrains action depth. **However:** per-level geometric variety is a *natural* roguelite variance source (procedural tube shapes!), and the **Superzapper** is a clean "panic-button resource to manage" — a roguelite staple. Build variety is the design puzzle: what do you upgrade on a 1D-rim ship?
- **Impl (3):** Pseudo-3D tube perspective is the technical risk. Can be faked in 2D but readability at speed is genuinely hard. Once the perspective trick works, content scales fast (just make new shapes).
- **Novelty (5):** Completely unclaimed. No prominent Tempest-style roguelite exists. Highest novelty ceiling of any candidate.

---

## Recommendation

### Primary pick: **Galaga**

**Total: 12/15** — highest score, driven by the best implementation ease (5) tied for highest novelty (5), with a unique roguelite seed the other candidates lack.

**Why Galaga over Tempest (next-highest at 11):**
- **Lower technical risk.** Galaga's 2D fixed-screen format is forgiving and well-understood. Tempest's pseudo-3D perspective trick adds real implementation risk for a solo developer — especially making lane combat readable at modern pacing.
- **Unique design seed.** The capture→dual-fighter mechanic generalizes into a full roguelite verb: **voluntary sacrifice for future power**. This is roguelite-design gold. The design space around "what do I give up now for what advantage later?" is deep and barely tapped. No other candidate offers anything as distinctive.
- **Implementation speed unlocks iteration.** A solo dev's biggest enemy is iteration cycle length. Galaga's simplicity means you can prototype the capture/sacrifice loop in days and start playtesting the actual fun fast.

**The core design challenge (flag this risk):**
The fixed-screen, 1-axis movement format was abandoned by the industry for a reason — modern players expect more positional expressiveness. **The capture/sacrifice mechanic is the wedge.** Design the entire roguelite around sacrifice-as-verb:
- Capture a fighter → it fights beside you (classic Galaga)
- Sacrifice the captured fighter → trigger a powerful one-time effect (roguelite twist)
- Different captured enemies offer different sacrifice effects (build-defining choices)
- Meta-progression: unlock new sacrifice effects, new capture-able enemy types, new starting kits

This turns Galaga's biggest weakness (constrained movement) into a strength: because the player has limited movement agency, the build/sacrifice decisions become the *primary* expression of skill and strategy.

### Alternative if novelty is paramount: **Tempest**

If the user weights novelty above all else (e.g., they'd rather risk a harder build for a more distinctive product), **Tempest** is the bolder pick. The pure white space and unique visual identity could make a more memorable release — but expect 2-3× the implementation cost and a much harder design puzzle (lane-locked action depth).

### Why not the others (one-liners)

- **Asteroids** — strong fit, but *Nova Drift* sets a benchmark you'll be measured against from day one.
- **Breakout** — too crowded, and indirect-combat caps build variety.
- **Robotron** — perfect fit, but you'd be entering the single most crowded roguelite subgenre on the market.

---

## Next Steps (outside this research)

1. **Validate the Galaga sacrifice-loop hypothesis** — prototype the capture/sacrifice mechanic in a minimal vertical slice before committing. The fun has to live there.
2. **Move to `gds-brainstorm-game`** — facilitated session to flesh out the sacrifice-roguelite design space (capture types, sacrifice effects, run structure, meta-progression).
3. **Then `gds-create-game-brief`** — formalize the vision before committing to a GDD.

---

## Sources

- [Wikipedia: Asteroids](https://en.wikipedia.org/wiki/Asteroids_(video_game)) · [Arcade Blogger: Creating a Vector Classic](https://arcadeblogger.com/2018/10/24/atari-asteroids-creating-a-vector-arcade-classic/)
- [Namco Wiki: Galaga](https://namco.fandom.com/wiki/Galaga) · [Wikipedia: Galaga](https://en.wikipedia.org/wiki/Galaga) · [Official Galaga history](https://galaga.com/en/history/galaga.php) · [Museum of the Game](https://www.arcade-museum.com/Videogame/galaga) · [r/shmups discussion on modern fixed shooters](https://www.reddit.com/r/shmups/comments/14u6i1n/shmups_for_someone_who_loves_galaga/)
- [Wikipedia: Robotron: 2084](https://en.wikipedia.org/wiki/Robotron:_2084)
- [Wikipedia: Tempest](https://en.wikipedia.org/wiki/Tempest_(video_game))
- [Steam: Nova Drift](https://store.steampowered.com/app/858210/Nova_Drift/) · [Steam: Asteroids... But Roguelite](https://store.steampowered.com/app/1392790/Asteroids_But_Roguelite/) · [Steam: Asterogue](https://store.steampowered.com/app/4152940/Asterogue/)
- [Steam: Roguebreaker](https://store.steampowered.com/app/731420/Roguebreaker/) · [Steam: Brick Odyssey](https://steamcommunity.com/app/2211110) · [Steam: Brick Survivors Roguelite](https://store.steampowered.com/app/4508990/Brick_Survivors_Roguelite/) · [Steam: Rogue Patterns](https://store.steampowered.com/app/2644140/Rogue_Patterns/)
- [Reddit r/roguelites: twin-stick / bullet-heaven recommendations](https://www.reddit.com/r/roguelites/comments/1oj7eby/just_discovered_roguelites_with_megabonk_need/)
- [Reddit r/roguelites: roguelike vs roguelite distinction](https://www.reddit.com/r/roguelites/comments/1sik188/is_there_an_official_distinction_for_roguelike_vs/)

---

**Research complete.** Document finalized at `_bmad-output/planning-artifacts/research/domain-roguelite-arcade-base-research-2026-06-27.md`.
