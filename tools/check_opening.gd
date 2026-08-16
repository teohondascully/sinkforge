extends SceneTree

## NO LARGE REGION OF THE OPENING FRAME MAY BE DEAD SPACE.
##
## The first screen a player ever sees is the one piece of this game judged before anything is played, and
## the piece least protected by tests: every other harness layer measures the SIM, and a composition
## failure is invisible to all of them. The failure that prompted this was not subtle — the bottom
## forty-five percent of the opening frame printed as one smooth brown gradient with about five distinct
## levels in it. Every terrain pass was running correctly; the veil MULTIPLIES, which preserves relative
## contrast perfectly, but at a multiplier of 0.18 the whole of the rock has thirty-five levels to live in
## and its own texture spans two of them. Correct code, dead picture.
##
## TWO THINGS THIS TEST LEARNED THE HARD WAY, both from measuring the broken frame and the fixed one side
## by side and finding they scored the same:
##
##   1. DETAIL MUST BE ABSOLUTE, NOT RELATIVE. Normalising local contrast by a region's own mean rewards
##      darkness: at mean luma 14, a two-byte dither scores 14% and looks like nothing. Bytes are already
##      roughly perceptual under sRGB, so absolute byte differences are the honest unit — and by that unit
##      the dead soil scored 1.9 and the fixed soil scores far more.
##   2. AVERAGES OVER BANDS HIDE REGIONS. A horizontal band spans sky, mountains, machines and the miner;
##      averaging a dead quarter with a busy one produces a fine number for a bad picture. Dead space is a
##      SPATIAL property — a contiguous area with nothing in it — so it has to be measured spatially.
##
## Hence: tile the frame, score each tile on its own, and cap the FRACTION of tiles that are dead. A tile
## is dead when it is flat AND crushed at once — low local contrast and few distinct levels. Either alone
## is legitimate: a sky gradient is flat but uses its whole range, and a dark rock face is compressed but
## has structure in it. Only both together means there is nothing there.
##
## No reference image, nothing to re-bless when the art changes. It asserts that the picture has content,
## which is true of every good version of this frame and false of the one that prompted it.

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 60
const TILE: int = 120                ## px per judged tile — about a sixteenth of the frame across

## WHAT IS JUDGED: the GROUND, from the horizon down to where the hotbar starts.
##
## Not the sky, which is a backdrop and is allowed — required, really — to be a smooth gradient; a test
## that counted empty sky as a failure would only ever be measuring how much sky is in frame, and would
## push every composition toward busy. Not the HUD either: vector chrome with hard edges over near-black
## panels flatters every tile it touches. The ground is the game's subject, it is where the player is
## going, and it is the region that was dead.
const HUD_BOTTOM: float = 0.20       ## fraction of the frame the hotbar + key strip occupy

## A tile is DEAD when both of these fall through. Absolute units, in luminance bytes.
const DEAD_DETAIL: float = 2.2       ## mean |neighbour difference| — under this there is no visible texture
const DEAD_RANGE: float = 26.0       ## 5th-to-95th percentile spread — under this it is a handful of levels

## Fraction of judged ground tiles allowed to be dead. Not zero — a dark cave mouth or an unlit overhang
## in frame is legitimately empty and a zero cap would forbid darkness itself. Measured on this frame: the
## broken opening ran 13 of 32 tiles dead (41%), the fixed one runs 0. Twelve percent is four tiles, which
## is room for a genuinely dark feature and nowhere near room for a dead region.
const DEAD_CAP: float = 0.12


func _initialize() -> void:
	# The dummy renderer paints blank frames, so there is nothing here to judge and pretending otherwise
	# would be worse than not running: a green "no dead space" on an all-black image is a lie. Skip, say
	# so, and let the machines that can actually draw be the ones that answer.
	if DisplayServer.get_name() == "headless":
		print("check_opening: SKIP — no display; a picture cannot be judged by the dummy renderer")
		quit(0)
		return
	MainView.dev_start = false
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw          # the veil/light layers repaint a frame behind a move
	var img: Image = get_root().get_texture().get_image()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var y0: int = _horizon_y(main, h)
	var y1: int = int(float(h) * (1.0 - HUD_BOTTOM))

	var total: int = 0
	var dead: int = 0
	var worst: String = ""
	var worst_score: float = 1e9
	var rows: Array[String] = []
	var ty: int = y0
	while ty + TILE <= y1:
		var line: String = ""
		var tx: int = 0
		while tx + TILE <= w:
			var s: Array = _tile(img, tx, ty)
			var detail: float = s[0]
			var rng: float = s[1]
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

	print("== the ground in the opening frame has to have something in it ==  (%dx%d, horizon at y=%d, %d tiles)"
		% [w, h, y0, total])
	for r: String in rows:
		print("    %s" % r)                          # '#' = dead, '.' = carries content
	var frac: float = float(dead) / float(maxi(total, 1))
	print("    deadest tile: %s" % worst)
	if frac <= DEAD_CAP:
		print("check_opening: PASS — %d/%d tiles dead (%.0f%%, cap %.0f%%)"
			% [dead, total, frac * 100.0, DEAD_CAP * 100.0])
		quit(0)
	else:
		printerr("check_opening: FAIL — %d/%d tiles dead (%.0f%%, cap %.0f%%): a region of the first screen"
			% [dead, total, frac * 100.0, DEAD_CAP * 100.0]
			+ " a player ever sees has nothing in it")
		quit(1)


## Screen row of the walked surface line, straight out of the sim and the live camera — so the judged
## region starts exactly where the ground starts, whatever the terrain and zoom happen to be.
func _horizon_y(main: MainView, h: int) -> int:
	var cam: Vector2 = main._camera.global_position
	var zoom: float = main._current_zoom()
	var col: int = main._cell_at(main._player.position).x
	var world_y: float = float(main.sim.surface_row(col) + 1) * float(WorldRenderer.CELL)
	return clampi(int((world_y - cam.y) * zoom + float(h) * 0.5), 0, h - 1)


## [mean absolute neighbour difference, 5th-to-95th percentile luminance spread] for one tile, both in
## luminance bytes. Sampled every other pixel — a 120px tile is 3600 samples either way and the statistics
## settle long before that.
func _tile(img: Image, x0: int, y0: int) -> Array:
	var hist: PackedInt32Array = PackedInt32Array()
	hist.resize(256)
	var diff: float = 0.0
	var n: int = 0
	for y: int in range(y0, y0 + TILE, 2):
		for x: int in range(x0, x0 + TILE - 2, 2):
			var a: float = _luma(img, x, y)
			hist[int(a)] += 1
			diff += absf(a - _luma(img, x + 2, y))
			n += 1
	if n == 0:
		return [0.0, 0.0]
	return [diff / float(n), float(_pct(hist, n, 0.95) - _pct(hist, n, 0.05))]


func _luma(img: Image, x: int, y: int) -> float:
	var c: Color = img.get_pixel(x, y)
	return clampf((c.r * 0.299 + c.g * 0.587 + c.b * 0.114) * 255.0, 0.0, 255.0)


func _pct(hist: PackedInt32Array, n: int, p: float) -> int:
	var want: int = int(float(n) * p)
	var acc: int = 0
	for v: int in 256:
		acc += hist[v]
		if acc >= want:
			return v
	return 255
