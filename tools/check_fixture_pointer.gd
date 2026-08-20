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
	# warp_mouse", and it cannot be written as a flat ban today because ten real calls remain. A guard that
	# fails on arrival gets disabled, and a guard that quietly asserts nothing is worse -- so this is a
	# RATCHET: the known sites are written down by name and count, and the number may fall but never rise.
	#
	# Why it matters that these are named rather than counted in aggregate: `warp_mouse` moves the ACTUAL
	# cursor on the user's actual desk. Every one of these is both a measurement that depends on nobody
	# touching the mouse AND a fixture reaching over to move a working person's pointer. capture_moments
	# holds seven of the ten and they are the ones that write into `history/`.
	# Budget, not a ban: these may only ever FALL. check_hud_layout (2), check_frametime (1) and
	# check_grapple_reads (5) have moved to `Controls.pose_pointer` and those entries are gone rather than
	# zeroed, so a reappearance is caught by the unlisted-file rule below. capture_moments keeps seven
	# because six of them regenerate PNGs that are byte-identical to curated `history/` entries and one
	# tuned shipped constants -- that is a phased job behind a baseline capture, not a bulk sed.
	var budget: Dictionary = {
		"capture_moments.gd": 7,
	}
	var found: Dictionary = {}
	var dir := DirAccess.open("res://tools")
	if dir != null:
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
				continue
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

	print()
	if _fails == 0:
		print("check_fixture_pointer: PASS — contamination is detected, and quiet is not called dirty")
		quit(0)
		return
	printerr("check_fixture_pointer: FAIL (%d)" % _fails)
	quit(1)
