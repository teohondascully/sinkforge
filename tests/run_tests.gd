extends SceneTree

## Headless validation harness — Layer 2 (sim unit tests) + tripwire #2 (determinism &
## item conservation). The node-free sim is testable with no scene tree, which is the whole
## point of the architecture.
##
## Run: godot --headless --path . --script res://tests/run_tests.gd
## Exits 0 on all-pass, non-zero on any failure.

var _failures: int = 0


func _initialize() -> void:
	print("== Sinkforge sim tests ==")
	_test_placement()
	_test_conservation()
	_test_determinism()
	_test_state_canary()
	_test_production()
	_test_production_rate()
	_test_machine_census()
	_test_machine_problems()
	_test_splitter()
	_test_terrain()
	_test_surface_silhouette()
	_test_mining_and_deposit()
	_test_hand_built_chain()
	_test_inventory_slots()
	_test_spit_and_collect()
	_test_slope_item_flow()
	_test_pile_falls_when_floor_mined()
	_test_craft_and_build()
	_test_worldgen()
	_test_layered_worldgen()
	_test_horizontal_ore_pull()
	_test_lift()
	_test_finite_deposit_and_drill()
	_test_coal_and_fuel()
	_test_trees_and_wood()
	_test_mining_rules()
	_test_hopper()
	_test_drop_toss()
	_test_block_placement_and_bazaar()
	_test_block_supported()
	_test_power_field()
	_test_conduit_network()
	_test_powered_lift()
	_test_pump()
	_test_automated_line()
	_test_machine_status()
	_test_no_empty_ground_piles()
	_test_behavior_registry()
	_test_rope()
	_test_saplings()
	_test_torch()
	_test_water_fluid()
	_test_save_load()
	_test_iron_chain()
	_test_rich_ore()
	_test_h_drill()
	_test_filter_ratio_passthrough()
	_test_research()
	_test_descent_gate()
	_test_descent_automation()
	_test_hints()
	_test_falling_pool()
	_test_scanner()
	_test_fine_terrain()
	_test_stress_invariants()
	_test_stress_flow()
	if _failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % _failures)
		quit(1)


# --- helpers -----------------------------------------------------------------

func _build_sim() -> FactorySim:
	# Vent on top of a column, processor lower in the SAME column: vent output falls down
	# the empty cells between them into the processor, then ingots fall to the sink.
	var vent_def: MachineDef = load("res://src/data/machines/ore_vent.tres")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	var sim: FactorySim = FactorySim.new()
	sim.place_machine(vent_def, Vector2i(6, 0))
	sim.place_machine(proc_def, Vector2i(6, 3))
	return sim


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)


func _items_present(sim: FactorySim, item: StringName) -> int:
	var total: int = int(sim.sink.get(item, 0))
	total += int(sim.inventory.get(item, 0))  # what the player is carrying counts as present too
	for pile: Variant in sim.ground.values():  # resting product piles on the floor
		total += int((pile as Dictionary).get(item, 0))
	for machine: MachineState in sim.machines:
		total += int(machine.input_buffer.get(item, 0))
		total += int(machine.output_buffer.get(item, 0))
	return total


func _dict_sig(d: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: StringName in d:
		parts.append("%s=%d" % [k, int(d[k])])
	return ",".join(parts)


## Invariant behind the tree tests (the user's "nothing floats" bug): every foliage cell is ROOTED — its
## 8-connected foliage component contains a cell resting directly on non-foliage solid ground. Mirrors
## FactorySim._settle_foliage's rule; false ⇒ a tree is left floating in the air.
func _no_floating_foliage(sim: FactorySim) -> bool:
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
	var is_fol := func(m: StringName) -> bool: return m == &"wood" or m == &"leaves"
	var visited: Dictionary = {}
	for cell: Vector2i in sim.solid:
		if not is_fol.call(sim.solid[cell]) or visited.has(cell):
			continue
		var stack: Array[Vector2i] = [cell]
		visited[cell] = true
		var rooted: bool = false
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			var below: Vector2i = c + Vector2i(0, 1)
			if sim.solid.has(below) and not is_fol.call(sim.solid[below]):
				rooted = true
			for d: Vector2i in dirs:
				var nb: Vector2i = c + d
				if not visited.has(nb) and sim.solid.has(nb) and is_fol.call(sim.solid[nb]):
					visited[nb] = true
					stack.append(nb)
		if not rooted:
			return false
	return true


## The WHOLE authoritative state as one canonical string (FABLE_50 #2). Built on SaveGame.capture,
## so the canary and the save format can never drift apart: any field added to the envelope is
## automatically guarded here, and a field the envelope misses is a field this canary misses — one
## list, two guards. Dictionary keys are sorted (content-based, insertion-order-proof); machine
## ARRAY order is kept as-is because tick order is itself authoritative.
func _state_signature(sim: FactorySim) -> String:
	return _canon(SaveGame.capture(sim))


func _canon(v: Variant) -> String:
	match typeof(v):
		TYPE_DICTIONARY:
			var d: Dictionary = v
			var keys: Array = d.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			var parts: PackedStringArray = []
			for k: Variant in keys:
				parts.append("%s=%s" % [str(k), _canon(d[k])])
			return "{%s}" % ",".join(parts)
		TYPE_ARRAY:
			var parts: PackedStringArray = []
			for e: Variant in (v as Array):
				parts.append(_canon(e))
			return "[%s]" % ",".join(parts)
		_:
			return str(v)


# --- tests -------------------------------------------------------------------

## Placement API: in-bounds empty cells accept machines; occupied/out-of-bounds are rejected;
## removal clears the cell.
func _test_placement() -> void:
	print("- placement")
	var sim: FactorySim = FactorySim.new()
	var vent_def: MachineDef = load("res://src/data/machines/ore_vent.tres")
	_check(sim.place_machine(vent_def, Vector2i(2, 2)) != null, "place in an empty cell")
	_check(sim.machine_at(Vector2i(2, 2)) != null, "machine_at finds the placed machine")
	_check(sim.place_machine(vent_def, Vector2i(2, 2)) == null, "cannot place on an occupied cell")
	_check(sim.place_machine(vent_def, Vector2i(-1, 0)) == null, "cannot place out of bounds")
	sim.remove_machine(Vector2i(2, 2))
	_check(sim.machine_at(Vector2i(2, 2)) == null, "remove clears the cell")


## Every item is created/destroyed ONLY by a recipe: items currently present must equal
## (total produced - total consumed). If this ever fails, the sim is leaking or inventing items.
func _test_conservation() -> void:
	print("- conservation")
	var sim: FactorySim = _build_sim()
	for _i: int in 200:
		sim.tick()
	for item: StringName in [&"ore", &"ingot"]:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present == net, "%s conserved (present=%d, produced-consumed=%d)" % [item, present, net])


## Same sim + same number of ticks => byte-identical state. This is the guard that fails the
## day non-determinism (or visuals leaking into the sim) creeps in.
func _test_determinism() -> void:
	print("- determinism")
	var a: FactorySim = _build_sim()
	var b: FactorySim = _build_sim()
	for _i: int in 200:
		a.tick()
		b.tick()
	_check(_state_signature(a) == _state_signature(b), "identical state after 200 ticks")


## The canary must SEE every authoritative layer: for each one, mutate a fresh sim in just that
## layer and assert the signature moves. A layer that can drift silently (the old canary saw only
## sink + machine buffers) is a whole class of leak the determinism test can't catch.
func _test_state_canary() -> void:
	print("- determinism canary covers the whole state")
	var base: String = _state_signature(_build_sim())
	var probes: Dictionary = {
		"solid": func(s: FactorySim) -> void: s.set_solid(Vector2i(1, 1), &"earth"),
		"wall": func(s: FactorySim) -> void: s.set_wall(Vector2i(1, 1), &"earth_wall"),
		"deposits": func(s: FactorySim) -> void: s.deposits[Vector2i(1, 1)] = 5,
		"inventory": func(s: FactorySim) -> void: s.inventory[&"ore"] = 3,
		"ground": func(s: FactorySim) -> void: s.ground[Vector2i(1, 1)] = {&"ore": 1},
		"conduit": func(s: FactorySim) -> void: s.conduit[Vector2i(1, 1)] = true,
		"rope": func(s: FactorySim) -> void: s.rope[Vector2i(1, 1)] = true,
		"torch": func(s: FactorySim) -> void: s.torch[Vector2i(1, 1)] = true,
		"water": func(s: FactorySim) -> void: s.water[Vector2i(1, 1)] = 4,
		"research": func(s: FactorySim) -> void: s.research[&"automation"] = true,
		"sapling": func(s: FactorySim) -> void: s.sapling[Vector2i(1, 1)] = 7,
		"world seed": func(s: FactorySim) -> void: s.world_seed = 4242,
		"ledger": func(s: FactorySim) -> void: s.total_produced[&"ore"] = 9,
		"machine facing": func(s: FactorySim) -> void: s.machines[0].facing = -1,
		"machine filter": func(s: FactorySim) -> void: s.machines[0].filter = &"ore",
		"machine mode": func(s: FactorySim) -> void: s.machines[0].mode = 2,
	}
	for probe_name: String in probes:
		var s: FactorySim = _build_sim()
		(probes[probe_name] as Callable).call(s)
		_check(_state_signature(s) != base, "canary sees %s" % probe_name)


## Sanity: the chain actually produces ingots, and the recipe ratio holds (2 ore per ingot).
func _test_production() -> void:
	print("- production sanity")
	var sim: FactorySim = _build_sim()
	for _i: int in 400:
		sim.tick()
	var ingots: int = int(sim.sink.get(&"ingot", 0))
	var consumed_ore: int = int(sim.total_consumed.get(&"ore", 0))
	_check(ingots > 0, "produced ingots (%d after 400 ticks)" % ingots)
	_check(ingots * 2 == consumed_ore, "2 ore per ingot (ingots=%d, consumed_ore=%d)" % [ingots, consumed_ore])


## production_rate: the X/min legibility read off the tick-driven ring buffer. A lone vent makes
## 1 ore/s (mine_ore time=1.0) → the rate must settle near 60/min; unknown items read 0; a fresh
## sim (no history) reads 0. Derived bookkeeping only — asserts it never perturbs conservation.
func _test_production_rate() -> void:
	print("- production rate (X/min)")
	var vent_def: MachineDef = load("res://src/data/machines/ore_vent.tres")
	var sim: FactorySim = FactorySim.new()
	_check(sim.production_rate(&"ore") == 0.0, "no history -> rate 0")
	sim.place_machine(vent_def, Vector2i(6, 0))
	for _i: int in 200:                                   # 10s of steady 1 ore/s production
		sim.tick()
	var rate: float = sim.production_rate(&"ore")
	_check(absf(rate - 60.0) < 10.0, "steady vent reads ~60 ore/min (got %.1f)" % rate)
	_check(sim.production_rate(&"mystery") == 0.0, "unknown item -> rate 0")
	var tops: Array[Dictionary] = sim.production_rates()
	_check(tops.size() == 1 and tops[0]["item"] == &"ore", "production_rates lists the one flowing item")
	var made: int = int(sim.total_produced.get(&"ore", 0))
	var present: int = _items_present(sim, &"ore")
	_check(made == present, "rate sampling is conservation-neutral (made=%d present=%d)" % [made, present])


## machine_census: the production dashboard's factory-at-a-glance read. Two vents + one processor →
## the census tallies 2 machine TYPES, 3 machines total (== grid.size()), and the vents (always
## producing) read as working. A pure read: it must not perturb conservation.
func _test_machine_census() -> void:
	print("- machine census (dashboard)")
	var vent_def: MachineDef = load("res://src/data/machines/ore_vent.tres")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	var sim: FactorySim = FactorySim.new()
	_check(sim.machine_census().is_empty(), "empty world -> no census")
	sim.place_machine(vent_def, Vector2i(6, 0))
	sim.place_machine(vent_def, Vector2i(8, 0))
	sim.place_machine(proc_def, Vector2i(6, 3))
	for _i: int in 60:
		sim.tick()
	var census: Array[Dictionary] = sim.machine_census()
	var total: int = 0
	var vent_row: Dictionary = {}
	for row: Dictionary in census:
		total += int(row["count"])
		if row["id"] == vent_def.id:
			vent_row = row
	_check(census.size() == 2, "two machine TYPES tallied (got %d)" % census.size())
	_check(total == sim.grid.size() and total == 3, "census total == grid.size() == 3 (got %d)" % total)
	_check(int(vent_row.get("count", 0)) == 2, "two vents counted (got %d)" % int(vent_row.get("count", 0)))
	_check(int(vent_row.get("working", 0)) == 2, "both vents read WORKING (got %d)" % int(vent_row.get("working", 0)))
	_check(census[0]["id"] == vent_def.id, "sorted most-numerous-first (vents lead)")


## machine_problems: the alert stack's data. A generator with no coal reads no_fuel → it's an ALERT; a
## steadily-producing vent is NOT (working machines never alert); starvation (no_input) is excluded.
func _test_machine_problems() -> void:
	print("- machine problems (alerts)")
	var vent_def: MachineDef = load("res://src/data/machines/ore_vent.tres")
	var gen_def: MachineDef = load("res://src/data/machines/generator.tres")
	var sim: FactorySim = FactorySim.new()
	_check(sim.machine_problems().is_empty(), "healthy world -> no alerts")
	sim.place_machine(vent_def, Vector2i(4, 0))               # always working -> must NOT alert
	sim.place_machine(gen_def, Vector2i(8, 0))                # no coal -> no_fuel -> an alert
	sim.place_machine(gen_def, Vector2i(10, 0))               # second starving generator -> grouped
	for _i: int in 5:
		sim.tick()
	var probs: Array[Dictionary] = sim.machine_problems()
	_check(probs.size() == 1, "one grouped alert (both generators, one row) — got %d" % probs.size())
	if probs.size() == 1:
		_check(probs[0]["id"] == gen_def.id and probs[0]["status"] == &"no_fuel", "the alert is generator/no_fuel")
		_check(int(probs[0]["count"]) == 2, "both starving generators counted (got %d)" % int(probs[0]["count"]))
		_check(sim.grid.has(probs[0]["cell"]), "carries a real representative cell to ping")


## A splitter divides its incoming ore between two columns. Down-branch ore falls clear to the
## sink as raw ore; right-branch ore lands in a processor and becomes ingots. Seeing BOTH ore and
## ingots in the sink proves both branches carry items; the down-count being ~half proves it
## actually splits (not silently all-down). Plus conservation must still hold with a router inline.
func _test_splitter() -> void:
	print("- splitter routing")
	var vent_def: MachineDef = load("res://src/data/machines/ore_vent.tres")
	var split_def: MachineDef = load("res://src/data/machines/splitter.tres")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	var sim: FactorySim = FactorySim.new()
	sim.place_machine(vent_def, Vector2i(6, 0))      # source
	sim.place_machine(split_def, Vector2i(6, 2))     # router
	sim.place_machine(proc_def, Vector2i(7, 4))      # catches ONLY the right branch
	for _i: int in 600:
		sim.tick()
	var ore_to_sink: int = int(sim.sink.get(&"ore", 0))      # down branch (col 6, clear to floor)
	var ingots: int = int(sim.sink.get(&"ingot", 0))         # right branch (col 7 processor)
	_check(ore_to_sink > 0, "down branch delivered raw ore to the sink (%d)" % ore_to_sink)
	_check(ingots > 0, "right branch fed the processor (ingots=%d)" % ingots)
	# Total ore created ~ ore-down + 2*ingots (+ small in-flight). Down share should be ~half, so
	# assert it is neither ~0 (all-right) nor ~all (no split). Wide bounds: just prove it splits.
	var produced_ore: int = int(sim.total_produced.get(&"ore", 0))
	_check(ore_to_sink >= produced_ore / 4 and ore_to_sink <= produced_ore * 3 / 4,
		"split is roughly even (down=%d of produced=%d)" % [ore_to_sink, produced_ore])
	for item: StringName in [&"ore", &"ingot"]:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present == net, "%s conserved through splitter (present=%d, net=%d)" % [item, present, net])
	# Direct ratio SET (FABLE_50 #32 — the config panel's clickable chips; R still cycles).
	var sm: MachineState = sim.machine_at(Vector2i(6, 2))
	_check(sim.set_split_mode(Vector2i(6, 2), 2) != "", "the panel can set a splitter's ratio directly")
	_check(sm.mode == 2, "…and the mode landed (1:2 RIGHT)")
	sim.set_split_mode(Vector2i(6, 2), 0)
	sim.set_split_mode(Vector2i(6, 2), 99)
	_check(sm.mode == 2, "an out-of-range mode clamps to a real pattern")
	_check(sim.set_split_mode(Vector2i(7, 4), 1) == "", "a non-splitter refuses the ratio knob")
	# Determinism with a router in the chain.
	var a: FactorySim = FactorySim.new()
	var b: FactorySim = FactorySim.new()
	for s: FactorySim in [a, b]:
		s.place_machine(vent_def, Vector2i(6, 0))
		s.place_machine(split_def, Vector2i(6, 2))
		s.place_machine(proc_def, Vector2i(7, 4))
	for _i: int in 200:
		a.tick()
		b.tick()
	_check(_state_signature(a) == _state_signature(b), "splitter chain is deterministic")


## Terrain is authoritative world state: solid cells block placement, mining clears them, and the
## avatar never touches this (it only reads is_solid). Groundwork for the embodied body (P2·S1a).
func _test_terrain() -> void:
	print("- terrain")
	var sim: FactorySim = FactorySim.new()
	var vent_def: MachineDef = load("res://src/data/machines/ore_vent.tres")
	sim.set_solid(Vector2i(3, 3))  # default &"earth"
	_check(sim.is_solid(Vector2i(3, 3)), "set_solid marks a cell solid")
	_check(sim.material_at(Vector2i(3, 3)) == &"earth", "default material is earth")
	_check(not sim.is_solid(Vector2i(4, 3)), "neighbouring cell stays open")
	_check(sim.place_machine(vent_def, Vector2i(3, 3)) == null, "cannot place a machine in solid earth")
	_check(sim.mine(Vector2i(3, 3)) == &"earth", "mining earth returns the earth material")
	_check(not sim.is_solid(Vector2i(3, 3)), "mined cell is now open")
	_check(sim.place_machine(vent_def, Vector2i(3, 3)) != null, "can place after mining out the earth")
	_check(sim.mine(Vector2i(5, 5)) == &"", "mining a non-solid cell yields nothing")
	_check(not sim.is_solid(Vector2i(-1, 0)), "out-of-bounds is never solid")


