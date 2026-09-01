extends "res://tests/test_base.gd"

## `_is_shelf_band`'s expected rows (band_height=4, shelf_every=3) are a from-scratch Python reference,
## and happen to exactly match the six bands legacy's own comment names as its shipping example
## ("rows 0-3, 16-19, 28-31, 36-39, 52-55 and 64-67") -- confirms this port carried the algorithm over
## faithfully, not just its constants.

func _initialize() -> void:
	_test_band_hash_matches_reference()
	_test_base_fill_bands_by_depth()
	_test_caves_never_carve_above_min_depth()
	_test_caves_carve_something()
	_test_carve_fraction_by_region()
	_test_ore_appears_somewhere()
	_test_coal_appears_somewhere()
	_test_iron_only_appears_at_or_below_stonereach()
	_test_grow_vein_respects_min_row_floor()
	_test_grow_vein_never_fills_a_carved_cave()
	_test_ruin_carves_a_chamber()
	_test_generation_is_deterministic()
	_test_different_seeds_diverge()
	_test_glimmer_appears_in_reveal_test_dense()
	_test_glimmer_never_appears_at_or_below_topsoil_end()
	_test_there_is_sky_above_the_surface_and_nothing_is_generated_into_it()
	_test_the_view_and_the_generator_agree_where_the_surface_is()
	_test_shallow_clay_has_no_glimmer_at_all()
	_test_dense_reveal_site_places_more_glimmer_than_sparse()
	_finish("shaft_generator")


func _test_band_hash_matches_reference() -> void:
	var expected_shelf_rows: Array = [0, 1, 2, 3, 16, 17, 18, 19, 28, 29, 30, 31, 36, 37, 38, 39, 52, 53, 54, 55, 64, 65, 66, 67]
	var got_shelf_rows: Array = []
	for row: int in 80:
		if ShaftGenerator._is_shelf_band(row, 4, 3):
			got_shelf_rows.append(row)
	_check(got_shelf_rows == expected_shelf_rows, "shelf bands (band_height=4, shelf_every=3) over rows 0..79 = %s (expected %s)" %
		[got_shelf_rows, expected_shelf_rows])


func _test_base_fill_bands_by_depth() -> void:
	var grid: TileGrid = TileGrid.new(4, 20, 1)
	ShaftGenerator._fill_base(grid, 0, 8, 14)
	_check(grid.get_material(Vector2i(0, 0)) == &"clay", "row 0 (< topsoil_end) is clay")
	_check(grid.get_material(Vector2i(0, 7)) == &"clay", "row 7 (< topsoil_end) is clay")
	_check(grid.get_material(Vector2i(0, 8)) == &"hardrock", "row 8 (== topsoil_end) is hardrock")
	_check(grid.get_material(Vector2i(0, 13)) == &"hardrock", "row 13 (< stonereach_end) is hardrock")
	_check(grid.get_material(Vector2i(0, 14)) == &"deepstone", "row 14 (== stonereach_end) is deepstone")
	_check(grid.get_material(Vector2i(0, 19)) == &"deepstone", "row 19 (deep) is deepstone")
	_check(grid.get_wall(Vector2i(0, 19)) == &"deepstone", "wall mirrors the block's material")


func _test_caves_never_carve_above_min_depth() -> void:
	var grid: TileGrid = TileGrid.new(12, 60, 1)
	ShaftGenerator._fill_base(grid, 0, 20, 50)
	var cave_cfg: Dictionary = StrataData.SHALLOW_CLAY["cave"]
	var shelf_cfg: Dictionary = StrataData.SHALLOW_CLAY["strata_shelf"]
	ShaftGenerator._carve_caves(grid, cave_cfg, shelf_cfg, 1, 0)
	var min_depth: int = int(cave_cfg["min_depth_cells"])
	var violations: int = 0
	for col: int in grid.width:
		for row: int in min_depth:
			if not grid.is_solid(Vector2i(col, row)):
				violations += 1
	_check(violations == 0, "no carved cell above min_depth_cells (%d found)" % violations)


