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
const STONE_THRESH: float = 0.42       ## was 0.34: fewer inclusions (D0398, the director's T017 ruling)
const STONE_RAMP: float = 1.6
const STONE_DARKEN: float = 0.11       ## was 0.17: softer ones
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
const GRAM_GRAIN: Array[float] = [1.60, 0.60, 0.22]   ## soil granular, stone restrained (stone quieter since D0398: the static was grain)
const GRAM_XSTR: Array[float] = [1.00, 0.35, 1.60]    ## <1 stretches features along the horizontal
const GRAM_CLUMP: Array[float] = [1.45, 0.60, 0.25]   ## pebbles in soil, not in stone
const GRAM_SEAM: Array[float] = [0.15, 1.00, 0.70]    ## fracture seam strength
const GRAM_PATCH: Array[float] = [1.35, 0.80, 0.60]   ## broad mass is part of a material's language; massive is plates (D0398)

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

## THE LAMINAE (D0398, the director's T017 ruling: "more bedding, fewer inclusions"). Legacy's bedding is a
## hue drift (`BeddingTone._strata`); a bedded rock also has PARTING PLANES -- thin dark lines where one
## lamina ends and the next begins -- and those are what make a face read as layered stone at a glance
## rather than as a tinted field. One line about a cell thick every `LAM_PERIOD_M`, on the SAME warped
## bedding coordinate `_strata` uses so the lines dip and rise with the hue bands, fading in and out under
## a slow field so they are partings and not a ruled page. Bedded rock only; the massive grammar's
## identity is plates and steep fractures, the clastic's is aggregate. Scaled by `GRAM_LAMINA`.
const LAM_PERIOD_M: float = 1.0
const LAM_BAND: float = 0.24          ## the fraction of a period the parting darkens: ~1 cell of 4
const LAM_DARKEN: float = 0.42        ## multiplicative, on the parting row
const LAM_ADD: float = 0.045          ## and a little absolute, so the line survives the veil's multiply
const LAM_FADE_FREQ: float = 0.03     ## the field that fades partings in and out, ~33 cells
const LAM_FADE_FLOOR: float = 0.30    ## a parting is never fainter than this share of itself...
const GRAM_LAMINA: Array[float] = [0.0, 1.0, 0.0]

## THE FLOOR UNDER THE MULTIPLIER, legacy `:1082`. Several independent darkeners stack — the grain, an
## embedded stone, a crack, and (when the neighbour terms arrive) the carved-edge AO and the form sink —
## and unfloored they could drive one cell to black, which prints as a PUNCTURE in an otherwise continuous
## face. Legacy's own words: "the same wrong note as a blown highlight, at the other end." Rock in shadow
## is dark rock, never a hole.
const VALUE_FLOOR: float = 0.22

## THE CARVED-EDGE TERMS, legacy `:1016-1078`. All four need to look at a NEIGHBOUR, which is why they
## arrive behind an optional probe rather than in the pure path.
##
## `SHADOW_TEAL` (`:385`): carved and AO-shadowed rock is pulled toward a cold teal-blue, so shadows read
## as the reference's blue-grey cold rock rather than as a warm brown murk.
const SHADOW_TEAL := Color(0.13, 0.20, 0.27)
const AO_PER_NEIGHBOUR: float = 0.125   ## each open neighbour darkens the fill toward that edge
const AO_TEAL_GATE: float = 0.5         ## above this much open air the cell also tints cold
const AO_TEAL_AMOUNT: float = 0.20
## Legacy `:220`. The lit lip fades over two rows rather than lighting exactly one: the molding makes a
## boundary ragged, so a BINARY rim lights alternating cells along a flat floor and a lip that should read
## as a lit edge prints as a DOTTED LINE.
const RIM_DEPTH: int = 2
const RIM_LIGHT: float = 0.10
const RIM_WARM: float = 0.03
## Legacy `:324-326`. The sky-ward gradient: a cell with open air above catches the light, one hanging
## under an overhang sinks into shadow. This is what gives a face volume rather than an even tone.
const FORM_REACH: int = 6
const FORM_LIFT: float = 0.22
const FORM_SINK: float = 0.13

