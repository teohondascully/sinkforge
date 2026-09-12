class_name SettingsControl
extends Control

## THE SETTINGS PAGE AS A REAL CONTROL TREE (D0632, the Hybrid ruling): the painter HUD keeps its
## one-frame-per-tick contract for the in-world chrome; this modal -- which never needed per-tick
## drawing -- is a retained tree with a Theme. `SettingsPage` stays the model: which face is open, where
## the keyboard cursor sits, what a row answers. This node presents it and speaks the same PAYLOADS the
## painter's hit-rects did, so `HudBridge.apply` and the seat's `_game_verb` are untouched.
##
## ONE NAVIGATOR, NOT TWO: every control here is `FOCUS_NONE`, so Enter/arrows are never consumed as
## gui input and always reach the seat's `_unhandled_input` -> `HudBridge.key`, the tested path. The
## cursor is drawn as a stylebox override on `page.row`'s control -- the same ring, outside the rect,
## that the painter drew by hand. Mouse hover feeds only the detail plate, matching the drawn page's
## own precedence.
##
## TWO SKINS, ONE TREE: `PageTokens.INSTRUMENT` / `.PAPER`, switched whole by `apply_skin`. The rise
## keeps `SettingsPage`'s own counter/ease, applied as the plate's offset and alpha.

signal payload(p: Dictionary)

## The model the shell already owns. `page.state` is the snapshot `HudBridge.snapshot()` hands over;
## `page.row`/`cat`/`capture`/`armed` are the keyboard face this mirrors.
var page: SettingsPage = null

var _tokens: Dictionary = PageTokens.INSTRUMENT
var _built_cat: int = -1
var _focusables: Array[Control] = []
var _hover_row: int = -1
var _dragging: HSlider = null
var _ringed: Control = null
var _ring_key: StringName = &"panel"

var _scrim: ColorRect = null
var _plate: PanelContainer = null
var _rail: VBoxContainer = null
var _head: Label = null
var _rows: VBoxContainer = null
var _detail: Label = null
var _foot: Label = null
var _dyn: Dictionary = {}   ## id -> the Control that re-reads the snapshot each frame


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	theme = PageTokens.make_theme(_tokens)
	_build_shell()


func apply_skin(skin: String) -> void:
	_tokens = PageTokens.named(skin)
	if is_inside_tree():
		theme = PageTokens.make_theme(_tokens)
		_scrim.color = Color(tokens_scrim(), 0.0)
		_ringed = null
		_built_cat = -1


func tokens_scrim() -> Color:
	return _tokens["scrim"]


func _process(delta: float) -> void:
	if page == null:
		visible = false
		return
	page.advance(delta)
	if not page.visible():
		visible = false
		return
	visible = true
	var t: float = page.ease()
	_plate.modulate.a = t
	_plate.position.y = (1.0 - t) * UiTheme.px(14.0)
	_scrim.color = Color(tokens_scrim(), float(_tokens["scrim"].a) * t)
	if _built_cat != page.cat:
		_build_face()
	_refresh()
	_focus_mirror()


