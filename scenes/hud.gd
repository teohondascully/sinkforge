class_name Hud
extends Node2D

## Screen-fixed HUD. Lives under a CanvasLayer so the follow-camera does NOT scroll it. Reads the sim
## only (OUTPUT total + the carried inventory) and shows the controls. Drawn in screen space.

const CANVAS := Vector2(640, 360)
const SLOT: float = 30.0        ## inventory hotbar slot size
const SLOT_GAP: float = 4.0
const MINI_W: float = 150.0     ## minimap width (top-right); height derives from the world aspect
const MINI_TOP: float = 34.0    ## minimap y (just under the FORGED counter)

var sim: FactorySim
var _font: Font = ThemeDB.fallback_font
var paused_getter: Callable
## The tutorial chain (representation-layer legibility — answers "how do I play?"). Set by MainView.
var objectives: Objectives
## Craftable machines for the CRAFT strip (set by MainView): [{name: String, cost: {item->count}}].
var craft_options: Array[Dictionary] = []
## Machine item id -> {color: Color, tag: String}, so machine items in the hotbar read as machines.
var machine_icons: Dictionary = {}
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


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# FORGED counter top-RIGHT: at this zoom the surface (and the forge) sits top-LEFT, so keep that
	# corner clear of HUD text (the forge-under-HUD legibility fix).
	var forged: String = "FORGED  %d ingot" % int(sim.total_produced.get(&"ingot", 0))
	var fw: float = _font.get_string_size(forged, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(_font, Vector2(CANVAS.x - fw - 12.0, 22), forged,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.80, 0.32))
	_draw_objectives()  # the tutorial chain, top-left — the "how do I play?" signpost
	_draw_hover()       # inspector for the machine under the cursor (recipe / I/O / holding)
	_draw_minimap()     # bottom-right world map — where you are, your machines, the dug shafts
	_draw_craft()       # now sits just above the hotbar (crafting next to the pack — Factorio-like)
	_draw_inventory()
	draw_rect(Rect2(0.0, CANVAS.y - 22.0, CANVAS.x, 22.0), Color(0.07, 0.08, 0.11, 0.9))  # controls backing
	draw_string(_font, Vector2(10, CANVAS.y - 10),
		"move A/D   jump SPACE   mine LMB   wheel pick   craft 1/2/3   place RMB   deposit E   pause P",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.75, 0.78, 0.85))
	if paused_getter.is_valid() and bool(paused_getter.call()):
		draw_string(_font, Vector2(CANVAS.x * 0.5 - 36.0, 22), "PAUSED (P)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.72, 0.30))


## The OBJECTIVES panel (top-left) — the signposted path through the loop. The current step is
## bright with its goal chip; done steps get a green tick and dim out; future steps stay muted. When
## the whole chain is finished it collapses to a short "all set" line, then auto-hides after a few
## seconds (the Guide stops nagging). Pure read of the Objectives tracker — no sim mutation.
func _draw_objectives() -> void:
	if objectives == null:
		return
	var cur: int = objectives.current_index()
	# Finished + lingered long enough → don't draw at all (keep the playfield clean for veterans).
	if objectives.all_done() and objectives.done_for() > 6.0:
		return
	var pad: float = 9.0
	var line_h: float = 16.0
	var pos := Vector2(12.0, 12.0)
	if objectives.all_done():
		var w: float = 232.0
		_panel(Rect2(pos, Vector2(w, 30.0)))
		draw_string(_font, pos + Vector2(pad, 20.0), "✓  All set — keep digging deeper.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.62, 0.86, 0.58))
		return
	var rows: int = objectives.steps.size()
	var width: float = 244.0
	var height: float = 26.0 + float(rows) * line_h + pad
	_panel(Rect2(pos, Vector2(width, height)))
	draw_string(_font, pos + Vector2(pad, 19.0), "OBJECTIVES",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.70, 0.74, 0.82))
	var y: float = pos.y + 26.0 + 12.0
	for i: int in rows:
		var step: Dictionary = objectives.steps[i]
		var done: bool = objectives.is_done(step["id"])
		var is_cur: bool = i == cur
		var box := Vector2(pos.x + pad, y - 9.0)
		# Checkbox: filled green tick when done, bright hollow ring when current, muted dot otherwise.
		if done:
			draw_string(_font, box, "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.84, 0.52))
		elif is_cur:
			draw_rect(Rect2(box + Vector2(1.0, -9.0), Vector2(9.0, 9.0)), Color(0.96, 0.82, 0.36), false, 1.5)
		else:
			draw_rect(Rect2(box + Vector2(2.0, -8.0), Vector2(7.0, 7.0)), Color(0.34, 0.36, 0.42), false, 1.0)
		var label: String = str(step["label"]) if is_cur else str(step["goal"])
		var col: Color
		if done:
			col = Color(0.50, 0.55, 0.52)        # completed — dim
		elif is_cur:
			col = Color(0.97, 0.93, 0.78)        # active — bright
		else:
			col = Color(0.55, 0.58, 0.66)        # upcoming — muted
		draw_string(_font, Vector2(pos.x + pad + 16.0, y), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12 if is_cur else 11, col)
		y += line_h


## A framed translucent panel backing (shared by HUD widgets — the start of the UI skin).
func _panel(rect: Rect2) -> void:
	draw_rect(rect, Color(0.06, 0.07, 0.10, 0.82))
	draw_rect(rect, Color(0.28, 0.31, 0.38, 0.9), false, 1.0)


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
	var width: float = 218.0
	var rows: int = 1 + int(has_recipe) + int(has_mode) + int(not holding.is_empty())
	var pad: float = 9.0
	var line_h: float = 18.0
	# Sits just below the minimap (same top-right column) so the two never collide.
	var mini_bottom: float = MINI_TOP + MINI_W * float(FactorySim.GRID_ROWS) / float(FactorySim.GRID_COLS)
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


## The MINIMAP (bottom-right): a cached image of the whole world — solid cells in their material
## colour, carved/dug cells as a dim wall backing, open sky as void — with your machines, YOU, and the
## visible window overlaid live. The terrain image rebuilds only when you DIG (sim.solid changes), so
## per-frame cost is one textured blit + a few dots. Navigation legibility for the cave-rich world (#9).
func _draw_minimap() -> void:
	if sim == null or not minimap_color.is_valid():
		return
	if _minimap_tex == null or sim.solid.size() != _minimap_solid_count:
		_minimap_solid_count = sim.solid.size()
		_rebuild_minimap()
	var cols: float = float(FactorySim.GRID_COLS)
	var rows: float = float(FactorySim.GRID_ROWS)
	var mw: float = MINI_W
	var mh: float = mw * rows / cols
	var origin := Vector2(CANVAS.x - mw - 12.0, MINI_TOP)
	var frame := Rect2(origin, Vector2(mw, mh))
	_panel(Rect2(origin - Vector2(3.0, 3.0), Vector2(mw + 6.0, mh + 6.0)))
	draw_texture_rect(_minimap_tex, frame, false)
	var scale := Vector2(mw / cols, mh / rows)
	var dot := Vector2(maxf(scale.x, 2.0), maxf(scale.y, 2.0))
	for m: MachineState in sim.machines:                       # your placed machines
		draw_rect(Rect2(origin + Vector2(m.cell) * scale, dot), Visuals.machine_color(m.def))
	if minimap_view.length() > 1.0:                            # the visible window
		var half: Vector2 = minimap_view * 0.5 / CELL
		var fc: Vector2 = minimap_focus / CELL
		var vr := Rect2(origin + (fc - half) * scale, minimap_view / CELL * scale)
		draw_rect(vr.intersection(frame), Color(1.0, 1.0, 1.0, 0.55), false, 1.0)
	var you := origin + minimap_focus / CELL * scale           # you-are-here marker
	draw_rect(Rect2(you - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color(0.97, 0.86, 0.36))
	draw_rect(Rect2(you - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), Color(0.10, 0.08, 0.0), false, 1.0)


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


## The CRAFT strip — 1 Processor (3 ingot)  2 Splitter (2 ingot) — press the number to craft one
## into the pack. Greyed when unaffordable. Centred just ABOVE the hotbar so crafting reads as part
## of the pack UI (and the top-left playfield stays clear). Two-pass: measure to centre, then draw.
func _draw_craft() -> void:
	if craft_options.is_empty():
		return
	var y: float = CANVAS.y - 28.0 - SLOT - 12.0
	var gap: float = 16.0
	var segs: Array[String] = ["CRAFT"]
	for i: int in craft_options.size():
		var opt: Dictionary = craft_options[i]
		segs.append("[%d] %s (%s)" % [i + 1, str(opt["name"]), _cost_text(opt["cost"])])
	var total_w: float = 0.0
	for s: String in segs:
		total_w += _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + gap
	var x: float = (CANVAS.x - (total_w - gap)) * 0.5
	draw_string(_font, Vector2(x, y), "CRAFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.62, 0.78, 0.68))
	x += _font.get_string_size("CRAFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + gap
	for i: int in craft_options.size():
		var cost: Dictionary = craft_options[i]["cost"]
		var label: String = segs[i + 1]
		draw_string(_font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.80, 0.86, 0.66) if _can_afford(cost) else Color(0.42, 0.44, 0.50))
		x += _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + gap


func _can_afford(cost: Dictionary) -> bool:
	for item: StringName in cost:
		if int(sim.inventory.get(item, 0)) < int(cost[item]):
			return false
	return true


func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for item: StringName in cost:
		parts.append("%d %s" % [int(cost[item]), item])
	return " ".join(parts)


## The carried pack as a hotbar of slots (icon + count), centred along the bottom. The active slot
## (mouse-wheel) is highlighted; it's the item E deposits. Reads `sim.inventory_slots()`.
func _draw_inventory() -> void:
	var slots: Array[Dictionary] = sim.inventory_slots()
	var n: int = FactorySim.INVENTORY_SLOTS
	var sel: int = int(inv_selected_getter.call()) if inv_selected_getter.is_valid() else 0
	var total_w: float = n * SLOT + (n - 1) * SLOT_GAP
	var x0: float = (CANVAS.x - total_w) * 0.5
	var y: float = CANVAS.y - 28.0 - SLOT
	for i: int in n:
		var sx: float = x0 + float(i) * (SLOT + SLOT_GAP)
		var slot_rect := Rect2(sx, y, SLOT, SLOT)
		draw_rect(slot_rect, Color(0.09, 0.10, 0.13, 0.88))
		var active: bool = i == sel
		draw_rect(slot_rect, Color(0.96, 0.85, 0.42) if active else Color(0.30, 0.32, 0.38),
			false, 2.0 if active else 1.0)
		if i < slots.size():
			var item: StringName = slots[i]["item"]
			var count: int = int(slots[i]["count"])
			var icon := Rect2(sx + 5.0, y + 4.0, SLOT - 10.0, SLOT - 13.0)
			if machine_icons.has(item):  # a machine item: its casing colour + a mini silhouette
				var ic: Dictionary = machine_icons[item]
				draw_rect(icon, ic["color"])
				# Same glyph the world draws (shared Visuals), just scaled down to the chip — never drifts.
				Visuals.draw_machine_glyph(self, icon.position + icon.size * 0.5, str(ic["kind"]),
					icon.size.y / 20.0, false, 0.0)
			else:
				draw_rect(icon, Visuals.item_color(item))
			draw_string(_font, Vector2(sx + 4.0, y + SLOT - 4.0), str(count),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.97, 0.97, 0.99))


func _buf(d: Dictionary) -> String:
	if d.is_empty():
		return "—"
	var parts: PackedStringArray = []
	for k: StringName in d:
		parts.append("%s %d" % [k, int(d[k])])
	return "  ".join(parts)
