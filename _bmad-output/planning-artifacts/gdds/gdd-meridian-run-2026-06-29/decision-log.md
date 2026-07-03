# Meridian Run — GDD Decision Log

Record of every design decision, change, and version transition for this GDD.
- **Inherited decisions** — settled in the brief / brainstorming; do **not** re-litigate. Pointed to source rather than re-dumped.
- **GDD-session decisions** — made while authoring this document.
- **Open Questions** — unresolved; must resolve (or explicitly defer) before Finalize.

---

## Inherited decisions (settled — do not re-litigate)

> Sources: `briefs/brief-meridian-run-2026-06-29/.decision-log.md`, `brainstorming-session-2026-06-28.md`. Rationale is one-line; full reasoning lives in the source.

**Core fantasy & positioning**
- Fantasy = "Godhood is the engine; the Gamble (capture/sacrifice) and the Test (1-axis skill/dodge) give it teeth." Glass-cannon god.
- Galaga chassis = a **differentiator, not the identity**. Meridian Run = build-crafter roguelite whose combat chassis is 1-axis fixed-screen Galaga.
- Primary audience = roguelite build-crafters (not shmup veterans).

**Run structure** (brainstorming [Run-26/27/28/37/40 RESOLVED])
- 20-wave campaign / 4 tiers / 5 waves per tier (Brotato model).
- Waves 5/10/15 = modifier waves; wave 20 = FINAL boss (victory gate).
- Endless = frozen build, escalating enemies, no further power-ups.
- Approach A: boss is the gate; endless = victory lap. Tiers + endless coexist.

**Build & risk systems**
- [Econ-8] Shared currency pool (Option A confirmed).
- [Build-9 RESOLVED] Sacrifice model: rescued-ship BUILD = permanent run-long track (never lost); docked SHIP = consumable; sacrifice = spend ship → temporary burst scaling with track. (Losing progress = unfun, rejected.)
- [Build-15] Hybrid docked ship: persistent dual-fighter (firepower + bigger hitbox) AND first-hit absorber.
- [Risk-6] Courting capture inverts Galaga — capture is an opportunity you chase (safe play = smaller safer reward; courted capture + rescue = bigger reward).
- [Ref-11] Dive-timing rescue + formation-turn penalty (kill boss during dive to rescue; kill in formation = ship turns against you).
- [Risk-12] Dual-fighter = larger hitbox → more power = bigger target = harder to dodge (self-balancing).
- [Run-32] Safe-play bonus (~30%) > rescue bonus (~25%) — primary farm-mitigation.

**Meta layer**
- [Meta-20] No meta-currency; pure feat-based unlocks (progression / skill / grind-fallback).
- [Meta-22] Cross-pollination: ship unlocks also seed signature mechanics into the shared power-up pool for all ships. **Mechanism = v1.0; full depth = post-1.0.**
- [Meta-23] Two-tier power-up pool: standard (all ships) + specialty (gated by fleet unlocks).
- [Meta-16] ~80/20 (or 90/10) variety vs raw-power split; raw-power compresses early waves only (Hades pattern).

**Scope & delivery**
- Solo intermediate dev; purpose = portfolio / skill-build (learn Godot deeply by shipping complete game). Commercial NOT required.
- v0.1 = systems-validation slice (validate build+gamble godhood feel — NOT re-proving the rescue loop). 2–3 ships, handful of power-ups, ~1 tier (~5 waves). Capture/rescue/sacrifice non-negotiable from start.
- v1.0 = shipped complete game: full 20-wave/4-tier campaign, wider power-up pool, multi-tier loops, endless, feat-unlocked fleet.
- Post-1.0 = full fleet (20+ ships), endless depth, combinatorial growth (additive data, not rewrites).

**Direction**
- Art = clean geometric neon-vector; audio = synthwave/arcade-electronic; narrative = light flavor only.
- JS prototype = reference-only and is NOT ported (Godot idioms only).
- Tuning values were explicitly deferred from the brief to the GDD — prototype numbers are a starting baseline, not final.

---

## GDD-session decisions

