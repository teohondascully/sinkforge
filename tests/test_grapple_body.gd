extends "res://tests/test_base.gd"

## THE LINE ON THE BODY (A' step 5c, D0360): legacy `check_grapple`'s four properties the fun is made of,
## driven through the real body and the real constraint -- IT BITES, IT SWINGS (faster than the legs),
## IT LIFTS (against gravity), IT CROSSES (a chasm no jump clears) -- and IT KEEPS (speed built on the
## line survives the release). Plus what this build adds: the wall stand-in for the parked collision
## half, the jump that cuts a taut line, translation consent for the swing, the signature and the door.
##
## The rig is legacy's in pixels: a ceiling 320 px over the floor, a chasm 320 px wide (the jump arc
## clears about a third of it), a thick roof to bite into.

const S: int = Fx.SCALE
const CELL: int = Heightfield.TERRAIN_CELL_PX
const W: int = 200                 ## terrain cells: 800 px
const H: int = 150
const CEIL_ROW: int = 20           ## rows 0..19 solid: the roof's underside at y = 80 px
const FLOOR_ROW: int = 100         ## rows 100.. solid: the floor at y = 400 px
const GAP_LEFT: int = 90           ## the chasm: cols 90..169 have no floor (320 px)
const GAP_RIGHT: int = 170
const WALL: int = 4
const STAND_Y: int = FLOOR_ROW * CELL - Body.HEIGHT_PX / 2   ## px: feet on the floor
## Floors, with headroom over the measured baseline (legacy's own).
const PLANT_TICKS_CAP: int = 12
const SWING_SPEED_FLOOR_NUM: int = 115   ## x1.15 RUN_SPEED the pumped arc must beat
const REEL_LIFT_FLOOR_PX: int = 96       ## legacy 3 cells of 32 px in 90 ticks of holding UP
const MOMENTUM_KEEP_NUM: int = 72        ## 0.72 of the launch speed left 30 ticks after a hands-off release


func _initialize() -> void:
	_test_it_bites()
	_test_a_miss_stows()
	_test_it_swings_faster_than_the_legs()
	_test_it_lifts()
	_test_it_crosses_the_chasm()
	_test_it_keeps_its_speed_on_release()
	_test_a_jump_cuts_a_taut_line_with_a_kick()
	_test_a_swing_into_a_wall_stops_at_the_wall()
	_test_the_swing_is_a_consenting_mover_and_signs()
	_test_through_the_door()
	_finish("grapple_body")


func _rig() -> TileGrid:
	var grid: TileGrid = TileGrid.new(W, H, 1)
	for col: int in range(W):
		for row: int in range(H):
			var chasm: bool = col >= GAP_LEFT and col < GAP_RIGHT
			if row < CEIL_ROW or (row >= FLOOR_ROW and not chasm) or col < WALL or col >= W - WALL:
				grid.set_material(Vector2i(col, row), &"hardrock")
	return grid


func _stand(col: int) -> Body:
	return Body.new((col * CELL + CELL / 2) * S, STAND_Y * S)


func _throw(cell: Vector2i, move: int = 0) -> InputFrame:
	var f: InputFrame = _input(move)
	f.grapple_pressed = true
	f.has_aim = true
	f.aim_col = cell.x
	f.aim_row = cell.y
	return f


func _jump(move: int = 0) -> InputFrame:
	var f: InputFrame = _input(move)
	f.jump_pressed = true
	f.jump_held = true
	return f


## Throw at `cell` and tick until the hook bites or the shot stows; ticks to the bite, or -1.
func _hook(body: Body, grid: TileGrid, cell: Vector2i, budget: int = 40) -> int:
	body.tick(_throw(cell), grid)
	for i: int in budget:
		if body.grapple.state == Grapple.State.ANCHORED:
			return i + 1
		if not body.grapple.live():
			return -1
		body.tick(_input(), grid)
	return -1


func _settle(body: Body, grid: TileGrid, ticks: int = 20) -> void:
	for _i: int in ticks:
		body.tick(_input(), grid)


