extends "res://tests/test_base.gd"

## `World` + `LogicGrid` + `PlacedVerbs` (A' step 3b, ADR 0009, D0347). Legacy's own tests for these verbs
## (`legacy/tests/test_sim.gd`: `_test_block_supported` 965, `_test_rope` 1232, `_test_torch` 1649,
## `_test_saplings` 760, the placement half of `_test_block_placement_and_bazaar` 978) re-expressed at
## the metre cell over a 4 px grid: the geometry and the expected numbers are legacy's; what legacy
## asserted about the PACK (spent one rope per segment, conserved) belongs to the items sub-step and is
## not here. Beyond legacy: the three states of a metre cell, the full-face rule for support, the
## displacement coupling `set_solid` now owns, the invariant, and the running signature of all three
## planes against a from-scratch rebuild under randomised mutation.

const ROCK: StringName = &"hardrock"
const SOIL: StringName = &"clay"


func _initialize() -> void:
	_test_the_constant_relation_and_the_sixteen_cells()
	_test_a_metre_has_three_states()
	_test_block_supported_is_legacy_geometry_with_a_full_face()
	_test_place_block_refuses_like_legacy_and_displaces_water()
	_test_rope_is_legacy_line_for_line()
	_test_torch_is_legacy_line_for_line()
	_test_conduit_and_structural_occupancy()
	_test_saplings_want_open_ground_on_a_full_soil_face()
	_test_placed_not_in_rock_invariant_fires_only_when_bypassed()
	_test_all_three_signatures_fold_and_agree_with_the_rebuild()
	_test_is_soil_reads_the_record()
	_finish("world_verbs")


func _world(logic_w: int = 16, logic_h: int = 16) -> World:
	return World.new(TileGrid.new(logic_w * LogicGrid.TERRAIN_PER_LOGIC, logic_h * LogicGrid.TERRAIN_PER_LOGIC, 1))


func _test_the_constant_relation_and_the_sixteen_cells() -> void:
	_check(LogicGrid.TERRAIN_PER_LOGIC == Body.LOGIC_TILE_PX / Heightfield.TERRAIN_CELL_PX,
		"TERRAIN_PER_LOGIC (%d) equals the body's 16 px tile over the 4 px terrain cell (ADR 0009's asserted relation)" % LogicGrid.TERRAIN_PER_LOGIC)
	var w: World = _world()
	var cells: Array[Vector2i] = w.terrain_cells_of(Vector2i(2, 3))
	var distinct: Dictionary = {}
	for c: Vector2i in cells:
		distinct[c] = true
	_check(cells.size() == 16 and distinct.size() == 16 and cells[0] == Vector2i(8, 12) and cells[15] == Vector2i(11, 15),
		"a metre covers sixteen distinct terrain cells from (8,12) to (11,15)")
	var below: Array[Vector2i] = w.terrain_face_cells(Vector2i(2, 3), Vector2i(0, 1))
	var expected_below: Array[Vector2i] = [Vector2i(8, 16), Vector2i(9, 16), Vector2i(10, 16), Vector2i(11, 16)]
	_check(below == expected_below, "the face below is the four cells of the next row (got %s)" % str(below))
	_check(w.terrain_face_cells(Vector2i(2, 3), Vector2i(-1, 0))[0] == Vector2i(7, 12), "the face to the left starts at (7,12)")
	_check(w.logic_in_bounds(Vector2i(15, 15)) and not w.logic_in_bounds(Vector2i(16, 0)) and not w.logic_in_bounds(Vector2i(0, -1)),
		"logic bounds: (15,15) in, (16,0) and (0,-1) out on a 16-metre world")


