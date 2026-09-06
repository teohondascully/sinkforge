extends "res://tests/test_base.gd"

## A STRANGER PLAYS THE TUTORIAL (D0409, the new-player review's rank-1 finding: the opening loop was
## uncompleteable). This suite is the hand of a player who knows nothing: it starts the tutorial the boot
## starts, and drives the door through the SAME commands the seat's hand issues -- `Command.move` with an
## aimed, held MINE, `Command.collect` every tick as the walk-over pickup, `Command.select`, `Command.drop`,
## `Command.build` -- while `Objectives`, the HUD's own ladder, watches the observations it would watch.
## Every rung it asserts latches on the ladder the player sees. Nothing is stocked, nothing is warped; the
## body walks. `tests/test_objectives.gd` proves the ladder's arithmetic on hand-built observations; this
## suite proves the WORLD can satisfy it, which is the thing that was false: the vein yielded `ore_iron`,
## the ladder and the forge wanted `ore`, nothing pressed collect, and no drill existed to build.
##
## Rungs 1-6 (mine, smelt, wood, build, fuel, first automation) are driven to completion. Rungs 7-9
## (hopper, power, winch) need the crew's cache, which lies behind rock beside the ingot cell; this suite
## asserts the cache is THERE with every machine those rungs name, and leaves the winch's link to the
## human -- stated here so the gap is a fact and not a hope.

const SEED: int = 20260826
const ANCHOR := Vector2i(32, 20)          # (spawn_col_m, SURFACE_ROW_M): the record's own origin, logic cells
const DT: float = 1.0 / 60.0
const M_PX: float = 16.0                   # world px a metre

var door: Interface
var world: World
var items: Items
var machines: Machines
var body: Body
var obj: Objectives
var oracle: Interface.Envelope
var ticks: int = 0


func _initialize() -> void:
	_test_a_stranger_completes_the_starter_loop()
	_finish("tutorial_playthrough")


# --- the hand ------------------------------------------------------------------------------------------

func _frame(move: int = 0, jump: bool = false) -> InputFrame:
	var f: InputFrame = InputFrame.new()
	f.move_dir = move
	f.jump_pressed = jump
	f.jump_held = jump
	return f


## One tick through the door, as the seat does it: the frame, then the standing collect, then any verbs,
## then the observation the HUD's ladder reads.
func _tick(f: InputFrame, verbs: Array[Command] = []) -> Interface.Observation:
	door.apply(Command.move(f))
	door.apply(Command.collect())
	for c: Command in verbs:
		door.apply(c)
	var o: Interface.Observation = door.observe(oracle)
	obj.refresh(o, DT)
	ticks += 1
	return o


func _body_m() -> Vector2:
	return Vector2(float(body.pos_x), float(body.pos_y)) / float(Fx.SCALE) / M_PX


## Walk until the body's centre is within a third of a metre of `x_m`, jumping when a step blocks the way.
func _walk_to(x_m: float, max_ticks: int = 900) -> bool:
	var stuck: int = 0
	for _i: int in max_ticks:
		var dx: float = x_m - _body_m().x
		if absf(dx) < 0.34:
			_tick(_frame())
			return true
		var before: float = _body_m().x
		_tick(_frame(1 if dx > 0.0 else -1, stuck > 6))
		stuck = stuck + 1 if absf(_body_m().x - before) < 0.005 else 0
	return false


## Hold MINE on a terrain cell until `done` says so, or the budget runs out. Returns the ticks spent.
func _mine(cell: Vector2i, done: Callable, max_ticks: int = 1200) -> int:
	for i: int in max_ticks:
		var f: InputFrame = _frame()
		f.has_aim = true
		f.aim_col = cell.x
		f.aim_row = cell.y
		f.mine_held = true
		_tick(f)
		if bool(done.call()):
			return i + 1
	return max_ticks


func _slot_of(item: StringName) -> int:
	var slots: Array[Dictionary] = items.pack.slots()
	for i: int in slots.size():
		if slots[i]["item"] == item:
			return i
	return -1


func _wait(n: int, until: Callable = Callable()) -> void:
	for _i: int in n:
		_tick(_frame())
		if until.is_valid() and bool(until.call()):
			return


func _tc(logic: Vector2i) -> Vector2i:
	return Vector2i(logic.x * 4 + 1, logic.y * 4 + 1)   # a terrain cell inside the metre


# --- the playthrough -----------------------------------------------------------------------------------

