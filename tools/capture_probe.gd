extends SceneTree

## A LUMINANCE PROBE OVER A SEAT CAPTURE (D0407). Reads a PNG the seat's shutter wrote and reports, for a
## disc about a point, the mean luminance and mean colour, so a claim like "the beacon reads from ten
## metres in the dark" is a number against a control and not a glance. Points are given in METRES from
## the body's own screen position, which the shutter prints as `body_cell`; at the seat's default zoom of 2
## over the 1280x720 viewport stretched to 1920x1080, one metre is 48 capture pixels (16 world px x 2 x 1.5).
##
##   godot --headless --path . -s tools/capture_probe.gd -- --png=PATH --body=960,540 \
##       [--zoom=2.0] --at=NAME:dx,dy[,r_m[,r_inner_m]] [--at=...]
##
## With `r_inner_m` the disc is an annulus, so a light can be read apart from the sprite that casts it.
##
## Each `--at` prints one line: `PROBE name lum=.. r=.. g=.. b=.. amber=..  n=..` where `amber` is the
## mean of (r - b), positive on a warm cast and negative on the deep's blue. Compare two `--at` lines
## rather than reading one: the control travels inside the capture.

const PX_PER_WORLD_PX: float = 1.5     # 1920 / 1280
const WORLD_PX_PER_M: float = 16.0


func _initialize() -> void:
	var png: String = ""
	var body := Vector2(960, 540)
	var zoom: float = 2.0
	var probes: Array[String] = []
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--png="):
			png = a.substr(6)
		elif a.begins_with("--body="):
			var p: PackedStringArray = a.substr(7).split(",")
			body = Vector2(float(p[0]), float(p[1]))
		elif a.begins_with("--zoom="):
			zoom = float(a.substr(7))
		elif a.begins_with("--at="):
			probes.append(a.substr(5))
	var img: Image = Image.load_from_file(png)
	if img == null or img.is_empty():
		print("PROBE_ERROR cannot read %s" % png)
		quit(2)
		return
	var px_per_m: float = WORLD_PX_PER_M * zoom * PX_PER_WORLD_PX
	for spec: String in probes:
		_probe(img, body, px_per_m, spec)
	quit()


func _probe(img: Image, body: Vector2, px_per_m: float, spec: String) -> void:
	var name_and_rest: PackedStringArray = spec.split(":")
	var parts: PackedStringArray = name_and_rest[1].split(",")
	var r_m: float = float(parts[2]) if parts.size() > 2 else 1.7
	var r_in_px: float = (float(parts[3]) if parts.size() > 3 else 0.0) * px_per_m
	var centre: Vector2 = body + Vector2(float(parts[0]), float(parts[1])) * px_per_m
	var r_px: float = r_m * px_per_m
	var sum := Vector3.ZERO
	var lum: float = 0.0
	var n: int = 0
	for y: int in range(maxi(0, int(centre.y - r_px)), mini(img.get_height(), int(centre.y + r_px) + 1)):
		for x: int in range(maxi(0, int(centre.x - r_px)), mini(img.get_width(), int(centre.x + r_px) + 1)):
			var d: float = Vector2(x, y).distance_to(centre)
			if d > r_px or d < r_in_px:
				continue
			var c: Color = img.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
			lum += c.get_luminance()
			n += 1
	if n == 0:
		print("PROBE %s off the capture" % name_and_rest[0])
		return
	var mean: Vector3 = sum / float(n)
	print("PROBE %s lum=%.4f r=%.3f g=%.3f b=%.3f amber=%.4f n=%d centre=(%d,%d) r_px=%d" % [
		name_and_rest[0], lum / float(n), mean.x, mean.y, mean.z, mean.x - mean.z, n, int(centre.x), int(centre.y), int(r_px)])
