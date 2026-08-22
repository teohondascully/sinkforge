class_name Hud
extends Node2D

## Screen-fixed HUD. It lives under a CanvasLayer so the follow camera does not scroll it, reads the sim
## only and draws in screen space.

const CANVAS := UiTheme.CANVAS

## The counter's own, aliased rather than copied so there is one of each in the tree.
const BAZAAR_COLS := BazaarPage.BAZAAR_COLS
const BAZAAR_HEAD := BazaarPage.BAZAAR_HEAD
const BAZAAR_FOOT := BazaarPage.BAZAAR_FOOT
const BAZAAR_MIN_H := BazaarPage.BAZAAR_MIN_H
const BAZAAR_DETAIL := BazaarPage.BAZAAR_DETAIL
const BAZAAR_SIZE := BazaarPage.BAZAAR_SIZE
const ITEM_PURPOSE := Visuals.ITEM_PURPOSE
const TAB_PACK := BazaarPage.TAB_PACK
const TAB_WORKS := BazaarPage.TAB_WORKS
const TAB_BENCH := BazaarPage.TAB_BENCH
const TAB_NAMES := BazaarPage.TAB_NAMES
const SLOT: float = 30.0        ## inventory hotbar slot size
const SLOT_GAP: float = 4.0
## Where the bottom furniture starts, as one definition rather than two. `_draw_inventory` derives the
## bar's y from these, and anything outside the HUD should read `bottom_furniture_fraction()` rather
## than carry its own number; `tools/check_opening.gd` hardcodes `HUD_BOTTOM = 0.20` where the real band
## starts at 295/360 = 0.819.
const HOTBAR_BAND_TOP: float = CANVAS.y - 28.0 - SLOT - 7.0
const HOTBAR_BAND_H: float = SLOT + 14.0


## The fraction of the canvas above the bottom furniture: the last row that is still world.
static func bottom_furniture_fraction() -> float:
	return HOTBAR_BAND_TOP / CANVAS.y
const MINI_W: float = 150.0     ## minimap box in the top-right corner; the world fits inside it,
const MINI_H: float = 116.0     ## ...whatever shape the world happens to be
const MINI_TOP: float = 34.0    ## minimap y (just under the FORGED counter)

## --- UI skin palette ---------------------------------------------------------------------------
##
## Owned by `UiTheme`, aliased here so this page's call sites read unchanged and `check_text_contrast`
## still finds every ink in this script's own constant map. The reasoning for each value lives with the
## value, in `scenes/ui_theme.gd`.
const UI_BG := UiTheme.UI_BG
const UI_EDGE := UiTheme.UI_EDGE
const UI_EDGE_HI := UiTheme.UI_EDGE_HI
const UI_ACCENT := UiTheme.UI_ACCENT
const GOLD_PALE := UiTheme.GOLD_PALE
const UI_WARN := UiTheme.UI_WARN
const UI_TEXT := UiTheme.UI_TEXT
const UI_TEXT_DIM := UiTheme.UI_TEXT_DIM
const UI_TEXT_FAINT := UiTheme.UI_TEXT_FAINT
const UI_SLOT := UiTheme.UI_SLOT
const UI_MODAL := UiTheme.UI_MODAL

var sim: FactorySim
var _font: Font = ThemeDB.fallback_font
var paused_getter: Callable
## Fast-forward game clock, set by MainView. Above 1 it draws a small "▶▶ Nx" chip top-left; 1.0 draws
## nothing, which is the calm-screen default.
var time_scale: float = 1.0
## The tutorial chain, which answers "how do I play?". Set by MainView.
var objectives: Objectives
## Craftable machines for the CRAFT strip (set by MainView): [{name: String, cost: {item->count}}].
var craft_options: Array[Dictionary]:
	get: return _bazaar_page.craft_options
	set(v): _bazaar_page.craft_options = v
## Machine item id -> {color: Color, tag: String}, so machine items in the hotbar read as machines.
var machine_icons: Dictionary = {}
## The item id per craft row, parallel to `craft_options` and set by MainView, machines then tools. It
## lets the craft panel render either a machine or a tool per row without depending on insertion order.
var craft_ids: Array[StringName]:
	get: return _bazaar_page.craft_ids
	set(v): _bazaar_page.craft_ids = v
## The active carried-item slot in the inventory hotbar (set by MainView; mouse-wheel cycles it).
var inv_selected_getter: Callable
## Inspector facts for the machine under the aim, pushed here by MainView: name, recipe, routing mode
## and what it holds. Empty means nothing is hovered. Drawn top-right under FORGED.
var hover_info: Dictionary = {}
var _hover_rect: Rect2 = Rect2()          ## the inspector's canvas rect this frame (the pin region)
var _knob_hits: Array[Dictionary] = []    ## clickable knob chips this frame: [{rect, payload}]
## Stalled machines from `sim.machine_problems()`, pushed each frame. A compact left-edge stack that
## appears only when something is stuck, each row clickable to ping the culprit. `_alert_hits` holds
## this frame's clickable rects as [{rect, cell}].
var alerts: Array[Dictionary] = []
var _alert_hits: Array[Dictionary] = []
const ALERT_REASON: Dictionary = {
	&"blocked": "output blocked — dig a drain",
	&"no_fuel": "out of coal — feed it",
	&"no_input": "starved — nothing feeding it",
	# The Drift Rig has two outputs dug in different places, so "output blocked" cannot say which column
	# jammed (docs/DRIFT.md §7).
	&"blocked_pay": "ore column jammed — dig a drain UNDER it",
	&"blocked_spoil": "spoil column jammed — dig a drain BEHIND it",
	&"no_power": "no power — it eats a network, not a coal box",
	# Spent is not starved. A Head that has finished its vein has nothing wrong with it, and calling it
	# starved sends the player hunting for a feed problem that does not exist (docs/LODE.md §5).
	&"spent": "the vein is worked out — pick it up and move it",
	&"unlinked": "nothing to feed — a Spur must touch a Drill, or a Spur that reaches one",
}
## The title and new-game card. {} means closed; otherwise {seed, tint, tint_name, tints, has_save}.
var title_info: Dictionary = {}
## Minimap inputs pushed by MainView: a material-id to colour lookup, handed over as a Callable so the
## HUD stays decoupled, plus the camera focus and the world-space view size. The terrain image is cached
## and rebuilt only on a dig.
var minimap_color: Callable
var minimap_focus: Vector2 = Vector2.ZERO
var minimap_view: Vector2 = Vector2.ZERO
var _minimap_tex: ImageTexture
var _minimap_solid_count: int = -1
const CELL: float = FactorySim.CELL

## On-demand overlays, pushed by MainView each frame. Only the hotbar, the FORGED chip and the current
## objective line are permanent; the crafting screen (E), the map (M) and the controls help (H/?) are
## summoned so they never clutter the playfield.
var inventory_open: bool = false   ## E/T: the Bazaar panel is open, and `bazaar_tab` picks the tab
var can_craft: bool = false        ## near a claimed Bazaar? gates the verbs, never the layout

const BAZAAR_RAIL := UiTheme.BAZAAR_RAIL
const BAZAAR_PAD := UiTheme.BAZAAR_PAD
## Elevation, not a gold slab. The live tab on both rails used to be a filled brass-tinted tile plus an
## accent edge plus a lit glyph, which is three signals for one bit of state. This is a lift off
## `UI_RAIL`, so the brass is spent once, on the edge, and it is derived rather than merely described as
## derived: the arithmetic below reproduces the bytes of the `Color(0.090, 0.100, 0.130)` it replaces.
##
## The lift is per-channel and deliberately not flat. 0.047 / 0.051 / 0.060 rises toward blue, so the
## lit tile comes up slightly cooler than its rail rather than just brighter, which keeps it from
## reading as the gold beside it. Alpha is zeroed: the rail is 92% and the tile inside it is opaque.
## How long the counter takes to arrive. A panel that appears fully formed in one frame is the loudest
## thing separating a menu from an interface, and 0.13s of rise is cheaper than any art.
const BAZAAR_RISE: float = 0.13
var bazaar_tab: int:
	get: return _bazaar_page.bazaar_tab
	set(v): _bazaar_page.bazaar_tab = v
var _bazaar_t: float:  ## 0..1 open ease, driven in _process
	get: return _bazaar_page._bazaar_t
	set(v): _bazaar_page._bazaar_t = v
var _bazaar_h: float = BAZAAR_SIZE.y  ## the height the counter is currently at, eased toward its tab's
## The rack, the shop half of WORKS, set by MainView beside `craft_options` in the same {name, cost}
## shape with `rack_ids` parallel to it. It is kept a separate list rather than appended to the craft
## list because the two columns mean different things: the left is what you build from your own
## materials, the right is what you buy with refined goods (`docs/BITS.md` §7).
var rack_options: Array[Dictionary]:
	get: return _bazaar_page.rack_options
	set(v): _bazaar_page.rack_options = v
var rack_ids: Array[StringName]:
	get: return _bazaar_page.rack_ids
	set(v): _bazaar_page.rack_ids = v
## The highlighted row on the active tab. One cursor serves the whole panel, and what "acts" means is
## the tab's own business: buy, craft or research.
var bazaar_row: int:
	get: return _bazaar_page.bazaar_row
	set(v): _bazaar_page.bazaar_row = v
## ...and where that cursor was left on each of the other two, one slot per tab. The cursor is shared
## but the place is not, so a glance sideways no longer costs the walk back down a long list. It is kept
## here rather than as three cursors because everything reading the selection asks the one that is live.
# `_bazaar_rows` is deliberately NOT forwarded. It is a PackedInt32Array, which is a value type, so a
# property getter hands back a copy and `hud._bazaar_rows[i] = x` would write to a temporary and vanish.
# Nothing outside the page reads it, and the page mutates its own field directly, so the safe thing is
# for the name not to exist here at all rather than to exist and quietly not work.
var show_minimap: bool = false
var minimap_large: bool = false    ## M cycles corner → LARGE (centred) → hidden
## True while a grapple line is on screen, hook in flight or anchored, pushed every frame by MainView.
## An arrival ceremony is held while it is set: the plate is centred on the body and the rope hangs
## through the same column so the two cannot share a frame legibly.
var rope_active: bool = false
## The player's ping marker in world coords, where Vector2.INF means none, set by clicking the open map.
## MainView owns it and pushes it here and to the renderer, which draws the in-world beacon.
var ping_world: Vector2 = Vector2.INF
var show_help: bool = false
var show_dashboard: bool = false   ## G: the production dashboard, throughput bars plus factory census
## The settings page, reached with ESC on a calm screen. Values are read straight off the `Settings`
## statics and every control click returns a payload through `settings_click()`, so the HUD never
## touches InputMap, audio or the config file.
var settings_open: bool = false

## The page itself. The properties below are where its state has always been read from, so they stay
## as properties rather than becoming `hud._settings_page.settings_cat` at every call site.
var _settings_page: SettingsPage = SettingsPage.new()

## The counter's pages. The bench draws itself in `BazaarPage`; the shell, the rail, the pack, the works
## list and the detail plate are still here and follow it, in that order.
var _bazaar_page: BazaarPage = BazaarPage.new()
var settings_capture: StringName:          ## the action awaiting its new key ("press a key…")
	get: return _settings_page.settings_capture
	set(v): _settings_page.settings_capture = v
var _settings_hits: Array[Dictionary]:     ## clickable controls this frame: [{rect, payload}]
	get: return _settings_page._settings_hits
	set(v): _settings_page._settings_hits = v
var _slider_rects: Dictionary:             ## slider id -> its bar Rect2 this frame (drag support)
	get: return _settings_page._slider_rects
	set(v): _settings_page._slider_rects = v
var settings_cat: int:                     ## which face of the page is open (the rail's selection)
	get: return _settings_page.settings_cat
	set(v): _settings_page.settings_cat = v
var _set_h: float:                         ## eased toward `_settings_wanted_h()`, like the counter
	get: return _settings_page._set_h
	set(v): _settings_page._set_h = v
var _set_t: float:                         ## the page's own rise, 0..1; drives the scrim and the defocus
	get: return _settings_page._set_t
	set(v): _settings_page._set_t = v
## The dashboard and the key list have no rise of their own, so they share one. Without it they were the
## two modals of four that left the world sharp behind them.
var _plain_t: float = 0.0
var settings_row: int:                     ## the keyboard cursor on the binding list
	get: return _settings_page.settings_row
	set(v): _settings_page.settings_row = v

## Transient toast for "SAVED", "LOADED" and other short notices. Set via `flash()`; fades on its own.
var _flash_text: String = ""
var _flash_life: float = 0.0

## The descent readout and its arrivals. `depth_row` is poked every frame by MainView, and the arrival
## is a one-shot banner fired when the body first crosses into a band it has not been in.
var depth_row: int = Strata.SURFACE_ROW
var _arrival_text: String = ""
var _arrival_kicker: String = ""
var _arrival_color: Color = Color.WHITE
var _arrival_life: float = 0.0
const ARRIVAL_HOLD: float = 3.4          ## total life of the banner, fade included

## The just-in-time hint bubble, pushed by MainView from the Hints tracker: a small speech bubble
## anchored near the body that teaches a newly acquired item's use. Empty text means none.
var hint_text: String = ""
var hint_anchor: Vector2 = Vector2.ZERO   ## canvas-space point the tail points at (above the head)
var hint_alpha: float = 0.0

## The hovered slot this frame (captured while drawing the hotbar/pack grid, drawn last, on top).
var _tooltip_item: StringName:
	get: return _bazaar_page._tooltip_item
	set(v): _bazaar_page._tooltip_item = v
var _tooltip_count: int:
	get: return _bazaar_page._tooltip_count
	set(v): _bazaar_page._tooltip_count = v
var _tooltip_anchor: Vector2:   ## top-centre of the hovered slot
	get: return _bazaar_page._tooltip_anchor
	set(v): _bazaar_page._tooltip_anchor = v


