class_name SettingsPage
extends RefCounted

## WHAT THE SETTINGS PAGE SHOWS, WHICH IS NOT THE SAME QUESTION AS WHAT THE SETTINGS ARE (A' step 6j,
## D0372). Legacy `scenes/settings_page.gd`'s split, kept: the shell's `Settings` owns the values and
## their persistence; this owns the PAGE -- which rows exist, in which category, in what order, what
## sentence each carries, and where the keyboard cursor goes next. ABOVE the drawing banner everything
## is data or a pure function of (category, row), reachable without a running game; the drawing is
## `SettingsDraw`. The view may not reach `shell/`, so the values arrive as a SNAPSHOT (`state`) the
## shell hands over each frame, and the page returns the same payload for a click and for ENTER, so the
## shell's one mutation path serves both pointers.
##
## Content re-authored: legacy's twenty-three bindings are this build's four actions; the audio levels
## and the feel toggles are the shell's own.

const CAT_AUDIO: int = 0
const CAT_CONTROLS: int = 1
const CAT_FEEL: int = 2
const CAT_GAME: int = 3
const CAT_NAMES: Array[String] = ["AUDIO", "CONTROLS", "FEEL", "GAME"]
## Rail display order: CONTROLS sits last on screen as a door opened by K, not as an equal tab.
const RAIL_ORDER: Array[int] = [CAT_AUDIO, CAT_FEEL, CAT_GAME, CAT_CONTROLS]

## The bindings, each with the sentence its key does not tell you; an empty sentence draws no plate.
const REMAP_ROWS: Array[Array] = [
	[Controls.LEFT, "move left", ""], [Controls.RIGHT, "move right", ""],
	[Controls.JUMP, "jump", ""],
	[Controls.MINE, "mine (hold)", "hold on rock; the pick decides what breaks"],
]
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
## The GAME face (D0396): the two doors a stranded player needs. Each row is [label, id, sentence]; the
## second press of NEW GAME is the one that acts, so a stray click cannot end a world.
const GAME_ROWS: Array[Array] = [
	["stranded", "surface", "back at the spawn, the line stowed; world and pack kept"],
	["start over", "new", "a fresh world from the seed; this save is replaced (press twice)"],
]
const CATEGORY_LINE: Array[String] = [
	"levels are remembered while muted",
	"click a binding, then press its new key",
	"how the game moves and what it does for you",
	"when the shaft has you: a way out, and a way to begin again",
]

## The page's own measurements, in the authoring canvas.
const SET_W: float = 432.0            ## CONTROLS: the one face wide enough for the two-column table
const SET_W_COMPACT: float = 296.0    ## AUDIO and FEEL
const SET_HEAD: float = 40.0
const SET_FOOT: float = 16.0
const SET_DETAIL: float = 36.0
const SET_ROW: float = 22.0
## The floor: four rail slots at the rail's own minimum pitch (`UiTheme.rail_slots`: the top edge, three
## pitches of tile + label + air, the last label, the edge) -- 196 fit three slots and clipped the fourth.
const SET_MIN_H: float = 236.0
const SET_CTRL_DX: float = 84.0
const SET_BAR_W: float = 78.0
const SET_VALUE_DX: float = 172.0     ## SET_CTRL_DX + SET_BAR_W + 10
const REMAP_ROW_H: float = 15.0
const REMAP_GAP: float = 16.0
const RISE_PER_S: float = 6.0         ## the plate's rise, seconds to full
const HEIGHT_EASE: float = 0.25       ## the plate's height follows the open face by this much a frame

var open: bool = false
var cat: int = CAT_AUDIO
var row: int = 0
var capture: StringName = &""         ## the action awaiting its new key ("press a key…")
var armed: String = ""                ## the GAME row whose first press was taken; the second acts
## The shell's snapshot: muted, levels {id: 0..1}, shake, auto_pickup, zoom_label, bindings {action:
## label}, event_labels {action: [labels]}, all_actions [action]. Empty until the shell fills it.
var state: Dictionary = {}
var _hits: Array[Dictionary] = []     ## clickable controls this frame: [{rect, payload}]
var _slider_rects: Dictionary = {}    ## slider id -> its bar Rect2 this frame (canvas px)
var _set_h: float = SET_MIN_H         ## authored px, eased toward wanted_h
var _set_t: float = 0.0               ## the rise, 0..1


static func action_label(action: StringName) -> String:
	for r: Array in REMAP_ROWS:
		if r[0] == action:
			return String(r[1])
	return String(action)


