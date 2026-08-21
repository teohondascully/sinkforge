extends "res://tools/check_base.gd"

## EXTRACTION MAY BE LATERAL. LOGISTICS STAYS VERTICAL.
##
## `docs/DRIFT.md` §7 names the properties the Drift Rig must hold, and the reason they are worth a whole
## harness layer is that this is the first machine in the game with TWO outputs that mean different things.
## Every other multi-output machine (the splitter) deals its stream round-robin; if the rig ever fell back
## to that path it would still look like it was working (items would still fall, both columns would still
## fill), and the one thing you bought it for, the sort, would be silently gone. That failure is invisible
## by eye and obvious to an assertion, which is exactly the kind this file is for.
##
##   THE SORT: pay lands in one column, spoil in the other, with ZERO cross-contamination. Checked from
##     both ends: no ore in the spoil column, no rock in the pay column.
##   THE ON-HOOK RULE: neither stream ever moves sideways. This is the GDD's whole division of labour and
##     the property that must never regress: everything the rig produces is found either straight below the
##     rig or straight below the cell behind it, and nowhere else in the world.
##   TWO INDEPENDENT JAMS: a column with no drain pools that stream ALONE, and the status names which one.
##     One shared "blocked" would be a lie on a machine whose two drains are dug in different places.
##   POWER, NOT COAL: unpowered it does nothing at all, and it never consumes a lump of coal to run. The
##     rig is what makes a power network necessary; if it quietly ran on fuel that argument evaporates.
##   IT CUTS TWO HIGH: the gallery it leaves is walkable, which is the difference between a drift and a
##     bore-hole, and the only reason the machine is called what it is called.
##   CONSERVATION: every cell it takes out of the world arrives somewhere as an item. Matter is never
##     deleted, which is the rule the whole spoil design rests on (docs/DRIFT.md §4).

const CELL: int = FactorySim.CELL

var _sim: FactorySim
var _def: MachineDef


func _initialize() -> void:
	print("== the drift rig ==")
	_def = load("res://src/data/machines/drift_rig.tres") as MachineDef
	_check(_def != null and _def.behavior == &"drift", "fixture: the Drift Rig def loads")
	if _def == null:
		quit(1)
		return
	_the_sort()
	_the_hook()
	_two_jams()
	_power_not_coal()
	_two_high()
	if _failures == 0:
		print("check_drift: PASS — it sorts at the face, and neither stream ever moves sideways")
		quit(0)
	else:
		printerr("check_drift: FAIL — %d failure(s)" % _failures)
		quit(1)

## A world with a rig at `at` facing +1, a mixed wall in front of it, and (unless `drains` says otherwise)
## an open shaft under both of its columns so the haul has somewhere to go.
## `wall_mix` true = alternating ore and stone two cells high, so both streams have work every step;
## false = plain stone, for the checks that want cells to CLEAR fast (an ore cell drains unit by unit, so a
## mixed wall measures the deposit size as much as the machine).
func _rig(at: Vector2i, wall: int, drain_pay: bool, drain_spoil: bool, powered: bool,
		wall_mix: bool = true) -> MachineState:
	_sim = FactorySim.new()
	for k: int in range(1, wall + 1):
		for dy: int in [0, -1]:
			var mat: StringName = &"stone"
			if wall_mix and (k + dy) % 2 == 0:
				mat = &"ore"
			_sim.set_solid(Vector2i(at.x + k, at.y + dy), mat)
	# The floor under everything, so an undrained column really is sealed rock rather than open sky...
	for x: int in range(at.x - 4, at.x + wall + 3):
		_sim.set_solid(Vector2i(x, at.y + 1), &"stone")
	# ...and a CATCH FLOOR six rows down, because a drained column with nothing under it drops its haul
	# clean out of the world into the sink, and a test that measured that would be measuring the void.
	for x: int in range(at.x - 4, at.x + wall + 3):
		_sim.set_solid(Vector2i(x, at.y + 7), &"stone")
	if drain_pay:
		_sim.set_solid(Vector2i(at.x, at.y + 1), &"")
	if drain_spoil:
		_sim.set_solid(Vector2i(at.x - 1, at.y + 1), &"")
	var m: MachineState = _sim.place_machine(_def, at)
	m.facing = 1
	if powered:
		_power(at)
	return m


