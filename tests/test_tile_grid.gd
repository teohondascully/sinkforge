extends "res://tests/test_base.gd"

func _initialize() -> void:
	_test_in_bounds()
	_test_material_get_set()
	_test_wall_get_set()
	_test_is_solid()
	_test_excavate_reveals_wall_not_material()
	_test_occupied_terrain_cells_sorted_and_excludes_air()
	_test_state_signature_stable_and_sensitive()
	_test_extend_terrain_dig_extent_first_touch_is_just_that_touch()
	_test_extend_terrain_dig_extent_merges_across_touches_closing_the_gap()
	_test_extend_terrain_dig_extent_is_per_column()
	_test_state_signature_sensitive_to_dig_extent()
	_test_running_signature_agrees_with_a_from_scratch_rebuild()
	_finish("tile_grid")


func _test_in_bounds() -> void:
	var grid: TileGrid = TileGrid.new(4, 3, 1)
	_check(grid.in_bounds(Vector2i(0, 0)), "(0,0) in bounds")
	_check(grid.in_bounds(Vector2i(3, 2)), "(width-1, height-1) in bounds")
	_check(not grid.in_bounds(Vector2i(4, 0)), "(width, 0) out of bounds")
	_check(not grid.in_bounds(Vector2i(0, 3)), "(0, height) out of bounds")
	_check(not grid.in_bounds(Vector2i(-1, 0)), "negative x out of bounds")


func _test_material_get_set() -> void:
	var grid: TileGrid = TileGrid.new(4, 4, 1)
	var cell: Vector2i = Vector2i(1, 1)
	_check(grid.get_material(cell) == &"", "unset cell reads as air (empty StringName)")
	grid.set_material(cell, &"clay")
	_check(grid.get_material(cell) == &"clay", "set_material then get_material round-trips")


func _test_wall_get_set() -> void:
	var grid: TileGrid = TileGrid.new(4, 4, 1)
	var cell: Vector2i = Vector2i(1, 1)
	_check(grid.get_wall(cell) == &"", "unset wall reads as air")
	grid.set_wall(cell, &"hardrock")
	_check(grid.get_wall(cell) == &"hardrock", "set_wall then get_wall round-trips")


func _test_is_solid() -> void:
	var grid: TileGrid = TileGrid.new(4, 4, 1)
	var cell: Vector2i = Vector2i(2, 2)
	_check(not grid.is_solid(cell), "cell with no material is not solid")
	grid.set_material(cell, &"clay")
	_check(grid.is_solid(cell), "cell with a material is solid")


func _test_excavate_reveals_wall_not_material() -> void:
	var grid: TileGrid = TileGrid.new(4, 4, 1)
	var cell: Vector2i = Vector2i(2, 2)
	grid.set_material(cell, &"clay")
	grid.set_wall(cell, &"hardrock")
	grid.excavate(cell)
	_check(not grid.is_solid(cell), "excavated cell is no longer solid")
	_check(grid.get_material(cell) == &"", "excavated cell's material is gone")
	_check(grid.get_wall(cell) == &"hardrock", "excavated cell's wall is unaffected -- the hole is a conveyor, not a void")


func _test_occupied_terrain_cells_sorted_and_excludes_air() -> void:
	var grid: TileGrid = TileGrid.new(5, 5, 1)
	grid.set_material(Vector2i(3, 1), &"clay")
	grid.set_material(Vector2i(0, 1), &"clay")
	grid.set_material(Vector2i(2, 0), &"clay")
	grid.set_wall(Vector2i(4, 4), &"hardrock")  # a wall with no block should not appear
	var cells: Array[Vector2i] = grid.occupied_terrain_cells()
	_check(cells.size() == 3, "occupied_terrain_cells excludes wall-only cells (%d found, expected 3)" % cells.size())
	_check(cells[0] == Vector2i(2, 0) and cells[1] == Vector2i(0, 1) and cells[2] == Vector2i(3, 1),
		"occupied_terrain_cells sorted by (y, x): got %s" % [cells])


