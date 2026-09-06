extends "res://tests/test_base.gd"

## `sim/items` (A' step 3c, D0348): the pack and its cap, ground piles, the landing rule, the ledger, the
## builder verbs, and the deposit plane. Legacy's tests re-expressed (`legacy/tests/test_sim.gd`:
## `_test_inventory_slots` 341, `_test_drop_toss` 927, `_test_pile_falls_when_floor_mined` 434,
## `_test_no_empty_ground_piles` 1126's resettle half, the pack halves of `_test_rope` 1232, `_test_torch`
## 1649, `_test_block_placement_and_bazaar` 978 and `_test_saplings` 760, `_test_carry_cap`'s shape from
## `legacy/tools/check_carry_cap.gd`) at the metre cell over a 4 px grid. Where legacy mined to fill the
## pack, the pack is filled directly: `mine` merges into `Mining` in a later sub-step. A machine below is
## an opaque occupant plus a buffer callback, the way the hub will supply it.

const ROCK: StringName = &"hardrock"


func _initialize() -> void:
	_test_pack_slots_and_the_two_numbers_from_data()
	_test_bulk_class_and_the_cap_arithmetic()
	_test_take_into_pack_spills_what_does_not_fit_and_collect_respects_the_cap()
	_test_drop_lands_in_a_machine_buffer_on_a_floor_or_in_the_sink()
	_test_pile_falls_when_the_floor_is_removed_and_leaves_no_empty_pile()
	_test_builder_verbs_spend_and_recover_and_conserve()
	_test_take_lode_refuses_a_full_pack_and_retires_a_dry_vein()
	_test_deposit_plane_reads_and_signature()
	_test_conservation_invariant_and_its_positive_control()
	_test_pack_signature_agrees_with_the_rebuild()
	_finish("items")


func _fresh(logic_w: int = 16, logic_h: int = 16) -> Items:
	return Items.new(World.new(TileGrid.new(logic_w * LogicGrid.TERRAIN_PER_LOGIC, logic_h * LogicGrid.TERRAIN_PER_LOGIC, 1)))


## Registers a machine occupant at `cell` with its own input buffer and wires the callbacks the hub will.
func _machine_at(items: Items, logic_cell: Vector2i) -> Dictionary:
	var buffer: Dictionary = {}
	items.world.logic.occupy(logic_cell, LogicGrid.KIND_MACHINE)
	var buffers: Dictionary = {logic_cell: buffer}
	items.machine_buffer = func(c: Vector2i) -> Variant: return buffers.get(c)
	items.machine_total = func(item: StringName) -> int:
		var n: int = 0
		for b: Dictionary in buffers.values():
			n += int(b.get(item, 0))
		return n
	return buffer


func _test_pack_slots_and_the_two_numbers_from_data() -> void:
	_check(Pack.inventory_slots() == 10 and Pack.bulk_cap() == 90, "INVENTORY_SLOTS 10 and PACK_BULK_CAP 90 read from data/player/pack.yaml")
	var pack: Pack = Pack.new()
	_check(pack.slots().is_empty() and pack.is_empty(), "empty pack = no slots")
	pack.add(&"ore", 4)
	pack.add(&"ore", 3)
	var slots: Array[Dictionary] = pack.slots()
	_check(slots.size() == 1 and slots[0]["item"] == &"ore" and int(slots[0]["count"]) == 7, "two adds of one item = one stack of 7")
	pack.add(&"ingot", 3)
	slots = pack.slots()
	_check(slots.size() == 2 and slots[1]["item"] == &"ingot", "second item type = second slot, insertion order preserved (ore, then ingot)")
	_check(pack.remove(&"ore", 10) == 7 and not pack.items.has(&"ore"), "remove takes what is there and a drained stack leaves the pack")
	_check(pack.remove(&"ore", 1) == 0 and pack.count(&"nothing") == 0, "removing from an absent stack is 0")
	var remaining: Array[StringName] = [&"ingot"]
	_check(pack.ids() == remaining, "ids() lists the remaining stack")


