class_name SettingsDraw
extends RefCounted

## THE SETTINGS PAGE AS IT IS DRAWN (A' step 6j, D0372): legacy `scenes/settings_page.gd`'s drawing
## half, static over a `SettingsPage` and a canvas. The page registers what was drawn (`add_hit`,
## `set_slider_rect`), so a click is routed against the rectangles that were actually painted and not
## against a second copy of the layout. Every number is legacy's authored number through `UiTheme.px`.
##
## The rules legacy wrote down and this keeps: the mouse wins when it is on a control because it is the
## more deliberate pointer, and the keyboard cursor speaks when nothing is hovered, so the detail plate
## always describes the thing that would act; hover lifts a fill, selection fills gold, focus RINGS from
## outside, and the three can coexist on one control; a clashing key wears the warn colour, not the gold.

const FS: int = 10
const HOVER_FILL := Color(0.30, 0.34, 0.44)
const ROW_LIT := Color(0.145, 0.129, 0.082)
const DARK_INK := Color(0.10, 0.10, 0.12)


static func _px(v: float) -> float:
	return UiTheme.px(v)


static func _pt(v: int) -> int:
	return UiTheme.pt(v)


static func _focus_ring(ci: CanvasItem, box: Rect2, grow: float = -1.0, spine: bool = false) -> void:
	PageDraw.focus_ring(ci, box, UiTheme.GOLD_PALE, UiTheme.UI_ACCENT, _px(PageDraw.FOCUS_GROW) if grow < 0.0 else grow, spine)


static func overlay(page: SettingsPage, ci: CanvasItem, font: Font, mouse: Vector2) -> void:
	page.begin_hits()
	var t: float = page.ease()
	ci.draw_rect(Rect2(Vector2.ZERO, UiTheme.CANVAS), Color(0.02, 0.025, 0.04, 0.42 * t))
	PageDraw.edge_vignette(ci, UiTheme.CANVAS, 0.5 * t)
	var g: Dictionary = page.geometry()
	var origin: Vector2 = g["origin"]
	var plate := Rect2(origin, Vector2(float(g["w"]), float(g["h"])))
	# The page rises the last few pixels into place: one transform, so nothing below has to know.
	ci.draw_set_transform(Vector2(0.0, (1.0 - t) * _px(14.0)), 0.0, Vector2.ONE)
	PageDraw.soft_shadow(ci, plate, int(_px(12.0)), 0.34)
	PageDraw.round_rect(ci, plate, _px(8.0), UiTheme.UI_MODAL)
	PageDraw.panel_sheen(ci, plate, UiTheme.UI_SCALE)
	_rail(page, ci, font, origin, g, mouse)
	_head(page, ci, font, origin)
	var told: String = _body(page, ci, font, g, mouse)
	_detail(page, ci, font, g, told, mouse)
	# Fitted to the plate it sits on (D0410): the compact faces are 592 px wide and the old 63-character
	# line overran their right edge by up to 100 px; drawn with the plate's own width as its limit so no
	# face can ever push it past the edge again, and a step higher so descenders clear the rounded foot.
	var legend: String = "arrows move   ENTER rebinds   1-4 tab   ESC closes" if page.cat == SettingsPage.CAT_CONTROLS \
		else "up/down row  left/right adjust  ENTER  1-4 tab  ESC"
	var legend_x: float = origin.x + _px(UiTheme.BAZAAR_RAIL + UiTheme.BAZAAR_PAD)
	var legend_w: float = origin.x + float(g["w"]) - _px(UiTheme.BAZAAR_PAD) - legend_x
	ci.draw_string(font, Vector2(legend_x, origin.y + float(g["h"]) - _px(9.0)), legend, HORIZONTAL_ALIGNMENT_LEFT, legend_w, _pt(8), UiTheme.UI_TEXT_FAINT)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The category rail: one hit per category, since the rail is how you change page with the mouse.