## The SHARED surface silhouette (sim.surface_row / sim.ramp_dir) the renderer draws and the avatar
## walks. Locks in: the slope is terrain-topology only, material-independent, ONE tile = a ramp, taller
## = a wall, and — the bug this whole slice fixes — a placed MACHINE never alters the silhouette (no
## phantom invisible diagonal). One authority → seen slope == walked slope, by construction.
func _test_surface_silhouette() -> void:
	print("- surface silhouette")
	var sim: FactorySim = FactorySim.new()
	# A flat run at row 10, with one column (5) raised a single tile, and column 8 raised TWO tiles.
	for col: int in range(3, 12):
		sim.set_solid(Vector2i(col, 10), &"earth")
	sim.set_solid(Vector2i(5, 9), &"earth")               # +1 step
	sim.set_solid(Vector2i(8, 9), &"stone")               # +2 tower (with the one below)
	sim.set_solid(Vector2i(8, 8), &"stone")
	_check(sim.surface_row(4) == 10, "surface_row finds the exposed top")
	_check(sim.surface_row(5) == 9, "surface_row tracks a raised column")
	_check(sim.surface_row(99) == FactorySim.GRID_ROWS, "an empty column has no surface")
	# Column 4 sits one tile below its right neighbour (col 5) → ramp rising to the RIGHT.
	_check(sim.ramp_dir(4) == 1, "a 1-tile step right reads as a rightward ramp")
	# Column 6 sits one tile below its left neighbour (col 5) → ramp rising to the LEFT.
	_check(sim.ramp_dir(6) == -1, "a 1-tile step left reads as a leftward ramp")
	_check(sim.ramp_dir(3) == 0, "flat ground has no ramp")
	# Stone slopes exactly like earth — geometry is material-independent (bug #1).
	_check(sim.surface_row(8) == 8 and sim.ramp_dir(7) == 0,
		"a 2-tile step is a WALL, not a ramp (only single steps slope)")
	# THE phantom-ramp killer: drop a machine onto FLAT ground (col 10, both neighbours level); the
	# silhouette must NOT move — no raised surface, no diagonal — so you bump the box, never glide it (bug #3).
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	_check(sim.ramp_dir(10) == 0, "flat ground reads flat before any machine")
	sim.place_machine(proc_def, Vector2i(10, 9))           # a machine standing on the flat row-10 ground
	_check(sim.surface_row(10) == 10, "a placed machine does NOT raise the surface silhouette")
	_check(sim.ramp_dir(10) == 0, "a placed machine casts NO phantom ramp (it's a box you bump, not a hill)")


## Mining an ore vein fills the pack and is conservation-safe; depositing hands it to a machine.
func _test_mining_and_deposit() -> void:
	print("- mining + deposit")
	var sim: FactorySim = FactorySim.new()
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	sim.set_solid(Vector2i(2, 2), &"ore")
	sim.set_solid(Vector2i(2, 3), &"ore")
	_check(sim.mine(Vector2i(2, 2)) == &"ore", "mining a vein returns ore")
	var after_one: int = int(sim.inventory.get(&"ore", 0))
	_check(after_one >= 3 and after_one <= 6, "mining a vein drops a 3-6 loose burst into the pack (got %d)" % after_one)
	sim.mine(Vector2i(2, 3))
	var carried: int = int(sim.inventory.get(&"ore", 0))
	_check(carried > after_one, "the pack accumulates across mines (%d)" % carried)
	_check(_items_present(sim, &"ore") == int(sim.total_produced.get(&"ore", 0)), "mined ore conserved")
	# Deposit into a processor and let it smelt — the by-hand loop drives production.
	var proc: MachineState = sim.place_machine(proc_def, Vector2i(2, 5))
	_check(sim.deposit(Vector2i(2, 5), &"ore", carried) == carried, "deposited all carried ore into the processor")
	_check(sim.inventory.is_empty(), "pack emptied after depositing all")
	_check(int(proc.input_buffer.get(&"ore", 0)) == carried, "processor received the ore")
	for _i: int in 200:
		sim.tick()
	_check(int(sim.sink.get(&"ingot", 0)) >= 1, "hand-fed ore forged at least one ingot (%d)" % int(sim.sink.get(&"ingot", 0)))
	for item: StringName in [&"ore", &"ingot"]:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present == net, "%s conserved across the by-hand loop (present=%d, net=%d)" % [item, present, net])
	_check(sim.deposit(Vector2i(2, 5), &"ore", 1) == 0, "cannot deposit ore you don't carry")


## S3 — a chain BUILT by hand. The player only ever calls place_machine / deposit / remove_machine,
## so building a splitter + two processors, digging a stock of ore, and hand-feeding the splitter
## must produce ingots down BOTH branches and conserve — guarding the chain the embodied body
## assembles. (S3 adds no sim code: place/remove already exist, so this exercises that same path.)
func _test_hand_built_chain() -> void:
	print("- hand-built chain")
	var split_def: MachineDef = load("res://src/data/machines/splitter.tres")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	var sim: FactorySim = FactorySim.new()
	_check(sim.place_machine(split_def, Vector2i(6, 2)) != null, "placed a splitter by hand")
	_check(sim.place_machine(proc_def, Vector2i(6, 4)) != null, "placed a processor under the down branch")
	_check(sim.place_machine(proc_def, Vector2i(7, 4)) != null, "placed a processor under the right branch")
	for v: int in 8:  # dig a stock of ore into the pack (each block a 3-6 burst)
		sim.set_solid(Vector2i(0, v), &"ore")
		sim.mine(Vector2i(0, v))
	var stock: int = int(sim.inventory.get(&"ore", 0))
	_check(stock >= 8, "dug a stock of ore into the pack (%d)" % stock)
	_check(sim.deposit(Vector2i(6, 2), &"ore", stock) == stock, "hand-fed all the ore into the splitter")
	for _i: int in 200:
		sim.tick()
	_check(int(sim.sink.get(&"ingot", 0)) > 0, "the hand-built chain forged ingots (%d)" % int(sim.sink.get(&"ingot", 0)))
	for item: StringName in [&"ore", &"ingot"]:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present == net, "%s conserved in the hand-built chain (present=%d, net=%d)" % [item, present, net])
	sim.remove_machine(Vector2i(7, 4))  # raw removal (demolish) — buffered items are destroyed, not salvaged
	_check(sim.machine_at(Vector2i(7, 4)) == null, "picked the processor back up (cell is buildable again)")
	# CONSERVATION survives a raw remove_machine: the destroyed buffer is credited to total_consumed, so
	# present == produced - consumed still holds (the old bug leaked the buffer here).
	for item: StringName in [&"ore", &"ingot"]:
		var present2: int = _items_present(sim, item)
		var net2: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present2 == net2, "%s conserved after raw removal (present=%d, net=%d)" % [item, present2, net2])
	# pickup_machine SALVAGES instead of destroying: the held items come back to the pack, none consumed.
	var s2: FactorySim = FactorySim.new()
	var proc_def2: MachineDef = load("res://src/data/machines/processor.tres")
	var held: MachineState = s2.place_machine(proc_def2, Vector2i(3, 3))
	held.input_buffer[&"ore"] = 4
	s2.total_produced[&"ore"] = 4                      # pretend those 4 ore were produced into it
	_check(s2.pickup_machine(Vector2i(3, 3)), "picked up a machine holding ore")
	_check(int(s2.inventory.get(&"ore", 0)) == 4, "the 4 held ore were salvaged into the pack")
	_check(int(s2.total_consumed.get(&"ore", 0)) == 0, "salvage consumed nothing (pickup ≠ destroy)")
	_check(_items_present(s2, &"ore") == 4 and int(s2.total_produced.get(&"ore", 0)) == 4, "salvaged ore conserved")


## The carried pack surfaces as an ordered slot list for the hotbar — one stack per item type, in
## stable insertion order, counts correct. Pure read; the inventory dict stays the source of truth.
func _test_inventory_slots() -> void:
	print("- inventory slots")
	var sim: FactorySim = FactorySim.new()
	_check(sim.inventory_slots().is_empty(), "empty pack = no slots")
	sim.set_solid(Vector2i(1, 1), &"ore")
	sim.set_solid(Vector2i(1, 2), &"ore")
	sim.mine(Vector2i(1, 1))
	sim.mine(Vector2i(1, 2))
	var carried: int = int(sim.inventory.get(&"ore", 0))
	var slots: Array[Dictionary] = sim.inventory_slots()
	_check(slots.size() == 1, "two mined ore blocks = one stack")
	_check(slots[0]["item"] == &"ore" and int(slots[0]["count"]) == carried, "the ore stack shows the carried count (%d)" % carried)
	sim.inventory[&"ingot"] = 3  # a second item type appears as a second slot, after ore
	slots = sim.inventory_slots()
	_check(slots.size() == 2, "second item type = second slot")
	_check(slots[1]["item"] == &"ingot" and int(slots[1]["count"]) == 3, "insertion order preserved (ore, then ingot)")


## A machine SPITS its product down the column; with a solid floor below, it lands as a physical
## ground pile (not the void sink); the player collects the pile into the pack. Conservation holds
## across spit → land → collect.
func _test_spit_and_collect() -> void:
	print("- spit + collect")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	var sim: FactorySim = FactorySim.new()
	sim.set_solid(Vector2i(3, 6), &"earth")            # a floor two cells below the forge
	sim.place_machine(proc_def, Vector2i(3, 3))
	sim.set_solid(Vector2i(0, 0), &"ore")              # mine 2 ore into the pack (real loop)
	sim.set_solid(Vector2i(0, 1), &"ore")
	sim.mine(Vector2i(0, 0))
	sim.mine(Vector2i(0, 1))
	_check(sim.deposit(Vector2i(3, 3), &"ore", 2) == 2, "hand-fed 2 ore into the forge")
	for _i: int in 80:
		sim.tick()
	var rest := Vector2i(3, 5)                          # on top of the row-6 floor
	_check(sim.sink.is_empty(), "nothing fell into the void sink (a floor caught it)")
	_check(int((sim.ground.get(rest, {}) as Dictionary).get(&"ingot", 0)) == 1, "one ingot rests on the floor")
	_check(sim.collect_ground(rest) == 1, "collecting the pile returns 1 item")
	_check(int(sim.inventory.get(&"ingot", 0)) == 1, "collected ingot is now in the pack")
	_check(sim.ground.is_empty(), "the pile is gone after collecting")
	for item: StringName in [&"ore", &"ingot"]:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present == net, "%s conserved across spit+collect (present=%d, net=%d)" % [item, present, net])


## Items that land on a 45° SURFACE ramp roll downhill to the base — nothing perches on a slope
## (playtest #76). Interior floors (below the surface) are square and do NOT roll.
func _test_slope_item_flow() -> void:
	print("- slope item flow")
	var sim: FactorySim = FactorySim.new()
	# A staircase DESCENDING to the right: surface rows 5,6,7,8 for cols 2..5, then flat (8) for 6,7.
	var tops: Dictionary = {2: 5, 3: 6, 4: 7, 5: 8, 6: 8, 7: 8}
	for col: int in tops:
		for row: int in range(int(tops[col]), FactorySim.GRID_ROWS):
			sim.set_solid(Vector2i(col, row), &"earth")
	sim.inventory[&"ore"] = 3
	sim.total_produced[&"ore"] = 3
	# Drop onto the TOP of the ramp (col 3). It should roll to the flat base — the last column that still
	# descends is col 5 (col 6 is level), so it settles resting on col 5's surface (row 7).
	sim.drop_item(Vector2i(3, 0), &"ore", 1)
	_check(sim.last_drop_landing == Vector2i(5, 7),
		"item on a down-right ramp rolls to the base (got %s)" % str(sim.last_drop_landing))
	_check(int((sim.ground.get(Vector2i(5, 7), {}) as Dictionary).get(&"ore", 0)) == 1,
		"the rolled item rests at the base of the slope")
	_check(not sim.ground.has(Vector2i(3, 5)), "nothing is left perched on the ramp top")

	# FLAT ground: an item does not move.
	sim.drop_item(Vector2i(7, 0), &"ore", 1)
	_check(sim.last_drop_landing == Vector2i(7, 7), "an item on flat ground stays put")

	# INTERIOR floor guard: a ramp on the surface, but a deep dug shaft with an interior floor far below.
	# An item dropped into the shaft rests on the interior floor — it must NOT use the outdoor slope.
	var sim2: FactorySim = FactorySim.new()
	for col: int in tops:                              # same surface staircase
		sim2.set_solid(Vector2i(col, int(tops[col])), &"earth")
	sim2.set_solid(Vector2i(3, 20), &"earth")          # an interior floor deep under col 3 (shaft open above)
	sim2.inventory[&"ore"] = 1
	sim2.total_produced[&"ore"] = 1
	sim2.drop_item(Vector2i(3, 10), &"ore", 1)         # dropped INTO the shaft, below the surface
	_check(sim2.last_drop_landing == Vector2i(3, 19),
		"an item on an interior floor does NOT roll along the outdoor slope (got %s)"
		% str(sim2.last_drop_landing))

	# Conservation across the rolls.
	var present: int = _items_present(sim, &"ore")
	var net: int = int(sim.total_produced.get(&"ore", 0)) - int(sim.total_consumed.get(&"ore", 0))
	_check(present == net, "ore conserved across slope rolls (present=%d, net=%d)" % [present, net])


## Gravity for resting product: a pile sitting on a solid floor must FALL when that floor is removed —
## mining the block under a pile re-drops it to the next floor below (and into a machine if one is there),
## never leaving it hanging. Conservation holds across the re-settle (items only move).
func _test_pile_falls_when_floor_mined() -> void:
	print("- pile falls when floor mined")
	var sim: FactorySim = FactorySim.new()
	# A two-deep floor stack: a pile rests on the upper block; a lower block sits beneath it.
	sim.set_solid(Vector2i(2, 5), &"earth")            # the block the pile rests on
	sim.set_solid(Vector2i(2, 7), &"earth")            # the floor below it (the pile's next landing)
	sim.ground[Vector2i(2, 4)] = {&"ingot": 3}         # the resting pile, on top of the (2,5) block
	sim.total_produced[&"ingot"] = 3                   # account for the injected pile so conservation checks
	_check(sim.mine(Vector2i(2, 5)) == &"earth", "mined the block under the pile")
	_check(not sim.ground.has(Vector2i(2, 4)), "the pile no longer hangs where its floor was")
	var landed := Vector2i(2, 6)                        # on top of the (2,7) floor
	_check(int((sim.ground.get(landed, {}) as Dictionary).get(&"ingot", 0)) == 3, "the pile fell to the floor below")
	_check(not sim.flow_events.is_empty(), "a flow_event was emitted so the fall animates")
	# Mining INTO a machine: a pile above a freshly-dug cell with a machine below feeds the machine.
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	sim.place_machine(proc_def, Vector2i(5, 8))
	sim.set_solid(Vector2i(5, 4), &"earth")
	sim.ground[Vector2i(5, 3)] = {&"ore": 2}
	sim.total_produced[&"ore"] = 2
	sim.mine(Vector2i(5, 4))
	var mach: MachineState = sim.machine_at(Vector2i(5, 8))
	_check(int(mach.input_buffer.get(&"ore", 0)) == 2, "a pile falling onto a machine feeds its input")
	for item: StringName in [&"ingot", &"ore"]:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present == net, "%s conserved across the re-settle (present=%d, net=%d)" % [item, present, net])


## Factorio-style building: craft a machine ITEM from carried ingots (spending them, counted as
## consumed), place it from the pack (consuming the item), and pick it back up (returning the item).
func _test_craft_and_build() -> void:
	print("- craft + build")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	var sim: FactorySim = FactorySim.new()
	sim.inventory[&"ingot"] = 5                         # forged elsewhere; inject for a focused test
	sim.total_produced[&"ingot"] = 5                    # account so conservation is checkable
	_check(sim.craft(proc_def), "craft a processor with enough ingots")
	_check(int(sim.inventory.get(&"ingot", 0)) == 2, "crafting spent 3 ingots")
	_check(int(sim.inventory.get(&"processor", 0)) == 1, "a processor item is now in the pack")
	_check(int(sim.total_consumed.get(&"ingot", 0)) == 3, "spent ingots counted as consumed")
	_check(not sim.craft(proc_def), "cannot craft a second one (only 2 ingots left)")
	var built: MachineState = sim.build_from_pack(proc_def, Vector2i(4, 4))
	_check(built != null and sim.machine_at(Vector2i(4, 4)) != null, "placed the processor from the pack")
	_check(int(sim.inventory.get(&"processor", 0)) == 0, "placing consumed the processor item")
	_check(sim.build_from_pack(proc_def, Vector2i(5, 5)) == null, "cannot place a machine you don't carry")
	# Pick up a machine that is HOLDING ore -> the ore is salvaged back, not destroyed (conservation).
	sim.set_solid(Vector2i(9, 0), &"ore")
	sim.set_solid(Vector2i(9, 1), &"ore")
	sim.mine(Vector2i(9, 0))
	sim.mine(Vector2i(9, 1))
	var held: int = int(sim.inventory.get(&"ore", 0))
	sim.deposit(Vector2i(4, 4), &"ore", held)
	_check(int(sim.inventory.get(&"ore", 0)) == 0, "ore handed into the machine left the pack")
	_check(sim.pickup_machine(Vector2i(4, 4)), "picked the machine back up")
	_check(int(sim.inventory.get(&"processor", 0)) == 1, "the machine item returned to the pack")
	_check(int(sim.inventory.get(&"ore", 0)) == held, "the machine's held ore was salvaged back to the pack (%d)" % held)
	# THE LEDGER IS TOTAL: the machine ITEM itself satisfies conservation through its whole life —
	# crafted (produced) → placed (consumed, not "present") → picked back up (produced again).
	for item: StringName in [&"ore", &"ingot", &"processor"]:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present == net, "%s conserved across craft+pickup (present=%d, net=%d)" % [item, present, net])


## The world-engine handshake: a generator produces a WorldData deterministically; the sim ingests
## it; mining carves a block but leaves its wall. Validates the gen↔sim contract independent of viz.
func _test_worldgen() -> void:
	print("- worldgen")
	var gen: WorldGen = HeightmapWorldGen.new()
	var a: WorldData = gen.generate(72, 40, 1337)
	var b: WorldData = gen.generate(72, 40, 1337)
	_check(a.blocks.size() > 0, "generated a non-empty world")
	_check(a.blocks == b.blocks, "same seed → identical blocks (deterministic)")
	var c: WorldData = gen.generate(72, 40, 99)
	_check(a.blocks != c.blocks, "a different seed → a different world (ore scatter varies)")
	# The stone smoke test: earth near the surface, stone deep down (richness via a new material id).
	var top: int = HeightmapWorldGen.FLAT_SURFACE_ROW
	_check(a.blocks.get(Vector2i(2, top)) == &"earth", "surface is earth")
	_check(a.blocks.get(Vector2i(2, top + HeightmapWorldGen.STONE_DEPTH + 2)) == &"stone",
		"deep cells are stone (a new material dropped into generation)")
	# The background WALL layer (Slice 3): walls behind every sub-surface cell, matching the rock zone.
	_check(a.walls.size() > 0 and a.walls == b.walls, "walls generated + deterministic")
	_check(a.walls.get(Vector2i(2, top)) == &"dirt_wall", "near-surface wall is dirt")
	_check(a.walls.get(Vector2i(2, top + HeightmapWorldGen.STONE_DEPTH + 2)) == &"stone_wall",
		"deep wall is stone")


	# Ingest + wall persistence (Slice 3): mining clears the block, keeps the wall.
	var sim: FactorySim = FactorySim.new()
	sim.load_world(a)
	_check(sim.is_solid(Vector2i(2, top)), "sim ingested the world (surface cell is solid)")
	sim.set_wall(Vector2i(2, top), &"stone_wall")
	sim.mine(Vector2i(2, top))
	_check(not sim.is_solid(Vector2i(2, top)), "mining cleared the block")
	_check(sim.wall_at(Vector2i(2, top)) == &"stone_wall", "the background wall survives mining the block")


