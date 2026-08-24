class_name MainView
extends Node2D

## The controller and session root. Owns a FactorySim, advances it, hosts the embodied Player and follow
## Camera2D, and translates mouse and keys into the player's reach-gated world verbs (try_mine,
## try_deposit, try_build, try_craft). It only reads sim production state; every edit goes through the
## sim's discrete API. It does not draw: a child WorldRenderer is the view, reading the sim and the aim
## state pushed to it each frame, and FallingItems is the cosmetic drop layer. Delete the view and the
## player and the production numbers are identical.
##
## The loop: dig solid earth (LMB, reach-limited), mine ore veins into your pack, drop ore (Q) above a
## Processor so gravity feeds it in, craft machines from ingots in the E screen, build the chain (RMB to
## place or pick up), and the Lift hauls goods and you upward. Controls: 1-8 select, wheel cycles, Q
## drop, E crafting, M map, H help.

const CELL: int = FactorySim.CELL
const REACH_CELLS: float = 3.2     ## how far the body can mine/deposit from its centre
## The F5/F9 quicksave slot (SaveGame envelope). A `static var` rather than a const, for the same reason
## `Settings.path` is one: anything driving the real save verbs must be able to point them at its own file
## first. As a const it saved over, and then deleted, the developer's actual game.
static var save_path: String = "user://sinkforge.save"
const WORLD_SIZE := Vector2(FactorySim.GRID_COLS * CELL, FactorySim.GRID_ROWS * CELL)
## The internal render viewport (project.godot), 1280x720. The HUD authors in Hud.CANVAS (640x360) space
## and its CanvasLayer is scaled by HUD_SCALE to fill this. World-area-shown math (motes, camera, minimap)
## reads VIEWPORT rather than CANVAS, since the two diverge here.
const VIEWPORT := Vector2(1280.0, 720.0)
const HUD_SCALE: float = VIEWPORT.x / 640.0        ## = 2.0; scales the 640×360 HUD onto the 1280×720 render
## Zoom levels cycled by Z. _current_zoom() reads the active level everywhere. Smaller is further out; Z
## cycles outward and wraps.
##
## Index 0 is 1.00x, which shows a 40x22-cell field: still a wide side-view field, comfortably wider than
## Terraria's in tile terms, while keeping the miner large enough to read as a character and a 32px cell
## large enough to show its rock texture rather than blooming into a smear. At 0.70x the field is 57x32
## cells and the avatar is well under one percent of the frame's width, which is below the size at which
## any amount of rim light, head-lamp or guide ring can make him findable. The steps out from there are
## 0.70x, 0.50x for the big-world feel, and 0.33x to survey the whole base.
const ZOOM_LEVELS: Array[float] = [1.00, 0.70, 0.50, 0.33]
var _zoom_idx: int = 0
const WORLD_SEED: int = 1337       ## the default gen seed; the title screen can reroll it


## The seed a boot uses when nothing has picked one: WORLD_SEED, unless SF_SEED names another.
##
## The override exists because the quality floors in this project are all measured on seed 1337, so a
## change that leaves 1337 pleasant and 4242 barren would pass every one of them. Routing the default
## through here lets those same checks run on other worlds rather than being re-implemented elsewhere.
##
## Consulted only when no explicit seed was chosen: `boot_seed`, set by the title screen or by a save being
## restored, always wins, so this can never overwrite a seed the player or a save actually picked.
static func default_seed() -> int:
	var env: String = OS.get_environment("SF_SEED")
	return int(env) if env.is_valid_int() else WORLD_SEED

## --- The title / new-game screen --------------------------------------------
## Opens on a real boot only: a process launched with `--script` suppresses it, so scripted drivers land in
## the live world instantly. Pick a world seed (TAB rerolls) and your lamp tint (left/right); ENTER
## descends. A changed seed reboots the scene through the statics below, which survive
## reload_current_scene; an unchanged one just drops the veil. C continues the F5/F9 save.
var _title_open: bool = false
var _title_seed: int = WORLD_SEED
var _title_tint: int = 0
## The seed this world was built with lives in one place, `sim.world_seed`, set by `load_world` at
## generation and by `SaveGame.restore` at load. A second copy on the controller was a live bug rather
## than a convenience: a restore updated the sim's seed and the fine terrain derived from it, but nothing
## updated the controller's, so the next F5 stamped the stale seed over the correct captured one and the
## load after that rebuilt the fine grid wrong. Two authorities for one fact is the defect.
static var boot_seed: int = -1              ## >= 0: the next boot generates with this seed
static var boot_tint: int = 0               ## the picked lamp tint index (persists across reloads)
static var boot_skip_title: bool = false    ## set before a new-world reload: land straight in the game
## The lamp tint colours the head-lamp's pools everywhere; it is your identity in the deep.
const LAMP_TINTS: Array[Dictionary] = [
	{"name": "miner's gold", "color": Color(1.0, 0.90, 0.66)},
	{"name": "carbide white", "color": Color(0.92, 0.96, 1.0)},
	{"name": "ember orange", "color": Color(1.0, 0.74, 0.44)},
	{"name": "willow green", "color": Color(0.80, 1.0, 0.72)},
	{"name": "violet arc", "color": Color(0.88, 0.74, 1.0)},
]
## Materials the player can place as blocks from the pack. Wood is the bazaar build material; the list
## grows as more buildables land.
const BUILD_MATERIALS: Array[StringName] = [&"wood", &"earth", &"stone", &"deepslate", &"gravel"]
## How close, in chebyshev cells around a bazaar's centre, you must stand to craft machines. Away from one,
## the E screen shows the pack only.
const BAZAAR_RADIUS: int = 3
## Dev: start with a stocked pack (ore, ingots, machines) for testing. Off by default, so a new game begins
## with an empty pack but for the two starter tools and the painful by-hand bootstrap that motivates
## automation is the actual first experience.
static var dev_start: bool = false

var sim: FactorySim
var _player: Player
var _camera: Camera2D
## The camera's un-snapped follow position, smoothed toward the body each frame. The value actually
## assigned to the camera is snap_to_pixel'd off this, so motion stays soft and the render stays crisp.
var _cam_pos: Vector2 = Vector2.ZERO
var _cam_lead: Vector2 = Vector2.ZERO   ## the eased velocity look-ahead the camera adds to the body
const CAMERA_LEAD_TIME: float = 0.34    ## seconds of travel the camera leads by
const STRIDE_LEAD: float = 0.55         ## extra lead time at full stride, so speed is visible
const CAMERA_LEAD_MAX: float = 170.0    ## px cap, so a terminal-velocity fall can't shove the body off-frame
const CAMERA_LEAD_VERTICAL: float = 0.55
const CAMERA_LEAD_EASE: float = 5.0     ## per-second easing on the lead itself (a lurch reads as a bug)
const CAMERA_FOLLOW_SPEED: float = 8.0   ## soft follow, matching the old position_smoothing_speed
var _renderer: WorldRenderer       ## the view: all world-space drawing and lighting (aim state is pushed to it)
var _hud: Hud                      ## screen-space HUD (objectives + the machine inspector are pushed to it)
var _paused: bool = false
## On-demand UI state: the crafting screen (E), the map (M) and the controls help (H) are summoned rather
## than permanent. Pushed to the HUD each frame so it knows what to draw.
var _inventory_open: bool = false   ## E opens the pack; crafting lives inside it, but machine-crafting is
                                    ## gated on standing near a claimed Bazaar
## Minimap mode: 0 hidden, 1 corner, 2 large and centred. M cycles; Esc closes.
var _minimap_mode: int = 0
## The player's ping marker in world coords (Vector2.INF = none): click the open map to set it, click it
## again to clear. A navigation bookmark, pushed to the HUD as a map dot and to the renderer as a beacon.
var _ping_world: Vector2 = Vector2.INF
var _hover_latch: Vector2i = Vector2i(-9999, -9999)   ## the machine the config panel is pinned to
## The settings overlay: ESC with nothing else open summons it, for audio sliders, screen-shake, zoom and
## the key remap page. While it is open it eats all input, page-sized. _capture_action is the action
## awaiting its new key; _settings_drag is the slider id being dragged.
var _settings_open: bool = false
var _capture_action: StringName = &""
var _settings_drag: String = ""
var _show_help: bool = false
var _show_dashboard: bool = false   ## G: the production dashboard, a non-modal read
## Fast-forward game clock: "." cycles Engine.time_scale through this ladder so the whole game, sim ticks
## and the body alike, runs faster. The body integrates in substeps (Player.MAX_SUBSTEP) so it cannot
## tunnel at the high multipliers.
const TIME_SCALES: Array[float] = [1.0, 2.0, 4.0, 8.0]
var _time_scale_idx: int = 0
## Timed mining, the friction: holding LMB charges the aimed cell, and it breaks when the charge reaches
## the material's hardness scaled by your best tool's speed. _mine_target tracks which cell is charging;
## the charge fraction is pushed to the renderer for the crack overlay.
var _mine_target: Vector2i = Vector2i(-999, -999)
var _mine_charge: float = 0.0
## The rock remembers. Charge is banked per cell rather than per aim: a cursor slip onto a neighbour used
## to zero the whole dig, so the pain of mis-aiming dwarfed the pain of the rock. Now the cracks you
## chipped stay chipped and returning to a block resumes it. Left alone the rock heals: CRACK_HOLD seconds
## of grace, so a slip costs nothing, then the banked charge bleeds off at CRACK_HEAL per second and the
## entry evicts itself at zero, so the table stays small without a cap and abandoned half-digs do not
## linger as free progress.
const CRACK_HOLD: float = 2.5    ## seconds a cell keeps its full banked charge after you look away
const CRACK_HEAL: float = 0.5    ## charge-seconds bled per second once the grace expires
var _cracks: Dictionary = {}     ## Vector2i -> Vector2(banked charge seconds, seconds since last worked)
var _aim: Vector2i = Vector2i(-99, -99)
## The dig plan: dragging LMB across rock paints marks (cell -> true), a plan that persists after release.
## While LMB is held and the cursor is not on a workable block, the miner works the nearest marked cell in
## reach instead, so you sketch a shaft once and hold rather than re-aiming every block. Player intent
## rather than production state: it lives here and in a renderer overlay, never enters the sim and is not
## saved. Reach, line-of-sight and tool gates are the same ones try_mine enforces.
var _dig_marks: Dictionary = {}
var _last_paint_world: Vector2 = Vector2.INF   ## last cursor world-pos while painting (sweep interpolation)
const MAX_DIG_MARKS: int = 200
## The machines you can craft, spending ingots. The ore_vent, a source, is deliberately absent: you remain
## the ore source by hand, which is the manual-to-automated pillar. `_machine_defs_by_id` resolves a
## carried hotbar item back to its def so a selected machine item can be placed.
var _craftable: Array[MachineDef] = []
var _machine_defs_by_id: Dictionary = {}
## Craftable tools (id + display name; cost lives in MiningRules.TOOL_RECIPES) shown in the Bazaar craft
## screen after the machines. The Stone Pickaxe is the first depth-unlocking upgrade.
const CRAFT_TOOLS: Array[Dictionary] = [
	{"id": &"stone_pickaxe", "name": "Stone Pickaxe"},
	{"id": &"iron_pickaxe", "name": "Iron Pickaxe"},
	{"id": &"scanner", "name": "Scanner"},
	# The bits are cutting heads rather than upgrades: each is a different job rather than the same job
	# faster, and you keep every one you buy. Priced in refined goods, so wanting one is a reason to run the
	# factory rather than a reason to hand-mine more (docs/BITS.md §7).
	{"id": BitRules.BROAD, "name": "Broad Bit"},
	{"id": BitRules.SINKER, "name": "Sinker Bit"},
	{"id": BitRules.LANCE, "name": "Lance Bit"},
	{"id": BitRules.WEDGE, "name": "Wedge Bit"},
]
## The scanner: with it selected, RMB fires a sonar pulse from the body, and ore bodies in range answer
## with echo rings through the rock. Transient and local: prospecting, not a map reveal.
const SCAN_RANGE_CELLS: float = 14.0
const SCAN_COOLDOWN: float = 1.6           ## pacing between pulses (feel, not economy)
var _scan_cooldown: float = 0.0
var _scan_dings: Array[Dictionary] = []    ## scheduled sonar returns: {at: seconds-from-now, pos, near}
## Which carried-item slot is active in the inventory hotbar (the mouse wheel cycles it). The selected item
## is what E deposits, for a resource, or RMB places, for a machine.
var _inv_selected: int = 0
## Cosmetic falling-product layer (driven by the sim's flow_events, never feeds back). Its own module.
var _falling := FallingItems.new()
## Bazaar view: detects completed wood frames (sim.find_bazaars) and plays the block-by-block transform
## into a decorated stall + shopkeeper. Representation-only; never writes the sim.
var _bazaars := Bazaars.new()
## Cosmetic particle + screenshake juice (dig/land/place/collect). Pure representation.
var _particles := Particles.new()
## The "+N" gain ticks that rise off a broken block, so the payoff shows where you are looking rather than
## only as a number in the corner of the HUD. Pure representation.
var _payouts := Payouts.new()
## The screen-space lens pass. Held so the counter can rack the world out of focus behind it: the panel
## draws on a layer above this one, so only what is behind it defocuses.
var _lens: ColorRect
var _shake: float = 0.0            ## current screenshake magnitude (px), decays each frame
var _line_pivots: int = 0          ## pivots on the rope last frame; the rising edge is a catch
var _step_dist: float = 0.0       ## accumulated walk distance, for periodic footstep dust
## The descent: which stratum the body was in last frame, so crossing into a new one can be an event.
## Session-scoped by design, so a returning player gets the arrival again. The banner is orientation as
## much as ceremony.
var _band_seen: Dictionary = {}   ## band index -> true, the bands announced this session
var _band_now: int = -1

## The thesis moment. The first time a line the player built pours an ingot with the player's hands
## nowhere near it, the game has said the only thing it is really about. A silent checkbox on the objective
## ladder left the stretch right after first automation as the longest quiet in a run, so this takes the
## arrival plate: the same ceremony a new stratum gets, for the same kind of event.
var _line_hailed: bool = false
const LINE_HAIL_SHAKE: float = 2.6
const SWING_PERIOD: float = 0.28   ## seconds between pick-blows while charge-mining (the swing cadence)
## Seconds of work per unit off an exposed lode (docs/LODE.md §5), before tool speed and rhythm. Short on
## purpose: this is a drum of small payouts rather than a charge that ends in a break, so the vein gives
## rather than shatters. Deliberately poorer than a drill per unit; the hand is how you get your first ore
## and how you top up, never how you supply a factory.
const LODE_CYCLE: float = 0.55
var _swing_clock: float = SWING_PERIOD  ## primed so a fresh charge's first blow lands instantly

## The dig rhythm. Mining had no momentum: every block started from a dead stop, so a twenty-block shaft
## was twenty identical unrelated chores. Breaking blocks back to back builds a rhythm that speeds the pick
## up and shortens the swing cadence, and it bleeds away if you stop. Nothing is displayed for it. The body
## swings visibly faster and the strikes come audibly quicker, which is where the player is already
## looking. It multiplies a grind that stays a grind: the first block of a run is exactly as slow as it
## was, so hand-mining still argues for automation, and what changed is that staying in the work pays back.
const RHYTHM_GAIN: float = 0.34    ## rhythm added per block broken (about 3 blocks to full)
const RHYTHM_GRACE: float = 1.1    ## seconds of not-digging before it starts to bleed
const RHYTHM_DECAY: float = 0.55   ## per-second bleed after the grace window
const RHYTHM_SPEED: float = 0.60   ## +60% charge rate at full rhythm
const RHYTHM_SWING: float = 0.55   ## and a 1/1.55 shorter cadence, so the speed is visible and audible
var _rhythm: float = 0.0           ## 0..1
var _rhythm_idle: float = 0.0      ## seconds since the last block broke
## The tutorial chain: the how-do-I-play signpost. Reads the sim.
var _objectives: Objectives
## Just-in-time hint bubbles: first rope in the pack → "RMB above a drop", etc. Reads the sim.
var _hints: Hints
## GPU ambient dust motes: a continuous GPUParticles2D haze that drifts in the air and catches the lamp
## light. Pure atmosphere; follows the camera each frame.
var _motes: GPUParticles2D
## Procedural audio: synthesized SFX and the factory hum. Poked from the same verb hooks that fire
## particles; never touches the sim.
var _sfx: Sfx
var _score: Score
## Descent engines whose breach has already been sounded (cell -> true). Primed on seed or load so an
## engine that breached before this session does not boom retroactively; a live breach booms once.
var _breach_heard: Dictionary = {}


