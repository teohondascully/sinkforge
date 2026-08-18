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
##
## ...except seven was not the topsoil band, it was a seventh of the frame, and the opening shot proved it:
## the bottom FORTY-FIVE PERCENT of the first screen a player ever sees printed as one smooth brown
## gradient with four or five levels in it and no visible rock at all. That is not "mysterious", it is
## dead space, and it is the single largest region of the composition.
##
## The cause is 8-bit, not artistic. The veil MULTIPLIES, which preserves relative contrast perfectly —
## but at a multiplier of 0.18 the whole rock has thirty-five levels to live in and its own texture spans
## about two of them, so a paint that measurably reads as rock at full light quantizes into a stain. There
## is no amount of terrain work that survives being multiplied into two levels.
##
## Sixteen tiles is the honest depth: daylight soaks into SOIL, not into rock. The band under the grass is
## meant to be the INVITATION to dig — you can see the dirt, you can see stones in it, you can see where it
## stops — and the dark begins at rock depth, where the player has genuinely descended. The deep is not
## touched by this at all; it is exactly as black as it was.
const SKY_FADE: int = 16
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
## HOW MUCH OF THE DEEP AMBIENT AN UNLIT *EMPTY* CELL KEEPS. Applies below the scatter band only, so the
## surface and the daylight soak are untouched.
##
## THE FINDING THIS FIXES, and it is not the one the audit predicted. `check_rock_reads` sampled 140 solid
## cells against 55 air cells outside every light source and asked how often you would be right telling them
## apart from pixels: 56%, against a coin flip of 50%. That is the blind tester's *"I cannot reliably tell
## solid rock from empty air"* stated as a number. But the medians say something sharper than "no contrast":
## unlit air read 12.0 and unlit rock read 9.4, so THE VOID WAS BRIGHTER THAN THE ROCK. Not a missing cue —
## an INVERTED one. A first-timer who learned to read that frame would have learned that brighter means
## emptier, which is backwards in every other game they have ever played and backwards against the lamp,
## where bright plainly means solid-and-lit.
##
## The mechanism was `_open_blur`, and it was not a bug. That term means "how much light can reach in here",
## which is exactly right near the surface, where openness IS how skylight arrives. Carried into the deep it
## keeps paying out light that has no source: an air pocket forty rows down is maximally open, so it took
## the full ambient, while the rock beside it took the openness of rock. Correct arithmetic, wrong premise —
## down here there is nothing overhead to be open TO.
##
## Why a floor on the VOID rather than a lift on the rock: the audit is explicit that raising global
## brightness is how this was got wrong before (an earlier blue fog did exactly that and had to be pulled),
## and the prescription is to SHAPE the darkness — keep unlit rock grainy while unlit air goes black. Rock's
## ambient is therefore untouched at AMBIENT_LIGHT, every value and every grain it had it still has, and the
## whole change is subtractive on cells that hold nothing. "Bring your own light" gets stronger, not weaker:
## the space you have carved is now the darkest thing in frame until you light it.
const VOID_FLOOR: float = 0.35
## `SF_MACHINE_BARE=1` strips a machine of everything that is UI ABOUT the machine — its name label, its
## held-count badge, its status lamp and its need bubble — leaving only the object. **It exists to make
## `PC-05`'s guard executable**: *"causality survives labels hidden and grayscale."* A guard phrased as a
## condition needs some way to establish that condition, and the alternative — reasoning about what the
## frame would look like without the labels — is exactly the kind of claim that is never wrong until it is.
##
## **IT MAKES THE ASSERTION HARDER, NEVER EASIER, AND THAT IS THE WHOLE TEST FOR WHETHER A SWITCH LIKE
## THIS BELONGS IN SHIPPED CODE.** A flag that restores a weaker measurement is a documented way to buy
## green; a flag that removes the crutches the measurement is not allowed to lean on is the measurement.
## Read once at load: a renderer that consults the environment per frame is a renderer whose output
## depends on when you asked.
static var BARE_MACHINES: bool = OS.get_environment("SF_MACHINE_BARE") == "1"
## SILHOUETTE ONLY — the casing and nothing else: no glyph, no light pool, no label. `PC-01` asks whether
## the machine's BODY carries its identity, and every other channel is a way of answering a different
## question. The glyph especially: it is a decal on the front, it is the thing a toolbar uses, and leaving
## it in would let `check_machine_identity` pass on twenty identical boxes wearing twenty different icons —
## which is the exact state the ticket was filed about. Suppressing it makes the assertion HARDER, which is
## the only kind of test switch that belongs in shipped code.
static var SILHOUETTE_ONLY: bool = OS.get_environment("SF_MACHINE_SILHOUETTE") == "1"
## ...AND ONE COLOUR FOR ALL OF THEM, which is the half that took two attempts to get right. The first
## version left every machine its registry hue and masked "material" as "far enough from bare rock", and
## that mask could not register its subject: the Descent Engine's shadowed foot lands within 3 levels of
## the rock behind it, so a DARK machine measured as a SMALLER machine. Twenty bodies scored a mean pair
## difference of 0.201 and the layer read that as twenty distinguishable shapes, when what it had measured
## was twenty different paint jobs on one rectangle. Painted identically, any difference left in the patch
## is geometry and nothing else.
const SILHOUETTE_GREY := Color(0.75, 0.75, 0.77)

## What is left of a machine's light pool once it stops working. Not zero: an installed machine in a dark
## gallery still has to be findable, and a base that vanishes when it idles is a base you cannot navigate.
## This is the value the furnace has used since its own gate was written; the change is that every other
## machine now gets it too — see `_paint_lights`.
const IDLE_GLOW: float = 0.12

const LAMP_COLOR := Color(1.0, 0.82, 0.50)          ## the miner's warm head-lamp — a SATURATED amber core
                                                   ## (was pale 1.0/.90/.66) so the pool reads warm-gold, not
                                                   ## a white wash (diff 11)
const LAMP_RADIUS: float = CELL * 5.6               ## the ADDITIVE bloom halo — tracks the reveal radius
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
## Will the carried DRIVE bite the aimed rock at all? False = the wall is over your tier, and the
## cursor has to say so BEFORE the swing (docs/BITS.md §5) rather than after a click that did nothing.
var _aim_bites: bool = true
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
## THE INCREMENTAL BAKE (#S14). The viewport is the WHOLE WORLD — 4096x4096 — and every chunk painter lives
## inside it, so nothing is ever culled: re-rendering it replayed every chunk over sixteen megapixels and
## cost ~100ms, once per dig. Measured, that was two thirds of a 114ms mining hitch (tools/check_frametime).
## Now the target is RETAINED and a dig re-renders only the chunks that changed: the rest keep the pixels
## they already had. `_eraser` blanks those chunks' rects first, because blending cannot remove coverage.
var _eraser: LightLayer                               ## z -11 inside the viewport: clears a dirty chunk's rect
var _erase_rects: Array[Rect2] = []                   ## world rects to blank on the next viewport render
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
var _veil_dirty: bool = true                     ## a FULL veil rebake (daylight moved / world loaded)
## #S14: a dig dirties only the columns it touched. Tracked separately from _veil_dirty so the cheap case
## stays cheap and the global case (the daylight clock) still gets the whole world.
var _veil_cols_dirty: bool = false
var _veil_col_min: int = 0
var _veil_col_max: int = 0
## Crystal seams (#4): the O(exposed-ore^2) flood is cached across frames and shared by _update_veil +
## _paint_lights (which both need the identical seam list). It only changes when ore EXPOSURE changes
## (terrain dug/placed near ore) or when the culling view-rect moves (a seam pans on/off screen), so it
## is recomputed on either signal and otherwise replayed. Invalidated in the terrain-dirty block below.
var _crystal_seams_cache: Array[Dictionary] = []
var _crystal_seams_valid: bool = false
var _crystal_seams_view: Rect2 = Rect2()
var _lights: LightLayer
var _tooth: LightLayer                                 ## post-veil rock tooth (rock_tooth.gdshader)
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
	# ITS OWN WORLD, SO THE COLOUR GRADE CANNOT REACH IT. The WorldEnvironment's adjustment pass runs as a
	# viewport post-process, and this viewport RETAINS its render target between updates (CLEAR_MODE_NEVER on
	# the partial-bake path -- that retention is what makes a dig cost one chunk instead of the whole world).
	# Inheriting the grade meant saturation 1.18 was re-applied to the same stored pixels on every bake, so
	# the terrain compounded 1.18^n: grass measured (87,130,47) at boot and (42,255,0) after a play arc, and
	# the walked surface line -- the one strip the fine layer does not cover -- read as a neon red-and-green
	# band across the whole frame. Measured: 24 colour-change events during one arc before this, 0 after.
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
	# The eraser sits BELOW the chunk painters inside the same viewport, so on a partial re-render each
	# dirty chunk's rect is blanked before that chunk repaints into it.
	_eraser = LightLayer.new()
	_eraser.setup(-11, _paint_erase)
	var erase_mat := ShaderMaterial.new()
	erase_mat.shader = load("res://scenes/erase.gdshader")
	_eraser.material = erase_mat
	_terrain_viewport.add_child(_eraser)
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
	# ...and the tooth INSIDE those 8px pixels, which the baked texture cannot hold and the screen post-pass
	# cannot supply (its grain is camera-locked, so it reads as dirt on the lens rather than as rough rock).
	# See scenes/rock_grit.gdshader; measured by tools/check_underground.
	var grit := ShaderMaterial.new()
	grit.shader = load("res://scenes/rock_grit.gdshader")
	_fine_layer.material = grit
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
	# ...and the tooth AGAIN, above the veil, because below it there is no tooth at all. rock_grit paints
	# into the terrain layer at z=-9 and `_dark` MULTIPLIES at z=50, so its additive floor — the one written
	# "so rock that the veil has taken most of the way down still has something in it" — is scaled by the
	# very factor that made the rock dark. See scenes/rock_tooth.gdshader; measured by check_rock_reads.
	_tooth = LightLayer.new()
	_tooth.setup(52, _paint_fine_terrain)
	_tooth.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tooth_mat := ShaderMaterial.new()
	tooth_mat.shader = load("res://scenes/rock_tooth.gdshader")
	_tooth.material = tooth_mat
	add_child(_tooth)
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
	_bake_terrain_full()   # the initial coarse terrain: every chunk, and the target cleared under it
	sim.terrain_dirty.clear()  # drop any dirt from world-seeding — the initial paint above already covers it
	_dark.queue_redraw()  # the veil's ONE draw command (the stretched lightmap); content updates via the texture


## Full-world repaint, for when the terrain changed WHOLESALE under the retained caches (loading a
## save). Requeues every terrain chunk + the skylight veil and drops the lazy seal-row cache. The
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
		_bake_terrain_chunks(dirty)
		sim.terrain_dirty.clear()
		_leaf_cache_dirty = true   # a felled tree stops shedding leaves
		_crystal_seams_valid = false   # a dig/place near ore changes which cells are EXPOSED — reflood the seams (#4)
		# The mold follows the dug shape — but patch ONLY the changed region's fine cells (dirty-chunks,
		# #102), not the whole grid: the per-dig freeze was the full fine rebake this used to trigger.
		_fine_region_pending = true
		_fine_dirty_min = rmin
		_fine_dirty_max = rmax
		# The veil is a pure LIGHT LEVEL now (#S3) — it carries no material colour at all, so a dig never
		# patches its hue. Only the skylight base cares, because a dig can move the surface line — and it
		# can only have moved it in the columns that changed (#S14).
		if _veil_cols_dirty:
			_veil_col_min = mini(_veil_col_min, rmin.x)
			_veil_col_max = maxi(_veil_col_max, rmax.x)
		else:
			_veil_col_min = rmin.x
			_veil_col_max = rmax.x
		_veil_cols_dirty = true
	if _fine_dirty:
		_bake_fine_terrain()          # FULL rebake (initial / load) — the slow lane
	elif _fine_region_pending:
		_bake_fine_region(_fine_dirty_min, _fine_dirty_max)   # the per-dig fast lane
		_fine_region_pending = false
	elif _fine != null and _fine.pending_rows() > 0:
		# #17: the boot bake painted only what was on screen. Fill the rest a slice per frame — behind the
		# player, off-camera, and after a dig has had its turn, because a dig is the one edit that is
		# visible immediately. See FineTerrain.bake_pending.
		_fine.bake_pending(FINE_FILL_BUDGET_US)
		if _fine_layer != null:
			_fine_layer.queue_redraw()


