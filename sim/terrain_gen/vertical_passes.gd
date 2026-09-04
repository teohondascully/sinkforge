class_name VerticalPasses
extends RefCounted
## The vertical structure and the reason it is reachable: legacy `layered_world_gen.gd` `_carve_rifts`
## (:440-480), `_mineralize` (:565-585) and the sinkhole passes (`_open_sinkholes`, `_drop_below`,
## `_cut_throat`, :487-560). Ported in A' step 8c (D0383) onto the deterministic generator.
##
## A rift walks down from a start row, wandering slightly, its half-width breathing on a sine so that it
## pinches and opens; the cave band under every column's surface is refused, so no rift opens a chimney
## into spawn. Cut through finished rock, its walls show ore (`ore_rift_walls`). Then the mouths: every
## carve refuses the band under the surface, which also seals the underground under an unbroken lid, so
## a forty-metre chasm can sit in a sealed bottle. Each mouth is cut UP from a rift's ceiling to daylight,
## flared toward the sky, over the column with the tallest fall beneath it.
##
## Two of legacy's transcendental shapes live here and both are integer tables (D0381): the width sine
## reads `Relief.SIN_MILLI`; the flare `pow(up, 2.2)` reads `FLARE_MILLI`, 65 entries linearly
## interpolated. Positions are carried in thousandths of a cell, as legacy carried them in floats.
## Rates, lengths and widths come from the site's `vertical` record in legacy's own units.

const MILLI: int = 1000
const ORTHO: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## round(pow(i / 64, 2.2) * 1000) for i in 0..64: legacy `SINKHOLE_FLARE 2.2`, "above 1 keeps the throat
## narrow and opens the cone late (a collapse)". The exponent is the shape, not a balance number, so it
## is the table rather than a field; checked in `tests/test_vertical_passes.gd`.
const FLARE_MILLI: PackedInt32Array = [
	0, 0, 0, 1, 2, 4, 5, 8, 10, 13, 17, 21, 25, 30, 35, 41, 47, 54, 61, 69, 77, 86, 95, 105, 116, 126,
	138, 150, 162, 175, 189, 203, 218, 233, 249, 265, 282, 300, 318, 336, 356, 375, 396, 417, 439, 461,
	484, 507, 531, 556, 581, 607, 633, 660, 688, 716, 745, 775, 805, 836, 868, 900, 933, 966, 1000,
]


## pow(up / 1000, 2.2) in thousandths, `up` in 0..1000: the table entry either side, interpolated.
static func flare_milli(up: int) -> int:
	var u: int = clampi(up, 0, MILLI)
	var k: int = u * 64 / MILLI
	var r: int = u * 64 % MILLI
	var a: int = FLARE_MILLI[k]
	var b: int = FLARE_MILLI[mini(k + 1, 64)]
	return a + (b - a) * r / MILLI


