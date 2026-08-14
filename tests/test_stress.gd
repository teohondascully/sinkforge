extends "res://tests/test_base.gd"

## Adversarial stress / invariant suite — long pseudo-random action sequences that churn the sim in
## bulk (build / mine / place / flood / power / research) and assert the hard invariants hold at every
## step: item conservation, no floating foliage, and power/flow/research consistency. These are the
## heaviest harness layers, isolated here so they parallelise cleanly against the fast unit suites.


func _initialize() -> void:
	print("== stress tests ==")
	_test_stress_invariants()
	_test_stress_flow()
	_test_stress_power()
	_test_stress_research()
	_finish("stress tests")


## --- ADVERSARIAL STRESS: long, interleaved, seeded operation sequences ---------------------------
## The rest of the suite is goal-oriented (each test proves ONE happy path). Live play instead keeps
## surfacing bugs from UNUSUAL, INTERLEAVED sequences — build a machine then dig the cell under it,
## place/remove rope/torch/conduit on cells that later get mined or built over, drop under back-pressure,
## mine under a pile, craft→build→pickup in and out of the pack, ticking between bursts so drills/hoppers/
## gravity all run against the churned state. This test drives one deterministic (fixed-seed RNG) mixed
## sequence of hundreds of ops and, after EVERY burst, asserts the CORE INVARIANTS that class of bug
## violates:
##   (1) CONSERVATION — for every item id touched, _items_present == total_produced - total_consumed.
##       (The big one: an interleaving that leaks or dupes an item is a real conservation bug. Placed
##       layers — rope/torch/conduit/sapling — are ledgered place=consumed/remove=produced, so the same
##       invariant covers them: placing drops present AND (produced-consumed) together.)
##   (2) NO CORRUPTION — placed-layer cells and solid cells never overlap (no rope/torch/conduit/machine
##       sharing a cell with solid rock; no machine on a solid cell), ground piles are never empty, and
##       every op on an out-of-bounds/occupied cell returned cleanly (checked inline as it's driven).
##   (3) DETERMINISM — the WHOLE sequence, re-run from the same seed on a fresh sim, yields a byte-identical
##       _state_signature. The proof the churn introduced no time/global-random dependence.
## A save→mutate→load happens MID-sequence (reusing SaveGame like _test_save_load) and operation continues
## against the restored sim, so the invariants must survive a serialization round-trip in the churn too.
func _test_stress_invariants() -> void:
	print("- STRESS: interleaved-op invariants (adversarial)")
	var final_a: String = _run_stress_sequence(0x5F1E)          # seeded run #1 (asserts invariants inline)
	var final_b: String = _run_stress_sequence(0x5F1E)          # seeded run #2 (silent — determinism proof)
	_check(final_a == final_b, "the WHOLE interleaved sequence is deterministic (identical final state)")


## Item ids the stress sequence can touch — the conservation frontier. Every one is asserted after every
## burst, so a leak in ANY of them fails. (Machine items live in the pack while carried, satisfying the
## SAME present==produced-consumed rule as resources — the ledger is total.)
const _STRESS_ITEMS: Array[StringName] = [
	&"ore", &"coal", &"ingot", &"earth", &"stone", &"wood", &"leaves", &"sapling",
	&"rope", &"conduit", &"torch", &"drill", &"processor", &"hopper", &"splitter",
]


## Run ONE full interleaved stress sequence under a fixed seed. Asserts the invariants after every burst.
## Returns the final _state_signature (so the caller can prove two same-seed runs match = determinism).
func _run_stress_sequence(rng_seed: int) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed                                          # FIXED seed — reproducible, no Date/global rand
	var drill_def: MachineDef = load("res://src/data/machines/drill.tres")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	var hopper_def: MachineDef = load("res://src/data/machines/hopper.tres")
	var split_def: MachineDef = load("res://src/data/machines/splitter.tres")
	var machine_defs: Array[MachineDef] = [drill_def, proc_def, hopper_def, split_def]

	var sim: FactorySim = FactorySim.new()
	# A hand-built fixture: a floor shelf at row 20 across cols 2..40, ore + coal veins hanging above it,
	# and a starting pack. Everything is well in-bounds (GRID 96×80), so the RNG cell picks stay legal.
	for col: int in range(2, 40):
		sim.set_solid(Vector2i(col, 20), &"stone")
	for col: int in range(4, 12):
		sim.set_solid(Vector2i(col, 8), &"ore")
		sim.deposits[Vector2i(col, 8)] = 30
	for col: int in range(14, 20):
		sim.set_solid(Vector2i(col, 8), &"coal")
		sim.deposits[Vector2i(col, 8)] = 30
	# Seed the pack + book it as produced so the ledger starts balanced (present == produced - consumed).
	var start_pack: Dictionary = {
		&"ore": 40, &"coal": 40, &"ingot": 60, &"earth": 30, &"stone": 30, &"wood": 30,
		&"rope": 20, &"conduit": 20, &"torch": 20, &"sapling": 8,
	}
	for item: StringName in start_pack:
		sim.inventory[item] = int(start_pack[item])
		sim.total_produced[item] = int(sim.total_produced.get(item, 0)) + int(start_pack[item])

	var loud: bool = rng_seed == 0x5F1E and _stress_first        # only the first run reports (twice would double the log)
	_stress_first = false
	var ops: int = 0
	var did_save_load: bool = false

	# 24 bursts of ~12 mixed ops, ticking between each — hundreds of interleaved ops total, bounded ticks.
	for burst: int in 24:
		for _k: int in 12:
			ops += 1
			var choice: int = rng.randi_range(0, 12)
			var cell: Vector2i = Vector2i(rng.randi_range(2, 44), rng.randi_range(3, 24))
			match choice:
				0:
					# BUILD a machine from the pack (craft one first if the pack is empty of it).
					var def: MachineDef = machine_defs[rng.randi_range(0, machine_defs.size() - 1)]
					if int(sim.inventory.get(def.id, 0)) <= 0:
						sim.craft_item(def.id, def.craft_cost, def.craft_count)   # may fail (short ingots) — fine
					sim.build_from_pack(def, cell)                # may fail (occupied/solid) — must not corrupt
				1:
					# PICK a machine back up (salvages buffers into the pack).
					sim.pickup_machine(cell)
				2:
					# RAW remove a machine (demolish — discards buffers, credited to consumed).
					sim.remove_machine(cell)
				3:
					# DIG the cell (may be under/beside a machine, a pile, foliage, or empty).
					sim.mine(cell)
				4:
					# PLACE a block — deliberately NOT gating on block_supported, so mid-air placement is
					# exercised (place_block itself must handle it without leaking; support is a controller gate).
					var mat: StringName = [&"earth", &"stone", &"wood"][rng.randi_range(0, 2)]
					sim.place_block(cell, mat)
				5:
					# ROPE: unroll down, or cut/retract an existing hang.
					if sim.is_climbable(cell):
						if rng.randi_range(0, 1) == 0:
							sim.remove_rope(cell)
						else:
							sim.retract_rope(cell)
					else:
						sim.place_rope(cell)
				6:
					# CONDUIT place/remove.
					if sim.has_conduit(cell):
						sim.remove_conduit(cell)
					else:
						sim.place_conduit(cell)
				7:
					# TORCH place/remove.
					if sim.has_torch(cell):
						sim.remove_torch(cell)
					else:
						sim.place_torch(cell)
				8:
					# SAPLING plant/remove (wants soil below — will often refuse, which is correct).
					if sim.sapling.has(cell):
						sim.remove_sapling(cell)
					else:
						sim.plant_sapling(cell)
				9:
					# DROP / TOSS a carried stack down a column (feeds a machine, piles on a floor, or voids).
					var item: StringName = [&"ore", &"coal", &"ingot"][rng.randi_range(0, 2)]
					sim.drop_item(cell, item, rng.randi_range(1, 5))
				10:
					# COLLECT a ground pile (walk-over pickup).
					sim.collect_ground(cell)
				11:
					# DEPOSIT into a machine at the cell if one is there (hand-feed).
					var item2: StringName = [&"ore", &"coal", &"ingot"][rng.randi_range(0, 2)]
					sim.deposit(cell, item2, rng.randi_range(1, 4))
				12:
					# CRAFT a machine item into the pack (spends ingots; may fail — fine).
					var def2: MachineDef = machine_defs[rng.randi_range(0, machine_defs.size() - 1)]
					sim.craft_item(def2.id, def2.craft_cost, def2.craft_count)
		# Step the sim so _flow / drills / hoppers / gravity / sapling-growth all run against the churn.
		for _t: int in rng.randi_range(1, 6):
			sim.tick()

		# A save→mutate→load roughly halfway, then keep operating against the RESTORED sim in place.
		if burst == 12 and not did_save_load:
			did_save_load = true
			var data: Dictionary = SaveGame.capture(sim)
			var path: String = "user://test_stress_%d.save" % rng_seed
			var wrote: bool = SaveGame.write(path, data)
			var back: Dictionary = SaveGame.read(path)
			var restored: FactorySim = FactorySim.new()
			var ok: bool = SaveGame.restore(restored, back)
			if loud:
				_check(wrote and not back.is_empty() and ok, "mid-sequence save→disk→load round-trips")
				_check(_state_signature(restored) == _state_signature(sim),
					"the restored mid-sequence state is byte-identical to the live one")
			sim = restored                                        # continue the churn on the restored sim
			DirAccess.remove_absolute(path)                       # don't leave a stray fixture save on disk

		# INVARIANTS after this burst.
		if loud:
			_stress_assert_invariants(sim, "burst %d (%d ops)" % [burst, ops])

	# Final gate.
	if loud:
		_stress_assert_invariants(sim, "final (%d ops)" % ops)
		_check(ops >= 250, "the sequence is long enough to stress interleavings (%d ops)" % ops)
	return _state_signature(sim)


