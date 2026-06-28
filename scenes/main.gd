class_name MainView
extends Node2D

## Representation + input layer for Prototype 1. OWNS a FactorySim (game-session-owns-sim rule,
## see docs/RISKS.md), advances it, draws it, and translates mouse/keys into sim placement ops.
## It only READS sim production state — never writes buffers/progress/sink. Placement goes
## through the sim's public API. Falling-item sprites are PURELY COSMETIC: spawned from the
## sim's flow-event log and animated here; they never feed back into production. Delete this
## node and the numbers are identical.
##
## `sim` is exposed read-only for tests/tools. Only this node advances it.
##
## DESIGN-OPEN (presentation/controls, NOT canon — collect into PLAYTEST_NOTES when playable):
##  - Shaft framing (rock walls vs blueprint), grid size 14x9, colours, the falling-item look,
##    fall speed/easing, build UX (click-select + click-place, right-click remove, space pause),
##    fixed camera/no-zoom: ALL placeholder and undecided.

const CANVAS := Vector2(640, 360)
const CELL: int = 32
const FALL_DURATION: float = 0.30

var sim: FactorySim
var _font: Font = ThemeDB.fallback_font
var _origin: Vector2
var _palette: Array[Dictionary] = []
var _selected_def: MachineDef
var _paused: bool = false
## Cosmetic falling sprites: {from: Vector2, to: Vector2, t: float, color: Color}.
var _falling: Array[Dictionary] = []


func _ready() -> void:
	# Centre the shaft horizontally; leave a top strip for the palette and a bottom strip for OUTPUT.
	_origin = Vector2((CANVAS.x - float(FactorySim.GRID_COLS * CELL)) * 0.5, 36.0)
	sim = FactorySim.new()
	var vent: MachineDef = load("res://src/data/machines/ore_vent.tres")
	var processor: MachineDef = load("res://src/data/machines/processor.tres")
	_palette = [
		{"def": vent, "color": Color(0.82, 0.45, 0.20)},
		{"def": processor, "color": Color(0.30, 0.55, 0.75)},
	]
	_selected_def = vent
	# Initial demo placement so there is a running cascade on open (provisional).
	sim.place_machine(vent, Vector2i(7, 1))
	sim.place_machine(processor, Vector2i(7, 5))


func _process(delta: float) -> void:
	if not _paused:
		sim.advance(delta)
		_spawn_falling_from_events()
		_advance_falling(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_SPACE:
			_paused = not _paused
			queue_redraw()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		var pos: Vector2 = get_local_mouse_position()
		for i: int in _palette.size():
			if _palette_rect(i).has_point(pos):
				_selected_def = _palette[i]["def"]
				queue_redraw()
				return
		var cell: Vector2i = _cell_from_pixel(pos)
		if not sim.in_bounds(cell):
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			sim.place_machine(_selected_def, cell)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			sim.remove_machine(cell)
		queue_redraw()


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


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.06, 0.06, 0.08))  # surrounding rock
	var shaft := Rect2(_origin, Vector2(FactorySim.GRID_COLS * CELL, FactorySim.GRID_ROWS * CELL))
	draw_rect(shaft, Color(0.11, 0.12, 0.15))                        # the excavated shaft
	_draw_grid(shaft)
	draw_rect(shaft.grow(1.0), Color(0.22, 0.23, 0.27), false, 2.0)  # shaft frame
	_draw_drop_paths()
	_draw_falling()
	for machine: MachineState in sim.machines:
		_draw_machine(machine)
	_draw_output()
	_draw_palette()
	if _paused:
		draw_string(_font, Vector2(_origin.x, 24), "PAUSED  (space)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.72, 0.30))


func _draw_grid(shaft: Rect2) -> void:
	var line_col := Color(1, 1, 1, 0.05)
	for c: int in FactorySim.GRID_COLS + 1:
		var x: float = _origin.x + float(c * CELL)
		draw_line(Vector2(x, shaft.position.y), Vector2(x, shaft.end.y), line_col)
	for r: int in FactorySim.GRID_ROWS + 1:
		var y: float = _origin.y + float(r * CELL)
		draw_line(Vector2(shaft.position.x, y), Vector2(shaft.end.x, y), line_col)


## Faint guide line from each machine straight down its column to where its output lands
## (the next machine, or the shaft floor) — makes the gravity flow path legible at a glance.
func _draw_drop_paths() -> void:
	for machine: MachineState in sim.machines:
		var x: float = _origin.x + float(machine.cell.x * CELL) + float(CELL) * 0.5
		var y0: float = _origin.y + float(machine.cell.y * CELL) + float(CELL)
		draw_line(Vector2(x, y0), Vector2(x, _landing_y(machine)), Color(0.45, 0.55, 0.68, 0.20), 2.0)


func _landing_y(machine: MachineState) -> float:
	for row: int in range(machine.cell.y + 1, FactorySim.GRID_ROWS):
		if sim.machine_at(Vector2i(machine.cell.x, row)) != null:
			return _origin.y + float(row * CELL)
	return _origin.y + float(FactorySim.GRID_ROWS * CELL)


func _draw_falling() -> void:
	for f: Dictionary in _falling:
		var from: Vector2 = f["from"]
		var to: Vector2 = f["to"]
		var t: float = clampf(float(f["t"]), 0.0, 1.0)
		var p: Vector2 = from.lerp(to, t * t)  # t^2 = accelerating under gravity
		# Dark outline + colored core so a falling item reads as a distinct token.
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color(0.05, 0.05, 0.07))
		draw_rect(Rect2(p - Vector2(4.5, 4.5), Vector2(9, 9)), f["color"])


