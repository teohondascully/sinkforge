class_name LayeredWorldGen
extends HeightmapWorldGen

## Adds CAVES (noise pockets, block erased and wall KEPT, only below CAVE_MIN_DEPTH) and DEPTH-BANDED
## ORE (blob veins, denser and bigger with depth) to HeightmapWorldGen's fill. Emits only existing
## material ids. Deterministic in (cols, rows, seed): one seeded RNG, one FastNoiseLite.

## Counted features ("N per column") were tuned against an 80-row world and are scaled against
## DENSITY_ROWS; per-CELL rolls (cave noise, spires, rubble) scale with area already.
const DENSITY_ROWS: int = 80         ## the world height every *_PER_COL figure below was tuned against


func _density_count(world: WorldData, per_col: float) -> int:
	return int(round(float(world.cols) * per_col * float(world.rows) / float(DENSITY_ROWS)))


# --- caves ---
## Caves never breach this many tiles below a column's surface (keeps the spawn base safe/solid).
const CAVE_MIN_DEPTH: int = 6
## Noise scale: smaller means larger, smoother pockets. ~0.10 gives room-sized caverns.
const CAVE_FREQ: float = 0.11
## Carve where noise exceeds this, easing toward CAVE_THRESHOLD_DEEP with depth. RAISED (#107): the old
## 0.40/0.12 opened ~31% of the underground into air; these keep it near 15%. PROGRESSION 10 /
## DESIGN_REVIEW F2.
const CAVE_THRESHOLD_TOP: float = 0.47
const CAVE_THRESHOLD_DEEP: float = 0.31
## X is compressed by this factor before sampling, so caverns come out wide and flat (#93).
const CAVE_XSTRETCH: float = 2.1
## Carve threshold eased this much just under a strata shelf and hardened just above one, so roofs hang
## from the hard bands and floors rest on them.
const CAVE_SHELF_BIAS: float = 0.10

# --- strata (horizontal rock banding, #93) ---
## Rows per band. Every few bands is a HARD SHELF (shale) that resists caving.
const STRATA_BAND_H: int = 4
## 1-in-N bands is a hard shelf. Deterministic per band index (a seeded hash), so the layering is stable.
const STRATA_SHELF_EVERY: int = 3
## Added to the carve threshold inside a shelf band, so it survives as a continuous ledge.
const STRATA_SHELF_RESIST: float = 0.34
## Below this ABSOLUTE row the strata banding stops (deepslate/seal/Stonereach own the deep look already).
const STRATA_MAX_ROW: int = DEEPSLATE_ROW

# --- big caverns (a few large cohesive chambers, #93) ---
## Chamber count is this x columns: wide flat-floored ellipses the tunnel worms thread. LOWERED (#107).
const CAVERN_PER_COL: float = 0.035
## Chamber half-extents (cells). Wide and shallow gives a flat floor rather than a ball.
const CAVERN_RX_MIN: int = 6
const CAVERN_RX_MAX: int = 9
const CAVERN_RY_MIN: int = 3
const CAVERN_RY_MAX: int = 5

# --- tunnels (winding caverns that connect the noise pockets into an explorable system) ---
## Worm count ≈ this × columns. Trimmed (#107) to connect the noise pockets without a tunnel maze.
const TUNNEL_PER_COL: float = 0.07
const TUNNEL_MIN_LEN: int = 18
const TUNNEL_MAX_LEN: int = 46
## Carve radius around the worm path (1 → ~3-wide walkable caverns).
const TUNNEL_RADIUS: int = 1

## --- VERTICAL STRUCTURE (#S5) -------------------------------------------------------------------------
## A RIFT is a narrow chasm falling THROUGH the layer stack, wandering as it goes. Budgeted against the
## dig-your-factory guard in tests/test_worldgen.gd, which caps open space at a quarter of everything
## below the surface; the first cut of these numbers reached 26.5% and tripped it. Re-cut for the
## 128-row world as rarer and longer at the same budget.
const RIFT_PER_COL: float = 0.018        ## ~4 rifts on this world — landmarks, not a feature grid
const RIFT_MIN_LEN: int = 34             ## rows; short of this it reads as a hole rather than a chasm
const RIFT_MAX_LEN: int = 80
const RIFT_HALF_W_MIN: float = 0.8       ## half-width in cells at the narrowest — a squeeze
const RIFT_HALF_W_MAX: float = 2.1       ## ...and at the widest — a rift PINCHES and OPENS as it falls
const RIFT_WANDER: float = 0.34          ## cells of horizontal drift per row (kept low: a rift is a fall line)
## A rift pays: ore in its wall upgrades to rich ore, plain rock sometimes becomes ore.
const RIFT_SPAWN_KEEPOUT: int = 10       ## columns either side of spawn no rift may start in
const RIFT_WALL_ORE_CHANCE: float = 0.11 ## plain rock in a rift wall that becomes ore
const RIFT_WALL_RICH_CHANCE: float = 0.55## ore already in a rift wall that upgrades to rich ore

## Shelves jutting into open space from a cavern's sides. Placed on the OPEN side of a solid wall.
const LEDGE_PER_COL: float = 0.22
const LEDGE_LEN_MIN: int = 2
const LEDGE_LEN_MAX: int = 4
const LEDGE_HEADROOM: int = 2            ## cells of clear air a shelf needs above it, or it is just fill

## Stalactites down from ceilings, stalagmites up from floors, one cell wide and tapering. Floor teeth
## are shorter: taller ones blocked the route down in two scripted play-test rungs.
const SPIRE_CHANCE: float = 0.075        ## per eligible ceiling cell
const SPIRE_FLOOR_BIAS: float = 0.34     ## × that chance for a floor cell — teeth belong on the roof
const SPIRE_HANG_MIN: int = 2            ## stalactite, growing DOWN from a ceiling
const SPIRE_HANG_MAX: int = 5
const SPIRE_RISE_MIN: int = 1            ## stalagmite, growing UP from a floor — steppable by construction
const SPIRE_RISE_MAX: int = 2

## RUBBLE: single loose blocks resting on cave floors.
const RUBBLE_CHANCE: float = 0.060

# --- ore ---
## Vein-seed attempts are this x columns, each kept by a depth-weighted roll. Nudged up (#107), but
## kept near 20% of solid rock.
const ORE_ATTEMPTS_PER_COL: float = 1.0
## A vein seed at the very bottom is accepted this often; at the surface, ~0. Linear in depth.
const ORE_CHANCE_DEEP: float = 0.85

## Acceptance floor. Without it tools/check_richness measured TOPSOIL at 1.2 encounters per hundred
## rows. At depth_frac 1 the floor drops out of the expression, so deep acceptance is unchanged.
const ORE_SHALLOW_FLOOR: float = 0.34
const COAL_SHALLOW_FLOOR: float = 0.42
## Vein BODY size (cells in the accretion blob), from this at the surface toward +BONUS at depth.
const ORE_SIZE_MIN: int = 8
const ORE_SIZE_DEPTH_BONUS: int = 44
## COAL veins, the drill's FUEL. Same cavity model as ore, slightly more common and shallower-reaching.
const COAL_ATTEMPTS_PER_COL: float = 0.8
const COAL_CHANCE_DEEP: float = 0.95
const COAL_SIZE_MIN: int = 6
const COAL_SIZE_DEPTH_BONUS: int = 30
const COAL_AMOUNT_BASE: int = 30         # modest PER-CELL (the drill bores cell by cell); big BODIES give the
const COAL_AMOUNT_DEPTH_BONUS: int = 170 # long-lasting TOTAL (hundreds shallow → thousands deep per body)
## Per-CELL ore deposit, kept MODEST: the Drill drains a cell then sinks to the next. Lasting supply
## is the multi-cell BODY (ORE_SIZE_*): cells x per-cell, hundreds shallow and thousands deep.
const ORE_AMOUNT_BASE: int = 30
const ORE_AMOUNT_DEPTH_BONUS: int = 170
## Vein seeds in or below the deepslate band roll this often into RICH ORE (#48), which the Blast
## Furnace smelts 1 -> 2 ingots and which carries more per-cell deposit.
const RICH_CHANCE: float = 0.45
const RICH_AMOUNT_MULT: float = 1.5