## FULL BAKE — every chunk, onto a freshly cleared target. Used for the initial paint and for a wholesale
## change (loading a save), where nothing on the target can be trusted. CLEAR_MODE_ONCE rather than ALWAYS:
## the target is retained from here on, and clearing it again would undo every partial bake below.
func _bake_terrain_full() -> void:
	for chunk: LightLayer in _chunks:
		chunk.visible = true
		chunk.queue_redraw()
	_erase_rects.clear()
	_terrain_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_terrain_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_terrain_layer.queue_redraw()


## PARTIAL BAKE (#S14) — the per-dig fast lane, and the fix for the mining hitch.
##
## Only the dirty chunks are made visible, so only their retained draw buffers are replayed; every other
## chunk keeps the pixels already in the target. The eraser blanks the dirty rects first, because a chunk
## repaint can only ADD coverage — a cell dug open to the sky would otherwise keep its rock.
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
## clear rather than a no-op — see scenes/erase.gdshader.
func _paint_erase(layer: LightLayer) -> void:
	for r: Rect2 in _erase_rects:
		layer.draw_rect(r, Color(0.0, 0.0, 0.0, 0.0))


## The row-major index of the chunk owning `cell`, or -1 if the cell is out of the world.
func _chunk_index(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= FactorySim.GRID_COLS or cell.y >= FactorySim.GRID_ROWS:
		return -1
	return (cell.y / CHUNK) * _chunk_cols + (cell.x / CHUNK)


# --- draw sequence (WORLD space; the Camera2D provides the view transform) ----

func _draw() -> void:
	_zoom = get_canvas_transform().get_scale().x   # once per frame; every zoom gate below reads this
	# Terrain + background walls + the smoothed surface are STATIC: drawn by the chunked terrain canvases
	# (below this, z -10) and repainted only on the DIG'd chunk. This per-frame pass draws ONLY the live/
	# sparse content (machines, items, conduits, cursor) — no full-world cell loop.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE).grow(1.0), Color(0.22, 0.23, 0.27), false, 2.0)  # world border
	_draw_crumble()   # a just-mined block shattering away at the terrain layer (#18)
	_draw_seams()     # the rock's grain — the planes a blow can follow (#S31)
	_draw_drop_paths()
	_draw_lode()      # ore in the BACK WALL — the vein you cleared the rock off, and how much is left
	_draw_ore_glints()  # veins glitter in the dark — discovery reads from across a cavern
	_draw_updrafts()  # rising shimmer in each lift's shaft, so "this column lifts UP" reads
	_draw_conduits()  # power tubes (copper, with a channel that glows by the live power level)
	_draw_power_pulses()  # bright beads flowing DOWN the live network — energy visibly moving (#19)
	_draw_ropes()     # placed climb-ropes hanging down their shafts (behind machines + the body)
	_draw_torches()   # mounted torches guttering on the walls — placed light, claimed territory
	_draw_saplings()  # planted sprouts growing on the sim's tick (#38 — renewable wood)
	_draw_ground()
	_draw_water()      # the L3 fluid layer — translucent blue pools filling each cell to its water line
	_draw_fill_tells() # YOUR OWN construction: packed fill reads as aggregate, loose fill weeps
	_draw_surface_life()  # drifting leaves off the canopies + the occasional bird — the surface breathes
	falling.draw(self, _view_world_rect(2.0))
	# Cull machines whose cell is off-screen. Margin 3 cells so a partially-on-screen machine's glow,
	# held-count badge, I/O ports, status bubble and contact shadow (all reaching past its own cell)
	# aren't clipped at the view edge. Off-screen machines aren't visible → skipping is pixel-identical.
	var mview: Rect2 = _view_world_rect(3.0)
	_plan_machine_labels(mview)   # nameplates are laid out for the whole frame before any of them draws
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

## Side length of a spatial-hash bucket, in cells. Any value >= CLUSTER_LINK works; at 4 the seven-cell
## neighbourhood a frontier pop has to search spans at most three buckets per axis.
const CLUSTER_BUCKET: int = 4

func _crystal_seams() -> Array[Dictionary]:
	return _cluster_seams(_exposed_ore_cells())


## The flood itself, split out from the world query above so it can be tested as what it is: a pure
## function from a cell list to a seam list. check_seam_flood drives it with synthetic scatters and clumps
## and compares it against the obvious quadratic implementation, which is a far harder test than one world.
##
## THE SEARCH IS SPATIAL, NOT LINEAR. This used to rescan the ENTIRE cell list for every frontier pop —
## O(n^2) in exposed ore — and it ran on a frame where n is at its largest, because digging is the thing
## that exposes ore. Now each pop looks only in the buckets its own neighbourhood can reach.
##
## THE ORDER IS PRESERVED, and that is not incidental: this is a GREEDY flood, so the order cells are
## absorbed in decides which seam a cell between two seams lands in, and therefore the centroids and radii
## that get drawn. The old scan walked a globally sorted list, so for a given frontier cell it absorbed
## matching cells in sorted order; the gathered candidates are re-sorted here to reproduce exactly that.
## Without the sort this is still a correct clustering and a different picture.
func _cluster_seams(from_cells: Array[Vector2i]) -> Array[Dictionary]:
	var cells: Array[Vector2i] = from_cells.duplicate()
	cells.sort()                                        # deterministic flood order
	# cell -> bucket, and bucket -> the cells in it. floori and not `>> 2`, but NOT for the reason this
	# comment first claimed: GDScript's right shift on ints floors toward negative infinity, so the two
	# agree on every coordinate including negative ones (checked, after a mutation that swapped them stayed
	# green and exposed the claim as decoration). The real reason is narrower — `>>` silently requires
	# CLUSTER_BUCKET to be a power of two, and nothing else here does. floori keeps the constant free.
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
			near.sort()                                 # …the globally-sorted order the old linear scan had
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


## THE LODE IN THE WALL (`docs/LODE.md` §4). Ore stopped being a block you punch out and became a face you
## work, so it needs to draw as a FACE: a wash of the ore's colour on the backing plus its flecks embedded in
## it, permanent, sitting there while you decide what to do about it. This is not the glint — the glint is a
## rare twinkle that says "something is over there", and it still fires on top of this. This is the thing
## itself, and it has to hold up being looked at for a long time, because you are going to build on it.
##
## AND IT THINS AS IT DRAINS, which is the part that has never existed. `deposits` is the number the player is
## meant to plan around and it has never once been visible: a 250-unit cell and a 4-unit cell were pixel
## identical, which broke the Drift Rig's own capture (docs/DRIFT.md — the rig chewed one cell forever and the
## photograph had to seed thin seams by hand to show a cycle). The fleck set is deterministic per cell and the
## draw takes a PREFIX of it, so flecks disappear one by one as the vein is worked rather than reshuffling —
## a half-worked vein looks like the same vein, half worked.
##
## Only EXPOSED lode draws. Ore still behind rock is the stain's job (`docs/LODE.md` §10, phase 4); until then
## the rock keeps its secret, exactly as it does today.
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
		# The MATRIX is baked into the wall plane (see `_wall_base_color`); what is left for the live pass is
		# the metal in it — and how much of it is left, which is the whole reason this draw exists.
		var nug: Color = _zone_tinted(def.nugget_color, c.y)
		var all: Array[Vector2] = _cell_speckles(c, def.nugget_count)
		var n: int = maxi(1, int(round(frac * float(all.size()))))
		for i: int in n:
			var p: Vector2 = base + all[i]
			# Size and facing are read back out of the position, so the grain field stays deterministic per
			# cell — a half-worked vein is the SAME vein, half worked — without a second hash to keep in step
			# with the first as the prefix shortens.
			var j: float = fposmod(all[i].x * 0.37 + all[i].y * 0.19, 1.0)
			var spin: float = fposmod(all[i].x * 0.11 + all[i].y * 0.53, 1.0) * TAU
			_draw_grain(p, GRAIN_MIN + GRAIN_VARY * j, spin, nug)


## HOW BIG A GRAIN OF METAL IS, and how much the size varies across a face. Small: the fleck field has to
## survive being stared at for as long as it takes to build on it, and a big fleck is a sticker.
const GRAIN_MIN: float = 1.45
const GRAIN_VARY: float = 1.15
const GRAIN_SEAT := Vector2(0.6, 0.9)                ## how far the grain's own shadow falls behind it
const GRAIN_SEAT_COLOR := Color(0.0, 0.0, 0.0, 0.38)
const GRAIN_BODY_DARK: float = 0.34                  ## the grain's midtone, under its nugget colour
const GRAIN_LIT: float = 0.42                        ## the facet the light is on
const GRAIN_SHADE: float = 0.36                      ## …and the one it is not


## ONE GRAIN OF METAL IN THE FACE — angular, and lit from one side.
##
## The lode's look died three times on the same read before this: a circle with a bright core is a BUBBLE, and
## six of them per cell is foam. Rock does not hold round metal. A grain is a facet — a small quad seated in
## its own shadow, split into a lit half and a shaded half — and the two-tone split is what does the work,
## because it means the grain is a SHAPE catching light from somewhere rather than a dot emitting it. That is
## `docs/LODE.md` §11's first line ("ore does not glow, it answers your lamp") spent at the level of one fleck;
## the veil overhead still does the rest, dimming the whole field where no lamp reaches it.
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
## Re-spanned when the world grew to 128 rows: the same four-beat arc, stretched over a descent that is
## now sixty rows longer, so a band is a stretch you travel rather than a step you cross.
const ZONE_TINTS: Array[Dictionary] = [
	{"from": 30, "to": 46, "color": Color(0.86, 0.58, 0.30), "strength": 0.22},   # Clayband — warmth to lose
	{"from": 48, "to": 62, "color": Color(0.55, 0.58, 0.66), "strength": 0.16},   # the honest neutral middle
	{"from": 64, "to": 84, "color": Color(0.40, 0.30, 0.62), "strength": 0.26},   # the approach to the seal
	{"from": 86, "to": 118, "color": Color(0.42, 0.55, 0.90), "strength": 0.34},  # Stonereach (L2), below the seal
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
	return FineTerrain.apply_tone(_cell_base_color(c, def), _cell_tone(c))


## The cell's colour BEFORE any tone: the material's base darkened with depth and zone-tinted. Split out
## for the fine bake (#S12), which needs the base and the tone separately so it can reconstruct the tone
## field between coarse samples instead of inheriting one flat value per 32px cell. The coarse pass gets
## the two put straight back together above, so its output is unchanged.
func _cell_base_color(c: Vector2i, def: MaterialDef) -> Color:
	var depth: float = clampf(float(c.y) / float(FactorySim.GRID_ROWS), 0.0, 1.0)
	var base: Color = def.base_color.darkened(depth * def.depth_darken)
	# THE STAIN (`docs/LODE.md` §10 phase 4). Rock with a vein behind it is MINERALISED rock, and it should
	# look it — otherwise, once ore stops being a block, the world is uniform stone and the only way to find
	# anything is to dig at random. This is the answer to the question that opened the whole migration:
	# "maybe the rock has some signal so you know there's a specific ore behind it".
	#
	# It is a DISCOLOURATION and nothing else. Not a glint: `_draw_ore_glints` already learned, at some cost,
	# that sparkling cells sealed inside stone read as a floating starfield rather than as a vein, so buried
	# ore gets no motion at all — §11's motion budget is spent entirely on the faces you have opened. And it
	# is far weaker than an exposed face, because it has to be findable without being a map marker: what you
	# notice is that a patch of rock is not quite the colour of the rock beside it.
	if sim.lode.has(c):
		base = _stain(base, _material(sim.lode[c]), LODE_STAIN_BURIED)
		base.v *= LODE_STAIN_BURIED_DARK
	return _zone_tinted(base, c.y)


## Carry rock `amount` of the way toward the metal in it, in HUE only — the host keeps the say over how lit
## it is. Shared by the buried stain and the exposed face so the two can never drift apart: an opened vein
## has to be the same vein, more so.
func _stain(host: Color, vein: MaterialDef, amount: float) -> Color:
	var out: Color = host.lerp(vein.nugget_color, amount)
	out.v = host.v * lerpf(1.0, LODE_STAIN_LIFT, amount / LODE_STAIN)
	return out


## The cell's (jitter, strata) tone, both already scaled by the depth boost.
##
## CONTRAST TO SPEND (#S2). Underground, everything a cell is painted with gets compressed twice — once
## by depth_darken, then again by the shadow veil sinking it toward a fraction of itself. A tonal range
## that reads fine in daylight survives that as mush, which is the mechanical reason deep rock looked
## like fog: the detail was there, scaled down until it stopped being detail. Both the jitter and the
## bedding therefore get progressively LOUDER with depth, so what reaches the eye after the veil takes
## its cut is roughly as legible at the bottom of the world as at the top. Measured against a real delve
## capture, not guessed: at the veil's opacity roughly half a cell's own tonal range survives to the eye,
## so the compensation has to be well over 2x by the deep band before bedding reads down there at all.
##
## That boost is also why quantising these two to the coarse grid was so costly, and why the fine bake
## reconstructs them: the term the game amplifies most was the term drawing the grid.
##
## Both are applied RELATIVE to the cell's own colour (see FineTerrain.apply_tone), then tinted. Absolute
## band targets looked right against brown topsoil and silently died below it: a dark clay target sits
## almost exactly on deep stone's own colour, so half the bedding became a no-op in precisely the place
## that needed it most. Lightening and darkening the cell always swings, whatever the cell happens to be;
## the tint then rides on top for the hue that makes a band read as a different DEPOSIT, not just shading.
func _cell_tone(c: Vector2i) -> Vector2:
	var depth: float = clampf(float(c.y) / float(FactorySim.GRID_ROWS), 0.0, 1.0)
	var boost: float = 1.0 + depth * 2.2
	return Vector2(_cell_jitter(c) * boost, _strata(c) * boost)


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
## The two band COLOURS live on FineTerrain with `apply_tone`, which is now the single authority for what
## a tone means to a pixel — the coarse pass and the fine pass have to agree, so only one of them may own it.
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
		# OVER YOUR DRIVE: the cursor goes cold and crossed BEFORE you press (docs/BITS.md §5). A binary
		# gate is only honest if you can see it coming, and the alternative — finding out by clicking and
		# watching nothing happen — reads as a broken game rather than as a locked door.
		if _aim_in_reach and not _aim_bites:
			var no := Color(0.86, 0.42, 0.34, 0.60 + 0.16 * sin(_anim_time * 3.0))
			draw_rect(Rect2(pos + Vector2(1, 1), Vector2(CELL - 2, CELL - 2)), no, false, 2.0)
			draw_line(pos + Vector2(5, 5), pos + Vector2(CELL - 5, CELL - 5), no, 2.0)
			draw_line(pos + Vector2(CELL - 5, 5), pos + Vector2(5, CELL - 5), no, 2.0)
			return
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
		if _ghost_def.behavior == &"drift" and _aim_placeable:
			_draw_drift_preview()    # the 2-high gallery + BOTH drop columns, each lit for its own drain
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


## When holding the Drift Rig, preview the TWO things that make it a different machine from the Borer:
## the gallery is TWO CELLS HIGH, and the haul leaves by TWO COLUMNS — pay straight down, spoil down the
## column behind. `docs/DRIFT.md` §6 names this as the thing most likely to go wrong ("two drop columns is
## twice the geometry to get wrong"), so both arrows are drawn and each is lit for its OWN drain: gold where
## a column has somewhere to fall, red-amber where that stream would pool the moment it started.
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
		# Tinted by CLASS, not by material: this machine's whole promise is that it separates the two, so
		# the preview should already show you which half of that wall is ore and which half is rock.
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
		_draw_dashed_rect(box, Color(1.0, 0.80, 0.30, 0.85), 6.0, 2.5)
	_drift_chute(_aim.x, "ORE")
	_drift_chute(_aim.x - facing, "SPOIL")


## One of the rig's two drop columns, drawn as an arrow under it and labelled, lit for its own drain.
func _drift_chute(col: int, label: String) -> void:
	var below := Vector2i(col, _aim.y + 1)
	if not sim.in_bounds(below):
		return
	var drained: bool = not sim.is_solid(below) or sim.machine_at(below) != null
	var tint := Color(1.0, 0.80, 0.30, 0.95) if drained else Color(0.98, 0.45, 0.38, 0.95)
	var cx: float = float(col * CELL) + float(CELL) * 0.5
	var top_y: float = float(below.y * CELL) + 3.0
	var bot_y: float = top_y + float(CELL) * 0.55
	draw_line(Vector2(cx, top_y), Vector2(cx, bot_y), tint, 2.5)
	draw_line(Vector2(cx, bot_y), Vector2(cx - 6.0, bot_y - 6.0), tint, 2.5)
	draw_line(Vector2(cx, bot_y), Vector2(cx + 6.0, bot_y - 6.0), tint, 2.5)
	var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_string(_font, Vector2(cx - w * 0.5, bot_y + 12.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, tint)


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
## Measured, not guessed, twice. The first measurement — a 13x7 chamber with two torches in it — found
## the back wall and the surrounding rock printing at luma 0.142 vs 0.117, so THE ROOM WAS INVISIBLE:
## you could not tell carved space from mass. The response was to spend half the wall's value proving it
## was not the rock in front of it, which separated the planes and cost the room its back wall — a lit
## chamber whose middle was a black rectangle.
##
## The real culprit was upstream (see MASS_SHADE): the veil gave buried rock and open space identical
## light, so no amount of grading here could win. Now the mass darkens itself and the same chamber
## measures 0.182 against 0.052 — a 3.5x separation instead of 1.2x — which buys the wall its value
## back. It is a lit rock surface again, and the recess is carried by the cast shadows above, by hue,
## and by the lighting model finally agreeing with all of it.
## WALL_RECESS and WALL_COOL live on FineTerrain with `apply_wall_tone`, which is now the single authority
## for what a wall colour is — the coarse pass and the fine pass have to agree, so only one may own it.
const WALL_AO_UNDER: float = 0.62    ## cast shadow on the wall under a solid ceiling — the deepest
const WALL_AO_SIDE: float = 0.34     ## …beside a solid wall
const WALL_AO_ABOVE: float = 0.16    ## …over a solid floor: light reaches a floor, so it stays open
## #S15: this pass used to run over every cell in the chunk, and almost all of it was invisible — the fine
## layer paints a walled cell opaquely, either as rock or (since #S13) as the wall itself. Almost: the mold
## deliberately leaves the top SURFACE_KEEP fine rows of each column's surface cell transparent so the grass
## cap can own the walked line, and a surface cell with a wall behind it shows THROUGH there. So the pass
## survives, confined to the band where it can still be seen. Same reasoning, and the same band, as the cell
## pass in `TerrainPainter.paint`.
func _draw_background(ci: CanvasItem, rect: Rect2i) -> void:
	var band: PackedInt32Array = PackedInt32Array()
	band.resize(rect.size.x)
	for i: int in rect.size.x:
		# Same bound as the mold's, and for the same reason: `surface_row` answers with the floor of a
		# shaft on a dug column, and this pass would then show the WALL through the cap band at whatever
		# depth the player happened to stop digging.
		var top: int = sim.surface_row(rect.position.x + i)
		band[i] = FineTerrain.walked_surface(top)
	for cy: int in range(rect.position.y, rect.position.y + rect.size.y):
		for cx: int in range(rect.position.x, rect.position.x + rect.size.x):
			var top_here: int = band[cx - rect.position.x]
			# Tested for by NAME, not left to the distance check. NO_SURFACE is -1, and `absi(0 - -1)` is
			# 1, which is NOT greater than 1 — so row zero of a hole column would have fallen through and
			# drawn. It is sky up there and `sim.wall` would have rejected it a line later, so the bug was
			# invisible; a sentinel that survives on a downstream accident is the thing being fixed here.
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


## THE GRAIN, DRAWN (#S31) — only where it is being used.
##
## `Seams` gives every rock cell a bedding plane, a joint, a diagonal or nothing, and a blow that follows one
## calves the whole run, so the grain has to be READABLE BEFORE YOU SWING or the mechanic is a slot machine.
## The first version answered that by drawing every plane in the world, all the time, and it was wrong on
## screen in three compounding ways. `Seams.at` keys bedding to the ROW and joints to the COLUMN, so one
## plane spans the entire world. Each cell laid its stroke on its own EDGE, so a run of them is a ruled line
## lying exactly on a cell boundary. And it was inked at 0.58 alpha. Eighteen percent of rows and twelve
## percent of columns, ruled, on the grid, in ink: the ground read as graph paper — dashed lines running up,
## sideways and diagonally across untouched rock, which is a renderer drawing its own storage layout.
##
## The fix is not a quieter version of that. "Readable before you swing" is answered better by the CURSOR
## than by the world: hovering a cell lights the plane through it and the run it would shear, which is more
## information than an ambient hairline ever carried, at the exact moment it is worth having, and it costs
## the other nine-tenths of the screen nothing. So the ambient pass is gone and rock reads as rock. The
## stroke itself is a SHADOW WITH A LIT LIP, never a drawn line — rock does not have ink in it — and it
## still wanders off the cell line, because a parting that ran straight down a boundary would put the grid
## back on screen for as long as the cursor sat there.
const SEAM_AIM_DARK := Color(0.02, 0.03, 0.05, 0.60)
const SEAM_AIM_LIP := Color(1.0, 0.96, 0.86, 0.32)
const SEAM_WANDER: float = 0.30                        ## how far off its nominal line a parting strays, in cells

func _draw_seams() -> void:
	var s: float = float(CELL)
	for key: Variant in _aim_run():
		var c: Vector2i = key
		_stroke_seam(c, Seams.at(c, sim.world_seed), s, SEAM_AIM_DARK, SEAM_AIM_LIP, 2.2)


## A smooth ±1 wander along a plane, sampled per cell INDEX so neighbouring cells share an endpoint exactly
## and the polyline is continuous. Two sines rather than a hash on purpose: a hash steps at every cell, which
## is the defect this replaces — a plane has to bend, not jump.
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


## The cells the AIMED cell's plane runs through, within one blow's reach along it — the mechanic made
## visible at the moment it is about to be used. Walked with `MainView._calve`'s own gates (contiguous, same
## seam, still solid) so what lights up is what would actually shear, not a decoration that resembles it.
## The heading gate is deliberately NOT applied: this says which way the rock parts, which is the thing you
## need in order to choose a heading at all.
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
const WATER_SHEEN_RADIUS: float = 2.4                 ## cells — wide enough that neighbouring pools MERGE
const WATER_SHEEN_SPREAD: float = 0.42                ## ...and dimmer each, so the total stays a whisper
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


## WATER, and the difference between a body of it and a blue rectangle.
##
## What was here drew every water cell as one flat translucent quad with a bright 2px line along its top,
## and that line was drawn for EVERY cell — including the ones with more water above them. So a pool three
## deep came out as three glowing horizontal stripes stacked inside a uniform slab, which is why the
## aquifers read as UI panels rather than as water. Three things fix it, and none of them are expensive:
##
##   THE SURFACE IS THE SURFACE.  The waterline is drawn only where there is sky (or rock, or air) directly
##                                above. Everything below is interior and gets no edge at all.
##   DEPTH DARKENS.               Water is not one colour. The further down inside the body a cell sits, the
##                                deeper and denser it draws — a gradient is the single cheapest cue that a
##                                volume has volume, and a flat fill is the single loudest cue that it does
##                                not.
##   IT MOVES.                    A still surface reads as a solid. The waterline rides a small travelling
##                                sine and carries a soft meniscus under it, and slow caustic bands drift
##                                through the body. All cosmetic, all off the free-running clock, none of it
##                                anywhere near the sim.
## Deep water is deeply BLUE, not dark. The first value here (0.05, 0.16, 0.34) took the body toward black
## as it deepened, which loses the one cue that says "this is water and not a hole": measured against the
## rock it sits in, the colour separation fell to 10 levels and most of that was the top few cells. Dropping
## red and green further while HOLDING blue up deepens it and reads more like water, not less.
const WATER_DEEP := Color(0.03, 0.13, 0.46)           ## the colour the body tends toward with depth
const WATER_DEPTH_CELLS: float = 7.0                  ## cells down over which the gradient runs out
## Deliberately short of opaque. Depth is carried by COLOUR — toward WATER_DEEP — rather than by density,
## because the rock behind a pool is where a body of water gets most of its visible structure: shut it out
## and the interior goes back to being a flat field, just a darker one. Judged, not guessed: at 0.80 the
## body measured 60% featureless by the shared dead-space standard; the rock showing through is what fixes
## that, not more caustics.
const WATER_ALPHA_DEEP: float = 0.66                  ## ...and the density it reaches there
const WATER_RIPPLE_AMP: float = 1.5                   ## px the waterline travels
const WATER_RIPPLE_LEN: float = 46.0                  ## px between ripple crests
const WATER_RIPPLE_SPEED: float = 1.7                 ## crests per second
const WATER_MENISCUS: float = 3.0                     ## px of soft edge hung under the bright line
const WATER_CAUSTIC_LEN: float = 78.0                 ## px between caustic bands
const WATER_CAUSTIC_SPEED: float = 0.55
const WATER_CAUSTIC: float = 0.15                     ## how much a band lifts the fill
## A second, finer set crossing the first the other way. One band pattern is a stripe; two at different
## scales and drifting in opposite directions interfere, and interference is what light on moving water
## actually looks like.
const WATER_CAUSTIC_LEN2: float = 29.0
const WATER_CAUSTIC_SPEED2: float = -0.9
const WATER_CAUSTIC2: float = 0.09


## How far INSIDE the body this cell sits: 0 at the surface, growing downward, capped where the gradient
## has run out anyway so a deep aquifer costs no more to draw than a puddle.
func _water_depth(c: Vector2i) -> float:
	var d: int = 0
	while d < int(WATER_DEPTH_CELLS):
		if sim.water_at(c - Vector2i(0, d + 1)) <= 0:
			break
		d += 1
	return float(d) / WATER_DEPTH_CELLS


## WHAT YOU BUILT, AND WHETHER IT HOLDS. Two tells over the same one pass, because they are two halves of
## one fact (docs/DRIFT.md §4):
##
##   PACKED fill draws as AGGREGATE — a compacted stipple with a hairline seam around the cell. The molded
##     terrain layer blends a one-cell material into its neighbours (that is what makes rock read as rock
##     rather than as tiles), which is exactly wrong for a wall whose whole value is being a different
##     material from the rock beside it. So packing is drawn ON TOP, as construction rather than as strata.
##   LOOSE fill WEEPS when water leans on it: a bead runs down the dry face and fades, phased per cell so a
##     wall reads as a weeping SURFACE rather than one blinking light. Without it, water simply appears on
##     the dry side out of nowhere, and the player never learns which of their walls is the leak.
##
## Iterates `fill` — the cells YOU built — so the cost is the size of your own construction, culled to the
## view. Pure representation: reads the sim, never writes it.
func _draw_fill_tells() -> void:
	if sim.fill.is_empty():
		return
	var view: Rect2 = _view_world_rect()
	var cell_f: float = float(CELL)
	for key: Variant in sim.fill:
		var c: Vector2i = key
		var base := Vector2(c) * cell_f
		if not view.has_point(base):
			continue
		if sim.fill[c] == FactorySim.FILL_PACKED:
			_draw_packed_cell(base, c, cell_f)
			continue
		if sim.water.is_empty():
			continue
		for pair: Array in [[Vector2i(0, -1), Vector2i(0, 1)], [Vector2i(-1, 0), Vector2i(1, 0)],
				[Vector2i(1, 0), Vector2i(-1, 0)]]:
			var wet: Vector2i = c + (pair[0] as Vector2i)
			var dry: Vector2i = c + (pair[1] as Vector2i)
			if sim.water_at(wet) < FactorySim.SEEP_PRESSURE or sim.is_solid(dry):
				continue
			var face := base + Vector2(cell_f, cell_f) * 0.5 + Vector2(pair[1] as Vector2i) * cell_f * 0.44
			# The face goes WET first — a cool sheen down the dry side, which is what you actually notice
			# from across a gallery — and the beads run down it.
			draw_line(face + Vector2(0.0, -cell_f * 0.46), face + Vector2(0.0, cell_f * 0.46),
				Color(0.55, 0.78, 0.94, 0.26), 3.0)
			for b: int in 2:
				var phase: float = fmod(_anim_time * 0.5 + float(c.x * 7 + c.y * 13) * 0.11
					+ 0.5 * float(b), 1.0)
				var at: Vector2 = face + Vector2(0.0, -cell_f * 0.42) + Vector2(0.0, cell_f * 0.9) * phase
				var fade: float = (1.0 - phase * 0.7)
				draw_circle(at, 2.3, Color(0.52, 0.76, 0.94, 0.85 * fade))
				draw_circle(at + Vector2(-0.6, -1.0), 1.1, Color(0.86, 0.95, 1.0, 0.85 * fade))
			break


## One packed cell: a hairline seam that says "this is a placed block, not the rock" and a deterministic
## scatter of crushed aggregate inside it. Deterministic (hashed off the cell) so it never crawls, and
## drawn at low alpha so a packed bulkhead reads as a surface rather than as a decal.
func _draw_packed_cell(base: Vector2, c: Vector2i, cell_f: float) -> void:
	draw_rect(Rect2(base + Vector2(1.0, 1.0), Vector2(cell_f - 2.0, cell_f - 2.0)),
		Color(0.70, 0.76, 0.84, 0.16), false, 1.0)
	var seed: int = c.x * 73856093 ^ c.y * 19349663
	for i: int in 6:
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var px: float = float(seed % 1000) / 1000.0
		seed = (seed * 1103515245 + 12345) & 0x7fffffff
		var py: float = float(seed % 1000) / 1000.0
		draw_circle(base + Vector2(3.0 + px * (cell_f - 6.0), 3.0 + py * (cell_f - 6.0)), 1.5,
			Color(0.62, 0.66, 0.72, 0.30))


func _draw_water() -> void:
	if sim.water.is_empty():
		return
	var view: Rect2 = _view_world_rect()
	var cell_f: float = float(CELL)
	var t: float = _anim_time
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

		var open_above: bool = sim.water_at(c - Vector2i(0, 1)) <= 0
		if not open_above:
			# AN INTERIOR CELL IS FULL. Its own level is a bookkeeping number about how much water lives
			# here, not a height — the water above it is resting ON it, so there is no air in this cell to
			# draw. Honouring the level everywhere made a settling body terrace into horizontal slabs with
			# gaps of rock showing between them, which is what a large pool looks like for the several
			# seconds it takes the sim to even out, and what an unevenly-fed aquifer looks like forever.
			left_y = base.y
			right_y = base.y
		if open_above:
			# Only a cell with nothing above it owns a waterline, and only that line ripples.
			left_y += sin((base.x) / WATER_RIPPLE_LEN * TAU + t * WATER_RIPPLE_SPEED * TAU) * WATER_RIPPLE_AMP
			right_y += sin((base.x + cell_f) / WATER_RIPPLE_LEN * TAU
				+ t * WATER_RIPPLE_SPEED * TAU) * WATER_RIPPLE_AMP

		# Depth tint: toward WATER_DEEP and denser as the body closes over you.
		var depth: float = _water_depth(c)
		var body: Color = WATER_COLOR.lerp(WATER_DEEP, depth)
		var alpha: float = lerpf(WATER_ALPHA, WATER_ALPHA_DEEP, depth)
		# ...and slow caustic bands, so the interior is never one dead value.
		var caustic: float = 0.5 + 0.5 * sin((base.x + base.y * 0.6) / WATER_CAUSTIC_LEN * TAU
			- t * WATER_CAUSTIC_SPEED * TAU)
		var caustic2: float = 0.5 + 0.5 * sin((base.x * 0.7 - base.y) / WATER_CAUSTIC_LEN2 * TAU
			- t * WATER_CAUSTIC_SPEED2 * TAU)
		body = body.lightened((caustic * WATER_CAUSTIC + caustic2 * WATER_CAUSTIC2)
			* (1.0 - depth * 0.4))
		var fill := Color(body.r, body.g, body.b, alpha)

		var tl := Vector2(base.x, left_y)
		var tr := Vector2(base.x + cell_f, right_y)
		var br := Vector2(base.x + cell_f, floor_y)
		var bl := Vector2(base.x, floor_y)
		draw_colored_polygon(PackedVector2Array([tl, tr, br, bl]), fill)

		if not open_above:
			continue
		# The MENISCUS: a soft band hung under the bright line so the surface has thickness. Without it the
		# waterline is a drawn stroke sitting on a fill; with it, the fill appears to end in a surface.
		var men := Color(WATER_SURFACE.r, WATER_SURFACE.g, WATER_SURFACE.b, 0.22)
		draw_colored_polygon(PackedVector2Array([
			tl, tr, Vector2(tr.x, right_y + WATER_MENISCUS), Vector2(tl.x, left_y + WATER_MENISCUS)]), men)
		var line := Color(WATER_SURFACE.r, WATER_SURFACE.g, WATER_SURFACE.b,
			minf(1.0, WATER_ALPHA + 0.22))
		draw_colored_polygon(PackedVector2Array([
			tl, tr, Vector2(tr.x, right_y + 1.5), Vector2(tl.x, left_y + 1.5)]), line)


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

## The zoom at/above which a machine's FINE casing detail — rivets, vent slots, the recessed faceplate —
## is resolvable enough to be worth drawing. Same reasoning as TEXT_ZOOM and a different threshold, because
## a rivet stops being a rivet before a label stops being a label: at the locked 0.50x default a 32px cell
## covers 16 screen pixels, and a 1.4px rivet in it is under a pixel of grey. What carries the machines at
## play zoom is the shading and the silhouette, which the cheap tier draws unconditionally.
const DETAIL_ZOOM: float = 0.62

## The canvas scale for THIS frame, read once in `_draw` instead of once per machine. `get_canvas_transform`
## is a server round-trip and the machine loop called it twice per machine — once for the label gate and
## again for the detail gate would have made it three times, on the pass that already owns the frame budget.
var _zoom: float = 1.0


## Should this machine's TEXT decorations draw? Yes when zoomed in enough to read them, OR when it's the
## machine the player is aiming at (so pointing at any box always reads its label/status, even zoomed out).
func _text_visible(cell: Vector2i) -> bool:
	if cell == _aim:
		return true
	return _zoom >= TEXT_ZOOM


## Is this drill standing ON a lode — i.e. a Head boring into the back wall rather than down through rock?
## Two mounts for one machine while the bridge lasts (`docs/LODE_PLAN.md` §3), and the sprite says WHICH,
## so it is never describing the wrong action. After the phase-3 cutover there is only ever the Head.
## Is this machine BOLTED TO THE WALL rather than standing in the cell? A Head on a lode, and every Spur —
## both are frames hung on a face, both must not hide the vein they are eating, and both therefore skip the
## opaque casing and the contact shadow that every other machine gets.
func _is_head(machine: MachineState) -> bool:
	return machine.def.behavior == &"spur" \
		or (machine.def.behavior == &"drill" and sim.lode.has(machine.cell))


func _draw_machine(machine: MachineState) -> void:
	var pos: Vector2 = Vector2(machine.cell) * float(CELL)
	var recipe: RecipeDef = machine.def.recipe
	var center: Vector2 = pos + Vector2(CELL, CELL) * 0.5
	# THE FACE, NOT THE CELL. Everything drawn ON a machine — glyph, badge, progress bar, ports, status
	# lamp — used to be positioned against the cell, which was correct for exactly as long as every machine
	# filled its cell. With `PC-01`'s profiles in, the Forge's input port hung in the air above its chimney
	# and the Ore Vent's progress bar ran across the rock beside its foot. `machine_face` is where the body
	# actually is; `check_casing_light` asserts it stays on one of the body's own parts.
	var face_u: Rect2 = Visuals.machine_face(Visuals.machine_kind(machine.def))
	var face := Rect2(pos + face_u.position * float(CELL), face_u.size * float(CELL))
	if _is_head(machine):
		# A Head is BOLTED TO THE WALL, so it gets no contact shadow at its feet — it is not standing on
		# anything. What it gets instead is a shadow cast onto the plane BEHIND it, offset down-right, which
		# is the cheapest and strongest way to say "this object is in front of that surface".
		draw_rect(Rect2(pos + Vector2(3.0, 3.0), Vector2(CELL - 4.0, CELL - 4.0)),
			Color(0.0, 0.0, 0.0, 0.34))
	else:
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
	elif _is_head(machine):
		# A HEAD IS A FRAME, NOT A FILL (`docs/LODE.md` §5). Every other machine gets an opaque casing filling
		# its cell, which is right for a box that processes things and wrong for one bolted onto the thing it
		# is eating: it would hide the vein completely, and the vein is the only reason the machine is there.
		# So the casing is dropped and the glyph's own rails carry the body — you watch the flecks thin THROUGH
		# the machine, which makes the Head a gauge without adding a gauge.
		Visuals.draw_machine_glyph(self, center,
			"spur" if machine.def.behavior == &"spur" else "collar", 1.0, active, clock, false,
			sim.lode_fraction(machine.cell))
	else:
		Visuals.draw_machine_casing(self, pos, float(CELL),
			SILHOUETTE_GREY if SILHOUETTE_ONLY else Visuals.machine_color(machine.def),
			active, _zoom >= DETAIL_ZOOM, Visuals.machine_kind(machine.def))
		if not SILHOUETTE_ONLY:
			# Scaled to the face it is stamped on, never larger than 1.0: a glyph that overhangs its own
			# casing is the "sticker" read the recessed faceplate exists to defeat.
			# FULL SIZE. The glyph is scaled to the FACE only where a face is genuinely small; every
			# shipped profile's face is the full-width body, and shrinking the glyph to fit it was the
			# single most damaging thing in the first carved version — a 0.8x gear at 16 screen pixels is
			# not a smaller gear, it is a smudge.
			Visuals.draw_machine_glyph(self, face.get_center(), Visuals.machine_kind(machine.def),
				clampf(minf(face.size.x, face.size.y) / float(CELL) + 0.24, 0.6, 1.0), active, clock,
				machine.facing < 0)   # directional machines (the Borer) draw mirrored when facing left

	# TEXT DECORATIONS are gated (perf + de-clutter): the name label, the held-count badge, and the
	# stalled NEED bubble are drawn ONLY when the text is actually readable (zoomed IN past _text_zoom)
	# OR this is the HOVERED/aimed machine (so pointing at any box still reads its label/status even
	# zoomed out). At the locked 0.50× default those labels are a few px tall — unreadable clutter — and
	# draw_string is the priciest per-call, so on a mature base the non-hovered machines drop their text.
	# The info isn't lost: the HUD hover inspector shows a machine's full details on hover regardless.
	var show_text: bool = _text_visible(machine.cell) and not BARE_MACHINES
	if show_text:
		_draw_machine_label(machine, pos)

	var held: int = _held(machine)
	if show_text and held > 0:
		# THE BADGE IS SIZED TO ITS NUMBER. It used to be a fixed 10px box, which is exactly one digit wide;
		# a Head sitting on a fat vein counts into the hundreds and the same viewer who caught the nameplate
		# collision read the result as two UI layers fighting — `889` painted across the machine and clipped
		# by its neighbour's plate. A count that outgrows its box is a count you cannot trust.
		var tag: String = str(held)
		var tw: float = _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 3.0
		var badge := Vector2(face.end.x - 2.0 - tw, face.position.y + 2.0)
		draw_rect(Rect2(badge, Vector2(tw, 11.0)), Color(0.04, 0.04, 0.06, 0.85))
		draw_string(_font, badge + Vector2(1.5, 9.0), tag,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.97, 0.97, 0.99))

	if recipe != null and recipe.time > 0.0:
		var bar_y: float = face.end.y - 3.0
		draw_rect(Rect2(face.position.x, bar_y, face.size.x, 3.0), Color(0.0, 0.0, 0.0, 0.35))
		var frac: float = clampf(machine.progress / recipe.time, 0.0, 1.0)
		draw_rect(Rect2(face.position.x, bar_y, face.size.x * frac, 3.0), Color(0.40, 0.90, 0.45))

	_draw_machine_io(machine, pos, face)
	if not BARE_MACHINES:
		_draw_machine_status(machine, face, show_text)
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


## Factorio-style legibility: a small STATUS LAMP on every machine + a blinking floating NEED bubble
## carrying the missing item's glyph when a machine is stalled on one (no fuel → coal, starved → its input).
## Reads FactorySim.machine_status (the sim's own run-gates, so it can't lie). Pure cosmetic — drawn glyphs,
## no emojis. The direct fix for "why has my drill gone quiet?" — the answer is now ON the machine.
##
## The look of each status lives in `Visuals.STATUS_LOOK`, not in a match here, and that move is the bug fix
## rather than a tidy-up: the match this replaced knew five of the sim's ten statuses and swept the other
## five into the grey that means "nothing is wrong". See the table for what that was showing people.
func _draw_machine_status(machine: MachineState, face: Rect2, show_bubble: bool = true) -> void:
	var pos: Vector2 = face.position   # the lamp rides the machine's own corner, not the cell's
	var status: StringName = sim.machine_status(machine)
	var look: Dictionary = Visuals.status_look(status)
	var lamp: Color = look["color"]
	# Status lamp: a rimmed mark in the machine's top-left corner (mirrors Factorio's entity status light).
	#
	# IT GROWS AS YOU ZOOM OUT. At the inspect zoom this is exactly the dot it always was; at the survey
	# zoom the same world-space dot covers about one screen pixel, which is where audit 195 — "machine
	# states become colour-only at survey zoom" — comes from. A lamp that shrinks with the machine answers
	# the question at the one zoom where you were already close enough to read the machine itself. So the
	# mark holds roughly its screen size instead, capped so it never eats the casing it sits on.
	var k: float = clampf(1.0 / maxf(_zoom, 0.2), 1.0, 1.8)
	var r: float = 3.1 * k
	var lamp_c: Vector2 = pos + Vector2(2.4 + r, 2.4 + r)
	draw_circle(lamp_c, 4.2 * k, Color(0.03, 0.03, 0.05, 0.9))
	Visuals.draw_status_mark(self, lamp_c, r, look["mark"], lamp)
	# Nothing to raise an alarm about: running, resting, or finished. `fix` is the sim's word for what the
	# player would have to DO, so "none" is exactly the set that needs no floating anything, and a status
	# added later inherits the right behaviour from its table entry instead of from a list of names here.
	if StringName(look["fix"]) == &"none" or status == &"spent":
		return
	if not show_bubble:
		# THE BUBBLE IS GONE AT THIS ZOOM, AND A STALL IS THE ONE THING THAT MUST STILL REACH YOU. This is
		# the branch the audit was describing: zoomed out, the need bubble is dropped as unreadable clutter
		# and the machine falls back on a coloured dot roughly a pixel across. So the alarm moves to the
		# only scale that survives out here — the whole cell — and to the one channel that needs no
		# resolution at all: MOTION. A stalled machine breathes a ring around itself; a working one does
		# nothing, because "no alarm" has to stay the quiet state or a mature base becomes a light show.
		var alarm: float = 0.40 + 0.60 * absf(sin(_anim_time * 2.6))
		draw_rect(Rect2(face.position - Vector2(1.5, 1.5), face.size + Vector2(3.0, 3.0)),
			Color(lamp.r, lamp.g, lamp.b, 0.80 * alarm), false, 2.0)
		return
	var pulse: float = 0.62 + 0.38 * sin(_anim_time * 6.5)
	var bob: float = sin(_anim_time * 3.0) * 1.5
	var bc: Vector2 = Vector2(face.get_center().x, face.position.y - 24.0 + bob)
	draw_circle(bc, 9.0, Color(0.05, 0.04, 0.06, 0.82 * pulse))
	draw_arc(bc, 9.0, 0.0, TAU, 20, Color(lamp.r, lamp.g, lamp.b, pulse), 1.6)

	# THE BUBBLE HOLDS UP WHAT YOU WOULD GO AND DO ABOUT IT, which for two statuses is an item you fetch and
	# for three is a job you perform. It could originally only draw items, so the jam / dead-power / unwired
	# states reached it and floated an ORE icon over all three — telling you to feed a machine that was not
	# hungry. They were then silenced, which was true but quiet: the lamp names the KIND of problem and the
	# bubble is where the specific one belongs. Now each job has its own glyph and the bubble speaks for all
	# five, without any of them borrowing another's answer.
	if not bool(look["feeds"]):
		Visuals.draw_fix_glyph(self, bc, 11.0, look["fix"], Color(lamp.r, lamp.g, lamp.b, 0.55 + 0.45 * pulse))
		return
	var need: StringName = &"ore"
	if status == &"no_fuel":
		need = &"coal"
	elif machine.def.behavior == &"descent":
		need = FactorySim.DESCENT_EATS              # the gate eats ingots, not ore
	elif machine.def.recipe != null and not machine.def.recipe.inputs.is_empty():
		need = machine.def.recipe.inputs.keys()[0]
	Visuals.draw_item(self, bc, 11.0, need)


## A small NAME plate centred just above the machine (FORGE / DRILL / LIFT / GENERATOR), so a new player
## can read what each box IS at a glance — the direct fix for "which one is the forge?". Dark pill backing
## keeps it legible over any terrain; uppercased + tight so it reads as a label, not prose. Pure cosmetic.
##
## THE PLATES ARE LAID OUT FOR THE WHOLE FRAME, NOT ONE MACHINE AT A TIME (`_plan_machine_labels`), which
## is the fix for a defect a blind first-time viewer found in a screenshot and read as a straight bug: a
## bank of three generators rendered as `GENER/ GENER/ GENERATOR`, three plates centred on adjacent 32px
## cells with ~45px of text each, overlapping into garbage. A machine cannot see its neighbours, so no
## amount of per-machine cleverness fixes that; something has to look at all of them at once.
const LABEL_FS: int = 8
const LABEL_H: float = 11.0
## How many rows of plates may stack above a machine before the rest are dropped. Two, and not more: the
## third row would start colliding with the machine one cell UP, which trades a text collision for a
## worse one. Run-collapsing below makes deep stacks rare enough that two is generous.
const LABEL_SHELVES: int = 2
const LABEL_SHELF_H: float = 12.0

## cell -> {text, shelf, cx, w} for every nameplate that will actually be drawn this frame.
var _label_plan: Dictionary = {}


## Lay out this frame's machine nameplates. Two passes, and the first one is the interesting one.
##
## RUNS COLLAPSE. A row of contiguous machines with the same name is labelled ONCE, as `SPUR ×5`. This
## started as collision avoidance and turned out to be the better read anyway: the same viewer who caught
## the overlap looked at a row of five Spurs beside a Drill and asked *"is this a conveyor? a bank of
## drills? did I build it or find it?"* — five identical plates say "five things", which is exactly the
## wrong sentence about a chain that is one Head plus its reach. One plate with a count says the truth,
## and says it in less ink.
##
## Then what is left is SHELF-PACKED left to right, dropping to a second row when a plate would land on
## the one before it. The aimed machine is packed first so that pointing at something always names it —
## that is the promise `_text_visible` makes when it exempts the aimed cell from the zoom gate, and a
## packer that silently dropped that plate would quietly break it.
func _plan_machine_labels(mview: Rect2) -> void:
	_label_plan.clear()
	var named: Dictionary = {}
	for m: MachineState in sim.machines:
		if not mview.has_point(Vector2(m.cell) * float(CELL)) or not _text_visible(m.cell):
			continue
		if not m.def.display_name.is_empty():
			named[m.cell] = m.def.display_name.to_upper()
	var runs: Array[Dictionary] = []
	for key: Variant in named:
		var c: Vector2i = key
		var west: Vector2i = c - Vector2i(1, 0)
		if named.get(west, &"") == named[c]:
			continue                          # mid-run: the westmost machine owns the plate for all of us
		var n: int = 1
		while named.get(c + Vector2i(n, 0), &"") == named[c]:
			n += 1
		var text: String = named[c] if n == 1 else "%s ×%d" % [named[c], n]
		var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FS).x + 6.0
		runs.append({"cell": c, "row": c.y, "x0": c.x, "span": n, "text": text, "w": w,
			"aimed": 0 if (_aim.y == c.y and _aim.x >= c.x and _aim.x < c.x + n) else 1})
	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["aimed"]) != int(b["aimed"]):
			return int(a["aimed"]) < int(b["aimed"])
		if int(a["row"]) != int(b["row"]):
			return int(a["row"]) < int(b["row"])
		return int(a["x0"]) < int(b["x0"]))
	var claimed: Dictionary = {}              # "row:shelf" -> the x this shelf is occupied up to
	for r: Dictionary in runs:
		var w2: float = float(r["w"])
		var cx: float = (float(r["x0"]) + float(r["span"]) * 0.5) * float(CELL)
		for shelf: int in LABEL_SHELVES:
			var slot: String = "%d:%d" % [int(r["row"]), shelf]
			if cx - w2 * 0.5 < float(claimed.get(slot, -1.0e9)):
				continue
			claimed[slot] = cx + w2 * 0.5 + 2.0
			_label_plan[r["cell"]] = {"text": r["text"], "shelf": shelf, "cx": cx, "w": w2}
			break


