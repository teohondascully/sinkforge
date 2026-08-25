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
##      registration verbs with a required trailing space, which is what excludes their own FUNCTION
##      DEFINITIONS. Counting bare `^add` on this same file overcounts by exactly those definitions, by
##      matching the definition of the thing being counted. Stated as a relation rather than as a pair of
##      numbers on purpose: the note below records this same comment naming three verbs after a fourth had
##      been added, and a pinned total is what rots.
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
	_check_registry_population(registered)

	var found: int = 0
	for doc: String in DOCS:
		var text: String = _read(doc)
		if text.is_empty():
			# A doc that will not open is a failure, not an absence. See non-vacuity note 3.
			_check(false, "%s opens and can be read" % doc)
			continue
		for c: Array in _claims_in(text):
			found += 1
			var claimed: int = int(c[0])
			_check(claimed == registered,
				"%s says %d where the runner registers %d (\"%s\")"
				% [doc.get_file(), claimed, registered, String(c[1])])

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
	_matcher_control(registered)
	_verdict("check_doc_counts", "%d claim(s) across %d doc(s) agree with the runner's %d"
		% [found, DOCS.size(), registered])


## Every layer-count claim in one document, as [number, the text that stated it]. Factored out so the
## control below and the real scan run the SAME matcher over the same patterns: a control that reimplements
## the thing it controls has proved that the reimplementation works.
func _claims_in(text: String) -> Array[Array]:
	var out: Array[Array] = []
	for pattern: String in CLAIMS:
		var re := RegEx.new()
		re.compile(pattern)
		for m: RegExMatch in re.search_all(text):
			out.append([int(m.get_string(1)), m.get_string(0)])
	return out


## THE MATCHER HAS TO BE ABLE TO CATCH A STALE NUMBER, and nothing here showed that it could.
##
## Every assertion above compares a number read out of a document against a number read out of the runner,
## and when the reading is broken the comparison agrees with itself: a capture group pointed at the wrong
## subexpression, a phrase that stopped matching once a heading was reworded, both sides counted off the
## same source. Each of those reports a clean tree, which is the report this layer exists to make
## impossible. `MIN_CLAIMS` says the scan found claims. It says nothing about whether a WRONG one would be
## caught, and those are different questions.
##
## So the matcher is run over two sentences built here, one stating a count that is wrong by one and one
## stating the count the runner actually registers, and it has to catch exactly the first.
func _matcher_control(registered: int) -> void:
	var phrase: String = "the harness registers %d layers"
	var stale: Array[Array] = _claims_in(phrase % (registered + 1))
	var fresh: Array[Array] = _claims_in(phrase % registered)
	var caught: int = 0
	for c: Array in stale:
		if int(c[0]) != registered:
			caught += 1
	var wrongly: int = 0
	for c: Array in fresh:
		if int(c[0]) != registered:
			wrongly += 1
	_check(caught == 1,
		"CONTROL: the matcher catches a claim of %d against the runner's %d (%d caught, %d matched)"
			% [registered + 1, registered, caught, stale.size()])
	_check(wrongly == 0,
		"CONTROL: ...and does not fire on the same sentence stating %d (%d matched, %d called wrong)"
			% [registered, fresh.size(), wrongly])


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


## THE COUNT MUST BE A POPULATION, NOT AN AGGREGATE.
##
## Everything above compares a number in a document against a number from the runner. Both can be wrong
## together, and a total is exactly the shape that hides it: two registrations of one script read as two
## layers, and a registration whose script was deleted reads as one. The docs would then agree with an
## inflated figure and every assertion here would pass, which is the failure this suite keeps meeting --
## a green taken over a population nobody enumerated.
##
## The occasion was a merge comparison. Two runners on two lines of history both registered exactly 107,
## and the SETS DIFFERED BY FOUR IN EACH DIRECTION. The equal totals were the most misleading thing in the
## comparison, because they invited the conclusion that the registries matched. A count is not a set, and
## it must not be the only thing asserted about one.
##
## Three properties, each of which the total is blind to:
##
##   1. the paths are DISTINCT. A duplicate inflates the count without adding a layer.
##   2. every path EXISTS. A dangling registration inflates the count without running anything.
##   3. the distinct-and-existing set is the SAME SIZE as the count. This is the one that makes the other
##      two more than a pair of spot checks, and it is what fired when a duplicate was planted: "109
##      distinct existing scripts, one per registration (110 counted)".
##
## A FOURTH AND A FIFTH WERE WRITTEN AND REMOVED, and the reason is worth more than the assertions were.
## They asserted that every registration line yields a path, and that this scan and `_count_registrations`
## agree on the total. Both are unreachable. `run_harness.sh` runs under `set -u` and `add()` dereferences
## `$2`, so a registration line with no path kills the runner at line 237 with an unbound variable before
## any layer starts. No sweep can reach this file in that state, so neither assertion could ever be false,
## and a control planting such a line produced no failure here -- it produced no run at all.
##
## They were written in the same hour this suite REJECTED an imported layer for reporting assertions that
## cannot fail. Keeping them would have shipped the defect that layer was rejected for describing. The
## test is not whether an assertion is reasonable; it is whether a planted defect makes it red.
func _check_registry_population(registered: int) -> void:
	var text: String = _read(RUNNER)
	var verbs: Array[String] = _verbs()
	var re: RegEx = RegEx.new()
	re.compile("\"(res://[^\"]+)\"")
	var paths: Array[String] = []
	for line: String in text.split("\n"):
		var is_reg: bool = false
		for v: String in verbs:
			if line.begins_with(v + " "):
				is_reg = true
				break
		if not is_reg:
			continue
		var m: RegExMatch = re.search(line)
		if m != null:
			paths.append(m.get_string(1).replace("res://", ""))

	var seen: Dictionary = {}
	var dupes: Array[String] = []
	for pth: String in paths:
		if seen.has(pth):
			if not dupes.has(pth):
				dupes.append(pth)
		seen[pth] = true
	_check(dupes.is_empty(),
		"no script is registered twice (%d duplicate path(s): %s)" % [dupes.size(), ", ".join(dupes)])

	var missing: Array[String] = []
	for pth: String in paths:
		if not FileAccess.file_exists("res://" + pth):
			missing.append(pth)
	_check(missing.is_empty(),
		"every registered script exists on disk (%d missing: %s)" % [missing.size(), ", ".join(missing)])

	# The control. Without it the three assertions above are satisfied by an empty `paths`, which is the
	# same trivial agreement `check_shared_constants` guards its own scan against.
	_check(seen.size() == registered,
		"the registry resolves to %d distinct existing scripts, one per registration (%d counted)"
			% [seen.size(), registered])