func _draw_machine(machine: MachineState) -> void:
	var pos: Vector2 = _origin + Vector2(machine.cell) * float(CELL)
	var recipe: RecipeDef = machine.def.recipe
	var is_source: bool = recipe != null and recipe.inputs.is_empty()
	draw_rect(Rect2(pos, Vector2(CELL, CELL)),
		Color(0.82, 0.45, 0.20) if is_source else Color(0.30, 0.55, 0.75))
	# Type tag (top) so stacked machines are distinguishable at a glance.
	draw_string(_font, Vector2(pos.x + 3, pos.y + 11), _tag(machine.def.display_name),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.06, 0.06, 0.09))
	# Held items (input + output) — ALWAYS shown, even 0, so the readout never disappears.
	draw_string(_font, Vector2(pos.x + 3, pos.y + 25), str(_held(machine)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.96, 0.96, 0.99))
	# Progress bar (track + fill) so 0% reads as an empty bar, not a glitchy nub.
	if recipe != null and recipe.time > 0.0:
		var bar_y: float = pos.y + float(CELL) - 3.0
		draw_rect(Rect2(pos.x, bar_y, float(CELL), 3.0), Color(0.0, 0.0, 0.0, 0.35))
		var frac: float = clampf(machine.progress / recipe.time, 0.0, 1.0)
		draw_rect(Rect2(pos.x, bar_y, float(CELL) * frac, 3.0), Color(0.40, 0.90, 0.45))


func _draw_output() -> void:
	var y: float = _origin.y + float(FactorySim.GRID_ROWS * CELL) + 22.0
	draw_string(_font, Vector2(_origin.x, y), "OUTPUT   %s" % _buf(sim.sink),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.80, 0.32))


func _draw_palette() -> void:
	for i: int in _palette.size():
		var entry: Dictionary = _palette[i]
		var r: Rect2 = _palette_rect(i)
		draw_rect(r, entry["color"])
		draw_string(_font, Vector2(r.position.x + 4, r.position.y + 15),
			_tag(entry["def"].display_name), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.06, 0.06, 0.09))
		if entry["def"] == _selected_def:
			draw_rect(r, Color.WHITE, false, 2.0)


# --- helpers -----------------------------------------------------------------

func _palette_rect(i: int) -> Rect2:
	return Rect2(_origin.x + float(i) * 34.0, 8.0, 26.0, 22.0)


func _cell_from_pixel(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - _origin.x) / float(CELL)), floori((p.y - _origin.y) / float(CELL)))


func _cell_center(cell: Vector2i) -> Vector2:
	return _origin + Vector2(cell) * float(CELL) + Vector2(CELL, CELL) * 0.5


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


func _buf(d: Dictionary) -> String:
	if d.is_empty():
		return "—"
	var parts: PackedStringArray = []
	for k: StringName in d:
		parts.append("%s %d" % [k, int(d[k])])
	return "  ".join(parts)
