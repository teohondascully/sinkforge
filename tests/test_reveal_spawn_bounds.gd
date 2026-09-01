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
## D0199. One jump arc is `JUMP_VELOCITY/GRAVITY` = 365/900 s = 25 ticks up and as many back down; 90 gives
## a full arc plus the initial fall onto the shaft floor plus a second attempt, so the run covers a re-jump
## rather than a single launch.
const JUMP_TICKS: int = 90



## D0267. THE SAME 128 (site, seed) WORLDS WERE GENERATED THREE TIMES -- once per assertion pass -- and
## `ShaftGenerator.generate` is ~858 ms for a 48x1024 shaft (~414 ms of it five-octave noise). 384
## generations is ~329 s, which measured as 347 s of a 351 s full sweep: this one suite WAS the sweep.
##
## Now each world is built once and handed out as a `clone()`. Cloning is a shallow duplicate of three
## dictionaries of immutable values, so every caller still gets a grid sharing no state with any other --
## which is what keeps this away from the aliasing question parked as `docs/NEEDS_DIRECTOR.md` P007. P007
## asks whether two passes may SHARE one carved grid; this shares nothing, it copies.
##
## The cache is keyed on (site, seed) and holds PRISTINE, uncarved worlds. `build_on` carves, so handing
## out the cached instance itself would let the first caller's entry shaft appear in every later pass --
## the exact defect this suite exists to measure, injected by its own optimisation. `_pristine` therefore
## never returns the stored grid, only a copy of it, and `_test_the_cache_hands_out_independent_worlds`
## below asserts that with a mutation rather than trusting the comment.
var _world_cache: Dictionary = {}


func _pristine(site: StringName, seed_value: int) -> TileGrid:
	var key: String = "%s|%d" % [site, seed_value]
	if not _world_cache.has(key):
		_world_cache[key] = ShaftGenerator.generate(StrataData.get_site(site), seed_value)
	return (_world_cache[key] as TileGrid).clone()


## The guard for the cache, and the reason it is safe. Carves one handed-out world, then asks for the same
## (site, seed) again and asserts the second copy is untouched -- by SIGNATURE, which is the cheapest
## complete statement of a grid's contents this project has. A cache that returned the stored instance
## would fail here; one that returned a copy of an already-carved grid would too.
func _test_the_cache_hands_out_independent_worlds() -> void:
	var first: TileGrid = _pristine(SITES[0], BASE_SEED)
	var untouched: String = first.state_signature()
	RevealSessionSetup.carve_entry_shaft(first, 1)
	_check(first.state_signature() != untouched,
		"positive control: carving an entry shaft actually changes a grid's signature -- without this, "
		+ "the independence check below passes on a signature that never moves for any reason")
	var second: TileGrid = _pristine(SITES[0], BASE_SEED)
	_check(second.state_signature() == untouched,
		"the cache hands out INDEPENDENT worlds: carving one leaves the next copy of the same (site, seed) "
		+ "pristine (%s vs %s)" % [second.state_signature(), untouched])
	_check(second.state_signature() == second.recomputed_signature(),
		"and a clone's running signature agrees with a from-scratch rebuild of itself")


func _initialize() -> void:
	_test_the_cache_hands_out_independent_worlds()
	_test_the_spawn_clears_the_world_edge_and_never_swallows_its_target()
	_test_walking_left_from_the_real_spawn_never_leaves_the_world()
	_test_the_control_walking_left_from_column_zero_DOES_leave_the_world()
	_test_jumping_from_the_real_spawn_never_leaves_the_world_through_the_ceiling()
	_test_the_control_jumping_under_an_open_ceiling_DOES_leave_the_world()
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
	var body: Body = Body.new(spawn_col * CELL * Fx.SCALE + Body.WIDTH_PX / 2 * Fx.SCALE,
		Fx.from_int(RevealSessionSetup.spawn_row_for_ceiling() * CELL))
	return {"grid": grid, "body": body}