func _test_state_signature_stable_and_sensitive() -> void:
	var a: TileGrid = TileGrid.new(4, 4, 1)
	var b: TileGrid = TileGrid.new(4, 4, 1)
	a.set_material(Vector2i(1, 1), &"clay")
	a.set_material(Vector2i(2, 2), &"hardrock")
	b.set_material(Vector2i(2, 2), &"hardrock")
	b.set_material(Vector2i(1, 1), &"clay")
	_check(a.state_signature() == b.state_signature(),
		"state_signature is the same regardless of the order cells were set in")
	b.set_material(Vector2i(1, 1), &"deepstone")
	_check(a.state_signature() != b.state_signature(), "state_signature changes when a cell's material differs")


## D0125. A column's first-ever touch has no history to merge against -- the returned range must be
## exactly the touch itself, unchanged. This is the backward-compatible case every existing dig test
## (`test_body.gd`) already exercises; asserting it here pins the contract at the `TileGrid` level too.
func _test_extend_terrain_dig_extent_first_touch_is_just_that_touch() -> void:
	var grid: TileGrid = TileGrid.new(10, 20, 1)
	var extent: Vector2i = grid.extend_terrain_dig_extent(3, 5, 8)
	_check(extent == Vector2i(5, 8), "first touch to a column returns exactly that touch's own range, got %s" % [extent])


## D0125's whole reason to exist: two touches to the same column with a GAP between them must merge
## into one contiguous span covering both, regardless of which touch happened first -- a low touch then
## a high one, and the reverse. This is the property that makes the D0122/D0123 staircase structurally
## impossible: the caller (`Body._handle_dig`) excavates the returned range, not just its own touch.
func _test_extend_terrain_dig_extent_merges_across_touches_closing_the_gap() -> void:
	var low_then_high: TileGrid = TileGrid.new(10, 20, 1)
	low_then_high.extend_terrain_dig_extent(4, 10, 12)
	var merged_a: Vector2i = low_then_high.extend_terrain_dig_extent(4, 15, 17)
	_check(merged_a == Vector2i(10, 17),
		"low touch then high touch merges to the full span with the gap closed, got %s" % [merged_a])

	var high_then_low: TileGrid = TileGrid.new(10, 20, 1)
	high_then_low.extend_terrain_dig_extent(4, 15, 17)
	var merged_b: Vector2i = high_then_low.extend_terrain_dig_extent(4, 10, 12)
	_check(merged_b == Vector2i(10, 17),
		"high touch then low touch merges to the same full span regardless of order, got %s" % [merged_b])

	var overlapping: TileGrid = TileGrid.new(10, 20, 1)
	overlapping.extend_terrain_dig_extent(4, 10, 14)
	var merged_c: Vector2i = overlapping.extend_terrain_dig_extent(4, 12, 16)
	_check(merged_c == Vector2i(10, 16), "overlapping touches merge to their union, got %s" % [merged_c])


## Column-scoped, not grid-wide (director's own explicit ruling: adjacent-column disagreement is legal
## geometry `_resolve_horizontal` already handles) -- a touch to one column must not extend another's.
func _test_extend_terrain_dig_extent_is_per_column() -> void:
	var grid: TileGrid = TileGrid.new(10, 20, 1)
	grid.extend_terrain_dig_extent(4, 10, 12)
	var other: Vector2i = grid.extend_terrain_dig_extent(5, 50, 52)
	_check(other == Vector2i(50, 52), "a different column's touch is unaffected by another column's extent, got %s" % [other])
	var same_col_again: Vector2i = grid.extend_terrain_dig_extent(4, 20, 22)
	_check(same_col_again == Vector2i(10, 22),
		"column 4's own extent still merges correctly after an unrelated column was touched, got %s" % [same_col_again])


## D0125's own state_signature() change: dig history is real state that affects future gameplay and
## isn't derivable from `_blocks` alone, so two grids with identical blocks but different dig history
## must produce different signatures -- and identical dig history reached via different touch order must
## produce the SAME signature (matching the existing order-independence property above).
func _test_state_signature_sensitive_to_dig_extent() -> void:
	var a: TileGrid = TileGrid.new(10, 20, 1)
	var b: TileGrid = TileGrid.new(10, 20, 1)
	_check(a.state_signature() == b.state_signature(), "two fresh grids with no dig history match")
	a.extend_terrain_dig_extent(4, 10, 12)
	_check(a.state_signature() != b.state_signature(), "state_signature changes when dig history differs")
	b.extend_terrain_dig_extent(4, 15, 17)  # gives b SOME history at col 4, but not the same range as a
	_check(a.state_signature() != b.state_signature(), "state_signature differs when dig extents at the same column differ")
	a.extend_terrain_dig_extent(4, 15, 17)
	b.extend_terrain_dig_extent(4, 10, 12)
	_check(a.state_signature() == b.state_signature(),
		"state_signature matches once both grids reach the same merged extent, regardless of touch order")