func _ready() -> void:
	Controls.register()    # register the remappable InputMap actions (the settings page rebinds them)
	if not _is_scripted_boot():
		# Machine-local prefs, on real boots only: a scripted boot always runs on pure defaults and can never
		# read or clobber the developer's settings file.
		Settings.persist = true
		Settings.load_settings()
		_zoom_idx = clampi(Settings.zoom_idx, 0, ZOOM_LEVELS.size() - 1)
	else:
		# The same gate silences the run. The shipped default is sound on, which is a statement about what a
		# player hears rather than about what a windowed test should do to whoever is sitting in front of it.
		# Muting here keeps that default honest: a scripted boot opts out of the audio the way it opts out of
		# persistence, instead of the default lying to stay quiet.
		Settings.muted = true
		Settings.apply_audio()
	sim = FactorySim.new()
	_craftable = [
		load("res://src/data/machines/processor.tres"),
		load("res://src/data/machines/splitter.tres"),
		load("res://src/data/machines/lift.tres"),
		load("res://src/data/machines/drill.tres"),  # automates ore extraction
		load("res://src/data/machines/spur.tres"),   # one more mouth on a Head: reach across a vein
		load("res://src/data/machines/hopper.tres"),  # stockpiles and meters gravity-fed output
		load("res://src/data/machines/generator.tres"),  # burns coal → power
		load("res://src/data/machines/conduit.tres"),     # carries power down+lateral
		load("res://src/data/machines/rope.tres"),        # the placeable climb; unrolls down a shaft
		load("res://src/data/machines/torch.tres"),       # placeable light: claimed territory in the black
		load("res://src/data/machines/descent_engine.tres"),  # the L1→L2 gate-breacher (docs/PROGRESSION.md)
		# The L2 crafter modules, per-item and gravity-fed: the iron chain.
		load("res://src/data/machines/iron_forge.tres"),
		load("res://src/data/machines/plate_press.tres"),
		load("res://src/data/machines/gear_mill.tres"),
		load("res://src/data/machines/h_drill.tres"),     # the Borer: sideways extraction
		load("res://src/data/machines/drift_rig.tres"),   # the Drift Rig: a powered gallery that sorts
		                                                  # pay from spoil at the face (docs/DRIFT.md)
		load("res://src/data/machines/blast_furnace.tres"),   # 1 rich ore -> 2 ingots (Enrichment)
		load("res://src/data/machines/crusher.tres"),     # spoil → gravel, the one material that packs
		                                                  # (docs/DRIFT.md §4, Packing)
		load("res://src/data/machines/pump.tres"),        # L3: power-drains flood water (Drainage)
	]
	for def: MachineDef in _craftable:
		_machine_defs_by_id[def.id] = def
	_seed_world()

	_sfx = Sfx.new()
	add_child(_sfx)
	_score = Score.new()
	add_child(_score)

	_player = Player.new()
	_player.sim = sim
	_player.place(_cell_center(Vector2i(SPAWN_COL, SURFACE - 2)))  # just above the centred plateau (falls onto it)
	_player.z_index = 60  # above the light layers (50/51) so the miner stays crisp inside his lamp pool
	add_child(_player)

	_camera = Camera2D.new()
	# The active zoom level frames the body as a readable character while keeping enough world in view to see
	# a vertical chain. Smaller is further out.
	_camera.zoom = Vector2(_current_zoom(), _current_zoom())
	# Pixel-snap the follow. Godot's built-in position_smoothing renders the camera at a fractional position,
	# so every terrain texel samples between screen pixels each frame and the world shimmers in motion.
	# Instead this smooths toward the body itself, for the same soft feel, and rounds the result to a whole
	# screen pixel via snap_to_pixel. That needs top_level, so this node owns the camera's global position
	# outright rather than inheriting the body's transform.
	_camera.position_smoothing_enabled = false
	_camera.top_level = true
	# Centred on the body, with no dead zone. The avatar is the player's anchor and must always be the focal
	# point; drag margins let it drift into a screen corner and under the HUD, which reads as not being able
	# to find your character. The manual smoothing above eases the follow so motion stays soft.
	_camera.drag_horizontal_enabled = false
	_camera.drag_vertical_enabled = false
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(WORLD_SIZE.x)
	_camera.limit_bottom = int(WORLD_SIZE.y)
	_player.add_child(_camera)
	_cam_pos = _player.global_position
	_camera.global_position = snap_to_pixel(_cam_pos, _current_zoom())
	_camera.make_current()

	var layer := CanvasLayer.new()
	layer.layer = 10  # above the screen-FX lens pass (layer 5) so the HUD stays crisp, un-vignetted
	# The HUD draws in Hud.CANVAS (640x360) space and the render viewport is VIEWPORT (1280x720), so the whole
	# HUD layer is scaled by HUD_SCALE to fill the render target. World space is untouched.
	layer.scale = Vector2(HUD_SCALE, HUD_SCALE)
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
	# The Rack is its own column rather than the tail of the machine list. The two mean different things: the
	# counter builds from your own materials, and the Rack sells gear for refined goods. Tools are not
	# placeable, so they are absent from machine_icons and the panel draws them by their item glyph.
	var rack_opts: Array[Dictionary] = []
	var rack_ids: Array[StringName] = []
	for t: Dictionary in CRAFT_TOOLS:
		var tid: StringName = t["id"]
		rack_opts.append({"name": t["name"], "cost": _tool_recipe(tid)})
		rack_ids.append(tid)
	hud.craft_options = craft_opts
	hud.craft_ids = craft_ids
	hud.rack_options = rack_opts
	hud.rack_ids = rack_ids
	hud.machine_icons = machine_icons
	hud.inv_selected_getter = func() -> int: return _inv_selected
	# Tutorial chain, built after the world is seeded so its baseline includes any dev-start kit, and handed
	# to the HUD to render. It only reads the sim; MainView refreshes it each frame.
	_objectives = Objectives.new(sim)
	hud.objectives = _objectives
	# Hint bubbles, same pattern: built after seeding, so a pre-stocked pack fires nothing at boot.
	_hints = Hints.new(sim)
	_hud = hud
	layer.add_child(hud)
	add_child(layer)

	# The view: a WorldRenderer draws all world-space sim state (terrain, machines, ground, falling items,
	# lighting). It reads the sim and the aim state pushed each frame and never mutates anything. Its draw
	# sits at z 0 and its lighting at z 50/51, so the player at z 60 stays crisp on top.
	_renderer = WorldRenderer.new()
	_renderer.setup(sim, _falling, _player)
	_renderer.particles = _particles
	_renderer.payouts = _payouts
	_renderer.bazaars = _bazaars
	_renderer.set_dig_marks(_dig_marks)   # a live reference: the overlay tracks the plan as it is painted
	add_child(_renderer)

	# Hand the HUD minimap a material-colour lookup (the renderer owns the MaterialDef registry) so the
	# map can paint terrain without the HUD depending on the renderer's internals.
	hud.minimap_color = _renderer.material_color

	_setup_post_fx()
	_prime_breach_watch()   # pre-breached engines must not boom at boot

	# The lamp tint survives reloads via the static; apply it to the view.
	_renderer.lamp_color = LAMP_TINTS[clampi(MainView.boot_tint, 0, LAMP_TINTS.size() - 1)]["color"]
	# A real boot opens on the new-game screen; a scripted boot, launched with --script, lands straight in the
	# live world.
	if not _is_scripted_boot() and not MainView.boot_skip_title:
		_open_title()
	MainView.boot_skip_title = false


## Was this process launched to run a script rather than the game?
static func _is_scripted_boot() -> bool:
	for arg: String in OS.get_cmdline_args():
		if arg == "--script" or arg == "-s":
			return true
	return false


func _open_title() -> void:
	_title_open = true
	_paused = true
	_title_seed = sim.world_seed
	_title_tint = clampi(MainView.boot_tint, 0, LAMP_TINTS.size() - 1)
	if _player != null:
		_player.auto_input = false        # the miner stands still behind the veil


## ENTER on the title: an unchanged seed just drops the veil; a new seed rebuilds the whole session
## through the boot statics (they survive reload_current_scene).
func _confirm_title() -> void:
	MainView.boot_tint = _title_tint
	if _title_seed != sim.world_seed:
		MainView.boot_seed = _title_seed
		MainView.boot_skip_title = true
		get_tree().reload_current_scene()
		return
	_dismiss_title()


## Close the title veil over this world (no reboot) and hand control to the body.
func _dismiss_title() -> void:
	MainView.boot_tint = _title_tint
	_renderer.lamp_color = LAMP_TINTS[_title_tint]["color"]
	_title_open = false
	_paused = false
	if _player != null:
		_player.auto_input = true


## Modern-rendering layer: a WorldEnvironment post-process. Bloom on the additive light pools (head-lamp,
## ore stream, machine glow, forge embers) so warm light blooms into the dark, plus a gentle colour grade.
## HDR-2D lets the additive pools exceed 1.0, so only genuine light blooms and flat UI does not. Pure
## representation, and the sim never knows. Vignette and film grain ride on a separate screen shader.
func _setup_post_fx() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.28
	env.glow_strength = 0.85
	env.glow_bloom = 0.0                   # no whole-image lift: halo only the already-bright pixels
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
	# The grade. Kept gentle, since legibility comes first, but numbers close to identity leave the world a
	# same-value brown and grey jumble the eye cannot get purchase on. Saturation is the lever that does the
	# most here and costs the least: it separates dirt from rock from ore from machine by hue, where a
	# contrast push would crush an underground that is already near-black. Contrast rises a little for form,
	# and brightness a little more to hold the darks up under it, so the deep stays readable.
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 1.18
	env.adjustment_brightness = 1.03
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_setup_ambient_motes()

	# The screen-space lens pass: vignette, film grain and a whisper of chromatic aberration on a full-screen
	# ColorRect, on a CanvasLayer below the HUD (layer 5 against the HUD's 10), so the world gets the lens and
	# the UI stays crisp. Reads the composited screen; sits under the WorldEnvironment glow.
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 5
	var lens := ColorRect.new()
	lens.material = ShaderMaterial.new()
	(lens.material as ShaderMaterial).shader = load("res://scenes/post_fx.gdshader")
	lens.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(lens)
	add_child(fx_layer)
	_lens = lens


## A continuous GPUParticles2D haze of dust motes drifting in the air. It fills the camera view,
## repositioned to the camera each frame, and sits at z 45, below the lighting veil (z 50) and the light
## pools (z 51), so a mote is dark in the gloom and lit warm where the lamp or a glow reaches it. Pure
## atmosphere; never touches the sim.
##
## The field also carries a wind, which is your own travel turned around. Below a walk there is none and
## past that it builds with the speed over the cap, so the swing and the long fall stir the air where a
## stroll does not. It is applied as the field's gravity, so the existing damping gives it inertia for
## free and the air takes a moment to get moving and a moment to settle.
const MOTE_SETTLE: float = 5.0        ## the ambient downward drift the field was tuned with
const MOTE_WIND_FROM: float = Player.RUN_SPEED   ## px/s of travel below which the air is simply still
const MOTE_WIND: float = 1.2          ## px/s^2 of wind per px/s of travel over that
const MOTE_WIND_EASE: float = 3.5     ## how quickly the air catches up with you
var _mote_wind: Vector2 = Vector2.ZERO


func _drive_mote_wind(delta: float) -> void:
	var mat: ParticleProcessMaterial = _motes.process_material as ParticleProcessMaterial
	if mat == null or _player == null:
		return
	var v: Vector2 = _player.velocity
	var over: float = maxf(0.0, v.length() - MOTE_WIND_FROM)
	var want: Vector2 = Vector2.ZERO if over <= 0.0 else -v.normalized() * over * MOTE_WIND
	_mote_wind = _mote_wind.lerp(want, 1.0 - exp(-MOTE_WIND_EASE * delta))
	mat.gravity = Vector3(_mote_wind.x, MOTE_SETTLE + _mote_wind.y, 0.0)


func _setup_ambient_motes() -> void:
	var view: Vector2 = VIEWPORT / _current_zoom()    # world area the camera shows (render viewport / zoom)
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(view.x * 0.6, view.y * 0.6, 1.0)  # a touch wider than the view
	mat.direction = Vector3(0.2, 1.0, 0.0)
	mat.spread = 180.0
	mat.gravity = Vector3(0.0, MOTE_SETTLE, 0.0)             # a barely-there settle
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 11.0
	mat.damping_min = 1.0
	mat.damping_max = 4.0
	mat.scale_min = 0.5
	mat.scale_max = 2.1
	# The field was tuned down to 0.20 alpha and 55 particles to stop it fogging the screen, and overshot into
	# invisibility. Denser and a touch brighter, with a wider size range so near motes read as near: enough
	# that the air is visibly moving in a still frame, and still well under the fog line that motivated the
	# original cut.
	mat.color = Color(1.0, 0.94, 0.82, 0.26)                 # warm dust
	mat.turbulence_enabled = true                            # organic, swirling drift
	mat.turbulence_noise_strength = 5.0
	mat.turbulence_noise_scale = 1.4
	_motes = GPUParticles2D.new()
	_motes.process_material = mat
	_motes.texture = _make_mote_texture()
	_motes.amount = 95                                       # atmosphere, not a snowstorm
	_motes.lifetime = 7.0
	_motes.preprocess = 5.0                                  # start with a full field, not an empty screen
	_motes.z_index = 45
	_motes.z_as_relative = false
	add_child(_motes)


## A tiny soft round dot for a single mote, with radial alpha falloff, so motes read as out-of-focus specks
## of dust rather than as hard pixels.
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


## Build the starting world through the world-engine handshake: a swappable WorldGen produces a WorldData
## (two material grids) and the sim ingests it, so MainView does not know how the world is made and
## swapping the generator changes nothing here. Then stamp the starting fixtures: a starter ore vein beside
## spawn, and the mineshaft, a shallow carved shaft over a rich vein with a forge already in its mouth. You
## hand-feed that forge to bootstrap, then cap it with a Drill so it feeds itself: the forge is constant,
## and what you automate is the feeding you were doing by hand.
## The flat spawn surface row. Every spawn-side fixture (mineshaft, vein, tree, forge) is placed relative
## to it, so pushing the surface down for sky moves them all together. Mirrors HeightmapWorldGen's constant.
const SURFACE := HeightmapWorldGen.FLAT_SURFACE_ROW
## The spawn cluster is laid out on the map-centred plateau, left→right, so nothing ever traps the body:
##   The bazaar (cols 40-43) is a walk-through stall, since its wood frame does not collide, claimed from
##     its right post (col 44) so the finishing block faces spawn. The open shaft (col 56) is the one real
##     blocking endpoint, only ever reached from its left edge (col 55). Everything between is benign to
##     walk: dug vein, step-over forge, coal on top. The tree (col 51) is felled for wood.
##   col 40-43 bazaar ruin, col 46 forge, cols 47-48 vein, col 49 spawn, col 51 tree, col 54 coal, col 56 shaft
const SPAWN_COL: int = 49
const MINESHAFT_COL: int = 56
const MINESHAFT_FORGE_CELL := Vector2i(46, SURFACE)                  ## bootstrap forge in a shallow surface pocket: toss ore in from col 45, collect ingots below. Off the shaft so it stays an open drop.
## Reach invariant: the drill cell sits at SURFACE+1 and no deeper, so the body places the drill and tosses
## coal down the mouth from the surface edge (col 55) with a comfortable reach margin and without entering
## the pit. Placing it deeper left only about a 4px margin, tipping the body into the shaft to be trapped.
const MINESHAFT_DRILL_CELL := Vector2i(MINESHAFT_COL, SURFACE + 1)   ## open cell: drop the Drill here, above the ore vein
const MINESHAFT_ORE_CELL := Vector2i(MINESHAFT_COL, SURFACE + 2)     ## the visible solid ore vein the drill bores down into
const AUTO_FORGE_CELL := Vector2i(MINESHAFT_COL, SURFACE + 3)        ## the automated line's forge, below the ore, catching the bored ore's fall
const MINESHAFT_ORE_RICHNESS: int = 400                              ## a rich starter-automation patch the drill runs on for a long time
## A visible ore vein breaching the surface beside spawn: the metal-flecked rock the first objective points
## at, and the bootstrap ore you hand-mine for the first ingots. Depth-banded worldgen leaves the shallow
## surface near-bare, so onboarding cannot rely on finding a vein. One tall and two wide, so it reads as a
## vein while mining it leaves only a one-tile trench you step straight out of; a two-deep pit would trap
## the body, since step-up climbs one tile. Realized by WorldSeeder.
const STARTER_VEIN_CELL := Vector2i(47, SURFACE)
## A guaranteed surface coal block between the shaft and the bazaar: the drill's fuel. Once you cap the
## deposit with a drill it will not run without coal, so this is the go-mine-coal target that closes the
## demand web. Placed at col 54, one left of the shaft's edge (55) on the rightward path, so mining it and
## tossing coal down the open shaft (56) is a short step. Rich enough that one hand-burst of 3-8 fuels the
## drill well past its deposit. Realized by WorldSeeder.
const TUTORIAL_COAL_CELLS: Array[Vector2i] = [Vector2i(54, SURFACE)]
## A guaranteed tutorial tree on the surface between spawn and the shaft: the wood source the bazaar step
## needs, since depth-banded worldgen plants trees out past the ruin, unreachable on the surface early.
## Trees are walk-through (Player._blocked passes wood and leaves), so a trunk sitting on the tutorial path
## is fine: the body strolls through it and chops it in passing, with no walling even for the taller body.
## Crowned with leaves so it reads and fells as a real tree. Realized by WorldSeeder.
const TUTORIAL_TREE_COL := 51
## The starter adit (docs/LODE.md): a small stepped cut into the ground beside spawn whose back wall shows
## an ore lode, needing no digging to find.
##
## With ore in the background plane a first-time player has nothing to aim at: every vein in the world is
## behind rock, and no surface stain telegraphs them through stone yet. The adit hands you a face instead.
## The rock is already gone and the vein is already showing, so the first swing teaches the real loop of
## clearing rock and working what is behind it. Past the face the vein continues down behind solid rock,
## which is the second half of the lesson: what you can see is the end of something, and the way to get
## more of it is to dig along it.
##
## The cut, cell by cell, relative to SURFACE. Two of its three constraints are the body's. It is two rows
## tall everywhere, because the body is 34px against a 32px cell and does not fit in one, so a one-row cut
## is a trench you look into rather than a place you go. It descends one row per column and opens the new
## row without closing the old one, so every column overlaps its neighbour by a row and the corridor is
## walkable at transit height. Without that overlap the step down is impassable: the body's head meets
## solid rock at every step, in a passage a floor-only check still calls a corridor.
##
## The third constraint is that it is sealed. A notch open to the sky puts a hole in the walking surface
## beside spawn, and that surface is not spare ground. It is the corridor the opening walks (spawn 49,
## tree 51, coal 54, shaft 56) and the runway every motion measurement runs on, and there is no unclaimed
## stretch of it. So the roof is unbroken and the cave is a pocket, plainly visible from the surface anyway
## because this game draws the ground it has not dug. You see the vein before you can reach it, and one
## swing at the roof drops you in.
const ADIT_COLS: Array[int] = [52, 53]                ## the roof you break, and the room it opens into
const ADIT_CHAMBER_COL: int = 54                      ## the deepest end, under the tutorial coal
const ADIT_ROOF: int = 1                              ## rows of intact ground over the pocket, so the surface stays whole
const ADIT_FACE_AMOUNT: int = 45                      ## per exposed cell: the first ingots, and not much more
const ADIT_DEEP_AMOUNT: int = 120                     ## per buried cell: the reason to follow it down

