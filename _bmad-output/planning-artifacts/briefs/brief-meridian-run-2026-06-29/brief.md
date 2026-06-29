---
title: "Meridian Run — Game Brief"
status: draft
created: 2026-06-29
updated: 2026-06-29
project_name: meridian-run
purpose: portfolio_skill_build
working_mode: coaching
source_inputs:
  - "_bmad-output/brainstorming-session-2026-06-28.md"
  - "_bmad-output/planning-artifacts/prototype-1-design-snapshot.md"
  - "_bmad-output/planning-artifacts/research/domain-roguelite-arcade-base-research-2026-06-27.md"
  - "_bmad-output/project-context.md"
---

# Game Brief: Meridian Run

## Executive Summary

**Meridian Run** is a build-crafter roguelite shooter built on ***Galaga*'s 1-axis, fixed-screen chassis**. Where genre leaders like *Brotato* and *Vampire Survivors* inherit *Robotron*'s twin-stick freedom, Meridian Run constrains the player to a single horizontal lane — and turns that constraint into the game's edge. The player weaves fire-columns, courts capture to fuel runaway builds, and pushes to see how far skill can carry their greed.

At its heart is the **glass-cannon god**: a ship built into absurd, compounding power, where the player's skill must carry the greed that built it. *Galaga*'s signature capture/rescue twist is re-engineered as the build *engine* — courting capture, rescuing for a dual-fighter, and sacrificing for a power burst are all push-your-luck decisions. Risk/reward is the game's DNA; every system is a deliberate gamble.

This is a **solo-developed portfolio piece**: a complete, shippable roguelite that proves a finished game can be built in Godot 4.6, architected so a lean v1.0 can grow into the full fleet, endless mode, and combinatorial build depth over time. The Galaga-style fixed-screen roguelite is essentially unclaimed territory — a fresh hook in a crowded genre.

## Vision

**Core fantasy (one sentence):** Build a ship into absurd, compounding power — then see how far your skill can carry your greed.

**Elevator pitch:** A build-crafter roguelite built on *Galaga*'s 1-axis chassis — weave a single lane, court capture to fuel runaway builds, and see how far your skill can carry your greed.

**The feeling:** the thrill of betting your survival on your escalating power — sharpened by a constrained lane where every risk decision counts. The build (the godhood pull) leads; the gamble — courting capture and sacrifice — and the test (skill and dodge) give it teeth.

## Target Players & Market

**Primary audience — roguelite build-crafters.** The *Brotato* / *Vampire Survivors* / *Hades* / *Binding of Isaac* crowd: players who love compounding builds and push-your-luck, who chase the "one more run" curve. They get a **fresh combat chassis** (1-axis lane-weaving) instead of another twin-stick.

**Secondary audience — classic-arcade / shmup veterans.** *Galaga* nostalgists and score-attack purists, smaller but loyal, starved of a modern fixed-screen fix — a bonus, not the target.

**Why now:** the fixed-screen, fixed-direction roguelite is essentially unclaimed (no prominent modern entry). The build-crafter audience is large and reachable; the 1-axis framing is the differentiator that earns their attention.

## Core Fundamentals

**Genre:** roguelite shooter (fixed-screen, 1-axis horizontal movement).

**Core loop:** survive procedurally-composed waves → earn power-ups and currency → court capture on captor waves → rescue for a dual-fighter or sacrifice for a power burst → compound power across a 20-wave / 4-tier campaign (5 waves per tier) → beat the final boss → push endless with a frozen build. Losing your last life ends the run.

**Pillars (load-bearing design commitments):**

1. **The godhood curve.** Compounding in-run builds are the spine; the run's two phases embody the fantasy — forge the god-build in waves 1–20, test it in endless.
2. **Rescue as build engine, not identity.** Capture/rescue/sacrifice is the in-run power economy; courting capture is a deliberate strategic gambit, not a punishment. The twist fuels the hook; it isn't the hook.
3. **Risk is the chassis's gift.** The 1-axis constraint makes the glass-cannon hitbox brutal and the gamble sharp. Because movement is constrained, build and gamble decisions become the primary expression of skill and strategy.
4. **Cross-pollination meta.** Each ship unlock seeds its signature mechanic into the shared power-up pool for *every* ship — combinatorial build-space growth that sustains long-term depth. (The *mechanism* is a v1.0 system; the full *depth* arrives post-1.0 — see Scope.)

**Mechanics (summary; detail in GDD):**
- 1-axis horizontal movement; formation and dive enemy AI
- Captor tractor-beam capture → rescue yields a **dual-fighter** (firepower + larger hitbox + first-hit absorber)
- **Sacrifice burst** — an "oh-shit button" scaling with the permanent build track
- Safe-play-vs-rescue bonus economy; feat-unlocked fleet (variety over raw power)
- Multi-tier difficulty loops; procedural wave and modifier variance

