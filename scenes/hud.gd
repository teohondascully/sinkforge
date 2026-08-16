class_name Hud
extends Node2D

## Screen-fixed HUD. Lives under a CanvasLayer so the follow-camera does NOT scroll it. Reads the sim
## only (OUTPUT total + the carried inventory) and shows the controls. Drawn in screen space.

const CANVAS := Vector2(640, 360)
const SLOT: float = 30.0        ## inventory hotbar slot size
const SLOT_GAP: float = 4.0
const MINI_W: float = 150.0     ## minimap BOX in the top-right corner; the world fits inside it,
const MINI_H: float = 116.0     ## ...whatever shape the world happens to be
const MINI_TOP: float = 34.0    ## minimap y (just under the FORGED counter)

## --- UI skin palette (one cohesive theme so the HUD reads as designed, not flat code-drawn) -------
##
## THE FOCAL HIERARCHY (#A3). The HUD used to hold the two brightest values in the frame — a near-white
## text and a near-fluorescent gold — which inverted the whole image: the eye was pulled to the chrome
## and away from the play space, and the world it left behind was a same-value jumble by comparison.
## That is a large part of what "it hurts my eyes to play" was pointing at. Both are stepped down here.
## The HUD is still perfectly readable against its own near-black panels (it always had the contrast to
## spare); it simply stops competing with the world for first look. Nothing in the UI should ever be
## brighter than lit rock.
const UI_BG := Color(0.07, 0.08, 0.115, 0.90)        ## panel fill
const UI_EDGE := Color(0.30, 0.34, 0.42)             ## panel border
const UI_EDGE_HI := Color(0.52, 0.58, 0.68, 0.45)    ## top bevel highlight → panels read as raised
const UI_ACCENT := Color(0.80, 0.66, 0.30)           ## gold accent (FORGED, selected slot, current step)
const UI_TEXT := Color(0.80, 0.83, 0.89)
const UI_TEXT_DIM := Color(0.54, 0.58, 0.66)
const UI_SLOT := Color(0.11, 0.12, 0.16, 0.95)       ## empty hotbar slot well

var sim: FactorySim
var _font: Font = ThemeDB.fallback_font
var paused_getter: Callable
## Fast-forward game clock (set by MainView). >1 draws a small "▶▶ Nx" chip top-left so you know the
## world is running fast; 1.0 draws nothing (the calm-screen default).
var time_scale: float = 1.0
## The tutorial chain (representation-layer legibility — answers "how do I play?"). Set by MainView.
var objectives: Objectives
## Craftable machines for the CRAFT strip (set by MainView): [{name: String, cost: {item->count}}].
var craft_options: Array[Dictionary] = []
## Machine item id -> {color: Color, tag: String}, so machine items in the hotbar read as machines.
var machine_icons: Dictionary = {}
## The item id per craft row (parallel to craft_options), set by MainView — machines then tools. Lets the
## craft panel render a machine (casing + glyph) or a tool (item glyph) per row without a fragile
## insertion-order dependency between two structures.
var craft_ids: Array[StringName] = []
## The active carried-item slot in the inventory hotbar (set by MainView; mouse-wheel cycles it).
var inv_selected_getter: Callable
## When you aim at one of your machines in reach, MainView pushes its inspector info here (name, recipe
## in→out, routing mode, what it's holding). Empty = nothing hovered. Drawn top-right under FORGED.
var hover_info: Dictionary = {}
var _hover_rect: Rect2 = Rect2()          ## the inspector's canvas rect this frame (#32 — pin region)
var _knob_hits: Array[Dictionary] = []    ## clickable knob chips this frame: [{rect, payload}]
## FACTORY ALERTS: stalled machines from sim.machine_problems(), pushed each frame.
## A compact LEFT-edge stack that appears ONLY when something's stuck (calm-by-default), each row
## clickable to ping the culprit. _alert_hits = this frame's clickable rects [{rect, cell}].
var alerts: Array[Dictionary] = []
var _alert_hits: Array[Dictionary] = []
const ALERT_REASON: Dictionary = {
	&"blocked": "output blocked — dig a drain",
	&"no_fuel": "out of coal — feed it",
	&"no_input": "starved — nothing feeding it",
}
## THE TITLE / NEW-GAME card (#6 + #45): {} = closed; else {seed, tint, tint_name, tints, has_save}.
var title_info: Dictionary = {}
## Minimap inputs (pushed by MainView): a material-id → colour lookup (the renderer's, handed over as a
## Callable so the HUD stays decoupled), the camera focus (player world pos) and the world-space view
## size, so the minimap can mark "you are here" + the visible window. The terrain image is cached and
## only rebuilt when you DIG (sim.solid changes), like the skylight veil.
var minimap_color: Callable
var minimap_focus: Vector2 = Vector2.ZERO
var minimap_view: Vector2 = Vector2.ZERO
var _minimap_tex: ImageTexture
var _minimap_solid_count: int = -1
const CELL: float = 32.0

## On-demand overlays (pushed by MainView each frame). The screen is calm by default: only the hotbar,
## a small FORGED chip, and the current-objective line are permanent. The crafting screen (E), the map
## (M), and the controls help (H/?) are summoned, so they never clutter the playfield.
var inventory_open: bool = false   ## E/T — THE BAZAAR panel is open (which TAB is `bazaar_tab`)
var can_craft: bool = false        ## are we near a claimed Bazaar? gates the VERBS, never the layout

## THE BAZAAR — one counter, three tabs (`docs/BAZAAR.md`).
##
## What this replaces: a 360-wide column on a 640x360 canvas that stacked the inventory grid, the craft list
## and the research bench on top of each other, ran out of room, and answered with a scrolling viewport and
## a scrollbar. Beside it, a SEPARATE full-screen tech overlay on `T` that drew the ladder you could not act
## on, because the research verb lived back in the pack screen. Look here, act there.
##
## Now it is one panel, always the same size, always the same three tabs, and it opens the same everywhere —
## including at the bottom of a shaft, where the whole point is that you can read every recipe and every tech
## price and plan the trip back. Away from a Bazaar the VERBS are dimmed and one line says where they live;
## nothing moves and nothing disappears. That is the fix for the panel that used to change shape depending on
## where you stood.
##
## NO SCROLLING VIEWPORT. Two columns of 24px rows give twenty rows in the space eight stacked ones used to
## need. If a list ever outgrows that the answer is a third column, not a scrollbar — `check_pack_layout`
## asserts it rather than trusting it.
const BAZAAR_SIZE := Vector2(600.0, 300.0)
const BAZAAR_PAD: float = 10.0
const BAZAAR_HEAD: float = 34.0    ## title + tab strip
const BAZAAR_FOOT: float = 20.0    ## the carried-goods line and the key legend
const BAZAAR_COL_HEAD: float = 18.0   ## each column's own title, ABOVE its rows rather than eating one
## 22 rather than the old craft list's 24, and the two pixels are load-bearing: at 24 a column holds nine
## rows and the spec's promise is twenty across the two. Ten and ten.
const BAZAAR_ROW_H: float = 22.0
const TAB_PACK: int = 0
const TAB_WORKS: int = 1
const TAB_BENCH: int = 2
const TAB_NAMES: Array[String] = ["PACK", "WORKS", "BENCH"]
var bazaar_tab: int = TAB_PACK
## THE RACK — the shop half of WORKS. Set by MainView beside `craft_options`, same {name, cost} shape, with
## `rack_ids` parallel to it. Kept a SEPARATE list rather than appended to the craft list because the two
## columns mean different things: the left is what you build from your own materials, the right is what you
## buy with refined goods (`docs/BITS.md` §7), and a player should never have to work out which is which.
var rack_options: Array[Dictionary] = []
var rack_ids: Array[StringName] = []
## The highlighted row on the active tab. One cursor for the whole panel: Enter acts on it, and what "acts"
## means is the tab's business — buy, craft, research.
var bazaar_row: int = 0
## The craft list can outgrow the panel (a machine per tier + tools), so it scrolls inside a bounded
## viewport while the RESEARCH bench stays pinned at the bottom (playtest: "automation fell off the
## bottom of the list, unreachable"). Scroll is in pixels, snapped to whole rows; the wheel drives it
## while the pack is open (MainView routes CYCLE to scroll_craft). Reset to 0 when the pack opens.
var _craft_scroll: float = 0.0
var _craft_scroll_max: float = 0.0
const CRAFT_ROW_H: float = 24.0
var show_minimap: bool = false
var minimap_large: bool = false    ## M cycles corner → LARGE (centred) → hidden
## The player's PING marker in world coords (Vector2.INF = none) — set by clicking the open map;
## MainView owns it and pushes it here + to the renderer (which draws the in-world beacon).
var ping_world: Vector2 = Vector2.INF
var show_help: bool = false
var show_dashboard: bool = false   ## G — the PRODUCTION DASHBOARD (throughput bars + factory census)
## THE SETTINGS page: ESC on a calm screen. Values are read straight off the Settings
## statics (representation reading representation); every control click returns a payload through
## settings_click() for MainView to act on — the HUD never touches InputMap, audio or the config file.
var settings_open: bool = false
var settings_capture: StringName = &""     ## the action awaiting its new key ("press a key…")
var _settings_hits: Array[Dictionary] = [] ## clickable controls this frame: [{rect, payload}]
var _slider_rects: Dictionary = {}         ## slider id -> its bar Rect2 this frame (drag support)

## Transient toast ("SAVED" / "LOADED" / short notices) — set via flash(), fades out on its own.
var _flash_text: String = ""
var _flash_life: float = 0.0

## THE DESCENT readout + arrivals. `depth_row` is poked every frame by MainView; the arrival is a
## one-shot banner MainView fires when the body first crosses into a band it has not been in.
var depth_row: int = Strata.SURFACE_ROW
var _arrival_text: String = ""
var _arrival_kicker: String = ""
var _arrival_color: Color = Color.WHITE
var _arrival_life: float = 0.0
const ARRIVAL_HOLD: float = 3.4          ## total life of the banner, fade included

## The just-in-time HINT BUBBLE (pushed by MainView from the Hints tracker): a small
## speech bubble anchored NEAR THE BODY teaching a newly-acquired item's use. Empty text = none.
var hint_text: String = ""
var hint_anchor: Vector2 = Vector2.ZERO   ## canvas-space point the tail points at (above the head)
var hint_alpha: float = 0.0

