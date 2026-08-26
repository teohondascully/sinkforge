extends "res://tests/test_base.gd"

## Golden isqrt vectors from Python's math.isqrt -- independent reference, not memory. Covers zero, one,
## perfect squares, and random values up to 2^62 (D0029: the largest magnitude length_sq() can produce
## for the largest pair of valid Fx deltas -- was 2^47 before that fix widened length_sq()'s own range).

func _initialize() -> void:
	_test_from_int_to_float_roundtrip()
	_test_add_sub()
	_test_mul_basic()
	_test_mul_matches_float_for_small_values()
	_test_div_basic()
	_test_div_by_zero_returns_zero_and_does_not_hang()
	_test_div_by_zero_logs_via_push_error()
	_test_lerp()
	_test_isqrt_known_values()
	_test_length_pythagorean_triples()
	_test_length_works_far_beyond_the_old_181px_limit()
	_test_length_sq_no_overflow_at_fx_own_outer_limit()
	_test_mul_self_square_overflow_boundary_is_exactly_181()
	_finish("fixed_point")


func _approx(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps


func _test_from_int_to_float_roundtrip() -> void:
	for i: int in [0, 1, -1, 5, -5, 2048, -2048, 32767, -32768]:
		var fx: int = Fx.from_int(i)
		_check(_approx(Fx.to_float(fx), float(i)), "from_int(%d) -> to_float() ≈ %d" % [i, i])


func _test_add_sub() -> void:
	var a: int = Fx.from_int(10)
	var b: int = Fx.from_int(3)
	_check(_approx(Fx.to_float(Fx.add(a, b)), 13.0), "add(10, 3) ≈ 13")
	_check(_approx(Fx.to_float(Fx.sub(a, b)), 7.0), "sub(10, 3) ≈ 7")
	_check(_approx(Fx.to_float(Fx.sub(b, a)), -7.0), "sub(3, 10) ≈ -7")


func _test_mul_basic() -> void:
	var a: int = Fx.from_int(3)
	var b: int = Fx.from_int(4)
	_check(_approx(Fx.to_float(Fx.mul(a, b)), 12.0), "mul(3, 4) ≈ 12")
	var neg: int = Fx.from_int(-3)
	_check(_approx(Fx.to_float(Fx.mul(neg, b)), -12.0), "mul(-3, 4) ≈ -12")
	_check(_approx(Fx.to_float(Fx.mul(neg, Fx.from_int(-4))), 12.0), "mul(-3, -4) ≈ 12")


func _test_mul_matches_float_for_small_values() -> void:
	var cases: Array = [[1.5, 2.5], [0.25, 4.0], [-1.5, 2.0], [100.0, 0.01]]
	for c: Array in cases:
		var a: int = Fx.from_int(0)
		var b: int = Fx.from_int(0)
		# from_int only takes whole numbers -- build fractional fixed-point values directly for this test.
		a = int(c[0] * Fx.SCALE)
		b = int(c[1] * Fx.SCALE)
		var got: float = Fx.to_float(Fx.mul(a, b))
		var want: float = c[0] * c[1]
		_check(_approx(got, want, 0.001), "mul(%s, %s) ≈ %s (got %s)" % [c[0], c[1], want, got])


func _test_div_basic() -> void:
	var a: int = Fx.from_int(12)
	var b: int = Fx.from_int(4)
	_check(_approx(Fx.to_float(Fx.div(a, b)), 3.0), "div(12, 4) ≈ 3")
	var c: int = Fx.from_int(-12)
	_check(_approx(Fx.to_float(Fx.div(c, b)), -3.0), "div(-12, 4) ≈ -3")


func _test_div_by_zero_returns_zero_and_does_not_hang() -> void:
	# Reaching this line at all is the real assertion -- an unguarded `/` here would leave the whole
	# suite hung with no further output and no exit code, per core/fixed_point.gd's own header comment.
	var result: int = Fx.div(Fx.from_int(10), 0)
	_check(result == 0, "div(10, 0) returns 0 rather than hanging the run")


## D0049. The test above only ever checked the RETURN value, not that `push_error()` actually ran --
## deleting the `push_error()` line from `Fx.div` (leaving the zero-guard's `return 0` intact) would
## still pass it, silently losing the "log loudly" half of the contract `core/fixed_point.gd`'s own
## header states. Stock GDScript has no in-process way to intercept a `push_error()` call from the same
## script that made it, so this spawns `tests/fixture_div_by_zero_probe.gd` as a real subprocess (the
## SAME pinned Godot binary this process is itself running, via `OS.get_executable_path()`) and greps
## its actual stderr for the exact message -- the only way to genuinely observe this, not assume it.
func _test_div_by_zero_logs_via_push_error() -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(),
		["--headless", "--path", project_root, "--script", "res://tests/fixture_div_by_zero_probe.gd"],
		output, true)
	_check(exit_code == 0, "the probe subprocess itself exits cleanly (got %d)" % exit_code)
	var combined: String = "\n".join(output)
	_check(combined.contains("Fx.div: division by zero"),
		"the probe's own stderr contains Fx.div's exact push_error message -- proves push_error actually ran, not just that div() returned 0 (captured output: %s)" %
		combined)


func _test_lerp() -> void:
	var a: int = Fx.from_int(0)
	var b: int = Fx.from_int(10)
	_check(Fx.lerp(a, b, 0) == a, "lerp(a, b, 0) == a exactly")
	_check(Fx.lerp(a, b, Fx.SCALE) == b, "lerp(a, b, SCALE) == b exactly")
	_check(_approx(Fx.to_float(Fx.lerp(a, b, Fx.SCALE / 2)), 5.0), "lerp(a, b, SCALE/2) ≈ 5 (midpoint)")


