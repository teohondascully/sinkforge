extends SceneTree

## P021's decision-free half: measure the TOTAL void fraction a generated world carries, split by SOURCE.
##
## The 15% figure that P021 turns on appears in a legacy COMMENT, and this project's own
## `range-read-as-observations` rule says a number with no measurement behind it is a claim, not data. The
## cheap move before touching any threshold is to find out what this build actually produces and what
## legacy's figure could have been counting. `docs/DECISIONS_LEDGER.md` D0258 measured CAVE carve alone at
## 0.0329; nobody has measured cave + ruins together, which is the reading candidate (2) needs.
##
## HOW IT ATTRIBUTES, and why it is not instrumentation. Each source is measured by REMOVING it from the
## site CONFIG and re-generating, then differencing the solid counts — `remove the subject and re-run`,
## not a counter threaded through the generator. Two reasons that is better here: the config is data, so
## nothing in `sim/` changes to take the measurement; and a counter would measure the counter's own idea
## of what carved, while a difference measures what the world actually holds.
##
## Run: godot --headless --path . --script tools/measure_void_fraction.gd -- [seeds]

const DEFAULT_SEEDS: int = 24
const NO_CAVE_THRESHOLD: float = 99.0  ## unreachable: the fBm sample is bounded well inside +/-2


func _initialize() -> void:
	var seeds: int = DEFAULT_SEEDS
	for arg: String in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			seeds = int(arg)

	# ONE SITE, not all three. Measured and checked: `reveal_test_dense`, `reveal_test_sparse` and
	# `shallow_clay` carry BYTE-IDENTICAL `cave`, `ruin`, `strata_shelf` and `layer_thresholds_m` blocks
	# and differ only in ore/reveal placement, which places material rather than carving. Three identical
	# void fractions to four decimal places looked exactly like an instrument that cannot register its
	# subject, so it was checked against the configs rather than assumed either way -- they really are the
	# same world shape, and running all three is three times the work for one number.
	_measure_site("shallow_clay", seeds)
	_sweep_thresholds("shallow_clay", maxi(4, seeds / 4))
	_compare_against_legacys_own_field("shallow_clay", maxi(4, seeds / 4))
	quit(0)


func _measure_site(site_id: String, seeds: int) -> void:
	var base: Dictionary = StrataRecords.RECORDS[site_id]
	var totals := {"cells": 0, "void": 0, "cave": 0, "ruin": 0}
	var per_seed_void: Array[float] = []

	for i: int in seeds:
		var seed_value: int = 1000 + i * 7919   ## odd stride, so consecutive runs are not adjacent seeds
		var full: TileGrid = ShaftGenerator.generate(base, seed_value)
		var no_cave: TileGrid = ShaftGenerator.generate(_without_caves(base), seed_value)
		var bare: TileGrid = ShaftGenerator.generate(_without_ruins(_without_caves(base)), seed_value)

		var cells: int = full.width * full.height
		var void_full: int = cells - _solid(full)
		var void_no_cave: int = cells - _solid(no_cave)
		var void_bare: int = cells - _solid(bare)

		totals["cells"] += cells
		totals["void"] += void_full
		totals["cave"] += void_full - void_no_cave
		totals["ruin"] += void_no_cave - void_bare
		per_seed_void.append(float(void_full) / float(cells))

		# THE CONTROL, and it runs every seed rather than once: with caves and ruins both removed the
		# world must be SOLID. A non-zero bare void would mean some other pass excavates and this whole
		# attribution is missing a source -- which is exactly the failure a difference-based measurement
		# cannot otherwise see.
		if void_bare != 0:
			print("  CONTROL FAILED seed %d: %d void cells with caves AND ruins removed -- a third source "
				% [seed_value, void_bare] + "excavates and this attribution is incomplete")

	var frac: float = float(totals["void"]) / float(totals["cells"])
	per_seed_void.sort()
	var median: float = per_seed_void[per_seed_void.size() / 2]
	# Mean AND median, because a thresholded fraction over a small sample can be carried by one outlier
	# and reporting only the mean would hide it (`unstable-threshold-statistics`).
	print("%s: %d seeds, %d cells" % [site_id, seeds, totals["cells"]])
	print("  TOTAL void   %.4f  (median per-seed %.4f, min %.4f, max %.4f)"
		% [frac, median, per_seed_void[0], per_seed_void[-1]])
	print("    of which caves %.4f, ruins %.4f"
		% [float(totals["cave"]) / float(totals["cells"]), float(totals["ruin"]) / float(totals["cells"])])
	print("  against legacy's stated 'near 15%%': %.1f%% of it" % (frac / 0.15 * 100.0))


func _solid(grid: TileGrid) -> int:
	var n: int = 0
	for col: int in grid.width:
		for row: int in grid.height:
			if grid.is_solid(Vector2i(col, row)):
				n += 1
	return n


## A copy of the site whose cave thresholds can never be crossed. `duplicate(true)` is deep on purpose:
## a shallow copy would share the nested `cave` dictionary and this would silently mutate the record every
## other measurement below reads from.
func _without_caves(site: Dictionary) -> Dictionary:
	var out: Dictionary = site.duplicate(true)
	out["cave"]["threshold_top"] = NO_CAVE_THRESHOLD
	out["cave"]["threshold_deep"] = NO_CAVE_THRESHOLD
	return out


