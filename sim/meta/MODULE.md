# sim/meta

## Purpose — SHAPE OPEN, 2026-08-27, more fundamentally than the rig-form question below

This module's purpose used to be "everything that survives between runs" —
rig state, unlocks, stockpile, offline processing. That definition assumed
a `sim/run` whose state was disposable, so there was something for `meta`
to be persistent *relative to*. The run-based structure is retired
(`docs/GDD.md` §9, D0076): there is no more disposable run state, so
"survives between runs" has no referent, and it's not yet decided whether
`meta` should still exist as a separate module from whatever holds shaft
state, or whether the rig/unlocks/stockpile concerns it names simply
become part of one persistent world-state module. Read `sim/run/MODULE.md`
before assuming anything here — the two modules' shapes are coupled.

What still clearly applies regardless of how this resolves: rig state,
unlocks, and stockpile are real, durable concepts that need to live
somewhere. Offline processing survives unchanged in concept — it is a
function of real-world elapsed time while the app is closed, which has
nothing to do with in-game run boundaries and was never actually tied to
the run/meta split.

Whether the surface rig is a small fixed deck or a second buildable factory
(mirroring the shaft) is a second, separate open design question. This
module must not be built in a way that forecloses the buildable-factory
option — keep it decoupled from any single-world assumption. That's why its
dependency list below is deliberately minimal rather than reaching for
`world`/`machines`/`transport` just because a buildable rig would
eventually need them.

## Must-not

- Mutate `sim/run`'s state directly, if that module still exists once the shape question above
  resolves — this module reads what haul/extraction produced and updates persistent state from
  that, it does not reach into another module's internals to change them.
- Assume the surface rig is a fixed deck. See above.

## Dependencies

`core`, `items` (stockpile is composed of item quantities), `economy`
(stockpile accounting and offline processing reuse economy's conversion
math).

Deliberately *not* declared: `sim/run` (see `sim/run`'s Gotchas for why —
this would risk a cycle, and the underlying coupling question survives the
reversal even though the specific mechanism named there doesn't),
`world`/`machines`/`transport` (see the buildable-factory note above).

## Consumers

`interface`, at minimum, once there is a concept for it to surface via `observe()`. No sim-internal
consumer is declared.

## Tick phase

Not tick-phase code. Offline processing is a function of real-world elapsed time, evaluated on load
— this was never actually gated by run boundaries and is unaffected by the reversal. Whatever else
this module ends up covering depends on the Purpose question above.

## Public API

None yet.

## Gotchas

**The Purpose section above is the load-bearing gotcha now: whether this module exists as a separate
thing from shaft state at all is undecided, more fundamentally than the buildable-factory question.**
Read it first. The buildable-factory question and the run/meta coupling question (see `sim/run`) are
both still unresolved and both still bear directly on this module's eventual shape, whatever that
shape turns out to be.
