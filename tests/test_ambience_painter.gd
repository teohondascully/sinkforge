extends "res://tests/test_base.gd"
## D0377. `view/visuals/ambience_painter.gd`: the placed plane's clockwork as functions a test can fail on.
## The claims are legacy's: a tube's level is its power over capacity; its stubs point at what it couples
## to and a lone tube keeps two nubs; power flows down and along downhill laterals with ties going right
## and NEVER up; beads grow with power and fade at both ends; a machine's guide ends at the next machine
## down or a short stub; the updraft climbs from the lift to the shaft's top; a pile shows at most four
## chips in a stable order; a sapling is a nub at age zero and brushes the cell above when grown; streaks
## appear only past 1.15x the run speed, five of them, longest through the middle; both canvases redraw on
## a real view.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_ambience_painter.gd
const S: int = Fx.SCALE
const CAP: int = 12000


func _initialize() -> void:
	_test_the_tube_and_its_couplings()
	_test_power_flows_down_and_never_up()
	_test_the_beads()
	_test_the_guide_and_the_pile()
	_test_the_sapling()
	_test_the_streaks()
	_test_the_updraft_on_a_real_shaft()
	await _test_both_canvases_run_on_a_real_view()
	_finish("ambience_painter")


func _obs(placed: Dictionary, power: Dictionary, machines: Array[Dictionary] = []) -> Interface.Observation:
	var o := Interface.Observation.new()
	o.placed = placed
	o.power = power
	o.machines = machines
	o.logic_window = Rect2i(0, 0, 20, 20)
	return o


func _test_the_tube_and_its_couplings() -> void:
	_check(int(MachinesRecords.RECORDS["conduit"]["capacity_milli"]) == CAP, "control: the tube's capacity is %d milli" % CAP)
	var o: Interface.Observation = _obs({Vector2i(5, 5): &"conduit"}, {Vector2i(5, 5): CAP})
	_check(is_equal_approx(AmbiencePainter.conduit_level(o, Vector2i(5, 5)), 1.0), "a full tube reads 1.0")
	o.power[Vector2i(5, 5)] = CAP / 2
	_check(is_equal_approx(AmbiencePainter.conduit_level(o, Vector2i(5, 5)), 0.5), "...half full 0.5")
	o.power[Vector2i(5, 5)] = CAP * 3
	_check(is_equal_approx(AmbiencePainter.conduit_level(o, Vector2i(5, 5)), 1.0), "...and never over 1.0")
	_check(AmbiencePainter.conduit_level(o, Vector2i(9, 9)) == 0.0, "a cell with no power reads 0")
	var lone: Array[Vector2] = AmbiencePainter.conduit_stubs(o, Vector2i(5, 5))
	var c: Vector2 = AmbiencePainter.logic_centre(Vector2i(5, 5))
	_check(lone.size() == 2 and lone[0].is_equal_approx(c + Vector2(0.0, 8.0)) and lone[1].is_equal_approx(c - Vector2(0.0, 8.0)), "a lone tube keeps a short nub up and down")
	var coupled: Interface.Observation = _obs({Vector2i(5, 5): &"conduit", Vector2i(6, 5): &"conduit"}, {}, [_machine_rec(&"generator", Vector2i(5, 6))])
	var stubs: Array[Vector2] = AmbiencePainter.conduit_stubs(coupled, Vector2i(5, 5))
	_check(stubs.size() == 2 and stubs.has(c + Vector2(0.0, 8.0)) and stubs.has(c + Vector2(8.0, 0.0)), "a tube with a machine below and a tube right stubs toward both, half a cell each")
	_check(AmbiencePainter.coupled(coupled, Vector2i(5, 6)) and not AmbiencePainter.coupled(coupled, Vector2i(4, 5)), "a machine couples, empty air does not")


func _test_power_flows_down_and_never_up() -> void:
	var o: Interface.Observation = _obs({Vector2i(5, 5): &"conduit", Vector2i(6, 5): &"conduit", Vector2i(4, 5): &"conduit", Vector2i(5, 4): &"conduit", Vector2i(5, 6): &"conduit"},
		{Vector2i(5, 5): CAP, Vector2i(6, 5): CAP / 2, Vector2i(4, 5): CAP, Vector2i(5, 4): 0, Vector2i(5, 6): CAP})
	var links: Array[Vector2i] = AmbiencePainter.flow_links(o, Vector2i(5, 5))
	_check(links.has(Vector2i(0, 1)), "a tube coupled below sends a bead down")
	_check(links.has(Vector2i(1, 0)), "...and along the lateral toward the lower tube on the right")
	_check(not links.has(Vector2i(-1, 0)), "...not toward an EQUAL tube on the left: ties go right")
	_check(not links.has(Vector2i(0, -1)), "...and never up, whatever the tube above carries")
	_check(links.size() == 2, "two links in all (%d)" % links.size())
	var tie: Interface.Observation = _obs({Vector2i(5, 5): &"conduit", Vector2i(6, 5): &"conduit"}, {Vector2i(5, 5): CAP, Vector2i(6, 5): CAP})
	_check(AmbiencePainter.flow_links(tie, Vector2i(5, 5)) == ([Vector2i(1, 0)] as Array[Vector2i]), "an equal tube on the right takes the tie")
	_check(AmbiencePainter.flow_links(tie, Vector2i(6, 5)).is_empty(), "...and does not send it back")


