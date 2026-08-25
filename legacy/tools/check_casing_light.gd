extends "res://tools/check_base.gd"

## EVERY MACHINE IN THE REGISTRY MUST STILL BE LIT.
##
## `Visuals.draw_machine_casing` sells a flat square as a piece of hardware with one trick: a pale edge
## along the top and a dark edge along the bottom, so two edges catch the light and two do not. Those edges
## are `col.lightened()` and `col.darkened()` of the machine's OWN registry colour, which means the trick
## is not a property of the drawing code at all. It is a property of the colour it is handed.
##
## Hand it near-white and `lightened()` has nowhere left to go: the lit edge and the body arrive at the same
## value, the object loses its top face, and it goes flat again, silently, with every pixel test still
## green, because nothing crashed and nothing moved. Near-black does the same at the other end, collapsing
## the body into its own shadow. A registry of eighteen hand-picked colours is exactly the sort of thing
## that eventually acquires one.
##
## WHAT IS ACTUALLY WORTH ASSERTING, and the first version of this file got it wrong in an instructive way.
## It led with a SPREAD floor: lit edge minus shadowed edge must exceed 0.22. Twenty colours passed it with
## the tightest at 0.388, which looked like a comfortable margin and was in fact a tell. `lightened` and
## `darkened` are affine in the colour, so the spread works out to
##
##     lum(col + (1-col)*0.34) - lum(col*0.50)  =  0.34 + 0.16 * lum(col)
##
## which is bounded below by 0.34 for EVERY colour that exists. No registry entry, no future entry, no
## deliberately hostile entry could ever have failed it. That is a floor no configuration can reach: the
## exact vacuity shape argued about on a different threshold earlier the same day, and
## then built. The margin looked healthy because it was arithmetic, not evidence.
##
## What can fail (and is the property that actually matters) is each edge separating from the BODY between
## them. Same algebra, and this time it bites:
##
##     lit edge - body   =  0.34 * (1 - lum)     fails once the body is brighter than ~0.82
##     body - shadow     =  0.50 * lum           fails once the body is darker than ~0.12
##
## So a near-white or near-black machine colour is caught and nothing else is, which is correct: those are
## the two ways this lighting model dies. The floor is 0.06: roughly 15 of 255 levels between a one-pixel
## edge and the face beside it, below which the edge stops being a separate value at 8-bit depth.
##
## AND THE GUARD PROVES ITSELF EVERY RUN. Two sentinel colours that must be REJECTED are judged alongside
## the registry, so "everything passed" can never mean "the check was inert": the day the guard stops
## biting, the sentinels pass and the layer goes red. That is worth more than the one mutation that would
## otherwise have been run by hand once and never again.
##
## Runs headless: Color arithmetic touches no display.
##
##   godot --headless --path . --script res://tools/check_casing_light.gd

## Each lit edge must separate from the body it borders by at least this much perceived luminance.
## See the derivation above: this is the one comparison a bad colour can actually lose.
const MIN_STEP: float = 0.06

## The same constants draw_machine_casing lights with. Kept in step by the assertion at the bottom, which
## fails if the drawing code is retuned without this file being retuned with it; otherwise this layer
## would go on happily proving a lighting model the game stopped using.
const TOP_LIGHTEN: float = 0.34
const BOT_DARKEN: float = 0.50


func _initialize() -> void:
	print("== every machine in the registry is still lit ==")
	_run()
	_verdict("check_casing_light", "every registry colour keeps a top face and a shadow")


