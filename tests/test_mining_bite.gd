extends "res://tests/test_base.gd"

## D0200 (Slice 1.5). THE BITE -- how much of the world one charged blow removes. Split out of
## `tests/test_mining.gd` when the two together crossed QUALITY gate 3's 400-line file limit; that suite
## keeps the charge mechanic (bank, heal, rhythm) and the hollow tell, this one keeps the blow's radius.
##
## The subject is a rate, not a mechanism. Slice 1 charged a full metre's worth of legacy hardness-seconds
## to remove ONE of the sixteen terrain cells that make up a metre, so it mined **16x slower per unit
## volume than legacy** -- a units error that seconds-per-CELL could never surface, because the two
## codebases' cells are different sizes. Every assertion below is written against the metre, which is the
## quantity both codebases share.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_mining_bite.gd

const CELL: int = Heightfield.TERRAIN_CELL_PX


func _initialize() -> void:
	_test_the_bite_disc_has_the_derived_area_at_every_radius()
	_test_bite_radius_zero_is_bit_for_bit_the_slice_1_blow()
	_test_the_bite_costs_the_same_charge_as_a_single_cell()
	_test_the_bite_clears_only_real_cells_and_evicts_their_cracks()
	_test_the_bite_is_deterministic_across_instances()
	_test_the_bite_restores_legacys_own_volumetric_rate()
	_finish("mining_bite")


## The disc's own areas, asserted against the geometry rather than against a table of expected numbers:
## a cell is in the bite iff `dx*dx + dy*dy <= r*r`. Counting them independently here is what makes the
## derived `DEFAULT_BITE_RADIUS` comment checkable instead of merely asserted.
func _test_the_bite_disc_has_the_derived_area_at_every_radius() -> void:
	var observed: Array[int] = []
	for r: int in range(0, 4):
		var grid: TileGrid = _solid_grid(&"clay")
		var mining: Mining = Mining.new()
		mining.bite_radius = r
		var body: Vector2i = _at_cell_centre(Vector2i(32, 32))
		var target: Vector2i = Vector2i(32, 34)
		_ticks_to_break(mining, grid, body, target, 400)
		observed.append(mining.broke_cells.size())
		# Independently recounted from the inequality, so this is two derivations agreeing, not one restated.
		var expected: int = 0
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r:
					expected += 1
		_check(mining.broke_cells.size() == expected,
			"radius %d clears the %d cells inside dx^2+dy^2 <= %d (cleared %d)"
			% [r, expected, r * r, mining.broke_cells.size()])
		_check(mining.broke_cells[0] == target,
			"radius %d records the charged target FIRST, so a view can tell the struck cell from the spall" % r)
	print("  [OBSERVED] bite areas by radius 0..3: %s cells" % str(observed))
	_check(observed[Mining.DEFAULT_BITE_RADIUS] == 13,
		"the shipped default clears 13 cells (got %d)" % observed[Mining.DEFAULT_BITE_RADIUS])


## The probe's control, and the reason a director sweeping `--bite=` is running an experiment rather than
## comparing against a remembered build: radius 0 must be the Slice 1 blow exactly, not approximately.
## Asserted on the GRID's own signature over a long run, not on one break -- a bite that leaked a single
## extra cell every hundred ticks would pass a one-break check.
func _test_bite_radius_zero_is_bit_for_bit_the_slice_1_blow() -> void:
	var grid: TileGrid = _solid_grid(&"clay")
	var mining: Mining = Mining.new()
	mining.bite_radius = Mining.CONTROL_BITE_RADIUS
	var body: Vector2i = _at_cell_centre(Vector2i(32, 32))
	var cleared: int = 0
	for t: int in 400:
		var target: Vector2i = Vector2i(30 + (t % 5), 34 + ((t / 9) % 3))
		mining.mine(grid, body.x, body.y, target, true)
		cleared += mining.broke_cells.size()
	var solid_missing: int = 0
	for dy: int in range(-6, 7):
		for dx: int in range(-6, 7):
			if not grid.is_solid(Vector2i(32 + dx, 34 + dy)):
				solid_missing += 1
	print("  [OBSERVED] radius 0 over 400 ticks: %d cells cleared, %d missing from a 13x13 window"
		% [cleared, solid_missing])
	_check(cleared == solid_missing,
		"at radius 0 the number of cells cleared equals the number of holes in the world -- every blow removed exactly one cell and none of them overlapped (%d vs %d)"
		% [cleared, solid_missing])
	_check(cleared > 0, "and the control actually mined, rather than passing because nothing happened")


