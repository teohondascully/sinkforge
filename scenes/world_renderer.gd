class_name WorldRenderer
extends Node2D

## The VIEW layer — all world-space drawing of the sim, split out of MainView so the controller
## (input + verbs + lifecycle) and the renderer are separately comprehensible. It READS the sim and a
## few pushed view-state values; it never mutates production state (delete it and the numbers are
## identical). Owns the MaterialDef registry (the visualiser half of the world-engine handshake), the
## cosmetic animation clock, and the two lighting canvases.
##
## Data flow is one-way: MainView PUSHES what the renderer can't derive from the sim — the aim cursor
## and its computed reach/placeable/ghost state via set_aim() — rather than the renderer reaching back
## into the controller. Everything else (terrain, machines, ground, lighting) it reads from the sim.

const CELL: int = 32
const WORLD_SIZE := Vector2(FactorySim.GRID_COLS * CELL, FactorySim.GRID_ROWS * CELL)
const SKY_COLOR := Color(0.09, 0.11, 0.16)         ## open air ABOVE the surface

## --- Lighting (the mood lever) -----------------------------------------------------------------
## The model is SKYLIGHT + ambient, not a depth gradient: the underground is near-black EVERYWHERE,
## and daylight only reaches where open air connects it to the sky. Sky floods DOWN each column's open
## air, attenuating with depth, and is BLOCKED by the first solid rock — so a dug shaft pours daylight
## down (it follows your digging), the dirt beside it stays dark, and an enclosed cave is pitch black
## until you bring a lamp. Warm artificial LIGHT pools (head-lamp, forge embers, machine glow) are the
## only light in the deep — your claimed territory in the black. (Recomputed when terrain changes.)
const SURFACE_LINE: int = 5                         ## reference daylight row; sky attenuates with depth past it
const SKY_REACH: int = 10                           ## tiles of open air sunlight reaches before going dark
const SKY_FADE: int = 3                             ## tiles of shallow light-scatter just under the surface
const AMBIENT_DARK: float = 0.945                   ## underground ambient (near-black, but a readability
                                                   ## floor — faint shapes read in the dark; the lamp still matters)
const SHADOW_COLOR := Color(0.03, 0.04, 0.075)      ## the cool blue-black the underworld sits in
const LAMP_COLOR := Color(1.0, 0.90, 0.66)          ## the miner's warm head-lamp
const LAMP_RADIUS: float = CELL * 5.0

var sim: FactorySim
var player: Player
var falling: FallingItems
var particles: Particles                              ## cosmetic juice layer (set by MainView), drawn on top

var _font: Font = ThemeDB.fallback_font
var _anim_time: float = 0.0                          ## free-running cosmetic clock (never feeds the sim)
var _materials: Dictionary = {}                      ## id -> MaterialDef (world-engine viz registry)

# Pushed by MainView each frame (the bits the renderer can't derive from the sim alone).
var _aim: Vector2i = Vector2i(-99, -99)
var _aim_in_reach: bool = false
var _aim_placeable: bool = false
var _ghost_def: MachineDef = null

var _dark: LightLayer
var _lights: LightLayer
var _glow_tex: GradientTexture2D
var _last_solid_count: int = -1                      ## repaint the skylight only when terrain (digging) changes


## Wire the renderer to the session it draws (called once by MainView after the sim + player exist).
func setup(world_sim: FactorySim, falling_items: FallingItems, body: Player) -> void:
	sim = world_sim
	falling = falling_items
	player = body
	for path: String in [
		"res://src/data/materials/earth.tres",
		"res://src/data/materials/ore.tres",
		"res://src/data/materials/stone.tres",
		"res://src/data/materials/dirt_wall.tres",
		"res://src/data/materials/stone_wall.tres",
	]:
		var def: MaterialDef = load(path)
		_materials[def.id] = def
	# Two world-space canvases ABOVE this renderer's draw — the skylight/darkness veil, then light pools.
	_glow_tex = _make_glow_texture()
	_dark = LightLayer.new()
	_dark.setup(50, false, _paint_darkness)
	add_child(_dark)
	_lights = LightLayer.new()
	_lights.setup(51, true, _paint_lights)
	add_child(_lights)
	_dark.queue_redraw()  # the skylight veil changes only when you DIG — repaint on terrain change, not per-frame


