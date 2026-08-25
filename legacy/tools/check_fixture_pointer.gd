extends SceneTree

## THE GUARD THAT DECIDES WHETHER A RUN COUNTED. `FixturePointer` exists to turn "a person moved the mouse
## while we were measuring" from a FAIL into a VOID, so this has to be right in both directions: a guard
## that never fires voids nothing and we keep chasing phantom projection bugs, and a guard that always
## fires voids every aim assertion we own and the layers stop meaning anything.
##
## Needs no Godot window and no pointer: every case drives synthetic positions through `_feed`, which is
## why that seam exists. Proving this by warping a real cursor around would mean grabbing the pointer of
## the person this whole mechanism is meant to stop bothering.

const SKIP_CODE: int = 42
## PRELOAD, not the bare `class_name`. A freshly written script's global class is not in the project's
## script-class cache until Godot rescans, so `FixturePointer` parses as an undeclared identifier on the
## very first run — which is exactly the run you want the guard to work on.
const FixturePointer := preload("res://tools/fixture_pointer.gd")

var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  %s" % label)
	else:
		printerr("  FAIL  %s" % label)
		_fails += 1


## ONE definition of "this line calls warp_mouse", used by the scan AND by the assertions that prove the
## scan works. Two copies would let the test pass while the scanner drifted.
func _is_warp_line(line: String) -> bool:
	var t: String = line.strip_edges()
	return not t.begins_with("#") and t.contains("warp_mouse(")


## And ONE definition of "this line reads the OS pointer", for the same reason. The seam is DESCRIBED in
## prose in a dozen places across the tree and prose cannot read a cursor.
func _is_cursor_line(line: String) -> bool:
	var t: String = line.strip_edges()
	if t.begins_with("#"):
		return false
	return t.contains("get_global_mouse_position(") or t.contains("get_mouse_position(")


## Every `.gd` under a directory, recursively. `DirAccess.get_files()` does not descend, and the game side
## of this scan has to reach `src/core`, `src/data` and `scenes/` alike -- a scanner that silently stops at
## the top level would report a clean tree it had mostly not opened.
func _gd_files(root: String, out: Array[String]) -> void:
	var dir := DirAccess.open(root)
	if dir == null:
		return
	for f: String in dir.get_files():
		if f.ends_with(".gd"):
			out.append(root + "/" + f)
	# `get_directories()`, and the first draft wrote `get_dirs()`, which does not exist. GDScript resolves
	# that at RUNTIME, so the parse check was clean, the walker never descended, and the scan reported a
	# clean tree over the 23 top-level scripts it managed to open before the error. The `scanned >= 40`
	# floor below is the only reason that surfaced as a red instead of a pass.
	for d: String in dir.get_directories():
		_gd_files(root + "/" + d, out)


