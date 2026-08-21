class_name Strata
extends RefCounted

## The descent, named: rows grouped into coloured depth bands, plus the accessors that read the table.
##
## Two readouts fall out of it. A permanent depth display (metres below the surface and the name of the
## band you are in), and a one-time arrival, a HUD banner plus a sting, the first time you cross into a
## band you have not been in.
##
## Names follow the layer ladder in docs/PROGRESSION.md (L1 Topsoil through L2 Stonereach), with
## intermediate bands for the stretches the ladder does not name. The three bands the generator owns
## take their rows from it rather than repeating the numbers, so a world that grows cannot leave the
## map of it behind.
##
## depth_m is rows below the surface datum, not rows below the player's own column, so two players at
## the same absolute height read the same number however they got there. One metre is one cell, 32px.

const SURFACE_ROW: int = 20            ## the datum; matches HeightmapWorldGen.FLAT_SURFACE_ROW

## Each band: the row it begins at, its name, and the colour it is announced in. Ordered top to bottom;
## a row belongs to the last band whose `from` it has reached.
const BANDS: Array[Dictionary] = [
	{"from": -99, "name": "OPEN SKY",      "color": Color(0.62, 0.76, 0.92)},
	{"from": SURFACE_ROW, "name": "TOPSOIL", "color": Color(0.72, 0.56, 0.34)},
	{"from": 30,  "name": "THE CLAYBAND",  "color": Color(0.86, 0.58, 0.30)},
	{"from": 44,  "name": "SHALE REACH",   "color": Color(0.58, 0.64, 0.74)},
	{"from": 60,  "name": "THE LONG DARK", "color": Color(0.52, 0.52, 0.60)},
	{"from": LayeredWorldGen.DEEPSLATE_ROW, "name": "THE DEEPSLATE", "color": Color(0.56, 0.50, 0.78)},
	{"from": LayeredWorldGen.SEAL_TOP, "name": "THE SEAL", "color": Color(0.72, 0.44, 0.86)},
	{"from": LayeredWorldGen.SEAL_TOP + LayeredWorldGen.SEAL_ROWS, "name": "STONEREACH",
		"color": Color(0.44, 0.62, 0.96)},
]


## Which band index a row is in. Always valid: row 0 lands in the first band, the bottom row in the last.
static func band_at(row: int) -> int:
	var out: int = 0
	for i: int in BANDS.size():
		if row >= int(BANDS[i]["from"]):
			out = i
	return out


static func name_at(row: int) -> String:
	return str(BANDS[band_at(row)]["name"])


static func color_at(row: int) -> Color:
	return BANDS[band_at(row)]["color"]


## Metres below the surface datum. Negative above it: standing on a hilltop reads as a negative depth
## rather than a clamped zero, so the number is never fudged.
static func depth_m(row: int) -> int:
	return row - SURFACE_ROW
