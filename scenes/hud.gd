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
	# The Drift Rig has TWO outputs, so "output blocked" is not an answer to anything — it has to say which
	# column jammed, because the two are dug in different places (docs/DRIFT.md §7).
	&"blocked_pay": "ore column jammed — dig a drain UNDER it",
	&"blocked_spoil": "spoil column jammed — dig a drain BEHIND it",
	&"no_power": "no power — it eats a network, not a coal box",
	# SPENT is not STARVED. A Head that has finished its vein has nothing wrong with it, and telling the
	# player it is "starved" sends them hunting for a feed problem that does not exist (`docs/LODE.md` §5).
	&"spent": "the vein is worked out — pick it up and move it",
	&"unlinked": "nothing to feed — a Spur must touch a Drill, or a Spur that reaches one",
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
## NO SCROLLING VIEWPORT, and no dead space either. #S34 rebuilt the SURFACE on top of that shape: the rows
## became a dense card grid across three columns, and the space the old two-column layout wasted became a
## DETAIL PLATE along the bottom — the thing you are about to buy, drawn large enough to want, with its
## price and its verb in the same look. Twenty-one rows fit without scrolling; `check_pack_layout` asserts
## it rather than trusting it.
const BAZAAR_SIZE := Vector2(608.0, 348.0)
const BAZAAR_RAIL: float = 56.0       ## the vertical tab rail down the left edge
const BAZAAR_PAD: float = 12.0
const BAZAAR_HEAD: float = 48.0       ## title + the carried-goods strip, with air under it
const BAZAAR_FOOT: float = 16.0       ## the key legend
const BAZAAR_DETAIL: float = 88.0     ## the detail plate along the bottom of the content
const BAZAAR_GUTTER: float = 10.0
## 24 again, not the 22 the two-column layout needed: three columns of eight is twenty-four rows, so the row
## can afford the two pixels back and the type can breathe.
const BAZAAR_ROW_H: float = 24.0
const BAZAAR_COLS: int = 3
## How long the counter takes to arrive. Not decoration: a panel that appears fully formed in one frame is
## the single loudest thing separating a menu from an interface, and 0.13s of rise is cheaper than any art.
const BAZAAR_RISE: float = 0.13
const TAB_PACK: int = 0
const TAB_WORKS: int = 1
const TAB_BENCH: int = 2
const TAB_NAMES: Array[String] = ["PACK", "WORKS", "BENCH"]
var bazaar_tab: int = TAB_PACK
var _bazaar_t: float = 0.0            ## 0..1 open ease, driven in _process
## THE RACK — the shop half of WORKS. Set by MainView beside `craft_options`, same {name, cost} shape, with
## `rack_ids` parallel to it. Kept a SEPARATE list rather than appended to the craft list because the two
## columns mean different things: the left is what you build from your own materials, the right is what you
## buy with refined goods (`docs/BITS.md` §7), and a player should never have to work out which is which.
var rack_options: Array[Dictionary] = []
var rack_ids: Array[StringName] = []
## The highlighted row on the active tab. One cursor for the whole panel: Enter acts on it, and what "acts"
## means is the tab's business — buy, craft, research.
var bazaar_row: int = 0
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
	&"gravel": "PACKED fill — the one block that doesn't weep when water leans on it",
	&"iron": "L2 ore — the Iron Forge smelts it into iron ingots",
	&"iron_ingot": "the L2 metal — plates, gears and the Iron Pickaxe",
	&"plate": "pressed iron sheet — the Borer's frame wants them",
	&"gear": "milled cog (iron + ingot) — the Borer's works want them",
	&"wood_pickaxe": "breaks tier-1 rock (earth · stone · ore · coal) — hold LMB",
	&"stone_pickaxe": "tier-2 pick — opens deepslate, iron and rich ore. A key, not a stat",
	&"iron_pickaxe": "tier-3 pick — the deepest key on the ladder, for what waits under L2",
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
	&"drift_rig": "cuts a 2-high gallery on POWER, and sorts it: ore drops below, spoil drops behind",
	&"crusher": "eats SPOIL, pours GRAVEL — pay falls straight through it, untouched",
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
	# The counter's arrival. Eased OUT, so it decelerates into place rather than sliding at a constant rate —
	# the difference between a panel that lands and a panel that is dragged on.
	var target: float = 1.0 if inventory_open else 0.0
	var step: float = delta / BAZAAR_RISE
	_bazaar_t = clampf(_bazaar_t + (step if target > _bazaar_t else -step * 2.0), 0.0, 1.0)
	queue_redraw()


## Ease-out cubic. The counter's rise reads as arriving because it slows down at the end.
func _bazaar_ease() -> float:
	var u: float = 1.0 - _bazaar_t
	return 1.0 - u * u * u


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
		# UNDER the objective line, not on top of it. Both were aimed at top-centre at y=8 and the
		# objective panel is 37 tall, so PAUSED printed straight across the one line telling you what to
		# do next — and pausing is exactly when a player stops to read it.
		var p := Rect2(CANVAS.x * 0.5 - 52.0, 50.0, 104.0, 26.0)
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
## The depth chip's width, on its own so the objective banner can measure what it must not grow under.
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
## The FORGED chip's width — the other wall the objective banner has to stay inside of.
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
	draw_string(_font, Vector2(x, cy + 6.0), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI_ACCENT)


## How long a fresh step shows its full how-to line, how long that takes to fade, and how long you have
## to sit on one step before it comes back (#B4).
const HINT_HOLD: float = 9.0
const HOVER_MAX_W: float = 300.0   ## the inspector may grow to fit its widest line, but no further
const HINT_FADE: float = 1.5
const HINT_STUCK: float = 40.0

