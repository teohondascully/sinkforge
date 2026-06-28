class_name LightLayer
extends Node2D

## A thin REPRESENTATION-layer canvas that paints one lighting pass for MainView in world space. It
## exists only so each pass gets its OWN blend mode (you can't switch blend mid-_draw on one CanvasItem):
## the DARKNESS pass is normal alpha (a shadow veil over the world), the LIGHT pass is additive (warm
## pools that punch back through the veil). MainView owns all the light MATH; this just provides the
## canvas + blend + redraw. Pure visuals — delete it and the sim numbers are identical.

## MainView sets this to its painter (`_paint_darkness` / `_paint_lights`); we hand it back this canvas
## so its draw_* calls land on US (they're only valid on the CanvasItem currently in its _draw pass).
var painter: Callable


func setup(z: int, additive: bool, paint: Callable) -> void:
	z_index = z
	painter = paint
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