## ITEM TOOLTIPS: hover a hotbar/pack slot → what this item is FOR. One line per id —
## the reference card behind the one-shot acquisition hints. Machines answer "what does placing it buy";
## resources answer "what wants this". Absent id = no purpose line (name + count still show).
const ITEM_PURPOSE: Dictionary = {
	&"ore": "smeltable — a Forge turns it into ingots (toss it in, Q)",
	&"ingot": "the L1 metal — pays for crafting, research, the Engine's toll",
	&"coal": "FUEL — generators, drills and borers burn it (drop it on them)",
	&"wood": "placeable block (RMB) — crafts ropes, torches, the Bazaar frame",
	&"stone": "placeable block — and the Stone Pickaxe's making",
	&"earth": "placeable block — plug a pit, bridge a gap",
	&"deepslate": "the deep rock — the sample that unlocks DESCENT research",
	&"iron": "L2 ore — the Iron Forge smelts it into iron ingots",
	&"iron_ingot": "the L2 metal — plates, gears and the Iron Pickaxe",
	&"plate": "pressed iron sheet — the Borer's frame wants them",
	&"gear": "milled cog (iron + ingot) — the Borer's works want them",
	&"wood_pickaxe": "breaks tier-1 rock (earth · stone · ore · coal) — hold LMB",
	&"stone_pickaxe": "tier-2 pick — opens deepslate and iron, and digs faster",
	&"iron_pickaxe": "tier-3 pick — the fastest made; keyed for what waits under L2",
	&"wood_axe": "an old hatchet — your pick chops trees now; this is a keepsake",
	&"sapling": "RMB plants it on grassy ground — a new tree grows (renewable wood)",
	&"rich_ore": "high-grade ore from the deep shelf — a Blast Furnace pours 2 ingots from 1",
	&"blast_furnace": "smelts RICH ore 1 → 2 ingots — the deep veins' payoff",
	&"scanner": "sonar — select it, RMB pulses: nearby veins echo through the rock",
	&"rope": "RMB above a drop — it unrolls down; W/S climbs it",
	&"torch": "RMB on a wall-backed cell — light that STAYS",
	&"conduit": "RMB lays power tube — power flows down + sideways, never up",
	&"processor": "the Forge — smelts what falls into it (ore → ingots)",
	&"splitter": "routes falling items DOWN + RIGHT (aim R at it: ratio)",
	&"lift": "hauls goods — and YOU — up its column; power multiplies it",
	&"drill": "bores straight down through an ore vein — burns coal",
	&"hopper": "banks what falls in, meters it DOWN — keeps the first item it tastes",
	&"generator": "burns coal into POWER for the machines around it",
	&"descent_engine": "stand it ON the seal, feed it ingots — it breaches the way down",
	&"iron_forge": "smelts iron ore into iron ingots (the L2 chain's base)",
	&"plate_press": "presses iron ingots into plates",
	&"gear_mill": "mills iron ingots + ingots into gears (two inputs, one column)",
	&"h_drill": "the Borer — chews sideways the way you faced; its haul drops below it",
}
## The hovered slot this frame (captured while drawing the hotbar/pack grid, drawn last, on top).
var _tooltip_item: StringName = &""
var _tooltip_count: int = 0
var _tooltip_anchor: Vector2 = Vector2.ZERO   ## top-centre of the hovered slot


## Show a short transient notice centred under the objective banner (~2s, fades).
func flash(text: String) -> void:
	_flash_text = text
	_flash_life = 2.2


## Announce arrival in a new stratum — the one moment the descent gets to be an EVENT.
func announce(text: String, kicker: String, color: Color) -> void:
	_arrival_text = text
	_arrival_kicker = kicker
	_arrival_color = color
	_arrival_life = ARRIVAL_HOLD


func _process(delta: float) -> void:
	_flash_life = maxf(0.0, _flash_life - delta)
	_arrival_life = maxf(0.0, _arrival_life - delta)
	queue_redraw()


func _draw() -> void:
	_tooltip_item = &""    # re-captured by whichever slot the cursor sits on this frame
	_alert_hits.clear()    # stale unless _draw_alerts repopulates it this frame (menus suppress it)
	# THE TITLE (#6): while it's open nothing else matters — the veil + the new-game card ARE the screen.
	if not title_info.is_empty():
		_draw_title()
		return
	# --- always on (minimal): the anchor furniture only ---
	_draw_forged()         # top-right production chip (small)
	_draw_depth()          # top-left depth readout — the one number a descent game owes you
	_draw_objective_line()  # top-centre, ONE current step — the signpost without the wall of text
	_draw_hover()          # inspector for the machine under the cursor (only when one is hovered)
	_draw_inventory()      # bottom-centre hotbar
	_draw_hint()           # tiny bottom-left "E craft · M map · H keys" — replaces the giant footer
	if not (inventory_open or show_help or settings_open or show_dashboard):
		_draw_hint_bubble()  # just-in-time teaching near the body (hidden while a menu dims the world)
		_draw_alerts()       # left-edge stalled-machine stack (only when something's stuck)
	# --- on demand (summoned, so they never clutter) ---
	if show_minimap:
		_draw_minimap()    # M — top-right world map
	if inventory_open:
		_draw_inventory_overlay()  # E/T — THE BAZAAR: one counter, three tabs (docs/BAZAAR.md)
	if show_dashboard:
		_draw_dashboard_overlay()  # G — throughput bars + factory census (the flywheel made legible)
	if show_help:
		_draw_help_overlay()      # H / ? — the full controls list
	if settings_open:
		_draw_settings_overlay()  # ESC — audio / feel / the remap page
	if paused_getter.is_valid() and bool(paused_getter.call()):
		var p := Rect2(CANVAS.x * 0.5 - 52.0, 8.0, 104.0, 26.0)
		_panel(p, true)
		draw_string(_font, p.position + Vector2(20.0, 18.0), "PAUSED (P)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI_ACCENT)
	_draw_fastforward()    # top-left "▶▶ Nx" chip when the game clock is sped up
	# The stratum plate is the one channel that means "stop, look" — so it does not fire over a menu, where
	# there is nothing to look at and it prints straight through the price column. It is a transient; if you
	# were reading the counter when you crossed a band, the depth readout still says where you are.
	if not (inventory_open or show_dashboard or settings_open):
		_draw_arrival()    # the stratum banner, on the frames after you first cross into one
	_draw_flash()          # transient toast (save/load feedback)
	_draw_item_tooltip()   # hovered-slot tooltip — drawn last so it rides over every panel


## THE TITLE / NEW-GAME screen (#6 + #45): a dark veil over the live (paused) world, the game's name,
## and the two choices that make this world YOURS — its seed and your lamp's colour. Deliberately
## spare: the world glowing behind the veil is the real menu art.
func _draw_title() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(CANVAS)), Color(0.03, 0.035, 0.06, 0.82))
	var cx: float = CANVAS.x * 0.5
	var y: float = CANVAS.y * 0.30
	# The name — tracked out wide, with the accent rule under it.
	var title: String = "S I N K F O R G E"
	var tw: float = _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(_font, Vector2(cx - tw * 0.5, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
		Color(0.97, 0.90, 0.62))
	draw_rect(Rect2(cx - tw * 0.5, y + 7.0, tw, 2.0), UI_ACCENT)
	var tag: String = "the way is down"
	var gw: float = _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(_font, Vector2(cx - gw * 0.5, y + 24.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.64, 0.70, 0.80))
	# The choices card.
	y += 48.0
	var card := Rect2(cx - 128.0, y, 256.0, 84.0)
	_panel(card, true)
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
		if i == sel:
			draw_rect(sw.grow(2.0), UI_ACCENT, false, 1.5)
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


## The transient toast: a small accented chip centred under the objective line, fading out over its
## last half-second. Cheap, reusable feedback for one-shot actions (F5 save / F9 load).
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


## The just-in-time HINT BUBBLE: a small speech bubble with a tail pointing down at the body, teaching
## the item that just landed in the pack. Word-wrapped, gold-capped like every panel,
## faded by the tracker's envelope. Clamped on-canvas so a body near a world edge still gets taught.
func _draw_hint_bubble() -> void:
	if hint_text == "" or hint_alpha <= 0.01:
		return
	var fs: int = 11
	var wrap_w: float = 230.0
	var text_size: Vector2 = _font.get_multiline_string_size(hint_text, HORIZONTAL_ALIGNMENT_LEFT, wrap_w, fs)
	var w: float = minf(text_size.x, wrap_w) + 20.0
	var h: float = text_size.y + 13.0
	var tail := Vector2(clampf(hint_anchor.x, 8.0, CANVAS.x - 8.0), clampf(hint_anchor.y, 60.0, CANVAS.y - 12.0))
	var origin := Vector2(clampf(tail.x - w * 0.5, 6.0, CANVAS.x - w - 6.0), tail.y - 7.0 - h)
	if origin.y < 38.0:                       # never under the objective line — flip below the anchor
		origin.y = tail.y + 7.0
	var a: float = hint_alpha
	var rect := Rect2(origin, Vector2(w, h))
	draw_rect(rect, Color(UI_BG.r, UI_BG.g, UI_BG.b, UI_BG.a * a))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2.0)), Color(UI_ACCENT.r, UI_ACCENT.g, UI_ACCENT.b, a))
	draw_rect(rect, Color(UI_EDGE.r, UI_EDGE.g, UI_EDGE.b, a), false, 1.0)
	var tip_y: float = tail.y if origin.y < tail.y else origin.y - 1.0   # tail reaches toward the body
	var base_y: float = (origin.y + h) if origin.y < tail.y else origin.y
	var tx: float = clampf(tail.x, origin.x + 10.0, origin.x + w - 10.0)
	draw_colored_polygon(PackedVector2Array([Vector2(tx - 5.0, base_y), Vector2(tx + 5.0, base_y),
		Vector2(tx, tip_y)]), Color(UI_BG.r, UI_BG.g, UI_BG.b, UI_BG.a * a))
	draw_multiline_string(_font, origin + Vector2(10.0, 6.0 + 10.0), hint_text,
		HORIZONTAL_ALIGNMENT_LEFT, wrap_w, fs, -1, Color(0.95, 0.90, 0.72, a))


