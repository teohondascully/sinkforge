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
	_test_the_slot_names_every_refusal()
	_test_the_slot_names_every_floor_drop()
	_test_the_slot_names_a_wrong_stack()
	_test_the_slot_stacks_over_a_lesson_and_yields_to_its_own()
	_test_the_dock_clears_a_full_hotbar_and_the_whole_legend()
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
	# D0488: the refusal slot stacks over the lesson plate; the stack of the tallest lesson and the slot
	# must clear the same disc.
	var slot: Rect2 = LessonDock.slot_rect(font, Refusals.headline(&"aim_machine"), tallest.position.y - UiTheme.px(LessonDock.SLOT_GAP))
	var stack: Rect2 = tallest.merge(slot)
	var worst_stack: float = 1.0e9
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var body: Vector2 = UiTheme.CANVAS * 0.5 + Vector2(lead.x * sx, lead.y * sy)
			var nearest := Vector2(clampf(body.x, stack.position.x, stack.end.x), clampf(body.y, stack.position.y, stack.end.y))
			worst_stack = minf(worst_stack, body.distance_to(nearest) - radius)
	_check(worst_stack > 0.0 and stack.position.y > UiTheme.px(60.0), "the slot over the tallest lesson (%d px together) stays %.0f px clear of the action area and below the objective band" % [int(stack.size.y), worst_stack])


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


## D0488 (strangers 61-75): a refused press says its headline on the dock from its first frame, for the
## linger after the release, and AGAIN on the next press: the slot is latched by nothing, where the lesson
## behind it fires once a game.
func _test_the_slot_names_every_refusal() -> void:
	var font: Font = ThemeDB.fallback_font
	var h: Hints = Hints.new()
	var f: Frame = _frame()
	var calm: Interface.Observation = f.obs
	var far: Frame = _frame()
	far.obs.aim_refusal = &"far"
	far.obs.aim_cell = Vector2i(far.obs.cell.x + 20, far.obs.cell.y)
	h.observe(far.obs, 0.016)
	var first: Dictionary = LessonDock.layout(h, far, font)
	_check(first.has("slot") and not first.has("rect") and String(first["slot"]["text"]) == "TOO FAR" and float(first["slot"]["alpha"]) > 0.99,
		"the first frame of a far press: the slot says TOO FAR at full alpha, no lesson yet (%s)" % str(first.get("slot", {}).get("text", "")))
	_check(((first["slot"]["rect"] as Rect2).end.y - UiTheme.px(Hotbar.HOTBAR_BAND_TOP - LessonDock.BAND_GAP)) < 0.01, "...seated at the dock's foot")
	f.obs = calm
	h.observe(calm, 0.016)                              # released after a 2-frame brush: the lesson never fired
	_check(h.active_id() == &"", "control: a two-frame brush fires no lesson")
	h.observe(calm, Refusals.SLOT_LINGER - Refusals.SLOT_FADE - 0.1)
	var held: Dictionary = LessonDock.layout(h, f, font)
	_check(held.has("slot") and float(held["slot"]["alpha"]) > 0.99, "a second after the release the word is still up in full (alpha %.2f)" % float(held.get("slot", {}).get("alpha", 0.0)))
	h.observe(calm, Refusals.SLOT_FADE * 0.6)
	var fading: Dictionary = LessonDock.layout(h, f, font)
	_check(fading.has("slot") and float(fading["slot"]["alpha"]) < 0.6 and float(fading["slot"]["alpha"]) > 0.1, "...fading through the last half second (alpha %.2f)" % float(fading.get("slot", {}).get("alpha", 0.0)))
	h.observe(calm, 1.0)
	_check(LessonDock.layout(h, f, font).is_empty(), "past the linger: no slot, no dock")
	var air: Frame = _frame()
	air.obs.aim_refusal = &"air"
	h.observe(air.obs, 0.016)
	var again: Dictionary = LessonDock.layout(h, air, font)
	_check(again.has("slot") and String(again["slot"]["text"]) == "NOTHING THERE", "the next refused press names itself again, its own word (%s)" % str(again.get("slot", {}).get("text", "")))
	var far2: Hints = Hints.new()
	far2.observe(far.obs, 0.016)
	far2.observe(calm, 2.0 * Refusals.SLOT_LINGER)
	far2.observe(far.obs, 0.016)
	_check(far2.slot_text() == "TOO FAR", "the SAME refusal a second time says it again: nothing latches (%s)" % far2.slot_text())
	var below: Frame = _frame()
	below.obs.aim_refusal = &"far"
	below.obs.aim_cell = below.obs.cell + Vector2i(0, Refusals.BELOW_CELLS)
	var hb: Hints = Hints.new()
	hb.observe(below.obs, 0.016)
	_check(hb.slot_text() == "TOO FAR DOWN", "a far press on a buried cell says TOO FAR DOWN (%s)" % hb.slot_text())
	var sight: Frame = _frame()
	sight.obs.aim_refusal = &"sight"
	var hs: Hints = Hints.new()
	hs.observe(sight.obs, 0.016)
	_check(hs.slot_text() == "BEHIND ROCK", "a sight refusal says BEHIND ROCK (%s)" % hs.slot_text())


