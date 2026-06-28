class_name MainView
extends Node2D

## Representation + input root for Prototype 2. OWNS a FactorySim (game-session-owns-sim rule,
## docs/RISKS.md), advances it, draws the WORLD in world-space under a follow Camera2D, hosts the
## embodied Player, and translates the mouse/keys into the player's WORLD-INTERACTION tools (mining,
## depositing). It only READS sim production state — terrain/inventory edits go through the sim's
## discrete API (mine/deposit/set_solid). Falling-item sprites are PURELY COSMETIC. Delete the
## visuals/player and the production numbers are identical.
##
## P2·S1a→S3: a body in a world of solid earth you DIG through (LMB, reach-limited); ore veins you
## mine into your pack; a Processor "forge" you hand-feed; and now you BUILD the chain from inside
## the world — RMB places a selected machine (Processor/Splitter) on an open cell within reach, or
## picks one of your machines back up (the embodied replacement for the removed god-cursor palette).
## NOT here yet: a build economy (machines are free this slice — see DECISIONS), automation of
## hauling/movement, combat, worldgen.
##
## DESIGN-OPEN (placeholder, undecided): world size/layout, colours, camera feel, the body's look,
## mining feel/reach, all numbers, art style. Collected for PLAYTEST_NOTES once felt.

const CELL: int = 32
const FALL_DURATION: float = 0.30
const REACH_CELLS: float = 3.2     ## how far the body can mine/deposit from its centre
const MINE_TIME: float = 0.12      ## seconds between mined cells while holding
const WORLD_SIZE := Vector2(FactorySim.GRID_COLS * CELL, FactorySim.GRID_ROWS * CELL)
const CAMERA_ZOOM: float = 0.7     ## camera zoom (provisional, tuned by eye); smaller = further out
const WORLD_SEED: int = 1337       ## fixed gen seed (provisional; expose to a new-game UI later)

const SKY_COLOR := Color(0.09, 0.11, 0.16)         ## open air ABOVE the surface

var sim: FactorySim
var _player: Player
var _camera: Camera2D
var _font: Font = ThemeDB.fallback_font
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
## Cosmetic falling sprites: {from: Vector2, to: Vector2, t: float, color: Color} in WORLD coords.
var _falling: Array[Dictionary] = []
## Free-running clock for cosmetic animation (the lift updraft shimmer). Never feeds the sim.
var _anim_time: float = 0.0
## The MaterialDef registry (id -> MaterialDef): the VISUALISER half of the world-engine handshake.
## The renderer maps a cell's material id to its appearance through this; the sim/generator only ever
## deal in ids. Loaded from src/data/materials/*.tres (see docs/WORLDGEN.md).
var _materials: Dictionary = {}


func _ready() -> void:
	sim = FactorySim.new()
	for path: String in [
		"res://src/data/materials/earth.tres",
		"res://src/data/materials/ore.tres",
		"res://src/data/materials/stone.tres",
		"res://src/data/materials/dirt_wall.tres",
		"res://src/data/materials/stone_wall.tres",
	]:
		var def: MaterialDef = load(path)
		_materials[def.id] = def
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
		machine_icons[def.id] = {"color": _machine_color(def), "kind": _machine_kind(def)}
	hud.craft_options = craft_opts
	hud.machine_icons = machine_icons
	hud.inv_selected_getter = func() -> int: return _inv_selected
	layer.add_child(hud)
	add_child(layer)


## Build the starting world through the world-engine handshake (docs/WORLDGEN.md): a swappable
## WorldGen produces a WorldData (two material grids); the sim ingests it. MainView no longer knows
## HOW the world is made — swap the generator and nothing here changes. Then place the lone Processor
## forge the player hand-feeds (a machine, not terrain — stays MainView's concern).
func _seed_world() -> void:
	var gen: WorldGen = HeightmapWorldGen.new()
	var world: WorldData = gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, WORLD_SEED)
	sim.load_world(world)
	var processor: MachineDef = load("res://src/data/machines/processor.tres")
	# The forge sits ON the surface (row 4, resting on the row-5 grass), not floating in the sky. It's
	# fed ONLY by ore you dig + deposit; forged ingots pile in its own cell to be walked over.
	sim.place_machine(processor, Vector2i(6, 4))


func _process(delta: float) -> void:
	_anim_time += delta
	if not _paused:
		sim.advance(delta)
		_spawn_falling_from_events()
		_advance_falling(delta)
		_collect_ground_under_player()
	_update_mining(delta)
	queue_redraw()


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


# --- cosmetic falling items (driven by the sim, never feeding back) -----------

