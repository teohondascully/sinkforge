class_name Hud
extends Node2D

## Screen-fixed HUD. Lives under a CanvasLayer so the follow-camera does NOT scroll it. Reads the sim
## only (OUTPUT total + the carried inventory) and shows the controls. Drawn in screen space.

const CANVAS := Vector2(640, 360)
const SLOT: float = 30.0        ## inventory hotbar slot size
const SLOT_GAP: float = 4.0
const MINI_W: float = 150.0     ## minimap width (top-right); height derives from the world aspect
const MINI_TOP: float = 34.0    ## minimap y (just under the FORGED counter)

## --- UI skin palette (one cohesive theme so the HUD reads as designed, not flat code-drawn) -------
const UI_BG := Color(0.07, 0.08, 0.115, 0.90)        ## panel fill
const UI_EDGE := Color(0.30, 0.34, 0.42)             ## panel border
const UI_EDGE_HI := Color(0.52, 0.58, 0.68, 0.45)    ## top bevel highlight → panels read as raised
const UI_ACCENT := Color(0.96, 0.82, 0.36)           ## gold accent (FORGED, selected slot, current step)
const UI_TEXT := Color(0.88, 0.90, 0.95)
const UI_TEXT_DIM := Color(0.58, 0.62, 0.70)
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
var inventory_open: bool = false   ## E — the PACK screen (full carried inventory + the craft panel)
var can_craft: bool = false        ## are we near a claimed Bazaar? gates the craft panel inside the pack screen
var show_minimap: bool = false
var minimap_large: bool = false    ## M cycles corner → LARGE (centred) → hidden (FABLE_50 #34)
## The player's PING marker in world coords (Vector2.INF = none) — set by clicking the open map;
## MainView owns it and pushes it here + to the renderer (which draws the in-world beacon).
var ping_world: Vector2 = Vector2.INF
var show_help: bool = false
var show_tech: bool = false        ## T — the TECH TREE graph (FABLE_50 #30)

## Transient toast ("SAVED" / "LOADED" / short notices) — set via flash(), fades out on its own.
var _flash_text: String = ""
var _flash_life: float = 0.0

## The just-in-time HINT BUBBLE (FABLE_50 #35, pushed by MainView from the Hints tracker): a small
## speech bubble anchored NEAR THE BODY teaching a newly-acquired item's use. Empty text = none.
var hint_text: String = ""
var hint_anchor: Vector2 = Vector2.ZERO   ## canvas-space point the tail points at (above the head)
var hint_alpha: float = 0.0

## ITEM TOOLTIPS (FABLE_50 #33): hover a hotbar/pack slot → what this item is FOR. One line per id —
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
	&"wood_axe": "fells trees — hold LMB on a trunk, the whole tree drops as wood",
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


func _process(delta: float) -> void:
	_flash_life = maxf(0.0, _flash_life - delta)
	queue_redraw()


