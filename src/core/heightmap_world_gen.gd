class_name HeightmapWorldGen
extends WorldGen

## The first concrete generator: an undulating heightmap surface (flat across the spawn/forge region so
## the motion harness stays valid), earth down to STONE_DEPTH with stone below, and seeded ore veins.
## Deterministic in (cols, rows, seed) via a seeded RNG.

## The spawn cluster sits on a flat plateau CENTRED on the map (cols [FLAT_START, FLAT_END]) so the
## player-follow camera frames the base mid-screen. Layered-sine hills roll away on both sides.
const FLAT_START: int = 30
const FLAT_END: int = 66
## Only the BASE PAD is dead flat, covering the ground the seeded fixtures stand on: the bootstrap forge,
## the mineshaft and the bazaar ruin footprint are placed at MainView.SURFACE by row rather than by
## lookup. That is columns 39-58. Elsewhere the relief ramps back in over RELIEF_RAMP columns.
const BASE_PAD_START: int = 39
const BASE_PAD_END: int = 58
const RELIEF_RAMP: int = 16

## EVERY SURFACE IS WALKABLE, BY CONSTRUCTION. The body auto-steps up to 1.3 cells, so a 2-row rise
## between adjacent columns is a wall it must jump; the fast-forward guard measured travel across rolling
## terrain at 60% of flat-ground speed before this.
##
## The guarantee is arithmetic, not a post-pass: |dh/dx| for a sum of sines is bounded by the sum of
## amplitude x frequency, so keeping that total under 1.0 means round() can never produce a step bigger
## than one row. The envelope ramps count too (relief x d(env)/dx), hence a generous RELIEF_RAMP.
##
##   near:  0.85 x 0.21                        = 0.179
##   far:   1.60 x 0.30  +  0.90 x 0.11        = 0.579
##   envelope: (1.60 + 0.90) / 16              = 0.156
##                                        total = 0.914  < 1.0
##
## tests/test_worldgen.gd asserts it over every column.
const NEAR_AMP: float = 0.85
const NEAR_FREQ: float = 0.21
const FAR_AMP_A: float = 1.60
const FAR_FREQ_A: float = 0.30
const FAR_AMP_B: float = 0.90
const FAR_FREQ_B: float = 0.11

## THE SCARPS, because the budget above cannot deliver a landscape alone. |dh/dx| <= sum(amp x freq) is
## exact, so amplitude is bought with WAVELENGTH: a six-row hill that never steps more than a row needs
## about sixty-three columns, and the world is a hundred and twenty-eight columns wide, capping walkable
## relief at roughly two such hills.
##
## So the relief that matters is a STEP: a few deliberate scarps, each a face too tall to walk up,
## splitting the surface into terraces. Everything between them stays under the budget; the faces are the
## marked exception, answered by a jump for the short ones and the rope for the rest, and the marking is
## recorded so a test can tell design from noise. Fixed columns rather than seeded, following the bazaar
## ruin's precedent, clear of the base pad and its ramps on both sides.
const SCARP_COLS: Array[int] = [17, 79, 107]
## Rows the ground steps DOWN at each scarp (negative steps up), read left to right: a five-row headland
## wall west, a four-row drop off the eastern edge of the home terrace, and a six-row wall beyond it. Two
## are climbs; the drop commits, costing a rope to undo.
const SCARP_STEPS: Array[int] = [5, 4, -6]
const SCARP_SPAN: int = 2            ## columns the face takes to fall — 2 keeps it a face, not a ramp
## The surface sits well DOWN the world so a tall SKY band fills the space above it and the body-centred
## camera frames the player mid-screen. Rows 0..FLAT_SURFACE_ROW-1 are sky.
const FLAT_SURFACE_ROW: int = 20

