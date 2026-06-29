---
title: 'Game Brainstorming Session'
date: '2026-06-28'
author: 'Mrdth'
version: '1.0'
stepsCompleted: [1, 2, 3, 4]
status: 'in-progress'
standalone_mode: true
seed_document: '_bmad-output/planning-artifacts/prototype-1-design-snapshot.md'
working_title: 'Meridian Run'
---

# Game Brainstorming Session

## Session Info

- **Date:** 2026-06-28
- **Facilitator:** Game Designer Agent
- **Participant:** Mrdth
- **Mode:** Standalone (no workflow tracking)
- **Seed:** Prototype v1 Design Snapshot — Galaga Rescue Roguelite

---

## Brainstorming Approach

**Selected Mode:** Guided — disciplined walk through techniques, sequenced toward *unexplored* space (not re-deriving the validated loop)

**Key Reframe (Mrdth):** The rescue/capture loop is Galaga's **twist**, not the game's **central hook**. Don't force the whole identity onto it. First job: discover the real central hook; rescue supports it.

**Guided Sequence (proposed):**
1. Player Fantasy Mining → surface the CENTRAL HOOK / player identity (the spine)
2. Core Loop + Twist Framing → position rescue correctly as a supporting twist
3. Failure State Design → is recoverable-life the hook, or a support?
4. Meta-Game Layer Design → what persists between runs (snapshot §6)
5. Run Structure → endless / fixed / victory state (§6)
6. Reward Schedule & Sacrifice Variety → 1-axis-respecting payouts (§6)
7. Roguelite Variance → procedural waves, modifier waves, in-run builds (§6)
8. Synthesis → organize 100+ ideas into themes for the brief phase

**Techniques Available:** Player Fantasy Mining, Core Loop Design, Failure State Design, Meta-Game Layer Design, Progression Curve Sculpting, Reward Schedule Architecture, Emergence Engineering, Ludonarrative Harmony, Constraint-Based Creativity, Genre Mashup, What If, Remix

**Focus Areas:** Central hook discovery · rescue-as-twist positioning · meta-progression · run structure · reward variety · roguelite variance

**Guardrails (established principles + new reframe):**
- Effects must respect 1-axis geometry (no radial/8-way)
- No screen-clearing bombs
- Player = underdog rescuer, not aggressor
- Rescue loop = twist, NOT the central hook

---

_Ideas will be captured below as we progress through the session._

---

## Ideas Generated (running capture)

> Count updated as ideas emerge through dialogue. Goal: 100+ before organization.

### [Hook-A] The Power-Escalation Fantasy *(CENTRAL HOOK CANDIDATE)*
**Source Technique:** Player Fantasy Mining
**Description:** The central hook is a Builder+Ascender fusion — *"How overpowered can I become, and how far can I push that power?"* Builds supply the means; wave-depth supplies the test; greed for more power risks the run.
**Potential:** STRONG — Mrdth's stated personal pull. Supplies the 50-hour compulsive core.
**Build-on:** Needs deep build space to survive (see concern below); rescue loop may BE the build engine.

### [Build-2] Multi-Source Build Engine
**Source Technique:** Player Fantasy Mining → Core Loop
**Description:** Power builds from MULTIPLE independent sources, not rescue alone. Base: survive a wave → power up. Bonus: survive the wave WITH a rescued ship still docked → extra power increase.
**Potential:** HIGH — prevents the rescue twist from accidentally re-becoming the hook; keeps the build engine robust.
**Emerging principle:** Builds must have multiple independent sources; rescue is ONE engine, not the only one.

### [Build-3] Dual Build Ladder (main ship + rescued ship)
**Source Technique:** Core Loop Design
**Description:** The main ship and the rescued ship have SEPARATE build tracks. Main = persistent core identity; rescued = a parallel, volatile track you invest in OR sacrifice.
**Potential:** HIGH novelty — creates investment tension (reliability vs. cashable risk).
**Build-on:** interacts with multi-rescue (multiple parallel ladders?); see resource-model fork below.

### [Build-4] Sacrifice as Buildable "Oh-Shit Button"
**Source Technique:** Core Loop Design
**Description:** Sacrificing the rescued ship is the emergency panic-button. Resulting buffs are CHOSEN/buildable (not fixed) — so the sacrifice payout is itself a build decision.
**Potential:** Reframes sacrifice from "fixed payout" to "spendable investment." Strong keep-vs-cash tension.