var _drift: FastNoiseLite
var _grain: FastNoiseLite
var _grain2: FastNoiseLite
var _patch: FastNoiseLite
var _stone: FastNoiseLite
var _crack: FastNoiseLite
var _huex: FastNoiseLite
var _huey: FastNoiseLite
var _lam_fade: FastNoiseLite
## The surface-aware terms (soil profile, moss, tufts), seeded with the same world seed (6o, D0378).
var surface: SurfaceTone


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
	_drift = field(world_seed, 0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, TONAL_FREQ, 3)
	_grain = field(world_seed, 0x27d4eb2f, FastNoiseLite.TYPE_SIMPLEX, GRAIN_FREQ)
	_grain2 = field(world_seed, 0x165667b1, FastNoiseLite.TYPE_VALUE, GRAIN_FREQ2)
	_patch = field(world_seed, 0x2545f491, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, PATCH_FREQ, 3)
	# Both of the next two are THRESHOLDED downstream, so neither may carry an octave tail: doubling the
	# frequency once puts detail at the grid's own scale, and a threshold on that prints the blob as
	# scattered squares and the crack as dots. One octave each — the shape is the point, not its edge.
	_stone = field(world_seed, 0x1b873593, FastNoiseLite.TYPE_SIMPLEX, STONE_FREQ)
	_crack = field(world_seed, 0x85ebca77, FastNoiseLite.TYPE_SIMPLEX, CRACK_FREQ)
	# Two independent low-frequency fields, so a region's hue pole is picked per broad region rather than
	# every region landing on the same one.
	_huex = field(world_seed, 0xc2b2ae35, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, HUE_FREQ)
	_huey = field(world_seed, 0x27d4eb2f, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, HUE_FREQ)
	_lam_fade = field(world_seed, 0x9e3779b9, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, LAM_FADE_FREQ, 2)
	surface = SurfaceTone.new(world_seed)


