extends "res://tests/test_base.gd"

## `view/visuals/seam_painter.gd` — the grain reveal (D0308, `docs/LEGACY_GAP.md` PRE-4).
##
## THE FOUR QUESTIONS, and the first one is the one this port is most likely to get wrong:
##
##   IT DRAWS NOTHING WHEN IT SHOULD.   No ambient pass. Legacy's own header says drawing the grain
##                                      everywhere reads as graph paper, and the obvious implementation
##                                      is the wrong one, so silence is asserted rather than assumed.
##   THE RUN IS WHAT WOULD SHEAR.       Contiguous, same seam, still solid, both directions, capped.
##                                      A decoration that RESEMBLES the calve is the failure mode.
##   THE POLYLINE IS CONTINUOUS.        Cell i's far endpoint IS cell i+1's near one, exactly. This is
##                                      why the wander is two sines and not a hash, and it is invisible
##                                      in any still frame small enough to eyeball.
##   THE POPULATION EXISTS.             Every assertion above is a PASS over an empty run. `Seams.at` is
##                                      a pure function of (cell, seed) and roughly two thirds of cells
##                                      have no seam at all, so a fixture that poses a cell and hopes is
##                                      a suite that measures nothing. Seeds are SEARCHED for here.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_seam_painter.gd

const GRID_W: int = 48
const GRID_H: int = 160
const ROCK_TOP: int = 8
const CELL: int = 4
const ROCK: StringName = &"stone"

## `1 + 2 * (RUN_CAP - 1)`: the worked cell, plus `RUN_CAP - 1` outward each way. Written as the
## expression rather than as 5 so it follows `Seams.RUN_CAP` if the Wedge bit ever raises it.
const MAX_RUN: int = 1 + 2 * (Seams.RUN_CAP - 1)

## Measured 2026-09-01 over seeds [1, 20260826, 424242] of SHALLOW_CLAY, every solid terrain cell:
## 0.3011 of the rock carries a seam. Pinned as a MEASUREMENT with a band, in the same shape as the carve
## ratchets, rather than as the 0.3289 the three rates predict under a per-cell independence model that
## does not hold -- see the cross-check in the test itself.
const MEASURED_GRAINED: float = 0.3011


func _initialize() -> void:
	_test_the_population_this_suite_needs_actually_exists()
	_test_nothing_is_drawn_unless_a_cell_is_being_worked()
	_test_the_run_stops_at_air_and_at_a_different_seam()
	_test_the_run_never_exceeds_the_calve_cap()
	_test_the_seam_gate_is_posed_by_a_plane_that_outranks_the_run()
	_test_the_polyline_is_continuous_along_every_seam_kind()
	_test_the_wander_bends_rather_than_jumps()
	_test_the_parting_does_not_lie_on_the_grid()
	_test_the_grain_is_reachable_in_a_world_the_generator_actually_makes()
	_finish("seam_painter")


## A world solid in ROCK from `ROCK_TOP` down, at `world_seed`, with `dug` excavated.
func _world(world_seed: int, dug: Array[Vector2i]) -> Interface.Observation:
	var grid: TileGrid = TileGrid.new(GRID_W, GRID_H, world_seed)
	for col: int in range(GRID_W):
		for row: int in range(ROCK_TOP, GRID_H):
			grid.set_material(Vector2i(col, row), ROCK)
			grid.set_wall(Vector2i(col, row), ROCK)
	for c: Vector2i in dug:
		grid.excavate(c)
	var body: Body = Body.new(Fx.from_int(GRID_W * CELL / 2), Fx.from_int(4 * CELL))
	var iface: Interface = Interface.new(grid, body, Mining.new())
	var view := Rect2(0.0, 0.0, float(GRID_W * CELL), float(GRID_H * CELL))
	var obs: Interface.Observation = iface.observe(
		Interface.Envelope.covering(view, WorldView.WINDOW_MARGIN_CELLS))
	obs.cell_px = CELL
	return obs