## The RICHER generator: same WorldData contract, deterministic, but now with CAVES (carved cells
## that keep their wall, only below CAVE_MIN_DEPTH so the base stays solid) and DEPTH-BANDED ore
## (more ore deep than shallow — the "deeper = richer" pull). Still emits only known material ids, so
## the renderer is untouched.
func _test_layered_worldgen() -> void:
	print("- layered worldgen")
	var gen: WorldGen = LayeredWorldGen.new()
	# Measure on the REAL world size: solid≫cave is a full-world property, and a truncated 40-row slice is
	# disproportionately "deep" (its whole band sits in the low-threshold zone) so it over-reads cave.
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	var mid: int = rows / 2
	var a: WorldData = gen.generate(cols, rows, 1337)
	var b: WorldData = gen.generate(cols, rows, 1337)
	_check(a.blocks == b.blocks, "same seed → identical blocks (deterministic, caves + veins)")
	_check(gen.generate(cols, rows, 99).blocks != a.blocks, "a different seed → a different world")

	# CAVES: some sub-surface cells are carved OPEN (block gone) yet still have a wall behind them —
	# a Terraria carved room. And the near-surface base is untouched (caves only below CAVE_MIN_DEPTH).
	var carved: int = 0
	var carved_with_wall: int = 0
	var breached_base: int = 0
	var solid_below: int = 0
	var hm := HeightmapWorldGen.new()
	for col: int in cols:
		var top: int = hm._surface_row(col)
		for row: int in range(top, rows):
			var cell: Vector2i = Vector2i(col, row)
			if not a.blocks.has(cell) and a.walls.has(cell):
				carved += 1
				carved_with_wall += 1
				if row < top + LayeredWorldGen.CAVE_MIN_DEPTH:
					breached_base += 1
			elif row > top and a.blocks.has(cell):
				solid_below += 1
	_check(carved > 50, "caves carved open cells in the rock (%d)" % carved)
	_check(carved_with_wall == carved, "every carved cell kept its wall (Terraria room, not void)")
	_check(breached_base == 0, "no cave breached the near-surface base (stays solid by construction)")
	# DIG-YOUR-FACTORY (#107, PROGRESSION §10 / DESIGN_REVIEW F2): the underground must be SOLID-dominant —
	# you carve your factory INTO ore-rich rock; caves are the rarer opt-in punctuation, NOT the medium you
	# traverse (follow-the-cave). Guard the identity so a future gen change can't silently drift it back.
	var cave_frac: float = float(carved) / float(maxi(1, solid_below + carved))
	_check(cave_frac < 0.25, "solid >> cave: caves stay opt-in punctuation (cave=%.1f%% of below-surface)"
		% [cave_frac * 100.0])

	# DEPTH-BANDED ORE: count ore in the top half vs the bottom half of the sub-surface column band.
	var ore_shallow: int = 0
	var ore_deep: int = 0
	for cell: Vector2i in a.blocks:
		if a.blocks[cell] == &"ore":
			if cell.y < mid:
				ore_shallow += 1
			else:
				ore_deep += 1
	_check(ore_deep > ore_shallow, "ore is depth-banded: more deep than shallow (deep=%d, shallow=%d)"
		% [ore_deep, ore_shallow])

	# Still ingests cleanly through the same contract (carved cells load as not-solid, walls intact).
	var sim: FactorySim = FactorySim.new()
	sim.load_world(a)
	var probe: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in a.walls:
		if not a.blocks.has(cell):
			probe = cell
			break
	_check(probe.x >= 0, "found a carved cave cell to probe")
	_check(not sim.is_solid(probe), "a carved cave loads as open (not solid)")
	_check(sim.wall_at(probe) != &"", "the carved cave still shows its background wall")

	# --- AQUIFERS (L3, slice 3a): deep SEALED water pockets seeded into carved rock. ---
	_check(not a.water.is_empty(), "aquifers seeded some water (%d cells)" % a.water.size())
	var watered: int = 0
	var near_surface: int = 0
	var bad_level: int = 0
	var in_solid: int = 0
	var seal_lo: int = LayeredWorldGen.SEAL_TOP
	var seal_hi: int = LayeredWorldGen.SEAL_TOP + LayeredWorldGen.SEAL_ROWS - 1
	for wc: Vector2i in a.water:
		watered += 1
		var lvl: int = int(a.water[wc])
		if lvl < 1 or lvl > FactorySim.WATER_MAX:
			bad_level += 1
		# DEEP + BASE-SAFE: every watered cell sits below its column's base-safe band, never near the surface.
		if wc.y < hm._surface_row(wc.x) + LayeredWorldGen.CAVE_MIN_DEPTH:
			near_surface += 1
		# NO watered cell is also solid rock (water only lives in the cells the aquifer pass carved open).
		if a.blocks.has(wc):
			in_solid += 1
		# ...and never inside the inviolate seal band.
		if wc.y >= seal_lo and wc.y <= seal_hi:
			in_solid += 1
	_check(watered > 0, "aquifer water exists (%d watered cells)" % watered)
	_check(near_surface == 0, "no aquifer water in the base-safe band (all deep, base stays dry)")
	_check(bad_level == 0, "every water level is valid (1..WATER_MAX)")
	_check(in_solid == 0, "no watered cell is solid or in the seal band (water only in carved cells)")
	# DETERMINISM: same seed → identical water grid (seeded rng only, no time/global random).
	_check(a.water == b.water, "same seed → identical aquifer water (deterministic)")
	# INGEST: the sim loads the water and it survives the contract (matches the generated grid).
	_check(sim.total_water() > 0, "load_world ingested the aquifer water (total=%d)" % sim.total_water())
	var water_match: bool = sim.water.size() == a.water.size()
	if water_match:
		for wc2: Vector2i in a.water:
			if sim.water_at(wc2) != int(a.water[wc2]):
				water_match = false
				break
	_check(water_match, "sim.water matches the generated world's water grid exactly")


## HORIZONTAL ore pull (the frontier fix): ore richness varies across X at a fixed depth, with the richest
## bands AWAY from spawn — so the cheapest fresh vein isn't always straight down the spawn column. Asserts
## the distribution is NOT uniform across x (there exist frontier x-regions statistically richer than the
## spawn region), AND that the horizontal term is fully deterministic (same seed → identical world).
func _test_horizontal_ore_pull() -> void:
	print("- horizontal ore pull (frontier richness)")
	var gen := LayeredWorldGen.new()
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	var world: WorldData = gen.generate(cols, rows, 20260807)

	# DETERMINISM: the whole world (blocks + amounts) reproduces bit-for-bit, so the new horizontal field
	# introduced no time/global-random dependence.
	var again: WorldData = gen.generate(cols, rows, 20260807)
	_check(world.blocks == again.blocks, "same seed → identical blocks (horizontal field is deterministic)")
	_check(world.amounts == again.amounts, "same seed → identical per-cell deposits (deterministic richness)")

	# Sum ore MASS (deposit richness) per column over a FIXED depth band, so any variation is purely
	# horizontal (depth is held constant across the comparison). Above the seal so all cells are real ore rock.
	var band_top: int = 30
	var band_bot: int = mini(LayeredWorldGen.SEAL_TOP, rows)
	var col_mass: PackedInt32Array = PackedInt32Array()
	col_mass.resize(cols)
	for cell: Vector2i in world.blocks:
		var m: StringName = world.blocks[cell]
		if (m == &"ore" or m == &"rich_ore" or m == &"coal") and cell.y >= band_top and cell.y < band_bot:
			col_mass[cell.x] += int(world.amounts.get(cell, 1))

	# Region masses: a spawn-centred window vs the two frontier edges (away from spawn on either side).
	var spawn: int = LayeredWorldGen.SPAWN_COL
	var half: int = 8
	var spawn_mass: int = _region_mass(col_mass, spawn - half, spawn + half)
	var left_mass: int = _region_mass(col_mass, 0, 2 * half)                     # far-left frontier
	var right_mass: int = _region_mass(col_mass, cols - 2 * half, cols)          # far-right frontier
	var frontier_mass: int = maxi(left_mass, right_mass)

	# NOT uniform: at a fixed depth some x-regions carry more ore than the spawn region — the frontier is
	# meaningfully richer (the "you must leave spawn" pull). Guard against a degenerate all-empty band.
	_check(spawn_mass + frontier_mass > 0, "the fixed depth band actually contains ore (spawn=%d, frontier=%d)"
		% [spawn_mass, frontier_mass])
	_check(frontier_mass > spawn_mass, "a frontier x-region is richer than spawn at a fixed depth (frontier=%d > spawn=%d)"
		% [frontier_mass, spawn_mass])

	# And the variation is a real spread, not one lucky cell: the richest window clears the spawn window by a
	# clear margin (the field's design — bands differ by up to ~2×HORIZONTAL_STRENGTH).
	_check(frontier_mass >= int(round(float(maxi(1, spawn_mass)) * 1.15)),
		"the frontier richness edge is a meaningful margin, not noise (%.2fx spawn)"
		% (float(frontier_mass) / float(maxi(1, spawn_mass))))

	# The field respects its own bound (subtlety guarantee): every column multiplier is within
	# [1-STRENGTH, 1+STRENGTH], so near-spawn ore is thinned but never nuked.
	var hfield: PackedFloat32Array = gen._horizontal_field(cols, 20260807)
	var in_bound: bool = true
	for c: int in cols:
		if hfield[c] < 1.0 - LayeredWorldGen.HORIZONTAL_STRENGTH - 0.0001 \
				or hfield[c] > 1.0 + LayeredWorldGen.HORIZONTAL_STRENGTH + 0.0001:
			in_bound = false
	_check(in_bound, "the horizontal multiplier stays bounded by HORIZONTAL_STRENGTH (subtle, never nukes spawn)")


## Sum a slice [lo, hi) of a per-column mass array, clamped to bounds. (test helper)
func _region_mass(col_mass: PackedInt32Array, lo: int, hi: int) -> int:
	var total: int = 0
	for c: int in range(maxi(0, lo), mini(col_mass.size(), hi)):
		total += col_mass[c]
	return total


## The LIFT carries items UP its column (the paid inverse of gravity), rate-limited by
## LIFT_THROUGHPUT, conserving items — they arrive at the top of the shaft.
func _test_lift() -> void:
	print("- lift")
	var lift_def: MachineDef = load("res://src/data/machines/lift.tres")
	var sim: FactorySim = FactorySim.new()
	var lift: MachineState = sim.place_machine(lift_def, Vector2i(5, 10))
	_check(lift != null and lift.def.behavior == &"lift", "placed a lift")
	lift.input_buffer[&"ore"] = 5                       # 5 ore fell onto the lift
	_check(_items_present(sim, &"ore") == 5, "5 ore present before lifting")
	sim.tick()
	_check(int(lift.input_buffer.get(&"ore", 0)) == 5 - FactorySim.LIFT_THROUGHPUT,
		"lift carries only LIFT_THROUGHPUT/tick (the rest is backlog = the cost)")
	for _i: int in 8:
		sim.tick()
	_check(lift.input_buffer.is_empty() and lift.output_buffer.is_empty(), "lift drained upward")
	var pile: Dictionary = sim.ground.get(Vector2i(5, 0), {})
	_check(int(pile.get(&"ore", 0)) == 5, "all 5 ore arrived at the TOP of the shaft")
	_check(_items_present(sim, &"ore") == 5, "ore conserved across lifting (present=5)")


## Finite ore deposits + the Drill (docs/MINING.md). A deposit cell holds a POOL: hand-mining drains it
## a unit at a time, clearing the block only when empty (a cell with no pool = 1 = today's one-hit). A
## placed Drill bores the vein straight below it, spitting ore down the column, and STOPS when the vein
## is exhausted — proving extraction is finite (no infinite-ore machine).
func _test_finite_deposit_and_drill() -> void:
	print("- ore mining + drill (boring model)")
	# Hand-mining an ore BLOCK (docs/MINING.md): ONE strike clears the whole block and drops a 3-6 loose BURST
	# into the pack — a quick, inefficient grab (the vein's larger latent yield is the DRILL's job, not the hand's).
	var sim: FactorySim = FactorySim.new()
	var cell := Vector2i(4, 6)
	sim.set_solid(cell, &"ore")
	sim.deposits[cell] = 12                             # the vein's drill-yield (discarded when hand-mined)
	var mat: StringName = sim.mine(cell)
	var burst: int = int(sim.inventory.get(&"ore", 0))
	_check(mat == &"ore" and not sim.is_solid(cell), "one strike breaks the whole ore block")
	_check(burst >= 3 and burst <= 6, "hand-mining drops a 3-6 loose burst (got %d)" % burst)
	_check(sim.ore_deposit_at(cell) == 0, "a hand-mined (now-open) cell is no vein — no confusing cavity left behind")
	_check(_items_present(sim, &"ore") == int(sim.total_produced.get(&"ore", 0)), "burst ore conserved")
	# ore_deposit_at reads the richness of a SOLID visible vein (for the hover), defaulting when unseeded.
	var solid_small := Vector2i(9, 9)
	sim.set_solid(solid_small, &"ore"); sim.deposits[solid_small] = 4
	_check(sim.ore_deposit_at(solid_small) == 4, "a solid vein reads its remaining richness (for the hover)")
	var bare := Vector2i(11, 9)                          # an ore cell with NO seeded richness
	sim.set_solid(bare, &"ore")
	_check(sim.ore_deposit_at(bare) == FactorySim.DEFAULT_ORE_DEPOSIT, "an unseeded solid ore cell reads the default richness")

	# The DRILL sits ABOVE a solid vein, bores DOWN into it, and pulls it to a forge/floor, stopping when dry.
	var drill_def: MachineDef = load("res://src/data/machines/drill.tres")
	var s2: FactorySim = FactorySim.new()
	var ore := Vector2i(8, 6)
	s2.set_solid(ore, &"ore"); s2.deposits[ore] = 14
	s2.set_solid(Vector2i(8, 8), &"stone")             # floor below the vein: catches the spat ore
	var pool: int = s2.ore_deposit_at(ore)
	_check(pool == 14, "the solid vein carries its full drill-yield (%d)" % pool)
	var drill: MachineState = s2.place_machine(drill_def, Vector2i(8, 5))   # OPEN cell above the vein
	_check(drill != null and drill.def.behavior == &"drill", "placed a drill above the vein")
	_check(s2.drill_target(drill.cell) == ore, "the drill targets the solid vein below it")
	drill.input_buffer[&"coal"] = pool                 # fuel it generously (the drill burns coal to run)
	for _i: int in 100 + pool * 25:                    # plenty of ticks to drain the whole pool
		s2.tick()
	_check(not s2.is_solid(ore), "the drill bored the vein cell out (carved the shaft)")
	_check(int(s2.total_produced.get(&"ore", 0)) == pool, "total ore = the drilled vein yield (%d)" % pool)
	_check(_items_present(s2, &"ore") == int(s2.total_produced.get(&"ore", 0)), "all ore conserved through the drill")
	var before: int = int(s2.total_produced.get(&"ore", 0))
	for _i: int in 40:
		s2.tick()
	_check(int(s2.total_produced.get(&"ore", 0)) == before, "an exhausted drill stops producing (extraction is finite)")

	# FORGIVING PLACEMENT: a drill dropped in the shaft high ABOVE a vein (not right on top) still bores
	# straight down to it — you don't have to hit the exact cell.
	var s3: FactorySim = FactorySim.new()
	var vein := Vector2i(6, 10)
	s3.set_solid(vein, &"ore"); s3.deposits[vein] = 8
	s3.set_solid(Vector2i(6, 13), &"stone")            # floor below the vein
	var above := Vector2i(6, 10 - 3)                   # place the drill THREE cells up the open shaft
	_check(s3.drill_target(above) == vein, "a drill high above the vein finds it straight down (forgiving reach)")
	var d3: MachineState = s3.place_machine(drill_def, above)
	d3.input_buffer[&"coal"] = 20
	var pool3: int = 8
	for _i: int in 100 + pool3 * 25:
		s3.tick()
	_check(not s3.is_solid(vein), "the offset drill bored the vein below it out")
	_check(_items_present(s3, &"ore") == int(s3.total_produced.get(&"ore", 0)), "ore conserved through the offset drill")
	# BORING through SOLID ore, BOTTOM-UP (the scaling drill, undermine model): a drill on an OPEN cell above a
	# solid ore COLUMN eats it from the BOTTOM up — targeting the DEEPEST ore first — so every freed unit falls
	# into the open shaft below and is never trapped under still-solid ore (the old top-down stuck-ore bug).
	var s4: FactorySim = FactorySim.new()
	for y: int in range(6, 10):                        # a 4-tall solid ore column at col 5, rows 6..9
		s4.set_solid(Vector2i(5, y), &"ore"); s4.deposits[Vector2i(5, y)] = 3
	# a DRAIN below the body: an open cell (5,10) then a stone catch-floor (5,12) — so the deepest ore has
	# somewhere to drop (not "blocked"), and the extracted ore piles in the reachable shaft, never buried.
	s4.set_solid(Vector2i(5, 12), &"stone")
	var drill_top := Vector2i(5, 5)                    # placed on the OPEN cell right above the body
	_check(s4.drill_target(drill_top) == Vector2i(5, 9), "the boring drill undermines: it targets the DEEPEST ore")
	var d4: MachineState = s4.place_machine(drill_def, drill_top)
	d4.input_buffer[&"coal"] = 60
	var body_total: int = 4 * 3                         # 4 cells × 3 each
	# Assert INVARIANT every tick: no LOOSE ore pile (`ground`) is ever left resting ON TOP of still-solid ore
	# — that was the top-down stuck-ore bug (freed ore trapped under the body it hadn't bored through yet).
	# Bottom-up undermining ejects only BELOW the deepest ore, so a freed unit always has open space to fall.
	var never_stranded: bool = true
	for _i: int in 100 + body_total * 25:
		s4.tick()
		for gcell: Variant in s4.ground.keys():
			var gc: Vector2i = gcell
			if int((s4.ground[gc] as Dictionary).get(&"ore", 0)) <= 0:
				continue
			var under := gc + Vector2i(0, 1)
			if s4.is_solid(under) and s4._is_ore_like(s4.solid[under]):
				never_stranded = false                 # an ore pile sits on top of unmined solid ore → stuck
	_check(never_stranded, "no loose ore pile is ever stranded on top of unmined ore (drains bottom-up)")
	for y: int in range(6, 10):
		_check(not s4.is_solid(Vector2i(5, y)), "bored-out ore cell (5,%d) is now carved open" % y)
	_check(int(s4.total_produced.get(&"ore", 0)) == body_total, "the whole ore body's deposit was extracted (%d)" % body_total)
	_check(_items_present(s4, &"ore") == body_total, "ore conserved through boring the solid body")
	_check(s4.drill_target(drill_top) == Vector2i(-1, -1), "a spent, fully-bored body leaves the drill nothing (idles)")

	# BLOCKED: a body resting DIRECTLY on rock (no drain) — the drill must STALL and report "blocked", not
	# mine ore into a dead pocket. The fix for "I dropped a drill but nothing flows": dig a drain below.
	var s5: FactorySim = FactorySim.new()
	s5.set_solid(Vector2i(3, 6), &"ore"); s5.deposits[Vector2i(3, 6)] = 5
	s5.set_solid(Vector2i(3, 7), &"stone")             # rock DIRECTLY under the ore → no drain path
	var d5: MachineState = s5.place_machine(drill_def, Vector2i(3, 5))
	d5.input_buffer[&"coal"] = 20
	_check(s5.drill_target(d5.cell) == Vector2i(3, 6), "the blocked drill still SEES the ore below it")
	_check(s5.machine_status(d5) == &"blocked", "a drill with rock directly under the vein reads 'blocked'")
	for _i: int in 200:
		s5.tick()
	_check(int(s5.total_produced.get(&"ore", 0)) == 0, "a blocked drill produces NOTHING (stalls, no dead-pocket mining)")
	_check(s5.is_solid(Vector2i(3, 6)), "the blocked drill left the vein intact (didn't bore into a dead pocket)")
	# open a drain: clear the rock below → the same drill now flows.
	s5.set_solid(Vector2i(3, 7), &"")
	s5.set_solid(Vector2i(3, 9), &"stone")             # a catch-floor two cells down
	_check(s5.machine_status(d5) == &"working", "once a drain is dug below, the drill reads 'working'")
	for _i: int in 200:
		s5.tick()
	_check(int(s5.total_produced.get(&"ore", 0)) == 5, "with a drain, the once-blocked drill drains the full vein")
	_check(_items_present(s5, &"ore") == int(s5.total_produced.get(&"ore", 0)), "ore conserved after unblocking")

	# PLACEMENT PREVIEW (what the overlay draws): the ore column the drill would bore, the drop cell, blocked flag.
	var s6: FactorySim = FactorySim.new()
	for y: int in range(4, 7):                          # a 3-tall vein at col 2, rows 4..6
		s6.set_solid(Vector2i(2, y), &"ore")
	s6.set_solid(Vector2i(2, 8), &"stone")              # open drain (row 7) then a catch-floor
	var pv: Dictionary = s6.drill_preview(Vector2i(2, 3))  # hover the open cell above the vein
	_check((pv["ore_cells"] as Array).size() == 3, "preview lists all 3 ore cells the drill would bore")
	_check(pv["ore_cells"][0] == Vector2i(2, 4) and pv["ore_cells"][-1] == Vector2i(2, 6), "preview spans top→bottom of the vein")
	_check(pv["drop_cell"] == Vector2i(2, 7), "preview drop cell is just below the deepest ore")
	_check(not pv["blocked"], "preview reads NOT blocked when a drain is open below")
	var pv_empty: Dictionary = s6.drill_preview(Vector2i(9, 3))  # nowhere near ore
	_check((pv_empty["ore_cells"] as Array).is_empty(), "preview over no ore lists nothing")


