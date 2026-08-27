# Engineer handoff: calibrated agent-journey evaluation

You are implementing a bounded research/evaluation slice for SINKFORGE. Read these files first:

- `docs/AGENT_PLAY_EVALUATION_PROTOCOL.md` — the authoritative specification;
- `docs/PRIORITY.md` — especially the experience-evaluation workstream, T2.1, T2.3, T3.1, and T1.0;
- `docs/DIRECTOR_BRIEF.md` §4 — evaluations A–N and their limits;
- `docs/A_PLUS_STATUS.md` — current A+ disposition;
- `docs/ORCHESTRATOR.md` — harness, machine-lock, save, and evidence rules;
- `tools/run_harness.sh`, `tools/with_machine.sh`, `tools/check_base.gd`, and existing `play_agent` tools;
- `docs/tracelog/sweeps/2026-08-22-area2-close/summary.txt` — the current sweep receipt.

## Mission

Design and, only when explicitly assigned, implement a calibrated agent-play evaluation layer that can tell
the difference between:

- a world or fixture that is impossible;
- a broken driver, pointer, frame, audio, save, or machine-lock contract;
- an actor that lacks basic game-operating capability;
- a communication/discoverability failure;
- a genuine gameplay/design failure;
- a motivation/payoff failure.

The actor is a probe, not an oracle and not a human replacement. Never convert one actor’s failure into a
game verdict without the controls specified below.

## Portfolio boundary: what you are and are not building

Do not turn this into a larger version of the deterministic harness. The existing harness remains the
technical regression layer for simulation invariants, real input, rendering/readability, performance,
save/load, exit codes, assertion floors, and harness self-integrity. This work is a separate, slower
experience-evaluation tier.

The broader portfolio has six distinct questions:

1. deterministic system correctness;
2. real-engine encounter contracts for selected visible changes;
3. calibrated agent journeys for understanding, recovery, and desire;
4. screenshot-only criticism with no code or state access;
5. counterfactual A/B comparisons with one treatment changed;
6. small human calibration sessions to check that actor behaviour resembles player behaviour.

Do not make one scalar or one harness job answer all six. A journey run may show that an actor did not form
the next desire, but it cannot prove that a route was reachable; an oracle can prove reachability, but cannot
prove comprehension or fun. Keep technical, journey, screenshot, A/B, and human receipts separate.

## Non-negotiable constraints

1. Do not add new gameplay or Freight Winch work.
2. Do not replace the deterministic harness; this is a separate experience-evaluation tier.
3. Do not expose `FactorySim`, coordinates, inventory, resource lists, objective IDs, event state, or hidden
   target cells to the blind actor.
4. Do not use a scripted milestone driver in the blind phase.
5. Do not lower a threshold to make a run green.
6. Do not call two same-family judges independent.
7. Do not average the evidence into a single “fun” score.
8. Do not automate before two or three manual runs establish a repeatable, actionable difference.
9. Do not touch canonical captures, the user save, or another worker’s files.
10. Never start a harness/game run without `tools/with_machine.sh` and an exclusive machine lock.
11. Preserve raw traces and mark `VALID`, `INVALID`, `VOID`, `ACTOR_INVALID`, `WORLD_INVALID`, or
    `ACTOR_LOOP`; never silently discard a run.
12. Keep the implementation on the canonical line. Do not create a worktree fleet or a parallel branch.

## Required architecture

The implementation must separate four roles:

### Blind actor

Receives only rendered frames/video, declared audio, ordinary controls, and normal loading/menu behavior.
Its prompt must not mention automation, lodes, drills, hauling, Factorio, Freight, or the expected solution.

### Capability calibrator

Runs explicit controls before the blind session: move, jump, aim, mine, grapple, menu navigation, machine
placement, and hole recovery. Failure here yields `ACTOR_INVALID`, not a game-quality score.

### Reachability oracle

May see privileged state solely to establish that a selected route/resource/state transition exists. Oracle
success never counts as player comprehension or fun evidence.

### Observer/judge

Reviews raw evidence without design intent or target bottleneck. It declares model family, prompt, evidence
order, and shared context. Any correlation is reported rather than called independence.

## Required assistance ladder

For a failed scenario, run pre-registered diagnostics in order:

- L0: blind, no hint;
- L1: ordinary game affordance visible/replayed;
- L2: one minimal plain-language hint;
- L3: explicit control and target instruction.

Interpret the first transition that resolves the failure. Do not use L1–L3 to manufacture a passing blind
result. L0→L1 is discoverability; L1→L2 is context/wording; L2→L3 is onboarding/control mapping; failure
at L3 after calibration indicates a likely world/driver/game problem; blind success followed by stopping is
motivation evidence.

