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
	_test_the_smelt_card_points_at_the_ring()
	_test_the_cards_lead_with_the_walk()
	_test_the_acknowledged_card_names_the_next()
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
	_check(String(ack["text"]).begins_with("✓  Mine 4 ore") and String(ack["text"]).find("next: Forge 2 ingots") > 0, "rung 1 just latched: the plate acknowledges it AND names the next goal (D0530) (%s)" % ack["text"])
	later.refresh(o, 5.0)
	var second: Dictionary = ObjectiveLine.layout(later, font, 0.0)
	_check(not second.is_empty() and String(second["text"]).begins_with("Forge 2 ingots") and String(second["howto"]) != "", "the second step at 5 s: its goal and its how-to, not an empty sky (%s)" % second.get("text", ""))
	_check(ObjectiveLine.layout(null, font, 0.0).is_empty(), "no ladder, no banner")
	_wrap_pins(later, font)


## D0424 (stranger 3): the smelt rung's how-to was elided at "the ingo…" beside a real depth chip, and the
## clause cut was the one that says the ingots come to you. It wraps to a second line now; the banner grows
## by one how-to line; only past two lines does the tail give.
func _wrap_pins(later: Objectives, font: Font) -> void:
	var corner: float = UiTheme.px(88.0)   # the depth chip's width with a band name on it, about what the seat shows
	var l: Dictionary = ObjectiveLine.layout(later, font, corner)
	var lines: PackedStringArray = String(l["howto"]).split("\n")
	_check(lines.size() == 2 and String(l["howto"]).find("ingots come to you") >= 0, "the smelt how-to wraps to two lines and keeps its last clause (%d lines: %s)" % [lines.size(), l["howto"]])
	_check(is_equal_approx((l["rect"] as Rect2).size.y, UiTheme.px(24.0 + 13.0 + ObjectiveLine.HOWTO_LINE_H)), "the banner is one how-to line taller (%.1f)" % (l["rect"] as Rect2).size.y)
	var free_w: float = UiTheme.CANVAS.x - (corner + UiTheme.px(18.0)) * 2.0
	for line: String in lines:
		_check(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(ObjectiveLine.HOWTO_SIZE)).x <= free_w - UiTheme.px(ObjectiveLine.PAD) * 2.0 + 0.01, "each line fits the span (%s)" % line)
	# EVERY rung's how-to, tokens filled, wraps whole at the LIVE span (D0443 reworded the smelt line; a
	# future rewording that runs to a third line loses its last clause to the ellipsis, silently). The live
	# corner is the wider of the depth chip and the corner map (D0430), which this pin measured at the
	# chip's 88 px until stranger 32 read "press RMB over the shaft m…" (D0457): the map's frame is wider.
	var live_corner: float = maxf(corner, Minimap.frame_rect(Vector2i(256, 1120), false).size.x)
	_check(live_corner > corner + 20.0, "control: the corner map is the wider corner chip (%.0f px over the depth chip's %.0f)" % [live_corner, corner])
	var live_w: float = UiTheme.CANVAS.x - (live_corner + UiTheme.px(18.0)) * 2.0 - UiTheme.px(ObjectiveLine.PAD) * 2.0
	for def: Dictionary in Objectives.STEPS:
		var filled: String = BindingLabels.fill(String(def["label"]))
		var wl: PackedStringArray = ObjectiveLine.wrap_howto(font, filled, UiTheme.pt(ObjectiveLine.HOWTO_SIZE), live_w)
		_check(wl.size() <= ObjectiveLine.HOWTO_LINES and not wl[wl.size() - 1].ends_with("…"), "%s: the how-to fits in %d line(s) whole at the live span (%s)" % [def["id"], wl.size(), filled.left(40)])
	var w: PackedStringArray = ObjectiveLine.wrap_howto(font, "one two three four five six seven eight nine ten eleven twelve", UiTheme.pt(9), 60.0)
	_check(w.size() == ObjectiveLine.HOWTO_LINES and w[w.size() - 1].ends_with("…") and w[0] != "", "past two lines the tail gives with an ellipsis (%s)" % str(w))
	_check(ObjectiveLine.wrap_howto(font, "", UiTheme.pt(9), 400.0).is_empty(), "an empty how-to is no lines")
	var one: PackedStringArray = ObjectiveLine.wrap_howto(font, "short", UiTheme.pt(9), 400.0)
	_check(one.size() == 1 and one[0] == "short", "a how-to that fits is one line, untouched")


