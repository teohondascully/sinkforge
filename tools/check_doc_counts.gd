extends "res://tools/check_base.gd"

## Harness layer: EVERY LAYER COUNT PRINTED IN A DOC IS THE COUNT THE RUNNER ACTUALLY REGISTERS.
##
## `CONTRIBUTING.md` states the rule this layer enforces: "A comment that states a number is a test with no
## runner. Either derive the fact from the constant, or put it somewhere the harness checks it." The two
## documents that carry that sentence both then state a layer count in prose, and nothing checked it.
##
## THE DEFECT IS NOT HYPOTHETICAL AND IT DID NOT TAKE A WEEK. Both files were written saying 100, went stale
## within twenty minutes when `check_shaders` was registered, were corrected to 101, and went stale again
## forty minutes later when `check_verdict_claims` landed. Two staleness events in one hour, from the most
## motivated reader the file will ever have, on a number sitting in the fourth line of a section. Nobody is
## going to do better by remembering.
##
## NON-VACUITY. Three ways this layer could pass without meaning anything, and what stops each:
##   1. Finding no claims at all and reporting a clean tree. A zero-result search is evidence about the
##      search, so `MIN_CLAIMS` asserts the scan found several. Rename the section headings and this fails
##      rather than going quiet.
##   2. Counting the registrations wrongly in the same direction as the docs. The count is taken from the
##      three registration verbs with a required trailing space, which is what excludes the three FUNCTION
##      DEFINITIONS `add() {`, `add_gl() {` and `add_excl() {`. A peer counting `^add` on this same file got
##      104 for a real 101 by matching the definition of the thing being counted.
##   3. Reading a doc it cannot find and calling that agreement. A file that will not open is a FAIL here,
##      never a skip: the whole point is that these two files exist and are read.
##
##     bash tools/with_machine.sh --headless --script res://tools/check_doc_counts.gd

const RUNNER: String = "res://tools/run_harness.sh"
const DOCS: Array[String] = ["res://README.md", "res://CONTRIBUTING.md", "res://docs/ENGINEERING.md"]

## Phrases that state the registered-layer count. Each pattern must capture the number in group 1. Kept as
## patterns rather than as one loose `[0-9]+ layers` because this file also says "17 layers" about the
## surface subset and "16 layers" about the CI selection, and both are correct.
const CLAIMS: Array[String] = [
	"registers ([0-9]+) layers",
	"whole suite: ([0-9]+) layers",
	"its ([0-9]+) layers",
	# NO `^` ON THIS ONE. Godot's RegEx is PCRE2 without MULTILINE, so `^` anchors to the start of the
	# whole file rather than of a line, and this claim sits at line 220. Anchored, the pattern would match
	# nothing, `found` would quietly drop from 4 to 3, and MIN_CLAIMS of 3 would still pass. A blind scan
	# reporting a clean tree is the exact shape this layer exists to catch, so it must not have it.
	"([0-9]+) is a count of registered layers",
	"([0-9]+) registered check layers",
]

## The per-verb counts, which the total cannot cover. `docs/ENGINEERING.md` prints a table of the three
## execution classes, and a table cell is exactly where a number goes stale unnoticed: it is not in a
## sentence anyone rereads. Each pattern must capture its number in group 1, keyed by the verb it claims.
## THE PATTERN IS DERIVED PER VERB, for the same reason the verbs are: this was a hand-kept dictionary of
## three, so a fourth execution class could be added to the runner and documented nowhere, and the layer
## whose name is "docs match the runner" would agree that they did.
func _verb_pattern(verb: String) -> String:
	return "\\| `%s` \\| ([0-9]+) \\|" % verb

## Below this the scan is not reading the documents, whatever it reports about them.
const MIN_CLAIMS: int = 3


