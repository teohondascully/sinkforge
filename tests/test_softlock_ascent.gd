extends "res://tests/test_base.gd"

## Gate 10's executable half (D0606). QUALITY.md's "no softlock" named no instrument at all; the scoped
## form it can honestly carry is ascent: from the deepest point a player can reach, a scripted policy
## gets back to the surface. Two probes over that form:
##
## 1. THE SELF-DUG SHAFT: a 28-column shaft in solid rock -- too wide to wall-mantle (measured: a
##    climb-only policy bounces off the wall face and never tops out). The escape is the pick: mine a
##    notch in the wall, mantle into it, repeat -- a dug staircase of standing notches. This is the
##    real softlock answer, because digging is the one verb that never runs out.
## 2. THE AUTHORED OPENING: the tutorial site's deepest authored floor (the supply room, ~7 m under the
##    pad), climbed back to standing on the surface with walk/jump/mantle alone -- the adit you can get
##    into, you can get out of.
##
## What this is NOT: a general reachability proof over arbitrary terrain (no such instrument exists;
## gate 10's own note says so). It is the two measured escape paths over the two deepest places the
## game hands a cold-start player.

const CELL: int = Heightfield.TERRAIN_CELL_PX
const SHAFT_COLS: int = 28
const SURFACE_ROW: int = 80   ## the synthetic world's surface, in terrain cells (20 m datum)
const SHAFT_FLOOR: int = 116  ## 9 m down


func _initialize() -> void:
	_test_a_wide_self_dug_shaft_returns_to_the_surface()
	_test_the_tutorial_sites_deepest_authored_floor_returns()
	_finish("softlock_ascent")


## Mine a mantle-notch out of the wall to the body's left: a cavity 5 columns deep and 10 rows tall
## whose floor is 6 rows above the body's feet. THE SCAN ORDER IS THE POLICY: bottom row first,
## farthest column first -- the staircase's next step is mined before the space above it, so the body
## can climb the dig while it is still being dug. Scanning top-first instead carves a sealed cavity the
## body cannot enter until it is finished, and the policy stalls inside the wall (measured, D0606).
## Returns whether there was anything left to mine -- when the block reads clear, the tick belongs to
## moving into the notch.
func _mine_notch(grid: TileGrid, mining: Mining, body: Body) -> bool:
	var feet_row: int = body._bottom_y() / (CELL * Fx.SCALE)
	var left_col: int = body._left_x() / (CELL * Fx.SCALE)
	var notch_floor: int = feet_row - 6   ## inside the mantle's 8-row reach, whole block inside the pick's
	for ty: int in range(notch_floor - 1, notch_floor - 11, -1):
		for tx: int in range(left_col - 5, left_col):
			var c := Vector2i(tx, ty)
			if grid.in_bounds(c) and grid.get_material(c) != &"":
				mining.mine(grid, body.pos_x, body.pos_y, c, true)
				return true
	return false


func _test_a_wide_self_dug_shaft_returns_to_the_surface() -> void:
	# A 256x128-cell world of hardrock below row 80 -- the real game's geometry (solid earth), not the
	# hostile chamber's floating slabs, whose under-floor is void by construction.
	var grid: TileGrid = TileGrid.new(256, 128, 42)
	for y: int in range(SURFACE_ROW, 128):
		for x: int in range(256):
			grid.set_material(Vector2i(x, y), &"hardrock")
	for y: int in range(SURFACE_ROW, SHAFT_FLOOR + 1):
		for x: int in range(104, 104 + SHAFT_COLS):
			grid.excavate(Vector2i(x, y))
	var body: Body = Body.new(
		(104 + SHAFT_COLS / 2) * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2,
		Fx.from_int(SHAFT_FLOOR * CELL) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	var mining: Mining = Mining.new()
	var input: InputFrame = InputFrame.new()
	var escaped_tick: int = -1
	for i: int in range(40000):
		input.move_dir = -1
		input.mantle_hold = true
		input.jump_pressed = body.on_floor
		input.jump_held = true
		if body.on_floor and _mine_notch(grid, mining, body):
			input.move_dir = 0
			input.jump_pressed = false
		body.tick(input, grid)
		var feet_row: int = body._bottom_y() / (CELL * Fx.SCALE)
		if body.on_floor and feet_row <= SURFACE_ROW:
			escaped_tick = i
			break
	_check(escaped_tick >= 0,
		"the dig-climb policy stands on the surface within 40000 ticks (escaped at %d)" % escaped_tick)


func _test_the_tutorial_sites_deepest_authored_floor_returns() -> void:
	var world: World = WorldSeeder.load_world(StrataData.SHALLOW_CLAY, 20260825)
	var items: Items = Items.new(world)
	var machines: Machines = Machines.new()
	_check(WorldSeeder.stamp(world, items, machines, &"tutorial", &"shallow_clay"),
		"the tutorial start stamps on the real site")
	var spawn: Vector2i = WorldSeeder.spawn_logic_cell(StartsRecords.RECORDS["tutorial"])
	# The supply room is the deepest authored open floor: logic dy +7 under the anchor.
	var body: Body = Body.new(
		(spawn.x + 2) * 16 * Fx.SCALE,
		Fx.from_int((spawn.y + 8) * 4 * CELL) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	var input: InputFrame = InputFrame.new()
	var surface_row: int = WorldSeeder.SURFACE_ROW_M * 4
	var stood_tick: int = -1
	for i: int in range(30000):
		input.move_dir = -1 if body._bottom_y() / (CELL * Fx.SCALE) > surface_row else 0
		input.mantle_hold = true
		input.jump_pressed = body.on_floor
		input.jump_held = true
		body.tick(input, world.grid)
		if body.on_floor and body._bottom_y() / (CELL * Fx.SCALE) <= surface_row:
			stood_tick = i
			break
	_check(stood_tick >= 0,
		"from the supply room's floor the body stands on the surface within 30000 ticks (stood at %d)" % stood_tick)
