extends "res://tools/check_base.gd"

## Harness layer: EVERY REGISTERED LAYER RUNS IN SOME CI JOB, and any that does not is named out loud.
##
## THE DEFECT THAT MOTIVATED IT WAS LIVE, AND BOTH JOBS WERE GREEN OVER IT. The display job selected its
## pixel layers by name:
##
##     SF_ONLY: check_opening|check_underground|check_water_reads|check_dig_hitch
##
## accurate on the day it was typed. `add_gl` then grew to six. `check_item_reads` and `check_hud_layout`
## skip in the headless job — correctly, they need a window — and this job never selected them, so they
## ran in NO CI JOB AT ALL. Nothing printed that. The headless job honestly reported them as SKIP and the
## display job honestly reported four passes, and the two reports together said nothing about the gap
## between them, because nobody was holding them against each other.
##
## THIS IS A JOIN DEFECT, which is the family named after finding the same shape in the
## machine-status lamp: a vocabulary defined in one file (`add_gl` in the runner) and consumed in another
## (a name list in the workflow), with every existing test reading one file or the other. Look for more of
## them anywhere one file enumerates what another file must handle.
##
## SET EQUALITY, NOT CONTAINMENT — also the peer's rule, and the reason this layer can fail. "Every layer
## the workflow names is real" passes trivially when the workflow names nothing, which is precisely the
## bug. So the load-bearing direction is the other one: every layer the RUNNER says needs a surface is
## either selected by the display job or explicitly excluded by it, and every exclusion must match a real
## layer, so a typo in `SF_NOT` cannot quietly excuse nothing while looking deliberate.
##
## NON-VACUITY. The scan can fail to find anything — a renamed verb, a reformatted workflow — and a scan
## that matches nothing satisfies every forward check. So the counts are asserted before the sets are
## compared: the runner must yield a plausible number of layers, must yield at least one that needs a
## surface, and the workflow must yield both a selection and an exclusion.
##   godot --headless --path . --script res://tools/check_ci_coverage.gd

const RUNNER: String = "tools/run_harness.sh"
const WORKFLOW: String = ".github/workflows/harness.yml"
## Below this the scan has plainly broken rather than the suite having shrunk. 72 layers today; a suite that
## genuinely fell under 40 is a thing somebody should have to come here and change on purpose.
const MIN_LAYERS: int = 40


