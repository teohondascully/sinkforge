extends "res://tests/test_base.gd"

## D0165 (queue #2 Part G): `docs/QUALITY.md` gate 8's REAL subject. `test_replay_determinism.gd`'s own
## `TrivialStub` is explicitly NOT `sim/` (its own docstring says so) and stays as a mechanism check for
## the hash-and-replay plumbing itself; THIS file is what gate 8 actually certifies now -- a real
## `ShaftGenerator`-generated `TileGrid` and a real `Body`, driven through `tests/
## fixture_shaft_replay_probe.gd`'s ~20,000 ticks of seeded random input (jump/mantle/dig all real input
## surface), run as TWO SEPARATE `OS.execute`d PROCESSES (not two in-process calls -- process-level
## nondeterminism, e.g. leaked static/global RNG state between calls in the same process, cannot show up
## in an in-process double-run the way it can across two independently-started engines).
##
## Proof this actually tests `sim/`, unlike the stub -- stated PRECISELY, not as "moving sim/ aside"
## generically (that claim was itself wrong, caught by a fix-queue certification: `tests/test_base.gd`'s
## own `_flat_grid()` helper constructs a real `TileGrid`, so removing ALL of `sim/` breaks the shared
## harness base for EVERY suite, including the stub -- a contrast that doesn't isolate what this docstring
## needs to prove, since both tests go red for the same unrelated reason). The actual isolating removal
## (verified in a scratch clone of HEAD, never the real working tree, so a dirty local tree can never
## contaminate the result): move ONLY `sim/terrain_gen/`, `sim/body/`, `sim/invariants/`, and `tests/
## body/fuzz_driver_common.gd` outside the project, leaving `sim/world/tile_grid.gd` in place (the one
## `sim/` file `test_base.gd` itself needs). Re-import, then run both suites: `test_replay_determinism.gd`
## (the stub) stays ALL PASS, exit 0 -- `test_base.gd` is provably still loadable. `test_shaft_replay_
## determinism.gd` (this file) goes 15 FAILURE(S), exit 1, root cause `ERROR: Failed to load script
## "res://tests/fixture_shaft_replay_probe.gd" with error "Parse error"` -- `ShaftGenerator`/`Body` are
## genuinely gone. `docs/DECISIONS_LEDGER.md` D0180 has the full command sequence and pasted exit codes.

const FIXED_SEED: int = 20260826
const EXPECTED_CHECKPOINTS: int = 200

