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

## Draw-domain painter modules: cohesive slabs of pure drawing lifted out of this file so it reads as a
## draw sequence, not one 2,700-line canvas. Each is stateless — it paints onto a CanvasItem this renderer
## hands it and reads renderer state as `r.x`. Preloaded by PATH (not class_name) so headless drivers
## resolve them without a refreshed global-class cache.
const SkyPainter := preload("res://scenes/sky_painter.gd")
const TerrainPainter := preload("res://scenes/terrain_painter.gd")

const CELL: int = 32
const WORLD_SIZE := Vector2(FactorySim.GRID_COLS * CELL, FactorySim.GRID_ROWS * CELL)
const SKY_COLOR := Color(0.09, 0.11, 0.16)         ## open air ABOVE the surface (the gradient's mid tone)
## PARALLAX ridgeline layers: factor = how world-locked (1 = terrain speed, 0 = pinned
## to the camera — smaller reads further away), drop = px below the horizon band the ridge crests sit,
## amp = crest height. Far hills are lighter (atmospheric haze), near hills darker.
##
## THREE PLANES, NOT TWO (#A2). With two ranges the backdrop still collapsed into "cardboard on sky":
## the far range was much darker than the sky behind it, which is the opposite of what distance does,
## so high contrast read it as NEAR and the scene had no middle. A third, farthest range now sits
## almost in the sky's own value, and SkyPainter's aerial-perspective lerp falls off far more steeply
## across the set (see its ridge loop), so the three ranges land at clearly different distances instead
## of three shades of the same one. The nearest range keeps its near-black silhouette — with real haze
## in front of it, it finally reads as the thing closest to you rather than as more of the same.
const RIDGES: Array[Dictionary] = [
	{"factor": 0.12, "drop": 205.0, "amp": 185.0, "freq": 0.004, "color": Color(0.235, 0.290, 0.400)},
	{"factor": 0.24, "drop": 150.0, "amp": 150.0, "freq": 0.006, "color": Color(0.145, 0.165, 0.225)},
	{"factor": 0.44, "drop": 55.0, "amp": 110.0, "freq": 0.010, "color": Color(0.062, 0.072, 0.112)},
]
## THE SINKFORGE — the endgame LANDMARK (greenlit 2026-08-07). A colossal DORMANT ancient machine whose
## CROWN breaches the surface: a broken cog-ring on a dead industrial pylon, buttressed by leaning
## pillars. It is the TIP of a colossus that SPANS the depth layers — its heart is at the core, many
## layers down (the endgame), and you descend ALONGSIDE it. A faint ember breathes at the cog's core:
## the machine is dormant, not extinct — the only warm thing on the dead crown, and the seed of the
## later "watch it thrum" payoff. Drawn in the backdrop (z -20) at a low parallax factor so it sits far
## on the horizon and stays roughly in view as you cross the surface (a seen destination = pilgrimage);
## the near ridge occludes its base (rising FROM behind the hills), and the walls cover it once you
## descend. Pure cosmetic — the sim never knows it exists. Anchored near the map-centre plateau so it
## reads as "you begin standing on top of it; the way is down."
const SINKFORGE_ANCHOR_X: float = 1552.0             ## world x of the crown (over the centred spawn plateau)
const SINKFORGE_FACTOR: float = 0.20                 ## distant-hill parallax: far, always roughly on the horizon
const SINKFORGE_SCALE: float = 1.28                  ## master size dial (imposing — the endgame megastructure)

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
## Tiles of shallow light-scatter under an exposed surface. Real ground near daylight is not black —
## light bounces into the first several feet of earth, and a game that cuts to pitch one tile down turns
## the bottom third of the opening frame into a void the player reads as "the world ends here" (#S3).
## Seven tiles is roughly the topsoil band, so the dirt layer reads AS DIRT from the surface and the dark
## begins where the player has actually descended into it.
const SKY_FADE: int = 7
## How dark the deep gets, on a 0 (full light) .. 1 (pitch) scale. Read by _light_level, which turns it
## into the multiplier the veil actually applies. The lamp/machine/crystal pools still cut this back to
## ~0, so the "bring your own light" pillar holds and lit rock pops hard out of the gloom.
## History: 0.87 (rock invisible) → 0.74 (structure lost in the murk) → 0.66.
const AMBIENT_DARK: float = 0.66
## THE COLOUR OF FULL GLOOM — as a MULTIPLIER, not a wash (#S3). Skylight-only ambient is cool and
## dim, so the deep both darkens and cools in the single operation. Because it multiplies, a cell keeps
## its own hue and its own relative contrast automatically: dark BROWN topsoil stays brown, dark GREY
## stone stays grey, and the bedding, fissures and carved edges painted into the rock survive as
## structure instead of being averaged under a haze. Raising these values lifts the whole deep; the
## RATIO between the channels is what makes shadow read cool.
## Tuned by measurement, not by eye: at (0.24, 0.28, 0.38) the deep printed unlit dirt at rgb(6,10,24)
## and unlit stone at rgb(8,14,31) — a 4:1 blue bias that erased every material's hue and left two very
## different rocks separated by four units of luminance. Barely cool and appreciably brighter keeps the
## material read (brown earth stays brown, grey stone stays grey) while the deep still plainly needs a lamp.
const AMBIENT_LIGHT := Color(0.34, 0.35, 0.42)
const LAMP_COLOR := Color(1.0, 0.82, 0.50)          ## the miner's warm head-lamp — a SATURATED amber core
                                                   ## (was pale 1.0/.90/.66) so the pool reads warm-gold, not
                                                   ## a white wash (diff 11)
const LAMP_RADIUS: float = CELL * 3.9               ## a warm pool with a higher-contrast falloff (was 4.0)
const LAMP_LEAD: float = CELL * 1.9                 ## how far the beam pool leads toward the aim (#44)

## --- Day/night (cosmetic-first) ---------------------------------------------------
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
var payouts: Payouts                                  ## the "+N" gain ticks off a broken block (set by MainView)

var _font: Font = ThemeDB.fallback_font
var _anim_time: float = 0.0                          ## free-running cosmetic clock (never feeds the sim)
var _materials: Dictionary = {}                      ## id -> MaterialDef (world-engine viz registry)
## MACHINE CONSTRUCT ANIMATION: cell -> elapsed seconds since placement. MainView
## pokes note_machine_built() on a real build (never on boot/load — pre-existing machines don't animate,
## the note_dig pattern). A short one-shot assemble overlay (flash + rising scan + bracket snap) plays.
var _construct: Dictionary = {}
const CONSTRUCT_DUR: float = 0.38
## MINE CRUMBLE: a just-mined block shatters into four chunks that fly apart, fall
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
## THE SCANNER pulse (pushed by try_scan): origin + age drive an expanding wavefront;
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
## COARSE TERRAIN BAKE (perf): the chunk painters above draw the static ~7700-cell coarse terrain, which
## on a mature base was ~72% of the frame's draw calls (~11,882). They're STATIC-per-terrain-change, so we
## host the chunk canvases inside a world-sized SubViewport (transparent bg) and draw its render-target as
## ONE textured quad at z -10 — pixel-identical by construction (same draw code), ~11k fewer draw calls.
## The viewport re-renders ONLY when a chunk was dirtied (terrain change), via render_target_update_mode
## UPDATE_ONCE; between changes the GPU replays the single quad for free.
var _terrain_viewport: SubViewport                    ## world-in-pixels canvas the chunk painters render into
var _terrain_layer: LightLayer                        ## the ONE quad in the main tree that draws the bake (z -10)
var _back: LightLayer      ## the parallax backdrop (sky gradient + ridgelines + clouds), z -20
## FINE TERRAIN MOLDING (Noita-look slice 1): the coarse 32px terrain fill re-rendered as an organic,
## molded 8px-grain field baked to one texture (scenes/fine_terrain.gd), drawn OVER the chunk terrain
## (which keeps drawing walls + the surface cap) so the blocky cell edges become curved. Rebuilt only
## on terrain change (_fine_dirty), never per frame — the same repaint-on-change discipline as the veil.
var _fine: FineTerrain
var _fine_layer: LightLayer
var _fine_dirty: bool = true                     ## FULL rebake pending (initial paint / load) — the slow lane
## THE PER-DIG FAST LANE (#102): a dig accumulates the coarse bounding box of this frame's changed cells so
## the fine baker patches only that region (dirty-chunks), instead of re-processing the whole ~120k grid.
var _fine_region_pending: bool = false
var _fine_dirty_min: Vector2i = Vector2i.ZERO
var _fine_dirty_max: Vector2i = Vector2i.ZERO
var _dark: LightLayer
## THE LIGHTMAP VEIL: the darkness is a small texture — ONE TEXEL PER CELL (RGB =
## the shadow colour, zone-tinted; A = darkness) — stretched over the whole world with LINEAR
## filtering, so light grades smoothly in EVERY direction instead of stepping cell to cell. The
## skylight/ambient BASE bakes only when terrain or the daylight step changes (_veil_dirty); each
## frame the base is copied and the live light sources CUT holes in it (lamp/torches/machines/
## conduits/falling drops), so where light falls the veil OPENS and the world shows its true
## colours under the additive warmth — light reveals, not just tints.
var _veil_img: Image
var _veil_tex: ImageTexture
var _veil_base: PackedByteArray
var _veil_scratch: PackedByteArray   ## persistent per-frame veil buffer — base memcpy'd in, holes cut (#3, no per-frame .duplicate)
var _veil_dirty: bool = true
## Crystal seams (#4): the O(exposed-ore^2) flood is cached across frames and shared by _update_veil +
## _paint_lights (which both need the identical seam list). It only changes when ore EXPOSURE changes
## (terrain dug/placed near ore) or when the culling view-rect moves (a seam pans on/off screen), so it
## is recomputed on either signal and otherwise replayed. Invalidated in the terrain-dirty block below.
var _crystal_seams_cache: Array[Dictionary] = []
var _crystal_seams_valid: bool = false
var _crystal_seams_view: Rect2 = Rect2()
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
		"res://src/data/materials/shale.tres",
		"res://src/data/materials/deepslate.tres",
		"res://src/data/materials/wood.tres",
		"res://src/data/materials/leaves.tres",
		"res://src/data/materials/sealrock.tres",
		"res://src/data/materials/iron.tres",
		"res://src/data/materials/dirt_wall.tres",
		"res://src/data/materials/stone_wall.tres",
		"res://src/data/materials/shale_wall.tres",
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
	# The chunk painters render into a world-sized SubViewport (a flat 3072×2560 canvas, no camera, so a
	# chunk's world-space draw lands 1:1 at pixel coords) with a TRANSPARENT background so the sky above
	# ground stays see-through (the backdrop shows). update_mode DISABLED = it never re-renders on its own;
	# we flip it to UPDATE_ONCE only when a chunk is dirtied (below), preserving the per-dig fast lane.
	_terrain_viewport = SubViewport.new()
	_terrain_viewport.size = Vector2i(FactorySim.GRID_COLS * CELL, FactorySim.GRID_ROWS * CELL)
	_terrain_viewport.transparent_bg = true
	_terrain_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_terrain_viewport.disable_3d = true
	_terrain_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_terrain_viewport)
	for cy: int in _chunk_rows:
		for cx: int in _chunk_cols:
			var rect := Rect2i(cx * CHUNK, cy * CHUNK, CHUNK, CHUNK)
			var chunk := LightLayer.new()
			chunk.setup(-10, _paint_terrain_chunk.bind(rect))  # painter(ci, rect) draws only this block
			_terrain_viewport.add_child(chunk)                        # renders into the bake viewport, not the main tree
			_chunks.append(chunk)
	# The ONE quad in the main tree that draws the baked coarse terrain (where the ~7700 chunk draws were,
	# z -10). Drawn at the world rect 1:1 with NEAREST filter so it lines up crisply with the pixel-snap
	# camera (#77) — unlike the veil which is intentionally low-res + linear. Content updates via the viewport.
	_terrain_layer = LightLayer.new()
	_terrain_layer.setup(-10, _paint_terrain_bake)
	_terrain_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_terrain_layer)
	# The PARALLAX BACKDROP sits BELOW the terrain chunks (z -20), repainted per frame:
	# a vertical sky gradient + two drifting ridgelines + slow clouds. The chunk background pass no
	# longer fills opaque sky, so the vista shows wherever no wall backs a cell (above ground); the
	# walls hide it underground for free.
	_back = LightLayer.new()
	_back.setup(-20, _paint_backdrop)
	add_child(_back)
	# The FINE TERRAIN mold (Noita-look): baked once here, drawn stretched over the chunk terrain
	# (z -9, above the -10 blocky fill, below all dynamic content). Nearest filter keeps the 8px fine
	# pixels crisp. It rebuilds only when the terrain changes (_fine_dirty), like the veil below.
	_fine = FineTerrain.new(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, 1337)
	_fine_layer = LightLayer.new()
	_fine_layer.setup(-9, _paint_fine_terrain)
	_fine_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_fine_layer)
	_bake_fine_terrain()
	# Two world-space canvases ABOVE this renderer's draw — the skylight/darkness veil, then light pools.
	_glow_tex = _make_glow_texture()
	_dark = LightLayer.new()
	_dark.setup(50, _paint_darkness, CanvasItemMaterial.BLEND_MODE_MUL)
	# The lightmap veil (#17): the darkness texture is tiny (one texel per cell) and the LINEAR
	# filter on the stretch is what turns per-cell values into smooth gradients across the world.
	_dark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_dark.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_veil_img = Image.create(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, false, Image.FORMAT_RGBA8)
	_veil_tex = ImageTexture.create_from_image(_veil_img)
	add_child(_dark)
	_lights = LightLayer.new()
	_lights.setup(51, _paint_lights, CanvasItemMaterial.BLEND_MODE_ADD)
	add_child(_lights)
	# THE DISTORTION PASS: one shared screen-warp shader; consumers draw masked quads.
	# Proven here on machine heat-haze. Sits ABOVE the world + veil but UNDER the additive light pools
	# (hot air bends the scene, lamplight stays crisp).
	_haze = LightLayer.new()
	_haze.setup(46, _paint_heat_haze)
	var haze_mat := ShaderMaterial.new()
	haze_mat.shader = load("res://scenes/heat_haze.gdshader")
	_haze.material = haze_mat
	add_child(_haze)
	for chunk: LightLayer in _chunks:
		chunk.queue_redraw()  # initial full paint (once); thereafter only dirtied chunks repaint
	_terrain_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE  # bake the initial coarse terrain once
	_terrain_layer.queue_redraw()
	sim.terrain_dirty.clear()  # drop any dirt from world-seeding — the initial paint above already covers it
	_dark.queue_redraw()  # the veil's ONE draw command (the stretched lightmap); content updates via the texture


