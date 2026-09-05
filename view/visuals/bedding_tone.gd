class_name BeddingTone
extends RefCounted

## THE TONE HALF OF `MaterialLook` (split out at the file cap, D0398): legacy `world_renderer.gd`'s
## `_cell_tone`, `_strata`, `_cell_jitter` and `fine_terrain.gd`'s `apply_tone` -- the jitter, the bedding
## hue bands, the depth boost and the one authority for what a tone means to a pixel. Every function is
## static and pure over (col, row): the bedding coordinate is shared with `RockTone.lamina` so the parting
## lines sit on the hue bands. `MaterialLook.matrix_color` is the caller.

## Legacy `fine_terrain.gd:405-406`. The two ends the bedding pulls toward.
const STRATA_WARM: Color = Color(0.86, 0.74, 0.52)  ## the sandy band
const STRATA_COOL: Color = Color(0.15, 0.16, 0.21)  ## the cool clay/silt band
const STRATA_AMOUNT: float = 0.22  ## legacy `world_renderer.gd:1611` had 0.17; D0398, T017: more bedding
## The bedding's pull by grammar (D0398): bedded rock IS its beds, soil has horizons, massive rock has
## almost none -- its identity is plates and fractures (`RockTone.GRAM_PATCH`/`GRAM_SEAM`).
const GRAM_BEDDING: Array[float] = [0.9, 1.4, 0.45]

## The depth over which the tone boost runs from none to full: the site's own `max_depth_m`, matching
## legacy's normalisation by `GRID_ROWS`. And the extra it reaches there -- legacy's `2.2`, so the boost
## spans 1.0 at the surface to 3.2 at the floor.
const TONE_BOOST_FULL_M: float = 256.0
const TONE_BOOST_AT_FLOOR: float = 1.0


## Legacy `world_renderer.gd:1596 _cell_tone`, as `(jitter, bedding)`.
##
## THE DEPTH BOOST, PORTED NOW THAT ITS PRECONDITION EXISTS (D0312). Legacy `world_renderer.gd:1591-1594
## _cell_tone` multiplies BOTH terms by `1 + depth * 2.2`, for one stated reason: the shadow veil takes
## roughly half a cell's tonal range, so the compensation must exceed 2x by the deep band or bedding does
## not read down there at all.
##
## This paragraph used to say "this build has no veil, so the boost would not be compensating for
## anything -- it comes back WITH the veil, not before it." **The veil landed at D0302 and its lamp at
## D0306**, so the deferral's own condition is met and the number it was waiting for now exists:
## `VeilPainter.MASS_SHADE` is 0.55, which is the "roughly half" legacy was describing, measured rather
## than assumed.
##
## Legacy normalises depth by `GRID_ROWS`, the world's whole row extent. The equivalent here is the
## site's own `max_depth_m` (256, `data/strata/shallow_clay.yaml:13`, per `docs/ARCHITECTURE.md` §9), so
## the boost runs from 1.0 at the surface to `1 + TONE_BOOST_AT_FLOOR` at the floor, on legacy's own
## curve. It is a metre constant for the same reason `DEPTH_DARKEN_FULL_M` is one.
##
## **AND THE CONSTANT IS 1.0 HERE, NOT LEGACY'S 2.2, BECAUSE THE TWO GUARANTEES CANNOT BOTH HOLD**
## (`docs/NEEDS_DIRECTOR.md` P029). At legacy's 2.2 the deep tone swing brings deepstone within **0.239**
## of glimmer, under `test_material_palette`'s shipped **0.25** distinctness floor — and glimmer is the
## reveal material, the one thing that must never be mistaken for the rock around it. Measured across the
## whole range: 2.2 → 0.239, 1.8 → 0.243, 1.5 → 0.248, 1.2 → 0.249, 1.1 → 0.250, **1.0 → 0.253**.
##
## Legacy's own requirement is that the boost EXCEED 2x at the deep band, which needs a constant of at
## least 1.83. The glimmer floor allows at most about 1.0. There is no value satisfying both, so this
## ships the largest one that breaks no shipped guarantee and the trade is parked rather than decided in
## a loop. It still does most of the work: post-veil deep spread goes 0.0706 → 0.1083, a 53% recovery.
## `bedded` is false for ore-bearing rock, which takes the JITTER but not the BEDDING -- see the note on
## `cell_color`. The jitter is a small achromatic value drift and breaks a flat fill either way; the
## bedding is a hue move toward `STRATA_WARM`/`STRATA_COOL` and is a statement about sedimentary
## structure. A vein is not bedded, it CUTS bedding, which is exactly why legacy drew it as separate
## polygons over the top rather than as a modulation of the fill.
static func cell_tone(col: int, row: int, bedded: bool = true, gram: int = RockTone.GRAM_CLASTIC) -> Vector2:
	var boost: float = tone_depth_boost(row)
	var pull: float = GRAM_BEDDING[clampi(gram, 0, RockTone.GRAM_MASSIVE)]
	return Vector2(_cell_jitter(col, row) * boost,
		(_strata(col, row) * pull if bedded else 0.0) * boost)