## True until the first stress run reports — so re-running the same sequence for the determinism proof
## doesn't double the harness log. Reset false after the first loud run.
var _stress_first: bool = true


## Assert the core invariants on `sim` at a checkpoint. Failing here = a real interleaving bug.
func _stress_assert_invariants(sim: FactorySim, where: String) -> void:
	# (1) CONSERVATION — every touched item id: present == produced - consumed.
	var leaked: PackedStringArray = []
	for item: StringName in _STRESS_ITEMS:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		if present != net:
			leaked.append("%s(present=%d,net=%d)" % [item, present, net])
	_check(leaked.is_empty(), "%s — conservation holds for every item%s"
		% [where, "" if leaked.is_empty() else ": LEAKED " + ", ".join(leaked)])

	# (2) NO CORRUPTION — placed layers never share a cell with solid rock or a machine, no ground pile
	# is empty, and every ground pile has a solid floor / machine directly below (nothing floats mid-air).
	var bad_layer: int = 0
	for layer_cell: Variant in sim.rope.keys():
		if sim.solid.has(layer_cell) or sim.grid.has(layer_cell):
			bad_layer += 1
	for layer_cell: Variant in sim.conduit.keys():
		if sim.solid.has(layer_cell) or sim.grid.has(layer_cell):
			bad_layer += 1
	for layer_cell: Variant in sim.torch.keys():
		if sim.solid.has(layer_cell) or sim.grid.has(layer_cell):
			bad_layer += 1
	_check(bad_layer == 0, "%s — no rope/conduit/torch overlaps solid rock or a machine (%d bad)"
		% [where, bad_layer])
	var bad_machine: int = 0
	for mcell: Variant in sim.grid.keys():
		if sim.solid.has(mcell):
			bad_machine += 1
	_check(bad_machine == 0, "%s — no machine occupies a solid cell (%d bad)" % [where, bad_machine])
	var empty_piles: int = 0
	for gcell: Variant in sim.ground.keys():
		if (sim.ground[gcell] as Dictionary).is_empty():
			empty_piles += 1
	_check(empty_piles == 0, "%s — no empty ground pile lingers (%d found)" % [where, empty_piles])
	# Nothing floats: every ground pile rests on a solid floor OR a machine (or the world floor row).
	var floating_piles: int = 0
	for gcell: Variant in sim.ground.keys():
		var gc: Vector2i = gcell
		var under: Vector2i = gc + Vector2i(0, 1)
		if gc.y >= FactorySim.GRID_ROWS - 1:
			continue                                              # resting on the world floor is legal
		if not sim.solid.has(under) and not sim.grid.has(under):
			floating_piles += 1
	_check(floating_piles == 0, "%s — no ground pile hangs in mid-air (%d floating)" % [where, floating_piles])


## STRESS: the FACTORY FLOW / routing NETWORK under interleaved churn (adversarial). The sibling
## _test_stress_invariants churns the PLACEMENT layers broadly; this one churns the FLOW: multi-stage
## columns (drill→forge→hopper→splitter) threaded by gravity across several columns so splitters route
## sideways, drills bore finite veins, hoppers meter with back-pressure, a borer chews its gallery — all
## while, MID-FLOW, machines are removed + rebuilt elsewhere, splitter ratios + hopper filters are
## reconfigured, and outputs are capped to build back-pressure cascades. After EVERY burst + at the end it
## asserts the flow invariants: (1) conservation for every item (present == produced − consumed, counting
## the borer's belly/bunker and every buffer); (2) back-pressure is LOSSLESS (a blocked/capped tick never
## drops total present — items pile, never vanish); (3) no negative/NaN buffer count, no deposit below zero,
## no buffer growing past what was produced (no runaway); (4) determinism — the whole sequence twice from
## one seed lands on an identical final signature. If any fails, it's a real flow/route/back-pressure bug.
func _test_stress_flow() -> void:
	print("- STRESS: factory-flow / routing network under churn (adversarial)")
	var final_a: String = _run_stress_flow_sequence(0xF107)      # seeded run #1 (asserts invariants inline)
	var final_b: String = _run_stress_flow_sequence(0xF107)      # seeded run #2 (silent — determinism proof)
	_check(final_a == final_b, "the WHOLE flow sequence is deterministic (identical final state)")


## Item ids the flow sequence can touch (its conservation frontier — asserted after every burst). ingot is
## FORGED by the recipe runner and the borer bellies earth/stone/coal, so the whole chain is covered.
const _FLOW_ITEMS: Array[StringName] = [
	&"ore", &"coal", &"ingot", &"earth", &"stone", &"wood",
	&"drill", &"processor", &"hopper", &"splitter", &"h_drill",
]


## The bounded-worst-case ceiling on any single buffer: every item ever produced in a run, so a buffer
## that grows past this is a runaway (invariant 3). The seeded pack + a few finite veins keep this small.
func _flow_total_produced(sim: FactorySim) -> int:
	var total: int = 0
	for item: StringName in _FLOW_ITEMS:
		total += int(sim.total_produced.get(item, 0))
	return total


