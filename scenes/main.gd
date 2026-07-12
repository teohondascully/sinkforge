class_name MainView
extends Node2D

## The CONTROLLER + session root. OWNS a FactorySim (game-session-owns-sim rule, docs/RISKS.md),
## advances it, hosts the embodied Player + follow Camera2D, and translates mouse/keys into the
## player's reach-gated WORLD VERBS (try_mine / try_deposit / try_build / try_craft). It only READS
## sim production state — every edit goes through the sim's discrete API. It does NOT draw: a child
## WorldRenderer is the VIEW (it reads the sim + the aim state we push it each frame); FallingItems is
## the cosmetic drop layer. Delete the view/player and the production numbers are identical.
##
## The loop you drive: DIG solid earth (LMB, reach-limited) → mine ore veins into your pack → DROP ore
## (Q) above a Processor "forge" so gravity feeds it in → craft machines from ingots in the E screen →
## BUILD the chain (RMB place / pick-up) → the Lift hauls goods + you UP. Controls: 1–8 select, wheel
## cycles, Q drop, E crafting, M map, H help. See docs/; combat/worldgen/power are still ahead.
##
## DESIGN-OPEN (placeholder): world size/layout, camera feel, the body's look, mining feel/reach, all
## numbers, art style — collected for PLAYTEST_NOTES once felt.

const CELL: int = 32
const REACH_CELLS: float = 3.2     ## how far the body can mine/deposit from its centre
const SAVE_PATH: String = "user://sinkforge.save"   ## the F5/F9 quicksave slot (SaveGame envelope)
const WORLD_SIZE := Vector2(FactorySim.GRID_COLS * CELL, FactorySim.GRID_ROWS * CELL)
## Zoom levels cycled by Z (Terraria-style). Default is zoomed OUT so you see the world you're working in,
## not just your feet. Smaller = further out. _current_zoom() reads the active level everywhere.
const ZOOM_LEVELS: Array[float] = [0.42, 0.6, 0.85]
var _zoom_idx: int = 0
const WORLD_SEED: int = 1337       ## fixed gen seed (provisional; expose to a new-game UI later)
## Materials the player can PLACE as blocks from the pack (the Terraria build primitive). Wood = the
## bazaar build material; the list grows as more buildables land (log/stone/etc).
const BUILD_MATERIALS: Array[StringName] = [&"wood", &"earth", &"stone", &"deepslate"]
## How close (chebyshev cells, around a bazaar's centre) you must stand to craft machines — the Bazaar is
## the crafting hub (Minecraft crafting-table proximity). Away from it, the E screen shows the pack only.
const BAZAAR_RADIUS: int = 3
## Dev: start with a stocked pack (ore/ingots/machines) for testing. OFF by default — a new game now
## begins REALISTICALLY (an empty pack but for the two starter tools), so the painful by-hand bootstrap
## that motivates automation is the actual first experience. Flip on for quick build/automation testing.
static var dev_start: bool = false

var sim: FactorySim
var _player: Player
var _camera: Camera2D
var _renderer: WorldRenderer       ## the VIEW: all world-space drawing + lighting (we push it aim state)
var _hud: Hud                      ## screen-space HUD (we push it objectives + the machine inspector)
var _paused: bool = false
## On-demand UI state (the calm-screen model): the crafting screen (E), the map (M), and the controls
## help (H/?) are summoned, not permanent. Pushed to the HUD each frame so it knows what to draw.
var _inventory_open: bool = false   ## E opens the PACK (Minecraft-style); crafting lives inside it, but
                                    ## machine-crafting is GATED on standing near a claimed Bazaar (docs/CRAFTING.md)
var _show_minimap: bool = false
var _show_help: bool = false
## Fast-forward game clock: "." cycles Engine.time_scale through this exponential ladder so the whole
## game (sim ticks AND the body) runs faster — watch a factory fill, or (headless) speed up play-tests.
## The body integrates in substeps (Player.MAX_SUBSTEP) so it can't tunnel at the high multipliers.
const TIME_SCALES: Array[float] = [1.0, 2.0, 4.0, 8.0]
var _time_scale_idx: int = 0
## Timed-mining (the friction): holding LMB CHARGES the aimed cell; it breaks when the charge reaches the
## material's hardness (scaled by your best tool's speed). _mine_target tracks which cell is charging so
## moving the cursor to a new block resets it. The charge fraction is pushed to the renderer (crack viz).
var _mine_target: Vector2i = Vector2i(-999, -999)
var _mine_charge: float = 0.0
var _aim: Vector2i = Vector2i(-99, -99)
## The machines you can CRAFT (1/2 keys → craft one into the pack, spending ingots). The ore_vent (a
## SOURCE) is deliberately absent — you remain the ore source by hand (manual→automated pillar; see
## DECISIONS 2026-06-27). `_machine_defs_by_id` resolves a carried hotbar item back to its def so a
## selected machine item can be placed.
var _craftable: Array[MachineDef] = []
var _machine_defs_by_id: Dictionary = {}
## Craftable TOOLS (id + display name; cost lives in MiningRules.TOOL_RECIPES) shown in the Bazaar craft
## screen after the machines. The Stone Pickaxe is the first depth-unlocking upgrade (docs/MINING.md).
const CRAFT_TOOLS: Array[Dictionary] = [
	{"id": &"stone_pickaxe", "name": "Stone Pickaxe"},
]
## Which carried-item slot is active in the inventory hotbar (mouse-wheel cycles it). The selected
## item is what E deposits (a resource) or RMB places (a machine) — the unified Factorio-style hotbar.
var _inv_selected: int = 0
## Cosmetic falling-product layer (driven by the sim's flow_events, never feeds back). Its own module.
var _falling := FallingItems.new()
## Bazaar view: detects completed wood frames (sim.find_bazaars) and plays the block-by-block transform
## into a decorated stall + shopkeeper. Representation-only; never writes the sim (docs/CRAFTING.md).
var _bazaars := Bazaars.new()
## Cosmetic particle + screenshake juice (dig/land/place/collect). Pure representation.
var _particles := Particles.new()
var _shake: float = 0.0            ## current screenshake magnitude (px), decays each frame
var _step_dist: float = 0.0       ## accumulated walk distance, for periodic footstep dust
const SWING_PERIOD: float = 0.28   ## seconds between pick-blows while charge-mining (the swing cadence)
var _swing_clock: float = SWING_PERIOD  ## primed so a fresh charge's first blow lands instantly
## The tutorial chain (representation-layer legibility — the "how do I play?" signpost). Reads the sim.
var _objectives: Objectives
## GPU ambient dust motes (docs/MODERN_FEEL.md) — a continuous GPUParticles2D haze that drifts in the
## air and catches the lamp light. Pure atmosphere; follows the camera each frame.
var _motes: GPUParticles2D
## Procedural audio (FABLE_50 #8) — synthesized SFX + the factory hum. Poked from the same verb hooks
## that fire particles; never touches the sim.
var _sfx: Sfx


