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
const VERB_CLAIMS: Dictionary = {
	"add": "\\| `add` \\| ([0-9]+) \\|",
	"add_gl": "\\| `add_gl` \\| ([0-9]+) \\|",
	"add_excl": "\\| `add_excl` \\| ([0-9]+) \\|",
}

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

	for verb: String in VERB_CLAIMS:
		var want: int = _count_registrations(verb)
		var re := RegEx.new()
		re.compile(VERB_CLAIMS[verb])
		for doc: String in DOCS:
			for m: RegExMatch in re.search_all(_read(doc)):
				found += 1
				_check(int(m.get_string(1)) == want,
					"%s says %s layers use `%s` where the runner registers %d"
					% [doc.get_file(), m.get_string(1), verb, want])

	_check(found >= MIN_CLAIMS,
		"the scan actually found the layer-count claims (%d found, at least %d expected)"
		% [found, MIN_CLAIMS])
	_verdict("check_doc_counts", "%d claim(s) across %d doc(s) agree with the runner's %d"
		% [found, DOCS.size(), registered])


## The three registration verbs, each requiring a trailing SPACE. Without it this matches `add() {`, which
## is the definition of the verb rather than a use of it, and inflates the count by exactly three.
func _count_registrations(verb: String = "") -> int:
	var text: String = _read(RUNNER)
	var n: int = 0
	for line: String in text.split("\n"):
		if verb.is_empty():
			if line.begins_with("add ") or line.begins_with("add_gl ") or line.begins_with("add_excl "):
				n += 1
		elif line.begins_with(verb + " "):
			n += 1
	return n


func _read(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s: String = f.get_as_text()
	f.close()
	return s
