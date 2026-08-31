extends "res://tests/test_base.gd"

## Mutation tests for `test_base.gd`'s `over()` / `_check_over()`, D0245.
##
## The guard refuses an assertion that ranges over an EMPTY population, because such an assertion is true
## by construction whatever the code does. This suite exists because a guard that has never been observed
## refusing is not a guard -- `docs/QUALITY.md` §2 -- and because this particular guard is the one the
## rest of the suite population will lean on.
##
## THE BRANCH THAT MATTERS is `over(0, true, ...)`: a condition that WOULD have passed, refused because
## it had no subject. If only the false branches were tested, a `return [condition, label]` with the
## count check deleted would still look correct.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_empty_population_guard.gd


func _initialize() -> void:
	_test_a_true_condition_over_nothing_is_refused()
	_test_a_real_population_still_decides_on_the_condition()
	_test_the_label_says_which_kind_of_failure_it_is()
	_test_the_guard_is_reachable_through_the_wrapper()
	_test_the_fuzz_population_is_read_not_assumed()
	_finish("empty_population_guard")


## THE POINT OF THE WHOLE FILE. `true` is the value a vacuous assertion actually produces -- `all()` over
## an empty array, a loop body that never runs, a max that is never contradicted -- so this is the case
## the guard exists to catch, and the only one that distinguishes it from a plain `_check`.
func _test_a_true_condition_over_nothing_is_refused() -> void:
	var verdict: Array = over(0, true, "every star is above the horizon")
	_check(not bool(verdict[0]),
		"a TRUE condition over 0 items is refused -- the case a plain _check would have passed")
	var negative: Array = over(-3, true, "a negative count is not a population either")
	_check(not bool(negative[0]),
		"and so is a negative count, which is what a bad subtraction produces rather than a crash")


## The negative control. If the guard refused everything it would be useless in a different way, and
## every suite that adopted it would go red for the wrong reason.
func _test_a_real_population_still_decides_on_the_condition() -> void:
	_check(bool(over(42, true, "x")[0]),
		"a true condition over 42 items passes -- the guard defers to the assertion when there is one")
	_check(not bool(over(42, false, "x")[0]),
		"and a FALSE condition over 42 items still fails, so the guard is not swallowing real failures")
	_check(bool(over(1, true, "x")[0]),
		"one item is a population: the boundary is > 0, not > 1")


## A vacuous pass and a real failure are different bugs and must not read alike in a log. Someone
## scanning output has to be able to tell "your code is wrong" from "your fixture built nothing".
func _test_the_label_says_which_kind_of_failure_it_is() -> void:
	var vacuous: String = String(over(0, true, "the field scatters")[1])
	var real: String = String(over(9, false, "the field scatters")[1])
	_check(vacuous.contains("VACUOUS") and vacuous.contains("0 item"),
		"the empty verdict names itself and its count: %s" % vacuous.substr(0, 60))
	_check(not real.contains("VACUOUS") and real.contains("over 9 item"),
		"a genuine failure does NOT say VACUOUS, and reports the population it ranged over: %s" % real)
	_check(vacuous.contains("the field scatters"),
		"and both keep the caller's own label, so the failing line is still findable")


## The wrapper is what suites actually call, so prove it is wired to the predicate rather than
## reimplementing it. Passing counts only -- a failing `_check_over` here would fail THIS suite, which is
## correct behaviour but would make the file unable to report anything else.
func _test_the_guard_is_reachable_through_the_wrapper() -> void:
	_check_over(3, true, "_check_over defers to over() and passes a real population")
	var before: int = _failures
	_check_over(0, true, "this line is EXPECTED to fail -- it is the guard firing on purpose")
	_check(_failures == before + 1,
		"and _check_over over an empty population records exactly one failure (%d -> %d)"
		% [before, _failures])
	## Undo the deliberate failure, or this suite reports a red it manufactured itself. Done explicitly
	## and named, because silently adjusting a failure counter is otherwise indistinguishable from
	## hiding one.
	_failures = before
	_check(true, "deliberate failure retracted; this suite's own count is honest again")


## `fuzz_total_ticks()` is what carries a real population into the three fuzz suites, whose assertions are
## all `counts[kind] == 0` -- the exact direction that passes over nothing. The case that matters is the
## one their old `summary_line != ""` guard could not see: a summary line that IS present and reports a
## sweep of zero.
func _test_the_fuzz_population_is_read_not_assumed() -> void:
	var real := "some noise\nFUZZ_SUMMARY seeds=100 ticks_per_seed=500 total_ticks=50000 violations=0 dig_disabled=false\ntail"
	_check(fuzz_total_ticks(real) == 50000,
		"a real summary line yields its own total_ticks (got %d, want 50000)" % fuzz_total_ticks(real))
	## THE DISCRIMINATOR. This line is PRESENT, so `summary_line != ""` passes on it; the population is 0,
	## so `_check_over` refuses -- which is the entire reason the parser exists rather than the presence check.
	var empty_sweep := "FUZZ_SUMMARY seeds=0 ticks_per_seed=500 total_ticks=0 violations=0 dig_disabled=false"
	_check(empty_sweep != "" and fuzz_total_ticks(empty_sweep) == 0,
		"a sweep that ran NOTHING still prints a present summary line, and reads as a population of 0")
	_check(not bool(over(fuzz_total_ticks(empty_sweep), true, "zero 'deadlock' violations")[0]),
		"so the hard-zero assertion over it is refused rather than passing, which is the whole retrofit")
	_check(fuzz_total_ticks("no summary here at all") == 0,
		"a crashed probe with no summary line also reads 0 -- absent and empty mean the same to a caller")
	_check(fuzz_total_ticks("FUZZ_SUMMARY seeds=4 violations=0") == 0,
		"and so does a summary line missing the field, rather than returning some other line's number")