## Poses `obs` as actively working `cell`. The painter reads exactly these two fields for its trigger.
func _work(obs: Interface.Observation, cell: Vector2i) -> Interface.Observation:
	obs.mining_is_charging = true
	obs.mining_charging_cell = cell
	return obs


## SEARCHES for a (seed, cell) posing `seam`, rather than asserting one exists. Returns
## `[seed, cell]` or `[]`. The search is over seeds first because `Seams.at` keys HORIZONTAL to the row
## and VERTICAL to the column: a fixed seed's rows are what they are, and hunting cells inside one seed
## can exhaust a 160-row world without ever finding a vertical.
func _find_seam(seam: int) -> Array:
	for world_seed: int in range(1, 400):
		for row: int in range(ROCK_TOP + Seams.RUN_CAP, GRID_H - Seams.RUN_CAP):
			for col: int in range(Seams.RUN_CAP, GRID_W - Seams.RUN_CAP):
				var c := Vector2i(col, row)
				if Seams.at(c, world_seed) == seam:
					return [world_seed, c]
	return []


## THE CONTROL, and it runs FIRST. Everything below reasons about a run of grained cells; if this world
## has no grain, `aim_run` returns an empty array and every later assertion is a pass over nothing.
func _test_the_population_this_suite_needs_actually_exists() -> void:
	for seam: int in [Seams.HORIZONTAL, Seams.VERTICAL, Seams.DIAGONAL]:
		var found: Array = _find_seam(seam)
		_check(not found.is_empty(),
			"positive control: a (seed, cell) exists posing seam kind %d -- without one, every assertion "
			% seam + "in this file passes over an empty run")
		if found.is_empty():
			continue
		var obs: Interface.Observation = _work(_world(int(found[0]), []), found[1])
		var run: Array[Vector2i] = SeamPainter.aim_run(obs)
		print("  [OBSERVED] seam %d at seed %d cell %s -> run of %d cell(s)"
			% [seam, int(found[0]), found[1], run.size()])
		_check(run.size() >= 1,
			"...and the painter's own walk returns a NON-EMPTY run for it (%d cells)" % run.size())


## NO AMBIENT PASS. Three ways the trigger can be absent, all silent. This is the assertion that fails if
## someone later "improves" the painter by drawing the grain everywhere -- which is the obvious
## implementation and the one legacy explicitly rejected as graph paper.
func _test_nothing_is_drawn_unless_a_cell_is_being_worked() -> void:
	var found: Array = _find_seam(Seams.HORIZONTAL)
	if found.is_empty():
		return  ## the control above already failed; do not report a second consequence of one cause
	var seed_value: int = int(found[0])
	var cell: Vector2i = found[1]

	var idle: Interface.Observation = _world(seed_value, [])
	idle.mining_is_charging = false
	idle.mining_charging_cell = cell
	_check(SeamPainter.aim_run(idle).is_empty(),
		"a cell that is merely POINTED AT draws nothing -- the grain answers the blow, not the cursor")

	var air: Interface.Observation = _work(_world(seed_value, [cell]), cell)
	_check(SeamPainter.aim_run(air).is_empty(),
		"a worked cell that has already been dug out draws nothing")

	# A CELL WITH NO GRAIN AT ALL, which is roughly two thirds of the world and was the case this suite
	# originally could not see. Found by mutation: deleting the `seam == NONE` guard left every assertion
	# green, because no fixture here ever worked an ungrained cell. It is not a cosmetic omission --
	# `Seams.terrain_axis(NONE)` is `Vector2i.ZERO`, so the walk would step by nothing and append the SAME
	# cell `RUN_CAP - 1` times in each direction.
	var bare: Array = _find_seam(Seams.NONE)
	_check(not bare.is_empty(), "positive control: an ungrained cell is reachable to pose")
	if not bare.is_empty():
		var none_run: Array[Vector2i] = SeamPainter.aim_run(
			_work(_world(int(bare[0]), []), bare[1]))
		_check(none_run.is_empty(),
			"a worked cell with NO grain draws nothing (%d cells) -- there is no run to shear, and a "
			% none_run.size() + "zero axis would otherwise light one cell five times over")

	# ...and a grained cell in the same world DOES draw, or "always empty" passes all four above.
	_check(not SeamPainter.aim_run(_work(_world(seed_value, []), cell)).is_empty(),
		"...and the SAME world, worked at a grained cell, is not empty -- the silences above are a "
		+ "trigger, not a painter that never draws")


