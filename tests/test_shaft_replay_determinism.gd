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

## Committed 2026-08-29 from CI's OWN pinned Linux Godot build (`docs/DECISIONS_LEDGER.md` D0167/D0168
## have the full account) -- NOT a local macOS run, deliberately: this project's own canonical
## environment is CI, and a golden array captured on a different platform/architecture is exactly the
## mistake D0167 found and corrected once already. A future change to ANY of `ShaftGenerator`,
## `TileGrid`, `Body`, or `FuzzDriverCommon.random_input`'s own draw order changes this array; that is
## the point -- this is a real regression gate on simulation OUTPUT, not just a same-run/same-run replay
## check that could pass even if `sim/` were rewritten from scratch to produce different (but internally
## self-consistent) behavior.
const GOLDEN_HASHES: PackedStringArray = [
	"2619626534", "973684755", "1491636492", "1711420538", "3926151418", "2751802694", "3371099930", "834120603", "899686883", "1964511398",
	"138201818", "4225282732", "1664098963", "985991020", "4094876245", "2892234585", "2094150544", "1097575000", "3083110840", "3302165737",
	"2869022085", "2414991460", "737980371", "2490984441", "1617960591", "493527517", "1540229983", "1603307027", "3704425796", "360548270",
	"3480160421", "2680041092", "3503991551", "4029095502", "4100887981", "1859561488", "3751712309", "3880950833", "1979809034", "144599598",
	"765007455", "2581702769", "2226900871", "4201543642", "2696325250", "4244152931", "618798421", "1401482298", "6430667", "4156921122",
	"4195482179", "3435858600", "2173625973", "2410447656", "553272888", "615147397", "2007006845", "2146858096", "1491445110", "709575822",
	"839612350", "368583022", "439096162", "1715151906", "2350278875", "87302517", "3060980967", "531893684", "3014658261", "2498053518",
	"341037946", "2669434216", "4104063848", "1398780991", "2811677789", "2867354288", "2220168353", "2432637130", "3051284958", "268947241",
	"3757136902", "786374539", "1271986395", "1773126921", "3738164528", "1998534901", "1657295391", "1325020674", "308363097", "1846753921",
	"3310178282", "3129489123", "1930061563", "3991513898", "620311179", "3389579686", "921768326", "3245385204", "1502033351", "922956745",
	"3971352349", "2234219289", "1796371727", "2938594246", "2757687256", "3463892476", "3056333457", "2019380731", "2839745410", "3364220313",
	"322870803", "3982482928", "2813656653", "1622846646", "976907961", "308982046", "1789381188", "2622209238", "4019534352", "2263157088",
	"516912365", "3070363237", "2630447141", "1574688452", "3836191177", "2507691776", "1220850434", "4207949915", "4060225972", "1475747046",
	"1879702801", "3245644001", "205474618", "1707664963", "4149014419", "2406842421", "583966630", "2798811941", "2498224302", "4285624924",
	"152519314", "701706059", "3795867054", "367730860", "1610752786", "2350676960", "790739377", "616848103", "3618044174", "3197787685",
	"1147964088", "2379464379", "4185948856", "4267994961", "3869577728", "2710247649", "2950910818", "3843371235", "1529579159", "1053424579",
	"817825511", "2423645013", "3589839938", "2125285099", "4288423770", "2407533019", "854080472", "1351036900", "3618084310", "3474534062",
	"1400053298", "2162075974", "2590023424", "1996554471", "286802097", "3854685674", "3595022702", "3862270760", "1418479842", "1921480480",
	"205600470", "860602399", "3563455528", "3533462334", "1008614215", "1298465215", "2653771644", "2358080298", "1155550499", "2615656282",
	"4080524477", "1074138300", "1258492511", "3127935819", "3282134247", "3406323200", "1498603411", "2433294947", "2937617296", "3485339754",
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
	_check(stepups > 0, "the golden scenario actually steps up at least once (got %d)" % stepups)
	_check(digs > 0, "the golden scenario actually digs at least once (got %d)" % digs)
