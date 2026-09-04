class_name StuddingPasses
extends RefCounted
## Rock put back so that open space has form, and the pass that judges what the others left behind:
## legacy `layered_world_gen.gd` `_stud_ledges` (:588-615), `_stud_spires` (:618-638), `_scatter_rubble`
## (:641-651), `_structural_rock`, `_open_cells` (:658-669) and `_seed_droughts` (:683-715). Ported in
## A' step 8d (D0384) onto the deterministic generator.
##
## Where an open cell sits against a side wall with air above, a short tongue of rock grows into the
## space; teeth hang from ceilings and rise from floors, tapering to a point; a loose block rests on a
## cave floor. Each takes the material of the rock it grows out of, and structure is rock: ore, coal and
## iron are rewards, so a ledge springing from a vein is hardrock. All three sample a SNAPSHOT of the
## open set so a ledge cannot seed another. Last, the drought pass: wherever a column has run too long
## through plain rock the generator owes something -- a make-up vein, or a vug, a cavity whose approach
## raises the pick's hollow ring -- planted back into the run just walked, so the break lands in the
## middle of the quiet rather than at the moment it was noticed. It reads the world it writes, so fixing
## one column also fixes its neighbours.
##
## Legacy's cell was a metre. Lengths, heights, headroom and the drought limit convert by the cells a
## metre; a per-cell chance (a spire per eligible ceiling cell, rubble per floor cell) is divided by it,
## because a metre of ceiling is four cells here and the rate is per metre of ceiling; a tooth or a block
## is a metre wide, as legacy's were, and a tooth tapers by the cell to a point.


## The material a structural block is built from: the rock it grows from, or the mid rock when that is a
## reward or nothing at all.
static func structural_rock(source: StringName) -> StringName:
	return source if ShaftGenerator.HOST_ROCK.has(source) else &"hardrock"


## Is this cell plain rock, meaning solid and made of nothing worth stopping for?
static func is_plain(grid: TileGrid, terrain_cell: Vector2i) -> bool:
	return ShaftGenerator.HOST_ROCK.has(grid.get_material(terrain_cell))


