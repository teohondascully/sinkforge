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
## Proof this actually tests `sim/`, unlike the stub: moving `sim/` aside and re-running this test turns
## it red (a Parse Error on `ShaftGenerator`/`TileGrid`/`Body`/`FuzzDriverCommon`, all real `sim/`-rooted
## classes this fixture calls directly) -- verified directly, not assumed, `docs/DECISIONS_LEDGER.md`
## D0165 has the exact command and its output. Re-running `test_replay_determinism.gd` the same way
## (`sim/` moved aside) stays GREEN, confirmed the same way -- the stub genuinely never touches `sim/` at
## all, which is exactly the contrast this queue asked this file to prove, not just claim.

const FIXED_SEED: int = 20260826
const EXPECTED_CHECKPOINTS: int = 200

## Committed 2026-08-29 from a real run of `tests/fixture_shaft_replay_probe.gd` at `FIXED_SEED` --
## `docs/DECISIONS_LEDGER.md` D0165 has the exact command. A future change to ANY of `ShaftGenerator`,
## `TileGrid`, `Body`, or `FuzzDriverCommon.random_input`'s own draw order changes this array; that is
## the point -- this is a real regression gate on simulation OUTPUT, not just a same-run/same-run replay
## check that could pass even if `sim/` were rewritten from scratch to produce different (but internally
## self-consistent) behavior.
const GOLDEN_HASHES: PackedStringArray = [
	"237606446", "1962317441", "359333107", "3196929188", "3186861646", "3343844635", "455634360", "1836568953", "2310313875", "1803024431",
	"1163790915", "3294679085", "1343104123", "4175152565", "3290177561", "1087868151", "2369223973", "2577769708", "2974971295", "118577949",
	"2656225865", "2673754849", "3190116668", "487232002", "3103071504", "4128245079", "392227823", "3594897938", "1383795860", "1695630209",
	"572119541", "2461087939", "2726545707", "3212309690", "3863606219", "1675038394", "2870085773", "2227557883", "2539917947", "4042161698",
	"1290170778", "1755624897", "2631474847", "251239304", "32420850", "2231367750", "128874578", "4059305909", "2327872805", "219258881",
	"1521116495", "2693501119", "599344184", "909211284", "3686349572", "2130897352", "2482933757", "3582650046", "605886838", "2014882807",
	"3998248917", "4070040979", "1302957820", "4191737162", "3455691412", "2201910721", "3533888674", "4237138131", "2259954012", "3458635073",
	"1763356763", "4087801234", "630241523", "279577739", "1577762481", "3011138124", "3213113608", "3286108391", "2026355598", "4235420883",
	"381470258", "1154377523", "4254104049", "2034371641", "723547449", "1662684647", "154078707", "3039317017", "1849470369", "3955767739",
	"3250461305", "2626997882", "1246825112", "2710563245", "1553149163", "2455323147", "2690380226", "3107914230", "168516804", "3796643850",
	"301392989", "171716917", "1066191467", "1343937240", "1834599621", "595151041", "3269655417", "3101341607", "2945088012", "56495734",
	"2346353161", "916188224", "556075249", "2822587386", "2933888040", "1314222493", "3931224035", "677968040", "280932514", "3819269806",
	"1235484391", "412947764", "1984256345", "3806806339", "4211669236", "2094598919", "225888058", "3598291807", "1132292549", "3883656511",
	"2413921646", "1603819739", "112258840", "1431923744", "3730211240", "1392176056", "1469912395", "928206248", "3015858258", "2783729522",
	"1094532664", "1009738090", "1036650201", "1568510223", "1102476903", "512018664", "1174979590", "1156672941", "3706135253", "3120116382",
	"4240287003", "140925", "2284493685", "1192324459", "3938616288", "1150442292", "2668172829", "302843550", "3879372902", "3240101187",
	"2479150606", "3938649800", "3499371726", "3022029231", "3975131520", "3010026806", "3149045990", "3032453830", "3554954541", "3057519776",
	"3332811668", "3751442745", "3933462392", "3573879787", "3605724583", "3899617167", "2048612418", "3853284793", "693596385", "3014301820",
	"1314680535", "1112220237", "3808895302", "3853734024", "179177299", "3657739879", "937741015", "1595897196", "1291434685", "2045792405",
	"2250592942", "3692760762", "1182865279", "1452151833", "2649136413", "2102592839", "1113164599", "47472275", "2799695532", "2921611773",
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
	_check(mismatch_at == -1,
		("checkpoint hashes exactly match the committed golden sequence (first mismatch at checkpoint %d) " +
		"-- a real simulation-code regression changes this; deleting sim/ entirely fails this test to " +
		"parse, not just to match (docs/DECISIONS_LEDGER.md D0165)") % mismatch_at)


## The stub's own `_test_stub_state_actually_varies` proves its trivial state isn't frozen; this is that
## same principle applied to the three named actions this queue asked this scenario to actually exercise
## -- a scenario that never once mantles, steps up, or digs would make every check above pass vacuously
## on a body that only ever falls or stands still.
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
	_check(mantles > 0, "the golden scenario actually mantles at least once (got %d)" % mantles)
	_check(stepups > 0, "the golden scenario actually steps up at least once (got %d)" % stepups)
	_check(digs > 0, "the golden scenario actually digs at least once (got %d)" % digs)