**Player-experience goals:** readable lane-combat; satisfying, legible compounding power; thrilling push-your-luck; mastery over your greed.

## References & Differentiation

| Title | Take | Deliberately leave |
|---|---|---|
| **Brotato** | Roguelite build-craft skeleton; 5-wave tier structure; feat-based unlocks; reward architecture | Twin-stick movement; item-stacking-only economy |
| **Vampire Survivors** | Short-run compounding-build dopamine | Auto-shooter passivity; open movement |
| **Hades** | Meta-progression pattern; heat / multi-tier loops | Narrative / visual-novel density |
| ***Galaga*** | 1-axis fixed-screen chassis; capture → dual-fighter mechanic; formation + dive AI | Pure score-attack; single-life harshness; no meta |

**Differentiators (mechanical, not cosmetic):**
1. **A fresh 1-axis combat chassis** — weave fire-columns and time in a constrained lane, vs. the twin-stick kiting the audience has played dozens of times.
2. **A capture/rescue/sacrifice build economy** the genre leaders lack — they are pure item-stacking.
3. **The glass-cannon hitbox as a risk lever** that only 1-axis geometry makes brutal (less room to dodge as you grow more powerful).

## Scope & MVP

**Platforms:** Windows + Linux desktop (Godot 4.6, 2D, Compatibility renderer).
**Team:** solo, intermediate developer.
**Structure:** staged — *v0.1 → v1.0 → post-1.0 growth* (milestone detail in the addendum).

**v0.1 — systems-validation slice (the "MVP").** Tests the as-yet-unvalidated hypothesis: that the *new* build and gamble systems produce the godhood *feel*. It is **not** a re-test of the rescue loop the prototype already proved fun. Lean meta: 2–3 ships, a handful of power-ups, ~1 tier (≈5 waves); capture/rescue/sacrifice included from the start.

**v1.0 — the shipped game (portfolio deliverable).** Full 20-wave / 4-tier campaign, wider power-up pool, multi-tier loops, endless mode, the feat-unlocked fleet — a complete, shippable roguelite.

**Post-1.0 growth — preserved, not committed.** The full fleet, endless depth, and combinatorial growth arrive as additive data, not rewrites; finishing v1.0 is the commitment.

**Definition of done (v1.0):** a complete, shippable build — full 20-wave / 4-tier campaign, endless mode, and the feat-unlocked fleet.

**Out of scope for this brief:** full content lists, mechanic tuning values, and the detailed GDD (all deferred — see addendum).

## Content & Direction

**Setting & narrative (light):** a space-navy / espionage flavor — captured ships hack the enemy mainframe and return with ship specs, justifying why rescues unlock new fleet ships. "Meridian" nods to both the 1-axis geometry (a line through the poles) and the peak/ascent hook. Narrative is flavor, not load-bearing; build-crafters aren't here for lore.

**Art — clean geometric neon-vector.** Chosen because it serves every constraint: achievable for one solo dev (the prototype already shipped readable geometric shapes), maximizes 1-axis lane-readability (essential for reading fire-columns), honors the arcade vector lineage, and enables cheap juice (neon glow, particle bursts, screen-shake on the godhood peak). Touchstones: *Geometry Wars*, *Resogun*, *Nova Drift*.

**Audio — synthwave / arcade-electronic.** Fits the neon-vector look, *Galaga*'s electronic roots, and the power-escalation energy; punchy SFX on hits, pickups, and sacrifice bursts carry the juice as much as the visuals.

**Content scale (orders of magnitude):** 20+ ships in the full fleet (post-1.0); a handful in v0.1; standard + specialty power-up pools; a modifier-wave roster (Swarm / Gauntlet / Bounty and more); a 20-wave, 4-tier campaign. (Full lists deferred — see Scope.)

## Risks

- **1-axis movement-depth risk.** The chassis is the wedge *and* the known weakness — modern players expect more positional expressiveness (the industry abandoned the format for a reason). **Mitigation:** constrained movement makes build and gamble the primary expression of skill and strategy (see Pillar 3). This is the central design bet.
- **Unproven new systems.** Courting-capture, dual-track builds, sacrifice-as-investment, and cross-pollination are unproven in code (only the rescue loop is playtested). **Mitigation:** v0.1 is scoped to validate exactly these; the JS prototype is reference-only and is not ported.
- **Scope vs. solo dev.** The full vision is large. **Mitigation:** staged v0.1 → v1.0 → growth; growth is an architectural possibility, not a commitment; content lists are deferred to keep v1.0 finishable.
- **Godhood-peak tuning.** The fantasy needs builds to reach absurdity; v1.0's multi-wave run must be tuned to hit that peak (a lighter concern at the compressed v0.1 scale).

## Open questions for the GDD

The exact life/health economy model; multi-rescue (multiple docked ships) interaction; captor variety at higher tiers; the full modifier-wave roster; feat-list design.
