extends SceneTree

## THE SNAPPED CAMERA HAS TO PRODUCE THE SAME FRAME, not just the same arithmetic.
##
## `check_pixel_snap` proves `MainView.snap_to_pixel` is correct as a function: the snapped position lands on
## the screen-pixel grid, a sub-pixel nudge yields the same snapped output, and the snap never moves the
## camera more than half a pixel. All true, all about the FUNCTION. Its docstring then said the end-to-end
## frame-diff -- render twice, assert identical terrain -- "lives in the headed fixture
## tools/capture_pixel_snap.gd". THAT FILE HAS NEVER EXISTED. Zero tree entries across every object in the
## repository, against a positive control finding check_pixel_snap.gd 205 times.
##
## So nothing verified that correct snap arithmetic actually reaches the framebuffer. A camera assignment
## that bypassed the snap, a viewport that resampled after it, or a terrain shader sampling in unsnapped
## space would all leave check_pixel_snap perfectly green while the terrain crawled. This is that missing
## layer, and it is deliberately end-to-end: it reads `get_texture().get_image()` and nothing else.
##
## TWO ARMS, BECAUSE ONE WOULD PROVE NOTHING. The scene animates -- dust motes, the veil, the body -- so two
## captures never match byte for byte and a bare "they differ" verdict is unreadable. Both arms therefore
## advance the same number of frames from the same baseline and differ ONLY in how far the follow target
## moved:
##
##   SAME BUCKET   target nudged 0.4 screen px, which rounds to the same pixel -> the camera must not move
##                 at all, so the only difference is animation. This is the noise floor.
##   NEXT BUCKET   target nudged a full screen pixel -> the camera moves exactly 1px and the terrain must
##                 shift with it. This is the positive control, and it is what makes the first number mean
##                 something: without it, "few pixels differ" is equally consistent with a frame-diff that
##                 cannot see anything at all.
##
## Each arm shoots its OWN baseline immediately before its own displaced frame, so both carry exactly two
## frames of animation. Sharing one baseline would have put the control four frames from it and the noise
## arm two, which quietly charges the control for drift it did not cause.
##
## AND IT JUDGES ONLY STRUCTURED PIXELS. A one-pixel shift can physically only show where the picture
## already varies horizontally; over flat sky or flat rock the shifted frame is the same frame. Counting
## those pixels does not measure the camera, it measures the dust drifting across them -- it adds noise to
## both arms and signal to neither. The population is therefore the pixels whose baseline neighbourhood
## varies by more than the tolerance, which is exactly the set where the property is falsifiable.
##
## The assertion is the RATIO, not either count. A snap that silently stopped working shows up as the two
## arms converging.
##
## MEASURED, four clean runs: noise arm 0.29 / 0.32 / 0.54 / 1.23 %, control arm 52.24 / 52.39 / 52.58 /
## 52.61 %. The control is stable to a tenth of a point; the noise arm swings fourfold with wherever the
## dust happens to be, which is why the cap sits at 2 % -- 1.6x over the worst run seen, not fitted to the
## best. The separation the layer actually rests on is 43x at worst.
##
## PROVED BY BREAKING IT: with `snap_to_pixel` returning its argument unchanged, the noise arm goes to
## 16.66 % and the layer exits 1. Both assertions fire -- the cap, and then the control ratio collapsing to
## 3.1x, which is the convergence the paragraph above predicts. That second failure is the useful one: it
## is what a frame-diff that has stopped discriminating looks like from the inside.
##
##   godot --path . --script res://tools/check_snap_frame.gd

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 70
const SUB_PX: float = 0.4            ## screen px — inside the bucket, must round away
const FULL_PX: float = 1.0           ## screen px — one bucket over, must show
const DIFF_TOL: int = 8              ## per-channel level a pixel must exceed to count as changed
const STRUCT_TOL: float = 6.0        ## luma levels across 2px a pixel needs to be able to reveal a shift
const NOISE_CAP: float = 0.02        ## same-bucket changed fraction may not exceed this
const MIN_STRUCTURED: int = 20000    ## the judged population may not quietly collapse
const CONTROL_RATIO: float = 4.0     ## next-bucket must differ at least this many times more than same
const BAND_TOP: float = 0.16         ## skip the HUD, same crop both arms
const BAND_BOTTOM: float = 0.80

var _fail: int = 0

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("check_snap_frame: SKIP — needs a real display to render a frame")
		quit(42)
		return
	MainView.dev_start = false
	await _run()

