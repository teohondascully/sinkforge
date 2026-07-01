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
const AMBIENT_DARK: float = 0.62                    ## underground ambient — DIM but visible (Terraria), not
                                                   ## pitch black. You can read the terrain everywhere; light
                                                   ## sources add warmth + clarity rather than being the ONLY way to see.
const SHADOW_COLOR := Color(0.05, 0.06, 0.10)       ## the cool blue-black the underworld sits in
const LAMP_COLOR := Color(1.0, 0.90, 0.66)          ## the miner's warm head-lamp
const LAMP_RADIUS: float = CELL * 4.0               ## a focused warm pool, not a screen-filling white disc

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
var _ghost_material: StringName = &""                ## a building material selected for block placement
var _guide_targets: Array[Dictionary] = []           ## current objective's WHERE-cells (pushed by MainView)
var _mine_cell: Vector2i = Vector2i(-999, -999)       ## block being charge-mined (cracks drawn on it; pushed by MainView)
var _mine_frac: float = 0.0                           ## 0..1 break-charge of that block — the felt-friction read
var bazaars: Bazaars = null                          ## the Bazaar view layer (set by MainView); may be null

var _terrain: LightLayer                             ## STATIC terrain/walls/surface — repainted only on terrain change, not per frame
var _dark: LightLayer
var _lights: LightLayer
var _glow_tex: GradientTexture2D
var _terrain_sig: Array = []                          ## last terrain signature; repaint terrain + skylight only when it changes


## Wire the renderer to the session it draws (called once by MainView after the sim + player exist).
func setup(world_sim: FactorySim, falling_items: FallingItems, body: Player) -> void:
	sim = world_sim
	falling = falling_items
	player = body
	for path: String in [
		"res://src/data/materials/earth.tres",
		"res://src/data/materials/ore.tres",
		"res://src/data/materials/coal.tres",
		"res://src/data/materials/stone.tres",
		"res://src/data/materials/deepslate.tres",
		"res://src/data/materials/wood.tres",
		"res://src/data/materials/leaves.tres",
		"res://src/data/materials/dirt_wall.tres",
		"res://src/data/materials/stone_wall.tres",
		"res://src/data/materials/deepslate_wall.tres",
	]:
		var def: MaterialDef = load(path)
		_materials[def.id] = def
	# A STATIC terrain canvas BELOW this renderer's dynamic draw (z -10): it carries the heavy ~7700-cell
	# immediate-mode terrain + wall + surface pass, repainted ONLY when the terrain changes (dig / place /
	# a drill draining a deposit) instead of every frame. Between changes the GPU replays its retained
	# buffer for free — the single biggest perf win, since the bottleneck was GDScript re-issuing the
	# whole world's draw commands 60×/second (the sim itself does almost nothing).
	_terrain = LightLayer.new()
	_terrain.setup(-10, false, _paint_terrain)
	add_child(_terrain)
	# Two world-space canvases ABOVE this renderer's draw — the skylight/darkness veil, then light pools.
	_glow_tex = _make_glow_texture()
	_dark = LightLayer.new()
	_dark.setup(50, false, _paint_darkness)
	add_child(_dark)
	_lights = LightLayer.new()
	_lights.setup(51, true, _paint_lights)
	add_child(_lights)
	_terrain.queue_redraw()
	_dark.queue_redraw()  # terrain + skylight veil change only when you DIG — repaint on terrain change, not per-frame


## The controller hands over the cursor + its computed affordances (reach / placeable / the ghost def).
func set_aim(cell: Vector2i, in_reach: bool, placeable: bool, ghost_def: MachineDef, ghost_material: StringName = &"") -> void:
	_ghost_material = ghost_material
	_aim = cell
	_aim_in_reach = in_reach
	_aim_placeable = placeable
	_ghost_def = ghost_def


## The controller hands over the cells the CURRENT objective points at (each {cell, mode}) — drawn as a
## pulsing ring ("act") or a ghost outline ("ghost") so a new player always sees WHERE the next step happens.
func set_guide_targets(targets: Array[Dictionary]) -> void:
	_guide_targets = targets