func _test_it_bites() -> void:
	var grid: TileGrid = _rig()
	var body: Body = _stand(60)
	_settle(body, grid)
	var ticks: int = _hook(body, grid, Vector2i(60, CEIL_ROW - 1))
	_check(body.grapple.state == Grapple.State.ANCHORED, "a shot at the roof ANCHORS")
	_check(ticks > 0 and ticks <= PLANT_TICKS_CAP, "...within %d ticks (took %d)" % [PLANT_TICKS_CAP, ticks])
	_check(grid.is_solid(body.grapple.anchor_cell), "it anchored in a genuinely solid cell")
	_check(body.grapple.just_planted or ticks > 0, "the plant tick was seen")
	body.grapple.cut()
	_check(not body.grapple.live(), "cutting the line stows it")


func _test_a_miss_stows() -> void:
	var grid: TileGrid = _rig()
	var body: Body = _stand(60)
	_settle(body, grid)
	var ticks: int = _hook(body, grid, Vector2i(150, 60))   # level, across 540 px of air: out of line
	_check(ticks == -1 and not body.grapple.live(), "a shot that hits nothing runs out of line and stows")


## Stand on the chasm's left lip, hook the roof out over the void, step off and PUMP: steer with the arc,
## flipping at each apex the way a player does. The best horizontal speed after the first second must beat
## the legs, or a swing slower than walking is a swing nobody will use.
func _test_it_swings_faster_than_the_legs() -> void:
	var grid: TileGrid = _rig()
	var body: Body = _stand(GAP_LEFT - 2)
	_settle(body, grid)
	if _hook(body, grid, Vector2i(GAP_LEFT + 3, CEIL_ROW - 1)) < 0:
		_check(false, "the swing rig anchored")
		return
	var dir: int = 1
	var prev_x: int = body.pos_x
	var best: int = 0
	for i: int in 420:
		body.tick(_input(dir), grid)
		var dx: int = body.pos_x - prev_x
		if dx != 0 and signi(dx) != dir:
			dir = -dir
		prev_x = body.pos_x
		if i > 60:
			best = maxi(best, absi(body.vel_x))
	_check(body.grapple.state == Grapple.State.ANCHORED, "the line held through the whole drive")
	_check(best * 100 >= Body.RUN_SPEED * SWING_SPEED_FLOOR_NUM,
		"a pumped swing beats walking (%d px/s >= %d)" % [best / S, (Body.RUN_SPEED * SWING_SPEED_FLOOR_NUM) / (100 * S)])


func _test_it_lifts() -> void:
	var grid: TileGrid = _rig()
	var body: Body = _stand(60)
	_settle(body, grid)
	if _hook(body, grid, Vector2i(60, CEIL_ROW - 1)) < 0:
		_check(false, "the reel rig anchored")
		return
	var y0: int = body.pos_y
	for _i: int in 90:
		body.tick(_input(0, 1), grid)
	var gained: int = (y0 - body.pos_y) / S
	_check(gained >= REEL_LIFT_FLOOR_PX, "reeling in lifts the body against gravity (%d px >= %d in 90 ticks)" % [gained, REEL_LIFT_FLOOR_PX])
	_check(not body.on_floor, "...and it is off the floor")
	var y1: int = body.pos_y
	for _i: int in 30:
		body.tick(_input(), grid)
	_check(absi(body.pos_y - y1) < 2 * S, "hands off, it hangs where the reel left it (drifted %d px)" % (absi(body.pos_y - y1) / S))


