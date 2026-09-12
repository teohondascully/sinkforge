extends "res://tests/test_base.gd"
## D0372 + D0632. `view/hud/settings_page.gd` is the pure model, posed headless; `settings_control.gd`
## is the face, a real Control tree witnessed in a real tree. The claims: the cursor and payload rules
## on this build's actions (same payload for a click and for ENTER, clamped rather than wrapped, the
## column jump only on the two-column face); the clash detection over every action; the wanted height;
## the rise. On the tree: every face's controls exist and take no gui focus, a slider emits its frac,
## a chip its payload, the ring mirrors `page.row` -- on CONTROLS, by MODEL row, not insertion order --
## the armed door says so, the skin swaps whole, and a closed page takes its tree with it.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_settings_page.gd
const S: int = Fx.SCALE


func _initialize() -> void:
	_test_the_tables_and_the_labels()
	_test_the_payloads_clamp()
	_test_the_cursor_steps_and_jumps()
	_test_the_clashes()
	_test_the_geometry_and_the_rise()
	await _test_the_control_tree_is_the_page()
	_finish("settings_page")


func _state() -> Dictionary:
	return {"muted": false, "levels": {"master": 1.0, "sound": 0.5, "ambience": 0.8, "music": 0.0},
		"shake": true, "auto_pickup": false, "zoom_label": "1.00x",
		"bindings": {Controls.LEFT: "A", Controls.RIGHT: "D", Controls.JUMP: "SPACE", Controls.MINE: "LMB"},
		"event_labels": {Controls.LEFT: ["A", "LEFT"], Controls.RIGHT: ["D", "RIGHT"], Controls.JUMP: ["SPACE"], Controls.MINE: ["LMB"]},
		"all_actions": [Controls.LEFT, Controls.RIGHT, Controls.JUMP, Controls.MINE]}


func _test_the_tables_and_the_labels() -> void:
	var n: int = SettingsPage.REMAP_ROWS.size()
	var per: int = SettingsPage.remap_per_col()
	_check(n == 25 and per == 13, "every action the hand reads, thirteen a column (%d, %d) -- D0410 + D0615's ten wells, not four of fifteen" % [n, per])
	var listed: Dictionary = {}
	for row: Array in SettingsPage.REMAP_ROWS:
		listed[row[0]] = true
	var missing: Array = []
	for action: StringName in Controls.defaults():
		if not listed.has(action):
			missing.append(action)
	_check(missing.is_empty(), "no bound action is left off the page: %s" % [missing])
	_check(SettingsPage.action_label(Controls.MINE) == "mine (hold)" and SettingsPage.action_label(&"no_such") == "no_such", "an action's human name, or its id when it has none")
	_check(SettingsPage.focus_count(SettingsPage.CAT_CONTROLS) == SettingsPage.REMAP_ROWS.size() + 1 and SettingsPage.focus_count(SettingsPage.CAT_AUDIO) == 5 and SettingsPage.focus_count(SettingsPage.CAT_FEEL) == 3, "the bindings plus RESET, the mute plus four levels, three toggles")
	_check(SettingsPage.clamp_cat(-1) == 0 and SettingsPage.clamp_cat(9) == SettingsPage.CAT_NAMES.size() - 1, "a category index that exists")
	_check(SettingsPage.RAIL_ORDER == [SettingsPage.CAT_AUDIO, SettingsPage.CAT_FEEL, SettingsPage.CAT_GAME, SettingsPage.CAT_CONTROLS], "GAME sits third on the rail; CONTROLS last as a door")
	_check(SettingsPage.focus_count(SettingsPage.CAT_GAME) == 2 and SettingsPage.wanted_h(SettingsPage.CAT_GAME) == SettingsPage.SET_MIN_H and SettingsPage.CAT_NAMES.size() == SettingsPage.CATEGORY_LINE.size(), "GAME: two rows at the floor height, and every category has its line")


func _test_the_payloads_clamp() -> void:
	_check(SettingsPage.row_payload(SettingsPage.CAT_CONTROLS, 3) == {"bind": String(Controls.MINE)}, "the fourth binding row binds MINE")
	_check(SettingsPage.row_payload(SettingsPage.CAT_CONTROLS, SettingsPage.REMAP_ROWS.size()) == {"reset": true} and SettingsPage.row_payload(SettingsPage.CAT_CONTROLS, 99) == {"reset": true}, "past the bindings is RESET, however far past")
	_check(SettingsPage.row_payload(SettingsPage.CAT_AUDIO, 0) == {"toggle": "mute"} and SettingsPage.row_payload(SettingsPage.CAT_AUDIO, 2) == {"slider": "sound"}, "audio: the mute, then the levels offset by one -- the table's second column is the shell's id, its first the label")
	_check(SettingsPage.row_payload(SettingsPage.CAT_AUDIO, 40) == {"slider": "music"}, "an audio row past the end clamps to the last level")
	_check(SettingsPage.row_payload(SettingsPage.CAT_FEEL, 1) == {"cycle": "zoom"} and SettingsPage.row_payload(SettingsPage.CAT_FEEL, 0) == {"toggle": "shake"}, "feel: zoom cycles, the rest toggle")


