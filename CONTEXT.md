# CONTEXT

**Read this first, every session, before anything else.** If you read only one file in this repository, read this one. It is kept under 250 lines deliberately. If it grows past that, something belongs in `docs/` instead.

---

## What this is

**Sinkforge is a factory game with a roguelite structure and an idle game's progression curve.** 2D, side-view, vertical.

The player bores a shaft from a permanent surface rig, builds extraction and routing infrastructure inside it, hauls refined material back up, and surfaces before the shaft floods. The shaft is lost. The material upgrades the rig, which extends and deepens the next run. Two factories exist: the shaft factory is disposable and different every run, the surface rig is permanent and optimized across dozens.

Three things follow that are easy to miss and expensive to get wrong:

- **The terrain is the factory.** The shape you dig is the routing. This is why roguelite structure works here and does not work for factory games generally: procedural geology rewrites your layout every run, where in a game with a flat infinite plane it would not change your build at all.
- **No global multipliers. Ever.** Factory games are ratio puzzles; idle games are number puzzles. Every upgrade is a new capability or a changed constraint, never a rate multiplied. See `docs/GDD.md` §2 and §5.
- **Down is free, up is powered.** The central asymmetry. R1 below.

It is also, and equally, a **measurement instrument for game design**. The game is playable end to end with no renderer, so that automated agents can play it thousands of times and produce falsifiable evidence about whether the design works. Both halves are the product. Neither is a wrapper around the other.

This is a portfolio centerpiece. The standard is: a senior staff engineer reads this repository for ten minutes and comes away impressed. That standard applies to the repository as an artifact, not only to the code inside it.

---

## The one-sentence architecture

**The simulation is a pure, deterministic, engine-free library. Everything else, including Godot, is a client of it.**

```
L4  experiment   claims, sweeps, ablations, reports
L3  harness      scenarios, envelopes, driver, aggregation
L2  interface    observe() and apply(). THE ONLY DOOR into the sim.
L1  sim          the entire game. deterministic. no engine.
L0  core         fixed-point, seeded RNG, IDs

view/ and shell/ are clients of L2, peers of the agents. Never above L1.
```

Dependency flow is one-way and lint-enforced: `L0 ← L1 ← L2 ← L3 ← L4`, with `view` and `shell` hanging off L2. Any cycle is a build failure.

Two invariants carry the whole design:

1. **A run must complete with no renderer.** If finishing a run needs a window, the research loop is dead.
2. **Agents and humans enter through the same door.** Different doors make agent runs and human runs incomparable, and every number the instrument produces becomes unfalsifiable.

Full detail: `docs/ARCHITECTURE.md`.

---

## The unit of work is a claim

Every design assertion in this project is a file in `claims/`: an English statement, the scenario that tests it, a metric, a threshold, the current measured value, and a status.

CI runs the claims. A change that breaks one fails the build and names it. Design regressions become as visible as code regressions.

**The claim corpus only grows.** Every bug a human finds becomes a scenario and stays forever.

Two rules that follow from this, and they are the most important process rules in the repository:

- **No harness surface without a claim it serves.** Every check must trace to a claim ID. This is the direct fix for the failure mode that produced the previous codebase, where instrumentation grew 90% in five days while the game grew 9%.
- **Instrument LOC may not exceed game LOC.** Enforced in CI. When it does, the next unit of work is game.

Format and workflow: `docs/CLAIMS.md`.

---

## The four design rules

These are invariants. A proposal that violates one is a design change, not an implementation detail. Push back if you find one that cannot be implemented cleanly.

**R1. Down is free, up is powered.** Gravity moves material downward at zero cost, through excavated space. All upward movement consumes fuel per unit per meter, forever. Transport cost is a first-class simulated quantity, not a rate cap.

**R2. Deep material is required, not more valuable.** No exponential per-unit value by depth. Tier-N upgrades require tier-N material *and* large quantities of tier-1 material. The exponential lives in quantity required.

**R3. Run length is a purchased resource.** Rig pump capacity determines how long a shaft holds before flooding. Run duration derives from rig state, never a constant.

**R4. Every tool tier removes one skill and introduces another.** Upgrades change the shape of the problem, not the numbers.

Rationale, consequences, and the dead ends already ruled out: `docs/GDD.md`.

---

## Repository map

```
CONTEXT.md            this file
README.md             public-facing. what the project is.
ONBOARDING.md         the session brief. paste as message one.
claims/               one file per design assertion. the unit of work.
core/                 L0
sim/                  L1  (one dir per module, each with MODULE.md)
interface/            L2
harness/              L3
experiment/           L4
view/                 renderer, client of L2
shell/                entry points, scene flow, save IO
data/                 all content as declarative text. no binary resources.
scenarios/            declarative test fixtures. each names a claim.
tools/                lints, validators, report generators
tests/                unit, property, scenario, golden
docs/                 normative documents only. see docs/README.md
docs/adr/             numbered decision records
docs/archive/         superseded documents, headed and dated
legacy/               the pre-pivot codebase. read-only. excluded from build.
```