## FACTORY ALERTS: a compact left-edge stack of stalled machines, shown ONLY when
## something's actually stuck (calm-by-default — a healthy factory draws nothing here). Each row names
## the machine + count + why, and is CLICKABLE to drop a ping on the culprit so you can walk to it (the
## camera is body-locked; a beacon is the honest "take me there"). MainView pushes `alerts` + routes the
## click through alert_click(). Capped at 5 rows so a cascading failure can't wallpaper the screen.
func _draw_alerts() -> void:
	if alerts.is_empty():
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
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
		draw_rect(Rect2(x, y, 2.5, rh - 3.0), Color(0.96, 0.46, 0.30))          # the warning edge
		var mdef: MachineDef = a["def"]
		var box := Rect2(x + 6.0, y + 2.5, 13.0, 13.0)
		draw_rect(box, Visuals.machine_color(mdef))
		Visuals.draw_machine_glyph(self, box.position + box.size * 0.5, Visuals.machine_kind(mdef),
			box.size.y / 20.0, false, 0.0)
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


## Route a click at `mouse` (canvas coords) to the alert it hit → {cell: Vector2i} to ping, or {} if the
## click missed the stack. MainView owns the ping; the HUD only reports the hit (the minimap-click rule).
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


## Fast-forward chip (top-left): a small "▶▶ Nx" tag shown ONLY while the game clock is sped up, so the
## world visibly racing has an on-screen cause. Hidden at 1x to keep the default screen calm. Press "."
## to cycle. Uses the shared accented panel skin.
## THE DEPTH READOUT (top-left). Metres below the surface datum, and the name of the band you are in,
## in that band's own colour — so the number and the world's palette agree. Permanent, because in a game
## whose entire subject is descending, "how far down am I" is not an optional overlay.
func _draw_depth() -> void:
	var m: int = Strata.depth_m(depth_row)
	var label: String = ("%d m" % m) if m >= 0 else ("+%d m" % -m)
	var band: String = Strata.name_at(depth_row)
	var tint: Color = Strata.color_at(depth_row)
	var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var bw: float = _font.get_string_size(band, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var chip := Rect2(10.0, 8.0, maxf(lw + 10.0 + bw, 96.0) + 24.0, 22.0)
	_panel(chip)
	var cy: float = chip.position.y + chip.size.y * 0.5
	draw_string(_font, Vector2(chip.position.x + 12.0, cy + 6.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI_ACCENT)
	draw_string(_font, Vector2(chip.position.x + 12.0 + lw + 10.0, cy + 5.0), band,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, tint)


## THE ARRIVAL PLATE. Only ever the FIRST time you enter a band — the whole value is that it is rare.
##
## It used to be set at three times this size across a full-width bar, which made the one moment the
## descent gets to be an event read instead as a modal dialog: it covered the play space, it competed
## with the objective banner directly above it, and a player's first instinct was to dismiss it. Weight
## in a title card comes from SPACING, not from point size. So: half the type, letters tracked apart, a
## kicker line above it, rules only as wide as the text, and no panel at all.
const ARRIVAL_SIZE: int = 15             ## canvas px; the objective banner above runs at 13
const ARRIVAL_TRACK: float = 3.4         ## extra px between letters — what makes small type read as engraved

## THE SCRIM. Panel-less type only reads while the thing behind it is dark, and every stratum plate fires
## underground, so the plate was legible for as long as it was the only thing that used this channel. The
## first-automation hail fires on the surface at midday, against a bright sky and a mountain range and a
## rotating gearwheel — and the words simply disappeared. The fix is not a panel (a panel is the modal
## dialog this design was built to escape) but a soft darkening under the words that has no edge to read
## as a shape: a soft field of dusk under the words that fades to nothing in every direction, so the text
## sits in its own patch of evening wherever it lands.
const SCRIM_COLS: int = 12               ## quads across the field...
const SCRIM_ROWS: int = 8                ## ...and down it
const SCRIM_ALPHA: float = 0.80          ## peak darkening, dead centre
const SCRIM_PAD: float = 34.0            ## px of solid core beyond the widest line
const SCRIM_FEATHER: float = 96.0        ## px the core fades out over, left and right
const SCRIM_ABOVE: float = 32.0
const SCRIM_BELOW: float = 18.0

func _draw_arrival() -> void:
	if _arrival_life <= 0.0:
		return
	var t: float = _arrival_life / ARRIVAL_HOLD
	var a: float = clampf(minf((1.0 - t) * 6.0, t * 2.4), 0.0, 1.0)     # fast in, slow out
	var y: float = CANVAS.y * 0.26 - (1.0 - t) * 5.0
	var w: float = _tracked_width(_arrival_text, ARRIVAL_SIZE, ARRIVAL_TRACK)
	var half: float = w * 0.5 + 12.0
	var kw: float = _tracked_width(_arrival_kicker, 9, 2.6) if _arrival_kicker != "" else 0.0
	_draw_scrim(maxf(w, kw) * 0.5 + SCRIM_PAD, y, a)
	if _arrival_kicker != "":
		_draw_tracked(_arrival_kicker, Vector2(CANVAS.x * 0.5 - kw * 0.5, y - 15.0), 9, 2.6,
			Color(_arrival_color, 0.80 * a))
	_draw_tracked(_arrival_text, Vector2(CANVAS.x * 0.5 - w * 0.5, y), ARRIVAL_SIZE, ARRIVAL_TRACK,
		Color(_arrival_color, a))
	# Two hairlines the width of the words: a frame that says "plate" without drawing a panel.
	for ry: float in [y - 25.0, y + 7.0]:
		draw_line(Vector2(CANVAS.x * 0.5 - half, ry), Vector2(CANVAS.x * 0.5 + half, ry),
			Color(_arrival_color, 0.40 * a), 1.0)


## The arrival plate's soft ground, drawn as an interpolated GRID rather than as a stack of bands.
##
## The first version stacked constant-alpha strips with a half-pixel overlap to hide the seams, which is
## precisely backwards: where two translucent strips overlap their alpha COMPOSITES, so every seam came
## out darker than either neighbour and the scrim rasterized as venetian blinds straight across the sky.
## A grid has no seams to hide. Adjacent quads share their edge vertices AND those vertices' colours, so
## the hardware interpolates one continuous field across the whole plate — and the falloff can then be
## smoothstepped on both axes, which puts a zero derivative at every outer edge and leaves nothing for
## the eye to catch.
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


## ...and a bell down the plate, so it has no top or bottom edge either.
func _scrim_v(yy: float, top: float, bot: float) -> float:
	return 1.0 - smoothstep(0.0, 1.0, absf(yy - (top + bot) * 0.5) / maxf((bot - top) * 0.5, 0.001))


func _scrim_c(weight: float, a: float) -> Color:
	return Color(0.02, 0.025, 0.04, SCRIM_ALPHA * a * weight)


## Letter-tracked text. Godot's draw_string has no tracking, and tracking is the entire difference
## between small type that reads as a label and small type that reads as a caption.
func _draw_tracked(text: String, at: Vector2, size: int, track: float, color: Color) -> void:
	var x: float = at.x
	for i: int in text.length():
		var ch: String = text[i]
		draw_string(_font, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + track


func _tracked_width(text: String, size: int, track: float) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x \
		+ track * float(maxi(0, text.length() - 1))


func _draw_fastforward() -> void:
	if time_scale <= 1.0:
		return
	var label: String = "▶▶ %dx" % int(time_scale)
	var tw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var chip := Rect2(10.0, 34.0, tw + 24.0, 22.0)   # under the depth chip, which owns the corner
	_panel(chip, true)
	draw_string(_font, chip.position + Vector2(12.0, 15.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI_ACCENT)


## FORGED production chip (top-right): an ingot swatch + the lifetime ingot count, in a small panel —
## consistent with the inspector/minimap skin instead of bare floating text.
func _draw_forged() -> void:
	var n: int = int(sim.total_produced.get(&"ingot", 0))
	var count: String = str(n)
	var label_w: float = _font.get_string_size("FORGED", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var count_w: float = _font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var w: float = 12.0 + 14.0 + 8.0 + label_w + 8.0 + count_w + 12.0
	var chip := Rect2(CANVAS.x - w - 10.0, 8.0, w, 22.0)
	_panel(chip)
	var x: float = chip.position.x + 12.0
	var cy: float = chip.position.y + chip.size.y * 0.5
	draw_rect(Rect2(x, cy - 6.0, 12.0, 12.0), Visuals.item_color(&"ingot"))
	draw_rect(Rect2(x, cy - 6.0, 12.0, 12.0), Color(0.0, 0.0, 0.0, 0.4), false, 1.0)
	x += 14.0 + 8.0
	draw_string(_font, Vector2(x, cy + 5.0), "FORGED", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI_TEXT_DIM)
	x += label_w + 8.0
	draw_string(_font, Vector2(x, cy + 6.0), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI_ACCENT)


## How long a fresh step shows its full how-to line, how long that takes to fade, and how long you have
## to sit on one step before it comes back (#B4).
const HINT_HOLD: float = 9.0
const HINT_FADE: float = 1.5
const HINT_STUCK: float = 40.0


## The OBJECTIVE line (top-centre) — the current step only, as a gentle nudge. Pure read of the
## Objectives tracker. Top-centre sits over open sky, so it never buries the avatar the way the old
## panel did. When the whole chain is done it shows a brief "all set" then auto-hides (the Guide stops
## nagging).
##
## LESS TEXT, MORE SHOW (#B4). This used to be one long imperative sentence, permanently — thirteen of
## them in a row, each a banner of prose across the top of the screen. It reads as homework: the game
## telling you what to do rather than a world inviting you to try things, and it was a real part of
## "the early game is annoying instead of seamless". The banner now leads with the SHORT goal ("Mine 4
## ore"), which is all a player needs once they know the verb, and carries the full how-to underneath
## only while it's actually wanted: for the first few seconds after a step opens, and again once you
## have been stuck on one long enough to want it back. In between, the world does the talking — the
## pulsing target ring already points at where the step happens.
func _draw_objective_line() -> void:
	if objectives == null:
		return
	if objectives.all_done() and objectives.done_for() > 5.0:
		return  # finished + lingered → clear the screen for veterans
	var text: String
	var col: Color
	var hint: String = ""
	var hint_a: float = 0.0
	if objectives.all_done():
		text = "✓  All set — keep digging deeper."
		col = Color(0.62, 0.86, 0.58)
	else:
		var step: Dictionary = objectives.steps[objectives.current_index()]
		text = str(step["goal"])
		col = Color(0.97, 0.93, 0.78)
		var age: float = objectives.step_age
		if age < HINT_HOLD + HINT_FADE:
			hint_a = clampf((HINT_HOLD + HINT_FADE - age) / HINT_FADE, 0.0, 1.0)
		elif age > HINT_STUCK:
			hint_a = clampf((age - HINT_STUCK) / HINT_FADE, 0.0, 1.0)   # you've stalled — hand it back
		if hint_a > 0.0:
			hint = str(step["label"])
	var fs: int = 13
	var hfs: int = 10
	var pad: float = 12.0
	var tw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0
	var hw: float = _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs).x if hint != "" else 0.0
	var w: float = maxf(tw, hw) + pad * 2.0
	var h: float = 24.0 + (13.0 if hint != "" else 0.0)
	var rect := Rect2((CANVAS.x - w) * 0.5, 8.0, w, h)
	_panel(rect, true)
	var cy: float = rect.position.y + 12.0
	if not objectives.all_done():
		draw_circle(Vector2(rect.position.x + pad + 1.0, cy), 3.0, UI_ACCENT)
	draw_string(_font, Vector2(rect.position.x + pad + 14.0, cy + 5.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if hint != "":
		draw_string(_font, Vector2(rect.position.x + pad, cy + 18.0), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, Color(UI_TEXT_DIM, hint_a))


## A framed, lightly-beveled panel backing — the shared skin for every HUD widget (objectives,
## inspector, minimap, the bottom pack). A faint lit top edge makes it read as raised rather than a
## flat sticker; `accent` paints a gold cap bar for headlined panels.
func _panel(rect: Rect2, accent: bool = false) -> void:
	draw_rect(rect, UI_BG)
	draw_line(rect.position + Vector2(1.0, 1.0), rect.position + Vector2(rect.size.x - 1.0, 1.0),
		UI_EDGE_HI, 1.0)
	draw_rect(rect, UI_EDGE, false, 1.0)
	if accent:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2.0)), UI_ACCENT)


## The machine INSPECTOR (top-right, under FORGED) — appears when you aim at one of your machines in
## reach. Names it and shows its recipe as item chips (inputs → outputs) or its routing mode, plus what
## it's currently holding. The "where does this eat / spit / what does it make" answer without a manual.
## CONFIG PANEL: machines with a knob also draw CLICKABLE rows — the splitter's three
## ratio chips, a filtered hopper's [clear] chip — and machines with a fill draw a real BAR (the
## engine's quota). MainView PINS the hover while the cursor crosses onto this panel, so the knobs are
## reachable; clicks land through hover_click() (every mutation stays a discrete sim call out there).
func _draw_hover() -> void:
	_knob_hits.clear()
	_hover_rect = Rect2()
	if hover_info.is_empty():
		return
	var ins: Array = hover_info.get("in", [])
	var outs: Array = hover_info.get("out", [])
	var holding: Array = hover_info.get("holding", [])
	var knobs: Array = hover_info.get("knobs", [])
	var bar: Dictionary = hover_info.get("bar", {})
	var has_recipe: bool = not ins.is_empty() or not outs.is_empty()
	var has_mode: bool = hover_info.has("mode") and str(hover_info["mode"]) != ""
	var has_rate: bool = hover_info.has("rate")
	var width: float = 218.0
	var rows: int = 1 + int(has_recipe) + int(has_mode) + int(not holding.is_empty()) + int(has_rate) \
		+ knobs.size() + int(not bar.is_empty())
	var pad: float = 9.0
	var line_h: float = 18.0
	# Sits below whatever occupies the top-right column: the CORNER minimap if it's shown (the large map
	# is centred, off this column), else just the FORGED chip — so the inspector never collides.
	var mini_bottom: float = minimap_frame().end.y if (show_minimap and not minimap_large) else 34.0
	var origin := Vector2(CANVAS.x - width - 12.0, mini_bottom + 10.0)
	_hover_rect = Rect2(origin, Vector2(width, 10.0 + float(rows) * line_h + 4.0))
	_panel(_hover_rect)
	var x0: float = origin.x + pad
	var y: float = origin.y + 8.0 + 12.0
	draw_string(_font, Vector2(x0, y), str(hover_info.get("name", "")),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.92, 0.80))
	y += line_h
	if has_recipe:
		var x: float = _chips(x0, y, ins)
		x = _arrow(x, y)
		_chips(x, y, outs)
		y += line_h
	if has_mode:
		draw_string(_font, Vector2(x0, y), str(hover_info["mode"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.66, 0.80, 0.90))
		y += line_h
	if not holding.is_empty():
		var hx: float = draw_string_pos(x0, y, "holds")
		_chips(hx, y, holding)
		y += line_h
	if has_rate:
		draw_string(_font, Vector2(x0, y), str(hover_info["rate"]),
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
	var mouse: Vector2 = get_viewport().get_mouse_position()
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


## The inspector's on-canvas rect this frame (Rect2() = not shown). MainView uses it to PIN the hover
## while the cursor travels onto the panel — the same "the open map is UI" rule the minimap follows.
func hover_panel_rect() -> Rect2:
	return _hover_rect


## The knob payload under a canvas point ({} = none). Read by MainView on LMB — the HUD never touches
## the sim; the controller turns the payload into a discrete sim call.
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


## Where the minimap sits RIGHT NOW (canvas space) — corner (top-right, small) or LARGE (centred).
## Public: MainView uses it to route map-clicks to the PING and to keep world verbs off the map.
##
## Both forms FIT the world's aspect inside a box rather than deriving one side from the other. A corner
## map sized by width alone was fine while the world was 96x80 and became a 150x150 slab down half the
## screen the moment it went square — a corner element has a height budget as much as a width one, and
## the world's shape is not the HUD's to assume.
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


## The MINIMAP (M — corner; M again — LARGE): a cached image of the whole world — solid cells in their
## material colour, carved/dug cells as a dim wall backing, open sky as void — with the live overlays of
## Minimap 2.0: DEPTH BANDS (the violet seal line + the cold Stonereach wash below it),
## your machines, BAZAAR diamonds, a pulsing BREACH marker on every opened way down, your PING (click
## the map to set/clear it — the in-world beacon is the renderer's), the visible window, and YOU. The
## terrain image rebuilds only when you DIG (sim.solid changes), so per-frame cost is one textured blit.
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
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)   # cosmetic clock — HUD only
	# --- depth bands: the layer ladder made legible at a glance ---
	var seal_y: float = origin.y + float(LayeredWorldGen.SEAL_TOP) * scale.y
	var seal_h: float = maxf(float(LayeredWorldGen.SEAL_ROWS) * scale.y, 1.5)
	draw_rect(Rect2(origin.x, seal_y + seal_h, frame.size.x, frame.end.y - (seal_y + seal_h)),
		Color(0.35, 0.50, 0.95, 0.10))                                  # Stonereach: a cold wash
	draw_rect(Rect2(origin.x, seal_y, frame.size.x, seal_h), Color(0.62, 0.42, 0.85, 0.55))  # THE SEAL
	# THE DESCENT CHART. The large map used to name exactly two bands, TOPSOIL and STONEREACH, and it
	# put the first of them immediately above the seal — which is the deepslate, sixty rows from any
	# topsoil. Every band Strata knows about now gets a hairline at its ceiling and its own name in its
	# own colour, so the map answers "how far down does this go, and what is between here and there"
	# at a glance. That is the whole reason to open a map in a game about descending.
	if minimap_large:
		for i: int in range(1, Strata.BANDS.size()):     # skip OPEN SKY: it has no ceiling to draw
			var band: Dictionary = Strata.BANDS[i]
			var by: float = origin.y + float(int(band["from"])) * scale.y
			if by < origin.y or by > frame.end.y - 6.0:
				continue
			var tint: Color = band["color"]
			draw_line(Vector2(origin.x, by), Vector2(frame.end.x, by), Color(tint, 0.30), 1.0)
			# A thin band (THE SEAL is two rows) would stack its name on top of the one below it. Every
			# band keeps its LINE; the one that loses its text is the shallower of a colliding pair,
			# because the deeper name is the one telling you what you are about to be in.
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
	# --- AQUIFERS: the flooded pockets that guard rich ore. A distinct cool cyan-blue (clear of the
	# amber power wash, the gold bazaars, and the violet seal/breach), alpha scaling with fill so deep
	# water reads solid, a puddle reads faint. Live overlay: water FLOWS each tick, not in the cached bake.
	var wcell: Vector2 = Vector2(maxf(scale.x, 1.0), maxf(scale.y, 1.0)).ceil()
	for water_cell_v: Variant in sim.water:
		var water_cell: Vector2i = water_cell_v
		var fill: float = clampf(float(sim.water[water_cell]) / float(FactorySim.WATER_MAX), 0.0, 1.0)
		draw_rect(Rect2(origin + Vector2(water_cell) * scale, wcell),
			Color(0.25, 0.62, 0.95, 0.30 + 0.45 * fill))
	# --- FRONTIER REACH: where the factory's POWER and placed LIGHT actually extend —
	# "your reach is how deep you can survive" read straight off the map. Power = a warm amber wash
	# per powered cell (brighter = more units, live off the derived sim.power field); placed torches =
	# small warm halos. Subtle alphas so terrain stays readable under the claim.
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


## A small filled diamond — the minimap's icon shape (reads at 3-5px where a square blurs into terrain).
func _map_diamond(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r), c + Vector2(r, 0.0),
		c + Vector2(0.0, r), c + Vector2(-r, 0.0)]), col)