## THE RUN IS THE CALVE, NOT A DECORATION THAT RESEMBLES IT. Both gates, in both directions.
func _test_the_run_stops_at_air_and_at_a_different_seam() -> void:
	var found: Array = _find_seam(Seams.HORIZONTAL)
	if found.is_empty():
		return
	var seed_value: int = int(found[0])
	var cell: Vector2i = found[1]
	var axis: Vector2i = Seams.terrain_axis(Seams.HORIZONTAL)

	var whole: Array[Vector2i] = SeamPainter.aim_run(_work(_world(seed_value, []), cell))
	# Dig the neighbour one step along +axis. Everything beyond it must go with it.
	var cut: Array[Vector2i] = SeamPainter.aim_run(
		_work(_world(seed_value, [cell + axis]), cell))
	print("  [OBSERVED] run %d cells whole, %d with the +1 neighbour dug out"
		% [whole.size(), cut.size()])
	for c: Vector2i in cut:
		# Integer dot by hand: `Vector2i` has no `dot()` in Godot 4, and `Vector2(c - cell).dot(...)`
		# would put a float comparison in the middle of an exact statement about cells.
		var d: Vector2i = c - cell
		_check(c == cell or d.x * axis.x + d.y * axis.y < 0,
			"nothing past the dug neighbour survives in the run (%s is on the far side)" % c)
	_check(cut.size() <= whole.size(),
		"cutting the run cannot make it longer (%d -> %d)" % [whole.size(), cut.size()])


## THE SEAM GATE, AND THE POPULATION THAT CANNOT POSE IT.
##
## Found by mutation-testing this file rather than by reading it: deleting
## `Seams.at(c, world_seed) != seam` from the walk left every assertion GREEN. The reason is structural
## and worth stating, because it is a trap for the next person who adds a case here.
##
## A HORIZONTAL run walks `(1, 0)`, so every cell in it shares the worked cell's ROW — and `Seams.at`
## keys HORIZONTAL to the row. **Every cell along a horizontal run is horizontal by construction**, so
## the seam gate is vacuous over that population and a suite drawing its fixture there is asserting
## nothing. The same holds for VERTICAL along a column and DIAGONAL along its anti-diagonal.
##
## The gate can only bite where a HIGHER-PRECEDENCE plane crosses the run: `Seams.at` answers bedding,
## then joint, then diagonal, so a cell partway down a VERTICAL run whose row happens to be a bedding
## plane answers HORIZONTAL and must break the run. That is the case searched for here, and if the search
## comes up empty this test says so rather than passing.
func _test_the_seam_gate_is_posed_by_a_plane_that_outranks_the_run() -> void:
	var posed: Array = _find_outranked_run()
	_check(not posed.is_empty(),
		"positive control: a run exists that a higher-precedence plane actually truncates -- a HORIZONTAL "
		+ "run cannot pose this gate, because nothing outranks bedding and every cell in the run shares "
		+ "the worked cell's row")
	if posed.is_empty():
		return
	var seed_value: int = int(posed[0])
	var cell: Vector2i = posed[1]
	var crossing: Vector2i = posed[2]
	var seam: int = Seams.at(cell, seed_value)
	var run: Array[Vector2i] = SeamPainter.aim_run(_work(_world(seed_value, []), cell))
	print("  [OBSERVED] seed %d: %s carries seam %d, crossed at %s by seam %d -> run of %d"
		% [seed_value, cell, seam, crossing, Seams.at(crossing, seed_value), run.size()])
	_check(not run.has(crossing),
		"the run STOPS at %s, where a higher-precedence plane crosses it -- a run that walked through "
		% crossing + "would light cells the calve will not take")
	for c: Vector2i in run:
		_check(Seams.at(c, seed_value) == seam,
			"every cell in the run shares the worked cell's seam (%s carries %d, not %d)"
			% [c, Seams.at(c, seed_value), seam])


