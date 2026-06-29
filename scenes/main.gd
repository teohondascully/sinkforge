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
const MINE_TIME: float = 0.12      ## seconds between mined cells while holding
const WORLD_SIZE := Vector2(FactorySim.GRID_COLS * CELL, FactorySim.GRID_ROWS * CELL)
## Zoom levels cycled by Z (Terraria-style). Default is zoomed OUT so you see the world you're working in,
## not just your feet. Smaller = further out. _current_zoom() reads the active level everywhere.
const ZOOM_LEVELS: Array[float] = [0.42, 0.6, 0.85]
var _zoom_idx: int = 0
const WORLD_SEED: int = 1337       ## fixed gen seed (provisional; expose to a new-game UI later)
## Materials the player can PLACE as blocks from the pack (the Terraria build primitive). Wood = the
## bazaar build material; the list grows as more buildables land (log/stone/etc).
const BUILD_MATERIALS: Array[StringName] = [&"wood"]
## Dev: start with a stocked pack (ore/ingots/machines) for testing. A static so the headless harness
## can force a CLEAN start (it asserts exact counts) by setting MainView.dev_start = false before boot.
static var dev_start: bool = true

var sim: FactorySim
var _player: Player
var _camera: Camera2D
var _renderer: WorldRenderer       ## the VIEW: all world-space drawing + lighting (we push it aim state)
var _hud: Hud                      ## screen-space HUD (we push it objectives + the machine inspector)
var _paused: bool = false
## On-demand UI state (the calm-screen model): the crafting screen (E), the map (M), and the controls
## help (H/?) are summoned, not permanent. Pushed to the HUD each frame so it knows what to draw.
var _crafting_open: bool = false
var _show_minimap: bool = false
var _show_help: bool = false
var _mine_cooldown: float = 0.0
var _aim: Vector2i = Vector2i(-99, -99)
## The machines you can CRAFT (1/2 keys → craft one into the pack, spending ingots). The ore_vent (a
## SOURCE) is deliberately absent — you remain the ore source by hand (manual→automated pillar; see
## DECISIONS 2026-06-27). `_machine_defs_by_id` resolves a carried hotbar item back to its def so a
## selected machine item can be placed.
var _craftable: Array[MachineDef] = []
var _machine_defs_by_id: Dictionary = {}
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
## The tutorial chain (representation-layer legibility — the "how do I play?" signpost). Reads the sim.
var _objectives: Objectives
## GPU ambient dust motes (docs/MODERN_FEEL.md) — a continuous GPUParticles2D haze that drifts in the
## air and catches the lamp light. Pure atmosphere; follows the camera each frame.
var _motes: GPUParticles2D


func _ready() -> void:
	Controls.register()    # register the remappable InputMap actions (foundation for a settings page)
	sim = FactorySim.new()
	_craftable = [
		load("res://src/data/machines/processor.tres"),
		load("res://src/data/machines/splitter.tres"),
		load("res://src/data/machines/lift.tres"),
		load("res://src/data/machines/drill.tres"),  # automates ore extraction (docs/MINING.md)
		load("res://src/data/machines/generator.tres"),  # burns coal → power (docs/POWER.md)
		load("res://src/data/machines/conduit.tres"),     # carries power down+lateral (docs/POWER.md)
	]
	for def: MachineDef in _craftable:
		_machine_defs_by_id[def.id] = def
	_seed_world()

	_player = Player.new()
	_player.sim = sim
	_player.position = _cell_center(Vector2i(3, 3))  # on the surface, near the forge
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
	var machine_icons: Dictionary = {}
	for def: MachineDef in _craftable:
		craft_opts.append({"name": def.display_name, "cost": def.craft_cost})
		machine_icons[def.id] = {"color": Visuals.machine_color(def), "kind": Visuals.machine_kind(def), "name": def.display_name}
	hud.craft_options = craft_opts
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
const MINESHAFT_COL: int = 8
const MINESHAFT_FORGE_CELL := Vector2i(8, 5)   ## the forge in the shaft mouth — hand-fed, then drill-fed
const MINESHAFT_DRILL_CELL := Vector2i(8, 4)   ## where the player caps it with the Drill (directly above)
func _seed_world() -> void:
	var gen: WorldGen = LayeredWorldGen.new()
	var world: WorldData = gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, WORLD_SEED)
	sim.load_world(world)
	_seed_starter_vein()
	_seed_tutorial_mineshaft()
	if dev_start:
		_dev_seed_pack()