func _test_a_metre_has_three_states() -> void:
	var w: World = _world()
	var lc := Vector2i(4, 4)
	_check(w.logic_air(lc) and not w.logic_solid(lc) and w.logic_open(lc) and not w.cell_occupied(lc), "fresh: air, open, unoccupied")
	w.set_solid(lc, ROCK)
	_check(w.logic_solid(lc) and not w.logic_air(lc) and not w.logic_open(lc) and w.cell_occupied(lc), "filled: solid, occupied")
	w.grid.excavate(Vector2i(17, 17))  # one 4 px cell out of the sixteen
	_check(not w.logic_solid(lc) and not w.logic_air(lc), "one cell dug: NEITHER solid NOR air -- the third state")
	_check(w.cell_occupied(lc) and not w.logic_open(lc), "...and it still counts as occupied and not open (a sliver of rock is rock)")
	w.set_solid(lc, &"")
	_check(w.logic_air(lc) and w.logic_open(lc), "excavating the metre makes it air and open again")
	_check(not w.logic_open(Vector2i(16, 0)), "out of bounds is never open")


## legacy `_test_block_supported`, cell for cell, plus the two rules the metre adds.
func _test_block_supported_is_legacy_geometry_with_a_full_face() -> void:
	var w: World = _world(24, 16)
	w.set_solid(Vector2i(5, 10), ROCK)
	_check(not w.block_supported(Vector2i(5, 2)), "isolated open-sky cell has NO support (can't float a block)")
	_check(w.block_supported(Vector2i(5, 9)), "on top of a solid block IS supported")
	_check(w.block_supported(Vector2i(6, 10)), "beside a solid block IS supported (extend a structure)")
	_check(not w.block_supported(Vector2i(8, 2)), "two cells from anything is still unsupported")
	w.set_wall(Vector2i(20, 3), ROCK)
	_check(w.block_supported(Vector2i(20, 3)), "a wall behind the cell supports a block (backfill a dug room)")
	# The metre's own rules. A half floor is not a floor: dig two of the four face cells out.
	w.grid.excavate(Vector2i(20, 40))
	w.grid.excavate(Vector2i(21, 40))
	_check(not w.face_solid(Vector2i(5, 9), Vector2i(0, 1)) and not w.block_supported(Vector2i(5, 9)),
		"a face with two of four cells dug is not a full face, so the cell above is no longer supported")
	_check(w.block_supported(Vector2i(6, 10)), "the untouched side face still supports")
	PlacedVerbs.place_conduit(w, Vector2i(12, 5))
	_check(w.block_supported(Vector2i(12, 4)), "a conduit neighbour supports (legacy's list)")
	PlacedVerbs.place_rope(w, Vector2i(15, 5), 1)
	_check(not w.block_supported(Vector2i(15, 4)), "a rope neighbour does NOT support (not in legacy's list)")
	_check(w.logic.occupy(Vector2i(18, 5), LogicGrid.KIND_MACHINE) and w.block_supported(Vector2i(18, 4)), "a machine neighbour supports")


func _test_place_block_refuses_like_legacy_and_displaces_water() -> void:
	var w: World = _world()
	_check(w.place_block(Vector2i(2, 2), ROCK), "placed a block into an open metre")
	_check(w.logic_solid(Vector2i(2, 2)), "the metre is solid")
	_check(not w.place_block(Vector2i(2, 2), ROCK), "cannot place onto an occupied cell")
	_check(not w.place_block(Vector2i(2, 3), &""), "no material, no block")
	_check(not w.place_block(Vector2i(16, 0), ROCK), "out of bounds refuses")
	PlacedVerbs.place_rope(w, Vector2i(6, 6), 1)
	_check(not w.place_block(Vector2i(6, 6), ROCK), "a block cannot be placed into a roped cell")
	# Water in every cell of a metre, then rock over it: displaced, accounted, gone.
	var poured: int = 0
	for terrain_cell: Vector2i in w.terrain_cells_of(Vector2i(8, 8)):
		poured += w.water.add_water(w.grid, terrain_cell, 3)
	_check(poured == 48, "poured 3 units into each of the sixteen cells (48)")
	var displaced: int = w.set_solid(Vector2i(8, 8), ROCK)
	_check(displaced == 48 and w.water.total_water() == 0, "set_solid displaced all 48 units and reported them (D0344's deferred coupling)")
	_check(Invariants.check_water_not_in_rock(w.water, w.grid, 0) == null, "no water is left inside the rock")
	_check(w.set_solid(Vector2i(16, 0), ROCK) == 0, "out of bounds displaces nothing")