## Re-captured 2026-08-31 from CI's OWN pinned Linux Godot build (job 99622409399), after D0258 ported
## legacy's five octaves into the cave field and re-derived `FASTNOISELITE_SD_CALIBRATION` against it.
## The world changed for the second time in one session, which is the expected and correct cost of a
## terrain-affecting constant; both re-pins were captured from CI, neither from a local run.
##
## Confirmed differently from the re-capture below it, and more strongly: rather than harvesting the local
## mismatch dump and diffing it, the CI array was spliced in FIRST and the local macOS run was then made
## to assert against it -- and passed, ALL PASS, which is the file's own 200-way equality check
## confirming rather than a comparison done off to one side. Coverage byte-identical across platforms:
## `jumps=937 mantles=0 stepups=0 digs=206 corner_ok=11 corner_unconsented=0`. It moved from
## `jumps=895 digs=261 corner_ok=9`, and that movement is the point -- a different world means a
## different path through it. What would have been alarming is coverage that did NOT move, or a zero.
##
## Re-captured 2026-08-31 from CI's OWN pinned Linux Godot build (run 33367080354, job 99409885089),
## after D0254 stopped `ValueNoise._lattice_hash` truncating the seed to 16 bits. This one diverges at
## checkpoint **0**, not partway through, and that is the correct shape: the seed reaches the noise field
## before a single cell is written, so the generated world is different from the first tile onward rather
## than drifting apart after some triggering event. The scenario's own coverage is unchanged across the
## re-capture -- `jumps=895 mantles=0 stepups=0 digs=261 corner_ok=9`, byte-identical on both platforms --
## which is what distinguishes "the world changed" from "the probe stopped exercising the same surface".
## Verified identical to the local macOS run at all 200 of 200 checkpoints (both captures harvested from
## the mismatch dump below, then diffed elementwise, not eyeballed).
##
## Re-captured 2026-08-31 from CI's OWN pinned Linux Godot build (run 33459669781, branch
## `run/miner-sprite`), after D0269 gave a dug tunnel two terrain cells of headroom above the head. The
## golden scenario digs 321 times and every one of them now clears two more rows, so the trajectory
## diverges from **checkpoint 0** -- the first dig is early. THE TWO-PROCESS REPLAY CHECK PASSED
## THROUGHOUT (bit-identical, first mismatch at -1) and the seed+1 control still diverges at the first
## checkpoint: this was a re-pin, not a determinism regression, and those are different findings with
## different remedies. Verified identical to the local macOS run at all 200 checkpoints again, which is
## a fact about this change and NOT a reason to capture locally next time.
##
## Harvesting it needed D0272 first: the parallel runner was filtering a failing suite's log to its
## `FAIL` lines, so the mismatch dump below -- a bare `print()`, added by D0167 for exactly this purpose
## -- did not reach the CI log at all. The first attempt at this re-pin found an empty harvest.
##
## Re-captured 2026-08-30 from CI's OWN pinned Linux Godot build (run 33331589523, commit c953117), after
## D0213 gated the ceiling corner nudge on the body having a velocity to be nudged along -- the scenario
## contained two unconsented nudges, so the trajectory diverges from checkpoint 30 onward. Verified
## identical to the local macOS run at all 200 checkpoints this time, which is a fact about this change
## and NOT a reason to capture locally next time (the previous re-capture, run 33322672300 / commit
## f224a01 after D0209/D0212, is the same story). Originally committed
## 2026-08-29 from CI's OWN pinned Linux Godot build (`docs/DECISIONS_LEDGER.md` D0167/D0168
## have the full account) -- NOT a local macOS run, deliberately: this project's own canonical
## environment is CI, and a golden array captured on a different platform/architecture is exactly the
## mistake D0167 found and corrected once already. A future change to ANY of `ShaftGenerator`,
## `TileGrid`, `Body`, or `FuzzDriverCommon.random_input`'s own draw order changes this array; that is
## the point -- this is a real regression gate on simulation OUTPUT, not just a same-run/same-run replay
## check that could pass even if `sim/` were rewritten from scratch to produce different (but internally
## self-consistent) behavior.
const GOLDEN_HASHES: PackedStringArray = [
	"2800313299", "3652849332", "2600408561", "845197780", "2285078664", "3827715772", "1855036922", "3171030771", "657096528", "2477734867",
	"4226357195", "855894502", "2211019882", "3808700274", "3081594895", "1598318085", "286024066", "3158382058", "877181660", "1748491687",
	"4250459669", "1580400012", "633496424", "3335543403", "1792632260", "1054347861", "2677179619", "2949364637", "2819498575", "623332278",
	"3251318746", "36292081", "1362557186", "4137622190", "3260508104", "3881927842", "3478500069", "2356072560", "2552236585", "1826507194",
	"2901602518", "1602077587", "1022249321", "1560409826", "752794252", "1701267186", "2773198118", "35900580", "1065687907", "888699782",
	"1503945800", "778253688", "1863525369", "3087883380", "3477721849", "1993477290", "3908432609", "2207159576", "1762965852", "293761376",
	"818981215", "1772652479", "1104942895", "3290451731", "119704358", "994926320", "388110347", "3752708493", "3022308351", "2107803639",
	"2657835756", "2173062947", "3911690514", "703547598", "2057807301", "3408050227", "2252952484", "1270012342", "829810401", "2494395249",
	"1651597019", "3552542034", "2137050532", "2108474095", "1210272385", "3903600296", "3269525674", "300086160", "2663710433", "2231592868",
	"3476080369", "59857103", "2049650985", "3489365316", "1090461184", "1133722026", "1625078560", "167385937", "3735277290", "1214208754",
	"1039591813", "3283836331", "3412709913", "2592471360", "835840906", "821765075", "1313675982", "50077277", "382211290", "271941828",
	"174677482", "286993330", "378483693", "568450305", "1980232012", "1913237306", "992235284", "1586303563", "1148038407", "251098520",
	"837861728", "2492614646", "1277838041", "3833970916", "409059929", "1882969429", "2272479319", "3160631787", "2231620454", "2737792481",
	"110805482", "1600838048", "3526275188", "990596474", "609574229", "2319845260", "4073623492", "3865204629", "473075470", "2796976647",
	"5776357", "41974905", "185284068", "2475493885", "2876365867", "1038529972", "1610548849", "980908144", "3711721805", "2551495250",
	"825798167", "2923661224", "2475127720", "3696522750", "3360029003", "4177071358", "3374042442", "1244307864", "2833189167", "4073374189",
	"2982858511", "961433216", "2814282753", "3301585769", "1945827786", "2520978692", "492094980", "4214482429", "4013763843", "407797005",
	"4294566040", "3064263771", "3544778775", "2633228001", "2285073687", "1917219831", "3059415296", "3146344084", "4201378033", "2087264110",
	"508687698", "2558946405", "1030949586", "256032976", "2401698427", "1686560543", "2384153976", "3537413516", "1977691133", "354655094",
	"1705436728", "645928255", "2942045373", "2315219815", "4079872340", "3202936281", "3154168330", "3525438348", "3814317971", "2579946737",
]


