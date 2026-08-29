extends "res://tests/test_base.gd"

## Proves `ObservationBuilder`'s CONSTRAINED envelope never leaks a cell outside its own declared radius
## -- the anti-cheat property THE CONTROL PLANE brief's S4 seam requires, matching `RevealMetric`'s own
## established discipline (docs/DECISIONS_LEDGER.md D0109). ORACLE's own unrestricted-by-design behavior
## is proven too, so the CONTRAST between the two envelopes is explicit, not an accident of one code path
## nobody exercised both sides of.

const CELL: int = Heightfield.TERRAIN_CELL_PX


func _initialize() -> void:
	_test_constrained_sees_only_within_radius()
	_test_oracle_sees_the_whole_grid()
	_test_canonical_action_round_trips_through_input_frame()
	_finish("observation_builder")


func _test_constrained_sees_only_within_radius() -> void:
	var grid: TileGrid = TileGrid.new(40, 40, 1)
	var body: Body = Body.new(20 * CELL * Fx.SCALE, Fx.from_int(20 * CELL))
	var spec: ObservationSpec = ObservationSpec.constrained(3)
	var obs: CanonicalObservation = ObservationBuilder.build(body, grid, spec)
	_check(obs.envelope == ObservationSpec.CONSTRAINED, "the observation names its own envelope")
	_check(obs.visible_cells.has(Vector2i(20, 20)), "the body's own cell is visible")
	_check(not obs.visible_cells.has(Vector2i(30, 30)),
		"a cell far outside the radius is ABSENT from the observation, not merely unsolid -- the anti-cheat property")
	_check(obs.visible_cells.size() == 49,
		"a radius-3 box centered away from any grid edge is exactly 7x7=49 cells (got %d)" %
		obs.visible_cells.size())


func _test_oracle_sees_the_whole_grid() -> void:
	var grid: TileGrid = TileGrid.new(10, 8, 1)
	var body: Body = Body.new(5 * CELL * Fx.SCALE, Fx.from_int(5 * CELL))
	var obs: CanonicalObservation = ObservationBuilder.build(body, grid, ObservationSpec.oracle())
	_check(obs.envelope == ObservationSpec.ORACLE, "the observation names its own envelope")
	_check(obs.visible_cells.size() == 80, "oracle sees every cell in a 10x8 grid (got %d)" % obs.visible_cells.size())


func _test_canonical_action_round_trips_through_input_frame() -> void:
	var action: CanonicalAction = CanonicalAction.new()
	action.move_dir = 1
	action.jump_pressed = true
	action.dig_pressed = true
	var input: InputFrame = action.to_input_frame()
	_check(input.move_dir == 1 and input.jump_pressed and input.dig_pressed and
		not input.jump_held and not input.mantle_hold,
		"every field survives the canonical-action -> InputFrame translation unchanged")