## Legacy `_field` `:494-503`, verbatim including its octave argument.
static func field(world_seed: int, salt: int, type: FastNoiseLite.NoiseType, freq: float,
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
func shade(base: Color, col: int, row: int, gram: int, solid_at: Callable = Callable()) -> Color:
	var g: int = clampi(gram, 0, GRAM_MASSIVE)
	var x: float = float(col)
	var y: float = float(row)

	# Broad tonal patches plus the low-frequency drift, both additive. Legacy scales the patch by the
	# material's own GRAM_PATCH: a material's broad mass is part of its language, not the world's — soil
	# is mottled by compaction at large scale, a stone plane is quiet at large scale and speaks in seams.
	var drift: float = _drift.get_noise_2d(x * 0.35 + 500.0, y * 0.35) * 0.07
	drift += _patch.get_noise_2d(x, y) * PATCH_AMP * GRAM_PATCH[g]

	var grain: float = _micro_texture(x, y, g)

	# Region hue: pull the body a hair toward a region-picked pole so a broad face carries its own tint.
	var col_out: Color = base
	var hx: float = _huex.get_noise_2d(x, y)
	var hy: float = _huey.get_noise_2d(x, y)
	var pole: Color = HUE_TEAL if hx < -0.15 else (HUE_BROWN if hx > 0.20 else HUE_VIOLET)
	col_out = col_out.lerp(pole, HUE_AMP * clampf(0.5 + 0.5 * hy, 0.15, 1.0))

	# THE CARVED-EDGE TERMS. Absent when no probe is supplied, which is the pure-material path and is what
	# a fixture without a world gets; every one of them is legacy's, at the addresses in their constants.
	var ao: float = 0.0
	var form: float = 0.0
	var rim: float = 0.0
	var rim_warm: float = 0.0
	if solid_at.is_valid():
		ao = _air_weight(solid_at, col, row)
		form = _sky_form(solid_at, col, row)
		if ao > AO_TEAL_GATE:
			col_out = col_out.lerp(SHADOW_TEAL, clampf(ao / 6.0, 0.0, 1.0) * AO_TEAL_AMOUNT)
		# The rim lights the topmost solid cell of an UP-facing face -- open air above, solid below. The
		# second half of that test is what stops a one-cell-thick shelf being lit from both sides.
		var top: int = _top_air_distance(solid_at, col, row)
		if top >= 0 and top < RIM_DEPTH and bool(solid_at.call(col, row + 1)):
			var lip: float = 1.0 - float(top) / float(RIM_DEPTH)
			rim = RIM_LIGHT * lip
			rim_warm = RIM_WARM * lip
	var lam: float = lamina(x, y) * GRAM_LAMINA[g]
	var vmul: float = maxf(VALUE_FLOOR, 1.0 - AO_PER_NEIGHBOUR * ao + grain + form) * (1.0 - LAM_DARKEN * lam)
	drift -= LAM_ADD * lam
	# CLAMPED, exactly where legacy clamps. Legacy's `_paint_fine` writes bytes -- `clampf(out.r, 0, 1)`
	# at `:1105` -- so the clamp is structural there rather than a choice, and leaving it out here let the
	# additive drift carry a channel NEGATIVE on dark rock: 3,013 of 36,000 sampled cells, worst luma
	# -0.14, found by this file's own test rather than by looking at it.
	return Color(
		clampf(col_out.r * vmul + drift + rim + rim_warm, 0.0, 1.0),
		clampf(col_out.g * vmul + drift + rim, 0.0, 1.0),
		clampf(col_out.b * vmul + drift + rim, 0.0, 1.0),
		base.a)


## The multiplicative half of the surface: grain, embedded stones and crack seams, as one value swing.
## Split out of `shade` at QUALITY gate 4's 50-line limit, and the seam is the right one -- everything
## here is microtexture that rides the material's own value, while everything left behind is either
## additive or reads the shape around the cell.
func _micro_texture(x: float, y: float, g: int) -> float:
	# Two octaves, stretched along x by the grammar so bedding runs flat.
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
	return grain


## The parting-plane weight at a cell, 0 off a parting and up to 1 on one. The whole band is the line (the
## band is a quarter-metre, one cell, so a row either is the parting or is not). BEDS ARE NOT ONE
## THICKNESS: the slow fade field picks the facies -- thick beds two metres apart where it runs low, the
## metre beds through the middle, fine laminations every half metre where it runs high, at a lighter
## weight -- so a face changes its rhythm laterally the way real bedding does, and the same field fades
## each parting but never below `LAM_FADE_FLOOR` of itself. Public for the suite: the periods are asserted
## in metres, the way every other feature size here is.
func lamina(x: float, y: float) -> float:
	var n: float = _lam_fade.get_noise_2d(x, y)
	var period: float = lamina_period_m(n)
	var f: float = BeddingTone.bedding_metres(x, y) / period
	if f - floor(f) >= LAM_BAND * LAM_PERIOD_M / period:
		return 0.0
	var weight: float = 0.55 if period < LAM_PERIOD_M else 1.0
	return weight * clampf(0.7 + 0.5 * n, LAM_FADE_FLOOR, 1.0)


## The bed thickness the fade field picks at a value: 2 m, 1 m or 0.5 m.
static func lamina_period_m(n: float) -> float:
	if n < -0.25:
		return LAM_PERIOD_M * 2.0
	if n > 0.45:
		return LAM_PERIOD_M * 0.5
	return LAM_PERIOD_M

## Legacy `_air_weight` `:1235`. Open air among the four orthogonal and four diagonal neighbours,
## orthogonals weighted 1.0 and diagonals 0.5, so a lone nub reads round and an exposed face reads deeply
## carved. Out of the probe's reach counts as AIR, exactly as legacy counts out-of-grid as air.
func _air_weight(solid_at: Callable, col: int, row: int) -> float:
	var w: float = 0.0
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		if not bool(solid_at.call(col + d.x, row + d.y)):
			w += 1.0
	for d: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		if not bool(solid_at.call(col + d.x, row + d.y)):
			w += 0.5
	return w


## Legacy `_sky_form` `:1291`. Brightens toward open air above and darkens under an overhang, each falling
## off over `FORM_REACH` rows. The `break` is legacy's: only the NEAREST opening counts, so a cell deep in
## rock is untouched and one just under a ceiling takes the full sink.
func _sky_form(solid_at: Callable, col: int, row: int) -> float:
	var f: float = 0.0
	for d: int in range(FORM_REACH):
		if not bool(solid_at.call(col, row - d - 1)):
			f += FORM_LIFT * (1.0 - float(d) / float(FORM_REACH))
			break
	for d: int in range(FORM_REACH):
		if not bool(solid_at.call(col, row + d + 1)):
			f -= FORM_SINK * (1.0 - float(d) / float(FORM_REACH))
			break
	return f


## Legacy `_top_air_distance` `:1382`. Rows between this cell and the nearest open air directly above it,
## or -1 when there is none within `RIM_DEPTH`. 0 means open air immediately above: an exposed top edge.
func _top_air_distance(solid_at: Callable, col: int, row: int) -> int:
	for d: int in range(RIM_DEPTH):
		if not bool(solid_at.call(col, row - d - 1)):
			return d
	return -1


## The seam feature size this grammar produces, in CELLS, on each axis — `1 / (freq * multiplier)`.
##
## Public because it is the check legacy prescribes for the direction error it shipped for a whole
## lifetime, and a picture cannot make it: a test computes this and reads the answer against the sentence
## "bedded runs flat". Returned as (width, height) so "flat" is `x > y` and needs no further arithmetic.
static func seam_feature_cells(gram: int) -> Vector2:
	var g: int = clampi(gram, 0, GRAM_MASSIVE)
	return Vector2(1.0 / (CRACK_FREQ * GRAM_SEAM_X[g]), 1.0 / (CRACK_FREQ * GRAM_SEAM_Y[g]))
