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
const SKY_COLOR := Color(0.09, 0.11, 0.16)         ## open air ABOVE the surface (the gradient's mid tone)
## PARALLAX ridgeline layers (FABLE_50 #10): factor = how world-locked (1 = terrain speed, 0 = pinned
## to the camera — smaller reads further away), drop = px below the horizon band the ridge crests sit,
## amp = crest height. Far hills are lighter (atmospheric haze), near hills darker.
const RIDGES: Array[Dictionary] = [
	{"factor": 0.22, "drop": 150.0, "amp": 150.0, "freq": 0.006, "color": Color(0.145, 0.165, 0.225)},
	{"factor": 0.42, "drop": 55.0, "amp": 110.0, "freq": 0.010, "color": Color(0.062, 0.072, 0.112)},
]

## --- Lighting (the mood lever) -----------------------------------------------------------------
## The model is SKYLIGHT + ambient, not a depth gradient: the underground is near-black EVERYWHERE,
## and daylight only reaches where open air connects it to the sky. Sky floods DOWN each column's open
## air, attenuating with depth, and is BLOCKED by the first solid rock — so a dug shaft pours daylight
## down (it follows your digging), the dirt beside it stays dark, and an enclosed cave is pitch black
## until you bring a lamp. Warm artificial LIGHT pools (head-lamp, forge embers, machine glow) are the
## only light in the deep — your claimed territory in the black. (Recomputed when terrain changes.)
## Tuned to the MEASURED world (LayeredWorldGen surfaces sit at rows ~17-23): full daylight down to the
## valley floor, then sunlight penetrates ~a dozen tiles into a dug shaft before the dark takes over.
## (The old 5/10 was tuned for the 40-row world — the grown world's surface sat PAST where daylight died,
## rendering the whole game in permanent dusk.)
const SURFACE_LINE: int = 22                        ## reference daylight row; sky attenuates with depth past it
const SKY_REACH: int = 12                           ## tiles of open air sunlight reaches before going dark
const SKY_FADE: int = 3                             ## tiles of shallow light-scatter just under the surface
const AMBIENT_DARK: float = 0.62                    ## underground ambient — DIM but visible (Terraria), not
                                                   ## pitch black. You can read the terrain everywhere; light
                                                   ## sources add warmth + clarity rather than being the ONLY way to see.
const SHADOW_COLOR := Color(0.05, 0.06, 0.10)       ## the cool blue-black the underworld sits in
const LAMP_COLOR := Color(1.0, 0.90, 0.66)          ## the miner's warm head-lamp
const LAMP_RADIUS: float = CELL * 4.0               ## a focused warm pool, not a screen-filling white disc
const LAMP_LEAD: float = CELL * 1.9                 ## how far the beam pool leads toward the aim (#44)

## --- Day/night (FABLE_50 #29, cosmetic-first) ---------------------------------------------------
## A slow surface rhythm off the cosmetic clock: the backdrop sky, the skylight veil, the godrays and
## the bird all breathe with it; the UNDERGROUND is untouched (no sun down there anyway — its ambient
## is the same by day or night, so the moody deep stays the moody deep). At night the surface dims
## toward (not into) the underground ambient — moonlight, not a cave — which makes placed torches
## matter above ground too. Purely representational: the sim never reads any of it. Later this clock
## is the hook for a surface threat rhythm (the backlog's note), which WILL want sim state — not this.
const DAY_SECONDS: float = 480.0                    ## one full cycle (8 min — long enough to live in)
const DAY_START_PHASE: float = 0.10                 ## boot mid-morning (fixtures + first sessions read day)
const NIGHT_DARK: float = 0.40                      ## how dark the night sky veils the surface (< AMBIENT_DARK)


## 0..1 through the cycle: 0.00-0.40 day · 0.40-0.55 dusk · 0.55-0.90 night · 0.90-1.00 dawn.
func day_phase() -> float:
	return fmod(_anim_time / DAY_SECONDS + DAY_START_PHASE, 1.0)


## How much daylight the sky holds right now: 1 at noon, 0 at deep night, smooth through dusk/dawn.
func daylight() -> float:
	var p: float = day_phase()
	if p < 0.40:
		return 1.0
	if p < 0.55:
		return 1.0 - smoothstep(0.40, 0.55, p)
	if p < 0.90:
		return 0.0
	return smoothstep(0.90, 1.0, p)

var sim: FactorySim
var player: Player
var falling: FallingItems
var particles: Particles                              ## cosmetic juice layer (set by MainView), drawn on top

var _font: Font = ThemeDB.fallback_font
var _anim_time: float = 0.0                          ## free-running cosmetic clock (never feeds the sim)
var _materials: Dictionary = {}                      ## id -> MaterialDef (world-engine viz registry)
## MACHINE CONSTRUCT ANIMATION (FABLE_NEXT_50 #9): cell -> elapsed seconds since placement. MainView
## pokes note_machine_built() on a real build (never on boot/load — pre-existing machines don't animate,
## the note_dig pattern). A short one-shot assemble overlay (flash + rising scan + bracket snap) plays.
var _construct: Dictionary = {}
const CONSTRUCT_DUR: float = 0.38
## MINE CRUMBLE (FABLE_NEXT_50 #18): a just-mined block shatters into four chunks that fly apart, fall
## and fade instead of popping out of existence — the removed rock leaves with weight. MainView pokes
## note_mined() on a real dig (the note_dig discipline). [{pos, col, age}], capped so a fast dig can't
## pile up unbounded.
var _crumble: Array[Dictionary] = []
const CRUMBLE_DUR: float = 0.24
const CRUMBLE_MAX: int = 48

# Pushed by MainView each frame (the bits the renderer can't derive from the sim alone).
var _aim: Vector2i = Vector2i(-99, -99)
var _aim_in_reach: bool = false
var _aim_placeable: bool = false
var _lamp_offset: Vector2 = Vector2.ZERO   ## eased head→beam-pool offset (the aim-following lamp, #44)
var lamp_color: Color = LAMP_COLOR         ## the picked lamp TINT (#45 — set from the title screen)
var _ghost_def: MachineDef = null
var _ghost_material: StringName = &""                ## a building material selected for block placement
var _guide_targets: Array[Dictionary] = []           ## current objective's WHERE-cells (pushed by MainView)
var _mine_cell: Vector2i = Vector2i(-999, -999)       ## block being charge-mined (cracks drawn on it; pushed by MainView)
var _mine_frac: float = 0.0                           ## 0..1 break-charge of that block — the felt-friction read
var _dig_marks: Dictionary = {}                       ## the dig PLAN (live ref from MainView) — hatched overlay
var _ping_world: Vector2 = Vector2.INF                ## the map-click PING (INF = none) — in-world beacon
var _daylight_step: int = -1                          ## quantized daylight — veil repaint trigger (#29)
## THE SCANNER pulse (FABLE_50 #27, pushed by try_scan): origin + age drive an expanding wavefront;
## each echo ({pos, dist, material}) lights up as the front passes its true distance, lingers, fades.
const SCAN_WAVE_SPEED: float = 260.0                  ## wavefront px/s — the controller staggers audio off it
const SCAN_ECHO_LINGER: float = 4.0                   ## seconds an echo stays readable after its hit
var _scan_origin: Vector2 = Vector2.INF
var _scan_age: float = -1.0                           ## -1 = no scan live
var _scan_echoes: Array[Dictionary] = []
var _scan_range: float = 0.0
var bazaars: Bazaars = null                          ## the Bazaar view layer (set by MainView); may be null
var _seal_rows: Array[int] = []                       ## world rows holding THE SEAL (lazy-scanned for its pulse)
var _seal_rows_scanned: bool = false

## STATIC terrain/walls/surface, split into a GRID of chunk canvases so a dig repaints only the affected
## chunk(s) (~64 cells) instead of the whole 7700-cell world (the ~300ms freeze). Each chunk owns a
## CHUNK×CHUNK cell block; sim.terrain_dirty tells us which to repaint each frame.
const CHUNK: int = 8                                  ## cells per chunk side (8×8 = 64-cell repaint per dig)
var _chunks: Array[LightLayer] = []                  ## row-major grid, size _chunk_cols × _chunk_rows
var _chunk_cols: int = 0
var _chunk_rows: int = 0
var _back: LightLayer      ## the parallax backdrop (sky gradient + ridgelines + clouds), z -20
var _dark: LightLayer
## THE LIGHTMAP VEIL (FABLE_50 #17): the darkness is a small texture — ONE TEXEL PER CELL (RGB =
## the shadow colour, zone-tinted; A = darkness) — stretched over the whole world with LINEAR
## filtering, so light grades smoothly in EVERY direction instead of stepping cell to cell. The
## skylight/ambient BASE bakes only when terrain or the daylight step changes (_veil_dirty); each
## frame the base is copied and the live light sources CUT holes in it (lamp/torches/machines/
## conduits/falling drops), so where light falls the veil OPENS and the world shows its true
## colours under the additive warmth — light reveals, not just tints.
var _veil_img: Image
var _veil_tex: ImageTexture
var _veil_base: PackedByteArray
var _veil_dirty: bool = true
var _lights: LightLayer
var _haze: LightLayer      ## the shared DISTORTION pass (#20) — heat shimmer now, water/L4 later
var _leaf_cells: Array[Vector2i] = []   ## cached canopy cells (surface life #15); rebuilt on terrain change
var _leaf_cache_dirty: bool = true
var _glow_tex: GradientTexture2D


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
		"res://src/data/materials/sealrock.tres",
		"res://src/data/materials/iron.tres",
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
	_chunk_cols = ceili(float(FactorySim.GRID_COLS) / float(CHUNK))
	_chunk_rows = ceili(float(FactorySim.GRID_ROWS) / float(CHUNK))
	for cy: int in _chunk_rows:
		for cx: int in _chunk_cols:
			var rect := Rect2i(cx * CHUNK, cy * CHUNK, CHUNK, CHUNK)
			var chunk := LightLayer.new()
			chunk.setup(-10, false, _paint_terrain_chunk.bind(rect))  # painter(ci, rect) draws only this block
			add_child(chunk)
			_chunks.append(chunk)
	# The PARALLAX BACKDROP (FABLE_50 #10) sits BELOW the terrain chunks (z -20), repainted per frame:
	# a vertical sky gradient + two drifting ridgelines + slow clouds. The chunk background pass no
	# longer fills opaque sky, so the vista shows wherever no wall backs a cell (above ground); the
	# walls hide it underground for free.
	_back = LightLayer.new()
	_back.setup(-20, false, _paint_backdrop)
	add_child(_back)
	# Two world-space canvases ABOVE this renderer's draw — the skylight/darkness veil, then light pools.
	_glow_tex = _make_glow_texture()
	_dark = LightLayer.new()
	_dark.setup(50, false, _paint_darkness)
	# The lightmap veil (#17): the darkness texture is tiny (one texel per cell) and the LINEAR
	# filter on the stretch is what turns per-cell values into smooth gradients across the world.
	_dark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_dark.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_veil_img = Image.create(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, false, Image.FORMAT_RGBA8)
	_veil_tex = ImageTexture.create_from_image(_veil_img)
	add_child(_dark)
	_lights = LightLayer.new()
	_lights.setup(51, true, _paint_lights)
	add_child(_lights)
	# THE DISTORTION PASS (FABLE_50 #20): one shared screen-warp shader; consumers draw masked quads.
	# Proven here on machine heat-haze. Sits ABOVE the world + veil but UNDER the additive light pools
	# (hot air bends the scene, lamplight stays crisp).
	_haze = LightLayer.new()
	_haze.setup(46, false, _paint_heat_haze)
	var haze_mat := ShaderMaterial.new()
	haze_mat.shader = load("res://scenes/heat_haze.gdshader")
	_haze.material = haze_mat
	add_child(_haze)
	for chunk: LightLayer in _chunks:
		chunk.queue_redraw()  # initial full paint (once); thereafter only dirtied chunks repaint
	sim.terrain_dirty.clear()  # drop any dirt from world-seeding — the initial paint above already covers it
	_dark.queue_redraw()  # the veil's ONE draw command (the stretched lightmap); content updates via the texture


