class_name World
extends RefCounted

## THE ONE OWNER OF THE PLANES: `grid` (4 px terrain, `TileGrid`), `logic` (the 16 px placed planes,
## `LogicGrid`), `water` (4 px levels, `WaterPlane`) and `deposits` (ore yield and the lode, `DepositPlane`, D0348). `docs/adr/0009-metre-cell-planes-over-the-terrain-grid.md`
## is the contract; this file is its derivations and the terrain verbs. Lifted in A' step 3b (D0347) from
## the verbs `legacy/src/core/factory_sim.gd` kept on the hub -- `set_solid` 703, `set_wall` 723,
## `block_supported` 908, `cell_occupied` 927, `place_block` 935 -- with one change of shape: legacy's
## cell was the metre, so `solid.has(cell)` answered everything; here a metre covers sixteen terrain cells
## and can be rock, air, or half-dug, so every metre-cell fact is DERIVED below and named for what it
## means. Pack accounting (legacy spent the inventory inside these verbs) is not here: the verbs return
## what they did and the items sub-step wraps them (ADR 0009 §5).

const N: int = LogicGrid.TERRAIN_PER_LOGIC
const ORTHO: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]

var grid: TileGrid
var logic: LogicGrid = LogicGrid.new()
var water: WaterPlane = WaterPlane.new()
var deposits: DepositPlane = DepositPlane.new()


func _init(terrain: TileGrid) -> void:
	grid = terrain


## A metre cell is in bounds when all sixteen of its terrain cells are.
func logic_in_bounds(logic_cell: Vector2i) -> bool:
	return logic_cell.x >= 0 and logic_cell.y >= 0 \
		and (logic_cell.x + 1) * N <= grid.width and (logic_cell.y + 1) * N <= grid.height


