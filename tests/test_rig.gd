extends "res://tests/test_base.gd"

## THE CREW'S RIG (D0484): the demand side of the economy, the spec's D1 as the first record. The rig eats
## only what its current demand asks for, pays the granted machine into its output when the demand is met,
## moves to the next demand, and its stage rides the save. Split from `test_machines.gd` at the size limit.

const ROCK: StringName = &"clay"

var items: Items
var world: World
var machines: Machines


func _initialize() -> void:
	_test_the_ladder_reads_the_records_in_order()
	_test_the_rig_takes_its_demand_and_pays_in_a_machine()
	_test_the_stage_rides_the_save_and_the_signature()
	_finish("rig")


func _test_the_ladder_reads_the_records_in_order() -> void:
	_check(Demands.count() >= 1 and Demands.at(0)["id"] == "d1", "the ladder's first demand is d1 (%d records)" % Demands.count())
	_check(Demands.wants(0) == {&"ingot": 2} and Demands.grants(0) == {&"drill": 1}, "D1 wants two ingots and grants the drill (%s -> %s)" % [Demands.wants(0), Demands.grants(0)])
	_check(Demands.at(Demands.count()).is_empty() and Demands.wants(Demands.count()).is_empty() and Demands.wants(-1).is_empty(), "past the ladder's end, and before it, nothing is asked")
	var orders: Array[int] = []
	for rec: Dictionary in Demands.ordered():
		orders.append(int(rec["order"]))
	var sorted: Array[int] = orders.duplicate()
	sorted.sort()
	_check(orders == sorted, "the records come out in `order` (%s)" % str(orders))


func _test_the_rig_takes_its_demand_and_pays_in_a_machine() -> void:
	items = _hub_items()
	world = items.world
	machines = _hub_machines(items)
	world.set_solid(Vector2i(5, 8), ROCK)                                   # a floor two metres down: what the rig pays lands there
	var rig: MachineState = machines.place(world, MachineDef.of(&"rig"), Vector2i(5, 6))
	_check(rig != null and rig.stage == 0 and MachineStatus.of(rig, world, machines) == &"no_input", "a fresh rig stands at stage 0, asking")
	_check(Machines.machine_eats(rig, &"ingot") and not Machines.machine_eats(rig, &"ore") and not Machines.machine_eats(rig, &"coal"), "it eats the demand's ingots and nothing else")
	_feed_machine(items, Vector2i(5, 6), &"ingot", 1)
	for _i: int in 3:
		HubTick.step(world, items, machines)
	_check(rig.stage == 0 and int(rig.input_buffer[&"ingot"]) == 1 and rig.output_buffer.is_empty(), "one ingot of two: the demand waits, nothing is paid")
	_feed_machine(items, Vector2i(5, 6), &"ingot", 1)
	HubTick.step(world, items, machines)
	_check(rig.stage == 1 and not rig.input_buffer.has(&"ingot") and rig.output_buffer.is_empty() and items.piles.count_at(Vector2i(5, 7), &"drill") == 1, "two ingots: the demand is met, the drill is set down and falls to the floor at the rig's foot the same tick, stage 1 (%s / pile %d)" % [rig.input_buffer, items.piles.count_at(Vector2i(5, 7), &"drill")])
	_check(int(items.total_consumed.get(&"ingot", 0)) == 2 and int(items.total_produced.get(&"drill", 0)) == 1, "the ledger saw the delivery and the payment")
	_check(Invariants.check_item_conservation(items, 4) == null, "conserved across the transaction")
	_check(MachineStatus.of(rig, world, machines) == (&"idle" if Demands.count() == 1 else &"no_input"), "past the last demand the rig is idle; with more on the ladder it asks again (%s)" % MachineStatus.of(rig, world, machines))
	_check(not Machines.machine_eats(rig, &"ingot") or Demands.count() > 1, "with the ladder spent it eats nothing")


func _test_the_stage_rides_the_save_and_the_signature() -> void:
	items = _hub_items()
	world = items.world
	machines = _hub_machines(items)
	var rig: MachineState = machines.place(world, MachineDef.of(&"rig"), Vector2i(5, 6))
	var before: String = machines.state_signature()
	rig.stage = 1
	_check(machines.state_signature() != before, "the stage is signed: a met demand changes the registry's signature")
	var env: Dictionary = SaveGame.capture(world, items, machines)
	var i2: Items = _hub_items()
	var m2: Machines = _hub_machines(i2)
	_check(SaveGame.restore(i2.world, i2, m2, env), "restore accepted the capture (%s)" % SaveGame.last_invalid)
	var back: MachineState = m2.machine_at(Vector2i(5, 6))
	_check(back != null and back.def.id == &"rig" and back.stage == 1 and m2.state_signature() == machines.state_signature(), "the rig comes back at stage 1 and the registries sign alike (%s)" % (str(back.stage) if back != null else "none"))