func _initialize() -> void:
	var registered: int = _count_registrations()
	_check(registered > 0, "read the registration list out of run_harness.sh (%d layers)" % registered)

	var found: int = 0
	for doc: String in DOCS:
		var text: String = _read(doc)
		if text.is_empty():
			# A doc that will not open is a failure, not an absence. See non-vacuity note 3.
			_check(false, "%s opens and can be read" % doc)
			continue
		for pattern: String in CLAIMS:
			var re := RegEx.new()
			re.compile(pattern)
			for m: RegExMatch in re.search_all(text):
				found += 1
				var claimed: int = int(m.get_string(1))
				_check(claimed == registered,
					"%s says %d where the runner registers %d (\"%s\")"
					% [doc.get_file(), claimed, registered, m.get_string(0)])

	# AND EVERY VERB THE RUNNER DEFINES MUST HAVE A ROW. Checking only the rows that exist lets a new
	# execution class be undocumented and still green -- the table would be internally consistent and
	# silently incomplete, which is exactly how `add_excl_hl` arrived. A verb with no row is a red here.
	var verbs: Array[String] = _verbs()
	_check(verbs.size() >= 3, "derived the registration verbs from the runner: %s" % ", ".join(verbs))
	for verb: String in verbs:
		var want: int = _count_registrations(verb)
		var re := RegEx.new()
		re.compile(_verb_pattern(verb))
		var rows: int = 0
		for doc: String in DOCS:
			for m: RegExMatch in re.search_all(_read(doc)):
				found += 1
				rows += 1
				_check(int(m.get_string(1)) == want,
					"%s says %s layers use `%s` where the runner registers %d"
					% [doc.get_file(), m.get_string(1), verb, want])
		_check(rows > 0, "`%s` (%d layers) has a row in the execution-class table" % [verb, want])

	_check(found >= MIN_CLAIMS,
		"the scan actually found the layer-count claims (%d found, at least %d expected)"
		% [found, MIN_CLAIMS])
	_verdict("check_doc_counts", "%d claim(s) across %d doc(s) agree with the runner's %d"
		% [found, DOCS.size(), registered])


## THE VERBS ARE DERIVED FROM THE RUNNER, and this function used to name three of them. `add_excl_hl` was
## added for a layer that must run alone but needs no display, and this file could not see it: the total
## read 104 where the runner declared 105, and the missing one was invisible rather than wrong. A guard
## against stale counts, holding its own stale count of the things it counts.
##
## The rule is the one `check_ci_coverage` already uses on the same file, deliberately: a registration verb
## is any function that appends to NAMES. Adding a fifth requires no edit here.
##
## EACH USE REQUIRES A TRAILING SPACE, without which this matches `add() {` -- the DEFINITION of the verb
## rather than a use of it -- and inflates the total by exactly the number of verbs. It also has to be a
## prefix match on the verb plus a space rather than on the verb alone, or `add ` would count `add_gl ` and
## `add_excl ` would count `add_excl_hl `.
func _verbs() -> Array[String]:
	var out: Array[String] = []
	for line: String in _read(RUNNER).split("\n"):
		var t: String = line.strip_edges()
		if not t.contains("NAMES+=("):
			continue
		var paren: int = t.find("() {")
		if paren > 0 and not out.has(t.substr(0, paren)):
			out.append(t.substr(0, paren))
	return out


func _count_registrations(verb: String = "") -> int:
	var text: String = _read(RUNNER)
	# NOT A TERNARY. `[verb] if ... else _verbs()` assigns an untyped `Array` to an `Array[String]` and
	# throws at RUNTIME, which --check-only does not see. The function then returned 0 for every verb, and
	# the "has a row in the table" assertion PASSED over those zeroes -- a row exists whether the count
	# beside it is 3 or garbage. Only the count comparison caught it.
	var verbs: Array[String] = []
	if verb.is_empty():
		verbs = _verbs()
	else:
		verbs.append(verb)
	var n: int = 0
	for line: String in text.split("\n"):
		for v: String in verbs:
			if line.begins_with(v + " "):
				n += 1
				break
	return n


func _read(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s: String = f.get_as_text()
	f.close()
	return s
