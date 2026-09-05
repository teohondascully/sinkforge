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
	_test_the_cell_hash_does_not_collide_where_the_string_form_could()
	_test_the_coarse_plane_is_classed_at_the_centre_and_versioned()
	_test_load_cells_equals_the_per_cell_writers()
	_finish("tile_grid")


## D0397: the bulk loader a restore uses must be the per-cell writers' equal in every plane, including
## the running signature -- and the signature is checked against its own rebuild, so a loader that folded
## a term wrong could not agree with both. Cells out of bounds ride along (the writers accept them too);
## walls behind air are in the dictionary and not in the signature, as ever.
func _test_load_cells_equals_the_per_cell_writers() -> void:
	var rng: SplitRng = SplitRng.new(99)
	var blocks: Dictionary = {}
	var walls: Dictionary = {}
	var ids: Array[StringName] = [&"clay", &"hardrock", &"ore_copper", &"coal"]
	for _i: int in 900:
		var cell := Vector2i(rng.next_range(-1, 24), rng.next_range(-1, 40))
		if rng.next_range(0, 3) > 0:
			blocks[cell] = ids[rng.next_range(0, 3)]
		if rng.next_range(0, 2) > 0:
			walls[cell] = ids[rng.next_range(0, 3)]
	var slow: TileGrid = TileGrid.new(24, 40, 5)
	for cell: Vector2i in blocks:
		slow.set_material(cell, blocks[cell])
	for cell: Vector2i in walls:
		slow.set_wall(cell, walls[cell])
	var fast: TileGrid = TileGrid.new(24, 40, 5)
	_check(fast.load_cells(blocks, walls), "an empty grid takes the bulk load")
	_check(fast.state_signature() == slow.state_signature() and fast.state_signature() == fast.recomputed_signature(), "the same signature as the per-cell writers, and it agrees with its own rebuild (%s vs %s)" % [fast.state_signature(), slow.state_signature()])
	_check(fast.block_index == slow.block_index and fast.wall_index == slow.wall_index and fast.legend == slow.legend, "the same index planes and the same legend order")
	_check(fast.sky_floor == slow.sky_floor and fast.coarse == slow.coarse, "the same sky floor and the same coarse plane")
	_check(fast.occupied_terrain_cells() == slow.occupied_terrain_cells() and fast.wall_terrain_cells() == slow.wall_terrain_cells(), "the same cells enumerate")
	_check(not fast.load_cells(blocks, walls) and fast.state_signature() == slow.state_signature(), "a second load onto a holding grid is refused and changes nothing")
	blocks.erase(blocks.keys()[0])
	var fewer: TileGrid = TileGrid.new(24, 40, 5)
	fewer.load_cells(blocks, walls)
	_check(fewer.state_signature() != slow.state_signature() and fewer.state_signature() == fewer.recomputed_signature(), "control: one cell fewer is another signature, still agreeing with its rebuild")


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
## impossible: the caller (`BodyDig.handle`) excavates the returned range, not just its own touch.
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


## THE COLLISIONS THE STRING FORM WAS EXPOSED TO (D0334). `_cell_term` used to fold the text
## `"%d,%d:%s/%s"`, where `(1, 23)` and `(12, 3)` differ only in where the comma falls and a material/wall
## pair differs only in where the slash falls. Folding is order-sensitive so the old form did in fact
## separate them, but nothing asserted it — and the replacement mixes x, y, material and wall as four
## terms at four fold positions, which is the property that has to hold whichever form is in use.
##
## Written as a POSITIVE-CONTROL sweep rather than one hand-picked pair: a hash that returned a constant
## would pass any single inequality that happened to be written the other way round.
func _test_the_cell_hash_does_not_collide_where_the_string_form_could() -> void:
	# Pairs whose text forms are anagram-adjacent: the digits are the same and only the separator moves.
	var swaps: Array = [
		[Vector2i(1, 23), Vector2i(12, 3)],
		[Vector2i(1, 23), Vector2i(23, 1)],
		[Vector2i(11, 2), Vector2i(1, 12)],
		[Vector2i(4, 56), Vector2i(45, 6)],
	]
	var distinct: int = 0
	for pair: Array in swaps:
		var a: TileGrid = TileGrid.new(64, 64, 7)
		a.set_material(pair[0] as Vector2i, &"clay")
		a.set_wall(pair[0] as Vector2i, &"clay")
		var b: TileGrid = TileGrid.new(64, 64, 7)
		b.set_material(pair[1] as Vector2i, &"clay")
		b.set_wall(pair[1] as Vector2i, &"clay")
		if a.state_signature() != b.state_signature():
			distinct += 1
		else:
			_check(false, "cells %s and %s hash the same" % [pair[0], pair[1]])
	_check_over(swaps.size(), distinct == swaps.size(),
		"coordinate pairs that share their digits still hash apart -- %d of %d" % [distinct, swaps.size()])

	# MATERIAL AND WALL ARE DIFFERENT TERMS, not one concatenation: swapping them must change the answer.
	var m: TileGrid = TileGrid.new(64, 64, 7)
	m.set_material(Vector2i(5, 5), &"clay")
	m.set_wall(Vector2i(5, 5), &"hardrock")
	var w: TileGrid = TileGrid.new(64, 64, 7)
	w.set_material(Vector2i(5, 5), &"hardrock")
	w.set_wall(Vector2i(5, 5), &"clay")
	_check(m.state_signature() != w.state_signature(),
		"swapping a cell's material and wall changes the signature")

	# CONTROL: two grids built the SAME way agree. Without this every row above passes on a hash that
	# returned a fresh value each call, which would break determinism entirely while looking rigorous.
	var c1: TileGrid = TileGrid.new(64, 64, 7)
	c1.set_material(Vector2i(5, 5), &"clay")
	c1.set_wall(Vector2i(5, 5), &"hardrock")
	_check(c1.state_signature() == m.state_signature(),
		"CONTROL: an identically-built grid matches, so the inequalities above are the hash separating "
			+ "inputs and not a hash that never repeats")

	_check_the_memo_is_populated_by_use()


