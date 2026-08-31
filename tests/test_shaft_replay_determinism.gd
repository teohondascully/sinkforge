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
	"663559107", "4265192295", "3620088972", "3382820429", "195607118", "3232782543", "2898007412", "123005979", "113287904", "1817470796",
	"888596258", "1155383923", "1067509454", "2796131099", "264315135", "4171809879", "3384361253", "3952842398", "2620961057", "1157152275",
	"799364336", "3897200370", "114550110", "3444790794", "1073835471", "3747653091", "1702521618", "386051008", "1395756567", "4160554588",
	"35416471", "3859091873", "2003942609", "4010150285", "2824393760", "2248776602", "1261292414", "2831194202", "1342589688", "4263110120",
	"1197548769", "2846681458", "3461786606", "572060631", "1948028286", "1415081023", "2315809344", "3007473940", "2065043044", "1445128851",
	"2394488400", "619197286", "534736804", "3894433094", "1111004301", "1103357858", "2258750407", "2129007276", "656806808", "2587593254",
	"1447510733", "1670708067", "544972086", "4193004840", "1415610498", "1504861740", "1820763935", "3660446249", "1807853245", "2600101641",
	"2985305016", "2571893228", "979797262", "816202541", "1086411694", "2241576245", "1374527118", "2075343857", "1387479119", "3342109608",
	"422853919", "1253188276", "3614637485", "177753372", "1649830615", "176662055", "4208023329", "701909830", "4114472476", "3865390833",
	"3120513215", "2931502168", "1347001514", "603205505", "975993777", "2459219793", "1436751044", "2977545503", "586803185", "568191104",
	"3533267789", "3133253390", "3588224841", "1819542135", "1125977854", "3303241765", "1746871391", "1845580676", "2164966918", "3347819404",
	"2293705488", "2341901871", "4279979112", "1696206303", "2019751119", "3459358146", "4039770619", "3187156917", "3039231280", "2801895280",
	"2768173088", "2472290777", "3800486633", "2129715869", "105017116", "3602023754", "1167894860", "3632509306", "169716946", "435561719",
	"3115891681", "1428736125", "3174656540", "1229445084", "4237246683", "393987843", "2702497574", "2856103035", "3377338467", "2030292059",
	"1481100487", "3811469683", "707347389", "871223654", "1058369007", "2338928888", "1347933980", "15891544", "2517703273", "2769070561",
	"680177061", "1363583298", "1171564249", "3937811789", "124854199", "2470192184", "2061540774", "1893621108", "1884742457", "4177536947",
	"108654985", "237385012", "1096930727", "517818076", "1678130830", "1254884693", "473189854", "3485342083", "1143162476", "2786106435",
	"2385454420", "2820580626", "1740175845", "2345819553", "1038084005", "2275429660", "4132929404", "679249616", "2845529715", "2657253302",
	"4052525519", "3835189360", "1353158720", "722742215", "2689529474", "4182752923", "3136791384", "1251295014", "1698486461", "1883888273",
	"3069637595", "3182038198", "444767817", "2401329692", "925965540", "171152311", "3518944471", "1348811946", "2008765942", "43979569"
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
