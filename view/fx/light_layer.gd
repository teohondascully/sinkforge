class_name LightLayer
extends Node2D

## One lighting pass, painted in world space. It exists so that each pass can carry its own blend mode,
## which a single CanvasItem cannot switch mid-`_draw`: terrain passes are MIX, the darkness pass
## multiplies so shadow scales the light already there, and the light pass is ADD. **This owns only the
## canvas, the blend and the redraw** -- the light math belongs to whatever drives it.
##
## Lifted unchanged from `legacy/scenes/light_layer.gd` (`docs/DECISIONS_LEDGER.md` D0227), whose own
## header said "MainView owns all the light math" and whose migration-map row carries a
## `[REASON CORRECTED]` note saying the same thing: **lifting this gets the CANVAS, not the lighting.**
##
## NO CONSUMER TODAY, and the thing it would serve does not exist. This build draws in ONE flat `_draw`
## on one CanvasItem with no blend modes anywhere, and `tests/body/material_look.gd` states plainly that
## the shadow veil "is not in Slice 0". The darkness pass and the head-lamp pool live in the coordinator
## rebuild, which is parked. So this file is banked against that work, which is the same shape as the
## one-hop `Visuals` batch the director declined for being banked -- flagged rather than quietly landed,
## because the two decisions ought to agree and only the director can say which way.

## The painter, handed this canvas back when it runs: `draw_*` calls are only valid on the CanvasItem
## currently inside its own `_draw` pass, so the callable receives the node rather than capturing it.
var painter: Callable


func setup(z: int, paint: Callable,
		blend: CanvasItemMaterial.BlendMode = CanvasItemMaterial.BLEND_MODE_MIX) -> void:
	z_index = z
	painter = paint
	if blend != CanvasItemMaterial.BLEND_MODE_MIX:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = blend
		material = mat


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
