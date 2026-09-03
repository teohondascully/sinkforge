class_name Flow
extends RefCounted

## THE FLOW PHASE: each machine's output is handed to its destination. Gravity is the conveyor: an
## ordinary machine's output goes straight DOWN its column (the landing rule); a lift's goes UP (the
## rise, gravity's paid inverse). Items are only moved here, never created or destroyed.
##
## Lifted in A' step 3e (D0350) from `legacy/src/core/factory_sim.gd`: `_flow` 2963, `_destinations`
## 3068, `_destinations_lift`, `_deliver` 3057, `_column_rise` 2409, `updraft_at` 585. Runs third in the
## hub tick, after every runner and before water, exactly where legacy ran it. The splitter's
## multi-destination dealing (`_split_pattern`, `route_toggle`) waits on its ruling (plan §8): every
## machine here has ONE destination.
##
## This module walks the registry and reads a machine's `def.behavior` only through the registry's
## routing (`updraft`); it prices and routes movement, it does not run a machine.

## Move every machine's output buffer to its destination, in placement order.
static func step(world: World, items: Items, machines: Machines) -> void:
	for m: MachineState in machines.machines:
		if m.output_buffer.is_empty():
			continue
		deliver(items, m, destination(world, items, machines, m), m.output_buffer)
		m.output_buffer.clear()


## Where a machine's output goes: `{to_cell, target}`. A lift routes up its column; everything else
## falls down it.
static func destination(world: World, items: Items, machines: Machines, m: MachineState) -> Dictionary:
	if Runners.behavior_flag(m.def, &"updraft"):
		return column_rise(world, items.piles, machines, m.logic_cell.x, m.logic_cell.y - 1)
	return Landing.column_landing(world, items.piles, items.machine_buffer, m.logic_cell.x, m.logic_cell.y + 1)


## Move a bundle of items from `m` into one destination, logging the flow event the view draws.
static func deliver(items: Items, m: MachineState, dest: Dictionary, bundle: Dictionary) -> void:
	var target: Dictionary = dest["target"]
	var to_cell: Vector2i = dest["to_cell"]
	for item: StringName in Ordering.ids(bundle):
		var count: int = int(bundle[item])
		target[item] = int(target.get(item, 0)) + count
		items.flow_events.append({"item": item, "from": m.logic_cell, "to": to_cell, "count": count})


## The lift's mirror of the landing rule: walk UP the column from `start_row` to the first machine (its
## input buffer) or the first metre with any rock (a ceiling: the pile rests in the open metre under it),
## else the pile in the world's top row. A live target dictionary, so `deliver` adds straight into it.
static func column_rise(world: World, piles: GroundPiles, machines: Machines, col: int, start_row: int) -> Dictionary:
	for row: int in range(start_row, -1, -1):
		var c := Vector2i(col, row)
		var m: MachineState = machines.machine_at(c)
		if m != null:
			return {"to_cell": c, "target": m.input_buffer}
		if not world.logic_air(c):
			var rest := Vector2i(col, row + 1)
			return {"to_cell": rest, "target": piles.pile(rest)}
	var top := Vector2i(col, 0)
	return {"to_cell": top, "target": piles.pile(top)}


## Is `logic_cell` inside a lift's updraft: is there a clear column straight DOWN to a machine whose
## behaviour carries the `updraft` flag? A floor breaks the draft; the first machine below answers.
static func updraft_at(world: World, machines: Machines, logic_cell: Vector2i) -> bool:
	for row: int in range(logic_cell.y + 1, Landing.floor_rows(world)):
		var here := Vector2i(logic_cell.x, row)
		if not world.logic_air(here):
			return false
		var m: MachineState = machines.machine_at(here)
		if m != null:
			return Runners.behavior_flag(m.def, &"updraft")
	return false
