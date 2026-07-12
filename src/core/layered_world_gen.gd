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
const ORE_ATTEMPTS_PER_COL: float = 0.9
## A vein seed at the very bottom is accepted this often; at the surface, ~0. Linear in depth.
const ORE_CHANCE_DEEP: float = 0.85
## Vein BODY size (cells in the accretion blob) grows from this (shallow) toward +BONUS (deep) — deeper =
## fatter bodies you can array more drills across. Big enough to be a real patch, not a fleck.
const ORE_SIZE_MIN: int = 8
const ORE_SIZE_DEPTH_BONUS: int = 44
## COAL veins — the drill's FUEL (docs/MINING.md). Mined the same cavity way as ore; a touch more common
## and a bit shallower-reaching than ore (you need a steady coal supply once you automate), still depth-banded.
const COAL_ATTEMPTS_PER_COL: float = 0.8
const COAL_CHANCE_DEEP: float = 0.95
const COAL_SIZE_MIN: int = 6
const COAL_SIZE_DEPTH_BONUS: int = 30
const COAL_AMOUNT_BASE: int = 30         # modest PER-CELL (the drill bores cell by cell); big BODIES give the
const COAL_AMOUNT_DEPTH_BONUS: int = 170 # long-lasting TOTAL (hundreds shallow → thousands deep per body)
## Per-CELL ore deposit (docs/MINING.md). MODEST now (the boring Drill drains a cell then sinks to the next,
## so a huge per-cell number would pin the drill on one cell forever); the LONG-LASTING supply comes from the
## fat multi-cell BODY (ORE_SIZE_*): body total = cells × per-cell ≈ hundreds shallow → thousands deep, the
## Factorio patch that feeds a drill ARRAY for a long time (deeper = richer = the automation pull). Same
## depth_frac as body size/chance.
const ORE_AMOUNT_BASE: int = 30
const ORE_AMOUNT_DEPTH_BONUS: int = 170


## Earth → stone happens in the heightmap base; below this ABSOLUTE row a third band turns to deepslate,
## so descending crosses distinct material zones (the "deeper = different place" read).
const DEEPSLATE_ROW: int = 52

## THE SEAL — the L1→L2 gate (docs/PROGRESSION.md §2/§9): an UNBROKEN band of unmineable sealrock across
## the world's full width, stamped LAST so no cave/tunnel/vein can hole it. It sits a few rows INTO the
## deepslate zone, leaving a mineable deepslate SHELF above it (rows DEEPSLATE_ROW..SEAL_TOP-1, the
## stone-pick tier gate) — the shelf is where you sample deepslate for the Descent research. Below the
## seal is STONEREACH (L2): richer veins + IRON, reachable only by feeding a Descent Engine its
## throughput quota (the wall that makes the factory mandatory — no pick opens it).
const SEAL_TOP: int = 56
const SEAL_ROWS: int = 2

## IRON — L2's signature material (the analyze-sample for the next tech tier), seeded ONLY below the
## seal. Rich fat bodies (it's the reward), same accretion machinery as ore/coal.
const IRON_ATTEMPTS_PER_COL: float = 0.5
const IRON_SIZE_MIN: int = 10
const IRON_SIZE_DEPTH_BONUS: int = 30
const IRON_AMOUNT: int = 220

# --- surface trees (wood source — the bazaar's gathering foundation, docs/CRAFTING.md) ---
## A tree is planted in an eligible column this often; min columns between trunks (spacing so the
## 3-wide canopies mostly read as separate trees). Sparse — the surface reads as wooded, not a wall.
const TREE_CHANCE: float = 0.20
const TREE_GAP: int = 3

## The abandoned Bazaar RUIN: an almost-complete wood frame stamped on flat ground near spawn. Finishing
## it (placing the one missing block) activates it — the onboarding for "build a Bazaar", the first lore
## ("someone was here"), and a worked example of the pattern (docs/CRAFTING.md). It is the LEFT endpoint of
## the centred plateau (cols 40-43); its missing post is the bottom-RIGHT one, so it's claimed from the
## SPAWN side (col 44) and completing it never walls the body off from the hand-work + shaft to its right.
const RUIN_X: int = 40