## Show a short transient notice centred under the objective banner (~2s, fades).
func flash(text: String) -> void:
	_flash_text = text
	_flash_life = 2.2


## Announce arrival in a new stratum, which is the one moment the descent gets to be an event.
##
## It is held rather than dropped while the big map is up. The plate is centred at y 62..112 and the
## large map's panel spans 181..459 by 41..319, so an arrival crossed with the map open lands inside it,
## a measured 222x50 overlap held by `check_hud_layout`. The goal plate, the pack bar and the inspector
## simply stand down there because they are persistent and come back. This one is a one-shot with a 3.4s
## life, so standing it down would delete it rather than compose it, and you would cross into the
## deepslate and never be told. It waits for the map to close and then fires in full.
func announce(text: String, kicker: String, color: Color) -> void:
	if _announce_held():
		_pending_arrival = [text, kicker, color]
		return
	_arrival_text = text
	_arrival_kicker = kicker
	_arrival_color = color
	_arrival_life = ARRIVAL_HOLD


## An arrival that fired while the whole-world view was open, waiting for it to close. Empty when none.
var _pending_arrival: Array = []


## Is the announce channel occupied right now? One caller, the controller, uses it to hold a
## just-in-time lesson back rather than stack it under the ceremony. Only one primary attention state
## may be up at a time, and this is the predicate that makes that rule enforceable.
func announcing() -> bool:
	return _arrival_life > 0.0


## The conditions under which an arrival ceremony is held.
##
## Held rather than dropped. The plate is a one-shot with a 3.4s life, so standing it down deletes the
## announcement instead of composing it. Its clock stops and it draws nothing while held. It then
## resumes with its remaining life intact.
##
## Two conditions, for two collisions. The large map shares the plate's rectangle in both directions. A
## ceremony firing under an open map waits in `_pending_arrival`, and one already up when the map opens
## freezes here, since `_draw_arrival` runs after `_draw_minimap`. A live grapple line shares the
## plate's column instead. The camera centres the body, so the plate spans canvas y 61.6 to 111.6
## directly over the miner and any rope reaching them passes through it. No position on a 640-wide
## canvas avoids that so the rope case can only be solved in time.
##
## Every gate site calls this rather than testing the conditions inline. A condition added to some sites
## and not others freezes the clock while the plate still fires and still draws.
func _announce_held() -> bool:
	return minimap_large or rope_active


func _process(delta: float) -> void:
	if not _pending_arrival.is_empty() and not _announce_held():
		var held: Array = _pending_arrival
		_pending_arrival = []
		announce(String(held[0]), String(held[1]), held[2] as Color)
	_flash_life = maxf(0.0, _flash_life - delta)
	if not _announce_held():
		_arrival_life = maxf(0.0, _arrival_life - delta)
	# The counter's arrival, eased out so it decelerates into place rather than sliding at a constant rate.
	# That is the difference between a panel that lands and a panel that is dragged on.
	var target: float = 1.0 if inventory_open else 0.0
	var step: float = delta / BAZAAR_RISE
	_bazaar_t = clampf(_bazaar_t + (step if target > _bazaar_t else -step * 2.0), 0.0, 1.0)
	# The counter's height follows the tab on the same clock as its rise. It is snapped when closed so that
	# opening never animates a size, and snapped near the target so a settled frame is a settled
	# measurement: `check_hud_layout` photographs this panel, and a footprint that depends on how many
	# frames have passed is not a footprint.
	if inventory_open or _bazaar_t > 0.0:
		var want: float = _bazaar_wanted_h()
		if _bazaar_t <= 0.0 or absf(want - _bazaar_h) < 0.5:
			_bazaar_h = want
		else:
			_bazaar_h += (want - _bazaar_h) * clampf(delta / BAZAAR_RISE, 0.0, 1.0)
	# The settings page follows its category on the counter's clock and by the counter's rule, snapped
	# while closed for the reason above.
	_set_t = clampf(_set_t + (step if settings_open else -step * 2.0), 0.0, 1.0)
	_plain_t = clampf(_plain_t + (step if (show_dashboard or show_help) else -step * 2.0), 0.0, 1.0)
	var set_want: float = _settings_wanted_h()
	if not settings_open or absf(set_want - _set_h) < 0.5:
		_set_h = set_want
	else:
		_set_h += (set_want - _set_h) * clampf(delta / BAZAAR_RISE, 0.0, 1.0)
	queue_redraw()


## THE SETTINGS PAGE, WHICH LIVES IN `SettingsPage` AND IS REACHED THROUGH HERE.
##
## The page draws itself. What stays on the Hud is the address: the field holding it, the properties
## that keep its state readable where it has always been read, and one forwarder per entry point.
## `scenes/main.gd` routes input through these names and three tools reach for them, so all of them
## are API and none of them changed.

## Re-bind on every entry rather than once at startup. `probing` is a static a fixture flips between
## frames; binding once would hand the page a snapshot and let it go stale.
func _page() -> SettingsPage:
	_settings_page._canvas = self
	_settings_page._font = _font
	_settings_page.probing = probing
	_settings_page.panel_probe = panel_probe
	return _settings_page


func _draw_settings_overlay() -> void:
	_page()._draw_settings_overlay()


func _settings_wanted_h() -> float:
	return _page()._settings_wanted_h()


func _remap_per_col() -> int:
	return _page()._remap_per_col()


func settings_ease() -> float:
	return _page().settings_ease()


func settings_focus_count() -> int:
	return _page().settings_focus_count()


func settings_row_payload(cat: int, i: int) -> Dictionary:
	return _page().settings_row_payload(cat, i)


func settings_focus_payload() -> Dictionary:
	return _page().settings_focus_payload()


func move_settings_row(keycode: int) -> void:
	_page().move_settings_row(keycode)


func settings_row_action() -> StringName:
	return _page().settings_row_action()


func set_settings_cat(cat: int) -> void:
	_page().set_settings_cat(cat)


func settings_click(canvas_pos: Vector2) -> Dictionary:
	return _page().settings_click(canvas_pos)


func settings_slider_frac(id: String, canvas_x: float) -> float:
	return _page().settings_slider_frac(id, canvas_x)


## `check_binding_conflict` asks the Hud which bindings collide, and has since before the page moved.
func _binding_clashes() -> Dictionary:
	return _page()._binding_clashes()


## The dashboard and the key list, on the same curve as the other two. Public for the same reason:
## whichever modal is up should rack the world, and racking only the modals that already had a rise is
## how two of the four came to read as stickers on a sharp frame.
func plain_modal_ease() -> float:
	var u: float = 1.0 - _plain_t
	return 1.0 - u * u * u


## Every helper surface, classified. The rule is that only one primary attention state may be on screen
## at a time, and this is the inventory that makes it checkable. It is a constant rather than a document
## because `tools/check_hud_layout.gd` asserts that every `_draw_*` method on this class appears here,
## so adding a surface without deciding what kind of thing it is fails rather than quietly becoming the
## eighth thing on the screen.
##
## The tags and what each one is allowed to do:
##
##   `critical`      interrupts. It arrives on its own schedule and expects to be read now, and at most
##                   one may be on screen at a time, which is the rule this registry is about.
##   `active`        describes what you are doing or looking at this moment. Several may coexist, since
##                   they answer questions you just asked with the cursor or the verb.
##   `discoverable`  you summoned it, so it may cover everything.
##   `ambient`       always-on state you read at a glance and never respond to. It must never move, and
##                   it may not become any of the above.
##   `internal`      not a surface but a drawing helper another entry uses, listed so the check above is
##                   total, and so "helper or screen" is a decision someone made.
##
## `_draw_title` is `discoverable` on a technicality worth stating. You did not summon it, but it owns
## the whole screen by design and returns before anything else draws, so nothing can collide with it.
const HELPER_TAGS: Dictionary = {
	# critical: the interrupt channel, and the one with a one-at-a-time rule
	"_draw_arrival": &"critical",         # the stratum plate: "stop, look"
	"_draw_flash": &"critical",           # save/load toast
	"_draw_alerts": &"critical",          # a machine is stalled and will stay stalled
	"_draw_hint_bubble": &"critical",     # a lesson, which is why it yields to the plate
	# active: about the thing under your hand right now
	"_draw_objective_line": &"active",
	"_draw_hover": &"active",
	"_draw_item_tooltip": &"active",
	# discoverable: you pressed a key to get it
	"_draw_minimap": &"discoverable",
	"_draw_inventory_overlay": &"discoverable",
	"_draw_dashboard_overlay": &"discoverable",
	"_draw_help_overlay": &"discoverable",
	"_draw_settings_overlay": &"discoverable",
	"_draw_title": &"discoverable",
	# ambient: state, read at a glance, never answered
	"_draw_depth": &"ambient",
	"_draw_forged": &"ambient",
	"_draw_inventory": &"ambient",        # the hotbar
	"_draw_hint": &"ambient",             # the bottom-left key legend
	"_draw_fastforward": &"ambient",
	# internal: helpers, not screens
	"_draw": &"internal",
	"_draw_scrim": &"internal",
	"_draw_thing_icon": &"internal",
	"_draw_tech_art": &"internal",
	"_draw_tech_chip": &"internal",
	"_draw_bazaar_rail": &"internal",
	"_draw_bazaar_head": &"internal",
	"_draw_settings_rail": &"internal",
	"_draw_settings_head": &"internal",
	"_draw_settings_detail": &"internal",
	"_draw_bazaar_foot": &"internal",
	"_draw_bazaar_detail": &"internal",
}

## The paused chip is a critical surface with no function of its own, being eight lines inline in
## `_draw()`. It is named here so the registry is honest about it.
##
## It lives in the left column under the fast-forward chip, and it may not move back to the centre. It
## used to print across the objective line at y=8, was pushed down to y 50..76, and landed inside the
## arrival plate's scrim core at `CANVAS.y * 0.26 - SCRIM_ABOVE`, or y 61.6..111.6. Pausing on the frame
## you cross a stratum is not exotic, because crossing a band is when a player stops to read. The
## ceremony, the objective line and the lesson bubble are all centred, so three surfaces compete over a
## 100px strip there while the left column holds two chips and 300px of nothing.
const PAUSED_CHIP: Rect2 = Rect2(10.0, 60.0, 104.0, 22.0)


## Is a modal up: the counter, the dashboard, the controls page or the settings page. All four dim the
## world and put a plate over the middle of it, so while one is open it is the screen and the furniture
## around it stands down. It is written once because it was spelled out three times, and one of the
## three had a different idea of which screens counted.
##
## The minimap is deliberately not in here. It is summoned rather than modal, and it has the opposite
## rule: the furniture stands down for the large form only, inside the surfaces it collides with.
func _modal_open() -> bool:
	return inventory_open or show_dashboard or show_help or settings_open


