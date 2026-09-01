class_name TestCarveProbe
extends RefCounted

## THE CARVE WALK, ONE COPY, TWO CALLERS (D0314). `tests/test_carve_fraction.gd` asks this over six
## seeds; `tools/probe_shelf_rate.gd` asks it over two hundred, which is far too slow for CI and is the
## sample `docs/NEEDS_DIRECTOR.md` P028 needs. Two copies would be two instruments that could drift, and
## the entire value of the 200-seed run is that its numbers are comparable with the suite's six.
##
## **THE POPULATION IS AN UNCARVED GRID, AND THAT IS NOT INCIDENTAL.** The first version of this file
## called `ShaftGenerator.generate()` and then `_carve_caves` on the result — a grid the generator had
## ALREADY carved, and had also filled with ore. It reported a non-shelf carve fraction of 0.0031 against
## the suite's 0.0561 and a shelf rate of exactly zero, which read as a dramatic finding and was a
## different measurement wearing the same name. What the suite measures, and what this now measures, is
## `_carve_caves` acting ONCE on bare banded rock: `TileGrid.new(48, 1024, 1)` plus `_fill_base`.
##
## `seeds_hit` is the field added for P028: a rate of 6 in 92,160 could be one seed carving six cells or
## six seeds carving one each, and those are different claims about whether the mechanism exists at all.
static func measure(seeds: Array, cave_cfg: Dictionary, shelf_cfg: Dictionary) -> Dictionary:
	var min_depth: int = int(cave_cfg["min_depth_cells"])
	var band_height: int = int(shelf_cfg["band_height_cells"])
	var shelf_every: int = int(shelf_cfg["shelf_every"])
	var out: Dictionary = {"shelf_eligible": 0, "shelf_carved": 0, "open_eligible": 0,
		"open_carved": 0, "seeds_hit": 0}
	for seed_value: int in seeds:
		var grid: TileGrid = TileGrid.new(48, 1024, 1)
		ShaftGenerator._fill_base(grid, 0, 40, 140)
		var solid_before: Array[Vector2i] = []
		for col: int in grid.width:
			for row: int in range(min_depth, grid.height):
				var cell: Vector2i = Vector2i(col, row)
				if grid.is_solid(cell):
					solid_before.append(cell)
		ShaftGenerator._carve_caves(grid, cave_cfg, shelf_cfg, seed_value, 0)
		var hit: int = 0
		for cell: Vector2i in solid_before:
			var shelf: bool = ShaftGenerator._is_shelf_band(cell.y, band_height, shelf_every)
			var key: String = "shelf" if shelf else "open"
			out[key + "_eligible"] = int(out[key + "_eligible"]) + 1
			if not grid.is_solid(cell):
				out[key + "_carved"] = int(out[key + "_carved"]) + 1
				if shelf:
					hit += 1
		if hit > 0:
			out["seeds_hit"] = int(out["seeds_hit"]) + 1
	return out
