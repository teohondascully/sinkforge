class_name WorldRenderer
extends Node2D

## The view layer: all world-space drawing of the sim. MainView owns input, verbs and lifecycle. This node
## reads the sim and a few pushed view-state values and never mutates sim state, so deleting it leaves the
## numbers identical. Owns the MaterialDef registry (the visualiser half of the world-engine handshake), the
## cosmetic animation clock, and the two lighting canvases.
##
## Data flow is one-way. MainView pushes what the renderer cannot derive from the sim: the aim cursor and its
## computed reach/placeable/ghost state, via set_aim(). Terrain, machines, ground and lighting are read from
## the sim.

## Draw-domain painter modules. Each is stateless: it paints onto a CanvasItem this renderer hands it and
## reads renderer state as `r.x`. Preloaded by path rather than class_name so headless drivers resolve them
## without a refreshed global-class cache.
const SkyPainter := preload("res://scenes/sky_painter.gd")
const TerrainPainter := preload("res://scenes/terrain_painter.gd")

const CELL: int = FactorySim.CELL
const WORLD_SIZE := Vector2(FactorySim.GRID_COLS * CELL, FactorySim.GRID_ROWS * CELL)
const SKY_COLOR := Color(0.09, 0.11, 0.16)         ## open air above the surface (the gradient's mid tone)
## Parallax ridgeline layers. factor = how world-locked (1 = terrain speed, 0 = pinned to the camera, so
## smaller reads further away); drop = px below the horizon band the ridge crests sit; amp = crest height.
## Far hills are lighter for atmospheric haze, near hills darker: a far range darker than the sky behind it
## is the opposite of what distance does, and high contrast reads as near.
##
## Three ranges and not two. With two the backdrop collapsed into cardboard on sky, with no middle distance.
## The farthest range now sits almost in the sky's own value, and SkyPainter's aerial-perspective lerp falls
## off steeply across the set (see its ridge loop), so the three land at clearly different distances. The
## nearest range keeps its near-black silhouette and reads as the thing closest to you.
const RIDGES: Array[Dictionary] = [
	{"factor": 0.12, "drop": 205.0, "amp": 185.0, "freq": 0.004, "color": Color(0.235, 0.290, 0.400)},
	{"factor": 0.24, "drop": 150.0, "amp": 150.0, "freq": 0.006, "color": Color(0.145, 0.165, 0.225)},
	{"factor": 0.44, "drop": 55.0, "amp": 110.0, "freq": 0.010, "color": Color(0.062, 0.072, 0.112)},
]
## The Sinkforge: the endgame landmark. A colossal dormant ancient machine whose crown breaches the surface,
## a broken cog-ring on a dead industrial pylon buttressed by leaning pillars. It is the tip of a colossus
## spanning the depth layers, with its heart at the core many layers down, and you descend alongside it. A
## faint ember breathes at the cog's core, so it reads as dormant rather than extinct. Drawn in the backdrop
## at z -20 on a low parallax factor so it sits far on the horizon and stays roughly in view as you cross the
## surface; the near ridge occludes its base, and the walls cover it once you descend. Purely cosmetic: the
## sim never knows it exists.
const SINKFORGE_ANCHOR_X: float = 1552.0             ## world x of the crown (centre of the spawn plateau, cols 30-66)
const SINKFORGE_FACTOR: float = 0.20                 ## distant-hill parallax: far, always roughly on the horizon
const SINKFORGE_SCALE: float = 1.28                  ## master size dial

## --- Lighting (the mood lever) -----------------------------------------------------------------
## The model is skylight + ambient, not a depth gradient: the underground is near-black everywhere, and
## daylight only reaches where open air connects it to the sky. Sky floods down each column's open air,
## attenuating with depth, and is blocked by the first solid rock, so a dug shaft pours daylight down, the
## dirt beside it stays dark, and an enclosed cave is pitch black until you bring a lamp. Warm artificial
## light pools (head-lamp, forge embers, machine glow) are the only light in the deep. Recomputed when
## terrain changes.
##
## Tuned to the generated world: HeightmapWorldGen puts surfaces between rows 11 and 31 with the spawn
## plateau at row 20. Full daylight down to the valley floor, then sunlight penetrates about a dozen tiles
## into a dug shaft before the dark takes over. Values tuned for a shallower world put the surface past where
## daylight died and rendered the whole game in permanent dusk.
const SURFACE_LINE: int = 22                        ## reference daylight row; sky attenuates with depth past it
const SKY_REACH: int = 12                           ## tiles of open air sunlight reaches before going dark
## Tiles of shallow light-scatter under an exposed surface. Ground near daylight is not black: light bounces
## into the first several feet of earth, and cutting to pitch one tile down turns the bottom of the opening
## frame into a void that reads as the end of the world.
##
## Sixteen and not seven, and the constraint is 8-bit rather than artistic. The veil multiplies, which
## preserves relative contrast perfectly, but a deep multiplier leaves the whole rock a few dozen 8-bit
## levels to live in while its own texture spans about two of them, so paint that measurably reads as rock
## at full light quantizes into a stain. At seven tiles the bottom 45% of the opening frame printed as one
## smooth brown gradient with four or five levels in it and no visible rock at all.
##
## Sixteen is the honest depth because daylight soaks into soil, not into rock: the band under the grass
## reads as dirt with stones in it and a visible bottom edge, and the dark begins at rock depth. The deep is
## not touched by this at all.
const SKY_FADE: int = 16
## How dark the deep gets, on a 0 (full light) .. 1 (pitch) scale. Read by _light_level, which turns it into
## the multiplier the veil applies. The lamp/machine/crystal pools still cut this back to ~0, so "bring your
## own light" holds and lit rock pops out of the gloom. 0.87 left rock invisible; 0.74 lost structure in the
## murk.
const AMBIENT_DARK: float = 0.66
## The colour of full gloom, as a multiplier rather than a wash. Skylight-only ambient is cool and dim, so
## the deep darkens and cools in one operation. Because it multiplies, a cell keeps its own hue and its own
## relative contrast for free: dark brown topsoil stays brown, dark grey stone stays grey, and the bedding,
## fissures and carved edges painted into the rock survive as structure rather than being averaged under a
## haze. Raising these values lifts the whole deep; the ratio between the channels is what makes shadow read
## cool.
##
## At (0.24, 0.28, 0.38) the deep printed unlit dirt at rgb(6,10,24) and unlit stone at rgb(8,14,31): a 4:1
## blue bias that erased every material's hue and left two very different rocks four units of luminance
## apart. Barely cool and appreciably brighter keeps the material read while the deep still plainly needs a
## lamp.
const AMBIENT_LIGHT := Color(0.34, 0.35, 0.42)
## How much of the deep ambient an unlit empty cell keeps. Applies below the scatter band only, so the
## surface and the daylight soak are untouched.
##
## `check_rock_reads` sampled 140 solid cells against 55 air cells outside every light source and asked how
## often you would be right telling them apart from pixels: 56%, against a coin flip of 50%. The medians say
## something sharper than "no contrast": unlit air read 12.0 and unlit rock read 9.4, so the void was
## brighter than the rock. An inverted cue rather than a missing one, and inverted against the lamp too,
## where bright means solid-and-lit.
##
## The mechanism is `_open_blur`, and it is not a bug. That term means "how much light can reach in here",
## which is right near the surface, where openness is how skylight arrives. Carried into the deep it keeps
## paying out light that has no source: an air pocket forty rows down is maximally open, so it took the full
## ambient while the rock beside it took the openness of rock. Down here there is nothing overhead to be
## open to.
##
## A floor on the void rather than a lift on the rock, because raising global brightness is how this was got
## wrong before: an earlier blue fog did exactly that and had to be pulled. Rock's ambient is untouched at
## AMBIENT_LIGHT and keeps every value and every grain it had; the whole change is subtractive on cells that
## hold nothing, so carved space is the darkest thing in frame until you light it.
const VOID_FLOOR: float = 0.35
## `SF_MACHINE_BARE=1` strips a machine of everything that is UI about the machine (name label, held-count
## badge, status lamp, need bubble), leaving only the object. It exists so that the guard "causality survives
## labels hidden and grayscale" can be established rather than reasoned about.
##
## It makes the assertion harder, never easier, which is the test for whether a switch like this belongs in
## shipped code: a flag that restores a weaker measurement buys green, a flag that removes the crutches the
## measurement may not lean on is the measurement. Read once at load, because a renderer that consults the
## environment per frame is a renderer whose output depends on when you asked.
static var BARE_MACHINES: bool = OS.get_environment("SF_MACHINE_BARE") == "1"
## `SF_MACHINE_SILHOUETTE=1`: the casing and nothing else, with no glyph, light pool or label. The question
## is whether the machine's body carries its identity, and every other channel answers a different one. The
## glyph especially is a decal on the front, so leaving it in would let `check_machine_identity` pass on
## twenty identical boxes wearing twenty different icons.
static var SILHOUETTE_ONLY: bool = OS.get_environment("SF_MACHINE_SILHOUETTE") == "1"
## One colour for all of them. Leaving each machine its registry hue and masking "material" as "far enough
## from bare rock" could not register its subject: the Descent Engine's shadowed foot lands within 3 levels
## of the rock behind it, so a dark machine measured as a smaller machine, and twenty bodies scored a mean
## pair difference of 0.201 that was twenty paint jobs on one rectangle. Painted identically, any difference
## left in the patch is geometry.
const SILHOUETTE_GREY := Color(0.75, 0.75, 0.77)

## What is left of a machine's light pool once it stops working. Not zero: an installed machine in a dark
## gallery still has to be findable, and a base that vanishes when it idles is a base you cannot navigate.
## The furnace has used this value since its own gate was written; every other machine gets it too, in
## `_paint_lights`.
const IDLE_GLOW: float = 0.12

const LAMP_COLOR := Color(1.0, 0.82, 0.50)          ## the miner's warm head-lamp: a saturated amber core, so
                                                   ## the pool reads warm-gold rather than as a white wash
## The lamp's ease rate, named so a fixture can derive its own settle budget instead of hard-coding a frame
## count. The recurrence collapses to `e_N = e0 * exp(-LAMP_EASE * T)`: decay depends only on elapsed game
## time, not on how it is chopped into frames.
const LAMP_EASE: float = 9.0
const LAMP_RADIUS: float = CELL * 5.6               ## the additive bloom halo, drawn by _paint_lights


## Where the lamp hangs. The expression was written out four times in this file; a caller that copies it a
## fifth time is one edit away from lighting a different point than the renderer does.
## Machine drawing, extracted along a measured seam. `machine_view.gd` records what crosses the line,
## and why it is that block rather than the larger and more contiguous lighting one.
var _machines: MachineView = null

## Water drawing, extracted along a measured seam. See `water_view.gd`.
var _water: WaterView = null
var _rope: RopeView = null

func lamp_head() -> Vector2:
	if player == null:
		return Vector2.ZERO
	return player.position + Vector2(0.0, -Player.HEIGHT * 0.30)


## What `_lamp_offset` is easing toward. This is an offset, a vector relative to the head, not a world
## point: every render site spends it as `head + _lamp_offset` (`_veil_cut` twice, `_draw_glow` twice), so
## reading it as a position is wrong by the whole head vector, and the error looks like a small lighting
## drift.
##
## Hoisted out of `_process` so a fixture asks instead of re-deriving. The head term, the `CELL * 0.9`
## fallback and the `facing` branch are three chances to get it subtly wrong, and `_process` calls this same
## method, so the two cannot drift apart.
func lamp_target_offset() -> Vector2:
	if player == null:
		return _lamp_offset
	var to_aim: Vector2 = _cell_center(_aim) - lamp_head()
	if to_aim.length() > float(CELL) * 0.9:
		return to_aim.limit_length(LAMP_LEAD)
	return Vector2(float(player.facing) * float(CELL) * 0.7, -float(CELL) * 0.2)


## The lamp's world position, which is what a layer measuring the lit pool wants.
func lamp_pos() -> Vector2:
	return lamp_head() + _lamp_offset


## How far the lamp still has to travel. A fixture waiting for the light to settle must assert this rather
## than watch `_lamp_offset` stop changing between frames. Under `Engine.time_scale = 0` the ease multiplier
## is `1.0 - exp(0)` = 0, so the offset cannot move at all, a derivative test reads perfectly still on every
## frame, and a settle check photographs a lamp pickled mid-slide. A residual reports the truth in that state.
##
## Two limits on what a small residual means:
## * It only means "settled" for a body at rest. The target is head-relative and recomputed from the live
##   position, so a walking, falling or swinging body carries a permanent residual floor, and a settle loop
##   run during a spawn fall will spend its whole budget and prove nothing.
## * It is not monotone across the `CELL * 0.9` branch. The two branches do not meet: at the threshold the
##   aimed target has magnitude 28.80 and the fallback 23.30, and with the aim behind the facing they are
##   ~51.6 px apart. A sub-pixel body move across that line teleports the target and spikes the residual
##   with nothing wrong. Bound it at a moment of rest; never assert it stayed low over an interval, or the
##   statistic is about the branch.
func lamp_residual() -> float:
	return _lamp_offset.distance_to(lamp_target_offset())


const LAMP_LEAD: float = CELL * 1.9                 ## how far the beam pool leads toward the aim

## --- Day/night (cosmetic-first) ---------------------------------------------------
## A slow surface rhythm off the cosmetic clock: the backdrop sky, the skylight veil, the godrays and the
## bird all breathe with it. The underground is untouched, since its ambient is the same by day or night. At
## night the surface dims toward, not into, the underground ambient, which reads as moonlight rather than a
## cave and makes placed torches matter above ground too. Purely representational: the sim never reads any
## of it.
const DAY_SECONDS: float = 480.0                    ## one full cycle (8 min)
const DAY_START_PHASE: float = 0.10                 ## boot mid-morning, so fixtures and a fresh world read day
const NIGHT_DARK: float = 0.40                      ## how dark the night sky veils the surface (< AMBIENT_DARK)


## 0..1 through the cycle: 0.00-0.40 day, 0.40-0.55 dusk, 0.55-0.90 night, 0.90-1.00 dawn.
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
## Machine construct animation: cell -> elapsed seconds since placement. MainView pokes
## note_machine_built() on a real build and never on boot or load, so pre-existing machines do not animate.
## A short one-shot assemble overlay (flash + rising scan + bracket snap) plays.
var _construct: Dictionary = {}
const CONSTRUCT_DUR: float = 0.38
## Mine crumble: a just-mined block shatters into four chunks that fly apart, fall and fade instead of
## popping out of existence, so the removed rock leaves with weight. MainView pokes note_mined() on a real
## dig. [{pos, col, age}], capped so a fast dig cannot pile up unbounded.
var _crumble: Array[Dictionary] = []
const CRUMBLE_DUR: float = 0.24
const CRUMBLE_MAX: int = 48

# Pushed by MainView each frame (the bits the renderer can't derive from the sim alone).
var _aim: Vector2i = Vector2i(-99, -99)
var _aim_in_reach: bool = false
## Will the carried drive bite the aimed rock at all? False = the wall is over your tier, and the cursor has
## to say so before the swing (`docs/BITS.md` §5) rather than after a click that did nothing.
var _aim_bites: bool = true
var _aim_placeable: bool = false
var _lamp_offset: Vector2 = Vector2.ZERO   ## eased head->beam-pool offset (the aim-following lamp)
var lamp_color: Color = LAMP_COLOR         ## the picked lamp tint, set from the title screen
var _ghost_def: MachineDef = null
var _ghost_material: StringName = &""                ## a building material selected for block placement
var _guide_targets: Array[Dictionary] = []           ## current objective's where-cells (pushed by MainView)
var _mine_cell: Vector2i = Vector2i(-999, -999)       ## block being charge-mined (cracks drawn on it; pushed by MainView)
var _mine_frac: float = 0.0                           ## 0..1 break-charge of that block: the felt-friction read
var _dig_marks: Dictionary = {}                       ## the dig plan (live ref from MainView), hatched overlay
var _ping_world: Vector2 = Vector2.INF                ## the map-click ping (INF = none), an in-world beacon
var _daylight_step: int = -1                          ## quantized daylight; the veil repaint trigger
## The scanner pulse, pushed by try_scan: origin + age drive an expanding wavefront, and each echo
## ({pos, dist, material}) lights up as the front passes its true distance, lingers, then fades.
const SCAN_WAVE_SPEED: float = 260.0                  ## wavefront px/s; the controller staggers audio off it
const SCAN_ECHO_LINGER: float = 4.0                   ## seconds an echo stays readable after its hit
var _scan_origin: Vector2 = Vector2.INF
var _scan_age: float = -1.0                           ## -1 = no scan live
var _scan_echoes: Array[Dictionary] = []
var _scan_range: float = 0.0
var bazaars: Bazaars = null                          ## the Bazaar view layer (set by MainView); may be null
var _seal_rows: Array[int] = []                       ## world rows holding the seal (lazy-scanned for its pulse)
var _seal_rows_scanned: bool = false

## Static terrain/walls/surface, split into a grid of chunk canvases so a dig repaints only the affected
## chunk(s), ~64 cells, instead of the whole 16,384-cell world, which was a ~300ms freeze. Each chunk owns a
## CHUNK x CHUNK cell block; sim.terrain_dirty says which to repaint each frame.
const CHUNK: int = 8                                  ## cells per chunk side (8x8 = 64-cell repaint per dig)
var _chunks: Array[LightLayer] = []                  ## row-major grid, size _chunk_cols x _chunk_rows
var _chunk_cols: int = 0
var _chunk_rows: int = 0
## Coarse terrain bake. The chunk painters above draw the static coarse terrain over the whole 16,384-cell
## world; measured on a mature base that was ~72% of the frame's draw calls, ~11,882 of them. They are
## static per terrain change, so the chunk canvases live inside a world-sized SubViewport with a transparent
## background and its render target is drawn as one textured quad at z -10: pixel-identical by construction,
## since it is the same draw code, and ~11k fewer draw calls. The viewport re-renders only when a chunk was
## dirtied, via render_target_update_mode UPDATE_ONCE; between changes the GPU replays the single quad.
var _terrain_viewport: SubViewport                    ## world-in-pixels canvas the chunk painters render into
var _terrain_layer: LightLayer                        ## the one quad in the main tree that draws the bake (z -10)
## The incremental bake. The viewport is the whole world, 4096x4096 px, and every chunk painter lives inside
## it, so nothing is ever culled: re-rendering it replayed every chunk over sixteen megapixels and cost
## ~100ms, once per dig, which was two thirds of a measured 114ms mining hitch (tools/check_frametime). The
## target is now retained and a dig re-renders only the chunks that changed; the rest keep the pixels they
## already had. `_eraser` blanks those chunks' rects first, because blending cannot remove coverage.
var _eraser: LightLayer                               ## z -11 inside the viewport: clears a dirty chunk's rect
var _erase_rects: Array[Rect2] = []                   ## world rects to blank on the next viewport render
var _back: LightLayer      ## the parallax backdrop (sky gradient + ridgelines + clouds), z -20
## Fine terrain molding: the coarse 32px terrain fill re-rendered as an organic 8px-grain field baked to one
## texture (scenes/fine_terrain.gd) and drawn over the chunk terrain, which keeps drawing walls and the
## surface cap, so the blocky cell edges become curved. Rebuilt only on terrain change (_fine_dirty), never
## per frame: the same repaint-on-change discipline as the veil.
var _fine: FineTerrain
var _fine_layer: LightLayer
var _fine_dirty: bool = true                     ## Full rebake pending (initial paint / load): the slow lane
## The per-dig fast lane: a dig accumulates the coarse bounding box of this frame's changed cells so the
## fine baker patches only that region instead of re-processing the whole 512 x 512 fine grid.
var _fine_region_pending: bool = false
var _fine_dirty_min: Vector2i = Vector2i.ZERO
var _fine_dirty_max: Vector2i = Vector2i.ZERO
var _dark: LightLayer
## The lightmap veil. The darkness is a small texture, one texel per cell, stretched over the whole world
## with LINEAR filtering so light grades smoothly in every direction instead of stepping cell to cell. The
## skylight/ambient base bakes only when terrain or the daylight step changes (_veil_dirty); each frame the
## base is copied and the live light sources cut holes in it (lamp, torches, machines, conduits, falling
## drops), so where light falls the veil opens and the world shows its true colours under the additive
## warmth. Light reveals rather than tinting.
var _veil_img: Image
var _veil_tex: ImageTexture
var _veil_base: PackedByteArray
var _veil_scratch: PackedByteArray   ## persistent per-frame veil buffer: base memcpy'd in, holes cut
var _veil_dirty: bool = true                     ## a full veil rebake (daylight moved / world loaded)
## A dig dirties only the columns it touched. Tracked separately from _veil_dirty so the cheap case stays
## cheap and the global case, the daylight clock, still gets the whole world.
var _veil_cols_dirty: bool = false
var _veil_col_min: int = 0
var _veil_col_max: int = 0
## Crystal seams: the flood is cached across frames and shared by _update_veil and _paint_lights, which
## both need the identical seam list. It only changes when ore exposure changes (terrain dug or placed near
## ore) or when the culling view-rect moves (a seam pans on or off screen), so it is recomputed on either
## signal and otherwise replayed. Invalidated in the terrain-dirty block below.
var _crystal_seams_cache: Array[Dictionary] = []
var _crystal_seams_valid: bool = false
var _crystal_seams_view: Rect2 = Rect2()
var _lights: LightLayer
var _tooth: LightLayer                                 ## post-veil rock tooth (rock_tooth.gdshader)
var _marks: LightLayer                                 ## post-veil player-intent markers (see _paint_marks)
var _haze: LightLayer      ## the shared distortion pass: heat shimmer now, water later
var _leaf_cells: Array[Vector2i] = []   ## cached canopy cells; rebuilt on terrain change
var _leaf_cache_dirty: bool = true
var _glow_tex: GradientTexture2D