func _draw_machine_label(machine: MachineState, pos: Vector2) -> void:
	if not _label_plan.has(machine.cell):
		return                                # collapsed into a neighbour's plate, or packed out
	var plan: Dictionary = _label_plan[machine.cell]
	var w: float = float(plan["w"])
	var left: float = float(plan["cx"]) - w * 0.5
	var top: float = pos.y - LABEL_H - float(int(plan["shelf"])) * LABEL_SHELF_H
	draw_rect(Rect2(left, top, w, LABEL_H), Color(0.04, 0.05, 0.08, 0.82))
	draw_string(_font, Vector2(left + 3.0, top + 8.5), String(plan["text"]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FS, Color(0.86, 0.90, 0.98))


## Small item-tinted PORTS on a machine's edges: where it EATS (input mouth, top, points IN) and where
## it SPITS (output spout, in the flow direction — down for a recipe-runner/source, down+right for a
## splitter, up for a lift). Tinted by the item so you learn "orange goes in here, yellow comes out
## there" at a glance — the in-world half of the I/O affordances. Pure cosmetic.
func _draw_machine_io(machine: MachineState, pos: Vector2, face: Rect2) -> void:
	var recipe: RecipeDef = machine.def.recipe
	var c: float = float(CELL)
	# THE MOUTH SITS ON THE MACHINE; THE SPOUT SITS ON THE CELL. Goods fall in from above and land on the
	# body, so the input wedge belongs on the face's top edge — over the chimney's shoulder for a Forge,
	# not floating where the chimney is not. Output is the opposite claim: it says which neighbouring CELL
	# the goods leave into, and every profile in the set keeps a flat foot at the cell line for exactly
	# that reason. Both stay on the face's centre column so they read as one throughput line.
	var mid: float = face.get_center().x
	if recipe != null and not recipe.inputs.is_empty():
		var in_item: StringName = recipe.inputs.keys()[0]
		_port(Vector2(mid, face.position.y), Vector2(0, 1), Visuals.item_color(in_item))
	var out_col := Color(0.80, 0.86, 0.94)                                                # neutral "routes"
	if recipe != null and not recipe.outputs.is_empty():
		out_col = Visuals.item_color(recipe.outputs.keys()[0])
	match machine.def.behavior:
		&"lift":
			_port(Vector2(mid, face.position.y), Vector2(0, -1), Color(0.5, 1.0, 0.92))   # spouts UP
		&"splitter":
			_port(Vector2(mid, pos.y + c), Vector2(0, 1), out_col)                        # down
			_port(Vector2(pos.x + c, face.get_center().y), Vector2(1, 0), out_col)        # + right
		_:
			_port(Vector2(mid, pos.y + c), Vector2(0, 1), out_col)                        # spouts down


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
## HOW MUCH OF A FRAME THE OFF-SCREEN FILL MAY TAKE (#17). 4ms of an 8.33ms frame, which is generous
## because the alternative it replaces is 1199ms of not drawing anything at all. It is a target and not a
## cap: `bake_pending` works in whole fine rows (~1.8ms each), so a call can overshoot by one row.
##
## Measured consequence at this budget: ~2 rows a frame, 320 rows, so the world finishes molding a little
## over a second after boot — off-camera, while the player is still reading the opening frame. The visible
## rect is already correct in the first bake; nothing the player is looking at waits for this.
const FINE_FILL_BUDGET_US: int = 4000

## THE OPENING VIEW IS THE GROUND AROUND THE BODY, and it is deliberately NOT the camera rect. Two attempts
## at asking the camera both failed, in ways worth keeping written down because the second one passed a test.
##
## `setup()` runs from main's `_ready` BEFORE the renderer is added to the tree, so `get_canvas_transform`
## and `get_viewport_rect` fail there — first loudly, with two engine errors, then QUIETLY, by returning an
## empty rect that `rebake` reads as "bake everything". The boot bake is the one bake #17 exists to split,
## so the change would have shipped defeating itself with a green sweep behind it.
##
## Guarding that with `is_inside_tree()` — camera rect inside, body rect outside — compiled, passed, and
## was still the wrong shape. It makes the opening view depend on WHICH call site ran first, and the two
## sites disagree: `setup()` is outside the tree and `_process` is inside it, so the same boot could bake
## around the body or around wherever the canvas transform happened to point on frame one, which is not
## necessarily the body. A view that is correct only when the frame ordering cooperates is a view that will
## be wrong on someone's machine and right on the one it was written on.
##
## The body's position needs no tree, no camera and no frame ordering, and the camera in this game is on
## the body by construction. The span is about 1.6 screens wide by 2.2 tall at the default zoom — 49152
## fine cells, 19% of the grid, so the opening bake costs roughly 226ms of the measured 1199ms. Generous on
## purpose, in both axes: overshooting wastes a few milliseconds once, and undershooting shows coarse
## terrain where the player is looking. Undershooting is also self-healing within about a second, which is
## why this errs toward the cheap failure rather than toward covering the survey zoom.
const FINE_OPENING_SPAN := Vector2(2048.0, 1536.0)


## The world rect the opening bake must finish before the first frame.
func _fine_view() -> Rect2:
	var at: Vector2 = player.position if player != null else Vector2.ZERO
	return Rect2(at - FINE_OPENING_SPAN * 0.5, FINE_OPENING_SPAN)


func _bake_fine_terrain() -> void:
	_fine_dirty = false
	if _fine == null:
		return
	_fine.rebake(
		func(c: Vector2i) -> bool: return sim.is_solid(c),
		func(fx: int, fy: int) -> bool: return sim.fine_is_solid(fx, fy),   # P2: the sim's real fine grid
		func(c: Vector2i) -> Color: return _cell_base_color(c, _material(sim.material_at(c))),
		_wall_base_color,
		func(col: int) -> int: return sim.surface_row(col),
		_cell_tone,
		_has_wall,
		sim.fine_solid_bytes(),   # the same fine grid handed over WHOLE — see rebake()'s bulk path
		_fine_view())   # #17: paint what is on screen NOW, owe the rest
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
		func(c: Vector2i) -> Color: return _cell_base_color(c, _material(sim.material_at(c))),
		_wall_base_color,
		func(col: int) -> int: return sim.surface_row(col),
		_cell_tone,
		_has_wall)
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
const WALL_NONE := Color(0.06, 0.055, 0.05)   ## a cell with no wall entry (unlikely on solid terrain)