## Charge is earned on the TARGET and the radius is the blow's, not the price's. This is the whole reason
## the bite restores legacy's rate: legacy charged one material's hardness-seconds for one full square
## metre, so scaling cost with area would undo the fix and leave the rate exactly where Slice 1 left it.
func _test_the_bite_costs_the_same_charge_as_a_single_cell() -> void:
	for material: StringName in [&"clay", &"hardrock", &"deepstone"]:
		var ticks: Array[int] = []
		for r: int in [Mining.CONTROL_BITE_RADIUS, Mining.DEFAULT_BITE_RADIUS]:
			var grid: TileGrid = _solid_grid(material)
			var mining: Mining = Mining.new()
			mining.bite_radius = r
			var body: Vector2i = _at_cell_centre(Vector2i(32, 32))
			ticks.append(_ticks_to_break(mining, grid, body, Vector2i(32, 34), 400))
		_check(ticks[0] == ticks[1] and ticks[0] == Mining.ticks_to_break(material),
			"%s takes the same %d ticks at radius %d as at radius %d -- the bite changes what a blow REMOVES, never what it costs (%d vs %d)"
			% [material, Mining.ticks_to_break(material), Mining.CONTROL_BITE_RADIUS,
			Mining.DEFAULT_BITE_RADIUS, ticks[0], ticks[1]])


## Two properties that would each be silent if wrong. A bite reaching past the world edge, or through
## already-open air, must report the honest smaller number rather than the disc's nominal area; and a cell
## the blow removes may not keep banked charge, or the bank would accumulate entries for cells that no
## longer exist and `state_signature` would diverge on them forever.
func _test_the_bite_clears_only_real_cells_and_evicts_their_cracks() -> void:
	var grid: TileGrid = _solid_grid(&"clay")
	var mining: Mining = Mining.new()
	var body: Vector2i = _at_cell_centre(Vector2i(1, 32))
	# Half-charge a neighbour that the coming blow's disc will swallow, so the eviction has a subject.
	var neighbour: Vector2i = Vector2i(2, 35)
	for _i: int in 8:
		mining.mine(grid, body.x, body.y, neighbour, true)
	var banked_before: int = mining.banked(neighbour)
	_check(banked_before > 0, "the neighbour carried real banked charge before the blow (%d units)" % banked_before)
	var target: Vector2i = Vector2i(1, 34)  ## col 1: the disc reaches col -1, which does not exist
	_ticks_to_break(mining, grid, body, target, 400)
	var full_disc: int = 13
	print("  [OBSERVED] a radius-%d bite two columns from the world edge cleared %d of a nominal %d cells"
		% [Mining.DEFAULT_BITE_RADIUS, mining.broke_cells.size(), full_disc])
	_check(mining.broke_cells.size() < full_disc,
		"a bite whose disc overhangs the world edge clears fewer than its nominal %d cells (%d)"
		% [full_disc, mining.broke_cells.size()])
	for cell: Vector2i in mining.broke_cells:
		_check(grid.in_bounds(cell), "every recorded cleared cell is inside the world (%s)" % str(cell))
	_check(mining.banked(neighbour) == 0,
		"a cell swallowed by the blow loses its banked charge rather than leaving a crack on a cell that no longer exists (%d units left)"
		% mining.banked(neighbour))
	_check(not grid.is_solid(neighbour), "and the neighbour really did go with the blow")