## Full-world repaint, for when the terrain changed WHOLESALE under the retained caches (loading a
## save). Requeues every terrain chunk + the skylight veil and drops the lazy seal-row cache. The
## incremental terrain_dirty path stays the per-dig fast lane; this is the load-time reset.
func repaint_world() -> void:
	for chunk: LightLayer in _chunks:
		chunk.queue_redraw()
	if _terrain_viewport != null:
		_terrain_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE  # re-bake the whole coarse terrain
		_terrain_layer.queue_redraw()
	_veil_dirty = true
	_fine_dirty = true
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


## The player's PING (set by clicking the minimap; Vector2.INF = none): drawn in-world
## as a pulsing beacon so "the spot I marked on the map" is findable when you walk up to it.
func set_ping(world: Vector2) -> void:
	_ping_world = world


## Begin a SONAR pulse: the controller computed the echoes (a pure deposits query);
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
	# The head-lamp FOLLOWS THE AIM: the pool leads from the head toward the cursor
	# (capped), eased so a mouse flick swings the beam like a worn lamp, not a snapped spotlight.
	# Cursor on/next to the body → fall back to plain facing so the light never collapses onto you.
	if player != null:
		var head: Vector2 = player.position + Vector2(0.0, -Player.HEIGHT * 0.30)
		var to_aim: Vector2 = _cell_center(_aim) - head
		var target: Vector2 = Vector2(float(player.facing) * float(CELL) * 0.7, -float(CELL) * 0.2)
		if to_aim.length() > float(CELL) * 0.9:
			target = to_aim.limit_length(LAMP_LEAD)
		_lamp_offset = _lamp_offset.lerp(target, 1.0 - exp(-9.0 * delta))
	_spawn_water_drips(delta)   # cosmetic drips shed off pouring water — motion cue (view-culled, rate-limited)
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
		var rmin := Vector2i(1 << 30, 1 << 30)        # coarse bounding box of the changed cells (fine fast lane)
		var rmax := Vector2i(-(1 << 30), -(1 << 30))
		for cell: Vector2i in sim.terrain_dirty:
			rmin.x = mini(rmin.x, cell.x); rmin.y = mini(rmin.y, cell.y)
			rmax.x = maxi(rmax.x, cell.x); rmax.y = maxi(rmax.y, cell.y)
			# All 8 neighbours + self: edge-AO/caps read orthogonally, and the autotile chamfer/fillet
			# passes (#9) read across CORNERS too — a dig at a chunk corner must repaint the diagonal chunk.
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var idx: int = _chunk_index(cell + Vector2i(dx, dy))
					if idx >= 0:
						dirty[idx] = true
		for idx: int in dirty:
			_chunks[idx].queue_redraw()
		# Re-bake the coarse-terrain viewport ONCE this frame (only the dirtied chunks actually repaint their
		# retained buffers inside it) and re-draw the single quad that shows it. The per-dig fast lane holds:
		# ~64 cells re-issue their draw commands into the viewport, not the whole world, and the bake is a
		# no-op on frames with no terrain change.
		_terrain_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_terrain_layer.queue_redraw()
		sim.terrain_dirty.clear()
		_leaf_cache_dirty = true   # a felled tree stops shedding leaves
		_crystal_seams_valid = false   # a dig/place near ore changes which cells are EXPOSED — reflood the seams (#4)
		# The mold follows the dug shape — but patch ONLY the changed region's fine cells (dirty-chunks,
		# #102), not the whole grid: the per-dig freeze was the full fine rebake this used to trigger.
		_fine_region_pending = true
		_fine_dirty_min = rmin
		_fine_dirty_max = rmax
		# The veil is a pure LIGHT LEVEL now (#S3) — it carries no material colour at all, so a dig never
		# patches its hue. Only the skylight base cares, because a dig can move the surface line.
		_veil_dirty = true
	if _fine_dirty:
		_bake_fine_terrain()          # FULL rebake (initial / load) — the slow lane
	elif _fine_region_pending:
		_bake_fine_region(_fine_dirty_min, _fine_dirty_max)   # the per-dig fast lane
		_fine_region_pending = false


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
	_draw_water()      # the L3 fluid layer — translucent blue pools filling each cell to its water line
	_draw_surface_life()  # drifting leaves off the canopies + the occasional bird — the surface breathes
	falling.draw(self)
	# Cull machines whose cell is off-screen. Margin 3 cells so a partially-on-screen machine's glow,
	# held-count badge, I/O ports, status bubble and contact shadow (all reaching past its own cell)
	# aren't clipped at the view edge. Off-screen machines aren't visible → skipping is pixel-identical.
	var mview: Rect2 = _view_world_rect(3.0)
	for machine: MachineState in sim.machines:
		if not mview.has_point(Vector2(machine.cell) * float(CELL)):
			continue
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
	_draw_speed_streaks()  # motion lines behind a body moving faster than it can run
	_draw_grapple()        # the live line + its hook, over the world and under the HUD
	_draw_aim()
	if payouts != null:
		payouts.draw(self)  # "+N" gain ticks LAST: the reward should never be buried by the world


## THE SONAR: an expanding wavefront ring from the body, and — as it passes each vein's
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


## The in-world PING beacon: a cyan pin bobbing over the marked spot + an expanding
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


## The painted dig PLAN: each marked cell wears amber corner brackets + a whisper of
## fill, breathing gently so the plan reads as "queued for the pick", quieter than the aim cursor and
## the objective rings. Marks are the controller's live dict; stale entries are its job to prune.
func _draw_dig_marks() -> void:
	if _dig_marks.is_empty():
		return
	var view: Rect2 = _view_world_rect()
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


## Living veins: one fleck per ore cell FLARES briefly on a slow per-cell staggered
## schedule, so a vein glitters in the lamplight and discovery reads from across a dark cavern. Walks
## sim.deposits (the sparse seeded-vein index — never the whole world) clipped to the camera view.
## THE SEAL gets its own tell: a slow faint violet breath along its two rows (lazy row scan). Pure
## cosmetics on the free-running clock; the sim never sees any of it.
## SURFACE LIFE: the top of the world stops reading static. Each canopy cell sheds a
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
	var view: Rect2 = _view_world_rect(4.0)
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


## CRYSTAL/ORE GLOW (fix-2 diff 2 / diff-04 #5) — Sinkforge's cool accent light. The reference's coloured
## light lives in BIG COHESIVE features, not scattered dots, so instead of glowing isolated hash-gated
## cells we CLUSTER nearby exposed ore into a few cohesive SEAMS: flood-connect adjacent exposed vein
## cells, then emit ONE glow per cluster (centroid + a radius that grows with the cluster's extent). A
## few large cool seam-glows read as crystal veins in the rock, not confetti. Both _update_veil (cuts a
## cool hole) and _paint_lights (lays the cyan pool) call this, so reveal + glow never disagree.
const CRYSTAL_COLOR := Color(0.34, 0.86, 1.0)          ## saturated cyan-teal — the cool pole vs the warm lamp
const CRYSTAL_MAX: int = 6                             ## hard cap of glowing seams on screen (taste ceiling)
const CRYSTAL_MIN_CELLS: int = 2                       ## a seam needs >= this many exposed cells to glow (kills lone specks)

