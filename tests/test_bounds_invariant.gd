extends "res://tests/test_base.gd"

## D0055. `Invariants.check_bounds`/`report_bounds`, and `body.gd::_enforce_grid_bounds()`, which is
## the actual fix -- root-caused from a real out-of-bounds launch the director hit in the first
## `--play` session: `_try_step` (auto step-up and mantle both call it) moves the body by `lift` with
## no check against the grid's own extent, so holding move+jump+mantle against the shaft wall chains
## repeated mantles with no cap on how many fire in a row, reaching y=-15.85px (well above row 0) in
## a real session and reproduced here in 4 ticks flat from a standing start. Not mantle-specific: a
## plain unassisted jump from any sufficiently high floor can reach the same place on its own --
## nothing bounded vertical (or horizontal) movement against the world's own declared size at all.

const CELL: int = Heightfield.TERRAIN_CELL_PX


func _initialize() -> void:
	_test_check_bounds_negative_control_fully_inside()
	_test_check_bounds_detects_left_violation()
	_test_check_bounds_detects_top_violation()
	_test_check_bounds_detects_right_violation()
	_test_check_bounds_detects_bottom_violation()
	_test_the_real_shaft_wall_mantle_chain_no_longer_leaves_the_grid()
	_test_sustained_pressure_against_a_boundary_reports_exactly_once()
	_test_a_staircase_of_short_ledges_cannot_be_chain_mantled_past_the_top()
	_finish("bounds_invariant")


func _test_check_bounds_negative_control_fully_inside() -> void:
	var v: Invariants.BoundsViolation = Invariants.check_bounds(0, 0, 1000, 1000, 10, 10, 20, 20)
	_check(v == null, "a box fully inside [0,1000)x[0,1000) is not a violation")


func _test_check_bounds_detects_left_violation() -> void:
	var v: Invariants.BoundsViolation = Invariants.check_bounds(0, 0, 1000, 1000, -5, 10, 20, 20)
	_check(v != null, "left=-5 (below grid_min_x=0) is a violation")


func _test_check_bounds_detects_top_violation() -> void:
	var v: Invariants.BoundsViolation = Invariants.check_bounds(0, 0, 1000, 1000, 10, -5, 20, 20)
	_check(v != null, "top=-5 (below grid_min_y=0) is a violation")


func _test_check_bounds_detects_right_violation() -> void:
	var v: Invariants.BoundsViolation = Invariants.check_bounds(0, 0, 1000, 1000, 990, 10, 1005, 20)
	_check(v != null, "right=1005 (above grid_max_x=1000) is a violation")


func _test_check_bounds_detects_bottom_violation() -> void:
	var v: Invariants.BoundsViolation = Invariants.check_bounds(0, 0, 1000, 1000, 10, 10, 20, 1005)
	_check(v != null, "bottom=1005 (above grid_max_y=1000) is a violation")


func _box_in_bounds(grid: TileGrid, body: Body) -> bool:
	return body._left_x() >= 0 and body._top_y() >= 0 and \
		body._right_x() <= grid.width * CELL * Fx.SCALE and body._bottom_y() <= grid.height * CELL * Fx.SCALE


