class_name MainView
extends Node2D

## The CONTROLLER + session root. OWNS a FactorySim (game-session-owns-sim rule, docs/RISKS.md),
## advances it, hosts the embodied Player + follow Camera2D, and translates mouse/keys into the
## player's reach-gated WORLD VERBS (try_mine / try_deposit / try_build / try_craft). It only READS
## sim production state — every edit goes through the sim's discrete API. It does NOT draw: a child
## WorldRenderer is the VIEW (it reads the sim + the aim state we push it each frame); FallingItems is
## the cosmetic drop layer. Delete the view/player and the production numbers are identical.
##
## The loop you drive: DIG solid earth (LMB, reach-limited) → mine ore veins into your pack → hand-feed
## a Processor "forge" → craft machines from ingots (1/2/3) → BUILD the chain (RMB place / pick-up) →
## the Lift hauls goods + you UP. See docs/ for the design; combat/worldgen/power are still ahead.
##
## DESIGN-OPEN (placeholder): world size/layout, camera feel, the body's look, mining feel/reach, all
## numbers, art style — collected for PLAYTEST_NOTES once felt.

const CELL: int = 32
const REACH_CELLS: float = 3.2     ## how far the body can mine/deposit from its centre
const MINE_TIME: float = 0.12      ## seconds between mined cells while holding
const WORLD_SIZE := Vector2(FactorySim.GRID_COLS * CELL, FactorySim.GRID_ROWS * CELL)
const CAMERA_ZOOM: float = 0.7     ## camera zoom (provisional, tuned by eye); smaller = further out
const WORLD_SEED: int = 1337       ## fixed gen seed (provisional; expose to a new-game UI later)

var sim: FactorySim
var _player: Player
var _camera: Camera2D
var _renderer: WorldRenderer       ## the VIEW: all world-space drawing + lighting (we push it aim state)
var _paused: bool = false
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


func _ready() -> void:
	sim = FactorySim.new()
	_craftable = [
		load("res://src/data/machines/processor.tres"),
		load("res://src/data/machines/splitter.tres"),
		load("res://src/data/machines/lift.tres"),
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
	_camera.position_smoothing_speed = 7.0
	# Dead-zone (drag margins): the body moves freely inside a centre box; the camera only scrolls once
	# it pushes the edge — so walking and jumping don't jitter the view. Smoothing eases the catch-up.
	_camera.drag_horizontal_enabled = true
	_camera.drag_vertical_enabled = true
	_camera.drag_left_margin = 0.18
	_camera.drag_right_margin = 0.18
	_camera.drag_top_margin = 0.22
	_camera.drag_bottom_margin = 0.24
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(WORLD_SIZE.x)
	_camera.limit_bottom = int(WORLD_SIZE.y)
	_player.add_child(_camera)
	_camera.make_current()

	var layer := CanvasLayer.new()
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
	layer.add_child(hud)
	add_child(layer)

	# The VIEW: a WorldRenderer draws all world-space sim state (terrain, machines, ground, falling
	# items, lighting). It reads the sim + the aim state we push each frame; it never mutates anything.
	# Its draw sits at z 0 and its lighting at z 50/51, so the player (z 60) stays crisp on top.
	_renderer = WorldRenderer.new()
	_renderer.setup(sim, _falling, _player)
	add_child(_renderer)


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


func _process(delta: float) -> void:
	if not _paused:
		sim.advance(delta)
		_falling.spawn_from_events(sim, _cell_center)
		_falling.advance(delta)
		_collect_ground_under_player()
	_update_mining(delta)  # refreshes _aim from the mouse
	# Push the cursor + its computed affordances to the view (it can't derive reach/placeable itself).
	_renderer.set_aim(_aim, _can_reach(_aim), _placeable(_aim), _selected_machine_def())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_P:
				_paused = not _paused
			elif key.keycode == KEY_E:
				try_deposit()
			elif key.keycode >= KEY_1 and key.keycode < KEY_1 + _craftable.size():
				try_craft(_craftable[key.keycode - KEY_1])  # 1/2 craft a machine item into the pack
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				try_build(_aim)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_cycle_inventory(1)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_cycle_inventory(-1)


# --- world-interaction tools (mining / depositing): discrete sim edits only ---

func _update_mining(delta: float) -> void:
	_mine_cooldown = maxf(0.0, _mine_cooldown - delta)
	_aim = _cell_at(get_global_mouse_position())
	if _paused:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _mine_cooldown <= 0.0 \
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
	return sim.mine(cell) != &""


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
			sim.collect_ground(Vector2i(cx, cy))


## Move the active hotbar slot, wrapping across the items currently carried.
func _cycle_inventory(dir: int) -> void:
	var n: int = sim.inventory_slots().size()
	if n <= 0:
		_inv_selected = 0
		return
	_inv_selected = (_inv_selected + dir + n) % n


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
		return sim.build_from_pack(def, cell) != null
	return false


## The machine def for the active hotbar slot, or null if the selected item isn't a placeable
## machine you carry (it's a resource, or the pack is empty).
func _selected_machine_def() -> MachineDef:
	var slots: Array[Dictionary] = sim.inventory_slots()
	if slots.is_empty():
		return null
	var sel: int = clampi(_inv_selected, 0, slots.size() - 1)
	return _machine_defs_by_id.get(slots[sel]["item"], null)


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
