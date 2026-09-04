class_name LightPainter
extends RefCounted

## THE ADDITIVE LIGHT PASS (A' step 6k, D0373): the pools that punch back through the veil. Legacy
## `scenes/world_renderer.gd`'s S2 seam -- `_paint_lights`, `_paint_machine_pools`, `_paint_godrays`,
## `_draw_glow`, the torch and conduit glows, the water sheen, the motes -- as one stateful painter on an
## ADD-blended canvas above the veil. Legacy's own rule for the whole pass: LIGHT REVEALS, IT DOES NOT
## PAINT. The veil's cut (`VeilPainter.lamp_lift`) is what makes rock visible; this is the bloom around a
## real lamp, held low so three overlapping pools cannot sum past 1 and blow the frame to a white smear.
##
## What the pass reads: the observation's body cell and facing (the lamp shares the VEIL's pool centre,
## `VeilPainter.lamp_head`, so a bloom and a reveal cannot light two different points), the machine
## records, the placed torches and conduits with the power field, the wet cells, the surface heights,
## and the scene's falling items for the motes. Every radius is legacy's, in metres (its cell), and
## becomes world px through `LOGIC_PX`. Not here: the sonar echoes (dead), the ore seam glow (S4, the
## glint's neighbour), and day/night -- this build has no day clock, so the godrays run at full day.

const LAMP_COLOR := Color(1.0, 0.82, 0.50)
const LAMP_RADIUS_M: float = 5.6
const LAMP_BLOOM: float = 0.17        ## legacy: at 0.32 it washed the pool's centre to cream
const IDLE_GLOW: float = 0.12         ## what is left of a machine's pool once it stops working
const MACHINE_POOL_R_M: float = 2.6
const MACHINE_POOL_LINK: int = ceili(MACHINE_POOL_R_M)
const FURNACE_EMBER := Color(1.0, 0.46, 0.16)
const BURNER_GLOW := Color(1.0, 0.62, 0.20)
const LIFT_TEAL := Color(0.36, 1.0, 0.90)
const TORCH_GLOW := Color(1.0, 0.60, 0.24)
const TORCH_R_M: float = 3.0
const CONDUIT_GLOW := Color(1.0, 0.78, 0.36)
const MOTE_R_M: float = 1.0
const RAY := Color(1.0, 0.95, 0.76)
const WATER_SHEEN := Color(0.32, 0.66, 0.98)
const WATER_SHEEN_BASE: float = 0.07
const WATER_SHEEN_LEVEL: float = 0.11
const WATER_SHEEN_RADIUS_M: float = 2.4
const WATER_SHEEN_SPREAD: float = 0.42
const M: float = float(Interface.Observation.LOGIC_PX)        ## world px per metre
const CELL: float = float(Interface.Observation.CELL_PX)
## The largest pool any source paints, so the view cull cannot clip a pool at the screen edge. Derived.
const CULL_M: float = maxf(maxf(TORCH_R_M, MACHINE_POOL_R_M), maxf(LAMP_RADIUS_M, WATER_SHEEN_RADIUS_M))

static var _glow: GradientTexture2D = null
var _falling: FallingItems = null


func _init(falling: FallingItems = null) -> void:
	_falling = falling


## A 128x128 radial gradient, bright centre to transparent edge, reused for every light pool: a hot
## centre and a fast fade rather than a wide soft wash.
static func glow_texture() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.92), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 128
		t.height = 128
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_glow = t
	return _glow


static func draw_glow(ci: CanvasItem, center: Vector2, radius: float, color: Color, intensity: float) -> void:
	if intensity <= 0.0 or radius <= 0.0:
		return
	ci.draw_texture_rect(glow_texture(), Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, Color(color.r, color.g, color.b, intensity))


static func logic_centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * M


## The lamp's flicker at `t`, times how dark the miner's own spot is: a live flame in the deep, a dim
## glow in daylight (the veil's own scale, so the bloom and the reveal agree about "deep").
static func lamp_flick(t: float, row: int) -> float:
	return (LAMP_BLOOM + 0.030 * sin(t * 11.0) + 0.020 * sin(t * 27.0)) * VeilPainter.lamp_scale(row)


