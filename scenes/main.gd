class_name MainView
extends Node2D

## The CONTROLLER + session root. OWNS a FactorySim (game-session-owns-sim rule),
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
## The internal render viewport (project.godot). Bumped 640×360 → 1280×720 for the SCALE spike: 2× the
## pixel density keeps the world crisp when the camera is zoomed WAY out (Noita: small avatar, big world).
## The HUD authors in Hud.CANVAS (640×360) space; its CanvasLayer is scaled by HUD_SCALE to fill this.
## World-area-shown math (motes/camera/minimap) reads VIEWPORT, not CANVAS, since they diverged here.
const VIEWPORT := Vector2(1280.0, 720.0)
const HUD_SCALE: float = VIEWPORT.x / 640.0        ## = 2.0; scales the 640×360 HUD onto the 1280×720 render
## Zoom levels cycled by Z (Terraria-style). _current_zoom() reads the active level everywhere. Smaller =
## further out; Z cycles outward and wraps.
##
## Index 0 is 1.00× (#A4, 2026-08-16). The previous default of 0.70× showed a 57×32-cell field, which put
## the miner at well under one percent of the frame's width — the measured floor under "it's hard to see
## the character at base zoom". Every code lever for his presence (cool two-tone rim, head-lamp, guide
## ring) was already pulled, and the blind judges still found him via the marker rather than the sprite,
## because at that size there is no sprite left to find. 1.00× shows 40×22 cells — still a wide side-view
## field, comfortably wider than Terraria's in tile terms — and buys back 43% of linear size on
## everything: the avatar becomes a character, a 32px cell shows its rock texture instead of blooming
## into a smear, and machine labels clear the declutter threshold with room to spare.
##
## The old default survives one step out (0.70×, the 2026-08-09 "Sees" A/B pick), then 0.50× (the
## big-world feel) and 0.33× (survey the whole base). Nothing was taken away — the frame just starts
## where the character is legible, and widens on demand.
const ZOOM_LEVELS: Array[float] = [1.00, 0.70, 0.50, 0.33]
var _zoom_idx: int = 0
const WORLD_SEED: int = 1337       ## the default gen seed (the title screen can reroll it — #6)

## --- THE TITLE / NEW-GAME screen -------------------------------------------
## Opens on a REAL boot only: every harness fixture and play-test launches with `--script`, which
## suppresses it — so scripted drivers land in the live world instantly and ZERO fixtures change.
## Pick a world seed (TAB rerolls) and your lamp tint (←/→), ENTER descends. A changed seed reboots
## the scene through the statics below (they survive reload_current_scene); an unchanged one just
## drops the veil. C continues the F5/F9 save.
var _title_open: bool = false
var _title_seed: int = WORLD_SEED
var _title_tint: int = 0
var _world_seed: int = WORLD_SEED           ## the seed THIS world was actually built with
static var boot_seed: int = -1              ## >=0: the next boot generates with this seed
static var boot_tint: int = 0               ## the picked lamp tint index (persists across reloads)
static var boot_skip_title: bool = false    ## set before a new-world reload: land straight in the game
## Your LAMP is your identity in the deep (#45): the tint colours the head-lamp's pools everywhere.
const LAMP_TINTS: Array[Dictionary] = [
	{"name": "miner's gold", "color": Color(1.0, 0.90, 0.66)},
	{"name": "carbide white", "color": Color(0.92, 0.96, 1.0)},
	{"name": "ember orange", "color": Color(1.0, 0.74, 0.44)},
	{"name": "willow green", "color": Color(0.80, 1.0, 0.72)},
	{"name": "violet arc", "color": Color(0.88, 0.74, 1.0)},
]
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
## The camera's un-snapped follow position (smoothed toward the body each frame); the value ACTUALLY
## assigned to the camera is snap_to_pixel'd off this, so motion stays soft but the render is crisp.
var _cam_pos: Vector2 = Vector2.ZERO
var _cam_lead: Vector2 = Vector2.ZERO   ## the eased velocity look-ahead the camera adds to the body (#S4)
const CAMERA_LEAD_TIME: float = 0.34    ## seconds of travel the camera leads by — how far "ahead" is
const CAMERA_LEAD_MAX: float = 170.0    ## px cap, so a terminal-velocity fall can't shove the body off-frame
const CAMERA_LEAD_VERTICAL: float = 0.55
const CAMERA_LEAD_EASE: float = 5.0     ## per-second easing on the lead itself (a lurch reads as a bug)
const CAMERA_FOLLOW_SPEED: float = 8.0   ## matches the old position_smoothing_speed (soft follow)
var _renderer: WorldRenderer       ## the VIEW: all world-space drawing + lighting (we push it aim state)
var _hud: Hud                      ## screen-space HUD (we push it objectives + the machine inspector)
var _paused: bool = false
## On-demand UI state (the calm-screen model): the crafting screen (E), the map (M), and the controls
## help (H/?) are summoned, not permanent. Pushed to the HUD each frame so it knows what to draw.
var _inventory_open: bool = false   ## E opens the PACK (Minecraft-style); crafting lives inside it, but
                                    ## machine-crafting is GATED on standing near a claimed Bazaar
## Minimap mode: 0 hidden · 1 corner · 2 LARGE (centred). M cycles; Esc closes.
var _minimap_mode: int = 0
## The player's PING marker in world coords (Vector2.INF = none): click the open map to set it, click
## it again to clear. A navigation bookmark — pushed to the HUD (map dot) + renderer (in-world beacon).
var _ping_world: Vector2 = Vector2.INF
var _hover_latch: Vector2i = Vector2i(-9999, -9999)   ## the machine the config panel is pinned to (#32)
## THE SETTINGS overlay: ESC (with nothing else open) summons it — audio sliders,
## screen-shake, zoom, and the remap page the Controls foundation was built for. While it's open it
## eats all input (the "open map is UI" rule, page-sized). _capture_action = the action awaiting its
## new key ("press a key…"); _settings_drag = the slider id being dragged.
var _settings_open: bool = false
var _capture_action: StringName = &""
var _settings_drag: String = ""
var _show_help: bool = false
var _show_tech: bool = false        ## T — the TECH TREE overlay; viewable anywhere,
                                    ## the research VERB (R) stays Bazaar-gated like the bench
