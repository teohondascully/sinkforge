extends "res://tests/test_base.gd"

## THE SLUMP'S COUPLING TO THE REST OF THE WORLD (A5, A7, A11 — Astra's audit, D0579). `test_slump.gd`
## pins the automaton against a grid posed by hand and `test_slump_body.gd` pins it against the player.
## This file is about the three things the automaton could not see at all:
##
##   A5  MACHINES. They live in `sim/machines`' own registry keyed by metre and never make terrain
##       solid, so `TileGrid.is_solid` cannot see one and falling earth wrote rock into a working
##       machine's cell. Earth now packs around machinery the way D0566 made it pack around the player.
##   A11 THE DRILL. Only a hand blow seeded the queue, so the world answered a pickaxe and ignored the
##       machine doing the same work — exactly backwards for a game about automating the digging.
##   A7  A RELOAD. The queue is transient, so a save mid-collapse came back with the earth standing and
##       nothing to wake it. Two identical factories then evolve differently depending on whether their
##       player reloaded, which is a divergence with a save file in the middle of it.
##
## EVERY TEST HERE DRIVES THE REAL SEAM. The lesson from A9, one commit earlier, is that a helper can be
## green while its call site is deleted; two guards passed that way and only the mutation found it. So
## these go through `MineHold.step` rather than calling `Slump` directly wherever the point is that
## something in the pipeline hands the automaton what it needs.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_slump_world.gd

const LOGIC_W: int = 16
const LOGIC_H: int = 16
const PER: int = LogicGrid.TERRAIN_PER_LOGIC
const LOOSE := &"clay"
const FIRM := &"hardrock"
const ORE := &"ore_iron"        ## `WorldMaterials.is_ore_like`; a drill only bores these


func _initialize() -> void:
	_test_falling_earth_packs_around_a_machine()
	_test_a_bored_metre_wakes_the_earth_above_it()
	_test_a_collapse_survives_a_capture_and_restore()
	_test_a_save_carries_the_collapse_through_the_real_session_path()
	_finish("slump_world")


## A world of open air with a hardrock floor along its bottom metre.
func _world() -> World:
	var items: Items = _hub_items(LOGIC_W, LOGIC_H)
	var world: World = items.world
	for col: int in range(LOGIC_W * PER):
		for row: int in range((LOGIC_H - 1) * PER, LOGIC_H * PER):
			world.grid.set_material(Vector2i(col, row), FIRM)
	return world


## One tick of the real seam, with a body parked far from the action so its own cell box is irrelevant.
func _tick(hold: MineHold, world: World, items: Items, machines: Machines, body: Body) -> void:
	hold.step(_input(), world, items, machines, Mining.new(), DigPlan.new(), LodeWork.new(), body, false)


func _far_body() -> Body:
	return Body.new(Fx.SCALE, Fx.SCALE)


## A5. A machine occupies a metre; loose earth is dropped down its column. The earth must come to rest ON
## the machine, never inside it. The control is the SAME pose with no machine placed: there the earth
## falls straight through to the floor, which is what proves the machine is what stopped it and not the
## geometry of the test.
func _test_falling_earth_packs_around_a_machine() -> void:
	var landed: Array[int] = []
	for with_machine: bool in [false, true]:
		var items: Items = _hub_items(LOGIC_W, LOGIC_H)
		var world: World = items.world
		for col: int in range(LOGIC_W * PER):
			for row: int in range((LOGIC_H - 1) * PER, LOGIC_H * PER):
				world.grid.set_material(Vector2i(col, row), FIRM)
		var machines: Machines = _hub_machines(items)
		var metre := Vector2i(8, LOGIC_H - 2)
		if with_machine:
			_check(machines.place(world, MachineDef.of(&"hopper"), metre) != null,
					"CONTROL: the machine really was placed at metre %s" % metre)
		var grain := Vector2i(metre.x * PER + 1, 4)
		world.grid.set_material(grain, LOOSE)
		var hold: MineHold = MineHold.new()
		var body: Body = _far_body()
		hold.slump.after_break(world.grid, [grain + Vector2i(0, 1)])
		for _i: int in 400:
			_tick(hold, world, items, machines, body)
		var at: int = -1
		for row: int in range(LOGIC_H * PER):
			if world.grid.get_material(Vector2i(grain.x, row)) == LOOSE:
				at = row
		landed.append(at)
		if with_machine:
			for c: Vector2i in world.terrain_cells_of(metre):
				_check(world.grid.get_material(c) != LOOSE,
						"no clay inside the machine's own cell %s" % c)
	_check(landed[0] > landed[1],
			"CONTROL and result together: with no machine the grain reaches row %d, with one it stops "
			% landed[0] + "at row %d — higher, on top of it. Equal rows would mean the machine was "
			% landed[1] + "never in the way and every assertion above would be about nothing.")