func _test_caves_carve_something() -> void:
	var grid: TileGrid = TileGrid.new(48, 400, 1)
	ShaftGenerator._fill_base(grid, 0, 40, 140)
	var cave_cfg: Dictionary = StrataData.SHALLOW_CLAY["cave"]
	var shelf_cfg: Dictionary = StrataData.SHALLOW_CLAY["strata_shelf"]
	ShaftGenerator._carve_caves(grid, cave_cfg, shelf_cfg, 1, 0)
	var open_count: int = 0
	for col: int in grid.width:
		for row: int in grid.height:
			if not grid.is_solid(Vector2i(col, row)):
				open_count += 1
	_check(open_count > 0, "cave carving opened at least one cell (%d opened)" % open_count)



## THE INSTRUMENT `_test_caves_carve_something` IS NOT (WG-2/WG-3, docs/LEGACY_GAP.md Tier 0).
##
## That test's floor is `open_count > 0` -- "cave carving opened at least one cell". A floor of one cell
## cannot distinguish a field carving the ~15% legacy aimed for from one carving 3%, and it cannot see a
## shelf band that carves EXACTLY ZERO cells at every seed and every coordinate. Both were true, both
## sat green, and nothing in this repository measured carve fraction until this function. That is the
## house failure class in its usual costume: the quiet green.
##
## Measured in FOUR partitions, not one, because a single pooled number hides the defect that matters --
## an overall fraction of 3.4% is equally consistent with "carving is uniformly thin" and with "carving
## is normal outside shelves and impossible inside them", which are completely different bugs with
## completely different fixes.
##
## `shelf_eligible > 0` and `open_eligible > 0` are asserted BEFORE any fraction is reported, and that is
## the load-bearing line here rather than a courtesy: a shelf carve fraction of 0.0 has two causes --
## the shelf is impermeable (the real one), or the sample contained no shelf cells at all, in which case
## 0.0 is a division that never had a subject. Without the population check this instrument would report
## the same headline number whether or not it had measured anything.
## Counts carved cells in two partitions over several seeds. Split out of the assertion below purely so
## each stays under the 50-line function limit -- but it earns the split: the measurement has no opinion
## about what the numbers should be, which is what makes it reusable for the WG-3 octave port's
## before/after comparison without editing an assertion to suit a result.
static func _measure_carve(seeds: Array, cave_cfg: Dictionary, shelf_cfg: Dictionary) -> Dictionary:
	var min_depth: int = int(cave_cfg["min_depth_cells"])
	var band_height: int = int(shelf_cfg["band_height_cells"])
	var shelf_every: int = int(shelf_cfg["shelf_every"])
	var out: Dictionary = {"shelf_eligible": 0, "shelf_carved": 0, "open_eligible": 0, "open_carved": 0}
	for seed: int in seeds:
		var grid: TileGrid = TileGrid.new(48, 1024, 1)
		ShaftGenerator._fill_base(grid, 0, 40, 140)
		var solid_before: Array[Vector2i] = []
		for col: int in grid.width:
			for row: int in range(min_depth, grid.height):
				var cell: Vector2i = Vector2i(col, row)
				if grid.is_solid(cell):
					solid_before.append(cell)
		ShaftGenerator._carve_caves(grid, cave_cfg, shelf_cfg, seed, 0)
		for cell: Vector2i in solid_before:
			var shelf: bool = ShaftGenerator._is_shelf_band(cell.y, band_height, shelf_every)
			var key: String = "shelf" if shelf else "open"
			out[key + "_eligible"] = int(out[key + "_eligible"]) + 1
			if not grid.is_solid(cell):
				out[key + "_carved"] = int(out[key + "_carved"]) + 1
	return out