func _test_bulk_class_and_the_cap_arithmetic() -> void:
	_check(Pack.is_bulk_item(&"ore") and Pack.is_bulk_item(&"ingot") and Pack.is_bulk_item(&"hardrock"), "ore, ingots and rock are bulk")
	_check(not Pack.is_bulk_item(&"drill") and not Pack.is_bulk_item(&"rope") and not Pack.is_bulk_item(&"torch"), "a placeable machine item (drill, rope, torch) is not bulk: the cap taxes freight, not the kit")
	var pack: Pack = Pack.new()
	pack.add(&"ore", 85)
	pack.add(&"drill", 3)
	_check(pack.carried_bulk() == 85 and pack.pack_room() == 5, "85 ore and 3 drills: bulk 85, room 5")
	_check(pack.can_carry(&"ore", 5) and not pack.can_carry(&"ore", 6), "5 more ore fit, 6 do not")
	_check(pack.can_carry(&"drill", 100) and pack.can_carry(&"ore", 0) and pack.can_carry(&"ore", -1), "machine items always fit; taking nothing always fits")
	pack.add(&"ore", 20)
	_check(pack.carried_bulk() == 105 and pack.pack_room() == 0, "an overfilled pack reads room 0, never negative")


func _test_take_into_pack_spills_what_does_not_fit_and_collect_respects_the_cap() -> void:
	var items: Items = _fresh()
	items.world.set_solid(Vector2i(3, 8), ROCK)               # a floor under column 3
	items.pack.add(&"ore", 88)
	var taken: int = items.take_into_pack(&"ore", 5, Vector2i(3, 2))
	_check(taken == 2, "with room for 2, take_into_pack banks 2 of 5 (got %d)" % taken)
	_check(items.piles.count_at(Vector2i(3, 7), &"ore") == 3, "the other 3 spilled down the column onto the floor pile")
	_check(items.flow_events.size() == 1 and items.last_drop_landing == Vector2i(3, 7), "one flow event and the landing cell for the grace")
	_check(items.take_into_pack(&"drill", 2, Vector2i(3, 2)) == 2 and items.pack.count(&"drill") == 2, "a machine item takes whole, uncapped")
	_check(items.collect_ground(Vector2i(3, 7)) == 0 and items.piles.count_at(Vector2i(3, 7), &"ore") == 3, "a full pack collects nothing and the pile stays")
	items.pack.remove(&"ore", 2)
	_check(items.collect_ground(Vector2i(3, 7)) == 2 and items.piles.count_at(Vector2i(3, 7), &"ore") == 1, "with room for 2, collect scoops 2 and leaves 1")
	items.pack.remove(&"ore", 50)
	_check(items.collect_ground(Vector2i(3, 7)) == 1 and not items.piles.ground.has(Vector2i(3, 7)), "the last unit collected and the pile is gone")
	_check(items.collect_ground(Vector2i(3, 7)) == 0, "collecting where there is no pile is 0")
	_check(items.take_into_pack(&"ore", 0, Vector2i(3, 2)) == 0, "taking nothing is nothing")


## legacy `_test_drop_toss`, three cases.
func _test_drop_lands_in_a_machine_buffer_on_a_floor_or_in_the_sink() -> void:
	var items: Items = _fresh()
	var forge: Dictionary = _machine_at(items, Vector2i(5, 6))
	items.pack.add(&"ore", 5)
	items.produced(&"ore", 5)
	var fed: int = items.drop_item(Vector2i(5, 2), &"ore", 3)
	_check(fed == 3 and int(forge.get(&"ore", 0)) == 3, "dropped 3 ore above the forge's column: they fell into its input buffer")
	_check(items.pack.count(&"ore") == 2 and items.present(&"ore") == 5, "the dropped ore left the pack; ore conserved (2 pack + 3 in forge)")
	_check(items.last_drop_landing == Vector2i(5, 6), "drop_item records the landing cell for the pickup grace")
	var s2: Items = _fresh()
	s2.world.set_solid(Vector2i(3, 9), ROCK)
	s2.pack.add(&"ingot", 4)
	_check(s2.drop_item(Vector2i(3, 1), &"ingot", 4) == 4 and s2.piles.count_at(Vector2i(3, 8), &"ingot") == 4, "dropped above a floor: the ingots rest as a pile on top of it")
	var s3: Items = _fresh()
	var f3: Dictionary = _machine_at(s3, Vector2i(7, 5))
	s3.pack.add(&"ore", 2)
	s3.drop_item(Vector2i(7, 1), &"ore", 2, Vector2i(4, 1))
	_check(int(f3.get(&"ore", 0)) == 2 and s3.flow_events[0]["from"] == Vector2i(4, 1), "a tossed stack lands by the target column, not the throw origin, which only colours the event")
	var s4: Items = _fresh()
	s4.pack.add(&"ore", 1)
	_check(s4.drop_item(Vector2i(2, 2), &"ore", 1) == 1 and int(s4.piles.sink.get(&"ore", 0)) == 1 and s4.present(&"ore") == 1, "a column dug clear to the bottom drops into the sink, which still counts as present")
	_check(s4.drop_item(Vector2i(2, 2), &"ore", 1) == 0, "nothing carried, nothing dropped")
	s4.world.grid.set_material(Vector2i(8, 33), ROCK)  # one 4 px cell of rock in metre (2, 8)
	s4.pack.add(&"ore", 1)
	s4.drop_item(Vector2i(2, 2), &"ore", 1)
	_check(s4.piles.count_at(Vector2i(2, 7), &"ore") == 1, "a half-dug metre is a floor: the pile rests in the metre above it (ADR 0009)")