var _show_dashboard: bool = false   ## G — the PRODUCTION DASHBOARD; non-modal read
## Fast-forward game clock: "." cycles Engine.time_scale through this exponential ladder so the whole
## game (sim ticks AND the body) runs faster — watch a factory fill, or (headless) speed up play-tests.
## The body integrates in substeps (Player.MAX_SUBSTEP) so it can't tunnel at the high multipliers.
const TIME_SCALES: Array[float] = [1.0, 2.0, 4.0, 8.0]
var _time_scale_idx: int = 0
## Timed-mining (the friction): holding LMB CHARGES the aimed cell; it breaks when the charge reaches the
## material's hardness (scaled by your best tool's speed). _mine_target tracks which cell is charging.
## The charge fraction is pushed to the renderer (crack viz).
var _mine_target: Vector2i = Vector2i(-999, -999)
var _mine_charge: float = 0.0
## THE ROCK REMEMBERS (#B1). Charge is banked PER CELL, not per aim: a cursor slip onto a neighbour used
## to zero the whole dig, which is the single most-punishing feel bug in the early game — the pain of
## mis-aiming dwarfed the pain of the rock. Now the cracks you chipped stay chipped, and returning to a
## block RESUMES it. Left alone the rock heals: CRACK_HOLD seconds of grace (so a slip costs literally
## nothing), then the banked charge bleeds off at CRACK_HEAL/s and the entry evicts itself at zero — the
## table stays small without a cap, and abandoned half-digs don't linger as free progress forever.
const CRACK_HOLD: float = 2.5    ## seconds a cell keeps its full banked charge after you look away
const CRACK_HEAL: float = 0.5    ## charge-seconds bled per second once the grace expires
var _cracks: Dictionary = {}     ## Vector2i -> Vector2(banked charge seconds, seconds since last worked)
var _aim: Vector2i = Vector2i(-99, -99)
## The DIG PLAN (smart mining): dragging LMB across rock PAINTS marks (cell -> true),
## a plan that persists after release; while LMB is held and the cursor isn't on a workable block, the
## miner works the nearest MARKED cell in reach instead — so you sketch a shaft once and hold, rather
## than re-aiming every block. Player INTENT, not production state: lives here (controller) + a renderer
## overlay, never enters the sim, isn't saved. Reach/LOS/tool gates are the same ones try_mine enforces.
var _dig_marks: Dictionary = {}
var _last_paint_world: Vector2 = Vector2.INF   ## last cursor world-pos while painting (sweep interpolation)
const MAX_DIG_MARKS: int = 200
## The machines you can CRAFT (1/2 keys → craft one into the pack, spending ingots). The ore_vent (a
## SOURCE) is deliberately absent — you remain the ore source by hand (manual→automated pillar; see
## 2026-06-27). `_machine_defs_by_id` resolves a carried hotbar item back to its def so a
## selected machine item can be placed.
var _craftable: Array[MachineDef] = []
var _machine_defs_by_id: Dictionary = {}
## Craftable TOOLS (id + display name; cost lives in MiningRules.TOOL_RECIPES) shown in the Bazaar craft
## screen after the machines. The Stone Pickaxe is the first depth-unlocking upgrade.
const CRAFT_TOOLS: Array[Dictionary] = [
	{"id": &"stone_pickaxe", "name": "Stone Pickaxe"},
	{"id": &"iron_pickaxe", "name": "Iron Pickaxe"},
	{"id": &"scanner", "name": "Scanner"},
]
## THE SCANNER: with it selected, RMB fires a sonar pulse from the body — ore bodies in
## range answer with echo rings THROUGH the rock (transient, localized: prospecting, not a map reveal).
const SCAN_RANGE_CELLS: float = 14.0
const SCAN_COOLDOWN: float = 1.6           ## pacing between pulses (feel, not economy)
var _scan_cooldown: float = 0.0
var _scan_dings: Array[Dictionary] = []    ## scheduled sonar returns: {at: seconds-from-now, pos, near}
## Which carried-item slot is active in the inventory hotbar (mouse-wheel cycles it). The selected
## item is what E deposits (a resource) or RMB places (a machine) — the unified Factorio-style hotbar.
var _inv_selected: int = 0
## Cosmetic falling-product layer (driven by the sim's flow_events, never feeds back). Its own module.
var _falling := FallingItems.new()
## Bazaar view: detects completed wood frames (sim.find_bazaars) and plays the block-by-block transform
## into a decorated stall + shopkeeper. Representation-only; never writes the sim.
var _bazaars := Bazaars.new()
## Cosmetic particle + screenshake juice (dig/land/place/collect). Pure representation.
var _particles := Particles.new()
## The "+N" gain ticks that rise off a broken block — the payoff shown where you're looking, instead of
## only as a number in the corner of the HUD. Pure representation.
var _payouts := Payouts.new()
var _shake: float = 0.0            ## current screenshake magnitude (px), decays each frame
var _step_dist: float = 0.0       ## accumulated walk distance, for periodic footstep dust
const SWING_PERIOD: float = 0.28   ## seconds between pick-blows while charge-mining (the swing cadence)
var _swing_clock: float = SWING_PERIOD  ## primed so a fresh charge's first blow lands instantly
## The tutorial chain (representation-layer legibility — the "how do I play?" signpost). Reads the sim.
var _objectives: Objectives
## Just-in-time hint bubbles: first rope in the pack → "RMB above a drop", etc. Reads the sim.
var _hints: Hints
## GPU ambient dust motes — a continuous GPUParticles2D haze that drifts in the
## air and catches the lamp light. Pure atmosphere; follows the camera each frame.
var _motes: GPUParticles2D
## Procedural audio — synthesized SFX + the factory hum. Poked from the same verb hooks
## that fire particles; never touches the sim.
var _sfx: Sfx
## Descent engines whose breach we've already sounded (cell -> true). Primed on seed/load so an engine
## that breached before this session doesn't boom retroactively; a live breach booms exactly once.
var _breach_heard: Dictionary = {}