static func _rail(page: SettingsPage, ci: CanvasItem, font: Font, origin: Vector2, g: Dictionary, mouse: Vector2) -> void:
	var rail := Rect2(origin, Vector2(_px(UiTheme.BAZAAR_RAIL), float(g["h"])))
	PageDraw.round_rect_left(ci, rail, _px(8.0), UiTheme.UI_RAIL)
	var ys: Array = UiTheme.rail_slots(Rect2(rail.position / UiTheme.UI_SCALE, rail.size / UiTheme.UI_SCALE), SettingsPage.RAIL_ORDER.size(),
		UiTheme.rail_word_slot_h(font) + UiTheme.RAIL_SLOT_AIR, UiTheme.rail_word_slot_h(font))
	for slot: int in SettingsPage.RAIL_ORDER.size():
		var c: int = SettingsPage.RAIL_ORDER[slot]
		var y: float = _px(float(ys[slot]))
		var on: bool = c == page.cat
		var box := Rect2(rail.position.x + _px(9.0), y, _px(UiTheme.RAIL_ICON), _px(UiTheme.RAIL_ICON))
		if on:
			PageDraw.round_rect(ci, box, _px(6.0), UiTheme.RAIL_ON_FILL)
			ci.draw_rect(Rect2(rail.position.x, y + _px(5.0), _px(2.5), _px(28.0)), UiTheme.UI_ACCENT)
		_glyph(ci, box.get_center(), c, on, box.has_point(mouse))
		var label: String = ("%d KEYS · %d" % [slot + 1, SettingsPage.REMAP_ROWS.size()]) if c == SettingsPage.CAT_CONTROLS else "%d %s" % [slot + 1, SettingsPage.CAT_NAMES[c]]
		var lw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _pt(UiTheme.RAIL_LABEL_FS)).x
		ci.draw_string(font, Vector2(box.get_center().x - lw * 0.5, y + _px(UiTheme.RAIL_LABEL_DY)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, _pt(UiTheme.RAIL_LABEL_FS), UiTheme.UI_TEXT if on else UiTheme.UI_TEXT_FAINT)
		page.add_hit(box.grow(_px(6.0)), {"cat": c})


## Four category glyphs, drawn rather than lettered: a speaker cone, a key cap, three sliders, a shaft mouth. `hot`
## is separate from `on`: hover keeps a cue outside the gold family.
static func _glyph(ci: CanvasItem, at: Vector2, kind: int, on: bool, hot: bool) -> void:
	var col: Color = UiTheme.GOLD_PALE if on else (UiTheme.UI_TEXT_DIM if hot else Color(0.40, 0.43, 0.50))
	var s: float = UiTheme.UI_SCALE
	match kind:
		SettingsPage.CAT_AUDIO:
			ci.draw_rect(Rect2(at + Vector2(-8.0, -3.0) * s, Vector2(4.0, 6.0) * s), col)
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-4.0, -1.0) * s, at + Vector2(1.0, -7.0) * s, at + Vector2(1.0, 7.0) * s, at + Vector2(-4.0, 1.0) * s]), col)
			ci.draw_arc(at + Vector2(1.0, 0.0) * s, 5.5 * s, -PI * 0.4, PI * 0.4, 8, col, 1.4 * s)
			ci.draw_arc(at + Vector2(1.0, 0.0) * s, 8.5 * s, -PI * 0.4, PI * 0.4, 8, col, 1.4 * s)
		SettingsPage.CAT_GAME:   # a shaft mouth with the ladder out of it
			ci.draw_rect(Rect2(at + Vector2(-8.0, -7.0) * s, Vector2(16.0, 2.0) * s), col)
			ci.draw_rect(Rect2(at + Vector2(-3.0, -7.0) * s, Vector2(1.6, 14.0) * s), Color(col, 0.8))
			ci.draw_rect(Rect2(at + Vector2(1.4, -7.0) * s, Vector2(1.6, 14.0) * s), Color(col, 0.8))
			for i: int in 3:
				ci.draw_rect(Rect2(at + Vector2(-3.0, -3.0 + float(i) * 4.0) * s, Vector2(6.0, 1.4) * s), col)
		SettingsPage.CAT_CONTROLS:
			ci.draw_rect(Rect2(at + Vector2(-8.0, -6.0) * s, Vector2(16.0, 13.0) * s), Color(col, 0.35))
			ci.draw_rect(Rect2(at + Vector2(-8.0, -6.0) * s, Vector2(16.0, 13.0) * s), col, false, 1.4 * s)
			ci.draw_rect(Rect2(at + Vector2(-3.0, -2.0) * s, Vector2(6.0, 5.0) * s), col)
		_:
			for i: int in 3:
				var y: float = at.y + (-6.0 + float(i) * 6.0) * s
				ci.draw_rect(Rect2(at.x - 9.0 * s, y - 0.7 * s, 18.0 * s, 1.6 * s), Color(col, 0.45))
				ci.draw_rect(Rect2(at.x + (-9.0 + float(3 - i) * 4.5) * s, y - 3.0 * s, 2.6 * s, 6.0 * s), col)


