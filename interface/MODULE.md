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

`interface/interface.gd`, `class_name Interface`. Constructed around a `TileGrid`, a `Body` and a
`Mining` its caller already owns; owns no scene and runs no loop.

- `observe(Envelope) -> Observation` — pure. Any number of calls leave `state_signature()` identical.
- `apply(Command) -> Result` — the only mutator. A rejected command changes nothing at all.
- `Envelope`, `Observation`, `Result` are inner classes, matching `Invariants`' own convention for
  value types belonging to a module's public file.

`docs/adr/0007-l2-interface.md` is normative for the three decisions behind that shape.

## Gotchas

**An `Observation` is a COPY, and it must stay one.** It holds a flat byte array over its window plus a
legend, and no reference to `TileGrid`, `Body` or `Mining`. Handing back a live grid would be cheaper
and would silently delete the envelope — a consumer holding the grid reads any cell it likes and no
filter here could stop it. `tests/test_interface.gd` tests this by attempting the reach-around
(observe, then excavate, then assert the observation still reports the old state), so the shortcut
cannot be reintroduced quietly.

**`Envelope` has one dimension because one has a mechanism.** `docs/ARCHITECTURE.md` §5 names four
(vision, planning, motor, priors); this build has a window and no fog, planner, motor model or priors
table. The other three are absent rather than stubbed, deliberately: a `vision` field that never
filters reads as a filter that has been checked.

**`window` has no default and there is no reachable "everything" envelope.** The run that must never be
handed perfect information by accident is the constrained one measuring discoverability.
`Envelope.oracle_over(grid)` makes the unfiltered case name itself at the call site.
