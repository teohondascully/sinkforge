extends "res://tests/test_base.gd"

## Golden vectors computed from a from-scratch Python reference implementation of the same hash and
## bilinear-smoothstep interpolation -- not from memory, not from the GDScript under test.

func _initialize() -> void:
	_test_corner_hashes_match_reference()
	_test_sample_matches_reference()
	_test_sample_stays_in_range()
	_test_same_inputs_same_output()
	_test_different_seeds_diverge()
	_test_high_seed_bits_reach_the_field()
	_test_calibrated_distribution_matches_fastnoiselite()
	_finish("value_noise")


func _test_corner_hashes_match_reference() -> void:
	var cases: Array = [
		{"x": 0, "y": 0, "seed": 0, "expected": 0},
		{"x": 1, "y": 0, "seed": 0, "expected": 1447796004},
		{"x": 0, "y": 1, "seed": 0, "expected": 4065948945},
		{"x": 5, "y": 7, "seed": 42, "expected": 446790201},
		{"x": 47, "y": 1023, "seed": 20260826, "expected": 4098068227},
	]
	for c: Dictionary in cases:
		var got: int = ValueNoise._lattice_hash(c["x"], c["y"], c["seed"])
		_check(got == c["expected"], "_lattice_hash(%d, %d, %d) = %d (expected %d)" %
			[c["x"], c["y"], c["seed"], got, c["expected"]])


func _test_sample_matches_reference() -> void:
	var cases: Array = [
		{"seed": 0, "x": 0.0, "y": 0.0, "expected": -1.0},
		{"seed": 0, "x": 3.7, "y": 12.2, "expected": -0.02192380046957079},
		{"seed": 0, "x": 100.05, "y": 500.9, "expected": -0.7996665834014892},
		{"seed": 0, "x": 47.99, "y": 1023.01, "expected": -0.43441079387090215},
		{"seed": 0, "x": 0.001, "y": 0.001, "expected": -0.9999923025406601},
		{"seed": 42, "x": 0.0, "y": 0.0, "expected": -0.9061786811580366},
		{"seed": 42, "x": 3.7, "y": 12.2, "expected": -0.43373889976460017},
		{"seed": 20260826, "x": 100.05, "y": 500.9, "expected": -0.85649048485134},
		{"seed": 20260826, "x": 47.99, "y": 1023.01, "expected": -0.9756363880094472},
	]
	for c: Dictionary in cases:
		var got: float = ValueNoise.sample(c["x"], c["y"], c["seed"])
		_check(is_equal_approx(got, c["expected"]), "sample(%s, %s, %d) = %.16f (expected %.16f)" %
			[c["x"], c["y"], c["seed"], got, c["expected"]])


func _test_sample_stays_in_range() -> void:
	var rng: SplitRng = SplitRng.new(1)
	for i: int in 2000:
		var x: float = rng.next_float() * 200.0
		var y: float = rng.next_float() * 2000.0
		var v: float = ValueNoise.sample(x, y, 777)
		_check(v >= -1.0 and v <= 1.0, "sample(%f, %f, 777) = %f is in [-1, 1]" % [x, y, v])


func _test_same_inputs_same_output() -> void:
	var a: float = ValueNoise.sample(12.34, 56.78, 999)
	var b: float = ValueNoise.sample(12.34, 56.78, 999)
	_check(a == b, "sample() is a pure function -- same inputs give bit-identical output")


func _test_different_seeds_diverge() -> void:
	var a: float = ValueNoise.sample(12.34, 56.78, 1)
	var b: float = ValueNoise.sample(12.34, 56.78, 2)
	_check(a != b, "different seeds sample differently at the same point")