## The controller pushes which block is being charge-mined and how far along (0..1) each frame, so the
## renderer can spider cracks across it — the visible friction that says "this is taking effort". Cosmetic.
func set_mine_progress(cell: Vector2i, frac: float) -> void:
	_mine_cell = cell
	_mine_frac = frac


func _process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()              # falling items, machine animation + the aim cursor move every frame
	if _lights != null:
		_lights.queue_redraw()  # the lamp follows the body + machines shimmer
	# Terrain + skylight depend on the dug world, NOT the cosmetic clock: repaint them ONLY when the
	# terrain actually changes (dig / place / a drill draining a deposit) — so the heavy full-world cell
	# pass runs on a dig, not 60×/second. Between changes each layer's retained GPU buffer is replayed.
	var sig: Array = _terrain_signature()
	if sig != _terrain_sig:
		_terrain_sig = sig
		if _terrain != null:
			_terrain.queue_redraw()
		if _dark != null:
			_dark.queue_redraw()


# --- draw sequence (WORLD space; the Camera2D provides the view transform) ----

func _draw() -> void:
	# Terrain + background walls + the world border + the smoothed surface are STATIC: drawn once by the
	# _terrain LightLayer (below this, z -10) and repainted only on terrain change. This per-frame pass
	# draws ONLY the live/sparse content (machines, items, conduits, cursor) — no full-world cell loop.
	_draw_drop_paths()
	_draw_updrafts()  # rising shimmer in each lift's shaft, so "this column lifts UP" reads
	_draw_conduits()  # power tubes (copper, with a channel that glows by the live power level)
	_draw_ore_deposits()  # glittering exposed ore in a mined-out cavity — what a drill taps (cavity model)
	_draw_ground()
	falling.draw(self)
	for machine: MachineState in sim.machines:
		_draw_machine(machine)
	if bazaars != null:
		bazaars.draw(self)  # decorated stall + the block-by-block transform, over the wood frame
	if particles != null:
		particles.draw(self)
	_draw_mine_cracks()    # spider cracks on the block you're charge-mining (the felt friction)
	_draw_guide_targets()  # pulsing "do it HERE" ring/ghost for the current objective step
	_draw_aim()


## Spider cracks across the block currently being charge-mined, growing with the break progress (pushed
## via set_mine_progress) — so hand-mining reads as effortful work on a specific block, not an instant
## pop. Deterministic crack angles per cell (no RNG) + a darkening overlay so the rock visibly weakens.
func _draw_mine_cracks() -> void:
	if _mine_frac <= 0.001 or not sim.is_solid(_mine_cell):
		return
	var pos := Vector2(_mine_cell) * float(CELL)
	var center := pos + Vector2(CELL, CELL) * 0.5
	draw_rect(Rect2(pos, Vector2(CELL, CELL)), Color(0.0, 0.0, 0.0, 0.22 * _mine_frac))  # weakening shade
	var n: int = 2 + int(_mine_frac * 5.0)
	# Light fractures (with a dark underlay) so they read on ANY material in the dark underground — the
	# "this block is breaking" tell. Brighten + lengthen with the charge; a bright impact pip near full.
	var shadow := Color(0.0, 0.0, 0.0, 0.45 * _mine_frac)
	var crack := Color(0.92, 0.94, 1.0, 0.30 + 0.6 * _mine_frac)
	var base_ang: float = float(_mine_cell.x) * 0.7 + float(_mine_cell.y) * 1.3
	for i: int in n:
		var ang: float = TAU * float(i) / float(n) + base_ang
		var length: float = float(CELL) * (0.18 + 0.34 * _mine_frac)
		var elbow := center + Vector2(cos(ang), sin(ang)) * length * 0.5
		var tip := center + Vector2(cos(ang + 0.4), sin(ang + 0.4)) * length
		draw_line(center, elbow, shadow, 3.0)
		draw_line(elbow, tip, shadow, 3.0)
		draw_line(center, elbow, crack, 1.5)
		draw_line(elbow, tip, crack, 1.5)
	draw_circle(center, 1.5 + 2.0 * _mine_frac, Color(1.0, 0.96, 0.85, 0.5 * _mine_frac))  # impact pip