## Runs the real fixture as its own OS process at `seed`, same `OS.execute`+captured-output pattern
## `tests/test_body_fuzz.gd` already uses for its own subprocess. Checks BOTH masked-crash shapes this
## project has already found in this exact spot (D0115/D0116's `SCRIPT ERROR:`, D0149/D0150's bare
## `ERROR:` sibling) rather than only the first -- a real native-level crash producing a bare `ERROR:`
## with no `SCRIPT ERROR:` prefix must not be silently absorbed into this probe's own expected, real
## `push_error` reports (bounds/floor-selection violations the body legitimately reaches while digging
## around freely for 20,000 ticks).
func _run_probe(seed_value: int) -> Dictionary:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(),
		["--headless", "--path", project_root, "--script", "res://tests/fixture_shaft_replay_probe.gd",
			"--", "--seed=%d" % seed_value],
		output, true)
	var combined: String = "\n".join(output)
	var lines: PackedStringArray = combined.split("\n")
	var bad_error: String = ""
	for i: int in lines.size():
		var line: String = lines[i]
		if line.begins_with("ERROR: ") and i + 1 < lines.size():
			var next_line: String = lines[i + 1].strip_edges()
			if next_line.begins_with("at: ") and not next_line.begins_with("at: push_error "):
				bad_error = line
				break
	var hashes: PackedStringArray = []
	var summary: String = ""
	var prefix: String = "SHAFT_REPLAY_HASHES seed=%d " % seed_value
	for line: String in lines:
		if line.begins_with(prefix):
			hashes = line.trim_prefix(prefix).split(",")
		elif line.begins_with("SHAFT_REPLAY_SUMMARY seed=%d " % seed_value):
			summary = line
	return {
		"exit_code": exit_code,
		"has_script_error": combined.contains("SCRIPT ERROR:"),
		"bad_error": bad_error,
		"hashes": hashes,
		"summary": summary,
	}


func _check_probe_ran_cleanly(result: Dictionary, label: String) -> void:
	_check(result.exit_code == 0, "%s: subprocess exits cleanly (got %d)" % [label, result.exit_code])
	_check(not result.has_script_error,
		"%s: no SCRIPT ERROR in output (D0115/D0116 masked-crash detector)" % label)
	_check(result.bad_error == "",
		"%s: no bare ERROR: from anything other than push_error (D0149/D0150 masked-crash sibling) -- got: %s" %
		[label, result.bad_error])
	_check(result.hashes.size() == EXPECTED_CHECKPOINTS,
		"%s: produced %d checkpoint hashes (expected %d)" % [label, result.hashes.size(), EXPECTED_CHECKPOINTS])


## Each subprocess run is a real ~20,000-tick simulation (tens of seconds); every check below is a
## PROJECTION over exactly three runs (same seed twice, seed+1 once), never a fresh run per check --
## six real runs for four checks would be pure waste of the same evidence.
func _initialize() -> void:
	var a: Dictionary = _run_probe(FIXED_SEED)
	var b: Dictionary = _run_probe(FIXED_SEED)
	var c: Dictionary = _run_probe(FIXED_SEED + 1)

	_check_probe_ran_cleanly(a, "process A (seed)")
	_check_probe_ran_cleanly(b, "process B (same seed, second process)")
	_check_probe_ran_cleanly(c, "process C (seed+1 control)")

	_test_same_seed_replays_bit_identical_across_two_processes(a, b)
	_test_seed_plus_one_diverges_at_checkpoint_zero(a, c)
	_test_matches_committed_golden_hashes(a)
	_test_scenario_actually_exercises_jump_mantle_step_and_dig(a)
	_finish("shaft_replay_determinism")