func _ready() -> void:
	Controls.register()    # register the remappable InputMap actions (the settings page rebinds them)
	if not _is_scripted_boot():
		# Machine-local prefs — REAL boots only: fixtures/tests always run on pure
		# defaults and can never read or clobber the dev's settings file (harness determinism).
		Settings.persist = true
		Settings.load_settings()
		_zoom_idx = clampi(Settings.zoom_idx, 0, ZOOM_LEVELS.size() - 1)
	sim = FactorySim.new()
	_craftable = [
		load("res://src/data/machines/processor.tres"),
		load("res://src/data/machines/splitter.tres"),
		load("res://src/data/machines/lift.tres"),
		load("res://src/data/machines/drill.tres"),  # automates ore extraction
		load("res://src/data/machines/hopper.tres"),  # stockpiles + meters gravity-fed output (the 'chest')
		load("res://src/data/machines/generator.tres"),  # burns coal → power
		load("res://src/data/machines/conduit.tres"),     # carries power down+lateral
		load("res://src/data/machines/rope.tres"),        # the placeable climb — unrolls down a shaft
		load("res://src/data/machines/torch.tres"),       # placeable LIGHT — claimed territory in the black
		load("res://src/data/machines/descent_engine.tres"),  # the L1→L2 gate-breacher (docs/PROGRESSION.md)
		# The L2 crafter modules (— per-item, gravity-fed): the iron chain.
		load("res://src/data/machines/iron_forge.tres"),
		load("res://src/data/machines/plate_press.tres"),
		load("res://src/data/machines/gear_mill.tres"),
		load("res://src/data/machines/h_drill.tres"),     # the Borer — sideways extraction
		load("res://src/data/machines/blast_furnace.tres"),   # 1 rich ore → 2 ingots (#48, Enrichment)
		load("res://src/data/machines/pump.tres"),        # L3: power-drains flood water (Drainage)
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
	# PIXEL-SNAP the follow (playtest: "texture blurs while running"). The built-in position_smoothing
	# renders the camera at a fractional position, so every terrain texel samples between screen pixels
	# each frame → shimmer/blur in motion. Instead we smooth toward the body OURSELVES (same soft feel)
	# and round the RESULT to a whole screen pixel via snap_to_pixel — crisp terrain, soft follow. That
	# needs top_level so we own the camera's global position outright, not the body's transform.
	_camera.position_smoothing_enabled = false
	_camera.top_level = true
	# CENTERED on the body — no dead-zone. The avatar is the player's anchor and must always be the
	# focal point; the old drag margins let it drift into a screen corner (and under the HUD), which read
	# as "I can't find my character". Our manual smoothing eases the follow so motion stays soft.
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
	# The HUD draws in Hud.CANVAS (640×360) space; the render viewport is now VIEWPORT (1280×720), so scale
	# the whole HUD layer up by HUD_SCALE to fill the doubled render target (world-space is untouched).
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
	# Craftable TOOLS listed AFTER machines (the Bazaar crafts both). Not placeable, so
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
	# Hint bubbles — same pattern: built after seeding (a pre-stocked pack fires nothing at boot).
	_hints = Hints.new(sim)
	_hud = hud
	layer.add_child(hud)
	add_child(layer)

	# The VIEW: a WorldRenderer draws all world-space sim state (terrain, machines, ground, falling
	# items, lighting). It reads the sim + the aim state we push each frame; it never mutates anything.
	# Its draw sits at z 0 and its lighting at z 50/51, so the player (z 60) stays crisp on top.
	_renderer = WorldRenderer.new()
	_renderer.setup(sim, _falling, _player)
	_renderer.particles = _particles
	_renderer.payouts = _payouts
	_renderer.bazaars = _bazaars
	_renderer.set_dig_marks(_dig_marks)   # a LIVE reference — the overlay tracks the plan as it's painted
	add_child(_renderer)

	# Hand the HUD minimap a material-colour lookup (the renderer owns the MaterialDef registry) so the
	# map can paint terrain without the HUD depending on the renderer's internals.
	hud.minimap_color = _renderer.material_color

	_setup_post_fx()
	_prime_breach_watch()   # fixtures may seed pre-breached engines; they don't boom at boot

	# The lamp tint (#45) survives reloads via the static; apply it to the view.
	_renderer.lamp_color = LAMP_TINTS[clampi(MainView.boot_tint, 0, LAMP_TINTS.size() - 1)]["color"]
	# THE TITLE (#6): a real boot opens on the new-game screen; every scripted boot (harness, fixtures,
	# play-tests — all launched with --script) lands straight in the live world.
	if not _is_scripted_boot() and not MainView.boot_skip_title:
		_open_title()
	MainView.boot_skip_title = false


## Was this process launched to run a script (harness fixture / play-test) rather than the game?
static func _is_scripted_boot() -> bool:
	for arg: String in OS.get_cmdline_args():
		if arg == "--script" or arg == "-s":
			return true
	return false


func _open_title() -> void:
	_title_open = true
	_paused = true
	_title_seed = _world_seed
	_title_tint = clampi(MainView.boot_tint, 0, LAMP_TINTS.size() - 1)
	if _player != null:
		_player.auto_input = false        # the miner stands still behind the veil


## ENTER on the title: an unchanged seed just drops the veil; a new seed rebuilds the whole session
## through the boot statics (they survive reload_current_scene).
func _confirm_title() -> void:
	MainView.boot_tint = _title_tint
	if _title_seed != _world_seed:
		MainView.boot_seed = _title_seed
		MainView.boot_skip_title = true
		get_tree().reload_current_scene()
		return
	_dismiss_title()


## Close the title veil over THIS world (no reboot) and hand control to the body.
func _dismiss_title() -> void:
	MainView.boot_tint = _title_tint
	_renderer.lamp_color = LAMP_TINTS[_title_tint]["color"]
	_title_open = false
	_paused = false
	if _player != null:
		_player.auto_input = true


## Modern-rendering layer: a WorldEnvironment post-process that gives the scene
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
	# THE GRADE (#A3). Kept gentle — Terraria never sacrifices legibility — but the old numbers were so
	# close to identity that the world stayed a same-value brown/grey jumble the eye couldn't get purchase
	# on. SATURATION is the lever that does the most here and costs the least: it separates dirt from rock
	# from ore from machine by HUE, where a contrast push would just crush an underground that is already
	# near-black. Contrast rises a little for form, and brightness a little more to hold the darks up
	# under it, so the deep stays readable.
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 1.18
	env.adjustment_brightness = 1.03
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
##. It fills the camera view (repositioned to the camera each frame) and sits at
## z 45, BELOW the lighting veil (z 50) + light pools (z 51), so a mote is dark in the gloom and lit
## warm where the lamp/glow reaches — "dust catching the light." Pure atmosphere; never touches the sim.
func _setup_ambient_motes() -> void:
	var view: Vector2 = VIEWPORT / _current_zoom()    # world area the camera shows (render viewport / zoom)
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
	mat.scale_max = 2.1
	# A LIVING FRAME (#A6). The field was tuned down to 0.20/55 to stop it fogging the screen, and
	# overshot into invisibility — atmosphere you cannot see is atmosphere you did not build. Denser and
	# a touch brighter, with a wider size range so near motes read as near: enough that the air is
	# visibly moving in a still frame, still well under the fog line that motivated the original cut.
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


## Build the starting world through the world-engine handshake: a swappable
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
## A visible ORE VEIN breaching the surface beside spawn — the "metal-flecked rock" the first objective
## points at, and the bootstrap ore you HAND-mine for the first ingots (depth-banded worldgen leaves the
## shallow surface near-bare, so onboarding can't rely on finding a vein). A 1-tall, 2-wide band so it READS
## as a vein yet mining it leaves only a SHALLOW (1-tile) trench you step straight out of — a 2-deep pit
## would trap the body (step-up climbs one tile). Hand-mined for the first few ore (the drill mines the deep
## veins in the mineshaft, not this surface strip). Realized by WorldSeeder.
const STARTER_VEIN_CELL := Vector2i(47, SURFACE)
## A guaranteed surface COAL block between the shaft and the bazaar — the drill's FUEL.
## Once you cap the deposit with a drill, it won't run without coal; this is the "go mine coal" target that
## closes the demand-web. Placed at col 54 — one left of the shaft's edge (55) on the rightward path, so
## mining it then tossing coal down the open shaft (56) is a short step. Rich enough that one hand-burst
## (3-8) fuels the drill well past its deposit. Realized by WorldSeeder.
const TUTORIAL_COAL_CELLS: Array[Vector2i] = [Vector2i(54, SURFACE)]
## A guaranteed TUTORIAL TREE on the surface between spawn and the shaft — the wood source the bazaar step
## needs (depth-banded worldgen plants trees out past the ruin, unreachable on the surface early). Trees are
## Terraria-style WALK-THROUGH (Player._blocked passes wood/leaves), so the trunk sitting on the tutorial
## path is fine — the body strolls through it and chops it in passing, no walling even for the taller body.
## Crowned with leaves so it reads + fells as a real tree. Realized by WorldSeeder.
const TUTORIAL_TREE_COL := 51

## The world builder. MainView owns the layout constants above (the canonical contract the play-tests assert
## against); scenes/world_seeder.gd is the procedure that realizes them — the tutorial fixtures, the starter
## kit, and the optional dev pack — onto the freshly-loaded sim. Preloaded by PATH (not class_name) so the
## headless test drivers resolve it without a refreshed global-class cache.
const WorldSeeder := preload("res://scenes/world_seeder.gd")


func _seed_world() -> void:
	var gen: WorldGen = LayeredWorldGen.new()
	_world_seed = MainView.boot_seed if MainView.boot_seed >= 0 else WORLD_SEED   # the title's pick (#6)
	var world: WorldData = gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, _world_seed)
	sim.load_world(world)
	WorldSeeder.seed_tutorial(sim, dev_start)


