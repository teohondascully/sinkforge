extends "res://tools/check_base.gd"

## THE GRAIN PAYS, AND IT NEVER CHARGES.
##
## `Seams` gives every rock cell a bedding plane, a joint, a diagonal or nothing, and a blow that follows one
## calves the contiguous run with it. The mechanic has exactly one rule that must never bend, stated twice in
## `docs/BITS.md` §4 on purpose: **cutting ACROSS the grain costs nothing extra.** It is today's mining, one
## cell, at today's speed. The moment a wrong swing is slower than it used to be, this stops being a reward
## for reading the rock and becomes the treadmill wearing a hat — so that is the property this layer exists
## to hold, and it is checked from both ends: along the grain must take MORE than one cell, across it must
## take EXACTLY one.
##
## The other three are the ways a run could quietly become a cheat:
##   * THE CAP — a blow may never take more than `RUN_CAP` cells however long the plane runs.
##   * THE DRIVE — a run re-checks `can_mine` per cell, so a seam can never smuggle you through rock your
##     pick cannot bite. Without this a bedding plane running into the deepslate band would hand a wood pick
##     the deep third of the world.
##   * CONTIGUITY — a run stops at the first cell that is not part of it, so one blow can never reach across
##     an open chamber and take rock on the far side.
##
## Determinism gets its own check because the whole design rests on it: a seam is a pure function of
## coordinate and seed, stored nowhere and saved never, so if it were not stable the world would re-grain
## itself under the player between loads.

const SCENE: String = "res://scenes/main.tscn"

## Density is the one number here that is a JUDGEMENT rather than a rule, so the band is wide. What it is
## really guarding is the two ways the field could be useless: a world with almost no grain (the mechanic
## never fires) and a world that is all grain (it always fires, so it is just faster mining).
const MIN_DENSITY: float = 0.24
const MAX_DENSITY: float = 0.45

var _main: MainView
var _sim: FactorySim
var _frames: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== the rock has a grain ==")
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frames += 1
	if _frames < 3:
		return
	process_frame.disconnect(_on_frame)
	_sim = _main.sim
	_field()
	_swings()
	if _failures == 0:
		print("check_seam: PASS — reading the grain pays, and ignoring it costs nothing")
		quit(0)
	else:
		printerr("check_seam: FAIL — %d failure(s)" % _failures)
		quit(1)