## A machine record's pool: {col, pulse, burning}, or {} when it is out. A cold or idle machine barely
## glows (light means working); a burner with no coal goes dark entirely, a lift breathes with its power.
static func machine_pool(rec: Dictionary, t: float) -> Dictionary:
	var kind: String = MachineLook.kind(rec.get("behavior", &""), rec.get("id", &""), bool(rec.get("source", false)))
	var working: bool = rec.get("status", &"") == &"working"
	var col: Color = FURNACE_EMBER
	var pulse: float = 0.7 + 0.12 * sin(t * 3.0 + float((rec["cell"] as Vector2i).x))
	var idled: bool = false
	if not working:
		pulse *= IDLE_GLOW
		idled = true
	var fuel: int = int(rec.get("fuel", 0)) + int((rec.get("input", {}) as Dictionary).get(&"coal", 0))
	if kind == "generator":
		col = BURNER_GLOW
		pulse = (0.85 + 0.22 * sin(t * 6.5)) if fuel > 0 else 0.0
		idled = false
	elif kind == "lift":
		col = LIFT_TEAL
		pulse = (0.55 + 0.5 * float(rec.get("power_permille", 0)) / 1000.0) * (0.85 + 0.15 * sin(t * 3.0))
		idled = false
	elif kind != "furnace":
		col = MachineLook.color(rec.get("behavior", &""), rec.get("id", &""), bool(rec.get("source", false)))
	if pulse <= 0.0:
		return {}
	return {"col": col, "pulse": pulse, "idled": idled, "burning": kind == "furnace" or (kind == "generator" and fuel > 0)}


## Same-light neighbours within `MACHINE_POOL_LINK` flood into one pool whose intensity is its brightest
## member -- a run of burners is lit like one machine stretched along its length, never like N added.
## Returns [{centre (px), radius (px), col, pulse}] plus the burning cores as [{at, pulse, col}].
static func pools(records: Array[Dictionary], t: float) -> Dictionary:
	var lit: Array[Dictionary] = []
	var at_cell: Dictionary = {}
	for rec: Dictionary in records:
		var p: Dictionary = machine_pool(rec, t)
		if p.is_empty():
			continue
		p["cell"] = rec["cell"]
		at_cell[rec["cell"]] = lit.size()
		lit.append(p)
	var claimed: Dictionary = {}
	var out: Array[Dictionary] = []
	for start: int in lit.size():
		if claimed.has(start):
			continue
		claimed[start] = true
		var group: Array[int] = [start]
		var head: int = 0
		while head < group.size():
			var g: Dictionary = lit[group[head]]
			head += 1
			for dy: int in range(-MACHINE_POOL_LINK, MACHINE_POOL_LINK + 1):
				for dx: int in range(-MACHINE_POOL_LINK, MACHINE_POOL_LINK + 1):
					var probe: Vector2i = (g["cell"] as Vector2i) + Vector2i(dx, dy)
					if not at_cell.has(probe) or claimed.has(at_cell[probe]):
						continue
					var o: Dictionary = lit[at_cell[probe]]
					if (o["col"] as Color) != (g["col"] as Color) or bool(o["idled"]) != bool(g["idled"]):
						continue
					claimed[at_cell[probe]] = true
					group.append(at_cell[probe])
		var sum := Vector2.ZERO
		var lo := Vector2(lit[start]["cell"] as Vector2i)
		var hi: Vector2 = lo
		var pulse_max: float = 0.0
		for gi: int in group:
			var c := Vector2(lit[gi]["cell"] as Vector2i)
			sum += c
			lo = lo.min(c)
			hi = hi.max(c)
			pulse_max = maxf(pulse_max, float(lit[gi]["pulse"]))
		out.append({"centre": (sum / float(group.size()) + Vector2(0.5, 0.5)) * M,
			"radius": MACHINE_POOL_R_M * M + (hi - lo).length() * M * 0.5, "col": lit[start]["col"], "pulse": pulse_max, "size": group.size()})
	var cores: Array[Dictionary] = []
	for e: Dictionary in lit:
		if bool(e["burning"]):
			cores.append({"at": logic_centre(e["cell"]), "pulse": float(e["pulse"]), "col": e["col"]})
	return {"pools": out, "cores": cores}