## D0199's control: the setup EXACTLY as it stood before the ceiling fix -- entry shaft carved from row 0,
## body centred at `HEIGHT_PX/CELL/2` so its top edge lands on y=0. Both literals are written out here
## rather than derived from `RevealSessionSetup`, on purpose: the point of a control is to hold the OLD
## shape fixed while the real one moves, and one that re-derived itself from the fixed code would follow
## the fix and stop reproducing anything (D0112's self-referential-assertion class, the same trap the
## `spawn_col >= MIN_SPAWN_COL` assertion above fell into and names).
func _prefix_ceiling_session(site: StringName, seed_value: int) -> Dictionary:
	var grid: TileGrid = ShaftGenerator.generate(StrataData.get_site(site), seed_value)
	var spawn_col: int = RevealSessionSetup.find_spawn(grid)["spawn_col"]
	# THE SKY BAND IS FILLED BACK IN, and that is what makes this a control again. This fixture poses the
	# world as it was BEFORE the two fixes it exists to measure — D0199's rock ceiling and P017's sky
	# (D0292) — and P017 removed the second one from underneath it: with twenty metres of air above the
	# rock the body simply falls, never jumps, and the control read 0 violations, which is exactly the
	# reading it is written to treat as "the test above measures nothing". Removing the SUBJECT means
	# putting the rock back, not looking somewhere else.
	for col: int in grid.width:
		for row: int in ShaftGenerator.SKY_ROWS:
			grid.set_material(Vector2i(col, row), &"clay")
			grid.set_wall(Vector2i(col, row), &"clay")
	var rows: int = Body.HEIGHT_PX / CELL + 2
	for dc: int in SHAFT_COLS:
		for row: int in rows:  # from row 0 -- the pre-fix carve, which opened the world's own ceiling
			grid.excavate(Vector2i(spawn_col + dc, row))
	var body: Body = Body.new(spawn_col * CELL * Fx.SCALE + Body.WIDTH_PX / 2 * Fx.SCALE,
		Fx.from_int((Body.HEIGHT_PX / CELL / 2) * CELL))
	return {"grid": grid, "body": body}


## Holds JUMP for `JUMP_TICKS` and returns the violating-tick count plus the highest the body's own top edge
## ever reached. `jump_pressed` is asserted on EVERY tick rather than pulsed: this is not a realistic input,
## it is the maximum upward pressure the control scheme can produce, which is what a ceiling guard has to
## survive. Re-jumps off the floor as often as it can, so one run covers repeated attempts, not one arc.
##
## `min_top` carries the same discriminating role `_walk_left`'s `min_left` does, and for the same reason:
## it is sampled after `_enforce_grid_bounds` has already clamped, so it can never be negative. `== 0` means
## the WORLD-EDGE CLAMP stopped the head; `> 0` means ROCK did.
func _hold_jump(body: Body, grid: TileGrid) -> Dictionary:
	var input: InputFrame = InputFrame.new()
	input.jump_pressed = true
	input.jump_held = true
	var violations: int = 0
	var min_top: int = 1 << 60
	for _i: int in JUMP_TICKS:
		body.tick(input, grid)
		if body.bounds_violation_this_tick:
			violations += 1
		min_top = mini(min_top, body._top_y())
	return {"violations": violations, "min_top": min_top}


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


