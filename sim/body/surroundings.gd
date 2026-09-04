class_name Surroundings
extends RefCounted

## What the body moves through beyond bare terrain (A' step 5c, D0360): whether a cell blocks it, whether
## a rope hangs here, how much water a cell holds, whether a lift's draft rises through it. The body
## reads its surroundings through this and nothing else, so `sim/body` keeps its dependency list (core,
## world, invariants) while the answers can come from the machines and the placed layer.
##
## THIS BASE IS THE BODY AS IT ALWAYS WAS: solid terrain blocks, nothing is climbable, nothing is wet,
## no draft. A body built without a world -- every body suite, the calibrated hostile chamber, the
## movement course -- runs on it bit for bit as before. `sim/run/world_surroundings.gd` overrides the
## four answers from the world and the machines, and `Interface` hands that to the body it owns.


func blocks(grid: TileGrid, terrain_cell: Vector2i) -> bool:
	return grid.is_solid(terrain_cell)


func is_climbable(_logic_cell: Vector2i) -> bool:
	return false


func water_at(_terrain_cell: Vector2i) -> int:
	return 0


func updraft_at(_logic_cell: Vector2i) -> bool:
	return false
