extends SceneTree

## THE BAKE MUST NOT CHANGE COLOUR BECAUSE YOU DUG SOMEWHERE ELSE.
##
## THE DEFECT THIS EXISTS FOR. The coarse terrain bake renders into a SubViewport that RETAINS its render
## target between updates -- CLEAR_MODE_NEVER on the partial-bake path, which is what makes a dig cost one
## chunk instead of the whole world. That viewport also inherited the WorldEnvironment, whose adjustment
## pass runs as a viewport post-process, so saturation 1.18 was re-applied to the same stored pixels on
## every bake update and the terrain compounded 1.18^n. A grass cell measured (87,130,47) at boot and
## (42,255,0) after one play arc. The fine layer covers the coarse bake everywhere except the walked
## surface line, so what it produced on screen was a neon red-and-green band running the full width of the
## frame where the ground meets the sky.
##
## WHY EIGHTY LAYERS PASSED A FRAME WITH A STRIPE ACROSS IT, which is the part worth keeping. Not one of
## them was pointed the wrong way. **Every layer in the suite photographs a freshly booted world** -- boot,
## settle, shutter -- and `1.18^1` is not a defect. The population the harness samples excluded the state in
## which the bug exists. A frame check for pure primaries would still pass on the broken build at boot.
##
## SO THE ASSERTION IS IDEMPOTENCE, NOT APPEARANCE. Sample cells in the bake, dig somewhere else, and
## require the sampled cells to be byte-identical. That guards the operator rather than the symptom: the
## next thing wrongly applied to stored pixels will produce a different symptom in a different band, and
## this layer will still catch it.
##
## THE DIGGING IS THE POPULATION, NOT THE ASSERTION, and it has to be the REAL path. Measured while the
## defect was live: six direct `_bake_terrain_chunks` calls drifted nothing, six `_bake_terrain_full` calls
## drifted nothing, and `sim.mine()` through the game's own repaint drifted (87,130,47) -> (85,245,0). A
## version of this layer that called the bake functions directly would have passed on the broken build.

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 70
const DIGS: int = 8                  ## dig events, each one a real mine + the renderer's own repaint
const SETTLE_DIG: int = 8            ## frames after each dig for the bake to land
const TOL: int = 1                   ## channel units a stable bake is allowed to move (it moves 0)
const MIN_SAMPLES: int = 6           ## the judged population may not quietly collapse to nothing
const DIG_COL_OFFSET: int = 40       ## columns away from every sample, so the digs cannot touch them
const WITNESS_MIN: int = 8           ## the dug column must move by at least this, or nothing was repainted

var _fails: int = 0

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("check_bake_idempotent: SKIP — needs a display (the bake is a SubViewport render target)")
		quit(0)
		return
	MainView.dev_start = false
	await _run()

func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	await physics_frame
	for _i: int in SETTLE:
		await physics_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var r: WorldRenderer = main._renderer
	var cell: int = WorldRenderer.CELL
	var img: Image = r._terrain_viewport.get_texture().get_image()

	print("== the bake must not change colour because you dug somewhere else ==")

	# --- the sampled population: painted surface cells, spread across the world ---
	var sites: Array[Vector2i] = []
	var before: Array[Color] = []
	var dig_col: int = -1
	for col: int in range(6, FactorySim.GRID_COLS - 6, 9):
		var row: int = main.sim.surface_row(col)
		if row <= 0 or row >= FactorySim.GRID_ROWS:
			continue
		var px: int = col * cell + cell / 2
		var py: int = row * cell + 2
		if px >= img.get_width() or py >= img.get_height():
			continue
		var c: Color = img.get_pixel(px, py)
		if c.a < 0.99:
			continue                      # air: nothing painted here, so nothing to hold still
		sites.append(Vector2i(px, py))
		before.append(c)
	print("  sampled %d painted surface cells across the bake" % sites.size())
	_check(sites.size() >= MIN_SAMPLES,
		"CONTROL: at least %d painted cells were found to judge (found %d)" % [MIN_SAMPLES, sites.size()])
	if sites.size() < MIN_SAMPLES:
		_finish()
		return

	# --- the witness column: far from every sample, and it is SUPPOSED to change ---
	dig_col = clampi(int(sites[0].x / cell) + DIG_COL_OFFSET, 4, FactorySim.GRID_COLS - 5)
	var wrow: int = main.sim.surface_row(dig_col)
	var wpx: int = dig_col * cell + cell / 2
	var wpy: int = wrow * cell + 2
	var witness_before: Color = img.get_pixel(wpx, wpy)

	# --- the population: real digs, through the game's own repaint path ---
	for i: int in DIGS:
		# The SURFACE cell, not the one under it. Digging below leaves the sampled cell solid and the
		# witness never moves -- which the control caught, and which would otherwise have let a broken
		# build pass on a bake nothing had touched.
		main.sim.mine(Vector2i(dig_col, main.sim.surface_row(dig_col)))
		for _k: int in SETTLE_DIG:
			await physics_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var after: Image = r._terrain_viewport.get_texture().get_image()

	# THE WITNESS FIRST. If the digs did not reach the bake, every stability claim below is satisfied by a
	# bake nothing touched, and the layer would pass on a build where the defect is live.
	var witness_after: Color = after.get_pixel(wpx, wpy)
	var wd: int = _delta(witness_before, witness_after)
	_check(wd >= WITNESS_MIN,
		"CONTROL: %d digs at column %d actually reached the bake (that column moved %d)"
			% [DIGS, dig_col, wd])

	# --- the claim ---
	var worst: int = 0
	var worst_at: Vector2i = Vector2i.ZERO
	var worst_pair: String = ""
	var moved: int = 0
	for i: int in sites.size():
		var d: int = _delta(before[i], after.get_pixel(sites[i].x, sites[i].y))
		if d > TOL:
			moved += 1
		if d > worst:
			worst = d
			worst_at = sites[i]
			worst_pair = "%s -> %s" % [_s(before[i]), _s(after.get_pixel(sites[i].x, sites[i].y))]
	if worst > 0:
		print("  worst drift %d at bake px %d,%d   %s" % [worst, worst_at.x, worst_at.y, worst_pair])
	_check(moved == 0,
		"%d of %d cells nobody dug hold their colour after %d digs elsewhere (worst drift %d, tol %d)"
			% [sites.size() - moved, sites.size(), DIGS, worst, TOL])
	_finish()


## Largest per-channel difference, in 0..255 units. Alpha is ignored: a cell going transparent is a
## different defect and check_grid owns it.
func _delta(a: Color, b: Color) -> int:
	return maxi(absi(int(a.r * 255.0) - int(b.r * 255.0)),
		maxi(absi(int(a.g * 255.0) - int(b.g * 255.0)),
			absi(int(a.b * 255.0) - int(b.b * 255.0))))


func _s(c: Color) -> String:
	return "(%d,%d,%d)" % [int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0)]


func _check(ok: bool, claim: String) -> void:
	print("    %s %s" % ["PASS" if ok else "FAIL", claim])
	if not ok:
		_fails += 1


func _finish() -> void:
	if _fails > 0:
		printerr("check_bake_idempotent: FAIL — the bake changes colour when you dig somewhere else, so it is "
			+ "being re-processed rather than re-drawn")
		quit(1)
		return
	print("check_bake_idempotent: PASS — digging moves only what you dug")
	quit(0)