func _ready() -> void:
	Controls.register()    # register the remappable InputMap actions (foundation for a settings page)
	sim = FactorySim.new()
	_craftable = [
		load("res://src/data/machines/processor.tres"),
		load("res://src/data/machines/splitter.tres"),
		load("res://src/data/machines/lift.tres"),
		load("res://src/data/machines/drill.tres"),  # automates ore extraction (docs/MINING.md)
		load("res://src/data/machines/hopper.tres"),  # stockpiles + meters gravity-fed output (the 'chest')
		load("res://src/data/machines/generator.tres"),  # burns coal → power (docs/POWER.md)
		load("res://src/data/machines/conduit.tres"),     # carries power down+lateral (docs/POWER.md)
		load("res://src/data/machines/rope.tres"),        # the placeable climb — unrolls down a shaft
		load("res://src/data/machines/torch.tres"),       # placeable LIGHT — claimed territory in the black
		load("res://src/data/machines/descent_engine.tres"),  # the L1→L2 gate-breacher (docs/PROGRESSION.md)
		# The L2 crafter modules (docs/CRAFTING.md — per-item, gravity-fed): the iron chain.
		load("res://src/data/machines/iron_forge.tres"),
		load("res://src/data/machines/plate_press.tres"),
		load("res://src/data/machines/gear_mill.tres"),
		load("res://src/data/machines/h_drill.tres"),     # the Borer — sideways extraction (FABLE_50 #46)
	]
	for def: MachineDef in _craftable:
		_machine_defs_by_id[def.id] = def
	_seed_world()

	_sfx = Sfx.new()
	add_child(_sfx)

	_player = Player.new()
	_player.sim = sim
	_player.position = _cell_center(Vector2i(SPAWN_COL, SURFACE - 2))  # just above the centred plateau (falls onto it)
	_player.z_index = 60  # above the light layers (50/51) so the miner stays crisp inside his lamp pool
	add_child(_player)

	_camera = Camera2D.new()
	# Zoom: 0.7 frames the body as a readable character while keeping enough world to see a vertical
	# chain (provisional — tuned by eye, see tools/capture_zoom.gd). Smaller = further out.
	_camera.zoom = Vector2(_current_zoom(), _current_zoom())
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	# CENTERED on the body — no dead-zone. The avatar is the player's anchor and must always be the
	# focal point; the old drag margins let it drift into a screen corner (and under the HUD), which read
	# as "I can't find my character". Position smoothing alone eases the follow so motion stays soft.
	_camera.drag_horizontal_enabled = false
	_camera.drag_vertical_enabled = false
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(WORLD_SIZE.x)
	_camera.limit_bottom = int(WORLD_SIZE.y)
	_player.add_child(_camera)
	_camera.make_current()

	var layer := CanvasLayer.new()
	layer.layer = 10  # above the screen-FX lens pass (layer 5) so the HUD stays crisp, un-vignetted
	var hud := Hud.new()
	hud.sim = sim
	hud.paused_getter = func() -> bool: return _paused
	var craft_opts: Array[Dictionary] = []
	var craft_ids: Array[StringName] = []
	var machine_icons: Dictionary = {}
	for def: MachineDef in _craftable:
		craft_opts.append({"name": def.display_name, "cost": def.craft_cost})
		craft_ids.append(def.id)
		machine_icons[def.id] = {"color": Visuals.machine_color(def), "kind": Visuals.machine_kind(def), "name": def.display_name}
	# Craftable TOOLS listed AFTER machines (the Bazaar crafts both — docs/MINING.md). Not placeable, so
	# they're not in machine_icons (the craft panel renders them via their item glyph instead).
	for t: Dictionary in CRAFT_TOOLS:
		var tid: StringName = t["id"]
		craft_opts.append({"name": t["name"], "cost": MiningRules.TOOL_RECIPES.get(tid, {})})
		craft_ids.append(tid)
	hud.craft_options = craft_opts
	hud.craft_ids = craft_ids
	hud.machine_icons = machine_icons
	hud.inv_selected_getter = func() -> int: return _inv_selected
	# Tutorial chain — built AFTER the world is seeded (so its baseline includes any dev-start kit) and
	# handed to the HUD to render. It only reads the sim; MainView refreshes it each frame.
	_objectives = Objectives.new(sim)
	hud.objectives = _objectives
	_hud = hud
	layer.add_child(hud)
	add_child(layer)

	# The VIEW: a WorldRenderer draws all world-space sim state (terrain, machines, ground, falling
	# items, lighting). It reads the sim + the aim state we push each frame; it never mutates anything.
	# Its draw sits at z 0 and its lighting at z 50/51, so the player (z 60) stays crisp on top.
	_renderer = WorldRenderer.new()
	_renderer.setup(sim, _falling, _player)
	_renderer.particles = _particles
	_renderer.bazaars = _bazaars
	add_child(_renderer)

	# Hand the HUD minimap a material-colour lookup (the renderer owns the MaterialDef registry) so the
	# map can paint terrain without the HUD depending on the renderer's internals.
	hud.minimap_color = _renderer.material_color

	_setup_post_fx()


## Modern-rendering layer (docs/MODERN_FEEL.md): a WorldEnvironment post-process that gives the scene
## its "2026 sheen" — BLOOM on our additive light pools (head-lamp, ore stream, machine glow, forge
## embers) so warm light blooms into the dark, plus a gentle colour grade (a touch more contrast +
## saturation). HDR-2D lets the additive pools exceed 1.0 so only genuine light blooms, not flat UI.
## Pure representation — the sim never knows. Vignette + film grain ride on a separate screen shader.
func _setup_post_fx() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.28
	env.glow_strength = 0.85
	env.glow_bloom = 0.0                   # no whole-image lift — halo only the already-bright pixels
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT  # gloss, not a wash-out add
	env.glow_hdr_threshold = 0.85         # bloom the bright cores (lamp/ember/ore/cursor), leave dark dark
	env.glow_hdr_scale = 1.0
	# Favour the tighter bloom levels so light "halos" close to its source instead of ballooning into a
	# giant soft orb that swallows readability.
	for i: int in range(0, 7):
		env.set_glow_level(i, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.7)
	env.set_glow_level(3, 0.3)
	env.adjustment_enabled = true          # gentle grade — keep the readability floor (Terraria never
	env.adjustment_contrast = 1.03         # sacrifices legibility), just a touch more pop + warmth
	env.adjustment_saturation = 1.07
	env.adjustment_brightness = 1.02
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_setup_ambient_motes()

	# The screen-space LENS pass — vignette + film grain + a whisper of chromatic aberration, on a
	# full-screen ColorRect on a CanvasLayer BELOW the HUD (layer 5 < HUD's 10), so the WORLD gets the
	# lens and the UI stays crisp. Reads the composited screen; sits under the WorldEnvironment glow.
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 5
	var lens := ColorRect.new()
	lens.material = ShaderMaterial.new()
	(lens.material as ShaderMaterial).shader = load("res://scenes/post_fx.gdshader")
	lens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(lens)
	add_child(fx_layer)


## A continuous GPUParticles2D haze of dust motes drifting in the air — the modern particle lever
## (docs/MODERN_FEEL.md). It fills the camera view (repositioned to the camera each frame) and sits at
## z 45, BELOW the lighting veil (z 50) + light pools (z 51), so a mote is dark in the gloom and lit
## warm where the lamp/glow reaches — "dust catching the light." Pure atmosphere; never touches the sim.
func _setup_ambient_motes() -> void:
	var view: Vector2 = Vector2(Hud.CANVAS) / _current_zoom()    # world area the camera shows
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(view.x * 0.6, view.y * 0.6, 1.0)  # a touch wider than the view
	mat.direction = Vector3(0.2, 1.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3(0.0, 5.0, 0.0)                     # a barely-there settle
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 11.0
	mat.damping_min = 1.0
	mat.damping_max = 4.0
	mat.scale_min = 0.5
	mat.scale_max = 1.7
	mat.color = Color(1.0, 0.94, 0.82, 0.20)                 # warm dust, faint (was 0.40 — fogged the screen)
	mat.turbulence_enabled = true                            # organic, swirling drift
	mat.turbulence_noise_strength = 4.0
	mat.turbulence_noise_scale = 1.4
	_motes = GPUParticles2D.new()
	_motes.process_material = mat
	_motes.texture = _make_mote_texture()
	_motes.amount = 55                                       # halved+ : atmosphere, not a snowstorm
	_motes.lifetime = 7.0
	_motes.preprocess = 5.0                                  # start with a full field, not an empty screen
	_motes.z_index = 45
	_motes.z_as_relative = false
	add_child(_motes)


## A tiny soft round dot for a single mote (radial alpha falloff) so motes read as out-of-focus specks
## of dust rather than hard pixels.
func _make_mote_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 12
	t.height = 12
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


## Build the starting world through the world-engine handshake (docs/WORLDGEN.md): a swappable
## WorldGen produces a WorldData (two material grids); the sim ingests it. MainView no longer knows
## HOW the world is made — swap the generator and nothing here changes. Then stamp the Rung-1 fixtures:
## a starter ORE vein beside spawn, and the MINESHAFT — a shallow carved shaft over a rich vein with a
## FORGE already in its mouth. You hand-feed that forge to bootstrap, then cap it with a Drill so it
## feeds itself: the forge is constant; you automate the FEEDING you were doing by hand.
## The flat spawn surface row — every spawn-side fixture (mineshaft, vein, tree, forge) is placed relative
## to it, so pushing the surface down for sky moves them all together. Mirrors HeightmapWorldGen's constant.
const SURFACE := HeightmapWorldGen.FLAT_SURFACE_ROW
## The spawn cluster is laid out on the map-centred plateau, left→right, so nothing ever traps the body:
##   BAZAAR (cols 40-43) is a WALK-THROUGH stall (its wood frame doesn't collide — you enter the shop), on
##     the LEFT; claimed from its RIGHT post (col 44) so the finishing block faces spawn. The open SHAFT
##     (col 56) is the one real blocking endpoint, only ever reached from its left edge (col 55). Everything
##     between is benign to walk (dug vein, step-over forge, coal-on-top). The TREE (col 51) is felled for wood.
##   col 40-43 BAZAAR ruin · col 46 FORGE · cols 47-48 VEIN · col 49 SPAWN · col 51 TREE · col 54 COAL · col 56 SHAFT
const SPAWN_COL: int = 49
const MINESHAFT_COL: int = 56
const MINESHAFT_FORGE_CELL := Vector2i(46, SURFACE)                  ## bootstrap forge — a shallow SURFACE pocket (toss ore in from col 45, collect ingots below). OFF the shaft so it stays an open drop.
## REACH INVARIANT: the DRILL cell sits at SURFACE+1 (not deeper) so the body places the drill + tosses coal
## down the mouth from the surface EDGE (col 55) with a comfortable reach margin, WITHOUT entering the pit.
## Placing it deeper left only a ~4px reach margin, tipping the body into the shaft where it got trapped.
const MINESHAFT_DRILL_CELL := Vector2i(MINESHAFT_COL, SURFACE + 1)   ## OPEN cell: drop the Drill here, ABOVE the ore vein
const MINESHAFT_ORE_CELL := Vector2i(MINESHAFT_COL, SURFACE + 2)     ## the visible SOLID ore vein the drill bores down into
const AUTO_FORGE_CELL := Vector2i(MINESHAFT_COL, SURFACE + 3)        ## the AUTO line's forge — below the ore, catches the bored ore's fall
const MINESHAFT_ORE_RICHNESS: int = 400                              ## a rich starter-automation patch (hundreds) the drill runs on for a long time
func _seed_world() -> void:
	var gen: WorldGen = LayeredWorldGen.new()
	var world: WorldData = gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, WORLD_SEED)
	sim.load_world(world)
	_seed_starter_vein()
	_seed_tutorial_coal()
	_seed_tutorial_tree()
	_seed_tutorial_mineshaft()
	_seed_starter_kit()
	if dev_start:
		_dev_seed_pack()


