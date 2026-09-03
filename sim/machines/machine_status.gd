class_name MachineStatus
extends RefCounted

## The per-machine status read the HUD and the hover show: `machine_status` 417 and the `_status_*`
## reads of `legacy/src/core/factory_sim.gd`, lifted in A' step 3d (D0349). Every read mirrors its
## runner's gates in the runner's order, so what the status says is what the tick will do. Pure reads.

static func of(m: MachineState, world: World, machines: Machines) -> StringName:
	match m.def.behavior:
		&"drill":
			return _status_drill(m, world, machines)
		&"generator":
			return &"no_fuel" if m.fuel <= 0 and int(m.input_buffer.get(&"coal", 0)) <= 0 else &"working"
		&"hopper":
			return _status_hopper(m, world, machines)
		&"pump":
			return _status_pump(m, world, machines)
		&"lift", &"winch_station":
			return Movers.status_mover(m)
		&"winch_head":
			return Movers.status_winch_head(m, machines)
	var recipe: RecipeDef = m.def.recipe
	if recipe == null:
		return &"idle"
	return &"working" if Runners.has_inputs(m, recipe) else &"no_input"


## Drill status: something to bore, then a drain, then fuel. Spent is not starved: a head that has pulled
## something and has no lode left under it reads spent; a misplaced drill still reads no_input.
static func _status_drill(m: MachineState, world: World, machines: Machines) -> StringName:
	var on_lode: Vector2i = Runners.drill_lode_target(world, m.logic_cell)
	if on_lode == Runners.NONE and m.fed > 0:
		return &"spent"
	var t: Vector2i = on_lode if on_lode != Runners.NONE else Runners.drill_target(world, machines, m.logic_cell)
	if t == Runners.NONE:
		return &"no_input"
	if on_lode == Runners.NONE and Runners.drill_blocked(world, machines, t):
		return &"blocked"
	if m.fuel <= 0 and int(m.input_buffer.get(&"coal", 0)) <= 0:
		return &"no_fuel"
	return &"working"


static func _status_hopper(m: MachineState, world: World, machines: Machines) -> StringName:
	if m.filter != &"" and m.input_buffer.has(m.filter):
		var below: MachineState = machines.first_machine_below(world, m.logic_cell)
		if below != null and Runners.buffer_load(below.input_buffer) >= m.def.feed_cap:
			return &"blocked"
	return &"working" if not m.input_buffer.is_empty() else &"idle"


## No power is idle; powered but with the reachable column already dry is idle, benignly; powered with
## water in reach is working.
static func _status_pump(m: MachineState, world: World, machines: Machines) -> StringName:
	if machines.power_throttle(m.logic_cell, m.def.power_demand_milli) <= 0:
		return &"idle"
	for dy: int in range(0, m.def.reach):
		var c: Vector2i = m.logic_cell + Vector2i(0, dy)
		if not world.logic_in_bounds(c) or world.logic_solid(c):
			break
		for terrain_cell: Vector2i in world.terrain_cells_of(c):
			if world.water.water_at(terrain_cell) > 0:
				return &"working"
	return &"idle"