## The field itself: stable, dense enough to matter, sparse enough to be a feature, and made of PLANES
## rather than of scattered cells.
func _field() -> void:
	var seed: int = _sim.world_seed
	var grained: int = 0
	var total: int = 0
	for y: int in range(0, FactorySim.GRID_ROWS, 3):
		for x: int in range(0, FactorySim.GRID_COLS, 3):
			total += 1
			if Seams.at(Vector2i(x, y), seed) != Seams.NONE:
				grained += 1
	var density: float = float(grained) / float(maxi(total, 1))
	print("  grain density %.1f%% of cells" % [density * 100.0])
	_check(density >= MIN_DENSITY and density <= MAX_DENSITY,
		"between %.0f%% and %.0f%% of the rock is grained" % [MIN_DENSITY * 100.0, MAX_DENSITY * 100.0])

	# THIS READ `Seams.at(probe, seed) == Seams.at(probe, seed)` — the identical call on both sides of the
	# equals, at one hand-picked cell. It could only have failed for a function that answered two adjacent
	# invocations differently, and it would have passed just as cheerfully for a `Seams.at` that returned
	# NONE for the entire world. The property its label claims is PURITY: the answer depends on (cell,
	# seed) and on nothing else — not on call order, not on what was asked before it. So take a spread of
	# cells, keep the answers, then ask again in REVERSE order with a different seed interleaved between
	# every pair, which is where a memo on "the last seed I was given" would die.
	var probes: Array[Vector2i] = []
	var first: Array[int] = []
	for i: int in range(0, 96):
		var c := Vector2i((i * 7 + 5) % FactorySim.GRID_COLS, (i * 11 + 3) % FactorySim.GRID_ROWS)
		probes.append(c)
		first.append(Seams.at(c, seed))
	var grained_probes: int = 0
	for f: int in first:
		if f != Seams.NONE:
			grained_probes += 1
	_check(grained_probes > 0 and grained_probes < first.size(),
		"the probe spread caught both grained and plain rock (%d of %d) — there is something to compare"
			% [grained_probes, first.size()])
	var stable: bool = true
	for j: int in range(probes.size() - 1, -1, -1):
		Seams.at(probes[j], seed + 1)      # another seed between every pair
		if Seams.at(probes[j], seed) != first[j]:
			stable = false
	_check(stable, "a cell's seam is the same answer re-asked out of order with another seed in between")
	var differs: int = 0
	for y: int in range(0, 64):
		if Seams.at(Vector2i(3, y), seed) != Seams.at(Vector2i(3, y), seed + 1):
			differs += 1
	_check(differs > 0, "a different seed grains the world differently (it is seeded, not hard-coded)")

	# PRECEDENCE, WHERE THE TWO PLANES CROSS. Bedding beats joint. That order is arbitrary but it must be
	# FIXED, because the renderer draws the grain and the swing calves along it and the two have to be
	# reading the same answer — and this file already DEPENDS on it in two places (`_plain_row` exists only
	# because a joint on a bedding row would report as bedding and be struck along the grain instead of
	# across it). It was stated in a comment and relied on by the fixtures, and asserted nowhere, which is
	# the shape of a rule that gets quietly inverted by a refactor while every test stays green.
	#
	# The FIXTURE guard carries the "this is really a joint" half: `_joint_column` returns a column only if
	# it answered VERTICAL on that row, so the `>= 0` below already says so and re-asserting it here would
	# be a check that cannot fail — the exact thing this commit is repairing elsewhere. One assertion, then,
	# and it is the load-bearing one. What it does NOT prove is that the joint SPANS as far as the bedding
	# row: a joint that simply stops short reads identically from outside. So this is precedence as far as
	# the field exposes it, which is further than nothing and is all that can be claimed honestly.
	var cross_row: int = _bedding_row()
	var cross_plain: int = _plain_row()
	var cross_col: int = _joint_column(cross_plain) if cross_plain >= 0 else -1
	# NON-VACUITY — the CROSSING has to exist before anything can be claimed about precedence at it.
	_check(cross_row >= 0 and cross_col >= 0,
		"there is a bedding row and a joint column to cross (row %d, joint at col %d on plain row %d)"
			% [cross_row, cross_col, cross_plain])
	if cross_row >= 0 and cross_col >= 0:
		_check(Seams.at(Vector2i(cross_col, cross_row), seed) == Seams.HORIZONTAL,
			"a column that answers VERTICAL on row %d answers BEDDING where the plane crosses it (row %d"
				% [cross_plain, cross_row]
				+ " gave %d) — bedding beats joint, the order this file's fixtures already assume"
				% Seams.at(Vector2i(cross_col, cross_row), seed))

	# PLANES, not a sprinkle. A bedding row must be bedding for its WHOLE length, because that is what makes
	# runs exist at all — a per-cell roll would give a run of three about once in six hundred cells.
	var row: int = _bedding_row()
	_check(row >= 0, "the world has at least one bedding plane in it")
	if row >= 0:
		var same: bool = true
		for x: int in range(0, FactorySim.GRID_COLS):
			if Seams.at(Vector2i(x, row), seed) != Seams.HORIZONTAL:
				same = false
				break
		_check(same, "a bedding plane runs the full width of the world (a plane, not a sprinkle)")