## Painter for the STATIC terrain layer (the _terrain LightLayer at z -10): background walls, terrain
## cells, the world border, and the smoothed surface — everything that changes only when you dig/place.
## Runs on a terrain-signature change, not per frame. It draws onto the layer it's handed (`ci`), NOT
## this node, so the heavy cell pass lands on a canvas the GPU can replay for free between digs.
func _paint_terrain(ci: CanvasItem) -> void:
	_draw_background(ci)  # sky above the surface; dark-dirt BACK WALL behind every dug-out cell + depth
	_draw_terrain(ci)     # (ends with the smoothed surface pass)
	ci.draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE).grow(1.0), Color(0.22, 0.23, 0.27), false, 2.0)


## A cheap dirty-key for the static terrain layers: it changes iff the DRAWN terrain could change —
## block count (dig/place), wall count, and the summed remaining ore (so the nugget-density "vein
## draining" read still updates as a drill eats a deposit, before the cell finally clears). RNG-free,
## O(deposits) per frame (a handful of cells), no false negatives for any in-play terrain mutation.
func _terrain_signature() -> Array:
	var dep: int = 0
	for v: int in sim.deposits.values():
		dep += int(v)
	return [sim.solid.size(), sim.wall.size(), dep]


## Draw the placed power conduits (docs/POWER.md): each tube is a copper segment with stubs to whatever
## it couples to (adjacent conduits, the generator feeding it, a machine drawing from it), and an inner
## CHANNEL that glows from dim to gold by the live power it carries — so a powered trunk reads as a bright
## line pouring down the shaft and a dead tube reads dark. The power level is the derived field, read-only.
func _draw_conduits() -> void:
	const COPPER := Color(0.46, 0.32, 0.20)
	const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	for cell: Variant in sim.conduit:
		var c: Vector2i = cell
		var center: Vector2 = Vector2(c) * float(CELL) + Vector2(CELL, CELL) * 0.5
		var lvl: float = _conduit_level(c)
		var glow: Color = Color(0.26, 0.22, 0.17).lerp(Color(1.0, 0.85, 0.40), lvl)
		var stubs: Array[Vector2] = []
		for d: Vector2i in DIRS:
			var nb: Vector2i = c + d
			if sim.has_conduit(nb) or sim.machine_at(nb) != null:
				stubs.append(center + Vector2(d) * float(CELL) * 0.5)
		# Copper casing: the centre node + a stub toward each coupling (default to a short vertical nub).
		draw_circle(center, 4.5, COPPER)
		if stubs.is_empty():
			stubs = [center + Vector2(0.0, float(CELL) * 0.5), center - Vector2(0.0, float(CELL) * 0.5)]
		for s: Vector2 in stubs:
			draw_line(center, s, COPPER, 7.0)
		# Inner channel glow over the same casing, lit by the power it carries.
		draw_circle(center, 2.2, glow)
		for s: Vector2 in stubs:
			draw_line(center, s, glow, 3.0)


## A conduit's power as a 0..1 fraction of tube capacity — the shared "how lit is this tube" reading the
## copper channel draw and the emitted light pool both key off (so the tube and its glow never disagree).
func _conduit_level(cell: Vector2i) -> float:
	return clampf(sim.power_at(cell) / FactorySim.CONDUIT_CAPACITY, 0.0, 1.0)


