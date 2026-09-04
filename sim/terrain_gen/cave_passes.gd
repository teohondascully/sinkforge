class_name CavePasses
extends RefCounted

## THE TWO CARVE PASSES D0017 LEFT BEHIND. Ported from
## `legacy/src/core/layered_world_gen.gd:372-403` (`_carve_big_caverns`), `405-437` (`_carve_tunnels`,
## `_carve_disc`). `docs/NEEDS_DIRECTOR.md` P021, director-ruled: *"it's a PORTING item, not a threshold
## move — the real gap is unported work."*
##
## D0017 scoped the generator to "strata banding, cave carving, and ore/coal/iron vein scattering only"
## and named big caverns and tunnels among the passes it did not carry, as "artifacts of the pre-pivot
## progression-gated structure". That reading held for rifts, sinkholes and the seal; it does not hold
## for these two, and P021's measurement is what showed it. Our carve rate is **correct** — 0.0400
## against Godot's own `FastNoiseLite` at 0.0428, a ratio of 0.935 — so the thinness of this world's
## caves was never a threshold. Legacy simply carves three times and we carved once.
##
## **A CORRECTION TO THE RULING'S WORDING, recorded rather than silently applied.** The ruling says
## "caves + ruins + shelf undercut bias". Ruins are already ported (`ShaftGenerator._place_ruins`) and
## P021 measured their contribution at 0.0010 of total void. The two passes actually missing are the two
## here. The shelf undercut bias is the third item and lands in `ShaftGenerator._carve_caves`, where it
## belongs, rather than in this file.
##
## **WHAT EACH IS FOR**, in legacy's words. Big caverns: "large cohesive chambers deep in the rock: wide
## ellipses, vertically squashed, with a solid floor shelf below the centre". Tunnels: "worms random-walk
## through the rock with a horizontal bias, **threading the isolated noise pockets into one connected
## system**". The second is the one that changes what the world IS — noise alone gives disconnected
## pockets, and a pocket you cannot walk into is scenery.
##
## **NO `cos`, NO `sin`, AND THAT IS A DETERMINISM REQUIREMENT RATHER THAN A STYLE.** Legacy's worm
## carries a float `angle` and steps by `cos(angle)`/`sin(angle)*0.55`. Godot's `cos` is the platform's
## libm, so two machines can differ in the last bit — and `docs/DECISIONS_LEDGER.md` D0167 pins this
## generator's output as golden hashes captured on CI Linux while development happens on macOS. One
## flipped rounding in one worm is a different world. The heading is an INDEX into a table of sixteen
## fixed-point directions instead, and the table is written out as literals rather than computed at
## startup, so no transcendental is evaluated at any point in world generation.

## Legacy's `_density_count` calibration row, but denominated in METRES rather than in cells.
##
## Legacy calibrated its `*_PER_COL` rates against an 80-row world whose cell is one metre. This world's
## cell is a quarter of a metre, so the same physical volume holds SIXTEEN times the cells — driving
## legacy's rate off our cell counts would put sixteen halls where legacy put one. Deriving from metres
## makes that impossible to get wrong here, and means these two passes are unaffected by
## `docs/LEGACY_GAP.md` WG-4 either way: they never touch `ShaftGenerator.DENSITY_ROWS` or a
## `*_per_col` value, both of which WG-4 converts.
const LEGACY_DENSITY_ROWS_M: int = 80

## `legacy/src/core/layered_world_gen.gd:71-76`. Rates are per legacy column (one metre) and stay as
## they are; the RADII are legacy CELLS and become metres, which is the same conversion read the other
## way round.
const CAVERN_PER_M_COL: float = 0.035
const CAVERN_RX_MIN_M: int = 6
const CAVERN_RX_MAX_M: int = 9
const CAVERN_RY_MIN_M: int = 3
const CAVERN_RY_MAX_M: int = 5

