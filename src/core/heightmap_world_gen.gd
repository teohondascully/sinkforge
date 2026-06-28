class_name HeightmapWorldGen
extends WorldGen

## The first concrete generator — reproduces today's hand-seeded world through the WorldData
## contract: an undulating heightmap surface (flat across the spawn/forge region so the motion
## harness stays valid), earth down to a depth then a STONE layer (the "richer" smoke test that
## proves extending generation is a localized change), and seeded ore veins scattered in the rock.
## Walls are filled in Slice 3. Deterministic in (cols, rows, seed) via a seeded RNG.

## Spawn/forge region (columns <= this) is kept flat so the player + harness have stable ground.
const FLAT_COLS: int = 8
const FLAT_SURFACE_ROW: int = 5
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

	# Surface + fill: earth near the top, stone below STONE_DEPTH.
	var surface: PackedInt32Array = PackedInt32Array()
	for col: int in cols:
		var top: int = _surface_row(col)
		surface.append(top)
		for row: int in range(top, rows):
			var below: int = row - top
			world.blocks[Vector2i(col, row)] = &"stone" if below >= STONE_DEPTH else &"earth"

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
	if col <= FLAT_COLS:
		return FLAT_SURFACE_ROW
	var h: float = 5.0 - 2.2 * sin(float(col) * 0.30) - 1.1 * sin(float(col) * 0.11 + 1.7)
	return clampi(int(round(h)), 3, 11)
