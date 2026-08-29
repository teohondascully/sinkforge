# sim/invariants

## Purpose

Continuous assertions: conservation of matter across the tick modulo
declared sinks, non-negative buffers, no items inside solid rock, no
machine in an invalid cell, flood level in a given section monotonic while
it is rising. This is a
checking module — it reads other submodules' state after they've acted
this tick and flags violations; it doesn't itself produce gameplay state.

## Must-not

- Be disabled in tests. These assertions are the deterministic-sim
  contract made checkable — turning them off to make a test pass hides the
  thing the test exists to catch.

## Dependencies

`core`, `world` ("no items inside solid rock"), `items` (buffer
non-negativity, matter conservation), `machines` ("no machine in an
invalid cell"), `fluid` (flood level monotonic — read directly from
`fluid`'s own state, not through `run`, to avoid needing a dependency on
`run`), `economy` (conservation "modulo declared sinks" needs to know what
economy has declared as a legitimate sink).

## Consumers

`interface`, at minimum — violations surface as part of the telemetry/
rejection surface `observe()`/`apply()` expose. `body` is the first real
sim-internal caller (`_resolve_floor`'s floor-selection check, docs/adr/0005,
D0043 — the function moved to `sim/body/vertical_resolve.gd::resolve_floor()` at D0059, after this
note was written) — it reports into this module but never reads a result back to change
its own behavior, so "nothing in `sim/` reads its output back" still holds in
the sense that matters (no gameplay decision depends on a violation), even
though it's no longer literally true that no sim module calls in. Emits via
`push_error()` directly for now, not through `telemetry`, which doesn't exist
yet — a stopgap the first of `telemetry`'s own consumers should revisit.

## Tick phase

`invariants` (8th phase — after `economy`, before `telemetry`). This is
one of the phases explicitly named in the fixed order, unlike `commands`
and `telemetry` (see their MODULE.md files).

## Public API

`invariants.gd`, `class_name Invariants`:
- `check_floor_selection(grid, column, scan_from_row, max_rows, chosen_floor_row, body_height_cells) -> FloorSelectionViolation`
  — pure, no logging. Returns a violation if a second real standing floor is
  visible inside the same scan window as the one already chosen, or `null`.
- `report_floor_selection(grid, column, scan_from_row, max_rows, chosen_floor_row, body_height_cells, seed, pos_x, pos_y) -> FloorSelectionViolation`
  — runs the check above and `push_error()`s if it fires (this module's own
  "log always, never `assert()`" policy — see the file header for why).

## Gotchas

- `push_error()`, not `assert()`, for every violation this module reports —
  `core/MODULE.md`'s documented hang hazard (an unguarded runtime error inside
  a bare `--headless --script` run never crashes, it hangs with no exit code)
  applies to a failed `assert()` exactly the same as any other runtime error.
  `docs/ARCHITECTURE.md` §9's "panic in debug, log in release" is read here as
  "surface it loudly," not "halt the process."