func _initialize() -> void:
	var runner: String = _read(RUNNER)
	var flow: String = _read(WORKFLOW)
	_check(not runner.is_empty(), "read %s" % RUNNER)
	_check(not flow.is_empty(), "read %s" % WORKFLOW)
	if runner.is_empty() or flow.is_empty():
		_verdict("check_ci_coverage")
		return

	# THE REGISTRATION VERBS, DERIVED. Spelling them out here would make this layer carry its own copy of
	# the very list whose staleness it exists to catch — the same mistake one level up. A verb is any
	# function in the runner that appends to NAMES.
	var verbs: Array[String] = []
	for line: String in runner.split("\n"):
		var t: String = line.strip_edges()
		if not t.contains("NAMES+=("):
			continue
		var paren: int = t.find("() {")
		if paren > 0 and not verbs.has(t.substr(0, paren)):
			verbs.append(t.substr(0, paren))
	_check(verbs.size() >= 3, "derived the registration verbs from the runner: %s" % ", ".join(verbs))

	# Which layers each verb registered, and which of them set GLFLAG=1 — "this needs a real surface".
	var needs_surface: Array[String] = []
	var all_layers: Array[String] = []
	var gl_verbs: Array[String] = []
	for v: String in verbs:
		if _verb_sets_gl(runner, v):
			gl_verbs.append(v)
	for line: String in runner.split("\n"):
		var t: String = line.strip_edges()
		for v: String in verbs:
			if not t.begins_with(v + " \""):
				continue
			var name: String = _first_quoted(t)
			if name.is_empty():
				continue
			all_layers.append(name)
			if gl_verbs.has(v):
				needs_surface.append(name)
			break
	_check(all_layers.size() >= MIN_LAYERS,
		"the runner registers %d layers (floor %d — under it, assume the scan broke)"
		% [all_layers.size(), MIN_LAYERS])
	_check(needs_surface.size() > 0,
		"%d of them need a real surface, via %s: %s"
		% [needs_surface.size(), ", ".join(gl_verbs), ", ".join(needs_surface)])

	# THE DISPLAY JOB MUST NOT SELECT BY NAME. This is the regression itself, stated as an assertion: a
	# workflow that enumerates pixel layers is a workflow that will be stale the next time one is added,
	# and the staleness is invisible from either job's output.
	_check(not _has_key(flow, "SF_ONLY"),
		"no CI job selects layers by NAME — a hand-kept list is what left two layers running nowhere")
	_check(_yaml_value(flow, "SF_GL_ONLY") == "1",
		"the display job selects by REGISTRATION (SF_GL_ONLY=1), so a new add_gl layer is covered the day"
		+ " it lands")

	# The exclusion, and both directions of it.
	var not_re: String = _yaml_value(flow, "SF_NOT")
	_check(not not_re.is_empty(), "the display job states its exclusions in SF_NOT rather than by omission")
	var excluded: Array[String] = []
	# `create_from_string` ALWAYS returns an object — a pattern that fails to compile comes back non-null
	# with `is_valid()` false, and its `search` then matches nothing. Measured against 4.6.2 rather than
	# assumed: `RegEx.create_from_string("check_(unclosed")` gives `!= null -> true`, `is_valid() -> false`.
	# So `_check(re != null, ...)` could not fail, and it was standing in front of the exact input it was
	# supposed to be validating. A broken SF_NOT would have been caught one assertion further down, by
	# `excluded.size() > 0` — but by the wrong line, saying the wrong thing.
	var re: RegEx = RegEx.create_from_string(not_re)
	_check(re.is_valid(), "SF_NOT ('%s') compiles as a pattern at all" % not_re)
	# AND THE CLAIM THIS USED TO MAKE IS STILL NOT PROVEN BY THAT. Godot's RegEx is PCRE2; the runner
	# filters with `grep -Eq` (run_harness.sh:317), which is POSIX ERE. `\d`, `(?i)` and lookarounds are
	# valid PCRE2 and are not ERE, so "Godot compiled it" is not "grep will use it the same way". Rather
	# than assert a cross-engine equivalence this layer cannot test, the pattern is held to the subset where
	# the two engines cannot disagree: layer names and alternation, which is all SF_NOT has ever needed.
	var plain: RegEx = RegEx.create_from_string("^[A-Za-z0-9_|]+$")
	_check(plain.search(not_re) != null,
		"SF_NOT ('%s') stays inside the names-and-alternation subset where PCRE2 and grep -E agree"
			% not_re + " — anything richer must be verified against grep by hand")
	if re.is_valid():
		for name: String in needs_surface:
			if re.search(name) != null:
				excluded.append(name)
	# THE REVERSE DIRECTION, which is the one that makes this self-proving: an exclusion matching nothing
	# looks exactly like a deliberate, careful exclusion and covers no one. A typo here would otherwise be
	# invisible forever.
	_check(excluded.size() > 0,
		"SF_NOT ('%s') actually matches a registered layer — an exclusion that matches nothing is a typo"
		% not_re + " wearing the costume of a decision")
	_check(excluded.size() < needs_surface.size(),
		"...and it does not exclude every surface layer (%d of %d) — that would be the display job doing"
		% [excluded.size(), needs_surface.size()] + " nothing while reporting green")

	# AN EXCLUSION HAS TO COST SOMETHING, and this assertion exists because the first mutation I tried
	# against this layer PASSED. Adding `check_hud_layout` to SF_NOT removed a layer from every CI job and
	# the layer reported it, correctly, as an exclusion on the record — its contract was only that nothing
	# runs nowhere WITHOUT being named. But "named" is a low bar, and the way the original defect returns is
	# not someone deleting a name, it is the exclusion list growing one flaky layer at a time until the
	# display job is a formality again. So each excluded layer must be ARGUED FOR in the workflow's own
	# prose: its name has to appear in a comment there. `check_frametime` has a paragraph, with two
	# containers' measurements in it. That is the standard, and it is the right price for opting out of CI.
	for name: String in excluded:
		var slug: String = name.split(" ")[0]
		_check(_declared_excluded(flow, slug),
			"%s is excluded from CI under an explicit `%s %s:` declaration saying why"
			% [slug, EXCLUDE_MARK, slug])

	var covered: Array[String] = []
	for name: String in needs_surface:
		if not excluded.has(name):
			covered.append(name)
	print("  CI coverage: %d layers declared · %d need a surface · %d run on the display job · %d excluded"
		% [all_layers.size(), needs_surface.size(), covered.size(), excluded.size()])
	print("      on the display job: %s" % ", ".join(covered))
	print("      excluded by SF_NOT: %s" % ", ".join(excluded))
	_check(covered.size() + excluded.size() == needs_surface.size(),
		"every layer needing a surface is either run by the display job or named in its exclusion — set"
		+ " equality, not containment")

	# And the headless job must stay unfiltered, or the layers that DON'T need a surface lose their cover
	# the same way. `SF_HEADLESS` is not a filter — it forces the no-display path — so it is not counted.
	_check(not flow.contains("SF_GL_ONLY: \"0\""),
		"nothing turns the display job's selection off while leaving it looking enabled")

	_verdict("check_ci_coverage",
		"%d surface layers, %d covered, %d excluded on the record" % [needs_surface.size(),
			covered.size(), excluded.size()])


