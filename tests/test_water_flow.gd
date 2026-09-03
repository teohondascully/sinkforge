extends "res://tests/test_base.gd"

## Water, lifted verbatim (A' step 2, `docs/DECISIONS_LEDGER.md` D0344). The first five groups are legacy's
## own `legacy/tests/test_power_water.gd::_test_water_fluid` re-expressed against `WaterPlane` +
## `TileGrid`: legacy's `FactorySim` helpers map as `set_solid` -> `grid.set_material`, `add_water` ->
## `water.add_water(grid, ...)`, `tick` -> `WaterFlow.step(water, grid)`. The geometry is legacy's cell for
## cell (the cell is now 4 px rather than a metre, which changes no number here). Legacy's third group,
## "set_solid onto a watered cell clears its water", is a property of a world VERB that lands in step 3; its
## primitive `displace` is asserted here and the verb's coupling is asserted with the verb.
##
## Beyond legacy: the conservation and not-in-rock invariants over 10,000 fuzzed ticks (the plan's
## acceptance for this step), the running signature against a from-scratch rebuild after randomised
## mutation (the self-check `test_tile_grid.gd` runs), and the cap-overflow branch pinned -- which is
## reachable only through `set_level`, because gravity never fills a cell past `WATER_MAX` and `add_water`
## clamps, so the branch is a conservation guarantee rather than a live path.

const ROCK: StringName = &"hardrock"
const FUZZ_TICKS: int = 10000


func _initialize() -> void:
	_test_gravity_pours_to_the_bottom_of_a_walled_shaft()
	_test_a_blob_settles_flat_in_a_basin()
	_test_displace_clears_a_cell_and_accounts_for_it()
	_test_total_is_invariant_over_120_ticks()
	_test_two_identical_pours_flow_identically_and_different_ones_do_not()
	_test_running_signature_agrees_with_a_from_scratch_rebuild()
	_test_conservation_and_no_water_in_rock_over_fuzzed_ticks()
	_test_overflow_rides_the_left_cell_and_nothing_is_dropped()
	_test_add_water_refuses_rock_and_out_of_bounds_and_clamps_to_room()
	_test_wet_cells_come_back_in_the_flow_scan_order()
	_finish("water_flow")


func _rock(grid: TileGrid, terrain_cell: Vector2i) -> void:
	grid.set_material(terrain_cell, ROCK)


func _clean(water: WaterPlane, grid: TileGrid, tick: int) -> bool:
	return Invariants.check_water_not_in_rock(water, grid, tick) == null


## Legacy 1. Column x=5, open rows 1..8, capped by a solid floor at row 9; solid walls left/right.
func _test_gravity_pours_to_the_bottom_of_a_walled_shaft() -> void:
	var grid: TileGrid = TileGrid.new(16, 16, 1)
	var water: WaterPlane = WaterPlane.new()
	for row: int in range(1, 10):
		_rock(grid, Vector2i(4, row))
		_rock(grid, Vector2i(6, row))
	_rock(grid, Vector2i(5, 9))
	var poured: int = water.add_water(grid, Vector2i(5, 1), 6)
	_check(poured == 6, "add_water returns the amount it actually placed")
	_check(water.total_water() == 6, "the poured water is all present")
	var clean: int = 0
	for t: int in 40:
		WaterFlow.step(water, grid)
		if _clean(water, grid, t):
			clean += 1
	_check_over(40, clean == 40, "water never occupies a solid cell across the 40 gravity ticks (clean=%d)" % clean)
	_check(water.water_at(Vector2i(5, 1)) == 0, "the top of the shaft drained")
	_check(water.water_at(Vector2i(5, 8)) == 6, "all 6 units settled at the bottom of the shaft")
	_check(water.total_water() == 6, "gravity run conserved total (6)")


