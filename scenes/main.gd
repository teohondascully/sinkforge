class_name MainView
extends Node2D

## Representation + input layer for Prototype 1. OWNS a FactorySim (game-session-owns-sim rule,
## see docs/RISKS.md), advances it, draws it, and translates mouse/keys into sim placement ops.
## It only READS sim production state — it never writes buffers/progress/sink. Placement goes
## through the sim's public place/remove API. Delete this node and the numbers are unchanged.
##
## `sim` is exposed read-only for tests/tools. Only this node advances it.
##
## DESIGN-OPEN (presentation/controls, NOT canon — collect into PLAYTEST_NOTES when playable):
##  - Grid: 12x9, centred, faint lines. Size/visibility/"dug earth vs blueprint" all open.
##  - Build UX: click palette swatch to select, left-click places, right-click removes,
##    space pauses. Drag-place, hotkeys, ghost-preview, etc. all undecided.
##  - Camera: fixed, no pan/zoom. Visual language: placeholder rects + counts; no falling-item
##    sprites yet (next slice). Colours arbitrary.

const CANVAS := Vector2(640, 360)
const CELL: int = 32

var sim: FactorySim
var _font: Font = ThemeDB.fallback_font
var _origin: Vector2
var _palette: Array[Dictionary] = []
var _selected_def: MachineDef
var _paused: bool = false


func _ready() -> void:
	_origin = Vector2(
		(CANVAS.x - float(FactorySim.GRID_COLS * CELL)) * 0.5,
		(CANVAS.y - float(FactorySim.GRID_ROWS * CELL)) * 0.5)
	sim = FactorySim.new()
	var vent: MachineDef = load("res://src/data/machines/ore_vent.tres")
	var processor: MachineDef = load("res://src/data/machines/processor.tres")
	_palette = [
		{"def": vent, "color": Color(0.82, 0.45, 0.20)},
		{"def": processor, "color": Color(0.30, 0.55, 0.75)},
	]
	_selected_def = vent
	# Initial demo placement so there is something running on open (provisional).
	sim.place_machine(vent, Vector2i(6, 1))
	sim.place_machine(processor, Vector2i(6, 4))


func _process(delta: float) -> void:
	if not _paused:
		sim.advance(delta)
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


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.10, 0.11, 0.13))
	_draw_grid()
	for machine: MachineState in sim.machines:
		_draw_machine(machine)
	_draw_output()
	_draw_palette()
	if _paused:
		draw_string(_font, Vector2(_origin.x, 22), "PAUSED  (space)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.72, 0.30))


func _draw_grid() -> void:
	var line_col := Color(1, 1, 1, 0.06)
	var w: float = float(FactorySim.GRID_COLS * CELL)
	var h: float = float(FactorySim.GRID_ROWS * CELL)
	for c: int in FactorySim.GRID_COLS + 1:
		var x: float = _origin.x + float(c * CELL)
		draw_line(Vector2(x, _origin.y), Vector2(x, _origin.y + h), line_col)
	for r: int in FactorySim.GRID_ROWS + 1:
		var y: float = _origin.y + float(r * CELL)
		draw_line(Vector2(_origin.x, y), Vector2(_origin.x + w, y), line_col)


func _draw_machine(machine: MachineState) -> void:
	var pos: Vector2 = _origin + Vector2(machine.cell) * float(CELL)
	var recipe: RecipeDef = machine.def.recipe
	var is_source: bool = recipe != null and recipe.inputs.is_empty()
	draw_rect(Rect2(pos, Vector2(CELL, CELL)),
		Color(0.82, 0.45, 0.20) if is_source else Color(0.30, 0.55, 0.75))
	if recipe != null and recipe.time > 0.0:
		var frac: float = clampf(machine.progress / recipe.time, 0.0, 1.0)
		draw_rect(Rect2(pos.x, pos.y + float(CELL) - 3.0, float(CELL) * frac, 3.0),
			Color(0.40, 0.90, 0.45))
	var held: int = 0
	for v: int in machine.input_buffer.values():
		held += v
	if held > 0:
		draw_string(_font, Vector2(pos.x + 4, pos.y + 13), str(held),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.05, 0.05, 0.08))


func _draw_output() -> void:
	var y: float = _origin.y + float(FactorySim.GRID_ROWS * CELL) + 20.0
	draw_string(_font, Vector2(_origin.x, y), "OUTPUT   %s" % _buf(sim.sink),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.80, 0.32))


func _draw_palette() -> void:
	for i: int in _palette.size():
		var entry: Dictionary = _palette[i]
		var r: Rect2 = _palette_rect(i)
		draw_rect(r, entry["color"])
		if entry["def"] == _selected_def:
			draw_rect(r, Color.WHITE, false, 2.0)


# --- helpers -----------------------------------------------------------------

func _palette_rect(i: int) -> Rect2:
	return Rect2(12.0 + float(i) * 40.0, 12.0, 32.0, 32.0)


func _cell_from_pixel(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - _origin.x) / float(CELL)), floori((p.y - _origin.y) / float(CELL)))


func _buf(d: Dictionary) -> String:
	if d.is_empty():
		return "—"
	var parts: PackedStringArray = []
	for k: StringName in d:
		parts.append("%s %d" % [k, int(d[k])])
	return "  ".join(parts)