func _test_carve_fraction_by_region() -> void:
	var m: Dictionary = _measure_carve([1, 20260826, 424242, 7, 99991, 31337],
		StrataData.SHALLOW_CLAY["cave"], StrataData.SHALLOW_CLAY["strata_shelf"])
	var shelf_eligible: int = int(m["shelf_eligible"])
	var open_eligible: int = int(m["open_eligible"])

	# Positive controls first -- see the docstring. A fraction computed over an empty population is not
	# a small number, it is no number.
	_check(shelf_eligible > 0,
		"positive control: the sample actually contains shelf-band cells to carve (%d) -- without this, " % shelf_eligible
		+ "a shelf carve fraction of 0.0 would mean 'nothing was measured', not 'nothing carves'")
	_check(open_eligible > 0,
		"positive control: the sample actually contains non-shelf cells to carve (%d)" % open_eligible)
	if shelf_eligible == 0 or open_eligible == 0:
		return

	var shelf_carved: int = int(m["shelf_carved"])
	var open_carved: int = int(m["open_carved"])
	var shelf_frac: float = float(shelf_carved) / float(shelf_eligible)
	var open_frac: float = float(open_carved) / float(open_eligible)
	var total_frac: float = float(shelf_carved + open_carved) / float(shelf_eligible + open_eligible)
	print("carve_fraction: overall %.4f | shelf-band %.4f (%d/%d) | non-shelf %.4f (%d/%d)" %
		[total_frac, shelf_frac, shelf_carved, shelf_eligible, open_frac, open_carved, open_eligible])

	# THE RATCHET, re-pinned 2026-08-31 after the WG-3 octave port (D0258). The previous version asserted
	# `shelf_frac == 0.0` as a pinned DEFECT and said "if this line FAILS, WG-2 is fixed". It failed. The
	# shelf carves 15 cells where it carved 0, so this now asserts the SHAPE legacy actually had rather
	# than the equality the acceptance criteria asked for -- see the failure message on the gradient check.
	_check(shelf_frac > 0.0,
		"WG-2 CLOSED: shelf bands are permeable at last (%d of %d over 6 seeds, was 0). " % [shelf_carved, shelf_eligible]
		+ "The wall was never a threshold that was too high -- it was a single-octave field with no tail "
		+ "to clear it with. If this returns to zero, the octave port has been undone.")
	_check(shelf_frac < open_frac,
		"WG-2 SHAPE: the shelf is a GRADIENT, not open rock -- shelf %.4f stays below non-shelf %.4f. " % [shelf_frac, open_frac]
		+ "Measured against real FastNoiseLite at legacy's own thresholds, this is what legacy did too: it "
		+ "clears 0.31 at 0.1164 and 0.65 at 0.0009, a 130x difference, and clears the 0.81 top-shelf "
		+ "threshold 0.0000 of the time. A shelf carving at the open-rock rate is not a fixed shelf, it is "
		+ "a deleted one -- do NOT 'fix' this by raising the calibration until the two numbers meet.")
	_check(absf(open_frac - 0.0493) < 0.0060,
		"non-shelf carve fraction %.4f stays near its measured 0.0493 (+/-0.0060)" % open_frac)
	_check(absf(total_frac - 0.0329) < 0.0060,
		"overall carve fraction %.4f stays near its measured 0.0329 (+/-0.0060). NOTE: legacy's own " % total_frac
		+ "stated target is ~15%%, and the octave port did NOT close that -- it moved 0.0358 -> 0.0329. "
		+ "That gap is a THRESHOLD question, not a noise-field one, and is parked as P021.")


func _test_ore_appears_somewhere() -> void:
	var grid: TileGrid = ShaftGenerator.generate(StrataData.SHALLOW_CLAY, 20260826)
	var found: bool = false
	for cell: Vector2i in grid.occupied_terrain_cells():
		if grid.get_material(cell) == &"ore_copper":
			found = true
			break
	_check(found, "a full shallow_clay generation places at least one ore_copper cell")