## COAL is a vein mined just like ore (the demand-web, docs/MINING.md), and the DRILL is FUEL-GATED on it:
## no coal → it idles; fed coal → it runs and burns the coal. A drill on a COAL deposit yields coal.
func _test_coal_and_fuel() -> void:
	print("- coal mining + drill fuel")
	# Hand-mining a coal block drops a 3-6 COAL burst and clears the block (same as ore).
	var sim: FactorySim = FactorySim.new()
	var cc := Vector2i(3, 4)
	sim.set_solid(cc, &"coal"); sim.deposits[cc] = 12
	sim.mine(cc)
	var cb: int = int(sim.inventory.get(&"coal", 0))
	_check(cb >= 3 and cb <= 6, "mining coal drops a 3-6 coal burst (got %d)" % cb)
	_check(not sim.is_solid(cc), "one strike breaks the whole coal block")
	_check(_items_present(sim, &"coal") == int(sim.total_produced.get(&"coal", 0)), "coal conserved")

	# The drill is FUEL-GATED: over a solid ore vein with NO coal it produces nothing; fed coal it runs + burns it.
	var drill_def: MachineDef = load("res://src/data/machines/drill.tres")
	var s2: FactorySim = FactorySim.new()
	var ore := Vector2i(8, 6)
	s2.set_solid(ore, &"ore"); s2.deposits[ore] = 20
	s2.set_solid(Vector2i(8, 9), &"stone")
	var d: MachineState = s2.place_machine(drill_def, Vector2i(8, 5))   # OPEN cell above the vein
	var base: int = int(s2.total_produced.get(&"ore", 0))
	for _i: int in 80:
		s2.tick()
	_check(int(s2.total_produced.get(&"ore", 0)) == base, "an UNFUELED drill produces nothing (needs coal)")
	_check(s2.is_solid(ore), "the vein is untouched without coal")
	d.input_buffer[&"coal"] = 10
	for _i: int in 200:
		s2.tick()
	_check(int(s2.total_produced.get(&"ore", 0)) > base, "fed coal, the drill pulls ore")
	_check(int(s2.total_consumed.get(&"coal", 0)) > 0, "the drill burned coal to run")

	# Material-aware: a drill over a solid COAL vein produces COAL (so coal can be automated too).
	var s3: FactorySim = FactorySim.new()
	var coalcell := Vector2i(4, 6)
	s3.set_solid(coalcell, &"coal"); s3.deposits[coalcell] = 20
	s3.set_solid(Vector2i(4, 9), &"stone")
	var d3: MachineState = s3.place_machine(drill_def, Vector2i(4, 5))   # OPEN cell above the coal vein
	d3.input_buffer[&"coal"] = 5
	var coal_before: int = int(s3.total_produced.get(&"coal", 0))
	for _i: int in 200:
		s3.tick()
	_check(int(s3.total_produced.get(&"coal", 0)) > coal_before, "a drill over a COAL vein produces coal (material-aware)")


## Surface trees + wood (the bazaar's gathering foundation, docs/CRAFTING.md). The generator stamps
## trees on the grass; foliage is solid + mineable but NOT walkable surface; chopping is BLOCK-BY-BLOCK
## (no whole-tree fell — docs/MINING.md), one wood per wood cell, leaves yield nothing, conserved.
func _test_trees_and_wood() -> void:
	print("- trees + wood")
	# Generation stamps real trees on the surface.
	var gen := LayeredWorldGen.new()
	# Generate at the REAL world size — worldgen trees start past the centred plateau (FLAT_END), so an
	# undersized test world leaves them no room; this asserts against the dimensions the game actually ships.
	var world: WorldData = gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, 1337)
	var wood_cells: int = 0
	var leaf_cells: int = 0
	for cell: Vector2i in world.blocks:
		if world.blocks[cell] == &"wood":
			wood_cells += 1
		elif world.blocks[cell] == &"leaves":
			leaf_cells += 1
	_check(wood_cells > 0 and leaf_cells > 0, "worldgen planted trees (wood=%d, leaves=%d)" % [wood_cells, leaf_cells])

	# A hand-built tree: 2 wood trunk + 1 leaf crown on a grass column.
	var sim: FactorySim = FactorySim.new()
	sim.set_solid(Vector2i(5, 5), &"earth")            # ground
	sim.set_solid(Vector2i(5, 4), &"wood")             # base trunk (rests on the earth = the root)
	sim.set_solid(Vector2i(5, 3), &"wood")
	sim.set_solid(Vector2i(5, 2), &"leaves")
	_check(sim.surface_row(5) == 5, "foliage is NOT the walkable surface — the ground row is (trees don't ramp)")
	_check(sim.is_solid(Vector2i(5, 3)), "a trunk cell is solid (you collide with / can chop it)")
	# NOTHING FLOATS (Terraria): cut the BASE trunk → it loses its root and the WHOLE tree falls. Chopping
	# the base returns that block's wood; _settle_foliage fells the rest (the trunk + canopy above) into
	# the pack too, so you get the whole tree and no leaves are left hanging in the air.
	_check(sim.mine(Vector2i(5, 4)) == &"wood", "chopping the base trunk returns wood material")
	_check(int(sim.inventory.get(&"wood", 0)) == 2, "the whole tree falls → BOTH trunk cells' wood (base + felled)")
	_check(not sim.is_solid(Vector2i(5, 4)) and not sim.is_solid(Vector2i(5, 3)), "both trunk cells cleared")
	_check(not sim.is_solid(Vector2i(5, 2)), "the CANOPY fell too — no floating leaves (nothing floats)")
	_check(sim.is_solid(Vector2i(5, 5)), "the ground under the tree survives (terrain does NOT collapse)")
	_check(_items_present(sim, &"wood") == int(sim.total_produced.get(&"wood", 0)), "wood conserved through the fall")

	# The other route to "nothing floats": dig the EARTH out from under a standing tree → it un-roots and falls.
	var sim2: FactorySim = FactorySim.new()
	sim2.set_solid(Vector2i(8, 6), &"earth")
	sim2.set_solid(Vector2i(8, 5), &"wood")
	sim2.set_solid(Vector2i(8, 4), &"wood")
	sim2.set_solid(Vector2i(8, 3), &"leaves")
	_check(sim2.mine(Vector2i(8, 6)) == &"earth", "digging the earth under the tree returns earth")
	_check(not sim2.is_solid(Vector2i(8, 5)) and not sim2.is_solid(Vector2i(8, 4))
		and not sim2.is_solid(Vector2i(8, 3)), "the un-rooted tree fell entirely — no floating trunk or leaves")
	# The invariant, asserted directly: after these ops, NO foliage cell floats (each has a downward path
	# to non-foliage ground through foliage). This is the check the user's 'nothing floats' bug wanted.
	_check(_no_floating_foliage(sim) and _no_floating_foliage(sim2), "no floating foliage remains anywhere")


## SAPLINGS (FABLE_50 #38 — the renewable-wood loop): chopped canopies hide seeds (deterministic per
## cell), planting wants soil, the TICK grows a real tree, occupation crushes / lost soil uproots,
## and the ledger stays total through chop → plant → grow → chop.
func _test_saplings() -> void:
	print("- saplings (renewable wood)")
	var sim: FactorySim = FactorySim.new()
	# Chopping leaves drops the deterministic per-cell share of saplings (~1 in 3, hash-set, no RNG).
	# A 30-cell grove: the share must be real (not zero, not every leaf) and exactly the hash's own count.
	var canopy: Array[Vector2i] = []
	for lx: int in range(18, 24):
		for ly: int in range(2, 7):
			canopy.append(Vector2i(lx, ly))
	var expect: int = 0
	for lc: Vector2i in canopy:
		sim.set_solid(lc, &"leaves")
		if sim.leaf_drops_sapling(lc):
			expect += 1
	for lc: Vector2i in canopy:
		sim.mine(lc)
	var got_s: int = int(sim.inventory.get(&"sapling", 0))
	_check(expect > 0 and expect < canopy.size(), "the grove hides SOME seeds (%d/30 — a share, not all/none)" % expect)
	_check(got_s == expect, "chopping the grove dropped exactly the hash-share (%d/%d)" % [got_s, expect])
	# Planting wants OPEN cell + SOIL below; anything else refuses.
	sim.set_solid(Vector2i(30, 10), &"earth")
	sim.set_solid(Vector2i(31, 10), &"stone")
	sim.inventory[&"sapling"] = int(sim.inventory.get(&"sapling", 0)) + 2
	sim.total_produced[&"sapling"] = int(sim.total_produced.get(&"sapling", 0)) + 2
	_check(not sim.plant_sapling(Vector2i(30, 5)), "mid-air (no soil below) refuses")
	_check(not sim.plant_sapling(Vector2i(31, 9)), "stone is not soil")
	_check(sim.plant_sapling(Vector2i(30, 9)), "open cell on earth roots the sapling")
	_check(not sim.plant_sapling(Vector2i(30, 9)), "an occupied sapling cell refuses a second seed")
	# The un-plant mirror: RMB takes it back; growth restarts from zero on replant.
	_check(sim.remove_sapling(Vector2i(30, 9)), "a planted sapling can be taken back")
	_check(sim.plant_sapling(Vector2i(30, 9)), "…and replanted")
	# GROWTH: run the sim to maturity — a real tree stands (trunk wood + a canopy), the sapling retires.
	for _i: int in FactorySim.SAPLING_GROW_TICKS + 1:
		sim.tick()
	_check(not sim.sapling.has(Vector2i(30, 9)), "the grown sapling retired")
	_check(sim.material_at(Vector2i(30, 9)) == &"wood", "a trunk stands where it was planted")
	var leaves_n: int = 0
	for c: Variant in sim.solid:
		if sim.solid[c] == &"leaves":
			leaves_n += 1
	_check(leaves_n >= 4, "the tree grew a canopy (%d leaf cells)" % leaves_n)
	# CRUSH: a sapling built over dies silently on the next tick.
	sim.set_solid(Vector2i(40, 10), &"earth")
	sim.inventory[&"sapling"] = int(sim.inventory.get(&"sapling", 0)) + 2
	sim.total_produced[&"sapling"] = int(sim.total_produced.get(&"sapling", 0)) + 2
	_check(sim.plant_sapling(Vector2i(40, 9)), "plant the crush candidate")
	sim.set_solid(Vector2i(40, 9), &"stone")            # built straight over the seedling
	sim.tick()
	_check(not sim.sapling.has(Vector2i(40, 9)), "a built-over sapling is crushed")
	# UPROOT: mine the soil out — the seed drops free as a ground item (back in the world, ledgered).
	sim.set_solid(Vector2i(50, 10), &"earth")
	_check(sim.plant_sapling(Vector2i(50, 9)), "plant the uproot candidate")
	sim.mine(Vector2i(50, 10))
	sim.tick()
	_check(not sim.sapling.has(Vector2i(50, 9)), "losing the soil uproots the sapling")
	var freed: int = 0
	for pile: Variant in sim.ground.values():
		freed += int((pile as Dictionary).get(&"sapling", 0))
	_check(freed == 1, "the uprooted seed dropped as a ground item")
	var present_s: int = _items_present(sim, &"sapling")
	var net_s: int = int(sim.total_produced.get(&"sapling", 0)) - int(sim.total_consumed.get(&"sapling", 0))
	_check(present_s == net_s, "saplings conserved through the whole loop (present=%d, net=%d)" % [present_s, net_s])


## Manual-mining friction rules (docs/MINING.md): the GATE (own a tool that breaks this) and the felt
## time (hardness / tool speed). Pure static logic, no sim — the same table the controller + try_mine use.
func _test_mining_rules() -> void:
	print("- mining rules (tools + friction)")
	var bare: Dictionary = {}
	var pick: Dictionary = {&"wood_pickaxe": 1}
	var axe: Dictionary = {&"wood_axe": 1}
	# Gate: rock AND wood want the pick (the axe was DELETED, #38 — one tool, one slot); dirt is
	# hand-mineable. A legacy axe in a pre-#38 save opens nothing.
	_check(not MiningRules.can_mine(&"stone", bare), "can't crack stone bare-handed")
	_check(MiningRules.can_mine(&"stone", pick), "the pickaxe cracks stone")
	_check(MiningRules.can_mine(&"wood", pick), "the pickaxe chops wood too (the axe is gone)")
	_check(not MiningRules.can_mine(&"wood", axe), "a legacy axe is a keepsake, not a key")
	_check(MiningRules.can_mine(&"earth", bare), "dirt is always hand-mineable")
	_check(MiningRules.can_mine(&"ore", pick), "the starter pick can mine ore")
	_check(MiningRules.STARTER_TOOLS.size() == 1 and MiningRules.STARTER_TOOLS[0] == &"wood_pickaxe",
		"one starter tool: the wooden pick")
	# Friction: harder rock takes longer; no tool = unbreakable (INF).
	_check(MiningRules.mine_seconds(&"stone", bare) == INF, "no pick → stone never breaks")
	_check(MiningRules.mine_seconds(&"stone", pick) > 0.0, "with a pick stone takes finite time")
	_check(MiningRules.is_tool_item(&"wood_pickaxe") and not MiningRules.is_tool_item(&"ore"), "tools are distinguished from resources")
	# TIER DEPTH-GATE: deepslate (the deep band) needs a tier-2 pick — the starter wood pick (tier 1) bounces.
	var stone_pick: Dictionary = {&"stone_pickaxe": 1}
	_check(MiningRules.required_tier(&"deepslate") == 2, "deepslate requires a tier-2 pick")
	_check(MiningRules.required_tier(&"stone") == 1, "ordinary rock is tier-1 (any pick)")
	_check(not MiningRules.can_mine(&"deepslate", pick), "the wood pick (tier 1) can't crack deepslate")
	_check(MiningRules.can_mine(&"deepslate", stone_pick), "the stone pick (tier 2) cracks deepslate")
	_check(MiningRules.mine_seconds(&"deepslate", pick) == INF, "wood pick → deepslate never breaks (gated)")
	_check(MiningRules.mine_seconds(&"deepslate", stone_pick) > 0.0, "stone pick → deepslate takes finite time")
	_check(MiningRules.best_tier(&"pick", stone_pick) == 2 and MiningRules.best_tier(&"pick", pick) == 1, "best_tier reads the pack's top pick")
	# CRAFTING the upgrade: the Stone Pickaxe is crafted from its TOOL_RECIPE (stone+wood), spending them.
	var s: FactorySim = FactorySim.new()
	s.inventory[&"stone"] = 10
	s.inventory[&"wood"] = 5
	_check(s.craft_item(&"stone_pickaxe", MiningRules.TOOL_RECIPES[&"stone_pickaxe"]), "craft a Stone Pickaxe with enough stone+wood")
	_check(int(s.inventory.get(&"stone_pickaxe", 0)) == 1, "the stone pickaxe is now in the pack")
	_check(int(s.inventory.get(&"stone", 0)) == 2 and int(s.inventory.get(&"wood", 0)) == 2, "crafting spent the recipe cost (8 stone, 3 wood)")
	_check(MiningRules.can_mine(&"deepslate", s.inventory), "with the crafted pick, deepslate is now mineable")
	var poor: FactorySim = FactorySim.new()
	poor.inventory[&"stone"] = 2
	_check(not poor.craft_item(&"stone_pickaxe", MiningRules.TOOL_RECIPES[&"stone_pickaxe"]), "can't craft the pick without enough materials")
	# THE IRON PICKAXE (tier 3, FABLE_50 #37): priced in the L2 chain's own product — the MATERIALS
	# gate it (iron ingots want the Iron Forge, which wants the breach). Its value today is SPEED;
	# tier 3 is the rung L3's rock band will gate on.
	var smith: FactorySim = FactorySim.new()
	smith.inventory[&"iron_ingot"] = 6
	smith.inventory[&"wood"] = 3
	_check(smith.craft_item(&"iron_pickaxe", MiningRules.TOOL_RECIPES[&"iron_pickaxe"]), "craft an Iron Pickaxe from 6 iron ingots + 3 wood")
	_check(MiningRules.best_tier(&"pick", smith.inventory) == 3, "the iron pick is tier 3")
	_check(MiningRules.mine_seconds(&"deepslate", smith.inventory)
		< MiningRules.mine_seconds(&"deepslate", stone_pick), "…and chews deepslate faster than the stone pick")
	_check(not MiningRules.can_mine(&"sealrock", smith.inventory), "even tier 3 cannot hand-mine THE SEAL")


## HOPPER (storage + metered feed): the missing 'chest'. It stockpiles what falls in, meters it DOWN to a
## machine below with BACK-PRESSURE (holds once the consumer is backed up), and HOLDS everything when there
## is no consumer below (pure storage). Items only move → conservation holds throughout.
func _test_hopper() -> void:
	print("- hopper (storage + metered feed)")
	var hopper_def: MachineDef = load("res://src/data/machines/hopper.tres")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	# Metered feed: a hopper above a forge banks a burst of ore and trickles it down; the forge smelts it,
	# and back-pressure keeps the forge's buffer small (the bulk stays banked in the hopper).
	var sim: FactorySim = FactorySim.new()
	var hopper: MachineState = sim.place_machine(hopper_def, Vector2i(3, 4))
	var forge: MachineState = sim.place_machine(proc_def, Vector2i(3, 6))
	sim.set_solid(Vector2i(3, 9), &"stone")            # floor: ingots land as a pile
	hopper.input_buffer[&"ore"] = 20                   # dump a burst in
	sim.total_produced[&"ore"] = 20                    # account it
	var forge_peak: int = 0
	for _i: int in 300:
		sim.tick()
		forge_peak = maxi(forge_peak, int(forge.input_buffer.get(&"ore", 0)))
	_check(int(hopper.input_buffer.get(&"ore", 0)) < 20, "the hopper released its stockpile downward over time")
	_check(int(sim.total_produced.get(&"ingot", 0)) > 0, "metered ore reached the forge and got smelted")
	_check(forge_peak <= FactorySim.HOPPER_FEED_CAP + FactorySim.HOPPER_RELEASE,
		"back-pressure kept the forge's buffer small (peak=%d) — the bulk stayed banked" % forge_peak)
	for item: StringName in [&"ore", &"ingot"]:
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(_items_present(sim, item) == net, "%s conserved through the hopper (present=%d, net=%d)" % [item, _items_present(sim, item), net])
	# Storage mode: a hopper with NO machine below (just floor) HOLDS its whole stockpile — it never spills.
	var s2: FactorySim = FactorySim.new()
	var store: MachineState = s2.place_machine(hopper_def, Vector2i(5, 4))
	s2.set_solid(Vector2i(5, 6), &"stone")             # a floor below, but no machine to feed
	store.input_buffer[&"ore"] = 10
	s2.total_produced[&"ore"] = 10
	for _i: int in 100:
		s2.tick()
	_check(int(store.input_buffer.get(&"ore", 0)) == 10, "with no consumer below, the hopper HOLDS its whole stockpile (storage)")
	_check(_items_present(s2, &"ore") == 10, "the held stockpile is conserved")


