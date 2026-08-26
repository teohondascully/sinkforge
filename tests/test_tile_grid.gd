extends "res://tests/test_base.gd"

func _initialize() -> void:
	_test_in_bounds()
	_test_material_get_set()
	_test_wall_get_set()
	_test_is_solid()
	_test_excavate_reveals_wall_not_material()
	_test_occupied_cells_sorted_and_excludes_air()
	_test_state_signature_stable_and_sensitive()
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


func _test_occupied_cells_sorted_and_excludes_air() -> void:
	var grid: TileGrid = TileGrid.new(5, 5, 1)
	grid.set_material(Vector2i(3, 1), &"clay")
	grid.set_material(Vector2i(0, 1), &"clay")
	grid.set_material(Vector2i(2, 0), &"clay")
	grid.set_wall(Vector2i(4, 4), &"hardrock")  # a wall with no block should not appear
	var cells: Array = grid.occupied_cells()
	_check(cells.size() == 3, "occupied_cells excludes wall-only cells (%d found, expected 3)" % cells.size())
	_check(cells[0] == Vector2i(2, 0) and cells[1] == Vector2i(0, 1) and cells[2] == Vector2i(3, 1),
		"occupied_cells sorted by (y, x): got %s" % [cells])


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