## The world builder. MainView owns the layout constants above, which are the canonical contract;
## scenes/world_seeder.gd is the procedure that realizes them (the tutorial fixtures, the starter kit and
## the optional dev pack) onto the freshly-loaded sim. Preloaded by path rather than class_name so headless
## drivers resolve it without a refreshed global-class cache.
const WorldSeeder := preload("res://scenes/world_seeder.gd")


func _seed_world() -> void:
	var gen: WorldGen = LayeredWorldGen.new()
	var seed: int = MainView.boot_seed if MainView.boot_seed >= 0 else default_seed()   # the title screen's pick
	var world: WorldData = gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, seed)
	sim.load_world(world)   # stamps `sim.world_seed`, the single authority from here on
	WorldSeeder.seed_tutorial(sim, dev_start)


## Rack the world out of focus behind the counter, tracking the HUD's own open ease so the blur arrives
## with the panel rather than snapping on. Nothing else in the frame is touched: the lens layer sits below
## the HUD, so the counter, the hotbar and every readable glyph stay crisp.
func _update_defocus() -> void:
	if _lens == null or _hud == null:
		return
	var mat: ShaderMaterial = _lens.material as ShaderMaterial
	if mat != null:
		# The settings page racks it too. Whichever modal is up owns the lens; taking the max rather than adding
		# them means opening one while the other falls does not double the blur.
		mat.set_shader_parameter("defocus",
			maxf(maxf(_hud._bazaar_ease(), _hud.settings_ease()), _hud.plain_modal_ease()) * 3.4)


func _process(delta: float) -> void:
	if not _paused:
		sim.advance(delta)
		_falling.spawn_from_events(sim, _cell_center)
		_falling.advance(delta)
		_land_drops()
		_age_drop_grace(delta)
		_collect_ground_under_player()
	_update_mining(delta)  # refreshes _aim from the mouse
	_update_bazaars(delta)
	_update_juice(delta)
	_update_defocus()
	if _camera != null:
		# Soft follow toward the body, then pixel-snap the render so the terrain does not shimmer in motion. A big
		# jump (spawn, an F9 load, a teleport) snaps instead of panning across the whole world, which also keeps
		# the frame centred the instant anything repositions the body.
		#
		# Look-ahead: the camera leads the body along its own velocity, so at speed you see where you are going
		# rather than where you have been. Without it a swing or a long fall spends its most interesting half
		# off-screen and the player brakes to see. The lead is capped in world px and eased so it does not
		# lurch on a direction change, and it goes to zero at a standstill. It leads further once the miner
		# is running, because a camera that holds the body dead centre at full stride cancels the stride: the
		# ground scrolls faster and the frame looks identical.
		var lead: Vector2 = _player.velocity * (CAMERA_LEAD_TIME * (1.0 + STRIDE_LEAD * _player.stride))
		lead.y *= CAMERA_LEAD_VERTICAL      # vertical space is scarcer on a 16:9 frame; lead into it gently
		_cam_lead = _cam_lead.lerp(lead.limit_length(CAMERA_LEAD_MAX),
			1.0 - exp(-CAMERA_LEAD_EASE * delta))
		var target: Vector2 = _player.global_position + _cam_lead
		if _cam_pos.distance_to(target) > VIEWPORT.x / _current_zoom() * 0.5:
			_cam_pos = target
		else:
			_cam_pos = _cam_pos.lerp(target, 1.0 - exp(-CAMERA_FOLLOW_SPEED * delta))
		_camera.global_position = snap_to_pixel(_cam_pos, _current_zoom())
	if _motes != null and _camera != null:
		_motes.position = _camera.get_screen_center_position()  # keep the haze over the view
		_drive_mote_wind(delta)
	if _objectives != null:
		_objectives.refresh(delta)
		if not _line_hailed and _objectives.is_done(&"auto"):
			_line_hailed = true
			_hail_the_line()
	if _hints != null and not _paused:
		if _player != null:
			_hints.note_in_water(_player._in_water())   # feed the body's wet state for the aquifer hint
			var pc: Vector2i = _cell_at(_player.position)
			# ...and its depth, for the grapple hint. Against the generated ground for the same reason as the ambience
			# bed below: the hint fires at DEPTH_HINT_ROWS, rows below the local surface that make the climb a real
			# trip, and `sim.surface_row` hands back the floor of the shaft you are standing in, so the number it fed
			# could not reach 10 by digging. A hint about the climb out of your own hole was unreachable by digging a
			# hole.
			_hints.note_depth(pc.y - HeightmapWorldGen.ground_row(pc.x))
			_note_rope_moments()                              # ...and the three the rope teaches by itself
			# A bubble's clock only runs while you could plausibly have read it. This threshold sits just above a
			# cruise: walking and reading is fine, flying and reading is not. Grappling and falling are both speed, so
			# one threshold covers them together with fast movement. Aiming is deliberately excluded, because the
			# cursor is live every frame of normal play and gating on it would suppress the lesson permanently.
			#
			# Hysteresis, or the bubble strobes: on one threshold a body cruising near it flips busy on and off
			# every few frames and the lesson flickers, which is a suppression rule worse than no rule. It arms
			# at 1.25x stride and releases only below 0.9x.
			var spd: float = _player.velocity.length()
			_hint_busy = (spd > Player.RUN_SPEED * (0.9 if _hint_busy else 1.25))
			_hints.note_busy(_hint_busy)
			# ...and whether the ceremony currently owns the announce channel, so a lesson waits for it rather than
			# being stacked under it. Read from the HUD rather than mirrored here: a second copy of "is the plate up"
			# is a second thing that can be wrong, and only one of them draws.
			#
			# AND THIS LINE READ THE WRONG ONE, under that exact comment. `announcing()` is the
			# plate's LIFETIME; `plate_on_screen()` is its VISIBILITY, and they differ for as long as a line is out,
			# because a plate in flight when the rope goes live has its clock frozen rather than dropped. A lesson
			# gated on the first waits behind a plate nobody can see. `wrapped` fires only while a line is live, so
			# the rope lesson was suppressed by the rope.
			_hints.note_ceremony(_hud.plate_on_screen())
			# The feet, not the body centre: standing on the grass, the centre cell is the air above it, which read as
			# open sky while the miner was plainly stood on the ground.
			_note_stratum(_cell_at(_player.position + Vector2(0.0, Player.HEIGHT * 0.5 + 2.0)).y)
			# Is the sapling lesson an instruction yet? Both halves of "a seed in the pack and the cursor on
			# ground that would take one" are the sim's own planting guards, asked through
			# `can_plant_sapling`. What the bubble promises and what the click does cannot come apart.
			# Reach is ours to add: the sim owns no avatar, and out past REACH_CELLS the RMB at try_build
			# refuses whatever the ground under the cursor says.
			_hints.note_relevant(Hints.SAPLING_GATE, _can_reach(_aim) and sim.can_plant_sapling(_aim))
		_hints.refresh(delta)
	# Push the cursor and its affordances to the view; it cannot derive reach or placeable itself.
	_renderer.set_aim(_aim, _can_reach(_aim), _placeable_here(_aim), _selected_machine_def(),
		_selected_build_material(), _drive_bites(_aim))
	_renderer.set_guide_targets(_guide_targets())   # pulse where the current objective happens
	if _hud != null:
		# The config-panel pin: while the cursor sits on the inspector itself, keep showing the machine it opened
		# for, or reaching for a knob would move the aim and close the panel.
		if _cursor_on_hover_panel() and sim.machine_at(_hover_latch) != null:
			_hud.hover_info = _hover_info_at(_hover_latch)
		else:
			_hud.hover_info = _hover_info()
			var hm: MachineState = sim.machine_at(_aim)
			_hover_latch = hm.cell if (hm != null and not _hud.hover_info.is_empty()) else Vector2i(-9999, -9999)
		_hud.inventory_open = _inventory_open
		_hud.can_craft = _near_bazaar()         # the E screen reveals recipes only at the Bazaar
		_hud.show_minimap = _minimap_mode > 0
		_hud.minimap_large = _minimap_mode == 2
		_hud.rope_active = _player.grapple.state != Grapple.State.IDLE
		_hud.ping_world = _ping_world
		_hud.show_help = _show_help
		_hud.show_dashboard = _show_dashboard
		_hud.alerts = sim.machine_problems()    # stalled machines feed the left-edge alert stack
		_hud.settings_open = _settings_open
		_hud.settings_capture = _capture_action
		_hud.title_info = {} if not _title_open else {
			"seed": _title_seed, "tint": _title_tint,
			"tint_name": str(LAMP_TINTS[_title_tint]["name"]),
			"tints": LAMP_TINTS,
			# The backup counts. If the slot was damaged, the one thing the title must not do is hide the Continue
			# prompt: that is the moment a recoverable save becomes an unrecovered one.
			"has_save": FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + SaveGame.BAK_SUFFIX),
		}
		_hud.time_scale = TIME_SCALES[_time_scale_idx]
		if _player != null:
			_hud.minimap_focus = _player.position
			_hud.minimap_view = VIEWPORT / _current_zoom()  # world area the camera shows (render viewport / zoom)
		# The hint bubble: text and fade from the tracker, anchored just over the miner's head.
		if _hints != null:
			_hud.hint_text = _hints.active_text()
			_hud.hint_alpha = _hints.active_alpha()
			if _player != null:
				# canvas transform maps world → RENDER-viewport (1280×720); the HUD draws in Hud.CANVAS
				# (640×360) scaled by HUD_SCALE, so bring the mapped point back into HUD-draw space.
				# A gated lesson points at its cell rather than at the miner. The bubble used to hang over
				# the head whatever it was about, so the planting lesson covered the ground it was
				# describing and the tree beside it. A lesson with a relevance gate is only on screen
				# because the cursor is over a cell that satisfies it, so that cell is the subject. The
				# bubble draws above its anchor with the tail reaching down, so anchoring a cell-high above
				# the cell points at it without sitting on it.
				var anchor: Vector2 = _player.position + Vector2(0.0, -Player.HEIGHT * 0.5 - 6.0)
				if _hints.active_gate() != &"":
					anchor = _cell_center(_aim) + Vector2(0.0, -float(CELL) * 0.5 - 6.0)
				_hud.hint_anchor = (get_viewport().get_canvas_transform() * anchor) / HUD_SCALE
			# AND WHAT THE LESSON IS ABOUT, through the same transform. `grapple.pivots` is "corners the line is
			# currently caught on", so on the grapple lesson the keep-out point IS the bend the sentence names.
			# Pushed every frame rather than latched: the line moves, and a stale keep-out point would lift the
			# plate off somewhere the rope has already left.
			var avoid: Array[Vector2] = []
			for pv: Vector2 in _player.grapple.pivots:
				avoid.append((get_viewport().get_canvas_transform() * pv) / HUD_SCALE)
			_hud.hint_avoid = avoid


## Reconcile the Bazaar view against the sim's detected frames. When one completes this frame, throw a
## burst of sparks and a shake at its centre, so the cosmetic transform reads as a real event.
func _update_bazaars(delta: float) -> void:
	for origin: Vector2i in _bazaars.update(sim, delta):
		var c: Vector2 = _bazaars.center_of(origin)
		_particles.dust(c + Vector2(0.0, -CELL), Color(1.0, 0.86, 0.5), 26)
		_particles.spark(c + Vector2(0.0, -CELL), Color(0.93, 0.84, 0.60))
		_particles.pop(c + Vector2(0.0, -CELL), Color(0.30, 0.62, 0.60))
		_shake = maxf(_shake, 3.6)
		_sfx.ui(&"chime", 1.2)


## Drive the cosmetic juice: advance particles, kick dust on a hard landing and on periodic footsteps, and
## decay the screenshake into the camera offset. None of this touches the sim.
func _update_juice(delta: float) -> void:
	_particles.advance(delta)
	_payouts.advance(delta)
	# The line's voice. A piton biting rock is a hard, close, percussive event and it wants to be felt: chips
	# off the anchor, a crack, and a small kick of shake so the plant lands in the hands. The release is the
	# opposite, a soft whip of nothing. Both are one-shot flags the body raises inside its substep, so they
	# fire exactly once per event no matter how the frame was subdivided.
	if _player != null:
		var g: Grapple = _player.grapple
		if g.just_planted:
			_particles.spark(g.anchor, Color(0.90, 0.84, 0.66))
			_sfx.play(&"crunch", g.anchor, 1.6, -4.0)
			_shake = maxf(_shake, 1.6)
		elif g.just_cut:
			_sfx.play(&"pop", _player.position, 1.7, -12.0)
		# The held voices. The drum while it hauls and the fibre singing under load are level-driven beds rather
		# than one-shots, so they are pushed every frame, including the frames where the level is zero, which is
		# what lets them go quiet instead of hanging on. This wiring is the whole reason they exist: the
		# generators, the streams and the set_line driver all shipped and nothing ever called it, so the winch and
		# the line were silent in the game while the audio layer passed on buffers it poked by hand.
		var haul: float = 0.0
		if g.state == Grapple.State.ANCHORED and delta > 0.0:
			haul = clampf((g.hauled / delta) / Grapple.REEL_SPEED, 0.0, 1.0)
		_sfx.set_line(haul, _line_load(g), delta)
		# A catch: the line taking a new corner. The rising edge of the pivot count is the event, and it is the one
		# rope event with no other tell, since the rope silently changes shape and your arc with it.
		if g.pivots.size() > _line_pivots:
			_sfx.play(&"catch", g.hitch(), 1.0, -7.0)
			_particles.spark(g.hitch(), Color(0.82, 0.76, 0.60))
		_line_pivots = g.pivots.size()
	# Sonar pacing and the staggered returns: each scheduled ding fires when the wavefront, whose speed the
	# renderer owns, actually reaches its vein, so the distance is audible.
	_scan_cooldown = maxf(0.0, _scan_cooldown - delta)
	for i: int in range(_scan_dings.size() - 1, -1, -1):
		var d: Dictionary = _scan_dings[i]
		d["at"] = float(d["at"]) - delta
		if float(d["at"]) <= 0.0:
			_sfx.play(&"ding", d["pos"], 1.7, -10.0)
			_scan_dings.remove_at(i)
	# The factory heartbeat: the hum swells with how much machinery is working near you and fades as you walk
	# away, so the base you built is a presence you can hear before you see it.
	if _player != null and _sfx != null:
		var working: float = 0.0
		var near_sq: float = pow(14.0 * float(CELL), 2.0)
		for m: MachineState in sim.machines:
			if _player.position.distance_squared_to(_cell_center(m.cell)) < near_sq \
					and sim.machine_status(m) == &"working":
				working += 1.0
		_sfx.set_hum(working / 5.0, delta)
		# Ambience beds: where the body is, heard. Wind above ground, dying within a few rows of descent; cave air
		# with intermittent drips, swelling to full about 10 rows under the surface of your column. Crossfaded
		# inside Sfx, so climbing a shaft trades earth for sky.
		#
		# Measured against the generated ground rather than `sim.surface_row`, which scans for the first solid
		# cell and so starts answering with the floor of your own shaft the moment you dig: `below` pins to about
		# -1 forever, which is full surface wind and a silent cave bed at the bottom of a forty-row hole. The bed
		# that exists to sell descent was loudest exactly where descent had happened.
		var below: float = float(_body_cell().y - HeightmapWorldGen.ground_row(_body_cell().x))
		_sfx.set_ambience(clampf(1.0 - below / 4.0, 0.0, 1.0), clampf(below / 10.0, 0.0, 1.0),
			_player.position, delta)
		# The rush: how fast you are going, heard. Measured from RUN_SPEED up, so a walk is the zero point,
		# because the sound has to mean faster than you can run, which is the only speed the rope and a sinkhole
		# ever give you. Ordinary mining never whistles, and a forty-row drop stops sounding exactly like standing
		# still.
		var fast: float = _player.velocity.length()
		_sfx.set_rush(clampf((fast - Player.RUN_SPEED) / (Player.MAX_FALL - Player.RUN_SPEED),
			0.0, 1.0), delta)
		# The score: where ambience says where you are, the score says what it means, and the only thing that
		# reliably means something in a game about descending is depth. The music is a pure function of it, using
		# absolute row rather than depth below your own column, because a shaft dug straight down and a shaft
		# reached by walking into a rift are the same distance from the sky and should sound the same. Mix, key
		# colour and pitch live inside Score.
		_score.set_depth(float(_body_cell().y) / float(FactorySim.GRID_ROWS - 1), delta)
		# Water audio: a soft pour bed that swells with how much falling or pouring water is near you, and a wet
		# pump drain while a pump near you is draining. Both are level-driven like the heartbeat, smoothed and
		# fading to silence inside Sfx.set_water. Reads the same pouring rule the renderer's water drips use (the
		# cell below is open, not full and not rock), so what you see pour is what you hear. Bounded: only cells
		# within near_sq are examined.
		var pour: float = 0.0
		for wkey: Variant in sim.water:
			var wc: Vector2i = wkey
			if int(sim.water[wc]) <= 0:
				continue
			if _player.position.distance_squared_to(_cell_center(wc)) >= near_sq:
				continue
			var wbelow: Vector2i = wc + Vector2i(0, 1)
			if sim.in_bounds(wbelow) and not sim.is_solid(wbelow) \
					and sim.water_at(wbelow) < FactorySim.WATER_MAX:
				pour += 1.0                                  # this cell is actively pouring near you
		var pumping: float = 0.0
		for m: MachineState in sim.machines:
			if m.def.behavior == &"pump" \
					and _player.position.distance_squared_to(_cell_center(m.cell)) < near_sq \
					and sim.machine_status(m) == &"working":
				pumping += 1.0
		_sfx.set_water(clampf(pour / 4.0, 0.0, 1.0), clampf(pumping / 2.0, 0.0, 1.0), delta)
		# The breach stinger: a Descent Engine reaching quota bores the seal open, a once-per-world event that
		# deserves a sound the size of the moment. Edge-latched per engine; _prime_breach_watch marks engines that
		# were already breached on a fresh seed or a loaded save, so only a breach on your watch booms.
		for m: MachineState in sim.machines:
			if m.def.behavior == &"descent" and m.fed >= FactorySim.DESCENT_QUOTA \
					and not _breach_heard.has(m.cell):
				_breach_heard[m.cell] = true
				_sfx.play(&"boom", _cell_center(m.cell), 1.0, 8.0)
				_shake = maxf(_shake, 7.0)
	if _player != null:
		var feet: Vector2 = _player.position + Vector2(0.0, Player.HEIGHT * 0.5)
		if _player.landed_hard:
			# Landing juice scales with impact: a step-off puffs, a terminal drop thuds and kicks.
			var imp: float = clampf((_player.last_impact - 240.0) / (Player.MAX_FALL - 240.0), 0.0, 1.0)
			_particles.dust(feet, Color(0.42, 0.32, 0.22), 6 + int(imp * 14.0))
			_shake = maxf(_shake, 1.8 + imp * 3.4)
			_sfx.play(&"thump", feet, 0.6 + imp * 0.5, -5.0)
		# Footsteps, one every ~22px travelled, with a noise and the right colour of dust. Walking is the most
		# frequent thing a player does here, and silent steps over a hardcoded brown puff read as a sprite
		# sliding across a picture rather than a person standing on ground. The material underfoot drives
		# both: harder rock scuffs higher and drier, on the same hardness-to-pitch mapping the mining crunch
		# uses, and the puff is that rock's own colour, so a stone floor never throws dirt.
		if _player.on_floor and absf(_player.velocity.x) > 20.0:
			_step_dist += absf(_player.velocity.x) * delta
			if _step_dist >= 22.0:
				_step_dist = 0.0
				var ground: StringName = sim.material_at(_cell_at(feet + Vector2(0.0, 2.0)))
				var puff: Color = _renderer.material_color(ground) if ground != &"" \
					else Color(0.40, 0.30, 0.20)
				# A running miner kicks more of the floor up than a walking one, and the puff is the only thing on screen
				# that says the ground is being pushed against rather than slid over.
				_particles.dust(feet, puff.lightened(0.10), 3 + int(round(4.0 * _player.stride)))
				# Quiet on purpose: this fires several times a second, so it has to sit under everything.
				var scuff: float = clampf(1.35 - MiningRules.hardness(ground) * 0.09, 0.85, 1.35)
				_sfx.play(&"step", feet, scuff, -19.0)
		else:
			_step_dist = 0.0
	_shake = move_toward(_shake, 0.0, delta * 24.0)
	if _camera != null:
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)) \
			if _shake > 0.05 and Settings.screen_shake else Vector2.ZERO


