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
## What a rail slot is made of. Both rails stack a tile with one line of type under it and neither may
## print into the slot below, so the pitch is a clearance and not a taste: at the old 150 floor the FEEL
## page came out 186 tall, the pitch collapsed to exactly `RAIL_ICON`, and the tiles met.
##
## What the two rails do not share is the line. The settings rail writes a word there and its slot ends
## at the word's descender, while the counter's rail puts the key that selects the tab on that same line
## as a cap and a cap is taller than a word, so its slot ends where the cap's shadow does. Both floors
## are the same sentence, the slot's last mark plus air, read off each rail's own drawing. For the
## settings rail that returns 54.0, which is the number this file shipped.
const RAIL_ICON: float = 38.0         ## the tile at the top of every slot, both rails
const RAIL_LABEL_FS: int = 7          ## and the type on the line under it
const RAIL_LABEL_DY: float = 44.0     ## the settings word's baseline, below the tile
const RAIL_TEXT_AIR: float = 2.0      ## tile to the top of the type under it
const RAIL_SLOT_AIR: float = 7.0      ## a slot's last mark to the next slot's tile
const RAIL_PITCH_MAX: float = 58.0    ## a tall rail spreads its tabs no further than this
const RAIL_TOP: float = 62.0          ## where the first tile sits when the rail has the room
const RAIL_TOP_FRAC: float = 0.18     ## ...and the share of a shorter rail it takes instead
const RAIL_EDGE: float = 6.0          ## the margin no slot crosses at either end
## The shared grid, measured from the content's left edge. It is named because a layout assertion that
## re-derives them is checking its own arithmetic against itself.
const SET_CTRL_DX: float = 116.0
const SET_BAR_W: float = 116.0
const SET_VALUE_DX: float = 242.0     ## SET_CTRL_DX + SET_BAR_W + 10
const REMAP_ROW_H: float = 15.0
const REMAP_GAP: float = 16.0
