extends "res://tests/test_base.gd"

## `sim/transport` + the movers (A' step 3e, D0350): the flow phase (every output to its one destination,
## down by the landing rule, up by the lift's rise), `updraft_at`, the power-governed lift, and the
## Freight Winch's link/trip/transit/purge lifecycle with its state in the registry's signature. Legacy's
## `_test_lift` and the live half of `_test_freight_winch_lifecycle` (`legacy/tests/test_sim.gd`; the
## save-reconciliation half waits for save v3), plus what 3d could not show: a hopper's metered release
## now ARRIVES in the forge below, and the forge's ingots fall on to the floor.

const ROCK: StringName = &"hardrock"

var world: World
var items: Items
var machines: Machines


func _initialize() -> void:
	_test_lift_carries_up_at_the_power_governed_cap()
	_test_column_rise_and_updraft()
	_test_flow_chains_a_hopper_into_a_forge_and_the_ingots_on_to_the_floor()
	_test_winch_links_trips_lands_and_holds()
	_test_winch_pickup_salvages_raw_remove_destroys_and_a_dead_route_returns_cargo()
	_test_signature_sees_routes_and_transit()
	_finish("transport")


func _rig() -> void:
	items = _hub_items()
	world = items.world
	machines = _hub_machines(items)


func _put(id: StringName, cell: Vector2i) -> MachineState:
	return machines.place(world, MachineDef.of(id), cell)


func _feed(cell: Vector2i, item: StringName, n: int) -> void:
	_feed_machine(items, cell, item, n)


func _steps(n: int) -> void:
	for _i: int in n:
		HubTick.step(world, items, machines)


func _status(cell: Vector2i) -> StringName:
	return MachineStatus.of(machines.machine_at(cell), world, machines)


func _lit_generator(cell: Vector2i) -> void:
	_put(&"generator", cell)
	_feed(cell, &"coal", 5)
	_steps(1)   # lights; the field is lit from the next step


## legacy `_test_lift`, then the powered and brownout caps that data now sets.
func _test_lift_carries_up_at_the_power_governed_cap() -> void:
	_rig()
	var lift: MachineState = _put(&"lift", Vector2i(5, 10))
	_check(lift != null and lift.def.behavior == &"lift" and Runners.behavior_flag(lift.def, &"updraft"), "placed a lift; its behaviour carries the updraft flag")
	_feed(Vector2i(5, 10), &"ore", 5)
	_steps(1)
	_check(int(lift.input_buffer[&"ore"]) == 5 - 2 and lift.output_buffer.is_empty(), "unpowered: throughput 2 a tick, the rest is backlog; and the flow phase already carried the 2 on")
	_check(items.piles.count_at(Vector2i(5, 0), &"ore") == 2, "they rose to the top of the shaft: a pile in row 0")
	_steps(8)
	_check(lift.input_buffer.is_empty() and lift.output_buffer.is_empty() and items.piles.count_at(Vector2i(5, 0), &"ore") == 5, "lift drained upward: all 5 at the top")
	_check(items.present(&"ore") == 5 and Invariants.check_item_conservation(items, 9) == null, "ore conserved across lifting")
	_check(_status(Vector2i(5, 10)) == &"idle", "empty reads idle")
	_rig()
	lift = _put(&"lift", Vector2i(5, 10))
	_lit_generator(Vector2i(6, 10))
	_feed(Vector2i(5, 10), &"ore", 10)
	_steps(1)
	_check(lift.power_permille == 1000 and int(lift.input_buffer[&"ore"]) == 4 and _status(Vector2i(5, 10)) == &"working", "powered at 4000 of 4000: powered_throughput 6 a tick")
	_rig()
	lift = _put(&"lift", Vector2i(5, 10))
	_lit_generator(Vector2i(7, 10))
	_feed(Vector2i(5, 10), &"ore", 10)
	_steps(1)
	_check(lift.power_permille == 500 and int(lift.input_buffer[&"ore"]) == 6, "brownout at 2000 of 4000: 2 + round(4 x 0.5) = 4 a tick")


