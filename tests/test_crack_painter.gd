extends "res://tests/test_base.gd"

## `view/visuals/crack_painter.gd` — the ported spider cracks (D0275, LEGACY_GAP T1 #5).
##
## `segments()` returns the geometry as data so it can be asserted directly. A painter tested only by
## calling `paint()` can assert nothing beyond "it did not crash", and an early return does exactly that
## while drawing nothing — the same reasoning `tests/test_hud.gd` records for the depth chip.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_crack_painter.gd

const CELL: int = Heightfield.TERRAIN_CELL_PX
const BLOW: float = 20.0   ## the default bite's footprint: (2 * 2 + 1) cells x 4px


func _initialize() -> void:
	_test_nothing_is_drawn_below_the_visibility_floor()
	_test_the_crack_grows_with_progress_in_both_count_and_length()
	_test_the_star_is_centred_on_its_cell_and_stays_near_it()
	_test_the_pattern_is_deterministic_and_differs_between_cells()
	_test_the_whole_visible_range_of_progress_produces_geometry()
	_test_the_frame_form_refuses_a_frame_that_carries_no_scale()
	_finish("crack_painter")


## Legacy's `_mine_frac <= 0.001` guard. A cell the player brushed past for one tick must not be
## decorated, or every surface they walked along carries permanent-looking damage.
func _test_nothing_is_drawn_below_the_visibility_floor() -> void:
	_check(CrackPainter.segments(Vector2i(3, 4), 0, CELL, BLOW).is_empty(),
		"zero progress draws nothing")
	_check(not CrackPainter.segments(Vector2i(3, 4), CrackPainter.MIN_VISIBLE, CELL, BLOW).is_empty(),
		"and the floor itself DOES draw -- without this the check above passes on a painter that never draws")


## BOTH AXES OF GROWTH, because legacy grows the crack two ways and either alone reads wrong: more
## fractures with no more length looks like confetti, more length with no more fractures looks like a
## scratch. Compared between two progress levels rather than against literals, so this measures the
## growth and not the constants.
func _test_the_crack_grows_with_progress_in_both_count_and_length() -> void:
	var cell := Vector2i(7, 11)
	var early: Array = CrackPainter.segments(cell, 100, CELL, BLOW)
	var late: Array = CrackPainter.segments(cell, 950, CELL, BLOW)
	_check(late.size() > early.size(),
		"more fractures at 95%% than at 10%% (%d vs %d segments)" % [late.size(), early.size()])
	_check(CrackPainter.crack_count(950) > CrackPainter.crack_count(100),
		"and the count function says so directly (%d vs %d)"
		% [CrackPainter.crack_count(950), CrackPainter.crack_count(100)])
	var centre := Vector2(cell) * float(CELL) + Vector2(CELL, CELL) * 0.5
	_check(_furthest(late, centre) > _furthest(early, centre),
		"and they reach further (%.2f vs %.2f px)" % [_furthest(late, centre), _furthest(early, centre)])


## The star must be ON its cell. A centre computed from the cell's corner rather than its middle, or one
## that forgot to scale by `cell_px`, would put every crack somewhere else entirely -- and at a 4px cell
## that is the kind of error a screenshot makes look like noise rather than like a bug.
##
## The reach bound is against the BLOW footprint, not the cell: legacy's cracks deliberately overhang the
## cell they are on (see the painter's header), so bounding them by `cell_px` would assert the port is
## wrong.
func _test_the_star_is_centred_on_its_cell_and_stays_near_it() -> void:
	var cell := Vector2i(12, 30)
	var centre := Vector2(cell) * float(CELL) + Vector2(CELL, CELL) * 0.5
	var segs: Array = CrackPainter.segments(cell, 500, CELL, BLOW)
	_check(not segs.is_empty(), "sanity: there is geometry to place (%d segments)" % segs.size())
	var from_centre: int = 0
	for s: Array in segs:
		if (s[0] as Vector2).distance_to(centre) < 0.001:
			from_centre += 1
	_check(from_centre == segs.size() / 2,
		"exactly half the segments start at the cell's centre -- the inner arm of each elbow (%d of %d)"
		% [from_centre, segs.size()])
	_check(_furthest(segs, centre) <= BLOW,
		"and nothing reaches beyond the blow's own footprint (%.2f of %.1f px)"
		% [_furthest(segs, centre), BLOW])


