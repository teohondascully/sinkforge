extends "res://tests/test_base.gd"

## `sim/machines` + the hub tick (A' step 3d, D0349): the registry, the power field in milli-units, the
## recipe/generator/hopper/pump/drill runners, the status reads, the build/pickup verbs, `HubTick`.
## Legacy's power-field, conduit, pump, production, hopper, drill, coal-and-fuel, machine-status,
## behaviour-registry and automated-line tests (`legacy/tests/test_sim.gd`) plus the pickup order fix, at
## the metre cell over a 4 px grid. Outputs flow on the same tick (`Flow`, 3e): they are read where they land.

const ROCK: StringName = &"hardrock"
const ORE_ROCK: StringName = &"ore_iron"   # the vein's material...
const ORE: StringName = &"ore"            # ...and the item it yields (D0409)

var world: World
var items: Items
var machines: Machines


func _initialize() -> void:
	_test_registry_place_remove_occupancy_and_first_machine_below()
	_test_power_field_aura_attenuates_and_the_throttle_is_the_cost_rule()
	_test_conduit_network_carries_down_and_sideways_never_up()
	_test_recipe_runner_consumes_produces_and_passes_junk_through()
	_test_unknown_tag_runs_the_recipe_and_flags_read_the_registry()
	_test_generator_burns_coal_and_the_field_follows_its_fuel()
	_test_pump_drains_only_while_powered_and_rock_caps_its_reach()
	_test_hopper_latches_filters_meters_and_holds_under_back_pressure()
	_test_drill_bores_the_deepest_ore_bottom_up_burns_coal_and_pours_down()
	_test_drill_gates_blocked_no_fuel_and_a_head_on_a_lode()
	_test_machine_status_mirrors_each_runner()
	_test_build_and_pickup_verbs_salvage_in_the_safe_order_and_conserve()
	_test_hub_tick_cadence_and_the_signature()
	_finish("machines")


func _rig(logic_w: int = 16, logic_h: int = 16) -> void:
	items = _hub_items(logic_w, logic_h)
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


## Rock walls either side of column `col`, rows `top`..`bottom`, and a floor: a pool that cannot spread.
func _basin(col: int, top: int, bottom: int) -> void:
	for y: int in range(top, bottom + 1):
		world.set_solid(Vector2i(col - 1, y), ROCK)
		world.set_solid(Vector2i(col + 1, y), ROCK)
	world.set_solid(Vector2i(col, bottom + 1), ROCK)


func _test_registry_place_remove_occupancy_and_first_machine_below() -> void:
	_rig()
	var forge: MachineState = _put(&"processor", Vector2i(5, 6))
	_check(forge != null and machines.machine_at(Vector2i(5, 6)) == forge and machines.count() == 1, "place registers the machine at its cell")
	_check(world.logic.occupant(Vector2i(5, 6)) == LogicGrid.KIND_MACHINE, "the world sees an opaque `machine` occupant (ADR 0009)")
	_check(_put(&"hopper", Vector2i(5, 6)) == null and machines.count() == 1, "an occupied cell refuses a second machine")
	world.set_solid(Vector2i(2, 2), ROCK)
	_check(_put(&"hopper", Vector2i(2, 2)) == null, "rock refuses")
	world.grid.set_material(Vector2i(12, 12), ROCK)  # one 4 px cell inside metre (3, 3)
	_check(_put(&"hopper", Vector2i(3, 3)) == null, "a half-dug metre is not open: refuses")
	_check(_put(&"hopper", Vector2i(40, 3)) == null and machines.place(world, null, Vector2i(4, 4)) == null, "out of bounds and an unknown def refuse")
	var hop: MachineState = _put(&"hopper", Vector2i(5, 2))
	_check(machines.first_machine_below(world, Vector2i(5, 2)) == forge, "first_machine_below walks the column to the forge")
	world.set_solid(Vector2i(5, 4), ROCK)
	_check(machines.first_machine_below(world, Vector2i(5, 2)) == null, "a floor between them: nothing to feed")
	var cells: Array[Vector2i] = [Vector2i(5, 2), Vector2i(5, 6)]
	var placed: Array[MachineState] = [forge, hop]
	_check(machines.machine_logic_cells() == cells and machines.machines == placed, "cells in scan order; the array in placement order (the forge was placed first)")
	_feed(Vector2i(5, 6), &"ore", 3)
	_check(int(forge.input_buffer[&"ore"]) == 3 and items.present(&"ore") == 3, "deposit reached the forge through the attached buffer callback, and it counts as present")
	_check(machines.remove(world, items, Vector2i(5, 6)) == forge and machines.count() == 1 and not world.logic.is_occupied(Vector2i(5, 6)), "remove clears the cell and the occupancy")
	_check(items.present(&"ore") == 0 and int(items.total_consumed[&"ore"]) == 3, "a raw remove DESTROYS the buffer and credits it as consumed, so conservation holds")
	_check(Invariants.check_item_conservation(items, 1) == null and machines.remove(world, items, Vector2i(9, 9)) == null, "conserved after the destroy; removing nothing is null")
	_check(Machines.machine_eats(hop, &"ore") == false and Machines.machine_eats(null, &"ore") == false, "a hopper eats nothing by recipe; null eats nothing")
	var drill: MachineState = _put(&"drill", Vector2i(8, 8))
	var gen: MachineState = _put(&"generator", Vector2i(9, 8))
	_check(Machines.machine_eats(drill, &"coal") and Machines.machine_eats(gen, &"coal") and not Machines.machine_eats(drill, &"ore"), "coal burners eat coal, not ore")
	var proc: MachineState = _put(&"processor", Vector2i(10, 8))
	_check(Machines.machine_eats(proc, &"ore") and not Machines.machine_eats(proc, &"coal"), "a recipe machine eats its inputs")


