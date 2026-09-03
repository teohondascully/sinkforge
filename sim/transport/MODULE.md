# sim/transport

## Purpose

Chutes (free, gravity-powered movement through excavated space), lifts
(powered, cost per unit-meter), and feeders. Implements the design rule
"down is free, up is powered" (R1).

**What is here now (A′ step 3e, D0350):** `flow.gd`, `Flow` — legacy's flow phase: every machine's
output buffer moves to its ONE destination each hub tick, down its column by the landing rule or up
it by the lift's rise; `updraft_at` for the body. The lift's and the winch's runners are `Movers` in
`sim/machines` (they are behaviours); their routing is here. The splitter's two-way dealing waits on
its ruling (plan §8).

Transport implements R1, which is what makes it a peer of `items` and
`machines` rather than a layer above or below either — it is a third
gameplay system at the same tier, not a service the other two call into or
a consumer that sits on top of them.

## Must-not

- Special-case machine types. Transport routes and prices movement; it reads a machine only through
  the registry's routing flags (`updraft`), never its tag.

## Dependencies

`core`, `world` (traversable excavated space, chute/lift topology), `items`
(the piles and the landing rule; the flow events), `machines` (added 2026-09-03, D0350: the flow
walks the registry and moves the buffers machines own).

The judgment call this file used to flag (does transport touch item positions, or only price
routes?) is settled by the lift: transport MOVES buffers, the registry owns them, and the movers
that fill an output buffer are machine behaviours. `transport -> items` and `transport -> machines`
are both real code dependencies now.

## Consumers

`interface`, at minimum. Sim-internal: `economy` (haul accounting reads
transport cost/movement), `run` (R1's cost model factors into the economy —
"and termination" dropped from this line 2026-08-27: no run-ending event
exists for R1's cost model to factor into anymore).

## Tick phase

`transport` (4th phase — after `machines`, before `items`).

## Public API

- `Flow` (`flow.gd`) — `step(world, items, machines)` (every output to its destination, placement
  order), `destination(world, items, machines, m) → {to_cell, target}`, `deliver()`,
  `column_rise(world, piles, machines, col, start_row)` (the lift's mirror of the landing: the first
  machine above, else the open metre under the first rock, else row 0), `updraft_at(world, machines,
  cell)` (a clear column down to a machine with the `updraft` flag).

## Gotchas

- **The ceiling is any rock**, as the landing's floor is: a half-dug metre stops a rising item.
- **One destination per machine** until the splitter is ruled; `route_toggle` is carried, unused.
