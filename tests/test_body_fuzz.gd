extends "res://tests/test_base.gd"

## D0057. Runs `fixture_body_fuzz_probe.gd`'s FULL sweep (1000 seeds x 1500 ticks of fully-decorrelated
## random input, no goal) as a subprocess -- counting `push_error`/print output from the same script
## that produced it doesn't work in-process, the same reason `fixture_div_by_zero_probe.gd` exists --
## and asserts on its captured output. `test_body_fuzz_fast.gd` runs a much smaller subset of this same
## fixture for per-commit CI; this file is the deep sweep, meant for local runs and a scheduled CI job
## (D0060 -- see `.github/workflows/harness.yml`'s `fuzz_nightly` job).
##
## `overflow`, `discontinuity`, `deadlock` are asserted HARD (zero tolerance) -- no known, accepted
## exception exists for any of the three at this sweep size.
##
## `embedded` and `grounded_no_floor` are asserted against a NAMED, COUNTED allowlist, not zero -- D0060.
## Both started far higher (1,749 and thousands respectively) and were root-caused and fixed down to a
## known, narrow residual across D0059's four sub-fixes; the numbers below are the exact counts measured
## on this sweep after every one of those fixes landed, not a guess:
##   - `embedded` <= 1: a single-tick graze of `HostileChamber.JUMP_CORNER` (seed=605, tick=844) while a
##     body already correctly falling toward the real floor below clips the isolated tile's corner for
##     exactly one tick before `_resolve_horizontal`'s depenetration clears it the next tick. Not an
##     oscillation or a stuck state (both those classes are what D0059's fixes actually eliminated) --
##     the box's own footprint touches one solid cell for one tick while in transit, which
##     `_grid_floor_backstop`'s own "is there a real, unreached floor still further down" guard (D0059g)
##     correctly refuses to treat as a landing, at the cost of not being able to suppress the single-tick
##     geometric overlap itself.
##   - `grounded_no_floor` <= 32: `_grid_floor_backstop` (D0059f) deliberately rests a body on the
##     TOPMOST solid row anywhere in its footprint when it is the only real ground available (a pit's own
##     lip) -- by construction this can leave OTHER columns of the same footprint over open air, which is
##     exactly what `PropertyChecks.grounded_implies_solid_beneath` (D0058) checks for. This is the
##     backstop's own known trade-off (rest fully, embed, and oscillate forever vs. rest partially and
##     report it), not an unexplained defect.
## An allowlist with a number attached is honest; a disabled check is not (the director's own words) --
## if either count grows on a future run, that is a new, real regression, not a widening of this bound.

func _initialize() -> void:
	_test_fuzz_finds_no_new_correctness_defects()
	_finish("body_fuzz")


## D0060: the allowlist bounds above, as data -- kept here rather than inlined so `test_body_fuzz_fast.gd`
## can read the same source of truth for its own (tighter, currently-zero) expectations without a second
## place either file's bound could drift out of sync with the other.
const ALLOWLIST: Dictionary = {"embedded": 1, "grounded_no_floor": 32}


func _test_fuzz_finds_no_new_correctness_defects() -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(),
		["--headless", "--path", project_root, "--script", "res://tests/fixture_body_fuzz_probe.gd"],
		output, true)
	_check(exit_code == 0, "the fuzz subprocess itself exits cleanly (got %d)" % exit_code)
	var combined: String = "\n".join(output)
	var counts: Dictionary = {}
	for kind: String in ["bounds", "floor_selection", "embedded", "grounded_no_floor", "overflow",
			"discontinuity", "deadlock"]:
		counts[kind] = combined.count("type=%s " % kind)
	var summary_line: String = ""
	for line: String in combined.split("\n"):
		if line.begins_with("FUZZ_SUMMARY"):
			summary_line = line
	_check(summary_line != "", "the fuzz probe printed its own summary line (got none -- did it crash mid-run?)")
	print("body_fuzz coverage: %s -- bounds=%d floor_selection=%d (reported, not gated) -- allowlisted: embedded=%d/%d grounded_no_floor=%d/%d" %
		[summary_line, counts["bounds"], counts["floor_selection"],
		counts["embedded"], ALLOWLIST["embedded"], counts["grounded_no_floor"], ALLOWLIST["grounded_no_floor"]])
	for kind: String in ["overflow", "discontinuity", "deadlock"]:
		_check(counts[kind] == 0,
			"zero '%s' violations across the fuzz sweep (got %d) -- see this run's own stdout above for the first occurrences" %
			[kind, counts[kind]])
	for kind: String in ALLOWLIST:
		_check(counts[kind] <= ALLOWLIST[kind],
			"'%s' violations stay within the documented D0060 allowlist (got %d, allowlisted %d) -- see this run's own stdout above; a count ABOVE the allowlist is a new regression, not the known residual" %
			[kind, counts[kind], ALLOWLIST[kind]])