static func remap_per_col() -> int:
	return int(ceil(float(REMAP_ROWS.size()) * 0.5))


## How many controls a category offers the keyboard cursor: CONTROLS is the bindings plus RESET KEYS;
## AUDIO is the mute chip and then the levels, which is why the levels are offset by one.
static func focus_count(c: int) -> int:
	match c:
		CAT_CONTROLS: return REMAP_ROWS.size() + 1
		CAT_FEEL: return FEEL_ROWS.size()
		CAT_GAME: return GAME_ROWS.size()
		_: return AUDIO_ROWS.size() + 1


## What one row of a category does, as the payload the click path already speaks. Every branch clamps
## rather than trusting the index: a payload aimed at nothing is indistinguishable from one aimed at
## something.
static func row_payload(c: int, i: int) -> Dictionary:
	match c:
		CAT_CONTROLS:
			if i < 0 or i >= REMAP_ROWS.size():
				return {"reset": true}
			return {"bind": String(REMAP_ROWS[i][0])}
		CAT_FEEL:
			var f: int = clampi(i, 0, FEEL_ROWS.size() - 1)
			var fid: String = String(FEEL_ROWS[f][1])
			return {"cycle": "zoom"} if fid == "zoom" else {"toggle": fid}
		CAT_GAME:
			return {"game": String(GAME_ROWS[clampi(i, 0, GAME_ROWS.size() - 1)][1])}
		_:
			if i <= 0:
				return {"toggle": "mute"}
			return {"slider": String(AUDIO_ROWS[clampi(i - 1, 0, AUDIO_ROWS.size() - 1)][1])}


## Where the cursor goes next: Up and Down step within a column, Left and Right jump a column on the
## two-column face and are 0 elsewhere. Clamped rather than wrapped: a cursor that leaps from the last
## row to the first reads as a lost keypress.
static func next_row(c: int, r: int, keycode: int) -> int:
	var step: int = remap_per_col() if c == CAT_CONTROLS else 0
	var out: int = r
	match keycode:
		KEY_UP: out -= 1
		KEY_DOWN: out += 1
		KEY_LEFT: out -= step
		KEY_RIGHT: out += step
	return clampi(out, 0, focus_count(c) - 1)


## The action under the cursor, or `&""` off the binding list (RESET KEYS included).
static func row_action(c: int, r: int) -> StringName:
	if c != CAT_CONTROLS or r < 0 or r >= REMAP_ROWS.size():
		return &""
	return REMAP_ROWS[r][0]


static func clamp_cat(c: int) -> int:
	return clampi(c, 0, CAT_NAMES.size() - 1)


static func width_for(c: int) -> float:
	return SET_W if c == CAT_CONTROLS else SET_W_COMPACT


## How tall the page wants to be for the face that is open; every term is taken from what draws it.
static func wanted_h(c: int) -> float:
	var need: float = 0.0
	match c:
		CAT_CONTROLS: need = float(remap_per_col()) * REMAP_ROW_H + 8.0
		CAT_FEEL: need = float(FEEL_ROWS.size()) * SET_ROW
		CAT_GAME: need = float(GAME_ROWS.size()) * SET_ROW
		_: need = float(AUDIO_ROWS.size() + 1) * SET_ROW
	return maxf(SET_HEAD + need + 8.0 + SET_DETAIL + SET_FOOT, SET_MIN_H)


## Which bindings share a key with another and who with, over the snapshot's event labels for EVERY
## action -- a warning naming an off-page action is still true and still actionable. `unbound` and `?`
## are excluded: two actions with no key are not in conflict.
static func clashes(snapshot: Dictionary) -> Dictionary:
	var labels: Dictionary = snapshot.get("event_labels", {})
	var by_key: Dictionary = {}
	for act: Variant in snapshot.get("all_actions", labels.keys()):
		for label: Variant in labels.get(act, []):
			if String(label) == "unbound" or String(label) == "?":
				continue
			var seen: Array = by_key.get(String(label), [])
			seen.append(StringName(act))
			by_key[String(label)] = seen
	var out: Dictionary = {}
	for r: Array in REMAP_ROWS:
		var act: StringName = r[0]
		var said: Array = []
		for label: Variant in labels.get(act, []):
			for other: Variant in by_key.get(String(label), []):
				if StringName(other) != act:
					said.append("%s is also %s" % [String(label), action_label(StringName(other))])
		if not said.is_empty():
			out[act] = said
	return out


