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

## Below this, consecutive samples are effectively independent. It corresponds to roughly three samples
## per noise feature, which is the honest boundary: fewer than three and there is no shape left to see,
## only a value that changes every cell. Fields well under it are not 'fine detail', they are static.
const LAG1_FLOOR: float = 0.25
const SAMPLES: int = 4096


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

	if fails == 0:
		print("check_texture: PASS — every field resolves on the grid it is sampled on")
		quit(0)
	else:
		print("check_texture: FAIL (%d)" % fails)
		quit(1)


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
