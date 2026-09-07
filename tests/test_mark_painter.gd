extends "res://tests/test_base.gd"
## D0376. `view/visuals/mark_painter.gd`, `mark_layout.gd` and `interface/aim_planes.gd`: the mark grammar
## as a list a test can fail on. The claims are legacy's: the square is where you point (chrome, faint out
## of reach, sized to what the pick takes); corners are what you would act on (a vein, a machine, in its
## own colour); a bar is a refusal, heavier than the square; a dash is a plan; the ghost stands only where
## a build is in hand over an open cell in reach, the drill shows its column and its drop, the rope its
## unroll; the drop lights the mouth it would feed; the hint names the nearest open cell only while you
## stand in your own way; the stars step aside for a ghost and nothing else; the door's answers agree with
## the verbs' own predicates.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_mark_painter.gd
const S: int = Fx.SCALE
const NONE: Vector2i = Vector2i(-1, -1)

var _items: Items
var _machines: Machines
var _world: World
var _door: Interface


func _initialize() -> void:
	_test_the_grammar_constants()
	_test_rock_wears_the_square_sized_to_the_blow()
	_test_a_held_button_past_the_reach_is_slashed_and_named()
	_test_the_cut_fills_the_square_from_the_floor_up()
	_test_a_held_drill_ghosts_and_previews()
	_test_standing_in_your_own_way_is_a_refusal_with_a_hint()
	_test_a_machine_under_the_aim_pulses_in_its_colour()
	_test_the_drop_lights_the_mouth_it_feeds()
	_test_the_rope_previews_its_unroll()
	_test_the_dig_plan_outlines_its_region()
	await _test_paint_runs_on_a_real_view()
	_finish("mark_painter")


## D0421, from the first stranger's run: MINE held on the right rock from a step too far, three times,
## and the frame did not change. The hold names its refusal (`far` / `sight` / `air`), the observation
## carries it, and the aim square goes to the refusal red at full weight with the bar struck across it --
## only while the button is held; a pointer merely resting past the reach keeps its faint chrome.
func _test_a_held_button_past_the_reach_is_slashed_and_named() -> void:
	_session()
	var resting: Interface.Observation = _aim(Vector2i(60, 101), false)   # 6.5 m off: past a 3.2 m reach
	_check(resting.aim_refusal == &"" and not resting.aim_in_reach, "a pointer resting past the reach refuses nothing (%s)" % resting.aim_refusal)
	var far: Interface.Observation = _aim(Vector2i(60, 101), true)
	_check(far.aim_refusal == &"far" and far.solid_at(far.aim_cell), "held on rock past the reach: the refusal is `far` (%s)" % far.aim_refusal)
	var marks: Array[Dictionary] = MarkLayout.build(far, 0.0, MaterialLook.new())
	var squares: Array[Dictionary] = _kinds(marks, &"square")
	var bars: Array[Dictionary] = _kinds(marks, &"bar")
	_check(squares.size() == 1 and Color(squares[0]["color"]).r == MarkPainter.REFUSE.r and Color(squares[0]["color"]).a > 0.9, "the square is the refusal red at full weight")
	_check(bars.size() == 1 and Color(bars[0]["color"]).r == MarkPainter.REFUSE.r, "...with the refusal bar struck across it: the same grammar as standing in your own way (%d bars)" % bars.size())
	var resting_marks: Array[Dictionary] = MarkLayout.build(resting, 0.0, MaterialLook.new())
	_check(_kinds(resting_marks, &"bar").is_empty(), "control: the resting pointer past the reach draws no bar")
	var air: Interface.Observation = _aim(Vector2i(34, 60), true)   # the sky over the body
	_check(air.aim_refusal == &"air" or air.aim_cell == Vector2i(-1, -1), "held on nothing: `air`, unless the hold snapped to a face (%s -> %s)" % [air.aim_refusal, air.aim_cell])
	var near: Interface.Observation = _aim(Vector2i(34, 101), true)
	_check(near.aim_refusal == &"", "held on rock in reach: no refusal, the blow lands (%s)" % near.aim_refusal)


