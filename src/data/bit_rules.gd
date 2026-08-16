class_name BitRules
extends RefCounted

## PICKS THAT DIFFER IN SHAPE, NOT IN SPEED (`docs/BITS.md` §2–§3).
##
## The pick ladder was secretly doing two jobs at once and doing the second one badly. `MiningRules.TOOLS`
## gates which rock you may bite AT ALL by tier — a wood pick cannot touch deepslate, it does not grind
## slowly through it — and it ALSO multiplied your break speed, 1.0 → 1.7 → 2.6. So every upgrade was
## mostly the old pick, faster. That is the treadmill, and the speed axis is the part worth deleting.
##
## Split the tool into the two things it was already doing and let each do only its own job:
##
##   THE DRIVE — your pick's tier. Decides what you can BITE at all. Monotonic, one track, never lost.
##   THE BITS  — interchangeable cutting heads. Decide what one swing TAKES. Horizontal: collect them all,
##               keep them all, and a new layer never takes one away from you.
##
## Each bit is a VERB rather than a number, and each answers a situation this game actually has. The prices
## are the design: a bit you would never take off is a stat wearing a costume, so every one of them is worse
## than the Point somewhere.
##
##   POINT   one cell, any direction. The baseline, and it never stops being correct.
##   BROAD   2x2 — but it PULVERISES: nothing it breaks enters your pack. For hollowing rooms, never veins.
##   LANCE   1x5 driven the way you face. Long recovery after the blow; it is a commitment, not a rhythm.
##   SINKER  three cells straight down, walls untouched. Sinks the clean 1-wide shaft a gravity chain wants.
##   WEDGE   splits ALONG a seam, eight cells deep — and does nothing whatsoever across the grain.
##
## The Broad's price is the one that makes the set work: you hollow a chamber with it and swap to the Point
## the moment you hit a vein, because Broad would grind the ore to nothing. That swap IS the mechanic.
##
## EQUIPPING IS STATELESS, deliberately. The bit you are digging with is simply the one in your selected
## hotbar slot; select anything else and you are back on the Point. There is no equip screen, no new key, no
## saved field to migrate, and no way to be confused about what you are holding — what is in your hand is
## what you dig with. Selecting ore to deposit does put you back on the Point, which is correct: you are
## holding ore.

const POINT: StringName = &"point"
const BROAD: StringName = &"broad_bit"
const LANCE: StringName = &"lance_bit"
const SINKER: StringName = &"sinker_bit"
const WEDGE: StringName = &"wedge_bit"

## `run_cap` is how far a blow may calve ALONG a seam (see `Seams`); 1 means this bit does not follow the
## grain at all. `keeps` false is the Broad's pulverise. `grain_only` is the Wedge's whole character: it
## splits rock or it does nothing, and which one is up to you reading the wall. `recovery` is seconds added
## before the next charge may begin — the Lance's cost, and the only reason it is not a strictly better Point.
## `ray` marks the shapes that are a DRIVEN LINE rather than a block: they stop at the first cell that is not
## solid, so a lance cannot punch through a chamber and take rock on its far side. Same rule the seam run
## obeys, for the same reason — a blow reaches as far as the rock it travels through, and no further.
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

## Bought rather than researched, and priced in REFINED goods rather than raw ore, so buying one is always a
## reason to run the factory harder and never a reason to hand-mine more (`docs/BITS.md` §7). They share the
## Bazaar's existing craft path until the Rack exists (`docs/BAZAAR.md` §6).
const BIT_RECIPES: Dictionary = {
	BROAD: {&"ingot": 3, &"stone": 12},
	SINKER: {&"ingot": 3, &"wood": 8},
	LANCE: {&"ingot": 5, &"coal": 4},
	WEDGE: {&"ingot": 8, &"coal": 6},
}


static func is_bit(item: StringName) -> bool:
	return BITS.has(item) and item != POINT


## The bit a pack-selection means. Anything that is not a bit — ore, a machine, an empty pack — is the Point,
## which is why there is no Point ITEM to seed, lose, or migrate into an old save.
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


## The cells one blow takes, aimed cell FIRST — the rest are what this bit adds around it. `face` is the
## body's horizontal heading (-1 or +1), so the shapes that have a direction point the way you are looking
## rather than at a fixed compass bearing.
##
## Every shape includes the aimed cell, which is not a detail: the aim cursor points at one cell and the
## contract with the player is that the cell you pointed at is the cell that breaks. A bit adds to that; it
## never moves it.
static func cut(bit: StringName, cell: Vector2i, face: int) -> Array[Vector2i]:
	var f: int = -1 if face < 0 else 1
	match bit:
		BROAD:
			# Extends the way you face and DOWNWARD — the two directions you are hollowing toward when you
			# are cutting a room, and the two that keep the aimed cell on the chamber's near-top corner
			# where you can see it.
			return [cell, cell + Vector2i(f, 0), cell + Vector2i(0, 1), cell + Vector2i(f, 1)]
		LANCE:
			return [cell, cell + Vector2i(f, 0), cell + Vector2i(f * 2, 0),
				cell + Vector2i(f * 3, 0), cell + Vector2i(f * 4, 0)]
		SINKER:
			return [cell, cell + Vector2i(0, 1), cell + Vector2i(0, 2)]
		_:
			return [cell]
