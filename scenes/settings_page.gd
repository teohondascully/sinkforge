class_name SettingsPage
extends RefCounted

## WHAT THE SETTINGS PAGE SHOWS, WHICH IS NOT THE SAME QUESTION AS WHAT THE SETTINGS ARE.
##
## `Settings` owns the values and their persistence: the volumes, the toggles, the bindings, the file.
## This owns the PAGE: which rows exist, in which category, in what order, what sentence each one carries,
## and where the keyboard cursor goes next. Those are different concerns and they change for different
## reasons. Adding a row here is a page edit; adding a setting there is a save-format edit.
##
## The file has two halves and the split is the point. ABOVE the drawing banner, everything is data or a
## pure function of (category, row): nothing there draws, reads a node, or holds state, so the cursor
## rules -- the part of the page most likely to be wrong and least able to be seen in a screenshot -- stay
## reachable without a running game. BELOW it, the page draws itself, holding a canvas, a font, the layout
## probe and its own display state.
##
## Adding a row, a category or a cursor rule belongs above and must stay callable from a headless test.
## Adding a pixel belongs below. The halves are not enforced by anything but this note, so the note is
## the enforcement: a static function that reaches for `_canvas` has crossed the line.
##
## The cursor field now lives here too, with the rest of the page's state; `Hud` keeps a property of the
## same name forwarding to it, because `scenes/main.gd` and three tools have always read it there.

const CAT_AUDIO: int = 0
const CAT_CONTROLS: int = 1
const CAT_FEEL: int = 2
const CAT_NAMES: Array[String] = ["AUDIO", "CONTROLS", "FEEL"]

## The bindings, each with the sentence its key does not tell you. A key legend that says what the key
## is for is a different document from one that says which key it is. The rows that say nothing here are
## the ones whose label already said it, such as "jump" and "map", and an empty string draws no plate
## rather than a padded restatement of the label.
const REMAP_ROWS: Array[Array] = [
	[Controls.LEFT, "move left", ""], [Controls.RIGHT, "move right", ""],
	[Controls.UP, "climb up", "ladders, ropes and lift shafts"],
	[Controls.DOWN, "climb down", ""],
	[Controls.JUMP, "jump", ""],
	[Controls.MINE, "mine (hold)", "hold on rock; the pickaxe decides what breaks"],
	[Controls.GRAPPLE, "grapple",
		"throw a line at what you are aiming at — it takes your weight, and pays out as you fall"],
	[Controls.BUILD, "build / place", "puts the held thing where you are aiming"],
	[Controls.DROP, "drop / feed", "into a machine's mouth if one is there"],
	[Controls.CRAFT, "pack", "the counter: what you carry, what you can build"],
	[Controls.RESEARCH, "research / config", ""],
	[Controls.MAP, "map", "press twice for the whole world"],
	[Controls.TECH, "tech tree", ""],
	[Controls.MUTE, "mute sound", ""],
	[Controls.DASHBOARD, "dashboard", ""], [Controls.HELP, "help", ""],
	[Controls.PAUSE, "pause", ""],
	[Controls.SPEED, "game speed", ""], [Controls.ZOOM, "zoom", ""],
	[Controls.SAVE, "quicksave", ""], [Controls.LOAD, "quickload", ""],
	[Controls.CLEAR_MARKS, "clear dig plan", ""],
]


## An action's human name, from the same table the page draws. It is static because `MainView` needs it
## to say which binding a rebind just took the key from, and a second copy of these names would be a
## second place for them to go stale.
static func action_label(action: StringName) -> String:
	for row: Array in REMAP_ROWS:
		if row[0] == action:
			return str(row[1])
	return String(action)

## The audio levels and the feel toggles as data, so the drawing is one loop over a table and the detail
## plate has somewhere to read its sentence from.
const AUDIO_ROWS: Array[Array] = [
	["master", "master", "everything, including the ambience bed"],
	["effects", "sound", "picks, impacts, machines — the things you cause"],
	["ambience", "ambience", "the layer's own voice: water, wind, the deep hum"],
	["music", "music", ""],
]
const FEEL_ROWS: Array[Array] = [
	["screen shake", "shake", "impacts and blasts kick the camera"],
	["zoom", "zoom", "how much of the shaft you can see at once"],
	["auto-pickup", "auto_pickup", "walk over a dropped thing to take it"],
]


## Rows per binding column and the single source for the split. `Hud._settings_wanted_h` asks this rather
## than re-deriving it, because a height computed from a second copy of a layout rule is right on the day
## it is written and silently wrong the day either copy moves.
static func remap_per_col() -> int:
	return int(ceil(float(REMAP_ROWS.size()) * 0.5))


## How many controls a category offers the keyboard cursor.
##
## CONTROLS is the bindings plus RESET KEYS, which sits at the end of the list rather than being a fourth
## thing with its own key: it is drawn on the detail plate under the two columns, so arriving at it by
## pressing Down off the bottom of the second column is where it already sits on the page.
##
## AUDIO is the mute chip and then the levels, in that order, which is why the levels are offset by one.
static func focus_count(cat: int) -> int:
	match cat:
		CAT_CONTROLS: return REMAP_ROWS.size() + 1
		CAT_FEEL: return FEEL_ROWS.size()
		_: return AUDIO_ROWS.size() + 1


## What one row of a category does, as the payload the click path already speaks.
##
## The keyboard and the mouse produce the same dictionary, deliberately, and this is the only place either
## of them gets it from. The page registers these as its hit payloads and returns this for the focused row,
## so `MainView._apply_setting` is one mutation path for both pointers rather than two that have to be kept
## agreeing. The page has already paid once for a page-side copy of a rule drifting from the resolver's.
##
## Every branch clamps rather than trusting the index. A payload built from an out-of-range row is a
## mutation aimed at nothing, and the caller cannot tell that from a mutation aimed at something.
static func row_payload(cat: int, i: int) -> Dictionary:
	match cat:
		CAT_CONTROLS:
			if i < 0 or i >= REMAP_ROWS.size():
				return {"reset": true}
			return {"bind": String(REMAP_ROWS[i][0])}
		CAT_FEEL:
			var f: int = clampi(i, 0, FEEL_ROWS.size() - 1)
			var fid: String = str(FEEL_ROWS[f][1])
			return {"cycle": "zoom"} if fid == "zoom" else {"toggle": fid}
		_:
			if i <= 0:
				return {"toggle": "mute"}
			return {"slider": str(AUDIO_ROWS[clampi(i - 1, 0, AUDIO_ROWS.size() - 1)][1])}