## The godray for one logic column: {mouth_row, end_row, mouth_light, floor_light} in terrain rows, or
## {} when the column does not qualify -- its sky-lit air must drop 2 m or more below an adjacent
## surface, which covers dug shafts and carved notches while leaving 1 m slope steps clean.
static func godray(surf_row: int, left_row: int, right_row: int) -> Dictionary:
	var line_row: int = row_at_depth(VeilPainter.SURFACE_LINE_M)
	var reach_rows: int = int(VeilPainter.SKY_REACH_M * MaterialLook.CELLS_PER_METRE)
	var mouth: int = maxi(mini(left_row, right_row), line_row)
	if surf_row - mouth < 2 * MaterialLook.CELLS_PER_METRE:
		return {}
	var mouth_light: float = 1.0 - clampf(float(mouth - line_row) / float(reach_rows), 0.0, 1.0)
	if mouth_light <= 0.05:
		return {}
	var end_row: int = mini(surf_row, line_row + reach_rows + 2 * MaterialLook.CELLS_PER_METRE)
	var floor_light: float = 1.0 - clampf(float(end_row - line_row) / float(reach_rows), 0.0, 1.0)
	return {"mouth_row": mouth, "end_row": end_row, "mouth_light": mouth_light, "floor_light": floor_light, "lands": end_row == surf_row}


## The terrain row at `depth_m` below the generated datum: the inverse of `MaterialLook.depth_m_exact`.
static func row_at_depth(depth_m: float) -> int:
	return MaterialLook.SURFACE_ROW + int(round(depth_m * float(MaterialLook.CELLS_PER_METRE)))


static func _surface_row(o: Interface.Observation, terrain_col: int) -> int:
	var y: int = o.surface_y_at_terrain_col(terrain_col)
	if y == Interface.Observation.NO_FLOOR:
		return o.world_cells.y
	return int(floor(float(y) / float(Fx.SCALE) / CELL))