func _process(delta: float) -> void:
	if not _paused:
		sim.advance(delta)
		_falling.spawn_from_events(sim, _cell_center)
		_falling.advance(delta)
		_age_drop_grace(delta)
		_collect_ground_under_player()
	_update_mining(delta)  # refreshes _aim from the mouse
	_update_bazaars(delta)
	_update_juice(delta)
	if _camera != null:
		# Soft follow toward the body, then PIXEL-SNAP the render so the terrain doesn't shimmer in motion.
		# A big jump (spawn / F9 load / a teleport) SNAPS instead of panning across the whole world — which
		# also keeps capture fixtures centred the instant they reposition the body.
		# LOOK-AHEAD (#S4). The camera leads the body along its own velocity, so at speed you see where you
		# are GOING rather than where you have been. Without it, every fast move — a swing, a long fall —
		# spends its most interesting half off-screen, and the player brakes to see. The lead is capped in
		# world px and eased so it doesn't lurch on a direction change, and it goes to zero at a standstill
		# so the resting frame is still centred on the miner.
		var lead: Vector2 = _player.velocity * CAMERA_LEAD_TIME
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
	if _objectives != null:
		_objectives.refresh(delta)
	if _hints != null and not _paused:
		if _player != null:
			_hints.note_in_water(_player._in_water())   # feed the body's wet state for the AQUIFER edge
			var pc: Vector2i = _cell_at(_player.position)
			_hints.note_depth(pc.y - sim.surface_row(pc.x))   # ...and its depth, for the GRAPPLE edge
		_hints.refresh(delta)
	# Push the cursor + its computed affordances to the view (it can't derive reach/placeable itself).
	_renderer.set_aim(_aim, _can_reach(_aim), _placeable_here(_aim), _selected_machine_def(), _selected_build_material())
	_renderer.set_guide_targets(_guide_targets())   # pulse WHERE the current objective happens
	if _hud != null:
		# The config-panel PIN (#32): while the cursor sits on the inspector itself, keep showing the
		# machine it opened for (else reaching for a knob would move the aim and close the panel).
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
		_hud.ping_world = _ping_world
		_hud.show_help = _show_help
		_hud.show_tech = _show_tech
		_hud.show_dashboard = _show_dashboard
		_hud.alerts = sim.machine_problems()    # stalled machines → the left-edge alert stack (#29)
		_hud.settings_open = _settings_open
		_hud.settings_capture = _capture_action
		_hud.title_info = {} if not _title_open else {
			"seed": _title_seed, "tint": _title_tint,
			"tint_name": str(LAMP_TINTS[_title_tint]["name"]),
			"tints": LAMP_TINTS,
			"has_save": FileAccess.file_exists(SAVE_PATH),
		}
		_hud.time_scale = TIME_SCALES[_time_scale_idx]
		if _player != null:
			_hud.minimap_focus = _player.position
			_hud.minimap_view = VIEWPORT / _current_zoom()  # world area the camera shows (render viewport / zoom)
		# The hint bubble: text + fade from the tracker, anchored just over the miner's head. The
		# native viewport IS the HUD canvas (640×360), so the canvas transform maps world → HUD space.
		if _hints != null:
			_hud.hint_text = _hints.active_text()
			_hud.hint_alpha = _hints.active_alpha()
			if _player != null:
				# canvas transform maps world → RENDER-viewport (1280×720); the HUD draws in Hud.CANVAS
				# (640×360) scaled by HUD_SCALE, so bring the mapped point back into HUD-draw space.
				_hud.hint_anchor = (get_viewport().get_canvas_transform() \
					* (_player.position + Vector2(0.0, -Player.HEIGHT * 0.5 - 6.0))) / HUD_SCALE


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
	_payouts.advance(delta)
	# THE LINE'S VOICE (#S4). A piton biting rock is a hard, close, percussive event and it wants to be
	# felt: chips off the anchor, a crack, and a small kick of shake so the plant lands in the hands. The
	# release is the opposite — a soft whip of nothing. Both are one-shot flags the body raises inside its
	# substep, so they fire exactly once per event no matter how the frame was subdivided.
	if _player != null:
		var g: Grapple = _player.grapple
		if g.just_planted:
			_particles.spark(g.anchor, Color(0.90, 0.84, 0.66))
			_sfx.play(&"crunch", g.anchor, 1.6, -4.0)
			_shake = maxf(_shake, 1.6)
		elif g.just_cut:
			_sfx.play(&"pop", _player.position, 1.7, -12.0)
	# Sonar pacing + the staggered returns: each scheduled ding fires when the wavefront (whose speed
	# the renderer owns) actually reaches its vein — you HEAR the distance.
	_scan_cooldown = maxf(0.0, _scan_cooldown - delta)
	for i: int in range(_scan_dings.size() - 1, -1, -1):
		var d: Dictionary = _scan_dings[i]
		d["at"] = float(d["at"]) - delta
		if float(d["at"]) <= 0.0:
			_sfx.play(&"ding", d["pos"], 1.7, -10.0)
			_scan_dings.remove_at(i)
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
		# AMBIENCE BEDS (audio slice 2): where the body IS, heard. Wind above ground, dying within a
		# few rows of descent; cave-air (+ intermittent drips) swelling to full ~10 rows under the
		# surface of your column. Crossfaded inside Sfx, so climbing a shaft trades earth for sky.
		var below: float = float(_body_cell().y - sim.surface_row(_body_cell().x))
		_sfx.set_ambience(clampf(1.0 - below / 4.0, 0.0, 1.0), clampf(below / 10.0, 0.0, 1.0),
			_player.position, delta)
		# WATER AUDIO (L3): a soft POUR bed that swells with how much falling/pouring water is near you
		# (a waterfall you hear when close), and a wet PUMP drain while a pump near you is draining —
		# both level-driven like the heartbeat, smoothed + fading to silence inside Sfx.set_water. Reads
		# the same "pouring" rule the renderer's water drips use (cell below is open, not-full, not rock),
		# so what you SEE pour is what you HEAR. Bounded: only cells within near_sq are examined.
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
		# THE BREACH stinger: a Descent Engine reaching quota bores the seal open — a once-per-world
		# event that deserves a sound the size of the moment. Edge-latched per engine; _prime_breach
		# marks engines that were ALREADY breached (fresh seed / loaded save), so only a breach that
		# happens on your watch booms.
		for m: MachineState in sim.machines:
			if m.def.behavior == &"descent" and m.fed >= FactorySim.DESCENT_QUOTA \
					and not _breach_heard.has(m.cell):
				_breach_heard[m.cell] = true
				_sfx.play(&"boom", _cell_center(m.cell), 1.0, 8.0)
				_shake = maxf(_shake, 7.0)
	if _player != null:
		var feet: Vector2 = _player.position + Vector2(0.0, Player.HEIGHT * 0.5)
		if _player.landed_hard:
			# Landing juice SCALES with impact (#43): a step-off puffs, a terminal drop thuds + kicks.
			var imp: float = clampf((_player.last_impact - 240.0) / (Player.MAX_FALL - 240.0), 0.0, 1.0)
			_particles.dust(feet, Color(0.42, 0.32, 0.22), 6 + int(imp * 14.0))
			_shake = maxf(_shake, 1.8 + imp * 3.4)
			_sfx.play(&"thump", feet, 0.6 + imp * 0.5, -5.0)
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
		_camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)) \
			if _shake > 0.05 and Settings.screen_shake else Vector2.ZERO