## The controller hands over the cursor + its computed affordances (reach / placeable / the ghost def).
func set_aim(cell: Vector2i, in_reach: bool, placeable: bool, ghost_def: MachineDef) -> void:
	_aim = cell
	_aim_in_reach = in_reach
	_aim_placeable = placeable
	_ghost_def = ghost_def


func _process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()              # falling items, machine animation + the aim cursor move every frame
	if _lights != null:
		_lights.queue_redraw()  # the lamp follows the body + machines shimmer
	# Skylight depends on terrain: when you DIG (solid count drops), daylight can reach further down a
	# new shaft — so repaint the static veil then, not every frame.
	if _dark != null and sim.solid.size() != _last_solid_count:
		_last_solid_count = sim.solid.size()
		_dark.queue_redraw()


# --- draw sequence (WORLD space; the Camera2D provides the view transform) ----

func _draw() -> void:
	_draw_background()  # sky above the surface; dark-dirt BACK WALL behind every dug-out cell + depth
	_draw_terrain()
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE).grow(1.0), Color(0.22, 0.23, 0.27), false, 2.0)
	_draw_drop_paths()
	_draw_updrafts()  # rising shimmer in each lift's shaft, so "this column lifts UP" reads
	_draw_ground()
	falling.draw(self)
	for machine: MachineState in sim.machines:
		_draw_machine(machine)
	if particles != null:
		particles.draw(self)
	_draw_aim()


func _draw_terrain() -> void:
	for cell: Variant in sim.solid:
		var c: Vector2i = cell
		var pos := Vector2(c) * float(CELL)
		var def: MaterialDef = _material(sim.solid[c])
		# Darken with depth so the lower world reads as DEEPER, not one flat fill.
		var depth: float = clampf(float(c.y) / float(FactorySim.GRID_ROWS), 0.0, 1.0)
		var col: Color = def.base_color.darkened(depth * def.depth_darken)
		# Per-cell tonal jitter (deterministic) so a field of earth isn't ONE flat colour — the single
		# biggest flat-fill tell. A stable hash nudges each cell's value a few percent up or down.
		var j: float = _cell_jitter(c)
		col = col.lightened(j) if j > 0.0 else col.darkened(-j)
		draw_rect(Rect2(pos, Vector2(CELL, CELL)), col)
		if def.grain:
			# Rock grain — a darker pit + a lighter clod + a mid chip, deterministic per cell, so the
			# surface reads as textured rock rather than a colour swatch.
			var sp: Array[Vector2] = _cell_speckles(c, 3)
			draw_rect(Rect2(pos + sp[0] - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), col.darkened(0.26))
			draw_rect(Rect2(pos + sp[1] - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), col.lightened(0.12))
			draw_rect(Rect2(pos + sp[2] - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), col.darkened(0.14))
		if def.has_nuggets():  # embedded specks so a vein reads as ore IN rock, not an orange block
			for nug: Vector2 in _cell_speckles(c, def.nugget_count):
				draw_circle(pos + nug, 2.0, def.nugget_color)
				draw_circle(pos + nug - Vector2(0.6, 0.6), 0.9, def.nugget_color.lightened(0.4))  # glint
		_draw_edge_ao(c, pos)  # carved depth: ambient occlusion on faces that border open air
	_draw_terrain_surface()


## A SMOOTH, spatially-coherent value nudge (~[-0.06, +0.06]) — low-frequency sines so neighbouring
## cells share tone (cloudy patches), NOT a per-cell random that seams at every tile edge (which just
## rebuilds the grid). Breaks the flat fill into organic light/dark drift. RNG-free → determinism-safe.
func _cell_jitter(c: Vector2i) -> float:
	var x: float = float(c.x)
	var y: float = float(c.y)
	var n: float = sin(x * 0.37 + y * 0.21) + sin(x * 0.13 - y * 0.41) + sin((x + y) * 0.27)
	return n / 3.0 * 0.06