## A rich ORE cell breaching the surface right beside spawn — the visible "orange-flecked rock" the first
## objective points at, and the bootstrap ore for the hand-smelted ingots (depth-banded worldgen leaves
## the shallow surface near-bare, so onboarding can't rely on finding a vein). ONE deep cell, not a
## vertical run: mining it leaves only a 1-tile pit you step straight back out of, instead of a deep hole
## you'd have to jump from. Distinct from the mineshaft's drill-vein so hand-mining never eats it.
const STARTER_VEIN_CELL := Vector2i(4, 5)
func _seed_starter_vein() -> void:
	sim.set_solid(STARTER_VEIN_CELL, &"ore")
	sim.deposits[STARTER_VEIN_CELL] = 6                            # ~3 ingots' worth — bootstrap + margin


## An ABANDONED MINESHAFT near spawn with a FORGE already in its mouth — the whole Rung-1 stage in one
## shallow fixture. Layout (col 8), daylight pouring down the carved shaft (walls kept):
##   row 5  FORGE      (placed) — you hand-feed it by tossing ore down the shaft, later the drill feeds it
##   row 6  open gap   — smelted ingots land here on the vein below; you drop in (1 tile) to scoop them
##   row 7  ORE vein   (rich) — the drill's target once you cap the forge
##   row 8  rock floor
## The drill goes ABOVE the forge at (8,4), floating one cell over the surface. The shaft is only 1 tile
## deep where you stand to collect, so you step straight back out — no trap. Sinking this exact shaft by
## hand is fragile (you'd mine the vein you mean to drill), so the world provides it; digging agency
## lives in the starter vein (step 1) and everywhere else.
func _seed_tutorial_mineshaft() -> void:
	var c: int = MINESHAFT_COL
	sim.set_solid(Vector2i(c, 5), &"")                             # shaft mouth (forge goes here)
	sim.set_solid(Vector2i(c, 6), &"")                             # collect gap (ingots land on the vein)
	sim.set_solid(Vector2i(c, 7), &"ore")                         # the vein (drill's target)
	sim.deposits[Vector2i(c, 7)] = 12                            # rich — runs the loop, then exhausts (finite)
	sim.set_solid(Vector2i(c, 8), &"earth")                      # floor under the vein
	sim.place_machine(load("res://src/data/machines/processor.tres"), MINESHAFT_FORGE_CELL)


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
		_hud.crafting_open = _crafting_open
		_hud.show_minimap = _show_minimap
		_hud.show_help = _show_help
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


## Drive the cosmetic juice: advance particles, kick dust on a hard landing + periodic footsteps, and
## decay the screenshake into the camera offset. None of this touches the sim.
func _update_juice(delta: float) -> void:
	_particles.advance(delta)
	if _player != null:
		var feet: Vector2 = _player.position + Vector2(0.0, Player.HEIGHT * 0.5)
		if _player.landed_hard:
			_particles.dust(feet, Color(0.42, 0.32, 0.22), 12)
			_shake = maxf(_shake, 3.2)
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
		_crafting_open = not _crafting_open
	elif event.is_action_pressed(Controls.DROP):
		try_drop()
	elif event.is_action_pressed(Controls.MAP):
		_show_minimap = not _show_minimap
	elif event.is_action_pressed(Controls.HELP):
		_show_help = not _show_help
	elif event.is_action_pressed(Controls.CLOSE):
		_crafting_open = false
		_show_help = false
	elif event.is_action_pressed(Controls.BUILD):
		try_build(_aim)
	elif event.is_action_pressed(Controls.ZOOM):
		_cycle_zoom()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_cycle_inventory(1)   # direct wheel handling (reliable) — the hotbar scroll select
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_cycle_inventory(-1)
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		var idx: int = event.keycode - KEY_1            # the fixed hotbar number row
		if _crafting_open:
			if idx < _craftable.size():
				try_craft(_craftable[idx])              # in the crafting screen, numbers CRAFT
		else:
			_select_slot(idx)                           # otherwise they SELECT the hotbar slot


# --- world-interaction tools (mining / depositing): discrete sim edits only ---

func _update_mining(delta: float) -> void:
	_mine_cooldown = maxf(0.0, _mine_cooldown - delta)
	_aim = _effective_aim(get_global_mouse_position())
	if _paused:
		return
	if Input.is_action_pressed(Controls.MINE) and _mine_cooldown <= 0.0 \
			and try_mine(_aim):
		_mine_cooldown = MINE_TIME


