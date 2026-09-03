class_name Machines
extends RefCounted

## THE MACHINE REGISTRY: every placed machine, by cell and in placement order, plus the derived power
## field. Lifted in A' step 3d (D0349) from `legacy/src/core/factory_sim.gd`: the `grid` dictionary and
## `machines` array (:179, :244), `machine_at` 374, `machine_eats` 388, `place_machine` 1887,
## `remove_machine` 1901, `_first_machine_below` 2396, `power_at`/`power_throttle` 2055-2066.
##
## PLACEMENT ORDER IS STATE. `machines` is walked in insertion order every tick and the save preserves it;
## it is unrecoverable from the grid. A machine's cell is registered in `World.logic` as the opaque
## occupant `&"machine"` (ADR 0009), so `sim/world` knows something is built there without knowing what.
##
## `power` is DERIVED: recomputed from scratch at the top of every hub tick by `PowerFlow`, never saved,
## never in the signature, so it cannot desync from placement or fuel. Milli-units; a consumer's throttle
## is per-mille (plan §5.1 rows 004-005).
##
## Holds no `Items` reference. The runners and the verbs take the item service as a parameter, and
## `attach_to` hands `Items` the two Callables it needs to see machine buffers -- one direction, so no
## RefCounted cycle (legacy's own warning about Callables stored on the sim).

var machines: Array[MachineState] = []   # placement order, state
var _by_cell: Dictionary = {}            # logic_cell -> MachineState
var power: Dictionary = {}               # logic_cell -> milli-power, derived each tick
## The Freight Winch's route table and in-flight trips (D0350): Head cell -> Station cell, and Head
## cell -> {"items": Dictionary, "ticks_remaining": int}. Both STATE, both in the signature; a trip's
## cargo counts as present. Edited from exactly three places: `link_winch`, `purge_winch_route`, and
## the Head's own tick advancing a trip already in flight (`Movers`).
var winch_routes: Dictionary = {}
var winch_transit: Dictionary = {}


func machine_at(logic_cell: Vector2i) -> MachineState:
	return _by_cell.get(logic_cell, null)


func count() -> int:
	return machines.size()


## Every occupied cell, in scan order (for reads that must not depend on placement order).
func machine_logic_cells() -> Array[Vector2i]:
	return Ordering.cells(_by_cell)


## Place a machine in an open metre. Returns the new MachineState, or null if out of bounds, occupied,
## or inside rock -- `World.logic_open` is legacy's `cell_occupied` gate and the occupancy plane is what
## makes the layers exclusive. Pack accounting is `MachineVerbs.build_from_pack`.
func place(world: World, def: MachineDef, logic_cell: Vector2i, facing: int = 1) -> MachineState:
	if def == null or not world.logic_open(logic_cell):
		return null
	if not world.logic.occupy(logic_cell, LogicGrid.KIND_MACHINE):
		return null
	var state: MachineState = MachineState.new(def, logic_cell)
	state.facing = facing
	_by_cell[logic_cell] = state
	machines.append(state)
	return state


## Remove the machine at a cell, if any. Items still in its buffers, and any winch cargo in flight
## from or to it, are DESTROYED with the machine and credited to `total_consumed`, so present ==
## produced - consumed holds. `MachineVerbs.pickup_machine` salvages both into the pack first and
## reaches here with nothing to destroy. Fuel and progress are not items. Returns the removed state.
func remove(world: World, items: Items, logic_cell: Vector2i) -> MachineState:
	var state: MachineState = machine_at(logic_cell)
	if state == null:
		return null
	for buffer: Dictionary in [state.input_buffer, state.output_buffer, purge_winch_route(logic_cell)]:
		for item: StringName in Ordering.ids(buffer):
			items.consumed(item, int(buffer[item]))
	_by_cell.erase(logic_cell)
	machines.erase(state)
	world.logic.vacate(logic_cell)
	return state


## The first machine straight down `logic_cell`'s column before any rock: the consumer a hopper feeds.
func first_machine_below(world: World, logic_cell: Vector2i) -> MachineState:
	var rows: int = Landing.floor_rows(world)
	for row: int in range(logic_cell.y + 1, rows):
		var c := Vector2i(logic_cell.x, row)
		var m: MachineState = machine_at(c)
		if m != null:
			return m
		if not world.logic_air(c):
			return null                     # a floor before any machine -> nothing to feed
	return null


## Would this machine consume `item` if fed it? A recipe machine's ingredients, a coal-burner's coal,
## the winch head's bulk cargo; false for everything else, so a mis-aimed handful cannot vanish into a
## box that will sit on it forever. The player-facing question; `Items.deposit` stays unfiltered.
static func machine_eats(machine: MachineState, item: StringName) -> bool:
	if machine == null:
		return false
	var behavior: StringName = machine.def.behavior
	if item == &"coal" and Runners.COAL_BURNERS.has(behavior):
		return true
	if behavior == &"winch_head":
		return Pack.is_bulk_item(item)
	var recipe: RecipeDef = machine.def.recipe
	return recipe != null and recipe.inputs.has(item)


## Available power at a cell in milli-units; 0 where none reaches. Pure read.
func power_at(logic_cell: Vector2i) -> int:
	return int(power.get(logic_cell, 0))