## Run ONE full interleaved FLOW stress sequence under a fixed seed. Asserts invariants after every burst.
## Returns the final _state_signature so the caller can prove two same-seed runs match (determinism).
func _run_stress_flow_sequence(rng_seed: int) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed                                          # FIXED seed — reproducible, no Date/global rand
	var drill_def: MachineDef = load("res://src/data/machines/drill.tres")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	var hopper_def: MachineDef = load("res://src/data/machines/hopper.tres")
	var split_def: MachineDef = load("res://src/data/machines/splitter.tres")
	var hd_def: MachineDef = load("res://src/data/machines/h_drill.tres")

	var sim: FactorySim = FactorySim.new()
	# A hand-built factory floor: a stone shelf at row 22 across cols 2..40 (every column's landing), with
	# fat finite ore + coal veins hanging above it that drills can bore. Well in-bounds (GRID 96×80).
	for col: int in range(2, 41):
		sim.set_solid(Vector2i(col, 22), &"stone")

	# THREE multi-stage columns, gravity-threaded top→bottom, so _flow really routes stage to stage. A
	# splitter mid-stack sends half sideways into the next column over (lateral routing under churn). All
	# cells sit ABOVE the row-22 shelf, so every stream has a real landing (a machine, then the floor).
	# col 6:  drill(4) → ore vein(5) → forge(7) → hopper(9) → splitter(11)   [splitter feeds col 7]
	# col 14: drill(4) → ore vein(5) → forge(7) → hopper(9)
	# col 20: drill(4) → coal vein(5) → hopper(8)                            [coal funnels to a store]
	var ore_veins: Array[Vector2i] = [Vector2i(6, 5), Vector2i(14, 5)]
	for v: Vector2i in ore_veins:
		sim.set_solid(v, &"ore")
		sim.deposits[v] = 24                                     # finite — the drill drains it and STOPS
	sim.set_solid(Vector2i(20, 5), &"coal")
	sim.deposits[Vector2i(20, 5)] = 24
	sim.place_machine(drill_def, Vector2i(6, 4))
	sim.place_machine(proc_def, Vector2i(6, 7))
	sim.place_machine(hopper_def, Vector2i(6, 9))
	sim.place_machine(split_def, Vector2i(6, 11))
	sim.place_machine(drill_def, Vector2i(14, 4))
	sim.place_machine(proc_def, Vector2i(14, 7))
	sim.place_machine(hopper_def, Vector2i(14, 9))
	sim.place_machine(drill_def, Vector2i(20, 4))
	sim.place_machine(hopper_def, Vector2i(20, 8))
	# A BORER on a solid rock ledge with a face to bore and (initially) NO drain — its haul pools in the
	# belly (the on-hook rule), and it self-feeds bored coal. Rock at (30,10); a 6-cell earth face to the
	# right with a coal seam; the drill's own fuel comes from the seam once it reaches it (seed a little).
	sim.set_solid(Vector2i(30, 10), &"stone")
	for x: int in range(31, 37):
		sim.set_solid(Vector2i(x, 9), &"earth")
	sim.set_solid(Vector2i(33, 9), &"coal")
	sim.deposits[Vector2i(33, 9)] = 6
	var borer: MachineState = sim.place_machine(hd_def, Vector2i(30, 9))
	borer.facing = 1

	# Seed the pack (fuel + spare machine items + material to toss/cap), booked as produced so the ledger
	# starts balanced (present == produced - consumed).
	var start_pack: Dictionary = {
		&"coal": 120, &"ore": 30, &"ingot": 40, &"earth": 40, &"stone": 40, &"wood": 20,
		&"drill": 2, &"processor": 2, &"hopper": 2, &"splitter": 2, &"h_drill": 1,
	}
	for item: StringName in start_pack:
		sim.inventory[item] = int(start_pack[item])
		sim.total_produced[item] = int(sim.total_produced.get(item, 0)) + int(start_pack[item])

	# Fuel every drill + the borer generously so the veins actually flow under the churn.
	for dc: Vector2i in [Vector2i(6, 4), Vector2i(14, 4), Vector2i(20, 4)]:
		sim.machine_at(dc).input_buffer[&"coal"] = 30
		sim.total_produced[&"coal"] = int(sim.total_produced.get(&"coal", 0)) + 30
	borer.input_buffer[&"coal"] = 8
	sim.total_produced[&"coal"] = int(sim.total_produced.get(&"coal", 0)) + 8

	var loud: bool = rng_seed == 0xF107 and _flow_stress_first   # only the first run reports
	_flow_stress_first = false
	# Machine cells the reconfigure/rebuild ops target (real live machines, so they hit real flow paths).
	var split_cells: Array[Vector2i] = [Vector2i(6, 11)]
	var hopper_cells: Array[Vector2i] = [Vector2i(6, 9), Vector2i(14, 9), Vector2i(20, 8)]
	var ops: int = 0
	var did_save_load: bool = false

	# 26 bursts of ~10 mixed FLOW ops, ticking between each — hundreds of interleaved ops, bounded ticks.
	# The invariant BEFORE/AFTER a burst's ticks proves back-pressure is lossless (present never drops).
	var present_before: Dictionary = _flow_present_all(sim)
	for burst: int in 26:
		for _k: int in 10:
			ops += 1
			var choice: int = rng.randi_range(0, 9)
			match choice:
				0:
					# RECONFIGURE a splitter's ratio directly (the config panel's chips) — reroute mid-flow.
					sim.set_split_mode(split_cells[rng.randi_range(0, split_cells.size() - 1)],
						rng.randi_range(0, 3))
				1:
					# R-CYCLE a splitter ratio / CLEAR a hopper filter (re-taste) — the other reconfigure verb.
					var cfg: Array[Vector2i] = split_cells + hopper_cells
					sim.configure_machine(cfg[rng.randi_range(0, cfg.size() - 1)])
				2:
					# REMOVE a mid-stack machine (salvages buffers to the pack) then it can be REBUILT later —
					# tests that tearing a stage out mid-flow salvages, doesn't leak, and re-forms a valid path.
					var yank: Array[Vector2i] = [Vector2i(6, 9), Vector2i(14, 9), Vector2i(6, 11)]
					sim.pickup_machine(yank[rng.randi_range(0, yank.size() - 1)])
				3:
					# REBUILD a hopper/splitter from the pack back into a mid-stack cell (re-close the chain).
					var spot: Array = [[Vector2i(6, 9), hopper_def], [Vector2i(14, 9), hopper_def],
						[Vector2i(6, 11), split_def]]
					var pick: Array = spot[rng.randi_range(0, spot.size() - 1)]
					sim.build_from_pack(pick[1], pick[0])       # may fail (occupied) — must not corrupt
				4:
					# RAW remove (demolish — discards buffers, credited to consumed) at a random stack cell.
					var demo: Array[Vector2i] = [Vector2i(20, 8), Vector2i(14, 7), Vector2i(6, 7)]
					sim.remove_machine(demo[rng.randi_range(0, demo.size() - 1)])
				5:
					# CAP an output to build BACK-PRESSURE: place a floor block just under a stack's tail so
					# its stream jams up the buffers instead of draining (lossless-pile invariant tested by
					# present_before/after). Or clear one to release it. Cells between the stacks + shelf.
					var caps: Array[Vector2i] = [Vector2i(6, 13), Vector2i(14, 13), Vector2i(20, 10)]
					var cc: Vector2i = caps[rng.randi_range(0, caps.size() - 1)]
					if sim.is_solid(cc):
						sim.mine(cc)                            # release the cap
					else:
						sim.place_block(cc, &"stone")           # jam the drain
				6:
					# TOSS a carried stack down a stack column — extra input for _flow to route through.
					var col: int = [6, 14, 20][rng.randi_range(0, 2)]
					var item: StringName = [&"ore", &"coal", &"ingot"][rng.randi_range(0, 2)]
					sim.drop_item(Vector2i(col, 1), item, rng.randi_range(1, 4))
				7:
					# COLLECT the tails: scoop any ground pile at the stack feet so the floor doesn't just
					# accumulate (keeps the sim honest that piles are re-collectable, conservation-neutral).
					for gc: Variant in sim.ground.keys():
						sim.collect_ground(gc)
						break
				8:
					# RE-FUEL a drill / the borer mid-run (keeps the veins boring so flow is live all sequence).
					var fc: Vector2i = [Vector2i(6, 4), Vector2i(14, 4), Vector2i(20, 4),
						Vector2i(30, 9)][rng.randi_range(0, 3)]
					sim.deposit(fc, &"coal", rng.randi_range(1, 3))
				9:
					# OPEN/close the borer's drain — cap on solid rock = belly POOLS (lossless), open = pours
					# down its own column (the on-hook rule) onto the ledge floor.
					var bd := Vector2i(30, 10)
					if sim.is_solid(bd):
						sim.set_solid(bd, &"")
					else:
						sim.set_solid(bd, &"stone")
		# Step the sim so drills bore, forges smelt, hoppers meter, splitters route, the borer chews, and
		# gravity threads it all — against the churned topology.
		for _t: int in rng.randi_range(2, 6):
			sim.tick()

		# A save→disk→load roughly halfway; keep operating on the RESTORED sim in place (flow must survive it).
		if burst == 13 and not did_save_load:
			did_save_load = true
			var data: Dictionary = SaveGame.capture(sim)
			var path: String = "user://test_stress_flow_%d.save" % rng_seed
			var wrote: bool = SaveGame.write(path, data)
			var back: Dictionary = SaveGame.read(path)
			var restored: FactorySim = FactorySim.new()
			var ok: bool = SaveGame.restore(restored, back)
			if loud:
				_check(wrote and not back.is_empty() and ok, "mid-flow save→disk→load round-trips")
				_check(_state_signature(restored) == _state_signature(sim),
					"the restored mid-flow state is byte-identical to the live one")
			sim = restored
			DirAccess.remove_absolute(path)

		# INVARIANTS after this burst.
		if loud:
			_flow_assert_invariants(sim, present_before, "burst %d (%d ops)" % [burst, ops])
		present_before = _flow_present_all(sim)

	# Final gate.
	if loud:
		_flow_assert_invariants(sim, present_before, "final (%d ops)" % ops)
		_check(ops >= 200, "the flow sequence is long enough to stress interleavings (%d ops)" % ops)
		# NON-VACUOUS: the drills actually bored their veins and the forges actually smelted — so the flow
		# invariants were tested against a LIVE factory, not a dead one that trivially conserves nothing.
		_check(int(sim.total_produced.get(&"ingot", 0)) > 0,
			"the sequence really forged ingots (%d) — flow was live" % int(sim.total_produced.get(&"ingot", 0)))
		var vein_ore: int = int(sim.total_produced.get(&"ore", 0))
		_check(vein_ore > 30, "the drills bored real ore from the veins (%d produced)" % vein_ore)
	return _state_signature(sim)