## legacy `_test_power_field`: an attenuating diamond, maximum of overlaps, and the throttle.
func _test_power_field_aura_attenuates_and_the_throttle_is_the_cost_rule() -> void:
	_rig()
	var gen: MachineState = _put(&"generator", Vector2i(5, 5))
	_steps(1)
	_check(machines.power_at(Vector2i(5, 5)) == 0, "unfueled: the field is dark")
	_feed(Vector2i(5, 5), &"coal", 2)
	_steps(1)
	_check(gen.fuel == 100 and machines.power_at(Vector2i(5, 5)) == 0, "the tick the coal is lit the field was already computed dark (legacy's order)")
	_steps(1)
	_check(machines.power_at(Vector2i(5, 5)) == 6000, "source cell: 6.0 -> 6000 milli")
	_check(machines.power_at(Vector2i(6, 5)) == 4000 and machines.power_at(Vector2i(5, 4)) == 4000, "one cell out: 6 x (1 - 1/3) = 4000")
	_check(machines.power_at(Vector2i(7, 5)) == 2000 and machines.power_at(Vector2i(6, 6)) == 2000, "two out (straight or diagonal manhattan 2): 2000")
	_check(machines.power_at(Vector2i(8, 5)) == 0 and machines.power_at(Vector2i(7, 7)) == 0 and not machines.power.has(Vector2i(8, 5)), "the rim is dark and absent from the field")
	_check(machines.power_throttle(Vector2i(5, 5), 4000) == 1000 and machines.power_throttle(Vector2i(6, 5), 4000) == 1000, "at or above demand: full speed")
	_check(machines.power_throttle(Vector2i(7, 5), 4000) == 500 and machines.power_throttle(Vector2i(8, 5), 4000) == 0, "half supplied is 500 per mille; dark is 0")
	_check(machines.power_throttle(Vector2i(8, 5), 0) == 1000, "no demand: full, wherever")
	_put(&"generator", Vector2i(7, 5))
	_feed(Vector2i(7, 5), &"coal", 1)
	_steps(2)
	_check(machines.power_at(Vector2i(6, 5)) == 4000, "two overlapping auras take the MAXIMUM, not the sum")


