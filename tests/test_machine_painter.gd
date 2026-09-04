extends "res://tests/test_base.gd"

## `view/visuals/machine_painter.gd` + `machine_labels.gd` (A' step 6c, D0364), structural: the layout
## decisions a test can fail on -- what counts as working, what a stalled machine asks for, where the
## ports sit, when text and plates show, how runs of plates collapse and pack, how the construction
## flash starts and ends -- and a real redraw over machines placed through the door. It cannot say the
## machines LOOK like hardware; that is the director's eye at the play scene.

const S: int = Fx.SCALE
const CELL: float = float(Interface.Observation.LOGIC_PX)


func _initialize() -> void:
	_test_what_counts_as_working()
	_test_what_a_stalled_machine_asks_for()
	_test_the_ports()
	_test_the_aim_and_the_gates()
	_test_plates_collapse_runs_and_pack_shelves()
	_test_the_construction_flash()
	await _test_paint_runs_against_a_real_frame_with_a_factory()
	_finish("machine_painter")


func _rec(behavior: StringName, extra: Dictionary = {}) -> Dictionary:
	var r: Dictionary = {"cell": Vector2i(4, 9), "id": behavior, "behavior": behavior, "source": false, "name": "X",
		"recipe": &"", "status": &"idle", "power_permille": 0, "progress_permille": 0, "facing": 1, "fuel": 0,
		"filter": &"", "input": {}, "output": {}}
	for k: Variant in extra:
		r[k] = extra[k]
	return r


func _frame(zoom: float, body_px: Vector2, aim: Vector2i = Vector2i(-1, -1)) -> Frame:
	var f: Frame = Frame.new()
	f.obs = Interface.Observation.new()
	f.obs.pos_x = int(body_px.x) * S
	f.obs.pos_y = int(body_px.y) * S
	f.obs.aim_cell = aim
	f.zoom = zoom
	return f


func _test_what_counts_as_working() -> void:
	_check(not MachinePainter.active(_rec(&"generator")) and MachinePainter.active(_rec(&"generator", {"fuel": 3})),
		"a generator works only while it has fuel")
	_check(not MachinePainter.active(_rec(&"lift")) and MachinePainter.active(_rec(&"lift", {"power_permille": 600}))
		and MachinePainter.active(_rec(&"lift", {"input": {&"ore": 1}})), "a lift stirs while powered or holding goods")
	_check(not MachinePainter.active(_rec(&"iron_forge")) and MachinePainter.active(_rec(&"iron_forge", {"progress_permille": 200}))
		and MachinePainter.active(_rec(&"hopper", {"output": {&"ingot": 2}})), "anything else works while a cycle runs or it holds product")
	_check(MachinePainter.held(_rec(&"hopper", {"input": {&"ore": 2, &"coal": 1}, "output": {&"ingot": 4}})) == 7, "held sums both buffers")


func _test_what_a_stalled_machine_asks_for() -> void:
	_check(MachinePainter.need_item(_rec(&"drill", {"status": &"no_fuel"})) == &"coal", "out of fuel asks for coal")
	_check(MachinePainter.need_item(_rec(&"iron_forge", {"status": &"no_input", "recipe": &"smelt_iron"})) == &"iron",
		"starved, it asks for its recipe's first input")
	_check(MachinePainter.need_item(_rec(&"hopper", {"status": &"no_input"})) == &"ore", "with no recipe the bubble falls back on ore")
	_check(MachinePainter.ink(&"ore") == ItemLook.color(&"ore") and MachinePainter.ink(&"no_such") == MachinePainter.CHROME,
		"a mark wears its item's colour, or chrome, never white")