## How far a vein carries its host rock toward the metal in it, and how much brighter a mineralised face is
## allowed to be than the plain rock beside it. The lift is deliberately almost nothing: a face reads as a
## face because of its colour and its grain, never because it is lit differently from the wall it is cut into.
const LODE_STAIN: float = 0.42
const LODE_STAIN_LIFT: float = 1.05
## …and how far rock STILL COVERING a vein carries, plus how much it DARKENS.
##
## The buried tell gets a value channel and the open face does not, and the asymmetry is the point. Holding
## value is right at an open face: both a face and the rock beside it are things you look at, and a carved
## pocket that came out brighter than its host read as more rock rather than as a hole. Buried, there is no
## such confusion — every cell in question is solid — and value is the only channel with any reach left,
## because the darkness veil crushes saturation long before it crushes brightness. A hue-only stain at 0.14
## was measurably applied and completely invisible on screen, in lamplight, on a forty-cell body.
##
## Mineralised rock reading DARKER is also the right direction: metal in stone is denser and duller than the
## stone, and a bruise in a lit wall is a thing the eye finds without being told to look.
##
## Both numbers are MEASURED, not picked. `capture_moments -- stain` stages two ore bodies in a lit gallery
## and prints the stained-vs-plain luma; capturing it again under SF_NO_LODE=1 gives the same frame without
## them, and the pair is diffed in matched boxes. That loop is the only way to set this honestly, because
## run-to-run noise from animation phase alone reaches ±8% and the first two attempts at this constant were
## read as "invisible" when they were merely below that floor. At 0.78 a buried body measures ~13% darker
## on screen against a ~2% noise floor: a patch of wrong-coloured rock you find when you look, and not a map
## marker. An earlier hue-only version at 0.14 measured -8% in the base colour and was genuinely invisible.
const LODE_STAIN_BURIED: float = 0.26
const LODE_STAIN_BURIED_DARK: float = 0.78

