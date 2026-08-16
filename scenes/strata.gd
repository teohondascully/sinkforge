class_name Strata
extends RefCounted

## THE STRATA — the descent, NAMED. One static table, and the two things that read it.
##
## The game's entire subject is going down, and until now going down was unmarked: you could dig for
## four minutes and the only evidence was that the rock got darker. There was no answer to "how deep am
## I", no answer to "where am I", and — worse for pacing — no MOMENT anywhere in the descent. A player
## crossing from topsoil into the deep band experienced nothing at all.
##
## So: rows are grouped into named bands with a colour each, and two things fall out of that for free.
##   1. A permanent DEPTH READOUT — metres below the surface, and the name of the band you are in.
##   2. A one-time ARRIVAL, the first time you cross into a band you have not been in. HUD banner, sting.
##
## The names come straight from docs/PROGRESSION.md's layer ladder (L1 Topsoil → L2 Stonereach), plus
## intermediate bands for the stretches the ladder does not name, because a forty-row descent needs more
## than two waypoints. Rows line up with the worldgen constants they describe: DEEPSLATE_ROW = 52 is
## where the deep band begins, SEAL_TOP = 56 is the seal itself.
##
## `depth_m` is deliberately NOT rows-below-your-own-column: it is rows below the surface datum, so two
## players standing at the same absolute height read the same number regardless of how they got there.
## A metre is one cell — 32px, about the miner's shoulder width, which is close enough to honest.

const SURFACE_ROW: int = 20            ## the datum; matches HeightmapWorldGen.FLAT_SURFACE_ROW

## Each band: the row it BEGINS at, its name, and the colour it is announced in. Ordered top to bottom;
## a row belongs to the last band whose `from` it has reached.
const BANDS: Array[Dictionary] = [
	{"from": -99, "name": "OPEN SKY",     "color": Color(0.62, 0.76, 0.92)},
	{"from": 20,  "name": "TOPSOIL",      "color": Color(0.72, 0.56, 0.34)},
	{"from": 27,  "name": "THE CLAYBAND", "color": Color(0.86, 0.58, 0.30)},
	{"from": 38,  "name": "SHALE REACH",  "color": Color(0.58, 0.64, 0.74)},
	{"from": 52,  "name": "THE DEEPSLATE","color": Color(0.56, 0.50, 0.78)},
	{"from": 56,  "name": "THE SEAL",     "color": Color(0.72, 0.44, 0.86)},
	{"from": 58,  "name": "STONEREACH",   "color": Color(0.44, 0.62, 0.96)},
]


## Which band index a row is in. Always valid — row 0 lands in OPEN SKY, row 79 in STONEREACH.
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


## Metres below the surface datum. Negative above it — standing on a hilltop should read as ABOVE the
## surface, not as a clamped zero, because the number is only trustworthy if it is never fudged.
static func depth_m(row: int) -> int:
	return row - SURFACE_ROW