func _draw_terrain(ci: CanvasItem) -> void:
	for cell: Variant in sim.solid:
		var c: Vector2i = cell
		var pos := Vector2(c) * float(CELL)
		var def: MaterialDef = _material(sim.solid[c])
		# Sprite-ready: if a tile PNG exists for this material, draw it and skip the procedural fill
		# (still draw the surface cap/ramp pass below). Phase B of docs/ART_SPEC.md.
		var tile: Texture2D = Art.tex("tile_" + String(def.id))
		if tile != null:
			ci.draw_texture_rect(tile, Rect2(pos, Vector2(CELL, CELL)), false)
			continue
		var col: Color = _cell_fill_color(c, def)
		ci.draw_rect(Rect2(pos, Vector2(CELL, CELL)), col)
		if def.grain:
			# Rock grain — a darker pit + a lighter clod + a mid chip, deterministic per cell, so the
			# surface reads as textured rock rather than a colour swatch.
			var sp: Array[Vector2] = _cell_speckles(c, 3)
			ci.draw_rect(Rect2(pos + sp[0] - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), col.darkened(0.26))
			ci.draw_rect(Rect2(pos + sp[1] - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), col.lightened(0.12))
			ci.draw_rect(Rect2(pos + sp[2] - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), col.darkened(0.14))
		if def.has_nuggets():  # embedded specks so a vein reads as ore IN rock, not an orange block
			# Speck DENSITY tracks the remaining deposit (docs/MINING.md): a rich body sparkles thickly, a
			# nearly-drained one thins to a fleck — so a chunk's "set amount" READS, and a drill eating it
			# bottom-up visibly fades. (Cells with no pool entry = amount 1 = today's sparse look.)
			var richness: int = int(sim.deposits.get(c, 1))
			var nug_n: int = clampi(def.nugget_count + richness - 1, def.nugget_count, def.nugget_count + 7)
			for nug: Vector2 in _cell_speckles(c, nug_n):
				ci.draw_circle(pos + nug, 2.0, def.nugget_color)
				ci.draw_circle(pos + nug - Vector2(0.6, 0.6), 0.9, def.nugget_color.lightened(0.4))  # glint
		_draw_edge_ao(ci, c, pos)  # carved depth: ambient occlusion on faces that border open air
	_draw_terrain_surface(ci)


## The final fill colour for a terrain cell: the material's base, DARKENED with depth (the lower world
## reads as deeper, not one flat fill) then nudged by the deterministic tonal jitter (so a field of earth
## isn't ONE flat colour — the biggest flat-fill tell). Extracted so the surface RAMP wedge fills with the
## exact same colour as the cell body below it — the slope is the same earth mass, not a sticker on top.
func _cell_fill_color(c: Vector2i, def: MaterialDef) -> Color:
	var depth: float = clampf(float(c.y) / float(FactorySim.GRID_ROWS), 0.0, 1.0)
	var col: Color = def.base_color.darkened(depth * def.depth_darken)
	var j: float = _cell_jitter(c)
	return col.lightened(j) if j > 0.0 else col.darkened(-j)


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
func _draw_edge_ao(ci: CanvasItem, c: Vector2i, pos: Vector2) -> void:
	const STEPS: int = 3
	for i: int in STEPS:
		var a: float = 0.20 * (1.0 - float(i) / float(STEPS))
		var sh := Color(0.0, 0.0, 0.0, a)
		var o: float = float(i) * 2.0
		var s := 2.0
		if not sim.is_solid(c + Vector2i(0, -1)):  # top face exposed
			ci.draw_rect(Rect2(pos.x, pos.y + o, float(CELL), s), sh)
		if not sim.is_solid(c + Vector2i(0, 1)):   # bottom face exposed (a ceiling from below)
			ci.draw_rect(Rect2(pos.x, pos.y + float(CELL) - o - s, float(CELL), s), sh)
		if not sim.is_solid(c + Vector2i(-1, 0)):  # left face exposed
			ci.draw_rect(Rect2(pos.x + o, pos.y, s, float(CELL)), sh)
		if not sim.is_solid(c + Vector2i(1, 0)):   # right face exposed
			ci.draw_rect(Rect2(pos.x + float(CELL) - o - s, pos.y, s, float(CELL)), sh)


## A cell's MaterialDef via the registry, or a safe fallback so an unknown id still renders.
func _material(id: StringName) -> MaterialDef:
	return _materials.get(id, _materials.get(&"earth"))