## THE MEMO, ASSERTED STRUCTURALLY RATHER THAN BY TIMING. Split from the test above at the 50-line limit.
func _check_the_memo_is_populated_by_use() -> void:
	# A mutant that disables the cache LOOKUP A mutant that disables the cache lookup makes the
	# code slower and still correct, so no correctness assertion can catch it and a timing one would be
	# flaky (and would have to run alone -- a duration assertion under parallel jobs measures contention).
	# What CAN be checked without a clock is that the cache is actually populated by use: if it never
	# filled, the lookup could never hit however the code was written. The measured saving itself is in
	# D0334, taken by removing the subject.
	var before: int = StateHash._id_folds.size()
	var probe: TileGrid = TileGrid.new(8, 8, 1)
	probe.set_material(Vector2i(1, 1), &"a_material_no_other_test_uses")
	probe.set_wall(Vector2i(1, 1), &"another_unused_material")
	_check(StateHash._id_folds.size() > before,
		"folding two unseen ids populated the memo (%d -> %d entries), so the lookup has something to hit"
			% [before, StateHash._id_folds.size()])
	_check(StateHash._id_folds.has(&"a_material_no_other_test_uses"),
		"and it is keyed by the id itself")


## D0371. The coarse plane: one class byte per logic cell, classed by the cell's CENTRE terrain cell,
## maintained at the mutators, versioned only on a change.
func _test_the_coarse_plane_is_classed_at_the_centre_and_versioned() -> void:
	var g: TileGrid = TileGrid.new(9, 6, 1)
	_check(g.coarse_width == 3 and g.coarse_height == 2 and g.coarse.size() == 6, "a 9x6 grid is a 3x2 coarse plane, the ragged edge rounded up (%dx%d)" % [g.coarse_width, g.coarse_height])
	_check(g.coarse_at(Vector2i(1, 1)) == TileGrid.COARSE_VOID and g.coarse_version == 0, "empty: void everywhere, version 0")
	g.set_material(Vector2i(4, 4), &"clay")      # not a centre: (4,4) is offset (0,0) of logic (1,1)
	_check(g.coarse_at(Vector2i(1, 1)) == TileGrid.COARSE_VOID and g.coarse_version == 0, "a write off the centre changes no class and no version")
	g.set_material(Vector2i(6, 6), &"clay")      # the centre of logic (1,1)
	_check(g.coarse_at(Vector2i(1, 1)) == TileGrid.COARSE_ROCK and g.coarse_version == 1, "a write at the centre classes the cell rock and bumps the version once")
	g.set_material(Vector2i(6, 6), &"clay")
	_check(g.coarse_version == 1, "rewriting the same class does not bump")
	g.set_material(Vector2i(6, 6), &"ore_iron")
	_check(g.coarse_at(Vector2i(1, 1)) == TileGrid.COARSE_ORE and g.coarse_version == 2, "ore at the centre classes ore")
	g.set_wall(Vector2i(6, 6), &"clay")
	g.excavate(Vector2i(6, 6))
	_check(g.coarse_at(Vector2i(1, 1)) == TileGrid.COARSE_WALL and g.coarse_version == 3, "dug with a wall behind classes wall (the wall write itself changed nothing under rock)")
	g.set_wall(Vector2i(6, 6), &"")
	_check(g.coarse_at(Vector2i(1, 1)) == TileGrid.COARSE_VOID, "wall cleared: void again")
	_check(g.coarse_at(Vector2i(-1, 0)) == TileGrid.COARSE_VOID and g.coarse_at(Vector2i(3, 0)) == TileGrid.COARSE_VOID, "outside the plane reads void")
	g.set_material(Vector2i(2, 2), &"hardrock")
	var c: TileGrid = g.clone()
	_check(c.coarse == g.coarse and c.coarse_version == g.coarse_version, "a clone carries the plane and its version")
	c.set_material(Vector2i(2, 2), &"")
	_check(g.coarse_at(Vector2i(0, 0)) == TileGrid.COARSE_ROCK and c.coarse_at(Vector2i(0, 0)) == TileGrid.COARSE_VOID, "and shares no state with the original")
	# The plane is NOT in the signature: two grids holding the same cells hash the same however many
	# coarse changes each went through to get there.
	var a: TileGrid = TileGrid.new(9, 6, 1)
	a.set_material(Vector2i(6, 6), &"clay")
	a.set_material(Vector2i(6, 6), &"ore_iron")
	var b: TileGrid = TileGrid.new(9, 6, 1)
	b.set_material(Vector2i(6, 6), &"ore_iron")
	_check(a.coarse_version == 2 and b.coarse_version == 1 and a.state_signature() == b.state_signature(), "two routes to one world: versions 2 and 1, one signature")