## THE PERMANENT PLATE IS THE PART THAT DIES (kill list #1; Diegetic 3.7).
##
## The how-to line already knew how to leave: it holds, fades, and comes back when you stall. The GOAL line
## did not — it sat at top-centre for every step, all thirteen of them, which is the "~85-90% of the
## interface floats above the world" finding and the reason the audit called the presentation system the
## art director. The complaint is PERMANENCE, not existence: a game may tell you what just became possible,
## it may not stand over you while you do it.
##
## So AFTER THE OPENING LESSON, NOTHING IS OFFERED. Later steps do not announce, do not hold, and do not
## fade — the top of the screen is simply empty, and guidance is REACTIVE ONLY: it returns when you have
## genuinely stalled, and not before. The world does the talking meanwhile —
## `world_renderer._draw_guide_targets()` already pulses a ring on the cells the current step points at,
## which is the "attach subsequent guidance to the relevant world object" half of the same recommendation,
## and it was already built and previously drowned out.
##
## This is the LITERAL reading, and it is a design call rather than a measurement one (2026-08-17). I built the
## softer version first — announce, hold six seconds, fade — and logged it in `the working notes` as a
## fork with the argument against my own choice: that reading an unambiguous kill-list item as ambiguous is
## less work and less risk for me, and that is how a kill list gets negotiated down one entry at a time.
## The directive chose literal. The soft version is one `else` branch away if it is ever wanted back.
##
## THIS IS ALSO THE PRECONDITION FOR MEASURING ANY OF IT. `docs/DIRECTOR_BRIEF.md` §4.4 scores whether a
## player forms a desire when NO objective is supplied; while a permanent slab supplies one, that
## evaluation reads the supervisor instead of the player and cannot return a valid result on this build.
##
## `GOAL_PERSISTS_THROUGH` is how many steps count as "the opening lesson" — the ones that keep the old
## permanent plate, so nobody is stranded on the first thing they ever see. At 1 that is the first step
## only. Raise it to teach longer; set it to 0 to remove the plate outright, including from the opening.
const GOAL_FADE: float = 1.2       ## how long reactive guidance takes to arrive once you have stalled
const GOAL_PERSISTS_THROUGH: int = 1


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
	# THE BIG MAP IS THE SCREEN. It is centred and 272 tall in a 360 canvas, so its panel top sits at y=41
	# while this banner reaches y=45 whenever its how-to line is up — a four-pixel overlap that
	# `check_hud_layout` caught only INTERMITTENTLY, because whether the how-to is on screen depends on
	# `step_age`, which depends on how much sim time the layer happened to burn. A latent collision behind
	# a flaky assertion. Standing down here fixes it for every timing rather than nudging the map: someone
	# who opened the whole-world view is looking at the world, and a goal plate over it is the supervisor
	# talking across the one screen that is purely for reading the game.
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
		# Reactive guidance, the ONLY thing a later step may put on screen: it arrives once you have sat on
		# a step long enough to want it, and it is zero until then.
		var stalled: float = clampf((age - HINT_STUCK) / GOAL_FADE, 0.0, 1.0)
		if objectives.current_index() < GOAL_PERSISTS_THROUGH:
			# The opening lesson keeps the plate, and the how-to that arrives with it and fades.
			if age < HINT_HOLD + HINT_FADE:
				hint_a = clampf((HINT_HOLD + HINT_FADE - age) / HINT_FADE, 0.0, 1.0)
			elif age > HINT_STUCK:
				hint_a = stalled
		else:
			goal_a = stalled                     # nothing is OFFERED after the first lesson
			hint_a = stalled
		if hint_a > 0.0:
			hint = str(step["label"])
	if goal_a <= 0.0 and hint_a <= 0.0:
		return                                    # nothing to say: leave the sky alone
	var fs: int = 13
	var hfs: int = 10
	var pad: float = 12.0
	# THE FREE SPAN. The banner is centred between two fixed chips — depth on the left, FORGED on the
	# right — so a long how-to line grows symmetrically until the plate's own frame runs under one and
	# through the other. ("Toss ore down the mineshaft into the forge…" did exactly that.) Clamp to what
	# is actually free and let the HOW-TO be the part that gives: the goal is the half you need.
	var free_w: float = CANVAS.x - (maxf(_depth_chip_w(), _forged_chip_w()) + 18.0) * 2.0
	text = _fit_text(text, fs, free_w - pad * 2.0 - 14.0)
	hint = _fit_text(hint, hfs, free_w - pad * 2.0)
	var tw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0
	var hw: float = _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs).x if hint != "" else 0.0
	var w: float = minf(maxf(tw, hw) + pad * 2.0, free_w)
	var h: float = 24.0 + (13.0 if hint != "" else 0.0)
	var rect := Rect2((CANVAS.x - w) * 0.5, 8.0, w, h)
	_panel(rect, true, maxf(goal_a, hint_a))   # the skin is as present as its most visible line
	var cy: float = rect.position.y + 12.0
	if not objectives.all_done():
		draw_circle(Vector2(rect.position.x + pad + 1.0, cy), 3.0, Color(UI_ACCENT, UI_ACCENT.a * goal_a))
	draw_string(_font, Vector2(rect.position.x + pad + 14.0, cy + 5.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, col.a * goal_a))
	if hint != "":
		draw_string(_font, Vector2(rect.position.x + pad, cy + 18.0), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, Color(UI_TEXT_DIM, hint_a))


## Trim a string until it fits `max_w`, with an ellipsis standing in for what was cut. Binary-search-free
## on purpose: these are one-line labels, the loop runs a handful of times, and a wrong answer here is a
## sentence running off a panel rather than a frame-rate problem.
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


## A framed, lightly-beveled panel backing — the shared skin for every HUD widget (objectives,
## inspector, minimap, the bottom pack). A faint lit top edge makes it read as raised rather than a
## flat sticker; `accent` paints a gold cap bar for headlined panels.
## TEST HOOK — when non-null, every panel this frame appends its rect here and nothing else changes.
##
## The HUD is immediate-mode: there are no Control nodes, so nothing about the layout can be read off the
## scene tree, and a layout test would otherwise have to RE-DERIVE where each chip goes. A test that
## recomputes the layout it is checking agrees with itself by construction and catches nothing. This is
## two lines that let `check_hud_layout` observe the boxes the HUD ACTUALLY DREW, at real screen size, in
## the real scene. Left null in play, so it costs one null check per panel.
static var panel_probe: Array[Rect2]


