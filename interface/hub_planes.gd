## The hub's planes copied onto an `Interface.Observation` (A' step 4, D0356), window-bounded, every
## container duplicated so a view cannot reach back through it. Split out of `interface.gd` the way
## the window cache was: `observe` stays a flat list of field reads.
extends RefCounted

const N: int = LogicGrid.TERRAIN_PER_LOGIC


static func fill(o: RefCounted, world: World, items: Items, machines: Machines, cache: HubCache) -> void:
	var w: Rect2i = o.window
	o.logic_window = Rect2i(Vector2i(Aim.floor_div(w.position.x, N), Aim.floor_div(w.position.y, N)), Vector2i.ZERO)
	var far := Vector2i((w.end.x + N - 1) / N, (w.end.y + N - 1) / N)
	o.logic_window.size = far - o.logic_window.position
	_fill_water(o, world, w, cache)
	_fill_deposits(o, world, w, cache)
	_fill_placed(o, world, cache)
	_fill_metre_planes(o, world, items, machines)
	o.ore_default = DepositPlane.DEFAULT_ORE_DEPOSIT
	o.pack = items.pack.slots()
	o.pack_bulk = items.pack.carried_bulk()
	o.pack_bulk_cap = Pack.bulk_cap()
	o.pack_slots = Pack.inventory_slots()
	o.sink = items.piles.sink.duplicate()
	o.winch_routes = machines.winch_routes.duplicate()
	o.winch_transit = machines.winch_transit.duplicate(true)


## The keys of `keyed` inside `w`, in scan order: filter first, then sort the few that are in the window.
static func _inside(keyed: Dictionary, w: Rect2i) -> Array[Vector2i]:
	var hit: Dictionary = {}
	for terrain_cell: Vector2i in keyed:
		if w.has_point(terrain_cell):
			hit[terrain_cell] = true
	return Ordering.cells_native(hit)


static func _fill_water(o: RefCounted, world: World, w: Rect2i, cache: HubCache) -> void:
	var key: Array = [world.water.version, w]
	if cache.water_key != key:
		cache.rebuilds += 1
		cache.water_key = key
		cache.water = PackedByteArray()
		cache.water.resize(w.size.x * w.size.y)
		cache.wet_cells = _inside(world.water.levels, w)
		for terrain_cell: Vector2i in cache.wet_cells:
			cache.water[(terrain_cell.y - w.position.y) * w.size.x + (terrain_cell.x - w.position.x)] = world.water.water_at(terrain_cell)
	o.water = cache.water
	o.wet_cells = cache.wet_cells


static func _fill_deposits(o: RefCounted, world: World, w: Rect2i, cache: HubCache) -> void:
	var lode_key: Array = [world.deposits.version, world.grid.terrain_version, w]   # `ore_deposit_at` reads solidity
	if cache.lode_key != lode_key:
		cache.rebuilds += 1
		cache.lode_key = lode_key
		if cache.lode_index_version != world.deposits.version:
			cache.lode_index = HubCache.index_of(world.deposits.lode)
			cache.lode_index_version = world.deposits.version
		cache.lodes = {}
		var hit: Dictionary = {}
		for terrain_cell: Vector2i in HubCache.inside_indexed(cache.lode_index, w):
			hit[terrain_cell] = true
		for terrain_cell: Vector2i in Ordering.cells_native(hit):
			cache.lodes[terrain_cell] = {"material": world.deposits.lode_at(terrain_cell),
				"amount": world.deposits.ore_deposit_at(world.grid, terrain_cell),
				"permille": world.deposits.lode_permille(terrain_cell)}
	o.lodes = cache.lodes
	var yield_key: Array = [world.deposits.version, world.grid.terrain_version, w]   # reads solidity too
	if cache.yield_key != yield_key:
		cache.rebuilds += 1
		cache.yield_key = yield_key
		if cache.yield_index_version != world.deposits.version:
			cache.yield_index = HubCache.index_of(world.deposits.deposits)
			cache.yield_index_version = world.deposits.version
		cache.ore_yield = {}
		for terrain_cell: Vector2i in HubCache.inside_indexed(cache.yield_index, w):
			if not cache.lodes.has(terrain_cell) and world.grid.is_solid(terrain_cell):
				cache.ore_yield[terrain_cell] = int(world.deposits.deposits[terrain_cell])
	o.ore_yield = cache.ore_yield
	o.ore_like_legend = PackedByteArray()
	o.ore_like_legend.resize(o.legend.size())
	for i: int in o.legend.size():
		o.ore_like_legend[i] = 1 if WorldMaterials.is_ore_like(StringName(o.legend[i])) else 0


static func _fill_placed(o: RefCounted, world: World, cache: HubCache) -> void:
	var lw: Rect2i = o.logic_window
	var key: Array = [world.logic.version, lw]
	if cache.placed_key != key:
		cache.rebuilds += 1
		cache.placed_key = key
		cache.placed = {}
		cache.conduit_tiers = {}
		for cell: Vector2i in world.logic.placed:
			if lw.has_point(cell):
				cache.placed[cell] = world.logic.placed[cell]
				if world.logic.has_conduit(cell):
					cache.conduit_tiers[cell] = world.logic.conduit_tier(cell)
		cache.saplings = {}
		for cell: Vector2i in world.logic.sapling_logic_cells():
			if lw.has_point(cell):
				cache.saplings[cell] = world.logic.sapling_age(cell)
	o.placed = cache.placed
	o.conduit_tiers = cache.conduit_tiers
	o.saplings = cache.saplings


static func _fill_metre_planes(o: RefCounted, world: World, items: Items, machines: Machines) -> void:
	var lw: Rect2i = o.logic_window
	var records: Array[Dictionary] = []   # typed here: `o` is reached dynamically and an untyped [] refuses
	for m: MachineState in machines.machines:
		if lw.has_point(m.logic_cell):
			records.append(_machine_record(m, world, machines))
	o.machines = records
	o.power = {}
	for cell: Vector2i in machines.power:
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
		"source": m.def.recipe != null and m.def.recipe.inputs.is_empty(),   # a no-input recipe: reads as a furnace (6b)
		"name": m.def.display_name, "recipe": m.def.recipe.id if m.def.recipe != null else &"",   # the painter's nameplate and ports (6c)
		"status": MachineStatus.of(m, world, machines), "power_permille": m.power_permille,
		"progress_permille": progress, "facing": m.facing, "fuel": m.fuel, "filter": m.filter,
		"input": m.input_buffer.duplicate(), "output": m.output_buffer.duplicate()}