## Legacy 2. Basin: solid floor at row 6 across x=1..5, walls at x=0 and x=6, open above.
func _test_a_blob_settles_flat_in_a_basin() -> void:
	var grid: TileGrid = TileGrid.new(16, 16, 1)
	var water: WaterPlane = WaterPlane.new()
	for x: int in range(1, 6):
		_rock(grid, Vector2i(x, 6))
	for row: int in range(1, 6):
		_rock(grid, Vector2i(0, row))
		_rock(grid, Vector2i(6, row))
	var poured: int = water.add_water(grid, Vector2i(3, 1), 8) + water.add_water(grid, Vector2i(3, 2), 7)
	_check(poured == 15, "poured 15 units into the basin")
	var clean: int = 0
	for t: int in 80:
		WaterFlow.step(water, grid)
		if _clean(water, grid, t):
			clean += 1
	_check_over(80, clean == 80, "water never occupies a solid cell across the 80 basin ticks (clean=%d)" % clean)
	_check(water.total_water() == 15, "basin conserved total (15)")
	var lo: int = 999
	var hi: int = -999
	var floor_wet: int = 0
	for x: int in range(1, 6):
		var lvl: int = water.water_at(Vector2i(x, 5))
		if lvl > 0:
			floor_wet += 1
			lo = mini(lo, lvl)
			hi = maxi(hi, lvl)
	_check(floor_wet >= 4 and hi - lo <= 1, "the pool settled to a flat top (wet=%d, spread=%d)" % [floor_wet, hi - lo])


## Legacy 3, the primitive half. A lone puddle trapped by rock on three sides cannot move; displacing it
## returns exactly its level and the total drops by exactly that.
func _test_displace_clears_a_cell_and_accounts_for_it() -> void:
	var grid: TileGrid = TileGrid.new(16, 16, 1)
	var water: WaterPlane = WaterPlane.new()
	var puddle := Vector2i(3, 3)
	for dxy: Vector2i in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		_rock(grid, puddle + dxy)
	water.add_water(grid, puddle, 5)
	_check(water.water_at(puddle) == 5 and water.total_water() == 5, "puddle trapped, 5 units present")
	var before: int = water.total_water()
	var displaced: int = water.displace(puddle)
	_check(displaced == 5, "displace returns the level it removed (5)")
	_check(water.water_at(puddle) == 0 and not water.levels.has(puddle), "the displaced cell is dry and not a stored 0")
	_check(water.total_water() == before - 5, "total dropped by exactly the displaced cell's level (5)")
	_check(water.displace(puddle) == 0, "displacing a dry cell removes nothing")
	water.add_water(grid, puddle, 5)
	_check(water.remove_water(puddle, 2) == 2 and water.water_at(puddle) == 3, "remove_water drains part of a cell and reports it")


## Legacy 4. No source, no drain: the total is a constant across every tick, checked by the invariant
## `sim/fluid`'s contract names.
func _test_total_is_invariant_over_120_ticks() -> void:
	var grid: TileGrid = TileGrid.new(16, 16, 1)
	var water: WaterPlane = WaterPlane.new()
	for row: int in range(1, 12):
		_rock(grid, Vector2i(2, row))
		_rock(grid, Vector2i(8, row))
	for x: int in range(3, 8):
		_rock(grid, Vector2i(x, 11))
	var total0: int = 0
	total0 += water.add_water(grid, Vector2i(4, 1), 8)
	total0 += water.add_water(grid, Vector2i(6, 1), 8)
	total0 += water.add_water(grid, Vector2i(5, 2), 5)
	var held: int = 0
	for t: int in 120:
		WaterFlow.step(water, grid)
		if Invariants.check_water_conservation(water, total0, t) == null:
			held += 1
	_check_over(120, held == 120, "total_water() invariant across 120 ticks (no source/drain, expect %d; held on %d)" % [total0, held])
	_check(Invariants.report_water_conservation(water, total0, 120) == null, "the reporting twin is silent on a conserved plane")
	_check(Invariants.report_water_not_in_rock(water, grid, 120) == null, "the reporting twin is silent when no water sits in rock")
	_check(Invariants.check_water_conservation(water, total0 + 1, 120) != null, "the conservation check fires when the expected total is wrong (positive control)")
	var wet: Vector2i = water.wet_terrain_cells()[0]
	grid.set_material(wet, ROCK)  # rock over water WITHOUT displace: the coupling step 3's verb must supply
	var rv: Invariants.WaterInRockViolation = Invariants.check_water_not_in_rock(water, grid, 121)
	_check(rv != null and rv.terrain_cell == wet and rv.level == water.water_at(wet),
		"the not-in-rock check fires, naming the cell and its level, when rock lands on water undisplaced (positive control)")