## THE COST RULE, in one place: the fraction of full speed a consumer at `logic_cell` gets, per mille,
## as clamp(available / demand, 0..1000). 1000 when fully supplied. Every consumer routes its draw
## through this and nothing else.
func power_throttle(logic_cell: Vector2i, demand_milli: int) -> int:
	if demand_milli <= 0:
		return 1000
	return clampi(power_at(logic_cell) * 1000 / demand_milli, 0, 1000)


## The link verb: join an unlinked Head to an unlinked Station, writing one route. Both ends must be
## the right machine AND unclaimed, which is what lets `purge_winch_route` assume at most one route
## touches a cell. Reach is the caller's job.
func link_winch(head_cell: Vector2i, station_cell: Vector2i) -> bool:
	var head: MachineState = machine_at(head_cell)
	if head == null or head.def.behavior != &"winch_head" or winch_routes.has(head_cell):
		return false
	var station: MachineState = machine_at(station_cell)
	if station == null or station.def.behavior != &"winch_station":
		return false
	for existing: Vector2i in winch_routes.values():
		if existing == station_cell:
			return false                          # that Station already answers to a different Head
	winch_routes[head_cell] = station_cell
	return true


## Does a route touch `cell`, as Head or Station? Purge it and any trip in flight on it, and hand back
## the cargo ({} if none) for the caller to dispose of: `pickup_machine` salvages it, `remove` credits it.
func purge_winch_route(logic_cell: Vector2i) -> Dictionary:
	var head_cell: Vector2i = logic_cell if winch_routes.has(logic_cell) else Runners.NONE
	if head_cell == Runners.NONE:
		for h: Vector2i in Ordering.cells(winch_routes):
			if winch_routes[h] == logic_cell:
				head_cell = h
				break
	if head_cell == Runners.NONE:
		return {}
	winch_routes.erase(head_cell)
	var transit: Dictionary = winch_transit.get(head_cell, {})
	winch_transit.erase(head_cell)
	return (transit.get("items", {}) as Dictionary)


## Take over another registry's contents (the save's staged registry, ADR 0010 §4): the array, the
## index, the winch tables. The derived field is cleared; the caller re-attaches `Items`.
func adopt_from(other: Machines) -> void:
	machines = other.machines
	_by_cell = other._by_cell
	winch_routes = other.winch_routes
	winch_transit = other.winch_transit
	power.clear()


## Give `Items` the two windows it needs into machine buffers: the buffer at a cell (for the landing
## rule and `deposit`) and the total of an item across every buffer and trip in flight (conservation).
func attach_to(items: Items) -> void:
	items.machine_buffer = func(logic_cell: Vector2i) -> Variant:
		var m: MachineState = machine_at(logic_cell)
		return m.input_buffer if m != null else null
	items.machine_total = func(item: StringName) -> int:
		var n: int = 0
		for m: MachineState in machines:
			n += int(m.input_buffer.get(item, 0)) + int(m.output_buffer.get(item, 0))
		for transit: Dictionary in winch_transit.values():
			n += int((transit["items"] as Dictionary).get(item, 0))
		return n


## Every machine's full state in placement order, from scratch (machines are few). `power_permille` is
## included: it is written by the runner each tick and read by the view between ticks, so it is state.
func state_signature() -> String:
	var a: int = 0
	var b: int = 0
	var i: int = 0
	for m: MachineState in machines:
		i += 1
		var head: Vector2i = StateHash.term(m.logic_cell.x, m.logic_cell.y, StateHash.id_fold(m.def.id), Vector2i(i, i))
		var body: String = "%d,%d,%d,%d,%d,%d,%d,%s" % [m.progress_ticks, m.route_toggle, m.fuel, m.power_permille, m.fed, m.facing, m.mode, m.filter]
		for buffer: Dictionary in [m.input_buffer, m.output_buffer]:
			for item: StringName in Ordering.ids(buffer):
				body += "|%s=%d" % [item, int(buffer[item])]
			body += "||"
		var t: Vector2i = StateHash.text_term(body)
		a ^= head.x ^ StateHash.mix(i, 0, t.x, 0, StateHash.LANE_A)
		b ^= head.y ^ StateHash.mix(i, 0, t.y, 0, StateHash.LANE_B)
	var winch: String = _winch_text()
	if not winch.is_empty():
		var w: Vector2i = StateHash.text_term(winch)
		a ^= w.x
		b ^= w.y
	return "m%d:%d" % [a, b]


## The winch state as text, routes then trips, each in cell order with cargo in text order.
func _winch_text() -> String:
	var out: String = ""
	for h: Vector2i in Ordering.cells(winch_routes):
		out += "r%d,%d>%d,%d;" % [h.x, h.y, winch_routes[h].x, winch_routes[h].y]
	for h: Vector2i in Ordering.cells(winch_transit):
		var transit: Dictionary = winch_transit[h]
		out += "t%d,%d@%d" % [h.x, h.y, int(transit["ticks_remaining"])]
		var cargo: Dictionary = transit["items"]
		for item: StringName in Ordering.ids(cargo):
			out += "|%s=%d" % [item, int(cargo[item])]
		out += ";"
	return out