## Controls, all through remappable InputMap actions (see Controls): 1-8 select hotbar slots rather than
## crafting, E opens the crafting screen where the numbers craft, the wheel cycles the hotbar, Q drops the
## selected stack so gravity feeds it in, M map, H help. Feeding is a drop rather than a deposit, which
## leaves E free for the crafting screen. The numeric row stays a direct keycode, a fixed convention; every
## other binding routes through Controls so a settings page can rebind it.
func _unhandled_input(event: InputEvent) -> void:
	# The title eats all input while open: TAB rerolls the seed, left and right pick the lamp, ENTER or SPACE
	# descends, C continues the save. Everything else waits behind the veil.
	if _title_open:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_TAB:
					_title_seed = randi() % 1000000
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_confirm_title()
				KEY_C:
					_dismiss_title()   # continue: the save brings its own world, so seed rerolls are moot
					_load_game()
			if event.keycode == KEY_LEFT or event.keycode == KEY_A:
				_title_tint = (_title_tint + LAMP_TINTS.size() - 1) % LAMP_TINTS.size()
			elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
				_title_tint = (_title_tint + 1) % LAMP_TINTS.size()
		return
	# The settings overlay eats all input while open: sliders, chips and the key-capture flow.
	if _settings_open:
		_settings_input(event)
		return
	# Retire the bottom-left key hint one entry at a time, as each key is actually used. Done here, above the
	# whole if/elif chain, rather than inside each branch: a hint that retires on some of its keys and not
	# others is worse than one that never retires, and five scattered call sites is how that happens. Every
	# hinted action, grapple included, is dispatched by this one chain, so one loop sees all of them.
	for row: Array in Hud.HINT_KEYS:
		if event.is_action_pressed(row[0]):
			_hud.note_hint_used(row[0])
			break
	if event.is_action_pressed(Controls.PAUSE):
		_paused = not _paused
	elif event.is_action_pressed(Controls.CRAFT):
		# E always lands on the pack tab, the one you want when you pressed the pack key.
		if _inventory_open and _hud.bazaar_tab == Hud.TAB_PACK:
			_inventory_open = false
		else:
			_inventory_open = true
			_hud.set_bazaar_tab(Hud.TAB_PACK)
	elif event.is_action_pressed(Controls.DROP):
		try_drop()
	elif event.is_action_pressed(Controls.MAP):
		_minimap_mode = (_minimap_mode + 1) % 3          # hidden, corner, large, hidden
	elif event.is_action_pressed(Controls.MUTE):
		_toggle_mute()
	elif event.is_action_pressed(Controls.HELP):
		_show_help = not _show_help
	elif event.is_action_pressed(Controls.TECH):
		# T is a tab of the counter rather than a second screen: the ladder and the verb that acts on it are the
		# same panel (docs/BAZAAR.md).
		if _inventory_open and _hud.bazaar_tab == Hud.TAB_BENCH:
			_inventory_open = false
		else:
			_inventory_open = true
			_hud.set_bazaar_tab(Hud.TAB_BENCH)
	elif event.is_action_pressed(Controls.DASHBOARD):
		_show_dashboard = not _show_dashboard
	elif event.is_action_pressed(Controls.CLOSE):
		# ESC closes whatever is open; with nothing open it opens settings, the pause-menu convention.
		if _inventory_open or _show_help or _show_dashboard or _minimap_mode != 0:
			_inventory_open = false
			_show_help = false
			_show_dashboard = false
			_minimap_mode = 0
		else:
			_settings_open = true
	elif event.is_action_pressed(Controls.RESEARCH) and not _inventory_open:
		# R is one verb. Two verbs on one key, research and configure-the-thing-you-are-aiming-at,
		# disambiguated by context, is something a player has to be taught. Research lives on ENTER at the
		# Bench tab, where a cursor is already sitting on the rung you would buy, so R keeps the only meaning
		# it can have while you are standing in the world.
		try_configure(_aim)
	elif _inventory_open and event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE):
		_bazaar_enter()
	elif _inventory_open and event is InputEventKey and event.pressed \
			and event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_S, KEY_A, KEY_D]:
		var dy: int = (1 if event.keycode in [KEY_DOWN, KEY_S] else 0) \
			- (1 if event.keycode in [KEY_UP, KEY_W] else 0)
		var dx: int = (1 if event.keycode in [KEY_RIGHT, KEY_D] else 0) \
			- (1 if event.keycode in [KEY_LEFT, KEY_A] else 0)
		_hud.bazaar_move(dx, dy)
	elif event.is_action_pressed(Controls.BUILD):
		if not _cursor_on_minimap() and not _cursor_on_hover_panel():   # UI panels eat the click
			if _selected_item() == &"scanner":
				try_scan()                                    # the selected item defines RMB: sonar rather than build
			else:
				try_build(_aim)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and _cursor_on_alerts():
		_ping_alert(Controls.pointer_viewport(self))      # click an alert → mark the culprit
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and _cursor_on_minimap():
		_toggle_ping(Controls.pointer_viewport(self))     # click the map → set/clear the ping
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and _cursor_on_hover_panel():
		_apply_knob(_hud.hover_click(Controls.pointer_viewport(self)))   # config-panel chips
	elif event.is_action_pressed(Controls.GRAPPLE):
		_toggle_grapple()
	elif event.is_action_pressed(Controls.ZOOM):
		_cycle_zoom()
	elif event.is_action_pressed(Controls.SPEED):
		_cycle_speed()
	elif event.is_action_pressed(Controls.SAVE):
		_save_game()
	elif event.is_action_pressed(Controls.LOAD):
		_load_game()
	elif event.is_action_pressed(Controls.CLEAR_MARKS):
		if not _dig_marks.is_empty():
			_dig_marks.clear()
			_hud.flash("dig plan cleared")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		# Nothing scrolls any more, since two columns of ten rows hold everything the game can list, so the wheel
		# is free to do the thing you actually want at a counter: change counter.
		if _inventory_open: _hud.set_bazaar_tab((_hud.bazaar_tab + 1) % 3)
		else: _cycle_inventory(1)                  # otherwise: the hotbar scroll select
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if _inventory_open: _hud.set_bazaar_tab((_hud.bazaar_tab + 2) % 3)
		else: _cycle_inventory(-1)
	elif event is InputEventKey and event.pressed and not event.echo \
			and ((event.keycode >= KEY_1 and event.keycode <= KEY_9) or event.keycode == KEY_0):
		# The fixed hotbar number row; 0 is the tenth slot, since the craft list outgrew 1-9.
		var idx: int = (event.keycode - KEY_1) if event.keycode != KEY_0 else 9
		if _inventory_open:
			# While the counter is open the number row picks a tab rather than a recipe. Buying moved to a cursor and
			# Enter, which is what let the shift-digit rows, 11 through 20 on a list that had outgrown its panel, go
			# away entirely.
			if idx < 3:
				_hud.set_bazaar_tab(idx)
		else:
			_select_slot(idx)                           # otherwise they select the hotbar slot


## Input while the settings overlay is open. Two modes: normally clicks land on the page's controls (via
## Hud.settings_click payloads, the knob pattern); while capturing, the very next key or mouse button
## becomes the chosen action's new binding, and ESC cancels. The HUD never touches InputMap or the config
## file; every mutation goes through Settings here in the controller.
func _settings_input(event: InputEvent) -> void:
	if _capture_action != &"":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_capture_action = &""                    # cancel: keep the old binding
			else:
				var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				_announce_rebind(Settings.rebind(_capture_action, {"key": code}))
				_capture_action = &""
		elif event is InputEventMouseButton and event.pressed:
			_announce_rebind(Settings.rebind(_capture_action, {"button": event.button_index}))
			_capture_action = &""
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_settings_open = false
		_settings_drag = ""
		return
	# The number row picks a category, and it sits below the capture branch above, which returns before
	# reaching here. That order is the whole reason Settings is not the counter's fourth face: a page that can
	# bind any key to anything cannot also spend the digits on navigation unless capture gets them first.
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode >= KEY_1 and event.keycode <= KEY_3:
		_hud.set_settings_cat(event.keycode - KEY_1)
		return
	# Keyboard operation of the binding list. Rebinding used to require a mouse: the only way to start a
	# capture was to click a chip, which makes the one page a player goes to when their input is not working
	# the page they cannot reach without it.
	#
	# The arrows and ENTER are read as physical keys rather than as actions, on purpose. If this moved the
	# cursor with `Controls.UP`/`DOWN` then rebinding `climb up` would change how you navigate the page you
	# are rebinding it on, and rebinding it to something unreachable would strand you. Raw keycodes cannot
	# be remapped, so the page stays operable no matter what the player does to their bindings.
	#
	# It covers the whole page, not just the binding list. This block used to run the cursor over CONTROLS
	# and nothing else: `Hud.move_settings_row` returned immediately on the other two faces, so the levels,
	# the toggles and the reset-keys row had no keyboard route to them at all, and a focus state cannot be
	# drawn on a control that can never be focused.
	#
	# A level is the one control on this page that wants the key repeat, and it is the only reason this
	# branch sits above the echo guard rather than inside it. Everything else here moves a cursor or fires
	# a verb, where an echo is a runaway: a held ENTER on a feel toggle would flip it once per repeat and
	# land wherever the key happened to be released. A level is a range, and crossing it in twenty separate
	# presses is the kind of control that makes a page feel broken; the guard is lifted for exactly the one
	# case that asks for it, tested on the FOCUSED control rather than on the category, so it cannot leak.
	if event is InputEventKey and event.pressed and event.echo \
			and (event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT) \
			and _hud.settings_focus_payload().has("slider"):
		_settings_horizontal(event.keycode)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_DOWN:
				_hud.move_settings_row(event.keycode)
				return
			KEY_LEFT, KEY_RIGHT:
				_settings_horizontal(event.keycode)
				return
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_settings_activate()
				return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_apply_setting(_hud.settings_click(Controls.pointer_viewport(self)))
		else:
			_settings_drag = ""                          # slider drag ends with the button
	elif event is InputEventMouseMotion and _settings_drag != "":
		_set_volume(_settings_drag,
			_hud.settings_slider_frac(_settings_drag, Controls.pointer_viewport(self).x))


## HOW FAR ONE PRESS MOVES A LEVEL. The page prints the level as a whole percent (`%d%%` on the value
## column), so a step that is not a whole number of percent would put two presses on the same printed
## number and read as a dropped keypress. 5 gives the bar twenty stops end to end, which is a tap count
## only because the arrows also repeat; see the echo branch in `_settings_input`.
const LEVEL_STEP: float = 0.05


## LEFT and RIGHT on the settings page: ADJUST the focused control, or move the cursor when the control
## under it has nothing to adjust.
##
## One rule, and it needs no per-category branch: a level and the zoom cycle hold a RANGE and the arrows
## walk it; everything else hands the key back to the cursor. On CONTROLS that fallback is the column jump
## the two-column layout has always meant, so the shipped behaviour is untouched. It is now the general
## rule's default case rather than the only case. On AUDIO and FEEL there is one column, so the same
## fallback moves the cursor by nothing and a horizontal press on a toggle is quiet: ENTER is a toggle's
## verb, and inventing a direction for a control with two unordered states (the mute chip reads `MUTED` or
## `SOUND ON`, not `ON` or `OFF`) would be picking which of them LEFT means.
##
## The range controls are exactly the two that a keyboard could not operate at all before this: a chip can
## be activated by ENTER, but a slider has no verb, and the settings page's own controls are mostly those
## four levels.
func _settings_horizontal(keycode: int) -> void:
	var payload: Dictionary = _hud.settings_focus_payload()
	var dir: int = 1 if keycode == KEY_RIGHT else -1
	if payload.has("slider"):
		var id: String = str(payload["slider"])
		_set_volume(id, Settings.level(id) + float(dir) * LEVEL_STEP)
		return
	if str(payload.get("cycle", "")) == "zoom":
		_cycle_zoom(dir)
		return
	_hud.move_settings_row(keycode)


## ENTER / SPACE: run the focused control's own verb, through THE SAME PAYLOAD a click on it produces.
##
## `Hud.settings_row_payload` is the one table both pointers read, so there is no second opinion here about
## what a control does. The failure this page has already had once, in a page-side copy of a conflict rule
## that drifted from the resolver's, is the reason to route the keyboard through the click path rather than
## to give it a switch of its own.
##
## A SLIDER HAS NO VERB and gets none invented for it. `_apply_setting` reads a `slider` payload as the
## start of a DRAG, which is a statement about a mouse button being held and is meaningless from a key;
## LEFT and RIGHT are what move a level, and the page's own legend says so.
func _settings_activate() -> void:
	var picked: StringName = _hud.settings_row_action()
	if picked != &"":
		_capture_action = picked
		return
	var payload: Dictionary = _hud.settings_focus_payload()
	if payload.has("slider"):
		return
	_apply_setting(payload)


## Say what a rebind COST. `Settings.rebind` returns every action it took the key from; those actions are
## now `unbound`, which is visible on their own rows but only if you happen to be looking at them.
##
## A silent steal would be the original defect wearing a fix: the duplicate would be gone and the player
## would still not know what happened to the binding they lost.
func _announce_rebind(displaced: Array[StringName]) -> void:
	if displaced.is_empty():
		return
	var names: Array[String] = []
	for a: StringName in displaced:
		# What it lost, rather than that it died. A rebind takes only the one event that collided: take the
		# up arrow from `climb up` and it keeps W and the stick, so a flat "unbound" would be a false alarm
		# about a binding that still works.
		var left: String = Settings.binding_label(a)
		names.append("%s unbound" % Hud.action_label(a) if left == "unbound"
			else "%s now %s" % [Hud.action_label(a), left])
	_hud.flash("%s — that key is taken" % " and ".join(names))


## Sound on or off, from the key or from the settings chip, saying so on screen either way: a mute you
## cannot see the result of is indistinguishable from a game whose audio has broken.
func _toggle_mute() -> void:
	_hud.flash("sound OFF" if Settings.toggle_mute() else "sound ON")


func _apply_setting(payload: Dictionary) -> void:
	if payload.has("slider"):
		_settings_drag = str(payload["slider"])          # press starts a drag; motion keeps updating it
		_set_volume(_settings_drag, float(payload.get("frac", 0.0)))
	elif payload.get("toggle", "") == "shake":
		Settings.screen_shake = not Settings.screen_shake
		Settings.save_settings()
	elif payload.get("toggle", "") == "mute":
		_toggle_mute()
	elif payload.get("toggle", "") == "auto_pickup":
		Settings.auto_pickup = not Settings.auto_pickup
		Settings.save_settings()
	elif payload.get("cycle", "") == "zoom":
		_cycle_zoom()
	elif payload.has("bind"):
		_capture_action = StringName(str(payload["bind"]))
	elif payload.has("reset"):
		Settings.reset_bindings()
		_hud.flash("bindings reset to defaults")
	elif payload.has("cat"):
		_hud.set_settings_cat(int(payload["cat"]))