func _wall_fill_color(c: Vector2i) -> Color:
	if not sim.wall.has(c):
		return WALL_NONE
	return FineTerrain.apply_wall_tone(_wall_base_color(c), _wall_strata(c))


## The wall's colour BEFORE any bedding or recess — split out for the fine bake (#S13), which reconstructs
## the bedding between coarse samples rather than inheriting one flat value per 32px cell. The coarse pass
## puts the two straight back together above, so its output is unchanged.
func _wall_base_color(c: Vector2i) -> Color:
	# A LODE IS WALL (`docs/LODE.md`). Ore in the background plane paints as the background plane — which
	# means it inherits the molding, the bedding, the recess shadow and the veil that every other wall gets,
	# for free, and cannot read as a decal stuck on top of the rock. The first cut of this drew the lode as
	# its own translucent wash in the dynamic pass and looked like a poster; the second looked like smoke.
	# Routing it through the wall's own colour authority is not a trick to make it look better, it is the
	# thesis implemented literally: the vein is what the wall is MADE OF here.
	if sim.lode.has(c):
		# MINERALISED, not just "ore-coloured". An ore block's matrix is within a hair of stone's — ore reads
		# as ore because of its pale flecks, not its rock — so painting the wall the ore's base colour is
		# literally correct and completely invisible. A real vein face is STAINED by what is in it, so the
		# wall here is the rock carried a quarter of the way toward the metal. That derives per material
		# rather than being picked: coal stains the wall dark, iron rusty, ore pale. One rule, four answers.
		#
		# …but it stains in HUE, not in VALUE. The first cut lerped the raw colour, and ore's nugget is pale
		# (v 0.85) against its matrix (v 0.34), so a 42% stain brightened the wall by 62% — a carved adit came
		# out LIGHTER than the solid rock around it and read as more rock rather than as a hole with a face at
		# the back of it. `docs/LODE.md` §11 already names the rule this breaks: brightness carries ATTENTION,
		# density carries richness. So the mix sets what the wall is made of and the host rock keeps the say
		# over how lit it is; the metal earns its brightness one grain at a time, in `_draw_lode`.
		var vein: MaterialDef = _material(sim.lode[c])
		var host: Color = _material(sim.wall[c]).base_color if sim.wall.has(c) else vein.base_color
		return _zone_tinted(_stain(host, vein, LODE_STAIN), c.y)
	if not sim.wall.has(c):
		return WALL_NONE
	return _zone_tinted(_material(sim.wall[c]).base_color, c.y)