## Carve the rifts; returns every cell inside one, open before or not, in carve order -- the list the
## wall ore and the mouths work from, so they can only touch a rift, never a cave beside one.
static func carve_rifts(grid: TileGrid, rng: SplitRng, cfg: Dictionary, surface: PackedInt32Array,
		cave_band: int, spawn_col: int, cells_per_m: int) -> Array[Vector2i]:
	var carved: Array[Vector2i] = []
	var count: int = maxi(2, CavePasses.count_for(grid.width, grid.height, float(cfg["per_col"]), cells_per_m))
	var keepout: int = int(cfg["spawn_keepout_m"]) * cells_per_m
	var margin_lo: int = 5 * cells_per_m
	var margin_hi: int = maxi(margin_lo, grid.width - 6 * cells_per_m)
	var wander: int = Relief.milli_cells(float(cfg["wander"]), 1)          # a slope: cells a row, dimensionless
	var nudge: int = Relief.milli_cells(float(cfg["wander_nudge"]), 1) / cells_per_m
	var half_min: int = Relief.milli_cells(float(cfg["half_w_min_m"]), cells_per_m)
	var half_max: int = Relief.milli_cells(float(cfg["half_w_max_m"]), cells_per_m)
	var pinch_lo: int = Relief.units(float(cfg["pinch_min"])) / cells_per_m
	var pinch_hi: int = Relief.units(float(cfg["pinch_max"])) / cells_per_m
	for _r: int in count:
		var x: int = rng.next_range(margin_lo, margin_hi) * MILLI
		# Push a rift that rolled too near spawn out to whichever side it already leans toward.
		if absi(x / MILLI - spawn_col) < keepout:
			var away: int = 1 if x / MILLI >= spawn_col else -1
			x = clampi(spawn_col + away * keepout, margin_lo, margin_hi) * MILLI
		var top: int = surface[x / MILLI] + cave_band \
			+ rng.next_range(int(cfg["top_min_m"]) * cells_per_m, int(cfg["top_max_m"]) * cells_per_m)
		var length: int = rng.next_range(int(cfg["min_len_m"]) * cells_per_m, int(cfg["max_len_m"]) * cells_per_m)
		var drift: int = rng.next_range(-wander, wander)
		var phase: int = rng.next_range(0, Relief.TURN - 1)
		var pinch: int = rng.next_range(pinch_lo, pinch_hi)      # how fast the width breathes down the fall
		for i: int in length:
			var row: int = top + i
			if row >= grid.height - 2 * cells_per_m:
				break
			# Width breathes on a sine, so the chasm reads as carved rather than extruded.
			var t: int = 500 + Relief.sin_milli(phase + i * pinch) / 2
			var half: int = half_min + (half_max - half_min) * t / MILLI
			_carve_row(grid, carved, surface, cave_band, row, (x - half) / MILLI, (x + half + MILLI - 1) / MILLI)
			x += drift
			drift = clampi(drift + rng.next_range(-nudge, nudge), -wander, wander)
			if x < 3 * cells_per_m * MILLI or x > (grid.width - 4 * cells_per_m) * MILLI:
				break
	return carved


## One row of a rift, columns `lo..hi` inclusive: the cave band under each column's own surface refused.
static func _carve_row(grid: TileGrid, carved: Array[Vector2i], surface: PackedInt32Array, cave_band: int,
		row: int, lo: int, hi: int) -> void:
	for col: int in range(lo, hi + 1):
		var cell := Vector2i(col, row)
		if not grid.in_bounds(cell) or row < surface[col] + cave_band:
			continue
		if grid.is_solid(cell):
			grid.excavate(cell)
		carved.append(cell)


## Enrich the host rock touching the carved cells: plain rock in a rift wall becomes ore at
## `wall_ore_chance` a metre of wall (the per-cell chance divides by the cells a metre), iron from
## `deep_row` down and copper above it (legacy gated the material by its seal; this build gates it by the
## same depth threshold iron itself uses). Legacy turned the one metre-cell; a single cell here is a
## four-pixel speck, so each turned cell grows a nugget of `wall_ore_size_m2` -- a metre square by default,
## which is the cell legacy turned (found by the ore-body pin at the switch-on, D0388). Returns ore cells.
static func ore_rift_walls(grid: TileGrid, rng: SplitRng, cfg: Dictionary, carved: Array[Vector2i],
		deep_row: int, cells_per_m: int) -> int:
	var chance: float = float(cfg["wall_ore_chance"]) / float(cells_per_m)
	var size: int = maxi(1, int(round(float(cfg["wall_ore_size_m2"]) * float(cells_per_m * cells_per_m))))
	var touched: Dictionary = {}
	var placed: int = 0
	for c: Vector2i in carved:
		for d: Vector2i in ORTHO:
			var cell: Vector2i = c + d
			if touched.has(cell) or not grid.in_bounds(cell):
				continue
			touched[cell] = true
			if not ShaftGenerator.HOST_ROCK.has(grid.get_material(cell)):
				continue
			if rng.next_float() < chance:
				var material: StringName = &"ore_iron" if cell.y >= deep_row else &"ore_copper"
				placed += ShaftGenerator.grow_vein(grid, rng, cell, size, material)
	return placed


