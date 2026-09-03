class_name Items
extends RefCounted

## THE ITEM SERVICE: the pack, the piles, the ledger, and every verb that moves an item between them and
## the world. Lifted in A' step 3c (D0348) from `legacy/src/core/factory_sim.gd`: `take_into_pack` 1860
## (THE ONE DOOR into the pack for anything the cap counts), `_spill_to_world` 1879, `drop_item` 1599,
## `collect_ground` 3176, `_resettle_pile_above` 3158, `take_lode` 1525, `deposit` 1574, and the
## conservation ledger `total_produced`/`total_consumed` (:255). The builder verbs that spend the pack on
## a placed thing are `BuildVerbs`, kept in their own file for the size cap.
##
## THE RULE, stated once (legacy's words): a full pack does not refuse the swing. The block still breaks,
## the world still gives up its material, and whatever will not fit FALLS instead of vanishing. Refusing
## the dig would make a full pack feel like a broken control, and destroying the excess would break
## conservation. Spilling makes the cost a TRIP; every unit stays recoverable. The lode is the exception,
## and `take_lode` says why.
##
## CONSERVATION: items are created and destroyed only by a recipe (or a placement, which converts an
## item into world matter and back). `present(item)` = pack + ground + sink + machine buffers, and
## `Invariants.check_item_conservation` holds it to produced - consumed. Machine buffers are reached
## through `machine_buffer`, a Callable(logic_cell) -> Dictionary or null (see `Landing`), and their
## total through `machine_total`, a Callable(item) -> int; both default to "no machines".
##
## `flow_events` is a VIEW channel: item movements logged for the falling-sprite animation. The sim never
## reads it back; the observation drains it (plan step 4). `last_drop_landing` likewise (the pickup grace).

var world: World
var pack: Pack = Pack.new()
var piles: GroundPiles = GroundPiles.new()
var total_produced: Dictionary = {}   # item -> units the world has ever given up or a recipe made
var total_consumed: Dictionary = {}   # item -> units a recipe ate or a placement turned into world matter
var flow_events: Array[Dictionary] = []
var last_drop_landing: Vector2i = Vector2i(-1, -1)
var machine_buffer: Callable = Callable()
var machine_total: Callable = Callable()


func _init(p_world: World) -> void:
	world = p_world


func produced(item: StringName, n: int) -> void:
	total_produced[item] = int(total_produced.get(item, 0)) + n


func consumed(item: StringName, n: int) -> void:
	total_consumed[item] = int(total_consumed.get(item, 0)) + n


## Units of `item` anywhere: pack, ground, sink, and every machine buffer the owner reports.
func present(item: StringName) -> int:
	var in_machines: int = int(machine_total.call(item)) if machine_total.is_valid() else 0
	return pack.count(item) + piles.present(item) + in_machines


## Returns how many units actually entered the pack; the rest spilled at `spill_at` (down its column).
## Callers that record production keep counting the FULL amount: material on the floor was still
## extracted, and `collect_ground` does not count production, so nothing is double-counted later.
func take_into_pack(item: StringName, n: int, spill_at: Vector2i) -> int:
	if n <= 0:
		return 0
	var taken: int = n if not Pack.is_bulk_item(item) else mini(n, pack.pack_room())
	if taken > 0:
		pack.add(item, taken)
	var rest: int = n - taken
	if rest > 0:
		_spill_to_world(spill_at, item, rest)
	return taken


## The overflow half of `take_into_pack`: `drop_item`'s tail with the pack half removed. The units land
## exactly the way dropped items land, so a spilled unit is indistinguishable from a dropped one.
func _spill_to_world(logic_cell: Vector2i, item: StringName, n: int) -> void:
	var dest: Dictionary = Landing.column_landing(world, piles, machine_buffer, logic_cell.x, logic_cell.y)
	dest["target"][item] = int(dest["target"].get(item, 0)) + n
	flow_events.append({"item": item, "from": logic_cell, "to": dest["to_cell"], "count": n})
	last_drop_landing = dest["to_cell"]


