class_name Invariants
extends RefCounted

## Continuous checking module (`sim/invariants/MODULE.md`): reads other submodules' state after
## they've acted, flags violations, produces no gameplay state itself. First real check: whether
## `sim/body`'s floor resolution picked between two competing standing surfaces without either of
## them knowing it. First measured at 0.85% of columns / 12% of shafts in real generated terrain
## (D0042) -- since superseded: that terrain shape was substantially an artifact of a `ValueNoise`
## calibration bug (D0045), and the corrected generator measures 0 of 4,800 columns (D0046,
## `docs/adr/0005-heightfield-local-window.md` has the full finding, including why 0/4,800 is a null
## result at this sample's resolution, not proof the case cannot occur). This check turns a silent
## "standing on the wrong floor, no error" bug report into a reproducible, position-and-seed-logged
## one; its purpose now is not measuring a known cost but watching for this case to reappear after a
## future noise, threshold, or site-config change. The window this check is called with must actually
## be wide enough to see the case it exists to catch -- `Body.FLOOR_SCAN_ROWS` (D0044) is sized from a
## real re-measurement of the row-gap distribution between genuinely-reachable stacked floors, not the
## original 6-row window, which could not see it by construction and reported zero regardless of real
## incidence.
##
## `report_floor_selection` itself logs unconditionally, every call, by design -- it stays exactly as
## cheap and stateless as `check_floor_selection`, which this module's own MODULE.md requires ("produces
## no gameplay state itself"). Left unratelimited, a body resting on one ambiguous floor logs the
## identical violation on nearly every call to this check (measured by mutation-testing the caller's own
## gate: 778 push_errors from one ~400-tick settle in `tests/test_cave_geometry.gd`, not merely once per
## tick -- `body.gd::_move_and_resolve_vertical` calls `_resolve_floor` twice on most resting ticks),
## burying the signal it exists to produce. That de-duplication happens
## at the CALLER instead (`sim/body/body.gd::_resolve_floor()`, D0052): it already tracks the body's own
## position every tick, so it is where the memory of "already reported this (column, floor) pair"
## belongs, not here.
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


class BoundsViolation:
	var left: int  ## Fx, all six fields
	var top: int
	var right: int
	var bottom: int
	var grid_max_x: int
	var grid_max_y: int
	var seed: int
	var pos_x: int  ## Fx
	var pos_y: int  ## Fx

	func _to_string() -> String:
		return ("Invariants: body's own box [%d,%d)x[%d,%d) extends outside the grid's own [0,%d)x" +
			"[0,%d) -- left the world. seed=%d pos=(%d,%d)") % [left, right, top, bottom, grid_max_x,
			grid_max_y, seed, pos_x, pos_y]


## Second real check (D0055): whether the body's own AABB still fits inside the grid's declared
## extent. Bounds are handed over as plain Fx values (`grid_min_x`/`grid_min_y`/`grid_max_x`/
## `grid_max_y`), not a `TileGrid` plus a cell size, for the same reason `check_floor_selection`'s
## callers hand over their own constants: this module has no reason to know `sim/body`'s pixel
## scale or `Heightfield`'s cell size, only the box comparison itself. Found live, not by design
## review: a chained auto-step-up/mantle (`body.gd::_try_step`, no bound of its own) launched a real
## `--play` session's body to y=-15.85px, well above row 0 -- `docs/DECISIONS_LEDGER.md` has the
## full root-cause trace. This is the diagnostic half of that fix: `body.gd` now also clamps the
## body back inside the grid every tick (the actual fix), and this check exists so a FUTURE
## regression that reopens some other path out of the world is still loud, not a silent clamp.
static func check_bounds(grid_min_x: int, grid_min_y: int, grid_max_x: int, grid_max_y: int,
		left: int, top: int, right: int, bottom: int) -> BoundsViolation:
	if left >= grid_min_x and top >= grid_min_y and right <= grid_max_x and bottom <= grid_max_y:
		return null
	var v: BoundsViolation = BoundsViolation.new()
	v.left = left
	v.top = top
	v.right = right
	v.bottom = bottom
	v.grid_max_x = grid_max_x
	v.grid_max_y = grid_max_y
	return v


## Runs `check_bounds`, and if it fires, logs it -- same "log always, never assert" policy as
## `report_floor_selection`.
static func report_bounds(grid_min_x: int, grid_min_y: int, grid_max_x: int, grid_max_y: int,
		left: int, top: int, right: int, bottom: int, seed: int, pos_x: int, pos_y: int) -> BoundsViolation:
	var v: BoundsViolation = check_bounds(grid_min_x, grid_min_y, grid_max_x, grid_max_y, left, top, right, bottom)
	if v != null:
		v.seed = seed
		v.pos_x = pos_x
		v.pos_y = pos_y
		push_error(v._to_string())
	return v
