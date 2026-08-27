extends SceneTree

## Standalone subprocess for `test_reachability_sweep.gd` (D0055) -- `push_error` from the same script
## that provoked it cannot be counted in-process (the same reason `fixture_div_by_zero_probe.gd` and
## `fixture_bounds_pressure_probe.gd` exist), so this runs the sweep for real and the caller counts
## occurrences in its own captured stderr.
##
## The policy: hold right, re-press jump every tick the body is grounded, hold mantle always. Not the
## golden `ScriptedTraverse`'s narrow, landmark-timed route -- a player who just leans on jump and mantle
## the whole way through, contacting every wall, ceiling, and ledge the chamber has rather than only the
## ones the scripted route's own timing happens to touch. Runs the full built width (`HostileChamber`'s
## grid extends to `CAVE_END + 4`), not just the scripted route's own `END_START` stopping point.

func _initialize() -> void:
	var grid: TileGrid = HostileChamber.build()
	# Spawn column needs real clearance from the grid's own left edge: the body is
	# `Body.WIDTH_PX / TERRAIN_CELL_PX` (4) cells wide, so a centre inside the first 2 columns puts the
	# LEFT edge past column 0 before a single tick runs -- not a real violation, a spawn that starts
	# already past the boundary. `HostileChamber.SPAWN_START + 4` clears it with margin.
	var spawn_col: int = HostileChamber.SPAWN_START + 4
	var body: Body = Body.new(
		spawn_col * Heightfield.TERRAIN_CELL_PX * Fx.SCALE + (Heightfield.TERRAIN_CELL_PX * Fx.SCALE) / 2,
		Fx.from_int(HostileChamber.FLOOR_ROW * Heightfield.TERRAIN_CELL_PX) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	var input: InputFrame = InputFrame.new()
	input.move_dir = 1
	input.mantle_hold = true
	for i: int in range(3000):
		input.jump_pressed = body.on_floor
		input.jump_held = true
		body.tick(input, grid)
	quit(0)
