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
## Verified against Python's math.isqrt for zero, one, perfect squares, and random values up to 2^62
## (D0029: length_sq() can produce values in this range for the largest valid Fx deltas -- was 2^47
## before that fix widened length_sq()'s own range) before being trusted.
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
## length() for pure comparisons (nearest/farthest, threshold checks). Ordering-preserving like any
## squared distance, but NOT an `Fx` value in the usual sense (do not call `to_float()` on it expecting
## a real squared distance -- pass it to `isqrt()`, which is the only thing that reads it).
##
## D0029 supersedes D0011's scope decision here. The prior version computed `add(mul(dx,dx), mul(dy,dy))`
## -- routing each squared term through `mul()`'s `_wrap32(product >> FRACTIONAL_BITS)` reduces it to a
## valid i32 `Fx` value before summing, and an i32 `Fx` value can only hold a squared real-unit magnitude
## up to ~32767, i.e. a per-axis delta up to ~181px before `mul(dx, dx)` alone wraps negative. That bound
## was real and reachable: `sim/body`'s grapple, rope, and camera-relative queries have no reason to stay
## under 11m. Squaring is exactly the operation that needs the extra headroom `mul()`'s i32 reduction
## throws away, so this accumulates the raw i64 products directly -- `dx`/`dy` are native GDScript ints
## already (never wrapped through `mul()`), and GDScript's 64-bit `int` holds `dx*dx + dy*dy` for ANY
## pair of valid `Fx` values (each bounded to i32 magnitude, ±2^31) with room to spare: the worst case,
## both deltas simultaneously at `Fx`'s own outer limit, is `2*(2^31-1)² ≈ 9.223e18`, still under i64's
## `9223372036854775807` -- verified exactly, not estimated, before this was trusted (see the commit
## message). There is no longer a reachable overflow boundary within the range any valid `Fx` value can
## occupy; the old 181px figure belonged to `mul()`'s general behavior, not to this function specifically
## -- `tests/test_fixed_point.gd` keeps that test, retitled to say so.
static func length_sq(dx: int, dy: int) -> int:
	return dx * dx + dy * dy


## Fixed-point Euclidean distance. `isqrt(dx*dx + dy*dy)` is exactly the `Fx` representation of the real
## distance with no separate rescale needed: `Fx(D) = D*SCALE = sqrt(dx_real²+dy_real²)*SCALE =
## sqrt((dx_real*SCALE)² + (dy_real*SCALE)²) = sqrt(dx² + dy²)`, since `dx`/`dy` already carry one factor
## of `SCALE` each. Safe for any pair of valid `Fx` deltas -- see `length_sq()`'s comment for the exact
## bound checked.
static func length(dx: int, dy: int) -> int:
	return isqrt(length_sq(dx, dy))


## --- Vectors (A' step 5, PRE-2; D0358). A fixed-point vector is a pair of `Fx` ints, returned as a
## `Vector2i` because its components ARE i32: the container is the format, so nothing can be smuggled in
## that the arithmetic below would not have wrapped. Never do arithmetic on the Vector2i itself -- Godot's
## Vector2i operators wrap at i32 silently, with no `_wrap32` discipline, and its `*`/`/` are not fixed
## point. Read the components out and use the functions here.
##
## Both divisions round TOWARD LESS ENERGY. `normalize` and `limit_length` divide by the CEILING square
## root of the squared length (`_isqrt_ceil`: never below the real length) and truncate each component
## toward zero, so a unit vector's length is never more than 1.0 and a clamped vector is never longer than
## its cap. A constraint built on these can only lose energy to rounding, never gain it -- the property
## that makes a position-projection solver unconditionally stable (`sim/body/grapple.gd`). `isqrt`'s own
## FLOOR would let the quotient overshoot by up to one unit, which is the wrong direction for a solver.
##
## The one i32 value whose square cannot be summed twice in i64 is the minimum itself (2 * 2^62 wraps), so
## every entry point clamps a component of -2^31 to -(2^31 - 1): one unit of error at a magnitude no
## world coordinate reaches, never a wrapped length reading as zero.
const _I32_MIN_SAFE: int = -2147483647


static func _clamp_min(x: int) -> int:
	return maxi(x, _I32_MIN_SAFE)


static func _isqrt_ceil(x: int) -> int:
	var r: int = isqrt(x)
	return r + 1 if r * r < x else r


## The unit vector along (dx, dy), components in Fx (SCALE == 1.0). The zero vector has no direction and
## returns zero; the caller chooses its default, as legacy's `Vector2.RIGHT` fallback did.
static func normalize(dx: int, dy: int) -> Vector2i:
	dx = _clamp_min(dx)
	dy = _clamp_min(dy)
	var len: int = _isqrt_ceil(length_sq(dx, dy))
	if len == 0:
		return Vector2i.ZERO
	return Vector2i(_wrap32((dx * SCALE) / len), _wrap32((dy * SCALE) / len))


## a . b, one Fx value: the exact i64 sum of products shifted once, so it rounds toward negative infinity
## like `mul`. Defined where the product sum fits i64 -- every use here dots a unit vector (|n| <= SCALE)
## against a velocity (|v| < 2^31), a product under 2^47; two arbitrary i32 vectors can wrap and no caller
## may pass them.
static func dot(ax: int, ay: int, bx: int, by: int) -> int:
	return _wrap32((ax * bx + ay * by) >> FRACTIONAL_BITS)


## (dx, dy) shortened to at most `max_len` (an Fx length), direction kept. A non-positive cap returns zero.
## `dx * max_len` is at most 2^62 in i64 and the truncating divide can only shrink, so the result's
## length is never above the cap and never below it by more than a unit per component.
static func limit_length(dx: int, dy: int, max_len: int) -> Vector2i:
	if max_len <= 0:
		return Vector2i.ZERO
	dx = _clamp_min(dx)
	dy = _clamp_min(dy)
	var sq: int = length_sq(dx, dy)
	if sq <= max_len * max_len:
		return Vector2i(dx, dy)
	var len: int = _isqrt_ceil(sq)
	return Vector2i(_wrap32((dx * max_len) / len), _wrap32((dy * max_len) / len))
