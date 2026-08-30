class_name HollowTell
extends RefCounted

## "Is there a void behind this rock?" -- the reading that lets mining tell a player what they are about to
## break into, before they break into it. Re-derived from `legacy/scenes/main.gd::_hollow_at` (lines
## 1638-1652), Slice 1, `docs/DECISIONS_LEDGER.md` D0196.
##
## Pure query. Reads `TileGrid.is_solid` and writes nothing, contains no RNG and no float, so it is legal
## in `sim/` even though every consumer of it -- sound pitch, draught particles, a reticle -- is view-only
## and nondeterministic. That split is legacy's own: the reading is deterministic enough for its test suite
## to assert exact numeric floors on it, and only its presentation is not.
##
## READ AT THE LOGIC TILE, NEVER AT THE TERRAIN CELL. Legacy probes 4 cells deep by 5 wide = 20 samples at
## its 32px cell. This world's terrain cell is 4px, so probing the same PHYSICAL box cell-by-cell would be
## 32x33 = 1056 samples per blow -- not a rescale, a rewrite. The probe therefore walks 16px logic tiles
## (one metre, the same physical unit legacy's 32px cell was), which restores the sample count to exactly
## 20 and the physical reach to the same 4 metres. A logic tile's solidity is its centre terrain cell.

const CELL_PX: int = Heightfield.TERRAIN_CELL_PX      ## 4
const LOGIC_TILE_PX: int = Body.LOGIC_TILE_PX          ## 16
const CELLS_PER_TILE: int = LOGIC_TILE_PX / CELL_PX    ## 4

const REACH: int = 4   ## logic tiles ahead the reading looks -- legacy TELL_REACH, same 4 metres
const SPREAD: int = 2  ## and how far to either side of the swing line -- legacy TELL_SPREAD

## Legacy's weights are floats: `near(d) = 1 - (d-1)/REACH` and `lateral(o) = 1 - |o|/(SPREAD+1)`, combined
## multiplicatively. Both are exact rationals, so they are carried here as integers scaled by their own
## denominators -- `near` by REACH, `lateral` by SPREAD+1 -- which makes the whole accumulation exact and
## the ratio `acc/total` identical to legacy's, since a common factor cancels.
##
##   near(d),   d = 1..4  ->  4, 3, 2, 1        (a void one tile in is worth four far out)
##   lateral(o), o = -2..2 ->  1, 2, 3, 2, 1
##
## TOTAL is DERIVED, not written down. Legacy hardcodes nothing but does accumulate `total` inside the probe
## loop unconditionally, which makes it a compile-time constant it never names: `(REACH+1)(SPREAD+1)/2`,
## i.e. 7.5 there. The same closed form here, in these integer units, is
## `(sum of near) * (sum of lateral)` = 10 * 9 = 90 -- and 90 / (REACH * (SPREAD+1)) = 90/12 = 7.5, the
## identical figure. Changing REACH or SPREAD recomputes it; nothing needs re-tuning by hand.
const TOTAL_WEIGHT: int = (REACH * (REACH + 1) / 2) * ((SPREAD + 1) * (SPREAD + 1))

## Legacy's hand-tuned `1.6` gain, as a rational. Its effect is that the reading saturates at 1.0 once the
## open-weight fraction reaches 0.625 rather than 1.0 -- a partly-open box already reads as fully hollow.
const GAIN_NUM: int = 16
const GAIN_DEN: int = 10

const FULL: int = 1000  ## the reading is per mille: 0 is solid to the horizon, 1000 is a void right behind
const RING: int = 120   ## above this the blow rings -- legacy's bare `0.12` literal at main.gd:1602
const BREACH: int = 450 ## above this a break counts as opening a space -- legacy's `BREACH_TELL`


## The reading behind `cell` when struck along `dir`, per mille, clamped to [0, FULL].
##
## OUT OF BOUNDS COUNTS AS SOLID HERE, AND THAT IS A DELIBERATE DIVERGENCE. Legacy counts an
## out-of-bounds probe as hollow (`not sim.in_bounds(probe) or not sim.is_solid(probe)`), which on its
## 128-cell-wide world put a false-void rim on about 3% of the map. This world's reveal sites are 48
## terrain cells wide -- **12 logic tiles** -- against a probe that reaches 4 tiles and spreads 2. Carrying
## legacy's convention would make a third of the world's width permanently read as cavity, so the tell
## would be loudest exactly where there is nothing to find. The world's edge is the edge of the world, not
## a hole in it.
static func read(grid: TileGrid, cell: Vector2i, dir: Vector2i) -> int:
	# The perpendicular. Legacy writes `Vector2i(dir.y, dir.x)`, which is the coordinate SWAP rather than a
	# true perpendicular `(-dir.y, dir.x)`; carried as-is because `o` runs symmetrically about zero, so the
	# two differ only in which side is scanned first and never in the result. Legacy's own comment calls it
	# a perpendicular, which it is not.
	var side: Vector2i = Vector2i(dir.y, dir.x)
	var origin: Vector2i = to_tile(cell)
	var acc: int = 0
	for d: int in range(1, REACH + 1):
		var near: int = REACH - d + 1
		for o: int in range(-SPREAD, SPREAD + 1):
			var lateral: int = SPREAD + 1 - absi(o)
			var probe: Vector2i = origin + dir * d + side * o
			if not _tile_solid(grid, probe):
				acc += near * lateral
	return mini(FULL, (acc * FULL * GAIN_NUM) / (TOTAL_WEIGHT * GAIN_DEN))


## The logic tile a terrain cell belongs to. Integer floor division, negative-safe: GDScript's `/` truncates
## toward zero, so cell -1 would land in tile 0 alongside cell 0 without the guard.
static func to_tile(cell: Vector2i) -> Vector2i:
	return Vector2i(_floor_div(cell.x, CELLS_PER_TILE), _floor_div(cell.y, CELLS_PER_TILE))


## A logic tile is solid if its centre terrain cell is. One sample rather than sixteen: the tell is a coarse
## "is there space back there" reading, not a coverage measurement, and sixteen samples per tile would put
## the probe count straight back where re-deriving it at tile granularity was meant to avoid.
static func _tile_solid(grid: TileGrid, tile: Vector2i) -> bool:
	var centre: Vector2i = Vector2i(
		tile.x * CELLS_PER_TILE + CELLS_PER_TILE / 2,
		tile.y * CELLS_PER_TILE + CELLS_PER_TILE / 2)
	if not grid.in_bounds(centre):
		return true  # see `read`'s own note: the world's edge is not a cavity
	return grid.is_solid(centre)


static func _floor_div(a: int, b: int) -> int:
	return (a / b) if a >= 0 else -(((-a) + b - 1) / b)