## A visible ORE VEIN breaching the surface beside spawn — the "orange-flecked rock" the first objective
## points at, and the bootstrap ore you HAND-mine for the first ingots (depth-banded worldgen leaves the
## shallow surface near-bare, so onboarding can't rely on finding a vein). A 1-tall, 2-wide band so it READS
## as a vein yet mining it leaves only a SHALLOW (1-tile) trench you step straight out of — a 2-deep pit
## would trap the body (step-up climbs one tile). Hand-mined for the first few ore (the drill mines the deep
## veins in the mineshaft, not this surface strip).
const STARTER_VEIN_CELL := Vector2i(47, SURFACE)
func _seed_starter_vein() -> void:
	for cell: Vector2i in [Vector2i(47, SURFACE), Vector2i(48, SURFACE)]:   # just left of spawn (49), right of the forge pocket (46)
		sim.set_solid(cell, &"ore")
		sim.deposits[cell] = 200                                  # richness for the hover readout; hand-mining grabs a loose burst


## A guaranteed surface COAL block between the shaft and the bazaar — the drill's FUEL (docs/MINING.md).
## Once you cap the deposit with a drill, it won't run without coal; this is the "go mine coal" target that
## closes the demand-web. Placed at col 54 — one left of the shaft's edge (55) on the rightward path, so
## mining it then tossing coal down the open shaft (56) is a short step. Rich enough that one hand-burst
## (3-8) fuels the drill well past its deposit.
const TUTORIAL_COAL_CELLS: Array[Vector2i] = [Vector2i(54, SURFACE)]
func _seed_tutorial_coal() -> void:
	for cell: Vector2i in TUTORIAL_COAL_CELLS:
		sim.set_solid(cell, &"coal")
		sim.deposits[cell] = 200                                   # a hundreds-scale coal patch — fuels the drill for a long time


## A guaranteed TUTORIAL TREE on the surface between spawn and the shaft — the wood source the bazaar step
## needs (depth-banded worldgen plants trees out past the ruin, unreachable on the surface early). Trees are
## Terraria-style WALK-THROUGH (Player._blocked passes wood/leaves), so the trunk sitting on the tutorial
## path is fine — the body strolls through it and chops it in passing, no walling even for the taller body.
## Crowned with leaves so it reads + fells as a real tree.
const TUTORIAL_TREE_COL := 51
func _seed_tutorial_tree() -> void:
	var g: int = sim.surface_row(TUTORIAL_TREE_COL)               # ground top row (solid at g); trunk above it
	sim.set_solid(Vector2i(TUTORIAL_TREE_COL, g - 1), &"wood")    # trunk base
	sim.set_solid(Vector2i(TUTORIAL_TREE_COL, g - 2), &"wood")    # trunk top
	for leaf: Vector2i in [Vector2i(TUTORIAL_TREE_COL, g - 3), Vector2i(TUTORIAL_TREE_COL, g - 4),
			Vector2i(TUTORIAL_TREE_COL + 1, g - 3)]:
		if not sim.is_solid(leaf):
			sim.set_solid(leaf, &"leaves")                       # crown — marks it a tree, fells to wood


## The RUNG-1 stage: a shallow BOOTSTRAP forge pocket (col 46) + the DRILL SHAFT (col 56). Split into two
## columns so the shaft stays a clean OPEN drop — you toss ore/coal straight down it and gravity delivers
## to whatever's at the bottom of that column (the forge, or the drill once you place it). Layout:
##   col 46 SURFACE   BOOTSTRAP FORGE  — toss surface ore in (from col 45); ingots fall to SURFACE+1 (collect)
##   col 46 SURFACE+1 open             — bootstrap ingots land here
##   col 46 SURFACE+2 floor
##   col 56 SURFACE   open        — the OPEN shaft mouth: toss ore/coal in here; gravity delivers it below
##   col 56 SURFACE+1 ORE block   — hand-mine it → cavity + a drillable deposit; then place the DRILL here
##                                  (SURFACE+1 so it's comfortably in reach from the col-55 surface edge)
##   col 56 SURFACE+2 AUTO FORGE  — catches the drill's pulled ore → ingots, hands-free
##   col 56 SURFACE+3 open        — auto ingots land
##   col 56 SURFACE+4 rock floor
## The drill needs COAL (docs/MINING.md) — you drop coal down the open shaft onto it to run it.
func _seed_tutorial_mineshaft() -> void:
	var c: int = MINESHAFT_COL
	# Bootstrap forge pocket (col 46) — a shallow 1-deep well, OFF the drill shaft.
	var bf: int = MINESHAFT_FORGE_CELL.x
	sim.set_solid(Vector2i(bf, SURFACE), &"")                      # carve the forge cell
	sim.set_solid(Vector2i(bf, SURFACE + 1), &"")                  # ingots land / collect
	sim.set_solid(Vector2i(bf, SURFACE + 2), &"earth")            # floor
	sim.place_machine(load("res://src/data/machines/processor.tres"), MINESHAFT_FORGE_CELL)   # bootstrap forge
	# Drill shaft (col 56) — OPEN mouth + drill cell so tossed coal drops straight down onto the drill, with a
	# VISIBLE solid ore vein just below the drill cell for the drill to bore into.
	sim.set_solid(Vector2i(c, SURFACE), &"")                       # open mouth (drop access)
	sim.set_solid(MINESHAFT_DRILL_CELL, &"")                       # SURFACE+1: OPEN — the player drops the Drill here
	sim.set_solid(MINESHAFT_ORE_CELL, &"ore")                     # SURFACE+2: the visible ore vein the drill bores down into
	sim.deposits[MINESHAFT_ORE_CELL] = MINESHAFT_ORE_RICHNESS      # a hundreds-scale vein the drill runs on for a long time
	sim.set_solid(AUTO_FORGE_CELL, &"")                           # SURFACE+3: carve the cell the AUTO forge sits in
	sim.set_solid(Vector2i(c, SURFACE + 4), &"")                   # gap under the auto forge (ingots land)
	sim.set_solid(Vector2i(c, SURFACE + 5), &"earth")            # rock floor
	sim.place_machine(load("res://src/data/machines/processor.tres"), AUTO_FORGE_CELL)        # auto-line forge