## The two read-only checks over the same 128 (site, seed) pairs, MERGED INTO ONE GENERATION PASS
## (`docs/DECISIONS_LEDGER.md` D0229). They were two functions each calling `ShaftGenerator.generate` over
## the identical loop, and generation is 149.3 ms -- measured, 517 calls and 77.2s of this suite's 81.1s.
## Merging the two read-only passes removes 128 of those calls, about 19s.
##
## Safe to merge precisely because BOTH ARE READ-ONLY: each calls only `find_spawn`, which mutates
## nothing. The other two passes go through `RevealSessionSetup.build`, which CARVES, and sharing one
## carved grid between the walk and jump tests is a different question with an aliasing answer -- parked
## as NEEDS_DIRECTOR P007 rather than folded in here on the grounds that it looks similar.
##
## Both assertions survive unchanged. The first is asserted against the DERIVED requirement (at least one
## solid cell between the body's left edge and x=0), not against `RevealSessionSetup.MIN_SPAWN_COL` --
## `spawn_col >= MIN_SPAWN_COL` is true by construction for any value of that constant, so it passes on
## the very mutant it exists to catch (D0112's self-referential-assertion class). The second is the other
## side of the same clamp: pushing the spawn right must never push it far enough to excavate the pocket
## it exists to approach, or a later `MIN_SPAWN_COL` change would silently pre-reveal the target and
## invalidate every reveal measurement taken after.
func _test_the_spawn_clears_the_world_edge_and_never_swallows_its_target() -> void:
	var worst: int = 1 << 30
	var worst_at: String = ""
	var worst_gap: int = 1 << 30
	var gap_at: String = ""
	var checked: int = 0
	var runs: int = 0
	for site: StringName in SITES:
		for i: int in SEEDS:
			runs += 1
			var seed_value: int = BASE_SEED + i
			var grid: TileGrid = _pristine(site, seed_value)
			var spawn: Dictionary = RevealSessionSetup.find_spawn(grid)
			var spawn_col: int = int(spawn["spawn_col"])
			if spawn_col < worst:
				worst = spawn_col
				worst_at = "%s seed=%d" % [site, seed_value]
			if int(spawn["target_glimmer_col"]) < 0:
				continue  # no shallow pocket this seed -- the width/2 fallback, nothing to swallow
			checked += 1
			var gap: int = int(spawn["target_glimmer_col"]) - (spawn_col + SHAFT_COLS)
			if gap < worst_gap:
				worst_gap = gap
				gap_at = "%s seed=%d (spawn %d, target %d)" % [site, seed_value, spawn_col, spawn["target_glimmer_col"]]
	print("  [OBSERVED] minimum spawn_col over %d seeds x %d sites: %d (%s)" % [SEEDS, SITES.size(), worst, worst_at])
	print("  [OBSERVED] tightest target-outside-shaft gap over %d seeds with a pocket: %d cols (%s)"
		% [checked, worst_gap, gap_at])
	_check_over(runs, worst >= 1,
		"no (site, seed) spawns the body flush against the world's left edge -- at least one solid cell stands between them (worst spawn_col %d at %s)"
		% [worst, worst_at])
	# The population is the seeds that HAVE a pocket, not the seeds that ran: a corpus where every seed took
	# the `continue` above leaves `worst_gap` holding its sentinel, and the assertion passes having compared
	# nothing. This was originally a hand-written `checked > 0` line bolted on beside the real assertion
	# (D0229); `_check_over` is that same idea as one call, so the population cannot drift away from the
	# assertion it protects (D0245).
	_check_over(checked, worst_gap >= 0,
		"the carved entry shaft never reaches the target pocket, so the target is never pre-revealed at spawn (tightest %d at %s, over %d of %d runs with a pocket)"
		% [worst_gap, gap_at, checked, runs])