## Wire the renderer to the world it draws. Called once by MainView, after the sim and player exist.
func setup(world_sim: FactorySim, falling_items: FallingItems, body: Player) -> void:
	_water = WaterView.new(self)
	_rope = RopeView.new(self)
	_machines = MachineView.new(self)
	sim = world_sim
	falling = falling_items
	player = body
	for path: String in [
		"res://src/data/materials/earth.tres",
		"res://src/data/materials/ore.tres",
		"res://src/data/materials/rich_ore.tres",
		"res://src/data/materials/coal.tres",
		"res://src/data/materials/stone.tres",
		"res://src/data/materials/shale.tres",
		"res://src/data/materials/deepslate.tres",
		"res://src/data/materials/wood.tres",
		"res://src/data/materials/leaves.tres",
		"res://src/data/materials/sealrock.tres",
		"res://src/data/materials/gravel.tres",
		"res://src/data/materials/iron.tres",
		"res://src/data/materials/dirt_wall.tres",
		"res://src/data/materials/stone_wall.tres",
		"res://src/data/materials/shale_wall.tres",
		"res://src/data/materials/deepslate_wall.tres",
	]:
		var def: MaterialDef = load(path)
		_materials[def.id] = def
	# A static terrain canvas below this renderer's dynamic draw (z -10). It carries the heavy 16,384-cell
	# immediate-mode terrain + wall + surface pass, repainted only when the terrain changes (dig, place, a
	# drill draining a deposit) instead of every frame. Between changes the GPU replays its retained buffer.
	# The bottleneck was GDScript re-issuing the whole world's draw commands every frame; the sim itself
	# costs almost nothing.
	_chunk_cols = ceili(float(FactorySim.GRID_COLS) / float(CHUNK))
	_chunk_rows = ceili(float(FactorySim.GRID_ROWS) / float(CHUNK))
	# The chunk painters render into a world-sized SubViewport: a flat 4096x4096 canvas with no camera, so a
	# chunk's world-space draw lands 1:1 at pixel coords, and a transparent background so the sky above
	# ground stays see-through and the backdrop shows. update_mode disabled means it never re-renders on its
	# own; it is flipped to UPDATE_ONCE only when a chunk is dirtied, below, which preserves the fast lane.
	_terrain_viewport = SubViewport.new()
	_terrain_viewport.size = Vector2i(FactorySim.GRID_COLS * CELL, FactorySim.GRID_ROWS * CELL)
	_terrain_viewport.transparent_bg = true
	_terrain_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_terrain_viewport.disable_3d = true
	# Its own world, so the colour grade cannot reach it. The WorldEnvironment's adjustment pass runs as a
	# viewport post-process, and this viewport retains its render target between updates (CLEAR_MODE_NEVER on
	# the partial-bake path; that retention is what makes a dig cost one chunk instead of the whole world).
	# Inheriting the grade meant saturation 1.18 was re-applied to the same stored pixels on every bake, so
	# the terrain compounded 1.18^n: grass measured (87,130,47) at boot and (42,255,0) after a play arc, and
	# the walked surface line, the one strip the fine layer does not cover, read as a neon red-and-green band
	# across the whole frame. Measured: 24 colour-change events during one arc before this, 0 after.
	_terrain_viewport.own_world_3d = true
	_terrain_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_terrain_viewport)
	for cy: int in _chunk_rows:
		for cx: int in _chunk_cols:
			var rect := Rect2i(cx * CHUNK, cy * CHUNK, CHUNK, CHUNK)
			var chunk := LightLayer.new()
			chunk.setup(-10, _paint_terrain_chunk.bind(rect))  # painter(ci, rect) draws only this block
			_terrain_viewport.add_child(chunk)                        # renders into the bake viewport, not the main tree
			_chunks.append(chunk)
	# The eraser sits below the chunk painters inside the same viewport, so on a partial re-render each
	# dirty chunk's rect is blanked before that chunk repaints into it.
	_eraser = LightLayer.new()
	_eraser.setup(-11, _paint_erase)
	var erase_mat := ShaderMaterial.new()
	erase_mat.shader = load("res://scenes/erase.gdshader")
	_eraser.material = erase_mat
	_terrain_viewport.add_child(_eraser)
	# The one quad in the main tree that draws the baked coarse terrain, at z -10 where the chunk draws were.
	# Drawn at the world rect 1:1 with NEAREST filter so it lines up crisply with the pixel-snap camera,
	# unlike the veil, which is deliberately low-res and linear. Content updates via the viewport.
	_terrain_layer = LightLayer.new()
	_terrain_layer.setup(-10, _paint_terrain_bake)
	_terrain_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_terrain_layer)
	# The parallax backdrop sits below the terrain chunks at z -20, repainted per frame: a vertical sky
	# gradient, drifting ridgelines and slow clouds. The chunk background pass no longer fills opaque sky, so
	# the vista shows wherever no wall backs a cell; underground the walls hide it for free.
	_back = LightLayer.new()
	_back.setup(-20, _paint_backdrop)
	add_child(_back)
	# The fine terrain mold: baked once here and drawn stretched over the chunk terrain at z -9, above the
	# -10 blocky fill and below all dynamic content. Nearest filter keeps the 8px fine pixels crisp. It
	# rebuilds only when the terrain changes (_fine_dirty), like the veil below.
	_fine = FineTerrain.new(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, 1337)
	_fine_layer = LightLayer.new()
	_fine_layer.setup(-9, _paint_fine_terrain)
	_fine_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# ...and the tooth inside those 8px pixels, which the baked texture cannot hold and the screen post-pass
	# cannot supply: its grain is camera-locked, so it reads as dirt on the lens rather than as rough rock.
	# See scenes/rock_grit.gdshader; measured by tools/check_underground.
	var grit := ShaderMaterial.new()
	grit.shader = load("res://scenes/rock_grit.gdshader")
	_fine_layer.material = grit
	add_child(_fine_layer)
	_bake_fine_terrain()
	# Two world-space canvases above this renderer's draw: the skylight/darkness veil, then the light pools.
	_glow_tex = _make_glow_texture()
	_dark = LightLayer.new()
	_dark.setup(50, _paint_darkness, CanvasItemMaterial.BLEND_MODE_MUL)
	# The lightmap veil: the darkness texture is tiny, one texel per cell, and the LINEAR filter on the
	# stretch is what turns per-cell values into smooth gradients across the world.
	_dark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_dark.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_veil_img = Image.create(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, false, Image.FORMAT_RGBA8)
	_veil_tex = ImageTexture.create_from_image(_veil_img)
	add_child(_dark)
	_lights = LightLayer.new()
	_lights.setup(51, _paint_lights, CanvasItemMaterial.BLEND_MODE_ADD)
	add_child(_lights)
	# ...and the tooth again, above the veil, because below it there is no tooth at all. rock_grit paints
	# into the terrain layer at z -9 and `_dark` multiplies at z 50, so its additive floor, the one meant to
	# keep something in rock the veil has taken most of the way down, is scaled by the very factor that made
	# the rock dark. See scenes/rock_tooth.gdshader; measured by check_rock_reads.
	_tooth = LightLayer.new()
	_tooth.setup(52, _paint_fine_terrain)
	_tooth.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var tooth_mat := ShaderMaterial.new()
	tooth_mat.shader = load("res://scenes/rock_tooth.gdshader")
	_tooth.material = tooth_mat
	add_child(_tooth)
	# HERE AND NOT AFTER THE BAKE ABOVE, because the bake runs before this node exists and clears
	# `_fine_dirty` on its way out, so the per-frame lane that normally refreshes this would never fire on
	# a fresh boot. The map would be missing for the whole session and the shader's hint_default_black
	# would make that look exactly like the isotropic tooth it replaces.
	_tooth_grammar()
	# Player intent sits above the dark. The map beacon, the dig plan and the objective marker are not part of
	# the world; they are things the player put there, and the veil was taking two thirds of each. Measured
	# at 24 metres by differencing per-pixel maxima with the cue placed against the cue cleared (null
	# control: peak +1.0 over 0 px): the beacon asks for luma 205.4 and delivered 63.3, the dig bracket asks
	# for ~104 and delivered 32.1. Both keep 31%, which is one multiplicative factor rather than two
	# coincidences. MIX rather than ADD, so a marker arrives at the colour it was authored in; an additive
	# pass here would blow out over the lamp, as it once did in _paint_lights, washing out the frame centre.
	_marks = LightLayer.new()
	_marks.setup(53, _paint_marks)
	add_child(_marks)
	# The distortion pass: one shared screen-warp shader, with consumers drawing masked quads. Used here for
	# machine heat-haze. Sits above the world and veil but under the additive light pools, so hot air bends
	# the scene and lamplight stays crisp.
	_haze = LightLayer.new()
	_haze.setup(46, _paint_heat_haze)
	var haze_mat := ShaderMaterial.new()
	haze_mat.shader = load("res://scenes/heat_haze.gdshader")
	_haze.material = haze_mat
	add_child(_haze)
	for chunk: LightLayer in _chunks:
		chunk.queue_redraw()  # initial full paint (once); thereafter only dirtied chunks repaint
	_bake_terrain_full()   # the initial coarse terrain: every chunk, and the target cleared under it
	sim.terrain_dirty.clear()  # drop any dirt from world-seeding; the initial paint covers it
	_dark.queue_redraw()  # the veil's one draw command (the stretched lightmap); content updates via the texture


## Full-world repaint, for when the terrain changed wholesale under the retained caches, such as loading a
## save. Requeues every terrain chunk and the skylight veil and drops the lazy seal-row cache. The
## incremental terrain_dirty path stays the per-dig fast lane; this is the load-time reset.
func repaint_world() -> void:
	for chunk: LightLayer in _chunks:
		chunk.queue_redraw()
	if _terrain_viewport != null:
		_bake_terrain_full()
	_veil_dirty = true
	_fine_dirty = true
	sim.terrain_dirty.clear()
	_seal_rows.clear()
	_seal_rows_scanned = false
	_leaf_cache_dirty = true


## The controller hands over the cursor + its computed affordances (reach / placeable / the ghost def).
func set_aim(cell: Vector2i, in_reach: bool, placeable: bool, ghost_def: MachineDef,
		ghost_material: StringName = &"", bites: bool = true) -> void:
	_ghost_material = ghost_material
	_aim = cell
	_aim_in_reach = in_reach
	_aim_placeable = placeable
	_ghost_def = ghost_def
	_aim_bites = bites


## The controller hands over the cells the current objective points at, each {cell, mode}, drawn as a
## pulsing ring ("act") or a ghost outline ("ghost") so a new player sees where the next step happens.
func set_guide_targets(targets: Array[Dictionary]) -> void:
	_guide_targets = targets


## The controller pushes which block is being charge-mined and how far along (0..1) each frame, so the
## renderer can spider cracks across it: the visible friction that says this is taking effort. Cosmetic.
func set_mine_progress(cell: Vector2i, frac: float) -> void:
	_mine_cell = cell
	_mine_frac = frac


## The controller hands over its dig-plan dict once as a live reference (cell -> true), so the overlay
## tracks paints and clears without a per-frame push. Read-only here: the plan is the controller's.
func set_dig_marks(marks: Dictionary) -> void:
	_dig_marks = marks


## The player's ping, set by clicking the minimap (Vector2.INF = none). Drawn in-world as a pulsing beacon
## so the spot marked on the map is findable on foot.
func set_ping(world: Vector2) -> void:
	_ping_world = world


## Begin a sonar pulse. The controller computed the echoes (a pure deposits query); from here the wavefront
## and echo lifecycle are cosmetic clockwork.
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
			_scan_age = -1.0    # pulse spent, every echo faded: the scan is over
			_scan_echoes = []
	# The head-lamp follows the aim: the pool leads from the head toward the cursor, capped, and eased so a
	# mouse flick swings the beam like a worn lamp rather than a snapped spotlight. With the cursor on or
	# beside the body it falls back to plain facing so the light never collapses onto you.
	if player != null:
		_lamp_offset = _lamp_offset.lerp(lamp_target_offset(), 1.0 - exp(-LAMP_EASE * delta))
	_water._spawn_water_drips(delta)   # cosmetic drips shed off pouring water (view-culled, rate-limited)
	queue_redraw()              # falling items, machine animation and the aim cursor move every frame
	_update_veil()              # the lightmap veil: rebake the base if dirty, re-cut the live lights
	if _lights != null:
		_lights.queue_redraw()  # the lamp follows the body + machines shimmer
	if _marks != null:
		_marks.queue_redraw()   # ping ring, dig pulse and objective chevron all breathe on _anim_time
	if _haze != null:
		_haze.queue_redraw()    # working furnaces convect; the shader's TIME drives the ripple
	if _back != null:
		_back.queue_redraw()    # the parallax vista slides against the camera (a few polygons, cheap)
	# The day/night veil: the skylight darkness is repainted only on terrain change, so the slow sky cycle
	# nudges it by quantized steps. 24 steps over the 72s of dusk or dawn is one cheap repaint every ~3s,
	# and none at all mid-day or deep night, since the step only moves while the light is changing.
	var dstep: int = int(daylight() * 24.0)
	if dstep != _daylight_step:
		_daylight_step = dstep
		_veil_dirty = true
	# Terrain depends on the dug world, not the cosmetic clock. Repaint only the chunks whose cells changed
	# this frame (sim.terrain_dirty): a dig rebuilds ~64 cells, not the whole 16,384-cell world, which was a
	# ~300ms freeze. A changed cell also dirties its neighbour chunks, since edge-AO and the surface cap on a
	# neighbouring cell read across the boundary. Between changes each chunk's retained buffer is replayed.
	if not sim.terrain_dirty.is_empty():
		var dirty: Dictionary = {}                    # chunk index -> true (dedup)
		var rmin := Vector2i(1 << 30, 1 << 30)        # coarse bounding box of the changed cells (fine fast lane)
		var rmax := Vector2i(-(1 << 30), -(1 << 30))
		for cell: Vector2i in sim.terrain_dirty:
			rmin.x = mini(rmin.x, cell.x); rmin.y = mini(rmin.y, cell.y)
			rmax.x = maxi(rmax.x, cell.x); rmax.y = maxi(rmax.y, cell.y)
			# All 8 neighbours plus self: edge-AO and caps read orthogonally, and the autotile chamfer and
			# fillet passes read across corners, so a dig at a chunk corner must repaint the diagonal chunk.
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					var idx: int = _chunk_index(cell + Vector2i(dx, dy))
					if idx >= 0:
						dirty[idx] = true
		_bake_terrain_chunks(dirty)
		sim.terrain_dirty.clear()
		_leaf_cache_dirty = true   # a felled tree stops shedding leaves
		_crystal_seams_valid = false   # a dig or place near ore changes which cells are exposed: reflood seams
		# The mold follows the dug shape, but patch only the changed region's fine cells rather than the whole
		# grid: the per-dig freeze was the full fine rebake this used to trigger.
		_fine_region_pending = true
		_fine_dirty_min = rmin
		_fine_dirty_max = rmax
		# The veil is a pure light level: it carries no material colour, so a dig never patches its hue. Only
		# the skylight base cares, because a dig can move the surface line, and only in the columns that
		# changed.
		if _veil_cols_dirty:
			_veil_col_min = mini(_veil_col_min, rmin.x)
			_veil_col_max = maxi(_veil_col_max, rmax.x)
		else:
			_veil_col_min = rmin.x
			_veil_col_max = rmax.x
		_veil_cols_dirty = true
	if _fine_dirty:
		_bake_fine_terrain()          # Full rebake (initial / load): the slow lane
		_tooth_grammar()
	elif _fine_region_pending:
		_bake_fine_region(_fine_dirty_min, _fine_dirty_max)   # the per-dig fast lane
		_tooth_grammar()
		_fine_region_pending = false
	elif _fine != null and _fine.pending_rows() > 0:
		# The boot bake painted only what was on screen. Fill the rest a slice per frame, off-camera and
		# after a dig has had its turn, because a dig is the one edit that is visible immediately. See
		# FineTerrain.bake_pending.
		_fine.bake_pending(FINE_FILL_BUDGET_US)
		if _fine_layer != null:
			_fine_layer.queue_redraw()


## Full bake: every chunk, onto a freshly cleared target. Used for the initial paint and for a wholesale
## change such as loading a save, where nothing on the target can be trusted. CLEAR_MODE_ONCE rather than
## always, because the target is retained from here on and clearing it again would undo every partial bake
## below.
func _bake_terrain_full() -> void:
	for chunk: LightLayer in _chunks:
		chunk.visible = true
		chunk.queue_redraw()
	_erase_rects.clear()
	_terrain_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_terrain_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_terrain_layer.queue_redraw()


## Partial bake: the per-dig fast lane, and the fix for the mining hitch.
##
## Only the dirty chunks are made visible, so only their retained draw buffers are replayed; every other
## chunk keeps the pixels already in the target. The eraser blanks the dirty rects first, because a chunk
## repaint can only ADD coverage, and a cell dug open to the sky would otherwise keep its rock.
##
## Chunks stay hidden after this returns, which is safe: the viewport re-renders only when a bake asks it
## to, and every bake sets visibility for itself before asking.
func _bake_terrain_chunks(dirty: Dictionary) -> void:
	_erase_rects.clear()
	for i: int in _chunks.size():
		var on: bool = dirty.has(i)
		_chunks[i].visible = on
		if on:
			_chunks[i].queue_redraw()
			var cx: int = i % _chunk_cols
			var cy: int = i / _chunk_cols
			_erase_rects.append(Rect2(float(cx * CHUNK * CELL), float(cy * CHUNK * CELL),
				float(CHUNK * CELL), float(CHUNK * CELL)))
	_eraser.queue_redraw()
	_terrain_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_terrain_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_terrain_layer.queue_redraw()


## Blank the rects a partial bake is about to repaint. The material's `blend_disabled` is what makes this a
## clear rather than a no-op; see scenes/erase.gdshader.
func _paint_erase(layer: LightLayer) -> void:
	for r: Rect2 in _erase_rects:
		layer.draw_rect(r, Color(0.0, 0.0, 0.0, 0.0))


## The row-major index of the chunk owning `cell`, or -1 if the cell is out of the world.
func _chunk_index(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= FactorySim.GRID_COLS or cell.y >= FactorySim.GRID_ROWS:
		return -1
	return (cell.y / CHUNK) * _chunk_cols + (cell.x / CHUNK)


# --- draw sequence (world space; the Camera2D provides the view transform) ----

func _draw() -> void:
	_zoom = get_canvas_transform().get_scale().x   # once per frame; every zoom gate below reads this
	# Terrain, background walls and the smoothed surface are static: drawn by the chunked terrain canvases
	# below this at z -10 and repainted only on the dug chunk. This per-frame pass draws only the live and
	# sparse content (machines, items, conduits, cursor), with no full-world cell loop.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE).grow(1.0), Color(0.22, 0.23, 0.27), false, 2.0)  # world border
	_draw_crumble()   # a just-mined block shattering away at the terrain layer
	_draw_seams()     # the rock's grain: the planes a blow can follow
	_draw_drop_paths()
	_draw_lode()      # ore in the back wall: the vein you cleared the rock off, and how much is left
	_draw_seal_pulse(_view_world_rect())  # the unbreakable band's slow violet breath. It is a wash on rock,
	                                      # so it belongs under the veil with the rock it is painted on. The
	                                      # ore flares used to be drawn here and are not any more: they are a
	                                      # light, and _paint_lights draws them above the veil.
	_draw_updrafts()  # rising shimmer in each lift's shaft, so the column reads as lifting up
	_draw_conduits()  # power tubes (copper, with a channel that glows by the live power level)
	_draw_power_pulses()  # bright beads flowing down the live network: energy visibly moving
	_rope._draw_ropes()     # placed climb-ropes hanging down their shafts (behind machines and the body)
	_draw_torches()   # mounted torches guttering on the walls: placed light, claimed territory
	_draw_saplings()  # planted sprouts growing on the sim's tick
	_draw_ground()
	_water._draw_water()     # the fluid layer: translucent blue pools filling each cell to its water line
	_water._draw_fill_tells() # player construction: packed fill reads as aggregate, loose fill weeps
	_draw_surface_life()  # drifting leaves off the canopies and the occasional bird
	falling.draw(self, _view_world_rect(2.0))
	# Cull machines whose cell is off-screen. Margin 3 cells so a partially-on-screen machine's glow,
	# held-count badge, I/O ports, status bubble and contact shadow, all of which reach past its own cell,
	# are not clipped at the view edge. Off-screen machines are not visible, so skipping is pixel-identical.
	var mview: Rect2 = _view_world_rect(3.0)
	_machines._plan_machine_labels(mview)   # nameplates are laid out for the whole frame before any of them draws
	for machine: MachineState in sim.machines:
		if not mview.has_point(Vector2(machine.cell) * float(CELL)):
			continue
		_machines._draw_machine(machine)
	if bazaars != null:
		bazaars.draw(self)  # decorated stall and the block-by-block transform, over the wood frame
	if particles != null:
		particles.draw(self)
	_draw_mine_cracks()    # spider cracks on the block being charge-mined (the felt friction)
	_draw_scan()           # the sonar pulse and vein echoes
	_draw_speed_streaks()  # motion lines behind a body moving faster than it can run
	_rope._draw_grapple()        # the live line and its hook, over the world and under the HUD
	_draw_aim()
	if payouts != null:
		payouts.draw(self)  # "+N" gain ticks last: the reward should never be buried by the world


## The sonar: an expanding wavefront ring from the body and, as it passes each vein's true distance, an
## echo: a pip and expanding ring in the vein's own nugget colour, glowing through the rock, lingering a
## few seconds, then gone. Prospecting rather than a map reveal: transient, local, and it only ever shows
## deposits that were in range when you fired.
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
		# The return itself: a diamond pip big enough to read in daylight, since the additive glow only
		# carries it in the dark, and white-cored so it reads as signal rather than as another ore fleck.
		var r: float = 4.5 + 1.0 * fade
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0.0, -r), pos + Vector2(r, 0.0),
			pos + Vector2(0.0, r), pos + Vector2(-r, 0.0)]),
			Color(col.r, col.g, col.b, 0.55 + 0.4 * fade))
		draw_circle(pos, 1.6, Color(1.0, 1.0, 1.0, 0.55 + 0.4 * fade))


## The post-veil marker pass. Everything here is something the player put on the world rather than
## something the world contains, which is why it is exempt from the darkness the world obeys, the same
## exemption `_player` has at z 60. Drawn MIX so each mark arrives at the colour it was authored in; see
## the note where `_marks` is created for the measurements that put it here.
func _paint_marks(layer: LightLayer) -> void:
	_draw_dig_marks(layer)      # the painted dig plan: corner-bracketed cells waiting for the pick
	_draw_guide_targets(layer)  # bobbing chevron, or a placement ghost, on the current objective step
	_draw_ping(layer)           # the map-click beacon: a cyan pin bobbing over the marked spot with an
	                            # expanding sonar ring, findable from across a cavern on foot


