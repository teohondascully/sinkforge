extends SceneTree

## NO TEXTURE FIELD MAY BE WHITE NOISE: the Nyquist guard.
##
## Every procedural texture in this game is a FastNoiseLite field sampled on an INTEGER grid: one sample
## per fine cell, one per coarse cell. A noise field only produces the smooth, clumped, structured values
## it is drawn for while its period is comfortably longer than that sample spacing. Push the frequency to
## 1.0 and the period is one sample; neighbouring cells become statistically independent and the field
## stops being texture and becomes STATIC: visually a checkerboard, and worse, a checkerboard that
## averages away every other detail layered on top of it.
##
## This was not hypothetical. Two fields shipped over the Nyquist limit at once: the fine terrain's
## "crisp grit" colour octave at 1.30 and the terrain molding's boundary grit at 1.10. Between them the
## underground rock printed as a high-contrast 8px checkerboard under a one-pixel dithered edge, and the
## hue, patch, crack and rim passes above them were all being averaged into mush. It is an easy bug to
## write (a bigger number reads like "finer detail") and an impossible one to see in the source, so it
## gets a test rather than a comment.
##
## The test is empirical, not a constant audit: each field is sampled along a straight line of integer
## coordinates and the lag-1 Pearson correlation of the sequence is measured. A field with structure
## correlates strongly with its own neighbour. White noise does not.
##
## PART TWO: AND THE PAINT IS WHAT YOU ACTUALLY SEE.
##
## Passing part one is necessary and nowhere near sufficient, which cost a whole round to learn. Every
## input field can clear the floor and the painted rock still print as confetti, for three reasons the
## ingredient test structurally cannot see:
##   1. AMPLITUDE. A field at the edge of resolvable, multiplied by a large swing, is a visible
##      checkerboard; the same field at a tenth the amplitude is grain. Correlation is scale-free and
##      says nothing about how loud the term is.
##   2. THRESHOLDS. `if stone > THRESH` turns a smooth field into a binary mask, and a mask is far less
##      correlated than the field it came from: a 0.5-correlated field can threshold into scattered
##      single cells.
##   3. STACKING. Six independent terms each individually quiet sum into one loud one.
## So the second half of this file bakes the REAL FineTerrain and measures the pixels. Flat grey stands
## in for the material palette, because the property under test is variation and a flat base makes every
## number below attributable to the texture passes alone.
##
## The unit that matters here is a FINE CELL: one texel, 8 world px, and at the game's zoom about twelve
## SCREEN pixels. Anything that changes value cell to cell is not fine detail at that size: it is a
## twelve-pixel checker, which is exactly what "blocky" means when a player says it.
##
## PART TWO IS MEASURED PER MATERIAL GRAMMAR, ON A COMPOSED SLAB, AND THE REASON IS A DEFECT.
##
## It used to bake a generated world and pool every deep-interior cell in rows 60..110 into one number.
## That number is not a property of the paint. It is a property of the paint CONVOLVED WITH THE MATERIAL
## MIX worldgen happened to put in those rows, because the paint runs a different texture grammar per
## material and the three grammars are deliberately nothing like each other — Clastic grain 1.60 against
## Massive 0.30, Massive seams 0.70 against Clastic 0.15. Change which rock sits at row 65 and the
## pooled number moves with the paint untouched.
##
## Which is what happened. `9d1841c fix(worldgen): scatter shelf bands instead of banding rows 0 to 31`
## repaired a hash that reduced to `(band / 8) % 3`, so every shale shelf had been landing in rows 0..31
## and rows 32..75 carried no strata at all. No paint constant, no painter file and no material resource
## changed; the roughness went 6.350% to 6.534% against a 6.50% ceiling and this layer went red. A
## worldgen fix reddening the texture layer is a sentence that should not be possible.
##
## The census below prints the population that moved, measured on both sides of that commit with one
## painter and one seed:
##
##                          before 9d1841c   at 9d1841c
##     clastic share             48.62%        58.34%
##     bedded  share              0.00%         3.04%      (shale, coarse rows 64..67)
##     massive share             51.38%        38.62%
##     pooled roughness across    6.350%        6.534%
##
## And note what the shares did, because the obvious story is the wrong one. The shale shelf is only 3%
## of the window; the move is mostly the clastic/massive balance swinging ten points, because
## `_is_shelf_band` also feeds the cave carve and the seeded RNG stream, so scattering the shelves
## re-rolled the whole material population of the band. Removing just the bedded cells from the pooled
## figure recovers 6.508%, not 6.350% — the shale is a passenger, not the cause.
##
## CANDIDATE FIX THAT DOES NOT WORK, measured rather than reasoned about: asserting PER MATERIAL on the
## generated world. It sounds like it removes the mix, and it does not remove the confound. Across the
## same commit the per-grammar readings moved 6.701% to 6.432% (clastic) and 5.269% to 5.606% (massive),
## both LARGER than the 0.18-point pooled move that reddened the layer in the first place. Two reasons:
## worldgen decides where a material sits and how much cave face it has, and `_contact_index` warps the
## grammar lookup, so a per-material bucket in a mixed world carries its neighbours' grammar at every
## boundary. Forcing one grammar over the same geometry reads 5.844 / 5.321 / 4.336 against those
## 6.432 / 6.583 / 5.606, and the whole of that difference is bleed.
##
## So the assertion is moved onto a population this file OWNS. Each grammar is baked on its own slab: a
## solid, uniform, material-free world built straight out of Callables, with no FactorySim and no
## worldgen anywhere in the call graph, so no worldgen edit can reach these numbers by construction.
##
## WHAT THE MOVE COSTS, because it is not free and the first draft of this comment claimed it was.
##
## A slab has no cave faces, so it has no `_sky_form` and no rim, and it has no material contacts. Those
## are real contributors to the pooled figure — contact triples alone measure 11.2% across a face, the
## roughest population in the frame and about 8% of it — so the slab reads a genuinely quieter quantity
## than the ceiling was calibrated against:
##
##                              clastic  bedded  massive
##     slab (this file)           5.3%    4.7%    3.7%
##     one grammar, real caves    5.8%    5.3%    4.3%
##     that grammar in the world  6.4%    6.6%    5.6%
##
## Against an unchanged 6.5% ceiling that is slack, and the slack is measurable as lost sensitivity.
## Restoring the historical `GRAM_SEAM` massive defect of 2.20 takes the massive slab 3.7% -> 9.53% and
## reds it, so the guard is not decorative. But at 1.00 — a value the OLD pooled statistic caught, at
## 6.9% — the slab reads 4.8% and passes. The trip point sits between 1.00 and 1.60 rather than between
## 0.70 and 1.00.
##
## THE CEILING AND THE FLOOR BELOW ARE UNCHANGED, deliberately, and that is why the paragraph above is a
## disclosure and not a repair. The number that belongs on a slab is not 6.5% and cannot be reached by
## reasoning from 6.5%; it needs the same calibration walk the original had, against pictures. The
## measurements a future calibration needs are printed on every run. Guessing one here would be trading
## a bar that is meaningless for a bar that is invented.