## The mouths. Columns the rifts carved are ranked by the fall under the rift's ceiling, deepest first
## (ties leftmost), the spawn keepout excluded; up to `count` are opened, each at least `spacing_m` from
## the last, none over a fall shorter than `min_drop_m`. Returns the columns opened, in the order cut.
static func open_sinkholes(grid: TileGrid, rng: SplitRng, cfg: Dictionary, carved: Array[Vector2i],
		surface: PackedInt32Array, spawn_col: int, cells_per_m: int) -> Array[int]:
	var tops: Dictionary = {}                   # the highest open cell in each rift column: the ceiling
	for c: Vector2i in carved:
		if not tops.has(c.x) or c.y < int(tops[c.x]):
			tops[c.x] = c.y
	var cols: Array = tops.keys()
	cols.sort()
	var keepout: int = int(cfg["keepout_m"]) * cells_per_m
	var ranked: Array[Vector2i] = []
	for col: Variant in cols:
		var cx: int = col
		if absi(cx - spawn_col) < keepout:
			continue                            # the tutorial's ground stays solid
		ranked.append(Vector2i(cx, drop_below(grid, cx, int(tops[cx]))))
	ranked.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y > b.y if a.y != b.y else a.x < b.x)
	var opened: Array[int] = []
	var spacing: int = int(cfg["spacing_m"]) * cells_per_m
	var min_drop: int = int(cfg["min_drop_m"]) * cells_per_m
	for cand: Vector2i in ranked:
		if opened.size() >= int(cfg["count"]) or cand.y < min_drop:
			break                               # nothing left worth opening onto
		var clear: bool = true
		for prev: int in opened:
			if absi(cand.x - prev) < spacing:
				clear = false
		if not clear:
			continue
		opened.append(cand.x)
		cut_throat(grid, rng, cfg, cand.x, int(tops[cand.x]), surface, cells_per_m)
	return opened


## How far a body stepping in here would fall: the unbroken open run below the ceiling.
static func drop_below(grid: TileGrid, col: int, ceiling: int) -> int:
	var run: int = 0
	for row: int in range(ceiling, grid.height):
		if grid.is_solid(Vector2i(col, row)):
			break
		run += 1
	return run


## One flaring shaft from a rift's ceiling up through the lid to daylight. The fall line stays plumb: a
## cone drifting off the column the drop is under would put the mouth in one place and the fall in
## another, so the source column is opened at every row regardless. Returns cells opened.
static func cut_throat(grid: TileGrid, rng: SplitRng, cfg: Dictionary, col: int, rift_top: int,
		surface: PackedInt32Array, cells_per_m: int) -> int:
	var sky: int = surface[col]
	if rift_top <= sky + 2 * cells_per_m:
		return 0                                # already open enough to be its own mouth
	var wander: int = Relief.milli_cells(float(cfg["wander"]), 1)
	var nudge: int = Relief.milli_cells(float(cfg["wander_nudge"]), 1) / cells_per_m
	var throat: int = Relief.milli_cells(float(cfg["throat_half_m"]), cells_per_m)
	var mouth: int = Relief.milli_cells(float(cfg["mouth_half_m"]), cells_per_m)
	var x: int = col * MILLI
	var drift: int = rng.next_range(-wander, wander)
	var opened: int = 0
	for row: int in range(rift_top, sky - 1, -1):
		var up: int = MILLI - (row - sky) * MILLI / maxi(1, rift_top - sky)   # 0 at the rift, 1000 at the sky
		var half: int = throat + (mouth - throat) * flare_milli(up) / MILLI
		for c: int in range((x - half) / MILLI, (x + half + MILLI - 1) / MILLI + 1):
			opened += _open_mouth(grid, Vector2i(c, row))
		opened += _open_mouth(grid, Vector2i(col, row))
		x += drift
		drift = clampi(drift + rng.next_range(-nudge, nudge), -wander, wander)
	return opened


## Deliberately past the cave band, because this IS the mouth. Only a solid cell is excavated: the grid's
## running signature is an XOR of what is there, and excavating air would move it.
static func _open_mouth(grid: TileGrid, cell: Vector2i) -> int:
	if not grid.in_bounds(cell) or not grid.is_solid(cell):
		return 0
	grid.excavate(cell)
	return 1
