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
