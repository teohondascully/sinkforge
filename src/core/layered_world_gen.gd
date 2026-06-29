class_name LayeredWorldGen
extends HeightmapWorldGen

## The RICHER generator (docs/WORLDGEN.md). Builds on HeightmapWorldGen's surface + earth/stone fill,
## then layers in the two things that most change how EXPLORING feels:
##   1. CAVES — organic carved pockets (open block, wall KEPT → Terraria carved room, not void) whose
##      openness GROWS with depth. The near-surface base stays solid by construction (caves only below
##      CAVE_MIN_DEPTH), so danger stays located/opt-in — you dig DOWN to find the open dark.
##   2. DEPTH-BANDED ORE — veins (grown blobs, not single specks) that get MORE FREQUENT and BIGGER
##      the deeper you go: the core pull (deeper = richer). Replaces the old uniform scatter.
##
## Emits only existing material ids (&"earth"/&"stone"/&"ore" + their walls) → the renderer needs ZERO
## change; this is the seam working. Deterministic in (cols, rows, seed): one seeded RNG for veins, a
## seeded FastNoiseLite for caves. Improve generation here without sim or viz knowing.

# --- caves ---
## Caves never breach this many tiles below a column's surface (keeps the spawn base safe/solid).
const CAVE_MIN_DEPTH: int = 6
## Noise scale — smaller = larger, smoother pockets. ~0.10 gives room-sized caverns.
const CAVE_FREQ: float = 0.11
## Carve where noise exceeds this. EASES toward CAVE_THRESHOLD_DEEP with depth → more open down low.
const CAVE_THRESHOLD_TOP: float = 0.40
const CAVE_THRESHOLD_DEEP: float = 0.12

# --- tunnels (winding caverns that connect the noise pockets into an explorable system) ---
## Worm count ≈ this × columns — a handful of long tunnels threading the rock.
const TUNNEL_PER_COL: float = 0.09
const TUNNEL_MIN_LEN: int = 18
const TUNNEL_MAX_LEN: int = 46
## Carve radius around the worm path (1 → ~3-wide walkable caverns).
const TUNNEL_RADIUS: int = 1

# --- ore ---
## Vein-seed attempts ≈ this × columns. Each is accepted by a depth-weighted roll, so most surviving
## veins land deep — the band. Tuned to a touch richer overall than the old flat 0.3/col scatter.
const ORE_ATTEMPTS_PER_COL: float = 1.6
## A vein seed at the very bottom is accepted this often; at the surface, ~0. Linear in depth.
const ORE_CHANCE_DEEP: float = 0.85
## Vein size grows from this many cells (shallow) toward +ORE_SIZE_DEPTH_BONUS (deep) — richer down low.
const ORE_SIZE_MIN: int = 2
const ORE_SIZE_DEPTH_BONUS: int = 6
## Per-cell DEPOSIT richness (how many ore one cell holds; finite deposits, docs/MINING.md). A shallow
## vein cell holds 1 (one hit, like before); a bottom-of-world cell holds 1+this — so deep deposits are
## the rich ones a Drill is worth building for. Depth-scaled, same depth_frac as size/chance.
const ORE_AMOUNT_DEPTH_BONUS: int = 4


## Earth → stone happens in the heightmap base; below this ABSOLUTE row a third band turns to deepslate,
## so descending crosses distinct material zones (the "deeper = different place" read).
const DEEPSLATE_ROW: int = 26

# --- surface trees (wood source — the bazaar's gathering foundation, docs/CRAFTING.md) ---
## A tree is planted in an eligible column this often; min columns between trunks (spacing so the
## 3-wide canopies mostly read as separate trees). Sparse — the surface reads as wooded, not a wall.
const TREE_CHANCE: float = 0.20
const TREE_GAP: int = 3

## The abandoned Bazaar RUIN: an almost-complete wood frame stamped on flat ground near spawn. Finishing
## it (placing the one missing block) activates it — the onboarding for "build a Bazaar", the first lore
## ("someone was here"), and a worked example of the pattern (docs/CRAFTING.md). Sits clear of the player
## (col 3) and forge (col 6), just past the flat spawn band.
const RUIN_X: int = 10


