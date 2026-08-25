extends "res://tools/check_base.gd"

## A LAYER MAY NOT EXIT 0 ON ITS OWN.
##
## `check_base.gd` refuses a green that asserted nothing: `_verdict()` sees `_passes == 0 and
## _failures == 0` and exits 1 saying so. That refusal is the only thing standing between the suite and a
## layer that reaches the end of a run having tested nothing — and it protects exactly the layers that
## route their exit through it. A layer writing its own
##
##     if _failures == 0:
##         print("THING OK")
##         quit(0)
##
## has opted out of it, and opted out invisibly: both shapes are exit 0 over a log with no FAIL line.
##
## HOW BIG THAT WAS, MEASURED RATHER THAN FEARED. On 2026-08-22, with `_check` overridden to record
## nothing — assertions still running, none of them counted — the 55 layers that hand-rolled their tail
## returned `55 PASS / 0 FAIL / 0 SKIP`. Fifty-five registered layers exited 0, reported green by the
## runner and quotable in a summary, having tested nothing at all. Nothing in the suite noticed, because
## nothing in the suite was looking: the rule lived in CONTRIBUTING.md's layer template and in the base
## class's own docstring, and a rule with no runner is a preference.
##
## THIS IS THE RUNNER FOR IT. The property is deliberately narrow — not "call `_verdict()`", which a layer
## could do while also quitting 0 somewhere else, but "do not exit 0 yourself", which is the thing that
## actually bypasses the guard. `quit(1)`, `quit(SKIP)` and `_void_layer()` are all left alone: a false red
## is loud and a skip is already accounted for by `tools/stand_downs.txt`.
##
## A BARE `quit()` IS `quit(0)`. Godot's default exit code is 0, so `quit()` opts out in exactly the same
## way while looking like it says nothing about the result. Both spellings are the subject.
##
## THE EXEMPTIONS ARE A RATCHET AND NOT A LIST OF EXCUSES. The list is EMPTY. Three layers were named
## below -- check_frametime, check_opening, check_underground -- on the grounds that they hand-roll their
## comparisons AND their diagnostics, so there was no shared tail in them to move; all three were then
## converted anyway, by recording each decision with `_check()` beside the sentence rather than instead of
## it. `EXEMPT` below carries that account in full. The list may only ever shrink: an exemption whose
## layer has since become compliant is a RED here, not a quiet no-op, because a stale exemption is how a
## permission granted once becomes permanent -- and that is not hypothetical, because the ratchet fired on
## all three the moment they complied, which is why there is nothing left here to name.
##
##   godot --headless --script res://tools/check_verdict_route.gd

const SCAN_ROOT: String = "res://tools/"

## The two triple-quote spellings, as constants rather than as literals in the scanner below, because a
## literal `"""` inside the function that strips `"""` blocks is a hall of mirrors for the next reader.
const TRIPLE_D: String = '"""'
const TRIPLE_S: String = "'''"

## The layers that may still exit 0 by hand, each with the reason it cannot be converted. SHRINK-ONLY:
## see `_ratchet()`. Converting one of these means deleting its row here in the same commit.
##
## IT IS EMPTY, AND IT WAS NOT WHEN THIS FILE WAS WRITTEN A FEW HOURS EARLIER.
##
## Three layers were named here — check_frametime, check_opening and check_underground — because they call
## `_check()` nowhere and their failures say more than a one-line label can carry: check_underground
## distinguishes a fixture that could not reach the rock from a verdict on the rock. All three are now
## converted, by recording each decision with `_check()` *beside* the sentence rather than instead of it,
## so nothing about their judgement or their diagnostics moved. The ratchet below is what asked: it went
## red on all three the moment they became compliant, saying "tighten the list the day it does not", and
## this is that day.
##
## KEPT RATHER THAN DELETED WITH THE ROWS. A gate that cannot express an exemption gets one anyway, in the
## form of somebody quietly not registering their layer. What must not be cheap is ADDING a row: it takes
## a sentence a reader can check, and the ratchet re-reads it on every run afterwards.
const EXEMPT: Dictionary = {}

## A scan that read nothing is not a clean tree. Near the real count (89 on 2026-08-23) so it notices the
## directory thinning, not only vanishing.
const MIN_POPULATION: int = 80

