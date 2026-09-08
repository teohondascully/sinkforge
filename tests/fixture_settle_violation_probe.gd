extends SceneTree

## Not a suite -- no `_finish()`, doesn't extend `test_base.gd`. Holds a body in THE ONE GEOMETRY the
## floor-selection check has a subject in (D0516) for `HOLD_TICKS` ticks, as a standalone script
## `tests/test_floor_ambiguity.gd` spawns as a subprocess and greps for how many times
## `Invariants.report_floor_selection` actually fired (D0052) -- the same reason
## `fixture_div_by_zero_probe.gd` exists: stock GDScript has no in-process way to count `push_error()`
## calls from the same script that made them. Before D0516 this probe settled a body onto
## `HostileChamber`'s cave shelf, 16 rows over a lower floor; that is not an ambiguous choice (the feet
## never reached the lower floor) and the check no longer reports it, so the probe poses the case that is.
##
## THE GEOMETRY. A shelf one terrain cell thick across the whole grid, one open cell, then a floor.
## `resolve_floor` scans from two rows above the feet, so a body whose feet are on the FLOOR with the
## shelf through its shins has reached both surfaces, and the resolver -- which takes the topmost -- lifts
## it onto the shelf: the floor it was standing on was the other candidate. That is the whole of what
## "ambiguous" means for this resolver, and the only shape of it: the two surfaces must be exactly two
## rows apart (a thick floor's own second row is interior, not a surface), inside the scan's two-row
## lookback. The shelf spans the grid because the horizontal pass, finding a still body's box inside
## rock, pushes it sideways by up to a cell a column (`HorizontalResolve._resolve_cell`, D0059) before the
## vertical pass runs; a one-cell shelf would be escaped that way and the check would never see it.
##
## `pose` is applied EVERY tick, not once: the first tick's landing lifts the body onto the shelf and the
## next tick's window no longer reaches the floor, so holding the condition means re-embedding the body.
## That is what lets this probe measure the caller's rate limit (D0052): one report over HOLD_TICKS
## landings on the same (column, floor) pair with the gate, HOLD_TICKS without it.

const CELL: int = Heightfield.TERRAIN_CELL_PX
const WIDTH_COLS: int = 96
const LEDGE_ROW: int = 40
const FLOOR_ROW: int = LEDGE_ROW + 2   ## one open cell between: two surfaces a cell apart
const HOLD_TICKS: int = 30


static func build_grid() -> TileGrid:
	var grid: TileGrid = TileGrid.new(WIDTH_COLS, FLOOR_ROW + 12, 20260907)
	for col: int in WIDTH_COLS:
		grid.set_material(Vector2i(col, LEDGE_ROW), &"hardrock")
		for row: int in range(FLOOR_ROW, FLOOR_ROW + 6):
			grid.set_material(Vector2i(col, row), &"hardrock")
	return grid


## Feet exactly on `floor_row`'s top face, mid-grid, at rest. With `FLOOR_ROW` the shelf runs through the
## shins (the ambiguous pose); with `LEDGE_ROW` the body stands on the shelf and the floor is below its
## feet (the control: the same two surfaces, only one of them reached).
static func pose(body: Body, floor_row: int) -> void:
	body.pos_x = (WIDTH_COLS / 2) * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2
	body.pos_y = Fx.from_int(floor_row * CELL) - (Body.HEIGHT_PX * Fx.SCALE) / 2
	body.vel_x = 0
	body.vel_y = 0


func _initialize() -> void:
	var grid: TileGrid = build_grid()
	var body: Body = Body.new(0, 0)
	var flagged: int = 0
	for i: int in HOLD_TICKS:
		pose(body, FLOOR_ROW)
		body.tick(InputFrame.new(), grid)
		if body.floor_selection_violation_this_tick:
			flagged += 1
	print("SETTLE_VIOLATION_PROBE ticks=%d flagged_ticks=%d" % [HOLD_TICKS, flagged])
	quit(0)