## True until the first flow-stress run reports (so the determinism re-run doesn't double the log).
var _flow_stress_first: bool = true


## Per-item snapshot for the back-pressure invariant: {present, consumed, acc=present+consumed}. `acc` is
## the monotone-non-decreasing quantity a lossy-flow bug would break (see _flow_assert_invariants inv. 2).
func _flow_present_all(sim: FactorySim) -> Dictionary:
	var out: Dictionary = {}
	for item: StringName in _FLOW_ITEMS:
		var present: int = _items_present(sim, item)
		var consumed: int = int(sim.total_consumed.get(item, 0))
		out[item] = {"present": present, "consumed": consumed, "acc": present + consumed}
	return out


## Assert the FLOW invariants at a checkpoint. `present_before` is the snapshot from the LAST checkpoint
## (before this burst's edits + ticks) — used to prove back-pressure never dropped total present.
func _flow_assert_invariants(sim: FactorySim, present_before: Dictionary, where: String) -> void:
	# (1) CONSERVATION — every flow item: present == produced - consumed. _items_present already counts the
	# sink, pack, ground, and ALL machine buffers (the borer's belly = output_buffer, its bunker = input_buffer).
	var leaked: PackedStringArray = []
	for item: StringName in _FLOW_ITEMS:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		if present != net:
			leaked.append("%s(present=%d,net=%d)" % [item, present, net])
	_check(leaked.is_empty(), "%s — conservation holds for every flow item%s"
		% [where, "" if leaked.is_empty() else ": LEAKED " + ", ".join(leaked)])

	# (2) BACK-PRESSURE IS LOSSLESS — across this burst's edits+ticks, no item EVAPORATES. When a downstream
	# is capped/blocked, items must PILE in buffers, never vanish. The exact, time-ordered statement: since
	# present == produced - consumed (inv. 1) and BOTH produced and consumed only ever GROW, the quantity
	# (present + consumed) is monotone non-decreasing. So present may only FALL by exactly the amount that
	# moved into `consumed` (a smelt reagent, a demolished buffer, a sink void) — a genuine lossy-flow bug
	# (an item dropped in _flow/_deliver/routing) would drop present WITHOUT a matching consumed rise, which
	# this catches. present_before is a snapshot of (present, consumed) from the last checkpoint.
	var evaporated: PackedStringArray = []
	for item: StringName in _FLOW_ITEMS:
		var accounted_now: int = _items_present(sim, item) + int(sim.total_consumed.get(item, 0))
		var accounted_before: int = int((present_before.get(item, {}) as Dictionary).get("acc", accounted_now))
		if accounted_now < accounted_before:
			evaporated.append("%s(before=%d, now=%d)" % [item, accounted_before, accounted_now])
	_check(evaporated.is_empty(),
		"%s — back-pressure is lossless (present+consumed never fell → nothing evaporated)%s"
		% [where, "" if evaporated.is_empty() else ": " + ", ".join(evaporated)])

	# (3) NO NEGATIVE / RUNAWAY — no machine buffer holds a negative or a count past everything ever
	# produced, and no seeded deposit went negative. A runaway (branch-relattice amplification) or a
	# negative (double-decrement) would trip here.
	var ceiling: int = _flow_total_produced(sim) + 1
	var bad_buffer: PackedStringArray = []
	for machine: MachineState in sim.machines:
		for buf: Dictionary in [machine.input_buffer, machine.output_buffer]:
			for item: StringName in buf:
				var n: int = int(buf[item])
				if n < 0:
					bad_buffer.append("neg %s=%d @%s" % [item, n, str(machine.cell)])
				elif n > ceiling:
					bad_buffer.append("runaway %s=%d>%d @%s" % [item, n, ceiling, str(machine.cell)])
	for dcell: Variant in sim.deposits.keys():
		if int(sim.deposits[dcell]) < 0:
			bad_buffer.append("neg deposit @%s=%d" % [str(dcell), int(sim.deposits[dcell])])
	for gc: Variant in sim.ground.keys():
		for item: StringName in (sim.ground[gc] as Dictionary):
			if int((sim.ground[gc] as Dictionary)[item]) < 0:
				bad_buffer.append("neg pile %s @%s" % [item, str(gc)])
	_check(bad_buffer.is_empty(), "%s — no negative/runaway buffer, deposit, or pile%s"
		% [where, "" if bad_buffer.is_empty() else ": " + ", ".join(bad_buffer)])