## Terraria/Minecraft-convention controls, all via REMAPPABLE InputMap actions (see Controls): 1–8
## SELECT hotbar slots (not craft), E opens the crafting SCREEN (where the numbers craft), the wheel
## cycles the hotbar, Q drops the selected stack (gravity feeds it in), M map, H help. Feeding is DROP,
## not deposit — so E is free for the crafting screen. The numeric row stays a direct keycode (a fixed
## convention); every other binding routes through Controls so a settings page can rebind it.
func _unhandled_input(event: InputEvent) -> void:
	# THE TITLE eats all input while open (#6): TAB rerolls the seed, ←/→ picks the lamp, ENTER/SPACE
	# descends, C continues the save. Everything else waits behind the veil.
	if _title_open:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_TAB:
					_title_seed = randi() % 1000000
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_confirm_title()
				KEY_C:
					_dismiss_title()   # continue = the save brings its OWN world; seed rerolls are moot
					_load_game()
			if event.keycode == KEY_LEFT or event.keycode == KEY_A:
				_title_tint = (_title_tint + LAMP_TINTS.size() - 1) % LAMP_TINTS.size()
			elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
				_title_tint = (_title_tint + 1) % LAMP_TINTS.size()
		return
	# THE SETTINGS overlay (#36) eats all input while open — sliders, chips, and the key-capture flow.
	if _settings_open:
		_settings_input(event)
		return
	if event.is_action_pressed(Controls.PAUSE):
		_paused = not _paused
	elif event.is_action_pressed(Controls.CRAFT):
		_inventory_open = not _inventory_open
		if _inventory_open: _hud.scroll_craft(-9999)   # open at the top of the craft list (#75)
	elif event.is_action_pressed(Controls.DROP):
		try_drop()
	elif event.is_action_pressed(Controls.MAP):
		_minimap_mode = (_minimap_mode + 1) % 3          # hidden → corner → LARGE → hidden
	elif event.is_action_pressed(Controls.HELP):
		_show_help = not _show_help
	elif event.is_action_pressed(Controls.TECH):
		_show_tech = not _show_tech
	elif event.is_action_pressed(Controls.DASHBOARD):
		_show_dashboard = not _show_dashboard
	elif event.is_action_pressed(Controls.CLOSE):
		# ESC closes whatever's open; with a CALM screen it opens SETTINGS (the pause-menu convention).
		if _inventory_open or _show_help or _show_tech or _show_dashboard or _minimap_mode != 0:
			_inventory_open = false
			_show_help = false
			_show_tech = false
			_show_dashboard = false
			_minimap_mode = 0
		else:
			_settings_open = true
	elif event.is_action_pressed(Controls.RESEARCH) and (_inventory_open or _show_tech):
		try_research(ResearchRules.next_tech(sim.research))   # R at the bench/tree: research the next tech
	elif event.is_action_pressed(Controls.RESEARCH) and not _inventory_open:
		try_configure(_aim)                                   # R in the world: configure the aimed machine
	elif event.is_action_pressed(Controls.BUILD):
		if not _cursor_on_minimap() and not _cursor_on_hover_panel():   # UI panels eat the click
			if _selected_item() == &"scanner":
				try_scan()                                    # the selected item defines RMB: sonar, not build
			else:
				try_build(_aim)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and _cursor_on_alerts():
		_ping_alert(get_viewport().get_mouse_position())      # click an alert → mark the culprit
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and _cursor_on_minimap():
		_toggle_ping(get_viewport().get_mouse_position())     # click the map → set/clear the ping
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and _cursor_on_hover_panel():
		_apply_knob(_hud.hover_click(get_viewport().get_mouse_position()))   # config-panel chips (#32)
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
		if _inventory_open: _hud.scroll_craft(1)   # in the PACK: the wheel scrolls the craft list (#75)
		else: _cycle_inventory(1)                  # otherwise: the hotbar scroll select
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		if _inventory_open: _hud.scroll_craft(-1)
		else: _cycle_inventory(-1)
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


## Input while THE SETTINGS overlay is open (#36). Two modes: normally clicks land on the page's
## controls (via Hud.settings_click payloads — the knob pattern); while CAPTURING, the very next key
## or mouse button becomes the chosen action's new binding (ESC cancels). The HUD never touches
## InputMap or the config file — every mutation goes through Settings here in the controller.
func _settings_input(event: InputEvent) -> void:
	if _capture_action != &"":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_capture_action = &""                    # cancel — keep the old binding
			else:
				var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				Settings.rebind(_capture_action, {"key": code})
				_capture_action = &""
		elif event is InputEventMouseButton and event.pressed:
			Settings.rebind(_capture_action, {"button": event.button_index})
			_capture_action = &""
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_settings_open = false
		_settings_drag = ""
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_apply_setting(_hud.settings_click(get_viewport().get_mouse_position()))
		else:
			_settings_drag = ""                          # slider drag ends with the button
	elif event is InputEventMouseMotion and _settings_drag != "":
		_set_volume(_settings_drag,
			_hud.settings_slider_frac(_settings_drag, get_viewport().get_mouse_position().x))