func _draw() -> void:
	_tooltip_item = &""    # re-captured by whichever slot the cursor sits on this frame
	_alert_hits.clear()    # stale unless _draw_alerts repopulates it this frame (menus suppress it)
	# While the title is open nothing else matters: the veil and the new-game card are the screen.
	if not title_info.is_empty():
		_draw_title()
		return
	# --- always on, unless a modal has taken the screen ---
	# Every line in here is world furniture, and each of the four modals draws a plate across the middle of
	# a 640x360 canvas; the counter alone is 608 wide and reaches 348 tall. Drawn unconditionally, the
	# depth chip and the hotbar came out in two pieces, half dimmed by the modal's scrim and half covered
	# by its plate, and a chip cut by an edge reads as a drawing fault.
	if not _modal_open():
		_draw_forged()         # top-right production chip (small)
		_draw_depth()          # top-left depth readout, the one number a descent game owes you
		_draw_objective_line()  # top-centre, one current step, the signpost without the wall of text
		_draw_inventory()      # bottom-centre hotbar
		_draw_hint()           # tiny bottom-left key legend, which replaces the giant footer
		_draw_hint_bubble()  # just-in-time teaching near the body (hidden while a menu dims the world)
		_draw_alerts()       # left-edge stalled-machine stack (only when something's stuck)
	# The inspector stands down inside itself rather than here, because it owns a click region as well as
	# a panel. Skipping the call would leave `_hover_rect` at whatever it held before the menu opened, and
	# `_cursor_on_hover_panel()` reads that rect, so a click on the counter would land on a config knob
	# belonging to a machine nobody can see. `_draw_hover` returns after clearing for the same reason.
	_draw_hover()          # inspector for the machine under the cursor (only when one is hovered)
	# --- on demand (summoned, so they never clutter) ---
	if show_minimap:
		_draw_minimap()    # M: top-right world map
	if inventory_open:
		_draw_inventory_overlay()  # E/T: the Bazaar, one counter with three tabs (docs/BAZAAR.md)
	if show_dashboard:
		_draw_dashboard_overlay()  # G: throughput bars and factory census
	if show_help:
		_draw_help_overlay()      # H, or the slash key: the full controls list
	if settings_open:
		_draw_settings_overlay()  # ESC: audio, feel, and the remap page
	if paused_getter.is_valid() and bool(paused_getter.call()):
		# Under the objective line, not on top of it. Both were aimed at top-centre at y=8 and the objective
		# panel is 37 tall so PAUSED printed across the one line telling you what to do next.
		_panel(PAUSED_CHIP)
		draw_string(_font, PAUSED_CHIP.position + Vector2(12.0, 15.0), "PAUSED (P)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI_TEXT)
	_draw_fastforward()    # top-left "▶▶ Nx" chip when the game clock is sped up
	# The stratum plate is the one channel that means "stop, look", so it does not fire over a modal, where
	# there is nothing to look at and it prints through the price column. Holding it costs nothing, since
	# the depth readout comes back with the world and names the band you are in.
	if not _modal_open():
		_draw_arrival()    # the stratum banner, on the frames after you first cross into one
	_draw_flash()          # transient toast (save/load feedback)
	_draw_item_tooltip()   # hovered-slot tooltip, drawn last so it rides over every panel


## The title and new-game screen: a dark veil over the live, paused world, the game's name, and the two
## choices that make this world yours. It is deliberately spare, because the world glowing behind the
## veil is the real menu art.
func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(CANVAS)), Color(0.03, 0.035, 0.06, 0.82))
	var cx: float = CANVAS.x * 0.5
	var y: float = CANVAS.y * 0.30
	# The name, tracked out wide, with the rule under it in the name's own ink rather than in the accent.
	# The 2px gold rule was retired from eight panels; this was the ninth, and it survived that pass only
	# because it is drawn by hand here instead of through `_panel`. A wordmark's rule is part of the
	# wordmark, so it takes one colour with the letters above it rather than a second one underneath.
	# The only thing on this screen a keypress reaches, `[ENTER] descend`, is the only gold left here.
	var title: String = "S I N K F O R G E"
	var mark := Color(0.97, 0.90, 0.62)
	var tw: float = _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(_font, Vector2(cx - tw * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, mark)
	draw_rect(Rect2(cx - tw * 0.5, y + 7.0, tw, 2.0), mark)
	var tag: String = "the way is down"
	var gw: float = _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(_font, Vector2(cx - gw * 0.5, y + 24.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.64, 0.70, 0.80))
	# The choices card.
	y += 48.0
	var card := Rect2(cx - 128.0, y, 256.0, 84.0)
	_panel(card)
	var x0: float = card.position.x + 14.0
	var ly: float = y + 22.0
	draw_string(_font, Vector2(x0, ly), "world seed", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		Color(0.62, 0.66, 0.74))
	draw_string(_font, Vector2(x0 + 78.0, ly), "%d" % int(title_info.get("seed", 0)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.92, 0.80))
	draw_string(_font, Vector2(card.end.x - 92.0, ly), "[TAB] reroll", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.55, 0.60, 0.70))
	ly += 26.0
	draw_string(_font, Vector2(x0, ly), "lamp", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.62, 0.66, 0.74))
	var tints: Array = title_info.get("tints", [])
	var sel: int = int(title_info.get("tint", 0))
	var sx: float = x0 + 44.0
	for i: int in tints.size():
		var sw := Rect2(sx, ly - 11.0, 14.0, 14.0)
		draw_rect(sw, (tints[i] as Dictionary)["color"])
		# The swatch row is the hardest case on the page, because here the thing being chosen is itself a
		# colour. A 1.5px `UI_ACCENT` outline was the whole mark, and gold sits in one of the five tints'
		# own neighbourhood, since miner's gold is (1.0, 0.90, 0.66), so the caret was a hue laid over hues
		# at lighter weight than any other cursor in the game. The shared ring is 2px with a dark keyline
		# under it, which is a value step and a shape whatever colour it lands beside.
		if i == sel:
			_focus_ring(sw)
		sx += 20.0
	draw_string(_font, Vector2(card.end.x - 92.0, ly), "[<-/->] pick", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.55, 0.60, 0.70))
	ly += 20.0
	draw_string(_font, Vector2(x0 + 44.0, ly), str(title_info.get("tint_name", "")),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.72, 0.76, 0.84))
	# The verbs.
	y = card.end.y + 26.0
	var go: String = "[ENTER]  descend"
	var gow: float = _font.get_string_size(go, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(_font, Vector2(cx - gow * 0.5, y), go, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI_ACCENT)
	if bool(title_info.get("has_save", false)):
		var cont: String = "[C]  continue your last save"
		var cw: float = _font.get_string_size(cont, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(_font, Vector2(cx - cw * 0.5, y + 18.0), cont, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.70, 0.76, 0.86))


## The transient toast: a small accented chip centred under the objective line, fading over its last
## half-second. Cheap reusable feedback for one-shot actions such as F5 save and F9 load.
func _draw_flash() -> void:
	if _flash_life <= 0.0 or _flash_text == "":
		return
	var a: float = clampf(_flash_life / 0.5, 0.0, 1.0)
	var w: float = _font.get_string_size(_flash_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 28.0
	var p := Rect2(CANVAS.x * 0.5 - w * 0.5, 46.0, w, 24.0)
	draw_rect(p, Color(UI_BG.r, UI_BG.g, UI_BG.b, UI_BG.a * a))
	draw_rect(p, Color(UI_EDGE.r, UI_EDGE.g, UI_EDGE.b, a), false, 1.0)
	draw_string(_font, p.position + Vector2(14.0, 17.0), _flash_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.88, 0.62, a))


## The just-in-time hint bubble: a small speech bubble with a tail pointing down at the body, teaching
## the item that just landed in the pack. It is word-wrapped, gold-capped like every panel, faded by the
## tracker's envelope, and clamped on-canvas so a body near a world edge still gets taught.
##
## `hint_box` is the box `_draw_hint_bubble` actually draws, extracted so a layout check can size every
## lesson without reimplementing the layout; a second copy of this arithmetic would agree with itself
## and not with the screen.
##
## Size was the whole complaint. At 11pt over a 230px wrap this box was 250x52 on a 640x360 canvas, 39%
## of the width and 14% of the height, set at nearly the objective banner's weight. 8pt over 176 halves
## the footprint, and the lessons were rewritten to one line each in the same pass, because a smaller
## box around the same paragraph is just a smaller paragraph.
const HINT_FS: int = 8
const HINT_WRAP: float = 176.0

static func hint_box(font: Font, text: String) -> Vector2:
	var ts: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, HINT_WRAP, HINT_FS)
	return Vector2(minf(ts.x, HINT_WRAP) + 16.0, ts.y + 11.0)


func _draw_hint_bubble() -> void:
	if hint_text == "" or hint_alpha <= 0.01:
		return
	var fs: int = HINT_FS
	var wrap_w: float = HINT_WRAP
	var box: Vector2 = hint_box(_font, hint_text)
	var w: float = box.x
	var h: float = box.y
	var tail := Vector2(clampf(hint_anchor.x, 8.0, CANVAS.x - 8.0),
		clampf(hint_anchor.y, 60.0, HOTBAR_BAND_TOP - 6.0))
	var origin := Vector2(clampf(tail.x - w * 0.5, 6.0, CANVAS.x - w - 6.0), tail.y - 7.0 - h)
	if origin.y < 38.0:                       # never under the objective line, so flip below the anchor
		origin.y = tail.y + 7.0
	var a: float = hint_alpha
	var rect := Rect2(origin, Vector2(w, h))
	# Elevation, not an outline. A flat fill inside a 1px border with a full-width bar across the top is a
	# dialog box and reads as one. A soft drop shadow puts the plate above the world instead of cut into
	# it and the rule shrinks to a left edge so the eye lands on the word rather than the frame.
	#
	# That edge is not the accent, because a hint is a thing to read and not a thing to press. It is the
	# sentence the item tooltip's spine was moved off gold for, and this plate has even less claim to it:
	# the tooltip at least describes what the cursor is over, while this one arrives on its own and
	# points at your body. `UI_EDGE_HI` at full strength is what that spine draws in, and the swap costs
	# nothing worth having, 6.24:1 against this plate before and 6.06:1 now.
	_round_rect(Rect2(rect.position + Vector2(0.0, 1.5), rect.size), 4.0, Color(0.0, 0.0, 0.0, 0.38 * a))
	_round_rect(rect, 4.0, Color(UI_BG.r, UI_BG.g, UI_BG.b, UI_BG.a * a))
	draw_rect(Rect2(rect.position + Vector2(0.0, 3.0), Vector2(1.5, h - 6.0)),
		Color(UI_EDGE_HI.r, UI_EDGE_HI.g, UI_EDGE_HI.b, a))
	var tip_y: float = tail.y if origin.y < tail.y else origin.y - 1.0   # tail reaches toward the body
	var base_y: float = (origin.y + h) if origin.y < tail.y else origin.y
	var tx: float = clampf(tail.x, origin.x + 10.0, origin.x + w - 10.0)
	draw_colored_polygon(PackedVector2Array([Vector2(tx - 3.5, base_y), Vector2(tx + 3.5, base_y),
		Vector2(tx, tip_y)]), Color(UI_BG.r, UI_BG.g, UI_BG.b, UI_BG.a * a))
	draw_multiline_string(_font, origin + Vector2(8.0, 5.0 + 8.0), hint_text,
		HORIZONTAL_ALIGNMENT_LEFT, wrap_w, fs, -1, Color(0.92, 0.88, 0.74, a))


