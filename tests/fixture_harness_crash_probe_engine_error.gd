extends "res://tests/test_base.gd"

## Companion to fixture_harness_crash_probe.gd (D0115/D0116): that fixture reproduces a GDScript-level
## `SCRIPT ERROR:` (an out-of-bounds `[]` read). THIS fixture reproduces a DIFFERENT masked-crash shape
## the D0149 audit found `tools/run_gd_test.sh` never checked for at all: an ENGINE-level bare `ERROR:`
## from a native `Array` method's own internal bounds check (`Array.remove_at()` with an out-of-range
## index) -- confirmed empirically (three scratch probes, not guessed) to print
##
##     ERROR: The calculated index 99 is out of bounds (the array has 3 elements). Leaving the array untouched.
##        at: remove_at (core/variant/array.cpp:512)
##
## i.e. NOT prefixed `SCRIPT ERROR:` at all, so the pre-D2 detector (which only ever grepped for that
## exact prefix) let this straight through. Confirmed the hard part directly, not assumed: a deliberate
## `push_error()` call ALSO prints a bare `ERROR:` first line with its own `at:` line pointing at a
## `core/*.cpp` engine location (`at: push_error (core/variant/variant_utility.cpp:1024)`) -- so the two
## cases cannot be told apart by "ERROR: is from the engine" alone. The one thing that DOES differ is the
## `at:` line's own function name: `push_error`/`push_warning` for a deliberate log call, anything else
## (here, `remove_at`) for a real unguarded native-call failure. This fixture's own `_crash()` continues
## normally afterward with NO unwinding at all (unlike the `[]`-read case) -- `remove_at()` is a void
## method, so there is no return value to poison, making this an even more silent failure mode than
## D0115's own original.
##
## NOT part of the `tests/test_*.gd` glob any CI step or local runner iterates -- run only by
## `tools/test_run_gd_test.sh`, matching `fixture_harness_crash_probe.gd`'s own convention.

static func _crash() -> void:
	var arr: Array = [1, 2, 3]
	arr.remove_at(99)  # ERROR: The calculated index 99 is out of bounds... -- NOT "SCRIPT ERROR:"


func _test_that_crashes_at_the_engine_level() -> void:
	_check(true, "before the crash inside this test function: still fine")
	_crash()
	_check(true, "after the crash: this line still runs -- remove_at() is void, nothing unwinds at all")


func _test_that_runs_after_the_crash() -> void:
	_check(true, "a LATER test function, called normally by _initialize()'s own sequential list -- proves"
		+ " the crash above did not abort the suite")


func _initialize() -> void:
	_test_that_crashes_at_the_engine_level()
	_test_that_runs_after_the_crash()
	_finish("harness_crash_probe_engine_error")