func _test_the_ports() -> void:
	var pos := Vector2(64.0, 144.0)
	var face := Rect2(pos + Vector2(0.0, CELL * MachineLook.CROWN), Vector2(CELL, CELL * (1.0 - MachineLook.CROWN)))
	var runner: Array[Dictionary] = MachinePainter.io_ports(_rec(&"iron_forge", {"recipe": &"smelt_iron"}), pos, face)
	_check(runner.size() == 2 and runner[0]["dir"] == Vector2(0, 1) and runner[0]["base"].y == face.position.y,
		"a recipe-runner's mouth sits on the face's top edge, pointing in")
	_check(runner[1]["dir"] == Vector2(0, 1) and runner[1]["base"].y == pos.y + CELL, "...and its spout on the cell line below")
	_check(runner[0]["color"] == ItemLook.color(&"iron") and runner[1]["color"] == ItemLook.color(&"iron_ingot"), "both tinted by their items")
	var lift: Array[Dictionary] = MachinePainter.io_ports(_rec(&"lift"), pos, face)
	_check(lift.size() == 1 and lift[0]["dir"] == Vector2(0, -1), "a lift has no mouth and spouts UP")
	var scale_body: float = MachinePainter.glyph_scale(face)
	var scale_torch: float = MachinePainter.glyph_scale(Rect2(pos, Vector2(CELL * 0.28, CELL * 0.72)))
	_check(is_equal_approx(scale_body, MachinePainter.CHROME_SCALE), "a full-width face takes the glyph at the cell's scale (%.2f)" % scale_body)
	_check(scale_torch < scale_body and scale_torch >= 0.6 * MachinePainter.CHROME_SCALE - 0.001, "a narrow face shrinks it, floored (%.2f)" % scale_torch)


func _test_the_aim_and_the_gates() -> void:
	var f: Frame = _frame(6.5, Vector2(72.0, 150.0), Vector2i(17, 38))
	_check(MachinePainter.aim_logic(f.obs) == Vector2i(4, 9), "the aimed terrain cell (17, 38) is logic cell (4, 9)")
	f.obs.aim_cell = Vector2i(-1, -1)
	_check(MachinePainter.aim_logic(f.obs) == Vector2i(-1, -1), "no aim stays no aim")
	f.obs.aim_cell = Vector2i(-3, 2)
	_check(MachinePainter.aim_logic(f.obs) == Vector2i(-1, 0), "a negative terrain cell floors")
	var near := Vector2i(4, 9)      # centre (72, 152): the body stands on it
	var far := Vector2i(30, 9)      # 26 cells away
	_check(MachinePainter.text_visible(f, far, Vector2i(-1, -1)), "at the play zoom text is readable everywhere")
	_check(MachinePainter.label_visible(f, near, Vector2i(-1, -1)) and not MachinePainter.label_visible(f, far, Vector2i(-1, -1)),
		"a plate shows near the body and not across the base")
	_check(MachinePainter.label_visible(f, far, far), "...unless that machine is the one aimed at")
	var out: Frame = _frame(0.5, Vector2(72.0, 150.0))
	_check(not MachinePainter.text_visible(out, near, Vector2i(-1, -1)) and not MachinePainter.label_visible(out, near, Vector2i(-1, -1)),
		"zoomed out past the text gate nothing reads, even up close")
	_check(MachinePainter.text_visible(out, near, near), "...except the aimed machine")


func _test_plates_collapse_runs_and_pack_shelves() -> void:
	var font: Font = ThemeDB.fallback_font
	var named: Dictionary = {Vector2i(2, 5): "HOPPER", Vector2i(3, 5): "HOPPER", Vector2i(4, 5): "HOPPER",
		Vector2i(6, 5): "DRILL", Vector2i(7, 5): "GENERATOR", Vector2i(2, 8): "LIFT"}
	var shown: Dictionary = {Vector2i(2, 5): true, Vector2i(3, 5): true, Vector2i(4, 5): true, Vector2i(6, 5): true, Vector2i(7, 5): true}
	var plan: Dictionary = MachineLabels.plan(named, shown, Vector2i(-1, -1), font, CELL)
	_check(plan.has(Vector2i(2, 5)) and String(plan[Vector2i(2, 5)]["text"]) == "HOPPER ×3", "three hoppers in a row are one plate with a count")
	_check(not plan.has(Vector2i(3, 5)) and not plan.has(Vector2i(4, 5)), "...owned by the westmost")
	_check(not plan.has(Vector2i(2, 8)), "a run with nothing visible in it wants no plate")
	_check(plan.has(Vector2i(6, 5)) and plan.has(Vector2i(7, 5)), "two different neighbours both get plates")
	_check(int(plan[Vector2i(6, 5)]["shelf"]) != int(plan[Vector2i(7, 5)]["shelf"]), "...on different shelves, because they would overlap")
	var aimed: Dictionary = MachineLabels.plan(named, shown, Vector2i(7, 5), font, CELL)
	_check(int(aimed[Vector2i(7, 5)]["shelf"]) == 0, "the aimed machine is packed first, onto the ground shelf")
	var part: Dictionary = MachineLabels.plan(named, {Vector2i(3, 5): true}, Vector2i(-1, -1), font, CELL)
	_check(part.has(Vector2i(3, 5)) and String(part[Vector2i(3, 5)]["text"]) == "HOPPER ×3",
		"the count is the factory's even when only one of the run is in view; the plate hangs over the visible part")