func _test_column_rise_and_updraft() -> void:
	_rig()
	var hop: MachineState = _put(&"hopper", Vector2i(5, 4))
	var d: Dictionary = Flow.column_rise(world, items.piles, machines, 5, 9)
	_check(d["to_cell"] == Vector2i(5, 4) and d["target"] == hop.input_buffer, "the rise stops at the first machine above: its input buffer")
	world.set_solid(Vector2i(5, 2), ROCK)
	d = Flow.column_rise(world, items.piles, machines, 5, 3)
	_check(d["to_cell"] == Vector2i(5, 3) and d["target"] == items.piles.pile(Vector2i(5, 3)), "a ceiling: the pile rests in the open metre under it")
	world.grid.set_material(Vector2i(28, 8), ROCK)   # one 4 px cell inside metre (7, 2)
	d = Flow.column_rise(world, items.piles, machines, 7, 9)
	_check(d["to_cell"] == Vector2i(7, 3), "a half-dug metre is a ceiling too (any rock), the mirror of the landing's floor")
	d = Flow.column_rise(world, items.piles, machines, 9, 9)
	_check(d["to_cell"] == Vector2i(9, 0) and d["target"] == items.piles.pile(Vector2i(9, 0)), "nothing above: the world's top row")
	items.piles.prune_empty()
	_put(&"lift", Vector2i(3, 12))
	_check(Flow.updraft_at(world, machines, Vector2i(3, 5)), "a clear column down to a lift: in its updraft")
	_check(not Flow.updraft_at(world, machines, Vector2i(4, 5)), "the next column over is not")
	world.set_solid(Vector2i(3, 8), ROCK)
	_check(not Flow.updraft_at(world, machines, Vector2i(3, 5)) and Flow.updraft_at(world, machines, Vector2i(3, 9)), "a floor breaks the draft above it, not below it")
	_put(&"hopper", Vector2i(3, 10))
	_check(not Flow.updraft_at(world, machines, Vector2i(3, 9)), "the first machine below answers: a hopper is not an updraft")
	_check(not Flow.updraft_at(world, machines, Vector2i(3, 14)), "nothing below: no draft")


## What 3d's hopper test could only leave in an output buffer: the release now arrives in the forge.
func _test_flow_chains_a_hopper_into_a_forge_and_the_ingots_on_to_the_floor() -> void:
	_rig()
	var hop: MachineState = _put(&"hopper", Vector2i(5, 2))
	var forge: MachineState = _put(&"processor", Vector2i(5, 5))
	world.set_solid(Vector2i(5, 9), ROCK)
	_feed(Vector2i(5, 2), &"ore", 6)
	_steps(1)
	_check(hop.output_buffer.is_empty() and int(forge.input_buffer[&"ore"]) == 1, "the hopper's release of 1 flowed into the forge's input the same tick")
	_check(items.flow_events.size() == 1 and items.flow_events[0]["from"] == Vector2i(5, 2) and items.flow_events[0]["to"] == Vector2i(5, 5), "one flow event, hopper to forge")
	_steps(1)
	_check(int(forge.input_buffer[&"ore"]) == 2 and _status(Vector2i(5, 5)) == &"working", "two ore: the forge is working")
	_steps(2)
	_check(int(hop.input_buffer[&"ore"]) == 3 and _status(Vector2i(5, 2)) == &"blocked", "feed_cap 3 reached in the forge: the hopper holds its other 3 (backed up)")
	_steps(200)
	_check(items.piles.count_at(Vector2i(5, 8), &"ingot") == 3 and int(items.total_produced[&"ingot"]) == 3, "three crafts: the ingots fell out of the forge on to the floor two metres down")
	_check(hop.input_buffer.is_empty() and forge.input_buffer.is_empty() and forge.output_buffer.is_empty(), "everything drained through")
	_check(Invariants.check_item_conservation(items, 204) == null and items.present(&"ore") == 0, "6 ore became 3 ingots; nothing lost in flight")
	_check(_status(Vector2i(5, 2)) == &"idle" and _status(Vector2i(5, 5)) == &"no_input", "idle and starved")