## Below this, consecutive samples are effectively independent. It corresponds to roughly three samples
## per noise feature, which is the honest boundary: fewer than three and there is no shape left to see,
## only a value that changes every cell. Fields well under it are not 'fine detail', they are static.
const LAG1_FLOOR: float = 0.25
const SAMPLES: int = 4096

## The painted rock's own lag-1 correlation, measured on deep interior cells. 0.55 is a feature spanning
## roughly four fine cells (cos(2*PI/4) = 0.0 is one that alternates; a four-cell period lands near 0.6),
## i.e. a clump you can see the shape of rather than a value that changes every square.
const PAINT_LAG1_FLOOR: float = 0.55

## ROUGHNESS: the mean second difference |L[i-1] - 2L[i] + L[i+1]| as a fraction of mean luminance.
##
## The obvious metric, a plain neighbour step, is wrong here and measuring it proved why: a smooth
## shading gradient across a rock face steps between neighbours exactly as much as a checkerboard does,
## so a step ceiling punishes FORM (the thing the terrain most needs) while a checkerboard hides under
## it. The second difference vanishes on any straight ramp and peaks on alternation, which is precisely
## the distinction the eye makes between "this surface is curving" and "these are two different tiles".
##
## L is the flat mean of the three channels, (R + G + B) / 3, and NOT either of the two weighted lumas
## used elsewhere in this repo. That is deliberate and it has to stay: the ceiling below was calibrated
## against this quantity, the two conventions disagree by 1.4 to 1.9 on this game's colours, and swapping
## one in would move every number here without anybody touching the paint.
##
## The ceiling is calibrated, not derived. The rock printed 12.7% across a face and 17.9% down one, which
## is unmistakably a grid of tiles at any magnification; the retune that made it read as rock lands at
## 5.9% and 5.6%. 6.5% is that, plus enough room to move a constant without tripping; this number's job
## is to stop the slide back, not to name a target. (For scale: a term alternating +/-A every cell
## contributes 4A, so the whole budget is about a 1.6% per-cell wobble.)
const PAINT_ROUGH_CEIL: float = 0.065

