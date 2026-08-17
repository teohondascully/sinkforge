extends "res://tools/check_base.gd"

## CAN YOU TELL WHAT YOU ARE HOLDING?
##
## check_voice asks whether two sounds can be told apart and refuses to let any pair sit on top of another.
## Nothing asked the same question of the icons, and the answer was no in a place that costs a gallery:
## earth, stone, shale, deepslate and sealrock all rendered through ONE cube differing only by tint, four of
## those tints sit within dE 8 of a neighbour in CIELab, and gravel had no glyph at all — it fell through
## draw_item's default branch to a flat coloured square.
##
## That last one is not cosmetic. Gravel is the only material that PACKS: a gallery backfilled with the
## stone you dug out of it is a sieve, and the same gallery packed with crushed gravel is a bulkhead. Which
## grey square is in your hand decides whether the water comes through.
##
## So this RENDERS every item's icon the way the hotbar does and compares them as a player's eye would:
##
##   SHAPE.   The alpha silhouette, compared by intersection-over-union. Two icons with IoU above SAME_SHAPE
##            occupy the same outline — whatever is drawn inside them, they read as the same object at
##            hotbar size.
##   COLOUR.  The mean colour over the covered pixels, in CIELab. Below SAME_TINT is a difference a person
##            will not reliably call at 40px against a moving background.
##
## The rule is a DISJUNCTION, and that is the design thesis stated as an assertion: two items may share an
## outline if their colours separate, and may share a colour if their outlines separate. What is forbidden
## is sharing both. A pair that does is not "similar", it is the same icon with two names.
##
## NEEDS A REAL WINDOW — it renders. Registered with add_gl, and it skips rather than lies if it finds no
## rendering device, because an all-blank comparison would pass this test perfectly.
##
##   godot --path . --script res://tools/check_item_reads.gd

## Every item draw_item is expected to have a real glyph for. The carried ground is the reason this layer
## exists; the metal chain is here because ingot/rich_ore and iron/iron_ingot/plate/iron_pickaxe are the
## other colour-close families and they should be held to the same rule.
const ITEMS: Array[StringName] = [
	&"earth", &"stone", &"gravel", &"shale", &"deepslate", &"sealrock",
	&"ore", &"rich_ore", &"iron", &"ingot", &"iron_ingot", &"plate", &"gear",
	&"coal", &"wood", &"scanner", &"sapling",
	&"wood_pickaxe", &"stone_pickaxe", &"iron_pickaxe", &"wood_axe",
	&"broad_bit", &"sinker_bit", &"lance_bit", &"wedge_bit",
]

const CANVAS: int = 64          ## px per icon render
const ICON: float = 48.0        ## the size draw_item is asked for, roughly a hotbar cell
const SAME_SHAPE: float = 0.90  ## silhouette IoU at or above which two icons share an outline
const SAME_TINT: float = 10.0   ## CIELab dE below which two icons share a colour

var _skipped: bool = false


## An inner class is its own scope and cannot see this script's constants, so the geometry is handed to it
## rather than read from CANVAS/ICON directly — which would not compile.
class Glyph extends Node2D:
	var item: StringName
	var at: Vector2
	var icon: float

	func _draw() -> void:
		Visuals.draw_item(self, at, icon, item)

