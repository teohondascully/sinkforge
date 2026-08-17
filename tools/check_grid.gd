extends SceneTree

## THE ROCK MUST NOT BETRAY ITS GRID.
##
## The terrain is stored one material per 32px coarse cell and REPAINTED at an 8px fine grain, and every
## texture pass in `scenes/fine_terrain.gd` — grain, patches, embedded stones, cracks, hue, AO, form — is
## sampled per FINE cell and measured by `check_texture`. All of it, however, is painted ON TOP OF a base
## colour that comes from the COARSE cell: `_cell_fill_color(c, def)`, one Color for all SUBDIV² children.
##
## That base is not flat. It carries `_cell_jitter` and `_strata`, two deliberately SMOOTH, low-frequency
## fields whose stated purpose is to break a flat fill into "cloudy patches ... NOT a per-cell random that
## seams at every tile edge (which just rebuilds the grid)". Evaluated once per coarse cell, that is
## exactly what they become: a smooth field sampled and held constant across 4x4 fine cells is a MOSAIC,
## and its every step lands on a coarse boundary. Worse, both are multiplied by `1.0 + depth * 2.2`, so
## the mosaic gets up to 3.2x LOUDER with depth — loudest precisely where the game is played.
##
## check_texture cannot see this. It bakes the real FineTerrain but substitutes a FLAT GREY for the
## material palette, deliberately, so its numbers are attributable to the texture passes alone. That makes
## it structurally blind to a defect in the coarse input, which is where this layer comes in: it reads the
## pixels the REAL renderer bakes with the REAL palette, and asks one question the eye asks first.
##
## THE MEASUREMENT. In the baked fine image, walk every pair of horizontally adjacent fine cells and sort
## each pair into two buckets:
##   SEAM — the pair straddles a coarse-cell boundary (fx+1 is a multiple of SUBDIV)
##   BODY — the pair sits inside one coarse cell
## Compare the mean |Δluma| of the two buckets. In rock that reads as rock, they are the same: a texture
## field does not know where the grid is. In rock that reads as a tilemap, SEAM is a multiple of BODY.
## Then do the same down the columns. The ratio is the whole test.
##
## WHAT IS EXCLUDED, and why each exclusion is necessary rather than convenient:
##   * pairs where either cell is not solid, or has ANY air among its 8 neighbours — edge cells carry AO,
##     rim, moss and form terms that step legitimately, and a face is where they all land at once.
##   * pairs whose two COARSE parents hold different materials — dirt meeting stone SHOULD step hard.
##     That is geology, not tiling, and a test that punished it would be asking for mush.
##   * everything above SOIL_CLEAR, where the soil profile keys bands to each column's own surface row
##     and therefore steps per COLUMN by design.
## What remains is one continuous material, away from every face: the case where a step can only come from
## the grid. Measured headless off the real bake, so it is exact — no camera, no zoom, no resampling.

const SCENE := "res://scenes/main.tscn"
const SETTLE_FRAMES: int = 8            ## frames to let the initial full bake land before reading pixels

## Fine rows below which the soil profile is fully faded out (SOIL_ROWS is 40 fine rows below a column's
## own surface, and the surface itself wanders); well clear of it, every column is plain rock.
const SOIL_CLEAR: int = 120

## How much harder a pair may step ACROSS a coarse boundary than inside one. 1.0 would demand the grid be
## perfectly invisible, which no honest bake achieves — the base colour is genuinely constant per cell for
## everything the coarse pass owns. The bar is set at a ratio the eye does not resolve as a line: a seam
## may be a fifth louder than the body's own grain, not a multiple of it.
const MAX_SEAM_RATIO: float = 1.20

## Refuse to pass on a thin sample — an empty world would otherwise score perfectly.
const MIN_PAIRS: int = 20000
## The BACK WALL (#S13) gets the same question asked of it, with its own floor: wall cells only exist where
## the world is already open (caves at worldgen, everything you dig after), so there are honestly fewer of
## them than there is solid rock, and demanding the rock's sample size here would fail on an untouched world.
const MIN_WALL_PAIRS: int = 4000

