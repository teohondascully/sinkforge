---
id: C002
title: Traversal over freshly dug irregular terrain stays efficient
status: BLOCKED
kind: feel
owner: engineering
created: 2026-08-25
last_measured: never
first_failed_at: never
scenario: (none yet — needs the hostile-geometry chamber extended with sub-tile rubble, per docs/ARCHITECTURE.md §9)
blocked_on: sim/body and sim/world do not exist. Requires the heightfield collision derivation (docs/ARCHITECTURE.md §9, "Resolution is not one number") to be built, not just designed.
---

## Claim

A player traversing terrain the player themselves just dug — freshly excavated, irregular, full of
sub-tile rubble and 1-to-3px ledges rather than clean 1-tile geometry — maintains velocity efficiency
at or above 0.92, the same threshold already required for the clean hostile-geometry chamber.

## Why this matters

This is the property the whole resolution-split architecture decision (`docs/ARCHITECTURE.md` §9)
exists to buy. The clean-geometry acceptance chamber is necessary but not sufficient: a controller
that passes it can still catch on the exact surface the player spends most of a run standing on,
since dug terrain is never clean 1-tile geometry. If this claim fails while the clean-chamber claim
passes, the resolution split didn't do its job and the heightfield derivation needs rework, not the
forgiveness set on top of it (auto step-up, corner correction, etc.) — those already have their own
budget in the clean-chamber acceptance criteria.

## Falsifiable form

Under a raw-input-frame driver (the same one `docs/ARCHITECTURE.md` §5 describes pre-interface
movement testing using), across a fixed set of dig patterns produced by excavating the hostile
chamber's fine terrain in a scripted sequence (not hand-authored geometry), `velocity_efficiency`
over the resulting irregular surface is ≥ 0.92, matching the clean-chamber threshold rather than a
lowered one.

## Metric

`velocity_efficiency`, the same telemetry quantity the clean-chamber acceptance criteria already use
(`docs/ARCHITECTURE.md` §9), measured over a traversal route defined on freshly-dug rather than
hand-authored geometry.

## Threshold

0.92 — deliberately the same number as the clean-chamber threshold, not a separately-negotiated one.
Where it came from: if dug terrain gets its own, lower bar, the claim stops measuring whether the
heightfield derivation actually works and starts measuring how low a bar was drawn around it, which
is exactly the threshold-before-measurement failure `docs/CLAIMS.md` §10b exists to prevent. This
threshold was set before any measurement exists (`first_failed_at: never`, `last_measured: never`).

## Current value

Never measured. `sim/body` and `sim/world` do not exist. The heightfield collision derivation this
claim is stated against is a design decision (`docs/ARCHITECTURE.md` §9), not yet an implementation.

## What this claim does not measure

- **Whether the rope/grapple feels good.** This claim is entirely about ground traversal over
  irregular dug terrain. The rope is this design's actual answer to movement freedom
  (`docs/GDD.md` §1, `docs/ARCHITECTURE.md` §9) and needs its own claim once it's built — this one
  says nothing about it.
- **Whether the dig patterns tested are representative of real play.** A scripted excavation
  sequence is not the same population as what real dig plans actually produce; this is closer to
  the constrained envelope's discoverability question than a claim about real players.
- **Ceiling and wall collision**, which stays grid-swept rather than derived, per
  `docs/ARCHITECTURE.md` §9 — this claim only exercises the ground plane.
- **Whether 0.92 is the right number for *this* population of geometry**, as opposed to being the
  right number for the clean chamber it was originally set against. The two thresholds being equal
  is a deliberate methodological choice (see Threshold above), not independent evidence that 0.92 is
  correct for dug terrain specifically.

## History

| Date | Commit | Data version | Value | Status | Note |
|---|---|---|---|---|---|
| 2026-08-25 | — | — | not measured | BLOCKED | Claim authored alongside the resolution-split architecture decision it tests. Blocked on `sim/body`, `sim/world`, and the extended hostile-geometry chamber. |
