extends "res://tests/test_base.gd"
## D0372. `view/hud/settings_page.gd` + `settings_draw.gd`: legacy's split kept, the pure half posed
## headless. The claims are legacy's own cursor and payload rules on this build's four actions: the
## same payload for a click and for ENTER, clamped rather than wrapped, the column jump only on the
## two-column face; the clash detection over every action; the page's wanted height from what draws
## it; the rise; and, after a real redraw, a click routed against the rectangles that were painted.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_settings_page.gd
const S: int = Fx.SCALE


func _initialize() -> void:
	_test_the_tables_and_the_labels()
	_test_the_payloads_clamp()
	_test_the_cursor_steps_and_jumps()
	_test_the_clashes()
	_test_the_geometry_and_the_rise()
	await _test_a_click_lands_on_what_was_painted()
	_finish("settings_page")


func _state() -> Dictionary:
	return {"muted": false, "levels": {"master": 1.0, "sound": 0.5, "ambience": 0.8, "music": 0.0},
		"shake": true, "auto_pickup": false, "zoom_label": "1.00x",
		"bindings": {Controls.LEFT: "A", Controls.RIGHT: "D", Controls.JUMP: "SPACE", Controls.MINE: "LMB"},
		"event_labels": {Controls.LEFT: ["A", "LEFT"], Controls.RIGHT: ["D", "RIGHT"], Controls.JUMP: ["SPACE"], Controls.MINE: ["LMB"]},
		"all_actions": [Controls.LEFT, Controls.RIGHT, Controls.JUMP, Controls.MINE]}


func _test_the_tables_and_the_labels() -> void:
	_check(SettingsPage.REMAP_ROWS.size() == 4 and SettingsPage.remap_per_col() == 2, "four bindings, two a column (%d, %d)" % [SettingsPage.REMAP_ROWS.size(), SettingsPage.remap_per_col()])
	_check(SettingsPage.action_label(Controls.MINE) == "mine (hold)" and SettingsPage.action_label(&"no_such") == "no_such", "an action's human name, or its id when it has none")
	_check(SettingsPage.focus_count(SettingsPage.CAT_CONTROLS) == 5 and SettingsPage.focus_count(SettingsPage.CAT_AUDIO) == 5 and SettingsPage.focus_count(SettingsPage.CAT_FEEL) == 3, "the bindings plus RESET, the mute plus four levels, three toggles")
	_check(SettingsPage.clamp_cat(-1) == 0 and SettingsPage.clamp_cat(9) == 2, "a category index that exists")
	_check(SettingsPage.RAIL_ORDER == [SettingsPage.CAT_AUDIO, SettingsPage.CAT_FEEL, SettingsPage.CAT_CONTROLS], "CONTROLS sits third on the rail as a door")


func _test_the_payloads_clamp() -> void:
	_check(SettingsPage.row_payload(SettingsPage.CAT_CONTROLS, 3) == {"bind": String(Controls.MINE)}, "the fourth binding row binds MINE")
	_check(SettingsPage.row_payload(SettingsPage.CAT_CONTROLS, 4) == {"reset": true} and SettingsPage.row_payload(SettingsPage.CAT_CONTROLS, 99) == {"reset": true}, "past the bindings is RESET, however far past")
	_check(SettingsPage.row_payload(SettingsPage.CAT_AUDIO, 0) == {"toggle": "mute"} and SettingsPage.row_payload(SettingsPage.CAT_AUDIO, 2) == {"slider": "sound"}, "audio: the mute, then the levels offset by one -- the table's second column is the shell's id, its first the label")
	_check(SettingsPage.row_payload(SettingsPage.CAT_AUDIO, 40) == {"slider": "music"}, "an audio row past the end clamps to the last level")
	_check(SettingsPage.row_payload(SettingsPage.CAT_FEEL, 1) == {"cycle": "zoom"} and SettingsPage.row_payload(SettingsPage.CAT_FEEL, 0) == {"toggle": "shake"}, "feel: zoom cycles, the rest toggle")


func _test_the_cursor_steps_and_jumps() -> void:
	_check(SettingsPage.next_row(SettingsPage.CAT_CONTROLS, 0, KEY_DOWN) == 1 and SettingsPage.next_row(SettingsPage.CAT_CONTROLS, 0, KEY_UP) == 0, "down steps, up at the top clamps")
	_check(SettingsPage.next_row(SettingsPage.CAT_CONTROLS, 0, KEY_RIGHT) == 2 and SettingsPage.next_row(SettingsPage.CAT_CONTROLS, 3, KEY_LEFT) == 1, "right and left jump a column on the two-column face")
	_check(SettingsPage.next_row(SettingsPage.CAT_CONTROLS, 4, KEY_DOWN) == 4, "down off RESET stays: clamped, never wrapped")
	_check(SettingsPage.next_row(SettingsPage.CAT_AUDIO, 2, KEY_RIGHT) == 2 and SettingsPage.next_row(SettingsPage.CAT_FEEL, 1, KEY_LEFT) == 1, "on the single-column faces the column jump is 0")
	_check(SettingsPage.row_action(SettingsPage.CAT_CONTROLS, 2) == Controls.JUMP and SettingsPage.row_action(SettingsPage.CAT_CONTROLS, 4) == &"" and SettingsPage.row_action(SettingsPage.CAT_AUDIO, 1) == &"", "the action under the cursor, none on RESET or off the face")
	var p: SettingsPage = SettingsPage.new()
	p.set_cat(SettingsPage.CAT_CONTROLS)
	p.row = 4
	p.set_cat(SettingsPage.CAT_FEEL)
	_check(p.cat == SettingsPage.CAT_FEEL and p.row == 2, "switching to a shorter face clamps the cursor rather than resetting it (%d)" % p.row)