## The STARTER TOOLS every new game begins with — a bad wooden pickaxe + a bad wooden axe (MiningRules
## .STARTER_TOOLS). They're the ONLY things in a fresh pack: you need the pick to grind through rock to
## ore and the axe to chop trees, and their badness (tier-1 speed) is what makes the early grind ache for
## a drill. Spawned → counted as produced so conservation holds. Always seeded (independent of dev_start).
func _seed_starter_kit() -> void:
	for tool: StringName in MiningRules.STARTER_TOOLS:
		sim.inventory[tool] = int(sim.inventory.get(tool, 0)) + 1
		sim.total_produced[tool] = int(sim.total_produced.get(tool, 0)) + 1


## Dev-testing kit: start with a stocked pack so you can immediately exercise the build/automation loop
## (place machines, feed, smelt) without first hand-mining a stack of ore. Items are SPAWNED, so they
## count as produced to keep the conservation invariant true. Flip DEV_START off for a clean playthrough.
## NOTE: the head-lamp glow and forge embers are LIGHTING effects on the miner/machines, not carryable
## items — there's nothing to put in the pack for those; they appear automatically in play.
func _dev_seed_pack() -> void:
	var kit: Dictionary = {&"ore": 20, &"ingot": 20, &"wood": 10, &"coal": 20, &"processor": 2, &"splitter": 2, &"lift": 1, &"drill": 1, &"generator": 1, &"conduit": 10}
	for item: StringName in kit:
		sim.inventory[item] = int(sim.inventory.get(item, 0)) + int(kit[item])
		sim.total_produced[item] = int(sim.total_produced.get(item, 0)) + int(kit[item])


func _process(delta: float) -> void:
	if not _paused:
		sim.advance(delta)
		_falling.spawn_from_events(sim, _cell_center)
		_falling.advance(delta)
		_collect_ground_under_player()
	_update_mining(delta)  # refreshes _aim from the mouse
	_update_bazaars(delta)
	_update_juice(delta)
	if _motes != null and _camera != null:
		_motes.position = _camera.get_screen_center_position()  # keep the haze over the view
	if _objectives != null:
		_objectives.refresh(delta)
	# Push the cursor + its computed affordances to the view (it can't derive reach/placeable itself).
	_renderer.set_aim(_aim, _can_reach(_aim), _placeable(_aim), _selected_machine_def(), _selected_build_material())
	_renderer.set_guide_targets(_guide_targets())   # pulse WHERE the current objective happens
	if _hud != null:
		_hud.hover_info = _hover_info()
		_hud.inventory_open = _inventory_open
		_hud.can_craft = _near_bazaar()         # the E screen reveals recipes only at the Bazaar
		_hud.show_minimap = _show_minimap
		_hud.show_help = _show_help
		_hud.time_scale = TIME_SCALES[_time_scale_idx]
		if _player != null:
			_hud.minimap_focus = _player.position
			_hud.minimap_view = Vector2(Hud.CANVAS) / _current_zoom()  # world area the camera shows


## Reconcile the Bazaar view against the sim's detected frames. When one COMPLETES this frame, throw a
## celebratory burst of sparks + a shake at its centre, so the cosmetic transform reads as a real event.
func _update_bazaars(delta: float) -> void:
	for origin: Vector2i in _bazaars.update(sim, delta):
		var c: Vector2 = _bazaars.center_of(origin)
		_particles.dust(c + Vector2(0.0, -CELL), Color(1.0, 0.86, 0.5), 26)
		_particles.spark(c + Vector2(0.0, -CELL), Color(0.93, 0.84, 0.60))
		_particles.pop(c + Vector2(0.0, -CELL), Color(0.30, 0.62, 0.60))
		_shake = maxf(_shake, 3.6)
		_sfx.ui(&"chime", 1.2)


## Drive the cosmetic juice: advance particles, kick dust on a hard landing + periodic footsteps, and
## decay the screenshake into the camera offset. None of this touches the sim.
func _update_juice(delta: float) -> void:
	_particles.advance(delta)
	# The factory HEARTBEAT: the hum swells with how much machinery is WORKING near you — walk away
	# and it fades; the base you built is a presence you can hear before you see it.
	if _player != null and _sfx != null:
		var working: float = 0.0
		var near_sq: float = pow(14.0 * float(CELL), 2.0)
		for m: MachineState in sim.machines:
			if _player.position.distance_squared_to(_cell_center(m.cell)) < near_sq \
					and sim.machine_status(m) == &"working":
				working += 1.0
		_sfx.set_hum(working / 5.0, delta)
	if _player != null:
		var feet: Vector2 = _player.position + Vector2(0.0, Player.HEIGHT * 0.5)
		if _player.landed_hard:
			_particles.dust(feet, Color(0.42, 0.32, 0.22), 12)
			_shake = maxf(_shake, 3.2)
			_sfx.play(&"thump", feet, 0.75, -5.0)
		# Footstep puffs while running on the ground — one every ~22px travelled.
		if _player.on_floor and absf(_player.velocity.x) > 20.0:
			_step_dist += absf(_player.velocity.x) * delta
			if _step_dist >= 22.0:
				_step_dist = 0.0
				_particles.dust(feet, Color(0.40, 0.30, 0.20), 3)
		else:
			_step_dist = 0.0
	_shake = move_toward(_shake, 0.0, delta * 24.0)
	if _camera != null:
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)) if _shake > 0.05 else Vector2.ZERO


## Terraria/Minecraft-convention controls, all via REMAPPABLE InputMap actions (see Controls): 1–8
## SELECT hotbar slots (not craft), E opens the crafting SCREEN (where the numbers craft), the wheel
## cycles the hotbar, Q drops the selected stack (gravity feeds it in), M map, H help. Feeding is DROP,
## not deposit — so E is free for the crafting screen. The numeric row stays a direct keycode (a fixed
## convention); every other binding routes through Controls so a settings page can rebind it.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(Controls.PAUSE):
		_paused = not _paused
	elif event.is_action_pressed(Controls.CRAFT):
		_inventory_open = not _inventory_open
	elif event.is_action_pressed(Controls.DROP):
		try_drop()
	elif event.is_action_pressed(Controls.MAP):
		_show_minimap = not _show_minimap
	elif event.is_action_pressed(Controls.HELP):
		_show_help = not _show_help
	elif event.is_action_pressed(Controls.CLOSE):
		_inventory_open = false
		_show_help = false
	elif event.is_action_pressed(Controls.RESEARCH) and _inventory_open:
		try_research(ResearchRules.next_tech(sim.research))   # R at the bench: research the next tech
	elif event.is_action_pressed(Controls.RESEARCH) and not _inventory_open:
		try_configure(_aim)                                   # R in the world: configure the aimed machine
	elif event.is_action_pressed(Controls.BUILD):
		try_build(_aim)
	elif event.is_action_pressed(Controls.ZOOM):
		_cycle_zoom()
	elif event.is_action_pressed(Controls.SPEED):
		_cycle_speed()
	elif event.is_action_pressed(Controls.SAVE):
		_save_game()
	elif event.is_action_pressed(Controls.LOAD):
		_load_game()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_cycle_inventory(1)   # direct wheel handling (reliable) — the hotbar scroll select
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_cycle_inventory(-1)
	elif event is InputEventKey and event.pressed and not event.echo \
			and ((event.keycode >= KEY_1 and event.keycode <= KEY_9) or event.keycode == KEY_0):
		# The fixed hotbar number row; 0 is the TENTH slot (the craft list outgrew 1-9).
		var idx: int = (event.keycode - KEY_1) if event.keycode != KEY_0 else 9
		if _inventory_open:
			if event.shift_pressed:
				idx += 10                               # SHIFT+digit = craft rows 11-20 (until the real tech panel)
			if idx < _craftable.size():
				try_craft(_craftable[idx])              # in the PACK screen, numbers CRAFT a machine (Bazaar-gated)
			elif idx < _craftable.size() + CRAFT_TOOLS.size():
				try_craft_tool(CRAFT_TOOLS[idx - _craftable.size()]["id"])   # …or a tool (same gate)
		else:
			_select_slot(idx)                           # otherwise they SELECT the hotbar slot


# --- world-interaction tools (mining / depositing): discrete sim edits only ---