## Ambient-occlusion crevice shadow on each cell face that borders OPEN air — a few inset strips of
## fading dark, so dug tunnels and exposed dirt faces look CARVED (recessed), not like flat stickers.
func _draw_edge_ao(c: Vector2i, pos: Vector2) -> void:
	const STEPS: int = 3
	for i: int in STEPS:
		var a: float = 0.20 * (1.0 - float(i) / float(STEPS))
		var sh := Color(0.0, 0.0, 0.0, a)
		var o: float = float(i) * 2.0
		var s := 2.0
		if not sim.is_solid(c + Vector2i(0, -1)):  # top face exposed
			draw_rect(Rect2(pos.x, pos.y + o, float(CELL), s), sh)
		if not sim.is_solid(c + Vector2i(0, 1)):   # bottom face exposed (a ceiling from below)
			draw_rect(Rect2(pos.x, pos.y + float(CELL) - o - s, float(CELL), s), sh)
		if not sim.is_solid(c + Vector2i(-1, 0)):  # left face exposed
			draw_rect(Rect2(pos.x + o, pos.y, s, float(CELL)), sh)
		if not sim.is_solid(c + Vector2i(1, 0)):   # right face exposed
			draw_rect(Rect2(pos.x + float(CELL) - o - s, pos.y, s, float(CELL)), sh)


## A cell's MaterialDef via the registry, or a safe fallback so an unknown id still renders.
func _material(id: StringName) -> MaterialDef:
	return _materials.get(id, _materials.get(&"earth"))


## Deterministic in-cell speckle positions (no RNG → determinism-safe): a stable hash of the cell
## seeds N points inset from the edges. Used for dirt grain + ore nuggets so terrain reads textured.
func _cell_speckles(c: Vector2i, n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var h: int = (int(c.x) * 73856093) ^ (int(c.y) * 19349663)
	for _i: int in n:
		h = (h * 1103515245 + 12345) & 0x7fffffff
		var fx: float = float(h % 1000) / 1000.0
		h = (h * 1103515245 + 12345) & 0x7fffffff
		var fy: float = float(h % 1000) / 1000.0
		out.append(Vector2(4.0 + fx * float(CELL - 8), 4.0 + fy * float(CELL - 8)))
	return out


## Smooth the blocky surface, reading the sim's shared silhouette authority (sim.surface_row /
## sim.ramp_dir) so the diagonal we DRAW is exactly the one the avatar WALKS. The ramp GEOMETRY is
## universal (every material slopes); only the EDGE PAINT is material-specific (grass cap vs stone lip).
func _draw_terrain_surface() -> void:
	for col: int in range(FactorySim.GRID_COLS):
		var r: int = sim.surface_row(col)
		if r >= FactorySim.GRID_ROWS:
			continue  # empty column, no surface
		var def: MaterialDef = _material(sim.material_at(Vector2i(col, r)))
		var edge: Color = def.cap_color if def.has_cap() else def.base_color.lightened(0.18)
		var px := float(col * CELL)
		var py := float(r * CELL)
		match sim.ramp_dir(col):
			1:  # rising to the right — fill the air corner above with a 45° slope
				var lo := Vector2(px, py)
				var hi := Vector2(px + CELL, py - CELL)
				draw_colored_polygon([lo, Vector2(px + CELL, py), hi], def.base_color)
				draw_line(lo, hi, edge, 3.0)
			-1:  # rising to the left
				var lo2 := Vector2(px + CELL, py)
				var hi2 := Vector2(px, py - CELL)
				draw_colored_polygon([lo2, Vector2(px, py), hi2], def.base_color)
				draw_line(lo2, hi2, edge, 3.0)
			_:  # flat top: a capped lip
				draw_rect(Rect2(px, py, float(CELL), 4.0), edge)


## The cursor cell, drawn by context (using the affordances MainView pushed via set_aim):
##   solid earth -> MINE box (white; faint out of reach) · your machine -> PICK-UP outline ·
##   open cell -> BUILD ghost of the selected machine (green outline = placeable, red = blocked).
func _draw_aim() -> void:
	if not sim.in_bounds(_aim):
		return
	var pos := Vector2(_aim) * float(CELL)
	if sim.is_solid(_aim):
		var col := Color(1, 1, 1, 0.85) if _aim_in_reach else Color(1, 1, 1, 0.18)
		draw_rect(Rect2(pos, Vector2(CELL, CELL)), col, false, 2.0)
		return
	if not _aim_in_reach:
		return
	var inner := Rect2(pos + Vector2(1, 1), Vector2(CELL - 2, CELL - 2))
	if sim.machine_at(_aim) != null:
		draw_rect(inner, Color(0.95, 0.45, 0.40, 0.9), false, 2.0)  # pick-up affordance
		return
	if _ghost_def == null:
		return  # the active hotbar item isn't a placeable machine — nothing to ghost
	# A brighter, more opaque tint so the ghost reads as a translucent PREVIEW on its own (4b critique).
	var ghost: Color = Visuals.machine_color(_ghost_def).lerp(Color.WHITE, 0.20)
	ghost.a = 0.55
	draw_rect(Rect2(pos + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)), ghost)
	Visuals.draw_machine_glyph(self, pos + Vector2(CELL, CELL) * 0.5, Visuals.machine_kind(_ghost_def), 1.0, false, 0.0)
	# A bright WHITE box hovering over the target cell (Terraria placement cursor); red when blocked.
	var border := Color(0.97, 0.98, 1.0, 0.95) if _aim_placeable else Color(0.95, 0.45, 0.40, 0.95)
	draw_rect(inner, border, false, 2.5)


