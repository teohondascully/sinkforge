extends SceneTree

## NO TEXTURE FIELD MAY BE WHITE NOISE — the Nyquist guard.
##
## Every procedural texture in this game is a FastNoiseLite field sampled on an INTEGER grid: one sample
## per fine cell, one per coarse cell. A noise field only produces the smooth, clumped, structured values
## it is drawn for while its period is comfortably longer than that sample spacing. Push the frequency to
## 1.0 and the period is one sample; neighbouring cells become statistically independent and the field
## stops being texture and becomes STATIC — visually a checkerboard, and worse, a checkerboard that
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
## PART TWO — AND THE PAINT IS WHAT YOU ACTUALLY SEE.
##
## Passing part one is necessary and nowhere near sufficient, which cost a whole round to learn. Every
## input field can clear the floor and the painted rock still print as confetti, for three reasons the
## ingredient test structurally cannot see:
##   1. AMPLITUDE. A field at the edge of resolvable, multiplied by a large swing, is a visible
##      checkerboard; the same field at a tenth the amplitude is grain. Correlation is scale-free and
##      says nothing about how loud the term is.
##   2. THRESHOLDS. `if stone > THRESH` turns a smooth field into a binary mask, and a mask is far less
##      correlated than the field it came from — a 0.5-correlated field can threshold into scattered
##      single cells.
##   3. STACKING. Six independent terms each individually quiet sum into one loud one.
## So the second half of this file bakes the REAL FineTerrain over a REAL generated world and measures
## the pixels. Flat grey stands in for the material palette, because the property under test is variation
## and a flat base makes every number below attributable to the texture passes alone.
##
## The unit that matters here is a FINE CELL: one texel, 8 world px, and at the game's zoom about twelve
## SCREEN pixels. Anything that changes value cell to cell is not fine detail at that size — it is a
## twelve-pixel checker, which is exactly what "blocky" means when a player says it.

## Below this, consecutive samples are effectively independent. It corresponds to roughly three samples
## per noise feature, which is the honest boundary: fewer than three and there is no shape left to see,
## only a value that changes every cell. Fields well under it are not 'fine detail', they are static.
const LAG1_FLOOR: float = 0.25
const SAMPLES: int = 4096

## The painted rock's own lag-1 correlation, measured on deep interior cells. 0.55 is a feature spanning
## roughly four fine cells (cos(2*PI/4) = 0.0 is one that alternates; a four-cell period lands near 0.6),
## i.e. a clump you can see the shape of rather than a value that changes every square.
const PAINT_LAG1_FLOOR: float = 0.55

## ROUGHNESS — the mean second difference |L[i-1] - 2L[i] + L[i+1]| as a fraction of mean luminance.
##
## The obvious metric, a plain neighbour step, is wrong here and measuring it proved why: a smooth
## shading gradient across a rock face steps between neighbours exactly as much as a checkerboard does,
## so a step ceiling punishes FORM — the thing the terrain most needs — while a checkerboard hides under
## it. The second difference vanishes on any straight ramp and peaks on alternation, which is precisely
## the distinction the eye makes between "this surface is curving" and "these are two different tiles".
##
## The ceiling is calibrated, not derived. The rock printed 12.7% across a face and 17.9% down one, which
## is unmistakably a grid of tiles at any magnification; the retune that made it read as rock lands at
## 5.9% and 5.6%. 6.5% is that, plus enough room to move a constant without tripping — this number's job
## is to stop the slide back, not to name a target. (For scale: a term alternating +/-A every cell
## contributes 4A, so the whole budget is about a 1.6% per-cell wobble.)
const PAINT_ROUGH_CEIL: float = 0.065

## Coarse rows the paint is measured over: deep enough to be past the surface cap, the moss band and the
## sky-scatter rows, so what is measured is plain buried rock and nothing else.
const PAINT_ROW0: int = 60
const PAINT_ROW1: int = 110


func _initialize() -> void:
	var fails: int = 0
	print("== texture fields must resolve on the sample grid ==")
	var fine: FineTerrain = FineTerrain.new(24, 24, 1337)
	var sim: FactorySim = FactorySim.new()
	sim.world_seed = 1337
	sim.rebuild_fine_terrain()          # builds the molding noise fields lazily

	# name -> [noise, x_step, y_step]. The step is how far the real paint loop moves per sample, which is
	# the thing that actually matters — a field sampled at x*0.38 is being asked for a far lower spatial
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

	if fails == 0:
		print("check_texture: PASS — fields resolve, and the rock they paint reads as rock")
		quit(0)
	else:
		print("check_texture: FAIL (%d)" % fails)
		quit(1)


