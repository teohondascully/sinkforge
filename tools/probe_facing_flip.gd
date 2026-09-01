extends Node2D

## WHERE THE MINER ACTUALLY LANDS WHEN IT TURNS -- measured in PIXELS, headed, because the defect is a
## disagreement between `MinerLook.draw_sprite`'s rect arithmetic and Godot's own convention for a
## negative-width `Rect2`, and rect arithmetic cannot register that. A unit test asserting the rect spans
## `[c - w/2, c + w/2]` PASSES on the broken code: `Rect2(c + w/2, -w)` and `Rect2(c - w/2, +w)` describe
## the same interval to a reader and different pixels to the rasterizer. So this probe reads the frame.
##
## It draws the SAME texture at the SAME centre twice, one band per facing, and reports the horizontal
## bounding box of drawn pixels in each band. A correct flip leaves both boxes centred on the same x.
##
##   godot --path . tools/probe_facing_flip.tscn
##
## Headed on purpose: `tools/capture_moments.sh` records that the headless renderer returns a null image
## here, so a `--headless` run of this would measure a known-broken path rather than a flip.

const CENTRE_X: float = 320.0
const ROW_LEFT: float = 120.0    ## band centres; far enough apart that a 32px jump cannot cross bands
const ROW_RIGHT: float = 260.0
const BAND_HALF: float = 60.0
const BODY_HEIGHT_PX: int = 40   ## Body.HEIGHT_PX, restated so this probe needs no `sim/` type

var _tex: Texture2D = null
## Set by any check that fails, and turned into the process exit code. A probe that printed FAIL and
## exited 0 would be usable by a human and invisible to CI, which is how a guard ends up running
## somewhere nobody looks.
var _failed: bool = false


func _ready() -> void:
	# EXACTLY the base resolution, so the canvas->image scale is 1.0 and a canvas pixel is an image
	# pixel. The default window is a 1.5x upscale of a 1280x720 target: under nearest filtering that
	# maps canvas pixels to image pixels 2,1,2,1..., which is asymmetric by construction and put about a
	# pixel of false skew into the mirror check. Shrinking the window is not an option either -- the
	# first draft used 640x400 and measured the downscale. Match the target and the confound is gone.
	get_window().size = Vector2i(1280, 720)
	_tex = MinerLook.resolve("miner_idle")
	if _tex == null:
		print("probe_facing_flip: FAIL - no miner texture resolved; the sprite path is not live here")
		get_tree().quit(1)
		return
	print("probe_facing_flip: texture %dx%d" % [_tex.get_width(), _tex.get_height()])
	_report_model()
	queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_report_pixels()
	get_tree().quit(1 if _failed else 0)


func _draw() -> void:
	# The WHOLE viewport, not a hand-sized rect: the first draft filled 640x400 and the untouched
	# remainder of the render target came back as clear-colour, which the span scan then counted as drawn
	# pixels and reported as a sprite spanning the full width. The background has to be something this
	# file put there, everywhere it looks.
	draw_rect(get_viewport_rect(), Color.BLACK, true)
	MinerLook.draw_sprite(self, _tex, Vector2(CENTRE_X, ROW_LEFT), BODY_HEIGHT_PX, -1)
	MinerLook.draw_sprite(self, _tex, Vector2(CENTRE_X, ROW_RIGHT), BODY_HEIGHT_PX, 1)


## The span the placement asks for, before any flip. Deliberately does NOT restate `draw_sprite`'s flip
## arithmetic: a second copy here would be a probe that agrees with itself, and the whole finding is that
## the arithmetic and the rasterizer disagree. `dest_rect` is read from the real file; the flip is left
## for the pixels to answer.
func _report_model() -> void:
	var dst: Rect2 = MinerLook.dest_rect(_tex, BODY_HEIGHT_PX)
	dst.position += Vector2(CENTRE_X, ROW_LEFT)
	print("probe_facing_flip: unflipped placement spans x %.1f..%.1f (centre %.1f)"
		% [dst.position.x, dst.position.x + dst.size.x, dst.position.x + dst.size.x * 0.5])
	_report_turn_sequence()