func _test_the_beads() -> void:
	_check(AmbiencePainter.bead_count(0.0) == 1 and AmbiencePainter.bead_count(0.5) == 2 and AmbiencePainter.bead_count(1.0) == 3, "one to three beads with power")
	var mid: float = AmbiencePainter.bead_alpha(1.0, 0.5)
	var end: float = AmbiencePainter.bead_alpha(1.0, 0.0)
	_check(mid > end and is_equal_approx(end, 0.82 * 0.35), "a bead fades at both ends of its run (%.3f mid, %.3f end)" % [mid, end])
	_check(AmbiencePainter.bead_alpha(0.0, 0.5) < AmbiencePainter.bead_alpha(1.0, 0.5), "...and is brighter with power")
	_check(AmbiencePainter.PULSE_GATE > 0.0 and AmbiencePainter.PULSE_GATE < 0.1, "a near-dead tube shows no flow (gate %.2f)" % AmbiencePainter.PULSE_GATE)


func _test_the_guide_and_the_pile() -> void:
	var o: Interface.Observation = _obs({}, {}, [_machine_rec(&"iron_forge", Vector2i(3, 3)), _machine_rec(&"hopper", Vector2i(3, 6))])
	_check(is_equal_approx(AmbiencePainter.guide_end_y(o, 3, 4, 64.0), 6.0 * 16.0), "a guide ends at the top of the next machine down its column")
	_check(is_equal_approx(AmbiencePainter.guide_end_y(o, 7, 4, 64.0), 64.0 + 16.0 * 0.9), "...or runs a 0.9-cell stub when nothing catches")
	var chips: Array[StringName] = AmbiencePainter.pile_chips({&"iron": 2, &"coal": 3})
	_check(chips.size() == 4, "a pile of five shows four chips (%d)" % chips.size())
	_check(chips == ([&"coal", &"coal", &"coal", &"iron"] as Array[StringName]), "...in name order, coal first (%s)" % str(chips))
	_check(AmbiencePainter.pile_chips({&"coal": 1}) == ([&"coal"] as Array[StringName]) and AmbiencePainter.pile_chips({}).is_empty(), "one chip for one, none for none")


func _test_the_sapling() -> void:
	var nub: Dictionary = AmbiencePainter.sapling_pose(Vector2i(4, 9), 0, 0.0)
	var grown: Dictionary = AmbiencePainter.sapling_pose(Vector2i(4, 9), AmbiencePainter.SAPLING_GROW_TICKS, 0.0)
	_check(is_equal_approx(float(nub["h"]), 3.0) and is_equal_approx(float(grown["h"]), 14.0), "a nub at 3 px, grown to 14 px (legacy's 6 and 28 at half)")
	_check((nub["foot"] as Vector2).y > (nub["tip"] as Vector2).y and is_equal_approx((nub["foot"] as Vector2).y, 10.0 * 16.0 - 0.5), "rooted at the cell's floor, growing up")
	_check(is_equal_approx(float(grown["g"]), 1.0) and is_equal_approx(float(AmbiencePainter.sapling_pose(Vector2i(4, 9), AmbiencePainter.SAPLING_GROW_TICKS * 3, 0.0)["g"]), 1.0), "growth saturates at the grow ticks")
	_check(AmbiencePainter.SAPLING_GROW_TICKS == 2400, "legacy's two minutes at 20 Hz (%d)" % AmbiencePainter.SAPLING_GROW_TICKS)


func _rest(vx_px_s: float, vy_px_s: float) -> Interface.Observation:
	var o := Interface.Observation.new()
	o.pos_x = 100 * S
	o.pos_y = 100 * S
	o.top_y = o.pos_y - 12 * S
	o.bottom_y = o.pos_y + 12 * S
	o.vel_x = int(round(vx_px_s * float(Fx.SCALE) / float(Interface.Observation.TICK_HZ)))
	o.vel_y = int(round(vy_px_s * float(Fx.SCALE) / float(Interface.Observation.TICK_HZ)))
	return o