## Public: a material's base colour by id (for the HUD minimap, which has no MaterialDef registry of
## its own). Decoupled — handed to the HUD as a Callable so it doesn't depend on this node's internals.
func material_color(id: StringName) -> Color:
	return _material(id).base_color


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
func _draw_terrain_surface(ci: CanvasItem) -> void:
	for col: int in range(FactorySim.GRID_COLS):
		var r: int = sim.surface_row(col)
		if r >= FactorySim.GRID_ROWS:
			continue  # empty column, no surface
		var cell := Vector2i(col, r)
		var def: MaterialDef = _material(sim.material_at(cell))
		var edge: Color = def.cap_color if def.has_cap() else def.base_color.lightened(0.18)
		var px := float(col * CELL)
		var py := float(r * CELL)
		var dir: int = sim.ramp_dir(col)
		if dir == 0:
			ci.draw_rect(Rect2(px, py, float(CELL), 4.0), edge)  # flat top: a capped lip
			continue
		# A 45° ramp wedge over the air corner. It's the SAME earth mass as the cell below, so it fills with
		# the cell's own body colour (not flat base_color) and carries a CONCAVE scoop: a per-vertex gradient
		# lights the top cap edge and pools shadow at the inner base corner, so the slope reads as a rounded,
		# carved earth shoulder instead of a flat triangular sticker. The WALKED hypotenuse (cap edge) stays
		# exactly on the 45° line the sim authority defines — only shading is added, never the geometry.
		var body: Color = _cell_fill_color(cell, def)
		var foot := Vector2(px, py) if dir == 1 else Vector2(px + CELL, py)         # the low (flat-side) corner
		var outer := Vector2(px + CELL, py) if dir == 1 else Vector2(px, py)        # bottom corner under the peak
		var peak := Vector2(px + CELL, py - CELL) if dir == 1 else Vector2(px, py - CELL)  # the raised cap corner
		# draw_polygon lets each vertex carry its own colour → the gradient. Cap corners lit, base pooled dark.
		var lit: Color = body.lightened(0.10)
		var pooled: Color = body.darkened(0.16)
		ci.draw_polygon(PackedVector2Array([foot, outer, peak]),
			PackedColorArray([pooled, pooled, lit]))
		# A second, tighter shadow triangle hugging the inner (base) corner deepens the concave scoop.
		var mid := (foot + outer) * 0.5
		ci.draw_polygon(PackedVector2Array([foot, mid, outer]),
			PackedColorArray([Color(0,0,0,0.14), Color(0,0,0,0.05), Color(0,0,0,0.14)]))
		# A couple of grain speckles so the wedge carries the same rock texture as the body (not a smooth face).
		# The wedge occupies the CELL-box ABOVE the cell top (py-CELL..py); speckles are placed there and kept
		# only if they fall under the diagonal (inside the triangle), so no fleck floats out over open air.
		if def.grain:
			var wedge_top := Vector2(px, py - CELL)
			for sp: Vector2 in _cell_speckles(cell, 2):
				if _in_ramp(sp, dir):
					ci.draw_rect(Rect2(wedge_top + sp - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), body.darkened(0.22))
		# The cap edge (grass/lip) rides the diagonal, with a soft dark liner just under it for a carved rim.
		ci.draw_line(foot, peak, edge.darkened(0.35), 4.0)
		ci.draw_line(foot, peak, edge, 3.0)


## True when a local point (0..CELL within the wedge's upper box) falls UNDER the 45° diagonal — i.e. inside
## the filled ramp triangle. Keeps grain speckles on the earth and off the open-air side. Mirrors the two
## ramp orientations: rising-right fills where x+y ≥ CELL; rising-left where y ≥ x.
func _in_ramp(local: Vector2, dir: int) -> bool:
	if dir == 1:
		return local.x + local.y >= float(CELL)
	return local.y >= local.x