## The three things the rope can teach itself.
##
## The winch has grown three techniques the game never mentioned: you can chain throws instead of landing,
## the line bends around corners and whips you round them, and it will catch a fall you are already
## committed to. A player who never finds those is playing a strictly worse game with the same build, and
## none of the three can be taught by a bubble at the start, because none of them means anything until you
## are in the situation. So each is poked as a condition and fires the frame the situation arrives: the
## release at speed, the first bend, the first landing that costs your footing.
##
## Predicates live here rather than in Hints because this is where the body and the rope are; Hints stays a
## latch and a queue that knows nothing about physics. Same reason note_in_water lives here.
const CHAIN_HINT_SPEED: float = Player.RUN_SPEED * 1.4    ## a release below this was not going anywhere


## What the line is carrying, which is not the same thing as how fast the body happens to be going.
##
## Tension on a pendulum is m*v^2/r plus the component of weight along the line, and both halves matter to
## the ear. The v^2/r term peaks at the bottom of an arc, exactly where reeling pays, because that is where
## the velocity is all tangential, so a creak driven by real tension tells you when to pull without a
## single word of UI. Driving it off raw speed would peak in the same places by accident and mean nothing:
## a body falling straight down a slack line is fast and carrying nothing at all.
const TENSION_FULL: float = Player.GRAVITY * 2.6   ## the load at which the fibre is singing flat out


func _line_load(g: Grapple) -> float:
	if not g.taut or _player == null:
		return 0.0
	var d: Vector2 = _player.position - g.hitch()
	var r: float = d.length()
	if r < 1.0:
		return 0.0
	var centripetal: float = _player.velocity.length_squared() / r
	var weight: float = Player.GRAVITY * maxf(0.0, d.y / r)   # only the part hanging below the hitch pulls
	return clampf((centripetal + weight) / TENSION_FULL, 0.0, 1.0)


## How near straight-down the body has to be for reeling to be the thing worth teaching. cos(~32 degrees):
## far enough into the bottom of the arc that a haul is nearly all tangential gain.
const PUMP_HINT_DOWN: float = 0.85

var _hint_busy: bool = false         ## moving too fast to read a lesson; hysteretic, see the poke
var _was_anchored: bool = false      ## line held last frame; the falling edge is a release


func _note_rope_moments() -> void:
	var g: Grapple = _player.grapple
	var anchored: bool = g.state == Grapple.State.ANCHORED
	# A release, airborne and moving: the exact frame a second throw would have paid off. Read as a transition
	# the controller tracks itself rather than off Grapple.just_cut, because that flag is cleared by the
	# player's own step and the player is a child node, so by the time the controller looks, the frame it was
	# set in is already over. Tracking the edge here cannot lose that race either way up.
	_hints.note(&"chain",
		_was_anchored and not anchored and not _player.on_floor
			and _player.velocity.length() > CHAIN_HINT_SPEED)
	_was_anchored = anchored
	# The pump: taut, quick, and near the bottom of the arc, the one instant where hauling the line in
	# converts almost entirely into speed. Teaching it anywhere else would be teaching a rule; teaching it
	# here is pointing at what the player's hands are already doing.
	var d: Vector2 = _player.position - g.hitch()
	_hints.note(&"pump",
		g.taut and _player.velocity.length() > CHAIN_HINT_SPEED
			and d.length() > 1.0 and d.y / d.length() > PUMP_HINT_DOWN)
	_hints.note(&"wrapped", not g.pivots.is_empty())
	_hints.note(&"hard_landing", _player.stagger > 0.0)


## The descent, marked. Crossing into a band for the first time this session raises a banner and a sting;
## every frame it also pushes the current row to the HUD's permanent depth readout. Downward crossings get
## the ceremony and upward ones do not: climbing back out is retreat rather than arrival, and a chime on
## the way up would make the whole thing feel like a scoreboard instead of a descent.
func _note_stratum(row: int) -> void:
	if _hud != null:
		_hud.depth_row = row
	var band: int = Strata.band_at(row)
	if band == _band_now:
		return
	var first_look: bool = _band_now < 0            # spawning somewhere is not arriving there
	var descending: bool = band > _band_now
	_band_now = band
	if first_look:
		_band_seen[band] = true
		return
	if _band_seen.has(band) or not descending:
		return
	_band_seen[band] = true
	if _hud != null:
		# The kicker carries the depth, which is what makes the plate an arrival rather than a label: you are told
		# where you got to as well as what it is called.
		_hud.announce(str(Strata.BANDS[band]["name"]),
			"%d METRES DOWN" % Strata.depth_m(row) if Strata.depth_m(row) > 0 else "THE SURFACE",
			Strata.color_at(row))
	# Pitched down as you go deeper, so the arrivals themselves form a descending line across a run: the same
	# idea the Score runs continuously, said once and out loud.
	_sfx.ui(&"chime", clampf(1.18 - float(band) * 0.11, 0.55, 1.2))


## The line runs: the first ingot this world produced without a hand on it.
##
## Announced with the same plate the strata get, deliberately. This game has exactly one channel that means
## stop, look, something changed, and spending it on the moment the player's machine outgrows the player is
## what that channel is for. The beat is aimed at the machine rather than at the screen: the sound comes
## from the drill, the sparks come off it and the shake radiates from it, so the eye is thrown at the thing
## that did the work instead of at a banner about it.
func _hail_the_line() -> void:
	var where: Vector2 = _player.position if _player != null else Vector2.ZERO
	for m: MachineState in sim.machines:
		if m.def.behavior == &"drill":
			where = _cell_center(m.cell)
			break
	if _hud != null:
		_hud.announce("THE LINE RUNS", "IT WORKS WITHOUT YOU", Color(0.98, 0.72, 0.34))
	if _sfx != null:
		_sfx.ui(&"ignite")
		_sfx.play(&"ignite", where, 1.0, -4.0)
	if _particles != null:
		_particles.burst(where, 16, Color(1.0, 0.80, 0.42), 90.0, TAU, 2.4, 1.1, 40.0)
		_particles.dust(where, Color(0.70, 0.62, 0.52), 10)
	_shake = maxf(_shake, LINE_HAIL_SHAKE)


func _set_volume(id: String, frac: float) -> void:
	match id:
		"master": Settings.master = clampf(frac, 0.0, 1.0)
		"sound": Settings.sound = clampf(frac, 0.0, 1.0)
		"ambience": Settings.ambience = clampf(frac, 0.0, 1.0)
		"music": Settings.music = clampf(frac, 0.0, 1.0)
	Settings.apply_audio()
	Settings.save_settings()


## The grapple (F or middle mouse). One key, one verb: throw. It shoots at the raw mouse point rather than
## at `_aim` on purpose, because `_aim` snaps to mineable faces within the pick's 3.2-cell reach, which is
## exactly the wrong behaviour for a tool whose whole job is to reach the far wall you cannot touch.
##
## The key used to toggle, cutting a live line. That made every chained arc cost a wasted press that also
## dropped you mid-swing, so the rope could never become a rhythm. Now it always throws, and Grapple.fire
## keeps the old line holding until the new hook bites; letting go is Space, which cuts the line and stacks
## a leap on the arc in one motion.
func _toggle_grapple() -> void:
	if _paused or _settings_open or _inventory_open:
		return
	var g: Grapple = _player.grapple
	if g.throwing():
		return                                    # a hook is already out: let it land
	g.fire(_player.hand(), Controls.pointer_world(self))
	_sfx.play(&"clunk", _player.position, 1.9, -10.0)


# --- world-interaction tools (mining / depositing): discrete sim edits only ---

## Timed mining: holding LMB charges the aimed block, with time scaled by your best tool against the rock's
## hardness. The block only breaks when the charge fills, so early hand-mining is a deliberate grind, the
## friction that sells automation, and the charge fraction drives the crack overlay. The wall-clock timing
## lives here; the tool gate lives in try_mine.
func _update_mining(delta: float) -> void:
	_rhythm_idle += delta
	if _rhythm_idle > RHYTHM_GRACE:
		_rhythm = maxf(0.0, _rhythm - delta * RHYTHM_DECAY)
	var mouse_world: Vector2 = Controls.pointer_world(self)
	_aim = _effective_aim(mouse_world)
	# Open UI (minimap, config panel) eats the cursor: LMB there clicks and never swings the pick.
	var pressed: bool = not _paused and not _settings_open and Controls.pressed(Controls.MINE) \
		and not _cursor_on_minimap() and not _cursor_on_hover_panel() and not _cursor_on_alerts()
	if pressed:
		_paint_dig_marks(mouse_world)        # dragging LMB sketches the plan, even beyond reach
	else:
		_last_paint_world = Vector2.INF
	# The charge and crack animation runs only on a cell you can actually break, using the same _mineable
	# predicate try_mine enforces: solid, in reach, and in line of sight. Without the line-of-sight term the
	# cracks would spider a full charge, try_mine would refuse for want of a clear path, and it would loop
	# forever, reading as a bug. If the aim is a block behind rock, _effective_aim already snaps to the nearest
	# exposed face toward the cursor, so you dig the path toward a buried target, and when no reachable face
	# exists nothing animates. When the cursor itself offers no workable block, the nearest marked cell in
	# reach becomes the work target: the precise hover always wins, the plan drains when the hand is free.
	var work: Vector2i = _aim
	if pressed and not _workable(work):
		work = _nearest_marked_workable()
	var holding: bool = pressed and _workable(work)
	_heal_cracks(delta, work if holding else Vector2i(-999, -999))
	if not holding:
		_mine_target = Vector2i(-999, -999)
		_mine_charge = 0.0
		_swing_clock = SWING_PERIOD          # primed: the first blow of the next charge lands instantly
		if _renderer != null:
			_renderer.set_mine_progress(Vector2i(-999, -999), 0.0)
		# Tool-locked hover keeps its no-progress read, and now skids, because a gate you cannot feel is
		# indistinguishable from a game that ignored your click (docs/BITS.md §5).
		if pressed and _refuses(_aim):
			_mine_target = _aim
			_renderer.set_mine_progress(_aim, 0.0)
			_skid(_aim, delta)
		else:
			_skid_clock = SKID_PERIOD        # primed: the first skid of the next attempt lands instantly
		return
	# Two kinds of work through one hold (docs/LODE.md §5). Rock breaks: a charge that ends in a cell
	# vanishing, with the charge banked on the cell so looking away does not cost you it. A lode is worked: a
	# short repeating cycle that yields a unit and changes nothing, so there is nothing to bank and nothing to
	# crack, and the payout is the progress read. The cadence, the pose, the blows and the rhythm are shared,
	# because both are a miner swinging at a face.
	var lode_face: bool = sim.lode_workable(work)
	var mat: StringName = sim.lode_at(work) if lode_face else sim.material_at(work)
	if work != _mine_target:                 # moved to a fresh block: resume whatever it already owes us
		_mine_target = work
		_mine_charge = 0.0 if lode_face else _banked_charge(work)
	var cls: StringName = MiningRules.required_tool(mat)
	var speed: float = MiningRules.best_speed(cls, sim.inventory) if cls != &"" else 1.0
	_mine_charge += delta * speed * (1.0 + _rhythm * RHYTHM_SPEED)
	var hard: float = LODE_CYCLE if lode_face else MiningRules.hardness(mat)
	if not lode_face:
		_cracks[work] = Vector2(_mine_charge, 0.0)            # bank it: this cell stays cracked while the cursor is elsewhere
		_renderer.set_mine_progress(work, clampf(_mine_charge / hard, 0.0, 1.0))
	else:
		_renderer.set_mine_progress(Vector2i(-999, -999), 0.0)  # nothing is breaking, so nothing is cracking
	# Swing feel: while charging, the body holds the dig pose facing the block, and on a steady cadence a blow
	# lands, with a chip of the rock's dust off the struck face and a micro-shake, so mining reads as
	# pick-strikes landing rather than as a progress bar silently filling.
	if _player != null:
		_player.note_dig(int(signf(_cell_center(work).x - _player.position.x)))
		_swing_clock += delta
		if _swing_clock >= SWING_PERIOD / (1.0 + _rhythm * RHYTHM_SWING):
			_swing_clock = 0.0
			var center: Vector2 = _cell_center(work)
			var to_body: Vector2 = _player.position - center
			_particles.chip(center + to_body.normalized() * (float(CELL) * 0.45),
				Visuals.terrain_dust(mat), to_body.angle())
			_shake = maxf(_shake, 0.7)
			# Harder rock strikes a deeper note (hardness 1..4 maps to pitch ~1.15..0.85).
			_sfx.play(&"crunch", center, clampf(1.25 - hard * 0.1 + _rhythm * 0.12, 0.8, 1.4))
			# ...and if there is a void behind the face, it rings over the top of that thud. Layered rather than
			# swapped, so the tell is the rock answering the same blow: the pick sounds the same, the wall does not.
			# Volume rides the reading, so closing on a cavity is a crescendo you can act on rather than a flag that
			# flips.
			var dir: Vector2i = _swing_dir(work)
			var hollow: float = 0.0 if lode_face else _hollow_at(work, dir)
			if hollow > 0.12:
				_sfx.play(&"hollow", center, clampf(1.05 - hollow * 0.25, 0.7, 1.15),
					lerpf(-26.0, -9.0, hollow))
				# ...and the same tell for a player with the sound off: air drawn through the face toward
				# the cavity, hanging in the lamp pool. A cave breathes, and this one does it at the wall
				# you are hitting.
				_particles.draught(center - Vector2(dir) * (float(CELL) * 0.4),
					Visuals.terrain_dust(mat).lightened(0.25), Vector2(dir), 1 + int(2.0 * hollow))
	if _mine_charge >= hard:
		_mine_charge = 0.0
		if lode_face:
			try_work_lode(work)                              # one unit off the vein; the vein stays
			return
		_cracks.erase(work)                                  # broken: nothing left to remember
		var was_hollow: float = _hollow_at(work, _swing_dir(work))
		if try_mine(work):                                   # charge full → land the breaking blow
			_rhythm = minf(1.0, _rhythm + RHYTHM_GAIN)       # ...and the rhythm carries into the next one
			_rhythm_idle = 0.0
			_note_breach(work, was_hollow)
			# Recovery as a negative charge rather than a separate timer: the next blow simply starts from further
			# back, so it reads as a heavy tool being hauled up again and needs no new state, no new gauge and no new
			# rule. Only the Lance has any.
			_mine_charge = -BitRules.recovery(BitRules.equipped(_selected_item()))


## How hollow the rock behind this face is: 0 is solid to the horizon, 1 is a void right behind it.
##
## The generator fills this world with caverns, rifts, halls, veins and aquifers, and without a tell none
## of it exists until you physically walk into it: you break every block blind, and digging is a chore
## rather than a search. Real rock rings when there is a cavity behind the face, and listening for that is
## the oldest skill in the trade.
##
## The reading is a weighted count of open cells in a small box ahead of the face, biased along the
## direction the pick is swinging: what is behind the block you are hitting matters, what is beside your
## own shoulder does not. Nearer counts for more, so the tell rises as you close on a void instead of
## switching on. It reads sim.solid directly and writes nothing, so there is nothing to desync.
const TELL_REACH: int = 4              ## cells ahead the reading looks
const TELL_SPREAD: int = 2             ## and how far to either side of the swing line
func _hollow_at(cell: Vector2i, dir: Vector2i) -> float:
	var side: Vector2i = Vector2i(dir.y, dir.x)          # perpendicular to the swing
	var acc: float = 0.0
	var total: float = 0.0
	for d: int in range(1, TELL_REACH + 1):
		var near: float = 1.0 - float(d - 1) / float(TELL_REACH)   # a void one cell in is worth four far out
		for o: int in range(-TELL_SPREAD, TELL_SPREAD + 1):
			var w: float = near * (1.0 - absf(float(o)) / float(TELL_SPREAD + 1))
			var probe: Vector2i = cell + dir * d + side * o
			total += w
			if not sim.in_bounds(probe) or not sim.is_solid(probe):
				acc += w
	return 0.0 if total <= 0.0 else clampf(acc / total * 1.6, 0.0, 1.0)


## Which way the pick is swinging, as a unit cell step: from the body toward the worked block. Falls back
## to straight down, which is where a miner who is not obviously beside something is usually digging.
func _swing_dir(cell: Vector2i) -> Vector2i:
	var d: Vector2 = _cell_center(cell) - _player.position
	if absf(d.x) > absf(d.y):
		return Vector2i(signi(int(d.x)), 0)
	return Vector2i(0, signi(int(d.y))) if absi(int(d.y)) > 0 else Vector2i(0, 1)


## The breach: the face gives way and the space behind it opens.
##
## The ring is the anticipation; this is the payoff, and a payoff that arrives silently teaches the player
## that the anticipation meant nothing. Air moving, a puff of the wall's own dust blown into the room
## rather than chipped off it, and a settle of the camera. Gated on the reading having actually been high,
## so breaking ordinary rock is exactly as unceremonious as it has always been: the beat is only worth
## anything while it stays rare.
const BREACH_TELL: float = 0.45        ## reading above which a break counts as opening a space
func _note_breach(cell: Vector2i, hollow: float) -> void:
	if hollow < BREACH_TELL:
		return
	var center: Vector2 = _cell_center(cell)
	_sfx.play(&"breach", center, clampf(1.12 - hollow * 0.22, 0.85, 1.15), lerpf(-14.0, -5.0, hollow))
	_particles.dust(center, Color(0.62, 0.60, 0.56), 6 + int(6.0 * hollow))
	_shake = maxf(_shake, 1.4 * hollow)


