extends SceneTree

## Not a suite -- no `_finish()`, doesn't extend `test_base.gd`. Reproduces
## `tests/test_cave_geometry.gd`'s own `_settle()` fixture (drop onto the ambiguous shelf, 400 ticks)
## as a standalone script `tests/test_cave_geometry.gd::_test_a_real_settle_rate_limits_the_guard_to_
## one_report()` can spawn as a subprocess and grep its stderr for how many times
## `Invariants.report_floor_selection` actually fired (D0052) -- the same reason
## `fixture_div_by_zero_probe.gd` exists: stock GDScript has no in-process way to count `push_error()`
## calls from the same script that made them.

const CELL: int = Heightfield.TERRAIN_CELL_PX


func _initialize() -> void:
	var grid: TileGrid = HostileChamber.build()
	var col: int = HostileChamber.CAVE_OVERHANG_START + 1
	var pos_x: int = col * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2
	var body: Body = Body.new(pos_x, Fx.from_int(12 * CELL))
	for i: int in range(400):
		body.tick(InputFrame.new(), grid)
	quit(0)