## legacy `_test_pile_falls_when_floor_mined` and the resettle half of `_test_no_empty_ground_piles`.
func _test_pile_falls_when_the_floor_is_removed_and_leaves_no_empty_pile() -> void:
	var items: Items = _fresh()
	items.world.set_solid(Vector2i(2, 5), ROCK)
	items.world.set_solid(Vector2i(2, 7), ROCK)
	items.piles.pile(Vector2i(2, 4))[&"ingot"] = 3
	items.produced(&"ingot", 3)
	items.world.set_solid(Vector2i(2, 5), &"")
	items.resettle_pile_above(Vector2i(2, 5))
	_check(not items.piles.ground.has(Vector2i(2, 4)), "the pile no longer hangs where its floor was")
	_check(items.piles.count_at(Vector2i(2, 6), &"ingot") == 3, "the pile fell to the floor below")
	_check(not items.flow_events.is_empty(), "a flow event was emitted so the fall animates")
	var forge: Dictionary = _machine_at(items, Vector2i(5, 8))
	items.world.set_solid(Vector2i(5, 4), ROCK)
	items.piles.pile(Vector2i(5, 3))[&"ore"] = 2
	items.produced(&"ore", 2)
	items.world.set_solid(Vector2i(5, 4), &"")
	items.resettle_pile_above(Vector2i(5, 4))
	_check(int(forge.get(&"ore", 0)) == 2, "a pile falling onto a machine feeds its input")
	var empties: int = 0
	for c: Vector2i in items.piles.ground:
		if (items.piles.ground[c] as Dictionary).is_empty():
			empties += 1
	_check(empties == 0, "resettling leaves no empty landing pile behind (found %d)" % empties)
	_check(Invariants.check_item_conservation(items, 0) == null, "ingot and ore conserved across the re-settle")
	items.resettle_pile_above(Vector2i(9, 9))
	_check(items.piles.ground.size() == 1, "resettling under nothing changes nothing")