## legacy `_test_conduit_network`: down at 92%, sideways at 80%, bleed 60%, never up.
func _test_conduit_network_carries_down_and_sideways_never_up() -> void:
	_rig()
	_put(&"generator", Vector2i(5, 3))
	_feed(Vector2i(5, 3), &"coal", 5)
	for y: int in [4, 5, 6]:
		PlacedVerbs.place_conduit(world, Vector2i(5, y))
	PlacedVerbs.place_conduit(world, Vector2i(6, 6))
	_steps(2)
	_check(machines.power_at(Vector2i(5, 4)) == 5520, "first tube: 6000 x 92% = 5520, above its own 4000 aura")
	_check(machines.power_at(Vector2i(5, 5)) == 5078 and machines.power_at(Vector2i(5, 6)) == 4671, "each cell down keeps 92% (integer floors)")
	_check(machines.power_at(Vector2i(5, 7)) == 2802, "bleed to the cell under the last tube: 4671 x 60%")
	_check(machines.power_at(Vector2i(6, 6)) == 4671 and machines.power_at(Vector2i(4, 6)) == 2802 and machines.power_at(Vector2i(7, 6)) == 2802, "the side tube is fed diagonally from the tube above-left at 92%, which beats the 80% lateral; bleed reaches both sides of the row")
	_rig()
	_put(&"generator", Vector2i(5, 8))
	_feed(Vector2i(5, 8), &"coal", 5)
	for y: int in [7, 6, 5, 4]:
		PlacedVerbs.place_conduit(world, Vector2i(5, y))
	_steps(2)
	var s2: Dictionary = machines.power
	_check(int(s2.get(Vector2i(5, 7), 0)) == 4000 and int(s2.get(Vector2i(5, 6), 0)) == 2000, "tubes above the generator light only by its aura")
	_check(not s2.has(Vector2i(5, 5)) and not s2.has(Vector2i(5, 4)), "power never flows UP a conduit")


## legacy `_test_production`: 2 ore -> 1 ingot over 40 ticks; junk passes through; the ledger balances.
func _test_recipe_runner_consumes_produces_and_passes_junk_through() -> void:
	_rig()
	var forge: MachineState = _put(&"processor", Vector2i(5, 6))
	_feed(Vector2i(5, 6), &"ore", 5)
	_feed(Vector2i(5, 6), &"coal", 1)
	_steps(1)
	_check(int(items.piles.sink.get(&"coal", 0)) == 1 and not forge.input_buffer.has(&"coal"), "coal is not in the recipe: passed through and fell on out (to the sink, no floor) on the first tick")
	_check(forge.progress_ticks == 1, "progress counts in ticks")
	_steps(38)
	_check(int(items.total_produced.get(&"ingot", 0)) == 0, "39 ticks: nothing yet")
	_steps(1)
	_check(int(items.piles.sink.get(&"ingot", 0)) == 1 and int(forge.input_buffer[&"ore"]) == 3, "tick 40: one ingot (fallen on out), two ore eaten")
	_check(int(items.total_produced[&"ingot"]) == 1 and int(items.total_consumed[&"ore"]) == 2, "the ledger saw the craft")
	_steps(40)
	_check(int(items.total_produced[&"ingot"]) == 2 and int(forge.input_buffer[&"ore"]) == 1, "a second craft; the odd ore waits")
	_steps(200)
	_check(int(items.total_produced[&"ingot"]) == 2 and forge.progress_ticks == 0, "starved: no progress accrues without a full input set")
	_check(Invariants.check_item_conservation(items, 280) == null, "present == produced - consumed across buffers, with machine_total attached")
	_check(_status(Vector2i(5, 6)) == &"no_input", "one ore short reads no_input")


func _test_unknown_tag_runs_the_recipe_and_flags_read_the_registry() -> void:
	_rig()
	_check(Runners.behavior_flag(MachineDef.of(&"generator"), &"power_source") and Runners.behavior_flag(MachineDef.of(&"lift"), &"updraft"), "the registry's flags")
	_check(not Runners.behavior_flag(MachineDef.of(&"drill"), &"updraft") and not Runners.behavior_flag(MachineDef.of(&"blast_furnace"), &"power_source"), "absent flags and unknown tags read false")
	var furnace: MachineState = _put(&"blast_furnace", Vector2i(4, 4))
	_feed(Vector2i(4, 4), &"rich_ore", 1)
	_steps(44)
	_check(int(items.total_produced.get(&"ingot", 0)) == 2 and furnace.output_buffer.is_empty(), "blast_furnace is a tag the table does not know: it runs its recipe (1 rich ore -> 2 ingots in 44 ticks)")
	_check(_status(Vector2i(4, 4)) == &"no_input", "and reads status by the recipe path")
	_put(&"rope", Vector2i(6, 6))
	_steps(3)
	_check(_status(Vector2i(6, 6)) == &"idle" and machines.machine_at(Vector2i(6, 6)).progress_ticks == 0, "a def with no recipe idles")


