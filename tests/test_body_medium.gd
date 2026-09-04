extends "res://tests/test_base.gd"

## THE MEDIUM (A' step 5c, D0360): the body's nine missing mechanisms from legacy `player.gd`, through
## `WorldSurroundings` -- rope grip and climb with the top hold and the jump that lets go, the lift's
## updraft, water wading (top speed, gravity, sink, jump), machines block and wood passes, the step-down
## floor snap (in the resolver, so bare terrain has it too), `place()`; and the bare `Surroundings` base
## answering as the body always did.

const S: int = Fx.SCALE
const CELL: int = Heightfield.TERRAIN_CELL_PX
const N: int = LogicGrid.TERRAIN_PER_LOGIC
const FLOOR_ROW: int = 60           ## terrain row: the floor at y = 240 px, logic row 15
const WIDTH: int = 120              ## terrain cells


func _initialize() -> void:
	_test_rope_grip_climb_and_top_hold()
	_test_a_jump_lets_go_of_the_rope()
	_test_the_updraft_carries_the_body_up()
	_test_water_wading()
	_test_machines_block_and_wood_passes()
	_test_step_down_snap()
	_test_bare_surroundings_answer_as_before()
	_finish("body_medium")


class Rig:
	var grid: TileGrid
	var world: World
	var items: Items
	var machines: Machines
	var body: Body


func _rig(col: int = 10) -> Rig:
	var r: Rig = Rig.new()
	r.grid = TileGrid.new(WIDTH, FLOOR_ROW + 16, 1)
	for c: int in range(WIDTH):
		for row: int in range(FLOOR_ROW, FLOOR_ROW + 16):
			r.grid.set_material(Vector2i(c, row), &"hardrock")
	r.world = World.new(r.grid)
	r.items = Items.new(r.world)
	r.machines = Machines.new()
	r.machines.attach_to(r.items)
	r.body = Body.new((col * CELL + CELL / 2) * S, (FLOOR_ROW * CELL - Body.HEIGHT_PX / 2) * S)
	r.body.surroundings = WorldSurroundings.new(r.world, r.machines)
	return r


func _run(r: Rig, f: InputFrame, ticks: int) -> void:
	for _i: int in ticks:
		r.body.tick(f, r.grid)


func _test_rope_grip_climb_and_top_hold() -> void:
	var r: Rig = _rig(10)                                   # body centre x = 42 px: logic column 2
	var hung: int = PlacedVerbs.place_rope(r.world, Vector2i(2, 8), 7)   # logic rows 8..14, the floor is 15
	_check(hung == 7, "seven rope segments hang down the body's column to the floor (%d)" % hung)
	_run(r, _input(), 20)
	_check(not r.body.climbing, "standing beside a rope is not gripping it")
	var y0: int = r.body.pos_y
	_run(r, _input(0, 1), 30)
	_check(r.body.climbing, "a climb press grips the rope")
	_check(y0 - r.body.pos_y >= 50 * S, "...and 30 ticks of W ride it up at 110 px/s (%d px)" % ((y0 - r.body.pos_y) / S))
	var y1: int = r.body.pos_y
	_run(r, _input(), 30)
	_check(r.body.climbing and absi(r.body.pos_y - y1) < S, "release = hang: still gripping, not moving (%d px)" % (absi(r.body.pos_y - y1) / S))
	_run(r, _input(0, -1), 20)
	_check(r.body.pos_y > y1, "S rides it down")
	_run(r, _input(0, 1), 300)
	var top_hold: int = 8 * N * CELL * S + BodyMedium.ROPE_TOP_HOLD_PX * S
	_check(r.body.climbing and r.body.pos_y >= top_hold - S and r.body.pos_y <= top_hold + 2 * S,
		"at the top the rise clamps so the grip holds, no jitter (centre %d px, hold %d)" % [r.body.pos_y / S, top_hold / S])
	_run(r, _input(1, 1), 40)
	_check(not r.body.climbing, "walking off the rope's column lets go")


func _test_a_jump_lets_go_of_the_rope() -> void:
	var r: Rig = _rig(10)
	PlacedVerbs.place_rope(r.world, Vector2i(2, 8), 7)
	_run(r, _input(), 20)
	_run(r, _input(0, 1), 30)
	_check(r.body.climbing and not r.body.on_floor, "gripping, off the floor")
	var f: InputFrame = _input()
	f.jump_pressed = true
	f.jump_held = true
	r.body.tick(f, r.grid)
	_check(not r.body.climbing and r.body.jumped_this_tick and r.body.vel_y < 0,
		"a jump from the rope lets go and leaps: gripping counts as grounded (vel_y %d)" % (r.body.vel_y / S))