## legacy `_test_rope`, with the pack (20 rope) as `max_segments`.
func _test_rope_is_legacy_line_for_line() -> void:
	var w: World = _world(24, 16)
	var col: int = 12
	w.set_solid(Vector2i(col, 10), ROCK)                     # the shaft floor
	var hung: int = PlacedVerbs.place_rope(w, Vector2i(col, 4), 20)
	_check(hung == 6, "rope unrolled from the anchor down to the floor (hung %d/6)" % hung)
	_check(w.logic.is_climbable(Vector2i(col, 4)) and w.logic.is_climbable(Vector2i(col, 9)), "anchor + bottom are climbable")
	_check(not w.logic.is_climbable(Vector2i(col, 10)), "the floor itself is not roped")
	_check(PlacedVerbs.place_rope(w, Vector2i(col, 4), 20) == 0, "an already-roped anchor refuses (no double-hang)")
	w.set_solid(Vector2i(col + 1, 3), ROCK)
	_check(PlacedVerbs.place_rope(w, Vector2i(col + 1, 3), 20) == 0, "cannot anchor inside solid rock")
	var s3: World = _world()
	_check(PlacedVerbs.place_rope(s3, Vector2i(5, 0), 2) == 2, "unroll stops when the pack runs out")
	_check(w.logic.rope_length(Vector2i(col, 8)) == 6, "rope_length counts the whole connected run from any segment")
	_check(w.logic.logic_rope_anchor(Vector2i(col, 8)) == Vector2i(col, 4), "rope_anchor walks up to the top segment")
	_check(w.logic.rope_length(Vector2i(col, 10)) == 0, "no rope -> length 0")
	var cut: int = PlacedVerbs.remove_rope(w, Vector2i(col, 7))
	_check(cut == 3, "cutting mid-rope takes it + the tail below (%d/3)" % cut)
	_check(w.logic.is_climbable(Vector2i(col, 6)) and not w.logic.is_climbable(Vector2i(col, 8)), "the rope above the cut stays")
	var got: int = PlacedVerbs.retract_rope(w, Vector2i(col, 6))
	_check(got == 3, "retract from a low segment recovers the whole hang via the anchor (%d/3)" % got)
	_check(not w.logic.is_climbable(Vector2i(col, 4)), "nothing left hanging after retract-all")
	_check(PlacedVerbs.retract_rope(w, Vector2i(col, 6)) == 0, "retracting where there is no rope is a no-op")
	_check(w.logic.placed_logic_cells(LogicGrid.KIND_ROPE).is_empty(), "no rope cells remain in the plane")


## legacy `_test_torch`, minus the pack and the research gate.
func _test_torch_is_legacy_line_for_line() -> void:
	var w: World = _world()
	w.set_solid(Vector2i(8, 10), ROCK)                        # a cave floor
	var spot := Vector2i(8, 9)                                # open, atop the floor (solid face below)
	_check(not PlacedVerbs.place_torch(w, Vector2i(3, 2)), "a floating sky cell refuses (nothing to mount on)")
	w.set_wall(Vector2i(3, 2), ROCK)
	_check(PlacedVerbs.place_torch(w, Vector2i(3, 2)), "a wall-backed open cell mounts")
	_check(PlacedVerbs.place_torch(w, spot), "a rock-adjacent open cell mounts")
	_check(not PlacedVerbs.place_torch(w, spot), "no double-mount")
	_check(not PlacedVerbs.place_torch(w, Vector2i(8, 10)), "cannot mount inside solid rock")
	_check(not w.place_block(spot, ROCK), "a block cannot be placed into a torch cell")
	_check(not w.logic.occupy(spot, LogicGrid.KIND_MACHINE), "a machine cannot be placed into a torch cell")
	_check(PlacedVerbs.remove_torch(w, spot), "removal takes the torch back")
	_check(not w.logic.has_torch(spot) and not PlacedVerbs.remove_torch(w, spot), "...and a second removal finds nothing")
	w.grid.excavate(Vector2i(33, 40))                         # dig one cell out of the floor's top row
	_check(not w.backed(spot), "a torch needs a FULL face: one cell dug out of the floor and nothing backs the spot")