## Every open cell under the cave band, in a deterministic scan order: the snapshot the studding passes
## sample. Scans the grid instead of tracking carves, so it sees the union of every earlier pass.
static func open_terrain_cells(grid: TileGrid, surface: PackedInt32Array, band: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for col: int in grid.width:
		for row: int in range(surface[col] + band, grid.height - 1):
			var cell := Vector2i(col, row)
			if not grid.is_solid(cell):
				out.append(cell)
	return out


## Where an open cell sits against a solid side wall with air above, grow a tongue of rock into the
## space, a metre thick. Returns cells set.
static func stud_ledges(grid: TileGrid, rng: SplitRng, cfg: Dictionary, sites: Array[Vector2i],
		cells_per_m: int) -> int:
	var wanted: int = CavePasses.count_for(grid.width, grid.height, float(cfg["per_col"]), cells_per_m)
	var headroom: int = int(cfg["headroom_m"]) * cells_per_m
	var thick: int = maxi(1, int(cfg["thickness_m"]) * cells_per_m)
	var placed: int = 0
	for _i: int in wanted:
		if sites.is_empty():
			return placed
		var c: Vector2i = sites[rng.next_range(0, sites.size() - 1)]
		var dir: int = 0
		if grid.is_solid(c + Vector2i(-1, 0)):
			dir = 1                                   # wall on the left so the shelf grows right
		elif grid.is_solid(c + Vector2i(1, 0)):
			dir = -1
		if dir == 0:
			continue                                  # needs a wall to spring from
		if not _clear_above(grid, c, headroom):
			continue                                  # a shelf you cannot stand on is just fill
		var mat: StringName = structural_rock(grid.get_material(c + Vector2i(-dir, 0)))
		var run: int = rng.next_range(int(cfg["len_min_m"]), int(cfg["len_max_m"])) * cells_per_m
		for k: int in run:
			var cell: Vector2i = c + Vector2i(dir * k, 0)
			if not grid.in_bounds(cell) or grid.is_solid(cell):
				break
			for t: int in thick:
				placed += _set_if_open(grid, cell + Vector2i(0, t), mat)
	return placed


static func _clear_above(grid: TileGrid, c: Vector2i, headroom: int) -> bool:
	for h: int in range(1, headroom + 1):
		if grid.is_solid(c + Vector2i(0, -h)):
			return false
	return true


static func _set_if_open(grid: TileGrid, cell: Vector2i, mat: StringName) -> int:
	if not grid.in_bounds(cell) or grid.is_solid(cell):
		return 0
	grid.set_material(cell, mat)
	return 1


## Hang teeth from ceilings and raise them from floors, tapering to a point. Returns cells set.
static func stud_spires(grid: TileGrid, rng: SplitRng, cfg: Dictionary, sites: Array[Vector2i],
		cells_per_m: int) -> int:
	var chance: float = float(cfg["chance"]) / float(cells_per_m)
	var bias: float = float(cfg["floor_bias"])
	var placed: int = 0
	for c: Vector2i in sites:
		var down: bool = grid.is_solid(c + Vector2i(0, -1))
		var up: bool = grid.is_solid(c + Vector2i(0, 1))
		if down == up:
			continue                                  # a 1-cell gap between two solids grows nothing
		var hang: bool = down                         # solid above, so this tooth hangs from a ceiling
		if rng.next_float() > chance * (1.0 if hang else bias):
			continue
		var step: int = 1 if hang else -1
		var mat: StringName = structural_rock(grid.get_material(c + Vector2i(0, -step)))
		var run: int = (rng.next_range(int(cfg["hang_min_m"]), int(cfg["hang_max_m"])) if hang
			else rng.next_range(int(cfg["rise_min_m"]), int(cfg["rise_max_m"]))) * cells_per_m
		placed += _taper(grid, c, step, run, cells_per_m, mat)
	return placed


## A tooth `run` cells long from `c` in direction `step`, `width` cells across at the root and one at the
## tip, centred on the column. Stops at the first solid cell on the centre line.
static func _taper(grid: TileGrid, c: Vector2i, step: int, run: int, width: int, mat: StringName) -> int:
	var placed: int = 0
	for k: int in run:
		var cell: Vector2i = c + Vector2i(0, step * k)
		if not grid.in_bounds(cell) or grid.is_solid(cell):
			break
		var w: int = maxi(1, width - width * k / maxi(1, run))
		for dx: int in range(-(w / 2), w - w / 2):
			placed += _set_if_open(grid, cell + Vector2i(dx, 0), mat)
	return placed


## A single loose block, a metre square, resting on a cave floor with air above it. Returns cells set.
static func scatter_rubble(grid: TileGrid, rng: SplitRng, cfg: Dictionary, sites: Array[Vector2i],
		cells_per_m: int) -> int:
	var chance: float = float(cfg["chance"]) / float(cells_per_m)
	var size: int = maxi(1, int(cfg["size_m"]) * cells_per_m)
	var placed: int = 0
	for c: Vector2i in sites:
		if not grid.is_solid(c + Vector2i(0, 1)):
			continue                                  # must be resting on something
		if grid.is_solid(c + Vector2i(0, -1)):
			continue                                  # and with air above it, or it is just fill
		if rng.next_float() > chance:
			continue
		var mat: StringName = structural_rock(grid.get_material(c + Vector2i(0, 1)))
		for dx: int in size:
			var foot: Vector2i = c + Vector2i(dx - size / 2, 0)
			if not grid.is_solid(foot + Vector2i(0, 1)):
				continue                              # a metre block, but only over what holds it up
			for dy: int in size:
				placed += _set_if_open(grid, foot + Vector2i(0, -dy), mat)
	return placed


## No column may run dry. Returns {"vugs": n, "veins": n}.
static func seed_droughts(grid: TileGrid, rng: SplitRng, cfg: Dictionary, surface: PackedInt32Array,
		band: int, deep_row: int, cells_per_m: int) -> Dictionary:
	var limit: int = int(cfg["limit_m"]) * cells_per_m
	var back_lo: int = int(cfg["back_min_m"]) * cells_per_m
	var back_hi: int = int(cfg["back_max_m"]) * cells_per_m
	var size: int = int(cfg["vein_size_m2"]) * cells_per_m * cells_per_m
	var floors: PackedInt32Array = Relief.offset(surface, band)
	var counts: Dictionary = {"vugs": 0, "veins": 0}
	for col: int in grid.width:
		var run: int = 0
		for row: int in range(floors[col], grid.height):
			if not is_plain(grid, Vector2i(col, row)):
				run = 0
				continue
			run += 1
			if run < limit:
				continue
			# Plant back into the run just walked, so the break lands in the middle of the quiet.
			var at := Vector2i(col, row - rng.next_range(back_lo, back_hi))
			if rng.next_float() < float(cfg["vug_chance"]):
				CavePasses.carve_disc(grid, at, cells_per_m, floors)
				counts["vugs"] += 1
			else:
				var coal: bool = rng.next_float() < float(cfg["coal_bias"])
				var mat: StringName = &"coal" if coal else (&"ore_iron" if at.y >= deep_row else &"ore_copper")
				ShaftGenerator.grow_vein(grid, rng, at, size, mat)
				counts["veins"] += 1
			run = row - at.y
	return counts
