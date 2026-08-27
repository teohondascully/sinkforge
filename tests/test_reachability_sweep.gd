extends "res://tests/test_base.gd"

## D0055. `test_bounds_invariant.gd` proves the safety net holds at two specific, pinned spots (the real
## shaft-wall mantle chain, sustained pressure at the left edge). This file is the director's other half
## of "fix 1": not a pinned repro, a SWEEP -- "the chamber's traversal path and the chamber's reachable
## space are different sets, and only the first is tested" was the root finding, so this runs a policy
## that never stops trying jump and mantle across the chamber's own full built width, not just the
## golden `ScriptedTraverse`'s narrow, landmark-timed route through it. "If a player can get somewhere,
## the suite should go there."
##
## Counting `push_error` occurrences from the same script that provoked them doesn't work in-process
## (the same reason `fixture_div_by_zero_probe.gd` exists) -- `fixture_aggressive_sweep_probe.gd` runs
## the real sweep as a subprocess; this asserts on its captured stderr.

func _initialize() -> void:
	_test_aggressive_sweep_never_leaves_the_grid()
	_finish("reachability_sweep")


func _test_aggressive_sweep_never_leaves_the_grid() -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(),
		["--headless", "--path", project_root, "--script", "res://tests/fixture_aggressive_sweep_probe.gd"],
		output, true)
	_check(exit_code == 0, "the sweep subprocess itself exits cleanly (got %d)" % exit_code)
	var combined: String = "\n".join(output)
	var occurrences: int = combined.count("left the world")
	_check(occurrences == 0,
		"3000 ticks of continuous right+jump+mantle pressure across the chamber's full built width never leaves the grid -- got %d occurrence(s) (captured output: %s)" %
		[occurrences, combined])
