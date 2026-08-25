# sim/world

## Purpose

Tile grid, chunks, material IDs, hardness, terrain queries and mutations.
The single source of truth for "what is at this cell" — solid rock, an
excavated void, what material, how hard it is to dig. Foundational: nearly
every other gameplay submodule queries or mutates it.

## Must-not

- Know about machines. No machine types, no machine placement concepts.
- Know about items. No item instances, no item types.

## Dependencies

`core` only.

## Consumers

`interface`, at minimum. Sim-internal: `terrain_gen` (writes generated
tiles), `body` (collision/depenetration/step-up against tile solidity),
`items` (falling/settling/pickup query tile occupancy), `behaviors`
(primitives that mutate terrain, e.g. an extraction primitive), `transport`
(chutes/lifts/feeders query traversable excavated space), `machines`
(placement validity queries tile state), `fluid` (the water automaton
operates over the tile grid), `invariants` (checks like "no items inside
solid rock" and "no machine in an invalid cell" read world state), `run`
(drives shaft generation and reads world state for termination conditions).

## Tick phase

None. `world` is substrate — a data store queried and mutated by other
phases — not itself one of the fixed tick phases.

## Public API

None yet.

## Gotchas

None yet.
