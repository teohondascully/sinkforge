extends SceneTree

## A CONTACT SHEET OF EVERY MACHINE, casing and glyph together, so the family can be COMPARED rather than
## described. The sibling of `tools/icon_sheet.gd` and it exists for the same reason: T3.2 asks to bring
## SPUR, DRILL and GENERATOR "up to DRIFT RIG", which is a comparative claim about nineteen drawings, and a
## comparative claim is the one thing a per-machine assertion cannot make. Counting primitives in the source
## gets you a proxy; the drawings are the subject.
##
## Not a harness layer and not registered as one — it asserts nothing. It is a viewer.
##
## SIZE MATTERS HERE MORE THAN IT DOES FOR ICONS. A machine is drawn one `CELL` wide in the world, and the
## casing's own detail pass is gated on zoom (`world_renderer.gd` `DETAIL_ZOOM`), so a sheet rendered at
## some flattering size answers a question nobody asked. Default is one cell — what the player sees at 1.00x
## zoom — with `SF_MACHINE_PX` to ask for another.
##
## The glyph scale is DERIVED from `SF_MACHINE_PX` and `WorldRenderer.CELL`, never passed in pixels — see the
## note in `Bench._draw`, which is the whole reason the first render of this sheet was unreadable.
##
##     SF_MACHINE_PX=32 SF_SHEET_SCALE=8    one cell, the play size
##     SF_MACHINE_PX=96 SF_SHEET_SCALE=3    the drawing as drawn, for judging detail density
##     SF_MACHINE_ACTIVE=0                  the cold/idle palette instead of the running one

const COLS: int = 6
const SCALE: int = 8
const PAD: int = 4


## An inner class is its own scope and cannot see this script's constants, so the padding is handed to it
## rather than read from `PAD` — which would not compile. Same trap `check_item_reads` records.
class Bench extends Node2D:
	var kind: String
	var col: Color
	var px: float
	var active: bool
	var pad: float

	func _draw() -> void:
		# THE TWO ARGUMENTS BELOW ARE IN DIFFERENT UNITS AND NOTHING IN EITHER SIGNATURE SAYS SO.
		# `draw_machine_casing` takes `cell_px` in PIXELS — `world_renderer.gd:2810` hands it `float(CELL)`.
		# `draw_machine_glyph` takes `s` in CELLS — the same renderer hands it `1.0` for a full-size machine
		# (`world_renderer.gd:1360`), and the HUD reaches the same place via `box.size.y / 20.0` because the
		# glyphs are drawn in a ~20-unit design space. Passing pixels to the second one drew the family at
		# 32x and 96x: every cell of the first sheet was a flat colour fill, which read as an art defect and
		# was a driver defect. Derived from CELL rather than written as 20.0, so it cannot drift from the
		# renderer's own convention.
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