## ONE generator beside the rig: the aura case, which is deliberately not enough for full speed (auras take
## the max and never sum, so the most a machine standing beside a generator ever reads is 4.0 of the rig's
## 6.0). The rig labours at two-thirds. That is the design, and building the fixture states it.
func _power(at: Vector2i) -> void:
	var gen: MachineDef = load("res://src/data/machines/generator.tres") as MachineDef
	var g: MachineState = _sim.place_machine(gen, at + Vector2i(-1, 0))
	g.input_buffer[&"coal"] = 200
	g.fuel = FactorySim.GENERATOR_FUEL_TICKS


## Ticks driven ONE AT A TIME. `advance()` caps how much backlog it will chew in a single call, so handing
## it twenty seconds at once silently runs a fraction of them, which reads as "the machine does nothing".
func _advance(seconds: float) -> void:
	for _i: int in int(seconds / FactorySim.SECONDS_PER_TICK):
		_sim.tick()


## Everything resting on the ground of one column, summed.
func _column_haul(col: int, from_row: int) -> Dictionary:
	var out: Dictionary = {}
	for row: int in range(from_row, FactorySim.GRID_ROWS):
		var pile: Dictionary = _sim.ground.get(Vector2i(col, row), {})
		for item: StringName in pile:
			out[item] = int(out.get(item, 0)) + int(pile[item])
	return out


## THE SORT, from both ends.
func _the_sort() -> void:
	var at := Vector2i(40, 40)
	var m: MachineState = _rig(at, 10, true, true, true)
	_advance(24.0)
	var pay: Dictionary = _column_haul(at.x, at.y + 1)
	var spoil: Dictionary = _column_haul(at.x - 1, at.y + 1)
	print("  pay column %s   ·   spoil column %s" % [pay, spoil])
	_check(int(pay.get(&"ore", 0)) > 0, "the rig sends ORE down its own column")
	_check(int(spoil.get(&"stone", 0)) > 0, "…and STONE down the column behind it")
	_check(int(pay.get(&"stone", 0)) == 0, "no spoil ever reaches the ore column")
	_check(int(spoil.get(&"ore", 0)) == 0, "…and no ore ever reaches the spoil column — the sort is total")
	_check(m.def.behavior == &"drift", "…and it is the rig doing it, not a splitter downstream")


## THE ON-HOOK RULE. Not "it usually falls down": nothing it produced may exist in ANY other column of the
## world, which is the only way to state "never moves sideways" as an assertion.
func _the_hook() -> void:
	var at := Vector2i(40, 40)
	_rig(at, 10, true, true, true)
	_advance(24.0)
	var strays: int = 0
	for cell: Vector2i in _sim.ground:
		if cell.x != at.x and cell.x != at.x - 1:
			for item: StringName in (_sim.ground[cell] as Dictionary):
				strays += int((_sim.ground[cell] as Dictionary)[item])
	_check(strays == 0, "NOTHING the rig cut left by any column but its two (%d stray item(s))" % strays)

	# CONSERVATION: every cell it removed arrived somewhere as an item.
	var produced: int = 0
	for item: StringName in _sim.total_produced:
		produced += int(_sim.total_produced[item])
	var landed: int = 0
	for cell: Vector2i in _sim.ground:
		for item: StringName in (_sim.ground[cell] as Dictionary):
			landed += int((_sim.ground[cell] as Dictionary)[item])
	var m: MachineState = _sim.machine_at(at)
	for buf: Dictionary in [m.output_buffer, m.spoil_buffer]:
		for item: StringName in buf:
			landed += int(buf[item])
	print("  produced %d, still accounted for %d" % [produced, landed])
	_check(produced > 0 and landed == produced, "every cell it took is still matter somewhere")


