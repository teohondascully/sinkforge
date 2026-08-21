extends "res://tools/check_base.gd"

## A CONSTANT DEFINED IN MANY PLACES IS A CONSTANT NOTHING RELATES.
##
## `const CELL: int = 32` is declared independently in TWENTY-FOUR files. They all agree today. Nothing
## in the tree could notice if one stopped agreeing: there is no shared owner, no import, and no assertion
## anywhere that compares them. The obvious reach is `FactorySim.CELL`, on the reasonable assumption
## that a grid constant lives with the grid, and it is not there either -- the name exists twenty-four
## times and belongs to no one.
##
## This is the runtime-invisible half of the defect class. A wrong value here does not crash and does not
## fail a test; it makes one file measure the world on a different ruler than its neighbours, and the
## symptom appears somewhere else entirely as a few pixels of drift.
##
## THE GUARD IS DELIBERATELY NOT A REFACTOR. Deriving all twenty-four from one owner is the real fix and
## it touches twenty-four files, which is not safe while several worktrees hold live work. This layer costs
## nothing, changes no behaviour, and makes the drift impossible to introduce silently in the meantime.
## When the tree is quiet, replace the duplicates and delete this.
##
## It reads SOURCE, so every line it prints is a statement about ONE CHECKOUT. It prints which.

## Names that must agree everywhere they are declared, with the value they must hold.
const SHARED: Dictionary = {
	"CELL": 32.0,
}

## Files exempt from a given name, with the reason. Empty on purpose: an exemption list that starts
## populated is an exemption list nobody audits.
const EXEMPT: Dictionary = {}

## EACH ASSERTION IS PROVED SEPARATELY, because one mutant leaves the others unproven.
##
## This layer makes three claims and they fail to different things, so a single control would have left
## two of them untested while the run looked fully controlled:
##
##   mutant                                     floor      agreement   opened
##   scenes/sfx.gd CELL 32 -> 33                PASS       **FAIL**    PASS
##   _walk skips tools/ (7 sites found, not 24) **FAIL**   PASS        PASS
##
## The second row is the one that matters. With seventeen files missed, "every declaration holds 32.0" is
## still TRUE -- seven were found and all seven agreed -- so the agreement check is vacuously satisfiable
## by a scan that barely ran. The floor is the only thing standing between this layer and a green line
## that means nothing, and it is provably not the same assertion as the one it protects.
##
## NOT PROVED: the third claim, that every .gd file opened and returned text. Reaching it needs a file
## that exists and cannot be read, which I have not staged. It is recorded as unproven rather than assumed
## to work, because an untested assertion is exactly what the other two rows are about.
const FLOOR: int = 20   ## fewer declarations than this and the scan found nothing, which is not a pass


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
		_check(sites.size() >= FLOOR,
			"%s: found %d declarations, at least %d expected — fewer means the scan missed files, and a"
				% [name, sites.size(), FLOOR] + " scan that found nothing agrees with itself trivially")
		_check(wrong.is_empty(),
			"%s: every declaration holds %s%s"
				% [name, want, "" if wrong.is_empty() else " — DISAGREE: " + ", ".join(wrong)])

	_check(unreadable.is_empty(),
		"every .gd file opened and returned text%s"
			% ("" if unreadable.is_empty() else " — could not read: " + ", ".join(unreadable)))
	_verdict("check_shared_constants",
		"one name, one value: a constant declared in many files is a constant nothing relates")