## `1 + depth * 2.2`, legacy's own form, with depth normalised over the world's stated depth budget.
##
## Public because the claim it encodes is testable and should be tested rather than believed: legacy says
## the compensation "must exceed 2x by the deep band", and `tests/test_material_palette.gd` asserts that
## against `MaterialLook.band_at`'s own ladder instead of restating the sentence.
static func tone_depth_boost(row: int) -> float:
	var frac: float = clampf(MaterialLook.depth_m_exact(row) / TONE_BOOST_FULL_M, 0.0, 1.0)
	return 1.0 + frac * TONE_BOOST_AT_FLOOR


## Legacy `fine_terrain.gd:411-415 apply_tone` -- THE single authority for what a tone means to a pixel.
##
## Legacy states three times, in three files, that only one place may own this, because the coarse pass
## and the fine pass have to reconstruct the same colour and a second copy is how they drift. There is
## only a coarse pass here today, so the rule costs nothing to keep and would cost a repaint to recover.
##
## Applied RELATIVE to the cell's own colour, never toward an absolute band target. Legacy tried the
## absolute form and recorded why it failed: a dark clay target sits almost exactly on deep stone's own
## colour, so half the bedding became a no-op in the place that needed it most.
static func apply_tone(base: Color, tone: Vector2) -> Color:
	var col: Color = base.lightened(tone.x) if tone.x > 0.0 else base.darkened(-tone.x)
	if tone.y > 0.0:
		return col.lightened(tone.y * 0.85).lerp(STRATA_WARM, tone.y * 0.30)
	return col.darkened(-tone.y * 1.05).lerp(STRATA_COOL, -tone.y * 0.20)


## Legacy `world_renderer.gd:1613-1619 _strata`. Sedimentary banding: the ground's own structure.
##
## Bands run horizontally -- the direction you cut across as you sink -- at three INCOMMENSURABLE
## frequencies, so fine laminations and thick beds overlap and the pattern never visibly repeats down a
## shaft. They are warped slowly along x by two more sines so a layer dips and rises like real bedding
## instead of ruling a straight line across the world.
##
## COMPUTED IN METRES, which is the whole of the scale conversion. Legacy's `c` is a 32px logic cell and
## one legacy cell is one metre; this world's cell is 4px and four of them are one metre, so feeding raw
## terrain rows into legacy's frequencies would give beds a quarter of their authored thickness -- ~4.6
## metres instead of ~18.5 for the thick bed, which at any real zoom is a stripe pattern and not bedding.
## Dividing the coordinate by `CELLS_PER_METRE` and leaving every legacy constant untouched keeps the
## authored wavelength in the units the director's "keep 16px, adapt the art" ruling preserves.
static func _strata(col: int, row: int) -> float:
	var y: float = bedding_metres(float(col), float(row))
	# Periods of roughly 18, 7 and 4 metres. A screen holds about 22 metres at the default zoom, so you
	# always see a thick bed, the layers inside it, and the fine laminations between: the whole scale
	# ladder at once, which is what makes ground read as ground.
	var n: float = sin(y * 0.34) * 0.46 + sin(y * 0.88) * 0.36 + sin(y * 1.62) * 0.18
	return n * STRATA_AMOUNT


## The warped bedding coordinate at a cell, in metres: the row in metres, dipped and raised along x by
## legacy's two slow sines, so a bed follows the same line wherever it is read. Shared by `_strata` (the
## hue bands) and `RockTone.lamina` (the parting lines), which is what keeps the lines ON the beds.
static func bedding_metres(x: float, y: float) -> float:
	var xm: float = x / float(MaterialLook.CELLS_PER_METRE)
	var ym: float = y / float(MaterialLook.CELLS_PER_METRE)
	return ym + sin(xm * 0.055) * 2.4 + sin(xm * 0.021) * 3.6


## Legacy `world_renderer.gd:1624-1629 _cell_jitter`. A smooth, spatially-coherent value nudge over
## roughly [-0.06, +0.06].
##
## LOW-FREQUENCY SINES, NOT A HASH, and that is the entire point of the function. This file previously
## carried a per-cell hash at the same +/-0.06 amplitude as a stand-in. Legacy's own comment rules the
## hash out by name: a per-cell random "seams at every tile edge and so redraws the grid" -- it re-draws
## the very lattice the renderer is trying to hide, which is exactly what the pre-port capture shows as
## a field of individually-visible speckled squares. Neighbouring cells must SHARE tone in cloudy
## patches for a fill to read as a mass rather than as tiles. Same metres conversion as `_strata`.
static func _cell_jitter(col: int, row: int) -> float:
	var x: float = float(col) / float(MaterialLook.CELLS_PER_METRE)
	var y: float = float(row) / float(MaterialLook.CELLS_PER_METRE)
	var n: float = sin(x * 0.37 + y * 0.21) + sin(x * 0.13 - y * 0.41) + sin((x + y) * 0.27)
	return n / 3.0 * 0.06
