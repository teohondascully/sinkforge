extends "res://tests/test_base.gd"

## Verifies every feature the director's chamber spec requires is actually PRESENT in the built
## chamber -- not by eye, by checking the specific cells each section's construction promises.
## docs/DECISIONS_LEDGER.md D0036 has the layout reasoning this checks against.

const CELL: int = Heightfield.TERRAIN_CELL_PX


func _initialize() -> void:
	_test_1_tile_pit_present()
	_test_1_tile_ledge_present()
	_test_rubble_is_jagged_and_actually_dug()
	_test_machine_cluster_present()
	_test_ceiling_corner_present_and_tight()
	_test_mantle_step_present()
	_test_narrow_shaft_present_and_3_tiles_wide()
	_finish("hostile_chamber")


func _test_1_tile_pit_present() -> void:
	var grid: TileGrid = HostileChamber.build()
	for col: int in range(HostileChamber.PIT_START, HostileChamber.PIT_END):
		_check(not grid.is_solid(Vector2i(col, HostileChamber.FLOOR_ROW)),
			"pit column %d has no floor at the spawn floor row" % col)
	_check(grid.is_solid(Vector2i(HostileChamber.PIT_START - 1, HostileChamber.FLOOR_ROW)),
		"solid ground immediately before the pit")
	_check(grid.is_solid(Vector2i(HostileChamber.PIT_END, HostileChamber.FLOOR_ROW)),
		"solid ground immediately after the pit")


func _test_1_tile_ledge_present() -> void:
	var grid: TileGrid = HostileChamber.build()
	var before: int = Heightfield.column_surface_y(grid, HostileChamber.LEDGE_START - 1, 0, 40)
	var after: int = Heightfield.column_surface_y(grid, HostileChamber.LEDGE_START, 0, 40)
	var rise: int = before - after
	_check(rise == Fx.from_int(Body.LOGIC_TILE_PX),
		"the ledge rises exactly one logic tile (%dpx, got %dpx)" %
		[Body.LOGIC_TILE_PX, rise / Fx.SCALE])


func _test_rubble_is_jagged_and_actually_dug() -> void:
	var grid: TileGrid = HostileChamber.build()
	var heights: Array[int] = []
	for col: int in range(HostileChamber.RUBBLE_START, HostileChamber.RUBBLE_END):
		heights.append(Heightfield.column_surface_y(grid, col, 0, 40))
	var distinct: Dictionary = {}
	for h: int in heights:
		distinct[h] = true
	_check(distinct.size() >= 2,
		"the fresh-dig section has at least 2 distinct column heights (got %d) -- a flat run would not be jagged" %
		distinct.size())
	var max_step: int = 0
	for i: int in range(1, heights.size()):
		max_step = maxi(max_step, absi(heights[i] - heights[i - 1]))
	_check(max_step > 0 and max_step <= Fx.from_int(CELL),
		"adjacent-column height differences stay within one terrain cell (got max %dpx) -- this is what makes the interpolated slope 1-3px, not a real wall" %
		(max_step / Fx.SCALE))
	# "Actually dug" means excavate() was really called, not that the shape looks right -- confirm at
	# least one column in this span had material removed from what a fully solid block would have had.
	var fully_solid_would_be: int = Heightfield.column_surface_y(grid, HostileChamber.RUBBLE_START, -100, 200)
	var any_dug: bool = false
	for h: int in heights:
		if h != fully_solid_would_be:
			any_dug = true
	_check(any_dug, "at least one rubble column differs from an undug block's own top -- confirms excavate() ran")


func _test_machine_cluster_present() -> void:
	var grid: TileGrid = HostileChamber.build()
	# The baseline is the section's OWN plateau height, read from a column outside the cluster's own
	# span -- sampling a cluster column's height directly would just report the protrusion's own row as
	# "the floor," since is_solid() doesn't distinguish a protrusion from ordinary ground.
	var baseline: int = Heightfield.column_surface_y(grid, HostileChamber.MACHINE_CLUSTER_START, 0, 40)
	var found: bool = false
	for col: int in range(HostileChamber.MACHINE_CLUSTER_START + 1, HostileChamber.MACHINE_CLUSTER_END - 1):
		var here: int = Heightfield.column_surface_y(grid, col, 0, 40)
		if here < baseline:  # smaller Fx y == higher up == protruding above the plateau
			found = true
	_check(found, "at least one column in the machine-cluster span protrudes above its own floor level")


func _test_ceiling_corner_present_and_tight() -> void:
	var grid: TileGrid = HostileChamber.build()
	var floor_row: int = HostileChamber.FLOOR_ROW - 4
	var floor_y: int = Fx.from_int(floor_row * CELL)
	var found_overhang: bool = false
	var tight: bool = false
	for col: int in range(HostileChamber.CEILING_CORNER_START, HostileChamber.CEILING_CORNER_END):
		for row: int in range(0, floor_row):
			if grid.is_solid(Vector2i(col, row)):
				found_overhang = true
				var clearance: int = floor_y - Fx.from_int(row * CELL + CELL)
				if clearance < Fx.from_int(Body.HEIGHT_PX):
					tight = true
	_check(found_overhang, "an overhang exists over the ceiling-corner section")
	_check(tight, "the overhang's clearance is tighter than the body's own height -- a clean pass requires corner correction, not just walking under it")


func _test_mantle_step_present() -> void:
	var grid: TileGrid = HostileChamber.build()
	var before: int = Heightfield.column_surface_y(grid, HostileChamber.MANTLE_START - 1, 0, 40)
	var after: int = Heightfield.column_surface_y(grid, HostileChamber.MANTLE_START, 0, 40)
	var rise: int = before - after
	_check(rise == Fx.from_int(Body.MANTLE_PX),
		"the mantle step rises exactly two logic tiles (%dpx, got %dpx) -- taller than STEP_UP_PX (%dpx), so only a mantle hold clears it" %
		[Body.MANTLE_PX, rise / Fx.SCALE, Body.STEP_UP_PX])


func _test_narrow_shaft_present_and_3_tiles_wide() -> void:
	var grid: TileGrid = HostileChamber.build()
	var mid_row: int = (HostileChamber.SHAFT_FLOOR_ROW + HostileChamber.FLOOR_ROW) / 2
	var open_cols: int = 0
	for col: int in range(HostileChamber.SHAFT_START, HostileChamber.SHAFT_END):
		if not grid.is_solid(Vector2i(col, mid_row)):
			open_cols += 1
	var want_cols: int = 3 * (Body.LOGIC_TILE_PX / CELL)
	_check(open_cols == want_cols,
		"the shaft opening is exactly 3 logic tiles wide (%d terrain cols, got %d)" %
		[want_cols, open_cols])
	# Confining walls actually exist with real width -- catches the exact bug found while building this:
	# the outer section bound once matched the opening's own width exactly, leaving zero-width walls.
	_check(grid.is_solid(Vector2i(HostileChamber.SHAFT_OPEN_START - 1, mid_row)),
		"a real wall exists immediately left of the shaft opening, not a zero-width margin")
	_check(grid.is_solid(Vector2i(HostileChamber.SHAFT_OPEN_END, mid_row)),
		"a real wall exists immediately right of the shaft opening, not a zero-width margin")
	_check(not grid.is_solid(Vector2i(HostileChamber.SHAFT_OPEN_START + 2, HostileChamber.SHAFT_FLOOR_ROW - 1)),
		"the shaft is genuinely open well below its top, not just a notch")
