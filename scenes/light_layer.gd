class_name LightLayer
extends Node2D

## One lighting pass for MainView, painted in world space. It exists so that each pass can carry its own
## blend mode, which a single CanvasItem cannot switch mid-_draw: terrain passes are MIX, the darkness
## pass multiplies, so shadow scales the light already there, and the light pass is ADD. MainView owns all
## the light math; this owns only the canvas, the blend and the redraw. Pure representation.

## MainView's painter (`_paint_darkness` or `_paint_lights`), handed this canvas back when it runs:
## draw_* calls are only valid on the CanvasItem currently inside its own _draw pass.
var painter: Callable


func setup(z: int, paint: Callable, blend: CanvasItemMaterial.BlendMode = CanvasItemMaterial.BLEND_MODE_MIX) -> void:
	z_index = z
	painter = paint
	if blend != CanvasItemMaterial.BLEND_MODE_MIX:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = blend
		material = mat


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