## Drop items from the pack into a column. Gravity is the conveyor: they FALL, into the first machine
## below, else onto the first floor as a re-collectable pile, else the sink. Returns how many dropped.
## `from_cell` is the visual launch origin for the toss; it colours only the flow event.
func drop_item(logic_cell: Vector2i, item: StringName, n: int, from_cell: Vector2i = Vector2i(-1, -1)) -> int:
	var dropped: int = pack.remove(item, n)
	if dropped <= 0:
		return 0
	var origin: Vector2i = logic_cell if from_cell == Vector2i(-1, -1) else from_cell
	var dest: Dictionary = Landing.column_landing(world, piles, machine_buffer, logic_cell.x, logic_cell.y)
	dest["target"][item] = int(dest["target"].get(item, 0)) + dropped
	flow_events.append({"item": item, "from": origin, "to": dest["to_cell"], "count": dropped})
	last_drop_landing = dest["to_cell"]
	return dropped


## Walk over a resting pile and scoop it into the pack. THE CAP APPLIES TO PICKING UP TOO: what does
## not fit STAYS in the pile, so the floor keeps it until there is room. Returns how many were collected.
func collect_ground(logic_cell: Vector2i) -> int:
	var pile: Dictionary = piles.ground.get(logic_cell, {})
	if pile.is_empty():
		return 0
	var collected: int = 0
	for item: StringName in Ordering.ids(pile):
		var want: int = int(pile[item])
		var got: int = want if not Pack.is_bulk_item(item) else mini(want, pack.pack_room())
		if got > 0:
			pack.add(item, got)
			collected += got
		if got >= want:
			pile.erase(item)
		else:
			pile[item] = want - got
	if pile.is_empty():
		piles.ground.erase(logic_cell)
	return collected


## When the floor under a resting pile is removed, the pile cannot hang in mid-air: cascade it down the
## now-open column to the next machine or floor below. Conservation-neutral. Call AFTER clearing the cell.
func resettle_pile_above(logic_cell: Vector2i) -> void:
	var above := logic_cell + Vector2i(0, -1)
	if not piles.ground.has(above):
		return
	var pile: Dictionary = piles.ground[above]
	piles.ground.erase(above)
	var dest: Dictionary = Landing.column_landing(world, piles, machine_buffer, logic_cell.x, logic_cell.y)
	for item: StringName in Ordering.ids(pile):
		var n: int = int(pile[item])
		if n <= 0:
			continue
		dest["target"][item] = int(dest["target"].get(item, 0)) + n
		flow_events.append({"item": item, "from": above, "to": dest["to_cell"], "count": n})
	piles.prune_empty()   # column_landing may have created an empty landing pile it didn't fill


## Take ONE UNIT from an exposed lode: the hand verb. THIS VERB REFUSES WHERE `mine` SPILLS: a lode face
## is not destroyed by being worked, so a full pack simply does not take the unit and the vein stays
## intact rather than being drained onto the floor one click at a time. Returns the item, or &"".
func take_lode(terrain_cell: Vector2i) -> StringName:
	if not world.deposits.lode_workable(world.grid, terrain_cell):
		return &""
	var item: StringName = world.deposits.lode_at(terrain_cell)
	if not pack.can_carry(item, 1):
		return &""
	var taken: StringName = world.deposits.take_one(world.grid, terrain_cell)
	pack.add(taken, 1)
	produced(taken, 1)
	return taken


## Hand items from the pack into the input buffer of the machine at `logic_cell`. Returns the number
## actually deposited, capped by what is carried. Unfiltered on purpose (a test rig may prime any
## buffer); "would this machine eat it" is the player-facing question and lives with the machines.
func deposit(logic_cell: Vector2i, item: StringName, n: int) -> int:
	if n <= 0 or not machine_buffer.is_valid():
		return 0
	var buffer: Variant = machine_buffer.call(logic_cell)
	if buffer == null:
		return 0
	var moved: int = pack.remove(item, n)
	if moved > 0:
		buffer[item] = int(buffer.get(item, 0)) + moved
	return moved


## The item state's signature: the pack's lanes, the piles from scratch, the ledger from scratch.
func state_signature() -> String:
	var a: int = 0
	var b: int = 0
	for item: StringName in Ordering.ids(total_produced):
		var f: Vector2i = StateHash.id_fold(item)
		var t: Vector2i = StateHash.term(f.x, f.y, Vector2i(int(total_produced[item]), 0), Vector2i.ONE)
		a ^= t.x
		b ^= t.y
	for item: StringName in Ordering.ids(total_consumed):
		var f2: Vector2i = StateHash.id_fold(item)
		var t2: Vector2i = StateHash.term(f2.x, f2.y, Vector2i(0, int(total_consumed[item])), Vector2i(2, 2))
		a ^= t2.x
		b ^= t2.y
	return "%s|%s|i%d:%d" % [pack.state_signature(), piles.recomputed_signature(), a, b]
