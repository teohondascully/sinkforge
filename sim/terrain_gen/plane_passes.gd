class_name PlanePasses
extends RefCounted
## The two generation passes that write PLANES beside the terrain -- water and the deposit plane -- so
## they run on the `World`, after the grid, through `ShaftGenerator.enrich`: legacy `layered_world_gen.gd`
## `_seed_aquifers` and `_seed_aquifer_treasure` (:846-905), `_seed_lodes` and `_grow_lode` (:775-810).
## Ported in A' step 8e (D0385) onto the deterministic generator.
##
## An aquifer is an ellipse of solid rock carved open and filled to the brim, deep, refusing the cave band
## under every column; its rim seeds one vein, the reason to reach it. A lode is ore in the BACKGROUND
## wall, a vein grown through host rock cell by cell where each cell carries its own deposit; the sim
## reads both, the renderer thins the fleck field by what is left. Lodes run dead last, because every
## lode guard tests the final world and the aquifers carve rock away and flood it.
##
## Per-cell amounts follow `data/starts/tutorial.yaml`'s rule (D0353): legacy's per-metre stock divided
## by the cells in a metre square, so a lode that held 40 a metre holds 3 a cell here. Depth fractions
## are integers in thousandths, so a lode's size and amount are exact in the seed.

const MILLI: int = 1000
const ORTHO: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## Carve and flood the pockets. Returns {"pockets": n, "flooded": cells, "treasure": vein cells}.
static func seed_aquifers(world: World, rng: SplitRng, cfg: Dictionary, surface: PackedInt32Array,
		band: int, min_row: int, deep_row: int, cells_per_m: int) -> Dictionary:
	var grid: TileGrid = world.grid
	var out: Dictionary = {"pockets": 0, "flooded": 0, "treasure": 0}
	var count: int = maxi(2, CavePasses.count_for(grid.width, grid.height, float(cfg["per_col"]), cells_per_m))
	var hi_row: int = grid.height - 2 * cells_per_m
	if hi_row <= min_row:
		return out
	for _a: int in count:
		var cx: int = rng.next_range(3 * cells_per_m, grid.width - 4 * cells_per_m)
		var cy: int = rng.next_range(min_row, hi_row)
		var rx: int = rng.next_range(int(cfg["rx_min_m"]), int(cfg["rx_max_m"])) * cells_per_m
		var ry: int = rng.next_range(int(cfg["ry_min_m"]), int(cfg["ry_max_m"])) * cells_per_m
		var carved: Array[Vector2i] = []          # the cells this pocket flooded; its rim seeds the vein
		for dy: int in range(-ry, ry + 1):
			for dx: int in range(-rx, rx + 1):
				if dx * dx * ry * ry + dy * dy * rx * rx > rx * rx * ry * ry:
					continue
				var cell := Vector2i(cx + dx, cy + dy)
				if not grid.in_bounds(cell) or cell.y < surface[cell.x] + band or cell.y < min_row:
					continue
				if not grid.is_solid(cell):
					continue
				grid.excavate(cell)                                  # open the cell, wall kept behind it
				world.water.set_level(cell, WaterPlane.WATER_MAX)    # and fill it: it is not solid now
				carved.append(cell)
		out["pockets"] += 1
		out["flooded"] += carved.size()
		out["treasure"] += _treasure(world, rng, cfg, carved, min_row, deep_row, cells_per_m)
	return out


