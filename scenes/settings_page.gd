class_name SettingsPage
extends RefCounted

## WHAT THE SETTINGS PAGE SHOWS, WHICH IS NOT THE SAME QUESTION AS WHAT THE SETTINGS ARE.
##
## `Settings` owns the values and their persistence: the volumes, the toggles, the bindings, the file.
## This owns the PAGE: which rows exist, in which category, in what order, what sentence each one carries,
## and where the keyboard cursor goes next. Those are different concerns and they change for different
## reasons. Adding a row here is a page edit; adding a setting there is a save-format edit.
##
## Everything in this file is data or a pure function of (category, row). Nothing here draws, nothing here
## reads a node, and nothing here holds state. That is the property worth keeping: the cursor rules are
## the part of the page most likely to be wrong and the part least able to be seen in a screenshot, so
## they are the part that benefits most from being reachable without a running game.
##
## `Hud` keeps the field it already had for where the cursor IS, and asks this where it should GO. The
## catalogs are aliased there rather than copied, so there is one of each in the tree.

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