## legacy `_test_freight_winch_lifecycle`'s live half, plus the gates the status names.
func _test_winch_links_trips_lands_and_holds() -> void:
	_rig()
	var head_cell := Vector2i(10, 10)
	var station_cell := Vector2i(11, 10)
	var head: MachineState = _put(&"winch_head", head_cell)
	var station: MachineState = _put(&"winch_station", station_cell)
	_check(_status(head_cell) == &"unlinked" and _status(station_cell) == &"idle", "placed: the head is unlinked, the station idle")
	_check(not machines.link_winch(Vector2i(1, 1), station_cell) and not machines.link_winch(station_cell, head_cell), "no head at the cell, or the ends reversed: refused")
	_check(not machines.link_winch(head_cell, Vector2i(1, 1)) and not machines.link_winch(head_cell, head_cell), "no station at the cell: refused")
	_check(MachineVerbs.link_winch(machines, head_cell, station_cell), "link_winch joins an unlinked head to an unlinked station")
	_check(not machines.link_winch(head_cell, station_cell), "...and refuses to link an already-linked head again")
	_put(&"winch_head", Vector2i(12, 10))
	_check(not machines.link_winch(Vector2i(12, 10), station_cell), "a station already answering to a head refuses a second")
	_feed(head_cell, &"ore", 8)
	_steps(1)
	_check(_status(head_cell) == &"no_power" and not machines.winch_transit.has(head_cell), "loaded but dark: no_power, nothing queued")
	_lit_generator(Vector2i(10, 9))
	_steps(1)
	_check(machines.winch_transit.has(head_cell) and head.input_buffer.is_empty(), "powered: a full trip of trip_capacity 8 queued into transit")
	var transit: Dictionary = machines.winch_transit[head_cell]
	_check(int(transit["items"][&"ore"]) == 8 and int(transit["ticks_remaining"]) == 40, "8 ore in flight for transit_ticks 40")
	_check(items.present(&"ore") == 8 and Invariants.check_item_conservation(items, 2) == null, "conservation holds MID-TRIP: transit counts as present")
	_check(_status(head_cell) == &"working", "a trip in flight reads working")
	_steps(39)
	_check(machines.winch_transit.has(head_cell) and int(machines.winch_transit[head_cell]["ticks_remaining"]) == 1 and station.input_buffer.is_empty(), "39 ticks later it is still in flight")
	_steps(1)
	_check(not machines.winch_transit.has(head_cell) and int(station.input_buffer[&"ore"]) == 8, "the 40th tick lands the cargo in the station's input buffer")
	_check(_status(head_cell) == &"idle" and _status(station_cell) == &"working", "head idle, station working (it holds goods)")
	_feed(head_cell, &"ore", 3)
	_feed(station_cell, &"ore", 52)
	_steps(1)
	_check(_status(head_cell) == &"blocked_station" and not machines.winch_transit.has(head_cell) and int(head.input_buffer[&"ore"]) == 3, "the station at station_cap 60 holds the trip: blocked_station, a visible queue")
	_check(Invariants.check_item_conservation(items, 43) == null, "conserved through the hold")
	_rig()
	head = _put(&"winch_head", head_cell)
	_put(&"winch_station", station_cell)
	machines.link_winch(head_cell, station_cell)
	_lit_generator(Vector2i(10, 8))   # two cells up: 2000 of 4000 demand
	_feed(head_cell, &"ore", 8)
	_steps(1)
	_check(head.power_permille == 500 and int(machines.winch_transit[head_cell]["items"][&"ore"]) == 4 and int(head.input_buffer[&"ore"]) == 4, "brownout: a trip carries round(8 x 0.5) = 4; the rest waits")


