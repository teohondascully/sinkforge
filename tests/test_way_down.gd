extends "res://tests/test_base.gd"

## THE WAY DOWN (D0440, D0509, D0568): who the footing spare rule protects, and who it was silently
## stopping. Posed fresh for every case, because the defect this suite exists to pin is invisible the
## moment the body has already fallen -- `Footing.of_body` returns nothing for a body in the air, so a
## case run after a case that dropped the body asserts nothing at all. The first version of this
## assertion lived at the tail of `test_interface_verbs.gd`'s footing test and survived reverting the
## rule it was written to pin, for exactly that reason.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_way_down.gd

const W: int = 60
const H: int = 60
const FLOOR_ROW: int = 40
const COL: int = 21


func _initialize() -> void:
	_test_a_side_blow_still_spares_the_boots()
	_test_a_blow_aimed_down_beside_the_boots_spares_nothing()
	_test_a_blow_from_the_air_spares_nothing_as_before()
	_test_the_margin_is_bounded_by_the_side_blow_it_must_not_swallow()
	_finish("way_down")


func _rig() -> TileGrid:
	var grid: TileGrid = TileGrid.new(W, H, 4)
	for col: int in W:
		for row: int in range(FLOOR_ROW, H):
			grid.set_material(Vector2i(col, row), &"hardrock")
	return grid


func _standing(grid: TileGrid) -> Body:
	var body: Body = Body.new(Fx.from_int(COL * Mining.CELL_PX), Fx.from_int((FLOOR_ROW - 8) * Mining.CELL_PX))
	var input: InputFrame = InputFrame.new()
	for _i: int in 90:
		body.tick(input, grid)
	return body


func _boots(body: Body) -> Array[Vector2i]:
	return Footing.of_body(body)


func _test_a_side_blow_still_spares_the_boots() -> void:
	var grid: TileGrid = _rig()
	var body: Body = _standing(grid)
	var feet: Array[Vector2i] = _boots(body)
	_check(body.on_floor and feet.size() == 4, "control: the body stands on four boot cells (%s)" % str(feet))
	var beside := Vector2i(feet[0].x - 3, feet[0].y)          # three columns clear: D0509's vein
	var spared: Array[Vector2i] = Footing.spared_for(body, beside)
	_check(spared.size() == 4, "a blow three columns to the side still spares all four boots (%d)" % spared.size())


## THE CHANGE. A blow aimed at the support row one column outside the boots is a player digging out from
## under themselves, and nothing is spared. Before D0568 the two-cell disc took everything AROUND the
## boots and left them standing on a pedestal -- which is why an Opus playthrough cut eleven cells
## straight down beneath itself across eight bursts and descended zero.
func _test_a_blow_aimed_down_beside_the_boots_spares_nothing() -> void:
	var grid: TileGrid = _rig()
	var body: Body = _standing(grid)
	var feet: Array[Vector2i] = _boots(body)
	var near := Vector2i(feet[0].x - Footing.OUT_MARGIN, feet[0].y)
	_check(not feet.has(near), "the aimed cell is NOT one of the four, which is the whole point (%s)" % near)
	_check(Footing.spared_for(body, near).is_empty(),
		"a blow aimed down beside the boots spares nothing: descent is a verb, not a pixel-hunt")
	var below := Vector2i(feet[2].x, feet[0].y + 2)           # under them, and deeper
	_check(Footing.spared_for(body, below).is_empty(), "and so does one aimed below them")


func _test_a_blow_from_the_air_spares_nothing_as_before() -> void:
	var grid: TileGrid = _rig()
	var body: Body = Body.new(Fx.from_int(COL * Mining.CELL_PX), Fx.from_int((FLOOR_ROW - 20) * Mining.CELL_PX))
	_check(not body.on_floor, "control: the body is in the air")
	_check(Footing.spared_for(body, Vector2i(COL, FLOOR_ROW)).is_empty(),
		"a body in the air has no footing and spares nothing, exactly as D0509 wrote it")


## `OUT_MARGIN` is not a free number. `tests/test_interface_verbs.gd` fires D0509's own side blow TWO
## columns clear of the boots and requires it to be spared, so the margin cannot reach 2 without turning
## that suite red. Pinned here as an ordering between two constants rather than left for someone to
## rediscover by breaking a different file.
func _test_the_margin_is_bounded_by_the_side_blow_it_must_not_swallow() -> void:
	var grid: TileGrid = _rig()
	var body: Body = _standing(grid)
	var feet: Array[Vector2i] = _boots(body)
	_check(Footing.OUT_MARGIN < 2, "OUT_MARGIN (%d) stays under the two-column side blow D0509 protects" % Footing.OUT_MARGIN)
	_check(Footing.spared_for(body, Vector2i(feet[0].x - 2, feet[0].y)).size() == 4,
		"...and a blow exactly two columns out is still spared")