`legacy/` exists so that porting has provenance. Nothing in it is on the build path. Files leave `legacy/` one at a time, under the gates in `docs/QUALITY.md`, and the commit that moves a file says why.

---

## Context discipline

The primary implementers here are agents with bounded context. These are architectural constraints, not style preferences.

- **The 5-file rule.** Any task must be completable by reading five files totalling 1,500 lines or fewer. If a task needs more, the module boundaries are wrong. Report that rather than working around it.
- **`MODULE.md` in every module**, 60 lines maximum: purpose, public API, invariants, dependencies, consumers, tick phase, and the three things that have bitten people here. Read the `MODULE.md` for dependencies, the implementation only for the module you are editing.
- **One concept per file. Filename equals concept.** No file named `utils`, `helpers`, `common`, or `manager`.
- **No cross-module reach-in.** A module's internals are private. All access goes through its interface file.
- **No global singletons.** No Godot autoloads in `sim/`. State is passed explicitly.
- **No file over 400 lines. No function over 50.** Enforced.

---

## Surviving context compaction

The repository is the memory. A session's in-flight reasoning is not — it lives only in context and
is gone on compaction unless it was written down first. Documents are re-readable; a train of thought
is not.

- **`CLAUDE.md`** is auto-loaded every session and survives compaction by construction. It is a short
  pointer, not content: it names the reading order and sends you to `docs/WORKING.md`.
- **`docs/WORKING.md`** is current state, not a log: current stage, what's done, what's in flight,
  decisions made this session, open questions, discoveries not yet written anywhere durable. Under
  150 lines. Update it as you work, not at the end. When a stage closes, its durable content moves
  to an ADR, a `MODULE.md`, or a claim, and `docs/WORKING.md` resets for the next stage.
- **Write discoveries immediately, not at a natural pause.** The test: if this session ended right
  now, would this be lost? If yes, write it before continuing — an ADR for a decision, a `MODULE.md`
  gotcha for a trap, `docs/WORKING.md` for everything else.
- **After any compaction, re-read `CLAUDE.md` and `docs/WORKING.md` before touching anything**, and
  state in one paragraph what you're doing and why. If that paragraph doesn't match
  `docs/WORKING.md`, stop and say so rather than guessing forward.
- **One stage per session.** End deliberately at a stage boundary with a written handoff rather than
  drifting into a compaction mid-task. If a stage looks too large to fit one session, say so before
  starting it — the same signal as a task needing more than five files.

---

## Tick order

Fixed and documented. Changing it requires an ADR.

```
input → body → machines → transport → items → fluid → economy → invariants → telemetry
```

The sim advances only by explicit `tick()`. It never sees `delta`, never reads a wall clock, and never touches the engine.

---

## Determinism

Non-negotiable, because it is what makes agent testing, replay debugging, and sweeps possible at all.

- Fixed timestep, 60 Hz. Rendering interpolates.
- Fixed-point for all state-affecting positions and velocities.
- Seeded, split RNG. One stream per subsystem. Streams are serialized state.
- No iteration over hash maps in state-affecting code.
- Generational-index entity IDs. Never pointers, never bare array positions.

`replay_determinism_test` must exist and pass from day one: run a recorded input log twice from one seed, hash state every 100 ticks, assert identical.

---

## What agents can and cannot measure

Be honest about this in every report. It is the difference between a credible instrument and a dashboard.

**Can:** reachability, dominant strategies, strategy diversity, stall location and duration, softlocks, regression across systems, legibility from a rendered frame.

**Cannot:** whether the game is fun. Agents do not get bored, do not misread visuals, and have no muscle memory.

Any claim about engagement needs a stated proxy metric and a stated account of what that proxy misses. `experiment/calibration/` holds recorded human sessions, captured through the same L2 interface with the same telemetry schema, so proxies can be checked against real behavior instead of assumed.

---

## Current state

Pivoted from a persistent-world factory game on 2026-08-25. The prior codebase is in `legacy/`, tagged `pre-pivot`. The prior compatibility audit and pivot plan are in `docs/archive/`; both remain accurate about the code they measured.

What was found structurally absent in the prior codebase, and is therefore greenfield: run lifecycle, typed command layer, run/meta save separation, declarative scenario format, R1's transport cost model, R3's flood clock. Those are L2 through L4 of the instrument, which is why they were absent.

Start point: `claims/C001-two-minute-run.md`, currently BLOCKED on `sim/run` not existing. It is the definition of done for the entire first sequence of work.
