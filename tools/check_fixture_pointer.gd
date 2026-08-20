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
		"...and the verdict is VOID, not failed — the distinction the peer lost edits to")

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

	print()
	if _fails == 0:
		print("check_fixture_pointer: PASS — contamination is detected, and quiet is not called dirty")
		quit(0)
		return
	printerr("check_fixture_pointer: FAIL (%d)" % _fails)
	quit(1)