### [Build-5] Brotato-Style Turrets Break the 1-Axis (Earned)
**Source Technique:** Genre Mashup / Constraint Creativity
**Description:** Generators/turrets fire in non-vertical directions — a CONTROLLED, EARNED way to expand beyond the player's 1-axis fire coverage.
**Potential:** HIGH — raises the build-depth ceiling by adding a sanctioned coverage layer.
**Guardrail refinement:** PLAYER'S own ship fire stays strictly 1-axis; earned external generators may expand coverage, bounded (never screen-clearing).

### Emerging Principles (refining the snapshot's design principles)
- **Multi-source builds:** power must accrue from >1 independent engine (rescue is one, not the only). Guards against twist-as-hook drift.
- **1-axis applies to the player's OWN fire; earned generators/turrets may expand coverage** — refines principle #1 (effects respect 1-axis) with an "earned exception."
- Build-axis priority (Mrdth): **projectile behavior > on-hit modifiers > generators**.

### [Econ-8] Shared Currency Pool — Option A confirmed
**Source Technique:** Core Loop Design
**Description:** Single currency fuels both build ladders via a take/sell/shop system (option A from the resource fork). Survive a wave → earn currency. Rescue-and-survive → earn MORE (multiplier).
**Potential:** Confirms the shared-pool model; sets up the Brotato reward layer below.

### [Risk-6] ★ COURTING CAPTURE — Rescue as Chased Risk *(LOAD-BEARING)*
**Source Technique:** Player Fantasy Mining / Failure State Design
**Description:** The core risk/reward = play SAFE (avoid capture → smaller, safer rewards) vs COURT CAPTURE (deliberately allow capture to set up a rescue that pays out BIGGER: currency multiplier + better power-up odds). INVERTS classic Galaga, where capture is purely bad. Built-in balance: fail the rescue / lose the ship before wave-end = lost life, no payout (genuine push-your-luck).
**Potential:** CRITICAL — fuses twist + hook; you chase risk to fuel the godhood curve. May be the hook's actual engine. Candidate for the central 50-hour pull.
**Build-on:** This is the Gambler fantasy made load-bearing. Flagged for pressure-testing.

### [Econ-7] Brotato-Style Reward Architecture
**Source Technique:** Genre Mashup (Brotato reference)
**Description:** Wave clear → free power-ups (take OR sell for currency). Between-wave SHOP offers random power-ups for purchase. Rescued-ship survival = currency multiplier + biased odds toward rescue-oriented power-ups (in both free roll and shop).
**Potential:** HIGH — proven roguelite reward loop; clean vehicle for the shared pool.

### [Build-10] Power-Up Targeting (main vs rescued)
**Source Technique:** Core Loop Design
**Description:** Power-ups target EITHER the main ship OR the rescued ship (e.g., projectile modifier for the rescue, OR an increase to the sacrifice bonus). Rescue survival biases rolls toward rescued-ship power-ups.
**Potential:** Makes the dual ladder [Build-3] concrete and lootable.