## D0421 (stranger 2): wood takes sixteen blows and the stranger never saw one land. While the hold charges
## a cell, its banked share rises as a wash inside the aim square from the floor up; before the first blow
## banks, and once the pointer rests, there is none.
func _test_the_cut_fills_the_square_from_the_floor_up() -> void:
	_session()
	var idle: Interface.Observation = _aim(Vector2i(34, 101), false)
	_check(not idle.mining_is_charging, "control: a resting pointer charges nothing")
	var o: Interface.Observation = idle
	for _i: int in 40:   # hold on iron: blows bank as the swing lands
		o = _aim(Vector2i(34, 101), true)
		if o.mining_cracks.get(o.aim_cell, 0) > 0:
			break
	var share: int = int(o.mining_cracks.get(o.aim_cell, 0))
	_check(o.mining_is_charging and share > 0 and share < 1000, "control: the hold has banked part of the cell (%d permille)" % share)
	var marks: Array[Dictionary] = MarkLayout.build(o, 0.0, MaterialLook.new())
	var sq: Rect2 = (_kinds(marks, &"square")[0])["rect"]
	var gauge: Array[Dictionary] = []   # the dig plan the drag painted wears a wash of its own; the gauge is the one inside the square
	for w: Dictionary in _kinds(marks, &"wash"):
		if is_equal_approx((w["rect"] as Rect2).end.y, sq.end.y) and is_equal_approx((w["rect"] as Rect2).size.x, sq.size.x) and (w["rect"] as Rect2).size.y < sq.size.y:
			gauge.append(w)
	_check(gauge.size() == 1, "the charging cell wears one gauge wash inside its square (%d)" % gauge.size())
	if gauge.size() == 1:
		var w: Rect2 = gauge[0]["rect"]
		_check(is_equal_approx(w.size.y, sq.size.y * float(share) / 1000.0), "...as tall as the banked share (%.2f of %.2f px for %d permille)" % [w.size.y, sq.size.y, share])
	var idle_marks: Array[Dictionary] = MarkLayout.build(_aim(Vector2i(34, 101), false), 0.0, MaterialLook.new())
	var idle_gauge: int = 0
	for w: Dictionary in _kinds(idle_marks, &"wash"):
		if is_equal_approx((w["rect"] as Rect2).end.y, sq.end.y) and (w["rect"] as Rect2).size.y < sq.size.y:
			idle_gauge += 1
	_check(idle_gauge == 0, "released, the gauge is gone (the plan's own wash may stay)")


## A hub session: iron from logic row 25 down, the body standing on it at logic column 8.
func _session() -> void:
	_items = _hub_items(20, 40)
	_machines = _hub_machines(_items)
	_world = _items.world
	for col: int in range(20):
		for row: int in range(25, 40):
			_world.set_solid(Vector2i(col, row), &"ore_iron")
	var body: Body = Body.new(Fx.from_int(8 * 16 + 8), Fx.from_int(25 * 16) - Body.HEIGHT_PX / 2 * S)
	_door = Interface.new(_world.grid, body, Mining.new(), _world, _items, _machines)


func _aim(terrain_cell: Vector2i, mine_held: bool = false) -> Interface.Observation:
	var f: InputFrame = InputFrame.new()
	f.has_aim = true
	f.aim_col = terrain_cell.x
	f.aim_row = terrain_cell.y
	f.mine_held = mine_held
	_door.apply(Command.move(f))
	return _door.observe(Interface.Envelope.covering(Rect2(0.0, 300.0, 320.0, 340.0), WorldView.WINDOW_MARGIN_CELLS))


func _hold(item: StringName, n: int) -> void:
	_items.pack.add(item, n)
	var slots: Array[Dictionary] = _items.pack.slots()
	for i: int in slots.size():
		if slots[i]["item"] == item:
			_door.apply(Command.select(i))
			return