## The exposed-ore cells in view (still solid, has-nuggets, touching a carved cavity) — the raw material
## a seam is built from. Split out so the clustering can walk it deterministically.
func _exposed_ore_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var view: Rect2 = _view_world_rect()
	for key: Variant in sim.deposits:
		var c: Vector2i = key
		var pos := Vector2(c) * float(CELL)
		if not view.has_point(pos) or not sim.is_solid(c):
			continue
		var md: MaterialDef = _material(sim.material_at(c))
		if not md.has_nuggets() or not md.glitters:  # coal has nuggets but does NOT glitter (it's fuel, not a gem)
			continue
		# Only EXPOSED ore glows: a crystal seam catches light where it meets a carved cavity, so at least
		# one orthogonal neighbour must be open air — confines the accent to carved edges (where you are).
		if sim.is_solid(c + Vector2i(0, -1)) and sim.is_solid(c + Vector2i(0, 1)) \
				and sim.is_solid(c + Vector2i(-1, 0)) and sim.is_solid(c + Vector2i(1, 0)):
			continue
		out.append(c)
	return out


## Cluster the exposed-ore cells into cohesive SEAMS (diff-04 #5). Greedy flood: pop a cell, absorb every
## still-unclaimed cell within CLUSTER_LINK of it (chained via a growing frontier), and emit the group as
## one glow {pos = centroid, radius = base + extent}. Deterministic (iterates a sorted cell list); a few
## big glows instead of many dots. Lone/tiny clusters (< CRYSTAL_MIN_CELLS) are dropped as noise.
const CLUSTER_LINK: int = 3                             ## cells within this chebyshev distance join one seam
func _crystal_seams() -> Array[Dictionary]:
	var cells: Array[Vector2i] = _exposed_ore_cells()
	cells.sort()                                        # deterministic flood order
	var seams: Array[Dictionary] = []
	var claimed: Dictionary = {}
	for start: Vector2i in cells:
		if claimed.has(start):
			continue
		var group: Array[Vector2i] = [start]
		claimed[start] = true
		var i: int = 0
		while i < group.size():                         # grow the frontier by chained proximity
			var g: Vector2i = group[i]
			i += 1
			for other: Vector2i in cells:
				if claimed.has(other):
					continue
				if absi(other.x - g.x) <= CLUSTER_LINK and absi(other.y - g.y) <= CLUSTER_LINK:
					claimed[other] = true
					group.append(other)
		if group.size() < CRYSTAL_MIN_CELLS:
			continue
		var sum := Vector2.ZERO
		var lo := Vector2(group[0])
		var hi := Vector2(group[0])
		for gc: Vector2i in group:
			sum += Vector2(gc)
			lo = lo.min(Vector2(gc))
			hi = hi.max(Vector2(gc))
		var centroid: Vector2 = (sum / float(group.size()) + Vector2(0.5, 0.5)) * float(CELL)
		var extent: float = (hi - lo).length() * float(CELL)          # diagonal span of the seam
		var radius: float = float(CELL) * 2.2 + extent * 0.55         # bigger seam -> bigger cohesive glow
		seams.append({"pos": centroid, "radius": radius, "cells": group})
		if seams.size() >= CRYSTAL_MAX:
			break
	return seams


## The FRAME accessor for crystal seams (#4): the raw _crystal_seams() flood is O(exposed-ore^2) and was
## run TWICE per frame (once in _update_veil, once in _paint_lights). It only changes when ore exposure
## changes (a dig/place near ore → _crystal_seams_valid cleared) or when the culling view-rect pans (a
## seam scrolls on/off screen). Recompute on either signal; otherwise replay the cached list, so both the
## veil cut and the light pool read the IDENTICAL seams (they never disagree, and it floods once, not
## twice). Note _crystal_seams() itself stays the pure compute (the profiler measures it in isolation).
func _crystal_seams_cached() -> Array[Dictionary]:
	var view: Rect2 = _view_world_rect()
	if not _crystal_seams_valid or view != _crystal_seams_view:
		_crystal_seams_cache = _crystal_seams()
		_crystal_seams_view = view
		_crystal_seams_valid = true
	return _crystal_seams_cache


## The GLOW COLOUR for an ore seam — derived from the seam's OWN material so the accent light AGREES with
## the flecks in the rock (the blind-playtest fix: no more cyan glow contradicting orange ore). Takes the
## first cell's material `nugget_color` and pushes it toward saturation (a light source reads as a
## purer hue than the embedded speck). A material with no nuggets falls back to the cool CRYSTAL_COLOR so
## any genuinely-cool future material still glows cool.
func _seam_glow_color(cells: Array) -> Color:
	if cells.is_empty():
		return CRYSTAL_COLOR
	var first: Vector2i = cells[0]
	var def: MaterialDef = _material(sim.material_at(first))
	if not def.has_nuggets():
		return CRYSTAL_COLOR
	var glow: Color = def.nugget_color
	# Push toward saturation: emitted light is a purer hue than the fleck. Nudge S up, keep V bright.
	glow = Color.from_hsv(glow.h, minf(1.0, glow.s + 0.20), maxf(glow.v, 0.85))
	return glow


func _draw_ore_glints() -> void:
	var view: Rect2 = _view_world_rect()
	const PERIOD: float = 3.4
	const FLARE_LEN: float = 0.5
	for key: Variant in sim.deposits:
		var c: Vector2i = key
		var pos := Vector2(c) * float(CELL)
		if not view.has_point(pos) or not sim.is_solid(c):
			continue
		var def: MaterialDef = _material(sim.material_at(c))
		if not def.has_nuggets() or not def.glitters:  # coal reads as dark clusters, not glinting gems
			continue
		# Only EXPOSED ore glints — a fleck catches the light at a dug face, not buried in solid rock. Ore
		# twinkling everywhere (incl. cells sealed inside stone) reads as a floating STARFIELD; gating to
		# exposed faces clusters the sparkle onto the vein you've actually dug into, so it reads as a VEIN.
		# (Discovery from across a dark cavern still works — the cohesive crystal-SEAM glows carry that.)
		if sim.is_solid(c + Vector2i(0, -1)) and sim.is_solid(c + Vector2i(0, 1)) \
				and sim.is_solid(c + Vector2i(-1, 0)) and sim.is_solid(c + Vector2i(1, 0)):
			continue
		var h: int = ((int(c.x) * 73856093) ^ (int(c.y) * 19349663)) & 0x7fffffff
		var offset: float = float(h % 997) / 997.0 * PERIOD
		var t: float = fmod(_anim_time + offset, PERIOD)
		if t > FLARE_LEN:
			continue
		var glint_dark: float = clampf(_skylight_alpha(c.y, sim.surface_row(c.x)) / AMBIENT_DARK, 0.0, 1.0)
		if glint_dark <= 0.05:                                  # a lit surface vein reads as rock, not a sparkle
			continue
		var flare: float = sin(t / FLARE_LEN * PI)              # 0 -> 1 -> 0 across the flare window
		var nubs: Array[Vector2] = _cell_speckles(c, def.nugget_count)
		var cycle: int = int((_anim_time + offset) / PERIOD)    # a different fleck flares each cycle
		var p: Vector2 = pos + nubs[cycle % nubs.size()]
		var col: Color = def.nugget_color.lightened(0.65)
		col.a = 0.85 * flare * glint_dark
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
	TerrainPainter.paint(self, ci, rect)   # solid cells in this chunk (ends with the surface cap pass for its columns)


## Draw the baked COARSE terrain (the SubViewport render-target) as ONE quad at z -10 — the ~11,882-draw
## chunk pass collapsed to a single textured rect. World rect 1:1, NEAREST filter so it snaps crisply with
## the pixel-snap camera. The render-target already holds the chunk painters' exact output (same draw code),
## so this is pixel-identical to the old per-chunk pass; it only re-renders on a terrain change.
func _paint_terrain_bake(layer: LightLayer) -> void:
	if _terrain_viewport == null:
		return
	layer.draw_texture_rect(_terrain_viewport.get_texture(),
		Rect2(Vector2.ZERO, WORLD_SIZE), false)


## Draw the placed power conduits: each tube is a copper segment with stubs to whatever
## it couples to (adjacent conduits, the generator feeding it, a machine drawing from it), and an inner
## CHANNEL that glows from dim to gold by the live power it carries — so a powered trunk reads as a bright
## line pouring down the shaft and a dead tube reads dark. The power level is the derived field, read-only.
func _draw_conduits() -> void:
	const COPPER := Color(0.46, 0.32, 0.20)
	const DIRS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	var view: Rect2 = _view_world_rect(2.0)
	for cell: Variant in sim.conduit:
		var c: Vector2i = cell
		if not view.has_point(Vector2(c) * float(CELL)):
			continue
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


## POWER PULSES: bright beads travel the LIVE conduit network so energy visibly
## FLOWS — down every vertical link and outward (downhill) along laterals, NEVER up (the game's locked
## hook made visible). Bead count + brightness scale with the power the tube carries; a dead tube shows
## nothing. Pure cosmetic clockwork over the copper draw — reads the derived power field, never writes.
const PULSE_SPEED: float = 1.7                        ## links traversed per second by a bead
func _draw_power_pulses() -> void:
	var view: Rect2 = _view_world_rect(2.0)
	for cell: Variant in sim.conduit:
		var c: Vector2i = cell
		if not view.has_point(Vector2(c) * float(CELL)):
			continue
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
	var view: Rect2 = _view_world_rect(2.0)
	for cell: Variant in sim.rope:
		var c: Vector2i = cell
		if not view.has_point(Vector2(c) * float(CELL)):
			continue
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


## Draw the mounted torches: the shared Visuals glyph, live-guttering on the cosmetic
## clock. The warm pool each one casts is painted by _paint_lights; here is just the stick + flame.
func _draw_torches() -> void:
	var view: Rect2 = _view_world_rect(2.0)
	for cell: Variant in sim.torch:
		if not view.has_point(Vector2(cell as Vector2i) * float(CELL)):
			continue
		Visuals.draw_machine_glyph(self, _cell_center(cell), "torch", 1.0, true, _anim_time)


## Draw the planted saplings (#38): a sprout rooted at the cell's floor that grows visibly taller with
## its progress — a just-planted seed is a nub, a nearly-grown one already brushes the cell above. The
## sway is cosmetic; growth itself is sim state (FactorySim.sapling ticks).
func _draw_saplings() -> void:
	var view: Rect2 = _view_world_rect(2.0)
	for cell: Variant in sim.sapling:
		var c: Vector2i = cell
		if not view.has_point(Vector2(c) * float(CELL)):
			continue
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