## The charge this cell already owes us (0.0 for untouched rock). Half-dug blocks resume where they
## stopped, so a mis-aim costs travel time, never progress.
func _banked_charge(cell: Vector2i) -> float:
	return (_cracks[cell] as Vector2).x if _cracks.has(cell) else 0.0


## Age every banked crack except the one being worked; past the grace window they bleed off and evict.
func _heal_cracks(delta: float, working: Vector2i) -> void:
	for cell: Vector2i in _cracks.keys():
		if cell == working:
			continue
		var c: Vector2 = _cracks[cell]
		c.y += delta
		if c.y > CRACK_HOLD:
			c.x -= delta * CRACK_HEAL
		if c.x <= 0.0 or not sim.is_solid(cell):   # healed, or the cell stopped being rock (dug/built over)
			_cracks.erase(cell)
		else:
			_cracks[cell] = c


## Will the carried drive bite this rock? True for anything that is not solid rock, where the question does
## not apply, and for rock within your tier; false only where the wall is genuinely over your drive, which
## is the one case the cursor has to draw differently.
func _drive_bites(cell: Vector2i) -> bool:
	if not sim.is_solid(cell):
		# An exposed lode is the other thing a drive can be under (docs/LODE.md §5). Answering it here means the
		# crossed cursor and the skid cover ore with no new code: the ladder is one ladder.
		if sim.lode_workable(cell):
			return MiningRules.can_mine(sim.lode_at(cell), sim.inventory)
		return true
	return MiningRules.can_mine(sim.material_at(cell), sim.inventory) \
		and _bit_bites(BitRules.equipped(_selected_item()), cell)


## Is this cell rock you can swing at but not break, the one state a skid answers? Solid, in reach, in line
## of sight so the swing would really land there, and then refused by one of the two things that can
## refuse: your drive is under the rock's tier, or the wedge is across the grain. Named rather than inlined
## so the mining loop and the refusal check assert the same sentence, and kept separate from `_mineable`,
## which must stay false here or the charge would spider forever on a cell that never breaks.
func _refuses(cell: Vector2i) -> bool:
	if not (_can_reach(cell) and _line_of_sight_clear(_body_cell(), cell)):
		return false
	if not sim.is_solid(cell):
		# ...or a vein whose ore is over your drive: the same refusal, the same tells, a different face.
		return sim.lode_workable(cell) and not MiningRules.can_mine(sim.lode_at(cell), sim.inventory)
	if not MiningRules.can_mine(sim.material_at(cell), sim.inventory):
		return true
	return not _bit_bites(BitRules.equipped(_selected_item()), cell)


## The skid (docs/BITS.md §5). Steel glancing off rock your drive cannot bite: a spark off the struck face,
## a short scrape and a flick of shake, on the same cadence a real blow lands on, so what you feel is
## swinging and not biting rather than nothing at all. Never a partial break bar: you must never be able to
## mistake cannot for slow, which is the whole reason the speed axis was deleted.
##
## The refusal also names the rung, once, on a long cooldown: the tier of drive this rock wants and the
## tool that carries it, the way a locked craft row names its tech. Saying it on every skid would be
## nagging; saying it never leaves over-tier rock reading as a broken click.
const SKID_PERIOD: float = 0.30       ## seconds between skids while you hold on rock that won't take it
const SKID_TELL_COOLDOWN: float = 6.0 ## and how long before it spells the reason out again
var _skid_clock: float = SKID_PERIOD
var _skid_tell: float = 0.0
var _skids: int = 0                   ## skids this session; nothing in the game reads it


func _skid(cell: Vector2i, delta: float) -> void:
	_skid_tell = maxf(0.0, _skid_tell - delta)
	_skid_clock += delta
	if _skid_clock < SKID_PERIOD:
		return
	_skid_clock = 0.0
	_skids += 1
	var center: Vector2 = _cell_center(cell)
	if _player != null:
		_player.note_dig(int(signf(center.x - _player.position.x)))
		var to_body: Vector2 = _player.position - center
		var face: Vector2 = center + to_body.normalized() * (float(CELL) * 0.45)
		# Sparks, not dust: nothing came off the rock. The colour is the tool's, not the wall's.
		_particles.spark(face, Color(1.0, 0.86, 0.52))
		_shake = maxf(_shake, 0.45)
	_sfx.play(&"skid", center, randf_range(0.94, 1.08))
	# The words, and only where nothing else has them. A tier refusal is already written down: the hover
	# inspector names the drive, in the same sentence, for as long as you hold the cursor on the rock. The
	# refusal nothing else explains is the wedge across the grain, where the pick is fine and the angle is
	# wrong, so that is the one the skid says out loud, once, on a cooldown.
	if _hud == null or _skid_tell > 0.0:
		return
	if not MiningRules.can_mine(sim.material_at(cell), sim.inventory):
		return
	_skid_tell = SKID_TELL_COOLDOWN
	_hud.flash("the %s splits ALONG the grain — line the swing up with the seam"
		% _thing_name(BitRules.equipped(_selected_item())))


## A carried thing's display name, for the one place that has to say a tool's name out loud.
func _thing_name(id: StringName) -> String:
	for t: Dictionary in CRAFT_TOOLS:
		if t["id"] == id:
			return str(t["name"])
	return MiningRules.tool_name(id)


## A cell the miner can work right now: breakable (solid + reach + LOS, the try_mine gate) and the
## carried tools are up to its rock. The single predicate both the hover target and the queue use.
func _workable(cell: Vector2i) -> bool:
	if _lode_workable(cell):
		return true
	return _mineable(cell) and MiningRules.can_mine(sim.material_at(cell), sim.inventory)


## Can the body work an exposed lode here (docs/LODE.md §5)? Reach and line of sight, exactly as for rock,
## and the same drive gate, because the tool ladder is the tool ladder and honouring it here is what lets
## the crossed cursor and the skid answer a lode with no extra code. What does not apply is the bit: bits
## decide the shape of a hole, and working a vein cuts no hole. A Wedge in your hand never refuses ore.
func _lode_workable(cell: Vector2i) -> bool:
	if not (sim.lode_workable(cell) and _can_reach(cell) and _line_of_sight_clear(_body_cell(), cell)):
		return false
	return MiningRules.can_mine(sim.lode_at(cell), sim.inventory)


## Sweep-paint the dig plan: every solid cell the cursor crossed since last frame gets a mark, with the
## segment sampled sub-cell so a fast drag does not skip blocks. Marks are allowed beyond reach, since the
## plan is where you intend to dig and reach gates the work rather than the sketch. Tool-locked rock refuses
## a mark, because a plan you cannot execute yet just reads as a bug later.
func _paint_dig_marks(mouse_world: Vector2) -> void:
	var from: Vector2 = _last_paint_world if _last_paint_world != Vector2.INF else mouse_world
	_last_paint_world = mouse_world
	var span: float = from.distance_to(mouse_world)
	var steps: int = maxi(1, ceili(span / (float(CELL) * 0.5)))
	for i: int in steps + 1:
		var cell: Vector2i = _cell_at(from.lerp(mouse_world, float(i) / float(steps)))
		if _dig_marks.has(cell) or _dig_marks.size() >= MAX_DIG_MARKS:
			continue
		if sim.is_solid(cell) and MiningRules.can_mine(sim.material_at(cell), sim.inventory):
			_dig_marks[cell] = true


## The marked cell nearest the body that can be worked right now. Prunes stale marks (cells already
## dug or built over) as it scans, so the plan never points at air.
func _nearest_marked_workable() -> Vector2i:
	var none := Vector2i(-999, -999)
	if _player == null or _dig_marks.is_empty():
		return none
	var best: Vector2i = none
	var best_d: float = INF
	for cell: Vector2i in _dig_marks.keys():
		if not sim.is_solid(cell):
			_dig_marks.erase(cell)            # dug (by hand or by the queue itself) → the mark is spent
			continue
		if not _workable(cell):
			continue                          # out of reach, no line of sight, or tool-locked: stays in the plan
		var d: float = _cell_center(cell).distance_squared_to(_player.position)
		if d < best_d:
			best_d = d
			best = cell
	return best


## Terraria-style mining reach: you do not have to land the cursor exactly on a reachable cell. Pointing at
## a block that is out of reach snaps the aim to the closest reachable block toward your cursor, and the
## highlight follows so you see what you will hit. Precise in-reach hovering is unchanged, and while
## building, with a machine or material selected, the aim stays exact: placement wants the cell you point at.
func _effective_aim(mouse_world: Vector2) -> Vector2i:
	var raw: Vector2i = _cell_at(mouse_world)
	var building: bool = _selected_machine_def() != null or _selected_build_material() != &""
	if building:
		return raw                          # placement wants the exact cell (it has its own _placeable gate)
	# Mining and interaction: an open cell in reach, or a solid block you have line of sight to, is the aim.
	if _can_reach(raw) and (not sim.is_solid(raw) or _line_of_sight_clear(_body_cell(), raw)):
		return raw
	return _nearest_reachable_solid(mouse_world, raw)   # else snap to the nearest block you can actually carve


## The reachable solid cell whose centre is closest to `point`, the cursor: the block Terraria-reach mining
## would bite. Scans only the small in-reach neighbourhood. Returns `fallback` when the cursor is not near
## any reachable block, so pointing at open air far off does not snap the cursor to a random wall behind
## you. The tolerance is one reach-radius from the cursor: point at or near a wall and it snaps.
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


## --- Player verbs (the addressable game surface) --------------------------------------------------
## The body's world actions, each reach-gated and boolean: did it happen? The input layer above drives them
## from mouse and keys, and automated play drives the same methods, so what a human can do is what a test
## can do, by construction.

## Enter, at the counter: do whatever the cursor is sitting on. The panel owns the cursor because the panel
## draws it; this owns the verbs. That split is the point, because the highlighted row and the thing that
## happens cannot drift apart, which is exactly how `R` ended up meaning two different things depending on
## where you were standing.
##
## All three verbs stay Bazaar-gated: you can read the whole counter from the bottom of a shaft and plan
## the trip back, and the footer says so, but you buy at the counter.
func _bazaar_enter() -> void:
	var act: Dictionary = _hud.bazaar_action()
	var kind: String = str(act.get("kind", ""))
	if kind == "":
		return
	var id: StringName = act["id"]
	match kind:
		"machine":
			var row: int = int(act["row"])
			if row < _craftable.size():
				try_craft(_craftable[row])
		"rack":
			try_craft_tool(id)
		"tech":
			try_research(id)
		"hold":
			# The pack's verb. Equipping is stateless (`BitRules`), so hold-this is literally select-this-slot, the
			# same act as pressing its hotbar digit, reachable from the screen you are already looking at rather than
			# only from a row of numbers hidden behind the panel.
			_inv_selected = int(act["row"])


## Mine the aimed cell if it is solid and within reach. Cooldown is input pacing, not part of the verb.
func try_mine(cell: Vector2i) -> bool:
	if _paused or not _mineable(cell):     # reach and line of sight: you cannot dig through solid rock to a hidden block
		return false
	var mat: StringName = sim.material_at(cell)
	if not MiningRules.can_mine(mat, sim.inventory):
		return false                                           # no tool for this rock
	var rich: bool = sim.ore_deposit_at(cell) > 0              # captured before the mine clears the cell
	var before: Dictionary = sim.inventory.duplicate()         # …so the payout tick can name the real yield
	# The bit decides what the blow takes. The drive decided whether you may bite this rock at all, above;
	# from here on the shape of the hole is the bit's business and nothing else's.
	var bit: StringName = BitRules.equipped(_selected_item())
	var keeps: bool = BitRules.keeps(bit)
	var mined: StringName = sim.mine(cell, keeps)
	if mined != &"":
		# Both resolved before the payout tick, because everything this one blow took is part of what it paid: a
		# "+3 stone" over a swing that handed you nine would be a lie.
		var calved: int = _shape(bit, cell, keeps) + _calve(cell, BitRules.cap(bit), keeps)
		_dig_marks.erase(cell)                                 # a dug cell's mark is spent
		var center: Vector2 = _cell_center(cell)
		_show_gains(before, center + Vector2(0.0, -float(CELL) * 0.35))
		_renderer.note_mined(cell, mat)                        # the block shatters away rather than popping
		_particles.dust(center, Visuals.terrain_dust(mat), 10)  # settling break-dust puff
		if calved > 0:
			# One blow, one report: the run gets a heavier shake and a lower, longer note than a single
			# break, so calving a ledge sounds like a different event rather than three fast ones.
			_shake = maxf(_shake, 3.4)
			_sfx.play(&"thump", center, 0.78, 3.0)
		if _player != null:
			# The breaking blow's payoff: chunky debris kicked out of the shattered face toward the digger, a heavier
			# kick than a mid-charge chip, and a vein pays out a bright fleck-spray in its own colour, so breaking ore
			# feels richer than breaking dirt.
			_particles.debris(center, Visuals.terrain_dust(mat).lightened(0.12),
				(_player.position - center).angle())
			_player.note_dig(int(signf(center.x - _player.position.x)))
		# Every break throws a spray in the material's own item colour, not just a rich one: the block visibly
		# becomes the thing you now carry, which is the moment the payout tick then names. A rich vein still
		# out-sparkles a plain one; it just is not the only break that reads as an event.
		_particles.spark(center, Visuals.item_color(mat).lightened(0.35 if rich else 0.15))
		_shake = maxf(_shake, 2.6 if rich else 2.0)
		_sfx.play(&"thump", center, 1.1 if rich else 1.0, 2.0 if rich else 0.0)
		_note_strike(cell, mat)
	return mined != &""


## Work one unit off an exposed lode (docs/LODE.md §5): the hand half of extraction, and a different verb
## from `try_mine` on purpose. Mining ends a cell, with a charge, a break, a hole and everything the bit
## shapes around it. Working a vein ends nothing: you take a unit, the face is still there, and the only
## thing that changed is how much is left. So there is no calve, no shape, no break-dust and no shatter,
## only a fleck-spray in the ore's own colour, a light strike, and the payout tick naming what you got.
func try_work_lode(cell: Vector2i) -> bool:
	if _paused or not _lode_workable(cell):
		return false
	var before: Dictionary = sim.inventory.duplicate()
	var item: StringName = sim.take_lode(cell)
	if item == &"":
		return false
	var center: Vector2 = _cell_center(cell)
	_show_gains(before, center + Vector2(0.0, -float(CELL) * 0.35))
	_particles.spark(center, Visuals.item_color(item).lightened(0.35))
	_shake = maxf(_shake, 1.4)                            # lighter than a break: nothing collapsed
	_sfx.play(&"thump", center, 1.18, 1.0)
	if _player != null:
		_player.note_dig(int(signf(center.x - _player.position.x)))
	_note_strike(cell, item)
	return true


## The rock has a grain, and the blow follows it (docs/BITS.md §4).
##
## Every rock cell carries a seam (see `Seams`: bedding planes, joints and diagonals, all free functions of
## the seed). Strike along one and the contiguous run of same-seam rock calves off with the struck cell, up
## to `Seams.RUN_CAP`. Strike across it and this returns nothing at all, which is the point: cutting
## against the grain is plain single-cell mining at the plain single-cell rate. The whole mechanic is
## upside for reading the rock and never a penalty for not.
##
## Three gates the run must respect, each for its own reason:
##   Contiguous. It stops at the first cell that is not solid, not the same seam, or not bitable. A run
##     that hopped over gaps would let one blow reach through a chamber and take rock on the far side.
##   The drive. Every calved cell is re-checked against `can_mine`, so a seam can never smuggle you past a
##     depth gate; the wall stays where the tool ladder put it.
##   Reach is not re-checked, deliberately. Reach gates the blow, and the calve is a consequence of the
##     blow rather than a second one. Requiring it would make the run vanish at exactly the arm's-length
##     distance where you can actually see the seam you are cutting.
##
## It walks one way and then the other rather than alternating, so a capped run reads as a ledge shearing
## off in one direction rather than crumbling evenly around the pick.
func _calve(from: Vector2i, cap: int, keeps: bool) -> int:
	if cap <= 1:
		return 0                          # this bit does not follow the grain (`BitRules`)
	var seam: int = Seams.at(from, sim.world_seed)
	if seam == Seams.NONE or not Seams.aligned(seam, _swing_heading(from)):
		return 0
	var axis: Vector2i = Seams.axis(seam)
	var taken: int = 0
	for side: int in [1, -1]:
		for step: int in range(1, cap):
			if taken >= cap - 1:
				break
			var c: Vector2i = from + axis * (step * side)
			if not sim.solid.has(c) or Seams.at(c, sim.world_seed) != seam:
				break
			var m: StringName = sim.material_at(c)
			if not MiningRules.can_mine(m, sim.inventory):
				break
			if sim.mine(c, keeps) == &"":
				break
			taken += 1
			_break_spall(c, m)
	return taken


## The bit's own shape: the cells a blow takes because of what is fitted to the drive, as opposed to
## because of the way the rock lies. Returns how many it took beyond the aimed cell, which `try_mine` has
## already broken.
##
## A ray bit stops at the first cell that is not solid; a block bit skips it and carries on. That is the
## whole reason the flag exists: a Lance is five cells driven through rock, so a chamber in the way ends
## the drive, and without that rule one blow could reach across a hall and take rock on the far side. A
## Broad's 2x2 has no travel direction to interrupt, so a gap in one corner is a corner already open.
func _shape(bit: StringName, cell: Vector2i, keeps: bool) -> int:
	var face: int = 1
	if _player != null and _cell_center(cell).x < _player.position.x:
		face = -1
	var ray: bool = BitRules.ray(bit)
	var took: int = 0
	for c: Vector2i in BitRules.cut(bit, cell, face):
		if c == cell:
			continue                      # the aimed cell is `try_mine`'s, already broken
		if not sim.solid.has(c):
			if ray:
				break
			continue
		var m: StringName = sim.material_at(c)
		if not MiningRules.can_mine(m, sim.inventory):
			break                         # the drive gates every cell, not just the one you pointed at
		if sim.mine(c, keeps) == &"":
			break
		took += 1
		_break_spall(c, m)
	return took