func _test_isqrt_known_values() -> void:
	var cases: Array = [
		[0, 0], [1, 1], [2, 1], [3, 1], [4, 2], [15, 3], [16, 4], [17, 4], [99, 9], [100, 10],
		[101, 10], [1000000, 1000], [2147483648, 46340], [2147483647, 46340], [4294967296, 65536],
		[1099511627776, 1048576], [140737488355328, 11863283], [31338827708829, 5598109],
		[68931111375447, 8302476], [39274139637470, 6266908], [28852458447017, 5371448],
		[8943934050713, 2990641], [26371227175534, 5135292], [65486305405067, 8092360],
		[118083876374774, 10866640], [126440489012192, 11244575], [78304079650220, 8848959],
		[4611686018427375559, 2147483647],
	]
	for c: Array in cases:
		var got: int = Fx.isqrt(c[0])
		_check(got == c[1], "isqrt(%d) == %d (got %d)" % [c[0], c[1], got])


func _test_length_pythagorean_triples() -> void:
	var triples: Array = [[3, 4, 5], [6, 8, 10], [5, 12, 13], [9, 12, 15]]
	for t: Array in triples:
		var dx: int = Fx.from_int(t[0])
		var dy: int = Fx.from_int(t[1])
		var got: float = Fx.to_float(Fx.length(dx, dy))
		_check(_approx(got, float(t[2]), 0.01), "length(%d, %d) ≈ %d (got %s)" % [t[0], t[1], t[2], got])
		# D0029: length_sq() is a raw i64 accumulator now, not an Fx-scaled value -- isqrt(length_sq(...))
		# must equal length(...) exactly, which is the property callers (and length() itself) actually
		# depend on, rather than to_float(length_sq(...)) meaning "the real squared distance" the way it
		# used to.
		_check(Fx.isqrt(Fx.length_sq(dx, dy)) == Fx.length(dx, dy),
			"isqrt(length_sq(%d, %d)) == length(%d, %d)" % [t[0], t[1], t[0], t[1]])


## D0029: length()/length_sq() used to silently corrupt past ~181px per axis (see
## _test_mul_self_square_overflow_boundary_is_exactly_181 below for why). These are all far beyond that,
## comfortably inside the ~2048m/32768px world-depth budget (docs/ARCHITECTURE.md §9), and match a
## from-scratch Python reference (raw i64 dx*dx+dy*dy, then math.isqrt) computed before this was trusted.
func _test_length_works_far_beyond_the_old_181px_limit() -> void:
	var cases: Array = [
		{"dx": 2000, "dy": 0, "want": 2000, "raw_sq": 17179869184000000},
		{"dx": 2000, "dy": 1500, "want": 2500, "raw_sq": 26843545600000000},
		{"dx": 20000, "dy": 15000, "want": 25000, "raw_sq": 2684354560000000000},
	]
	for c: Dictionary in cases:
		var dx: int = Fx.from_int(c["dx"])
		var dy: int = Fx.from_int(c["dy"])
		var got_raw: int = Fx.length_sq(dx, dy)
		_check(got_raw == c["raw_sq"], "length_sq(%d, %d) == %d (got %d)" %
			[c["dx"], c["dy"], c["raw_sq"], got_raw])
		var got: float = Fx.to_float(Fx.length(dx, dy))
		_check(_approx(got, float(c["want"]), 0.01), "length(%d, %d) ≈ %d (got %s)" %
			[c["dx"], c["dy"], c["want"], got])


## Executable documentation of D0029's actual claim: even the worst case -- both deltas simultaneously at
## Fx's own outer representable limit (i32 max, ~32768 real units / ~2048m, far beyond anything
## docs/ARCHITECTURE.md §9's ~256m playable depth could ever produce) -- fits in a native 64-bit int with
## room to spare. Verified against Python (2*(2^31-1)² = 9223372028264841218 < i64 max 9223372036854775807)
## before being trusted, not estimated from the exponents alone.
func _test_length_sq_no_overflow_at_fx_own_outer_limit() -> void:
	var extreme: int = 2147483647  # i32 max -- the largest magnitude any valid Fx value can ever hold
	var raw: int = Fx.length_sq(extreme, extreme)
	_check(raw == 9223372028264841218, "length_sq(I32_MAX, I32_MAX) == 9223372028264841218 (got %d)" % raw)
	_check(raw > 0, "no wraparound -- a corrupted result would show up as negative")


## Executable documentation, not just a comment: mul(dx, dx) for dx expressed in whole pixels is only
## valid up to dx == 181 before the i32 wrap silently corrupts the result -- verified against an
## independent Python computation of the exact wraparound point before this test was written. This is a
## property of Fx.mul() itself (any multiplication whose real-unit product exceeds ~32767 overflows the
## same way), not of length()/length_sq() specifically -- D0029 moved those off of mul() entirely, which
## is why this test is scoped to mul() by name now rather than to length_sq()'s old boundary.
func _test_mul_self_square_overflow_boundary_is_exactly_181() -> void:
	var safe: int = Fx.from_int(181)
	var safe_sq: float = Fx.to_float(Fx.mul(safe, safe))
	_check(_approx(safe_sq, 32761.0), "mul(181, 181) ≈ 32761 (still in range)")

	var unsafe: int = Fx.from_int(182)
	var unsafe_sq: float = Fx.to_float(Fx.mul(unsafe, unsafe))
	_check(unsafe_sq < 0.0, "mul(182, 182) silently wraps negative (%s) -- this IS the documented boundary" % unsafe_sq)
