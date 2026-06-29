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
const CAMERA_ZOOM: float = 0.7     ## camera zoom (provisional, tuned by eye); smaller = further out
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
	_camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
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
		machine_icons[def.id] = {"color": Visuals.machine_color(def), "kind": Visuals.machine_kind(def)}
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
	var view: Vector2 = Vector2(Hud.CANVAS) / CAMERA_ZOOM    # world area the camera shows
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
## HOW the world is made — swap the generator and nothing here changes. Then place the lone Processor
## forge the player hand-feeds (a machine, not terrain — stays MainView's concern).
func _seed_world() -> void:
	var gen: WorldGen = LayeredWorldGen.new()
	var world: WorldData = gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, WORLD_SEED)
	sim.load_world(world)
	var processor: MachineDef = load("res://src/data/machines/processor.tres")
	# The forge sits ON the surface (row 4, resting on the row-5 grass), not floating in the sky. It's
	# fed ONLY by ore you dig + deposit; forged ingots pile in its own cell to be walked over.
	sim.place_machine(processor, Vector2i(6, 4))
	if dev_start:
		_dev_seed_pack()


## Dev-testing kit: start with a stocked pack so you can immediately exercise the build/automation loop
## (place machines, feed, smelt) without first hand-mining a stack of ore. Items are SPAWNED, so they
## count as produced to keep the conservation invariant true. Flip DEV_START off for a clean playthrough.
## NOTE: the head-lamp glow and forge embers are LIGHTING effects on the miner/machines, not carryable
## items — there's nothing to put in the pack for those; they appear automatically in play.
func _dev_seed_pack() -> void:
	var kit: Dictionary = {&"ore": 20, &"ingot": 20, &"wood": 10, &"processor": 2, &"splitter": 2, &"lift": 1, &"drill": 1}
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
	if _hud != null:
		_hud.hover_info = _hover_info()
		_hud.crafting_open = _crafting_open
		_hud.show_minimap = _show_minimap
		_hud.show_help = _show_help
		if _player != null:
			_hud.minimap_focus = _player.position
			_hud.minimap_view = Vector2(Hud.CANVAS) / CAMERA_ZOOM  # world area the camera shows


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
	elif event.is_action_pressed(Controls.CYCLE_NEXT):
		_cycle_inventory(1)
	elif event.is_action_pressed(Controls.CYCLE_PREV):
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
	_aim = _cell_at(get_global_mouse_position())
	if _paused:
		return
	if Input.is_action_pressed(Controls.MINE) and _mine_cooldown <= 0.0 \
			and try_mine(_aim):
		_mine_cooldown = MINE_TIME


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


## Scoop up any resting product pile in a cell the body overlaps — Factorio/Terraria-style "walk
## over items to grab them". Pure discrete sim edit (collect_ground); the avatar only triggers it.
func _collect_ground_under_player() -> void:
	if _player == null or sim.ground.is_empty():
		return
	var half := Vector2(Player.WIDTH, Player.HEIGHT) * 0.5
	var lo: Vector2i = _cell_at(_player.position - half)
	var hi: Vector2i = _cell_at(_player.position + half)
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			var cell := Vector2i(cx, cy)
			var pile: Dictionary = sim.ground.get(cell, {})
			if pile.is_empty():
				continue
			var item: StringName = pile.keys()[0]
			if sim.collect_ground(cell):
				_particles.pop(_cell_center(cell), Visuals.item_color(item))  # walk-over pickup pop


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
## a machine, you let go above its column and it falls in (or onto the floor). Drops at the body's own
## cell; the sim cascades it down via drop_item. Returns whether anything fell.
func try_drop() -> bool:
	if _player == null:
		return false
	var slots: Array[Dictionary] = sim.inventory_slots()
	if slots.is_empty():
		return false
	var sel: int = clampi(_inv_selected, 0, slots.size() - 1)
	var item: StringName = slots[sel]["item"]
	var carried: int = int(slots[sel]["count"])
	var cell: Vector2i = _cell_at(_player.position)
	var dropped: int = sim.drop_item(cell, item, carried)
	if dropped > 0:
		_particles.pop(_cell_center(cell), Visuals.item_color(item))
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
	var def: MachineDef = _selected_machine_def()
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
			info["mode"] = "lifts goods + you UP (costs throughput)"
		&"splitter":
			info["mode"] = "splits the flow DOWN + RIGHT"
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
		and sim.machine_at(cell) == null and not _player_occupies(cell)


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