## legacy `_test_coal_and_fuel`'s generator half.
func _test_generator_burns_coal_and_the_field_follows_its_fuel() -> void:
	_rig()
	var gen: MachineState = _put(&"generator", Vector2i(5, 5))
	_feed(Vector2i(5, 5), &"coal", 1)
	_steps(1)
	_check(gen.fuel == 100 and not gen.input_buffer.has(&"coal") and int(items.total_consumed[&"coal"]) == 1, "lighting a coal consumes it: fuel_ticks 100, lit after the burn step so the first burn is next tick")
	_steps(100)
	_check(gen.fuel == 0 and machines.power_at(Vector2i(5, 5)) == 6000, "the last tick of the coal: the field was computed while it still burned")
	_steps(1)
	_check(machines.power_at(Vector2i(5, 5)) == 0 and _status(Vector2i(5, 5)) == &"no_fuel", "spent and dark")
	_check(Invariants.check_item_conservation(items, 101) == null, "the burnt coal is consumed, not lost")


## legacy `_test_pump`: powered drains at most rate x throttle; unpowered nothing; rock caps the reach.
func _test_pump_drains_only_while_powered_and_rock_caps_its_reach() -> void:
	_rig()
	_basin(3, 4, 6)
	for y: int in [4, 5, 6]:
		for tc: Vector2i in world.terrain_cells_of(Vector2i(3, y)):
			world.water.set_level(tc, WaterPlane.WATER_MAX)
	var full: int = 3 * 16 * WaterPlane.WATER_MAX
	_put(&"pump", Vector2i(3, 4))
	_steps(5)
	_check(world.water.total_water() == full and _status(Vector2i(3, 4)) == &"idle", "three metres (384 units) in a walled basin; unpowered: drains nothing, reads idle")
	_put(&"generator", Vector2i(3, 3))
	_feed(Vector2i(3, 3), &"coal", 3)
	_steps(2)
	var pump: MachineState = machines.machine_at(Vector2i(3, 4))
	_check(pump.power_permille == 1000 and world.water.total_water() == full - 48, "powered at 4000 of 4000 demand: rate 3 per metre-cell x16 = 48 units drained in one tick")
	_check(_status(Vector2i(3, 4)) == &"working" and Invariants.check_water_not_in_rock(world.water, world.grid, 2) == null, "working, and no water entered rock")
	_steps(200)
	_check(world.water.total_water() == 0 and _status(Vector2i(3, 4)) == &"idle", "the column pumped dry reads idle, benignly")
	_rig()
	world.set_solid(Vector2i(3, 6), ROCK)
	_basin(3, 8, 8)
	for tc: Vector2i in world.terrain_cells_of(Vector2i(3, 8)):
		world.water.set_level(tc, WaterPlane.WATER_MAX)
	_put(&"pump", Vector2i(3, 4))
	_put(&"generator", Vector2i(3, 3))
	_feed(Vector2i(3, 3), &"coal", 3)
	_steps(30)
	_check(world.water.total_water() == 16 * WaterPlane.WATER_MAX and _status(Vector2i(3, 4)) == &"idle", "rock two metres down caps the reach: the pool under it is untouched, the pump idles")


## legacy `_test_hopper`: latch on first taste, pass the rest through, meter one a tick, hold at the cap.
func _test_hopper_latches_filters_meters_and_holds_under_back_pressure() -> void:
	_rig()
	var hop: MachineState = _put(&"hopper", Vector2i(5, 3))
	_feed(Vector2i(5, 3), &"ore", 4)
	_feed(Vector2i(5, 3), &"coal", 2)
	_steps(3)
	_check(hop.filter == &"ore", "latched on the first thing it tasted (insertion order), consumer or not")
	_check(int(items.piles.sink.get(&"coal", 0)) == 2 and not hop.input_buffer.has(&"coal"), "the other item passed straight through and fell on out")
	_check(int(hop.input_buffer[&"ore"]) == 4, "no consumer below: the banked good is stored")
	var forge: MachineState = _put(&"processor", Vector2i(5, 7))
	_steps(1)
	_check(int(forge.input_buffer[&"ore"]) == 1 and int(hop.input_buffer[&"ore"]) == 3 and _status(Vector2i(5, 3)) == &"working", "a consumer below: metered, release 1 a tick, into the forge")
	_steps(2)
	_check(int(forge.input_buffer[&"ore"]) == 3 and int(hop.input_buffer[&"ore"]) == 1 and _status(Vector2i(5, 3)) == &"blocked", "the forge holds feed_cap 3: the hopper holds its last one and reads blocked")
	_steps(1)
	_check(int(hop.input_buffer[&"ore"]) == 1, "and keeps holding it")
	_check(MachineVerbs.configure_machine(machines, Vector2i(5, 3)).begins_with("hopper") and hop.filter == &"", "configure clears the filter to re-taste")
	_check(MachineVerbs.configure_machine(machines, Vector2i(5, 7)) == "" and MachineVerbs.configure_machine(machines, Vector2i(1, 1)) == "", "nothing to configure on a forge or an empty cell")
	forge.input_buffer.clear()
	_steps(1)
	_check(hop.input_buffer.is_empty() and int(forge.input_buffer[&"ore"]) == 1, "cap lifted: the last unit released; the buffer stays free of zero keys")