## The fixed skeleton: scrim over everything, the plate centred, rail down its left and the face on
## its right. Children of a CanvasLayer draw in screen pixels, so every length is authored x UI_SCALE.
func _build_shell() -> void:
	_scrim = ColorRect.new()
	_scrim.name = "scrim"
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP   ## a modal eats the clicks it covers
	_scrim.color = Color(tokens_scrim(), 0.0)
	add_child(_scrim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_plate = PanelContainer.new()
	_plate.name = "plate"
	_plate.theme_type_variation = &"PagePlate"
	centre.add_child(_plate)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", int(UiTheme.px(UiTheme.BAZAAR_PAD)))
	_plate.add_child(split)
	_rail = VBoxContainer.new()
	_rail.name = "rail"
	_rail.custom_minimum_size.x = UiTheme.px(UiTheme.BAZAAR_RAIL - UiTheme.BAZAAR_PAD)
	split.add_child(_rail)
	for slot: int in SettingsPage.RAIL_ORDER.size():
		var c: int = SettingsPage.RAIL_ORDER[slot]
		var tab := _chip("%d %s" % [slot + 1, SettingsPage.CAT_NAMES[c]], {"cat": c}, &"RailTab")
		tab.toggle_mode = true
		tab.add_theme_font_size_override("font_size", int(_tokens["rail_size"]))
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_rail.add_child(tab)
	var face := VBoxContainer.new()
	face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(face)
	_head = Label.new()
	_head.name = "head"
	_head.add_theme_font_size_override("font_size", int(_tokens["display_size"]))
	face.add_child(_head)
	_rows = VBoxContainer.new()
	_rows.name = "rows"
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", int(UiTheme.px(4.0)))
	face.add_child(_rows)
	var detail_plate := PanelContainer.new()
	detail_plate.theme_type_variation = &"PageRail"
	face.add_child(detail_plate)
	_detail = Label.new()
	_detail.name = "detail"
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size", int(_tokens["small_size"]))
	_detail.add_theme_color_override("font_color", _tokens["ink_faint"])
	detail_plate.add_child(_detail)
	_foot = Label.new()
	_foot.name = "foot"
	_foot.add_theme_font_size_override("font_size", int(_tokens["small_size"]))
	_foot.add_theme_color_override("font_color", _tokens["ink_faint"])
	face.add_child(_foot)


## Rebuild the open face's rows. The plate asks for the face's own size, so CONTROLS' two-column table
## gets its width and AUDIO keeps its compact one -- `SettingsPage`'s own numbers, one hop away.
func _build_face() -> void:
	_built_cat = page.cat
	for kid: Node in _rows.get_children():
		kid.queue_free()
	_focusables.clear()
	_dyn.clear()
	_ringed = null
	_hover_row = -1
	_head.text = "SETTINGS  %s" % SettingsPage.CAT_NAMES[page.cat]
	_plate.custom_minimum_size = Vector2(
		UiTheme.px(SettingsPage.width_for(page.cat)), UiTheme.px(SettingsPage.wanted_h(page.cat)))
	_foot.text = "arrows move   ENTER rebinds   1-4 tab   ESC closes" if page.cat == SettingsPage.CAT_CONTROLS \
		else "up/down row  left/right adjust  ENTER  1-4 tab  ESC"
	match page.cat:
		SettingsPage.CAT_CONTROLS: _face_controls()
		SettingsPage.CAT_FEEL: _face_feel()
		SettingsPage.CAT_GAME: _face_game()
		_: _face_audio()


## AUDIO: the mute chip, then one slider row per level -- the shell's snapshot order, row 0 first.
func _face_audio() -> void:
	_add_row("sound", _chip("SOUND ON", {"toggle": "mute"}, &"Chip", "mute"))
	for r: Array in SettingsPage.AUDIO_ROWS:
		var id: String = String(r[1])
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.focus_mode = Control.FOCUS_NONE
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = UiTheme.px(SettingsPage.SET_BAR_W)
		slider.drag_started.connect(func() -> void: _dragging = slider)
		slider.drag_ended.connect(func(_c: bool) -> void: _dragging = null)
		slider.value_changed.connect(func(v: float) -> void: _emit({"slider": id, "frac": v}))
		_dyn[id] = slider
		var pct := Label.new()
		pct.add_theme_font_size_override("font_size", int(_tokens["body_size"]))
		pct.custom_minimum_size.x = UiTheme.px(14.0)
		_dyn["pct:" + id] = pct
		_add_row(String(r[0]), slider, pct)


## FEEL: a chip per row -- toggles print ON/OFF, the zoom prints its own label.
func _face_feel() -> void:
	for r: Array in SettingsPage.FEEL_ROWS:
		var id: String = String(r[1])
		_add_row(String(r[0]), _chip("", SettingsPage.row_payload(page.cat, _focusables.size()), &"Chip", id))


## GAME: the two doors; NEW GAME's second press is the one that acts, said on the chip itself.
func _face_game() -> void:
	for r: Array in SettingsPage.GAME_ROWS:
		var id: String = String(r[1])
		var chip := _chip("RETURN TO SURFACE" if id != "new" else "NEW GAME",
				SettingsPage.row_payload(page.cat, _focusables.size()),
				&"ChipWarn" if id == "new" else &"Chip", id)
		_add_row(String(r[0]), chip)


## CONTROLS: two columns of [verb -- binding chip], RESET KEYS last -- the same focus order the
## model's `row_payload` already assigns.
func _face_controls() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(UiTheme.px(SettingsPage.REMAP_GAP)))
	grid.add_theme_constant_override("v_separation", int(UiTheme.px(2.0)))
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.add_child(grid)
	var per_col: int = SettingsPage.remap_per_col()
	_focusables.resize(SettingsPage.REMAP_ROWS.size())   ## indexed by MODEL row: the grid is filled
	for pos: int in SettingsPage.REMAP_ROWS.size():       ## column-major while `page.row` is row-major
		var i: int = (pos % 2) * per_col + pos / 2
		var r: Array = SettingsPage.REMAP_ROWS[i]
		_add_row(String(r[1]), _chip("?", {"bind": String(r[0])}, &"Chip", "bind:" + String(r[0])), null, grid, i)
	var reset := _chip("RESET KEYS", {"reset": true}, &"Chip", "reset")
	_focusables.append(reset)
	_wire_hover(reset, _focusables.size() - 1)
	_rows.add_child(reset)