func paint_frame(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null:
		return
	var o: Interface.Observation = frame.obs
	var t: float = frame.anim_time
	var view: Rect2 = frame.view_world_rect.grow(CULL_M * M)
	_paint_godrays(o, ci, t, frame.view_world_rect)
	# The lamp: the aimed pool where the veil cuts, a dimmer throat between it and the head, a close body
	# glow -- two glows along one line read as a directed beam with no shader.
	var flick: float = lamp_flick(t, o.cell.y)
	var head: Vector2 = VeilPainter.lamp_head(o) * CELL
	var body: Vector2 = (Vector2(o.cell) + Vector2(0.5, 0.5)) * CELL
	draw_glow(ci, head, LAMP_RADIUS_M * M, LAMP_COLOR, flick)
	draw_glow(ci, body.lerp(head, 0.45), LAMP_RADIUS_M * M * 0.62, LAMP_COLOR, flick * 0.38)
	draw_glow(ci, body, 1.5 * M, LAMP_COLOR, 0.06 * VeilPainter.lamp_scale(o.cell.y))
	var p: Dictionary = pools(o.machines, t)
	for pool: Dictionary in p["pools"]:
		if view.has_point(pool["centre"]):
			draw_glow(ci, pool["centre"], pool["radius"], pool["col"], pool["pulse"])
	for core: Dictionary in p["cores"]:
		var pulse: float = core["pulse"]
		var c: Color = Color(1.0, 0.94, 0.82).lerp(core["col"], 0.18)
		ci.draw_circle(core["at"], (2.4 + 1.1 * pulse) * M / 32.0 * 2.0, Color(c.r, c.g, c.b, 0.85 * pulse))
	for cell: Vector2i in o.placed:
		var at: Vector2 = logic_centre(cell)
		if not view.has_point(at):
			continue
		if o.has_torch(cell):
			var gutter: float = 0.68 + 0.08 * sin(t * 9.0 + float(cell.x) * 1.7) + 0.05 * sin(t * 23.0 + float(cell.y))
			var tpool: Vector2 = at + Vector2(0.6, -3.0)
			draw_glow(ci, tpool, TORCH_R_M * M, TORCH_GLOW, gutter)
			ci.draw_circle(tpool, (1.6 + 0.8 * gutter) * 0.5, Color(1.0, 0.93, 0.78, 0.8 * gutter))
		elif o.has_conduit(cell):
			var lvl: float = clampf(float(o.power_at(cell)) / float(int(MachinesRecords.RECORDS["conduit"]["capacity_milli"])), 0.0, 1.0)
			if lvl > 0.04:
				draw_glow(ci, at, (0.9 + 0.7 * lvl) * M, CONDUIT_GLOW, lvl * 0.7)
	if _falling != null:
		var mote_view: Rect2 = frame.view_world_rect.grow(2.0 * M)
		for m: Dictionary in _falling.motes():
			if mote_view.has_point(m["pos"]):
				draw_glow(ci, m["pos"], MOTE_R_M * M, m["color"], 0.38)
	_paint_water_sheen(o, ci, t, view)


## Where a dug shaft admits the sky below the enclosing ground, a soft daylight beam pours down it.
func _paint_godrays(o: Interface.Observation, ci: CanvasItem, t: float, view: Rect2) -> void:
	var n: int = int(MaterialLook.CELLS_PER_METRE)
	var col0: int = floori(view.position.x / M) - 1
	var col1: int = ceili(view.end.x / M) + 1
	for lc: int in range(col0, col1 + 1):
		var tc: int = lc * n + n / 2
		if tc < 0 or tc >= o.world_cells.x:
			continue
		var ray: Dictionary = godray(_surface_row(o, tc), _surface_row(o, maxi(tc - n, 0)), _surface_row(o, mini(tc + n, o.world_cells.x - 1)))
		if ray.is_empty():
			continue
		var x: float = float(lc) * M
		var y0: float = float(ray["mouth_row"]) * CELL
		var y1: float = float(ray["end_row"]) * CELL + (M * 0.4 if bool(ray["lands"]) else 0.0)
		var shimmer: float = 0.85 + 0.15 * sin(t * 0.7 + float(lc) * 1.3)
		var mouth_light: float = ray["mouth_light"]
		for pass_i: int in 2:
			var half_w: float = (M * 0.46) if pass_i == 0 else (M * 0.24)
			var a: float = (0.10 if pass_i == 0 else 0.14) * mouth_light * shimmer
			var a_end: float = a * (float(ray["floor_light"]) / maxf(mouth_light, 0.01)) * 0.5
			var cx: float = x + M * 0.5
			ci.draw_polygon(PackedVector2Array([Vector2(cx - half_w, y0), Vector2(cx + half_w, y0), Vector2(cx + half_w * 0.8, y1), Vector2(cx - half_w * 0.8, y1)]),
				PackedColorArray([Color(RAY, a), Color(RAY, a), Color(RAY, a_end), Color(RAY, a_end)]))
		if bool(ray["lands"]) and float(ray["floor_light"]) > 0.06:
			draw_glow(ci, Vector2(x + M * 0.5, float(ray["end_row"]) * CELL), 1.6 * M, RAY, 0.18 * float(ray["floor_light"]) * shimmer)


## A faint cool bloom off the water's SKIN -- the top and the sides of a body, never its middle -- so a
## flooded pocket reads as a dim blue presence in the deep before a lamp reaches it. Our water cell is a
## quarter of legacy's metre, so the radius scales with it and neighbours still blend.
func _paint_water_sheen(o: Interface.Observation, ci: CanvasItem, t: float, view: Rect2) -> void:
	var r: float = WATER_SHEEN_RADIUS_M * CELL
	for wc: Vector2i in o.wet_cells:
		var at: Vector2 = (Vector2(wc) + Vector2(0.5, 0.5)) * CELL
		if not view.has_point(at):
			continue
		if o.water_at(wc - Vector2i(0, 1)) > 0 and o.water_at(wc + Vector2i(-1, 0)) > 0 and o.water_at(wc + Vector2i(1, 0)) > 0:
			continue
		var frac: float = clampf(float(o.water_at(wc)) / float(Interface.Observation.WATER_MAX), 0.0, 1.0)
		var shim: float = 0.9 + 0.1 * sin(t * 1.8 + float(wc.x) * 0.6 + float(wc.y) * 0.4)
		draw_glow(ci, at, r, WATER_SHEEN, (WATER_SHEEN_BASE + WATER_SHEEN_LEVEL * frac) * WATER_SHEEN_SPREAD * shim)
