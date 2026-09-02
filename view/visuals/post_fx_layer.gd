class_name PostFxLayer
extends CanvasLayer

## THE LENS. A full-screen pass carrying legacy's vignette, film grain, chromatic aberration and palette
## grade, ported from `legacy/scenes/post_fx.gdshader` (85 lines, lifted whole). `docs/PORT_ORDER.md` V3;
## `docs/DECISIONS_LEDGER.md` D0328.
##
## Legacy's own description of what it buys: it "makes the framebuffer read as a shot through real glass
## rather than flat pixels", and on top of the lens sits a grade — a filmic S-curve plus a split-tone
## pulling shadows toward the underworld's cool blue-black and highlights toward the lamp's warm gold —
## "so every material, light and UI colour passes through one shared grade."
##
## **BETWEEN THE WORLD AND THE HUD, and that placement is the whole design.** Godot draws `CanvasLayer`s
## in ascending `layer` order, so this sits above every world painter and below `HudLayer`: the world gets
## the lens and the UI stays crisp. Legacy says the same in its own header — "runs on a full-screen
## ColorRect on a CanvasLayer below the HUD".
##
## **ONE ADAPTATION, AND IT IS NOT COSMETIC.** Legacy seeds its grain from `TIME`, a wall clock. This
## project's screenshot-comparison discipline (`docs/QUALITY.md`) rests on the renderer being a function
## of STATE — two captures of the same tick must be byte-comparable — and a wall-clock grain makes every
## capture differ, which would quietly void every capture-based verdict this repository takes. D0277
## already ruled this once for `Frame.anim_time`: a cosmetic TICK COUNTER, never a wall clock. The shader
## takes an `anim_time` uniform and this layer feeds it that same clock, so the grain still moves for a
## player watching it and still reproduces exactly for a capture.

## Above every world painter, below `HudLayer.HUD_CANVAS_LAYER`. Asserted against it in
## `tests/test_post_fx.gd` rather than left as a comment, because the two numbers are in different files
## and the failure — a graded, grain-covered HUD — is the kind of thing that reads as "the UI looks a bit
## soft" rather than as a bug.
const POST_FX_CANVAS_LAYER: int = 5

var _rect: ColorRect = null
var _material: ShaderMaterial = null


## Builds the pass. Returns false when the shader cannot be loaded, rather than mounting a ColorRect with
## no material — which would paint an opaque rectangle over the entire world, a far worse failure than no
## lens at all.
func setup() -> bool:
	layer = POST_FX_CANVAS_LAYER
	var shader: Shader = load("res://view/visuals/post_fx.gdshader") as Shader
	if shader == null:
		return false
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect = ColorRect.new()
	_rect.material = _material
	# FULL-SCREEN AND CLICK-THROUGH. `SCREEN_UV` is only the whole screen if the rect actually covers it,
	# and a Control that eats input would silently swallow every mouse event the aim verb needs -- which
	# would present as "mining stopped working" with nothing pointing at a renderer.
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	return true


## Feed the deterministic clock. Called once per rendered tick by the coordinator; see the header for why
## this is not `TIME`.
func set_anim_time(seconds: float) -> void:
	if _material != null:
		_material.set_shader_parameter(&"anim_time", seconds)


## Rack the world out of focus behind a modal, in mip levels. Legacy drove this from its Bazaar counter —
## which GDD §9 kills by name — so **nothing sets it in this build yet** and it rests at 0.0, which is the
## shader's own no-op branch. Kept rather than stripped because the mechanism is not the Bazaar: legacy's
## note is that dimming the world "38% and leaving it perfectly sharp said nothing about the panel being
## in front of anything", and that finding applies to any modal this game grows.
func set_defocus(mips: float) -> void:
	if _material != null:
		_material.set_shader_parameter(&"defocus", maxf(mips, 0.0))
