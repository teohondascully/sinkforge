extends SceneTree

## Not a suite -- no `_finish()`, doesn't extend `test_base.gd`. Spawns a body at the chamber's own
## left edge (column 0) and holds continuous leftward pressure for 200 ticks, so
## `tests/test_bounds_invariant.gd::_test_sustained_pressure_against_a_boundary_reports_exactly_once()`
## can spawn this as a subprocess and grep its real stderr for how many times
## `Invariants.report_bounds` actually fired -- same reason `fixture_div_by_zero_probe.gd` and
## `fixture_settle_violation_probe.gd` exist: stock GDScript has no in-process way to count
## `push_error()` calls from the same script that made them.

const CELL: int = Heightfield.TERRAIN_CELL_PX


func _initialize() -> void:
	var grid: TileGrid = HostileChamber.build()
	var body: Body = Body.new(
		HostileChamber.SPAWN_START * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2,
		Fx.from_int(HostileChamber.FLOOR_ROW * CELL) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	var input: InputFrame = InputFrame.new()
	input.move_dir = -1
	for i: int in range(200):
		body.tick(input, grid)
	quit(0)
