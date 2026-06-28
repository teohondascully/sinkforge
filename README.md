# Sinkforge

A 2D side-view factory automation game where **gravity is the conveyor belt.** Dig downward, discover exotic materials at each depth layer, and engineer vertical production chains that cascade resources from the surface to the depths. Part Factorio, part idle progression.

**Engine:** Godot 4.6.2 (GDScript) · **Target:** Steam (Windows/Mac/Linux) · **Dev:** macOS / Apple Silicon

---

## For Assistant Code: Start Here

1. **Read `ASSISTANT.md` first** — it's the project memory anchor: current phase, locked decisions, doc pointers, and per-session hooks.
2. Then read `docs/GDD.md` (design bible) and `docs/DECISIONS.md` (why things are the way they are).
3. Check `docs/SESSION_LOG.md` (last 3 entries) and `docs/ARCHITECTURE.md` for current state before writing code.
4. Current task: see `prompts/prototype-1.md`.

## Repo Structure

```
sinkforge/
├── ASSISTANT.md              # Memory anchor — read every session
├── README.md             # This file
├── docs/
│   ├── GDD.md            # Game design bible
│   ├── DECISIONS.md      # Decision log (most recent wins on conflict)
│   ├── ROADMAP.md        # Playable-milestone progress bar
│   ├── ARCHITECTURE.md   # Technical source of truth (update as built)
│   ├── MATERIALS.md      # Material/machine/recipe catalog
│   ├── LAYERS.md         # Depth layer definitions
│   ├── SESSION_LOG.md    # Dev diary (append every session)
│   └── PLAYTEST_NOTES.md # Honest feelings from playing builds
├── prompts/
│   └── prototype-1.md    # Prototype 1 build prompt
├── src/                  # (created during setup)
├── assets/               # (created during setup)
└── scenes/               # (created during setup)
```

## Core Architectural Principles (non-negotiable)

1. **Data-driven everything.** Machines, materials, recipes, layers are Godot custom Resources consumed by a generic engine. Adding content = editing data, not writing classes.
2. **Abstract flow is source of truth.** Production math runs through rate-based flow; discrete falling-item sprites are cosmetic only and never drive resource counts.
3. **Every milestone is playable.** Infrastructure serves a playable goal. Admin tooling grows as editor plugins on demand, never speculatively.
4. **Simulation is node-free; visuals are a separate pooled layer.** A factory sim becomes thousands of simple entities, which Godot nodes handle poorly. See `docs/ARCHITECTURE_PRINCIPLES.md` for the full anti-rot charter (fixed-tick sim, composition, typed GDScript, batched rendering).

## Source-of-Truth Hierarchy (on conflict)

1. `docs/DECISIONS.md` (most recent decision wins)
2. `docs/GDD.md`
3. `ASSISTANT.md`
4. `docs/ARCHITECTURE.md`
5. Everything else