## `alpha` modulates the whole skin so a panel can FADE rather than blink out. Panels that fade fully are
## expected to return before calling this at all, so the probe keeps recording only what was really drawn.
func _panel(rect: Rect2, accent: bool = false, alpha: float = 1.0) -> void:
	if panel_probe != null:
		panel_probe.append(rect)
	draw_rect(rect, Color(UI_BG, UI_BG.a * alpha))
	draw_line(rect.position + Vector2(1.0, 1.0), rect.position + Vector2(rect.size.x - 1.0, 1.0),
		Color(UI_EDGE_HI, UI_EDGE_HI.a * alpha), 1.0)
	draw_rect(rect, Color(UI_EDGE, UI_EDGE.a * alpha), false, 1.0)
	if accent:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2.0)), Color(UI_ACCENT, UI_ACCENT.a * alpha))


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
	var pad: float = 9.0
	var line_h: float = 18.0
	# THE PANEL TAKES THE WIDTH OF ITS WIDEST LINE. It is anchored to the right edge of the canvas, so a
	# line that overflowed a fixed 218px ran off the SCREEN — which is how "too hard for your pick — craft
	# a Stone Pickaxe", the single most important sentence the inspector says, came out as "craft a Stone
	# Pick". Capped, and anything past the cap is ellipsized rather than lost off the edge.
	var name_text: String = str(hover_info.get("name", ""))
	var mode_text: String = str(hover_info.get("mode", "")) if has_mode else ""
	var rate_text: String = str(hover_info.get("rate", "")) if has_rate else ""
	var widest: float = _font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	for line: String in [mode_text, rate_text]:
		if line != "":
			widest = maxf(widest, _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
	var width: float = clampf(widest + pad * 2.0, 218.0, HOVER_MAX_W)
	name_text = _fit_text(name_text, 13, width - pad * 2.0)
	mode_text = _fit_text(mode_text, 11, width - pad * 2.0)
	rate_text = _fit_text(rate_text, 11, width - pad * 2.0)
	var rows: int = 1 + int(has_recipe) + int(has_mode) + int(not holding.is_empty()) + int(has_rate) \
		+ knobs.size() + int(not bar.is_empty())
	# Sits below whatever occupies the top-right column: the CORNER minimap if it's shown (the large map
	# is centred, off this column), else just the FORGED chip — so the inspector never collides.
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
##
## The shape is a rail, a head, a grid of rows, and a DETAIL PLATE across the bottom. The plate is the whole
## argument of #S34: the old layout gave the goods a 16px glyph on a 22px row and then left a third of the
## panel empty, so nothing in the shop was ever drawn large enough to want. Rows are for choosing between;
## the plate is for wanting. Splitting those two jobs is also what let the rows get denser — a row no longer
## has to carry a description, because there is somewhere for the description to live.
func _bazaar_geometry() -> Dictionary:
	var origin := Vector2((CANVAS.x - BAZAAR_SIZE.x) * 0.5, (CANVAS.y - BAZAAR_SIZE.y) * 0.5)
	var inner_x: float = origin.x + BAZAAR_RAIL + BAZAAR_PAD
	var inner_w: float = BAZAAR_SIZE.x - BAZAAR_RAIL - BAZAAR_PAD * 2.0
	var body_h: float = BAZAAR_SIZE.y - BAZAAR_HEAD - BAZAAR_FOOT
	var content := Rect2(inner_x, origin.y + BAZAAR_HEAD, inner_w, body_h - BAZAAR_DETAIL - 8.0)
	var detail := Rect2(inner_x, content.end.y + 8.0, inner_w, BAZAAR_DETAIL)
	return {
		"origin": origin, "w": BAZAAR_SIZE.x, "h": BAZAAR_SIZE.y,
		"content": content, "detail": detail, "cols": BAZAAR_COLS,
		"col_w": (content.size.x - BAZAAR_GUTTER * float(BAZAAR_COLS - 1)) / float(BAZAAR_COLS),
		"row_h": BAZAAR_ROW_H,
		"rows": int(content.size.y / BAZAAR_ROW_H),
	}


## WHAT THE COUNTER WILL SELL YOU TODAY — the indices of the rows whose tech is already yours.
##
## #S34b: WORKS used to list the whole catalogue, sixteen machines deep, thirteen of them greyed out behind
## techs you had not reached. That is decision paralysis dressed as content: a wall of things you cannot have
## in the place you go to get things. The future has a home already — it is the BENCH, where every locked
## machine sits under the rung that unlocks it, greyed, in the one screen whose whole job is "what comes
## next". So the counter shows what you can BUILD and the ladder shows what you could build LATER, and
## neither one has to do both jobs badly.
func _unlocked(ids: Array[StringName], n: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in n:
		var id: StringName = ids[i] if i < ids.size() else &""
		var lock: StringName = ResearchRules.locking_tech(id)
		if lock == &"" or sim.is_researched(lock):
			out.append(i)
	return out


func open_machines() -> Array[int]:
	return _unlocked(craft_ids, craft_options.size())


func open_rack() -> Array[int]:
	return _unlocked(rack_ids, rack_options.size())


## How many columns each WORKS group takes, at this row height. Groups are laid left to right and never
## share a column, because the left list is what you BUILD from your own materials and the right is what you
## BUY with refined goods — a player should never have to work out which is which from a row's position.
func works_columns(rows: int) -> Dictionary:
	var m: int = maxi(1, ceili(float(open_machines().size()) / float(maxi(rows, 1))))
	var r: int = maxi(1, ceili(float(open_rack().size()) / float(maxi(rows, 1))))
	# The counter has a fixed number of columns, so if the two lists ever ask for more than it has, they get
	# SQUEEZED rather than allowed to run off the panel's edge — the group that overflows falls back to a
	# window around the cursor, which is ugly but reachable. This clamp is the FAILURE MODE made legible
	# instead of invisible, not the intended layout.
	#
	# THE PROPERTY: today the two lists together ask for no more columns than the counter has, so this
	# branch never fires. `check_pack_layout` holds that — and holds it correctly, which this comment used
	# to claim without it being true. It read `lay["total"] <= cols`, a number this function had *just*
	# clamped into range, so the assertion could not fail however far the lists overflowed and the citation
	# was vouching for a guarantee nobody was making. It now computes what the lists ask for BEFORE the
	# clamp sees it. Naming the property rather than only the test is the point: a citation is an assertion
	# made somewhere it cannot run, and this one was wrong for as long as it took someone to read both files.
	if m + r > BAZAAR_COLS:
		r = clampi(r, 1, BAZAAR_COLS - 1)
		m = BAZAAR_COLS - r
	return {"machines": m, "rack": r, "total": m + r}


## How many rows the active tab offers the cursor. WORKS is the two lists end to end; BENCH is the ladder.
func bazaar_row_count() -> int:
	match bazaar_tab:
		TAB_WORKS:
			return open_machines().size() + open_rack().size()
		TAB_BENCH:
			return ResearchRules.ORDER.size()
		_:
			return sim.inventory_slots().size()


## WHAT ENTER WOULD DO, as {kind, id} — kind is "machine", "rack", "tech" or "". The panel owns the cursor
## because the panel draws it; MainView owns the verbs. Splitting it this way means the highlighted row and
## the thing that happens can never drift apart, which is the bug that made `R` two different keys.
func bazaar_action() -> Dictionary:
	var i: int = bazaar_row
	match bazaar_tab:
		TAB_WORKS:
			if i < 0 or i >= bazaar_row_count():
				return {}
			# The cursor walks the OPEN rows; `row` is the index into the full catalogue, because that is
			# what MainView's verbs are keyed on. Filtering the view must never renumber the world.
			var open_m: Array[int] = open_machines()
			if i < open_m.size():
				return {"kind": "machine", "id": _craft_id(open_m[i]), "row": open_m[i]}
			var r: int = open_rack()[i - open_m.size()]
			return {"kind": "rack", "id": rack_ids[r] if r < rack_ids.size() else &"", "row": r}
		TAB_BENCH:
			if i < 0 or i >= ResearchRules.ORDER.size():
				return {}
			return {"kind": "tech", "id": ResearchRules.ORDER[i], "row": i}
		_:
			# PACK's verb is HOLD. It was the one tab with a cursor and nothing to do with it, which is also
			# why it read as half a screen — and holding a thing from the pack screen is exactly what the
			# stateless bit-equipping wants (`BitRules`): what is in your hand is what you dig with.
			var slots: Array[Dictionary] = sim.inventory_slots()
			if i < 0 or i >= slots.size():
				return {}
			return {"kind": "hold", "id": slots[i]["item"], "row": i}


## Move the cursor. `dy` steps a row; `dx` jumps a whole COLUMN, which is the same motion your eye makes and
## is what carries you across the counter-to-Rack gap in one keystroke rather than in ten.
func bazaar_move(dx: int, dy: int) -> void:
	var n: int = bazaar_row_count()
	if n <= 0:
		return
	if dx != 0:
		bazaar_row = clampi(bazaar_row + dx * int(_bazaar_geometry()["rows"]), 0, n - 1)
	bazaar_row = clampi(bazaar_row + dy, 0, n - 1)


func set_bazaar_tab(tab: int) -> void:
	bazaar_tab = clampi(tab, TAB_PACK, TAB_BENCH)
	bazaar_row = 0


## THE COUNTER. Drawn as a lamp-lit object rather than as a dialog box: elevation instead of a border, a
## gradient instead of a fill, one accent doing one job, and a 0.13s rise on open so it ARRIVES.
func _draw_inventory_overlay() -> void:
	# DIMMED, NOT BLACKED. You are at a counter with a shopkeeper standing next to you and banners over your
	# head — the staging `scenes/bazaars.gd` builds block by block — so the world stays legible behind the
	# panel instead of being switched off the moment you open it. MainView blurs it in the same breath
	# (`_bazaar_blur`), which is what makes the panel read as being IN FRONT of something.
	var t: float = _bazaar_ease()
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.02, 0.025, 0.04, 0.42 * t))
	_bazaar_vignette(0.5 * t)
	var g: Dictionary = _bazaar_geometry()
	var origin: Vector2 = g["origin"]
	var panel := Rect2(origin, Vector2(g["w"], g["h"]))
	# The whole counter rises the last few pixels into place. One transform, so nothing below has to know.
	draw_set_transform(Vector2(0.0, (1.0 - t) * 14.0), 0.0, Vector2.ONE)

	_soft_shadow(panel, 12, 0.34)
	_round_rect(panel, 8.0, Color(0.062, 0.070, 0.094, 0.985))
	_panel_sheen(panel)
	# The rail is the tab strip, turned on its side and given room to be an object. Three icons you can hit
	# with a glance beat three words you have to read.
	_draw_bazaar_rail(origin, g)
	_draw_bazaar_head(origin, g)
	match bazaar_tab:
		TAB_WORKS:
			_tab_works(g)
		TAB_BENCH:
			_tab_bench(g)
		_:
			_tab_pack(g)
	_draw_bazaar_detail(g)
	_draw_bazaar_foot(origin, g)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The rail: three tabs as glyphs, the live one lit and carrying a brass edge. The digit that selects it
## rides under each glyph, because a key legend nobody can find is a key nobody presses.
func _draw_bazaar_rail(origin: Vector2, g: Dictionary) -> void:
	var rail := Rect2(origin, Vector2(BAZAAR_RAIL, float(g["h"])))
	_round_rect_left(rail, 8.0, Color(0.043, 0.049, 0.070, 0.92))
	for i: int in 3:
		var y: float = rail.position.y + 62.0 + float(i) * 58.0
		var on: bool = i == bazaar_tab
		var box := Rect2(rail.position.x + 9.0, y, 38.0, 38.0)
		if on:
			_round_rect(box, 6.0, Color(0.145, 0.129, 0.082))
			draw_rect(Rect2(rail.position.x, y + 5.0, 2.5, 28.0), UI_ACCENT)
		_rail_glyph(box.get_center(), i, on)
		var label: String = TAB_NAMES[i]
		var lw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		draw_string(_font, Vector2(box.get_center().x - lw * 0.5, y + 48.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UI_TEXT if on else Color(0.36, 0.39, 0.45))
		draw_string(_font, Vector2(box.position.x + 1.0, y + 10.0), str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.34, 0.30, 0.22) if on else Color(0.24, 0.26, 0.31))