## D0496 (strangers 76-81): the DROP's refusals ride the slot too, where D0488 read only `aim_refusal`.
## Stranger 76 pressed Q eleven times far from the forge: the first drop taught DROPPED, and the ten after
## it showed the pile at their feet and nothing else. The first floor drop is still the LESSON's (the slot
## yields to the plate whose first word it would repeat); every drop after it says DROPPED again, latched
## by nothing, for the same linger.
func _test_the_slot_names_every_floor_drop() -> void:
	var font: Font = ThemeDB.fallback_font
	var f: Frame = _frame()
	var h: Hints = Hints.new()
	var calm: Interface.Observation = _hint_obs()
	var fell: Interface.Observation = _hint_obs()
	fell.drop_went = &"floor"
	h.observe(calm, 0.016)
	h.observe(fell, 0.016)
	_check(h.active_id() == &"dropped_floor" and h.slot_text() == "", "the FIRST floor drop is its own lesson's: the plate says it and the slot yields (active %s, slot \"%s\")" % [h.active_id(), h.slot_text()])
	for _i: int in 3:
		h.observe(calm, 4.0)                                   # the lesson reads out and leaves the plate
	_check(h.active_id() == &"" and LessonDock.layout(h, f, font).is_empty(), "...and once it has read out, nothing is up (active %s)" % h.active_id())
	h.observe(fell, 0.016)
	var second: Dictionary = LessonDock.layout(h, f, font)
	_check(second.has("slot") and not second.has("rect") and String(second["slot"]["text"]) == "DROPPED" and float(second["slot"]["alpha"]) > 0.99,
		"the SECOND floor drop -- the lesson spent, no plate -- says DROPPED in the slot at once (\"%s\")" % str(second.get("slot", {}).get("text", "")))
	var srect: Rect2 = second.get("slot", {}).get("rect", Rect2())   # `.get` so a red above does not crash the run and shrink the count
	_check(absf(srect.end.y - UiTheme.px(Hotbar.HOTBAR_BAND_TOP - LessonDock.BAND_GAP)) < 0.01, "...seated at the dock's foot, no lesson under it (foot %.0f px)" % srect.end.y)
	h.observe(calm, Refusals.SLOT_LINGER - Refusals.SLOT_FADE - 0.1)
	_check(h.slot_text() == "DROPPED", "still up a second after the drop, inside the linger (\"%s\")" % h.slot_text())
	h.observe(calm, Refusals.SLOT_FADE + 0.5)
	_check(h.slot_text() == "" and LessonDock.layout(h, f, font).is_empty(), "%.1f s past the drop (linger %.1f s): no slot, no dock (\"%s\")" % [Refusals.SLOT_LINGER + 0.4, Refusals.SLOT_LINGER, h.slot_text()])
	h.observe(fell, 0.016)
	_check(h.slot_text() == "DROPPED", "a THIRD floor drop after the linger says it AGAIN: the slot latches nothing (\"%s\")" % h.slot_text())


## The wrong stack (D0443, D0496): the same fixture as `test_hints_moments._test_wrong_stack_pins` --
## clay dropped on the floor beside a forge that takes ore, ore still in the pack. Stranger 76's eleventh
## press was the one that finally fired the lesson; every press before and after it now says the words.
func _test_the_slot_names_a_wrong_stack() -> void:
	var forge: Dictionary = {"cell": Vector2i(11, 10), "id": &"processor", "recipe": &"smelt_ingot", "input": {}, "output": {}}
	var typed: Array[Dictionary] = [forge]
	var h: Hints = Hints.new()
	var held: Interface.Observation = _hint_obs([["clay", 3], ["ore", 4]])
	held.pos_x = 10 * 16 * S
	held.pos_y = 10 * 16 * S
	held.machines = typed
	var fell: Interface.Observation = _hint_obs([["ore", 4]])
	fell.pos_x = held.pos_x
	fell.pos_y = held.pos_y
	fell.machines = typed
	fell.drop_went = &"floor"
	h.observe(held, 0.016)
	h.observe(fell, 0.016)
	_check(h.active_id() == &"dropped_wrong" and h.slot_text() == "", "the first wrong stack is its own lesson's: the slot yields (active %s, slot \"%s\")" % [h.active_id(), h.slot_text()])
	for _i: int in 3:
		h.observe(held, 4.0)                                   # reads out, and the pack holds clay again
	h.observe(fell, 0.016)
	_check(h.slot_text() == "WRONG STACK" and h.active_id() == &"", "the next wrong stack says WRONG STACK in the slot, the lesson spent (\"%s\", active %s)" % [h.slot_text(), h.active_id()])


