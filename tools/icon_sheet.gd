extends SceneTree

## A CONTACT SHEET OF EVERY ITEM ICON, so a change to one can be LOOKED AT rather than only measured.
## `check_item_reads` answers "are any two of these the same?" and it answers it well, but a glyph can be
## provably distinct from all 26 others and still not read as the thing it is named after. Distinctness is a
## property of a pair; legibility is a property of one icon and a person. This renders the set to a PNG.
## Not a harness layer and deliberately not registered as one: it asserts nothing. It is a VIEWER, and the
## reason it is tracked is that it caught a defect no assertion could — the first rope glyph measured cleanly
## distinct from all 26 other icons and read as a magnifying glass, two cells from the scanner.

const ITEMS: Array[StringName] = [
	&"earth", &"stone", &"gravel", &"shale", &"deepslate", &"sealrock",
	&"ore", &"rich_ore", &"iron", &"ingot", &"iron_ingot", &"plate", &"gear",
	&"coal", &"wood", &"scanner", &"sapling", &"rope", &"torch",
	&"wood_pickaxe", &"stone_pickaxe", &"iron_pickaxe", &"wood_axe",
	&"broad_bit", &"sinker_bit", &"lance_bit", &"wedge_bit",
]
const CANVAS: int = 64
const ICON: float = 48.0
const COLS: int = 7
const SCALE: int = 3            ## nearest-neighbour blow-up, so the 16px-slot cues stay honest but visible


class Glyph extends Node2D:
	var item: StringName
	var at: Vector2
	var icon: float

	func _draw() -> void:
		Visuals.draw_item(self, at, icon, item)


func _initialize() -> void:
	var rows: int = int(ceil(float(ITEMS.size()) / float(COLS)))
	var sheet := Image.create(COLS * CANVAS, rows * CANVAS, false, Image.FORMAT_RGBA8)
	# A mid grey, not black and not white: half these icons are dark rock and half are pale metal, and either
	# extreme would flatter one group and hide the other.
	sheet.fill(Color(0.22, 0.23, 0.26))
	for i: int in ITEMS.size():
		var img: Image = await _render(ITEMS[i])
		img.convert(Image.FORMAT_RGBA8)
		var dst := Vector2i((i % COLS) * CANVAS, int(i / COLS) * CANVAS)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, Vector2i(CANVAS, CANVAS)), dst)
		print("  %2d  %s" % [i, ITEMS[i]])
	sheet.resize(sheet.get_width() * SCALE, sheet.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	var out: String = str(OS.get_environment("SF_SHEET_OUT"))
	if out.is_empty():
		out = "res://_icon_sheet.png"
	sheet.save_png(out)
	print("  wrote %s  (%d items, %d cols, x%d)" % [out, ITEMS.size(), COLS, SCALE])
	quit(0)


func _render(item: StringName) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(CANVAS, CANVAS)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var g := Glyph.new()
	g.item = item
	g.at = Vector2(CANVAS, CANVAS) * 0.5
	g.icon = ICON
	vp.add_child(g)
	get_root().add_child(vp)
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	return img