## The wall's bedding: the SAME beds as the foreground rock, because it IS the same ground seen a plane
## back — a tunnel cut through a sandy layer should show that layer behind it — only quieter.
func _wall_strata(c: Vector2i) -> float:
	return _cell_tone(c).y * FineTerrain.WALL_STRATA_QUIET


func _has_wall(c: Vector2i) -> bool:
	return sim.wall.has(c) or sim.lode.has(c)   # a vein is always something to see, wall behind it or not


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


## THE AIMING GHOST. Where the hook would bite if you threw it now — the marker, and the faint line it
## sits on the end of.
##
## The rope is the traversal verb and it was fired BLIND: you pointed at a wall fifteen cells off and found
## out whether you had the range, and whether anything was in the way, only after the throw. Every other
## reaching tool in the game shows you its target (the pick has its aim box, the builder its ghost); the
## one tool whose whole job is distance had nothing, so using it well meant memorising a radius.
##
## Drawn quietly on purpose: a thin dotted lead and a small ring, nothing that competes with the ore glint
## or the crack overlay. And drawn ONLY when the line is stowed — once you are on the rope your attention
## belongs on the arc, and a second line racing your cursor across the rock is noise at exactly the moment
## you can least afford it.
const AIM_DOTS: int = 11
const AIM_RING: float = 6.0
const AIM_LEAD := Color(0.86, 0.80, 0.62, 0.34)
const AIM_MARK := Color(0.99, 0.88, 0.56, 0.88)
const AIM_MISS := Color(0.62, 0.64, 0.70, 0.16)   ## nothing in range: the lead fades out and there is no ring
const AIM_SHADE := Color(0.06, 0.05, 0.04, 0.55)  ## a dark backing ring, so the mark survives pale rock too


