extends SceneTree
## MICRO-BENCHMARK, not a harness layer — it asserts nothing and is not registered in run_harness.sh.
##
## The boot/load full bake costs ~1520ms after the bulk-fine-grid fix, and the question this answers is
## where that time actually goes, because the last guess (Callable dispatch) turned out to be 10% of it and
## the change built on that guess bought 175ms of 1695.
##
## `_paint_fine` runs once per fine cell — 262144 of them — and makes EIGHT FastNoiseLite.get_noise_2d()
## calls each: _huex, _huey, _noise, _patch, _grain, _grain2, _stone, _crack. That is 2.1M noise
## evaluations per bake. This times that loop alone, against an equivalent loop doing the surrounding
## arithmetic with the noise replaced by a constant, so the difference is the noise cost and nothing else.
##
##   tools/measure_bake_noise.gd   (run via: godot --headless --path . --script res://tools/...)

const FINE := preload("res://scenes/fine_terrain.gd")

const CELLS: int = 262144        ## the real fine-grid size: GRID_COLS*SUBDIV * GRID_ROWS*SUBDIV
const REPS: int = 3              ## best-of, so a scheduling blip cannot make either side look good


func _initialize() -> void:
	var fine: Object = FINE.new(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, 1337)
	var w: int = FactorySim.GRID_COLS * FINE.SUBDIV

	var noise_us: int = 1 << 62
	var plain_us: int = 1 << 62
	var sink: float = 0.0

	for _r: int in REPS:
		var t0: int = Time.get_ticks_usec()
		for i: int in CELLS:
			var fx: float = float(i % w)
			var fy: float = float(i / w)
			# The same eight samples _paint_fine takes, at the same coordinates and stretches.
			sink += fine._huex.get_noise_2d(fx, fy)
			sink += fine._huey.get_noise_2d(fx, fy)
			sink += fine._noise.get_noise_2d(fx * 0.35 + 500.0, fy * 0.35)
			sink += fine._patch.get_noise_2d(fx, fy)
			sink += fine._grain.get_noise_2d(fx * FINE.GRAIN_XSTRETCH, fy)
			sink += fine._grain2.get_noise_2d(fx * FINE.GRAIN_XSTRETCH, fy)
			sink += fine._stone.get_noise_2d(fx, fy)
			sink += fine._crack.get_noise_2d(fx * 1.4, fy)
		noise_us = mini(noise_us, Time.get_ticks_usec() - t0)

	for _r: int in REPS:
		var t0: int = Time.get_ticks_usec()
		for i: int in CELLS:
			var fx: float = float(i % w)
			var fy: float = float(i / w)
			# Identical loop shape and arithmetic, no noise. The difference isolates the calls.
			sink += fx + fy
			sink += fx + fy
			sink += fx * 0.35 + 500.0 + fy * 0.35
			sink += fx + fy
			sink += fx * FINE.GRAIN_XSTRETCH + fy
			sink += fx * FINE.GRAIN_XSTRETCH + fy
			sink += fx + fy
			sink += fx * 1.4 + fy
		plain_us = mini(plain_us, Time.get_ticks_usec() - t0)

	var noise_ms: float = noise_us / 1000.0
	var plain_ms: float = plain_us / 1000.0
	print("  loop WITH 8 noise samples/cell : %8.2f ms  (%.3f us/cell)" % [noise_ms, float(noise_us) / CELLS])
	print("  loop with the arithmetic only  : %8.2f ms  (%.3f us/cell)" % [plain_ms, float(plain_us) / CELLS])
	print("  the noise calls alone cost     : %8.2f ms  (%.3f us per get_noise_2d, %d calls)"
		% [noise_ms - plain_ms, float(noise_us - plain_us) / float(CELLS * 8), CELLS * 8])
	print("  (sink %.1f — printed so the loops cannot be optimised away)" % sink)
	quit(0)