## The exact glitch: spawn next to the shaft's left wall, hold move+jump+mantle continuously.
## Reproduced (before the fix existed) 4 ticks in -- min row reached -1.19, well above row 0.
func _test_the_real_shaft_wall_mantle_chain_no_longer_leaves_the_grid() -> void:
	var grid: TileGrid = HostileChamber.build()
	var col: int = HostileChamber.SHAFT_START - 1
	var body: Body = Body.new(
		col * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2,
		Fx.from_int(HostileChamber.FLOOR_ROW * CELL) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	var input: InputFrame = InputFrame.new()
	input.move_dir = 1
	input.jump_held = true
	input.jump_pressed = true
	input.mantle_hold = true
	var ever_out_of_bounds: bool = false
	for i: int in range(600):
		body.tick(input, grid)
		input.jump_pressed = false
		if not _box_in_bounds(grid, body):
			ever_out_of_bounds = true
	_check(not ever_out_of_bounds,
		"holding move+jump+mantle against the shaft wall for 600 ticks never leaves the grid's own [0,%d)x[0,%d) (Fx px)" %
		[grid.width * CELL * Fx.SCALE, grid.height * CELL * Fx.SCALE])
	_check(body.on_floor, "settles on a real floor afterward rather than hanging mid-air or oscillating")


## A guard's own real integration test can be accidentally satisfied by the SPECIFIC obstacle it
## exercises being shorter than whatever margin the level happens to carry that day
## (`docs/QUALITY.md` §2's own documented failure class: "a guard whose trigger condition normal
## execution rarely reaches will survive being deliberately broken"). The real shaft wall test above
## uses a wall only ~32 rows tall (`Body.MANTLE_PX`/`CELL` x 4 logic-tile segments) -- shorter than
## `HostileChamber.TOP_MARGIN_ROWS` (40), so the wall's OWN finite height, not `_try_step`'s preemptive
## top-boundary refusal, is what actually stops that particular chain from crossing row 0; verified
## directly by disabling both `body.gd::_enforce_grid_bounds`'s call and `_try_step`'s
## `_top_y() - lift < 0` check and re-running that test alone -- it stayed green.
##
## A single monolithic wall taller than the body's own height doesn't reproduce the chain either, for a
## different reason: `_resolve_horizontal`'s per-cell scan starts at the body's own TOPMOST overlapped
## row, and once a wall extends above the body's own head at every position (as a tall monolith does by
## construction), THAT row's own `lift` is always ~`Body.HEIGHT_PX`, already past `MANTLE_PX` -- it
## depenetrates and zeroes `vel_x` before a shorter, climbable row ever gets examined. Verified directly
## (a traced probe against exactly this shape never produced a single `mantled_this_tick`).
##
## What the real bug needs -- and what actually reproduces it -- is a STAIRCASE: repeated short ledges,
## each exactly `MANTLE_PX` above the last and reachable from the side, so every new resting height sees
## the SAME small `lift` the one before it did. A 40-step version of this (traced directly) climbs
## cleanly, 8 rows per successful mantle, with no cap of its own -- which is exactly the defect: nothing
## bounds how many of these a continuous walk can chain, so the total climb is set by however many steps
## the level happens to place, not by anything in the controller. Sized so an UNCAPPED climb (verified:
## disabling the fix here reaches top row ~-14) would cross row 0 by a wide margin, and a capped one
## (12 steps, reaching top row 2) stops just short of it.
func _test_a_staircase_of_short_ledges_cannot_be_chain_mantled_past_the_top() -> void:
	var width: int = 260
	var height: int = 200
	var base_floor_row: int = 100
	var grid: TileGrid = TileGrid.new(width, height, 1)
	for col: int in range(0, 6):
		for row: int in range(base_floor_row, base_floor_row + 6):
			grid.set_material(Vector2i(col, row), &"hardrock")
	var step_row: int = base_floor_row - Body.MANTLE_PX / CELL
	var step_col: int = 6
	for i: int in range(40):
		for col: int in range(step_col, step_col + 6):
			for row: int in range(step_row, step_row + 6):
				grid.set_material(Vector2i(col, row), &"hardrock")
		step_row -= Body.MANTLE_PX / CELL
		step_col += 6
	var body: Body = Body.new(
		3 * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2,
		Fx.from_int(base_floor_row * CELL) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	var input: InputFrame = InputFrame.new()
	input.move_dir = 1
	input.mantle_hold = true
	var ever_out_of_bounds: bool = false
	for i: int in range(600):
		body.tick(input, grid)
		if not _box_in_bounds(grid, body):
			ever_out_of_bounds = true
	_check(not ever_out_of_bounds,
		"walking a 40-step mantle staircase (each step MANTLE_PX above the last, spanning 320 rows -- far past row 0 from a floor at row 100 if uncapped) never leaves the grid's declared [0,%d)x[0,%d)" %
		[grid.width, grid.height])


## D0052's pattern applied to a second guard: pin the body against the world's own left edge with
## continuous leftward pressure for many ticks (spawn is column 0 -- the grid's own left edge) and
## prove two things at once: the correction actually holds (every tick, not just the first), and the
## report stays a single line for one continuous episode rather than firing every tick pressure is
## still being applied -- the same log-volume failure class D0052 fixed for the floor-selection guard.
func _test_sustained_pressure_against_a_boundary_reports_exactly_once() -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(),
		["--headless", "--path", project_root, "--script", "res://tests/fixture_bounds_pressure_probe.gd"],
		output, true)
	_check(exit_code == 0, "the probe subprocess itself exits cleanly (got %d)" % exit_code)
	var combined: String = "\n".join(output)
	# D0115/D0117: exit_code==0 is not enough on its own -- a mid-run SCRIPT ERROR could abort the
	# 200-tick pressure loop early, before it ever reaches the one occurrence this test expects, and
	# a subsequent unrelated occurrence could still land the count on exactly 1 by coincidence.
	_check(not combined.contains("SCRIPT ERROR:"),
		"the probe's own output contains no SCRIPT ERROR (docs/DECISIONS_LEDGER.md D0117)")
	var occurrences: int = combined.count("left the world")
	_check(occurrences == 1,
		"200 ticks of continuous leftward pressure against column 0 logs the violation exactly ONCE, not once per tick -- got %d occurrences (captured output: %s)" %
		[occurrences, combined])