## Timed mining: holding LMB CHARGES the aimed block (time scaled by your best tool vs the rock's
## hardness — docs/MINING.md). The block only breaks when the charge fills, so early hand-mining is a
## deliberate grind (the friction that sells automation). The charge fraction drives the crack overlay.
## (The wall-clock timing lives HERE; the tool-GATE lives in try_mine, the verb the play-harness drives.)
func _update_mining(delta: float) -> void:
	_aim = _effective_aim(get_global_mouse_position())
	# The charge/crack animation runs ONLY on a cell you can actually break — the SAME _mineable predicate
	# try_mine enforces (solid + in reach + LINE OF SIGHT). Without the LOS term the cracks would spider a
	# full charge, try_mine would refuse (no clear path), and it'd loop forever — reading as a bug. If the
	# aim is a block behind rock, _effective_aim already snaps to the nearest EXPOSED face toward the cursor,
	# so you dig the PATH toward a buried target; when no reachable face exists, nothing animates (no phantom).
	var holding: bool = not _paused and Input.is_action_pressed(Controls.MINE) and _mineable(_aim)
	if not holding:
		_mine_target = Vector2i(-999, -999)
		_mine_charge = 0.0
		_swing_clock = SWING_PERIOD          # primed: the FIRST blow of the next charge lands instantly
		if _renderer != null:
			_renderer.set_mine_progress(Vector2i(-999, -999), 0.0)
		return
	var mat: StringName = sim.material_at(_aim)
	if not MiningRules.can_mine(mat, sim.inventory):
		# You lack the tool for this rock — no progress (a hint reads it as "you need a better pick").
		_mine_target = _aim
		_mine_charge = 0.0
		_renderer.set_mine_progress(_aim, 0.0)
		return
	if _aim != _mine_target:                                  # moved to a fresh block → restart the charge
		_mine_target = _aim
		_mine_charge = 0.0
	var cls: StringName = MiningRules.required_tool(mat)
	var speed: float = MiningRules.best_speed(cls, sim.inventory) if cls != &"" else 1.0
	_mine_charge += delta * speed
	var hard: float = MiningRules.hardness(mat)
	_renderer.set_mine_progress(_aim, clampf(_mine_charge / hard, 0.0, 1.0))
	# Swing FEEL (FABLE_50 #40): while charging, the body holds the dig pose facing the block, and on a
	# steady cadence a BLOW lands — a chip of the rock's dust off the struck face + a micro-shake — so
	# mining reads as pick-strikes landing, not a progress bar silently filling.
	if _player != null:
		_player.note_dig(int(signf(_cell_center(_aim).x - _player.position.x)))
		_swing_clock += delta
		if _swing_clock >= SWING_PERIOD:
			_swing_clock = 0.0
			var center: Vector2 = _cell_center(_aim)
			var to_body: Vector2 = _player.position - center
			_particles.chip(center + to_body.normalized() * (float(CELL) * 0.45),
				Visuals.terrain_dust(mat), to_body.angle())
			_shake = maxf(_shake, 0.7)
			# Harder rock strikes a deeper note (hardness 1..4 → pitch ~1.15..0.85).
			_sfx.play(&"crunch", center, clampf(1.25 - hard * 0.1, 0.8, 1.2))
	if _mine_charge >= hard:
		_mine_charge = 0.0
		try_mine(_aim)                                       # charge full → land the breaking blow


## Terraria-style mining reach: you don't have to land the cursor exactly on a reachable cell. When you
## point at a BLOCK that's out of reach, the aim snaps to the closest reachable block toward your cursor
## (and the highlight follows, so you see what you'll hit). Precise in-reach hovering is unchanged, and
## while BUILDING (a machine/material selected) the aim stays exact — placement wants the cell you point at.
func _effective_aim(mouse_world: Vector2) -> Vector2i:
	var raw: Vector2i = _cell_at(mouse_world)
	var building: bool = _selected_machine_def() != null or _selected_build_material() != &""
	if building:
		return raw                          # placement wants the exact cell (it has its own _placeable gate)
	# Mining/interaction: an OPEN cell in reach, or a SOLID block you have LINE OF SIGHT to, is the aim as-is.
	if _can_reach(raw) and (not sim.is_solid(raw) or _line_of_sight_clear(_body_cell(), raw)):
		return raw
	return _nearest_reachable_solid(mouse_world, raw)   # else snap to the nearest block you can actually carve


## The reachable SOLID cell whose centre is closest to `point` (the cursor) — the block Terraria-reach
## mining would bite. Scans only the small in-reach neighbourhood. Returns `fallback` if the cursor isn't
## near any reachable block (pointing at open air far off → no snap, so the cursor never jumps to a random
## wall behind you). The tolerance is one reach-radius from the cursor: point at/near a wall and it snaps.
func _nearest_reachable_solid(point: Vector2, fallback: Vector2i) -> Vector2i:
	if _player == null:
		return fallback
	var center: Vector2i = _cell_at(_player.position)
	var span: int = ceili(REACH_CELLS) + 1
	var tol_sq: float = pow(REACH_CELLS * float(CELL), 2.0)
	var best: Vector2i = fallback
	var best_d: float = INF
	for dy: int in range(-span, span + 1):
		for dx: int in range(-span, span + 1):
			var c: Vector2i = center + Vector2i(dx, dy)
			if not sim.is_solid(c) or not _can_reach(c) or not _line_of_sight_clear(center, c):
				continue
			var d: float = _cell_center(c).distance_squared_to(point)
			if d < best_d and d <= tol_sq:
				best_d = d
				best = c
	return best


## --- Player VERBS (the addressable game surface) --------------------------------------------------
## The body's world-actions, each reach-gated and boolean (did it happen?). The real input layer above
## drives them from mouse/keys; the scripted play-harness (tools/play_agent.gd) drives the SAME methods
## to literally play the game. One verb surface → what a human can do, the test can do, by construction.

## Mine the aimed cell if it's solid and within reach. (Cooldown is input pacing, not part of the verb.)
func try_mine(cell: Vector2i) -> bool:
	if _paused or not _mineable(cell):     # reach + LINE OF SIGHT: can't dig through solid rock to a hidden block
		return false
	var mat: StringName = sim.material_at(cell)
	if not MiningRules.can_mine(mat, sim.inventory):
		return false                                           # no tool for this rock — the gate the test drives
	var rich: bool = sim.ore_deposit_at(cell) > 0              # captured BEFORE the mine clears the cell
	var mined: StringName = sim.mine(cell)
	if mined != &"":
		var center: Vector2 = _cell_center(cell)
		_particles.dust(center, Visuals.terrain_dust(mat), 10)  # settling break-dust puff
		if _player != null:
			# The breaking blow's payoff (FABLE_50 #40): chunky debris kicked out of the shattered face
			# toward the digger, a heavier kick than a mid-charge chip — and a vein pays out a bright
			# fleck-spray in its own colour, so breaking ore FEELS richer than breaking dirt.
			_particles.debris(center, Visuals.terrain_dust(mat).lightened(0.12),
				(_player.position - center).angle())
			_player.note_dig(int(signf(center.x - _player.position.x)))
		if rich:
			_particles.spark(center, Visuals.item_color(mat).lightened(0.35))
		_shake = maxf(_shake, 2.2 if rich else 1.7)
		_sfx.play(&"thump", center, 1.1 if rich else 1.0, 2.0 if rich else 0.0)
	return mined != &""


## Hand the SELECTED carried item into the nearest machine within reach (the manual half of the arc).
func try_deposit() -> bool:
	var slots: Array[Dictionary] = sim.inventory_slots()
	if slots.is_empty():
		return false
	var sel: int = clampi(_inv_selected, 0, slots.size() - 1)
	var item: StringName = slots[sel]["item"]
	var carried: int = int(slots[sel]["count"])
	if carried <= 0 or MiningRules.is_tool_item(item):
		return false                                           # tools are equipment — never fed into a machine
	for machine: MachineState in sim.machines:
		if _can_reach(machine.cell):
			return sim.deposit(machine.cell, item, carried) > 0
	return false


## Configure the aimed machine (R outside the pack screen, FABLE_50 #49): cycle a splitter's ratio,
## clear a hopper's filter. Reach-gated like every world verb; the sim returns the toast text.
func try_configure(cell: Vector2i) -> bool:
	if _paused or not _can_reach(cell):
		return false
	var label: String = sim.configure_machine(cell)
	if label == "":
		return false
	_hud.flash(label)
	_particles.spark(_cell_center(cell), Color(0.75, 0.85, 0.98))
	_sfx.play(&"pop", _cell_center(cell), 1.4)
	return true


## Craft a machine item from carried ingots into the pack — GATED on standing near a claimed Bazaar
## (the crafting hub, docs/CRAFTING.md). Refused away from it, so machine-crafting pulls you to the stall.
func try_craft(def: MachineDef) -> bool:
	if not _near_bazaar():
		return false
	var made: bool = sim.craft(def)
	if made:
		_sfx.ui(&"ding")
	return made


