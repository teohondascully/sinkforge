extends "res://tests/test_base.gd"

## `demand_satisfied` (D0605): the rig's stage advance emits a machine-lifecycle event that
## `observe()` surfaces as `o.events` -- the telemetry primitive claim C003's metric reads
## (`demand_satisfied.id`), which did not exist at all before this. A delivery short of the wants
## must emit nothing: the event marks a demand MET, not items arrived.

var items: Items
var machines: Machines
var world: World


func _initialize() -> void:
	_test_partial_delivery_emits_nothing()
	_test_full_delivery_emits_once_with_the_demands_own_id()
	_test_the_event_surfaces_through_observe_and_drains()
	_finish("demand_satisfied")


func _rig() -> MachineState:
	items = _hub_items(16, 16)
	world = items.world
	machines = _hub_machines(items)
	return machines.place(world, MachineDef.of(&"rig"), Vector2i(5, 5))


func _feed_wants(rig: MachineState, fraction: float = 1.0) -> void:
	for item: StringName in Demands.wants(rig.stage):
		var n: int = int(Demands.wants(rig.stage)[item])
		_feed_machine(items, rig.logic_cell, item, int(n * fraction))


func _test_partial_delivery_emits_nothing() -> void:
	var rig: MachineState = _rig()
	var first: StringName = Demands.wants(rig.stage).keys()[0]
	_feed_machine(items, rig.logic_cell, first, 1)   # d1 wants two; one is a delivery, not a satisfaction
	HubTick.step(world, items, machines)
	_check(rig.stage == 0 and machines.events.is_empty(),
		"a delivery short of the wants advances nothing and emits nothing (stage %d)" % rig.stage)


func _test_full_delivery_emits_once_with_the_demands_own_id() -> void:
	var rig: MachineState = _rig()
	var stage0: Dictionary = Demands.at(0)
	_feed_wants(rig)
	HubTick.step(world, items, machines)
	_check(machines.events.size() == 1, "one demand met: one event (got %d)" % machines.events.size())
	var ev: Dictionary = machines.events[0] if machines.events.size() == 1 else {}
	_check(ev.get("kind") == &"demand_satisfied" and ev.get("id") == StringName(String(stage0.get("id", ""))),
		"the event carries the demand record's own id (%s), not a hardcoded name" % String(ev.get("id", "?")))
	_check(int(ev.get("stage", -1)) == 0 and ev.get("cell") == rig.logic_cell,
		"the event names the stage that completed and the rig's cell")
	_check(rig.stage == 1 and not Demands.wants(1).is_empty(),
		"the rig advanced to the next demand (stage %d)" % rig.stage)
	HubTick.step(world, items, machines)
	_check(machines.events.size() == 1, "an undelivered next demand emits nothing on the next tick")


func _test_the_event_surfaces_through_observe_and_drains() -> void:
	var rig: MachineState = _rig()
	_feed_wants(rig)
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(64))
	var door: Interface = Interface.new(world.grid, body, Mining.new(), world, items, machines)
	HubTick.step(world, items, machines)
	var o: Interface.Observation = door.observe(Interface.Envelope.covering(
		Rect2(0.0, 0.0, 320.0, 320.0), WorldView.WINDOW_MARGIN_CELLS))
	_check(o.events.size() == 1 and o.events[0].get("kind") == &"demand_satisfied",
		"observe() surfaces the event -- the channel C003's metric reads")
	_check(machines.events.is_empty(), "observe() drained the sim's queue: a consumed channel, one observe wide")
	var again: Interface.Observation = door.observe(Interface.Envelope.covering(
		Rect2(0.0, 0.0, 320.0, 320.0), WorldView.WINDOW_MARGIN_CELLS))
	_check(again.events.is_empty(), "a drained channel does not repeat the event on the next observe")
