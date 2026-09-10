extends "res://tests/test_base.gd"

## THE SWING'S COLLISION POLICY (A9, D0578). Split out of `test_grapple_body.gd`, which is about what
## the line can DO -- bite, swing, lift, cross, release. This file is about what it must never do.
##
## D0567 let a constrained move SLIDE along a face instead of being refused outright, which is what made
## a dug shaft climbable, and argued safety from "every candidate is a subset of a move the constraint
## already wanted". That is a claim about the candidate SET. `BodySwing._slide` tests DESTINATIONS and
## never the path between them, so the claim says nothing about what the body passes through on the way.
## Astra probed it and a move straight across an intervening floor was accepted because the far side was
## clear.
##
## Every rig here POSES the grapple's state directly rather than throwing a hook for it. That is
## deliberate: these are the states a long blocked reel used to produce, `Grapple.give_back` now prevents
## that route, and a backstop has to be tested from the state it exists to survive rather than from the
## road that used to lead there.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_grapple_safety.gd

const S: int = Fx.SCALE
const CELL: int = Heightfield.TERRAIN_CELL_PX
const W: int = 200
const H: int = 150
const CEIL_ROW: int = 20
const FLOOR_ROW: int = 100


func _initialize() -> void:
	_test_the_bound_is_the_bodys_own_box()
	_test_an_endpoint_check_alone_would_cross_a_wall()
	_test_one_swing_pass_never_moves_the_body_further_than_its_box()
	_test_a_refused_pull_gives_its_line_back()
	_test_a_refused_pull_does_not_ratchet_over_many_ticks()
	_test_a_trimmed_move_prices_the_landing_where_the_body_stopped()
	_finish("grapple_safety")


## A roof and a floor, open between, and NO side walls -- these tests never travel far enough sideways
## to need them, and the duplication gate is right that a fourth verbatim copy of the walled chamber in
## `test_grapple.gd` would be a copy rather than a fixture.
func _rig() -> TileGrid:
	var grid: TileGrid = TileGrid.new(W, H, 1)
	for col: int in range(W):
		for row: int in range(CEIL_ROW):
			grid.set_material(Vector2i(col, row), &"hardrock")
		for row: int in range(FLOOR_ROW, H):
			grid.set_material(Vector2i(col, row), &"hardrock")
	return grid


func _stand(col: int) -> Body:
	return Body.new((col * CELL + CELL / 2) * S, (FLOOR_ROW * CELL - Body.HEIGHT_PX / 2) * S)


## An ANCHORED line from `body` to `at`, with `length` px of it paid out. No throw, no flight.
func _hitch(body: Body, at: Vector2i, length_px: int) -> Grapple:
	var g: Grapple = body.grapple
	g.state = Grapple.State.ANCHORED
	g.anchor = at
	g.length = length_px * S
	return g


## THE BOUND IS DERIVED, NOT CHOSEN. Move a `WIDTH_PX`-wide box by `d`: the origin spans `[x-8, x+8]`
## and the destination `[x+d-8, x+d+8]`, so a solid can sit between them touched by neither only when
## `d > WIDTH_PX`. At or under the body's own width there is no gap for anything to hide in, and an
## endpoint-only collision check is sound by construction. `[[constant-must-dominate-constant]]`: this
## asserts the RELATION between two constants, never the literal either of them happens to hold.
func _test_the_bound_is_the_bodys_own_box() -> void:
	_check(BodySwing.MAX_CORRECTION <= Body.WIDTH_PX * S,
			"the correction bound (%d fx) is at most the body's own width (%d fx)"
			% [BodySwing.MAX_CORRECTION, Body.WIDTH_PX * S])


## THE GAP, REPRODUCED. One cell of rock between the body and a clear landing 200 px away -- the shape
## of a correction owed after a long blocked reel. Both assertions here are CONTROLS: they exist to show
## the hazard is real, so the bound in the next test is answering something.
func _test_an_endpoint_check_alone_would_cross_a_wall() -> void:
	var grid: TileGrid = _rig()
	var body: Body = _stand(30)
	var from := Vector2i(body.pos_x, body.pos_y)
	var wall_col: int = int(from.x / (CELL * S)) + 10
	for row: int in range(CEIL_ROW, FLOOR_ROW):
		grid.set_material(Vector2i(wall_col, row), &"hardrock")
	var far := Vector2i(from.x + 200 * S, from.y)
	_check(not BodySwing._blocked_at(body, grid, far),
			"CONTROL: the far landing is CLEAR, so an endpoint check has nothing to object to")
	_check(BodySwing._slide(body, grid, from, far) == far,
			"CONTROL: and `_slide` accepts it whole -- straight across the wall. Astra's probe, "
			+ "reproduced: the destination is clear and the path is not checked at all.")
	var stepped: Vector2i = BodySwing._step_toward(from, far)
	_check(stepped.x - from.x <= BodySwing.MAX_CORRECTION,
			"the bounded step asks for %d px, not 200" % ((stepped.x - from.x) / S))
	_check(stepped.x < wall_col * CELL * S,
			"and lands SHORT of the wall (%d px against a wall at %d px), so the endpoint it hands "
			% [stepped.x / S, wall_col * CELL] + "`_slide` cannot be on the far side of anything")


