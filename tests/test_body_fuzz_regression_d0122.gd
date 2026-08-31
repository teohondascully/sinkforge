extends "res://tests/test_base.gd"

## D0125: the first permanent per-commit regression fixture built from a NIGHTLY-only escape --
## `docs/DECISIONS_LEDGER.md` D0122/D0123 found a real `discontinuity` defect (the dig-created staircase
## fragment) that `test_body_fuzz_fast.gd`'s own 100-seed/500-tick window could never reach (the
## reproducing case needs the shared grid's dig history accumulated across seeds 0-497, plus ticks past
## 500 within seed=497 itself). Rather than widen the fast suite uniformly (cost: ~114s, the full sweep's
## own price, defeating its purpose), this replays EXACTLY the minimal known-reproducing prefix -- seeds
## 0 through 497 inclusive, on ONE shared `TileGrid`, matching `fixture_body_fuzz_probe.gd`'s own
## accumulation structure exactly (a fresh-grid replay of seed=497 alone reproduces nothing -- confirmed
## directly while diagnosing D0123, the load-bearing detail of that whole investigation). This is the
## agreed mechanism: a nightly escape becomes a fast-suite case, closing the exact hole that let dig ship
## broken for a full session before the nightly sweep caught it.
##
## Targeted growth, not uniform enlargement: only `discontinuity` is asserted here, not the full
## allowlist `test_body_fuzz.gd` carries -- this fixture's whole reason to exist is the one class D0122
## found, not a second copy of the nightly gate at a smaller size.

func _initialize() -> void:
	_test_d0122_reproducing_prefix_finds_no_discontinuity()
	_finish("body_fuzz_regression_d0122")


func _test_d0122_reproducing_prefix_finds_no_discontinuity() -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(),
		["--headless", "--path", project_root, "--script", "res://tests/fixture_body_fuzz_probe.gd",
			"--", "--seeds=498", "--ticks=1500"],
		output, true)
	_check(exit_code == 0, "the fuzz subprocess itself exits cleanly (got %d)" % exit_code)
	var combined: String = "\n".join(output)
	# D0117/D0120's own guard, same reason as every other fuzz wrapper in this project.
	_check(not combined.contains("SCRIPT ERROR:"),
		"the fuzz probe's own output contains no SCRIPT ERROR (docs/DECISIONS_LEDGER.md D0117)")
	var summary_line: String = ""
	for line: String in combined.split("\n"):
		if line.begins_with("FUZZ_SUMMARY"):
			summary_line = line
	_check(summary_line != "", "the fuzz probe printed its own summary line (got none -- did it crash mid-run?)")
	_check(summary_line.contains("seeds=498") and summary_line.contains("ticks_per_seed=1500"),
		"the probe actually ran the D0122 reproducing prefix, not a silent fallback to some other size (got: %s)" %
		summary_line)
	var discontinuity_count: int = combined.count("type=discontinuity ")
	print("body_fuzz_regression_d0122 coverage: %s -- discontinuity=%d" % [summary_line, discontinuity_count])
	_check_over(fuzz_total_ticks(combined), discontinuity_count == 0,
		"zero 'discontinuity' violations across seeds 0-497 (the D0122 reproducing prefix) -- got %d; see this run's own stdout above for the first occurrence" %
		discontinuity_count)
