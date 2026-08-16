class_name Seams
extends RefCounted

## THE ROCK HAS A GRAIN.
##
## Mining has had exactly one verb since the beginning: point at a cell, hold, the cell goes away. Every
## block costs the same attention as every other block, so a thousand of them cost a thousand times the
## attention, and that is the whole reason hand-mining reads as a chore rather than a craft. The fix is not
## to make blocks break faster — that is the treadmill (`docs/BITS.md` §2) — it is to make SOME of them
## break together, and to let you SEE which before you swing.
##
## So every rock cell now carries a seam direction, and striking ALONG it calves off the contiguous run of
## same-seam rock in one blow. Reading the rock pays.
##
## SEAMS NEVER PUNISH. This is the load-bearing rule and it is why this is not slowness wearing a hat:
## cutting ACROSS the grain costs nothing extra — it is exactly today's mining, one cell at today's speed.
## A player who never notices seams plays the game we already shipped; a player who does gets paid for
## looking. Any version where the wrong swing is SLOWER is the treadmill coming back in through the window.
##
## THEY ARE LINES, NOT A SPRINKLE, and that is the part worth getting right. The obvious implementation —
## roll a direction per cell — gives a 35%-dense sprinkle in which a contiguous run of three same-seam cells
## occurs about once in six hundred, so the mechanic would fire essentially never and would be invisible
## besides. Real rock does not work that way either: bedding planes are horizontal and run for miles, joints
## are vertical and roughly parallel, and both are properties of a PLANE rather than of a stone. So a
## horizontal seam is a ROW of the world, a vertical seam is a COLUMN, a diagonal seam is one anti-diagonal.
## Runs come for free, the field is legible as strata (which the terrain already draws), and the scanner
## finally has something to keep revealing after it has found every vein.
##
## STORAGE COST: ZERO. A seam is a pure function of (coordinate, world_seed) — deterministic, never saved,
## never resident, the same trick the ore glints and the fine terrain already use. Changing the rates below
## re-grains every existing world, which is fine: no save records this.

enum { NONE = 0, HORIZONTAL = 1, VERTICAL = 2, DIAGONAL = 3 }

## How often a plane of each kind occurs. Bedding dominates, because it is what the strata already draw and
## therefore the one a player can read without being taught; joints are the crossing set that keeps a shaft
## from being a single answer; diagonals are rare enough to feel like a find. Combined these leave roughly a
## third of the world grained — placeholders for play, not a spec (`docs/BITS.md` §4).
const RATE_HORIZONTAL: float = 0.18
const RATE_VERTICAL: float = 0.12
const RATE_DIAGONAL: float = 0.07

## Salts, so the three planes are independent fields of the same seed rather than the same field read thrice.
const SALT_HORIZONTAL: int = 0x9e3779b9
const SALT_VERTICAL: int = 0x85ebca6b
const SALT_DIAGONAL: int = 0xc2b2ae35

## How many cells one blow may take along the grain, for a plain swing. The Wedge bit raises this
## (`docs/BITS.md` §3); until bits exist this is the only cap there is. Three is deliberately modest: it is
## a beat, not a bulldozer, and the point is that you notice it.
const RUN_CAP: int = 3


## The seam through a cell, or NONE. Precedence is bedding, then joint, then diagonal — an arbitrary but
## FIXED order, so a cell where two planes cross has one answer and both the renderer and the swing agree
## on it.
static func at(c: Vector2i, world_seed: int) -> int:
	if _plane(c.y, world_seed ^ SALT_HORIZONTAL) < RATE_HORIZONTAL:
		return HORIZONTAL
	if _plane(c.x, world_seed ^ SALT_VERTICAL) < RATE_VERTICAL:
		return VERTICAL
	if _plane(c.x + c.y, world_seed ^ SALT_DIAGONAL) < RATE_DIAGONAL:
		return DIAGONAL
	return NONE


## The step along a seam — the direction its run travels. NONE has no axis.
static func axis(seam: int) -> Vector2i:
	match seam:
		HORIZONTAL:
			return Vector2i(1, 0)
		VERTICAL:
			return Vector2i(0, 1)
		DIAGONAL:
			return Vector2i(1, -1)
		_:
			return Vector2i.ZERO


## Does a blow travelling `dir` cut ALONG this seam? Compared as an undirected line: striking a bedding
## plane from the left and from the right are the same act, and demanding a sign would make half of every
## seam silently dead. `dir` is the swing's direction — from the body toward the cell — and need not be
## normalised or axis-aligned; it is quantised to the nearest of the three planes here.
static func aligned(seam: int, dir: Vector2i) -> bool:
	if seam == NONE or dir == Vector2i.ZERO:
		return false
	var a: Vector2i = axis(seam)
	# Dominant-axis quantisation: a swing counts as along the grain when its heading is closer to that
	# plane than to either other. Cheap, exact for integers, and no trigonometry in the dig path.
	var along: int = absi(dir.x * a.x + dir.y * a.y)
	var across: int = absi(dir.x * a.y - dir.y * a.x)
	return along >= across


## A stable scramble of ONE CELL, for anything that needs the same seam to look different in different
## places. The plane decides WHERE the grain runs; this decides how it looks along its length — which
## stretches have opened and which are still welded shut. Deterministic, so a parting does not crawl.
static func grain(c: Vector2i) -> int:
	var h: int = (c.x * 668265263) ^ (c.y * 374761393)
	h = (h ^ (h >> 15)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


## A stable scramble of one plane index. Returns 0..1. Same shape as TerrainPainter._fringe_hash — RNG-free
## and stable across loads, so a world's grain is a property of its seed and nothing else.
static func _plane(index: int, salt: int) -> float:
	var h: int = (index * 374761393) ^ (salt * 668265263)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0
