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
	_test_production()
	_test_splitter()
	_test_terrain()
	_test_surface_silhouette()
	_test_mining_and_deposit()
	_test_hand_built_chain()
	_test_inventory_slots()
	_test_spit_and_collect()
	_test_pile_falls_when_floor_mined()
	_test_craft_and_build()
	_test_worldgen()
	_test_layered_worldgen()
	_test_lift()
	_test_finite_deposit_and_drill()
	_test_coal_and_fuel()
	_test_trees_and_wood()
	_test_mining_rules()
	_test_hopper()
	_test_drop_toss()
	_test_block_placement_and_bazaar()
	_test_power_field()
	_test_conduit_network()
	_test_powered_lift()
	_test_automated_line()
	_test_machine_status()
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


func _state_signature(sim: FactorySim) -> String:
	var parts: PackedStringArray = []
	parts.append("sink:%s" % _dict_sig(sim.sink))
	for machine: MachineState in sim.machines:
		parts.append("in[%s]out[%s]p%.4f" % [
			_dict_sig(machine.input_buffer), _dict_sig(machine.output_buffer), machine.progress])
	return "|".join(parts)


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
	sim.remove_machine(Vector2i(7, 4))  # pick a machine back up
	_check(sim.machine_at(Vector2i(7, 4)) == null, "picked the processor back up (cell is buildable again)")


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
	for item: StringName in [&"ore", &"ingot"]:
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
	var a: WorldData = gen.generate(72, 40, 1337)
	var b: WorldData = gen.generate(72, 40, 1337)
	_check(a.blocks == b.blocks, "same seed → identical blocks (deterministic, caves + veins)")
	_check(gen.generate(72, 40, 99).blocks != a.blocks, "a different seed → a different world")

	# CAVES: some sub-surface cells are carved OPEN (block gone) yet still have a wall behind them —
	# a Terraria carved room. And the near-surface base is untouched (caves only below CAVE_MIN_DEPTH).
	var carved: int = 0
	var carved_with_wall: int = 0
	var breached_base: int = 0
	for col: int in 72:
		var top: int = HeightmapWorldGen.new()._surface_row(col)
		for row: int in range(top, 40):
			var cell: Vector2i = Vector2i(col, row)
			if not a.blocks.has(cell) and a.walls.has(cell):
				carved += 1
				carved_with_wall += 1
				if row < top + LayeredWorldGen.CAVE_MIN_DEPTH:
					breached_base += 1
	_check(carved > 50, "caves carved open cells in the rock (%d)" % carved)
	_check(carved_with_wall == carved, "every carved cell kept its wall (Terraria room, not void)")
	_check(breached_base == 0, "no cave breached the near-surface base (stays solid by construction)")

	# DEPTH-BANDED ORE: count ore in the top half vs the bottom half of the sub-surface column band.
	var ore_shallow: int = 0
	var ore_deep: int = 0
	for cell: Vector2i in a.blocks:
		if a.blocks[cell] == &"ore":
			if cell.y < 24:
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
	# BORING through SOLID ore (the scaling drill): a drill placed on an OPEN cell above a solid ore COLUMN
	# eats down through it — draining + CLEARING each cell (carving its shaft) — until it hits rock below.
	var s4: FactorySim = FactorySim.new()
	for y: int in range(6, 10):                        # a 4-tall solid ore column at col 5, rows 6..9
		s4.set_solid(Vector2i(5, y), &"ore"); s4.deposits[Vector2i(5, y)] = 3
	s4.set_solid(Vector2i(5, 10), &"stone")            # rock floor under the body (the drill stops here)
	var drill_top := Vector2i(5, 5)                    # placed on the OPEN cell right above the body
	_check(s4.drill_target(drill_top) == Vector2i(5, 6), "the boring drill targets the solid ore below it")
	var d4: MachineState = s4.place_machine(drill_def, drill_top)
	d4.input_buffer[&"coal"] = 60
	var body_total: int = 4 * 3                         # 4 cells × 3 each
	for _i: int in 100 + body_total * 25:
		s4.tick()
	for y: int in range(6, 10):
		_check(not s4.is_solid(Vector2i(5, y)), "bored-out ore cell (5,%d) is now carved open" % y)
	_check(s4.is_solid(Vector2i(5, 10)), "the drill stopped at the rock floor (didn't bore through rock)")
	_check(int(s4.total_produced.get(&"ore", 0)) == body_total, "the whole ore body's deposit was extracted (%d)" % body_total)
	_check(_items_present(s4, &"ore") == body_total, "ore conserved through boring the solid body")
	_check(s4.drill_target(drill_top) == Vector2i(-1, -1), "a spent, fully-bored body leaves the drill nothing (idles)")


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
	sim.set_solid(Vector2i(5, 4), &"wood")
	sim.set_solid(Vector2i(5, 3), &"wood")
	sim.set_solid(Vector2i(5, 2), &"leaves")
	_check(sim.surface_row(5) == 5, "foliage is NOT the walkable surface — the ground row is (trees don't ramp)")
	_check(sim.is_solid(Vector2i(5, 3)), "a trunk cell is solid (you collide with / can chop it)")
	# Chop ONE trunk cell → only that block clears, the rest of the tree stands (block-by-block).
	_check(sim.mine(Vector2i(5, 4)) == &"wood", "chopping a trunk cell returns wood material")
	_check(int(sim.inventory.get(&"wood", 0)) == 1, "chopping one trunk cell yields exactly ONE wood (no flood-fell)")
	_check(not sim.is_solid(Vector2i(5, 4)), "the chopped cell is now clear")
	_check(sim.is_solid(Vector2i(5, 3)) and sim.is_solid(Vector2i(5, 2)), "the rest of the tree still stands")
	# Chopping a leaf cell clears it but yields no wood.
	_check(sim.mine(Vector2i(5, 2)) == &"leaves", "chopping a leaf returns leaves material")
	_check(int(sim.inventory.get(&"wood", 0)) == 1, "leaves yield no wood")
	_check(sim.is_solid(Vector2i(5, 5)), "the ground under the tree survives")
	_check(_items_present(sim, &"wood") == int(sim.total_produced.get(&"wood", 0)), "wood conserved")