## The lighter break feedback for a cell a blow took in passing, as opposed to the one it was aimed at.
## Same dust and the same fleck in the material's own colour, at a fraction of the count: one blow should
## read as one event with a wide mouth, never as three or five separate breaks going off at once.
func _break_spall(c: Vector2i, m: StringName) -> void:
	_dig_marks.erase(c)
	var at: Vector2 = _cell_center(c)
	_renderer.note_mined(c, m)
	_particles.dust(at, Visuals.terrain_dust(m), 6)
	_particles.spark(at, Visuals.item_color(m).lightened(0.15))


## The strike that finds the vein.
##
## The pick already has a hollow ring, so the rock tells you when there is space behind it. This is the
## other half of the same sentence: it must also tell you when there is metal behind it. Without it,
## breaking the first block of a vein and breaking its sixth are the same event with the same dust, spark
## and tick, and the best moment in digging has no moment. Raising ore density is no substitute, since
## meeting more of a thing you already carry registers as nothing at all.
##
## It fires on exposure rather than on proximity, which is what keeps it from becoming wallpaper: a
## neighbour only counts if this blow is what uncovered it, with every other side of it still buried.
## Tunnel along a seam you have already opened and it stays quiet; break through into one and it rings.
const TREASURE: Array[StringName] = [&"ore", &"rich_ore", &"coal", &"iron"]
const STRIKE_SHAKE: float = 3.2
var veins_struck: int = 0                 ## a session's real discoveries

func _note_strike(cell: Vector2i, was: StringName) -> void:
	if was in TREASURE:
		return                             # already inside the body; the arrival was the blow before this
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cell + d
		if not sim.in_bounds(n) or not sim.is_solid(n):
			continue
		var found: StringName = sim.material_at(n)
		if not found in TREASURE or not _was_buried(n, cell):
			continue
		veins_struck += 1
		var at: Vector2 = _cell_center(n)
		var tint: Color = Visuals.item_color(found)
		_sfx.play(&"vein", at, 1.16 if found == &"rich_ore" else 1.0, 1.0)
		_particles.burst(at, 9, tint.lightened(0.30), 62.0, TAU, 1.7, 0.75, 60.0)
		_shake = maxf(_shake, STRIKE_SHAKE)
		return                             # one arrival per blow, however much the blow uncovered


## Whether `cell` had no open side at all until `opened` was broken: this blow is what found it.
func _was_buried(cell: Vector2i, opened: Vector2i) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cell + d
		if n != opened and sim.in_bounds(n) and not sim.is_solid(n):
			return false
	return true


## Float a "+N" tick at `at` for every pack entry that grew since `before`: the payoff shown at the point
## of impact instead of only as a number in the HUD corner. Diffing the pack rather than reading the verb's
## return value means the tick always names what you actually got, so an ore burst is the 3-6 it really
## paid, a leaf that hid a sapling says sapling, and new yields need no wiring.
func _show_gains(before: Dictionary, at: Vector2) -> void:
	for item: StringName in sim.inventory:
		var delta: int = int(sim.inventory[item]) - int(before.get(item, 0))
		if delta > 0:
			_payouts.gain(at, item, delta)


## Hand the selected carried item into the nearest machine within reach (the manual half of the arc).
func try_deposit() -> bool:
	var slots: Array[Dictionary] = sim.inventory_slots()
	if slots.is_empty():
		return false
	var sel: int = clampi(_inv_selected, 0, slots.size() - 1)
	var item: StringName = slots[sel]["item"]
	var carried: int = int(slots[sel]["count"])
	if carried <= 0 or MiningRules.is_tool_item(item):
		return false                                           # tools are equipment, never fed into a machine
	for machine: MachineState in sim.machines:
		if _can_reach(machine.cell):
			return sim.deposit(machine.cell, item, carried) > 0
	return false


## Configure the aimed machine (R outside the pack screen): cycle a splitter's ratio, clear a hopper's
## filter. Reach-gated like every world verb; the sim returns the toast text.
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


## Craft a machine item from carried ingots into the pack, gated on standing near a claimed Bazaar, the
## crafting hub. Refused away from it, so machine-crafting pulls you to the stall.
func try_craft(def: MachineDef) -> bool:
	if not _near_bazaar():
		return false
	var made: bool = sim.craft(def)
	if made:
		_sfx.ui(&"ding")
	return made


## Fire the sonar: a pulse expands from the body, and every still-solid deposit in range answers with an
## echo ring through the rock, which the renderer draws, and a distance-staggered return chirp. Requires
## carrying a Scanner; a short cooldown paces it. A pure query: it reads deposits and mutates nothing, so
## the whole feature adds no sim state.
func try_scan() -> bool:
	if _paused or _scan_cooldown > 0.0 or _player == null:
		return false
	if int(sim.inventory.get(&"scanner", 0)) <= 0:
		return false
	var origin: Vector2 = _player.position
	var echoes: Array[Dictionary] = []
	var range_px: float = SCAN_RANGE_CELLS * float(CELL)
	for cell_v: Variant in sim.deposits:
		var cell: Vector2i = cell_v
		if not sim.is_solid(cell) or sim.ore_deposit_at(cell) <= 0:
			continue
		var pos: Vector2 = _cell_center(cell)
		var dist: float = origin.distance_to(pos)
		if dist <= range_px:
			# The identity comes from the same branch as the amount (`deposit_material_at`) rather than from
			# `material_at`. A buried vein's solid is the stone in front of it, and stone's nugget_color is
			# transparent, so taking the identity from the rock plane drew every buried echo's arc, pip and
			# through-rock glow in nothing, which is the one case the glow exists for.
			echoes.append({"cell": cell, "pos": pos, "dist": dist,
				"material": sim.deposit_material_at(cell)})
	echoes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["dist"]) < float(b["dist"]))
	_scan_cooldown = SCAN_COOLDOWN
	_renderer.start_scan(origin, echoes)
	_sfx.ui(&"pop", 0.55)                                     # the low fire chirp
	for i: int in mini(echoes.size(), 6):                     # returns, staggered by true distance
		_scan_dings.append({"at": float(echoes[i]["dist"]) / WorldRenderer.SCAN_WAVE_SPEED,
			"pos": echoes[i]["pos"]})
	if echoes.is_empty():
		_hud.flash("no echoes — nothing in range")
	return true


## Craft a tool, such as the Stone Pickaxe, from carried materials: the same Bazaar gate and the same
## generic sink as machine crafting (sim.craft_item). The pickaxe-tier upgrade path, since crafting one
## unlocks the deeper rock its tier gates.
func try_craft_tool(tool_id: StringName) -> bool:
	if not _near_bazaar():
		return false
	var made: bool = sim.craft_item(tool_id, _tool_recipe(tool_id))
	if made:
		_sfx.ui(&"ding", 1.1)
	return made


## Research a tech at the Bazaar bench (ENTER on the Bench tab): the demand-side pull. Analyze a sample of
## the tech's signature material and spend refined ingots to unlock crafting its machines
## (docs/PROGRESSION.md §5). Bazaar proximity is the bench, the same gate as crafting, and the spend itself
## is the sim's discrete research_tech.
func try_research(tech_id: StringName) -> bool:
	if not _near_bazaar():
		return false
	var done: bool = sim.research_tech(tech_id)
	if done and _player != null:
		_particles.spark(_player.position, Color(0.55, 0.85, 1.0))  # a cool "insight" burst at the bench
		_shake = maxf(_shake, 2.0)
		_sfx.ui(&"chime")
	return done


## Scoop up resting product piles near the body: walk over items to grab them, widened to a short reach so
## a machine's output flows to you when you stand at it. Gravity drops a forge's ingots into the cell below
## it, which the body often cannot stand in because the machine caps it, so collecting within the same
## reach the body mines and builds with means you stand at your line and its output comes to you instead of
## having to occupy the exact landing cell. A pure discrete sim edit (collect_ground); the avatar only
## triggers it.
const COLLECT_REACH_CELLS: float = 2.5
## No-auto-pickup grace, because a just-dropped item was instantly sucked back up: cell -> seconds
## remaining. Set on a Q-drop for the landing cell and aged each frame; a graced cell is skipped.
const DROP_GRACE_S: float = 1.3
## How far a drop must fall to count as a full-weight landing. Eight cells is the shaft the tutorial digs;
## anything at or past it lands as hard as landing gets, and a one-cell hand-off barely registers.
const DROP_IMPACT_CELLS: float = 8.0
const DROP_VOICE_MIN: float = 0.15   ## below this it is a place-down, not a fall, and stays silent
const DROP_VOICE_MAX: int = 2        ## simultaneous landing sounds; more is a rattle, not more landings
var _no_pickup: Dictionary = {}


## Age the per-cell no-pickup grace; drop cells whose grace has elapsed so they auto-collect again.
func _age_drop_grace(delta: float) -> void:
	if _no_pickup.is_empty():
		return
	for c: Variant in _no_pickup.keys():
		var t: float = float(_no_pickup[c]) - delta
		if t <= 0.0:
			_no_pickup.erase(c)
		else:
			_no_pickup[c] = t


## The arrival: the half of a toss that had no cue at all.
##
## A drop already fires `_particles.pop` at the moment of the THROW, at the toss cell. But the item is in
## the air for `FALL_DURATION` after that and comes down at `sim.last_drop_landing`, which for a toss into a
## shaft is many rows below, so the only feedback the verb had was wrong in space and in time, and the
## landing, which is the part with any weight in it, was silent. This is subtraction rather than invention:
## the impact-scaled vocabulary already exists for the body landing (dust count, shake and thump pitch all
## ride `player.last_impact`) and nothing had ever called it for an item.
##
## It scales with the fall, because that is the only thing that distinguishes setting something down from
## dropping it down a hole. A one-cell toss should tick; an eight-cell drop should land.
##
## NO SHAKE, deliberately, and it is the one piece of that vocabulary not borrowed. The body landing kicks
## the camera because the camera is on the body. Shaking the screen for a pebble arriving twelve rows away
## would say the wrong thing about where the player is, and drops are frequent enough that it would be
## constant.
func _land_drops() -> void:
	var landings: Dictionary = _falling.take_landings()
	if landings.is_empty():
		return
	# Sound is capped and dust is not: dust is per-cell and reads as one event however many cells it covers,
	# but N simultaneous clunks is a rattle rather than N landings. The loudest few carry the moment.
	var voices: int = 0
	for key: Variant in landings:
		var l: Dictionary = landings[key]
		var pos: Vector2 = l["pos"]
		var col: Color = l["color"]
		var imp: float = clampf(float(l["drop"]) / (float(WorldRenderer.CELL) * DROP_IMPACT_CELLS), 0.0, 1.0)
		_particles.dust(pos, col.darkened(0.35), 2 + int(imp * 6.0))
		# Below this the drop is a place-down, not a fall, and a sound on it would fire on every routine
		# hand-off between machines, which is most of what this channel carries once a factory is running.
		if imp > DROP_VOICE_MIN and voices < DROP_VOICE_MAX:
			voices += 1
			_sfx.play(&"clunk", pos, 1.18 - imp * 0.30, -20.0 + imp * 9.0)


func _collect_ground_under_player() -> void:
	if _player == null or sim.ground.is_empty() or not Settings.auto_pickup:
		return
	var reach_sq: float = pow(COLLECT_REACH_CELLS * float(CELL), 2.0)
	for cell: Variant in sim.ground.keys():                          # keys() copies, so collecting mid-iteration is safe
		var c: Vector2i = cell
		if _no_pickup.has(c):                                        # just dropped here: leave it a moment
			continue
		var pile: Dictionary = sim.ground[c]
		if pile.is_empty():                                          # a pruned-but-lingering empty pile: skip
			continue
		if _player.position.distance_squared_to(_cell_center(c)) > reach_sq:
			continue
		var item: StringName = pile.keys()[0]
		var before: Dictionary = sim.inventory.duplicate()
		if sim.collect_ground(c):
			_particles.pop(_cell_center(c), Visuals.item_color(item))  # pickup pop
			_show_gains(before, _cell_center(c) + Vector2(0.0, -float(CELL) * 0.35))
			_sfx.play(&"pop", _cell_center(c), 1.0, -4.0)


## Snap a world position so it lands on a whole screen pixel at the given zoom: the pixel-art camera fix. A
## fractional camera offset makes every terrain texel sample between screen pixels each frame, which
## shimmers and blurs in motion. Rounding the camera to the screen-pixel grid removes the sub-pixel jitter
## while the smoothing keeps the follow soft. Static and pure, so the grid alignment can be asserted
## without a live scene.
static func snap_to_pixel(world_pos: Vector2, zoom: float) -> Vector2:
	if zoom <= 0.0:
		return world_pos
	return (world_pos * zoom).round() / zoom


## The active camera zoom level (Z cycles the index). Read everywhere the view-size matters.
func _current_zoom() -> float:
	return ZOOM_LEVELS[_zoom_idx]


## Cycle to the next zoom level (Z) and apply it to the camera, Terraria-style zoom-out/in.
## The pick persists as a setting (real boots restore it; save is a no-op on scripted boots).
## EVERY CALLER THAT PREDATES THE PARAMETER STEPS FORWARD, which is why 1 is the default: the ZOOM action
## and the settings chip both mean "next". The settings page's LEFT arrow is the only caller that asks for
## -1, and it is ADDED to the modulus rather than negated, so stepping back off index 0 wraps to the top
## instead of landing on a negative index.
func _cycle_zoom(dir: int = 1) -> void:
	_zoom_idx = (_zoom_idx + dir + ZOOM_LEVELS.size()) % ZOOM_LEVELS.size()
	if _camera != null:
		_camera.zoom = Vector2(_current_zoom(), _current_zoom())
	Settings.zoom_idx = _zoom_idx
	Settings.save_settings()


## Cycle the fast-forward game clock (".") and apply it. Engine.time_scale scales both the sim's tick
## accumulator, so the factory runs faster, and the body's physics, which substeps so it cannot tunnel.
func _cycle_speed() -> void:
	_time_scale_idx = (_time_scale_idx + 1) % TIME_SCALES.size()
	Engine.time_scale = TIME_SCALES[_time_scale_idx]


## F5 quicksave: the sim capture and the body's position, in one versioned file. The write is atomic and
## keeps the previous save as a backup (see SaveGame.write), so a failed save leaves the old one intact and
## "save FAILED" is a survivable sentence rather than an epitaph.
func _save_game() -> void:
	var data: Dictionary = SaveGame.capture(sim)
	data["player_pos"] = _player.position
	data["lamp_tint"] = MainView.boot_tint          # representation keys ride beside the sim envelope
	# Which lessons have already been given. Without this the game re-teaches the grapple, the wrap, the chain
	# and the hard landing on every launch, because the latch lived only in memory.
	if _hints != null:
		data["hints_taught"] = _hints.taught_ids()
	# No `world_seed` line here: `capture` already wrote `sim.world_seed`, and the controller overwriting it
	# with a second copy of the same fact is precisely the bug documented at `_title_seed`.
	_hud.flash("SAVED" if SaveGame.write(save_path, data) else "save FAILED")


## F9 quickload: restore in place, so the sim object survives and every live reference stays valid, put the
## body back, and repaint the retained view caches wholesale. A missing or bad file never touches the game.
func _load_game() -> void:
	var data: Dictionary = SaveGame.read(save_path)
	if data.is_empty() or not SaveGame.restore(sim, data):
		# Three different sentences, because they are three different situations and only one of them is ordinary.
		# Telling somebody who definitely saved an hour ago that they have no save is a lie that also destroys the
		# evidence: they start a new game and overwrite what was left.
		if SaveGame.last_read == SaveGame.Read.CORRUPT:
			_hud.flash("save DAMAGED — not loaded")
		elif not data.is_empty():
			_hud.flash("save UNREADABLE — not loaded")
		else:
			_hud.flash("no save to load")
		return
	var pp: Variant = data.get("player_pos")
	if pp is Vector2:
		_player.place(pp)
		_player.velocity = Vector2.ZERO
	MainView.boot_tint = clampi(int(data.get("lamp_tint", MainView.boot_tint)), 0, LAMP_TINTS.size() - 1)
	_renderer.lamp_color = LAMP_TINTS[MainView.boot_tint]["color"]
	_renderer.repaint_world()
	_prime_breach_watch()   # a breach that happened before this save does not boom retroactively
	if _hints != null:
		# Order matters and only one order is correct: restore the taught-list first, then `resync`. `resync`
		# re-arms the pack snapshot and clears the queue, so restoring after it would be harmless today and is one
		# refactor away from a lesson being re-queued and then marked as already given. Absent in an older save,
		# which restores today's behaviour rather than breaking on it.
		_hints.restore_taught(data.get("hints_taught", []) as Array)
		_hints.resync()     # whatever the save already carries is old news, not a fresh acquisition
	_hud.flash("RECOVERED (backup)" if SaveGame.last_read == SaveGame.Read.RECOVERED else "LOADED")


## Mark every already-breached descent engine as heard, so the breach stinger fires only for a breach that
## happens on the player's watch. Runs at session start and after every load.
func _prime_breach_watch() -> void:
	_breach_heard.clear()
	for m: MachineState in sim.machines:
		if m.def.behavior == &"descent" and m.fed >= FactorySim.DESCENT_QUOTA:
			_breach_heard[m.cell] = true


## Is the cursor over the open minimap? While it is, the map owns the mouse: LMB pings it and no world verb
## fires underneath, following the rule that clicks on visible UI do not hit the world.
func _cursor_on_minimap() -> bool:
	return _minimap_mode > 0 and _hud != null \
		and _hud.minimap_frame().grow(3.0).has_point(Controls.pointer_viewport(self))