# --- HORIZONTAL richness (the FRONTIER pull) ---
## A deterministic per-column multiplier centred on 1.0 that varies ore across X at a fixed depth, so
## richer zones fan out AWAY from spawn: a low-frequency FastNoiseLite band mixed with a
## distance-from-spawn ramp. Multiplies into vein ACCEPTANCE, blob SIZE and per-cell RICHNESS, clamped
## to [1 - HORIZONTAL_STRENGTH, 1 + HORIZONTAL_STRENGTH] and stacked on the depth term. STRENGTH 0.0
## restores the depth-only world, FREQ sets band width, FRONTIER_BIAS tilts between distance and pure
## noise (1.0 = all distance). Seeded off the world seed plus an offset, uncorrelated with the caves.
const HORIZONTAL_STRENGTH: float = 0.55
const HORIZONTAL_FREQ: float = 0.045
const FRONTIER_BIAS: float = 0.5
## Column the distance ramp measures from. Near it the ramp contributes ~0, the map edges ~+1.
const SPAWN_COL: int = (FLAT_START + FLAT_END) / 2


## Below this ABSOLUTE row a third band turns to deepslate. Earth to stone happens in the base.
const DEEPSLATE_ROW: int = 76

## THE SEAL, the L1->L2 gate (docs/PROGRESSION.md 2/9): an UNBROKEN full-width band of unmineable
## sealrock, stamped LAST so no cave, tunnel or vein can hole it. Rows DEEPSLATE_ROW..SEAL_TOP-1 stay
## a mineable deepslate SHELF where deepslate is sampled for Descent research. Below is STONEREACH
## (L2), reachable only by feeding a Descent Engine its throughput quota.
const SEAL_TOP: int = 84
const SEAL_ROWS: int = 2

## IRON, L2's signature material and the analyze-sample for the next tier, seeded ONLY below the seal.
const IRON_ATTEMPTS_PER_COL: float = 0.5
const IRON_SIZE_MIN: int = 10
const IRON_SIZE_DEPTH_BONUS: int = 30
const IRON_AMOUNT: int = 220

# --- LODES: ore in the WALL plane rather than the terrain ---
## Terrain is the carved plane, the lode the extracted one (`docs/LODE.md`). Every pass above stamps ore
## as a SOLID BLOCK; these bodies go into the background plane behind rock that stays solid, for the Head,
## the Spur, the Borer and the Drift Rig to draw from. ADDITIVE: the cutover that converts the ore blocks
## and deletes the solid-ore path is `docs/LODE_PLAN.md` phase 3, so every richness assertion above keeps
## its meaning. `WorldRenderer` already stains a buried lode through rock and draws an exposed one off
## `sim.lode`; that the stain code RUNS here holds, whether it is VISIBLE in play is unverified
## (`LODE_PLAN.md` 5).
const LODE_ATTEMPTS_PER_COL: float = 0.35
const LODE_SIZE_MIN: int = 6
const LODE_SIZE_DEPTH_BONUS: int = 12
const LODE_AMOUNT_BASE: int = 40
const LODE_AMOUNT_DEPTH_BONUS: int = 170
## Lode keepout below a column's generated ground, so it follows the relief rather than cutting flat.
const LODE_MIN_DEPTH: int = 14

# --- aquifers (the L3 water pockets a dig breaks into) ---
## Sealed pressurised water pockets carved into SOLID rock (block erased, wall KEPT) and filled to
## WATER_MAX, so digging in releases them. Never within CAVE_MIN_DEPTH of a column's surface, centre
## at or below AQUIFER_MIN_ROW, never spliced into the cave/tunnel system. Stamped LAST, after the
## seal; a blob cell landing in the seal band or any non-solid cell is skipped.
const AQUIFER_PER_COL: float = 0.045       # pocket count ≈ this × cols (a handful, like the big caverns)
const AQUIFER_MIN_ROW: int = DEEPSLATE_ROW + 2   # centres live in/below the deep deepslate + Stonereach band
const AQUIFER_RX_MIN: int = 2
const AQUIFER_RX_MAX: int = 4
const AQUIFER_RY_MIN: int = 2
const AQUIFER_RY_MAX: int = 3

# --- aquifer TREASURE (L3 risk/REWARD): the flood GUARDS a rich vein ---
## A modest &"rich_ore" vein in the SOLID rock lining each pocket, so draining and mining the walls
## pays out. Seeded from a solid RIM cell, so _grow_vein bores INTO the surrounding rock.
const AQUIFER_ORE_SIZE_MIN: int = 5
const AQUIFER_ORE_SIZE_MAX: int = 9
## Per-cell deposit: the deep-band ore baseline (ORE_AMOUNT_BASE + full-depth bonus) x the rich multiplier.
const AQUIFER_ORE_RICHNESS: int = int((ORE_AMOUNT_BASE + ORE_AMOUNT_DEPTH_BONUS) * RICH_AMOUNT_MULT)

# --- surface trees (the wood source the bazaar is gathered for) ---
## Plant chance per eligible column, and minimum columns between trunks so canopies read as separate trees.
const TREE_CHANCE: float = 0.20
const TREE_GAP: int = 3

## The abandoned Bazaar RUIN: a wood frame that activates when its one missing block is placed. Sits at
## the LEFT endpoint of the centred plateau (cols 40-43) with the missing post bottom-RIGHT, so it is
## claimed from the SPAWN side (col 44) and completing it never walls the body off from the shaft.
const RUIN_X: int = 40