func generate(cols: int, rows: int, seed: int) -> WorldData:
	# Start from the heightmap base (surface + earth/stone blocks + matching walls), then enrich.
	var world: WorldData = super.generate(cols, rows, seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_band_deepslate(world)
	_carve_caves(world, seed)
	_carve_tunnels(world, rng)
	_scatter_veins(world, rng)
	_scatter_coal(world, rng)
	_scatter_iron(world, rng)
	_plant_trees(world, rng)
	_stamp_bazaar_ruin(world)
	_stamp_seal(world)          # LAST: the gate band overwrites everything, so nothing can hole it
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
		var richness: int = ORE_AMOUNT_BASE + int(round(depth_frac * float(ORE_AMOUNT_DEPTH_BONUS)))
		_grow_vein(world, rng, Vector2i(cx, cy), size, richness)


## A depth-banded COAL pass — the drill's fuel. Same machinery as ore veins (cavity model), its own
## depth-weighted commonness/size/richness, stamping &"coal" blocks the player mines for coal.
func _scatter_coal(world: WorldData, rng: RandomNumberGenerator) -> void:
	var attempts: int = int(round(float(world.cols) * COAL_ATTEMPTS_PER_COL))
	for _i: int in attempts:
		var cx: int = rng.randi_range(0, world.cols - 1)
		var top: int = _surface_row(cx)
		if top + 1 >= world.rows:
			continue
		var cy: int = rng.randi_range(top + 1, world.rows - 1)
		var depth_frac: float = float(cy - top) / float(maxi(1, world.rows - top))
		if rng.randf() > depth_frac * COAL_CHANCE_DEEP:
			continue
		var size: int = COAL_SIZE_MIN + int(round(depth_frac * float(COAL_SIZE_DEPTH_BONUS)))
		var richness: int = COAL_AMOUNT_BASE + int(round(depth_frac * float(COAL_AMOUNT_DEPTH_BONUS)))
		_grow_vein(world, rng, Vector2i(cx, cy), size, richness, &"coal")


## Grow one vein as a compact ACCRETION BLOB (not a thin random walk): repeatedly fill a random frontier
## cell and add its rock neighbours, so the body comes out fat + contiguous — a real ore BODY you can line
## the top of with a row of drills, each boring its own column down through it (the scaling supply loop).
## Every converted cell carries the vein's depth-scaled `richness` (its finite per-cell deposit).
func _grow_vein(world: WorldData, rng: RandomNumberGenerator, seed_cell: Vector2i, size: int, richness: int, material: StringName = &"ore") -> void:
	var filled: Dictionary = {}
	var frontier: Array[Vector2i] = [seed_cell]
	var placed: int = 0
	while placed < size and not frontier.is_empty():
		var cell: Vector2i = frontier.pop_at(rng.randi_range(0, frontier.size() - 1))
		if filled.has(cell) or not world.in_bounds(cell):
			continue
		var here: StringName = world.blocks.get(cell, &"")
		if here != &"earth" and here != &"stone" and here != &"deepslate":
			continue                                # only replace SOLID rock (never fill a carved cave)
		world.blocks[cell] = material
		world.amounts[cell] = richness
		filled[cell] = true
		placed += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			frontier.append(cell + d)


## IRON bodies — L2's reward, seeded ONLY below the seal (depth position within L2 sets size richness).
## Replaces solid rock exactly like ore/coal veins; the drill bores it the same way.
func _scatter_iron(world: WorldData, rng: RandomNumberGenerator) -> void:
	var l2_top: int = SEAL_TOP + SEAL_ROWS
	if l2_top >= world.rows - 1:
		return
	var attempts: int = int(round(float(world.cols) * IRON_ATTEMPTS_PER_COL))
	for _i: int in attempts:
		var cx: int = rng.randi_range(0, world.cols - 1)
		var cy: int = rng.randi_range(l2_top, world.rows - 1)
		var depth_frac: float = float(cy - l2_top) / float(maxi(1, world.rows - l2_top))
		var size: int = IRON_SIZE_MIN + int(round(depth_frac * float(IRON_SIZE_DEPTH_BONUS)))
		_grow_vein(world, rng, Vector2i(cx, cy), size, IRON_AMOUNT, &"iron")


## Stamp THE SEAL: an unbroken full-width sealrock band (rows SEAL_TOP..+SEAL_ROWS-1), filling even
## carved cells — the one thing worldgen guarantees solid. Backed by deepslate wall so the breach shaft
## reads as carved rock, not void.
func _stamp_seal(world: WorldData) -> void:
	for row: int in range(SEAL_TOP, mini(SEAL_TOP + SEAL_ROWS, world.rows)):
		for col: int in world.cols:
			var cell := Vector2i(col, row)
			world.blocks[cell] = &"sealrock"
			world.amounts.erase(cell)                 # a vein cell overwritten by the seal keeps no deposit
			if not world.walls.has(cell):
				world.walls[cell] = &"deepslate_wall"


## Plant sparse trees on the grass surface — the source of WOOD (the bazaar's gathering foundation,
## docs/CRAFTING.md). A tree is a 1-wide trunk of &"wood" under a 3-wide rounded &"leaves" canopy,
## stamped in the AIR above a column's ground cell. The centred flat plateau (the spawn cluster) is left clear
## so a tree never traps the player or buries the forge. Foliage is solid + choppable but excluded from
## the walkable silhouette (FactorySim.surface_row), so trees don't ramp; chopping one fells it (→wood).
func _plant_trees(world: WorldData, rng: RandomNumberGenerator) -> void:
	var last: int = -99
	# Keep the spawn → bazaar band clear of worldgen trees (a tree just past the 3-tall bazaar frame would be
	# the "nearest" tree but unreachable behind the wall). The tutorial tree (seeded left of spawn) is the
	# early wood source; natural trees start past the ruin + a buffer.
	var start: int = maxi(FLAT_END + 2, RUIN_X + FactorySim.BAZAAR_W + 3)
	for col: int in range(start, world.cols):
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
## the wood frame MINUS one block (the bottom-right post, facing spawn) for the player to finish — the moment it
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