func _test_the_updraft_carries_the_body_up() -> void:
	var r: Rig = _rig(10)
	r.machines.place(r.world, MachineDef.of(&"lift"), Vector2i(2, 14))   # the lift on the floor, under the body's column
	r.body.place(r.body.pos_x, (FLOOR_ROW * CELL - 40) * S)               # start a metre and a half up its open shaft
	_check(r.body.surroundings.updraft_at(BodyMedium.logic_cell(r.body)), "the shaft above the lift carries a draft")
	var y0: int = r.body.pos_y
	_run(r, _input(), 30)
	_check(r.body.pos_y < y0 - 40 * S, "hands off, the draft carries the body UP (%d px in 30 ticks)" % ((y0 - r.body.pos_y) / S))
	_check(r.body.vel_y <= -BodyMedium.LIFT_RISE_SPEED, "at least the rise speed (%d px/s)" % (r.body.vel_y / S))


func _test_water_wading() -> void:
	var r: Rig = _rig(10)
	for c: int in range(0, WIDTH):
		for row: int in range(FLOOR_ROW - 12, FLOOR_ROW):        # 48 px of water over the floor
			r.world.water.set_level(Vector2i(c, row), WaterPlane.WATER_MAX)
	_run(r, _input(), 5)
	_check(r.body.wet, "the body's box over water cells is wet")
	_run(r, _input(1), 90)
	var top: int = (Body.RUN_SPEED * BodyMedium.WATER_SPEED_NUM) / BodyMedium.WATER_SPEED_DEN
	_check(r.body.vel_x <= top and r.body.vel_x >= top - S, "wading top speed is 0.55x the run (%d px/s)" % (r.body.vel_x / S))
	var f: InputFrame = _input()
	f.jump_pressed = true
	f.jump_held = true
	r.body.tick(f, r.grid)
	var weak: int = (Body.JUMP_VELOCITY * BodyMedium.WATER_JUMP_NUM) / BodyMedium.WATER_JUMP_DEN
	_check(r.body.vel_y <= weak + S and r.body.vel_y >= weak - S, "the leap out of water is 0.7x (%d px/s)" % (r.body.vel_y / S))
	var dry: Rig = _rig(10)
	dry.body.place(dry.body.pos_x, 20 * S)
	r.body.place(r.body.pos_x, (FLOOR_ROW * CELL - 40) * S)
	for _i: int in 40:
		r.body.tick(_input(), r.grid)
		dry.body.tick(_input(), dry.grid)
	_check(r.body.vel_y <= BodyMedium.WATER_MAX_SINK, "sinking caps at 220 px/s (%d)" % (r.body.vel_y / S))
	_check(dry.body.vel_y > r.body.vel_y or r.body.on_floor, "...slower than the dry fall (%d dry vs %d wet)" % [dry.body.vel_y / S, r.body.vel_y / S])