## The current objective's WHERE-cell(s), drawn as a breathing beacon so a new player can't miss where to
## act. "act" = a pulsing amber ring + a bobbing down-arrow over the target (dig this / feed this forge);
## "ghost" = a pulsing green dashed cell showing where to place the next machine (cap the forge). Cosmetic.
func _draw_guide_targets() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_anim_time * 4.0)         # 0..1 breathing
	for t: Dictionary in _guide_targets:
		var cell: Vector2i = t["cell"]
		if not sim.in_bounds(cell):
			continue
		var pos := Vector2(cell) * float(CELL)
		var center := pos + Vector2(CELL, CELL) * 0.5
		if String(t.get("mode", "act")) == "ghost":
			var g := Color(0.45, 1.0, 0.55, 0.35 + 0.45 * pulse)
			var pad: float = 2.0 + 2.0 * pulse
			draw_rect(Rect2(pos + Vector2(pad, pad), Vector2(CELL - 2.0 * pad, CELL - 2.0 * pad)), g, false, 2.5)
		else:
			var ring := Color(1.0, 0.78, 0.30, 0.55 + 0.40 * pulse)
			var r: float = float(CELL) * (0.62 + 0.12 * pulse)
			draw_arc(center, r, 0.0, TAU, 28, ring, 2.5)
			draw_rect(Rect2(pos + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)), Color(ring.r, ring.g, ring.b, 0.10 + 0.10 * pulse))
		# A bobbing down-pointer above the cell so it's obvious even off-centre.
		var bob: float = -float(CELL) * (0.9 + 0.18 * pulse)
		var tip := center + Vector2(0.0, bob)
		var arrow := Color(1.0, 0.85, 0.40, 0.85)
		draw_colored_polygon([tip + Vector2(0, 7), tip + Vector2(-6, -4), tip + Vector2(6, -4)], arrow)


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
	if _ghost_def != null:
		# A brighter, more opaque tint so the ghost reads as a translucent PREVIEW on its own (4b critique).
		var ghost: Color = Visuals.machine_color(_ghost_def).lerp(Color.WHITE, 0.20)
		ghost.a = 0.55
		draw_rect(Rect2(pos + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)), ghost)
		Visuals.draw_machine_glyph(self, pos + Vector2(CELL, CELL) * 0.5, Visuals.machine_kind(_ghost_def), 1.0, false, 0.0)
	elif _ghost_material != &"":
		# Block-placement preview: a translucent material-tinted fill (the Terraria build cursor).
		var bg: Color = _material(_ghost_material).base_color
		bg.a = 0.55
		draw_rect(Rect2(pos + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)), bg)
	else:
		return  # the active hotbar item isn't placeable — nothing to ghost
	# A bright WHITE box hovering over the target cell (Terraria placement cursor); red when blocked.
	var border := Color(0.97, 0.98, 1.0, 0.95) if _aim_placeable else Color(0.95, 0.45, 0.40, 0.95)
	draw_rect(inner, border, false, 2.5)


## Sky + the REAL background WALL layer (sim.wall). Open sky fills the top; each wall cell paints its
## material colour (depth-darkened) BEHIND the terrain, so a dug-out cell reveals the carved-room backing.
func _draw_background(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), SKY_COLOR)
	for cell_v: Variant in sim.wall:
		var c: Vector2i = cell_v
		var def: MaterialDef = _material(sim.wall[c])
		var wpos := Vector2(c) * float(CELL)
		# Sprite-ready: a tile_<wall-id>.png (e.g. tile_dirt_wall.png) replaces the flat fill.
		var wtex: Texture2D = Art.tex("tile_" + String(def.id))
		if wtex != null:
			ci.draw_texture_rect(wtex, Rect2(wpos, Vector2(CELL, CELL)), false)
			continue
		var depth: float = clampf(float(c.y) / float(FactorySim.GRID_ROWS), 0.0, 1.0)
		ci.draw_rect(Rect2(wpos, Vector2(CELL, CELL)), def.base_color.darkened(depth * def.depth_darken))


## Exposed wall DEPOSITS (docs/MINING.md, cavity model): once you hand-mine an ore block, the leftover
## richness glitters in the open cavity — a recessed cluster of ore nuggets a Drill taps. Speck density
## tracks the remaining yield, so the deposit visibly thins as a drill eats it. Drawn UNDER machines (the
## drill sits over it) on the dynamic layer (it changes each drill cycle). A warm glint is added in the lights.
func _draw_ore_deposits() -> void:
	for cell_v: Variant in sim.ore_deposits:
		var c: Vector2i = cell_v
		var remaining: int = int(sim.ore_deposits[c])
		var item: StringName = StringName(sim.deposit_item.get(c, &"ore"))
		var ndef: MaterialDef = _material(item)
		var nug: Color = ndef.nugget_color if ndef.has_nuggets() else Visuals.item_color(item)
		var pos := Vector2(c) * float(CELL)
		draw_rect(Rect2(pos + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), Color(0.05, 0.05, 0.06, 0.55))  # recessed backing
		var n: int = clampi(2 + remaining / 3, 3, 12)
		for p: Vector2 in _cell_speckles(c, n):
			draw_circle(pos + p, 2.4, nug)
			draw_circle(pos + p - Vector2(0.7, 0.7), 1.0, nug.lightened(0.55))  # glint


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
				Visuals.draw_item(self, p, 9.0, item)  # sprite-ready (item_<id>.png) or flat chip
				idx += 1