## THE BOUND AT ITS CALL SITE, which is not the same test. The first version of this suite asserted
## `_step_toward` clamps and deleting the CALL in `BodySwing.step` left every assertion green: the
## helper was tested and the code path was not. Found by running the mutation, not by reading the test.
func _test_one_swing_pass_never_moves_the_body_further_than_its_box() -> void:
	var grid: TileGrid = _rig()
	var body: Body = _stand(30)
	_hitch(body, Vector2i(body.pos_x + 200 * S, body.pos_y - 200 * S), Grapple.MIN_LENGTH / S)
	var before := Vector2i(body.pos_x, body.pos_y)
	BodySwing.step(body, grid, _input())
	var moved := Vector2i(body.pos_x - before.x, body.pos_y - before.y)
	var far: int = Fx.isqrt_ceil(Fx.length_sq(moved.x, moved.y))
	_check(far > 0, "CONTROL: the posed state really does demand a correction (%d px)" % (far / S))
	_check(far <= BodySwing.MAX_CORRECTION,
			"one swing pass moved the body %d px, inside its own %d px box -- from a line %d px short "
			% [far / S, BodySwing.MAX_CORRECTION / S, 283 - Grapple.MIN_LENGTH / S]
			+ "of the anchor. Unbounded, that is a single-tick teleport across whatever lies between.")


## THE RATCHET, which is what made a large correction reachable in ordinary play instead of only in a
## probe. `Grapple.reel` shortens the line on every ANCHORED tick with up held -- before anything knows
## the constrained position will be refused. This is the CONTROL for the test after it: if a reel did
## not actually take line in, "the line did not shorten" would be true of a winch that never moved.
func _test_a_refused_pull_gives_its_line_back() -> void:
	var g: Grapple = Grapple.new()
	g.state = Grapple.State.ANCHORED
	g.anchor = Vector2i(0, 0)
	g.length = 200 * S
	var before: int = g.length
	g.reel(1)
	_check(g.length < before and g.hauled > 0,
			"CONTROL: a reel takes line in unconditionally (%d px), knowing nothing about whether the "
			% (g.hauled / S) + "body will be able to follow")


## AND THE CALL SITE. The unit assertions above pass whether or not `BodySwing` ever calls it, so the
## refusal is posed for real: pack the world solid around the body so every candidate `_slide` can offer
## is inside rock, then hold up for thirty ticks.
##
## THE BODY IS SNAPPED TO THE CELL GRID FIRST, and the control is why. A 16 px box at an arbitrary x
## straddles FIVE 4 px columns, so a pocket cut to the cells the box touches is 20 px wide and the body
## drifts the spare 4 -- which is exactly what the control caught on this test's first run.
func _test_a_refused_pull_does_not_ratchet_over_many_ticks() -> void:
	var grid: TileGrid = TileGrid.new(W, H, 2)
	for col: int in range(W):
		for row: int in range(H):
			grid.set_material(Vector2i(col, row), &"hardrock")
	var pocket_col: int = 40
	var pocket_row: int = 60
	var body: Body = Body.new((pocket_col * CELL + Body.WIDTH_PX / 2) * S,
			(pocket_row * CELL + Body.HEIGHT_PX / 2) * S)
	for col: int in range(pocket_col, pocket_col + Body.WIDTH_PX / CELL):
		for row: int in range(pocket_row, pocket_row + Body.HEIGHT_PX / CELL):
			grid.excavate(Vector2i(col, row))
	var g: Grapple = _hitch(body, Vector2i(body.pos_x + 80 * S, body.pos_y - 120 * S), 60)
	var entombed := Vector2i(body.pos_x, body.pos_y)
	var line_before: int = g.length
	for _i: int in 30:
		body.tick(_input(0, 1), grid)
	_check(Vector2i(body.pos_x, body.pos_y) == entombed,
			"CONTROL: packed in, the body cannot move at all -- so every one of those thirty ticks took "
			+ "the refusal path. Without this, the assertion below passes on a body that simply climbed.")
	# It may take ONE step: a slack line reeling in is not a refused pull, and the tick it goes taut is
	# the tick the refusal starts. From there it must stop.
	var taken: int = line_before - g.length
	_check(taken <= Grapple.REEL_PER_TICK,
			"and it stops the moment the pull is refused: %d px over thirty ticks, at most the one step "
			% (taken / S) + "that made the line taut. Unfixed it takes 7 px EVERY tick -- 210 px here -- "
			+ "and the correction owed grows with it until one tick must move the body past its own box.")


## THE LANDING DATUM FOLLOWS THE SLIDE. `_slide` tries the VERTICAL candidate first, so in a shaft the
## accepted y EQUALS the requested y and a test there cannot tell the two apart -- which is why deleting
## this guard left the shaft assertion green. It bites only where the vertical candidate is blocked and
## the horizontal one is not: under a ceiling, with the line pulling up and across.
func _test_a_trimmed_move_prices_the_landing_where_the_body_stopped() -> void:
	var grid: TileGrid = _rig()
	var body: Body = Body.new((40 * CELL + CELL / 2) * S, (CEIL_ROW * CELL + Body.HEIGHT_PX / 2) * S)
	var g: Grapple = _hitch(body, Vector2i(body.pos_x + 60 * S, (CEIL_ROW * CELL - 40) * S), 40)
	var asked: Vector2i = g.constrain_position_fx(Vector2i(body.pos_x, body.pos_y))
	_check(g.taut and asked.y < body.pos_y,
			"CONTROL: the constraint really does ask the body to rise (%d px), which is the direction "
			% ((body.pos_y - asked.y) / S) + "the ceiling refuses")
	var held: int = body.pos_y
	BodySwing.step(body, grid, _input())
	_check(body.pos_y == held,
			"CONTROL: and the ceiling refused it -- the body did not rise (%d px)" % (body.pos_y / S))
	_check(body.gait.fall_from_y == body.pos_y,
			"the gait's fall datum is where the body actually IS (%d px), not the %d px the constraint "
			% [body.gait.fall_from_y / S, asked.y / S] + "asked for and the roof refused. Priced from "
			+ "the request, a rope pulling up under a ceiling quietly forgives a fall never taken.")
