class_name Invariants
extends RefCounted

## Continuous checking module (`sim/invariants/MODULE.md`): reads other submodules' state after
## they've acted, flags violations, produces no gameplay state itself. First real check: whether
## `sim/body`'s floor resolution picked between two competing standing surfaces without either of
## them knowing it -- `docs/adr/0005-heightfield-local-window.md` measured this at 0.85% of
## columns / 12% of shafts in real generated terrain (D0042), rare enough to accept as a documented
## limitation rather than build stateful floor tracking to eliminate. This check turns a silent
## "standing on the wrong floor, no error" bug report into a reproducible, position-and-seed-logged
## one, and gives a real-play incidence number to compare against the generated-terrain figure. The
## window this check is called with must actually be wide enough to see the case it exists to catch --
## `Body.FLOOR_SCAN_ROWS` (D0044) is sized from a real re-measurement of the row-gap distribution
## between genuinely-reachable stacked floors, not the original 6-row window, which could not see it
## by construction and reported zero regardless of real incidence.
##
## Known, not yet addressed: `report_floor_selection` logs on EVERY tick the condition holds, not once
## per episode -- a body resting on an ambiguous floor for N ticks produces N near-identical log lines
## (measured: ~390 lines from one ~400-tick settle in `tests/test_cave_geometry.gd`). This module is
## deliberately stateless (MODULE.md's own purpose: "produces no gameplay state itself"), so de-duplicating
## across ticks would need either caller-side state in `body.gd` or a design change here; flagged rather
## than fixed, since the case itself is sub-1% and this session's scope was the window, not log volume.
##
## `docs/ARCHITECTURE.md` §9: "Panic in debug, log in release." This file logs via `push_error()`
## unconditionally rather than `assert()`-ing, in both build types -- `core/MODULE.md`'s own
## documented gotcha: an unguarded runtime error inside a bare `--headless --script` run does not
## crash the process, it HANGS the whole run with no further output and no exit code (verified
## empirically, the same finding that shaped `Fx.div`'s zero-guard). An `assert()` failure is a
## runtime error by the same mechanism, so it carries the same hang risk in exactly the harness
## context invariant checks need to run cleanly under. `push_error()` already prints loudly (visible
## in both the editor debugger and a release log) without that risk, so "panic in debug" is read
## here as "surface it loudly," not "halt the process" -- a real, deliberate reinterpretation of that
## line, recorded because a literal panic would reintroduce a hazard this codebase already paid to
## discover once.


class FloorSelectionViolation:
	var column: int
	var chosen_floor_row: int
	var competing_floor_row: int
	var seed: int
	var pos_x: int  ## Fx
	var pos_y: int  ## Fx

	func _to_string() -> String:
		return ("Invariants: body resolved to floor row %d in column %d, but a second standing " +
			"surface (row %d) is also visible inside the same local scan window -- ambiguous floor " +
			"selection. seed=%d pos=(%d,%d)") % [chosen_floor_row, column, competing_floor_row, seed, pos_x, pos_y]


## `body_height_cells`/`step_up_cells` etc. are passed in rather than read from `Body`'s own
## constants -- this checking module has no reason to depend on `sim/body` (it would be the callee,
## not the caller, in every real use), so the caller hands over the numbers it already has.
##
## Detects whether `column`'s scan window [scan_from_row, scan_from_row + max_rows) can see more
## than one real standing floor: the one `_resolve_floor` actually chose (`chosen_floor_row`), and a
## second, DISTINCT one whose own boundary also falls inside that window and which has genuine
## clearance (>= body_height_cells of open air) above it, wherever that clearance actually ends --
## the clearance check is not itself bounded by the window, only the second floor's boundary row is,
## matching what makes a shelf actually walkable rather than a random thin ledge glimpsed in passing.
static func check_floor_selection(grid: TileGrid, column: int, scan_from_row: int, max_rows: int,
		chosen_floor_row: int, body_height_cells: int) -> FloorSelectionViolation:
	var window_end: int = scan_from_row + max_rows
	var row: int = chosen_floor_row + 1
	while row < window_end:
		if grid.is_solid(Vector2i(column, row)):
			var clearance: int = 0
			var probe: int = row - 1
			while probe >= 0 and not grid.is_solid(Vector2i(column, probe)):
				clearance += 1
				probe -= 1
			if clearance >= body_height_cells:
				var v: FloorSelectionViolation = FloorSelectionViolation.new()
				v.column = column
				v.chosen_floor_row = chosen_floor_row
				v.competing_floor_row = row
				return v
		row += 1
	return null


## Runs `check_floor_selection`, and if it fires, logs it (position/seed included) per this file's
## "log always, never assert" policy above. Returns the violation (or null) so a caller/test can
## also count occurrences without re-deriving them from log output.
static func report_floor_selection(grid: TileGrid, column: int, scan_from_row: int, max_rows: int,
		chosen_floor_row: int, body_height_cells: int, seed: int, pos_x: int, pos_y: int) -> FloorSelectionViolation:
	var v: FloorSelectionViolation = check_floor_selection(
		grid, column, scan_from_row, max_rows, chosen_floor_row, body_height_cells)
	if v != null:
		v.seed = seed
		v.pos_x = pos_x
		v.pos_y = pos_y
		push_error(v._to_string())
	return v
