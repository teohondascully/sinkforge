extends "res://tests/test_base.gd"

## The main-scene state-logic blocks lifted into `sim/mining` (A' step 3i, D0354): the integer line of
## sight against legacy's float DDA as an oracle, the aim snap, the dig plan, the break's yield (a burst
## per blow, the rest opening as a lode; rubble sixteenths into blocks), and the hand on a lode.

const CELL: int = Heightfield.TERRAIN_CELL_PX
const ROCK: StringName = &"hardrock"


func _initialize() -> void:
	_test_line_of_sight_cases_and_the_float_oracle()
	_test_aim_is_exact_in_reach_and_snaps_to_the_nearest_visible_face()
	_test_dig_plan_paints_a_drag_and_drains_the_nearest_workable_mark()
	_test_break_yield_bursts_once_and_opens_the_rest_as_lode()
	_test_rubble_banks_sixteenths_into_blocks_and_a_pile_falls()
	_test_hand_on_a_lode_cycles_stalls_on_a_full_pack_and_quickens_with_rhythm()
	_finish("mining_blocks")


## A solid grid with a one-cell shaft opened for the body to stand in at `at`, `depth` cells tall.
func _pocket(material: StringName, at: Vector2i, depth: int = 2) -> TileGrid:
	var grid: TileGrid = _solid_grid(material)
	for dy: int in depth:
		grid.excavate(at - Vector2i(0, dy))
	return grid