## Fine rows the slabs are measured over. Kept at the rows the pooled statistic used, so every number
## this file has ever printed stays on one scale and the two can be read against each other. Deep enough
## to be past the surface cap, the moss band and the sky-scatter rows: `_moss_life` is zero below coarse
## row 34 and `_soil` reaches 40 fine rows below a column's surface, so what is measured here is the
## texture passes and nothing else.
const PAINT_ROW0: int = 60
const PAINT_ROW1: int = 110

## The three grammars, by their index in FineTerrain's GRAM_* tables. Named here rather than reached for
## through the enum so the printed report can say which is which.
const GRAMMARS: Array[String] = ["clastic", "bedded", "massive"]

## `_profile` population selectors that are not a grammar index. Negative so they cannot collide with
## one, named so a call site cannot read as a magic number.
const ANY_GRAMMAR: int = -1
const STRADDLING: int = -2


func _initialize() -> void:
	var fails: int = 0
	print("== texture fields must resolve on the sample grid ==")
	var fine: FineTerrain = FineTerrain.new(24, 24, 1337)
	var sim: FactorySim = FactorySim.new()
	sim.world_seed = 1337
	sim.rebuild_fine_terrain()          # builds the molding noise fields lazily

	# name -> [noise, x_step, y_step]. The step is how far the real paint loop moves per sample, which is
	# the thing that actually matters: a field sampled at x*0.38 is being asked for a far lower spatial
	# frequency than the same field sampled at x*1.0, and only the AS-SAMPLED rate can be judged.
	var fields: Array = [
		["fine.grain (octave 1)", fine._grain, FineTerrain.GRAIN_XSTRETCH, 0.0],
		["fine.grain (octave 2)", fine._grain2, FineTerrain.GRAIN_XSTRETCH, 0.0],
		["fine.grain down-column", fine._grain, 0.0, 1.0],
		["fine.grain2 down-column", fine._grain2, 0.0, 1.0],
		["fine.patch", fine._patch, 1.0, 0.0],
		["fine.stone", fine._stone, 1.0, 0.0],
		["fine.crack", fine._crack, 1.4, 0.0],
		["fine.moss", fine._moss, 1.0, 0.0],
		["fine.tonal drift", fine._noise, 0.35, 0.0],
		["fine.hue x", fine._huex, 1.0, 0.0],
		["fine.hue y", fine._huey, 1.0, 0.0],
		["sim.fine_edge", sim._fine_edge, 1.0, 0.0],
		["sim.fine_grit", sim._fine_grit, 1.0, 0.0],
	]
	for f: Array in fields:
		var label: String = f[0]
		var noise: FastNoiseLite = f[1]
		var r: float = _lag1(noise, float(f[2]), float(f[3]))
		if r >= LAG1_FLOOR:
			print("  PASS: %-24s lag-1 correlation %.2f" % [label, r])
		else:
			printerr("  FAIL: %-24s lag-1 correlation %.2f — this field is STATIC, not texture" % [label, r])
			fails += 1

	fails += _check_paint()
	_report_world()

	if fails == 0:
		print("check_texture: PASS — fields resolve, and every grammar's rock reads as rock")
		quit(0)
	else:
		print("check_texture: FAIL (%d)" % fails)
		quit(1)


