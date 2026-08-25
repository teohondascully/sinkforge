# sim/meta

## Purpose

Persistent rig state, unlocks, stockpile, offline processing — everything
that survives between runs.

Whether the surface rig is a small fixed deck or a second buildable factory
(mirroring the shaft) is an explicit open design question. This module
must not be built in a way that forecloses the buildable-factory option —
keep it decoupled from any single-world assumption. That's why its
dependency list below is deliberately minimal rather than reaching for
`world`/`machines`/`transport` just because a buildable rig would
eventually need them.

## Must-not

- Mutate run state directly. `meta` reads what a completed run produced
  (via whatever hands it run results — see `sim/run`'s Gotchas) and updates
  persistent state from that; it does not reach into `sim/run`'s internals
  to change them.
- Assume the surface rig is a fixed deck. See above.

## Dependencies

`core`, `items` (stockpile is composed of item quantities), `economy`
(stockpile accounting and offline processing reuse economy's conversion
math).

Deliberately *not* declared: `sim/run` (see `sim/run`'s Gotchas for why —
this would risk a cycle), `world`/`machines`/`transport` (see the
buildable-factory note above).

## Consumers

`interface`, at minimum — meta's persistent state is what a `MetaIdle`/
`SiteSelect` observation surfaces. No sim-internal consumer is declared.

## Tick phase

Not tick-phase code. `meta` operates between runs (including offline
processing, which by definition isn't happening inside any run's fixed
tick loop).

## Public API

None yet.

## Gotchas

The buildable-factory question and the run/meta coupling question (see
`sim/run`) are both unresolved and both bear directly on this module's
eventual shape.