## THE BAND THE GENERATED GROUND CAN OCCUPY. `ground_row` clamps into these, so no column's ground is ever
## outside them on either generator (`LayeredWorldGen extends HeightmapWorldGen`). Public because the
## RENDERER must distinguish a surface from the floor of a hole: `FactorySim.surface_row` returns the first
## solid cell from row 0, which a dug column answers with the rock under the player's own shaft. Consumers
## meaning the walked ground must reject anything below `SURFACE_ROW_MAX`; see `FineTerrain.NO_SURFACE`.
const SURFACE_ROW_MIN: int = FLAT_SURFACE_ROW - 9   ## the highest hilltop (row 11)
const SURFACE_ROW_MAX: int = FLAT_SURFACE_ROW + 11  ## the lowest valley floor (row 31)
## Earth turns to STONE this many tiles below the surface.
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

	# Surface + fill in BOTH layers, so a dug-out cell reveals a background WALL of the matching rock
	# rather than empty void.
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


## THE GROUND OF A COLUMN: topmost solid row, flat across the spawn/forge region and layered-sine hills
## beyond. Seed-independent for now; the seam supports a seeded surface later.
##
## PUBLIC AND STATIC because it is the only truthful depth reference once the world has been PLAYED.
## `FactorySim.surface_row` scans from row 0 for the first solid cell, which a dug shaft answers with the
## rock under the player's own boots, collapsing any computed depth to about -1. `SURFACE_ROW_MIN/MAX`
## bound the band, so they reject a rift floor forty rows down but not a ten-row shaft. Costs nothing to
## call: only constants and the static `terrace`.
##
## IT RECOMPUTES THE GROUND, IT DOES NOT REMEMBER IT. `generate` builds a `surface` array and discards it
## and the save format does not carry it, so this is right for a loaded world only while the constants it
## reads are the ones that world was BUILT with. Changing FLAT_SURFACE_ROW, the relief amplitudes or
## `terrace` silently gives older saves an answer describing terrain they do not have. A seeded surface
## would force keeping the array `generate` currently discards.
static func ground_row(col: int) -> int:
	var out: int = maxi(BASE_PAD_START - col, col - BASE_PAD_END)
	if out <= 0:
		return FLAT_SURFACE_ROW                      # the fixtures' ground — dead flat by contract
	# Relief in TWO stages: near the pad, one tile of long-wavelength roll keeps every step one the
	# auto-step-up glides; far out, the full layered hills fade in. Dropping the full hills straight onto the
	# pad edge put three-row steps a dozen columns from spawn and halved travel speed.
	var near: float = clampf(float(out) / float(RELIEF_RAMP), 0.0, 1.0)
	var far: float = clampf(float(out - RELIEF_RAMP) / float(RELIEF_RAMP), 0.0, 1.0)
	var h: float = float(FLAT_SURFACE_ROW) \
		- NEAR_AMP * sin(float(col) * NEAR_FREQ + 0.5) * near \
		- (FAR_AMP_A * sin(float(col) * FAR_FREQ_A)
			+ FAR_AMP_B * sin(float(col) * FAR_FREQ_B + 1.7)) * far
	return clampi(int(round(h)) + terrace(col), SURFACE_ROW_MIN, SURFACE_ROW_MAX)


## The accumulated scarp offset at a column: which terrace this ground belongs to. Public because the
## worldgen guard must tell a designed face from a hillside the budget failed to keep walkable.
##
## Measured FROM THE PAD. Accumulating from column zero left the fixtures' flat ground five rows below the
## terrain either side, putting the base in a bowl with unclimbable walls: the fast-forward guard stalled
## at 297px and the worldgen guard reported a stray five-row rise at column 38.
static func terrace(col: int) -> int:
	return _terrace_raw(col) - _terrace_raw(BASE_PAD_START)


static func _terrace_raw(col: int) -> int:
	var out: int = 0
	for i: int in SCARP_COLS.size():
		var at: int = SCARP_COLS[i]
		if col <= at:
			continue
		# Fall over SCARP_SPAN columns so the face is a face rather than a single cliff edge, and still past a jump.
		out += int(round(float(SCARP_STEPS[i]) * clampf(float(col - at) / float(SCARP_SPAN), 0.0, 1.0)))
	return out


## Is this column ON a scarp face, the marked exception to the walkable-step contract?
static func on_scarp(col: int) -> bool:
	for at: int in SCARP_COLS:
		if col > at and col <= at + SCARP_SPAN:
			return true
	return false
