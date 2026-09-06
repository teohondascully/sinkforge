extends "res://tests/test_base.gd"
## D0370, the reveal rule REVERSED by D0411. `view/hud/objective_line.gd`: the banner rules as data.
## EVERY rung keeps its plate and shows its how-to the moment it opens; the how-to fades over
## HINT_HOLD + HINT_FADE and returns once you have stalled past HINT_STUCK (legacy offered a later rung
## nothing until the stall, and the new-player review found the player standing under an empty sky); a
## just-finished rung is acknowledged before the next takes the plate; the goal carries its count; the
## banner clamps to the span the corner chips leave free; a finished ladder says so without a bullet and
## clears after its linger.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_objective_line.gd
const S: int = Fx.SCALE


func _initialize() -> void:
	_test_the_alphas()
	_test_the_layout()
	await _test_paint_runs_through_the_hud_host()
	_finish("objective_line")


func _test_the_alphas() -> void:
	var a: Dictionary = ObjectiveLine.alphas(0, 0.0, false)
	_check(float(a["goal"]) == 1.0 and float(a["hint"]) == 1.0, "the opening step at 0 s: plate and how-to both up")
	a = ObjectiveLine.alphas(0, ObjectiveLine.HINT_HOLD + ObjectiveLine.HINT_FADE * 0.5, false)
	_check(is_equal_approx(float(a["hint"]), 0.5) and float(a["goal"]) == 1.0, "half-way through the fade the how-to is half (%.2f)" % float(a["hint"]))
	a = ObjectiveLine.alphas(0, 20.0, false)
	_check(float(a["hint"]) == 0.0 and float(a["goal"]) == 1.0, "at 20 s the how-to is gone, the plate stays")
	a = ObjectiveLine.alphas(0, ObjectiveLine.HINT_STUCK + ObjectiveLine.GOAL_FADE, false)
	_check(is_equal_approx(float(a["hint"]), 1.0), "stalled past HINT_STUCK the how-to returns in full")
	a = ObjectiveLine.alphas(1, 5.0, false)
	_check(float(a["goal"]) == 1.0 and float(a["hint"]) == 1.0, "a later step at 5 s: plate AND how-to, the same rule as the first (D0411 reversed legacy's silence)")
	a = ObjectiveLine.alphas(1, 20.0, false)
	_check(float(a["goal"]) == 1.0 and float(a["hint"]) == 0.0, "at 20 s its how-to has faded and the plate stays")
	a = ObjectiveLine.alphas(1, ObjectiveLine.HINT_STUCK + ObjectiveLine.GOAL_FADE, false)
	_check(float(a["goal"]) == 1.0 and float(a["hint"]) == 1.0, "and the how-to is back once stalled")
	a = ObjectiveLine.alphas(3, 0.0, true)
	_check(float(a["goal"]) == 1.0 and float(a["hint"]) == 0.0, "done: the plate, no how-to")


func _test_the_layout() -> void:
	var font: Font = ThemeDB.fallback_font
	var obj: Objectives = Objectives.new()
	obj.refresh(Interface.Observation.new(), 0.0)
	var l: Dictionary = ObjectiveLine.layout(obj, font, UiTheme.px(96.0))
	_check(not l.is_empty() and String(l["text"]).begins_with("Mine 4 ore") and String(l["text"]).ends_with("0/4") and String(l["howto"]) != "", "a fresh ladder: the first goal, its count and its how-to (%s)" % str(l.get("text", "")))
	var rect: Rect2 = l["rect"]
	_check(is_equal_approx(rect.size.y, UiTheme.px(24.0 + 13.0)) and is_equal_approx(rect.position.y, UiTheme.px(ObjectiveLine.TOP)), "two lines tall at legacy's top (%s)" % str(rect))
	_check(is_equal_approx(rect.get_center().x, UiTheme.CANVAS.x * 0.5), "centred")
	var free_w: float = UiTheme.CANVAS.x - (UiTheme.px(96.0) + UiTheme.px(18.0)) * 2.0
	_check(rect.size.x <= free_w + 0.01, "no wider than the span the corner chips leave (%.0f <= %.0f)" % [rect.size.x, free_w])
	var tight: Dictionary = ObjectiveLine.layout(obj, font, 500.0)
	_check((tight["rect"] as Rect2).size.x <= UiTheme.CANVAS.x - (500.0 + UiTheme.px(18.0)) * 2.0 + 0.01 and String(tight["howto"]).ends_with("…"), "wide corner chips squeeze it and the how-to gives with an ellipsis")
	for _i: int in 40:
		obj.refresh(Interface.Observation.new(), 0.5)
	l = ObjectiveLine.layout(obj, font, 0.0)
	_check(String(l["howto"]) == "" and is_equal_approx((l["rect"] as Rect2).size.y, UiTheme.px(24.0)), "twenty seconds on the how-to is gone and the banner is one line")
	var later: Objectives = Objectives.new()
	later.refresh(Interface.Observation.new(), 0.0)
	var o: Interface.Observation = Interface.Observation.new()
	o.pack = [{"item": &"ore", "count": 4}]
	later.refresh(o, 0.016)
	var ack: Dictionary = ObjectiveLine.layout(later, font, 0.0)
	_check(String(ack["text"]).begins_with("✓") and String(ack["text"]).find("Mine 4 ore") >= 0, "rung 1 just latched: the plate acknowledges it first (%s)" % ack["text"])
	later.refresh(o, 5.0)
	var second: Dictionary = ObjectiveLine.layout(later, font, 0.0)
	_check(not second.is_empty() and String(second["text"]).begins_with("Forge 2 ingots") and String(second["howto"]) != "", "the second step at 5 s: its goal and its how-to, not an empty sky (%s)" % second.get("text", ""))
	_check(ObjectiveLine.layout(null, font, 0.0).is_empty(), "no ladder, no banner")


func _test_paint_runs_through_the_hud_host() -> void:
	var items: Items = _hub_items(20, 20)
	var machines: Machines = _hub_machines(items)
	var world: World = items.world
	for col: int in range(20):
		for row: int in range(15, 20):
			world.set_solid(Vector2i(col, row), &"clay")
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(14 * 16 + 8) - Body.HEIGHT_PX / 2 * S)
	var door: Interface = Interface.new(world.grid, body, Mining.new(), world, items, machines)
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	var chip: ObjectiveLine = ObjectiveLine.new()
	var ran: Array = [0]
	view.add_hud().add_chip(func(f: Frame, ci: CanvasItem) -> void:
		chip.paint(f, ci)
		ran[0] = int(ran[0]) + 1)
	await process_frame
	view.refresh()
	view.add_hud().refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0 and chip.objectives.current_index() == 0, "paint() ran through the host and stepped the ladder (%d)" % int(ran[0]))
	view.queue_free()