func _test_coal_appears_somewhere() -> void:
	var grid: TileGrid = ShaftGenerator.generate(StrataData.SHALLOW_CLAY, 20260826)
	var found: bool = false
	for cell: Vector2i in grid.occupied_terrain_cells():
		if grid.get_material(cell) == &"coal":
			found = true
			break
	_check(found, "a full shallow_clay generation places at least one coal cell")


func _test_iron_only_appears_at_or_below_stonereach() -> void:
	var grid: TileGrid = ShaftGenerator.generate(StrataData.SHALLOW_CLAY, 20260826)
	var stonereach_end: int = int(StrataData.SHALLOW_CLAY["layer_thresholds_m"]["stonereach_end"]) * ShaftGenerator.TERRAIN_CELLS_PER_METER
	var found: bool = false
	var violations: int = 0
	for cell: Vector2i in grid.occupied_terrain_cells():
		if grid.get_material(cell) == &"ore_iron":
			found = true
			if cell.y < stonereach_end:
				violations += 1
	_check(found, "a full shallow_clay generation places at least one ore_iron cell")
	_check(violations == 0, "no ore_iron cell sits above stonereach_end (%d found)" % violations)


## `_test_iron_only_appears_at_or_below_stonereach` exercises min_row through a full seeded generation,
## which turned out not to reliably probe the boundary (a real accretion blob is compact, radius roughly
## sqrt(size), so most seeds never wander far enough to test the floor at all). This forces the issue: an
## all-host-rock grid, a seed sitting exactly on the floor, and a blob big enough that it must repeatedly
## offer cells one row above the floor to its own frontier.
func _test_grow_vein_respects_min_row_floor() -> void:
	var grid: TileGrid = TileGrid.new(20, 20, 1)
	for col: int in grid.width:
		for row: int in grid.height:
			grid.set_material(Vector2i(col, row), &"hardrock")
	var rng: SplitRng = SplitRng.new(3).split("terrain_gen")
	var min_row: int = 10
	ShaftGenerator._grow_vein(grid, rng, Vector2i(10, min_row), 60, &"ore_iron", min_row)
	var violations: int = 0
	for col: int in grid.width:
		for row: int in range(0, min_row):
			if grid.get_material(Vector2i(col, row)) == &"ore_iron":
				violations += 1
	_check(violations == 0, "_grow_vein never plants above min_row even when forced to try (%d found)" % violations)


## The other half of the host-rock check: a vein must never overwrite an already-open (carved-cave)
## cell, only solid host rock. Seed a vein right next to a pre-carved cell it is certain to offer its own
## frontier and confirm it stays open.
func _test_grow_vein_never_fills_a_carved_cave() -> void:
	var grid: TileGrid = TileGrid.new(10, 10, 1)
	for col: int in grid.width:
		for row: int in grid.height:
			grid.set_material(Vector2i(col, row), &"hardrock")
	var cave_cell: Vector2i = Vector2i(5, 5)
	grid.excavate(cave_cell)
	var rng: SplitRng = SplitRng.new(9).split("terrain_gen")
	ShaftGenerator._grow_vein(grid, rng, Vector2i(4, 5), 30, &"ore_copper")
	_check(grid.get_material(cave_cell) == &"", "a carved cave cell stays open even when a vein grows past it")


func _test_ruin_carves_a_chamber() -> void:
	var grid: TileGrid = TileGrid.new(30, 500, 1)
	for col: int in grid.width:
		for row: int in grid.height:
			grid.set_material(Vector2i(col, row), &"hardrock")
	var rng: SplitRng = SplitRng.new(5).split("terrain_gen")
	var ruin_cfg: Dictionary = {"count": 1, "min_depth_m": 100, "radius_cells": 4}
	ShaftGenerator._place_ruins(grid, rng, ruin_cfg, 0)
	var min_row: int = 100 * ShaftGenerator.TERRAIN_CELLS_PER_METER
	var open_below_min: int = 0
	var open_above_min: int = 0
	for col: int in grid.width:
		for row: int in grid.height:
			if not grid.is_solid(Vector2i(col, row)):
				if row >= min_row:
					open_below_min += 1
				else:
					open_above_min += 1
	_check(open_below_min > 0, "the ruin carved at least one open cell at or past min_depth_m (%d)" % open_below_min)
	_check(open_above_min == 0, "the ruin carved nothing above min_depth_m (%d found)" % open_above_min)