## SEARCHES for `[seed, cell, crossing]` where `cell` carries a seam and the very next cell along its own
## axis carries a DIFFERENT one. Returns `[]` if none is reachable in the search space.
func _find_outranked_run() -> Array:
	for world_seed: int in range(1, 400):
		for seam: int in [Seams.VERTICAL, Seams.DIAGONAL]:
			var axis: Vector2i = Seams.terrain_axis(seam)
			for row: int in range(ROCK_TOP + Seams.RUN_CAP, GRID_H - Seams.RUN_CAP):
				for col: int in range(Seams.RUN_CAP, GRID_W - Seams.RUN_CAP):
					var c := Vector2i(col, row)
					if Seams.at(c, world_seed) != seam:
						continue
					var n: Vector2i = c + axis
					if Seams.at(n, world_seed) != seam:
						return [world_seed, c, n]
	return []


func _test_the_run_never_exceeds_the_calve_cap() -> void:
	var checked: int = 0
	for seam: int in [Seams.HORIZONTAL, Seams.VERTICAL, Seams.DIAGONAL]:
		var found: Array = _find_seam(seam)
		if found.is_empty():
			continue
		var run: Array[Vector2i] = SeamPainter.aim_run(
			_work(_world(int(found[0]), []), found[1]))
		checked += 1
		_check(run.size() <= MAX_RUN,
			"seam kind %d lights at most %d cells (%d) -- `Seams.RUN_CAP` is what one blow takes, and a "
			% [seam, MAX_RUN, run.size()] + "reveal longer than the calve is a promise the sim will not keep")
		var unique: Dictionary = {}
		for c: Vector2i in run:
			unique[c] = true
		_check(unique.size() == run.size(),
			"...and it lights each cell once (%d entries, %d distinct)" % [run.size(), unique.size()])
	_check(checked == 3, "all three seam kinds were reachable to check (%d of 3)" % checked)


## THE CONTINUITY THAT IS THE WHOLE REASON THE WANDER IS TWO SINES. Cell i's far endpoint must BE cell
## i+1's near endpoint -- not close to it. A hash-based wander would step at every cell and this would
## fail by roughly a third of a cell, which is invisible at any zoom that fits a run on screen.
func _test_the_polyline_is_continuous_along_every_seam_kind() -> void:
	var s: float = float(CELL)
	for seam: int in [Seams.HORIZONTAL, Seams.VERTICAL, Seams.DIAGONAL]:
		var axis: Vector2i = Seams.terrain_axis(seam)
		var base := Vector2i(20, 40)
		var worst: float = 0.0
		for step: int in range(0, 6):
			var c: Vector2i = base + axis * step
			var n: Vector2i = base + axis * (step + 1)
			var here: Dictionary = SeamPainter.stroke_geometry(c, seam, s)
			var next: Dictionary = SeamPainter.stroke_geometry(n, seam, s)
			# HORIZONTAL and DIAGONAL both run +x, so `b` meets the next cell's `a`. VERTICAL runs +y and
			# does the same. The joint is the same joint in all three; only the axis differs.
			worst = maxf(worst, (Vector2(here["b"]) - Vector2(next["a"])).length())
		print("  [OBSERVED] seam kind %d: worst endpoint gap %.6f px over 6 joints" % [seam, worst])
		_check(worst < 0.0001,
			"seam kind %d joins exactly at every cell boundary (worst gap %.6f px). A hash-based wander "
			% [seam, worst] + "steps here by ~%.2f px and looks fine in a still frame." % (0.3 * s))


