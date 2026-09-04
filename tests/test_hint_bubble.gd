extends "res://tests/test_base.gd"
## D0370. `view/hud/hint_bubble.gd`: the placement rule and the mapping. The bubble sits above its
## anchor, flips below near the banner's band, lifts over what the lesson is about, stays on-canvas;
## the world maps onto the canvas through the frame's view rect; no active lesson is no bubble.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_hint_bubble.gd
const S: int = Fx.SCALE
const TEXT: String = "ROPE — set it above a drop. Climb it up and down; leap off."


func _initialize() -> void:
	_test_world_to_canvas()
	_test_the_placement_rule()
	_test_the_layout_follows_the_lesson()
	await _test_paint_runs_through_the_hud_host()
	_finish("hint_bubble")


func _frame(body_px: Vector2 = Vector2(320.0, 180.0)) -> Frame:
	var f: Frame = Frame.new()
	f.obs = Interface.Observation.new()
	f.obs.on_floor = true
	f.obs.pos_x = int(body_px.x) * S
	f.obs.pos_y = int(body_px.y) * S
	f.obs.top_y = int(body_px.y - 20.0) * S
	f.obs.cell = Vector2i(int(body_px.x) / 4, Interface.Observation.SKY_ROWS)
	f.view_world_rect = Rect2(0.0, 0.0, 640.0, 360.0)
	return f


func _test_world_to_canvas() -> void:
	var f: Frame = _frame()
	_check(HintBubble.world_to_canvas(f, Vector2.ZERO).is_equal_approx(Vector2.ZERO), "the view rect's origin is the canvas origin")
	_check(HintBubble.world_to_canvas(f, Vector2(640.0, 360.0)).is_equal_approx(UiTheme.CANVAS), "its far corner is the canvas corner")
	_check(HintBubble.world_to_canvas(f, Vector2(320.0, 180.0)).is_equal_approx(UiTheme.CANVAS * 0.5), "the middle is the middle")
	f.view_world_rect = Rect2(100.0, 50.0, 320.0, 180.0)
	_check(HintBubble.world_to_canvas(f, Vector2(100.0, 50.0)).is_equal_approx(Vector2.ZERO) and HintBubble.world_to_canvas(f, Vector2(260.0, 140.0)).is_equal_approx(UiTheme.CANVAS * 0.5), "a zoomed, panned view maps the same way")


func _test_the_placement_rule() -> void:
	var font: Font = ThemeDB.fallback_font
	var box: Vector2 = HintBubble.hint_box(font, TEXT)
	_check(box.x <= UiTheme.px(HintBubble.WRAP + 16.0) + 0.01 and box.y > 0.0, "the box is no wider than the wrap plus its padding (%s)" % str(box))
	var anchor := Vector2(640.0, 400.0)
	var r: Rect2 = HintBubble.hint_rect(font, TEXT, anchor, [] as Array[Vector2])
	var tail: Vector2 = HintBubble.hint_tail(anchor)
	_check(is_equal_approx(r.end.y, tail.y - UiTheme.px(7.0)), "the bubble sits above its anchor with a 7 px gap")
	_check(is_equal_approx(r.get_center().x, anchor.x), "centred on it")
	var high: Rect2 = HintBubble.hint_rect(font, TEXT, Vector2(640.0, 70.0), [] as Array[Vector2])
	_check(high.position.y > UiTheme.px(60.0), "near the top it flips below the anchor (%s)" % str(high))
	var pivot: Vector2 = r.get_center()
	var lifted: Rect2 = HintBubble.hint_rect(font, TEXT, anchor, [pivot] as Array[Vector2])
	_check(lifted.end.y <= pivot.y + 0.01 and lifted.position.y >= UiTheme.px(HintBubble.TOP_FLIP), "a pivot inside the box lifts the bubble until it clears it (%s)" % str(lifted))
	var edge: Rect2 = HintBubble.hint_rect(font, TEXT, Vector2(5.0, 400.0), [] as Array[Vector2])
	_check(edge.position.x >= UiTheme.px(6.0), "an anchor at the left edge keeps the bubble on-canvas")
	var low: Vector2 = HintBubble.hint_tail(Vector2(640.0, 700.0))
	_check(low.y <= UiTheme.px(Hotbar.HOTBAR_BAND_TOP - 6.0), "the tail never points into the hotbar band (%.0f)" % low.y)


func _test_the_layout_follows_the_lesson() -> void:
	var font: Font = ThemeDB.fallback_font
	var h: Hints = Hints.new()
	var f: Frame = _frame()
	_check(HintBubble.layout(h, f, font).is_empty(), "no lesson, no bubble")
	h.observe(f.obs, 0.016)
	f.obs.pack = [{"item": &"rope", "count": 1}]
	h.observe(f.obs, 0.016)
	h.observe(f.obs, 1.0)
	var l: Dictionary = HintBubble.layout(h, f, font)
	_check(not l.is_empty() and String(l["text"]).begins_with("ROPE") and float(l["alpha"]) > 0.99, "the rope lesson is up a second after the rope arrives")
	var anchor: Vector2 = l["anchor"]
	_check(anchor.is_equal_approx(HintBubble.world_to_canvas(f, Vector2(320.0, 160.0 - HintBubble.HEAD_CLEAR))), "anchored just over the body's head (%s)" % str(anchor))
	var tail: PackedVector2Array = l["tail"]
	_check(bool(l["above"]) and tail[2].y <= HintBubble.hint_tail(anchor).y + 0.01 and tail[2].y >= (l["rect"] as Rect2).end.y, "the tail's tip reaches down toward the head from the plate's base")
	_check(HintBubble.layout(h, null, font).is_empty(), "no frame, no bubble")


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
	var plate: ArrivalPlate = ArrivalPlate.new()
	var chip: HintBubble = HintBubble.new(plate)
	var ran: Array = [0]
	view.add_hud().add_chip(func(f: Frame, ci: CanvasItem) -> void:
		if f != null and f.obs != null and int(ran[0]) == 1:
			f.obs.pack.append({"item": &"torch", "count": 1})   # a torch arrives on the second frame
		chip.paint(f, ci)
		ran[0] = int(ran[0]) + 1)
	await process_frame
	view.refresh()
	view.add_hud().refresh()
	for _i: int in 4:
		await process_frame
		view.refresh()
		view.add_hud().refresh()
	_check(int(ran[0]) > 1, "paint() ran through the host over several frames (%d)" % int(ran[0]))
	_check(chip.hints.taught_ids().has("torch") or int(ran[0]) < 3, "the torch that arrived mid-run was taught (%s)" % str(chip.hints.taught_ids()))
	view.queue_free()
