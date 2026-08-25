extends "res://tests/test_base.gd"

## Power and fluids suite: the L2 power field and conduit network (power floods DOWN and lateral,
## never up), the powered lift and the pump (the paid inverses of gravity and flood), and the
## discrete-cell water / aquifer layer. Asserts the power field solves in one top-to-bottom sweep
## and that the flow, drain and lift costs behave deterministically.


func _initialize() -> void:
	print("== power/water tests ==")
	_test_power_field()
	_test_conduit_network()
	_test_powered_lift()
	_test_pump()
	_test_water_fluid()
	_finish("power/water tests")


## A fueled generator pours power into its aura; out of coal it goes dark; the coal is genuinely
## consumed, so conservation holds. The field is derived: recomputed each tick, never stored.
func _test_power_field() -> void:
	print("- power field + generator")
	var gen_def: MachineDef = load("res://src/data/machines/generator.tres")
	var sim: FactorySim = FactorySim.new()
	var cell := Vector2i(8, 8)
	var g: MachineState = sim.place_machine(gen_def, cell)
	# No fuel yet → no power anywhere.
	sim.tick()
	_check(sim.power_at(cell) == 0.0, "an unfueled generator emits no power")
	# Feed it coal (as a drop would) and let it burn.
	g.input_buffer[&"coal"] = 2
	sim.total_produced[&"coal"] = 2                     # account for the injected coal (conservation)
	sim.tick()                                          # consumes 1 coal, fuel set; power appears next tick
	sim.tick()
	_check(sim.power_at(cell) > 0.0, "a fueled generator powers its own cell")
	_check(sim.power_at(cell + Vector2i(1, 0)) > 0.0, "the aura reaches an adjacent cell")
	_check(sim.power_at(cell + Vector2i(0, 1)) > sim.power_at(cell + Vector2i(0, FactorySim.POWER_AURA + 5)),
		"power attenuates with distance (near > far)")
	_check(sim.power_at(cell + Vector2i(0, FactorySim.POWER_AURA + 1)) == 0.0, "no power past the aura rim")
	_check(int(sim.total_consumed.get(&"coal", 0)) == 1, "burned exactly one coal so far")
	# Burn the rest dry, then it should go dark.
	for _i: int in FactorySim.GENERATOR_FUEL_TICKS * 3:
		sim.tick()
	_check(sim.power_at(cell) == 0.0, "out of coal, the generator goes dark")
	_check(int(sim.total_consumed.get(&"coal", 0)) == 2, "consumed both coal total (extraction finite)")
	var present: int = _items_present(sim, &"coal")
	var net: int = int(sim.total_produced.get(&"coal", 0)) - int(sim.total_consumed.get(&"coal", 0))
	_check(present == net, "coal conserved across burning (present=%d, net=%d)" % [present, net])