var _main: Node = null
var _frames: int = 0


func _initialize() -> void:
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	_judge()
	return true


func _judge() -> void:
	var r: WorldRenderer = _main._renderer
	var fine: FineTerrain = r._fine
	# #17 made the boot bake progressive, so at SETTLE_FRAMES part of the grid is still transparent — and
	# every sweep below SKIPS transparent cells, so an unfinished grid does not read as a grid problem, it
	# reads as too few pairs to say anything. It failed exactly that way. This layer judges the molded rock,
	# not boot pacing; give it a whole one. See FineTerrain.finish_pending.
	var filled: int = fine.finish_pending()
	if filled > 0:
		print("  (finished %d rows of outstanding boot fill before judging)" % filled)
	var sub: int = FineTerrain.SUBDIV
	var fcols: int = fine._fcols
	var frows: int = fine._frows
	var data: PackedByteArray = fine._data
	var solid: PackedByteArray = fine._fine_solid

	print("== the rock must not betray its grid ==  (fine grid %dx%d, %d fine cells per coarse side)"
		% [fcols, frows, sub])

	var ok: bool = true
	print("  -- the rock you have not dug --")
	ok = _report("across a face (left-right)", _sweep(r, fine, data, solid, fcols, frows, sub, false, true),
		MIN_PAIRS) and ok
	ok = _report("down a face (top-bottom)", _sweep(r, fine, data, solid, fcols, frows, sub, false, false),
		MIN_PAIRS) and ok
	# THE BACK WALL. Until #S13 this layer could not see it at all — it samples only cells with all nine
	# fine neighbours solid, and a wall cell is air by definition. The wall was therefore the one large
	# thing on screen with no instrument on it, and it was a flat fill per 32px cell the whole time.
	print("  -- the wall behind what you have dug --")
	ok = _report("across the wall (left-right)", _sweep(r, fine, data, solid, fcols, frows, sub, true, true),
		MIN_WALL_PAIRS) and ok
	ok = _report("down the wall (top-bottom)", _sweep(r, fine, data, solid, fcols, frows, sub, true, false),
		MIN_WALL_PAIRS) and ok

	if not ok:
		printerr("check_grid: FAIL — the coarse grid is visible in the rock")
		quit(1)
		return
	print("check_grid: PASS — the paint does not know where the coarse cells are")
	quit(0)


## Walk every adjacent pair along one axis, bucket it SEAM/BODY, and return
## [seam_mean, body_mean, seam_pairs, body_pairs]. `horizontal` picks the axis.
func _sweep(r: WorldRenderer, fine: FineTerrain, data: PackedByteArray, solid: PackedByteArray,
		fcols: int, frows: int, sub: int, wall: bool, horizontal: bool) -> Array:
	var from_row: int = SOIL_CLEAR
	var seam_sum: float = 0.0
	var body_sum: float = 0.0
	var seam_n: int = 0
	var body_n: int = 0
	for fy: int in range(from_row, frows - 1):
		for fx: int in range(1, fcols - 1):
			var nx: int = fx + 1 if horizontal else fx
			var ny: int = fy if horizontal else fy + 1
			if wall:
				if not _wall_interior(fine, data, solid, fcols, frows, sub, fx, fy) \
						or not _wall_interior(fine, data, solid, fcols, frows, sub, nx, ny):
					continue
				if not _same_wall(r, sub, fx, fy, nx, ny):
					continue
			else:
				if not _deep_interior(solid, fcols, frows, fx, fy) \
						or not _deep_interior(solid, fcols, frows, nx, ny):
					continue
				if not _same_material(r, sub, fx, fy, nx, ny):
					continue
			var step: float = absf(_luma(data, fcols, fx, fy) - _luma(data, fcols, nx, ny))
			# The pair straddles a coarse boundary when the SECOND cell starts a new coarse cell.
			var straddles: bool = (nx % sub == 0) if horizontal else (ny % sub == 0)
			if straddles:
				seam_sum += step
				seam_n += 1
			else:
				body_sum += step
				body_n += 1
	return [
		seam_sum / float(maxi(seam_n, 1)),
		body_sum / float(maxi(body_n, 1)),
		seam_n,
		body_n,
	]


