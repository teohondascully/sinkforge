extends "res://tests/test_base.gd"

## Verifies docs/ARCHITECTURE.md §9's sub-pixel heightfield derivation against hand-built TileGrid
## fixtures, checked against independently-computed expected values (not just "did it run").

const CELL: int = Heightfield.TERRAIN_CELL_PX


func _initialize() -> void:
	_test_flat_floor_reads_flat_everywhere()
	_test_single_cell_step_gives_1_2_3px_sub_pixel_rise()
	_test_column_centre_reads_its_own_height_exactly()
	_test_gap_returns_no_floor_not_an_average()
	_finish("heightfield")


func _test_flat_floor_reads_flat_everywhere() -> void:
	var grid: TileGrid = _flat_grid(10, 20)
	var want: int = Fx.from_int(10 * CELL)
	# Sample at column centres and at several sub-pixel offsets between them -- a flat floor must not
	# ripple just because the sample point isn't on a column boundary.
	for col: int in range(2, 8):
		var col_center: int = col * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2
		for offset_px: int in [0, 1, 2, 3]:
			var x: int = col_center + offset_px * Fx.SCALE
			var got: int = Heightfield.surface_y_at_x(grid, x, 0, 20)
			_check(got == want, "flat floor at col %d +%dpx == %d (got %d)" %
				[col, offset_px, want, got])


func _test_single_cell_step_gives_1_2_3px_sub_pixel_rise() -> void:
	# Columns 0..4 solid from row 10 (y=40px); columns 5+ solid from row 9 (y=36px) -- one cell higher,
	# the exact shape a real dig leaves at the edge of a ledge. The interpolation zone between column 4
	# and column 5's centres spans one full cell width (4px) and one full cell height (4px), a 1:1 ramp.
	var grid: TileGrid = TileGrid.new(20, 20, 1)
	for col: int in range(-2, 5):
		for row: int in range(10, 14):
			grid.set_material(Vector2i(col, row), &"hardrock")
	for col: int in range(5, 22):
		for row: int in range(9, 14):
			grid.set_material(Vector2i(col, row), &"hardrock")

	var col4_center: int = 4 * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2
	var y_low: int = Fx.from_int(10 * CELL)   # 40px, column 4's own height
	var y_high: int = Fx.from_int(9 * CELL)   # 36px, column 5's own height -- 4px higher

	_check(Heightfield.surface_y_at_x(grid, col4_center, 0, 20) == y_low,
		"column 4's own centre reads its own height (40px) exactly")
	for rise_px: int in [1, 2, 3]:
		var x: int = col4_center + rise_px * Fx.SCALE
		var want: int = y_low - rise_px * Fx.SCALE
		var got: int = Heightfield.surface_y_at_x(grid, x, 0, 20)
		_check(got == want, "single-cell step, %dpx into the ramp: height == %d (got %d)" %
			[rise_px, want, got])
	var col5_center: int = 5 * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2
	_check(Heightfield.surface_y_at_x(grid, col5_center, 0, 20) == y_high,
		"column 5's own centre reads its own height (36px) exactly, no blend leaking past the step")


func _test_column_centre_reads_its_own_height_exactly() -> void:
	var grid: TileGrid = _flat_grid(10, 20)
	# Punch one column one cell deeper -- if a centre-sample ever blended with a neighbour, this is the
	# fixture that would catch it: everything except column 10 stays exact.
	grid.set_material(Vector2i(10, 10), &"")
	var deep_center: int = 10 * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2
	var got: int = Heightfield.surface_y_at_x(grid, deep_center, 0, 20)
	_check(got == Fx.from_int(11 * CELL), "a dug column's own centre reads its own (deeper) height, not a blend")


func _test_gap_returns_no_floor_not_an_average() -> void:
	# A real pit: columns 8..12 have nothing solid within the scanned range at all. Sampling inside or
	# straddling the gap must return NO_FLOOR, never an averaged height with the solid ground beside it --
	# an average would read as a phantom platform floating over open air.
	var grid: TileGrid = _flat_grid(10, 20)
	for col: int in range(8, 13):
		for row: int in range(0, 20):
			grid.set_material(Vector2i(col, row), &"")
	var mid_pit: int = 10 * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2
	_check(Heightfield.surface_y_at_x(grid, mid_pit, 0, 20) == Heightfield.NO_FLOOR,
		"sampling inside a real gap returns NO_FLOOR")
	var edge: int = 7 * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2 + (CELL * Fx.SCALE) / 2
	_check(Heightfield.surface_y_at_x(grid, edge, 0, 20) == Heightfield.NO_FLOOR,
		"sampling straddling the gap's edge returns NO_FLOOR, not an average with the solid side")
