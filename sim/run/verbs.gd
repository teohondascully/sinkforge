class_name Verbs
extends RefCounted

## THE SITUATED VERBS: what the body can do to the world from where it stands. Lifted in A' step 3i
## (D0355) from `legacy/scenes/main.gd`'s state-logic blocks: `try_build` 2645 and `_placeable` 2778,
## `try_drop` 2534 and `_reachable_eater` 2571, `_collect_ground_under_player` 2323 with the drop grace
## 2237-2262, `try_configure` 2148, `try_link_winch` 1487. Every edit goes through the sim's discrete
## verbs (`BuildVerbs`, `MachineVerbs`, `Items`); this object only decides WHICH one the press means,
## reach-gated by the one reach rule (`Aim.in_reach_logic`). The particles, sounds and toasts legacy
## fired beside each verb are the view's, read off the outcome this returns.
##
## Its own state is small and signed: the hotbar selection (a drop's subject), the per-cell no-pickup
## grace in ticks (a just-dropped stack is not sucked straight back up), and the armed winch head of the
## two-press link. Legacy did not save any of it; it is session-scoped and is not in the v3 envelope.
##
## Every cell here is a METRE (`logic_cell`); the body's box is `sim/body`'s.

## Scoop reach: ONE ARM'S LENGTH, the same 3.2 m the hand digs and builds at (`Mining.REACH_NUM/DEN`).
## Legacy's COLLECT_REACH_CELLS was 2.5 at its metre-tall body; this body's centre stands 1.25 m over its
## feet, so the tutorial forge's ingots -- two metres down the next column -- lay 2.9 m off and the rung
## "collect the ingots it makes" could not be done from where a player stands (D0409). One reach, everywhere.
const COLLECT_REACH_NUM: int = Mining.REACH_NUM
const COLLECT_REACH_DEN: int = Mining.REACH_DEN
const DROP_GRACE_TICKS: int = 78   # legacy DROP_GRACE_S 1.3 s at 60 Hz
const NONE: Vector2i = Vector2i(-1, -1)

var world: World
var items: Items
var machines: Machines
var body: Body
var selected: int = 0                  # hotbar index into `Pack.slots()`
## THE SELECTION FOLLOWS THE ITEM (D0412): the pack compacts when a stack drains, so an index alone
## re-pointed BUILD and DROP at whatever slid into the numbered position. `select()` remembers the item the
## index held (`followed`); `tick()` re-resolves the index to that item's current slot while it is carried,
## and when it is gone the index stays where it was. Session-scoped like `selected`, in the signature too.
var followed: StringName = &""
var auto_pickup: bool = true
var pending_winch_head: Vector2i = NONE
var _drop_grace: Dictionary = {}       # logic_cell -> ticks remaining


func _init(p_world: World, p_items: Items, p_machines: Machines, p_body: Body) -> void:
	world = p_world
	items = p_items
	machines = p_machines
	body = p_body


## Age the drop grace: once per tick, from the owner.
func tick() -> void:
	if followed != &"":
		var slots: Array[Dictionary] = items.pack.slots()
		for i: int in slots.size():
			if slots[i]["item"] == followed:
				selected = i
				break
	for cell: Vector2i in _drop_grace.keys():
		var left: int = int(_drop_grace[cell]) - 1
		if left <= 0:
			_drop_grace.erase(cell)
		else:
			_drop_grace[cell] = left


func body_logic_cell() -> Vector2i:
	return Aim.logic_cell_of(body.pos_x, body.pos_y)


func can_reach(logic_cell: Vector2i) -> bool:
	return Aim.in_reach_logic(body.pos_x, body.pos_y, logic_cell)


func selected_item() -> StringName:
	var slots: Array[Dictionary] = items.pack.slots()
	if slots.is_empty():
		return &""
	return slots[clampi(selected, 0, slots.size() - 1)]["item"]


func selected_machine_def() -> MachineDef:
	return MachineDef.of(selected_item())


## A building material in the hotbar: a material id the world knows, which is not also a placeable.
func selected_build_material() -> StringName:
	var item: StringName = selected_item()
	return item if WorldMaterials.exists(item) and not MachineDef.exists(item) else &""


## A cell takes a hand-placed machine when it is in bounds, unoccupied, and not the cell the body is
## standing in, so you can never seal yourself inside a machine you place. Occupancy is the sim's answer
## (every placed layer asked once, over there); bounds and the body are the two halves it cannot answer.
func placeable(logic_cell: Vector2i) -> bool:
	return world.logic_in_bounds(logic_cell) and not world.cell_occupied(logic_cell) and not body_occupies(logic_cell)


func body_occupies(logic_cell: Vector2i) -> bool:
	var left: int = logic_cell.x * Aim.LOGIC_FX
	var top: int = logic_cell.y * Aim.LOGIC_FX
	var half_w: int = Body.WIDTH_PX * Fx.SCALE / 2
	var half_h: int = Body.HEIGHT_PX * Fx.SCALE / 2
	return body.pos_x + half_w > left and body.pos_x - half_w < left + Aim.LOGIC_FX \
		and body.pos_y + half_h > top and body.pos_y - half_h < top + Aim.LOGIC_FX