## Full-world repaint, for when the terrain changed WHOLESALE under the retained caches (loading a
## save). Requeues every terrain chunk + the skylight veil and drops the lazy seal-row cache. The
## incremental terrain_dirty path stays the per-dig fast lane; this is the load-time reset.
func repaint_world() -> void:
	for chunk: LightLayer in _chunks:
		chunk.queue_redraw()
	_veil_dirty = true
	sim.terrain_dirty.clear()
	_seal_rows.clear()
	_seal_rows_scanned = false
	_leaf_cache_dirty = true


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


## The controller hands over its dig-plan dict ONCE as a live reference (cell -> true); the overlay
## tracks paints/clears without a per-frame push. Read-only here — the plan is the controller's.
func set_dig_marks(marks: Dictionary) -> void:
	_dig_marks = marks


## The player's PING (FABLE_50 #34 — set by clicking the minimap; Vector2.INF = none): drawn in-world
## as a pulsing beacon so "the spot I marked on the map" is findable when you walk up to it.
func set_ping(world: Vector2) -> void:
	_ping_world = world


## Begin a SONAR pulse (FABLE_50 #27): the controller computed the echoes (a pure deposits query);
## from here the wavefront + echo lifecycle are cosmetic clockwork.
func start_scan(origin: Vector2, echoes: Array[Dictionary]) -> void:
	_scan_origin = origin
	_scan_age = 0.0
	_scan_echoes = echoes
	_scan_range = MainView.SCAN_RANGE_CELLS * float(CELL)


func _process(delta: float) -> void:
	_anim_time += delta
	if not _construct.is_empty():                        # age the assemble overlays; drop the finished ones
		for cell: Vector2i in _construct.keys():
			var e: float = float(_construct[cell]) + delta
			if e >= CONSTRUCT_DUR:
				_construct.erase(cell)
			else:
				_construct[cell] = e
	if not _crumble.is_empty():                          # age the mine-crumbles; retire the spent ones
		for i: int in range(_crumble.size() - 1, -1, -1):
			_crumble[i]["age"] = float(_crumble[i]["age"]) + delta
			if float(_crumble[i]["age"]) >= CRUMBLE_DUR:
				_crumble.remove_at(i)
	if _scan_age >= 0.0:
		_scan_age += delta
		if _scan_age > _scan_range / SCAN_WAVE_SPEED + SCAN_ECHO_LINGER:
			_scan_age = -1.0    # pulse spent, every echo faded — the scan is over
			_scan_echoes = []
	# The head-lamp FOLLOWS THE AIM (FABLE_50 #44): the pool leads from the head toward the cursor
	# (capped), eased so a mouse flick swings the beam like a worn lamp, not a snapped spotlight.
	# Cursor on/next to the body → fall back to plain facing so the light never collapses onto you.
	if player != null:
		var head: Vector2 = player.position + Vector2(0.0, -Player.HEIGHT * 0.30)
		var to_aim: Vector2 = _cell_center(_aim) - head
		var target: Vector2 = Vector2(float(player.facing) * float(CELL) * 0.7, -float(CELL) * 0.2)
		if to_aim.length() > float(CELL) * 0.9:
			target = to_aim.limit_length(LAMP_LEAD)
		_lamp_offset = _lamp_offset.lerp(target, 1.0 - exp(-9.0 * delta))
	queue_redraw()              # falling items, machine animation + the aim cursor move every frame
	_update_veil()              # the lightmap veil (#17): rebake the base if dirty, re-cut the live lights
	if _lights != null:
		_lights.queue_redraw()  # the lamp follows the body + machines shimmer
	if _haze != null:
		_haze.queue_redraw()    # working furnaces convect (#20 — the shader's TIME drives the ripple)
	if _back != null:
		_back.queue_redraw()    # the parallax vista slides against the camera (a few polygons — cheap)
	# The day/night veil (#29): the skylight darkness is repainted only on terrain change, so the slow
	# sky cycle nudges it by quantized steps — ~one cheap repaint every few seconds through dusk/dawn,
	# none at all mid-day or deep night (the step only moves while the light is actually changing).
	var dstep: int = int(daylight() * 24.0)
	if dstep != _daylight_step:
		_daylight_step = dstep
		_veil_dirty = true
	# Terrain depends on the dug world, NOT the cosmetic clock. Repaint ONLY the chunks whose cells actually
	# changed this frame (sim.terrain_dirty) — a dig rebuilds ~64 cells, not the whole 7700-cell world (the
	# old ~300ms freeze). A changed cell also dirties its 4 neighbour chunks, since edge-AO + the surface cap
	# on a neighbouring cell read across the boundary. Between changes each chunk's retained buffer is replayed.
	if not sim.terrain_dirty.is_empty():
		var dirty: Dictionary = {}                    # chunk index -> true (dedup)
		for cell: Vector2i in sim.terrain_dirty:
			# All 8 neighbours + self: edge-AO/caps read orthogonally, and the autotile chamfer/fillet
			# passes (#9) read across CORNERS too — a dig at a chunk corner must repaint the diagonal chunk.
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var idx: int = _chunk_index(cell + Vector2i(dx, dy))
					if idx >= 0:
						dirty[idx] = true
		for idx: int in dirty:
			_chunks[idx].queue_redraw()
		sim.terrain_dirty.clear()
		_leaf_cache_dirty = true   # a felled tree stops shedding leaves
		# The skylight base also depends on the surface line the dig may have moved — rebake it.
		_veil_dirty = true


## The row-major index of the chunk owning `cell`, or -1 if the cell is out of the world.
func _chunk_index(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= FactorySim.GRID_COLS or cell.y >= FactorySim.GRID_ROWS:
		return -1
	return (cell.y / CHUNK) * _chunk_cols + (cell.x / CHUNK)


# --- draw sequence (WORLD space; the Camera2D provides the view transform) ----

func _draw() -> void:
	# Terrain + background walls + the smoothed surface are STATIC: drawn by the chunked terrain canvases
	# (below this, z -10) and repainted only on the DIG'd chunk. This per-frame pass draws ONLY the live/
	# sparse content (machines, items, conduits, cursor) — no full-world cell loop.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE).grow(1.0), Color(0.22, 0.23, 0.27), false, 2.0)  # world border
	_draw_crumble()   # a just-mined block shattering away at the terrain layer (#18)
	_draw_drop_paths()
	_draw_ore_glints()  # veins glitter in the dark — discovery reads from across a cavern
	_draw_updrafts()  # rising shimmer in each lift's shaft, so "this column lifts UP" reads
	_draw_conduits()  # power tubes (copper, with a channel that glows by the live power level)
	_draw_power_pulses()  # bright beads flowing DOWN the live network — energy visibly moving (#19)
	_draw_ropes()     # placed climb-ropes hanging down their shafts (behind machines + the body)
	_draw_torches()   # mounted torches guttering on the walls — placed light, claimed territory
	_draw_saplings()  # planted sprouts growing on the sim's tick (#38 — renewable wood)
	_draw_ground()
	_draw_surface_life()  # drifting leaves off the canopies + the occasional bird — the surface breathes
	falling.draw(self)
	for machine: MachineState in sim.machines:
		_draw_machine(machine)
	if bazaars != null:
		bazaars.draw(self)  # decorated stall + the block-by-block transform, over the wood frame
	if particles != null:
		particles.draw(self)
	_draw_dig_marks()      # the painted dig PLAN — corner-bracketed cells waiting for the pick
	_draw_mine_cracks()    # spider cracks on the block you're charge-mining (the felt friction)
	_draw_guide_targets()  # pulsing "do it HERE" ring/ghost for the current objective step
	_draw_ping()           # the map-click beacon — the spot you marked, findable on foot
	_draw_scan()           # the sonar pulse + vein echoes (the scanner's whole voice)
	_draw_aim()


## THE SONAR (FABLE_50 #27): an expanding wavefront ring from the body, and — as it passes each vein's
## true distance — an ECHO: a pip + expanding ring in the vein's own nugget colour, glowing THROUGH the
## rock, lingering a few seconds then gone. Prospecting, not a map reveal: transient, local, and it
## only ever shows deposits that were in range when you fired.
func _draw_scan() -> void:
	if _scan_age < 0.0:
		return
	var front: float = _scan_age * SCAN_WAVE_SPEED
	if front <= _scan_range:                                # the pulse itself, while it still travels
		var edge: float = clampf(1.0 - front / _scan_range, 0.0, 1.0)
		var wc := Color(0.45, 0.95, 1.0, 0.10 + 0.30 * edge)
		draw_arc(_scan_origin, front, 0.0, TAU, 64, wc, 2.0)
		draw_arc(_scan_origin, maxf(front - 9.0, 0.0), 0.0, TAU, 64,
			Color(wc.r, wc.g, wc.b, wc.a * 0.4), 1.2)
	for e: Dictionary in _scan_echoes:
		var since_hit: float = _scan_age - float(e["dist"]) / SCAN_WAVE_SPEED
		if since_hit < 0.0 or since_hit > SCAN_ECHO_LINGER:
			continue
		var fade: float = 1.0 - since_hit / SCAN_ECHO_LINGER
		var pos: Vector2 = e["pos"]
		var col: Color = _material(e["material"] as StringName).nugget_color
		var ring: float = fmod(since_hit, 1.1) / 1.1        # each echo keeps re-ringing as it fades
		draw_arc(pos, 5.0 + ring * 16.0, 0.0, TAU, 20,
			Color(col.r, col.g, col.b, 0.9 * fade * (1.0 - ring)), 2.0)
		# The return itself: a diamond pip big enough to read in DAYLIGHT (the additive glow only
		# carries it in the dark), white-cored so it reads "signal", not "another ore fleck".
		var r: float = 4.5 + 1.0 * fade
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0.0, -r), pos + Vector2(r, 0.0),
			pos + Vector2(0.0, r), pos + Vector2(-r, 0.0)]),
			Color(col.r, col.g, col.b, 0.55 + 0.4 * fade))
		draw_circle(pos, 1.6, Color(1.0, 1.0, 1.0, 0.55 + 0.4 * fade))


## The in-world PING beacon (FABLE_50 #34): a cyan pin bobbing over the marked spot + an expanding
## sonar ring, so the bookmark you clicked on the map is visible from across a cavern when you arrive.
func _draw_ping() -> void:
	if _ping_world.x == INF:
		return
	var ring: float = fmod(_anim_time, 1.6) / 1.6
	var col := Color(0.45, 0.95, 1.0)
	draw_arc(_ping_world, 6.0 + ring * 26.0, 0.0, TAU, 28,
		Color(col.r, col.g, col.b, 0.5 * (1.0 - ring)), 2.0)
	var bob: float = sin(_anim_time * 3.0) * 2.5
	var tip: Vector2 = _ping_world + Vector2(0.0, -4.0 + bob)
	draw_line(tip, tip + Vector2(0.0, -10.0), Color(col.r, col.g, col.b, 0.85), 1.5)
	var head: Vector2 = tip + Vector2(0.0, -13.0)
	draw_colored_polygon(PackedVector2Array([head + Vector2(0.0, -4.5), head + Vector2(4.0, 0.0),
		head + Vector2(0.0, 4.5), head + Vector2(-4.0, 0.0)]), col)
	draw_circle(head, 1.4, Color(0.06, 0.10, 0.14))


## The painted dig PLAN (FABLE_50 #24): each marked cell wears amber corner brackets + a whisper of
## fill, breathing gently so the plan reads as "queued for the pick", quieter than the aim cursor and
## the objective rings. Marks are the controller's live dict; stale entries are its job to prune.
func _draw_dig_marks() -> void:
	if _dig_marks.is_empty():
		return
	var view: Rect2 = (get_canvas_transform().affine_inverse() * get_viewport_rect()).grow(float(CELL))
	var pulse: float = 0.65 + 0.35 * sin(_anim_time * 2.6)
	var edge := Color(0.95, 0.72, 0.30, 0.30 + 0.25 * pulse)
	var fill := Color(0.95, 0.72, 0.30, 0.05)
	var arm: float = float(CELL) * 0.28
	for key: Variant in _dig_marks:
		var pos := Vector2(key as Vector2i) * float(CELL)
		if not view.has_point(pos):
			continue
		draw_rect(Rect2(pos + Vector2.ONE * 2.0, Vector2.ONE * float(CELL - 4)), fill)
		for corner: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2.ONE]:
			var c: Vector2 = pos + corner * float(CELL) + (Vector2.ONE * 0.5 - corner) * 4.0
			var dir := Vector2.ONE * 0.5 - corner   # points inward
			draw_line(c, c + Vector2(signf(dir.x) * arm, 0.0), edge, 1.5)
			draw_line(c, c + Vector2(0.0, signf(dir.y) * arm), edge, 1.5)


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