## Sky + the REAL background WALL layer (sim.wall). Open sky fills the top; each wall cell paints its
## material colour (depth-darkened) BEHIND the terrain, so a dug-out cell reveals the carved-room backing.
func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), SKY_COLOR)
	for cell_v: Variant in sim.wall:
		var c: Vector2i = cell_v
		var def: MaterialDef = _material(sim.wall[c])
		var depth: float = clampf(float(c.y) / float(FactorySim.GRID_ROWS), 0.0, 1.0)
		draw_rect(Rect2(Vector2(c) * float(CELL), Vector2(CELL, CELL)),
			def.base_color.darkened(depth * def.depth_darken))


func _draw_drop_paths() -> void:
	var guide := Color(0.45, 0.55, 0.68, 0.20)
	for machine: MachineState in sim.machines:
		var col: int = machine.cell.x
		var cx: float = float(col * CELL) + float(CELL) * 0.5
		var bottom: float = float(machine.cell.y * CELL) + float(CELL)
		draw_line(Vector2(cx, bottom), Vector2(cx, _guide_end_y(col, machine.cell.y + 1, bottom)), guide, 2.0)
		if machine.def.behavior == &"splitter" and col + 1 < FactorySim.GRID_COLS:
			var cy: float = float(machine.cell.y * CELL) + float(CELL) * 0.5
			var rx: float = float((col + 1) * CELL) + float(CELL) * 0.5
			draw_line(Vector2(cx, cy), Vector2(rx, cy), guide, 2.0)
			draw_line(Vector2(rx, cy), Vector2(rx, _guide_end_y(col + 1, machine.cell.y, cy)), guide, 2.0)


## Rising shimmer in the open shaft above each lift — teal motes that ascend and fade, so the
## inverted-gravity column reads at a glance. Purely cosmetic (driven by _anim_time, never the sim).
func _draw_updrafts() -> void:
	for machine: MachineState in sim.machines:
		if machine.def.behavior != &"lift":
			continue
		var c: Vector2i = machine.cell
		var top_row: int = 0  # scan up to the first solid/machine — the top of the open shaft
		for r: int in range(c.y - 1, -1, -1):
			if sim.is_solid(Vector2i(c.x, r)) or sim.machine_at(Vector2i(c.x, r)) != null:
				top_row = r + 1
				break
		var top_y: float = float(top_row * CELL)
		var bot_y: float = float(c.y * CELL)
		var height: float = bot_y - top_y
		if height <= 1.0:
			continue
		var cx: float = float(c.x * CELL) + float(CELL) * 0.5
		var motes: int = 6
		for i: int in motes:
			var phase: float = fmod(_anim_time * 46.0 + float(i) * height / float(motes), height)
			var my: float = bot_y - phase                          # rises from the lift up the shaft
			var mx: float = cx + sin((_anim_time * 2.0 + float(i)) * 1.7) * 7.0
			var a: float = (1.0 - phase / height) * 0.7            # fade as it climbs
			draw_circle(Vector2(mx, my), 2.4, Color(0.6, 1.0, 0.92, a))


