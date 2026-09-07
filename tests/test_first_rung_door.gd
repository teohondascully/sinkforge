extends "res://tests/test_base.gd"

## THE FIRST RUNGS THROUGH THE DOOR, as a stranger's hands drive them (D0452, D0456): the real tutorial
## world, real commands, the pack read back. Split from `test_tutorial_teaching.gd` at the size limit.

const SEED: int = 20260826


func _initialize() -> void:
	_test_a_held_mine_snaps_whatever_the_hand_holds()
	_test_the_ingots_come_to_the_spot_the_drop_was_taken_from()
	_finish("first_rung_door")


## D0452 (stranger 29): with one clay in the pack, selected, a held MINE on the ringed block's SECOND row
## was refused "sight" four times, wordless -- the block selection had switched the mine aim to the exact
## cell. Through the door: the same press cuts ore now; the idle aim with the block selected keeps the
## exact cell (the build preview); open sky and the forge's cell stay refusals, not snaps onto rock.
func _test_a_held_mine_snaps_whatever_the_hand_holds() -> void:
	var door: Interface = Session.new_game(StrataData.SHALLOW_CLAY, SEED, &"tutorial")
	if door == null:
		_check(false, "the tutorial starts")
		return
	var world: World = door.services()["world"]
	var items: Items = door.services()["items"]
	var body: Body = door.services()["body"]
	var oracle: Interface.Envelope = Interface.Envelope.oracle_over(world.grid)
	var tick: Callable = func(cell: Vector2i, held: bool, verbs: Array = []) -> Interface.Observation:
		var f: InputFrame = InputFrame.new()
		f.has_aim = true
		f.aim_col = cell.x
		f.aim_row = cell.y
		f.mine_held = held
		door.apply(Command.move(f))
		door.apply(Command.collect())
		for c: Command in verbs:
			door.apply(c)
		return door.observe(oracle)
	var bc: Vector2i = Aim.cell_of(body.pos_x, body.pos_y)
	var top: Vector2i = _vein_top(world, bc)
	var ore: Vector2i = top + Vector2i(0, 1)                       # the row under the block's exposed top
	_check(top != Vector2i(-1, -1) and world.grid.is_solid(ore) and not LineOfSight.clear(world.grid, bc, ore) and LineOfSight.clear(world.grid, bc, top),
		"premise: the vein's second row %s is in the ground behind its top %s from the body at %s" % [str(ore), str(top), str(bc)])
	var o: Interface.Observation = _bank_a_clay(world, items, bc, tick)
	var clay_slot: int = -1
	for i: int in items.pack.slots().size():
		if items.pack.slots()[i]["item"] == &"clay":
			clay_slot = i
	_check(items.pack.count(&"clay") > 0 and items.pack.count(&"ore") == 0 and clay_slot >= 0, "premise: a clay cut from the surface beside the body, no ore yet (clay %d, ore %d)" % [items.pack.count(&"clay"), items.pack.count(&"ore")])
	o = tick.call(ore, false, [Command.select(clay_slot)])
	_check(o.aim_cell == ore, "idle with the clay selected, the aim is the exact cell (the build preview) (%s)" % str(o.aim_cell))
	var before: int = items.pack.count(&"ore")
	for _i: int in 90:
		o = tick.call(ore, true)
		if items.pack.count(&"ore") > before:
			break
	_check(items.pack.count(&"ore") > before and o.aim_refusal == &"", "held MINE on the second row with clay selected cuts ore through the block's visible face (ore %d, refusal '%s')" % [items.pack.count(&"ore"), o.aim_refusal])
	var sky: Vector2i = bc + Vector2i(0, -8)
	o = tick.call(sky, true)
	_check(o.aim_refusal == &"air" and o.aim_cell == sky, "held MINE on open sky in reach: refused as air, not snapped onto rock (%s)" % o.aim_refusal)
	var forge: Vector2i = Vector2i(-1, -1)
	for rec: Dictionary in o.machines:
		if rec.get("id", &"") == &"processor":
			forge = Vector2i(rec["cell"]) * 4 + Vector2i(1, 2)
	o = tick.call(forge, true)
	_check(forge != Vector2i(-1, -1) and o.aim_refusal == &"air" and o.aim_cell == forge, "held MINE on the forge's cell: refused as air (a machine is not terrain), never a snap onto the rock beside it (%s at %s)" % [o.aim_refusal, str(o.aim_cell)])