## THE DIRECTOR'S OWN TEST, printed as a list: turn right, turn left, turn right, and read off where the
## miner ended up each time. The body never moves -- only `facing` alternates -- so every row must show
## the same span. A row that walks is the defect, and the pre-fix code alternates 304..336 / 336..368
## down the column.
##
## These are the rects the rasterizer is handed, resolved through `drawn_span`, so no window is needed to
## read them; the pixel bands below are what earn `drawn_span` the right to be believed.
func _report_turn_sequence() -> void:
	var spans: Array[Vector2] = []
	var line: String = ""
	for i: int in 6:
		var facing: int = 1 if i % 2 == 0 else -1
		var span: Vector2 = MinerLook.drawn_span(
			MinerLook.placed_rect(_tex, Vector2(CENTRE_X, ROW_LEFT), BODY_HEIGHT_PX, facing))
		spans.append(span)
		line += "  turn %s -> %.0f..%.0f\n" % ["RIGHT" if facing > 0 else "LEFT ", span.x, span.y]
	print("probe_facing_flip: turn sequence at a FIXED body position (x %.0f):\n%s" % [CENTRE_X, line.strip_edges()])
	var moved: int = 0
	for span: Vector2 in spans:
		if not is_equal_approx(span.x, spans[0].x):
			moved += 1
	if moved > 0:
		print("probe_facing_flip: FAIL - %d of %d turns MOVED the miner while it stood still"
			% [moved, spans.size()])
		_failed = true
	else:
		print("probe_facing_flip: PASS - all %d turns leave the miner where it stood" % spans.size())


func _report_pixels() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	# Printed, not assumed. `canvas_items` stretch means the render target and the canvas need not share
	# a scale, and a scan that silently reasons in the wrong one measures the stretch instead of the flip.
	print("probe_facing_flip: image %dx%d, viewport rect %s"
		% [img.get_width(), img.get_height(), str(get_viewport_rect().size)])
	# THE SCALE IS THE WHOLE MEASUREMENT. The render target is 1920x1080 and the canvas is 1280x720, so
	# a band scanned at canvas rows lands 1.5x too high in the image. The first run did exactly that: the
	# facing+1 band covered image rows 200..320 while its sprite sat at 348..420, so the number reported
	# for facing+1 was the BOTTOM EDGE of the facing-1 sprite. Both boxes looked plausible and neither
	# described its own subject.
	var scale: float = float(img.get_width()) / get_viewport_rect().size.x
	print("probe_facing_flip: canvas->image scale %.3f" % scale)
	var left_box: Vector2 = _span(img, ROW_LEFT, scale)
	var right_box: Vector2 = _span(img, ROW_RIGHT, scale)
	_say("facing -1", left_box)
	_say("facing +1", right_box)
	if left_box.x < 0.0 or right_box.x < 0.0:
		print("probe_facing_flip: FAIL - a band drew nothing, so neither box is a verdict about the flip")
		_failed = true
		return
	var c_left: float = (left_box.x + left_box.y) * 0.5
	var c_right: float = (right_box.x + right_box.y) * 0.5
	# The widths are reported too. Two boxes can share a centre and still disagree -- a clipped or
	# half-drawn sprite has a centre like anything else -- so "same centre" is only a verdict alongside
	# "same width".
	print("probe_facing_flip: RESULT centre facing -1 = %.1f (w %.0f), facing +1 = %.1f (w %.0f)"
		% [c_left, left_box.y - left_box.x, c_right, right_box.y - right_box.x])
	# NOT THE VERDICT, and labelled so it cannot be read as one. The miner is asymmetric and wears a rim
	# halo, so mirroring genuinely moves its bounding box -- a correct flip does NOT leave this at zero,
	# and the residual here is the art's own asymmetry, not a placement error. The size of the number is
	# still worth printing: a full sprite width means the bug, a pixel or two means the art.
	print("probe_facing_flip: bbox centre shifts %+.1f canvas px across the turn "
		% (c_right - c_left) + "(art asymmetry, not a verdict -- see VERDICT below)")
	# AND THE MIRROR MUST SURVIVE THE FIX. "Both boxes centred on the same x" is satisfied by deleting
	# the flip outright, which would trade a visible jump for a miner that never turns around. The
	# miner art is asymmetric, so its lit-pixel centroid sits off its own bbox centre; mirroring
	# reflects that offset. Equal magnitude, OPPOSITE sign is the thing only a real flip produces.
	var m_left: float = _centroid(img, ROW_LEFT, scale) - CENTRE_X
	var m_right: float = _centroid(img, ROW_RIGHT, scale) - CENTRE_X
	print("probe_facing_flip: RESULT mass-centroid offset facing -1 = %+.2f, facing +1 = %+.2f (a live flip mirrors the sign)"
		% [m_left, m_right])
	_report_mirror_shift(img, scale)


