extends "res://tests/test_grapple_body.gd"

## THE LAST METRE AND A HALF IS THE MANTLE'S (P035, D0631) -- split out of test_grapple_body at QUALITY
## gate 4's 400-line file limit, and the seam is the verb's own: the parent keeps the line's properties,
## this file keeps the verb the line hands off to. The shaft rig, the hook helper, and the constants are
## all inherited.


func _initialize() -> void:
	_test_the_last_stretch_is_a_lip_mantle()
	_finish("lip_mantle")


## P035's ruled answer (D0631): the last metre and a half is the MANTLE's, fired from the hang itself.
## A reel stops `Grapple.MIN_LENGTH` under the lip -- supported, not ballistic -- so toward-and-up on the
## rope climbs out the way the rope's ending should feel. The control half matters as much: without
## `mantle_hold` the same hang must NOT climb, or the gate is open rather than the verb firing.
func _test_the_last_stretch_is_a_lip_mantle() -> void:
	var grid: TileGrid = _shaft_rig()
	var body: Body = Body.new(((SHAFT_LEFT + 3) * CELL) * S, (SHAFT_FLOOR * CELL - Body.HEIGHT_PX / 2) * S)
	_settle(body, grid)
	# The anchor is the LIP ITSELF -- the topmost solid cell the wall has -- so the reel's stop leaves
	# the feet within MANTLE_PX of the surface the way the entry measured on the real seat.
	if _hook(body, grid, Vector2i(SHAFT_LEFT - 1, SHAFT_TOP), 80) < 0:
		_check(false, "the hook bit the lip")
		return
	for _i: int in 300:
		body.tick(_input(0, 1), grid)
	var hang_feet: int = body.pos_y + Body.HEIGHT_PX / 2
	var lip_top: int = SHAFT_TOP * CELL * S
	print("  [OBSERVED] reeled out: feet %d px under the lip (MANTLE_PX %d, on_floor=%s)"
		% [(hang_feet - lip_top) / S, Body.MANTLE_PX, body.on_floor])
	# CONTROL: drift toward the wall WITHOUT toward-and-up -- the hang must not climb on its own.
	for _i: int in 120:
		body.tick(_input(-1), grid)
	_check(Aim.cell_of(body.pos_x, body.pos_y).y > SHAFT_TOP,
		"CONTROL: pressing into the wall without mantle_hold does not climb out (row %d, lip %d)"
		% [Aim.cell_of(body.pos_x, body.pos_y).y, SHAFT_TOP])
	# THE VERB: toward the wall and UP, held -- the mantle fires off the line and the feet land topside.
	var f: InputFrame = _input(-1)
	f.mantle_hold = true
	var out: bool = false
	for _i: int in 240:
		body.tick(f, grid)
		if body.on_floor and Aim.cell_of(body.pos_x, body.pos_y).y < SHAFT_TOP:
			out = true
			break
	_check(out, "toward-and-up on the hang mantles the lip and stands on the surface (row %d, on_floor=%s)"
		% [Aim.cell_of(body.pos_x, body.pos_y).y, body.on_floor])
	_check(PropertyChecks.solid_overlap_count(body, grid) == 0, "...and the mantle never ends inside rock")