## The vein's nearest exposed top cell to the body (the ringed block's), or (-1, -1).
func _vein_top(world: World, bc: Vector2i) -> Vector2i:
	var top: Vector2i = Vector2i(-1, -1)
	for dy: int in range(0, 12):
		for dx: int in range(-12, 13):
			var c: Vector2i = bc + Vector2i(dx, dy)
			if world.grid.in_bounds(c) and world.grid.get_material(c) == &"ore_iron":
				if top == Vector2i(-1, -1) or c.y < top.y or (c.y == top.y and absi(c.x - bc.x) < absi(top.x - bc.x)):
					top = c
	return top


## The surface beside the body cut as stranger 29 cut it: a block is sixteen cells, so the hold walks the
## aim along the row as each bite opens it, until a whole clay block is in the pack.
func _bank_a_clay(world: World, items: Items, bc: Vector2i, tick: Callable) -> Interface.Observation:
	var o: Interface.Observation = null
	var clay: Vector2i = bc + Vector2i(3, 5)
	for _i: int in 600:
		if not world.grid.is_solid(clay):
			clay = Vector2i(clay.x + 1, clay.y) if clay.x < bc.x + 8 else Vector2i(bc.x + 3, clay.y + 1)
			continue
		o = tick.call(clay, true)
		if items.pack.count(&"clay") > 0:
			break
	return o


## D0456 (the ceiling run, stranger 30): the drop is taken from where the machine is in reach of the body;
## the ingots land a metre lower in the forge's well. Measured from the body's centre point they lay 3.26 m
## off; the scoop reads the trunk, head to feet, so they come to the player who has not moved.
func _test_the_ingots_come_to_the_spot_the_drop_was_taken_from() -> void:
	var door: Interface = Session.new_game(StrataData.SHALLOW_CLAY, SEED, &"tutorial")
	if door == null:
		_check(false, "the tutorial starts")
		return
	var world: World = door.services()["world"]
	var items: Items = door.services()["items"]
	var body: Body = door.services()["body"]
	var oracle: Interface.Envelope = Interface.Envelope.oracle_over(world.grid)
	var tick: Callable = func(f: InputFrame, verbs: Array) -> Interface.Observation:
		door.apply(Command.move(f))
		door.apply(Command.collect())
		for c: Command in verbs:
			door.apply(c)
		return door.observe(oracle)
	var bc: Vector2i = Aim.cell_of(body.pos_x, body.pos_y)
	var top: Vector2i = _vein_top(world, bc)
	for _i: int in 200:
		var f: InputFrame = InputFrame.new()
		f.has_aim = true
		f.aim_col = top.x
		f.aim_row = top.y
		f.mine_held = true
		tick.call(f, [])
		if items.pack.count(&"ore") >= 4:
			break
	for _i: int in 10:
		var f: InputFrame = InputFrame.new()
		f.move_dir = -1
		tick.call(f, [])
	for _i: int in 30:
		tick.call(InputFrame.new(), [])
	var spot: Vector2i = Vector2i(body.pos_x, body.pos_y)
	var slot: int = 0
	for i: int in items.pack.slots().size():
		if items.pack.slots()[i]["item"] == &"ore":
			slot = i
	tick.call(InputFrame.new(), [Command.select(slot)])
	var o: Interface.Observation = tick.call(InputFrame.new(), [Command.drop()])
	_check(o.drop_went == &"fed", "premise: from %.2f m left of the spawn the forge took the stack (%s)" % [(32.5 - float(spot.x) / float(Fx.SCALE * 16)), o.drop_went])
	for _i: int in 240:
		o = tick.call(InputFrame.new(), [])
	_check(items.pack.count(&"ingot") >= 2 and Vector2i(body.pos_x, body.pos_y) == spot, "four seconds later, without a step, the ingots are in the pack (%d ingots; moved %s)" % [items.pack.count(&"ingot"), str(Vector2i(body.pos_x, body.pos_y) != spot)])