func _guide_end_y(col: int, start_row: int, stub_from: float) -> float:
	for row: int in range(start_row, FactorySim.GRID_ROWS):
		if sim.machine_at(Vector2i(col, row)) != null:
			return float(row * CELL)
	return stub_from + float(CELL) * 0.9


## Resting product piles on the floor (sim.ground) — what a machine has spat out, waiting to be
## walked over and collected. A little stack so a bigger pile reads as "more".
func _draw_ground() -> void:
	for cell_v: Variant in sim.ground:
		var cell: Vector2i = cell_v
		var pile: Dictionary = sim.ground[cell]
		var base := Vector2(cell) * float(CELL)
		var total: int = 0
		for v: int in pile.values():
			total += v
		var shown: int = mini(total, 4)
		var idx: int = 0
		for item: StringName in pile:
			var per: int = mini(int(pile[item]), shown)
			for _k: int in per:
				var p := base + Vector2(float(CELL) * 0.5, float(CELL) - 6.0 - float(idx) * 4.5)
				draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color(0.04, 0.04, 0.06))
				draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9, 9)), Visuals.item_color(item))
				idx += 1


## A machine: a riveted CASING + its animated type glyph (shared Visuals) + a held-count badge + the
## recipe progress bar. The glyph spins/breathes while the machine is working.
func _draw_machine(machine: MachineState) -> void:
	var pos: Vector2 = Vector2(machine.cell) * float(CELL)
	var recipe: RecipeDef = machine.def.recipe
	var center: Vector2 = pos + Vector2(CELL, CELL) * 0.5
	# Contact shadow — grounds the machine on the floor it sits on.
	draw_set_transform(pos + Vector2(float(CELL) * 0.5, float(CELL) - 1.0), 0.0, Vector2(1.0, 0.26))
	draw_circle(Vector2.ZERO, float(CELL) * 0.46, Color(0.0, 0.0, 0.0, 0.30))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := Rect2(pos + Vector2(1.0, 1.0), Vector2(CELL - 2.0, CELL - 2.0))
	draw_rect(body, Visuals.machine_color(machine.def))
	draw_rect(body, Color(0.04, 0.04, 0.06, 0.8), false, 1.5)  # darker inset casing
	for corner: Vector2 in [Vector2(4, 4), Vector2(CELL - 4, 4), Vector2(4, CELL - 4),
			Vector2(CELL - 4, CELL - 4)]:
		draw_circle(pos + corner, 1.0, Color(0.0, 0.0, 0.0, 0.5))  # bolts

	# A machine reads as ALIVE while it's working — it has materials in hand or a cycle in progress.
	var active: bool = _held(machine) > 0 or machine.progress > 0.0
	Visuals.draw_machine_glyph(self, center, Visuals.machine_kind(machine.def), 1.0, active, _anim_time)

	var held: int = _held(machine)
	if held > 0:
		var badge := Vector2(pos.x + float(CELL) - 12.0, pos.y + 4.0)
		draw_rect(Rect2(badge, Vector2(10.0, 11.0)), Color(0.04, 0.04, 0.06, 0.85))
		draw_string(_font, badge + Vector2(1.5, 9.0), str(held),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.97, 0.97, 0.99))

	if recipe != null and recipe.time > 0.0:
		var bar_y: float = pos.y + float(CELL) - 3.0
		draw_rect(Rect2(pos.x, bar_y, float(CELL), 3.0), Color(0.0, 0.0, 0.0, 0.35))
		var frac: float = clampf(machine.progress / recipe.time, 0.0, 1.0)
		draw_rect(Rect2(pos.x, bar_y, float(CELL) * frac, 3.0), Color(0.40, 0.90, 0.45))


func _held(machine: MachineState) -> int:
	var n: int = 0
	for v: int in machine.input_buffer.values():
		n += v
	for v: int in machine.output_buffer.values():
		n += v
	return n


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * float(CELL) + Vector2(CELL, CELL) * 0.5


# --- Lighting passes (painted by the LightLayer children; pure visuals) -------

