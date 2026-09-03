class_name Runners
extends RefCounted

## THE PER-TICK RUNNERS, one per behaviour, and the behaviour registry that names them. Lifted in A'
## step 3d (D0349) from `legacy/src/core/factory_sim.gd`: `_BEHAVIORS` 149, `_behavior_flag` 572,
## `_run_machine` 2071, `_run_recipe` 2081, `_has_inputs`, `_run_pump` 2150, `_run_hopper` 2301,
## `_run_drill` 2532 (+ `drill_target` 2418, `_drill_blocked` 2439, `drill_lode_target` 2462,
## `_live_mouths` 463, `head_coverage` 497), `_run_generator` 2946.
##
## Every number a runner reads is a field of the machine's record (`MachineDef`); the runner is the
## logic. Time is ticks (`progress_ticks`, `time_ticks`, `fuel_ticks`), power is milli-units and the
## throttle per-mille (plan §5.1). Legacy dispatched by `call(entry["run"])` on the hub; a static class
## has no instance to call by name, so the registry keeps the FLAGS and dispatch is a `match` on the same
## tag, which reads the same and cannot name a method that does not exist.
##
## The lift and the winch are `Movers` (step 3e, D0350); splitter, crusher and spur wait on a ruling
## (plan §8). A tag with no runner runs the default recipe, as legacy's table did for an unknown tag.
##
## THE DRILL ON THE METRE GRID (D0349): its target is a metre cell (`World.logic_ore_body`), it bores one
## unit a cycle with `World.bore_one`, which drains and excavates the metre's 4 px cells in scan order,
## and the freed unit pours down its own column from the bored metre. A head on a lode drains the metre's
## lode cells one unit a cycle the same way. `head_coverage` is the head's own cell until Spur is ruled.

const BEHAVIORS: Dictionary = {
	&"lift": {"updraft": true},
	&"generator": {"power_source": true},
}
const COAL_BURNERS: Array[StringName] = [&"drill", &"h_drill", &"generator"]   # legacy :380
const NONE: Vector2i = Vector2i(-1, -1)


## Does this def's behavior entry set `flag`? The registry read for one-off behavior queries such as
## the power sweep and updraft_at, so a second generator-like machine needs no change.
static func behavior_flag(def: MachineDef, flag: StringName) -> bool:
	return bool((BEHAVIORS.get(def.behavior, {}) as Dictionary).get(flag, false))


## Dispatch a machine's per-tick work by its behaviour tag; no runner = the default recipe-runner.
static func run(m: MachineState, world: World, items: Items, machines: Machines) -> void:
	match m.def.behavior:
		&"drill":
			_run_drill(m, world, items, machines)
		&"generator":
			_run_generator(m, items)
		&"hopper":
			_run_hopper(m, world, machines)
		&"pump":
			_run_pump(m, world, machines)
		&"lift":
			Movers.run_lift(m, machines)
		&"winch_head":
			Movers.run_winch_head(m, machines)
		&"winch_station":
			pass                                  # a pure receiver: the Head lands trips in it
		_:
			_run_recipe(m, items)


## The DEFAULT machine, a named recipe-runner: consume the recipe's inputs over its cycle time and
## produce its outputs. The only place items are created or destroyed, so conservation holds.
static func _run_recipe(m: MachineState, items: Items) -> void:
	var recipe: RecipeDef = m.def.recipe
	if recipe == null:
		return
	# PASS-THROUGH: every machine is a filter for what its recipe WANTS; anything else moves through to
	# the output and falls on down the column. A mixed drill stream therefore sorts itself down a machine
	# stack (the forge keeps ore, the coal pours past into the generator below), and junk can never clog
	# an input buffer. Conservation-neutral.
	for item: StringName in m.input_buffer.keys():
		if not recipe.inputs.has(item):
			m.output_buffer[item] = int(m.output_buffer.get(item, 0)) + int(m.input_buffer[item])
			m.input_buffer.erase(item)
	if not has_inputs(m, recipe):
		return
	m.progress_ticks += 1
	if m.progress_ticks < recipe.time_ticks:
		return
	m.progress_ticks -= recipe.time_ticks
	for item: StringName in recipe.inputs:
		var n: int = int(recipe.inputs[item])
		_take_from_buffer(m.input_buffer, item, n)
		items.consumed(item, n)
	for item: StringName in recipe.outputs:
		var n: int = int(recipe.outputs[item])
		m.output_buffer[item] = int(m.output_buffer.get(item, 0)) + n
		items.produced(item, n)