func _draw_ping(canvas: CanvasItem) -> void:
	if _ping_world.x == INF:
		return
	var ring: float = fmod(_anim_time, 1.6) / 1.6
	var col := Color(0.45, 0.95, 1.0)
	canvas.draw_arc(_ping_world, 6.0 + ring * 26.0, 0.0, TAU, 28,
		Color(col.r, col.g, col.b, 0.5 * (1.0 - ring)), 2.0)
	var bob: float = sin(_anim_time * 3.0) * 2.5
	var tip: Vector2 = _ping_world + Vector2(0.0, -4.0 + bob)
	canvas.draw_line(tip, tip + Vector2(0.0, -10.0), Color(col.r, col.g, col.b, 0.85), 1.5)
	var head: Vector2 = tip + Vector2(0.0, -13.0)
	canvas.draw_colored_polygon(PackedVector2Array([head + Vector2(0.0, -4.5), head + Vector2(4.0, 0.0),
		head + Vector2(0.0, 4.5), head + Vector2(-4.0, 0.0)]), col)
	canvas.draw_circle(head, 1.4, Color(0.06, 0.10, 0.14))


## The painted dig plan: each marked cell wears amber corner brackets and a whisper of fill, breathing
## gently so the plan reads as queued for the pick, quieter than the aim cursor and the objective marker.
## Marks are the controller's live dict; pruning stale entries is its job.
func _draw_dig_marks(canvas: CanvasItem) -> void:
	if _dig_marks.is_empty():
		return
	var view: Rect2 = _view_world_rect()
	var pulse: float = 0.65 + 0.35 * sin(_anim_time * 2.6)
	var edge := Color(0.95, 0.72, 0.30, 0.30 + 0.25 * pulse)
	var fill := Color(0.95, 0.72, 0.30, 0.05)
	for key: Variant in _dig_marks:
		var cell: Vector2i = key
		if not view.has_point(Vector2(cell) * float(CELL)):
			continue
		# The same corners the cursor puts on the thing it is over, at a thinner stroke. A marked cell is a
		# thing the pick will act on, only later and not now, and the difference between now and later is
		# worth a stroke width rather than a whole second shape. `_cell_corners` cuts both, so the two can
		# never drift into two marks.
		canvas.draw_rect(_mark_wash(cell), fill)
		_cell_corners(canvas, _mark_rect(cell), edge, 1.5)


## Spider cracks across the block currently being charge-mined, growing with the break progress pushed via
## set_mine_progress, so hand-mining reads as effortful work on a specific block rather than an instant
## pop. Deterministic crack angles per cell (no RNG) plus a darkening overlay, so the rock visibly weakens.
func _draw_mine_cracks() -> void:
	if _mine_frac <= 0.001 or not sim.is_solid(_mine_cell):
		return
	var pos := Vector2(_mine_cell) * float(CELL)
	var center := pos + Vector2(CELL, CELL) * 0.5
	draw_rect(Rect2(pos, Vector2(CELL, CELL)), Color(0.0, 0.0, 0.0, 0.22 * _mine_frac))  # weakening shade
	var n: int = 2 + int(_mine_frac * 5.0)
	# Light fractures over a dark underlay, so they read on any material in the dark underground. They
	# brighten and lengthen with the charge, with a bright impact pip near full.
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


## Surface life, so the top of the world stops reading static. Each canopy cell sheds a drifting leaf on its
## own long cycle; position is a pure function of the cosmetic clock, so no per-leaf state is kept. Every so
## often a bird crosses the sky. Zero allocations and no sim reads beyond the cached canopy list, which is
## rebuilt only when terrain changes, so a felled tree stops shedding.
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
	# The bird: one silhouette crossing the whole world's sky on a long cycle, with direction and altitude
	# picked per crossing. Two flapping wing-strokes, three draw calls. Birds fly by day only; after dusk the
	# sky belongs to the stars.
	const CYCLE: float = 47.0
	const CROSS_T: float = 16.0
	var cyc: int = int(_anim_time / CYCLE)
	var ct: float = fmod(_anim_time, CYCLE)
	if ct < CROSS_T and daylight() > 0.5:
		# `Seams.grain` rather than a bare `cyc * 2654435761`: that constant is odd, so its low bit is the
		# low bit of `cyc` untouched, and `bh % 2` was exactly `cyc % 2` over 100,000 verified cycles. The
		# bird reversed direction on every single crossing, which is a metronome rather than a choice, and
		# altitude marched in steps of +23 for the same reason. Two salts keep heading and height apart.
		var bh_dir: int = Seams.grain(Vector2i(cyc, 11))
		var bh_alt: int = Seams.grain(Vector2i(cyc, 22))
		var frac: float = ct / CROSS_T
		var span: float = float(FactorySim.GRID_COLS * CELL)
		var bx: float = lerpf(-80.0, span + 80.0, frac if bh_dir % 2 == 0 else 1.0 - frac)
		var by: float = float(SURFACE_LINE * CELL) - 190.0 - float(bh_alt % 90) \
			+ sin(ct * 1.3) * 10.0
		if view.has_point(Vector2(bx, by)):
			var flap: float = absf(sin(ct * 9.0)) * 5.0
			var bc := Color(0.16, 0.18, 0.24)
			draw_line(Vector2(bx - 6.0, by - flap + 2.0), Vector2(bx, by), bc, 1.6)
			draw_line(Vector2(bx, by), Vector2(bx + 6.0, by - flap + 2.0), bc, 1.6)


## Crystal/ore glow: the cool accent light. Coloured light reads as a feature when it is big and cohesive
## and as confetti when it is scattered dots, so instead of glowing isolated cells this clusters nearby
## exposed ore into a few cohesive seams: flood-connect adjacent exposed vein cells, then emit one glow per
## cluster (centroid plus a radius that grows with the cluster's extent). Both _update_veil, which cuts a
## cool hole, and _paint_lights, which lays the pool, call this, so reveal and glow never disagree.
const CRYSTAL_COLOR := Color(0.34, 0.86, 1.0)          ## saturated cyan-teal: the cool pole against the warm lamp
const CRYSTAL_MAX: int = 6                             ## hard cap of glowing seams on screen
const CRYSTAL_MIN_CELLS: int = 2                       ## exposed cells a seam needs to glow (kills lone specks)

## The exposed-ore cells in view: still solid, has-nuggets, touching a carved cavity. The raw material a
## seam is built from, split out so the clustering can walk it deterministically.
func _exposed_ore_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var view: Rect2 = _view_world_rect()
	for key: Variant in sim.deposits:
		var c: Vector2i = key
		var pos := Vector2(c) * float(CELL)
		if not view.has_point(pos) or not sim.is_solid(c):
			continue
		var md: MaterialDef = _material(sim.material_at(c))
		if not md.has_nuggets() or not md.glitters:  # coal has nuggets but does not glitter: it is fuel
			continue
		# Only exposed ore glows. A crystal seam catches light where it meets a carved cavity, so at least one
		# orthogonal neighbour must be open air, which confines the accent to carved edges.
		if sim.is_solid(c + Vector2i(0, -1)) and sim.is_solid(c + Vector2i(0, 1)) \
				and sim.is_solid(c + Vector2i(-1, 0)) and sim.is_solid(c + Vector2i(1, 0)):
			continue
		out.append(c)
	return out


## Cluster the exposed-ore cells into cohesive seams. Greedy flood: pop a cell, absorb every still-unclaimed
## cell within CLUSTER_LINK of it via a growing frontier, and emit the group as one glow
## {pos = centroid, radius = base + extent}. Deterministic, since it iterates a sorted cell list. Clusters
## smaller than CRYSTAL_MIN_CELLS are dropped as noise.
const CLUSTER_LINK: int = 3                             ## cells within this chebyshev distance join one seam

## Side length of a spatial-hash bucket, in cells. Any value >= CLUSTER_LINK works; at 4 the seven-cell
## neighbourhood a frontier pop has to search spans at most three buckets per axis.
const CLUSTER_BUCKET: int = 4

func _crystal_seams() -> Array[Dictionary]:
	return _cluster_seams(_exposed_ore_cells())


## The flood itself, split out from the world query above so it can be tested as a pure function from a cell
## list to a seam list. check_seam_flood drives it with synthetic scatters and clumps and compares it against
## the obvious quadratic implementation, which is a harder test than one world.
##
## The search is spatial, not linear. Rescanning the entire cell list for every frontier pop is O(n^2) in
## exposed ore, on the frame where n is largest, because digging is what exposes ore. Each pop now looks only
## in the buckets its own neighbourhood can reach.
##
## The absorption order must be preserved. This is a greedy flood, so the order cells are absorbed in decides
## which seam a cell between two seams lands in, and therefore the centroids and radii that get drawn. The
## linear scan walked a globally sorted list, so for a given frontier cell it absorbed matching cells in
## sorted order; the gathered candidates are re-sorted here to reproduce that. Without the sort this is still
## a correct clustering and a different picture.
func _cluster_seams(from_cells: Array[Vector2i]) -> Array[Dictionary]:
	var cells: Array[Vector2i] = from_cells.duplicate()
	cells.sort()                                        # deterministic flood order
	# cell -> bucket, and bucket -> the cells in it. floori rather than `>> 2`, and not because of sign:
	# GDScript's right shift on ints floors toward negative infinity, so the two agree on every coordinate
	# including negative ones. The reason is narrower: `>>` silently requires CLUSTER_BUCKET to be a power of
	# two, and nothing else here does. floori keeps the constant free.
	var buckets: Dictionary = {}
	for c: Vector2i in cells:
		var key := Vector2i(floori(float(c.x) / float(CLUSTER_BUCKET)), floori(float(c.y) / float(CLUSTER_BUCKET)))
		if not buckets.has(key):
			buckets[key] = ([] as Array[Vector2i])
		(buckets[key] as Array[Vector2i]).append(c)
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
			var near: Array[Vector2i] = []
			var bx0: int = floori(float(g.x - CLUSTER_LINK) / float(CLUSTER_BUCKET))
			var bx1: int = floori(float(g.x + CLUSTER_LINK) / float(CLUSTER_BUCKET))
			var by0: int = floori(float(g.y - CLUSTER_LINK) / float(CLUSTER_BUCKET))
			var by1: int = floori(float(g.y + CLUSTER_LINK) / float(CLUSTER_BUCKET))
			for by: int in range(by0, by1 + 1):
				for bx: int in range(bx0, bx1 + 1):
					var key := Vector2i(bx, by)
					if not buckets.has(key):
						continue
					for other: Vector2i in (buckets[key] as Array[Vector2i]):
						if claimed.has(other):
							continue
						if absi(other.x - g.x) <= CLUSTER_LINK and absi(other.y - g.y) <= CLUSTER_LINK:
							near.append(other)
			near.sort()                                 # the globally-sorted order the linear scan had
			for other: Vector2i in near:
				if claimed.has(other):                  # a bucket overlap can offer the same cell twice
					continue
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
		var radius: float = float(CELL) * 2.2 + extent * 0.55         # bigger seam, bigger cohesive glow
		seams.append({"pos": centroid, "radius": radius, "cells": group})
		if seams.size() >= CRYSTAL_MAX:
			break
	return seams


## The frame accessor for crystal seams. The raw _crystal_seams() flood is expensive and was run twice per
## frame, once in _update_veil and once in _paint_lights. It only changes when ore exposure changes (a dig or
## place near ore clears _crystal_seams_valid) or when the culling view-rect pans and a seam scrolls on or
## off screen. Recompute on either signal, otherwise replay the cached list, so the veil cut and the light
## pool read the identical seams and it floods once per frame rather than twice. _crystal_seams() itself
## stays the pure compute, so the profiler can measure it in isolation.
func _crystal_seams_cached() -> Array[Dictionary]:
	var view: Rect2 = _view_world_rect()
	if not _crystal_seams_valid or view != _crystal_seams_view:
		_crystal_seams_cache = _crystal_seams()
		_crystal_seams_view = view
		_crystal_seams_valid = true
	return _crystal_seams_cache


## The glow colour for an ore seam, derived from the seam's own material so the accent light agrees with the
## flecks in the rock rather than putting a cyan glow on orange ore. Takes the first cell's material
## `nugget_color` and pushes it toward saturation, because a light source reads as a purer hue than the
## embedded speck. A material with no nuggets falls back to CRYSTAL_COLOR.
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


## The lode in the wall (`docs/LODE.md` §4). Ore is a face you work rather than a block you punch out, so it
## draws as a face: a wash of the ore's colour on the backing plus its flecks embedded in it, permanent, and
## it has to hold up to being looked at for a long time. This is not the glint, which is a rare twinkle that
## says something is over there and still fires on top of this.
##
## It thins as it drains. `deposits` is the number the player plans around, and a 250-unit cell used to be
## pixel-identical to a 4-unit one, so a rig chewing a fat vein showed no progress at all (`docs/DRIFT.md`).
## The fleck set is deterministic per cell and the draw takes a prefix of it, so flecks disappear one by one
## as the vein is worked rather than reshuffling, and a half-worked vein looks like the same vein, half
## worked.
##
## Only exposed lode draws here. Ore still behind rock is the stain's job (`docs/LODE.md` §10).
func _draw_lode() -> void:
	if sim.lode.is_empty():
		return
	var view: Rect2 = _view_world_rect()
	var cell_f: float = float(CELL)
	for key: Variant in sim.lode:
		var c: Vector2i = key
		var base := Vector2(c) * cell_f
		if not view.has_point(base) or sim.is_solid(c):
			continue
		var frac: float = sim.lode_fraction(c)
		if frac <= 0.0:
			continue
		var def: MaterialDef = _material(sim.lode[c])
		if not def.has_nuggets():
			continue
		# The matrix is baked into the wall plane (see `_wall_base_color`); what is left for the live pass is
		# the metal in it, and how much of it is left, which is the reason this draw exists.
		var nug: Color = _zone_tinted(def.nugget_color, c.y)
		var all: Array[Vector2] = _cell_speckles(c, def.nugget_count)
		var n: int = maxi(1, int(round(frac * float(all.size()))))
		for i: int in n:
			var p: Vector2 = base + all[i]
			# Size and facing are read back out of the position, so the grain field stays deterministic per
			# cell without a second hash to keep in step with the first as the prefix shortens.
			var j: float = fposmod(all[i].x * 0.37 + all[i].y * 0.19, 1.0)
			var spin: float = fposmod(all[i].x * 0.11 + all[i].y * 0.53, 1.0) * TAU
			_draw_grain(p, GRAIN_MIN + GRAIN_VARY * j, spin, nug)


## How big a grain of metal is, and how much the size varies across a face. Small, because the fleck field
## has to survive being stared at for as long as it takes to build on it, and a big fleck reads as a sticker.
const GRAIN_MIN: float = 1.45
const GRAIN_VARY: float = 1.15
const GRAIN_SEAT := Vector2(0.6, 0.9)                ## how far the grain's own shadow falls behind it
const GRAIN_SEAT_COLOR := Color(0.0, 0.0, 0.0, 0.38)
const GRAIN_BODY_DARK: float = 0.34                  ## the grain's midtone, under its nugget colour
const GRAIN_LIT: float = 0.42                        ## the facet the light is on
const GRAIN_SHADE: float = 0.36                      ## ...and the one it is not


## One grain of metal in the face: angular, and lit from one side.
##
## A circle with a bright core reads as a bubble, and six of them per cell reads as foam. A grain is a facet
## instead: a small quad seated in its own shadow, split into a lit half and a shaded half. The two-tone
## split is what does the work, because it makes the grain a shape catching light rather than a dot emitting
## it, which is `docs/LODE.md` §11's rule ("ore does not glow, it answers your lamp") applied at the level of
## one fleck. The veil overhead still dims the whole field where no lamp reaches it.
func _draw_grain(p: Vector2, r: float, spin: float, nug: Color) -> void:
	var ax := Vector2(cos(spin), sin(spin)) * r
	var ay := Vector2(-ax.y, ax.x) * 0.74
	var q := PackedVector2Array([p + ax, p + ay, p - ax, p - ay])
	var seated := PackedVector2Array([
		q[0] + GRAIN_SEAT, q[1] + GRAIN_SEAT, q[2] + GRAIN_SEAT, q[3] + GRAIN_SEAT])
	draw_colored_polygon(seated, GRAIN_SEAT_COLOR)
	var body: Color = nug.darkened(GRAIN_BODY_DARK)
	draw_colored_polygon(q, body)
	draw_colored_polygon(PackedVector2Array([q[3], q[0], p]), body.lightened(GRAIN_LIT))
	draw_colored_polygon(PackedVector2Array([q[1], q[2], p]), body.darkened(GRAIN_SHADE))


## Knockout switch for the glint, default true; only measurement code sets it false. A cosmetic cue that
## cannot be switched off cannot be measured by subtraction, and subtraction is the one instrument whose
## answer does not depend on how the subject happens to be distributed on screen. The alternative, splitting
## exposed ore into clustered and lone and comparing them, had six cells in it, because `_cluster_seams`
## absorbs ~87% of exposed ore; three of its nine runs divided 0 by 0 and printed a confident zero.
var draw_glints: bool = true


## The glint has to be drawn above the veil, which is the same layer-order trap as rock_grit.
##
## Drawn from `_draw` at z 0, every flare was scaled by `_dark`, the LightLayer at z 50 with BLEND_MODE_MUL
## that makes rock dark. `glint_dark` below raises the flare's alpha as the surround darkens, so the
## compensation and the attenuation were the same number and cancelled.
##
## Knockout confirms it. Suppressing the flares entirely changed which ore cells reach the frame's brightest
## 1% by nothing (9 of 13, 12 of 20, 20 of 30 discovered, identical cell for cell with the cue on and off)
## and moved ore's share of that band by -10.5%, -0.35% and +0.6%. The +0.6% is the tell that a per-frame
## quantile measures its own threshold: deleting pixels lowers the bar and lets others in. Every ore cell
## that did reach the bright band got there on the seam light pool, which `_paint_lights` draws at z 51,
## above the veil.
##
## So this is called from `_paint_lights`, additive and post-veil, on the same canvas as the pools it was
## losing to. `glint_dark` is kept and now does what it describes: a surface vein in daylight stays quiet
## and a vein in the deep flares at full strength, with nothing downstream to take it back.
##
## What is left wrong with the glint is its colour rather than its loudness, and that is left alone on
## purpose. It arrives at rgb 255,255,~237 in both underground frames, which is white, and it cannot arrive
## as anything else: `ore.nugget_color` is (0.78, 0.81, 0.85) at HSV saturation 0.082, and the
## `.lightened(0.65)` below takes that to 0.026, six levels of chroma against 26 for iron and 52 for
## rich_ore, before the additive composite, the palette grade and the WorldEnvironment glow finish clipping
## R and G. The brightest mineral mark in the game therefore says bright rather than ore, while the grains
## that do carry the ore's hue (`_draw_lode`, 159 levels of chroma in daylight) sit at 234 up top and at
## 82-89 under the veil. `glint_dark` compounds it by design, driving the flare to full strength exactly
## where the rock is darkest, which is exactly where the ore being marked cannot be seen. Every repair for
## it (a smaller `lightened`, a ceiling held under UI white, or removing the overdraw where the two lines
## and the circle stack additively at the star's centre) changes how loud and what colour a deliberate
## discovery cue is, so it is a look decision rather than a tuning one.
##
## The per-cell phase hash below is not a linear-sequence-as-hash site: its `% 997` outputs have 13, 14 and
## 28 distinct gaps over a 16-cell horizontal run, a 16-cell vertical face and a 6x6 patch, so there is no
## three-distance lattice, unlike the star and cloud fields.
func _draw_glint_flares(view: Rect2, canvas: CanvasItem) -> void:
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
		# Only exposed ore glints: a fleck catches the light at a dug face, not buried in solid rock. Ore
		# twinkling everywhere, including cells sealed inside stone, reads as a floating starfield; gating to
		# exposed faces clusters the sparkle onto the vein that has been dug into. Discovery from across a
		# dark cavern is carried by the cohesive crystal-seam glows instead.
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
		var r: float = 2.0 + 2.5 * flare                        # a small 4-point star, not a lens flare
		canvas.draw_line(p + Vector2(-r, 0.0), p + Vector2(r, 0.0), col, 1.2)
		canvas.draw_line(p + Vector2(0.0, -r), p + Vector2(0.0, r), col, 1.2)
		canvas.draw_circle(p, 1.1 + 0.8 * flare, Color(col, minf(1.0, col.a + 0.15)))


## The seal's slow violet breath, so the unbreakable band reads as dormant power rather than dark rock. Rows
## are found once by scanning a couple of probe columns per row, since the band is full-width by
## construction; each visible still-solid sealrock cell breathes a faint wash on a long cycle.
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


## Painter for one terrain chunk, bound to its cell `rect`: background walls, terrain cells and the smoothed
## surface, but only for cells inside this chunk. A CanvasItem is not clipped to `rect` (the surface wedge
## may reach one cell above it), so cross-boundary detail draws fine; `rect` only bounds which cells this
## chunk is responsible for. The world border is drawn by the dynamic _draw, as one thin outline.
func _paint_terrain_chunk(ci: CanvasItem, rect: Rect2i) -> void:
	_draw_background(ci, rect)  # sky within this chunk, and the back wall behind every dug-out cell
	TerrainPainter.paint(self, ci, rect)   # solid cells in this chunk, ending with the surface cap for its columns


## Draw the baked coarse terrain (the SubViewport render-target) as one quad at z -10: the ~11,882-draw chunk
## pass collapsed to a single textured rect. World rect 1:1, NEAREST filter so it snaps crisply with the
## pixel-snap camera. The render-target holds the chunk painters' exact output, since it is the same draw
## code, so this is pixel-identical to a per-chunk pass; it only re-renders on a terrain change.
func _paint_terrain_bake(layer: LightLayer) -> void:
	if _terrain_viewport == null:
		return
	layer.draw_texture_rect(_terrain_viewport.get_texture(),
		Rect2(Vector2.ZERO, WORLD_SIZE), false)


## Draw the placed power conduits. Each tube is a copper segment with stubs to whatever it couples to
## (adjacent conduits, the generator feeding it, a machine drawing from it) and an inner channel that glows
## from dim to gold by the live power it carries, so a powered trunk reads as a bright line pouring down the
## shaft and a dead tube reads dark. The power level is a derived field; this pass is read-only.
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
		# Copper casing: the centre node plus a stub toward each coupling, defaulting to a short vertical nub.
		draw_circle(center, 4.5, COPPER)
		if stubs.is_empty():
			stubs = [center + Vector2(0.0, float(CELL) * 0.5), center - Vector2(0.0, float(CELL) * 0.5)]
		for s: Vector2 in stubs:
			draw_line(center, s, COPPER, 7.0)
		# Inner channel glow over the same casing, lit by the power it carries.
		draw_circle(center, 2.2, glow)
		for s: Vector2 in stubs:
			draw_line(center, s, glow, 3.0)


