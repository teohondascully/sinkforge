---
id: C001
title: A bounded two-minute run completes end to end, headless
status: BLOCKED
kind: structural
owner: engineering
created: 2026-08-25
last_measured: never
first_failed_at: never
scenario: scenarios/first_bore.yaml
blocked_on: sim/run does not exist. No session lifecycle, flood clock, or extraction resolution exists in any form.
---

## Claim

A scripted agent, given no privileged information beyond what a first-time player would have, can start a run, descend a fresh shaft, smelt one ingot, deliver material to the surface, and have the run resolve, entirely headless, in under 7,200 ticks.

## Why this matters

This is the tracer bullet. It is thin everywhere and complete once, and it exercises every layer of the architecture: `core` for determinism, `sim` for the run lifecycle and the world, `interface` for the observation and command path, `harness` for the scenario and driver, `experiment` for the verdict. Nothing else in the project is worth building until this passes, because until it does there is no evidence that a bounded run is buildable on this foundation at all.

It also encodes the two architectural invariants as a testable fact rather than an aspiration: if this claim can only be measured with a window open, the instrument does not exist.

If this claim cannot be made to pass within a few weeks of focused work, that is a real finding about the architecture, and it should be reported rather than worked around.

## Falsifiable form

Under the `constrained` envelope, on scenario `first_bore` with seed 12345, a run initiated from `MetaIdle` reaches `RunResolved` with at least one unit of material banked, within 7,200 ticks, with zero invariant violations, in a process launched with no rendering context.

## Metric

`run_end.reason == "resolved"` and `run_end.banked >= 1`, from `telemetry.jsonl`, with `ticks_used` from `result.json`, from a driver process launched headless.

Supporting assertions that must also hold, because a run that "completes" while violating them has not established what the claim says it establishes:

- `invariants_hold` across every tick
- `edge_catch_events == 0` during traversal
- `pickup_attempt_empty == 0`
- state hashes identical across two runs from the same seed and input log

## Threshold

7,200 ticks, which is two minutes at 60 Hz.

Where the number came from: Draft A's first run length, chosen because the shortest run in the progression is the cheapest thing to build and the cheapest thing to sweep, not because two minutes has been established as a good session length. That is a separate claim and it is not this one. If the design settles on Draft C, this threshold moves and the History records why.

## Current value

Never measured. `sim/run` does not exist. The prior codebase contained no session lifecycle, no flood clock, no run boundary, and no shaft-to-surface haul mechanic under any name, confirmed by exhaustive search and a full read of the previous entry point.

## What this claim does not measure

A great deal, and naming it is the point:

- **Whether the run is any good.** This is a completability claim. A run that resolves in 7,200 ticks may still be tedious, confusing, or trivial.
- **Whether a human could do it.** The agent operates under a constrained envelope, not a human one. It has no confusion, no misreading, and no hesitation.
- **Whether the design rules are implemented correctly.** R1's cost model, R2's recipe quantities, and R4's tool tiers can all be absent or wrong while this claim passes.
- **Whether anything is legible.** Nothing is rendered.
- **Performance at scale.** A two-minute opening run exercises almost nothing of the Section 10 budgets.

Each of those needs its own claim. This one establishes only that the loop closes.

## History

| Date | Commit | Data version | Value | Status | Note |
|---|---|---|---|---|---|
| 2026-08-25 | — | — | not measured | BLOCKED | Claim authored at pivot. Blocked on `sim/run`. |