## The head: the identifying word carries the contrast, not the word that is the same on every face.
static func _head(page: SettingsPage, ci: CanvasItem, font: Font, origin: Vector2) -> void:
	var x: float = origin.x + _px(UiTheme.BAZAAR_RAIL + UiTheme.BAZAAR_PAD)
	PageDraw.tracked(ci, font, "SETTINGS", Vector2(x, origin.y + _px(26.0)), _pt(15), _px(2.8), UiTheme.UI_TEXT_FAINT)
	PageDraw.tracked(ci, font, SettingsPage.CAT_NAMES[page.cat], Vector2(x + PageDraw.tracked_width(font, "SETTINGS", _pt(15), _px(2.8)) + _px(16.0), origin.y + _px(26.0)), _pt(15), _px(2.8), UiTheme.UI_TEXT)


static func _body(page: SettingsPage, ci: CanvasItem, font: Font, g: Dictionary, mouse: Vector2) -> String:
	var c: Rect2 = g["content"]
	match page.cat:
		SettingsPage.CAT_CONTROLS: return _controls(page, ci, font, g, c, mouse)
		SettingsPage.CAT_FEEL: return _feel(page, ci, font, c, mouse)
		SettingsPage.CAT_GAME: return _game(page, ci, font, c, mouse)
		_: return _audio(page, ci, font, c, mouse)


static func _audio(page: SettingsPage, ci: CanvasItem, font: Font, c: Rect2, mouse: Vector2) -> String:
	var said: String = ""
	var y: float = c.position.y + _px(14.0)
	var muted: bool = bool(page.state.get("muted", false))
	ci.draw_string(font, Vector2(c.position.x, y), "sound", HORIZONTAL_ALIGNMENT_LEFT, -1, _pt(FS), UiTheme.UI_TEXT)
	var mute_focused: bool = page.row == 0
	if _chip(page, ci, font, c.position.x + _px(SettingsPage.SET_CTRL_DX), y, "MUTED" if muted else "SOUND ON", SettingsPage.row_payload(SettingsPage.CAT_AUDIO, 0), not muted, mouse, FS, muted, mute_focused) or mute_focused:
		said = "silences everything at once; the levels below are kept"
	for i: int in SettingsPage.AUDIO_ROWS.size():
		var r: Array = SettingsPage.AUDIO_ROWS[i]
		y += _px(SettingsPage.SET_ROW)
		var id: String = String(r[1])
		var focused: bool = page.row == i + 1
		if _slider(page, ci, font, c.position.x, y, id, String(r[0]), page.level(id), mouse, focused, muted):
			said = String(r[2])
		elif focused and said == "":
			said = String(r[2])
	return said


