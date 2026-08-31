extends "res://tests/test_base.gd"

## Slice 2, D0214. `interface/interface.gd` is `docs/ARCHITECTURE.md` §5's L2 door, and this suite pins
## the three properties that make it a door rather than a wrapper. Two of them are about what it REFUSES
## to do, which is the part a happy-path test would never notice:
##
##   1. `observe()` is pure. Called any number of times, in any order, it leaves `state_signature()`
##      byte-identical. A door that advanced the world when read would make every consumer's frame rate
##      part of the simulation.
##   2. An `Observation` holds no reference into `sim/`. Mutating the grid AFTER observing must not
##      change what the observation says, or the envelope is decorative -- a consumer holding a live
##      `TileGrid` can read any cell it likes and no filter in `interface.gd` could stop it. This is the
##      invariant `interface/MODULE.md` states as "never bypassable by reaching around it", tested by
##      actually trying to reach around it.
##   3. A rejected command changes NOTHING. Not a partial mine, not a tick. `state_signature()` again.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_interface.gd

const FLOOR_ROW: int = 20
const GRID_W: int = 40
const GRID_H: int = 30


func _initialize() -> void:
	_test_observe_is_pure()
	_test_an_observation_does_not_track_the_grid_it_came_from()
	_test_the_window_is_what_bounds_a_read()
	_test_a_move_command_advances_exactly_one_tick()
	_test_every_rejection_is_named_and_changes_nothing()
	_test_a_mine_command_inside_reach_actually_breaks_ground()
	_test_the_wall_plane_is_its_own_plane()
	_test_the_surface_answers_in_fx_and_only_from_inside_the_window()
	_finish("interface")


## A solid floor from `FLOOR_ROW` down, open above, with the body standing on it.
func _build() -> Array:
	var grid: TileGrid = TileGrid.new(GRID_W, GRID_H, 1)
	for col: int in range(0, GRID_W):
		for row: int in range(FLOOR_ROW, GRID_H):
			grid.set_material(Vector2i(col, row), &"clay")
	var body: Body = Body.new(
		Fx.from_int(GRID_W * Heightfield.TERRAIN_CELL_PX / 2),
		Fx.from_int(FLOOR_ROW * Heightfield.TERRAIN_CELL_PX) - (Body.HEIGHT_PX * Fx.SCALE) / 2)
	var iface: Interface = Interface.new(grid, body, Mining.new())
	for _i: int in 10:
		iface.apply(Command.move(InputFrame.new()))
	return [grid, body, iface]


func _sig(grid: TileGrid, body: Body) -> String:
	return body.state_signature() + "||" + grid.state_signature()


func _test_observe_is_pure() -> void:
	var parts: Array = _build()
	var grid: TileGrid = parts[0]
	var body: Body = parts[1]
	var iface: Interface = parts[2]
	var before: String = _sig(grid, body)
	for _i: int in 25:
		iface.observe(Interface.Envelope.oracle_over(grid))
	_check(_sig(grid, body) == before, "25 observe() calls leave the sim state byte-identical")


## The reach-around test, and the reason `Observation` copies instead of holding a reference. If it held
## the grid, the excavation below would show through and this would fail.
func _test_an_observation_does_not_track_the_grid_it_came_from() -> void:
	var parts: Array = _build()
	var grid: TileGrid = parts[0]
	var iface: Interface = parts[2]
	var target: Vector2i = Vector2i(2, FLOOR_ROW)
	var o: Interface.Observation = iface.observe(Interface.Envelope.oracle_over(grid))
	_check(o.solid_at(target), "the observation sees the floor cell as solid to begin with")
	grid.excavate(target)
	_check(not grid.is_solid(target), "control: the grid itself really did change")
	_check(o.solid_at(target),
		"the observation taken BEFORE the change still reports solid -- it is a value, not a view")
	var after: Interface.Observation = iface.observe(Interface.Envelope.oracle_over(grid))
	_check(not after.solid_at(target), "and a fresh observation does see the change")


