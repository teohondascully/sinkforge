extends "res://tests/test_base.gd"

## D0192 (Slice 1, step 1). The reveal scene spawned the body FLUSH against the world's own left edge,
## so a single leftward keypress carried it out of the grid and `Invariants.report_bounds` fired "left
## the world". Found in the director's own Slice 0 `--play` session, reproduced offline from the recorded
## log (`tests/body/recordings/reveal_play_2026-08-30T04-19-05.log`, ticks 91 and 165).
##
## Mechanism: `find_spawn` returned `col - APPROACH_OFFSET_COLS`, and a pocket at column 6 gives spawn
## column 0 -- body left edge exactly on x=0. `carve_entry_shaft` then excavated columns 0..3, removing
## the very rock that would have stopped the walk, so nothing but the world-edge clamp was left to stop
## it. The clamp did stop it, correctly, 0.3125px out (one acceleration step) -- and reported it.
##
## NOT a tail case: `find_spawn`'s `col < APPROACH_OFFSET_COLS: continue` guard skips columns 0..5, so
## every shallow pocket in that range piles onto column 6 and every one of those spawns flush. Over 400
## seeds this is the MODE of the distribution -- `reveal_test_dense` 213/400 (53.2%),
## `reveal_test_sparse` 56/400 (14.0%).
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_reveal_spawn_bounds.gd

const CELL: int = Heightfield.TERRAIN_CELL_PX
const SEEDS: int = 64  ## the 400-seed figures above come from a one-off sweep; this is the standing guard
const BASE_SEED: int = 20260826  ## the director's own seed -- seed 0 of the sweep, and a failing one
const SITES: Array[StringName] = [&"reveal_test_dense", &"reveal_test_sparse"]
## Long enough for the body to accelerate to full run speed and cross any plausible margin: RUN_SPEED is
## 150px/s == 2.5px/tick, so 120 ticks covers 300px against a 192px-wide world.
const WALK_TICKS: int = 120
const SHAFT_COLS: int = 4  ## `carve_entry_shaft`'s own `range(0, 4)`


func _initialize() -> void:
	_test_the_spawn_is_never_flush_against_the_world_edge()
	_test_the_spawn_never_swallows_its_own_target_pocket()
	_test_walking_left_from_the_real_spawn_never_leaves_the_world()
	_test_the_control_walking_left_from_column_zero_DOES_leave_the_world()
	_test_the_control_builds_the_same_body_the_real_setup_does()
	_finish("reveal_spawn_bounds")


## Reproduces the PRE-FIX setup at an arbitrary column: carve the entry shaft there, put the body there.
## Deliberately a copy of `RevealSessionSetup.build`'s own body construction rather than a call to it,
## because `build` no longer has a way to produce a flush spawn -- that is the whole point of the fix. It
## cannot drift away from `build` unnoticed: `_test_the_control_builds_the_same_body_the_real_setup_does`
## below pins the two together.
func _session_at_column(site: StringName, seed_value: int, spawn_col: int) -> Dictionary:
	var grid: TileGrid = ShaftGenerator.generate(StrataData.get_site(site), seed_value)
	RevealSessionSetup.carve_entry_shaft(grid, spawn_col)
	var spawn_row: int = Body.HEIGHT_PX / CELL / 2
	var body: Body = Body.new(
		spawn_col * CELL * Fx.SCALE + Body.WIDTH_PX / 2 * Fx.SCALE, Fx.from_int(spawn_row * CELL))
	return {"grid": grid, "body": body}