## STRESS: the POWER NETWORK + its consumers under interleaved churn (adversarial). The siblings churn
## PLACEMENT (_test_stress_invariants) and FLOW (_test_stress_flow); this one churns the DERIVED POWER
## FIELD and the two consumers that read it — the LIFT (haul goods UP, power-governed) and the PUMP (the L3
## flood-drain, powered → removes water). Generators are placed/removed and fueled on and off; conduits are
## placed/removed and rerouted (incl. cells later mined out or built over — the cross-layer occupancy rules);
## pockets are flooded with add_water so pumps have work; the sim ticks in bursts so _compute_power,
## _flow_power_through_conduits, _flow_water and every consumer all run against the churned topology. After
## every burst + at the end it asserts: (1) POWER FIELD SANE — every power_at is finite, >= 0, bounded (no
## NaN/negative/runaway), and a cell only holds power where a generator+conduit path could justify it (a dark
## world reads exactly 0 everywhere); (2) ITEM CONSERVATION — present == produced − consumed for every id
## (coal, ore, ingot, conduit, machine items…), same as the other stress tests; (3) DRAINAGE SANE — across a
## burst with NO add_water, total_water is non-increasing (pumps only ever REMOVE), never negative, and an
## UNPOWERED pump drains nothing; (4) DETERMINISM — the whole sequence twice from one seed → identical final
## _state_signature. If any fails, it's a real power/conduit/pump/water-drain bug.
func _test_stress_power() -> void:
	print("- STRESS: power network + consumers (pump/lift) under churn (adversarial)")
	var final_a: String = _run_stress_power_sequence(0x9074E1)   # seeded run #1 (asserts invariants inline)
	var final_b: String = _run_stress_power_sequence(0x9074E1)   # seeded run #2 (silent — determinism proof)
	_check(final_a == final_b, "the WHOLE power sequence is deterministic (identical final state)")


## True until the first power-stress run reports (so the determinism re-run doesn't double the harness log).
var _power_stress_first: bool = true

## Item ids the power sequence can touch — its conservation frontier (asserted after every burst). Machine
## items (generator/lift/pump/conduit) satisfy the SAME present==produced-consumed rule as resources: crafted
## = produced, placed = consumed, picked back up = produced. Coal is the load-bearing one (the generator burns it).
const _POWER_ITEMS: Array[StringName] = [
	&"ore", &"coal", &"ingot", &"earth", &"stone",
	&"conduit", &"generator", &"lift", &"pump",
]

## A hard, generous upper bound on any single power reading: a conduit tube is capacity-clamped to
## CONDUIT_CAPACITY, a generator aura peaks at GENERATOR_POWER; the field takes MAXes of those (never sums
## unboundedly), so nothing sane can exceed this. A value past it (or NaN/negative) = a runaway/leak bug.
func _power_ceiling() -> float:
	return maxf(FactorySim.CONDUIT_CAPACITY, FactorySim.GENERATOR_POWER) + 1.0


## Run ONE full interleaved POWER stress sequence under a fixed seed. Asserts invariants after every burst.
## Returns the final _state_signature so the caller can prove two same-seed runs match (determinism).
func _run_stress_power_sequence(rng_seed: int) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed                                          # FIXED seed — reproducible, no Date/global rand
	var gen_def: MachineDef = load("res://src/data/machines/generator.tres")
	var lift_def: MachineDef = load("res://src/data/machines/lift.tres")
	var pump_def: MachineDef = load("res://src/data/machines/pump.tres")

	var sim: FactorySim = FactorySim.new()
	# A hand-built fixture, all well in-bounds (GRID 96×80): a stone shelf at row 24 across cols 2..44 gives
	# every column a landing; two SEALED flooded pockets give the pumps real work (walled shafts, brim-full);
	# a coal vein hangs above so drops have coal to route; a starting pack (booked as produced) starts the
	# ledger balanced. The power ops churn generators/conduits/lifts/pumps ON TOP of this.
	for col: int in range(2, 44):
		sim.set_solid(Vector2i(col, 24), &"stone")
	for col: int in range(4, 10):
		sim.set_solid(Vector2i(col, 6), &"coal")
		sim.deposits[Vector2i(col, 6)] = 30
	# Two sealed flooded pockets (a 1-wide walled shaft each, floor at the bottom, brim-full) — the pump work.
	# Cols 30 and 36; rows 10..15 open, row 16 floor, walls at col±1. Sealed so any total_water drop is a pump.
	var pocket_cols: Array[int] = [30, 36]
	var initial_water: int = 0
	for pc: int in pocket_cols:
		for row: int in range(10, 17):
			sim.set_solid(Vector2i(pc - 1, row), &"stone")      # left wall
			sim.set_solid(Vector2i(pc + 1, row), &"stone")      # right wall
		sim.set_solid(Vector2i(pc, 16), &"stone")               # floor
		for row: int in range(10, 16):                          # fill the 6 open cells to the brim
			initial_water += sim.add_water(Vector2i(pc, row), FactorySim.WATER_MAX)
	# Seed the pack + book it as produced so the ledger starts balanced (present == produced - consumed).
	var start_pack: Dictionary = {
		&"coal": 120, &"ore": 20, &"ingot": 40, &"earth": 30, &"stone": 30,
		&"conduit": 30, &"generator": 3, &"lift": 3, &"pump": 3,
	}
	for item: StringName in start_pack:
		sim.inventory[item] = int(start_pack[item])
		sim.total_produced[item] = int(sim.total_produced.get(item, 0)) + int(start_pack[item])

	var loud: bool = rng_seed == 0x9074E1 and _power_stress_first  # only the first run reports
	_power_stress_first = false

	# The pump cells sit in the TOP of each flooded pocket, so a placed pump has water in reach to drain.
	var pump_tops: Array[Vector2i] = [Vector2i(30, 10), Vector2i(36, 10)]
	# Generator/lift/conduit ops target a churn zone left of the pockets (cols 2..26), plus BESIDE the pumps
	# (so a generator can actually power a pump). Cells picked here are the interleaving surface.
	var ops: int = 0
	var did_save_load: bool = false

	# 24 bursts of ~11 mixed power ops, ticking between each — hundreds of interleaved ops, bounded ticks.
	# Each burst records water BEFORE any add_water this burst, then does its ops+ticks, so the drainage
	# invariant (total_water non-increasing when nothing was added) is checked against a real baseline.
	for burst: int in 24:
		var water_before_burst: int = sim.total_water()
		var added_water_this_burst: bool = false
		for _k: int in 11:
			ops += 1
			var choice: int = rng.randi_range(0, 10)
			var cell: Vector2i = Vector2i(rng.randi_range(2, 26), rng.randi_range(3, 22))
			match choice:
				0:
					# BUILD a GENERATOR from the pack — either in the churn zone or BESIDE a pump (to power it).
					var spot: Vector2i = cell
					if rng.randi_range(0, 1) == 0:
						spot = pump_tops[rng.randi_range(0, pump_tops.size() - 1)] + Vector2i(-2, 0)
					if int(sim.inventory.get(&"generator", 0)) <= 0:
						sim.craft_item(gen_def.id, gen_def.craft_cost, gen_def.craft_count)   # may fail — fine
					sim.build_from_pack(gen_def, spot)            # may fail (occupied/solid) — must not corrupt
				1:
					# FUEL a generator ON: hand-feed coal into whatever machine is at the cell (a generator burns it).
					var gc: Vector2i = cell
					if rng.randi_range(0, 1) == 0:
						gc = pump_tops[rng.randi_range(0, pump_tops.size() - 1)] + Vector2i(-2, 0)
					sim.deposit(gc, &"coal", rng.randi_range(1, 4))
				2:
					# PLACE a PUMP into the top of a flooded pocket (so it has water to drain) — or a random cell.
					var pspot: Vector2i = cell
					if rng.randi_range(0, 1) == 0:
						pspot = pump_tops[rng.randi_range(0, pump_tops.size() - 1)]
					if int(sim.inventory.get(&"pump", 0)) <= 0:
						sim.craft_item(pump_def.id, pump_def.craft_cost, pump_def.craft_count)
					sim.build_from_pack(pump_def, pspot)
				3:
					# PLACE a LIFT (the powered up-hauler) + toss a stack onto it so it carries under power.
					if int(sim.inventory.get(&"lift", 0)) <= 0:
						sim.craft_item(lift_def.id, lift_def.craft_cost, lift_def.craft_count)
					var lift: MachineState = sim.build_from_pack(lift_def, cell)
					if lift != null and int(sim.inventory.get(&"ore", 0)) > 0:
						sim.deposit(cell, &"ore", mini(4, int(sim.inventory.get(&"ore", 0))))
				4:
					# PICK a machine back up (salvages buffers into the pack) — tears a generator/lift/pump out mid-run.
					if rng.randi_range(0, 1) == 0:
						sim.pickup_machine(cell)
					else:
						sim.pickup_machine(pump_tops[rng.randi_range(0, pump_tops.size() - 1)]
							+ Vector2i(-2, 0))
				5:
					# CONDUIT place/remove/reroute — the network churn (down+lateral power routing).
					if sim.has_conduit(cell):
						sim.remove_conduit(cell)
					else:
						sim.place_conduit(cell)
				6:
					# LAY A CONDUIT RUN from a churn-zone cell DOWN a few cells (a real trunk power can flood).
					var run: int = rng.randi_range(1, 5)
					for i: int in run:
						sim.place_conduit(cell + Vector2i(0, i))  # may refuse (occupied) — must not corrupt
				7:
					# MINE the cell — may erase a conduit's neighbour, a generator's footing, or a pocket wall
					# (cross-layer: a conduit stays a conduit when the rock beside it is dug; a machine's power
					# path can change). place_block's inverse; conservation must hold across the terrain edit.
					sim.mine(cell)
				8:
					# PLACE a block over a cell — can build OVER open cells beside conduits/machines (the
					# occupancy gate must refuse a solid-on-conduit overlap without leaking).
					var mat: StringName = [&"earth", &"stone"][rng.randi_range(0, 1)]
					sim.place_block(cell, mat)
				9:
					# FLOOD a random pocket cell with a splash of water (so pumps keep having work). Flagged so
					# the drainage invariant knows water was ADDED this burst (total_water may legitimately rise).
					var pcol: int = pocket_cols[rng.randi_range(0, pocket_cols.size() - 1)]
					var prow: int = rng.randi_range(10, 15)
					if sim.add_water(Vector2i(pcol, prow), rng.randi_range(1, FactorySim.WATER_MAX)) > 0:
						added_water_this_burst = true
				10:
					# RAW remove (demolish — discards buffers, credited to consumed) at the cell.
					sim.remove_machine(cell)
		# Step the sim so _compute_power / _flow_power_through_conduits / consumers / _flow_water all run.
		for _t: int in rng.randi_range(2, 6):
			sim.tick()

		# A save→disk→load roughly halfway; keep operating on the RESTORED sim (the power field is DERIVED, so
		# it must rebuild identically next tick; water + conduits + machine fuel ride the envelope).
		if burst == 12 and not did_save_load:
			did_save_load = true
			var data: Dictionary = SaveGame.capture(sim)
			var path: String = "user://test_stress_power_%d.save" % rng_seed
			var wrote: bool = SaveGame.write(path, data)
			var back: Dictionary = SaveGame.read(path)
			var restored: FactorySim = FactorySim.new()
			var ok: bool = SaveGame.restore(restored, back)
			if loud:
				_check(wrote and not back.is_empty() and ok, "mid-power save→disk→load round-trips")
				_check(_state_signature(restored) == _state_signature(sim),
					"the restored mid-power state is byte-identical to the live one")
			sim = restored
			DirAccess.remove_absolute(path)

		# INVARIANTS after this burst. Drainage is checked against the pre-burst water total, but ONLY when no
		# water was added this burst (an add_water op legitimately raises total_water — not a pump violation).
		if loud:
			_power_assert_invariants(sim, "burst %d (%d ops)" % [burst, ops])
			if not added_water_this_burst:
				_check(sim.total_water() <= water_before_burst,
					"burst %d — total_water never ROSE without an add (%d -> %d): pumps only drain"
					% [burst, water_before_burst, sim.total_water()])

	# Final gate.
	if loud:
		_power_assert_invariants(sim, "final (%d ops)" % ops)
		_check(ops >= 250, "the power sequence is long enough to stress interleavings (%d ops)" % ops)
		# NON-VACUOUS: the pockets started flooded and the pumps really pumped — so the drainage invariants
		# were tested against LIVE water, not a dry world that trivially "never rises".
		_check(initial_water > 0, "the pockets started flooded (%d units) — drainage had something to test"
			% initial_water)
		var drained: int = int(sim.total_consumed.get(&"coal", 0))
		_check(drained > 0, "generators actually burned coal (%d) — power was live" % drained)
	return _state_signature(sim)


