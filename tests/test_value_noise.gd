extends "res://tests/test_base.gd"

## Golden vectors computed from a from-scratch Python reference implementation of the same hash and
## bilinear-smoothstep interpolation -- not from memory, not from the GDScript under test.

func _initialize() -> void:
	_test_corner_hashes_match_reference()
	_test_sample_matches_reference()
	_test_sample_stays_in_range()
	_test_same_inputs_same_output()
	_test_different_seeds_diverge()
	_finish("value_noise")


func _test_corner_hashes_match_reference() -> void:
	var cases: Array = [
		{"x": 0, "y": 0, "seed": 0, "expected": 0},
		{"x": 1, "y": 0, "seed": 0, "expected": 1447796004},
		{"x": 0, "y": 1, "seed": 0, "expected": 4065948945},
		{"x": 5, "y": 7, "seed": 42, "expected": 3568898538},
		{"x": 47, "y": 1023, "seed": 20260826, "expected": 3929133372},
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
		{"seed": 42, "x": 0.0, "y": 0.0, "expected": -0.4941857176586487},
		{"seed": 42, "x": 3.7, "y": 12.2, "expected": -0.588743680687817},
		{"seed": 20260826, "x": 100.05, "y": 500.9, "expected": 0.5857218396852522},
		{"seed": 20260826, "x": 47.99, "y": 1023.01, "expected": -0.6824269880668973},
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
