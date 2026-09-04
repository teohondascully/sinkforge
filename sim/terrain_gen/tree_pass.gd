class_name TreePass
extends RefCounted
## Surface trees: legacy `layered_world_gen.gd` `_plant_trees` (:920-955), ported in A' step 8g (D0387)
## onto the deterministic generator. A trunk of `wood` two to three metres tall on solid ground with a
## canopy of `leaves` over it; at most one tree every `gap_m`, at `chance` a metre of ground, none over a
## cave mouth (a column whose surface cell is open) and none on the start's pad. Legacy's trunk was one
## metre-cell wide and its canopy six cells in a T over it; here the trunk is `trunk_w_m` wide and the
## canopy an ellipse `canopy_w_m` by `canopy_h_m`, by the cell, so a tree reads as one at this scale.
##
## Trees are blocks with no wall behind them, as legacy's were: dug, they leave sky.

const MILLI: int = 1000


## Plant the trees; returns how many. `keepout` is the first and last column, inclusive, no tree may root
## in -- the pad the start record is stamped onto and a margin about it.
static func plant(grid: TileGrid, rng: SplitRng, cfg: Dictionary, surface: PackedInt32Array, keepout: Vector2i,
		cells_per_m: int) -> int:
	var planted: int = 0
	var last: int = -grid.width
	var gap: int = int(cfg["gap_m"]) * cells_per_m
	var chance: float = float(cfg["chance"]) / float(cells_per_m)    # legacy's rate was a metre of ground
	var trunk_w: int = maxi(1, Relief.milli_cells(float(cfg["trunk_w_m"]), cells_per_m) / MILLI)
	var rx: int = maxi(1, Relief.milli_cells(float(cfg["canopy_w_m"]), cells_per_m) / (2 * MILLI))
	var ry: int = maxi(1, Relief.milli_cells(float(cfg["canopy_h_m"]), cells_per_m) / (2 * MILLI))
	for col: int in grid.width:
		if col >= keepout.x and col <= keepout.y:
			continue
		if col - last < gap or rng.next_float() > chance:
			continue
		var ground: int = surface[col]
		if not grid.is_solid(Vector2i(col, ground)):
			continue                                   # no solid surface here: a cave mouth or a rift
		var trunk: int = rng.next_range(int(cfg["trunk_min_m"]), int(cfg["trunk_max_m"])) * cells_per_m
		var top: int = ground - trunk                  # the row of the topmost trunk cell
		if top - 2 * ry < 0:
			continue                                   # not enough sky above for trunk and canopy
		if _blocked(grid, col, ground, trunk, trunk_w):
			continue                                   # a hill cell already occupies the trunk space
		for h: int in range(1, trunk + 1):
			for dx: int in trunk_w:
				grid.set_material(Vector2i(col + dx, ground - h), &"wood")
		_canopy(grid, Vector2i(col + trunk_w / 2, top - ry), rx, ry)
		last = col
		planted += 1
	return planted


static func _blocked(grid: TileGrid, col: int, ground: int, trunk: int, trunk_w: int) -> bool:
	for h: int in range(1, trunk + 1):
		for dx: int in trunk_w:
			var cell := Vector2i(col + dx, ground - h)
			if not grid.in_bounds(cell) or grid.is_solid(cell):
				return true
	return false


## Leaves in an integer ellipse about `centre`, only where there is nothing yet: the trunk stays wood.
static func _canopy(grid: TileGrid, centre: Vector2i, rx: int, ry: int) -> void:
	for dy: int in range(-ry, ry + 1):
		for dx: int in range(-rx, rx + 1):
			if dx * dx * ry * ry + dy * dy * rx * rx > rx * rx * ry * ry:
				continue
			var leaf: Vector2i = centre + Vector2i(dx, dy)
			if grid.in_bounds(leaf) and not grid.is_solid(leaf):
				grid.set_material(leaf, &"leaves")
