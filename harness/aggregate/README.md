# harness/aggregate

## Purpose

Telemetry -> metrics -> report artifacts. Takes the raw `telemetry.jsonl`
(and the other per-run outputs) `harness/driver` produces and turns them
into the numbers a claim's verdict actually depends on — this is where
"the agent finished" becomes "velocity_efficiency was 0.94."

## Dependencies

`core` (telemetry event payloads are expressed in `core` primitives).
Reads `harness/driver`'s output files; does not depend on `harness/driver`
as code, only on its output format.

## Consumers

`experiment/claims_runner` (turns aggregated metrics into a claim verdict),
`experiment/sweeps` (aggregates across many runs into a distribution),
`experiment/ablations` (diffs aggregated metrics between a baseline and a
changed `data/` value).

## Public API

None yet. This directory is a skeleton — no code has been written.

## Gotchas

None yet.
