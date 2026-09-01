extends "res://tests/test_base.gd"

## THE CARVE-FRACTION INSTRUMENT, split out of `tests/test_shaft_generator.gd` at the 400-line file cap
## (D0307). The seam is the right one and not merely the convenient one: everything left behind asks
## "does the generator produce the right KIND of thing" -- bands, veins, glimmer, sky -- and this file
## alone asks "and HOW MUCH of the world does it open", which is the question WG-2 and WG-3 were about
## and the one no other suite in the repository poses.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_carve_fraction.gd


func _initialize() -> void:
	_test_carve_fraction_by_region()
	_finish("carve_fraction")


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

	_check_carve_ratchets(shelf_frac, open_frac, total_frac, shelf_carved, shelf_eligible)


## The ratchets themselves, split from the measurement at the 50-line function gate. The split is also
## the right shape: above is what the world DID, here is what it is held to.
func _check_carve_ratchets(shelf_frac: float, open_frac: float, total_frac: float,
		shelf_carved: int, shelf_eligible: int) -> void:
	# THE RATCHET, re-pinned 2026-08-31 after the WG-3 octave port (D0258). The previous version asserted
	# `shelf_frac == 0.0` as a pinned DEFECT and said "if this line FAILS, WG-2 is fixed". It failed. The
	# shelf carves 15 cells where it carved 0, so this now asserts the SHAPE legacy actually had rather
	# than the equality the acceptance criteria asked for -- see the failure message on the gradient check.
	# READ THIS BEFORE TRUSTING THE LINE BELOW (D0307, docs/NEEDS_DIRECTOR.md P028). Sweeping
	# `cave.frequency` measured `shelf_carved` at 0, 1, 6, 15 and 17 cells out of 46,080 -- no trend, a 17x
	# move between adjacent frequencies, and one landing on exactly zero. THAT IS A NOISE FLOOR, and a
	# `> 0.0` guard against a noise floor samples its subject rather than measuring it. When D0258 declared
	# WG-2 closed, the evidence under the sentence in the message was ONE CARVED CELL. The claim may well be
	# true; this assertion cannot establish it. Treat it as a TRIPWIRE for the octave port being undone --
	# which is what its own last sentence says -- and not as evidence that shelf bands are permeable.
	# Unresolved on purpose: re-stating a Tier-0 closure criterion is the director's call, not a loop's.
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
	# RE-PINNED 2026-09-01 for WG-4 Batch A (D0305), from the new measurement rather than by widening the
	# old band -- the band width is unchanged at +/-0.0060 and only its centre moved. The conversion
	# raised `cave.min_depth_cells` 6 -> 24 and `strata_shelf.band_height_cells` 4 -> 16, which changes
	# both what carves and which rows count as shelf, so the populations behind these two fractions are
	# not the ones the previous numbers were measured over. A band widened to swallow both would be
	# measuring nothing.
	_check(absf(open_frac - 0.0561) < 0.0060,
		"non-shelf carve fraction %.4f stays near its measured 0.0561 (+/-0.0060)" % open_frac)
	_check(absf(total_frac - 0.0381) < 0.0060,
		"overall carve fraction %.4f stays near its measured 0.0381 (+/-0.0060). NOTE: legacy's own " % total_frac
		+ "stated target is ~15%%, and neither the octave port nor WG-4 closed it on THIS measure -- "
		+ "0.0358 -> 0.0329 -> 0.0381. What P021 closed was the missing carve PASSES (D0291), which this "
		+ "fraction does not see: it measures `_carve_caves` alone. `tools/measure_void_fraction.gd` is "
		+ "the one that counts every source, and it reads 0.1058.")