func _test_winch_pickup_salvages_raw_remove_destroys_and_a_dead_route_returns_cargo() -> void:
	var head_cell := Vector2i(10, 10)
	var station_cell := Vector2i(11, 10)
	_rig()
	_put(&"winch_head", head_cell)
	_put(&"winch_station", station_cell)
	machines.link_winch(head_cell, station_cell)
	_lit_generator(Vector2i(10, 9))
	_feed(head_cell, &"ore", 8)
	_steps(1)
	_check(machines.winch_transit.has(head_cell), "a trip is in flight")
	_check(MachineVerbs.pickup_machine(items, machines, head_cell), "picked the head up mid-trip")
	_check(not machines.winch_routes.has(head_cell) and not machines.winch_transit.has(head_cell), "picking up the head purges the route and the in-flight transit with it")
	_check(items.pack.count(&"ore") == 8 and items.pack.count(&"winch_head") == 1, "the ore mid-trip is salvaged into the pack, not destroyed")
	_check(items.present(&"ore") == 8 and Invariants.check_item_conservation(items, 2) == null, "conservation holds after the relocation")
	_rig()
	_put(&"winch_head", head_cell)
	_put(&"winch_station", station_cell)
	machines.link_winch(head_cell, station_cell)
	_lit_generator(Vector2i(10, 9))
	_feed(head_cell, &"ore", 8)
	_steps(1)
	_check(MachineVerbs.pickup_machine(items, machines, station_cell) and not machines.winch_routes.has(head_cell) and items.pack.count(&"ore") == 8, "picking up the STATION purges the same route (matched as the value) and salvages the same cargo")
	_rig()
	_put(&"winch_head", head_cell)
	_put(&"winch_station", station_cell)
	machines.link_winch(head_cell, station_cell)
	_lit_generator(Vector2i(10, 9))
	_feed(head_cell, &"ore", 8)
	_steps(1)
	machines.remove(world, items, station_cell)
	_check(not machines.winch_routes.has(head_cell) and not machines.winch_transit.has(head_cell), "a raw remove of the station purges the route and the trip")
	_check(items.present(&"ore") == 0 and int(items.total_consumed[&"ore"]) == 8 and Invariants.check_item_conservation(items, 2) == null, "and DESTROYS the cargo, credited as consumed, the way a raw remove destroys a buffer")
	_rig()
	var head: MachineState = _put(&"winch_head", head_cell)
	_put(&"winch_station", station_cell)
	machines.link_winch(head_cell, station_cell)
	_lit_generator(Vector2i(10, 9))
	_feed(head_cell, &"ore", 8)
	_steps(1)
	machines.winch_routes[head_cell] = Vector2i(3, 3)   # the route died mid-flight without a purge (a save that outlived its station)
	_steps(40)
	_check(not machines.winch_transit.has(head_cell) and int(head.input_buffer[&"ore"]) == 8, "a route to nothing on landing: the cargo returns to the head's own buffer, not the void")
	_check(Invariants.check_item_conservation(items, 41) == null, "conserved")


func _test_signature_sees_routes_and_transit() -> void:
	var head_cell := Vector2i(10, 10)
	var station_cell := Vector2i(11, 10)
	_rig()
	_put(&"winch_head", head_cell)
	_put(&"winch_station", station_cell)
	var a: String = machines.state_signature()
	var twin: Machines = Machines.new()
	var w2: World = World.new(TileGrid.new(64, 64, 1))
	twin.place(w2, MachineDef.of(&"winch_head"), head_cell)
	twin.place(w2, MachineDef.of(&"winch_station"), station_cell)
	_check(twin.state_signature() == a, "twins sign the same")
	machines.link_winch(head_cell, station_cell)
	var linked: String = machines.state_signature()
	_check(linked != a, "a route is state: linking changes the signature")
	twin.link_winch(head_cell, station_cell)
	_check(twin.state_signature() == linked, "and the twin linked the same way agrees")
	machines.winch_transit[head_cell] = {"items": {&"ore": 3}, "ticks_remaining": 12}
	var flying: String = machines.state_signature()
	_check(flying != linked, "a trip in flight is state")
	machines.winch_transit[head_cell]["ticks_remaining"] = 11
	_check(machines.state_signature() != flying, "so is its countdown")
	machines.purge_winch_route(station_cell)
	_check(machines.state_signature() == a and machines.purge_winch_route(head_cell).is_empty(), "purged by the station's cell: back to the unlinked signature; purging again finds nothing")
