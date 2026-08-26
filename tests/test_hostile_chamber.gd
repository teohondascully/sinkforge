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
	_test_jump_corner_present()
	_test_mantle_step_present()
	_test_narrow_shaft_present_and_correctly_wide()
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


func _test_jump_corner_present() -> void:
	# Not "tight relative to a floor" -- this obstruction lives entirely in the pit jump's rising
	# airspace, never above a walkable floor at all, so there is no floor-relative clearance to measure.
	# See `HostileChamber.JUMP_CORNER_COL`'s own comment for why THIS shape (a single cell only the jump
	# arc reaches) is the one corner correction can resolve, unlike this test's predecessor.
	var grid: TileGrid = HostileChamber.build()
	_check(grid.is_solid(Vector2i(HostileChamber.JUMP_CORNER_COL, HostileChamber.JUMP_CORNER_ROW)),
		"a corner obstruction exists in the pit jump's rising arc")
	_check(HostileChamber.JUMP_CORNER_COL >= HostileChamber.PIT_START - ScriptedTraverse.JUMP_RUNWAY_COLS and
		HostileChamber.JUMP_CORNER_COL < HostileChamber.PIT_END,
		"the corner sits within the jump's own column span, not off in unrelated terrain")
	_check(HostileChamber.JUMP_CORNER_ROW < HostileChamber.FLOOR_ROW - (Body.HEIGHT_PX / CELL),
		"the corner sits above the spawn floor's own headroom -- a grounded body never reaches it, only the jump's arc does")


func _test_mantle_step_present() -> void:
	var grid: TileGrid = HostileChamber.build()
	var before: int = Heightfield.column_surface_y(grid, HostileChamber.MANTLE_START - 1, 0, 40)
	var after: int = Heightfield.column_surface_y(grid, HostileChamber.MANTLE_START, 0, 40)
	var rise: int = before - after
	_check(rise == Fx.from_int(Body.MANTLE_PX),
		"the mantle step rises exactly two logic tiles (%dpx, got %dpx) -- taller than STEP_UP_PX (%dpx), so only a mantle hold clears it" %
		[Body.MANTLE_PX, rise / Fx.SCALE, Body.STEP_UP_PX])


func _test_narrow_shaft_present_and_correctly_wide() -> void:
	var grid: TileGrid = HostileChamber.build()
	# Sampled well above where the right wall deliberately stops (`Body.HEIGHT_PX` above the shaft floor,
	# so the body has full standing headroom to walk out) -- a row any lower would read the exit gap as
	# part of the shaft's own opening and over-count its width.
	var mid_row: int = HostileChamber.SHAFT_FLOOR_ROW - Body.HEIGHT_PX / CELL - 4
	var open_cols: int = 0
	for col: int in range(HostileChamber.SHAFT_START, HostileChamber.SHAFT_END):
		if not grid.is_solid(Vector2i(col, mid_row)):
			open_cols += 1
	_check(open_cols == HostileChamber.SHAFT_OPEN_COLS,
		"the shaft opening is exactly SHAFT_OPEN_COLS wide (%d terrain cols, got %d)" %
		[HostileChamber.SHAFT_OPEN_COLS, open_cols])
	# Confining walls actually exist with real width -- catches the exact bug found while building this:
	# the outer section bound once matched the opening's own width exactly, leaving zero-width walls.
	_check(grid.is_solid(Vector2i(HostileChamber.SHAFT_OPEN_START - 1, mid_row)),
		"a real wall exists immediately left of the shaft opening, not a zero-width margin")
	_check(grid.is_solid(Vector2i(HostileChamber.SHAFT_OPEN_END, mid_row)),
		"a real wall exists immediately right of the shaft opening, not a zero-width margin")
	_check(not grid.is_solid(Vector2i(HostileChamber.SHAFT_OPEN_START + 2, HostileChamber.SHAFT_FLOOR_ROW - 1)),
		"the shaft is genuinely open well below its top, not just a notch")
	# The exit past SHAFT_OPEN_END needs the body's FULL height of clearance to walk out standing up, not
	# just an opening at foot level -- a corridor tall enough for feet but not head reads as a wall the
	# instant the body is close enough to stand on the floor at all (the exact bug this test once missed).
	var exit_col: int = HostileChamber.SHAFT_OPEN_END + 1
	var clear_rows: int = 0
	for row: int in range(HostileChamber.SHAFT_FLOOR_ROW - 1, 0, -1):
		if grid.is_solid(Vector2i(exit_col, row)):
			break
		clear_rows += 1
	_check(clear_rows >= Body.HEIGHT_PX / CELL,
		"the exit past the shaft has a full body-height of clearance above its floor (got %d rows, need %d)" %
		[clear_rows, Body.HEIGHT_PX / CELL])
