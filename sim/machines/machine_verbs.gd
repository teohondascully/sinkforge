class_name MachineVerbs
extends RefCounted

## The player's machine verbs over the registry and the item service: `build_from_pack` 1715,
## `pickup_machine` 1752 and `configure_machine` 3014 of `legacy/src/core/factory_sim.gd`, lifted in A'
## step 3d (D0349). Statics, like `BuildVerbs`: the verbs are the seam `Interface.apply` reaches, and
## nothing here holds state.

## Place a machine the pack carries. Returns the new state, or null when the pack has none or the cell
## refuses. The machine item leaves the pack and is credited as consumed: it became world matter.
static func build_from_pack(items: Items, machines: Machines, def: MachineDef, logic_cell: Vector2i, facing: int = 1) -> MachineState:
	if def == null or items.pack.count(def.id) <= 0:
		return null
	var state: MachineState = machines.place(items.world, def, logic_cell, facing)
	if state == null:
		return null
	items.pack.remove(def.id, 1)
	items.consumed(def.id, 1)
	return state


## Pick a placed machine back up into the pack as one machine item. Returns true if one was there. Its
## buffers are SALVAGED into the pack (spilling past the cap, on the same rule as mining), never
## destroyed.
##
## THE ORDER MATTERS AND LEGACY'S FIRST VERSION GOT IT WRONG: spilling while the machine was still in
## the grid sent the overflow down its own column, where the landing rule found THIS MACHINE, fed the
## units back into the buffer being emptied, and the removal then destroyed them. So the contents come
## out first, the machine is removed, and only then is anything spilled into a column with no machine
## at the top of it.
static func pickup_machine(items: Items, machines: Machines, logic_cell: Vector2i) -> bool:
	var state: MachineState = machines.machine_at(logic_cell)
	if state == null:
		return false
	var salvaged: Dictionary = {}
	for buffer: Dictionary in [state.input_buffer, state.output_buffer]:
		for item: StringName in buffer:
			salvaged[item] = int(salvaged.get(item, 0)) + int(buffer[item])
		buffer.clear()   # salvaged out either way, and cleared so remove has nothing to destroy
	machines.remove(items.world, items, logic_cell)
	for item: StringName in Ordering.ids(salvaged):
		items.take_into_pack(item, int(salvaged[item]), logic_cell)
	items.pack.add(state.def.id, 1)
	items.produced(state.def.id, 1)   # mirrors build's consume
	return true


## The configure verb (R in legacy): a hopper clears its filter and re-tastes. The splitter's ratio
## cycle joins it in step 3e. Returns the toast text, "" when the cell has nothing configurable.
static func configure_machine(machines: Machines, logic_cell: Vector2i) -> String:
	var m: MachineState = machines.machine_at(logic_cell)
	if m == null:
		return ""
	if m.def.behavior == &"hopper":
		m.filter = &""
		return "hopper: filter cleared, it keeps the next thing it tastes"
	return ""
