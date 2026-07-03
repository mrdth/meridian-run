---
title: Meridian Run — Game Design Document
game_type: Roguelite Shooter (fixed-screen, 1-axis, Galaga-lineage chassis)
primary_game_type: roguelike (roguelite)
secondary_game_type: shooter (arcade, fixed-screen)
genre_complexity: high
platforms: [Windows, Linux (desktop)]
created: 2026-06-29
updated: 2026-06-30
status: draft
version: 1.1-draft
sources:
  brief: _bmad-output/planning-artifacts/briefs/brief-meridian-run-2026-06-29/
  brainstorming: _bmad-output/brainstorming-session-2026-06-28.md
  research: _bmad-output/planning-artifacts/research/domain-roguelite-arcade-base-research-2026-06-27.md
  prototype: _bmad-output/planning-artifacts/prototype-1-design-snapshot.md
---

# Meridian Run — Game Design Document

**Author:** Mrdth
**Game Type:** Roguelite Shooter (fixed-screen, 1-axis, Galaga-lineage chassis)
**Target Platforms:** Windows + Linux (desktop)

> **Bracketed refs** (`[Ref-11]`, `[Risk-12]`, `[Var-33]`, `[Var-34]`, `[Build-9]`, `[Build-15]`, `[Wave-1]`) cite settled decisions in the brainstorming session / brief / GDD-session — see `decision-log.md`.

---

## Executive Summary

### Core Concept

A build-crafter roguelite on Galaga's 1-axis fixed-screen chassis. Build a ship into absurd, compounding power across a 20-wave / 4-tier campaign, then test how far skill can carry that greed in endless mode. The **glass-cannon god**: your firepower and your hitbox grow together, so the more powerful you become, the harder the same bullets are to dodge. The feeling: *the thrill of betting your survival on your escalating power, sharpened by a constrained lane where every risk counts — mastery over your own greed.*

### Target Audience

**Primary:** roguelite build-crafters — the *Brotato* / *Vampire Survivors* / *Hades* / *Binding of Isaac* crowd who love compounding builds and push-your-luck and chase the "one more run" curve. They get a fresh 1-axis combat chassis instead of another twin-stick.
**Secondary:** classic-arcade / shmup veterans and *Galaga* nostalgists — smaller, loyal, starved of a modern fixed-screen fix. A bonus, not the target.

### Unique Selling Points (USPs)

1. **A fresh 1-axis combat chassis** — weave fire-columns in a constrained lane, vs. the twin-stick kiting the audience has played dozens of times.
2. **A capture/rescue/sacrifice build economy** the genre leaders lack — they are pure item-stacking.
3. **The glass-cannon hitbox as a risk lever** — only 1-axis geometry makes "more power = bigger target = harder to dodge" brutal.

---

## Goals and Context

### Project Goals

Portfolio / skill-build: learn Godot 4.6 deeply by shipping a complete, real game. A finished vertical slice takes priority over breadth; scope is brutally honest to one intermediate solo dev. Commercial positioning is **not** required.

### Background and Rationale

Originated in a JS/Canvas prototype (reference-only — re-derived in Godot idioms, **not** ported). Domain research evaluated five classic arcade bases for a roguelite twist; *Galaga* scored 12/15 on the strength of its capture→sacrifice verb — *"the design space around 'what do I give up now for what advantage later?' is deep and barely tapped."* Brainstorming reframed rescue as the hook's *engine*, not its *identity*: Meridian Run is a build-crafter roguelite whose combat chassis is 1-axis fixed-screen Galaga. The Galaga aspect is a differentiator, not the identity.

---

## Core Gameplay

### Game Pillars

The whole design answers to three orthogonal pillars — accumulation / decision / execution. Each was cut-tested: removing any one breaks the game.

**P1 · Godhood — *"How overpowered can I become?"***
Build a ship into absurd, compounding power across the run; the late game must reach a felt peak of runaway strength.
*Steers:* the multi-source build engine, the dual-ladder, the compounding power curve, the late-run godhood-peak target, and the cross-pollination depth that sustains it.