func _draw() -> void:
	_tooltip_item = &""    # re-captured by whichever slot the cursor sits on this frame
	# --- always on (minimal): the anchor furniture only ---
	_draw_forged()         # top-right production chip (small)
	_draw_objective_line()  # top-centre, ONE current step — the signpost without the wall of text
	_draw_hover()          # inspector for the machine under the cursor (only when one is hovered)
	_draw_inventory()      # bottom-centre hotbar
	_draw_hint()           # tiny bottom-left "E craft · M map · H keys" — replaces the giant footer
	if not (inventory_open or show_tech or show_help):
		_draw_hint_bubble()  # just-in-time teaching near the body (hidden while a menu dims the world)
	# --- on demand (summoned, so they never clutter) ---
	if show_minimap:
		_draw_minimap()    # M — top-right world map
	if inventory_open:
		_draw_inventory_overlay()  # E — the PACK screen: full inventory + (at the Bazaar) the craft panel
	if show_tech:
		_draw_tech_overlay()      # T — the research ladder as a graph (the PULL's face)
	if show_help:
		_draw_help_overlay()      # H / ? — the full controls list
	if paused_getter.is_valid() and bool(paused_getter.call()):
		var p := Rect2(CANVAS.x * 0.5 - 52.0, 8.0, 104.0, 26.0)
		_panel(p, true)
		draw_string(_font, p.position + Vector2(20.0, 18.0), "PAUSED (P)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI_ACCENT)
	_draw_fastforward()    # top-left "▶▶ Nx" chip when the game clock is sped up
	_draw_flash()          # transient toast (save/load feedback)
	_draw_item_tooltip()   # hovered-slot tooltip — drawn last so it rides over every panel


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
## the item that just landed in the pack (FABLE_50 #35). Word-wrapped, gold-capped like every panel,
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


## Fast-forward chip (top-left): a small "▶▶ Nx" tag shown ONLY while the game clock is sped up, so the
## world visibly racing has an on-screen cause. Hidden at 1x to keep the default screen calm. Press "."
## to cycle. Uses the shared accented panel skin.
func _draw_fastforward() -> void:
	if time_scale <= 1.0:
		return
	var label: String = "▶▶ %dx" % int(time_scale)
	var tw: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var chip := Rect2(10.0, 8.0, tw + 24.0, 22.0)
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


## The OBJECTIVE line (top-centre) — ONE line: the current step only, as a gentle nudge, not a wall of
## text. A small gold dot + the step's how-to label. When the whole chain is done it shows a brief
## "all set" then auto-hides (the Guide stops nagging). Pure read of the Objectives tracker. Top-centre
## sits over open sky, so it never buries the avatar (who spawns top-left) the way the old panel did.
func _draw_objective_line() -> void:
	if objectives == null:
		return
	if objectives.all_done() and objectives.done_for() > 5.0:
		return  # finished + lingered → clear the screen for veterans
	var text: String
	var col: Color
	if objectives.all_done():
		text = "✓  All set — keep digging deeper."
		col = Color(0.62, 0.86, 0.58)
	else:
		var step: Dictionary = objectives.steps[objectives.current_index()]
		text = str(step["label"])
		col = Color(0.97, 0.93, 0.78)
	var fs: int = 13
	var tw: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pad: float = 12.0
	var w: float = tw + pad * 2.0 + 14.0
	var rect := Rect2((CANVAS.x - w) * 0.5, 8.0, w, 24.0)
	_panel(rect, true)
	var cy: float = rect.position.y + rect.size.y * 0.5
	if not objectives.all_done():
		draw_circle(Vector2(rect.position.x + pad + 1.0, cy), 3.0, UI_ACCENT)
	draw_string(_font, Vector2(rect.position.x + pad + 14.0, cy + 5.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


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
func _draw_hover() -> void:
	if hover_info.is_empty():
		return
	var ins: Array = hover_info.get("in", [])
	var outs: Array = hover_info.get("out", [])
	var holding: Array = hover_info.get("holding", [])
	var has_recipe: bool = not ins.is_empty() or not outs.is_empty()
	var has_mode: bool = hover_info.has("mode") and str(hover_info["mode"]) != ""
	var has_rate: bool = hover_info.has("rate")
	var width: float = 218.0
	var rows: int = 1 + int(has_recipe) + int(has_mode) + int(not holding.is_empty()) + int(has_rate)
	var pad: float = 9.0
	var line_h: float = 18.0
	# Sits below whatever occupies the top-right column: the CORNER minimap if it's shown (the large map
	# is centred, off this column), else just the FORGED chip — so the inspector never collides.
	var mini_bottom: float = (MINI_TOP + MINI_W * float(FactorySim.GRID_ROWS) / float(FactorySim.GRID_COLS)) \
		if (show_minimap and not minimap_large) else 34.0
	var origin := Vector2(CANVAS.x - width - 12.0, mini_bottom + 10.0)
	_panel(Rect2(origin, Vector2(width, 10.0 + float(rows) * line_h + 4.0)))
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
func minimap_frame() -> Rect2:
	var cols: float = float(FactorySim.GRID_COLS)
	var rows: float = float(FactorySim.GRID_ROWS)
	if minimap_large:
		var mh: float = 272.0
		var mw: float = mh * cols / rows
		return Rect2(Vector2((CANVAS.x - mw) * 0.5, (CANVAS.y - mh) * 0.5), Vector2(mw, mh))
	return Rect2(Vector2(CANVAS.x - MINI_W - 12.0, MINI_TOP), Vector2(MINI_W, MINI_W * rows / cols))


## The MINIMAP (M — corner; M again — LARGE): a cached image of the whole world — solid cells in their
## material colour, carved/dug cells as a dim wall backing, open sky as void — with the live overlays of
## Minimap 2.0 (FABLE_50 #34): DEPTH BANDS (the violet seal line + the cold Stonereach wash below it),
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
	if minimap_large:
		draw_string(_font, Vector2(origin.x + 5.0, seal_y - 4.0), "TOPSOIL",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.75, 0.72, 0.60, 0.75))
		draw_string(_font, Vector2(origin.x + 5.0, seal_y + seal_h + 10.0), "STONEREACH",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.65, 0.90, 0.75))
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


## The PACK SCREEN (E) — a centred panel, OFF the hotbar, dimming the world ("you're in a menu"). Top: the
## FULL carried inventory as a grid of icon+count chips (your whole pack, not just the hotbar row). Bottom:
## the CRAFT panel — but machine-crafting is the Bazaar's job, so the recipes show only when you're near a
## claimed Bazaar (can_craft); away from it, a hint sends you to find/claim one. E/Esc closes.
func _draw_inventory_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.0, 0.0, 0.0, 0.5))  # dim the world
	var slots: Array[Dictionary] = sim.inventory_slots()
	var cols: int = 6
	var cell: float = 34.0
	var grid_h: float = ceilf(maxf(1.0, float(slots.size())) / float(cols)) * cell + 6.0
	# Craftables draw TWO-UP (the list outgrew a 360px-tall canvas as machines accrued); research rows
	# stay full-width. Away from the Bazaar there's just the one hint line.
	var row_h: float = 24.0
	var craft_lines: int = int(ceilf(float(craft_options.size()) / 2.0)) if can_craft else 1
	var w: float = 360.0
	# The live production summary ("making ore 8.2/min · ingot 4.1/min") gets its own header line
	# when anything is flowing — the factory's pulse, read at a glance (sim.production_rates).
	var rates: Array[Dictionary] = sim.production_rates()
	var head: float = 30.0 + (15.0 if not rates.is_empty() else 0.0)
	var craft_head: float = 24.0
	# The RESEARCH BENCH section (only at the Bazaar): ONE summary row — the next tech + the [T] tree
	# pointer. The full ladder lives in the tech-tree overlay now (FABLE_50 #30), so the pack stays
	# this height no matter how many tiers the tree grows.
	var research_h: float = (craft_head + row_h) if can_craft else 0.0
	var h: float = head + grid_h + craft_head + float(craft_lines) * row_h + research_h + 12.0
	var origin := Vector2((CANVAS.x - w) * 0.5, (CANVAS.y - h) * 0.5)
	_panel(Rect2(origin, Vector2(w, h)), true)
	draw_string(_font, origin + Vector2(14.0, 23.0), "PACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI_ACCENT)
	draw_string(_font, origin + Vector2(w - 116.0, 22.0), "E / Esc to close",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)
	if not rates.is_empty():
		var parts: PackedStringArray = []
		for i: int in mini(3, rates.size()):     # top three — a pulse line, not a spreadsheet
			parts.append("%s %.1f/min" % [_item_label(rates[i]["item"]), float(rates[i]["rate"])])
		draw_string(_font, origin + Vector2(14.0, 38.0), "making  " + " · ".join(parts),
			HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, 10, Color(0.85, 0.72, 0.42))
	# --- the full pack as an icon grid ---
	var gx: float = origin.x + 10.0
	var gy: float = origin.y + head
	if slots.is_empty():
		draw_string(_font, Vector2(gx + 2.0, gy + 18.0), "(empty — go dig)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT_DIM)
	for i: int in slots.size():
		var ix: float = gx + float(i % cols) * cell
		var iy: float = gy + float(i / cols) * cell
		var box := Rect2(ix, iy, cell - 4.0, cell - 4.0)
		draw_rect(box, UI_SLOT)
		draw_rect(box, UI_EDGE, false, 1.0)
		var item: StringName = slots[i]["item"]
		if box.has_point(get_viewport().get_mouse_position()):   # hovered → tooltip (drawn last)
			draw_rect(box, UI_EDGE_HI, false, 1.0)
			_tooltip_item = item
			_tooltip_count = int(slots[i]["count"])
			_tooltip_anchor = Vector2(box.get_center().x, box.position.y)
		var icon := Rect2(box.position + Vector2(5.0, 4.0), Vector2(box.size.x - 10.0, box.size.y - 12.0))
		if machine_icons.has(item):
			var mspr: Texture2D = Art.tex("machine_" + String(item))
			if mspr != null:
				draw_texture_rect(mspr, icon, false)
			else:
				draw_rect(icon, machine_icons[item]["color"])
				Visuals.draw_machine_glyph(self, icon.position + icon.size * 0.5,
					str(machine_icons[item]["kind"]), icon.size.y / 20.0, false, 0.0)
		else:
			Visuals.draw_item(self, icon.position + icon.size * 0.5, icon.size.y, item)
		var cnt: String = str(int(slots[i]["count"]))
		draw_string(_font, box.position + Vector2(box.size.x - 11.0, box.size.y - 2.0), cnt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT)
	# --- the craft panel (gated on Bazaar proximity) ---
	var cy: float = origin.y + head + grid_h
	draw_line(Vector2(origin.x + 8.0, cy), Vector2(origin.x + w - 8.0, cy), UI_EDGE, 1.0)
	cy += 4.0
	if not can_craft:
		draw_string(_font, Vector2(origin.x + 14.0, cy + 19.0), "CRAFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI_TEXT_DIM)
		draw_string(_font, Vector2(origin.x + 70.0, cy + 19.0), "— claim & stand by the Bazaar",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT_DIM)
		return
	draw_string(_font, Vector2(origin.x + 14.0, cy + 19.0), "CRAFT  (at the Bazaar)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI_ACCENT)
	var y: float = cy + craft_head
	var half_w: float = (w - 16.0) * 0.5
	for i: int in craft_options.size():
		var opt: Dictionary = craft_options[i]
		var afford: bool = _can_afford(opt["cost"])
		var rr := Rect2(origin.x + 6.0 + float(i % 2) * (half_w + 4.0), y + float(i / 2) * row_h,
			half_w, row_h - 3.0)
		draw_rect(rr, UI_SLOT)
		draw_rect(rr, UI_EDGE, false, 1.0)
		var icon2 := Rect2(rr.position + Vector2(4.0, 3.0), Vector2(row_h - 9.0, row_h - 9.0))
		var id: StringName = _craft_id(i)
		if machine_icons.has(id):
			var spr: Texture2D = Art.tex("machine_" + String(id))
			if spr != null:
				draw_texture_rect(spr, icon2, false)
			else:
				draw_rect(icon2, machine_icons[id]["color"])
				Visuals.draw_machine_glyph(self, icon2.position + icon2.size * 0.5,
					str(machine_icons[id]["kind"]), icon2.size.y / 20.0, false, 0.0)
		elif id != &"":
			Visuals.draw_item(self, icon2.position + icon2.size * 0.5, icon2.size.y, id)  # a tool: its item glyph
		# A machine still locked behind unresearched tech: dim the row and say WHAT unlocks it (the PULL
		# made legible — you see the drill, you see the bench row that opens it).
		var lock: StringName = ResearchRules.locking_tech(id)
		var locked: bool = lock != &"" and not sim.is_researched(lock)
		var name_col: Color = Color(0.40, 0.42, 0.48) if locked else (UI_TEXT if afford else Color(0.45, 0.47, 0.53))
		var right: String = ("needs %s" % str(ResearchRules.tech(lock)["name"])) if locked else _cost_text(opt["cost"])
		var right_col: Color = Color(0.62, 0.50, 0.34) if locked \
			else (UI_ACCENT if afford else Color(0.45, 0.40, 0.30))
		if locked:
			draw_rect(rr, Color(0.0, 0.0, 0.0, 0.35))
		var cw: float = _font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		# Clip the name to the space LEFT of the right-hand price/lock text (long names would collide).
		var name_w: float = rr.size.x - (row_h - 1.0) - cw - 10.0
		# Keys 1-9 then 0 cover the first ten rows; rows 11+ craft on SHIFT+digit (until the real
		# tech-tree panel, FABLE_50 #30). The cap reads "s1" for shift-1.
		var keycap: String
		if i < 9:
			keycap = str(i + 1)
		elif i == 9:
			keycap = "0"
		else:
			keycap = "s%d" % (i - 9) if i < 19 else "s0"
		draw_string(_font, rr.position + Vector2(row_h - 1.0, 15.0),
			"[%s] %s" % [keycap, str(opt["name"])], HORIZONTAL_ALIGNMENT_LEFT, name_w, 11, name_col)
		draw_string(_font, rr.position + Vector2(rr.size.x - cw - 5.0, 15.0), right,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, right_col)
	y += float(int(ceilf(float(craft_options.size()) / 2.0))) * row_h
	_draw_research_bench(origin, w, y, row_h, craft_head)


## The RESEARCH BENCH summary (the Bazaar's other half — docs/PROGRESSION.md §5): ONE row for the NEXT
## researchable tech ([R] + its analyze-sample + price), or a done-line when the tree is exhausted. The
## full ladder is the TECH TREE overlay's job now ([T], FABLE_50 #30) — this row is the bench's handle
## on it, and the pack screen stops growing a row per tier.
func _draw_research_bench(origin: Vector2, w: float, y0: float, row_h: float, head_h: float) -> void:
	var y: float = y0 + 5.0
	draw_line(Vector2(origin.x + 8.0, y - 2.0), Vector2(origin.x + w - 8.0, y - 2.0), UI_EDGE, 1.0)
	draw_string(_font, Vector2(origin.x + 14.0, y + 14.0), "RESEARCH  (the bench)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI_ACCENT)
	var tree_hint: String = "[T] tech tree"
	var tw: float = _font.get_string_size(tree_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(_font, Vector2(origin.x + w - tw - 13.0, y + 14.0), tree_hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_TEXT_DIM)
	y += head_h - 5.0
	var next: StringName = ResearchRules.next_tech(sim.research)
	var rr := Rect2(origin.x + 6.0, y, w - 12.0, row_h - 3.0)
	draw_rect(rr, UI_SLOT)
	draw_rect(rr, UI_EDGE, false, 1.0)
	if next == &"":
		draw_circle(rr.position + Vector2(12.0, 10.5), 3.2, Color(0.38, 0.78, 0.44))
		draw_string(_font, rr.position + Vector2(21.0, 15.0), "every tech researched",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 0.62, 0.48))
		return
	var t: Dictionary = ResearchRules.tech(next)
	var sample: StringName = t.get("sample", &"")
	var afford: bool = _can_afford(t["cost"]) and (sample == &"" or int(sim.inventory.get(sample, 0)) >= 1)
	var price: String = ("analyze %s + " % _item_label(sample) if sample != &"" else "") + _cost_text(t["cost"])
	draw_string(_font, rr.position + Vector2(8.0, 15.0), "[R]  Research %s" % str(t["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI_TEXT if afford else Color(0.45, 0.47, 0.53))
	var pw: float = _font.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(_font, rr.position + Vector2(rr.size.x - pw - 5.0, 15.0), price,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI_ACCENT if afford else Color(0.45, 0.40, 0.30))


## THE TECH TREE (FABLE_50 #30, [T]): the research PULL's face — the ladder drawn as a GRAPH. Tiers
## derive from each tech's `requires` chain, so when the tree branches (a wide tier), its chips simply
## stack in their column — zero layout changes. Chip states: DONE (green lamp, settled), NEXT (gold
## edge + [R] + live afford-price), LOCKED (dimmed; the arrow already says what opens it). Each chip
## shows its analyze-sample, its price, and the machine glyphs it unlocks — what you're buying, visible
## before you can afford it. Viewable anywhere; the research VERB stays at the Bazaar bench.
func _draw_tech_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.0, 0.0, 0.0, 0.5))
	# --- tiers by prerequisite-chain depth ---
	var tiers: Array = []                                  # tier index -> Array[StringName]
	for tid: StringName in ResearchRules.ORDER:
		var d: int = 0
		var cur: StringName = ResearchRules.tech(tid).get("requires", &"")
		while cur != &"":
			d += 1
			cur = ResearchRules.tech(cur).get("requires", &"")
		while tiers.size() <= d:
			tiers.append([])
		(tiers[d] as Array).append(tid)
	# --- geometry ---
	var chip := Vector2(102.0, 74.0)
	var gap_x: float = 14.0
	var gap_y: float = 8.0
	var tallest: int = 1
	for tier: Array in tiers:
		tallest = maxi(tallest, tier.size())
	var body_w: float = float(tiers.size()) * chip.x + float(tiers.size() - 1) * gap_x
	var body_h: float = float(tallest) * chip.y + float(tallest - 1) * gap_y
	var w: float = body_w + 24.0
	var h: float = body_h + 58.0
	var origin := Vector2((CANVAS.x - w) * 0.5, (CANVAS.y - h) * 0.5)
	_panel(Rect2(origin, Vector2(w, h)), true)
	draw_string(_font, origin + Vector2(14.0, 22.0), "TECH TREE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI_ACCENT)
	draw_string(_font, origin + Vector2(w - 110.0, 21.0), "T / Esc to close",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UI_TEXT_DIM)
	var rects: Dictionary = {}                             # tech id -> chip Rect2
	for ti: int in tiers.size():
		var tier: Array = tiers[ti]
		var col_h: float = float(tier.size()) * chip.y + float(tier.size() - 1) * gap_y
		for ni: int in tier.size():
			rects[tier[ni]] = Rect2(origin + Vector2(12.0 + float(ti) * (chip.x + gap_x),
				30.0 + (body_h - col_h) * 0.5 + float(ni) * (chip.y + gap_y)), chip)
	# --- arrows first (under the chips): prereq's right edge -> dependent's left edge ---
	var next: StringName = ResearchRules.next_tech(sim.research)
	for tid: StringName in ResearchRules.ORDER:
		var req: StringName = ResearchRules.tech(tid).get("requires", &"")
		if req == &"" or not rects.has(req):
			continue
		var a: Rect2 = rects[req]
		var b: Rect2 = rects[tid]
		var p0 := Vector2(a.end.x, a.position.y + a.size.y * 0.5)
		var p1 := Vector2(b.position.x, b.position.y + b.size.y * 0.5)
		var lit: bool = sim.is_researched(req)             # the path you've already walked glows
		var lc: Color = Color(0.55, 0.75, 0.55, 0.8) if lit else Color(UI_EDGE.r, UI_EDGE.g, UI_EDGE.b, 0.8)
		draw_line(p0, p1, lc, 1.5)
		var tip := PackedVector2Array([p1, p1 + Vector2(-5.0, -3.5), p1 + Vector2(-5.0, 3.5)])
		draw_colored_polygon(tip, lc)
	# --- the chips ---
	for tid: StringName in ResearchRules.ORDER:
		_draw_tech_chip(tid, rects[tid], tid == next)
	# --- footer: where the verb lives ---
	var foot: String
	if next == &"":
		foot = "every tech researched — the tree is yours"
	elif can_craft:
		foot = "R  research %s" % str(ResearchRules.tech(next)["name"])
	else:
		foot = "research happens at the Bazaar bench — stand by it and press R"
	draw_string(_font, origin + Vector2(14.0, h - 10.0), foot, HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, 10,
		UI_ACCENT if (next != &"" and can_craft) else UI_TEXT_DIM)


## One tech chip: lamp + name / analyze-sample / price / the unlocked machines as mini-glyphs.
func _draw_tech_chip(tid: StringName, rr: Rect2, is_next: bool) -> void:
	var t: Dictionary = ResearchRules.tech(tid)
	var done: bool = sim.is_researched(tid)
	draw_rect(rr, UI_SLOT)
	if is_next:
		draw_rect(rr.grow(1.0), UI_ACCENT, false, 1.5)     # the lit rung — where R lands
	else:
		draw_rect(rr, UI_EDGE, false, 1.0)
	var name_col: Color = Color(0.45, 0.62, 0.48) if done else (UI_TEXT if is_next else Color(0.40, 0.42, 0.48))
	draw_circle(rr.position + Vector2(10.0, 11.0), 3.2,
		Color(0.38, 0.78, 0.44) if done else (UI_ACCENT if is_next else Color(0.22, 0.24, 0.30)))
	draw_string(_font, rr.position + Vector2(18.0, 15.0), str(t["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 24.0, 11, name_col)
	# The price: what you analyze + what you pour in. Dim on done (paid), gold-if-affordable on next.
	var sample: StringName = t.get("sample", &"")
	var afford: bool = _can_afford(t["cost"]) and (sample == &"" or int(sim.inventory.get(sample, 0)) >= 1)
	var line_col: Color = Color(0.42, 0.52, 0.45) if done \
		else ((UI_ACCENT if afford else Color(0.62, 0.52, 0.34)) if is_next else Color(0.40, 0.42, 0.48))
	if sample != &"":
		draw_string(_font, rr.position + Vector2(8.0, 30.0), "analyze %s" % _item_label(sample),
			HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 14.0, 8, line_col)
	draw_string(_font, rr.position + Vector2(8.0, 42.0), "+ " + _cost_text(t["cost"]),
		HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 14.0, 8, line_col)
	# What it buys: the unlocked machines' faces, dimmed until the tech is live.
	var ux: float = rr.position.x + 8.0
	for uid: StringName in (t.get("unlocks", []) as Array):
		var box := Rect2(ux, rr.position.y + 50.0, 16.0, 16.0)
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
		"jump        SPACE",
		"climb       W / S  on a rope (release = hang)",
		"mine        LMB (hold)",
		"dig plan    LMB drag paints it · X clears",
		"select      1–9  ·  mouse wheel",
		"place / pick  RMB  (machine, rope, or block)",
		"drop / feed  Q  (gravity feeds it in)",
		"pack        E  (inventory · craft at Bazaar)",
		"research    R  (in the pack screen, at the bench)",
		"tech tree   T",
		"configure   R  (aimed at a splitter / hopper)",
		"map         M  (again: LARGE · click it = ping)",
		"fast-fwd    .     (1x → 2x → 4x → 8x)",
		"save / load  F5 / F9",
		"pause       P     ·   help   H",
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


## A tiny dim hint, bottom-left — the toggle keys, so the player knows the menus exist without the old
## always-on keyboard-reference footer hogging the whole bottom edge.
func _draw_hint() -> void:
	draw_string(_font, Vector2(10.0, CANVAS.y - 8.0), "Q drop   ·   E pack   ·   M map   ·   H keys",
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


## The hovered slot's TOOLTIP (FABLE_50 #33): the item's name, the count you hold, and one purpose
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
