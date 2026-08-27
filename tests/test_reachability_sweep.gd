extends "res://tests/test_base.gd"

## D0055. `test_bounds_invariant.gd` proves the safety net holds at two specific, pinned spots (the real
## shaft-wall mantle chain, sustained pressure at the left edge). This file is the director's other half
## of "fix 1": not a pinned repro, a SWEEP -- "the chamber's traversal path and the chamber's reachable
## space are different sets, and only the first is tested" was the root finding, so this runs a policy
## that never stops trying jump and mantle across the chamber's own full built width, not just the
## golden `ScriptedTraverse`'s narrow, landmark-timed route through it. "If a player can get somewhere,
## the suite should go there."
##
## D0059d: runs in-process, checking `_box_in_bounds` every tick (`test_bounds_invariant.gd`'s own
## pattern), NOT a subprocess grepping `push_error` line counts. The two are not equivalent: D0052's own
## rate-limiting latches to exactly one "left the world" line for BOTH a benign single touch-and-correct
## AND a body that never gets corrected and stays out of bounds forever -- a log-line count cannot tell
## them apart (confirmed directly: disabling `_enforce_grid_bounds`'s correction entirely still produced
## exactly 1 logged line). `_box_in_bounds`, checked fresh after every `tick()` returns, cannot be fooled
## this way: `_enforce_grid_bounds` corrects synchronously before `tick()` returns, so a body that is
## genuinely, always corrected is NEVER seen out of bounds by the caller, regardless of how many times
## the underlying violation fired internally. This is a strictly stronger assertion than the log-based
## one it replaces, not a loosened one -- it requires literally zero out-of-bounds sightings, same as
## `test_bounds_invariant.gd`'s two direct per-tick checks already require, including at the world's
## FAR edge (`HostileChamber`'s own `CAVE_END + 4`), which `fixture_aggressive_sweep_probe.gd` (now
## unused, deleted) never got clean enough progress to actually reach before D0059/D0059b landed.

const CELL: int = Heightfield.TERRAIN_CELL_PX


func _initialize() -> void:
	_test_aggressive_sweep_never_leaves_the_grid()
	_finish("reachability_sweep")


func _box_in_bounds(grid: TileGrid, body: Body) -> bool:
	return body._left_x() >= 0 and body._top_y() >= 0 and \
		body._right_x() <= grid.width * CELL * Fx.SCALE and body._bottom_y() <= grid.height * CELL * Fx.SCALE


## The policy: hold right, re-press jump every tick the body is grounded, hold mantle always -- not the
## golden `ScriptedTraverse`'s narrow, landmark-timed route, a player who just leans on jump and mantle
## the whole way through, contacting every wall, ceiling, and ledge the chamber has. Runs the full built
## width (`HostileChamber`'s grid extends to `CAVE_END + 4`), not just the scripted route's own
## `END_START` stopping point.
func _test_aggressive_sweep_never_leaves_the_grid() -> void:
	var grid: TileGrid = HostileChamber.build()
	# Spawn column needs real clearance from the grid's own left edge: the body is
	# `Body.WIDTH_PX / TERRAIN_CELL_PX` (4) cells wide, so a centre inside the first 2 columns puts the
	# LEFT edge past column 0 before a single tick runs -- not a real violation, a spawn that starts
	# already past the boundary. `HostileChamber.SPAWN_START + 4` clears it with margin.
	var spawn_col: int = HostileChamber.SPAWN_START + 4
	var body: Body = Body.new(
		spawn_col * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2,
		Fx.from_int(HostileChamber.FLOOR_ROW * CELL) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	var input: InputFrame = InputFrame.new()
	input.move_dir = 1
	input.mantle_hold = true
	var ever_out_of_bounds: bool = false
	for i: int in range(3000):
		input.jump_pressed = body.on_floor
		input.jump_held = true
		body.tick(input, grid)
		if not _box_in_bounds(grid, body):
			ever_out_of_bounds = true
	_check(not ever_out_of_bounds,
		"3000 ticks of continuous right+jump+mantle pressure across the chamber's full built width never leaves the grid's own [0,%d)x[0,%d) (Fx px)" %
		[grid.width * CELL * Fx.SCALE, grid.height * CELL * Fx.SCALE])