## The wander has to BEND. A constant is continuous too, and a continuity test alone would pass on one --
## so this asserts the thing actually moves, and moves smoothly.
func _test_the_wander_bends_rather_than_jumps() -> void:
	var lo: float = 1e9
	var hi: float = -1e9
	var worst_step: float = 0.0
	var prev: float = SeamPainter.wander(0, 0.0)
	for i: int in range(1, 200):
		var v: float = SeamPainter.wander(i, 0.0)
		lo = minf(lo, v)
		hi = maxf(hi, v)
		worst_step = maxf(worst_step, absf(v - prev))
		prev = v
	print("  [OBSERVED] wander over 200 cells: range %.3f .. %.3f, largest single step %.3f"
		% [lo, hi, worst_step])
	_check(hi - lo > 1.0,
		"the wander actually travels (%.3f over 200 cells) -- a constant would pass the continuity test "
		% (hi - lo) + "above and put the grid straight back on screen")
	_check(hi <= 1.0001 and lo >= -1.0001,
		"...and stays inside +/-1 (%.3f .. %.3f), so `WANDER` means what it says in cells" % [lo, hi])
	_check(worst_step < (hi - lo) * 0.5,
		"...and it BENDS rather than jumps: the largest single-cell step is %.3f against a %.3f span. A "
		% [worst_step, hi - lo] + "hash would step by most of the range at every cell.")


## THE STROKE MUST NOT LIE ON THE CELL BOUNDARY, which is the whole reason the wander exists: a parting
## drawn straight down a grid line puts the grid back on screen for exactly as long as the cursor sits
## there, and that is the same defect as the ambient pass, arriving through the other door.
##
## THE FLOOR IS ZERO, DERIVED RATHER THAN CHOSEN. Set `WANDER` to 0.0 and this deviation is EXACTLY 0.0
## at every cell -- so any positive floor separates "the wander is there" from "the wander was deleted",
## and that is the regression worth a gate.
##
## WHAT THIS DELIBERATELY DOES NOT PIN IS THE VALUE. Mutation-testing this suite found that halving
## `WANDER` from 0.30 to 0.15 goes uncaught, and that is correct: how far a parting strays is a LOOK
## call, and a suite that fails when the director nudges it is a suite that has appointed itself the
## art director. Deletion is a regression; 0.15 is a preference. Only the first is gated.
func _test_the_parting_does_not_lie_on_the_grid() -> void:
	var s: float = float(CELL)
	for seam: int in [Seams.HORIZONTAL, Seams.VERTICAL]:
		var worst: float = 0.0
		for i: int in range(0, 40):
			var c := Vector2i(20 + i, 40 + i)
			var g: Dictionary = SeamPainter.stroke_geometry(c, seam, s)
			var a: Vector2 = g["a"]
			# The nominal grid line this stroke is a parting ALONG: its own cell edge.
			var on_grid: float = (float(c.y) * s) if seam == Seams.HORIZONTAL else (float(c.x) * s)
			var got: float = a.y if seam == Seams.HORIZONTAL else a.x
			worst = maxf(worst, absf(got - on_grid))
		print("  [OBSERVED] seam kind %d: furthest the parting strays from its cell edge = %.3f px "
			% [seam, worst] + "(%.3f cells)" % (worst / s))
		_check(worst > 0.0,
			"seam kind %d strays off its own cell edge (%.3f px). With `WANDER` at 0.0 this is exactly "
			% [seam, worst] + "0.000 -- a ruled line on a grid boundary, which is the graph-paper defect.")


