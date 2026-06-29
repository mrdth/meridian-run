# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Meridian Run** — a 2D fixed-screen roguelite shooter built in **Godot 4.6** with **GDScript**
and the **Compatibility** renderer (`gl_compatibility`). Built on a *Galaga*-lineage 1-axis
chassis (player locked to a bottom lane, vertical fire-columns) — "Run" in the title means
*roguelite run*, not an endless-runner. Originated from a JS/Canvas prototype;
the prototype is **reference-only** (see gotchas below). Targets Windows + Linux desktop.

## Current state — scaffolding only

There is **no game code yet**: no `.gd` or `.tscn` files, no `addons/`, and `docs/` is empty.
When asked to "match the surrounding code," be aware there is none yet — establish the first
patterns in line with the rules below rather than copying existing ones.

## Read this first: `_bmad-output/project-context.md`

The authoritative implementation rules (65 of them) live in
**`_bmad-output/project-context.md`**. **Read it before writing any game code**, and follow it
exactly. It covers engine-specific gotchas, performance/hot-path discipline, code organization,
testing, and platform/build rules. This file deliberately does not duplicate it — defer to it.

When a rule conflicts with a design intent, flag it to the user (Mrdth) instead of overriding.

## Gotchas that bite if you only read `project.godot`

- **The game is 2D, not 3D.** `project.godot` still carries the engine's 3D defaults:
  `config/features=...Forward Plus` and `3d/physics_engine="Jolt Physics"`. Both are misleading —
  this project uses the 2D physics server (`CharacterBody2D`/`RigidBody2D`/`Area2D`) and the
  Compatibility renderer. Ignore the 3D settings.
- **Do not port the prototype.** JS/Canvas patterns do not transfer: no plain-object "entities"
  (use Nodes/`Resource`), no manual draw loops (use the scene tree + `Node2D`), no `splice`-during-
  iteration. Re-derive every behaviour in Godot idioms. This rule is in project-context.md too.
- **It's a fixed-screen shooter, not a runner.** Despite the name, Meridian Run is a *Galaga*-lineage
  fixed-screen roguelite (1-axis horizontal movement, vertical fire) — not a side-scrolling or
  auto-scrolling endless-runner. "Run" = roguelite run. Do **not** introduce auto-scroll, side-scroll
  parallax, or runner-style one-button input.

## Commands

Godot is available on PATH as `godot` (`/usr/bin/godot`).

```bash
# Open the project in the editor
godot --path . -e

# Run headless (no GUI) — for CI / scripted checks
godot --headless --path .
```

The game is **not yet runnable as a game** — no main scene is defined in Project Settings.

### Testing

Automated tests use **GUT** (Godot Unit Test) — the **committed** test framework for this project.
It is not yet *installed* (no `addons/gut/` yet, since there is no game code); it installs at project
scaffolding. Once present, the CI/pre-commit command is:

```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

Per project-context.md: separate pure logic from Node/scene code so logic can be unit-tested
without instantiating scenes. Tests live under a top-level `tests/` mirroring the domain layout,
named `test_<thing>.gd`.

## Intended architecture

No source tree exists yet, but the target layout (co-located by domain) and all naming
conventions are specified in project-context.md's "Code Organization Rules" section. Key shape:
each system keeps its scenes + scripts + art together under its own folder (`player/`, `world/`,
`enemies/`, `ui/`); `systems/` holds autoloads/singles; `resources/` holds `.tres` data;
`assets/` holds shared/cross-domain art and audio.

## Development methodology

A **BMAD + GDS (Game Dev Skills)** workflow is installed under `.claude/skills/`. There are two
parallel skill sets: `bmad-*` (general software process — PRD, architecture, dev-story) and
`gds-*` (game-tailored — GDD, game architecture, game dev-story, playtest plans). **For game
work, prefer the `gds-*` variants.** Use the `bmad-help` / `gds-*` help skills to choose the
right next step when the user invokes the methodology.