## legacy `_test_finite_deposit_and_drill` + the undermine half of `_test_coal_and_fuel`.
func _test_drill_bores_the_deepest_ore_bottom_up_burns_coal_and_pours_down() -> void:
	_rig()
	world.set_solid(Vector2i(5, 5), ORE_ROCK)
	world.set_solid(Vector2i(5, 6), ORE_ROCK)
	world.set_solid(Vector2i(5, 10), ROCK)
	var drill: MachineState = _put(&"drill", Vector2i(5, 3))
	_check(Runners.drill_target(world, machines, Vector2i(5, 3)) == Vector2i(5, 6), "the target is the DEEPEST ore metre of the body, through the air gap")
	_check(_status(Vector2i(5, 3)) == &"no_fuel", "a target with a drain and no coal: no_fuel")
	_steps(5)
	_check(drill.progress_ticks == 0, "no coal: holds")
	_feed(Vector2i(5, 3), &"coal", 2)
	_steps(20)
	_check(drill.fuel == 40 and int(items.total_produced[ORE]) == 1, "one cycle (20 ticks): one unit bored, 20 fuel ticks burnt of the coal's 60")
	_check(items.piles.count_at(Vector2i(5, 9), ORE) == 1 and items.flow_events[0]["from"] == Vector2i(5, 6), "the unit poured down the column from the bored metre onto the floor")
	_check(world.deposits.ore_deposit_at(world.grid, Vector2i(20, 24)) == 15 and world.logic_ore_body(Vector2i(5, 6)), "the first 4 px cell of the metre lost one of its 16; the metre is still an ore body")
	for tc: Vector2i in world.terrain_cells_of(Vector2i(5, 6)):
		world.deposits.set_deposit(tc, 1)
	for tc: Vector2i in world.terrain_cells_of(Vector2i(5, 5)):
		world.deposits.set_deposit(tc, 1)
	_feed(Vector2i(5, 3), &"coal", 20)
	_steps(16 * 20)
	_check(world.logic_air(Vector2i(5, 6)) and world.logic_solid(Vector2i(5, 5)), "sixteen cycles at one a cell: the deeper metre is bored out, the one above untouched (bottom-up)")
	_check(Runners.drill_target(world, machines, Vector2i(5, 3)) == Vector2i(5, 5), "the target moved up to the next metre")
	_steps(16 * 20)
	_check(world.logic_air(Vector2i(5, 5)) and _status(Vector2i(5, 3)) == &"no_input", "the body is gone: no_input")
	_check(items.piles.count_at(Vector2i(5, 9), ORE) == 33 and int(items.total_produced[ORE]) == 33, "every bored unit is on the floor: 1 + 16 + 16")
	_check(Invariants.check_item_conservation(items, 660) == null, "conserved, coal burnt included")
	var burnt: int = int(items.total_consumed[&"coal"])
	_check(burnt == 11 and drill.fuel == 0, "660 running ticks over 60-tick coals: exactly 11 coals, the last spent on the last cycle")
	_rig()
	world.set_solid(Vector2i(5, 5), ORE_ROCK)
	world.set_solid(Vector2i(5, 9), ROCK)
	_put(&"drill", Vector2i(5, 3))
	var forge: MachineState = _put(&"processor", Vector2i(5, 7))
	_feed(Vector2i(5, 3), &"coal", 1)
	_steps(20)
	_check(int(forge.input_buffer.get(ORE, 0)) == 1 and items.piles.count_at(Vector2i(5, 8), ORE) == 0, "a machine below collects the bored unit INTO ITS RECIPE: the vein yields `ore`, the forge's input, so the line's first link holds (D0409; before it, `ore_iron` fell through to the floor)")
	world.grid.set_material(Vector2i(20, 22), ROCK)   # one stone cell inside ore metre (5, 5)
	_check(Runners.drill_target(world, machines, Vector2i(5, 3)) == Runners.NONE and _status(Vector2i(5, 3)) == &"no_input", "a single stone cell inside the metre caps the column: the bit only takes ore")


