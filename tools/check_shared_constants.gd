extends "res://tools/check_base.gd"

## A CONSTANT DEFINED IN MANY PLACES IS A CONSTANT NOTHING RELATES.
##
## `const CELL: int = 32` was declared independently in TWENTY-FOUR files. They all agreed, by luck.
## Nothing in the tree could have noticed if one stopped agreeing: there was no shared owner, no import,
## and no assertion anywhere that compared them. The obvious reach was `FactorySim.CELL`, on the
## reasonable assumption that a grid constant lives with the grid, and it was not there either. The name
## existed twenty-four times and belonged to no one.
##
## This is the runtime-invisible half of the defect class. A wrong value here does not crash and does not
## fail a test; it makes one file measure the world on a different ruler than its neighbours, and the
## symptom appears somewhere else entirely as a few pixels of drift.
##
## THE OWNER NOW EXISTS: `FactorySim.CELL`, beside GRID_COLS and GRID_ROWS whose unit it is. Consumers
## alias it (`const CELL: int = FactorySim.CELL`) so call sites stay short while exactly one literal
## remains in the tree.
##
## THIS LAYER IS RETAINED AS A REGRESSION CHECK RATHER THAN DELETED. Its job has inverted: it used to
## detect drift AMONG duplicates, and now it detects the RE-INTRODUCTION of one. A future file that
## writes `const CELL: int = 32` of its own is not a compile error and not a test failure anywhere else
## in the suite; it is a second literal, and a second literal is where the whole defect starts again.
##
## It reads SOURCE, so every line it prints is a statement about ONE CHECKOUT. It prints which.

## Names that must agree everywhere they are declared, with the value they must hold.
const SHARED: Dictionary = {
	"CELL": 32.0,
}

## Files exempt from a given name, with the reason. Empty on purpose: an exemption list that starts
## populated is an exemption list nobody audits.
const EXEMPT: Dictionary = {}

## NAMES THAT MUST BE DECLARED IN EXACTLY ONE FILE, AND WHICH FILE THAT IS.
##
## `SHARED` above asks what a name's VALUE must be, which only works for scalars. This asks a different
## question that works for anything: how many files DEFINE it, and is that the file it was put in. A table
## of twenty-two key bindings has no value to compare, and it is exactly the kind of thing that gets
## copied back into a page "just for now".
##
## AN ALIAS IS NOT A DEFINITION. `const REMAP_ROWS: Array[Array] = SettingsPage.REMAP_ROWS` names the
## symbol locally so the drawing code reads unchanged, and it cannot drift because there is nothing in it
## to drift. A literal on the right-hand side is a second owner. That distinction is the whole check: it
## permits the cheap, reversible form of an extraction while refusing the one that re-couples.
##
## This is the guard for the HUD extractions. Each one moves a cluster out of `hud.gd` and leaves aliases
## behind, and the failure mode is not that the move goes wrong on the day. It is that six weeks later a
## fix lands in the page rather than the module, because the page is where the drawing is and the symbol
## still resolves there.
##
## PROVED BY TWO MUTANTS, and they fire on different assertions, which is the point of there being two:
##
##   mutant                                          count      location
##   a second REMAP_ROWS definition, re-inlined      **FAIL**   not reached
##   the one definition moved to another file        PASS       **FAIL**
##
## The first is the re-coupling this exists to catch. The second is why the location assertion is not
## redundant with the count: a cluster can be moved out of the page and land somewhere nobody meant, and
## "there is exactly one of it" is true the whole time. The location check is skipped when the count is
## already wrong, because two owners have no single place to be.
const SOLE_OWNER: Dictionary = {
	"REMAP_ROWS": "res://scenes/settings_page.gd",
	"AUDIO_ROWS": "res://scenes/settings_page.gd",
	"FEEL_ROWS": "res://scenes/settings_page.gd",
	"CAT_NAMES": "res://scenes/settings_page.gd",
	# The focus ring's shape constants. They are used by exactly one routine and moved with it, so unlike
	# the catalogs above there is no alias left behind: a second FOCUS_KEYLINE anywhere is a second ring.
	"FOCUS_KEYLINE": "res://scenes/visuals.gd",
	"FOCUS_SPINE_DX": "res://scenes/visuals.gd",
	"KEYCAP_BASE": "res://scenes/visuals.gd",
	"KEYCAP_DROP": "res://scenes/visuals.gd",
	# The page's palette. Aliased on Hud, so these prove the alias is an alias and not a second literal.
	"UI_ACCENT": "res://scenes/ui_theme.gd",
	"UI_TEXT": "res://scenes/ui_theme.gd",
	"UI_MODAL": "res://scenes/ui_theme.gd",
	"CANVAS": "res://scenes/ui_theme.gd",
	"RAIL_ON_FILL": "res://scenes/ui_theme.gd",
	"SET_W": "res://scenes/settings_page.gd",
	"RAIL_TOP_FRAC": "res://scenes/settings_page.gd",
}