## A machine: a riveted CASING + its animated type glyph (shared Visuals) + a held-count badge + the
## recipe progress bar. The glyph spins/breathes while the machine is working.
## Is a machine visibly "working" this tick — behavior-aware, so the glyph animates truthfully: a
## generator burns only while fueled, a lift stirs while powered or holding goods, others while a cycle
## runs or they hold product. Shared by the glyph draw and the light pool so they never disagree.
func _machine_active(machine: MachineState) -> bool:
	match machine.def.behavior:
		&"generator":
			return machine.fuel > 0
		&"lift":
			return machine.power_factor > 0.05 or not machine.input_buffer.is_empty()
		_:
			return _held(machine) > 0 or machine.progress > 0.0


func _draw_machine(machine: MachineState) -> void:
	var pos: Vector2 = Vector2(machine.cell) * float(CELL)
	var recipe: RecipeDef = machine.def.recipe
	var center: Vector2 = pos + Vector2(CELL, CELL) * 0.5
	# Contact shadow — grounds the machine on the floor it sits on.
	draw_set_transform(pos + Vector2(float(CELL) * 0.5, float(CELL) - 1.0), 0.0, Vector2(1.0, 0.26))
	draw_circle(Vector2.ZERO, float(CELL) * 0.46, Color(0.0, 0.0, 0.0, 0.30))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Sprite-ready: a machine_<id>.png replaces the code-drawn casing+glyph (docs/ART_SPEC.md, Phase A);
	# the badge / progress bar / I/O ports below still overlay it. Absent → today's primitive look.
	var spr: Texture2D = Art.tex("machine_" + String(machine.def.id))
	if spr != null:
		draw_texture_rect(spr, Rect2(pos, Vector2(CELL, CELL)), false)
	else:
		var body := Rect2(pos + Vector2(1.0, 1.0), Vector2(CELL - 2.0, CELL - 2.0))
		draw_rect(body, Visuals.machine_color(machine.def))
		draw_rect(body, Color(0.04, 0.04, 0.06, 0.8), false, 1.5)  # darker inset casing
		for corner: Vector2 in [Vector2(4, 4), Vector2(CELL - 4, 4), Vector2(4, CELL - 4),
				Vector2(CELL - 4, CELL - 4)]:
			draw_circle(pos + corner, 1.0, Color(0.0, 0.0, 0.0, 0.5))  # bolts
		# A machine reads as ALIVE while it's working (behavior-aware), and a powered LIFT marches faster.
		var active: bool = _machine_active(machine)
		var clock: float = _anim_time
		if machine.def.behavior == &"lift":
			clock = _anim_time * (1.0 + machine.power_factor)   # the chevrons surge when powered
		Visuals.draw_machine_glyph(self, center, Visuals.machine_kind(machine.def), 1.0, active, clock)

	_draw_machine_label(machine, pos)

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

	_draw_machine_io(machine, pos)


## A small NAME plate centred just above the machine (FORGE / DRILL / LIFT / GENERATOR), so a new player
## can read what each box IS at a glance — the direct fix for "which one is the forge?". Dark pill backing
## keeps it legible over any terrain; uppercased + tight so it reads as a label, not prose. Pure cosmetic.
func _draw_machine_label(machine: MachineState, pos: Vector2) -> void:
	var name: String = machine.def.display_name.to_upper()
	if name.is_empty():
		return
	var fs: int = 8
	var w: float = _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var cx: float = pos.x + float(CELL) * 0.5
	var top: float = pos.y - 11.0
	draw_rect(Rect2(cx - w * 0.5 - 3.0, top, w + 6.0, 11.0), Color(0.04, 0.05, 0.08, 0.82))
	draw_string(_font, Vector2(cx - w * 0.5, top + 8.5), name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.86, 0.90, 0.98))