## TWO INDEPENDENT JAMS, and a status that says which.
func _two_jams() -> void:
	# Spoil sealed, pay draining: the ore keeps coming and the status blames the spoil column BY NAME.
	var at := Vector2i(40, 40)
	var m: MachineState = _rig(at, 12, true, false, true)
	# A rig that has already been running: its spoil belly is one bite from the cap. Priming beats waiting
	# forty-eight seconds of sim for a property that is about the CAP, not about how long it takes to reach.
	m.spoil_buffer[&"stone"] = FactorySim.DRIFT_BELLY - 1
	_advance(40.0)
	var pay: Dictionary = _column_haul(at.x, at.y + 1)
	var pooled: int = 0
	for item: StringName in m.spoil_buffer:
		pooled += int(m.spoil_buffer[item])
	print("  spoil sealed: %d ore delivered, %d spoil pooled, status %s"
		% [int(pay.get(&"ore", 0)), pooled, _sim.machine_status(m)])
	_check(int(pay.get(&"ore", 0)) > 0, "a jammed SPOIL column does not stop the ore coming")
	_check(pooled > 0, "…the spoil pools in its own belly rather than vanishing")
	_check(_sim.machine_status(m) == &"blocked_spoil",
		"…and the status names the SPOIL column the moment it is full, not just 'blocked'")

	# The mirror: pay sealed, spoil draining.
	var m2: MachineState = _rig(at, 12, false, true, true)
	m2.output_buffer[&"ore"] = FactorySim.DRIFT_BELLY - 1
	_advance(40.0)
	var spoil2: Dictionary = _column_haul(at.x - 1, at.y + 1)
	_check(int(spoil2.get(&"stone", 0)) > 0, "a jammed ORE column does not stop the spoil leaving")
	_check(_sim.machine_status(m2) == &"blocked_pay", "…and the status names the ORE column")


## POWER, NOT COAL.
func _power_not_coal() -> void:
	var at := Vector2i(40, 40)
	var m: MachineState = _rig(at, 8, true, true, false)
	var solid_before: int = _sim.solid.size()
	_advance(20.0)
	_check(_sim.solid.size() == solid_before, "unpowered, the rig cuts NOTHING at all")
	_check(_sim.machine_status(m) == &"no_power", "…and says so — 'no power', in its own word")
	_check(int(_sim.total_consumed.get(&"coal", 0)) == 0, "…and it never burned a lump of coal to try")

	# Powered, it runs: same fixture, one difference, so the check is about power and nothing else.
	var m2: MachineState = _rig(at, 8, true, true, true)
	var before2: int = _sim.solid.size()
	_advance(20.0)
	_check(_sim.solid.size() < before2, "powered, it cuts")
	_check(m2.power_factor > 0.0 and m2.power_factor < 1.0,
		"…and LABOURS on one generator's aura rather than refusing (%.2f of full)" % m2.power_factor)

	# ...and a real network gets it to full. This is the assertion that keeps DRIFT_POWER_DEMAND honest: a
	# demand no achievable network can meet is a number that only ever punishes.
	var m3: MachineState = _rig(at, 8, true, true, false)
	var gen: MachineDef = load("res://src/data/machines/generator.tres") as MachineDef
	for d: Vector2i in [Vector2i(-1, -4), Vector2i(0, -4), Vector2i(1, -4)]:
		var g: MachineState = _sim.place_machine(gen, at + d)
		g.input_buffer[&"coal"] = 200
		g.fuel = FactorySim.GENERATOR_FUEL_TICKS
	_sim.inventory[&"conduit"] = 40
	for k: int in range(3, 0, -1):
		_sim.place_conduit(at + Vector2i(0, -k))
	_advance(1.0)
	print("  three generators on a conduit trunk: throttle %.2f" % m3.power_factor)
	_check(m3.power_factor >= 1.0, "a real conduit trunk runs the rig at FULL speed — the demand is meetable")


## IT CUTS TWO HIGH, and only two. A rig that quietly cut one row is a Borer with a new name; one that cut
## three would eat the gallery's ceiling out from over your head.
func _two_high() -> void:
	var at := Vector2i(40, 40)
	_rig(at, 8, true, true, true, false)
	for k: int in range(1, 9):
		_sim.set_solid(Vector2i(at.x + k, at.y - 2), &"stone")   # a real ceiling to try to eat
	_advance(30.0)
	var cut_lo: int = 0
	var cut_hi: int = 0
	var cut_above: int = 0
	# The ceiling row is FILLED by the fixture here, so "did it cut above the head" is a real question
	# rather than a reading of empty sky.
	for k: int in range(1, 5):
		if not _sim.is_solid(Vector2i(at.x + k, at.y)):
			cut_lo += 1
		if not _sim.is_solid(Vector2i(at.x + k, at.y - 1)):
			cut_hi += 1
		if not _sim.is_solid(Vector2i(at.x + k, at.y - 2)):
			cut_above += 1
	print("  after 30s: %d floor cells and %d head cells cut, %d above the head" % [cut_lo, cut_hi, cut_above])
	_check(cut_lo > 0 and cut_hi > 0, "the gallery is cut TWO cells high — you can walk it")
	_check(cut_above == 0, "…and not three: the rig never takes the gallery's ceiling")