## THE GUARD THAT WAS MISSING (D0254). `_test_different_seeds_diverge` above compares seeds 1 and 2,
## which differ in their LOWEST bits -- and the defect it failed to catch lived entirely in the HIGH
## ones. `_lattice_hash` masked `seed & 0xFFFF`, so every pair of seeds congruent mod 65,536 generated a
## bit-identical world, and a test that only ever varies the bottom bit of a seed can never observe that.
## A divergence check is only as wide as the bits it actually moves.
##
## The offsets below are chosen to walk a bit up through the word rather than to be "big numbers":
## 2^16 is the old mask boundary itself, 2^20 and 2^32 sit above it, and 2^32 additionally exercises the
## `seed >> 32` fold that carries the high half of a 64-bit seed in at all. `SplitRng` supplies full
## 64-bit seeds, so that half is real input, not a hypothetical.
##
## Asserted as PAIRWISE-DISTINCT over the whole set rather than each-differs-from-the-base, because the
## weaker form passes on a hash that maps every offset seed to one single other value.
func _test_high_seed_bits_reach_the_field() -> void:
	var offsets: Array[int] = [0, 1 << 16, 1 << 20, 1 << 32]
	var base: int = 1337
	var seen: Dictionary = {}
	for off: int in offsets:
		var v: float = ValueNoise.sample(3.7, 11.3, base + off)
		seen[v] = int(seen.get(v, 0)) + 1
	_check_over(offsets.size(), seen.size() == offsets.size(),
		"seeds differing only ABOVE bit 16 sample differently: %d distinct values from %d seeds "
		% [seen.size(), offsets.size()]
		+ "(before D0254 all four returned -0.0519986834, because the seed was masked to 16 bits)")


## D0045: `FASTNOISELITE_SD_CALIBRATION` exists so a threshold ported from a `FastNoiseLite`-tuned
## legacy system clears at approximately the rate it was tuned for. This re-measures both distributions
## directly (not from memory of the number that motivated the constant) at the real cave-carving
## frequency/x_stretch (`data/strata/shallow_clay.yaml`) across several seeds, so a future change to the
## hash, the interpolation, or the calibration constant itself that drifts this back apart is caught
## here rather than discovered later as an unexplained change in cave density.
func _test_calibrated_distribution_matches_fastnoiselite() -> void:
	var x_stretch: float = 2.1
	var frequency: float = 0.11
	var vn_sum: float = 0.0
	var vn_sq_sum: float = 0.0
	var fnl_sum: float = 0.0
	var fnl_sq_sum: float = 0.0
	var n: int = 0
	for seed_i: int in range(5):
		var seed: int = 300000 + seed_i * 7919
		var fnl := FastNoiseLite.new()
		fnl.seed = seed
		fnl.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fnl.frequency = frequency
		for col: int in range(0, 48):
			var nx: float = float(col) / x_stretch * frequency
			for row: int in range(6, 1024, 8):
				var ny: float = float(row) * frequency
				var vn: float = ValueNoise.sample(nx, ny, seed) * ValueNoise.FASTNOISELITE_SD_CALIBRATION
				var fnl_v: float = fnl.get_noise_2d(float(col) / x_stretch, float(row))
				vn_sum += vn
				vn_sq_sum += vn * vn
				fnl_sum += fnl_v
				fnl_sq_sum += fnl_v * fnl_v
				n += 1
	var vn_mean: float = vn_sum / float(n)
	var fnl_mean: float = fnl_sum / float(n)
	var vn_sd: float = sqrt(maxf(0.0, vn_sq_sum / float(n) - vn_mean * vn_mean))
	var fnl_sd: float = sqrt(maxf(0.0, fnl_sq_sum / float(n) - fnl_mean * fnl_mean))
	_check(n > 10000, "sanity: measured over a real sample size (got %d)" % n)
	# +/-15% band: wide enough that this isn't re-testing the exact calibration ratio to the digit
	# (that's what the constant's own derivation comment records), tight enough to catch a real drift --
	# e.g. an accidental change to FASTNOISELITE_SD_CALIBRATION's magnitude, or a hash/interpolation
	# change that alters this file's own output distribution shape.
	_check(fnl_sd > 0.0 and absf(vn_sd - fnl_sd) / fnl_sd < 0.15,
		"calibrated ValueNoise SD (%.4f) stays within 15%% of FastNoiseLite's real measured SD (%.4f) -- ratio %.3f" %
		[vn_sd, fnl_sd, vn_sd / fnl_sd])