func _draw_aim_ghost() -> void:
	if player == null or player.grapple.live() or sim == null:
		return
	var from: Vector2 = player.hand()
	var shot: Dictionary = player.grapple.trace(sim, from, get_global_mouse_position())
	var to: Vector2 = shot["at"]
	var hit: bool = shot["hit"]
	# A dotted lead rather than a solid one: a solid line reads as a rope that is already there.
	for i: int in AIM_DOTS:
		var t0: float = float(i) / float(AIM_DOTS)
		var t1: float = t0 + 0.5 / float(AIM_DOTS)
		var fade: float = 1.0 if hit else 1.0 - t0            # out of range, the throw trails off into nothing
		draw_line(from.lerp(to, t0), from.lerp(to, t1),
			(AIM_LEAD if hit else AIM_MISS) * Color(1, 1, 1, fade), 1.0)
	if hit:
		draw_arc(to, AIM_RING, 0.0, TAU, 16, AIM_SHADE, 3.0)
		draw_arc(to, AIM_RING, 0.0, TAU, 16, AIM_MARK, 1.5)
		draw_arc(to, AIM_RING * 0.30, 0.0, TAU, 8, AIM_MARK, 1.5)


func _draw_grapple() -> void:
	_draw_aim_ghost()
	if player == null or not player.grapple.live():
		return
	var g: Grapple = player.grapple
	var from: Vector2 = player.hand()
	# A CHAINED throw draws both: the line still carrying you, and the hook already on its way to the next
	# one. Seeing them overlap for those few frames is the clearest possible statement of what chaining
	# does — you never let go of anything.
	if g.state == Grapple.State.ANCHORED:
		# A WRAPPED line is drawn as what it is: bar-taut around every corner it has caught on, and hanging
		# only on the last segment. Drawing the whole thing as one chord to the hook would put rope straight
		# through the rock it is wrapped around, which is precisely the lie the wrap exists to end.
		var at: Vector2 = g.anchor
		for pivot: Vector2 in g.pivots:
			_draw_cord(at, pivot, 0.0)
			at = pivot
		_draw_cord(from, at, g.slack(from) * ROPE_SAG)
		# The piton belongs at the HOOK and nowhere else, pointed back down the first span of line.
		_draw_hook(g.pivots[0] if not g.pivots.is_empty() else from, g.anchor, 0.0)
	if g.throwing():
		_draw_rope(from, g.tip, 0.0)


## One line, bowed by `sag`, with its hook on the end.
func _draw_rope(from: Vector2, to: Vector2, sag: float) -> void:
	_draw_cord(from, to, sag)
	_draw_hook(from, to, sag)


## Just the CORD — no hook. Split out because a wrapped line is several spans and only ONE of them ends at
## the hook; drawing the whole polyline with _draw_rope sprouted a piton at every corner it caught on.
func _draw_cord(from: Vector2, to: Vector2, sag: float) -> void:
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

## The hook: a wedge biting INTO the rock, oriented along the line's last segment so it always looks planted.
func _draw_hook(from: Vector2, to: Vector2, sag: float) -> void:
	var pts := PackedVector2Array()
	for i: int in ROPE_SEGMENTS + 1:
		var t: float = float(i) / float(ROPE_SEGMENTS)
		var p: Vector2 = from.lerp(to, t)
		p.y += sin(t * PI) * sag
		pts.append(p)
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
## MASS OCCLUDES (#S6) — the last reason a dug room did not read as a room.
##
## The veil's light level was a pure function of ROW: every cell at a given depth got the same light,
## whether it was open air or the middle of a hundred tonnes of rock. So a 13x7 chamber cut into the
## deep printed at the same value as the mass around it — measured, the room's back wall came out at
## luma 0.148 against 0.127 for the surrounding stone, a sixteen-percent difference no eye reads as
## SPACE. Every other depth cue in the renderer (the recessed wall plane, its cast shadows, the carved
## edges, the second-plane hue shift) was fighting a lighting model that flatly contradicted it.
##
## Light does not travel through stone. Openness is measured as a field — 1 in air, 0 in rock — and
## smoothed with a separable box blur, so light bleeds a couple of cells INTO the mass from any opening
## instead of stopping at a hard line. Solid cells are then dimmed by how buried they are: a rock face
## on the edge of a chamber keeps nearly all its light, and rock with nothing but rock around it loses
## MASS_SHADE of it. Open cells are never touched — the veil's own row-based level already describes
## them, and the lamp still cuts straight through all of it, so shining a light on buried rock reveals
## it exactly as before.
##
## Cost: the field is floats in flat arrays, not Dictionary probes, and the blur is separable, so the
## whole term is four linear passes over 7.7k cells inside a bake that already ran on terrain change.
## check_dig_hitch holds.
## WHY 0.55 AND NOT 0.46. Deep buried mass sits at openness≈0 with `key`≈0 (rock above it and rock below
## it, so the vertical gradient is flat), which puts it at exactly `1 - MASS_SHADE` while an open cell sits
## at 1.0. The open-vs-buried contrast is therefore capped at `1/(1 - MASS_SHADE)` BY CONSTRUCTION, and the
## KEY cannot raise it — the KEY brightens up-facing FACES, which is a different cell than the one this
## ratio is about. At 0.46 that cap is 1.85x, and `check_room_reads` has demanded 2.0x since the day it was
## written: a floor above the model's structural maximum, unreachable by construction.
##
## It passed anyway, for three years of commits, because it sampled ONE cell and that cell's material tone
## rode along with the lighting — a dark-toned stone read 39 where the lighting alone predicts 46, and
## 86/39 = 2.21x looked like headroom. Taking the median over the buried block (which is what the light
## actually does to the mass, with the per-material tone lottery averaged out) reports 1.87x, and 86 x 0.54
## = 46.4 confirms it is the model and not the measurement.
##
## So the floor was right about what the game needs and the renderer was not delivering it. 0.55 makes the
## cap 2.22x, which clears 2.0 with room for material spread instead of depending on it. This is the
## legibility complaint a blind first-time player filed as "I cannot reliably tell solid rock from empty
## air", with a number attached to it at last.
const MASS_SHADE: float = 0.55       ## light a fully-buried cell loses vs. one at an opening
const MASS_REACH: int = 2            ## cells light bleeds into the mass (the blur radius)
const KEY_STRENGTH: float = 0.30     ## brightening of a fully up-facing mass (and dimming of an overhang)
const KEY_GAIN: float = 3.0          ## how fast the vertical openness gradient saturates the key
var _open_field: PackedFloat32Array = PackedFloat32Array()
var _open_blur: PackedFloat32Array = PackedFloat32Array()
## #S14: raw solidity, kept SEPARATE and persistent. The vertical blur below writes its result back into
## `_open_field`, destroying the raw values it was built from — harmless when every column is rebuilt every
## time, fatal once a bake covers only a band, because the horizontal blur of a band column reads raw
## solidity from columns OUTSIDE it. Those columns are unchanged and cached; they just have to still hold
## what they are supposed to hold.
var _open_raw: PackedFloat32Array = PackedFloat32Array()


