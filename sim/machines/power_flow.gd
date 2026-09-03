class_name PowerFlow
extends RefCounted

## Per-tick power propagation: rebuilds the power field from the fueled generators and the conduit
## network. Stateless. Derived and recomputed from scratch each tick, so it cannot desync from placement
## or fuel. Deterministic: top-to-bottom pass, fixed L->R then R->L tie-break.
##
## Lifted in A' step 3d (D0349) from `legacy/src/core/power_flow.gd` (89 lines) with plan §5.2's eight
## rows fixed: the all-float field is MILLI-UNITS (legacy 6.0 -> 6000), the keep and bleed fractions are
## percentages, and every number is a field of the generator's or the conduit's record
## (`data/machines`) rather than a `const` on the hub. The field is keyed by `logic_cell`.

## Rebuild the field: every fueled generator stamps its aura, then power floods the conduit network.
static func compute(world: World, machines: Machines) -> Dictionary:
	var power: Dictionary = {}
	for machine: MachineState in machines.machines:
		if Runners.behavior_flag(machine.def, &"power_source") and machine.fuel > 0:
			_emit_aura(world, power, machine.logic_cell, machine.def.power_milli, machine.def.aura)
	var conduits: Array[Vector2i] = world.logic.placed_logic_cells(LogicGrid.KIND_CONDUIT)
	if not conduits.is_empty():
		_flow_through_conduits(world, machines, power, conduits)
	return power


## Stamp a generator's innate aura: an attenuating diamond (manhattan radius `aura`) around `origin`
## that fades to 0 at the rim. Overlapping auras take the maximum rather than the sum.
static func _emit_aura(world: World, power: Dictionary, origin: Vector2i, amount_milli: int, aura: int) -> void:
	for dy: int in range(-aura, aura + 1):
		for dx: int in range(-aura, aura + 1):
			var dist: int = absi(dx) + absi(dy)
			if dist > aura:
				continue
			var cell: Vector2i = origin + Vector2i(dx, dy)
			if not world.logic_in_bounds(cell):
				continue
			var v: int = amount_milli * (aura + 1 - dist) / (aura + 1)   # legacy: amount * (1 - dist / (aura + 1))
			power[cell] = maxi(int(power.get(cell, 0)), v)


## Flood power through the conduit network in one top-to-bottom pass. Power flows down and laterally
## but never up, so the network is acyclic by row and needs no iterative solver. Per row the vertical
## inflow is the sum of the feeders above clamped to the tube's capacity, which also bounds branch
## amplification; horizontal spread is a lossy maximum delivered both ways along the row, L->R then
## R->L as the tie-break that stops two adjacent tubes forming a same-row loop. Each conduit cell then
## writes into the field and bleeds to its neighbours so adjacent machines draw.
static func _flow_through_conduits(world: World, machines: Machines, power: Dictionary, conduits: Array[Vector2i]) -> void:
	var tube: MachineDef = MachineDef.of(&"conduit")
	var carried: Dictionary = {}                        # conduit cell -> milli-power it carries this tick
	var by_row: Dictionary = {}                         # y -> Array[int] of conduit x's in that row
	for c: Vector2i in conduits:                        # already in scan order: rows ascend, x ascends within
		if not by_row.has(c.y):
			by_row[c.y] = ([] as Array[int])
		(by_row[c.y] as Array[int]).append(c.x)
	var rows: Array = by_row.keys()
	rows.sort()                                         # ints: a plain sort is lexical here
	for y: int in rows:
		var xs: Array[int] = by_row[y]
		for x: int in xs:
			var vin: int = 0
			for dx: int in [-1, 0, 1]:
				vin += _power_out_of(world, machines, Vector2i(x + dx, y - 1), carried) * tube.v_keep_pct / 100
			carried[Vector2i(x, y)] = mini(vin, tube.capacity_milli)
		for i: int in range(1, xs.size()):
			if xs[i] == xs[i - 1] + 1:
				var cell := Vector2i(xs[i], y)
				carried[cell] = maxi(int(carried.get(cell, 0)), int(carried[Vector2i(xs[i - 1], y)]) * tube.h_keep_pct / 100)
		for i: int in range(xs.size() - 2, -1, -1):
			if xs[i] == xs[i + 1] - 1:
				var cell := Vector2i(xs[i], y)
				carried[cell] = maxi(int(carried.get(cell, 0)), int(carried[Vector2i(xs[i + 1], y)]) * tube.h_keep_pct / 100)
	for cell: Vector2i in conduits:
		var v: int = int(carried.get(cell, 0))
		if v <= 0:
			continue          # a tube carrying nothing adds no field entry (consumers read keys as "lit")
		power[cell] = maxi(int(power.get(cell, 0)), v)
		for nb: Vector2i in World.ORTHO:
			var n: Vector2i = cell + nb
			if world.logic_in_bounds(n):
				power[n] = maxi(int(power.get(n, 0)), v * tube.bleed_pct / 100)


## Power a cell feeds down into the conduit below it: a fueled generator pours its full output, a
## conduit passes what it carries, anything else nothing. Read during the top-down pass, so a feeder is
## final.
static func _power_out_of(world: World, machines: Machines, cell: Vector2i, carried: Dictionary) -> int:
	if world.logic.has_conduit(cell):
		return int(carried.get(cell, 0))
	var m: MachineState = machines.machine_at(cell)
	if m != null and Runners.behavior_flag(m.def, &"power_source") and m.fuel > 0:
		return m.def.power_milli
	return 0
