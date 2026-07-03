# Story 1.4 — Formation/Dive Feel Findings & Deferred Scope Decision

**Date:** 2026-07-03 · **Author:** dev agent (gds-dev-story) · **Status:** **RESOLVED 2026-07-03.**
Option B was implemented via a `gds-correct-course` pass → decision-log `[Wave-2]` + Sprint Change
Proposal `planning-artifacts/sprint-change-proposal-2026-07-03.md`. The cap-12 concurrency model is
**retired**; the escalating drip model (`per_tick(wave)` hard-capped per tick, no concurrency cap,
dive-loop kept) is live in `formation_spawner.gd`. The findings below are retained for traceability.

> **Purpose:** record the design findings from the 1.4 v1 playtest so a future
> `gds-correct-course` — **without this session's context** — can pick up the deferred scope
> change (option B) if playtest still feels wrong after the rework. Self-contained: cites the
> source specs by file:line.

---

## What happened

Story 1.4 v1 shipped functionally (90/90 GUT tests, clean headless launch) but the **feel is
wrong** and a **scope call was mis-made**. Mrdth's playtest (2026-07-03):

> "Enemies drift slowly in from top, pause ~0.25s, dive very slowly, drop off the bottom and
> never reappear. Nothing here feels like Galaga… I think the 4+N enemies has been
> misunderstood — this refers to multiple formations across a wave. Classic Galaga: 40 enemies
> in 5 groups following spiraling patterns into formation, before any dive mechanic begins."

## Finding 1 — The movement model is broken (implementation bug, not tuning)

**Root cause:** entry/dive movement was built as *chase the sampled curve point at `move_speed`*
(`velocity = (target - pos).normalized() * move_speed`). Because the curve point advances
(`curve_length / duration` px/s) faster than the enemy chases (60/50/80 px/s), the enemy **can
never catch up** — it drifts and never cleanly reaches formation. This is a defect in the
movement model itself.

Compounding it:
- The GDD's **formation-drift** speed (60/50/80, FR43) was reused as the **entry** speed. Entry
  should be fast/snappy; drift slow. They must be separate.
- The v1 entry "curve" was a straight vertical line, not a Galaga spiral.
- Divers exited the bottom and **vanished** (released to pool) — no re-entry loop.

**Fix (in the rework):** exact curve tracking (`velocity = (target - pos) / delta`; with
`collision_mask = 0` the body snaps to the sampled point each frame, traversing the curve
crisply in exactly `entry_duration_s`/`dive_duration_s`). `move_speed` governs only formation
drift. Real spiraling `Curve2D` entry paths. Dive → re-enter top → return to slot loop.

## Finding 2 — Formation choreography was wrongly deferred to 1.8

**Story 1.8** (`epics.md:408`) is a **lifecycle + feel-gate story**, NOT formation choreography.
Its ACs: minimal `wave_controller` (spawn→active→completed-on-timer), HP heal + replay, the
Debug overlay (FR50), the ≥60 FPS playtest gate. Its FRs: FR30, FR47 (juice), FR50 (debug).

Formation-entry choreography and dive behavior belong in **1.4** — AC2 reads: *"fly to
formation rows then execute dive patterns (Galaga-lineage)"*. "Tune it in 1.8" was wrong for
everything except the numeric dial-pass.

## Finding 3 — The `4+N` / cap-12 fork (the deferred decision)

**What the source actually says** (deliberate, not ambiguous):
- **FR30** (`epics.md:82`): "wave N = **4+N enemies (capped at 12)** enter as formation pulses —
  a **concurrency/spawn budget, not a kill quota**."
- **GDD Run Structure** (`gdd.md:166`): "Spawning within a wave = pulsed formations, not a
  streaming swarm [Wave-1]… The **4+N, cap 12** formula is the **concurrency/spawn budget** —
  keeping the 1-axis fire-columns *readable* (P3)… **Galaga's choreographed soul inside
  Brotato's bounded clock.**"

So the literal spec is **≤12 individual enemies** in multiple pulses — deliberately scaled down
from Galaga's ~40 for **readability on the 1-axis chassis**. v1 implemented the literal spec.

**The fork:**
- **(A) CHOSEN:** Keep the cap-12 readability decision; deliver the Galaga *feel* within it
  (spiraling group entry, formation assembly, dive→re-enter→return loops, fixed movement).
  In-scope for 1.4; no doc changes. Rationale: readability is sound for 1-axis; the missing
  Galaga soul is in the *choreography*, not the *count*.
- **(B) DEFERRED:** Revisit the GDD's cap-12 / readability call for closer-to-Galaga density
  (e.g. cap-24, or reframe `4+N` as *formation-groups* of ~8). This is a **design-doc change**
  (FR30 `epics.md:82`, GDD `gdd.md:166`, the P3 readability rationale) and should go through a
  formal `gds-correct-course`.

## Trigger conditions for option B (when to revisit)

Mrdth's lingering concern (2026-07-03), to re-evaluate **after** the rework is in:

> "5 enemies in first wave feels trivial — what happens when those 5 are killed in 15s? Player
> just waits 45s for the wave to end?"

Reframe: the [Wave-1] decision is **timer-based** (survive-to-end, not clear-to-end), so
"empty screen after clearing" is an inherent property. Mitigations: enough density that
clearing-before-timer is hard; OR shorter wave duration; OR continuous in-wave respawning.

The rework's **dive→re-enter→return loop** makes enemies cycle until killed (persistent,
diving threats, not one-pass), raising time-to-clear — so it *partly* addresses this. But it
does **not** change the count.

**→ If, post-rework, wave 1 (5 enemies) still clears fast and leaves dead time, that is the
signal to run option B** (raise the cap / reframe 4+N as formation-groups) via
`gds-correct-course`. The cap-12-vs-Galaga-density question is genuinely Mrdth's call and was
not closed by this session.

## What the rework (option A) delivers

1. **Fixed movement** — exact curve tracking; enemies reach formation crisply (no pursuit lag).
2. **Entry speed ≠ drift speed** — fast entry, slow drift (separate knobs).
3. **Spiraling/swooping `Curve2D` entry paths** (several variants → groups enter from varied
   angles), replacing the v1 straight lines.
4. **Coherent formation groups** — spawn as groups sharing entry timing/shapes ("as one
   disperses, the next enters"), not one-by-one.
5. **Dive → re-enter top → return to formation loop** — the core Galaga rhythm; enemies
   release to the Pool **only on death**, not on diving off-screen.

## Source citations

- `planning-artifacts/epics.md:82` — FR30 (4+N cap-12 spawn budget).
- `planning-artifacts/epics.md:342` — Story 1.4 (AC2 "fly to formation rows then execute dive
  patterns, Galaga-lineage").
- `planning-artifacts/epics.md:408` — Story 1.8 (authored wave + feel gate; FR30/FR47/FR50).
- `planning-artifacts/gdds/.../gdd.md:166` — Run Structure (pulsed formations; cap-12
  readability; "Galaga's choreographed soul inside Brotato's bounded clock").
- `planning-artifacts/gdds/.../gdd.md:247` — Enemy Design ("wave N = 4+N, cap 12").
- `planning-artifacts/gdds/.../decision-log.md` — `[Wave-1]` timed-duration wave (kill-count
  rejected).
- Story file: `_bmad-output/implementation-artifacts/1-4-enemy-types-and-formation-dive-ai.md`
  (v1 Change Log + Completion Notes).