## THE VERDICT. Everything above is a summary statistic of one band, and both of them are confounded by
## the art itself: the miner is asymmetric and wears a rim halo, so its bounding box and its centroid BOTH
## move when it is mirrored, correctly, by an amount no one can predict from the placement. Reading the
## fix off those numbers means deciding how much residual is "just the art", which is a judgment call
## standing in for a measurement.
##
## This has no such freedom. It mirrors the facing-1 band about the placement centre and slides it across
## the facing+1 band, reporting the shift that matches best. A correct flip matches at 0 whatever the art
## looks like; the pre-fix code matches at the sprite width. The art's asymmetry cancels because the same
## art is on both sides of the comparison.
func _report_mirror_shift(img: Image, scale: float) -> void:
	var best_shift: int = 0
	var best_cost: float = -1.0
	var zero_cost: float = 0.0
	for shift: int in range(-48, 49):
		var cost: float = _mirror_cost(img, scale, shift)
		if shift == 0:
			zero_cost = cost
		if best_cost < 0.0 or cost < best_cost:
			best_cost = cost
			best_shift = shift
	print("probe_facing_flip: VERDICT best mirror alignment at shift %+d px (residual %.1f; at shift 0 it is %.1f)"
		% [best_shift, best_cost, zero_cost])
	if best_shift != 0:
		print("probe_facing_flip: VERDICT FAIL - turning also TRANSLATES the miner %+d px" % best_shift)
		_failed = true
		return
	# A run where NOTHING was drawn aligns perfectly at every shift, so "best shift is 0" is a pass by
	# construction on a blank frame. The bands are already checked for emptiness above; this checks the
	# shape of the cost curve instead -- a real sprite disagrees sharply with itself when slid off centre,
	# and the pre-fix run measured exactly that (30.7 aligned against 1173.1 at the wrong shift).
	var off_cost: float = _mirror_cost(img, scale, 8)
	if off_cost <= best_cost * 2.0:
		print("probe_facing_flip: VERDICT FAIL - the frame does not disagree with itself when slid 8px "
			+ "(%.1f against %.1f aligned), so a shift of 0 here is not evidence of anything" % [off_cost, best_cost])
		_failed = true
		return
	print("probe_facing_flip: VERDICT PASS - turning mirrors the miner in place "
		+ "(sliding it 8px costs %.1f against %.1f aligned)" % [off_cost, best_cost])


## Summed absolute colour difference between the facing-1 band, mirrored about `CENTRE_X`, and the
## facing+1 band displaced by `shift`. Lower is a better match.
func _mirror_cost(img: Image, scale: float, shift: int) -> float:
	var cost: float = 0.0
	var dy: int = int((ROW_RIGHT - ROW_LEFT) * scale)
	var y0: int = int((ROW_LEFT - BAND_HALF) * scale)
	var y1: int = int((ROW_LEFT + BAND_HALF) * scale)
	var x0: int = int((CENTRE_X - BAND_HALF) * scale)
	var x1: int = int((CENTRE_X + BAND_HALF) * scale)
	var axis: int = int(2.0 * CENTRE_X * scale) - 1  ## mirror maps x -> axis - x, within the placement rect
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var mx: int = axis - x + int(float(shift) * scale)
			if mx < 0 or mx >= img.get_width() or y + dy >= img.get_height():
				continue
			var a: Color = img.get_pixel(x, y)
			var b: Color = img.get_pixel(mx, y + dy)
			cost += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
	return cost


## Horizontal bounds of non-background pixels in the band around `row_centre`, or (-1,-1) for an empty
## band. Compared against the black fill rather than against a threshold: the fill is drawn by this file.
func _span(img: Image, row_centre: float, scale: float) -> Vector2:
	var lo: int = img.get_width()
	var hi: int = -1
	var y0: int = maxi(0, int((row_centre - BAND_HALF) * scale))
	var y1: int = mini(img.get_height() - 1, int((row_centre + BAND_HALF) * scale))
	for y: int in range(y0, y1 + 1):
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.02 or c.g > 0.02 or c.b > 0.02:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	if hi < 0:
		return Vector2(-1.0, -1.0)
	## Back into CANVAS units, which is the space `CENTRE_X` and every number in `MinerLook` is written
	## in. Reporting image pixels would make a 32px sprite read as 48 and a 32px error read as 48.
	return Vector2(float(lo) / scale, float(hi) / scale)


## Brightness-weighted mean x of the band, in canvas units. Weighted rather than counted so the reading
## is driven by where the art's mass IS, not by where its faint rim halo happens to clear a threshold.
func _centroid(img: Image, row_centre: float, scale: float) -> float:
	var sum_w: float = 0.0
	var sum_x: float = 0.0
	var y0: int = maxi(0, int((row_centre - BAND_HALF) * scale))
	var y1: int = mini(img.get_height() - 1, int((row_centre + BAND_HALF) * scale))
	for y: int in range(y0, y1 + 1):
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			var w: float = c.r + c.g + c.b
			if w <= 0.06:
				continue
			sum_w += w
			sum_x += w * float(x)
	if sum_w <= 0.0:
		return -1.0
	return (sum_x / sum_w) / scale


func _say(label: String, box: Vector2) -> void:
	if box.x < 0.0:
		print("probe_facing_flip: %s drew NOTHING in its band" % label)
		return
	print("probe_facing_flip: %s spans x %.0f..%.0f (centre %.1f, expected %.1f)"
		% [label, box.x, box.y, (box.x + box.y) * 0.5, CENTRE_X])