## THE ASSERTION. One slab per grammar, each held to the ceiling and the floor above.
func _check_paint() -> int:
	print("== and the rock each grammar paints must read as rock ==")
	var fails: int = 0
	var rough_across: Array[float] = []
	for gram: int in GRAMMARS.size():
		var fine: FineTerrain = _slab(gram)
		# THE INPUT THAT DOES NOT TRAVEL IN THE SIGNATURE. `FineTerrain.grammar_at` is a Callable set on
		# the instance, not a `rebake` parameter, and `_grammar_of` guards it with `.is_valid()` — the
		# correct guard, which is exactly why nobody found out for 89 green layers that this file was
		# omitting it and baking every material as GRAM_CLASTIC. It measured 5.93% and passed while the
		# game printed 10.40% against a 6.5% ceiling. The painter now raises a flag when it bakes flat;
		# assert on it, because an omitted input must be impossible to miss rather than impossible.
		if fine.baked_flat:
			printerr("  FAIL: the %s slab baked FLAT — grammar_at never reached the paint, so this "
				% GRAMMARS[gram] + "number belongs to Clastic whatever the label says")
			fails += 1
		var prof: Dictionary = _measure(fine)
		for axis: String in ["across a face", "down a face"]:
			var p: Array = prof[axis]
			var r: float = p[0]
			var rough: float = p[1]
			var n: int = int(p[2])
			if axis == "across a face":
				rough_across.append(rough)
			if r >= PAINT_LAG1_FLOOR and rough <= PAINT_ROUGH_CEIL:
				print("  PASS: %-8s %-14s lag-1 %.2f, roughness %.1f%%  (%d samples)"
					% [GRAMMARS[gram], axis, r, rough * 100.0, n])
			else:
				# TWO DECIMALS ON THE FAILING LINE. At %.1f a roughness a few ten-thousandths over the
				# ceiling prints as equal to it, so the line reads "6.5% (ceil 6.5%)" and looks like the
				# assertion is wrong rather than the paint. The passing line above can stay coarse.
				printerr("  FAIL: %-8s %-14s lag-1 %.2f (floor %.2f), roughness %.2f%% (ceil %.2f%%)"
					% [GRAMMARS[gram], axis, r, PAINT_LAG1_FLOOR, rough * 100.0, PAINT_ROUGH_CEIL * 100.0])
				fails += 1

	# THREE LABELS ARE NOT THREE MEASUREMENTS UNLESS THEY DISAGREE. The ceiling alone cannot catch a
	# grammar system that has stopped reaching the paint, because a collapse to Clastic collapses to a
	# number UNDER the ceiling — which is the precise shape of the defect this layer already missed once.
	# So the readings themselves are asserted to be distinct. Exact inequality, not a tolerance: the bake
	# is deterministic in (seed, coords), so two grammars that genuinely differ cannot tie, and two that
	# tie are not two grammars. No magnitude is being judged here, only that the three are three.
	# Counted on its own and not folded into `fails` until the end, so this line reports ITS property
	# rather than the state of the ceiling assertions above it. A PASS that goes quiet because something
	# unrelated failed is a PASS nobody can read.
	var ties: int = 0
	for a: int in GRAMMARS.size():
		for b: int in range(a + 1, GRAMMARS.size()):
			if rough_across[a] == rough_across[b]:
				printerr("  FAIL: %s and %s paint IDENTICALLY (both %.4f%%) — the grammar is not reaching "
					% [GRAMMARS[a], GRAMMARS[b], rough_across[a] * 100.0] + "the paint")
				ties += 1
	if ties == 0:
		print("  PASS: the three grammars paint three different rocks (%.2f%%, %.2f%%, %.2f%% across)"
			% [rough_across[0] * 100.0, rough_across[1] * 100.0, rough_across[2] * 100.0])
	return fails + ties


