# CONTEXT

**Read this first, every session, before anything else.** If you read only one file in this repository, read this one. It is kept short deliberately — `wc -l CONTEXT.md` is the number, not a figure written here to go stale; if it's grown noticeably, something belongs in `docs/` instead.

---

## What this is

**Sinkforge is a factory game with a persistent underground shaft and an idle game's progression curve.** 2D, side-view, vertical.

The player bores a shaft from a permanent surface rig, builds extraction and routing infrastructure inside it, and hauls refined material back up to satisfy demands waiting at the rig. There is no reset: the shaft is the same one the player started on, deeper and more built-out than it was an hour ago. Satisfying a demand unlocks the next capability, which is what lets the shaft go deeper still. One shaft, one permanent rig — the shaft is where the factory lives, the rig is the standing consumer that makes building it necessary in the first place.

Three things follow that are easy to miss and expensive to get wrong:

- **The terrain is the factory.** The shape you dig is the routing, independent of whether the shaft resets — an aquifer where you wanted your main chute, ore forty meters further than the last vein. What no longer holds: geology used to reshuffle every run and no longer does, since there is one shaft now. Lateral variety instead has to come from the un-mined extent of that one world; whether that's enough is an open question (`docs/GDD.md` §8).
- **No global multipliers. Ever.** Factory games are ratio puzzles; idle games are number puzzles. Every upgrade is a new capability or a changed constraint, never a rate multiplied. See `docs/GDD.md` §2 and §5.
- **Down is free, up is powered.** The central asymmetry. R1 below.
- **The rig-as-consumer macro-loop needs a micro-loop underneath it.** Feeding the rig is a transaction, minutes apart; nothing was renewing interest between deliveries. Three want-layers (Reveal, Flow, Pressure) are the proposed fix — Reveal is the first one under test. `docs/GDD.md` §12.

It is also, and equally, a **measurement instrument for game design**. The game is playable end to end with no renderer, so that automated agents can play it thousands of times and produce falsifiable evidence about whether the design works. Both halves are the product. Neither is a wrapper around the other.

This is a portfolio centerpiece. The standard is: a senior staff engineer reads this repository for ten minutes and comes away impressed. That standard applies to the repository as an artifact, not only to the code inside it.

---

## The one-sentence architecture

**The simulation is a pure, engine-free library, deterministic within a single platform/build. Everything else, including Godot, is a client of it.** (Cross-platform bit-identical replay has a known, diagnosed gap in multiple float sites on the terrain-generation and RNG state path — corrected 2026-08-29, fix queue R5, a prior version of this line named only the cave noise; `docs/DECISIONS_LEDGER.md` D0183 enumerates all four known sites, D0171/D0172 fix not yet scheduled.)

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
- **Instrument LOC growth may not outpace game LOC growth.** A trailing-window velocity check
  (`docs/QUALITY.md` gate 7, `tools/layer_lint/check_loc_ratio.py`), enforced in CI. The absolute
  instrument/game ratio is reported alongside it, not itself a gate — see gate 7's own text for why that
  distinction is load-bearing, not a downgrade. When the velocity check fails, the next unit of work is
  game.

Format and workflow: `docs/CLAIMS.md`.

---

## The four design rules

These are invariants. A proposal that violates one is a design change, not an implementation detail. Push back if you find one that cannot be implemented cleanly.

**R1. Down is free, up is powered.** Gravity moves material downward at zero cost, through excavated space. All upward movement consumes fuel per unit per meter, forever. Transport cost is a first-class simulated quantity, not a rate cap.

**R2. Deep material is required, not more valuable.** No exponential per-unit value by depth. Tier-N upgrades require tier-N material *and* large quantities of tier-1 material. The exponential lives in quantity required.

**R3. Water is continuous upkeep, not a countdown.** Groundwater seeps into every excavated section, always. Pump capacity is infrastructure, not a one-time purchase against a clock. A starved section floods and its machines are wrecked into scrap.

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
docs/BRIEF.md         this session's digest, incl. "What was learned" — findings, not a work log
docs/WORKING.md       current state. not a log. resets when a stage closes
docs/DECISIONS_LEDGER.md   append-only judgment calls, numbered, never edited after the fact
history/              curated images, policy-capped at 12 — currently 168, cull left as director-action.
                      earns its place by illustrating a finding
