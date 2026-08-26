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
