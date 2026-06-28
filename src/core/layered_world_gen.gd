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

# --- ore ---
## Vein-seed attempts ≈ this × columns. Each is accepted by a depth-weighted roll, so most surviving
## veins land deep — the band. Tuned to a touch richer overall than the old flat 0.3/col scatter.
const ORE_ATTEMPTS_PER_COL: float = 1.6
## A vein seed at the very bottom is accepted this often; at the surface, ~0. Linear in depth.
const ORE_CHANCE_DEEP: float = 0.85
## Vein size grows from this many cells (shallow) toward +ORE_SIZE_DEPTH_BONUS (deep) — richer down low.
const ORE_SIZE_MIN: int = 2
const ORE_SIZE_DEPTH_BONUS: int = 6


func generate(cols: int, rows: int, seed: int) -> WorldData:
	# Start from the heightmap base (surface + earth/stone blocks + matching walls), then enrich.
	var world: WorldData = super.generate(cols, rows, seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_carve_caves(world, seed)
	_scatter_veins(world, rng)
	return world


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
		_grow_vein(world, rng, Vector2i(cx, cy), size)


## Grow one vein as a random-walk blob from a seed cell, converting solid rock to ore as it wanders.
func _grow_vein(world: WorldData, rng: RandomNumberGenerator, seed_cell: Vector2i, size: int) -> void:
	var cell: Vector2i = seed_cell
	for _step: int in size:
		var here: StringName = world.blocks.get(cell, &"")
		if here == &"earth" or here == &"stone":
			world.blocks[cell] = &"ore"
		var dir: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi_range(0, 3)]
		cell += dir
		if not world.in_bounds(cell):
			break