## The three tab glyphs, drawn rather than lettered: a satchel, a gear, a ladder of rungs.
func _rail_glyph(at: Vector2, kind: int, on: bool) -> void:
	var col: Color = Color(0.949, 0.831, 0.549) if on else Color(0.40, 0.43, 0.50)
	match kind:
		TAB_PACK:
			draw_rect(Rect2(at + Vector2(-8.0, -3.0), Vector2(16.0, 11.0)), col)
			draw_arc(at + Vector2(0.0, -3.0), 5.5, PI, TAU, 10, col, 1.8)
		TAB_WORKS:
			draw_arc(at, 6.5, 0.0, TAU, 20, col, 2.2)
			for i: int in 6:
				var a: float = TAU * float(i) / 6.0
				draw_line(at + Vector2(cos(a), sin(a)) * 6.5, at + Vector2(cos(a), sin(a)) * 9.5, col, 1.8)
		_:
			for i: int in 3:
				draw_rect(Rect2(at.x - 8.0 + float(i) * 2.0, at.y + 5.0 - float(i) * 6.0,
					16.0 - float(i) * 4.0, 2.6), col)


## The head: who you are talking to, which counter you are at, and — the thing the old footer buried in a
## run-on sentence — what you are carrying, as chips you can count without reading.
func _draw_bazaar_head(origin: Vector2, g: Dictionary) -> void:
	var x: float = origin.x + BAZAAR_RAIL + BAZAAR_PAD
	_tracked("BAZAAR", Vector2(x, origin.y + 29.0), 17, 2.8, UI_TEXT)
	_tracked(TAB_NAMES[bazaar_tab], Vector2(x + _tracked_w("BAZAAR", 17, 2.8) + 16.0, origin.y + 29.0),
		17, 2.8, Color(0.26, 0.28, 0.34))
	var rx: float = origin.x + float(g["w"]) - BAZAAR_PAD
	for item: StringName in [&"wood", &"stone", &"coal", &"ore", &"iron_ingot", &"ingot"]:
		var n: int = int(sim.inventory.get(item, 0))
		if n <= 0:
			continue
		var label: String = str(n)
		var cw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 25.0
		rx -= cw + 5.0
		if rx < x + 170.0:
			break
		_round_rect(Rect2(rx, origin.y + 6.0, cw, 20.0), 4.0, Color(1.0, 1.0, 1.0, 0.045))
		Visuals.draw_item(self, Vector2(rx + 11.0, origin.y + 16.0), 13.0, item)
		draw_string(_font, Vector2(rx + 19.0, origin.y + 20.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT)


## The footer is now one line: the keys. What you are carrying moved to the head as chips, and where the
## verbs live moved onto the verb BUTTON, where it is answering the question you are actually asking.
func _draw_bazaar_foot(origin: Vector2, g: Dictionary) -> void:
	var keys: String = "arrows  pick      1 2 3  tab      E  close"
	draw_string(_font, Vector2(origin.x + BAZAAR_RAIL + BAZAAR_PAD, origin.y + float(g["h"]) - 5.0), keys,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.34, 0.37, 0.43))


# --- the tabs -------------------------------------------------------------------------------------------