func _test_the_cursor_steps_and_jumps() -> void:
	_check(SettingsPage.next_row(SettingsPage.CAT_CONTROLS, 0, KEY_DOWN) == 1 and SettingsPage.next_row(SettingsPage.CAT_CONTROLS, 0, KEY_UP) == 0, "down steps, up at the top clamps")
	_check(SettingsPage.next_row(SettingsPage.CAT_CONTROLS, 0, KEY_RIGHT) == SettingsPage.remap_per_col() and SettingsPage.next_row(SettingsPage.CAT_CONTROLS, SettingsPage.remap_per_col() + 1, KEY_LEFT) == 1, "right and left jump a column on the two-column face")
	var reset_row: int = SettingsPage.REMAP_ROWS.size()
	_check(SettingsPage.next_row(SettingsPage.CAT_CONTROLS, reset_row, KEY_DOWN) == reset_row, "down off RESET stays: clamped, never wrapped")
	_check(SettingsPage.next_row(SettingsPage.CAT_AUDIO, 2, KEY_RIGHT) == 2 and SettingsPage.next_row(SettingsPage.CAT_FEEL, 1, KEY_LEFT) == 1, "on the single-column faces the column jump is 0")
	_check(SettingsPage.row_action(SettingsPage.CAT_CONTROLS, 2) == Controls.JUMP and SettingsPage.row_action(SettingsPage.CAT_CONTROLS, SettingsPage.REMAP_ROWS.size()) == &"" and SettingsPage.row_action(SettingsPage.CAT_AUDIO, 1) == &"", "the action under the cursor, none on RESET or off the face")
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
	p.open = false
	for _i: int in 30:
		p.advance(0.05)
	_check(not p.visible(), "closed again: gone")
	var lines: Array = SettingsPage.wrap(font, "click a binding, then press its new key, and then some more words to wrap", 120.0, 10)
	_check(lines.size() >= 2, "a long sentence wraps at the plate's width (%d lines)" % lines.size())