## Craft a TOOL (e.g. the Stone Pickaxe) from carried materials — same Bazaar gate + same generic sink as
## machine crafting (sim.craft_item). The pickaxe-tier upgrade path (docs/MINING.md): craft it here, and it
## unlocks the deeper rock its tier gates. Verb-surfaced so the play-harness can drive tool crafting too.
func try_craft_tool(tool_id: StringName) -> bool:
	if not _near_bazaar():
		return false
	var made: bool = sim.craft_item(tool_id, MiningRules.TOOL_RECIPES.get(tool_id, {}))
	if made:
		_sfx.ui(&"ding", 1.1)
	return made


## RESEARCH a tech at the Bazaar bench (R in the pack screen) — the demand-side PULL: analyze a sample
## of the tech's signature material + spend refined ingots to UNLOCK crafting its machines
## (docs/PROGRESSION.md §5). Bazaar proximity is the bench (same gate as crafting); the spend itself is
## the sim's discrete research_tech. Verb-surfaced so the play-harness researches like a player.
func try_research(tech_id: StringName) -> bool:
	if not _near_bazaar():
		return false
	var done: bool = sim.research_tech(tech_id)
	if done and _player != null:
		_particles.spark(_player.position, Color(0.55, 0.85, 1.0))  # a cool "insight" burst at the bench
		_shake = maxf(_shake, 2.0)
		_sfx.ui(&"chime")
	return done


## Scoop up resting product piles NEAR the body — Factorio/Terraria "walk over items to grab them",
## widened to a short REACH so a machine's output flows to you when you stand at it. A pure downward
## conveyor (gravity) drops a forge's ingots into the cell below it, which the body often can't stand IN
## (the machine caps it); collecting within reach — the same reach the body mines/builds with — means you
## just stand at your line and its output comes to you, instead of needing to occupy the exact landing
## cell. Pure discrete sim edit (collect_ground); the avatar only triggers it.
const COLLECT_REACH_CELLS: float = 2.5
func _collect_ground_under_player() -> void:
	if _player == null or sim.ground.is_empty():
		return
	var reach_sq: float = pow(COLLECT_REACH_CELLS * float(CELL), 2.0)
	for cell: Variant in sim.ground.keys():                          # keys() copies — safe to collect mid-iter
		var c: Vector2i = cell
		var pile: Dictionary = sim.ground[c]
		if pile.is_empty():                                          # a pruned-but-lingering empty pile: skip
			continue
		if _player.position.distance_squared_to(_cell_center(c)) > reach_sq:
			continue
		var item: StringName = pile.keys()[0]
		if sim.collect_ground(c):
			_particles.pop(_cell_center(c), Visuals.item_color(item))  # pickup pop
			_sfx.play(&"pop", _cell_center(c), 1.0, -4.0)


## The active camera zoom level (Z cycles the index). Read everywhere the view-size matters.
func _current_zoom() -> float:
	return ZOOM_LEVELS[_zoom_idx]


## Cycle to the next zoom level (Z) and apply it to the camera — Terraria-style zoom-out/in.
func _cycle_zoom() -> void:
	_zoom_idx = (_zoom_idx + 1) % ZOOM_LEVELS.size()
	if _camera != null:
		_camera.zoom = Vector2(_current_zoom(), _current_zoom())


## Cycle the fast-forward game clock (".") and apply it. Engine.time_scale scales BOTH the sim's
## tick accumulator (the factory runs faster) and the body's physics (which substeps, so no tunnel).
func _cycle_speed() -> void:
	_time_scale_idx = (_time_scale_idx + 1) % TIME_SCALES.size()
	Engine.time_scale = TIME_SCALES[_time_scale_idx]


## F5 quicksave (FABLE_50 #1): the sim capture + the body's position, one versioned file.
func _save_game() -> void:
	var data: Dictionary = SaveGame.capture(sim)
	data["player_pos"] = _player.position
	_hud.flash("SAVED" if SaveGame.write(SAVE_PATH, data) else "save FAILED")


## F9 quickload: restore in place (sim object survives, so every live reference stays valid), put the
## body back, and repaint the retained view caches wholesale. A missing/bad file never touches the game.
func _load_game() -> void:
	var data: Dictionary = SaveGame.read(SAVE_PATH)
	if data.is_empty() or not SaveGame.restore(sim, data):
		_hud.flash("no save to load")
		return
	var pp: Variant = data.get("player_pos")
	if pp is Vector2:
		_player.position = pp
		_player.velocity = Vector2.ZERO
	_renderer.repaint_world()
	_hud.flash("LOADED")


## Move the active hotbar slot, wrapping across the items currently carried.
func _cycle_inventory(dir: int) -> void:
	var n: int = sim.inventory_slots().size()
	if n <= 0:
		_inv_selected = 0
		return
	_inv_selected = (_inv_selected + dir + n) % n


## Select hotbar slot `idx` directly (the number keys 1–8). No-op past the last carried item, so an
## empty slot can't become the active selection.
func _select_slot(idx: int) -> void:
	if idx < sim.inventory_slots().size():
		_inv_selected = idx


## DROP the selected stack (Q): gravity is the conveyor, so feeding is DROPPING — you don't insert into
## a machine, you let go above its column and it falls in (or onto the floor). It TOSSES forward (the
## Minecraft arc): the stack lands in the cell you're FACING-and-below — so you stand beside a forge and
## toss ore in, or fling it over a ledge into the next shaft. If that facing cell is a wall (you can't
## toss through rock), it falls back to a straight drop down your own column (so feeding a shaft you
## stand over still works). The body's cell is the visual launch origin; the sim cascades the landing.
func try_drop() -> bool:
	if _player == null:
		return false
	var slots: Array[Dictionary] = sim.inventory_slots()
	if slots.is_empty():
		return false
	var sel: int = clampi(_inv_selected, 0, slots.size() - 1)
	var item: StringName = slots[sel]["item"]
	var carried: int = int(slots[sel]["count"])
	var here: Vector2i = _cell_at(_player.position)
	var face: Vector2i = here + Vector2i(_player.facing, 0)
	# Toss forward into the facing column when it's clear (open air or a machine to feed); a solid wall
	# blocks the toss, so drop straight down instead. Landing is sim-truth; `here` is the launch origin.
	var target: Vector2i = face if (sim.in_bounds(face) and not sim.is_solid(face)) else here
	var dropped: int = sim.drop_item(target, item, carried, here)
	if dropped > 0:
		_particles.pop(_cell_center(target), Visuals.item_color(item))
	return dropped > 0


## RMB build verb: standing in reach of `cell`, place the selected machine on an open cell, or pick one
## of your own machines back up. Reach-limited + situated — the embodied replacement for the removed
## god-cursor palette. Every edit goes through the sim's discrete place/remove API, so the body still
## only triggers discrete mutations (determinism preserved). Returns whether anything happened.
func try_build(cell: Vector2i) -> bool:
	if _paused or not _can_reach(cell):
		return false
	if sim.machine_at(cell) != null:
		if sim.pickup_machine(cell):     # pick your machine back up into the pack
			_sfx.play(&"clunk", _cell_center(cell), 0.85)
			return true
		return false
	if sim.has_conduit(cell):
		if sim.remove_conduit(cell):     # pick a power tube back up into the pack
			_sfx.play(&"clunk", _cell_center(cell), 1.15)
			return true
		return false
	if sim.is_climbable(cell):
		if sim.remove_rope(cell) > 0:    # CUT the rope here — it and everything hanging below returns
			_sfx.play(&"pop", _cell_center(cell), 0.8)
			return true
		return false
	if sim.has_torch(cell):
		if sim.remove_torch(cell):       # take a mounted torch back into the pack
			_sfx.play(&"pop", _cell_center(cell), 0.9)
			return true
		return false
	var def: MachineDef = _selected_machine_def()
	if def != null and def.behavior == &"torch":
		var lit: bool = sim.place_torch(cell)     # mounts on a wall-backed / rock-adjacent open cell
		if lit:
			_particles.spark(_cell_center(cell), Color(1.0, 0.78, 0.42))
			_sfx.play(&"pop", _cell_center(cell), 1.15)
		return lit
	if def != null and def.behavior == &"conduit":
		var laid: bool = sim.place_conduit(cell)  # power tube → the conduit layer (not a machine)
		if laid:
			_particles.spark(_cell_center(cell), Visuals.machine_color(def).lightened(0.3))
			_sfx.play(&"clunk", _cell_center(cell), 1.2)
		return laid
	if def != null and def.behavior == &"rope":
		var hung: int = sim.place_rope(cell)      # anchors here and UNROLLS down the open column
		if hung > 0:
			_particles.spark(_cell_center(cell), Visuals.machine_color(def).lightened(0.3))
			_sfx.play(&"pop", _cell_center(cell), 0.85)
		return hung > 0
	if def != null and _placeable(cell):
		var placed: MachineState = sim.build_from_pack(def, cell)
		if placed != null:
			# Directional machines work the way YOU faced when placing (the Borer bores that way).
			placed.facing = _player.facing if _player != null else 1
			_particles.spark(_cell_center(cell), Visuals.machine_color(def).lightened(0.3))
			_shake = maxf(_shake, 2.2)
			_sfx.play(&"clunk", _cell_center(cell))
		return placed != null
	# Block placement (the Terraria build primitive): the selected hotbar item is a building material.
	var mat: StringName = _selected_build_material()
	if mat != &"" and _placeable(cell) and sim.place_block(cell, mat):
		_particles.dust(_cell_center(cell), Visuals.terrain_dust(mat), 6)
		_sfx.play(&"crunch", _cell_center(cell), 0.75)
		return true
	return false