func _spawn_falling_from_events() -> void:
	for ev: Dictionary in sim.flow_events:
		var from: Vector2 = _cell_center(ev["from"])
		var to: Vector2 = _cell_center(ev["to"])
		var color: Color = _item_color(ev["item"])
		var count: int = int(ev["count"])
		for i: int in count:
			var jitter := Vector2((float(i) - float(count - 1) * 0.5) * 4.0, 0.0)
			_falling.append({"from": from + jitter, "to": to + jitter, "t": 0.0, "color": color})
	sim.flow_events.clear()


func _advance_falling(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for f: Dictionary in _falling:
		var t: float = float(f["t"]) + delta / FALL_DURATION
		if t < 1.0:
			f["t"] = t
			keep.append(f)
	_falling = keep


# --- drawing (WORLD space; the Camera2D provides the view transform) ----------

func _draw() -> void:
	_draw_background()  # sky above the surface; dark-dirt BACK WALL behind every dug-out cell + depth
	_draw_terrain()
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE).grow(1.0), Color(0.22, 0.23, 0.27), false, 2.0)
	_draw_drop_paths()
	_draw_updrafts()  # rising shimmer in each lift's shaft, so "this column lifts UP" reads
	_draw_ground()
	_draw_falling()
	for machine: MachineState in sim.machines:
		_draw_machine(machine)
	_draw_aim()


func _draw_terrain() -> void:
	for cell: Variant in sim.solid:
		var c: Vector2i = cell
		var pos := Vector2(c) * float(CELL)
		var def: MaterialDef = _material(sim.solid[c])
		# Darken with depth so the lower world reads as DEEPER, not one flat fill.
		var depth: float = clampf(float(c.y) / float(FactorySim.GRID_ROWS), 0.0, 1.0)
		var col: Color = def.base_color.darkened(depth * def.depth_darken)
		draw_rect(Rect2(pos, Vector2(CELL, CELL)), col)
		if def.grain:
			# Dirt grain — a darker pit + a lighter clod, deterministic per cell, so earth isn't a
			# flat colour fill (the #1 "debug art" tell once the grid is gone).
			var sp: Array[Vector2] = _cell_speckles(c, 2)
			draw_rect(Rect2(pos + sp[0] - Vector2(2, 2), Vector2(4, 4)), col.darkened(0.22))
			draw_rect(Rect2(pos + sp[1] - Vector2(1.5, 1.5), Vector2(3, 3)), col.lightened(0.10))
		if def.has_nuggets():  # embedded specks so a vein reads as ore IN rock, not an orange block
			for nug: Vector2 in _cell_speckles(c, def.nugget_count):
				draw_circle(pos + nug, 2.0, def.nugget_color)
	_draw_terrain_surface()  # grass caps + diagonal slope ramps on the exposed surface


## A cell's MaterialDef via the registry, or a safe fallback so an unknown id still renders.
func _material(id: StringName) -> MaterialDef:
	return _materials.get(id, _materials.get(&"earth"))


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
## universal (every material — earth, stone, ore — slopes); only the EDGE PAINT is material-specific:
## a capped material (grass) gets its bright cap colour, an uncapped one (stone) a subtle lightened lip.
func _draw_terrain_surface() -> void:
	for col: int in range(FactorySim.GRID_COLS):
		var r: int = sim.surface_row(col)
		if r >= FactorySim.GRID_ROWS:
			continue  # empty column, no surface
		var def: MaterialDef = _material(sim.material_at(Vector2i(col, r)))
		var edge: Color = def.cap_color if def.has_cap() else def.base_color.lightened(0.18)
		var px := float(col * CELL)
		var py := float(r * CELL)
		match sim.ramp_dir(col):
			1:  # rising to the right — fill the air corner above with a 45° slope
				var lo := Vector2(px, py)
				var hi := Vector2(px + CELL, py - CELL)
				draw_colored_polygon([lo, Vector2(px + CELL, py), hi], def.base_color)
				draw_line(lo, hi, edge, 3.0)
			-1:  # rising to the left
				var lo2 := Vector2(px + CELL, py)
				var hi2 := Vector2(px, py - CELL)
				draw_colored_polygon([lo2, Vector2(px, py), hi2], def.base_color)
				draw_line(lo2, hi2, edge, 3.0)
			_:  # flat top: a capped lip
				draw_rect(Rect2(px, py, float(CELL), 4.0), edge)