## Removed by COUNT, not by radius. The first version set `radius_cells = 0` and the control fired on
## every single seed with exactly 1 void cell: `_carve_disc` at radius 0 still carves its centre. The
## control was right and the removal was wrong — which is the whole reason a difference-based measurement
## needs one, since a 1-cell leak is invisible in a fraction reported to four places.
func _without_ruins(site: Dictionary) -> Dictionary:
	var out: Dictionary = site.duplicate(true)
	out["ruin"]["count"] = 0
	return out


## What threshold pair would produce legacy's stated 15%, measured rather than solved for.
##
## The shipped `threshold_top 0.47` / `threshold_deep 0.31` came over verbatim from legacy. This walks
## them DOWN together by a shared offset — a lower threshold carves more, since `_carve_caves` excavates
## where `noise > threshold` — and reports the void fraction at each step, so the answer is a measured
## curve rather than a number somebody solved for algebraically against an assumed distribution.
##
## Reported as a curve on purpose. If the 15% target is later revised, or WG-4 changes what a cell means,
## the useful artifact is the RELATIONSHIP; a single fitted constant would have to be re-derived from
## scratch.
func _sweep_thresholds(site_id: String, seeds: int) -> void:
	var base: Dictionary = StrataRecords.RECORDS[site_id]
	print("\nthreshold sweep on %s, %d seeds each (offset applied to BOTH top and deep):" % [site_id, seeds])
	print("  offset   top    deep   void      x of 15%")
	for step: int in 11:
		var offset: float = -0.02 * float(step)
		var cfg: Dictionary = base.duplicate(true)
		cfg["cave"]["threshold_top"] = float(base["cave"]["threshold_top"]) + offset
		cfg["cave"]["threshold_deep"] = float(base["cave"]["threshold_deep"]) + offset
		var cells: int = 0
		var empty: int = 0
		for i: int in seeds:
			var grid: TileGrid = ShaftGenerator.generate(cfg, 1000 + i * 7919)
			cells += grid.width * grid.height
			empty += grid.width * grid.height - _solid(grid)
		var frac: float = float(empty) / float(cells)
		print("  %+.2f   %.3f  %.3f  %.4f    %.2f"
			% [offset, cfg["cave"]["threshold_top"], cfg["cave"]["threshold_deep"], frac, frac / 0.15])


## THE CONTROLLED COMPARISON THAT SETTLES WHETHER THE THRESHOLD IS WRONG.
##
## `docs/DECISIONS_LEDGER.md` D0258 showed our field matches FastNoiseLite's CROSSING RATES at three
## isolated thresholds. That is not the same claim as "the same fraction of the world opens", because the
## real pipeline lerps the threshold with depth and adds `shelf_resist` on a third of the rows — a field
## can match at three points and still carve differently once composed with all of that.
##
## So this runs the SAME carve pipeline twice, changing exactly one thing: the noise source. Ours is
## `ValueNoise.sample_fbm` times the D0258 calibration; the reference is Godot's own `FastNoiseLite` with
## legacy's literal settings (`TYPE_SIMPLEX_SMOOTH`, `frequency = CAVE_FREQ`), which is the engine class
## legacy actually called. Everything else — the lerp, the shelf resist, the x-stretch, the min depth, the
## grid — is held identical.
##
## If the two agree, the threshold is CORRECT and the 15% gap is not a calibration problem.
func _compare_against_legacys_own_field(site_id: String, seeds: int) -> void:
	var site: Dictionary = StrataRecords.RECORDS[site_id]
	var cave: Dictionary = site["cave"]
	var shelf: Dictionary = site["strata_shelf"]
	var width: int = int(site["width_cells"])
	var height: int = int(site["max_depth_m"]) * ShaftGenerator.TERRAIN_CELLS_PER_METER
	var min_depth: int = int(cave["min_depth_cells"])
	var carve_span: int = maxi(1, height - min_depth)

	var ours: int = 0
	var theirs: int = 0
	var total: int = 0
	for i: int in seeds:
		var seed_value: int = 1000 + i * 7919
		var fnl := FastNoiseLite.new()
		fnl.seed = seed_value
		fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH   ## legacy sets this explicitly; it is not the default
		fnl.frequency = float(cave["frequency"])
		for col: int in width:
			for row: int in range(min_depth, height):
				var depth_frac: float = float(row - min_depth) / float(carve_span)
				var threshold: float = lerpf(float(cave["threshold_top"]), float(cave["threshold_deep"]), depth_frac)
				if ShaftGenerator._is_shelf_band(row, int(shelf["band_height_cells"]), int(shelf["shelf_every"])):
					threshold += float(shelf["shelf_resist"])
				var nx: float = float(col) / float(cave["x_stretch"])
				var mine: float = ValueNoise.sample_fbm(nx * float(cave["frequency"]),
					float(row) * float(cave["frequency"]), seed_value) * ValueNoise.FASTNOISELITE_SD_CALIBRATION
				if mine > threshold:
					ours += 1
				if fnl.get_noise_2d(nx, float(row)) > threshold:
					theirs += 1
				total += 1

	var ours_frac: float = float(ours) / float(total)
	var theirs_frac: float = float(theirs) / float(total)
	print("\ncave pass ONLY, identical pipeline, only the noise source differs (%d seeds):" % seeds)
	print("  ours (ValueNoise fBm x calibration): %.4f" % ours_frac)
	print("  legacy's own FastNoiseLite SIMPLEX_SMOOTH @ freq %.2f: %.4f" % [cave["frequency"], theirs_frac])
	print("  ratio ours/theirs: %.3f" % (ours_frac / maxf(theirs_frac, 1e-9)))
	print("  -> if these agree, the shipped thresholds are RIGHT and the 15%% gap is elsewhere")
