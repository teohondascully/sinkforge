class_name RockTone
extends RefCounted

## THE MOLDED-ROCK SHADING, ported from `legacy/scenes/fine_terrain.gd` — the noise fields at `:505-534`
## and the paint terms inside `_paint_fine` at `:993-1085`. `docs/PORT_ORDER.md` V2;
## `docs/DECISIONS_LEDGER.md` D0327.
##
## **WHY THIS IS NOT A PORT OF THAT FILE'S 1,402 LINES, and the finding is a measurement.** Legacy
## renders rock on a FINE grid it subdivides out of its 32px coarse cell: `SUBDIV 4`, so `FINE = 8px`.
## Legacy's cell is one metre, so its fine cell is **1/4 metre**. This build's terrain cell is 4px against
## 16px/metre — also **1/4 metre**.
##
##     legacy    32 px = 1 m,  SUBDIV 4  ->  fine cell  8 px = 1/4 m
##     here      16 px = 1 m,               terrain cell 4 px = 1/4 m
##
## **This build's terrain cell IS legacy's fine cell.** Porting the subdivision would have subdivided a
## grid already at legacy's finest resolution — 1/16-metre cells, four times finer than legacy ever
## rendered, at sixteen times the cost — which is the WG-4 regime trap (D0305) in its sharpest form. So
## the ~435 lines of subdivision bookkeeping (`rebake`, `_fine_rect`, `bake_pending`, the byte buffer, the
## fine texture, the progressive fill) do not come over at all. The shading does.
##
## **AND EVERY FREQUENCY CONSTANT BELOW PORTS UNCHANGED, which is the payoff of that finding.** Legacy
## samples these fields at FINE-cell indices `(fx, fy)`; this file samples at terrain-cell indices
## `(col, row)`. Same physical granularity, so a feature legacy describes as "~11 fine cells" is ~11 cells
## here and 2.75 metres in both. Nothing is rescaled, which means nothing can be rescaled WRONGLY —
## `tests/test_rock_tone.gd` asserts the feature sizes in metres against legacy's own comments.
##
## WHAT IS DELIBERATELY NOT HERE. Every term in legacy's `_paint_fine` that needs to look at a NEIGHBOUR:
## the fine AO (`_air_weight`, 8 neighbours), the rim light (`_top_air_distance`), the sky-form gradient
## (`_sky_form`), the moss (needs an exposed top edge), the hanging tufts, and the soil profile (needs the
## column's surface row). They are all reachable through `Observation.material_at` and are a follow-up;
## keeping them out means every term in this file is a pure function of `(col, row, grammar)` and can be
## asserted without posing a world. The floor and the combination are written so they slot in unchanged.

## Legacy `:48`. Low-frequency tonal drift so a broad rock face is not one flat colour.
const TONAL_FREQ: float = 0.085

## Legacy `:73-76`. Bedding grain: two octaves, the second crisper. `XSTRETCH` below 1 stretches features
## horizontally, which is what makes bedded rock read as bedded.
const GRAIN_FREQ: float = 0.09        ## a feature spanning ~11 cells
const GRAIN_FREQ2: float = 0.115      ## the finer octave, ~9 cells, still a shape and not a dot
const GRAIN_XSTRETCH: float = 0.38
const GRAIN_AMP: float = 0.10

## Legacy `:108-116`. Broad patches, embedded stone blobs, hairline crack seams.
const PATCH_FREQ: float = 0.045       ## ~22 cells, the largest single variation term in the bake
const PATCH_AMP: float = 0.22
const STONE_FREQ: float = 0.10        ## embedded darker-stone blobs, ~10 cells across
const STONE_THRESH: float = 0.34
const STONE_RAMP: float = 1.6
const STONE_DARKEN: float = 0.17
const CRACK_FREQ: float = 0.09
const CRACK_BAND: float = 0.075       ## |noise| under this is seam; wider is a line, not a dotted one
const CRACK_DARKEN: float = 0.15