## The pack halves of legacy's rope, torch, block and sapling tests.
func _test_builder_verbs_spend_and_recover_and_conserve() -> void:
	var items: Items = _fresh(24, 16)
	var col: int = 12
	items.world.set_solid(Vector2i(col, 10), ROCK)
	items.pack.add(&"rope", 20)
	items.produced(&"rope", 20)
	_check(BuildVerbs.place_rope(items, Vector2i(col, 4)) == 6 and items.pack.count(&"rope") == 14, "rope: 6 segments hung, each spent one carried rope")
	var s3: Items = _fresh()
	s3.pack.add(&"rope", 2)
	s3.produced(&"rope", 2)
	_check(BuildVerbs.place_rope(s3, Vector2i(5, 0)) == 2 and s3.pack.is_empty(), "unroll stops when the pack runs out")
	_check(BuildVerbs.remove_rope(items, Vector2i(col, 7)) == 3 and items.pack.count(&"rope") == 17, "cutting mid-rope returns 3 segments to the pack")
	_check(BuildVerbs.retract_rope(items, Vector2i(col, 6)) == 3 and items.pack.count(&"rope") == 20, "retracting from a low segment brings the rest home: every segment came home")
	_check(Invariants.check_item_conservation(items, 0) == null, "rope conserved through place+cut+retract")
	# Torch.
	items.world.set_solid(Vector2i(8, 10), ROCK)
	var spot := Vector2i(8, 9)
	_check(not BuildVerbs.place_torch(items, spot), "no torch carried -> refused")
	items.pack.add(&"torch", 3)
	items.produced(&"torch", 3)
	_check(not BuildVerbs.place_torch(items, Vector2i(3, 2)) and items.pack.count(&"torch") == 3, "a floating sky cell refuses and spends nothing")
	_check(BuildVerbs.place_torch(items, spot) and items.pack.count(&"torch") == 2, "a rock-adjacent open cell mounts and spends one")
	_check(BuildVerbs.remove_torch(items, spot) and items.pack.count(&"torch") == 3, "removal takes the torch back into the pack")
	_check(Invariants.check_item_conservation(items, 0) == null, "torch conserved through mount+remove")
	# Block.
	items.pack.add(ROCK, 3)
	items.produced(ROCK, 3)
	_check(BuildVerbs.place_block(items, Vector2i(2, 2), ROCK) and items.world.logic_solid(Vector2i(2, 2)) and items.pack.count(ROCK) == 2, "placed a rock block from the pack: solid, pack spent one")
	_check(not BuildVerbs.place_block(items, Vector2i(2, 2), ROCK) and items.pack.count(ROCK) == 2, "cannot place onto an occupied cell, nothing spent")
	_check(items.present(ROCK) == int(items.total_produced[ROCK]) - int(items.total_consumed[ROCK]), "rock conserved across placement (place = consume)")
	_check(not BuildVerbs.place_block(items, Vector2i(2, 3), &"deepstone"), "no deepstone carried, no block")
	# Conduit and sapling.
	items.pack.add(&"conduit", 1)
	items.produced(&"conduit", 1)
	_check(BuildVerbs.place_conduit(items, Vector2i(6, 6)) and items.pack.is_empty() == false and items.pack.count(&"conduit") == 0, "a conduit goes down and the pack spends it")
	_check(BuildVerbs.remove_conduit(items, Vector2i(6, 6)) and items.pack.count(&"conduit") == 1, "and comes back")
	items.world.set_solid(Vector2i(20, 10), &"clay")
	items.pack.add(&"sapling", 1)
	items.produced(&"sapling", 1)
	_check(BuildVerbs.plant_sapling(items, Vector2i(20, 9)) and items.pack.count(&"sapling") == 0, "planted from the pack")
	items.pack.add(&"ore", 90)
	items.produced(&"ore", 90)
	_check(not BuildVerbs.remove_sapling(items, Vector2i(20, 9)) and items.world.logic.has_sapling(Vector2i(20, 9)), "a FULL pack leaves the sapling planted (refusing destroys nothing)")
	items.pack.remove(&"ore", 3)  # bulk was 92 (90 ore + 2 rock); 89 leaves room for exactly one sapling
	items.consumed(&"ore", 3)
	_check(items.pack.pack_room() == 1 and BuildVerbs.remove_sapling(items, Vector2i(20, 9)) and items.pack.count(&"sapling") == 1, "with room for exactly one, the sapling comes back")
	_check(Invariants.check_item_conservation(items, 0) == null, "everything conserved across the builder verbs")


func _test_take_lode_refuses_a_full_pack_and_retires_a_dry_vein() -> void:
	var items: Items = _fresh()
	var face := Vector2i(10, 20)  # a terrain cell; the wall behind an open face
	items.world.deposits.seed_lode(face, &"ore_iron", 2)
	_check(items.world.deposits.lode_workable(items.world.grid, face) and items.world.deposits.lode_permille(face) == 1000, "an exposed lode of 2 is workable and full")
	items.pack.add(&"ore", 90)
	_check(items.take_lode(face) == &"" and items.world.deposits.ore_deposit_at(items.world.grid, face) == 2, "a full pack takes nothing and the vein is untouched")
	items.pack.remove(&"ore", 90)
	_check(items.take_lode(face) == &"ore" and items.pack.count(&"ore") == 1 and int(items.total_produced[&"ore"]) == 1, "one unit taken, banked and ledgered")
	_check(items.world.deposits.lode_permille(face) == 500, "half the vein remains (500 per mille)")
	_check(items.take_lode(face) == &"ore" and not items.world.deposits.lode.has(face) and items.world.deposits.lode_permille(face) == 0, "the second unit works the vein dry and it is retired")
	_check(items.take_lode(face) == &"", "nothing left to take")
	items.world.grid.set_material(face, ROCK)
	items.world.deposits.seed_lode(face, &"ore_iron", 5)
	_check(not items.world.deposits.lode_workable(items.world.grid, face) and items.world.deposits.lode_at(face) == &"ore_iron", "a lode behind rock exists but is not workable")


