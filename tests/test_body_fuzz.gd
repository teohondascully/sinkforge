extends "res://tests/test_base.gd"

## D0057. Runs `fixture_body_fuzz_probe.gd` (1000 seeds x 1500 ticks of fully-decorrelated random input,
## no goal) as a subprocess -- counting `push_error`/print output from the same script that produced it
## doesn't work in-process, the same reason `fixture_div_by_zero_probe.gd` exists -- and asserts on its
## captured output.
##
## Four of the six violation types this fuzzer checks are asserted HARD (zero tolerance): `embedded`
## (the body's final resolved position overlaps solid material -- nothing currently corrects this, unlike
## bounds), `discontinuity` (a position jump bigger than any known legitimate mechanic explains),
## `overflow` (numeric magnitude far past anything real), `deadlock` (state frozen for 300+ ticks despite
## continuously-varying random input).
##
## `bounds` and `floor_selection` are DELIBERATELY NOT asserted zero here, and this is a real judgment
## call, not an oversight -- see D0057 for the reasoning. Both already have a verified, unconditional
## correction (`Body._enforce_grid_bounds`, D0055; `Invariants.check_floor_selection` is diagnostic-only
## by design, ADR-0005) and dedicated tests that already accept the underlying condition occurring
## (`test_bounds_invariant.gd`'s sustained-pressure test, `test_cave_geometry.gd`'s ambiguous-floor
## tests) -- asserting zero here would just be re-litigating those, and would immediately fail on the
## chamber's own known, already-accepted left edge (nothing stops the body walking past column 0; the
## fuzzer found this constantly, since 1/3 of random `move_dir` draws point left from a spawn two columns
## in). This file counts and reports both instead, as the coverage-frequency data D0057 also asked for --
## a sudden large jump in either count on an unrelated change is still worth noticing, just not a FAIL by
## itself.

func _initialize() -> void:
	_test_fuzz_finds_no_new_correctness_defects()
	_finish("body_fuzz")


func _test_fuzz_finds_no_new_correctness_defects() -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(),
		["--headless", "--path", project_root, "--script", "res://tests/fixture_body_fuzz_probe.gd"],
		output, true)
	_check(exit_code == 0, "the fuzz subprocess itself exits cleanly (got %d)" % exit_code)
	var combined: String = "\n".join(output)
	var counts: Dictionary = {}
	for kind: String in ["bounds", "floor_selection", "embedded", "overflow", "discontinuity", "deadlock"]:
		counts[kind] = combined.count("type=%s " % kind)
	var summary_line: String = ""
	for line: String in combined.split("\n"):
		if line.begins_with("FUZZ_SUMMARY"):
			summary_line = line
	_check(summary_line != "", "the fuzz probe printed its own summary line (got none -- did it crash mid-run?)")
	print("body_fuzz coverage: %s -- bounds=%d floor_selection=%d (reported, not gated)" %
		[summary_line, counts["bounds"], counts["floor_selection"]])
	for kind: String in ["embedded", "overflow", "discontinuity", "deadlock"]:
		_check(counts[kind] == 0,
			"zero '%s' violations across the fuzz sweep (got %d) -- see this run's own stdout above for the first occurrences" %
			[kind, counts[kind]])