## One grammar's slab: solid, uniform, and built out of nothing but Callables.
##
## There is no FactorySim here and no LayeredWorldGen, which is the whole point — a number that cannot be
## reached from worldgen cannot be moved by a worldgen edit. `rebake` already supports this; its own
## docstring calls out "callers with no array, such as check_texture building a synthetic world".
##
## What the slab holds fixed, and why each one is safe to hold:
##   * every coarse and fine cell solid, so `_deep` below is true everywhere but the one-cell border,
##     `_air_weight` is zero and `_sky_form` is zero — no carved-edge passes, which are SUPPOSED to swing
##     hard and are form rather than noise;
##   * no walkable surface (`surface_at` answers past `HeightmapWorldGen.SURFACE_ROW_MAX`, which
##     `FineTerrain.walked_surface` maps to NO_SURFACE), so the cap band and the whole soil profile are
##     out, the same way they are out for any column that is rock all the way up;
##   * flat grey for body and wall, and a zero tone, exactly as the pooled version had them: the property
##     under test is variation, and the coarse tone field is measured by tools/check_grid against the
##     real palette;
##   * the same seed, the same fine rows and the same fine coordinates as the world bake, so the noise
##     fields are sampled in the same places and the slab number and the world number are comparable
##     rather than merely similar.
##
## WHAT THIS DOES NOT MEASURE, said plainly. A slab is one material, so a second difference that straddles
## a contact between two materials is not in this population at all — and it is not in the per-grammar
## split of the world bake either, which requires all three cells of the triple to agree. The census
## measures them separately and they come out at 11.2% across a face, the loudest population in the
## frame, on about 8% of the samples. Nothing in the suite holds them to a number today. Neither does
## this file: 11.2% is what a step between two different rocks looks like, and calling that a defect
## needs a picture rather than a comparison against a ceiling calibrated on rock interiors.
func _slab(gram: int) -> FineTerrain:
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	var fine: FineTerrain = FineTerrain.new(cols, rows, 1337)
	fine.grammar_at = func(_c: Vector2i) -> int: return gram
	var grey := Color(0.42, 0.42, 0.42)
	var no_surface: int = HeightmapWorldGen.SURFACE_ROW_MAX + 1
	fine.rebake(
		func(_c: Vector2i) -> bool: return true,
		func(_fx: int, _fy: int) -> bool: return true,
		func(_c: Vector2i) -> Color: return grey,
		func(_c: Vector2i) -> Color: return grey,
		func(_col: int) -> int: return no_surface,
		func(_c: Vector2i) -> Vector2: return Vector2.ZERO,
		func(_c: Vector2i) -> bool: return false)
	return fine


## Luminance and roughness of a baked slab over the measured rows, on both axes.
func _measure(fine: FineTerrain) -> Dictionary:
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	var sub: int = FineTerrain.SUBDIV
	var fcols: int = cols * sub
	var frows: int = rows * sub
	var lum := PackedFloat32Array()
	lum.resize(fcols * frows)
	var interior := PackedByteArray()
	interior.resize(lum.size())
	for fy: int in range(PAINT_ROW0 * sub, PAINT_ROW1 * sub):
		for fx: int in range(fcols):
			var i: int = fy * fcols + fx
			var i4: int = i * 4
			lum[i] = (float(fine._data[i4]) + float(fine._data[i4 + 1]) + float(fine._data[i4 + 2])) / 3.0
			# The slab's only non-interior cells are the outermost ring, where the painter reads
			# out-of-bounds as air and applies AO. Excluded for the same reason a carved edge is.
			interior[i] = 1 if (fx > 0 and fx < fcols - 1 and fy > 0 and fy < frows - 1) else 0
	return {
		"across a face": _profile(lum, interior, 1),
		"down a face": _profile(lum, interior, fcols),
	}