## No RNG, exactly as legacy -- two runs of the same seed must paint identically or a capture cannot be
## compared with a previous one, which is what `docs/QUALITY.md`'s screenshot discipline rests on. Paired
## with the opposite property: adjacent cells must NOT be identical, or the field reads as stamped.
func _test_the_pattern_is_deterministic_and_differs_between_cells() -> void:
	var a: Array = CrackPainter.segments(Vector2i(5, 9), 600, CELL, BLOW)
	var again: Array = CrackPainter.segments(Vector2i(5, 9), 600, CELL, BLOW)
	var same := true
	for i: int in a.size():
		if not (a[i][0] as Vector2).is_equal_approx(again[i][0] as Vector2) \
				or not (a[i][1] as Vector2).is_equal_approx(again[i][1] as Vector2):
			same = false
	_check_over(a.size(), same, "the same cell at the same progress produces byte-identical geometry")
	_check(not is_equal_approx(CrackPainter.base_angle(Vector2i(5, 9)), CrackPainter.base_angle(Vector2i(6, 9))),
		"a horizontal neighbour gets a different base angle")
	_check(not is_equal_approx(CrackPainter.base_angle(Vector2i(5, 9)), CrackPainter.base_angle(Vector2i(5, 10))),
		"and so does a vertical one")


## POPULATION CHECK over the whole per-mille range a cell can actually hold, rather than the three values
## the tests above happen to use. Catches an off-by-one at either end and, more usefully, any progress at
## which the count function returns something a loop cannot draw.
func _test_the_whole_visible_range_of_progress_produces_geometry() -> void:
	var empty: Array[int] = []
	var odd_counts: Array[int] = []
	for p: int in range(CrackPainter.MIN_VISIBLE, 1001):
		var segs: Array = CrackPainter.segments(Vector2i(2, 2), p, CELL, BLOW)
		if segs.is_empty():
			empty.append(p)
		if segs.size() % 2 != 0:
			odd_counts.append(p)
	_check_over(1000 - CrackPainter.MIN_VISIBLE + 1, empty.is_empty(),
		"every visible progress value produces at least one fracture (%d empty: %s)"
		% [empty.size(), empty.slice(0, 5)])
	_check_over(1000 - CrackPainter.MIN_VISIBLE + 1, odd_counts.is_empty(),
		"and always an even segment count -- every fracture is an elbow, two segments (%d odd: %s)"
		% [odd_counts.size(), odd_counts.slice(0, 5)])


func _furthest(segs: Array, centre: Vector2) -> float:
	var worst: float = 0.0
	for s: Array in segs:
		worst = maxf(worst, maxf((s[0] as Vector2).distance_to(centre), (s[1] as Vector2).distance_to(centre)))
	return worst


## `paint_frame` reads its two scales from the observation, so an observation that carries neither must
## draw nothing rather than divide by zero or stamp every crack on top of itself at the origin. Checked
## against a CONTROL that DOES carry them, without which a `paint_frame` that returned unconditionally
## would satisfy every row here.
func _test_the_frame_form_refuses_a_frame_that_carries_no_scale() -> void:
	var canvas := Node2D.new()
	var complete := Frame.new()
	complete.obs = Interface.Observation.new()
	complete.obs.cell_px = CELL
	complete.obs.mining_blow_px = int(BLOW)
	complete.obs.mining_cracks = {Vector2i(3, 3): 500}
	_check(not CrackPainter.segments(Vector2i(3, 3), 500, complete.obs.cell_px,
		float(complete.obs.mining_blow_px)).is_empty(),
		"CONTROL: a complete observation has geometry to draw")
	# Each of these is a real state: a zero-radius bite, and an observation built before the scale fields
	# existed. Neither may crash, and neither may draw.
	var no_blow := Frame.new(); no_blow.obs = Interface.Observation.new(); no_blow.obs.cell_px = CELL
	var no_cell := Frame.new(); no_cell.obs = Interface.Observation.new(); no_cell.obs.mining_blow_px = int(BLOW)
	var no_obs := Frame.new()
	var empty: int = 0
	for f: Frame in [no_blow, no_cell, no_obs, null]:
		CrackPainter.paint_frame(f, canvas)
		if CrackPainter.plan(f).is_empty():
			empty += 1
	_check(empty == 4, "every incomplete frame -- no blow, no cell size, no observation, no frame -- plans nothing (%d of 4)" % empty)
	var whole := Frame.new()
	whole.obs = Interface.Observation.new()
	whole.obs.cell_px = CELL
	whole.obs.mining_blow_px = int(BLOW)
	_check(not CrackPainter.plan(whole).is_empty() and CrackPainter.plan(whole)["cell_px"] == CELL, "CONTROL: a frame with a blow and a scale plans a draw")
	canvas.free()