## One labelled row into `_rows` (or a supplied container), the verb on the left and its control(s) on
## the right; registers the control in `_focusables`/`_dyn`/`_hover` under the row's own index, which
## is what keeps the keyboard cursor and the pointer naming the same thing.
func _add_row(label: String, control: Control, extra: Control = null, into: Container = null, row_idx: int = -1) -> void:
	var idx: int = row_idx if row_idx >= 0 else _focusables.size()
	if row_idx >= 0:
		_focusables[row_idx] = control
	else:
		_focusables.append(control)
	if control.get_meta("dyn_id", "") != "":
		_dyn[control.get_meta("dyn_id")] = control
	_wire_hover(control, idx)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(UiTheme.px(8.0)))
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", int(_tokens["body_size"]))
	l.add_theme_color_override("font_color", _tokens["ink_dim"])
	if into == null:
		l.custom_minimum_size.x = UiTheme.px(SettingsPage.SET_CTRL_DX - 8.0)
	else:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL if into == null else Control.SIZE_SHRINK_END
	h.add_child(control)
	if extra != null:
		h.add_child(extra)
	# The ring's bed: a PanelContainer whose `panel` starts EMPTY and takes the focus stylebox when
	# `page.row` lands here. A Button could carry `normal` itself, but an HSlider has no "normal" to
	# override -- the wrapper gives every row the same ringable surface.
	var wrap := PanelContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	wrap.add_child(h)
	control.set_meta("ring", wrap)
	(into if into != null else _rows).add_child(wrap)


func _chip(text: String, p: Dictionary, variation: StringName, dyn_id: String = "") -> Button:
	var b := Button.new()
	b.theme_type_variation = variation
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", int(_tokens["body_size"]))
	b.pressed.connect(_emit.bind(p))
	if dyn_id != "":
		b.set_meta("dyn_id", dyn_id)
	return b


func _emit(p: Dictionary) -> void:
	payload.emit(p)


func _wire_hover(c: Control, i: int) -> void:
	c.mouse_entered.connect(func() -> void: _hover_row = i)
	c.mouse_exited.connect(func() -> void:
		if _hover_row == i:
			_hover_row = -1)


