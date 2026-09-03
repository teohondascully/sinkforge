class_name MineHold
extends RefCounted

## THE MINE HOLD, one tick: legacy `main.gd` `_update_mining` 1522-1624's decision half, lifted in A'
## step 4b (D0357) over the blocks step 3i already lifted. While the button is held the drag paints the
## dig plan; the aim is the frame's cell snapped to the nearest visible face (`Aim`); when the aim
## itself offers no workable block the nearest marked cell in reach becomes the work target (the plan
## drains when the hand is free); rock is charged and broken (`Mining`), a lode face is worked
## (`LodeWork`), and what breaks is yielded to the ledger. Building keeps the aim exact.
##
## Rides `MOVE`'s `InputFrame` (`has_aim`, `aim_col`/`aim_row`, `mine_held`): aim is state-affecting
## input and is already recorded per tick, so no second input format is needed (`sim/commands`).

var last_aim: Vector2i = Vector2i(-1, -1)   # the last painted point's cell, for the drag
var aim_cell: Vector2i = Vector2i(-1, -1)   # this tick's effective aim, for the door's observation
var aim_is_lode: bool = false


func step(frame: InputFrame, world: World, items: Items, mining: Mining, plan: DigPlan, lode: LodeWork, body: Body, building: bool) -> void:
	if not frame.has_aim:
		last_aim = Vector2i(-1, -1)
		aim_cell = Vector2i(-1, -1)
		aim_is_lode = false
		mining.mine(world.grid, body.pos_x, body.pos_y, Mining.NO_CELL, false)
		lode.work(world, items, mining, body.pos_x, body.pos_y, Mining.NO_CELL, false)
		return
	var raw := Vector2i(frame.aim_col, frame.aim_row)
	var point: Vector2i = Aim.cell_center_fx(raw)
	if frame.mine_held:
		var from: Vector2i = Aim.cell_center_fx(last_aim) if last_aim != Vector2i(-1, -1) else point
		plan.paint(world.grid, from.x, from.y, point.x, point.y)
		last_aim = raw
	else:
		last_aim = Vector2i(-1, -1)
	var aim: Vector2i = Aim.effective(world.grid, body.pos_x, body.pos_y, point.x, point.y, building)
	var work: Vector2i = aim
	if frame.mine_held and not _workable(world, body, work):
		var marked: Vector2i = plan.nearest_workable(world.grid, body.pos_x, body.pos_y)
		if marked != Mining.NO_CELL:
			work = marked
	aim_cell = work
	aim_is_lode = world.deposits.lode_workable(world.grid, work)
	if aim_is_lode:
		mining.mine(world.grid, body.pos_x, body.pos_y, Mining.NO_CELL, false)
		lode.work(world, items, mining, body.pos_x, body.pos_y, work, frame.mine_held)
		return
	lode.work(world, items, mining, body.pos_x, body.pos_y, Mining.NO_CELL, false)
	var visible: bool = LineOfSight.clear(world.grid, Aim.cell_of(body.pos_x, body.pos_y), work)
	mining.mine(world.grid, body.pos_x, body.pos_y, work, frame.mine_held and visible)
	if mining.broke_this_tick:
		items.yield_break(mining.broke_cells, mining.broke_materials)


## Workable by hand: an exposed lode, or solid rock in reach and in sight (legacy `_workable` 1786).
func _workable(world: World, body: Body, cell: Vector2i) -> bool:
	if world.deposits.lode_workable(world.grid, cell):
		return Mining.in_reach(body.pos_x, body.pos_y, cell) and LineOfSight.clear(world.grid, Aim.cell_of(body.pos_x, body.pos_y), cell)
	return world.grid.in_bounds(cell) and world.grid.is_solid(cell) and Mining.in_reach(body.pos_x, body.pos_y, cell) \
		and LineOfSight.clear(world.grid, Aim.cell_of(body.pos_x, body.pos_y), cell)