func _test_generation_is_deterministic() -> void:
	var a: TileGrid = ShaftGenerator.generate(StrataData.SHALLOW_CLAY, 20260826)
	var b: TileGrid = ShaftGenerator.generate(StrataData.SHALLOW_CLAY, 20260826)
	_check(a.state_signature() == b.state_signature(), "the same seed generates a bit-identical shaft twice")


func _test_different_seeds_diverge() -> void:
	var a: TileGrid = ShaftGenerator.generate(StrataData.SHALLOW_CLAY, 1)
	var b: TileGrid = ShaftGenerator.generate(StrataData.SHALLOW_CLAY, 2)
	_check(a.state_signature() != b.state_signature(), "different seeds generate different shafts")


func _count_glimmer(grid: TileGrid) -> int:
	var count: int = 0
	for cell: Vector2i in grid.occupied_terrain_cells():
		if grid.get_material(cell) == &"glimmer":
			count += 1
	return count


func _test_glimmer_appears_in_reveal_test_dense() -> void:
	var grid: TileGrid = ShaftGenerator.generate(StrataData.REVEAL_TEST_DENSE, 20260826)
	_check(_count_glimmer(grid) > 0, "a full reveal_test_dense generation places at least one glimmer cell")


func _test_glimmer_never_appears_at_or_below_topsoil_end() -> void:
	var grid: TileGrid = ShaftGenerator.generate(StrataData.REVEAL_TEST_DENSE, 20260826)
	# The threshold is metres BELOW THE SURFACE, and the surface is row `SKY_ROWS` (P017/D0292) -- read
	# through the same offset the generator uses rather than restated, or this measures a row the world
	# no longer keys anything to.
	var topsoil_end: int = ShaftGenerator.SKY_ROWS \
		+ int(StrataData.REVEAL_TEST_DENSE["layer_thresholds_m"]["topsoil_shale_end"]) \
		* ShaftGenerator.TERRAIN_CELLS_PER_METER
	var violations: int = 0
	for cell: Vector2i in grid.occupied_terrain_cells():
		if grid.get_material(cell) == &"glimmer" and cell.y >= topsoil_end:
			violations += 1
	_check(violations == 0, "no glimmer cell sits at or below topsoil_end (%d found)" % violations)


func _test_shallow_clay_has_no_glimmer_at_all() -> void:
	var grid: TileGrid = ShaftGenerator.generate(StrataData.SHALLOW_CLAY, 20260826)
	_check(_count_glimmer(grid) == 0,
		"the real site (no `reveal` block) places zero glimmer -- the optional-field guard actually guards")


func _test_dense_reveal_site_places_more_glimmer_than_sparse() -> void:
	# Same seed, deliberately: this isolates density as the one variable, since determinism means any
	# difference in output has to come from the `reveal` config, not from a different RNG draw sequence.
	var sparse: TileGrid = ShaftGenerator.generate(StrataData.REVEAL_TEST_SPARSE, 20260826)
	var dense: TileGrid = ShaftGenerator.generate(StrataData.REVEAL_TEST_DENSE, 20260826)
	var sparse_count: int = _count_glimmer(sparse)
	var dense_count: int = _count_glimmer(dense)
	_check(dense_count > sparse_count,
		"the dense reveal site places more glimmer than the sparse one at the same seed (dense=%d, sparse=%d)" %
		[dense_count, sparse_count])


