extends SceneTree

## D0135's own follow-up diagnosis: traces `resolve_floor`'s (`sim/body/vertical_resolve.gd`) internal
## decision at every real resolve_floor-attributed `grounded_no_floor` violation, WITHOUT modifying
## `resolve_floor`/`vertical_resolve.gd` at all -- every quantity this file prints is independently
## RECOMPUTED from outside, calling `Heightfield`'s own public static functions with the exact same
## parameters `resolve_floor` itself uses, mirroring D0123's own instrumented-replay methodology for the
## dig staircase defect. Diagnose-and-report only, per explicit instruction: `resolve_floor` and
## `vertical_resolve.gd` are untouched by this investigation.
##
## NOT part of the `tests/test_*.gd` glob any CI step iterates -- a one-off diagnostic script, matching
## `fixture_*.gd`'s own established "not a real suite" convention, run by hand via
## `godot --headless --path . --script res://tests/diag_resolve_floor.gd -- --seeds=N --ticks=N [--no-dig]`.
## Reuses `fixture_body_fuzz_probe.gd`'s own spawn/RNG/dig-roll structure exactly, so it reproduces the
## IDENTICAL trajectories D0132's own telemetry run already measured (55/59 dig-on, 29/32 dig-off).

const CELL: int = Heightfield.TERRAIN_CELL_PX
const DEFAULT_NUM_SEEDS: int = 1000
const DEFAULT_TICKS_PER_SEED: int = 1500

var NUM_SEEDS: int = DEFAULT_NUM_SEEDS
var TICKS_PER_SEED: int = DEFAULT_TICKS_PER_SEED
var DIG_DISABLED: bool = false


## The two columns and heights `Heightfield.surface_y_at_x` would blend between for `x_fx` -- this
## REPRODUCES its own column-selection math rather than extracting it, so this file adds zero coupling
## to `heightfield.gd`'s own internals; if that math ever changes, this diagnostic script goes stale
## harmlessly (a one-off investigation aid), not silently wrong.
func _straddle(grid: TileGrid, x_fx: int, scan_from: int, max_rows: int) -> Dictionary:
	var cell_px: int = CELL * Fx.SCALE
	var col: int = int(floor(float(x_fx) / float(cell_px)))
	var col_center: int = col * cell_px + cell_px / 2
	var left_col: int = (col - 1) if x_fx < col_center else col
	var right_col: int = left_col + 1
	var left_h: int = Heightfield.column_surface_y(grid, left_col, scan_from, max_rows)
	var right_h: int = Heightfield.column_surface_y(grid, right_col, scan_from, max_rows)
	return {"left_col": left_col, "right_col": right_col, "left_h": left_h, "right_h": right_h}


func _diagnose(body: Body, grid: TileGrid, seed: int, tick: int) -> void:
	var row: int = Body._px_to_cell(body._bottom_y())
	var scan_from: int = maxi(0, row - 2)
	var samples: Dictionary = {
		"left": body._left_x() + Fx.SCALE,
		"right": body._right_x() - Fx.SCALE,
		"center": body.pos_x,
	}
	var heights: Dictionary = {}
	for name: String in samples:
		heights[name] = Heightfield.surface_y_at_x(grid, samples[name], scan_from, Body.FLOOR_SCAN_ROWS)
	var winner: String = "center"
	if heights["left"] <= heights["right"] and heights["left"] <= heights["center"]:
		winner = "left"
	elif heights["right"] <= heights["left"] and heights["right"] <= heights["center"]:
		winner = "right"
	var st: Dictionary = _straddle(grid, samples[winner], scan_from, Body.FLOOR_SCAN_ROWS)
	var transition: bool = st["left_h"] != st["right_h"]
	var left_col: int = Body._px_to_cell(body._left_x())
	var right_col: int = Body._px_to_cell(body._right_x() - 1)
	var solid_flags: Array = []
	for col: int in range(left_col, right_col + 1):
		solid_flags.append("1" if grid.is_solid(Vector2i(col, row)) else "0")
	print(("RESOLVE_FLOOR_DIAG seed=%d tick=%d row=%d winner=%s s_left=%d s_right=%d s_center=%d " +
		"straddle_cols=(%d,%d) straddle_h=(%d,%d) transition=%s footprint_cols=(%d,%d) footprint_solid=%s") %
		[seed, tick, row, winner, heights["left"], heights["right"], heights["center"],
		st["left_col"], st["right_col"], st["left_h"], st["right_h"], transition,
		left_col, right_col, ",".join(solid_flags)])


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			NUM_SEEDS = int(arg.trim_prefix("--seeds="))
		elif arg.begins_with("--ticks="):
			TICKS_PER_SEED = int(arg.trim_prefix("--ticks="))
		elif arg == "--no-dig":
			DIG_DISABLED = true
	var grid: TileGrid = HostileChamber.build()
	var diagnosed: int = 0
	for seed: int in range(NUM_SEEDS):
		var rng: SplitRng = SplitRng.new(seed)
		var body: Body = FuzzDriverCommon.spawn_body()
		for tick: int in range(TICKS_PER_SEED):
			body.tick(FuzzDriverCommon.random_input(rng, DIG_DISABLED), grid)
			if body.floor_source_this_tick == &"resolve_floor" and not PropertyChecks.grounded_implies_solid_beneath(body, grid):
				_diagnose(body, grid, seed, tick)
				diagnosed += 1
	print("RESOLVE_FLOOR_DIAG_SUMMARY seeds=%d ticks_per_seed=%d diagnosed=%d dig_disabled=%s" %
		[NUM_SEEDS, TICKS_PER_SEED, diagnosed, DIG_DISABLED])
	quit(0)