## A conduit's power as a 0..1 fraction of tube capacity: the shared reading the copper channel draw and the
## emitted light pool both key off, so the tube and its glow never disagree.
func _conduit_level(cell: Vector2i) -> float:
	return clampf(sim.power_at(cell) / FactorySim.CONDUIT_CAPACITY, 0.0, 1.0)


## Power pulses: bright beads travel the live conduit network so energy visibly flows, down every vertical
## link and outward along downhill laterals, never up, which is the sim's locked hook made visible. Bead
## count and brightness scale with the power the tube carries; a dead tube shows nothing. Cosmetic clockwork
## over the copper draw: reads the derived power field, never writes it.
const PULSE_SPEED: float = 1.7                        ## links traversed per second by a bead
func _draw_power_pulses() -> void:
	var view: Rect2 = _view_world_rect(2.0)
	for cell: Variant in sim.conduit:
		var c: Vector2i = cell
		if not view.has_point(Vector2(c) * float(CELL)):
			continue
		var lvl: float = _conduit_level(c)
		if lvl < 0.08:                                # dead or near-dead tube: no flow to show
			continue
		var center: Vector2 = Vector2(c) * float(CELL) + Vector2(CELL, CELL) * 0.5
		# Flow links leaving this node: down, if coupled to a conduit or a consumer machine, plus downhill
		# laterals toward an equal-or-lower conduit, with ties going right. Never up: that would deny the hook.
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




## Draw the mounted torches: the shared Visuals glyph, live-guttering on the cosmetic clock. The warm pool
## each one casts is painted by _paint_lights; this is just the stick and flame.
func _draw_torches() -> void:
	var view: Rect2 = _view_world_rect(2.0)
	for cell: Variant in sim.torch:
		if not view.has_point(Vector2(cell as Vector2i) * float(CELL)):
			continue
		Visuals.draw_machine_glyph(self, _cell_center(cell), "torch", 1.0, true, _anim_time)


## Draw the planted saplings: a sprout rooted at the cell's floor that grows visibly taller with its
## progress, so a just-planted seed is a nub and a nearly-grown one brushes the cell above. The sway is
## cosmetic; growth itself is sim state (FactorySim.sapling ticks).
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


## Depth-zone palettes. Each zone pulls the terrain toward its own temperature, eased across a transition
## band so strata read as different places rather than as stripes. Topsoil keeps its warm material colours,
## since no entry means no tint. A new depth layer is one new row here; bands straddle their transition, and
## strength is the held tint.
##
## The descent runs a four-beat colour arc a player can feel without reading a depth gauge: warm ochre clay
## carries the topsoil's warmth a little way down and then loses it, the middle stone sits neutral so the
## rest is measured against it, the approach to the seal goes cold violet, and Stonereach chills into
## slate-blue below the seal. Depth sold by darkness alone is the weakest of the available signals, and it is
## the one the shadow veil is already spending.
##
## The bands are spanned against the 128-row world, so a band is a stretch you travel rather than a step you
## cross.
const ZONE_TINTS: Array[Dictionary] = [
	{"from": 30, "to": 46, "color": Color(0.86, 0.58, 0.30), "strength": 0.22},   # Clayband: warmth to lose
	{"from": 48, "to": 62, "color": Color(0.55, 0.58, 0.66), "strength": 0.16},   # the honest neutral middle
	{"from": 64, "to": 84, "color": Color(0.40, 0.30, 0.62), "strength": 0.26},   # the approach to the seal
	{"from": 86, "to": 118, "color": Color(0.42, 0.55, 0.90), "strength": 0.34},  # Stonereach (L2), below the seal
]


## Ease `col` toward every zone tint whose band `row` has entered. Applied to terrain and walls, so the whole
## stratum shifts together; machines and items stay untinted, because the artificial keeps its own colour.
func _zone_tinted(col: Color, row: int) -> Color:
	for z: Dictionary in ZONE_TINTS:
		var lo: int = int(z["from"])
		if row <= lo:
			continue
		var t: float = clampf(float(row - lo) / float(int(z["to"]) - lo), 0.0, 1.0)
		col = col.lerp(z["color"] as Color, float(z["strength"]) * smoothstep(0.0, 1.0, t))
	return col


## The final fill colour for a terrain cell: the material's base darkened with depth, then nudged by the
## deterministic tonal jitter so a field of earth is not one flat colour. Extracted so the surface ramp wedge
## fills with exactly the same colour as the cell body below it: the slope is the same earth mass, not a
## sticker on top.
func _cell_fill_color(c: Vector2i, def: MaterialDef) -> Color:
	return FineTerrain.apply_tone(_cell_base_color(c, def), _cell_tone(c))


## The cell's colour before any tone: the material's base darkened with depth and zone-tinted. Split out for
## the fine bake, which needs the base and the tone separately so it can reconstruct the tone field between
## coarse samples instead of inheriting one flat value per 32px cell. The coarse pass puts the two straight
## back together above, so its output is unchanged.
func _cell_base_color(c: Vector2i, def: MaterialDef) -> Color:
	var depth: float = clampf(float(c.y) / float(FactorySim.GRID_ROWS), 0.0, 1.0)
	# depth_darken is outweighed by the zone tints applied after it, and cannot be tuned out of that.
	# _zone_tinted lerps toward four mid-bright targets, so it both lightens the deep and attenuates
	# whatever this line did by (1 - strength). Measured authored luma from row 24 to row 88 rises in
	# every material that spans bands: coal +39.8, deepslate +33.7, ore +19.8, stone +12.2. Deleting
	# depth_darken makes those slopes steeper, not flatter (+41.1, +36.2, +22.6, +16.1), and applying it
	# after the tints instead only reaches flat for stone. The lever for a darker deep is ZONE_TINTS,
	# which is a palette decision rather than a tuning one. What makes the deep read dark in the shipped
	# image is the shadow veil, a separate multiply layer that never touches these bytes.
	var base: Color = def.base_color.darkened(depth * def.depth_darken)
	# The stain (`docs/LODE.md` §10). Rock with a vein behind it is mineralised rock and should look
	# it; otherwise, once ore stops being a block, the world is uniform stone and the only way to find
	# anything is to dig at random.
	#
	# It is a discolouration and nothing else. Not a glint: `_draw_glint_flares` establishes that sparkling
	# cells sealed inside stone read as a floating starfield rather than as a vein, so buried ore gets no
	# motion at all and §11's motion budget is spent entirely on opened faces. It is also far weaker than an
	# exposed face, because it has to be findable without being a map marker: what you notice is that a patch
	# of rock is not quite the colour of the rock beside it.
	if sim.lode.has(c):
		base = _stain(base, _material(sim.lode[c]), LODE_STAIN_BURIED)
		base.v *= LODE_STAIN_BURIED_DARK
	return _zone_tinted(base, c.y)


## Carry rock `amount` of the way toward the metal in it, in hue only: the host keeps the say over how lit it
## is. Shared by the buried stain and the exposed face so the two cannot drift apart, since an opened vein
## has to be the same vein, more so.
func _stain(host: Color, vein: MaterialDef, amount: float) -> Color:
	var out: Color = host.lerp(vein.nugget_color, amount)
	out.v = host.v * lerpf(1.0, LODE_STAIN_LIFT, amount / LODE_STAIN)
	return out


## The cell's (jitter, strata) tone, both already scaled by the depth boost.
##
## Contrast to spend. Underground, everything a cell is painted with is compressed twice: once by
## depth_darken, then again by the shadow veil sinking it toward a fraction of itself. A tonal range that
## reads fine in daylight survives that as mush, which is the mechanical reason deep rock read as fog. Both
## the jitter and the bedding therefore get progressively louder with depth, so what reaches the eye after
## the veil takes its cut is roughly as legible at the bottom of the world as at the top. Measured against a
## delve capture: at the veil's opacity roughly half a cell's own tonal range survives to the eye, so the
## compensation has to be well over 2x by the deep band before bedding reads down there at all.
##
## That boost is also why quantising these two to the coarse grid was costly, and why the fine bake
## reconstructs them: the term the game amplifies most was the term drawing the grid.
##
## Both are applied relative to the cell's own colour (see FineTerrain.apply_tone), then tinted. Absolute
## band targets looked right against brown topsoil and died below it: a dark clay target sits almost exactly
## on deep stone's own colour, so half the bedding became a no-op in the place that needed it most.
## Lightening and darkening the cell always swings, whatever the cell happens to be; the tint then rides on
## top for the hue that makes a band read as a different deposit rather than as shading.
func _cell_tone(c: Vector2i) -> Vector2:
	var depth: float = clampf(float(c.y) / float(FactorySim.GRID_ROWS), 0.0, 1.0)
	var boost: float = 1.0 + depth * 2.2
	return Vector2(_cell_jitter(c) * boost, _strata(c) * boost)


## Sedimentary banding: the ground's own structure. The cell jitter above breaks a field of earth out of one
## flat colour, but it drifts in cloudy isotropic patches, which reads as noise on a slab rather than as a
## slab made of something.
##
## Bands run horizontally, the direction you cut across as you sink, at three incommensurable frequencies, so
## fine laminations and thick beds overlap and the pattern never visibly repeats down a shaft. They are
## warped slowly along x so a layer dips and rises like real bedding instead of ruling a straight line across
## the world. Light bands go sandy and dark bands go to cool clay: a hue move rather than a value one,
## because value alone would only re-shade the same brown.
##
## Deterministic and RNG-free, and it feeds the fine-terrain bake through the same callable, so a dug face
## exposes the same layer the coarse cell was showing. The two band colours live on FineTerrain with
## `apply_tone`, which is the single authority for what a tone means to a pixel: the coarse pass and the fine
## pass have to agree, so only one of them may own it.
const STRATA_AMOUNT: float = 0.17              ## how far a band pulls toward its colour

func _strata(c: Vector2i) -> float:
	var y: float = float(c.y) + sin(float(c.x) * 0.055) * 2.4 + sin(float(c.x) * 0.021) * 3.6
	# Periods of roughly 18, 7 and 4 cells. A screen holds about 22 rows at the default zoom, so you always
	# see a thick bed, the two or three layers inside it, and the fine laminations between: the whole scale
	# ladder at once, which is what makes ground read as ground.
	var n: float = sin(y * 0.34) * 0.46 + sin(y * 0.88) * 0.36 + sin(y * 1.62) * 0.18
	return n * STRATA_AMOUNT


## A smooth, spatially-coherent value nudge over ~[-0.06, +0.06]. Low-frequency sines, so neighbouring cells
## share tone in cloudy patches, rather than a per-cell random that seams at every tile edge and so redraws
## the grid. Breaks the flat fill into organic light/dark drift. RNG-free, so it is determinism-safe.
func _cell_jitter(c: Vector2i) -> float:
	var x: float = float(c.x)
	var y: float = float(c.y)
	var n: float = sin(x * 0.37 + y * 0.21) + sin(x * 0.13 - y * 0.41) + sin((x + y) * 0.27)
	return n / 3.0 * 0.06


## A cell's MaterialDef via the registry, or a safe fallback so an unknown id still renders.
func _material(id: StringName) -> MaterialDef:
	return _materials.get(id, _materials.get(&"earth"))


## Public: a material's base colour by id, for the HUD minimap, which has no MaterialDef registry of its own.
## Handed to the HUD as a Callable so it does not depend on this node's internals.
func material_color(id: StringName) -> Color:
	return _material(id).base_color


## Deterministic in-cell speckle positions, RNG-free so it is determinism-safe: a stable hash of the cell
## seeds N points inset from the edges. Used for dirt grain and ore nuggets so terrain reads textured.
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


## Interface drawn into world space is not white. White is reserved for impact and for physical events.
##
## Without that rule every mark drifts to the top of the value range, because the top of the range is the
## cheapest way to make one more thing read. A rock shattering under the pick (`_draw_mine_cracks`,
## 0.92/0.94/1.00), a sonar return arriving (`_draw_scan`, a 1.0 core), a targeting ring parked on the
## objective cell for a whole step and the cursor box all spoke in the same voice, and the two that were
## events had nothing left to shout with.
##
## Pure white is the brightest mark this screen can make and there is exactly one of it, so it is spent on
## the rarest thing: something that has just happened, at the moment it happens. Chrome is what the player
## looks through rather than at, and it has no moment: the cursor, the build ghost's border, guidance. It
## is allowed to be bright, and it is not allowed to be white.
##
## One constant rather than a palette, because the sites that take it differ only in alpha and each already
## carries an alpha settled in place, some under the veil and some above it. Moving hue and leaving every
## alpha alone keeps this one change rather than two.
const CHROME := Color(0.78, 0.83, 0.92)


## An arrow is matter moving. A chevron is attention. Nothing else points.
##
## Four unrelated grammars had grown into the same handful of shapes, and every one read as "go this way":
## a solid wedge on a machine's edge for goods crossing there, the same wedge bobbing three cells up in the
## air on a line for the objective below it, and a stem with an open head for ore pouring out under the
## Drill, the Borer and each of the Drift Rig's two drop columns. Three of the four described a flow; the
## fourth did not, and it was the one carrying the whole of the game's guidance.
##
## An arrow says matter moves along the way it points. It is a solid head, with a stem when the goods
## travel a distance to get there and without one when they only cross a boundary, and it is always drawn
## in contact with the path it describes: on the casing edge the goods pass through, in the cell they land
## in. `_matter_wedge` draws that head for every one of them, so a machine's spout and a drop column's
## arrowhead are one mark called twice rather than two similar marks kept in step.
##
## A chevron says look here. It is an open stroke, it has no stem of its own, and it is the only mark in
## the file that floats free of the thing it means. Guidance owns it and nothing else may draw one. Its
## tether is dotted rather than drawn for the same reason the head opened up: a solid line running from a
## head down onto a cell is a stem, and a stem would make the mark an arrow pouring something into that
## rock, which is the drop column's sentence and the one thing guidance must not be caught saying.
##
## The rule reaches as far as the marks this file lays over the world and no further. `Visuals._lift`
## marches open chevrons up the Lift's body to mean goods rise through it, which is matter wearing the
## attention shape. That one sits inside the casing and is part of the picture of what the machine is
## rather than a note laid on top of the world, so it is a boundary case rather than a collision, and the
## first place to look if the two ever start reading as each other.
##
## Half-width and rise of the one chevron there is, in pixels. Kept here rather than at the draw site
## because it is the shape the rule names, and because a second chevron appearing anywhere with its own
## numbers is exactly the drift this is written down to stop.
const GUIDE_CHEVRON := Vector2(9.0, 10.0)


## A square is where you point. Corners are what you would act on. A dash is a plan. A bar is a refusal.
##
## Four shapes for two questions: what is the cursor on, and may I act on it. Five marks used to answer
## them and no two were cut from the same parts, and two of them were not cut differently at all. Over an
## empty cell the build ghost's border said yes in chrome and no in red at the same size and weight, so the
## difference between a press that lands and a press that does nothing was a hue, which is no difference to
## a player who cannot use hue.
##
## A square is the cursor and says only "here". One inset, one weight, chrome, and it neither breathes nor
## grows: it is on screen every frame of the game, and a mark that never leaves cannot be the mark that
## means now.
##
## Corners say this is the thing your next press acts on. They breathe, they grow, and they carry the
## thing's own colour, so they name what is under the cursor as well as where it is. That is the half of
## the sentence a neutral reticle could never say, and the reason this is the mark the active action keeps.
## `_cell_corners` cuts them for the hovered thing and for the painted dig plan alike, the plan wearing a
## thinner stroke of the same shape rather than a second shape to learn.
##
## A dash is a plan: something happens to this cell later, by your hand or by a machine's. It is the build
## previews' shape and the placement objective's.
##
## A bar is a refusal, struck across the cell it refuses, in the one red both refusals share. This part of
## the vocabulary has to survive being glanced at rather than read, which is why the answer is a shape and
## not only a colour.
##
## Nothing that aligns to a cell is round. The world keeps two rings and neither is a cell mark. The hook's
## endpoint (`_draw_aim_ghost`) sits where the hook would touch and is not snapped to the grid, so it reads
## as a contact point rather than as a square's worth of rock, which is what says it belongs to a different
## verb than the one the cursor is holding. The sonar's returns and the map pin's beacon expand, and a
## growing ring is an arrival rather than a place. The need bubble over a stalled machine gets a stem down
## onto the roof it speaks for: floating free in the dark it is a thin circle with a bolt struck through
## it, which is a prohibition sign in every language on earth, while a mark touching the thing it is about
## reads as a label.
##
## Where the rule stops: `Visuals.draw_status_mark` cuts a small cross for a machine wired to nothing, and
## a cross on a machine is close to the bar this file spends on refusal. That one is a lamp glyph inside
## the casing rather than a note laid over the world, so it is a boundary case in the same way
## `Visuals._lift`'s chevrons are, and the first place to look if the two start reading as each other.
##
## Inset from the cell edge that every mark here is drawn at, in pixels. One number rather than one per
## site, so a cell wearing two of them shows no seam between them.
const MARK_INSET: float = 1.0
## Stroke weight of the cursor square, of the corners and of a plan's dashes.
const MARK_W: float = 2.0
## The bar is heavier than the square it crosses, derived rather than typed so the two cannot drift apart:
## the square says where and the bar says no, and of the two only the bar has to arrive without being
## looked at.
const MARK_BAR_W: float = MARK_W * 1.5
## Corner arm length as a fraction of the cell. A quarter still reads as a corner; much longer and the four
## arms close up into the outline the square already owns.
const MARK_ARM: float = 0.25
## Where a wash inside a mark starts: clear of the outline's own stroke, so a fill under a square does not
## show through the line. Derived from the two above rather than written as the 2.0 it happens to come to,
## because a retuned stroke has to take its fill with it.
const MARK_FILL: float = MARK_INSET + MARK_W * 0.5
## The one red a refusal is drawn in. There were two, and nothing related them: rock over your drive's tier
## wore one, a blocked placement the other. This is the brighter, kept because a refusal answers something
## you are doing right now and is allowed to interrupt. Each site keeps the alpha it had already settled
## on, so only the hue moves.
##
## The red-amber the build previews warn in is deliberately not this. A warning says the machine you are
## about to place will sit there with nowhere to drain; a refusal says the press will not happen at all.
## One of them stops you and the other does not, and they should not arrive in the same colour.
const REFUSE := Color(0.95, 0.45, 0.40)


## The current objective's cell. Mode "ghost" is a dashed green cell showing where to place the next
## machine; mode "act" is a chevron bobbing in the air above the target with a tether down to it, over
## a faint wash on the cell itself (dig this, feed this forge). Cosmetic.
##
## one ring grammar, and it belongs to the active action. "act" used to draw a near-white reticle over a
## dark backing ring here, so the objective and the cursor were both breathing a shape around a cell, on
## the same 4.0 rad/s clock, in two colour languages, at once. The cursor's ring is the one that survives
## (`_draw_interact_pulse`): it appears only where the next action would land, it is drawn in the colour of
## the thing being acted on so it says what as well as where, and it leaves when you look elsewhere. An
## objective is a destination rather than an action, it sits on screen for the length of a whole step, and
## a mark that never goes away cannot be the mark that means now. So guidance points from above instead and
## stays out of the ring language entirely.
func _draw_guide_targets(canvas: CanvasItem) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_anim_time * 4.0)         # 0..1 breathing
	for t: Dictionary in _guide_targets:
		var cell: Vector2i = t["cell"]
		if not sim.in_bounds(cell):
			continue
		var center: Vector2 = _cell_center(cell)
		if String(t.get("mode", "act")) == "ghost":
			# A dashed cell, not a breathing one. An outline that grows around a cell is what the cursor
			# does when it lands on something you can act on, and a placement objective is not that: it is
			# a plan, which is the shape the build previews already wear and which this cell is about to
			# become one of. It still breathes in value, so it reads as live without borrowing the gesture.
			var g := Color(0.45, 1.0, 0.55, 0.35 + 0.45 * pulse)
			_draw_dashed_rect(canvas, _mark_rect(cell), g, 6.0, MARK_W)
		else:
			# The cell itself, so the tether lands on something definite rather than in the middle of rock that
			# looks like every other cell. A wash and not an outline: an outline around a cell is the cursor's
			# shape, and this is the one place that has to not borrow it. Chrome rather than the reticle's old
			# near-white, at the alpha the wash already carried.
			canvas.draw_rect(_mark_wash(cell), Color(CHROME.r, CHROME.g, CHROME.b, 0.10 + 0.10 * pulse))
		# A bobbing chevron floats high above the cell, out of the lamp wash and into open air, on a tether
		# back down to the exact rock so the eye tracks marker to target. Drawn twice, a thick dark stroke
		# under a chrome one, so it punches through both the bright lamp and the bright day sky; that is
		# what the filled wedge's dark backing polygon used to do and it is the property worth keeping.
		var lift: float = float(CELL) * (2.9 + 0.35 * pulse)
		# `lift` is where the mark hangs, and the chevron's point sits on it directly, with no second offset
		# for an apex: that was bookkeeping for building a triangle around a point rather than anything the
		# mark meant.
		var tip := center + Vector2(0.0, -lift)
		# The tether is ticked, not drawn. A solid line from a head down onto a cell is a stem, and a stem
		# is what makes an arrow: the mark would then be saying something pours into that rock, which is
		# the drop column's sentence. Ticks with gaps in them read as a leader line instead, and the tick
		# pattern is the one `_draw_dashed_rect` already uses on the build previews.
		_dotted_line(canvas, tip + Vector2(0.0, 3.0), center + Vector2(0.0, -float(CELL) * 0.5),
			Color(CHROME.r, CHROME.g, CHROME.b, 0.30 + 0.20 * pulse), 2.0)
		# The mark itself: an open chevron. It used to be a filled wedge, which is the shape a machine's
		# spout wears to mean goods leave here (`_matter_wedge`), and one shape cannot mean both.
		_chevron(canvas, tip, Color(0.02, 0.04, 0.06, 0.85), 5.0)
		_chevron(canvas, tip, Color(CHROME.r, CHROME.g, CHROME.b, 0.94), 2.6)


## The attention mark: an open chevron whose point sits at `point`, arms rising away from it by
## `GUIDE_CHEVRON`. One polyline rather than two lines so the arms meet in a joint instead of crossing at
## the point, which at a 5px backing stroke is the difference between a chevron and a blob.
##
## Drawn to a passed canvas because guidance lives on the marks layer, above the veil, and not on `self`.
func _chevron(canvas: CanvasItem, point: Vector2, col: Color, width: float) -> void:
	canvas.draw_polyline(PackedVector2Array([
		point + Vector2(-GUIDE_CHEVRON.x, -GUIDE_CHEVRON.y),
		point,
		point + Vector2(GUIDE_CHEVRON.x, -GUIDE_CHEVRON.y)]), col, width)


