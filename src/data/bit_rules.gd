class_name BitRules
extends RefCounted

## PICKS THAT DIFFER IN SHAPE, NOT IN SPEED (`docs/BITS.md` 2-3). `MiningRules.TOOLS` used to gate which rock
## a tier may bite AND multiply break speed 1.0 / 1.7 / 2.6. The speed axis is deleted, leaving the DRIVE (a
## pick's tier, gating what may be bitten) and the BITS below (interchangeable cutting heads deciding what one
## swing takes; all collectable, none ever removed). Each bit is priced so it is worse than the Point somewhere:
##
##   POINT   one cell, any direction. The baseline.
##   BROAD   2x2, but PULVERISES: nothing it breaks enters the pack. For rooms, never veins.
##   LANCE   1x5 driven along the facing. Long recovery after the blow.
##   SINKER  three cells straight down, walls untouched. Sinks a clean 1-wide shaft.
##   WEDGE   splits ALONG a seam, eight cells deep, and does nothing across the grain.
##
## EQUIPPING IS STATELESS: the bit in use is whatever sits in the selected hotbar slot, and anything
## that is not a bit means the Point. No equip screen, no new key, no saved field to migrate.

const POINT: StringName = &"point"
const BROAD: StringName = &"broad_bit"
const LANCE: StringName = &"lance_bit"
const SINKER: StringName = &"sinker_bit"
const WEDGE: StringName = &"wedge_bit"

## `cap`: how far a blow may calve ALONG a seam (see `Seams`); 1 = does not follow the grain. `keeps` false
## is the Broad's pulverise. `grain_only` is the Wedge: it splits rock or does nothing. `recovery` is seconds
## added before the next charge may begin. `ray` marks a DRIVEN LINE rather than a block: it stops at the first
## non-solid cell, so a lance cannot take rock beyond a chamber.
const BITS: Dictionary = {
	POINT: {
		&"label": "Point", &"cap": Seams.RUN_CAP, &"keeps": true,
		&"grain_only": false, &"recovery": 0.0, &"ray": false,
	},
	BROAD: {
		&"label": "Broad", &"cap": 1, &"keeps": false,
		&"grain_only": false, &"recovery": 0.0, &"ray": false,
	},
	LANCE: {
		&"label": "Lance", &"cap": 1, &"keeps": true,
		&"grain_only": false, &"recovery": 0.85, &"ray": true,
	},
	SINKER: {
		&"label": "Sinker", &"cap": 1, &"keeps": true,
		&"grain_only": false, &"recovery": 0.0, &"ray": true,
	},
	WEDGE: {
		&"label": "Wedge", &"cap": 8, &"keeps": true,
		&"grain_only": true, &"recovery": 0.0, &"ray": false,
	},
}

## Bought rather than researched, and priced in REFINED goods rather than raw ore (`docs/BITS.md` 7). They share
## the Bazaar's craft path until the Rack exists (`docs/BAZAAR.md` 6).
const BIT_RECIPES: Dictionary = {
	BROAD: {&"ingot": 3, &"stone": 12},
	SINKER: {&"ingot": 3, &"wood": 8},
	LANCE: {&"ingot": 5, &"coal": 4},
	WEDGE: {&"ingot": 8, &"coal": 6},
}


static func is_bit(item: StringName) -> bool:
	return BITS.has(item) and item != POINT


## The bit a pack selection means. Anything that is not a bit is the Point, so there is no Point ITEM to seed,
## lose, or migrate into an old save.
static func equipped(selected: StringName) -> StringName:
	return selected if is_bit(selected) else POINT


static func label(bit: StringName) -> String:
	return String(BITS.get(bit, BITS[POINT])[&"label"])


static func cap(bit: StringName) -> int:
	return int(BITS.get(bit, BITS[POINT])[&"cap"])


static func keeps(bit: StringName) -> bool:
	return bool(BITS.get(bit, BITS[POINT])[&"keeps"])


static func grain_only(bit: StringName) -> bool:
	return bool(BITS.get(bit, BITS[POINT])[&"grain_only"])


static func recovery(bit: StringName) -> float:
	return float(BITS.get(bit, BITS[POINT])[&"recovery"])


## A driven line, which stops at the first gap, versus a block, which does not.
static func ray(bit: StringName) -> bool:
	return bool(BITS.get(bit, BITS[POINT])[&"ray"])


## The cells one blow takes, aimed cell FIRST; the rest are what this bit adds. `face` is the body's horizontal
## heading (-1 or +1). Every shape must include the aimed cell: a bit never moves it.
static func cut(bit: StringName, cell: Vector2i, face: int) -> Array[Vector2i]:
	var f: int = -1 if face < 0 else 1
	match bit:
		BROAD:
			# Extends along the facing and DOWNWARD, keeping the aimed cell on the chamber's near-top corner.
			return [cell, cell + Vector2i(f, 0), cell + Vector2i(0, 1), cell + Vector2i(f, 1)]
		LANCE:
			return [cell, cell + Vector2i(f, 0), cell + Vector2i(f * 2, 0),
				cell + Vector2i(f * 3, 0), cell + Vector2i(f * 4, 0)]
		SINKER:
			return [cell, cell + Vector2i(0, 1), cell + Vector2i(0, 2)]
		_:
			return [cell]