## Inspector data for the machine under the cursor (if you aim at one of your machines within reach):
## its name, recipe (inputs → outputs as item lists), routing mode, and what it currently holds. The
## HUD renders it. Pure read of the sim — the legibility answer to "where does this eat / spit / make".
func _hover_info() -> Dictionary:
	if not _can_reach(_aim):
		return {}
	var m: MachineState = sim.machine_at(_aim)
	if m == null:
		# A visible SOLID ore vein — show how much ore is in it + the nudge to automate it. The readout the
		# user asked for ("hover to see how much ore is left"), now on the vein itself (no cavity to explain).
		var dep: int = sim.ore_deposit_at(_aim)
		if dep > 0:
			return {"name": "Ore Vein", "in": [], "out": [], "holding": [],
				"mode": "%d ore — drop a Drill just above it (%s)" % [dep, _rate_eta(_drill_rate(), dep)]}
		# THE SEAL is its own answer: no pick ever opens it — the Descent Engine does (docs/PROGRESSION.md).
		if sim.material_at(_aim) == &"sealrock":
			return {"name": "The Seal", "in": [], "out": [], "holding": [],
				"mode": "no pick will breach it — research DESCENT, stand an Engine on it, feed it %d ingots" % FactorySim.DESCENT_QUOTA}
		# Rock you can't break with your current tools — the depth-gate's "why?" answer (docs/MINING.md).
		if sim.is_solid(_aim):
			var rock: StringName = sim.material_at(_aim)
			if not MiningRules.can_mine(rock, sim.inventory):
				return {"name": String(rock).capitalize(), "in": [], "out": [], "holding": [],
					"mode": "too hard for your pick — craft a Stone Pickaxe (tier %d)" % MiningRules.required_tier(rock)}
		return {}
	var info: Dictionary = {"name": m.def.display_name}
	var recipe: RecipeDef = m.def.recipe
	var ins: Array = []
	var outs: Array = []
	if recipe != null:
		for it: StringName in recipe.inputs:
			ins.append({"item": it, "count": int(recipe.inputs[it])})
		for it: StringName in recipe.outputs:
			outs.append({"item": it, "count": int(recipe.outputs[it])})
	info["in"] = ins
	info["out"] = outs
	match m.def.behavior:
		&"lift":
			info["mode"] = "lifts goods + you UP" + ("  (POWERED ×%.1f)" % (1.0 + (float(FactorySim.LIFT_POWERED_THROUGHPUT) / float(FactorySim.LIFT_THROUGHPUT) - 1.0) * m.power_factor) if m.power_factor > 0.05 else "  (unpowered baseline)")
		&"splitter":
			info["mode"] = ["splits DOWN + RIGHT evenly (R: ratio)",
				"splits 2:1 favouring DOWN (R: ratio)",
				"splits 1:2 favouring RIGHT (R: ratio)"][m.mode % 3]
		&"hopper":
			var stock: int = 0
			for it: StringName in m.input_buffer:
				stock += int(m.input_buffer[it])
			if m.filter == &"":
				info["mode"] = "stockpiles %d — keeps the FIRST thing it tastes, passes the rest" % stock
			else:
				info["mode"] = "banks %s (%d) — passes everything else (R: re-taste)" % [String(m.filter), stock]
		&"generator":
			info["mode"] = "burns coal → POWER" + ("  (running)" if m.fuel > 0 else "  (out of fuel)")
		&"descent":
			if m.fed >= FactorySim.DESCENT_QUOTA:
				info["mode"] = "BREACHED — the way down is open"
			elif sim.machine_status(m) == &"blocked":
				info["mode"] = "stand it ON the seal (nothing to breach below)"
			else:
				info["mode"] = "fed %d/%d ingots — drop them in (gravity feeds it)" % [m.fed, FactorySim.DESCENT_QUOTA]
		&"h_drill":
			var btgt: Vector2i = sim.h_drill_target(m.cell, m.facing)
			var belly: int = 0
			for it2: StringName in m.output_buffer:
				belly += int(m.output_buffer[it2])
			var bcoal: int = int(m.input_buffer.get(&"coal", 0))
			match sim.machine_status(m):
				&"no_input":
					info["mode"] = "gallery spent — carry it to a new rock face"
				&"blocked":
					info["mode"] = "belly FULL (%d) — dig a drain below it, or pick it up" % belly
				&"no_fuel":
					info["mode"] = "OUT OF COAL — it burns coal to bore (drop some on it)"
				_:
					info["mode"] = "boring %s %s — belly %d · coal %d" % [
						String(sim.material_at(btgt)), ("→" if m.facing > 0 else "←"), belly, bcoal]
		&"drill":
			var tgt: Vector2i = sim.drill_target(m.cell)         # the solid ore vein it bores below
			var dep2: int = sim.drill_column_remaining(m.cell) if tgt.x >= 0 else 0
			var coal: int = int(m.input_buffer.get(&"coal", 0))
			var fueled: bool = m.fuel > 0 or coal > 0
			if dep2 <= 0:
				info["mode"] = "idle — no ore below (drop it into a shaft above an ore vein)"
			elif not fueled:
				info["mode"] = "OUT OF COAL — drop coal on it to run  (%d ore left)" % dep2
			else:
				info["mode"] = "drilling %s — %d ore left  ·  coal %d" % [_rate_eta(_drill_rate(), dep2), dep2, coal]
		_:
			if recipe != null and recipe.inputs.is_empty():
				info["mode"] = "ore source"
			elif recipe != null:
				info["mode"] = "smelts (%.1fs/cycle)" % recipe.time
	var hold: Dictionary = {}
	for it: StringName in m.input_buffer:
		hold[it] = int(hold.get(it, 0)) + int(m.input_buffer[it])
	for it: StringName in m.output_buffer:
		hold[it] = int(hold.get(it, 0)) + int(m.output_buffer[it])
	var holding: Array = []
	for it: StringName in hold:
		holding.append({"item": it, "count": int(hold[it])})
	info["holding"] = holding
	# The factory-wide make-rate of this machine's product (sim.production_rate — the "12/min" read).
	# Recipe machines rate their first output; a drill rates the material it's boring.
	var rate_item: StringName = &""
	if recipe != null and not recipe.outputs.is_empty():
		rate_item = recipe.outputs.keys()[0]
	elif m.def.behavior == &"drill":
		var bore: Vector2i = sim.drill_target(m.cell)
		if bore.x >= 0:
			rate_item = sim.material_at(bore)
	if rate_item != &"":
		var per_min: float = sim.production_rate(rate_item)
		if per_min > 0.05:
			info["rate"] = "factory makes %.1f %s/min" % [per_min, String(rate_item)]
	return info


## The machine def for the active hotbar slot, or null if the selected item isn't a placeable
## machine you carry (it's a resource, or the pack is empty).
func _selected_machine_def() -> MachineDef:
	var slots: Array[Dictionary] = sim.inventory_slots()
	if slots.is_empty():
		return null
	var sel: int = clampi(_inv_selected, 0, slots.size() - 1)
	return _machine_defs_by_id.get(slots[sel]["item"], null)