## Living veins (FABLE_50 #19): one fleck per ore cell FLARES briefly on a slow per-cell staggered
## schedule, so a vein glitters in the lamplight and discovery reads from across a dark cavern. Walks
## sim.deposits (the sparse seeded-vein index — never the whole world) clipped to the camera view.
## THE SEAL gets its own tell: a slow faint violet breath along its two rows (lazy row scan). Pure
## cosmetics on the free-running clock; the sim never sees any of it.
## SURFACE LIFE (FABLE_50 #15): the top of the world stops reading static. Each canopy cell sheds a
## drifting leaf on its own long cycle (stateless — position is a pure function of the cosmetic clock,
## the ore-glint trick), and every so often a bird crosses the sky. Zero allocations, zero sim reads
## beyond the cached canopy list (rebuilt only when terrain changes — a felled tree stops shedding).
func _draw_surface_life() -> void:
	if _leaf_cache_dirty:
		_leaf_cache_dirty = false
		_leaf_cells.clear()
		for key: Variant in sim.solid:
			if sim.solid[key] == &"leaves":
				_leaf_cells.append(key)
	var view: Rect2 = (get_canvas_transform().affine_inverse() * get_viewport_rect()).grow(float(CELL) * 4.0)
	const FALL_T: float = 5.0
	for c: Vector2i in _leaf_cells:
		var pos := Vector2(c) * float(CELL)
		if not view.has_point(pos):
			continue
		var h: int = ((int(c.x) * 73856093) ^ (int(c.y) * 83492791)) & 0x7fffffff
		var period: float = 9.0 + float(h % 800) / 100.0
		var t: float = fmod(_anim_time + float(h % 997) / 997.0 * period, period)
		if t > FALL_T:
			continue
		var f: float = t / FALL_T                                  # 0..1 through the fall
		var sway: float = sin(t * 2.2 + float(h)) * 9.0
		var p := Vector2(pos.x + float(CELL) * 0.5 + sway + f * 14.0,
			pos.y + float(CELL) * 0.6 + f * 3.4 * float(CELL))
		var leaf_c := Color(0.32, 0.52, 0.26).lerp(Color(0.55, 0.48, 0.22), float(h % 100) / 100.0)
		leaf_c.a = 0.9 * (1.0 - maxf(0.0, f - 0.8) * 5.0)          # fade out on landing
		draw_set_transform(p, t * 2.6 + float(h % 7), Vector2.ONE)
		draw_rect(Rect2(Vector2(-2.4, -1.4), Vector2(4.8, 2.8)), leaf_c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The bird: one silhouette crossing the whole world's sky on a long cycle, direction and altitude
	# picked per crossing. Two flapping wing-strokes — unmistakable at any distance, three draw calls.
	# Birds fly by DAY (#29) — after dusk the sky belongs to the stars.
	const CYCLE: float = 47.0
	const CROSS_T: float = 16.0
	var cyc: int = int(_anim_time / CYCLE)
	var ct: float = fmod(_anim_time, CYCLE)
	if ct < CROSS_T and daylight() > 0.5:
		var bh: int = (cyc * 2654435761) & 0x7fffffff
		var frac: float = ct / CROSS_T
		var span: float = float(FactorySim.GRID_COLS * CELL)
		var bx: float = lerpf(-80.0, span + 80.0, frac if bh % 2 == 0 else 1.0 - frac)
		var by: float = float(SURFACE_LINE * CELL) - 190.0 - float(bh % 90) \
			+ sin(ct * 1.3) * 10.0
		if view.has_point(Vector2(bx, by)):
			var flap: float = absf(sin(ct * 9.0)) * 5.0
			var bc := Color(0.16, 0.18, 0.24)
			draw_line(Vector2(bx - 6.0, by - flap + 2.0), Vector2(bx, by), bc, 1.6)
			draw_line(Vector2(bx, by), Vector2(bx + 6.0, by - flap + 2.0), bc, 1.6)


func _draw_ore_glints() -> void:
	var view: Rect2 = (get_canvas_transform().affine_inverse() * get_viewport_rect()).grow(float(CELL))
	const PERIOD: float = 3.4
	const FLARE_LEN: float = 0.5
	for key: Variant in sim.deposits:
		var c: Vector2i = key
		var pos := Vector2(c) * float(CELL)
		if not view.has_point(pos) or not sim.is_solid(c):
			continue
		var def: MaterialDef = _material(sim.material_at(c))
		if not def.has_nuggets():
			continue
		var h: int = ((int(c.x) * 73856093) ^ (int(c.y) * 19349663)) & 0x7fffffff
		var offset: float = float(h % 997) / 997.0 * PERIOD
		var t: float = fmod(_anim_time + offset, PERIOD)
		if t > FLARE_LEN:
			continue
		var flare: float = sin(t / FLARE_LEN * PI)              # 0 -> 1 -> 0 across the flare window
		var nubs: Array[Vector2] = _cell_speckles(c, def.nugget_count)
		var cycle: int = int((_anim_time + offset) / PERIOD)    # a different fleck flares each cycle
		var p: Vector2 = pos + nubs[cycle % nubs.size()]
		var col: Color = def.nugget_color.lightened(0.65)
		col.a = 0.85 * flare
		var r: float = 2.0 + 2.5 * flare                        # a little 4-point star, not a lens flare
		draw_line(p + Vector2(-r, 0.0), p + Vector2(r, 0.0), col, 1.2)
		draw_line(p + Vector2(0.0, -r), p + Vector2(0.0, r), col, 1.2)
		draw_circle(p, 1.1 + 0.8 * flare, Color(col, minf(1.0, col.a + 0.15)))
	_draw_seal_pulse(view)


## THE SEAL's slow violet breath: the unbreakable band reads as dormant power, not just dark rock.
## Rows found once by scanning a couple of probe columns per row (the band is full-width by
## construction); each visible still-solid sealrock cell breathes a faint wash on a long cycle.
func _draw_seal_pulse(view: Rect2) -> void:
	if not _seal_rows_scanned:
		_seal_rows_scanned = true
		var probe: int = FactorySim.GRID_COLS / 2
		for row: int in FactorySim.GRID_ROWS:
			if sim.material_at(Vector2i(0, row)) == &"sealrock" \
					or sim.material_at(Vector2i(probe, row)) == &"sealrock":
				_seal_rows.append(row)
	if _seal_rows.is_empty():
		return
	var col_lo: int = maxi(0, int(view.position.x / float(CELL)))
	var col_hi: int = mini(FactorySim.GRID_COLS - 1, int(view.end.x / float(CELL)))
	for row: int in _seal_rows:
		var ry: float = float(row) * float(CELL)
		if ry + float(CELL) < view.position.y or ry > view.end.y:
			continue
		for cx: int in range(col_lo, col_hi + 1):
			var c := Vector2i(cx, row)
			if sim.material_at(c) != &"sealrock":
				continue
			var breath: float = 0.5 + 0.5 * sin(_anim_time * 0.9 + float(cx) * 0.35)
			draw_rect(Rect2(Vector2(c) * float(CELL), Vector2(CELL, CELL)),
				Color(0.42, 0.22, 0.66, 0.05 + 0.09 * breath))


## Painter for ONE terrain chunk (bound to its cell `rect`): background walls, terrain cells, and the
## smoothed surface — but only for cells inside this chunk. A CanvasItem isn't clipped to `rect` (the
## surface wedge may reach one cell above it), so cross-boundary detail draws fine; `rect` only bounds
## which cells this chunk is RESPONSIBLE for. The world border moved to the dynamic _draw (one thin outline).
func _paint_terrain_chunk(ci: CanvasItem, rect: Rect2i) -> void:
	_draw_background(ci, rect)  # sky within this chunk; dark-dirt BACK WALL behind every dug-out cell + depth
	_draw_terrain(ci, rect)     # solid cells in this chunk (ends with the surface cap pass for its columns)


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


## POWER PULSES (FABLE_NEXT_50 #19): bright beads travel the LIVE conduit network so energy visibly
## FLOWS — down every vertical link and outward (downhill) along laterals, NEVER up (the game's locked
## hook made visible). Bead count + brightness scale with the power the tube carries; a dead tube shows
## nothing. Pure cosmetic clockwork over the copper draw — reads the derived power field, never writes.
const PULSE_SPEED: float = 1.7                        ## links traversed per second by a bead
func _draw_power_pulses() -> void:
	for cell: Variant in sim.conduit:
		var c: Vector2i = cell
		var lvl: float = _conduit_level(c)
		if lvl < 0.08:                                # dead / near-dead tube: no flow to show
			continue
		var center: Vector2 = Vector2(c) * float(CELL) + Vector2(CELL, CELL) * 0.5
		# Flow links leaving THIS node: down (if coupled to a conduit or a consumer machine) + downhill
		# laterals (toward an equal-or-lower conduit; ties go right). Never up — that would deny the hook.
		var links: Array[Vector2i] = []
		var below: Vector2i = c + Vector2i(0, 1)
		if sim.has_conduit(below) or sim.machine_at(below) != null:
			links.append(Vector2i(0, 1))
		for dx: int in [1, -1]:
			var nb: Vector2i = c + Vector2i(dx, 0)
			if sim.has_conduit(nb):
				var nl: float = _conduit_level(nb)
				if nl < lvl or (is_equal_approx(nl, lvl) and dx == 1):
					links.append(Vector2i(dx, 0))
		for d: Vector2i in links:
			var span: float = float(CELL) if sim.has_conduit(c + d) else float(CELL) * 0.5
			var to: Vector2 = center + Vector2(d) * span
			var beads: int = 1 + int(lvl * 2.0)      # 1..3 beads with power
			for b: int in beads:
				var t: float = fmod(_anim_time * PULSE_SPEED + float(b) / float(beads)
					+ float(c.x + c.y) * 0.13, 1.0)
				var p: Vector2 = center.lerp(to, t)
				var a: float = (0.32 + 0.5 * lvl) * (0.35 + 0.65 * sin(t * PI))   # fade at both ends
				draw_circle(p, 3.0, Color(1.0, 0.85, 0.45, a * 0.32))            # soft halo
				draw_circle(p, 1.7, Color(1.0, 0.92, 0.58, a))                   # bright core


## Draw the placed ropes: each cell is a taut hemp line down the middle with rung KNOTS every few px,
## a hitch loop on the top (anchor) cell, and a loose frayed tail on the bottom one — so a roped shaft
## reads instantly as "climbable" against the dark. Sways very gently (cosmetic clock) like a hung line.
func _draw_ropes() -> void:
	const HEMP := Color(0.76, 0.63, 0.42)
	const SHADE := Color(0.42, 0.33, 0.20)
	for cell: Variant in sim.rope:
		var c: Vector2i = cell
		var x: float = float(c.x * CELL) + float(CELL) * 0.5
		var top := Vector2(x, float(c.y * CELL))
		var sway: float = sin(_anim_time * 1.6 + float(c.y) * 0.7) * 0.8
		var is_anchor: bool = not sim.rope.has(c + Vector2i(0, -1))
		var is_tail: bool = not sim.rope.has(c + Vector2i(0, 1))
		var bot := Vector2(x + sway, float((c.y + 1) * CELL))
		draw_line(top + Vector2(1.2, 0), bot + Vector2(1.2, 0), SHADE, 2.6)         # back shade = depth
		draw_line(top, bot, HEMP, 1.8)
		for k: int in 3:                                                             # rung knots
			var ky: float = float(c.y * CELL) + 5.0 + float(k) * 10.5
			draw_line(Vector2(x - 3.0, ky), Vector2(x + 3.0, ky), HEMP.darkened(0.15), 2.0)
		if is_anchor:
			draw_arc(top + Vector2(0.0, 3.0), 3.2, 0.0, TAU, 10, HEMP, 2.0)          # the hitch loop
		if is_tail:
			draw_line(bot, bot + Vector2(sway * 2.0, -5.0), HEMP.darkened(0.1), 1.6)  # frayed tail curl


## Draw the mounted torches (FABLE_50 #26): the shared Visuals glyph, live-guttering on the cosmetic
## clock. The warm pool each one casts is painted by _paint_lights; here is just the stick + flame.
func _draw_torches() -> void:
	for cell: Variant in sim.torch:
		Visuals.draw_machine_glyph(self, _cell_center(cell), "torch", 1.0, true, _anim_time)


## Draw the planted saplings (#38): a sprout rooted at the cell's floor that grows visibly taller with
## its progress — a just-planted seed is a nub, a nearly-grown one already brushes the cell above. The
## sway is cosmetic; growth itself is sim state (FactorySim.sapling ticks).
func _draw_saplings() -> void:
	for cell: Variant in sim.sapling:
		var c: Vector2i = cell
		var t: float = clampf(float(sim.sapling[c]) / float(FactorySim.SAPLING_GROW_TICKS), 0.0, 1.0)
		var foot := Vector2(float(c.x * CELL) + float(CELL) * 0.5, float((c.y + 1) * CELL) - 1.0)
		var h: float = 6.0 + t * 22.0
		var sway: float = sin(_anim_time * 2.2 + float(c.x) * 1.3) * (1.0 + t * 1.5)
		var tip := foot + Vector2(sway, -h)
		var stem := Color(0.48, 0.36, 0.22)
		var leaf := Color(0.40, 0.62, 0.28)
		draw_line(foot, tip, stem, 1.6 + t * 1.4)
		draw_circle(tip, 2.0 + t * 3.5, leaf)
		draw_circle(tip + Vector2(-2.0 - t * 2.0, 1.0), 1.6 + t * 2.2, leaf.darkened(0.15))
		draw_circle(tip + Vector2(2.0 + t * 2.0, 0.5), 1.6 + t * 2.2, leaf.lightened(0.10))


func _draw_terrain(ci: CanvasItem, rect: Rect2i) -> void:
	for cy: int in range(rect.position.y, rect.position.y + rect.size.y):
		for cx: int in range(rect.position.x, rect.position.x + rect.size.x):
			var c := Vector2i(cx, cy)
			if not sim.solid.has(c):
				continue
			_draw_terrain_cell(ci, c)
	_draw_inner_fillets(ci, rect)   # concave junctions rounded into the open cells (autotile #9)
	_draw_terrain_surface(ci, rect)


## The concave half of the autotile (FABLE_50 #9): wherever an OPEN cell's corner meets two solid
## orthogonal faces (a floor meeting a wall, a ceiling meeting a pillar), a quarter-round shoulder of
## the supporting rock's own colour fills that corner — carved junctions read as worn rock, not Lego
## seams. Bottom corners take the FLOOR cell's colour, top corners the CEILING's. Runs per chunk after
## the cells; the surface cap/ramp pass paints after (over) it, so the walked line stays authoritative.
func _draw_inner_fillets(ci: CanvasItem, rect: Rect2i) -> void:
	const R: float = 7.0
	var s: float = float(CELL)
	# Per corner: offsets of the two solid supports, the corner point in the open cell's box, the fan's
	# start angle (degrees), and which support paints it (its own body colour).
	var corners: Array = [
		{"a": Vector2i(0, -1), "b": Vector2i(-1, 0), "pt": Vector2(0.0, 0.0), "deg": 0.0, "src": Vector2i(0, -1)},
		{"a": Vector2i(0, -1), "b": Vector2i(1, 0), "pt": Vector2(s, 0.0), "deg": 90.0, "src": Vector2i(0, -1)},
		{"a": Vector2i(0, 1), "b": Vector2i(1, 0), "pt": Vector2(s, s), "deg": 180.0, "src": Vector2i(0, 1)},
		{"a": Vector2i(0, 1), "b": Vector2i(-1, 0), "pt": Vector2(0.0, s), "deg": 270.0, "src": Vector2i(0, 1)},
	]
	for cy: int in range(rect.position.y, rect.position.y + rect.size.y):
		for cx: int in range(rect.position.x, rect.position.x + rect.size.x):
			var c := Vector2i(cx, cy)
			if sim.solid.has(c) or not sim.in_bounds(c):
				continue
			var pos := Vector2(c) * s
			for k: Dictionary in corners:
				if not sim.is_solid(c + (k["a"] as Vector2i)) or not sim.is_solid(c + (k["b"] as Vector2i)):
					continue
				var src: Vector2i = c + (k["src"] as Vector2i)
				var col: Color = _cell_fill_color(src, _material(sim.material_at(src)))
				var corner: Vector2 = pos + (k["pt"] as Vector2)
				var fan := PackedVector2Array([corner])
				for i: int in 4:
					var a: float = deg_to_rad(float(k["deg"]) + 90.0 * float(i) / 3.0)
					fan.append(corner + Vector2(cos(a), sin(a)) * R)
				ci.draw_colored_polygon(fan, col)


## One solid terrain cell: fill, grain, ore nuggets, and carved-edge AO. Split out of the cell loop so the
## chunked painter can draw just its block's cells (was `for cell in sim.solid` over the whole world).
func _draw_terrain_cell(ci: CanvasItem, c: Vector2i) -> void:
		var pos := Vector2(c) * float(CELL)
		var def: MaterialDef = _material(sim.solid[c])
		# Sprite-ready: if a tile PNG exists for this material, draw it and skip the procedural fill
		# (still draw the surface cap/ramp pass below). Phase B of docs/ART_SPEC.md.
		var tile: Texture2D = Art.tex("tile_" + String(def.id))
		if tile != null:
			ci.draw_texture_rect(tile, Rect2(pos, Vector2(CELL, CELL)), false)
			return
		var col: Color = _cell_fill_color(c, def)
		_draw_cell_silhouette(ci, c, pos, col)
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


## The cell's body FILL, autotiled (FABLE_50 #9): instead of a flat square, the silhouette CHAMFERS
## every convex corner — a 45° cut wherever two adjacent faces are both open — so free edges read as
## weathered earth, a lone block reads as a boulder, and cave mouths lose the Lego. The 45° echoes the
## ramp language (one diagonal vocabulary everywhere). The cut is skipped on the top corners of the
## column's walkable surface cell: the cap/ramp pass owns that edge, and the seen line must stay
## exactly the walked line. Sprite tiles (tile_<id>.png) bypass this — art brings its own edges.
func _draw_cell_silhouette(ci: CanvasItem, c: Vector2i, pos: Vector2, col: Color) -> void:
	const R: float = 7.0
	var open_u: bool = not sim.is_solid(c + Vector2i(0, -1))
	var open_d: bool = not sim.is_solid(c + Vector2i(0, 1))
	var open_l: bool = not sim.is_solid(c + Vector2i(-1, 0))
	var open_r: bool = not sim.is_solid(c + Vector2i(1, 0))
	var keep_top: bool = sim.surface_row(c.x) == c.y     # the walk line — the cap/ramp pass owns it
	var s: float = float(CELL)
	var pts := PackedVector2Array()
	if open_u and open_l and not keep_top:               # top-left
		pts.append(pos + Vector2(0.0, R)); pts.append(pos + Vector2(R, 0.0))
	else:
		pts.append(pos)
	if open_u and open_r and not keep_top:               # top-right
		pts.append(pos + Vector2(s - R, 0.0)); pts.append(pos + Vector2(s, R))
	else:
		pts.append(pos + Vector2(s, 0.0))
	if open_d and open_r:                                # bottom-right
		pts.append(pos + Vector2(s, s - R)); pts.append(pos + Vector2(s - R, s))
	else:
		pts.append(pos + Vector2(s, s))
	if open_d and open_l:                                # bottom-left
		pts.append(pos + Vector2(R, s)); pts.append(pos + Vector2(0.0, s - R))
	else:
		pts.append(pos + Vector2(0.0, s))
	ci.draw_colored_polygon(pts, col)


## DEPTH-ZONE PALETTES (FABLE_50 #13): each zone pulls the terrain toward its own temperature, eased
## across a transition band so strata read as different PLACES, not stripes. Topsoil keeps its warm
## material colours (no entry = no tint); Stonereach below THE SEAL chills toward cold slate-blue.
## A new depth layer = one new row here (rows straddle the transition; strength is the held tint).
const ZONE_TINTS: Array[Dictionary] = [
	{"from": 50, "to": 66, "color": Color(0.42, 0.55, 0.90), "strength": 0.30},   # Stonereach (L2)
]


## Ease `col` toward every zone tint whose band `row` has entered. Applied to terrain AND walls (the
## whole stratum shifts together); machines/items stay untinted — the artificial keeps its own colour.
func _zone_tinted(col: Color, row: int) -> Color:
	for z: Dictionary in ZONE_TINTS:
		var lo: int = int(z["from"])
		if row <= lo:
			continue
		var t: float = clampf(float(row - lo) / float(int(z["to"]) - lo), 0.0, 1.0)
		col = col.lerp(z["color"] as Color, float(z["strength"]) * smoothstep(0.0, 1.0, t))
	return col


## The final fill colour for a terrain cell: the material's base, DARKENED with depth (the lower world
## reads as deeper, not one flat fill) then nudged by the deterministic tonal jitter (so a field of earth
## isn't ONE flat colour — the biggest flat-fill tell). Extracted so the surface RAMP wedge fills with the
## exact same colour as the cell body below it — the slope is the same earth mass, not a sticker on top.
func _cell_fill_color(c: Vector2i, def: MaterialDef) -> Color:
	var depth: float = clampf(float(c.y) / float(FactorySim.GRID_ROWS), 0.0, 1.0)
	var col: Color = _zone_tinted(def.base_color.darkened(depth * def.depth_darken), c.y)
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
## CORNER-AWARE (FABLE_50 #14): each strip INSETS where the silhouette chamfered that corner (no AO
## sliver floating over the 45° cut), and where a face DEAD-ENDS into an overhang (perpendicular
## neighbour solid but the diagonal past it solid too — a concave inside corner) a nested SCOOP patch
## darkens the junction end, so carved pockets read scooped from the rock, not taped together. Both
## cells at a junction patch their own face, so the scoop is symmetric with zero cross-cell drawing.
func _draw_edge_ao(ci: CanvasItem, c: Vector2i, pos: Vector2) -> void:
	const STEPS: int = 3
	const CH: float = 7.0                              # the silhouette's chamfer radius — keep in lockstep
	var open_u: bool = not sim.is_solid(c + Vector2i(0, -1))
	var open_d: bool = not sim.is_solid(c + Vector2i(0, 1))
	var open_l: bool = not sim.is_solid(c + Vector2i(-1, 0))
	var open_r: bool = not sim.is_solid(c + Vector2i(1, 0))
	var keep_top: bool = sim.surface_row(c.x) == c.y   # top corners uncut there — the cap pass owns them
	var cs: float = float(CELL)
	for i: int in STEPS:
		var a: float = 0.20 * (1.0 - float(i) / float(STEPS))
		var sh := Color(0.0, 0.0, 0.0, a)
		var o: float = float(i) * 2.0
		var s := 2.0
		if open_u:
			var x0: float = CH if (open_l and not keep_top) else 0.0
			var x1: float = cs - (CH if (open_r and not keep_top) else 0.0)
			ci.draw_rect(Rect2(pos.x + x0, pos.y + o, x1 - x0, s), sh)
		if open_d:
			var x0: float = CH if open_l else 0.0
			var x1: float = cs - (CH if open_r else 0.0)
			ci.draw_rect(Rect2(pos.x + x0, pos.y + cs - o - s, x1 - x0, s), sh)
		if open_l:
			var y0: float = CH if (open_u and not keep_top) else 0.0
			var y1: float = cs - (CH if open_d else 0.0)
			ci.draw_rect(Rect2(pos.x + o, pos.y + y0, s, y1 - y0), sh)
		if open_r:
			var y0: float = CH if (open_u and not keep_top) else 0.0
			var y1: float = cs - (CH if open_d else 0.0)
			ci.draw_rect(Rect2(pos.x + cs - o - s, pos.y + y0, s, y1 - y0), sh)
	# The concave scoops. A face's end is concave when its continuation cell is solid (the face stops)
	# AND the diagonal past it is solid too (an overhang roofs the junction). Each scoop: two nested
	# rects hugging that end of the face, stacking extra dark onto the strips already there.
	var solid_ul: bool = sim.is_solid(c + Vector2i(-1, -1))
	var solid_ur: bool = sim.is_solid(c + Vector2i(1, -1))
	var solid_dl: bool = sim.is_solid(c + Vector2i(-1, 1))
	var solid_dr: bool = sim.is_solid(c + Vector2i(1, 1))
	if open_u:
		if not open_l and solid_ul:
			_ao_scoop(ci, pos + Vector2(0.0, 0.0), Vector2(1.0, 0.0), true)
		if not open_r and solid_ur:
			_ao_scoop(ci, pos + Vector2(cs, 0.0), Vector2(-1.0, 0.0), true)
	if open_d:
		if not open_l and solid_dl:
			_ao_scoop(ci, pos + Vector2(0.0, cs), Vector2(1.0, 0.0), false)
		if not open_r and solid_dr:
			_ao_scoop(ci, pos + Vector2(cs, cs), Vector2(-1.0, 0.0), false)
	if open_l:
		if not open_u and solid_ul:
			_ao_scoop(ci, pos + Vector2(0.0, 0.0), Vector2(0.0, 1.0), true)
		if not open_d and solid_dl:
			_ao_scoop(ci, pos + Vector2(0.0, cs), Vector2(0.0, -1.0), true)
	if open_r:
		if not open_u and solid_ur:
			_ao_scoop(ci, pos + Vector2(cs, 0.0), Vector2(0.0, 1.0), false)
		if not open_d and solid_dr:
			_ao_scoop(ci, pos + Vector2(cs, cs), Vector2(0.0, -1.0), false)


## One concave-junction scoop: nested darkening rects growing from `corner` along `along` (the face
## direction), hugging the face surface. `near_edge` = the face lies on the min side of the perpendicular
## axis (top/left faces) vs the max side (bottom/right). Alphas stack on the face strips beneath.
func _ao_scoop(ci: CanvasItem, corner: Vector2, along: Vector2, near_edge: bool) -> void:
	const DEPTH: float = 6.0                           # matches the strip stack (3 steps x 2 px)
	for ext: float in [9.0, 5.0]:                      # two nested patches = a cheap gradient
		var run: Vector2 = along * ext
		var thick := Vector2(DEPTH, DEPTH) - along.abs() * DEPTH
		if not near_edge:
			thick = -thick
		var r := Rect2(corner, run + thick).abs()
		ci.draw_rect(r, Color(0.0, 0.0, 0.0, 0.11))


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
func _draw_terrain_surface(ci: CanvasItem, rect: Rect2i) -> void:
	for col: int in range(rect.position.x, rect.position.x + rect.size.x):
		if col >= FactorySim.GRID_COLS:
			break
		var r: int = sim.surface_row(col)
		if r >= FactorySim.GRID_ROWS:
			continue  # empty column, no surface
		# Only THIS chunk's rows own the cap. (The wedge reaches one cell up into the chunk above, which is
		# harmless — chunks aren't clipped — and that neighbour is dirtied on a dig so stale caps clear.)
		if r < rect.position.y or r >= rect.position.y + rect.size.y:
			continue
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


## An INTERACTABLE outline pulse (FABLE_50 #21): a breathing coloured outline + solid corner brackets
## around the hovered thing — the modern "you can act on this" affordance, in the thing's OWN colour so
## a drill pulses steel and an ore vein pulses ore. Drawn, not shadered: machines and terrain here are
## procedural canvas paint, so there's no texture a shader outline could sample — the drawn pulse is
## the same visual language at zero pipeline cost.
func _draw_interact_pulse(rect: Rect2, col: Color) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_anim_time * 4.0)
	var r: Rect2 = rect.grow(2.0 + pulse * 2.5)
	draw_rect(r, Color(col.r, col.g, col.b, 0.28 + 0.42 * pulse), false, 2.0)
	var arm: float = float(CELL) * 0.22
	var solid := Color(col.r, col.g, col.b, 0.95)
	for corner: int in 4:
		var c := Vector2(r.position.x if corner % 2 == 0 else r.end.x,
			r.position.y if corner < 2 else r.end.y)
		var d := Vector2(1.0 if corner % 2 == 0 else -1.0, 1.0 if corner < 2 else -1.0)
		draw_line(c, c + Vector2(arm * d.x, 0.0), solid, 2.0)
		draw_line(c, c + Vector2(0.0, arm * d.y), solid, 2.0)


