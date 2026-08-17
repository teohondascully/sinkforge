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

## THE SCARPS — and the reason the budget above cannot deliver a landscape on its own.
##
## |dh/dx| <= sum(amp x freq) is exact, which means amplitude is bought with WAVELENGTH: a six-row hill
## that never steps more than a row needs about sixty-three columns to rise over. The world is a hundred
## and twenty-eight columns wide. There is room for two such hills, and that is the whole ceiling on
## walkable relief here — no tuning gets past it, because it is arithmetic and a map size, not a choice.
##
## So the relief that MATTERS stops pretending to be a hill and becomes a step. A handful of deliberate
## scarps, each a face too tall to walk up, splitting the surface into terraces at different heights.
## Everything between them stays under the budget and is walked exactly as before; the faces themselves are
## the exception, and they are an exception the game now has answers to — a jump for the short ones, the
## rope for the rest. That is the same shape as the sinkhole mouths: a rule kept everywhere by construction,
## broken only at a few marked places, with the marking recorded so a test can tell design from noise.
##
## Fixed columns rather than seeded ones, following the bazaar ruin's precedent: these are landmarks, the
## world is a fixed size, and a skyline you can learn is worth more here than one that is merely different
## every time. Placed clear of the base pad and its ramps on both sides.
const SCARP_COLS: Array[int] = [17, 79, 107]
## Rows the ground steps DOWN at each scarp (negative steps up), read left to right. Chosen for what each
## one asks of a player LEAVING the base, which is the direction every one of them is met from: a five-row
## headland wall to the west, a four-row drop off the eastern edge of the home terrace, and a six-row wall
## beyond it. Two of the three are climbs, so wandering out of the base is not uniformly free in either
## direction; the drop is the one that commits you, because it costs nothing to take and the rope to undo.
const SCARP_STEPS: Array[int] = [5, 4, -6]
const SCARP_SPAN: int = 2            ## columns the face takes to fall — 2 keeps it a face, not a ramp
## The surface sits well DOWN the world so a tall SKY band fills the space above it — the camera, centred
## on the body, then frames the player in the middle of the screen (Terraria) instead of jamming them at
## the top against the limit. Everything below is underground; the rows above (0..FLAT_SURFACE_ROW-1) are sky.
const FLAT_SURFACE_ROW: int = 20

## THE BAND THE GENERATED GROUND CAN OCCUPY, and it is a promise other code needs to be able to rely on.
## `ground_row` clamps into these, so no column's ground is ever outside them, on either generator —
## `LayeredWorldGen extends HeightmapWorldGen`, so this bound governs both.
##
## They are public because the RENDERER has to be able to ask "is that a surface, or the floor of a hole?"
## `FactorySim.surface_row` cannot answer it: that function scans from row 0 and returns the first solid
## cell, which is the right question at generation time and the wrong one afterwards, because a dug column
## answers with the rock under the player's own shaft. Consumers that mean *the walked ground* must reject
## anything below `SURFACE_ROW_MAX`; see `FineTerrain.NO_SURFACE`.
const SURFACE_ROW_MIN: int = FLAT_SURFACE_ROW - 9   ## the highest hilltop (row 11)
const SURFACE_ROW_MAX: int = FLAT_SURFACE_ROW + 11  ## the lowest valley floor (row 31)
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
		var top: int = ground_row(col)
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


## THE GROUND OF A COLUMN — where the sky stops, for the whole codebase and not just for generation.
##
## Topmost solid row for a column: flat across the spawn/forge region, gentle layered-sine hills
## beyond (so steps render as smooth diagonal slopes). Seed-independent for now — a future generator
## can make the surface seeded; the seam already supports it.
##
## PUBLIC AND STATIC because this is the only truthful answer to "how far below the sky is that?" once
## the world has been PLAYED. `FactorySim.surface_row` scans from row 0 for the first solid cell, which
## is the same question only while the world is untouched: dig a shaft and it answers with the rock under
## your own boots, so the depth every consumer computes from it collapses to about -1 no matter how deep
## you are. `SURFACE_ROW_MIN/MAX` were made public for the same reason and are only half an answer — they
## bound the band, so they can reject a rift floor forty rows down but not the ten-row shaft you dug this
## minute, which is the case the beds and the hints actually live in.
##
## It costs nothing to hand out: only constants and the static `terrace`, so it needs no instance, no
## seed, no retained heightmap and no save field, and it stays correct on a world loaded from disk with
## its generator long gone. Seven consumers outside this file needed it and could not have it —
## `FineTerrain.walked_surface`, `check_relief` and `play_tests` each invented a private threshold (three
## numbers for one bound), and `test_worldgen` reached through the underscore five times with a comment
## noting it is seed-independent. That is what a private answer everybody needs looks like.
static func ground_row(col: int) -> int:
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
	return clampi(int(round(h)) + terrace(col), SURFACE_ROW_MIN, SURFACE_ROW_MAX)


## The accumulated scarp offset at a column: which terrace this ground belongs to. Public because the
## worldgen guard needs to tell a designed face apart from a hillside the budget failed to keep walkable,
## and because a scarp is the one place the every-step-is-walkable contract is deliberately broken.
##
## Measured FROM THE PAD, and that subtraction is the whole difference between a landscape and a bug. The
## first version accumulated from column zero, which left the fixtures' flat ground — returned above as the
## bare datum — five rows below the terrain either side of it. The base was at the bottom of a bowl with
## unclimbable walls: the fast-forward guard stalled at 297px walking out of it, and the worldgen guard
## reported a stray five-row rise at column 38, one column outside the pad. Anchoring here makes the pad a
## terrace in its own right, so its edges are continuous by construction and every discontinuity in the
## world is one of the marked faces below.
static func terrace(col: int) -> int:
	return _terrace_raw(col) - _terrace_raw(BASE_PAD_START)


static func _terrace_raw(col: int) -> int:
	var out: int = 0
	for i: int in SCARP_COLS.size():
		var at: int = SCARP_COLS[i]
		if col <= at:
			continue
		# Fall over SCARP_SPAN columns so the face is a face and not a single impossible cliff edge: the
		# body can stand on it, the renderer has something to shade, and the drop is still past a jump.
		out += int(round(float(SCARP_STEPS[i]) * clampf(float(col - at) / float(SCARP_SPAN), 0.0, 1.0)))
	return out


## Is this column ON a scarp face — the marked exception to the walkable-step contract?
static func on_scarp(col: int) -> bool:
	for at: int in SCARP_COLS:
		if col > at and col <= at + SCARP_SPAN:
			return true
	return false
