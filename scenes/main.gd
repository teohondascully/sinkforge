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

const EARTH_COLOR := Color(0.30, 0.22, 0.16)
const ORE_COLOR := Color(0.85, 0.55, 0.24)

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


func _ready() -> void:
	sim = FactorySim.new()
	_craftable = [
		load("res://src/data/machines/processor.tres"),
		load("res://src/data/machines/splitter.tres"),
	]
	for def: MachineDef in _craftable:
		_machine_defs_by_id[def.id] = def
	_seed_world()

	_player = Player.new()
	_player.sim = sim
	_player.position = _cell_center(Vector2i(3, 3))  # on the surface, near the forge
	add_child(_player)

	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
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
		machine_icons[def.id] = {"color": _machine_color(def), "tag": _tag(def.display_name)}
	hud.craft_options = craft_opts
	hud.machine_icons = machine_icons
	hud.inv_selected_getter = func() -> int: return _inv_selected
	layer.add_child(hud)
	add_child(layer)


## Build the starting world: open sky on top, solid earth below, an output chute under the forge,
## ore veins to discover by digging, and the lone Processor the player hand-feeds.
func _seed_world() -> void:
	for row: int in range(4, FactorySim.GRID_ROWS):
		for col: int in FactorySim.GRID_COLS:
			sim.set_solid(Vector2i(col, row), &"earth")
	for row: int in range(4, 6):  # a SHORT chute under the forge (col 6) — spat ingots fall a couple
		sim.set_solid(Vector2i(6, row), &"")  # cells and land on the row-6 floor, where you collect them
	# Shallow veins (rows 5-6) are mineable from the surface within reach, so the FIRST loop is
	# completable by hand today — no ladders yet. Deeper veins are aspiration: getting back up from
	# them is the friction that will later pull traversal/automation (the manual→automated arc).
	var shallow: Array = [[8, 5], [9, 5], [8, 6], [11, 5], [12, 5], [12, 6]]
	var deep: Array = [[3, 9], [4, 9], [10, 12], [11, 12], [15, 7], [16, 7], [8, 16], [9, 16], [9, 17]]
	for vein: Array in shallow + deep:
		sim.set_solid(Vector2i(int(vein[0]), int(vein[1])), &"ore")
	var processor: MachineDef = load("res://src/data/machines/processor.tres")
	sim.place_machine(processor, Vector2i(6, 3))  # the forge — fed ONLY by ore you dig + deposit


func _process(delta: float) -> void:
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
				_deposit_into_reach()
			elif key.keycode >= KEY_1 and key.keycode < KEY_1 + _craftable.size():
				sim.craft(_craftable[key.keycode - KEY_1])  # 1/2 craft a machine item into the pack
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				_try_build()
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
			and _can_reach(_aim) and sim.is_solid(_aim):
		sim.mine(_aim)
		_mine_cooldown = MINE_TIME


## Hand the SELECTED carried item into the nearest machine within reach (the manual half of the arc).
func _deposit_into_reach() -> void:
	var slots: Array[Dictionary] = sim.inventory_slots()
	if slots.is_empty():
		return
	var sel: int = clampi(_inv_selected, 0, slots.size() - 1)
	var item: StringName = slots[sel]["item"]
	var carried: int = int(slots[sel]["count"])
	if carried <= 0:
		return
	for machine: MachineState in sim.machines:
		if _can_reach(machine.cell):
			sim.deposit(machine.cell, item, carried)
			return


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


## RMB build verb: standing in reach of the aimed cell, place the selected machine on an open cell,
## or pick one of your own machines back up. Reach-limited + situated — the embodied replacement for
## the removed god-cursor palette. Every edit goes through the sim's discrete place/remove API, so
## the body still only triggers discrete mutations (determinism preserved).
func _try_build() -> void:
	if _paused or not _can_reach(_aim):
		return
	if sim.machine_at(_aim) != null:
		sim.pickup_machine(_aim)  # pick your machine back up into the pack
		return
	var def: MachineDef = _selected_machine_def()
	if def != null and _placeable(_aim):
		sim.build_from_pack(def, _aim)


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
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.07, 0.08, 0.11))  # open air / sky-in-the-dark
	_draw_terrain()
	_draw_grid()
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE).grow(1.0), Color(0.22, 0.23, 0.27), false, 2.0)
	_draw_drop_paths()
	_draw_ground()
	_draw_falling()
	for machine: MachineState in sim.machines:
		_draw_machine(machine)
	_draw_aim()