## The cursor cell, drawn by context (using the affordances MainView pushed via set_aim):
##   solid earth -> MINE box (white; faint out of reach; a VEIN adds an ore-coloured interact pulse) ·
##   your machine -> interact pulse in its own colour (RMB picks up, R configures) ·
##   open cell -> BUILD ghost of the selected machine (green outline = placeable, red = blocked).
func _draw_aim() -> void:
	if not sim.in_bounds(_aim):
		return
	var pos := Vector2(_aim) * float(CELL)
	if sim.is_solid(_aim):
		var col := Color(1, 1, 1, 0.85) if _aim_in_reach else Color(1, 1, 1, 0.18)
		draw_rect(Rect2(pos, Vector2(CELL, CELL)), col, false, 2.0)
		if _aim_in_reach and sim.ore_deposit_at(_aim) > 0:   # a rich vein reads as a THING, not just rock
			_draw_interact_pulse(Rect2(pos + Vector2(1, 1), Vector2(CELL - 2, CELL - 2)),
				_material(sim.material_at(_aim)).nugget_color)
		return
	if not _aim_in_reach:
		return
	var inner := Rect2(pos + Vector2(1, 1), Vector2(CELL - 2, CELL - 2))
	var m: MachineState = sim.machine_at(_aim)
	if m != null:
		_draw_interact_pulse(inner, Visuals.machine_color(m.def).lightened(0.25))
		return
	if _ghost_def != null:
		# A brighter, more opaque tint so the ghost reads as a translucent PREVIEW on its own (4b critique).
		var ghost: Color = Visuals.machine_color(_ghost_def).lerp(Color.WHITE, 0.20)
		ghost.a = 0.55
		draw_rect(Rect2(pos + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)), ghost)
		Visuals.draw_machine_glyph(self, pos + Vector2(CELL, CELL) * 0.5, Visuals.machine_kind(_ghost_def), 1.0, false, 0.0)
		if _ghost_def.behavior == &"drill" and _aim_placeable:
			_draw_drill_preview()  # dashed ore column + out-arrow: show what this drill will bore & where it pours
		if _ghost_def.behavior == &"rope" and _aim_placeable:
			_draw_rope_preview()   # ghost line down the shaft: how far the rope will unroll from here
		if _ghost_def.behavior == &"h_drill" and _aim_placeable:
			_draw_h_drill_preview()  # the gallery it will chew + where the haul drains (or won't)
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


