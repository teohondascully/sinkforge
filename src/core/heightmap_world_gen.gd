class_name HeightmapWorldGen
extends WorldGen

## The first concrete generator — reproduces today's hand-seeded world through the WorldData
## contract: an undulating heightmap surface (flat across the spawn/forge region so the motion
## harness stays valid), earth down to a depth then a STONE layer (the "richer" smoke test that
## proves extending generation is a localized change), and seeded ore veins scattered in the rock.
## Walls are filled in Slice 3. Deterministic in (cols, rows, seed) via a seeded RNG.

## The spawn cluster sits on a flat plateau CENTRED on the map (cols [FLAT_START, FLAT_END]) so the
## player-follow camera frames the base in the middle of the screen — not jammed against the left edge
## with everything shifted right. Gentle layered-sine hills roll away on both sides. Harness-stable ground.
const FLAT_START: int = 30
const FLAT_END: int = 66
## ...but only the BASE PAD is dead flat, and it is much smaller than that. The plateau used to run the
## full 36 columns, which is wider than the camera: at spawn the entire visible horizon was one ruler-drawn
## line from edge to edge, and no amount of art on top of it will stop that reading as a placeholder. A
## real skyline is the cheapest legibility a side-on game has and it was being spent on nothing.
##
## What genuinely has to be flat is the ground the seeded fixtures stand on — the bootstrap forge, the
## mineshaft, the bazaar ruin footprint — because those are placed at MainView.SURFACE by row, not by
## lookup. That is columns 39-58. Everywhere else the relief ramps back in over RELIEF_RAMP columns, so
## the join is seamless, the near-base slopes are the one-tile steps the ramp authority glides, and the
## frame around the player finally has a horizon with a shape.
const BASE_PAD_START: int = 39
const BASE_PAD_END: int = 58
const RELIEF_RAMP: int = 16

## EVERY SURFACE IS WALKABLE, BY CONSTRUCTION. The body auto-steps up to 1.3 cells; a 2-row rise between
## adjacent columns is a wall it has to jump, and a skyline built out of them is the "walking feels
## clunky" complaint in its purest form — you press right, and the world says no, repeatedly, on ground
## that looks like a gentle hill. The fast-forward guard measured it before anyone had to feel it: travel
## across rolling terrain dropped to 60% of flat-ground speed.
##
## The guarantee is arithmetic rather than a post-pass. |dh/dx| for a sum of sines is bounded by the sum
## of amplitude x frequency, so choosing the terms so that total stays under 1.0 means round() can never
## produce a step bigger than one row — no clamping, no smoothing pass, no special cases. The envelope
## ramps count too (relief x d(env)/dx), which is why RELIEF_RAMP is generous: a short ramp is itself a
## slope, and a short ramp under a tall hill was quietly generating exactly the walls it was hiding.
##
##   near:  0.85 x 0.21                        = 0.179
##   far:   1.60 x 0.30  +  0.90 x 0.11        = 0.579
##   envelope: (1.60 + 0.90) / 16              = 0.156
##                                        total = 0.914  < 1.0
##
## tests/test_worldgen.gd asserts it over every column, so a future tweak that breaks the budget trips
## the harness instead of shipping a hillside nobody can climb.
const NEAR_AMP: float = 0.85
const NEAR_FREQ: float = 0.21
const FAR_AMP_A: float = 1.60
const FAR_FREQ_A: float = 0.30
const FAR_AMP_B: float = 0.90
const FAR_FREQ_B: float = 0.11
## The surface sits well DOWN the world so a tall SKY band fills the space above it — the camera, centred
## on the body, then frames the player in the middle of the screen (Terraria) instead of jamming them at
## the top against the limit. Everything below is underground; the rows above (0..FLAT_SURFACE_ROW-1) are sky.
const FLAT_SURFACE_ROW: int = 20
## Earth turns to STONE this many tiles below the surface — sells depth, and demonstrates a new
## material dropped into generation without touching sim or renderer.
const STONE_DEPTH: int = 8
## Roughly the old vein density (~0.3 veins per column, 2 cells wide).
const VEIN_DENSITY: float = 0.3


func generate(cols: int, rows: int, seed: int) -> WorldData:
	var world := WorldData.new()
	world.cols = cols
	world.rows = rows
	world.seed = seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	# Surface + fill: earth near the top, stone below STONE_DEPTH — in BOTH layers, so a dug-out cell
	# reveals a background WALL of the matching rock (Terraria-style carved room), not empty void.
	var surface: PackedInt32Array = PackedInt32Array()
	for col: int in cols:
		var top: int = _surface_row(col)
		surface.append(top)
		for row: int in range(top, rows):
			var below: int = row - top
			var deep: bool = below >= STONE_DEPTH
			var cell: Vector2i = Vector2i(col, row)
			world.blocks[cell] = &"stone" if deep else &"earth"
			world.walls[cell] = &"stone_wall" if deep else &"dirt_wall"

	# Ore veins: seeded scatter, 2 cells wide, embedded wherever there's rock.
	var veins: int = int(round(float(cols) * VEIN_DENSITY))
	for _i: int in veins:
		var cx: int = rng.randi_range(0, cols - 2)
		var cy: int = rng.randi_range(surface[cx] + 1, rows - 1)
		for dx: int in [0, 1]:
			var cell: Vector2i = Vector2i(cx + dx, cy)
			var here: StringName = world.blocks.get(cell, &"")
			if here == &"earth" or here == &"stone":
				world.blocks[cell] = &"ore"

	return world


## Topmost solid row for a column: flat across the spawn/forge region, gentle layered-sine hills
## beyond (so steps render as smooth diagonal slopes). Seed-independent for now — a future generator
## can make the surface seeded; the seam already supports it.
func _surface_row(col: int) -> int:
	var out: int = maxi(BASE_PAD_START - col, col - BASE_PAD_END)
	if out <= 0:
		return FLAT_SURFACE_ROW                      # the fixtures' ground — dead flat by contract
	# Relief everywhere else, in TWO stages, because the terrain near the base is walked constantly and
	# the terrain far from it is mostly looked at. Near the pad: a single tile of long-wavelength roll —
	# enough that the horizon has a shape, gentle enough that every step is one the auto-step-up glides.
	# Far out: the full layered hills fade in. Dropping the full hills straight onto the pad edge was
	# measurably wrong, not just aesthetically — three-row steps a dozen columns from spawn halved the
	# body's travel speed and the fast-forward guard caught it as "not advancing".
	var near: float = clampf(float(out) / float(RELIEF_RAMP), 0.0, 1.0)
	var far: float = clampf(float(out - RELIEF_RAMP) / float(RELIEF_RAMP), 0.0, 1.0)
	var h: float = float(FLAT_SURFACE_ROW) \
		- NEAR_AMP * sin(float(col) * NEAR_FREQ + 0.5) * near \
		- (FAR_AMP_A * sin(float(col) * FAR_FREQ_A)
			+ FAR_AMP_B * sin(float(col) * FAR_FREQ_B + 1.7)) * far
	return clampi(int(round(h)), FLAT_SURFACE_ROW - 3, FLAT_SURFACE_ROW + 5)
