class_name Fx
extends RefCounted

## Fixed-point arithmetic: i32, 16 fractional bits. `docs/adr/0003-fixed-point-representation.md` and
## `docs/ARCHITECTURE.md` §9 ("The world scale") have the reasoning and the constants this format was
## checked against; this file is just the arithmetic. A "fixed-point value" is a plain GDScript `int`
## holding an i32 bit pattern scaled by `SCALE` -- not an object, so values compare with `==`, store in
## arrays/dictionaries directly, and cost nothing to pass around. Static functions operate on them, the
## same shape as `core/entity_id_pool.gd`'s packed ids.
##
## GDScript's native `int` is 64-bit, wider than the i32 this format specifies, so every operation that
## could overflow i32 range is explicitly wrapped (`_wrap32`) to two's-complement 32-bit behavior rather
## than silently using the wider native range -- matching what a real i32 would do, on purpose, per the
## ADR's reasoning for choosing i32 at all.
##
## Two rounding conventions exist here and do NOT match each other: `mul` rounds toward negative
## infinity (arithmetic right shift), `div` truncates toward zero (native integer division). Both are
## deterministic; they are just different conventions, so `mul(div(a, b), b) == a` should not be assumed
## even where `a` is exactly divisible by `b` in real-number terms.

const FRACTIONAL_BITS: int = 16
const SCALE: int = 1 << FRACTIONAL_BITS  # 65536


static func _wrap32(x: int) -> int:
	var m: int = x & 0xFFFFFFFF
	if m >= 0x80000000:
		m -= 0x100000000
	return m


static func from_int(i: int) -> int:
	return _wrap32(i * SCALE)


## Debug/render only -- never on a path that affects simulation state (`core/MODULE.md`).
static func to_float(fx: int) -> float:
	return float(fx) / float(SCALE)


static func add(a: int, b: int) -> int:
	return _wrap32(a + b)


static func sub(a: int, b: int) -> int:
	return _wrap32(a - b)


static func mul(a: int, b: int) -> int:
	var product: int = a * b  # i32 * i32 always fits a native 64-bit int -- see the ADR.
	return _wrap32(product >> FRACTIONAL_BITS)


## Returns 0 and logs an error on division by zero, rather than letting GDScript's `/` raise a runtime
## script error -- a raised error inside a bare `--headless --script` run (no scene tree owner to catch
## it) does not crash the process, it leaves the run permanently idling with no further output and no
## exit code, because nothing after the error ever reaches `quit()`. Verified empirically; see the
## commit message for how. Guard every division for exactly this reason, here and anywhere else.
static func div(a: int, b: int) -> int:
	if b == 0:
		push_error("Fx.div: division by zero")
		return 0
	var numerator: int = a << FRACTIONAL_BITS
	return _wrap32(numerator / b)


## Linear interpolation. `t` is itself a fixed-point value, conventionally in [0, SCALE] for a to b, but
## not clamped -- extrapolation is a valid, well-defined use.
static func lerp(a: int, b: int, t: int) -> int:
	return add(a, mul(sub(b, a), t))


## Integer square root, floor(sqrt(x)), for non-negative x. Newton's method (Heron's method): converges
## monotonically for any positive integer, needs no floating point, and terminates deterministically.
## Verified against Python's math.isqrt for zero, one, perfect squares, and random values up to 2^47
## (the largest magnitude length_sq() can produce here) before being trusted.
static func isqrt(x: int) -> int:
	if x <= 0:
		return 0
	var guess: int = x
	var next_guess: int = (guess + x / guess) / 2
	while next_guess < guess:
		guess = next_guess
		next_guess = (guess + x / guess) / 2
	return guess


## Squared fixed-point distance between two fixed-point deltas -- exact, no sqrt, prefer this over
## length() for pure comparisons (nearest/farthest, threshold checks).
static func length_sq(dx: int, dy: int) -> int:
	return add(mul(dx, dx), mul(dy, dy))


## Fixed-point Euclidean distance. `length_sq` is a fixed-point value V/SCALE; sqrt(V/SCALE)*SCALE =
## isqrt(V * SCALE), which is what this computes rather than converting through a float at any point.
##
## LOCAL-NEIGHBORHOOD ONLY, not a world-scale distance function: squaring a fixed-point value quadratic-
## ally consumes i32's range, so `mul(dx, dx)` alone silently wraps once |dx| exceeds 181 (real units,
## i.e. px) -- 182² is already negative garbage. Combined with a nonzero dy the safe bound is tighter
## still. `tests/test_fixed_point.gd`'s `_test_length_sq_overflow_boundary_is_exactly_181` demonstrates
## this boundary directly rather than only describing it. Safe for collision checks and per-tick
## movement deltas (both comfortably under 181px); never for a distance that could span meaningful
## fractions of the ~2048m world-depth budget in `docs/ARCHITECTURE.md` §9.
static func length(dx: int, dy: int) -> int:
	return isqrt(length_sq(dx, dy) * SCALE)