## THE REPORT, AND IT ASSERTS NOTHING. Said once and loudly because a number printed next to assertions
## reads like one: everything below is a census, not a guard.
##
## It bakes the world that actually generates and prints what is in the measured rows and how each
## grammar reads there, so the mix the pooled statistic used to hide stays visible and the historical
## pooled figure stays comparable. It is deliberately not asserted: it is a property of worldgen, it
## moves when worldgen moves, and holding a paint layer to it is the defect this file was repaired for.
## The guard that belongs on a material population belongs in a worldgen layer, and there isn't one.
func _report_world() -> void:
	print("== census: what worldgen actually put in rows %d..%d (REPORT ONLY, nothing asserted) =="
		% [PAINT_ROW0, PAINT_ROW1])
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	var sim: FactorySim = FactorySim.new()
	sim.load_world(LayeredWorldGen.new().generate(cols, rows, 1337))
	sim.rebuild_fine_terrain()

	var defs: Dictionary = {}
	var mdir := DirAccess.open("res://src/data/materials")
	for f: String in mdir.get_files():
		var mdef: MaterialDef = load("res://src/data/materials/" + f.trim_suffix(".remap")) as MaterialDef
		if mdef != null:
			defs[mdef.id] = mdef
	var fine: FineTerrain = FineTerrain.new(cols, rows, 1337)
	fine.grammar_at = func(c: Vector2i) -> int:
		var dd: MaterialDef = defs.get(sim.material_at(c))
		return dd.grammar if dd != null else 0
	var grey := Color(0.42, 0.42, 0.42)
	fine.rebake(
		func(c: Vector2i) -> bool: return sim.is_solid(c),
		func(fx: int, fy: int) -> bool: return sim.fine_is_solid(fx, fy),
		func(_c: Vector2i) -> Color: return grey,
		func(_c: Vector2i) -> Color: return grey,
		func(col: int) -> int: return sim.surface_row(col),
		func(_c: Vector2i) -> Vector2: return Vector2.ZERO,
		func(_c: Vector2i) -> bool: return false)

	var sub: int = FineTerrain.SUBDIV
	var fcols: int = cols * sub
	var lum := PackedFloat32Array()
	lum.resize(fcols * rows * sub)
	var interior := PackedByteArray()
	interior.resize(lum.size())
	# The grammar of each deep cell's own coarse parent. A triple counts for a grammar only when all
	# three members carry it, so a triple straddling a contact is attributed to neither of them and gets
	# a bucket of its own below.
	var gram := PackedByteArray()
	gram.resize(lum.size())
	var hist: Dictionary = {}
	var rows_with: Dictionary = {}
	var total: int = 0
	for fy: int in range(PAINT_ROW0 * sub, PAINT_ROW1 * sub):
		for fx: int in range(fcols):
			var i: int = fy * fcols + fx
			var i4: int = i * 4
			lum[i] = (float(fine._data[i4]) + float(fine._data[i4 + 1]) + float(fine._data[i4 + 2])) / 3.0
			if not _deep(sim, fx, fy):
				continue
			interior[i] = 1
			var cell := Vector2i(fx / sub, fy / sub)
			var mid: StringName = sim.material_at(cell)
			var d: MaterialDef = defs.get(mid)
			gram[i] = d.grammar if d != null else 0
			hist[mid] = int(hist.get(mid, 0)) + 1
			if not rows_with.has(mid):
				rows_with[mid] = {}
			rows_with[mid][cell.y] = true
			total += 1

	var keys: Array = hist.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(hist[a]) > int(hist[b]))
	for k: Variant in keys:
		var d3: MaterialDef = defs.get(k)
		var g3: int = d3.grammar if d3 != null else 0
		var rs: Array = rows_with[k].keys()
		rs.sort()
		print("   %-12s %-8s %6.2f%% of deep cells   coarse rows %d..%d"
			% [String(k), GRAMMARS[g3], 100.0 * float(hist[k]) / float(maxi(total, 1)),
				int(rs[0]), int(rs[rs.size() - 1])])
	for axis: Array in [["across a face", 1], ["down a face", fcols]]:
		var step: int = int(axis[1])
		var all: Array = _profile(lum, interior, step)
		print("   pooled  %-14s lag-1 %.2f  roughness %.2f%%  (%d samples)"
			% [axis[0], all[0], all[1] * 100.0, int(all[2])])
		for g4: int in GRAMMARS.size():
			var p: Array = _profile(lum, interior, step, gram, g4)
			print("      %-8s %-14s lag-1 %.2f  roughness %.2f%%  (%d samples)"
				% [GRAMMARS[g4], axis[0], p[0], p[1] * 100.0, int(p[2])])
		# MEASURED IN ITS OWN PASS, not backed out of the pooled figure by subtraction: every bucket has
		# its own mean luminance, so the arithmetic would be wrong. Contacts are the roughest population
		# in the frame and they belong to no material, which is exactly why a per-material repair — this
		# one included — cannot see them. Whether an 11% step at a material boundary is a defect or is
		# simply what a boundary looks like is an open question and not one a number settles.
		var st: Array = _profile(lum, interior, step, gram, STRADDLING)
		print("      contact  %-14s lag-1 %.2f  roughness %.2f%%  (%d samples)"
			% [axis[0], st[0], st[1] * 100.0, int(st[2])])