## Holds move_dir = -1 for `WALK_TICKS` and returns how many ticks reported a bounds violation, plus the
## furthest-left the body's own box ever reached. Counts `bounds_violation_this_tick`, which is NOT
## rate-limited, rather than the push_error the ledger's D0052 latch suppresses after the first tick of an
## excursion -- a test counting stderr lines would read one 12-tick excursion as a single event.
##
## `min_left` is sampled AFTER `tick()` returns, so it can never be negative: `_enforce_grid_bounds` runs
## inside the same tick and has already clamped the body back to x=0 by the time this reads it. That is not
## a limitation to work around, it is the discriminating quantity -- `min_left == 0` means the WORLD-EDGE
## CLAMP is what stopped the body, and `min_left > 0` means TERRAIN did. A sign check here would be a guard
## that cannot fail; this distinction is the actual subject. (Caught by the control below, which passed its
## violation-count assertion while failing an earlier `min_left < 0` one.)
func _walk_left(body: Body, grid: TileGrid) -> Dictionary:
	var input: InputFrame = InputFrame.new()
	input.move_dir = -1
	var violations: int = 0
	var min_left: int = 1 << 60
	for _i: int in WALK_TICKS:
		body.tick(input, grid)
		if body.bounds_violation_this_tick:
			violations += 1
		min_left = mini(min_left, body._left_x())
	return {"violations": violations, "min_left": min_left}


func _test_the_spawn_is_never_flush_against_the_world_edge() -> void:
	var worst: int = 1 << 30
	var worst_at: String = ""
	for site: StringName in SITES:
		for i: int in SEEDS:
			var seed_value: int = BASE_SEED + i
			var grid: TileGrid = ShaftGenerator.generate(StrataData.get_site(site), seed_value)
			var spawn_col: int = RevealSessionSetup.find_spawn(grid)["spawn_col"]
			if spawn_col < worst:
				worst = spawn_col
				worst_at = "%s seed=%d" % [site, seed_value]
	print("  [OBSERVED] minimum spawn_col over %d seeds x %d sites: %d (%s)" % [SEEDS, SITES.size(), worst, worst_at])
	# Asserted against the DERIVED requirement (at least one solid cell between the body's left edge and
	# x=0), not against `RevealSessionSetup.MIN_SPAWN_COL` -- `spawn_col >= MIN_SPAWN_COL` is true by
	# construction for any value of that constant, so it passes on the very mutant it exists to catch. It
	# did, when this was first written; the literal is the fix (D0112's self-referential-assertion class).
	_check(worst >= 1,
		"no (site, seed) spawns the body flush against the world's left edge -- at least one solid cell stands between them (worst spawn_col %d at %s)"
		% [worst, worst_at])


## The other side of the same clamp: pushing the spawn right must never push it far enough right to
## excavate the pocket it exists to approach. `carve_entry_shaft` opens `[spawn_col, spawn_col+SHAFT_COLS)`,
## so the target must sit at or beyond `spawn_col + SHAFT_COLS`. Without this, raising `MIN_SPAWN_COL`
## later would silently pre-reveal the target and quietly invalidate every reveal measurement taken after.
func _test_the_spawn_never_swallows_its_own_target_pocket() -> void:
	var worst_gap: int = 1 << 30
	var worst_at: String = ""
	var checked: int = 0
	for site: StringName in SITES:
		for i: int in SEEDS:
			var seed_value: int = BASE_SEED + i
			var grid: TileGrid = ShaftGenerator.generate(StrataData.get_site(site), seed_value)
			var spawn: Dictionary = RevealSessionSetup.find_spawn(grid)
			if int(spawn["target_glimmer_col"]) < 0:
				continue  # no shallow pocket this seed -- the width/2 fallback, nothing to swallow
			checked += 1
			var gap: int = int(spawn["target_glimmer_col"]) - (int(spawn["spawn_col"]) + SHAFT_COLS)
			if gap < worst_gap:
				worst_gap = gap
				worst_at = "%s seed=%d (spawn %d, target %d)" % [site, seed_value, spawn["spawn_col"], spawn["target_glimmer_col"]]
	print("  [OBSERVED] tightest target-outside-shaft gap over %d seeds with a pocket: %d cols (%s)"
		% [checked, worst_gap, worst_at])
	_check(worst_gap >= 0,
		"the carved entry shaft never reaches the target pocket, so the target is never pre-revealed at spawn (tightest %d at %s)"
		% [worst_gap, worst_at])


