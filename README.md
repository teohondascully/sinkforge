# Sinkforge

Sinkforge is a 2D vertical excavation and factory game: bore a shaft, automate the extraction and
routing inside it, haul what you refine back to the surface before the shaft floods, and spend the
yield on a permanent rig that lets the next run go deeper. It is equally, and not incidentally, a
measurement instrument for game design — the entire simulation runs headless and deterministic, so
scripted agents can play it thousands of times and produce falsifiable evidence about whether the
design works, rather than an opinion about whether it might.

**Stage 4 of 7 toward `C001`, the first playable milestone — last updated 2026-08-26.** The build
sequence toward `claims/C001-two-minute-run.md` — a scripted agent completing one bounded run entirely
headless — is ordered and stage-gated (`ONBOARDING.md`). `core/` (stage 1), a stub determinism harness
(stage 2), and `sim/world`+`sim/terrain_gen` (stage 3) landed first. `sim/body` — collision, the
heightfield ground plane, the full forgiveness set (step-up, corner correction, coyote time, jump
buffer) — is stage 4, and its movement acceptance suite is green against a hostile fixed chamber
(`docs/ARCHITECTURE.md` §9). Next: `sim/commands`+`interface` (5), `sim/run`+`meta` (6), and `harness/`
(7) — `first_bore`, the first scripted-agent run through the full interface. `ONBOARDING.md` lists five
more stages after that (items/machines/behaviors/transport, `sim/fluid`, extraction and haul, a minimal
`view/`, then closing `C001` itself) toward the fuller game. Live detail: `docs/WORKING.md` (current
state) and `docs/BRIEF.md` (this session's digest).

## The pivot, and why it's a strength

Until 2026-08-25 this was a persistent-world factory game. It didn't get rewritten on a hunch — it got
measured, twice, independently. A 20-agent structural audit found the simulation layer roughly 72%
compatible with an engine-free, deterministic rewrite, with zero dependency cycles across the entire
script graph (`docs/archive/COMPAT_AUDIT_2026-08-25.md`). A second pass, reading the shipped economy
rather than the code's shape, found the core loop had no continuous demand at the top of its own tech
tree: two of its highest-tier products were dead ends nobody needed more of, and the material meant to
anchor the economy had quietly become a currency standing in for one
(`docs/archive/PIVOT_PLAN_2026-08-25.md`). The architecture was sound. The game built on top of it
wasn't demanding enough of the player to keep being a game. The pivot kept the architecture, most of
the code, and the central asymmetry — down is free, up is powered — and rebuilt the loop around it as
a run-based roguelite with a permanent surface rig: the shape that actually needs a continuous stream
of return trips. Full design reasoning: `docs/GDD.md`.

## What exists, and what doesn't

Real and tested: `core/` (fixed-point arithmetic, a seeded splittable RNG, generational entity IDs),
`sim/world` (the tile grid and material registry), `sim/terrain_gen` (seeded strata generation, cave
carving, ore/coal/iron veins), `sim/body` (kinematics, collision, the sub-pixel heightfield ground
plane, step-up/mantle/corner-correction/coyote/jump-buffer), and the first real check in
`sim/invariants` (a diagnostic guard on `sim/body`'s floor resolution, `docs/adr/0005`). All of it is
engine-free GDScript, verified against a from-scratch reference wherever the algorithm mattered,
mutation-tested throughout — 13 suites, 96 test functions, all green (`.github/workflows/harness.yml`
runs every suite under the real, pinned engine on every push, not only locally).

Scaffolded and not yet built: ten more `sim/` modules (`commands`, `run`, `meta`, `items`, `machines`,
`behaviors`, `transport`, `fluid`, `economy`, `telemetry`) each have a `MODULE.md` stating their
responsibility and boundaries, and zero lines of code. There is no `interface/`, no `harness/`, no
`view/`, no playable build, and no packaged release. Two claims exist (`claims/`) and both are
`BLOCKED`, never measured, because the modules they depend on don't exist yet. None of this is softened
elsewhere in the repository — `docs/WORKING.md` and `docs/BRIEF.md` say
the same thing in more detail, and the claim files carry `BLOCKED` in their own front matter.

## The architecture, and why

The simulation is a pure, deterministic, engine-free library. Everything else — Godot's renderer, a
human player, a scripted agent — is a client of it, through one interface:

```
L4  experiment   claims, sweeps, ablations, reports
L3  harness      scenarios, envelopes, driver, aggregation
L2  interface    observe() and apply(). THE ONLY DOOR into the sim.
L1  sim          the entire game. deterministic. no engine.
L0  core         fixed-point, seeded RNG, generational entity IDs
```

Dependency flow is one-way and lint-enforced (`tools/layer_lint/layer_lint.py`): `L0 ← L1 ← L2 ← L3 ←
L4`, with `view/` and `shell/` hanging off L2 as peers of the agents rather than layered above the sim.

Two invariants carry the whole design and neither is negotiable. A run must complete with no renderer
open, or the research loop this instrument exists to run is dead. And agents and humans enter through
the same door — `observe()`/`apply()` — because different doors would make their numbers incomparable
and the whole instrument unfalsifiable. Full detail: `docs/ARCHITECTURE.md`.

## The method

*No layer may certify all six questions.* That line is the clearest statement of what this project's
evaluation program actually believes, and it belongs here rather than buried in a specification
document. A technical pass can prove a state transition is correct; it cannot certify that the result
is fun. An agent that fails a journey doesn't, by itself, prove the game is broken — the failure might
be the agent's own capability limit, not a defect. So the evaluation program
(`docs/EXPERIENCE_EVALUATION.md`) is deliberately six separate layers: deterministic system checks,
real-engine encounter checks, calibrated agent journeys with actor-validity controls, screenshot-only
criticism from an observer with no code access, counterfactual A/B on a pinned actor and seed, and
human calibration sessions captured through the same interface an agent uses. Each layer answers a
narrower question than the others on purpose, and no single number from any one of them is allowed to
stand in for the rest.

## The claim corpus

Every design assertion the project currently defends is a file in `claims/`: an English statement, the
scenario that exercises it, a metric, a threshold fixed before anything was measured, the current
measured value, and a status. `C001-two-minute-run.md` is the tracer bullet — a scripted agent starts
a run, descends a fresh shaft, smelts one ingot, delivers it to the surface, and the run resolves,
entirely headless, in under 7,200 ticks. It's `BLOCKED`: `sim/run` doesn't exist yet, so there's
nothing to measure. `C002-traversal-over-rubble.md` is narrower and further out — the same 0.92
velocity-efficiency threshold already required over clean geometry, measured instead against terrain
the player just dug, because a controller that only passes on clean floors hasn't actually proven the
resolution-split collision architecture works. It's blocked on `sim/body` and `sim/world`'s heightfield
derivation. Both claims state plainly, in their own "what this does not measure" section, exactly what
passing them would and wouldn't prove — a claim that oversells its own result is a defect in the claim,
not a virtue.

## The gates

Ten structural gates run in CI on every push (`tools/layer_lint/`, `.github/workflows/harness.yml`):

| Gate | What it checks |
| --- | --- |
| `layer_lint.py` | dependency direction between layers is one-way |
| `no_engine_imports.py` | `core/`/`sim/` never touch the scene tree, file IO, the wall clock, unseeded randomness, or several other categories of engine coupling |
| `check_coordinate_naming.py` | every coordinate crossing `sim/world`/`sim/terrain_gen`'s API names which of two grids it's on |
| `check_size_limits.py` | no file over 400 lines, no function over 50 |
| `check_loc_ratio.py` | instrument code isn't outgrowing game code |
| `schema_validator.py` | every data file matches its schema |
| `check_claim_references.py` | every scenario names a claim that actually exists |
| `data_codegen/generate.py --check` | every generated `data/<kind>/generated.gd` matches its YAML source |
| `check_working_freshness.py` | `docs/WORKING.md`'s stated date isn't older than `HEAD`'s own commit |
| `check_project_settings.py` | `project.godot` keeps its load-bearing flags (static typing as a build failure, `DECISIONS.md`'s "Enforcement tripwire #1") — added after a non-headless Godot launch silently stripped it once |

A separate `tests` job (added 2026-08-26, D0047) downloads the exact pinned Godot version this project
develops against and runs every `tests/test_*.gd` suite under it — the gates above are static analysis
over the source tree and answer questions that don't need the engine; the suites answer the ones that
do (determinism, conservation, the movement acceptance thresholds in `docs/ARCHITECTURE.md` §9). Before
this, "all green" above was locally verified only; every suite passing is now a CI fact, not a claim.

Two findings this stage show the gates doing real work rather than performing it. `no_engine_imports.py`
had checked for engine coupling since the project's restructuring, but only against a handful of
hand-picked class names — an audit against Godot's actual class registry found it would have let 276
more engine classes through silently, including something as ordinary as extending `Timer`. It's now
derived directly from that registry (`docs/DECISIONS_LEDGER.md` D0026). Separately, mutation-testing
`sim/terrain_gen`'s safety guards found that two of them survived being deliberately broken under the
project's own full-scale integration test, because the condition each one protects against is rare
enough that a normal run never happens to exercise it (D0024) — a real defect a green suite would not
have caught, found by breaking the code on purpose rather than trusting that it passed. Both are now
`docs/QUALITY.md` §2 rules, not one-off fixes to one file.

## `legacy/`

`legacy/` holds the pre-pivot codebase: read-only, excluded from every build and every gate, tagged in
full at `pre-pivot`. It's kept because the compatibility audit found most of it worth porting, not
rewriting — deleting it to start clean would have thrown that finding away and read, correctly, as a
panic rewrite it wasn't. Files leave one at a time: each commit that moves code out of `legacy/` names
the original path, states what changed and why, and the result has to fit the new layer boundaries,
size limits, and naming conventions or it doesn't leave yet. `legacy/README.md` has the detail.

## Clone size

This is a large clone on purpose. `.git` is 351 MB and the tracked working tree is 332 MB;
`history/` (229 MB, 166 dated screenshots) and `docs/media/` (104 MB, the canonical visual record of
named moments) together account for nearly all of it, and both are tracked deliberately rather than
referenced externally. Eighty-four screenshots from an earlier version of this archive were once
permanently lost during a refactor, which is the entire reason `docs/DECISIONS.md`'s "never destroy a
curated file" rule exists (LOCKED) — a release attachment or an LFS store was considered and rejected
for the same reason a moved file isn't a deleted one: it would trade a strong protection for a weaker
one. `legacy/` itself, the frozen pre-pivot code, adds only 7.3 MB on top of that. Neither `history/`
nor `docs/media/` is read by the game; both carry a `.gdignore` so the engine's import scan skips them.
