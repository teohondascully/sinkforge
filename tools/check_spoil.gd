extends "res://tools/check_base.gd"

## SPOIL IS NOT WASTE — IT IS WHAT THE FRONTIER IS MADE OF.
##
## `docs/DRIFT.md` §4 makes two claims that only mean anything if they are enforced, and both of them are
## the kind that would keep LOOKING right long after they stopped being true.
##
##   THE CRUSHER EATS SPOIL AND ONLY SPOIL. Two units of rock become one of gravel — the sink that makes a
##     gallery's spoil stream survivable — and PAY FALLS STRAIGHT THROUGH IT. A crusher that quietly ate ore
##     would be a trap wearing a machine's face, and you would not notice for an hour.
##   PACKING IS REAL. A gallery backfilled with the stone you dug out of it WEEPS: water leans on loose fill
##     and finds its way through. The same gallery packed with gravel does not. That difference is the whole
##     reason the Crusher exists, so it is asserted from both sides — the loose wall must leak, the packed
##     wall must hold — and neither assertion is worth anything without the other.
##   MATTER IS STILL NEVER DELETED. The crusher CONSUMES two and PRODUCES one; the ledger has to say so.
##     Water is MOVED through a seeping wall and never created, exactly as WaterFlow moves it.
##   AND IT NEVER BECOMES HOUSEKEEPING (§5). No spoil meter, no refusal to run: a full crusher jams its own
##     output like every other machine and the rig upstream keeps cutting into its own belly.

var _sim: FactorySim
var _def: MachineDef


func _initialize() -> void:
	print("== spoil, crushed and packed ==")
	_def = load("res://src/data/machines/crusher.tres") as MachineDef
	_check(_def != null and _def.behavior == &"crush", "fixture: the Crusher def loads")
	if _def == null:
		quit(1)
		return
	_it_crushes()
	_pay_falls_through()
	_power_not_coal()
	_loose_fill_weeps()
	_packed_gravel_holds()
	_the_chain()
	if _failures == 0:
		print("check_spoil: PASS — spoil crushes to gravel, and only packed gravel holds water back")
		quit(0)
	else:
		printerr("check_spoil: FAIL — %d failure(s)" % _failures)
		quit(1)

## Ticks driven ONE AT A TIME: advance() caps the backlog it will chew in a single call, so handing it
## twenty seconds at once runs a fraction of them and reads as "the machine does nothing".
func _advance(seconds: float) -> void:
	for _i: int in int(seconds / FactorySim.SECONDS_PER_TICK):
		_sim.tick()


## A powered crusher standing on rock, with a drain under it so its gravel has somewhere to fall.
func _crusher(at: Vector2i, powered: bool = true, drain: bool = true) -> MachineState:
	_sim = FactorySim.new()
	for x: int in range(at.x - 4, at.x + 5):
		_sim.set_solid(Vector2i(x, at.y + 1), &"stone")
		_sim.set_solid(Vector2i(x, at.y + 6), &"stone")     # a catch floor, or the haul falls out of the world
	if drain:
		_sim.set_solid(Vector2i(at.x, at.y + 1), &"")
	var m: MachineState = _sim.place_machine(_def, at)
	if powered:
		var gen: MachineDef = load("res://src/data/machines/generator.tres") as MachineDef
		var g: MachineState = _sim.place_machine(gen, at + Vector2i(-1, 0))
		g.input_buffer[&"coal"] = 200
		g.fuel = FactorySim.GENERATOR_FUEL_TICKS
	return m


## Everything resting on the ground of one column, summed.
func _column_haul(col: int, from_row: int) -> Dictionary:
	var out: Dictionary = {}
	for row: int in range(from_row, FactorySim.GRID_ROWS):
		var pile: Dictionary = _sim.ground.get(Vector2i(col, row), {})
		for item: StringName in pile:
			out[item] = int(out.get(item, 0)) + int(pile[item])
	return out