## Manual-mining friction rules (docs/MINING.md): the GATE (own a tool that breaks this) and the felt
## time (hardness / tool speed). Pure static logic, no sim — the same table the controller + try_mine use.
func _test_mining_rules() -> void:
	print("- mining rules (tools + friction)")
	var bare: Dictionary = {}
	var pick: Dictionary = {&"wood_pickaxe": 1}
	var axe: Dictionary = {&"wood_axe": 1}
	var kit: Dictionary = {&"wood_pickaxe": 1, &"wood_axe": 1}
	# Gate: rock needs a pick, wood needs an axe, dirt is hand-mineable.
	_check(not MiningRules.can_mine(&"stone", bare), "can't crack stone bare-handed")
	_check(MiningRules.can_mine(&"stone", pick), "the pickaxe cracks stone")
	_check(not MiningRules.can_mine(&"wood", pick), "a pickaxe can't chop wood (needs an axe)")
	_check(MiningRules.can_mine(&"wood", axe), "the axe chops wood")
	_check(MiningRules.can_mine(&"earth", bare), "dirt is always hand-mineable")
	_check(MiningRules.can_mine(&"ore", kit), "the starter kit can mine ore")
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
	_check(s2.place_conduit(Vector2i(3, 3)), "place a carried conduit into an open cell")
	_check(s2.has_conduit(Vector2i(3, 3)), "the cell now holds a conduit")
	_check(int(s2.inventory.get(&"conduit", 0)) == 1, "placing spent one conduit from the pack")
	s2.set_solid(Vector2i(4, 3), &"earth")
	_check(not s2.place_conduit(Vector2i(4, 3)), "cannot run a conduit through solid rock")
	_check(s2.remove_conduit(Vector2i(3, 3)), "pick the conduit back up")
	_check(not s2.has_conduit(Vector2i(3, 3)) and int(s2.inventory.get(&"conduit", 0)) == 2, "it returned to the pack")


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