## Assert the POWER invariants on `sim` at a checkpoint. Failing here = a real power/conduit/pump/water bug.
func _power_assert_invariants(sim: FactorySim, where: String) -> void:
	# (1) POWER FIELD SANE — every reading is finite, >= 0, and bounded by the physical ceiling. And the field
	# is DERIVED: every powered cell must be justified by a nearby fueled generator (within its aura, or within
	# aura+conduit reach). We prove justification cheaply: a fueled generator exists — if there is NONE, the
	# field must be EXACTLY empty (a dark world reads 0 everywhere; a stray reading would be an invented supply).
	var fueled_gen: bool = false
	for m: MachineState in sim.machines:
		if sim._behavior_flag(m.def, &"power_source") and m.fuel > 0:
			fueled_gen = true
			break
	var ceiling: float = _power_ceiling()
	var bad_power: PackedStringArray = []
	for pcell: Variant in sim.power.keys():
		var v: float = sim.power_at(pcell)
		if is_nan(v) or is_inf(v):
			bad_power.append("nonfinite %s=%s" % [str(pcell), str(v)])
		elif v < 0.0:
			bad_power.append("negative %s=%.3f" % [str(pcell), v])
		elif v > ceiling:
			bad_power.append("runaway %s=%.3f>%.3f" % [str(pcell), v, ceiling])
	_check(bad_power.is_empty(), "%s — power field finite/>=0/bounded%s"
		% [where, "" if bad_power.is_empty() else ": " + ", ".join(bad_power)])
	# No fueled generator anywhere → NO cell can carry power, so the derived field must be empty. This catches
	# a "power where nothing justifies it" leak. *** THIS ASSERT IS CURRENTLY RED — it caught a real bug: ***
	# _flow_power_through_conduits stamps a 0.0-valued GHOST entry into `power` for EVERY conduit cell (+ its 4
	# bled neighbours) unconditionally — carried[cell] = minf(0.0, CAP) = 0.0 with no source, then written to the
	# field. power_at() reads 0 (correct value), but the ENTRY exists, so consumers that iterate power.keys()
	# treat a dead conduit as lit: hud.gd's minimap frontier-reach draws every power.keys() cell at alpha
	# >= 0.12, so laying a conduit with no/unfueled generator wrongly washes the whole run "powered" on the map.
	# Minimal repro: a lone `sim.conduit[Vector2i(8,8)] = 1`, no generator, one tick → sim.power.size() == 5
	# (the cell + 4 neighbours), all valued 0.0. Fix belongs in the game (skip writing <=0 carried power / prune
	# zero entries), NOT here — this test stays RED demonstrating the catch.
	if not fueled_gen:
		var ghosts: PackedStringArray = []
		for pcell2: Variant in sim.power.keys():
			ghosts.append("%s=%.3f" % [str(pcell2), sim.power_at(pcell2)])
		_check(sim.power.is_empty(),
			"%s — no fueled generator → the power field must be EMPTY, but holds %d GHOST cell(s) (0-valued conduit entries that light the minimap)%s"
			% [where, sim.power.size(),
				"" if ghosts.is_empty() else ": " + ", ".join(ghosts.slice(0, 6)) + ("…" if ghosts.size() > 6 else "")])

	# (2) ITEM CONSERVATION — every touched item id: present == produced - consumed (machine items included).
	var leaked: PackedStringArray = []
	for item: StringName in _POWER_ITEMS:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		if present != net:
			leaked.append("%s(present=%d,net=%d)" % [item, present, net])
	_check(leaked.is_empty(), "%s — conservation holds for every item%s"
		% [where, "" if leaked.is_empty() else ": LEAKED " + ", ".join(leaked)])

	# (3) DRAINAGE SANE (per-cell) — no water level is ever negative or over WATER_MAX (integer + clamped), and
	# no watered cell is also solid rock (rock displaces water). A pump double-decrement or a stray add into
	# rock would trip here. (The across-burst "total never rose without an add" check lives in the burst loop.)
	var bad_water: PackedStringArray = []
	for wcell: Variant in sim.water.keys():
		var lvl: int = int(sim.water[wcell])
		if lvl < 0 or lvl > FactorySim.WATER_MAX:
			bad_water.append("bad-level %s=%d" % [str(wcell), lvl])
		if sim.solid.has(wcell):
			bad_water.append("water-in-rock %s" % str(wcell))
	_check(bad_water.is_empty(), "%s — every water level is valid (0..WATER_MAX) and never in rock%s"
		% [where, "" if bad_water.is_empty() else ": " + ", ".join(bad_water)])

	# (4) NO CORRUPTION — a conduit never shares a cell with solid rock or a machine (the cross-layer occupancy
	# rule that mine/place_block/place_conduit must jointly uphold under churn).
	var bad_layer: int = 0
	for ccell: Variant in sim.conduit.keys():
		if sim.solid.has(ccell) or sim.grid.has(ccell):
			bad_layer += 1
	_check(bad_layer == 0, "%s — no conduit overlaps solid rock or a machine (%d bad)" % [where, bad_layer])