## A11. `World.bore_one` excavates a metre's cells; the earth above must answer. Driven through the real
## seam because the whole defect was a missing channel between two systems, not a wrong rule in either.
func _test_a_bored_metre_wakes_the_earth_above_it() -> void:
	var moved: Array[bool] = []
	for bore: bool in [false, true]:
		var items: Items = _hub_items(LOGIC_W, LOGIC_H)
		var world: World = items.world
		var machines: Machines = _hub_machines(items)
		var metre := Vector2i(6, 8)
		# ORE, not plain rock: `DepositPlane.ore_deposit_at` answers 0 for anything that is not
		# `is_ore_like`, so a drill posed over hardrock bores nothing and the test would measure that
		# instead of the wake channel. Its own control caught this.
		for c: Vector2i in world.terrain_cells_of(metre):
			world.grid.set_material(c, ORE)
			world.deposits.set_deposit(c, 1)
		var above := Vector2i(metre.x * PER, metre.y * PER - 1)
		world.grid.set_material(above, LOOSE)
		if bore:
			# The CONTROL is the excavation, not the returned item. `bore_one` returns
			# `WorldMaterials.yield_of` of the material it broke, and plain hardrock yields nothing --
			# so `!= &""` is false on a bore that worked perfectly. The first version of this test
			# asserted exactly that and failed on its own control.
			world.bore_one(metre)
			_check(not world.grid.is_solid(Vector2i(metre.x * PER, metre.y * PER)),
					"CONTROL: the drill really did bore the metre out")
		var hold: MineHold = MineHold.new()
		var body: Body = _far_body()
		for _i: int in 10:
			_tick(hold, world, items, machines, body)
		moved.append(world.grid.get_material(above) != LOOSE)
	_check(not moved[0],
			"CONTROL: unbored, the earth above hangs — the queue is the active set and nothing woke it")
	_check(moved[1],
			"and a BORED metre wakes it: the drill answers the world the same way a hand blow does. "
			+ "Before this, only a swung pickaxe did, in a game about not swinging one.")


## A7. A collapse interrupted by a save resumes on load, because the queue TRAVELS with the save.
##
## Deriving it on load was tried first and measured wrong: the generated world holds 1061 unsupported
## loose cells, so a rebuild-on-load collapsed a tenth of the world's loose earth on every load while a
## fresh session sat still. `test_boot_snapshot.gd` caught that; see D0579.
func _test_a_collapse_survives_a_capture_and_restore() -> void:
	var world: World = _world()
	var col: int = 20
	for row: int in range(10, 18):
		world.grid.set_material(Vector2i(col, row), LOOSE)
	var live: Slump = Slump.new()
	live.after_break(world.grid, [Vector2i(col, 18)])
	live.settle(world.grid, world.water)
	_check(live.pending() > 0, "CONTROL: a collapse really is in flight (%d owed)" % live.pending())

	var saved: Array[Vector2i] = live.capture()
	_check(saved.size() == live.pending(),
			"the capture carries every cell still owed a look (%d of %d)" % [saved.size(), live.pending()])
	var loaded: Slump = Slump.new()
	_check(loaded.pending() == 0, "CONTROL: and a fresh queue starts empty, so the restore below is not a no-op")
	loaded.restore(saved)
	_check(loaded.pending() == saved.size(),
			"a restored queue holds the same cells (%d)" % loaded.pending())
	for _i: int in 400:
		loaded.settle(world.grid, world.water)
	_check(world.grid.get_material(Vector2i(col, 10)) != LOOSE,
			"and the collapse the save interrupted runs to completion after the load")
	_check(Slump.loose_cells_in(world.grid, Rect2i(0, 0, world.grid.width, world.grid.height)) == 8,
			"with every one of the eight cells still in the world")


## A7's CALL SITE. The test above proves `capture`/`restore` round-trip a queue; it says nothing about
## whether the SAVE carries one. `Session.from_save` builds a door over an empty grid and restores into
## it -- no world generation -- so the real path runs here for the price of a capture. This is the gap
## that let two guards through one commit earlier, and it caught a third: `reset_transients()` replaces
## `_hold`, so the services read at the top of `Session.restore` hold the DISCARDED one.
func _test_a_save_carries_the_collapse_through_the_real_session_path() -> void:
	var pending: Array[int] = []
	for falling: bool in [false, true]:
		var grid: TileGrid = TileGrid.new(LOGIC_W * PER, LOGIC_H * PER, 1)
		var door: Interface = Interface.new(grid, Body.new(4 * PER * Fx.SCALE, 4 * PER * Fx.SCALE), Mining.new())
		var world: World = door.services()["world"]
		for col: int in range(LOGIC_W * PER):
			for row: int in range((LOGIC_H - 1) * PER, LOGIC_H * PER):
				world.grid.set_material(Vector2i(col, row), FIRM)
		if falling:
			for row: int in range(10, 18):
				world.grid.set_material(Vector2i(20, row), LOOSE)
			((door.services()["hold"] as MineHold).slump).after_break(world.grid, [Vector2i(20, 18)])
		var env: Dictionary = Session.capture(door)
		var back: Interface = Session.from_save(env)
		if back == null:
			_check(false, "the envelope restores (%s)" % SaveGame.last_invalid)
			return
		pending.append(((back.services()["hold"] as MineHold).slump).pending())
	_check(pending[0] == 0,
			"CONTROL: a save with nothing falling restores an empty queue (%d) -- which is what every "
			% pending[0] + "save written before this key meant, and they still load")
	_check(pending[1] > 0,
			"and a save taken mid-collapse restores %d cell(s) still owed a look. Before this the "
			% pending[1] + "earth stood forever and two identical factories diverged on whether their "
			+ "player had reloaded.")