## DEPTH-ZONE PALETTES: each zone pulls the terrain toward its own temperature, eased
## across a transition band so strata read as different PLACES, not stripes. Topsoil keeps its warm
## material colours (no entry = no tint); Stonereach below THE SEAL chills toward cold slate-blue.
## A new depth layer = one new row here (rows straddle the transition; strength is the held tint).
## THE DESCENT'S COLOUR ARC (#S5). One tint was doing all of this work, and the twenty-odd rows between
## the topsoil and it were a single undifferentiated grey — the heart of the game, and the place a player
## spends the most time, painted in exactly one colour. Depth was being sold by DARKNESS alone, which is
## the weakest of the three signals available and the one the shadow veil is already spending.
##
## Now the descent runs an arc a player can feel without reading a depth gauge: warm ochre clay carries
## the topsoil's warmth a little way down and then loses it, the middle stone sits honestly neutral (the
## rest is measured against it), Stonereach chills hard into slate-blue below the seal, and the last band
## before the bottom of the world goes cold violet toward the sealrock it is approaching. Warm to neutral
## to cold to alien: that is what going deeper looks like when you cannot see a number.
##
## A new depth layer = one new row here. Bands straddle their transition; strength is the held tint.
const ZONE_TINTS: Array[Dictionary] = [
	{"from": 26, "to": 36, "color": Color(0.86, 0.58, 0.30), "strength": 0.22},   # Clayband — warmth to lose
	{"from": 40, "to": 50, "color": Color(0.55, 0.58, 0.66), "strength": 0.16},   # the honest neutral middle
	{"from": 50, "to": 66, "color": Color(0.42, 0.55, 0.90), "strength": 0.34},   # Stonereach (L2)
	{"from": 68, "to": 79, "color": Color(0.40, 0.30, 0.62), "strength": 0.26},   # the approach to the seal
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
	# CONTRAST TO SPEND (#S2). Underground, everything a cell is painted with gets compressed twice —
	# once by depth_darken, then again by the shadow veil sinking it toward a fraction of itself. A
	# tonal range that reads fine in daylight survives that as mush, which is the mechanical reason deep
	# rock looked like fog: the detail was there, scaled down until it stopped being detail. Both the
	# jitter and the bedding therefore get progressively LOUDER with depth, so what reaches the eye
	# after the veil takes its cut is roughly as legible at the bottom of the world as at the top.
	# Measured against a real delve capture, not guessed: at the veil's opacity roughly half a cell's own
	# tonal range survives to the eye, so the compensation has to be well over 2x by the deep band before
	# bedding reads down there at all.
	var boost: float = 1.0 + depth * 2.2
	var j: float = _cell_jitter(c) * boost
	col = col.lightened(j) if j > 0.0 else col.darkened(-j)
	# Bedding is applied RELATIVE to the cell's own colour, then tinted. Absolute band targets looked
	# right against brown topsoil and silently died below it: a dark clay target sits almost exactly on
	# deep stone's own colour, so half the bedding became a no-op in precisely the place that needed it
	# most. Lightening and darkening the cell always swings, whatever the cell happens to be; the tint
	# then rides on top for the hue that makes a band read as a different DEPOSIT and not just shading.
	var s: float = _strata(c) * boost
	if s > 0.0:
		return col.lightened(s * 0.85).lerp(STRATA_WARM, s * 0.30)
	return col.darkened(-s * 1.05).lerp(STRATA_COOL, -s * 0.20)


## SEDIMENTARY BANDING — the ground's own structure. The cell jitter above breaks a field of earth out
## of ONE flat colour, but it drifts in cloudy isotropic patches, which reads as noise on a slab rather
## than as a slab made of something. From the surface, forty cells of untouched dirt were a single brown
## expanse: the largest remaining piece of "flat and two-dimensional", and the reason a shaft felt like
## a hole punched in cardboard instead of a cut through ground.
##
## Bands run HORIZONTALLY (the direction you cut across as you sink) at three incommensurable
## frequencies, so fine laminations and thick beds overlap and the pattern never visibly repeats down a
## shaft. They are warped slowly along x so a layer dips and rises like real bedding instead of ruling a
## straight line across the world. Light bands go sandy and dark bands go to cool clay — a HUE move, not
## just a value one, because value alone would just re-shade the same brown.
##
## Deterministic and RNG-free, and it feeds the fine-terrain bake through the same callable, so a dug
## face exposes the same layer the coarse cell was showing.
const STRATA_WARM := Color(0.86, 0.74, 0.52)   ## the sandy band
const STRATA_COOL := Color(0.15, 0.16, 0.21)   ## the cool clay/silt band
const STRATA_AMOUNT: float = 0.17              ## how far a band pulls toward its colour

func _strata(c: Vector2i) -> float:
	var y: float = float(c.y) + sin(float(c.x) * 0.055) * 2.4 + sin(float(c.x) * 0.021) * 3.6
	# Periods of roughly 18, 7 and 4 cells: a screen holds about twenty rows, so you always see a thick
	# bed, the two or three layers inside it, and the fine laminations between — the whole scale ladder
	# at once, which is what makes ground read as ground.
	var n: float = sin(y * 0.34) * 0.46 + sin(y * 0.88) * 0.36 + sin(y * 1.62) * 0.18
	return n * STRATA_AMOUNT


## A SMOOTH, spatially-coherent value nudge (~[-0.06, +0.06]) — low-frequency sines so neighbouring
## cells share tone (cloudy patches), NOT a per-cell random that seams at every tile edge (which just
## rebuilds the grid). Breaks the flat fill into organic light/dark drift. RNG-free → determinism-safe.
func _cell_jitter(c: Vector2i) -> float:
	var x: float = float(c.x)
	var y: float = float(c.y)
	var n: float = sin(x * 0.37 + y * 0.21) + sin(x * 0.13 - y * 0.41) + sin((x + y) * 0.27)
	return n / 3.0 * 0.06


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


## The current objective's WHERE-cell(s), drawn as a breathing beacon so a new player can't miss where to
## act. "act" = a pulsing white reticle + a bobbing down-arrow over the target (dig this / feed this forge);
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
			# NEUTRAL-WHITE targeting reticle. History: amber read as a campfire (warm ring at ground level),
			# then cyan read faintly as an "energy node" against the ore. A near-white ring on a dark backing
			# is pure "UI marker" — never heat, never magic — and reads on any background.
			var ring := Color(0.92, 0.96, 1.0, 0.55 + 0.40 * pulse)
			var r: float = float(CELL) * (0.62 + 0.12 * pulse)
			# A dark backing ring first so the cyan reads even INSIDE the warm head-lamp pool (the
			# starter vein sits under the miner's lamp).
			draw_arc(center, r, 0.0, TAU, 28, Color(0.02, 0.05, 0.07, 0.6), 4.5)
			draw_arc(center, r, 0.0, TAU, 28, ring, 2.5)
			draw_rect(Rect2(pos + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)), Color(ring.r, ring.g, ring.b, 0.10 + 0.10 * pulse))
		# A bobbing down-pointer floated HIGH ABOVE the cell — out of the lamp wash, into open air —
		# with a tether line back down to the exact rock so the eye tracks marker → target. Dark-outlined
		# so it punches through both the bright lamp AND the bright day sky (reads on any background).
		var lift: float = float(CELL) * (2.9 + 0.35 * pulse)
		var tip := center + Vector2(0.0, -lift)
		var arrow := Color(0.95, 0.98, 1.0, 0.94)
		var dark := Color(0.02, 0.04, 0.06, 0.85)
		# tether: marker down to the cell top
		draw_line(tip + Vector2(0, 4), center + Vector2(0.0, -float(CELL) * 0.5), Color(0.88, 0.93, 1.0, 0.30 + 0.20 * pulse), 2.0)
		# the pointer: a bold outlined chevron, ~1.6x the old size
		var back := PackedVector2Array([tip + Vector2(0, 12), tip + Vector2(-11, -7), tip + Vector2(11, -7)])
		draw_colored_polygon(back, dark)
		draw_colored_polygon([tip + Vector2(0, 9), tip + Vector2(-8, -5), tip + Vector2(8, -5)], arrow)


## An INTERACTABLE outline pulse: a breathing coloured outline + solid corner brackets
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


## THE PARALLAX BACKDROP (day/night sky): what the sky IS when nothing backs a
## cell. A vertical gradient breathing between DAY and NIGHT palettes on the day clock, a sun/moon
## riding its arc, stars fading in after dusk, two ridgeline silhouettes sliding at sub-terrain speed,
## and a few slow clouds. Fully deterministic per frame from the camera + the cosmetic clock.
## Delegates to SkyPainter — the parallax celestial backdrop (sky gradient, stars, sun/moon, clouds, the
## Sinkforge crown, ridgelines). Kept as a method so it stays the far backdrop layer's draw callback (see
## setup()'s _back.setup(..., _paint_backdrop)); the body lives in scenes/sky_painter.gd.
func _paint_backdrop(ci: CanvasItem) -> void:
	SkyPainter.paint(self, ci)


## The REAL background WALL layer (sim.wall): a dug-out cell reveals the carved-room backing behind it.
## Cells with NO wall stay transparent — the parallax backdrop (z -20) shows through, which is what
## makes open sky sky.
##
## THE SECOND PLANE (#S3) — the biggest single reason the game read two-dimensional, and the one that
## hid the longest because every look review was graded on surface captures where dug cells barely
## appear. A tunnel rendered as a flat rectangle at roughly four percent grey. Not dark: EMPTY. A black
## rectangle in a sheet of coloured paper is the definition of flat, and no amount of work on the
## foreground plane can fix it, because the depth cue that matters is the SECOND plane behind it.
##
## The wall was being darkened twice — once in its own paint, and again by the shadow veil whose entire
## job is darkness — so the veil was compounding a value that had already been crushed. Darkness now
## belongs to the veil alone, and the wall's paint describes the MATERIAL: a real rock face, plainly
## visible as a surface, textured like the rock in front of it but flatter and cooler so the two planes
## separate by hue as well as value.
##
## The recess itself comes from the last part: solid rock CASTS onto the wall behind it. Every edge
## where this wall meets solid takes a soft inward shadow, deepest under a ceiling because the world's
## key light comes from above (#A1). That cast is what turns "a hole" into "a room" — it is the same
## cue Terraria leans on, and it costs four neighbour lookups in a pass that only runs on a dig.
## Measured, not guessed: with a 13x7 chamber dug and two torches hung in it, the room's back wall and
## the solid rock around it printed close enough in value that THE ROOM WAS INVISIBLE — you could not
## tell carved space from mass. A back plane has to lose a decisive amount of light, because it is
## further from every source and shadowed by the rock in front of it; half is not too much.
const WALL_RECESS: float = 0.52      ## how far the back plane sits behind the front one, in value
const WALL_COOL := Color(0.16, 0.19, 0.30)   ## the cool it drifts toward (distance desaturates)
const WALL_AO_UNDER: float = 0.62    ## cast shadow on the wall under a solid ceiling — the deepest
const WALL_AO_SIDE: float = 0.34     ## …beside a solid wall
const WALL_AO_ABOVE: float = 0.16    ## …over a solid floor: light reaches a floor, so it stays open
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
			var col: Color = _wall_fill_color(c)
			ci.draw_rect(Rect2(wpos, Vector2(CELL, CELL)), col)
			TerrainPainter.paint_wall_face(self, ci, c, wpos, col)


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
	var view: Rect2 = _view_world_rect(2.0)
	for cell_v: Variant in sim.ground:
		var cell: Vector2i = cell_v
		if not view.has_point(Vector2(cell) * float(CELL)):
			continue
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