## The whole verb, end to end, played the way a player plays it: run at the lip, hook the roof out over the
## void, ride the arc with the stick held, and LET GO (a jump) over the far side. The release is the point.
func _test_it_crosses_the_chasm() -> void:
	var grid: TileGrid = _rig()
	var body: Body = _stand(GAP_LEFT - 30)
	_settle(body, grid)
	for _i: int in 34:
		body.tick(_input(1), grid)
	body.tick(_throw(Vector2i(GAP_LEFT + 40, CEIL_ROW - 1), 1), grid)
	var released: bool = false
	var far_lip: int = GAP_RIGHT * CELL * S
	for _i: int in 400:
		if not released and body.grapple.taut and body.pos_x > far_lip:
			body.tick(_jump(1), grid)
			released = true
		else:
			body.tick(_input(1), grid)
		if released and body.on_floor:
			break
	_settle(body, grid, 60)
	var landed_col: int = Body._px_to_cell(body.pos_x)
	_check(released, "the body swung out over the far lip and let go")
	_check(landed_col >= GAP_RIGHT and body.on_floor,
		"a 320 px chasm no jump can clear is crossed by swinging it (ended at col %d, far lip %d, on_floor=%s)"
		% [landed_col, GAP_RIGHT, body.on_floor])


## The controller property the swing depends on: a body moving faster than it can run, with nobody
## touching the controls, must still be moving faster than it can run a moment later. Without it the tool
## is decorative: the controller's normal job is to hold you AT RUN_SPEED, and it bled a 420 px/s release
## to a walk inside a sixth of a second.
func _test_it_keeps_its_speed_on_release() -> void:
	var grid: TileGrid = _flat_grid(FLOOR_ROW, W)          # no chasm: the launch must land on floor
	var body: Body = Body.new(25 * CELL * S, (FLOOR_ROW * CELL - 192) * S)
	body.vel_x = BodySwing.SWING_MAX_SPEED
	body.vel_y = -40 * S
	var flown: int = 0
	for _i: int in 30:
		body.tick(_input(), grid)
		flown += 1
		if body.on_floor:
			break
	_check(flown == 30 and not body.on_floor, "the launch stayed in the air for the whole window (%d ticks)" % flown)
	_check(body.vel_x * 100 >= BodySwing.SWING_MAX_SPEED * MOMENTUM_KEEP_NUM,
		"speed built on the line SURVIVES the release (%d of %d px/s 30 ticks later)" % [body.vel_x / S, BodySwing.SWING_MAX_SPEED / S])
	_settle(body, grid, 60)
	_check(body.on_floor and absi(body.vel_x) <= Body.RUN_SPEED, "...and skids to a walk on landing (%d px/s)" % (body.vel_x / S))


func _test_a_jump_cuts_a_taut_line_with_a_kick() -> void:
	var grid: TileGrid = _rig()
	var body: Body = _stand(60)
	_settle(body, grid)
	_hook(body, grid, Vector2i(60, CEIL_ROW - 1))
	for _i: int in 30:
		body.tick(_input(0, 1), grid)        # reel up into a hang
	_check(body.grapple.taut and not body.on_floor, "hanging on a taut line")
	var rising: int = body.vel_y                     # the winch had the body closing on the hook
	body.tick(_jump(), grid)
	_check(not body.grapple.live() and body.grapple.just_cut, "a jump off a taut line CUTS it")
	_check(body.vel_y < 0 and body.jumped_this_tick, "...and stacks the leap on the arc (vel_y %d px/s)" % (body.vel_y / S))
	# Legacy's formula: (min(vy, 0) + JUMP) * RELEASE_KICK, the rise the winch built stacked under the leap.
	var kicked: int = ((mini(rising + Body.GRAVITY_PER_TICK, 0) + Body.JUMP_VELOCITY) * Grapple.PUMP_CLAMP_NUM) / Grapple.PUMP_CLAMP_DEN
	_check(absi(body.vel_y - kicked) <= 30 * S,
		"the release kick is the pump's own 21/20 on the stacked leap (vel_y %d, expected %d)" % [body.vel_y / S, kicked / S])


