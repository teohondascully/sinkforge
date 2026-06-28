class_name Hud
extends Node2D

## Screen-fixed HUD for P2·S1a. Lives under a CanvasLayer so the follow-camera does NOT scroll it.
## Reads the sim only (the running OUTPUT total) and shows the controls. Drawn in screen space.

const CANVAS := Vector2(640, 360)

var sim: FactorySim
var _font: Font = ThemeDB.fallback_font
var paused_getter: Callable


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_string(_font, Vector2(10, 22), "OUTPUT   %s" % _buf(sim.sink),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.80, 0.32))
	draw_string(_font, Vector2(10, CANVAS.y - 12), "← → / A D  move      SPACE / W  jump      P  pause",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.75, 0.78, 0.85))
	if paused_getter.is_valid() and bool(paused_getter.call()):
		draw_string(_font, Vector2(CANVAS.x - 110, 22), "PAUSED (P)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.72, 0.30))


func _buf(d: Dictionary) -> String:
	if d.is_empty():
		return "—"
	var parts: PackedStringArray = []
	for k: StringName in d:
		parts.append("%s %d" % [k, int(d[k])])
	return "  ".join(parts)