func _apply_setting(payload: Dictionary) -> void:
	if payload.has("slider"):
		_settings_drag = str(payload["slider"])          # press starts a drag; motion keeps updating it
		_set_volume(_settings_drag, float(payload.get("frac", 0.0)))
	elif payload.get("toggle", "") == "shake":
		Settings.screen_shake = not Settings.screen_shake
		Settings.save_settings()
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


func _set_volume(id: String, frac: float) -> void:
	match id:
		"master": Settings.master = clampf(frac, 0.0, 1.0)
		"sound": Settings.sound = clampf(frac, 0.0, 1.0)
		"ambience": Settings.ambience = clampf(frac, 0.0, 1.0)
	Settings.apply_audio()
	Settings.save_settings()


## THE GRAPPLE (F / middle-mouse). One key, two verbs: a live line is cut, a stowed one is fired at
## wherever the cursor is. It shoots at the raw mouse point rather than at `_aim` on purpose — `_aim`
## snaps to mineable faces within the pick's 3.2-cell reach, which is exactly the wrong behaviour for a
## tool whose whole job is to reach the far wall you CAN'T touch.
func _toggle_grapple() -> void:
	if _paused or _settings_open or _inventory_open:
		return
	var g: Grapple = _player.grapple
	if g.live():
		g.cut()
		_sfx.play(&"pop", _player.position, 1.5, -8.0)
		return
	g.fire(_player.hand(), get_global_mouse_position())
	_sfx.play(&"clunk", _player.position, 1.9, -10.0)


# --- world-interaction tools (mining / depositing): discrete sim edits only ---

## Timed mining: holding LMB CHARGES the aimed block (time scaled by your best tool vs the rock's
## hardness). The block only breaks when the charge fills, so early hand-mining is a
## deliberate grind (the friction that sells automation). The charge fraction drives the crack overlay.
## (The wall-clock timing lives HERE; the tool-GATE lives in try_mine, the verb the play-harness drives.)
func _update_mining(delta: float) -> void:
	var mouse_world: Vector2 = get_global_mouse_position()
	_aim = _effective_aim(mouse_world)
	# Open UI (minimap / config panel) eats the cursor: LMB there clicks, never swings the pick.
	var pressed: bool = not _paused and not _settings_open and Input.is_action_pressed(Controls.MINE) \
		and not _cursor_on_minimap() and not _cursor_on_hover_panel() and not _cursor_on_alerts()
	if pressed:
		_paint_dig_marks(mouse_world)        # dragging LMB sketches the plan (even beyond reach)
	else:
		_last_paint_world = Vector2.INF
	# The charge/crack animation runs ONLY on a cell you can actually break — the SAME _mineable predicate
	# try_mine enforces (solid + in reach + LINE OF SIGHT). Without the LOS term the cracks would spider a
	# full charge, try_mine would refuse (no clear path), and it'd loop forever — reading as a bug. If the
	# aim is a block behind rock, _effective_aim already snaps to the nearest EXPOSED face toward the cursor,
	# so you dig the PATH toward a buried target; when no reachable face exists, nothing animates (no phantom).
	# THE QUEUE FALLBACK (#24): when the cursor itself offers no workable block, the nearest MARKED cell in
	# reach becomes the work target — the precise hover always wins, the plan drains whenever the hand is free.
	var work: Vector2i = _aim
	if pressed and not _workable(work):
		work = _nearest_marked_workable()
	var holding: bool = pressed and _workable(work)
	_heal_cracks(delta, work if holding else Vector2i(-999, -999))
	if not holding:
		_mine_target = Vector2i(-999, -999)
		_mine_charge = 0.0
		_swing_clock = SWING_PERIOD          # primed: the FIRST blow of the next charge lands instantly
		if _renderer != null:
			_renderer.set_mine_progress(Vector2i(-999, -999), 0.0)
		# Tool-locked hover keeps its "no progress" read (the hint says why).
		if pressed and _mineable(_aim) and not MiningRules.can_mine(sim.material_at(_aim), sim.inventory):
			_mine_target = _aim
			_renderer.set_mine_progress(_aim, 0.0)
		return
	var mat: StringName = sim.material_at(work)
	if work != _mine_target:                 # moved to a fresh block → RESUME whatever it already owes us
		_mine_target = work
		_mine_charge = _banked_charge(work)
	var cls: StringName = MiningRules.required_tool(mat)
	var speed: float = MiningRules.best_speed(cls, sim.inventory) if cls != &"" else 1.0
	_mine_charge += delta * speed
	var hard: float = MiningRules.hardness(mat)
	_cracks[work] = Vector2(_mine_charge, 0.0)                # bank it: this cell stays cracked if we look away
	_renderer.set_mine_progress(work, clampf(_mine_charge / hard, 0.0, 1.0))
	# Swing FEEL: while charging, the body holds the dig pose facing the block, and on a
	# steady cadence a BLOW lands — a chip of the rock's dust off the struck face + a micro-shake — so
	# mining reads as pick-strikes landing, not a progress bar silently filling.
	if _player != null:
		_player.note_dig(int(signf(_cell_center(work).x - _player.position.x)))
		_swing_clock += delta
		if _swing_clock >= SWING_PERIOD:
			_swing_clock = 0.0
			var center: Vector2 = _cell_center(work)
			var to_body: Vector2 = _player.position - center
			_particles.chip(center + to_body.normalized() * (float(CELL) * 0.45),
				Visuals.terrain_dust(mat), to_body.angle())
			_shake = maxf(_shake, 0.7)
			# Harder rock strikes a deeper note (hardness 1..4 → pitch ~1.15..0.85).
			_sfx.play(&"crunch", center, clampf(1.25 - hard * 0.1, 0.8, 1.2))
	if _mine_charge >= hard:
		_mine_charge = 0.0
		_cracks.erase(work)                                  # broken: nothing left to remember
		try_mine(work)                                       # charge full → land the breaking blow


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


## A cell the miner can WORK right now: breakable (solid + reach + LOS, the try_mine gate) AND the
## carried tools are up to its rock. The single predicate both the hover target and the queue use.
func _workable(cell: Vector2i) -> bool:
	return _mineable(cell) and MiningRules.can_mine(sim.material_at(cell), sim.inventory)


