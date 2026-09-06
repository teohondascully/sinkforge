extends "res://tests/test_base.gd"
## D0368. `view/hud/hotbar.gd`: legacy's hotbar on the `layout()`/`paint()` split, so the claims are the
## rules legacy wrote down and then found violated: the bar shows only what you carry with a floor of one;
## the window CONTAINS the selection (a selection past the tenth well used to light nothing); the keybind
## digit stops when the keys do; a chevron marks the hidden end; the selected item is named; the hovered
## well captures a tooltip clamped on-canvas; PACK FULL shows only with no room; and a real redraw
## through the HUD host runs.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_hotbar.gd
const S: int = Fx.SCALE


func _initialize() -> void:
	_test_labels()
	_test_the_bar_is_the_pack_with_a_floor_of_one()
	_test_the_window_contains_the_selection()
	_test_keys_stop_where_the_keyboard_does()
	_test_the_tooltip_and_the_pointer()
	_test_pack_full_only_without_room()
	_test_geometry_is_legacys_under_the_scale()
	await _test_paint_runs_through_the_hud_host()
	_finish("hotbar")


func _frame(items: Array, sel: int = 0, cap: int = 10) -> Frame:
	var f: Frame = Frame.new()
	f.obs = Interface.Observation.new()
	var typed: Array[Dictionary] = []
	for i: int in items.size():
		typed.append({"item": StringName(items[i]), "count": i + 1})
	f.obs.pack = typed
	f.obs.pack_selected = sel
	f.obs.pack_slots = cap
	f.obs.pack_bulk_cap = 40
	f.obs.pack_bulk = 0
	return f


func _font() -> Font:
	return ThemeDB.fallback_font


func _test_labels() -> void:
	_check(Hotbar.item_label(&"drill") == "Drill", "a machine item is its record's display name (%s)" % Hotbar.item_label(&"drill"))
	_check(Hotbar.item_label(&"ore_iron") == "Ore iron", "a resource is its id, spaced and capitalised (%s)" % Hotbar.item_label(&"ore_iron"))
	_check(Hotbar.item_label(&"coal") == "Coal", "(%s)" % Hotbar.item_label(&"coal"))


func _test_the_bar_is_the_pack_with_a_floor_of_one() -> void:
	var empty: Dictionary = Hotbar.layout(_frame([]), _font())
	_check(empty.is_empty(), "an empty pack draws NO bar (D0412): a lit empty well read as missing content, and the bar is the carried items")
	var three: Dictionary = Hotbar.layout(_frame(["coal", "stone", "drill"], 1), _font())
	_check((three["wells"] as Array).size() == 3, "three items are three wells, no trailing empties (%d)" % (three["wells"] as Array).size())
	_check(bool(three["sel_lit"]) and (three["wells"] as Array)[1]["active"], "the selected well is lit")
	_check(String((three["label"] as Dictionary).get("text", "")) == "Stone", "and named above the bar (%s)" % str((three["label"] as Dictionary).get("text", "")))
	_check(not bool(three["more_left"]) and not bool(three["more_right"]), "nothing hidden, no chevrons")
	_check(Hotbar.layout(null, _font()).is_empty() and Hotbar.layout(Frame.new(), _font()).is_empty(), "no frame, no layout")


func _test_the_window_contains_the_selection() -> void:
	var items: Array = []
	for i: int in 12:
		items.append("item_%d" % i)
	var far: Dictionary = Hotbar.layout(_frame(items, 11), _font())
	_check((far["wells"] as Array).size() == 10, "twelve items are capped at ten wells")
	_check(int(far["window"]) == 2 and bool(far["sel_lit"]), "selection 11 of 12 slides the window to 2..11 and lights (window %d)" % int(far["window"]))
	_check(bool(far["more_left"]) and not bool(far["more_right"]), "the chevron marks the hidden LEFT end only")
	var home: Dictionary = Hotbar.layout(_frame(items, 0), _font())
	_check(int(home["window"]) == 0 and bool(home["more_right"]) and not bool(home["more_left"]), "selection 0 shows 0..9 and marks the right")
	_check(Hotbar.window_start(12, 10, 6) == 1, "a mid selection centres the window (%d)" % Hotbar.window_start(12, 10, 6))
	_check(Hotbar.window_start(3, 3, 2) == 0, "a pack inside the cap never scrolls")


func _test_keys_stop_where_the_keyboard_does() -> void:
	var items: Array = []
	for i: int in 12:
		items.append("item_%d" % i)
	var l: Dictionary = Hotbar.layout(_frame(items, 11), _font())
	var wells: Array = l["wells"]
	_check(String(wells[0]["key"]) == "3" and int(wells[0]["index"]) == 2, "the digit follows the pack index, not the well (%s)" % str(wells[0]["key"]))
	_check(String(wells[7]["key"]) == "0", "the tenth key is 0")
	_check(String(wells[8]["key"]) == "" and String(wells[9]["key"]) == "", "the eleventh and twelfth have no key and say so by staying blank")


