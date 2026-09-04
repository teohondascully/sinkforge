extends "res://tests/test_base.gd"

## The door over the hub (A' step 4a, D0356): the interface owns the world's planes, the item service,
## the registry, the verbs and the rate window; a MOVE runs the hub on every third tick; the observation
## carries every hub plane as a window-bounded COPY plus the consumed flow-event channel; observe stays
## pure against the whole session's signature.

const ROCK: StringName = &"hardrock"

var items: Items
var world: World
var machines: Machines
var body: Body
var iface: Interface


func _initialize() -> void:
	_test_the_planes_reach_the_door_as_copies()
	_test_a_move_runs_the_hub_every_third_tick_and_events_are_consumed_once()
	_test_the_window_bounds_the_metre_planes_and_observe_is_pure()
	_test_the_hub_planes_are_kept_until_their_own_plane_moves()
	_finish("interface_hub")


func _rig() -> void:
	items = _hub_items()
	world = items.world
	machines = _hub_machines(items)
	for row_m: int in range(10, 16):
		for col_m: int in 16:
			world.set_solid(Vector2i(col_m, row_m), ROCK)
	body = Body.new(Fx.from_int(5 * 16 + 8), Fx.from_int(10 * 16) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	iface = Interface.new(world.grid, body, Mining.new(), world, items, machines)


func _oracle() -> Interface.Observation:
	return iface.observe(Interface.Envelope.oracle_over(world.grid))


func _test_the_planes_reach_the_door_as_copies() -> void:
	_rig()
	for tc: Vector2i in world.terrain_cells_of(Vector2i(2, 9)):
		world.water.set_level(tc, 5)
	world.deposits.seed_lode(Vector2i(30, 39), &"coal", 4)
	world.deposits.take_one(world.grid, Vector2i(30, 39))
	world.deposits.set_deposit(Vector2i(40, 40), 9)
	world.set_solid(Vector2i(10, 10), &"ore_iron")
	PlacedVerbs.place_conduit(world, Vector2i(9, 9))
	PlacedVerbs.place_torch(world, Vector2i(4, 9))
	world.logic.plant(Vector2i(3, 9))
	world.logic.set_sapling_age(Vector2i(3, 9), 5)
	var hop: MachineState = machines.place(world, MachineDef.of(&"hopper"), Vector2i(7, 9), -1)
	_feed_machine(items, Vector2i(7, 9), &"ore", 2)
	items.pack.add(&"ingot", 3)
	items.produced(&"ingot", 3)
	items.drop_item(Vector2i(12, 2), &"ingot", 1)
	var o: Interface.Observation = _oracle()
	_check(o.logic_window == Rect2i(0, 0, 16, 16) and o.hub_tick == 0, "the oracle window covers all sixteen metres")
	_check(o.water_at(Vector2i(8, 36)) == 5 and o.water_at(Vector2i(8, 35)) == 0 and o.water_at(Vector2i(-1, 0)) == 0, "water per terrain cell; dry and out of window read 0")
	_check(o.lode_at(Vector2i(30, 39)) == &"coal" and o.lode_permille(Vector2i(30, 39)) == 750 and o.deposit_at(Vector2i(30, 39)) == 3, "a lode: material, 3 of 4 left, 750 per mille")
	_check(o.deposit_at(Vector2i(40, 40)) == 9 and o.deposit_at(Vector2i(41, 40)) == o.ore_default and o.ore_default == 16 and o.is_ore_like_at(Vector2i(41, 40)) and not o.is_ore_like_at(Vector2i(0, 40)), "a seeded ore cell's yield, the default for an unseeded one, and 0 for rock")
	_check(o.has_conduit(Vector2i(9, 9)) and o.has_torch(Vector2i(4, 9)) and not o.is_climbable(Vector2i(9, 9)) and o.placed_at(Vector2i(7, 9)) == &"machine", "the placed layers, the machine's cell included")
	_check(o.sapling_age(Vector2i(3, 9)) == 5 and o.sapling_age(Vector2i(2, 9)) == -1, "saplings by age; -1 for none")
	var rec: Dictionary = o.machine_at(Vector2i(7, 9))
	_check(rec["id"] == &"hopper" and rec["facing"] == -1 and rec["status"] == &"working" and int(rec["input"][&"ore"]) == 2 and o.machine_at(Vector2i(8, 9)).is_empty(), "a machine record: id, facing, status (a hopper holding goods works), its buffer; empty for none")
	_check(o.pile_at(Vector2i(12, 9)) == {&"ingot": 1} and o.pile_at(Vector2i(11, 9)).is_empty(), "the pile on the floor, keyed by metre")
	_check(o.pack.size() == 1 and o.pack[0]["item"] == &"ingot" and int(o.pack[0]["count"]) == 2 and o.pack_bulk == 2 and o.pack_bulk_cap == 90 and o.pack_slots == 10, "the pack (the ore went into the hopper, one ingot was dropped) with its cap and slot count")
	var before: String = iface.state_signature()
	rec["input"][&"ore"] = 99
	o.piles[Vector2i(12, 9)][&"ingot"] = 99
	o.lodes[Vector2i(30, 39)]["amount"] = 99
	o.placed.clear()
	o.pack[0]["count"] = 99
	_check(iface.state_signature() == before and int(hop.input_buffer[&"ore"]) == 2 and items.pack.count(&"ingot") == 2, "every plane is a copy: mangling the observation moved nothing in the sim")


func _test_a_move_runs_the_hub_every_third_tick_and_events_are_consumed_once() -> void:
	_rig()
	machines.place(world, MachineDef.of(&"generator"), Vector2i(8, 9))
	_feed_machine(items, Vector2i(8, 9), &"coal", 2)
	for _i: int in 4:
		iface.apply(Command.move(InputFrame.new()))
	_check(_oracle().power_at(Vector2i(8, 9)) == 0 and _oracle().hub_tick == 1, "four moves: one hub tick (the third), which lit the coal but computed the field first")
	for _i: int in 2:
		iface.apply(Command.move(InputFrame.new()))
	var o: Interface.Observation = _oracle()
	_check(o.hub_tick == 2 and o.power_at(Vector2i(8, 9)) == 6000 and o.machine_at(Vector2i(8, 9))["power_permille"] == 1000, "six moves: the second hub tick, and the field is lit at 6000 milli")
	items.pack.add(&"ore", 3)
	items.produced(&"ore", 3)
	items.drop_item(Vector2i(6, 2), &"ore", 3)
	_check(_oracle().flow_events.is_empty(), "an event the item service logged is not on the channel until a tick drains it")
	iface.apply(Command.move(InputFrame.new()))
	var first: Interface.Observation = _oracle()
	_check(first.flow_events.size() == 1 and first.flow_events[0]["item"] == &"ore" and first.flow_events[0]["count"] == 3, "the next observe carries the drop's flow event")
	_check(_oracle().flow_events.is_empty(), "and it is consumed: the observe after has none")


func _test_the_window_bounds_the_metre_planes_and_observe_is_pure() -> void:
	_rig()
	machines.place(world, MachineDef.of(&"hopper"), Vector2i(2, 9))
	machines.place(world, MachineDef.of(&"hopper"), Vector2i(13, 9))
	for tc: Vector2i in world.terrain_cells_of(Vector2i(2, 9)):
		world.water.set_level(tc, 3)
	var near: Interface.Observation = iface.observe(Interface.Envelope.new(Rect2i(0, 30, 24, 12)))
	_check(near.logic_window == Rect2i(0, 7, 6, 4) and near.machines.size() == 1 and near.machine_at(Vector2i(2, 9))["id"] == &"hopper" and near.machine_at(Vector2i(13, 9)).is_empty(), "a window over the left quarter sees only the near hopper")
	_check(near.water_at(Vector2i(8, 36)) == 3 and near.water_at(Vector2i(52, 36)) == 0, "water inside the window; outside reads 0")
	var before: String = iface.state_signature()
	for _i: int in 3:
		_oracle()
		iface.observe(Interface.Envelope.new(Rect2i(0, 30, 24, 12)))
	_check(iface.state_signature() == before, "observe is pure against the whole session's signature")
	for _i: int in 3:
		iface.apply(Command.move(InputFrame.new()))
	_check(iface.state_signature() != before, "a hub tick (water settling) moves the session signature")
	var again: Interface = Interface.new(world.grid, body, Mining.new())
	_check(again.state_signature() != iface.state_signature(), "the compatibility constructor wraps the grid in fresh services: a different session")


## The hub planes cache (2026-09-04): a hub tick that moved no plane refills nothing; a write to one plane
## refills that plane and the observation reads the new content. Counted, not only checked for correctness,
## for the same reason `plane_rebuilds` is -- a cache that recomputes every time passes every content assertion.
func _test_the_hub_planes_are_kept_until_their_own_plane_moves() -> void:
	_rig()
	var env: Interface.Envelope = Interface.Envelope.new(Rect2i(0, 30, 24, 12))
	var wet: Vector2i = world.terrain_cells_of(Vector2i(2, 9))[0]
	world.water.set_level(wet, 3)
	iface.observe(env)
	var after_first: int = iface.hub_rebuilds()
	_check(after_first >= 4, "the first observe filled every keyed plane (%d refills)" % after_first)
	for _i: int in 3:
		iface.apply(Command.move(InputFrame.new()))   # one hub tick, the water settling under it
	var o: Interface.Observation = iface.observe(env)
	var after_hub: int = iface.hub_rebuilds()
	_check(o.water_at(wet) == 3 or o.wet_cells.size() > 0, "the water is still in the observation after the hub tick")
	for _i: int in 3:
		iface.apply(Command.move(InputFrame.new()))
	iface.observe(env)
	for _i: int in 3:
		iface.apply(Command.move(InputFrame.new()))
	iface.observe(env)
	var settled: int = iface.hub_rebuilds()
	for _i: int in 3:
		iface.apply(Command.move(InputFrame.new()))
	iface.observe(env)
	_check(iface.hub_rebuilds() == settled, "once the water rests a hub tick refills no plane (%d after, %d before)" % [iface.hub_rebuilds(), settled])
	_check(after_hub > after_first or settled > after_first, "and the settling ticks before it did refill the water plane (%d -> %d)" % [after_first, settled])
	world.deposits.seed_lode(Vector2i(9, 36), &"ore_iron", 40)
	var lode_only: int = iface.hub_rebuilds()
	var moved: Interface.Observation = iface.observe(env)
	_check(iface.hub_rebuilds() == lode_only + 2, "a lode write refills the lode and yield planes and nothing else (%d -> %d)" % [lode_only, iface.hub_rebuilds()])
	_check(moved.lodes.has(Vector2i(9, 36)) and moved.lodes[Vector2i(9, 36)]["material"] == &"ore_iron", "and the observation reads the lode it was refilled from")
