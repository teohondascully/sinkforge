# sim/transport

## Purpose

Chutes (free, gravity-powered movement through excavated space), lifts
(powered, cost per unit-meter), and feeders. Implements the design rule
"down is free, up is powered" (R1).

Transport implements R1, which is what makes it a peer of `items` and
`machines` rather than a layer above or below either — it is a third
gameplay system at the same tier, not a service the other two call into or
a consumer that sits on top of them.

## Must-not

- Special-case machine types. Transport routes and prices movement; it does
  not know what kind of machine is feeding a chute or drawing from a lift.

## Dependencies

`core`, `world` (traversable excavated space, chute/lift topology), `items`
(relocating item instances along a route is the whole point of this
module).

Flagged as a judgment call: the exact relationship between `transport` and
`items` isn't settled. It's plausible that in the final design transport
only computes routing/cost and the `items` phase (which runs right after
transport in the fixed tick order) is what actually applies the resulting
position changes to item instances — which would make the dependency run
the other way, or be mediated through `sim/commands` instead of a direct
code dependency. Declared here as `transport -> items` because transport's
job is meaningless without touching item positions, but this is the
weakest-confidence dependency call in `sim/`.

## Consumers

`interface`, at minimum. Sim-internal: `economy` (haul accounting reads
transport cost/movement), `run` (R1's cost model factors into the economy —
"and termination" dropped from this line 2026-08-27: no run-ending event
exists for R1's cost model to factor into anymore).

## Tick phase

`transport` (4th phase — after `machines`, before `items`).

## Public API

None yet.

## Gotchas

See the dependency note above re: `items`.