## The frame's moving parts, re-read from the snapshot while the page is up: slider values (except the
## one in the hand), chip texts, the capture and the arm, the clash marks. Every `_dyn` read is guarded
## -- a key only exists while its face is built.
func _refresh() -> void:
	var st: Dictionary = page.state
	var muted: bool = bool(st.get("muted", false))
	var mute: Button = _dyn.get("mute")
	if mute != null:
		mute.text = "MUTED" if muted else "SOUND ON"
	for id: String in ["master", "sound", "ambience", "music"]:
		var s: HSlider = _dyn.get(id)
		if s != null and s != _dragging:
			s.set_value_no_signal(page.level(id))
		var pct: Label = _dyn.get("pct:" + id)
		if pct != null:
			pct.text = "%d%%" % int(round(page.level(id) * 100.0))
			pct.add_theme_color_override("font_color", _tokens["ink_dim"] if muted else _tokens["ink"])
	for id: String in ["shake", "auto_pickup"]:
		var b: Button = _dyn.get(id)
		if b != null:
			b.text = "ON" if bool(st.get("shake" if id == "shake" else "auto_pickup", true)) else "OFF"
	var zoom_b: Button = _dyn.get("zoom")
	if zoom_b != null:
		zoom_b.text = String(st.get("zoom_label", ""))
	var new_b: Button = _dyn.get("new")
	if new_b != null:
		new_b.text = "NEW GAME · SURE?" if page.armed == "new" else "NEW GAME"
	var clashes: Dictionary = SettingsPage.clashes(st)
	for r: Array in SettingsPage.REMAP_ROWS:
		var b: Button = _dyn.get("bind:" + String(r[0]))
		if b == null:
			continue
		var act: StringName = r[0]
		b.text = "press a key…" if page.capture == act else page.binding_label(act)
		b.add_theme_color_override("font_color", _tokens["warn"] if clashes.has(act) else _tokens["ink"])
	for slot: int in _rail.get_child_count():
		(_rail.get_child(slot) as Button).set_pressed_no_signal(SettingsPage.RAIL_ORDER[slot] == page.cat)
	_detail.text = _detail_text()


## What the detail plate says: the hovered control's own sentence wins (the more deliberate pointer),
## else the focused row's, else the category's standing line -- the drawn page's exact precedence.
func _detail_text() -> String:
	var i: int = _hover_row if _hover_row >= 0 else page.row
	match page.cat:
		SettingsPage.CAT_CONTROLS:
			if i >= SettingsPage.REMAP_ROWS.size():
				return "puts every binding back to its default"
			var act: StringName = SettingsPage.row_action(page.cat, i)
			if page.capture == act and act != &"":
				return "press any key to bind it — ESC cancels"
			var clash: Array = SettingsPage.clashes(page.state).get(act, [])
			if not clash.is_empty():
				return " and ".join(clash)
			var r: Array = SettingsPage.REMAP_ROWS[i]
			return String(r[2]) if String(r[2]) != "" else "%s — press Enter to rebind" % String(r[1])
		SettingsPage.CAT_FEEL:
			if i >= 0 and i < SettingsPage.FEEL_ROWS.size():
				return String(SettingsPage.FEEL_ROWS[i][2])
		SettingsPage.CAT_GAME:
			if i >= 0 and i < SettingsPage.GAME_ROWS.size():
				return String(SettingsPage.GAME_ROWS[i][2])
		_:
			if i == 0:
				return "silences everything at once; the levels below are kept"
			if i > 0 and i <= SettingsPage.AUDIO_ROWS.size():
				return String(SettingsPage.AUDIO_ROWS[i - 1][2])
	return SettingsPage.CATEGORY_LINE[page.cat]


## The keyboard cursor as a drawn ring: the row wrapper at `page.row` gets the focus stylebox -- the
## face's lit bed and an accent border pushed outside the rect; focus RINGS from outside, the drawn
## page's own rule. A bare control (RESET) rings on its own `normal`. Nothing here takes real gui
## focus, so keys stay the seat's.
func _focus_mirror() -> void:
	var want: Control = _focusables[page.row] if page.row >= 0 and page.row < _focusables.size() else null
	var target: Control = want
	var key := &"normal"
	if want != null and want.has_meta("ring"):
		target = want.get_meta("ring")
		key = &"panel"
	if target == _ringed:
		return
	if _ringed != null and is_instance_valid(_ringed):
		_ringed.remove_theme_stylebox_override(_ring_key)
	_ringed = target
	_ring_key = key
	if _ringed == null:
		return
	var ring := StyleBoxFlat.new()
	ring.bg_color = _tokens["row_lit"]
	ring.border_color = _tokens["accent_pale"]
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(int(float(_tokens["radius"]) * 0.5) + 2)
	ring.set_expand_margin_all(3.0)
	_ringed.add_theme_stylebox_override(key, ring)


## The control's row index in `_focusables`, or -1 -- the ring's bookkeeping, kept honest because a
## rebuilt face reuses neither list nor nodes.
func _focus_row_of(c: Control) -> int:
	return _focusables.find(c)