## DROP / TOSS (the central "gravity is the conveyor" feeding verb): letting go of a stack above a column
## cascades it DOWN to the first machine (feeds its input) else the first floor (a re-collectable pile) else
## the void — and the cosmetic toss origin (from_cell) never changes WHERE it lands. Conservation holds:
## items only MOVE pack→(machine|ground), none made or destroyed.
func _test_drop_toss() -> void:
	print("- drop / toss (gravity feed)")
	# Case 1: drop above a forge in the same column → it feeds the forge's input buffer.
	var sim: FactorySim = FactorySim.new()
	var forge: MachineState = sim.place_machine(load("res://src/data/machines/processor.tres"), Vector2i(5, 6))
	sim.inventory[&"ore"] = 5
	sim.total_produced[&"ore"] = 5
	var fed: int = sim.drop_item(Vector2i(5, 2), &"ore", 3)          # let go 3 ore above the forge's column
	_check(fed == 3, "dropped 3 ore into the column")
	_check(int(forge.input_buffer.get(&"ore", 0)) == 3, "the ore fell into the forge's input buffer")
	_check(int(sim.inventory.get(&"ore", 0)) == 2, "the dropped ore left the pack")
	_check(_items_present(sim, &"ore") == 5, "ore conserved through the drop (2 pack + 3 in forge)")
	# The landing cell is exposed so the controller can grace it (no instant re-pickup — playtest fix).
	_check(sim.last_drop_landing == Vector2i(5, 6), "drop_item records the landing cell for the pickup grace")

	# Case 2: drop above just a floor → it rests as a re-collectable ground pile (no machine to catch it).
	var s2: FactorySim = FactorySim.new()
	s2.set_solid(Vector2i(3, 9), &"stone")                          # a floor to land on
	s2.inventory[&"ingot"] = 4
	s2.total_produced[&"ingot"] = 4
	var d2: int = s2.drop_item(Vector2i(3, 1), &"ingot", 4)
	_check(d2 == 4, "dropped 4 ingot down an open column")
	var landed := Vector2i(3, 8)                                    # rests on top of the row-9 floor
	_check(int((s2.ground.get(landed, {}) as Dictionary).get(&"ingot", 0)) == 4, "the ingots rest as a ground pile on the floor")
	_check(_items_present(s2, &"ingot") == 4, "ingot conserved as a ground pile")

	# Case 3: the toss ORIGIN (from_cell, cosmetic) does not change the landing — a tossed stack lands by the
	# target column's gravity, not where it was flung from.
	var s3: FactorySim = FactorySim.new()
	var f3: MachineState = s3.place_machine(load("res://src/data/machines/processor.tres"), Vector2i(7, 5))
	s3.inventory[&"ore"] = 2
	s3.total_produced[&"ore"] = 2
	s3.drop_item(Vector2i(7, 1), &"ore", 2, Vector2i(4, 1))         # flung from col 4, aimed at col 7
	_check(int(f3.input_buffer.get(&"ore", 0)) == 2, "a tossed stack lands by the target column, not the throw origin")


## Block SUPPORT (the "no placing blocks in mid-air" playtest fix): a building block needs a wall behind
## it or an orthogonal solid/machine/conduit neighbour. Machines are exempt (gated in the controller).
func _test_block_supported() -> void:
	print("- block support (no mid-air blocks)")
	var sim: FactorySim = FactorySim.new()
	sim.set_solid(Vector2i(5, 10), &"earth")
	_check(not sim.block_supported(Vector2i(5, 2)), "isolated open-sky cell has NO support (can't float a block)")
	_check(sim.block_supported(Vector2i(5, 9)), "on top of a solid block IS supported")
	_check(sim.block_supported(Vector2i(6, 10)), "beside a solid block IS supported (extend a structure)")
	_check(not sim.block_supported(Vector2i(8, 2)), "two cells from anything is still unsupported")
	sim.set_wall(Vector2i(20, 3), &"earth")            # a dug room keeps its wall → a block can backfill it
	_check(sim.block_supported(Vector2i(20, 3)), "a wall behind the cell supports a block (backfill a dug room)")


## Block placement (the Terraria build primitive) + Bazaar structure detection (docs/CRAFTING.md).
func _test_block_placement_and_bazaar() -> void:
	print("- block placement + bazaar")
	var sim: FactorySim = FactorySim.new()
	# place_block consumes a carried material into an open cell; conservation holds (consumed, then
	# mining it back is produced).
	sim.inventory[&"wood"] = 3
	sim.total_produced[&"wood"] = 3                     # pretend these were chopped, so net starts balanced
	_check(sim.place_block(Vector2i(2, 2), &"wood"), "placed a wood block from the pack")
	_check(sim.is_solid(Vector2i(2, 2)) and int(sim.inventory.get(&"wood", 0)) == 2, "block is solid, pack spent one")
	_check(not sim.place_block(Vector2i(2, 2), &"wood"), "cannot place onto an occupied cell")
	var net: int = int(sim.total_produced.get(&"wood", 0)) - int(sim.total_consumed.get(&"wood", 0))
	_check(_items_present(sim, &"wood") == net, "wood conserved across placement (place = consume)")

	# Build a valid bazaar frame on solid ground and detect it.
	var b: FactorySim = FactorySim.new()
	var o := Vector2i(10, 6)                            # top-left of the 4×3 frame
	for ix: int in 4:                                  # ground row under the whole footprint
		b.set_solid(o + Vector2i(ix, 3), &"earth")
	b.set_solid(o + Vector2i(0, 0), &"wood"); b.set_solid(o + Vector2i(1, 0), &"wood")
	b.set_solid(o + Vector2i(2, 0), &"wood"); b.set_solid(o + Vector2i(3, 0), &"wood")  # top beam
	b.set_solid(o + Vector2i(0, 1), &"wood"); b.set_solid(o + Vector2i(3, 1), &"wood")  # posts
	b.set_solid(o + Vector2i(0, 2), &"wood")
	_check(not b.is_bazaar_at(o), "frame missing one post is NOT yet a bazaar")
	_check(b.bazaar_completion_cell() == o + Vector2i(3, 2), "completion cell points at the single missing post")
	b.set_solid(o + Vector2i(3, 2), &"wood")           # the completing block
	_check(b.is_bazaar_at(o), "completing the frame forms a valid bazaar")
	_check(b.bazaar_completion_cell() == Vector2i(-1, -1), "a complete bazaar has no completion cell")
	var found: Array[Vector2i] = b.find_bazaars()
	_check(found.size() == 1 and found[0] == o, "find_bazaars locates exactly it")
	_check(b.near_bazaar(b.bazaar_center(o), 3), "near_bazaar true at the interior")
	_check(not b.near_bazaar(o + Vector2i(40, 0), 3), "near_bazaar false far away")
	# WALK-THROUGH: the bazaar is a stall you enter, so its wood FRAME cells (posts + beam) don't block the
	# body, but its interior FLOOR (plain ground) does, and a lone wood block (e.g. a tree) is never a frame.
	_check(b.is_bazaar_frame_cell(o + Vector2i(0, 0)), "a top-beam cell is a walk-through frame cell")
	_check(b.is_bazaar_frame_cell(o + Vector2i(0, 1)), "a post cell is a walk-through frame cell")
	_check(b.is_bazaar_frame_cell(o + Vector2i(3, 2)), "the completing post is a walk-through frame cell")
	_check(not b.is_bazaar_frame_cell(o + Vector2i(1, 3)), "the interior FLOOR is solid ground, not a frame cell (you stand on it)")
	b.set_solid(Vector2i(50, 10), &"wood")             # a lone trunk, no frame around it
	_check(not b.is_bazaar_frame_cell(Vector2i(50, 10)), "a lone wood block (tree) is NOT a bazaar frame cell (trees still block)")
	# A wood block dropped INTO the interior breaks it (no longer open).
	b.set_solid(o + Vector2i(1, 1), &"wood")
	_check(not b.is_bazaar_at(o), "a blocked interior is no longer a valid bazaar")


## POWER (docs/POWER.md): a fueled generator pours power into its aura; out of coal it goes dark; coal
## is genuinely consumed (conservation). The field is derived — recomputed each tick, never stored.
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


## CONDUITS (docs/POWER.md): power floods DOWN + LATERAL through tubes, never UP (a U delivers as an L);
## the place/remove API moves a carried conduit in/out of the layer. Geometry: a generator at (8,4) feeds
## a down-leg, a lateral bottom, and an up-leg — the up-leg must stay dark even directly above live power.
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
	# The up-leg tube carries NOTHING upward (a U delivers as an L). The corner's immediate up-neighbour
	# gets only a faint 1-cell aura bleed (like a generator's), so test from two cells up where even that
	# is gone — the tube itself never climbs.
	_check(sim.power_at(Vector2i(10, 9)) == 0.0, "the up-leg carries no power (U delivers as L)")
	_check(sim.power_at(Vector2i(10, 8)) == 0.0, "no power climbs the up-leg (never flows up)")
	# place / remove API (carried conduit item ⇄ the layer).
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
	# Symmetric placed-layer accounting: place = consumed, remove = produced, so present == net holds
	# with conduits mid-placed too (they were the one item that silently skipped the ledger).
	s2.place_conduit(Vector2i(3, 3))
	var present_c: int = _items_present(s2, &"conduit")
	var net_c: int = int(s2.total_produced.get(&"conduit", 0)) - int(s2.total_consumed.get(&"conduit", 0))
	_check(present_c == net_c, "conduit conserved with one placed (present=%d, net=%d)" % [present_c, net_c])


## POWER governs the lift (docs/POWER.md): unpowered it runs at LIFT_THROUGHPUT (proved by _test_lift);
## with a generator beside it pouring power into its cell, it carries up to LIFT_POWERED_THROUGHPUT — the
## cost rule (power_throttle) routing the boost. Fighting gravity UP is the canonical "costs power" case.
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


## THE PUMP — the powered flood-drain (docs/DECISIONS.md, the L3 aquifer answer). It falls on the LOCKED
## hook: water floods DOWN for free, pumping it back OUT costs power. This is the on-hook PROOF — a POWERED
## pump drains a flooded pocket substantially, an identical UNPOWERED pump barely touches it. Also asserts
## the drain is bounded/sane: no water is ever created and no cell goes negative.
func _test_pump() -> void:
	print("- pump (powered flood-drain, L3)")
	var pump_def: MachineDef = load("res://src/data/machines/pump.tres")
	var gen_def: MachineDef = load("res://src/data/machines/generator.tres")

	# Build one flooded, SEALED pocket: a walled 1-wide shaft (x=col) with a floor, brim-full of water.
	# Returns the sim + the top-of-pocket cell the pump sits in. Sealed so no water escapes — any drop in
	# total_water is attributable to the pump alone.
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

	# --- POWERED: a fueled generator beside the pump pours power into its cell → it drains the pocket. ---
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
	# Tick a while: the powered pump should drain the pocket substantially (aim: nearly dry).
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

	# --- UNPOWERED: an identical flooded pocket, a pump with NO generator → it does essentially nothing. ---
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

	# --- SANITY: the pump never CREATES water — the drained pocket's total only ever fell. ---
	_check(after <= before and uafter <= ubefore, "the pump only ever removes water, never adds it")
	# machine_status mirrors the runner: powered+wet reads working, unpowered reads idle ("no power").
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


## RUNG 1 — the SELF-FEEDING LINE (docs/PROGRESSION.md, the first automation milestone). The mechanical
## spec the guided objective chain + the R1 agent-play-test drive the player to build: a Drill on TOP of an
## ore CHUNK, with a Processor forge directly below the chunk. The drill drains the chunk bottom-up and its
## ore FALLS into the forge (gravity is the conveyor, the locked hook); the forge smelts; ingots pile on the
## floor — all with ZERO hand-mining or hand-feeding once placed. If this breaks, the rung the player is
## being guided toward is unbuildable. Conservation must hold throughout.
## machine_status is the read-only legibility mirror of the run-gates (Slice A). It must report exactly
## what _run_machine would do THIS tick — no fuel/no input/idle/working — so the on-machine status lamp
## can't lie. Pure query, no mutation.
func _test_machine_status() -> void:
	print("- machine status (legibility mirror)")
	var drill_def: MachineDef = load("res://src/data/machines/drill.tres")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	var hopper_def: MachineDef = load("res://src/data/machines/hopper.tres")

	# Drill above a solid ore vein, no coal → no_fuel; fed coal → working.
	var sim: FactorySim = FactorySim.new()
	var ore := Vector2i(6, 6)
	sim.set_solid(ore, &"ore"); sim.deposits[ore] = 20
	sim.set_solid(Vector2i(6, 9), &"stone")
	var drill: MachineState = sim.place_machine(drill_def, Vector2i(6, 5))   # OPEN cell above the vein
	_check(sim.machine_status(drill) == &"no_fuel", "unfueled drill over ore reads no_fuel")
	drill.input_buffer[&"coal"] = 5
	_check(sim.machine_status(drill) == &"working", "fueled drill over ore reads working")

	# Drill with nothing borable below (over plain stone) → no_input.
	var s2: FactorySim = FactorySim.new()
	s2.set_solid(Vector2i(3, 6), &"stone")
	var idle_drill: MachineState = s2.place_machine(drill_def, Vector2i(3, 5))
	idle_drill.input_buffer[&"coal"] = 5
	_check(s2.machine_status(idle_drill) == &"no_input", "drill with no ore below reads no_input")

	# Forge: starved → no_input; fed its ingredient → working.
	var s3: FactorySim = FactorySim.new()
	var forge: MachineState = s3.place_machine(proc_def, Vector2i(4, 3))
	_check(s3.machine_status(forge) == &"no_input", "starved forge reads no_input")
	var need: StringName = proc_def.recipe.inputs.keys()[0]
	forge.input_buffer[need] = int(proc_def.recipe.inputs[need])
	_check(s3.machine_status(forge) == &"working", "fed forge reads working")

	# Hopper: empty → idle (benign); holding items → working.
	var s4: FactorySim = FactorySim.new()
	var hopper: MachineState = s4.place_machine(hopper_def, Vector2i(2, 2))
	_check(s4.machine_status(hopper) == &"idle", "empty hopper reads idle")
	hopper.input_buffer[&"ore"] = 3
	_check(s4.machine_status(hopper) == &"working", "loaded hopper reads working")


## The `sim.ground` map must never retain an EMPTY pile dict — an empty {} crashed walk-over collect
## (`pile.keys()[0]`) and drew phantom guides. A SPLITTER leaks them: _destinations builds the landing pile
## for BOTH columns, but a tick that routes all items one way leaves the other column's pile empty. Assert
## _prune_empty_ground keeps `ground` clean, and that the surviving piles are conserved.
func _test_no_empty_ground_piles() -> void:
	print("- no empty ground piles (splitter leak guard)")
	var split_def: MachineDef = load("res://src/data/machines/splitter.tres")
	var sim: FactorySim = FactorySim.new()
	# A splitter over TWO open columns, each with a stone floor a few cells down so items land as GROUND piles.
	var sc := Vector2i(5, 3)
	var splitter: MachineState = sim.place_machine(split_def, sc)
	sim.set_solid(Vector2i(sc.x, sc.y + 4), &"stone")       # floor under the DOWN column
	sim.set_solid(Vector2i(sc.x + 1, sc.y + 4), &"stone")   # floor under the RIGHT column
	# Feed a SINGLE ore unit each tick — the splitter routes it to ONE column, so the OTHER column's
	# freshly-created landing pile is empty right when the tick returns (the frame's collect step runs THEN
	# and crashed on it). Check for empties immediately after EACH tick — the transient the prune must erase.
	var empties: int = 0
	for _i: int in 6:
		splitter.input_buffer[&"ore"] = 1
		sim.total_produced[&"ore"] = int(sim.total_produced.get(&"ore", 0)) + 1
		sim.tick()
		for cell: Variant in sim.ground.keys():
			if (sim.ground[cell] as Dictionary).is_empty():
				empties += 1
	_check(empties == 0, "no empty ground pile lingers when the tick returns (splitter routes one way; found %d)" % empties)
	_check(_items_present(sim, &"ore") == int(sim.total_produced.get(&"ore", 0)), "ore conserved through the splitter to ground")
	# The resettle path: a pile on a block whose floor is mined must not leave an empty landing pile either.
	var s2: FactorySim = FactorySim.new()
	s2.set_solid(Vector2i(2, 5), &"stone")                  # a block with a pile resting on top of it
	s2.ground[Vector2i(2, 4)] = {&"ingot": 2}
	s2.total_produced[&"ingot"] = 2
	s2.set_solid(Vector2i(2, 8), &"stone")                  # a lower floor to catch the cascade
	s2.mine(Vector2i(2, 5))                                 # remove the floor → the pile resettles down
	var e2: int = 0
	for cell: Variant in s2.ground.keys():
		if (s2.ground[cell] as Dictionary).is_empty():
			e2 += 1
	_check(e2 == 0, "resettling a pile leaves no empty landing pile behind (found %d)" % e2)
	_check(_items_present(s2, &"ingot") == 2, "ingot conserved through the resettle cascade")


func _test_automated_line() -> void:
	print("- automated ore→ingot line (Rung 1)")
	var drill_def: MachineDef = load("res://src/data/machines/drill.tres")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	var sim: FactorySim = FactorySim.new()
	var col: int = 8
	# Boring model: a DRILL in the open cell above a solid ore vein bores DOWN into it → the ore falls into a
	# forge just below the vein → ingots land on the floor. Hands-free after placing + fueling the drill.
	var ore := Vector2i(col, 5)
	sim.set_solid(ore, &"ore"); sim.deposits[ore] = 30      # the visible solid vein the drill bores
	var line_drill: MachineState = sim.place_machine(drill_def, Vector2i(col, 4))  # drill in the OPEN cell above the vein
	sim.place_machine(proc_def, Vector2i(col, 6))            # forge below the vein (catches the bored ore's fall)
	sim.set_solid(Vector2i(col, 8), &"stone")               # floor under the forge's output gap (row 7)
	line_drill.input_buffer[&"coal"] = 30                   # fuel it (the drill burns coal); player does NOTHING after
	for _i: int in 600:
		sim.tick()
	var ingots: int = int(sim.total_produced.get(&"ingot", 0))
	_check(ingots > 0, "the line forged ingots with NO hand intervention (%d)" % ingots)
	_check(int(sim.total_produced.get(&"ore", 0)) >= ingots * 2, "the drill supplied the ore the forge smelted")
	var piled: int = 0
	for pile: Variant in sim.ground.values():
		piled += int((pile as Dictionary).get(&"ingot", 0))
	_check(piled > 0, "ingots piled on the floor, ready to collect (%d)" % piled)
	for item: StringName in [&"ore", &"ingot"]:
		var present_i: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present_i == net, "%s conserved in the automated line (present=%d, net=%d)" % [item, present_i, net])