## THE ASSERTION THE CAPTURE NEEDED AND DID NOT HAVE (D0309).
##
## Everything above poses a fixture: a slab of one material at a seed searched for until it carried the
## seam the test wanted. That proves the painter's LOGIC and says nothing about whether a player will
## ever see it — and the difference is not academic. `SeamPainter` shipped correct, mounted on the real
## coordinator, with every suite green, and a four-moment capture diffed against the parent commit at
## **exactly zero pixels**. Nothing here could have caught that, because a searched-for seed is by
## construction a world with the grain in it.
##
## What the capture was actually showing is that at its own tick the agent works cell (24, 95), and
## `Seams.at` answers NONE there. So this measures the RATE in a real generated world: not "can the
## grain exist" but "how much of the rock a player digs through carries one".
##
## THE BAND IS WIDE ON PURPOSE. `Seams` combines three planes at 0.18 / 0.12 / 0.07, and the union of
## three independent events at those rates is `1 - 0.82*0.88*0.93 = 0.329`. The assertion is that the
## measured rate lands near the rate the CONSTANTS predict — which is a check on the wiring, not a pin on
## taste, and it moves correctly if the director retunes the rates.
func _test_the_grain_is_reachable_in_a_world_the_generator_actually_makes() -> void:
	var predicted: float = 1.0 - (
		(1.0 - float(Seams.RATE_HORIZONTAL) / float(Seams.RATE_DENOMINATOR))
		* (1.0 - float(Seams.RATE_VERTICAL) / float(Seams.RATE_DENOMINATOR))
		* (1.0 - float(Seams.RATE_DIAGONAL) / float(Seams.RATE_DENOMINATOR)))
	var grained: int = 0
	var solid: int = 0
	for world_seed: int in [1, 20260826, 424242]:
		var grid: TileGrid = ShaftGenerator.generate(StrataData.SHALLOW_CLAY, world_seed)
		for cell: Vector2i in grid.occupied_terrain_cells():
			solid += 1
			if Seams.at(cell, world_seed) != Seams.NONE:
				grained += 1
	_check(solid > 0, "positive control: the generated worlds contain solid rock at all (%d cells)" % solid)
	if solid == 0:
		return
	var rate: float = float(grained) / float(solid)
	print("  [OBSERVED] %d of %d solid cells carry a seam (%.4f), constants predict %.4f"
		% [grained, solid, rate, predicted])
	_check(absf(rate - MEASURED_GRAINED) < 0.05,
		"a real generated world grains %.4f of its solid rock, near its measured %.4f (+/-0.05). If this "
		% [rate, MEASURED_GRAINED] + "falls to zero the mechanic is invisible in play and no fixture in "
		+ "this file would notice, because every fixture here SEARCHES for a seed that has the grain.")
	# THE CONSTANTS AS A LOOSE CROSS-CHECK, and the gap between the two numbers is not an error.
	# `1 - 0.82*0.88*0.93 = 0.3289` treats the three planes as independent PER-CELL events. They are not:
	# `Seams.at` keys bedding to the ROW and joints to the COLUMN, so a whole row or column is in or out
	# together, and over 48 columns the vertical term alone carries real sampling error. The measured
	# 0.3011 is the truth and 0.3289 is a model of it; this bound is wide enough to say "the rates are
	# wired to the outcome" without pretending the model is exact.
	_check(absf(rate - predicted) < 0.10,
		"...and it tracks the %.4f its own three rates predict, within a bound wide enough for the fact "
		% predicted + "that the planes are row- and column-quantised rather than per-cell (measured "
		+ "%.4f). A rate change that moved nothing here would mean the constants are decorative." % rate)
	# ...and the other direction, which is the one the capture actually tripped over: most rock is BARE.
	_check(rate < 0.5,
		"...and most solid rock carries NO grain (%.4f grained) -- which is why a capture aimed at an "
		% rate + "arbitrary tick shows nothing, and why `tools/capture_moments.sh` pins the `grain` "
		+ "moment to a tick whose worked cell is known to be grained rather than trusting the odds")