func generate(cols: int, rows: int, seed: int) -> WorldData:
	# Start from the heightmap base (surface + earth/stone blocks + matching walls), then enrich.
	var world: WorldData = super.generate(cols, rows, seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Per-column horizontal richness multiplier, built once and reused by ore and coal.
	var hfield: PackedFloat32Array = _horizontal_field(cols, seed)
	_band_strata(world)          # STRATA: stack hard shelf bands (shale) through the mid rock (#93)
	_band_deepslate(world)
	_carve_caves(world, seed)    # anisotropic + shelf-aware → wide flat caverns, overhangs, ledges (#93)
	_carve_big_caverns(world, rng)   # a few large cohesive chambers the tunnels thread together (#93)
	_carve_tunnels(world, rng)
	_scatter_veins(world, rng, hfield)
	_scatter_coal(world, rng, hfield)
	_scatter_iron(world, rng)
	# THE VERTICAL PASSES (#S5) run AFTER the ore, load-bearing both ways: a rift cut through finished rock
	# slices veins so its walls show ore, and the horizontal richness field is computed on unperturbed rock.
	var rift_cells: Array[Vector2i] = _carve_rifts(world, rng)
	_mineralize(world, rng, rift_cells)                # RIFTS: vertical space — and the reason to go to one
	_open_sinkholes(world, rng, rift_cells)            # ...and the reason it is not sealed under a lid
	_stud_ledges(world, rng)     # then put rock BACK: shelves, spires and rubble, so open space has form
	_stud_spires(world, rng)
	_scatter_rubble(world, rng)
	# LAST pass over the rock, judging what every earlier pass left behind: no column may run dry.
	_seed_droughts(world, rng)
	_plant_trees(world, rng)
	_stamp_bazaar_ruin(world)
	_stamp_seal(world)          # LAST solid pass: the gate band overwrites everything, so nothing can hole it
	_seed_aquifers(world, rng)  # AFTER the seal — carves + fills water into solid rock; no later pass touches it
	# DEAD LAST: every lode guard tests the FINAL world, and the seal overwrites blocks wholesale while the
	# aquifers carve rock away and flood it.
	_seed_lodes(world, rng, hfield)
	return world


## Per-column richness multiplier (see HORIZONTAL_STRENGTH). Deterministic in (cols, seed): a seeded
## low-frequency noise band mixed with a distance ramp, normalised to [0,1], mapped into [1-S, 1+S].
func _horizontal_field(cols: int, seed: int) -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = seed + 91_331               # offset so the richness band doesn't correlate with the caves
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = HORIZONTAL_FREQ
	# Farthest any column sits from spawn, normalising the distance ramp so an edge column reaches ~1.
	var max_dist: float = float(maxi(1, maxi(SPAWN_COL, cols - 1 - SPAWN_COL)))
	var field := PackedFloat32Array()
	field.resize(cols)
	for col: int in cols:
		# (a) organic noise band in [0,1]; (b) distance-from-spawn ramp in [0,1] (0 at spawn, 1 at the edge).
		var band: float = (noise.get_noise_2d(float(col), 0.0) + 1.0) * 0.5
		var ramp: float = float(abs(col - SPAWN_COL)) / max_dist
		var mix: float = lerpf(band, ramp, FRONTIER_BIAS)   # tilt toward the frontier ramp per FRONTIER_BIAS
		# Map the [0,1] mix onto a symmetric multiplier around 1.0, bounded by STRENGTH (keeps it subtle).
		field[col] = 1.0 + (mix * 2.0 - 1.0) * HORIZONTAL_STRENGTH
	return field


## Convert the deep band (rows >= DEEPSLATE_ROW) of stone to deepslate in both grids. Veins overlay after.
func _band_deepslate(world: WorldData) -> void:
	for cell: Vector2i in world.blocks:
		if cell.y >= DEEPSLATE_ROW and world.blocks[cell] == &"stone":
			world.blocks[cell] = &"deepslate"
	for cell: Vector2i in world.walls:
		if cell.y >= DEEPSLATE_ROW and world.walls[cell] == &"stone_wall":
			world.walls[cell] = &"deepslate_wall"


## Is the band containing `row` a hard shelf band? Deterministic and seed-independent, so shelves stack
## at the same depths in every world. False outside the strata zone (surface fill to STRATA_MAX_ROW).
##
## Exactly one band in every STRATA_SHELF_EVERY is a shelf by arithmetic, and the hash chooses WHICH one
## inside each group rather than whether a shelf happens at all. Both bounds are tight and attained: at
## most 2 shelf bands touch, and at most 2 * (STRATA_SHELF_EVERY - 1) bands separate two of them. On the
## shipping constants that is 6 shelf bands of 19, at rows 0-3, 16-19, 28-31, 36-39, 52-55 and 64-67.
func _is_shelf_band(row: int) -> bool:
	if row >= STRATA_MAX_ROW:
		return false
	var band: int = row / STRATA_BAND_H
	return band % STRATA_SHELF_EVERY == _band_hash(band / STRATA_SHELF_EVERY) % STRATA_SHELF_EVERY


## Scatter a band-group index. The fold-back is the whole function: multiply, xor down, multiply, xor
## down. A bare `(i * K) >> s` reads a multiplicative step off bits the index still occupies, which
## yields an arithmetic progression rather than a scatter, and every modulus taken off it is another view
## of that one progression. The previous form here reduced exactly to `(band / 8) % 3`, which put every
## shelf in rows 0..31 and left rows 32..75 with no strata at all.
##
## Kept local rather than shared with the equivalent mixer in scenes/sky_painter.gd: that one is on the
## representation side of the seam, and src/ does not depend on scenes/.
static func _band_hash(group: int) -> int:
	var h: int = (((group & 0xFFFF) + 1) * 2654435761) & 0xFFFFFFFF
	h = (h ^ (h >> 15)) & 0xFFFFFFFF
	h = (h * 0x2545F491) & 0xFFFFFFFF
	return h >> 16


## Turn the HARD SHELF bands into &"shale", a cave-resistant rock, in BOTH grids. Runs BEFORE veins and
## caves and only converts solid earth/stone, so it never fills a cave or overwrites ore.
func _band_strata(world: WorldData) -> void:
	for cell: Vector2i in world.blocks:
		if cell.y >= STRATA_MAX_ROW:
			continue
		if not _is_shelf_band(cell.y):
			continue
		# Only band the STONE zone: the earth surface layer is left alone so strata start below ground.
		if world.blocks[cell] == &"stone":
			world.blocks[cell] = &"shale"
			if world.walls.get(cell, &"") == &"stone_wall":
				world.walls[cell] = &"shale_wall"


## Carve caves with seeded noise. A cell opens (block erased, WALL kept) when noise clears the
## depth-eased, strata-adjusted threshold, and never inside the base-safe band. Anisotropic and
## strata-aware (#93): X is compressed by CAVE_XSTRETCH; hard shelf bands add STRATA_SHELF_RESIST and
## survive as ledges; an asymmetric shelf bias undercuts a band and pools cave below it.
func _carve_caves(world: WorldData, seed: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = CAVE_FREQ
	for col: int in world.cols:
		var top: int = ground_row(col)
		var cave_start: int = top + CAVE_MIN_DEPTH
		for row: int in range(cave_start, world.rows):
			var cell: Vector2i = Vector2i(col, row)
			if not world.blocks.has(cell):
				continue
			var depth_frac: float = float(row - cave_start) / float(maxi(1, world.rows - cave_start))
			var threshold: float = lerpf(CAVE_THRESHOLD_TOP, CAVE_THRESHOLD_DEEP, depth_frac)
			# STRATA resistance: a hard shelf band is much harder to open (survives as a ledge/bridge).
			if _is_shelf_band(row):
				threshold += STRATA_SHELF_RESIST
			# OVERHANG bias: easier just under a shelf (undercut → overhang), harder just above one (roof pools).
			elif _is_shelf_band(row - 1):
				threshold -= CAVE_SHELF_BIAS
			elif _is_shelf_band(row + 1):
				threshold += CAVE_SHELF_BIAS
			# Anisotropy: compress X so features span more columns than rows → wide, flat caverns.
			if noise.get_noise_2d(float(col) / CAVE_XSTRETCH, float(row)) > threshold:
				world.blocks.erase(cell)        # open air; the wall behind it stays (carved room)


## Large cohesive chambers deep in the rock (#93): wide ellipses vertically squashed, with a solid floor
## shelf below the centre. Wall kept, never breaches the base-safe band, only opens solid rock.
func _carve_big_caverns(world: WorldData, rng: RandomNumberGenerator) -> void:
	var count: int = maxi(2, _density_count(world, CAVERN_PER_COL))
	# Chambers live in the deep-but-above-seal band, so they read as halls on Stonereach's approach.
	var lo_row: int = DEEPSLATE_ROW - 18
	var hi_row: int = SEAL_TOP - 3
	if hi_row <= lo_row:
		return
	for _c: int in count:
		var cx: int = rng.randi_range(4, world.cols - 5)
		var cy: int = rng.randi_range(lo_row, hi_row)
		var rx: int = rng.randi_range(CAVERN_RX_MIN, CAVERN_RX_MAX)
		var ry: int = rng.randi_range(CAVERN_RY_MIN, CAVERN_RY_MAX)
		# Keep the bottom ~third of the ellipse SOLID, giving a flat floor shelf to stand on.
		var floor_cut: int = maxi(1, ry - 1)
		for dy: int in range(-ry, ry + 1):
			for dx: int in range(-rx, rx + 1):
				if dy > floor_cut:
					continue                                  # leave a flat floor below the centre
				var ex: float = float(dx) / float(rx)
				var ey: float = float(dy) / float(ry)
				if ex * ex + ey * ey > 1.0:
					continue
				var cell := Vector2i(cx + dx, cy + dy)
				if not world.in_bounds(cell):
					continue
				if cell.y < ground_row(cell.x) + CAVE_MIN_DEPTH:
					continue                                  # protect the near-surface base
				if world.blocks.has(cell):
					world.blocks.erase(cell)                  # open; wall kept (carved room)


## Worms random-walk through the rock with a horizontal bias, threading the isolated noise pockets
## into one connected system. Each keeps its wall and never rises into the base-safe band.
func _carve_tunnels(world: WorldData, rng: RandomNumberGenerator) -> void:
	var worms: int = maxi(3, _density_count(world, TUNNEL_PER_COL))
	for _w: int in worms:
		var x: float = float(rng.randi_range(2, world.cols - 3))
		var min_row: int = ground_row(int(x)) + CAVE_MIN_DEPTH + 2
		if min_row >= world.rows - 2:
			continue
		var y: float = float(rng.randi_range(min_row, world.rows - 2))
		var angle: float = rng.randf_range(-PI, PI)
		var length: int = rng.randi_range(TUNNEL_MIN_LEN, TUNNEL_MAX_LEN)
		for _s: int in length:
			_carve_disc(world, Vector2i(int(round(x)), int(round(y))), TUNNEL_RADIUS)
			angle += rng.randf_range(-0.5, 0.5)         # gentle wander
			x += cos(angle)
			y += sin(angle) * 0.55                       # bias horizontal (flatten vertical drift)
			if x < 1.0 or x >= float(world.cols - 1) or y >= float(world.rows - 1):
				break


## Carve a disc of OPEN air (block erased, wall kept), refusing any cell in a column's base-safe band.
func _carve_disc(world: WorldData, center: Vector2i, radius: int) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius + 1:
				continue
			var cell: Vector2i = center + Vector2i(dx, dy)
			if not world.in_bounds(cell):
				continue
			if cell.y < ground_row(cell.x) + CAVE_MIN_DEPTH:
				continue                                 # protect the near-surface base
			if world.blocks.has(cell):
				world.blocks.erase(cell)


## A chasm walks DOWN from a start row, wandering slightly, its half-width breathing so it pinches and
## opens. Wall kept; refuses the base-safe band, so a rift can never open a chimney into the tutorial.
func _carve_rifts(world: WorldData, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var carved: Array[Vector2i] = []
	var count: int = maxi(2, _density_count(world, RIFT_PER_COL))
	for _r: int in count:
		var x: float = float(rng.randi_range(5, world.cols - 6))
		# Push a rift that rolled too near spawn out to whichever side it was already leaning toward.
		if absf(x - float(SPAWN_COL)) < float(RIFT_SPAWN_KEEPOUT):
			var away: float = 1.0 if x >= float(SPAWN_COL) else -1.0
			x = clampf(float(SPAWN_COL) + away * float(RIFT_SPAWN_KEEPOUT), 5.0, float(world.cols - 6))
		var top: int = ground_row(int(x)) + CAVE_MIN_DEPTH + rng.randi_range(2, 10)
		var length: int = rng.randi_range(RIFT_MIN_LEN, RIFT_MAX_LEN)
		var drift: float = rng.randf_range(-RIFT_WANDER, RIFT_WANDER)
		var phase: float = rng.randf_range(0.0, TAU)
		var pinch: float = rng.randf_range(0.16, 0.30)      # how fast the width breathes down the fall
		for i: int in length:
			var row: int = top + i
			if row >= world.rows - 2:
				break
			# Width breathes on a sine so the chasm reads as carved by something that varied, not extruded.
			var t: float = 0.5 + 0.5 * sin(phase + float(i) * pinch)
			var half: float = lerpf(RIFT_HALF_W_MIN, RIFT_HALF_W_MAX, t)
			var lo: int = int(floor(x - half))
			var hi: int = int(ceil(x + half))
			for col: int in range(lo, hi + 1):
				var cell := Vector2i(col, row)
				if not world.in_bounds(cell):
					continue
				if cell.y < ground_row(cell.x) + CAVE_MIN_DEPTH:
					continue
				world.blocks.erase(cell)
				world.routes[cell] = true          # deliberate vertical structure, not undirected cave
				carved.append(cell)
			x += drift
			drift = clampf(drift + rng.randf_range(-0.10, 0.10), -RIFT_WANDER, RIFT_WANDER)
			if x < 3.0 or x > float(world.cols - 4):
				break
	return carved


## SINKHOLES: the mouths that make the vertical structure reachable. Every carve elsewhere refuses the
## CAVE_MIN_DEPTH rows under a column's surface, which also seals the underground under an unbroken lid:
## tools/check_descent measured the whole connected open space reaching ONE row below the surface, with
## forty rows of chasm at column 24 in a sealed bottle. Cut UP from the top of a rift, flared toward the
## surface. Columns are ranked by the FALL underneath, the tallest unbroken open run below the rift
## ceiling; taking the leftmost rift column past the keepout instead opened a mouth over the tapering END
## of a chasm, and tools/check_plunge measured the body dropping twelve rows onto a shelf.
const SINKHOLE_COUNT: int = 3            ## mouths in a world — landmarks, and rare enough to stay landmarks
const SINKHOLE_MOUTH_HALF: float = 3.0   ## half-width where it meets the sky: wide enough to see from away
const SINKHOLE_THROAT_HALF: float = 1.1  ## ...and where it joins the rift below
const SINKHOLE_FLARE: float = 2.2        ## >1 keeps the throat narrow and opens the cone late (a collapse)
const SINKHOLE_KEEPOUT: int = 20         ## columns either side of spawn that stay sealed (the tutorial's ground)
const SINKHOLE_SPACING: int = 15         ## columns between mouths, so no two read as one broken region
const SINKHOLE_WANDER: float = 0.22      ## cells of drift per row — a throat, not a drainpipe
const SINKHOLE_MIN_DROP: int = 14        ## rows of fall under a mouth, below which it is a pit not a route

func _open_sinkholes(world: WorldData, rng: RandomNumberGenerator, rift_cells: Array[Vector2i]) -> void:
	# The highest open cell in each column the rifts carved: the ceiling that must be broken through.
	var tops: Dictionary = {}
	for c: Vector2i in rift_cells:
		if not tops.has(c.x) or c.y < int(tops[c.x]):
			tops[c.x] = c.y
	var cols: Array = tops.keys()
	cols.sort()

	# Rank by the fall underneath, deepest first, ties to the leftmost column so the pick stays deterministic.
	var ranked: Array[Vector2i] = []
	for col: Variant in cols:
		var cx: int = col
		if absi(cx - SPAWN_COL) < SINKHOLE_KEEPOUT:
			continue                                        # the tutorial's ground stays solid
		ranked.append(Vector2i(cx, _drop_below(world, cx, int(tops[cx]))))
	ranked.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y > b.y if a.y != b.y else a.x < b.x)

	var opened: Array[int] = []
	for cand: Vector2i in ranked:
		if opened.size() >= SINKHOLE_COUNT or cand.y < SINKHOLE_MIN_DROP:
			break                                           # nothing left worth opening onto
		var clear: bool = true
		for prev: int in opened:
			if absi(cand.x - prev) < SINKHOLE_SPACING:
				clear = false
		if not clear:
			continue
		opened.append(cand.x)
		_cut_throat(world, rng, cand.x, int(tops[cand.x]))


## How far a body stepping in here would FALL: the unbroken open run below the rift's ceiling.
func _drop_below(world: WorldData, col: int, ceiling: int) -> int:
	var run: int = 0
	for row: int in range(ceiling, world.rows):
		if world.blocks.has(Vector2i(col, row)):
			break
		run += 1
	return run


## Carve one flaring shaft from a rift's ceiling up through the lid to daylight.
func _cut_throat(world: WorldData, rng: RandomNumberGenerator, col: int, rift_top: int) -> void:
	var sky: int = ground_row(col)
	if rift_top <= sky + 2:
		return                                          # already open enough to be its own mouth
	var x: float = float(col)
	var drift: float = rng.randf_range(-SINKHOLE_WANDER, SINKHOLE_WANDER)
	for row: int in range(rift_top, sky - 1, -1):
		var up: float = 1.0 - float(row - sky) / float(maxi(1, rift_top - sky))   # 0 at the rift, 1 at the sky
		var half: float = lerpf(SINKHOLE_THROAT_HALF, SINKHOLE_MOUTH_HALF, pow(up, SINKHOLE_FLARE))
		for c: int in range(int(floor(x - half)), int(ceil(x + half)) + 1):
			var cell := Vector2i(c, row)
			if world.in_bounds(cell):
				world.blocks.erase(cell)                # deliberately past CAVE_MIN_DEPTH: this IS the mouth
				world.routes[cell] = true
		# THE FALL LINE stays plumb: a cone drifting off the column the drop is under puts the mouth in one
		# place and the fall in another. The source column is opened at every row regardless.
		var plumb := Vector2i(col, row)
		if world.in_bounds(plumb):
			world.blocks.erase(plumb)
			world.routes[plumb] = true
		x += drift
		drift = clampf(drift + rng.randf_range(-0.08, 0.08), -SINKHOLE_WANDER, SINKHOLE_WANDER)


## Enrich the solid rock touching the rift's carved cells. Runs on the carve's own cell list rather than
## rescanning, so it can only touch rift walls and never a cave that happens to sit beside one.
func _mineralize(world: WorldData, rng: RandomNumberGenerator, carved: Array[Vector2i]) -> void:
	var rich: int = int(round(float(ORE_AMOUNT_BASE + ORE_AMOUNT_DEPTH_BONUS) * RICH_AMOUNT_MULT))
	var touched: Dictionary = {}
	for c: Vector2i in carved:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var cell: Vector2i = c + d
			if touched.has(cell) or not world.in_bounds(cell):
				continue
			touched[cell] = true
			var here: StringName = world.blocks.get(cell, &"")
			if here == &"ore":
				# RICH ore stays a DEEP find: at twenty rows it would let a player skip the tier gate sideways.
				if cell.y >= DEEPSLATE_ROW and rng.randf() < RIFT_WALL_RICH_CHANCE:
					world.blocks[cell] = &"rich_ore"
					world.amounts[cell] = rich
			elif here == &"stone" or here == &"shale" or here == &"deepslate":
				if rng.randf() < RIFT_WALL_ORE_CHANCE:
					world.blocks[cell] = &"ore"
					world.amounts[cell] = ORE_AMOUNT_BASE + ORE_AMOUNT_DEPTH_BONUS


## Where an open cell sits against a solid side wall with air above, grow a short tongue of rock into
## the space. Sampled from a snapshot of the open set, so a ledge cannot seed another.
func _stud_ledges(world: WorldData, rng: RandomNumberGenerator) -> void:
	var sites: Array[Vector2i] = _open_cells(world)
	var wanted: int = _density_count(world, LEDGE_PER_COL)
	for _i: int in wanted:
		if sites.is_empty():
			return
		var c: Vector2i = sites[rng.randi_range(0, sites.size() - 1)]
		var dir: int = 0
		if world.blocks.has(c + Vector2i(-1, 0)):
			dir = 1                                   # wall on the left → the shelf grows right
		elif world.blocks.has(c + Vector2i(1, 0)):
			dir = -1
		if dir == 0:
			continue                                  # needs a wall to spring from
		var clear: bool = true
		for h: int in range(1, LEDGE_HEADROOM + 1):
			if world.blocks.has(c + Vector2i(0, -h)):
				clear = false
				break
		if not clear:
			continue                                  # a shelf you cannot stand on is just fill
		var mat: StringName = _structural_rock(world.blocks.get(c + Vector2i(-dir, 0), &"stone"))
		var run: int = rng.randi_range(LEDGE_LEN_MIN, LEDGE_LEN_MAX)
		for k: int in run:
			var cell: Vector2i = c + Vector2i(dir * k, 0)
			if not world.in_bounds(cell) or world.blocks.has(cell):
				break
			world.blocks[cell] = mat


## Hang teeth from ceilings and raise them from floors, tapering to a point. Each takes the material of
## the rock it grows out of.
func _stud_spires(world: WorldData, rng: RandomNumberGenerator) -> void:
	for c: Vector2i in _open_cells(world):
		var down: bool = world.blocks.has(c + Vector2i(0, -1))
		var up: bool = world.blocks.has(c + Vector2i(0, 1))
		if down == up:
			continue                                  # a 1-cell gap between two solids grows nothing
		var hang: bool = down                         # solid above → this tooth hangs from a ceiling
		if rng.randf() > SPIRE_CHANCE * (1.0 if hang else SPIRE_FLOOR_BIAS):
			continue
		var step: int = 1 if hang else -1
		var mat: StringName = _structural_rock(world.blocks.get(c + Vector2i(0, -step), &"stone"))
		var run: int = rng.randi_range(SPIRE_HANG_MIN, SPIRE_HANG_MAX) if hang \
			else rng.randi_range(SPIRE_RISE_MIN, SPIRE_RISE_MAX)
		for k: int in run:
			var cell: Vector2i = c + Vector2i(0, step * k)
			if not world.in_bounds(cell) or world.blocks.has(cell):
				break
			world.blocks[cell] = mat


## RUBBLE: a single loose block resting on a cave floor.
func _scatter_rubble(world: WorldData, rng: RandomNumberGenerator) -> void:
	for c: Vector2i in _open_cells(world):
		if not world.blocks.has(c + Vector2i(0, 1)):
			continue                                  # must be resting on something
		if world.blocks.has(c + Vector2i(0, -1)):
			continue                                  # ...with air above it, or it is just fill
		if rng.randf() > RUBBLE_CHANCE:
			continue
		world.blocks[c] = _structural_rock(world.blocks.get(c + Vector2i(0, 1), &"stone"))


## The material a structural block is built from. Ore, coal and iron are REWARDS, so structure is plain rock.
const _REWARD_ROCK: Array[StringName] = [&"ore", &"rich_ore", &"coal", &"iron"]


func _structural_rock(source: StringName) -> StringName:
	return &"stone" if source == &"" or _REWARD_ROCK.has(source) else source


## Every underground cell currently OPEN, in a deterministic scan order. Scans the grid rather than
## tracking carves, so it sees the union of every earlier pass and the studding passes stay byte-identical.
func _open_cells(world: WorldData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for col: int in world.cols:
		var top: int = ground_row(col) + CAVE_MIN_DEPTH
		for row: int in range(top, world.rows - 1):
			var cell := Vector2i(col, row)
			if not world.blocks.has(cell):
				out.append(cell)
	return out


## Depth band, floored: `floor` at the surface rising to 1.0 at the world bottom.
static func _banded(depth_frac: float, floor_frac: float) -> float:
	return floor_frac + (1.0 - floor_frac) * clampf(depth_frac, 0.0, 1.0)


## THE DROUGHT PASS. Flooring the depth ramp raises the AVERAGE, but a world can measure 7.5 encounters
## per hundred rows and still contain a shaft running thirty-five rows of identical rock. Wherever the
## rock has gone quiet for too long this plants a make-up vein, or a VUG, a cavity whose approach raises
## the pick's hollow ring. Reads the world it is writing, so fixing one column also fixes its neighbours.
const DROUGHT_LIMIT: int = 18            ## rows of unbroken plain rock before the generator owes you something
const DROUGHT_VUG_CHANCE: float = 0.28   ## ...and how often what it owes you is a cavity rather than a vein
const DROUGHT_VEIN_SIZE: int = 5
const DROUGHT_COAL_BIAS: float = 0.38    ## share of planted veins that are coal rather than ore
const PLAIN_ROCK: Array[StringName] = [&"earth", &"stone", &"shale", &"deepslate"]

func _seed_droughts(world: WorldData, rng: RandomNumberGenerator) -> void:
	for col: int in world.cols:
		var top: int = ground_row(col) + CAVE_MIN_DEPTH
		var run: int = 0
		for row: int in range(top, world.rows):
			if not _is_plain(world, Vector2i(col, row)):
				run = 0
				continue
			run += 1
			if run < DROUGHT_LIMIT:
				continue
			# Plant back INTO the run just walked, so the break lands in the middle of the quiet rather than
			# at the moment it was noticed.
			var at := Vector2i(col, row - rng.randi_range(3, DROUGHT_LIMIT - 4))
			if rng.randf() < DROUGHT_VUG_CHANCE:
				_carve_disc(world, at, 1)
			else:
				var span: int = maxi(1, world.rows - ground_row(col))
				var depth_frac: float = float(at.y - ground_row(col)) / float(span)
				var coal: bool = rng.randf() < DROUGHT_COAL_BIAS
				var base: int = COAL_AMOUNT_BASE if coal else ORE_AMOUNT_BASE
				var bonus: int = COAL_AMOUNT_DEPTH_BONUS if coal else ORE_AMOUNT_DEPTH_BONUS
				_grow_vein(world, rng, at, DROUGHT_VEIN_SIZE,
					base + int(round(depth_frac * float(bonus))), &"coal" if coal else &"ore")
			run = row - at.y


## Is this cell plain rock, i.e. solid and made of nothing worth stopping for?
func _is_plain(world: WorldData, cell: Vector2i) -> bool:
	return world.blocks.has(cell) and world.blocks[cell] in PLAIN_ROCK


## Depth-banded ore: many seed attempts, each kept by a depth-weighted roll, grown into a blob whose
## size also scales with depth. Only replaces SOLID rock, though a vein can end up exposed in a cave wall.
func _scatter_veins(world: WorldData, rng: RandomNumberGenerator, hfield: PackedFloat32Array) -> void:
	var attempts: int = _density_count(world, ORE_ATTEMPTS_PER_COL)
	for _i: int in attempts:
		var cx: int = rng.randi_range(0, world.cols - 1)
		var top: int = ground_row(cx)
		if top + 1 >= world.rows:
			continue
		var cy: int = rng.randi_range(top + 1, world.rows - 1)
		var depth_frac: float = float(cy - top) / float(maxi(1, world.rows - top))
		# A rich x-band lifts acceptance, size and deposit; a lean band drops them.
		var hmul: float = hfield[cx]
		if rng.randf() > _banded(depth_frac, ORE_SHALLOW_FLOOR) * ORE_CHANCE_DEEP * hmul:
			continue                            # rejected — shallow seeds still mostly die here (the band)
		var size: int = ORE_SIZE_MIN + int(round(depth_frac * float(ORE_SIZE_DEPTH_BONUS) * hmul))
		var richness: int = ORE_AMOUNT_BASE + int(round(depth_frac * float(ORE_AMOUNT_DEPTH_BONUS) * hmul))
		# A vein seeded in or below the deepslate band may come up RICH, smelting 1 -> 2 ingots.
		var material: StringName = &"ore"
		if cy >= DEEPSLATE_ROW and rng.randf() < RICH_CHANCE:
			material = &"rich_ore"
			richness = int(round(float(richness) * RICH_AMOUNT_MULT))
		_grow_vein(world, rng, Vector2i(cx, cy), size, richness, material)


## Depth-banded COAL. Same cavity machinery as ore veins with its own commonness, size and richness.
func _scatter_coal(world: WorldData, rng: RandomNumberGenerator, hfield: PackedFloat32Array) -> void:
	var attempts: int = _density_count(world, COAL_ATTEMPTS_PER_COL)
	for _i: int in attempts:
		var cx: int = rng.randi_range(0, world.cols - 1)
		var top: int = ground_row(cx)
		if top + 1 >= world.rows:
			continue
		var cy: int = rng.randi_range(top + 1, world.rows - 1)
		var depth_frac: float = float(cy - top) / float(maxi(1, world.rows - top))
		var hmul: float = hfield[cx]            # same frontier pull as ore (coal fans out too)
		if rng.randf() > _banded(depth_frac, COAL_SHALLOW_FLOOR) * COAL_CHANCE_DEEP * hmul:
			continue
		var size: int = COAL_SIZE_MIN + int(round(depth_frac * float(COAL_SIZE_DEPTH_BONUS) * hmul))
		var richness: int = COAL_AMOUNT_BASE + int(round(depth_frac * float(COAL_AMOUNT_DEPTH_BONUS) * hmul))
		_grow_vein(world, rng, Vector2i(cx, cy), size, richness, &"coal")


## Grow one vein as a compact ACCRETION BLOB rather than a thin random walk: repeatedly fill a random
## frontier cell and add its rock neighbours. Every converted cell carries the vein's depth-scaled
## `richness`, its finite per-cell deposit. `min_row` floors the blob: a body seeded just under the seal
## could otherwise climb through rows the seal stamp later re-fills and leave its crest ABOVE them.
func _grow_vein(world: WorldData, rng: RandomNumberGenerator, seed_cell: Vector2i, size: int, richness: int, material: StringName = &"ore", min_row: int = 0) -> void:
	var filled: Dictionary = {}
	var frontier: Array[Vector2i] = [seed_cell]
	var placed: int = 0
	while placed < size and not frontier.is_empty():
		var cell: Vector2i = frontier.pop_at(rng.randi_range(0, frontier.size() - 1))
		if filled.has(cell) or not world.in_bounds(cell) or cell.y < min_row:
			continue
		var here: StringName = world.blocks.get(cell, &"")
		if here != &"earth" and here != &"stone" and here != &"deepslate" and here != &"shale":
			continue                                # only replace SOLID rock (never fill a carved cave)
		world.blocks[cell] = material
		world.amounts[cell] = richness
		filled[cell] = true
		placed += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			frontier.append(cell + d)


## LODE BODIES: the accretion machinery of the veins above, writing to the BACKGROUND plane and leaving
## the host rock in place. Material follows the tier the depth means: ore above the seal, iron below.
## Runs DEAD LAST in `generate`, after the seal and the aquifers, because every guard below tests the
## final world and those passes overwrite blocks and flood rock.
func _seed_lodes(world: WorldData, rng: RandomNumberGenerator, hfield: PackedFloat32Array) -> void:
	var l2_top: int = SEAL_TOP + SEAL_ROWS
	for _i: int in _density_count(world, LODE_ATTEMPTS_PER_COL):
		var cx: int = rng.randi_range(0, world.cols - 1)
		var floor_row: int = ground_row(cx) + LODE_MIN_DEPTH
		if floor_row >= world.rows - 1:
			continue
		var cy: int = rng.randi_range(floor_row, world.rows - 1)
		# Depth sets size and richness; the horizontal field tilts the fat ones AWAY from spawn.
		var depth_frac: float = float(cy) / float(maxi(1, world.rows - 1))
		var hmul: float = hfield[cx] if cx < hfield.size() else 1.0
		var size: int = LODE_SIZE_MIN + int(round(depth_frac * float(LODE_SIZE_DEPTH_BONUS)))
		var richness: int = LODE_AMOUNT_BASE \
			+ int(round(depth_frac * float(LODE_AMOUNT_DEPTH_BONUS) * hmul))
		_grow_lode(world, rng, Vector2i(cx, cy), size, maxi(1, richness),
			&"iron" if cy >= l2_top else &"ore")


## Grow one lode body. Accretion identical to `_grow_vein` and deterministic in the rng sequence, but it
## writes `world.lodes` and NEVER `world.blocks`. A cell is refused unless it is plain
## earth/stone/deepslate/shale: sealrock would be unreachable, foliage and bazaar structure are not rock,
## and a carved-open cell would leave ore hanging in a cave. Ore-like cells are refused because mining an
## ore block writes a lode into that cell (`factory_sim.gd`), already-lode cells because two bodies would
## fight over `amounts`, and water cells because an aquifer cell is already open and flooded. The wall
## behind is not checked: the base pass fills one under every rock cell.
func _grow_lode(world: WorldData, rng: RandomNumberGenerator, seed_cell: Vector2i, size: int,
		richness: int, material: StringName) -> void:
	var filled: Dictionary = {}
	var frontier: Array[Vector2i] = [seed_cell]
	var placed: int = 0
	while placed < size and not frontier.is_empty():
		var cell: Vector2i = frontier.pop_at(rng.randi_range(0, frontier.size() - 1))
		# THE DEPTH FLOOR IS THIS CELL'S OWN COLUMN, and not the column the body was seeded in. A lode
		# accretes sideways and the ground it must stay under is not level, so carrying the seed
		# column's floor across the whole body lets one seeded on high ground creep into a neighbour
		# whose surface sits lower and break out near it. It read as correct because the two agree
		# wherever the ground is flat, which is most of the world and all of the spawn pad -- the
		# disagreement only shows up against a step, and moving where the steps fall exposed it.
		if filled.has(cell) or not world.in_bounds(cell) \
				or cell.y < ground_row(cell.x) + LODE_MIN_DEPTH:
			continue
		var here: StringName = world.blocks.get(cell, &"")
		if here != &"earth" and here != &"stone" and here != &"deepslate" and here != &"shale":
			continue                                # host rock only — never ore-like, sealrock, wood, air
		if world.lodes.has(cell) or world.water.has(cell):
			continue                                # one vein per cell, and never inside an aquifer
		world.lodes[cell] = material
		world.amounts[cell] = richness              # a lode's richness IS its deposit; the sim reads both
		filled[cell] = true
		placed += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			frontier.append(cell + d)


## IRON bodies, seeded ONLY below the seal, with depth within L2 setting size and richness.
func _scatter_iron(world: WorldData, rng: RandomNumberGenerator) -> void:
	var l2_top: int = SEAL_TOP + SEAL_ROWS
	if l2_top >= world.rows - 1:
		return
	var attempts: int = _density_count(world, IRON_ATTEMPTS_PER_COL)
	for _i: int in attempts:
		var cx: int = rng.randi_range(0, world.cols - 1)
		var cy: int = rng.randi_range(l2_top, world.rows - 1)
		var depth_frac: float = float(cy - l2_top) / float(maxi(1, world.rows - l2_top))
		var size: int = IRON_SIZE_MIN + int(round(depth_frac * float(IRON_SIZE_DEPTH_BONUS)))
		_grow_vein(world, rng, Vector2i(cx, cy), size, IRON_AMOUNT, &"iron", l2_top)


## Stamp THE SEAL: an unbroken full-width sealrock band (rows SEAL_TOP..+SEAL_ROWS-1) filling even
## carved cells. Backed by deepslate wall so the breach shaft reads as carved rock rather than void.
func _stamp_seal(world: WorldData) -> void:
	for row: int in range(SEAL_TOP, mini(SEAL_TOP + SEAL_ROWS, world.rows)):
		for col: int in world.cols:
			var cell := Vector2i(col, row)
			world.blocks[cell] = &"sealrock"
			world.amounts.erase(cell)                 # a vein cell overwritten by the seal keeps no deposit
			if not world.walls.has(cell):
				world.walls[cell] = &"deepslate_wall"


## Small SEALED water pockets carved deep into solid rock and filled to WATER_MAX. Runs LAST, after the
## seal, so no later solid pass overwrites the water. Each is an ellipse whose CENTRE sits at or below
## AQUIFER_MIN_ROW; it only ERASES SOLID rock, keeping the wall, and refuses the column's base-safe band,
## the seal band and already-open air, so it stays sealed on all sides.
func _seed_aquifers(world: WorldData, rng: RandomNumberGenerator) -> void:
	var count: int = maxi(2, _density_count(world, AQUIFER_PER_COL))
	var seal_lo: int = SEAL_TOP
	var seal_hi: int = SEAL_TOP + SEAL_ROWS - 1
	# Centres span AQUIFER_MIN_ROW down to near the world bottom, leaving room for the blob.
	var lo_row: int = AQUIFER_MIN_ROW
	var hi_row: int = world.rows - 2
	if hi_row <= lo_row:
		return
	for _a: int in count:
		var cx: int = rng.randi_range(3, world.cols - 4)
		var cy: int = rng.randi_range(lo_row, hi_row)
		var rx: int = rng.randi_range(AQUIFER_RX_MIN, AQUIFER_RX_MAX)
		var ry: int = rng.randi_range(AQUIFER_RY_MIN, AQUIFER_RY_MAX)
		var carved: Array[Vector2i] = []            # the cells THIS pocket flooded — its rim is our vein seed
		for dy: int in range(-ry, ry + 1):
			for dx: int in range(-rx, rx + 1):
				var ex: float = float(dx) / float(rx)
				var ey: float = float(dy) / float(ry)
				if ex * ex + ey * ey > 1.0:
					continue
				var cell := Vector2i(cx + dx, cy + dy)
				if not world.in_bounds(cell):
					continue
				# BASE-SAFE: never within CAVE_MIN_DEPTH of the column's surface (base stays dry).
				if cell.y < ground_row(cell.x) + CAVE_MIN_DEPTH:
					continue
				# Never in the seal band (the seal is inviolate solid) and never above the deep aquifer band.
				if cell.y < AQUIFER_MIN_ROW or (cell.y >= seal_lo and cell.y <= seal_hi):
					continue
				# Only carve SOLID rock, keeping the wall. Skipping already-open air is what keeps the pocket
				# sealed by rock rather than spliced into the cave/tunnel system.
				if not world.blocks.has(cell):
					continue
				world.blocks.erase(cell)                  # open the cell (wall kept behind it)
				world.amounts.erase(cell)                 # a vein cell we flooded keeps no deposit
				world.water[cell] = FactorySim.WATER_MAX  # fill the carved cell (guaranteed not solid now)
				carved.append(cell)
		# REWARD: line the drained pocket's walls with a rich vein (only grows into the solid rim rock).
		_seed_aquifer_treasure(world, rng, carved)


## Grow the aquifer's reward vein in the SOLID rock lining the pocket, seeded from a rim cell so
## _grow_vein bores INTO the surrounding rock and can never fill what the pocket carved. min_row
## SEAL_TOP+SEAL_ROWS floors it at the top of Stonereach. Empty `carved` means no vein.
func _seed_aquifer_treasure(world: WorldData, rng: RandomNumberGenerator, carved: Array[Vector2i]) -> void:
	if carved.is_empty():
		return
	# The SOLID rim: cells adjacent to a flooded cell that are still rock _grow_vein accepts.
	var rim: Array[Vector2i] = []
	var seen: Dictionary = {}
	for wc: Vector2i in carved:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = wc + d
			if seen.has(nb) or not world.in_bounds(nb):
				continue
			seen[nb] = true
			var here: StringName = world.blocks.get(nb, &"")
			if here == &"earth" or here == &"stone" or here == &"deepslate" or here == &"shale":
				rim.append(nb)
	if rim.is_empty():
		return                                         # pocket fully rimmed by seal/other water/air — no vein
	var seed_cell: Vector2i = rim[rng.randi_range(0, rim.size() - 1)]
	var size: int = rng.randi_range(AQUIFER_ORE_SIZE_MIN, AQUIFER_ORE_SIZE_MAX)
	_grow_vein(world, rng, seed_cell, size, AQUIFER_ORE_RICHNESS, &"rich_ore", SEAL_TOP + SEAL_ROWS)


## Sparse surface trees, the source of WOOD: a 1-wide &"wood" trunk under a 3-wide rounded &"leaves"
## canopy, stamped in the AIR above a column's ground cell, clear of the centred flat plateau. Foliage is
## excluded from the walkable silhouette (FactorySim.surface_row), so trees do not ramp.
func _plant_trees(world: WorldData, rng: RandomNumberGenerator) -> void:
	var last: int = -99
	# Keep the spawn-to-bazaar band clear: a tree just past the 3-tall frame would be the nearest tree but
	# unreachable behind the wall. The tutorial tree left of spawn is the early wood source.
	var start: int = maxi(FLAT_END + 2, RUIN_X + FactorySim.BAZAAR_W + 3)
	for col: int in range(start, world.cols):
		if col - last < TREE_GAP or rng.randf() > TREE_CHANCE:
			continue
		var ground: int = ground_row(col)
		if not world.blocks.has(Vector2i(col, ground)):
			continue                                   # column has no solid surface here (cave mouth) — skip
		var trunk: int = rng.randi_range(2, 3)
		if ground - trunk - 2 < 0:
			continue                                   # not enough sky above for trunk + canopy
		var blocked: bool = false
		for h: int in range(1, trunk + 1):
			if world.blocks.has(Vector2i(col, ground - h)):
				blocked = true                         # a hill cell already occupies the trunk space — skip
				break
		if blocked:
			continue
		for h: int in range(1, trunk + 1):
			world.blocks[Vector2i(col, ground - h)] = &"wood"
		# Rounded canopy: a 3-wide band beside/above the trunk top, with a single leaf crowning it.
		var ttr: int = ground - trunk                  # row of the topmost trunk cell
		var canopy: Array[Vector2i] = [
			Vector2i(col, ttr - 1), Vector2i(col, ttr - 2),
			Vector2i(col - 1, ttr - 1), Vector2i(col + 1, ttr - 1),
			Vector2i(col - 1, ttr), Vector2i(col + 1, ttr),
		]
		for leaf: Vector2i in canopy:
			if leaf.y >= 0 and leaf.x >= 0 and leaf.x < world.cols and not world.blocks.has(leaf):
				world.blocks[leaf] = &"leaves"
		last = col


## Stamp the bazaar ruin (see RUIN_X): flatten its footprint to FLAT_SURFACE_ROW, then lay the wood frame
## MINUS the bottom-right post. On completion FactorySim.find_bazaars detects it.
func _stamp_bazaar_ruin(world: WorldData) -> void:
	var ground: int = FLAT_SURFACE_ROW
	var w: int = FactorySim.BAZAAR_W
	var h: int = FactorySim.BAZAAR_H
	# Skip the ruin on any world too small for its fixed-column footprint (cols 40-43); it wrote unguarded
	# at fixed columns and went OOB on narrow worlds.
	if ground - h < 0 or not world.in_bounds(Vector2i(RUIN_X + w - 1, ground + 3)):
		return
	for cx: int in range(RUIN_X, RUIN_X + w):                  # flatten + clear the footprint
		for ry: int in range(0, ground):
			world.blocks.erase(Vector2i(cx, ry))              # remove any bump / tree above the ground line
			world.walls.erase(Vector2i(cx, ry))              # ...and its back-wall, so the cleared area is open
			                                                 # SKY (no floating dirt wall above the flattened ruin)
		for ry: int in range(ground, ground + 4):
			var fc := Vector2i(cx, ry)
			var existing: StringName = world.blocks.get(fc, &"")
			# Solid ground to build on, and CLEAR any buried tree stump (wood or leaves under a cleared
			# canopy), so a finished bazaar never connects to orphan wood that could flood-fell it.
			if existing == &"" or existing == &"wood" or existing == &"leaves":
				world.blocks[fc] = &"earth"
				world.walls[fc] = &"dirt_wall"
	var o := Vector2i(RUIN_X, ground - h)                     # frame top-left
	var missing := o + Vector2i(w - 1, h - 1)                 # bottom-RIGHT post — the gap faces spawn (which is
	                                                          # RIGHT of the ruin), so the player walks up from the
	                                                          # hand-work side to place the finishing block, and ends
	                                                          # up on the shaft side (never walled off by the frame)
	for dx: int in w:
		world.blocks[o + Vector2i(dx, 0)] = &"wood"           # top beam
	for dy: int in range(1, h):                               # posts (both sides), minus the gap
		for px: int in [0, w - 1]:
			var c := o + Vector2i(px, dy)
			if c != missing:
				world.blocks[c] = &"wood"
		for ix: int in range(1, w - 1):                       # keep the interior open
			world.blocks.erase(o + Vector2i(ix, dy))