## The envelope's one live dimension. A cell outside the window reads as empty rather than as its real
## material, which is what a fog filter will be built on; asserting it now means the bypass cannot be
## introduced later without a red test.
func _test_the_window_is_what_bounds_a_read() -> void:
	var parts: Array = _build()
	var grid: TileGrid = parts[0]
	var iface: Interface = parts[2]
	var inside: Vector2i = Vector2i(5, FLOOR_ROW)
	var outside: Vector2i = Vector2i(30, FLOOR_ROW)
	var o: Interface.Observation = iface.observe(Interface.Envelope.new(Rect2i(0, 0, 10, GRID_H)))
	_check(grid.is_solid(outside), "control: the out-of-window cell IS solid in the grid")
	_check(o.solid_at(inside), "a cell inside the window reads its real material")
	_check(not o.solid_at(outside), "a cell outside it does not, even though the grid says solid")
	_check(not o.in_window(outside) and o.in_window(inside),
		"and `in_window` is what tells the two cases apart, so 'empty' is never confused with 'unseen'")


func _test_a_move_command_advances_exactly_one_tick() -> void:
	var parts: Array = _build()
	var grid: TileGrid = parts[0]
	var body: Body = parts[1]
	var iface: Interface = parts[2]
	var before_tick: int = iface.observe(Interface.Envelope.oracle_over(grid)).tick
	var input: InputFrame = InputFrame.new()
	input.move_dir = 1
	var r: Interface.Result = iface.apply(Command.move(input))
	_check(r.ok and r.reason == &"", "a move command is accepted with no reason")
	_check(iface.observe(Interface.Envelope.oracle_over(grid)).tick == before_tick + 1,
		"and advances the tick counter by exactly one")
	_check(body.vel_x > 0, "and the body actually integrated the input (vel_x = %d)" % body.vel_x)


## Each rejection posed alone, with the other two conditions held valid, so no case can pass on another's
## behalf. `docs/ARCHITECTURE.md` §5 makes these reasons telemetry, which is why they are named constants
## and why a silent no-op inside `Mining` would not have been good enough.
func _test_every_rejection_is_named_and_changes_nothing() -> void:
	var parts: Array = _build()
	var grid: TileGrid = parts[0]
	var body: Body = parts[1]
	var iface: Interface = parts[2]
	var cases: Array = [
		{"cell": Vector2i(-1, FLOOR_ROW), "want": Interface.REJECT_OUT_OF_BOUNDS, "label": "off the grid"},
		{"cell": Vector2i(Body._px_to_cell(body.pos_x), 0), "want": Interface.REJECT_NOT_SOLID, "label": "open air overhead"},
		{"cell": Vector2i(GRID_W - 1, FLOOR_ROW), "want": Interface.REJECT_OUT_OF_REACH, "label": "solid floor across the map"},
	]
	## Every assertion below lives INSIDE the loop, so an empty `cases` array would run zero of them and
	## report success -- the D0245 shape, arriving as a loop that never executes rather than as an
	## aggregate over nothing. Checked before the loop, where it cannot be forgotten to depend on it.
	_check_over(cases.size(), true,
		"the rejection cases are actually posed, so the checks inside the loop have something to run on")
	for c: Dictionary in cases:
		var before: String = _sig(grid, body)
		var r: Interface.Result = iface.apply(Command.mine(c["cell"]))
		_check(not r.ok and r.reason == c["want"],
			"mining %s is rejected as `%s` (got ok=%s reason=%s)" % [c["label"], c["want"], r.ok, r.reason])
		_check(_sig(grid, body) == before, "and the rejected `%s` command changed nothing at all" % c["label"])


## The positive control for the three rejections above: without it, "rejected" could be the only thing
## this door ever does and every check in the previous test would still pass.
##
## `clay`, not a made-up name. The first version of this test filled the grid with `&"earth"`, which is a
## LEGACY material id and not one of this build's seven -- `TileGrid.is_solid` is true for any non-empty
## string, so the fixture looked right, but `Mining.break_cost` fell through to zero and the cell broke on
## the first tick. The charge path was never exercised and the test said it was. Hence the budget control
## below: a break cost of one tick is now a failure, not a pass.
func _test_a_mine_command_inside_reach_actually_breaks_ground() -> void:
	var parts: Array = _build()
	var grid: TileGrid = parts[0]
	var body: Body = parts[1]
	var iface: Interface = parts[2]
	var target: Vector2i = Vector2i(Body._px_to_cell(body.pos_x), FLOOR_ROW)
	_check(Mining.in_reach(body.pos_x, body.pos_y, target), "control: the cell under the body is in reach")
	var accepted: int = 0
	var budget: int = Mining.ticks_to_break(&"clay") * 4
	_check(budget > 4, "control: clay is a real material with a real break cost (%d ticks budgeted)" % budget)
	for _i: int in budget:
		if iface.apply(Command.mine(target)).ok:
			accepted += 1
		if not grid.is_solid(target):
			break
	_check(accepted > 1, "the in-reach mine command is accepted repeatedly while charging (%d times)" % accepted)
	_check(not grid.is_solid(target), "and holding it eventually breaks the cell")