## When holding a Drill and hovering a valid spot, preview WHAT it will bore: a dashed outline around the
## ore column it'll drain (top→bottom of the vein straight below) + a downward OUT-ARROW under the bottommost
## ore marking where the ore pours. Teaches the player to hunt tall, vertical veins (longer automation) and
## warns (amber, "dig a drain") when the vein bottoms on rock with nowhere to drop. Pure overlay.
func _draw_drill_preview() -> void:
	var pv: Dictionary = sim.drill_preview(_aim)
	var ore_cells: Array = pv["ore_cells"]
	if ore_cells.is_empty():
		return                                            # not over any ore — nothing to preview
	var blocked: bool = pv["blocked"]
	var flow := Color(1.0, 0.80, 0.30, 0.95)              # warm gold: "here's the ore, it'll flow"
	var warn := Color(0.98, 0.45, 0.38, 0.95)             # red-amber: no drain below
	var tint: Color = warn if blocked else flow
	# Tint each cell the drill will bore by ITS OWN material — so a MIXED column (e.g. ore stacked on coal)
	# reads honestly as mixed: the drill bores straight down through both and pours a MIXED stream, and now
	# you SEE that before committing (ore cells glow amber, coal cells dark) rather than one uniform gold.
	for oc: Variant in ore_cells:
		var mat_col: Color = _material(sim.material_at(oc)).nugget_color
		draw_rect(Rect2(Vector2(oc) * float(CELL), Vector2(CELL, CELL)), Color(mat_col.r, mat_col.g, mat_col.b, 0.22))
	# Dashed box hugging the whole ore column (topmost ore .. bottommost ore, one cell wide).
	var top: Vector2i = ore_cells[0]
	var bot: Vector2i = ore_cells[-1]
	var box := Rect2(Vector2(top) * float(CELL) + Vector2(1, 1),
		Vector2(CELL - 2, float((bot.y - top.y + 1) * CELL) - 2))
	_draw_dashed_rect(box, tint, 6.0, 2.5)
	# The OUT-ARROW: a downward chevron in the cell just below the bottommost ore — where the ore pours out.
	var drop: Vector2i = pv["drop_cell"]
	if sim.in_bounds(drop):
		var cx: float = float(drop.x * CELL) + float(CELL) * 0.5
		var top_y: float = float(drop.y * CELL) + 3.0
		var bot_y: float = top_y + float(CELL) * 0.55
		draw_line(Vector2(cx, top_y), Vector2(cx, bot_y), tint, 2.5)
		var head: float = 6.0
		draw_line(Vector2(cx, bot_y), Vector2(cx - head, bot_y - head), tint, 2.5)
		draw_line(Vector2(cx, bot_y), Vector2(cx + head, bot_y - head), tint, 2.5)


## When holding the Borer, preview its GALLERY: tint every solid cell it can chew along the facing
## (the builder's facing — it bores the way YOU are looking), a dashed box around the run, and the
## down out-arrow under its own cell — gold when a drain exists below, red-amber when it would sit
## sealed on rock and pool ("dig a drain first"). Mirrors _draw_drill_preview's language sideways.
func _draw_h_drill_preview() -> void:
	var facing: int = player.facing if player != null else 1
	var cells: Array[Vector2i] = []
	for k: int in range(1, FactorySim.H_DRILL_RANGE + 1):
		var c := Vector2i(_aim.x + facing * k, _aim.y)
		if not sim.in_bounds(c) or sim.machine_at(c) != null:
			break
		if not sim.is_solid(c):
			continue
		if MiningRules.required_tier(sim.material_at(c)) > FactorySim.H_DRILL_TIER:
			break
		cells.append(c)
	if cells.is_empty():
		return
	var below := _aim + Vector2i(0, 1)
	var drained: bool = not sim.is_solid(below) or sim.machine_at(below) != null
	var tint := Color(1.0, 0.80, 0.30, 0.95) if drained else Color(0.98, 0.45, 0.38, 0.95)
	for c: Vector2i in cells:
		var mat_col: Color = _material(sim.material_at(c)).nugget_color
		draw_rect(Rect2(Vector2(c) * float(CELL), Vector2(CELL, CELL)), Color(mat_col.r, mat_col.g, mat_col.b, 0.22))
	var lo: int = mini(cells[0].x, cells[-1].x)
	var hi: int = maxi(cells[0].x, cells[-1].x)
	var box := Rect2(Vector2(float(lo * CELL) + 1.0, float(_aim.y * CELL) + 1.0),
		Vector2(float((hi - lo + 1) * CELL) - 2.0, float(CELL) - 2.0))
	_draw_dashed_rect(box, tint, 6.0, 2.5)
	# The out-arrow under the borer's OWN cell — the on-hook rule made visible before you commit.
	var cx: float = float(_aim.x * CELL) + float(CELL) * 0.5
	var top_y: float = float(below.y * CELL) + 3.0
	var bot_y: float = top_y + float(CELL) * 0.55
	draw_line(Vector2(cx, top_y), Vector2(cx, bot_y), tint, 2.5)
	draw_line(Vector2(cx, bot_y), Vector2(cx - 6.0, bot_y - 6.0), tint, 2.5)
	draw_line(Vector2(cx, bot_y), Vector2(cx + 6.0, bot_y - 6.0), tint, 2.5)