## THE SAME QUESTION ASKED OF CODE RATHER THAN OF A NAME.
##
## `SOLE_OWNER` catches a constant re-declared somewhere it should not be. It cannot catch a ROUTINE
## re-typed under a different name, which is the form the duplication actually took here: `hud.gd` held
## two implementations of letter-spaced text, `_tracked` and `_draw_tracked`, identical but for a
## parameter name, with thirteen and five callers. Both correct, both agreeing, and nothing in the tree
## comparing them. The day one is fixed and the other is not, some captions print through their titles
## and some do not.
##
## So each entry is a fragment distinctive enough that its presence means the routine is THERE, not
## merely referenced. The count is of FILES, not occurrences: one file may legitimately use a fragment
## twice, as `round_rect` and `round_rect_left` both do.
##
## Choosing a fragment is the whole skill. Too generic and it fires on innocent code; too specific and a
## reformat makes it vacuous, which is the worse failure because it goes green. Both below are the load
## bearing line of their routine, the one you cannot write the routine without.
const SOLE_IMPL: Dictionary = {
	"sb.corner_detail = 8": "res://scenes/visuals.gd",
	"get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT": "res://scenes/visuals.gd",
	"box.grow(grow - 1.0)": "res://scenes/visuals.gd",
	"Vector2(0.0, KEYCAP_DROP)": "res://scenes/visuals.gd",
}

## EACH ASSERTION IS PROVED SEPARATELY, because one mutant leaves the others unproven.
##
## This layer makes three claims and they fail to different things, so a single control would have left
## two of them untested while the run looked fully controlled:
##
##   mutant                                        coverage   once     agreement   opened
##   _walk skips tools/ (47 files seen, not 165)   **FAIL**   PASS     PASS        PASS
##   a second literal, via SF_SHARED_CONST_EXTRA   PASS       **FAIL** PASS        PASS
##   the OWNER FactorySim.CELL 32 -> 33            PASS       PASS     **FAIL**    PASS
##
## Each mutant fires exactly one assertion, which is what makes them a proof rather than three runs of the
## same test. Two rows deserve reading twice.
##
## ROW 1. With tools/ skipped the scan finds exactly ONE declaration, the owner, and "every declaration
## holds 32.0" is then TRUE of a population of one. The agreement check passes VACUOUSLY on a scan that
## never ran, and so does the exactly-once check. Coverage is the only thing standing between this layer
## and a green line that means nothing.
##
## ROW 2 IS THE ORIGINAL DEFECT, REPRODUCED. The re-introduced literal holds 32, so it AGREES, so the
## agreement assertion passes and reports nothing. That is precisely how twenty-four copies accumulated in
## the first place: every one of them agreed on the day it was written. Only the count sees it. The failure
## names the sites, because "found 2" sends you grepping and "found 2 -- factory_sim.gd:36, hud.gd:218" is
## already the fix.
##
## ROW 3 answers the objection to consumers aliasing the value at all: a test that imports the constant it
## checks cannot notice a change to it. True of any single consumer, and the reason the expected value is
## written HERE. Changing CELL still fails loudly; it now takes one assertion to say so instead of needing
## twenty-four files to disagree with each other.
##
## NOT PROVED: the third claim, that every .gd file opened and returned text. Reaching it needs a file
## that exists and cannot be read, which I have not staged. It is recorded as unproven rather than assumed
## to work, because an untested assertion is exactly what the other two rows are about.
## THE COVERAGE CONTROL COUNTS FILES OPENED, NOT DECLARATIONS FOUND.
##
## It used to count declarations, with a floor of 20 against the 24 that existed. That conflated two
## different quantities: "did the scan run" and "how many copies exist". Consolidating the copies is the
## whole point of this layer, so the old floor would have failed on the success it was built to reach,
## and the only ways to keep it green were to lower it after every slice or to abandon the refactor.
##
## Files scanned is invariant under the refactor and is what the coverage claim was always about. Derived,
## not chosen: this tree walks 165 .gd files, of which tools/ is 118 and everything else is 47. A floor of
## 120 is below the real count with 45 files of slack, and above BOTH degenerate scans -- a walk that skips
## tools/ sees 47, a walk that sees only tools/ sees 118. Either one fails by a wide margin.
const FILE_FLOOR: int = 120