## A ticked leader line: `dash`-length ticks with an equal gap after each, from `a` to `b`. Same pattern
## and same default length as `_draw_dashed_rect`'s perimeter, so a broken line means the same thing
## everywhere in the file: a line that relates two things rather than one that carries something between
## them.
func _dotted_line(canvas: CanvasItem, a: Vector2, b: Vector2, col: Color, width: float,
		dash: float = 6.0) -> void:
	var span: float = a.distance_to(b)
	if span <= 0.0:
		return
	var dir: Vector2 = (b - a) / span
	var t: float = 0.0
	while t < span:
		canvas.draw_line(a + dir * t, a + dir * minf(t + dash, span), col, width)
		t += dash * 2.0


## The rect every cell mark is drawn on. One function so the square, the corners, the dash and the bar
## cannot come apart by a pixel as any one of them is retuned.
func _mark_rect(cell: Vector2i) -> Rect2:
	var span: float = float(CELL) - 2.0 * MARK_INSET
	return Rect2(Vector2(cell) * float(CELL) + Vector2(MARK_INSET, MARK_INSET), Vector2(span, span))


## The wash inside a mark: the same rect the outline sits on, pulled in clear of its stroke.
func _mark_wash(cell: Vector2i) -> Rect2:
	return _mark_rect(cell).grow(MARK_INSET - MARK_FILL)


## The cursor square: the cell you are pointing at, and nothing beyond that. Three sites used to cut their
## own version. Over rock it was the cell's full width; under a build ghost it was inset by a pixel and half
## a pixel heavier; over refused rock it was inset by a pixel. The cursor therefore changed size and weight
## as it crossed from stone into air. One mark in three colours now.
func _cell_square(cell: Vector2i, col: Color) -> void:
	draw_rect(_mark_rect(cell), col, false, MARK_W)


## corners: four L-brackets hugging `rect` with their arms turned inward. The hovered thing wears them
## solid and the painted dig plan wears them thin, which is the whole of the difference between the two
## sites that used to keep a corner loop each, at two arm lengths and two insets.
##
## Drawn to a passed canvas because the dig plan lives on the marks layer, above the veil, while the
## cursor's own go on `self`.
func _cell_corners(canvas: CanvasItem, rect: Rect2, col: Color, width: float) -> void:
	var arm: float = float(CELL) * MARK_ARM
	for corner: int in 4:
		var c := Vector2(rect.position.x if corner % 2 == 0 else rect.end.x,
			rect.position.y if corner < 2 else rect.end.y)
		var d := Vector2(1.0 if corner % 2 == 0 else -1.0, 1.0 if corner < 2 else -1.0)
		canvas.draw_line(c, c + Vector2(arm * d.x, 0.0), col, width)
		canvas.draw_line(c, c + Vector2(0.0, arm * d.y), col, width)


## A refusal: the cursor square in the refusal red with a bar struck across it. Both of the game's hard
## refusals come through here: rock over the carried drive's tier and a cell with no room for the machine
## in hand. They were the pair that differed in hue and in nothing else, and a refusal is exactly the
## answer that must not depend on telling two reds apart.
##
## One bar where there used to be a crossed pair. Two strokes were never saying more than one, and a cross
## is the mark a machine's lamp wears for a wire that leads nowhere. It starts half a corner arm in from
## the mark's corners, which is where the cross it replaces started and is far enough in that a cell could
## wear corners and a bar at once without them touching. `alpha` is whatever the calling site had already
## settled on, so only the shape and the hue move.
func _cell_refusal(cell: Vector2i, alpha: float) -> void:
	var no := Color(REFUSE.r, REFUSE.g, REFUSE.b, alpha)
	_cell_square(cell, no)
	var rect: Rect2 = _mark_rect(cell)
	var pull := Vector2.ONE * (float(CELL) * MARK_ARM * 0.5)
	draw_line(rect.position + pull, rect.end - pull, no, MARK_BAR_W)


## An interactable outline pulse: a breathing coloured outline plus solid corner brackets around the hovered
## thing, in the thing's own colour, so a drill pulses steel and an ore vein pulses ore. Drawn rather than
## shadered because machines and terrain here are procedural canvas paint, so there is no texture a shader
## outline could sample.
##
## this is the mark the active action keeps: an outline that grows around a cell means the next press lands
## there. Nothing else may grow one, which is why the objective marker gave up first its reticle and then
## its breathing outline (see `_draw_guide_targets`). The colour is not decoration either, it is the second
## half of the sentence, naming what is under the cursor without any text; that is the part a neutral
## reticle could not say and the reason this is the survivor.
func _draw_interact_pulse(rect: Rect2, col: Color) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_anim_time * 4.0)
	var r: Rect2 = rect.grow(2.0 + pulse * 2.5)
	draw_rect(r, Color(col.r, col.g, col.b, 0.28 + 0.42 * pulse), false, MARK_W)
	_cell_corners(self, r, Color(col.r, col.g, col.b, 0.95), MARK_W)


## The cursor cell, drawn by context from the affordances MainView pushed via set_aim:
##   solid earth -> the cursor square, faint out of reach; a vein adds ore-coloured corners
##   your machine -> corners in the machine's own colour
##   open cell -> a build ghost of the selected machine under the cursor square, barred when blocked.
func _draw_aim() -> void:
	if not sim.in_bounds(_aim):
		return
	if sim.is_solid(_aim):
		# Rock over the carried drive's tier: the cursor goes cold and barred before you press
		# (`docs/BITS.md` §5). A binary gate is only honest if you can see it coming; finding out by clicking
		# and watching nothing happen reads as a broken game rather than as a locked door.
		if _aim_in_reach and not _aim_bites:
			_cell_refusal(_aim, 0.60 + 0.16 * sin(_anim_time * 3.0))
			return
		# Chrome, not white: the cursor is on screen every frame of the game, and a permanent mark cannot hold
		# the brightest colour the screen has (see CHROME). Both alphas are the ones this box already used, so
		# the near/far reach step is unchanged.
		var col := Color(CHROME.r, CHROME.g, CHROME.b, 0.85) if _aim_in_reach else Color(CHROME.r, CHROME.g, CHROME.b, 0.18)
		_cell_square(_aim, col)
		if _aim_in_reach and sim.ore_deposit_at(_aim) > 0:   # a rich vein reads as a thing, not just rock
			_draw_interact_pulse(_mark_rect(_aim), _material(sim.material_at(_aim)).nugget_color)
		return
	if not _aim_in_reach:
		return
	var inner: Rect2 = _mark_rect(_aim)
	var m: MachineState = sim.machine_at(_aim)
	if m != null:
		_draw_interact_pulse(inner, Visuals.machine_color(m.def).lightened(0.25))
		return
	if _ghost_def != null:
		# A bright, fairly opaque tint so the ghost reads as a translucent preview on its own. Lifted toward
		# chrome rather than toward white, because a preview is a thing you are still deciding about and
		# white belongs to things that have already happened (see CHROME). The lift is what makes the ghost
		# read as translucent; where it lands is what stops it reading as urgent.
		var ghost: Color = Visuals.machine_color(_ghost_def).lerp(CHROME, 0.20)
		ghost.a = 0.55
		draw_rect(_mark_wash(_aim), ghost)
		Visuals.draw_machine_glyph(self, _cell_center(_aim), Visuals.machine_kind(_ghost_def), 1.0, false, 0.0)
		if _ghost_def.behavior == &"drill" and _aim_placeable:
			_draw_drill_preview()  # dashed ore column and out-arrow: what it bores, and where it pours
		if _ghost_def.behavior == &"rope" and _aim_placeable:
			_draw_rope_preview()   # ghost line down the shaft: how far the rope will unroll from here
		if _ghost_def.behavior == &"h_drill" and _aim_placeable:
			_draw_h_drill_preview()  # the gallery it will chew, and where the haul drains (or does not)
		if _ghost_def.behavior == &"drift" and _aim_placeable:
			_draw_drift_preview()    # the 2-high gallery and both drop columns, each lit for its own drain
	elif _ghost_material != &"":
		# Block-placement preview: a translucent material-tinted fill.
		var bg: Color = _material(_ghost_material).base_color
		bg.a = 0.55
		draw_rect(_mark_wash(_aim), bg)
	else:
		return  # the active hotbar item is not placeable, so there is nothing to ghost
	# The same cursor square as over rock, over a cell you may fill. Chrome rather than the near-white it
	# was, for the same reason the cursor moved: a preview is not an event. A cell you may not fill is
	# barred, where it used to be a second red square differing from the placeable one only in hue. The two
	# answers to "can this go here" are now two shapes, and the refusal is the same mark rock over your
	# tier wears, since it is the same sentence about a different obstacle.
	if _aim_placeable:
		_cell_square(_aim, Color(CHROME.r, CHROME.g, CHROME.b, 0.95))
	else:
		_cell_refusal(_aim, 0.95)


## Holding a Drill over a valid spot previews what it will bore: a dashed outline around the ore column it
## will drain, top to bottom of the vein straight below, plus a downward out-arrow under the bottommost ore
## marking where the ore pours. It warns in red-amber when the vein bottoms on rock with nowhere to drop.
## Pure overlay.
func _draw_drill_preview() -> void:
	var pv: Dictionary = sim.drill_preview(_aim)
	var ore_cells: Array = pv["ore_cells"]
	if ore_cells.is_empty():
		return                                            # not over any ore, so nothing to preview
	var blocked: bool = pv["blocked"]
	var flow := Color(1.0, 0.80, 0.30, 0.95)              # warm gold: the ore is there and it will flow
	var warn := Color(0.98, 0.45, 0.38, 0.95)             # red-amber: no drain below
	var tint: Color = warn if blocked else flow
	# Tint each cell the drill will bore by its own material, so a mixed column (ore stacked on coal) reads
	# as mixed: the drill bores straight down through both and pours a mixed stream, and that is visible
	# before committing rather than as one uniform gold.
	for oc: Variant in ore_cells:
		var mat_col: Color = _material(sim.material_at(oc)).nugget_color
		draw_rect(Rect2(Vector2(oc) * float(CELL), Vector2(CELL, CELL)), Color(mat_col.r, mat_col.g, mat_col.b, 0.22))
	# Dashed box hugging the whole ore column (topmost ore .. bottommost ore, one cell wide).
	var top: Vector2i = ore_cells[0]
	var bot: Vector2i = ore_cells[-1]
	var box := Rect2(Vector2(top) * float(CELL) + Vector2(1, 1),
		Vector2(CELL - 2, float((bot.y - top.y + 1) * CELL) - 2))
	_draw_dashed_rect(self, box, tint, 6.0, MARK_W)
	# The out-arrow, in the cell just below the bottommost ore, where the ore pours out.
	var drop: Vector2i = pv["drop_cell"]
	if sim.in_bounds(drop):
		_out_arrow(drop, tint)


## Holding the Borer previews its gallery: tint every solid cell it can chew along the builder's facing,
## since it bores the way the player is looking, plus a dashed box around the run and a down out-arrow under
## its own cell. Gold when a drain exists below, red-amber when it would sit sealed on rock and pool.
## Mirrors _draw_drill_preview's language sideways.
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
	_draw_dashed_rect(self, box, tint, 6.0, MARK_W)
	# The out-arrow under the borer's own cell: the on-hook rule made visible before you commit.
	_out_arrow(below, tint)


## Holding the Drift Rig previews the two things that make it a different machine from the Borer: the gallery
## is two cells high, and the haul leaves by two columns, pay straight down and spoil down the column behind.
## `docs/DRIFT.md` §6 names two drop columns as the geometry most likely to go wrong, so both arrows are
## drawn and each is lit for its own drain: gold where a column has somewhere to fall, red-amber where that
## stream would pool the moment it started.
func _draw_drift_preview() -> void:
	var facing: int = player.facing if player != null else 1
	var cells: Array[Vector2i] = []
	for k: int in range(1, FactorySim.DRIFT_RANGE + 1):
		var lo := Vector2i(_aim.x + facing * k, _aim.y)
		var hi := lo + Vector2i(0, -1)
		if not sim.in_bounds(lo) or not sim.in_bounds(hi) \
				or sim.machine_at(lo) != null or sim.machine_at(hi) != null:
			break
		var hard: bool = false
		for c: Vector2i in [lo, hi]:
			if sim.is_solid(c) and MiningRules.required_tier(sim.material_at(c)) > FactorySim.DRIFT_TIER:
				hard = true
		if hard:
			break
		if sim.is_solid(lo):
			cells.append(lo)
		if sim.is_solid(hi):
			cells.append(hi)
	for c: Vector2i in cells:
		# Tinted by class, not by material: this machine's promise is that it separates the two, so the
		# preview shows which half of that wall is ore and which half is rock.
		var pay: bool = sim.drift_is_pay(sim.material_at(c))
		var col: Color = Color(1.0, 0.82, 0.34, 0.26) if pay else Color(0.62, 0.66, 0.70, 0.18)
		draw_rect(Rect2(Vector2(c) * float(CELL), Vector2(CELL, CELL)), col)
	if not cells.is_empty():
		var xs: Array[int] = []
		for c: Vector2i in cells:
			xs.append(c.x)
		xs.sort()
		var box := Rect2(Vector2(float(xs[0] * CELL) + 1.0, float((_aim.y - 1) * CELL) + 1.0),
			Vector2(float((xs[-1] - xs[0] + 1) * CELL) - 2.0, float(CELL * 2) - 2.0))
		_draw_dashed_rect(self, box, Color(1.0, 0.80, 0.30, 0.85), 6.0, MARK_W)
	_drift_chute(_aim.x, "ORE")
	_drift_chute(_aim.x - facing, "SPOIL")


