class_name Seams
extends RefCounted

## THE ROCK HAS A GRAIN. Every rock cell carries a seam direction; a blow struck ALONG the grain calves
## off the contiguous run of same-seam rock in one hit. Cutting ACROSS costs nothing extra: ordinary
## one-cell mining at ordinary speed, because the wrong swing must never be slower.
##
## Seams are PLANES, not per-cell rolls: horizontal = a world ROW, vertical = a COLUMN, diagonal = one
## anti-diagonal. A per-cell roll at 35% density yields a run of three about once in six hundred. A seam
## is a pure function of (coordinate, world_seed), never saved; changing the rates below re-grains every
## world.
##
## Lifted from `legacy/src/data/seams.gd` (`docs/DECISIONS_LEDGER.md` D0227). One change, and it is the
## reason this file could come to `sim/` at all: **the three rates and `_plane` were floats and are now
## integers.** `sim/` is fixed-point and cross-platform-deterministic by contract (ARCHITECTURE §4), and
## a float comparison is the one thing in this file that could have differed between two machines.
##
## THE CONVERSION IS EXACT, not rounded. `_plane` returned `(h & 0xffff) / 65535.0` and the caller asked
## `< 0.18`; it now returns the raw `h & 0xffff` (0..65535) and the caller asks
## `v * 10000 < RATE * 65535` with RATE in ten-thousandths. Both sides are integers, the inequality is
## the same one, and no value of `v` changes its answer -- as opposed to the tempting
## `v < int(0.18 * 65535)`, which flips exactly one of the 65,536 inputs per plane. Pinned by a test
## rather than by this paragraph (`tests/test_seams.gd`).
##
## NOT WIRED TO ANYTHING YET, stated so nobody reads its presence as a shipped mechanic: no mining path
## calls `at()` or `aligned()`. It is the substrate the grain mechanic needs, ported while it is cheap
## and provably pure, not the mechanic.

enum { NONE = 0, HORIZONTAL = 1, VERTICAL = 2, DIAGONAL = 3 }

## How often a plane of each kind occurs, in TEN-THOUSANDTHS (1800 = 0.18). Combined, roughly a third of
## the world is grained. Placeholders tuned for play, not a spec.
const RATE_HORIZONTAL: int = 1800
const RATE_VERTICAL: int = 1200
const RATE_DIAGONAL: int = 700
const RATE_DENOMINATOR: int = 10000

## The width of `_plane`'s output, which is a 16-bit hash slice: 0..65535 inclusive.
const PLANE_MAX: int = 65535

## Salts, so the three planes are independent fields of the seed rather than one field read thrice.
const SALT_HORIZONTAL: int = 0x9e3779b9
const SALT_VERTICAL: int = 0x85ebca6b
const SALT_DIAGONAL: int = 0xc2b2ae35

## Cells one plain swing may take along the grain. The Wedge bit raises it.
const RUN_CAP: int = 3


## The seam through a cell, or NONE. Precedence is bedding, joint, diagonal: arbitrary but FIXED, so a
## cell where two planes cross has one answer the renderer and the swing agree on.
static func at(terrain_cell: Vector2i, world_seed: int) -> int:
	if _under(_plane(terrain_cell.y, world_seed ^ SALT_HORIZONTAL), RATE_HORIZONTAL):
		return HORIZONTAL
	if _under(_plane(terrain_cell.x, world_seed ^ SALT_VERTICAL), RATE_VERTICAL):
		return VERTICAL
	if _under(_plane(terrain_cell.x + terrain_cell.y, world_seed ^ SALT_DIAGONAL), RATE_DIAGONAL):
		return DIAGONAL
	return NONE


## The step along a seam, in TERRAIN cells: the direction its run travels. NONE has no axis. The
## `terrain_` prefix is the D0027 rule -- a bare `axis()` returning Vector2i cannot say which of the two
## grids it speaks, and seams are on the 4px terrain grid, not the 16px logic one.
static func terrain_axis(seam: int) -> Vector2i:
	match seam:
		HORIZONTAL:
			return Vector2i(1, 0)
		VERTICAL:
			return Vector2i(0, 1)
		DIAGONAL:
			return Vector2i(1, -1)
		_:
			return Vector2i.ZERO


## Does a blow travelling `dir` cut ALONG this seam? Compared as an undirected line: requiring a sign
## would leave half of every seam dead. `dir` is the swing direction, body toward cell, need not be
## normalised or axis-aligned, and is quantised to the nearest of the three planes here.
static func aligned(seam: int, terrain_dir: Vector2i) -> bool:
	if seam == NONE or terrain_dir == Vector2i.ZERO:
		return false
	var seam_axis: Vector2i = terrain_axis(seam)
	# Dominant-axis quantisation. Exact for integers, and no trigonometry in the dig path.
	var along: int = absi(terrain_dir.x * seam_axis.x + terrain_dir.y * seam_axis.y)
	var across: int = absi(terrain_dir.x * seam_axis.y - terrain_dir.y * seam_axis.x)
	return along >= across


## A stable scramble of one cell, for anything needing the same seam to look different in different
## places: the plane decides where the grain runs, this decides how it looks along its length.
static func grain(terrain_cell: Vector2i) -> int:
	var h: int = (terrain_cell.x * 668265263) ^ (terrain_cell.y * 374761393)
	h = (h ^ (h >> 15)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


## `numerator / PLANE_MAX < rate / RATE_DENOMINATOR`, cross-multiplied so both sides stay integers.
static func _under(numerator: int, rate: int) -> bool:
	return numerator * RATE_DENOMINATOR < rate * PLANE_MAX


## A stable scramble of one plane index, 0..PLANE_MAX. RNG-free and stable across loads, so a world's
## grain is a property of its seed alone. Returns the raw hash slice; the float division the legacy
## version ended with is gone, and `_under` carries the comparison instead.
static func _plane(index: int, salt: int) -> int:
	var h: int = (index * 374761393) ^ (salt * 668265263)
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0xffff
