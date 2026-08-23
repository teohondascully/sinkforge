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
## THE EXEMPTIONS ARE A RATCHET AND NOT A LIST OF EXCUSES. Three layers are named below because they
## hand-roll their comparisons AND their diagnostics and call `_check()` nowhere, so there is no shared
## tail in them to move; converting them is assertion rewriting. The list may only ever shrink: an
## exemption whose layer has since become compliant is a RED here, not a quiet no-op, because a stale
## exemption is how a permission granted once becomes permanent.
##
##   godot --headless --script res://tools/check_verdict_route.gd

const SCAN_ROOT: String = "res://tools/"

## The two triple-quote spellings, as constants rather than as literals in the scanner below, because a
## literal `"""` inside the function that strips `"""` blocks is a hall of mirrors for the next reader.
const TRIPLE_D: String = '"""'
const TRIPLE_S: String = "'''"

## The layers that may still exit 0 by hand, each with the reason it cannot be converted. SHRINK-ONLY:
## see `_ratchet()`. Converting one of these means deleting its row here in the same commit.
const EXEMPT: Dictionary = {
	"check_frametime.gd":
		"calls neither _check() nor _verdict(); every phase is a hand-rolled comparison with its own"
		+ " multi-line diagnostic, and the SLO's two terms are printed at the site",
	"check_opening.gd":
		"same shape: the dead-tile fraction is compared inline and the failure explains which of three"
		+ " different things went wrong, in its own words",
	"check_underground.gd":
		"same shape, and it additionally distinguishes a FIXTURE that could not reach the rock from a"
		+ " verdict on the rock, which _check()'s one-line labels cannot carry",
}

## A scan that read nothing is not a clean tree. Near the real count (89 on 2026-08-23) so it notices the
## directory thinning, not only vanishing.
const MIN_POPULATION: int = 80

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

	var pop: Array[String] = []
	var offenders: Array[String] = []
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

	_ratchet(pop)
	_verdict("check_verdict_route",
		"%d inheritors, %d permitted to exit 0 by hand and every one of them still needs to"
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