## When holding Rope over a valid anchor, preview the UNROLL: a translucent hemp line from the anchor
## down every open cell it will rope (capped by how many segments you carry), ending in a tick at the
## floor it reaches. Sells the one-placement-ropes-the-shaft verb before you commit. Pure overlay.
func _draw_rope_preview() -> void:
	var carried: int = int(sim.inventory.get(&"rope", 0))
	if carried <= 0:
		return
	var c: Vector2i = _aim
	var hung: int = 0
	while sim.in_bounds(c) and not sim.is_solid(c) and sim.machine_at(c) == null \
			and not sim.is_climbable(c) and hung < carried:
		hung += 1
		c += Vector2i(0, 1)
	if hung <= 0:
		return
	var x: float = float(_aim.x * CELL) + float(CELL) * 0.5
	var top := Vector2(x, float(_aim.y * CELL) + 4.0)
	var bot := Vector2(x, float((_aim.y + hung) * CELL) - 2.0)
	var ghost := Color(0.90, 0.78, 0.52, 0.55)
	draw_line(top, bot, ghost, 1.8)
	for k: int in range(1, hung):                       # a faint knot at each cell it will rope
		var ky: float = float((_aim.y + k) * CELL)
		draw_line(Vector2(x - 3.0, ky), Vector2(x + 3.0, ky), ghost, 1.5)
	draw_line(bot + Vector2(-5.0, 0.0), bot + Vector2(5.0, 0.0), ghost, 2.2)   # the floor it reaches


## A dashed rectangle outline — perimeter walked clockwise, laying `dash`-length ticks every other `dash`.
## Used by the drill preview; keeps the overlay reading as a PLAN (dashed) vs a solid selection box.
func _draw_dashed_rect(rect: Rect2, color: Color, dash: float, width: float) -> void:
	var corners: Array[Vector2] = [
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
	]
	for i: int in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var seg: float = a.distance_to(b)
		var dir: Vector2 = (b - a).normalized()
		var t: float = 0.0
		while t < seg:
			var t2: float = minf(t + dash, seg)
			draw_line(a + dir * t, a + dir * t2, color, width)
			t += dash * 2.0


## THE PARALLAX BACKDROP (FABLE_50 #10 + the #29 day/night sky): what the sky IS when nothing backs a
## cell. A vertical gradient breathing between DAY and NIGHT palettes on the day clock, a sun/moon
## riding its arc, stars fading in after dusk, two ridgeline silhouettes sliding at sub-terrain speed,
## and a few slow clouds. Fully deterministic per frame from the camera + the cosmetic clock.
func _paint_backdrop(ci: CanvasItem) -> void:
	var view: Rect2 = (ci.get_canvas_transform().affine_inverse() * ci.get_viewport_rect()).grow(96.0)
	var cam: Vector2 = view.get_center()
	var horizon: float = float(SURFACE_LINE) * float(CELL)
	var dl: float = daylight()
	# Sky palette: the original moody night, eased toward a subdued day blue (overcast-underworld, not
	# beach postcard) by the daylight level. Dusk/dawn pass through a brief warm blush at the horizon.
	var top_c: Color = Color(0.045, 0.06, 0.105).lerp(Color(0.21, 0.32, 0.50), dl)
	var hor_c: Color = Color(0.125, 0.135, 0.185).lerp(Color(0.46, 0.55, 0.66), dl)
	var blush: float = clampf(1.0 - absf(dl - 0.5) * 2.0, 0.0, 1.0)     # peaks mid-transition
	hor_c = hor_c.lerp(Color(0.62, 0.42, 0.34), blush * 0.35)           # dusk/dawn ember at the horizon
	var grad_top: float = horizon - 420.0
	ci.draw_rect(Rect2(view.position, Vector2(view.size.x, maxf(0.0, grad_top - view.position.y))), top_c)
	var quad := PackedVector2Array([Vector2(view.position.x, grad_top), Vector2(view.end.x, grad_top),
		Vector2(view.end.x, horizon), Vector2(view.position.x, horizon)])
	ci.draw_polygon(quad, PackedColorArray([top_c, top_c, hor_c, hor_c]))
	if view.end.y > horizon:
		ci.draw_rect(Rect2(Vector2(view.position.x, horizon),
			Vector2(view.size.x, view.end.y - horizon)), hor_c)
	# STARS: a hashed field in near-pinned sky space, fading in as the daylight dies; each twinkles on
	# its own phase. Stateless — the ore-glint trick pointed at the sky.
	if dl < 0.85:
		var star_a: float = (1.0 - dl) * 0.9
		for i: int in 42:
			var sh: int = i * 2654435761
			var sx: float = view.position.x + fposmod(float(sh % 4093) + cam.x * 0.04, view.size.x)
			var sy: float = grad_top - 60.0 + float((sh / 7) % 380)
			if sy > horizon - 90.0:
				continue
			var tw: float = 0.55 + 0.45 * sin(_anim_time * (1.1 + float(sh % 13) * 0.13) + float(i))
			ci.draw_circle(Vector2(sx, sy), 1.1 + float(sh % 3) * 0.4,
				Color(0.85, 0.88, 0.95, star_a * tw * 0.8))
	# SUN / MOON: each rides a low arc across the view during its half of the cycle, pinned to the
	# camera like any celestial thing. The sun is a warm bloom; the moon a small pale disc.
	var p: float = day_phase()
	var arc: float = (p + 0.05) / 0.60 if p < 0.55 else (p - 0.55) / 0.45   # 0..1 across its transit
	var is_sun: bool = p < 0.55
	if arc >= 0.0 and arc <= 1.0:
		var body := Vector2(cam.x + (arc - 0.5) * 760.0,
			(horizon - 130.0) - sin(arc * PI) * 240.0 + cam.y * 0.05)
		if is_sun:
			ci.draw_circle(body, 46.0, Color(1.0, 0.88, 0.62, 0.10 + 0.10 * dl))
			ci.draw_circle(body, 22.0, Color(1.0, 0.92, 0.70, 0.30 + 0.25 * dl))
			ci.draw_circle(body, 13.0, Color(1.0, 0.97, 0.85, 0.85))
		else:
			ci.draw_circle(body, 18.0, Color(0.80, 0.85, 0.95, 0.12))
			ci.draw_circle(body, 10.0, Color(0.88, 0.91, 0.97, 0.85))
			ci.draw_circle(body + Vector2(3.5, -2.5), 8.0, top_c.lerp(Color(0.82, 0.86, 0.94), 0.25))  # the shadowed limb
	# Clouds: soft three-lobe blobs drifting with the wind, barely lighter than the sky. Each wraps
	# through the visible span on its own phase so the cover never visibly loops. Lit by the daylight.
	var span: float = view.size.x + 500.0
	for i: int in 5:
		var h: float = float((i * 2654435761) % 1000) / 1000.0
		var p2: float = 0.10 + h * 0.06                                 # nearly pinned = far away
		var cx: float = view.position.x - 250.0 + fposmod(
			h * 4000.0 + _anim_time * (4.0 + h * 3.0) + cam.x * (1.0 - p2) - view.position.x, span)
		var cy: float = horizon - 300.0 - h * 130.0 + cam.y * (1.0 - p2) * 0.25
		var cc: Color = Color(0.42, 0.47, 0.58, 0.05 + h * 0.02) \
			.lerp(Color(0.78, 0.82, 0.88, 0.10 + h * 0.03), dl)
		var r: float = 26.0 + h * 30.0
		ci.draw_circle(Vector2(cx, cy), r, cc)
		ci.draw_circle(Vector2(cx - r * 0.9, cy + r * 0.25), r * 0.7, cc)
		ci.draw_circle(Vector2(cx + r * 0.9, cy + r * 0.22), r * 0.75, cc)
	# Ridgelines: far-to-near silhouettes. Sampled in FEATURE space (x shifted by the camera's
	# unparallaxed remainder) so crests slide slower than the terrain — the whole depth illusion.
	# By day they haze toward the sky (aerial perspective); by night they sink back to silhouette.
	for ridge: Dictionary in RIDGES:
		var f: float = float(ridge["factor"])
		var amp: float = float(ridge["amp"])
		var freq: float = float(ridge["freq"])
		var base_y: float = horizon - float(ridge["drop"]) + cam.y * (1.0 - f) * 0.30
		# Deep underground the camera drags base_y BELOW the polygon's fixed bottom edge — the crest
		# line would dip under the floor line (a self-intersecting polygon, triangulation fails).
		# Clamp the crests above the floor: invisible either way (walls cover the backdrop down there).
		var floor_y: float = horizon + 320.0
		var pts := PackedVector2Array()
		var x: float = view.position.x
		while x <= view.end.x + 24.0:
			var u: float = (x - cam.x * (1.0 - f)) * freq
			var crest: float = sin(u * TAU) * 0.55 + sin(u * TAU * 2.31 + 1.7) * 0.30 \
				+ sin(u * TAU * 0.47 + 0.6) * 0.35
			pts.append(Vector2(x, minf(base_y - (crest * 0.5 + 0.5) * amp, floor_y - 4.0)))
			x += 24.0
		pts.append(Vector2(view.end.x + 24.0, floor_y))
		pts.append(Vector2(view.position.x, floor_y))
		ci.draw_colored_polygon(pts, (ridge["color"] as Color).lerp(hor_c, dl * (0.42 - f * 0.5)))


## The REAL background WALL layer (sim.wall): each wall cell paints its material colour (depth-
## darkened) BEHIND the terrain, so a dug-out cell reveals the carved-room backing. Cells with NO wall
## stay transparent — the parallax backdrop (z -20) shows through, which is what makes open sky sky.
func _draw_background(ci: CanvasItem, rect: Rect2i) -> void:
	for cy: int in range(rect.position.y, rect.position.y + rect.size.y):
		for cx: int in range(rect.position.x, rect.position.x + rect.size.x):
			var c := Vector2i(cx, cy)
			if not sim.wall.has(c):
				continue
			var def: MaterialDef = _material(sim.wall[c])
			var wpos := Vector2(c) * float(CELL)
			# Sprite-ready: a tile_<wall-id>.png (e.g. tile_dirt_wall.png) replaces the flat fill.
			var wtex: Texture2D = Art.tex("tile_" + String(def.id))
			if wtex != null:
				ci.draw_texture_rect(wtex, Rect2(wpos, Vector2(CELL, CELL)), false)
				continue
			var depth: float = clampf(float(c.y) / float(FactorySim.GRID_ROWS), 0.0, 1.0)
			ci.draw_rect(Rect2(wpos, Vector2(CELL, CELL)),
				_zone_tinted(def.base_color.darkened(depth * def.depth_darken), c.y))


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


## The drop-in ANIMATION standard (docs/ART_SPEC.md Phase C): how fast the 2-frame working cycle chugs.
## One shared cadence so a bank of machines reads as one factory, not a zoo of tempos; the lift's frames
## ride its surged clock so power still visibly speeds it up.
const WORK_ANIM_FPS: float = 4.0


## The sprite for a machine's CURRENT state, or null → the code-drawn casing+glyph. Fallback chain per
## frame: working + work_0/work_1 drawn → cycle them; working + ONLY work_0 drawn → alternate idle↔work_0
## (a 2-frame chug from one extra PNG); idle or no work frames → the static machine_<id>. Partial sets
## always degrade gracefully — the artist can land frames one at a time.
func _machine_sprite(machine: MachineState, active: bool, clock: float) -> Texture2D:
	var base: String = "machine_" + String(machine.def.id)
	var idle: Texture2D = Art.tex(base)
	if idle == null:
		return null
	if active:
		var work_0: Texture2D = Art.tex(base + "_work_0")
		if work_0 != null:
			if int(clock * WORK_ANIM_FPS) % 2 == 1:
				var work_1: Texture2D = Art.tex(base + "_work_1")
				return work_1 if work_1 != null else idle
			return work_0
	return idle


## MainView pokes this when a machine is genuinely PLACED (try_build succeeds) so the assemble overlay
## plays once. Boot/load never call it → pre-existing machines never animate (the note_dig discipline).
func note_machine_built(cell: Vector2i) -> void:
	_construct[cell] = 0.0