## Where the keyboard cursor goes next. Up and Down step within a column, while Left and Right jump a
## column, which is what the two-column layout makes them mean. It is clamped rather than wrapped, because
## a cursor that leaps from the last row to the first reads as a lost keypress.
##
## The column jump is the one thing that stays category-shaped. AUDIO and FEEL are single columns, so there
## is no column to jump to and the step is 0. `MainView` reads Left and Right on those faces as an
## adjustment to the focused control instead, and only falls back here when the control has nothing to
## adjust. One rule, and it never has to guess: a slider and a cycle move, everything else steps.
##
## Returns the new row rather than mutating, so the rule can be checked without a page to hold the cursor.
static func next_row(cat: int, row: int, keycode: int) -> int:
	var step: int = remap_per_col() if cat == CAT_CONTROLS else 0
	var out: int = row
	match keycode:
		KEY_UP: out -= 1
		KEY_DOWN: out += 1
		KEY_LEFT: out -= step
		KEY_RIGHT: out += step
	return clampi(out, 0, focus_count(cat) - 1)


## The action under the cursor, or &"" when the cursor is not on a binding. That also covers the last
## CONTROLS index, RESET KEYS, since that is a control and not a binding. The guard is written as a range
## test rather than a category test, which is why it held the day the list grew a tail.
static func row_action(cat: int, row: int) -> StringName:
	if cat != CAT_CONTROLS or row < 0 or row >= REMAP_ROWS.size():
		return &""
	return REMAP_ROWS[row][0]


## A category index that exists. Named separately from the page's own setter because the clamp is a
## property of the catalog, not of the page holding the field.
static func clamp_cat(cat: int) -> int:
	return clampi(cat, 0, CAT_NAMES.size() - 1)


## ---- THE PAGE'S OWN MEASUREMENTS ----
##
## These are the settings page's, not the counter's. What the two genuinely share (the rail width, the
## plate's inner air, the canvas) lives in `UiTheme`; what only this page uses lives here, so a change to
## one page cannot silently resize the other.

## The settings page, which takes the counter's grammar and keeps its own state.
##
## It shares the counter's plate, rail, head, detail plate and sizing behaviour, while `_settings_open`
## and ESC stay its own. It is not the counter's fourth face, and the reason lives in the input handlers
## rather than in proximity. `main.gd:1006` routes every event to `_settings_input` and returns. That
## total intercept is what key capture requires, because it must be able to swallow any key, while the
## counter binds the digit row and the mouse wheel to tab selection. A binding capture cannot live
## inside a tab strip. The other reason once recorded, that the counter is a place with a precondition,
## is not true: `E` sets `_inventory_open` with no proximity check, and `_near_bazaar()` gates exactly
## one field.
##
## The grid. The old page put slider bars at x0+62 and chips at x0+92: two control columns in one stack,
## 30px apart. There is now one label x, one control x and one value x.
##
## The height. The old page was a fixed 592x286 whatever it was showing. One category at a time on a
## panel that sizes to it makes FEEL barely half the height of CONTROLS.
const SET_W: float = 432.0
const SET_HEAD: float = 40.0          ## title + category name
const SET_FOOT: float = 16.0          ## the key legend
## The plate that says what the control under your hand does. It was 56, tall enough for three lines and
## never given more than one, because the CONTROLS face is the only one that puts anything else in it, and
## that is a single RESET KEYS button on the same baseline. 36 holds both with room and takes 20px off
## every page height, which is 20px less of the banner above and the hotbar below that this panel prints
## over: the settings footprint measured 47.22% of canvas, down from 50.97%.
const SET_DETAIL: float = 36.0
const SET_ROW: float = 22.0           ## an audio/feel row
const SET_MIN_H: float = 196.0
## The shared grid, measured from the content's left edge. It is named because a layout assertion that
## re-derives them is checking its own arithmetic against itself.
const SET_CTRL_DX: float = 116.0
const SET_BAR_W: float = 116.0
const SET_VALUE_DX: float = 242.0     ## SET_CTRL_DX + SET_BAR_W + 10
const REMAP_ROW_H: float = 15.0
const REMAP_GAP: float = 16.0


## What each category says when your hand is not on anything: the page describing itself rather than
## sitting blank, which is the state it is in most of the time it is open.
const CATEGORY_LINE: Array[String] = [
	"levels are remembered while muted",
	"click a binding, then press its new key",
	"how the game moves and what it does for you",
]


# ------------------------------------------------------------------------------------------------
# THE PAGE AS IT IS DRAWN.
#
# Everything above this line is data and pure functions, and it stays that way. What follows is the
# page rendering itself, moved off `Hud` whole: twenty-six functions that between them reached for
# nothing of the Hud except a canvas to draw on, a font to measure with, and the layout probe.
#
# Those three are held as fields rather than threaded through as arguments. Twenty-six functions
# passing `(canvas, font, probe)` on every hop is the parameter-heavy shape this extraction exists
# to avoid; the page owns a canvas for as long as it is drawing on one.
#
# `Hud` re-binds them on entry to each forwarded call, so a `probing` flag a fixture flips between
# frames cannot be observed stale here.

var _canvas: CanvasItem = null              ## the Hud, as something to draw on and nothing more
var _font: Font = ThemeDB.fallback_font
var probing: bool = false                   ## mirrored from Hud; see its `panel_probe` note
var panel_probe: Array[Rect2] = []          ## THE SAME array object Hud holds, shared by reference