## The cursor cell, drawn by context so digging and building are legible without a god-cursor:
##   solid earth   -> MINE target (white box; faint out of reach)
##   your machine  -> PICK-UP affordance (red outline; only when in reach)
##   open cell     -> BUILD ghost of the selected machine within reach (green outline = placeable,
##                    red = blocked, e.g. your own footing). Out-of-reach open cells draw nothing, so
##                    the open sky stays uncluttered.
func _draw_aim() -> void:
	if not sim.in_bounds(_aim):
		return
	var pos := Vector2(_aim) * float(CELL)
	var in_reach: bool = _can_reach(_aim)
	if sim.is_solid(_aim):
		var col := Color(1, 1, 1, 0.85) if in_reach else Color(1, 1, 1, 0.18)
		draw_rect(Rect2(pos, Vector2(CELL, CELL)), col, false, 2.0)
		return
	if not in_reach:
		return
	var inner := Rect2(pos + Vector2(1, 1), Vector2(CELL - 2, CELL - 2))
	if sim.machine_at(_aim) != null:
		draw_rect(inner, Color(0.95, 0.45, 0.40, 0.9), false, 2.0)  # pick-up affordance
		return
	var def: MachineDef = _selected_machine_def()
	if def == null:
		return  # the active hotbar item isn't a placeable machine — nothing to ghost
	# A brighter, more opaque tint so the ghost reads as a translucent PREVIEW on its own — not only
	# by its border (4b critique: the dark fill leaned entirely on the green outline to be seen).
	var ghost: Color = _machine_color(def).lerp(Color.WHITE, 0.20)
	ghost.a = 0.55
	draw_rect(Rect2(pos + Vector2(2, 2), Vector2(CELL - 4, CELL - 4)), ghost)
	_draw_machine_icon(pos + Vector2(CELL, CELL) * 0.5, def)  # PREVIEW the actual silhouette, not a "P"
	var ok: bool = _placeable(_aim)
	# A bright WHITE box hovering over the target cell (Terraria placement cursor); red when blocked.
	var border := Color(0.97, 0.98, 1.0, 0.95) if ok else Color(0.95, 0.45, 0.40, 0.95)
	draw_rect(inner, border, false, 2.5)


## Sky + the REAL background WALL layer (sim.wall). Open sky fills the top; each wall cell paints its
## material colour (depth-darkened) BEHIND the terrain, so a dug-out cell reveals the carved-room
## backing (a Terraria wall) rather than floating void. Blocks draw on top, so a wall only shows where
## its block has been mined away — exactly the dug rooms/tunnels.
func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), SKY_COLOR)
	for cell_v: Variant in sim.wall:
		var c: Vector2i = cell_v
		var def: MaterialDef = _material(sim.wall[c])
		var depth: float = clampf(float(c.y) / float(FactorySim.GRID_ROWS), 0.0, 1.0)
		draw_rect(Rect2(Vector2(c) * float(CELL), Vector2(CELL, CELL)),
			def.base_color.darkened(depth * def.depth_darken))


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
				draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9, 9)), _item_color(item))
				idx += 1


func _draw_falling() -> void:
	for f: Dictionary in _falling:
		var from: Vector2 = f["from"]
		var to: Vector2 = f["to"]
		var t: float = clampf(float(f["t"]), 0.0, 1.0)
		var col: Color = f["color"]
		# A fading comet-trail behind the item along its path, so the DOWNWARD flow reads as a stream
		# on the gravity "conveyor" (the core hook), not a lone hopping square.
		var trail: int = 4
		for i: int in range(trail, 0, -1):
			var tt: float = clampf(t - float(i) * 0.06, 0.0, 1.0)
			var pp: Vector2 = from.lerp(to, tt)
			pp.y -= sin(tt * PI) * 10.0
			var a: float = (1.0 - float(i) / float(trail + 1)) * 0.30
			var sz: float = 5.0 - float(i) * 0.7
			draw_rect(Rect2(pp - Vector2(sz, sz), Vector2(sz * 2.0, sz * 2.0)), Color(col.r, col.g, col.b, a))
		# Travel down the column, with a small launch-hop so the item reads as SPAT OUT, then gravity.
		var p: Vector2 = from.lerp(to, t)
		p.y -= sin(t * PI) * 10.0
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color(0.05, 0.05, 0.07))
		draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9, 9)), col)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), col.lightened(0.4))  # bright core "pops"


## A machine as a CASING + a type silhouette (no more "P 0" debug letters): a glowing furnace for the
## ore-fed forge/source, a gear for processors, a down+right fork for splitters. Buffered count shows
## as a small corner badge only when non-zero; the recipe progress bar stays.
func _draw_machine(machine: MachineState) -> void:
	var pos: Vector2 = Vector2(machine.cell) * float(CELL)
	var recipe: RecipeDef = machine.def.recipe
	var center: Vector2 = pos + Vector2(CELL, CELL) * 0.5
	var body := Rect2(pos + Vector2(1.0, 1.0), Vector2(CELL - 2.0, CELL - 2.0))
	draw_rect(body, _machine_color(machine.def))
	# Riveted casing: darker inset + corner bolts so it reads as a built machine, not a flat tile.
	draw_rect(body, Color(0.04, 0.04, 0.06, 0.8), false, 1.5)
	for corner: Vector2 in [Vector2(4, 4), Vector2(CELL - 4, 4), Vector2(4, CELL - 4),
			Vector2(CELL - 4, CELL - 4)]:
		draw_circle(pos + corner, 1.0, Color(0.0, 0.0, 0.0, 0.5))

	_draw_machine_icon(center, machine.def)

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


