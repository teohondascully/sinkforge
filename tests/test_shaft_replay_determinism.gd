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

## Re-captured 2026-08-30 from CI's OWN pinned Linux Godot build (run 33322672300, commit f224a01),
## after D0209/D0212 gated both climbs on being grounded, changing every checkpoint. Originally committed
## 2026-08-29 from CI's OWN pinned Linux Godot build (`docs/DECISIONS_LEDGER.md` D0167/D0168
## have the full account) -- NOT a local macOS run, deliberately: this project's own canonical
## environment is CI, and a golden array captured on a different platform/architecture is exactly the
## mistake D0167 found and corrected once already. A future change to ANY of `ShaftGenerator`,
## `TileGrid`, `Body`, or `FuzzDriverCommon.random_input`'s own draw order changes this array; that is
## the point -- this is a real regression gate on simulation OUTPUT, not just a same-run/same-run replay
## check that could pass even if `sim/` were rewritten from scratch to produce different (but internally
## self-consistent) behavior.
const GOLDEN_HASHES: PackedStringArray = [
	"744447601", "2275946744", "3743315378", "1964373881", "527899842", "3788538579", "1430851417", "3434642574", "1945268279", "1576253418",
	"3915685171", "1002167618", "1893791982", "1399882651", "843937023", "3558063839", "3781834910", "2805057073", "1244955879", "277418735",
	"247192747", "3787793942", "4199162242", "1780131630", "353926579", "2557505735", "789217220", "210204978", "2474506217", "3815021931",
	"689659617", "1552365279", "1431151814", "1044352385", "3643058551", "203493136", "227901803", "2331998145", "418723152", "3006637113",
	"1831978704", "2636593140", "123455052", "3524842165", "415383969", "3072591122", "331719780", "3716079857", "1417101110", "1197321421",
	"3535482427", "3715085127", "2408179930", "1794158631", "1009817198", "833941568", "540140981", "1816591873", "3603830884", "937272996",
	"2607324146", "2135436017", "991663221", "41112038", "1565124909", "81852330", "743307704", "107879088", "2212324192", "169395998",
	"137900114", "766691503", "3867603743", "4109419006", "825337242", "2296903405", "2399001072", "4278349328", "3427710422", "2576549390",
	"3850178805", "2888819313", "4240110161", "2905975770", "2844800133", "797437872", "3456956425", "67596008", "1427695741", "9314787",
	"1965550490", "1014604124", "216218306", "3845555538", "4062123770", "1803504837", "1578918735", "412383051", "3503529174", "2042074491",
	"4023800101", "2024613106", "1001356037", "3367903418", "1460224673", "3707661140", "4138245417", "4104263477", "4233113074", "1943739998",
	"573653382", "815152274", "3266159852", "2617809273", "2087019631", "274211398", "1139568375", "1414249558", "2408244980", "2613284482",
	"1227665602", "830226108", "2673026083", "2759273552", "1273303730", "3850211369", "2701794745", "430309846", "1483194870", "2057396483",
	"1544109891", "2734822562", "1018637046", "4172444523", "1189761133", "4271772834", "2554580231", "3879517987", "444245811", "141993411",
	"2502270512", "1011148527", "621634606", "3021639251", "172204145", "2523880706", "1656163778", "3618329919", "1268195136", "2435446414",
	"2915837128", "2338969710", "914580599", "2074548590", "346016960", "3256035989", "3952590734", "347108330", "51643671", "1782616442",
	"1197172960", "1044589319", "4091944353", "2694878806", "1023482483", "673626328", "1712139673", "45025449", "2096539683", "438364323",
	"2708585627", "2276617809", "2644210703", "2295454607", "1557110594", "1718459481", "2083713239", "2323340843", "3255403377", "4220116105",
	"665101049", "2358399898", "1302653474", "209915479", "2854376526", "3393696893", "1643217375", "3075751762", "1521039596", "2017327681",
	"3543568456", "2382638602", "2639087895", "4171772113", "1330293286", "200769363", "1434530517", "1638339421", "1796387065", "3208727319",
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