var settings_cat: int = CAT_AUDIO           ## which face of the page is open (the rail's selection)
var settings_row: int = 0                   ## the keyboard cursor on the binding list
var settings_capture: StringName = &""      ## the action awaiting its new key ("press a key…")
var _settings_hits: Array[Dictionary] = []  ## clickable controls this frame: [{rect, payload}]
var _slider_rects: Dictionary = {}          ## slider id -> its bar Rect2 this frame (drag support)
var _set_h: float = SET_MIN_H               ## eased toward `_settings_wanted_h()`, like the counter
var _set_t: float = 0.0                     ## the page's own rise, 0..1; drives the scrim and defocus


## The drawing primitives, mirrored rather than reached for. Each is the body `Hud` had with `self`
## replaced by the canvas this page was handed. They are private because they are not this page's
## interface -- `Visuals` is -- and they exist only to spare every call site two extra arguments.

func _round_rect(rect: Rect2, r: float, col: Color) -> void:
	# The probe entry travels with the drawing. `check_hud_layout` reads `panel_probe` off the Hud
	# and still sees every settings panel, because the array here IS the Hud's array. Dropping this
	# would have left the page silently unmeasured -- the same transitive reach that made the rail
	# constants look settings-specific when the bazaar was using every one of them.
	if probing:
		panel_probe.append(rect)
	Visuals.round_rect(_canvas, rect, r, col)


func _round_rect_left(rect: Rect2, r: float, col: Color) -> void:
	Visuals.round_rect_left(_canvas, rect, r, col)


func _panel_sheen(rect: Rect2) -> void:
	Visuals.panel_sheen(_canvas, rect)


func _soft_shadow(rect: Rect2, spread: int, peak: float) -> void:
	Visuals.soft_shadow(_canvas, rect, spread, peak)


func _tracked(text: String, at: Vector2, size: int, track: float, col: Color) -> void:
	Visuals.tracked(_canvas, _font, text, at, size, track, col)


func _tracked_w(text: String, size: int, track: float) -> float:
	return Visuals.tracked_width(_font, text, size, track)


func _focus_ring(box: Rect2, grow: float = Visuals.FOCUS_GROW, spine: bool = false) -> void:
	Visuals.focus_ring(_canvas, box, UiTheme.GOLD_PALE, UiTheme.UI_ACCENT, grow, spine)


func _bazaar_vignette(peak: float) -> void:
	Visuals.edge_vignette(_canvas, UiTheme.CANVAS, peak)


func _keycap(at: Vector2, key: String, fs: int = 8) -> float:
	return Visuals.keycap(_canvas, _font, at, key, fs, panel_probe if probing else [])


func _keycap_w(key: String, fs: int) -> float:
	return Visuals.keycap_width(_font, key, fs)


func _rail_slots(rail: Rect2, n: int, min_pitch: float, slot_h: float) -> Array:
	return UiTheme.rail_slots(rail, n, min_pitch, slot_h)


func _rail_word_slot_h() -> float:
	return UiTheme.rail_word_slot_h(_font)


func _rail_word_dy() -> float:
	return UiTheme.rail_word_dy(_font)


func _rail_key_dy() -> float:
	return UiTheme.rail_key_dy(_font)


func _rail_key_slot_h() -> float:
	return UiTheme.rail_key_slot_h(_font)


func _settings_geometry() -> Dictionary:
	var h: float = _set_h
	var origin := Vector2((UiTheme.CANVAS.x - SET_W) * 0.5, (UiTheme.CANVAS.y - h) * 0.5)
	var inner_x: float = origin.x + UiTheme.BAZAAR_RAIL + UiTheme.BAZAAR_PAD
	var inner_w: float = SET_W - UiTheme.BAZAAR_RAIL - UiTheme.BAZAAR_PAD * 2.0
	var body_h: float = h - SET_HEAD - SET_FOOT
	var content := Rect2(inner_x, origin.y + SET_HEAD, inner_w, body_h - SET_DETAIL - 8.0)
	return {
		"origin": origin, "w": SET_W, "h": h, "content": content,
		"detail": Rect2(inner_x, content.end.y + 8.0, inner_w, SET_DETAIL),
		"col_w": (inner_w - REMAP_GAP) * 0.5,
	}


## How tall the page wants to be for the category that is open. Every term is taken from the function
## that draws it. See `_bazaar_wanted_h`.
func _settings_wanted_h() -> float:
	var need: float = 0.0
	match settings_cat:
		CAT_CONTROLS:
			need = float(_remap_per_col()) * REMAP_ROW_H + 8.0
		CAT_FEEL:
			need = float(FEEL_ROWS.size()) * SET_ROW
		_:
			need = float(AUDIO_ROWS.size() + 1) * SET_ROW    # the levels, plus the mute above them
	return maxf(SET_HEAD + need + 8.0 + SET_DETAIL + SET_FOOT, SET_MIN_H)


## Rows per binding column and the single source for the split. `_settings_wanted_h` asks this rather
## than re-deriving it, because a height computed from a second copy of a layout rule is right on the
## day it is written and silently wrong the day either copy moves.
func _remap_per_col() -> int:
	return SettingsPage.remap_per_col()