## Dispatch a machine's type silhouette at a cell centre (shared by the world machine, the build
## ghost, and — in spirit — the hotbar): furnace for the ore-fed source, fork for splitters, gear
## for everything else. One place so the icon a machine shows is the icon you preview when placing.
func _draw_machine_icon(center: Vector2, def: MachineDef) -> void:
	if def.behavior == &"lift":
		_draw_lift_icon(center)
	elif def.behavior == &"splitter":
		_draw_splitter_icon(center)
	elif def.recipe != null and def.recipe.inputs.is_empty():
		_draw_furnace_icon(center)
	else:
		_draw_gear_icon(center)


## The icon "kind" string for the HUD hotbar, so a carried machine item shows its silhouette too.
func _machine_kind(def: MachineDef) -> String:
	if def.behavior == &"lift":
		return "lift"
	if def.behavior == &"splitter":
		return "fork"
	if def.recipe != null and def.recipe.inputs.is_empty():
		return "furnace"
	return "gear"


## Furnace (ore source / forge): a dark mouth with a glowing ember core + a lintel cap.
func _draw_furnace_icon(center: Vector2) -> void:
	draw_rect(Rect2(center.x - 8.0, center.y - 9.0, 16.0, 2.5), Color(0.05, 0.05, 0.07))  # lintel
	draw_rect(Rect2(center.x - 6.5, center.y - 4.0, 13.0, 10.0), Color(0.12, 0.08, 0.05))  # mouth
	draw_circle(center + Vector2(0.0, 2.5), 3.4, Color(1.0, 0.55, 0.18))                   # ember
	draw_circle(center + Vector2(0.0, 2.5), 1.7, Color(1.0, 0.90, 0.55))


## Gear (processor): a cogged dark disc with a bright hub, so it reads as "working machine".
func _draw_gear_icon(center: Vector2) -> void:
	var gear := Color(0.10, 0.13, 0.18)
	draw_circle(center, 6.2, gear)
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0
		draw_circle(center + Vector2(cos(a), sin(a)) * 6.8, 1.7, gear)
	draw_circle(center, 2.6, Color(0.55, 0.78, 0.98))


## Lift: stacked UP-chevrons — it carries goods (and you) up its column, the paid inverse of gravity.
func _draw_lift_icon(center: Vector2) -> void:
	var up := Color(0.85, 1.0, 0.95)
	for k: int in 2:
		var oy: float = float(k) * 7.0 - 2.0
		draw_line(center + Vector2(-6.0, oy + 4.0), center + Vector2(0.0, oy - 2.0), up, 2.0)
		draw_line(center + Vector2(0.0, oy - 2.0), center + Vector2(6.0, oy + 4.0), up, 2.0)


## Fork (splitter): a stem that splits DOWN and to the RIGHT — mirrors its 50/50 routing.
func _draw_splitter_icon(center: Vector2) -> void:
	var fork := Color(0.93, 0.88, 1.0)
	draw_line(center + Vector2(0.0, -6.5), center, fork, 2.0)
	draw_line(center, center + Vector2(0.0, 7.0), fork, 2.0)
	draw_line(center, center + Vector2(7.0, 4.0), fork, 2.0)


# --- helpers -----------------------------------------------------------------

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * float(CELL) + Vector2(CELL, CELL) * 0.5


func _cell_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / float(CELL)), floori(world_pos.y / float(CELL)))


func _machine_color(def: MachineDef) -> Color:
	if def.behavior == &"lift":
		return Color(0.26, 0.66, 0.62)  # teal — reads as "anti-gravity tech"
	if def.behavior == &"splitter":
		return Color(0.58, 0.42, 0.78)
	var recipe: RecipeDef = def.recipe
	if recipe != null and recipe.inputs.is_empty():
		return Color(0.82, 0.45, 0.20)
	return Color(0.30, 0.55, 0.75)


func _item_color(item: StringName) -> Color:
	if item == &"ore":
		return Color(0.88, 0.52, 0.24)
	if item == &"ingot":
		return Color(0.97, 0.85, 0.42)
	return Color.WHITE


func _held(machine: MachineState) -> int:
	var n: int = 0
	for v: int in machine.input_buffer.values():
		n += v
	for v: int in machine.output_buffer.values():
		n += v
	return n