func generate(cols: int, rows: int, seed: int) -> WorldData:
	# Start from the heightmap base (surface + earth/stone blocks + matching walls), then enrich.
	var world: WorldData = super.generate(cols, rows, seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_band_deepslate(world)
	_carve_caves(world, seed)
	_carve_tunnels(world, rng)
	_scatter_veins(world, rng)
	_plant_trees(world, rng)
	_stamp_bazaar_ruin(world)
	return world


## Convert the deep band (rows ≥ DEEPSLATE_ROW) of stone to deepslate, in both grids, so a dug-out deep
## cell reveals a deepslate wall. A new material id dropped into generation — renderer just needs it
## registered. Veins still overlay afterwards.
func _band_deepslate(world: WorldData) -> void:
	for cell: Vector2i in world.blocks:
		if cell.y >= DEEPSLATE_ROW and world.blocks[cell] == &"stone":
			world.blocks[cell] = &"deepslate"
	for cell: Vector2i in world.walls:
		if cell.y >= DEEPSLATE_ROW and world.walls[cell] == &"stone_wall":
			world.walls[cell] = &"deepslate_wall"


## Carve organic caves with seeded noise. A cell opens (block erased, WALL kept) when the noise there
## clears a depth-eased threshold — so caves are rare/small near the surface and widen with depth.
func _carve_caves(world: WorldData, seed: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = CAVE_FREQ
	for col: int in world.cols:
		var top: int = _surface_row(col)
		var cave_start: int = top + CAVE_MIN_DEPTH
		for row: int in range(cave_start, world.rows):
			var cell: Vector2i = Vector2i(col, row)
			if not world.blocks.has(cell):
				continue
			var depth_frac: float = float(row - cave_start) / float(maxi(1, world.rows - cave_start))
			var threshold: float = lerpf(CAVE_THRESHOLD_TOP, CAVE_THRESHOLD_DEEP, depth_frac)
			if noise.get_noise_2d(float(col), float(row)) > threshold:
				world.blocks.erase(cell)        # open air; the wall behind it stays (carved room)


## Winding TUNNELS: a few worms random-walk through the rock with a horizontal bias, carving walkable
## caverns that thread the isolated noise pockets into one connected, explorable system (the noise alone
## gives blobs; these give you somewhere to GO). Each worm keeps its wall (carved room) and never rises
## into the base-safe band. Deterministic via the shared rng.
func _carve_tunnels(world: WorldData, rng: RandomNumberGenerator) -> void:
	var worms: int = maxi(3, int(round(float(world.cols) * TUNNEL_PER_COL)))
	for _w: int in worms:
		var x: float = float(rng.randi_range(2, world.cols - 3))
		var min_row: int = _surface_row(int(x)) + CAVE_MIN_DEPTH + 2
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


## Carve a small disc of OPEN air (block erased, wall kept), refusing any cell in a column's base-safe
## band so tunnels never undermine the spawn surface.
func _carve_disc(world: WorldData, center: Vector2i, radius: int) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius + 1:
				continue
			var cell: Vector2i = center + Vector2i(dx, dy)
			if not world.in_bounds(cell):
				continue
			if cell.y < _surface_row(cell.x) + CAVE_MIN_DEPTH:
				continue                                 # protect the near-surface base
			if world.blocks.has(cell):
				world.blocks.erase(cell)


## Depth-banded ore: many vein-seed attempts, each kept by a depth-weighted roll (deep seeds survive,
## shallow ones rarely do), then grown into a blob whose size also scales with depth. Ore only replaces
## SOLID rock (earth/stone) — never fills a carved cave, though a vein can sit exposed in a cave wall.
func _scatter_veins(world: WorldData, rng: RandomNumberGenerator) -> void:
	var attempts: int = int(round(float(world.cols) * ORE_ATTEMPTS_PER_COL))
	for _i: int in attempts:
		var cx: int = rng.randi_range(0, world.cols - 1)
		var top: int = _surface_row(cx)
		if top + 1 >= world.rows:
			continue
		var cy: int = rng.randi_range(top + 1, world.rows - 1)
		var depth_frac: float = float(cy - top) / float(maxi(1, world.rows - top))
		if rng.randf() > depth_frac * ORE_CHANCE_DEEP:
			continue                            # rejected — most shallow seeds die here (the band)
		var size: int = ORE_SIZE_MIN + int(round(depth_frac * float(ORE_SIZE_DEPTH_BONUS)))
		var richness: int = 1 + int(round(depth_frac * float(ORE_AMOUNT_DEPTH_BONUS)))
		_grow_vein(world, rng, Vector2i(cx, cy), size, richness)


## Grow one vein as a random-walk blob from a seed cell, converting solid rock to ore as it wanders.
## Each converted cell is stamped with the vein's depth-scaled `richness` (its finite deposit amount).
func _grow_vein(world: WorldData, rng: RandomNumberGenerator, seed_cell: Vector2i, size: int, richness: int) -> void:
	var cell: Vector2i = seed_cell
	for _step: int in size:
		var here: StringName = world.blocks.get(cell, &"")
		if here == &"earth" or here == &"stone" or here == &"deepslate":
			world.blocks[cell] = &"ore"
			world.amounts[cell] = richness
		var dir: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi_range(0, 3)]
		cell += dir
		if not world.in_bounds(cell):
			break


## Plant sparse trees on the grass surface — the source of WOOD (the bazaar's gathering foundation,
## docs/CRAFTING.md). A tree is a 1-wide trunk of &"wood" under a 3-wide rounded &"leaves" canopy,
## stamped in the AIR above a column's ground cell. The spawn/forge band (cols ≤ FLAT_COLS) is left clear
## so a tree never traps the player or buries the forge. Foliage is solid + choppable but excluded from
## the walkable silhouette (FactorySim.surface_row), so trees don't ramp; chopping one fells it (→wood).
func _plant_trees(world: WorldData, rng: RandomNumberGenerator) -> void:
	var last: int = -99
	for col: int in range(FLAT_COLS + 1, world.cols):
		if col - last < TREE_GAP or rng.randf() > TREE_CHANCE:
			continue
		var ground: int = _surface_row(col)
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


## Stamp the near-complete bazaar ruin (see RUIN_X). Flatten its footprint to FLAT_SURFACE_ROW, then lay
## the wood frame MINUS one block (the bottom-right post) for the player to finish — the moment it
## completes, FactorySim.find_bazaars detects it and the Bazaars view plays the transform.
func _stamp_bazaar_ruin(world: WorldData) -> void:
	var ground: int = FLAT_SURFACE_ROW
	var w: int = FactorySim.BAZAAR_W
	var h: int = FactorySim.BAZAAR_H
	for cx: int in range(RUIN_X, RUIN_X + w):                  # flatten + clear the footprint
		for ry: int in range(0, ground):
			world.blocks.erase(Vector2i(cx, ry))              # remove any bump / tree above the ground line
			world.walls.erase(Vector2i(cx, ry))              # ...and its back-wall, so the cleared area is open
			                                                 # SKY (no floating dirt wall above the flattened ruin)
		for ry: int in range(ground, ground + 4):
			var fc := Vector2i(cx, ry)
			var existing: StringName = world.blocks.get(fc, &"")
			# Solid ground to stand + build on — and CLEAR any buried tree stump (wood/leaves left under a
			# cleared canopy), so a finished bazaar never connects to orphan wood that could flood-fell it.
			if existing == &"" or existing == &"wood" or existing == &"leaves":
				world.blocks[fc] = &"earth"
				world.walls[fc] = &"dirt_wall"
	var o := Vector2i(RUIN_X, ground - h)                     # frame top-left
	var missing := o + Vector2i(0, h - 1)                     # bottom-LEFT post — the gap faces spawn, so the
	                                                          # player can walk up and place the finishing block
	                                                          # (the far side is behind the 3-tall frame wall)
	for dx: int in w:
		world.blocks[o + Vector2i(dx, 0)] = &"wood"           # top beam
	for dy: int in range(1, h):                               # posts (both sides), minus the gap
		for px: int in [0, w - 1]:
			var c := o + Vector2i(px, dy)
			if c != missing:
				world.blocks[c] = &"wood"
		for ix: int in range(1, w - 1):                       # keep the interior open
			world.blocks.erase(o + Vector2i(ix, dy))
