class_name BedSequence
extends RefCounted

## THE BEDS AS A SEQUENCE, NOT A PERIOD (D0406; the round before's "ruled paper", V71/T018). D0398 drew a
## parting every metre of the warped bedding coordinate, one cell thick, at one strength: where the fade
## field ran flat the face read as lines on a page, because every bed was the same bed. Real bedding is a
## SUCCESSION: each bed its own thickness, each parting its own sharpness, some boundaries barely there
## and some two cells of dark shale, and the rhythm changing with the facies rather than switching.
##
## Every metre boundary `j` of the warped coordinate is a candidate parting with four properties drawn from
## a hash of (j, world seed), constant along the bed so the line stays one continuous surface:
##   - PRESENCE: ~three in ten are absent, so beds merge into two- and three-metre units;
##   - POSITION: shifted up to +/-0.3 m, so thicknesses run 0.4..1.6 m before merging, plus a small wobble
##     along the bed so a line drifts a cell here and there instead of ruling straight across;
##   - THICKNESS: one cell, or one in five two cells;
##   - STRENGTH: 0.45..1.0 of the full parting.
## THE FACIES are the fade field's, as before -- thick beds where it runs low, fine laminations where it
## runs high -- but blended over a band of the field rather than switched at a value, so a facies boundary
## is a change of rhythm, never a line that starts mid-air. The same field fades every parting, never
## below its floor. Pure and seeded: the same cell always shades the same.

const SPACING_M: float = 1.0          ## the base metre boundary; every other feature is relative to it
const ABSENT: float = 0.30            ## the share of metre boundaries that are not partings
const JITTER_M: float = 0.6           ## a boundary sits within +/- half of this of its metre
const WOBBLE_M: float = 0.10          ## the along-bed drift, under half a cell, so a line breaks its rule
const WOBBLE_FREQ: float = 0.7        ## per metre of x
const HALF_THIN_M: float = 0.125      ## half a cell: the one-cell parting
const HALF_THICK_M: float = 0.25      ## a full cell each way: the two-cell parting
const THICK_SHARE: float = 0.20
const STRENGTH_FLOOR: float = 0.45    ## the faintest present parting, as a share of the full one
const FINE_WEIGHT: float = 0.55       ## a half-metre lamination's weight against a metre parting
const FADE_FLOOR: float = 0.30        ## a parting is never fainter than this share of itself
## The facies blends: the odd metre boundaries fade OUT as the field falls through [-0.35, -0.15] (thick
## beds, two metres apart), and the half-metre laminations fade IN as it rises through [0.35, 0.55].
const THICK_LO: float = -0.35
const THICK_HI: float = -0.15
const FINE_LO: float = 0.35
const FINE_HI: float = 0.55

var _seed: int


func _init(world_seed: int) -> void:
	_seed = world_seed


## The parting weight at warped depth `b` (metres), column `x_m` (metres) and fade-field value `n` (-1..1):
## 0 off every parting, up to 1 on a full one.
func weight(b: float, x_m: float, n: float) -> float:
	var k: int = floori(b / SPACING_M)
	var odd_weight: float = smoothstep(THICK_LO, THICK_HI, n)
	var fine_weight: float = smoothstep(FINE_LO, FINE_HI, n) * FINE_WEIGHT
	var best: float = 0.0
	for j: int in range(k - 1, k + 2):
		var facies: float = 1.0 if (j & 1) == 0 else odd_weight
		if facies > 0.0:
			best = maxf(best, _boundary(b, x_m, j, 0, facies))
		if fine_weight > 0.0:
			best = maxf(best, _boundary(b, x_m, j, 1, fine_weight))
	if best <= 0.0:
		return 0.0
	return best * clampf(0.7 + 0.5 * n, FADE_FLOOR, 1.0)


## One candidate boundary: metre `j` (lane 0) or the half-metre above it (lane 1), at its own position,
## thickness and strength; 0 when absent or when `b` is off it.
func _boundary(b: float, x_m: float, j: int, lane: int, facies: float) -> float:
	var id: int = j * 2 + lane
	if _unit(id, 1) < ABSENT:
		return 0.0
	var pos: float = (float(j) + 0.5 * lane) * SPACING_M + (_unit(id, 2) - 0.5) * JITTER_M
	pos += WOBBLE_M * sin(x_m * WOBBLE_FREQ + _unit(id, 5) * TAU)
	var half: float = HALF_THICK_M if _unit(id, 3) < THICK_SHARE else HALF_THIN_M
	if absf(b - pos) >= half:
		return 0.0
	return facies * (STRENGTH_FLOOR + (1.0 - STRENGTH_FLOOR) * _unit(id, 4))


## A unit float from (boundary id, salt, world seed): integer mixing, so the same seed beds the same on
## every platform.
func _unit(id: int, salt: int) -> float:
	var h: int = (id * 374761393 + salt * 668265263 + _seed * 1274126177) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777216.0