func _test_walking_left_from_the_real_spawn_never_leaves_the_world() -> void:
	var total_violations: int = 0
	var offender: String = ""
	var worst_left: int = 1 << 60
	var worst_at: String = ""
	for site: StringName in SITES:
		for i: int in SEEDS:
			var seed_value: int = BASE_SEED + i
			var session: Dictionary = RevealSessionSetup.build(site, seed_value)
			var walked: Dictionary = _walk_left(session["body"], session["grid"])
			total_violations += int(walked["violations"])
			if int(walked["min_left"]) < worst_left:
				worst_left = int(walked["min_left"])
				worst_at = "%s seed=%d" % [site, seed_value]
			if int(walked["violations"]) > 0 and offender == "":
				offender = ("%s seed=%d (%d ticks, min_left %.4f px)"
					% [site, seed_value, walked["violations"], float(walked["min_left"]) / float(Fx.SCALE)])
	print("  [OBSERVED] furthest-left any real spawn reached over %d seeds x %d sites: %.4f px (%s)"
		% [SEEDS, SITES.size(), float(worst_left) / float(Fx.SCALE), worst_at])
	_check(total_violations == 0,
		("holding LEFT for %d ticks from the real spawn never leaves the world, on any of %d seeds x %d " +
		"sites (%d violating ticks%s)")
		% [WALK_TICKS, SEEDS, SITES.size(), total_violations, "" if offender == "" else ", first " + offender])
	# The mechanism, not just the outcome: a body stopped by terrain never reaches x=0 at all, so its own
	# furthest-left is strictly positive. A body stopped by the world-edge clamp sits at exactly 0. This is
	# what distinguishes "the fix works" from "the clamp is quietly doing the work and not reporting it".
	_check(worst_left > 0,
		"every real spawn is stopped by TERRAIN, strictly inside the world, never by the world-edge clamp (furthest-left %.4f px at %s; 0.0 would mean the clamp)"
		% [float(worst_left) / float(Fx.SCALE), worst_at])


## The control, and the reason the assertion above is a measurement rather than a tautology: the SAME walk
## from the SAME grid at the pre-fix spawn column must still leave the world. Without this, a walk that
## never moved -- a broken `_walk_left`, an InputFrame field renamed out from under it, a body wedged in
## rock -- would report zero violations and read as a pass.
func _test_the_control_walking_left_from_column_zero_DOES_leave_the_world() -> void:
	var session: Dictionary = _session_at_column(&"reveal_test_dense", BASE_SEED, 0)
	var walked: Dictionary = _walk_left(session["body"], session["grid"])
	print("  [OBSERVED] control (spawn_col=0): %d violating ticks, min_left %.4f px"
		% [walked["violations"], float(walked["min_left"]) / float(Fx.SCALE)])
	_check(int(walked["violations"]) > 0,
		"CONTROL: the pre-fix flush spawn still reproduces the director's own bounds violation (%d ticks) -- if this "
		% walked["violations"] + "ever reads 0, the test above is passing because it measures nothing")
	_check(int(walked["min_left"]) == 0,
		"CONTROL: the pre-fix spawn is held at exactly x=0 by the world-edge CLAMP, not by terrain (min_left %.4f px) -- the mirror of the real spawn's strictly-positive value"
		% (float(walked["min_left"]) / float(Fx.SCALE)))


## Pins the hand-built control to the real setup, so "the control reproduces the old path" stays true as
## `RevealSessionSetup.build` changes. Runs both at the column `find_spawn` actually chooses, where the two
## must agree exactly; a drift in spawn row, body width or Fx scaling would show up here and nowhere else.
func _test_the_control_builds_the_same_body_the_real_setup_does() -> void:
	var real: Dictionary = RevealSessionSetup.build(&"reveal_test_dense", BASE_SEED)
	var grid: TileGrid = ShaftGenerator.generate(StrataData.get_site(&"reveal_test_dense"), BASE_SEED)
	var spawn_col: int = RevealSessionSetup.find_spawn(grid)["spawn_col"]
	var mine: Dictionary = _session_at_column(&"reveal_test_dense", BASE_SEED, spawn_col)
	var a: Body = real["body"]
	var b: Body = mine["body"]
	_check(a.pos_x == b.pos_x and a.pos_y == b.pos_y,
		"the control helper spawns the body exactly where RevealSessionSetup.build does at the same column (%d,%d vs %d,%d)"
		% [a.pos_x, a.pos_y, b.pos_x, b.pos_y])