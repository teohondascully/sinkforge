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

`DecisionMeter` (`decision_meter.gd`) — the decisions-per-minute instrument (D0643). `record(tick,
payload)` takes each `RouteBot.step()` emission, `report()` bins it into 3600-tick sim-minutes:
decisions (all emissions), active vs idle payloads, a histogram of action kinds read off the
payload's own buttons, leg-kind attribution, and the traversal/digging/processing/observe/idle
bucket roll-up. `ScenarioDriver.run_metered` is its driver; `tools/measure_decisions.gd` prints it.

## Gotchas

`elapsed_ticks` must be set by the driver (the world clock, `bot.ticks` — which includes idle ticks
a goal watch spends deciding nothing). Without it the report bins only to the last decision and a
decision-free tail disappears instead of reading as zeros.