## The swings. Each builds its own rock so the geometry is known exactly, then drives the REAL verb.
func _swings() -> void:
	var row: int = _bedding_row()
	if row < 0:
		return

	# ALONG THE GRAIN. A wall of stone on a bedding row, struck from the side.
	_clear(row, 20, 44)
	for x: int in range(30, 42):
		_sim.set_solid(Vector2i(x, row), &"stone")
	_main._player.position = _main._cell_center(Vector2i(29, row))
	var took: int = _swing(Vector2i(30, row), row, 20, 44)
	print("  along a bedding plane, one blow took %d cells" % took)
	_check(took > 1, "striking ALONG the grain calves more than the struck cell")
	_check(took <= Seams.RUN_CAP, "a blow never takes more than RUN_CAP (%d) cells" % Seams.RUN_CAP)

	# ACROSS THE GRAIN — the rule that must never bend. A JOINT (vertical plane) struck sideways is being
	# cut across, so it must cost exactly what it always cost: one cell.
	# The joint has to be sampled on a row that is NOT itself bedding: bedding wins the precedence, so a
	# joint crossing a bedding plane reports as bedding, and striking it sideways would be along the grain.
	var plain: int = _plain_row()
	var col: int = _joint_column(plain)
	_check(plain >= 0 and col >= 0, "the world has at least one joint on an unbedded row")
	if plain >= 0 and col >= 0:
		_clear(plain, col - 6, col + 6)
		for y: int in range(plain - 1, plain + 2):
			_sim.set_solid(Vector2i(col, y), &"stone")
		_main._player.position = _main._cell_center(Vector2i(col - 1, plain))
		var across: int = _swing(Vector2i(col, plain), plain, col - 6, col + 6)
		print("  across a joint, one blow took %d cell(s)" % across)
		_check(across == 1, "striking ACROSS the grain takes exactly one cell — the grain never punishes")

	# THE DRIVE GATE. The same bedding plane, but the rock beside the struck cell is deepslate, which a
	# tier-1 starter pick cannot bite. The run must stop dead at it rather than calve straight through.
	_clear(row, 60, 80)
	_sim.set_solid(Vector2i(70, row), &"stone")
	for x: int in range(71, 76):
		_sim.set_solid(Vector2i(x, row), &"deepslate")
	var pick: int = MiningRules.best_tier(&"pick", _sim.inventory)
	_main._player.position = _main._cell_center(Vector2i(69, row))
	# Only run the assertion when the pack really is under-tier; a save/starter change should say so rather
	# than silently turn this into a check of nothing.
	if pick >= MiningRules.required_tier(&"deepslate"):
		print("  (skipped: the pack already holds a tier-%d pick, so nothing here is over-tier)" % pick)
	else:
		var gated: int = _swing(Vector2i(70, row), row, 60, 80)
		print("  along a plane running into over-tier rock, one blow took %d cell(s)" % gated)
		_check(gated == 1, "a run stops at rock the drive cannot bite — a seam never smuggles you past a gate")

	# CONTIGUITY. A gap in the plane must end the run, or one blow reaches across a chamber.
	_clear(row, 84, 104)
	_sim.set_solid(Vector2i(90, row), &"stone")
	for x: int in range(92, 98):
		_sim.set_solid(Vector2i(x, row), &"stone")     # note the hole at 91
	_main._player.position = _main._cell_center(Vector2i(89, row))
	var hopped: int = _swing(Vector2i(90, row), row, 84, 104)
	print("  along a plane with a hole in it, one blow took %d cell(s)" % hopped)
	_check(hopped == 1, "a run stops at a gap — one blow never reaches across open space")


## Carve an open pocket around a row so the body has somewhere to stand and line-of-sight is clear.
func _clear(row: int, from_x: int, to_x: int) -> void:
	for x: int in range(from_x, to_x):
		for y: int in range(row - 3, row + 4):
			_sim.set_solid(Vector2i(x, y), &"")


## Drive the real verb once and count how many solid cells the band lost.
func _swing(cell: Vector2i, row: int, from_x: int, to_x: int) -> int:
	var before: int = _solid_in(row, from_x, to_x)
	_main.try_mine(cell)
	return before - _solid_in(row, from_x, to_x)


func _solid_in(row: int, from_x: int, to_x: int) -> int:
	var n: int = 0
	for x: int in range(from_x, to_x):
		for y: int in range(row - 3, row + 4):
			if _sim.solid.has(Vector2i(x, y)):
				n += 1
	return n


## A row this world has made a bedding plane, in the band the tests build in. -1 if the seed produced none
## there, which the caller reports rather than silently passing.
func _bedding_row() -> int:
	for y: int in range(MainView.SURFACE + 6, MainView.SURFACE + 40):
		if Seams.at(Vector2i(0, y), _sim.world_seed) == Seams.HORIZONTAL:
			return y
	return -1


## A row with no bedding plane on it — where a joint can actually surface.
func _plain_row() -> int:
	for y: int in range(MainView.SURFACE + 6, MainView.SURFACE + 40):
		if Seams.at(Vector2i(0, y), _sim.world_seed) != Seams.HORIZONTAL:
			return y
	return -1


## A column this world has made a joint, sampled on a row known to carry no bedding plane.
func _joint_column(row: int) -> int:
	if row < 0:
		return -1
	for x: int in range(30, FactorySim.GRID_COLS - 30):
		if Seams.at(Vector2i(x, row), _sim.world_seed) == Seams.VERTICAL:
			return x
	return -1