## Legacy 5, plus sensitivity: the signature is content-based, so the same total arranged differently
## hashes differently.
func _test_two_identical_pours_flow_identically_and_different_ones_do_not() -> void:
	var a: Array = _build_and_pour(3)
	var b: Array = _build_and_pour(3)
	for _i: int in 60:
		WaterFlow.step(a[1], a[0])
		WaterFlow.step(b[1], b[0])
	var wa: WaterPlane = a[1]
	var wb: WaterPlane = b[1]
	_check(wa.total_water() == wb.total_water(), "two identical water sims agree on total after 60 ticks")
	_check(wa.levels == wb.levels, "...and on the exact levels dictionary")
	_check(wa.state_signature() == wb.state_signature(), "...and on the state signature (water rides it)")
	var same_total_elsewhere: WaterPlane = WaterPlane.new()
	same_total_elsewhere.add_water(a[0], Vector2i(3, 1), 7)
	var moved: WaterPlane = WaterPlane.new()
	moved.add_water(a[0], Vector2i(5, 1), 7)
	_check(same_total_elsewhere.total_water() == moved.total_water()
		and same_total_elsewhere.state_signature() != moved.state_signature(),
		"same total, different cell: the signatures differ")


func _build_and_pour(first_col: int) -> Array:
	var grid: TileGrid = TileGrid.new(16, 16, 1)
	for row: int in range(1, 10):
		_rock(grid, Vector2i(1, row))
		_rock(grid, Vector2i(7, row))
	for x: int in range(2, 7):
		_rock(grid, Vector2i(x, 9))
	var water: WaterPlane = WaterPlane.new()
	water.add_water(grid, Vector2i(first_col, 1), 7)
	water.add_water(grid, Vector2i(5, 2), 6)
	water.add_water(grid, Vector2i(4, 1), 3)
	return [grid, water]


## The self-check `TileGrid` runs (D0261): after randomised adds, removes and flow steps, the running
## two-lane signature must equal the one rebuilt from the cells. A write that skipped `set_level` shows
## up here and nowhere else.
func _test_running_signature_agrees_with_a_from_scratch_rebuild() -> void:
	var rng: SplitRng = SplitRng.new(20260903)
	var grid: TileGrid = _fuzz_grid(rng, 20, 20, 30)
	var water: WaterPlane = WaterPlane.new()
	var mutations: int = 0
	var agreed: int = 0
	var first_bad: String = ""
	for i: int in 400:
		var op: int = rng.next_range(0, 5)
		var cell := Vector2i(rng.next_range(0, 19), rng.next_range(0, 19))
		if op <= 2:
			water.add_water(grid, cell, rng.next_range(1, 8))
		elif op == 3:
			water.remove_water(cell, rng.next_range(1, 8))
		else:
			WaterFlow.step(water, grid)
		mutations += 1
		if water.state_signature() == water.recomputed_signature():
			agreed += 1
		elif first_bad.is_empty():
			first_bad = " first disagreement at mutation %d: running %s vs rebuilt %s" % [i, water.state_signature(), water.recomputed_signature()]
	_check_over(mutations, agreed == mutations,
		"running signature agrees with the from-scratch rebuild after every one of %d mutations (agreed %d)%s" % [mutations, agreed, first_bad])
	_check(water.total_water() > 0, "the mutation run left water in the world, so the agreement above was over a non-empty plane")
	var copy: WaterPlane = water.clone()
	_check(copy.state_signature() == water.state_signature() and copy.levels == water.levels, "clone carries the levels and the lanes")


## The plan's acceptance for this step: no source, no drain, sum invariant, and never in rock, over
## FUZZ_TICKS ticks of a randomised world. Every pour happens at tick 0 through add_water, whose return
## value is the only source of `total0`, so a refused pour cannot inflate the expectation.
func _test_conservation_and_no_water_in_rock_over_fuzzed_ticks() -> void:
	var rng: SplitRng = SplitRng.new(1337)
	var grid: TileGrid = _fuzz_grid(rng, 24, 24, 35)
	var water: WaterPlane = WaterPlane.new()
	var total0: int = 0
	for _i: int in 60:
		total0 += water.add_water(grid, Vector2i(rng.next_range(0, 23), rng.next_range(0, 23)), rng.next_range(1, 8))
	_check(total0 > 0, "the fuzz poured a non-zero total (%d) so the invariants below have a subject" % total0)
	var conserved: int = 0
	var clean: int = 0
	var first_bad: String = ""
	for t: int in FUZZ_TICKS:
		WaterFlow.step(water, grid)
		var cv: Invariants.WaterConservationViolation = Invariants.check_water_conservation(water, total0, t)
		var rv: Invariants.WaterInRockViolation = Invariants.check_water_not_in_rock(water, grid, t)
		if cv == null:
			conserved += 1
		elif first_bad.is_empty():
			first_bad = " " + cv._to_string()
		if rv == null:
			clean += 1
		elif first_bad.is_empty():
			first_bad = " " + rv._to_string()
	_check_over(FUZZ_TICKS, conserved == FUZZ_TICKS,
		"total water conserved on every one of %d fuzzed ticks (held %d)%s" % [FUZZ_TICKS, conserved, first_bad])
	_check_over(FUZZ_TICKS, clean == FUZZ_TICKS,
		"no water in rock on any of %d fuzzed ticks (clean %d)" % [FUZZ_TICKS, clean])
	_check(water.state_signature() == water.recomputed_signature(), "and the running signature still matches the rebuild at the end")


