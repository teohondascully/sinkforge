extends "res://tests/test_base.gd"

## LOOSE MATERIAL FALLING ONTO THE BODY (D0562, D0566). `Slump` writes solid cells into space the body
## may be standing in: `Slump.target` asks `TileGrid.is_solid` and the body is not in the grid, so
## nothing in the automaton can see it. That is deliberate -- terrain does not negotiate with the player
## -- but it makes one question load-bearing, and it is the question that decides whether "undermining
## drops a mass" is a feature or a way to lose a session:
##
##   **Can a collapse bury the body in rock it cannot get out of?**
##
## The answer is no, and the reason is `VerticalResolve.grid_floor_backstop`, which depenetrates a body
## found inside solid ground (D0206, `tests/test_footprint_grounding.gd`). That path predates the slump
## by months and was written for a different cause. This suite is what makes it a guarantee rather than
## a coincidence: it stands a body under falling earth, runs both systems on the same ticks, and asserts
## the overlap is zero at EVERY tick, not merely at the end.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_slump_body.gd

const W: int = 40
const H: int = 40
const FLOOR_ROW: int = 30
const COL: int = 10
const LOOSE := &"clay"
const FIRM := &"hardrock"


func _initialize() -> void:
	_test_a_cell_dropped_on_the_body_never_leaves_it_inside_rock()
	_test_a_collapsing_roof_never_leaves_it_inside_rock()
	_test_the_body_is_pushed_up_not_down()
	_finish("slump_body")


func _floor() -> TileGrid:
	var grid: TileGrid = TileGrid.new(W, H, 5)
	for col: int in W:
		for row: int in range(FLOOR_ROW, H):
			grid.set_material(Vector2i(col, row), FIRM)
	return grid


## A body standing on the floor at `COL`, dropped there first so its feet are where the resolver puts
## them and not where this file guessed.
func _standing(grid: TileGrid, spawn_row: int = FLOOR_ROW - 8) -> Body:
	var body: Body = Body.new(Fx.from_int(COL * Mining.CELL_PX), Fx.from_int(spawn_row * Mining.CELL_PX))
	var input: InputFrame = InputFrame.new()
	for _i: int in 90:
		body.tick(input, grid)
	return body


## Run both systems on the same ticks and return the worst overlap seen at ANY tick. Checking only the
## final state would pass a run that buried the body for two seconds and then spat it out.
func _run(grid: TileGrid, body: Body, s: Slump, ticks: int) -> int:
	var water: WaterPlane = WaterPlane.new()
	var input: InputFrame = InputFrame.new()
	var worst: int = 0
	for _i: int in ticks:
		s.settle(grid, water, MineHold.body_cells(body))
		body.tick(input, grid)
		worst = maxi(worst, PropertyChecks.solid_overlap_count(body, grid))
	return worst


func _test_a_cell_dropped_on_the_body_never_leaves_it_inside_rock() -> void:
	var grid: TileGrid = _floor()
	var body: Body = _standing(grid)
	grid.set_material(Vector2i(COL, FLOOR_ROW - 15), LOOSE)   # well above the head, unsupported
	var s: Slump = Slump.new()
	s.after_break(grid, [Vector2i(COL, FLOOR_ROW - 14)])
	var worst: int = _run(grid, body, s, 300)
	print("  [OBSERVED] one cell dropped on a standing body: worst overlap over 300 ticks = %d" % worst)
	_check(worst == 0, "a cell landing on the body never leaves it inside rock (worst overlap %d)" % worst)
	_check(Slump.loose_cells_in(grid, Rect2i(0, 0, W, H)) == 1, "and the cell is still somewhere in the world")


## The real scenario: a tunnel cut at body height in a clay bank, so the roof loses its support with the
## body standing directly under it. This is what item 7 of the overnight queue actually asks for and it
## is the case a player will hit first.
func _test_a_collapsing_roof_never_leaves_it_inside_rock() -> void:
	var grid: TileGrid = _floor()
	for col: int in W:                                    # bank the whole world in clay above the floor
		for row: int in range(FLOOR_ROW - 20, FLOOR_ROW):
			grid.set_material(Vector2i(col, row), LOOSE)
	# A tunnel with real clearance: the body is 10 cells tall, so a 10-cell tunnel would spawn it with
	# its head in the roof and the bounds enforcer would eject it sideways before the collapse ever ran.
	# The first version of this fixture did exactly that and posted a 40-cell overlap that had nothing to
	# do with the slump -- the failure was in `_standing`, three lines before the subject.
	for row: int in range(FLOOR_ROW - 12, FLOOR_ROW):
		for col: int in range(COL - 3, COL + 4):
			grid.excavate(Vector2i(col, row))
	var body: Body = _standing(grid, FLOOR_ROW - 6)
	var before: int = Slump.loose_cells_in(grid, Rect2i(0, 0, W, H))
	var s: Slump = Slump.new()
	_check(PropertyChecks.solid_overlap_count(body, grid) == 0, "the body starts the case standing clear in the tunnel")
	for col: int in range(COL - 3, COL + 4):
		s.after_break(grid, [Vector2i(col, FLOOR_ROW - 12)])
	var worst: int = _run(grid, body, s, 600)
	print("  [OBSERVED] roof collapse onto a standing body: worst overlap over 600 ticks = %d, body cell %s"
		% [worst, Aim.cell_of(body.pos_x, body.pos_y)])
	_check(worst == 0, "a collapsing roof never leaves the body inside rock (worst overlap %d)" % worst)
	_check(Slump.loose_cells_in(grid, Rect2i(0, 0, W, H)) == before,
		"and the collapse conserved every cell of earth it moved")


## THE DIRECTION MATTERS. Depenetration that pushed the body DOWN would post the same zero overlap and
## drop the player through the floor, which is the worse bug wearing the better bug's number.
func _test_the_body_is_pushed_up_not_down() -> void:
	var grid: TileGrid = _floor()
	var body: Body = _standing(grid)
	var start_y: int = body.pos_y
	for row: int in range(FLOOR_ROW - 14, FLOOR_ROW - 10):   # four cells of earth queued over its head
		grid.set_material(Vector2i(COL, row), LOOSE)
	var s: Slump = Slump.new()
	s.after_break(grid, [Vector2i(COL, FLOOR_ROW - 10)])
	_run(grid, body, s, 400)
	print("  [OBSERVED] buried under four cells: pos_y %.1f -> %.1f (down is positive)"
		% [float(start_y) / float(Fx.SCALE), float(body.pos_y) / float(Fx.SCALE)])
	_check(body.pos_y <= start_y, "earth landing on the body never pushes it DOWN through the floor")
	_check(body.pos_y > Fx.from_int(0), "and never ejects it out of the top of the world")