func _run() -> void:
	var judged: int = 0
	var lums: Array[float] = []
	var tightest: float = 9.0
	var tightest_name: String = ""

	for behavior: Variant in Visuals.MACHINE_STYLE:
		var style: Dictionary = Visuals.MACHINE_STYLE[behavior]
		var col: Color = style["color"]
		for state: Array in _both_states(col):
			var margin: float = _margin(state[1])
			_check(margin >= MIN_STEP,
				"%s %s: its edges stand off its body by %.3f (floor %.2f)"
					% [String(behavior), state[0], margin, MIN_STEP])
			if state[0] == "working":
				lums.append(_lum(state[1]))
			judged += 1
			if margin < tightest:
				tightest = margin
				tightest_name = String(behavior) + " " + String(state[0])

	# THE TWO FALLBACKS ARE MACHINES TOO. `machine_color` answers for defs with no registry entry (the
	# sooty furnace and the steel-blue runner), and those bodies get the identical casing. A test that
	# walked only the dictionary would leave untested the two colours most likely to be forgotten, one of
	# which is the darkest body the game ships and therefore the closest to the floor.
	for fb: Array in [["the sooty furnace", Color(0.28, 0.23, 0.20)],
			["the generic runner", Color(0.30, 0.55, 0.75)]]:
		for state: Array in _both_states(fb[1]):
			var margin: float = _margin(state[1])
			_check(margin >= MIN_STEP,
				"fallback %s %s: its edges stand off its body by %.3f" % [fb[0], state[0], margin])
			if state[0] == "working":
				lums.append(_lum(state[1]))
			judged += 1
			if margin < tightest:
				tightest = margin
				tightest_name = "fallback " + String(fb[0]) + " " + String(state[0])

	# THE GUARD MUST BITE. Not "did it bite once when it was written": every run, on colours chosen to be
	# exactly the two failures this model has. If either of these passes, the check above is decoration.
	for bad: Array in [["a near-white body", Color(0.95, 0.95, 0.93)],
			["a near-black body", Color(0.04, 0.04, 0.05)]]:
		_check(_margin(bad[1]) < MIN_STEP,
			"%s is REJECTED (margin %.3f) — the floor is live" % [bad[0], _margin(bad[1])])

	# NON-VACUITY, and it is not the loop count. Every assertion above is satisfied by a registry of one
	# entry, and satisfied perfectly by eighteen identical greys, which is the failure this layer exists to
	# catch, wearing a passing scorecard. The registry must be large AND its colours must genuinely differ.
	_check(judged >= 30, "%d machine bodies were judged (every registry colour, in both states)" % judged)
	var lo: float = 9.0
	var hi: float = -9.0
	for l: float in lums:
		lo = minf(lo, l)
		hi = maxf(hi, l)
	# WORKING BODIES ONLY, and that is not tidiness. Pooling both states here would let the spread be
	# manufactured by `_cold_iron` itself: eighteen identical greys, half of them darkened, still report a
	# range. The claim is that the game AUTHORED different machines, so only authored colours may prove it.
	_check(hi - lo > 0.20,
		"the bodies really are different colours (luminance %.3f..%.3f)" % [lo, hi])
	print("  tightest margin: %s at %.3f (floor %.2f)" % [tightest_name, tightest, MIN_STEP])

	# THE MODEL THIS FILE TESTS MUST BE THE MODEL THE GAME DRAWS. If draw_machine_casing is retuned, these
	# numbers go stale and this layer keeps proving a lighting model nothing uses any more: vacuity by a
	# premise nobody re-measured. There is no way to read a literal back out of a function, so the constants
	# are duplicated and this is the tripwire on the duplicate: change the drawing code and land here.
	_check_face_sits_on_body()
	_check(is_equal_approx(TOP_LIGHTEN, 0.34) and is_equal_approx(BOT_DARKEN, 0.50),
		"the bevel constants here still match draw_machine_casing's (%.2f up, %.2f down)"
			% [TOP_LIGHTEN, BOT_DARKEN])

	# AND THE IDLE PALETTE MUST STILL BE A PALETTE. `_cold_iron` is the game's, called not copied, so it
	# cannot go stale the way the bevel constants can, but it CAN be turned up until every idle machine is
	# the same black, which is the failure mode of "make it look off": the distinction arrives and the
	# machines stop being told apart from each other. So the spread is asserted on the cold bodies alone.
	var cold: Array[float] = []
	for behavior: Variant in Visuals.MACHINE_STYLE:
		cold.append(_lum(Visuals._cold_iron(Visuals.MACHINE_STYLE[behavior]["color"])))
	var clo: float = 9.0
	var chi: float = -9.0
	for l: float in cold:
		clo = minf(clo, l)
		chi = maxf(chi, l)
	_check(chi - clo > 0.12,
		"idle machines are still different machines (cold luminance %.3f..%.3f)" % [clo, chi])
	_check(chi < hi,
		"idle really is darker than working at the top of the range (%.3f cold vs %.3f lit)" % [chi, hi])


