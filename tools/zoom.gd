extends SceneTree
## ZOOM — magnify a region of a capture so a human (or a vision agent) can judge pixels.
##
## The captures in `capture_moments.gd` are 1920x1080 and the miner is 34 rows tall, so the thing we
## most often need to look at is roughly 1% of the frame. This crops a box and scales it up with
## NEAREST so the art is judged as authored, not as a bilinear smear.
##
##   godot --headless --path . --script res://tools/zoom.gd -- _moment_boot.png 960 520 160 120 6
##   godot --headless --path . --script res://tools/zoom.gd -- _moment_boot.png          # auto-centre
##
## Args: <png> [cx cy w h] [scale].  With no box it takes a 240x160 box at the frame centre, which is
## where the play agent parks the body in most moments.

const DEFAULT_W: int = 240
const DEFAULT_H: int = 160
const DEFAULT_SCALE: int = 6
const OUT_SUFFIX: String = "_zoom"

func _initialize() -> void:
	var argv: PackedStringArray = OS.get_cmdline_user_args()
	if argv.is_empty():
		printerr("usage: zoom.gd -- <png> [cx cy w h] [scale]")
		quit(1)
		return

	var path: String = argv[0]
	var img: Image = Image.load_from_file(path)
	if img == null:
		printerr("cannot read ", path)
		quit(1)
		return

	var box: Rect2i = _box(argv, img.get_size())
	var scale: int = int(argv[5]) if argv.size() > 5 else (int(argv[1]) if argv.size() == 2 else DEFAULT_SCALE)
	scale = maxi(1, scale)

	var cut: Image = img.get_region(box)
	cut.resize(cut.get_width() * scale, cut.get_height() * scale, Image.INTERPOLATE_NEAREST)

	var out: String = path.get_basename() + OUT_SUFFIX + ".png"
	cut.save_png(out)
	print("%s -> %s  (%dx%d at %s, x%d)" % [path, out, box.size.x, box.size.y, box.position, scale])
	quit(0)

## Clamp the requested box to the frame so a bad centre crops rather than errors.
func _box(argv: PackedStringArray, frame: Vector2i) -> Rect2i:
	var w: int = DEFAULT_W
	var h: int = DEFAULT_H
	var centre: Vector2i = frame / 2
	if argv.size() >= 5:
		centre = Vector2i(int(argv[1]), int(argv[2]))
		w = maxi(1, int(argv[3]))
		h = maxi(1, int(argv[4]))
	w = mini(w, frame.x)
	h = mini(h, frame.y)
	var pos: Vector2i = centre - Vector2i(w, h) / 2
	pos.x = clampi(pos.x, 0, frame.x - w)
	pos.y = clampi(pos.y, 0, frame.y - h)
	return Rect2i(pos, Vector2i(w, h))