## Rebuild the cached terrain image: one pixel per cell — solid = material colour, dug-but-walled = a
## dim wall backing (the carved room), open sky = void. Cheap; runs only when terrain changes.
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


## THE BAZAAR'S GEOMETRY — one fixed shape, computed in one place, read by both the draw and the layout
## test, so seen == tested. Nothing here depends on how long a list is or on whether you are standing at a
## counter, which is the entire point: the panel that changes shape is the panel you cannot learn.
func _bazaar_geometry() -> Dictionary:
	var origin := Vector2((CANVAS.x - BAZAAR_SIZE.x) * 0.5, (CANVAS.y - BAZAAR_SIZE.y) * 0.5)
	var content := Rect2(origin + Vector2(BAZAAR_PAD, BAZAAR_HEAD),
		Vector2(BAZAAR_SIZE.x - BAZAAR_PAD * 2.0, BAZAAR_SIZE.y - BAZAAR_HEAD - BAZAAR_FOOT))
	return {
		"origin": origin, "w": BAZAAR_SIZE.x, "h": BAZAAR_SIZE.y, "content": content,
		"col_w": (content.size.x - 12.0) * 0.5, "row_h": BAZAAR_ROW_H,
		"rows": int((content.size.y - BAZAAR_COL_HEAD) / BAZAAR_ROW_H),
	}


