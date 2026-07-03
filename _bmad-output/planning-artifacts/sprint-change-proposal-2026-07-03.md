# Sprint Change Proposal — Story 1.4 Formation Density

**Date:** 2026-07-03 · **Trigger story:** 1-4-enemy-types-and-formation-dive-ai
**Status:** Direction **approved by Mrdth (2026-07-03)** — Idea 1 + performance guardrail. Concrete edits below, **pending apply-approval** before GDD/epic/story files are modified.
**Branch:** `1-4-formation-rework` (v1 `82f235d` → option-A rework `ed31bab` → this change, uncommitted).

---

## 1. Decision

**Retire the `4+N, cap 12` on-screen concurrency cap and its P3 readability rationale.** Replace with an **escalating pulsed-formation spawn model** (Idea 1), keeping the dive-loop, with a **per-tick spawn cap** (wave-scaled + hard-capped) as the performance guardrail.

**Why** (Mrdth's call, recorded so it's a documented change, not silent):
1. A fixed cap is a *ceiling* an 8–12× godhood build trivializes → late-game threat evaporates (the "12 enemies at wave 17+ is trivial" problem).
2. **Timer-termination ([Wave-1]) structurally requires replenishment** — a fixed batch clears-fast-then-waits. This is the real root cause, stronger than "readability."
3. The drip model is faithful to the cited **Brotato** inspiration (continuous escalating spawns), which cap-12 diverged from.

## 2. The Spawn Model (precise spec)

- Formation pulses recur every **`drip_interval_s`** for the whole wave duration.
- Each pulse spawns **`per_tick(wave) = min(base + ⌊wave × growth⌋, max_per_tick)`** enemies:
  - **wave-scaled** (pressure grows with wave) and **hard-capped per tick** (the performance guardrail).
  - Example tuning *(playtest)*: `base=2, growth=0.5, max_per_tick=6` → w1≈2, w5≈4, w10+=6 per pulse.
- **No on-screen concurrency cap.** Enemies enter (formation-group choreography) → form → dive → **re-enter and cycle until killed** (the dive-loop). Pressure **escalates** as pulses accumulate.
- **Performance guardrail** = the per-tick hard cap bounds spawn *rate*; worst-case total spawned = `(wave_duration / drip_interval) × max_per_tick`, verified at the 1.8 perf gate. (No concurrency cap by design.)
- Variant mix scales by tier (unchanged). **Swarm** modifier re-anchored → 2× `per_tick` (or halved `drip_interval`). **Tier-2** "denser formations" → raised `per_tick` scaling.

## 3. Concrete Edits (old → new)

### GDD — `gdd.md:166` (Run Structure, spawning bullet)
**OLD:** "...The `4+N, cap 12` formula is the **concurrency/spawn budget, not a kill quota** — keeping the 1-axis fire-columns *readable* (P3) while sustaining pressure for the whole duration. Galaga's choreographed soul inside Brotato's bounded clock."
**NEW:** "...Pulses fire every `drip_interval_s`; each spawns `per_tick(wave) = min(base + ⌊wave·growth⌋, max_per_tick)` enemies — **wave-scaled and hard-capped per tick (a performance guardrail), with no on-screen concurrency cap**. Each pulse enters → forms → dives → **re-enters and cycles until killed** (Galaga-lineage loop), so **pressure escalates** across the wave (timer-terminated waves *require* replenishment — a fixed batch clears-fast-then-waits). The per-tick cap bounds spawn *rate*, not count; worst-case entities (wave_duration × per-tick cap) are verified at the perf gate. *Galaga's choreographed soul inside Brotato's bounded clock.* *(2026-07-03 [Wave-2]: retires the prior `4+N, cap 12` concurrency cap and its P3 readability rationale — a cap is a ceiling a godhood build trivializes.)*"
*(Also retitles the bullet "pulsed formations, not a streaming swarm" → "**escalating pulsed formations**".)*

### Epics — `epics.md:82` (FR30)
**OLD:** "...wave N = 4+N enemies (capped at 12) enter as **formation pulses** — a concurrency/spawn budget, **not a kill quota**..."
**NEW:** "...an **escalating spawn schedule over the wave's fixed duration** [Wave-1][Wave-2]: formation pulses recur every `drip_interval_s`, each spawning `per_tick(wave)` enemies (wave-scaled, **hard-capped per tick**; **no concurrency cap**) — enemies enter → form → dive → re-enter and cycle until killed (Galaga-lineage loop), so pressure escalates as pulses accumulate. *(Retires the prior `4+N, cap 12` concurrency cap.)*"

### Story 1.4 — AC3
**OLD:** "Given wave N, Then it spawns 4+N enemies (capped at 12) as formation pulses across the wave's duration — a spawn budget, not a kill quota (FR30; the wave ends on a timer [Wave-1])."
**NEW:** "Given wave N, Then formation pulses recur every `drip_interval_s` across the wave's duration, each spawning `per_tick(N)` enemies (wave-scaled, **hard-capped per tick**; no concurrency cap) — enemies enter → form → dive → re-enter and cycle until killed, so pressure escalates as pulses accumulate (FR30; timer-terminated [Wave-1][Wave-2])."

### Decision log — new `[Wave-2]` entry (`gdds/.../decision-log.md`)
Records: retires `4+N, cap 12` + P3 readability; rationale (godhood ceiling + timer-replenish); new model spec; Swarm/Tier-2 re-anchoring. *(See §2.)*

### Code — `world/formation_spawner.gd` (Story 1.4 scope)
Replace the cap-12 budget + `group_size` pulse model with the periodic drip: a pulse every `drip_interval_s`, each spawning `per_tick(wave)` enemies (wave-scaled, hard-capped), ticking for the **whole wave duration** (not until a budget is spent). Keep the formation-group entry choreography + the dive-loop. New tunables: `drip_interval_s`, `per_tick_base`, `per_tick_growth`, `max_per_tick`. Update `tests/world/test_formation_spawner.gd` accordingly (wave-scaled per-tick counts, multi-pulse escalation, the hard cap).

## 4. Ripple Effects (note for later; not blocking 1.4)
- **Architecture / `epics.md:757`**: "formation pulses (4+N cap 12 spawn budget)" → reword to escalating drip.
- **Epic 4 (`RunGenerator`, Stories 4.2/4.4)**: emits the spawn schedule; contract changes from "spawn budget" → "recurring pulse schedule with per-tick cap." Addressed when 4.x lands.
- **Difficulty (`gdd.md:206`)**: Swarm/Tier-2 re-anchored to per-tick (above).

## 5. Handoff
**Scope: Minor–Moderate.** All edits executable by the Developer agent (me): GDD `166` + FR30 + Story 1.4 AC3 + decision-log `[Wave-2]` + `formation_spawner.gd` rewrite + test updates, on branch `1-4-formation-rework`. No new epics/stories. Success criteria: GDD/FR30/Story consistent with the drip model; spawner implements it; GUT green; headless launch shows escalating pulses with no concurrency cap and no perf spike.