func _fuzz_grid(rng: SplitRng, w: int, h: int, rock_percent: int) -> TileGrid:
	var grid: TileGrid = TileGrid.new(w, h, 1)
	for row: int in h:
		for col: int in w:
			if rng.next_range(0, 99) < rock_percent:
				_rock(grid, Vector2i(col, row))
	return grid


## Legacy's `cap_total` branch. A floor run of two cells holding more than 2 x WATER_MAX after a settle
## parks the surplus on the leftmost cell rather than dropping it. Only `set_level` can put a cell above
## WATER_MAX (see the header), so the branch is entered directly.
func _test_overflow_rides_the_left_cell_and_nothing_is_dropped() -> void:
	var grid: TileGrid = TileGrid.new(8, 8, 1)
	var water: WaterPlane = WaterPlane.new()
	for row: int in range(1, 4):
		_rock(grid, Vector2i(0, row))
		_rock(grid, Vector2i(3, row))
	_rock(grid, Vector2i(1, 4))
	_rock(grid, Vector2i(2, 4))
	water.set_level(Vector2i(1, 3), 20)
	WaterFlow.step(water, grid)
	_check(water.total_water() == 20, "an over-full run keeps every unit (20)")
	_check(water.water_at(Vector2i(2, 3)) == WaterPlane.WATER_MAX, "the right cell fills to WATER_MAX")
	_check(water.water_at(Vector2i(1, 3)) == WaterPlane.WATER_MAX + 4, "the surplus (4) rides the leftmost cell")
	_check(water.state_signature() == water.recomputed_signature(), "the lanes followed the over-full write too")


func _test_add_water_refuses_rock_and_out_of_bounds_and_clamps_to_room() -> void:
	var grid: TileGrid = TileGrid.new(8, 8, 1)
	var water: WaterPlane = WaterPlane.new()
	_rock(grid, Vector2i(2, 2))
	_check(water.add_water(grid, Vector2i(2, 2), 4) == 0, "add_water refuses a solid cell")
	_check(water.add_water(grid, Vector2i(8, 0), 4) == 0, "add_water refuses an out-of-bounds cell")
	_check(water.add_water(grid, Vector2i(1, 1), 0) == 0 and water.add_water(grid, Vector2i(1, 1), -3) == 0, "add_water refuses a non-positive amount")
	_check(water.total_water() == 0 and water.is_empty(), "nothing above created water")
	_check(water.add_water(grid, Vector2i(1, 1), 5) == 5, "a first pour of 5 into an open cell lands whole")
	_check(water.add_water(grid, Vector2i(1, 1), 6) == 3, "a second pour of 6 is clamped to the 3 units of room")
	_check(water.water_at(Vector2i(1, 1)) == WaterPlane.WATER_MAX, "the cell is now full")


func _test_wet_cells_come_back_in_the_flow_scan_order() -> void:
	var grid: TileGrid = TileGrid.new(8, 8, 1)
	var water: WaterPlane = WaterPlane.new()
	for cell: Vector2i in [Vector2i(5, 2), Vector2i(1, 2), Vector2i(3, 1)]:
		water.add_water(grid, cell, 1)
	var cells: Array[Vector2i] = water.wet_terrain_cells()
	var expected: Array[Vector2i] = [Vector2i(3, 1), Vector2i(1, 2), Vector2i(5, 2)]
	_check(cells == expected,
		"wet_terrain_cells is top-to-bottom then left-to-right, the order WaterFlow scans in (got %s)" % str(cells))
	_check(WaterFlow._cell_less(Vector2i(9, 0), Vector2i(0, 1)) and not WaterFlow._cell_less(Vector2i(0, 1), Vector2i(9, 0)),
		"_cell_less orders by row before column")
