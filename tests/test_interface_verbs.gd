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
	_test_a_build_that_places_nothing_says_why()
	_test_the_mine_hold_rides_the_move_frame()
	_test_the_session_round_trips_through_the_door()
	_test_a_new_game_stands_on_the_spawn()
	_test_the_world_ends_in_a_wall()
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
	var went: Interface.Observation = _oracle()
	_check(r.ok and r.detail == &"dropped" and items.pack.count(&"ore") == 0 and went.pile_at(Vector2i(6, 9)) == {&"ore": 4}, "drop tosses the selected stack forward on to the floor")
	_check(went.drop_went == &"floor", "the observation says the drop went to the floor (D0428: %s)" % went.drop_went)
	_check(_oracle().drop_went == &"", "and only for one observe")
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
	_short_drop_pins()


## D0434: a drop that falls short of a machine in sight names that machine for DROP_SHORT_TICKS, so the mark
## can flash it in the refusal's grammar; a drop with no eater around names nothing.
func _short_drop_pins() -> void:
	_rig()
	items.pack.add(&"ore", 3)
	items.produced(&"ore", 3)
	iface.apply(Command.select(0))
	iface.apply(Command.drop())
	_check(_oracle().drop_short_cell == Vector2i(-1, -1), "a floor drop with no machine in sight names no machine")
	items.pack.add(&"ore", 3)
	items.produced(&"ore", 3)
	world.set_solid(Vector2i(11, 9), &"")
	machines.place(world, MachineDef.of(&"processor"), Vector2i(11, 9))   # six metres right: in sight, out of the 3.2 m reach
	iface.apply(Command.select(0))
	var r: Interface.Result = iface.apply(Command.drop())
	var o: Interface.Observation = _oracle()
	_check(r.ok and o.drop_went == &"floor" and o.drop_short_cell == Vector2i(11, 9), "the stack fell to the floor and the forge six metres off is named as what it fell short of (%s)" % o.drop_short_cell)
	for _i: int in Interface.DROP_SHORT_TICKS - 2:
		iface.apply(Command.move(InputFrame.new()))
	_check(_oracle().drop_short_cell == Vector2i(11, 9), "the name holds through the flash")
	for _i: int in 4:
		iface.apply(Command.move(InputFrame.new()))
	_check(_oracle().drop_short_cell == Vector2i(-1, -1), "and is gone after DROP_SHORT_TICKS")


## D0470 (strangers 49, 50, 51): RMB past the reach, or on the body's own cell with a machine in hand,
## placed nothing and said nothing. The refusal rides the observation's refusal channel, one observe wide.
func _test_a_build_that_places_nothing_says_why() -> void:
	_rig()
	items.pack.add(&"hopper", 1)
	items.produced(&"hopper", 1)
	iface.apply(Command.select(0))
	var r: Interface.Result = iface.apply(Command.build(Vector2i(12, 9)))
	var o: Interface.Observation = _oracle()
	_check(not r.ok and o.aim_refusal == &"build_far", "a BUILD seven metres off places nothing and the observation says build_far (%s)" % o.aim_refusal)
	_check(_oracle().aim_refusal == &"", "...for one observe only (%s)" % _oracle().aim_refusal)
	r = iface.apply(Command.build(Vector2i(5, 8)))
	o = _oracle()
	_check(not r.ok and o.aim_refusal == &"build_here" and machines.count() == 0, "a BUILD on the body's own cell places nothing and says build_here (%s)" % o.aim_refusal)
	r = iface.apply(Command.build(Vector2i(6, 9)))
	o = _oracle()
	_check(r.ok and o.aim_refusal == &"" and machines.count() == 1, "control: a placement beside the body carries no refusal (%s)" % o.aim_refusal)


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


## T036 taken provisionally (D0457): a body run at the world's east edge stops against it like rock and
## never leaves the grid, so the "left the world" report stays what D0055 meant it for. Control: the
## base `Surroundings` a body suite runs on still lets the box past the edge, where the clamp catches it.
func _test_the_world_ends_in_a_wall() -> void:
	var door: Interface = Session.new_game(StrataData.SHALLOW_CLAY, 20260903, &"tutorial")
	if door == null:
		_check(false, "the tutorial starts")
		return
	var b: Body = door.services()["body"]
	var w: World = door.services()["world"]
	var grid_max_x: int = w.grid.width * Body.CELL_PX * Fx.SCALE
	var violations: int = 0
	for _i: int in 900:                                           # fifteen seconds of running right
		var f: InputFrame = InputFrame.new()
		f.move_dir = 1
		door.apply(Command.move(f))
		if b.bounds_violation_this_tick:
			violations += 1
	var right_edge: int = b.pos_x + (Body.WIDTH_PX * Fx.SCALE) / 2
	_check(violations == 0 and right_edge <= grid_max_x and right_edge >= grid_max_x - 2 * Body.CELL_PX * Fx.SCALE,
		"fifteen seconds of running east: the body stands against the edge (right edge %d of %d) with no bounds report (%d)" % [right_edge, grid_max_x, violations])
	var bare: Body = Body.new(grid_max_x - 8 * Body.CELL_PX * Fx.SCALE, b.pos_y)
	var open: TileGrid = TileGrid.new(w.grid.width, w.grid.height, 1)
	var floor_row: int = Body._px_to_cell(bare.pos_y + (Body.HEIGHT_PX * Fx.SCALE) / 2)
	for x: int in range(w.grid.width - 40, w.grid.width):
		open.set_material(Vector2i(x, floor_row), ROCK)             # a floor to the edge, so only the edge is in question
	var bare_violations: int = 0
	for _i: int in 120:
		var f: InputFrame = InputFrame.new()
		f.move_dir = 1
		bare.tick(f, open)
		if bare.bounds_violation_this_tick:
			bare_violations += 1
	var bare_right: int = bare.pos_x + (Body.WIDTH_PX * Fx.SCALE) / 2
	_check(bare_violations > 0 and bare_right >= grid_max_x - Body.CELL_PX * Fx.SCALE, "control: on the base surroundings the same run on a floored edge is reported past the grid (%d ticks in violation, right edge %d)" % [bare_violations, bare_right])
