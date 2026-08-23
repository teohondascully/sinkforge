extends "res://tools/check_base.gd"

## A verdict may not claim what no assertion tested.
##
## `check_vacuous_assertions` already refuses two shapes of green-that-means-nothing: a bound outside the
## range the expression can produce, and an error path returning the value the assertion wants. This is a
## third, and it is worse than either for one specific reason.
##
## A and B produce a `PASS:` line, which is one of many and which a reader can go and check. This produces
## the SUMMARY sentence, and a summary is the thing that gets quoted into a commit message, a document or
## a status report by somebody who never opens the layer. The instance that prompted this read:
##
##     check_seam_flood: PASS — spatial hash and quadratic scan agree, and the hash is faster
##
## The file timed both arms into `fast_ms` and `slow_ms`, computed `speedup`, and declared `MIN_SPEEDUP`.
## Nothing compared any of them. The layer would have printed "the hash is faster" with the hash ten times
## slower, and under a parallel run it would have printed it while the number it declined to check was
## measuring the other eleven jobs.
##
## THE PREDICATE IS COMPARISONS, NOT ASSERTION HELPERS, AND THAT IS THE WHOLE DESIGN.
##
## The obvious version looks for the claim in a `_verdict()` note and the evidence in a `_check()` call.
## Both halves were wrong here, and one of them still is. When this was written, under a third of the
## layers this gate scans called `_verdict()`, so keying on it would have been blind to most of the tree;
## after the verdict-tail conversion of 2026-08-23 it is 86 of 99 and that half of the objection is gone.
## The `_check()` half never depended on the count: 90 of 99 call it, and the nine that do not are exactly
## where a claim is most likely to hide, because a layer enforcing its floor with `if r >= LAG1_FLOOR:`
## rather than `_check(r >= LAG1_FLOOR)` would be reported as unguarded. Both mistakes were made while
## building this and both scored as coverage.
##
## So: the claim is any string containing `<layer>: PASS`, HOWEVER it is printed, plus any note handed to
## `_verdict()` — see `_verdict_lines()` for why the second reading had to be added and what it cost to
## leave out. The evidence is any comparison operator anywhere in the file with a duration-bearing name on
## either side.
##
## A NAME CARRIES A DURATION ONLY BY WHOLE PART. Substring matching finds `ms` inside items, seams,
## streams and materials; that search returned eight files of pure noise before it was written this way.
##
##   godot --headless --path . --script res://tools/check_verdict_claims.gd

const SCAN_ROOT: String = "res://tools/"

## Names whose parts mean "a length of time". Matched between underscores or at either end, never as a
## substring.
const TIME_PARTS: Array[String] = ["ms", "msec", "usec", "sec", "secs", "seconds",
	"elapsed", "ticks", "duration", "dur", "speedup"]

## Words that assert one thing took less time than another. A verdict using one of these has claimed a
## measurement, whether or not the layer made it.
const SPEED_CLAIMS: Array[String] = ["faster", "slower", "quicker", "cheaper", "speedup",
	"costs less", "cost less", "within budget", "under budget", "no hitch"]

## The layer's own positive control. If the detector cannot flag this, it cannot flag anything, and a
## detector that reports a clean tree because it is broken is the defect it exists to find.
const CONTROL_SRC: String = """
var fast_ms: float = 0.0
var slow_ms: float = 1.0
print("check_control: PASS — the two agree, and the first is faster")
"""

## ...and its negative twin, so a detector that flags everything fails too.
const CONTROL_CLEAN: String = """
var fast_ms: float = 0.0
var slow_ms: float = 1.0
if fast_ms < slow_ms:
	print("check_control: PASS — the two agree, and the first is faster")
"""