## TWO IN, ONE OUT — and the ledger says both halves of that.
func _it_crushes() -> void:
	var at := Vector2i(40, 40)
	var m: MachineState = _crusher(at)
	m.input_buffer[&"stone"] = 12
	m.input_buffer[&"earth"] = 8
	_advance(24.0)
	var out: Dictionary = _column_haul(at.x, at.y + 1)
	print("  crusher out: %s   ·   still holding: %s" % [out, m.input_buffer])
	var gravel: int = int(out.get(&"gravel", 0)) + int(m.output_buffer.get(&"gravel", 0))
	_check(gravel > 0, "the crusher pours GRAVEL (%d of it)" % gravel)
	_check(int(out.get(&"stone", 0)) == 0 and int(out.get(&"earth", 0)) == 0,
		"…and no uncrushed rock ever reaches the column below")
	var eaten: int = int(_sim.total_consumed.get(&"stone", 0)) + int(_sim.total_consumed.get(&"earth", 0))
	_check(eaten == gravel * FactorySim.CRUSH_RATIO,
		"the ledger balances: %d spoil consumed → %d gravel at %d:1" % [eaten, gravel, FactorySim.CRUSH_RATIO])
	_check(int(_sim.total_produced.get(&"gravel", 0)) == gravel,
		"…and every gravel it made is on the produced ledger — the stream halves, it doesn't vanish")


## PAY FALLS STRAIGHT THROUGH. The single most important property of this machine, because the failure is
## silent: a crusher that ate ore would still hum, still pour gravel, and still look completely fine.
func _pay_falls_through() -> void:
	var at := Vector2i(40, 40)
	var m: MachineState = _crusher(at)
	m.input_buffer[&"ore"] = 9
	m.input_buffer[&"iron"] = 3
	m.input_buffer[&"stone"] = 6
	_advance(24.0)
	var out: Dictionary = _column_haul(at.x, at.y + 1)
	_check(int(out.get(&"ore", 0)) == 9 and int(out.get(&"iron", 0)) == 3,
		"every scrap of pay passes through the crusher UNTOUCHED (ore %d, iron %d)"
			% [int(out.get(&"ore", 0)), int(out.get(&"iron", 0))])
	_check(int(_sim.total_consumed.get(&"ore", 0)) == 0,
		"…and the crusher never consumes an ore — it is a filter, not a furnace")
	_check(int(out.get(&"gravel", 0)) > 0, "…while the rock in the same stream still becomes gravel")


## POWER, NOT COAL — the whole rung's constraint. Unpowered it holds its spoil and says so.
func _power_not_coal() -> void:
	var at := Vector2i(40, 40)
	var m: MachineState = _crusher(at, false)
	m.input_buffer[&"stone"] = 10
	_advance(20.0)
	_check(int(_sim.total_produced.get(&"gravel", 0)) == 0, "unpowered, it crushes nothing")
	_check(_sim.machine_status(m) == &"no_power", "…and says so — 'no power', in its own word")
	_check(int(_sim.total_consumed.get(&"coal", 0)) == 0, "…and burns no coal doing it")
	var m2: MachineState = _crusher(at, true)
	m2.input_buffer[&"stone"] = 10
	_advance(20.0)
	_check(int(_sim.total_produced.get(&"gravel", 0)) > 0, "powered, it runs")
	_check(m2.power_factor >= 1.0,
		"…and a LONE generator is enough for one crusher (%.2f of full)" % m2.power_factor)


## A tank of water with a wall between its two halves: `mat` built by hand at column x=wall_x, rows y0..y1.
## Returns the sim. Water sits on the LEFT of the wall; the right side starts dry.
func _tank(mat: StringName, rows: int = 4) -> int:
	_sim = FactorySim.new()
	var wall_x: int = 40
	var y0: int = 40
	# A sealed box: floor, ceiling and two end walls, so the only way across is THROUGH the built wall.
	for x: int in range(wall_x - 5, wall_x + 6):
		_sim.set_solid(Vector2i(x, y0 + rows), &"stone")
		_sim.set_solid(Vector2i(x, y0 - 1), &"stone")
	for y: int in range(y0, y0 + rows):
		_sim.set_solid(Vector2i(wall_x - 5, y), &"stone")
		_sim.set_solid(Vector2i(wall_x + 5, y), &"stone")
	# The wall you BUILT — place_block, not set_solid, because the whole point is that fill is construction.
	_sim.inventory[mat] = rows
	for y2: int in range(y0, y0 + rows):
		var ok: bool = _sim.place_block(Vector2i(wall_x, y2), mat)
		_check(ok, "fixture: a %s block goes into the wall at row %d" % [str(mat), y2])
	for y3: int in range(y0, y0 + rows):                       # fill the left half to the brim
		for x2: int in range(wall_x - 4, wall_x):
			_sim.add_water(Vector2i(x2, y3), FactorySim.WATER_MAX)
	return wall_x