func _test_same_seed_replays_bit_identical_across_two_processes(a: Dictionary, b: Dictionary) -> void:
	var mismatch_at: int = -1
	for i: int in mini(a.hashes.size(), b.hashes.size()):
		if a.hashes[i] != b.hashes[i]:
			mismatch_at = i
			break
	_check(mismatch_at == -1,
		"two SEPARATE OS processes replaying the same seed produce bit-identical checkpoint hashes " +
		"(first mismatch at checkpoint %d)" % mismatch_at)


func _test_seed_plus_one_diverges_at_checkpoint_zero(a: Dictionary, c: Dictionary) -> void:
	_check(a.hashes.size() > 0 and c.hashes.size() > 0, "both runs produced at least one checkpoint hash")
	if a.hashes.size() > 0 and c.hashes.size() > 0:
		_check(a.hashes[0] != c.hashes[0],
			"a different seed diverges by the very FIRST checkpoint -- proves the seed genuinely drives " +
			"real varying state (terrain AND input), not a frozen no-op scenario that would pass this " +
			"whole test vacuously")


func _test_matches_committed_golden_hashes(a: Dictionary) -> void:
	_check(a.hashes.size() == GOLDEN_HASHES.size(),
		"produces exactly the %d committed golden checkpoint hashes (got %d)" %
		[GOLDEN_HASHES.size(), a.hashes.size()])
	var mismatch_at: int = -1
	for i: int in mini(a.hashes.size(), GOLDEN_HASHES.size()):
		if a.hashes[i] != GOLDEN_HASHES[i]:
			mismatch_at = i
			break
	if mismatch_at != -1:
		# Printed unconditionally on mismatch, not gated behind a verbose flag -- a real regression's own
		# new sequence must be readable straight from the CI log, not require a local re-run to see
		# (docs/DECISIONS_LEDGER.md D0167: the golden hashes were originally captured on a different
		# platform/engine build than CI's own pinned Linux Godot, and diagnosing that took an extra
		# commit+push round-trip specifically because this array wasn't printed anywhere on mismatch).
		print("shaft_replay_determinism GOLDEN MISMATCH -- observed hashes this run: %s" % ",".join(a.hashes))
	_check(mismatch_at == -1,
		("checkpoint hashes exactly match the committed golden sequence (first mismatch at checkpoint %d) " +
		"-- a real simulation-code regression changes this; deleting sim/ entirely fails this test to " +
		"parse, not just to match (docs/DECISIONS_LEDGER.md D0165)") % mismatch_at)