func _test_drill_gates_blocked_no_fuel_and_a_head_on_a_lode() -> void:
	_rig()
	world.set_solid(Vector2i(5, 5), ORE_ROCK)
	world.set_solid(Vector2i(5, 6), ROCK)
	var drill: MachineState = _put(&"drill", Vector2i(5, 3))
	_feed(Vector2i(5, 3), &"coal", 1)
	_check(Runners.drill_blocked(world, machines, Vector2i(5, 5)) and _status(Vector2i(5, 3)) == &"blocked", "rock under the ore: nowhere to drain, blocked")
	_steps(10)
	_check(drill.fuel == 0 and int(drill.input_buffer[&"coal"]) == 1 and drill.progress_ticks == 0, "blocked burns nothing")
	world.set_solid(Vector2i(5, 6), &"")
	_put(&"hopper", Vector2i(5, 6))
	_check(not Runners.drill_blocked(world, machines, Vector2i(5, 5)) and _status(Vector2i(5, 3)) == &"working", "a machine directly below is a drain")
	_rig()
	world.set_solid(Vector2i(5, 15), ORE_ROCK)
	_put(&"drill", Vector2i(5, 3))
	_check(_status(Vector2i(5, 3)) == &"blocked", "ore on the world floor has nowhere to drop")
	_rig()
	world.set_solid(Vector2i(5, 8), ROCK)
	var head: MachineState = _put(&"drill", Vector2i(5, 4))
	world.deposits.seed_lode(Vector2i(20, 16), &"coal", 2)
	world.deposits.seed_lode(Vector2i(21, 16), &"coal", 1)
	_check(Runners.drill_lode_target(world, Vector2i(5, 4)) == Vector2i(5, 4) and _status(Vector2i(5, 4)) == &"no_fuel", "a lode in the head's own metre: the head draws it in place; wants coal first")
	_feed(Vector2i(5, 4), &"coal", 1)
	_steps(20)
	_check(int(items.total_produced[&"coal"]) == 1 + 1 and head.fed == 1 and items.piles.count_at(Vector2i(5, 7), &"coal") == 1, "one unit a cycle off the vein (plus the coal fed), poured down the head's own column")
	_check(world.deposits.lode_permille(Vector2i(20, 16)) == 500 and world.logic_air(Vector2i(5, 4)), "the vein thins and nothing is cleared")
	_steps(40)
	_check(head.fed == 3 and world.deposits.lode_terrain_cells().is_empty(), "three units and the vein is gone")
	_check(_status(Vector2i(5, 4)) == &"spent", "spent is not starved: it pulled something and there is no lode left under it")
	_check(Invariants.check_item_conservation(items, 60) == null, "conserved")


## legacy `_test_machine_status`: the reads mirror the runners' gates.
func _test_machine_status_mirrors_each_runner() -> void:
	_rig()
	_put(&"processor", Vector2i(2, 2))
	_check(_status(Vector2i(2, 2)) == &"no_input", "forge, empty: no_input")
	_feed(Vector2i(2, 2), &"ore", 2)
	_check(_status(Vector2i(2, 2)) == &"working", "forge, fed: working")
	_put(&"generator", Vector2i(4, 2))
	_check(_status(Vector2i(4, 2)) == &"no_fuel", "generator, cold: no_fuel")
	_feed(Vector2i(4, 2), &"coal", 1)
	_check(_status(Vector2i(4, 2)) == &"working", "generator with coal waiting: working")
	_put(&"drill", Vector2i(6, 2))
	_check(_status(Vector2i(6, 2)) == &"no_input", "drill over nothing: no_input")
	_put(&"hopper", Vector2i(8, 2))
	_put(&"pump", Vector2i(10, 2))
	_check(_status(Vector2i(8, 2)) == &"idle" and _status(Vector2i(10, 2)) == &"idle", "hopper, empty: idle; pump, dark: idle")