## The building MATERIAL for the active hotbar slot (e.g. &"wood"), or &"" if the selected item isn't a
## placeable block. Drives RMB block placement + the renderer's placement ghost.
func _selected_build_material() -> StringName:
	var slots: Array[Dictionary] = sim.inventory_slots()
	if slots.is_empty():
		return &""
	var sel: int = clampi(_inv_selected, 0, slots.size() - 1)
	var item: StringName = slots[sel]["item"]
	return item if item in BUILD_MATERIALS else &""


## A cell takes a hand-placed machine if it's in-bounds, open (not earth), unoccupied, and NOT the
## cell the body is standing in — so you can never seal yourself inside a machine you place.
func _placeable(cell: Vector2i) -> bool:
	return sim.in_bounds(cell) and not sim.is_solid(cell) \
		and sim.machine_at(cell) == null and not sim.has_conduit(cell) \
		and not sim.is_climbable(cell) and not _player_occupies(cell)


func _player_occupies(cell: Vector2i) -> bool:
	if _player == null:
		return false
	var cell_rect := Rect2(Vector2(cell) * float(CELL), Vector2(CELL, CELL))
	var body := Rect2(_player.position - Vector2(Player.WIDTH, Player.HEIGHT) * 0.5,
		Vector2(Player.WIDTH, Player.HEIGHT))
	return cell_rect.intersects(body)


func _can_reach(cell: Vector2i) -> bool:
	if _player == null:
		return false
	return _player.position.distance_to(_cell_center(cell)) <= REACH_CELLS * float(CELL)


## The grid cell the body occupies — the origin for mining line-of-sight.
func _body_cell() -> Vector2i:
	return _cell_at(_player.position)


## Can the body actually MINE `cell`? Reach radius is not enough — you can't dig THROUGH solid rock to a
## block behind it (the "I mined 3,0 while 1,0 and 2,0 were still wall" bug). A block is mineable only if a
## straight line from the body to it is CLEAR of other solid cells — so you carve the exposed FACE of a wall
## one layer at a time (mine the face → the pocket grows → the next layer is exposed). The dig becomes
## carving, not poking a radius blob. Building/hover keep the plain reach test; this gates mining only.
func _mineable(cell: Vector2i) -> bool:
	return sim.is_solid(cell) and _can_reach(cell) and _line_of_sight_clear(_body_cell(), cell)


## Is the straight segment from cell `a` to cell `b` clear of SOLID cells strictly between them? A grid
## voxel-walk (Amanatides–Woo DDA) from a toward b: the first solid cell entered BEFORE reaching b blocks
## the ray. The target b itself may be solid (it's what you're mining); adjacent cells are always clear
## (no cell between). Pure read of sim.is_solid — deterministic, no allocation.
func _line_of_sight_clear(a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return true
	var ox: float = float(a.x) + 0.5
	var oy: float = float(a.y) + 0.5                     # ray origin = centre of cell a (in cell units)
	var dx: float = (float(b.x) + 0.5) - ox
	var dy: float = (float(b.y) + 0.5) - oy
	var cx: int = a.x
	var cy: int = a.y
	var step_x: int = signi(dx)
	var step_y: int = signi(dy)
	var t_max_x: float = INF
	var t_delta_x: float = INF
	if dx != 0.0:
		t_delta_x = absf(1.0 / dx)
		t_max_x = ((float(cx + (1 if step_x > 0 else 0))) - ox) / dx
	var t_max_y: float = INF
	var t_delta_y: float = INF
	if dy != 0.0:
		t_delta_y = absf(1.0 / dy)
		t_max_y = ((float(cy + (1 if step_y > 0 else 0))) - oy) / dy
	for _guard: int in 512:                              # bounded by grid size; can't loop forever
		if t_max_x < t_max_y:
			cx += step_x
			t_max_x += t_delta_x
		else:
			cy += step_y
			t_max_y += t_delta_y
		if cx == b.x and cy == b.y:
			return true                                 # reached the target → nothing solid in the way
		if sim.is_solid(Vector2i(cx, cy)):
			return false                                # a solid cell before the target blocks the dig
	return true


# --- helpers -----------------------------------------------------------------

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * float(CELL) + Vector2(CELL, CELL) * 0.5


func _cell_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / float(CELL)), floori(world_pos.y / float(CELL)))


## World-space hint cells for the CURRENT objective step — the legibility answer to "where do I do that?".
## Each is {cell, mode}: "act" = pulse a target ring here (mine this rock / feed this forge), "ghost" =
## outline where to place the next machine (cap the forge). The view pulses them; deleting this changes no
## production number (pure read of the sim + objective state). Maps the objective id → fixtures/sim queries.
func _guide_targets() -> Array[Dictionary]:
	if _objectives == null or _objectives.all_done():
		return []
	var out: Array[Dictionary] = []
	match _objectives.current_id():
		&"mine":
			var ore: Vector2i = _nearest_ore_to_player()
			if ore.x >= 0:
				out.append({"cell": ore, "mode": "act"})
		&"smelt":
			var forge: Vector2i = _first_forge()
			if forge.x >= 0:
				out.append({"cell": forge, "mode": "act"})
		&"wood":
			var tree: Vector2i = _nearest_tree_to_player()
			if tree.x >= 0:
				out.append({"cell": tree, "mode": "act"})
		&"bazaar":
			var gap: Vector2i = sim.bazaar_completion_cell()
			if gap.x >= 0:
				out.append({"cell": gap, "mode": "ghost"})
		&"build":
			var spot: Vector2i = MINESHAFT_DRILL_CELL     # the drill caps the ore chunk from directly above
			if sim.machine_at(spot) == null and not sim.is_solid(spot) and sim.material_at(spot + Vector2i(0, 1)) == &"ore":
				out.append({"cell": spot, "mode": "ghost"})
	return out


## True when the body stands close enough to a CLAIMED (completed) Bazaar to craft machines there. The
## crafting hub gate (docs/CRAFTING.md): away from it, the E screen shows the pack but no recipes.
func _near_bazaar() -> bool:
	return _player != null and sim.near_bazaar(_cell_at(_player.position), BAZAAR_RADIUS)


## The nominal extraction RATE of a Drill in ore/second (1 unit per recipe cycle). Read off the drill def
## so it tracks the recipe, not a magic number — the throughput the hover inspector surfaces.
func _drill_rate() -> float:
	var drill: MachineDef = _machine_defs_by_id.get(&"drill", null)
	if drill == null or drill.recipe == null or drill.recipe.time <= 0.0:
		return 0.0
	return 1.0 / drill.recipe.time


## Format a rate + an ETA-to-empty for a deposit — "1.0/s, ~4m left" — so the player reads throughput AND
## how long the patch lasts at that rate (the "is this worth automating?" answer). Rate 0 → amount only.
func _rate_eta(rate: float, amount: int) -> String:
	if rate <= 0.0:
		return "%d left" % amount
	var secs: int = int(round(float(amount) / rate))
	var span: String = ("~%dm left" % (secs / 60)) if secs >= 90 else ("~%ds left" % secs)
	return "%.1f/s · %s" % [rate, span]


## The cell of the first FORGE (processor) placed in the world, or (-1,-1) if none — the smelt/build guide
## follows the forge wherever it sits (seeded mineshaft, or one the player built themselves).
func _first_forge() -> Vector2i:
	for m: MachineState in sim.machines:
		if m.def.id == &"processor":
			return m.cell
	return Vector2i(-1, -1)


## The ore cell nearest the player (the dig target for the opening step). Scans the bounded terrain; the
## starter vein by spawn wins by proximity, and it keeps pointing at real ore as veins deplete.
func _nearest_ore_to_player() -> Vector2i:
	var here: Vector2i = _cell_at(_player.position)
	var best := Vector2i(-1, -1)
	var best_d: int = 1 << 30
	for cell_v: Variant in sim.solid:
		var cell: Vector2i = cell_v
		if sim.solid[cell] != &"ore":
			continue
		var d: int = (cell - here).length_squared()
		if d < best_d:
			best_d = d
			best = cell
	return best


## The nearest WOOD (tree trunk) cell to the player — the chop target for the wood step. Trees are sparse
## on the surface; this points at the closest one so "go get wood" isn't a hunt.
func _nearest_tree_to_player() -> Vector2i:
	var here: Vector2i = _cell_at(_player.position)
	var best := Vector2i(-1, -1)
	var best_d: int = 1 << 30
	for cell_v: Variant in sim.solid:
		var cell: Vector2i = cell_v
		if sim.solid[cell] != &"wood":
			continue
		var d: int = (cell - here).length_squared()
		if d < best_d:
			best_d = d
			best = cell
	return best
