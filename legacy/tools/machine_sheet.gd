extends SceneTree

## A CONTACT SHEET OF EVERY MACHINE, casing and glyph together, so the family can be COMPARED rather than
## described. The sibling of `tools/icon_sheet.gd` and it exists for the same reason: T3.2 asks to bring
## SPUR, DRILL and GENERATOR "up to DRIFT RIG", which is a comparative claim about nineteen drawings, and a
## comparative claim is the one thing a per-machine assertion cannot make. Counting primitives in the source
## gets you a proxy; the drawings are the subject.
##
## Not a harness layer and not registered as one; it asserts nothing. It is a viewer.
##
## SIZE MATTERS HERE MORE THAN IT DOES FOR ICONS. A machine is drawn one `CELL` wide in the world, and the
## casing's own detail pass is gated on zoom (`world_renderer.gd` `DETAIL_ZOOM`), so a sheet rendered at
## some flattering size answers a question nobody asked. Default is one cell, what the player sees at 1.00x
## zoom, with `SF_MACHINE_PX` to ask for another.
##
## The glyph scale is DERIVED from `SF_MACHINE_PX` and `WorldRenderer.CELL`, never passed in pixels; see the
## note in `Bench._draw`, which is the whole reason the first render of this sheet was unreadable.
##
## WHAT THIS SHEET CANNOT BE USED TO JUDGE, above one cell: STROKE WEIGHT. Twenty-one `draw_line` widths in
## `visuals.gd` are absolute rather than multiplied by `s`, in `_drift` and `_crusher` and `_hopper` as much
## as in `_drill` and `_generator`. That is not a bug, because `s` never exceeds 1.0 at any call site in the
## game (the HUD's boxes give 0.65/0.75/0.85, `world_renderer.gd` passes 1.0 at both its
## `Visuals.draw_machine_glyph` call sites, and the veil pass clamps to it),
## so those widths act as a MINIMUM STROKE: relatively thicker as the icon shrinks, which is what keeps a
## hairline alive at 13 pixels. Above `SF_MACHINE_PX = CELL` this sheet leaves the range the game uses and
## every one of those strokes renders proportionally THINNER than it ever does in play. Judging "these look
## spindly" off the 96px sheet would be judging an artefact of the sheet, and the fix it invites, scaling
## all 21, would thin the hotbar icons that the floor exists to protect. The tool says so at runtime.
##
##     SF_MACHINE_PX=32 SF_SHEET_SCALE=8    one cell, the play size
##     SF_MACHINE_PX=96 SF_SHEET_SCALE=3    the drawing as drawn, for judging detail density
##     SF_MACHINE_ACTIVE=0                  the cold/idle palette instead of the running one

const COLS: int = 6
const SCALE: int = 8
const PAD: int = 4

## How many `draw_line` widths in `visuals.gd` are absolute rather than `* s`. Only used to make the
## above-one-cell warning specific; counted with a scan of every draw_line's fourth argument.
const UNSCALED_STROKES: int = 21