## Terraria-style mining reach: you don't have to land the cursor exactly on a reachable cell. When you
## point at a BLOCK that's out of reach, the aim snaps to the closest reachable block toward your cursor
## (and the highlight follows, so you see what you'll hit). Precise in-reach hovering is unchanged, and
## while BUILDING (a machine/material selected) the aim stays exact — placement wants the cell you point at.
func _effective_aim(mouse_world: Vector2) -> Vector2i:
	var raw: Vector2i = _cell_at(mouse_world)
	var building: bool = _selected_machine_def() != null or _selected_build_material() != &""
	if building or _can_reach(raw):
		return raw
	return _nearest_reachable_solid(mouse_world, raw)


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
			if not sim.is_solid(c) or not _can_reach(c):
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
	if _paused or not _can_reach(cell) or not sim.is_solid(cell):
		return false
	var mat: StringName = sim.material_at(cell)
	var mined: StringName = sim.mine(cell)
	if mined != &"":
		_particles.dust(_cell_center(cell), Visuals.terrain_dust(mat), 10)  # break-debris puff
		_shake = maxf(_shake, 1.4)
		if _player != null:                                    # Phase-C dig anim: latch the pose, face the cell
			_player.note_dig(int(signf(_cell_center(cell).x - _player.position.x)))
	return mined != &""


## Hand the SELECTED carried item into the nearest machine within reach (the manual half of the arc).
func try_deposit() -> bool:
	var slots: Array[Dictionary] = sim.inventory_slots()
	if slots.is_empty():
		return false
	var sel: int = clampi(_inv_selected, 0, slots.size() - 1)
	var item: StringName = slots[sel]["item"]
	var carried: int = int(slots[sel]["count"])
	if carried <= 0:
		return false
	for machine: MachineState in sim.machines:
		if _can_reach(machine.cell):
			return sim.deposit(machine.cell, item, carried) > 0
	return false


## Craft a machine item from carried ingots into the pack (the 1/2/3 hotbar craft).
func try_craft(def: MachineDef) -> bool:
	return sim.craft(def)


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
		if _player.position.distance_squared_to(_cell_center(c)) > reach_sq:
			continue
		var item: StringName = (sim.ground[c] as Dictionary).keys()[0]
		if sim.collect_ground(c):
			_particles.pop(_cell_center(c), Visuals.item_color(item))  # pickup pop


## The active camera zoom level (Z cycles the index). Read everywhere the view-size matters.
func _current_zoom() -> float:
	return ZOOM_LEVELS[_zoom_idx]


## Cycle to the next zoom level (Z) and apply it to the camera — Terraria-style zoom-out/in.
func _cycle_zoom() -> void:
	_zoom_idx = (_zoom_idx + 1) % ZOOM_LEVELS.size()
	if _camera != null:
		_camera.zoom = Vector2(_current_zoom(), _current_zoom())


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
		return sim.pickup_machine(cell)  # pick your machine back up into the pack
	if sim.has_conduit(cell):
		return sim.remove_conduit(cell)  # pick a power tube back up into the pack
	var def: MachineDef = _selected_machine_def()
	if def != null and def.behavior == &"conduit":
		var laid: bool = sim.place_conduit(cell)  # power tube → the conduit layer (not a machine)
		if laid:
			_particles.spark(_cell_center(cell), Visuals.machine_color(def).lightened(0.3))
		return laid
	if def != null and _placeable(cell):
		var built: bool = sim.build_from_pack(def, cell) != null
		if built:
			_particles.spark(_cell_center(cell), Visuals.machine_color(def).lightened(0.3))
			_shake = maxf(_shake, 2.2)
		return built
	# Block placement (the Terraria build primitive): the selected hotbar item is a building material.
	var mat: StringName = _selected_build_material()
	if mat != &"" and _placeable(cell) and sim.place_block(cell, mat):
		_particles.dust(_cell_center(cell), Visuals.terrain_dust(mat), 6)
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
			info["mode"] = "splits the flow DOWN + RIGHT"
		&"generator":
			info["mode"] = "burns coal → POWER" + ("  (running)" if m.fuel > 0 else "  (out of fuel)")
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
		and sim.machine_at(cell) == null and not sim.has_conduit(cell) and not _player_occupies(cell)


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
		&"build":
			var f: Vector2i = _first_forge()
			if f.x >= 0:
				var cap: Vector2i = f + Vector2i(0, -1)   # the drill caps the forge from directly above
				if sim.machine_at(cap) == null and not sim.is_solid(cap):
					out.append({"cell": cap, "mode": "ghost"})
	return out


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
