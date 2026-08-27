# sim/fluid

## Purpose

Water automaton: active-cell set, flood level, aquifer breach.

## Must-not

- Tick every cell every frame. Must use an active-cell set (only cells
  where water state can still change get processed) — this is a hard
  performance constraint, not a style preference.

The base fluid automaton's design contract guarantees total water is
conserved across a tick. Continuous seepage into excavated sections (R3,
`docs/GDD.md` §4 — rewritten 2026-08-27 from a run-ending clock to local,
continuous upkeep) is a controlled, deliberate violation of that contract,
and it must stay contained to one clearly-named function gated by
section/pump state — not threaded through the conservation-preserving
passes. Anyone reading the conservation-checking code should be able to
find the one place water is deliberately injected without having to audit
the whole module.

**What owns the seepage/pump-upkeep logic is an open question, same as
`sim/run`'s own shape (see `sim/run/MODULE.md`).** The description below
still names `run` because nothing has replaced it yet — read it as "whatever
ends up owning local flood/pump state," not a confirmed dependency.

## Dependencies

`core`, `world` (the automaton operates over the tile grid).

## Consumers

`interface`, at minimum. Sim-internal: `invariants` (flood level in a given
section, monotonic while rising, reads this module's flood level state
directly, not through `run`), `run` (drives the seepage/pump-upkeep
mechanic via the one gated override function described above — provisional
naming, see the open question noted under Purpose above).

## Tick phase

`fluid` (6th phase — after `items`, before `economy`).

## Public API

None yet.

## Gotchas

The conservation-violating flood-clock function is the one deliberately
special-cased piece of this module — see Must-not above. Everything else
in `fluid` should conserve water exactly.