## Power floods DOWN and LATERAL through conduit tubes, never UP, so a U delivers as an L; and the
## place/remove API moves a carried conduit in and out of the layer. Geometry: a generator at (8,4)
## feeds a down-leg, a lateral bottom, and an up-leg. The up-leg must stay dark even where it sits
## directly above live power.
func _test_conduit_network() -> void:
	print("- conduit network")
	var gen_def: MachineDef = load("res://src/data/machines/generator.tres")
	var sim: FactorySim = FactorySim.new()
	var g: MachineState = sim.place_machine(gen_def, Vector2i(8, 4))
	g.input_buffer[&"coal"] = 5
	sim.total_produced[&"coal"] = 5
	# A U: down the 8-column, across the bottom at row 12, up the 10-column.
	for y: int in range(5, 13):
		sim.conduit[Vector2i(8, y)] = 1            # down leg
	sim.conduit[Vector2i(9, 12)] = 1               # bottom lateral
	sim.conduit[Vector2i(10, 12)] = 1
	for y: int in range(5, 12):
		sim.conduit[Vector2i(10, y)] = 1           # up leg
	for _i: int in 3:
		sim.tick()                                  # fuel up + let the field settle
	_check(sim.power_at(Vector2i(8, 8)) > 0.0, "power reaches down the conduit, past the generator's aura")
	_check(sim.power_at(Vector2i(8, 5)) > sim.power_at(Vector2i(8, 11)), "power attenuates down the trunk")
	_check(sim.power_at(Vector2i(10, 12)) > 0.0, "power carries ACROSS the lateral bottom of the U")
	# The up-leg tube carries NOTHING upward. The corner's immediate up-neighbour gets only a faint
	# 1-cell bleed, so these read from two cells up and higher, where even the bleed is gone and the
	# only thing that could deliver power is the tube itself.
	_check(sim.power_at(Vector2i(10, 9)) == 0.0, "the up-leg carries no power (U delivers as L)")
	_check(sim.power_at(Vector2i(10, 8)) == 0.0, "no power climbs the up-leg (never flows up)")
	# place / remove API: a carried conduit item moves both ways between the pack and the layer.
	var s2: FactorySim = FactorySim.new()
	s2.inventory[&"conduit"] = 2
	s2.total_produced[&"conduit"] = 2      # seed the ledger too, so the conservation assert below is honest
	_check(s2.place_conduit(Vector2i(3, 3)), "place a carried conduit into an open cell")
	_check(s2.has_conduit(Vector2i(3, 3)), "the cell now holds a conduit")
	_check(int(s2.inventory.get(&"conduit", 0)) == 1, "placing spent one conduit from the pack")
	s2.set_solid(Vector2i(4, 3), &"earth")
	_check(not s2.place_conduit(Vector2i(4, 3)), "cannot run a conduit through solid rock")
	_check(s2.remove_conduit(Vector2i(3, 3)), "pick the conduit back up")
	_check(not s2.has_conduit(Vector2i(3, 3)) and int(s2.inventory.get(&"conduit", 0)) == 2, "it returned to the pack")
	# Symmetric placed-layer accounting: place counts as consumed, remove as produced, so present == net
	# holds with conduits mid-placed too. A placed layer that skips the ledger breaks conservation.
	s2.place_conduit(Vector2i(3, 3))
	var present_c: int = _items_present(s2, &"conduit")
	var net_c: int = int(s2.total_produced.get(&"conduit", 0)) - int(s2.total_consumed.get(&"conduit", 0))
	_check(present_c == net_c, "conduit conserved with one placed (present=%d, net=%d)" % [present_c, net_c])


## Power governs the lift. Unpowered it runs at LIFT_THROUGHPUT, which _test_lift proves; with a
## generator beside it pouring power into its cell it carries up to LIFT_POWERED_THROUGHPUT, with
## power_throttle routing the boost. Fighting gravity upward is the canonical "costs power" case.
func _test_powered_lift() -> void:
	print("- powered lift")
	var lift_def: MachineDef = load("res://src/data/machines/lift.tres")
	var gen_def: MachineDef = load("res://src/data/machines/generator.tres")
	var sim: FactorySim = FactorySim.new()
	var lift: MachineState = sim.place_machine(lift_def, Vector2i(5, 10))
	var g: MachineState = sim.place_machine(gen_def, Vector2i(4, 10))   # beside the lift; aura covers it
	g.input_buffer[&"coal"] = 9
	sim.total_produced[&"coal"] = 9
	for _i: int in 3:
		sim.tick()                                                     # warm the generator so power flows
	_check(sim.power_at(lift.cell) > 0.0, "power reaches the lift's cell")
	_check(lift.power_factor > 0.0, "the lift registers a power boost (factor=%.2f)" % lift.power_factor)
	# One powered tick: it should carry more than the unpowered baseline.
	lift.input_buffer[&"ore"] = 12
	sim.total_produced[&"ore"] = 12
	sim.tick()
	var carried: int = 12 - int(lift.input_buffer.get(&"ore", 0))
	_check(carried > FactorySim.LIFT_THROUGHPUT,
		"a powered lift beats the unpowered baseline (%d > %d)" % [carried, FactorySim.LIFT_THROUGHPUT])
	_check(carried == FactorySim.LIFT_POWERED_THROUGHPUT,
		"fully powered → full throughput (%d)" % carried)
	var present: int = _items_present(sim, &"ore")
	_check(present == int(sim.total_produced.get(&"ore", 0)), "ore conserved through the powered lift (present=%d)" % present)