func _report(label: String, m: Array, min_pairs: int) -> bool:
	var seam: float = m[0]
	var body: float = m[1]
	var pairs: int = int(m[2]) + int(m[3])
	var ratio: float = seam / maxf(body, 0.0001)
	print("  %s: seam step %.3f vs body step %.3f  ->  %.2fx  (%d seam / %d body pairs)"
		% [label, seam, body, ratio, int(m[2]), int(m[3])])
	if pairs < min_pairs:
		printerr("    FAIL: only %d pairs sampled (need %d) — the sample is too thin to mean anything"
			% [pairs, min_pairs])
		return false
	if ratio > MAX_SEAM_RATIO:
		printerr("    FAIL: crossing a coarse boundary steps %.2fx harder than the rock's own grain (cap %.2fx)"
			% [ratio, MAX_SEAM_RATIO])
		return false
	print("    PASS: %.2fx (cap %.2fx)" % [ratio, MAX_SEAM_RATIO])
	return true


## A cell deep enough inside the rock that no face term (AO, rim, moss, form) reaches it: solid, with all
## eight neighbours solid too.
func _deep_interior(solid: PackedByteArray, fcols: int, frows: int, fx: int, fy: int) -> bool:
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			var x: int = fx + dx
			var y: int = fy + dy
			if x < 0 or y < 0 or x >= fcols or y >= frows:
				return false
			if solid[y * fcols + x] == 0:
				return false
	return true


## A back-wall cell far enough from any rock that no cast shadow reaches it: painted (alpha 255), not
## solid, its coarse parent not solid either — which excludes the eroded back-ROCK branch, a different
## paint — and the same true of all eight neighbours.
func _wall_interior(fine: FineTerrain, data: PackedByteArray, solid: PackedByteArray, fcols: int,
		frows: int, sub: int, fx: int, fy: int) -> bool:
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			var x: int = fx + dx
			var y: int = fy + dy
			if x < 0 or y < 0 or x >= fcols or y >= frows:
				return false
			if solid[y * fcols + x] == 1:
				return false
			if data[(y * fcols + x) * 4 + 3] != 255:
				return false
			if fine._solid_mask[(y / sub) * fine._cols + (x / sub)] > 0.5:
				return false
	return true


## Two wall cells share a wall material when their COARSE parents do.
func _same_wall(r: WorldRenderer, sub: int, ax: int, ay: int, bx: int, by: int) -> bool:
	var a: Vector2i = Vector2i(ax / sub, ay / sub)
	var b: Vector2i = Vector2i(bx / sub, by / sub)
	if a == b:
		return true
	return r.sim.wall.get(a, &"") == r.sim.wall.get(b, &"")


## Two fine cells share a material when their COARSE parents do — a real material boundary is allowed to
## step as hard as it likes.
func _same_material(r: WorldRenderer, sub: int, ax: int, ay: int, bx: int, by: int) -> bool:
	var a: Vector2i = Vector2i(ax / sub, ay / sub)
	var b: Vector2i = Vector2i(bx / sub, by / sub)
	if a == b:
		return true
	return r.sim.material_at(a) == r.sim.material_at(b)


## Perceptual luminance of one baked fine texel, 0..255.
func _luma(data: PackedByteArray, fcols: int, fx: int, fy: int) -> float:
	var i: int = (fy * fcols + fx) * 4
	return 0.2126 * float(data[i]) + 0.7152 * float(data[i + 1]) + 0.0722 * float(data[i + 2])
