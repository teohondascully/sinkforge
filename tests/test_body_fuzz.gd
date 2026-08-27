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
## `embedded` and `grounded_no_floor` are asserted against NAMED, COUNTED bounds, not zero -- but the two
## are DIFFERENT KINDS OF THING (D0061, correcting D0060's own framing, which lumped them together as one
## "allowlist"), and are kept in two separate constants below so a future reader can't mistake one for
## the other:
##
## `RESIDUAL` -- a genuine, unresolved leftover that should trend toward zero, never designed around:
##   - `embedded` <= 1: a single-tick graze of `HostileChamber.JUMP_CORNER` (seed=605, tick=844) while a
##     body already correctly falling toward the real floor below clips the isolated tile's corner for
##     exactly one tick before `_resolve_horizontal`'s depenetration clears it the next tick. Not an
##     oscillation or a stuck state (both those classes are what D0059's fixes actually eliminated) --
##     the box's own footprint touches one solid cell for one tick while in transit, which
##     `_grid_floor_backstop`'s own "is there a real, unreached floor still further down" guard (D0059g)
##     correctly refuses to treat as a landing, at the cost of not being able to suppress the single-tick
##     geometric overlap itself.
##
## `DESIGN_TRADEOFF` -- a deliberate choice with a stated cost and a real alternative, not a bug to fix:
##   - `grounded_no_floor` <= 32: `_grid_floor_backstop` (D0059f) deliberately rests a body on the
##     TOPMOST solid row anywhere in its footprint when that is the only real ground available (a pit's
##     own lip), rather than requiring the ENTIRE footprint to be supported before granting `on_floor`.
##     The alternative (full-footprint support required) was available and is not what shipped -- it
##     would make this count zero, at the cost of a body standing at ANY narrow ledge edge (not just a
##     pit) needing to walk fully onto it before resting, and a pit-lip body specifically would just keep
##     falling instead of resting at all, since nothing else supports it. D0061 has the full reasoning and
##     the reversal cost. In play: a body standing at a lip with most of its own width still hanging over
##     open air reads as grounded (can jump, doesn't fall) even though the FULL footprint isn't supported
##     -- visually similar to the ledge-edge forgiveness coyote time already grants, not a new kind of
##     wrongness a player would name, but worth stating plainly rather than leaving implicit.
##
## An allowlist with a number attached is honest; a disabled check is not (the director's own words) --
## if either count grows on a future run, that is a new, real regression, not a widening of this bound.

func _initialize() -> void:
	_test_fuzz_finds_no_new_correctness_defects()
	_finish("body_fuzz")


## D0060/D0061: the bounds above, as data -- kept here rather than inlined so `test_body_fuzz_fast.gd`
## can read the same source of truth for its own (tighter, currently-zero) expectations without a second
## place either file's bound could drift out of sync with the other. Two separate constants, not one
## dictionary, because they answer different questions when one of them moves: a `RESIDUAL` count moving
## is a regression to root-cause; a `DESIGN_TRADEOFF` count moving is a change in how often the traded-off
## scenario actually occurs, worth noting but not automatically a defect.
const RESIDUAL: Dictionary = {"embedded": 1}
const DESIGN_TRADEOFF: Dictionary = {"grounded_no_floor": 32}


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
	print("body_fuzz coverage: %s -- bounds=%d floor_selection=%d (reported, not gated) -- residual: embedded=%d/%d -- design trade-off: grounded_no_floor=%d/%d" %
		[summary_line, counts["bounds"], counts["floor_selection"],
		counts["embedded"], RESIDUAL["embedded"], counts["grounded_no_floor"], DESIGN_TRADEOFF["grounded_no_floor"]])
	for kind: String in ["overflow", "discontinuity", "deadlock"]:
		_check(counts[kind] == 0,
			"zero '%s' violations across the fuzz sweep (got %d) -- see this run's own stdout above for the first occurrences" %
			[kind, counts[kind]])
	for kind: String in RESIDUAL:
		_check(counts[kind] <= RESIDUAL[kind],
			"'%s' violations stay within the documented D0059 RESIDUAL bound (got %d, bound %d) -- see this run's own stdout above; a count ABOVE the bound is a new regression, not the known residual" %
			[kind, counts[kind], RESIDUAL[kind]])
	for kind: String in DESIGN_TRADEOFF:
		_check(counts[kind] <= DESIGN_TRADEOFF[kind],
			"'%s' violations stay within the documented D0061 DESIGN TRADE-OFF bound (got %d, bound %d) -- see this run's own stdout above; a count ABOVE the bound means the traded-off scenario is occurring more than measured, worth a fresh look at whether the trade-off still holds" %
			[kind, counts[kind], DESIGN_TRADEOFF[kind]])