## One vein off the pocket's rim: a host-rock cell touching the water, grown from there, never above
## `min_row`. A pocket rimmed entirely by water or air seeds none.
static func _treasure(world: World, rng: SplitRng, cfg: Dictionary, carved: Array[Vector2i], min_row: int,
		deep_row: int, cells_per_m: int) -> int:
	if carved.is_empty():
		return 0
	var rim: Array[Vector2i] = []
	var seen: Dictionary = {}
	for wc: Vector2i in carved:
		for d: Vector2i in ORTHO:
			var nb: Vector2i = wc + d
			if seen.has(nb) or not world.grid.in_bounds(nb):
				continue
			seen[nb] = true
			if ShaftGenerator.HOST_ROCK.has(world.grid.get_material(nb)):
				rim.append(nb)
	if rim.is_empty():
		return 0
	var seed_cell: Vector2i = rim[rng.next_range(0, rim.size() - 1)]
	var size: int = rng.next_range(int(cfg["ore_size_min_m2"]), int(cfg["ore_size_max_m2"])) * cells_per_m * cells_per_m
	var material: StringName = &"ore_iron" if seed_cell.y >= deep_row else &"ore_copper"
	return ShaftGenerator.grow_vein(world.grid, rng, seed_cell, size, material, min_row)


## Depth below the datum in thousandths of the rock's height, clamped.
static func depth_permille(row: int, datum: int, height: int) -> int:
	return clampi((row - datum) * MILLI / maxi(1, height - 1 - datum), 0, MILLI)


## The lodes. Returns the cells seeded.
static func seed_lodes(world: World, rng: SplitRng, cfg: Dictionary, surface: PackedInt32Array, datum: int,
		deep_row: int, cells_per_m: int) -> int:
	var grid: TileGrid = world.grid
	var attempts: int = CavePasses.count_for(grid.width, grid.height, float(cfg["per_col"]), cells_per_m)
	var min_depth: int = int(cfg["min_depth_m"]) * cells_per_m
	var area: int = cells_per_m * cells_per_m
	var seeded: int = 0
	for _i: int in attempts:
		var cx: int = rng.next_range(0, grid.width - 1)
		var floor_row: int = surface[cx] + min_depth
		if floor_row >= grid.height - 1:
			continue
		var cy: int = rng.next_range(floor_row, grid.height - 1)
		var df: int = depth_permille(cy, datum, grid.height)
		var size: int = int(cfg["size_min_m2"]) * area + (df * int(cfg["size_depth_bonus_m2"]) * area + MILLI / 2) / MILLI
		# Legacy's per-metre stock, divided over the cells of a metre square (D0353's rule), at least one.
		var per_m: int = int(cfg["amount_base"]) * MILLI + df * int(cfg["amount_depth_bonus"])
		var amount: int = maxi(1, (per_m + MILLI * area / 2) / (MILLI * area))
		var material: StringName = &"ore_iron" if cy >= deep_row else &"ore_copper"
		seeded += grow_lode(world, rng, Vector2i(cx, cy), size, amount, material, surface, min_depth)
	return seeded


## Grow one lode as a compact accretion blob through host rock, each cell carrying `amount`: never above
## the column's `min_depth`, never where a lode already is, never in water. Returns cells seeded.
static func grow_lode(world: World, rng: SplitRng, terrain_seed: Vector2i, size: int, amount: int,
		material: StringName, surface: PackedInt32Array, min_depth: int) -> int:
	var grid: TileGrid = world.grid
	var filled: Dictionary = {}
	var frontier: Array[Vector2i] = [terrain_seed]
	var placed: int = 0
	while placed < size and not frontier.is_empty():
		var idx: int = rng.next_range(0, frontier.size() - 1)
		var cell: Vector2i = frontier[idx]
		frontier.remove_at(idx)
		if filled.has(cell) or not grid.in_bounds(cell) or cell.y < surface[cell.x] + min_depth:
			continue
		if not ShaftGenerator.HOST_ROCK.has(grid.get_material(cell)):
			continue                                # host rock only: never ore-like, never air
		if world.deposits.lode.has(cell) or world.water.water_at(cell) > 0:
			continue                                # one vein per cell and never inside an aquifer
		world.deposits.seed_lode(cell, material, amount)
		filled[cell] = true
		placed += 1
		for d: Vector2i in ORTHO:
			frontier.append(cell + d)
	return placed