## THE BEHAVIOR REGISTRY contract (FactorySim._BEHAVIORS): every entry's hook names resolve to real
## sim methods (a typo'd entry would silently dead-letter that machine), every registered behavior
## has a Visuals.MACHINE_STYLE look (the representation twin can't drift), and a def with an UNKNOWN
## tag falls through to the default recipe-runner — the registry's fallback keeps future/modded tags
## alive instead of dead.
func _test_behavior_registry() -> void:
	print("- behavior registry")
	var sim: FactorySim = FactorySim.new()
	for tag: StringName in FactorySim._BEHAVIORS:
		var entry: Dictionary = FactorySim._BEHAVIORS[tag]
		for hook: String in ["run", "status", "dests"]:
			if entry.has(hook):
				_check(sim.has_method(entry[hook]), "%s.%s resolves to a sim method" % [tag, hook])
		_check(Visuals.MACHINE_STYLE.has(tag), "%s has a MACHINE_STYLE look" % tag)
	var def := MachineDef.new()
	def.id = &"registry_probe"
	def.display_name = "Probe"
	def.behavior = &"experimental_tag"                       # NOT in the registry
	def.recipe = load("res://src/data/recipes/smelt_ingot.tres")
	var probe: MachineState = sim.place_machine(def, Vector2i(4, 5))
	probe.input_buffer[&"ore"] = 6
	for _i: int in 200:
		sim.tick()
	_check(int(sim.total_produced.get(&"ingot", 0)) > 0,
		"an unknown behavior tag falls through to the default recipe-runner")
	_check(sim.machine_status(probe) != &"", "unknown tag still derives a status")


## The ROPE (the placeable climb — docs/DECISIONS 2026-07-11): ONE placement anchors at the aim cell and
## UNROLLS DOWN the open column (a segment per cell) until floor/machine/rope/world-bottom or the pack
## runs dry; cutting a segment takes it AND everything hanging below; solids/machines refuse roped cells;
## items still fall STRAIGHT THROUGH a roped shaft (the rope never enters item-flow); and the &"rope"
## item satisfies the total ledger through place/cut.
func _test_rope() -> void:
	print("- rope")
	var sim: FactorySim = FactorySim.new()
	var col: int = 12
	sim.set_solid(Vector2i(col, 10), &"stone")               # the shaft floor
	sim.inventory[&"rope"] = 20
	sim.total_produced[&"rope"] = 20
	var hung: int = sim.place_rope(Vector2i(col, 4))
	_check(hung == 6, "rope unrolled from the anchor down to the floor (hung %d/6)" % hung)
	_check(sim.is_climbable(Vector2i(col, 4)) and sim.is_climbable(Vector2i(col, 9)), "anchor + bottom are climbable")
	_check(not sim.is_climbable(Vector2i(col, 10)), "the floor itself is not roped")
	_check(int(sim.inventory.get(&"rope", 0)) == 14, "each segment spent one carried rope")
	_check(sim.place_rope(Vector2i(col, 4)) == 0, "an already-roped anchor refuses (no double-hang)")
	sim.set_solid(Vector2i(col + 1, 3), &"earth")
	_check(sim.place_rope(Vector2i(col + 1, 3)) == 0, "cannot anchor inside solid rock")
	# The pack caps the unroll: with 2 segments left, a deep shaft gets only 2.
	var s3: FactorySim = FactorySim.new()
	s3.inventory[&"rope"] = 2
	s3.total_produced[&"rope"] = 2
	_check(s3.place_rope(Vector2i(5, 0)) == 2, "unroll stops when the pack runs out")
	# Solids/machines refuse roped cells (cut the rope first — no rope-in-stone).
	sim.inventory[&"earth"] = 1
	sim.total_produced[&"earth"] = 1
	_check(not sim.place_block(Vector2i(col, 6), &"earth"), "a block cannot be placed into a roped cell")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	_check(sim.place_machine(proc_def, Vector2i(col, 6)) == null, "a machine cannot be placed into a roped cell")
	# Items fall THROUGH a roped shaft: a drop from above the rope lands on the floor pile, not mid-rope.
	sim.inventory[&"ore"] = 1
	sim.total_produced[&"ore"] = 1
	sim.drop_item(Vector2i(col, 2), &"ore", 1)
	var rest: Vector2i = Vector2i(col, 9)                     # the open cell on top of the floor
	_check(int((sim.ground.get(rest, {}) as Dictionary).get(&"ore", 0)) == 1,
		"a dropped item falls straight through the rope to the floor")
	# Rope QoL (FABLE_50 #39): length + anchor read from ANY segment; retract from any segment recovers ALL.
	_check(sim.rope_length(Vector2i(col, 8)) == 6, "rope_length counts the whole connected run from any segment")
	_check(sim.rope_anchor(Vector2i(col, 8)) == Vector2i(col, 4), "rope_anchor walks up to the top segment")
	_check(sim.rope_length(Vector2i(col, 10)) == 0, "no rope -> length 0")
	# CUT mid-rope: the segment and everything below return; the rope above stays hung.
	var cut: int = sim.remove_rope(Vector2i(col, 7))
	_check(cut == 3, "cutting mid-rope takes it + the tail below (%d/3)" % cut)
	_check(sim.is_climbable(Vector2i(col, 6)) and not sim.is_climbable(Vector2i(col, 8)), "the rope above the cut stays")
	_check(int(sim.inventory.get(&"rope", 0)) == 17, "cut segments returned to the pack")
	# RETRACT-ALL (#39): aim at the BOTTOM of the remaining hang — the whole rope comes back anyway.
	var got: int = sim.retract_rope(Vector2i(col, 6))
	_check(got == 3, "retract from a low segment recovers the whole hang via the anchor (%d/3)" % got)
	_check(not sim.is_climbable(Vector2i(col, 4)), "nothing left hanging after retract-all")
	_check(sim.retract_rope(Vector2i(col, 6)) == 0, "retracting where there is no rope is a no-op")
	_check(int(sim.inventory.get(&"rope", 0)) == 20, "every segment came home")
	var present_r: int = _items_present(sim, &"rope")
	var net_r: int = int(sim.total_produced.get(&"rope", 0)) - int(sim.total_consumed.get(&"rope", 0))
	_check(present_r == net_r, "rope conserved through place+cut+retract (present=%d, net=%d)" % [present_r, net_r])


## THE L2 IRON CHAIN (FABLE_50 #47, PROGRESSION §5 medium chains, CRAFTING.md modules): the two new
## techs gate the modules; the modules are pure recipe-runners behind their style tags; the chain runs
## GRAVITY-FED — iron dropped down a column smelts to iron ingots which fall into the press and come
## out plates on the floor; the gear mill is the first MULTI-INPUT module (iron + copper ingot must
## merge in one column — the vertical merge puzzle); conservation holds across the whole chain.
func _test_iron_chain() -> void:
	print("- the L2 iron chain (crafter modules)")
	var forge_def: MachineDef = load("res://src/data/machines/iron_forge.tres")
	var press_def: MachineDef = load("res://src/data/machines/plate_press.tres")
	var mill_def: MachineDef = load("res://src/data/machines/gear_mill.tres")
	var sim: FactorySim = FactorySim.new()
	_check(ResearchRules.locking_tech(&"iron_forge") == &"ironworks", "the iron forge gates on Ironworks")
	_check(ResearchRules.locking_tech(&"plate_press") == &"machining"
		and ResearchRules.locking_tech(&"gear_mill") == &"machining", "the modules gate on Machining")
	sim.inventory[&"ingot"] = 40; sim.total_produced[&"ingot"] = 40
	sim.inventory[&"iron"] = 12;  sim.total_produced[&"iron"] = 12
	_check(not sim.craft(forge_def), "the iron forge refuses before Ironworks")
	_check(not sim.research_tech(&"ironworks"), "Ironworks refuses before the L1 ladder is done")
	for t: StringName in [&"automation", &"power", &"descent"]:
		sim.research[t] = true
	_check(sim.research_tech(&"ironworks"), "Ironworks researches (iron sample + 10 ingots)")
	_check(sim.craft(forge_def), "the iron forge crafts")
	sim.inventory[&"iron_ingot"] = 7; sim.total_produced[&"iron_ingot"] = 7
	_check(sim.research_tech(&"machining"), "Machining researches — iron pays for iron")
	_check(sim.craft_unlocked(&"plate_press") and sim.craft_unlocked(&"gear_mill"),
		"Machining opens the module branch")
	# THE GRAVITY CHAIN: forge over press in ONE column; raw iron dropped in the top comes out plates
	# on the floor. (8 iron -> 4 iron ingots -> 2 plates, all falling stage to stage.)
	sim.set_solid(Vector2i(6, 8), &"stone")
	sim.place_machine(forge_def, Vector2i(6, 2))
	sim.place_machine(press_def, Vector2i(6, 5))
	sim.drop_item(Vector2i(6, 0), &"iron", 8)
	for _i: int in 500:
		sim.tick()
	var pile: Dictionary = sim.ground.get(Vector2i(6, 7), {})
	_check(int(pile.get(&"plate", 0)) == 2, "iron poured in the top comes out PLATES on the floor (%s)" % str(pile))
	# The MULTI-INPUT module: the mill waits until BOTH streams (iron ingot + copper ingot) have merged
	# into its column — CRAFTING.md's vertical merge puzzle, and the L1 copper line's continuing job.
	sim.set_solid(Vector2i(10, 5), &"stone")
	sim.place_machine(mill_def, Vector2i(10, 2))
	sim.inventory[&"iron_ingot"] = int(sim.inventory.get(&"iron_ingot", 0)) + 2
	sim.total_produced[&"iron_ingot"] = int(sim.total_produced.get(&"iron_ingot", 0)) + 2
	sim.drop_item(Vector2i(10, 0), &"iron_ingot", 2)
	for _i: int in 80:
		sim.tick()
	var mill_pile: Dictionary = sim.ground.get(Vector2i(10, 4), {})
	_check(int(mill_pile.get(&"gear", 0)) == 0, "the mill WAITS for both streams (starved on iron alone)")
	sim.drop_item(Vector2i(10, 0), &"ingot", 2)
	for _i: int in 200:
		sim.tick()
	mill_pile = sim.ground.get(Vector2i(10, 4), {})
	_check(int(mill_pile.get(&"gear", 0)) == 4, "iron+copper merged -> 2 gears per craft (%s)" % str(mill_pile))
	for item: StringName in [&"iron", &"iron_ingot", &"plate", &"gear", &"ingot"]:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present == net, "%s conserved through the chain (present=%d, net=%d)" % [item, present, net])


## ORE QUALITY (FABLE_50 #48): vein seeds landing in/below the deepslate band come up RICH — a distinct
## material (it READS in-world) whose chunk the Enrichment-gated BLAST FURNACE smelts 1 → 2 ingots.
## Deeper = richer gains its second axis: deep veins aren't just bigger, they're better.
func _test_rich_ore() -> void:
	print("- rich ore + the blast furnace (#48)")
	# Worldgen: rich veins exist, and only around/below the deepslate band (seeds are band-gated; a
	# grown blob may crest a few rows above its seed, never further).
	var gen := LayeredWorldGen.new()
	var world: WorldData = gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, 4242)
	var rich_cells: int = 0
	var too_shallow: int = 0
	for cell: Vector2i in world.blocks:
		if world.blocks[cell] == &"rich_ore":
			rich_cells += 1
			if cell.y < LayeredWorldGen.DEEPSLATE_ROW - 8:
				too_shallow += 1
	_check(rich_cells > 0, "worldgen seeded rich veins (%d cells)" % rich_cells)
	_check(too_shallow == 0, "rich ore stays a DEEP find (none far above the band; %d strays)" % too_shallow)
	_check(MiningRules.required_tier(&"rich_ore") == 2, "rich ore wants the tier-2 pick (the shelf's own gate)")
	# The research gate: the Blast Furnace crafts only once ENRICHMENT is in.
	var sim: FactorySim = FactorySim.new()
	var bf_def: MachineDef = load("res://src/data/machines/blast_furnace.tres")
	_check(ResearchRules.locking_tech(&"blast_furnace") == &"enrichment", "the Blast Furnace gates on Enrichment")
	sim.inventory[&"plate"] = 2; sim.total_produced[&"plate"] = 2
	sim.inventory[&"gear"] = 1; sim.total_produced[&"gear"] = 1
	_check(not sim.craft(bf_def), "the Blast Furnace refuses before Enrichment")
	for t: StringName in [&"automation", &"power", &"descent", &"ironworks", &"machining"]:
		sim.research[t] = true
	sim.inventory[&"rich_ore"] = 1; sim.total_produced[&"rich_ore"] = 1
	sim.inventory[&"iron_ingot"] = 4; sim.total_produced[&"iron_ingot"] = 4
	_check(sim.research_tech(&"enrichment"), "Enrichment researches (rich-ore sample + 4 iron ingots)")
	_check(sim.craft(bf_def), "…and the Blast Furnace crafts (2 plate + 1 gear)")
	# 1 rich ore → 2 ingots, gravity-fed, conserved (double the plain forge's 2-ore-per-ingot density).
	sim.set_solid(Vector2i(6, 6), &"stone")
	sim.place_machine(bf_def, Vector2i(6, 3))
	sim.inventory[&"rich_ore"] = int(sim.inventory.get(&"rich_ore", 0)) + 3
	sim.total_produced[&"rich_ore"] = int(sim.total_produced.get(&"rich_ore", 0)) + 3
	sim.drop_item(Vector2i(6, 1), &"rich_ore", 3)
	for _i: int in 400:
		sim.tick()
	var pile: Dictionary = sim.ground.get(Vector2i(6, 5), {})
	_check(int(pile.get(&"ingot", 0)) == 6, "3 rich ore poured in came out 6 ingots (%s)" % str(pile))
	for item: StringName in [&"rich_ore", &"ingot", &"plate", &"gear", &"iron_ingot"]:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present == net, "%s conserved through enrichment (present=%d, net=%d)" % [item, present, net])


## FILTERS, RATIOS & PASS-THROUGH (FABLE_50 #49 — the routing kit): (a) every recipe machine passes
## through what its recipe doesn't want (a mixed stream sorts ITSELF down a machine stack); (b) a
## hopper keeps the FIRST thing it tastes and passes the rest (R re-tastes); (c) the splitter's
## R-cycled ratio deals 2:1 / 1:2. Conservation everywhere.
func _test_filter_ratio_passthrough() -> void:
	print("- filters, ratios & pass-through")
	var hopper_def: MachineDef = load("res://src/data/machines/hopper.tres")
	var split_def: MachineDef = load("res://src/data/machines/splitter.tres")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	var gen_def: MachineDef = load("res://src/data/machines/generator.tres")
	# (a) PASS-THROUGH: ore+coal poured down one column; the forge keeps ore, coal pours past into
	# the generator below and BURNS. The stack sorts the stream with zero routing hardware.
	var sim: FactorySim = FactorySim.new()
	sim.set_solid(Vector2i(6, 9), &"stone")
	sim.place_machine(proc_def, Vector2i(6, 3))
	sim.place_machine(gen_def, Vector2i(6, 6))
	sim.inventory[&"ore"] = 4;  sim.total_produced[&"ore"] = 4
	sim.inventory[&"coal"] = 2; sim.total_produced[&"coal"] = 2
	sim.drop_item(Vector2i(6, 0), &"ore", 4)
	sim.drop_item(Vector2i(6, 0), &"coal", 2)
	for _i: int in 140:
		sim.tick()
	var forge: MachineState = sim.machine_at(Vector2i(6, 3))
	_check(not forge.input_buffer.has(&"coal"), "the forge PASSED the coal it can't smelt")
	_check(int(sim.total_consumed.get(&"coal", 0)) >= 1, "…and the generator below caught it and burns")
	_check(int(sim.total_produced.get(&"ingot", 0)) == 2, "the ore still smelted (2 ingots)")
	# (b) THE FILTER: the hopper keeps the first thing it tastes, passes the rest; R re-tastes.
	var s2: FactorySim = FactorySim.new()
	s2.set_solid(Vector2i(3, 7), &"stone")
	s2.place_machine(hopper_def, Vector2i(3, 3))
	s2.inventory[&"ore"] = 3;  s2.total_produced[&"ore"] = 3
	s2.inventory[&"coal"] = 3; s2.total_produced[&"coal"] = 3
	s2.drop_item(Vector2i(3, 0), &"ore", 3)
	for _i: int in 6:
		s2.tick()
	s2.drop_item(Vector2i(3, 0), &"coal", 3)
	for _i: int in 30:
		s2.tick()
	var hop: MachineState = s2.machine_at(Vector2i(3, 3))
	_check(hop.filter == &"ore", "the hopper latched the FIRST thing it tasted")
	_check(int(hop.input_buffer.get(&"ore", 0)) == 3, "…banks it (nothing below -> holds the stock)")
	_check(not hop.input_buffer.has(&"coal"), "…and passed the coal")
	_check(int((s2.ground.get(Vector2i(3, 6), {}) as Dictionary).get(&"coal", 0)) == 3,
		"the passed coal fell on down the column")
	_check(s2.configure_machine(Vector2i(3, 3)) != "", "R clears the filter (re-taste)")
	_check(hop.filter == &"", "…cleared")
	# (c) THE RATIO: 12 units through a 2:1-DOWN splitter = exactly 8 down, 4 right.
	var s3: FactorySim = FactorySim.new()
	s3.set_solid(Vector2i(6, 9), &"stone")
	s3.set_solid(Vector2i(7, 9), &"stone")
	s3.place_machine(split_def, Vector2i(6, 2))
	var label: String = s3.configure_machine(Vector2i(6, 2))
	_check(label.contains("2:1"), "R cycles the splitter ratio (%s)" % label)
	s3.inventory[&"ore"] = 12; s3.total_produced[&"ore"] = 12
	s3.drop_item(Vector2i(6, 0), &"ore", 12)
	for _i: int in 80:
		s3.tick()
	var down_n: int = int((s3.ground.get(Vector2i(6, 8), {}) as Dictionary).get(&"ore", 0))
	var right_n: int = int((s3.ground.get(Vector2i(7, 8), {}) as Dictionary).get(&"ore", 0))
	_check(down_n == 8 and right_n == 4, "2:1 DOWN dealt exactly 8/4 (got %d/%d)" % [down_n, right_n])
	_check(s3.configure_machine(Vector2i(6, 2)).contains("1:2"), "…cycles on to 1:2 RIGHT")
	_check(s3.configure_machine(Vector2i(6, 2)).contains("even"), "…and wraps to even")
	for pair: Array in [[sim, &"ore"], [sim, &"coal"], [s2, &"ore"], [s2, &"coal"], [s3, &"ore"]]:
		var s: FactorySim = pair[0]
		var item: StringName = pair[1]
		var present: int = _items_present(s, item)
		var net: int = int(s.total_produced.get(item, 0)) - int(s.total_consumed.get(item, 0))
		_check(present == net, "%s conserved (present=%d, net=%d)" % [item, present, net])