## The determinism assertion the gate depends on, run at the shipped radius. Iterating a `Dictionary` to
## clear the disc would pass this by luck on one machine; the nested integer `range` is what makes it hold.
func _test_the_bite_is_deterministic_across_instances() -> void:
	var sigs: Array[String] = []
	var orders: Array[String] = []
	for _run: int in 2:
		var grid: TileGrid = _solid_grid(&"clay")
		var mining: Mining = Mining.new()
		var order: PackedStringArray = []
		for t: int in 300:
			# Sinks BOTH the aim and the body, five rows at a time, so every step meets fresh rock, stays
			# inside the 12.8-cell reach, and completes a 17-tick clay charge inside its 25-tick window.
			# The first draft cycled 28 cells of hardrock and never completed a single charge -- the order
			# assertion below is what caught it, and it stays as the control for exactly that.
			var row: int = 34 + 5 * (t / 25)
			var target: Vector2i = Vector2i(31, row)
			var body: Vector2i = _at_cell_centre(Vector2i(31, row - 2))
			mining.mine(grid, body.x, body.y, target, t % 13 != 0)
			for cell: Vector2i in mining.broke_cells:
				order.append("%d,%d" % [cell.x, cell.y])
		sigs.append("%s|%s" % [mining.state_signature(), grid.state_signature()])
		orders.append(";".join(order))
	_check(sigs[0] == sigs[1],
		"two independent runs at the shipped bite radius produce identical mining AND grid state")
	_check(orders[0] == orders[1],
		"and clear their cells in the identical ORDER -- what `broke_cells` promises a view")
	_check(orders[0].length() > 20, "the run actually broke something rather than passing on two empty strings")


## The number the whole probe is about, printed rather than buried. Legacy's `CELL` is 32px and one charge
## removes one of them -- one square metre. This world's metre is `Body.LOGIC_TILE_PX`, which is
## `(16/4)^2 = 16` terrain cells, and Slice 1 removed exactly ONE of them per charge.
func _test_the_bite_restores_legacys_own_volumetric_rate() -> void:
	var cells_per_metre: int = (Body.LOGIC_TILE_PX / CELL) * (Body.LOGIC_TILE_PX / CELL)
	var grid: TileGrid = _solid_grid(&"clay")
	var mining: Mining = Mining.new()
	var body: Vector2i = _at_cell_centre(Vector2i(32, 32))
	_ticks_to_break(mining, grid, body, Vector2i(32, 34), 400)
	var bite: int = mining.broke_cells.size()
	var secs: float = float(Mining.ticks_to_break(&"clay")) / 60.0
	print("  [OBSERVED] one metre is %d terrain cells. clay: legacy 1.000 m^2 in 0.280 s; Slice 1 %.3f m^2 in %.3f s; radius %d %.3f m^2 in %.3f s"
		% [cells_per_metre, 1.0 / float(cells_per_metre), secs, Mining.DEFAULT_BITE_RADIUS,
		float(bite) / float(cells_per_metre), secs])
	print("  [OBSERVED] volumetric rate against legacy: Slice 1 %.2fx, radius %d %.2fx"
		% [1.0 / float(cells_per_metre) / (secs / 0.280), Mining.DEFAULT_BITE_RADIUS,
		float(bite) / float(cells_per_metre) / (secs / 0.280)])
	_check(bite <= cells_per_metre,
		"the shipped bite never removes MORE than legacy's one square metre per charge (%d cells of %d)"
		% [bite, cells_per_metre])
	# The derivation's own claim: r=2 is the largest disc that stays under a metre, so r=3 must exceed it.
	# Without this the constant could be any small number and still pass the bound above.
	var over: int = 0
	for dy: int in range(-3, 4):
		for dx: int in range(-3, 4):
			if dx * dx + dy * dy <= 9:
				over += 1
	_check(over > cells_per_metre,
		"and it is the LARGEST such disc -- radius %d would clear %d cells, past the metre's %d"
		% [Mining.DEFAULT_BITE_RADIUS + 1, over, cells_per_metre])