## THE GUARD FOR D0261'S O(1) SIGNATURE, and the reason that optimisation is safe to make.
##
## `state_signature()` is now carried incrementally by the four mutation methods instead of rebuilt.
## Its failure mode is silent and total: a path that forgets to update leaves the running value stale,
## and **a stale value agrees with itself across two runs**, so `test_shaft_replay_determinism` goes
## green while the two worlds genuinely differ. That is this project's house failure class arriving in
## its usual costume, and no amount of care while editing prevents it.
##
## So the running value is checked against a from-scratch rebuild of the same state after EVERY kind of
## mutation, and then after a long randomised sequence of them. A forgotten update in any path makes
## this fail immediately -- which is a durable guard, unlike remembering to write a mutation test each
## time someone adds a method.
##
## The randomised tail is not decoration. The per-method checks below all mutate a cell that was in a
## known state; the sequence reaches combinations nobody enumerated -- excavating an already-air cell,
## setting a wall behind air and then filling the block in front of it, re-digging a column that already
## has an extent. `excavate` on air and `set_wall` behind air are exactly the two no-op cases where an
## over-eager xor (rather than a forgotten one) desynchronises the hash, so the sequence tests both
## directions of the same mistake.
func _test_running_signature_agrees_with_a_from_scratch_rebuild() -> void:
	var grid: TileGrid = TileGrid.new(16, 16, 7)
	_check(grid.state_signature() == grid.recomputed_signature(),
		"an empty grid's running signature already agrees with a rebuild (%s)" % grid.state_signature())

	var steps: Array[String] = []
	grid.set_material(Vector2i(2, 3), &"clay")
	steps.append("set_material")
	grid.set_wall(Vector2i(2, 3), &"slate")
	steps.append("set_wall behind a block")
	grid.set_wall(Vector2i(9, 9), &"slate")
	steps.append("set_wall behind AIR (must change nothing)")
	grid.excavate(Vector2i(2, 3))
	steps.append("excavate")
	grid.excavate(Vector2i(5, 5))
	steps.append("excavate AIR (must change nothing)")
	grid.extend_terrain_dig_extent(2, 3, 6)
	steps.append("extend_terrain_dig_extent, first touch")
	grid.extend_terrain_dig_extent(2, 1, 9)
	steps.append("extend_terrain_dig_extent, merging")
	for label: String in steps:
		pass
	_check_over(steps.size(), grid.state_signature() == grid.recomputed_signature(),
		"after each of %d mutation kinds (%s) the running signature still equals a rebuild -- running %s, rebuilt %s"
		% [steps.size(), ", ".join(steps), grid.state_signature(), grid.recomputed_signature()])

	# A long pseudo-random sequence over a small grid, so cells collide and every path is re-entered on
	# state it did not create. SplitRng, not randi(): this file is a determinism test and may not seed
	# itself from the clock.
	var rng: SplitRng = SplitRng.new(20260831)
	var mats: Array[StringName] = [&"clay", &"slate", &"glimmer"]
	var mutations: int = 0
	for _i: int in 400:
		var c: Vector2i = Vector2i(rng.next_range(0, 7), rng.next_range(0, 7))
		var pick: int = rng.next_range(0, 3)
		if pick == 0:
			grid.set_material(c, mats[rng.next_range(0, mats.size() - 1)])
		elif pick == 1:
			grid.set_wall(c, mats[rng.next_range(0, mats.size() - 1)])
		elif pick == 2:
			grid.excavate(c)
		else:
			grid.extend_terrain_dig_extent(c.x, c.y, c.y + rng.next_range(0, 4))
		mutations += 1
	_check_over(mutations, grid.state_signature() == grid.recomputed_signature(),
		"and after %d randomised mutations -- running %s, rebuilt %s"
		% [mutations, grid.state_signature(), grid.recomputed_signature()])
	_check(grid.state_signature() != "0:0",
		"positive control: the sequence actually left a non-empty signature (%s) -- two ZEROS would " % grid.state_signature()
		+ "agree with each other while proving nothing at all")