func _draw_settings_overlay() -> void:
	_settings_hits.clear()
	_slider_rects.clear()
	# The counter's ground rather than the old page's: a tinted scrim instead of pure black, because a
	# modal that blacks the world out reads as a different application, while one that tints it reads as a
	# screen you are on.
	var t: float = settings_ease()
	_canvas.draw_rect(Rect2(Vector2.ZERO, UiTheme.CANVAS), Color(0.02, 0.025, 0.04, 0.42 * t))
	_bazaar_vignette(0.5 * t)
	var g: Dictionary = _settings_geometry()
	var origin: Vector2 = g["origin"]
	var mouse: Vector2 = Controls.pointer_viewport(_canvas)
	var plate := Rect2(origin, Vector2(SET_W, float(g["h"])))
	# The page rises the last few pixels into place, one transform, exactly as the counter does.
	_canvas.draw_set_transform(Vector2(0.0, (1.0 - t) * 14.0), 0.0, Vector2.ONE)
	# Elevation, not a border. The old page was a hard-cornered rectangle with a 1px edge, while the
	# counter earned its depth from a soft shadow and a sheen, and this page gets the same two.
	_soft_shadow(plate, 12, 0.34)
	# Opaque, and the comment that earned it stays. `UiTheme.UI_BG` is 90% because furniture sits over the world
	# and is meant to, while a modal is not furniture: at 0.90 the objective banner read straight through
	# this page, since ten percent of a lit banner over an unlit panel is about twice the panel's value.
	_round_rect(plate, 8.0, UiTheme.UI_MODAL)
	_panel_sheen(plate)
	_draw_settings_rail(origin, g, mouse)
	_draw_settings_head(origin, g)
	# The plate follows the mouse, so whatever control is under your hand explains itself. With nothing
	# under it, it falls back to the category's own line, so the plate is never blank and never stale.
	var told: String = _settings_body(g, mouse)
	_draw_settings_detail(g, told, mouse)
	# What the keyboard can do here, said on the page rather than left to be found. The line named 1 2 3
	# and ESC because those were the only two keys true of the whole page: the arrows moved a cursor on one
	# of the three faces and every other control was mouse-only. They are true of all three now, and a
	# control you can focus but cannot discover is the same defect one step further in, on the page a
	# player opens precisely when their input is not doing what they expect.
	var legend: String = "arrows move   ENTER rebinds   1 2 3 category   ESC closes" \
		if settings_cat == CAT_CONTROLS \
		else "arrows move and adjust   ENTER acts   1 2 3 category   ESC closes"
	_canvas.draw_string(_font, Vector2(origin.x + UiTheme.BAZAAR_RAIL + UiTheme.BAZAAR_PAD, origin.y + float(g["h"]) - 5.0),
		legend, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.UI_TEXT_FAINT)
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The category rail. It shares `_rail_slots` with the counter's rail so the two cannot drift apart and
## it registers a hit per category, since the rail is how you change page with the mouse.
func _draw_settings_rail(origin: Vector2, g: Dictionary, mouse: Vector2) -> void:
	var rail := Rect2(origin, Vector2(UiTheme.BAZAAR_RAIL, float(g["h"])))
	_round_rect_left(rail, 8.0, UiTheme.UI_RAIL)
	var ys: Array = _rail_slots(rail, CAT_NAMES.size(),
		_rail_word_slot_h() + UiTheme.RAIL_SLOT_AIR, _rail_word_slot_h())
	for i: int in CAT_NAMES.size():
		var y: float = ys[i]
		var on: bool = i == settings_cat
		var box := Rect2(rail.position.x + 9.0, y, UiTheme.RAIL_ICON, UiTheme.RAIL_ICON)
		if on:
			_round_rect(box, 6.0, UiTheme.RAIL_ON_FILL)
			_canvas.draw_rect(Rect2(rail.position.x, y + 5.0, 2.5, 28.0), UiTheme.UI_ACCENT)
		_settings_glyph(box.get_center(), i, on, box.has_point(mouse))
		# The number travels inside the word. It used to be drawn separately above the icon while the word
		# sat below it, which put every word equidistant between the icon it names and the number of the
		# next one: 47px to its own icon against 46px to the wrong number on the shipped frames, and on
		# the shortest page they landed on one baseline and the rail printed "2 AUDIO" when 2 is CONTROLS.
		# One string cannot drift away from itself at any pitch.
		var label: String = "%d %s" % [i + 1, CAT_NAMES[i]]
		var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.RAIL_LABEL_FS).x
		_canvas.draw_string(_font, Vector2(box.get_center().x - lw * 0.5, y + UiTheme.RAIL_LABEL_DY), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.RAIL_LABEL_FS, UiTheme.UI_TEXT if on else UiTheme.UI_TEXT_FAINT)
		_settings_hits.append({"rect": box.grow(6.0), "payload": {"cat": i}})


## Three category glyphs, drawn rather than lettered, in the counter's hand: a speaker cone with two
## arcs, a key cap, and three sliders at different settings.
##
## `hot` is a separate argument from `on` because they are separate facts, and one call site's
## `on or box.has_point(mouse)` blurred them. Under a resting pointer the rail lit two glyphs in the
## selection gold at once, and the brighter-looking one was not the page you were on: hover is where the
## hand happens to be, while gold in this file says your input is connected to the thing. The counter's
## rail (`_rail_glyph`) never had the bug, since it passes `on` alone, and the two rails share their slot
## pitch, their fill and their labels, so the odd one out was this signature. Hover keeps a cue and takes
## it out of the gold family: `UiTheme.UI_TEXT_DIM` is one clear value step over the unlit glyph, 6.42:1 on the
## rail against the unlit 3.82, and nowhere near the 13.60:1 of the lit one.
func _settings_glyph(at: Vector2, kind: int, on: bool, hot: bool = false) -> void:
	var col: Color = UiTheme.GOLD_PALE if on else (UiTheme.UI_TEXT_DIM if hot else Color(0.40, 0.43, 0.50))
	match kind:
		CAT_AUDIO:
			_canvas.draw_rect(Rect2(at + Vector2(-8.0, -3.0), Vector2(4.0, 6.0)), col)
			var pts := PackedVector2Array([at + Vector2(-4.0, -1.0), at + Vector2(1.0, -7.0),
				at + Vector2(1.0, 7.0), at + Vector2(-4.0, 1.0)])
			_canvas.draw_colored_polygon(pts, col)
			_canvas.draw_arc(at + Vector2(1.0, 0.0), 5.5, -PI * 0.4, PI * 0.4, 8, col, 1.4)
			_canvas.draw_arc(at + Vector2(1.0, 0.0), 8.5, -PI * 0.4, PI * 0.4, 8, col, 1.4)
		CAT_CONTROLS:
			_canvas.draw_rect(Rect2(at + Vector2(-8.0, -6.0), Vector2(16.0, 13.0)), Color(col, 0.35))
			_canvas.draw_rect(Rect2(at + Vector2(-8.0, -6.0), Vector2(16.0, 13.0)), col, false, 1.4)
			_canvas.draw_rect(Rect2(at + Vector2(-3.0, -2.0), Vector2(6.0, 5.0)), col)
		_:
			for i: int in 3:
				var y: float = at.y - 6.0 + float(i) * 6.0
				_canvas.draw_rect(Rect2(at.x - 9.0, y - 0.7, 18.0, 1.6), Color(col, 0.45))
				_canvas.draw_rect(Rect2(at.x - 9.0 + float(3 - i) * 4.5, y - 3.0, 2.6, 6.0), col)