## Small item-tinted PORTS on a machine's edges: where it EATS (input mouth, top, points IN) and where
## it SPITS (output spout, in the flow direction — down for a recipe-runner/source, down+right for a
## splitter, up for a lift). Tinted by the item so you learn "orange goes in here, yellow comes out
## there" at a glance — the in-world half of the I/O affordances (VIBE_GAP #8). Pure cosmetic.
func _draw_machine_io(machine: MachineState, pos: Vector2) -> void:
	var recipe: RecipeDef = machine.def.recipe
	var c: float = float(CELL)
	if recipe != null and not recipe.inputs.is_empty():
		var in_item: StringName = recipe.inputs.keys()[0]
		_port(pos + Vector2(c * 0.5, 0.0), Vector2(0, 1), Visuals.item_color(in_item))   # mouth: points in
	var out_col := Color(0.80, 0.86, 0.94)                                                # neutral "routes"
	if recipe != null and not recipe.outputs.is_empty():
		out_col = Visuals.item_color(recipe.outputs.keys()[0])
	match machine.def.behavior:
		&"lift":
			_port(pos + Vector2(c * 0.5, c), Vector2(0, -1), Color(0.5, 1.0, 0.92))       # spouts UP
		&"splitter":
			_port(pos + Vector2(c * 0.5, c), Vector2(0, 1), out_col)                      # down
			_port(pos + Vector2(c, c * 0.5), Vector2(1, 0), out_col)                      # + right
		_:
			_port(pos + Vector2(c * 0.5, c), Vector2(0, 1), out_col)                      # spouts down


## One little triangular port: base sits on the casing edge at `base`, apex juts out by `dir`.
func _port(base: Vector2, dir: Vector2, color: Color) -> void:
	var size: float = 4.5
	var perp := Vector2(dir.y, -dir.x) * size
	var apex := base + dir * (size + 2.5)
	var p1 := base + perp
	var p2 := base - perp
	draw_colored_polygon(PackedVector2Array([apex, p1, p2]), Color(color.r, color.g, color.b, 0.95))
	draw_line(p1, p2, Color(0.04, 0.04, 0.06, 0.55), 1.0)


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
		var flick: float = 0.55 + 0.03 * sin(_anim_time * 11.0) + 0.02 * sin(_anim_time * 27.0)
		_draw_glow(layer, player.position + Vector2(f * float(CELL) * 0.7, -float(CELL) * 0.2),
			LAMP_RADIUS, LAMP_COLOR, flick)
		_draw_glow(layer, player.position, float(CELL) * 1.4, LAMP_COLOR, 0.12)  # faint close body glow
	for machine: MachineState in sim.machines:
		var kind: String = Visuals.machine_kind(machine.def)
		var col: Color = Color(1.0, 0.58, 0.30)            # furnace ember (warm)
		var pulse: float = 0.5 + 0.1 * sin(_anim_time * 3.0 + float(machine.cell.x))  # a sign of life
		if kind == "generator":
			col = Color(1.0, 0.72, 0.30)                   # warm coal-burner glow
			# Breathes while fueled, goes DARK when it runs dry — the "is it making power?" read.
			pulse = (0.55 + 0.2 * sin(_anim_time * 6.5)) if machine.fuel > 0 else 0.0
		elif kind == "lift":
			col = Color(0.5, 1.0, 0.92)                    # lift teal (echoes the updraft motes)
			pulse *= 0.4 + 0.6 * machine.power_factor      # brighter the more power it's drawing
		elif kind != "furnace":
			col = Color(0.55, 0.82, 0.98)                  # cool machine glow
		if pulse > 0.0:
			_draw_glow(layer, _cell_center(machine.cell), float(CELL) * 2.3, col, pulse)
	# Powered conduits EMIT light, so a live trunk pours a column of warm glow down the dark shaft
	# (the in-world tube is drawn under the veil; this is what makes its power read from across the room).
	for cell: Variant in sim.conduit:
		var lvl: float = _conduit_level(cell)
		if lvl > 0.04:
			_draw_glow(layer, _cell_center(cell), float(CELL) * (0.9 + 0.7 * lvl), Color(1.0, 0.82, 0.42), lvl * 0.5)
	# Exposed ORE deposits glint warmly in the dark — the "shiny vein revealed" read (cavity model). Coal
	# deposits stay dark (no glow) — they read as black seams, not gold.
	for cell_v: Variant in sim.ore_deposits:
		if StringName(sim.deposit_item.get(cell_v, &"ore")) == &"ore":
			_draw_glow(layer, _cell_center(cell_v), float(CELL) * 1.15, Color(1.0, 0.62, 0.32), 0.22)
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