## #S14: `dug_from`..`dug_to` are the columns whose terrain changed. A dig changes light only near itself
## and only down its own columns — the surface line it may have moved, and the openness of its neighbours —
## so the whole 16,384-cell field never needed rebuilding for it. Measured at 13ms per dig before this,
## which was the second-largest piece of a mining hitch after the terrain bake itself.
##
## The daylight clock is the case that genuinely IS global: every row's sky level moves at once. That path
## passes the whole world and pays the full cost, a few times a day rather than a few times a second.
func _bake_veil_base(dug_from: int = 0, dug_to: int = FactorySim.GRID_COLS - 1) -> void:
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	if _veil_base.size() != cols * rows * 4:
		_veil_base.resize(cols * rows * 4)
		dug_from = 0
		dug_to = cols - 1
	var band: Vector2i = _bake_openness(cols, rows, dug_from, dug_to)
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
	# A/B SWITCH, and it stays. check_rock_reads varies 53-63% run to run on identical code -- the delve
	# lands in a slightly different place each time -- so a single before-number and a single after-number
	# cannot tell a real change from the spread, and that is exactly the mistake this switch exists to stop
	# anyone repeating. With it, the same build measures both arms, three runs each, and the comparison is
	# between two distributions instead of two anecdotes. It also keeps the fix FALSIFIABLE: a constant you
	# can turn off is a claim you can test.
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
				# UNLIT NOTHING IS ABSENCE, AND ABSENCE IS THE DARKEST THING DOWN HERE. See VOID_FLOOR.
				#
				# `and not wall`, because a cell with nothing in it is TWO different objects and the first
				# version of this treated them as one. A natural void was never filled and has no backing;
				# a CARVED ROOM is space someone opened, and the wall behind it is a surface that survived
				# the digging. Flooring both to near-black made a chamber read 0.79x DARKER than the buried
				# mass around it and turned check_room_reads red — correctly, because the whole claim of
				# that layer is that carved space announces itself as carved. A room you dug going darker
				# than the rock you dug it out of is the inversion I just fixed, pointed the other way.
				#
				# This is the distinction the renderer already draws everywhere else — `_draw_background`
				# paints walled cells and only walled cells — so the term was in the vocabulary and this
				# code was the one place not using it.
				r = void_r
				g = void_g
				b = void_b
			# Clamped, because the key term can push a strongly up-facing cell ABOVE its row's own light
			# level and a byte does not say so — it wraps, and a lit ledge prints as a dark one.
			var lit: float = _open_blur[row * cols + col]
			_veil_base[i] = mini(255, int(float(r) * lit))
			_veil_base[i + 1] = mini(255, int(float(g) * lit))
			_veil_base[i + 2] = mini(255, int(float(b) * lit))
			_veil_base[i + 3] = 255


## Build the per-cell "how much light can reach in here" multiplier used by _bake_veil_base. Four linear
## passes: solidity, a horizontal blur, a vertical blur, then the multiplier. The blur is what makes an
## opening bleed light into the rock around it rather than ending at a hard black line — without it the
## row under a flat surface would drop straight to buried-dark and the ground would read as a painted
## band rather than as earth you are looking into the top of.
## `dug_from`..`dug_to` are the columns whose SOLIDITY changed. Everything downstream of them changes over
## a wider band — the horizontal blur reaches MASS_REACH either side — so the function widens the range
## itself and returns the band it actually refreshed, which is what the caller must then re-compose.
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
	# Open cells keep their full row-based light; solid ones are dimmed by how buried they are. The
	# blurred openness is already 0..1, and a cell touching air lands high enough in it that a rock FACE
	# — the thing you actually look at when you look at a wall — barely dims at all.
	#
	# ...and then the KEY (#S8). How buried a cell is says how much light reaches it; it says nothing about
	# which way its mass faces, so a floor and a ceiling at the same burial depth came out at the same
	# brightness, and a cavern read as a dark patch rather than as a space with a lit floor and a shadowed
	# roof. The VERTICAL GRADIENT of the openness field is exactly that missing information: it is positive
	# where the air is above (an up-facing surface) and negative where the air is below (an overhang), and
	# it is already smooth because the field was blurred, so it shades as a gradient rather than banding.
	# Light in a mine comes down, so up-facing mass gains and down-facing mass loses.
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


## Darkness (0 = full light, AMBIENT_DARK = the deep's gloom) → the multiplier the veil applies there.
## Full light is white, i.e. the world untouched; full gloom is AMBIENT_LIGHT, a cool near-dark, so
## shadow both dims and cools in one operation the way real skylight-only ambient does.
## IS THERE GENUINELY NOTHING HERE — the predicate VOID_FLOOR needs, written once because I got it wrong
## twice by reaching for one that already existed.
##
## `not is_solid` looked like "this cell is empty" and is not. It is COLLISION's question, and it has been
## answering that question correctly for years: it means "a body may pass through here". Three different
## things pass that test and only one of them is nothing.
##
##   a CARVED ROOM has a wall behind it — space someone opened, and the backing survived the digging.
##     Flooring it made a chamber read 0.79x darker than the mass it was cut from (check_room_reads).
##   a FLOODED CELL has water in it — a surface with a colour and a depth ramp of its own. Flooring it put
##     the floor of a pool 23.4 levels LIGHTER than its surface, inverting the depth cue (check_water_reads).
##   a TRUE VOID is the only one that is absence, and the only one that should go black.
##
## Both breaks were the same mistake and I shipped the second one in the fix for the first. The lesson is
## not "check more conditions": it is that a predicate borrowed from another subsystem carries THAT
## subsystem's question. This one is written here, in the renderer, in terms of what the renderer means.
func _is_true_void(c: Vector2i) -> bool:
	return not sim.is_solid(c) and not sim.wall.has(c) and not sim.water.has(c)


func _light_level(darkness: float) -> Color:
	return Color.WHITE.lerp(AMBIENT_LIGHT, clampf(darkness / AMBIENT_DARK, 0.0, 1.0))


## A source's own colour → the colour its light REVEALS rock in. A lamp is amber but it is still bright,
## so a full-strength pool must reach near-white or it would darken the channels its tint is weakest in
## (a saturated teal lift would print a teal-and-black hole instead of lighting the rock). LIGHT_TINT is
## how much of the source's hue survives that lift: enough to read as amber/teal at a glance, never
## enough to strangle a channel. This is why warm lamp + cool crystal reads as colour contrast in stone
## rather than as two coloured stickers.
const LIGHT_TINT: float = 0.28
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
		_veil_cols_dirty = false
		_bake_veil_base()
	elif _veil_cols_dirty:
		_veil_cols_dirty = false
		_bake_veil_base(maxi(_veil_col_min, 0), mini(_veil_col_max, FactorySim.GRID_COLS - 1))
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
		# HOW MUCH OF THE FRAME YOU CAN SEE (#S5). The camera shows 40x22 cells. A 5.4-cell reveal lights
		# roughly a tenth of that, so the underground was played through a keyhole: whatever the terrain
		# passes put into the world — rifts, ledges, spires, a colour arc across the layers — the player
		# met one lamp-width of it at a time and the other nine tenths of every frame was black.
		#
		# "Bring your own light" is a real pillar and it survives this: the pool still falls off hard, the
		# deep outside it is still genuinely dark, and torches and machines still buy you territory that
		# stays lit when you leave. What changes is that the lamp shows you the ROOM you are standing in
		# rather than the arm's length in front of you — which is the difference between exploring a cave
		# and feeling around one. The throat and body pools widen with it so the beam keeps its shape.
		_veil_cut(bytes, head + _lamp_offset, 9.0, 0.99, lamp_lit)         # aimed beam — wide reveal, open core
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
			_veil_cut(bytes, mpos, 2.8, s, _light_tint(Visuals.machine_color(machine.def)))
	for cell: Variant in sim.torch:
		var tpos: Vector2 = _cell_center(cell as Vector2i)
		if cull.has_point(tpos):
			# Two cuts, same shape as the head-lamp: a wide soft glow that makes the ROOM habitable and
			# a hot core at the flame. One quadratic pool alone put a 2-cell bright disc on the wall and
			# left the rest of a hung chamber black — which is not what a torch in a room looks like, and
			# it is the reason lighting a space felt like decorating it rather than claiming it.
			_veil_cut(bytes, tpos, 7.6, 0.52, _light_tint(TORCH_LIGHT))
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
				+ sin(float(col) * 4.1 - float(row) * 3.7) * 0.38) * 0.13 * window
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
		if SILHOUETTE_ONLY:
			continue          # a body's shape is not its glow (see the flag's note)
		var kind: String = Visuals.machine_kind(machine.def)
		# Saturated cores (diffs 2, 9): each machine's pool blazes in its OWN colour out of the black — a
		# hot orange forge, an amber burner, a cyan-teal lift — the coloured-pools-on-black Noita read.
		var col: Color = Color(1.0, 0.46, 0.16)            # furnace ember (hot saturated orange)
		var pulse: float = 0.7 + 0.12 * sin(_anim_time * 3.0 + float(machine.cell.x))  # a sign of life
		# A COLD/idle machine barely glows — it blazes only while it is doing its job. The rule reads
		# truthfully in one direction only: **light = working.**
		#
		# THIS WAS A FURNACE-ONLY RULE AND THE EXCEPTION WAS WRITTEN DOWN AS A FEATURE. The line read
		# `if kind == "furnace" and not _machine_active(machine)`, with the parenthetical *"(Non-furnace
		# runners keep their steady casing glow.)"* — so a stopped drill, hopper, splitter, crusher, borer,
		# press, mill and pump each lit the rock around them exactly as brightly as a running one. That is
		# `PC-05`'s evidence line word for word: *"labels/pointers carry state because hardware does not."*
		# The hardware was not merely silent about its state, it was **asserting the wrong one**, and the
		# phrasing turned a defect into a design note nobody would think to question.
		#
		# MEASURED with the name label, held badge and status lamp suppressed (`check_machine_state`): a
		# working Drill and a stopped Drill differed by **~14 levels of luma against a ~7-level animation
		# baseline** — a still frame of each was the same picture with the bit at a different angle. The
		# Forge, whose pool was already gated, differed by 92. **The gate was the entire difference between
		# them**; the casings, the glyphs and the two machines' art were never the variable.
		#
		# The generator keeps its own harder gate below (`fuel > 0` → pool off entirely, not dimmed): a
		# burner with no coal is not idling, it is out.
		if not _machine_active(machine):
			pulse *= IDLE_GLOW
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
	# The same cull the item bodies get (FallingItems.draw). A glow is one textured quad, but there can be
	# MAX_ITEMS=240 of them and its radius is a single cell — so a mote more than two cells outside the view
	# cannot put a pixel on screen, and the whole pour of a factory running somewhere you are not was being
	# painted into the light layer every frame.
	var mote_view: Rect2 = _view_world_rect(2.0)
	for m: Dictionary in falling.motes():
		# Dropped/falling items GLOW (the gravity-pour visual), but a dropped STACK overlaps many motes into
		# a "mini sun" (playtest). Dimmer + tighter per mote so a stream reads warm without blowing out.
		if not mote_view.has_point(m["pos"]):
			continue
		_draw_glow(layer, m["pos"], float(CELL) * 1.0, m["color"], 0.38)
	# WATER SELF-SHEEN (L3 legibility): each on-screen water cell adds a FAINT cool bloom so a flooded
	# pocket reads as a dim blue presence in the near-black deep — you can perceive the flood hazard before
	# a lamp reaches it. Deliberately weak (WATER_SHEEN_BASE + level-scaled), well under a torch/crystal/
	# lamp, so lit + shallow water looks essentially unchanged and it never reads as a light source or lava.
	# View-culled like the passes above; scaled modestly by water level (a full cell glows a touch more).
	# Drawn on the body's SKIN, not cell by cell. A glow of radius 1.15 cells at every cell centre puts one
	# disc per cell in a square grid: adjacent discs touch without merging, so a wide aquifer came out as
	# visible polka dots — the loudest thing in frame once the fill itself stopped being a flat slab. Only
	# the cells at the top or the sides of the body glow now, over a radius wide enough that neighbours
	# actually blend, which is both cheaper on a deep pool and closer to what dim water does: the light
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
			# A faint slow shimmer so the pool reads as live water, not a painted disc — tiny amplitude.
			var wshim: float = 0.9 + 0.1 * sin(_anim_time * 1.8 + float(wc.x) * 0.6 + float(wc.y) * 0.4)
			_draw_glow(layer, _cell_center(wc), float(CELL) * WATER_SHEEN_RADIUS, WATER_SHEEN,
				wintensity * wshim)


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
