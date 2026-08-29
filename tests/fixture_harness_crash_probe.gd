extends "res://tests/test_base.gd"

## Not a real test suite. Deliberately triggers an engine-level `SCRIPT ERROR:` mid-run (an out-of-bounds
## `Array` read) -- the exact D0115 mechanism, reproduced and root-caused here rather than only observed
## once during D0114's mutation testing. Exists so the fix (`tools/run_gd_test.sh`, D0116) has a real,
## permanent, reproducible case to prove itself against.
##
## NOT part of the `tests/test_*.gd` glob any CI step or local runner iterates -- run only by
## `tools/test_run_gd_test.sh`, this file's own dedicated caller. `fixture_*.gd` (not `test_*.gd`) is this
## project's own existing convention for exactly this kind of special-purpose, deliberately-not-a-real-
## suite probe (`fixture_div_by_zero_probe.gd`, `fixture_bounds_pressure_probe.gd`, ...).
##
## GDScript root cause, confirmed empirically (three scratch probes, not guessed): an uncaught runtime
## error does not propagate as an exception (GDScript has none) -- it unwinds ONLY the function it
## occurred in, which returns a type-default value to ITS OWN caller, and that caller then continues
## normally as if the call had returned that default. A crash directly inside `_initialize()` (the
## SceneTree entry point Godot itself calls, with no GDScript caller above it to unwind to) hangs
## forever instead -- a real, different, ALREADY-mitigated failure mode (`.github/workflows/harness.yml`'s
## own `timeout-minutes`, and the documented `core/MODULE.md` hazard note). This probe deliberately
## crashes inside a CALLED function, matching every real `_test_*()` suite's own shape, to reproduce the
## dangerous mode: no hang, no non-zero exit, `_finish()` reached normally, `_failures` genuinely 0.

static func _crash() -> int:
	var empty: Array[int] = []
	return empty[0]  # SCRIPT ERROR: Out of bounds get index -- unwinds ONLY this function (see above)


func _test_that_crashes() -> void:
	_check(true, "before the crash inside this test function: still fine")
	var _boom: int = _crash()  # SCRIPT ERROR fires here; this function's remaining lines never run
	_check(true, "UNREACHABLE -- if this ever prints, GDScript's error-unwind semantics changed")


func _test_that_runs_after_the_crash() -> void:
	_check(true, "a LATER test function, called normally by _initialize()'s own sequential list -- proves"
		+ " the crash above did not abort the suite, only the one function it happened in")


func _initialize() -> void:
	_test_that_crashes()
	_test_that_runs_after_the_crash()
	_finish("harness_crash_probe")