## THE SAME CLAIM, MADE THROUGH `_verdict()`, WHICH THIS GATE COULD NOT SEE UNTIL 2026-08-23.
##
## `_verdict(layer, note)` prints `<layer>: PASS (n asserted) — <note>`, and it builds that line inside
## `tools/check_base.gd`. The literal in the layer is the NOTE ALONE, which contains no `: PASS`, so the
## string search below walked straight past it. Measured before the fix: of 89 layers inheriting the base,
## 31 already reached the terminal this way and every claim any of them made was invisible here. The
## comment at the top of this file reasoned about the opposite direction — that keying on `_verdict()`
## would miss the hand-rollers — and shipped the mirror of the bug it was warning about.
##
## The verdict-tail conversion of 2026-08-23 moves 55 more layers onto `_verdict()`, which would have
## taken this gate from blind to a third of the tree to blind to 86 of 89. That is why the fix lands
## first: a gate must be armed for the shape before the shape arrives, or the arrival is what disarms it.
const CONTROL_NOTE: String = """
var fast_ms: float = 0.0
var slow_ms: float = 1.0
_verdict("check_control", "the two agree, and the first is faster")
"""

## ...and ITS negative twin. Note the layer-name argument is a string too: a reader that took every
## literal in the call would treat `check_control` as part of the claim, which is noise rather than a
## claim, so the first argument is skipped by position.
const CONTROL_NOTE_CLEAN: String = """
var fast_ms: float = 0.0
var slow_ms: float = 1.0
if fast_ms < slow_ms:
	_verdict("check_control", "the two agree, and the first is faster")
"""

## AND A THIRD KIND OF WRONG: a claim the detector INVENTED. Two quote characters in a comment, three
## lines apart, with the words `: PASS` and a speed word in the prose between them. There is no literal
## here and no verdict — but a pattern whose negated class forgets the newline reads the whole span as
## one string. Flagged by the version of this file that shipped until 2026-08-23; it must be silent now.
const CONTROL_SPAN: String = """
var fast_ms: float = 0.0
# a comment that opens a quote "here
# and shuts it three lines down, having said : PASS
# and said the word faster" on the way past
"""


func _initialize() -> void:
	var pos: Array[String] = _claims_without_evidence(CONTROL_SRC)
	_check(not pos.is_empty(),
		"the detector flags its own positive control (a speed claim with nothing compared)")
	_check(_claims_without_evidence(CONTROL_CLEAN).is_empty(),
		"...and stays quiet on the same file once a comparison guards it")
	_check(not _claims_without_evidence(CONTROL_NOTE).is_empty(),
		"...and flags the same claim when it is made through _verdict()'s note instead of a print")
	_check(_claims_without_evidence(CONTROL_NOTE_CLEAN).is_empty(),
		"...and stays quiet on THAT one too once a comparison guards it")
	_check(_claims_without_evidence(CONTROL_SPAN).is_empty(),
		"...and does not read a claim out of the prose between two quotes on different lines")

	var scanned: int = 0
	var bad: Array[String] = []
	var dir := DirAccess.open(SCAN_ROOT)
	if dir == null:
		_skip_layer("check_verdict_claims", "%s does not open" % SCAN_ROOT)
		return
	for f: String in dir.get_files():
		if not f.begins_with("check_") or not f.ends_with(".gd"):
			continue
		if f == "check_verdict_claims.gd":
			continue
		var src: String = FileAccess.get_file_as_string(SCAN_ROOT + f)
		if src.is_empty():
			bad.append("%s could not be read" % f)
			continue
		scanned += 1
		for claim: String in _claims_without_evidence(src):
			bad.append("%s — %s" % [f, claim])

	## A scan that read nothing is not a clean tree. The floor is deliberately near the real count so it
	## notices the directory emptying, not just vanishing.
	_check(scanned >= 80, "the scan actually read the suite (%d layers)" % scanned)
	_check(bad.is_empty(),
		"no verdict claims a speed the layer never compared (%d checked)" % scanned)
	for b: String in bad:
		printerr("    %s" % b)

	_verdict("check_verdict_claims", "%d layers, every speed claim backed by a comparison" % scanned)