func _test_walking_left_from_the_real_spawn_never_leaves_the_world() -> void:
	var total_violations: int = 0
	var offender: String = ""
	var worst_left: int = 1 << 60
	var worst_at: String = ""
	var runs: int = 0
	for site: StringName in SITES:
		for i: int in SEEDS:
			runs += 1
			var seed_value: int = BASE_SEED + i
			var session: Dictionary = RevealSessionSetup.build_on(_pristine(site, seed_value))
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
	# `total_violations == 0` is the shape D0245 guards: a sum over an empty corpus is zero, so a SITES list
	# that lost its entries would read as the strongest possible pass. `runs` is COUNTED in the loop rather
	# than computed as `SEEDS * SITES.size()`, because a product of two constants cannot register a loop body
	# that never executed.
	_check_over(runs, total_violations == 0,
		("holding LEFT for %d ticks from the real spawn never leaves the world, on any of %d seeds x %d " +
		"sites (%d violating ticks%s)")
		% [WALK_TICKS, SEEDS, SITES.size(), total_violations, "" if offender == "" else ", first " + offender])
	# The mechanism, not just the outcome: a body stopped by terrain never reaches x=0 at all, so its own
	# furthest-left is strictly positive. A body stopped by the world-edge clamp sits at exactly 0. This is
	# what distinguishes "the fix works" from "the clamp is quietly doing the work and not reporting it".
	_check_over(runs, worst_left > 0,
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


## D0199, the vertical mirror of `_test_walking_left_...`. Found in the director's own Slice 1 `--play`
## session (`reveal_play_2026-08-30T05-58-03.log`), which reported one bounds violation with the body's box
## reaching y = -3.4px -- through the CEILING, on a build where the left-edge fix was already in.
func _test_jumping_from_the_real_spawn_never_leaves_the_world_through_the_ceiling() -> void:
	var total_violations: int = 0
	var offender: String = ""
	var worst_top: int = 1 << 60
	var worst_at: String = ""
	var runs: int = 0
	for site: StringName in SITES:
		for i: int in SEEDS:
			runs += 1
			var seed_value: int = BASE_SEED + i
			var session: Dictionary = RevealSessionSetup.build_on(_pristine(site, seed_value))
			var jumped: Dictionary = _hold_jump(session["body"], session["grid"])
			total_violations += int(jumped["violations"])
			if int(jumped["min_top"]) < worst_top:
				worst_top = int(jumped["min_top"])
				worst_at = "%s seed=%d" % [site, seed_value]
			if int(jumped["violations"]) > 0 and offender == "":
				offender = ("%s seed=%d (%d ticks, min_top %.4f px)"
					% [site, seed_value, jumped["violations"], float(jumped["min_top"]) / float(Fx.SCALE)])
	print("  [OBSERVED] highest any real spawn's head reached over %d seeds x %d sites: %.4f px (%s)"
		% [SEEDS, SITES.size(), float(worst_top) / float(Fx.SCALE), worst_at])
	_check_over(runs, total_violations == 0,
		("holding JUMP for %d ticks from the real spawn never leaves the world through the ceiling, on any " +
		"of %d seeds x %d sites (%d violating ticks%s)")
		% [JUMP_TICKS, SEEDS, SITES.size(), total_violations, "" if offender == "" else ", first " + offender])
	_check_over(runs, worst_top > 0,
		"every real spawn's head is stopped by ROCK, strictly inside the world, never by the world-edge clamp (highest %.4f px at %s; 0.0 would mean the clamp)"
		% [float(worst_top) / float(Fx.SCALE), worst_at])


## The vertical control, and what makes the assertion above a measurement. Same seed, same column, same
## input -- only the entry shaft's own first row differs. If this ever reads 0 violations, either the jump
## stopped happening or the body stopped moving, and the test above is green about nothing.
func _test_the_control_jumping_under_an_open_ceiling_DOES_leave_the_world() -> void:
	var session: Dictionary = _prefix_ceiling_session(&"reveal_test_dense", BASE_SEED)
	var jumped: Dictionary = _hold_jump(session["body"], session["grid"])
	print("  [OBSERVED] control (entry shaft carved from row 0): %d violating ticks, min_top %.4f px"
		% [jumped["violations"], float(jumped["min_top"]) / float(Fx.SCALE)])
	_check(int(jumped["violations"]) > 0,
		"CONTROL: the pre-fix open ceiling still reproduces the director's own bounds violation (%d ticks) -- if this "
		% jumped["violations"] + "ever reads 0, the test above is passing because it measures nothing")
	_check(int(jumped["min_top"]) == 0,
		"CONTROL: the pre-fix spawn is held at exactly y=0 by the world-edge CLAMP, not by rock (min_top %.4f px) -- the mirror of the real spawn's strictly-positive value"
		% (float(jumped["min_top"]) / float(Fx.SCALE)))


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