## D0495 (strangers 76-81): the smelt rung said "the black seam right of you", a bearing true only where
## the game starts you -- S79 stood ON the seam with the WHITE RING under its own feet and strode further
## right; 78 and 81 pressed shadows. The card names the RING and the order it moves in (D0486: the coal
## seam until the pack holds coal, the forge after), and keeps D0493's number key and its last clause.
func _test_the_smelt_card_points_at_the_ring() -> void:
	var smelt: String = ""
	for def: Dictionary in Objectives.STEPS:
		if def["id"] == &"smelt":
			smelt = String(def["label"])
	_check(smelt.find("WHITE RING") >= 0, "the smelt card names the WHITE RING, the instrument every stranger has followed since D0447 (%s)" % smelt)
	_check(smelt.find("coal seam first") >= 0 and smelt.find("forge after") >= 0, "and the ORDER the ring moves in: the coal seam first, the forge after (D0486) (%s)" % smelt)
	_check(smelt.find("NUMBER and [DROP]") >= 0 and smelt.ends_with("ingots come to you."), "D0493's number key and the last clause survive the rewording (%s)" % smelt)
	_check(smelt.length() <= 141, "no longer than the card that already wrapped to two lines (%d <= 141 chars)" % smelt.length())
	var bearings: PackedStringArray = PackedStringArray()
	var holds: PackedStringArray = PackedStringArray()
	for def: Dictionary in Objectives.STEPS:
		var lab: String = String(def["label"])
		if lab.find("right of you") >= 0 or lab.find("left of you") >= 0 or (lab.find("beside you") >= 0 and def["id"] != &"mine"):
			bearings.append(String(def["id"]))                              # D0507: "beside you" is a bearing too (S97 pressed at the shaft, 6 m from the ring); the FIRST rung alone is played from the spawn, where it is true (6 of 6 in three batches)
		if lab.find("hold them") >= 0 or lab.find("hold each") >= 0:
			holds.append(String(def["id"]))                                 # D0507: "hold" never taught the number key (S94, S97); NUMBER does
	_check(bearings.is_empty(), "no rung's label carries a bearing from the spawn, 'beside you' included (%d such rungs: %s)" % [bearings.size(), str(bearings)])
	_check(holds.is_empty(), "no rung's label says 'hold' a stack where it means the NUMBER key (%d such rungs: %s)" % [holds.size(), str(holds)])
	var deliver: String = ""
	for def: Dictionary in Objectives.STEPS:
		if def["id"] == &"deliver":
			deliver = String(def["label"])
	_check(deliver.find("WHITE RING") >= 0 and deliver.find("NUMBER and [DROP]") >= 0 and deliver.length() <= 141, "the deliver card names the ring and the number key within the two-line length (%d chars: %s)" % [deliver.length(), deliver])


## D0515 (strangers 103-108): the smelt card opened on the ring's route and ended "press NUMBER then
## [DROP]"; six of six pressed NUMBER then Q where they stood (the spawn, cells 147, 166, 184, 202; the
## forge at 116-119), and the deliver card sent S104 past the rig to the world's edge. A card that names a
## place leads with WALK, then STAND beside the machine, THEN the keys -- in that order, so the key
## sequence cannot be read before the walk it needs. The winch card names a place too and takes the shape.
func _test_the_cards_lead_with_the_walk() -> void:
	var labels: Dictionary = {}
	for def: Dictionary in Objectives.STEPS:
		labels[def["id"]] = String(def["label"])
	for id: StringName in [&"smelt", &"deliver"]:
		var lab: String = labels[id]
		var at: Array[int] = [lab.find("STAND"), lab.find("NUMBER"), lab.find("[DROP]")]
		_check(lab.begins_with("WALK"), "%s: the card's first word is WALK, not the ring or the keys (%s)" % [id, lab.left(24)])
		_check(at[0] > 0 and at[1] > at[0] and at[2] > at[1], "%s: STAND, NUMBER, [DROP] in that order after WALK (at %d, %d, %d)" % [id, at[0], at[1], at[2]])
	var winch: String = labels[&"winch"]
	_check(winch.begins_with("WALK") and winch.find("STAND") > 0 and winch.find("Then") > winch.find("STAND") and winch.find("6 ingots") >= 0, "the winch card names a place, so it is WALK, STAND, Then as well, and keeps its 6 ingots (WALK at %d, STAND at %d, Then at %d)" % [winch.find("WALK"), winch.find("STAND"), winch.find("Then")])
	_check(labels[&"smelt"].find("STAND beside the forge") >= 0, "the smelt card says WHICH machine to stand beside: the forge, not the ring that may be on the seam (%s)" % labels[&"smelt"])