## The wall plane must be the WALL plane. The characteristic failure of adding a second plane that
## shares the block plane's encoding is wiring it to the same getter: every assertion about presence,
## shape and legend still passes, and the field is a duplicate of the one beside it.
##
## So the wall material is deliberately DIFFERENT from the block material in the same cell, and the
## discriminating assertion is `wall_at != material_at` -- which `get_material` in place of `get_wall`
## cannot satisfy. Excavating then checks the property the plane exists for: `excavate()` REVEALS the
## wall rather than erasing it, so the cell goes empty in one plane and stays in the other.
func _test_the_wall_plane_is_its_own_plane() -> void:
	var parts: Array = _build()
	var grid: TileGrid = parts[0]
	var iface: Interface = parts[2]
	var c := Vector2i(GRID_W / 2, FLOOR_ROW + 2)
	grid.set_wall(c, &"deepstone")
	var o: Interface.Observation = iface.observe(Interface.Envelope.oracle_over(grid))
	_check(o.material_at(c) == &"clay", "control: the block plane still reads its own material")
	_check(o.wall_at(c) == &"deepstone",
		"the wall plane reads the wall material (%s)" % o.wall_at(c))
	_check(o.wall_at(c) != o.material_at(c),
		"DISCRIMINATOR: wall and block disagree in the same cell, so the wall plane is not a copy "
		+ "of the block plane -- get_material() in place of get_wall() would fail here and nowhere else")
	grid.excavate(c)
	var after: Interface.Observation = iface.observe(Interface.Envelope.oracle_over(grid))
	_check(after.material_at(c) == &"" and after.wall_at(c) == &"deepstone",
		"excavate empties the block and REVEALS the wall: block=%s wall=%s"
		% [after.material_at(c), after.wall_at(c)])
	var outside := Vector2i(0, 0)
	var narrow: Interface.Observation = iface.observe(
		Interface.Envelope.new(Rect2i(GRID_W / 2 - 1, FLOOR_ROW, 3, 3)))
	_check(narrow.wall_at(outside) == &"" and not narrow.in_window(outside),
		"a wall outside the window reads &\"\", the same conflation material_at makes on purpose")


## The surface is an `Fx` world-y and it is scanned inside the window only.
##
## Two assertions carry this. The first pins the UNIT: a row index would read 20, an unscaled pixel
## height 80, and the correct answer is 80 << 16 -- three values a laxer check would not separate.
## The second poses the envelope: a window sitting entirely ABOVE the floor must report NO_FLOOR, not
## the floor it could have found by scanning past its own edge, because a column the observer was not
## given cells for is a column it cannot answer about.
func _test_the_surface_answers_in_fx_and_only_from_inside_the_window() -> void:
	var parts: Array = _build()
	var grid: TileGrid = parts[0]
	var iface: Interface = parts[2]
	var col: int = GRID_W / 2
	var o: Interface.Observation = iface.observe(Interface.Envelope.oracle_over(grid))
	var want: int = Fx.from_int(FLOOR_ROW * Heightfield.TERRAIN_CELL_PX)
	_check(o.surface_y_at_terrain_col(col) == want,
		"the surface is an Fx world-y: got %d, want %d (a row index would be %d, raw px %d)"
		% [o.surface_y_at_terrain_col(col), want, FLOOR_ROW, FLOOR_ROW * Heightfield.TERRAIN_CELL_PX])
	var above: Interface.Observation = iface.observe(
		Interface.Envelope.new(Rect2i(0, 0, GRID_W, FLOOR_ROW - 2)))
	_check(grid.is_solid(Vector2i(col, FLOOR_ROW)),
		"control: the floor this window cannot see IS solid in the grid")
	_check(above.surface_y_at_terrain_col(col) == Heightfield.NO_FLOOR,
		"a window above the floor reports NO_FLOOR rather than scanning past its own edge (got %d)"
		% above.surface_y_at_terrain_col(col))
	_check(o.surface_y_at_terrain_col(GRID_W + 5) == Heightfield.NO_FLOOR,
		"and a column outside the window entirely is NO_FLOOR, not an out-of-range index")