## PACK — the whole carried inventory as a grid of wells, given the whole width. It is the same pack it
## always was; it simply stopped sharing a 360px column with two other screens.
func _tab_pack(g: Dictionary) -> void:
	var content: Rect2 = g["content"]
	var slots: Array[Dictionary] = sim.inventory_slots()
	if slots.is_empty():
		draw_string(_font, content.position + Vector2(2.0, 20.0), "(empty — go dig)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT_DIM)
		return
	var cell: float = 46.0
	var cols: int = maxi(1, int(content.size.x / cell))
	var held: int = inv_selected_getter.call() if inv_selected_getter.is_valid() else -1
	for i: int in slots.size():
		var box := Rect2(content.position.x + float(i % cols) * cell, content.position.y + float(i / cols) * cell,
			cell - 6.0, cell - 6.0)
		if box.end.y > content.end.y:
			break
		var item: StringName = slots[i]["item"]
		var hot: bool = box.has_point(get_viewport().get_mouse_position())
		var picked: bool = i == bazaar_row
		if picked:
			_round_rect(box, 5.0, Color(0.176, 0.153, 0.098))
			draw_rect(Rect2(box.position + Vector2(0.0, 3.0), Vector2(2.0, box.size.y - 6.0)), UI_ACCENT)
		else:
			_round_rect(box, 5.0, Color(1.0, 1.0, 1.0, 0.062 if hot else 0.030))
		if hot:
			_tooltip_item = item
			_tooltip_count = int(slots[i]["count"])
			_tooltip_anchor = Vector2(box.get_center().x, box.position.y)
		_draw_thing_icon(item, Rect2(box.position + Vector2(8.0, 5.0),
			Vector2(box.size.x - 16.0, box.size.y - 17.0)))
		draw_string(_font, box.position + Vector2(box.size.x - 13.0, box.size.y - 4.0),
			str(int(slots[i]["count"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT)
		# The thing actually in your hand wears a mark, because "what am I holding" is the question the pack
		# screen is opened to answer and the hotbar is behind the panel while it is open.
		if i == held:
			draw_string(_font, box.position + Vector2(5.0, 12.0), "HELD",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.949, 0.831, 0.549))
	_pack_ledger(content, slots)


## Under the grid: what the factory is making for you, as bars. The pack tab had the most empty space of the
## three and the least reason for it — this is the one screen where "is the flywheel spinning" is worth
## asking, because you are standing still looking at what you own.
func _pack_ledger(content: Rect2, slots: Array[Dictionary]) -> void:
	var cell: float = 46.0
	var cols: int = maxi(1, int(content.size.x / cell))
	var top: float = content.position.y + float((slots.size() + cols - 1) / cols) * cell + 14.0
	if top > content.end.y - 30.0:
		return
	var rates: Array[Dictionary] = sim.production_rates()
	if rates.is_empty():
		return
	_tracked("YOUR LINE IS MAKING", Vector2(content.position.x + 1.0, top), 8, 2.0, Color(0.451, 0.365, 0.180))
	var fastest: float = 0.001
	for r: Dictionary in rates:
		fastest = maxf(fastest, float(r["rate"]))
	var bar_w: float = minf(240.0, content.size.x * 0.5)
	for i: int in mini(5, rates.size()):
		var y: float = top + 12.0 + float(i) * 17.0
		if y > content.end.y - 4.0:
			return
		var item: StringName = rates[i]["item"]
		var rate: float = float(rates[i]["rate"])
		Visuals.draw_item(self, Vector2(content.position.x + 8.0, y + 3.0), 13.0, item)
		draw_string(_font, Vector2(content.position.x + 18.0, y + 7.0), _item_label(item),
			HORIZONTAL_ALIGNMENT_LEFT, 80.0, 9, UI_TEXT)
		var bx: float = content.position.x + 104.0
		_round_rect(Rect2(bx, y - 3.0, bar_w, 10.0), 3.0, Color(1.0, 1.0, 1.0, 0.035))
		_round_rect(Rect2(bx, y - 3.0, maxf(3.0, bar_w * (rate / fastest)), 10.0), 3.0,
			Color(0.85, 0.72, 0.42, 0.62))
		draw_string(_font, Vector2(bx + bar_w + 8.0, y + 6.0), "%.1f/min" % rate,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.72, 0.42))


## WORKS — the counter (what you BUILD from your own materials) and the Rack (what you BUY with refined
## goods), as a dense card grid. No scrolling, no scrollbar, no shift-digit.
func _tab_works(g: Dictionary) -> void:
	var content: Rect2 = g["content"]
	var rows: int = int(g["rows"])
	var lay: Dictionary = works_columns(rows)
	# The columns SPREAD to fill the counter. Once WORKS lists only what you can build, most of the game is
	# two columns rather than three, and three columns' worth of narrow rows with an empty third is exactly
	# the dead space this rebuild exists to kill. Capped, because a row wide enough to lose its price at the
	# far end is its own problem.
	var used: int = maxi(1, int(lay["total"]))
	var col_w: float = minf(268.0,
		(content.size.x - BAZAAR_GUTTER * float(used - 1)) / float(used))
	var open_m: Array[int] = open_machines()
	var open_r: Array[int] = open_rack()
	_works_group(content, 0, int(lay["machines"]), col_w, rows, "MACHINES", craft_options, open_m, 0, true)
	_works_group(content, int(lay["machines"]), int(lay["rack"]), col_w, rows, "THE RACK",
		rack_options, open_r, open_m.size(), false)
	# ...and one quiet line saying the rest exists and where it lives. Hiding the locked half is only honest
	# if the panel still tells you there IS a locked half — otherwise the counter looks finished at four
	# machines and the tech ladder looks optional.
	var hidden: int = (craft_options.size() - open_m.size()) + (rack_options.size() - open_r.size())
	if hidden > 0:
		var line: String = "%d more wait behind research — press 3 for the BENCH" % hidden
		draw_string(_font, Vector2(content.position.x + 1.0, content.end.y - 2.0), line,
			HORIZONTAL_ALIGNMENT_LEFT, content.size.x, 9, Color(0.451, 0.402, 0.280))


## One GROUP — a list poured down as many columns as it needs, left to right. `base` is where the group
## starts in the panel's flat cursor index, so the highlight and `bazaar_action()` cannot disagree.
func _works_group(content: Rect2, col0: int, cols: int, col_w: float, rows: int, title: String,
		opts: Array[Dictionary], open_rows: Array[int], base: int, machines: bool) -> void:
	var x0: float = content.position.x + float(col0) * (col_w + BAZAAR_GUTTER)
	_tracked(title, Vector2(x0 + 1.0, content.position.y - 6.0), 8, 2.0, Color(0.451, 0.365, 0.180))
	if open_rows.is_empty():
		draw_string(_font, Vector2(x0 + 1.0, content.position.y + 16.0), "(nothing unlocked yet)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_DIM)
		return
	# A group longer than its columns shows a WINDOW around the cursor rather than truncating — the safety
	# valve, not the plan. It only moves when the cursor leaves it, so the rows never slide about.
	var capacity: int = rows * cols
	var first: int = 0
	if open_rows.size() > capacity:
		first = clampi(bazaar_row - base - capacity / 2, 0, open_rows.size() - capacity)
	for i: int in mini(capacity, open_rows.size()):
		var oi: int = open_rows[first + i]
		var rr := Rect2(x0 + float(i / rows) * (col_w + BAZAAR_GUTTER),
			content.position.y + float(i % rows) * BAZAAR_ROW_H, col_w, BAZAAR_ROW_H - 3.0)
		_works_row(rr, opts[oi], _works_id(machines, oi), base + first + i == bazaar_row)


func _works_id(machines: bool, i: int) -> StringName:
	if machines:
		return _craft_id(i)
	return rack_ids[i] if i < rack_ids.size() else &""


## One row. A CARD, not an outlined box: a surface tint you can see through to the panel, a well for the
## glyph, and — when it is the one the cursor is on — a brass edge and a warmer fill. Nothing is outlined,
## because an outline around every row makes every row shout and the selected one shout no louder.
func _works_row(rr: Rect2, opt: Dictionary, id: StringName, selected: bool) -> void:
	var afford: bool = _can_afford(opt["cost"])
	if selected:
		_round_rect(rr, 4.0, Color(0.176, 0.153, 0.098))
		draw_rect(Rect2(rr.position + Vector2(0.0, 2.0), Vector2(2.0, rr.size.y - 4.0)), UI_ACCENT)
	else:
		_round_rect(rr, 4.0, Color(1.0, 1.0, 1.0, 0.030))
	_draw_thing_icon(id, Rect2(rr.position + Vector2(6.0, 2.5), Vector2(16.0, 16.0)))
	var name_col: Color = (Color(0.949, 0.831, 0.549) if selected else UI_TEXT) if afford \
		else Color(0.48, 0.50, 0.56)
	var cw: float = _cost_glyphs(rr, opt["cost"])
	draw_string(_font, rr.position + Vector2(26.0, 14.0), str(opt["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 36.0 - cw, 10, name_col)


## The price as GLYPHS, not as prose. "6 Iron Ingot 3 Wood" is a hundred pixels of a hundred-and-seventy
## pixel row, and it was clipping the NAME off the thing you were buying — "Iron Pickax", "Blast Furnac".
## The same fact as two icons and two numbers is forty, and it reads faster besides: you are matching a
## picture against the chips in the head rather than parsing a sentence. Green when the pack covers it, red
## when it does not, per ingredient, so a short list says WHICH thing is short.
func _cost_glyphs(rr: Rect2, cost: Dictionary) -> float:
	var w: float = 0.0
	for item: StringName in cost:
		w += 12.0 + _font.get_string_size(str(int(cost[item])), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 7.0
	var x: float = rr.end.x - 5.0 - w
	for item: StringName in cost:
		var n: int = int(cost[item])
		Visuals.draw_item(self, Vector2(x + 6.0, rr.position.y + 10.5), 12.0, item)
		var label: String = str(n)
		draw_string(_font, Vector2(x + 13.0, rr.position.y + 14.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.482, 0.796, 0.518) if int(sim.inventory.get(item, 0)) >= n else Color(0.804, 0.427, 0.376))
		x += 12.0 + _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 7.0
	return w


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


# --- the detail plate -----------------------------------------------------------------------------------

## THE DETAIL PLATE. The selected thing, drawn large under a lamp, with one sentence of what it is for, its
## price as have/need chips, and the verb as a real button carrying the key that runs it.
##
## This is where the panel stops being a list and starts being a shop. It also puts the three answers a
## player is actually after — what is this, can I afford it, what do I press — in one place, at one glance,
## instead of spread across a row, a footer and a manual.
func _draw_bazaar_detail(g: Dictionary) -> void:
	var box: Rect2 = g["detail"]
	_round_rect(box, 6.0, Color(1.0, 1.0, 1.0, 0.028))
	var art := Rect2(box.position + Vector2(10.0, 10.0), Vector2(68.0, 68.0))
	var act: Dictionary = bazaar_action()
	var kind: String = str(act.get("kind", ""))
	if kind == "":
		_detail_pack(box, art)
		return
	var id: StringName = act["id"]
	if kind == "hold":
		_detail_hold(box, art, id, int(act.get("row", 0)))
		return
	var title: String = ""
	var blurb: String = ""
	var cost: Dictionary = {}
	var verb: String = ""
	var ready: bool = false
	var note: String = ""
	if kind == "tech":
		var t: Dictionary = ResearchRules.tech(id)
		title = str(t["name"])
		cost = t["cost"]
		var sample: StringName = t.get("sample", &"")
		# What it BUYS you, by name. A ladder that only prices its rungs is asking you to buy a number; the
		# reason to climb is the machines waiting at the top of it, and now that WORKS lists only what you
		# can already build, this plate is the only place those machines are named at all.
		var names: PackedStringArray = []
		for uid: StringName in (t.get("unlocks", []) as Array):
			names.append(_thing_label(uid))
		if not names.is_empty():
			blurb = "unlocks " + " · ".join(names)
		elif sample != &"":
			blurb = "analyze a sample of %s, then pour in the metal" % _item_label(sample)
		else:
			blurb = "a rung of the ladder — spend the metal, keep the knowledge"
		if sample != &"" and not names.is_empty():
			blurb += "\nanalyze a sample of %s, then pour in the metal" % _item_label(sample)
		var next: StringName = ResearchRules.next_tech(sim.research)
		if sim.is_researched(id):
			verb = "RESEARCHED"
			note = "already yours"
		elif id != next:
			verb = "LOCKED"
			var req: StringName = t.get("requires", &"")
			note = "behind %s" % (str(ResearchRules.tech(req)["name"]) if req != &"" else "an earlier rung")
		else:
			verb = "RESEARCH"
			ready = can_craft and _can_afford(cost) \
				and (sample == &"" or int(sim.inventory.get(sample, 0)) >= 1)
			note = "" if can_craft else "at a claimed Bazaar"
	else:
		var opts: Array[Dictionary] = craft_options if kind == "machine" else rack_options
		var row: int = int(act.get("row", 0))
		if row < 0 or row >= opts.size():
			return
		title = str(opts[row]["name"])
		cost = opts[row]["cost"]
		blurb = str(ITEM_PURPOSE.get(id, "—"))
		var lock: StringName = ResearchRules.locking_tech(id)
		if lock != &"" and not sim.is_researched(lock):
			verb = "LOCKED"
			note = "research %s first" % str(ResearchRules.tech(lock)["name"])
		else:
			verb = "BUILD" if kind == "machine" else "BUY"
			ready = can_craft and _can_afford(cost)
			note = "" if can_craft else "at a claimed Bazaar"

	# The lamp. Three rings behind the goods is the whole trick, and it is what makes a 44px glyph read as
	# lit rather than as big.
	for k: int in 3:
		draw_circle(art.get_center(), 34.0 - float(k) * 8.0, Color(0.85, 0.70, 0.35, 0.045))
	_round_rect(art, 5.0, Color(0.0, 0.0, 0.0, 0.26))
	if kind == "tech":
		_draw_tech_art(id, art)
	else:
		_draw_thing_icon(id, Rect2(art.get_center() - Vector2(22.0, 22.0), Vector2(44.0, 44.0)))

	var tx: float = art.end.x + 14.0
	var btn_w: float = 104.0
	var text_w: float = box.end.x - tx - btn_w - 24.0
	_tracked(title.to_upper(), Vector2(tx, box.position.y + 24.0), 13, 1.8, Color(0.949, 0.831, 0.549))
	draw_multiline_string(_font, Vector2(tx, box.position.y + 40.0), blurb, HORIZONTAL_ALIGNMENT_LEFT,
		text_w, 9, 2, UI_TEXT_DIM)
	# The price as have/need chips: "can I afford this" answered in the same glance as "what does it cost".
	var cx: float = tx
	for item: StringName in cost:
		var need: int = int(cost[item])
		var have: int = int(sim.inventory.get(item, 0))
		cx = _detail_chip(Vector2(cx, box.position.y + 62.0), item, need, have) + 6.0

	var btn := Rect2(box.end.x - btn_w - 10.0, box.position.y + box.size.y - 34.0, btn_w, 24.0)
	if ready:
		_round_rect(btn, 5.0, UI_ACCENT)
		var vw: float = _tracked_w(verb, 10, 2.0)
		_tracked(verb, Vector2(btn.position.x + 12.0, btn.position.y + 16.0), 10, 2.0, Color(0.08, 0.07, 0.04))
		draw_string(_font, Vector2(btn.position.x + 16.0 + vw, btn.position.y + 16.0), "ENTER",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.08, 0.07, 0.04, 0.62))
	else:
		_round_rect(btn, 5.0, Color(1.0, 1.0, 1.0, 0.05))
		_tracked(verb, Vector2(btn.position.x + 12.0, btn.position.y + 16.0), 10, 2.0, Color(0.44, 0.46, 0.52))
	if note != "":
		var nw: float = _font.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(_font, Vector2(btn.get_center().x - nw * 0.5, btn.position.y - 6.0), note,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.58, 0.48, 0.32))


## A machine's display name if it is one, an item's label otherwise. The tech ladder names both.
func _thing_label(id: StringName) -> String:
	if machine_icons.has(id):
		return str(machine_icons[id]["name"])
	return _item_label(id)


## A tech has no glyph of its own — it is knowledge — so its plate shows WHAT IT BUYS: the machines it
## unlocks, laid out big. That is also the honest answer to "why would I research this", which a lamp icon
## would not have been.
func _draw_tech_art(tid: StringName, art: Rect2) -> void:
	var unlocks: Array = ResearchRules.tech(tid).get("unlocks", [])
	if unlocks.is_empty():
		Visuals.draw_item(self, art.get_center(), 40.0, &"ingot")
		return
	var n: int = mini(4, unlocks.size())
	if n == 1:
		_draw_thing_icon(unlocks[0], Rect2(art.get_center() - Vector2(21.0, 21.0), Vector2(42.0, 42.0)))
		return
	var cell: float = 25.0
	var cols: int = 2
	var span := Vector2(float(cols) * cell, float((n + cols - 1) / cols) * cell)
	var at: Vector2 = art.get_center() - span * 0.5
	for i: int in n:
		_draw_thing_icon(unlocks[i], Rect2(at + Vector2(float(i % cols) * cell + 2.0,
			float(i / cols) * cell + 2.0), Vector2(cell - 4.0, cell - 4.0)))


## The plate for a thing you are CARRYING: what it is for, how many you have, and the one verb the pack
## screen has — put it in your hand.
func _detail_hold(box: Rect2, art: Rect2, id: StringName, row: int) -> void:
	for k: int in 3:
		draw_circle(art.get_center(), 34.0 - float(k) * 8.0, Color(0.85, 0.70, 0.35, 0.045))
	_round_rect(art, 5.0, Color(0.0, 0.0, 0.0, 0.26))
	_draw_thing_icon(id, Rect2(art.get_center() - Vector2(22.0, 22.0), Vector2(44.0, 44.0)))
	var tx: float = art.end.x + 14.0
	_tracked(_item_label(id).to_upper(), Vector2(tx, box.position.y + 24.0), 13, 1.8,
		Color(0.949, 0.831, 0.549))
	draw_multiline_string(_font, Vector2(tx, box.position.y + 40.0), str(ITEM_PURPOSE.get(id, "—")),
		HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 260.0, 9, 2, UI_TEXT_DIM)
	var carried: int = int(sim.inventory.get(id, 0))
	var made: int = int(sim.total_produced.get(id, 0))
	draw_string(_font, Vector2(tx, box.position.y + 76.0),
		"carrying %d   ·   %d gathered all told" % [carried, made],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.36, 0.39, 0.45))
	var held: int = inv_selected_getter.call() if inv_selected_getter.is_valid() else -1
	var btn := Rect2(box.end.x - 114.0, box.position.y + box.size.y - 34.0, 104.0, 24.0)
	if row == held:
		_round_rect(btn, 5.0, Color(1.0, 1.0, 1.0, 0.05))
		_tracked("IN HAND", Vector2(btn.position.x + 12.0, btn.position.y + 16.0), 10, 2.0,
			Color(0.44, 0.46, 0.52))
	else:
		_round_rect(btn, 5.0, UI_ACCENT)
		_tracked("HOLD", Vector2(btn.position.x + 12.0, btn.position.y + 16.0), 10, 2.0, Color(0.08, 0.07, 0.04))
		draw_string(_font, Vector2(btn.position.x + 58.0, btn.position.y + 16.0), "ENTER",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.08, 0.07, 0.04, 0.62))


## PACK has nothing to buy, so its plate answers the other question a pack screen is asked: what is the
## factory actually making for you while you stand here.
func _detail_pack(box: Rect2, art: Rect2) -> void:
	for k: int in 3:
		draw_circle(art.get_center(), 34.0 - float(k) * 8.0, Color(0.85, 0.70, 0.35, 0.035))
	_round_rect(art, 5.0, Color(0.0, 0.0, 0.0, 0.26))
	Visuals.draw_item(self, art.get_center(), 40.0, &"ingot")
	var tx: float = art.end.x + 14.0
	_tracked("THE PACK", Vector2(tx, box.position.y + 24.0), 13, 1.8, Color(0.949, 0.831, 0.549))
	var rates: Array[Dictionary] = sim.production_rates()
	if rates.is_empty():
		draw_string(_font, Vector2(tx, box.position.y + 42.0),
			"nothing is running — build a Forge at the WORKS tab and feed it ore",
			HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 120.0, 9, UI_TEXT_DIM)
		return
	draw_string(_font, Vector2(tx, box.position.y + 42.0), "your line is making",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_DIM)
	var cx: float = tx
	for i: int in mini(5, rates.size()):
		var item: StringName = rates[i]["item"]
		var label: String = "%.1f/min" % float(rates[i]["rate"])
		var cw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 25.0
		if cx + cw > box.end.x - 12.0:
			break
		_round_rect(Rect2(cx, box.position.y + 50.0, cw, 20.0), 4.0, Color(1.0, 1.0, 1.0, 0.045))
		Visuals.draw_item(self, Vector2(cx + 11.0, box.position.y + 60.0), 13.0, item)
		draw_string(_font, Vector2(cx + 19.0, box.position.y + 64.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.72, 0.42))
		cx += cw + 6.0


## One have/need chip. Green when the pack covers it, red when it does not — the affordability answer given
## per ingredient rather than as one verdict, so a short shopping list says WHICH thing is short.
func _detail_chip(at: Vector2, item: StringName, need: int, have: int) -> float:
	var label: String = "%d/%d" % [need, have]
	var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 26.0
	_round_rect(Rect2(at, Vector2(w, 19.0)), 4.0, Color(1.0, 1.0, 1.0, 0.05))
	Visuals.draw_item(self, at + Vector2(11.0, 9.5), 13.0, item)
	var ok: bool = have >= need
	draw_string(_font, at + Vector2(19.0, 13.5), str(need), HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(0.482, 0.796, 0.518) if ok else Color(0.804, 0.427, 0.376))
	var nw: float = _font.get_string_size(str(need), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(_font, at + Vector2(19.0 + nw, 13.5), "/%d" % have, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(0.36, 0.39, 0.45))
	return at.x + w


# --- the bench ------------------------------------------------------------------------------------------

## BENCH — the research ladder as a graph, AND the verb that acts on it, on one screen.
##
## This is the fix for the worst of the six: the tree used to be a separate full-screen overlay on `T` that
## showed you the ladder you could not act on, because the research verb lived back inside the pack screen.
## You read here and acted there. Now the ladder is a tab of the same counter, a cursor walks it, and the
## SELECTED rung is the one the detail plate prices and the one Enter takes.
##
## Tiers derive from each tech's `requires` chain, so a branching tree simply stacks its chips in a column
## and no layout changes. The chips are SCALED to the panel rather than the panel to the chips: the ladder
## grows, the counter does not.
func _tab_bench(g: Dictionary) -> void:
	var content: Rect2 = g["content"]
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
	var chip := Vector2(
		minf(108.0, (content.size.x - float(tiers.size() - 1) * gap.x) / float(tiers.size())),
		minf(64.0, (content.size.y - float(tallest - 1) * gap.y) / float(tallest)))
	var span := Vector2(float(tiers.size()) * chip.x + float(tiers.size() - 1) * gap.x,
		float(tallest) * chip.y + float(tallest - 1) * gap.y)
	var at := Vector2(content.position.x + (content.size.x - span.x) * 0.5,
		content.position.y + (content.size.y - span.y) * 0.5)
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
		var lc: Color = Color(0.48, 0.72, 0.52, 0.85) if sim.is_researched(req) \
			else Color(0.26, 0.29, 0.36, 0.85)
		draw_line(p0, p1, lc, 1.5)
		draw_colored_polygon(PackedVector2Array([p1, p1 + Vector2(-5.0, -3.5), p1 + Vector2(-5.0, 3.5)]), lc)
	var next: StringName = ResearchRules.next_tech(sim.research)
	var picked: StringName = &""
	var act: Dictionary = bazaar_action()
	if act.get("kind", "") == "tech":
		picked = act["id"]
	for tid: StringName in ResearchRules.ORDER:
		_draw_tech_chip(tid, rects[tid], tid == next, tid == picked)


## One tech chip: a lamp, a name, and the machines it unlocks. Its PRICE moved to the detail plate — a chip
## that carried the price had to shrink the name to fit it, and a truncated name ("Prospecti") costs the
## player more than a second glance downward does.
func _draw_tech_chip(tid: StringName, rr: Rect2, is_next: bool, picked: bool = false) -> void:
	var t: Dictionary = ResearchRules.tech(tid)
	var done: bool = sim.is_researched(tid)
	if picked:
		_round_rect(rr, 5.0, Color(0.176, 0.153, 0.098))
		draw_rect(Rect2(rr.position + Vector2(0.0, 3.0), Vector2(2.0, rr.size.y - 6.0)), UI_ACCENT)
	elif done:
		_round_rect(rr, 5.0, Color(0.078, 0.113, 0.086))
	else:
		_round_rect(rr, 5.0, Color(1.0, 1.0, 1.0, 0.040 if is_next else 0.022))
	var name_col: Color = Color(0.48, 0.70, 0.52) if done \
		else ((Color(0.949, 0.831, 0.549) if picked else UI_TEXT) if is_next else Color(0.40, 0.42, 0.48))
	var narrow: bool = rr.size.x < 96.0
	var indent: float = 15.0 if narrow else 19.0
	# The largest size the NAME actually fits at, rather than a size picked from the chip's width. A chip
	# guessed from its own geometry printed "Prospectin" and "Enrichmen" — a truncated name costs the player
	# more than a point of type does, and only the string knows how wide it is.
	var room: float = rr.size.x - indent - 5.0
	var fs: int = 9 if narrow else 11
	while fs > 7 and _font.get_string_size(str(t["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	draw_circle(rr.position + Vector2(8.0 if narrow else 11.0, 13.0), 3.2,
		Color(0.38, 0.78, 0.44) if done else (UI_ACCENT if is_next else Color(0.22, 0.24, 0.30)))
	draw_string(_font, rr.position + Vector2(indent, 16.0), str(t["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, room, fs, name_col)
	# What it buys: the unlocked machines' faces, dimmed until the tech is live.
	var ux: float = rr.position.x + 7.0
	for uid: StringName in (t.get("unlocks", []) as Array):
		var box := Rect2(ux, rr.position.y + 26.0, 17.0, 17.0)
		if box.end.x > rr.end.x - 3.0 or box.end.y > rr.end.y - 3.0:
			break                                          # a narrow chip shows what it can, never overflows
		_draw_thing_icon(uid, box)
		if not done:
			draw_rect(box, Color(0.0, 0.0, 0.0, 0.22 if is_next else 0.45))
		ux += 20.0


# --- the counter's surface primitives --------------------------------------------------------------------

## A REAL rounded rect. Composing one from a rect plus four circles double-blends every corner the moment
## the fill is translucent, which is exactly what a modern surface tint is.
func _round_rect(rect: Rect2, r: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r))
	sb.corner_detail = 8
	sb.draw(get_canvas_item(), rect)


## Rounded on the left two corners only — for the rail, flush against the panel's edge.
func _round_rect_left(rect: Rect2, r: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(0)
	sb.corner_radius_top_left = int(r)
	sb.corner_radius_bottom_left = int(r)
	sb.corner_detail = 8
	sb.draw(get_canvas_item(), rect)


## Elevation instead of a border. A modern panel does not outline itself; it casts. Concentric translucent
## rings are the cheap honest version of that, and they are what stop the counter reading as printed on the
## world behind it.
func _soft_shadow(rect: Rect2, spread: int, peak: float) -> void:
	for i: int in range(spread, 0, -1):
		var t: float = float(i) / float(spread)
		draw_rect(rect.grow(float(i)), Color(0.0, 0.0, 0.0, peak * (1.0 - t) * 0.32))


## One hairline of light along the top edge and a slow warm gradient down the plate — the two marks that say
## which way the lamp is, which is the difference between a surface and a fill.
func _panel_sheen(rect: Rect2) -> void:
	for i: int in 10:
		var t: float = float(i) / 9.0
		draw_rect(Rect2(rect.position.x + 2.0, rect.position.y + 2.0 + t * 46.0, rect.size.x - 4.0, 5.0),
			Color(1.0, 0.94, 0.82, 0.020 * (1.0 - t)))
	draw_rect(Rect2(rect.position.x + 8.0, rect.position.y, rect.size.x - 16.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.075))


## Letter-spaced type. Small caps with air between them is most of what separates a title from a label.
func _tracked(text: String, at: Vector2, size: int, track: float, col: Color) -> void:
	var x: float = at.x
	for i: int in text.length():
		var ch: String = text[i]
		draw_string(_font, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + track


## What `_tracked` actually occupies — the plain width plus one gap per letter. Measuring tracked type with
## `get_string_size` is how a caption ends up printed through its own title.
func _tracked_w(text: String, size: int, track: float) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x \
		+ track * float(maxi(text.length() - 1, 0))


## Darkens the frame's edges so the eye is pushed to the counter. Every modern pause screen does it; this
## one did not, which was part of why the panel read as pasted onto a screenshot.
func _bazaar_vignette(peak: float) -> void:
	if peak <= 0.001:
		return
	for i: int in 18:
		var t: float = float(i) / 18.0
		var inset: float = t * 130.0
		draw_rect(Rect2(0.0, 0.0, CANVAS.x, 1.0 + inset * 0.5), Color(0.0, 0.0, 0.0, peak * 0.030))
		draw_rect(Rect2(0.0, CANVAS.y - 1.0 - inset * 0.5, CANVAS.x, 1.0 + inset * 0.5),
			Color(0.0, 0.0, 0.0, peak * 0.030))
		draw_rect(Rect2(0.0, 0.0, 1.0 + inset, CANVAS.y), Color(0.0, 0.0, 0.0, peak * 0.024))
		draw_rect(Rect2(CANVAS.x - 1.0 - inset, 0.0, 1.0 + inset, CANVAS.y),
			Color(0.0, 0.0, 0.0, peak * 0.024))


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
## The CONTROLS card, hoisted out of _draw_help_overlay so check_hud_layout can MEASURE it. Text is the
## half a panel-rect test cannot see: every one of these is drawn inside a fixed-width column, and a line
## wider than its column spills across the card or off it entirely while the panel it overflows still
## reports a perfectly legal rectangle.
## Column width for the CONTROLS card, and the number check_hud_layout holds every line to.
const HELP_COL_W: float = 236.0
## Text size the card is drawn at — named so the measuring layer cannot drift from the drawing code.
const HELP_TEXT_SIZE: int = 11

const HELP_LINES: Array[String] = [
	"move        A / D  (or ← →)",
	"jump        W  or  SPACE",
	"climb       W / S  on a rope (not a jump)",
	"grapple     F  at ringed rock · again to ride",
	"swing       W / S reel in / out · SPACE off",
	# The three techniques the winch grew. Each is taught in place by a hint the first time you are in
	# the situation (scenes/hints.gd), but a lesson you can only be told once is a lesson you can miss,
	# so the card carries them too — same key-first voice as every line above it.
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


func _draw_help_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.0, 0.0, 0.0, 0.45))
	# TWO COLUMNS, BECAUSE ONE DID NOT FIT ON THE SCREEN. At 16px a row this list is 25 rows and 440px
	# tall on a 360px canvas, centred — so it hung 40px off the top AND 40px off the bottom, and the first
	# and last controls were simply not on screen. It rendered cleanly and looked deliberate, which is why
	# nothing caught it until check_hud_layout measured the box instead of looking at it.
	#
	# Splitting rather than shrinking is the right repair twice over: a smaller font would have fitted the
	# same wall of 25 rows into the same screen, and a wall of rows is the thing this card should least be.
	var lines: Array[String] = HELP_LINES
	var half: int = int(ceil(float(lines.size()) * 0.5))
	var col_w: float = HELP_COL_W
	var w: float = col_w * 2.0 + 16.0
	var h: float = 30.0 + float(half) * 16.0 + 10.0
	var origin := Vector2((CANVAS.x - w) * 0.5, (CANVAS.y - h) * 0.5)
	_panel(Rect2(origin, Vector2(w, h)), true)
	draw_string(_font, origin + Vector2(14.0, 22.0), "CONTROLS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI_ACCENT)
	for i: int in lines.size():
		var col: int = i / half
		var row: int = i % half
		draw_string(_font, Vector2(origin.x + 16.0 + float(col) * col_w, origin.y + 38.0 + float(row) * 16.0),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, HELP_TEXT_SIZE, UI_TEXT)


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
	[Controls.MUTE, "mute sound"],
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
	# The mute sits ON the AUDIO header, above the levels it overrides, because that is what it does: one
	# switch over the whole block. It reads as its STATE ("MUTED" / "SOUND ON"), never as an instruction —
	# a chip that says the opposite of what is happening is the oldest bug in settings UI.
	_settings_chip(x0 + 92.0, 58.0, "MUTED" if Settings.muted else "SOUND ON",
		{"toggle": "mute"}, not Settings.muted, mouse)
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
	# Dimmed while muted: the levels are still yours and still remembered, but nothing they say is audible,
	# and a bright slider over a silent game is the page lying about which control is in charge.
	draw_string(_font, Vector2(x0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		UI_TEXT_DIM if Settings.muted else UI_TEXT)
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
##
## IT RETIRES ITSELF, ONE KEY AT A TIME, AND THAT IS THE POINT. The subjective audit's charge against this
## line was not that it is ugly — it is 10px and dim — but that it is PERMANENT: "the persistent bottom-left
## key legend reads like test-build chrome", listed on the kill list under "teach contextually, then remove
## it". A reference card that never leaves is a statement that the game expects you never to learn it, and
## it sits in the corner of every screenshot the game will ever take.
##
## So each entry disappears the first time you press that key, and when the last one goes the line goes with
## it. A player who already knows the controls clears it in about four seconds and never sees it again; a
## player who does not gets exactly the entries they have not yet used, which is a smaller and more pointed
## hint every time they look. Nothing is hidden that has not been demonstrably learned.
##
## SESSION-SCOPED ON PURPOSE. This is not written to the save. `check_save_frontier` guards every field in
## the envelope and would rightly demand this one declare its disposition, and "which keys has this player
## pressed" is not world state — it is a teaching aid whose cost of being wrong is one dim line for four
## seconds. A returning player re-clears it. That is cheaper than owning a migration for it.
const HINT_KEYS: Array = [
	[Controls.GRAPPLE, "F hook"], [Controls.DROP, "Q drop"], [Controls.CRAFT, "E pack"],
	[Controls.MAP, "M map"], [Controls.HELP, "H keys"],
]

var _hint_used: Dictionary = {}          ## action -> true, once the player has pressed it this session


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
		return                            # everything here has been used — the line has finished its job
	draw_string(_font, Vector2(10.0, CANVAS.y - 8.0), "   ·   ".join(parts),
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
	# THE BIG MAP IS THE SCREEN — the same rule as the goal plate at :699, decided there for the same
	# reason. The map's panel runs y 41..319 of a 360 canvas and this bar's backing starts at y=295, and the
	# map draws SECOND (:270 after :263). So the bar was not overlapped, it was BURIED: rows 319..339 poked
	# out below the map's edge, which is exactly where each slot's count badge sits (:2330) — every count
	# legible, every icon it counts cut in half. That is worse than either showing the bar or hiding it.
	# Standing down rather than nudging the map, because :696 already rejected nudging in writing: the map
	# is the one screen that is purely for reading the world, and your pack is not what you are reading.
	# M puts it back. Held by `check_hud_layout:_check_big_map`.
	if minimap_large:
		return
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