## RMB: standing in reach of `cell`, pick up what is there (a machine, a conduit, a rope, a torch, a
## sapling), else place what is selected (a sapling on soil, a torch, a conduit, a rope, a machine, a
## block). Returns what happened, &"" for nothing.
func build(logic_cell: Vector2i) -> StringName:
	if not can_reach(logic_cell):
		return &""
	if machines.machine_at(logic_cell) != null:
		return &"picked_up" if MachineVerbs.pickup_machine(items, machines, logic_cell) else &""
	if world.logic.has_conduit(logic_cell):
		return &"conduit_removed" if BuildVerbs.remove_conduit(items, logic_cell) else &""
	if world.logic.is_climbable(logic_cell):
		return &"rope_retracted" if BuildVerbs.retract_rope(items, logic_cell) > 0 else &""
	if world.logic.has_torch(logic_cell):
		return &"torch_removed" if BuildVerbs.remove_torch(items, logic_cell) else &""
	if world.logic.has_sapling(logic_cell):
		return &"sapling_removed" if BuildVerbs.remove_sapling(items, logic_cell) else &""
	return _place(logic_cell)


func _place(logic_cell: Vector2i) -> StringName:
	if selected_item() == &"sapling":
		return &"planted" if BuildVerbs.plant_sapling(items, logic_cell) else &""
	var def: MachineDef = selected_machine_def()
	if def != null and def.behavior == &"torch":
		return &"torch" if BuildVerbs.place_torch(items, logic_cell) else &""
	if def != null and def.behavior == &"conduit":
		return &"conduit" if BuildVerbs.place_conduit(items, logic_cell) else &""
	if def != null and def.behavior == &"rope":
		return &"rope" if BuildVerbs.place_rope(items, logic_cell) > 0 else &""
	if def != null and placeable(logic_cell):
		return &"machine" if MachineVerbs.build_from_pack(items, machines, def, logic_cell, body.facing) != null else &""
	var material: StringName = selected_build_material()
	if material != &"" and placeable(logic_cell) and world.block_supported(logic_cell) and BuildVerbs.place_block(items, logic_cell, material):
		return &"block"
	return &""


## Q: drop the selected stack. Gravity is the conveyor, so feeding is dropping. When a machine in reach
## genuinely eats what you hold, the toss goes in; else it tosses forward into the facing column when
## that is not solid, else straight down your own column. Returns the units that left the pack.
func drop() -> int:
	var item: StringName = selected_item()
	if item == &"":
		return 0
	var carried: int = items.pack.count(item)
	var mouth: MachineState = reachable_eater(item)
	if mouth != null:
		var fed: int = items.deposit(mouth.logic_cell, item, carried)
		if fed > 0:
			return fed
	var here: Vector2i = body_logic_cell()
	var face: Vector2i = here + Vector2i(body.facing, 0)
	var target: Vector2i = face if (world.logic_in_bounds(face) and not world.logic_solid(face)) else here
	var dropped: int = items.drop_item(target, item, carried, here)
	if dropped > 0:
		_drop_grace[items.last_drop_landing] = DROP_GRACE_TICKS
	return dropped


## The nearest machine in reach that would consume `item`, or null; ties by distance, so a wall of
## machines feeds the one you stand at. Placement order breaks an exact tie, as legacy's list did.
func reachable_eater(item: StringName) -> MachineState:
	var best: MachineState = null
	var best_d: int = -1
	for m: MachineState in machines.machines:
		if not can_reach(m.logic_cell) or not Machines.machine_eats(m, item):
			continue
		var d: int = _dist_sq_to_metre(m.logic_cell)
		if best_d < 0 or d < best_d:
			best_d = d
			best = m
	return best


func _dist_sq_to_metre(logic_cell: Vector2i) -> int:
	var half: int = Aim.LOGIC_FX / 2
	return Fx.length_sq(logic_cell.x * Aim.LOGIC_FX + half - body.pos_x, logic_cell.y * Aim.LOGIC_FX + half - body.pos_y)


## Scoop resting piles within the scoop reach, skipping cells under drop grace. Returns units collected.
func collect() -> int:
	if not auto_pickup or items.piles.ground.is_empty():
		return 0
	var collected: int = 0
	var reach_fx: int = COLLECT_REACH_NUM * Aim.LOGIC_FX / COLLECT_REACH_DEN
	for cell: Vector2i in items.piles.pile_logic_cells():
		if _drop_grace.has(cell) or _dist_sq_to_metre(cell) > reach_fx * reach_fx:
			continue
		collected += items.collect_ground(cell)
	return collected


## R: configure the aimed machine. Reach-gated; the sim returns the toast text, "" for nothing.
func configure(logic_cell: Vector2i) -> String:
	if not can_reach(logic_cell):
		return ""
	return MachineVerbs.configure_machine(machines, logic_cell)


## L, twice: arm an unlinked head, then commit the route to an unlinked station. Returns `armed`,
## `linked`, `failed` (the second press did not link), or &"" for a press on nothing.
func link_winch(logic_cell: Vector2i) -> StringName:
	if not can_reach(logic_cell):
		return &""
	var target: MachineState = machines.machine_at(logic_cell)
	if target == null:
		return &""
	if target.def.behavior == &"winch_head" and not machines.winch_routes.has(logic_cell):
		pending_winch_head = logic_cell
		return &"armed"
	if target.def.behavior == &"winch_station" and pending_winch_head != NONE:
		var linked: bool = machines.link_winch(pending_winch_head, logic_cell)
		pending_winch_head = NONE
		return &"linked" if linked else &"failed"
	return &""


func state_signature() -> String:
	var grace: PackedStringArray = []
	for cell: Vector2i in Ordering.cells(_drop_grace):
		grace.append("%d,%d=%d" % [cell.x, cell.y, int(_drop_grace[cell])])
	return "v%d,%s,%d,%d|%s" % [selected, followed, pending_winch_head.x, pending_winch_head.y, ";".join(grace)]


## A hotbar digit: the index, and the item it holds now, which the selection then follows.
func select(index: int) -> void:
	selected = index
	var slots: Array[Dictionary] = items.pack.slots()
	followed = slots[index]["item"] if index >= 0 and index < slots.size() else &""