## THE HORIZONTAL DRILL / the Borer (FABLE_50 #46, the user's spec): bores sideways along its facing,
## burns coal per bite, feeds bored COAL to its own fuel bunker, bellies everything else, and honours
## the ON-HOOK rule — its haul exits DOWN its own column only; sealed on rock it POOLS (never spills
## into the tunnel), and stalls at the 5-slot belly cap. Conservation across the whole gallery.
func _test_h_drill() -> void:
	print("- the horizontal drill (the Borer)")
	var hd_def: MachineDef = load("res://src/data/machines/h_drill.tres")
	var sim: FactorySim = FactorySim.new()
	_check(ResearchRules.locking_tech(&"h_drill") == &"machining", "the Borer gates on Machining")
	# A sealed tunnel: the borer sits on solid rock (NO drain), a 4-cell face to its right with a
	# 2-unit coal seam in the middle.
	sim.set_solid(Vector2i(6, 6), &"stone")
	for x: int in range(7, 11):
		sim.set_solid(Vector2i(x, 5), &"earth")
	sim.set_solid(Vector2i(8, 5), &"coal")
	sim.deposits[Vector2i(8, 5)] = 2
	var m: MachineState = sim.place_machine(hd_def, Vector2i(6, 5))
	m.facing = 1
	_check(sim.machine_status(m) == &"no_fuel", "dark without coal")
	for _i: int in 80:
		sim.tick()
	_check(sim.is_solid(Vector2i(7, 5)), "no coal, no boring")
	sim.inventory[&"coal"] = 3; sim.total_produced[&"coal"] = 3
	sim.deposit(Vector2i(6, 5), &"coal", 3)                  # hand-feed the bunker
	for _i: int in 40:                                       # one 1.5s cycle + slack
		sim.tick()
	_check(not sim.is_solid(Vector2i(7, 5)), "the first bite cleared the face")
	_check(int(m.output_buffer.get(&"earth", 0)) == 1, "the haul sits in the BELLY (no drain below)")
	_check(sim.ground.is_empty(), "nothing spilled onto the tunnel floor (on-hook: no lateral piles)")
	for _i: int in 260:                                      # the rest of the gallery (6 bites total)
		sim.tick()
	_check(not sim.is_solid(Vector2i(8, 5)) and not sim.is_solid(Vector2i(10, 5)),
		"the gallery ran through the coal seam to its last cell")
	_check(int(m.output_buffer.get(&"earth", 0)) == 3, "belly holds the bored earth")
	_check(not m.output_buffer.has(&"coal"), "bored coal fed the FUEL BUNKER, not the belly")
	_check(sim.machine_status(m) == &"no_input", "gallery spent -> idle (carry it to a new face)")
	# THE DRAIN: open the floor under it and the belly pours down its OWN column (the on-hook rule).
	sim.set_solid(Vector2i(6, 8), &"stone")                  # a catch floor two below
	sim.set_solid(Vector2i(6, 6), &"")
	for _i: int in 3:
		sim.tick()
	_check(m.output_buffer.is_empty(), "the belly drained the moment a drain opened")
	_check(int((sim.ground.get(Vector2i(6, 7), {}) as Dictionary).get(&"earth", 0)) == 3,
		"…straight down its own column onto the catch floor")
	for item: StringName in [&"earth", &"coal"]:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present == net, "%s conserved through the gallery (present=%d, net=%d)" % [item, present, net])
	# The 5-slot belly cap + facing LEFT, on a second rig.
	var s2: FactorySim = FactorySim.new()
	s2.set_solid(Vector2i(3, 3), &"stone")                   # sealed floor
	s2.set_solid(Vector2i(2, 2), &"earth")                   # a face to the LEFT
	var m2: MachineState = s2.place_machine(hd_def, Vector2i(3, 2))
	m2.facing = -1
	m2.input_buffer[&"coal"] = 1
	s2.total_produced[&"coal"] = 1; s2.inventory[&"coal"] = 0
	for it: StringName in [&"a", &"b", &"c", &"d", &"e"]:    # five stacks already in the belly
		m2.output_buffer[it] = 1
	_check(s2.machine_status(m2) == &"blocked", "a full 5-slot belly stalls the bit (blocked: empty me)")
	m2.output_buffer.clear()
	for _i: int in 40:
		s2.tick()
	_check(not s2.is_solid(Vector2i(2, 2)), "facing -1 bores LEFT")


## SAVE/LOAD (FABLE_50 #1) — capture → restore must round-trip the WHOLE authoritative state, and
## determinism is the verifier: a restored sim ticked N times must match the original ticked N times,
## signature + dict for dict. Also: the version gate, the unknown-def gate (both leave the sim
## untouched), and a real disk round-trip through the binary Variant format.
func _test_save_load() -> void:
	print("- save/load (versioned, determinism-verified)")
	var vent_def: MachineDef = load("res://src/data/machines/ore_vent.tres")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	var gen_def: MachineDef = load("res://src/data/machines/generator.tres")
	var sim: FactorySim = FactorySim.new()
	# A busy little world: terrain + wall + a deposit, a producing line, a fueled generator,
	# conduit/rope/torch layers, research, pack + ground items.
	sim.set_solid(Vector2i(6, 8), &"stone")
	sim.set_solid(Vector2i(7, 8), &"ore")
	sim.set_wall(Vector2i(6, 7), &"earth")
	sim.deposits[Vector2i(7, 8)] = 123
	sim.place_machine(vent_def, Vector2i(6, 0))
	sim.place_machine(proc_def, Vector2i(6, 3))
	sim.place_machine(gen_def, Vector2i(9, 8))
	sim.inventory[&"coal"] = 3;  sim.total_produced[&"coal"] = 3
	sim.deposit(Vector2i(9, 8), &"coal", 2)
	sim.inventory[&"conduit"] = 2; sim.total_produced[&"conduit"] = 2
	sim.place_conduit(Vector2i(9, 7))
	sim.inventory[&"rope"] = 4;  sim.total_produced[&"rope"] = 4
	sim.place_rope(Vector2i(6, 6))
	sim.inventory[&"torch"] = 1; sim.total_produced[&"torch"] = 1
	sim.place_torch(Vector2i(6, 7))
	sim.inventory[&"ore"] = 3;   sim.total_produced[&"ore"] = 3
	sim.research[&"automation"] = true      # state set directly — research_tech's costs aren't the subject
	for _i: int in 90:
		sim.tick()
	var data: Dictionary = SaveGame.capture(sim)
	# Version gate + unknown-def gate: both refuse and leave the target untouched.
	var fresh: FactorySim = FactorySim.new()
	var bad_ver: Dictionary = data.duplicate(true); bad_ver["version"] = 99
	_check(not SaveGame.restore(fresh, bad_ver), "an unknown save version refuses")
	var bad_def: Dictionary = data.duplicate(true)
	(bad_def["machines"] as Array)[0]["def"] = "bogus_machine"
	_check(not SaveGame.restore(fresh, bad_def), "an unknown machine def refuses")
	_check(fresh.machines.is_empty() and fresh.solid.is_empty(), "a refused restore leaves the sim untouched")
	# The real round-trip — through DISK, not just memory.
	var path: String = "user://test_sinkforge.save"
	_check(SaveGame.write(path, data), "the envelope writes to disk")
	var back: Dictionary = SaveGame.read(path)
	_check(not back.is_empty(), "…and reads back")
	var sim2: FactorySim = FactorySim.new()
	_check(SaveGame.restore(sim2, back), "the restore lands")
	_check(sim2.solid == sim.solid and sim2.wall == sim.wall and sim2.deposits == sim.deposits,
		"terrain + walls + deposits round-trip")
	_check(sim2.inventory == sim.inventory and sim2.ground == sim.ground and sim2.sink == sim.sink,
		"pack + ground + sink round-trip")
	_check(sim2.conduit == sim.conduit and sim2.rope == sim.rope and sim2.torch == sim.torch,
		"the placed layers round-trip")
	_check(sim2.research == sim.research, "research round-trips")
	_check(sim2.machines.size() == sim.machines.size(), "every machine came back")
	var gen2: MachineState = sim2.machine_at(Vector2i(9, 8))
	var gen1: MachineState = sim.machine_at(Vector2i(9, 8))
	_check(gen2 != null and gen2.def.id == &"generator" and gen2.fuel == gen1.fuel,
		"machine runtime state (fuel mid-burn) survives")
	# THE determinism proof: both sims run on, in lockstep, forever.
	for _i: int in 120:
		sim.tick()
		sim2.tick()
	_check(_state_signature(sim) == _state_signature(sim2),
		"restored sim stays in LOCKSTEP with the original (120 ticks on)")
	_check(sim.sink == sim2.sink and sim.total_produced == sim2.total_produced,
		"…down to the ledgers")
	DirAccess.remove_absolute(path)


## TORCHES (FABLE_50 #26) — the placeable light, a placed layer like rope: mounts only on a backed
## open cell (wall behind or a solid neighbour — no floating lights in the sky), refuses solids/
## machines/doubles, blocks solids/machines from its cell, returns to the pack on removal, and the
## item satisfies the total ledger. The light it casts is representation — nothing here to test.
func _test_torch() -> void:
	print("- torches (placeable light)")
	var sim: FactorySim = FactorySim.new()
	sim.set_solid(Vector2i(8, 10), &"stone")                  # a cave floor
	var spot := Vector2i(8, 9)                                # open, atop the floor (solid neighbour below)
	_check(not sim.place_torch(spot), "no torch carried -> refused")
	sim.inventory[&"torch"] = 3
	sim.total_produced[&"torch"] = 3
	_check(not sim.place_torch(Vector2i(3, 2)), "a floating sky cell refuses (nothing to mount on)")
	sim.set_wall(Vector2i(3, 2), &"earth")
	_check(sim.place_torch(Vector2i(3, 2)), "a wall-backed open cell mounts")
	_check(sim.place_torch(spot), "a rock-adjacent open cell mounts")
	_check(not sim.place_torch(spot), "no double-mount")
	_check(not sim.place_torch(Vector2i(8, 10)), "cannot mount inside solid rock")
	_check(int(sim.inventory.get(&"torch", 0)) == 1, "each mount spent one carried torch")
	sim.inventory[&"earth"] = 1
	sim.total_produced[&"earth"] = 1
	_check(not sim.place_block(spot, &"earth"), "a block cannot be placed into a torch cell")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	_check(sim.place_machine(proc_def, spot) == null, "a machine cannot be placed into a torch cell")
	_check(sim.remove_torch(spot), "removal takes the torch back")
	_check(not sim.has_torch(spot) and int(sim.inventory.get(&"torch", 0)) == 2, "…into the pack")
	_check(ResearchRules.locking_tech(&"torch") == &"", "torches are research-UNGATED (never lock the light)")
	var present_t: int = _items_present(sim, &"torch")
	var net_t: int = int(sim.total_produced.get(&"torch", 0)) - int(sim.total_consumed.get(&"torch", 0))
	_check(present_t == net_t, "torch conserved through mount+remove (present=%d, net=%d)" % [present_t, net_t])


## WATER (L3 Aquifer/fluids, first slice) — the discrete-cell integer fluid. Deterministic sim-level:
## it FALLS on the hook (down for free), SETTLES to a flat top, never enters/coexists with solid rock,
## conserves total across ticks, and two identical sims flow byte-identically. Sim-only — no render yet.
func _test_water_fluid() -> void:
	print("- water (L3 fluid primitive)")

	# Helpers scoped to this test.
	var no_water_in_solid := func(s: FactorySim) -> bool:
		for cv: Variant in s.water:
			if s.solid.has(cv as Vector2i):
				return false
		return true

	# --- 1. GRAVITY: pour at the top of a walled open shaft; it all ends at the bottom. ---
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

	# --- 2. SETTLE FLAT: pour a blob into a wide walled basin; the surface flattens. ---
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
	# Surface is FLAT: the wettest ROW of the basin has all its wet cells within 1 unit of each other.
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

	# --- 3. BLOCKED BY SOLID: placing rock into a watered cell clears that cell's water. ---
	var d: FactorySim = FactorySim.new()
	d.add_water(Vector2i(3, 3), 5)                            # a lone puddle, walled so it can't move
	for dxy: Vector2i in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		d.set_solid(Vector2i(3, 3) + dxy, &"stone")           # floor + both walls trap it in place
	_check(d.water_at(Vector2i(3, 3)) == 5 and d.total_water() == 5, "puddle trapped, 5 units present")
	var before_disp: int = d.total_water()
	d.set_solid(Vector2i(3, 3), &"stone")                     # rock over the watered cell displaces it
	_check(d.water_at(Vector2i(3, 3)) == 0, "set_solid onto a watered cell clears its water")
	_check(d.total_water() == before_disp - 5, "total dropped by exactly the displaced cell's level (5)")
	# The mirror path — placing a carried block into a watered cell also displaces it.
	var d2: FactorySim = FactorySim.new()
	d2.add_water(Vector2i(2, 2), 4)
	d2.inventory[&"stone"] = 1; d2.total_produced[&"stone"] = 1
	d2.set_solid(Vector2i(2, 3), &"stone")                    # a floor to build off (block_supported)
	_check(d2.place_block(Vector2i(2, 2), &"stone"), "place_block lands on the watered cell")
	_check(d2.water_at(Vector2i(2, 2)) == 0, "place_block onto a watered cell displaces its water too")

	# --- 4. CONSERVATION across many ticks with no source/drain. ---
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

	# --- 5. DETERMINISM: two identically-built, identically-poured sims tick to identical water. ---
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


## THE PULL — research at the Bazaar bench (docs/PROGRESSION.md §5): locked machines refuse to craft
## until their tech is researched; researching consumes an analyze-SAMPLE + refined ingots (both
## ledgered); prereqs order the ladder; and every tech's unlock list points at a real machine def.
func _test_research() -> void:
	print("- research (the PULL)")
	var drill_def: MachineDef = load("res://src/data/machines/drill.tres")
	var sim: FactorySim = FactorySim.new()
	sim.inventory[&"ingot"] = 20; sim.total_produced[&"ingot"] = 20
	sim.inventory[&"ore"] = 2;    sim.total_produced[&"ore"] = 2
	_check(not sim.craft(drill_def), "the drill refuses to craft before Automation is researched")
	_check(not sim.research_tech(&"power"), "power refuses before its prereq (automation)")
	_check(not sim.research_tech(&"bogus_tech"), "an unknown tech refuses")
	var s2: FactorySim = FactorySim.new()
	s2.inventory[&"ingot"] = 20; s2.total_produced[&"ingot"] = 20
	_check(not s2.research_tech(&"automation"), "research refuses WITHOUT the analyze-sample (no ore held)")
	_check(sim.research_tech(&"automation"), "automation researches with an ore sample + the ingot price")
	_check(sim.is_researched(&"automation"), "the tech is recorded")
	_check(int(sim.inventory.get(&"ore", 0)) == 1, "analyzing consumed ONE ore sample")
	_check(int(sim.inventory.get(&"ingot", 0)) == 18, "the bench consumed the ingot price")
	_check(not sim.research_tech(&"automation"), "a researched tech refuses a second spend")
	_check(sim.craft(drill_def), "the drill crafts once Automation is researched")
	_check(not sim.craft_unlocked(&"generator"), "the generator stays locked behind Power")
	sim.inventory[&"coal"] = 1; sim.total_produced[&"coal"] = 1
	_check(sim.research_tech(&"power"), "power researches after automation (coal sample + 12 ingots)")
	_check(sim.craft_unlocked(&"generator") and sim.craft_unlocked(&"lift"), "power opened its branch")
	for item: StringName in [&"ore", &"ingot", &"coal", &"drill"]:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present == net, "%s conserved through the research flow (present=%d, net=%d)" % [item, present, net])
	# Tree contract: every unlock id resolves to a real machine def OR a tool recipe (a typo'd id
	# would gate nothing). The scanner is the first TOOL unlock (Prospecting).
	for tid: StringName in ResearchRules.TECHS:
		for uid: StringName in (ResearchRules.TECHS[tid]["unlocks"] as Array):
			var path: String = "res://src/data/machines/%s.tres" % uid
			_check(ResourceLoader.exists(path) or MiningRules.TOOL_RECIPES.has(uid),
				"%s unlock '%s' resolves to a machine def or a tool recipe" % [tid, uid])


## THE DESCENT GATE — the L1→L2 throughput wall (docs/PROGRESSION.md §2/§9). Worldgen guarantees an
## UNBROKEN sealrock band with a mineable deepslate SHELF above and IRON only below; no pick opens it;
## the Descent Engine eats gravity-fed ingots on the seal (a true sink, quota-capped), passes every
## other item through, and at quota BREACHES the shaft down — piles on the seal falling with it.
func _test_descent_gate() -> void:
	print("- the descent gate (L1→L2)")
	var gen: LayeredWorldGen = LayeredWorldGen.new()
	var world: WorldData = gen.generate(96, 80, 1337)
	var holes: int = 0
	for row: int in range(LayeredWorldGen.SEAL_TOP, LayeredWorldGen.SEAL_TOP + LayeredWorldGen.SEAL_ROWS):
		for col: int in world.cols:
			if world.blocks.get(Vector2i(col, row), &"") != &"sealrock":
				holes += 1
	_check(holes == 0, "the seal band is UNBROKEN across the world (holes=%d)" % holes)
	var iron_below: int = 0
	var iron_above: int = 0
	var shelf: int = 0
	for cell: Vector2i in world.blocks:
		if world.blocks[cell] == &"iron":
			if cell.y >= LayeredWorldGen.SEAL_TOP + LayeredWorldGen.SEAL_ROWS:
				iron_below += 1
			else:
				iron_above += 1
		elif world.blocks[cell] == &"deepslate" and cell.y < LayeredWorldGen.SEAL_TOP:
			shelf += 1
	_check(iron_below > 0 and iron_above == 0,
		"IRON seeds only below the seal (below=%d above=%d)" % [iron_below, iron_above])
	_check(shelf > 0, "a mineable deepslate SHELF sits above the seal (%d cells — the Descent sample)" % shelf)
	_check(not MiningRules.can_mine(&"sealrock", {&"stone_pickaxe": 1, &"wood_pickaxe": 1}),
		"no pick can mine sealrock — the wall is not a tool gate")
	# The engine, in a fixture: seal at rows 10-11, engine hung above it, an L2 floor at 14.
	var eng_def: MachineDef = load("res://src/data/machines/descent_engine.tres")
	var sim: FactorySim = FactorySim.new()
	var col2: int = 5
	sim.set_solid(Vector2i(col2, 10), &"sealrock")
	sim.set_solid(Vector2i(col2, 11), &"sealrock")
	sim.set_solid(Vector2i(col2, 14), &"stone")
	var eng: MachineState = sim.place_machine(eng_def, Vector2i(col2, 8))
	sim.inventory[&"ingot"] = FactorySim.DESCENT_QUOTA + 5
	sim.total_produced[&"ingot"] = FactorySim.DESCENT_QUOTA + 5
	sim.inventory[&"coal"] = 2
	sim.total_produced[&"coal"] = 2
	sim.deposit(Vector2i(col2, 8), &"coal", 2)
	sim.deposit(Vector2i(col2, 8), &"ingot", 10)
	for _i: int in 30:
		sim.tick()
	_check(eng.fed == 10, "the engine ate the first ingots (fed=%d/10)" % eng.fed)
	_check(sim.is_solid(Vector2i(col2, 10)), "the seal holds below quota")
	var coal_rest: int = int((sim.ground.get(Vector2i(col2, 9), {}) as Dictionary).get(&"coal", 0))
	_check(coal_rest == 2, "non-ingot goods pass THROUGH the engine and pile on the seal (%d coal)" % coal_rest)
	sim.deposit(Vector2i(col2, 8), &"ingot", FactorySim.DESCENT_QUOTA - 10 + 5)   # the rest + 5 over
	for _i: int in 30:
		sim.tick()
	_check(eng.fed == FactorySim.DESCENT_QUOTA, "the quota fills and CAPS (fed=%d)" % eng.fed)
	_check(not sim.is_solid(Vector2i(col2, 10)) and not sim.is_solid(Vector2i(col2, 11)),
		"THE BREACH: the seal bored open straight down")
	_check(sim.machine_status(eng) == &"idle", "a breached engine reads done (idle)")
	var l2_pile: Dictionary = sim.ground.get(Vector2i(col2, 13), {}) as Dictionary
	_check(int(l2_pile.get(&"coal", 0)) == 2 and int(l2_pile.get(&"ingot", 0)) == 5,
		"the seal-top pile + the overfeed FELL through the breach to the L2 floor (%s)" % str(l2_pile))
	for item: StringName in [&"ingot", &"coal"]:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present == net, "%s conserved through the gate (present=%d, net=%d)" % [item, present, net])
	# A misplaced engine (no seal below) eats NOTHING — everything passes through; status says so.
	var s2: FactorySim = FactorySim.new()
	s2.set_solid(Vector2i(3, 6), &"stone")
	var lost: MachineState = s2.place_machine(eng_def, Vector2i(3, 3))
	s2.inventory[&"ingot"] = 4
	s2.total_produced[&"ingot"] = 4
	s2.deposit(Vector2i(3, 3), &"ingot", 4)
	for _i: int in 20:
		s2.tick()
	_check(lost.fed == 0, "a misplaced engine eats nothing")
	_check(s2.machine_status(lost) == &"blocked", "…and reads blocked (stand it ON the seal)")
	_check(int((s2.ground.get(Vector2i(3, 5), {}) as Dictionary).get(&"ingot", 0)) == 4,
		"…and its ingots pass through untouched")
	# The craft gate: the engine stays locked until Descent is researched (power → descent ladder).
	var s3: FactorySim = FactorySim.new()
	_check(not s3.craft_unlocked(&"descent_engine"), "the engine is locked at boot")
	s3.inventory = {&"ore": 1, &"coal": 1, &"deepslate": 1, &"ingot": 40}
	s3.total_produced = {&"ore": 1, &"coal": 1, &"deepslate": 1, &"ingot": 40}
	s3.research_tech(&"automation")
	s3.research_tech(&"power")
	_check(s3.research_tech(&"descent"), "Descent researches after Power (deepslate sample + ingots)")
	_check(s3.craft_unlocked(&"descent_engine"), "…and unlocks the engine")