## How many rows the active tab offers the cursor. WORKS is the two lists end to end; BENCH is the ladder.
func bazaar_row_count() -> int:
	match bazaar_tab:
		TAB_WORKS:
			return craft_options.size() + rack_options.size()
		TAB_BENCH:
			return ResearchRules.ORDER.size()
		_:
			return 0


## WHAT ENTER WOULD DO, as {kind, id} — kind is "machine", "rack", "tech" or "". The panel owns the cursor
## because the panel draws it; MainView owns the verbs. Splitting it this way means the highlighted row and
## the thing that happens can never drift apart, which is the bug that made `R` two different keys.
func bazaar_action() -> Dictionary:
	var i: int = bazaar_row
	match bazaar_tab:
		TAB_WORKS:
			if i < 0 or i >= bazaar_row_count():
				return {}
			if i < craft_options.size():
				return {"kind": "machine", "id": _craft_id(i), "row": i}
			var r: int = i - craft_options.size()
			return {"kind": "rack", "id": rack_ids[r] if r < rack_ids.size() else &"", "row": r}
		TAB_BENCH:
			if i < 0 or i >= ResearchRules.ORDER.size():
				return {}
			return {"kind": "tech", "id": ResearchRules.ORDER[i], "row": i}
		_:
			return {}


## Move the cursor. `dy` steps a row; `dx` jumps a column — on WORKS that is the counter-to-Rack hop, which
## is a real place to want to go in one keystroke rather than ten.
func bazaar_move(dx: int, dy: int) -> void:
	var n: int = bazaar_row_count()
	if n <= 0:
		return
	if dx != 0 and bazaar_tab == TAB_WORKS:
		var machines: int = craft_options.size()
		bazaar_row = mini(bazaar_row + machines, n - 1) if bazaar_row < machines else maxi(bazaar_row - machines, 0)
	bazaar_row = clampi(bazaar_row + dy, 0, n - 1)


func set_bazaar_tab(tab: int) -> void:
	bazaar_tab = clampi(tab, TAB_PACK, TAB_BENCH)
	bazaar_row = 0


