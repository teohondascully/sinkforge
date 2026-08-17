extends "res://tools/check_base.gd"

## EVERY MACHINE IN THE REGISTRY MUST STILL BE LIT.
##
## `Visuals.draw_machine_casing` sells a flat square as a piece of hardware with one trick: a pale edge
## along the top and a dark edge along the bottom, so two edges catch the light and two do not. Those edges
## are `col.lightened()` and `col.darkened()` of the machine's OWN registry colour — which means the trick
## is not a property of the drawing code at all. It is a property of the colour it is handed.
##
## Hand it near-white and `lightened()` has nowhere left to go: the lit edge and the body arrive at the same
## value, the object loses its top face, and it goes flat again — silently, with every pixel test still
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
## deliberately hostile entry could ever have failed it. That is a floor no configuration can reach — the
## exact vacuity shape I had argued about a different threshold earlier the same day, and
## then built. The margin looked healthy because it was arithmetic, not evidence.
##
## What can fail — and is the property that actually matters — is each edge separating from the BODY between
## them. Same algebra, and this time it bites:
##
##     lit edge - body   =  0.34 * (1 - lum)     fails once the body is brighter than ~0.82
##     body - shadow     =  0.50 * lum           fails once the body is darker than ~0.12
##
## So a near-white or near-black machine colour is caught and nothing else is, which is correct: those are
## the two ways this lighting model dies. The floor is 0.06 — roughly 15 of 255 levels between a one-pixel
## edge and the face beside it, below which the edge stops being a separate value at 8-bit depth.
##
## AND THE GUARD PROVES ITSELF EVERY RUN. Two sentinel colours that must be REJECTED are judged alongside
## the registry, so "everything passed" can never mean "the check was inert" — the day the guard stops
## biting, the sentinels pass and the layer goes red. That is worth more than the one mutation I would
## otherwise have run by hand once and never again.
##
## Runs headless — Color arithmetic touches no display.
##
##   godot --headless --path . --script res://tools/check_casing_light.gd

## Each lit edge must separate from the body it borders by at least this much perceived luminance.
## See the derivation above: this is the one comparison a bad colour can actually lose.
const MIN_STEP: float = 0.06

## The same constants draw_machine_casing lights with. Kept in step by the assertion at the bottom, which
## fails if the drawing code is retuned without this file being retuned with it — otherwise this layer
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
		var margin: float = _margin(col)
		_check(margin >= MIN_STEP,
			"%s: its edges stand off its body by %.3f (floor %.2f)" % [String(behavior), margin, MIN_STEP])
		lums.append(_lum(col))
		judged += 1
		if margin < tightest:
			tightest = margin
			tightest_name = String(behavior)

	# THE TWO FALLBACKS ARE MACHINES TOO. `machine_color` answers for defs with no registry entry — the
	# sooty furnace and the steel-blue runner — and those bodies get the identical casing. A test that
	# walked only the dictionary would leave untested the two colours most likely to be forgotten, one of
	# which is the darkest body the game ships and therefore the closest to the floor.
	for fb: Array in [["the sooty furnace", Color(0.28, 0.23, 0.20)],
			["the generic runner", Color(0.30, 0.55, 0.75)]]:
		var margin: float = _margin(fb[1])
		_check(margin >= MIN_STEP,
			"fallback %s: its edges stand off its body by %.3f" % [fb[0], margin])
		lums.append(_lum(fb[1]))
		judged += 1
		if margin < tightest:
			tightest = margin
			tightest_name = "fallback " + String(fb[0])

	# THE GUARD MUST BITE. Not "did it bite once when I wrote it" — every run, on colours chosen to be
	# exactly the two failures this model has. If either of these passes, the check above is decoration.
	for bad: Array in [["a near-white body", Color(0.95, 0.95, 0.93)],
			["a near-black body", Color(0.04, 0.04, 0.05)]]:
		_check(_margin(bad[1]) < MIN_STEP,
			"%s is REJECTED (margin %.3f) — the floor is live" % [bad[0], _margin(bad[1])])

	# NON-VACUITY, and it is not the loop count. Every assertion above is satisfied by a registry of one
	# entry, and satisfied perfectly by eighteen identical greys — which is the failure this layer exists to
	# catch, wearing a passing scorecard. The registry must be large AND its colours must genuinely differ.
	_check(judged >= 15, "%d machine colours were judged" % judged)
	var lo: float = 9.0
	var hi: float = -9.0
	for l: float in lums:
		lo = minf(lo, l)
		hi = maxf(hi, l)
	_check(hi - lo > 0.20,
		"the bodies really are different colours (luminance %.3f..%.3f)" % [lo, hi])
	print("  tightest margin: %s at %.3f (floor %.2f)" % [tightest_name, tightest, MIN_STEP])

	# THE MODEL THIS FILE TESTS MUST BE THE MODEL THE GAME DRAWS. If draw_machine_casing is retuned, these
	# numbers go stale and this layer keeps proving a lighting model nothing uses any more — vacuity by a
	# premise nobody re-measured. There is no way to read a literal back out of a function, so the constants
	# are duplicated and this is the tripwire on the duplicate: change the drawing code and land here.
	_check(is_equal_approx(TOP_LIGHTEN, 0.34) and is_equal_approx(BOT_DARKEN, 0.50),
		"the bevel constants here still match draw_machine_casing's (%.2f up, %.2f down)"
			% [TOP_LIGHTEN, BOT_DARKEN])


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
