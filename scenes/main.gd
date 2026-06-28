class_name MainView
extends Node2D

## Representation + input root for Prototype 2. OWNS a FactorySim (game-session-owns-sim rule,
## docs/RISKS.md), advances it, draws the WORLD in world-space under a follow Camera2D, and hosts
## the embodied Player (a separate representation-layer node). It only READS sim state — never
## writes buffers/progress/sink. Terrain edits go through the sim's discrete API. Falling-item
## sprites are PURELY COSMETIC (driven by the sim's flow-event log). Delete the visuals/player and
## the production numbers are identical.
##
## P2·S1a scope: a body you move in a scrolling world that shares space with the running factory.
## NOT here yet: digging (S1b), inventory/hauling (S2), embodied building (S3). The god-cursor
## build palette of Prototype 1 was intentionally removed — building becomes embodied in S3.
##
## DESIGN-OPEN (placeholder, undecided): world size/shape, terrain layout, colours, camera feel,
## the body's look, all movement numbers, art style. Collected for PLAYTEST_NOTES once felt.

const CELL: int = 32
const FALL_DURATION: float = 0.30
const WORLD_SIZE := Vector2(FactorySim.GRID_COLS * CELL, FactorySim.GRID_ROWS * CELL)

var sim: FactorySim
var _player: Player
var _camera: Camera2D
var _font: Font = ThemeDB.fallback_font
var _paused: bool = false
## Cosmetic falling sprites: {from: Vector2, to: Vector2, t: float, color: Color} in WORLD coords.
var _falling: Array[Dictionary] = []


func _ready() -> void:
	sim = FactorySim.new()
	_seed_world()

	_player = Player.new()
	_player.sim = sim
	_player.position = _cell_center(Vector2i(2, 16))  # on the ground near the left
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
	layer.add_child(hud)
	add_child(layer)


## Build the starting world: solid ground (with a chute gap under the factory so the cascade falls
## clean to the sink), a few platforms to climb, and the demo factory in shared space.
func _seed_world() -> void:
	var chute: Array[int] = [9, 10]  # leave these columns open top-to-bottom for the cascade
	for col: int in FactorySim.GRID_COLS:
		if col in chute:
			continue
		sim.set_solid(Vector2i(col, 18), true)
		sim.set_solid(Vector2i(col, 19), true)
	# Climbable ledges from the ground up toward the factory at the top.
	for ledge: Array in [[2, 15, 4], [11, 14, 3], [4, 11, 3], [13, 9, 3], [4, 7, 3]]:
		for i: int in int(ledge[2]):
			sim.set_solid(Vector2i(int(ledge[0]) + i, int(ledge[1])), true)
	# Demo factory: vent → splitter fans into two processors; their ingots rain down the chute.
	var vent: MachineDef = load("res://src/data/machines/ore_vent.tres")
	var processor: MachineDef = load("res://src/data/machines/processor.tres")
	var splitter: MachineDef = load("res://src/data/machines/splitter.tres")
	sim.place_machine(vent, Vector2i(9, 1))
	sim.place_machine(splitter, Vector2i(9, 4))
	sim.place_machine(processor, Vector2i(9, 7))
	sim.place_machine(processor, Vector2i(10, 7))


func _process(delta: float) -> void:
	if not _paused:
		sim.advance(delta)
		_spawn_falling_from_events()
		_advance_falling(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_P:
			_paused = not _paused


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
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color(0.11, 0.12, 0.15))  # the open shaft/air
	_draw_terrain()
	_draw_grid()
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE).grow(1.0), Color(0.22, 0.23, 0.27), false, 2.0)
	_draw_drop_paths()
	_draw_falling()
	for machine: MachineState in sim.machines:
		_draw_machine(machine)


func _draw_terrain() -> void:
	for cell: Variant in sim.solid:
		var c: Vector2i = cell
		var pos := Vector2(c) * float(CELL)
		draw_rect(Rect2(pos, Vector2(CELL, CELL)), Color(0.30, 0.22, 0.16))          # earth
		draw_rect(Rect2(pos, Vector2(CELL, CELL)), Color(0.0, 0.0, 0.0, 0.18), false, 1.0)


func _draw_grid() -> void:
	var line_col := Color(1, 1, 1, 0.04)
	for c: int in FactorySim.GRID_COLS + 1:
		var x: float = float(c * CELL)
		draw_line(Vector2(x, 0.0), Vector2(x, WORLD_SIZE.y), line_col)
	for r: int in FactorySim.GRID_ROWS + 1:
		var y: float = float(r * CELL)
		draw_line(Vector2(0.0, y), Vector2(WORLD_SIZE.x, y), line_col)


## Faint guide tracing where each machine's output goes — down its column, and for a splitter the
## sideways-then-down elbow. Mirrors FactorySim._destinations. A drop that lands on a machine draws
## a full connector; a terminal drop (falling out to the sink) draws only a short stub, so guides
## don't streak the whole tall world down into the HUD.
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


## y where a guide should stop: the top of the next machine down this column, or — if the item just
## falls out to the sink — a short stub below where it started (no full-height line to nowhere).
func _guide_end_y(col: int, start_row: int, stub_from: float) -> float:
	for row: int in range(start_row, FactorySim.GRID_ROWS):
		if sim.machine_at(Vector2i(col, row)) != null:
			return float(row * CELL)
	return stub_from + float(CELL) * 0.9


func _draw_falling() -> void:
	for f: Dictionary in _falling:
		var from: Vector2 = f["from"]
		var to: Vector2 = f["to"]
		var t: float = clampf(float(f["t"]), 0.0, 1.0)
		var p: Vector2 = from.lerp(to, t * t)  # t^2 = accelerating under gravity
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