## Legacy `:202-206`. Rock is not one blue-grey: a very-low-frequency two-noise field picks a hue pole
## per broad region so whole faces share a tint and the frame stops reading as monochrome.
const HUE_FREQ: float = 0.028         ## enormous regions (~36 cells), so a whole face shares a tint
const HUE_AMP: float = 0.12
const HUE_TEAL := Color(0.16, 0.30, 0.34)
const HUE_BROWN := Color(0.30, 0.24, 0.17)
const HUE_VIOLET := Color(0.24, 0.18, 0.30)

## THE TEXTURE GRAMMAR — legacy `:120-177`, and the reason a port of the amplitudes alone would not have
## worked. Legacy states it: until grammars existed "every solid material in the world ran the identical
## noise at a different hue", so two materials "read as square variation before material" as a structural
## fact rather than as a tuning choice. **No amplitude fixes a layer that cannot tell which material it
## is painting.**
##
## The two ends are deliberately opposite in BOTH cues a viewer has — how loud the surface is, and which
## way it runs. Soil is granular, clumpy and directionless, because loose ground does not fracture along
## planes. Stone is a quiet broad plane cut by steeply-dipping seams: quieter AND directional, and its
## direction is the opposite of bedding's. A material told apart on only one of those is told apart by a
## knob rather than by a language.
##
## `data/materials/*.yaml` has carried a `grammar:` field since Slice 0 and **nothing has ever read it**
## — the same shape as the depth chip before D0271: the data was entirely present and the consumer was
## missing. `MaterialLook.grammar_of` is that consumer.
enum { GRAM_CLASTIC = 0, GRAM_BEDDED = 1, GRAM_MASSIVE = 2 }
const GRAM_GRAIN: Array[float] = [1.60, 0.85, 0.30]   ## soil granular, stone restrained
const GRAM_XSTR: Array[float] = [1.00, 0.35, 1.60]    ## <1 stretches features along the horizontal
const GRAM_CLUMP: Array[float] = [1.45, 0.60, 0.25]   ## pebbles in soil, not in stone
const GRAM_SEAM: Array[float] = [0.15, 1.20, 0.70]    ## fracture seam strength
const GRAM_PATCH: Array[float] = [1.35, 1.00, 0.50]   ## broad mass is part of a material's language

## SEAM DIRECTION, WHICH IS EASY TO WRITE BACKWARDS AND WAS. Legacy's own note: in
## `get_noise_2d(x * a, y * b)` a large multiplier makes the field vary FAST on that axis, so features are
## NARROW on it. A horizontally elongated grain (bedding) therefore needs a SMALL x and a LARGE y.
##
## Legacy had these inverted for their entire first life, under a comment asserting the opposite of what
## the arithmetic did: `[3.00, 0.35]` for Bedded gave features 3.7 cells wide by 31.7 tall — vertical
## laminae in the material named for flat ones — and Massive carried the mirror error. **No number its
## texture layer printed could see it**, because the one cue that could have registered a direction error
## was disqualified by its own null rig. The check legacy prescribes is arithmetic, not a picture:
## compute `1 / (freq * multiplier)` per grammar and read the answer against the sentence.
## `tests/test_rock_tone.gd` does exactly that, in metres.
const GRAM_SEAM_X: Array[float] = [1.00, 0.35, 3.40]  ## bedded runs flat (small x), massive runs steep
const GRAM_SEAM_Y: Array[float] = [1.00, 3.00, 0.40]
const GRAM_SEAM_W: Array[float] = [1.00, 1.35, 1.70]  ## a plane's fracture is a line, not a fleck

## THE FLOOR UNDER THE MULTIPLIER, legacy `:1082`. Several independent darkeners stack — the grain, an
## embedded stone, a crack, and (when the neighbour terms arrive) the carved-edge AO and the form sink —
## and unfloored they could drive one cell to black, which prints as a PUNCTURE in an otherwise continuous
## face. Legacy's own words: "the same wrong note as a blown highlight, at the other end." Rock in shadow
## is dark rock, never a hole.
const VALUE_FLOOR: float = 0.22