## The stand-in for the parked collision half: a swing into a wall stops at the wall, the line reads slack
## there, and the body is never inside rock.
func _test_a_swing_into_a_wall_stops_at_the_wall() -> void:
	var grid: TileGrid = _rig()
	var body: Body = _stand(WALL + 8)               # 32 px from the left wall's face at x = 16
	_settle(body, grid)
	_hook(body, grid, Vector2i(WALL + 2, CEIL_ROW - 1))   # the roof, out over the wall
	var inside: int = 0
	var slack_at_wall: int = 0
	for _i: int in 240:
		body.tick(_input(-1, 1), grid)          # reel and push into the wall
		if body._box_blocked(grid, body._left_x(), body._top_y(), body._right_x(), body._bottom_y()):
			inside += 1
		if body._left_x() <= WALL * CELL * S + S and not body.grapple.taut:
			slack_at_wall += 1
	_check(inside == 0, "the body is never inside rock (%d ticks were)" % inside)
	_check(body._left_x() >= WALL * CELL * S, "it stopped at the wall's face (left edge %d px, face %d)" % [body._left_x() / S, WALL * CELL])
	_check(slack_at_wall > 0, "the line read slack while held against the wall (%d ticks)" % slack_at_wall)


func _drive(body: Body, grid: TileGrid) -> void:
	_settle(body, grid)
	_hook(body, grid, Vector2i(GAP_LEFT + 3, CEIL_ROW - 1))
	for i: int in 120:
		body.tick(_input(1 if (i / 30) % 2 == 0 else -1, 1 if i % 7 == 0 else 0), grid)


func _test_the_swing_is_a_consenting_mover_and_signs() -> void:
	var grid: TileGrid = _rig()
	var a: Body = _stand(GAP_LEFT - 2)
	var b: Body = _stand(GAP_LEFT - 2)
	var violations: int = 0
	var swung: int = 0
	_settle(a, grid)
	_hook(a, grid, Vector2i(GAP_LEFT + 3, CEIL_ROW - 1))
	for _i: int in 120:
		a.tick(_input(), grid)                  # hands off: only the line moves the body sideways
		if a.translation_consent_violation_this_tick:
			violations += 1
		if a.swung_this_tick:
			swung += 1
	_check(swung > 0, "the line moved the body with no input (%d ticks)" % swung)
	_check(violations == 0, "...and translation consent was never violated: the swing is a consenting mover")
	var c: Body = _stand(GAP_LEFT - 2)
	_drive(b, grid)
	_drive(c, grid)
	_check(b.state_signature() == c.state_signature(), "two identical drives sign identically")
	_check(b.state_signature().contains(b.grapple.state_signature()), "the body's signature carries the line's")
	var d: Body = Body.new(0, 0)
	d.restore(b.capture())
	_check(d.state_signature() == b.state_signature(), "capture/restore round-trips a body on a line")
	b.place(100 * S, 100 * S)
	_check(not b.grapple.live() and b.vel_x == 0 and b.gait.fall_from_y == 100 * S, "place() moves a body, cuts its line and prices no fall")


func _test_through_the_door() -> void:
	var grid: TileGrid = _rig()
	var door: Interface = Interface.new(grid, _stand(60), Mining.new())
	var env: Interface.Envelope = Interface.Envelope.new(Rect2i(0, 0, W, H))
	for _i: int in 20:
		door.apply(Command.move(_input()))
	var o: Interface.Observation = door.observe(env)
	_check(o.grapple_state == 0 and o.hand.y < o.pos_y, "stowed, the observation carries the hand above the centre")
	door.apply(Command.move(_throw(Vector2i(60, CEIL_ROW - 1))))
	for _i: int in 15:
		door.apply(Command.move(_input()))
	o = door.observe(env)
	var anchor_cell := Vector2i(Body._px_to_cell(o.grapple_anchor.x), Body._px_to_cell(o.grapple_anchor.y))
	_check(o.grapple_state == 2 and grid.is_solid(anchor_cell), "the door reports the line anchored in solid rock")
	_check(o.grapple_hitch == o.grapple_anchor and o.grapple_pivots.is_empty(), "no pivots: the hitch is the hook")
	var before: String = door.state_signature()
	door.observe(env)
	_check(door.state_signature() == before, "observing the line changes nothing")
	var saved: Dictionary = Session.capture(door)
	var other: Interface = Interface.new(_rig(), _stand(10), Mining.new())
	_check(Session.restore(other, saved) and other.state_signature() == before, "the session round-trips a body on a line")
