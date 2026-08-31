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
	"150657453", "2221957652", "510626638", "3241288213", "868471486", "1711324207", "2869815957", "2348561834", "3722518899", "2431519558",
	"2703277839", "3675531614", "329767274", "2624101943", "587646491", "913244187", "2458051642", "1550779981", "2599821155", "3793830667",
	"4290588903", "818184114", "1602386846", "3575536074", "2265953327", "2580092611", "2695567147", "712141017", "1094177712", "164058258",
	"4115476621", "3285681943", "3492393699", "408699551", "2624504562", "2287285323", "1486628154", "1966435996", "103740223", "1372438575",
	"2266287880", "645458407", "1830444387", "2815555340", "2862652147", "1554462068", "3907462965", "758700297", "967895641", "303140552",
	"3374018373", "4155025115", "2355690393", "3858057305", "3081473632", "1186858421", "484005157", "2275214218", "2586977910", "3112096260",
	"1422526307", "1986510846", "3305914577", "816883071", "283549971", "1535780285", "651972868", "2029056206", "504751842", "652829102",
	"964717949", "1249252485", "947048743", "2082896518", "1325855656", "1462522895", "1543429560", "515750704", "2543434247", "582341458",
	"3598028521", "95370462", "3533508535", "3649188422", "3389115809", "4098790132", "1745797472", "2552962187", "1936624859", "484004872",
	"4102043179", "3114140836", "3261847222", "3426703533", "2860780830", "366203810", "1892020565", "4229314544", "57239148", "742612762",
	"3806599122", "2715556973", "4042791359", "3317050754", "2653843399", "36405614", "4050106536", "1428474189", "2550121167", "816110161",
	"3280810784", "468325665", "1747722309", "661807452", "2469638089", "1577021836", "3645654694", "759536928", "53423931", "511799675",
	"1762364459", "3952863940", "2566762964", "3958807304", "4188148647", "3906149397", "987088855", "1583841861", "1717978615", "392442876",
	"2829922982", "185981378", "3849588992", "954988224", "1466463903", "3473222087", "1588361546", "3960109144", "1107586624", "2817937464",
	"1625648660", "127357517", "577312727", "919789954", "3738364203", "3457544020", "2888022520", "876175028", "3250317541", "816322397",
	"2379889569", "2135311582", "3262473045", "3055571017", "1360176115", "651608724", "754562498", "1856928592", "99281845", "1814332271",
	"899081221", "3111085848", "3587253579", "2332072640", "1972536562", "2074040953", "2027149378", "3789034535", "2975116880", "2832041703",
	"1289469752", "450820214", "508470025", "2883799493", "2656846025", "1100345600", "2837830496", "1753158580", "799530263", "116211738",
	"13171", "1013919060", "997280036", "247620459", "2327868902", "3904603967", "1359522364", "3953177482", "3194093537", "2651913321",
	"1664216401", "1159202413", "612325792", "2049958133", "1987983021", "1732150784", "1689122592", "2083501939", "2500057135", "3551563731"
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
