class_name MainView
extends Node2D

## Representation layer for Prototype 1. OWNS a FactorySim (game-session-owns-sim rule, see
## docs/RISKS.md) and draws it. It only READS sim state — it never writes back. Delete this
## node and the production numbers would be identical; the sim is the source of truth.
##
## `sim` is exposed read-only for tests/tools (e.g. the capture tool fast-forwards it for a
## deterministic screenshot). Only this node should advance it.
##
## DESIGN-OPEN (presentation, NOT canon — collect into PLAYTEST_NOTES when playable):
##  - Camera: fixed, no pan/zoom yet. Panning/zoom behaviour is wide open.
##  - Visual language: machines + numbers as placeholder rects/text. No falling-item sprites
##    yet (next slice). How flow is shown (sprites vs streams vs gauges) is undecided.
##  - Layout/colours: arbitrary placeholders, no style commitment.

const CANVAS := Vector2(640, 360)
const CELL: int = 32
const CHAIN_X: int = 296
const TOP_Y: int = 48
const GAP_Y: int = 88

var sim: FactorySim
var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	sim = FactorySim.new()
	sim.add_machine(MachineState.new(load("res://src/data/machines/ore_vent.tres")))
	sim.add_machine(MachineState.new(load("res://src/data/machines/processor.tres")))


func _process(delta: float) -> void:
	sim.advance(delta)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, CANVAS), Color(0.10, 0.11, 0.13))
	for i: int in sim.machines.size():
		_draw_machine(i, sim.machines[i])
	_draw_sink()


func _draw_machine(index: int, machine: MachineState) -> void:
	var y: int = TOP_Y + index * GAP_Y
	draw_rect(Rect2(CHAIN_X, y, CELL, CELL), Color(0.30, 0.55, 0.75))
	var recipe: RecipeDef = machine.def.recipe
	if recipe != null and recipe.time > 0.0:
		var frac: float = clampf(machine.progress / recipe.time, 0.0, 1.0)
		draw_rect(Rect2(CHAIN_X, y + CELL + 3, float(CELL) * frac, 4), Color(0.40, 0.90, 0.45))
	var label: String = "%s   in %s   out %s" % [
		machine.def.display_name, _buf(machine.input_buffer), _buf(machine.output_buffer)]
	draw_string(_font, Vector2(CHAIN_X + CELL + 14, y + 16), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.88, 0.90, 0.94))


func _draw_sink() -> void:
	var y: int = TOP_Y + sim.machines.size() * GAP_Y
	draw_string(_font, Vector2(CHAIN_X - 56, y + 16), "OUTPUT   %s" % _buf(sim.sink),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.80, 0.32))


func _buf(d: Dictionary) -> String:
	if d.is_empty():
		return "—"
	var parts: PackedStringArray = []
	for k: StringName in d:
		parts.append("%s %d" % [k, int(d[k])])
	return "  ".join(parts)