## The head: what page this is and which face of it you are on. The counter's title pair exactly.
func _draw_settings_head(origin: Vector2, g: Dictionary) -> void:
	var x: float = origin.x + UiTheme.BAZAAR_RAIL + UiTheme.BAZAAR_PAD
	# The identifying word carries the contrast. This pair was the other way round, with `SETTINGS` at
	# 12.6:1 and the category at 2.0:1, so the brightest text on the page was the word that is the same on
	# all three faces and the dimmest was the only one saying which face you are looking at. A blind read
	# called it the most damaging defect on the screen: it fails at telling you what it is.
	_tracked("SETTINGS", Vector2(x, origin.y + 26.0), 15, 2.8, UiTheme.UI_TEXT_FAINT)
	_tracked(CAT_NAMES[settings_cat],
		Vector2(x + _tracked_w("SETTINGS", 15, 2.8) + 16.0, origin.y + 26.0), 15, 2.8, UiTheme.UI_TEXT)


## The open category, returning the sentence the detail plate should say, which is whatever the mouse is
## over. Returning it rather than storing it keeps the plate's content derived from the same pass that
## decided what was under the cursor.
func _settings_body(g: Dictionary, mouse: Vector2) -> String:
	var c: Rect2 = g["content"]
	match settings_cat:
		CAT_CONTROLS:
			return _settings_controls(g, c, mouse)
		CAT_FEEL:
			return _settings_feel(c, mouse)
		_:
			return _settings_audio(c, mouse)


## The plate follows the hand, and then the caret. `said` was set by hover alone, which is correct while
## the mouse is on the page and leaves the plate saying the category's own line for a keyboard user
## standing on a control that has a sentence written for it. The order is the one `_settings_controls`
## already argued for and had to be corrected into: hover first and unconditionally, because it is the
## more deliberate pointer, and focus fills in when nothing is hovered.
func _settings_audio(c: Rect2, mouse: Vector2) -> String:
	var said: String = ""
	var y: float = c.position.y + 14.0
	_canvas.draw_string(_font, Vector2(c.position.x, y), "sound", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiTheme.UI_TEXT)
	# The mute reads as its state and never as an instruction, because a chip that says the opposite of
	# what is happening is the oldest bug in settings UI.
	#
	# The focus arm needs no `said == ""` beside it, unlike the rows below. This is the first control the
	# category draws, so nothing can have spoken yet and a test for it would be a guard that cannot be
	# false, which is the exact shape the rest of this function's history is a catalogue of.
	var mute_focused: bool = settings_row == 0
	if _settings_chip(c.position.x + SET_CTRL_DX, y, "MUTED" if Settings.muted else "SOUND ON",
			settings_row_payload(CAT_AUDIO, 0), not Settings.muted, mouse, 10, Settings.muted,
			mute_focused) or mute_focused:
		said = "silences everything at once; the levels below are kept"
	for i: int in AUDIO_ROWS.size():
		var row: Array = AUDIO_ROWS[i]
		y += SET_ROW
		var id: String = str(row[1])
		var focused: bool = settings_row == i + 1
		if _settings_slider(c.position.x, y, id, str(row[0]), _audio_level(id), mouse, focused):
			said = str(row[2])
		elif focused and said == "":
			said = str(row[2])
	return said


func _settings_feel(c: Rect2, mouse: Vector2) -> String:
	var said: String = ""
	var y: float = c.position.y + 14.0
	for i: int in FEEL_ROWS.size():
		var row: Array = FEEL_ROWS[i]
		var id: String = str(row[1])
		_canvas.draw_string(_font, Vector2(c.position.x, y), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			UiTheme.UI_TEXT)
		var text: String = ""
		var on: bool = false
		if id == "zoom":
			text = "%.2fx" % MainView.ZOOM_LEVELS[
				clampi(Settings.zoom_idx, 0, MainView.ZOOM_LEVELS.size() - 1)]
		else:
			on = Settings.screen_shake if id == "shake" else Settings.auto_pickup
			text = "ON" if on else "OFF"
		var focused: bool = settings_row == i
		if _settings_chip(c.position.x + SET_CTRL_DX, y, text, settings_row_payload(CAT_FEEL, i), on,
				mouse, 10, false, focused) or (focused and said == ""):
			said = str(row[2])
		y += SET_ROW
	return said


## How many controls the open category offers the keyboard, which is the population `settings_row` is an
## index into. It was 22 and it was only ever the bindings, because the cursor existed for the binding
## list alone and every other control on this page was reachable by mouse only. That gap is what this
## closes: the levels, the toggles and RESET KEYS could not be focused at all, so there was nothing for a
## focus state to be drawn on.
##
## RESET KEYS is part of the controls list, at its end, rather than a fourth thing with its own key. It
## is drawn on the detail plate under the two columns, so arriving at it by pressing Down off the bottom
## of the second column is where it already sits on the page.
func settings_focus_count() -> int:
	return SettingsPage.focus_count(settings_cat)


## What one row of a category does, as the payload the click path already speaks.
##
## The keyboard and the mouse produce the same dictionary, deliberately, and this is the only place
## either of them gets it from. `_settings_audio`, `_settings_feel` and `_settings_controls` register
## these as the hit payloads, and `settings_focus_payload` returns this for the focused row, so
## `MainView._apply_setting` is one mutation path for both pointers rather than two that have to be kept
## agreeing. The page has already paid once for a page-side copy of a rule drifting from the resolver's,
## in `_binding_clashes`.
func settings_row_payload(cat: int, i: int) -> Dictionary:
	return SettingsPage.row_payload(cat, i)