func _test_conduit_and_structural_occupancy() -> void:
	var w: World = _world()
	var lc := Vector2i(3, 3)
	_check(PlacedVerbs.place_conduit(w, lc) and w.logic.has_conduit(lc) and w.logic.conduit_tier(lc) == 1, "a conduit goes into an open cell at tier 1")
	_check(not PlacedVerbs.place_conduit(w, lc), "no double-pipe")
	_check(not w.logic.occupy(lc, LogicGrid.KIND_ROPE), "occupy refuses an occupied cell whatever the kind: exclusivity is structural")
	_check(PlacedVerbs.place_rope(w, lc, 5) == 0 and not PlacedVerbs.place_torch(w, lc), "rope and torch refuse the piped cell")
	_check(w.logic.vacate(lc) == LogicGrid.KIND_CONDUIT and w.logic.conduit_tier(lc) == 0, "vacate returns the kind and clears the tier")
	_check(not PlacedVerbs.remove_conduit(w, lc), "removing where there is none is false")
	_check(w.logic.occupy(lc, LogicGrid.KIND_MACHINE) and w.logic.occupant(lc) == LogicGrid.KIND_MACHINE, "a machine registers as the opaque kind")
	_check(w.cell_occupied(lc) and not w.logic_open(lc), "an occupied air cell is occupied and not open")
	_check(not w.logic.occupy(Vector2i(4, 4), &""), "an empty kind is refused")
	w.set_solid(Vector2i(6, 6), ROCK)
	_check(not PlacedVerbs.place_conduit(w, Vector2i(6, 6)), "a conduit refuses rock")


## legacy `_test_saplings`, the planting geometry (growth, crush and uproot are the flora lift).
func _test_saplings_want_open_ground_on_a_full_soil_face() -> void:
	var w: World = _world(40, 16)
	w.set_solid(Vector2i(30, 10), SOIL)
	w.set_solid(Vector2i(31, 10), ROCK)
	_check(not PlacedVerbs.can_plant_sapling(w, Vector2i(30, 5)), "mid-air (no soil below) refuses")
	_check(not PlacedVerbs.can_plant_sapling(w, Vector2i(31, 9)), "rock is not soil")
	_check(PlacedVerbs.plant_sapling(w, Vector2i(30, 9)), "open cell on soil roots the sapling")
	_check(not PlacedVerbs.plant_sapling(w, Vector2i(30, 9)), "an occupied sapling cell refuses a second seed")
	_check(w.logic.sapling_age(Vector2i(30, 9)) == 0 and w.logic.has_sapling(Vector2i(30, 9)), "a fresh sapling is age 0")
	w.logic.set_sapling_age(Vector2i(30, 9), 5)
	_check(w.logic.sapling_age(Vector2i(30, 9)) == 5, "age is settable (the flora pass ages it)")
	_check(PlacedVerbs.remove_sapling(w, Vector2i(30, 9)), "a planted sapling can be taken back")
	_check(PlacedVerbs.plant_sapling(w, Vector2i(30, 9)) and w.logic.sapling_age(Vector2i(30, 9)) == 0, "...and replanted, growth restarting from zero")
	_check(not PlacedVerbs.remove_sapling(w, Vector2i(30, 8)), "removing where none is planted is false")
	w.grid.excavate(Vector2i(121, 40))  # one cell of the soil face under (30,9)
	_check(not w.soil_below(Vector2i(30, 9)) and not PlacedVerbs.can_plant_sapling(w, Vector2i(30, 8)), "soil must be a FULL face")
	var planted: Array[Vector2i] = [Vector2i(30, 9)]
	_check(w.logic.sapling_logic_cells() == planted, "the sapling plane lists the one planted")
	PlacedVerbs.place_conduit(w, Vector2i(31, 8))
	w.set_solid(Vector2i(31, 9), SOIL)
	_check(not PlacedVerbs.can_plant_sapling(w, Vector2i(31, 8)), "a piped cell refuses a sapling (legacy's gate omitted conduits; ADR 0009 closes it)")


