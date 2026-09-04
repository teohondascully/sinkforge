extends "res://tests/test_base.gd"
## D0372. `view/hud/page_draw.gd` and the theme's rail arithmetic: the measurements a page lays out
## by. Tracked width is the plain width plus one gap per letter; a keycap has a floor; the rail's slot
## pitch has a floor that beats the cap, and the first slot never crosses the edge.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_page_draw.gd


func _initialize() -> void:
	_test_tracked_and_keycap_arithmetic()
	_test_the_rail_slots()
	_finish("page_draw")


func _test_tracked_and_keycap_arithmetic() -> void:
	var font: Font = ThemeDB.fallback_font
	var plain: float = font.get_string_size("SETTINGS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_check(is_equal_approx(PageDraw.tracked_width(font, "SETTINGS", 15, 2.8), plain + 2.8 * 7.0), "eight letters carry seven gaps")
	_check(is_equal_approx(PageDraw.tracked_width(font, "A", 15, 2.8), font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x), "one letter carries none")
	_check(PageDraw.keycap_width(font, "1", 8) == PageDraw.KEYCAP_MIN_W, "a single digit's cap is the square-ish floor")
	_check(PageDraw.keycap_width(font, "SPACE", 8) > PageDraw.KEYCAP_MIN_W and is_equal_approx(PageDraw.keycap_height(8), 8.0 + PageDraw.KEYCAP_PAD_Y), "a word's cap is wider, and the height is the type plus its pad")
	_check(PageDraw.FOCUS_W == 2.0, "the focus ring is double the weight of every 1 px edge")


func _test_the_rail_slots() -> void:
	var font: Font = ThemeDB.fallback_font
	var slot_h: float = UiTheme.rail_word_slot_h(font)
	var short: Array = UiTheme.rail_slots(Rect2(0.0, 0.0, 56.0, 186.0), 3, slot_h + UiTheme.RAIL_SLOT_AIR, slot_h)
	_check(short.size() == 3 and float(short[1]) - float(short[0]) >= slot_h + UiTheme.RAIL_SLOT_AIR - 0.01, "on a short rail the pitch holds its floor so the tiles never meet (%.1f)" % (float(short[1]) - float(short[0])))
	var tall: Array = UiTheme.rail_slots(Rect2(0.0, 0.0, 56.0, 400.0), 3, slot_h + UiTheme.RAIL_SLOT_AIR, slot_h)
	_check(float(tall[1]) - float(tall[0]) <= UiTheme.RAIL_PITCH_MAX + 0.01, "on a tall rail the pitch is capped (%.1f)" % (float(tall[1]) - float(tall[0])))
	_check(float(tall[0]) >= UiTheme.RAIL_EDGE and float(short[0]) >= UiTheme.RAIL_EDGE, "the first slot never crosses the edge margin")
	_check(is_equal_approx(UiTheme.rail_word_dy(font), UiTheme.RAIL_ICON + font.get_ascent(UiTheme.RAIL_LABEL_FS) + UiTheme.RAIL_TEXT_AIR), "the word's baseline is the tile plus the ascent plus air")
