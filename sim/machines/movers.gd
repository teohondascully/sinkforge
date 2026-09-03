class_name Movers
extends RefCounted

## The runners that MOVE items rather than make them: the lift and the Freight Winch. Lifted in A' step
## 3e (D0350) from `legacy/src/core/factory_sim.gd`: `_run_lift` 2124, `_status_mover` 547,
## `_run_winch_head` 2184, `_advance_winch_transit` 2229, `_run_winch_station` 2251 (a pure receiver:
## nothing to run), `_status_winch_head` 2267. Their routing is `Flow`'s; their route and transit state is
## the registry's (`Machines.winch_routes`/`winch_transit`). Every number is a record field.

## A LIFT runs no recipe: it carries items UP its column, the paid inverse of gravity. Its throughput is
## power-governed: `throughput` at the unpowered baseline, scaling to `powered_throughput` as power
## reaches its cell through the one cost rule. The rest stays a backlog. Whatever falls onto it is hauled.
static func run_lift(m: MachineState, machines: Machines) -> void:
	m.power_permille = machines.power_throttle(m.logic_cell, m.def.power_demand_milli)
	var cap: int = m.def.throughput + ((m.def.powered_throughput - m.def.throughput) * m.power_permille + 500) / 1000
	_move_up_to(m.input_buffer, m.output_buffer, cap)


## Move up to `cap` units from one buffer to another, item by item in text order, keeping the source
## free of dead keys. Returns the units moved.
static func _move_up_to(from: Dictionary, to: Dictionary, cap: int) -> int:
	var moved: int = 0
	for item: StringName in Ordering.ids(from):
		if moved >= cap:
			break
		var take: int = mini(int(from[item]), cap - moved)
		to[item] = int(to.get(item, 0)) + take
		Runners._take_from_buffer(from, item, take)
		moved += take
	return moved


## A mover (lift, winch station): working while goods are in it, idle when empty.
static func status_mover(m: MachineState) -> StringName:
	return &"working" if not m.input_buffer.is_empty() else &"idle"


## THE FREIGHT WINCH, the Head half. Reads its OWN input buffer, never the output: unlinked, unpowered,
## or with nothing waiting, it holds what falls into it like any machine with no drain. With a trip in
## flight the Head counts it down and lands it straight in the Station's input buffer, so the Station's
## own tick never touches a buffer that is not its own. A trip queues a power-scaled share of
## `trip_capacity` and holds while the Station is at its `station_cap`.
static func run_winch_head(m: MachineState, machines: Machines) -> void:
	m.power_permille = machines.power_throttle(m.logic_cell, m.def.power_demand_milli)
	if machines.winch_transit.has(m.logic_cell):
		advance_winch_transit(m, machines)
		return
	if not machines.winch_routes.has(m.logic_cell) or m.input_buffer.is_empty():
		return                                        # unlinked, or nothing waiting to haul
	var cap: int = (m.def.trip_capacity * m.power_permille + 500) / 1000
	if cap <= 0:
		return                                        # unpowered: no free ride, the pump's own cost rule
	var station: MachineState = _station_of(m, machines)
	if station == null or Runners.buffer_load(station.input_buffer) >= station.def.station_cap:
		return                                        # dangling route (transient), or a backed-up Station
	var load: Dictionary = {}
	if _move_up_to(m.input_buffer, load, cap) > 0:
		machines.winch_transit[m.logic_cell] = {"items": load, "ticks_remaining": m.def.transit_ticks}


## Count one tick off an in-flight trip. The tick that CREATES a trip does not also count against it, so
## a trip spends exactly `transit_ticks` full ticks in flight. On reaching 0 the cargo lands in the
## Station's input buffer; if the route died mid-flight (a raw removal that skipped the purge), the
## cargo returns to the Head's own buffer rather than vanishing: salvage, never destroy.
static func advance_winch_transit(m: MachineState, machines: Machines) -> void:
	var transit: Dictionary = machines.winch_transit[m.logic_cell]
	var remaining: int = int(transit["ticks_remaining"]) - 1
	if remaining > 0:
		transit["ticks_remaining"] = remaining
		return
	var cargo: Dictionary = transit["items"]
	machines.winch_transit.erase(m.logic_cell)
	var station: MachineState = _station_of(m, machines)
	var into: Dictionary = station.input_buffer if station != null else m.input_buffer
	for item: StringName in Ordering.ids(cargo):
		into[item] = int(into.get(item, 0)) + int(cargo[item])


## The Station a Head is routed to, or null when the route is missing or points at something else.
static func _station_of(m: MachineState, machines: Machines) -> MachineState:
	if not machines.winch_routes.has(m.logic_cell):
		return null
	var station: MachineState = machines.machine_at(machines.winch_routes[m.logic_cell])
	if station == null or station.def.behavior != &"winch_station":
		return null
	return station


## Winch Head status, mirroring `run_winch_head`'s gates in the same order. `unlinked` is "placed, but
## nothing to route to"; a trip in flight reads `working` regardless of power; `blocked_station` names
## the one hold that used to read as `working`: the fix is clearing or rerouting the Station, not
## digging a drain.
static func status_winch_head(m: MachineState, machines: Machines) -> StringName:
	if not machines.winch_routes.has(m.logic_cell):
		return &"unlinked"
	if machines.winch_transit.has(m.logic_cell):
		return &"working"
	if m.input_buffer.is_empty():
		return &"idle"
	if machines.power_throttle(m.logic_cell, m.def.power_demand_milli) <= 0:
		return &"no_power"
	var station: MachineState = _station_of(m, machines)
	if station != null and Runners.buffer_load(station.input_buffer) >= station.def.station_cap:
		return &"blocked_station"
	return &"working"
