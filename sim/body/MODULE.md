# sim/body

## Purpose

Player kinematics: integration, collision, depenetration, step-up, corner
correction, coyote time and jump buffer, climb, rope, swim, carry weight.

This is the highest-risk module in the whole build. It has a strict
automated acceptance suite (edge_catch_events=0, velocity_efficiency>=0.92,
100% step-up/corner-correction success, etc.) run against a fixed
hostile-geometry test chamber, and nothing past it gets built until this
module is green against that suite.

## Must-not

- Read input devices directly. Movement is driven by commands arriving
  through `interface`'s `apply(Command)`, not by polling a keyboard/gamepad
  from inside `sim/`.
- Know about rendering. No camera, no sprite/mesh concepts, nothing that
  assumes a view exists.

## Dependencies

`core`, `world` (collision and depenetration query tile solidity), `invariants`
(`vertical_resolve.gd::resolve_floor` reports a diagnostic-only floor-selection
check to `Invariants.report_floor_selection` -- docs/adr/0005, D0043 -- never
reads a result back, never changes behavior from it).

`vertical_resolve.gd` (D0060) is an internal file of this module, same as
`heightfield.gd`/`input_frame.gd` -- outside code still goes through `body.gd`
alone, per `tools/layer_lint/layer_lint.py`'s "no sibling reach-in" rule. Split
out of `body.gd` once the 400-line file-size gate could no longer be met by
comment trimming without cutting load-bearing reasoning: ceiling/floor
vertical-axis collision resolution, as static functions taking `body: Body`
explicitly rather than living as `Body`'s own instance methods.

`sim/items` is deliberately *not* declared as a dependency here, even
though the module's own purpose lists "carry weight." How carried-item
weight reaches body's integration math is an open detail — it may end up
being a plain scalar passed in rather than a real dependency on `items`.
Flagged as unresolved rather than guessed at.

## Consumers

`interface`, at minimum — `apply()` commands drive body, `observe()`
surfaces its resulting kinematic state. No other sim submodule is known to
depend on `body` directly yet.

## Tick phase

`body` (2nd phase, right after `input`).

## Public API

None yet.

## Gotchas

- None yet, beyond the carry-weight/`items` coupling noted above.
- **Digging exists now** (`docs/DECISIONS_LEDGER.md` D0110/D0112/D0113, `docs/GDD.md` §12's Reveal
  want-layer): a new `InputFrame.dig_pressed` field, handled by `Body._handle_dig`, excavates the ONE
  COLUMN adjacent to the body's leading edge in `facing`'s direction, across the body's OWN full height
  (not just its centre row — a single-row notch can't be walked through by a body several cells tall,
  D0113's own real bug). Deliberately horizontal-only, one column, one tick per press, no hardness gate —
  the smallest thing that could test the Reveal hypothesis, not R4's eventual tool-tier/hardness system,
  which does not exist yet. `dig_event_this_tick`/`dug_material_this_tick` are the same "per-tick
  telemetry, read by the caller, not auto-cleared" shape every other event flag here already uses;
  `dug_material_this_tick` reports `glimmer` if the column held it anywhere, else the first real material.
  **Two real bugs shipped in the first commit, both found only by actually running
  `tests/body/reveal_scene.gd` end to end, neither caught by that commit's own unit tests**: an off-by-one
  in the right-facing target column (D0112) and the single-row-not-full-column gap (D0113) — worth
  reading both entries before touching this mechanic again, since the pattern (a test that derives its
  expected value from the function under test) is easy to repeat by accident.
- **A third real bug, this one requiring cross-tick replay to reproduce (D0122/D0123)**: dig excavates
  only the body's CURRENT footprint at the moment of the touch; a later dig at a DIFFERENT vertical offset
  in the SAME column (without the body ever occupying the rows in between during a dig) left a jagged
  sub-cell fragment `_resolve_horizontal` was never exercised against — the fuzzer's `discontinuity`
  violations. Fixed by `_handle_dig` excavating `TileGrid.extend_terrain_dig_extent`'s own merged, per-column
  high/low-water mark (D0125) instead of just its own touch range, so a column is always one contiguous
  open span from the lowest row ever dug there to the highest. Deliberately does NOT touch
  `_resolve_horizontal` itself — the resolver was correct for the geometry it was designed against; the
  defect was the illegal input, not the resolver (`docs/DECISIONS_LEDGER.md` D0125's full reasoning).