## Legacy `main.gd` `_line_of_sight_clear` 2877, floats and all: the oracle the integer walk must match.
func _legacy_los(grid: TileGrid, a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return true
	var ox: float = float(a.x) + 0.5
	var oy: float = float(a.y) + 0.5
	var dx: float = (float(b.x) + 0.5) - ox
	var dy: float = (float(b.y) + 0.5) - oy
	var cx: int = a.x
	var cy: int = a.y
	var step_x: int = signi(dx)
	var step_y: int = signi(dy)
	var t_max_x: float = INF
	var t_delta_x: float = INF
	if dx != 0.0:
		t_delta_x = absf(1.0 / dx)
		t_max_x = ((float(cx + (1 if step_x > 0 else 0))) - ox) / dx
	var t_max_y: float = INF
	var t_delta_y: float = INF
	if dy != 0.0:
		t_delta_y = absf(1.0 / dy)
		t_max_y = ((float(cy + (1 if step_y > 0 else 0))) - oy) / dy
	for _guard: int in 512:
		if t_max_x < t_max_y:
			cx += step_x
			t_max_x += t_delta_x
		else:
			cy += step_y
			t_max_y += t_delta_y
		if cx == b.x and cy == b.y:
			return true
		if grid.is_solid(Vector2i(cx, cy)):
			return false
	return true


## A tie: the ray from a's centre to b's passes exactly through a cell corner, so "x boundary first or y
## boundary first" is a genuine coin toss. With g = gcd(|dx|, |dy|) that happens iff both |dx|/g and
## |dy|/g are odd. Legacy's float walk decided ties by accumulated rounding drift in `t_max += t_delta`,
## which is platform-dependent; the integer walk decides them by rule (y first). So legacy is an oracle
## only off the ties.
func _has_tie(a: Vector2i, b: Vector2i) -> bool:
	var dx: int = absi(b.x - a.x)
	var dy: int = absi(b.y - a.y)
	if dx == 0 or dy == 0:
		return false
	var g: int = dx
	var r: int = dy
	while r != 0:
		var t: int = g % r
		g = r
		r = t
	return (dx / g) % 2 == 1 and (dy / g) % 2 == 1


func _test_line_of_sight_cases_and_the_float_oracle() -> void:
	var grid: TileGrid = TileGrid.new(16, 16, 1)
	var a := Vector2i(2, 2)
	_check(LineOfSight.clear(grid, a, a) and LineOfSight.clear(grid, a, Vector2i(3, 3)) and LineOfSight.clear(grid, a, Vector2i(1, 2)), "the same cell and every neighbour are clear: nothing lies between")
	_check(LineOfSight.clear(grid, a, Vector2i(2, 9)) and LineOfSight.clear(grid, a, Vector2i(9, 2)) and LineOfSight.clear(grid, a, Vector2i(9, 9)), "open air: straight and diagonal lines are clear")
	grid.set_material(Vector2i(2, 5), ROCK)
	_check(not LineOfSight.clear(grid, a, Vector2i(2, 9)) and LineOfSight.clear(grid, a, Vector2i(2, 5)), "a solid cell strictly between blocks; the target itself may be solid (it is what you mine)")
	_check(LineOfSight.clear(grid, a, Vector2i(9, 2)), "a cell off the line does not block")
	var d: TileGrid = TileGrid.new(16, 16, 1)
	d.set_material(Vector2i(1, 1), ROCK)
	_check(not LineOfSight.clear(d, Vector2i(0, 0), Vector2i(3, 3)), "the diagonal (0,0)->(3,3) walks (0,1),(1,1),(1,2),(2,2),(2,3): ties step y first, and (1,1) is on it")
	var d2: TileGrid = TileGrid.new(16, 16, 1)
	d2.set_material(Vector2i(1, 0), ROCK)
	_check(LineOfSight.clear(d2, Vector2i(0, 0), Vector2i(3, 3)), "(1,0) is not on that walk")
	var rng: SplitRng = SplitRng.new(20260903).split("los")
	var noisy: TileGrid = TileGrid.new(32, 32, 1)
	for _i: int in 40:
		noisy.set_material(Vector2i(rng.next_range(0, 32), rng.next_range(0, 32)), ROCK)
	var disagreements: int = 0
	var tie_disagreements: int = 0
	var ties: int = 0
	var blocked: int = 0
	for _j: int in 400:
		var p := Vector2i(rng.next_range(0, 32), rng.next_range(0, 32))
		var q := Vector2i(rng.next_range(0, 32), rng.next_range(0, 32))
		var ours: bool = LineOfSight.clear(noisy, p, q)
		var tie: bool = _has_tie(p, q)
		if tie:
			ties += 1
		if ours != _legacy_los(noisy, p, q):
			if tie:
				tie_disagreements += 1
			else:
				disagreements += 1
				print("  [DISAGREE] %s -> %s ours=%s legacy=%s" % [p, q, ours, not ours])
		if not ours:
			blocked += 1
	_check(disagreements == 0 and ties > 20, "the integer walk agrees with legacy's float DDA on every non-tie pair of 400 random ones (%d non-tie disagreements; %d tie pairs excluded, %d of which legacy's drift decided the other way)" % [disagreements, ties, tie_disagreements])
	_check(blocked > 40 and blocked < 360, "both answers occurred in the sample (%d of 400 blocked)" % blocked)


func _test_aim_is_exact_in_reach_and_snaps_to_the_nearest_visible_face() -> void:
	var grid: TileGrid = _pocket(ROCK, Vector2i(8, 8))
	var body: Vector2i = _at_cell_centre(Vector2i(8, 8))
	var below: Vector2i = _at_cell_centre(Vector2i(8, 9))
	_check(Aim.cell_of(body.x, body.y) == Vector2i(8, 8) and Aim.cell_of(-1, -1) == Vector2i(-1, -1), "the cell of a point, floor division")
	_check(Aim.effective(grid, body.x, body.y, below.x, below.y, false) == Vector2i(8, 9), "an adjacent solid cell in reach: exact")
	var above: Vector2i = _at_cell_centre(Vector2i(8, 7))
	_check(Aim.effective(grid, body.x, body.y, above.x, above.y, false) == Vector2i(8, 7), "an open cell in reach: exact")
	var buried: Vector2i = _at_cell_centre(Vector2i(8, 11))
	_check(Aim.effective(grid, body.x, body.y, buried.x, buried.y, true) == Vector2i(8, 11), "building: the exact cell, whatever it is")
	_check(Aim.effective(grid, body.x, body.y, buried.x, buried.y, false) == Vector2i(8, 9), "a block behind rock: the aim snaps to the nearest reachable face toward the cursor (the floor of the pocket)")
	var side: Vector2i = _at_cell_centre(Vector2i(11, 8))
	_check(Aim.effective(grid, body.x, body.y, side.x, side.y, false) == Vector2i(9, 8), "three cells into the wall beside you: the face you can carve")
	var far: Vector2i = _at_cell_centre(Vector2i(40, 40))
	_check(Aim.effective(grid, body.x, body.y, far.x, far.y, false) == Vector2i(40, 40), "far off: nothing within a reach of the cursor, so the raw cell comes back unsnapped")
	var open: TileGrid = TileGrid.new(64, 64, 1)
	var far_air: Vector2i = _at_cell_centre(Vector2i(30, 30))
	_check(Aim.effective(open, body.x, body.y, far_air.x, far_air.y, false) == Vector2i(30, 30), "open air beyond reach with no wall anywhere: raw")


func _test_dig_plan_paints_a_drag_and_drains_the_nearest_workable_mark() -> void:
	var grid: TileGrid = _pocket(ROCK, Vector2i(8, 8))
	var body: Vector2i = _at_cell_centre(Vector2i(8, 8))
	var plan: DigPlan = DigPlan.new()
	var from: Vector2i = _at_cell_centre(Vector2i(4, 9))
	var to: Vector2i = _at_cell_centre(Vector2i(30, 9))
	plan.paint(grid, from.x, from.y, to.x, to.y)
	_check(plan.marks.size() == 27 and plan.marks.has(Vector2i(4, 9)) and plan.marks.has(Vector2i(30, 9)) and plan.marks.has(Vector2i(17, 9)), "a fast drag across a row marks every solid cell it crossed, sub-cell sampled: 27 of them, including the far ones beyond reach")
	plan.paint(grid, body.x, body.y, body.x, body.y)
	_check(plan.marks.size() == 27, "air takes no mark; painting the same cells again adds nothing")
	var nearest: Vector2i = plan.nearest_workable(grid, body.x, body.y)
	_check(nearest == Vector2i(8, 9), "the nearest workable mark is the one under the body's feet")
	grid.excavate(Vector2i(8, 9))
	_check(plan.nearest_workable(grid, body.x, body.y) == Vector2i(9, 9) or plan.nearest_workable(grid, body.x, body.y) == Vector2i(7, 9), "dug: the mark is spent and the next nearest answers")
	_check(not plan.marks.has(Vector2i(8, 9)) and plan.marks.size() == 26, "the spent mark was pruned")
	var sig: String = plan.state_signature()
	_check(sig.begins_with("p4,9;5,9;") and sig != DigPlan.new().state_signature(), "the plan signs its marks in scan order")
	var cap: DigPlan = DigPlan.new()
	var wide: TileGrid = _solid_grid(ROCK, 64)
	for row: int in 20:
		cap.paint(wide, 0, Fx.from_int(row * CELL), Fx.from_int(63 * CELL), Fx.from_int(row * CELL))
	_check(cap.marks.size() == DigPlan.MAX_MARKS, "the plan caps at %d marks" % DigPlan.MAX_MARKS)
	cap.clear()
	_check(cap.marks.is_empty() and cap.nearest_workable(wide, body.x, body.y) == Mining.NO_CELL, "cleared: nothing to work")


func _test_break_yield_bursts_once_and_opens_the_rest_as_lode() -> void:
	var items: Items = _hub_items()
	var world: World = items.world
	_hub_machines(items)
	for y: int in range(9, 13):
		for x: int in range(4, 12):
			world.set_solid(Vector2i(x, y), ROCK)
	world.set_solid(Vector2i(6, 9), &"ore_iron")
	var mining: Mining = Mining.new()
	var body: Vector2i = _at_cell_centre(Vector2i(26, 34))            # standing in air above the ore metre
	var target: Vector2i = Vector2i(26, 37)                              # a cell of the ore metre (6, 9)
	var took: int = _ticks_to_break(mining, world.grid, body, target, 400)
	_check(took > 0 and mining.broke_cells.size() == 12 and mining.broke_materials.size() == 12 and mining.broke_materials[0] == &"ore_iron", "a blow at the default bite clears 12 cells here (the disc's top cell is the air metre above) and records what each was")
	_check(mining.broke_materials.count(&"ore_iron") == 11 and mining.broke_materials.count(ROCK) == 1, "eleven of them ore, one the rock metre beside")
	items.yield_break(mining.broke_cells, mining.broke_materials)
	var burst: int = items.pack.count(&"ore")   # the vein is ore_iron; the pack holds `ore` (D0409)
	_check(burst >= 3 and burst <= 6 and int(items.total_produced[&"ore"]) == burst, "one 3..6 burst per BLOW into the pack, counted as produced")
	_check(world.deposits.lode_at(target) == &"ore_iron" and world.deposits.ore_deposit_at(world.grid, target) == 16 - burst, "the struck cell opened as a lode holding what the burst left of its 16")
	var lode_total: int = 0
	var opened: int = 0
	for i: int in mining.broke_cells.size():
		var cell: Vector2i = mining.broke_cells[i]
		lode_total += world.deposits.ore_deposit_at(world.grid, cell)
		if cell != target and mining.broke_materials[i] == &"ore_iron" and world.deposits.lode_workable(world.grid, cell) and world.deposits.ore_deposit_at(world.grid, cell) == 16:
			opened += 1
	_check(opened == 10, "every other cleared ore cell opened as a full, workable lode of 16")
	_check(lode_total + burst == 11 * DepositPlane.DEFAULT_ORE_DEPOSIT and world.deposits.lode_at(Vector2i(28, 37)) == &"", "the ore's yield is conserved: burst in the pack plus what the lodes hold; the rock cell opened nothing")
	var v1: Invariants.ItemConservationViolation = Invariants.check_item_conservation(items, 1)
	_check(v1 == null, "conserved" if v1 == null else "NOT conserved: %s present %d net %d" % [v1.item, v1.present, v1.net])


func _test_rubble_banks_sixteenths_into_blocks_and_a_pile_falls() -> void:
	var items: Items = _hub_items()
	var world: World = items.world
	_hub_machines(items)
	for y: int in range(9, 13):
		for x: int in range(4, 12):
			world.set_solid(Vector2i(x, y), ROCK)
	var mining: Mining = Mining.new()
	var rock_target: Vector2i = Vector2i(34, 37)                         # a cell of rock metre (8, 9)
	var body2: Vector2i = _at_cell_centre(Vector2i(34, 34))
	_ticks_to_break(mining, world.grid, body2, rock_target, 400)
	items.yield_break(mining.broke_cells, mining.broke_materials)
	_check(items.pack.count(ROCK) == 0 and mining.broke_cells.size() == 12, "twelve cells of rock: twelve sixteenths, no block yet")
	var sig_after_first: String = items.state_signature()
	_ticks_to_break(mining, world.grid, body2, Vector2i(34, 40), 400)
	items.yield_break(mining.broke_cells, mining.broke_materials)
	_check(items.pack.count(ROCK) == 1 and int(items.total_produced[ROCK]) == 1, "the second bite passes sixteen: one hardrock block in the pack")
	var v2: Invariants.ItemConservationViolation = Invariants.check_item_conservation(items, 2)
	_check(sig_after_first != items.state_signature(), "the rubble bank is state")
	_check(v2 == null, "conserved through the rubble" if v2 == null else "NOT conserved: %s present %d net %d" % [v2.item, v2.present, v2.net])
	world.set_solid(Vector2i(6, 8), ROCK)
	items.pack.add(&"ingot", 2)
	items.produced(&"ingot", 2)
	items.drop_item(Vector2i(10, 2), &"ingot", 2)
	_check(items.piles.count_at(Vector2i(10, 8), &"ingot") == 2, "a pile rests on the rock metre (10, 9)")
	var m3: Mining = Mining.new()
	m3.bite_radius = 3                                                   # a blow that takes the whole metre
	_ticks_to_break(m3, world.grid, _at_cell_centre(Vector2i(42, 34)), Vector2i(42, 37), 400)
	items.yield_break(m3.broke_cells, m3.broke_materials)
	_check(world.logic_air(Vector2i(10, 9)) and items.piles.count_at(Vector2i(10, 8), &"ingot") == 0 and items.piles.count_at(Vector2i(10, 9), &"ingot") == 2, "the metre under the pile is bored out: the pile fell to the next floor")


func _test_hand_on_a_lode_cycles_stalls_on_a_full_pack_and_quickens_with_rhythm() -> void:
	var items: Items = _hub_items()
	var world: World = items.world
	var face := Vector2i(33, 37)
	world.deposits.seed_lode(face, &"coal", 3)
	var body: Vector2i = _at_cell_centre(Vector2i(33, 34))
	var mining: Mining = Mining.new()
	var lode: LodeWork = LodeWork.new()
	_check(LodeWork.LODE_CYCLE_TICKS == 33, "legacy's LODE_CYCLE 0.55 s is 33 ticks")
	var got: StringName = &""
	var ticks: int = 0
	for _i: int in 60:
		ticks += 1
		got = lode.work(world, items, mining, body.x, body.y, face, true)
		if got != &"":
			break
	_check(got == &"coal" and ticks == 33 and items.pack.count(&"coal") == 1 and lode.charge == 0, "a held hand takes one unit off the face on the 33rd tick and the cycle restarts")
	_check(lode.progress_per_mille() == 0, "progress read: 0 after the take")
	lode.work(world, items, mining, body.x, body.y, face, true)
	_check(lode.progress_per_mille() == 1000 / 33 and lode.state_signature() != LodeWork.new().state_signature(), "one tick in: 30 per mille, and the charge is state")
	lode.work(world, items, mining, body.x, body.y, face, false)
	_check(lode.charge == 0 and lode.target == Mining.NO_CELL, "released: nothing banked, the cycle starts over")
	var behind: TileGrid = world.grid
	behind.set_material(Vector2i(33, 35), ROCK)
	_check(lode.work(world, items, mining, body.x, body.y, face, true) == &"" and lode.target == Mining.NO_CELL, "a rock between hand and face: no work (line of sight)")
	behind.excavate(Vector2i(33, 35))
	items.pack.add(&"ore", Pack.bulk_cap() - 1)
	items.produced(&"ore", Pack.bulk_cap() - 1)
	for _i: int in 40:
		lode.work(world, items, mining, body.x, body.y, face, true)
	_check(items.pack.count(&"coal") == 1 and lode.charge >= LodeWork.CYCLE_COST, "a full pack: take_lode refuses, the cycle stalls at full charge rather than spilling")
	items.drop_item(Vector2i(2, 2), &"ore", 10)
	_check(lode.work(world, items, mining, body.x, body.y, face, true) == &"coal", "room made (ten ore dropped): the next tick takes")
	var fresh: Mining = Mining.new()
	var solid: TileGrid = _solid_grid(ROCK)
	for _i: int in 3:
		_ticks_to_break(fresh, solid, _at_cell_centre(Vector2i(8, 8)), Vector2i(8, 9), 400)
		solid.set_material(Vector2i(8, 9), ROCK)
	_check(fresh.rhythm() > 0, "three quick breaks built rhythm")
	var quick: LodeWork = LodeWork.new()
	var t2: int = 0
	for _i: int in 60:
		t2 += 1
		if quick.work(world, items, fresh, body.x, body.y, face, true) != &"":
			break
	_check(t2 < 33 and t2 >= 20, "rhythm quickens the hand: %d ticks a unit instead of 33" % t2)
	_check(Invariants.check_item_conservation(items, 100) == null, "conserved")