## The pump is the powered flood-drain, and the L3 aquifer's answer. It sits on the locked hook: water
## floods down for free, and pumping it back out costs power. That is what these checks prove. A powered
## pump drains a flooded pocket substantially; an identical unpowered pump barely touches it. The drain
## is also bounded and sane: no water is ever created and no cell goes negative.
func _test_pump() -> void:
	print("- pump (powered flood-drain, L3)")
	var pump_def: MachineDef = load("res://src/data/machines/pump.tres")
	var gen_def: MachineDef = load("res://src/data/machines/generator.tres")

	# Build one flooded, SEALED pocket: a walled 1-wide shaft (x=col) with a floor, brim-full of water.
	# Returns the sim plus the top-of-pocket cell the pump sits in. Sealing it is what makes any drop in
	# total_water attributable to the pump alone.
	var build_pocket := func(col: int) -> Dictionary:
		var s: FactorySim = FactorySim.new()
		for row: int in range(3, 8):
			s.set_solid(Vector2i(col - 1, row), &"stone")     # left wall
			s.set_solid(Vector2i(col + 1, row), &"stone")     # right wall
		s.set_solid(Vector2i(col, 7), &"stone")               # floor
		var poured: int = 0
		for row: int in range(3, 7):                          # fill rows 3..6 (4 open cells) to the brim
			poured += s.add_water(Vector2i(col, row), FactorySim.WATER_MAX)
		return {"sim": s, "top": Vector2i(col, 3), "poured": poured}

	# --- Powered: a fueled generator beside the pump pours power into its cell, and it drains. ---
	var pd: Dictionary = build_pocket.call(6)
	var sim: FactorySim = pd["sim"]
	var top: Vector2i = pd["top"]
	var flooded: int = int(pd["poured"])
	_check(flooded == FactorySim.WATER_MAX * 4 and flooded > 0, "the pocket starts brim-full (%d units)" % flooded)
	sim.place_machine(pump_def, top)                          # the pump in the top of the flooded pocket
	# Generator two cells left of the pocket wall (its aura reaches the pump's cell), fueled with coal.
	var g: MachineState = sim.place_machine(gen_def, top + Vector2i(-2, 0))
	g.input_buffer[&"coal"] = 40
	sim.total_produced[&"coal"] = 40
	for _i: int in 3:
		sim.tick()                                            # warm the generator so power flows
	_check(sim.power_at(top) > 0.0, "power reaches the pump's cell")
	var before: int = sim.total_water()                       # after warm-up (the pump already drained a little)
	_check(before > 0, "water still present after warm-up (%d units)" % before)
	# 30 ticks is enough for the powered pump to take the pocket down to a quarter of `before` or less.
	var negative_seen: bool = false
	for _i: int in 30:
		sim.tick()
		for cv: Variant in sim.water:                         # integer + clamped: no cell ever goes negative
			if int(sim.water[cv]) < 0:
				negative_seen = true
	var after: int = sim.total_water()
	_check(after < before, "a POWERED pump drains water out of the pocket (%d -> %d)" % [before, after])
	_check(after <= before / 4, "the powered pump drains the pocket substantially (%d << %d)" % [after, before])
	_check(not negative_seen, "no cell ever holds a negative water level")

	# --- Unpowered: an identical flooded pocket, a pump with NO generator. It must move nothing. ---
	var upd: Dictionary = build_pocket.call(16)
	var usim: FactorySim = upd["sim"]
	var utop: Vector2i = upd["top"]
	var uflooded: int = int(upd["poured"])
	usim.place_machine(pump_def, utop)                        # a pump, but no power anywhere
	var ubefore: int = usim.total_water()
	for _i: int in 30:
		usim.tick()
		_check(usim.power_at(utop) == 0.0, "no power reaches the unpowered pump")
	var uafter: int = usim.total_water()
	_check(uafter == ubefore, "an UNPOWERED pump drains nothing (%d -> %d) — the on-hook cost rule" % [ubefore, uafter])

	# --- Sanity: the pump never CREATES water. Both pockets' totals only ever fell. ---
	_check(after <= before and uafter <= ubefore, "the pump only ever removes water, never adds it")
	# machine_status mirrors the runner: powered and wet reads working, unpowered reads idle.
	var s3: Dictionary = build_pocket.call(26)
	var wsim: FactorySim = s3["sim"]
	var wtop: Vector2i = s3["top"]
	var wpump: MachineState = wsim.place_machine(pump_def, wtop)
	_check(wsim.machine_status(wpump) == &"idle", "an unpowered pump reads idle (no power)")
	var wg: MachineState = wsim.place_machine(gen_def, wtop + Vector2i(-2, 0))
	wg.input_buffer[&"coal"] = 20
	wsim.total_produced[&"coal"] = 20
	for _i: int in 3:
		wsim.tick()
	_check(wsim.machine_status(wpump) == &"working", "a powered pump over water reads working")


