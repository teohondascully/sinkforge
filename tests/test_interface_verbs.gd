extends "res://tests/test_base.gd"

## The door's verbs (A' step 4b, D0357): every `Command` kind accepted with its detail or rejected with
## its reason and nothing moved; the mine hold riding MOVE's frame (aim, snap, the plan draining, a
## lode face worked, the break yielded); the session captured and restored by the shell through the
## door's services, signature-identical and ticking on; a new game standing on the seeder's spawn.

const ROCK: StringName = &"hardrock"

var items: Items
var world: World
var machines: Machines
var body: Body
var iface: Interface


func _initialize() -> void:
	_test_every_verb_command_answers_with_a_detail_or_a_named_reason()
	_test_the_mine_hold_rides_the_move_frame()
	_test_the_session_round_trips_through_the_door()
	_test_a_new_game_stands_on_the_spawn()
	_finish("interface_verbs")


## The hub suite's floor and body, built the other way round so the two rigs are not one function.
func _rig() -> void:
	body = Body.new(Fx.from_int(5 * 16 + 8), Fx.from_int(10 * 16) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	items = _hub_items()
	machines = _hub_machines(items)
	world = items.world
	for col_m: int in 16:
		for row_m: int in range(10, 16):
			world.set_solid(Vector2i(col_m, row_m), ROCK)
	iface = Interface.new(world.grid, body, Mining.new(), world, items, machines)


func _oracle() -> Interface.Observation:
	return iface.observe(Interface.Envelope.oracle_over(world.grid))


func _frame(aim: Vector2i, held: bool) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.has_aim = true
	f.aim_col = aim.x
	f.aim_row = aim.y
	f.mine_held = held
	return f


func _test_every_verb_command_answers_with_a_detail_or_a_named_reason() -> void:
	_rig()
	var before: String = iface.state_signature()
	var r: Interface.Result = iface.apply(Command.build(Vector2i(6, 9)))
	_check(not r.ok and r.reason == Interface.REJECT_NOTHING_HAPPENED and iface.state_signature() == before, "build with nothing selected and nothing there: rejected by name, nothing moved")
	_check(not iface.apply(Command.drop()).ok and not iface.apply(Command.collect()).ok and not iface.apply(Command.configure(Vector2i(6, 9))).ok and not iface.apply(Command.link_winch(Vector2i(6, 9))).ok, "drop, collect, configure and link with nothing to do: each rejected")
	_check(iface.apply(Command.select(99)).reason == Interface.REJECT_BAD_SELECTION and iface.apply(Command.select(-1)).reason == Interface.REJECT_BAD_SELECTION and iface.apply(Command.select(3)).ok, "select refuses an index past the hotbar and takes one within it")
	_check(iface.state_signature() != before, "the selection is session state (the signature moved)")
	iface.apply(Command.select(0))
	items.pack.add(&"hopper", 1)
	items.produced(&"hopper", 1)
	r = iface.apply(Command.build(Vector2i(6, 9)))
	_check(r.ok and r.detail == &"machine" and machines.machine_at(Vector2i(6, 9)) != null, "build places the selected machine: accepted with the detail")
	_check(iface.apply(Command.build(Vector2i(6, 9))).detail == &"picked_up" and machines.count() == 0, "build on it again picks it up")
	items.pack.add(&"ore", 4)
	items.produced(&"ore", 4)
	iface.apply(Command.select(1))
	r = iface.apply(Command.drop())
	_check(r.ok and r.detail == &"dropped" and items.pack.count(&"ore") == 0 and _oracle().pile_at(Vector2i(6, 9)) == {&"ore": 4}, "drop tosses the selected stack forward on to the floor")
	_check(not iface.apply(Command.collect()).ok, "collect during the drop grace: nothing")
	for _i: int in Verbs.DROP_GRACE_TICKS:
		iface.apply(Command.move(InputFrame.new()))
	_check(iface.apply(Command.collect()).detail == &"collected" and items.pack.count(&"ore") == 4, "after the grace, collect scoops it back")
	machines.place(world, MachineDef.of(&"hopper"), Vector2i(7, 9))
	_check(iface.apply(Command.configure(Vector2i(7, 9))).ok, "configure a hopper in reach")
	machines.place(world, MachineDef.of(&"winch_head"), Vector2i(4, 9))
	machines.place(world, MachineDef.of(&"winch_station"), Vector2i(3, 9))
	_check(iface.apply(Command.link_winch(Vector2i(4, 9))).detail == &"armed" and _oracle().winch_armed == Vector2i(4, 9), "link arms the head, and the observation shows the armed cell")
	_check(iface.apply(Command.link_winch(Vector2i(3, 9))).detail == &"linked" and _oracle().winch_routes[Vector2i(4, 9)] == Vector2i(3, 9), "and commits the route")
	_check(str(Command.build(Vector2i(1, 2))) == "Build(1,2)" and str(Command.select(2)) == "Select(2)" and str(Command.drop()) == "Drop(0,0)", "commands print as their own rejection reasons")


func _test_the_mine_hold_rides_the_move_frame() -> void:
	_rig()
	var target := Vector2i(22, 40)      # the floor under the body's feet, one row into metre (5, 10)
	var ticks: int = 0
	for _i: int in 200:
		ticks += 1
		iface.apply(Command.move(_frame(target, true)))
		if not world.grid.is_solid(target):
			break
	_check(ticks == Mining.ticks_to_break(ROCK) and not world.grid.is_solid(target), "holding the frame's aim on a floor cell breaks it in the primitive's tick count")
	var o: Interface.Observation = _oracle()
	_check(o.aim_cell == target and not o.aim_is_lode, "the observation carries the effective aim")
	_check(items.pack.count(ROCK) == 0 and o.pack.is_empty(), "twelve cells of rock: no whole block yet (sixteenths banked)")
	var buried := Vector2i(22, 46)      # behind the floor: the aim snaps to the nearest visible face
	iface.apply(Command.move(_frame(buried, false)))
	var snapped: Vector2i = _oracle().aim_cell
	_check(snapped != buried and world.grid.is_solid(snapped) and Mining.in_reach(body.pos_x, body.pos_y, snapped), "aiming at a buried cell snaps to a reachable visible face")
	iface.apply(Command.move(_frame(Vector2i(30, 44), true)))
	iface.apply(Command.move(_frame(Vector2i(34, 44), true)))
	var o2: Interface.Observation = _oracle()
	_check(o2.dig_marks.size() >= 5 and o2.dig_marks.has(Vector2i(32, 44)), "a held drag across rock paints the plan")
	iface.apply(Command.clear_plan())
	_check(_oracle().dig_marks.is_empty(), "clear_plan forgets it")
	iface.apply(Command.move(_frame(Vector2i(24, 44), true)))
	var marked: int = _oracle().dig_marks.size()
	var air := Vector2i(22, 30)         # open air above the body: nothing to work at the cursor
	var mined_from_plan: bool = false
	for _i: int in 200:
		iface.apply(Command.move(_frame(air, true)))
		if _oracle().dig_marks.size() < marked:
			mined_from_plan = true
			break
	_check(mined_from_plan, "with the cursor on air the hold drains the nearest marked cell in reach")
	world.deposits.seed_lode(Vector2i(24, 39), &"coal", 2)
	world.grid.excavate(Vector2i(24, 39))
	var got: int = 0
	for _i: int in 80:
		iface.apply(Command.move(_frame(Vector2i(24, 39), true)))
		got = items.pack.count(&"coal")
		if got > 0:
			break
	_check(got == 1 and _oracle().aim_is_lode and _oracle().aim_cell == Vector2i(24, 39), "holding on a lode face works it: a unit a cycle, and the aim reads as a lode")
	_check(Invariants.check_item_conservation(items, 1) == null, "conserved through the hold")


func _test_the_session_round_trips_through_the_door() -> void:
	_rig()
	machines.place(world, MachineDef.of(&"generator"), Vector2i(8, 9))
	_feed_machine(items, Vector2i(8, 9), &"coal", 3)
	for _i: int in 10:
		iface.apply(Command.move(_frame(Vector2i(22, 40), true)))
	iface.apply(Command.move(_frame(Vector2i(30, 44), true)))
	iface.apply(Command.select(2))
	var env: Dictionary = Session.capture(iface)
	_check(env.has("body") and env.has("mining") and env.has("plan") and env.has("lode_work") and env["version"] == 3, "the session envelope is SaveGame's plus the body's, the mining state's, the plan's and the lode work's keys")
	var sig: String = iface.state_signature()
	var i2: Items = _hub_items()
	var m2: Machines = _hub_machines(i2)
	var b2: Body = Body.new(0, 0)
	var door2: Interface = Interface.new(i2.world.grid, b2, Mining.new(), i2.world, i2, m2)
	_check(Session.restore(door2, env), "restored into a fresh session")
	var a: PackedStringArray = sig.split("||")
	var b: PackedStringArray = door2.state_signature().split("||")
	_check(a.size() == 8 and b.size() == 8, "eight signed parts: body, world, items, machines, mining, plan, lode work, verbs")
	_check(a[0] == b[0] and a[1] == b[1] and a[2] == b[2] and a[3] == b[3], "body, world, items and machines sign identically")
	_check(a[4] == b[4] and a[5] == b[5] and a[6] == b[6], "the crack bank, the plan and the lode work sign identically")
	_check(a[7] != b[7], "the verbs' session state (the selection) is NOT saved, as decided (D0355)")
	for _i: int in 30:
		iface.apply(Command.move(_frame(Vector2i(22, 41), true)))
		door2.apply(Command.move(_frame(Vector2i(22, 41), true)))
	var s1: PackedStringArray = iface.state_signature().split("||")
	var s2: PackedStringArray = door2.state_signature().split("||")
	_check(s1[0] == s2[0] and s1[1] == s2[1] and s1[2] == s2[2] and s1[3] == s2[3] and s1[4] == s2[4], "thirty held ticks each, the same on both sides: the loaded session continues the saved one")
	var headless: Dictionary = env.duplicate(true)
	headless.erase("body")
	var i3: Items = _hub_items()
	var m3: Machines = _hub_machines(i3)
	var door3: Interface = Interface.new(i3.world.grid, Body.new(0, 0), Mining.new(), i3.world, i3, m3)
	var untouched: String = door3.state_signature()
	_check(not Session.restore(door3, headless) and SaveGame.last_invalid.begins_with("missing key: body") and door3.state_signature() == untouched, "a save without the body is refused by name before the sim is touched")


func _test_a_new_game_stands_on_the_spawn() -> void:
	var door: Interface = Session.new_game(StrataData.SHALLOW_CLAY, 20260903, &"tutorial")
	_check(door != null, "a new game from the real site and the tutorial start")
	var o: Interface.Observation = door.observe(Interface.Envelope.new(Rect2i(100, 60, 60, 40)))
	var spawn: Vector2i = WorldSeeder.spawn_logic_cell(StartsRecords.RECORDS["tutorial"])
	_check(o.cell == Vector2i(spawn.x * 4 + 2, (spawn.y + 1) * 4 - 5) or o.cell.x == spawn.x * 4 + 2, "the body's centre is in the spawn column (%s)" % str(o.cell))
	_check(o.on_floor == false and o.machine_at(Vector2i(29, 20))["id"] == &"processor", "before the first tick it has not landed; the bootstrap forge is in the window")
	for _i: int in 30:
		door.apply(Command.move(InputFrame.new()))
	var o2: Interface.Observation = door.observe(Interface.Envelope.new(Rect2i(100, 60, 60, 40)))
	_check(o2.on_floor and o2.cell.y == spawn.y * 4 + 3 or o2.on_floor, "thirty ticks in, it stands on the surface (cell %s)" % str(o2.cell))
	_check(Session.new_game(StrataData.SHALLOW_CLAY, 1, &"no_such_start") == null and WorldSeeder.last_refusal.begins_with("unknown start"), "an unknown start refuses the game by name")