## The slot over a lesson: when another lesson holds the plate the slot sits a gap above it; when the
## refusal's OWN lesson holds the plate (its first words are the headline) the slot says nothing.
func _test_the_slot_stacks_over_a_lesson_and_yields_to_its_own() -> void:
	var font: Font = ThemeDB.fallback_font
	var h: Hints = Hints.new()
	var f: Frame = _frame()
	h.observe(f.obs, 0.016)
	f.obs.pack = [{"item": &"rope", "count": 1}]
	h.observe(f.obs, 0.016)
	h.observe(f.obs, 1.0)
	var far: Frame = _frame()
	far.obs.pack = f.obs.pack
	far.obs.aim_refusal = &"far"
	far.obs.aim_cell = Vector2i(far.obs.cell.x + 20, far.obs.cell.y)
	h.observe(far.obs, 0.016)
	var l: Dictionary = LessonDock.layout(h, far, font)
	_check(l.has("rect") and String(l["text"]).begins_with("ROPE") and l.has("slot"), "the rope lesson and the slot are both up")
	var plate: Rect2 = l["rect"]
	var slot: Rect2 = l["slot"]["rect"]
	_check(is_equal_approx(slot.end.y, plate.position.y - UiTheme.px(LessonDock.SLOT_GAP)) and is_equal_approx(slot.position.x, plate.position.x), "the slot sits a gap above the lesson plate, at its left")
	var own: Hints = Hints.new()
	for _i: int in Hints.FAR_TICKS:
		own.observe(far.obs, 0.016)
	own.observe(far.obs, 0.5)
	var o: Dictionary = LessonDock.layout(own, far, font)
	_check(own.active_id() == &"too_far" and o.has("rect") and not o.has("slot"), "TOO FAR's own lesson on the plate: the slot yields (active %s, slot %s)" % [own.active_id(), own.slot_text()])


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


## Astra's next test for the dock (D0416): readable beside the legend and a populated hotbar. The tallest
## lesson's plate against a ten-slot hotbar's backing and the legend's full first line: no overlap, and a
## gap between the dock's foot and the legend's cap.
func _test_the_dock_clears_a_full_hotbar_and_the_whole_legend() -> void:
	var font: Font = ThemeDB.fallback_font
	var tallest: Rect2 = LessonDock.dock_rect(font, TEXT)
	for text: String in _every_lesson():
		var r: Rect2 = LessonDock.dock_rect(font, text)
		if r.size.y > tallest.size.y:
			tallest = r
	var f: Frame = _frame()
	var typed: Array[Dictionary] = []
	for i: int in 10:
		typed.append({"item": &"ore", "count": 99})
	f.obs.pack = typed
	f.obs.pack_slots = 10
	f.obs.pack_bulk_cap = 400
	var bar: Dictionary = Hotbar.layout(f, font)
	var backing: Rect2 = bar["backing"]
	_check(backing.size.x > 0.0 and not tallest.intersects(backing), "the tallest lesson's plate does not touch a full ten-slot hotbar's backing (%s vs %s)" % [tallest, backing])
	var legend: KeyLegend = KeyLegend.new()
	var l: Dictionary = legend.layout(f, font)
	var parts: PackedStringArray = legend.remaining()
	var text: String = KeyLegend.SEPARATOR.join(parts)
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(KeyLegend.SIZE)).x
	var cap: float = float((l["at"] as Vector2).y) - font.get_ascent(UiTheme.pt(KeyLegend.SIZE))
	var legend_rect := Rect2(Vector2((l["at"] as Vector2).x, cap), Vector2(tw, font.get_height(UiTheme.pt(KeyLegend.SIZE))))
	_check(parts.size() >= 3 and not tallest.intersects(legend_rect) and tallest.end.y < legend_rect.position.y, "the plate sits %.0f px above the whole legend's line (%d parts, %.0f px wide)" % [legend_rect.position.y - tallest.end.y, parts.size(), tw])
	_check(not legend_rect.intersects(backing), "and the legend's line stays clear of the hotbar's backing")