## P017 (D0292), and the assertion is about ABSENCE, which is the hard kind: the sky band must hold no
## block AND no wall. A band with walls but no blocks looks identical from the sim's side -- `is_solid`
## is false either way -- and reads as a tunnel rather than as open air, because `WallPainter` draws
## exactly the cells that have a wall behind them (D0286).
func _test_there_is_sky_above_the_surface_and_nothing_is_generated_into_it() -> void:
	var grid: TileGrid = ShaftGenerator.generate(StrataData.REVEAL_TEST_DENSE, 4242)
	var surface: int = ShaftGenerator.SKY_ROWS
	_check(surface > 0, "sanity: there is a sky band at all (%d rows)" % surface)
	var blocks: int = 0
	var walls: int = 0
	for col: int in grid.width:
		for row: int in surface:
			var cell := Vector2i(col, row)
			if grid.is_solid(cell):
				blocks += 1
			if grid.get_wall(cell) != &"":
				walls += 1
	_check_over(grid.width * surface, blocks == 0,
		"no block is generated above the surface (%d of %d)" % [blocks, grid.width * surface])
	_check_over(grid.width * surface, walls == 0,
		"and no WALL either (%d) -- a wall with no block is a tunnel, not sky, and it is the wall plane "
		% walls + "that decides which of the two the player sees")
	# CONTROL: the row immediately below is rock. Without it every row above passes on a generator that
	# produced an empty world.
	var solid_below: int = 0
	for col: int in grid.width:
		if grid.is_solid(Vector2i(col, surface)):
			solid_below += 1
	_check(solid_below == grid.width,
		"CONTROL: the very next row is solid across the whole width (%d of %d) -- the sky ENDS"
		% [solid_below, grid.width])
	# The band has to clear the jump, or it is decoration. 74px apex at a 4px cell is ~18 rows; this is
	# derived from the two of them rather than restated, so a jump tuning change fails here.
	var apex_rows: int = 74 / Heightfield.TERRAIN_CELL_PX
	_check(surface > apex_rows,
		"and the band is taller than a full jump (%d rows vs a %d-row apex), so the ceiling is never the "
		% [surface, apex_rows] + "thing the player notices")


## CONSTANT MUST DOMINATE CONSTANT. `view/` may not name a `sim/` symbol, so `MaterialLook.SURFACE_ROW`
## is a COPY of `ShaftGenerator.SKY_ROWS` and the two can silently disagree — at which point every depth
## on the HUD is wrong by the difference and the horizon is drawn in the middle of the rock. Asserted
## here rather than trusted to the comment that says so.
func _test_the_view_and_the_generator_agree_where_the_surface_is() -> void:
	_check(MaterialLook.SURFACE_ROW == ShaftGenerator.SKY_ROWS,
		"the palette's surface row (%d) is the generator's sky band (%d)"
		% [MaterialLook.SURFACE_ROW, ShaftGenerator.SKY_ROWS])
	_check(MaterialLook.CELLS_PER_METRE == ShaftGenerator.TERRAIN_CELLS_PER_METER,
		"and its metre is the generator's metre (%d vs %d)"
		% [MaterialLook.CELLS_PER_METRE, ShaftGenerator.TERRAIN_CELLS_PER_METER])
	# And the conversion built on them lands where it should: zero AT the datum, negative above it,
	# positive below. The negative half is what `DepthChip` renders as `+N m` and has never until now
	# been reachable in a generated world.
	_check(MaterialLook.depth_m(ShaftGenerator.SKY_ROWS) == 0,
		"the surface row is 0 m (%d)" % MaterialLook.depth_m(ShaftGenerator.SKY_ROWS))
	_check(MaterialLook.depth_m(0) < 0,
		"the top of the sky is a NEGATIVE depth (%d m) -- the readout's `+N m` case, reachable at last"
		% MaterialLook.depth_m(0))
	_check(MaterialLook.depth_m(ShaftGenerator.SKY_ROWS + 10 * MaterialLook.CELLS_PER_METRE) == 10,
		"and ten metres of rock below it reads as 10 m (%d)"
		% MaterialLook.depth_m(ShaftGenerator.SKY_ROWS + 10 * MaterialLook.CELLS_PER_METRE))
