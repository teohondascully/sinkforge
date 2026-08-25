# ADR 0002: R1's cost mechanism is wired to the shaft-to-surface lift only, for now

**Status:** accepted, 2026-08-26.

## Context

R1 ("down is free, up is powered," `docs/GDD.md` §4) says all upward movement consumes fuel per unit
per meter. `docs/GDD.md` §4 originally left open whether that governs every upward movement inside the
shaft or only the shaft-to-surface boundary, and deferred the choice to an ADR.

Charging every internal lift is the more complete implementation of the rule as written, but it is also
the more expensive one to build first: it requires the cost model to reason about arbitrary internal
transport topology (chute segment, feeder hop, whatever transport primitives `sim/transport` ends up
with) before any of that exists. Charging only the shaft-to-surface boundary is cheaper to build and
sufficient to prove out R1's central claim — that hauling has a real cost — without also having designed
internal transport's full shape first.

## Decision

The cost mechanism is **per-unit-per-meter from the start** — it is not a flat toll or a rate cap, it is
the real quantity R1 describes. It is **wired only to the shaft-to-surface lift** initially. Internal
in-shaft lifts (moving material up between two points inside the shaft, short of the surface) are free
for now.

The load-bearing constraint, and the reason this is worth an ADR rather than a comment: **extending the
charge to internal movement must be a data change, not a rewrite.** The cost mechanism itself must not
be hardcoded to know "the surface" as a special case — it must be parameterized by which lift segments
are chargeable, with "shaft-to-surface only" as the current data, not the current code. If implementing
this narrows the mechanism to something that only knows how to charge one boundary, the option this
decision exists to preserve is gone and the next change becomes the rewrite this ADR was written to
avoid.

## Consequences

- `sim/economy` (or wherever the cost model lives) takes "which lifts are chargeable" as configuration,
  not as a conditional on segment identity. A future change to charge internal lifts is a data-file edit.
- Internal transport can be built and iterated on without the cost model design being a blocking
  dependency — R1's core claim is testable against the boundary charge alone.
- The corollary in `docs/GDD.md` §4 ("fuel must be found within or below the layer being worked") is not
  yet mechanically enforced for internal movement under this decision — fuel found deep and hauled a
  short internal distance is currently free, same as everything else internal. That gap is intentional
  and tracked here, not a bug to fix under a different task.
- If a claim ever measures internal-haul behavior and the free-internal-lift assumption turns out to
  matter to the result, that claim's scope note should say so explicitly rather than let the gap surface
  as a surprise.
