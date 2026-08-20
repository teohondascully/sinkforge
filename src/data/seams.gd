class_name Seams
extends RefCounted

## THE ROCK HAS A GRAIN. Every rock cell carries a seam direction; a blow struck ALONG the grain calves off the
## contiguous run of same-seam rock in one hit (`docs/BITS.md` 2). Cutting ACROSS costs nothing extra: ordinary
## one-cell mining at ordinary speed, because the wrong swing must never be slower.
##
## Seams are PLANES, not per-cell rolls: horizontal = a world ROW, vertical = a COLUMN, diagonal = one
## anti-diagonal. A per-cell roll at 35% density yields a run of three about once in six hundred. A seam is a
## pure function of (coordinate, world_seed), never saved; changing the rates below re-grains every world.

enum { NONE = 0, HORIZONTAL = 1, VERTICAL = 2, DIAGONAL = 3 }

## How often a plane of each kind occurs. Combined, roughly a third of the world is grained.
## Placeholders tuned for play, not a spec (`docs/BITS.md` §4).
const RATE_HORIZONTAL: float = 0.18
const RATE_VERTICAL: float = 0.12
const RATE_DIAGONAL: float = 0.07

## Salts, so the three planes are independent fields of the seed rather than one field read thrice.
const SALT_HORIZONTAL: int = 0x9e3779b9
const SALT_VERTICAL: int = 0x85ebca6b
const SALT_DIAGONAL: int = 0xc2b2ae35

## Cells one plain swing may take along the grain. The Wedge bit raises it (`docs/BITS.md` §3).
const RUN_CAP: int = 3


## The seam through a cell, or NONE. Precedence is bedding, joint, diagonal: arbitrary but FIXED, so a cell where
## two planes cross has one answer the renderer and the swing agree on.
static func at(c: Vector2i, world_seed: int) -> int:
	if _plane(c.y, world_seed ^ SALT_HORIZONTAL) < RATE_HORIZONTAL:
		return HORIZONTAL
	if _plane(c.x, world_seed ^ SALT_VERTICAL) < RATE_VERTICAL:
		return VERTICAL
	if _plane(c.x + c.y, world_seed ^ SALT_DIAGONAL) < RATE_DIAGONAL:
		return DIAGONAL
	return NONE


## The step along a seam: the direction its run travels. NONE has no axis.
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


## Does a blow travelling `dir` cut ALONG this seam? Compared as an undirected line: requiring a sign would leave
## half of every seam dead. `dir` is the swing direction, body toward cell, need not be normalised or axis-aligned,
## and is quantised to the nearest of the three planes here.
static func aligned(seam: int, dir: Vector2i) -> bool:
	if seam == NONE or dir == Vector2i.ZERO:
		return false
	var a: Vector2i = axis(seam)
	# Dominant-axis quantisation. Exact for integers, and no trigonometry in the dig path.
	var along: int = absi(dir.x * a.x + dir.y * a.y)
	var across: int = absi(dir.x * a.y - dir.y * a.x)
	return along >= across


## A stable scramble of one cell, for anything needing the same seam to look different in different places: the
## plane decides where the grain runs, this decides how it looks along its length.
static func grain(c: Vector2i) -> int:
	var h: int = (c.x * 668265263) ^ (c.y * 374761393)
	h = (h ^ (h >> 15)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


## A stable scramble of one plane index, 0..1. Same shape as TerrainPainter._fringe_hash: RNG-free and stable
## across loads, so a world's grain is a property of its seed alone.
static func _plane(index: int, salt: int) -> float:
	var h: int = (index * 374761393) ^ (salt * 668265263)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0