### [Build-9] Sacrifice = Trade Life-Recovery, NOT Full Wipe (refines Build-4)
**Source Technique:** Core Loop Design
**Description:** Sacrificing the rescued ship trades its LIFE-RECOVERY (the HP you'd regain at wave-end) for a temporary power burst. NOT a total destruction of the rescued ship's accumulated build. *(Fork unresolved: cash-out-burst vs surgical-trade — see clarifying Q.)*
**Potential:** Reframes sacrifice from "fixed payout / total consume" to a more surgical, repeatable risk lever.

### [Build-9 RESOLVED] Permanent track, consumable ship (sacrifice model locked)
**Source Technique:** Core Loop Design *(user-resolved fork)*
**Description:**
- The rescued-ship **BUILD is a permanent run-long track** — investment is NEVER lost on sacrifice (losing mid-run progress = unfun; rejected).
- The **docked SHIP (a life)** is the consumable entity.
- **Sacrifice = oh-shit button:** spend the docked ship → temporary power burst that **scales with track investment** (modest early, grows). Forfeits the survival bonus + the life-regain.
- **Keep =** survive to wave-end → currency multiplier + upgrade-odds bonus + regain life; track keeps growing.
- **Anti-spam mechanism:** pure opportunity cost — every sacrifice skips the survival payout AND burns a potential life. No artificial cooldown needed.
**Tuning flag:** if the burst scales with the permanent track, the oh-shit button COMPOUNDS over a long run → mirror of the "too strong at start" concern: it could be too strong by LATE run. Needs a ceiling or HP-relative scaling. (Prototype base: 2×→3.75× for 10s — already high at start.)
**Synergy:** safe investment keeps courting-capture [Risk-6] attractive even when you sacrifice.

### ⚠️ PRESSURE-TEST: Courting Capture [Risk-6] — Pre-Mortem
**Vulnerability found — the risk-free farm:** For a skilled, healthy player the court-capture cycle is net-positive with controllable risk:
- Court capture (−1 HP, 1s invuln) → rescue (kill boss) → keep to wave-end (+1 HP regain) = **net 0 HP**.
- PLUS a wingman all wave (extra damage + 1-hit shield) PLUS currency multiplier + upgrade-odds bonus.
- The only downside (lost life) triggers on FAILURE — which a skilled player rarely does → gamble evaporates → **mandatory every wave** → dramatic capture devolves into a **farming chore**. Kills balance AND fantasy.
**Natural brake (good, already exists):** at low HP, safe-play dominates (fail = dead). So optimal play is health-contingent — but that's a binary (healthy→farm / fragile→safe), not yet a rich choice.
**Mitigation candidates (to co-design):**
- **Risk in the rescue itself** — harrowing, not routine: expose-yourself to free the ship / hostage-boss enrages / tight rescue window / counter-attack on rescue.
- **Risk in the payout** — rescued-ship quality is RANDOM; bonus is a gamble (gamble-on-a-gamble; can't farm a sure thing).
- **Lasting cost of capture** — beyond HP: boss empowers post-capture / temporary debuff / swarm escalation you must survive to cash out.
- **Payout scales with risk taken** — bigger bonus for rescuing at LOW HP / under pressure (reward the gamble, not the success).

### ✅ PRE-MORTEM RESOLVED — via original Galaga mechanics + scaling (Mrdth)
Original Galaga already carries the needed risk + lasting cost; the prototype had simplified them away. Adopting the originals + scaling:

**[Ref-11] Dive-timing rescue + formation-turn penalty**
Rescue ONLY succeeds by killing the boss DURING ITS DIVE. Kill in FORMATION → captured ship TURNS AGAINST the player (becomes an enemy; returns in a later wave). Adds timing risk + an ACTIVE failure penalty (not just "no rescue").

**[Risk-12] Lasting cost: dual-fighter LARGER HITBOX**
Rescued ship joins as dual-fighter: +firepower AND +hitbox. More power = bigger target = harder to dodge (brutal in 1-axis geometry — less room to weave between fire-columns). **Self-balancing anti-farm:** each rescue compounds your hitbox → can't endlessly court capture without becoming a huge target; natural ceiling where a giant hitbox can't dodge.

**[Risk-13] Captured-firepower empowers the boss *(reserve tuning lever)***
Captured ship's firepower added to the boss → your own build threatens you. **High-end self-scaling:** the stronger you are, the more dangerous your captured ship in the boss's grip → keeps courting-capture scary even for skilled/healthy players late-game. Held as an "if needed" escalation dial.

**[Scaling-14] Wave-scaled boss HP + hitbox**
Boss HP scales per wave (rescue needs more sustained fire during the dive window); hitbox scaling compounds dodge difficulty.

**★ KEY INSIGHT — the hitbox cost gives the hook TEETH:** the power-escalation fantasy becomes *"glass-cannon god — how far can skill carry my own greed?"* (not invincibility). Reward (firepower) and cost (hitbox) are COUPLED and COMPOUND = emergent self-balance. The Ascender half of [Hook-A] made visceral, from the original mechanic rather than a patch.

**Design deviation to confirm:** prototype used a FRAGILE 1-hit wingman; original uses a PERSISTENT dual-fighter with bigger hitbox. The bigger-hitbox version is what enables the anti-farm balance. Lean: adopt original (persistent dual-fighter + bigger hitbox), reconciled with permanent-track [Build-9] + sacrifice.

### [Build-15] Hybrid docked ship — persistent dual-fighter + 1-hit absorber (RESOLVED: combined original + prototype)
Docked ship = persistent dual-fighter (firepower + bigger hitbox) that ALSO absorbs the first hit (dies first, sparing player HP). Resolves the "double-loss" cruelty: a bigger hitbox won't cost 2 lives on one hit — the docked ship dies first, the player continues the wave.
**Cost of absorption:** lose firepower + hitbox shrinks back + forfeit the wave-end life-regain (ship gone). So the docked ship is simultaneously: **firepower source · hitbox cost · first-hit shield · potential-life**.
**Emergent micro-tension:** hold the docked ship for firepower+absorber, or proactively cash it via sacrifice [Build-9] before it gets absorbed? Holding too long risks losing the sacrifice window.
**Multi-rescue interaction (parked):** multiple docked ships = compounding hitbox + multiple absorbers — likely self-limiting (huge hitbox burns absorbers fast in dense fire), but needs a balance pass.

### Meta-Game Layer (guided step 4)

**[Meta-16] ~80/20 (or 90/10) variety/raw-power split**
Meta is overwhelmingly VARIETY/DEPTH. The small raw-power slice specifically COMPRESSES EARLY WAVES on future runs (skip already-solved content) — NOT raising the late-game ceiling. Preserves the hook; removes early-run tedium. (Hades-pattern: permanent boosts help clear *mastered* early content, not beat the frontier.)

**[Meta-17] Achievement/milestone-based unlock cadence**
Unlocks gated by FEATS (Brotato / Noobs Are Coming model: beat wave X, perform feat Y) — NOT per-rescue (per-rescue would over-unlock and dilute). Encourages mastery + varied play, not grind.

**[Meta-18] Meta-unlocks = new playable SHIP TYPES (the Fleet)**
Persistent unlocks are new ships added to the fleet. Each ship = a distinct playstyle / base property (variety, not raw power).

**[Meta-19] ★ Narrative: rescued ships "learn"/"hack" enemy tech while captured**
The rescue loop is INTELLIGENCE GATHERING. A ship captured by enemy type X "studied" X's tech → unlocking it grants capabilities themed on X. Justifies WHY rescues unlock new ship types; ties the enemy roster to unlockable ships. Ludonarrative gold — potentially signature. Reframes capture from "loss" to "espionage": your captured ship was a mole.

**SYNTHESIS (reconciles 17+18+19):** An unlock = a themed rescue-FEAT → unlocks the enemy-tech ship. E.g., "rescue a ship from a Bomber boss" (a specific, milestone-gated achievement) → unlocks the Bomber-tech ship. Cadence stays controlled (not every rescue); the narrative explains the new ship. Achievement-cadence + learned-tech flavor, unified into one system.

**[Meta-20] No meta-currency (deferred for simplicity)**
Decision: NO between-run currency or shop. Pure feat-based unlocks only. Avoids grind + bookkeeping; keeps meta clean and skill-driven.
*Implication (parked for run-structure):* with no shop, the 20% raw-power "compress early waves" boost [Meta-16] must be delivered another way — likely auto-applied, or as a "start at a later wave" convenience once mastery is proven. Revisit when we design run structure.

**[Meta-21] Large fleet — broad ship variety**
The fleet is intentionally LARGE (all example ships valid: Bullet Hose, Interceptor, Bulwark, Shield-Piercer, Heavy, Controller + more). Playstyle breadth is the point; serves the Builder hook.

**[Meta-22] ★★ Ship unlocks EXPAND the in-run power-up pool (cross-pollination)**
Unlocking a ship ALSO unlocks its SIGNATURE MECHANIC as a findable power-up available to ALL ships. → Hybrid builds (e.g. play Bulwark, find Shield-Piercer's armor-piercing ammo). The meta fleet DIRECTLY deepens the in-run build space — combinatorial growth is what sustains the 50-hour hook. **Each unlock = a new build component, not just a new ship.** This is "variety feeds the hook" made literal.

**[Meta-23] Two-tier power-up pool (standard + specialty)**
- **Standard pool** (fire-rate, shields, damage, move-speed...) — available to ALL ships from the start. Keeps the base game complete; ships differ in feel, not in access to basics.
- **Specialty pool** (armor-piercing, tractor-pull, blast-columns...) — gated behind fleet unlocks [Meta-22].
- A ship's signature mechanic = also a findable power-up. Play the ship (start with it) OR find its power-up on another ship (hybrid build).

**[Meta-24] Feat-based unlock design — progression + skill, grind as fallback**
Mix of three feat types:
- **Progression-gated** (Brotato "win with A → unlock B"; "reach wave X") — natural, low grind.
- **Skill-based** (hardest feats: no-hit a dive, rescue at 1 HP) — mastery, prestigious.
- **Grind/accumulation** (kill 50k grunts, rescue 50 total) — accessibility fallback so less-skilled players still progress.
*Principle:* favor skill/progression; allow grind as a safety net. Honors "variety + skill-driven" ethos.

**[Meta-25] Crown-jewel unlock tied to the core loop (Tractor-tech ship)**
The Tractor Boss prize-ship unlocks via a RESCUE feat — thematically perfect (mastered the rescue fantasy → earn the ship that learned from the captor itself). Lean: SKILL/progression-gated rescue feat (e.g. "rescue a ship directly from the Tractor Boss" / "rescue 3 ships in one run"), NOT a pure grind count — the crown jewel should feel EARNED, not ground.

**★ SYNERGY to flag:** cross-pollination [Meta-22] is what lets "how OP can I become" [Hook-A] reach exciting heights; the existing RISK mechanics (hitbox cost [Risk-12], courting-capture danger [Risk-6]) are what keep that OP from being trivial. They're complementary — escalation needs both an engine and a brake.

**[Meta-25 DEFERRED] Crown-jewel feat + captor variety — PARKED for run structure**
Two interlocking items deferred (both depend on how the run is structured):
- **Crown-jewel feat:** "rescue from the Tractor Boss" is NOT special — in the prototype the Tractor Boss is the ONLY captor, so that's just *every rescue*. A meaningful feat must reference run-structure concepts (difficulty tiers / specific conditions), e.g. "rescue a ship on every wave of tier-3 difficulty."
- **Captor variety (latent gap):** the "learned enemy tech" model [Meta-19] assumes capture by DIFFERENT enemy types — but currently only the Tractor Boss captures. Run structure must resolve: do NEW captors appear at higher tiers (each captor → its tech ship)? Or is "learning" mapped differently (e.g. by enemies present during capture)?

**✅ META LAYER STATUS: basis defined (ideas 16–25). Crown-jewel feat + captor-variety deferred to run structure. Ready to move on.

**[Meta-19] CLARIFICATION (Mrdth) — decoupled from captor variety:**
The "learned enemy tech" narrative does NOT require capture by different enemy types. While captured, the ship **HACKS THE ENEMY MAINFRAME** and returns with **SHIP SPECS** — so *any* rescue can yield *any* ship design, regardless of which enemy held it (or any other flexible in-fiction explanation).
- **Resolves the captor-variety concern:** [Meta-19] works fine with only the Tractor Boss as captor. Captor/enemy variety is now purely an OPTIONAL run-variety question for run structure — NOT a dependency for the meta model.
- **Crown-jewel feat still deferred** — it just needs run-structure concepts (tiers / conditions) to be meaningful, independent of captor type.
- Net: meta layer fully defined; nothing blocks on captor variety.

### Run Structure (guided step 5)

**[Run-26] Tier structure: 5-wave tiers, boss every 5th wave (Brotato model)**
Waves grouped into 5-wave tiers; every 5th wave is a boss wave (tier cap). Resolves the prototype's "boss every wave" tuning concern (snapshot §4: "may feel too busy; consider every-3rd-wave"). Tier boundaries (waves 5/10/15/20…) give the parked difficulty-tier feats [Meta-25] a concrete home.

**[Run-27] Victory at wave 20, then choice: end or endless**
Campaign = 20 waves (4 tiers). Beat wave 20 = VICTORY state (closure + achievement → feeds meta feat-unlocks). Player then CHOOSES: end the run (bank the victory) OR continue into endless mode.

**[Run-28] ★ Endless = locked build, NO extra power-ups (pure "how far can I push")**
Endless provides NO further power-ups; the build is FROZEN at the wave-20 state. Endless = pure skill + escalating ENEMY difficulty vs a fixed build. **The hook's two halves map to the run's two phases:** "how OP can I become" (Builder) lives in waves 1–20; "how far can I push it" (Ascender) lives in endless. Elegantly splits [Hook-A].

**[Run-29] Emergent: boss-every-5 bounds the courting-capture farm**
Capture/rescue only occurs on boss waves (every 5th) → courting-capture [Risk-6] is naturally limited to ~4 opportunities per campaign (+ endless). Further mitigates the pre-mortem farm concern WITHOUT artificial limits — a pure structural cap.

**Run termination:** default = HP 0 (to confirm).

**[Run-30] Life economy = SHIPS, with a health buffer (avoid 1-shot harshness)** *(refines run termination)*
Run ends at lives/ships = 0 — but unlike original Galaga (1 hit = 1 life), there's a HEALTH BUFFER so single hits don't instantly cost a life. Captures cost a ship (a life); rescuing + keeping regains one. The prototype's 3 HP is this buffer, reframed as ship/life integrity. *To pin:* exact model (X ships × Y HP? shared pool? per-ship health?). Confirms HP=0 (ships=0) as run-terminator.

**[Run-31] Capture is NOT limited to boss waves** *(relaxes Run-29)*
Gating capture to boss waves (4×/run) would make the courting-capture gamble [Risk-6] too rare. Instead, captor-capable enemies can appear on regular waves as a composition/variance element. Run-29's boss-only bound is dropped.

**[Run-32] ★★ SAFE-PLAY bonus > RESCUE bonus (primary farm-mitigation)** *(Mrdth — resolves pre-mortem cleanly)*
Prevent courting-capture becoming mandatory via REWARD STRUCTURE, not rarity/punishment: **~30% bonus for dodging capture all wave vs ~25% for capture→rescue→survive.** Safe play pays slightly MORE → neither path dominates:
- **Safe play** = more currency, but no rescued ship (no wingman firepower, no dual-ladder track, no sacrifice button, no life-regain).
- **Courting capture** = slightly less currency, BUT the rescued ship's full benefits.
Safe-play is the default; capture is a deliberate strategic gambit for SHIP-POWER. Keeps rescue accessible without degeneracy. The third — and best — mitigation.

**[Run-29 REVISED]** Boss-every-5 no longer the primary farm bound; the bonus structure [Run-32] is. Boss cadence [Run-26] still defines tiers, just not capture gating.

### Roguelite Variance (guided step 7)

**[Var-33] Procedural wave composition** *(seed)*
Wave patterns are NOT fixed: enemy types, counts, and formations vary between runs (generated within tier rules). Run #50 differs from run #5.

**[Var-34] Tier-cap = MODIFIER wave (random); wave 20 = FINAL boss** *(refines Run-26/27, Mrdth)*
Waves 5/10/15 are MODIFIER waves — randomly one of the approved types [Var-35] — so each run's tier-caps differ (you don't know if tier-2 ends in Swarm or Gauntlet). Wave 20 = the FINAL BOSS (fixed climactic fight = the victory gate). Evolves Run-26's "boss every 5": tier caps become modifier events, not generic bosses; the campaign culminates in one unique final boss. Randomized cap-modifiers add strong run-to-run variety.

**[Var-35] Modifier wave types (approved: Swarm / Gauntlet / Bounty)** + more possible
- **Swarm** — 2× enemies, no captor (raw-DPS build test).
- **Gauntlet** — denser fire-columns, fewer foes (dodge / hitbox-management test).
- **Bounty** — elite enemies w/ guaranteed power-up drops (build-acceleration wave).
Randomly selected for tier-caps (waves 5/10/15) [Var-34]. Roster open to more.

**🔗 CROWN-JEWEL UN-PARKED (potential):** if the wave-20 FINAL boss is a CAPTOR, then "rescue from the final boss" becomes a meaningful crown-jewel feat [Meta-25] — it's SPECIAL (happens once, at the climax, run on the line), unlike "rescue from the Tractor Boss = every rescue." Awaits decision on whether the final boss is a captor.

**[Run-36] Captor presence: graduated (teach early → escalate with wave)**
Captor appears on an EARLY wave to teach the capture/rescue mechanic, then the chance to occur increases with wave number. Good onboarding + natural difficulty curve. Refines [Run-31].

**[Run-37] ★ Multi-tier difficulty loops (Brotato / danger-level model)**
Beating a tier's wave 20 unlocks the NEXT tier (a harder 1–20 loop): **Tier 2** = enemies have more HP + more formations + elite-chance on any wave; **Tier 3** = Tier 2 but harder. Structured cross-run difficulty progression. (Proven model: Brotato danger levels, Hades heat.)

**[Run-38] Tier-cap escalation: modifier → modifier+miniboss → harder** *(RESOLVES the modifier-vs-miniboss question)*
Tier-cap content graduates with tier: **Tier 1** caps = modifier only; **Tier 2** caps = modifier + mini-boss; **Tier 3** = Tier 2 but harder. The either/or was the wrong frame — it's *both, scaled by tier.*

**[Run-39] ★ Crown jewel = beat Tier 3 (prestige) OR rescue-N grind (fallback)** *(UN-PARKS Meta-25; supersedes the "final-boss-is-captor" framing)*
Tractor-tech prize ship has TWO unlock paths: (a) **prestige/skill** — defeat Tier 3; (b) **grind/accessibility** — rescue N ships (e.g. 500), with N tuned to Tier-3 difficulty so the paths are comparable effort. Applies the [Meta-24] skill+grind-fallback principle to the crown jewel. NOT a trivial first-clear — genuinely earned. *(The "final boss is a captor" idea is now optional/thematic, not the crown-jewel gate.)*

**[Run-40] OPEN: tiers vs endless — how do they relate?** *(to confirm)*
[Run-37] multi-tier loops and [Run-28] endless-locked-build may COEXIST (different fantasies): tiers = cross-run difficulty climbing + unlocks; endless = in-run build-efficacy test (frozen build). Lean: keep BOTH. Awaits confirmation.

**[Run-40 RESOLVED] Tiers + endless COEXIST (confirmed).** Different fantasies: tiers = cross-run difficulty climbing + unlocks; endless = in-run build-efficacy test.
**Choice-point design (A vs B, under discussion):**
- **A — boss is the gate, endless = victory lap:** Beat wave-20 boss → unlocks next tier (whether you then end OR push endless) → choose end / endless. Endless = test your FINALIZED god-build's ceiling. Matches [Hook-A] "how far can I push [my build]."
- **B — boss optional, choice at wave 19:** At wave 19, choose face-the-boss (win → unlock + maybe a ship feat) OR skip to endless (no boss, scaling waves, no unlock). Endless = endurance alternative. Adds an explicit risk-choice but muddies endless-as-build-test; weakens the climax (boss optional).
**Lean: A** — endless stays the "finalized-build ceiling" flex (fits the hook); boss-mandatory = clear climax + earned unlocks; risk is inherent in the boss fight (you can die), no skip-mechanic needed.

**✅ CONFIRMED: A (Mrdth).** Run structure complete.

---

## Synthesis: Themes & Promising Combinations

*Generated from ~40 collaborative system-ideas. The spine is complete and coherent.*

### Themes

**1. The Power-Escalation Hook (the spine)** [Hook-A]
"How OP can I become / how far can I push it" — Builder supplies the means (builds), Ascender supplies the test (depth). The run's two phases ARE the hook: build the god-build in waves 1–20 [Run-27], test it in endless [Run-28].

**2. The Rescue Twist as Build ENGINE (twist feeds hook, doesn't compete)** [Risk-6, Build-2/3/9/15, Meta-19]
Rescue generates in-run power (dual-ladder, sacrifice, docked firepower), the meta fleet (learned-tech ships), and cross-pollination power-ups. The twist is the FUEL, not the identity — directly honoring "rescue = twist, not hook."

**3. Risk/Reward is the Game's DNA** [Risk-6, Risk-12, Ref-11, Run-32, Build-9]
Every system is a gamble: courting capture, sacrifice, glass-cannon hitbox, safe-play-vs-rescue bonus, dive-timing rescue. The game is saturated with meaningful risk decisions — that's its feel.

**4. Build Depth via Constraint (1-axis as feature)** [Build-5, Meta-22/23, Build-10]
Depth comes from projectile BEHAVIOR / on-hit MODIFIERS / GENERATORS, not spatial aiming. The 1-axis constraint focuses (not limits) the build space. Earned generators (turrets) can expand coverage.

**5. Proven Roguelite Skeleton** [Meta-16/17/18/20/21/24, Run-26/27/30/37/40, Var-33/34/35/38]
Brotato/Hades-influenced architecture: feat-unlocked fleet (variety>power, no currency), 5-wave tiers, 20-wave campaign, multi-tier loops, procedural variance, modifier caps, lives=ships+health. The rescue+power IDENTITY sits on top of this proven base.

**6. Self-Balancing Systems (emergent elegance)** [Risk-12, Run-32, Run-31/36]
Multiple overlapping balancers prevent degenerate strategy: hitbox compounds (caps the farm), safe-play bonus > rescue (no mandatory capture), graduated captor presence. The pre-mortem is TRIPLE-LOCKED.

### Promising Combinations (the "aha" syntheses)

1. **Hook = two phases of the run.** Builder (waves 1–20) + Ascender (endless). The run structure literally embodies the hook. [Hook-A + Run-28]
2. **Twist = hook's engine.** Rescue generates in-run power + meta fleet + cross-pollination power-ups. [Risk-6 + Build-9 + Meta-19 + Meta-22]
3. **The glass-cannon god.** Firepower (reward) & hitbox (cost) are coupled + compound = emergent difficulty curve + anti-farm. Gives the power-fantasy teeth. [Risk-12 + Build-15]
4. **Triple-locked farm mitigation.** Three independent balancers (hitbox cost, original-Galaga rescue risk, safe-play bonus) — robust by design. [Risk-12 + Ref-11 + Run-32]
5. **Cross-pollination = the 50-hour engine.** Each fleet unlock expands the build space combinatorially for ALL ships. Sustains the Builder hook long-term. [Meta-22]
6. **The espionage reframe unifies the fiction.** Capture = running spies on the enemy mainframe → ties rescue fantasy + fleet unlocks + meta layer under one narrative. [Meta-19]
7. **Tier-graduated caps + crown-jewel gating = long-term goals.** [Var-38 + Run-39]

### Session Stats
- **System-ideas generated:** ~40 (deep / structural)
- **Themes identified:** 6
- **Promising combinations:** 7
- **Pillars articulated:** hook · core loop · rescue twist · build engine · risk balance · meta layer · run structure · roguelite variance
- **Breadth NOT yet enumerated:** 20+ ship fleet, standard/specialty power-up lists, full modifier roster, formation types, feat list — natural next-phase task for the brief/GDD.

---

## Session Summary

**Working Title: 🎯 Meridian Run** — *peak/Ascender hook ("how high can I climb?") + "line through the poles" (1-axis geometry nod); "Run" = roguelite. Chosen after Steam-collision checks. Always revisable.*

### Most Promising Concepts

**🏆 Top Pick: Cross-Pollination Meta-Layer** [Meta-22]
Unlocking a ship also unlocks its signature mechanic as a findable power-up for EVERY ship → hybrid builds + combinatorial build-space growth. This is the session's standout: it's what sustains the Builder hook for 50 hours, and it directly wires the meta layer into the in-run fantasy. Each unlock = a new build component, not just a new ship.

**🥈 Runner-up: Courting Capture** [Risk-6]
Capture becomes an opportunity you *chase* (not just a punishment) — inverting classic Galaga and fusing the rescue twist directly to the power-escalation hook. The strongest candidate for the game's actual engine, balanced by a triple-lock of self-balancing systems.

**🏅 Honorable Mention: The Glass-Cannon God** [Risk-12 + Build-15]
Firepower (reward) and hitbox (cost) coupled + compound = an emergent difficulty curve *and* anti-farm in one rule. Gives the power fantasy real teeth ("how far can skill carry my own greed?") without a single patched-on limiter.

### Key Insights

- **The rescue twist must FEED the hook, not BE it** — the foundational reframe that kept the design honest (twist = engine, not identity).
- **Risk/reward is the game's DNA** — every system (capture, sacrifice, hitbox, safe-play bonus, dive-rescue) is a gamble; that saturation is the feel.
- **Self-balancing systems beat patched limiters** — three independent balancers make courting-capture non-degenerate *emergently*.
- **The 1-axis constraint focuses depth** — build variety lives in projectile behavior/modifiers/generators, not spatial aiming.
- **The espionage reframe unifies the fiction** — capture = running spies on the enemy mainframe ties rescue + fleet + meta under one narrative.

### Recommended Next Steps

1. **Create Game Brief** (`gds-create-game-brief`) — formalize this vision into a one-pager before committing to a GDD. *(The snapshot's §8 also recommends this as the immediate next step.)*
2. **Enumerate content breadth** — the 20+ ship fleet, standard/specialty power-up lists, modifier roster, formations, and feat list. Natural work for the brief/GDD phase.
3. **Pressure-test / prototype the new systems** — courting-capture + the dual-ladder + cross-pollination are unproven in code (only the v0/v1 rescue loop is playtested). A focused prototype of the build + capture economy would de-risk the biggest unknowns.

---

## Session Complete

**Date:** 2026-06-28
**Participant:** Mrdth
**Mode:** Standalone
**Status:** Complete — Steps [1, 2, 3, 4]

### Output
This brainstorming session generated:
- ~40 deep system-ideas
- 6 emerging themes
- 7 promising combinations
- A complete, coherent design spine across all 8 pillars (hook → loop → twist → build → risk → meta → run → variance)

### Handoff
Next planned workflow: `gds-create-game-brief` (formalize vision) → `gds-gdd` (full design document).**
