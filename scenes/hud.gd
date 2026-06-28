class_name Hud
extends Node2D

## Screen-fixed HUD for P2·S1a. Lives under a CanvasLayer so the follow-camera does NOT scroll it.
## Reads the sim only (the running OUTPUT total) and shows the controls. Drawn in screen space.

const CANVAS := Vector2(640, 360)

var sim: FactorySim
var _font: Font = ThemeDB.fallback_font
var paused_getter: Callable
## The hand-build palette (set by MainView): the machine names you can place, and which is selected.
var palette_names: PackedStringArray = []
var selected_getter: Callable


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_string(_font, Vector2(10, 22), "OUTPUT   %s" % _buf(sim.sink),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.80, 0.32))
	draw_string(_font, Vector2(10, 42), "PACK     %s" % _buf(sim.inventory),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.90, 0.66, 0.40))
	_draw_palette()
	draw_string(_font, Vector2(10, CANVAS.y - 12),
		"move A/D   jump SPACE   mine LMB   build RMB   select 1/2   deposit E   pause P",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.78, 0.85))
	if paused_getter.is_valid() and bool(paused_getter.call()):
		draw_string(_font, Vector2(CANVAS.x - 110, 22), "PAUSED (P)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.72, 0.30))


## The build palette, with the selected machine boxed/brightened — so RMB-to-build has a visible
## current choice (1/2 cycle it). Drawn in screen space under the PACK readout.
func _draw_palette() -> void:
	if palette_names.is_empty():
		return
	var sel: int = int(selected_getter.call()) if selected_getter.is_valid() else 0
	var x: float = 10.0
	var y: float = 62.0
	draw_string(_font, Vector2(x, y), "BUILD", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.62, 0.78, 0.68))
	x += 52.0
	for i: int in palette_names.size():
		var label: String = "%d %s" % [i + 1, palette_names[i]]
		var w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var on: bool = i == sel
		if on:
			draw_rect(Rect2(x - 4.0, y - 13.0, w + 8.0, 18.0), Color(0.30, 0.50, 0.34, 0.55))
		draw_string(_font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.60, 0.96, 0.62) if on else Color(0.50, 0.55, 0.62))
		x += w + 18.0


func _buf(d: Dictionary) -> String:
	if d.is_empty():
		return "—"
	var parts: PackedStringArray = []
	for k: StringName in d:
		parts.append("%s %d" % [k, int(d[k])])
	return "  ".join(parts)