var _drift: FastNoiseLite
var _grain: FastNoiseLite
var _grain2: FastNoiseLite
var _patch: FastNoiseLite
var _stone: FastNoiseLite
var _crack: FastNoiseLite
var _huex: FastNoiseLite
var _huey: FastNoiseLite


## `FastNoiseLite` IS LEGAL HERE and banned three metres away, which is worth stating so nobody 'fixes'
## it. `tools/layer_lint/no_engine_imports.py` bans it by name in `core/` and `sim/` because anything on
## the deterministic path must be reproducible across processes and platforms. This is `view/`: the fields
## below are cosmetic, seeded from `Observation.world_seed`, and touch no sim state. Legacy's migration
## row says the same — the 1,402-line view-side namesake "keeps its noise and lands in `view/` legally",
## while its 114-line SIM-side namesake is the one that must swap to `core/SplitRng`.
func _init(world_seed: int) -> void:
	# Octave budgets are legacy's, and the reason is at its `_field`: FastNoiseLite defaults to 5-octave
	# FBM and each octave doubles the frequency, so a field whose base resolves on this grid still ships
	# three or four octaves that do NOT, and those are white noise mixed straight into the result. Legacy
	# names that default as "the systemic cause of 'the rock reads as static'".
	_drift = _field(world_seed, 0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, TONAL_FREQ, 3)
	_grain = _field(world_seed, 0x27d4eb2f, FastNoiseLite.TYPE_SIMPLEX, GRAIN_FREQ)
	_grain2 = _field(world_seed, 0x165667b1, FastNoiseLite.TYPE_VALUE, GRAIN_FREQ2)
	_patch = _field(world_seed, 0x2545f491, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, PATCH_FREQ, 3)
	# Both of the next two are THRESHOLDED downstream, so neither may carry an octave tail: doubling the
	# frequency once puts detail at the grid's own scale, and a threshold on that prints the blob as
	# scattered squares and the crack as dots. One octave each — the shape is the point, not its edge.
	_stone = _field(world_seed, 0x1b873593, FastNoiseLite.TYPE_SIMPLEX, STONE_FREQ)
	_crack = _field(world_seed, 0x85ebca77, FastNoiseLite.TYPE_SIMPLEX, CRACK_FREQ)
	# Two independent low-frequency fields, so a region's hue pole is picked per broad region rather than
	# every region landing on the same one.
	_huex = _field(world_seed, 0xc2b2ae35, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, HUE_FREQ)
	_huey = _field(world_seed, 0x27d4eb2f, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, HUE_FREQ)


## Legacy `_field` `:494-503`, verbatim including its octave argument.
static func _field(world_seed: int, salt: int, type: FastNoiseLite.NoiseType, freq: float,
		octaves: int = 1) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = world_seed ^ salt
	n.noise_type = type
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_NONE if octaves <= 1 else FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = maxi(octaves, 1)
	return n


