class_name ValueNoise
extends RefCounted

## Deterministic, engine-free 2D noise. Cave carving needs SOMETHING like `FastNoiseLite`'s smooth
## pseudo-random field, but `FastNoiseLite` is a Godot engine `Resource` -- forbidden in `sim/`
## (`docs/ARCHITECTURE.md` §2/§4: "engine-free"; the gap in `tools/layer_lint/no_engine_imports.py` that
## would have let it through anyway is closed as of `docs/DECISIONS_LEDGER.md` D0023).
##
## Value noise, not simplex: hash each integer lattice point to a pseudo-random corner value, bilinear-
## interpolate between the four corners surrounding a sample point, easing with the smoothstep polynomial
## (`3t^2 - 2t^3`) rather than linearly so the field has no visible grid creases. No `sin`/`cos`/`pow`
## anywhere (`docs/ARCHITECTURE.md` §4: forbidden on state-affecting paths, and generation is
## state-affecting -- it writes the tile grid).
##
## Output range is approximately [-1, 1] -- this file's own real property, but NOT, as an earlier
## version of this comment claimed, a match for `FastNoiseLite.get_noise_2d`'s actual distribution.
## Corrected 2026-08-26 (D0045), after an external audit measured them directly and this session
## independently reproduced the result: `FastNoiseLite.TYPE_SIMPLEX_SMOOTH` at legacy's own tuned
## frequency/seed range does NOT span anywhere near [-1, 1] in practice (measured range roughly
## [-0.83, 0.78] across 20 seeds), and its standard deviation (~0.25) is under 60% of this file's own
## (~0.43, pooled 244,800-sample measurement). Matching RANGE endpoints was never the same claim as
## matching DISTRIBUTION, and only the distribution determines what fraction of samples clear a fixed
## threshold -- the thing `data/strata/*.yaml`'s cave thresholds (`threshold_top: 0.47`, ported directly
## from `legacy/src/core/layered_world_gen.gd`'s `FastNoiseLite`-tuned constants) actually depend on.
## `FASTNOISELITE_SD_CALIBRATION` below is the fix, applied by callers, not baked into `sample()` itself
## (see that constant's own comment for why).
##
## Hash: integer inputs masked to 16 bits, weighted-summed, then multiply-xor-shift-mixed once. Not
## SplitMix64 (that stream is stateful and sequential; this needs a pure function of (x, y, seed) so the
## same cell always hashes the same way regardless of scan order). Verified against a from-scratch Python
## reference before this file was trusted -- see the commit message for how.

## Multiply a raw `sample()` by this before comparing it against a threshold that was tuned against
## `FastNoiseLite` (any `data/*.yaml` value ported from `legacy/`, which used
## `FastNoiseLite.TYPE_SIMPLEX_SMOOTH` throughout) -- measured directly (D0045), not derived: pooled
## 244,800 samples across 20 seeds at the real cave-carving frequency/x_stretch gave `FastNoiseLite`
## SD ~0.2487, this file's own raw SD ~0.4336; 0.2487/0.4336 = 0.574. Deliberately NOT applied inside
## `sample()` itself -- that would break every golden-vector assertion in `tests/test_value_noise.gd`
## (bit-exact against a from-scratch Python reference of the RAW hash/interpolation math, unrelated to
## this calibration), and would silently narrow this file's own real, wider distribution for any FUTURE
## consumer that has no reason to want FastNoiseLite parity at all. A ratio, not a shape match: same
## standard deviation does not guarantee identical skew/kurtosis between two differently-generated noise
## fields, only that a fixed threshold clears at approximately the same rate, which is what a ported
## threshold constant actually depends on. `tests/test_value_noise.gd`'s distribution test re-measures
## this against real `FastNoiseLite` output so a hash or interpolation change that drifts it is caught.
const FASTNOISELITE_SD_CALIBRATION: float = 0.574


## The seed, avalanched into 32 bits. **This exists because the previous form TRUNCATED it** (D0254).
##
## `_lattice_hash` used to fold the seed in as `(seed & 0xFFFF) * 2246822519`, and a 16-bit mask does not
## mean "cheaply mixed", it means **only 65,536 distinct noise fields exist in this entire game**. Any two
## seeds congruent mod 65,536 produced a bit-identical world: `sample(3.7, 11.3, 1337)`,
## `sample(3.7, 11.3, 1337 + 2^16)` and `sample(3.7, 11.3, 1337 + 2^20)` all returned exactly
## `-0.0519986834`. `core/split_rng.gd` hands out full 64-bit values and 48 of them were being discarded
## before they reached a single cell.
##
## The masks on `x` and `y` are NOT the same mistake and stay: a terrain coordinate is genuinely bounded
## (this world is 48 x 1024 cells), so 16 bits is headroom rather than truncation. A seed is not bounded.
##
## Why the fold is shaped like this. `(s & 0x7FFFFFFF) * 2246822519` is the widest multiply that provably
## fits: 2^31 x 2246822519 = 4.83e18, against a signed-64 ceiling of 9.22e18. Masking to 32 bits instead
## would give 9.65e18 and silently wrap -- still deterministic, but deterministic nonsense, and the kind
## that shows up as a distribution defect nobody can trace. `tools/.../ref.py`'s own assert states that
## bound rather than assuming it. The `seed >> 32` fold in the first line is what carries the high half
## in at all, and it is a no-op for the small seeds this game actually uses, which is why the whole
## defect stayed invisible: every seed anyone typed was already under 2^16 or looked fine next to one.
static func _seed32(seed: int) -> int:
	var s: int = (seed ^ (seed >> 32)) & 0xFFFFFFFF
	s = (s ^ (s >> 16)) & 0xFFFFFFFF
	s = ((s & 0x7FFFFFFF) * 2246822519) & 0xFFFFFFFF
	s = (s ^ (s >> 15)) & 0xFFFFFFFF
	return s


static func _lattice_hash(x: int, y: int, seed: int) -> int:
	var h: int = ((x & 0xFFFF) * 374761393) + ((y & 0xFFFF) * 668265263) + _seed32(seed)
	h = h & 0xFFFFFFFF
	h = (h ^ (h >> 15)) & 0xFFFFFFFF
	h = (h * 0x2545F491) & 0xFFFFFFFF
	h = (h ^ (h >> 13)) & 0xFFFFFFFF
	return h


static func _corner_value(x: int, y: int, seed: int) -> float:
	var h: int = _lattice_hash(x, y, seed)
	return (float(h) / float(0xFFFFFFFF)) * 2.0 - 1.0


static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## Sample the field at a continuous (x, y). Two lattice points passed the same (x, y, seed) always hash
## the same regardless of how many samples were taken before -- no internal state, unlike `SplitRng`.
static func sample(x: float, y: float, seed: int) -> float:
	var x0: int = int(floor(x))
	var y0: int = int(floor(y))
	var tx: float = x - float(x0)
	var ty: float = y - float(y0)
	var sx: float = _smooth(tx)
	var sy: float = _smooth(ty)
	var v00: float = _corner_value(x0, y0, seed)
	var v10: float = _corner_value(x0 + 1, y0, seed)
	var v01: float = _corner_value(x0, y0 + 1, seed)
	var v11: float = _corner_value(x0 + 1, y0 + 1, seed)
	var top: float = lerpf(v00, v10, sx)
	var bottom: float = lerpf(v01, v11, sx)
	return lerpf(top, bottom, sy)
