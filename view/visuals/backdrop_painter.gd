class_name BackdropPainter
extends RefCounted

## THE FLAT FILL BEHIND EVERYTHING, tinted toward the band the body is in. Lifted out of
## `tests/body/reveal_scene.gd`'s own `_draw` at D0276, unchanged in what it paints.
##
## **IT HAD TO MOVE, and the reason is a bug this file exists to make impossible.** The fill is opaque and
## spans 12,000px. While the scene drew terrain in the same `_draw`, order alone kept the terrain on top.
## The moment terrain became a painter at `z_index = -50`, the scene's own `_draw` at z 0 covered it: the
## first capture after that change showed the HUD, the miner and the cracks over a flat empty grey, and
## **every one of the 48 suites passed**. Nothing asserted that a painter's output reached the screen,
## because nothing can — Godot exposes no way to read back a `CanvasItem`'s draw commands.
##
## This is D0244's finding one layer down, and D0244's comment was sitting three lines above the bug:
## "`--sky` REPLACES this fill rather than layering under it... the first capture showed flat COLOR_BG
## above the terrain and looked exactly like a painter that had not run. Found by looking at the image,
## not by reasoning about z_index, which was correct all along." The z_index was correct again. What was
## wrong again was which node owned the fill.
##
## As a painter it sits at the bottom of one ordered stack (`tests/body/reveal_view_setup.gd`) instead of
## in a different node's draw call, so "what is behind what" is answerable by reading one list.

## D0189: the ground is tinted toward its band, so depth reads as a change in the WORLD and not only as a
## number in the corner. Kept to 0.10 because legacy's band colours were authored as ANNOUNCEMENT colours
## -- type on a dark plate, every one between 0.44 and 0.96 in its brightest channel -- and are far too
## bright to use as fills at full strength.
const COLOR_BG: Color = Color(0.16, 0.16, 0.18)
const BAND_TINT: float = 0.10

## Big enough to cover any framing the debug flags can produce, including `--wide-view` at its most
## zoomed-out. A rect sized to the camera would be correct and would also have to be recomputed as the
## camera eases; this is a backdrop, and being generous costs one draw call.
const SPAN: float = 12000.0


## The fill colour at a given body row. Separated from `paint` so it is assertable: the tint is the part
## that can be silently wrong (a band lookup off by a row reads as a slightly different grey), and a test
## calling `paint` could only assert that it did not crash.
static func fill_color(look: MaterialLook, body_row: int) -> Color:
	if look == null:
		return COLOR_BG
	return COLOR_BG.lerp(look.band_color(body_row), BAND_TINT)


static func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null:
		return
	ci.draw_rect(Rect2(-SPAN * 0.5, -SPAN * 0.5, SPAN, SPAN),
		fill_color(frame.look, frame.obs.cell.y), true)