## The focused control's payload. `MainView` acts on this and never on the index, so what ENTER does is
## decided by the same table that decided what a click on the same control does.
func settings_focus_payload() -> Dictionary:
	return settings_row_payload(settings_cat, settings_row)


## Move the keyboard cursor. Up and Down step within a column, while Left and Right jump a column, which
## is what the two-column layout makes them mean. It is clamped rather than wrapped, because a cursor
## that leaps from the last row to the first reads as a lost keypress.
##
## It used to refuse every category but CONTROLS, in its first two lines, which is the mechanical form of
## the same gap: on AUDIO and FEEL the arrow keys did nothing at all, so the page a player opens when
## their input is not working had four levels and three toggles that only a mouse could reach.
##
## The column jump is the one thing that stays category-shaped. AUDIO and FEEL are single columns, so
## there is no column to jump to and the step is 0. `MainView` reads Left and Right on those faces as an
## adjustment to the focused control instead, and only falls back here when the control has nothing to
## adjust. One rule, and it never has to guess: a slider and a cycle move, everything else steps.
func move_settings_row(keycode: int) -> void:
	settings_row = SettingsPage.next_row(settings_cat, settings_row, keycode)


## The action under the keyboard cursor, or &"" when the cursor is not on a binding list. That now also
## covers the last CONTROLS index, RESET KEYS, since that is a control and not a binding. The guard was
## already written as a range test rather than a category test, so it held the day the list grew a tail.
func settings_row_action() -> StringName:
	return SettingsPage.row_action(settings_cat, settings_row)


## The bindings: two columns of eleven, each row a label and the key that does it. The capture state is
## on the row that is capturing, "press a key…", rather than in a sentence at the bottom of the page
## competing with the reset control.
func _settings_controls(g: Dictionary, c: Rect2, mouse: Vector2) -> String:
	var said: String = ""
	var per_col: int = _remap_per_col()
	var col_w: float = float(g["col_w"])
	var clashes: Dictionary = _binding_clashes()
	for i: int in REMAP_ROWS.size():
		var row: Array = REMAP_ROWS[i]
		var col: int = i / per_col
		var x: float = c.position.x + float(col) * (col_w + REMAP_GAP)
		var y: float = c.position.y + 12.0 + float(i % per_col) * REMAP_ROW_H
		var action: StringName = row[0]
		var capturing: bool = settings_capture == action
		var clash: Array = clashes.get(action, [])
		var text: String = "press a key…" if capturing else Settings.binding_label(action)
		var bw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 10.0
		var chip := Rect2(x + col_w - bw, y - 10.0, bw, 13.0)
		var lit: bool = chip.has_point(mouse)
		var cursor: bool = i == settings_row
		var plate := Rect2(x - 4.0, y - 11.0, col_w + 8.0, 15.0)
		if lit or capturing or cursor:
			# The whole row lights, not just the chip, because the row is the thing you are choosing, and
			# that is what makes the plate below it read as being about something.
			_round_rect(plate, 3.0, Color(0.145, 0.129, 0.082))
		# The keyboard cursor is not the hover and must not look like it. Hover is a warm fill under
		# whatever the mouse happens to be over, while focus is a claim about where the next keypress will
		# land, and it persists with no pointer anywhere near it. So focus gets the rail's own gold edge
		# bar, the mark this UI already uses for the selected one, and the two can coexist on different
		# rows without either being ambiguous.
		#
		# The spine is only half of that now. It was the whole mark while the binding list was the only
		# thing on this page a keyboard could reach, and now that the levels, the toggles and RESET wear a
		# ring, a row that wore only a spine would be the one focused control on the page saying it
		# differently. The ring goes on the row's own plate edge rather than outside it, since these rows
		# are drawn on a 15px pitch with 15px plates and there is no outside to draw in. The spine stays,
		# because it is the counter's mark for a cursor sitting on a row and this is one.
		if cursor:
			_focus_ring(plate, 0.0, true)
		# The mouse wins when it is on a row, because it is the more deliberate pointer, and the keyboard
		# cursor speaks when nothing is hovered, so the plate always describes the thing that would act.
		#
		# That sentence was here while the code did the opposite. The whole block sat under `if cursor:`,
		# so `said` was set only for the row the keyboard cursor was parked on, and hovering a row with
		# the mouse produced no plate text at all, which made the clash message unreachable by mouse.
		#
		# `lit` is checked first and unconditionally, and `cursor` fills in when nothing is hovered. The
		# old `elif lit or said == "":` could not be false either, since exactly one row is the cursor row
		# and `said` is still empty when it is reached.
		if lit or (cursor and said == ""):
			if capturing:
				said = "press any key to bind it — ESC cancels"
			elif not clash.is_empty():
				said = " and ".join(clash)
			else:
				said = str(row[2]) if str(row[2]) != "" else "%s — press Enter to rebind" % str(row[1])
		_canvas.draw_string(_font, Vector2(x, y), str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			UiTheme.UI_TEXT if (lit or capturing) else UiTheme.UI_TEXT_DIM)
		# A clashing key is not a selected one, so it does not get the gold. It gets the warn colour the
		# stalled-machine alerts use, which is the only other thing in this UI meaning "this will not do what
		# you think". Dark type on both, because light grey on either is unreadable.
		var fill: Color = UiTheme.UI_ACCENT if capturing else (
			UiTheme.UI_WARN if not clash.is_empty() else (Color(0.30, 0.34, 0.44) if lit else UiTheme.UI_SLOT))
		_canvas.draw_rect(chip, fill)
		_canvas.draw_rect(chip, Color(0.0, 0.0, 0.0, 0.5), false, 1.0)
		_canvas.draw_string(_font, Vector2(chip.position.x + 5.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.10, 0.10, 0.12) if (capturing or not clash.is_empty()) else UiTheme.UI_TEXT)
		_settings_hits.append({"rect": chip, "payload": settings_row_payload(CAT_CONTROLS, i)})
	# The tail of the list is RESET KEYS, which is drawn on the detail plate below and therefore cannot
	# describe itself the way a row does, since the plate is written before the chip on it is. Its sentence
	# is said here where the rest of the category's are, so a caret parked on it is not sitting over the
	# page's generic line with no idea what ENTER is about to do to twenty-two bindings.
	if settings_row >= REMAP_ROWS.size() and said == "":
		said = "puts every binding back to its default"
	return said