## A machine's tile is solid to the body on every side: one tile is a step the legs auto-climb (legacy's
## 1.3-cell step), so the body walks OVER a lone machine and never through it; two stacked are a wall.
func _test_machines_block_and_wood_passes() -> void:
	var r: Rig = _rig(10)
	var placed: MachineState = r.machines.place(r.world, MachineDef.of(&"hopper"), Vector2i(5, 14))   # on the floor ahead: x 80..96 px
	_check(placed != null and r.machines.machine_at(Vector2i(5, 14)) != null, "the hopper stands at logic (5, 14)")
	_check(r.body.surroundings.blocks(r.grid, Vector2i(20, FLOOR_ROW - 1)), "blocks(): the machine's tile, at terrain (20, 59)")
	var stand_y: int = r.body.pos_y
	var highest: int = stand_y
	var inside: int = 0
	var stepped: int = 0
	for _i: int in 90:
		r.body.tick(_input(1), r.grid)
		highest = mini(highest, r.body.pos_y)
		if r.body.stepped_up_this_tick:
			stepped += 1
		if r.body._box_blocked(r.grid, r.body._left_x(), r.body._top_y(), r.body._right_x(), r.body._bottom_y()):
			inside += 1
	_check(stepped >= 1 and highest <= stand_y - 16 * S + S, "one machine is a step: the body climbed onto it (%d px up)" % ((stand_y - highest) / S))
	_check(inside == 0 and r.body.pos_x > 110 * S, "...and walked over it, never through it (%d ticks inside, x %d px)" % [inside, r.body.pos_x / S])
	var wall: Rig = _rig(10)
	wall.machines.place(wall.world, MachineDef.of(&"hopper"), Vector2i(5, 14))
	wall.machines.place(wall.world, MachineDef.of(&"hopper"), Vector2i(5, 13))                 # stacked: two tiles, no step
	_run(wall, _input(1), 90)
	_check(wall.body._right_x() <= 80 * S and wall.body._right_x() >= 78 * S,
		"two stacked machines wall the body: it stops at their face (right edge %d px, face 80)" % (wall.body._right_x() / S))
	var w: Rig = _rig(10)
	for row: int in range(FLOOR_ROW - 12, FLOOR_ROW):
		w.grid.set_material(Vector2i(25, row), &"wood")                    # a trunk at x 100..104 px
	_check(w.grid.is_solid(Vector2i(25, FLOOR_ROW - 1)), "the trunk is solid terrain")
	_run(w, _input(1), 90)
	_check(w.body.pos_x > 110 * S, "...and wood passes: the body walked through it (x %d px)" % (w.body.pos_x / S))
	_check(not w.body.surroundings.blocks(w.grid, Vector2i(25, FLOOR_ROW - 1))
		and w.body.surroundings.blocks(w.grid, Vector2i(25, FLOOR_ROW)), "blocks(): wood no, hardrock yes")


func _test_step_down_snap() -> void:
	var r: Rig = _rig(10)
	for c: int in range(30, WIDTH):
		for row: int in range(FLOOR_ROW, FLOOR_ROW + 4):
			r.grid.excavate(Vector2i(c, row))                              # one tile (16 px) lower from x = 120 px
	_run(r, _input(), 10)
	var airborne: int = 0
	var snapped: int = 0
	for _i: int in 60:
		r.body.tick(_input(1), r.grid)
		if not r.body.on_floor:
			airborne += 1
		if r.body.stepped_down_this_tick:
			snapped += 1
	_check(r.body.pos_x > 130 * S, "the body walked past the step (x %d px)" % (r.body.pos_x / S))
	_check(snapped >= 1, "the floor snap hugged the one-tile step (%d snaps)" % snapped)
	_check(airborne == 0, "...so the walk never went airborne (%d ticks did)" % airborne)
	var deep: Rig = _rig(10)
	for c: int in range(30, WIDTH):
		for row: int in range(FLOOR_ROW, FLOOR_ROW + 8):
			deep.grid.excavate(Vector2i(c, row))                           # two tiles down: a real drop
	_run(deep, _input(), 10)
	var fell: int = 0
	for _i: int in 60:
		deep.body.tick(_input(1), deep.grid)
		if not deep.body.on_floor:
			fell += 1
	_check(fell > 0 and not deep.body.stepped_down_this_tick, "a two-tile drop is a fall, not a step (%d airborne ticks)" % fell)
	var still: Rig = _rig(28)                                                # feet on the lip, not walking
	_run(still, _input(), 10)
	_check(still.body.on_floor and not still.body.stepped_down_this_tick, "a resting body is never snapped down")


func _test_bare_surroundings_answer_as_before() -> void:
	var base: Surroundings = Surroundings.new()
	var grid: TileGrid = _flat_grid(FLOOR_ROW, WIDTH)
	_check(base.blocks(grid, Vector2i(5, FLOOR_ROW)) and not base.blocks(grid, Vector2i(5, 1)), "bare: solid blocks, air does not")
	_check(not base.is_climbable(Vector2i(1, 1)) and base.water_at(Vector2i(1, 1)) == 0 and not base.updraft_at(Vector2i(1, 1)),
		"bare: no rope, no water, no draft")
	var body: Body = Body.new(20 * CELL * S, (FLOOR_ROW * CELL - 40) * S)
	for _i: int in 40:
		body.tick(_input(1), grid)
	_check(body.on_floor and not body.wet and not body.climbing and body.vel_x == Body.RUN_SPEED,
		"a body built alone runs on bare terrain exactly as before")
	_check(WorldSurroundings.logic_of(Vector2i(-1, -5)) == Vector2i(-1, -2) and WorldSurroundings.logic_of(Vector2i(7, 4)) == Vector2i(1, 1),
		"logic_of floors negative terrain cells")