## The FACTORY OUT-PRODUCES the descent WALL (Belongs F1, docs/DESIGN_REVIEW.md — the anti-speedrun pillar,
## PROGRESSION §2). DESCENT_QUOTA is a THROUGHPUT wall you point production at, not a countable pile you
## hand-carry. This proves that HONESTLY at the sim level: a fully AUTOMATED line — a drill boring a solid
## ore vein → a forge smelting the ore into ingots → the Descent Engine eating them off gravity — fills the
## quota and BREACHES the seal with NO hand intervention, well inside a bounded tick budget. Mirrors
## _test_automated_line's drill→forge column, then stacks the engine over the seal like _test_descent_gate.
func _test_descent_automation() -> void:
	print("- descent gate out-produced by an automated line")
	var drill_def: MachineDef = load("res://src/data/machines/drill.tres")
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	var eng_def: MachineDef = load("res://src/data/machines/descent_engine.tres")
	var sim: FactorySim = FactorySim.new()
	var col: int = 8
	# The line, top-down in ONE column so gravity/_flow threads it (mirrors _test_automated_line):
	#   drill (row 4) bores the solid ore vein (row 5) → ore falls into the forge (row 6) → 2 ore smelt to
	#   1 ingot → the ingot falls into the Descent Engine (row 8) → at quota it BREACHES the seal (rows 9-10).
	var ore := Vector2i(col, 5)
	# A vein rich enough to yield the whole quota: 2 ore per ingot, so DESCENT_QUOTA*2 ore + a safety margin.
	sim.set_solid(ore, &"ore"); sim.deposits[ore] = FactorySim.DESCENT_QUOTA * 2 + 20
	var drill: MachineState = sim.place_machine(drill_def, Vector2i(col, 4))
	sim.place_machine(proc_def, Vector2i(col, 6))            # forge below the vein, catches the bored ore
	var eng: MachineState = sim.place_machine(eng_def, Vector2i(col, 8))  # engine catches the forge's ingots
	sim.set_solid(Vector2i(col, 9), &"sealrock")            # THE SEAL below the engine (rows 9-10)
	sim.set_solid(Vector2i(col, 10), &"sealrock")
	sim.set_solid(Vector2i(col, 14), &"stone")             # an L2 floor to catch the breach spillover
	# Fuel the drill ONCE at the start; the player does NOTHING after (the whole point — automation).
	var coal_fuel: int = FactorySim.DESCENT_QUOTA * 2 + 40
	drill.input_buffer[&"coal"] = coal_fuel
	sim.total_produced[&"coal"] = coal_fuel                 # book the fuel so conservation balances
	# Budget: the forge is the throughput floor (2.0 s/ingot = 40 ticks → 64 ingots ≈ 2560 ticks); the drill
	# keeps pace (1.0 s/ore = 20 ticks; 128 ore ≈ 2560 ticks). 4000 ticks (~200 s @ 20 Hz) is a comfortable
	# ceiling — legible & ratchetable via the printed actual-ticks margin below.
	var budget: int = 4000
	var breach_tick: int = -1
	for t: int in budget:
		sim.tick()
		if eng.fed >= FactorySim.DESCENT_QUOTA:
			breach_tick = t + 1
			break
	_check(breach_tick >= 0,
		"the AUTOMATED line reached the quota within %d ticks (fed=%d/%d)" % [budget, eng.fed, FactorySim.DESCENT_QUOTA])
	if breach_tick >= 0:
		print("    (out-produced the gate in %d ticks — %d-tick margin under the %d budget)"
			% [breach_tick, budget - breach_tick, budget])
	_check(eng.fed >= FactorySim.DESCENT_QUOTA,
		"the engine ate a full quota of ingots off gravity, hands-free (fed=%d)" % eng.fed)
	_check(not sim.is_solid(Vector2i(col, 9)) and not sim.is_solid(Vector2i(col, 10)),
		"THE BREACH: the automated feed bored the seal open — the factory descends")
	# Conservation stays clean across the whole automated pipeline (nothing leaked or duplicated).
	for item: StringName in [&"ore", &"ingot", &"coal"]:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present == net, "%s conserved through the automated gate (present=%d, net=%d)" % [item, present, net])


## HINT BUBBLES (FABLE_50 #35 — scenes/hints.gd, representation-only): a hint fires exactly once, on the
## acquisition EDGE (0 → >0 this session); pre-stocked packs fire nothing; simultaneous triggers queue
## one-at-a-time; resync() (after a load) re-arms the snapshot without re-teaching.
func _test_hints() -> void:
	print("[hints]")
	var sim: FactorySim = FactorySim.new()
	var hints: Hints = Hints.new(sim)
	hints.refresh(0.016)
	_check(hints.active_text() == "", "no hint on an empty pack")
	sim.inventory[&"rope"] = 1
	hints.refresh(0.016)
	_check(hints.active_text().begins_with("ROPE"), "first rope in the pack teaches the rope")
	hints.refresh(0.1)   # the fade-in starts at 0 on the activation frame — advance into it
	_check(hints.active_alpha() > 0.0, "…with a live fade envelope")
	hints.refresh(Hints.SHOW_SECONDS + 1.0)
	_check(hints.active_text() == "", "the bubble expires")
	sim.inventory.erase(&"rope")
	hints.refresh(0.016)
	sim.inventory[&"rope"] = 3
	hints.refresh(0.016)
	_check(hints.active_text() == "", "re-acquiring never re-teaches (latched)")
	# Two acquisitions in one frame queue: the second shows after the first expires.
	sim.inventory[&"torch"] = 4
	sim.inventory[&"generator"] = 1
	hints.refresh(0.016)
	_check(hints.active_text().begins_with("TORCH"), "simultaneous triggers show one bubble at a time")
	hints.refresh(Hints.SHOW_SECONDS + 1.0)
	hints.refresh(0.016)
	_check(hints.active_text().begins_with("GENERATOR"), "…the second queues behind it")
	# A pre-stocked pack (dev kit / loaded save) fires nothing at construction.
	var s2: FactorySim = FactorySim.new()
	s2.inventory[&"lift"] = 1
	var h2: Hints = Hints.new(s2)
	h2.refresh(0.016)
	_check(h2.active_text() == "", "a pre-stocked pack fires nothing at boot")
	s2.inventory[&"hopper"] = 1
	h2.refresh(0.016)
	_check(h2.active_text().begins_with("HOPPER"), "…but a genuinely new item still teaches")
	h2.resync()
	_check(h2.active_text() == "", "resync clears the live bubble (post-load)")
	s2.inventory[&"splitter"] = 2
	h2.refresh(0.016)
	_check(h2.active_text().begins_with("SPLITTER"), "resync re-arms edges for what comes after")


## FALLING-ITEM POOLING + CAP (FABLE_50 #5 — scenes/falling_items.gd, cosmetic layer): live drops are
## HARD-CAPPED (the abstract flow layer is authoritative, extra visuals are pure churn); retired drops
## recycle through a pool; the motes() scratch tracks the live count. Behavioral only — no allocation
## probes, just the observable contract the pool must keep.
func _test_falling_pool() -> void:
	print("[falling pool]")
	var falling: FallingItems = FallingItems.new()
	for i: int in FallingItems.MAX_ITEMS + 50:
		falling.inject(Vector2.ZERO, Vector2(0.0, 64.0), Color.WHITE)
	_check(falling.size() == FallingItems.MAX_ITEMS,
		"live drops hard-cap at MAX_ITEMS (%d)" % falling.size())
	_check(falling.motes().size() == FallingItems.MAX_ITEMS, "motes track the live count")
	falling.advance(FallingItems.FALL_DURATION * 0.5)
	_check(falling.size() == FallingItems.MAX_ITEMS, "mid-flight drops survive advance")
	falling.advance(FallingItems.FALL_DURATION)
	_check(falling.size() == 0, "arrived drops all retire")
	_check(falling.motes().is_empty(), "…and the motes scratch drains with them")
	# Retired drops feed the next spawns (the pool path) with the same observable behavior.
	falling.inject(Vector2.ZERO, Vector2(0.0, 32.0), Color.RED, 0.25)
	_check(falling.size() == 1, "post-retire spawns fly again (pool reuse path)")
	var m: Dictionary = falling.motes()[0]
	_check(m["color"] == Color.RED and (m["pos"] as Vector2).y > 0.0,
		"a reused drop carries ITS OWN fields, not the retired one's")


## THE SCANNER (FABLE_50 #27): the first TOOL behind research — Prospecting (the tree's first branch)
## gates crafting it via the SAME sim-level craft_unlocked gate machines use; ungated tools stay free.
## The scan itself is a pure query (zero sim state), so what's testable headless is the gate + pacing.
func _test_scanner() -> void:
	print("[scanner]")
	var sim: FactorySim = FactorySim.new()
	var recipe: Dictionary = MiningRules.TOOL_RECIPES[&"scanner"]
	sim.inventory = {&"ingot": 20, &"ore": 3, &"coal": 3}
	sim.total_produced = {&"ingot": 20, &"ore": 3, &"coal": 3}
	_check(not sim.craft_item(&"scanner", recipe), "the scanner refuses to craft before Prospecting")
	sim.inventory[&"stone"] = 8
	sim.inventory[&"wood"] = 3
	sim.total_produced[&"stone"] = 8
	sim.total_produced[&"wood"] = 3
	_check(sim.craft_item(&"stone_pickaxe", MiningRules.TOOL_RECIPES[&"stone_pickaxe"]),
		"a research-free tool still crafts on materials alone (the gate touches only locked ids)")
	_check(sim.research_tech(&"automation"), "automation researches")
	_check(ResearchRules.next_tech(sim.research) == &"prospecting",
		"the bench's next rung after Automation is Prospecting (before the Power wall)")
	_check(sim.research_tech(&"prospecting"), "prospecting researches (ore sample + 4 ingots)")
	_check(sim.craft_item(&"scanner", recipe), "…and the scanner crafts")
	_check(int(sim.inventory.get(&"scanner", 0)) == 1, "one scanner in the pack")
	_check(MiningRules.is_tool_item(&"scanner"), "the scanner is EQUIPMENT (never machine-feedable)")
	_check(not MiningRules.can_mine(&"stone", {&"scanner": 1}),
		"…and its class never satisfies a pick gate (a lone scanner can't crack stone)")
	for item: StringName in [&"ingot", &"ore", &"coal", &"stone", &"wood", &"scanner"]:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present == net, "%s conserved through research + craft (present=%d, net=%d)" % [item, present, net])


## FINE TERRAIN (docs/FINE_TERRAIN.md P2 — the dual-grid overhaul). The fine grid is ADDITIVE + DERIVED:
## it must be (a) deterministic from seed, (b) NEVER change the coarse authority that ALL logistics read,
## (c) stay in sync when a coarse cell is edited, and (d) rebuild identically after a load. If any of these
## breaks, the locked hook or the save format is at risk — so this is a guardrail, not a feature test.
func _test_fine_terrain() -> void:
	print("[fine terrain]")
	var gen: WorldGen = LayeredWorldGen.new()
	var world: WorldData = gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, 1337)

	# (a) DETERMINISM — same seed → identical fine array across two independent loads.
	var s1: FactorySim = FactorySim.new()
	s1.load_world(world)
	var s2: FactorySim = FactorySim.new()
	s2.load_world(gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, 1337))
	_check(s1.fine_w() == FactorySim.GRID_COLS * FactorySim.SUBDIV
		and s1.fine_h() == FactorySim.GRID_ROWS * FactorySim.SUBDIV, "fine grid is SUBDIV× the coarse grid")
	_check(_fine_checksum(s1) == _fine_checksum(s2), "same seed → identical fine array (deterministic)")
	# The fine grid has REAL detail: some fine cells differ from a pure 4× upscale of the coarse grid
	# (the boundary molding erodes/accretes edges) — proving it's fine DATA, not just a stretched coarse mask.
	var molded: int = 0
	var solid_fine: int = 0
	for fy: int in s1.fine_h():
		for fx: int in s1.fine_w():
			var here: bool = s1.fine_is_solid(fx, fy)
			if here:
				solid_fine += 1
			if here != s1.is_solid(Vector2i(fx / FactorySim.SUBDIV, fy / FactorySim.SUBDIV)):
				molded += 1
	_check(solid_fine > 0, "the fine grid has solid rock in it (%d cells)" % solid_fine)
	_check(molded > 200, "fine molding bends the coarse boundary (%d fine cells differ from coarse)" % molded)

	# (b) COARSE UNCHANGED — the coarse solid/material for a fixed seed must be IDENTICAL to what it was
	# before the fine layer existed. We prove the fine layer is purely additive two ways: the coarse
	# checksum matches a second independent load, and known interior cells read exactly as the coarse
	# grid intends (a solid earth cell stays solid earth; a carved cave stays open).
	_check(_coarse_checksum(s1) == _coarse_checksum(s2), "coarse solid grid identical across loads (fine is additive)")
	# The world is generated at exactly GRID_COLS×GRID_ROWS, so every block is in bounds → solid == blocks.
	_check(s1.solid == world.blocks, "coarse solid == the ingested WorldData blocks (unchanged by fine)")
	var a_solid: Vector2i = _first_deep_solid(s1)
	_check(a_solid.x >= 0 and s1.is_solid(a_solid), "a known coarse-solid cell is still solid")
	_check(s1.material_at(a_solid) == world.blocks.get(a_solid, &""), "material_at unchanged by the fine layer")

	# (c) SYNC — mining a coarse cell re-molds its 4×4 fine block (+ the boundary band), and the O(local)
	# incremental sync must produce EXACTLY what a full rebuild would (the load-time path); if these ever
	# diverge, the fine grid silently rots after digging. We mine a solid cell that has OPEN AIR right below
	# it (a cavity/cave-edge cell) so the opening actually admits — its block drains toward air — then assert
	# the block cleared AND that the whole grid equals a full rebuild of the identical coarse state.
	var dug: Vector2i = _first_solid_over_air(s1)
	_check(dug.x >= 0, "found a solid cell with open air below to mine")
	var pre_solid: int = _fine_block_solid(s1, dug)
	s1.mine(dug)
	var post_solid: int = _fine_block_solid(s1, dug)
	_check(post_solid < pre_solid, "mining re-molds the 4×4 fine block toward air (was %d, now %d)"
		% [pre_solid, post_solid])
	_check(not s1.is_solid(dug), "…and the coarse cell is open (coarse still authoritative)")
	# The incremental dig-sync == a full rebuild from the same coarse grid (byte-for-byte, ANY cell).
	var rebuilt: FactorySim = FactorySim.new()
	rebuilt.load_world(gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, 1337))
	rebuilt.mine(dug)
	rebuilt.rebuild_fine_terrain()
	_check(_fine_bytes(s1) == _fine_bytes(rebuilt), "incremental dig-sync == a full rebuild (no drift)")

	# (d) LOAD REBUILDS IDENTICAL — a save/restore round-trip through disk must produce the SAME fine
	# terrain (it is derived, rebuilt by restore, never stored — so it can never desync or bloat the save).
	var s3: FactorySim = FactorySim.new()
	s3.load_world(gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, 1337))
	s3.mine(_first_solid_over_air(s3))             # scar it (a real dig) before saving
	var before: PackedByteArray = _fine_bytes(s3)
	var data: Dictionary = SaveGame.capture(s3)
	var path: String = "user://test_fine_terrain.save"
	SaveGame.write(path, data)
	var s4: FactorySim = FactorySim.new()
	_check(SaveGame.restore(s4, SaveGame.read(path)), "the scarred world restores")
	_check(_fine_bytes(s4) == before, "load rebuilds byte-identical fine terrain (derived, unsaved)")
	_check(s4.solid == s3.solid, "coarse terrain round-trips exactly")


## Count of solid fine cells in a coarse cell's SUBDIV×SUBDIV block.
func _fine_block_solid(sim: FactorySim, coarse: Vector2i) -> int:
	var n: int = 0
	for dy: int in FactorySim.SUBDIV:
		for dx: int in FactorySim.SUBDIV:
			if sim.fine_is_solid(coarse.x * FactorySim.SUBDIV + dx, coarse.y * FactorySim.SUBDIV + dy):
				n += 1
	return n


## A checksum of the fine solid grid — cheap byte fold, enough to catch any divergence.
func _fine_checksum(sim: FactorySim) -> int:
	var h: int = 1469598103
	for fy: int in sim.fine_h():
		for fx: int in sim.fine_w():
			h = (h * 33 + (1 if sim.fine_is_solid(fx, fy) else 0)) & 0x7fffffff
	return h


## The whole fine solid grid as bytes (for exact equality across a save/load round-trip).
func _fine_bytes(sim: FactorySim) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(sim.fine_w() * sim.fine_h())
	for fy: int in sim.fine_h():
		for fx: int in sim.fine_w():
			out[fy * sim.fine_w() + fx] = 1 if sim.fine_is_solid(fx, fy) else 0
	return out


## A checksum of the COARSE solid grid (material ids folded in) — proves the coarse authority is unchanged.
func _coarse_checksum(sim: FactorySim) -> int:
	var keys: Array = sim.solid.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a.y * FactorySim.GRID_COLS + a.x) < (b.y * FactorySim.GRID_COLS + b.x))
	var h: int = 2166136261
	for k: Vector2i in keys:
		h = (h * 33 + k.x * 31 + k.y * 17 + int(str(sim.solid[k]).hash())) & 0x7fffffff
	return h


## First solid cell scanning down a central column — a known-solid interior probe.
func _first_deep_solid(sim: FactorySim) -> Vector2i:
	var col: int = FactorySim.GRID_COLS / 2
	for row: int in range(0, FactorySim.GRID_ROWS):
		if sim.is_solid(Vector2i(col, row)):
			return Vector2i(col, row)
	return Vector2i(-1, -1)


## First mineable solid cell that sits directly OVER open air (a cavity/cave-edge cell) — mining it
## genuinely opens the fine block toward air (its bilinear solidness drops), the clean sync case.
func _first_solid_over_air(sim: FactorySim) -> Vector2i:
	for row: int in range(0, FactorySim.GRID_ROWS - 1):
		for col: int in range(0, FactorySim.GRID_COLS):
			var c := Vector2i(col, row)
			if not sim.is_solid(c) or sim.is_solid(c + Vector2i(0, 1)):
				continue
			if str(sim.solid[c]) == "sealrock":
				continue                                          # unmineable — skip
			return c
	return Vector2i(-1, -1)


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