## The sixteen terrain cells a metre covers, row-major.
func terrain_cells_of(logic_cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy: int in N:
		for dx: int in N:
			out.append(Vector2i(logic_cell.x * N + dx, logic_cell.y * N + dy))
	return out


## The four terrain cells of the NEIGHBOURING metre along the edge it shares with `logic_cell`, one
## metre-step `logic_dir` away. For `logic_dir = (0, 1)` that is the row directly under the cell's floor.
func terrain_face_cells(logic_cell: Vector2i, logic_dir: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x0: int = logic_cell.x * N
	var y0: int = logic_cell.y * N
	for i: int in N:
		if logic_dir == Vector2i(0, 1):
			out.append(Vector2i(x0 + i, y0 + N))
		elif logic_dir == Vector2i(0, -1):
			out.append(Vector2i(x0 + i, y0 - 1))
		elif logic_dir == Vector2i(1, 0):
			out.append(Vector2i(x0 + N, y0 + i))
		else:
			out.append(Vector2i(x0 - 1, y0 + i))
	return out


## All sixteen solid: whole rock.
func logic_solid(logic_cell: Vector2i) -> bool:
	for terrain_cell: Vector2i in terrain_cells_of(logic_cell):
		if not grid.is_solid(terrain_cell):
			return false
	return true


## All sixteen air: a whole open metre. Half-dug is neither this nor `logic_solid`.
func logic_air(logic_cell: Vector2i) -> bool:
	for terrain_cell: Vector2i in terrain_cells_of(logic_cell):
		if grid.is_solid(terrain_cell):
			return false
	return true


## Where a placed thing can go: in bounds, wholly air, nothing placed.
func logic_open(logic_cell: Vector2i) -> bool:
	return logic_in_bounds(logic_cell) and logic_air(logic_cell) and not logic.is_occupied(logic_cell)


## Legacy's single occupancy gate (`factory_sim.gd:927`): any rock in the metre, or anything placed.
## Conservative on purpose -- a rope does not hang through a sliver of rock.
func cell_occupied(logic_cell: Vector2i) -> bool:
	return not logic_air(logic_cell) or logic.is_occupied(logic_cell)


## Any of the sixteen has a wall behind it: a dug room keeps its wall, so a block can backfill it.
func wall_backs(logic_cell: Vector2i) -> bool:
	for terrain_cell: Vector2i in terrain_cells_of(logic_cell):
		if grid.get_wall(terrain_cell) != &"":
			return true
	return false


## The neighbouring metre presents a FULL face along the shared edge: four solid terrain cells, all in
## bounds. Down, that is a floor across the whole metre.
func face_solid(logic_cell: Vector2i, logic_dir: Vector2i) -> bool:
	for terrain_cell: Vector2i in terrain_face_cells(logic_cell, logic_dir):
		if not grid.in_bounds(terrain_cell) or not grid.is_solid(terrain_cell):
			return false
	return true


## The four cells of the face below are all a soil material (`data/materials` `soil: true`).
func soil_below(logic_cell: Vector2i) -> bool:
	for terrain_cell: Vector2i in terrain_face_cells(logic_cell, Vector2i(0, 1)):
		if not WorldMaterials.is_soil(grid.get_material(terrain_cell)):
			return false
	return true


## Can a building block be placed here? Legacy's adjacency rule (`factory_sim.gd:908`): a wall backs
## the cell, or an orthogonal neighbour is something to build off -- a full solid face, a machine, or a
## conduit. A pure read. The CONTROLLER gates block placement on it rather than `place_block`, because
## machines are exempt (a lift is legitimately placed in an open shaft) and worldgen places freely.
func block_supported(logic_cell: Vector2i) -> bool:
	if wall_backs(logic_cell):
		return true
	for logic_dir: Vector2i in ORTHO:
		var nb: Vector2i = logic_cell + logic_dir
		if face_solid(logic_cell, logic_dir):
			return true
		var kind: StringName = logic.occupant(nb)
		if kind == LogicGrid.KIND_MACHINE or kind == LogicGrid.KIND_CONDUIT:
			return true
	return false


## Something to mount a torch on: a wall behind, or any full solid face (`factory_sim.gd:1073-1076`).
func backed(logic_cell: Vector2i) -> bool:
	if wall_backs(logic_cell):
		return true
	for logic_dir: Vector2i in ORTHO:
		if face_solid(logic_cell, logic_dir):
			return true
	return false


## Seed or clear a whole metre of terrain. `&""` excavates the sixteen cells (revealing their walls, as
## digging does); otherwise every cell becomes `material` and the water in each is displaced -- "rock
## displaces water: the two layers never coexist in a cell" (`factory_sim.gd:708`), the coupling D0344
## deferred to here. Returns the units of water displaced so the caller can account for them. Out of
## bounds is a no-op returning 0.
func set_solid(logic_cell: Vector2i, material: StringName) -> int:
	if not logic_in_bounds(logic_cell):
		return 0
	var displaced: int = 0
	for terrain_cell: Vector2i in terrain_cells_of(logic_cell):
		if material == &"":
			grid.excavate(terrain_cell)
		else:
			grid.set_material(terrain_cell, material)
			displaced += water.displace(terrain_cell)
	return displaced


## Set or clear the background wall across a whole metre (`&""` clears). Discrete edit like set_solid.
func set_wall(logic_cell: Vector2i, material: StringName) -> void:
	if not logic_in_bounds(logic_cell):
		return
	for terrain_cell: Vector2i in terrain_cells_of(logic_cell):
		grid.set_wall(terrain_cell, material)


## The building primitive, the inverse of mine: a carried block into an open metre, which becomes solid.
## Refuses out-of-bounds and occupied cells (any rock, anything placed) -- "every placed layer is
## mutually exclusive: clear the cell first". Does NOT check `block_supported` (see it). Returns whether
## the block went down; the water it displaced is read back through `water` by the caller that ledgers.
func place_block(logic_cell: Vector2i, material: StringName) -> bool:
	if material.is_empty() or not logic_in_bounds(logic_cell) or cell_occupied(logic_cell):
		return false
	set_solid(logic_cell, material)
	return true


## The planes' running signatures, joined. Each keeps its own lanes and its own rebuild check.
func state_signature() -> String:
	return "%s|%s|%s|%s" % [grid.state_signature(), logic.state_signature(), water.state_signature(), deposits.state_signature()]


func recomputed_signature() -> String:
	return "%s|%s|%s|%s" % [grid.recomputed_signature(), logic.recomputed_signature(), water.recomputed_signature(), deposits.recomputed_signature()]


func clone() -> World:
	var copy: World = World.new(grid.clone())
	copy.logic = logic.clone()
	copy.water = water.clone()
	copy.deposits = deposits.clone()
	return copy