## The modal as a real tree (D0632), re-cut typeset (D0634): the shell builds around the model, faces
## materialize per category, the head is an overline over a display title over a rule, every row sits
## on a hairline, the plate hugs its content, and the payloads the painter's hit-rects spoke now come
## off real control signals.
func _test_the_control_tree_is_the_page() -> void:
	var page: SettingsPage = SettingsPage.new()
	page.state = _state()
	var ctl := SettingsControl.new()
	ctl.page = page
	root.add_child(ctl)
	await process_frame
	var plate: PanelContainer = ctl.find_child("plate", true, false)   # runtime nodes are unowned
	var rail: VBoxContainer = ctl.find_child("rail", true, false)
	_check(ctl.theme != null and plate != null and rail != null and ctl.find_child("detail", true, false) != null,
		"the shell: a themed plate with a rail and a detail plate")
	_check(not ctl.visible, "a closed page keeps its tree dark")
	_check(rail.get_child_count() == SettingsPage.RAIL_ORDER.size(), "one rail tab per face, in rail order")
	page.open = true
	for _i: int in 40:
		page.advance(0.05)
	for _i: int in 3:
		await process_frame
	_check(ctl.visible and is_equal_approx(page.ease(), 1.0), "an open page raises a visible tree")
	var overline: Label = ctl.find_child("overline", true, false)
	var title: Label = ctl.find_child("title", true, false)
	_check(overline != null and overline.text == "SETTINGS" and title != null and title.text == "Audio"
		and ctl.find_child("head_rule", true, false) != null,
		"the head typesets itself: tracked overline, the category as display title, a rule under it")
	_check((overline.get_theme_font("font") as FontVariation).spacing_glyph > 0
		and (title.get_theme_font("font") as FontVariation).variation_embolden > 0.0,
		"the fake-it hierarchy is real: the overline is tracked, the title emboldened")
	_check(is_zero_approx(plate.custom_minimum_size.y),
		"the plate hugs content -- no authored height floor to float an empty lower half")
	var wrap0: Control = ctl._focusables[0].get_meta("ring")
	var ruled: bool = false
	for k: Node in (wrap0.get_child(0) as Container).get_children():
		if (k as Control).theme_type_variation == &"PageRule":
			ruled = true
	_check(ruled, "every row sits on a PageRule hairline, not a filled box")
	var sliders: Array = ctl.find_children("*", "HSlider", true, false)
	var chips: Array = ctl.find_children("*", "Button", true, false)
	_check(sliders.size() == 4 and chips.size() == SettingsPage.RAIL_ORDER.size() + 1,
		"AUDIO: four sliders, the rail, and the mute chip (%d sliders, %d chips)" % [sliders.size(), chips.size()])
	var unfocused: bool = true
	for c: Control in ctl.find_children("*", "Control", true, false):
		if c.focus_mode != Control.FOCUS_NONE:
			unfocused = false
	_check(unfocused, "no control takes gui focus -- keys stay the seat's")
	var got: Array = []
	ctl.payload.connect(func(p: Dictionary) -> void: got.append(p))
	(sliders[1] as HSlider).value = 0.25   # the snapshot seats sound at 0.5; a change is what emits
	_check(not got.is_empty() and got[0].get("slider") == "sound" and absf(float(got[0].get("frac", -1.0)) - 0.25) < 0.05,
		"the second slider answers at a quarter: %s" % str(got))
	got.clear()
	for c: Control in chips:
		if String(c.get_meta("dyn_id", "")) == "mute":
			(c as Button).pressed.emit()
	_check(got == [{"toggle": "mute"}], "the mute chip's payload is the model's: %s" % str(got))
	got.clear()
	(rail.get_child(3) as Button).pressed.emit()
	_check(got == [{"cat": SettingsPage.CAT_CONTROLS}], "the fourth rail tab selects CONTROLS: %s" % str(got))
	page.row = 2
	await process_frame
	_check((ctl._focusables[2].get_meta("ring") as Control).has_theme_stylebox_override("panel")
		and not (ctl._focusables[0].get_meta("ring") as Control).has_theme_stylebox_override("panel"),
		"the ring mirrors page.row and moves off the row it left")
	await _controls_and_game_faces(page, ctl)
	ctl.apply_skin("paper")
	for _i: int in 2:
		await process_frame
	# `ctl.theme` is the skin carrier: `apply_skin` rebuilds it whole, and the plate reads its
	# "panel" stylebox under the PagePlate variation from it.
	_check((ctl.theme.get_stylebox("panel", "PagePlate") as StyleBoxFlat).bg_color.is_equal_approx(PageTokens.PAPER["plate"])
		and plate.theme_type_variation == &"PagePlate",
		"the paper skin reaches the theme the plate draws from")
	_check((ctl._detail as Label).get_theme_color("font_color").is_equal_approx(PageTokens.PAPER["ink_faint"])
		and (ctl._foot as Label).get_theme_color("font_color").is_equal_approx(PageTokens.PAPER["ink_faint"]),
		"the note ink rides the swap whole -- the capture's stale-INSTRUMENT-ink bug cannot recur (D0634)")
	page.open = false
	for _i: int in 40:
		page.advance(0.05)
	for _i: int in 3:
		await process_frame
	_check(not ctl.visible, "a closed page takes the tree with it")
	ctl.queue_free()


## CONTROLS and GAME (D0632): the two-column face rings by MODEL row even though the grid is filled
## column-major, and the armed second door says SURE on the chip itself.
func _controls_and_game_faces(page: SettingsPage, ctl: SettingsControl) -> void:
	page.set_cat(SettingsPage.CAT_CONTROLS)
	for _i: int in 2:
		await process_frame
	_check(ctl._focusables.size() == SettingsPage.REMAP_ROWS.size() + 1, "the bindings plus RESET are the cursor's stops")
	_check(String((ctl._focusables[1] as Control).get_meta("dyn_id", "")) == "bind:" + String(SettingsPage.REMAP_ROWS[1][0]),
		"row 1's ring lands on the model's second binding, not the grid's second cell")
	_check((ctl._focusables[1].get_meta("ring") as Control).get_parent() is GridContainer, "the rows live in the two-column grid")
	page.row = 1
	await process_frame
	_check((ctl._focusables[1].get_meta("ring") as Control).has_theme_stylebox_override("panel"), "the ring follows the cursor into the second binding")
	page.set_cat(SettingsPage.CAT_GAME)
	page.armed = "new"
	for _i: int in 2:
		await process_frame
	var new_chip: Button = null
	for c: Control in ctl.find_children("*", "Button", true, false):
		if String(c.get_meta("dyn_id", "")) == "new":
			new_chip = c
	var got: Array = []
	ctl.payload.connect(func(p: Dictionary) -> void: got.append(p))
	new_chip.pressed.emit()
	_check(new_chip.text.contains("SURE") and got == [{"game": "new"}],
		"the armed door says SURE and still speaks its payload (%s / %s)" % [new_chip.text, str(got)])
