extends SceneTree

## A CONTACT SHEET OF EVERY ITEM ICON, so a change to one can be LOOKED AT rather than only measured.
## `check_item_reads` answers "are any two of these the same?" and it answers it well, but a glyph can be
## provably distinct from all 26 others and still not read as the thing it is named after. Distinctness is a
## property of a PAIR; legibility is a property of ONE icon and a person, and no pairwise metric can register
## it however many pairs it ranks — the arity is wrong, not the implementation.
##
## Not a harness layer and deliberately not registered as one: it asserts nothing. It is a VIEWER, and the
## reason it is tracked is that it caught a defect no assertion could — the first `rope` glyph measured
## cleanly distinct from all 26 other icons and read as a magnifying glass, two cells from the `scanner`.
##
## RENDER AT THE SIZE THE GAME ACTUALLY DRAWS, which is not the size the suite measures. `Visuals.draw_item`
## is called at **13.0** through most of the HUD, **12.0** in the pack rows and **9.0** for an item lying in
## the world (`world_renderer.gd`, the `draw_item(self, p, 9.0, item)` call); the detail plate is the only large one. `check_item_reads` renders
## at 48 and its constant is commented "roughly a hotbar cell" — it is roughly FOUR of them. A cue that
## exists at 48 and dies at 13 is invisible to that layer AND to a sheet drawn at its default, so the size is
## an env knob and the SMALL sizes are the ones that decide whether a glyph works.
##
##     SF_ICON_PX=13 SF_SHEET_SCALE=8   the hotbar
##     SF_ICON_PX=9  SF_SHEET_SCALE=10  an item on the ground
##     SF_SHEET_OUT=/path/sheet.png     where to write (default res://_icon_sheet.png)

const ITEMS: Array[StringName] = [
	&"earth", &"stone", &"gravel", &"shale", &"deepslate", &"sealrock",
	&"ore", &"rich_ore", &"iron", &"ingot", &"iron_ingot", &"plate", &"gear",
	&"coal", &"wood", &"scanner", &"sapling", &"rope", &"torch",
	&"wood_pickaxe", &"stone_pickaxe", &"iron_pickaxe", &"wood_axe",
	&"broad_bit", &"sinker_bit", &"lance_bit", &"wedge_bit",
]
const ICON: float = 48.0        ## default draw size; override with SF_ICON_PX
const COLS: int = 7
const SCALE: int = 3            ## nearest-neighbour blow-up; override with SF_SHEET_SCALE

var _icon_px: float = ICON
var _cell: int = 64


class Glyph extends Node2D:
	var item: StringName
	var at: Vector2
	var icon: float

	func _draw() -> void:
		Visuals.draw_item(self, at, icon, item)


func _initialize() -> void:
	_icon_px = _env_f("SF_ICON_PX", ICON)
	var scale: int = int(_env_f("SF_SHEET_SCALE", float(SCALE)))
	# Padding round the glyph so neighbours cannot be read as one shape, and a floor so a 9px icon still
	# lands in a cell big enough to see its own edges.
	_cell = maxi(int(ceil(_icon_px)) + 6, 16)
	var rows: int = int(ceil(float(ITEMS.size()) / float(COLS)))
	var sheet := Image.create(COLS * _cell, rows * _cell, false, Image.FORMAT_RGBA8)
	# A mid grey, not black and not white: half these icons are dark rock and half are pale metal, and either
	# extreme would flatter one group and hide the other.
	sheet.fill(Color(0.22, 0.23, 0.26))
	for i: int in ITEMS.size():
		var img: Image = await _render(ITEMS[i])
		img.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, Vector2i(_cell, _cell)),
			Vector2i((i % COLS) * _cell, int(i / COLS) * _cell))
	sheet.resize(sheet.get_width() * scale, sheet.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var out: String = str(OS.get_environment("SF_SHEET_OUT"))
	if out.is_empty():
		out = "res://_icon_sheet.png"
	sheet.save_png(out)
	print("  %d items at %.0f px in a %d px cell, x%d -> %s"
		% [ITEMS.size(), _icon_px, _cell, scale, out])
	quit(0)


func _env_f(key: String, fallback: float) -> float:
	var raw: String = str(OS.get_environment(key))
	if raw.is_empty() or not raw.is_valid_float():
		return fallback
	return float(raw)


func _render(item: StringName) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(_cell, _cell)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var g := Glyph.new()
	g.item = item
	g.at = Vector2(_cell, _cell) * 0.5
	g.icon = _icon_px
	vp.add_child(g)
	get_root().add_child(vp)
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	return img