func _test_placed_not_in_rock_invariant_fires_only_when_bypassed() -> void:
	var w: World = _world()
	w.set_solid(Vector2i(2, 5), ROCK)
	PlacedVerbs.place_torch(w, Vector2i(2, 4))
	PlacedVerbs.place_conduit(w, Vector2i(5, 5))
	_check(Invariants.check_placed_not_in_rock(w, 0) == null and Invariants.report_placed_not_in_rock(w, 0) == null, "through the verbs, nothing placed sits in rock")
	_check(not w.place_block(Vector2i(2, 4), ROCK), "the verb refuses rock over a torch")
	w.grid.set_material(Vector2i(9, 17), ROCK)  # BYPASS: one 4 px cell written under the torch without vacating
	var v: Invariants.PlacedInRockViolation = Invariants.check_placed_not_in_rock(w, 7)
	_check(v != null and v.logic_cell == Vector2i(2, 4) and v.kind == LogicGrid.KIND_TORCH and v.tick == 7,
		"a bypassing terrain write under a torch fires the invariant, naming cell, kind and tick (positive control)")


func _test_all_three_signatures_fold_and_agree_with_the_rebuild() -> void:
	var rng: SplitRng = SplitRng.new(20260903)
	var w: World = _world(12, 12)
	var mutations: int = 0
	var agreed: int = 0
	var first_bad: String = ""
	for i: int in 300:
		var lc := Vector2i(rng.next_range(0, 11), rng.next_range(0, 11))
		match rng.next_range(0, 7):
			0: w.set_solid(lc, ROCK)
			1: w.set_solid(lc, &"")
			2: w.grid.excavate(Vector2i(rng.next_range(0, 47), rng.next_range(0, 47)))
			3: PlacedVerbs.place_rope(w, lc, rng.next_range(1, 4))
			4: PlacedVerbs.place_torch(w, lc)
			5: PlacedVerbs.place_conduit(w, lc)
			6: PlacedVerbs.plant_sapling(w, lc)
			_: w.water.add_water(w.grid, Vector2i(rng.next_range(0, 47), rng.next_range(0, 47)), rng.next_range(1, 8))
		if i % 5 == 4:
			WaterFlow.step(w.water, w.grid)
		if i % 9 == 8:
			PlacedVerbs.remove_rope(w, lc)
			PlacedVerbs.remove_torch(w, lc)
			PlacedVerbs.remove_conduit(w, lc)
			PlacedVerbs.remove_sapling(w, lc)
		mutations += 1
		if w.state_signature() == w.recomputed_signature():
			agreed += 1
		elif first_bad.is_empty():
			first_bad = " first disagreement at %d: %s vs %s" % [i, w.state_signature(), w.recomputed_signature()]
	_check_over(mutations, agreed == mutations, "all three planes' running signatures agree with the rebuild after each of %d mutations (%d agreed)%s" % [mutations, agreed, first_bad])
	_check(not w.logic.placed.is_empty() and w.water.total_water() > 0, "the run left placed things (%d) and water (%d), so the agreement was over non-empty planes" % [w.logic.placed.size(), w.water.total_water()])
	var copy: World = w.clone()
	_check(copy.state_signature() == w.state_signature() and copy.logic.placed == w.logic.placed, "clone carries every plane and lane")
	var free: Vector2i = Vector2i(-1, -1)
	for y: int in 12:
		for x: int in 12:
			if free.x < 0 and copy.logic_open(Vector2i(x, y)):
				free = Vector2i(x, y)
	_check(free.x >= 0 and copy.logic.occupy(free, LogicGrid.KIND_MACHINE), "an open metre was found and a machine registered in it")
	_check(copy.state_signature() != w.state_signature(), "one more placed thing changes the joined signature")
	_check(copy.state_signature().count("|") == 2, "the joined signature has three parts")


func _test_is_soil_reads_the_record() -> void:
	_check(WorldMaterials.is_soil(SOIL), "clay is soil (legacy's earth)")
	_check(not WorldMaterials.is_soil(ROCK) and not WorldMaterials.is_soil(&"no_such_material"), "hardrock and an unknown id are not soil")