## THE WATER (L3 Aquifer/fluids, slice 2 — the render of sim.water). Each watered cell (integer level
## 1..WATER_MAX) draws a TRANSLUCENT blue fill whose HEIGHT is level/WATER_MAX of the cell, anchored at
## the cell's BOTTOM — so a partially-full cell reads a low water line and a settled pool reads a flat
## surface across its top. A lighter surface line makes the waterline legible. Translucent enough that
## the terrain / back-wall behind shows through (water is see-through). Read each frame (water flows
## every tick), never cached — the sim is authoritative; this pass never writes it. Drawn in the main
## world pass (below the z-50 veil), so deep water reads dark and daylit water reads bright, like all
## world content. Clipped to the camera view — most water cells are off-screen.
const WATER_COLOR := Color(0.16, 0.42, 0.72)          ## deep cool blue — reads as water, stays see-through
const WATER_ALPHA: float = 0.58                       ## translucent (mid of the 0.5–0.65 window)
const WATER_SURFACE := Color(0.42, 0.72, 0.95)        ## a brighter waterline so the top edge reads
## A faint COOL self-sheen so a flooded pocket reads as a dim blue presence in the near-black deep (the
## flood hazard must be perceptible before you bring a lamp). Deliberately WEAK — well below a torch/
## crystal seam/lamp — so lit + shallow water looks essentially unchanged and it never reads as a light
## source or lava. Painted on the additive light layer, the same way crystal seams/conduits/motes do.
const WATER_SHEEN := Color(0.32, 0.66, 0.98)          ## cool blue tint for the wet-sheen pool
const WATER_SHEEN_BASE: float = 0.07                  ## floor intensity for a barely-wet cell
const WATER_SHEEN_LEVEL: float = 0.11                 ## added intensity at a brim-full cell (scales by level)
## The surface y (top of the water) a cell would draw for a given integer level, anchored at the cell
## BOTTOM. Higher level => higher surface => SMALLER y. Level 0 => the cell floor (an empty edge).
func _water_surface_y(cell: Vector2i, level: int) -> float:
	var frac: float = clampf(float(level) / float(FactorySim.WATER_MAX), 0.0, 1.0)
	return float(cell.y) * float(CELL) + float(CELL) * (1.0 - frac)


## WATER MOTION CUE (representation-only): a pouring water cell — one with open (non-solid, non-full)
## space directly below it — occasionally sheds a cool-blue DRIP into the particle layer, and where the
## drop lands (the first cell that isn't open air below) a tiny SPLASH. Rate-limited so a steady
## waterfall shimmers with the odd drop, not a firehose: each on-screen pouring cell is gated by a
## per-cell staggered phase (the ore-glint trick) so only a fraction spawn on any frame, and a hard
## per-frame cap bounds the total. View-culled — off-screen water costs one has_point() and skips.
## Never touches the sim (reads water/solid, writes only the cosmetic `particles` layer via randf).
const WATER_DRIP_PERIOD: float = 0.9                  ## a cell sheds at most one drip per this window
const WATER_DRIP_MAX_PER_FRAME: int = 6               ## hard cap so a wide sheet can't flood the pool
func _spawn_water_drips(delta: float) -> void:
	if particles == null or sim.water.is_empty():
		return
	var view: Rect2 = _view_world_rect()
	var cell_f: float = float(CELL)
	var spawned: int = 0
	for key: Variant in sim.water:
		if spawned >= WATER_DRIP_MAX_PER_FRAME:
			break
		var c: Vector2i = key
		var level: int = int(sim.water[c])
		if level <= 0:
			continue
		var base := Vector2(c) * cell_f
		if not view.has_point(base):
			continue
		# "Pouring" = the cell below is in-bounds, not solid, and has room for more water (the sim's own
		# fall rule). A cell sitting on a full pool or on rock is settled — no drip.
		var below: Vector2i = c + Vector2i(0, 1)
		if not sim.in_bounds(below) or sim.is_solid(below) or sim.water_at(below) >= FactorySim.WATER_MAX:
			continue
		# Per-cell staggered probabilistic gate: a stable hash phase spreads the cells across the period
		# so they don't all pop on the same frame, and the chance scales with delta so the rate is
		# frame-rate independent (~one drip per WATER_DRIP_PERIOD per pouring cell).
		var h: int = ((int(c.x) * 73856093) ^ (int(c.y) * 19349663)) & 0x7fffffff
		var phase: float = float(h % 997) / 997.0
		if randf() > delta / WATER_DRIP_PERIOD * (0.7 + 0.6 * phase):
			continue
		# Drip is shed at the water's own surface line, mid-cell — it then falls under gravity.
		var surf_y: float = _water_surface_y(c, level)
		particles.water_drip(Vector2(base.x + cell_f * 0.5, surf_y + 2.0))
		spawned += 1
		# A small splash where the pour LANDS: scan down the open column to the first blocker (rock or a
		# full-water surface). Only if it's reasonably close + on-screen, so we don't chase a bottomless
		# shaft or splash off-view. Occasional (half the drips) so it stays subtle.
		if randf() < 0.5:
			var land: Vector2i = below
			var steps: int = 0
			while steps < 8 and sim.in_bounds(land + Vector2i(0, 1)) \
					and not sim.is_solid(land + Vector2i(0, 1)) \
					and sim.water_at(land + Vector2i(0, 1)) < FactorySim.WATER_MAX:
				land += Vector2i(0, 1)
				steps += 1
			var lpos := Vector2(land) * cell_f + Vector2(cell_f * 0.5, cell_f)
			if view.has_point(Vector2(land) * cell_f):
				particles.water_splash(lpos)


func _draw_water() -> void:
	if sim.water.is_empty():
		return
	var view: Rect2 = _view_world_rect()
	var fill := Color(WATER_COLOR.r, WATER_COLOR.g, WATER_COLOR.b, WATER_ALPHA)
	var line := Color(WATER_SURFACE.r, WATER_SURFACE.g, WATER_SURFACE.b, minf(1.0, WATER_ALPHA + 0.22))
	var cell_f: float = float(CELL)
	for key: Variant in sim.water:
		var c: Vector2i = key
		var level: int = int(sim.water[c])
		if level <= 0:
			continue
		var base := Vector2(c) * cell_f
		if not view.has_point(base):
			continue
		# Fill anchored at the BOTTOM (fills upward from the floor). The TOP EDGE is smoothed: each side of
		# the surface is the AVERAGE of this cell's surface y and the horizontal neighbour's surface y, so a
		# level pool draws a near-flat top and a level STEP tapers into a ramp instead of a hard stair. A
		# side with NO water neighbour keeps this cell's own height (pool edges stay crisp).
		var floor_y: float = base.y + cell_f
		var mid_y: float = _water_surface_y(c, level)
		var left_lvl: int = sim.water_at(c + Vector2i(-1, 0))
		var right_lvl: int = sim.water_at(c + Vector2i(1, 0))
		# Left edge = average with the left neighbour's surface (or this cell's own if there's none).
		var left_y: float = mid_y
		if left_lvl > 0:
			left_y = 0.5 * (mid_y + _water_surface_y(c + Vector2i(-1, 0), left_lvl))
		# Right edge = average with the right neighbour's surface (or this cell's own if there's none).
		var right_y: float = mid_y
		if right_lvl > 0:
			right_y = 0.5 * (mid_y + _water_surface_y(c + Vector2i(1, 0), right_lvl))
		# The fill as a quad: sloped top (left_y..right_y) down to the flat cell floor. Same colour+alpha.
		var tl := Vector2(base.x, left_y)
		var tr := Vector2(base.x + cell_f, right_y)
		var br := Vector2(base.x + cell_f, floor_y)
		var bl := Vector2(base.x, floor_y)
		draw_colored_polygon(PackedVector2Array([tl, tr, br, bl]), fill)
		# The brighter waterline rides the smoothed top edge (a thin quad, 2px thick, following the slope).
		draw_colored_polygon(PackedVector2Array([
			tl, tr, Vector2(tr.x, right_y + 2.0), Vector2(tl.x, left_y + 2.0)]), line)


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


## The drop-in ANIMATION standard: how fast the 2-frame working cycle chugs.
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


## The zoom at/above which per-machine TEXT decorations (name label, held badge, need bubble) are legible
## enough to draw for EVERY on-screen machine. Below it (the locked 0.50× default + the 0.33× survey view)
## only the HOVERED/aimed machine shows its text; the rest stay clean glyphs (readable at a glance, and
## no wall of unreadable tiny labels on a big base). The zoom is the canvas transform's scale — a camera
## zoom of 0.70 (the inspect level) gives a canvas scale of 0.70. Threshold below 0.70, above 0.50.
const TEXT_ZOOM: float = 0.65


## Should this machine's TEXT decorations draw? Yes when zoomed in enough to read them, OR when it's the
## machine the player is aiming at (so pointing at any box always reads its label/status, even zoomed out).
func _text_visible(cell: Vector2i) -> bool:
	if cell == _aim:
		return true
	return get_canvas_transform().get_scale().x >= TEXT_ZOOM


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
	# 2-frame machine_<id>_work_0/1 cycle plays; the badge / progress
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

	# TEXT DECORATIONS are gated (perf + de-clutter): the name label, the held-count badge, and the
	# stalled NEED bubble are drawn ONLY when the text is actually readable (zoomed IN past _text_zoom)
	# OR this is the HOVERED/aimed machine (so pointing at any box still reads its label/status even
	# zoomed out). At the locked 0.50× default those labels are a few px tall — unreadable clutter — and
	# draw_string is the priciest per-call, so on a mature base the non-hovered machines drop their text.
	# The info isn't lost: the HUD hover inspector shows a machine's full details on hover regardless.
	var show_text: bool = _text_visible(machine.cell)
	if show_text:
		_draw_machine_label(machine, pos)

	var held: int = _held(machine)
	if show_text and held > 0:
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
	_draw_machine_status(machine, pos, show_text)
	if _construct.has(machine.cell):     # the one-shot assemble overlay (#9), on top of the finished draw
		_draw_construct(pos, clampf(float(_construct[machine.cell]) / CONSTRUCT_DUR, 0.0, 1.0))


## The one-shot ASSEMBLE overlay for a just-placed machine: a settling flash that
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
func _draw_machine_status(machine: MachineState, pos: Vector2, show_bubble: bool = true) -> void:
	var status: StringName = sim.machine_status(machine)
	var lamp: Color
	match status:
		&"working": lamp = Color(0.35, 0.92, 0.42)
		&"no_fuel": lamp = Color(0.96, 0.26, 0.20)
		&"no_input": lamp = Color(0.97, 0.72, 0.22)
		_: lamp = Color(0.52, 0.55, 0.62)          # idle
	# Status lamp: a rimmed dot in the machine's top-left corner (mirrors Factorio's entity status light).
	# The lamp is a glanceable COLOUR (like the glyph), not text — it stays ALWAYS on so a red/amber
	# stall still reads from across a zoomed-out base. Only the floating text-ish NEED bubble is gated.
	var lamp_c: Vector2 = pos + Vector2(5.5, 5.5)
	draw_circle(lamp_c, 4.2, Color(0.03, 0.03, 0.05, 0.9))
	draw_circle(lamp_c, 3.1, lamp)
	if status == &"working":
		return                                       # green = fine; no floating alarm
	if status == &"idle":
		return                                       # benign (empty mover); lamp is enough
	if not show_bubble:
		return                                       # zoomed out + not hovered: lamp is enough, drop the bubble
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
## there" at a glance — the in-world half of the I/O affordances. Pure cosmetic.
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


