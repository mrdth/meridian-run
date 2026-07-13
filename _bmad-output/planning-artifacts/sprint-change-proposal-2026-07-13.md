# Sprint Change Proposal — Story 2.7 Repositioning & Currency-Channel Simplification

**Date:** 2026-07-13
**Raised by:** Mrdth (during pre-implementation review of Story 2.7)
**Triggering story:** 2.7 — *Safe-Play vs Rescue Bonus Economy* (status: `backlog`, no story file yet)
**Scope classification:** **Moderate** — backlog reorganization + spec rewording across GDD/epics/decision-log. No code rollback; no completed story touched.
**Mode:** Batch (edit proposals presented together below).

---

## Section 1 — Issue Summary

### Problem statement

Story 2.7's acceptance criteria grant a **currency bonus** at wave-clear (safe-play ~30%, rescue ~25%). Two issues:

1. **Dependency that cannot be satisfied in Epic 2:** there is no currency system yet. `run/run_state.gd` carries `ships` and `score` only — and `score` is explicitly *"display-only (FR49 — score is NEVER spent)"* (`run_state.gd:55`). The debug cheat list defers *"give currency"* as out-of-scope *"systems that don't exist yet"* (`systems/debug.gd:12`). Currency is **Epic 3's domain** — FR49 sits under E3, and Story 3.5 already states *"Currency = wave score converted at the shop (earned per wave + rescue/safe bonuses)."* Story 2.7 as written has **nothing to grant to**.

2. **Design — FR20 and FR27 tangle the reward channels.** FR20 gives *both* outcomes a currency bonus (safe slightly more); FR27 *also* grants rescue a *"currency multiplier and biased odds."* Rescue is thus paid in currency **and** build track, while safe play is paid in currency only — and the 5pp currency spread between them is imperceptible to a player, so the "gamble" barely differentiates the paths.

### When discovered

Pre-implementation review of the next story (2.7), at the close of Epic 2 (2.1–2.6 done). No code has been written for 2.7; no story file exists. Cost of change is at its minimum.

### Evidence

