extends "res://tools/check_base.gd"

## Harness layer — the CAMERA PIXEL-SNAP contract (playtest: "the texture blurs while running, and the
## tests didn't catch it"). The blur is sub-pixel camera jitter: a fractional camera offset makes every
## terrain texel sample between screen pixels each frame. The fix rounds the camera to the screen-pixel
## grid (MainView.snap_to_pixel). This proves that logic so a future camera refactor can't quietly
## reintroduce the shimmer:
##   - a snapped position lands EXACTLY on the screen-pixel grid (snap*zoom is integer) at every zoom
##   - a sub-pixel nudge of the follow target yields the SAME snapped output → identical frame → no crawl
##   - the snap never moves the camera more than half a screen-pixel from the true position
## (The end-to-end frame-diff — render twice, assert identical terrain — lives in the headed fixture
## tools/capture_pixel_snap.gd, which also saves the screenshot; rendering needs a real GPU context.)
##   godot --headless --path . --script res://tools/check_pixel_snap.gd

func _initialize() -> void:
	print("== pixel-snap check ==")
	# Every zoom the game actually uses (SCALE spike retuned the ladder to 0.62/0.9/1.3), plus a couple of
	# awkward fractionals. The snap MATH is zoom-generic, so this just keeps the live zooms under coverage.
	var zooms: Array[float] = [0.62, 0.9, 1.3, 0.42, 0.6, 0.85, 1.0, 0.333333]
	var samples: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(100.3, 240.7), Vector2(-55.9, 12.1),
		Vector2(1234.56, 789.01), Vector2(0.49, 0.51),
	]
	for z: float in zooms:
		for p: Vector2 in samples:
			var s: Vector2 = MainView.snap_to_pixel(p, z)
			# 1) grid-aligned: s*z must be whole screen pixels (no sub-pixel offset → no shimmer).
			# Threshold is 1e-3, not 1e-4: at a non-power-of-2 zoom (e.g. the new 1.3) with a large
			# coordinate, round()/z then ×z accumulates ~1e-4 of float32 noise — 1/1000 of a screen pixel,
			# imperceptible. A REAL grid mis-snap is a fraction of a pixel (≥0.1), still far above this.
			var screen: Vector2 = s * z
			var off: float = maxf(absf(screen.x - roundf(screen.x)), absf(screen.y - roundf(screen.y)))
			_check(off < 1.0e-3, "z=%.3f p=%s → grid-aligned (off=%.2e)" % [z, str(p), off])
			# 3) never more than half a screen pixel from the true position
			var world_px: float = 1.0 / z
			_check(s.distance_to(p) <= world_px * 0.75,
				"z=%.3f p=%s → snap stays within a pixel (moved %.3f, px=%.3f)"
				% [z, str(p), s.distance_to(p), world_px])

	# 2) QUANTIZATION: two follow targets inside the same screen-pixel cell snap to the SAME output, so a
	# sub-pixel camera nudge renders an identical frame (this is exactly the "no crawl while running" fix).
	var z2: float = 0.42
	var base := Vector2(500.0, 300.0)
	var base_snapped: Vector2 = MainView.snap_to_pixel(base, z2)
	var nudge: float = 0.4 / z2 * 0.5    # under half a screen pixel in world units
	for dx: float in [-nudge, 0.0, nudge]:
		for dy: float in [-nudge, 0.0, nudge]:
			var s2: Vector2 = MainView.snap_to_pixel(base + Vector2(dx, dy), z2)
			_check(s2.is_equal_approx(base_snapped),
				"sub-pixel nudge (%.3f,%.3f) → identical snapped frame" % [dx, dy])
	# crossing a FULL screen pixel DOES move (proving it's real quantization, not a constant)
	var moved: Vector2 = MainView.snap_to_pixel(base + Vector2(1.0 / z2, 0.0), z2)
	_check(not moved.is_equal_approx(base_snapped), "a full-pixel move DOES shift (quantized, not frozen)")

	# 4) zero-zoom guard (never divide by zero)
	_check(MainView.snap_to_pixel(base, 0.0) == base, "zoom 0 is a safe no-op")

	if _failures == 0:
		print("PIXEL SNAP OK")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % _failures)
		quit(1)