## Required loop detector

Terminate a probable actor loop when there is repeated action/state/camera n-grams, repeated failed attempts,
or no meaningful world-state change over the declared window. Classify it `ACTOR_LOOP`, preserve the trace,
and run the assistance ladder. One model looping is not a game verdict; replication by multiple calibrated
profiles may become one.

## Required journey phases

1. Blind opening: 90 seconds, no objective supplied.
2. Self-directed play: 8–12 minutes, actor chooses the next action.
3. Constrained target: 5–10 minutes, one explicit target to separate comprehension from motivation.
4. Recovery/pressure probe: 3–5 minutes, one known blockage, depletion, adjacency, darkness, or recovery case.

The first manual pilot may stop at five minutes and must be labelled a pilot, not a 20-minute result.

## Required journey questions

The journey is not a milestone checklist. Record whether the actor independently forms a next desire after
each payoff, including:

- seeking processing after discovering ore;
- seeking fuel or input after building a machine;
- choosing a new route after depletion;
- recognizing that a machine retired a manual task;
- recovering from a self-created hole or navigation mistake.

Also record time to understanding, dead-end actions, reversals, voluntary continuation, unexplained idle
periods, and the actor's post-run account of what it was trying to do. The prompt must not tell the actor
which desire the experiment expects.

## Counterfactual and screenshot follow-ups

After manual journeys establish a repeatable bottleneck, propose one-treatment A/B comparisons using the
same actor profile, seed family, route, goal, feed, and input cadence. Examples include a quieter terrain
cue, reduced tutorial chrome, a contextual grapple preview, or a stronger machine-state payoff. Report
changes in understanding, dead-end actions, continuation, and recovery; do not collapse them into a single
fun score.

A screenshot-only critic is a separate role. It receives ordered captures or video without code,
simulation state, objective labels, or design intent and reports what a first-time viewer cannot explain.
Do not let its observations leak into the blind actor's prompt before the first verdict.

Adaptive self-play, generated goals, and automatic scenario mutation are deferred until two or three manual
runs demonstrate a repeatable actionable difference. They are not a substitute for calibration and may
reward-hack the evaluator.

## Scenario registry requirements

Each scenario must name its question, seed rule, phase, feed/cadence, controls, privileged-state policy,
oracle fixture, capability profile, holdout status, stop window, and raw evidence artifacts. Rotate across
seed, depth, lighting, resource distribution, depletion, terrain geometry, machine adjacency, inventory,
objective visibility, recovery, starvation, and relocation. Retire scenarios that stop producing information;
do not increase scenario count for its own sake.

## Validity taxonomy

Use exactly these classifications unless the director approves an extension:

- `WORLD_INVALID` — required world state or route absent;
- `DRIVER_INVALID` — input/capture/audio/timing/lock failure;
- `ACTOR_INVALID` — capability calibration failed;
- `COMMUNICATION_FINDING` — minimal cue/hint resolves it;
- `DESIGN_FINDING` — calibrated actor cannot infer/execute from ordinary cues;
- `MOTIVATION_FINDING` — actor understands but does not continue;
- `ACTOR_LOOP` — progress plateau requiring diagnostic treatment;
- `VOID` — evidence contract contaminated or incomplete.

## Required receipt

Retain commit, scenario, seed, actor/model/version, prompt hash, settings, calibration, oracle result,
controls, feed, lock status, timestamps, raw artifacts/checksums, validity class, stop reason, dimension
vector, confidence, missing evidence, counterexample, and comparison eligibility. A prose summary without
the raw receipt is not evidence.

## Required report format

For every run, report:

1. hypothesis written before the run;
2. actor capability result;
3. oracle reachability result;
4. exact feed/control/prompt boundary;
5. observed timeline;
6. validity classification and why;
7. assistance-ladder result if applicable;
8. evidence/inference separation;
9. score vector only for valid runs;
10. next recommendation—one highest-leverage change, not a shopping list.

## Stop conditions

Stop implementation and report if the actor boundary cannot be enforced, the selected seed is invalid,
the machine lock is unavailable, the receipt cannot be retained, the population denominator is ambiguous,
or the experiment would require changing gameplay to make the test work. Do not “solve” a blocked evaluation
by relaxing its floor or adding an objective rail.

## Completion evidence

The design slice is complete only when the specification, scenario schema, actor capability suite, oracle
contract, assistance ladder, loop detector, validity taxonomy, receipt format, and one manually calibrated
pilot are documented. Automation remains a separate future decision after two or three manual runs.