## One of the rig's two drop columns, drawn as an arrow under it and labelled, lit for its own drain.
func _drift_chute(col: int, label: String) -> void:
	var below := Vector2i(col, _aim.y + 1)
	if not sim.in_bounds(below):
		return
	var drained: bool = not sim.is_solid(below) or sim.machine_at(below) != null
	var tint := Color(1.0, 0.80, 0.30, 0.95) if drained else Color(0.98, 0.45, 0.38, 0.95)
	var tip: Vector2 = _out_arrow(below, tint)
	# The label hangs off the arrow's own tip rather than off a second copy of the arrow's length, so a
	# retuned arrow takes its caption with it.
	var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(_font, tip + Vector2(-w * 0.5, 12.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, tint)


## Holding Rope over a valid anchor previews the unroll: a translucent hemp line from the anchor down every
## open cell it will rope, capped by how many segments are carried, ending in a tick at the floor it
## reaches. Pure overlay.
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


## A drop-column arrow: goods leave the machine above and fall into `cell`. A stem down the middle of the
## column ending in `_matter_wedge`, which is the same head a machine's spout wears, because it is the same
## claim about the same goods one cell further along.
##
## One function for four call sites: the Drill's preview, the Borer's, and each of the Drift Rig's two
## columns. As three hand-rolled copies they had already drifted, the Drill naming its head size `6.0` in a
## local while the other two wrote the same `6.0` twice each as bare literals. Three copies of a shape are
## three chances for it to stop being one shape.
##
## Returns the tip, so a caller that hangs something off the end of the arrow does not need its own copy of
## how long the arrow is.
func _out_arrow(cell: Vector2i, tint: Color) -> Vector2:
	var cx: float = float(cell.x * CELL) + float(CELL) * 0.5
	var top_y: float = float(cell.y * CELL) + 3.0
	var tip := Vector2(cx, top_y + float(CELL) * 0.55)
	# The stem stops short by exactly the head's stand-off, so the mark still ends where the three
	# hand-rolled versions ended and the head is not a fourth thing bolted onto the end of the old length.
	draw_line(Vector2(cx, top_y), tip - Vector2(0.0, MachineView.WEDGE_JUT), tint, 2.5)
	_machines._matter_wedge(tip - Vector2(0.0, MachineView.WEDGE_JUT), Vector2(0, 1), tint)
	return tip


## A plan: the perimeter walked clockwise, laying `dash`-length ticks every other `dash`. Every site that
## says something will happen to these cells later draws one: what a Drill will bore, the gallery a Borer
## will chew, both of a Drift Rig's columns, and the cell guidance wants the next machine on.
##
## Drawn to a passed canvas, like `_dotted_line` and `_chevron`, because guidance's copy lives on the marks
## layer above the veil while the build previews go on `self`. One weight for all four, where two of them
## used to be half a pixel heavier than the others.
func _draw_dashed_rect(canvas: CanvasItem, rect: Rect2, color: Color, dash: float, width: float) -> void:
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
			canvas.draw_line(a + dir * t, a + dir * t2, color, width)
			t += dash * 2.0


## The parallax backdrop: what the sky is when nothing backs a cell. A vertical gradient breathing between
## day and night palettes on the day clock, a sun or moon riding its arc, stars fading in after dusk,
## ridgeline silhouettes sliding at sub-terrain speed, the Sinkforge crown, and a few slow clouds. Fully
## deterministic per frame from the camera and the cosmetic clock. Kept as a method so it stays the far
## backdrop layer's draw callback (see setup()'s _back.setup(..., _paint_backdrop)); the body lives in
## scenes/sky_painter.gd.
func _paint_backdrop(ci: CanvasItem) -> void:
	SkyPainter.paint(self, ci)


## The background wall layer (sim.wall): a dug-out cell reveals the carved-room backing behind it. Cells with
## no wall stay transparent, so the parallax backdrop at z -20 shows through, which is what makes open sky
## read as sky.
##
## The second plane is the depth cue that matters. A tunnel rendered as a flat rectangle at roughly four
## percent grey does not read as dark, it reads as empty, and no amount of work on the foreground plane fixes
## it. The wall used to be darkened twice, once in its own paint and again by the shadow veil, so the veil
## compounded a value that had already been crushed. Darkness belongs to the veil alone; the wall's paint
## describes the material, a rock face textured like the rock in front of it but flatter and cooler, so the
## two planes separate by hue as well as by value.
##
## The recess comes from solid rock casting onto the wall behind it. Every edge where this wall meets solid
## takes a soft inward shadow, deepest under a ceiling, because the world's key light comes from above. That
## cast is what turns a hole into a room, and it costs four neighbour lookups in a pass that only runs on a
## dig.
##
## Measured twice. A 13x7 chamber with two torches in it printed its back wall at luma 0.142 against 0.117
## for the surrounding rock, so carved space and mass were indistinguishable. Spending half the wall's value
## proving it was not the rock in front of it separated the planes and cost the room its back wall: a lit
## chamber whose middle was a black rectangle. The cause was upstream (see MASS_SHADE), where the veil gave
## buried rock and open space identical light, so no grading here could win. With the mass darkening itself
## the same chamber measures 0.182 against 0.052, a 3.5x separation instead of 1.2x, which buys the wall its
## value back.
##
## WALL_RECESS and WALL_COOL live on FineTerrain with `apply_wall_tone`, which is the single authority for
## what a wall colour is: the coarse pass and the fine pass have to agree, so only one may own it.
const WALL_AO_UNDER: float = 0.62    ## cast shadow on the wall under a solid ceiling; the deepest
const WALL_AO_SIDE: float = 0.34     ## ...beside a solid wall
const WALL_AO_ABOVE: float = 0.16    ## ...over a solid floor: light reaches a floor, so it stays open
## This pass is confined to the surface band, because everywhere else it is invisible: the fine layer paints
## a walled cell opaquely, either as rock or as the wall itself. The exception is that the mold deliberately
## leaves the top SURFACE_KEEP fine rows of each column's surface cell transparent so the grass cap can own
## the walked line, and a surface cell with a wall behind it shows through there. Same reasoning, and the
## same band, as the cell pass in `TerrainPainter.paint`.
func _draw_background(ci: CanvasItem, rect: Rect2i) -> void:
	var band: PackedInt32Array = PackedInt32Array()
	band.resize(rect.size.x)
	for i: int in rect.size.x:
		# Same bound as the mold's, and for the same reason: `surface_row` answers with the floor of a shaft
		# on a dug column, and this pass would then show the wall through the cap band at whatever depth the
		# player happened to stop digging.
		var top: int = sim.surface_row(rect.position.x + i)
		band[i] = FineTerrain.walked_surface(top)
	for cy: int in range(rect.position.y, rect.position.y + rect.size.y):
		for cx: int in range(rect.position.x, rect.position.x + rect.size.x):
			var top_here: int = band[cx - rect.position.x]
			# Tested for by name rather than left to the distance check. NO_SURFACE is -1, and `absi(0 - -1)`
			# is 1, which is not greater than 1, so row zero of a hole column would fall through and draw. It
			# is sky up there and `sim.wall` would reject it a line later, so the defect is invisible; a
			# sentinel that survives on a downstream accident is what this guards against.
			if top_here == FineTerrain.NO_SURFACE:
				continue
			if absi(cy - top_here) > 1:
				continue
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


## The grain, drawn only where it is being used.
##
## `Seams` gives every rock cell a bedding plane, a joint, a diagonal or nothing, and a blow that follows one
## calves the whole run, so the grain has to be readable before the swing or the mechanic is a slot machine.
## Drawing every plane in the world all the time answers that badly: `Seams.at` keys bedding to the row and
## joints to the column, so one plane spans the entire world; each cell lays its stroke on its own edge, so a
## run of them is a ruled line lying exactly on a cell boundary. At Seams.RATE_HORIZONTAL 0.18 and
## RATE_VERTICAL 0.12 that is 18% of rows and 12% of columns ruled on the grid in ink, which reads as graph
## paper: a renderer drawing its own storage layout.
##
## So the ambient pass does not exist and the cursor answers instead. Hovering a cell lights the plane
## through it and the run it would shear, which is more information than an ambient hairline carried, at the
## moment it is worth having, and it costs the rest of the screen nothing. The stroke itself is a shadow with
## a lit lip rather than a drawn line, and it wanders off the cell line, because a parting that ran straight
## down a boundary would put the grid back on screen for as long as the cursor sat there.
const SEAM_AIM_DARK := Color(0.02, 0.03, 0.05, 0.60)
const SEAM_AIM_LIP := Color(1.0, 0.96, 0.86, 0.32)
const SEAM_WANDER: float = 0.30                        ## how far off its nominal line a parting strays, in cells

func _draw_seams() -> void:
	var s: float = float(CELL)
	for key: Variant in _aim_run():
		var c: Vector2i = key
		_stroke_seam(c, Seams.at(c, sim.world_seed), s, SEAM_AIM_DARK, SEAM_AIM_LIP, 2.2)


## A smooth +/-1 wander along a plane, sampled per cell index so neighbouring cells share an endpoint exactly
## and the polyline is continuous. Two sines rather than a hash, because a hash steps at every cell and a
## plane has to bend rather than jump.
func _seam_wander(i: int, salt: float) -> float:
	return 0.62 * sin(float(i) * 0.73 + salt) + 0.38 * sin(float(i) * 0.31 + salt * 2.1)


## One cell's stretch of parting: the shadow on the plane, the lit lip just past it.
func _stroke_seam(c: Vector2i, seam: int, s: float, dark: Color, lip: Color, w: float) -> void:
	var a: Vector2
	var b: Vector2
	var perp: Vector2
	match seam:
		Seams.HORIZONTAL:
			var salt: float = float(c.y) * 1.37
			a = Vector2(float(c.x) * s, (float(c.y) + _seam_wander(c.x, salt) * SEAM_WANDER) * s)
			b = Vector2(float(c.x + 1) * s, (float(c.y) + _seam_wander(c.x + 1, salt) * SEAM_WANDER) * s)
			perp = Vector2(0.0, 2.4)
		Seams.VERTICAL:
			var salt_v: float = float(c.x) * 1.37
			a = Vector2((float(c.x) + _seam_wander(c.y, salt_v) * SEAM_WANDER) * s, float(c.y) * s)
			b = Vector2((float(c.x) + _seam_wander(c.y + 1, salt_v) * SEAM_WANDER) * s, float(c.y + 1) * s)
			perp = Vector2(2.4, 0.0)
		_:
			# The diagonal runs (1,-1), so it is parameterised by x alone: the cell up-right of this one
			# recomputes this cell's far endpoint as its own near one, and the line joins exactly.
			var salt_d: float = float(c.x + c.y) * 1.37
			var d0: float = _seam_wander(c.x, salt_d) * SEAM_WANDER * s
			var d1: float = _seam_wander(c.x + 1, salt_d) * SEAM_WANDER * s
			a = Vector2(float(c.x) * s + d0, float(c.y + 1) * s + d0)
			b = Vector2(float(c.x + 1) * s + d1, float(c.y) * s + d1)
			perp = Vector2(1.7, 1.7)
	draw_line(a, b, dark, w)
	draw_line(a + perp, b + perp, lip, maxf(w * 0.62, 1.0))


## The cells the aimed cell's plane runs through, within one blow's reach along it. Walked with
## `MainView._calve`'s own gates (contiguous, same seam, still solid) so what lights up is what would
## actually shear rather than a decoration that resembles it. The heading gate is deliberately not applied:
## this says which way the rock parts, which is what you need in order to choose a heading at all.
func _aim_run() -> Dictionary:
	var out: Dictionary = {}
	if not _aim_in_reach or not _aim_bites or not sim.solid.has(_aim):
		return out
	var seam: int = Seams.at(_aim, sim.world_seed)
	if seam == Seams.NONE or sim.is_foliage_material(sim.solid[_aim]):
		return out
	out[_aim] = true
	var axis: Vector2i = Seams.axis(seam)
	for side: int in [1, -1]:
		for step: int in range(1, Seams.RUN_CAP):
			var c: Vector2i = _aim + axis * (step * side)
			if not sim.solid.has(c) or Seams.at(c, sim.world_seed) != seam:
				break
			out[c] = true
	return out


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


## Rising shimmer in the open shaft above each lift: teal motes that ascend and fade, so the
## inverted-gravity column reads at a glance. Purely cosmetic, driven by _anim_time and never by the sim.
func _draw_updrafts() -> void:
	for machine: MachineState in sim.machines:
		if machine.def.behavior != &"lift":
			continue
		var c: Vector2i = machine.cell
		var top_row: int = 0  # scan up to the first solid or machine: the top of the open shaft
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


## Resting product piles on the floor (sim.ground): what a machine has spat out, waiting to be walked over
## and collected. Drawn as a stack, capped at four chips, so a bigger pile reads as more.
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


## A faint cool self-sheen so a flooded pocket reads as a dim blue presence in the near-black deep: the flood
## hazard has to be perceptible before you bring a lamp. Deliberately weak, well below a torch, crystal seam
## or lamp, so lit and shallow water looks essentially unchanged and it never reads as a light source or as
## lava. Painted on the additive light layer, like crystal seams, conduits and motes.
const WATER_SHEEN := Color(0.32, 0.66, 0.98)          ## cool blue tint for the wet-sheen pool
const WATER_SHEEN_BASE: float = 0.07                  ## floor intensity for a barely-wet cell
const WATER_SHEEN_LEVEL: float = 0.11                 ## added intensity at a brim-full cell (scales by level)
const WATER_SHEEN_RADIUS: float = 2.4                 ## cells; wide enough that neighbouring pools merge
const WATER_SHEEN_SPREAD: float = 0.42                ## ...and dimmer each, so the total stays a whisper




## Three rules keep a body of water from reading as a blue rectangle. Drawing every cell as one flat
## translucent quad with a bright 2px line along its top puts that line on interior cells too, so a pool
## three deep comes out as three glowing horizontal stripes stacked inside a uniform slab.
##
##   The surface is the surface. The waterline is drawn only where there is sky, rock or air directly above.
##     Everything below is interior and gets no edge at all.
##   Depth darkens. The further down inside the body a cell sits, the deeper and denser it draws. A gradient
##     is the cheapest cue that a volume has volume.
##   It moves. A still surface reads as a solid, so the waterline rides a small travelling sine and carries a
##     soft meniscus under it, and slow caustic bands drift through the body. All cosmetic, all off the
##     free-running clock, none of it near the sim.
##
## Deep water is deeply blue rather than dark. At (0.05, 0.16, 0.34) the body tended toward black as it
## deepened, which loses the cue that says water and not hole: measured against the rock it sits in, the
## colour separation fell to 10 levels, most of that in the top few cells. Dropping red and green further
## while holding blue up deepens it and reads more like water.
const WATER_DEEP := Color(0.03, 0.13, 0.46)           ## the colour the body tends toward with depth
















## MainView pokes this when a machine is genuinely placed, meaning try_build succeeded, so the assemble
## overlay plays once. Boot and load never call it, so pre-existing machines never animate.
func note_machine_built(cell: Vector2i) -> void:
	_construct[cell] = 0.0


## MainView pokes this when a block is genuinely mined, so the removed rock crumbles away. Carries the
## material colour, so dirt, stone and ore each shatter in their own hue. Capped at CRUMBLE_MAX: a rapid dig
## drops the oldest crumble rather than growing without bound.
func note_mined(cell: Vector2i, material: StringName) -> void:
	_crumble.append({"pos": Vector2(cell) * float(CELL), "col": material_color(material), "age": 0.0})
	if _crumble.size() > CRUMBLE_MAX:
		_crumble.pop_front()


## The mine-crumble overlay: each fresh dig shatters the cell into four chunks that fly apart on an outward
## plus gravity arc, shrink and fade over CRUMBLE_DUR, with a brief warm break-flash at the instant of
## impact. Sits at the terrain layer, under machines and items. Pure cosmetic: reads _crumble, not the sim.
func _draw_crumble() -> void:
	var half: float = float(CELL) * 0.5
	for cr: Dictionary in _crumble:
		var pos: Vector2 = cr["pos"]
		var col: Color = cr["col"]
		var t: float = clampf(float(cr["age"]) / CRUMBLE_DUR, 0.0, 1.0)
		if t < 0.28:                                     # the break flash: a quick warm burst inset from the
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


## The zoom at or above which per-machine text decorations (name label, held badge, need bubble) are legible
## enough to draw for every on-screen machine. MainView.ZOOM_LEVELS is [1.00, 0.70, 0.50, 0.33] and the
## default is 1.00, so this threshold sits between the 0.70 inspect level and the 0.50 and 0.33 levels below
## it. At those two, only the hovered or aimed machine shows its text and the rest stay clean glyphs, so a
## big base is not a wall of unreadable tiny labels. The zoom here is the canvas transform's scale, which
## equals the camera zoom.
const TEXT_ZOOM: float = 0.65

## The zoom at or above which a machine's fine casing detail (rivets, vent slots, the recessed faceplate) is
## resolvable enough to be worth drawing. Same reasoning as TEXT_ZOOM and a different threshold, because a
## rivet stops being a rivet before a label stops being a label: at 0.50x a 32px cell covers 16 screen
## pixels, and a 1.4px rivet in it is under a pixel of grey. What carries the machines when small is the
## shading and the silhouette, which the cheap tier draws unconditionally.
const DETAIL_ZOOM: float = 0.62

## The canvas scale for this frame, read once in `_draw` rather than once per machine.
## `get_canvas_transform` is a server round-trip and the machine loop called it twice per machine; a third
## call for the detail gate would land on the pass that already owns the frame budget.
var _zoom: float = 1.0
















































func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * float(CELL) + Vector2(CELL, CELL) * 0.5


## View culling: the on-screen world-space rectangle, grown by `margin_cells` so partially-on-screen content
## and its glow, labels or shadows that reach past its cell are not clipped at the edge. The per-frame draw
## passes test `if not view.has_point(Vector2(cell) * CELL): continue` before emitting any draw call for an
## element, so every pass reads the identical rect. Off-screen draws are not visible, so skipping them is
## pixel-identical on screen. `margin_cells` should be 2-3 or more for passes whose visual overspills its
## cell: machines have glow, badges and I/O ports, and a lamp-lit item glow reaches further still.
func _view_world_rect(margin_cells: float = 1.0) -> Rect2:
	return (get_canvas_transform().affine_inverse() * get_viewport_rect()).grow(float(CELL) * margin_cells)


# --- Lighting passes (painted by the LightLayer children; pure visuals) -------

## Draw the baked fine-terrain mold stretched over the world; the nearest filter keeps the 8px fine pixels
## crisp. Its one draw command replays for free, and content only changes when _bake_fine_terrain
## re-uploads.
## Hand the post-veil tooth the coarse grammar map, so its hash cell can run along the material's own
## grain instead of being square everywhere. Without this the tooth is isotropic white noise laid over
## every material at the largest amplitude any rock mark gets, and it flattens the grammar's direction to
## nothing -- see the header of rock_tooth.gdshader for the measurement that caught it.
##
## Cheap enough to call after every bake: `grammar_texture()` rebuilds only when a bake actually rewrote
## the map, and the uniform keeps the same ImageTexture across updates.
func _tooth_grammar() -> void:
	if _fine == null or _tooth == null:
		return
	var mat: ShaderMaterial = _tooth.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("gram_tex", _fine.grammar_texture())


func _paint_fine_terrain(layer: LightLayer) -> void:
	if _fine == null:
		return
	layer.draw_texture_rect(_fine.texture(), _fine.world_rect(), false)


## How much of a frame the off-screen fine fill may take: 4ms of the project's 8.33ms budget, which is
## generous because the alternative is 1199ms of not drawing anything at all. It is a target and not a cap,
## because `bake_pending` works in whole fine rows at ~1.8ms each, so a call can overshoot by one row.
##
## At this budget that is ~2 rows a frame against the world's 512 fine rows, all of it off-camera. The
## visible rect is already correct in the first bake, so nothing the player is looking at waits for this.
const FINE_FILL_BUDGET_US: int = 4000

## The opening view is the ground around the body, and deliberately not the camera rect.
##
## `setup()` runs from main's `_ready` before the renderer is added to the tree, so `get_canvas_transform`
## and `get_viewport_rect` fail there: first loudly, with two engine errors, then quietly, by returning an
## empty rect that `rebake` reads as "bake everything", which is the one bake this split exists to avoid.
##
## Guarding that with `is_inside_tree()` (camera rect inside, body rect outside) compiles and passes and is
## still the wrong shape, because it makes the opening view depend on which call site ran first, and the two
## sites disagree: `setup()` is outside the tree and `_process` is inside it. The same boot could then bake
## around the body or around wherever the canvas transform happened to point on frame one.
##
## The body's position needs no tree, no camera and no frame ordering, and the camera is on the body by
## construction. The span is about 1.6 screens wide by 2.2 tall at the 1.00x default zoom, which is 49152
## fine cells or 19% of the 512 x 512 fine grid, so the opening bake costs roughly 226ms of the measured
## 1199ms. Generous on purpose in both axes: overshooting wastes a few milliseconds once, undershooting
## shows coarse terrain where the player is looking, and undershooting self-heals within about a second.
const FINE_OPENING_SPAN := Vector2(2048.0, 1536.0)


## The world rect the opening bake must finish before the first frame.
func _fine_view() -> Rect2:
	var at: Vector2 = player.position if player != null else Vector2.ZERO
	return Rect2(at - FINE_OPENING_SPAN * 0.5, FINE_OPENING_SPAN)


func _bake_fine_terrain() -> void:
	_fine_dirty = false
	if _fine == null:
		return
	# The material's texture grammar, beside its colour. Set here rather than passed through `rebake`,
	# because the region path and several other callers use that signature too; see `grammar_at`.
	_fine.grammar_at = func(c: Vector2i) -> int: return _material(sim.material_at(c)).grammar
	_fine.rebake(
		func(c: Vector2i) -> bool: return sim.is_solid(c),
		func(fx: int, fy: int) -> bool: return sim.fine_is_solid(fx, fy),   # the sim's real fine grid
		func(c: Vector2i) -> Color: return _cell_base_color(c, _material(sim.material_at(c))),
		_wall_base_color,
		func(col: int) -> int: return sim.surface_row(col),
		_cell_tone,
		_has_wall,
		sim.fine_solid_bytes(),   # the same fine grid handed over whole; see rebake()'s bulk path
		_fine_view())   # paint what is on screen now, and owe the rest
	if _fine_layer != null:
		_fine_layer.queue_redraw()


## The per-dig fast lane: patch only the fine cells under the changed coarse region [cmin..cmax] instead of
## the whole grid. Same palette, wall and surface authorities as the full bake, so the patched region is
## byte-identical to a full rebake (check_dig_hitch).
func _bake_fine_region(cmin: Vector2i, cmax: Vector2i) -> void:
	if _fine == null:
		return
	_fine.grammar_at = func(c: Vector2i) -> int: return _material(sim.material_at(c)).grammar
	_fine.rebake_region(cmin, cmax,
		func(c: Vector2i) -> bool: return sim.is_solid(c),
		func(fx: int, fy: int) -> bool: return sim.fine_is_solid(fx, fy),
		func(c: Vector2i) -> Color: return _cell_base_color(c, _material(sim.material_at(c))),
		_wall_base_color,
		func(col: int) -> int: return sim.surface_row(col),
		_cell_tone,
		_has_wall)
	if _fine_layer != null:
		_fine_layer.queue_redraw()


## The back-wall colour behind a dug or eroded cell: the same zone-tinted wall fill the coarse background
## pass paints, so an eroded fine cell shows exactly the wall it would if hand-dug. Falls back to a dark
## dirt tone for a cell with no wall entry, which is unlikely on solid terrain.
##
## It carries the same bedding as the foreground rock, because it is the same ground seen a plane back: a
## tunnel cut through a sandy layer should show that layer behind it. Then it recedes, pushed down in value
## and drifted toward cool, which are the two moves distance makes. It does not darken itself for being
## underground; that is the veil's job, and doing it here as well counted the same shadow twice.
const WALL_NONE := Color(0.06, 0.055, 0.05)   ## a cell with no wall entry (unlikely on solid terrain)

## How far a vein carries its host rock toward the metal in it, and how much brighter a mineralised face is
## allowed to be than the plain rock beside it. The lift is deliberately almost nothing: a face reads as a
## face because of its colour and its grain, never because it is lit differently from the wall it is cut
## into.
const LODE_STAIN: float = 0.42
const LODE_STAIN_LIFT: float = 1.05
## ...and how far rock still covering a vein carries, plus how much it darkens.
##
## The buried tell gets a value channel and the open face does not, and the asymmetry is deliberate. Holding
## value is right at an open face: both a face and the rock beside it are things you look at, and a carved
## pocket brighter than its host reads as more rock rather than as a hole. Buried, every cell in question is
## solid, so there is no such confusion, and value is the only channel with reach left, because the darkness
## veil crushes saturation long before it crushes brightness. A hue-only stain at 0.14 was measurably applied
## and completely invisible on screen, in lamplight, on a forty-cell body.
##
## Mineralised rock reading darker is also the right direction: metal in stone is denser and duller than the
## stone, and a bruise in a lit wall is something the eye finds without being told to look.
##
## Both numbers are measured. `capture_moments -- stain` stages two ore bodies in a lit gallery and prints
## the stained-vs-plain luma; capturing again under SF_NO_LODE=1 gives the same frame without them, and the
## pair is diffed in matched boxes. That loop is the only honest way to set this, because run-to-run noise
## from animation phase alone reaches +/-8% and the first two attempts at this constant were read as
## invisible when they were merely below that floor. At 0.78 a buried body measures ~13% darker on screen
## against a ~2% noise floor: a patch of wrong-coloured rock you find when you look, not a map marker. The
## hue-only version at 0.14 measured -8% in the base colour and was genuinely invisible.
const LODE_STAIN_BURIED: float = 0.26
const LODE_STAIN_BURIED_DARK: float = 0.78

func _wall_fill_color(c: Vector2i) -> Color:
	if not sim.wall.has(c):
		return WALL_NONE
	return FineTerrain.apply_wall_tone(_wall_base_color(c), _wall_strata(c))


## The wall's colour before any bedding or recess. Split out for the fine bake, which reconstructs the
## bedding between coarse samples rather than inheriting one flat value per 32px cell. The coarse pass puts
## the two straight back together above, so its output is unchanged.
func _wall_base_color(c: Vector2i) -> Color:
	# A lode is wall (`docs/LODE.md`). Ore in the background plane paints as the background plane, so it
	# inherits the molding, the bedding, the recess shadow and the veil that every other wall gets, for free,
	# and cannot read as a decal stuck on top of the rock. Drawing the lode as its own translucent wash in
	# the dynamic pass looked like a poster in one version and like smoke in the next. Routing it through the
	# wall's own colour authority states the thesis literally: the vein is what the wall is made of here.
	if sim.lode.has(c):
		# Mineralised, not just ore-coloured. An ore block's matrix is within a hair of stone's, since ore
		# reads as ore because of its pale flecks rather than its rock, so painting the wall the ore's base
		# colour is literally correct and completely invisible. A real vein face is stained by what is in it,
		# so the wall here is the rock carried LODE_STAIN (0.42) of the way toward the metal. That derives per
		# material rather than being picked: coal stains the wall dark, iron rusty, ore pale.
		#
		# It stains in hue and not in value. Lerping the raw colour brightened the wall by 62%, because ore's
		# nugget is pale (v 0.85) against its matrix (v 0.34), so a carved adit came out lighter than the solid
		# rock around it and read as more rock rather than as a hole with a face at the back of it.
		# `docs/LODE.md` §11 names the rule that breaks: brightness carries attention, density carries
		# richness. So the mix sets what the wall is made of and the host rock keeps the say over how lit it
		# is; the metal earns its brightness one grain at a time, in `_draw_lode`.
		var vein: MaterialDef = _material(sim.lode[c])
		var host: Color = _material(sim.wall[c]).base_color if sim.wall.has(c) else vein.base_color
		return _zone_tinted(_stain(host, vein, LODE_STAIN), c.y)
	if not sim.wall.has(c):
		return WALL_NONE
	return _zone_tinted(_material(sim.wall[c]).base_color, c.y)


## The wall's bedding: the same beds as the foreground rock, only quieter, because it is the same ground
## seen a plane back and a tunnel cut through a sandy layer should show that layer behind it.
func _wall_strata(c: Vector2i) -> float:
	return _cell_tone(c).y * FineTerrain.WALL_STRATA_QUIET


func _has_wall(c: Vector2i) -> bool:
	return sim.wall.has(c) or sim.lode.has(c)   # a vein is always something to see, wall behind it or not


func _paint_darkness(layer: LightLayer) -> void:
	layer.draw_texture_rect(_veil_tex,
		Rect2(0.0, 0.0, float(FactorySim.GRID_COLS * CELL), float(FactorySim.GRID_ROWS * CELL)), false)


## Above running pace the body gets motion lines trailing along its own velocity. At 400 px/s the sprite
## crosses a 32px cell in five frames at 60fps, and without streaks the eye reads that as a teleport rather
## than as speed. The lines start where the body was and fade out behind it, so they show the path just
## taken.
##
## Gated to speed that had to be earned: a body at walking pace draws nothing, so the streaks are themselves
## a readout that the swing worked.
const STREAK_MIN: float = 1.15          ## multiple of Player.RUN_SPEED before any line is drawn
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
	# 0 at the threshold, 1 at the swing's terminal, so the lines grow in with the speed rather than popping
	# on at full strength the instant the threshold is crossed.
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


## How far a slack line hangs below its own chord.
##
## Tension has to be encoded in the cable's form rather than in added UI. Measured by `check_grapple_reads`
## with the body standing on the floor, so the pose is stable and the camera cannot move: at a flat 26px sag
## scaled only by slackness, a rope at 0.55 slack differed from the same rope pulled bar-taut by 10 levels
## of luma in its own corridor, and the side-by-side is two straight lines. 0.55 x 26px is a 14px bow across
## a 500px span, under 3%, which is a wobble rather than a hang.
##
## A rope's sag is a fact about its length, not a constant. For a chord `d`, the parabolic approximation
## gives extra length ~ (8/3)(h^2/d), so h = d * sqrt(3s / (8(1-s))) where `s` is the slack fraction the
## winch already computes. At 10% slack that is a fifth of the span; at half slack it is six tenths of it.
## Capped, because past a point the loop leaves the screen and stops being information, and floored at a
## couple of pixels so a nearly-taut line still reads as rope rather than as a drawn ray.
const SAG_CAP: float = 0.42             ## most of the chord the hang may ever be
const SAG_MIN: float = 2.0              ## px, so even a tight line keeps a whisker of curve


## The hang of a line, in pixels, from the chord it spans and how much line is spare.
static func rope_sag(span: float, slack: float) -> float:
	var s: float = clampf(slack, 0.0, 0.94)
	return clampf(span * sqrt(3.0 * s / (8.0 * (1.0 - s))), SAG_MIN, span * SAG_CAP)















## Bake the veil's base, which is the skylight/ambient model: daylight floods down each column's open air,
## attenuating past SURFACE_LINE, is blocked by the first solid rock, scatters SKY_FADE tiles under the
## exposed surface, and everything deeper sits in full ambient, with the night floor applied above ground.
## Runs only when terrain or the quantized daylight changes.
##
## Shadow multiplies. Carrying a shadow colour in RGB and a darkness in A and alpha-blending it over the
## world is what fog does, not what shadow does: at the deep's ambient opacity only about a third of a cell's
## own colour survived to the eye, and the other two thirds were a smooth blurred wash painted on top. Since
## the texture is one texel per cell stretched across the world, that wash was a soft cloud with no
## relationship to the rock underneath, and it averaged away the bedding, fissures, grain and carved edges.
##
## As a multiply, a texel is a light level: white leaves the world untouched, AMBIENT_LIGHT is the cool
## near-dark of the deep, and everything between is a dimmer. Multiplication is proportional, so relative
## contrast survives it exactly, so rock a fifth brighter than its neighbour stays a fifth brighter at any
## light level, and detail dims instead of dissolving. It also deletes work: an alpha-blend needs each
## texel's RGB to be that cell's own colour darkened, purely so the hue survives, whereas a multiply
## preserves hue for free. So there is no per-cell shadow-colour bake, no dirty flag for it and no per-dig
## patch pass, and a dig never touches this texture's colours.
##
## Mass occludes. A veil light level that is a pure function of row gives every cell at a given depth the
## same light, whether it is open air or the middle of a hundred tonnes of rock, so a 13x7 chamber cut into
## the deep printed at luma 0.148 against 0.127 for the surrounding stone: a 16% difference no eye reads as
## space, and every other depth cue in the renderer was fighting it.
##
## Light does not travel through stone. Openness is measured as a field, 1 in air and 0 in rock, and smoothed
## with a separable box blur, so light bleeds a couple of cells into the mass from any opening instead of
## stopping at a hard line. Solid cells are then dimmed by how buried they are: a rock face on the edge of a
## chamber keeps nearly all its light, and rock with nothing but rock around it loses MASS_SHADE of it. Open
## cells are never touched, since the veil's own row-based level already describes them, and the lamp cuts
## straight through all of it, so shining a light on buried rock reveals it as before.
##
## Cost: the field is floats in flat arrays rather than Dictionary probes, and the blur is separable, so the
## whole term is four linear passes over the world's 16,384 cells inside a bake that already ran on terrain
## change. check_dig_hitch holds.
## Why 0.55 and not 0.46. Deep buried mass sits at openness ~0 with `key` ~0, because it has rock above and
## below it so the vertical gradient is flat, which puts it at exactly `1 - MASS_SHADE` while an open cell
## sits at 1.0. The open-versus-buried contrast is therefore capped at `1/(1 - MASS_SHADE)` by construction,
## and the key cannot raise it, because the key brightens up-facing faces, which is a different cell from
## the one this ratio is about. At 0.46 that cap is 1.85x, and `check_room_reads` demands 2.0x: a floor above
## the model's structural maximum, unreachable by construction.
##
## It passed anyway because it sampled one cell, and that cell's material tone rode along with the lighting:
## a dark-toned stone read 39 where the lighting alone predicts 46, and 86/39 = 2.21x looked like headroom.
## Taking the median over the buried block, which is what the light actually does to the mass with the
## per-material tone lottery averaged out, reports 1.87x, and 86 x 0.54 = 46.4 confirms it is the model and
## not the measurement.
##
## 0.55 makes the cap 2.22x, which clears 2.0 with room for material spread instead of depending on it. That
## floor is the legibility requirement "solid rock must be reliably distinguishable from empty air", with a
## number attached.
const MASS_SHADE: float = 0.55       ## light a fully-buried cell loses against one at an opening
const MASS_REACH: int = 2            ## cells light bleeds into the mass (the blur radius)
const KEY_STRENGTH: float = 0.30     ## brightening of a fully up-facing mass (and dimming of an overhang)
const KEY_GAIN: float = 3.0          ## how fast the vertical openness gradient saturates the key
var _open_field: PackedFloat32Array = PackedFloat32Array()
var _open_blur: PackedFloat32Array = PackedFloat32Array()
## Raw solidity, kept separate and persistent. The vertical blur below writes its result back into
## `_open_field`, destroying the raw values it was built from. That is harmless when every column is rebuilt
## every time and fatal once a bake covers only a band, because the horizontal blur of a band column reads
## raw solidity from columns outside it, and those columns are unchanged and cached.
var _open_raw: PackedFloat32Array = PackedFloat32Array()


## `dug_from`..`dug_to` are the columns whose terrain changed. A dig changes light only near itself and only
## down its own columns (the surface line it may have moved, and the openness of its neighbours), so the
## whole 16,384-cell field never needs rebuilding for it. Rebuilding it all measured 13ms per dig, the
## second-largest piece of a mining hitch after the terrain bake itself.
##
## The daylight clock genuinely is global: every row's sky level moves at once. That path passes the whole
## world and pays the full cost, a few times a day rather than a few times a second.
func _bake_veil_base(dug_from: int = 0, dug_to: int = FactorySim.GRID_COLS - 1) -> void:
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	if _veil_base.size() != cols * rows * 4:
		_veil_base.resize(cols * rows * 4)
		dug_from = 0
		dug_to = cols - 1
	var band: Vector2i = _bake_openness(cols, rows, dug_from, dug_to)
	# Above its column's surface the light level depends on the row alone, so table it once per bake rather
	# than calling a function per cell, which is the bake's dominant cost over 16,384 cells.
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
	# The deep's own ambient, and the value the scatter band under the turf line lerps toward, so the soak
	# follows the deep it is fading into. The void floor below derives from it, so rock and void keep one
	# ratio between them.
	var amb: Color = _light_level(AMBIENT_DARK)
	var amb_r: int = int(amb.r * 255.0)
	var amb_g: int = int(amb.g * 255.0)
	var amb_b: int = int(amb.b * 255.0)
	# `SF_NO_VOID_FLOOR=1` disables VOID_FLOOR, so one build can measure both arms. check_rock_reads varies
	# 53-63% run to run on identical code, because the delve lands in a slightly different place each time,
	# so a single before-number against a single after-number cannot tell a real change from the spread. With
	# the switch the same build measures both arms, three runs each, and the comparison is between two
	# distributions rather than two anecdotes. A constant that can be turned off is a claim that can be
	# tested.
	var vf: float = 1.0 if OS.get_environment("SF_NO_VOID_FLOOR") == "1" else VOID_FLOOR
	var void_r: int = int(float(amb_r) * vf)
	var void_g: int = int(float(amb_g) * vf)
	var void_b: int = int(float(amb_b) * vf)
	for col: int in range(band.x, band.y + 1):
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
			elif _is_true_void(Vector2i(col, row)):
				# Unlit nothing is absence, and absence is the darkest thing down here. See VOID_FLOOR.
				#
				# The predicate needs `and not wall`, because a cell with nothing in it is two different
				# objects. A natural void was never filled and has no backing; a carved room is space someone
				# opened, and the wall behind it is a surface that survived the digging. Flooring both to
				# near-black made a chamber read 0.79x darker than the buried mass around it and turned
				# check_room_reads red, correctly, because that check's whole claim is that carved space
				# announces itself as carved.
				#
				# It is the distinction the renderer draws everywhere else: `_draw_background` paints walled
				# cells and only walled cells.
				r = void_r
				g = void_g
				b = void_b
			# Clamped, because the key term can push a strongly up-facing cell above its row's own light level
			# and a byte does not say so: it wraps, and a lit ledge prints as a dark one.
			var lit: float = _open_blur[row * cols + col]
			_veil_base[i] = mini(255, int(float(r) * lit))
			_veil_base[i + 1] = mini(255, int(float(g) * lit))
			_veil_base[i + 2] = mini(255, int(float(b) * lit))
			_veil_base[i + 3] = 255


## Build the per-cell "how much light can reach in here" multiplier used by _bake_veil_base. Four linear
## passes: solidity, a horizontal blur, a vertical blur, then the multiplier. The blur is what makes an
## opening bleed light into the rock around it rather than ending at a hard black line; without it the row
## under a flat surface drops straight to buried-dark and the ground reads as a painted band rather than as
## earth you are looking into the top of.
##
## `dug_from`..`dug_to` are the columns whose solidity changed. Everything downstream of them changes over a
## wider band, because the horizontal blur reaches MASS_REACH either side, so this widens the range itself
## and returns the band it actually refreshed, which is the band the caller must re-compose.
func _bake_openness(cols: int, rows: int, dug_from: int, dug_to: int) -> Vector2i:
	var n: int = cols * rows
	if _open_field.size() != n:
		_open_field.resize(n)
		_open_blur.resize(n)
		_open_raw.resize(n)
	var solid: Dictionary = sim.solid
	for row: int in range(rows):
		var base: int = row * cols
		for col: int in range(dug_from, dug_to + 1):
			_open_raw[base + col] = 0.0 if solid.has(Vector2i(col, row)) else 1.0
	var col_from: int = maxi(dug_from - MASS_REACH, 0)
	var col_to: int = mini(dug_to + MASS_REACH, cols - 1)
	var span: float = float(MASS_REACH * 2 + 1)
	for row: int in range(rows):                    # horizontal box blur, clamped at the world edges
		var base: int = row * cols
		for col: int in range(col_from, col_to + 1):
			var acc: float = 0.0
			for d: int in range(-MASS_REACH, MASS_REACH + 1):
				acc += _open_raw[base + clampi(col + d, 0, cols - 1)]
			_open_blur[base + col] = acc / span
	for col: int in range(col_from, col_to + 1):    # ...then vertical, into the working buffer
		for row: int in range(rows):
			var acc: float = 0.0
			for d: int in range(-MASS_REACH, MASS_REACH + 1):
				acc += _open_blur[clampi(row + d, 0, rows - 1) * cols + col]
			_open_field[row * cols + col] = acc / span
	# Open cells keep their full row-based light; solid ones are dimmed by how buried they are. The blurred
	# openness is already 0..1, and a cell touching air lands high enough in it that a rock face, which is
	# what you look at when you look at a wall, barely dims at all.
	#
	# Then the key. How buried a cell is says how much light reaches it and nothing about which way its mass
	# faces, so a floor and a ceiling at the same burial depth come out at the same brightness and a cavern
	# reads as a dark patch rather than as a space with a lit floor and a shadowed roof. The vertical
	# gradient of the openness field is that missing information: positive where the air is above (an
	# up-facing surface) and negative where the air is below (an overhang), and already smooth because the
	# field was blurred, so it shades as a gradient rather than banding. Light in a mine comes down, so
	# up-facing mass gains and down-facing mass loses.
	for row: int in range(rows):
		for col: int in range(col_from, col_to + 1):
			var i: int = row * cols + col
			if not solid.has(Vector2i(col, row)):
				_open_blur[i] = 1.0
				continue
			var above: float = _open_field[maxi(row - 1, 0) * cols + col]
			var below: float = _open_field[mini(row + 1, rows - 1) * cols + col]
			var key: float = clampf((above - below) * KEY_GAIN, -1.0, 1.0)
			_open_blur[i] = lerpf(1.0 - MASS_SHADE, 1.0, clampf(_open_field[i] * 2.2, 0.0, 1.0)) \
				* (1.0 + KEY_STRENGTH * key)
	return Vector2i(col_from, col_to)


## Is there genuinely nothing here? The predicate VOID_FLOOR needs, written here in the renderer's own terms
## rather than borrowed from another subsystem.
##
## `not is_solid` looks like "this cell is empty" and is not: it is collision's question, and it means "a
## body may pass through here". Three different things pass that test and only one of them is nothing.
##
##   a carved room has a wall behind it: space someone opened, with backing that survived the digging.
##     Flooring it makes a chamber read 0.79x darker than the mass it was cut from (check_room_reads).
##   a flooded cell has water in it: a surface with a colour and a depth ramp of its own. Flooring it puts
##     the floor of a pool 23.4 levels lighter than its surface, inverting the depth cue (check_water_reads).
##   a true void is the only one that is absence, and the only one that should go black.
##
## A predicate borrowed from another subsystem carries that subsystem's question.
func _is_true_void(c: Vector2i) -> bool:
	return not sim.is_solid(c) and not sim.wall.has(c) and not sim.water.has(c)


func _light_level(darkness: float) -> Color:
	return Color.WHITE.lerp(AMBIENT_LIGHT, clampf(darkness / AMBIENT_DARK, 0.0, 1.0))


## A source's own colour mapped to the colour its light reveals rock in. A lamp is amber but still bright,
## so a full-strength pool must reach near-white or it would darken the channels its tint is weakest in: a
## saturated teal lift would print a teal-and-black hole instead of lighting the rock. LIGHT_TINT is how
## much of the source's hue survives that lift, which is enough to read as amber or teal at a glance and
## never enough to strangle a channel. This is why a warm lamp and a cool crystal read as colour contrast in
## stone rather than as two coloured stickers.
const LIGHT_TINT: float = 0.28
const TORCH_LIGHT := Color(1.0, 0.72, 0.34)   ## a wall torch burns hotter and oranger than the head-lamp
const SEAM_LIGHT := Color(0.46, 0.86, 1.0)    ## exposed-ore seams answer in cold cyan

## Pool radii in cells for every veil source that gets view-culled. They are named here rather than written
## at the call site because the cull margin below must be at least the largest of them: a source outside the
## margin is skipped entirely, so any pool that reaches further than the margin is clipped where it crosses
## the screen edge, and the clip pops in and out as the camera scrolls.
const TORCH_GLOW_R: float = 7.6      ## the wide soft glow that makes a room habitable
const TORCH_CORE_R: float = 4.4      ## the hot core at the flame
const MACHINE_GLOW_R: float = 2.8
const CONDUIT_GLOW_R: float = 1.8
const MOTE_GLOW_R: float = 1.4
## Derived, never written by hand: widen any pool above and the margin follows it. A hand-set margin of 6.0
## against a 7.6-cell torch clipped the outer glow of every torch within 1.6 cells of the view edge.
##
## One veil source is missing from this max and cannot join it as things stand: the crystal seam pool.
## `_crystal_seams` sizes each seam `CELL * 2.2 + extent * 0.55` where `extent` is the cluster's diagonal
## span, so in cells the pool is `2.2 + 0.55 * span`, and nothing bounds it. A seam spanning ten cells
## already reaches 7.7 and clears the margin every other source is held under; twenty-five cells, which is
## what a drift gallery run along a vein produces, reaches 16. `CRYSTAL_MAX` caps how many seams glow and
## `CRYSTAL_MIN_CELLS` caps how small one may be; neither caps how large.
##
## It is worse than the torch case that prompted the derivation above, because `_exposed_ore_cells` culls
## its input cells at `_view_world_rect()`, a one-cell margin, so a seam is dropped entirely while its pool
## could still reach sixteen cells into frame. Since the cull drops cells rather than seams, a vein
## straddling the view edge also loses its outside cells, which shrinks `extent` and so shrinks the radius:
## the size of the glow is partly a fact about where the camera is.
##
## Not fixed here, because every repair for it moves pixels (capping the radius, widening the collection
## margin, or clustering in world space instead of view space) and that wants a look pass rather than a
## constant edited blind. Written down at the constant it violates so the rule and its one exception are
## read together.
const VEIL_CULL_MARGIN: float = maxf(maxf(TORCH_GLOW_R, MACHINE_GLOW_R),
	maxf(CONDUIT_GLOW_R, MOTE_GLOW_R))


func _light_tint(source: Color) -> Color:
	return Color.WHITE.lerp(source, LIGHT_TINT)


## Per frame: copy the baked base and let every live light cut its pool out of the darkness. The cuts are
## multiplicative, so each source scales the remaining veil and stacked lights deepen the opening without
## over-subtracting. Where light falls the world shows its true colours through the hole, and the additive
## pools then lay their warmth on top. Falling items cut too, so a gravity pour visibly opens the dark.
func _update_veil() -> void:
	if _veil_dirty:
		_veil_dirty = false
		_veil_cols_dirty = false
		_bake_veil_base()
	elif _veil_cols_dirty:
		_veil_cols_dirty = false
		_bake_veil_base(maxi(_veil_col_min, 0), mini(_veil_col_max, FactorySim.GRID_COLS - 1))
	# Persistent scratch: the working buffer is a member, refilled from the freshly-baked base each frame.
	# `.duplicate()` is a native memcpy, ~0.4us at this size, and is not the veil's cost; the real cost is the
	# per-source cutting below plus the texture upload. Cutting into the member directly means nothing leaks
	# a fresh local per frame. The base is re-copied whole each frame, so a light that scrolls off-screen and
	# back leaves no stale hole: only this frame's on-screen cuts appear over a fully-dark base.
	_veil_scratch = _veil_base.duplicate()
	var bytes: PackedByteArray = _veil_scratch   # alias for brevity; mutating it is the intended per-frame write
	# Off-screen cut cull: the veil texture covers the whole world but only the on-screen portion is ever
	# visible, so a light hole cut off-screen is invisible and skipping it is behaviour-preserving. Every
	# unbounded source (machines, torches, conduits, motes) is culled against a grown view rect so a source
	# just off-screen whose glow still reaches on-screen keeps cutting. The margin is the largest culled pool
	# radius, so no source is ever dropped while it can still reach the screen. The player lamp and the seams
	# are on-screen by nature and are not culled.
	var cull: Rect2 = _view_world_rect(VEIL_CULL_MARGIN)
	# Light cuts hard to reveal rock: the pools open a bright core that falls off tight, so lit rock pops out
	# of the gloom, and each cut carries its source's colour, so what the lamp uncovers is warm stone rather
	# than grey stone with an amber sticker over it.
	if player != null:
		var head: Vector2 = lamp_head()
		var lamp_lit: Color = _light_tint(lamp_color)
		# How much of the frame the lamp can show. The camera shows 40x22 cells at the 1.00x default zoom. A
		# 5.4-cell reveal lights roughly a tenth of that, which plays the underground through a keyhole:
		# whatever the terrain passes put into the world (rifts, ledges, spires, a colour arc across the
		# layers) is met one lamp-width at a time, with the other nine tenths of the frame black.
		#
		# "Bring your own light" survives the wider reveal: the pool still falls off hard, the deep outside it
		# is still genuinely dark, and torches and machines still buy territory that stays lit when you leave.
		# What changes is that the lamp shows the room you are standing in rather than the arm's length in
		# front of you. The throat and body pools widen with it so the beam keeps its shape.
		_veil_cut(bytes, head + _lamp_offset, 9.0, 0.99, lamp_lit)         # aimed beam: wide reveal, open core
		_veil_cut(bytes, head + _lamp_offset * 0.45, 5.0, 0.8, lamp_lit)   # the beam throat
		_veil_cut(bytes, player.position, 3.4, 0.5, lamp_lit)              # close body glow
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
			_veil_cut(bytes, mpos, MACHINE_GLOW_R, s, _light_tint(Visuals.machine_color(machine.def)))
	for cell: Variant in sim.torch:
		var tpos: Vector2 = _cell_center(cell as Vector2i)
		if cull.has_point(tpos):
			# Two cuts, the same shape as the head-lamp: a wide soft glow that makes the room habitable and a
			# hot core at the flame. One quadratic pool alone put a 2-cell bright disc on the wall and left the
			# rest of a hung chamber black, which is not what a torch in a room looks like.
			_veil_cut(bytes, tpos, TORCH_GLOW_R, 0.52, _light_tint(TORCH_LIGHT))
			_veil_cut(bytes, tpos, TORCH_CORE_R, 0.94, _light_tint(TORCH_LIGHT))
	for cell: Variant in sim.conduit:
		var cpos: Vector2 = _cell_center(cell as Vector2i)
		if not cull.has_point(cpos):
			continue
		var lvl: float = _conduit_level(cell as Vector2i)
		if lvl > 0.04:
			_veil_cut(bytes, cpos, CONDUIT_GLOW_R, lvl * 0.7)
	# Crystal/ore seam glow: a few cohesive seams of clustered exposed ore each cut one larger cool hole in
	# the gloom, so the vein's rock is revealed around it, and _paint_lights lays the saturated pool on top.
	# Seams are view-culled by their cells, at a one-cell margin, which is not the same as culling them by
	# their pool; see VEIL_CULL_MARGIN, where the arithmetic is.
	for seam: Dictionary in _crystal_seams_cached():
		var breath: float = 0.55 + 0.45 * sin(_anim_time * 1.4 + float(seam["pos"].x) * 0.02)
		_veil_cut(bytes, seam["pos"], float(seam["radius"]) / float(CELL), 0.62 + 0.26 * breath,
			_light_tint(SEAM_LIGHT))
	for m: Dictionary in falling.motes():
		var fpos: Vector2 = m["pos"]
		if cull.has_point(fpos):
			_veil_cut(bytes, fpos, MOTE_GLOW_R, 0.5)
	_veil_img.set_data(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, false, Image.FORMAT_RGBA8, bytes)
	_veil_tex.update(_veil_img)


## Open the veil in a radial falloff around a world position; `radius` is in cells. The falloff is textured:
## a cheap per-cell value nudge breaks the pool's outer half so the light reveals rock grain as it fades
## rather than ending in a clean gaussian blob. The core stays smooth, because the nudge scales up with
## distance, so the bright centre is unbroken.
##
## Light has a colour. `tint` is the colour of the source's light, and the cut lifts each channel toward
## `255 * tint` rather than toward flat white, so lamp-lit rock comes out amber and lift-lit rock comes out
## teal through the multiply, each carrying its own material hue underneath. This is the job the additive
## pass used to do by painting over the rock, which is why the additive pass could drop to a fraction of its
## old strength: revealing in colour beats repainting in colour.
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
			# Textured falloff: a stable RNG-free per-cell grain mottles the pool's outer region so its edge
			# reveals rock detail, and near the core (f approaching 1) the grain vanishes so the hot centre
			# stays clean. Two crossed-sine scales with a window that peaks mid-falloff and vanishes at both
			# the hot core and the dead fringe, so light dissolves into the rock grain as it fades.
			var window: float = (1.0 - f) * clampf(f * 2.2, 0.0, 1.0)
			var g: float = (sin(float(col) * 1.7 + float(row) * 2.3) * 0.62 \
				+ sin(float(col) * 4.1 - float(row) * 3.7) * 0.38) * 0.13 * window
			# A cut raises the light level toward the tint rather than lowering an opacity: the same pool and
			# the same falloff, expressed in the multiply model. Sources stack by each lifting whatever the
			# previous one left, so overlapping pools brighten toward full light and can never overshoot it.
			var lift: float = clampf(strength * f * f + g * strength, 0.0, 1.0)  # noisy soft-edged pool
			var idx: int = (row * cols + col) * 4
			for k: int in 3:
				var v: float = float(bytes[idx + k])
				if target[k] > v:                        # a light only ever adds light to a channel
					bytes[idx + k] = int(v + (target[k] - v) * lift)


## Darkness alpha for one cell, given its column's first-solid row. Open air above the rock is lit by sky,
## attenuating with absolute depth past SURFACE_LINE; the exposed surface and the SKY_FADE tiles below it get
## shallow scatter; everything deeper is full ambient. At night the sky itself dims, so everywhere sky-driven
## darkens toward NIGHT_DARK, which is moonlight rather than a cave. The deep ambient is already darker than
## NIGHT_DARK, so the underground never changes.
func _skylight_alpha(row: int, surf: int) -> float:
	var night_floor: float = NIGHT_DARK * (1.0 - daylight())
	var sky: float = maxf(AMBIENT_DARK * clampf(float(row - SURFACE_LINE) / float(SKY_REACH), 0.0, 1.0),
		night_floor)
	if row <= surf:
		return sky                                      # sky-lit open air / exposed ground
	var scatter: float = clampf(float(row - surf) / float(SKY_FADE), 0.0, 1.0)
	return lerpf(sky, AMBIENT_DARK, scatter)


## The heat-haze quads: every working furnace or generator gets a plume quad above its casing whose vertex
## alpha, which is the shader's strength mask, is full at the machine top and fades to nothing about 2 cells
## up. The shader displaces whatever the screen already shows there, so the plume warps terrain, walls, items
## and the machine's own smoke alike. Recipe-runners have behavior &"", so the hot check keys on the glyph
## kind instead, and only forge-style machines shimmer rather than every module.
func _paint_heat_haze(layer: LightLayer) -> void:
	for machine: MachineState in sim.machines:
		var kind: String = Visuals.machine_kind(machine.def)
		var hot: bool = kind == "furnace" or kind == "generator"
		if not hot or not _machines._machine_active(machine):
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


## The machine light pool's radius in cells, and the distance at which two of those pools are one light.
##
## Distinct from MACHINE_GLOW_R, which is the same lamp's hole in the darkness veil, and the two are free to
## differ because they compose differently: the veil cuts are multiplicative, so overlapping holes deepen an
## opening and can never over-subtract, while these pools are additive and overlapping ones sum.
##
## The link distance is derived from the radius rather than picked. Two pools whose centres sit closer than
## one radius overlap across their hot cores, which is exactly the sum that clips, so a pair that close is
## one light by definition.
const MACHINE_POOL_R: float = 2.6
const MACHINE_POOL_LINK: int = ceili(MACHINE_POOL_R)


## One cohesive pool per run of neighbouring same-coloured emitters, plus each machine's own hot core. This
## is also why a row of burners used to read as a slab.
##
## The light layer blends additive, so N overlapping pools sum to N times one pool's intensity and clip
## against the framebuffer. Three generators in a row printed a featureless orange block with their own
## fuel counters and status lamps drawn at z 0 underneath it and destroyed by it: 99.3% of the pixels
## across the three casings clipped at 255 in some channel, and every counter and lamp rect on all three
## was clipped edge to edge. A pool exists to say a machine is working, and it was erasing what the machine
## had to say.
##
## The ore seam pass below already answers this for clustered ore, and this is the same treatment. Flood
## the emitters into groups, lay one pool per group, and keep the per-machine pip, so a run of burners
## reads as three machines inside one light rather than as one wide lamp. The radius is derived: a single
## machine's radius plus half the group's diagonal extent, which is the size at which the outermost member
## still keeps a full single-machine radius of light around it. A lone machine is a group of one whose
## extent is zero, so its pool is arithmetically the identical draw call it always was. Photographed beside
## the run, the Drift Rig's casing clipped 15.36% to 15.50% over three runs of the unchanged build and
## 15.26% to 15.31% over three of four runs of this one, with the fourth at 16.30%.
##
## This fixes the stacking rather than the burner's own tuning, and knockout separates the two. Suppress
## the two neighbours' pools on that same capture and the surviving generator, now alone, still clips 96.4%
## of its own counter and 87.7% of its own status lamp: one pool of (1.0, 0.62, 0.20) at a pulse near 0.9
## lays some 211 levels of red over a casing already electric gold in a torch-lit gallery. It is the base
## that decides rather than the pool alone. check_machine_state stages one machine in a dark room whose
## empty mean luma is 17, and there the same generator's working frame clips 4%. So the outer machines of a
## run come back at 45.4% and 35.4% clipped against 98.8% before, while the one nearest the centroid, which
## by construction receives exactly one machine's worth of pool, stays where a lone burner always was.
##
## Grouped by pool colour rather than by machine kind, because the colour is what a merge would destroy:
## two modules with different casings paint different pools and have to stay apart, while two emitters
## painting the same hue on the same rock lose nothing by sharing one. No casing colour in MACHINE_STYLE
## coincides with the furnace, generator or lift pool literals, so this never merges across kinds. The idle
## gate joins that key for the same reason: an idled pool and a working pool are different lights even in
## one colour, and pooling them would publish a working machine's state over the stopped machine beside it,
## which is the exact read IDLE_GLOW exists to make.
func _paint_machine_pools(layer: LightLayer) -> void:
	if SILHOUETTE_ONLY:
		return          # a body's shape is not its glow; see SILHOUETTE_ONLY
	# Every machine that actually emits, resolved once: where it is, what colour it paints, how hard it is
	# painting this frame, whether the idle gate is what set that, and whether it burns hot enough for a core.
	var lit: Array[Dictionary] = []
	var at_cell: Dictionary = {}
	for machine: MachineState in sim.machines:
		var kind: String = Visuals.machine_kind(machine.def)
		# Each machine's pool blazes in its own colour out of the black: a hot orange forge, an amber burner,
		# a cyan-teal lift.
		var col: Color = Color(1.0, 0.46, 0.16)            # furnace ember (hot saturated orange)
		var pulse: float = 0.7 + 0.12 * sin(_anim_time * 3.0 + float(machine.cell.x))  # a sign of life
		# A cold or idle machine barely glows: it blazes only while it is doing its job, so light means
		# working. The gate applies to every machine, not just the furnace.
		#
		# Gating only `kind == "furnace"` left a stopped drill, hopper, splitter, crusher, borer, press, mill
		# and pump each lighting the rock around them exactly as brightly as a running one, so the hardware
		# was not merely silent about its state, it was asserting the wrong one. Measured with the name label,
		# held badge and status lamp suppressed (`check_machine_state`): a working Drill and a stopped Drill
		# differed by ~14 levels of luma against a ~7-level animation baseline, while the Forge, whose pool
		# was already gated, differed by 92. The gate is the entire difference; the casings, the glyphs and
		# the two machines' art were never the variable.
		#
		# The generator keeps its own harder gate below, where `fuel > 0` fails and the pool goes off
		# entirely rather than dimming: a burner with no coal is not idling, it is out.
		var idled: bool = false
		if not _machines._machine_active(machine):
			pulse *= IDLE_GLOW
			idled = true
		if kind == "generator":
			col = Color(1.0, 0.62, 0.20)                   # warm coal-burner glow
			# Breathes while fueled and goes dark when it runs dry: the "is it making power?" read. This
			# replaces pulse rather than scaling it, so the idle multiplier above never reached a burner at
			# all, and the flag has to follow the number rather than the test that set it.
			pulse = (0.85 + 0.22 * sin(_anim_time * 6.5)) if machine.fuel > 0 else 0.0
			idled = false
		elif kind == "lift":
			col = Color(0.36, 1.0, 0.90)                   # lift teal, echoing the updraft motes
			pulse = (0.55 + 0.5 * machine.power_factor) * (0.85 + 0.15 * sin(_anim_time * 3.0))
			idled = false                                  # replaced, exactly as the burner's is
		elif kind != "furnace":
			# Each machine's pool takes its own casing colour, so a drill, hopper and splitter read as distinct
			# devices in the dark instead of as a field of identical cyan blobs.
			col = Visuals.machine_color(machine.def)
		if pulse <= 0.0:
			continue        # out, not dim: it neither pools nor widens the pool of the run it sits in
		at_cell[machine.cell] = lit.size()
		lit.append({
			"cell": machine.cell, "col": col, "pulse": pulse, "idled": idled,
			# Only the genuinely burning machines, meaning a furnace or a fueled generator, blaze a core.
			"burning": kind == "furnace" or (kind == "generator" and machine.fuel > 0)})
	# The flood: pop an unclaimed emitter and absorb every same-light neighbour within MACHINE_POOL_LINK of
	# anything already in the group. One machine per cell, so the lookup is the cell dictionary rather than
	# the spatial hash the ore flood needs, and the neighbourhood is walked in a fixed order so a group and
	# its extent are the same every frame.
	var claimed: Dictionary = {}
	for start: int in lit.size():
		if claimed.has(start):
			continue
		claimed[start] = true
		var group: Array[int] = [start]
		var head: int = 0
		while head < group.size():
			var g: Dictionary = lit[group[head]]
			head += 1
			var gc: Vector2i = g["cell"]
			for dy: int in range(-MACHINE_POOL_LINK, MACHINE_POOL_LINK + 1):
				for dx: int in range(-MACHINE_POOL_LINK, MACHINE_POOL_LINK + 1):
					var probe: Vector2i = gc + Vector2i(dx, dy)
					if not at_cell.has(probe):
						continue
					var other: int = at_cell[probe]
					if claimed.has(other):
						continue
					var o: Dictionary = lit[other]
					if (o["col"] as Color) != (g["col"] as Color) or bool(o["idled"]) != bool(g["idled"]):
						continue
					claimed[other] = true
					group.append(other)
		var sum := Vector2.ZERO
		var lo := Vector2(lit[start]["cell"] as Vector2i)
		var hi: Vector2 = lo
		# The group's own brightest member sets the pool's intensity. Not the sum, which is the defect, and
		# not the mean, which would make a run of burners weaker than one burner: a run is lit like a single
		# machine stretched along its length rather than like N machines added together.
		var pulse_max: float = 0.0
		for gi: int in group:
			var e: Dictionary = lit[gi]
			var c := Vector2(e["cell"] as Vector2i)
			sum += c
			lo = lo.min(c)
			hi = hi.max(c)
			pulse_max = maxf(pulse_max, float(e["pulse"]))
		var centroid: Vector2 = (sum / float(group.size()) + Vector2(0.5, 0.5)) * float(CELL)
		var extent: float = (hi - lo).length() * float(CELL)        # diagonal span of the run
		_draw_glow(layer, centroid, float(CELL) * MACHINE_POOL_R + extent * 0.5,
			lit[start]["col"], pulse_max)
	# The cores last, one per burning machine, on top of whatever pool covers them. A fire's centre is
	# near-white rather than saturated, so the forge ember and the coal burner each get a small hot-white pip
	# and the pool reads like flame rather than as a flat coloured disc. These are what keep a run of three
	# from reading as one wide lamp, so they stay per-machine and at each machine's own pulse; the layer is
	# additive, where draw order carries no meaning, so lifting them out of the pool loop changes nothing but
	# the shape of this function.
	for e: Dictionary in lit:
		if not bool(e["burning"]):
			continue
		var p: float = float(e["pulse"])
		var core: Color = Color(1.0, 0.94, 0.82).lerp(e["col"] as Color, 0.18)  # near-white, a whisper of the pool's hue
		layer.draw_circle(_cell_center(e["cell"] as Vector2i), 2.4 + 1.1 * p, Color(core.r, core.g, core.b, 0.85 * p))


## The additive light pools that punch back through the veil: the miner's head-lamp, a glow per run of
## machines and a glow per falling drop.
func _paint_lights(layer: LightLayer) -> void:
	_paint_godrays(layer)  # under the pools: daylight shafts pouring down dug columns
	if draw_glints:        # exposed ore twinkles here, above the veil; see _draw_glint_flares
		_draw_glint_flares(_view_world_rect(), layer)
	# Sonar echoes glow through the darkness veil: an answer from inside unlit rock has to read in the black,
	# or the scanner is useless exactly where prospecting matters.
	if _scan_age >= 0.0:
		for e: Dictionary in _scan_echoes:
			var since_hit: float = _scan_age - float(e["dist"]) / SCAN_WAVE_SPEED
			if since_hit < 0.0 or since_hit > SCAN_ECHO_LINGER:
				continue
			var fade: float = 1.0 - since_hit / SCAN_ECHO_LINGER
			_draw_glow(layer, e["pos"], float(CELL) * 2.1,
				_material(e["material"] as StringName).nugget_color, 0.65 * fade)
	if player != null:
		# A faint flicker so the lamp reads as a live flame rather than a static disc.
		#
		# Light reveals, it does not paint. The lamp does two jobs: it cuts a wide hole in the darkness veil
		# (see _update_veil, 9 cells at 0.99 strength, which is what actually makes rock visible) and it adds
		# an amber pool on top. An additive term strong enough to swamp the reveal repaints the rock the veil
		# just uncovered: three overlapping pools summed past 1.0, tripped the glow threshold and blew the
		# centre of the frame to a white smear.
		#
		# Because the veil cut carries the lamp's amber, this pass is pure bloom, the halo around a real lamp,
		# rather than the thing that makes rock warm. At 0.32 it was still adding ~85/255 over the reveal and
		# washing the pool's centre to a structureless cream; at 0.17 the carved rock inside the pool survives
		# and the lamp still plainly reads as a lamp.
		var flick: float = 0.17 + 0.030 * sin(_anim_time * 11.0) + 0.020 * sin(_anim_time * 27.0)
		# Scale the lamp by how dark the miner's spot actually is: a full blaze in the deep where it is the
		# light, and a dim glow in daylight. At spawn the full-strength lamp washed out both the avatar and
		# the starter ore it sits on, so every warm thing read as a lamp.
		var pcell := Vector2i(int(floor(player.position.x / float(CELL))), int(floor(player.position.y / float(CELL))))
		var pdark: float = _skylight_alpha(pcell.y, sim.surface_row(pcell.x))
		var lamp_scale: float = lerpf(0.30, 1.0, clampf(pdark / AMBIENT_DARK, 0.0, 1.0))
		flick *= lamp_scale
		# The aim-following beam: a bright cast pool where the cursor is, plus a dimmer throat pool between it
		# and the head. Two glows along one line read as a directed beam, with no shader needed. The throat and
		# body pools are held well below the main one so the overlapping centres do not sum past 1 and go
		# white.
		var head: Vector2 = lamp_head()
		_draw_glow(layer, head + _lamp_offset, LAMP_RADIUS, lamp_color, flick)
		_draw_glow(layer, head + _lamp_offset * 0.45, LAMP_RADIUS * 0.62, lamp_color, flick * 0.38)
		_draw_glow(layer, player.position, float(CELL) * 1.5, lamp_color, 0.06 * lamp_scale)  # close body glow
	_paint_machine_pools(layer)
	# Torches: the placeable light. Each mounted torch casts a warm guttering pool, smaller than the
	# head-lamp but permanent, so torches dropped along a dig mark the route home.
	for cell: Variant in sim.torch:
		var tc: Vector2i = cell
		var gutter: float = 0.68 + 0.08 * sin(_anim_time * 9.0 + float(tc.x) * 1.7) \
			+ 0.05 * sin(_anim_time * 23.0 + float(tc.y))
		var tpool: Vector2 = _cell_center(tc) + Vector2(1.2, -6.0)
		_draw_glow(layer, tpool, float(CELL) * 3.0, Color(1.0, 0.60, 0.24), gutter)
		# White-hot flame core: the guttering torch flame has a bright near-white centre.
		layer.draw_circle(tpool, 1.6 + 0.8 * gutter, Color(1.0, 0.93, 0.78, 0.8 * gutter))
	# Powered conduits emit light, so a live trunk pours a column of warm glow down the dark shaft. The
	# in-world tube is drawn under the veil, so this is what makes its power read from across the room.
	for cell: Variant in sim.conduit:
		var lvl: float = _conduit_level(cell)
		if lvl > 0.04:
			_draw_glow(layer, _cell_center(cell), float(CELL) * (0.9 + 0.7 * lvl), Color(1.0, 0.78, 0.36), lvl * 0.7)
	# Ore seam glow: one cohesive glow per clustered exposed vein, sized to the seam's extent, plus a hot core
	# pip on each exposed cell, so the seam reads as discrete nuggets inside one glow. The glow takes the
	# seam's own material colour, `nugget_color` pushed toward saturation, rather than a hardcoded cyan, so ore
	# glows warm orange, rich_ore gold and iron cold steel, and the light agrees with the flecks in the rock.
	# On a mixed seam the first cell's material governs.
	#
	# The accent is deliberately tight and dim. A wide soft radial halo of any colour impersonates a light
	# source, and first-time players read it as a lamp or a lava blob rather than as rock. Ore reads by its
	# tinted cell body and chunky nuggets, drawn under the veil; what is left here is a tight dim accent plus
	# bright nugget pips, so an exposed vein shimmers in the dark without pretending to be a lamp.
	for seam: Dictionary in _crystal_seams_cached():
		var breath: float = 0.55 + 0.45 * sin(_anim_time * 1.4 + float(seam["pos"].x) * 0.02)
		var seam_glow: Color = _seam_glow_color(seam["cells"])
		# Gate the discovery glow by how dark the vein sits, as the lamp is gated: a vein in daylight reads as
		# pure rock, since a glow of any strength there impersonates a lamp, while a vein in the deep dark
		# still shimmers and stays findable across a cavern.
		var sc := Vector2i(int(seam["pos"].x / float(CELL)), int(seam["pos"].y / float(CELL)))
		var seam_dark: float = clampf(_skylight_alpha(sc.y, sim.surface_row(sc.x)) / AMBIENT_DARK, 0.0, 1.0)
		if seam_dark <= 0.02:
			continue
		_draw_glow(layer, seam["pos"], float(seam["radius"]) * 0.42, seam_glow, (0.11 + 0.07 * breath) * seam_dark)
		var core_pip: Color = seam_glow.lightened(0.5)
		for c: Vector2i in seam["cells"]:
			var cb: float = 0.55 + 0.45 * sin(_anim_time * 1.4 + float(c.x) * 0.6 + float(c.y) * 0.4)
			layer.draw_circle(_cell_center(c), 1.4 + 0.6 * cb, Color(core_pip.r, core_pip.g, core_pip.b, (0.55 + 0.30 * cb) * seam_dark))
	# The same cull the item bodies get in FallingItems.draw. A glow is one textured quad, but
	# FallingItems.MAX_ITEMS is 240 and the radius is a single cell, so a mote more than two cells outside the
	# view cannot put a pixel on screen, and without this the whole pour of a factory running somewhere else
	# is painted into the light layer every frame.
	var mote_view: Rect2 = _view_world_rect(2.0)
	for m: Dictionary in falling.motes():
		# Dropped and falling items glow, but a dropped stack overlaps many motes into one blown-out disc, so
		# each mote is dimmer and tighter and a stream reads warm without clipping.
		if not mote_view.has_point(m["pos"]):
			continue
		_draw_glow(layer, m["pos"], float(CELL) * 1.0, m["color"], 0.38)
	# Water self-sheen: a faint cool bloom so a flooded pocket reads as a dim blue presence in the near-black
	# deep and the flood hazard is perceptible before a lamp reaches it. Deliberately weak, WATER_SHEEN_BASE
	# plus a level-scaled term, well under a torch, crystal seam or lamp, so lit and shallow water looks
	# essentially unchanged and it never reads as a light source or as lava. View-culled like the passes above.
	#
	# Drawn on the body's skin rather than cell by cell. A glow of radius 1.15 cells at every cell centre puts
	# one disc per cell in a square grid, and adjacent discs touch without merging, so a wide aquifer comes out
	# as visible polka dots. Only the cells at the top or the sides of the body glow, over a radius wide enough
	# that neighbours blend, which is cheaper on a deep pool and closer to what dim water does: the light
	# leaves at the surface, not out of the middle.
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
			var skin: bool = sim.water_at(wc - Vector2i(0, 1)) <= 0 \
					or sim.water_at(wc + Vector2i(-1, 0)) <= 0 \
					or sim.water_at(wc + Vector2i(1, 0)) <= 0
			if not skin:
				continue
			var wfrac: float = clampf(float(wlevel) / float(FactorySim.WATER_MAX), 0.0, 1.0)
			var wintensity: float = (WATER_SHEEN_BASE + WATER_SHEEN_LEVEL * wfrac) * WATER_SHEEN_SPREAD
			# A faint slow shimmer, tiny in amplitude, so the pool reads as live water and not as a disc.
			var wshim: float = 0.9 + 0.1 * sin(_anim_time * 1.8 + float(wc.x) * 0.6 + float(wc.y) * 0.4)
			_draw_glow(layer, _cell_center(wc), float(CELL) * WATER_SHEEN_RADIUS, WATER_SHEEN,
				wintensity * wshim)


## Godrays: where a dug shaft admits the sky below the enclosing ground, a soft daylight beam pours down it,
## fading exactly where the skylight veil fades over SKY_REACH, with a slow shimmer. A column qualifies when
## its sky-lit air drops 2 or more rows below an adjacent surface edge, which covers dug shafts and carved
## notches while leaving 1-row slope steps clean. Per-vertex alpha polygons on the additive layer; reads only
## sim.surface_row. Pure cosmetics.
func _paint_godrays(layer: LightLayer) -> void:
	var cell_f: float = float(CELL)
	const RAY := Color(1.0, 0.95, 0.76)
	var dl: float = daylight()                              # no sun, no shafts: rays die at night
	if dl <= 0.03:
		return
	for col: int in range(FactorySim.GRID_COLS):
		var surf: int = sim.surface_row(col)
		# The beam mouth is the shallower neighbouring surface, because light pours past that edge. min and
		# not max, so a 2-wide shaft still beams: its partner column is deep, and the outer rim is the edge.
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
		# Two nested beams: a wide faint wash and a narrow bright core, each fading top to bottom.
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
		# A soft landing pool where the beam meets the floor while still lit.
		if end_row == surf and floor_light > 0.06:
			_draw_glow(layer, Vector2(x + cell_f * 0.5, float(surf) * cell_f),
				cell_f * 1.6, RAY, 0.18 * floor_light * shimmer * dl)


## One soft radial light pool (the shared glow texture, tinted + faded), added over the darkness.
func _draw_glow(layer: LightLayer, center: Vector2, radius: float, color: Color, intensity: float) -> void:
	var tint := Color(color.r, color.g, color.b, intensity)
	layer.draw_texture_rect(_glow_tex, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
		false, tint)


## A 128x128 radial gradient, bright centre to transparent edge, reused for every light pool.
func _make_glow_texture() -> GradientTexture2D:
	var g := Gradient.new()
	# A bright core with a tight falloff, so light blazes out of the near-black base. The mid stop sits in at
	# 0.42 and low, so the pool has a hot centre and a fast fade rather than a wide soft wash. Cores keep their
	# warm tint rather than clipping to pure white.
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