func _initialize() -> void:
	print("== a human at the keyboard is a contaminant, and this is how we notice ==")

	# --- IT DOES NOT FIRE ON A QUIET BOX ---
	var quiet := FixturePointer.new(null)
	for _i: int in 40:
		quiet._feed(Vector2(640.0, 360.0))
	_check(not quiet.contaminated(), "an untouched pointer is NOT contamination (40 identical samples)")
	_check(quiet.reason().contains("OURS"),
		"...and it says so: an aim failure on a quiet box is our bug, not the user's hand")

	# --- SUB-PIXEL JITTER IS NOISE, NOT A HAND ---
	var jitter := FixturePointer.new(null)
	for i: int in 40:
		jitter._feed(Vector2(640.0 + 0.4 * float(i % 2), 360.0))
	_check(not jitter.contaminated(),
		"sub-pixel jitter is noise, not a hand (below TOL_PX %.1f)" % FixturePointer.TOL_PX)

	# --- IT FIRES ON A REAL MOVE ---
	var touched := FixturePointer.new(null)
	for _i: int in 20:
		touched._feed(Vector2(640.0, 360.0))
	touched._feed(Vector2(772.3, 360.0))          # the 132.3 px that started this
	for _i: int in 19:
		touched._feed(Vector2(772.3, 360.0))
	_check(touched.contaminated(), "a 132.3 px jump IS contamination — the number that misled me")
	_check(touched.reason().contains("VOID"),
		"...and the verdict is VOID, not failed — the distinction that cost real edits")

	# --- NON-VACUITY: THE NUMBERS IN THE REASON ARE REAL, NOT DECORATION ---
	# A reason that always printed the same string would satisfy the two `contains` checks above while
	# telling a reader nothing. These assert the accounting actually tracked what happened.
	var r: String = touched.reason()
	_check(r.contains("1 of 40"), "...and it reports HOW MANY samples moved (1 of 40), not just that one did")
	_check(r.contains("132"), "...and the largest jump is the real magnitude, carried into the message")

	# --- IT COUNTS EVERY MOVE, NOT JUST THE FIRST ---
	var many := FixturePointer.new(null)
	for i: int in 30:
		many._feed(Vector2(100.0 * float(i), 0.0))
	_check(many.reason().contains("29 of 30"),
		"a pointer moving all run counts every move (29 of 30), so travel is not understated")

	# --- THE FIXTURE-SIDE HALF OF INP-01, AS A RATCHET ---
	# The GAME side is closed: `scenes/` now has zero raw cursor reads outside the seam in
	# `controls.gd`. The assertion that would actually close the FIXTURE side is "no fixture calls
	# warp_mouse". It was written as a RATCHET rather than a ban because ten real calls remained at the
	# time -- a guard that fails on arrival gets disabled, and a guard that quietly asserts nothing is
	# worse. THE DEBT IS NOW PAID: every one of the ten has moved to `Controls.pose_pointer`, so the
	# ratchet has been tightened to its floor and this IS the flat ban the paragraph above wanted.
	# The machinery is kept rather than deleted, because a ban is only the ratchet with an empty budget,
	# and a reappearance has to fail by the same rule that a regression would have.
	#
	# Why it matters that these are named rather than counted in aggregate: `warp_mouse` moves the ACTUAL
	# cursor on the user's actual desk. Every one of these is both a measurement that depends on nobody
	# touching the mouse AND a fixture reaching over to move a working person's pointer. capture_moments
	# held seven of the ten and they were the ones that write into `history/`.
	#
	# WHY THE BUDGET IS EMPTY, STATED SO IT CANNOT ROT AGAIN. check_hud_layout (2), check_frametime (1)
	# and check_grapple_reads (5) moved to `Controls.pose_pointer` first; capture_moments' seven followed,
	# and the six sites that regenerated `history/` PNGs now carry a "POSED, NOT WARPED, AT PROVABLY THE
	# SAME POINT" comment where the call used to be. An entry left at 7 against a real count of 0 is not a
	# harmless leftover: it is SEVEN CALLS OF SLACK on a debt that was already paid, and every one of them
	# would move a working person's cursor across their desk without turning this layer red. A ratchet that
	# is not tightened when the debt is paid stops being a bound and becomes a licence.
	# A SCAN THAT READ NOTHING SCORED CLEAN, and this was a review finding, in the same function as the fix for
	# it: sixty lines down the game-side scan makes an unreadable file an OFFENDER and asserts a concrete
	# population floor. This one did neither. `DirAccess.open` returning null skipped the entire loop;
	# `FileAccess.open` returning null `continue`d past the file; `found` stayed empty either way, so `over`
	# was empty and the budget assertion PASSED over zero files. The layer printed "0 calls across 0 file(s)"
	# and reported success.
	#
	# WHAT MADE IT INVISIBLE IS WORTH MORE THAN THE FIX. The three assertions beneath it are controls on the
	# PREDICATE -- they prove `_is_warp_line` recognises a real call, and refuses a comment about one, and
	# refuses a doc comment. All three genuinely run and genuinely pass. **A control on the predicate is not
	# a control on the population.** Together they answer "does my detector work" and nothing at all
	# answered "did my detector look at anything". An assertion counter cannot see the difference: the layer
	# reports several real assertions either way.
	var budget: Dictionary = {}
	var found: Dictionary = {}
	var opened: int = 0
	var unreadable: Array[String] = []
	var dir := DirAccess.open("res://tools")
	if dir == null:
		unreadable.append("res://tools (the directory itself would not open)")
	else:
		for f: String in dir.get_files():
				if not f.ends_with(".gd") or f.begins_with("_scratch_"):
					continue
				# THE SCANNER CANNOT SCAN ITSELF. This file has to contain the literal token in order to look
				# for it, so an unguarded sweep counts its own search string as a call, finds it over a budget
				# of zero, and fails on arrival. Named explicitly rather than pattern-dodged, because the only
				# safe exclusion is one a reader can see is the detector and not a subject.
				if f == "check_fixture_pointer.gd":
					continue
				var txt: FileAccess = FileAccess.open("res://tools/" + f, FileAccess.READ)
				if txt == null:
					unreadable.append(f)
					continue
				opened += 1
				var n: int = 0
				while not txt.eof_reached():
					var line: String = txt.get_line()
					if _is_warp_line(line):
						n += 1
				if n > 0:
					found[f] = n
	var over: Array[String] = []
	for f: String in found.keys():
		var allowed: int = int(budget.get(f, 0))
		if int(found[f]) > allowed:
			over.append("%s has %d (budget %d)" % [f, found[f], allowed])
	# THE POPULATION, ASSERTED RATHER THAN PRINTED. The floor is concrete for the same reason the game-side
	# one is: `tools/` has carried well over sixty `.gd` fixtures for a long time, so a collapse below that
	# is a scan that failed, not a directory that emptied.
	_check(opened >= 60, "(setup) the warp scan opened %d fixture scripts under tools/" % opened)
	_check(unreadable.is_empty(),
		"(setup) every fixture under tools/ could be read (%s)"
			% ("all readable" if unreadable.is_empty() else "COULD NOT READ: " + ", ".join(unreadable)))
	_check(over.is_empty(),
		"no fixture gained a new warp_mouse call — it moves the USER'S cursor (%s)"
			% ("all within budget" if over.is_empty() else ", ".join(over)))
	# NON-VACUITY, and the first version got this WRONG in a way worth recording: it asserted
	# `total >= 10`, tying "the scanner works" to "the debt still exists". Nine of the ten sites were then
	# paid off within the hour and the assertion would have gone red for the best possible reason.
	# **A guard that fails when the problem is FIXED is measuring the problem, not the guard.** So prove
	# the classifier on synthetic lines instead, which holds whether the debt is ten or zero.
	_check(_is_warp_line("\tvp.warp_mouse(vp.get_canvas_transform() * world)"),
		"...and the scanner recognises a real call")
	_check(not _is_warp_line("# the fixture used to warp_mouse(...) here"),
		"...and does NOT count a comment about one")
	_check(not _is_warp_line("\t## `warp_mouse(` moves the user's actual cursor"),
		"...and does not count a doc comment either")
	var total: int = 0
	for f: String in found.keys():
		total += int(found[f])
	print("    warp_mouse debt: %d calls across %d file(s)" % [total, found.size()])

	# --- AND THE GAME SIDE OF INP-01, OVER THE WHOLE TREE ---
	# This assertion already existed, in `check_grapple_reads`, over a HARDCODED LIST OF THREE FILES --
	# main.gd, hud.gd, world_renderer.gd -- and that layer says so in its own header, because a guard whose
	# claim outruns its population is the failure this repository keeps rediscovering. It was honest about
	# the limit and the limit was still a hole: a NEW file under `scenes/` or `src/` that read the OS
	# cursor would be invisible to it, and the list is maintained by hand.
	#
	# It also lived in the wrong layer. `check_grapple_reads` is exclusive AND needs a surface, so it runs
	# in the display job only; this is a text scan that needs neither, and here it runs in both jobs.
	#
	# THE MEASURED ANSWER TODAY IS TWO, BOTH INSIDE THE SEAM. `controls.gd` is the one file allowed to touch
	# the OS pointer -- `pointer_world()` and the raw read beneath it are what everything else goes through,
	# and `pose_pointer()` is what lets a fixture state a world point without a cursor existing at all.
	# Named as an exclusion rather than pattern-dodged, on the same rule the warp scan uses above: the only
	# safe exclusion is one a reader can see is the seam and not a subject.
	var cursor_files: Array[String] = []
	_gd_files("res://scenes", cursor_files)
	_gd_files("res://src", cursor_files)
	var raw: Array[String] = []
	var scanned: int = 0
	for path: String in cursor_files:
		if path == "res://scenes/controls.gd":
			continue
		var cf: FileAccess = FileAccess.open(path, FileAccess.READ)
		if cf == null:
			raw.append("%s (unreadable)" % path)
			continue
		scanned += 1
		var ln: int = 0
		while not cf.eof_reached():
			ln += 1
			if _is_cursor_line(cf.get_line()):
				raw.append("%s:%d" % [path, ln])
	# A ZERO-RESULT SEARCH IS EVIDENCE ABOUT THE SEARCH until the search is shown to have happened. The
	# floor is concrete rather than `> 0`: the tree has carried well over forty scripts under these two
	# directories for a long time, and a collapse below that is a walker that stopped descending, not a
	# repository that shrank.
	_check(scanned >= 40,
		"(setup) the game-side scan opened %d scripts under scenes/ and src/" % scanned)
	_check(raw.is_empty(),
		"no shipped script outside the controls.gd seam reads the OS cursor (%s)"
			% ("clean" if raw.is_empty() else ", ".join(raw)))
	# NON-VACUITY for the classifier, on synthetic lines, for the same reason the warp one is done this
	# way: tying "the scanner works" to "the debt still exists" makes the guard go red the day it is fixed.
	_check(_is_cursor_line("\tvar w := vp.get_mouse_position()"), "...and the scanner recognises a raw read")
	_check(not _is_cursor_line("## `get_global_mouse_position()` is what this seam replaces"),
		"...and does NOT count the prose describing the seam")
	print("    OS-cursor reads outside the seam: %d, across %d scanned script(s)" % [raw.size(), scanned])

	print()
	if _fails == 0:
		print("check_fixture_pointer: PASS — contamination is detected, and quiet is not called dirty")
		quit(0)
		return
	printerr("check_fixture_pointer: FAIL (%d)" % _fails)
	quit(1)