func _test_a_stranger_completes_the_starter_loop() -> void:
	door = Session.new_game(StrataData.SHALLOW_CLAY, SEED, &"tutorial")
	_check(door != null, "the tutorial starts (%s)" % WorldSeeder.last_refusal)
	if door == null:
		return
	world = door.services()["world"]
	items = door.services()["items"]
	machines = door.services()["machines"]
	body = door.services()["body"]
	oracle = Interface.Envelope.oracle_over(world.grid)
	obj = Objectives.new()
	_tick(_frame())
	_check(obj.current_id() == &"mine" and items.pack.slots().is_empty(), "a new game opens on the first rung with an empty pack")
	_rungs_mine_and_smelt()
	_rungs_wood_and_build()
	_rungs_fuel_and_automation()
	_the_cache_is_in_the_world()
	_check(world.state_signature() == world.recomputed_signature(), "the world's signature agrees with its rebuild after %d ticks" % ticks)
	print("tutorial_playthrough: rungs 1-6 in %d ticks (%.1f s of play)" % [ticks, ticks / 60.0])


## 1. MINE: the vein two metres left of spawn, in the surface row. 2. SMELT: walk to the forge pocket three
## metres left, drop the ore into its mouth, wait, and the walk-over collect takes the ingots.
func _rungs_mine_and_smelt() -> void:
	var vein: Vector2i = _tc(ANCHOR + Vector2i(-1, 0))
	_check(world.grid.get_material(vein) == &"ore_iron", "the starter vein is iron ore at %s" % [vein])
	_walk_to(float(ANCHOR.x) - 0.5)
	var spent: int = _mine(vein, func() -> bool: return obj.is_done(&"mine"))
	_check(obj.is_done(&"mine"), "rung 1 latches: %d ore in the pack after %d ticks of holding MINE (the vein yields `ore`, the ladder's word)" % [items.pack.count(&"ore"), spent])
	_check(items.pack.count(&"ore") >= 4 and items.pack.count(&"ore_iron") == 0, "and what the hand holds is `ore`, never the material's name")
	_walk_to(float(ANCHOR.x) - 2.0)
	var forge: MachineState = machines.machine_at(ANCHOR + Vector2i(-3, 0))
	_check(forge != null and forge.def.id == &"processor", "the bootstrap forge stands three metres left of spawn")
	_tick(_frame(), [Command.select(_slot_of(&"ore"))])
	var r: Interface.Result = door.apply(Command.drop())
	_check(r.ok and int(forge.input_buffer.get(&"ore", 0)) >= 4, "drop feeds the forge in reach: %s, %d ore in its mouth" % [r.detail, int(forge.input_buffer.get(&"ore", 0))])
	_wait(600, func() -> bool: return obj.is_done(&"smelt"))
	_check(obj.is_done(&"smelt"), "rung 2 latches: %d ingots collected off the pocket floor by walking near it (no key)" % obj.gained(&"ingot"))


## 3. WOOD: the nearest trunk stands fifteen metres west; walk to it and fell it. 4. BUILD: back east, dig
## down into the adit where the crew's drill lies, take it, climb out, set it in the shaft mouth.
func _rungs_wood_and_build() -> void:
	var trunk: Vector2i = _nearest_wood()
	_check(trunk != Vector2i(-1, -1), "a tree stands within reach of the spawn pad (%s)" % [trunk])
	var arrived: bool = _walk_to(float(trunk.x) / 4.0 + 1.25)
	_check(arrived, "the body walks to the trunk (%.1f m from spawn, at x %.1f m)" % [absf(float(trunk.x) / 4.0 - float(ANCHOR.x)), _body_m().x])
	var felled: int = _fell(trunk)
	_check(obj.is_done(&"wood"), "rung 3 latches: wood in the pack (%d) after %d trunk cells felled -- sixteen cells make a block" % [items.pack.count(&"wood"), felled])
	_walk_to(float(ANCHOR.x) + 4.5)
	_check(items.pack.count(&"drill") == 0, "the drill lies in the adit below, not in the pack: nothing was stocked")
	_dig_down_to(ANCHOR + Vector2i(4, 3))
	_wait(30, func() -> bool: return items.pack.count(&"drill") > 0)
	_check(items.pack.count(&"drill") == 1, "the crew's drill is picked up by walking over it in the adit (body at %s, %.2f m)" % [Aim.logic_cell_of(body.pos_x, body.pos_y), _body_m().y])
	_climb_out(ANCHOR + Vector2i(4, 3))
	_walk_to(float(ANCHOR.x) + 6.5)
	_tick(_frame(), [Command.select(_slot_of(&"drill"))])
	var rb: Interface.Result = door.apply(Command.build(ANCHOR + Vector2i(7, 1)))
	_tick(_frame())
	_check(rb.ok and obj.is_done(&"build"), "rung 4 latches: the drill stands in the shaft above the vein (%s)" % rb.detail)


