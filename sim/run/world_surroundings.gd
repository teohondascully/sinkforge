class_name WorldSurroundings
extends Surroundings

## The body's surroundings answered from the world and the machines (A' step 5c, D0360): legacy
## `player.gd`'s `_blocks`, `_in_water`, `is_climbable` and `updraft_at` reads, composed here in `sim/run`
## so `sim/body` never depends on `sim/machines` or `sim/transport`. `Interface` hands one to the body it
## owns; a body without one runs on the `Surroundings` base, bare terrain.

const N: int = LogicGrid.TERRAIN_PER_LOGIC
## Wood and leaves are walk-through: tree trunks and foliage never wall the body (legacy `player.gd:566`);
## a body taller than a tile would otherwise be walled by any trunk.
const PASSABLE: Array[StringName] = [&"wood", &"leaves"]

var _world: World
var _machines: Machines


func _init(world: World, machines: Machines) -> void:
	_world = world
	_machines = machines


## Solid terrain blocks unless it is wood or leaves; a machine blocks on its one logic cell, which is its
## base (`docs/ARCHITECTURE.md` §9: "non-solid to the player except a 1-tile base" -- every machine here
## is one tile, so the base is the machine).
func blocks(grid: TileGrid, terrain_cell: Vector2i) -> bool:
	if grid.is_solid(terrain_cell):
		return not PASSABLE.has(grid.get_material(terrain_cell))
	return _machines.machine_at(logic_of(terrain_cell)) != null


func is_climbable(logic_cell: Vector2i) -> bool:
	return _world.logic.is_climbable(logic_cell)


func water_at(terrain_cell: Vector2i) -> int:
	return _world.water.water_at(terrain_cell)


func updraft_at(logic_cell: Vector2i) -> bool:
	return Flow.updraft_at(_world, _machines, logic_cell)


## The logic cell a terrain cell lies in, floored for the negative cells a body can touch at the edge.
static func logic_of(terrain_cell: Vector2i) -> Vector2i:
	var x: int = terrain_cell.x - (N - 1 if terrain_cell.x < 0 else 0)
	var y: int = terrain_cell.y - (N - 1 if terrain_cell.y < 0 else 0)
	return Vector2i(x / N, y / N)
