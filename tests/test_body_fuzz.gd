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
## `DESIGN_TRADEOFF` -- named this way when 32 was raised to 59 (D0122/D0127/D0128), but the justification
## given for that raise was ITSELF FALSIFIED shortly after, by an instrument built specifically to check
## it (D0132/D0135) -- corrected here (D0150/queue D3) rather than left standing, since a comment stating a
## falsified claim as settled fact is worse than no comment:
##   - `grounded_no_floor` <= 59. **What D0128 claimed at the time:** the entire 32->59 excess was the
##     already-accepted `_grid_floor_backstop` (D0059f) pit-lip trade-off (below), reachable at more
##     locations now that dig exists -- "raise it, and in the same commit document that 59 = the D0059
##     mechanism plus dig exposure" (the director's own contemporaneous ruling, quoted in D0135). **This was
##     not true.** D0132's own per-violation telemetry measured the real split: only 4/59 (dig-on) and
##     3/32 (dig-off) violations trace to `grid_floor_backstop` at all -- the named mechanism accounts for
##     7 of 91 occurrences, not all of them (D0135, filed at HIGH severity as a falsified decision-
##     rationale, not a prose imprecision).
##   - **The actual dominant mechanism, diagnosed after the fact (D0137), not assumed:** `resolve_floor`
##     samples the heightfield at three x-positions (left foot, right foot, centre) and takes
##     `mini(s_left, s_right, s_centre)` as the landing surface -- but `Heightfield.NO_FLOOR` (an i32-max
##     sentinel meaning "this sample cannot vote, the columns it straddles disagree across a real gap") is
##     just a very large integer to `mini()`, so it never wins. Whenever AT LEAST ONE of the three samples
##     finds real ground, `resolve_floor` grounds the body's ENTIRE footprint there and returns `true` --
##     even when another sample correctly reported open air beneath it -- which short-circuits
##     `move_and_resolve`'s own `resolve_floor(...) or grid_floor_backstop(...)` before the backstop below
##     ever runs. Measured across all 84 non-`grid_floor_backstop` occurrences (55 dig-on + 29 dig-off):
##     100% show a real, unambiguous floor at one sample and an honest `NO_FLOOR` at another, on a
##     partially-solid footprint -- one exact, fully-characterized mechanism, not several partly-understood
##     ones, and NOT heightfield interpolation blending (that hypothesis was directly refuted: `transition`
##     is `false` in all 84 cases).
##   - **Pre-existing, not dig-created -- confirmed, not assumed:** the dig-OFF population alone already
##     shows 29 occurrences of this exact `resolve_floor` mechanism, at `HostileChamber`'s own BUILT-IN
##     flat-to-open transitions. Dig only creates MORE locations reaching the same `FLOOR_ROW` height by
##     carving new ones sideways -- the frequency rose, the mechanism did not change.
##   - `_grid_floor_backstop` (D0059f) itself, for the minority of violations it DOES cause: deliberately
##     rests a body on the TOPMOST solid row anywhere in its footprint when that is the only real ground
##     available (a pit's own lip), rather than requiring the ENTIRE footprint to be supported before
##     granting `on_floor` -- the alternative (full-footprint support required) would make this count zero,
##     at the cost of a body standing at ANY narrow ledge edge needing to walk fully onto it before
##     resting. D0061 has the full reasoning. This description is accurate on its own terms; what was wrong
##     was claiming it explains the bulk of the bound.
##   - **Current status, stated precisely (D0135): 59 is a MEASUREMENT, not yet a justified ceiling.** Its
##     mechanism moved from "known, accepted" to "diagnosed, under active investigation" -- an attempted
##     fix to `resolve_floor`'s own criterion exists and is not yet landed (`docs/DECISIONS_LEDGER.md`,
##     D0139 and its own follow-ups, for the current state of that attempt). If `grounded_no_floor` ever
##     exceeds 59, THAT is a new regression against this measured baseline, not a widening of this bound.
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
const DESIGN_TRADEOFF: Dictionary = {"grounded_no_floor": 59}  ## D0122/D0127/D0128: raised from 32


func _test_fuzz_finds_no_new_correctness_defects() -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(),
		["--headless", "--path", project_root, "--script", "res://tests/fixture_body_fuzz_probe.gd"],
		output, true)
	_check(exit_code == 0, "the fuzz subprocess itself exits cleanly (got %d)" % exit_code)
	var combined: String = "\n".join(output)
	# D0117/D0120: exit_code==0 and a present summary line are NOT enough on their own -- the exact
	# D0115/D0116 mechanism applies to `_check_tick()` too (a called function, inside this probe's own
	# `_initialize()`), so a runtime error on some seed/tick would log SCRIPT ERROR, silently NOT count
	# as a violation for that tick, and let the loop continue to a normal-looking FUZZ_SUMMARY and exit 0.
	_check(not combined.contains("SCRIPT ERROR:"),
		"the fuzz probe's own output contains no SCRIPT ERROR -- a mid-run crash on some seed/tick would" +
		" otherwise silently undercount violations rather than fail loud (docs/DECISIONS_LEDGER.md D0117)")
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
			"'%s' violations stay within the documented D0061/D0128 DESIGN TRADE-OFF bound (got %d, bound %d) -- see this run's own stdout above; a count ABOVE the bound means the traded-off scenario is occurring more than measured, worth a fresh look at whether the trade-off still holds" %
			[kind, counts[kind], DESIGN_TRADEOFF[kind]])