## The SKYLIGHT veil (per column): daylight floods DOWN each column's open air, attenuating with depth
## (SKY_REACH) and BLOCKED by the first solid rock — below that it's full underground ambient, plus a
## couple tiles of shallow scatter just under the exposed surface. So an open/dug shaft is lit down its
## length, the rock beside it is dark, and an enclosed cave is near-black. Painted only on terrain change.
func _paint_darkness(layer: LightLayer) -> void:
	var cell_f: float = float(CELL)
	for col: int in range(FactorySim.GRID_COLS):
		var surf: int = sim.surface_row(col)            # first solid going down = where sky is blocked
		var x: float = float(col) * cell_f
		var ambient_from: int = surf + SKY_FADE         # below the shallow-scatter band → pure ambient
		for row: int in range(FactorySim.GRID_ROWS):
			var a: float = _skylight_alpha(row, surf)
			if a <= 0.004:
				continue                                # full daylight — let the world show through
			if row >= ambient_from:                     # collapse the uniform deep ambient into one rect
				layer.draw_rect(Rect2(x, float(row) * cell_f, cell_f,
					float(FactorySim.GRID_ROWS - row) * cell_f),
					Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, a))
				break
			layer.draw_rect(Rect2(x, float(row) * cell_f, cell_f, cell_f),
				Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, a))


## Darkness alpha for one cell, given its column's first-solid row. Open air above the rock is lit by
## sky (attenuating with absolute depth past SURFACE_LINE); the exposed surface + SKY_FADE tiles below
## get shallow scatter; everything deeper is full ambient.
func _skylight_alpha(row: int, surf: int) -> float:
	var atten: float = clampf(float(row - SURFACE_LINE) / float(SKY_REACH), 0.0, 1.0)
	if row <= surf:
		return AMBIENT_DARK * atten                     # sky-lit open air / exposed ground, dimming with depth
	var scatter: float = clampf(float(row - surf) / float(SKY_FADE), 0.0, 1.0)
	return lerpf(AMBIENT_DARK * atten, AMBIENT_DARK, scatter)


## The additive LIGHT pools that punch back through the veil: the miner's head-lamp + a glow per machine
## + a glow per falling drop (the gravity stream made loud).
func _paint_lights(layer: LightLayer) -> void:
	if player != null:
		var f: float = float(player.facing)
		# A faint flicker so the lamp reads as a live flame, not a static disc.
		var flick: float = 0.8 + 0.04 * sin(_anim_time * 11.0) + 0.03 * sin(_anim_time * 27.0)
		_draw_glow(layer, player.position + Vector2(f * float(CELL) * 0.7, -float(CELL) * 0.2),
			LAMP_RADIUS, LAMP_COLOR, flick)
		_draw_glow(layer, player.position, float(CELL) * 1.7, LAMP_COLOR, 0.24)  # close body glow
	for machine: MachineState in sim.machines:
		var kind: String = Visuals.machine_kind(machine.def)
		var col: Color = Color(1.0, 0.58, 0.30)            # furnace ember (warm)
		if kind == "lift":
			col = Color(0.5, 1.0, 0.92)                    # lift teal (echoes the updraft motes)
		elif kind != "furnace":
			col = Color(0.55, 0.82, 0.98)                  # cool machine glow
		var pulse: float = 0.5 + 0.1 * sin(_anim_time * 3.0 + float(machine.cell.x))  # a sign of life
		_draw_glow(layer, _cell_center(machine.cell), float(CELL) * 2.3, col, pulse)
	for m: Dictionary in falling.motes():
		_draw_glow(layer, m["pos"], float(CELL) * 1.35, m["color"], 0.6)


## One soft radial light pool (the shared glow texture, tinted + faded), added over the darkness.
func _draw_glow(layer: LightLayer, center: Vector2, radius: float, color: Color, intensity: float) -> void:
	var tint := Color(color.r, color.g, color.b, intensity)
	layer.draw_texture_rect(_glow_tex, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
		false, tint)


## A 128² radial gradient (bright centre → transparent edge, soft curve) reused for every light pool.
func _make_glow_texture() -> GradientTexture2D:
	var g := Gradient.new()
	# Softer core (0.72, not a clipping 0.85) so a pool shows its WARM colour instead of blowing to white.
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.72), Color(1, 1, 1, 0.26), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