static func has_inputs(m: MachineState, recipe: RecipeDef) -> bool:
	for item: StringName in recipe.inputs:
		if int(m.input_buffer.get(item, 0)) < int(recipe.inputs[item]):
			return false
	return true


## Take `n` of `item` out of a buffer, keeping it free of dead zero-count keys.
static func _take_from_buffer(buffer: Dictionary, item: StringName, n: int) -> void:
	var left: int = int(buffer.get(item, 0)) - n
	if left > 0:
		buffer[item] = left
	else:
		buffer.erase(item)


## Burn one tick of the current fuel; when it is spent, refuel from the coal in the input buffer,
## crediting the coal as consumed. Returns false when there is neither fuel nor coal.
static func _burn_or_refuel(m: MachineState, items: Items) -> bool:
	if m.fuel > 0:
		return true
	if int(m.input_buffer.get(&"coal", 0)) <= 0:
		return false
	_take_from_buffer(m.input_buffer, &"coal", 1)
	items.consumed(&"coal", 1)
	m.fuel = m.def.fuel_ticks
	return true


## A generator burns coal into power (which `PowerFlow` reads off `fuel > 0`); it makes no item.
static func _run_generator(m: MachineState, items: Items) -> void:
	if m.fuel > 0:
		m.fuel -= 1
	if m.fuel <= 0:
		_burn_or_refuel(m, items)


## THE PUMP: while POWERED it DRAINS water out of its own metre and the metres straight below it. Water
## fell in for free; pumping it back out costs power. The budget is round(rate x throttle), spent
## top-down over `reach` metres, sixteen cells each in scan order; a solid metre or the world floor ends
## the reach. `rate` is legacy's per-metre-cell figure, converted x16 to this plane's cells (D0344).
static func _run_pump(m: MachineState, world: World, machines: Machines) -> void:
	m.power_permille = machines.power_throttle(m.logic_cell, m.def.power_demand_milli)
	var budget: int = (m.def.rate * World.N * World.N * m.power_permille + 500) / 1000
	if budget <= 0:
		return                                   # unpowered -> no free drain (the cost rule, one place)
	for dy: int in range(0, m.def.reach):
		if budget <= 0:
			break
		var c: Vector2i = m.logic_cell + Vector2i(0, dy)
		if not world.logic_in_bounds(c) or world.logic_solid(c):
			break                                # rock caps the column: nothing watered lies below it
		for terrain_cell: Vector2i in world.terrain_cells_of(c):
			if budget <= 0:
				break
			budget -= world.water.remove_water(terrain_cell, budget)


## THE HOPPER: keeps the first thing it tastes (the filter latches on insertion order, by design), passes
## everything else through, and meters `release` of the banked good a tick into the first machine below
## while that machine holds fewer than `feed_cap`. With nothing to feed it is storage.
static func _run_hopper(m: MachineState, world: World, machines: Machines) -> void:
	if m.input_buffer.is_empty():
		return
	if m.filter == &"":
		m.filter = m.input_buffer.keys()[0]     # deterministic: insertion order
	for item: StringName in m.input_buffer.keys():
		if item == m.filter:
			continue                            # the banked good, metered below
		m.output_buffer[item] = int(m.output_buffer.get(item, 0)) + int(m.input_buffer[item])
		m.input_buffer.erase(item)
	if not m.input_buffer.has(m.filter):
		return
	var below: MachineState = machines.first_machine_below(world, m.logic_cell)
	if below == null or buffer_load(below.input_buffer) >= m.def.feed_cap:
		return                                  # nothing to feed, or the consumer is backed up: hold
	var take: int = mini(int(m.input_buffer[m.filter]), m.def.release)
	m.output_buffer[m.filter] = int(m.output_buffer.get(m.filter, 0)) + take
	_take_from_buffer(m.input_buffer, m.filter, take)


static func buffer_load(buffer: Dictionary) -> int:
	var load: int = 0
	for item: StringName in buffer:
		load += int(buffer[item])
	return load