## 5. FUEL: the coal seam by the shaft, then drop coal on the drill. 6. AUTO: stand back -- the drill bores,
## the ore falls into the forge below, ingots come out, the rate list moves.
func _rungs_fuel_and_automation() -> void:
	_walk_to(float(ANCHOR.x) + 5.5)
	_mine(_tc(ANCHOR + Vector2i(5, 0)), func() -> bool: return items.pack.count(&"coal") >= 2)
	_check(items.pack.count(&"coal") >= 2, "coal dug from the seam (%d)" % items.pack.count(&"coal"))
	_walk_to(float(ANCHOR.x) + 6.5)
	_tick(_frame(), [Command.select(_slot_of(&"coal"))])
	var rf: Interface.Result = door.apply(Command.drop())
	_tick(_frame())
	_check(rf.ok and obj.is_done(&"fuel"), "rung 5 latches: the drill is fuelled (%s)" % rf.detail)
	_wait(1800, func() -> bool: return obj.is_done(&"auto"))
	_check(obj.is_done(&"auto"), "rung 6 latches: first automation -- the line runs on its own (%d ticks in)" % ticks)
	_check(obj.current_id() == &"hopper", "the ladder stands on rung 7 with six behind it")


## 7-9: the crew's cache, stated as a fact -- the machines those rungs name exist, as piles or scooped.
func _the_cache_is_in_the_world() -> void:
	var cache: Dictionary = {}
	for c: Vector2i in items.piles.pile_logic_cells():
		for item: Variant in items.piles.pile(c):
			cache[item] = true
	var supplied: int = 0
	for m: StringName in [&"hopper", &"generator", &"winch_head", &"winch_station"]:
		if cache.has(m) or items.pack.count(m) > 0:
			supplied += 1
	_check(supplied == 4, "the machines rungs 7-9 name are in the world -- the crew's cache under the spawn, or already scooped (%d of 4; piles %s, pack %s)" % [supplied, cache.keys(), items.pack.slots()])


func _nearest_wood() -> Vector2i:
	var best := Vector2i(-1, -1)
	for col: int in range(ANCHOR.x * 4 - 120, ANCHOR.x * 4 + 120):
		for row: int in range(ANCHOR.y * 4 - 60, ANCHOR.y * 4 + 4):
			var c := Vector2i(col, row)
			if world.grid.get_material(c) == &"wood" and (best == Vector2i(-1, -1) or absi(c.x - ANCHOR.x * 4) < absi(best.x - ANCHOR.x * 4)):
				best = c
	return best


## Fell the trunk `wood_cell` stands in: every wood cell in its column and the one beside it, bottom up,
## each held until it breaks. Returns the cells broken.
func _fell(wood_cell: Vector2i) -> int:
	var cols: Array[int] = [wood_cell.x]
	for dx: int in [-1, 1]:
		if world.grid.get_material(Vector2i(wood_cell.x + dx, wood_cell.y)) == &"wood":
			cols.append(wood_cell.x + dx)
	var broken: int = 0
	for row: int in range(ANCHOR.y * 4 + 3, ANCHOR.y * 4 - 60, -1):
		for col: int in cols:
			var c := Vector2i(col, row)
			if world.grid.get_material(c) != &"wood":
				continue
			_mine(c, func() -> bool: return not world.grid.is_solid(c), 300)
			if not world.grid.is_solid(c):
				broken += 1
			if obj.is_done(&"wood"):
				return broken
	return broken


## Dig straight down from where the body stands until it rests in `logic`: the first solid metre under
## the body's column is the one to open, then fall, then again.
func _dig_down_to(logic: Vector2i) -> void:
	for _i: int in 12:
		var at: Vector2i = Aim.logic_cell_of(body.pos_x, body.pos_y)
		if at.y >= logic.y:
			return
		var ground: Vector2i = at
		while world.logic_open(ground) and ground.y < logic.y + 2:
			ground.y += 1
		_open_metre(ground)
		_wait(60)


## Hold MINE on each still-solid cell of a metre in turn until the whole metre is open: a blow breaks a
## pattern of cells around the aim, and an aim that has become air charges nothing.
func _open_metre(logic: Vector2i) -> void:
	for _pass: int in 3:
		for c: Vector2i in world.terrain_cells_of(logic):
			if not world.grid.is_solid(c):
				continue
			_mine(c, func() -> bool: return not world.grid.is_solid(c), 240)
		if world.logic_open(logic):
			return


## Climb out of a one-metre-wide well: jump with the wall as the way up (the mantle), east.
func _climb_out(_well: Vector2i) -> void:
	for _i: int in 240:
		if Aim.logic_cell_of(body.pos_x, body.pos_y).y <= ANCHOR.y - 1:
			return
		_tick(_frame(1, true))