func _test_the_streaks() -> void:
	var run: float = float(Interface.Observation.RUN_SPEED_PX_S)
	_check(AmbiencePainter.streaks(_rest(0.0, 0.0)).is_empty(), "at rest, no streak")
	_check(AmbiencePainter.streaks(_rest(run, 0.0)).is_empty(), "at the run speed, none: the floor is 1.15x")
	var fast: Array[Dictionary] = AmbiencePainter.streaks(_rest(run * 2.0, 0.0))
	_check(fast.size() == 5, "past it, five (%d)" % fast.size())
	var mid: float = (fast[2]["a"] as Vector2).distance_to(fast[2]["b"] as Vector2)
	var edge: float = (fast[0]["a"] as Vector2).distance_to(fast[0]["b"] as Vector2)
	_check(mid > edge, "longest through the middle (%.1f > %.1f)" % [mid, edge])
	_check((fast[2]["b"] as Vector2).x < (fast[2]["a"] as Vector2).x, "trailing behind the direction of travel")
	var terminal: Array[Dictionary] = AmbiencePainter.streaks(_rest(run * 2.8, 0.0))
	var tmid: float = (terminal[2]["a"] as Vector2).distance_to(terminal[2]["b"] as Vector2)
	_check(tmid > mid and float(terminal[2]["alpha"]) > float(fast[2]["alpha"]), "longer and brighter toward the swing's terminal")
	_check(AmbiencePainter.speed_px_s(_rest(run, 0.0)).is_equal_approx(Vector2(run, 0.0)), "the velocity round-trips through the door's fixed point")


func _test_the_updraft_on_a_real_shaft() -> void:
	var items: Items = _hub_items(20, 20)
	var machines: Machines = _hub_machines(items)
	var world: World = items.world
	for col: int in range(20):
		for row: int in range(15, 20):
			world.set_solid(Vector2i(col, row), &"clay")
	world.set_solid(Vector2i(5, 10), &"clay")   # a ceiling four metres above the lift's cell
	machines.place(world, MachineDef.of(&"lift"), Vector2i(5, 14))
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(14 * 16 + 8) - Body.HEIGHT_PX / 2 * S)
	var door: Interface = Interface.new(world.grid, body, Mining.new(), world, items, machines)
	var o: Interface.Observation = door.observe(Interface.Envelope.covering(Rect2(0.0, 0.0, 320.0, 320.0), WorldView.WINDOW_MARGIN_CELLS))
	var top: int = AmbiencePainter.shaft_top_row(o, Vector2i(5, 14))
	_check(top == 11 * 4, "the shaft's top is the first open terrain row under the ceiling (%d)" % top)
	var motes: Array[Dictionary] = AmbiencePainter.updraft_motes(o, Vector2i(5, 14), 1.3)
	_check(motes.size() == AmbiencePainter.UPDRAFT_MOTES, "six motes (%d)" % motes.size())
	var inside: bool = true
	for m: Dictionary in motes:
		var p: Vector2 = m["pos"]
		if p.y < 11.0 * 16.0 - 0.01 or p.y > 14.0 * 16.0 + 0.01 or float(m["alpha"]) <= 0.0 or float(m["alpha"]) > 0.7:
			inside = false
	_check(inside, "every mote rides between the lift and the shaft's top, fading as it climbs")
	world.set_solid(Vector2i(5, 13), &"clay")
	var sealed: Interface.Observation = door.observe(Interface.Envelope.covering(Rect2(0.0, 0.0, 320.0, 320.0), WorldView.WINDOW_MARGIN_CELLS))
	_check(AmbiencePainter.updraft_motes(sealed, Vector2i(5, 14), 1.3).is_empty(), "a lift with rock directly above has no shaft to shimmer in")


func _test_both_canvases_run_on_a_real_view() -> void:
	var items: Items = _hub_items(20, 20)
	var machines: Machines = _hub_machines(items)
	var world: World = items.world
	for col: int in range(20):
		for row: int in range(15, 20):
			world.set_solid(Vector2i(col, row), &"clay")
	machines.place(world, MachineDef.of(&"generator"), Vector2i(3, 14))
	machines.place(world, MachineDef.of(&"lift"), Vector2i(5, 14))
	machines.place(world, MachineDef.of(&"torch"), Vector2i(7, 14))
	machines.place(world, MachineDef.of(&"conduit"), Vector2i(4, 14))
	items.produced(&"coal", 2)
	items.drop_item(Vector2i(9, 14), &"coal", 2, Vector2i(9, 13))
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(14 * 16 + 8) - Body.HEIGHT_PX / 2 * S)
	var door: Interface = Interface.new(world.grid, body, Mining.new(), world, items, machines)
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	var ran: Array = [0, 0]
	view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		AmbiencePainter.paint_under(f, ci)
		ran[0] = int(ran[0]) + 1)
	view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		AmbiencePainter.paint(f, ci)
		ran[1] = int(ran[1]) + 1)
	await process_frame
	view.refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0 and int(ran[1]) > 0, "both canvases ran over a burner, a lift, a torch, a tube and a pile (%d, %d)" % [int(ran[0]), int(ran[1])])
	view.queue_free()
