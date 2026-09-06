extends "res://tests/test_base.gd"

## `sim/run/verbs.gd` (A' step 3i, verbs half, D0355): the situated verbs legacy's main scene ran --
## build and pick up, drop (into an eater, forward, or straight down) with its grace, scoop within
## reach, configure, the two-press winch link -- over the four services, reach-gated at the metre.

const ROCK: StringName = &"hardrock"

var world: World
var items: Items
var machines: Machines
var body: Body
var verbs: Verbs


func _initialize() -> void:
	_test_placeable_bounds_occupancy_and_the_body_itself()
	_test_build_places_and_picks_up_every_kind_by_what_is_selected()
	_test_drop_feeds_an_eater_else_tosses_forward_else_straight_down_and_grace_holds_it()
	_test_collect_reach_and_configure()
	_test_winch_link_is_two_presses()
	_finish("verbs")


## A 16 x 16 metre world, ground from row 10 down, the body standing on it at column 5.
func _rig() -> void:
	items = _hub_items()
	world = items.world
	machines = _hub_machines(items)
	for row_m: int in range(10, 16):
		for col_m: int in 16:
			world.set_solid(Vector2i(col_m, row_m), ROCK)
	body = Body.new(Fx.from_int(5 * 16 + 8), Fx.from_int(10 * 16) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	verbs = Verbs.new(world, items, machines, body)


func _carry(item: StringName, n: int) -> void:
	items.pack.add(item, n)
	items.produced(item, n)


func _select(item: StringName) -> void:
	var slots: Array[Dictionary] = items.pack.slots()
	for i: int in slots.size():
		if slots[i]["item"] == item:
			verbs.selected = i
			return
	_check(false, "select: %s is not in the pack" % item)


func _test_placeable_bounds_occupancy_and_the_body_itself() -> void:
	_rig()
	_check(verbs.body_logic_cell() == Vector2i(5, 8) and verbs.body_occupies(Vector2i(5, 9)) and verbs.body_occupies(Vector2i(5, 7)), "the body's centre is in metre (5, 8) and its 40 px box reaches (5, 7) and (5, 9)")
	_check(not verbs.body_occupies(Vector2i(6, 8)) and not verbs.body_occupies(Vector2i(5, 10)), "not the next column, not the floor")
	_check(not verbs.placeable(Vector2i(5, 9)) and verbs.placeable(Vector2i(6, 9)), "you can never seal yourself inside a machine you place; the cell beside you takes one")
	_check(not verbs.placeable(Vector2i(5, 10)) and not verbs.placeable(Vector2i(40, 9)), "rock and out of bounds do not")
	_check(verbs.can_reach(Vector2i(8, 9)) and not verbs.can_reach(Vector2i(9, 9)), "reach at the metre: 3 metres over is in, 4 is out (the one reach rule)")
	_check(verbs.selected_item() == &"" and verbs.selected_machine_def() == null and verbs.selected_build_material() == &"", "an empty pack selects nothing")


func _test_build_places_and_picks_up_every_kind_by_what_is_selected() -> void:
	_rig()
	body.facing = -1
	_carry(&"hopper", 1)
	_select(&"hopper")
	_check(verbs.build(Vector2i(14, 9)) == &"" and verbs.build(Vector2i(5, 9)) == &"" and verbs.build(Vector2i(5, 10)) == &"" and machines.count() == 0, "out of reach, your own cell, and rock: nothing")
	_check(verbs.build(Vector2i(6, 9)) == &"machine" and machines.machine_at(Vector2i(6, 9)).facing == -1 and items.pack.count(&"hopper") == 0, "a selected machine is built from the pack, facing the way the body faces")
	_check(verbs.build(Vector2i(6, 9)) == &"picked_up" and items.pack.count(&"hopper") == 1 and machines.count() == 0, "RMB on your machine picks it back up")
	_rig()
	_carry(&"conduit", 1)
	_select(&"conduit")
	_check(verbs.build(Vector2i(7, 9)) == &"conduit" and world.logic.has_conduit(Vector2i(7, 9)), "a conduit is laid")
	_check(verbs.build(Vector2i(7, 9)) == &"conduit_removed" and items.pack.count(&"conduit") == 1, "and picked back up")
	_rig()
	for row_m: int in range(10, 13):
		world.set_solid(Vector2i(7, row_m), &"")
	_carry(&"rope", 4)
	_select(&"rope")
	_check(verbs.build(Vector2i(7, 9)) == &"rope" and world.logic.is_climbable(Vector2i(7, 12)) and items.pack.count(&"rope") == 0, "four carried ropes anchor and unroll four segments down the open column")
	_check(verbs.build(Vector2i(7, 11)) == &"" and verbs.build(Vector2i(7, 10)) == &"rope_retracted" and items.pack.count(&"rope") == 4 and not world.logic.is_climbable(Vector2i(7, 9)), "RMB any segment in reach and the whole rope returns (the third segment is out of reach)")
	_rig()
	_carry(&"torch", 1)
	_select(&"torch")
	_check(verbs.build(Vector2i(4, 9)) == &"torch" and world.logic.has_torch(Vector2i(4, 9)), "a torch mounts on a rock-adjacent open cell")
	_check(verbs.build(Vector2i(4, 9)) == &"torch_removed" and items.pack.count(&"torch") == 1, "and comes back")
	_rig()
	world.set_solid(Vector2i(6, 10), &"clay")
	_carry(&"sapling", 1)
	_select(&"sapling")
	_check(verbs.build(Vector2i(6, 9)) == &"planted" and world.logic.has_sapling(Vector2i(6, 9)), "a sapling roots on soil")
	_check(verbs.build(Vector2i(6, 9)) == &"sapling_removed" and items.pack.count(&"sapling") == 1, "and can be taken back")
	_rig()
	_carry(ROCK, 1)
	_select(ROCK)
	_check(verbs.selected_build_material() == ROCK and verbs.build(Vector2i(7, 8)) == &"" and not world.logic_solid(Vector2i(7, 8)), "a block wants support: (7, 8) has none")
	_check(verbs.build(Vector2i(6, 9)) == &"block" and world.logic_solid(Vector2i(6, 9)) and items.pack.count(ROCK) == 0, "a carried material places a supported block")
	_check(Invariants.check_item_conservation(items, 1) == null, "every placement and pickup balanced the ledger")


func _test_drop_feeds_an_eater_else_tosses_forward_else_straight_down_and_grace_holds_it() -> void:
	_rig()
	_check(verbs.drop() == 0, "nothing carried, nothing dropped")
	_carry(&"ore", 5)
	_select(&"ore")
	var forge: MachineState = machines.place(world, MachineDef.of(&"processor"), Vector2i(7, 9))
	_check(verbs.reachable_eater(&"ore") == forge and verbs.reachable_eater(&"coal") == null, "the forge in reach eats ore, not coal")
	_check(verbs.drop() == 5 and int(forge.input_buffer[&"ore"]) == 5 and items.pack.is_empty(), "the toss goes into a machine in reach that wants it")
	machines.remove(world, items, Vector2i(7, 9))
	_carry(&"coal", 3)
	_select(&"coal")
	body.facing = 1
	_check(verbs.drop() == 3 and items.piles.count_at(Vector2i(6, 9), &"coal") == 3 and items.last_drop_landing == Vector2i(6, 9), "no eater: tossed forward into the facing column, landing on its floor")
	_check(verbs.collect() == 0 and items.piles.count_at(Vector2i(6, 9), &"coal") == 3, "just dropped: the grace keeps it from being sucked straight back up")
	for _i: int in Verbs.DROP_GRACE_TICKS - 1:
		verbs.tick()
	_check(verbs.collect() == 0, "one tick short of the grace")
	verbs.tick()
	_check(verbs.collect() == 3 and items.pack.count(&"coal") == 3, "grace over: scooped back")
	world.set_solid(Vector2i(6, 8), ROCK)
	_check(verbs.drop() == 3 and items.piles.count_at(Vector2i(5, 9), &"coal") == 3, "a wall ahead of the body's cell: it drops straight down your own column instead")
	_check(verbs.state_signature() != Verbs.new(world, items, machines, body).state_signature(), "the grace table is signed state")
	_check(Invariants.check_item_conservation(items, 80) == null, "conserved through every toss")


func _test_collect_reach_and_configure() -> void:
	_rig()
	_carry(&"ingot", 4)
	items.drop_item(Vector2i(7, 2), &"ingot", 2)
	items.drop_item(Vector2i(9, 2), &"ingot", 2)
	_check(items.piles.count_at(Vector2i(7, 9), &"ingot") == 2 and items.piles.count_at(Vector2i(9, 9), &"ingot") == 2, "two piles on the floor, two and four metres over")
	verbs.auto_pickup = false
	_check(verbs.collect() == 0, "auto-pickup off: nothing")
	verbs.auto_pickup = true
	_check(verbs.collect() == 2 and items.pack.count(&"ingot") == 2 and items.piles.count_at(Vector2i(9, 9), &"ingot") == 2, "the pile 2 m over is scooped (within the arm's 3.2 m, D0409); the one 4 m over is not")
	machines.place(world, MachineDef.of(&"hopper"), Vector2i(6, 9))
	_check(verbs.configure(Vector2i(6, 9)).begins_with("hopper") and verbs.configure(Vector2i(14, 9)) == "" and verbs.configure(Vector2i(7, 9)) == "", "configure reaches the hopper; not out of reach, not an empty cell")


func _test_winch_link_is_two_presses() -> void:
	_rig()
	machines.place(world, MachineDef.of(&"winch_head"), Vector2i(6, 9))
	machines.place(world, MachineDef.of(&"winch_station"), Vector2i(7, 9))
	machines.place(world, MachineDef.of(&"winch_head"), Vector2i(8, 9))
	_check(verbs.link_winch(Vector2i(7, 9)) == &"" and verbs.link_winch(Vector2i(4, 9)) == &"", "a station with nothing armed, or an empty cell: nothing")
	_check(verbs.link_winch(Vector2i(6, 9)) == &"armed" and verbs.pending_winch_head == Vector2i(6, 9), "press one arms the head")
	_check(verbs.link_winch(Vector2i(7, 9)) == &"linked" and machines.winch_routes[Vector2i(6, 9)] == Vector2i(7, 9) and verbs.pending_winch_head == Verbs.NONE, "press two links it and clears the arm")
	_check(verbs.link_winch(Vector2i(6, 9)) == &"", "a linked head does not arm again")
	_check(verbs.link_winch(Vector2i(8, 9)) == &"armed" and verbs.link_winch(Vector2i(7, 9)) == &"failed" and verbs.pending_winch_head == Verbs.NONE, "a second head aimed at the taken station: failed, and the arm is spent")
	_check(verbs.link_winch(Vector2i(14, 9)) == &"", "out of reach")
