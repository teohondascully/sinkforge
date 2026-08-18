extends RefCounted

## WHAT "DEAD SPACE" MEANS, IN ONE PLACE.
##
## A region of a frame is dead when it is flat AND crushed at once — low local contrast and few distinct
## levels. Either alone is legitimate: a sky gradient is flat but uses its whole range, and a dark rock face
## is compressed but has structure in it. Only both together means there is nothing there.
##
## Two things this definition learned the hard way, both from measuring a broken frame and a fixed one side
## by side and finding they scored the same:
##
##   1. DETAIL MUST BE ABSOLUTE, NOT RELATIVE. Normalising local contrast by a region's own mean rewards
##      darkness: at mean luma 14, a two-byte dither scores 14% and looks like nothing. Bytes are already
##      roughly perceptual under sRGB, so absolute byte differences are the honest unit.
##   2. AVERAGES OVER BANDS HIDE REGIONS. Averaging a dead quarter with a busy one produces a fine number
##      for a bad picture. Dead space is a SPATIAL property — a contiguous area with nothing in it — so it
##      is measured spatially: tile the region, score each tile alone, cap the FRACTION that come back dead.
##
## It lives on its own because more than one layer needs to ask the question and they must be asking the
## SAME question: check_opening judges the first screen a player ever sees, check_underground judges the
## place they spend the rest of the game. Two definitions of dead space would be two standards.

const TILE: int = 120                ## px per judged tile — about a sixteenth of a 1080p frame across

## A tile is DEAD when both of these fall through. Absolute units, in luminance bytes.
const DEAD_DETAIL: float = 2.2       ## mean |neighbour difference| — under this there is no visible texture
const DEAD_RANGE: float = 26.0       ## 5th-to-95th percentile spread — under this it is a handful of levels


## Judge the horizontal slab of `img` between rows y0 and y1.
##
## `lit_floor` (mean luminance bytes) excuses tiles too dark to be judged at all. It exists for the
## underground, where darkness is the DESIGN: a tile out past the lamp is supposed to have nothing in it,
## and a guard that counted it would be measuring how much unlit rock is in frame — the same mistake as
## counting empty sky on the surface. Left at zero, every tile is judged.
##
## Returns {total, dead, frac, rows (one string per tile row, '#' dead / '.' alive / ' ' unlit), worst,
## details (the per-judged-tile local-contrast figures, for callers that want the distribution)}.
static func judge(img: Image, y0: int, y1: int, lit_floor: float = 0.0) -> Dictionary:
	var w: int = img.get_width()
	var total: int = 0
	var dead: int = 0
	var worst: String = "(nothing judged)"
	var worst_score: float = 1e9
	var rows: Array[String] = []
	var details: PackedFloat32Array = PackedFloat32Array()
	var ty: int = y0
	while ty + TILE <= y1:
		var line: String = ""
		var tx: int = 0
		while tx + TILE <= w:
			var s: Array = _tile(img, tx, ty)
			var detail: float = s[0]
			var rng: float = s[1]
			if float(s[2]) < lit_floor:
				line += " "
				tx += TILE
				continue
			details.append(detail)
			var is_dead: bool = detail < DEAD_DETAIL and rng < DEAD_RANGE
			total += 1
			if is_dead:
				dead += 1
			line += "#" if is_dead else "."
			var score: float = detail / DEAD_DETAIL + rng / DEAD_RANGE
			if score < worst_score:
				worst_score = score
				worst = "(%d,%d) detail %.1f range %.0f" % [tx, ty, detail, rng]
			tx += TILE
		rows.append(line)
		ty += TILE
	# NOTHING JUDGED FALLS TO THE FAILING SIDE, and the `maxi(total, 1)` this replaces is why it has to be
	# said out loud. That was a divide-by-zero guard, which is a reasonable thing to reach for — and it made
	# the empty case return 0.0, the BEST possible score. A judged band that collapsed to nothing therefore
	# reported a flawless frame, and every caller gating on `frac <= cap` passed unconditionally.
	#
	# That is the whole family in one line: the failure moved the number the passing way, so tightening the
	# cap would have made a broken capture pass more comfortably. A guard against an impossible arithmetic
	# case must fall to the side that stops the build, because "I could not measure this" and "this is
	# perfect" are the two readings, and only one of them is safe to be wrong about.
	return {"total": total, "dead": dead, "frac": 1.0 if total == 0 else float(dead) / float(total),
		"rows": rows, "worst": worst, "details": details}


## Print a judgement the same way whoever is asking. '#' = dead, '.' = carries content.
static func report(j: Dictionary) -> void:
	for r: String in j["rows"]:
		print("    %s" % r)
	print("    deadest tile: %s" % str(j["worst"]))


## [mean absolute neighbour difference, 5th-to-95th percentile luminance spread, mean luminance] for one
## tile, all in luminance bytes. Sampled every other pixel — a 120px tile is 3600 samples either way and the statistics
## settle long before that.
static func _tile(img: Image, x0: int, y0: int) -> Array:
	var hist: PackedInt32Array = PackedInt32Array()
	hist.resize(256)
	var diff: float = 0.0
	var n: int = 0
	for y: int in range(y0, y0 + TILE - 2, 2):
		for x: int in range(x0, x0 + TILE - 2, 2):
			var a: float = _luma(img, x, y)
			hist[int(a)] += 1
			# HORIZONTAL AND VERTICAL, averaged. This measured only |luma(x,y) - luma(x+2,y)| -- one axis --
			# so a tile whose content varies VERTICALLY scored zero detail and was reported DEAD. That is
			# exactly the structure this terrain draws: strata, bedding, partings and the cast shadow on the
			# back wall all vary up-the-frame and are near-constant along it.
			#
			# Averaging the two axes rather than summing keeps the scale: isotropic content reads the same as
			# before, so the calibrated caps still mean what they meant. Only tiles that are detailed on the
			# axis nobody was looking at move, which is precisely the false negative being repaired.
			#
			# A/B'd across every layer that shares this metric before landing, because a change here moves all of
			# them at once: check_opening went 1/32 -> 7/32 dead (a real dead region the one-axis metric could not
			# see), check_underground and check_water_reads both unchanged and passing. That measurement is why
			# there is no env switch back to the old behaviour -- an escape hatch to a metric known to under-report
			# is a way to buy green, and the A/B it would have served is already done and written down here.
			var dh: float = absf(a - _luma(img, x + 2, y))
			var dv: float = absf(a - _luma(img, x, y + 2))
			diff += (dh + dv) * 0.5
			n += 1
	if n == 0:
		return [0.0, 0.0, 0.0]
	var sum: float = 0.0
	for v: int in 256:
		sum += float(v) * float(hist[v])
	return [diff / float(n), float(_pct(hist, n, 0.95) - _pct(hist, n, 0.05)), sum / float(n)]


static func _luma(img: Image, x: int, y: int) -> float:
	var c: Color = img.get_pixel(x, y)
	return clampf((c.r * 0.299 + c.g * 0.587 + c.b * 0.114) * 255.0, 0.0, 255.0)


static func _pct(hist: PackedInt32Array, n: int, p: float) -> int:
	var want: int = int(float(n) * p)
	var acc: int = 0
	for v: int in 256:
		acc += hist[v]
		if acc >= want:
			return v
	return 255