**P2 · The Gamble — *"How far will I push my greed?"***
Every system is a bet: court capture, choose rescue-or-sacrifice, weigh the safe-play bonus against the bigger capture payout.
*Steers:* the courting-capture economy, the safe-vs-rescue bonus gap (~30% vs ~25%), the sacrifice burst, the dual-ladder invest-vs-spend, and the discrete survival unit the gamble trades.

**P3 · The Test — *"How far can skill carry it?"***
A constrained 1-axis lane of readable fire-columns where a hitbox that grows with your power means skill must carry the greed you built.
*Steers:* the 1-axis chassis, hitbox-as-cost, telegraph/dodge windows, readability, and the underdog-rescuer identity.

**Design principles preserved (not pillars, but load-bearing):**
- **Cross-pollination** — unlocking a ship seeds its signature mechanic into the shared power-up pool for every ship — the engine of the 50-hour build depth (P1 + meta).
- **Rescue is the engine, not the identity** — the capture/rescue loop exists to *feed* the Godhood+Gamble fantasy, never to be the headline. (A standing design discipline from the brainstorming's pivotal reframe.)
- **Underdog rescuer, never aggressor** — a *mechanic-evaluation guardrail*, not just an art choice: if a proposed mechanic doesn't serve the rescue fantasy or the recoverable-life tension, it's off-theme. (This is why the prototype's radial-burst / capture-enemies version was rejected.)
- **Triple-lock self-balancing** — three independent farm-mitigations overlap by design (hitbox-compounds [Risk-12], safe-play bonus > rescue bonus, threat-relative sacrifice ceiling), so degenerate strategies are pre-empted without patched-on limiters.

### Core Gameplay Loop

Survive procedurally-composed waves → earn power-ups and currency → court capture on captor waves (or play safe for a higher bonus) → rescue for a docked dual-fighter or sacrifice for a power burst → compound power across the 20-wave / 4-tier campaign → beat the wave-20 final boss → choose to end or push endless with a frozen build. Losing your last ship ends the run.

**Moment-to-moment:** weave a 1-axis lane of fire-columns, manage a hitbox that grows with each docked ship, and decide each captor wave whether to court capture (gamble) or play safe.

### Win/Loss Conditions

- **Win:** defeat the wave-20 final boss (then choose: end the run, or continue into endless).
- **Loss:** lose your last ship (ships = 0). HP is per-wave; full heal between waves.

---

## Game Mechanics

### Primary Mechanics

#### Life & Health Economy

Two layered resources with clean, separate roles:

- **Ships (lives)** — the **run economy** and the discrete unit the Gamble (P2) trades. Start **3**, cap **5**; run ends at 0. Ships enter only from external sources (tier-cap floor, shop/upgrades) — the capture/rescue loop is ship-neutral (keep) or ship-negative (sacrifice/absorb/failed-rescue). Ships are never farmed, only spent or bet.
- **HP (per-ship buffer)** — the **wave-survival** resource for the Test (P3); chip damage from fire-columns. Base **3**, grows via defensive build. **Fully heals between every wave**, so HP is a within-wave resource — run tension lives in ship attrition, not HP attrition.

**Damage model:** standard fire **1 dmg** (flat across all tiers — pressure scales, not lethality); heavy/elite shots **2 dmg** (rare, telegraphed). i-frames **1 s** after each hit.

**Capture:** costs **1 ship**, bypasses HP; next ship respawns at full HP. **Once per wave, clean-only** — a captor can only tractor a ship with no docked ship present (special/modifier waves excepted). **Max one docked ship at a time** (one capture/rescue/dock per wave) — multiple docked ships are not supported.

**The clean/docked tradeoff** — the central within-wave decision, expressing all three pillars at once:

| State | Capture risk | Fire risk | Firepower |
|---|---|---|---|
| **Clean** | ON — gamble available | small hitbox → easy dodge | base |
| **Docked** | OFF — capture-immune | bigger hitbox ([Risk-12]) → hard dodge | +dual-fighter |

#### The Rescued Ship — dual nature

The rescued ship is **one entity with two roles** (reconciling the combat and build views):

- **The BUILD (permanent run-long track)** — invested in via the rescued-ship ladder; **never lost**, even when the docked ship is sacrificed or absorbed. This is the track the sacrifice burst scales with.
- **The DOCKED SHIP (consumable combat fighter)** — the physical dual-fighter attached after rescue: +firepower, +hitbox, intrinsic first-hit absorber.

#### Docked-ship resolution

You make **one active choice — Sacrifice now, or Hold:**
- **Sacrifice** (active, input): consume the docked ship → threat-relative burst (see below). The **build track persists.** Net −1 ship.
- **Hold** (passive default): keep the docked ship through the wave. Holding resolves to one of:
  - **Keep** — reach wave-end with it alive → it flies off → regain 1 ship. Net 0.
  - **Absorb** — *intrinsic, not chosen:* if you're hit while holding, the docked ship dies first, sparing your HP. Net −1 ship (it's gone, no regain). This is the **hold-vs-cash micro-tension**: hold too long and you may lose the sacrifice window to an absorb.
- **Failed rescue** (failure outcome, not a choice): kill the captor in formation → the captured ship **turns against you** ([Ref-11]). Net −1 ship, +1 enemy.

**No-gamble baseline — Safe play** (avoid capture): no ship change, +safe-play bonus (~30%) vs rescue bonus (~25%).

**Anti-spam:** sacrifice needs **no artificial cooldown** — every sacrifice forgoes the survival payout (keep→regain) AND spends a potential life, so the opportunity cost is the natural limiter ([Build-9]). Combined with one-docked-ship-per-wave, sacrifice is inherently bounded.

#### Capture / Rescue / Sacrifice

- **Captor** (Tractor-lineage) state machine: **enter (~1 s, descends to formation row)** → formation (3.5–5.5 s random, side-to-side + periodic fire) → telegraph (**0.7 s**, capture column locks to player x — the fair dodge window) → capture (**0.4 s** active) → dive (**1.6 s**, bezier toward player then off-screen). Caught during the 0.4 s window while clean → captured (−1 ship, stored on boss).
- **Onboarding cadence:** a captor appears on an **early wave to teach** capture/rescue, then captor-chance **scales with wave number** so the gamble stays available without being spammy.
- **Rescue:** kill the captor **during its dive** → freed ship docks. Kill in formation → ship turns enemy ([Ref-11]).
- **Sacrifice burst:** threat-relative temporary buff — **triple-shot (±0.18 rad) / ×1.5 damage / fast-fire (0.10 s cooldown) / ~10 s**. Scales with the rescued-ship build track, bounded against current-wave threat (see *Difficulty Curve*). **No screen-clear** (prototype guardrail).
- **[Risk-13] reserve lever** (held, not committed): captured firepower could be added to the captor — your own build threatens you — as a high-end escalation dial if late-run balance needs it.

#### Movement & Combat Chassis

1-axis horizontal movement, fixed-screen, player locked to the bottom lane. Vertical fire-columns only. **Player move-speed baseline ~320 px/s** *(baseline, playtest-tuned)* — the chassis's central feel param, balanced against bullet speed (620 px/s) and the 0.7 s telegraph window so dodge-feel is fair. Earned non-vertical generators (Brotato-style turrets) are a **bounded exception** for coverage; player-ship fire stays strictly 1-axis. **Build-axis priority:** projectile behavior > on-hit modifiers > generators.

### Controls and Input

- Keyboard + gamepad, all via Godot **Input Map actions** (never hardcoded keys). Actions: Move (left/right), Fire, Sacrifice docked ship, plus UI (confirm/back/pause).
- Analog stick movement with a deadzone (continuous, not digital); every action has both keyboard and gamepad bindings — controller vs keyboard "just works."
- Saves/settings via `user://`.

---

## Roguelite Specific Design

### Run Structure

- **20 waves / 4 tiers** (Brotato model). Every 5th wave is a modifier wave.
- **Wave termination = timed (Brotato-clock), not kill-count** [Wave-1]. A wave ends when its **fixed, data-tuned duration** (`wave_tuning.tres`) expires — **not** when the screen is cleared. The fixed clock is the only model that (a) bounds run length, (b) preserves godhood *duration* (P1 — the clock is the ruler power is measured against; kill-count *shrinks* late waves and thus the peak window), (c) guarantees the captor FSM its full gamble runway + a predictable *Keep*-outcome horizon (P2), (d) keeps the [Risk-12] docked-hitbox cost honest for the whole wave (P3 — kill-count lets strong builds dodge the cost via short exposure), and (e) lets the **Gauntlet** modifier ("dense fire, *few* foes") function as a real dodge test. *(The prototype's clear-condition was gated on a per-wave boss no longer in the design — boss is wave-20 only — so it does not carry over.)*
- **Run-length budget = a feel guideline, not a cap.** A full 20-wave run (excl. endless) is expected to land **~25–45 minutes** — naturally bounded by timed waves + the between-wave reward/shop interludes. The 20–30 min gut-feel is **not** a hard cap; ~45 min is acceptable. Wave duration is the primary dial, tuned in playtest (logged as a Difficulty-curve knob). *(Endless is bounded only by player skill.)*
- **Spawning within a wave = escalating pulsed formations** [Wave-1][Wave-2]. `RunGenerator` emits a **spawn schedule** — an ordered list of **formation pulses** (composition + entry timing + dive pattern + captor-presence) via the `enemy_spawn` sub-stream. Pulses recur every `drip_interval_s` for the whole duration; each spawns `per_tick(wave) = min(per_tick_base + ⌊wave × per_tick_growth⌋, max_per_tick)` enemies — **wave-scaled and hard-capped per tick (a performance guardrail), with NO on-screen concurrency cap**. Each pulse enters → forms → dives → **re-enters and cycles until killed** (Galaga-lineage loop); as one disperses, the next enters, so **pressure escalates** across the wave (timer-terminated waves *require* replenishment — a fixed batch clears-fast-then-waits). The per-tick cap bounds spawn *rate*, not on-screen count; worst-case entities (`wave_duration / drip_interval × max_per_tick`) are verified at the perf gate. *Galaga's choreographed soul inside Brotato's bounded clock.* **[Wave-2] (2026-07-03, correct-course):** retires the prior `4+N, cap 12` concurrency cap and its P3 readability rationale — a fixed cap is a ceiling an 8–12× godhood build trivializes, and timer-termination demands replenishment. See decision-log `[Wave-2]`.
- Waves 5/10/15 = **modifier waves** (randomly one of approved types); wave 20 = **final boss** (fixed, the victory gate).
- **Endless:** build frozen at the wave-20 state, no further power-ups, **escalating enemy threat** — the Ascender phase. *"How OP can I become"* (waves 1–20); *"how far can I push it"* (endless). **Escalation baseline:** ~+10% enemy HP & fire-density per wave past 20 *(baseline, playtest-tuned)*.
- Run ends at ships = 0.

### Procedural Generation

Deterministic **seeded** generation — same seed → same wave layouts, spawns, and modifier selections (player timing still varies; not a frame-exact replay). `project-context.md` already mandates seeded `RandomNumberGenerator`, so the discipline is free.
- **Procedural (seed-governed):** wave composition **and spawn schedule** (enemy types / counts / formations / pulse-timings, [Var-33][Wave-1]); modifier-wave selection at waves 5/10/15 ([Var-34]).
- **Authored (fixed):** wave-20 final boss fight; captor AI behavior; individual enemy stats.
- **v1.0:** determinism under-the-hood only (reproducible runs, debuggable, feature-ready). **Post-1.0:** daily-challenge + shareable seed codes + leaderboards.

### Permadeath and Progression

- **Permadeath-lite:** run ends at last ship; in-run power is lost.
- **What persists:** the feat-unlocked fleet. **No meta-currency, no between-run shop** (avoids grind + bookkeeping; keeps meta skill-driven).
- **Meta split:** ~80/20 (or 90/10) **variety vs raw-power**. The small raw-power slice **compresses early waves** on future runs (skip mastered content), not raise the late-game ceiling (Hades pattern).
- **Unlock cadence:** pure **feat-based** (progression-gated / skill / grind-fallback), not per-rescue. Three feat types: progression ("win with A → unlock B"), skill ("no-hit a dive", "rescue at 1 HP"), grind/accumulation ("rescue 50 total") as accessibility safety net.
- **Cross-pollination mechanism:** on **unlocking a ship (the fleet-unlock meta event)**, its signature mechanic is added as **one entry to the shared power-up pool**, droppable for **all ships** in all subsequent runs (weighted alongside the standard pool). **Mechanism = v1.0; full depth (synergies, specialty gating) = post-1.0.**
- **Crown-jewel ship:** Tier-3 victory **or** rescue-N grind (N ≈ 500, tuned to comparable effort — see *Assumptions*).

### Item and Upgrade System

- **Two-tier power-up pool:** **standard** (fire-rate, shields, damage, move-speed, +HP-cap, +ship — available to all ships from start) + **specialty** (armor-piercing, tractor-pull, blast-columns… gated behind fleet unlocks via cross-pollination).
- **Dual build ladder:** **main ship** (persistent core identity, run-long) + **rescued ship** (permanent build track per *dual nature* above; the docked fighter is the consumable). Power-ups target either ladder.
- **Acquisition (Brotato-style) — baselines** *(playtest-tuned)*: wave clear → **3 power-ups, choose-1** (take **or** sell at ~50% value); between-wave **shop offers 4 random** power-ups at currency cost. Rescued-ship survival → currency multiplier + biased odds toward rescue-oriented power-ups. **Target ~12–15 power-ups acquired by wave 20.**
- **Synergy model:** godhood-defining upgrades compound **multiplicatively over current** (not additive-over-base); **target ~8–12× wave-1 DPS at the final boss** *(baseline, playtest-tuned)* — the felt godhood peak.
- ✅ **Sacrifice-compounding ceiling resolved (threat-relative)** — see *Difficulty Curve*.
- ⏳ **Full standard/specialty pool lists** = content-breadth brainstorm.
- **Score = display-only** (cumulative; leaderboards post-1.0), **separate from currency** — currency is earned per wave + rescue multiplier and fuels builds. Score never spends.

### Character Selection (The Fleet)

- Ship types = distinct playstyles / base properties (**variety > raw power**). **v0.1:** 2–3 ships. **v1.0:** feat-unlocked fleet. **Post-1.0:** 20+ ships.
- Each ship's signature mechanic also becomes a findable power-up for all ships (cross-pollination).
- ⏳ **Full roster** (e.g. Bullet Hose, Interceptor, Bulwark, Shield-Piercer, Heavy, Controller…) = deferred to the post-systems content-breadth brainstorm.

### Difficulty Modifiers

- **Multi-tier loops:** beat wave 20 → unlock a harder 1–20 tier. **Baselines** *(playtest-tuned)*: **Tier 2** = +30% enemy HP, +elite-chance any wave, denser formations; **Tier 3** = Tier 2 + another step (~+60% total). Brotato danger-levels / Hades heat.
- **Modifier waves** (waves 5/10/15, randomly one approved type): **Swarm** (2× enemies, no captor — raw-DPS test) · **Gauntlet** (denser fire-columns, fewer foes — dodge/hitbox test) · **Bounty** (elite enemies, guaranteed power-up drops — build-acceleration).
- **Tier-cap escalation:** Tier 1 caps = modifier only; Tier 2+ caps = modifier + mini-boss.
- ⏳ Full modifier roster (beyond the three above) = content-breadth brainstorm.

---

## Shooter-Chassis Specific Design

### Weapon Systems

Prototype baselines (retuned in v1.0 playtest):

| Weapon | Damage | Fire cooldown | Notes |
|---|---|---|---|
| Player base shot | 10 | 0.16 s | straight up, 620 px/s |
| Sacrifice burst (buffed) | ×1.5 | 0.10 s | +triple-shot (±0.18 rad), ~10 s, threat-relative ceiling |
| Docked ship stream | 10 | matches player | parallel bullet, +28 px x-offset |
| Earned generators | ⏳ | ⏳ | bounded non-vertical coverage (earned exception); values in content-breadth brainstorm |

- Build-axis priority: **projectile behavior > on-hit modifiers > generators.**
- No screen-clearing weapons (prototype guardrail — large-AoE only when rare/earned/non-repeatable).
- ⏳ Ship-signature weapons + specialty pool = content-breadth brainstorm.

### Aiming and Combat Mechanics

- **Aiming:** fixed vertical fire (1-axis); no twin-stick, no aiming input.
- **Hit detection:** projectile (not hitscan).
- **Dodge:** 1-axis lateral; telegraphed capture column (0.7 s window) is the read-and-react test.
- No critical/weak-point system (arcade-flat); open whether elites get weak points.

### Enemy Design and AI

Prototype baselines (retuned per tier in v1.0):

| Enemy | HP | Score | Behavior | Fire interval | Speed |
|---|---|---|---|---|---|
| Grunt | 30 | 100 | downward, cannon-fodder | 1.2–2.4 s | 60 |
| Shielder | 50 | 150 | tougher | 0.9–1.8 s | 50 |
| Bomber | 80 | 300 | heavy (**2 dmg**) | 1.6–2.8 s | 80 |
| Captor (Tractor) | 60 *(+50%/tier)* | — | enter/formation/telegraph/capture/dive state machine | — | — |

- **Formation + dive AI** (*Galaga*-lineage); wave N = 4+N enemies, cap 12; variant mix scales by tier.
- 🚧 **Captor variety at higher tiers** — open run-variety question (decoupled from the meta model after the mainframe-hack clarification).

### Arena and Level Design

- **Single fixed-screen**; player locked to bottom; 1-axis horizontal lane; vertical fire geometry. No cover, no verticality — a pure dodge lane (the readability that makes the 1-axis Test fair).
- Power-up drops on wave clear and on Bounty modifier waves.
- **Multiplayer:** N/A — single-player only (out of scope).

---

## Progression and Balance

### Player Progression

- **In-run:** compounding power — waves 1–20 forge the god-build; dual-ladder (main persistent + rescued build track); cross-pollination expands the build space mid-run.
- **Meta:** feat-unlocked fleet + cross-pollination; crown-jewel ship via Tier-3 or rescue-N.
- **Endless:** frozen build (no further growth) — pure skill vs escalating threat.

### Difficulty Curve

*(shape agreed; exact numbers = v1.0 playtest)*

Target the **player-power : enemy-threat ratio** (absurdity is relative, not absolute):
- **Build phase (waves 1–20): compounding** — player power rises faster than enemy threat; synergies multiply (multiplicative-over-current), dual-ladder + cross-pollination stack. Target **~8–12× wave-1 DPS at the final boss**.
- **Peak ~waves 17–20** — godhood peaks **at the final boss** so the climax lands at maximum power, not after a coast.
- **Endless: inverted** — frozen build vs escalating enemy threat (~+10%/wave); the Test (P3) begins.
- **Tuning knobs (v1.0 playtest):** power-up acquisition rate/wave · synergy multiplicativity · enemy HP/density scaling per tier · tier-cap power spikes · **wave duration (the run-length / pacing dial, [Wave-1])**.
- **Sacrifice-burst ceiling = threat-relative:** scales against current-wave enemy HP/threat, so always a useful tide-turner and never an insta-win regardless of track investment. Reinforced by: buff-not-nuke (no screen-clear), −1 ship cost, opportunity-cost anti-spam, one-sacrifice-per-wave.

### Economy and Resources

- **Shared currency pool** fuels both build ladders via take/sell/shop. *(Score is proposed separate/display-only — see Item & Upgrade System.)*
- Survive wave → earn currency; rescue-and-survive → earn more (multiplier).
- **Safe-play bonus (~30%) > rescue bonus (~25%)** — the primary farm-mitigation; safe play yields more currency but no rescued-ship benefits, courting capture yields slightly less currency but full ship benefits.

---

## Level Design Framework

### Level Types

- Regular waves · captor waves · modifier waves (Swarm / Gauntlet / Bounty) · tier-cap waves (modifier / mini-boss) · wave-20 final boss · endless.

### Level Progression

- 4-tier campaign → victory → endless; multi-tier unlock loops (Tier 2, Tier 3).

---

## Art and Audio Direction

### Art Style

Clean geometric **neon-vector** (touchstones: *Geometry Wars*, *Resogun*, *Nova Drift*). Pixel art rejected — higher cost + worse readability for a solo intermediate dev. Neon-vector maximizes 1-axis lane-readability (essential for reading fire-columns), honors the arcade vector lineage, and enables cheap juice (neon glow, particle bursts, screen-shake on the godhood peak). **Philosophy:** favor **build-crafter reward clarity — juice, readability, clear power-up feedback, progression UI — over shmup-purist minimalism** (resolved by audience: the primary crowd wants the Brotato/VS-style reward read, not Galaga-purist austerity). The **underdog-rescuer** identity governs all visual identity (player reads as the rescuer, never the aggressor).

### Audio and Music

Synthwave / arcade-electronic — fits the neon-vector look, *Galaga*'s electronic roots, and the power-escalation energy. Punchy SFX on hits, pickups, and sacrifice bursts carry the juice as much as the visuals.

**Narrative (light flavor, not load-bearing):** a space-navy / espionage frame — captured ships hack the enemy mainframe and return with ship specs, justifying why rescues unlock new fleet ships. *"Meridian"* nods to both the 1-axis geometry (a line through the poles) and the peak/ascent hook. Build-crafters aren't here for lore.

---

## Technical Specifications

### Performance Requirements

- **≥60 FPS floor** (minimum, not a cap) — frame-budget ceiling 16.67 ms for the worst-case frame (`project-context.md`).
- Gameplay on a **fixed-timestep physics loop (60 Hz)**; all motion delta-based so it behaves identically at 60 or 144+ FPS.
- **Deterministic** seeded runs (reproducible from a seed). Profile measured hotspots, not guesses.
- *(Pooling, batching, scene structure, and node choice are architecture decisions — see `gds-game-architecture`, not this spec.)*

### Platform-Specific Details

- **Windows + Linux desktop**; Godot 4.6, 2D, Compatibility renderer. Export preset per platform; verify on both before release.
- Input via Input Map actions + gamepad; saves/settings via `user://`; responsive 2D scaling (fixed base resolution, canvas-scaled).

### Asset Requirements
⏳ Asset counts and budgets deferred with the content-breadth brainstorm (neon-vector keeps the per-asset cost low).

### Testing
**GUT** (Godot Unit Test) is the committed test framework — installs at project scaffolding (Epic 1) under `addons/gut/`; runs headless via `godot --headless -s addons/gut/gut_cmdln.gd`. Testability principle (`project-context.md`): separate pure logic from Node/scene code so systems unit-test without instantiating scenes; tests under `tests/` mirroring the domain layout, named `test_<thing>.gd`.

---

## Development Epics

> Detailed breakdown: `epics.md`. Recommended sequence below. v0.1 = Epics 1–3 (systems-validation slice); v1.0 = Epics 1–5 (shipped game); post-1.0 = Epic 6.

| # | Epic | Milestone | Playable deliverable |
|---|---|---|---|
| 1 | Combat Chassis & Feel | v0.1 | a single wave with good feel |
| 2 | The Gamble | v0.1 | full capture/rescue/sacrifice loop in a wave |
| 3 | Build Engine | **v0.1 hypothesis** | a compressed ~5-wave run hitting a felt godhood peak |
| 4 | Run Structure & Meta | v1.0 | full 20-wave run → boss → endless |
| 5 | v1.0 Polish & Content | v1.0 | shippable game (Win + Linux) |
| 6 | Post-1.0 Growth | post-1.0 | full fleet, daily seeds, depth (uncommitted) |

---

## Success Metrics

### Technical Metrics

- ≥60 FPS sustained on target hardware (Windows + Linux), measured over a 10-minute combat loop.
- Deterministic seeded runs reproducible from a seed.
- Clean headless GUT test suite passing; both platform exports verified.

### Gameplay Metrics

*(portfolio scope — honest playtest signal, not telemetry rigor)*
- **v0.1 hypothesis validated:** a compressed run produces a **felt godhood peak** (the build+gamble systems deliver the fantasy).
- The **gamble is engaged:** safe-vs-capture choices actually occur and feel meaningful (not solved, not ignored).
- The **"one more run" pull** is reported in playtesting.
- **Portfolio bar met:** learned Godot 4.6 deeply; shipped a complete, shippable v1.0 game (the definition of done).

---

## Risks

- **[CENTRAL DESIGN BET] 1-axis movement-depth risk.** The chassis is both the wedge *and* the known weakness — modern players expect more positional expressiveness (the industry abandoned fixed-screen 1-axis for a reason). **Mitigation:** constrained movement makes build and gamble the primary expression of skill and strategy; the clean/docked tradeoff and the glass-cannon hitbox give the lane real depth. This bet must be validated early (Epic 1 feel gate, Epic 3 hypothesis).
- **Unproven new systems.** Only the rescue loop is playtested (prototype). Courting-capture, the dual-ladder, and cross-pollination are unproven in code — Epic 3 is the go/no-go gate for exactly these.
- **Scope vs solo dev.** The full vision is large; the v0.1→v1.0→post-1.0 phasing and the content-breadth deferrals exist to keep it shippable by one intermediate dev. The cross-pollination *depth* (the 50-hour engine) is the prime scope-risk → post-1.0.
- **Godhood-peak tuning.** Builds must reach absurdity by the final boss without trivializing it; migrated to v1.0 playtest (baselines ~8–12× DPS documented above as starting targets).
- **[Risk-13] reserve lever** — held in reserve if late-run balance needs an escalation dial (see *Capture / Rescue / Sacrifice*).

---

## Out of Scope

- Commercial / market positioning.
- Meta-currency / between-run shop.
- Screen-clearing bombs; player radial / 8-way fire.
- Mobile / touch controls.
- Narrative / visual-novel density.
- Full fleet depth at v1.0 (post-1.0); daily/shared-seed UX at v1.0 (post-1.0).

---

## Assumptions and Dependencies

- **[ASSUMPTION]** Prototype tuning values (HP 3, fire cooldown 0.16 s, bullet 620 px/s, enemy stats, captor timings) are starting baselines, retuned in v1.0 playtest.
- **[ASSUMPTION]** Safe-play ~30% / rescue ~25% bonus values are placeholder targets, tuned in playtest.
- **[ASSUMPTION]** Crown-jewel rescue-N ≈ 500 — tuned to Tier-3-comparable effort.
- **[Dependency]** GUT test framework (committed decision; installs at project scaffolding / Epic 1).
- **[Dependency]** Content-breadth brainstorm (post-systems) for the full fleet roster, specialty pool, modifier roster, formation types, and feat list.
- **[Bracketed refs]** cite brainstorming/brief decision IDs: `[Ref-11]` dive-timing rescue + formation-turn penalty · `[Risk-12]` dual-fighter larger hitbox · `[Var-33]`/`[Var-34]` procedural wave/modifier variance · `[Build-9]` sacrifice model (permanent track + consumable ship) · `[Build-15]` hybrid docked ship (intrinsic absorber) · `[Risk-13]` captured-firepower reserve lever · `[Wave-1]` timed-duration wave structure (pulsed formations; kill-count rejected) — **GDD-session decision**.

---

## Open Questions (remaining)

- **Q#6 Cross-pollination balance** — hybrid-build OP-ness; mechanism proposed (above), exact balance in v1.0 playtest.
- **Q#8 Modifier-wave roster** — Swarm/Gauntlet/Bounty + more; ⏳ scope the v1.0 roster in the content-breadth brainstorm.
- **Q#9 Captor variety at higher tiers** — ⏳ run-variety, post-systems.
- **Q#10 Feat-list design** — three feat types defined; actual feats ⏳ content-breadth brainstorm.
- **Q#11 Content-breadth enumeration** — full fleet roster, specialty pool, formations, feats. ⏳ Deferred to a dedicated post-systems brainstorm (per brief) — not blocking this GDD's structure, only its content breadth.