## How much water has arrived on the DRY side of the wall.
func _far_side(wall_x: int) -> int:
	var sum: int = 0
	for cell: Vector2i in _sim.water:
		if cell.x > wall_x:
			sum += int(_sim.water[cell])
	return sum


## LOOSE FILL WEEPS. Backfill a gallery with the stone you dug out of it and the aquifer finds its way in.
func _loose_fill_weeps() -> void:
	var wall_x: int = _tank(&"stone")
	var before: int = _sim.total_water()
	_advance(60.0)
	var through: int = _far_side(wall_x)
	print("  loose stone wall: %d units of water found their way through in a minute" % through)
	_check(through > 0, "a wall of LOOSE FILL weeps — the rock you stacked back is not a bulkhead")
	_check(_sim.total_water() == before,
		"…and not one unit was created doing it (%d in, %d out)" % [before, _sim.total_water()])
	_check(_sim.is_loose_fill(Vector2i(wall_x, 40)),
		"…and the sim knows why: the cell is LOOSE fill, not strata")


## PACKED GRAVEL HOLDS. The payoff, and the reason there is a machine on this rung at all.
func _packed_gravel_holds() -> void:
	var wall_x: int = _tank(&"gravel")
	_advance(60.0)
	print("  packed gravel wall: %d units through" % _far_side(wall_x))
	_check(_far_side(wall_x) == 0, "a PACKED GRAVEL wall holds the water back completely")
	_check(_sim.is_packed(Vector2i(wall_x, 40)), "…and reads as packed, which is what the renderer draws")
	# And the world's own rock is not fill at all — strata never seeps, only your own construction does.
	_check(not _sim.is_loose_fill(Vector2i(wall_x - 5, 41)) and not _sim.is_packed(Vector2i(wall_x - 5, 41)),
		"…while undisturbed strata is neither: the seep is a property of what YOU built")


## THE CHAIN, end to end: a Drift Rig cutting rock drops its spoil down the column behind it, into a
## crusher, which pours gravel. That is the sentence docs/DRIFT.md §4 is written to make true.
func _the_chain() -> void:
	_sim = FactorySim.new()
	var at := Vector2i(40, 40)
	var rig_def: MachineDef = load("res://src/data/machines/drift_rig.tres") as MachineDef
	for k: int in range(1, 9):                                 # plain rock: all spoil, which is the point
		for dy: int in [0, -1]:
			_sim.set_solid(Vector2i(at.x + k, at.y + dy), &"stone")
	for x: int in range(at.x - 4, at.x + 10):
		_sim.set_solid(Vector2i(x, at.y + 1), &"stone")
		_sim.set_solid(Vector2i(x, at.y + 8), &"stone")
	_sim.set_solid(Vector2i(at.x - 1, at.y + 1), &"")          # the spoil shaft, dug by hand
	var rig: MachineState = _sim.place_machine(rig_def, at)
	rig.facing = 1
	var crusher: MachineState = _sim.place_machine(_def, at + Vector2i(-1, 2))
	var gen: MachineDef = load("res://src/data/machines/generator.tres") as MachineDef
	for d: Vector2i in [Vector2i(-1, -4), Vector2i(0, -4), Vector2i(1, -4)]:
		var g: MachineState = _sim.place_machine(gen, at + d)
		g.input_buffer[&"coal"] = 200
		g.fuel = FactorySim.GENERATOR_FUEL_TICKS
	_sim.inventory[&"conduit"] = 40
	for k2: int in range(3, 0, -1):
		_sim.place_conduit(at + Vector2i(0, -k2))
	# A branch down the SPOIL column to the crusher. Power spreads sideways from the trunk and then down;
	# a lone tap two cells off the trunk is not connected to anything, which is how the first build of this
	# fixture ended up with a crusher reading `no_power` under a perfectly good generator bank.
	for d2: Vector2i in [Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1)]:
		_sim.place_conduit(at + d2)
	_advance(40.0)
	var made: int = int(_sim.total_produced.get(&"gravel", 0))
	print("  rig → spoil column → crusher: %d gravel, crusher status %s"
		% [made, str(_sim.machine_status(crusher))])
	_check(made > 0, "a gallery's spoil stream falls into a crusher and comes out as gravel, hands-free")
	_check(int(_sim.total_produced.get(&"stone", 0)) >= made * FactorySim.CRUSH_RATIO,
		"…and every gravel is accounted for by rock the rig actually cut")