## Water is the L3 aquifer's discrete-cell integer fluid. Five deterministic sim-level claims: it FALLS
## on the hook (down for free), SETTLES to a flat top, never enters or coexists with solid rock,
## conserves its total across ticks, and two identically-built sims flow byte-identically. Sim only;
## there is no render layer to test here.
func _test_water_fluid() -> void:
	print("- water (L3 fluid primitive)")

	# Helpers scoped to this test.
	var no_water_in_solid := func(s: FactorySim) -> bool:
		for cv: Variant in s.water:
			if s.solid.has(cv as Vector2i):
				return false
		return true

	# --- 1. Gravity: pour at the top of a walled open shaft; it all ends at the bottom. ---
	# Column x=5, open rows 1..8, capped by a solid floor at row 9; solid walls left/right of the shaft.
	var g: FactorySim = FactorySim.new()
	for row: int in range(1, 10):
		g.set_solid(Vector2i(4, row), &"stone")               # left wall
		g.set_solid(Vector2i(6, row), &"stone")               # right wall
	g.set_solid(Vector2i(5, 9), &"stone")                     # floor at the bottom of the shaft
	var poured_g: int = g.add_water(Vector2i(5, 1), 6)        # pour 6 units at the top
	_check(poured_g == 6, "add_water returns the amount it actually placed")
	_check(g.total_water() == 6, "the poured water is all present")
	for _i: int in 40:
		g.tick()
		_check(no_water_in_solid.call(g), "water never occupies a solid cell (gravity run)")
	_check(g.water_at(Vector2i(5, 1)) == 0, "the top of the shaft drained")
	_check(g.water_at(Vector2i(5, 8)) == 6, "all 6 units settled at the bottom of the shaft")
	_check(g.total_water() == 6, "gravity run conserved total (6)")

	# --- 2. Settle flat: pour a blob into a wide walled basin; the surface flattens. ---
	# Basin: solid floor at row 6 across x=1..5, walls at x=0 and x=6, open above.
	var b: FactorySim = FactorySim.new()
	for x: int in range(1, 6):
		b.set_solid(Vector2i(x, 6), &"stone")                 # floor
	for row: int in range(1, 6):
		b.set_solid(Vector2i(0, row), &"stone")               # left wall
		b.set_solid(Vector2i(6, row), &"stone")               # right wall
	var poured_b: int = 0
	poured_b += b.add_water(Vector2i(3, 1), 8)                # a tall blob dumped into one column
	poured_b += b.add_water(Vector2i(3, 2), 7)
	_check(poured_b == 15, "poured 15 units into the basin")
	for _i: int in 80:
		b.tick()
		_check(no_water_in_solid.call(b), "water never occupies a solid cell (basin run)")
	_check(b.total_water() == 15, "basin conserved total (15)")
	# Flat means: on the row directly on the floor, at least 4 cells are wet and their levels span 1 unit.
	var lo: int = 999
	var hi: int = -999
	var floor_wet: int = 0
	for x: int in range(1, 6):
		var lvl: int = b.water_at(Vector2i(x, 5))             # the row directly on the floor
		if lvl > 0:
			floor_wet += 1
			lo = mini(lo, lvl)
			hi = maxi(hi, lvl)
	_check(floor_wet >= 4 and hi - lo <= 1, "the pool settled to a flat top (wet=%d, spread=%d)" % [floor_wet, hi - lo])

	# --- 3. Blocked by solid: placing rock into a watered cell clears that cell's water. ---
	var d: FactorySim = FactorySim.new()
	d.add_water(Vector2i(3, 3), 5)                            # a lone puddle, walled so it can't move
	for dxy: Vector2i in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		d.set_solid(Vector2i(3, 3) + dxy, &"stone")           # floor + both walls trap it in place
	_check(d.water_at(Vector2i(3, 3)) == 5 and d.total_water() == 5, "puddle trapped, 5 units present")
	var before_disp: int = d.total_water()
	d.set_solid(Vector2i(3, 3), &"stone")                     # rock over the watered cell displaces it
	_check(d.water_at(Vector2i(3, 3)) == 0, "set_solid onto a watered cell clears its water")
	_check(d.total_water() == before_disp - 5, "total dropped by exactly the displaced cell's level (5)")
	# The mirror path: placing a carried block into a watered cell displaces the water too.
	var d2: FactorySim = FactorySim.new()
	d2.add_water(Vector2i(2, 2), 4)
	d2.inventory[&"stone"] = 1; d2.total_produced[&"stone"] = 1
	d2.set_solid(Vector2i(2, 3), &"stone")                    # a floor to build off (block_supported)
	_check(d2.place_block(Vector2i(2, 2), &"stone"), "place_block lands on the watered cell")
	_check(d2.water_at(Vector2i(2, 2)) == 0, "place_block onto a watered cell displaces its water too")

	# --- 4. Conservation across many ticks with no source or drain. ---
	var c: FactorySim = FactorySim.new()
	for row: int in range(1, 12):
		c.set_solid(Vector2i(2, row), &"stone")
		c.set_solid(Vector2i(8, row), &"stone")
	for x: int in range(3, 8):
		c.set_solid(Vector2i(x, 11), &"stone")                # a wide floor
	var total0: int = 0
	total0 += c.add_water(Vector2i(4, 1), 8)
	total0 += c.add_water(Vector2i(6, 1), 8)
	total0 += c.add_water(Vector2i(5, 2), 5)
	var invariant: bool = true
	for _i: int in 120:
		c.tick()
		if c.total_water() != total0:
			invariant = false
	_check(invariant and c.total_water() == total0,
		"total_water() invariant across 120 ticks (no source/drain, expect %d)" % total0)

	# --- 5. Determinism: two identically-built, identically-poured sims tick to identical water. ---
	var build_and_pour := func() -> FactorySim:
		var s: FactorySim = FactorySim.new()
		for row: int in range(1, 10):
			s.set_solid(Vector2i(1, row), &"stone")
			s.set_solid(Vector2i(7, row), &"stone")
		for x: int in range(2, 7):
			s.set_solid(Vector2i(x, 9), &"stone")
		s.add_water(Vector2i(3, 1), 7)
		s.add_water(Vector2i(5, 2), 6)
		s.add_water(Vector2i(4, 1), 3)
		return s
	var sa: FactorySim = build_and_pour.call()
	var sb: FactorySim = build_and_pour.call()
	for _i: int in 60:
		sa.tick()
		sb.tick()
	_check(sa.total_water() == sb.total_water(), "two identical water sims agree on total after 60 ticks")
	_check(sa.water == sb.water, "…and on the exact water dict")
	_check(_state_signature(sa) == _state_signature(sb), "…and on the whole state signature (water rides it)")