## Bake the real fine terrain over a real world and measure the PIXELS. Only deep interior cells count —
## a cell whose eight fine neighbours are all solid — because the carved-edge passes (AO, rim, moss,
## back-rock) are SUPPOSED to swing hard at a boundary; that is form, not noise. What must be quiet is
## the middle of a rock face, which is most of what is on screen and all of what reads as "flat and
## blocky" when it isn't.
func _check_paint() -> int:
	print("== and the rock it paints must read as rock ==")
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	var sim: FactorySim = FactorySim.new()
	sim.load_world(LayeredWorldGen.new().generate(cols, rows, 1337))
	sim.rebuild_fine_terrain()
	var fine: FineTerrain = FineTerrain.new(cols, rows, 1337)
	var grey := Color(0.42, 0.42, 0.42)
	fine.rebake(
		func(c: Vector2i) -> bool: return sim.is_solid(c),
		func(fx: int, fy: int) -> bool: return sim.fine_is_solid(fx, fy),
		func(_c: Vector2i) -> Color: return grey,
		func(_c: Vector2i) -> Color: return grey,
		func(col: int) -> int: return sim.surface_row(col))

	var sub: int = FineTerrain.SUBDIV
	var fcols: int = cols * sub
	var lum := PackedFloat32Array()
	lum.resize(fcols * rows * sub)
	var interior := PackedByteArray()
	interior.resize(lum.size())
	for fy: int in range(PAINT_ROW0 * sub, PAINT_ROW1 * sub):
		for fx: int in range(fcols):
			var i: int = fy * fcols + fx
			var i4: int = i * 4
			lum[i] = (float(fine._data[i4]) + float(fine._data[i4 + 1]) + float(fine._data[i4 + 2])) / 3.0
			interior[i] = 1 if _deep(sim, fx, fy) else 0

	var fails: int = 0
	for axis: Array in [["across a face", 1, 0], ["down a face", 0, 1]]:
		var step: int = int(axis[1]) + int(axis[2]) * fcols
		var prof: Array = _profile(lum, interior, step)
		var r: float = prof[0]
		var rough: float = prof[1]
		var n: int = int(prof[2])
		if r >= PAINT_LAG1_FLOOR and rough <= PAINT_ROUGH_CEIL:
			print("  PASS: paint %-14s lag-1 %.2f, roughness %.1f%%  (%d samples)"
				% [axis[0], r, rough * 100.0, n])
		else:
			printerr("  FAIL: paint %-14s lag-1 %.2f (floor %.2f), roughness %.1f%% (ceil %.1f%%)"
				% [axis[0], r, PAINT_LAG1_FLOOR, rough * 100.0, PAINT_ROUGH_CEIL * 100.0])
			fails += 1
	return fails


## A fine cell in the MIDDLE of rock: itself and all eight fine neighbours solid.
func _deep(sim: FactorySim, fx: int, fy: int) -> bool:
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			if not sim.fine_is_solid(fx + dx, fy + dy):
				return false
	return true


## Lag-1 Pearson correlation and mean relative roughness along one axis, over runs of THREE consecutive
## deep-interior cells (the triple is what the second difference needs, and requiring all three interior
## keeps carved edges — which are supposed to be sharp — out of the statistic). Returns [r, rough, n].
func _profile(lum: PackedFloat32Array, interior: PackedByteArray, step: int) -> Array:
	var n: int = 0
	var sa: float = 0.0
	var sb: float = 0.0
	var rough: float = 0.0
	var lo: int = maxi(0, -step) + absi(step)
	var hi: int = lum.size() - maxi(0, step) - absi(step)
	for i: int in range(lo, hi):
		if interior[i] == 0 or interior[i - step] == 0 or interior[i + step] == 0:
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
		if interior[i] == 0 or interior[i - step] == 0 or interior[i + step] == 0:
			continue
		var a: float = lum[i] - ma
		var b: float = lum[i + step] - mb
		cov += a * b
		va += a * a
		vb += b * b
	var r: float = 0.0 if va <= 0.0 or vb <= 0.0 else cov / sqrt(va * vb)
	return [r, rough / float(n) / maxf(ma, 1.0), n]


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