func _draw_terrain() -> void:
	for cell: Variant in sim.solid:
		var c: Vector2i = cell
		var pos := Vector2(c) * float(CELL)
		var is_ore: bool = sim.solid[c] == &"ore"
		draw_rect(Rect2(pos, Vector2(CELL, CELL)), ORE_COLOR if is_ore else EARTH_COLOR)
		draw_rect(Rect2(pos, Vector2(CELL, CELL)), Color(0.0, 0.0, 0.0, 0.18), false, 1.0)
		if is_ore:  # a few facets so a vein reads as "valuable", not just a brown tile
			draw_circle(pos + Vector2(CELL, CELL) * 0.5, 3.5, Color(1.0, 0.85, 0.5))


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
	var ok: bool = _placeable(_aim)
	var border := Color(0.45, 0.95, 0.5, 0.9) if ok else Color(0.95, 0.45, 0.40, 0.9)
	draw_rect(inner, border, false, 2.0)
	draw_string(_font, Vector2(pos.x + 3, pos.y + 11), _tag(def.display_name),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.92, 0.97, 0.92, 0.8))


func _draw_grid() -> void:
	var line_col := Color(1, 1, 1, 0.04)
	for c: int in FactorySim.GRID_COLS + 1:
		var x: float = float(c * CELL)
		draw_line(Vector2(x, 0.0), Vector2(x, WORLD_SIZE.y), line_col)
	for r: int in FactorySim.GRID_ROWS + 1:
		var y: float = float(r * CELL)
		draw_line(Vector2(0.0, y), Vector2(WORLD_SIZE.x, y), line_col)


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
		# Travel down the column, with a small launch-hop so the item reads as SPAT OUT, then gravity.
		var p: Vector2 = from.lerp(to, t)
		p.y -= sin(t * PI) * 10.0
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color(0.05, 0.05, 0.07))
		draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9, 9)), f["color"])


func _draw_machine(machine: MachineState) -> void:
	var pos: Vector2 = Vector2(machine.cell) * float(CELL)
	var recipe: RecipeDef = machine.def.recipe
	var body := Rect2(pos + Vector2(1.0, 1.0), Vector2(CELL - 2.0, CELL - 2.0))
	draw_rect(body, _machine_color(machine.def))
	draw_rect(body, Color(0.04, 0.04, 0.06, 0.7), false, 1.0)
	draw_string(_font, Vector2(pos.x + 3, pos.y + 11), _tag(machine.def.display_name),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.06, 0.06, 0.09))
	draw_string(_font, Vector2(pos.x + 3, pos.y + 25), str(_held(machine)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.96, 0.96, 0.99))
	if recipe != null and recipe.time > 0.0:
		var bar_y: float = pos.y + float(CELL) - 3.0
		draw_rect(Rect2(pos.x, bar_y, float(CELL), 3.0), Color(0.0, 0.0, 0.0, 0.35))
		var frac: float = clampf(machine.progress / recipe.time, 0.0, 1.0)
		draw_rect(Rect2(pos.x, bar_y, float(CELL) * frac, 3.0), Color(0.40, 0.90, 0.45))


# --- helpers -----------------------------------------------------------------

func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * float(CELL) + Vector2(CELL, CELL) * 0.5


func _cell_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / float(CELL)), floori(world_pos.y / float(CELL)))


func _machine_color(def: MachineDef) -> Color:
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


func _tag(display_name: String) -> String:
	var t: String = ""
	for word: String in display_name.split(" ", false):
		if not word.is_empty():
			t += word[0]
	return t.to_upper()


func _held(machine: MachineState) -> int:
	var n: int = 0
	for v: int in machine.input_buffer.values():
		n += v
	for v: int in machine.output_buffer.values():
		n += v
	return n
