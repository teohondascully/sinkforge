extends "res://tests/test_base.gd"

## D0139: unit tests for `VerticalResolve._full_footprint_solid` and the `resolve_floor` fix it backs --
## the resolver must ESTABLISH `grounded_implies_solid_beneath`'s own invariant (full-footprint solidity
## at the landing row), not approximate it via three point-samples (D0137's diagnosed mechanism).

const CELL: int = Heightfield.TERRAIN_CELL_PX
const TEST_FLOOR_ROW: int = 40
const TEST_SPAWN_ROW: int = Body.HEIGHT_PX / Heightfield.TERRAIN_CELL_PX / 2


func _initialize() -> void:
	_test_full_footprint_solid_true_when_every_column_solid()
	_test_full_footprint_solid_false_when_any_column_open()
	_test_resolve_floor_still_grounds_a_normal_flat_floor()
	_test_resolve_floor_refuses_a_partial_footprint_landing()
	_finish("vertical_resolve")


func _test_full_footprint_solid_true_when_every_column_solid() -> void:
	var grid: TileGrid = TileGrid.new(20, 30, 1)
	for col: int in range(0, 20):
		for row: int in range(15, 20):
			grid.set_material(Vector2i(col, row), &"hardrock")
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(10 * CELL))
	_check(VerticalResolve._full_footprint_solid(body, grid, Fx.from_int(15 * CELL)),
		"every column across the footprint is solid at the landing row -- passes")


func _test_full_footprint_solid_false_when_any_column_open() -> void:
	# Same shape as D0137's own diagnosed occurrences: solid under most of the footprint, open under
	# the rest -- a pit lip, not a real floor for the whole box.
	var grid: TileGrid = TileGrid.new(20, 30, 1)
	var half_width_cols: int = Body.WIDTH_PX / CELL / 2
	for col: int in range(10 - half_width_cols, 10):  # solid under the LEFT half only
		for row: int in range(15, 20):
			grid.set_material(Vector2i(col, row), &"hardrock")
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(10 * CELL))
	_check(not VerticalResolve._full_footprint_solid(body, grid, Fx.from_int(15 * CELL)),
		"solid under only half the footprint fails -- partial support is not full support")


func _test_resolve_floor_still_grounds_a_normal_flat_floor() -> void:
	var grid: TileGrid = _flat_grid(TEST_FLOOR_ROW, 20)
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(TEST_SPAWN_ROW * CELL))
	for i: int in range(200):
		body.tick(InputFrame.new(), grid)
	_check(body.on_floor, "a body given 200 ticks to fall still settles on an ordinary flat floor")
	_check(body.floor_source_this_tick == &"resolve_floor",
		"the ordinary landing is still attributed to resolve_floor, not grid_floor_backstop (got %s)" %
		body.floor_source_this_tick)


func _test_resolve_floor_refuses_a_partial_footprint_landing() -> void:
	# Reconstructs D0137's own diagnosed shape directly: a real floor under part of the footprint,
	# open air under the rest, at the exact row a naive three-sample resolve_floor would have grounded
	# on before this fix. Columns 0-9 solid (not just under the footprint) so the LEFT foot sample's own
	# straddle never touches an unset neighbouring column and reports NO_FLOOR by accident -- that would
	# make `surface` itself NO_FLOOR and reject via the OLDER, pre-existing check instead of this fix's
	# own new one, silently passing for the wrong reason (found by mutation-testing this exact test).
	var grid: TileGrid = TileGrid.new(20, 30, 1)
	for col: int in range(0, 10):
		for row: int in range(15, 20):
			grid.set_material(Vector2i(col, row), &"hardrock")
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(13 * CELL))
	var result: bool = VerticalResolve.resolve_floor(body, grid)
	_check(not result, "resolve_floor refuses to ground a body over a partial-support pit lip (got %s)" % result)
	_check(not body.on_floor, "on_floor stays false -- grid_floor_backstop gets its own turn next, not this call")
