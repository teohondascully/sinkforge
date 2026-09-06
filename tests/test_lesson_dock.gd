extends "res://tests/test_base.gd"
## D0413 (V70, the new-player review's rank 6). `view/hud/lesson_dock.gd`: the lesson text lives at ONE
## place on the screen and never on the body. The dock's rect depends on the text alone; it sits above
## the hotbar band at the legend's margin; it stays clear of the action area round a centred miner at the
## closest zoom under the largest camera lead a visible lesson can have; the world-to-canvas mapping the
## bubble used to own lives on the frame; no active lesson is no dock; a redraw runs through the host.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_lesson_dock.gd
const S: int = Fx.SCALE
const TEXT: String = "ROPE — set it above a drop. Climb it up and down; leap off."

## THE ACTION AREA, in world px round the body's centre: the mining reach (3.2 m, `Mining.REACH_NUM/DEN`,
## the same reach the collect verb and the grapple's near throws use) plus half the body, so the disc
## covers the miner too. And the body is not always at the canvas centre: the camera leads it by
## `LEAD_TIME` x velocity, and a lesson is visible up to `Hints.BUSY_ARM` x a run (above that the busy
## rule hides it), so the body can stand that far from centre with a lesson up.
const REACH_WORLD_PX: float = float(Mining.REACH_NUM) / float(Mining.REACH_DEN) * float(MaterialLook.CELLS_PER_METRE * Interface.Observation.CELL_PX)
const HALF_BODY_WORLD_PX: float = float(Body.HEIGHT_PX) * 0.5
const LEAD_WORLD_PX: float = float(Body.RUN_SPEED_PX_S) * Hints.BUSY_ARM * CameraRig.LEAD_TIME


func _initialize() -> void:
	_test_canvas_of()
	_test_the_dock_is_stable_and_clear_of_the_action_area()
	_test_the_layout_follows_the_lesson()
	await _test_paint_runs_through_the_hud_host()
	_finish("lesson_dock")


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


func _test_canvas_of() -> void:
	var f: Frame = _frame()
	_check(f.canvas_of(Vector2.ZERO).is_equal_approx(Vector2.ZERO), "the view rect's origin is the canvas origin")
	_check(f.canvas_of(Vector2(640.0, 360.0)).is_equal_approx(UiTheme.CANVAS), "its far corner is the canvas corner")
	_check(f.canvas_of(Vector2(320.0, 180.0)).is_equal_approx(UiTheme.CANVAS * 0.5), "the middle is the middle")
	f.view_world_rect = Rect2(100.0, 50.0, 320.0, 180.0)
	_check(f.canvas_of(Vector2(100.0, 50.0)).is_equal_approx(Vector2.ZERO) and f.canvas_of(Vector2(260.0, 140.0)).is_equal_approx(UiTheme.CANVAS * 0.5), "a zoomed, panned view maps the same way")
	_check(Frame.new().canvas_of(Vector2(10.0, 10.0)).x < 0.0, "a frame with no view yet maps off-canvas")


## Every lesson the game can show, filled with its verb names (the longest labels the tokens fall back
## to), laid out; the tallest dock is the one the action area is checked against.
func _every_lesson() -> Array[String]:
	var out: Array[String] = []
	for def: Dictionary in Hints.DEFS:
		out.append(BindingLabels.fill(String(def["text"])))
	for m: Dictionary in Hints.MOMENTS:
		out.append(BindingLabels.fill(String(m["text"])))
	return out


func _test_the_dock_is_stable_and_clear_of_the_action_area() -> void:
	var font: Font = ThemeDB.fallback_font
	var at_centre: Rect2 = LessonDock.dock_rect(font, TEXT)
	_check(is_equal_approx(at_centre.position.x, UiTheme.px(LessonDock.MARGIN_X)), "it stands at the legend's left margin")
	_check(is_equal_approx(at_centre.end.y, UiTheme.px(Hotbar.HOTBAR_BAND_TOP - LessonDock.BAND_GAP)), "its foot is a gap above the hotbar band (%.0f)" % at_centre.end.y)
	_check(at_centre.size.x <= UiTheme.px(LessonDock.WRAP + 16.0) + 0.01, "no wider than the wrap plus its padding")
	# The closest zoom: the canvas is the viewport (project 1280x720), so canvas px per world px == zoom.
	var zoom: float = CameraRig.ZOOM_LEVELS[0]
	for z: float in CameraRig.ZOOM_LEVELS:
		zoom = maxf(zoom, z)
	var radius: float = (REACH_WORLD_PX + HALF_BODY_WORLD_PX) * zoom
	var lead: Vector2 = Vector2(LEAD_WORLD_PX, LEAD_WORLD_PX * CameraRig.LEAD_VERTICAL) * zoom
	var tallest: Rect2 = at_centre
	var longest: String = TEXT
	for text: String in _every_lesson():
		var r: Rect2 = LessonDock.dock_rect(font, text)
		if r.size.y > tallest.size.y:
			tallest = r
			longest = text
	var worst: float = 1.0e9
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var body: Vector2 = UiTheme.CANVAS * 0.5 + Vector2(lead.x * sx, lead.y * sy)
			var nearest := Vector2(clampf(body.x, tallest.position.x, tallest.end.x), clampf(body.y, tallest.position.y, tallest.end.y))
			worst = minf(worst, body.distance_to(nearest) - radius)
	_check(worst > 0.0, "the tallest lesson (%d px, %d lines of \"%s...\") stays %.0f px clear of the action area at zoom %.2f under a %.0f px lead"
		% [int(tallest.size.y), int(tallest.size.y / UiTheme.pt(LessonDock.FS)), longest.substr(0, 14), worst, zoom, lead.x])
	_check(tallest.position.y > UiTheme.px(60.0), "and below the objective line's band")


func _test_the_layout_follows_the_lesson() -> void:
	var font: Font = ThemeDB.fallback_font
	var h: Hints = Hints.new()
	var f: Frame = _frame()
	_check(LessonDock.layout(h, f, font).is_empty(), "no lesson, no dock")
	h.observe(f.obs, 0.016)
	f.obs.pack = [{"item": &"rope", "count": 1}]
	h.observe(f.obs, 0.016)
	h.observe(f.obs, 0.05)
	var rising: Dictionary = LessonDock.layout(h, f, font)
	_check(not rising.is_empty() and float(rising["alpha"]) < 0.5 and (rising["rect"] as Rect2).position.y > LessonDock.dock_rect(font, rising["text"]).position.y, "arriving, the plate is below its seat and fading in (alpha %.2f)" % rising["alpha"])
	h.observe(f.obs, 1.0)
	var l: Dictionary = LessonDock.layout(h, f, font)
	_check(not l.is_empty() and String(l["text"]).begins_with("ROPE") and float(l["alpha"]) > 0.99, "the rope lesson is up a second after the rope arrives")
	_check((l["rect"] as Rect2) == LessonDock.dock_rect(font, l["text"]), "...seated: the rect is the dock's for that text")
	var moved: Frame = _frame(Vector2(100.0, 100.0))
	_check((LessonDock.layout(h, moved, font)["rect"] as Rect2) == (l["rect"] as Rect2), "the body elsewhere, the plate does not move")
	_check(LessonDock.layout(h, null, font).is_empty(), "no frame, no dock")


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
	var chip: LessonDock = LessonDock.new(plate)
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
