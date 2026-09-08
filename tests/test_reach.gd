extends "res://tests/test_base.gd"
## THE ONE REACH RULE IN CORE (D0521): `Reach` is the arithmetic `Aim.in_reach_point` had, moved to the floor
## of the stack so the view can draw the drop's own line. Three things are pinned. (1) `Reach` and the sim's
## `Aim.in_reach_logic` agree on a 400-point grid of body centres round the tutorial forge (29, 20), the
## boundary cells 128-130 at row 75 among them; the first disagreeing point is printed. (2) The rule IS the
## Euclidean 3.2 m, inclusive: the same grid against an independent float compare, with the ins and outs
## counted so a degenerate population cannot pass. (3) The edge is D0520's own probe: at row 75 px 514 is
## in and 515 out, and the circle is 16/5 and not `Observation.REACH_PX`'s truncated 51 px.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_reach.gd
const S: int = Fx.SCALE
const TILE: int = 16
const FORGE: Vector2i = Vector2i(29, 20)        ## the tutorial's surface forge: its centre is px (472, 328)
const ROW_75_Y: int = 300                       ## the body's centre y with its feet on the surface
const REACH_PX: float = 3.2 * 16.0              ## 51.2 px, the rule in the unit the receipts count in
## 20 x 20 body centres, at the terrain cells' own centres: columns 115-134 (px 462-538, from 10 px left of
## the forge's centre to 66 right), rows 66-85 (px 266-342, 62 above to 14 below). Both sides of the
## circle on both axes.
const COL_0: int = 115
const ROW_0: int = 66
const SIDE: int = 20


func _initialize() -> void:
	_test_reach_agrees_with_the_sim_on_the_grid()
	_test_the_rule_is_the_euclidean_three_point_two_metres()
	_test_the_edge_is_the_probes_own()
	_test_the_sims_names_are_cores_numbers()
	_finish("reach")


func _grid_point(i: int, j: int) -> Vector2i:
	return Vector2i((COL_0 + i) * 4 + 2, (ROW_0 + j) * 4 + 2)


func _test_reach_agrees_with_the_sim_on_the_grid() -> void:
	var first_bad: String = ""
	var n: int = 0
	for j: int in SIDE:
		for i: int in SIDE:
			var p: Vector2i = _grid_point(i, j)
			n += 1
			var core_says: bool = Reach.in_reach_metre(p.x * S, p.y * S, FORGE, TILE)
			var sim_says: bool = Aim.in_reach_logic(p.x * S, p.y * S, FORGE)
			if core_says != sim_says and first_bad == "":
				first_bad = "px %s: Reach %s, Aim %s" % [str(p), str(core_says), str(sim_says)]
	_check(n == 400 and first_bad == "", "Reach and Aim.in_reach_logic agree at all %d body centres round the forge (first disagreement: %s)" % [n, first_bad if first_bad != "" else "none"])
	var centre: Vector2i = Reach.metre_centre_fx(FORGE, TILE)
	_check(centre == Vector2i(FORGE.x * Aim.LOGIC_FX + Aim.LOGIC_FX / 2, FORGE.y * Aim.LOGIC_FX + Aim.LOGIC_FX / 2) and centre == Vector2i(472 * S, 328 * S),
		"the metre's centre is the sim's own input, px (472, 328) in Fx (%s)" % str(Vector2(centre) / float(S)))


## The independent compare: integer px deltas squared against 51.2^2 in float. The deltas are whole px, so
## the sum is an exact integer and 2621.44 never ties it.
func _test_the_rule_is_the_euclidean_three_point_two_metres() -> void:
	var ins: int = 0
	var outs: int = 0
	var first_bad: String = ""
	for j: int in SIDE:
		for i: int in SIDE:
			var p: Vector2i = _grid_point(i, j)
			var ddx: int = p.x - 472
			var ddy: int = p.y - 328
			var euclid: bool = float(ddx * ddx + ddy * ddy) <= REACH_PX * REACH_PX
			var got: bool = Reach.in_reach(p.x * S, p.y * S, 472 * S, 328 * S, TILE)
			if got:
				ins += 1
			else:
				outs += 1
			if got != euclid and first_bad == "":
				first_bad = "px %s at %.2f px: Reach %s, Euclid %s" % [str(p), sqrt(float(ddx * ddx + ddy * ddy)), str(got), str(euclid)]
	_check(first_bad == "" and ins > 100 and outs > 100, "Reach is the inclusive Euclidean 51.2 px circle at every grid point: %d in, %d out (first disagreement: %s)" % [ins, outs, first_bad if first_bad != "" else "none"])


## D0520's headless probe: at row 75 the drop passes at px 514 and fails at 515. Cell 128's centre (514) is
## the band's last cell; 129 (518) and 130 (522) are past it; 107 (430) is the band's first, 106 (426) short.
func _test_the_edge_is_the_probes_own() -> void:
	var at_514: bool = Reach.in_reach_metre(514 * S, ROW_75_Y * S, FORGE, TILE)
	var at_515: bool = Reach.in_reach_metre(515 * S, ROW_75_Y * S, FORGE, TILE)
	_check(at_514 and not at_515, "row 75: px 514 in (42^2 + 28^2 = 2548 <= 2621.44), px 515 out (2633): got %s, %s" % [str(at_514), str(at_515)])
	var cells: Array = []
	for c: int in [106, 107, 128, 129, 130]:
		cells.append(Reach.in_reach_metre((c * 4 + 2) * S, ROW_75_Y * S, FORGE, TILE))
	_check(cells == [false, true, true, false, false], "cells 106, 107, 128, 129, 130 at row 75: out, in, in, out, out (%s)" % str(cells))
	# Not the truncated REACH_PX: an offset of (51, 4) px is 2617 px^2, inside 51.2^2 and outside 51^2.
	var fine: bool = Reach.in_reach((472 + 51) * S, (328 + 4) * S, 472 * S, 328 * S, TILE)
	_check(fine and Interface.Observation.REACH_PX == 51, "the circle is 16/5 (51.2 px), not Observation.REACH_PX's %d: an offset of (51, 4) px is in (%s)" % [Interface.Observation.REACH_PX, str(fine)])
	# The axis reject admits nothing the circle refuses: 52 px straight along one axis is out.
	_check(not Reach.in_reach((472 + 52) * S, 328 * S, 472 * S, 328 * S, TILE) and Reach.in_reach((472 + 51) * S, 328 * S, 472 * S, 328 * S, TILE), "along one axis 51 px is in and 52 out")


func _test_the_sims_names_are_cores_numbers() -> void:
	_check(Mining.REACH_NUM == Reach.NUM and Mining.REACH_DEN == Reach.DEN and Reach.NUM == 16 and Reach.DEN == 5, "Mining.REACH_NUM/DEN are Reach.NUM/DEN, 16/5 (%d/%d, %d/%d)" % [Mining.REACH_NUM, Mining.REACH_DEN, Reach.NUM, Reach.DEN])
