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
## Both halves are wrong here, and measurably: **under a third of the layers this gate scans call
## `_verdict()`** and **about nine in ten call `_check()`**, so a detector written that way is blind to
## roughly two thirds of the tree on one axis and a tenth on the other. Proportions rather than a pair of
## totals: the totals move with every layer added, the argument does not, and a stale pair in a comment
## about stale detectors is the joke writing itself. The one real instance reaches the terminal through a bare `print`, and a layer that
## enforces its floor with `if r >= LAG1_FLOOR:` rather than `_check(r >= LAG1_FLOOR)` would be reported
## as unguarded. Both mistakes were made while building this and both scored as coverage.
##
## So: the claim is any string containing `<layer>: PASS`, however it is printed, and the evidence is any
## comparison operator anywhere in the file with a duration-bearing name on either side.
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


func _initialize() -> void:
	var pos: Array[String] = _claims_without_evidence(CONTROL_SRC)
	_check(not pos.is_empty(),
		"the detector flags its own positive control (a speed claim with nothing compared)")
	_check(_claims_without_evidence(CONTROL_CLEAN).is_empty(),
		"...and stays quiet on the same file once a comparison guards it")

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


## The verdict lines of a source, however they reach the terminal.
func _verdict_lines(src: String) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string("\"([^\"\\\\]*:\\s*PASS[^\"\\\\]*)\"")
	for m: RegExMatch in re.search_all(src):
		out.append(m.get_string(1))
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