- `run/run_state.gd:5` — *"RunState (seed/currency) is Epic 4 (Story 4-6)"*; fields present are `ships`, `score` only.
- `run/run_state.gd:55` — score is never spent (FR49).
- `systems/debug.gd:12` — *"give currency"* cheat deferred (systems don't exist).
- `epics.md:247` — Epic 3 covers FR49 (currency); `epics.md:626` (Story 3.5) — *"earned per wave + rescue/safe bonuses."*
- `gdd.md:287`, `decision-log.md:32 [Run-32]` — the "~30% vs ~25%" two-bonus model.
- `gdd.md:193`, `epics.md:76` (FR27) — rescue's "currency multiplier + biased odds."

---

## Section 2 — Impact Analysis

### Epic impact

- **Epic 2 (The Gamble):** Still completes as planned. Story 2.7 is **split**, not removed — the E2-owned half (per-wave gamble-outcome *detection*: did the player stay clean or court capture?) stays in E2 as a slimmed, renamed story. E2 delivers no currency. FR20 is now covered **across** E2 (detection) and E3 (currency) — same pattern the plan already uses for FR7 (E2 + E3).
- **Epic 3 (Build Engine):** Absorbs the currency-bonus economy. Story 3.4 (*Wave-Clear Reward — Take-or-Sell*) becomes the natural owner of "wave-clear currency earning + safe-play bonus" — a gap that 3.4/3.5 already implicitly depend on but no story owned. This **fills a gap** rather than adding net scope.

### Story impact

| Story | Change |
|-------|--------|
| **2.7** | Rename → *Per-Wave Gamble-Outcome Signal (Safe vs Courted)*. Slim AC to **detection only** — classify the wave's gamble outcome and emit it via `EventBus`. No currency logic, no `economy_tuning.tres`. |
| **3.4** | Amend AC to own **wave-clear currency earning + safe-play bonus** (pure logic, GUT-tested, reads the E2 signal + `economy_tuning.tres`). Existing take-or-sell card AC unchanged. |
| **2.8** | No change (gamble-gate legibility is unchanged; it can consume the 2.7 signal). |

No completed story (2.1–2.6, all of E1) is touched. No rollback.

### Artifact conflicts (living docs to update)

- **GDD** (`gdds/.../gdd.md`) — 6 locations: P2 pillar (71–72), triple-lock (82), core loop (86), no-gamble baseline (137), acquisition (193), score/currency (197), economy (286–287).
- **Decision log** (`gdds/.../decision-log.md`) — [Risk-6] (29), [Run-32] (32).
- **Epics** (`epics.md`) — FR20 (66), FR27 (76), FR→epic map (195), Epic 3 FR coverage (247), Story 2.7 (519–532).
- **Sprint status** (`sprint-status.yaml`) — rename story key `2-7-safe-play-vs-rescue-bonus-economy` → `2-7-per-wave-gamble-outcome-signal`.
- **Historical docs** (`implementation-readiness-report-2026-07-01.md`, `sprint-change-proposal-2026-07-03.md`, story files 2.1–2.6) — **left untouched** as point-in-time snapshots.

### Technical impact

- None yet (no code exists for 2.7 or any E3 story). The change is spec-only at this date.
- **Forward contract established:** E2 emits `gamble_outcome_recorded(outcome)` (an `enum GambleOutcome { SAFE, COURTED }`); E3 Story 3.4 consumes it. This is the classic emit-now/consume-later seam — E2 produces the classification for free because the gamble FSM + docked-ship resolution (built through 2.6) already determine it.

---

## Section 3 — Recommended Approach

**Selected: Direct Adjustment (Option 1)** — modify stories within the existing plan + reword the spec. No rollback, no MVP change, no new epic.

### Rationale

- The detection half is genuinely E2's (it owns the gamble FSM); the currency half is genuinely E3's (it owns currency). Splitting along that seam is the *honest* dependency boundary, not a workaround.
- Building currency early in E2 (the alternative) would pull an E3 system backward and risk rework when 3.4/3.5 formalize currency earning/conversion. E2's gate is *gamble legibility* (2.8), not economy — currency can wait for E3.
- The design simplification (baseline + single safe-play bonus) **sharpens the gamble** into two distinct reward channels — currency (safe) vs build-track (rescue) — which directly serves Story 2.8's "real, legible decision" gate. A 5pp currency spread was never legible; two different reward currencies is.

### Design guardrail (Mrdth-confirmed, 2026-07-13)

> Rescue's **biased odds toward wing-track power-ups** (FR27) are preserved as a rescue-exclusive reward. They are **not** stripped, weakened, or reallocated to safe-play. Safe-play's reward is currency only; rescue's reward is the build track (wing-ladder growth + biased odds). Both paths stay attractive.

This means FR27 loses only its *"currency multiplier"* phrase (the source of the channel tangle); its biased-odds language stays.

### Open tuning parameter (deferred to Story 3.4)

The prior two-bonus model used ~30% / ~25% (5pp spread). Under the new model (rescue = baseline 0%), the single `safe_play_bonus_pct` value will be **re-baselined during Story 3.4 playtesting** — it is no longer a 5pp gap but the full currency differential between the two paths. No number is prescribed in this proposal; the spec records it as "a tuned wave-clear currency bonus." Placeholder retained as `~30%` only as prior-model provenance, flagged for retuning.

### Effort / risk / timeline

- **Effort:** Low–Medium (spec edits across 4 files; no code).
- **Risk:** Low (no completed work touched; change made at the cheapest possible moment).
- **Timeline impact:** None — E2 closes on the same story count; E3 absorbs work it already implicitly depended on.

---

## Section 4 — Detailed Change Proposals

### A. GDD — `gdd.md`

**A1. Pillar P2 (line 71)**
```
OLD: Every system is a bet: court capture, choose rescue-or-sacrifice, weigh the safe-play bonus against the bigger capture payout.
NEW: Every system is a bet: court capture, choose rescue-or-sacrifice, weigh the safe-play currency bonus against rescue's bigger build-track payout.
```

**A2. Pillar P2 steers (line 72)**
```
OLD: *Steers:* the courting-capture economy, the safe-vs-rescue bonus gap (~30% vs ~25%), the sacrifice burst, the dual-ladder invest-vs-spend, and the discrete survival unit the gamble trades.
NEW: *Steers:* the courting-capture economy, the two reward channels (safe-play currency bonus vs rescue's build-track payout), the sacrifice burst, the dual-ladder invest-vs-spend, and the discrete survival unit the gamble trades.
```

**A3. Triple-lock self-balancing (line 82)**
```
OLD: - **Triple-lock self-balancing** — three independent farm-mitigations overlap by design (hitbox-compounds [Risk-12], safe-play bonus > rescue bonus, threat-relative sacrifice ceiling), so degenerate strategies are pre-empted without patched-on limiters.
NEW: - **Triple-lock self-balancing** — three independent farm-mitigations overlap by design (hitbox-compounds [Risk-12], safe play earns the currency premium while rescue earns none, threat-relative sacrifice ceiling), so degenerate strategies are pre-empted without patched-on limiters.
```

**A4. No-gamble baseline (line 137)**
```
OLD: **No-gamble baseline — Safe play** (avoid capture): no ship change, +safe-play bonus (~30%) vs rescue bonus (~25%).
NEW: **No-gamble baseline — Safe play** (avoid capture): no ship change, +wave-clear currency bonus (rescue earns no currency bonus — it pays via the build track: wing-ladder growth + biased power-up odds, FR27).
```

**A5. Acquisition (line 193)**
```
OLD: Rescued-ship survival → currency multiplier + biased odds toward rescue-oriented power-ups. **Target ~12–15 power-ups acquired by wave 20.**
NEW: Rescued-ship survival → biased odds toward wing-track (rescue-oriented) power-ups — no currency bonus (rescue pays via the build track, not currency; see FR20). **Target ~12–15 power-ups acquired by wave 20.**
```

**A6. Score/currency separation (line 197)**
```
OLD: ...currency is earned per wave + rescue multiplier and fuels builds. Score never spends.
NEW: ...currency is earned per wave (+ safe-play bonus when clean) and fuels builds. Score never spends.
```

**A7. Economy and Resources (line 286)**
```
OLD: - Survive wave → earn currency; rescue-and-survive → earn more (multiplier).
NEW: - Survive wave → earn currency (+ safe-play bonus if clean); rescue-and-survive → no currency bonus, but biased wing-track power-up odds + wing-ladder growth.
```

**A8. Economy and Resources (line 287)**
```
OLD: - **Safe-play bonus (~30%) > rescue bonus (~25%)** — the primary farm-mitigation; safe play yields more currency but no rescued-ship benefits, courting capture yields slightly less currency but full ship benefits.
NEW: - **Safe play earns a wave-clear currency bonus; rescue earns none (baseline)** — currency is the safe-play incentive; the build track (wing ladder + biased power-up odds) is rescue's payoff. This is the primary farm-mitigation: capture-spam farms no currency premium. *(Revised 2026-07-13: collapsed the prior two-bonus model — ~30% safe / ~25% rescue — into baseline + safe-play-only; the single bonus value is re-baselined in Story 3.4.)*
```

### B. Decision log — `decision-log.md`

**B1. [Risk-6] (line 29)**
```
OLD: - [Risk-6] Courting capture inverts Galaga — capture is an opportunity you chase (safe play = smaller safer reward; courted capture + rescue = bigger reward).
NEW: - [Risk-6] Courting capture inverts Galaga — capture is an opportunity you chase (safe play = smaller safer reward, paid in currency; courted capture + rescue = bigger reward, paid in build-track investment).
```

**B2. [Run-32] (line 32)**
```
OLD: - [Run-32] Safe-play bonus (~30%) > rescue bonus (~25%) — primary farm-mitigation.
NEW: - [Run-32] Safe play earns the wave-clear currency bonus; rescue earns none (baseline) — primary farm-mitigation. *(Revised 2026-07-13: two-bonus model collapsed to baseline + safe-play-only; rescue pays via the build track, FR27. Single bonus value re-baselined in Story 3.4.)*
```

### C. Epics — `epics.md`

**C1. FR20 (line 66)**
```
OLD: - **FR20:** **Safe play** (avoiding capture) yields a safe-play bonus (~30%); courting capture/rescue yields a rescue bonus (~25%); safe-play bonus > rescue bonus (the primary farm-mitigation).
NEW: - **FR20:** **Safe play** (avoiding capture) yields a wave-clear currency bonus; courting capture/rescue yields **no currency bonus (baseline)**. Currency is the safe-play incentive; rescue's payoff routes through the build track (FR27 — biased wing-track odds + wing-ladder growth), not currency. The primary farm-mitigation: capture-spam farms no currency premium. *(Split across epics: E2 owns per-wave detection — Story 2.7; E3 owns the currency grant — Story 3.4.)*
```

**C2. FR27 (line 76)**
```
OLD: - **FR27:** Rescued-ship survival grants a currency multiplier and biased odds toward rescue-oriented power-ups; target ~12–15 power-ups acquired by wave 20.
NEW: - **FR27:** Rescued-ship survival grants biased odds toward wing-track (rescue-oriented) power-ups; target ~12–15 power-ups acquired by wave 20. *(Currency multiplier removed 2026-07-13 — rescue no longer grants a currency bonus per FR20; rescue pays through the build track, not currency. Biased odds preserved.)*
```

**C3. FR→epic map (line 195)**
```
OLD: | FR20 | E2 | Safe-play vs rescue bonus |
NEW: | FR20 | E2 + E3 | Safe-play currency bonus (E2: detection, Story 2.7 · E3: currency grant, Story 3.4) |
```

**C4. Epic 3 FR coverage (line 247)**
```
OLD: **FRs covered:** FR7 (generators exception), FR22–FR28 (mechanism), FR46 (select/shop UI), FR49 (currency), FR50 (cheats)
NEW: **FRs covered:** FR7 (generators exception), FR20 (currency half — Story 3.4), FR22–FR28 (mechanism), FR46 (select/shop UI), FR49 (currency), FR50 (cheats)
```

**C5. Story 2.7 (lines 519–532) — rename + rewrite**
```
OLD:
### Story 2.7: Safe-Play vs Rescue Bonus Economy

As a player,
I want playing safe to pay slightly more currency while capture/rescue pays in ship benefits,
So that the gamble is a genuine tradeoff, not a solved optimum.

**Acceptance Criteria:**
- **Given** the player avoids capture all wave (safe play), **Then** wave-clear grants a **safe-play bonus (~30%)**.
- **Given** the player courts capture / rescues, **Then** wave-clear grants a **rescue bonus (~25%)**.
- **Given** the two, **Then** safe-play bonus > rescue bonus (the primary farm-mitigation).
- **Given** bonus values, **Then** they read from `economy_tuning.tres`.

*(FR20)*

NEW:
### Story 2.7: Per-Wave Gamble-Outcome Signal (Safe vs Courted)

As a developer,
I want each cleared wave to record whether the player played safe or courted capture/rescue,
So that the Epic 3 economy can apply the correct currency reward without re-deriving gamble state.

**Acceptance Criteria:**
- **Given** the player avoids capture for the entire wave (no capture event), **Then** the wave records a **SAFE** gamble-outcome.
- **Given** a capture event occurs this wave (regardless of later rescue / sacrifice / absorb / failed-rescue resolution), **Then** the wave records a **COURTED** gamble-outcome.
- **Given** wave clear, **Then** the outcome is emitted via `EventBus` (e.g. `gamble_outcome_recorded(outcome: GambleOutcome)` — an `enum { SAFE, COURTED }`) for the E3 economy to consume.
- **Given** the signal, **Then** it carries **no currency logic** — E2 produces the classification only; the currency bonus is computed in Epic 3 (Story 3.4) from `economy_tuning.tres`.
- **Given** the classification, **Then** it is **pure logic**, GUT-tested (SAFE when no capture occurred; COURTED when a capture occurred).

*(FR20 detection half · FR20 currency half → Story 3.4)*
```

**C6. Story 3.4 (lines 599–615) — append one AC** (existing take-or-sell AC unchanged)
```
NEW AC (append):
- **Given** wave clear, **Then** `RunState` awards wave-clear currency = base + `safe_play_bonus_pct` (from `economy_tuning.tres`) **iff** the gamble-outcome was SAFE (read from the Story 2.7 signal); COURTED waves award base only. The bonus computation is **pure logic**, GUT-tested.

*(adds FR20 currency half · FR49)*
```

### D. Sprint status — `sprint-status.yaml`

**D1. Rename story key (line 76)**
```
OLD: 2-7-safe-play-vs-rescue-bonus-economy: backlog
NEW: 2-7-per-wave-gamble-outcome-signal: backlog
```

---

## Section 5 — Implementation Handoff

**Scope: Moderate** — backlog reorganization + spec rewording. No code; no rollback.

| Recipient | Responsibility |
|-----------|----------------|
| **Mrdth (PO/dev)** | Approve this proposal; confirm the design guardrail (rescue biased-odds preserved) and the open tuning parameter (safe-play % re-baselined in 3.4). |
| **Game Developer (on next `gds-create-story` for 2.7)** | Create the slimmed *Per-Wave Gamble-Outcome Signal* story from the amended epics.md AC. Pure-logic classifier + `EventBus` signal; GUT-tested. |
| **Game Developer (on Epic 3, Story 3.4)** | Implement wave-clear currency earning + safe-play bonus consuming the 2.7 signal; create `economy_tuning.tres`; re-baseline `safe_play_bonus_pct` in playtesting. |

### Success criteria

- All living docs (GDD, decision-log, epics, sprint-status) consistently describe the **baseline + safe-play-bonus-only** model with rescue paying via the build track.
- No doc still references a "rescue currency bonus" or "rescue currency multiplier" as a live spec (only historical point-in-time reports retain the old language, by design).
- Story 2.7's AC contains no currency logic; Story 3.4's AC owns the currency grant.
- `EventBus.gamble_outcome_recorded` is the named seam between E2 (producer) and E3 (consumer).
