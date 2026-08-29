class_name ObservationBuilder
extends RefCounted

## THE CONTROL PLANE brief's S4 seam: a PURE function of (state, spec) -- no policy argument. Fairness
## and anti-cheat live in exactly this one place every policy shares, not duplicated per-policy the way
## `tests/body/scripted_traverse.gd`'s own oracle policy currently reads `Body`/`TileGrid` and privileged
## `HostileChamber` constants directly. CONSTRAINED must never call `grid.get_material()`/`is_solid()`
## outside its own declared radius -- the anti-cheat property `tests/control_plane/
## test_observation_builder.gd` proves directly, matching `RevealMetric`/`RevealReplayDriver`'s own
## established discipline (docs/DECISIONS_LEDGER.md D0109): the metric/observation may only see what its
## own contract allows, never grid state beyond it.

static func build(body: Body, grid: TileGrid, spec: ObservationSpec) -> CanonicalObservation:
	var obs: CanonicalObservation = CanonicalObservation.new()
	obs.pos_x = body.pos_x
	obs.pos_y = body.pos_y
	obs.vel_x = body.vel_x
	obs.vel_y = body.vel_y
	obs.on_floor = body.on_floor
	obs.facing = body.facing
	obs.envelope = spec.envelope
	obs.visible_cells = _visible_cells(body, grid, spec)
	return obs


static func _visible_cells(body: Body, grid: TileGrid, spec: ObservationSpec) -> Dictionary:
	var cells: Dictionary = {}
	if spec.envelope == ObservationSpec.ORACLE:
		for row: int in range(grid.height):
			for col: int in range(grid.width):
				cells[Vector2i(col, row)] = _cell_info(grid, Vector2i(col, row))
		return cells
	# CONSTRAINED: only the box within `vision_radius_cells` of the body's own cell is ever read from
	# `grid` at all -- not filtered out of a full scan afterward, which would still have CALLED
	# `get_material` on an out-of-radius cell even if the result were later discarded, the same "reads
	# the subject before the caveat applies" shape D0109's own anti-cheat contract exists to forbid.
	var body_col: int = Body._px_to_cell(body.pos_x)
	var body_row: int = Body._px_to_cell(body.pos_y)
	var r: int = spec.vision_radius_cells
	for row: int in range(maxi(0, body_row - r), mini(grid.height, body_row + r + 1)):
		for col: int in range(maxi(0, body_col - r), mini(grid.width, body_col + r + 1)):
			cells[Vector2i(col, row)] = _cell_info(grid, Vector2i(col, row))
	return cells


static func _cell_info(grid: TileGrid, cell: Vector2i) -> Dictionary:
	var solid: bool = grid.is_solid(cell)
	return {"solid": solid, "material": grid.get_material(cell) if solid else &""}
