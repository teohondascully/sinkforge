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

## Multiply a raw `sample_fbm()` by this before comparing it against a threshold that was tuned against
## `FastNoiseLite` (any `data/*.yaml` value ported from `legacy/`, which used
## `FastNoiseLite.TYPE_SIMPLEX_SMOOTH` throughout). Applied by callers, never inside the sampler itself:
## baking it in would break every golden-vector assertion in `tests/test_value_noise.gd` (bit-exact
## against a from-scratch Python reference of the RAW hash/interpolation math, unrelated to any
## calibration) and would narrow this file's own real distribution for a future consumer with no reason
## to want FastNoiseLite parity at all.
##
## **THE PREVIOUS VERSION OF THIS COMMENT NAMED ITS OWN DEFECT AND SHIPPED ANYWAY.** It said, correctly:
## "same standard deviation does not guarantee identical skew/kurtosis between two differently-generated
## noise fields, only that a fixed threshold clears at approximately the same rate". That word
## *approximately* was carrying one third of every shaft. The crossing rates matched to three decimals in
## the body of the distribution and to *nothing at all* in the tail, where the shelf thresholds live. A
## caveat written in prose beside a constant does not constrain the constant; the test below now measures
## the tail directly, which is what the prose should have been from the start.
##
## RE-DERIVED 2026-08-31 against `sample_fbm` (D0258, closes WG-2 and WG-3). Was 0.574, and that number
## was never a guess -- D0045 measured it honestly. It calibrated the wrong field.
##
## The old constant matched STANDARD DEVIATION between single-octave `sample()` and `FastNoiseLite`. A
## threshold does not read standard deviation, it reads the TAIL, and matching spread between two
## differently-shaped distributions does not match their tails. Measured at the real cave-carving
## frequency/x_stretch, 244,800 samples per field across 20 seeds, the calibrated single-octave field
## cleared 0.31 at 0.1167 (against FastNoiseLite's 0.1164 -- an excellent match) while clearing 0.65 at
## **0.0000** against FastNoiseLite's 0.0009. Same spread, one field with a tail and one without. The
## shelf thresholds live entirely in that tail, which is why one third of every shaft was a wall.
##
## Five octaves fixes it at the source rather than by widening a constant until caves appear:
##
##   threshold   FastNoiseLite   fbm5 @ 0.9644   1-octave @ 0.5779
##   0.31           0.1164          0.1107            0.1167
##   0.47           0.0250          0.0252            0.0213
##   0.65           0.0009          0.0015            0.0000
##   0.81           0.0000          0.0000            0.0000
##
## Derived the same way the old one was, so the two are comparable: `FastNoiseLite` SD 0.2486 over this
## file's own `sample_fbm` SD 0.2578 = 0.9644. It sits near 1.0 because a 5-octave sum of this file's
## noise is already close to `FastNoiseLite`'s shape -- the constant is small now precisely BECAUSE the
## field is right, and a calibration far from 1.0 should read as a warning that something upstream is
## being compensated for rather than fixed.
##
## READ THE 0.81 ROW BEFORE "FIXING" THE SHELF FURTHER. FastNoiseLite clears it 0.0000 of the time too.
## Legacy's shelf was never uniformly permeable: it is a GRADIENT, solid near the surface (threshold 0.81)
## and breachable at depth (0.65). A shelf that carves at the open-rock rate is not a fixed shelf, it is
## a deleted one. `tests/test_shaft_generator.gd`'s ratchet asserts the gradient, not equality.
const FASTNOISELITE_SD_CALIBRATION: float = 0.9644


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


## `FastNoiseLite`'s own fBm defaults, ported (D0258, WG-3). Legacy NEVER SET THESE -- `layered_world_gen.gd`
## configures only seed/type/frequency, so its cave field ran at Godot's defaults, and those defaults are
## a 5-octave fractal. Confirmed by printing them rather than trusting the plan:
## `FastNoiseLite.new()` reports `fractal_type = 1 (FRACTAL_FBM)`, `fractal_octaves = 5`,
## `fractal_lacunarity = 2.0`, `fractal_gain = 0.5`. Corroborated twice inside legacy itself --
## `src/core/fine_terrain.gd:102` and `scenes/fine_terrain.gd:488` both explicitly set `FRACTAL_NONE`
## *because* the default is 5-octave FBM, which is only worth writing down if you know it bites.
const FBM_OCTAVES: int = 5
const FBM_LACUNARITY: float = 2.0
const FBM_GAIN: float = 0.5


## `FastNoiseLite::CalculateFractalBounding`, evaluated for the constants above rather than left as a
## literal: `ampFractal = 1 + 0.5 + 0.25 + 0.125 + 0.0625 = 1.9375`, and the bounding is its reciprocal.
## Derived at load, not written as 0.516129, because a hand-copied reciprocal is a constant nobody can
## check against the octave count it belongs to -- change `FBM_OCTAVES` and this follows.
static func _fractal_bounding() -> float:
	var amp: float = absf(FBM_GAIN)
	var amp_fractal: float = 1.0
	for _i: int in range(1, FBM_OCTAVES):
		amp_fractal += amp
		amp *= absf(FBM_GAIN)
	return 1.0 / amp_fractal


## Five octaves of `sample()`, summed exactly the way `FastNoiseLite::GenFractalFBm` sums them.
##
## THIS IS THE PORT, AND `sample()` BELOW IS DELIBERATELY UNTOUCHED. `sample()`'s golden vectors in
## `tests/test_value_noise.gd` are bit-exact against a from-scratch Python reference of the raw
## hash-and-interpolate math; folding octaves into it would have destroyed that verification to gain
## nothing, since the fractal is a *composition* of the primitive and not a change to it. One octave is
## still a legitimate field for any future consumer that wants one.
##
## Faithful to `GenFractalFBm` in the three places it would be easy to get wrong:
##   - the seed ADVANCES PER OCTAVE (`GenNoiseSingle(seed++, ...)`). Reusing one seed would stack five
##     scaled copies of the SAME field, whose sum is that field again with a different amplitude -- it
##     would look like a working port and produce a single-octave distribution.
##   - amplitude starts at `_fractal_bounding()`, not at 1.0, which is what keeps the output in roughly
##     the same range as one octave instead of 1.9375x wider.
##   - `weighted_strength` is Godot's default 0, so FastNoiseLite's per-octave amplitude reweighting
##     (`Lerp(1, min(noise+1, 2) * 0.5, weightedStrength)`) collapses to `Lerp(1, _, 0) == 1` and is
##     omitted here rather than implemented as a no-op multiply.
static func sample_fbm(x: float, y: float, seed: int) -> float:
	var sum: float = 0.0
	var amp: float = _fractal_bounding()
	var fx: float = x
	var fy: float = y
	for i: int in FBM_OCTAVES:
		sum += sample(fx, fy, seed + i) * amp
		fx *= FBM_LACUNARITY
		fy *= FBM_LACUNARITY
		amp *= FBM_GAIN
	return sum


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