## VIEW CULLING: the on-screen world-space rectangle, grown by `margin_cells` so partially-on-screen
## content (and its glow / labels / shadows that reach past its cell) isn't clipped at the edge. The
## per-frame draw passes test `if not view.has_point(Vector2(cell) * CELL): continue` BEFORE emitting
## any draw call for an element — the same cull _draw_water/_draw_ore_glints already used inline, now
## shared so every pass reads the identical rect. Off-screen draws aren't visible, so skipping them is
## pixel-identical on-screen. `margin_cells` is generous (≥ 2-3) for passes whose visual overspills its
## cell (machines have glow/badges/IO ports; a big lamp-lit item glow reaches further).
func _view_world_rect(margin_cells: float = 1.0) -> Rect2:
	return (get_canvas_transform().affine_inverse() * get_viewport_rect()).grow(float(CELL) * margin_cells)


# --- Lighting passes (painted by the LightLayer children; pure visuals) -------

## THE LIGHTMAP VEIL: the whole darkness is ONE stretched texture draw — one texel
## per cell, linear-filtered over the world, so light grades smoothly sideways as well as down (the
## old pass drew a rect per cell: hard vertical edges on every lit shaft). Content lives in the
## texture; this draw command never re-issues.
## Draw the baked fine-terrain mold stretched over the world (nearest filter → crisp 8px fine pixels).
## Its ONE draw command replays for free; content only changes when _bake_fine_terrain re-uploads.
func _paint_fine_terrain(layer: LightLayer) -> void:
	if _fine == null:
		return
	layer.draw_texture_rect(_fine.texture(), _fine.world_rect(), false)


## Rebuild the molded fine-terrain texture from the current sim.solid (via scenes/fine_terrain.gd),
## reusing this renderer's exact material + wall palette so the mold matches the coarse pass's colours.
## Called on terrain change only (never per frame). Cleared _fine_dirty + a redraw of the ONE quad.
func _bake_fine_terrain() -> void:
	_fine_dirty = false
	if _fine == null:
		return
	_fine.rebake(
		func(c: Vector2i) -> bool: return sim.is_solid(c),
		func(fx: int, fy: int) -> bool: return sim.fine_is_solid(fx, fy),   # P2: the sim's real fine grid
		func(c: Vector2i) -> Color: return _cell_fill_color(c, _material(sim.material_at(c))),
		_wall_fill_color,
		func(col: int) -> int: return sim.surface_row(col))
	if _fine_layer != null:
		_fine_layer.queue_redraw()


## THE PER-DIG FAST LANE (#102 dirty-chunks): patch only the fine cells under the changed coarse region
## [cmin..cmax] instead of the whole grid — the mining micro-freeze fix. Same palette/wall/surface
## authorities as the full bake, so the patched region is byte-identical to a full rebake (check_dig_hitch).
func _bake_fine_region(cmin: Vector2i, cmax: Vector2i) -> void:
	if _fine == null:
		return
	_fine.rebake_region(cmin, cmax,
		func(c: Vector2i) -> bool: return sim.is_solid(c),
		func(fx: int, fy: int) -> bool: return sim.fine_is_solid(fx, fy),
		func(c: Vector2i) -> Color: return _cell_fill_color(c, _material(sim.material_at(c))),
		_wall_fill_color,
		func(col: int) -> int: return sim.surface_row(col))
	if _fine_layer != null:
		_fine_layer.queue_redraw()


## The back-wall colour behind a dug/eroded cell — the same zone-tinted wall fill the coarse background
## pass paints (so an eroded fine cell shows exactly the wall it would if hand-dug). Falls back to a
## dark dirt tone for a cell with no wall entry (unlikely on solid terrain).
##
## It carries the same bedding as the foreground rock, because it IS the same ground seen a plane back —
## a tunnel cut through a sandy layer should show that layer behind it. Then it recedes: pushed down in
## value and drifted toward cool, the two moves distance actually makes. What it no longer does is
## darken itself for being underground; that is the veil's job, and doing it here as well was
## double-counting the same shadow twice (#S3).
func _wall_fill_color(c: Vector2i) -> Color:
	if not sim.wall.has(c):
		return Color(0.06, 0.055, 0.05)
	var def: MaterialDef = _material(sim.wall[c])
	var col: Color = _zone_tinted(def.base_color, c.y)
	var boost: float = 1.0 + clampf(float(c.y) / float(FactorySim.GRID_ROWS), 0.0, 1.0) * 2.2
	var s: float = _strata(c) * boost * 0.7                # the same beds, a little quieter back there
	col = col.lightened(s * 0.85) if s > 0.0 else col.darkened(-s * 1.05)
	return col.darkened(WALL_RECESS).lerp(WALL_COOL, 0.30)


func _paint_darkness(layer: LightLayer) -> void:
	layer.draw_texture_rect(_veil_tex,
		Rect2(0.0, 0.0, float(FactorySim.GRID_COLS * CELL), float(FactorySim.GRID_ROWS * CELL)), false)


## SPEED READS (#S4). Above running pace the body gets motion lines trailing along its own velocity.
## This is the cheapest possible trick and it is worth more than it costs: at 400px/s the sprite crosses
## a cell in five frames, and without streaks the eye reads that as a teleport rather than as speed —
## which is why fast movement in a tile game so often feels twitchy instead of exhilarating. The lines
## start where the body was and fade out behind it, so they show you the path you just took.
##
## Deliberately gated to speed you had to EARN. A body at walking pace draws nothing, so the streaks are
## themselves a readout: seeing them means the swing worked.
const STREAK_MIN: float = 1.15          ## × RUN_SPEED before any line is drawn
const STREAK_COUNT: int = 5
const STREAK_SPREAD: float = 9.0        ## px the fan of lines spans across the direction of travel
const STREAK_COLOR := Color(0.86, 0.92, 1.0)


func _draw_speed_streaks() -> void:
	if player == null:
		return
	var v: Vector2 = player.velocity
	var speed: float = v.length()
	var floor_speed: float = Player.RUN_SPEED * STREAK_MIN
	if speed < floor_speed:
		return
	# 0 at the threshold, 1 at the swing's terminal — so the lines grow in with the speed rather than
	# popping on at full strength the instant you cross the line.
	var t: float = clampf((speed - floor_speed) / (Player.SWING_MAX_SPEED - floor_speed), 0.0, 1.0)
	var dir: Vector2 = v / speed
	var side := Vector2(-dir.y, dir.x)
	var origin: Vector2 = player.position + Vector2(0.0, -Player.HEIGHT * 0.15)
	for i: int in STREAK_COUNT:
		var f: float = (float(i) / float(STREAK_COUNT - 1)) * 2.0 - 1.0   # -1..1 across the fan
		var a: Vector2 = origin + side * f * STREAK_SPREAD
		var run: float = (16.0 + 30.0 * t) * (1.0 - absf(f) * 0.45)       # longest through the middle
		draw_line(a - dir * 6.0, a - dir * (6.0 + run),
			Color(STREAK_COLOR, (0.10 + 0.26 * t) * (1.0 - absf(f) * 0.5)), 1.0)


## THE LINE. Drawn as a chain of short segments along a quadratic bow rather than as one straight line,
## so slack reads as ROPE: a line the body has swung inside of sags, a line the body is hanging on snaps
## bar-straight, and you can see which you are on without looking at your speed. The hook itself is a
## small dark wedge at the anchor with a bright chip on its lit side, because a hook that reads as a dot
## makes the whole tool read as a laser pointer.
const ROPE_SEGMENTS: int = 14
const ROPE_SAG: float = 26.0            ## px the fully-slack line bows below the chord
const ROPE_CORE := Color(0.78, 0.70, 0.52)
const ROPE_SHADE := Color(0.20, 0.16, 0.12)


func _draw_grapple() -> void:
	if player == null or not player.grapple.live():
		return
	var g: Grapple = player.grapple
	var from: Vector2 = player.hand()
	var to: Vector2 = g.tip if g.state == Grapple.State.FLYING else g.anchor
	var sag: float = g.slack(from) * ROPE_SAG
	var pts := PackedVector2Array()
	for i: int in ROPE_SEGMENTS + 1:
		var t: float = float(i) / float(ROPE_SEGMENTS)
		var p: Vector2 = from.lerp(to, t)
		p.y += sin(t * PI) * sag                     # a parabola is close enough to a catenary at this size
		pts.append(p)
	# Two passes: a dark under-stroke that gives the rope an edge against light rock, then the fibre.
	for i: int in ROPE_SEGMENTS:
		draw_line(pts[i], pts[i + 1], ROPE_SHADE, 4.5)
	for i: int in ROPE_SEGMENTS:
		draw_line(pts[i], pts[i + 1], ROPE_CORE, 2.0)
	# A twist highlight every other segment: the difference between "a rope" and "a laser" at this scale
	# is entirely whether the line has any internal structure at all.
	for i: int in ROPE_SEGMENTS:
		if i % 2 == 0:
			draw_line(pts[i], pts[i].lerp(pts[i + 1], 0.55), ROPE_CORE.lightened(0.35), 1.0)
	# The hook: a wedge biting INTO the rock, oriented along the last segment so it always looks planted.
	var dir: Vector2 = (pts[ROPE_SEGMENTS] - pts[ROPE_SEGMENTS - 1]).normalized()
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var head: Vector2 = to + dir * 3.0
	draw_colored_polygon(PackedVector2Array([
		head, head - dir * 9.0 + side * 5.0, head - dir * 6.0, head - dir * 9.0 - side * 5.0]),
		ROPE_SHADE.lightened(0.22))
	draw_line(head - dir * 8.0 + side * 3.0, head - dir * 2.0, Color(0.92, 0.86, 0.70), 1.0)