## An inner class is its own scope and cannot see this script's constants, so the padding is handed to it
## rather than read from `PAD`, which would not compile. Same trap `check_item_reads` records.
class Bench extends Node2D:
	var kind: String
	var col: Color
	var px: float
	var active: bool
	var pad: float

	func _draw() -> void:
		# THE TWO ARGUMENTS BELOW ARE IN DIFFERENT UNITS. `draw_machine_casing` takes PIXELS,
		# `draw_machine_glyph` takes CELLS, and passing pixels to the second drew the family at 32x and 96x:
		# every cell of the first sheet a flat colour fill, which read as an art defect and was a driver
		# defect.
		#
		# The first note here said neither signature stated so. THAT WAS FALSE and the correction is the useful
		# part. `draw_machine_casing`'s parameter is literally named `cell_px`, and `draw_machine_glyph`
		# carried a docstring reading "scaled by `s` (1.0 = full 32px world icon, smaller for HUD chips)".
		# Both units were documented. The two `static func` lines were read and the four lines above one of
		# them were not, so the unit was inferred from the argument NAME (`s` reads as "size") and from the
		# fact that its neighbour took pixels. So this was not an undocumented API; it was an unread one, and
		# the remedy proposed (add a docstring) was the remedy already in place and already failing.
		#
		# What actually reaches someone at a CALL SITE is the parameter name, because GDScript has no named
		# arguments and the call shows a bare `1.0`. That fix landed in `c256d6e`, renaming the parameter
		# `s` -> `cells`. Derived from CELL here rather than written as 20.0, so this tool cannot drift from
		# the renderer's convention either.
		Visuals.draw_machine_casing(self, Vector2(pad, pad), px, col, active, true, kind)
		Visuals.draw_machine_glyph(self, Vector2(pad + px * 0.5, pad + px * 0.5),
			kind, px / float(WorldRenderer.CELL), active, 0.35, false, 1.0)


func _initialize() -> void:
	var px: float = _env_f("SF_MACHINE_PX", float(WorldRenderer.CELL))
	var scale: int = int(_env_f("SF_SHEET_SCALE", float(SCALE)))
	var active: bool = not str(OS.get_environment("SF_MACHINE_ACTIVE")) == "0"
	var cell: int = int(ceil(px)) + PAD * 2

	# One entry per KIND rather than per id: several ids share a kind and would draw identically.
	var kinds: Array[String] = []
	var colour: Dictionary = {}
	for id: Variant in Visuals.MACHINE_STYLE:
		var e: Dictionary = Visuals.MACHINE_STYLE[id]
		var k: String = str(e.get("kind", ""))
		if k.is_empty() or kinds.has(k):
			continue
		kinds.append(k)
		colour[k] = e.get("color", Color.WHITE) as Color
	kinds.sort()

	var rows: int = int(ceil(float(kinds.size()) / float(COLS)))
	var sheet := Image.create(COLS * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.10, 0.10, 0.12))          # the dark the machines are actually seen against
	for i: int in kinds.size():
		var img: Image = await _render(kinds[i], colour[kinds[i]], px, active, cell)
		img.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, Vector2i(cell, cell)),
			Vector2i((i % COLS) * cell, int(i / COLS) * cell))
	sheet.resize(sheet.get_width() * scale, sheet.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var out: String = str(OS.get_environment("SF_SHEET_OUT"))
	if out.is_empty():
		out = "res://_machine_sheet.png"
	sheet.save_png(out)
	print("  %d kinds at %.0f px (%s), x%d -> %s"
		% [kinds.size(), px, "running" if active else "idle", scale, out])
	if px > float(WorldRenderer.CELL):
		# Not a warning about the render, which is correct; a warning about what may be READ off it.
		print("  NOTE: %.0f px is %.2fx the %d px cell, so glyph scale is %.2f and the game never exceeds"
			% [px, px / float(WorldRenderer.CELL), WorldRenderer.CELL, px / float(WorldRenderer.CELL)])
		print("        1.0. The %d absolute stroke widths in visuals.gd render %.2fx thinner here than in"
			% [UNSCALED_STROKES, px / float(WorldRenderer.CELL)])
		print("        play. Judge silhouette, colour and density off this sheet; judge stroke weight at 32.")
	print("  order: %s" % ", ".join(kinds))
	quit(0)


func _env_f(key: String, fallback: float) -> float:
	var raw: String = str(OS.get_environment(key))
	if raw.is_empty() or not raw.is_valid_float():
		return fallback
	return float(raw)


func _render(kind: String, col: Color, px: float, active: bool, cell: int) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(cell, cell)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var b := Bench.new()
	b.kind = kind
	b.col = col
	b.px = px
	b.active = active
	b.pad = float(PAD)
	vp.add_child(b)
	get_root().add_child(vp)
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	return img
