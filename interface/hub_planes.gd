## The hub's planes copied onto an `Interface.Observation` (A' step 4, D0356), window-bounded, every
## container duplicated so a view cannot reach back through it. Split out of `interface.gd` the way
## the window cache was: `observe` stays a flat list of field reads.
extends RefCounted

const N: int = LogicGrid.TERRAIN_PER_LOGIC


static func fill(o: RefCounted, world: World, items: Items, machines: Machines) -> void:
	var w: Rect2i = o.window
	o.logic_window = Rect2i(Vector2i(Aim.floor_div(w.position.x, N), Aim.floor_div(w.position.y, N)), Vector2i.ZERO)
	var far := Vector2i((w.end.x + N - 1) / N, (w.end.y + N - 1) / N)
	o.logic_window.size = far - o.logic_window.position
	_fill_terrain_planes(o, world, w)
	_fill_metre_planes(o, world, items, machines)
	o.ore_default = DepositPlane.DEFAULT_ORE_DEPOSIT
	o.pack = items.pack.slots()
	o.pack_bulk = items.pack.carried_bulk()
	o.pack_bulk_cap = Pack.bulk_cap()
	o.pack_slots = Pack.inventory_slots()
	o.sink = items.piles.sink.duplicate()
	o.winch_routes = machines.winch_routes.duplicate()
	o.winch_transit = machines.winch_transit.duplicate(true)


static func _fill_terrain_planes(o: RefCounted, world: World, w: Rect2i) -> void:
	o.water = PackedByteArray()
	o.water.resize(w.size.x * w.size.y)
	var wet: Array[Vector2i] = []   # typed local, then assigned: an untyped `[]` cannot land on a typed field
	for terrain_cell: Vector2i in world.water.wet_terrain_cells():
		if w.has_point(terrain_cell):
			o.water[(terrain_cell.y - w.position.y) * w.size.x + (terrain_cell.x - w.position.x)] = world.water.water_at(terrain_cell)
			wet.append(terrain_cell)
	o.wet_cells = wet
	o.lodes = {}
	for terrain_cell: Vector2i in world.deposits.lode_terrain_cells():
		if w.has_point(terrain_cell):
			o.lodes[terrain_cell] = {"material": world.deposits.lode_at(terrain_cell),
				"amount": world.deposits.ore_deposit_at(world.grid, terrain_cell),
				"permille": world.deposits.lode_permille(terrain_cell)}
	o.ore_yield = {}
	for terrain_cell: Vector2i in Ordering.cells(world.deposits.deposits):
		if w.has_point(terrain_cell) and not o.lodes.has(terrain_cell) and world.grid.is_solid(terrain_cell):
			o.ore_yield[terrain_cell] = int(world.deposits.deposits[terrain_cell])
	o.ore_like_legend = PackedByteArray()
	o.ore_like_legend.resize(o.legend.size())
	for i: int in o.legend.size():
		o.ore_like_legend[i] = 1 if WorldMaterials.is_ore_like(StringName(o.legend[i])) else 0


static func _fill_metre_planes(o: RefCounted, world: World, items: Items, machines: Machines) -> void:
	var lw: Rect2i = o.logic_window
	o.placed = {}
	o.conduit_tiers = {}
	for cell: Vector2i in Ordering.cells(world.logic.placed):
		if lw.has_point(cell):
			o.placed[cell] = world.logic.placed[cell]
			if world.logic.has_conduit(cell):
				o.conduit_tiers[cell] = world.logic.conduit_tier(cell)
	o.saplings = {}
	for cell: Vector2i in world.logic.sapling_logic_cells():
		if lw.has_point(cell):
			o.saplings[cell] = world.logic.sapling_age(cell)
	var records: Array[Dictionary] = []   # typed here: `o` is reached dynamically and an untyped [] refuses
	for m: MachineState in machines.machines:
		if lw.has_point(m.logic_cell):
			records.append(_machine_record(m, world, machines))
	o.machines = records
	o.power = {}
	for cell: Vector2i in Ordering.cells(machines.power):
		if lw.has_point(cell):
			o.power[cell] = machines.power[cell]
	o.piles = {}
	for cell: Vector2i in items.piles.pile_logic_cells():
		if lw.has_point(cell):
			o.piles[cell] = (items.piles.ground[cell] as Dictionary).duplicate()


static func _machine_record(m: MachineState, world: World, machines: Machines) -> Dictionary:
	var progress: int = 0
	if m.def.recipe != null and m.def.recipe.time_ticks > 0:
		progress = clampi(m.progress_ticks * 1000 / m.def.recipe.time_ticks, 0, 1000)
	return {"cell": m.logic_cell, "id": m.def.id, "behavior": m.def.behavior,
		"status": MachineStatus.of(m, world, machines), "power_permille": m.power_permille,
		"progress_permille": progress, "facing": m.facing, "fuel": m.fuel, "filter": m.filter,
		"input": m.input_buffer.duplicate(), "output": m.output_buffer.duplicate()}
