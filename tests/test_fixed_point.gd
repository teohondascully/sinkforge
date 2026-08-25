extends "res://tests/test_base.gd"

## Golden isqrt vectors from Python's math.isqrt -- independent reference, not memory. Covers zero, one,
## perfect squares, and random values up to 2^47 (the largest magnitude length()/length_sq() can produce
## for values within their documented safe range).

func _initialize() -> void:
	_test_from_int_to_float_roundtrip()
	_test_add_sub()
	_test_mul_basic()
	_test_mul_matches_float_for_small_values()
	_test_div_basic()
	_test_div_by_zero_returns_zero_and_does_not_hang()
	_test_lerp()
	_test_isqrt_known_values()
	_test_length_pythagorean_triples()
	_test_length_sq_overflow_boundary_is_exactly_181()
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
		var got_sq: float = Fx.to_float(Fx.length_sq(dx, dy))
		_check(_approx(got_sq, float(t[2] * t[2]), 0.01),
			"length_sq(%d, %d) ≈ %d (got %s)" % [t[0], t[1], t[2] * t[2], got_sq])


## Executable documentation, not just a comment: mul(dx, dx) for dx expressed in whole pixels is only
## valid up to dx == 181 before the i32 wrap silently corrupts the result -- verified against an
## independent Python computation of the exact wraparound point before this test was written. Any
## caller squaring or measuring a delta anywhere near this magnitude needs to know the bound exists;
## a comment saying so can go stale, this test cannot pass while it's wrong.
func _test_length_sq_overflow_boundary_is_exactly_181() -> void:
	var safe: int = Fx.from_int(181)
	var safe_sq: float = Fx.to_float(Fx.mul(safe, safe))
	_check(_approx(safe_sq, 32761.0), "mul(181, 181) ≈ 32761 (still in range)")

	var unsafe: int = Fx.from_int(182)
	var unsafe_sq: float = Fx.to_float(Fx.mul(unsafe, unsafe))
	_check(unsafe_sq < 0.0, "mul(182, 182) silently wraps negative (%s) -- this IS the documented boundary" % unsafe_sq)