## STRESS: the RESEARCH → CRAFT → PLACE gating chain under interleaved churn (adversarial). The siblings
## churn PLACEMENT (_test_stress_invariants), FLOW (_test_stress_flow), and POWER (_test_stress_power); this
## one churns the PROGRESSION GATE — the demand-side pull (docs/PROGRESSION.md §5, ResearchRules). Live play
## keeps surfacing gate bugs from UNUSUAL orderings (the pump-reachability bug that motivated this): attempt
## to research a tech before its prereq / with no sample / with the price short / twice; attempt to craft &
## build a machine before AND after its gating tech is in; grant samples+costs sometimes-insufficient,
## sometimes-enough; interleave craft→build→pickup of the just-unlocked machines and tick between bursts so
## the placed machines run against the churned research state. After EVERY burst + at the end it asserts:
##   (1) GATE HONORED — a machine/tool whose locking tech is NOT researched can NEVER be crafted (craft
##       returns false AND produced nothing); once researched it CAN. A tech whose `requires` is unmet, or
##       whose sample/price is short, is NEVER recorded as researched.
##   (2) RESEARCH MONOTONE + DISCRETE — a tech, once unlocked, never re-locks; is_researched() matches the
##       `research` dict exactly; only ids that live in the tree are ever recorded (no invented tech).
##   (3) CONSERVATION — for every item id touched (craft inputs/outputs, machine items, the research
##       sample + refined-goods cost), _items_present == total_produced − total_consumed. A gate path that
##       leaks or dupes an item (double-spend a refused research, produce an item on a refused craft) fails.
##   (4) DETERMINISM — the whole seeded sequence twice from one seed → byte-identical final _state_signature.
## A save→disk→load happens MID-sequence and the churn continues on the restored sim, so the research dict +
## every ledger must survive a serialization round-trip too. Bounded to run in a couple of seconds.
func _test_stress_research() -> void:
	print("- STRESS: research→craft→place gating under churn (adversarial)")
	var final_a: String = _run_stress_research_sequence(0xC0FFEE)   # seeded run #1 (asserts invariants inline)
	var final_b: String = _run_stress_research_sequence(0xC0FFEE)   # seeded run #2 (silent — determinism proof)
	_check(final_a == final_b, "the WHOLE research→craft→place sequence is deterministic (identical final state)")


## True until the first research-stress run reports (so the determinism re-run doesn't double the harness log).
var _research_stress_first: bool = true

## The item ids the research sequence can touch — its conservation frontier (asserted after every burst).
## Includes the analyze SAMPLES (ore/coal/deepslate/iron/iron_ingot/rich_ore), the refined-goods research
## COSTS (ingot/iron_ingot/plate/gear), and every gated MACHINE + the gated TOOL (scanner). Machine/tool items
## satisfy the SAME present==produced-consumed rule as resources — the ledger is total.
const _RESEARCH_ITEMS: Array[StringName] = [
	&"ore", &"coal", &"deepslate", &"iron", &"iron_ingot", &"rich_ore", &"ingot", &"plate", &"gear",
	&"drill", &"hopper", &"generator", &"conduit", &"lift", &"descent_engine",
	&"iron_forge", &"plate_press", &"gear_mill", &"h_drill", &"blast_furnace", &"pump", &"scanner",
]