## Factory alerts: a compact left-edge stack of stalled machines, shown only when something is stuck, so
## a healthy factory draws nothing here. Each row names the machine, the count and the reason, and is
## clickable to drop a ping on the culprit; the camera is body-locked, so a beacon is the honest way to
## get there. MainView pushes `alerts` and routes the click through `alert_click()`. Capped at 5 rows so
## a cascading failure cannot wallpaper the screen.
func _draw_alerts() -> void:
	if alerts.is_empty():
		return
	var mouse: Vector2 = Controls.pointer_viewport(self)
	var w: float = 184.0
	var rh: float = 22.0
	var x: float = 10.0
	var y: float = 100.0
	var tri := Vector2(x + 5.0, y - 8.0)                       # a small warning triangle (font-safe glyph)
	draw_colored_polygon(PackedVector2Array([tri + Vector2(-4.0, 3.0), tri + Vector2(4.0, 3.0),
		tri + Vector2(0.0, -4.0)]), Color(0.95, 0.60, 0.30))
	draw_string(_font, Vector2(x + 13.0, y - 4.0), "ALERTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(0.94, 0.64, 0.44))
	for i: int in mini(5, alerts.size()):
		var a: Dictionary = alerts[i]
		var rect := Rect2(x, y, w, rh - 3.0)
		var lit: bool = rect.has_point(mouse)
		draw_rect(rect, Color(0.20, 0.11, 0.10, 0.95) if lit else Color(0.15, 0.09, 0.09, 0.92))
		draw_rect(rect, Color(0.78, 0.40, 0.32, 0.7 if lit else 0.45), false, 1.0)
		draw_rect(Rect2(x, y, 2.5, rh - 3.0), UI_WARN)                          # the warning edge
		var mdef: MachineDef = a["def"]
		var box := Rect2(x + 6.0, y + 2.5, 13.0, 13.0)
		draw_rect(box, Visuals.machine_color(mdef))
		Visuals.draw_machine_glyph(self, box.position + box.size * 0.5, Visuals.machine_kind(mdef),
			Visuals.glyph_cells_for(box.size.y), false, 0.0)
		var cnt: int = int(a["count"])
		var nm: String = str(a["name"]) + ("  ×%d" % cnt if cnt > 1 else "")
		draw_string(_font, Vector2(x + 24.0, y + 8.0), nm, HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, 9,
			Color(0.96, 0.86, 0.78))
		draw_string(_font, Vector2(x + 24.0, y + 16.0), str(ALERT_REASON.get(a["status"], str(a["status"]))),
			HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, 8, Color(0.82, 0.62, 0.54))
		_alert_hits.append({"rect": rect, "cell": a["cell"]})
		y += rh
	draw_string(_font, Vector2(x + 2.0, y + 5.0), "click one → mark it on the map",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI_TEXT_DIM)


## Route a click at `mouse`, in canvas coords, to the alert it hit, returning {cell: Vector2i} to ping
## or {} on a miss. MainView owns the ping and the HUD only reports the hit.
func alert_click(mouse: Vector2) -> Dictionary:
	for hit: Dictionary in _alert_hits:
		if (hit["rect"] as Rect2).has_point(mouse):
			return {"cell": hit["cell"]}
	return {}


## Is `mouse` over the alert stack this frame? (MainView holsters the pick over it, like the minimap.)
func cursor_on_alerts(mouse: Vector2) -> bool:
	for hit: Dictionary in _alert_hits:
		if (hit["rect"] as Rect2).has_point(mouse):
			return true
	return false


## The depth readout, top-left. Metres below the surface datum and the name of the band you are in, in
## that band's own colour, so the number and the world's palette agree. It is permanent: in a game whose
## whole subject is descending, "how far down am I" is not an optional overlay.
##
## The chip's width sits on its own, so the objective banner can measure what it must not grow under.
func _depth_chip_w() -> float:
	var m: int = Strata.depth_m(depth_row)
	var label: String = ("%d m" % m) if m >= 0 else ("+%d m" % -m)
	var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var bw: float = _font.get_string_size(Strata.name_at(depth_row), HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	return maxf(lw + 10.0 + bw, 96.0) + 24.0


func _draw_depth() -> void:
	var m: int = Strata.depth_m(depth_row)
	var label: String = ("%d m" % m) if m >= 0 else ("+%d m" % -m)
	var band: String = Strata.name_at(depth_row)
	var tint: Color = Strata.color_at(depth_row)
	var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var chip := Rect2(10.0, 8.0, _depth_chip_w(), 22.0)
	_panel(chip)
	var cy: float = chip.position.y + chip.size.y * 0.5
	draw_string(_font, Vector2(chip.position.x + 12.0, cy + 6.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI_TEXT)
	draw_string(_font, Vector2(chip.position.x + 12.0 + lw + 10.0, cy + 5.0), band,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tint)


## The arrival plate, which fires only the first time you enter a band, because the value is that it is
## rare.
##
## Weight in a title card comes from spacing, not from point size. At three times this size across a
## full-width bar it read as a modal dialog: it covered the play space, it competed with the objective
## banner directly above it and the first instinct was to dismiss it. So: half the type, letters
## tracked apart, a kicker line above it, rules only as wide as the text, and no panel at all.
const ARRIVAL_SIZE: int = 15             ## canvas px; the objective banner above runs at 13
const ARRIVAL_TRACK: float = 3.4         ## extra px between letters, which makes small type read as engraved

## The scrim. Panel-less type only reads while the thing behind it is dark, and every stratum plate
## fires underground except the first-automation hail, which fires on the surface at midday against a
## bright sky, a mountain range and a rotating gearwheel, where the words simply disappeared. The fix is
## not a panel, because a panel is the modal dialog this design escapes, but a soft field of dusk under
## the words that fades to nothing in every direction and so has no edge to read as a shape.
const SCRIM_COLS: int = 12               ## quads across the field...
const SCRIM_ROWS: int = 8                ## ...and down it
## Peak darkening, dead centre. It was 0.80 until it was measured. The scrim is
## `Color(0.02, 0.025, 0.04)` drawn over the frame, which is a multiply in all but name: it keeps a
## fixed fraction of whatever is underneath. Underground the rock behind it sits at a luma near ten and
## barely moves. The rope is hemp at 0.76/0.63/0.42.
##
## `check_ceremony_reads` measured what that costs. Across the plate the rope moved a mean of 26.5 dE
## out of the 41.4 of separation it had from its backing while the rock behind it moved 6.6. The veil
## took four times more from the line you are hanging from than from the background it was drawn to
## suppress. The plate cannot be moved aside either. The camera centres the body and the plate is
## centred too, so its 420px footprint on a 640px canvas always contains the miner's column.
##
## The words get their contrast locally instead, from a near-black shadow a pixel behind each glyph.
## That buys the same separation inside a letter's width and works on bright sky as well as dark rock.
## The field veil is then only what a compositional weight needs.
const SCRIM_ALPHA: float = 0.28
const SCRIM_PAD: float = 34.0            ## px of solid core beyond the widest line
const SCRIM_INK := Color(0.02, 0.025, 0.04)   ## the veil's own colour, now spent per glyph instead
const SCRIM_INK_OFF := Vector2(1.0, 1.0)      ## a pixel down and right, which is enough at this type size
const SCRIM_INK_A: float = 0.90
const SCRIM_FEATHER: float = 96.0        ## px the core fades out over, left and right
const SCRIM_ABOVE: float = 32.0
const SCRIM_BELOW: float = 18.0

func _draw_arrival() -> void:
	if _arrival_life <= 0.0 or _announce_held():
		return
	var t: float = _arrival_life / ARRIVAL_HOLD
	var a: float = clampf(minf((1.0 - t) * 6.0, t * 2.4), 0.0, 1.0)     # fast in, slow out
	var y: float = CANVAS.y * 0.26 - (1.0 - t) * 5.0
	var w: float = _tracked_w(_arrival_text, ARRIVAL_SIZE, ARRIVAL_TRACK)
	var half: float = w * 0.5 + 12.0
	var kw: float = _tracked_w(_arrival_kicker, 9, 2.6) if _arrival_kicker != "" else 0.0
	var core_half: float = maxf(w, kw) * 0.5 + SCRIM_PAD
	# The ceremony is furniture while it is up, so a layout check has to be able to see it. It draws no
	# `_panel()`, deliberately, so `panel_probe` was blind to it. It is registered as the solid core only
	# and not the feathered extent, because the feather fades to nothing by construction and calling it
	# occupied would report collisions with regions that are visually empty.
	if probing:
		panel_probe.append(Rect2(CANVAS.x * 0.5 - core_half, y - SCRIM_ABOVE,
			core_half * 2.0, SCRIM_ABOVE + SCRIM_BELOW))
	_draw_scrim(core_half, y, a)
	# The shadow carries the contrast the veil used to. It is drawn under every glyph rather than under
	# the whole plate so it costs the world a pixel around each letter instead of a 420x50 field.
	if _arrival_kicker != "":
		_tracked(_arrival_kicker, Vector2(CANVAS.x * 0.5 - kw * 0.5, y - 15.0) + SCRIM_INK_OFF, 9, 2.6,
			Color(SCRIM_INK, SCRIM_INK_A * a))
		_tracked(_arrival_kicker, Vector2(CANVAS.x * 0.5 - kw * 0.5, y - 15.0), 9, 2.6,
			Color(_arrival_color, 0.80 * a))
	_tracked(_arrival_text, Vector2(CANVAS.x * 0.5 - w * 0.5, y) + SCRIM_INK_OFF, ARRIVAL_SIZE,
		ARRIVAL_TRACK, Color(SCRIM_INK, SCRIM_INK_A * a))
	_tracked(_arrival_text, Vector2(CANVAS.x * 0.5 - w * 0.5, y), ARRIVAL_SIZE, ARRIVAL_TRACK,
		Color(_arrival_color, a))
	# Two hairlines the width of the words: a frame that says "plate" without drawing a panel.
	for ry: float in [y - 25.0, y + 7.0]:
		draw_line(Vector2(CANVAS.x * 0.5 - half, ry), Vector2(CANVAS.x * 0.5 + half, ry),
			Color(_arrival_color, 0.40 * a), 1.0)


## The arrival plate's soft ground, drawn as an interpolated grid rather than as a stack of bands.
##
## Constant-alpha strips with a half-pixel overlap are precisely backwards: where two translucent strips
## overlap their alpha composites, so every seam comes out darker than either neighbour and the scrim
## rasterizes as venetian blinds across the sky. A grid has no seams to hide, since adjacent quads share
## their edge vertices and those vertices' colours, so the hardware interpolates one continuous field
## and the falloff can be smoothstepped on both axes, putting a zero derivative at every outer edge.
func _draw_scrim(core_half: float, y: float, a: float) -> void:
	var cx: float = CANVAS.x * 0.5
	var top: float = y - SCRIM_ABOVE
	var bot: float = y + SCRIM_BELOW
	var half_w: float = core_half + SCRIM_FEATHER
	var xstep: float = half_w * 2.0 / float(SCRIM_COLS)
	var ystep: float = (bot - top) / float(SCRIM_ROWS)
	for r: int in SCRIM_ROWS:
		var y0: float = top + ystep * float(r)
		var y1: float = y0 + ystep
		var v0: float = _scrim_v(y0, top, bot)
		var v1: float = _scrim_v(y1, top, bot)
		if maxf(v0, v1) <= 0.004:
			continue
		for c: int in SCRIM_COLS:
			var x0: float = cx - half_w + xstep * float(c)
			var x1: float = x0 + xstep
			var h0: float = _scrim_h(x0 - cx, core_half)
			var h1: float = _scrim_h(x1 - cx, core_half)
			if maxf(h0, h1) <= 0.004:
				continue
			draw_polygon(
				PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
				PackedColorArray([_scrim_c(h0 * v0, a), _scrim_c(h1 * v0, a),
					_scrim_c(h1 * v1, a), _scrim_c(h0 * v1, a)]))


## Full weight across the core, smoothly out to nothing across the feather.
func _scrim_h(dx: float, core_half: float) -> float:
	return 1.0 - smoothstep(core_half, core_half + SCRIM_FEATHER, absf(dx))


## ...and a bell down the plate so it has no top or bottom edge either.
func _scrim_v(yy: float, top: float, bot: float) -> float:
	return 1.0 - smoothstep(0.0, 1.0, absf(yy - (top + bot) * 0.5) / maxf((bot - top) * 0.5, 0.001))


func _scrim_c(weight: float, a: float) -> Color:
	return Color(0.02, 0.025, 0.04, SCRIM_ALPHA * a * weight)


## Letter-tracked text. `draw_string` has no tracking, and tracking is the whole difference between
## small type that reads as a label and small type that reads as a caption.
## The fast-forward chip, top-left: a small "▶▶ Nx" tag shown only while the game clock is sped up, so a
## visibly racing world has an on-screen cause. Hidden at 1x to keep the default screen calm.
func _draw_fastforward() -> void:
	if time_scale <= 1.0:
		return
	var label: String = "▶▶ %dx" % int(time_scale)
	var tw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var chip := Rect2(10.0, 34.0, tw + 24.0, 22.0)   # under the depth chip, which owns the corner
	_panel(chip)
	draw_string(_font, chip.position + Vector2(12.0, 15.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI_TEXT)


## The FORGED production chip, top-right: an ingot swatch and the lifetime ingot count in a small panel,
## on the same skin as the inspector and the minimap rather than as bare floating text.
##
## Its width sits on its own too, being the other wall the objective banner has to stay inside of.
func _forged_chip_w() -> float:
	var label_w: float = _font.get_string_size("FORGED", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var count_w: float = _font.get_string_size(str(int(sim.total_produced.get(&"ingot", 0))),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	return 12.0 + 14.0 + 8.0 + label_w + 8.0 + count_w + 12.0


func _draw_forged() -> void:
	var n: int = int(sim.total_produced.get(&"ingot", 0))
	var count: String = str(n)
	var label_w: float = _font.get_string_size("FORGED", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var w: float = _forged_chip_w()
	var chip := Rect2(CANVAS.x - w - 10.0, 8.0, w, 22.0)
	_panel(chip)
	var x: float = chip.position.x + 12.0
	var cy: float = chip.position.y + chip.size.y * 0.5
	draw_rect(Rect2(x, cy - 6.0, 12.0, 12.0), Visuals.item_color(&"ingot"))
	draw_rect(Rect2(x, cy - 6.0, 12.0, 12.0), Color(0.0, 0.0, 0.0, 0.4), false, 1.0)
	x += 14.0 + 8.0
	draw_string(_font, Vector2(x, cy + 5.0), "FORGED", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI_TEXT_DIM)
	x += label_w + 8.0
	draw_string(_font, Vector2(x, cy + 6.0), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI_TEXT)


## How long a fresh step shows its full how-to line, how long that takes to fade, and how long you have
## to sit on one step before it comes back.
const HINT_HOLD: float = 9.0
const HOVER_MAX_W: float = 300.0   ## the inspector may grow to fit its widest line, but no further
## ...and never shrinks below this, so a one-word machine name still reads as a panel rather than a
## chip. It is named because `check_hud_layout` needs the same number to reason about the right column,
## and a check that re-types a literal is checking its own arithmetic against itself.
const HOVER_MIN_W: float = 218.0
const HINT_FADE: float = 1.5
const HINT_STUCK: float = 40.0

## The permanent objective plate is retired after the opening lesson.
##
## The problem was permanence rather than existence. The game may say what has just become possible, but
## it may not stand over the player while they do it. The how-to line already behaved that way, holding,
## fading and returning on a stall; the goal line sat at top-centre through every step.
##
## After the opening lesson nothing is offered. Later steps do not announce, hold or fade, and guidance
## becomes reactive, returning only once the player has genuinely stalled. The world carries it
## meanwhile, since `world_renderer._draw_guide_targets()` pulses a ring on the cells the step points at.
##
## `GOAL_PERSISTS_THROUGH` is how many steps count as the opening lesson and keep the permanent plate,
## so nobody is stranded on the first thing they ever see. At 1 that is the first step only; raise it to
## teach for longer, or set it to 0 to remove the plate entirely.
const GOAL_FADE: float = 1.2       ## how long reactive guidance takes to arrive once you have stalled
const GOAL_PERSISTS_THROUGH: int = 1


## The objective line, top-centre: the current step only as a gentle nudge, and a pure read of the
## Objectives tracker. Top-centre sits over open sky, so it never buries the avatar. When the whole
## chain is done it shows a brief "all set" and then auto-hides.
##
## The banner leads with the short goal, "Mine 4 ore", which is all a player needs once they know the
## verb, and carries the full how-to underneath only while that is wanted: for the first few seconds
## after a step opens and again once you have been stuck long enough to want it back. In between the
## world does the talking. The pulsing target ring already points at where the step happens.
func _draw_objective_line() -> void:
	if objectives == null:
		return
	if objectives.all_done() and objectives.done_for() > 5.0:
		return  # finished + lingered → clear the screen for veterans
	# The big map is the screen. It is centred and 272 tall in a 360 canvas, so its panel top sits at y=41
	# while this banner reaches y=45 whenever its how-to line is up, and whether the how-to is up depends
	# on `step_age`, which made the collision intermittent. Standing down here fixes it for every timing
	# rather than nudging the map: someone who opened the whole-world view is looking at the world.
	if minimap_large:
		return
	var text: String
	var col: Color
	var hint: String = ""
	var hint_a: float = 0.0
	var goal_a: float = 1.0
	if objectives.all_done():
		text = "✓  All set — keep digging deeper."
		col = Color(0.62, 0.86, 0.58)
	else:
		var step: Dictionary = objectives.steps[objectives.current_index()]
		text = str(step["goal"])
		col = Color(0.97, 0.93, 0.78)
		var age: float = objectives.step_age
		# Reactive guidance, the only thing a later step may put on screen. It arrives once you have sat on a
		# step long enough to want it and it is zero until then.
		var stalled: float = clampf((age - HINT_STUCK) / GOAL_FADE, 0.0, 1.0)
		if objectives.current_index() < GOAL_PERSISTS_THROUGH:
			# The opening lesson keeps the plate, and the how-to that arrives with it and fades.
			if age < HINT_HOLD + HINT_FADE:
				hint_a = clampf((HINT_HOLD + HINT_FADE - age) / HINT_FADE, 0.0, 1.0)
			elif age > HINT_STUCK:
				hint_a = stalled
		else:
			goal_a = stalled                     # nothing is offered after the first lesson
			hint_a = stalled
		if hint_a > 0.0:
			hint = str(step["label"])
	if goal_a <= 0.0 and hint_a <= 0.0:
		return                                    # nothing to say: leave the sky alone
	var fs: int = 13
	var hfs: int = 10
	var pad: float = 12.0
	# The free span. The banner is centred between two fixed chips, depth on the left and FORGED on the
	# right, so a long how-to line grows symmetrically until the plate's frame runs under one and through
	# the other. Clamp to what is actually free and let the how-to be the part that gives, because the
	# goal is the half you need.
	var free_w: float = CANVAS.x - (maxf(_depth_chip_w(), _forged_chip_w()) + 18.0) * 2.0
	text = _fit_text(text, fs, free_w - pad * 2.0 - 14.0)
	hint = _fit_text(hint, hfs, free_w - pad * 2.0)
	var tw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0
	var hw: float = _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs).x if hint != "" else 0.0
	var w: float = minf(maxf(tw, hw) + pad * 2.0, free_w)
	var h: float = 24.0 + (13.0 if hint != "" else 0.0)
	var rect := Rect2((CANVAS.x - w) * 0.5, 8.0, w, h)
	_panel(rect, maxf(goal_a, hint_a))   # the skin is as present as its most visible line
	var cy: float = rect.position.y + 12.0
	# The bullet belongs to the sentence, so it is drawn in the sentence's ink. It used to be the accent,
	# which put "the thing you can act on" on a banner that takes no input at all, a few dozen pixels
	# from a lit hotbar slot on the bare screen that does. Nor was the colour carrying the state: the
	# state is the dot's presence, since a finished ladder draws a tick inside the line instead of a dot
	# beside it. The colour here was free, and free is not a reason to spend the one colour that means
	# something. 8.25:1 against this plate before, 15.91:1 now.
	if not objectives.all_done():
		draw_circle(Vector2(rect.position.x + pad + 1.0, cy), 3.0, Color(col, col.a * goal_a))
	draw_string(_font, Vector2(rect.position.x + pad + 14.0, cy + 5.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, col.a * goal_a))
	if hint != "":
		draw_string(_font, Vector2(rect.position.x + pad, cy + 18.0), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, Color(UI_TEXT_DIM, hint_a))


## Trim a string until it fits `max_w`, with an ellipsis standing in for what was cut. It is
## deliberately not a binary search: these are one-line labels, the loop runs a handful of times, and a
## wrong answer here is a sentence running off a panel rather than a frame-rate problem.
func _fit_text(text: String, size: int, max_w: float) -> String:
	if text == "" or max_w <= 0.0:
		return text
	if _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w:
		return text
	var cut: String = text
	while cut.length() > 1:
		cut = cut.substr(0, cut.length() - 1)
		if _font.get_string_size(cut + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w:
			return cut.strip_edges(false, true) + "…"
	return "…"


## Layout probe. While `probing` is set, every panel drawn this frame appends its rect here and nothing
## else changes. The HUD is immediate-mode with no Control nodes so nothing about the layout can be read
## off the scene tree. A layout check that re-derived where each chip goes would agree with itself by
## construction and catch nothing. These two lines let `check_hud_layout` observe the boxes the HUD
## actually drew, at real screen size, in the real scene.
##
## The flag is the whole guard because the one it replaces could never be false. `if panel_probe != null:`
## reads as "unset" but a `static var panel_probe: Array[Rect2]` initialises to `[]` and in GDScript
## `[] != null` is true, checked against 4.6.2 rather than assumed. The guard therefore fell open on
## every frame of every real session: one Rect2 per panel, six to ten panels a frame at 60fps, into a
## static array nothing clears. Fixtures set `Hud.probing = true` and `check_hud_layout` asserts that it
## is false by default and that the probes stay empty when it is.
static var probing: bool = false
static var panel_probe: Array[Rect2]

## The hotbar, measured the same way and for the same reason. It reports rectangles. The first version
## reported a count, which was worth nothing: `wells += 1` sat unconditionally inside `for k in n`, so
## the count could only ever equal `n`, itself `clampi(carried, 1, INVENTORY_SLOTS)`. That is arithmetic.
##
## Geometry can disagree. Had `sx` been derived from the pack index rather than the window slot, the
## wells would have marched off the end of their own backing and off the canvas without moving any
## count. The keys: `carried` is the item types held; `wells` every drawn slot rect in draw order; `sel`
## the active index; `sel_lit` whether any drawn well lit up as the selection; `window` the pack index
## the first well shows; `backing` the framed rect; `label` the selected item's name plate or a zero
## Rect2 when none was drawn. The bar's early returns leave it untouched so an empty probe under
## `probing` means the bar did not draw.
static var hotbar_probe: Dictionary


## A framed, lightly bevelled panel backing: the shared skin for every HUD widget. A faint lit top edge
## makes it read as raised rather than as a flat sticker. `alpha` modulates the whole skin so a panel
## can fade rather than blink out. Panels that fade fully are expected to return before calling this at
## all, so the probe records only what was really drawn.
##
## A panel does not wear the selection colour. This used to take an `accent` flag that drew a 2px
## `UI_ACCENT` rule across the top. Eight surfaces asked for it: PAUSED, the title's choices card, the
## fast-forward chip, the objective line, the dashboard, the help page, settings and the hotbar backing.
## A mark that appears on eight things marks nothing. What made panels read as raised was never the gold
## anyway. It is `UI_EDGE_HI`, the one-pixel bevel along the top.
##
## The parameter is removed rather than defaulted to false. A flag with no caller is a switch waiting to
## be flipped back by someone reading it as an available option.
func _panel(rect: Rect2, alpha: float = 1.0) -> void:
	if probing:
		panel_probe.append(rect)
	draw_rect(rect, Color(UI_BG, UI_BG.a * alpha))
	draw_line(rect.position + Vector2(1.0, 1.0), rect.position + Vector2(rect.size.x - 1.0, 1.0),
		Color(UI_EDGE_HI, UI_EDGE_HI.a * alpha), 1.0)
	draw_rect(rect, Color(UI_EDGE, UI_EDGE.a * alpha), false, 1.0)


## The machine inspector, top-right under FORGED, shown when you aim at one of your machines in reach.
## It names the machine and shows its recipe as item chips, inputs to outputs, or its routing mode, plus
## what it is holding. Machines with a knob also draw clickable rows such as the splitter's three ratio
## chips or a filtered hopper's [clear] chip, and machines with a fill draw a real bar. MainView pins
## the hover while the cursor crosses onto this panel so the knobs are reachable. Clicks land through
## `hover_click()` because every mutation stays a discrete sim call out there.
func _draw_hover() -> void:
	_knob_hits.clear()
	_hover_rect = Rect2()
	# Called every frame rather than from inside the not-modal branch, because those two clears are frame
	# hygiene. Skip the call and the knob hit-boxes and the panel rect survive into a frame that never drew
	# them, so a click lands on a control no longer on screen. The call stays and the drawing leaves
	# instead, since `main.gd` recomputes `hover_info` off the world aim whichever menu is up.
	if _modal_open():
		return
	if hover_info.is_empty():
		return
	# The big map is the screen, the third element to take this rule after the goal plate and the pack bar.
	# It stands down before the rect is built so `_hover_rect` stays empty and `_cursor_on_hover_panel()`
	# reports false; otherwise the config-panel pin in MainView's frame sync would latch a machine nobody
	# can see.
	#
	# A modal earns the same stand-down, and it has to happen here rather than at the call site. The rect
	# is a click region, so a skipped call leaves the last one behind and a click on the counter lands on
	# an invisible knob. You also cannot aim at a machine while a plate covers the world.
	if minimap_large or _modal_open():
		return
	var ins: Array = hover_info.get("in", [])
	var outs: Array = hover_info.get("out", [])
	var holding: Array = hover_info.get("holding", [])
	var knobs: Array = hover_info.get("knobs", [])
	var bar: Dictionary = hover_info.get("bar", {})
	var has_recipe: bool = not ins.is_empty() or not outs.is_empty()
	var has_mode: bool = hover_info.has("mode") and str(hover_info["mode"]) != ""
	var has_rate: bool = hover_info.has("rate")
	var pad: float = 9.0
	var line_h: float = 18.0
	# The panel takes the width of its widest line. It is anchored to the right edge of the canvas, so a
	# line overflowing a fixed 218px ran off the screen: "too hard for your pick, craft a Stone Pickaxe",
	# the most important sentence the inspector says, came out as "craft a Stone Pick". It is capped now,
	# and anything past the cap is ellipsized rather than lost off the edge.
	var name_text: String = str(hover_info.get("name", ""))
	var mode_text: String = str(hover_info.get("mode", "")) if has_mode else ""
	var rate_text: String = str(hover_info.get("rate", "")) if has_rate else ""
	var widest: float = _font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	for line: String in [mode_text, rate_text]:
		if line != "":
			widest = maxf(widest, _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
	var width: float = clampf(widest + pad * 2.0, HOVER_MIN_W, HOVER_MAX_W)
	name_text = _fit_text(name_text, 13, width - pad * 2.0)
	mode_text = _fit_text(mode_text, 11, width - pad * 2.0)
	rate_text = _fit_text(rate_text, 11, width - pad * 2.0)
	var rows: int = 1 + int(has_recipe) + int(has_mode) + int(not holding.is_empty()) + int(has_rate) \
		+ knobs.size() + int(not bar.is_empty())
	# This sits below whatever occupies the top-right column: the corner minimap if it is shown, otherwise
	# the FORGED chip. Centred does not mean narrow. At 128x128 the large map spans x 181..459 while this
	# panel is right-anchored with a `HOVER_MIN_W` floor, so its left edge is at most 640 - 218 - 12 = 410,
	# and the measured overlap was 49x50, reachable in ordinary play. `_draw_hover` returns early under the
	# large map so the `else 34.0` fallback below only runs for the corner form.
	var mini_bottom: float = minimap_frame().end.y if (show_minimap and not minimap_large) else 34.0
	var origin := Vector2(CANVAS.x - width - 12.0, mini_bottom + 10.0)
	_hover_rect = Rect2(origin, Vector2(width, 10.0 + float(rows) * line_h + 4.0))
	_panel(_hover_rect)
	var x0: float = origin.x + pad
	var y: float = origin.y + 8.0 + 12.0
	draw_string(_font, Vector2(x0, y), name_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.92, 0.80))
	y += line_h
	if has_recipe:
		var x: float = _chips(x0, y, ins)
		x = _arrow(x, y)
		_chips(x, y, outs)
		y += line_h
	if has_mode:
		draw_string(_font, Vector2(x0, y), mode_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.66, 0.80, 0.90))
		y += line_h
	if not holding.is_empty():
		var hx: float = draw_string_pos(x0, y, "holds")
		_chips(hx, y, holding)
		y += line_h
	if has_rate:
		draw_string(_font, Vector2(x0, y), rate_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.72, 0.42))
		y += line_h
	if not bar.is_empty():
		var br := Rect2(x0, y - 11.0, width - pad * 2.0, 12.0)
		draw_rect(br, Color(0.0, 0.0, 0.0, 0.45))
		draw_rect(Rect2(br.position, Vector2(br.size.x * clampf(float(bar.get("frac", 0.0)), 0.0, 1.0),
			br.size.y)), Color(0.62, 0.42, 0.95, 0.85))
		draw_rect(br, Color(0.0, 0.0, 0.0, 0.5), false, 1.0)
		draw_string(_font, Vector2(x0 + 3.0, y - 1.0), str(bar.get("label", "")),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.94, 0.99))
		y += line_h
	var mouse: Vector2 = Controls.pointer_viewport(self)
	for knob: Variant in knobs:
		var k: Dictionary = knob
		var x: float = x0
		if k.get("kind", "") == "choice":
			x = draw_string_pos(x, y, str(k.get("label", "")))
			var options: Array = k.get("options", [])
			for i: int in options.size():
				var text: String = str(options[i])
				var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10.0
				var chip := Rect2(x, y - 12.0, w, 15.0)
				var current: bool = i == int(k.get("current", -1))
				var lit: bool = chip.has_point(mouse)
				draw_rect(chip, Color(0.93, 0.78, 0.30) if current
					else (Color(0.30, 0.34, 0.44) if lit else Color(0.16, 0.18, 0.24)))
				draw_rect(chip, Color(0.0, 0.0, 0.0, 0.5), false, 1.0)
				draw_string(_font, Vector2(x + 5.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
					Color(0.10, 0.10, 0.12) if current else Color(0.90, 0.92, 0.96))
				_knob_hits.append({"rect": chip, "payload": {"knob": "choice", "index": i}})
				x += w + 5.0
		elif k.get("kind", "") == "action":
			var text2: String = str(k.get("label", ""))
			var w2: float = _font.get_string_size(text2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0
			var chip2 := Rect2(x, y - 12.0, w2, 15.0)
			draw_rect(chip2, Color(0.34, 0.30, 0.22) if chip2.has_point(mouse) else Color(0.22, 0.20, 0.16))
			draw_rect(chip2, Color(0.93, 0.78, 0.30, 0.55), false, 1.0)
			draw_string(_font, Vector2(x + 6.0, y), text2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				Color(0.95, 0.88, 0.62))
			_knob_hits.append({"rect": chip2, "payload": {"knob": "action", "id": k.get("id", "")}})
		y += line_h


## The inspector's on-canvas rect this frame, where Rect2() means not shown. MainView uses it to pin the
## hover while the cursor travels onto the panel, under the same "the open map is UI" rule.
func hover_panel_rect() -> Rect2:
	return _hover_rect


## The knob payload under a canvas point, or {} for none. MainView reads it on LMB; the HUD never
## touches the sim, and the controller turns the payload into a discrete sim call.
func hover_click(canvas_pos: Vector2) -> Dictionary:
	for hit: Dictionary in _knob_hits:
		if (hit["rect"] as Rect2).has_point(canvas_pos):
			return hit["payload"]
	return {}


## Draw a run of item chips (a colour swatch + count) left-to-right; returns the x just past them.
func _chips(x0: float, y: float, items: Array) -> float:
	var x: float = x0
	for entry: Dictionary in items:
		var item: StringName = entry["item"]
		var sw := Rect2(x, y - 11.0, 12.0, 12.0)
		if machine_icons.has(item):
			draw_rect(sw, machine_icons[item]["color"])
		else:
			draw_rect(sw, Visuals.item_color(item))
		draw_rect(sw, Color(0.0, 0.0, 0.0, 0.4), false, 1.0)
		var label: String = " %d" % int(entry["count"])
		draw_string(_font, Vector2(x + 14.0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.92, 0.93, 0.96))
		x += 14.0 + _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0
	return x


func _arrow(x: float, y: float) -> float:
	draw_string(_font, Vector2(x, y), "->", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.70, 0.74, 0.82))
	return x + _font.get_string_size("->", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8.0


func draw_string_pos(x: float, y: float, text: String) -> float:
	draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.62, 0.66, 0.74))
	return x + _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8.0


## Where the minimap sits right now, in canvas space: corner and small, or large and centred. It is
## public so MainView can route map clicks to the ping and keep world verbs off the map.
##
## Both forms fit the world's aspect inside a box rather than deriving one side from the other. A corner
## map sized by width alone was fine while the world was 96x80 and became a 150x150 slab down half the
## screen the moment it went square. A corner element has a height budget as much as a width one.
func minimap_frame() -> Rect2:
	var world := Vector2(float(FactorySim.GRID_COLS), float(FactorySim.GRID_ROWS))
	if minimap_large:
		var big: Vector2 = _fit(world, Vector2(360.0, 272.0))
		return Rect2((CANVAS - big) * 0.5, big)
	var small: Vector2 = _fit(world, Vector2(MINI_W, MINI_H))
	return Rect2(Vector2(CANVAS.x - small.x - 12.0, MINI_TOP), small)


## The largest rect with `aspect`'s proportions that fits inside `box`.
func _fit(aspect: Vector2, box: Vector2) -> Vector2:
	return aspect * minf(box.x / aspect.x, box.y / aspect.y)


## The minimap, on M for the corner form and M again for the large one. It is a cached image of the
## whole world: solid cells in their material colour; carved cells as a dim wall backing; open sky as
## void. Over that go live overlays for the depth bands, your machines, Bazaar diamonds, a pulsing
## breach marker on every opened way down, your ping, the visible window and you. The terrain image
## rebuilds only when you dig so the per-frame cost is one textured blit.
func _draw_minimap() -> void:
	if sim == null or not minimap_color.is_valid():
		return
	if _minimap_tex == null or sim.solid.size() != _minimap_solid_count:
		_minimap_solid_count = sim.solid.size()
		_rebuild_minimap()
	var cols: float = float(FactorySim.GRID_COLS)
	var rows: float = float(FactorySim.GRID_ROWS)
	var frame: Rect2 = minimap_frame()
	var origin: Vector2 = frame.position
	_panel(frame.grow(3.0))
	draw_texture_rect(_minimap_tex, frame, false)
	var scale := Vector2(frame.size.x / cols, frame.size.y / rows)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)   # cosmetic clock, HUD only
	# --- depth bands: the layer ladder made legible at a glance ---
	var seal_y: float = origin.y + float(LayeredWorldGen.SEAL_TOP) * scale.y
	var seal_h: float = maxf(float(LayeredWorldGen.SEAL_ROWS) * scale.y, 1.5)
	draw_rect(Rect2(origin.x, seal_y + seal_h, frame.size.x, frame.end.y - (seal_y + seal_h)),
		Color(0.35, 0.50, 0.95, 0.10))                                  # Stonereach: a cold wash
	draw_rect(Rect2(origin.x, seal_y, frame.size.x, seal_h), Color(0.62, 0.42, 0.85, 0.55))  # the seal
	# The descent chart. Every band Strata knows about gets a hairline at its ceiling and its own name in
	# its own colour, so the map answers "how far down does this go and what is between here and there" at
	# a glance. It used to name TOPSOIL and STONEREACH only, and put the first of them immediately above
	# the seal, which is deepslate, sixty rows from any topsoil.
	if minimap_large:
		for i: int in range(1, Strata.BANDS.size()):     # skip OPEN SKY: it has no ceiling to draw
			var band: Dictionary = Strata.BANDS[i]
			var by: float = origin.y + float(int(band["from"])) * scale.y
			if by < origin.y or by > frame.end.y - 6.0:
				continue
			var tint: Color = band["color"]
			draw_line(Vector2(origin.x, by), Vector2(frame.end.x, by), Color(tint, 0.30), 1.0)
			# A thin band, and the seal is two rows, would stack its name on the one below it. Every band keeps
			# its line, and the one that loses its text is the shallower of a colliding pair, because the deeper
			# name tells you what you are about to be in.
			if i + 1 < Strata.BANDS.size():
				var next_y: float = origin.y + float(int(Strata.BANDS[i + 1]["from"])) * scale.y
				if next_y - by < 9.0:
					continue
			draw_string(_font, Vector2(origin.x + 5.0, by + 8.0), str(band["name"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(tint, 0.80))
			var depth: String = "%d m" % Strata.depth_m(int(band["from"]))
			var dw: float = _font.get_string_size(depth, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			draw_string(_font, Vector2(frame.end.x - dw - 5.0, by + 8.0), depth,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(tint, 0.55))
	# --- aquifers: the flooded pockets that guard rich ore, in a cool cyan-blue clear of the amber power
	# wash, the gold bazaars and the violet seal, with alpha scaling by fill so deep water reads solid and
	# a puddle reads faint. It is a live overlay, since water flows each tick rather than in the bake.
	var wcell: Vector2 = Vector2(maxf(scale.x, 1.0), maxf(scale.y, 1.0)).ceil()
	for water_cell_v: Variant in sim.water:
		var water_cell: Vector2i = water_cell_v
		var fill: float = clampf(float(sim.water[water_cell]) / float(FactorySim.WATER_MAX), 0.0, 1.0)
		draw_rect(Rect2(origin + Vector2(water_cell) * scale, wcell),
			Color(0.25, 0.62, 0.95, 0.30 + 0.45 * fill))
	# --- frontier reach: where the factory's power and placed light actually extend. Power is a warm amber
	# wash per powered cell, brighter for more units and read off the derived `sim.power` field, and placed
	# torches are small warm halos. The alphas stay subtle so terrain reads under the claim.
	for pcell_v: Variant in sim.power:
		var pcell: Vector2i = pcell_v
		var lvl: float = clampf(float(sim.power[pcell]) / FactorySim.GENERATOR_POWER, 0.12, 1.0)
		draw_rect(Rect2(origin + Vector2(pcell) * scale, scale.ceil()),
			Color(1.0, 0.70, 0.22, 0.10 + 0.24 * lvl))
	var halo: float = maxf(scale.x, scale.y) * 2.6
	for tcell_v: Variant in sim.torch:
		draw_circle(origin + (Vector2(tcell_v as Vector2i) + Vector2(0.5, 0.5)) * scale, halo,
			Color(1.0, 0.80, 0.42, 0.16))
	# --- your placed machines ---
	var dot := Vector2(maxf(scale.x, 2.0), maxf(scale.y, 2.0))
	for m: MachineState in sim.machines:
		draw_rect(Rect2(origin + Vector2(m.cell) * scale, dot), Visuals.machine_color(m.def))
	# --- bazaars: the crafting hubs wear a gold diamond ---
	for o: Vector2i in sim.find_bazaars():
		_map_diamond(origin + (Vector2(o) + Vector2(float(FactorySim.BAZAAR_W) * 0.5, 1.0)) * scale,
			3.5, Color(0.98, 0.84, 0.35))
	# --- breach markers: every opened way down pulses violet (find it again from anywhere) ---
	for m: MachineState in sim.machines:
		if m.def.behavior == &"descent" and m.fed >= FactorySim.DESCENT_QUOTA:
			_map_diamond(origin + (Vector2(m.cell) + Vector2(0.5, 0.5)) * scale,
				3.0 + pulse * 2.5, Color(0.80, 0.55, 1.0, 0.55 + 0.45 * pulse))
	# --- your ping ---
	if ping_world.x != INF:
		var pc: Vector2 = origin + ping_world / CELL * scale
		draw_line(pc + Vector2(-4.0, 0.0), pc + Vector2(4.0, 0.0), Color(0.45, 0.95, 1.0), 1.0)
		draw_line(pc + Vector2(0.0, -4.0), pc + Vector2(0.0, 4.0), Color(0.45, 0.95, 1.0), 1.0)
		draw_arc(pc, 4.0 + pulse * 3.0, 0.0, TAU, 20, Color(0.45, 0.95, 1.0, 0.9 - pulse * 0.5), 1.0)
	if minimap_view.length() > 1.0:                            # the visible window
		var half: Vector2 = minimap_view * 0.5 / CELL
		var fc: Vector2 = minimap_focus / CELL
		var vr := Rect2(origin + (fc - half) * scale, minimap_view / CELL * scale)
		draw_rect(vr.intersection(frame), Color(1.0, 1.0, 1.0, 0.55), false, 1.0)
	var you := origin + minimap_focus / CELL * scale           # you-are-here marker
	draw_rect(Rect2(you - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color(0.97, 0.86, 0.36))
	draw_rect(Rect2(you - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color(0.10, 0.08, 0.0), false, 1.0)
	if minimap_large:
		var cap: String = "click the map to ping · M cycles size"
		var cw: float = _font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_rect(Rect2(origin.x + 3.0, frame.end.y - 17.0, cw + 10.0, 14.0), Color(0.05, 0.06, 0.09, 0.8))
		draw_string(_font, Vector2(origin.x + 8.0, frame.end.y - 6.0), cap,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_DIM)


## A small filled diamond, the minimap's icon shape, which reads at 3-5px where a square blurs into rock.
func _map_diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r, 0.0),
		c + Vector2(0.0, r), c + Vector2(-r, 0.0)]), col)


## Rebuild the cached terrain image at one pixel per cell: solid takes the material colour, dug-but-
## walled takes a dim wall backing, and open sky is void. Cheap, and it runs only when terrain changes.
func _rebuild_minimap() -> void:
	var w: int = FactorySim.GRID_COLS
	var h: int = FactorySim.GRID_ROWS
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var cell := Vector2i(x, y)
			var c: Color
			if sim.is_solid(cell):
				c = minimap_color.call(sim.material_at(cell))
			elif sim.wall_at(cell) != &"":
				c = (minimap_color.call(sim.wall_at(cell)) as Color).darkened(0.5)
			else:
				c = Color(0.09, 0.11, 0.16)
			img.set_pixel(x, y, c)
	_minimap_tex = ImageTexture.create_from_image(img)


## The detail plate lives on `BazaarPage` now, with its own twenty helpers and thirty-three constants.
## These two stay because the shell still calls them: the plate's wanted height feeds the panel geometry,
## and `_draw` reaches the plate through here. Both go when the shell follows.
## Which machine a counter row resolves to. The page owns the resolution; this address stays because
## `tools/check_row_identity.gd` probes rows through the Hud, and that layer exists to turn the
## same-length coincidence between `craft_ids` and `craft_options` into a checked property.
func _craft_id(i: int) -> StringName:
	return _bazaar()._craft_id(i)


func _detail_wanted_h() -> float:
	return _bazaar()._detail_wanted_h()


func _draw_bazaar_detail(g: Dictionary) -> void:
	_bazaar()._draw_bazaar_detail(g)


## The counter, drawn as a lamp-lit object rather than as a dialog box: elevation instead of a border, a
## gradient instead of a fill, one accent doing one job, and a 0.13s rise on open.
func _draw_inventory_overlay() -> void:
	# Dimmed, not blacked. You are at a counter with a shopkeeper beside you and banners overhead, which
	# `scenes/bazaars.gd` stages block by block, so the world stays legible behind the panel instead of
	# being switched off. MainView blurs it in the same breath, which is what makes the panel read as
	# being in front of something.
	var t: float = _bazaar_ease()
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.02, 0.025, 0.04, 0.42 * t))
	_modal_vignette(0.5 * t)
	var g: Dictionary = _bazaar_geometry()
	var origin: Vector2 = g["origin"]
	var panel := Rect2(origin, Vector2(g["w"], g["h"]))
	# The whole counter rises the last few pixels into place. One transform, so nothing below has to know.
	draw_set_transform(Vector2(0.0, (1.0 - t) * 14.0), 0.0, Vector2.ONE)

	_soft_shadow(panel, 12, 0.34)
	_round_rect(panel, 8.0, UI_MODAL)
	_panel_sheen(panel)
	# The rail is the tab strip turned on its side and given room to be an object, since three icons you
	# can hit with a glance beat three words you have to read.
	_bazaar()._draw_bazaar_rail(origin, g)
	_draw_bazaar_head(origin, g)
	match bazaar_tab:
		TAB_WORKS:
			_bazaar()._tab_works(g)
		TAB_BENCH:
			# The picked tech is the shell's answer, not the bench's question: `bazaar_action` resolves the
			# focused row for every tab, so the bench is handed the id rather than reaching back for it.
			var bact: Dictionary = bazaar_action()
			_bazaar()._tab_bench(g, bact["id"] if bact.get("kind", "") == "tech" else &"")
		_:
			_bazaar()._tab_pack(g)
	_draw_bazaar_detail(g)
	_draw_bazaar_foot(origin, g)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _keycap(at: Vector2, key: String, fs: int = 8) -> float:
	return Visuals.keycap(self, _font, at, key, fs, panel_probe if probing else [])


## The counter's shell draws itself on `BazaarPage` now. These addresses stay because the Hud's own
## `_draw_inventory_overlay` and `_process` call them, and because `scenes/main.gd` and four checks in
## `tools/` reach the counter through the Hud rather than through the page.
func _bazaar_geometry() -> Dictionary:
	return _bazaar()._bazaar_geometry()


func _bazaar_wanted_h() -> float:
	return _bazaar()._bazaar_wanted_h()


func bazaar_move(dx: int, dy: int) -> void:
	_bazaar().bazaar_move(dx, dy)


func _draw_bazaar_head(origin: Vector2, g: Dictionary) -> void:
	_bazaar()._draw_bazaar_head(origin, g)


func _draw_bazaar_foot(origin: Vector2, g: Dictionary) -> void:
	_bazaar()._draw_bazaar_foot(origin, g)


func _modal_vignette(peak: float) -> void:
	_bazaar()._modal_vignette(peak)


# --- the tabs -------------------------------------------------------------------------------------------


## A machine's sprite or an item's glyph, whichever this id is. The pack grid, the works rows and the
## tech chips all want exactly this and used to each carry their own copy of it.

## Bound on entry rather than at startup, for the reason the settings page is: `probing` is a static a
## fixture flips between frames, and a snapshot would go stale between them.
func _bazaar() -> BazaarPage:
	_bazaar_page._canvas = self
	_bazaar_page._font = _font
	_bazaar_page._sim = sim
	_bazaar_page._icons = machine_icons
	_bazaar_page._inv_selected = inv_selected_getter
	_bazaar_page._bazaar_h = _bazaar_h
	_bazaar_page.can_craft = can_craft
	_bazaar_page.probing = probing
	_bazaar_page.panel_probe = panel_probe
	return _bazaar_page


## THE COUNTER, WHICH LIVES IN `BazaarPage` AND IS REACHED THROUGH HERE.
##
## The model moved first and the tabs follow it. What stays is the address: one forwarder per name that
## `scenes/main.gd` or a tool has always called, and the properties above for the state they read.

func open_machines() -> Array[int]:
	return _bazaar().open_machines()


func open_rack() -> Array[int]:
	return _bazaar().open_rack()


func works_columns(rows: int) -> Dictionary:
	return _bazaar().works_columns(rows)


static func works_window_first(count: int, capacity: int, base: int, cursor: int) -> int:
	return BazaarPage.works_window_first(count, capacity, base, cursor)


func bazaar_row_count() -> int:
	return _bazaar().bazaar_row_count()


func bazaar_action() -> Dictionary:
	return _bazaar().bazaar_action()


func set_bazaar_tab(tab: int) -> void:
	_bazaar().set_bazaar_tab(tab)


func _bazaar_ease() -> float:
	return _bazaar()._bazaar_ease()


## A word that is true of you, not a button you failed to press.
##
## `_verb_button` draws the right pair: one action, live or not yet. RESEARCHED and HELD are not that
## pair's second half. They are states with no verb behind them and in the same grey pill they read as
## an action whose button is broken, so the plate said AUTOMATION, already yours, RESEARCHED.
##
## So a state gets a form of its own and the difference in shape arrives before the difference in
## colour: no plate under it, a tick, and the green the ladder already paints what is yours in. Three
## marks now say three things across the counter. A gold pill is the verb you can run, a grey pill the
## verb you cannot run yet, and this is nothing to run.


# --- the detail plate -----------------------------------------------------------------------------------


# --- the bench ------------------------------------------------------------------------------------------


# --- the counter's surface primitives --------------------------------------------------------------------

## A real rounded rect. Composing one from a rect plus four circles double-blends every corner the
## moment the fill is translucent, which is exactly what a modern surface tint is.
func _round_rect(rect: Rect2, r: float, col: Color) -> void:
	# Rounded boxes are panels too. `panel_probe` used to see only `_panel()`, and the Bazaar is built
	# entirely out of these, so `check_hud_layout`'s "Bazaar open" row recorded the bare screen's four
	# panels and nothing else, and its headline claim, that the HUD must not print on top of itself, had
	# never covered the largest overlay in the game.
	#
	# THE PROBE STAYS HERE rather than moving with the drawing. It is a property of this page being
	# measured, not of how a rounded box is drawn, and `check_hud_layout` reaches for it on the Hud.
	if probing:
		panel_probe.append(rect)
	Visuals.round_rect(self, rect, r, col)


## The focus ring. Shape, weight and inset live in `Visuals.focus_ring`; the page supplies its own gold.
func _focus_ring(box: Rect2, grow: float = Visuals.FOCUS_GROW, spine: bool = false) -> void:
	Visuals.focus_ring(self, box, GOLD_PALE, UI_ACCENT, grow, spine)


## Elevation instead of a border. A modern panel does not outline itself, it casts, and concentric
## translucent rings are the cheap honest version of that, which is what stops the counter reading as
## printed on the world behind it.
func _soft_shadow(rect: Rect2, spread: int, peak: float) -> void:
	Visuals.soft_shadow(self, rect, spread, peak)


## One hairline of light along the top edge and a slow warm gradient down the plate. Those are the two
## marks that say which way the lamp is, which is the difference between a surface and a fill.
func _panel_sheen(rect: Rect2) -> void:
	Visuals.panel_sheen(self, rect)


## Letter-spaced type. Small caps with air between them is most of what separates a title from a label.
func _tracked(text: String, at: Vector2, size: int, track: float, col: Color) -> void:
	Visuals.tracked(self, _font, text, at, size, track, col)


## What `_tracked` actually occupies: the plain width plus one gap per letter. Measuring tracked type
## with `get_string_size` is how a caption ends up printed through its own title.
func _tracked_w(text: String, size: int, track: float) -> float:
	return Visuals.tracked_width(_font, text, size, track)


## The production dashboard, on G: the factory's whole output at a glance, so scaling is felt rather
## than guessed. Two columns, both pure sim reads. THROUGHPUT takes `production_rates()` as per-item
## /min bars, relative and absolute, sorted fastest first, with a grand total; FACTORY takes
## `machine_census()` as machines by type with a live working count. It is non-modal, a status read.
func _draw_dashboard_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.0, 0.0, 0.0, 0.5))
	var w: float = 392.0
	var h: float = 238.0
	var origin := Vector2((CANVAS.x - w) * 0.5, (CANVAS.y - h) * 0.5)
	_panel(Rect2(origin, Vector2(w, h)))
	draw_string(_font, origin + Vector2(14.0, 22.0), "PRODUCTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI_TEXT_DIM)
	draw_string(_font, origin + Vector2(w - 108.0, 21.0), "G / Esc to close",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)
	draw_line(origin + Vector2(206.0, 34.0), origin + Vector2(206.0, h - 12.0), UI_EDGE, 1.0)  # column rule

	# --- left column: THROUGHPUT, meaning is output growing? -------------------------------------
	var lx: float = origin.x + 14.0
	var rates: Array[Dictionary] = sim.production_rates()
	var grand: float = 0.0
	var top: float = 0.0
	for r: Dictionary in rates:
		grand += float(r["rate"])
		top = maxf(top, float(r["rate"]))
	draw_string(_font, Vector2(lx, origin.y + 48.0), "THROUGHPUT · last 60s",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_DIM)
	draw_string(_font, Vector2(lx, origin.y + 66.0), "%.1f" % grand, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI_TEXT)
	draw_string(_font, Vector2(lx + 4.0 + _font.get_string_size("%.1f" % grand,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, origin.y + 66.0), "items/min",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)
	if rates.is_empty():
		draw_string(_font, Vector2(lx, origin.y + 92.0), "nothing producing yet —",
			HORIZONTAL_ALIGNMENT_LEFT, 184.0, 10, UI_TEXT_DIM)
		draw_string(_font, Vector2(lx, origin.y + 106.0), "mine, or feed a machine.",
			HORIZONTAL_ALIGNMENT_LEFT, 184.0, 10, UI_TEXT_DIM)
	else:
		var y: float = origin.y + 84.0
		var bar_x: float = lx + 74.0
		var bar_w: float = 118.0
		for i: int in mini(9, rates.size()):                  # top nine, which is the panel's height budget
			var item: StringName = rates[i]["item"]
			var rate: float = float(rates[i]["rate"])
			Visuals.draw_item(self, Vector2(lx + 7.0, y - 3.0), 13.0, item)
			draw_string(_font, Vector2(lx + 16.0, y), _item_label(item), HORIZONTAL_ALIGNMENT_LEFT, 56.0, 9, UI_TEXT)
			var frac: float = rate / top if top > 0.0 else 0.0
			draw_rect(Rect2(bar_x, y - 8.0, bar_w, 9.0), UI_SLOT)   # bar well
			var col: Color = Visuals.item_color(item)
			draw_rect(Rect2(bar_x, y - 8.0, maxf(2.0, bar_w * frac), 9.0), col)
			draw_string(_font, Vector2(bar_x + 3.0, y - 0.5), "%.1f/min" % rate,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI_TEXT)
			y += 16.6

	# --- right column: FACTORY census, meaning how big and how healthy? --------------------------
	var rx: float = origin.x + 218.0
	var census: Array[Dictionary] = sim.machine_census()
	var total_m: int = sim.grid.size()
	var working_m: int = 0
	for c: Dictionary in census:
		working_m += int(c["working"])
	draw_string(_font, Vector2(rx, origin.y + 48.0), "FACTORY · %d machine%s" % [total_m,
		"" if total_m == 1 else "s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_DIM)
	if census.is_empty():
		draw_string(_font, Vector2(rx, origin.y + 70.0), "no machines built yet.",
			HORIZONTAL_ALIGNMENT_LEFT, 160.0, 10, UI_TEXT_DIM)
		draw_string(_font, Vector2(rx, origin.y + 84.0), "craft one (E), place it (RMB).",
			HORIZONTAL_ALIGNMENT_LEFT, 160.0, 10, UI_TEXT_DIM)
	else:
		# The summary is green when it is true, and it used to be green unconditionally. `0 working` sat in
		# the healthy colour directly above a row flagging the same machines as stalled, and a colour that is
		# the same for every value of the number beside it is not reporting the number.
		var all_up: bool = working_m >= total_m and total_m > 0
		draw_string(_font, Vector2(rx, origin.y + 63.0), "%d working" % working_m,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.78, 0.55) if all_up else UI_WARN)
		var y2: float = origin.y + 84.0
		for i: int in mini(9, census.size()):
			var row: Dictionary = census[i]
			var mdef: MachineDef = row["def"]
			var box := Rect2(rx, y2 - 11.0, 15.0, 15.0)
			draw_rect(box, Visuals.machine_color(mdef))
			Visuals.draw_machine_glyph(self, box.position + box.size * 0.5,
				Visuals.machine_kind(mdef), Visuals.glyph_cells_for(box.size.y), false, 0.0)
			draw_string(_font, Vector2(rx + 20.0, y2), str(row["name"]), HORIZONTAL_ALIGNMENT_LEFT, 96.0, 9, UI_TEXT)
			# The count and the working count: green when all are running, and the alert colour when some are
			# stalled. This used to draw `UI_ACCENT`, the colour this same panel uses for its heading and its
			# grand total, so a player who had learned that gold means "selected, available, yours" was shown a
			# fault in it, two rows under a gold number meaning the opposite. The left-edge alert stack reports
			# the same machines in `UI_WARN`, and now both say it the same way.
			var cnt: int = int(row["count"])
			var wrk: int = int(row["working"])
			var stat_col: Color = Color(0.55, 0.78, 0.55) if wrk == cnt else UI_WARN
			draw_string(_font, Vector2(rx + 118.0, y2), "%d" % cnt, HORIZONTAL_ALIGNMENT_RIGHT, 24.0, 10, UI_TEXT)
			draw_string(_font, Vector2(rx + 144.0, y2), "%d▸" % wrk, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, stat_col)
			y2 += 16.6


## The CONTROLS card's measurements, hoisted out of `_draw_help_overlay` so `check_hud_layout` can
## measure it. Text is the half a panel-rect test cannot see: every line is drawn inside a fixed-width
## column and a line wider than its column spills across the card while the panel it overflows still
## reports a perfectly legal rectangle.
## Column width for the card and the number `check_hud_layout` holds every line to.
const HELP_COL_W: float = 236.0
## Text size the card is drawn at, named so the measuring code cannot drift from the drawing code.
const HELP_TEXT_SIZE: int = 11

const HELP_LINES: Array[String] = [
	"move        A / D  (or ← →)",
	"jump        W  or  SPACE",
	"climb       W / S  on a rope (not a jump)",
	"grapple     F  at ringed rock · again to ride",
	"swing       W / S reel in / out · SPACE off",
	# The three techniques the winch grew. Each is taught in place by a hint the first time you are in the
	# situation, in scenes/hints.gd, but a lesson you can only be told once is a lesson you can miss, so
	# the card carries them too, in the same key-first voice as every line above it.
	"chain       F in mid-air — keeps your speed",
	"wrap        the line bends round corners",
	"catch       F while falling — ends the fall",
	"mine        LMB (hold)",
	"dig plan    LMB drag paints it · X clears",
	"select      1–9  ·  mouse wheel",
	"place/pick  RMB  (machine, rope, block)",
	"scan        RMB  (Scanner — veins echo)",
	"drop / feed  Q  (gravity feeds it in)",
	"counter     E  (pack · works · bench)",
	"  tabs      1 / 2 / 3   ·   mouse wheel",
	"  pick      arrows / WASD   ·   buy  ENTER",
	"bench       T  (straight to the tech ladder)",
	"configure   R  (aimed at a splitter / hopper)",
	"dashboard   G",
	"map         M  (again: LARGE · click it = ping)",
	"fast-fwd    .     (1x → 2x → 4x → 8x)",
	"save / load  F5 / F9",
	"pause       P     ·   help   H",
	"settings    ESC  (audio · shake · remap keys)",
	]


## The help overlay, on H or the slash key: the full control list, summoned rather than stuck on
## screen, on a centred card.
func _draw_help_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.0, 0.0, 0.0, 0.45))
	# Two columns, because one did not fit on the screen. At 16px a row this list is 25 rows and 440px tall
	# on a 360px canvas, centred, so it hung 40px off the top and 40px off the bottom, and the first and
	# last controls were simply not on screen. Splitting rather than shrinking is the right repair twice
	# over: a smaller font would have fitted the same wall of 25 rows into the same screen, and a wall of
	# rows is the thing this card should least be.
	var lines: Array[String] = HELP_LINES
	var half: int = int(ceil(float(lines.size()) * 0.5))
	var col_w: float = HELP_COL_W
	var w: float = col_w * 2.0 + 16.0
	var h: float = 30.0 + float(half) * 16.0 + 10.0
	var origin := Vector2((CANVAS.x - w) * 0.5, (CANVAS.y - h) * 0.5)
	_panel(Rect2(origin, Vector2(w, h)))
	draw_string(_font, origin + Vector2(14.0, 22.0), "CONTROLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI_TEXT_DIM)
	for i: int in lines.size():
		var col: int = i / half
		var row: int = i % half
		draw_string(_font, Vector2(origin.x + 16.0 + float(col) * col_w, origin.y + 38.0 + float(row) * 16.0),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, HELP_TEXT_SIZE, UI_TEXT)


## The settings page's own measurements live with the page, in `scenes/settings_page.gd`. Aliased
## here so the drawing below reads unchanged while there is one of each in the tree.

## The page's shape lives in `SettingsPage`, aliased here so the drawing below reads unchanged and there
## is still exactly one of each in the tree.
const CAT_AUDIO: int = SettingsPage.CAT_AUDIO
const CAT_CONTROLS: int = SettingsPage.CAT_CONTROLS
const CAT_FEEL: int = SettingsPage.CAT_FEEL
const CAT_NAMES: Array[String] = SettingsPage.CAT_NAMES

const REMAP_ROWS: Array[Array] = SettingsPage.REMAP_ROWS


const AUDIO_ROWS: Array[Array] = SettingsPage.AUDIO_ROWS
const FEEL_ROWS: Array[Array] = SettingsPage.FEEL_ROWS


## The two measurements of a slot, taken off the drawing that makes them. The word clears the tile by
## the font's own ascent, which is why the counter's word sits at 48 and not at the settings rail's 44,
## and the cap is hung so its key lands on that same baseline, leaving the cap's shadow as the lowest
## mark in the slot. Every one of these is read from the font at the size the rail actually draws,
## because a metric copied into a constant stops being true when the type changes.


## Where a rail's boxes sit, for a rail of any height and any number of slots. It is extracted from the
## counter's rail rather than copied into this one, because two rails computing their own pitch are two
## rails that eventually disagree.
##
## Neither measurement has a default any more. `min_pitch` used to default to 0.0 and the counter's rail
## was the caller that took the default, so the rail with the taller slot of the two was the one drawing
## without a floor. An optional argument is answered by whichever caller thought about it, which is
## never the caller that needed the answer.
##
## `slot_h` is what a slot draws below its own top, and it is here so a stack too tall for its rail
## comes back inside the panel rather than off the bottom of it: the floor clears the slot above, and
## this clears the panel's own edge. Where there is room to spare the first tile sits at `RAIL_TOP`.


## An action's human name. The table it reads lives on `SettingsPage` with the rest of the page's
## vocabulary; this stays because `MainView` has always asked the Hud for it.
static func action_label(action: StringName) -> String:
	return SettingsPage.action_label(action)


## A tiny dim hint, bottom-left, listing the toggle keys. It tells the player the menus exist without an
## always-on keyboard-reference footer hogging the whole bottom edge.
##
## It retires itself, one key at a time, and that is the point. The charge against this line was never
## that it is ugly at 10px and dim, but that it is permanent. A reference card that never leaves says
## the game expects you never to learn it, and it sits in the corner of every screenshot. So each entry
## disappears the first time you press that key, and when the last one goes the line goes with it.
##
## It is deliberately not written to the save. Which keys a player has pressed is not world state. It is
## a teaching aid whose cost of being wrong is one dim line for four seconds.
const HINT_KEYS: Array = [
	[Controls.GRAPPLE, "F hook"], [Controls.DROP, "Q drop"], [Controls.CRAFT, "E pack"],
	[Controls.MAP, "M map"], [Controls.HELP, "H keys"],
]

var _hint_used: Dictionary = {}          ## action -> true, once the player has pressed it


## Called from the input handler when one of the hinted actions fires. Unknown actions are ignored, so a
## caller may pass anything without checking.
func note_hint_used(action: StringName) -> void:
	_hint_used[action] = true


func _draw_hint() -> void:
	var parts: PackedStringArray = PackedStringArray()
	for row: Array in HINT_KEYS:
		if not _hint_used.has(row[0]):
			parts.append(String(row[1]))
	if parts.is_empty():
		return                            # everything here has been used, so the line has finished its job
	draw_string(_font, Vector2(10.0, CANVAS.y - 8.0), "   ·   ".join(parts),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)


## The carried pack as a hotbar of slots, icon and count, centred along the bottom. The active slot,
## which the mouse wheel cycles, is highlighted and it is the one the world verbs act with. It reads
## `sim.inventory_slots()`.
func _draw_inventory() -> void:
	# The big map is the screen, the same rule as the goal plate and decided there for the same reason.
	# The map's panel runs y 41..319 of a 360 canvas, this bar's backing starts at y=295, and the map draws
	# second, so the bar was not overlapped but buried: rows 319..339 poked out below the map's edge, which
	# is exactly where each slot's count badge sits, so every count stayed legible while every icon it
	# counts was cut in half. It stands down rather than nudging the map, because the map is the one screen
	# purely for reading the world. M puts it back.
	if minimap_large:
		return
	var slots: Array[Dictionary] = sim.inventory_slots()
	# Show only the slots you actually carry, not a fixed row of empty wells, because a trailing empty slot
	# reads as "broken, what goes here?". The bar grows and shrinks with your pack, with a floor of 1.
	var n: int = clampi(slots.size(), 1, FactorySim.INVENTORY_SLOTS)
	var sel: int = int(inv_selected_getter.call()) if inv_selected_getter.is_valid() else 0
	# The bar is a window onto the pack, not the pack. `inventory_slots()` has no cap: it returns one entry
	# per item type, and the type universe is 20 machines plus 16 materials plus the crafted intermediates,
	# while this bar is capped at ten and `clampi` used to swallow the difference in silence. Carrying
	# eleven types drew ten wells and said nothing about the eleventh. Worse, `_cycle_inventory` wraps
	# modulo the full count, so the wheel walks the selection to index 10+ where the loop below never
	# reaches it, leaving no lit well anywhere on the bar. The name plate, whose guard is
	# `sel < slots.size()` and not `sel < n`, was still drawn at the selection's arithmetic position, off
	# the right end of the bar and eventually off the canvas. It is reachable on frame one of a dev start,
	# where the dev kit is ten types and the starter pickaxe is an eleventh. So the window is placed to
	# contain the selection instead of assuming it does, centred and derived purely from `sel`.
	var w0: int = clampi(sel - n / 2, 0, maxi(slots.size() - n, 0))
	var total_w: float = n * SLOT + (n - 1) * SLOT_GAP
	var x0: float = (CANVAS.x - total_w) * 0.5
	var y: float = HOTBAR_BAND_TOP + 7.0            # the band is the definition; the well row sits inside it
	# A clean framed backing just for the hotbar, since the craft strip that used to share this panel now
	# lives in the E screen. It keeps the bar reading as one deliberate unit rather than as floating slots.
	var backing := Rect2(x0 - 8.0, HOTBAR_BAND_TOP, total_w + 16.0, HOTBAR_BAND_H)
	_panel(backing)
	var wells: Array[Rect2] = []
	var sel_lit: bool = false
	for k: int in n:
		var i: int = w0 + k                                      # window slot -> the pack index it shows
		var sx: float = x0 + float(k) * (SLOT + SLOT_GAP)
		var slot_rect := Rect2(sx, y, SLOT, SLOT)
		var active: bool = i == sel
		wells.append(slot_rect)
		sel_lit = sel_lit or active
		if i < slots.size() and slot_rect.has_point(Controls.pointer_viewport(self)):
			_tooltip_item = slots[i]["item"]                     # hovered hotbar slot → tooltip
			_tooltip_count = int(slots[i]["count"])
			_tooltip_anchor = Vector2(slot_rect.get_center().x, slot_rect.position.y)
		if active:
			draw_rect(slot_rect.grow(2.0), Color(UI_ACCENT.r, UI_ACCENT.g, UI_ACCENT.b, 0.18))  # selection glow
		draw_rect(slot_rect, UI_SLOT)                                                            # well
		draw_line(slot_rect.position + Vector2(1.0, 1.0), slot_rect.position + Vector2(SLOT - 1.0, 1.0),
			UI_EDGE_HI, 1.0)                                                                      # top bevel
		draw_rect(slot_rect, UI_ACCENT if active else UI_EDGE, false, 2.0 if active else 1.0)
		# A faint keybind number in the slot corner, so the hotbar reads as keyed, and only where a key really
		# exists. The row is 1-9 then 0 for the tenth, so the tenth well said "10" for a key nobody has and
		# once the window can scroll, `k + 1` would relabel whichever items happen to be on screen. The digit
		# follows the pack index and stops when the keys do, staying blank rather than lying.
		if i < 10:
			draw_string(_font, slot_rect.position + Vector2(2.0, 9.0), "0" if i == 9 else str(i + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI_TEXT_FAINT)
		if i < slots.size():
			var item: StringName = slots[i]["item"]
			var count: int = int(slots[i]["count"])
			var icon := Rect2(sx + 6.0, y + 6.0, SLOT - 12.0, SLOT - 14.0)
			# A machine's sprite or casing-colour-plus-glyph, or a resource's sprite or colour chip. This
			# used to be twelve lines of that decision written out again, differing from the Bazaar's copy
			# only by the rim, which is now the argument. `inventory_slots()` iterates real inventory keys,
			# so the empty-id branch inside is unreachable from here.
			Visuals.thing_icon(self, item, icon, machine_icons, Color(0.0, 0.0, 0.0, 0.35))
			# Count badge bottom-right with a dark backing so it stays legible over any icon colour.
			var cnt: String = str(count)
			var cw: float = _font.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_rect(Rect2(sx + SLOT - cw - 5.0, y + SLOT - 13.0, cw + 4.0, 12.0), Color(0.03, 0.03, 0.05, 0.85))
			draw_string(_font, Vector2(sx + SLOT - cw - 3.0, y + SLOT - 3.0), cnt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT)
	# The pack continues that way, so a chevron marks whichever end has more pack behind it. It is
	# deliberately a mark and not a count, because the number of types you carry is the pack screen's job,
	# and a bar that starts reporting totals is on its way to being a second inventory. It only says "not
	# all of it is here", which is the fact the bar was concealing.
	if w0 > 0:
		_more_mark(Vector2(backing.position.x - 5.0, y + SLOT * 0.5), -1.0)
	if w0 + n < slots.size():
		_more_mark(Vector2(backing.end.x + 5.0, y + SLOT * 0.5), 1.0)
	# Name the selected item just above the bar, so the coloured chips stop being mystery squares.
	var label_rect := Rect2()
	if sel >= w0 and sel < mini(w0 + n, slots.size()):
		var label: String = _item_label(slots[sel]["item"])
		var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var lx: float = x0 + float(sel - w0) * (SLOT + SLOT_GAP) + (SLOT - lw) * 0.5
		var ly: float = y - 12.0
		var plate := Rect2(lx - 5.0, ly - 11.0, lw + 10.0, 15.0)
		draw_rect(plate, Color(0.05, 0.06, 0.09, 0.88))
		# The name of the selected item, not the selection. The slot already carries a gold border and a gold
		# glow and a third gold on the same object is emphasis competing with itself.
		draw_string(_font, Vector2(lx, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT)
		label_rect = plate
	if probing:
		hotbar_probe = {"carried": slots.size(), "wells": wells, "sel": sel, "sel_lit": sel_lit,
			"window": w0, "backing": backing, "label": label_rect}


## "There is more pack this way." A chevron pointing outward from the end of the hotbar, drawn only when
## the window is hiding something in that direction. It is dim on purpose, since it hints that the bar
## is a view rather than a control and nothing about it is clickable.
func _more_mark(at: Vector2, dir: float) -> void:
	var col := Color(UI_TEXT_DIM.r, UI_TEXT_DIM.g, UI_TEXT_DIM.b, 0.55)
	draw_line(at + Vector2(-3.0 * dir, -5.0), at + Vector2(2.0 * dir, 0.0), col, 1.5)
	draw_line(at + Vector2(2.0 * dir, 0.0), at + Vector2(-3.0 * dir, 5.0), col, 1.5)


## The hovered slot's tooltip: the item's name, the count you hold, and one purpose line, which answers
## what this is for where the question is asked. It is captured by the hotbar and pack-grid slot loops
## this frame and drawn last, above every panel, clamped on-canvas above the hovered slot.
func _draw_item_tooltip() -> void:
	if _tooltip_item == &"":
		return
	var name_line: String = "%s  ×%d" % [_item_label(_tooltip_item), _tooltip_count]
	var purpose: String = str(ITEM_PURPOSE.get(_tooltip_item, ""))
	var fs: int = 10
	var wrap_w: float = 200.0
	var name_w: float = _font.get_string_size(name_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var body: Vector2 = _font.get_multiline_string_size(purpose, HORIZONTAL_ALIGNMENT_LEFT, wrap_w, fs) \
		if purpose != "" else Vector2.ZERO
	var w: float = maxf(name_w, minf(body.x, wrap_w)) + 18.0
	var h: float = 22.0 + (body.y + 4.0 if purpose != "" else 0.0)
	var origin := Vector2(clampf(_tooltip_anchor.x - w * 0.5, 6.0, CANVAS.x - w - 6.0),
		maxf(_tooltip_anchor.y - h - 6.0, 6.0))
	var rect := Rect2(origin, Vector2(w, h))
	draw_rect(rect, Color(UI_BG.r, UI_BG.g, UI_BG.b, 0.96))
	draw_rect(rect, UI_EDGE, false, 1.0)
	# A spine rather than a cap and no longer gold, because a tooltip describes what the cursor is over,
	# which is `active` and not the thing a keystroke acts on. `UI_EDGE_HI` keeps the edge without the verb.
	draw_rect(Rect2(rect.position, Vector2(2.0, rect.size.y)), Color(UI_EDGE_HI, 1.0))
	draw_string(_font, origin + Vector2(9.0, 15.0), name_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT)
	if purpose != "":
		draw_multiline_string(_font, origin + Vector2(9.0, 29.0), purpose,
			HORIZONTAL_ALIGNMENT_LEFT, wrap_w, fs, -1, Color(0.78, 0.74, 0.62))


## Human-readable name for a carried item. A machine item uses its def's display name, such as Forge or
## Drill, and a resource its capitalised id, so ore becomes "Ore".
func _item_label(item: StringName) -> String:
	return Visuals.thing_label(item, machine_icons)