## THE SECOND RULE, AND IT IS THE SAME DEFECT WEARING THE OTHER GLOVE. A layer may not move `_passes` or
## `_failures` itself.
##
## `_check(false, label)` is exactly `_failures += 1` followed by `printerr("  FAIL: %s")`, and six layers
## had written that pair out by hand at a fixture-bail: check_aim, check_plunge, check_pump, check_teaching,
## check_water_reads, check_wrap. Byte-identical output, so nothing in any log could tell them apart. They
## were harmless as written — the counter really was incremented — and that is the point: the danger is not
## the six sites, it is that the counter is reachable at all. `_passes += 1` at a fixture-bail would be the
## same keystrokes and would manufacture the assertion count that `_verdict()`'s refusal keys on, turning
## the one guard against a layer that stopped judging into a number the layer supplies itself.
##
## READS ARE FINE and are left alone. `if _failures > 0:` in check_item_reads decides whether a headless
## run reports a failure or a skip, which is a real decision that needs the count.
const COUNTER_WRITE: String = "(_passes|_failures)\\s*(\\+=|-=|\\*=|/=|=[^=])"

## The positive control for it: a hand-rolled failed assertion.
const CONTROL_COUNTER: String = """
func _run() -> void:
	if not _ready_to_judge():
		_failures += 1
		printerr("  FAIL: nothing to judge")
		return
"""

## ...and the read that must stay allowed, so the rule is about writing and not about the name.
const CONTROL_COUNTER_READ: String = """
func _run() -> void:
	if _failures > 0:
		printerr("  the pixel half could not run, and the half that could run failed")
		return
	_verdict("check_thing", "the thing holds")
"""

## The detector's own positive control: a hand-rolled green.
const CONTROL_BAD: String = """
func _initialize() -> void:
	_check(true, "a thing")
	if _failures == 0:
		print("THING OK")
		quit(0)
"""

## ...its negative twin, identical but routed through the base class.
const CONTROL_GOOD: String = """
func _initialize() -> void:
	_check(true, "a thing")
	_verdict("check_thing", "the thing holds")
"""

## A bare `quit()`, which is `quit(0)` wearing a different face.
const CONTROL_BARE: String = """
func _initialize() -> void:
	_check(true, "a thing")
	quit()
"""

## AND THE CONTROL THAT KEEPS THIS GATE FROM BEING THE THING IT IS AUDITING. `quit(0)` appears in comments
## across this suite — in `check_item_reads`, in `check_row_identity`, and four times in the file you are
## reading — because the exit protocol is a thing people write ABOUT. A detector that matched raw text
## would flag every one of them, which is a confident wrong red, and the fix for that (a per-file
## exemption) would have quietly widened the permission list. Strip comments first, and prove it here.
const CONTROL_COMMENTED: String = """
func _initialize() -> void:
	# the old version used to quit(0) here, which is what this comment is about
	_check(true, "a thing")
	_verdict("check_thing", "the thing holds")
"""

## ...and its twin, so a stripper that ate the whole line would fail too: the code is on the SAME line as
## a trailing comment mentioning nothing relevant.
const CONTROL_TRAILING: String = """
func _initialize() -> void:
	_check(true, "a thing")
	quit(0)   # a trailing comment
"""

## AND A CONTROL FOR THE OTHER HALF OF THE STRIPPER, which this gate needed the moment it flagged its own
## control constants. A `quit(0)` inside a string is inert, whatever kind of quotes hold it.
const CONTROL_IN_STRING: String = """
func _initialize() -> void:
	_check(true, "the words quit(0) inside a plain string")
	_verdict("check_thing", "the thing holds")
"""


