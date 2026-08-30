class_name PropertyChecks
extends RefCounted

## D0058, item 3 of the director's exploration-tier reframe. Named, reusable correctness properties over
## `Body`+`TileGrid` state -- pure, stateless predicates, same shape as `sim/invariants`' own checks, but
## TEST-ONLY: violating one is a testing signal for THIS harness to act on, never something the shipped
## controller should silently correct, so these live here rather than in `sim/invariants`. Consumed by
## `fixture_body_fuzz_probe.gd` (checked every tick, same as the fuzzer's other five invariants) and
## available to any future property-specific generator without duplicating the predicate itself.


## How many solid cells the body's own box currently overlaps — zero at every tick is the property the
## collision resolver exists to maintain, and anything else means the body is INSIDE rock. The half-open
## convention matters and is why this reads `_right_x() - 1`/`_bottom_y() - 1`: a body RESTING on a floor
## does not overlap it, so a nonzero count here is never just contact.
##
## Moved here 2026-08-30 (D0206) from SIX independent copies — `tests/fixture_step_up_into_wall_probe.gd`,
## `tests/test_cave_geometry.gd`, `tests/test_footprint_grounding.gd`, `tests/test_step_up_grounding.gd`,
## and two `tools/scratch/` probes — which `tools/quality_check/duplication.py` found as one cluster. It
## belongs in this file specifically, not in `test_base.gd`: this is a named reusable property over
## `Body`+`TileGrid`, which is what this module's own docstring says it is for, and being a `class_name`
## global it also reaches the fixture that extends `SceneTree` rather than the suite base.
##
## Worth noting how close this came to shipping broken: the duplication gate is BLOCKING, but it runs
## after the LOC-ratio gate in the same CI job, and that gate is red — so CI reported this step as
## `skipped`, not failed, on the commit that took the cluster from three copies to six.
static func solid_overlap_count(body: Body, grid: TileGrid) -> int:
	var n: int = 0
	for col: int in range(Body._px_to_cell(body._left_x()), Body._px_to_cell(body._right_x() - 1) + 1):
		for row: int in range(Body._px_to_cell(body._top_y()), Body._px_to_cell(body._bottom_y() - 1) + 1):
			if grid.in_bounds(Vector2i(col, row)) and grid.is_solid(Vector2i(col, row)):
				n += 1
	return n


## "Grounded implies solid ground beneath." `on_floor == true` should mean there is real solid material
## directly under the body's ENTIRE horizontal footprint, not just somewhere within reach -- a body
## resting with only part of its footprint over solid ground is not genuinely standing. Checks the row
## immediately below `_bottom_y()` across every column the body's box spans. This is a second, independent
## signal for the same class of defect `embedded` catches from a different angle: mantling onto
## `HostileChamber.JUMP_CORNER`'s single floating tile (D0057) sets `on_floor = true` via `_try_step`
## without the body ever landing on a real, full-width surface -- `check_bounds`-style, it doesn't care
## WHY the property fails, only that it does.
static func grounded_implies_solid_beneath(body: Body, grid: TileGrid) -> bool:
	if not body.on_floor:
		return true
	var row: int = Body._px_to_cell(body._bottom_y())
	var left_col: int = Body._px_to_cell(body._left_x())
	var right_col: int = Body._px_to_cell(body._right_x() - 1)
	for col: int in range(left_col, right_col + 1):
		if not grid.is_solid(Vector2i(col, row)):
			return false
	return true