func _test_deposit_plane_reads_and_signature() -> void:
	var items: Items = _fresh()
	var d: DepositPlane = items.world.deposits
	var g: TileGrid = items.world.grid
	g.set_material(Vector2i(4, 4), &"ore_iron")
	_check(d.ore_deposit_at(g, Vector2i(4, 4)) == DepositPlane.DEFAULT_ORE_DEPOSIT and d.deposit_material_at(g, Vector2i(4, 4)) == &"ore_iron", "a solid ore block with no seed reads the default (16 per 4 px cell, 256 a metre), identified by its own material")
	d.set_deposit(Vector2i(4, 4), 7)
	_check(d.ore_deposit_at(g, Vector2i(4, 4)) == 7, "a seeded ore block reads its seed")
	g.set_material(Vector2i(5, 4), &"coal")
	_check(WorldMaterials.is_ore_like(&"coal") and d.ore_deposit_at(g, Vector2i(5, 4)) == DepositPlane.DEFAULT_ORE_DEPOSIT, "coal (kind fuel) is ore-like")
	g.set_material(Vector2i(6, 4), ROCK)
	_check(not WorldMaterials.is_ore_like(ROCK) and d.ore_deposit_at(g, Vector2i(6, 4)) == 0 and d.deposit_material_at(g, Vector2i(6, 4)) == &"", "plain rock has no yield and no identity")
	d.seed_lode(Vector2i(6, 4), &"ore_copper", 9)
	_check(d.deposit_material_at(g, Vector2i(6, 4)) == &"ore_copper" and d.ore_deposit_at(g, Vector2i(6, 4)) == 9 and g.get_material(Vector2i(6, 4)) == ROCK,
		"a lode behind a solid block: the block in front is stone, but identity and amount come from the lode (never from material_at)")
	var lodes: Array[Vector2i] = d.lode_terrain_cells()
	_check(lodes.size() == 1 and lodes[0] == Vector2i(6, 4), "lode_terrain_cells lists it")
	_check(d.state_signature() == d.recomputed_signature(), "the deposit plane's running signature matches the rebuild")
	var before: String = d.state_signature()
	d.take_one(g, Vector2i(6, 4))
	_check(d.state_signature() == before, "a lode behind rock cannot be taken, so nothing moved")
	g.excavate(Vector2i(6, 4))
	_check(d.take_one(g, Vector2i(6, 4)) == &"ore_copper" and d.state_signature() != before and d.state_signature() == d.recomputed_signature(), "exposed, one unit comes off and the signature moves with it")
	_check(items.world.clone().deposits.state_signature() == d.state_signature(), "World.clone carries the deposit plane")


func _test_conservation_invariant_and_its_positive_control() -> void:
	var items: Items = _fresh()
	items.world.set_solid(Vector2i(3, 8), ROCK)
	items.pack.add(&"ore", 10)
	items.produced(&"ore", 10)
	items.drop_item(Vector2i(3, 2), &"ore", 4)
	_check(Invariants.check_item_conservation(items, 5) == null and Invariants.report_item_conservation(items, 5) == null, "pack 6 + pile 4 = produced 10: conserved")
	items.pack.add(&"ore", 1)  # a unit from nowhere
	var v: Invariants.ItemConservationViolation = Invariants.check_item_conservation(items, 6)
	_check(v != null and v.item == &"ore" and v.present == 11 and v.net == 10 and v.tick == 6, "a unit from nowhere fires the invariant with the numbers (positive control)")


func _test_pack_signature_agrees_with_the_rebuild() -> void:
	var rng: SplitRng = SplitRng.new(3)
	var pack: Pack = Pack.new()
	var ids: Array[StringName] = [&"ore", &"ingot", &"coal", &"drill", &"rope"]
	var agreed: int = 0
	for i: int in 200:
		var item: StringName = ids[rng.next_range(0, ids.size() - 1)]
		if rng.next_range(0, 2) == 0:
			pack.remove(item, rng.next_range(1, 6))
		else:
			pack.add(item, rng.next_range(1, 6))
		if pack.state_signature() == pack.recomputed_signature():
			agreed += 1
	_check_over(200, agreed == 200, "the pack's running signature agrees with the rebuild after each of 200 mutations (%d)" % agreed)
	var a: Pack = Pack.new()
	var b: Pack = Pack.new()
	a.add(&"ore", 3)
	a.add(&"coal", 1)
	b.add(&"coal", 1)
	b.add(&"ore", 3)
	_check(a.state_signature() == b.state_signature() and a.slots() != b.slots(), "same contents in a different pickup order: same signature, different hotbar order (order is view state)")