func _initialize() -> void:
	_check(_exits_zero(CONTROL_BAD), "the detector flags a hand-rolled `quit(0)` green (positive control)")
	_check(not _exits_zero(CONTROL_GOOD), "...and stays quiet on the same layer once it calls _verdict()")
	_check(_exits_zero(CONTROL_BARE), "...and flags a bare `quit()`, which is exit 0 by another spelling")
	_check(not _exits_zero(CONTROL_COMMENTED),
		"...and does not flag a `quit(0)` that is only ever mentioned in a comment")
	_check(_exits_zero(CONTROL_TRAILING),
		"...and still flags one that shares its line with a trailing comment")
	_check(not _exits_zero(CONTROL_IN_STRING),
		"...and does not flag a `quit(0)` that only ever appears inside a string literal")
	_check(_writes_counter(CONTROL_COUNTER),
		"the detector flags a layer moving _failures itself (positive control)")
	_check(not _writes_counter(CONTROL_COUNTER_READ),
		"...and leaves a layer that only READS the counter alone")

	var pop: Array[String] = []
	var offenders: Array[String] = []
	var counter_writers: Array[String] = []
	var unreadable: Array[String] = []
	var dir := DirAccess.open(SCAN_ROOT)
	if dir == null:
		_check(false, "the tools directory opens, so this gate has something to scan")
		_verdict("check_verdict_route")
		return
	for f: String in dir.get_files():
		if not f.begins_with("check_") or not f.ends_with(".gd"):
			continue
		var src: String = FileAccess.get_file_as_string(SCAN_ROOT + f)
		if src.is_empty():
			unreadable.append(f)
			continue
		# The population is the INHERITORS. A layer extending SceneTree has no base-class guard to bypass,
		# so the rule does not apply to it and counting it would be a different claim.
		if not src.begins_with('extends "res://tools/check_base.gd"'):
			continue
		pop.append(f)
		if _exits_zero(src) and not EXEMPT.has(f):
			offenders.append(f)
		if _writes_counter(src):
			counter_writers.append(f)

	_check(unreadable.is_empty(), "every check_*.gd in %s could be read (%d unreadable)"
		% [SCAN_ROOT, unreadable.size()])
	for u: String in unreadable:
		printerr("    unreadable: %s" % u)
	_check(pop.size() >= MIN_POPULATION,
		"the scan actually read the inheritors (%d, floor %d)" % [pop.size(), MIN_POPULATION])
	_check(offenders.is_empty(),
		"no layer reaches exit 0 without going through _verdict() (%d scanned, %d exempt)"
		% [pop.size(), EXEMPT.size()])
	for o: String in offenders:
		printerr("    %s exits 0 by hand — route it through _verdict(), or add it to EXEMPT with a"
			% o + " reason a reader can check")
	_check(counter_writers.is_empty(),
		"no layer moves _passes or _failures itself (%d scanned)" % pop.size())
	for c: String in counter_writers:
		printerr("    %s writes an assertion counter directly — say it with _check(cond, label), which is"
			% c + " the same two statements and goes through the one place that counts them")

	_ratchet(pop)
	_verdict("check_verdict_route",
		"%d inheritors, none of them exiting 0 without _verdict()" % pop.size() if EXEMPT.is_empty()
		else "%d inheritors, %d permitted to exit 0 by hand and every one of them still needs to"
			% [pop.size(), EXEMPT.size()])


## THE LIST MAY ONLY SHRINK. An exemption for a layer that no longer exits 0 by hand is not harmless: it
## is a standing permission nobody is using and nobody will notice being used again. An exemption naming a
## file that is no longer in the population at all is worse, because it reads as coverage of something
## that is not there.
func _ratchet(pop: Array[String]) -> void:
	for f: String in EXEMPT:
		if not pop.has(f):
			_check(false, "EXEMPT names %s, which is not an inheritor in %s any more — delete the row"
				% [f, SCAN_ROOT])
			continue
		var src: String = FileAccess.get_file_as_string(SCAN_ROOT + f)
		_check(_exits_zero(src),
			"%s still needs its exemption (it still exits 0 by hand); tighten the list the day it does not"
			% f)


## Does this source exit 0 under its own power? `quit(0)` or a bare `quit()`, in code rather than in prose.
func _exits_zero(src: String) -> bool:
	var code: String = _strip_comments(src)
	return code.contains("quit(0)") or code.contains("quit()")


## Does this source assign to an assertion counter? Comments and strings stripped for the same reason as
## above: `_failures += 1` is written ABOUT in this suite as often as it used to be written.
func _writes_counter(src: String) -> bool:
	var re := RegEx.create_from_string(COUNTER_WRITE)
	return re.search(_strip_comments(src)) != null


## Everything from an unquoted `#` to the end of its line, removed, and every string literal replaced by
## nothing.
##
## TWO REASONS, AND THE SECOND WAS FOUND BY THIS GATE FLAGGING ITSELF ON ITS FIRST RUN. Comments have to
## go because `quit(0)` is a thing people write ABOUT: it appears in prose in check_item_reads, in
## check_row_identity and several times in the file you are reading, and a detector matching raw text
## would answer every one of them with a confident wrong red. Strings have to go for the same reason one
## level in: this gate's own controls are triple-quoted blocks containing exactly the shape it hunts, and
## on its first run it reported ITSELF as an offender. The alternative on offer was a per-file exemption
## for the detector, which would have widened the permission list to hide a defect in the detector — the
## trade this whole file exists to refuse.
##
## The naive version of the string rule is worse than none: truncating at a `#` inside a string DELETES
## code the scan was supposed to read, and that fails silent-and-green.
func _strip_comments(src: String) -> String:
	var out: String = ""
	var i: int = 0
	while i < src.length():
		var three: String = src.substr(i, 3)
		if three == TRIPLE_D or three == TRIPLE_S:
			var close: int = src.find(three, i + 3)
			# An unterminated block runs to the end of a file that would not parse anyway. Drop the rest
			# rather than falling through and reading the block as code.
			i = src.length() if close == -1 else close + 3
			continue
		var c: String = src[i]
		if c == "\"" or c == "'":
			var j: int = i + 1
			while j < src.length() and src[j] != c and src[j] != "\n":
				j += 2 if src[j] == "\\" else 1
			i = j + 1
			continue
		if c == "#":
			while i < src.length() and src[i] != "\n":
				i += 1
			continue
		out += c
		i += 1
	return out
