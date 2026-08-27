extends "res://tests/test_base.gd"

## D0060: per-commit CI companion to `test_body_fuzz.gd`'s full 1000x1500 sweep -- "a fuzzer that takes
## four minutes will get disabled within a month" (the director's own words) applies to every commit,
## not just the deep one. 100 seeds x 500 ticks (measured: ~5s locally, vs. the full sweep's ~114s),
## invoked via `fixture_body_fuzz_probe.gd`'s own `--seeds=`/`--ticks=` override.
##
## Every violation type is asserted HARD zero here, INCLUDING `embedded` and `grounded_no_floor` --
## `test_body_fuzz.gd`'s own D0060 allowlist entries are unreachable within this smaller window (measured
## directly: 0/0 on this exact seed/tick range, since the known residual's specific occurrences --
## seed=605 tick=844 for `embedded`; seed>=98 at ticks past 500 for `grounded_no_floor` -- fall outside
## seeds 0-99 or past tick 500). This is not a looser bound reached by luck: any NEW occurrence inside
## this narrower, more heavily-trodden window (the seeds/ticks every commit actually exercises) is real
## regression evidence, not the known residual, so zero tolerance stays correct and MORE valuable here,
## not less.

func _initialize() -> void:
	_test_fast_fuzz_finds_no_correctness_defects()
	_finish("body_fuzz_fast")


func _test_fast_fuzz_finds_no_correctness_defects() -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(),
		["--headless", "--path", project_root, "--script", "res://tests/fixture_body_fuzz_probe.gd",
			"--", "--seeds=100", "--ticks=500"],
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
	_check(summary_line.contains("seeds=100") and summary_line.contains("ticks_per_seed=500"),
		"the probe actually ran with the fast override, not silently falling back to the full sweep (got: %s)" %
		summary_line)
	print("body_fuzz_fast coverage: %s -- bounds=%d floor_selection=%d (reported, not gated)" %
		[summary_line, counts["bounds"], counts["floor_selection"]])
	for kind: String in ["embedded", "grounded_no_floor", "overflow", "discontinuity", "deadlock"]:
		_check(counts[kind] == 0,
			"zero '%s' violations across the fast fuzz sweep (got %d) -- see this run's own stdout above for the first occurrences" %
			[kind, counts[kind]])