func _test_the_clashes() -> void:
	_check(SettingsPage.clashes(_state()).is_empty(), "four distinct keys: no clash")
	var st: Dictionary = _state()
	st["event_labels"][Controls.JUMP] = ["A"]
	var c: Dictionary = SettingsPage.clashes(st)
	_check(c.has(Controls.JUMP) and c.has(Controls.LEFT) and String(c[Controls.JUMP][0]) == "A is also move left", "jump on A clashes with move left, said on both rows (%s)" % str(c))
	st["event_labels"][Controls.JUMP] = ["unbound"]
	st["event_labels"][Controls.MINE] = ["unbound"]
	_check(SettingsPage.clashes(st).is_empty(), "two unbound actions are not in conflict")
	st["event_labels"][&"sf_extra"] = ["D"]
	st["all_actions"].append(&"sf_extra")
	_check(String(SettingsPage.clashes(st).get(Controls.RIGHT, [""])[0]).begins_with("D is also"), "an off-page action's clash is still named on the row it collides with")


func _test_the_geometry_and_the_rise() -> void:
	var font: Font = ThemeDB.fallback_font
	_check(SettingsPage.wanted_h(SettingsPage.CAT_FEEL) == SettingsPage.SET_MIN_H and SettingsPage.wanted_h(SettingsPage.CAT_AUDIO) >= SettingsPage.SET_MIN_H, "the short faces sit at the floor")
	_check(SettingsPage.width_for(SettingsPage.CAT_CONTROLS) > SettingsPage.width_for(SettingsPage.CAT_AUDIO), "CONTROLS is the wide face")
	var p: SettingsPage = SettingsPage.new()
	_check(not p.visible() and p.ease() == 0.0, "closed and settled: invisible")
	p.open = true
	p.advance(0.05)
	_check(p.visible() and p.ease() > 0.0 and p.ease() < 1.0, "opening: visible and part way up (%.2f)" % p.ease())
	for _i: int in 30:
		p.advance(0.05)
	_check(is_equal_approx(p.ease(), 1.0), "a second on it is fully up")
	var g: Dictionary = p.geometry()
	_check((g["origin"] as Vector2).x > 0.0 and is_equal_approx(float(g["w"]), UiTheme.px(SettingsPage.SET_W_COMPACT)) and (g["content"] as Rect2).size.x > 0.0, "the plate is centred at the compact width with a content rect (%s)" % str(g["content"]))
	p.open = false
	for _i: int in 30:
		p.advance(0.05)
	_check(not p.visible(), "closed again: gone")
	var lines: Array = SettingsPage.wrap(font, "click a binding, then press its new key, and then some more words to wrap", 120.0, 10)
	_check(lines.size() >= 2, "a long sentence wraps at the plate's width (%d lines)" % lines.size())


func _test_a_click_lands_on_what_was_painted() -> void:
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
	var page: SettingsPage = SettingsPage.new()
	page.state = _state()
	page.open = true
	for _i: int in 40:
		page.advance(0.05)
	var ran: Array = [0]
	view.add_hud().add_chip(func(f: Frame, ci: CanvasItem) -> void:
		page.paint(f, ci)
		ran[0] = int(ran[0]) + 1)
	await process_frame
	view.refresh()
	view.add_hud().refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0 and page.hit_count() == 3 + 1 + 4, "the AUDIO face painted three rail tabs, the mute and four sliders as hits (%d runs, %d hits)" % [int(ran[0]), page.hit_count()])
	var g: Dictionary = page.geometry()
	var c: Rect2 = g["content"]
	var bar_x: float = c.position.x + UiTheme.px(SettingsPage.SET_CTRL_DX)
	var bar_y: float = c.position.y + UiTheme.px(14.0) + UiTheme.px(SettingsPage.SET_ROW) * 2.0 - UiTheme.px(4.0)
	var hit: Dictionary = page.click(Vector2(bar_x + UiTheme.px(SettingsPage.SET_BAR_W) * 0.5, bar_y))
	_check(hit.get("slider", "") == "sound" and absf(float(hit.get("frac", -1.0)) - 0.5) < 0.05, "a click on the middle of the second level is that slider at half (%s)" % str(hit))
	_check(page.click(Vector2(2.0, 2.0)).is_empty(), "a click on nothing is nothing")
	page.set_cat(SettingsPage.CAT_CONTROLS)
	view.refresh()
	view.add_hud().refresh()
	for _i: int in 2:
		await process_frame
	_check(page.hit_count() == 3 + 4 + 1, "the CONTROLS face painted the rail, four bindings and RESET (%d)" % page.hit_count())
	view.queue_free()