func _kinds(marks: Array[Dictionary], kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Dictionary in marks:
		if m["kind"] == kind:
			out.append(m)
	return out


func _test_the_grammar_constants() -> void:
	_check(is_equal_approx(MarkPainter.S, 0.5), "legacy's pixels come over at half (%.2f)" % MarkPainter.S)
	_check(MarkPainter.MARK_BAR_W > MarkPainter.MARK_W and is_equal_approx(MarkPainter.MARK_BAR_W, MarkPainter.MARK_W * 1.5), "the bar is heavier than the square, derived")
	_check(MarkPainter.MARK_FILL > MarkPainter.MARK_INSET, "a wash starts clear of the outline's stroke")
	_check(MarkPainter.MARK_W >= 1.0 and MarkPainter.THIN_W >= 1.0, "no stroke is under a pixel (%.2f, %.2f)" % [MarkPainter.MARK_W, MarkPainter.THIN_W])
	var r := Rect2(0.0, 0.0, 16.0, 16.0)
	_check(MarkPainter.mark_rect(r).encloses(MarkPainter.mark_wash(r)) and MarkPainter.mark_rect(r) != MarkPainter.mark_wash(r), "the wash sits inside the mark rect")
	_check(MarkPainter.CHROME == MachinePainter.CHROME and MarkPainter.CHROME != Color.WHITE, "one chrome, shared with the factory, and never white")


func _test_rock_wears_the_square_sized_to_the_blow() -> void:
	_session()
	var o: Interface.Observation = _aim(Vector2i(34, 101))
	# The hold snaps the aim to the nearest workable surface cell (`Aim.effective`), so the cell it lands on
	# is asserted to be rock in reach near the request, not the request itself.
	_check((o.aim_cell - Vector2i(34, 101)).length() <= 1.0 and o.aim_in_reach and o.solid_at(o.aim_cell), "the fixture aims rock in reach (%s, reach %s)" % [str(o.aim_cell), str(o.aim_in_reach)])
	var marks: Array[Dictionary] = MarkLayout.build(o, 0.0, MaterialLook.new())
	var squares: Array[Dictionary] = _kinds(marks, &"square")
	_check(squares.size() >= 1, "rock wears a square (%d)" % squares.size())
	var sq: Dictionary = squares[0]
	var want: Rect2 = MarkPainter.mark_rect(MarkPainter.blow_rect(o))
	_check(sq["rect"] == want and is_equal_approx(float(o.mining_blow_px), want.size.x + 2.0 * MarkPainter.MARK_INSET), "sized to what one blow takes: %d px (%s)" % [o.mining_blow_px, str(sq["rect"])])
	_check(Color(sq["color"]).r == MarkPainter.CHROME.r and is_equal_approx(Color(sq["color"]).a, 0.85), "chrome at 0.85 in reach")
	_check(not _kinds(marks, &"corners").is_empty(), "...and iron is a vein: corners in its own colour")
	var far: Interface.Observation = _aim(Vector2i(34, 140))
	var fsq: Array[Dictionary] = _kinds(MarkLayout.build(far, 0.0, MaterialLook.new()), &"square")
	_check(not far.aim_in_reach and fsq.size() == 1 and is_equal_approx(Color(fsq[0]["color"]).a, 0.18), "out of reach the square goes faint and the corners leave (%d marks)" % fsq.size())
	_check(MarkPainter.sky_marks(o).is_empty(), "the stars do not step aside for a cursor on rock")
	_check(MarkLayout.build(_aim(Vector2i(40, 90)), 0.0, MaterialLook.new()).is_empty(), "open air in reach with nothing in hand: no mark at all")


func _test_a_held_drill_ghosts_and_previews() -> void:
	_session()
	_hold(&"drill", 1)
	var o: Interface.Observation = _aim(Vector2i(40, 96))
	_check(o.held_item == &"drill" and o.aim_in_reach and not o.solid_at(o.aim_cell), "the fixture holds a drill over open air in reach")
	_check(o.aim_placeable, "the door says the press would land")
	var marks: Array[Dictionary] = MarkLayout.build(o, 0.0, MaterialLook.new())
	var glyphs: Array[Dictionary] = _kinds(marks, &"glyph")
	_check(glyphs.size() == 1 and String(glyphs[0]["glyph"]) == "drill", "the ghost wears the drill's glyph")
	var sq: Array[Dictionary] = _kinds(marks, &"square")
	_check(sq.size() == 1 and is_equal_approx(Color(sq[0]["color"]).a, 0.95) and sq[0]["rect"] == MarkPainter.mark_rect(MarkPainter.logic_rect(Vector2i(10, 24))), "a placeable ghost takes the chrome square on the METRE")
	_check(_kinds(marks, &"bar").is_empty(), "...and no bar")
	var dp: Dictionary = o.drill_preview
	_check(not dp.is_empty() and (dp["cells"] as Array).size() == 15 and bool(dp["blocked"]), "the drill previews the fifteen-metre ore column below and a blocked drop at the world's floor")
	_check(_kinds(marks, &"dash").size() == 1 and _kinds(marks, &"arrow").size() == 1 and Color(_kinds(marks, &"dash")[0]["color"]) == MarkPainter.WARN, "a dashed box, an out-arrow, red-amber because nothing drains")
	_check(MarkPainter.sky_marks(o).size() == 1, "the stars step aside for a ghost")
	_check(MarkPainter.target_rect(o) == MarkPainter.logic_rect(Vector2i(10, 24)), "with a build in hand the cursor answers about the metre")


func _test_standing_in_your_own_way_is_a_refusal_with_a_hint() -> void:
	_session()
	_hold(&"drill", 1)
	var o: Interface.Observation = _aim(Vector2i(34, 98))
	_check(MarkPainter.aim_logic(o) == Vector2i(8, 24) and not o.aim_placeable, "aiming the metre the body stands in refuses the press")
	var marks: Array[Dictionary] = MarkLayout.build(o, 0.0, MaterialLook.new())
	var bars: Array[Dictionary] = _kinds(marks, &"bar")
	_check(bars.size() == 1 and is_equal_approx(float(bars[0]["width"]), MarkPainter.MARK_BAR_W), "the refusal bar, heavier than the square")
	var reds: int = 0
	for s: Dictionary in _kinds(marks, &"square"):
		if Color(s["color"]).r == MarkPainter.REFUSE.r and not s.has("hint"):
			reds += 1
	_check(reds == 1, "the square goes red with it (%d)" % reds)
	_check(o.place_hint != NONE and o.place_hint != Vector2i(8, 24), "the door names a nearby open cell (%s)" % str(o.place_hint))
	var hints: int = 0
	for s: Dictionary in _kinds(marks, &"square"):
		if s.has("hint"):
			hints += 1
	_check(hints == 1, "...and the layout draws the hint once")
	_check(AimPlanes.logic_of(Vector2i(-1, -1)) == Vector2i(-1, -1) and AimPlanes.logic_of(Vector2i(7, 4)) == Vector2i(1, 1), "logic_of floors toward negative infinity")


func _test_a_machine_under_the_aim_pulses_in_its_colour() -> void:
	_session()
	_machines.place(_world, MachineDef.of(&"iron_forge"), Vector2i(10, 24))
	var o: Interface.Observation = _aim(Vector2i(41, 97))
	_check(not o.machine_at(Vector2i(10, 24)).is_empty() and o.aim_in_reach, "the fixture aims a forge in reach")
	var marks: Array[Dictionary] = MarkLayout.build(o, 0.0, MaterialLook.new())
	var corners: Array[Dictionary] = _kinds(marks, &"corners")
	var want: Color = MachineLook.color(&"iron_forge", &"iron_forge", true).lightened(0.25)
	_check(corners.size() == 1 and Color(corners[0]["color"]).r == want.r and Color(corners[0]["color"]).g == want.g, "corners in the forge's own colour")
	_check(_kinds(marks, &"glyph").is_empty() and _kinds(marks, &"bar").is_empty(), "no ghost and no refusal over your own machine")
	_check(MarkPainter.sky_marks(o).is_empty(), "no ghost, so the stars stay")


func _test_the_drop_lights_the_mouth_it_feeds() -> void:
	_session()
	_machines.place(_world, MachineDef.of(&"generator"), Vector2i(10, 24))
	_hold(&"coal", 3)
	var o: Interface.Observation = _aim(Vector2i(34, 101))
	_check(o.held_item == &"coal" and o.feed_target == Vector2i(10, 24), "the door names the burner the drop would feed (%s)" % str(o.feed_target))
	var lips: int = 0
	for w: Dictionary in _kinds(MarkLayout.build(o, 0.0, MaterialLook.new()), &"wash"):
		if w.has("lip"):
			lips += 1
	_check(lips == 1, "the mouth's lip is lit once")
	_hold(&"drill", 1)
	var d: Interface.Observation = _aim(Vector2i(34, 101))
	_check(d.feed_target == NONE, "holding something no machine eats lights nothing")


func _test_the_rope_previews_its_unroll() -> void:
	_session()
	_hold(&"rope", 3)
	var o: Interface.Observation = _aim(Vector2i(40, 96))
	_check(o.aim_placeable and o.rope_preview == 1, "a rope over one metre of air above rock hangs one segment (%d)" % o.rope_preview)
	var ropes: Array[Dictionary] = _kinds(MarkLayout.build(o, 0.0, MaterialLook.new()), &"rope")
	_check(ropes.size() == 1 and int(ropes[0]["hung"]) == 1, "...and the layout draws the unroll")
	_check(AimPlanes.rope_hang(_world, Vector2i(10, 20), 3) == 3 and AimPlanes.rope_hang(_world, Vector2i(10, 20), 2) == 2, "the hang is the open cells below, capped by what is carried")


func _test_the_dig_plan_outlines_its_region() -> void:
	_session()
	_aim(Vector2i(34, 102), true)
	var o: Interface.Observation = _aim(Vector2i(36, 102), true)
	_check(not o.dig_marks.is_empty(), "dragging the pick over rock paints a plan (%d cells)" % o.dig_marks.size())
	var marks: Array[Dictionary] = MarkLayout.build(o, 0.0, MaterialLook.new())
	var washes: int = 0
	var edges: int = 0
	for m: Dictionary in marks:
		if m["kind"] == &"wash" and Color(m["color"]).r == MarkPainter.DIG.r:
			washes += 1
		elif m["kind"] == &"line":
			edges += 1
	_check(washes == o.dig_marks.size(), "every marked cell wears the whisper of fill (%d)" % washes)
	_check(edges > 0 and edges < 4 * o.dig_marks.size(), "the region's boundary is stroked, not every cell's four sides (%d edges for %d cells)" % [edges, o.dig_marks.size()])


func _test_paint_runs_on_a_real_view() -> void:
	_session()
	_hold(&"drill", 1)
	_aim(Vector2i(40, 96))
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(_door, MaterialLook.new(), cam)
	var ran: Array = [0]
	view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		MarkPainter.paint(f, ci)
		ran[0] = int(ran[0]) + 1)
	await process_frame
	view.refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0, "paint() ran on a real view with a ghost, a preview and a square (%d)" % int(ran[0]))
	view.queue_free()