## Is the cursor over the machine inspector panel? While it is, LMB hits panel knobs and the world verbs
## stay holstered, the same UI-eats-the-click rule as the open minimap.
func _cursor_on_hover_panel() -> bool:
	if _hud == null:
		return false
	var r: Rect2 = _hud.hover_panel_rect()
	return r.size.x > 0.0 and r.has_point(Controls.pointer_viewport(self))


## Turn a clicked config-panel chip into the discrete sim call it stands for. The HUD only reports what was
## clicked; every mutation happens here, through the sim's public surface.
func _apply_knob(payload: Dictionary) -> void:
	if payload.is_empty() or sim.machine_at(_hover_latch) == null:
		return
	var label: String = ""
	match str(payload.get("knob", "")):
		"choice":
			label = sim.set_split_mode(_hover_latch, int(payload.get("index", 0)))
		"action":
			if str(payload.get("id", "")) == "clear_filter":
				label = sim.configure_machine(_hover_latch)
	if label != "":
		_hud.flash(label)
		_particles.spark(_cell_center(_hover_latch), Color(0.75, 0.85, 0.98))
		_sfx.play(&"pop", _cell_center(_hover_latch), 1.4)


## Is the cursor over the alert stack this frame? While it is, LMB marks the alert and the pick stays
## holstered, the same UI-eats-the-click rule as the open minimap and the config panel.
func _cursor_on_alerts() -> bool:
	return _hud != null and _hud.cursor_on_alerts(Controls.pointer_viewport(self))


## Clicking an alert drops the ping on the stalled machine, so its in-world beacon and map dot lead you
## there. The camera is body-locked, so this is the honest take-me-to-it. MainView owns the ping.
func _ping_alert(canvas_pos: Vector2) -> void:
	var payload: Dictionary = _hud.alert_click(canvas_pos)
	if payload.is_empty():
		return
	_ping_world = _cell_center(payload["cell"]).clamp(Vector2.ZERO, WORLD_SIZE)
	_renderer.set_ping(_ping_world)
	_hud.flash("marked — follow the beacon")


## Set or clear the ping from a click on the map (canvas coords to world). Clicking on or next to the
## existing ping clears it; anywhere else moves it. The HUD draws the map dot, the renderer the beacon.
func _toggle_ping(canvas_pos: Vector2) -> void:
	var frame: Rect2 = _hud.minimap_frame()
	var world: Vector2 = (canvas_pos - frame.position) / frame.size * WORLD_SIZE
	if _ping_world.x != INF and _ping_world.distance_to(world) < 2.5 * float(CELL):
		_ping_world = Vector2.INF
		_hud.flash("ping cleared")
	else:
		_ping_world = world.clamp(Vector2.ZERO, WORLD_SIZE)
	_renderer.set_ping(_ping_world)


## Move the active hotbar slot, wrapping across the items currently carried.
func _cycle_inventory(dir: int) -> void:
	var n: int = sim.inventory_slots().size()
	if n <= 0:
		_inv_selected = 0
		return
	_inv_selected = (_inv_selected + dir + n) % n


## Select hotbar slot `idx` directly, from the number keys. A no-op past the last carried item, so an empty
## slot cannot become the active selection.
func _select_slot(idx: int) -> void:
	if idx < sim.inventory_slots().size():
		_inv_selected = idx


## Drop the selected stack (Q). Gravity is the conveyor, so feeding is dropping: you do not insert into a
## machine, you let go above its column and it falls in, or onto the floor. It tosses forward, so the stack
## lands in the cell you are facing-and-below, which is how you stand beside a forge and toss ore in, or
## fling it over a ledge into the next shaft. If that facing cell is a wall you cannot toss through it, so
## it falls back to a straight drop down your own column and feeding a shaft you stand over still works.
## The body's cell is the visual launch origin; the sim cascades the landing.
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
	# The toss finds the mouth. Gravity is still the conveyor, but the first ore-to-ingot handoff was fiddly
	# out of all proportion to its importance: stand a cell off, or face the wrong way, and the stack lands at
	# your feet, gets auto-scooped a moment later, and you try the whole dance again. So when a machine in
	# reach genuinely eats what you are holding, the toss goes in. Everything else keeps the old arc: over a
	# ledge, down a shaft, onto the floor. This only ever redirects a throw a machine wanted anyway.
	var mouth: MachineState = _reachable_eater(item)
	if mouth != null:
		var fed: int = sim.deposit(mouth.cell, item, carried)
		if fed > 0:
			_particles.pop(_cell_center(mouth.cell), Visuals.item_color(item))
			_sfx.play(&"pop", _cell_center(mouth.cell), 1.2)
			return true
	var face: Vector2i = here + Vector2i(_player.facing, 0)
	# Toss forward into the facing column when it is clear, meaning open air or a machine to feed; a solid wall
	# blocks the toss, so drop straight down instead. Landing is sim-truth; `here` is the launch origin.
	var target: Vector2i = face if (sim.in_bounds(face) and not sim.is_solid(face)) else here
	var dropped: int = sim.drop_item(target, item, carried, here)
	if dropped > 0:
		_no_pickup[sim.last_drop_landing] = DROP_GRACE_S   # do not instantly suck it back up
		_particles.pop(_cell_center(target), Visuals.item_color(item))
	return dropped > 0


## The nearest machine in reach that would actually consume `item`, or null. Ties break by distance, so a
## wall of machines feeds the one you are standing at rather than the one first in the list.
func _reachable_eater(item: StringName) -> MachineState:
	var best: MachineState = null
	var best_d: float = INF
	for machine: MachineState in sim.machines:
		if not _can_reach(machine.cell) or not sim.machine_eats(machine, item):
			continue
		var d: float = _player.position.distance_squared_to(_cell_center(machine.cell))
		if d < best_d:
			best_d = d
			best = machine
	return best


## RMB build verb: standing in reach of `cell`, place the selected machine on an open cell, or pick one of
## your own machines back up. Reach-limited and situated, the embodied replacement for a god-cursor
## palette. Every edit goes through the sim's discrete place and remove API, so the body still only
## triggers discrete mutations and determinism is preserved. Returns whether anything happened.
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
		if sim.retract_rope(cell) > 0:   # RMB any segment and the whole rope returns
			_sfx.play(&"pop", _cell_center(cell), 0.8)
			return true
		return false
	if sim.has_torch(cell):
		if sim.remove_torch(cell):       # take a mounted torch back into the pack
			_sfx.play(&"pop", _cell_center(cell), 0.9)
			return true
		return false
	if sim.sapling.has(cell):
		if sim.remove_sapling(cell):     # take a planted sapling back (growth so far is forfeit)
			_sfx.play(&"pop", _cell_center(cell), 1.1)
			return true
		return false
	# Plant a carried sapling on soil, the renewable-wood verb: selected sapling plus open ground.
	if _selected_item() == &"sapling":
		var rooted: bool = sim.plant_sapling(cell)
		if rooted:
			_particles.dust(_cell_center(cell) + Vector2(0.0, 8.0), Color(0.35, 0.55, 0.25), 5)
			_sfx.play(&"pop", _cell_center(cell), 1.3)
			# The renewability claim rides the first successful plant rather than the pickup. Poked once and never
			# unpoked: `Hints` latches on the rising edge and again in `_done`, so a second sapling is not a second
			# lesson.
			if _hints != null:
				_hints.note(&"planted", true)
		return rooted
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
		var hung: int = sim.place_rope(cell)      # anchors here and unrolls down the open column
		if hung > 0:
			_particles.spark(_cell_center(cell), Visuals.machine_color(def).lightened(0.3))
			_sfx.play(&"pop", _cell_center(cell), 0.85)
		return hung > 0
	if def != null and _placeable(cell):
		var placed: MachineState = sim.build_from_pack(def, cell)
		if placed != null:
			# Directional machines work the way you faced when placing (the Borer bores that way).
			placed.facing = _player.facing if _player != null else 1
			_renderer.note_machine_built(cell)   # play the one-shot assemble overlay
			_particles.spark(_cell_center(cell), Visuals.machine_color(def).lightened(0.3))
			_shake = maxf(_shake, 2.2)
			_sfx.play(&"clunk", _cell_center(cell))
		return placed != null
	# Block placement: the selected hotbar item is a building material.
	var mat: StringName = _selected_build_material()
	if mat != &"" and _placeable(cell) and sim.block_supported(cell) and sim.place_block(cell, mat):
		_particles.dust(_cell_center(cell), Visuals.terrain_dust(mat), 6)
		_sfx.play(&"crunch", _cell_center(cell), 0.75)
		return true
	return false


## The world-cell readout for the HUD info panel, built in scenes/hover_info.gd: a machine's name, its
## recipe as inputs and outputs in item lists, its routing mode, and what it currently holds. MainView
## supplies the two bits of controller context the readout cannot compute itself: whether the cell is in
## reach, using the same reach gate the verbs use, and the current drill rate from the machine-def table.
## Pure read of the sim.
const HoverInfo := preload("res://scenes/hover_info.gd")


func _hover_info() -> Dictionary:
	return _hover_info_at(_aim)


## The same read for an explicit cell: the config-panel pin re-reads the latched machine while the cursor
## is off exploring the panel's own knobs.
func _hover_info_at(aim: Vector2i) -> Dictionary:
	return HoverInfo.describe(sim, aim, _can_reach(aim), _drill_rate())


## The item id in the active hotbar slot, or &"" when the pack is empty.
func _selected_item() -> StringName:
	var slots: Array[Dictionary] = sim.inventory_slots()
	if slots.is_empty():
		return &""
	return slots[clampi(_inv_selected, 0, slots.size() - 1)]["item"]


## The machine def for the active hotbar slot, or null when the selected item is not a placeable machine
## you carry, meaning it is a resource or the pack is empty.
func _selected_machine_def() -> MachineDef:
	var slots: Array[Dictionary] = sim.inventory_slots()
	if slots.is_empty():
		return null
	var sel: int = clampi(_inv_selected, 0, slots.size() - 1)
	return _machine_defs_by_id.get(slots[sel]["item"], null)


## The building material for the active hotbar slot, or &"" when the selected item is not a placeable
## block. Drives RMB block placement and the renderer's placement ghost.
func _selected_build_material() -> StringName:
	var slots: Array[Dictionary] = sim.inventory_slots()
	if slots.is_empty():
		return &""
	var sel: int = clampi(_inv_selected, 0, slots.size() - 1)
	var item: StringName = slots[sel]["item"]
	return item if item in BUILD_MATERIALS else &""


## A cell takes a hand-placed machine when it is in-bounds, unoccupied, and not the cell the body is
## standing in, so you can never seal yourself inside a machine you place. Occupancy is the sim's answer
## and not a second opinion. `factory_sim.gd` records the stress test that caught per-function guards
## each checking a different subset of the placed layers, and this copy had drifted the same way: it listed
## solid/machine/conduit/rope and never asked about `torch`. The ghost therefore drew its placeable border
## over a mounted torch and unrolled the rope and drill previews (`world_renderer.gd`) where the
## click is really the pickup at :2386 that every sim placement path refuses outright. Bounds and the body
## are the two halves the sim cannot answer, because it owns no avatar. The placed layers are asked once
## over there, so the next one added there arrives here free.
func _placeable(cell: Vector2i) -> bool:
	return sim.in_bounds(cell) and not sim.cell_occupied(cell) and not _player_occupies(cell)


## Placeable for the current selection: a machine only needs an open cell, but a building block also needs
## support, since rock cannot be plopped in mid-air. Drives both the ghost colour and the place gate, so
## the two can never disagree.
func _placeable_here(cell: Vector2i) -> bool:
	if not _placeable(cell):
		return false
	var def: MachineDef = _selected_machine_def()
	if def != null and def.behavior == &"spur":
		return spur_fits(cell)
	if def == null and _selected_build_material() != &"":
		return sim.block_supported(cell)
	return true


## A spur has two conditions and both are visible in the world. It eats what it stands on, the same rule as
## the Head, so it needs a lode behind it; and it is one more mouth on an existing drill, so it has to
## touch a Head or a Spur that chains back to one. Gated at placement rather than allowed and then reported
## broken: an unlinked Spur is a machine doing nothing, and docs/DRIFT.md §6 is explicit that placement is
## the thing that will be got wrong every time if it is not refused clearly at the moment of the attempt.
## The ghost turns red before the click, and the hover says which half is missing.
func spur_fits(cell: Vector2i) -> bool:
	return sim.lode_at(cell) != &"" and sim.spur_head(cell).x >= 0


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


## The grid cell the body occupies: the origin for mining line-of-sight.
func _body_cell() -> Vector2i:
	return _cell_at(_player.position)


## Can the body actually mine `cell`? Reach radius is not enough: you cannot dig through solid rock to a
## block behind it. A block is mineable only if a straight line from the body to it is clear of other solid
## cells, so you carve the exposed face of a wall one layer at a time and the pocket grows into it, which
## makes the dig carving rather than poking a radius blob. Building and hover keep the plain reach test;
## this gates mining only.
func _mineable(cell: Vector2i) -> bool:
	if not (sim.is_solid(cell) and _can_reach(cell) and _line_of_sight_clear(_body_cell(), cell)):
		return false
	# The wedge splits or it does nothing. It is the one bit that can refuse a cell, and the refusal has to
	# live here rather than in try_mine: the hold-loop charges on this same predicate, so a cell that looked
	# mineable and then would not break would spider a full charge and start over forever. Gating the
	# predicate instead means the aim cursor greys out on rock the Wedge cannot split before you press
	# anything, which is also the honest way to sell a specialist tool.
	return _bit_bites(BitRules.equipped(_selected_item()), cell)


## Can this bit break this cell at all? Only the Wedge ever says no, and only across the grain.
func _bit_bites(bit: StringName, cell: Vector2i) -> bool:
	if not BitRules.grain_only(bit):
		return true
	return Seams.aligned(Seams.at(cell, sim.world_seed), _swing_heading(cell))


## The blow's heading, in world pixels from the body to the struck cell. Deliberately not `_swing_dir`,
## which quantises to four compass directions: after that quantisation a diagonal plane is
## indistinguishable from an axis-aligned one, so every diagonal seam would read as along-the-grain from
## any angle and the rarest, most satisfying plane in the world would become the most forgiving one.
func _swing_heading(cell: Vector2i) -> Vector2i:
	if _player == null:
		return Vector2i.ZERO
	var d: Vector2 = _cell_center(cell) - _player.position
	return Vector2i(roundi(d.x), roundi(d.y))


## A tool or bit's ingredient cost. One lookup, so the craft screen and the craft verb can never disagree
## about what something costs.
func _tool_recipe(id: StringName) -> Dictionary:
	if BitRules.BIT_RECIPES.has(id):
		return BitRules.BIT_RECIPES[id]
	return MiningRules.TOOL_RECIPES.get(id, {})


## Is the straight segment from cell `a` to cell `b` clear of solid cells strictly between them? A grid
## voxel-walk (Amanatides-Woo DDA) from a toward b: the first solid cell entered before reaching b blocks
## the ray. The target b itself may be solid, since it is what you are mining, and adjacent cells are
## always clear because no cell lies between. Pure read of sim.is_solid: deterministic, no allocation.
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


## World-space hint cells for the current objective step: where do I do that? Each is {cell, mode}, where
## "act" pulses a target ring here (mine this rock, feed this forge) and "ghost" outlines where to place
## the next machine. The view pulses them; deleting this changes no production number, since it is a pure
## read of the sim and the objective state. Maps the objective id onto fixtures and sim queries.
func _guide_targets() -> Array[Dictionary]:
	if _objectives == null or _objectives.all_done():
		return []
	var out: Array[Dictionary] = []
	match _objectives.current_id():
		&"mine":
			var ore: Vector2i = _nearest_material_to_player(&"ore")
			if ore.x >= 0:
				out.append({"cell": ore, "mode": "act"})
		&"smelt":
			var forge: Vector2i = _first_forge()
			if forge.x >= 0:
				out.append({"cell": forge, "mode": "act"})
		&"wood":
			var tree: Vector2i = _nearest_material_to_player(&"wood")
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


## True when the body stands close enough to a claimed, completed Bazaar to craft machines there. Away from
## it the E screen shows the pack but no recipes.
func _near_bazaar() -> bool:
	return _player != null and sim.near_bazaar(_cell_at(_player.position), BAZAAR_RADIUS)


## The nominal extraction rate of a Drill in ore per second, one unit per recipe cycle. Read off the drill
## def so it tracks the recipe rather than a magic number; the hover inspector surfaces it.
func _drill_rate() -> float:
	var drill: MachineDef = _machine_defs_by_id.get(&"drill", null)
	if drill == null or drill.recipe == null or drill.recipe.time <= 0.0:
		return 0.0
	return 1.0 / drill.recipe.time


## The cell of the first forge (processor) placed in the world, or (-1,-1) if none. The smelt and build
## guides follow the forge wherever it sits, seeded or player-built.
func _first_forge() -> Vector2i:
	for m: MachineState in sim.machines:
		if m.def.id == &"processor":
			return m.cell
	return Vector2i(-1, -1)


## The nearest solid cell of one material, by squared cell distance from the body. Two callers: the dig
## target for the opening step, where the starter vein by spawn wins by proximity and the answer keeps
## pointing at real ore as veins deplete; and the chop target for the wood step, where trees are sparse on
## the surface so the closest one is the difference between an errand and a hunt.
##
## THIS WAS THE SAME FUNCTION TWICE, differing in one material literal. Neither copy was wrong, which is
## how it survived: a duplicate only announces itself when the two sides drift, and until then it reads as
## two functions that happen to agree.
func _nearest_material_to_player(material: StringName) -> Vector2i:
	var here: Vector2i = _cell_at(_player.position)
	var best := Vector2i(-1, -1)
	var best_d: int = 1 << 30
	for cell_v: Variant in sim.solid:
		var cell: Vector2i = cell_v
		if sim.solid[cell] != material:
			continue
		var d: int = (cell - here).length_squared()
		if d < best_d:
			best_d = d
			best = cell
	return best
