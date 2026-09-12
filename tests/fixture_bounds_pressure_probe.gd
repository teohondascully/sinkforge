extends SceneTree

## Not a suite -- no `_finish()`, doesn't extend `test_base.gd`. Spawns a body at the chamber's own
## left edge (column 0) and holds continuous leftward pressure for 200 ticks, so
## `tests/test_bounds_invariant.gd::_test_sustained_pressure_against_a_boundary_reports_exactly_once()`
## can spawn this as a subprocess and grep its real stderr for how many times
## `Invariants.report_bounds` actually fired -- same reason `fixture_div_by_zero_probe.gd` and
## `fixture_settle_violation_probe.gd` exist: stock GDScript has no in-process way to count
## `push_error()` calls from the same script that made them.
##
## The per-tick `_box_in_bounds` assertion (D0600) exists because of a measured hole: with
## `_enforce_grid_bounds`'s correction disabled, this probe produced a real out-of-bounds body for
## ~199 ticks and `test_bounds_invariant.gd` still reported ALL PASS -- the log-latch test counts
## REPORTS, not containment, and the containment tests in that suite exercise scenarios where
## `_try_step`'s preemptive refusal or the terrain itself holds the body in. This probe is the one
## scenario where the post-hoc clamp is the ONLY thing between the body and open boundary, so it is
## where that clamp's containment is actually asserted: a body seen outside the grid quits non-zero
## and the suite's `exit_code == 0` check fails on it.

const CELL: int = Heightfield.TERRAIN_CELL_PX


func _box_in_bounds(grid: TileGrid, body: Body) -> bool:
	return body._left_x() >= 0 and body._top_y() >= 0 and \
		body._right_x() <= grid.width * CELL * Fx.SCALE and body._bottom_y() <= grid.height * CELL * Fx.SCALE


func _initialize() -> void:
	var grid: TileGrid = HostileChamber.build()
	var body: Body = Body.new(
		HostileChamber.SPAWN_START * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2,
		Fx.from_int(HostileChamber.FLOOR_ROW * CELL) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	var input: InputFrame = InputFrame.new()
	input.move_dir = -1
	for i: int in range(200):
		body.tick(input, grid)
		if not _box_in_bounds(grid, body):
			print("OUT_OF_BOUNDS at tick %d pos=(%d,%d)" % [i, body.pos_x, body.pos_y])
			quit(2)
			return
	quit(0)
