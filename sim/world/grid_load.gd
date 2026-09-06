class_name GridLoad
extends RefCounted

## THE BULK PATH ONTO A TILE GRID (D0397). A restore's 480K cells were 1.2 s through `set_material` and
## `set_wall`, each of which folds the signature term twice and re-derives the sky floor and the coarse
## class on every stamp; the generator's base fill paid the same. This writes both layers in one pass
## each, folds the term once per occupied cell, and rebuilds the two derived planes once at the end.
##
## The result is identical to writing every cell through `set_material` then `set_wall` in the same
## order: the same dictionaries, the same index bytes and legend, the same sky floor and coarse plane,
## and the same signature -- XOR is order-free, and `tests/test_tile_grid.gd` pins the equality against
## the per-cell writers AND against the grid's own from-scratch rebuild. Static over the grid rather than
## a method on it so `tile_grid.gd` stays under its cap; it reaches the grid's planes the way the grid's
## own methods do.


## False, having touched nothing, on a grid that already holds cells: the per-cell writers are the path then.
static func load_cells(grid: TileGrid, blocks: Dictionary, walls: Dictionary) -> bool:
	if not grid._blocks.is_empty() or not grid._walls.is_empty():
		return false
	grid._blocks = blocks.duplicate()
	grid._walls = walls.duplicate()
	var a: int = 0
	var b: int = 0
	var w: int = grid.width
	for cell: Vector2i in grid._blocks:
		var m: StringName = grid._blocks[cell]
		var t: Vector2i = StateHash.term(cell.x, cell.y, StateHash.id_fold(m), StateHash.id_fold(grid._walls.get(cell, &"")))
		a ^= t.x
		b ^= t.y
		if grid.in_bounds(cell):
			grid.block_index[cell.y * w + cell.x] = grid.ordinal_of(m)
	for cell: Vector2i in grid._walls:
		if grid.in_bounds(cell):
			grid.wall_index[cell.y * w + cell.x] = grid.ordinal_of(grid._walls[cell])
	grid._xor_term(Vector2i(a, b))
	grid._solidity_all = true   # a whole grid arrived: the solidity log names nothing, it says `all`
	rebuild_sky_floor(grid)
	rebuild_coarse(grid)
	return true


## The sky floor from the block plane: the first solid row down each column, or `height`.
static func rebuild_sky_floor(grid: TileGrid) -> void:
	var w: int = grid.width
	for col: int in w:
		var r: int = 0
		while r < grid.height and grid.block_index[r * w + col] == 0:
			r += 1
		grid.sky_floor[col] = r


## Every logic cell's class from its centre terrain cell, the way `TileGrid._coarse_refresh` classes one write.
static func rebuild_coarse(grid: TileGrid) -> void:
	var n: int = LogicGrid.TERRAIN_PER_LOGIC
	var changed: bool = false
	for cy: int in grid.coarse_height:
		for cx: int in grid.coarse_width:
			var centre := Vector2i(cx * n + TileGrid.COARSE_CENTRE, cy * n + TileGrid.COARSE_CENTRE)
			if not grid.in_bounds(centre):
				continue
			var i: int = cy * grid.coarse_width + cx
			var cls: int = grid.coarse_class_of(centre)
			if grid.coarse[i] != cls:
				grid.coarse[i] = cls
				changed = true
	if changed:
		grid.coarse_version += 1