## How far above the deep-rock boundary the chambers start, and how far off the world's floor they stop.
## Legacy's band is `DEEPSLATE_ROW - 18 .. SEAL_TOP - 3`; there is no seal here, so the top of the band
## keeps its 18 m offset from the boundary where deep rock begins (this build's `stonereach_end`, which
## is the same idea under a different name) and the bottom becomes the world's own floor.
const CAVERN_ABOVE_DEEP_M: int = 18
const CAVERN_FLOOR_MARGIN_M: int = 3

## `legacy/src/core/layered_world_gen.gd:80-84`. Lengths and the radius are legacy cells -> metres.
const TUNNEL_PER_M_COL: float = 0.07
const TUNNEL_MIN_LEN_M: int = 18
const TUNNEL_MAX_LEN_M: int = 46
const TUNNEL_RADIUS_M: int = 1

## THE HEADING TABLE. Sixteen directions, 22.5 degrees apart, in `Fx`-style fixed point — `dx` is
## `cos(a)` and `dy` is `sin(a) * 0.55`, legacy's horizontal bias folded in so the walk carries it
## without a second multiply. Written out rather than computed, per the header: nothing in world
## generation may evaluate a transcendental.
const DIR_SCALE: int = 65536
const DIRS: Array[Vector2i] = [
	Vector2i(65536, 0), Vector2i(60547, 13794), Vector2i(46341, 25488), Vector2i(25080, 33301),
	Vector2i(0, 36045), Vector2i(-25080, 33301), Vector2i(-46341, 25488), Vector2i(-60547, 13794),
	Vector2i(-65536, 0), Vector2i(-60547, -13794), Vector2i(-46341, -25488), Vector2i(-25080, -33301),
	Vector2i(0, -36045), Vector2i(25080, -33301), Vector2i(46341, -25488), Vector2i(60547, -13794),
]
## Legacy wanders by `randf_range(-0.5, 0.5)` radians per step, which is +/-28.6 degrees. One table step
## is 22.5, so +/-1 is the nearest analogue and it is deliberately the gentler of the two available
## roundings: a worm that turns harder than legacy's coils back on itself and stops connecting anything.
const WANDER_STEPS: int = 1


## Legacy's `_density_count`, in metres. See `LEGACY_DENSITY_ROWS_M`.
static func count_for(width_cells: int, height_cells: int, per_m_col: float, cells_per_m: int) -> int:
	if cells_per_m <= 0:
		return 0
	var cols_m: float = float(width_cells) / float(cells_per_m)
	var rows_m: float = float(height_cells) / float(cells_per_m)
	return int(round(cols_m * per_m_col * rows_m / float(LEGACY_DENSITY_ROWS_M)))


## WIDE HALLS DEEP IN THE ROCK. A squashed ellipse with its bottom third left solid, so a chamber has a
## flat floor to stand on rather than being a lens you slide through — legacy's own note, and the reason
## `floor_cut` exists.
static func carve_big_caverns(grid: TileGrid, rng: SplitRng, deep_row: int, floors: PackedInt32Array,
		cells_per_m: int) -> int:
	var count: int = maxi(2, count_for(grid.width, grid.height, CAVERN_PER_M_COL, cells_per_m))
	var above_deep: int = deep_row - CAVERN_ABOVE_DEEP_M * cells_per_m
	var hi: int = grid.height - CAVERN_FLOOR_MARGIN_M * cells_per_m
	if hi <= maxi(lowest(floors), above_deep):
		return 0
	var carved: int = 0
	for _c: int in count:
		var cx: int = rng.next_range(4, maxi(4, grid.width - 5))
		# The column's own floor (A' step 8b, D0382): under a hill the band starts higher, under a valley
		# lower. With one floor for every column this is the scalar it was, draw for draw.
		var lo: int = maxi(floors[cx], above_deep)
		if hi <= lo:
			continue
		var cy: int = rng.next_range(lo, hi)
		var rx: int = rng.next_range(CAVERN_RX_MIN_M, CAVERN_RX_MAX_M) * cells_per_m
		var ry: int = rng.next_range(CAVERN_RY_MIN_M, CAVERN_RY_MAX_M) * cells_per_m
		# The bottom of the ellipse stays solid. `ry - 1` in legacy cells is a whole metre of floor here,
		# which is the same shelf at this build's resolution rather than a quarter of one.
		var floor_cut: int = maxi(1, ry - cells_per_m)
		for dy: int in range(-ry, ry + 1):
			if dy > floor_cut:
				continue
			for dx: int in range(-rx, rx + 1):
				# The ellipse test in integers: `(dx/rx)^2 + (dy/ry)^2 > 1` multiplied out, so a hall's
				# shape does not depend on float rounding the goldens would have to reproduce.
				if dx * dx * ry * ry + dy * dy * rx * rx > rx * rx * ry * ry:
					continue
				carved += _open(grid, Vector2i(cx + dx, cy + dy), floors)
	return carved