func _draw_inventory_overlay() -> void:
	# DIMMED, NOT BLACKED. You are at a counter with a shopkeeper standing next to you and banners over your
	# head — the staging `scenes/bazaars.gd` builds block by block — so the world stays legible behind the
	# panel instead of being switched off the moment you open it.
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.0, 0.0, 0.0, 0.38))
	var g: Dictionary = _bazaar_geometry()
	var origin: Vector2 = g["origin"]
	var w: float = g["w"]
	var content: Rect2 = g["content"]
	# The counter itself is OPAQUE. The world around it stays readable — that is what the light dim above is
	# for — but a menu you can read the world THROUGH is a menu you cannot read at all: the zone title card
	# and the hotbar were printing straight through the price column.
	draw_rect(Rect2(origin, Vector2(w, g["h"])), Color(0.055, 0.065, 0.085, 0.985))
	_panel(Rect2(origin, Vector2(w, g["h"])), true)
	draw_string(_font, origin + Vector2(14.0, 22.0), "THE BAZAAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI_ACCENT)
	_draw_bazaar_tabs(origin, w)
	match bazaar_tab:
		TAB_WORKS:
			_tab_works(content, g)
		TAB_BENCH:
			_tab_bench(content)
		_:
			_tab_pack(content)
	_draw_bazaar_foot(origin, w, g["h"])


## The tab strip, right of the title. The active tab is the only one drawn in full — the others recede,
## because three equally-lit labels is three things to read and one lit one is a place you are standing.
func _draw_bazaar_tabs(origin: Vector2, w: float) -> void:
	var x: float = origin.x + w - 14.0
	for i: int in range(TAB_NAMES.size() - 1, -1, -1):
		var label: String = TAB_NAMES[i]
		var tw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		x -= tw + 10.0
		var on: bool = i == bazaar_tab
		if on:
			draw_rect(Rect2(x - 6.0, origin.y + 9.0, tw + 12.0, 18.0), UI_SLOT)
			draw_line(Vector2(x - 6.0, origin.y + 27.0), Vector2(x + tw + 6.0, origin.y + 27.0), UI_ACCENT, 1.5)
		draw_string(_font, Vector2(x, origin.y + 22.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			UI_TEXT if on else Color(0.42, 0.44, 0.50))
		x -= 12.0


## The footer: what you are carrying that the counter cares about, and where the verbs live. The second half
## is the fix for the panel that used to vanish when you walked away from the stall — you can read every
## recipe and every price from the bottom of a shaft, and the panel simply tells you where to spend them.
func _draw_bazaar_foot(origin: Vector2, w: float, h: float) -> void:
	var y: float = origin.y + h - 7.0
	draw_line(Vector2(origin.x + 8.0, y - 13.0), Vector2(origin.x + w - 8.0, y - 13.0), UI_EDGE, 1.0)
	var parts: PackedStringArray = []
	for item: StringName in [&"ingot", &"iron_ingot", &"ore", &"coal", &"stone", &"wood"]:
		var n: int = int(sim.inventory.get(item, 0))
		if n > 0:
			parts.append("%d %s" % [n, _item_label(item)])
	draw_string(_font, Vector2(origin.x + 14.0, y), " · ".join(parts) if not parts.is_empty() else "carrying nothing",
		HORIZONTAL_ALIGNMENT_LEFT, w - 210.0, 9, UI_TEXT_DIM)
	var keys: String = "1/2/3 tab   E close" if can_craft else "1/2/3 tab   E close   — verbs at a claimed Bazaar"
	var kw: float = _font.get_string_size(keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(_font, Vector2(origin.x + w - kw - 13.0, y), keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		UI_TEXT_DIM if can_craft else Color(0.58, 0.48, 0.32))


## PACK — the whole carried inventory, given the whole width. It is the same grid it always was; it simply
## stopped sharing a 360px column with two other screens.
func _tab_pack(content: Rect2) -> void:
	var slots: Array[Dictionary] = sim.inventory_slots()
	var cell: float = 34.0
	var cols: int = maxi(1, int(content.size.x / cell))
	var rates: Array[Dictionary] = sim.production_rates()
	var top: float = content.position.y
	if not rates.is_empty():
		var parts: PackedStringArray = []
		for i: int in mini(4, rates.size()):
			parts.append("%s %.1f/min" % [_item_label(rates[i]["item"]), float(rates[i]["rate"])])
		draw_string(_font, Vector2(content.position.x + 2.0, top + 10.0), "making  " + " · ".join(parts),
			HORIZONTAL_ALIGNMENT_LEFT, content.size.x - 4.0, 10, Color(0.85, 0.72, 0.42))
		top += 18.0
	if slots.is_empty():
		draw_string(_font, Vector2(content.position.x + 2.0, top + 18.0), "(empty — go dig)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT_DIM)
		return
	for i: int in slots.size():
		var box := Rect2(content.position.x + float(i % cols) * cell, top + float(i / cols) * cell,
			cell - 4.0, cell - 4.0)
		if box.end.y > content.end.y:
			break
		draw_rect(box, UI_SLOT)
		draw_rect(box, UI_EDGE, false, 1.0)
		var item: StringName = slots[i]["item"]
		if box.has_point(get_viewport().get_mouse_position()):
			draw_rect(box, UI_EDGE_HI, false, 1.0)
			_tooltip_item = item
			_tooltip_count = int(slots[i]["count"])
			_tooltip_anchor = Vector2(box.get_center().x, box.position.y)
		_draw_thing_icon(item, Rect2(box.position + Vector2(5.0, 4.0),
			Vector2(box.size.x - 10.0, box.size.y - 12.0)))
		draw_string(_font, box.position + Vector2(box.size.x - 11.0, box.size.y - 2.0),
			str(int(slots[i]["count"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT)


## WORKS — the counter (left: what you BUILD from your own materials) and the Rack (right: what you BUY with
## refined goods). Two columns of ten rows, no scrolling, no scrollbar, no shift-digit.
func _tab_works(content: Rect2, g: Dictionary) -> void:
	var col_w: float = g["col_w"]
	var rows: int = int(g["rows"])
	_works_column(Rect2(content.position, Vector2(col_w, content.size.y)), "MACHINES",
		craft_options, 0, rows, true)
	_works_column(Rect2(Vector2(content.position.x + col_w + 12.0, content.position.y),
		Vector2(col_w, content.size.y)), "THE RACK", rack_options, craft_options.size(), rows, false)


## One column of buyable rows. `base` is where this column starts in the panel's flat cursor index, so the
## highlight and `bazaar_action()` cannot disagree about which row is which.
func _works_column(box: Rect2, title: String, opts: Array[Dictionary], base: int, rows: int,
		machines: bool) -> void:
	draw_string(_font, box.position + Vector2(4.0, 12.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_ACCENT)
	if opts.is_empty():
		draw_string(_font, box.position + Vector2(4.0, 34.0), "(nothing here yet)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)
		return
	# Show a window around the cursor rather than truncating, so a list longer than the column can still be
	# reached — but the window only ever moves when the cursor leaves it, so the rows do not slide about.
	var first: int = 0
	if opts.size() > rows:
		first = clampi(bazaar_row - base - rows / 2, 0, opts.size() - rows)
	for i: int in mini(rows, opts.size()):
		var oi: int = first + i
		var rr := Rect2(box.position + Vector2(0.0, BAZAAR_COL_HEAD + float(i) * BAZAAR_ROW_H),
			Vector2(box.size.x, BAZAAR_ROW_H - 3.0))
		_works_row(rr, opts[oi], _works_id(machines, oi), base + oi == bazaar_row)
	if opts.size() > rows:
		draw_string(_font, box.position + Vector2(box.size.x - 40.0, 12.0),
			"%d/%d" % [bazaar_row - base + 1, opts.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UI_TEXT_DIM)


func _works_id(machines: bool, i: int) -> StringName:
	if machines:
		return _craft_id(i)
	return rack_ids[i] if i < rack_ids.size() else &""


func _works_row(rr: Rect2, opt: Dictionary, id: StringName, selected: bool) -> void:
	draw_rect(rr, UI_SLOT)
	var lock: StringName = ResearchRules.locking_tech(id)
	var locked: bool = lock != &"" and not sim.is_researched(lock)
	var afford: bool = _can_afford(opt["cost"])
	if selected:
		draw_rect(rr.grow(1.0), UI_ACCENT, false, 1.5)
	else:
		draw_rect(rr, UI_EDGE, false, 1.0)
	_draw_thing_icon(id, Rect2(rr.position + Vector2(4.0, 2.5),
		Vector2(BAZAAR_ROW_H - 8.0, BAZAAR_ROW_H - 8.0)))
	if locked:
		draw_rect(rr, Color(0.0, 0.0, 0.0, 0.35))
	var right: String = ("needs %s" % str(ResearchRules.tech(lock)["name"])) if locked else _cost_text(opt["cost"])
	var right_col: Color = Color(0.62, 0.50, 0.34) if locked else (UI_ACCENT if afford else Color(0.45, 0.40, 0.30))
	var name_col: Color = Color(0.40, 0.42, 0.48) if locked else (UI_TEXT if afford else Color(0.45, 0.47, 0.53))
	var cw: float = _font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(_font, rr.position + Vector2(BAZAAR_ROW_H - 1.0, 14.0), str(opt["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - BAZAAR_ROW_H - cw - 8.0, 11, name_col)
	draw_string(_font, rr.position + Vector2(rr.size.x - cw - 5.0, 14.0), right,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, right_col)


## A machine's sprite or an item's glyph, whichever this id is. Both the pack grid, the works rows and the
## tech chips want exactly this and used to each carry their own copy of it.
func _draw_thing_icon(id: StringName, box: Rect2) -> void:
	if machine_icons.has(id):
		var spr: Texture2D = Art.tex("machine_" + String(id))
		if spr != null:
			draw_texture_rect(spr, box, false)
			return
		draw_rect(box, machine_icons[id]["color"])
		Visuals.draw_machine_glyph(self, box.position + box.size * 0.5,
			str(machine_icons[id]["kind"]), box.size.y / 20.0, false, 0.0)
		return
	if id != &"":
		Visuals.draw_item(self, box.position + box.size * 0.5, box.size.y, id)


## BENCH — the research ladder as a graph, AND the verb that acts on it, on one screen.
##
## This is the fix for the worst of the six: the tree used to be a separate full-screen overlay on `T` that
## showed you the ladder you could not act on, because the research verb lived back inside the pack screen.
## You read here and acted there. Now the ladder is a tab of the same counter, a cursor walks it, and the
## selected node is the one the verb takes — so what you are looking at and what you would get are the same
## thing by construction rather than by remembering.
##
## Tiers derive from each tech's `requires` chain, so a branching tree simply stacks its chips in a column
## and no layout changes. The chips are SCALED to the panel rather than the panel to the chips: the ladder
## grows, the counter does not.
func _tab_bench(content: Rect2) -> void:
	var tiers: Array = []
	for tid: StringName in ResearchRules.ORDER:
		var d: int = 0
		var cur: StringName = ResearchRules.tech(tid).get("requires", &"")
		while cur != &"":
			d += 1
			cur = ResearchRules.tech(cur).get("requires", &"")
		while tiers.size() <= d:
			tiers.append([])
		(tiers[d] as Array).append(tid)
	if tiers.is_empty():
		return
	var tallest: int = 1
	for tier: Array in tiers:
		tallest = maxi(tallest, tier.size())
	var gap := Vector2(10.0, 6.0)
	var body_h: float = content.size.y - 14.0                  # a line of footer under the graph
	var chip := Vector2(
		minf(102.0, (content.size.x - float(tiers.size() - 1) * gap.x) / float(tiers.size())),
		minf(74.0, (body_h - float(tallest - 1) * gap.y) / float(tallest)))
	var span := Vector2(float(tiers.size()) * chip.x + float(tiers.size() - 1) * gap.x,
		float(tallest) * chip.y + float(tallest - 1) * gap.y)
	var at := Vector2(content.position.x + (content.size.x - span.x) * 0.5, content.position.y)
	var rects: Dictionary = {}
	for ti: int in tiers.size():
		var tier: Array = tiers[ti]
		var col_h: float = float(tier.size()) * chip.y + float(tier.size() - 1) * gap.y
		for ni: int in tier.size():
			rects[tier[ni]] = Rect2(at + Vector2(float(ti) * (chip.x + gap.x),
				(span.y - col_h) * 0.5 + float(ni) * (chip.y + gap.y)), chip)
	# Arrows first, under the chips: the prereq's right edge to the dependent's left edge. A path you have
	# already walked glows, so the tree reads as a route rather than as a table.
	for tid: StringName in ResearchRules.ORDER:
		var req: StringName = ResearchRules.tech(tid).get("requires", &"")
		if req == &"" or not rects.has(req):
			continue
		var a: Rect2 = rects[req]
		var b: Rect2 = rects[tid]
		var p0 := Vector2(a.end.x, a.position.y + a.size.y * 0.5)
		var p1 := Vector2(b.position.x, b.position.y + b.size.y * 0.5)
		var lc: Color = Color(0.55, 0.75, 0.55, 0.8) if sim.is_researched(req) \
			else Color(UI_EDGE.r, UI_EDGE.g, UI_EDGE.b, 0.8)
		draw_line(p0, p1, lc, 1.5)
		draw_colored_polygon(PackedVector2Array([p1, p1 + Vector2(-5.0, -3.5), p1 + Vector2(-5.0, 3.5)]), lc)
	var next: StringName = ResearchRules.next_tech(sim.research)
	var picked: StringName = &""
	var act: Dictionary = bazaar_action()
	if act.get("kind", "") == "tech":
		picked = act["id"]
	for tid: StringName in ResearchRules.ORDER:
		_draw_tech_chip(tid, rects[tid], tid == next, tid == picked)
	_draw_bench_foot(content, picked, next)


## One line under the ladder saying what Enter would do to the SELECTED node — not to "the next one". A tree
## that highlights one node and acts on another is the same look-here-act-there bug in miniature.
func _draw_bench_foot(content: Rect2, picked: StringName, next: StringName) -> void:
	var y: float = content.end.y - 3.0
	var foot: String
	var col: Color = UI_TEXT_DIM
	if picked == &"":
		foot = "every tech researched — the tree is yours" if next == &"" else "pick a rung"
	elif sim.is_researched(picked):
		foot = "%s — already yours" % str(ResearchRules.tech(picked)["name"])
		col = Color(0.45, 0.62, 0.48)
	elif picked != next:
		var req: StringName = ResearchRules.tech(picked).get("requires", &"")
		foot = "%s — locked behind %s" % [str(ResearchRules.tech(picked)["name"]),
			str(ResearchRules.tech(req)["name"]) if req != &"" else "an earlier rung"]
	elif not can_craft:
		foot = "Enter researches %s — at a claimed Bazaar" % str(ResearchRules.tech(picked)["name"])
		col = Color(0.58, 0.48, 0.32)
	else:
		foot = "Enter  research %s" % str(ResearchRules.tech(picked)["name"])
		col = UI_ACCENT
	draw_string(_font, Vector2(content.position.x + 2.0, y), foot, HORIZONTAL_ALIGNMENT_LEFT,
		content.size.x - 4.0, 10, col)


## One tech chip: lamp + name / analyze-sample / price / the unlocked machines as mini-glyphs.
func _draw_tech_chip(tid: StringName, rr: Rect2, is_next: bool, picked: bool = false) -> void:
	var t: Dictionary = ResearchRules.tech(tid)
	var done: bool = sim.is_researched(tid)
	draw_rect(rr, UI_SLOT)
	if is_next:
		draw_rect(rr.grow(1.0), UI_ACCENT, false, 1.5)     # the lit rung — the one the ladder is offering
	else:
		draw_rect(rr, UI_EDGE, false, 1.0)
	if picked:
		draw_rect(rr.grow(2.5), UI_EDGE_HI, false, 1.5)    # …and the one the CURSOR is on, which Enter takes
	var name_col: Color = Color(0.45, 0.62, 0.48) if done else (UI_TEXT if is_next else Color(0.40, 0.42, 0.48))
	# The chip is SCALED to the panel (the ladder grows, the counter does not), so its type has to scale with
	# it or a seven-tier tree prints "Prospecti". The lamp keeps its size and gives up its indent first,
	# because a truncated NAME costs the player more than a tight margin does.
	var narrow: bool = rr.size.x < 96.0
	var fs: int = 9 if narrow else 11
	var indent: float = 14.0 if narrow else 18.0
	draw_circle(rr.position + Vector2(7.0 if narrow else 10.0, 11.0), 3.2,
		Color(0.38, 0.78, 0.44) if done else (UI_ACCENT if is_next else Color(0.22, 0.24, 0.30)))
	draw_string(_font, rr.position + Vector2(indent, 14.0), str(t["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - indent - 4.0, fs, name_col)
	# The price: what you analyze + what you pour in. Dim on done (paid), gold-if-affordable on next.
	var sample: StringName = t.get("sample", &"")
	var afford: bool = _can_afford(t["cost"]) and (sample == &"" or int(sim.inventory.get(sample, 0)) >= 1)
	var line_col: Color = Color(0.42, 0.52, 0.45) if done \
		else ((UI_ACCENT if afford else Color(0.62, 0.52, 0.34)) if is_next else Color(0.40, 0.42, 0.48))
	if sample != &"":
		draw_string(_font, rr.position + Vector2(6.0, 28.0), "analyze %s" % _item_label(sample),
			HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 10.0, 8, line_col)
	draw_string(_font, rr.position + Vector2(6.0, 40.0), "+ " + _cost_text(t["cost"]),
		HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 10.0, 8, line_col)
	# What it buys: the unlocked machines' faces, dimmed until the tech is live.
	var ux: float = rr.position.x + 6.0
	for uid: StringName in (t.get("unlocks", []) as Array):
		var box := Rect2(ux, rr.position.y + 48.0, 16.0, 16.0)
		if box.end.x > rr.end.x - 2.0 or box.end.y > rr.end.y - 2.0:
			break                                          # a narrow chip shows what it can, never overflows
		if machine_icons.has(uid):
			var spr: Texture2D = Art.tex("machine_" + String(uid))
			if spr != null:
				draw_texture_rect(spr, box, false)
			else:
				draw_rect(box, machine_icons[uid]["color"])
				Visuals.draw_machine_glyph(self, box.position + box.size * 0.5,
					str(machine_icons[uid]["kind"]), box.size.y / 20.0, false, 0.0)
		else:
			Visuals.draw_item(self, box.position + box.size * 0.5, box.size.y, uid)
		if not done:
			draw_rect(box, Color(0.0, 0.0, 0.0, 0.25 if is_next else 0.45))
		ux += 19.0
	if not done and not is_next:
		draw_rect(rr, Color(0.0, 0.0, 0.0, 0.30))          # locked: the whole chip recedes


## THE PRODUCTION DASHBOARD ([G]): the flywheel made legible — the factory's whole
## output at a glance so scaling is FELT, not guessed. Two columns, both pure sim reads: THROUGHPUT
## (production_rates() → per-item /min bars, relative + absolute, sorted fastest-first, grand total) and
## FACTORY (machine_census() → machines by type with a live working-count). Non-modal, like the tech
## tree — a status read, never blocks the world.
func _draw_dashboard_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.0, 0.0, 0.0, 0.5))
	var w: float = 392.0
	var h: float = 238.0
	var origin := Vector2((CANVAS.x - w) * 0.5, (CANVAS.y - h) * 0.5)
	_panel(Rect2(origin, Vector2(w, h)), true)
	draw_string(_font, origin + Vector2(14.0, 22.0), "PRODUCTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI_ACCENT)
	draw_string(_font, origin + Vector2(w - 108.0, 21.0), "G / Esc to close",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)
	draw_line(origin + Vector2(206.0, 34.0), origin + Vector2(206.0, h - 12.0), UI_EDGE, 1.0)  # column rule

	# --- left column: THROUGHPUT (the flywheel — is output growing?) -----------------------------
	var lx: float = origin.x + 14.0
	var rates: Array[Dictionary] = sim.production_rates()
	var grand: float = 0.0
	var top: float = 0.0
	for r: Dictionary in rates:
		grand += float(r["rate"])
		top = maxf(top, float(r["rate"]))
	draw_string(_font, Vector2(lx, origin.y + 48.0), "THROUGHPUT · last 60s",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_DIM)
	draw_string(_font, Vector2(lx, origin.y + 66.0), "%.1f" % grand, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI_ACCENT)
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
		for i: int in mini(9, rates.size()):                  # top nine — the panel's height budget
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

	# --- right column: FACTORY census (the empire — how big, how healthy?) ------------------------
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
		draw_string(_font, Vector2(rx, origin.y + 63.0), "%d working" % working_m,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.78, 0.55))
		var y2: float = origin.y + 84.0
		for i: int in mini(9, census.size()):
			var row: Dictionary = census[i]
			var mdef: MachineDef = row["def"]
			var box := Rect2(rx, y2 - 11.0, 15.0, 15.0)
			draw_rect(box, Visuals.machine_color(mdef))
			Visuals.draw_machine_glyph(self, box.position + box.size * 0.5,
				Visuals.machine_kind(mdef), box.size.y / 20.0, false, 0.0)
			draw_string(_font, Vector2(rx + 20.0, y2), str(row["name"]), HORIZONTAL_ALIGNMENT_LEFT, 96.0, 9, UI_TEXT)
			# count · working — green when all are running, amber when some are stalled
			var cnt: int = int(row["count"])
			var wrk: int = int(row["working"])
			var stat_col: Color = Color(0.55, 0.78, 0.55) if wrk == cnt else UI_ACCENT
			draw_string(_font, Vector2(rx + 118.0, y2), "%d" % cnt, HORIZONTAL_ALIGNMENT_RIGHT, 24.0, 10, UI_TEXT)
			draw_string(_font, Vector2(rx + 144.0, y2), "%d▸" % wrk, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, stat_col)
			y2 += 16.6


## The id of the i-th craftable — supplied explicitly by MainView (craft_ids, parallel to craft_options),
## so machines and tools can interleave without relying on machine_icons insertion order. Falls back to the
## old machine_icons-keys derivation if craft_ids wasn't set (defensive).
func _craft_id(i: int) -> StringName:
	if i < craft_ids.size():
		return craft_ids[i]
	var keys: Array = machine_icons.keys()
	return keys[i] if i < keys.size() else &""


## The HELP overlay (H / ?) — the full control list, summoned not stuck on screen. Centred card.
func _draw_help_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.0, 0.0, 0.0, 0.45))
	var lines: Array[String] = [
		"move        A / D  (or ← →)",
		"jump        W  or  SPACE",
		"climb       W / S  on a rope (W climbs, not jumps)",
		"grapple     F  — throw at the ringed rock; throw again to swing on, Space to let go",
		"swing       W / S reel the line in / out · SPACE leaps off it",
		# The three techniques the winch grew. Each is taught in place by a hint the first time you are in
		# the situation (scenes/hints.gd), but a lesson you can only be told once is a lesson you can miss,
		# so the card carries them too — same key-first voice as every line above it.
		"chain       F again in mid-air — the next line keeps the speed you left with",
		"wrap        the line bends round corners; the shorter it gets, the harder it whips",
		"catch       F on the way down — the line ends the fall, and the cost of landing it",
		"mine        LMB (hold)",
		"dig plan    LMB drag paints it · X clears",
		"select      1–9  ·  mouse wheel",
		"place / pick  RMB  (machine, rope, or block)",
		"scan        RMB  (Scanner selected — veins echo)",
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
	var w: float = 244.0
	var h: float = 30.0 + float(lines.size()) * 16.0 + 10.0
	var origin := Vector2((CANVAS.x - w) * 0.5, (CANVAS.y - h) * 0.5)
	_panel(Rect2(origin, Vector2(w, h)), true)
	draw_string(_font, origin + Vector2(14.0, 22.0), "CONTROLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI_ACCENT)
	var y: float = origin.y + 38.0
	for ln: String in lines:
		draw_string(_font, Vector2(origin.x + 16.0, y), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT)
		y += 16.0


## THE SETTINGS page: audio sliders + feel chips on the left, the full REMAP list on
## the right (the page the Controls foundation was built for). Every interactive control registers a
## hit-rect + payload; MainView routes clicks through settings_click() — the knob pattern (#32).
const REMAP_ROWS: Array[Array] = [
	[Controls.LEFT, "move left"], [Controls.RIGHT, "move right"],
	[Controls.UP, "climb up"], [Controls.DOWN, "climb down"],
	[Controls.JUMP, "jump"], [Controls.MINE, "mine (hold)"],
	[Controls.GRAPPLE, "grapple"],
	[Controls.BUILD, "build / place"], [Controls.DROP, "drop / feed"],
	[Controls.CRAFT, "pack"], [Controls.RESEARCH, "research / config"],
	[Controls.MAP, "map"], [Controls.TECH, "tech tree"],
	[Controls.DASHBOARD, "dashboard"], [Controls.HELP, "help"],
	[Controls.PAUSE, "pause"],
	[Controls.SPEED, "game speed"], [Controls.ZOOM, "zoom"],
	[Controls.SAVE, "quicksave"], [Controls.LOAD, "quickload"],
	[Controls.CLEAR_MARKS, "clear dig plan"],
]


func _draw_settings_overlay() -> void:
	_settings_hits.clear()
	_slider_rects.clear()
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.0, 0.0, 0.0, 0.55))
	var panel := Rect2(90.0, 14.0, 460.0, 332.0)
	_panel(panel, true)
	draw_string(_font, panel.position + Vector2(16.0, 24.0), "SETTINGS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI_ACCENT)
	draw_string(_font, panel.position + Vector2(panel.size.x - 78.0, 24.0), "ESC closes",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)
	var mouse: Vector2 = get_viewport().get_mouse_position()
	# --- left column: AUDIO + FEEL ---
	var x0: float = panel.position.x + 16.0
	draw_string(_font, Vector2(x0, 58.0), "AUDIO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)
	_settings_slider(x0, 78.0, "master", "master", Settings.master)
	_settings_slider(x0, 98.0, "sound", "sound", Settings.sound)
	_settings_slider(x0, 118.0, "ambience", "ambience", Settings.ambience)
	_settings_slider(x0, 138.0, "music", "music", Settings.music)
	draw_string(_font, Vector2(x0, 170.0), "FEEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)
	draw_string(_font, Vector2(x0, 190.0), "screen shake", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT)
	_settings_chip(x0 + 92.0, 190.0, "ON" if Settings.screen_shake else "OFF",
		{"toggle": "shake"}, Settings.screen_shake, mouse)
	draw_string(_font, Vector2(x0, 210.0), "zoom", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT)
	_settings_chip(x0 + 92.0, 210.0, "%.2fx" % MainView.ZOOM_LEVELS[
		clampi(Settings.zoom_idx, 0, MainView.ZOOM_LEVELS.size() - 1)], {"cycle": "zoom"}, false, mouse)
	draw_string(_font, Vector2(x0, 230.0), "auto-pickup", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT)
	_settings_chip(x0 + 92.0, 230.0, "ON" if Settings.auto_pickup else "OFF",
		{"toggle": "auto_pickup"}, Settings.auto_pickup, mouse)
	_settings_chip(x0, panel.position.y + panel.size.y - 20.0, "RESET KEYS TO DEFAULTS",
		{"reset": true}, false, mouse)
	draw_string(_font, Vector2(x0, panel.position.y + panel.size.y - 38.0),
		"click a binding, then press its new key", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_DIM)
	# --- right column: CONTROLS (the remap page) ---
	var x1: float = panel.position.x + 212.0
	var chip_right: float = panel.position.x + panel.size.x - 16.0
	draw_string(_font, Vector2(x1, 58.0), "CONTROLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)
	var y: float = 74.0
	for row: Array in REMAP_ROWS:
		var action: StringName = row[0]
		var label: String = str(row[1])
		draw_string(_font, Vector2(x1, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)
		var capturing: bool = settings_capture == action
		var bind_text: String = "press a key…" if capturing else Settings.binding_label(action)
		var bw: float = _font.get_string_size(bind_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 10.0
		var chip := Rect2(chip_right - bw, y - 10.0, bw, 13.0)
		var lit: bool = chip.has_point(mouse)
		draw_rect(chip, UI_ACCENT if capturing else (Color(0.30, 0.34, 0.44) if lit else UI_SLOT))
		draw_rect(chip, Color(0.0, 0.0, 0.0, 0.5), false, 1.0)
		draw_string(_font, Vector2(chip.position.x + 5.0, y), bind_text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 10, Color(0.10, 0.10, 0.12) if capturing else UI_TEXT)
		_settings_hits.append({"rect": chip, "payload": {"bind": String(action)}})
		y += 13.8


## One slider row: label + a clickable/drag-able bar + the live percentage.
func _settings_slider(x0: float, y: float, id: String, label: String, value: float) -> void:
	draw_string(_font, Vector2(x0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT)
	var bar := Rect2(x0 + 62.0, y - 9.0, 100.0, 10.0)
	_slider_rects[id] = bar
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.5))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(value, 0.0, 1.0), bar.size.y)), UI_ACCENT)
	draw_rect(bar, UI_EDGE, false, 1.0)
	draw_string(_font, Vector2(bar.position.x + bar.size.x + 8.0, y), "%d%%" % int(round(value * 100.0)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)
	# The whole bar (with a touch of slop) is the hit zone; the payload carries the clicked fraction.
	_settings_hits.append({"rect": bar.grow(3.0), "payload": {"slider": id}})


func _settings_chip(x: float, y: float, text: String, payload: Dictionary, active: bool,
		mouse: Vector2) -> void:
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12.0
	var chip := Rect2(x, y - 11.0, w, 15.0)
	draw_rect(chip, UI_ACCENT if active else (Color(0.30, 0.34, 0.44) if chip.has_point(mouse) else UI_SLOT))
	draw_rect(chip, Color(0.0, 0.0, 0.0, 0.5), false, 1.0)
	draw_string(_font, Vector2(x + 6.0, y + 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.10, 0.10, 0.12) if active else UI_TEXT)
	_settings_hits.append({"rect": chip, "payload": payload})


## The control payload under a canvas point ({} = none) — sliders add the clicked fraction so a
## single press already sets the value (drag then refines it via settings_slider_frac).
func settings_click(canvas_pos: Vector2) -> Dictionary:
	for hit: Dictionary in _settings_hits:
		if (hit["rect"] as Rect2).has_point(canvas_pos):
			var payload: Dictionary = (hit["payload"] as Dictionary).duplicate()
			if payload.has("slider"):
				payload["frac"] = settings_slider_frac(str(payload["slider"]), canvas_pos.x)
			return payload
	return {}


## Fraction along a slider's bar for a canvas x — used by click AND drag (MainView keeps updating
## through mouse motion while the button stays down, even if the cursor drifts off the bar).
func settings_slider_frac(id: String, canvas_x: float) -> float:
	var bar: Rect2 = _slider_rects.get(id, Rect2())
	if bar.size.x <= 0.0:
		return 0.0
	return clampf((canvas_x - bar.position.x) / bar.size.x, 0.0, 1.0)


## A tiny dim hint, bottom-left — the toggle keys, so the player knows the menus exist without the old
## always-on keyboard-reference footer hogging the whole bottom edge.
func _draw_hint() -> void:
	draw_string(_font, Vector2(10.0, CANVAS.y - 8.0), "F hook   ·   Q drop   ·   E pack   ·   M map   ·   H keys",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)


func _can_afford(cost: Dictionary) -> bool:
	for item: StringName in cost:
		if int(sim.inventory.get(item, 0)) < int(cost[item]):
			return false
	return true


func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for item: StringName in cost:
		parts.append("%d %s" % [int(cost[item]), _item_label(item)])   # "6 Iron Ingot", never a raw id
	return " ".join(parts)


## The carried pack as a hotbar of slots (icon + count), centred along the bottom. The active slot
## (mouse-wheel) is highlighted; it's the item E deposits. Reads `sim.inventory_slots()`.
func _draw_inventory() -> void:
	var slots: Array[Dictionary] = sim.inventory_slots()
	# Show ONLY the slots you actually carry, not a fixed row of empty wells — a trailing empty slot reads
	# as "broken / what goes here?". The bar grows/shrinks with your pack (min 1 so it never vanishes).
	var n: int = clampi(slots.size(), 1, FactorySim.INVENTORY_SLOTS)
	var sel: int = int(inv_selected_getter.call()) if inv_selected_getter.is_valid() else 0
	var total_w: float = n * SLOT + (n - 1) * SLOT_GAP
	var x0: float = (CANVAS.x - total_w) * 0.5
	var y: float = CANVAS.y - 28.0 - SLOT
	# A clean framed backing just for the hotbar (the craft strip that used to share this panel now lives
	# in the E screen). Keeps the bar reading as one deliberate unit, not floating slots.
	_panel(Rect2(x0 - 8.0, y - 7.0, total_w + 16.0, SLOT + 14.0), true)
	for i: int in n:
		var sx: float = x0 + float(i) * (SLOT + SLOT_GAP)
		var slot_rect := Rect2(sx, y, SLOT, SLOT)
		var active: bool = i == sel
		if i < slots.size() and slot_rect.has_point(get_viewport().get_mouse_position()):
			_tooltip_item = slots[i]["item"]                     # hovered hotbar slot → tooltip
			_tooltip_count = int(slots[i]["count"])
			_tooltip_anchor = Vector2(slot_rect.get_center().x, slot_rect.position.y)
		if active:
			draw_rect(slot_rect.grow(2.0), Color(UI_ACCENT.r, UI_ACCENT.g, UI_ACCENT.b, 0.18))  # selection glow
		draw_rect(slot_rect, UI_SLOT)                                                            # well
		draw_line(slot_rect.position + Vector2(1.0, 1.0), slot_rect.position + Vector2(SLOT - 1.0, 1.0),
			UI_EDGE_HI, 1.0)                                                                      # top bevel
		draw_rect(slot_rect, UI_ACCENT if active else UI_EDGE, false, 2.0 if active else 1.0)
		# Faint keybind number in the slot corner (1-8) so the hotbar reads as keyed.
		draw_string(_font, slot_rect.position + Vector2(2.0, 9.0), str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.45, 0.48, 0.56))
		if i < slots.size():
			var item: StringName = slots[i]["item"]
			var count: int = int(slots[i]["count"])
			var icon := Rect2(sx + 6.0, y + 6.0, SLOT - 12.0, SLOT - 14.0)
			if machine_icons.has(item):  # a machine item: its sprite, or casing colour + a mini silhouette
				var mspr: Texture2D = Art.tex("machine_" + String(item))
				if mspr != null:
					draw_texture_rect(mspr, icon, false)
				else:
					var ic: Dictionary = machine_icons[item]
					draw_rect(icon, ic["color"])
					draw_rect(icon, Color(0.0, 0.0, 0.0, 0.35), false, 1.0)
					# Same glyph the world draws (shared Visuals), scaled to the chip — never drifts.
					Visuals.draw_machine_glyph(self, icon.position + icon.size * 0.5, str(ic["kind"]),
						icon.size.y / 20.0, false, 0.0)
			else:  # a resource item: its sprite (item_<id>.png) or the flat colour chip
				Visuals.draw_item(self, icon.position + icon.size * 0.5, icon.size.y, item)
			# Count badge bottom-right with a dark backing so it stays legible over any icon colour.
			var cnt: String = str(count)
			var cw: float = _font.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_rect(Rect2(sx + SLOT - cw - 5.0, y + SLOT - 13.0, cw + 4.0, 12.0), Color(0.03, 0.03, 0.05, 0.85))
			draw_string(_font, Vector2(sx + SLOT - cw - 3.0, y + SLOT - 3.0), cnt,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT)
	# Name the SELECTED item just above the bar — so the coloured chips stop being mystery squares.
	if sel < slots.size():
		var label: String = _item_label(slots[sel]["item"])
		var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var lx: float = x0 + float(sel) * (SLOT + SLOT_GAP) + (SLOT - lw) * 0.5
		var ly: float = y - 12.0
		draw_rect(Rect2(lx - 5.0, ly - 11.0, lw + 10.0, 15.0), Color(0.05, 0.06, 0.09, 0.88))
		draw_string(_font, Vector2(lx, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_ACCENT)


## The hovered slot's TOOLTIP: the item's name, the count you hold, and one purpose
## line — "what is this FOR" answered where the question is asked. Captured by the hotbar/pack-grid
## slot loops this frame; drawn last, above every panel, clamped on-canvas above the hovered slot.
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
	draw_rect(Rect2(rect.position, Vector2(2.0, rect.size.y)), UI_ACCENT)   # a gold spine, not a cap
	draw_string(_font, origin + Vector2(9.0, 15.0), name_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT)
	if purpose != "":
		draw_multiline_string(_font, origin + Vector2(9.0, 29.0), purpose,
			HORIZONTAL_ALIGNMENT_LEFT, wrap_w, fs, -1, Color(0.78, 0.74, 0.62))


## Human-readable name for a carried item: a machine item uses its def's display name (Forge/Drill/…),
## a resource its capitalised id (ore → "Ore"). Stops the hotbar chips from being unlabelled colour squares.
func _item_label(item: StringName) -> String:
	if machine_icons.has(item):
		return String(machine_icons[item].get("name", item))
	return String(item).capitalize()


func _buf(d: Dictionary) -> String:
	if d.is_empty():
		return "—"
	var parts: PackedStringArray = []
	for k: StringName in d:
		parts.append("%s %d" % [k, int(d[k])])
	return "  ".join(parts)
