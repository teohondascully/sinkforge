class_name LightLayer
extends Node2D

## A thin REPRESENTATION-layer canvas that paints one lighting pass for MainView in world space. It
## exists only so each pass gets its OWN blend mode (you can't switch blend mid-_draw on one CanvasItem):
## terrain passes are ordinary MIX, the DARKNESS pass MULTIPLIES (shadow scales the light already there,
## which is what shadow physically does — see WorldRenderer's veil notes), and the LIGHT pass is ADD
## (warm pools punching back through). MainView owns all the light MATH; this just provides the canvas +
## blend + redraw. Pure visuals — delete it and the sim numbers are identical.

## MainView sets this to its painter (`_paint_darkness` / `_paint_lights`); we hand it back this canvas
## so its draw_* calls land on US (they're only valid on the CanvasItem currently in its _draw pass).
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