## The stub's own `_test_stub_state_actually_varies` proves its trivial state isn't frozen; this is that
## same principle applied to jump/step/dig (mantle is reported, not gated -- see D0168 below) -- a
## scenario that never once exercises them would make every check above pass vacuously on a body that
## only ever falls or stands still.
func _test_scenario_actually_exercises_jump_mantle_step_and_dig(a: Dictionary) -> void:
	_check(a.summary != "", "the golden run printed its own summary line (got none -- did it crash mid-run?)")
	var jumps: int = 0
	var mantles: int = 0
	var stepups: int = 0
	var digs: int = 0
	for field: String in a.summary.split(" "):
		if field.begins_with("jumps="): jumps = int(field.trim_prefix("jumps="))
		elif field.begins_with("mantles="): mantles = int(field.trim_prefix("mantles="))
		elif field.begins_with("stepups="): stepups = int(field.trim_prefix("stepups="))
		elif field.begins_with("digs="): digs = int(field.trim_prefix("digs="))
	print("shaft_replay_determinism scenario coverage: %s" % a.summary)
	_check(jumps > 0, "the golden scenario actually jumps at least once (got %d)" % jumps)
	# NOT a _check() (D0168): CI's own canonical (Linux) golden run legitimately shows mantles=0 despite
	# spawning the body directly against the mantle wall -- macOS locally mantles from the same seed and
	# geometry, CI does not. This traces to the same platform-float gap D0167 already found in
	# `ValueNoise` (real, unfixed here -- out of scope), not to a defect in `_try_climb`'s own mantle
	# logic, which IS covered elsewhere (`test_body_acceptance.gd`'s scripted traverse mantles over
	# `HostileChamber.MANTLE_START` and passes in this same CI). Reported, not asserted, so this file
	# doesn't stay permanently red over a platform gap Part G was never scoped to fix.
	if mantles == 0:
		print("shaft_replay_determinism NOTE: golden run mantled zero times on this platform (see D0168)")
	# NOT a _check() either, from D0209, and for a sharper reason than the mantle case above: this
	# assertion was only ever satisfied BY THE DEFECT. Measured directly, by instrumenting this scenario's
	# own probe to record whether the body was airborne on each step-up and running it either side of the
	# fix: **AIRBORNE_STEPUPS=11 of 11**. Every step-up this 20,000-tick scenario has ever produced was
	# `_try_step` firing in mid-air -- the body translated a full logic tile in one tick, 960 px/s against
	# a 560 px/s terminal velocity. It has never once exercised a legitimate grounded step-up, so the
	# coverage this line claimed to prove did not exist; what it actually proved was that the bug was
	# still present. Gating on it now would mean keeping the defect to keep the assertion green.
	#
	# The path's REAL coverage, all of it grounded and all of it passing: `test_step_up_grounding.gd`,
	# `test_floor_source_telemetry.gd::_test_auto_step_up_names_try_step`, `test_movement_course.gd`'s
	# four one-tile stairs, and `test_body_acceptance.gd`'s own `step_up_success_rate` over
	# `HostileChamber.LEDGE_START`. Reported here, not asserted, and the gap is named rather than papered
	# over: this scenario's random driver does not currently produce a grounded walk into its own carved
	# ledge, which is worth fixing in the scenario if step-up determinism coverage is wanted back.
	if stepups == 0:
		print("shaft_replay_determinism NOTE: golden run stepped up zero times -- all 11 occurrences " +
			"before D0209 were AIRBORNE, i.e. the defect; grounded step-up is covered by four other suites")
	_check(digs > 0, "the golden scenario actually digs at least once (got %d)" % digs)
	_check_corner_consent(a.summary)


## D0213, and the `_check()` half of it IS an assertion rather than a NOTE, unlike the mantle and step-up
## reports above -- because unlike them it has a witness. This 20,000-tick scenario is the only automated
## thing in the project that poses the ceiling corner nudge at all: measured either side of the gate, it
## produces **corner_unconsented=2, corner_ok=18** with the defect present and **0 and 11** with it fixed.
## The fast fuzzer cannot stand in for it -- over 50,000 ticks of `HostileChamber` it fires
## `corner_corrected_this_tick` **zero** times, so its own green on this class is vacuous
## (`fixture_body_fuzz_probe.gd`'s header carries that isolation).
##
## `corner_ok` is REPORTED, not asserted, and the asymmetry is deliberate. `unconsented == 0` alone would
## also pass on a build where the mechanic had been deleted outright -- the wrong fix, and exactly what a
## grounded gate here would produce -- so something has to hold the other side. But this scenario's world
## comes from `ShaftGenerator`, and D0167/D0168 already measured that its `ValueNoise` differs between
## macOS and CI's Linux; a platform whose generated shaft simply has no reachable corner would go red for
## a reason that is not a regression. The pairing is carried instead by `tests/test_corner_consent.gd`,
## which builds its own grid from constants and so means the same thing on every platform.
func _check_corner_consent(summary: String) -> void:
	var ok: int = -1
	var unconsented: int = -1
	for field: String in summary.split(" "):
		if field.begins_with("corner_ok="): ok = int(field.trim_prefix("corner_ok="))
		elif field.begins_with("corner_unconsented="): unconsented = int(field.trim_prefix("corner_unconsented="))
	_check(unconsented == 0,
		"no corner nudge moved the body in a direction it had no velocity for (got %d, was 2 before D0213)" % unconsented)
	print("shaft_replay_determinism NOTE: corner_ok=%d on this platform (D0213: 11 locally, 18 before the " % ok +
		"gate; the deletion-proofing pair lives in test_corner_consent.gd, which is platform-independent)")