func _test_the_tooltip_and_the_pointer() -> void:
	var f: Frame = _frame(["coal", "stone", "drill"], 0)
	var none: Dictionary = Hotbar.layout(f, _font())
	_check((none["tooltip"] as Dictionary).is_empty(), "no pointer, no tooltip")
	var well: Rect2 = (none["wells"] as Array)[2]["rect"]
	var over: Dictionary = Hotbar.layout(f, _font(), well.get_center())
	var tip: Dictionary = over["tooltip"]
	_check(not tip.is_empty() and String(tip["name"]).begins_with("Drill") and String(tip["name"]).ends_with("×3"), "the pointer over the third well captures its item and count (%s)" % str(tip.get("name", "")))
	var rect: Rect2 = tip["rect"]
	_check(rect.end.y <= well.position.y, "the tooltip sits above the well it describes")
	_check(rect.position.x >= 0.0 and rect.end.x <= UiTheme.CANVAS.x, "and inside the canvas")
	_check(String(tip["purpose"]) == ItemLook.purpose(&"drill"), "with the item's purpose line")
	var edge: Dictionary = Hotbar.tooltip_layout(_font(), {"item": &"coal", "count": 1, "anchor": Vector2(2.0, 700.0)})
	_check((edge["rect"] as Rect2).position.x >= UiTheme.px(6.0), "an anchor at the left edge clamps the tooltip on-canvas")


func _test_pack_full_only_without_room() -> void:
	var f: Frame = _frame(["coal"])
	_check(Hotbar.pack_full_layout(f, _font()).is_empty(), "room in the pack: no chip")
	f.obs.pack_bulk = 40
	var l: Dictionary = Hotbar.pack_full_layout(f, _font())
	_check(not l.is_empty() and String(l["label"]) == "PACK FULL", "no room: the chip")
	var chip: Rect2 = l["chip"]
	_check(chip.end.x <= UiTheme.CANVAS.x - UiTheme.px(10.0) + 0.01 and is_equal_approx(chip.position.y, UiTheme.px(Hotbar.CHIP_TOP)), "top-right, in the ambient corner register (%s)" % str(chip))
	f.obs.pack_bulk_cap = 0
	_check(Hotbar.pack_full_layout(f, _font()).is_empty(), "a zero cap is not a full pack")


func _test_geometry_is_legacys_under_the_scale() -> void:
	var l: Dictionary = Hotbar.layout(_frame(["coal", "stone"], 0), _font())
	var backing: Rect2 = l["backing"]
	_check(is_equal_approx(backing.position.y, UiTheme.px(Hotbar.HOTBAR_BAND_TOP)) and is_equal_approx(backing.size.y, UiTheme.px(Hotbar.HOTBAR_BAND_H)), "the backing is the band, scaled (%s)" % str(backing))
	_check(is_equal_approx(backing.get_center().x, UiTheme.CANVAS.x * 0.5), "centred on the canvas (%.1f)" % backing.get_center().x)
	var w0: Rect2 = (l["wells"] as Array)[0]["rect"]
	var w1: Rect2 = (l["wells"] as Array)[1]["rect"]
	_check(is_equal_approx(w1.position.x - w0.position.x, UiTheme.px(Hotbar.SLOT + Hotbar.SLOT_GAP)) and is_equal_approx(w0.size.x, UiTheme.px(Hotbar.SLOT)), "wells are SLOT wide, SLOT_GAP apart, scaled")
	_check(is_equal_approx(Hotbar.bottom_furniture_fraction(), 295.0 / 360.0), "the last row that is still world is 295/360 (%.3f)" % Hotbar.bottom_furniture_fraction())


func _test_paint_runs_through_the_hud_host() -> void:
	var items: Items = _hub_items(20, 20)
	var machines: Machines = _hub_machines(items)
	var world: World = items.world
	for col: int in range(20):
		for row: int in range(15, 20):
			world.set_solid(Vector2i(col, row), &"clay")
	items.pack.add(&"coal", 3)
	items.pack.add(&"drill", 1)
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(14 * 16 + 8) - Body.HEIGHT_PX / 2 * S)
	var door: Interface = Interface.new(world.grid, body, Mining.new(), world, items, machines)
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	var ran: Array = [0, 0]
	view.add_hud().add_chip(func(f: Frame, ci: CanvasItem) -> void:
		Hotbar.paint(f, ci)
		if f != null and f.obs != null and f.obs.pack.size() == 2:
			ran[1] = 1
		ran[0] = int(ran[0]) + 1)
	view.add_hud().add_chip(Hotbar.paint_pack_full)
	await process_frame
	view.refresh()
	view.add_hud().refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0, "paint() ran inside the HUD host's draw pass (%d)" % int(ran[0]))
	_check(int(ran[1]) == 1, "and the frame it drew carried the two carried items")
	view.queue_free()