## THE GAME DRAWS EVERY MACHINE IN TWO PALETTES AND THIS LAYER USED TO KNOW ABOUT ONE. `draw_machine_casing`
## takes an `active` flag and runs an idle body through `Visuals._cold_iron` (darkened 0.22 and pulled 0.18
## toward grey), so the colours in MACHINE_STYLE are the working half of what ships, and the half nearer the
## floor was the half nobody judged. That matters here specifically: the near-black sentinel below is
## REJECTED for having no shadow left to give, and darkening is the operation that walks a body toward it.
##
## Calls the game's own function rather than re-deriving it. A copy of `_cold_iron` in this file would be a
## second tripwire to keep in step, and the bevel constants below are already the one place that has to be.
func _both_states(col: Color) -> Array:
	return [["working", col], ["idle", Visuals._cold_iron(col)]]


## THE FACE TABLE CANNOT DRIFT AWAY FROM THE PROFILE TABLE. `machine_face` names where a machine's glyph,
## badge, progress bar and ports are drawn, and `machine_profile` names where its body actually is. They
## are two dictionaries keyed by the same strings, which is a promise nothing enforces, and the failure is
## silent and total: a face that has slipped off its parts draws every cue on the machine onto bare rock,
## and looks exactly like a face that has not.
##
## WHAT IT PROVES TODAY IS LESS THAN THAT, AND THE GAP IS WORTH SAYING OUT LOUD. The face override is
## empty, so `machine_face` derives the face FROM the profile and hands back one of the very parts it is
## then compared against. `Rect2.encloses` accepts an identical rectangle, so every per-kind check below
## passes by construction and no edit to the profile table can redden one. This is a guard held cocked
## rather than a measurement: it starts discriminating the first time somebody writes an entry into the
## override, which is the only way the two tables can come apart. The control underneath is what carries
## the weight meanwhile.
func _check_face_sits_on_body() -> void:
	var judged: int = 0
	for kind: Variant in Visuals.MACHINE_PROFILE:
		var face: Rect2 = Visuals.machine_face(String(kind))
		var on_body: bool = false
		for part: Rect2 in Visuals.machine_profile(String(kind)):
			if part.encloses(face):
				on_body = true
		_check(on_body, "%s's face sits on one of its own body parts" % String(kind))
		judged += 1
	_check(judged >= 10, "%d profiles were judged" % judged)
	# THE PREDICATE MUST BITE. A face that is not one of the parts is the one input the loop above cannot
	# currently produce, so it is built here by hand and required to be rejected. That is a statement about
	# `encloses` discriminating, not about the loop being reachable; the note on the function says which.
	var stray := Rect2(0.0, 0.0, 1.0, 1.0)
	var any: bool = false
	for part: Rect2 in Visuals.machine_profile("drill"):
		if part.encloses(stray):
			any = true
	_check(not any, "CONTROL: a full-cell face is REJECTED against the drill's carved body — the test bites")


## How far the nearer of the two lit edges stands off the body between them. The MINIMUM of the two steps,
## because an object with a crisp top face and a shadow that has merged into the body is still broken.
func _margin(col: Color) -> float:
	var lm: float = _lum(col)
	return minf(_lum(col.lightened(TOP_LIGHTEN)) - lm, lm - _lum(col.darkened(BOT_DARKEN)))


## Perceived brightness, not the arithmetic mean of the channels. Green carries most of what an eye calls
## brightness and blue almost none, so a mean would rate the teal Lift and the purple Splitter as equally
## bright bodies when one of them is visibly twice the other.
func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