## Does this registration verb mark its layers as needing a surface? Read from the verb's own body rather
## than from a list here — `add_excl` sets GLFLAG=1 too, and a layer that measures TIME needs a real
## renderer for the same reason a layer that measures pixels does.
func _verb_sets_gl(runner: String, verb: String) -> bool:
	for line: String in runner.split("\n"):
		var t: String = line.strip_edges()
		if t.begins_with(verb + "() {"):
			return t.contains("GLFLAG+=(1)")
	return false


## The first double-quoted run in a line — a layer's display name, as the runner stores it.
func _first_quoted(line: String) -> String:
	var a: int = line.find("\"")
	if a < 0:
		return ""
	var b: int = line.find("\"", a + 1)
	return "" if b < 0 else line.substr(a + 1, b - a - 1)


## The value of a `KEY: value` line in the workflow, quotes stripped. Deliberately a scan of the whole
## file rather than a YAML parse: there is one of each of these keys, and a parser is a dependency this
## layer does not need in order to answer the only question it asks.
func _yaml_value(flow: String, key: String) -> String:
	for line: String in flow.split("\n"):
		var t: String = line.strip_edges()
		if t.begins_with("#") or not t.begins_with(key + ":"):
			continue
		var v: String = t.substr(key.length() + 1).strip_edges()
		return v.trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
	return ""


## Is `key` SET anywhere in the workflow, as opposed to merely MENTIONED?
##
## The distinction is not pedantry and this layer proved it on its own first run. The comment explaining
## why `SF_ONLY` was removed necessarily QUOTES the line it replaced, so a bare `flow.contains("SF_ONLY:")`
## went red over its own explanation — a scanner that cannot tell a directive from a description, failing
## on prose about the very defect it was written to catch. The lesson from the same day
## applies: when a new instrument fires, check the instrument before the code. It was the instrument.
## Did someone DECLARE this layer excluded, in the structured form, rather than merely mention it?
##
## THE FIRST VERSION OF THIS ASKED FOR A COMMENT NAMING THE LAYER, and the mutation still passed. The
## workflow's own explanation of the original defect says "`check_item_reads` and `check_hud_layout` ran in
## NEITHER job" — so the prose written to describe the bug satisfied the guard against the bug, for exactly
## the two layers involved. That is twice in one file that free text fooled a scanner (the other was
## `SF_ONLY:` inside a comment), which is the argument for a MARKER rather than a keyword search: a
## declaration nobody writes by accident and no amount of surrounding explanation can imitate.
const EXCLUDE_MARK: String = "# CI-EXCLUDED"
func _declared_excluded(flow: String, slug: String) -> bool:
	for line: String in flow.split("\n"):
		var t: String = line.strip_edges()
		if t.begins_with("%s %s:" % [EXCLUDE_MARK, slug]) and t.length() > EXCLUDE_MARK.length() \
				+ slug.length() + 8:
			return true
	return false


func _has_key(flow: String, key: String) -> bool:
	for line: String in flow.split("\n"):
		var t: String = line.strip_edges()
		if not t.begins_with("#") and t.begins_with(key + ":"):
			return true
	return false


## Read a repo-relative file from the real filesystem. NOT via `res://`: `.github/` is outside anything the
## import pipeline knows about, and this layer's whole job is to read files the engine does not load.
func _read(rel: String) -> String:
	var path: String = ProjectSettings.globalize_path("res://").path_join(rel)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("  could not open %s" % path)
		return ""
	return f.get_as_text()