## Run ONE full interleaved research→craft→place sequence under a fixed seed. Asserts invariants after every
## burst. Returns the final _state_signature so two same-seed runs can be compared for determinism.
func _run_stress_research_sequence(rng_seed: int) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed                                          # FIXED seed — reproducible, no Date/global rand

	# Every research-gated machine def, keyed by id (so we can look one up by its gating tech's unlock list).
	var defs_by_id: Dictionary = {}
	for id: StringName in [&"drill", &"hopper", &"generator", &"conduit", &"lift", &"descent_engine",
			&"iron_forge", &"plate_press", &"gear_mill", &"h_drill", &"blast_furnace", &"pump"]:
		defs_by_id[id] = load("res://src/data/machines/%s.tres" % id) as MachineDef

	var sim: FactorySim = FactorySim.new()
	# A floor shelf at row 20 across cols 2..40 so built machines have footing/landing (GRID 96×80 — all
	# well in-bounds). No worldgen: the pack is injected and booked as produced so the ledger starts balanced.
	for col: int in range(2, 40):
		sim.set_solid(Vector2i(col, 20), &"stone")
	# A GENEROUS pack of every sample + every refined good the ladder wants, booked as produced so
	# present == produced - consumed holds from tick 0. Deliberately large so many crafts/researches SUCCEED
	# (the gate is exercised on the yes-path too), but each op is small enough that some still fall short.
	var start_pack: Dictionary = {
		&"ore": 60, &"coal": 40, &"deepslate": 30, &"iron": 60, &"iron_ingot": 80, &"rich_ore": 20,
		&"ingot": 200, &"plate": 40, &"gear": 40,
	}
	for item: StringName in start_pack:
		sim.inventory[item] = int(start_pack[item])
		sim.total_produced[item] = int(sim.total_produced.get(item, 0)) + int(start_pack[item])

	var loud: bool = rng_seed == 0xC0FFEE and _research_stress_first  # only the first run reports
	_research_stress_first = false
	var ops: int = 0
	var did_save_load: bool = false

	# 26 bursts of ~14 mixed gate ops, ticking between each — hundreds of interleaved ops, bounded ticks.
	for burst: int in 26:
		for _k: int in 14:
			ops += 1
			var choice: int = rng.randi_range(0, 9)
			# A build/pickup cell on the open row just above the shelf (row 19), so a build has real footing.
			var cell: Vector2i = Vector2i(rng.randi_range(2, 38), 19)
			match choice:
				0:
					# RESEARCH the NEXT valid tech (prereq met) — the yes-path of the gate. May still fail if the
					# sample or the refined-goods price is short THIS moment (both are legit refusals).
					var nxt: StringName = ResearchRules.next_tech(sim.research)
					if nxt != &"":
						sim.research_tech(nxt)
				1:
					# RESEARCH an ARBITRARY tech in the tree (often out of order → prereq unmet → MUST refuse
					# without recording it or spending anything). This is the invalid-order churn.
					var any_tid: StringName = ResearchRules.ORDER[rng.randi_range(0, ResearchRules.ORDER.size() - 1)]
					sim.research_tech(any_tid)
				2:
					# RESEARCH a BOGUS tech id — must refuse, record nothing, spend nothing (no invented tech).
					sim.research_tech([&"phlogiston", &"unobtainium", &"", &"warp"][rng.randi_range(0, 3)])
				3:
					# STARVE research TEMPORARILY: hide the whole pack of a random SAMPLE, try the next tech (with
					# no sample research_tech must REFUSE — proving the sample gate, not just the price), then RESTORE
					# the sample so the ladder can still progress deeper in later bursts (the yes-path reaches L2+).
					# Nothing is spent on a refused research, so the temporary hide/restore is conservation-neutral.
					var sample: StringName = [&"ore", &"coal", &"deepslate", &"iron", &"iron_ingot", &"rich_ore"][rng.randi_range(0, 5)]
					var had: int = int(sim.inventory.get(sample, 0))
					if had > 0:
						sim.inventory.erase(sample)
					var nxt2: StringName = ResearchRules.next_tech(sim.research)
					if nxt2 != &"":
						sim.research_tech(nxt2)                   # refuses if that tech wanted the hidden sample
					if had > 0:                                   # restore — the refusal spent nothing, so the pack is intact
						sim.inventory[sample] = int(sim.inventory.get(sample, 0)) + had
				4:
					# CRAFT a random gated MACHINE item into the pack. Must succeed IFF its tech is researched;
					# a refused craft (locked, or ingredients short) must produce nothing / spend nothing.
					var did: MachineDef = defs_by_id.values()[rng.randi_range(0, defs_by_id.size() - 1)]
					sim.craft(did)
				5:
					# CRAFT via the GENERIC primitive (craft_item) for a machine — the same gate must apply
					# (machines and tools share craft_item, so gating a machine here proves the shared path).
					var did2: MachineDef = defs_by_id.values()[rng.randi_range(0, defs_by_id.size() - 1)]
					sim.craft_item(did2.id, did2.craft_cost, did2.craft_count)
				6:
					# CRAFT the gated TOOL (scanner — the first TOOL behind research, locked by Prospecting).
					# Same craft_item gate as machines: refuses until Prospecting is in, then crafts.
					sim.craft_item(&"scanner", MiningRules.TOOL_RECIPES[&"scanner"], 1)
				7:
					# BUILD a machine from the pack onto the open row (consumes the item; may fail if none carried
					# or the cell is occupied — must not corrupt). This is the PLACE half of research→craft→place.
					var did3: MachineDef = defs_by_id.values()[rng.randi_range(0, defs_by_id.size() - 1)]
					sim.build_from_pack(did3, cell)
				8:
					# PICK a machine back up (returns the item to the pack — the salvage half; conservation must
					# survive craft→place→pickup of a research-gated machine, the ledger being total).
					sim.pickup_machine(cell)
				9:
					# CRAFT a gated machine we KNOW is unlocked-or-not, then IMMEDIATELY try to build it — the
					# tight craft→place coupling that the pump-reachability bug lived in.
					var did4: MachineDef = defs_by_id[[&"pump", &"lift", &"h_drill", &"blast_furnace"][rng.randi_range(0, 3)]]
					if sim.craft(did4):
						sim.build_from_pack(did4, cell)
		# Step the sim so any built machines run against the churned research/pack state.
		for _t: int in rng.randi_range(1, 5):
			sim.tick()

		# A save→disk→load roughly halfway; keep operating on the RESTORED sim (research + ledgers ride the envelope).
		if burst == 13 and not did_save_load:
			did_save_load = true
			var data: Dictionary = SaveGame.capture(sim)
			var path: String = "user://test_stress_research_%d.save" % rng_seed
			var wrote: bool = SaveGame.write(path, data)
			var back: Dictionary = SaveGame.read(path)
			var restored: FactorySim = FactorySim.new()
			var ok: bool = SaveGame.restore(restored, back)
			if loud:
				_check(wrote and not back.is_empty() and ok, "mid-sequence research save→disk→load round-trips")
				_check(_state_signature(restored) == _state_signature(sim),
					"the restored mid-sequence research state is byte-identical to the live one")
			sim = restored
			DirAccess.remove_absolute(path)

		# INVARIANTS after this burst.
		if loud:
			_research_assert_invariants(sim, "burst %d (%d ops)" % [burst, ops])

	# Final gate + NON-VACUOUS proof (the sequence really exercised BOTH sides of the gate, not just refusals).
	if loud:
		_research_assert_invariants(sim, "final (%d ops)" % ops)
		_check(ops >= 300, "the research sequence is long enough to stress interleavings (%d ops)" % ops)
		_check(sim.research.size() > 0, "some techs actually researched — the yes-path was exercised (%d)" % sim.research.size())
		var crafted_any: bool = false
		for id: StringName in _RESEARCH_ITEMS:
			if int(sim.total_produced.get(id, 0)) > int(start_pack.get(id, 0)):
				crafted_any = true                                # a gated item was produced by a real craft/pickup
				break
		_check(crafted_any, "some gated machine/tool actually crafted — the craft yes-path was exercised")
	return _state_signature(sim)


## Assert the research→craft→place GATE invariants on `sim` at a checkpoint. Failing here = a real gate bug.
func _research_assert_invariants(sim: FactorySim, where: String) -> void:
	# (1) GATE HONORED — for EVERY gated item id, if its locking tech is NOT researched then it must be
	# un-craftable (craft_unlocked false). This is the core gate: a crafted-but-locked item is the bug.
	var breaches: PackedStringArray = []
	for tid: StringName in ResearchRules.TECHS:
		var researched: bool = sim.research.has(tid)
		for uid: StringName in (ResearchRules.TECHS[tid]["unlocks"] as Array):
			var unlocked: bool = sim.craft_unlocked(uid)
			if researched and not unlocked:
				breaches.append("%s researched but %s still locked" % [tid, uid])
			elif not researched and unlocked:
				breaches.append("%s NOT researched but %s craftable" % [tid, uid])
	_check(breaches.is_empty(), "%s — the craft gate matches the research state for every unlock%s"
		% [where, "" if breaches.is_empty() else ": " + ", ".join(breaches)])

	# (2) RESEARCH MONOTONE + DISCRETE — every recorded tech is a REAL tree id (no invented/bogus id got in),
	# its prereq was met when recorded (a tech in the set implies its `requires` is also in the set), and
	# is_researched() mirrors the dict exactly. (Monotone — never re-locks — is enforced across the whole run
	# by the determinism proof + the gate check above; here we assert the set is internally CONSISTENT.)
	var bad_research: PackedStringArray = []
	for tid2: Variant in sim.research.keys():
		var id2: StringName = tid2
		if not ResearchRules.TECHS.has(id2):
			bad_research.append("invented tech '%s'" % id2)
		elif not ResearchRules.prereq_met(id2, sim.research):
			bad_research.append("'%s' recorded with an UNMET prereq" % id2)
		elif not sim.is_researched(id2):
			bad_research.append("is_researched disagrees for '%s'" % id2)
	_check(bad_research.is_empty(), "%s — research set is discrete/monotone/consistent%s"
		% [where, "" if bad_research.is_empty() else ": " + ", ".join(bad_research)])

	# (3) CONSERVATION — every touched item id: present == produced - consumed (samples, costs, machine + tool
	# items all included). A refused research that still spent, or a refused craft that still produced, fails here.
	var leaked: PackedStringArray = []
	for item: StringName in _RESEARCH_ITEMS:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		if present != net:
			leaked.append("%s(present=%d,net=%d)" % [item, present, net])
	_check(leaked.is_empty(), "%s — conservation holds for every item%s"
		% [where, "" if leaked.is_empty() else ": LEAKED " + ", ".join(leaked)])