legacy/               the pre-pivot codebase. read-only. excluded from build.
```

`legacy/` exists so that porting has provenance. Nothing in it is on the build path. Files leave `legacy/` one at a time, under the gates in `docs/QUALITY.md`, and the commit that moves a file says why.

---

## Context discipline

The primary implementers here are agents with bounded context. These are architectural constraints, not style preferences.

- **The 5-file rule.** Any task must be completable by reading five files totalling 1,500 lines or fewer. If a task needs more, the module boundaries are wrong. Report that rather than working around it.
- **`MODULE.md` in every module**, a 100-line LIMIT enforced by `check_size_limits.py` (gate 3): purpose, public API, invariants, dependencies, consumers, tick phase, and the three things that have bitten people here. Read the `MODULE.md` for dependencies, the implementation only for the module you are editing. The number was 60 and unenforced until 2026-08-30, by which point 10 of the 18 tracked files exceeded it — a rule no instance obeys is a comment, so the director ruled it up to one the tree can meet rather than deleting prose written on purpose (`docs/DECISIONS_LEDGER.md` D0226). Headroom is real but thin: `core/MODULE.md` is 98.
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

## Review bandwidth

Throughput regularly exceeds review capacity. Gates catch structural drift; they do not catch a design
decision quietly made in the wrong direction inside an otherwise-clean diff. That is what this section
exists to surface.

- **Every judgment call not dictated by a normative doc gets a `docs/DECISIONS_LEDGER.md` entry**,
  written when made, not at session end. Four lines: decided, alternative, why, reverse cost. Test:
  would a competent engineer with these documents have plausibly chosen differently? If yes, log it.
- **Reversibility gates whether to proceed.** CHEAP — proceed by default, log it, the director skims
  and reverts if wrong. EXPENSIVE — stop and wait; do not proceed on an assumption. EXPENSIVE means it
  shapes a public interface, a data schema, the tick order, a save format, or anything the four design
  rules touch — or, the more general test: would this make it a different game? When unsure, EXPENSIVE.
- **`docs/TASTE_QUEUE.md`** holds feel/visual/design judgment calls as playable fixtures (below), never
  mixed with correctness. Batched for review together; does not block unless also EXPENSIVE.
- **`docs/BRIEF.md`** regenerates as the last action before reporting to the director, not at an
  arbitrary session boundary — a brief regenerated mid-session goes stale the moment more decisions land.
  One screen, EXPENSIVE decisions awaiting the director listed first. If it takes more than 90 seconds to
  read, it's too long. Its "What was learned" section is findings, not a work log: what happened, what
  was learned, and pointers into the ledger and commits for detail — write it before the final
  regeneration, in the same terse style as a ledger entry. This absorbed what would otherwise be a
  separate `docs/JOURNAL.md`; folding it in means one fewer document to remember, and because `BRIEF.md`
  is committed every session, the running narrative lives in `git log -p -- docs/BRIEF.md`, not in an
  ever-growing file. Five documents carry the process now — ledger, brief, working state, taste queue,
  history — and if a sixth starts to seem necessary, that is a signal something else should retire.
- **Ledger spot-audits are sampled by the director, never by the session being audited.**
  `tools/spot_audit.py` picks one commit uniformly at random from those made after
  `docs/DECISIONS_LEDGER.md`'s own creation (an earlier version sampled the entire history and drew a
  pre-ledger commit — a null result, not an audit). The reviewer runs it, reads that commit's full diff,
  and checks it against the ledger entries claiming to cover it — a session selecting its own sample
  defeats the point, which is checking whether the session under-reported.
- **Every external audit is run against an explicit, pinned commit hash — never "the repo" or "the
  current state".** Local commits are routinely ahead of `origin/main` (sessions push rarely), so an
  auditor working from a clone or a stale checkout can genuinely be looking at a different tree than the
  one a session most recently reported on, with no signal to either party that this happened. Both the
  brief handed to the auditor and the report it returns must state the hash. Without this, a real
  finding about an old commit and a false contradiction of a current report are indistinguishable from
  the outside — resolving one from first principles (`git log`, `git ls-tree <hash>`, re-running the
  gate the audit cites, at the disputed hash) is possible but should never be necessary.
- **Any multi-item task the director hands a session lands in `docs/WORKING.md` before work starts, not
  only in the chat message that gave it.** Added 2026-08-26 after a numbered "items 1-7" list survived
  entirely in chat, outside the repo, across a chunk of session work — it never reached the session that
  went to act on it, because nothing durable carried it. The fix is mechanical, the same shape as the
  pinned-hash rule above: a list that only lives in a message is one compaction, one session boundary, or
  one summary away from gone, which is exactly the failure this protocol exists to prevent. The session
  receiving the list writes it into `docs/WORKING.md` verbatim (or a faithful summary that preserves
  every item's number and substance) before starting item 1, not after finishing it.
- Markdown and git only. If this starts to look like a subsystem, say so instead of building it.

## Playable fixtures

A scenario is a declarative fixture (seed, rig state, loadout, start depth, goal) whether a bot or a
human drives it. Full detail: `docs/ARCHITECTURE.md` §6, `docs/QUALITY.md` §2.

- Every stage ships at least one playable fixture demonstrating what it changed, in `scenarios/`,
  identical format to the bot ones.
- Fixtures are **derived, never authored** — reproducible from a real run, never hand-crafted to a state
  the game can't actually produce.
- Review unit is before/after on the **same** recorded input, presented blind, revealed after the
  director picks.
- Fixture ownership is the parallelism contract once parallel write work starts: two workers on
  disjoint fixtures cannot collide in a way the gates won't catch. Stronger than disjoint files alone,
  and the condition to meet before parallel write work starts on `sim/` or `view/`.

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
- Four decoupled resolutions (visual, terrain/digging, machine/logic, collision) — collision is derived from the fine terrain as an integer heightfield, never equal to the pixel grid itself. `docs/ARCHITECTURE.md` §9.

`replay_determinism_test` must exist and pass from day one: run a recorded input log twice from one seed, hash state every 100 ticks, assert identical. Real subject now `tests/test_shaft_replay_determinism.gd` (gate 8) — proven WITHIN a platform (two independent processes, bit-identical); NOT yet proven ACROSS platforms, since multiple sites on the terrain-generation and RNG state path use real floats, not fixed-point (corrected 2026-08-29, fix queue R5 — a prior version of this line named only the cave noise; `docs/DECISIONS_LEDGER.md` D0183 enumerates all four known sites, D0171/D0172 — a real, diagnosed, unscheduled fix, not a design decision made here).

---

## What agents can and cannot measure

Be honest about this in every report. It is the difference between a credible instrument and a dashboard.

**Can:** reachability, dominant strategies, strategy diversity, stall location and duration, softlocks, regression across systems, legibility from a rendered frame.

**Cannot:** whether the game is fun. Agents do not get bored, do not misread visuals, and have no muscle memory.

Any claim about engagement needs a stated proxy metric and a stated account of what that proxy misses. `experiment/calibration/` holds recorded human sessions, captured through the same L2 interface with the same telemetry schema, so proxies can be checked against real behavior instead of assumed.

---

## Current state

Pivoted from a persistent-world factory game on 2026-08-25, then pivoted again on 2026-08-27 when the
run-based roguelite structure the first pivot adopted was itself retired, back to a persistent shaft
(`docs/GDD.md` §9, D0076). The prior codebase is in `legacy/`, tagged `pre-pivot`; the compatibility
audit and pivot plan in `docs/archive/` remain accurate about the code they measured — the engineering
layers (`core/`, `sim/world`, `sim/terrain_gen`, `sim/body`) are unaffected by the second pivot,
confirmed directly (D0076).

What was found structurally absent in the prior codebase, and is therefore greenfield: session/save
infrastructure, typed command layer, declarative scenario format, R1's transport cost model, R3's local
flood mechanics — L2 through L4 of the instrument. Session/save shape is open again as of the second
pivot: the run/meta split `sim/run`/`sim/meta` assumed no longer applies, and nothing replaces it yet.

`claims/C001-two-minute-run.md` is RETIRED — it measured the run-based roguelite structure, which is
retired (`docs/GDD.md` §9, `docs/DECISIONS_LEDGER.md` D0076). Start point now: `claims/C003-cold-start-reaches-d1.md`,
BLOCKED on nearly the entire remaining build sequence (its own `blocked_on` names what's missing). It is
the definition of done for the entire first sequence of work.