## MainView pokes this when a block is genuinely MINED so the removed rock crumbles away (#18). Carries
## the material colour so dirt/stone/ore each shatter in their own hue. Capped — a rapid dig drops the
## oldest crumble rather than growing without bound.
func note_mined(cell: Vector2i, material: StringName) -> void:
	_crumble.append({"pos": Vector2(cell) * float(CELL), "col": material_color(material), "age": 0.0})
	if _crumble.size() > CRUMBLE_MAX:
		_crumble.pop_front()


## The mine-crumble overlay (#18): each fresh dig shatters the cell into four chunks that fly apart on an
## outward+gravity arc, shrink, and fade over CRUMBLE_DUR, with a brief white break-flash at the instant
## of impact. Sits at the terrain layer (under machines/items). Pure cosmetic — reads _crumble, no sim.
func _draw_crumble() -> void:
	var half: float = float(CELL) * 0.5
	for cr: Dictionary in _crumble:
		var pos: Vector2 = cr["pos"]
		var col: Color = cr["col"]
		var t: float = clampf(float(cr["age"]) / CRUMBLE_DUR, 0.0, 1.0)
		if t < 0.28:                                     # the break FLASH — a quick warm burst inset from the
			var fi: float = float(CELL) * (0.16 + t)     # cell edges (a pop, not a lit tile), swelling out
			draw_rect(Rect2(pos + Vector2(fi, fi), Vector2(float(CELL) - fi * 2.0, float(CELL) - fi * 2.0)),
				Color(1.0, 0.92, 0.72, (0.28 - t) * 1.1))
		for qx: int in 2:
			for qy: int in 2:
				var qc: Vector2 = pos + Vector2((float(qx) + 0.5) * half, (float(qy) + 0.5) * half)
				var out: Vector2 = Vector2(float(qx) - 0.5, float(qy) - 0.5).normalized()
				var off: Vector2 = out * (t * 5.0) + Vector2(0.0, t * t * 11.0)   # spread + gravity fall
				var sz: float = half * ((1.0 - t) * 0.86 + 0.14)                  # shrink toward nothing
				var cc := Color(col.r, col.g, col.b, 1.0 - t)
				draw_rect(Rect2(qc + off - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), cc)
				draw_rect(Rect2(qc + off - Vector2(sz, sz) * 0.5, Vector2(sz, sz)),
					Color(0.03, 0.03, 0.05, (1.0 - t) * 0.5), false, 1.0)          # dark rim for definition


func _draw_machine(machine: MachineState) -> void:
	var pos: Vector2 = Vector2(machine.cell) * float(CELL)
	var recipe: RecipeDef = machine.def.recipe
	var center: Vector2 = pos + Vector2(CELL, CELL) * 0.5
	# Contact shadow — grounds the machine on the floor it sits on.
	draw_set_transform(pos + Vector2(float(CELL) * 0.5, float(CELL) - 1.0), 0.0, Vector2(1.0, 0.26))
	draw_circle(Vector2.ZERO, float(CELL) * 0.46, Color(0.0, 0.0, 0.0, 0.30))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# A machine reads as ALIVE while it's working (behavior-aware), and a powered LIFT marches faster.
	var active: bool = _machine_active(machine)
	var clock: float = _anim_time
	if machine.def.behavior == &"lift":
		clock = _anim_time * (1.0 + machine.power_factor)   # the chevrons surge when powered
	# Sprite-ready: a machine_<id>.png replaces the code-drawn casing+glyph, and while WORKING the
	# 2-frame machine_<id>_work_0/1 cycle plays (docs/ART_SPEC.md Phase A + C); the badge / progress
	# bar / I/O ports below still overlay it. Absent → today's primitive look.
	var spr: Texture2D = _machine_sprite(machine, active, clock)
	if spr != null:
		if machine.facing < 0:   # directional machines (the Borer) mirror when facing left, like glyphs
			draw_set_transform(center, 0.0, Vector2(-1.0, 1.0))
			draw_texture_rect(spr, Rect2(Vector2(CELL, CELL) * -0.5, Vector2(CELL, CELL)), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(spr, Rect2(pos, Vector2(CELL, CELL)), false)
	else:
		var body := Rect2(pos + Vector2(1.0, 1.0), Vector2(CELL - 2.0, CELL - 2.0))
		draw_rect(body, Visuals.machine_color(machine.def))
		draw_rect(body, Color(0.04, 0.04, 0.06, 0.8), false, 1.5)  # darker inset casing
		for corner: Vector2 in [Vector2(4, 4), Vector2(CELL - 4, 4), Vector2(4, CELL - 4),
				Vector2(CELL - 4, CELL - 4)]:
			draw_circle(pos + corner, 1.0, Color(0.0, 0.0, 0.0, 0.5))  # bolts
		Visuals.draw_machine_glyph(self, center, Visuals.machine_kind(machine.def), 1.0, active, clock,
			machine.facing < 0)   # directional machines (the Borer) draw mirrored when facing left

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
	_draw_machine_status(machine, pos)
	if _construct.has(machine.cell):     # the one-shot assemble overlay (#9), on top of the finished draw
		_draw_construct(pos, clampf(float(_construct[machine.cell]) / CONSTRUCT_DUR, 0.0, 1.0))


## The one-shot ASSEMBLE overlay for a just-placed machine (FABLE_NEXT_50 #9): a settling flash that
## fades, a bright scan line sweeping up the casing (the frame "prints" upward), and corner brackets
## snapping inward to lock the frame. All additive/overlay — never hides the terrain. t: 0→1.
func _draw_construct(pos: Vector2, t: float) -> void:
	var c: float = float(CELL)
	var e: float = 1.0 - t
	draw_rect(Rect2(pos, Vector2(c, c)), Color(1.0, 0.94, 0.78, 0.45 * e * e))       # settling bloom
	var ly: float = pos.y + c * (1.0 - t)                                            # scan line, bottom→top
	draw_rect(Rect2(pos.x, ly - 1.0, c, 2.0), Color(0.82, 0.95, 1.0, 0.85 * sin(t * PI)))
	var off: float = e * 5.0                                                         # brackets snap inward
	var bl: float = 5.0
	var bc := Color(0.96, 0.86, 0.52, 0.35 + 0.55 * e)
	for cn: Array in [
			[Vector2(-off, -off), Vector2(1.0, 0.0), Vector2(0.0, 1.0)],
			[Vector2(c + off, -off), Vector2(-1.0, 0.0), Vector2(0.0, 1.0)],
			[Vector2(-off, c + off), Vector2(1.0, 0.0), Vector2(0.0, -1.0)],
			[Vector2(c + off, c + off), Vector2(-1.0, 0.0), Vector2(0.0, -1.0)]]:
		var p: Vector2 = pos + (cn[0] as Vector2)
		draw_line(p, p + (cn[1] as Vector2) * bl, bc, 1.5)
		draw_line(p, p + (cn[2] as Vector2) * bl, bc, 1.5)


## Factorio-style legibility: a small STATUS LAMP on every machine (green working / red no-fuel /
## amber starved / grey idle) + a blinking floating NEED bubble carrying the missing item's glyph when
## a machine is stalled (no fuel → coal, starved → its input). Reads FactorySim.machine_status (the sim's
## own run-gates, so it can't lie). Pure cosmetic — drawn glyphs, no emojis. The direct fix for "why has
## my drill gone quiet?" — the answer is now ON the machine, like Factorio.
func _draw_machine_status(machine: MachineState, pos: Vector2) -> void:
	var status: StringName = sim.machine_status(machine)
	var lamp: Color
	match status:
		&"working": lamp = Color(0.35, 0.92, 0.42)
		&"no_fuel": lamp = Color(0.96, 0.26, 0.20)
		&"no_input": lamp = Color(0.97, 0.72, 0.22)
		_: lamp = Color(0.52, 0.55, 0.62)          # idle
	# Status lamp: a rimmed dot in the machine's top-left corner (mirrors Factorio's entity status light).
	var lamp_c: Vector2 = pos + Vector2(5.5, 5.5)
	draw_circle(lamp_c, 4.2, Color(0.03, 0.03, 0.05, 0.9))
	draw_circle(lamp_c, 3.1, lamp)
	if status == &"working":
		return                                       # green = fine; no floating alarm
	if status == &"idle":
		return                                       # benign (empty mover); lamp is enough
	# Stalled (no_fuel / no_input) → a blinking bubble floats above the machine carrying WHAT it needs.
	var need: StringName = &"ore"
	if status == &"no_fuel":
		need = &"coal"
	elif machine.def.behavior == &"descent":
		need = FactorySim.DESCENT_EATS              # the gate eats ingots, not ore
	elif machine.def.recipe != null and not machine.def.recipe.inputs.is_empty():
		need = machine.def.recipe.inputs.keys()[0]
	var pulse: float = 0.62 + 0.38 * sin(_anim_time * 6.5)
	var bob: float = sin(_anim_time * 3.0) * 1.5
	var bc: Vector2 = pos + Vector2(float(CELL) * 0.5, -24.0 + bob)
	draw_circle(bc, 9.0, Color(0.05, 0.04, 0.06, 0.82 * pulse))
	draw_arc(bc, 9.0, 0.0, TAU, 20, Color(lamp.r, lamp.g, lamp.b, pulse), 1.6)
	Visuals.draw_item(self, bc, 11.0, need)


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

## THE LIGHTMAP VEIL (FABLE_50 #17): the whole darkness is ONE stretched texture draw — one texel
## per cell, linear-filtered over the world, so light grades smoothly sideways as well as down (the
## old pass drew a rect per cell: hard vertical edges on every lit shaft). Content lives in the
## texture; this draw command never re-issues.
func _paint_darkness(layer: LightLayer) -> void:
	layer.draw_texture_rect(_veil_tex,
		Rect2(0.0, 0.0, float(FactorySim.GRID_COLS * CELL), float(FactorySim.GRID_ROWS * CELL)), false)


## Bake the veil's BASE — the skylight/ambient model, unchanged: daylight floods DOWN each column's
## open air (attenuating past SURFACE_LINE), is BLOCKED by the first solid rock, scatters SKY_FADE
## tiles under the exposed surface, and everything deeper sits in full ambient (with the #29 night
## floor above ground). RGB per texel = SHADOW_COLOR exactly (NOT zone-tinted — the #13 palette
## lerps toward a bright terrain temperature that would wash the near-black veil out; the zones
## already read through the tinted terrain the veil dims); A = darkness. Runs only when terrain or
## the quantized daylight changes.
func _bake_veil_base() -> void:
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	if _veil_base.size() != cols * rows * 4:
		# The RGB bytes are SHADOW_COLOR everywhere, forever — written once here; every rebake
		# below touches ONLY the alpha byte per cell (a quarter of the writes).
		_veil_base.resize(cols * rows * 4)
		var sr: int = int(SHADOW_COLOR.r * 255.0)
		var sg: int = int(SHADOW_COLOR.g * 255.0)
		var sb: int = int(SHADOW_COLOR.b * 255.0)
		for i: int in range(cols * rows):
			_veil_base[i * 4] = sr
			_veil_base[i * 4 + 1] = sg
			_veil_base[i * 4 + 2] = sb
	# Above its column's surface the sky alpha depends on the ROW alone — table it once per bake
	# instead of a function call per cell (the bake's dominant cost at 7.7k cells).
	var sky_byte: PackedInt32Array = PackedInt32Array()
	sky_byte.resize(rows)
	var night_floor: float = NIGHT_DARK * (1.0 - daylight())
	for row: int in range(rows):
		var sky: float = maxf(AMBIENT_DARK * clampf(float(row - SURFACE_LINE) / float(SKY_REACH), 0.0, 1.0),
			night_floor)
		sky_byte[row] = int(clampf(sky, 0.0, 1.0) * 255.0)
	var ambient_byte: int = int(AMBIENT_DARK * 255.0)
	for col: int in range(cols):
		var surf: int = sim.surface_row(col)
		var scatter_end: int = mini(surf + SKY_FADE, rows - 1)
		for row: int in range(rows):
			var a: int = ambient_byte
			if row <= surf:
				a = sky_byte[row]
			elif row <= scatter_end:                        # the shallow-scatter band under the surface
				var t: float = float(row - surf) / float(SKY_FADE)
				a = int(lerpf(float(sky_byte[row]), float(ambient_byte), t))
			_veil_base[(row * cols + col) * 4 + 3] = a


## Per frame: copy the baked base and let every live light CUT its pool out of the darkness —
## multiplicative (each source scales the REMAINING veil), so stacked lights deepen the opening
## without over-subtracting. Where light falls the world shows its true colours through the hole;
## the additive pools then lay their warmth on top. The falling stream cuts too — the gravity pour
## visibly opens the dark as it falls.
func _update_veil() -> void:
	if _veil_dirty:
		_veil_dirty = false
		_bake_veil_base()
	var bytes: PackedByteArray = _veil_base.duplicate()
	if player != null:
		var head: Vector2 = player.position + Vector2(0.0, -Player.HEIGHT * 0.30)
		_veil_cut(bytes, head + _lamp_offset, 4.2, 0.8)          # the aimed beam pool
		_veil_cut(bytes, head + _lamp_offset * 0.45, 2.6, 0.45)  # the beam throat
		_veil_cut(bytes, player.position, 1.6, 0.2)              # faint close body glow
	for machine: MachineState in sim.machines:
		var kind: String = Visuals.machine_kind(machine.def)
		var s: float = 0.32                                      # cool working glow
		if kind == "generator":
			s = 0.55 if machine.fuel > 0 else 0.0                # dark when it runs dry
		elif kind == "furnace":
			s = 0.5
		elif kind == "lift":
			s = 0.18 + 0.35 * machine.power_factor
		if s > 0.0:
			_veil_cut(bytes, _cell_center(machine.cell), 2.4, s)
	for cell: Variant in sim.torch:
		_veil_cut(bytes, _cell_center(cell as Vector2i), 3.2, 0.6)
	for cell: Variant in sim.conduit:
		var lvl: float = _conduit_level(cell as Vector2i)
		if lvl > 0.04:
			_veil_cut(bytes, _cell_center(cell as Vector2i), 1.6, lvl * 0.4)
	for m: Dictionary in falling.motes():
		_veil_cut(bytes, m["pos"], 1.2, 0.3)
	_veil_img.set_data(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, false, Image.FORMAT_RGBA8, bytes)
	_veil_tex.update(_veil_img)


## Scale down the veil alpha in a radial falloff around a world position (radius in CELLS).
func _veil_cut(bytes: PackedByteArray, world: Vector2, radius: float, strength: float) -> void:
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	var cx: float = world.x / float(CELL)
	var cy: float = world.y / float(CELL)
	var c0: int = maxi(0, int(cx - radius))
	var c1: int = mini(cols - 1, int(cx + radius))
	var r0: int = maxi(0, int(cy - radius))
	var r1: int = mini(rows - 1, int(cy + radius))
	for row: int in range(r0, r1 + 1):
		for col: int in range(c0, c1 + 1):
			var dx: float = float(col) + 0.5 - cx
			var dy: float = float(row) + 0.5 - cy
			var d: float = sqrt(dx * dx + dy * dy)
			if d >= radius:
				continue
			var f: float = 1.0 - d / radius
			var keep: float = 1.0 - strength * f * f             # quadratic falloff = a soft-edged pool
			var idx: int = (row * cols + col) * 4 + 3
			bytes[idx] = int(float(bytes[idx]) * keep)


## Darkness alpha for one cell, given its column's first-solid row. Open air above the rock is lit by
## sky (attenuating with absolute depth past SURFACE_LINE); the exposed surface + SKY_FADE tiles below
## get shallow scatter; everything deeper is full ambient. The DAY/NIGHT floor (#29): at night the sky
## itself dims, so everywhere sky-driven darkens toward NIGHT_DARK (moonlight, not a cave) — the deep
## ambient is already darker than that, so the underground never changes.
func _skylight_alpha(row: int, surf: int) -> float:
	var night_floor: float = NIGHT_DARK * (1.0 - daylight())
	var sky: float = maxf(AMBIENT_DARK * clampf(float(row - SURFACE_LINE) / float(SKY_REACH), 0.0, 1.0),
		night_floor)
	if row <= surf:
		return sky                                      # sky-lit open air / exposed ground
	var scatter: float = clampf(float(row - surf) / float(SKY_FADE), 0.0, 1.0)
	return lerpf(sky, AMBIENT_DARK, scatter)


## The heat-haze quads (#20): every working furnace/generator gets a plume quad above its casing whose
## vertex alpha (the shader's strength mask) is full at the machine top and fades to nothing ~2 cells
## up — the shader displaces whatever the screen already shows there, so the plume warps terrain,
## walls, items and the machine's own smoke alike. Recipe-runners have behavior &""; the furnace check
## keys on the glyph kind so only HOT machines (forge/iron forge) shimmer, not every module.
func _paint_heat_haze(layer: LightLayer) -> void:
	for machine: MachineState in sim.machines:
		var kind: String = Visuals.machine_kind(machine.def)
		var hot: bool = kind == "furnace" or kind == "generator"
		if not hot or not _machine_active(machine):
			continue
		var top := Vector2(float(machine.cell.x) * CELL + float(CELL) * 0.5,
			float(machine.cell.y) * CELL + 2.0)
		var w: float = float(CELL) * 0.72
		var h: float = float(CELL) * 2.1
		var pts := PackedVector2Array([
			top + Vector2(-w * 0.5, 0.0), top + Vector2(w * 0.5, 0.0),
			top + Vector2(w * 0.34, -h), top + Vector2(-w * 0.34, -h)])
		var cols := PackedColorArray([
			Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0)])
		layer.draw_polygon(pts, cols)