## The detail plate. The counter's answer to twenty-two rows of equal weight was to make the selected
## thing large, say what it is for, and put the verb on a real button. A key binding wants that more
## than a machine does, because the row `grapple  F` tells a first-timer nothing whatever.
func _draw_settings_detail(g: Dictionary, said: String, mouse: Vector2) -> void:
	var d: Rect2 = g["detail"]
	_round_rect(d, 5.0, Color(0.0, 0.0, 0.0, 0.22))
	var line: String = said
	if line == "":
		line = CATEGORY_LINE[settings_cat]
	# Wrapped by hand at the plate's width, since `draw_string` will not wrap, and a sentence that runs off
	# a plate is the defect this page was opened to fix.
	var y: float = d.position.y + 20.0
	for part: String in _wrap(line, d.size.x - 24.0, 10):
		_canvas.draw_string(_font, Vector2(d.position.x + 12.0, y), part, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			UiTheme.UI_TEXT if said != "" else UiTheme.UI_TEXT_FAINT)
		y += 13.0
	if settings_cat == CAT_CONTROLS:
		var w: float = _font.get_string_size("RESET KEYS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 14.0
		_settings_chip(d.end.x - w, d.end.y - 8.0, "RESET KEYS",
			settings_row_payload(CAT_CONTROLS, REMAP_ROWS.size()), false, mouse, 9, false,
			settings_row >= REMAP_ROWS.size())


## One level, with its label, bar and percentage all on the shared grid. It returns whether the mouse is
## on it so the caller can hand its sentence to the detail plate.
##
## `focused` is the keyboard's claim on it, a third state beside `hot` and the level itself. The bar
## already had two hover marks, a lifted frame and a pale cap, and neither of them can say that the next
## keypress moves this particular level. Hover is wherever the hand happens to be resting and vanishes
## when it leaves, while focus persists with no pointer on the page at all.
func _settings_slider(x0: float, y: float, id: String, label: String, value: float,
		mouse: Vector2, focused: bool = false) -> bool:
	var bar := Rect2(x0 + SET_CTRL_DX, y - 9.0, SET_BAR_W, 10.0)
	_slider_rects[id] = bar
	var hot: bool = bar.grow(4.0).has_point(mouse)
	# Dimmed while muted. The levels are still yours and still remembered, but nothing they say is audible,
	# and a bright slider over a silent game is the page lying about which control is in charge.
	_canvas.draw_string(_font, Vector2(x0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		UiTheme.UI_TEXT_DIM if Settings.muted else UiTheme.UI_TEXT)
	_canvas.draw_rect(bar, Color(0.0, 0.0, 0.0, 0.5))
	var fill := Rect2(bar.position, Vector2(bar.size.x * clampf(value, 0.0, 1.0), bar.size.y))
	_canvas.draw_rect(fill, Color(UiTheme.UI_ACCENT, 0.55) if Settings.muted else UiTheme.UI_ACCENT)
	# The travelled end gets a bright cap rather than the bar getting brighter, because a long gold fill
	# reads as a progress meter and a meter is a thing you watch rather than a thing you drag.
	#
	# Frame first, then the handle. Drawn the other way round the frame overprints the handle where it
	# crosses the bar, and a cap standing 2px proud top and bottom renders as three disconnected pieces: a
	# nub, a sliver, a nub. That reads as a rendering fault rather than as something to drag.
	_canvas.draw_rect(bar, UiTheme.UI_EDGE_HI if hot else UiTheme.UI_EDGE, false, 1.0)
	if value > 0.0:
		_canvas.draw_rect(Rect2(fill.end.x - 2.0, bar.position.y - 2.0, 2.5, bar.size.y + 4.0),
			UiTheme.GOLD_PALE if hot else Color(0.80, 0.83, 0.89))
	_canvas.draw_string(_font, Vector2(x0 + SET_VALUE_DX, y), "%d%%" % int(round(value * 100.0)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiTheme.UI_TEXT if (hot or focused) else UiTheme.UI_TEXT_DIM)
	# Outside the cap as well as outside the bar. The travelled end stands 2px proud of the frame top and
	# bottom, so a ring at the default clearance would have crossed it and read as the rendering fault the
	# cap was reshaped to avoid. The extra 2px puts the ring clear of both.
	if focused:
		_focus_ring(bar.grow(2.0))
	_settings_hits.append({"rect": bar.grow(3.0), "payload": {"slider": id}})
	return hot


## One chip. It returns whether the mouse is on it, for the same reason the slider does.
##
## `warn` is a third state, and it exists because two were not enough. `UiTheme.UI_ACCENT` is spoken for one
## line from its definition, so a chip filled with it asserts that the thing it names is on. The mute
## chip passed `Settings.muted` as `active`, which lit the loudest element on the AUDIO page gold
## precisely when the audio was off. Flipping it to `not muted` alone would be wrong the other way,
## since muted would then read as merely unselected, and silence the player did not intend is worth
## noticing. Warm-on-dark says suppressed without claiming chosen.
##
## `focused` is a fourth state, orthogonal to the other three rather than another value of them. A chip
## can be on, hovered and focused at once and has to say all three. `active` fills it gold, `hot` lifts
## the unfilled fill and `warn` paints it warm-on-dark, all three of them changes to the chip's interior,
## while focus rings it from the outside, which is why the gold fill of an engaged toggle cannot swallow
## it. That separation is the point: if focus and selection drew the same mark, a keyboard user could not
## tell the toggle they are standing on from the toggle that is switched on.
func _settings_chip(x: float, y: float, text: String, payload: Dictionary, active: bool,
		mouse: Vector2, size: int = 10, warn: bool = false, focused: bool = false) -> bool:
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 12.0
	var chip := Rect2(x, y - 11.0, w, 15.0)
	var hot: bool = chip.has_point(mouse)
	if warn:
		_canvas.draw_rect(chip, Color(0.22, 0.15, 0.11))
		_canvas.draw_rect(chip, Color(0.86, 0.47, 0.31, 0.95 if hot else 0.75), false, 1.0)
		_canvas.draw_string(_font, Vector2(x + 6.0, y + 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(0.96, 0.64, 0.47))
	else:
		_canvas.draw_rect(chip, UiTheme.UI_ACCENT if active else (Color(0.30, 0.34, 0.44) if hot else UiTheme.UI_SLOT))
		_canvas.draw_rect(chip, Color(0.0, 0.0, 0.0, 0.5), false, 1.0)
		_canvas.draw_string(_font, Vector2(x + 6.0, y + 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(0.10, 0.10, 0.12) if active else UiTheme.UI_TEXT)
	if focused:
		_focus_ring(chip)
	_settings_hits.append({"rect": chip, "payload": payload})
	return hot


## Move to a category. It is named like `set_bazaar_tab` and for the same reason: the page owns which
## face it is showing and `main.gd` asks for a change rather than pushing the field every frame.
##
## The cursor comes with it. The three faces offer 5, 23 and 3 controls, so an index that was legal on
## CONTROLS is off the end of both the others, and an out-of-range cursor is not cosmetic here. It is a
## focus ring drawn on nothing, on the page whose whole job is saying where the keyboard is. Clamped
## rather than reset, so switching away and back on a short page leaves you near where you were.
func set_settings_cat(cat: int) -> void:
	settings_cat = SettingsPage.clamp_cat(cat)
	settings_row = clampi(settings_row, 0, settings_focus_count() - 1)


## The control payload under a canvas point, or {} for none. Sliders add the clicked fraction, so a
## single press already sets the value and a drag then refines it via `settings_slider_frac`.
func settings_click(canvas_pos: Vector2) -> Dictionary:
	for hit: Dictionary in _settings_hits:
		if (hit["rect"] as Rect2).has_point(canvas_pos):
			var payload: Dictionary = (hit["payload"] as Dictionary).duplicate()
			if payload.has("slider"):
				payload["frac"] = settings_slider_frac(str(payload["slider"]), canvas_pos.x)
			return payload
	return {}


## Fraction along a slider's bar for a canvas x, used by click and by drag alike, since MainView keeps
## updating through mouse motion while the button stays down, even if the cursor drifts off the bar.
func settings_slider_frac(id: String, canvas_x: float) -> float:
	var bar: Rect2 = _slider_rects.get(id, Rect2())
	if bar.size.x <= 0.0:
		return 0.0
	return clampf((canvas_x - bar.position.x) / bar.size.x, 0.0, 1.0)


## Named rather than fetched. `Settings` is a `class_name` of static vars, and a dynamic `get()` against
## one fails at runtime rather than at parse time, which is the wrong trade in a page four checks
## photograph.
##
## The match itself moved to `Settings` and this is the forwarder. Keyboard adjustment of a level has to
## read the level before it can move it, and that read happens in `MainView` where the mutation lives, so
## the alternative to one shared accessor was two copies of the same four names in two files, which is
## the shape of defect this page has already shipped once.
func _audio_level(id: String) -> float:
	return Settings.level(id)


## Which bindings share a key with another and who with.
##
## `Settings.rebind` writes the new key and returns; it has never checked for a conflict. Bind `jump` to
## `W` and `W` is now `climb up` and `jump`, both fire, and nothing anywhere says so. The page shows the
## clash rather than the rebind refusing it, because refusing would overrule a deliberate choice, and
## silently unbinding the other action would be worse than either.
##
## They are compared on the label, which is what the row displays, because a clash the page draws has to
## be a clash the page can show you. `unbound` and `?` are excluded, since two actions with no key are
## not in conflict and a naive equality would call them the loudest clash on the board.
## equality would have called them the loudest clash on the board.
func _binding_clashes() -> Dictionary:
	# The population is every event of every action and it used to be neither. It compared
	# `Settings.binding_label`, which is `events[0]`, across the 22 `REMAP_ROWS`. Most actions have two or
	# three events, so a collision on any event but the first was invisible: bind something to the up arrow
	# and it silently shares with `climb up`, whose first event is W. And `Settings.rebind` scans all 25 of
	# `Controls.defaults()`, so it can displace `close`, `cycle next` or `cycle prev`, none of which have a
	# row here.
	#
	# Detecting over all 25 while displaying on the 22 is deliberate. The page owns 22 rows, but a warning
	# naming an off-page action is still true and still actionable, and silence would not be.
	var by_key: Dictionary = {}
	for act: StringName in Controls.defaults():
		for label: String in Settings.event_labels(act):
			if label == "unbound" or label == "?":
				continue
			var seen: Array = by_key.get(label, [])
			seen.append(act)
			by_key[label] = seen
	# The phrase names the colliding key, not the row's chip. Once a clash can live on an action's second
	# event, "%s is also %s" filled in with `binding_label(action)` would point at the wrong key and the
	# row would turn orange over `A` while the collision was on the left arrow. The display and the fix
	# have to be about the same event, which is why both sides share one predicate.
	var out: Dictionary = {}
	for row: Array in REMAP_ROWS:
		var act: StringName = row[0]
		var said: Array = []
		for label: String in Settings.event_labels(act):
			for other_v: Variant in by_key.get(label, []):
				if StringName(other_v) != act:
					said.append("%s is also %s" % [label, action_label(StringName(other_v))])
		if not said.is_empty():
			out[act] = said
	return out


## Break a sentence to a pixel width. Words only; a plate this size never needs more.
func _wrap(text: String, width: float, size: int) -> Array:
	var out: Array = []
	var line: String = ""
	for word: String in text.split(" ", false):
		var probe: String = word if line == "" else line + " " + word
		if _font.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = probe
	if line != "":
		out.append(line)
	return out


## The settings page's rise, on the same curve. It is public because `MainView._update_defocus` racks
## the world out of focus behind it, and a modal that leaves the world sharp reads as a sticker.
func settings_ease() -> float:
	var u: float = 1.0 - _set_t
	return 1.0 - u * u * u