## Break a sentence to a pixel width, words only.
static func wrap(font: Font, text: String, width: float, size: int) -> Array:
	var out: Array = []
	var line: String = ""
	for word: String in text.split(" ", false):
		var probe: String = word if line == "" else line + " " + word
		if font.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = probe
	if line != "":
		out.append(line)
	return out


# ---- the page's state ----------------------------------------------------------------------------

## The plate's geometry in CANVAS px for the current face and eased height.
func geometry() -> Dictionary:
	var h: float = UiTheme.px(_set_h)
	var w: float = UiTheme.px(width_for(cat))
	var origin := Vector2((UiTheme.CANVAS.x - w) * 0.5, (UiTheme.CANVAS.y - h) * 0.5)
	var inner_x: float = origin.x + UiTheme.px(UiTheme.BAZAAR_RAIL + UiTheme.BAZAAR_PAD)
	var inner_w: float = w - UiTheme.px(UiTheme.BAZAAR_RAIL + UiTheme.BAZAAR_PAD * 2.0)
	var body_h: float = h - UiTheme.px(SET_HEAD + SET_FOOT)
	var content := Rect2(inner_x, origin.y + UiTheme.px(SET_HEAD), inner_w, body_h - UiTheme.px(SET_DETAIL + 8.0))
	return {"origin": origin, "w": w, "h": h, "content": content,
		"detail": Rect2(inner_x, content.end.y + UiTheme.px(8.0), inner_w, UiTheme.px(SET_DETAIL)),
		"col_w": (inner_w - UiTheme.px(REMAP_GAP)) * 0.5}


## The rise, on the counter's curve.
func ease() -> float:
	var u: float = 1.0 - _set_t
	return 1.0 - u * u * u


## Step the rise toward open or closed and the height toward the open face's wanted height.
func advance(delta: float) -> void:
	_set_t = move_toward(_set_t, 1.0 if open else 0.0, delta * RISE_PER_S)
	_set_h = lerpf(_set_h, wanted_h(cat), HEIGHT_EASE)


func visible() -> bool:
	return open or _set_t > 0.001


func set_cat(c: int) -> void:
	cat = clamp_cat(c)
	row = clampi(row, 0, focus_count(cat) - 1)
	armed = ""


func move_row(keycode: int) -> void:
	row = next_row(cat, row, keycode)


func focus_payload() -> Dictionary:
	return row_payload(cat, row)


func focus_action() -> StringName:
	return row_action(cat, row)


## Registered by the drawing pass: every clickable control and every slider's bar.
func begin_hits() -> void:
	_hits.clear()
	_slider_rects.clear()


func add_hit(rect: Rect2, payload: Dictionary) -> void:
	_hits.append({"rect": rect, "payload": payload})


func set_slider_rect(id: String, rect: Rect2) -> void:
	_slider_rects[id] = rect


func hit_count() -> int:
	return _hits.size()


## The control payload under a canvas point, or {} for none; a slider adds the clicked fraction.
func click(canvas_pos: Vector2) -> Dictionary:
	for hit: Dictionary in _hits:
		if (hit["rect"] as Rect2).has_point(canvas_pos):
			var payload: Dictionary = (hit["payload"] as Dictionary).duplicate()
			if payload.has("slider"):
				payload["frac"] = slider_frac(String(payload["slider"]), canvas_pos.x)
			return payload
	return {}


func slider_frac(id: String, canvas_x: float) -> float:
	var bar: Rect2 = _slider_rects.get(id, Rect2())
	if bar.size.x <= 0.0:
		return 0.0
	return clampf((canvas_x - bar.position.x) / bar.size.x, 0.0, 1.0)


func level(id: String) -> float:
	return float((state.get("levels", {}) as Dictionary).get(id, 1.0))


func binding_label(action: StringName) -> String:
	return String((state.get("bindings", {}) as Dictionary).get(action, "?"))


static func _pointer(ci: CanvasItem) -> Vector2:
	var vp: Viewport = ci.get_viewport()
	return vp.get_mouse_position() if vp != null else Vector2(-1.0, -1.0)


var _last_time: float = 0.0


func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null:
		return
	var dt: float = clampf(frame.anim_time - _last_time, 0.0, 0.1)
	_last_time = frame.anim_time
	advance(dt)
	if not visible():
		return
	SettingsDraw.overlay(self, ci, ThemeDB.fallback_font, _pointer(ci))