func _frame() -> String:
	var root: String = ProjectSettings.globalize_path("res://")
	var out: Array = []
	var code: int = OS.execute("git", ["-C", root, "rev-parse", "--abbrev-ref", "HEAD"], out, true)
	var ref: String = "unknown ref (git exit %d)" % code
	if code == 0 and not out.is_empty() and not String(out[0]).strip_edges().is_empty():
		ref = String(out[0]).strip_edges()
	return "%s  [%s]" % [root, ref]


func _walk(dir: String, acc: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		var p: String = dir.path_join(n)
		if d.current_is_dir():
			if not n.begins_with("."):
				_walk(p, acc)
		elif n.ends_with(".gd") and not n.begins_with("_scratch_"):
			# `tools/_scratch_*.gd` are gitignored throwaways, and several deliberately declare a DIFFERENT
			# CELL because they are fixtures proving a scanner red. They are not part of the tree's
			# contract, so they are excluded from the WALK rather than added to EXEMPT -- an exemption
			# entry says "this source file is allowed to disagree", which is a much stronger claim and one
			# nobody should be able to make quietly.
			acc.append(p)
		n = d.get_next()
	d.list_dir_end()


func _initialize() -> void:
	print("== shared constants: one name, one value, everywhere ==")
	print("  scanned tree: %s" % _frame())

	var files: Array[String] = []
	_walk("res://", files)
	files.sort()

	var extra: String = OS.get_environment("SF_SHARED_CONST_EXTRA")
	if not extra.is_empty():
		for p: String in extra.split(",", false):
			var t: String = p.strip_edges()
			if not t.is_empty() and not files.has(t):
				files.append(t)
		print("  (SF_SHARED_CONST_EXTRA adds %s)" % extra)

	print("  scanned %d .gd file(s)" % files.size())
	_check(files.size() >= FILE_FLOOR,
		"the scan opened %d .gd files, at least %d expected — below this the walk missed whole directories,"
			% [files.size(), FILE_FLOOR]
			+ " and a scan that barely ran agrees with itself trivially")

	var unreadable: Array[String] = []
	for name: String in SHARED:
		var want: float = float(SHARED[name])
		var re := RegEx.create_from_string("^\\s*(?:const|static var)\\s+%s\\b[^=]*=\\s*(-?[0-9.]+)" % name)
		var sites: Array[Dictionary] = []
		for p: String in files:
			var f: FileAccess = FileAccess.open(p, FileAccess.READ)
			if f == null:
				unreadable.append(p)
				continue
			var body: String = f.get_as_text()
			if body.is_empty():
				# No .gd in this tree is empty. An empty read is a read that failed, and counting it as a
				# file with no declarations is how a scanner reports a sweep it never performed.
				unreadable.append(p)
				continue
			var line_no: int = 0
			for line: String in body.split("\n"):
				line_no += 1
				var m: RegExMatch = re.search(line)
				if m != null:
					sites.append({"path": p, "line": line_no, "value": float(m.get_string(1))})

		var wrong: Array[String] = []
		for s: Dictionary in sites:
			if not is_equal_approx(float(s["value"]), want):
				wrong.append("%s:%d = %s (want %s)"
					% [String(s["path"]).replace("res://", ""), s["line"], s["value"], want])

		print("  %s: %d declaration(s), all must equal %s" % [name, sites.size(), want])

		# THE POINT OF THE LAYER NOW. One literal, and a second one is where the whole defect restarts.
		# Naming the sites matters: "found 2" sends you grepping, "found 2 -- src/core/factory_sim.gd:36,
		# scenes/hud.gd:218" is already the fix.
		var where: Array[String] = []
		for s: Dictionary in sites:
			where.append("%s:%d" % [String(s["path"]).replace("res://", ""), s["line"]])
		_check(sites.size() == 1,
			"%s is declared exactly once and found %d%s"
				% [name, sites.size(), "" if sites.size() == 1 else " — at " + ", ".join(where)])
		_check(wrong.is_empty(),
			"%s: every declaration holds %s%s"
				% [name, want, "" if wrong.is_empty() else " — DISAGREE: " + ", ".join(wrong)])

	for name: String in SOLE_OWNER:
		var want_file: String = String(SOLE_OWNER[name])
		var owners: Array[String] = []
		var alias_n: int = 0
		var re2 := RegEx.create_from_string("^\\s*const\\s+%s\\b[^=]*=\\s*(.+?)\\s*$" % name)
		var alias_re := RegEx.create_from_string("^[A-Z][A-Za-z0-9_]*\\.%s$" % name)
		for p: String in files:
			var f2: FileAccess = FileAccess.open(p, FileAccess.READ)
			if f2 == null:
				continue
			var line_no2: int = 0
			for line: String in f2.get_as_text().split("\n"):
				line_no2 += 1
				var m2: RegExMatch = re2.search(line)
				if m2 == null:
					continue
				if alias_re.search(m2.get_string(1)) != null:
					alias_n += 1                       # names the symbol, owns nothing, cannot drift
				else:
					owners.append("%s:%d" % [String(p).replace("res://", ""), line_no2])
		print("  %s: %d definition(s), %d alias(es), owner must be %s"
			% [name, owners.size(), alias_n, want_file.replace("res://", "")])
		_check(owners.size() == 1,
			"%s is DEFINED in exactly one file and found %d%s"
				% [name, owners.size(), "" if owners.size() == 1 else " — at " + ", ".join(owners)])
		if owners.size() == 1:
			_check(owners[0].begins_with(want_file.replace("res://", "")),
				"%s is defined in %s and it is in %s"
					% [name, want_file.replace("res://", ""), owners[0]])

	# THE LAYER MUST NOT SCAN ITSELF. Every fragment below is a string literal in the table above, so an
	# unfiltered walk finds this file for every entry and the guard reports its own table as duplication.
	# Skipping by path rather than by cleverness: if the path stops matching, the layer fails loudly on
	# its own source rather than quietly stopping checking.
	var self_path: String = ""
	var own: Script = get_script() as Script
	if own != null:
		self_path = own.resource_path
	for frag: String in SOLE_IMPL:
		var want2: String = String(SOLE_IMPL[frag])
		var hits: Array[String] = []
		for p2: String in files:
			if p2 == self_path:
				continue
			var f3: FileAccess = FileAccess.open(p2, FileAccess.READ)
			if f3 == null:
				continue
			if f3.get_as_text().contains(frag):
				hits.append(String(p2).replace("res://", ""))
		var shown: String = frag if frag.length() <= 34 else frag.substr(0, 31) + "..."
		print("  impl \"%s\": in %d file(s)" % [shown, hits.size()])
		_check(hits.size() == 1,
			"the implementation \"%s\" is in exactly one file and found %d%s"
				% [shown, hits.size(), "" if hits.size() == 1 else " — " + ", ".join(hits)])
		if hits.size() == 1:
			_check(hits[0] == want2.replace("res://", ""),
				"\"%s\" lives in %s and it is in %s"
					% [shown, want2.replace("res://", ""), hits[0]])

	_check(unreadable.is_empty(),
		"every .gd file opened and returned text%s"
			% ("" if unreadable.is_empty() else " — could not read: " + ", ".join(unreadable)))
	_verdict("check_shared_constants",
		"one name, one value: a constant declared in many files is a constant nothing relates")
