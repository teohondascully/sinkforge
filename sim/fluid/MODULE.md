# sim/fluid

## Purpose

Water automaton: active-cell set, flood level, aquifer breach.

## Must-not

- Tick every cell every frame. Must use an active-cell set (only cells
  where water state can still change get processed) — this is a hard
  performance constraint, not a style preference.

The base fluid automaton's design contract guarantees total water is
conserved across a tick. A run's rising flood clock is a controlled,
deliberate violation of that contract, and it must stay contained to one
clearly-named function gated by run state — not threaded through the
conservation-preserving passes. Anyone reading the conservation-checking
code should be able to find the one place water is deliberately injected
without having to audit the whole module.

## Dependencies

`core`, `world` (the automaton operates over the tile grid).

## Consumers

`interface`, at minimum. Sim-internal: `invariants` (flood level monotonic
within a run reads this module's flood level state directly, not through
`run`), `run` (drives the flood clock via the one gated override function
described above).

## Tick phase

`fluid` (6th phase — after `items`, before `economy`).

## Public API

None yet.

## Gotchas

The conservation-violating flood-clock function is the one deliberately
special-cased piece of this module — see Must-not above. Everything else
in `fluid` should conserve water exactly.