func _test_the_construction_flash() -> void:
	var p: MachinePainter = MachinePainter.new()
	var o: Interface.Observation = Interface.Observation.new()
	o.machines = [_rec(&"hopper", {"cell": Vector2i(1, 1)})]
	p.track_construction(o, 0.016)
	_check(p._construct.is_empty(), "the first frame primes without a flash: a loaded base does not assemble itself")
	o.machines = [_rec(&"hopper", {"cell": Vector2i(1, 1)}), _rec(&"drill", {"cell": Vector2i(5, 1)})]
	p.track_construction(o, 0.016)
	_check(p._construct.has(Vector2i(5, 1)) and not p._construct.has(Vector2i(1, 1)), "a machine that appears starts its flash")
	for _i: int in 30:
		p.track_construction(o, 0.016)
	_check(not p._construct.has(Vector2i(5, 1)), "...which ends after CONSTRUCT_DUR")
	o.machines = [_rec(&"hopper", {"cell": Vector2i(1, 1)})]
	p.track_construction(o, 0.016)
	o.machines = [_rec(&"hopper", {"cell": Vector2i(1, 1)}), _rec(&"drill", {"cell": Vector2i(5, 1)})]
	p.track_construction(o, 0.016)
	o.machines = [_rec(&"hopper", {"cell": Vector2i(1, 1)})]
	p.track_construction(o, 0.016)
	_check(not p._construct.has(Vector2i(5, 1)), "a machine picked up mid-flash takes its flash with it")


func _test_paint_runs_against_a_real_frame_with_a_factory() -> void:
	var items: Items = _hub_items(20, 20)
	var machines: Machines = _hub_machines(items)
	var world: World = items.world
	for col: int in range(20):
		for row: int in range(15, 20):
			world.set_solid(Vector2i(col, row), &"clay")
	for id: String in ["hopper", "drill", "generator", "lift", "iron_forge", "pump", "torch", "rope", "conduit", "winch_head"]:
		machines.place(world, MachineDef.of(StringName(id)), Vector2i(2 + (["hopper", "drill", "generator", "lift", "iron_forge", "pump", "torch", "rope", "conduit", "winch_head"].find(id)) * 1, 14))
	var gen: MachineState = machines.machine_at(Vector2i(4, 14))
	if gen != null:
		gen.fuel = 4
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(14 * 16 + 8) - Body.HEIGHT_PX / 2 * S)
	var door: Interface = Interface.new(world.grid, body, Mining.new(), world, items, machines)
	var o: Interface.Observation = door.observe(Interface.Envelope.new(Rect2i(0, 0, 80, 80)))
	_check(o.machines.size() == 10, "control: ten machines reach the observation (%d)" % o.machines.size())
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	var painter: MachinePainter = MachinePainter.new()
	var ran: Array = [0]
	view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		painter.paint_frame(f, ci)
		ran[0] = int(ran[0]) + 1)
	await process_frame
	view.refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0, "paint_frame() ran to completion inside a real draw pass over ten machines (%d)" % int(ran[0]))
	view.queue_free()
