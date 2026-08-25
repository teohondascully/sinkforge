# sim/items

## Purpose

Item instances as packed arrays: falling, settling, pile state, pickup.
The foundational data structure for "a physical thing exists in the
world" — analogous to what `world` is for tiles. Other gameplay modules
(behaviors, transport, machines, economy) consume it to do their jobs.

## Must-not

- Own transport policy. How and whether an item moves through a chute or a
  powered lift (cost, direction, rate) belongs to `sim/transport`; `items`
  only holds the instances and their basic physical state (falling,
  settling into a pile, being picked up).

## Dependencies

`core`, `world` (falling/settling/pickup all query tile occupancy and
solidity to know where an item can rest).

## Consumers

`interface`, at minimum. Sim-internal: `behaviors` (primitives consume and
produce item instances), `transport` (moves item instances per R1),
`machines` (machines consume/produce items via behaviors), `economy`
(haul accounting and conversion operate on item quantities), `invariants`
(matter conservation, non-negative buffers, "no items inside solid rock"
all read item state), `run` (extraction resolution counts hauled items).

## Tick phase

`items` (5th phase — after `transport`, so this phase resolves physical
falling/settling/piling for anything not already claimed by a transport
mechanism that tick).

## Public API

None yet.

## Gotchas

None yet.