func _initialize() -> void:
	print("== can you tell what you are holding ==")
	await _run()
	# quit() sets the exit code and leaves at the end of the frame, so a SECOND quit overwrites the first.
	# Without this guard the skip below returned 0, and the runner reads the exact code — so a layer that
	# announced "I did not run" in its own output was counted as a PASS, which is the precise defect the
	# three-state runner exists to prevent. Caught by expecting 42 and getting 0.
	if _skipped:
		return
	if _failures == 0:
		print("check_item_reads: PASS — no two items wear the same icon")
		quit(0)
	else:
		printerr("check_item_reads: FAIL (%d)" % _failures)
		quit(1)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("check_item_reads: SKIP — no rendering device, and comparing blank images would pass.")
		_skipped = true
		quit(SKIP)
		return

	var shots: Dictionary = {}
	for item: StringName in ITEMS:
		shots[item] = await _render(item)

	# --- every icon is actually drawn (a blank one would compare equal to every other blank one) ---
	var blank: Array[String] = []
	for item: StringName in ITEMS:
		if _coverage(shots[item]) < 0.02:
			blank.append(String(item))
	_check(blank.is_empty(),
		"every item draws something (%d blank: %s)" % [blank.size(), ", ".join(blank)])
	if not blank.is_empty():
		return                      # the comparisons below are meaningless over blanks

	# --- ...and no two of them read the same ---
	var worst_iou: float = 0.0
	var worst_pair: String = ""
	var clashes: Array[String] = []
	for i: int in ITEMS.size():
		for j: int in range(i + 1, ITEMS.size()):
			var a: StringName = ITEMS[i]
			var b: StringName = ITEMS[j]
			var iou: float = _iou(shots[a], shots[b])
			var de: float = _de(_mean_lab(shots[a]), _mean_lab(shots[b]))
			if iou > worst_iou:
				worst_iou = iou
				worst_pair = "%s/%s" % [a, b]
			if iou >= SAME_SHAPE and de < SAME_TINT:
				clashes.append("%s/%s (IoU %.2f, dE %.1f)" % [a, b, iou, de])
	print("  %d items, %d pairs; the most alike outlines are %s at IoU %.2f"
		% [ITEMS.size(), ITEMS.size() * (ITEMS.size() - 1) / 2, worst_pair, worst_iou])
	for c: String in clashes:
		printerr("    %s" % c)
	_check(clashes.is_empty(),
		"no pair shares BOTH an outline and a colour (%d pair(s) do)" % clashes.size())

	# --- the carried ground specifically: it is what this layer was written for ---
	# NOT "these six no longer share a silhouette" — that would be the wrong claim and it would fail on a
	# pair that is working as designed. sealrock KEEPS the cube, deliberately: it is a block, and its colour
	# already separates it from stone by dE 24. What must hold is the narrower, true thing — where COLOUR
	# cannot tell two carried materials apart, SHAPE has to, because tint is the half that dies first at
	# hotbar size against a dark moving background.
	var ground: Array[StringName] = [&"earth", &"stone", &"gravel", &"shale", &"deepslate", &"sealrock"]
	var unseparated: Array[String] = []
	var close_pairs: int = 0
	for i: int in ground.size():
		for j: int in range(i + 1, ground.size()):
			var a: StringName = ground[i]
			var b: StringName = ground[j]
			if _de(_mean_lab(shots[a]), _mean_lab(shots[b])) >= SAME_TINT:
				continue                                    # colour already separates these two
			close_pairs += 1
			var iou: float = _iou(shots[a], shots[b])
			if iou >= SAME_SHAPE:
				unseparated.append("%s/%s (IoU %.2f)" % [a, b, iou])
	# Non-vacuity: if no carried pair is colour-close, the loop above asserts nothing at all. The palette
	# genuinely has several such pairs, so zero here means the measurement broke, not that the art is good.
	_check(close_pairs > 0,
		"the carried ground still contains colour-close pairs to judge (%d) — else this asserts nothing"
			% close_pairs)
	_check(unseparated.is_empty(),
		"...and every one of them is separated by SHAPE instead (%d not: %s)"
			% [unseparated.size(), ", ".join(unseparated)])

	# --- and gravel in particular, against the block it decides a flood against ---
	var gs: float = _iou(shots[&"gravel"], shots[&"stone"])
	_check(gs < 0.75,
		"gravel and stone are plainly different objects (IoU %.2f) — the sieve/bulkhead choice reads" % gs)


# --- rendering + comparison ---------------------------------------------------------------------------

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


## Fraction of the canvas the icon covers — the silhouette, as a number.
func _coverage(img: Image) -> float:
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				n += 1
	return float(n) / float(img.get_width() * img.get_height())


## Intersection over union of two alpha silhouettes: 1.0 = the same outline, 0.0 = no overlap at all.
func _iou(a: Image, b: Image) -> float:
	var inter: int = 0
	var uni: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			var pa: bool = a.get_pixel(x, y).a > 0.5
			var pb: bool = b.get_pixel(x, y).a > 0.5
			if pa and pb:
				inter += 1
			if pa or pb:
				uni += 1
	return float(inter) / float(maxi(uni, 1))


## Mean colour over the covered pixels only — the background must not dilute the reading.
func _mean_lab(img: Image) -> Vector3:
	var r: float = 0.0
	var g: float = 0.0
	var b: float = 0.0
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var p: Color = img.get_pixel(x, y)
			if p.a <= 0.5:
				continue
			r += p.r
			g += p.g
			b += p.b
			n += 1
	if n == 0:
		return Vector3.ZERO
	return _lab(Color(r / float(n), g / float(n), b / float(n)))


func _lab(c: Color) -> Vector3:
	var lr: float = _linear(c.r)
	var lg: float = _linear(c.g)
	var lb: float = _linear(c.b)
	var x: float = (lr * 0.4124 + lg * 0.3576 + lb * 0.1805) / 0.95047
	var y: float = lr * 0.2126 + lg * 0.7152 + lb * 0.0722
	var z: float = (lr * 0.0193 + lg * 0.1192 + lb * 0.9505) / 1.08883
	return Vector3(116.0 * _f(y) - 16.0, 500.0 * (_f(x) - _f(y)), 200.0 * (_f(y) - _f(z)))


func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else (7.787 * t + 16.0 / 116.0)


func _linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


func _de(a: Vector3, b: Vector3) -> float:
	return (a - b).length()
