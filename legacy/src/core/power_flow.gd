extends RefCounted

## Per-tick power propagation: clears and refills the sim's `power` field from the fueled generators and the
## conduit network. Stateless. Derived and recomputed from scratch each tick, so it cannot desync from
## placement or fuel. Deterministic: top-to-bottom pass, fixed L->R then R->L tie-break.

## Rebuild the power field: every fueled generator stamps its aura, then power floods the conduit network.
static func compute(sim: FactorySim) -> void:
	sim.power.clear()
	for machine: MachineState in sim.machines:
		if sim._behavior_flag(machine.def, &"power_source") and machine.fuel > 0:
			_emit_aura(sim, machine.cell, FactorySim.GENERATOR_POWER)
	if not sim.conduit.is_empty():
		_flow_through_conduits(sim)


## Stamp a generator's innate aura: an attenuating diamond (manhattan radius POWER_AURA) around `origin`
## that fades to 0 at the rim. Overlapping auras take the maximum rather than the sum.
static func _emit_aura(sim: FactorySim, origin: Vector2i, amount: float) -> void:
	for dy: int in range(-FactorySim.POWER_AURA, FactorySim.POWER_AURA + 1):
		for dx: int in range(-FactorySim.POWER_AURA, FactorySim.POWER_AURA + 1):
			var dist: int = absi(dx) + absi(dy)
			if dist > FactorySim.POWER_AURA:
				continue
			var cell: Vector2i = origin + Vector2i(dx, dy)
			if not sim.in_bounds(cell):
				continue
			var v: float = amount * (1.0 - float(dist) / float(FactorySim.POWER_AURA + 1))
			sim.power[cell] = maxf(float(sim.power.get(cell, 0.0)), v)


## Flood power through the conduit network in one top-to-bottom pass. Power flows down and laterally but
## never up, so the network is acyclic by row and needs no iterative solver. Per row the vertical inflow is
## the sum of the feeders above clamped to CONDUIT_CAPACITY, which also bounds branch amplification, while
## horizontal spread is a lossy maximum delivered both ways along the row, where the L->R then R->L order
## is the tie-break that stops two adjacent tubes forming a same-row loop. Each conduit cell then writes
## into the field and bleeds to its neighbours so adjacent machines draw.
static func _flow_through_conduits(sim: FactorySim) -> void:
	var carried: Dictionary = {}                       # conduit cell -> power it carries this tick
	# Touch only actual conduit cells, grouped by row, so a sparse network costs O(conduits), not O(grid).
	var by_row: Dictionary = {}                         # y -> Array[int] of conduit x's in that row
	for cell: Variant in sim.conduit:
		var c: Vector2i = cell
		if not by_row.has(c.y):
			by_row[c.y] = ([] as Array[int])
		(by_row[c.y] as Array[int]).append(c.x)
	var rows: Array = by_row.keys()
	rows.sort()                                         # top→bottom: each row finalized before the next reads it
	for y: int in rows:
		var xs: Array[int] = by_row[y]
		xs.sort()
		# (1) vertical inflow from the row above (additive merge, capacity-clamped).
		for x: int in xs:
			var vin: float = 0.0
			for dx: int in [-1, 0, 1]:
				vin += _power_out_of(sim, Vector2i(x + dx, y - 1), carried) * FactorySim.CONDUIT_V_KEEP
			carried[Vector2i(x, y)] = minf(vin, FactorySim.CONDUIT_CAPACITY)
		# (2) horizontal spread within the row: L→R then R→L lossy maximum (the same-row tie-break), only
		# transferring between conduits that are actually adjacent in this row.
		for i: int in range(1, xs.size()):
			if xs[i] == xs[i - 1] + 1:
				var cell := Vector2i(xs[i], y)
				carried[cell] = maxf(float(carried.get(cell, 0.0)), float(carried[Vector2i(xs[i - 1], y)]) * FactorySim.CONDUIT_H_KEEP)
		for i: int in range(xs.size() - 2, -1, -1):
			if xs[i] == xs[i + 1] - 1:
				var cell := Vector2i(xs[i], y)
				carried[cell] = maxf(float(carried.get(cell, 0.0)), float(carried[Vector2i(xs[i + 1], y)]) * FactorySim.CONDUIT_H_KEEP)
	# Merge the carried power into the field, and bleed it to neighbours so a machine beside a tube draws.
	for cell: Vector2i in carried:
		var v: float = float(carried[cell])
		if v <= 0.0:
			continue          # a tube carrying no power adds no field entry, or consumers that read
			                  # power.keys() as "lit" (minimap frontier-reach) wash an unpowered run powered
		sim.power[cell] = maxf(float(sim.power.get(cell, 0.0)), v)
		for nb: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + nb
			if sim.in_bounds(n):
				sim.power[n] = maxf(float(sim.power.get(n, 0.0)), v * FactorySim.CONDUIT_BLEED)


## Power a cell feeds down into the conduit below it: a fueled generator pours its full output, a conduit
## passes what it carries, anything else nothing. Read during the top-down pass, so a feeder is final.
static func _power_out_of(sim: FactorySim, cell: Vector2i, carried: Dictionary) -> float:
	if sim.conduit.has(cell):
		return float(carried.get(cell, 0.0))
	var m: MachineState = sim.grid.get(cell, null)
	if m != null and sim._behavior_flag(m.def, &"power_source") and m.fuel > 0:
		return FactorySim.GENERATOR_POWER
	return 0.0