## legacy `pickup_machine`'s order fix and `build_from_pack`.
func _test_build_and_pickup_verbs_salvage_in_the_safe_order_and_conserve() -> void:
	_rig()
	var def: MachineDef = MachineDef.of(&"hopper")
	_check(MachineVerbs.build_from_pack(items, machines, def, Vector2i(5, 4)) == null and machines.count() == 0, "nothing carried: nothing built")
	items.pack.add(&"hopper", 2)
	items.produced(&"hopper", 2)
	world.set_solid(Vector2i(5, 8), ROCK)
	var hop: MachineState = MachineVerbs.build_from_pack(items, machines, def, Vector2i(5, 4))
	_check(hop != null and items.pack.count(&"hopper") == 1 and int(items.total_consumed[&"hopper"]) == 1, "built from the pack: one left, one credited as world matter")
	_check(MachineVerbs.build_from_pack(items, machines, def, Vector2i(5, 4)) == null and items.pack.count(&"hopper") == 1, "a refused placement spends nothing")
	_check(Invariants.check_item_conservation(items, 1) == null, "conserved across the build")
	_feed(Vector2i(5, 4), &"ore", 100)
	hop.output_buffer[&"torch"] = 2
	items.produced(&"torch", 2)
	_check(items.pack.carried_bulk() == 0 and items.present(&"ore") == 100, "the pack is empty of bulk; the hopper holds 100 ore and 2 torches")
	_check(MachineVerbs.pickup_machine(items, machines, Vector2i(5, 4)) and machines.count() == 0, "picked up")
	_check(items.pack.count(&"hopper") == 2 and int(items.total_produced[&"hopper"]) == 3, "the machine item is back in the pack; produced mirrors build's consume")
	_check(items.pack.count(&"ore") == 90 and items.pack.count(&"torch") == 2, "salvaged up to the bulk cap of 90; torches are placeables, not bulk")
	_check(items.piles.count_at(Vector2i(5, 7), &"ore") == 10, "the overflow spilled down a column that no longer has the hopper at the top of it: it rests on the floor")
	_check(items.present(&"ore") == 100 and Invariants.check_item_conservation(items, 2) == null, "not one unit fed back into the buffer being emptied and destroyed (the order fix)")
	_check(not MachineVerbs.pickup_machine(items, machines, Vector2i(5, 4)) and MachineVerbs.build_from_pack(items, machines, null, Vector2i(6, 4)) == null, "nothing there any more; a null def refuses")


func _test_hub_tick_cadence_and_the_signature() -> void:
	_rig()
	var fired: Array[int] = []
	for t: int in range(0, 7):
		if HubTick.advance(t, world, items, machines):
			fired.append(t)
	var expected: Array[int] = [0, 3, 6]
	_check(fired == expected and HubTick.HUB_TICK_DIVISOR == 3, "the hub runs every third body tick: 20 Hz on the 60 Hz tick (D0345)")
	_check(machines.state_signature() == "m0:0", "no machines: the zero signature")
	var a: Machines = Machines.new()
	var b: Machines = Machines.new()
	var w2: World = World.new(TileGrid.new(64, 64, 1))
	a.place(world, MachineDef.of(&"hopper"), Vector2i(2, 2))
	a.place(world, MachineDef.of(&"drill"), Vector2i(4, 2))
	b.place(w2, MachineDef.of(&"hopper"), Vector2i(2, 2))
	b.place(w2, MachineDef.of(&"drill"), Vector2i(4, 2))
	_check(a.state_signature() == b.state_signature(), "two registries built the same way sign the same")
	var c: Machines = Machines.new()
	var w3: World = World.new(TileGrid.new(64, 64, 1))
	c.place(w3, MachineDef.of(&"drill"), Vector2i(4, 2))
	c.place(w3, MachineDef.of(&"hopper"), Vector2i(2, 2))
	_check(c.state_signature() != a.state_signature(), "PLACEMENT ORDER IS STATE: the same machines placed in the other order sign differently")
	b.machines[0].input_buffer[&"ore"] = 1
	_check(b.state_signature() != a.state_signature(), "a unit in a buffer changes it")
	b.machines[0].input_buffer.erase(&"ore")
	b.machines[1].fuel = 7
	var s_fuel: String = b.state_signature()
	_check(s_fuel != a.state_signature(), "fuel changes it")
	b.power[Vector2i(2, 2)] = 6000
	_check(b.state_signature() == s_fuel, "the power field is derived and NOT in the signature")