- **2026-06-29** — GDD workspace created at `planning-artifacts/gdds/gdd-meridian-run-2026-06-29/`. Skeleton + this log persisted; section bodies to be pre-populated from extracts and walked. *(pending game-type confirmation + working-mode choice from Mrdth)*
- **2026-06-29 — Game-type confirmed:** roguelike/roguelite primary (high complexity) + shooter chassis (fixed-screen). Genre section scaffolded with roguelite subsections primary, shooter-chassis subsections folded in.
- **2026-06-29 — Game Pillars confirmed (3).** P1 Godhood (power-escalation), P2 The Gamble (push-your-luck), P3 The Test (1-axis skill/dodge). Wording accepted as proposed. Cut-tested: each removal breaks the game. Orthogonal: accumulation / decision / execution. **Cross-pollination explicitly preserved as a load-bearing design principle (under P1 + meta layer) — NOT demoted by staying at 3 pillars.** Underdog-rescuer retained as a guardrail under P3.
- **2026-06-29 — Life & Health Economy resolved (Ships × HP model).** Two layered resources: **Ships** = run economy (start 3 / cap 5, the gamble unit, gained only externally; loop is ship-neutral or ship-negative — never farmed) and **HP** = per-ship wave-survival buffer (base 3, grows via build, **full heal every wave**). Damage flat: 1 standard / 2 heavy-rare-telegraphed; i-frames 1s. **Capture = −1 ship, bypasses HP, respawn full HP; once per wave, clean-only** (captor tractors only when no docked ship; special waves excepted). **Clean/docked tradeoff** = central within-wave decision (clean: gamble-on + small hitbox; docked: capture-immune + bigger hitbox [Risk-12] + dual-fighter firepower) — serves all 3 pillars. **Docked-ship resolution:** absorb next fire-hit (−1) / sacrifice→burst (−1) / keep→regain (net 0) / failed-rescue→ship-turns-enemy [Ref-11] (−1). Safe-play baseline ~30% bonus > rescue ~25%. *Rationale:* Mrdth's Point 2 exposed the loop as net-zero/negative → ships only enter externally (retired the "banking above 3" idea); Points 1 & 3 → clean-gate + one-capture-per-wave eliminates multi-capture run-death AND caps docked ships at 1 (multi-rescue stacking removed). *Full heal every wave* (Mrdth tweak) → HP is within-wave; tier-cap floor re-purposed to **+1 HP cap** (permanent per-wave buffer growth). **Open Q#1 & Q#5 RESOLVED.**
- **2026-06-29 — Seed determinism resolved.** Deterministic seeded generation (same seed → same wave composition + modifier selection; not a frame-exact replay — player timing varies). Procedural = wave composition [Var-33] + modifier selection [Var-34]; authored = wave-20 boss, captor AI, enemy stats. **v1.0: under-the-hood only** (reproducible/debuggable, feature-ready); daily-challenge + shareable seed codes + leaderboards = post-1.0. Low cost — project-context already mandates seeded RNG. **Open Q#7 RESOLVED.**
- **2026-06-29 — Godhood-peak curve + sacrifice ceiling resolved (shape; exact numbers = v1.0 playtest).** Curve targets the **player-power : enemy-threat ratio**: compounding build phase (waves 1–20, power outpaces threat), **peak at the final boss (~waves 17–20)**, **inverted endless** (frozen build vs escalating threat = the Test). Tuning knobs: acquisition rate/wave, synergy multiplicativity, enemy scaling/tier, tier-cap spikes. **Sacrifice-burst ceiling = threat-relative** (Mrdth) — scales against current-wave enemy HP/threat, so always a useful tide-turner / never an insta-win regardless of track investment; reinforced by buff-not-nuke (no screen-clear guardrail) + −1 ship cost + one-sacrifice-per-wave. **Open Q#3 & Q#4 RESOLVED** (shape; exact values deferred to v1.0 playtest per brief).
- **2026-06-29 — GUT committed as the test framework.** GUT (Godot Unit Test) is the decided/committed test framework (no longer "planned, not yet installed"). Installs at project scaffolding (Epic 1) under `addons/gut/`; not yet present since there is no game code. Updated CLAUDE.md Testing section + GDD Technical Specifications (Testing subsection + Assumptions). project-context.md already called GUT "the committed framework."
- **2026-06-29 — "Runner" label corrected to fixed-screen roguelite shooter.** CLAUDE.md project line ("2D runner game" → "2D fixed-screen roguelite shooter") + new clarifying gotcha; project-context.md input-handling line ("for a runner" → "for a fixed-screen action game") + a Genre bullet in Tech Stack. "Meridian Run" = roguelite *run*, not an endless-runner; do not introduce auto-scroll / side-scroll / one-button runner input. (The design sources were always a fixed-screen 1-axis shooter; the CLAUDE.md label was stale.)
- **2026-06-29 — Finalize pass: input reconciliation + discipline validation (two subagents).** Applied autofixes: added **Risks section** (incl. the central 1-axis-movement-depth design bet — the biggest dropped intent); fixed **engine-implementation leakage** (Controls, Tech Specs, Epic 1 In-list rewritten as WHAT-specs, not Godot primitives); reframed **docked-ship resolution** (Absorb = passive consequence of holding per [Build-15], not an active choice) and reconciled the **rescued ship's dual nature** (permanent build track + consumable docked fighter); broadened underdog-rescuer to a *mechanic* guardrail; added triple-lock self-balancing principle, art "build-crafter over shmup-purist" philosophy, captor onboarding cadence + entering state, sacrifice opportunity-cost anti-spam rationale, [Risk-13] reserve lever, bracketed-ref legend, no-multi-dock statement. Added **baseline values** tagged playtest-tuned (move speed ~320 px/s; tier scaling +30/+60%; endless +10%/wave; synergy mult-over-current ~8–12× DPS at boss; economy 3-choose-1 + shop-of-4 + ~12–15 by wave 20; captor HP +50%/tier). **Open design calls for Mrdth:** score purpose (proposed display-only/separate) + cross-pollination trigger (proposed on-fleet-unlock). GDD → v0.3.
- **2026-06-29 — Finalize COMPLETE.** Mrdth confirmed both open design calls (both matched his brainstorming intent): **score = display-only, separate from currency** (not score-as-currency); **cross-pollination triggers on fleet unlock** (one signature = one shared-pool entry for all ships). `[ASSUMPTION]`/`[NOTE FOR DESIGNER]` tags removed; both are now firm decisions in the body. Remaining open questions are all content-breadth (deferred to post-systems brainstorm) — nothing phase-blocking. GDD v0.3 → **v1.0-draft**. Finalize steps: decision-log audit ✓ · input reconciliation ✓ (subagent) · discipline validation ✓ (subagent, leakage fixed) · open-items review ✓ · polish/doc-standards = none configured (skip) · narrative handoff = N/A (no genre-guide narrative flag; narrative is light flavor) · external handoffs = none configured. **GDD ready for `gds-game-architecture`.**
- **2026-06-30 — Wave structure resolved: timed-duration + pulsed formations (kill-count rejected) [Wave-1].** Surfaced as a latent gap during UX planning — the GDD named wave *composition* (`4+N cap 12`) and (downstream) a wave FSM state `cleared`, but never stated the **termination condition**. **Decision:** a wave ends on a **fixed, data-tuned timer** (Brotato-clock), **not** when cleared; within the duration, `RunGenerator` emits a **spawn schedule** of **formation pulses** (Galaga-lineage enter→form→dive), and `4+N cap 12` is a **concurrency/spawn budget, not a kill quota**. *Rationale:* timed is the only model that (a) gives a **bounded, predictable run length** — a 20-wave run lands ~25–45 min (a feel *guideline*, not a hard cap; Mrdth confirmed 20–30 was gut-feel and ~45 is acceptable; endless excluded), (b) preserves the godhood **duration** (P1 — the clock is the ruler power is measured against; kill-count shrinks late waves and shrinks the peak window), (c) guarantees the captor FSM its full gamble runway + a predictable *Keep*-outcome horizon (P2), (d) keeps the [Risk-12] docked-hitbox cost honest for the full wave (P3 — kill-count lets strong builds dodge the cost via short exposure), and (e) is the only way the **Gauntlet** modifier ("dense fire, few foes") works as a dodge test. *Rejected:* kill-count/clear (Galaga-authentic) — unbounds run length, truncates the captor gamble under strong builds, lets power dodge the hitbox cost, self-defeats Gauntlet, and its "waves get longer as you progress" premise is already negated by `cap 12` (counts flatten at wave 8) plus the removed per-wave boss (the prototype's clear-condition was boss-gated). Wave duration = primary run-length/pacing dial, tuned in E3/E4 playtests. **Downstream propagation APPLIED 2026-06-30** in `planning-artifacts/epics.md`: FR30 + Stories 1.4/1.8 reframed as spawn budget over the wave duration; Story 4.2 `RunGenerator` output = spawn schedule (formation pulses + timings); Story 4.3 FSM state `cleared`→`completed`; Story 4.4 win-condition = timer expiry. The colloquial "wave clear" reward terminology (FR22 etc.) is left as-is (= "wave completed").
- **2026-07-03 — Spawn model corrected: escalating pulsed formations (retires cap-12 concurrency) [Wave-2].** Triggered by Story 1.4 playtest (correct-course; see `implementation-artifacts/1-4-formation-feel-findings.md` + `planning-artifacts/sprint-change-proposal-2026-07-03.md`). **Decision:** retire the `4+N, cap 12` on-screen concurrency cap and its P3 readability rationale from [Wave-1]; replace with an **escalating drip** model — formation pulses recur every `drip_interval_s` for the whole wave, each spawning `per_tick(wave) = min(per_tick_base + ⌊wave × per_tick_growth⌋, max_per_tick)` enemies (wave-scaled, **hard-capped per tick** as a performance guardrail), **NO concurrency cap**; enemies dive-loop (cycle until killed), so pressure escalates as pulses accumulate. *Rationale:* (1) a fixed cap is a **ceiling an 8–12× godhood build trivializes** (late-game threat — Mrdth: "12 enemies at wave 17+ is no real challenge"); (2) **timer-termination ([Wave-1]) structurally requires replenishment** — a fixed batch clears-fast-then-waits, so cap-12 + one-pass spawn was doomed by the timer combo, not by readability; (3) faithful to the cited **Brotato** model (continuous escalating spawns), which cap-12 diverged from. The per-tick cap bounds spawn *rate* (worst-case entities = `wave_duration / drip_interval × max_per_tick`, perf-gate-verified), NOT on-screen count. *Modifier re-anchoring:* **Swarm** = 2× `per_tick` (or halved `drip_interval`); **Tier-2 "denser formations"** = raised `per_tick` scaling (both were defined relative to the retired cap). *Readability (P3)* demoted from a spawn-cap driver to a playtest watch-item. **Downstream propagation APPLIED 2026-07-03:** GDD `gdd.md:166`, FR30 `epics.md:82`, Story 1.4 AC3 (epics + story file); `formation_spawner.gd` rewritten to the drip model. Ripples (later epics, not blocking 1.4): `epics.md:757` wording + Epic-4 `RunGenerator` contract (spawn schedule = recurring per-tick-capped pulses) + Difficulty Swarm/Tier references.

---

## Open Questions

> Must resolve (or explicitly defer to a named phase) before Finalize.

1. ~~**Life/health economy model**~~ ✅ RESOLVED 2026-06-29 — Ships × HP model (see GDD-session decisions). Ships (start 3/cap 5) = run economy; HP (base 3, full heal/wave) = within-wave buffer; capture = −1 ship clean-only once/wave; clean/docked tradeoff; docked ship resolves absorb/sacrifice/keep/failed-rescue.
2. **Game Pillars wording** — fantasy resolution maps to ~3 pillars (Godhood / Gamble / Test) but not stated as steering pillars. Confirm count + wording.
3. ~~**Sacrifice-burst late-run compounding ceiling**~~ ✅ RESOLVED 2026-06-29 — threat-relative ceiling (scales vs current-wave threat); buff-not-nuke + ship-cost + one-per-wave brakes. Exact cap = v1.0 playtest.
4. ~~**Godhood-peak tuning curve**~~ ✅ RESOLVED 2026-06-29 — compounding build phase, peak at final boss (~waves 17–20), inverted endless; targets power:threat ratio. Exact numbers = v1.0 playtest.
5. ~~**Multi-rescue balance**~~ ✅ RESOLVED 2026-06-29 — one capture/rescue/dock per wave (clean-gate + per-wave cap) means max 1 docked ship at a time; stacking removed. The single docked ship's bigger hitbox ([Risk-12]) is the within-wave cost.
6. **Cross-pollination balance** — how OP can hybrid builds get; synergy needs both an engine and a brake.
7. ~~**Seed determinism policy**~~ ✅ RESOLVED 2026-06-29 — deterministic seed; v1.0 under-the-hood, daily/shared-seed UX post-1.0.
8. **Modifier-wave roster** — Swarm/Gauntlet/Bounty named + "and more." Scope the v1.0 roster.
9. **Captor variety at higher tiers** — open run-variety question (decoupled from meta model after mainframe-hack clarification).
10. **Feat-list design** — three feat types defined (progression/skill/grind); actual feats not enumerated.
11. **Content-breadth enumeration** — full fleet roster, specialty power-up pool, formation types. ⏳ Deferred to dedicated post-systems brainstorm (per brief) — not blocking this GDD's structure, only its content breadth.
