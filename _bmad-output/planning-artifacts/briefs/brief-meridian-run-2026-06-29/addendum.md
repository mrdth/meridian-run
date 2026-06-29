---
title: "Meridian Run — Game Brief Addendum"
status: draft
created: 2026-06-29
updated: 2026-06-29
purpose: "Brief-overflow detail + pointers to deeper source docs. Carries scope-milestone granularity and points to where the full design detail resides."
---

# Addendum — Meridian Run Game Brief

Holds detail that belongs but does not fit a 1–2-page brief, plus pointers to the source
documents where full design depth resides.

## Scope milestones (detail behind "Scope & MVP")

### v0.1 — systems-validation slice (the "MVP")
- **Goal:** see brief §Scope & MVP — validates that the new build and gamble systems produce
  the godhood *feel*, not a re-test of the already-playtested rescue loop.
- **Lean meta:** 2–3 ship types · a handful of power-ups · ~1 tier (≈5 waves).
- **Capture/rescue/sacrifice included** from the start (non-negotiable).
- **Power curve (delta):** compressed so a 5-wave run still *feels* the compounding, even if
  "unbalanced" by full-game standards — acceptable at v0.1.

### v1.0 — shipped game (portfolio deliverable)
- Full **20-wave campaign / 4 tiers**; tier-cap is a modifier or mini-boss; **wave-20 final
  boss** is the victory gate.
- Wider **power-up pool** (standard + specialty).
- **Multi-tier difficulty loops** (beat a tier's wave 20 → unlock a harder 1–20 loop);
  **endless mode** (frozen build, escalating enemies — the "how far can I push it" test).
- **Feat-unlocked fleet** — the core ship variety (variety > raw power).

### Post-1.0 growth — preserved, not committed
- Full fleet, cross-pollination *depth*, captor variety, expanded modifier and feat roster.
- Growth arrives as additive data (data-driven resources), not rewrites — see
  `project-context.md`'s code-organization rules; v1.0's systems must be built open to allow it.

## Pointers (where the full design detail resides)

- **Brainstorming** — ~40 system-ideas, 6 themes, 7 combinations; the complete spine across
  all 8 pillars (hook → loop → twist → build → risk → meta → run → variance):
  `_bmad-output/brainstorming-session-2026-06-28.md`
- **Playtested core loop + mechanics + design principles** (1-axis geometry, no screen-clearing
  bombs, underdog-rescuer identity): `_bmad-output/planning-artifacts/prototype-1-design-snapshot.md`
- **Candidate comparison + "why not the others"** (rejected alternatives — Asteroids / Breakout /
  Robotron / Tempest) + novelty scan: `_bmad-output/planning-artifacts/research/domain-roguelite-arcade-base-research-2026-06-27.md`
- **Engine & technical constraints** (Godot 4.6, 2D, performance, code organization, testing,
  platform/build): `_bmad-output/project-context.md`
- **Full reasoning + rejected alternatives for every brief decision:** `.decision-log.md`
  (sibling file in this folder).

## Deferred: content-breadth enumeration

The full fleet list, specialty power-up pool, modifier roster, formations, and feat list are
**not this brief's job** — planned as a dedicated content-breadth brainstorm *after* initial
systems implementation (per the brainstorming's synthesis note and Mrdth). The brief and the
GDD's first pass state only orders of magnitude; enumeration follows once systems exist to hang
content on.