func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var zoom: float = main._current_zoom()

	# START ON THE GRID. The property is "targets inside one pixel bucket render identically", so the
	# baseline has to sit at a known place in its bucket -- nudging 0.4px from an arbitrary fractional
	# position can legitimately cross a rounding boundary, and that would be the snap working, not failing.
	var base: Vector2 = MainView.snap_to_pixel(main._cam_pos, zoom)
	main._cam_pos = base
	var same_r: Array = await _arm(main, base, SUB_PX, zoom)
	var over_r: Array = await _arm(main, base, FULL_PX, zoom)
	var same: int = int(same_r[0])
	var over: int = int(over_r[0])

	print("== the snapped camera has to produce the same frame ==")
	print("  zoom %.2f, band rows %.0f%%..%.0f%%, changed at >%d levels, structured at >%.0f levels"
		% [zoom, BAND_TOP * 100.0, BAND_BOTTOM * 100.0, DIFF_TOL, STRUCT_TOL])
	var same_f: float = float(same) / maxf(1.0, float(same_r[1]))
	print("  SAME bucket (+%.1fpx): %d of %d structured pixels changed (%.2f%%)"
		% [SUB_PX, same, int(same_r[1]), same_f * 100.0])
	print("  NEXT bucket (+%.1fpx): %d of %d structured pixels changed (%.2f%%)"
		% [FULL_PX, over, int(over_r[1]), float(over) / maxf(1.0, float(over_r[1])) * 100.0])

	# POPULATION FLOOR, and I found the need for it by auditing other layers and landing on my own. Every
	# number above is a fraction of `structured`, and nothing yet asserted that `structured` is a real
	# population. If the crop drifted onto flat sky, or the structure threshold rose past the terrain's
	# actual contrast, the denominator would shrink toward nothing and BOTH arms would go quiet together --
	# a layer reporting 0.00% and 0.00% with a control that cannot fire. Measured at ~155,400 across four
	# runs, stable to a third of a percent; the floor is 20,000, an order below the observed and a long way
	# above a collapse. It is a veto, not a scaling factor: it runs BEFORE either ratio is judged.
	_check(int(same_r[1]) >= MIN_STRUCTURED and int(over_r[1]) >= MIN_STRUCTURED,
		"there is enough structure on screen to see a shift at all (%d and %d pixels, floor %d)"
		% [int(same_r[1]), int(over_r[1]), MIN_STRUCTURED])
	if int(same_r[1]) < MIN_STRUCTURED or int(over_r[1]) < MIN_STRUCTURED:
		printerr("    ...so the two fractions below are shares of nearly nothing and mean nothing.")
		_fail += 1
		printerr("check_snap_frame: %d FAILURE(S)" % _fail)
		quit(1)
		return
	_check(same_f <= NOISE_CAP,
		"a target inside one pixel bucket leaves the frame alone — %.2f%% changed (cap %.2f%%)"
		% [same_f * 100.0, NOISE_CAP * 100.0])
	# NON-VACUITY. If the control cannot move the picture either, the first number is not a pass, it is a
	# frame-diff that sees nothing — which is the exact defect this layer exists because of.
	_check(over > same * int(CONTROL_RATIO) and over > 0,
		"CONTROL: one bucket over DOES move the picture — %d changed against %d (needs %.0fx)"
		% [over, same, CONTROL_RATIO])
	if _fail > 0:
		printerr("check_snap_frame: %d FAILURE(S)" % _fail)
	quit(1 if _fail > 0 else 0)

func _shoot(main: MainView, target: Vector2, zoom: float) -> Image:
	main._cam_pos = target
	main._camera.global_position = MainView.snap_to_pixel(target, zoom)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return get_root().get_texture().get_image()

## One arm: its own baseline, then the same scene with the follow target moved `nudge` screen pixels.
## Returns [changed, structured] — both counted over the structured population only.
func _arm(main: MainView, base: Vector2, nudge: float, zoom: float) -> Array:
	var a: Image = await _shoot(main, base, zoom)
	var b: Image = await _shoot(main, base + Vector2(nudge / zoom, 0.0), zoom)
	var y0: int = int(float(a.get_height()) * BAND_TOP)
	var y1: int = int(float(a.get_height()) * BAND_BOTTOM)
	var changed: int = 0
	var structured: int = 0
	for y: int in range(y0, y1):
		for x: int in range(1, a.get_width() - 1):
			if absf(_luma(a, x + 1, y) - _luma(a, x - 1, y)) <= STRUCT_TOL:
				continue
			structured += 1
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			if maxf(maxf(absf(p.r - q.r), absf(p.g - q.g)), absf(p.b - q.b)) * 255.0 > float(DIFF_TOL):
				changed += 1
	return [changed, structured]

func _luma(img: Image, x: int, y: int) -> float:
	var c: Color = img.get_pixel(x, y)
	return (c.r * 0.299 + c.g * 0.587 + c.b * 0.114) * 255.0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		printerr("  FAIL: %s" % msg)
		_fail += 1
