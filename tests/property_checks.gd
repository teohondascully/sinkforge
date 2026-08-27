class_name PropertyChecks
extends RefCounted

## D0058, item 3 of the director's exploration-tier reframe. Named, reusable correctness properties over
## `Body`+`TileGrid` state -- pure, stateless predicates, same shape as `sim/invariants`' own checks, but
## TEST-ONLY: violating one is a testing signal for THIS harness to act on, never something the shipped
## controller should silently correct, so these live here rather than in `sim/invariants`. Consumed by
## `fixture_body_fuzz_probe.gd` (checked every tick, same as the fuzzer's other five invariants) and
## available to any future property-specific generator without duplicating the predicate itself.


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