## Bake the veil's BASE — the skylight/ambient model: daylight floods DOWN each column's open air
## (attenuating past SURFACE_LINE), is BLOCKED by the first solid rock, scatters SKY_FADE tiles under
## the exposed surface, and everything deeper sits in full ambient (with the #29 night floor above
## ground). Runs only when terrain or the quantized daylight changes.
##
## SHADOW MULTIPLIES (#S3). This texel used to carry a shadow COLOUR in RGB and a darkness in A, and
## the layer alpha-blended it over the world. That is not what shadow does — it is what fog does. At
## the deep's ambient opacity only about a third of a cell's own colour survived to the eye, and the
## other two thirds were a smooth blurred wash painted on top; since the texture is one texel per cell
## stretched across the world, that wash was a soft cloud with no relationship to the rock underneath.
## Every honest attempt to give the deep structure — bedding, fissures, grain, the carved edges — was
## being averaged away by a haze drawn over it. That is the whole answer to "the underground reads as
## fog", and it was a blend mode.
##
## The layer now MULTIPLIES. A texel is a LIGHT LEVEL: white leaves the world untouched, AMBIENT_LIGHT
## is the cool near-dark of the deep, and everything between is a dimmer. Multiplication is
## proportional, so relative contrast survives it perfectly — rock that is a fifth brighter than its
## neighbour stays a fifth brighter at any light level, and detail dims instead of dissolving.
##
## It also deletes work rather than adding it. The old model needed each texel's RGB to be that cell's
## OWN colour darkened, purely so the hue survived the blend; a multiply preserves hue for free. The
## whole per-cell shadow-colour bake, its dirty flag, and its per-dig patch pass are gone with it, and
## a dig no longer touches this texture's colours at all.
func _bake_veil_base() -> void:
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	if _veil_base.size() != cols * rows * 4:
		_veil_base.resize(cols * rows * 4)
	# Above its column's surface the light level depends on the ROW alone — table it once per bake
	# instead of a function call per cell (the bake's dominant cost at 7.7k cells).
	var sky_rgb: PackedInt32Array = PackedInt32Array()
	sky_rgb.resize(rows * 3)
	var night_floor: float = NIGHT_DARK * (1.0 - daylight())
	for row: int in range(rows):
		var sky: float = maxf(AMBIENT_DARK * clampf(float(row - SURFACE_LINE) / float(SKY_REACH), 0.0, 1.0),
			night_floor)
		var c: Color = _light_level(sky)
		sky_rgb[row * 3] = int(c.r * 255.0)
		sky_rgb[row * 3 + 1] = int(c.g * 255.0)
		sky_rgb[row * 3 + 2] = int(c.b * 255.0)
	var amb: Color = _light_level(AMBIENT_DARK)
	var amb_r: int = int(amb.r * 255.0)
	var amb_g: int = int(amb.g * 255.0)
	var amb_b: int = int(amb.b * 255.0)
	for col: int in range(cols):
		var surf: int = sim.surface_row(col)
		var scatter_end: int = mini(surf + SKY_FADE, rows - 1)
		for row: int in range(rows):
			var i: int = (row * cols + col) * 4
			var r: int = amb_r
			var g: int = amb_g
			var b: int = amb_b
			if row <= surf:
				r = sky_rgb[row * 3]
				g = sky_rgb[row * 3 + 1]
				b = sky_rgb[row * 3 + 2]
			elif row <= scatter_end:                        # the shallow-scatter band under the surface
				var t: float = float(row - surf) / float(SKY_FADE)
				r = int(lerpf(float(sky_rgb[row * 3]), float(amb_r), t))
				g = int(lerpf(float(sky_rgb[row * 3 + 1]), float(amb_g), t))
				b = int(lerpf(float(sky_rgb[row * 3 + 2]), float(amb_b), t))
			_veil_base[i] = r
			_veil_base[i + 1] = g
			_veil_base[i + 2] = b
			_veil_base[i + 3] = 255


## Darkness (0 = full light, AMBIENT_DARK = the deep's gloom) → the multiplier the veil applies there.
## Full light is white, i.e. the world untouched; full gloom is AMBIENT_LIGHT, a cool near-dark, so
## shadow both dims and cools in one operation the way real skylight-only ambient does.
func _light_level(darkness: float) -> Color:
	return Color.WHITE.lerp(AMBIENT_LIGHT, clampf(darkness / AMBIENT_DARK, 0.0, 1.0))


## A source's own colour → the colour its light REVEALS rock in. A lamp is amber but it is still bright,
## so a full-strength pool must reach near-white or it would darken the channels its tint is weakest in
## (a saturated teal lift would print a teal-and-black hole instead of lighting the rock). LIGHT_TINT is
## how much of the source's hue survives that lift: enough to read as amber/teal at a glance, never
## enough to strangle a channel. This is why warm lamp + cool crystal reads as colour contrast in stone
## rather than as two coloured stickers.
const LIGHT_TINT: float = 0.34
const TORCH_LIGHT := Color(1.0, 0.72, 0.34)   ## a wall torch burns hotter/oranger than the head-lamp
const SEAM_LIGHT := Color(0.46, 0.86, 1.0)    ## exposed-ore seams answer in cold cyan


func _light_tint(source: Color) -> Color:
	return Color.WHITE.lerp(source, LIGHT_TINT)


## Per frame: copy the baked base and let every live light CUT its pool out of the darkness —
## multiplicative (each source scales the REMAINING veil), so stacked lights deepen the opening
## without over-subtracting. Where light falls the world shows its true colours through the hole;
## the additive pools then lay their warmth on top. The falling stream cuts too — the gravity pour
## visibly opens the dark as it falls.
func _update_veil() -> void:
	if _veil_dirty:
		_veil_dirty = false
		_bake_veil_base()
	# PERSISTENT scratch (#3): the working buffer is a MEMBER, refilled from the freshly-baked base each
	# frame (.duplicate() is a native memcpy — ~0.4us at this size — not the veil's cost; the real cost is
	# the per-source cutting below + the texture upload). Cut into the member directly so nothing leaks a
	# fresh local per frame. The base is re-copied whole each frame, so a light that scrolls off-screen and
	# back leaves no stale hole (only THIS frame's on-screen cuts appear over a fully-dark base).
	_veil_scratch = _veil_base.duplicate()
	var bytes: PackedByteArray = _veil_scratch   # alias for brevity; mutating it is the intended per-frame write
	# OFF-SCREEN CUT CULL (#3): the veil texture covers the whole world but only the on-screen portion is
	# ever visible, so a light hole cut off-screen is invisible — skipping it is behaviour-preserving. Cull
	# every unbounded source (machines/torches/conduits/motes) against a generously-grown view rect: the
	# margin (6 cells) exceeds the widest of these pools (a torch's 4.4) so a source just off-screen whose
	# glow still reaches on-screen keeps cutting. The base is re-copied each frame (fully dark), so a light
	# that scrolls off and back leaves no stale hole. (Player lamp + seams are already on-screen by nature.)
	var cull: Rect2 = _view_world_rect(6.0)
	# Light cuts HARD to reveal rock: the pools open a bright core that falls off tight, so lit rock pops
	# out of the gloom (diffs 1, 11) — and each cut carries its SOURCE's colour (#S3), so what the lamp
	# uncovers is warm stone rather than grey stone with an amber sticker over it.
	if player != null:
		var head: Vector2 = player.position + Vector2(0.0, -Player.HEIGHT * 0.30)
		var lamp_lit: Color = _light_tint(lamp_color)
		_veil_cut(bytes, head + _lamp_offset, 5.4, 0.99, lamp_lit)         # aimed beam — wide reveal, open core
		_veil_cut(bytes, head + _lamp_offset * 0.45, 3.2, 0.8, lamp_lit)   # the beam throat
		_veil_cut(bytes, player.position, 2.2, 0.5, lamp_lit)              # close body glow
	for machine: MachineState in sim.machines:
		var mpos: Vector2 = _cell_center(machine.cell)
		if not cull.has_point(mpos):
			continue
		var kind: String = Visuals.machine_kind(machine.def)
		var s: float = 0.6                                       # cool working glow
		if kind == "generator":
			s = 0.9 if machine.fuel > 0 else 0.0                 # dark when it runs dry
		elif kind == "furnace":
			s = 0.85
		elif kind == "lift":
			s = 0.35 + 0.55 * machine.power_factor
		if s > 0.0:
			_veil_cut(bytes, mpos, 2.8, s, _light_tint(Visuals.machine_color(machine.def)))
	for cell: Variant in sim.torch:
		var tpos: Vector2 = _cell_center(cell as Vector2i)
		if cull.has_point(tpos):
			_veil_cut(bytes, tpos, 4.4, 0.94, _light_tint(TORCH_LIGHT))
	for cell: Variant in sim.conduit:
		var cpos: Vector2 = _cell_center(cell as Vector2i)
		if not cull.has_point(cpos):
			continue
		var lvl: float = _conduit_level(cell as Vector2i)
		if lvl > 0.04:
			_veil_cut(bytes, cpos, 1.8, lvl * 0.7)
	# CRYSTAL/ORE SEAM GLOW (fix-2 diff 2 / diff-04 #5): a few COHESIVE seams (clustered exposed ore) each
	# cut ONE larger cool hole in the gloom so the vein's rock is revealed around it, and _paint_lights lays
	# the saturated cyan pool on top. Warm lamp + cool crystal = the colour contrast the reference lives on.
	# (Seams are already view-culled — _exposed_ore_cells builds only from cells inside _view_world_rect.)
	for seam: Dictionary in _crystal_seams_cached():
		var breath: float = 0.55 + 0.45 * sin(_anim_time * 1.4 + float(seam["pos"].x) * 0.02)
		_veil_cut(bytes, seam["pos"], float(seam["radius"]) / float(CELL), 0.62 + 0.26 * breath,
			_light_tint(SEAM_LIGHT))
	for m: Dictionary in falling.motes():
		var fpos: Vector2 = m["pos"]
		if cull.has_point(fpos):
			_veil_cut(bytes, fpos, 1.4, 0.5)
	_veil_img.set_data(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, false, Image.FORMAT_RGBA8, bytes)
	_veil_tex.update(_veil_img)