## Sweep-paint the dig plan: every solid cell the cursor crossed since last frame gets a mark (the
## segment is sampled sub-cell so a fast drag doesn't skip blocks). Marks are allowed BEYOND reach —
## the plan is where you intend to dig, reach gates the work, not the sketch. Tool-locked rock refuses
## a mark (a plan you can't execute yet just reads as a bug later).
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
			continue                          # out of reach / no LOS / tool-locked — stays in the plan
		var d: float = _cell_center(cell).distance_squared_to(_player.position)
		if d < best_d:
			best_d = d
			best = cell
	return best


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
	var before: Dictionary = sim.inventory.duplicate()         # …so the payout tick can name the real yield
	var mined: StringName = sim.mine(cell)
	if mined != &"":
		_dig_marks.erase(cell)                                 # a dug cell's mark is spent
		var center: Vector2 = _cell_center(cell)
		_show_gains(before, center + Vector2(0.0, -float(CELL) * 0.35))
		_renderer.note_mined(cell, mat)                        # the block shatters away, not pops (#18)
		_particles.dust(center, Visuals.terrain_dust(mat), 10)  # settling break-dust puff
		if _player != null:
			# The breaking blow's payoff: chunky debris kicked out of the shattered face
			# toward the digger, a heavier kick than a mid-charge chip — and a vein pays out a bright
			# fleck-spray in its own colour, so breaking ore FEELS richer than breaking dirt.
			_particles.debris(center, Visuals.terrain_dust(mat).lightened(0.12),
				(_player.position - center).angle())
			_player.note_dig(int(signf(center.x - _player.position.x)))
		# THE BREAK POPS (#A6). Every break throws a spray in the material's OWN item colour, not just a
		# rich one — the block visibly becomes the thing you now carry, which is the moment the payout
		# tick then names. A rich vein still out-sparkles a plain one; it just isn't the only break that
		# reads as an event.
		_particles.spark(center, Visuals.item_color(mat).lightened(0.35 if rich else 0.15))
		_shake = maxf(_shake, 2.6 if rich else 2.0)
		_sfx.play(&"thump", center, 1.1 if rich else 1.0, 2.0 if rich else 0.0)
	return mined != &""


## Float a "+N" tick at `at` for every pack entry that GREW since `before` — the payoff shown at the
## point of impact instead of only as a number in the HUD corner (#B2). Diffing the pack rather than
## reading the verb's return value means the tick always names what you actually got: an ore burst is
## the 3-6 it really paid, a leaf that hid a sapling says sapling, and new yields need no wiring.
func _show_gains(before: Dictionary, at: Vector2) -> void:
	for item: StringName in sim.inventory:
		var delta: int = int(sim.inventory[item]) - int(before.get(item, 0))
		if delta > 0:
			_payouts.gain(at, item, delta)


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


## Configure the aimed machine (R outside the pack screen): cycle a splitter's ratio,
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
## (the crafting hub). Refused away from it, so machine-crafting pulls you to the stall.
func try_craft(def: MachineDef) -> bool:
	if not _near_bazaar():
		return false
	var made: bool = sim.craft(def)
	if made:
		_sfx.ui(&"ding")
	return made


## Fire the SONAR: a pulse expands from the body; every still-solid deposit in range
## answers with an echo ring through the rock (the renderer draws it) and a distance-staggered return
## chirp — literal sonar. Requires carrying a Scanner; a short cooldown paces it. Pure QUERY: reads
## deposits, mutates nothing — the whole feature adds ZERO sim state.
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
			echoes.append({"cell": cell, "pos": pos, "dist": dist, "material": sim.material_at(cell)})
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


## Craft a TOOL (e.g. the Stone Pickaxe) from carried materials — same Bazaar gate + same generic sink as
## machine crafting (sim.craft_item). The pickaxe-tier upgrade path: craft it here, and it
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
## No-auto-pickup GRACE (playtest fix — a just-dropped item was instantly sucked back up): cell → seconds
## remaining. Set on Q-drop for the landing cell, aged each frame; a graced cell is skipped by auto-collect.
const DROP_GRACE_S: float = 1.3
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


func _collect_ground_under_player() -> void:
	if _player == null or sim.ground.is_empty() or not Settings.auto_pickup:
		return
	var reach_sq: float = pow(COLLECT_REACH_CELLS * float(CELL), 2.0)
	for cell: Variant in sim.ground.keys():                          # keys() copies — safe to collect mid-iter
		var c: Vector2i = cell
		if _no_pickup.has(c):                                        # just dropped here — leave it a moment
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


## Snap a world position so it lands on a whole SCREEN pixel at the given zoom — the pixel-art camera
## fix (playtest: "texture blurs while running"). A fractional camera offset makes every terrain texel
## sample between screen pixels each frame → shimmer/blur in motion. Rounding the camera to the
## screen-pixel grid removes the sub-pixel jitter while the smoothing keeps the follow soft. Static +
## pure so the harness (check_pixel_snap) can assert the grid alignment without a live scene.
static func snap_to_pixel(world_pos: Vector2, zoom: float) -> Vector2:
	if zoom <= 0.0:
		return world_pos
	return (world_pos * zoom).round() / zoom


## The active camera zoom level (Z cycles the index). Read everywhere the view-size matters.
func _current_zoom() -> float:
	return ZOOM_LEVELS[_zoom_idx]


## Cycle to the next zoom level (Z) and apply it to the camera — Terraria-style zoom-out/in.
## The pick persists as a setting (real boots restore it; save is a no-op on scripted boots).
func _cycle_zoom() -> void:
	_zoom_idx = (_zoom_idx + 1) % ZOOM_LEVELS.size()
	if _camera != null:
		_camera.zoom = Vector2(_current_zoom(), _current_zoom())
	Settings.zoom_idx = _zoom_idx
	Settings.save_settings()


## Cycle the fast-forward game clock (".") and apply it. Engine.time_scale scales BOTH the sim's
## tick accumulator (the factory runs faster) and the body's physics (which substeps, so no tunnel).
func _cycle_speed() -> void:
	_time_scale_idx = (_time_scale_idx + 1) % TIME_SCALES.size()
	Engine.time_scale = TIME_SCALES[_time_scale_idx]


## F5 quicksave: the sim capture + the body's position, one versioned file.
func _save_game() -> void:
	var data: Dictionary = SaveGame.capture(sim)
	data["player_pos"] = _player.position
	data["lamp_tint"] = MainView.boot_tint          # representation keys ride beside the sim envelope
	data["world_seed"] = _world_seed
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
	MainView.boot_tint = clampi(int(data.get("lamp_tint", MainView.boot_tint)), 0, LAMP_TINTS.size() - 1)
	_renderer.lamp_color = LAMP_TINTS[MainView.boot_tint]["color"]
	_renderer.repaint_world()
	_prime_breach_watch()   # a breach that happened before this save doesn't boom retroactively
	if _hints != null:
		_hints.resync()     # whatever the save already carries is old news, not a fresh acquisition
	_hud.flash("LOADED")


## Mark every ALREADY-breached descent engine as heard, so the breach stinger fires only for a breach
## that happens on the player's watch (fresh session start + after every load).
func _prime_breach_watch() -> void:
	_breach_heard.clear()
	for m: MachineState in sim.machines:
		if m.def.behavior == &"descent" and m.fed >= FactorySim.DESCENT_QUOTA:
			_breach_heard[m.cell] = true


## Is the cursor over the OPEN minimap? While it is, the map owns the mouse: LMB pings it and no world
## verb (mine/build) fires underneath — the "clicks on visible UI don't hit the world" rule.
func _cursor_on_minimap() -> bool:
	return _minimap_mode > 0 and _hud != null \
		and _hud.minimap_frame().grow(3.0).has_point(get_viewport().get_mouse_position())