## THE WORMS. Legacy's own reason, which is the whole point of the pass: noise carving alone leaves
## isolated pockets, and these thread them into one connected system.
static func carve_tunnels(grid: TileGrid, rng: SplitRng, floors: PackedInt32Array, cells_per_m: int) -> int:
	var worms: int = maxi(3, count_for(grid.width, grid.height, TUNNEL_PER_M_COL, cells_per_m))
	var radius: int = TUNNEL_RADIUS_M * cells_per_m
	var head_room: int = 2 * cells_per_m
	if lowest(floors) + head_room >= grid.height - 2:
		return 0
	var carved: int = 0
	for _w: int in worms:
		# Position carried in fixed point, exactly as legacy carries it in floats: a worm that rounded to
		# whole cells each step could not have a heading between two of them and would walk in staircases.
		var x: int = rng.next_range(2, maxi(2, grid.width - 3)) * DIR_SCALE
		var start_depth: int = floors[x / DIR_SCALE] + head_room
		if start_depth >= grid.height - 2:
			continue
		var y: int = rng.next_range(start_depth, grid.height - 2) * DIR_SCALE
		var heading: int = rng.next_range(0, DIRS.size() - 1)
		var length: int = rng.next_range(TUNNEL_MIN_LEN_M, TUNNEL_MAX_LEN_M) * cells_per_m
		for _s: int in length:
			carved += _carve_disc(grid, Vector2i(x / DIR_SCALE, y / DIR_SCALE), radius, floors)
			heading = posmod(heading + rng.next_range(-WANDER_STEPS, WANDER_STEPS), DIRS.size())
			var step: Vector2i = DIRS[heading]
			x += step.x
			y += step.y
			if x < DIR_SCALE or x >= (grid.width - 1) * DIR_SCALE or y >= (grid.height - 1) * DIR_SCALE:
				break
	return carved


## A disc of open air, block erased and wall kept. Legacy's `_carve_disc`, including its `+ 1` slack on
## the radius test, which is what stops a small disc reading as a diamond.
static func _carve_disc(grid: TileGrid, centre: Vector2i, radius: int, floors: PackedInt32Array) -> int:
	var carved: int = 0
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius + 1:
				continue
			carved += _open(grid, centre + Vector2i(dx, dy), floors)
	return carved


## Opens one cell if it is solid, in bounds and below the protected near-surface band. Returns 1 if it
## opened something, so every caller can report what it actually did rather than being trusted — a carve
## pass that silently carved nothing is the exact shape `tools/measure_void_fraction.gd` was written to
## catch (D0285).
## The shallowest floor across the width: the one-number pre-check a per-column floor still needs, so a
## world too short for a pass returns before it draws, exactly as the scalar did.
static func lowest(floors: PackedInt32Array) -> int:
	var out: int = 0x7FFFFFFF
	for f: int in floors:
		out = mini(out, f)
	return out


static func _open(grid: TileGrid, cell: Vector2i, floors: PackedInt32Array) -> int:
	if cell.x < 0 or cell.x >= grid.width or cell.y >= grid.height or cell.y < floors[cell.x]:
		return 0
	if not grid.is_solid(cell):
		return 0
	grid.excavate(cell)   ## block erased, wall kept -- a carved room, not a void
	return 1
