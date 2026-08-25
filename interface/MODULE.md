# interface

## Purpose

The only door into the sim. Exactly two operations:

- `observe(envelope) -> Observation`
- `apply(Command) -> Result`

Commands are typed values from `sim/commands`, submitted, validated, and
either applied or rejected with a reason (rejection reasons are part of
telemetry). Observations are filtered by a capability envelope (vision,
planning, motor, priors dimensions) — this is what makes a scripted-agent
run and a human run comparable, so it's worth getting right here rather
than retrofitting it after `harness` and `view` both exist and disagree
about what an "observation" is.

## Dependencies

`sim`, `core`.

## Consumers

`harness` (agents/bots), `view`, `shell` — all as peers. None of the three
is privileged over another: a scripted bot and a human player go through
exactly the same `observe()`/`apply()` door, filtered by whatever envelope
applies to them.

## Invariants

- Nothing above this layer ever calls a sim mutator directly. Every state
  change from `harness`, `view`, or `shell` goes through `apply()`.
- Nothing above this layer reads raw sim state directly either — every
  read goes through `observe(envelope)`, so the envelope's filtering is
  never bypassable by reaching around it.

## Public API

None yet. This directory is a skeleton — no code has been written.

## Gotchas

None yet.