static func _feel(page: SettingsPage, ci: CanvasItem, font: Font, c: Rect2, mouse: Vector2) -> String:
	var said: String = ""
	var y: float = c.position.y + _px(14.0)
	for i: int in SettingsPage.FEEL_ROWS.size():
		var r: Array = SettingsPage.FEEL_ROWS[i]
		var id: String = String(r[1])
		ci.draw_string(font, Vector2(c.position.x, y), String(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, _pt(FS), UiTheme.UI_TEXT)
		var text: String
		var on: bool = false
		if id == "zoom":
			text = String(page.state.get("zoom_label", "1.00x"))
		else:
			on = bool(page.state.get("shake" if id == "shake" else "auto_pickup", true))
			text = "ON" if on else "OFF"
		var focused: bool = page.row == i
		if _chip(page, ci, font, c.position.x + _px(SettingsPage.SET_CTRL_DX), y, text, SettingsPage.row_payload(SettingsPage.CAT_FEEL, i), on, mouse, FS, false, focused) or (focused and said == ""):
			said = String(r[2])
		y += _px(SettingsPage.SET_ROW)
	return said


## The GAME face (D0396): a label, a chip, a sentence. NEW GAME paints warm and asks twice: the armed
## chip says so in its own text, so the confirmation is on the control and not in a dialog.
static func _game(page: SettingsPage, ci: CanvasItem, font: Font, c: Rect2, mouse: Vector2) -> String:
	var said: String = ""
	var y: float = c.position.y + _px(14.0)
	for i: int in SettingsPage.GAME_ROWS.size():
		var r: Array = SettingsPage.GAME_ROWS[i]
		var id: String = String(r[1])
		ci.draw_string(font, Vector2(c.position.x, y), String(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, _pt(FS), UiTheme.UI_TEXT)
		var text: String = "RETURN TO SURFACE"
		if id == "new":
			text = "NEW GAME · SURE?" if page.armed == "new" else "NEW GAME"
		var focused: bool = page.row == i
		if _chip(page, ci, font, c.position.x + _px(SettingsPage.SET_CTRL_DX), y, text, SettingsPage.row_payload(SettingsPage.CAT_GAME, i), false, mouse, FS, id == "new", focused) or (focused and said == ""):
			said = String(r[2])
		y += _px(SettingsPage.SET_ROW)
	return said


## The bindings in two columns; the capture state is on the row that is capturing.
static func _controls(page: SettingsPage, ci: CanvasItem, font: Font, g: Dictionary, c: Rect2, mouse: Vector2) -> String:
	var said: String = ""
	var per_col: int = SettingsPage.remap_per_col()
	var col_w: float = float(g["col_w"])
	var clashes: Dictionary = SettingsPage.clashes(page.state)
	for i: int in SettingsPage.REMAP_ROWS.size():
		var r: Array = SettingsPage.REMAP_ROWS[i]
		var x: float = c.position.x + float(i / per_col) * (col_w + _px(SettingsPage.REMAP_GAP))
		var y: float = c.position.y + _px(12.0) + float(i % per_col) * _px(SettingsPage.REMAP_ROW_H)
		var action: StringName = r[0]
		var capturing: bool = page.capture == action
		var clash: Array = clashes.get(action, [])
		var text: String = "press a key…" if capturing else page.binding_label(action)
		var bw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _pt(FS)).x + _px(10.0)
		var chip := Rect2(x + col_w - bw, y - _px(10.0), bw, _px(13.0))
		var lit: bool = chip.has_point(mouse)
		var cursor: bool = i == page.row
		var plate := Rect2(x - _px(4.0), y - _px(11.0), col_w + _px(8.0), _px(15.0))
		if lit or capturing or cursor:
			PageDraw.round_rect(ci, plate, _px(3.0), ROW_LIT)
		if cursor:
			_focus_ring(ci, plate, 0.0, true)
		if lit or (cursor and said == ""):
			if capturing:
				said = "press any key to bind it — ESC cancels"
			elif not clash.is_empty():
				said = " and ".join(clash)
			else:
				said = String(r[2]) if String(r[2]) != "" else "%s — press Enter to rebind" % String(r[1])
		ci.draw_string(font, Vector2(x, y), String(r[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, _pt(FS), UiTheme.UI_TEXT if (lit or capturing) else UiTheme.UI_TEXT_DIM)
		var fill: Color = UiTheme.UI_ACCENT if capturing else (UiTheme.UI_WARN if not clash.is_empty() else (HOVER_FILL if lit else UiTheme.UI_SLOT))
		ci.draw_rect(chip, fill)
		ci.draw_rect(chip, Color(0.0, 0.0, 0.0, 0.5), false, 1.0)
		ci.draw_string(font, Vector2(chip.position.x + _px(5.0), y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _pt(FS), DARK_INK if (capturing or not clash.is_empty()) else UiTheme.UI_TEXT)
		page.add_hit(chip, SettingsPage.row_payload(SettingsPage.CAT_CONTROLS, i))
	if page.row >= SettingsPage.REMAP_ROWS.size() and said == "":
		said = "puts every binding back to its default"
	return said


## The detail plate: what the control under your hand does, wrapped by hand at the plate's width.
static func _detail(page: SettingsPage, ci: CanvasItem, font: Font, g: Dictionary, said: String, mouse: Vector2) -> void:
	var d: Rect2 = g["detail"]
	PageDraw.round_rect(ci, d, _px(5.0), Color(0.0, 0.0, 0.0, 0.22))
	var line: String = said if said != "" else SettingsPage.CATEGORY_LINE[page.cat]
	var y: float = d.position.y + _px(20.0)
	for part: String in SettingsPage.wrap(font, line, d.size.x - _px(24.0), _pt(FS)):
		ci.draw_string(font, Vector2(d.position.x + _px(12.0), y), part, HORIZONTAL_ALIGNMENT_LEFT, -1, _pt(FS), UiTheme.UI_TEXT if said != "" else UiTheme.UI_TEXT_FAINT)
		y += _px(13.0)
	if page.cat == SettingsPage.CAT_CONTROLS:
		var w: float = font.get_string_size("RESET KEYS", HORIZONTAL_ALIGNMENT_LEFT, -1, _pt(9)).x + _px(14.0)
		_chip(page, ci, font, d.end.x - w, d.end.y - _px(8.0), "RESET KEYS", SettingsPage.row_payload(SettingsPage.CAT_CONTROLS, SettingsPage.REMAP_ROWS.size()), false, mouse, 9, false, page.row >= SettingsPage.REMAP_ROWS.size())


## One level: label, bar and percentage on the shared grid; dimmed while muted. Returns hover.
static func _slider(page: SettingsPage, ci: CanvasItem, font: Font, x0: float, y: float, id: String, label: String, value: float, mouse: Vector2, focused: bool, muted: bool) -> bool:
	var bar := Rect2(x0 + _px(SettingsPage.SET_CTRL_DX), y - _px(9.0), _px(SettingsPage.SET_BAR_W), _px(10.0))
	page.set_slider_rect(id, bar)
	var hot: bool = bar.grow(_px(4.0)).has_point(mouse)
	ci.draw_string(font, Vector2(x0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, _pt(FS), UiTheme.UI_TEXT_DIM if muted else UiTheme.UI_TEXT)
	ci.draw_rect(bar, Color(0.0, 0.0, 0.0, 0.5))
	var fill := Rect2(bar.position, Vector2(bar.size.x * clampf(value, 0.0, 1.0), bar.size.y))
	ci.draw_rect(fill, Color(UiTheme.UI_ACCENT, 0.55) if muted else UiTheme.UI_ACCENT)
	ci.draw_rect(bar, UiTheme.UI_EDGE_HI if hot else UiTheme.UI_EDGE, false, 1.0)
	if value > 0.0:
		ci.draw_rect(Rect2(fill.end.x - _px(2.0), bar.position.y - _px(2.0), _px(2.5), bar.size.y + _px(4.0)), UiTheme.GOLD_PALE if hot else Color(0.80, 0.83, 0.89))
	ci.draw_string(font, Vector2(x0 + _px(SettingsPage.SET_VALUE_DX), y), "%d%%" % int(round(value * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, _pt(FS), UiTheme.UI_TEXT if (hot or focused) else UiTheme.UI_TEXT_DIM)
	if focused:
		_focus_ring(ci, bar.grow(_px(2.0)))
	page.add_hit(bar.grow(_px(3.0)), {"slider": id})
	return hot


## One chip: `active` fills gold, `hot` lifts the fill, `warn` paints warm-on-dark (suppressed without
## claiming chosen), and `focused` rings it from outside. Returns hover.
static func _chip(page: SettingsPage, ci: CanvasItem, font: Font, x: float, y: float, text: String, payload: Dictionary, active: bool, mouse: Vector2, size: int, warn: bool, focused: bool) -> bool:
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _pt(size)).x + _px(12.0)
	var chip := Rect2(x, y - _px(11.0), w, _px(15.0))
	var hot: bool = chip.has_point(mouse)
	if warn:
		ci.draw_rect(chip, Color(0.22, 0.15, 0.11))
		ci.draw_rect(chip, Color(0.86, 0.47, 0.31, 0.95 if hot else 0.75), false, 1.0)
		ci.draw_string(font, Vector2(x + _px(6.0), y + _px(1.0)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _pt(size), Color(0.96, 0.64, 0.47))
	else:
		ci.draw_rect(chip, UiTheme.UI_ACCENT if active else (HOVER_FILL if hot else UiTheme.UI_SLOT))
		ci.draw_rect(chip, Color(0.0, 0.0, 0.0, 0.5), false, 1.0)
		ci.draw_string(font, Vector2(x + _px(6.0), y + _px(1.0)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _pt(size), DARK_INK if active else UiTheme.UI_TEXT)
	if focused:
		_focus_ring(ci, chip)
	page.add_hit(chip, payload)
	return hot