## THE DRILL: bores the deepest ore body in its column one unit a cycle, burning coal, and pours the
## freed unit down the column from the bored metre. A head standing on a lode drains the lode in place
## instead and clears nothing. Gates in order: something to bore, a drain below it, fuel.
static func _run_drill(m: MachineState, world: World, items: Items, machines: Machines) -> void:
	var recipe: RecipeDef = m.def.recipe
	if recipe == null:
		return
	var lode_cell: Vector2i = drill_lode_target(world, m.logic_cell)
	var target: Vector2i = lode_cell if lode_cell != NONE else drill_target(world, machines, m.logic_cell)
	if target == NONE:
		return                          # nothing borable below: idle, hold progress
	if lode_cell == NONE and drill_blocked(world, machines, target):
		return                          # ore has no drain below: stall, and the status reads "blocked"
	if not _burn_or_refuel(m, items):
		return                          # out of fuel, no coal -> idle ("feed me coal")
	m.fuel -= _live_mouths(world, m.logic_cell) if lode_cell != NONE else 1
	m.progress_ticks += 1
	if m.progress_ticks < recipe.time_ticks:
		return
	m.progress_ticks -= recipe.time_ticks
	if lode_cell != NONE:
		_pull_lode(m, world, items)
		return
	var item: StringName = world.bore_one(target)
	if item == &"":
		return
	if world.logic_air(target):
		items.resettle_pile_above(target)     # the metre is bored out: anything resting above now falls
	items.produced(item, 1)
	items.eject(target + Vector2i(0, 1), item, 1, target)


## ONE COLUMN, ONE DRAIN: every covered lode cell gives up a unit and all of it pours out of the head's
## own column. `fed` counts what this head has pulled; it is how `spent` is known.
static func _pull_lode(m: MachineState, world: World, items: Items) -> void:
	var pulled: int = 0
	for c: Vector2i in head_coverage(m.logic_cell):
		for terrain_cell: Vector2i in world.terrain_cells_of(c):
			var vein: StringName = world.deposits.take_one(world.grid, terrain_cell)
			if vein == &"":
				continue
			items.produced(vein, 1)
			items.eject(m.logic_cell + Vector2i(0, 1), vein, 1, c)
			pulled += 1
			break                       # one unit per covered metre per cycle
	m.fed += pulled


## The deepest ore body straight down `logic_cell`'s column, or NONE. Scans through the drill's own shaft
## and air gaps, stops at a machine (a collection point) or at rock that is not ore.
static func drill_target(world: World, machines: Machines, logic_cell: Vector2i) -> Vector2i:
	var deepest: Vector2i = NONE
	for dy: int in range(0, Landing.floor_rows(world)):
		var c := Vector2i(logic_cell.x, logic_cell.y + dy)
		if not world.logic_in_bounds(c):
			break
		if not world.logic_air(c):
			if world.logic_ore_body(c):
				deepest = c            # remember it, keep scanning deeper for the true bottom of the body
			else:
				break                  # solid rock caps the column: the body bottomed out here
		elif dy > 0 and machines.machine_at(c) != null:
			break                      # a machine below -> collection point, stop scanning
	return deepest


## True when the deepest ore has nowhere to DRAIN: the metre directly below it is rock or the world
## floor, so a freed unit would pile against the body it came out of. A machine below collects it.
static func drill_blocked(world: World, machines: Machines, target: Vector2i) -> bool:
	if target == NONE:
		return false
	var below := target + Vector2i(0, 1)
	if not world.logic_in_bounds(below):
		return true
	if machines.machine_at(below) != null:
		return false
	return not world.logic_air(below)


## A drill standing IN a metre whose wall holds a lode with something left draws from it in place: the
## head's own cell first, then outward over its coverage. NONE when no covered lode has ore.
static func drill_lode_target(world: World, logic_cell: Vector2i) -> Vector2i:
	for c: Vector2i in head_coverage(logic_cell):
		if _metre_has_lode(world, c):
			return c
	return NONE


static func _metre_has_lode(world: World, logic_cell: Vector2i) -> bool:
	for terrain_cell: Vector2i in world.terrain_cells_of(logic_cell):
		if world.deposits.lode_workable(world.grid, terrain_cell):
			return true
	return false


## The head and every Spur chained to it. Spur awaits a ruling (plan §8), so this is the head alone.
static func head_coverage(head_cell: Vector2i) -> Array[Vector2i]:
	return [head_cell]


static func _live_mouths(world: World, head_cell: Vector2i) -> int:
	var n: int = 0
	for c: Vector2i in head_coverage(head_cell):
		if _metre_has_lode(world, c):
			n += 1
	return maxi(n, 1)