## Scale down the veil alpha in a radial falloff around a world position (radius in CELLS). The falloff
## is TEXTURED (fix-2 diff 8): a cheap per-cell value nudge breaks the pool's outer half so the light
## reveals rock grain as it fades instead of a clean gaussian blob (the reference's noisy pool edges).
## The core stays smooth (the nudge scales up with distance) so the bright centre is unbroken.
##
## LIGHT HAS A COLOUR (#S3). `tint` is the colour of the source's light, and the cut lifts each channel
## toward `255 * tint` rather than toward flat white — so lamp-lit rock comes out AMBER and lift-lit rock
## comes out TEAL through the multiply, carrying their own material hue underneath. This is the job the
## additive pass used to do by painting over the rock, which is why the additive pass could be cut to a
## fraction of its old strength: revealing in colour beats repainting in colour.
func _veil_cut(bytes: PackedByteArray, world: Vector2, radius: float, strength: float,
		tint: Color = Color.WHITE) -> void:
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	var target := PackedFloat32Array([tint.r * 255.0, tint.g * 255.0, tint.b * 255.0])
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
			# Textured falloff: a stable per-cell grain (RNG-free hash → sine) mottles the pool's outer
			# region so its edge reveals rock detail; near the core (f→1) the grain vanishes so the hot
			# centre stays clean. Small amplitude (±0.10) — a whisper of noise, not a broken pool.
			# diff-04 #4: mottle the pool's outer half HARDER (two crossed-sine scales, window peaks
			# mid-falloff, vanishes at the hot core and the dead fringe) so light dissolves into the rock
			# grain as it fades instead of a clean gaussian. Amplitude lifted 0.10 -> 0.22.
			var window: float = (1.0 - f) * clampf(f * 2.2, 0.0, 1.0)
			var g: float = (sin(float(col) * 1.7 + float(row) * 2.3) * 0.62 \
				+ sin(float(col) * 4.1 - float(row) * 3.7) * 0.38) * 0.22 * window
			# A cut RAISES the light level toward white rather than lowering an opacity — the same pool
			# and the same falloff, expressed in the multiply model (#S3). Sources still stack the way
			# they did: each lifts whatever the previous one left, so overlapping pools brighten toward
			# full light and can never overshoot it.
			var lift: float = clampf(strength * f * f + g * strength, 0.0, 1.0)  # noisy soft-edged pool
			var idx: int = (row * cols + col) * 4
			for k: int in 3:
				var v: float = float(bytes[idx + k])
				if target[k] > v:                        # a light only ever ADDS light to a channel
					bytes[idx + k] = int(v + (target[k] - v) * lift)


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
		# A faint flicker so the lamp reads as a live flame, not a static disc. Bright enough to blaze
		# against the near-black base but held at 0.66 so the WARM amber core reads (not blown to white) —
		# the pool is the light in the deep, and it stays gold (diff 11).
		# LIGHT REVEALS, IT DOESN'T PAINT (#S2). The lamp does two jobs: it CUTS a wide hole in the
		# darkness veil (see _update_veil — 5.4 cells at near-full strength, which is what actually makes
		# rock visible) and it ADDS an amber pool on top. The additive term was strong enough to swamp the
		# reveal: three overlapping pools summed past 1.0, tripped the glow threshold, and blew the centre
		# of the frame to a white smear. Rock the veil had just uncovered was repainted flat — which is
		# most of why the underground read as fog rather than as stone. The pool is now a fraction of what
		# it was: enough that you plainly see a warm lamp, not so much that it erases what the lamp is for.
		# Cut again (#S3): now that the veil CUT carries the lamp's amber, this pass is pure bloom — the
		# halo you'd see around a real lamp — not the thing that makes rock warm. At 0.32 it was still
		# adding ~85/255 over the reveal and washing the pool's centre to a structureless cream; at 0.17
		# the carved rock inside the pool survives and the lamp still plainly reads as a lamp.
		var flick: float = 0.17 + 0.030 * sin(_anim_time * 11.0) + 0.020 * sin(_anim_time * 27.0)
		# Scale the lamp by how DARK the miner's spot actually is (blind-playtest fix): a full blaze in the
		# deep where it IS the light, but a dim glow in daylight — at spawn the full-strength lamp was
		# washing out the avatar AND the starter ore it sits on, so every warm thing read as "a lamp".
		var pcell := Vector2i(int(floor(player.position.x / float(CELL))), int(floor(player.position.y / float(CELL))))
		var pdark: float = _skylight_alpha(pcell.y, sim.surface_row(pcell.x))
		var lamp_scale: float = lerpf(0.30, 1.0, clampf(pdark / AMBIENT_DARK, 0.0, 1.0))
		flick *= lamp_scale
		# The AIM-FOLLOWING beam (#44): a bright cast pool where you're looking + a dimmer throat pool
		# between it and the head — two glows along one line read as a directed beam, no shader needed. The
		# inner/body pools are held well below the main so the overlapping centres don't sum past 1 → white.
		var head: Vector2 = player.position + Vector2(0.0, -Player.HEIGHT * 0.30)
		_draw_glow(layer, head + _lamp_offset, LAMP_RADIUS, lamp_color, flick)
		_draw_glow(layer, head + _lamp_offset * 0.45, LAMP_RADIUS * 0.62, lamp_color, flick * 0.38)
		_draw_glow(layer, player.position, float(CELL) * 1.5, lamp_color, 0.06 * lamp_scale)  # close body glow
	for machine: MachineState in sim.machines:
		var kind: String = Visuals.machine_kind(machine.def)
		# Saturated cores (diffs 2, 9): each machine's pool blazes in its OWN colour out of the black — a
		# hot orange forge, an amber burner, a cyan-teal lift — the coloured-pools-on-black Noita read.
		var col: Color = Color(1.0, 0.46, 0.16)            # furnace ember (hot saturated orange)
		var pulse: float = 0.7 + 0.12 * sin(_anim_time * 3.0 + float(machine.cell.x))  # a sign of life
		# A COLD/idle forge barely glows — it blazes only while smelting (like the generator going dark when
		# it runs dry). Fixes the idle spawn-forge washing warm light over the starter ore beside it, and
		# reads truthfully: light = working. (Non-furnace runners keep their steady casing glow.)
		if kind == "furnace" and not _machine_active(machine):
			pulse *= 0.12
		if kind == "generator":
			col = Color(1.0, 0.62, 0.20)                   # warm coal-burner glow
			# Breathes while fueled, goes DARK when it runs dry — the "is it making power?" read.
			pulse = (0.85 + 0.22 * sin(_anim_time * 6.5)) if machine.fuel > 0 else 0.0
		elif kind == "lift":
			col = Color(0.36, 1.0, 0.90)                   # lift teal (echoes the updraft motes)
			pulse = (0.55 + 0.5 * machine.power_factor) * (0.85 + 0.15 * sin(_anim_time * 3.0))
		elif kind != "furnace":
			# Each machine's pool takes its OWN casing colour, so a drill / hopper / splitter read as
			# DISTINCT devices in the dark instead of a field of identical cyan blobs (blind-playtest fix).
			col = Visuals.machine_color(machine.def)
		if pulse > 0.0:
			_draw_glow(layer, _cell_center(machine.cell), float(CELL) * 2.6, col, pulse)
			# WHITE-HOT CORE (noita-diff-03 #6): a fire's centre is near-white, not saturated — the forge
			# ember + coal burner get a tiny hot-white pip so the pool reads like real flame, not a flat
			# coloured disc. Only the genuinely BURNING machines (furnace/fueled generator) blaze a core.
			if kind == "furnace" or (kind == "generator" and machine.fuel > 0):
				var core := Color(1.0, 0.94, 0.82).lerp(col, 0.18)   # near-white, a whisper of the pool's hue
				layer.draw_circle(_cell_center(machine.cell), 2.4 + 1.1 * pulse, Color(core.r, core.g, core.b, 0.85 * pulse))
	# Torches: the placeable light. Each mounted torch casts a warm guttering pool —
	# smaller than the head-lamp, but it STAYS: dropped along a dig, they mark the route home, and a
	# lit cave reads as claimed territory in the black.
	for cell: Variant in sim.torch:
		var tc: Vector2i = cell
		var gutter: float = 0.68 + 0.08 * sin(_anim_time * 9.0 + float(tc.x) * 1.7) \
			+ 0.05 * sin(_anim_time * 23.0 + float(tc.y))
		var tpool: Vector2 = _cell_center(tc) + Vector2(1.2, -6.0)
		_draw_glow(layer, tpool, float(CELL) * 3.0, Color(1.0, 0.60, 0.24), gutter)
		# White-hot flame core (noita-diff-03 #6): the guttering torch flame has a bright near-white centre.
		layer.draw_circle(tpool, 1.6 + 0.8 * gutter, Color(1.0, 0.93, 0.78, 0.8 * gutter))
	# Powered conduits EMIT light, so a live trunk pours a column of warm glow down the dark shaft
	# (the in-world tube is drawn under the veil; this is what makes its power read from across the room).
	for cell: Variant in sim.conduit:
		var lvl: float = _conduit_level(cell)
		if lvl > 0.04:
			_draw_glow(layer, _cell_center(cell), float(CELL) * (0.9 + 0.7 * lvl), Color(1.0, 0.78, 0.36), lvl * 0.7)
	# ORE SEAM GLOW (fix-2 diff 2 / diff-04 #5): one cohesive glow per clustered exposed vein, sized to the
	# seam's extent, + a hot core pip on each exposed cell so the seam reads as discrete nuggets inside one
	# big cohesive glow. The glow now takes the seam's OWN material colour (`nugget_color` pushed to
	# saturation) instead of a hardcoded cyan — so ore glows warm orange, rich_ore gold, iron cold steel.
	# The light AGREES with the flecks in the rock; a first-time player's eye lands on the material, not a
	# contradicting blue pool. (Mixed seams: the first cell's material governs — good enough.)
	# LEGIBILITY REWORK (2026-08-09): the old wide radial halo read as a LAMP / lava blob to first-time
	# players ("is that the ore or a light?"), never as rock — a soft glow of ANY colour impersonates a
	# light source. Ore now reads by its tinted CELL BODY + crisp chunky nuggets (drawn under the veil);
	# here we keep only a TIGHT, dim luminous accent + bright nugget PIPS so an exposed vein SHIMMERS in
	# the dark (discovery from across a cavern) without pretending to be a lamp.
	for seam: Dictionary in _crystal_seams_cached():
		var breath: float = 0.55 + 0.45 * sin(_anim_time * 1.4 + float(seam["pos"].x) * 0.02)
		var seam_glow: Color = _seam_glow_color(seam["cells"])
		# Gate the discovery glow by how DARK the vein sits (like the lamp): a vein in daylight reads as pure
		# rock (a glow of any strength there impersonates a lamp — the blind-playtest "is the ore a light?"),
		# while a vein in the deep dark still SHIMMERS so it's findable across a cavern.
		var sc := Vector2i(int(seam["pos"].x / float(CELL)), int(seam["pos"].y / float(CELL)))
		var seam_dark: float = clampf(_skylight_alpha(sc.y, sim.surface_row(sc.x)) / AMBIENT_DARK, 0.0, 1.0)
		if seam_dark <= 0.02:
			continue
		_draw_glow(layer, seam["pos"], float(seam["radius"]) * 0.42, seam_glow, (0.11 + 0.07 * breath) * seam_dark)
		var core_pip: Color = seam_glow.lightened(0.5)
		for c: Vector2i in seam["cells"]:
			var cb: float = 0.55 + 0.45 * sin(_anim_time * 1.4 + float(c.x) * 0.6 + float(c.y) * 0.4)
			layer.draw_circle(_cell_center(c), 1.4 + 0.6 * cb, Color(core_pip.r, core_pip.g, core_pip.b, (0.55 + 0.30 * cb) * seam_dark))
	for m: Dictionary in falling.motes():
		# Dropped/falling items GLOW (the gravity-pour visual), but a dropped STACK overlaps many motes into
		# a "mini sun" (playtest). Dimmer + tighter per mote so a stream reads warm without blowing out.
		_draw_glow(layer, m["pos"], float(CELL) * 1.0, m["color"], 0.38)
	# WATER SELF-SHEEN (L3 legibility): each on-screen water cell adds a FAINT cool bloom so a flooded
	# pocket reads as a dim blue presence in the near-black deep — you can perceive the flood hazard before
	# a lamp reaches it. Deliberately weak (WATER_SHEEN_BASE + level-scaled), well under a torch/crystal/
	# lamp, so lit + shallow water looks essentially unchanged and it never reads as a light source or lava.
	# View-culled like the passes above; scaled modestly by water level (a full cell glows a touch more).
	if not sim.water.is_empty():
		var wview: Rect2 = _view_world_rect()
		for wkey: Variant in sim.water:
			var wc: Vector2i = wkey
			var wlevel: int = int(sim.water[wc])
			if wlevel <= 0:
				continue
			var wpos := Vector2(wc) * float(CELL)
			if not wview.has_point(wpos):
				continue
			var wfrac: float = clampf(float(wlevel) / float(FactorySim.WATER_MAX), 0.0, 1.0)
			var wintensity: float = WATER_SHEEN_BASE + WATER_SHEEN_LEVEL * wfrac
			# A faint slow shimmer so the pool reads as live water, not a painted disc — tiny amplitude.
			var wshim: float = 0.9 + 0.1 * sin(_anim_time * 1.8 + float(wc.x) * 0.6 + float(wc.y) * 0.4)
			_draw_glow(layer, _cell_center(wc), float(CELL) * 1.15, WATER_SHEEN, wintensity * wshim)


## GODRAYS — the signature shot: where a dug shaft admits the sky below the enclosing
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
	# A brighter core with a TIGHTER falloff (diffs 2, 11): light blazes out of the near-black base. The
	# mid stop pulled in (0.42) + lower so the pool has a hot centre and a fast fade — Noita contrast,
	# not a wide soft wash. Cores still carry their WARM tint (not clipped to pure white).
	g.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.92), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
