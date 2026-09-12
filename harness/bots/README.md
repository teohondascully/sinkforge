# harness/bots

## Purpose

The scripted/planner/language agents themselves (T0/T1/T2), entering
through the same `interface` door a human would via `view`. A bot consumes
`Observation`s (filtered through a `harness/envelope`) and produces
`Command`s — nothing more privileged than that.

## Dependencies

`interface`, `sim` (types only, via `interface`), `core`,
`harness/envelope` (a bot is written against a specific envelope's
observation shape).

## Consumers

`harness/driver` (runs a bot against a scenario), `experiment/sweeps`
(runs a bot across many seeds/envelopes).

## Tiers

- **T0** — scripted: fixed logic, deterministic, fast-loop-safe.
- **T1** — planner: searches/plans over the oracle or constrained envelope.
- **T2** — language: reasons in natural language over the language
  envelope. Slow-loop only, never in CI (see `harness/envelope`).

## Public API

`ColdStartBot` (`cold_start.gd`) — the scripted T0 policy for `agent: cold_start` scenarios:
`execute(anchor)` runs the tutorial route (mine vein, feed forge, mine coal, feed forge, collect
ingots, deliver to the rig) through `Interface.apply`/`observe` only. Named `execute` rather than
`run` because `check_claim_references` reads `func run(` as a check-registering file and a policy
is not a check.

## Gotchas

None yet.