## A fine cell in the MIDDLE of rock: itself and all eight fine neighbours solid.
func _deep(sim: FactorySim, fx: int, fy: int) -> bool:
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			if not sim.fine_is_solid(fx + dx, fy + dy):
				return false
	return true


## Lag-1 Pearson correlation and mean relative roughness along one axis, over runs of THREE consecutive
## in-mask cells (the triple is what the second difference needs, and requiring all three in the mask
## keeps carved edges, which are supposed to be sharp, out of the statistic). Returns [r, rough, n].
##
## `want` selects a sub-population by grammar: ANY_GRAMMAR takes every in-mask triple, STRADDLING takes
## only the triples whose three members do NOT agree, and 0..2 takes only the triples where all three
## carry that grammar. Anything but ANY_GRAMMAR needs `gram`.
func _profile(lum: PackedFloat32Array, interior: PackedByteArray, step: int,
		gram: PackedByteArray = PackedByteArray(), want: int = ANY_GRAMMAR) -> Array:
	var n: int = 0
	var sa: float = 0.0
	var sb: float = 0.0
	var rough: float = 0.0
	var lo: int = maxi(0, -step) + absi(step)
	var hi: int = lum.size() - maxi(0, step) - absi(step)
	for i: int in range(lo, hi):
		if not _wanted(interior, gram, want, i, step):
			continue
		n += 1
		sa += lum[i]
		sb += lum[i + step]
		rough += absf(lum[i - step] - 2.0 * lum[i] + lum[i + step])
	if n < 256:
		return [0.0, 9.9, n]                        # too few samples to judge — fail loudly, never silently
	var ma: float = sa / float(n)
	var mb: float = sb / float(n)
	var cov: float = 0.0
	var va: float = 0.0
	var vb: float = 0.0
	for i: int in range(lo, hi):
		if not _wanted(interior, gram, want, i, step):
			continue
		var a: float = lum[i] - ma
		var b: float = lum[i + step] - mb
		cov += a * b
		va += a * a
		vb += b * b
	var r: float = 0.0 if va <= 0.0 or vb <= 0.0 else cov / sqrt(va * vb)
	return [r, rough / float(n) / maxf(ma, 1.0), n]


## Is the triple centred on `i` in the population `want` names? Both passes of `_profile` have to answer
## this identically or the mean and the covariance are taken over different samples, so they ask once.
func _wanted(interior: PackedByteArray, gram: PackedByteArray, want: int, i: int, step: int) -> bool:
	if interior[i] == 0 or interior[i - step] == 0 or interior[i + step] == 0:
		return false
	if want == ANY_GRAMMAR:
		return true
	var agree: bool = gram[i] == gram[i - step] and gram[i] == gram[i + step]
	if want == STRADDLING:
		return not agree
	return agree and gram[i] == want


## Lag-1 Pearson correlation of the field sampled along one integer step of the paint loop.
func _lag1(noise: FastNoiseLite, dx: float, dy: float) -> float:
	var v := PackedFloat32Array()
	v.resize(SAMPLES)
	for i: int in SAMPLES:
		v[i] = noise.get_noise_2d(float(i) * dx, float(i) * dy)
	var n: int = SAMPLES - 1
	var sa: float = 0.0
	var sb: float = 0.0
	for i: int in n:
		sa += v[i]
		sb += v[i + 1]
	var ma: float = sa / float(n)
	var mb: float = sb / float(n)
	var cov: float = 0.0
	var va: float = 0.0
	var vb: float = 0.0
	for i: int in n:
		var a: float = v[i] - ma
		var b: float = v[i + 1] - mb
		cov += a * b
		va += a * a
		vb += b * b
	return 0.0 if va <= 0.0 or vb <= 0.0 else cov / sqrt(va * vb)
