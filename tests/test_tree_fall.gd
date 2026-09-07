extends "res://tests/test_base.gd"

## `sim/mining/tree_fall.gd` -- the crown falls with the trunk (T034 taken provisionally, D0438). Posed on
## flat ground with the tree pass's own planter, so every wood and leaf cell is one it put there; then the
## trunk is cut cell by cell as a MINE hold cuts it, bottom up, and the leaves are watched.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_tree_fall.gd

const W: int = 128
const H: int = 96
const GROUND: int = 64
const COL: int = 60
const TRUNK: int = 8          ## two metres, the tutorial tree's
const TRUNK_W: int = 2
const RX: int = 6
const RY: int = 5


func _initialize() -> void:
	_test_a_standing_trunk_holds_every_leaf()
	_test_a_stub_in_the_foliage_holds_nothing()
	_test_the_last_cut_drops_the_crown_nearest_first()
	_test_a_neighbours_crown_stands_on_its_own_wood()
	_finish("tree_fall")


func _ground() -> TileGrid:
	var grid: TileGrid = TileGrid.new(W, H, 3)
	for col: int in W:
		for row: int in range(GROUND, H):
			grid.set_material(Vector2i(col, row), &"clay")
	return grid


func _cells_of(grid: TileGrid, material: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for col: int in W:
		for row: int in GROUND:
			if grid.get_material(Vector2i(col, row)) == material:
				out.append(Vector2i(col, row))
	return out


## Cut one wood cell the way the hold does: excavate, then hand the break to the crown.
func _cut(grid: TileGrid, fall: TreeFall, cell: Vector2i) -> void:
	grid.excavate(cell)
	fall.after_break(grid, [cell], [&"wood"])


func _test_a_standing_trunk_holds_every_leaf() -> void:
	var grid: TileGrid = _ground()
	TreePass.plant_one(grid, COL, GROUND, TRUNK, TRUNK_W, RX, RY)
	var leaves: int = _cells_of(grid, &"leaves").size()
	var wood: int = _cells_of(grid, &"wood").size()
	_check(wood == TRUNK * TRUNK_W and leaves > 30, "the planter stands %d wood and %d leaves" % [wood, leaves])
	var fall: TreeFall = TreeFall.new()
	# Three cells nicked out of the left column: the right column still runs from the ground to the crown.
	for h: int in [2, 4, 6]:
		_cut(grid, fall, Vector2i(COL, GROUND - h))
	for _t: int in 60:
		fall.crumble(grid)
	_check(fall.pending() == 0 and _cells_of(grid, &"leaves").size() == leaves, "with one column of the trunk still grounded under the crown, nothing is queued and every leaf stays (%d of %d)" % [_cells_of(grid, &"leaves").size(), leaves])
	# Control for the search itself: a leaf cut loose by hand, with nothing of the tree cut, is not the
	# crown's business -- the box holds wood, so the rest stays; but a floating leaf far from any wood is
	# unsupported by the same rule.
	grid.set_material(Vector2i(COL + 40, GROUND - 20), &"leaves")
	var loose: Array[Vector2i] = TreeFall.unsupported_leaves(grid, Vector2i(COL + 40, GROUND - 20))
	_check(loose.size() == 1 and loose[0] == Vector2i(COL + 40, GROUND - 20), "control: a lone leaf forty cells off, with the standing crown inside its box, is the one unsupported cell (%s)" % [loose])


## The bite is a disc, so a live felling leaves the trunk's top row -- inside the canopy's bottom -- standing
## alone in the leaves. Wood that reaches no ground through wood holds nothing; the stub itself stays.
func _test_a_stub_in_the_foliage_holds_nothing() -> void:
	var grid: TileGrid = _ground()
	TreePass.plant_one(grid, COL, GROUND, TRUNK, TRUNK_W, RX, RY)
	var leaves: int = _cells_of(grid, &"leaves").size()
	var fall: TreeFall = TreeFall.new()
	for h: int in range(1, TRUNK):                     # every row but the top one
		for dx: int in TRUNK_W:
			_cut(grid, fall, Vector2i(COL + dx, GROUND - h))
	_check(_cells_of(grid, &"wood").size() == TRUNK_W and grid.get_material(Vector2i(COL, GROUND - TRUNK)) == &"wood", "control: the top row of the trunk still stands, two cells of wood inside the canopy's bottom row")
	_check(fall.pending() == leaves, "...and holds nothing: every leaf is queued (%d of %d)" % [fall.pending(), leaves])
	for _t: int in 200:
		fall.crumble(grid)
	_check(_cells_of(grid, &"leaves").is_empty() and _cells_of(grid, &"wood").size() == TRUNK_W, "the crown is gone and the stub stays, its two cuts still the player's wood")


func _test_the_last_cut_drops_the_crown_nearest_first() -> void:
	var grid: TileGrid = _ground()
	TreePass.plant_one(grid, COL, GROUND, TRUNK, TRUNK_W, RX, RY)
	var leaves: int = _cells_of(grid, &"leaves").size()
	var fall: TreeFall = TreeFall.new()
	for h: int in range(1, TRUNK + 1):
		for dx: int in TRUNK_W:
			_cut(grid, fall, Vector2i(COL + dx, GROUND - h))
	_check(fall.pending() == leaves, "the trunk cut from the ground up, every leaf is queued once though fifteen more cuts followed the first (%d of %d)" % [fall.pending(), leaves])
	var top: Vector2i = Vector2i(COL + 1, GROUND - TRUNK)
	var first_d: int = -1
	var last_d: int = -1
	var ticks: int = 0
	var monotone: bool = true
	while fall.pending() > 0 and ticks < 200:
		fall.crumble(grid)
		ticks += 1
		for c: Vector2i in fall.crumbled_this_tick:
			var d: int = absi(c.x - top.x) + absi(c.y - top.y)
			if first_d < 0:
				first_d = d
			if d < last_d:
				monotone = false
			last_d = d
	_check(_cells_of(grid, &"leaves").is_empty() and ticks == (leaves + TreeFall.CRUMBLE_PER_TICK - 1) / TreeFall.CRUMBLE_PER_TICK,
		"the crown crumbles to nothing at %d cells a tick: %d ticks for %d leaves" % [TreeFall.CRUMBLE_PER_TICK, ticks, leaves])
	_check(monotone and first_d <= 2 and last_d > first_d, "nearest the cut first: the fall runs outward from %d to %d cells off the trunk's top" % [first_d, last_d])
	_check(grid.state_signature() == grid.recomputed_signature(), "the grid's signature agrees with its rebuild after the collapse")


func _test_a_neighbours_crown_stands_on_its_own_wood() -> void:
	var grid: TileGrid = _ground()
	TreePass.plant_one(grid, COL, GROUND, TRUNK, TRUNK_W, RX, RY)
	TreePass.plant_one(grid, COL + 10, GROUND, TRUNK, TRUNK_W, RX, RY)   # crowns overlap by two cells
	var touching: bool = false
	for c: Vector2i in _cells_of(grid, &"leaves"):
		if c.x == COL + 6 and grid.get_material(c + Vector2i(1, 0)) == &"leaves":
			touching = true
	_check(touching, "control: the two crowns touch, so support could flow between them")
	var before: Array[Vector2i] = _cells_of(grid, &"leaves")
	var fall: TreeFall = TreeFall.new()
	for h: int in range(1, TRUNK + 1):
		for dx: int in TRUNK_W:
			_cut(grid, fall, Vector2i(COL + dx, GROUND - h))
	for _t: int in 200:
		fall.crumble(grid)
	var after: Array[Vector2i] = _cells_of(grid, &"leaves")
	var neighbour_wood: int = _cells_of(grid, &"wood").size()
	_check(neighbour_wood == TRUNK * TRUNK_W and after.size() == before.size(), "felling one tree of two whose crowns touch drops NO leaf: the merged canopy stands on the neighbour's trunk (%d of %d)" % [after.size(), before.size()])
	for h: int in range(1, TRUNK + 1):
		for dx: int in TRUNK_W:
			_cut(grid, fall, Vector2i(COL + 10 + dx, GROUND - h))
	for _t: int in 200:
		fall.crumble(grid)
	_check(_cells_of(grid, &"leaves").is_empty(), "...and the second trunk cut, the whole merged canopy is gone")