## Is the cursor over the machine inspector/config panel? While it is, LMB hits panel knobs and the
## world verbs stay holstered (the same "UI eats the click" rule as the open minimap).
func _cursor_on_hover_panel() -> bool:
	if _hud == null:
		return false
	var r: Rect2 = _hud.hover_panel_rect()
	return r.size.x > 0.0 and r.has_point(get_viewport().get_mouse_position())


## Turn a clicked config-panel chip (#32) into the discrete sim call it stands for. The HUD only
## reports WHAT was clicked; every mutation happens here, through the sim's public surface.
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
## holstered (same "UI eats the click" rule as the open minimap / config panel).
func _cursor_on_alerts() -> bool:
	return _hud != null and _hud.cursor_on_alerts(get_viewport().get_mouse_position())


## Click an alert (#29) → drop the PING on the stalled machine so its in-world beacon + map dot lead you
## there (the camera is body-locked, so this is the honest "take me to it"). MainView owns the ping.
func _ping_alert(canvas_pos: Vector2) -> void:
	var payload: Dictionary = _hud.alert_click(canvas_pos)
	if payload.is_empty():
		return
	_ping_world = _cell_center(payload["cell"]).clamp(Vector2.ZERO, WORLD_SIZE)
	_renderer.set_ping(_ping_world)
	_hud.flash("marked — follow the beacon")


## Set/clear the PING from a click on the map (canvas coords → world). Clicking on (or next to) the
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
	# THE TOSS FINDS THE MOUTH (#B2). Gravity is still the conveyor, but the first ore→ingot handoff was
	# fiddly out of all proportion to its importance: stand a cell off, or face the wrong way, and the
	# stack lands at your feet, gets auto-scooped a moment later, and you try the whole dance again. So
	# when a machine in reach genuinely EATS what you're holding, the toss goes in — you aimed at the
	# forge, you meant the forge. Everything else keeps the old arc: over a ledge, down a shaft, onto the
	# floor. This only ever redirects a throw that a machine wanted anyway.
	var mouth: MachineState = _reachable_eater(item)
	if mouth != null:
		var fed: int = sim.deposit(mouth.cell, item, carried)
		if fed > 0:
			_particles.pop(_cell_center(mouth.cell), Visuals.item_color(item))
			_sfx.play(&"pop", _cell_center(mouth.cell), 1.2)
			return true
	var face: Vector2i = here + Vector2i(_player.facing, 0)
	# Toss forward into the facing column when it's clear (open air or a machine to feed); a solid wall
	# blocks the toss, so drop straight down instead. Landing is sim-truth; `here` is the launch origin.
	var target: Vector2i = face if (sim.in_bounds(face) and not sim.is_solid(face)) else here
	var dropped: int = sim.drop_item(target, item, carried, here)
	if dropped > 0:
		_no_pickup[sim.last_drop_landing] = DROP_GRACE_S   # don't instantly suck it back up (playtest fix)
		_particles.pop(_cell_center(target), Visuals.item_color(item))
	return dropped > 0


## The nearest machine in reach that would actually consume `item`, or null. Ties break by distance so
## a wall of machines feeds the one you're standing at, not the one that happens to be first in the list.
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
		if sim.retract_rope(cell) > 0:   # RMB any segment → the WHOLE rope returns (retract-all, #39)
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
	# PLANT a carried sapling on soil (#38 — the renewable-wood verb). Selected sapling + open ground.
	if _selected_item() == &"sapling":
		var rooted: bool = sim.plant_sapling(cell)
		if rooted:
			_particles.dust(_cell_center(cell) + Vector2(0.0, 8.0), Color(0.35, 0.55, 0.25), 5)
			_sfx.play(&"pop", _cell_center(cell), 1.3)
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
			_renderer.note_machine_built(cell)   # play the one-shot assemble overlay (#9)
			_particles.spark(_cell_center(cell), Visuals.machine_color(def).lightened(0.3))
			_shake = maxf(_shake, 2.2)
			_sfx.play(&"clunk", _cell_center(cell))
		return placed != null
	# Block placement (the Terraria build primitive): the selected hotbar item is a building material.
	var mat: StringName = _selected_build_material()
	if mat != &"" and _placeable(cell) and sim.block_supported(cell) and sim.place_block(cell, mat):
		_particles.dust(_cell_center(cell), Visuals.terrain_dust(mat), 6)
		_sfx.play(&"crunch", _cell_center(cell), 0.75)
		return true
	return false


## Inspector data for the machine under the cursor (if you aim at one of your machines within reach):
## its name, recipe (inputs → outputs as item lists), routing mode, and what it currently holds. The
## HUD renders it. Pure read of the sim — the legibility answer to "where does this eat / spit / make".
## The world-cell READOUT for the HUD info panel — built in scenes/hover_info.gd. MainView supplies the
## two bits of controller context the readout can't compute itself: whether the cell is in REACH (the
## same reach-gate the verbs use) and the current DRILL rate (from the machine-def table).
const HoverInfo := preload("res://scenes/hover_info.gd")


func _hover_info() -> Dictionary:
	return _hover_info_at(_aim)


## The same read for an explicit cell — the config panel PIN (#32) re-reads the latched machine while
## the cursor is off exploring the panel's own knobs.
func _hover_info_at(aim: Vector2i) -> Dictionary:
	return HoverInfo.describe(sim, aim, _can_reach(aim), _drill_rate())


## The item id in the active hotbar slot, or &"" when the pack is empty.
func _selected_item() -> StringName:
	var slots: Array[Dictionary] = sim.inventory_slots()
	if slots.is_empty():
		return &""
	return slots[clampi(_inv_selected, 0, slots.size() - 1)]["item"]


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


## Placeable for the CURRENT selection: a machine only needs an open cell (_placeable), but a building
## BLOCK also needs support — no plopping rock in mid-air (the playtest fix). Drives both the ghost colour
## and the place gate so they never disagree.
func _placeable_here(cell: Vector2i) -> bool:
	if not _placeable(cell):
		return false
	if _selected_machine_def() == null and _selected_build_material() != &"":
		return sim.block_supported(cell)
	return true


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
## crafting hub gate: away from it, the E screen shows the pack but no recipes.
func _near_bazaar() -> bool:
	return _player != null and sim.near_bazaar(_cell_at(_player.position), BAZAAR_RADIUS)


## The nominal extraction RATE of a Drill in ore/second (1 unit per recipe cycle). Read off the drill def
## so it tracks the recipe, not a magic number — the throughput the hover inspector surfaces.
func _drill_rate() -> float:
	var drill: MachineDef = _machine_defs_by_id.get(&"drill", null)
	if drill == null or drill.recipe == null or drill.recipe.time <= 0.0:
		return 0.0
	return 1.0 / drill.recipe.time


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
