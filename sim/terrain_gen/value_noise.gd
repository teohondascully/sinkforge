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
## Output range is approximately [-1, 1], matching what `FastNoiseLite.get_noise_2d` returns -- load-
## bearing, because `data/strata/*.yaml`'s cave thresholds (e.g. `threshold_top: 0.47`) are numeric
## literals ported directly from `legacy/src/core/layered_world_gen.gd`'s `FastNoiseLite`-calibrated
## constants. A [0, 1]-ranged noise would silently change what those thresholds mean.
##
## Hash: integer inputs masked to 16 bits, weighted-summed, then multiply-xor-shift-mixed once. Not
## SplitMix64 (that stream is stateful and sequential; this needs a pure function of (x, y, seed) so the
## same cell always hashes the same way regardless of scan order). Verified against a from-scratch Python
## reference before this file was trusted -- see the commit message for how.


static func _lattice_hash(x: int, y: int, seed: int) -> int:
	var h: int = ((x & 0xFFFF) * 374761393) + ((y & 0xFFFF) * 668265263) + ((seed & 0xFFFF) * 2246822519)
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