## The additive LIGHT pools that punch back through the veil: the miner's head-lamp + a glow per machine
## + a glow per falling drop (the gravity stream made loud).
func _paint_lights(layer: LightLayer) -> void:
	_paint_godrays(layer)  # under the pools: daylight SHAFTS pouring down dug columns
	# Sonar echoes GLOW through the darkness veil (#27) — an answer from inside unlit rock must read
	# in the black, or the scanner is useless exactly where prospecting matters.
	if _scan_age >= 0.0:
		for e: Dictionary in _scan_echoes:
			var since_hit: float = _scan_age - float(e["dist"]) / SCAN_WAVE_SPEED
			if since_hit < 0.0 or since_hit > SCAN_ECHO_LINGER:
				continue
			var fade: float = 1.0 - since_hit / SCAN_ECHO_LINGER
			_draw_glow(layer, e["pos"], float(CELL) * 2.1,
				_material(e["material"] as StringName).nugget_color, 0.65 * fade)
	if player != null:
		# A faint flicker so the lamp reads as a live flame, not a static disc.
		var flick: float = 0.55 + 0.03 * sin(_anim_time * 11.0) + 0.02 * sin(_anim_time * 27.0)
		# The AIM-FOLLOWING beam (#44): a bright cast pool where you're looking + a dimmer throat pool
		# between it and the head — two glows along one line read as a directed beam, no shader needed.
		var head: Vector2 = player.position + Vector2(0.0, -Player.HEIGHT * 0.30)
		_draw_glow(layer, head + _lamp_offset, LAMP_RADIUS, lamp_color, flick)
		_draw_glow(layer, head + _lamp_offset * 0.45, LAMP_RADIUS * 0.62, lamp_color, flick * 0.45)
		_draw_glow(layer, player.position, float(CELL) * 1.4, lamp_color, 0.12)  # faint close body glow
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
	# Torches: the placeable light (FABLE_50 #26). Each mounted torch casts a warm guttering pool —
	# smaller than the head-lamp, but it STAYS: dropped along a dig, they mark the route home, and a
	# lit cave reads as claimed territory in the black.
	for cell: Variant in sim.torch:
		var tc: Vector2i = cell
		var gutter: float = 0.42 + 0.05 * sin(_anim_time * 9.0 + float(tc.x) * 1.7) \
			+ 0.03 * sin(_anim_time * 23.0 + float(tc.y))
		_draw_glow(layer, _cell_center(tc) + Vector2(1.2, -6.0), float(CELL) * 3.1,
			Color(1.0, 0.72, 0.38), gutter)
	# Powered conduits EMIT light, so a live trunk pours a column of warm glow down the dark shaft
	# (the in-world tube is drawn under the veil; this is what makes its power read from across the room).
	for cell: Variant in sim.conduit:
		var lvl: float = _conduit_level(cell)
		if lvl > 0.04:
			_draw_glow(layer, _cell_center(cell), float(CELL) * (0.9 + 0.7 * lvl), Color(1.0, 0.82, 0.42), lvl * 0.5)
	for m: Dictionary in falling.motes():
		# Dropped/falling items GLOW (the gravity-pour visual), but a dropped STACK overlaps many motes into
		# a "mini sun" (playtest). Dimmer + tighter per mote so a stream reads warm without blowing out.
		_draw_glow(layer, m["pos"], float(CELL) * 0.95, m["color"], 0.26)


## GODRAYS (FABLE_50 #12) — the signature shot: where a dug shaft admits the sky below the enclosing
## ground, a soft daylight BEAM pours down it, fading exactly where the skylight veil fades (SKY_REACH),
## with a slow shimmer. A column qualifies when its sky-lit air drops ≥2 rows below an adjacent surface
## edge (dug shafts + carved notches; 1-row slope steps stay clean). Per-vertex alpha polygons on the
## additive layer; reads only sim.surface_row. Pure cosmetics.
func _paint_godrays(layer: LightLayer) -> void:
	var cell_f: float = float(CELL)
	const RAY := Color(1.0, 0.95, 0.76)
	var dl: float = daylight()                              # no sun, no shafts (#29): rays die at night
	if dl <= 0.03:
		return
	for col: int in range(FactorySim.GRID_COLS):
		var surf: int = sim.surface_row(col)
		# The beam mouth = the SHALLOWER neighbouring surface (light pours past that edge) — min, not
		# max, so a 2-wide shaft still beams (its partner column is deep; the outer rim is the edge).
		var mouth: int = mini(sim.surface_row(maxi(col - 1, 0)),
			sim.surface_row(mini(col + 1, FactorySim.GRID_COLS - 1)))
		mouth = maxi(mouth, SURFACE_LINE)
		if surf - mouth < 2:
			continue                                        # no real shaft below the enclosure
		var mouth_light: float = 1.0 - clampf(float(mouth - SURFACE_LINE) / float(SKY_REACH), 0.0, 1.0)
		if mouth_light <= 0.05:
			continue                                        # the sky never reaches this deep a mouth
		var end_row: int = mini(surf, SURFACE_LINE + SKY_REACH + 2)
		var floor_light: float = 1.0 - clampf(float(end_row - SURFACE_LINE) / float(SKY_REACH), 0.0, 1.0)
		var x: float = float(col) * cell_f
		var y0: float = float(mouth) * cell_f
		var y1: float = float(end_row) * cell_f + (cell_f * 0.4 if end_row == surf else 0.0)
		var shimmer: float = 0.85 + 0.15 * sin(_anim_time * 0.7 + float(col) * 1.3)
		# Two nested beams: a wide faint wash + a narrow bright core, each fading top -> bottom.
		for pass_i: int in 2:
			var half_w: float = (cell_f * 0.46) if pass_i == 0 else (cell_f * 0.24)
			var a: float = (0.10 if pass_i == 0 else 0.14) * mouth_light * shimmer * dl
			var a_end: float = a * (floor_light / maxf(mouth_light, 0.01)) * 0.5
			var cx: float = x + cell_f * 0.5
			var pts := PackedVector2Array([
				Vector2(cx - half_w, y0), Vector2(cx + half_w, y0),
				Vector2(cx + half_w * 0.8, y1), Vector2(cx - half_w * 0.8, y1)])
			var cols := PackedColorArray([
				Color(RAY, a), Color(RAY, a), Color(RAY, a_end), Color(RAY, a_end)])
			layer.draw_polygon(pts, cols)
		# A soft landing pool where the beam actually MEETS the floor while still lit.
		if end_row == surf and floor_light > 0.06:
			_draw_glow(layer, Vector2(x + cell_f * 0.5, float(surf) * cell_f),
				cell_f * 1.6, RAY, 0.18 * floor_light * shimmer * dl)


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
