class_name SettingsPage
extends RefCounted

## WHAT THE SETTINGS PAGE SHOWS, WHICH IS NOT THE SAME QUESTION AS WHAT THE SETTINGS ARE (A' step 6j,
## D0372). Legacy `scenes/settings_page.gd`'s split, kept: the shell's `Settings` owns the values and
## their persistence; this owns the PAGE -- which rows exist, in which category, in what order, what
## sentence each carries, and where the keyboard cursor goes next. Everything here is data or a pure
## function of (category, row), reachable without a running game; the drawing is `SettingsControl`, a
## real Control tree (D0632, the Hybrid ruling -- the hit-rect painter `SettingsDraw` is gone). The
## view may not reach `shell/`, so the values arrive as a SNAPSHOT (`state`) the shell hands over each
## frame, and the page returns the same payload for a click and for ENTER, so the shell's one mutation
## path serves both pointers.
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
## EVERY action the hand reads, not four of fifteen (D0410; the new-player review: "KEYS · 4" exposed only
## movement, jump and mining while grapple, reel, build and drop went unlisted). The ten hotbar wells are
## the last rows (T026, D0615): they used to be physical-key polls no remap could reach.
const REMAP_ROWS: Array[Array] = [
	[Controls.LEFT, "move left", ""], [Controls.RIGHT, "move right", ""],
	[Controls.JUMP, "jump", ""],
	[Controls.MINE, "mine (hold)", "hold on rock; the pick decides what breaks"],
	[Controls.GRAPPLE, "grapple", "throw the line at rock above; again to let go"],
	[Controls.CLIMB_UP, "reel in / climb", "shorten the line, or climb a rope"],
	[Controls.CLIMB_DOWN, "pay out / descend", "lengthen the line, or slide down a rope"],
	[Controls.BUILD, "build / pick up", "place what is selected at the aim, or take a machine back"],
	[Controls.DROP, "drop", "drop the selected stack: into a mouth in reach, else forward"],
	[Controls.CONFIGURE, "configure", "the aimed machine's own toggle"],
	[Controls.LINK, "link winch", "arm a winch head, then its station"],
	[Controls.CLEAR_PLAN, "clear plan", ""],
	[Controls.MAP, "map", "the corner map grows and shrinks"],
	[Controls.SETTINGS, "settings", ""],
	[Controls.SAVE, "save", "write the slot now"],
	[Controls.SLOTS[0], "slot 1", "select the first hotbar well"],
	[Controls.SLOTS[1], "slot 2", ""],
	[Controls.SLOTS[2], "slot 3", ""],
	[Controls.SLOTS[3], "slot 4", ""],
	[Controls.SLOTS[4], "slot 5", ""],
	[Controls.SLOTS[5], "slot 6", ""],
	[Controls.SLOTS[6], "slot 7", ""],
	[Controls.SLOTS[7], "slot 8", ""],
	[Controls.SLOTS[8], "slot 9", ""],
	[Controls.SLOTS[9], "slot 0", "the tenth well"],
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
const SET_FOOT: float = 22.0   # 16 -> 22 (D0410): the legend cleared the detail box by nothing
const SET_DETAIL: float = 36.0
const SET_ROW: float = 22.0
## The floor: four rail slots at the rail's own minimum pitch (`UiTheme.rail_slots`: the top edge, three
## pitches of tile + label + air, the last label, the edge) -- 196 fit three slots and clipped the fourth.
const SET_MIN_H: float = 236.0
const SET_CTRL_DX: float = 84.0
const SET_BAR_W: float = 78.0
const REMAP_ROW_H: float = 15.0
const REMAP_GAP: float = 16.0
const RISE_PER_S: float = 6.0         ## the plate's rise, seconds to full

var open: bool = false
var cat: int = CAT_AUDIO
var row: int = 0
var capture: StringName = &""         ## the action awaiting its new key ("press a key…")
var armed: String = ""                ## the GAME row whose first press was taken; the second acts
## The shell's snapshot: muted, levels {id: 0..1}, shake, auto_pickup, zoom_label, bindings {action:
## label}, event_labels {action: [labels]}, all_actions [action]. Empty until the shell fills it.
var state: Dictionary = {}
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
## Since D0634 this is the page's own MEASURE, not the plate's size -- the retained tree sizes itself
## to content, so no mechanism reads this; the suite pins it as the authored geometry spec.
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

## The rise, on the counter's curve. `SettingsControl` reads this for the plate's offset and alpha.
func ease() -> float:
	var u: float = 1.0 - _set_t
	return 1.0 - u * u * u


## Step the rise toward open or closed.
func advance(delta: float) -> void:
	_set_t = move_toward(_set_t, 1.0 if open else 0.0, delta * RISE_PER_S)


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


func level(id: String) -> float:
	return float((state.get("levels", {}) as Dictionary).get(id, 1.0))


func binding_label(action: StringName) -> String:
	return String((state.get("bindings", {}) as Dictionary).get(action, "?"))


## The detail note's sentence: what a row answers, which is the model's question, not the view's --
## moved here in D0634 so the text is posed headless like every other table. `hover` is the pointer's
## row (-1 for none): it wins over the keyboard cursor, else the category's standing line.
func detail_text(hover: int) -> String:
	var i: int = hover if hover >= 0 else row
	match cat:
		CAT_CONTROLS:
			if i >= REMAP_ROWS.size():
				return "puts every binding back to its default"
			var act: StringName = row_action(cat, i)
			if capture == act and act != &"":
				return "press any key to bind it — ESC cancels"
			var clash: Array = clashes(state).get(act, [])
			if not clash.is_empty():
				return " and ".join(clash)
			var r: Array = REMAP_ROWS[i]
			return String(r[2]) if String(r[2]) != "" else "%s — press Enter to rebind" % String(r[1])
		CAT_FEEL:
			if i >= 0 and i < FEEL_ROWS.size():
				return String(FEEL_ROWS[i][2])
		CAT_GAME:
			if i >= 0 and i < GAME_ROWS.size():
				return String(GAME_ROWS[i][2])
		_:
			if i == 0:
				return "silences everything at once; the levels below are kept"
			if i > 0 and i <= AUDIO_ROWS.size():
				return String(AUDIO_ROWS[i - 1][2])
	return CATEGORY_LINE[cat]