## D0530 (strangers 113 and 124): "✓ Forge 2 ingots" alone on the plate for the ACK_HOLD beat read as the end
## of the game -- "No new objectives appeared. Per instructions, I quit" -- while the state was already on the
## deliver rung. The tick card carries the next rung's goal after "next:", in the goal's ink (the `tail`
## paint draws in GOAL_INK); the last rung latched shows the all-done text; and every rung's acknowledged
## line fits whole at the live span (D0502's shape: count the cut, report the widest against the budget).
func _test_the_acknowledged_card_names_the_next() -> void:
	var font: Font = ThemeDB.fallback_font
	var mid: Objectives = Objectives.new()
	mid.restore_done(["mine", "smelt"])
	mid.refresh(Interface.Observation.new(), 0.0)
	var l: Dictionary = ObjectiveLine.layout(mid, font, 0.0)
	var text: String = String(l["text"])
	_check(text.begins_with("✓  Forge 2 ingots") and text.find(ObjectiveLine.NEXT_SEP + "Deliver 2 ingots") > 0, "the smelt rung just latched: its tick, then next: the deliver goal (%s)" % text)
	_check(String(l["tail"]) == ObjectiveLine.NEXT_SEP + "Deliver 2 ingots" and text == "✓  Forge 2 ingots" + String(l["tail"]), "the tail paint draws in GOAL_INK is the separator and the next goal, and the line is the tick's part plus it (tail \"%s\")" % l["tail"])
	_check((l["ink"] as Color) == ObjectiveLine.DONE_INK, "the tick and the finished goal keep DONE_INK")
	var plain: Dictionary = ObjectiveLine.layout(Objectives.new(), font, 0.0)
	_check(plain.is_empty() or String(plain.get("tail", "x")) == "", "control: a goal line that is not an acknowledgement has no tail")
	var last: Objectives = Objectives.new()
	var ids: Array = []
	for def: Dictionary in Objectives.STEPS:
		ids.append(String(def["id"]))
	last.restore_done(ids)
	last.refresh(Interface.Observation.new(), 0.0)
	var done: Dictionary = ObjectiveLine.layout(last, font, 0.0)
	_check(String(done["text"]).begins_with("✓  All set") and String(done["text"]).find("next:") < 0 and String(done["tail"]) == "", "the last rung latched: the all-done text, no next (%s)" % done["text"])
	# The fit pin: every rung's acknowledged line, whole, at the live span the how-to pin measures.
	var live_corner: float = maxf(UiTheme.px(88.0), Minimap.frame_rect(Vector2i(256, 1120), false).size.x)
	var budget: float = UiTheme.CANVAS.x - (live_corner + UiTheme.px(18.0)) * 2.0 - UiTheme.px(ObjectiveLine.PAD) * 2.0 - UiTheme.px(14.0)
	var cut: int = 0
	var widest: float = 0.0
	var lines: int = 0
	for i: int in range(1, Objectives.STEPS.size()):
		var obj: Objectives = Objectives.new()
		obj.restore_done(ids.slice(0, i))
		obj.refresh(Interface.Observation.new(), 0.0)
		var line: String = String(ObjectiveLine.layout(obj, font, live_corner)["text"])
		var whole: String = "✓  " + String(Objectives.STEPS[i - 1]["goal"]) + ObjectiveLine.NEXT_SEP + String(Objectives.STEPS[i]["goal"])
		widest = maxf(widest, font.get_string_size(whole, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(ObjectiveLine.GOAL_SIZE)).x)
		lines += 1
		cut += 1 if line != whole else 0
	_check(lines == Objectives.STEPS.size() - 1 and cut == 0, "every rung's acknowledged line fits the card whole at the live span: %d of %d cut, widest %.0f of %.0f px" % [cut, lines, widest, budget])
	_check(ObjectiveLine.first_clause("Raise the winch, then rest") == "Raise the winch" and ObjectiveLine.first_clause("Fuel: the Drill") == "Fuel" and ObjectiveLine.first_clause("Build the line") == "Build the line", "the first clause stops at a comma or a colon and is the whole goal without one")
	# Squeezed to the width of "...next: Forge 2 in": the line gives from its END, so the finished goal and
	# "next:" both survive and the next goal is what is cut.
	var room: float = font.get_string_size("✓  Mine 4 ore" + ObjectiveLine.NEXT_SEP + "Forge 2 in", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(ObjectiveLine.GOAL_SIZE)).x
	var squeezed: Dictionary = ObjectiveLine.acknowledged(1, font, room)
	var st: String = squeezed["text"]
	_check(st.begins_with("✓  Mine 4 ore" + ObjectiveLine.NEXT_SEP + "F") and st.ends_with("…") and st.length() < ("✓  Mine 4 ore" + ObjectiveLine.NEXT_SEP + "Forge 2 ingots").length(), "squeezed to %.0f px the line gives from the end and keeps next: (%s)" % [room, st])
	_check(String(squeezed["tail"]).begins_with(ObjectiveLine.NEXT_SEP) and st == "✓  Mine 4 ore" + String(squeezed["tail"]), "and the GOAL_INK tail is still the separator onward (%s)" % squeezed["tail"])


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