## The verdict lines of a source, however they reach the terminal — and there are two ways, not one.
##
## A layer either builds the whole line itself, in which case the literal carries `: PASS`, or it hands
## `_verdict()` a note and the base class builds the line around it, in which case the literal carries
## nothing this gate can key on. Both are collected here. Anything that only reads the first shape reports
## a clean tree over the second, which is the failure this file is about, one level up.
## A LITERAL DOES NOT SPAN A LINE, AND UNTIL 2026-08-23 THIS PATTERN THOUGHT IT COULD.
## `[^"\\]*` matches newlines, so between any two quote characters in the file — including two that
## belong to different sentences of a COMMENT — the pattern would happily read the prose in between as one
## string literal. It flagged check_seam_flood on a "claim" assembled from six comment lines, one of which
## contained the words `: PASS` because it was describing this gate. A detector that can invent its subject
## out of the commentary about it is worse than one that misses: the miss is quiet, this is a confident
## wrong red. Excluding the newline costs nothing real, because a GDScript literal cannot contain one.
func _verdict_lines(src: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string("\"([^\"\\\\\\n]*:\\s*PASS[^\"\\\\\\n]*)\"")
	for m: RegExMatch in re.search_all(src):
		out.append(m.get_string(1))
	for note: String in _verdict_notes(src):
		out.append(note)
	return out


## Every `note` argument passed to `_verdict()` in this source, with the concatenation flattened.
##
## NOT A REGEX, AND THE REASON IS WORTH THE TWENTY LINES. A note is frequently wrapped across lines with
## `+`, and it is sometimes built with `%`, so `_verdict\("[^"]*",\s*"([^"]*)"\)` reads the FIRST chunk of
## a wrapped claim and stops — and a claim's verb tends to live at the end of the sentence, which is
## exactly the half it would drop. Scan to the matching parenthesis instead, honouring string literals so
## a bracket inside a note cannot close the call early, and take every literal after the first.
##
## The first literal is the LAYER NAME and is skipped by position. It is not a claim, and `check_faster`
## would otherwise read as one.
func _verdict_notes(src: String) -> Array[String]:
	var out: Array[String] = []
	var at: int = src.find("_verdict(")
	while at != -1:
		var i: int = at + "_verdict(".length()
		var depth: int = 1
		var in_str: bool = false
		var lits: Array[String] = []
		var cur: String = ""
		while i < src.length() and depth > 0:
			var c: String = src[i]
			if in_str:
				if c == "\\":
					i += 2
					continue
				if c == "\"":
					in_str = false
					lits.append(cur)
					cur = ""
				else:
					cur += c
			elif c == "\"":
				in_str = true
			elif c == "(":
				depth += 1
			elif c == ")":
				depth -= 1
			i += 1
		# An unterminated call means the scan ran off the end of the file, which is a broken read rather
		# than a clean one. Say so by reporting nothing FOR THIS CALL and carrying on, so one malformed
		# site cannot silence the rest of the file.
		if depth == 0 and lits.size() > 1:
			out.append(" ".join(lits.slice(1)))
		at = src.find("_verdict(", at + 1)
	return out


## Does any name on either side of a comparison carry a time unit?
func _compares_a_duration(src: String) -> bool:
	var re := RegEx.create_from_string(
		"([A-Za-z_][A-Za-z_0-9]*)\\s*(?:<=|>=|<|>|==|!=)|(?:<=|>=|<|>|==|!=)\\s*([A-Za-z_][A-Za-z_0-9]*)")
	for m: RegExMatch in re.search_all(src):
		for g: int in [1, 2]:
			var name: String = m.get_string(g)
			if name != "" and _is_duration(name):
				return true
	return false


## Does the source compute a duration at all? A layer that never times anything cannot be accused of
## failing to check a timing.
func _measures_a_duration(src: String) -> bool:
	if src.contains("get_ticks_usec") or src.contains("get_ticks_msec"):
		return true
	var re := RegEx.create_from_string("[A-Za-z_][A-Za-z_0-9]*")
	for m: RegExMatch in re.search_all(src):
		if _is_duration(m.get_string(0)):
			return true
	return false


## A time unit must be a whole underscore-separated part of the name. `items` and `seams` contain "ms".
func _is_duration(name: String) -> bool:
	for part: String in name.to_lower().split("_"):
		if TIME_PARTS.has(part):
			return true
	return false


func _claims_without_evidence(src: String) -> Array[String]:
	var out: Array[String] = []
	if not _measures_a_duration(src) or _compares_a_duration(src):
		return out
	for v: String in _verdict_lines(src):
		var low: String = v.to_lower()
		for c: String in SPEED_CLAIMS:
			if low.contains(c):
				out.append(v.strip_edges())
				break
	return out