## The molded colour for one terrain cell. `base` is the material's own colour with the depth darkening,
## zone tint and bedding already on it (`MaterialLook.matrix_color`); this adds the terms that make it
## read as rock rather than as a filled square.
##
## THE COMBINATION IS LEGACY'S, `:1082-1084`: the grain rides the colour MULTIPLICATIVELY so it scales
## with the material's own value and cannot bleach dark rock, while the drift and patch are ADDITIVE so a
## broad face still separates from its neighbour where the multiplicative term has almost nothing left to
## scale. Getting that backwards makes deep rock either uniformly black or uniformly grey.
func shade(base: Color, col: int, row: int, gram: int) -> Color:
	var g: int = clampi(gram, 0, GRAM_MASSIVE)
	var x: float = float(col)
	var y: float = float(row)

	# Broad tonal patches plus the low-frequency drift, both additive. Legacy scales the patch by the
	# material's own GRAM_PATCH: a material's broad mass is part of its language, not the world's — soil
	# is mottled by compaction at large scale, a stone plane is quiet at large scale and speaks in seams.
	var drift: float = _drift.get_noise_2d(x * 0.35 + 500.0, y * 0.35) * 0.07
	drift += _patch.get_noise_2d(x, y) * PATCH_AMP * GRAM_PATCH[g]

	# Grain: two octaves, stretched along x by the grammar so bedding runs flat.
	var gx: float = x * GRAIN_XSTRETCH * GRAM_XSTR[g]
	var gamp: float = GRAIN_AMP * GRAM_GRAIN[g]
	var grain: float = _grain.get_noise_2d(gx, y) * gamp + _grain2.get_noise_2d(gx, y) * (gamp * 0.35)

	# Embedded stones: a mid-frequency mask past a threshold darkens a whole cluster into an inclusion.
	var stone: float = _stone.get_noise_2d(x, y)
	if stone > STONE_THRESH:
		grain -= STONE_DARKEN * GRAM_CLUMP[g] * smoothstep(0.0, 1.0, (stone - STONE_THRESH) * STONE_RAMP)

	# Crack seams: a ridged near-zero band of a second field cuts a thin dark fracture. Soil gets the
	# clumps and almost no seams; stone gets the seams and almost no clumps.
	var crackv: float = absf(_crack.get_noise_2d(x * GRAM_SEAM_X[g], y * GRAM_SEAM_Y[g]))
	var band: float = CRACK_BAND * GRAM_SEAM_W[g]
	if crackv < band:
		grain -= CRACK_DARKEN * GRAM_SEAM[g] * smoothstep(0.0, 1.0, 1.0 - crackv / band)

	# Region hue: pull the body a hair toward a region-picked pole so a broad face carries its own tint.
	var col_out: Color = base
	var hx: float = _huex.get_noise_2d(x, y)
	var hy: float = _huey.get_noise_2d(x, y)
	var pole: Color = HUE_TEAL if hx < -0.15 else (HUE_BROWN if hx > 0.20 else HUE_VIOLET)
	col_out = col_out.lerp(pole, HUE_AMP * clampf(0.5 + 0.5 * hy, 0.15, 1.0))

	# `1.0` is where the neighbour terms will land: legacy's `shade` (carved-edge AO) and `_sky_form`.
	# Written as the sum rather than folded away so adding them is one edit and the floor still covers it.
	var vmul: float = maxf(VALUE_FLOOR, 1.0 + grain)
	# CLAMPED, exactly where legacy clamps. Legacy's `_paint_fine` writes bytes -- `clampf(out.r, 0, 1)`
	# at `:1105` -- so the clamp is structural there rather than a choice, and leaving it out here let the
	# additive drift carry a channel NEGATIVE on dark rock: 3,013 of 36,000 sampled cells, worst luma
	# -0.14, found by this file's own test rather than by looking at it.
	return Color(
		clampf(col_out.r * vmul + drift, 0.0, 1.0),
		clampf(col_out.g * vmul + drift, 0.0, 1.0),
		clampf(col_out.b * vmul + drift, 0.0, 1.0),
		base.a)


## The seam feature size this grammar produces, in CELLS, on each axis — `1 / (freq * multiplier)`.
##
## Public because it is the check legacy prescribes for the direction error it shipped for a whole
## lifetime, and a picture cannot make it: a test computes this and reads the answer against the sentence
## "bedded runs flat". Returned as (width, height) so "flat" is `x > y` and needs no further arithmetic.
static func seam_feature_cells(gram: int) -> Vector2:
	var g: int = clampi(gram, 0, GRAM_MASSIVE)
	return Vector2(1.0 / (CRACK_FREQ * GRAM_SEAM_X[g]), 1.0 / (CRACK_FREQ * GRAM_SEAM_Y[g]))
