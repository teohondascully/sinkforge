extends "res://tools/check_base.gd"

## DOES THE GRAPPLE LOOK LIKE A TOOL, OR LIKE THE GEOMETRY SOMEBODY DEBUGGED IT WITH?
##
## `check_grapple` already scores the four properties the FUN is made of: it bites, it swings, it lifts,
## it crosses. Every one of them is a fact about the body's velocity, and not one of them would change by a
## single number if the rope were drawn as a magenta line with an arrow on it. `GR-01`–`GR-07` are the
## other half, and they are a different instrument:
##
##   `GR-01`  the persistent dashed guide reads as construction geometry, not as a tool
##   `GR-02`  aim and attachment are visually conflated
##   `GR-03`  tension has no visible state in a still frame
##   `GR-04`  the guide rivals the miner's silhouette against calm sky. REPRODUCES, and it is the endpoint
##            MARK rather than the lead: the same preview adds ~15 levels of edge on dark rock and its ring
##            alone carries ~208 against open sky. Reported, never asserted: how loud an aim mark should be
##            is a design call, and the two numbers a floor would compare are not the same quantity.
##   `GR-05`  the preview occupies most of the frame instead of the endpoint
##   `GR-06`  the player must out-rank their own tool telemetry
##   `GR-07`  judge it in motion, not only in screenshots
##
## **THE FIRST JOB IS NOT TO FIX THESE, IT IS TO FIND OUT WHICH ARE STILL TRUE.** `UI-01` in this same
## programme turned out to be aimed at a property the code does not have (its bubble is anchored to the
## body, not the screen), and the complaint survived while the diagnosis did not. Two of these read the
## same way on inspection: `_draw_aim_ghost` returns early while `grapple.live()`, so aim and rope are
## never on screen together (`GR-02`), and `_draw_cord` bows the line by its slack, so tension is already
## form rather than UI (`GR-03`). Both were MEASURED here rather than argued, and the measurement split
## them. `GR-02` was already satisfied. `GR-03` was not: the bow was a flat 26 pixels regardless of how much
## line was out, and measured as a share of its own chord a rope at 0.55 slack departed it by **0.013**
## against a bar-taut **0.012**. Those are the same picture. The ticket was right, and the code read as
## though it disagreed, which is the most expensive kind of wrong comment there is.
##
## HOW THE GUIDE IS ISOLATED, and this comment described the opposite of the code for one commit, which is
## the failure the paragraph above is about. The first version parked the cursor ON the miner's own hand
## for the reference frame, so no test switch was needed. And that also swings the HEAD-LAMP, which is
## aimed. Five and a half cells of light moved between the two captures and the difference mask ate it;
## excluding a lamp-sized disc to compensate then blinded the layer to the near field, the only place a
## shortened lead lives, and it measured 0.04 of the throw inked while seeing the endpoint ring alone.
##
## So there IS a switch (`RopeView.AIM_GHOST_OFF`), and the reference frame has the cursor in exactly
## the same place, the lamp in exactly the same position, and the body in exactly the same pose. The
## difference is the preview and nothing else.
##
##   godot --path . --script res://tools/check_grapple_reads.gd
##
## `SF_GREADS_DUMP=<dir>` writes every capture and every mask.

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 40
const CELL: int = FactorySim.CELL

## The rig: a wide pocket of open sky with a thick ceiling to bite and a floor to stand on. Copied in shape
## from `check_grapple`, for the same reason it gives: nothing about this may depend on worldgen.
const RIG_LEFT: int = 14
const RIG_RIGHT: int = 46
## The ceiling is TEN cells above the floor and the target eight across, because `Grapple.MAX_RANGE` is
## fifteen cells of line and the first rig put the only anchor twenty-three away. The hook flew, ran out of
## winch and stowed, and the layer reported "the rig anchors" as a failure of the RENDERER.
const CEIL_ROW: int = 20
const FLOOR_ROW: int = 30

## Where the body stands, and what it aims at: a long diagonal, which is the shot the tickets are about.
const STAND_COL: int = RIG_LEFT + 5
const TARGET_COL: int = RIG_LEFT + 13
## A column far enough from spawn that the surface there is ordinary ground rather than the opening scene's
## dug pit, and the sky above it is the flat daylight gradient the ticket is about.
const SKY_COL: int = 96
const HAND_RADIUS: float = 14.0       ## excluded from the guide mask — the collapsed preview's own origin

## How far from the background a pixel must be to count as drawn ON it. Read against a measured
## still-frame noise floor, printed every run.
const DRAW_LEVEL: float = 10.0

## Frames between the two reference captures. Long enough to contain the slow animations (the marker bob,
## the glint twinkle), because a control that samples faster than the thing it is controlling for is blind
## to exactly the parts of the frame that will contaminate the measurement.
const QUIET_GAP: int = 30
## HOW MANY periods the self-motion controls sample before believing a number. Three runs of an unchanged
## build put the single-sample version at 5.04%, 6.10% and 3.20% against a 6% ceiling; the count is here so
## a reader can see that the stability came from sampling and not from moving the line.
const SKY_PAIR_GAP: int = 4            ## the measurement's own separation; the exclusion uses the same one
## 9 x SKY_PAIR_GAP = 36 frames, one full period of the lamp's slower flicker term (2*PI/11.0 = 34.3).
const SKY_STILL_PAIRS: int = 9
const CHURN_SAMPLES: int = 4
const PHASE_SAMPLES: int = 3

## Half-width of the corridor the preview is measured in. Wide enough for the endpoint ring (6px radius, a
## 3px shade stroke) and the dashes' antialiasing, narrow enough that a glint two hundred pixels off the
## line cannot be mistaken for the tool.
const CORRIDOR_HALF: float = 44.0

## `GR-03`: how many times the rope's own animation the tension difference must clear. 3.0 was copied from
## `check_machine_state` before anything here had been measured, which is the habit this repository keeps
## catching itself in. It stays at 3.0 only because the measurement has since walked far past it, and the
## number now has both its sides: the sag-by-length rope and the flat-26px rope it replaced, on this same
## instrument, in the same rig.
const TENSION_MARGIN: float = 3.0

## `GR-03`: how far a slack line must hang below its own chord to read as hanging, as a share of that
## chord. Set from the two ropes measured on this instrument in this rig: the flat-26px rope bows **0.03**
## of its chord at 0.55 slack (a 14px deviation over 500px, which is a wobble), and the sag-by-length rope
## bows **0.42**, its cap. 0.15 sits between them with room on both sides, and it is a number a person can
## check against a screenshot with a ruler rather than a preference about how ropey a rope should look.
const BOW_FLOOR: float = 0.15

## `_bow_now`'s two ways of FAILING TO MEASURE, as values no real reading can collide with. They used to be
## `0.0` (a chord too short to have a direction) and `-1.0` (fewer than 40 cord pixels found), and both of
## them PASS at the call site: on the right-hand side of `bow_slack > bow_taut * 3.0`, `-1.0` becomes -3.0
## and `0.0` becomes 0.0, so a rope the mask never found reads as a rope that is perfectly taut. A number
## meaning "could not look" must never be arithmetic on the same axis as one meaning "looked".
const BOW_NO_CHORD: float = -101.0
const BOW_NO_CORD: float = -102.0
const BOW_BINS: int = 24
var _bow_best := PackedFloat32Array()
var _bow_hits := PackedInt32Array()
var _bow_over := PackedInt32Array()


## Stations along the chord that saw any cord-coloured pixel. A cord spans the chord; a patch does not.
func _bow_occupied() -> int:
	var n: int = 0
	for i: int in _bow_hits.size():
		if _bow_hits[i] > 0:
			n += 1
	return n


## The per-station profile as one line. A real cord is a smooth arc rising to the middle; a patch of
## rock the mask has mistaken for cord is a spike, and a mask admitting the whole corridor is a wall.
## Which of the three CI is looking at cannot be read off a single percentile, and is the whole question.
func _bow_sketch() -> String:
	var rim: float = maxf(_bow_rim() * _bow_span, 1.0)
	var out: String = ""
	for i: int in _bow_best.size():
		if _bow_best[i] < 0.0:
			out += "."
		else:
			out += str(clampi(int(_bow_best[i] / rim * 9.0), 0, 9))
	return out


## How many stations saw a pixel the renderer could not have drawn. Reported rather than used: a cord that
## reads clean at every station and a cord with a wall behind two of them are different situations, and a
## single number that had already discarded the wall could not tell them apart.
func _bow_over_stations() -> int:
	var n: int = 0
	for i: int in _bow_over.size():
		if _bow_over[i] > 0:
			n += 1
	return n


## WHAT MAKES A SET OF STATIONS A CORD, and the first version of this got it wrong in a way worth keeping.
##
## I required two thirds of the stations to be occupied. That rejected the TAUT arm at 13 of 24 while it
## was reading perfectly well, because a taut rope is a thinner thing than a slack one: fewer of its
## pixels clear `ROPE_TOL`, so it drops stations to antialiasing even where the cord plainly is. A count
## was measuring line width and calling it evidence.
##
## A cord runs from the hand to the piton, so the property that actually separates it from a patch is
## EXTENT: its occupied stations must reach across the chord. Dropouts in the middle are the mask
## blinking, not the rope stopping. The count floor stays only to stop two lone stations at opposite ends
## from qualifying as a span.
##
##     local taut    ......01111.00..00.0000.    13 stations, extent 6..22   a cord with gaps
##     local slack   33444..44..333...1111000    17 stations, extent 0..22   a cord
##
const BOW_MIN_EXTENT: float = 2.0 / 3.0
const BOW_MIN_STATIONS: float = 0.5


## WHERE THE ESTIMATOR IS WELL CONDITIONED. `_draw_cord` puts the departure at `sin(t * PI) * sag`, so
## every station is an independent estimate `sag = offset / sin(t * PI)` -- and near either end that
## divisor goes to zero and multiplies the cord's own half-width, and any noise, without limit. At
## `sin >= 0.70`, the central half of the chord, the amplification is at most 1.43x. This is a fact about
## the estimator rather than a number chosen to suit a reading.
const BOW_SIN_FLOOR: float = 0.70
## Fewer contributing stations than this and a median is not a median.
const BOW_MIN_EST: int = 4


## THE BOW AS THE MEDIAN OF PER-STATION ESTIMATES, which is what the shape of the cord makes available.
##
## `_bow_clean` takes the PEAK of the surviving profile, and a peak is a maximum: one contaminated station
## sets it, whatever the other twenty-three say. On the software renderer that is exactly what happens.
## Rejecting out-of-band pixels moved the reading from 0.4638 to 0.4106 and no further, because the thing
## at stations 17 to 20 straddles the band edge and its INSIDE half is still the largest offset present.
##
## The cord's own geometry gives a better answer. `_draw_cord` draws the hang as `sin(t * PI) * sag`, so
## each station carries an independent estimate of the SAME quantity, and the median of those survives a
## minority of contaminated stations in a way a maximum cannot. The half-width is subtracted first because
## the mask finds the stroke's outer edge, not its centreline.
##
## Returns `BOW_NO_CORD` rather than a small number when too few stations are usable, for the same reason
## as everything else on this axis: a failure to measure must not be arithmetic alongside a measurement.
func _bow_sag_median(span: float) -> float:
	var est: Array[float] = []
	for i: int in _bow_best.size():
		if _bow_best[i] < 0.0:
			continue
		var t: float = (float(i) + 0.5) / float(BOW_BINS)
		var k: float = sin(t * PI)
		if k < BOW_SIN_FLOOR:
			continue
		est.append(maxf(_bow_best[i] - RopeView.CORD_CORE_W * 0.5, 0.0) / k)
	if est.size() < BOW_MIN_EST:
		return BOW_NO_CORD
	est.sort()
	var mid: int = est.size() / 2
	var med: float = est[mid] if est.size() % 2 == 1 else (est[mid - 1] + est[mid]) * 0.5
	return med / maxf(span, 1.0)


## HOW MANY STATIONS AGREE WITH THE MEDIAN, which is the shape test the value alone cannot give.
##
## For a real hang every well-conditioned station estimates the SAME `sag`, because the offset is
## `sin(t * PI) * sag` and the estimator divides that back out. So the estimates should cluster. Anything
## that is not the hang -- rock inside `ROPE_TOL`, another rope, a hook -- lands at its own arbitrary
## distance and estimates something else. A tight cluster is a cord; a scatter is a mask that found
## several different objects and averaged them.
##
## Reported, not asserted, until it has been read on both renderers. What it is FOR: `pct99` returns the
## right number from the wrong place on this rig, 125px at t=0.19 where the cord can reach 71px, and no
## test on the VALUE can catch that. A test on the agreement can.
func _bow_agree(span: float) -> float:
	var mid: float = _bow_sag_median(span)
	if is_equal_approx(mid, BOW_NO_CORD) or mid <= 0.0:
		return -1.0
	var target: float = mid * span
	var near: int = 0
	var total: int = 0
	for i: int in _bow_best.size():
		if _bow_best[i] < 0.0:
			continue
		var t: float = (float(i) + 0.5) / float(BOW_BINS)
		var k: float = sin(t * PI)
		if k < BOW_SIN_FLOOR:
			continue
		total += 1
		var est: float = maxf(_bow_best[i] - RopeView.CORD_CORE_W * 0.5, 0.0) / k
		if absf(est - target) <= target * BOW_AGREE_BAND:
			near += 1
	return float(near) / maxf(float(total), 1.0)


## How far a station may sit from the median and still count as agreeing with it. A quarter is wide enough
## that antialiasing and the bin's own width do not disqualify a good station, and narrow enough that a
## contaminant at twice or half the hang does not slip in.
const BOW_AGREE_BAND: float = 0.25


## `_bow_sag_median` for the run log, sentinel spelled out.
func _bow_sag_str(span: float) -> String:
	var v: float = _bow_sag_median(span)
	if is_equal_approx(v, BOW_NO_CORD):
		return "TOO FEW STATIONS"
	return "%.4f" % v


## The bow, measured only from what the renderer could actually have drawn.
##
## THE FAILURE THIS REPLACES. `pct99` is a percentile over every cord-coloured pixel in the corridor, and
## the corridor is 24px wider than the clamp on purpose. On the software renderer the far end of the
## chord, stations 17 to 20 of 24, sits against something that fills that strip, and a percentile cannot
## tell "the rope hangs this far" from "a fifth of my pixels are not rope". Both arms read 0.4624 and
## 0.4634 against a rim of 0.4650: pinned, and pinned is not a measurement.
##
## Median filtering alone did not fix it and the profile shows why. The contaminated block is three to
## four stations WIDE, so a three-wide median sees a majority of contaminated neighbours and returns
## contamination. Width is what defeats a smoother, which is why the rejection has to come first and be
## about physics rather than about smoothness.
##
## Returns `BOW_NO_CORD` when too few stations survive, because a peak over a handful of stations is not
## a statement about a cord and must not be arithmetic on the same axis as one that is.
func _bow_clean(span: float) -> float:
	var first: int = -1
	var last: int = -1
	for i: int in _bow_best.size():
		if _bow_best[i] >= 0.0:
			if first < 0:
				first = i
			last = i
	if first < 0:
		return BOW_NO_CORD
	var extent: float = float(last - first + 1) / float(BOW_BINS)
	if extent < BOW_MIN_EXTENT or float(_bow_occupied()) < BOW_MIN_STATIONS * float(BOW_BINS):
		return BOW_NO_CORD
	var peak: float = 0.0
	for i: int in range(1, BOW_BINS - 1):
		if _bow_best[i - 1] < 0.0 or _bow_best[i] < 0.0 or _bow_best[i + 1] < 0.0:
			continue
		var t: Array[float] = [_bow_best[i - 1], _bow_best[i], _bow_best[i + 1]]
		t.sort()
		peak = maxf(peak, t[1])
	return peak / maxf(span, 1.0)


## `_bow_clean` for the run log, with the sentinel spelled rather than printed as a negative share.
func _bow_clean_str(span: float) -> String:
	var v: float = _bow_clean(span)
	if is_equal_approx(v, BOW_NO_CORD):
		return "TOO FEW STATIONS"
	return "%.4f" % v


## The peak of the per-station profile, median-filtered across neighbours so one contaminated station
## cannot set the answer while a real arc, which is smooth across its neighbours, survives.
func _bow_binned() -> float:
	var peak: float = 0.0
	for i: int in range(1, BOW_BINS - 1):
		if _bow_best[i - 1] < 0.0 or _bow_best[i] < 0.0 or _bow_best[i + 1] < 0.0:
			continue
		var t: Array[float] = [_bow_best[i - 1], _bow_best[i], _bow_best[i + 1]]
		t.sort()
		peak = maxf(peak, t[1])
	return peak

## ...and `_corridor_fill`'s, for the same reason and by the same rule. It used to answer a zero-length
## throw with `0.0`, which is a legal share and therefore indistinguishable from "the preview drew nothing
## across a real throw", and which sailed through the cap that used to stand at the call site. A value
## meaning "there was nothing to measure" must not be a legal value of the thing being measured.
const FILL_NO_SPAN: float = -103.0

## `GR-05`: how much of the throw the preview is allowed to draw.
##
## NO FLOOR IS SET AND THAT IS DELIBERATE. Guessing a bound before measuring has been wrong four times in
## this repository and every one of the guesses looked reasonable. The run reports; the number it reports
## is what a bound may later be argued from, once there is a decision about what the preview should be.
##
## AND FOR AS LONG AS THAT WAS TRUE THERE WAS ALSO A `_check` HERE, AGAINST `SPAN_CAP = 1.01`, WHICH COULD
## NOT FAIL. `_corridor_fill` resizes `bins` to `full`, writes only 0 or 1 into each element, sums them and
## returns `n / full`. So the value is bounded by 1.0 BY CONSTRUCTION and a cap of 1.01 sits above the
## largest number the expression can produce. Not a loose bound: an unsatisfiable-in-the-other-direction
## one. Every green "the aim preview inks 0.13 of the distance it is previewing (cap 1.01)" this layer has
## ever printed was an arithmetic identity wearing an assertion's clothes.
##
## **A DEFERRED FLOOR AND A GREEN LIGHT WIRED TO NOTHING LOOK IDENTICAL IN THE LOG**, and only one of them
## is honest. The decision not to bound `fill` yet is kept exactly as it was; what changes is that the
## layer now SAYS it has not bounded it, through `_stand_down`, so the runner reports the layer as having
## passed without verifying everything instead of counting a tautology as a test. That is the same shape
## this file already chose three times for `GR-04` at :517: report the measurement, state that the design
## call is not the harness's to make, assert nothing.
##
## No cap is invented here. Inventing one would be worse than the tautology, because it would look
## calibrated.

## `GR-06`: the miner must out-read their own telemetry. This one IS asserted, because it is not a matter
## of taste: a tool that is easier to see than the person holding it has inverted the frame.
const BODY_MARGIN: float = 1.15
## THE AIM GHOST'S CONTROL, AND A TIGHTER FLOOR FOR IT THAT WAS TRIED AND WITHDRAWN.
##
## `guide_edge > 1.0` cannot fail for the reason it is written. Removing every stroke `_draw_aim_ghost`
## makes still leaves a residual in this mask -- the head-lamp swings with the cursor, so the rock it lights
## is not identical between the two captures -- and that residual is four to five levels, not zero. The
## control passes on a frame with no preview in it, and the GR-06 comparison underneath then weighs the
## miner against a 4.6-level nothing.
##
## Measured, eight runs each side, the OFF side produced by returning from `_draw_aim_ghost` before it draws:
##
##     ghost drawn      13.0  13.7  17.9  19.6  26.7  28.3  29.7  31.7   levels of edge
##     ghost removed     3.8   4.6   4.6   4.7   4.8   5.1   5.2   5.4
##
## A floor of 8.0 separates those cleanly and it FAILED INSIDE THE SWEEP, on an honest frame, at 2.8 levels
## over 3982 pixels. Every one of the sixteen samples above was taken with the layer run on its own, where
## the mask settles around 700-1100 pixels. `_edge_gain` is a MEAN over that mask, so a mask four times the
## size dilutes the same signal below the level the subject's own absence produces: in-sweep WITH the ghost
## reads lower than standalone WITHOUT it. No fixed floor is valid across both, and the bound is not the
## part that is wrong.
##
## So the number stays at 1.0 and the defect stays written down. The measurement above is kept because it is
## the evidence the next attempt starts from, and the next attempt is a statistic that does not dilute --
## `_edge_p90` is already in this file and already used for the body, which also means GR-06 currently
## compares a p90 against a mean. Withdrawn rather than tuned: a bound chosen on a population that excludes
## the condition the gate runs in is not a bound, and lowering it until the sweep goes green would restore
## exactly the vacuity this was trying to remove.
const GHOST_EDGE_FLOOR: float = 1.0

var _skipped: bool = false
var _main: MainView = null
var _full := Rect2i()
## Carried from the underground phase into the surface one, so `GR-04`'s report can state the same
## preview's contrast on both backgrounds instead of quoting one and asserting against the other.
var _rock_gain: float = -1.0
var _rock_px: int = 0
## The chord `_bow_now` last measured across, in screen pixels. Carried out of the function so the
## saturation rejection can quote the mask rim it is describing (`SAG_CAP + 24/span`) rather than naming
## a cap without the number that produced it.
var _bow_span: float = 0.0


## OPEN: THE CORD MASK ADMITS ANYTHING ROPE-COLOURED, AND THAT IS WHY THIS LAYER IS RED ON CI.
##
## `_bow_now` selects cord by hue alone, inside a corridor that is `span * SAG_CAP + 24.0` wide because it
## has to admit a fully hung rope. Anything else drawn in that warm grey and lying inside the corridor is
## taken as cord, and since the reading is a 99th percentile of OFFSET, whatever sits furthest from the
## chord decides it. The layer then correctly refuses to publish a verdict, and reports saturation. That
## report is honest but names the wrong subject: the ROPE did not saturate, the mask did.
##
## A LOCAL, DETERMINISTIC REPRODUCTION EXISTS, which is worth more than the CI red because it can be run
## on demand. Centre the objective line in `hud.gd::_draw_objective_line` — `gx = rect.position.x +
## (w - tw) * 0.5` instead of `rect.position.x + pad` — and about 250px of warm-grey text moves into the
## corridor:
##
##     leftpinned objective (shipped)   bow 0.054 taut / 0.237 slack   3 of 3   healthy
##     centred objective                bow 0.462 taut / 0.463 slack   4 of 4   at the rim 0.4650
##
## Still-frame churn was 0.10% throughout, so it is not machine contention, and the glyph-divisor refactor
## that landed in the same hour was ruled out separately at 0.053/0.237 over three runs. That HUD fix is a
## real one and is held behind this defect rather than dropped.
##
## TWO REPAIRS WERE BUILT AND BOTH FAILED ON MEASUREMENT. Recording them so the third does not repeat one:
##
##   1. FLOOD FILL FROM THE ANCHORS. "The cord is what the hand holds" is the right sentence and the wrong
##      test, because attachment is not visible: the miner is drawn over the hand end and the piton over
##      the other, so a taut cord had 370 rope-coloured pixels in the corridor and 3 within reach of an
##      anchor. Slack measured 0.208; taut returned NO CORD.
##   2. LONGEST CONNECTED RUN ALONG THE CHORD. Extent is the right discriminator — a cord spans the chord
##      and a word does not — but the cord is not connected at this tolerance. Lighting, the veil and the
##      depth fade move the drawn colour along its length, so inside ROPE_TOL it breaks into dashes: the
##      longest runs spanned 0.16 and 0.09 of the chord, and both ropes returned NO CORD.
##
## What both attempts established: the rope is present as roughly 370-470 matching pixels distributed
## along the whole chord, and it is neither anchored-visible nor contiguous. So the next attempt should
## bin by `along` and use the fact that the cord occupies nearly EVERY bin while text occupies few,
## rather than any property of a single connected component. Hiding the HUD for the shutter is the cheap
## alternative and is not sufficient on its own: CI saturates with the shipped left-pinned objective, so
## something other than this text is also inside the corridor there, most likely rock the software
## rasterizer renders closer to ROPE_HUE than hardware does.


func _initialize() -> void:
	print("== the grapple, as a picture rather than as a velocity ==")
	await _run()
	if _skipped:
		return
	_verdict("check_grapple_reads", "the rope reads as a tool and the miner out-reads it")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_skipped = true
		_skip_layer("check_grapple_reads", "no display; the difference between two blank frames is zero, "
			+ "which every assertion here would read as 'nothing was drawn'")
		return
	MainView.dev_start = false
	MainView.boot_skip_title = true
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	for _i: int in SETTLE:
		await physics_frame

	_build_rig(_main.sim)
	_main._renderer.repaint_world()
	await _stand(STAND_COL, FLOOR_ROW - 2)
	await _quiet()
	var img: Image = get_root().get_texture().get_image()
	_full = Rect2i(0, 0, img.get_width(), img.get_height())

	var p: Player = _main._player
	var target: Vector2 = _main._cell_center(Vector2i(TARGET_COL, CEIL_ROW))

	# THE BACKGROUND, TWICE, and the second one is the noise floor. A threshold quoted without the noise it
	# has to clear is a preference wearing a number. THE CURSOR IS ON THE TARGET FOR BOTH CAPTURES and the
	# preview is switched off for the reference instead; see `RopeView.AIM_GHOST_OFF`. Parking the
	# cursor elsewhere also swings the aimed head-lamp, and excluding a lamp-sized disc to compensate
	# blinded the measurement to the near field, which is the only place a shortened lead exists.
	RopeView.AIM_GHOST_OFF = true
	await _look_at(target)
	var bg: PackedFloat32Array = await _luma()
	# THE CONTROL HAS TO COVER THE SAME DURATION AS THE COMPARISON, and the first version took its two
	# reference captures back to back. Anything that animates SLOWLY therefore looked perfectly still to the
	# control and perfectly new to the measurement: the Forge's off-screen marker bobs, and ore glints
	# twinkle over about a second, so the guide mask acquired a bobbing triangle 450px away and a pair of
	# glints 1030px away in the opposite corner, which is where "the preview reaches 1.82 of its own throw"
	# came from. **A noise floor sampled over a shorter interval than the signal is not a noise floor.**
	# SAMPLED OVER A PERIOD, NOT ONCE. Taking a single pair samples the animation at whatever PHASE the run
	# happened to reach: measured across three runs of an unchanged build this control read 5.04%, 6.10% and
	# 3.20% against its own 6% ceiling, so which side of the line it landed on was decided by the clock and
	# not by the picture. **A statistic on a duty-cycled cue needs a full period.** The head-lamp flickers on
	# two sine terms, ore glints turn over about a second, dust falls.
	#
	# The FLOOR IS UNCHANGED at 0.06: this replaces one random draw with the MEDIAN of several draws of the
	# same quantity, which is the estimator the repository already settled on for thresholded fractions after
	# an identical fraction swung 25% to 84% between identical runs. Mean and spread are printed beside it so
	# a future reader can see what one sample would have been worth.
	#
	# The EXCLUSION MASK takes the UNION rather than the median: a pixel that moved in any sample is a pixel
	# that moves, and under-excluding is what put a bobbing marker and two ore glints into the guide mask.
	var samples: Array[float] = []
	var bg2: PackedFloat32Array = bg
	var noise: float = 0.0
	var moving: PackedByteArray = PackedByteArray()
	# CONSECUTIVE PAIRS. The first version compared every sample against the SAME `bg`, so the four draws
	# spanned 30, 60, 90 and 120 frames: four different intervals of a growing quantity, not four draws of
	# one. Their median is then biased upward and moves with CHURN_SAMPLES, which is precisely the property
	# a median is chosen to avoid. The numbers that fix produced were quoted in a commit message as
	# "the median of several draws of the same quantity"; they were not, and they are re-derived below.
	var prev_luma: PackedFloat32Array = bg
	for _s: int in CHURN_SAMPLES:
		for _i: int in QUIET_GAP:
			await physics_frame
		var cur: PackedFloat32Array = await _luma()
		noise = maxf(noise, _max_abs(prev_luma, cur))
		var m: PackedByteArray = _moving(prev_luma, cur)
		moving = m if moving.is_empty() else _either(moving, m)
		samples.append(_coverage(m))
		prev_luma = cur
		bg2 = cur
	var churn: float = _median(samples)
	var spread: String = ""
	for v: float in samples:
		spread += "%.2f%% " % (v * 100.0)
	print("    churn samples over %d periods: %s(median %.2f%%)" % [CHURN_SAMPLES, spread, churn * 100.0])
	# NOTHING IN THIS GAME HOLDS STILL, and the first version of this control demanded that it did. Two
	# consecutive captures of an untouched frame differ by 163 levels at their worst pixel: the head-lamp
	# flickers on two sine terms by design, ore glints, dust falls. **A worst-pixel noise floor is a
	# statement about the liveliest pixel in the frame, not about the frame**, and holding a threshold above
	# it would mean measuring nothing. So the moving pixels are IDENTIFIED and excluded instead, and what is
	# asserted is that they are a small minority; if most of the frame is in motion the exclusion has
	# stopped being an exclusion.
	print("    still-frame churn: %.2f%% of pixels move on their own (worst pixel %.1f levels)"
		% [churn * 100.0, noise])
	_check(churn < 0.06,
		"CONTROL: the frame is mostly still — %.2f%% of it moves between two untouched captures"
			% (churn * 100.0))
	_check_pointer_seam()
	_dump("bg")

	# --- GR-05 / GR-01: how much of the throw does the preview draw? ------------------
	# THE CHURN CONTROL ABOVE RUNS ON THE LIVE FRAME AND HAS TO. It asserts that the frame is mostly still,
	# and a held clock would make that unfalsifiable — the same reason the sky block poses only its own
	# capture pair. What follows asks a different question, what switching the preview on changed, and for
	# that the clock is held.
	#
	# `bg` above is the wrong reference for it twice over: it is 120 frames and three and a half lamp
	# periods before the shot, and the exclusion beside it is unioned from pairs 30 frames apart while the
	# shot is a 4-frame difference. Measured on the sky half, which had the identical fault, the exclusion
	# mask came back in phase and saw almost nothing while the short pair saw 15716 corridor pixels. This
	# half reads 2.4..3.7 levels with the preview drawn and 1.9..3.5 with it never drawn, which is the same
	# blindness. `posed_bg` is captured with the clock already stopped, so what separates it from `aim` is
	# the preview and nothing else. `bg` keeps its other jobs; only the preview differences move.
	#
	# AND `ANIM_FROZEN` IS NOT THE WHOLE CLOCK. It holds `WorldRenderer._anim_time`, which is a GDScript
	# variable; `post_fx.gdshader` runs film grain off the shader built-in `TIME`, which nothing in GDScript
	# poses. The grain is faint -- `grain_amount` 0.014, about 3.6 levels -- and re-seeds on
	# `fract(TIME * 0.96)`, so it cycles about once a second and two captures four frames apart hold two
	# partially decorrelated grain fields. Every pixel of the screen therefore differs a little, and the
	# ones sitting near `_mask`'s threshold cross it or do not depending on how much WALL TIME those four
	# frames took. Under load they take longer, so the mask grows.
	#
	# That is not a cosmetic wobble, because the statistic is a p90 over the mask. Eight unloaded runs of
	# this layer read 144, 147, 265, 176, 304, 149, 177, 153 preview pixels; two sweeps on this same commit
	# read 322 and 465, and at 465 the p90 collapsed from ~142 levels to 43.6 and `GR-06` PASSED. The same
	# tree gave a red and a green in the same hour, and the green was the broken measurement -- diluting
	# the preview's reading is exactly what makes the miner look louder than it.
	#
	# `Engine.time_scale` scales shader `TIME`, so zero holds the grain as well. Six runs with it held read
	# 146, 148, 143, 147, 149, 141 pixels and 140.6..142.4 levels: the count stops moving, the reading
	# stops moving, and it stops at the value the clean runs already gave, so this is not stability bought
	# by measuring nothing. `GR-06` still fails all six. The fix makes the red reliable; it does not
	# remove it.
	#
	# IT IS RELEASED AT THE END OF THE PAIR AND NOT WITH `ANIM_FROZEN`, which runs on to GR-02 below.
	# `_hook` drives a real throw and a throw needs physics to advance, so a zero time scale held that far
	# would hang the layer waiting for a hook that cannot fly.
	WorldRenderer.ANIM_FROZEN = true
	Engine.time_scale = 0.0
	for _i: int in 4:
		await physics_frame
	var posed_bg: PackedFloat32Array = await _luma()
	_dump("posed_bg")
	RopeView.AIM_GHOST_OFF = false
	for _i: int in 4:
		await physics_frame
	var aim: PackedFloat32Array = await _luma()
	Engine.time_scale = 1.0
	_dump("aim")
	var hand: Vector2 = p.hand()
	var guide: PackedByteArray = _without(_mask(aim, posed_bg, hand, moving), _body_mask())
	_dump_mask("aim_guide", guide)
	var reach: float = _screen(hand).distance_to(_screen(target))
	var span: float = _corridor_reach(guide, _screen(hand), _screen(target))
	var fill: float = _corridor_fill(guide, _screen(hand), _screen(target))
	var stray: int = _outside_corridor(guide, _screen(hand), _screen(target))
	# THE DEGENERATE CASE IS A FAILURE TO MEASURE AND NOT A SMALL MEASUREMENT. `_corridor_fill` used to
	# return `0.0` for a zero-length throw, and `0.0 <= 1.01` PASSED; a rig that posed the hand on top of
	# the target scored a green line on a measurement it never made. Same fault as `_bow_now`'s two
	# sentinels above, so it is spelled the same way and rejected here rather than averaged in.
	if is_equal_approx(fill, FILL_NO_SPAN):
		_check(false, "the rig posed a throw with a LENGTH to measure the preview against — the hand and "
			+ "the target projected to within a pixel of each other, so there is no throw to ink a share of")
		# The share is measured below this branch, so on this path the registered row is neither declined
		# nor made. Said from here, because the branch that would have said it is the one not running.
		_not_reached("grapple.gr05-preview-share", "the rig posed a zero-length throw, so there was no"
			+ " share to measure and nothing to decline asserting a bound on")
	else:
		print("    the preview inks %.2f of the throw and reaches %.0f px of %.0f; %d drawn pixels lie "
			% [fill, span, reach, stray] + "off the corridor entirely")
		_stand_down("grapple.gr05-preview-share", "GR-05's share of the throw the preview inks (measured %.2f)" % fill,
			"no bound has been decided for it, and the cap that used to stand here was 1.01 over a "
			+ "quantity `_corridor_fill` bounds at 1.0 by construction — an assertion that could not "
			+ "fail. The measurement is the deliverable until there is a design call to assert")

	# --- GR-06 / GR-04: does the miner out-read the miner's tool? ---------------------
	var body: PackedByteArray = _body_mask()
	_dump_mask("body", body)
	var guide_edge: float = _edge_gain(aim, posed_bg, guide)
	var body_edge: float = _edge_p90(aim, body)
	print("    against dark rock — miner %.1f levels, preview %.1f levels (%d preview pixels)"
		% [body_edge, guide_edge, _count(guide)])
	_rock_gain = guide_edge
	_rock_px = _count(guide)
	# The floor is the WITHDRAWN one; see GHOST_EDGE_FLOOR. The pixel count is printed beside the level
	# because the two together are what showed the mean was being diluted, and neither alone did.
	_check(guide_edge > GHOST_EDGE_FLOOR,
		"CONTROL: the preview was actually drawn (%.1f levels of edge over %d pixels, floor %.1f — a floor"
			% [guide_edge, _count(guide), GHOST_EDGE_FLOOR]
			+ " this low cannot fail; see GHOST_EDGE_FLOOR)")
	_check(body_edge > 1.0,
		"CONTROL: the miner was actually drawn (%.1f levels of edge, over %d pixels)"
			% [body_edge, _count(body)])
	_check(body_edge >= guide_edge * BODY_MARGIN,
		"the miner out-reads their own telemetry (%.1f vs %.1f levels, floor %.2fx)"
			% [body_edge, guide_edge, BODY_MARGIN])

	# --- GR-02: is a thrown rope a different picture from an aimed one? ---------------
	# THE POSE IS RELEASED ON EVERY PATH OUT of this block. The hook is thrown once and its result held,
	# because `_hook` drives a real throw and asking twice is not free; a clock left held on the failing
	# path would silence the phase baselines the checks below depend on, and would do it quietly.
	var hooked: bool = await _hook(Vector2i(TARGET_COL, CEIL_ROW))
	if not hooked:
		WorldRenderer.ANIM_FROZEN = false
	if hooked:
		var roped: PackedFloat32Array = await _luma()
		_dump("anchored")
		var rope: PackedByteArray = _mask(roped, posed_bg, hand, moving)
		_dump_mask("rope", rope)
		# The two live in the same corridor by construction: same hand, same target. If they were the same
		# picture the difference between their masks would be nothing, and `GR-02`'s complaint would stand.
		print("    aim vs anchored: %.3f of the corridor is drawn by one and not the other"
			% _shape_diff(guide, rope))
		_check(_shape_diff(guide, rope) > 0.20,
			"an aimed line and an attached one are not the same picture (%.3f of the corridor differs)"
				% _shape_diff(guide, rope))
		# THE POSE ENDS HERE. GR-03 below takes a phase baseline on purpose, to keep a rope's own animation
		# from scoring as a tension cue, and a held clock would zero the very quantity it needs.
		WorldRenderer.ANIM_FROZEN = false

		# --- GR-03: does tension have a still-frame form? -----------------------------
		# SLACK against TAUT, and the phase baseline in between, because a rope with a wind animation on it
		# would otherwise score its own clock as a tension cue; the mistake `check_machine_state` made
		# and had to unmake.
		# THE BODY HAS TO BE HELD UP BY SOMETHING THAT IS NOT THE ROPE, and the two versions before this one
		# were not. Hanging, the miner swings and settles between captures, so the "clock" baseline was
		# body motion: it measured 15.6 levels against a 13.5-level tension signal and reported that a
		# slack rope looks like a taut one. Paying out line while hanging is worse still: the body simply
		# falls to the new length. Standing on the floor with the anchor overhead, the pose is stable at any
		# payout, which is also the situation a player is in whenever they are not mid-swing.
		p.grapple.length = Grapple.MAX_RANGE
		p.position = _main._cell_center(Vector2i(STAND_COL, FLOOR_ROW - 2))
		p.velocity = Vector2.ZERO
		for _i: int in 60:
			await physics_frame
		var hitch: Vector2 = p.grapple.hitch()
		var taut: PackedFloat32Array = await _at_slack(0.0)
		_dump("taut")
		for _i: int in 8:
			await physics_frame
		var taut_mid: PackedFloat32Array = await _luma()
		# THREE CAPTURES OF THE TAUT STATE, not two, spread over the same window the state change gets. The
		# lane is wide enough to contain a full hang, which means it is also wide enough to contain a lot of
		# falling dust and twinkling ore: counted raw, the clock baseline came out at 4771 pixels against a
		# 5036-pixel signal and the layer reported that a hanging rope looks like a straight one. The union
		# of what moves on its own across the window is removed from BOTH counts, so what is left of the
		# baseline is the rope's own animation and what is left of the signal is the hang.
		# THE BASELINE IS A MEDIAN OF SEVERAL DRAWS, not one. Across three runs of an unchanged build the
		# SIGNAL was 4702, 4703 and 4711 px (stable to a fifth of a percent) while this baseline drew 1017,
		# 332 and 2701. **The flake was never in the rope; it was in the control**, and at 2701 the baseline
		# ate a margin the signal had always cleared. One draw from a periodic process is not an estimate of it.
		# `TENSION_MARGIN` is untouched at 3.0; only the estimator changed.
		var phases: Array[PackedFloat32Array] = [taut, taut_mid]
		for _s: int in PHASE_SAMPLES:
			for _i: int in 8:
				await physics_frame
			phases.append(await _luma())
		var slack: PackedFloat32Array = await _at_slack(0.55)
		_dump("slack")
		# COUNTED, NOT AVERAGED, and the mean was wrong for a reason worth writing down: widening the lane to
		# contain the hang also filled it with unchanged rock, so the same pair of ropes scored 9.96 in a
		# narrow lane and 3.07 in a wide one. **A mean over an area is a statement about the area.** What
		# the ticket asks is how much of the picture tension changes, which is a count of the pixels the two
		# states disagree about, a number the lane's size cannot move.
		# THE LANE HAS TO BE WIDE ENOUGH TO CONTAIN THE THING IT IS MEASURING, and the first version sized it
		# to `CORRIDOR_HALF`: 44px, chosen for the aim preview, which is straight. A slack rope hangs up to
		# `SAG_CAP` of its own chord below it, so the whole hang fell outside the lane and the measurement
		# went DOWN, 9.96 to 8.07, at the exact moment the picture became unmistakable. **An instrument
		# scoped to the old behaviour reads an improvement as a regression.**
		var lane: PackedByteArray = _corridor(_screen(p.hand()), _screen(hitch),
			_screen(p.hand()).distance_to(_screen(hitch)) * WorldRenderer.SAG_CAP + 24.0)
		# The self-motion mask is the UNION across every consecutive pair in the series, so widening the series
		# can only ever exclude MORE. Under-excluding is what once put a bobbing marker and two ore glints into
		# a mask this layer trusted.
		var churn2: PackedByteArray = PackedByteArray()
		for i: int in phases.size() - 1:
			var m2: PackedByteArray = _moving(phases[i], phases[i + 1])
			churn2 = m2 if churn2.is_empty() else _either(churn2, m2)
		var still: PackedByteArray = _without(lane, churn2)
		# Each draw spans the SAME two-step interval, so every sample measures the quantity the signal is
		# compared against rather than a shorter or longer one.
		var phase_draws: Array[float] = []
		for i: int in phases.size() - 2:
			phase_draws.append(float(_changed_in(phases[i], phases[i + 2], still)))
		var phase_spread: String = ""
		for v: float in phase_draws:
			phase_spread += "%d " % int(v)
		var d_phase: float = _median(phase_draws)
		print("    clock baseline draws: %s(median %d)" % [phase_spread, int(d_phase)])
		var d_tension: float = float(_changed_in(taut, slack, still))
		print("    the two states differ over %d pixels of the rope's lane, against %d from the clock"
			% [int(d_tension), int(d_phase)])
		_check(d_tension > maxf(d_phase * TENSION_MARGIN, 40.0),
			"a slack rope and a taut one are different pictures (%d px vs a %d px clock baseline)"
				% [int(d_tension), int(d_phase)])

		# AND NOW THE NUMBER THE TICKET ACTUALLY ASKS FOR, which is not that one.
		#
		# `GR-03`'s evidence is *"no visible physical state distinction IN STILL FRAME"*, a claim about one
		# picture, not about two. The count above compares two captures, and it answered YES for the flat
		# 26px rope as loudly as for the hanging one (3537 px against 4540): displacing a line by more than
		# its own width changes a similar number of pixels whether the displacement is 14px or 200. **A
		# difference metric cannot answer a single-frame question**, and it would have closed this ticket on
		# a rope that reads as a straight line.
		#
		# What a person reads in one frame is BOW: how far the cord departs from the straight chord between
		# its ends, as a share of that chord. THE CORD IS FOUND BY ITS OWN COLOUR, not by differencing
		# against a rope-free capture; that version cut the line to get its reference, and cutting also
		# changes the miner's pose and the key prompt, so the same rope measured 0.24 on one run and 0.31 on
		# the next with taut and slack indistinguishable. A single-frame question deserves a single-frame
		# mask.
		var bow_taut: float = await _bow_now(p.hand(), hitch, 0.0)
		var rim_taut: float = _bow_rim()
		var bow_slack: float = await _bow_now(p.hand(), hitch, 0.55)
		var rim_slack: float = _bow_rim()
		# WHAT THE RENDERER SAYS IT DREW, beside what the mask read, because until this line existed the
		# two had never been put next to each other and a constant was standing in for the prediction.
		#
		# `rope_sag` returns a hang in PIXELS OF Y; `_draw_cord` applies it as `p.y += sin(t * PI) * sag`,
		# so the maximum is vertical. `_bow_now` measures the PERPENDICULAR departure from the chord
		# (`|d.cross(axis)|`). On a diagonal those are not the same quantity: a vertical drop of `h` across
		# a chord at angle theta departs it by `h * cos(theta)`. This shot is deliberately a long diagonal,
		# so the factor is real and it is why a reading near 0.24 sits under a 0.42 cap without either
		# number being wrong.
		#
		# REPORTED, NOT ASSERTED. The honest bound here is "the mask agrees with `rope_sag`", but the two
		# have never been compared, the mask is known to shave the arc's most antialiased pixels, and
		# guessing a tolerance before seeing the spread is how four invented bounds in this repository
		# turned out wrong. The number goes in the log until there is a measurement to set it from.
		var chord: Vector2 = _screen(hitch) - _screen(p.hand())
		var cos_t: float = absf(chord.x) / maxf(chord.length(), 1.0)
		var span_w: float = p.hand().distance_to(hitch)
		var pred: float = (WorldRenderer.rope_sag(span_w, 0.55) / maxf(span_w, 1.0)) * cos_t
		print("    bow: %s of the chord pulled tight, %s at 0.55 slack (mask rim %.4f / %.4f, drawn cap %.2f)"
			% [_bow_str(bow_taut), _bow_str(bow_slack), rim_taut, rim_slack, WorldRenderer.SAG_CAP])
		print(("      the renderer's own model predicts %.4f of the chord here: rope_sag is clamped to "
			+ "SAG_CAP (slack 0.55 solves to 0.6770, every slack above 0.3199 pins) and the chord lies at "
			+ "%.1f degrees, so a vertical hang of %.2f departs it by %.4f")
			% [pred, rad_to_deg(acos(clampf(cos_t, -1.0, 1.0))), WorldRenderer.SAG_CAP, pred])
		# THE SATURATION GUARD'S OWN PRECONDITION, asserted rather than assumed. `_bow_measured` refuses a
		# reading at or above `SAG_CAP`, and that is only a saturation test while a legitimate reading
		# cannot get there. It cannot here because the chord is diagonal, which costs the vertical hang a
		# `cos(theta)`. Flatten the shot and the honest reading climbs toward 0.42 until the guard starts
		# rejecting real ropes; the exact inversion this layer was suspected of and does not have. So the
		# geometry that makes the threshold valid is checked beside the reading it protects.
		_check(pred < WorldRenderer.SAG_CAP,
			("the posed shot leaves the saturation guard room to be a saturation guard — the renderer's "
				+ "predicted departure is %.4f of the chord against a %.2f threshold. If this fails, the "
				+ "shot was flattened and `_bow_measured` will start refusing correct readings")
				% [pred, WorldRenderer.SAG_CAP])

		# THE REJECTION THAT HAD TO EXIST BEFORE EITHER ASSERTION BELOW MEANT ANYTHING.
		#
		# `_bow_now` throws away every pixel further than `span * SAG_CAP + 24.0` from the chord, so the
		# largest number it can return is `SAG_CAP + 24/span`, 0.4621 on this rig's 570px chord. CI read
		# **0.463 slack against 0.462 taut**. That is not a slack rope beside a taut one, it is the same
		# mask rim twice, and `world_renderer.gd:3125` settles it: the DRAWN hang is hard-clamped to
		# `span * SAG_CAP`, so a reading at or above `SAG_CAP` provably did not come off the cord. It came
		# off whatever else in a lamp-lit rock pocket falls within `ROPE_TOL` of `ROPE_HUE`, and inside a
		# band 263px either side of the chord there is plenty of it.
		#
		# NEITHER ASSERTION COULD SAY SO, and they failed in opposite directions. `bow_slack > bow_taut *
		# 3.0` asks 1.386 of a quantity whose ceiling is 0.4621: unsatisfiable arithmetic, reported for
		# days as a design failure of the rope. `bow_slack >= BOW_FLOOR` was the worse half, because it
		# PASSED: a green assertion taken off the rim of its own mask, about a rope nobody had measured.
		# **A statistic pinned to its own ceiling is not a small measurement, it is not a measurement.**
		#
		# `BOW_FLOOR`'s note quotes the sag-by-length rope bowing "0.42, its cap"; that is the renderer's
		# clamp rather than the mask rim, so it may well have been the real cord at full hang. It is still
		# a reading with no headroom in it, one rounding from the rejection added here, and which of the
		# two it was is not decidable from source. Flagged, not moved.
		#
		# So this is a REJECTION and not a new threshold: no number is chosen here. The bound is
		# `WorldRenderer.SAG_CAP` read off the renderer at run time, and the layer's answer to a saturated
		# instrument is to say the instrument saturated, never to publish the rim as if it were a bow.
		# `BOW_FLOOR` and `TENSION_MARGIN` are untouched; moving a threshold to accommodate a reading that
		# came off the wrong pixels is how a floor ends up set to the noise it was meant to clear.
		var taut_read: bool = _bow_measured("taut", bow_taut, rim_taut)
		var slack_read: bool = _bow_measured("slack", bow_slack, rim_slack)
		if taut_read and slack_read:
			# Both numbers came off the cord, so the row's condition did not hold and the assertion below
			# IS the row being made rather than declined.
			_asserted("grapple.gr03-single-frame-bow")
			_check(bow_slack >= BOW_FLOOR,
				"a slack rope HANGS — it departs its own chord by %.3f of it (floor %.2f)"
					% [bow_slack, BOW_FLOOR])
			_check(bow_slack > bow_taut * 3.0,
				"and a taut one does not (%.3f slack against %.3f taut)" % [bow_slack, bow_taut])
		else:
			_stand_down("grapple.gr03-single-frame-bow", "GR-03's single-frame bow — both the floor and the taut-against-slack ratio",
				"neither number came off the cord, and a verdict on the rope drawn from the mask's rim "
				+ "would be a claim about the instrument wearing the rope's name")

	else:
		_check(false, "the rig anchors, so the attached states can be judged at all")
		# No anchor means no attached state, so the bow is never read either way — a different thing from
		# reading it and declining to bound it, and the two used to be the same silence.
		_not_reached("grapple.gr03-single-frame-bow", "the rig never anchored, so no attached state"
			+ " existed to read a bow from")

	await _check_against_sky()

	_main.queue_free()
	await physics_frame


## `GR-04`: *"reduce rope contrast against calm sky until it is needed"*, evidence *"the guide rivals the
## miner silhouette against blue sky."*
##
## EVERYTHING ABOVE THIS RUNS IN A ROCK POCKET, which is the half of the constraint that reads *"cable
## remains readable against dark underground"*, and it is the easy half. A pale warm line on near-black
## rock has contrast to spare. The claim being made here is the opposite one, on a background that is
## bright, flat and uniform, where a dark miner and a pale rope are competing on different signs.
##
## The miner is left standing on real surface ground rather than in a built rig, because the ticket is
## about the surface as it ships and a rig would mean choosing the sky.
func _check_against_sky() -> void:
	var p: Player = _main._player
	var sim: FactorySim = _main.sim
	p.grapple.cut()
	var col: int = SKY_COL
	var row: int = sim.surface_row(col)
	p.position = _main._cell_center(Vector2i(col, row - 2))
	p.velocity = Vector2.ZERO
	for _i: int in 60:
		await physics_frame
	await _quiet()

	# ONE BLOCK ALONE IN THE SKY, and the first version of this did not build one. It aimed at empty air nine
	# cells across and twelve up, the trace stopped on the nearest tree trunk, and the ring landed a cell
	# from the miner's head against foliage. So a measurement labelled "against calm sky" was taken against
	# a tree. The ticket is about a mark on an open background, so the rig makes one: everything cleared for
	# five cells around, a single solid cell in the middle of it, sky behind and on every side.
	var perch := Vector2i(col + 8, row - 9)
	for dx: int in range(-5, 6):
		for dy: int in range(-5, 6):
			sim.set_solid(perch + Vector2i(dx, dy), &"")
	sim.set_solid(perch, &"stone")
	_main._renderer.repaint_world()
	for _i: int in 20:
		await physics_frame
	var target: Vector2 = _main._cell_center(perch)
	# THE REFERENCE IS TAKEN ON BOTH SIDES OF THE MEASUREMENT, and on the surface that is not fussiness.
	# **Clouds drift.** A reference captured thirty frames before the shot has clouds thirty frames out of
	# position, so every cloud edge in the frame reads as something the preview drew; the first version of
	# this scored the preview at 202 levels against the miner's 87 and its mask image was cloud outlines and
	# the serifs of the word "ore". Sandwiching the shot means anything a cloud touched on either side of it
	# is excluded, and the nearer reference is four frames away rather than thirty.
	RopeView.AIM_GHOST_OFF = true
	await _look_at(target)
	# THE COSMETIC CLOCK IS HELD FOR THE LENGTH OF THIS MEASUREMENT. Excluding the pixels the lamp moves
	# cannot work here: the preview is drawn ON TOP of the lamp's pool and shares every pixel with it, so a
	# mask wide enough to cover the flicker covers the preview too. Measured — with the exclusion unioned
	# across a full lamp period the corridor lost 4720..12364 pixels and the preview kept 0..167, and three
	# runs in four failed a control that had been passing on the flicker. The clock is posed instead, which
	# is what the repository already does to the pointer for this same measurement.
	WorldRenderer.ANIM_FROZEN = true
	# AND THE SHADER CLOCK WITH IT, for the reason written at the dark-rock block above: `ANIM_FROZEN` holds
	# a GDScript variable and `post_fx`'s film grain runs off the shader built-in `TIME`. Here the cost
	# landed on the exclusion rather than on the mask. With the world clock posed and the grain still
	# running, the only pixels `_moving` can find ARE grain, so the exclusion stopped being a drift mask and
	# became a noise mask whose size tracked machine load -- and every pixel it holds is a corridor pixel
	# taken away from the measurement. Three runs with only `_anim_time` posed ate 344, 51 and 21 corridor
	# pixels and read 142.8, 160.2 and 155.6 levels over 181..185 mask pixels. Four with the shader clock
	# posed too ate 0, 0, 0 and 0, read 156.4..159.1 levels, and found exactly 182 mask pixels every run.
	Engine.time_scale = 0.0
	# THE EXCLUSION IS BUILT AT THE MEASUREMENT'S OWN TIME SCALE, and the version before this one was not.
	# It differenced `aim` against a reference four frames away and then excluded the pixels that moved
	# between two references THIRTY-EIGHT frames apart. A difference taken at one separation cannot be
	# removed by a mask built at another, and here the two separations sit on opposite sides of a period.
	# The head-lamp's amber pool covers this corridor and flickers by design on two sine terms,
	# `0.030 * sin(t * 11.0) + 0.020 * sin(t * 27.0)`, whose periods are 34.3 and 14.0 frames. Measured on
	# one run of the old code, in the window the corridor occupies:
	#
	#   reference to shot, 34 frames apart (0.99 of a period):   1645 pixels over DRAW_LEVEL
	#   reference to reference, 38 frames (1.11 of a period):    2642
	#   shot to reference, 4 frames (0.12 of a period):         15716
	#
	# The long pairs come back nearly in phase and see almost nothing, so the mask they build excludes
	# almost nothing; the four-frame pair catches the flicker mid-swing and reads ten times as much. The
	# whole-frame count for that pair was 15892, so 99% of it was inside this corridor. That is the lamp.
	#
	# What this cost: with the exclusion blind to the lamp, the count was the lamp's phase and not the
	# preview. A copy of this layer with every `AIM_GHOST_OFF` flipped to `true`, so the preview is never
	# drawn at all, scored 15..10076 pixels against runs of 62..9264 with it drawn, and reached HIGHER
	# than any of them. The measurement did not contain its subject.
	#
	# So the still pairs are taken at SKY_PAIR_GAP, the same separation the shot is measured over, and
	# unioned across SKY_STILL_PAIRS of them so that every phase of the slower term is covered. A pixel
	# that moves on its own at this time scale, at any phase, is excluded. The preview does not move
	# between two ghost-off captures, so none of its own pixels can be excluded by this.
	var moving: PackedByteArray = PackedByteArray()
	var still: PackedFloat32Array = await _luma()
	_dump("sky_bare")
	for _s: int in SKY_STILL_PAIRS:
		for _i: int in SKY_PAIR_GAP:
			await physics_frame
		var cur: PackedFloat32Array = await _luma()
		var m: PackedByteArray = _moving(still, cur)
		moving = m if moving.is_empty() else _either(moving, m)
		still = cur
	RopeView.AIM_GHOST_OFF = false
	for _i: int in SKY_PAIR_GAP:
		await physics_frame
	var aim: PackedFloat32Array = await _luma()
	_dump("sky_aim")
	RopeView.AIM_GHOST_OFF = true
	for _i: int in SKY_PAIR_GAP:
		await physics_frame
	var bg: PackedFloat32Array = await _luma()
	_dump("sky_bg")
	Engine.time_scale = 1.0
	WorldRenderer.ANIM_FROZEN = false
	RopeView.AIM_GHOST_OFF = false
	# RESTRICTED TO THE CORRIDOR, and the surface is why it has to be. Underground the background is flat
	# dark rock and a difference mask is the preview; up here it is **clouds**, which drift, and the lesson
	# plate, which fades. The first version measured 177 levels against the miner's 87 and the mask image
	# was cloud outlines and the serifs of the word "ore". None of that is within forty pixels of the throw.
	var lane: PackedByteArray = _corridor(_screen(p.hand()), _screen(target))
	# THE MINER IS NOT THE PREVIEW. The body's idle animation lives inside the throw corridor, a few pixels
	# past the hand disc, and a two-sample temporal control CANNOT remove a periodic thing: the two
	# references are 38 frames apart, and an idle cycle near that period matches in both of them while
	# differing in the shot between. **A control sampled at the signal's own period is blind by
	# construction.** The body is excluded by geometry instead, which no phase can defeat.
	var guide: PackedByteArray = _without(
		_without(_mask(aim, bg, p.hand(), moving), _invert(lane)), _body_mask())
	_dump_mask("sky_guide", guide)
	var body: PackedByteArray = _body_mask()
	var guide_edge: float = _edge_gain(aim, bg, guide)
	var body_edge: float = _edge_p90(aim, body)
	# WHAT THE SUBTRACTION ATE, over the same corridor and with the same body cut. It is the travelling
	# control on the pose: a corridor that is still losing pixels means something in the frame is alive that
	# the pose does not reach, and the count beside it is not the preview.
	#
	# THIS CONTROL WAS RIGHT AND NOBODY MADE IT FAIL. Its own sentence said a nonzero count meant "something
	# alive that `_anim_time` does not drive", which is precisely what the film grain was, and it printed
	# 21, 30, 51 and 344 across recent runs while nothing read it. It is still printed and still not
	# asserted, and that is now a deliberate gap rather than an oversight: with both clocks posed it reads 0
	# in the corridor over four runs, but the whole-frame mover count over those same four reads 0, 0, 0 and
	# 3, so the residual is not identically zero and four samples do not locate a bound. A cap could also
	# not catch every unposed run -- one of the five measured without the shader clock posed happened to eat
	# 0 as well. The numbers on both sides are recorded here so the next pass starts from data: posed 0 0 0 0
	# in-corridor, unposed 344 51 21 30 0. Unposed with neither clock held it read 4720..12364.
	var eaten: int = _count(_without(_without(moving, _invert(lane)), _body_mask()))
	print("    against open sky — miner %.1f levels, preview %.1f levels (%d preview pixels, "
		% [body_edge, guide_edge, _count(guide)] + "%d corridor pixels eaten by drift)" % eaten)
	# THE FLOOR IS UNCHANGED AT 60 and it now means something. With the clock posed, three runs with the
	# preview drawn read 182, 182 and 189 pixels, and three with it never drawn read 0, 0 and 0. The floor
	# sits between a residual of nothing and a signal that reproduces to within seven pixels. It was not
	# raised to sit closer to the signal: six samples on one machine can say the gap is real and cannot say
	# where inside it a bound belongs.
	_check(_count(guide) > 60,
		"CONTROL: the preview drew something against the sky at all — %d pixels, %d eaten; with the "
		% [_count(guide), eaten] + "preview never drawn this reads 0")
	# REPORTED, NOT ASSERTED, AND THAT IS `GR-04`'s OWN SHAPE. Its approach line is *"state-based alpha and
	# endpoint emphasis"*: how loud an aim mark should be is a design call, and the two candidate floors
	# here are not comparable quantities: the miner's number is the step between an opaque body and what is
	# behind it, while the ring's is the contrast it carries WITHIN itself, a dark backing stroke against a
	# pale mark. Asserting one against the other would be the ruler-mismatch this repository keeps finding.
	#
	# What IS asserted is the constraint the ticket states in the other direction: *"cable remains readable
	# against dark underground"*, because that one compares a thing to itself in the place it must work.
	print("    GR-04 REPRODUCES: on dark rock the whole preview adds %.0f levels of edge over %d pixels; "
		% [_rock_gain, _rock_px] + "on open sky the endpoint mark alone carries %.0f over %d, against a "
		% [guide_edge, _count(guide)] + "miner whose own silhouette step is %.0f. How loud an aim mark "
		% body_edge + "should be is a design call, not a harness one.")


## WAIT UNTIL THE GUIDANCE HAS FINISHED TALKING, and the layer needed this twice for two different
## reasons. Teleporting into the underground rig crosses a stratum boundary, so the ARRIVAL PLATE is
## mid-animation over half the frame; two captures of the "still" rig differed by 248 levels and the guide
## mask swallowed 119156 pixels of fading serif type. Teleporting to the surface lands the body in the air,
## which fires the CHAIN IT lesson: a high-contrast plate the width of the frame, appearing between the
## reference capture and the shot, with its edge straight through the throw corridor. That is where "the
## preview reads 194 levels against the miner's 88" came from, a number that would have confirmed `GR-04`
## on the strength of a tutorial bubble.
##
## **A layer that photographs a transient is measuring the transient**, three times over now.
func _quiet() -> void:
	var waited: int = 0
	while waited < 900 and (_main._hud.announcing() or _main._hints.active_alpha() > 0.02):
		waited += 1
		await physics_frame
	for _i: int in 30:
		await physics_frame
	print("    waited %d frames for the guidance to go quiet" % waited)


func _build_rig(sim: FactorySim) -> void:
	for col: int in range(RIG_LEFT - 2, RIG_RIGHT + 3):
		for row: int in range(CEIL_ROW - 3, FLOOR_ROW + 6):
			sim.set_solid(Vector2i(col, row), &"")
	for col: int in range(RIG_LEFT - 2, RIG_RIGHT + 3):
		for row: int in range(CEIL_ROW - 3, CEIL_ROW + 1):
			sim.set_solid(Vector2i(col, row), &"stone")
		for row: int in range(FLOOR_ROW, FLOOR_ROW + 5):
			sim.set_solid(Vector2i(col, row), &"stone")


func _stand(col: int, row: int) -> void:
	var p: Player = _main._player
	p.grapple.cut()
	p.position = _main._cell_center(Vector2i(col, row))
	p.velocity = Vector2.ZERO
	p.input_dir = 0.0
	p.input_climb = 0.0
	p.jump_held = false
	for _i: int in 40:
		await physics_frame


## WHAT REPLACED THREE CONTROLS THE SEAM MADE TAUTOLOGICAL.
##
## The retired three read `_aim_lands_on().distance_to(target) < 3.0`, and once the pointer is POSED
## rather than warped, `_aim_lands_on()` returns the posed value itself. All three would have reported
## 0.0 px forever, including in a build where the aim path had been broken outright. **They are not
## dropped for being inconvenient; they are dropped because they could no longer fail**, and an assertion
## that cannot fail is worse than no assertion because its green vouches for the defect's absence.
##
## What they were actually guarding was "the pose reached the game". With a seam there are exactly two
## ways that stops being true: a reader in the aim path goes behind the seam's back to the OS cursor, or
## the fixture is not holding the pointer at all. Both are checked here, and both can genuinely fail:
## put `get_global_mouse_position()` back into `_update_mining` and this goes red.
##
## THE TEXT SCAN THAT USED TO LIVE HERE HAS MOVED, AND WIDENED, AND THE PARAGRAPH IT REPLACES WAS STALE.
## It read three hardcoded files -- main.gd, hud.gd, world_renderer.gd -- and said so honestly, on the rule
## that a guard whose claim outruns its population is the failure this repository keeps rediscovering. The
## honesty did not close the hole: the list was maintained by hand, so a NEW script under `scenes/` or
## `src/` that read the OS cursor was invisible to it.
##
## It also sat in the wrong layer. This one is exclusive AND needs a surface, so it runs in the display job
## only, while a text scan needs neither. `check_fixture_pointer` now walks all of `scenes/` and `src/`
## recursively -- 41 scripts, `controls.gd` named as the seam -- and runs in both jobs.
##
## AND THE OTHER TWO CLAIMS IN THAT PARAGRAPH HAD SIMPLY GONE OUT OF DATE. "Ten `warp_mouse` sites still
## live under `tools/`" is now zero, and "the fixture-side counterpart is owed" describes a ratchet that
## exists, is tightened to an empty budget, and is therefore already the flat ban the sentence wanted.
## Both were true when written. Neither was true when read, and nothing was going to notice: prose is the
## one part of this suite with no assertion behind it.
##
## WHAT STAYS HERE IS THE RUNTIME HALF, which no text scan can answer: at this instant, in this running
## game, is the fixture actually holding the pointer?


func _check_pointer_seam() -> void:
	_check(Controls.pointer_posed(),
		"CONTROL: the fixture still owns the pointer — a released seam would be measuring a human's hand")


## POSING THE AIM WITHOUT TOUCHING THE HUMAN'S MOUSE.
##
## This used to call `vp.warp_mouse(vp.get_canvas_transform() * world)` and then wait for the readback to
## agree. The transform pair was right and the wait was not the problem either. **The problem was that
## `warp_mouse` moves the REAL cursor on the REAL desk, and a person was using this machine.** Their hand
## moved it back, so the readback disagreed by however far they had travelled, which is why the pooled
## offsets were 1.0, 97.2, 132.3, 254.9 and 786.7 px rather than one constant number. A wrong transform
## gives a constant offset; that spread was a race, and the other racer was a hand.
##
## Measured with a passive probe that never warps: **11 of 40 samples moved in four seconds,
## largest single jump 21154.6 px, and `focused: false`**: the window did not even have keyboard focus and
## was still tracking their pointer.
##
## So the layer stops asking the windowing system for anything. `Controls.pose_pointer` states the world
## point directly and every reader in the game resolves to it, which makes this measurement independent of
## who else is using the box, and no longer yanks their pointer across the screen while they work.
##
## The settle loop is gone with it, and not because it was wrong: a posed world point needs no round-trip
## and, unlike a posed SCREEN pixel, does not change meaning while the camera is still moving. That was the
## other half of the old race.
##
## DEBT, stated so it cannot quietly vanish: nothing here exercises the real
## `warp_mouse` -> `get_global_mouse_position` path any more. Disqualifying a cue also blinds the suite to
## whatever only that cue could see, so the OS-cursor round-trip needs its own layer that VOIDS rather than
## FAILS when a human is on the box. Tracked as INP-01; `tools/fixture_pointer.gd` is the
## intended detector.
## HOW LONG THE LAMP MAY TAKE TO FOLLOW, and how still counts as settled.
##
## Posing the pointer is instant; what the pointer DRIVES is not. `world_renderer.gd:554` eases the
## head-lamp toward the aim with `lerp(target, 1.0 - exp(-9.0 * delta))`, so after a pose the dominant
## underground light source keeps sliding for roughly thirty frames. Photographing during that slide makes
## two "untouched" captures differ because the LIGHTING changed between them, which is a self-inflicted
## version of the very churn the control downstream is trying to bound.
##
## The old settle loop waited on the CURSOR and therefore waited on the wrong thing; deleting it with the
## warp was right, and replacing it with a single frame was not. This waits on the quantity that is
## actually still moving, and reads it from the renderer rather than assuming a frame count.
const LAMP_SETTLE_MAX: int = 240
## A RESIDUAL epsilon, not a step epsilon. The first version bounded the frame-to-frame STEP, which is
## `residual * (1 - exp(-LAMP_EASE/60))` = residual * 0.1393, so 0.05 as a step was really ~0.359 px of
## residual. Kept at 0.05 as a residual deliberately: it is ~7x tighter, the body is at rest here, and the
## measured settle still lands inside the budget with room (0.03 px, held 6).
const LAMP_SETTLE_EPS: float = 0.05
const LAMP_SETTLE_HOLD: int = 6


func _look_at(world: Vector2) -> void:
	Controls.pose_pointer(world)
	# ASSERT THE RESIDUAL, DO NOT WATCH THE DERIVATIVE. The first version of this loop broke when
	# `_lamp_offset` stopped CHANGING, which is a different question with the same answer most of the time
	# and the opposite answer exactly when it matters: under `Engine.time_scale = 0` the ease multiplier is
	# `1.0 - exp(0)` = 0, the offset cannot move, and a derivative test reads PERFECTLY STILL on every frame
	# while the lamp sits pickled mid-slide. This layer never freezes, so that version was not wrong here,
	# but it was one hoist away from being wrong in `check_ceremony_reads`, which does.
	#
	# It also awaited `physics_frame` while `_lamp_offset` is written in `_process`. More than one physics
	# tick per rendered frame returns the same value twice, which a derivative test scores as settled on a
	# frame where the lamp could not have moved. The residual does not care which clock it is sampled on.
	var held: int = 0
	var residual: float = 0.0
	for _i: int in LAMP_SETTLE_MAX:
		await RenderingServer.frame_post_draw
		residual = _main._renderer.lamp_residual()
		if residual <= LAMP_SETTLE_EPS:
			held += 1
			if held >= LAMP_SETTLE_HOLD:
				break
		else:
			held = 0
	# SAID OUT LOUD, and asserted. The previous version fell out of this loop silently, so a lamp that never
	# settled was indistinguishable from one that did and the churn control downstream absorbed the
	# difference as noise.
	_check(held >= LAMP_SETTLE_HOLD,
		"the head-lamp settled before the shutter (%.2f px residual after %d frames, held %d)"
			% [residual, LAMP_SETTLE_MAX, held])
	# Not a wait for the pose (that is immediate now) but for the frame that DRAWS through it, since
	# every assertion downstream reads pixels rather than state.
	# READS THE CONSUMED VALUE, NOT THE SEAM. This check was written against `Controls.pointer_world`, which
	# under a pose returns the posed point itself, so it compared `world` with `world` and could only ever
	# be 0.0. That is the identical defect as the three assertions this file retired for being unable to
	# fail, committed a hundred lines below the paragraph explaining why that is unacceptable, with a
	# docstring claiming it "still has a channel to fail through". It did not.
	#
	# `_main._aim` is what `_update_mining` DERIVED from the pointer and what the renderer actually draws
	# and lights from, so it diverges the moment the aim path breaks, which is the thing worth knowing.
	# It is a CELL, so the tolerance is in cells and the posed point is converted the same way the game
	# converts it.
	var want: Vector2i = _main._cell_at(world)
	var got: Vector2i = _main._aim
	if Vector2(got - want).length() > AIM_SETTLE_CELLS:
		printerr("  NOTE: the posed aim did not reach the game: posed %s, _update_mining derived %s"
			% [str(want), str(got)])


## How far the game's DERIVED aim cell may sit from the cell under the posed point. Not zero, because
## `_effective_aim` legitimately snaps to the nearest reachable solid when the raw cell is out of reach,
## so this bounds "the pose reached the game" without asserting that no snapping occurred.
const AIM_SETTLE_CELLS: float = 2.0


## Where the RENDERER thinks the cursor is, in world space: the exact expression `_draw_aim_ghost` calls,
## so a seam that resolved differently for the fixture than for the game would show up here.
func _aim_lands_on() -> Vector2:
	return Controls.pointer_world(_main._renderer)


func _hook(target: Vector2i) -> bool:
	var p: Player = _main._player
	p.grapple.fire(p.hand(), _main._cell_center(target))
	for _i: int in 120:
		await physics_frame
		if p.grapple.state == Grapple.State.ANCHORED:
			for _j: int in 10:
				await physics_frame
			return true
		if not p.grapple.live():
			return false
	return false


## Pose a chosen slack by PAYING OUT LINE, with the body where it already is.
##
## The first version moved the body instead, on the reasoning that `slack()` is a pure function of the
## hand's distance from the hitch and a fixture should therefore drive the hand. That is true and it was
## still wrong: **the camera follows the body**, so the two captures were of two different parts of the
## world and the 19 levels between them were mostly rock. The side-by-side made it obvious in a second: one
## frame is a miner over a floor, the other is a miner under a ceiling.
##
## `length` is the winch's payout and the player pays it out with a key, so setting it is driving a real
## state rather than writing into the thing being measured. Body fixed, camera fixed, one variable.
func _at_slack(want: float) -> PackedFloat32Array:
	var g: Grapple = _main._player.grapple
	var d: float = _main._player.hand().distance_to(g.hitch())
	g.length = clampf(d / maxf(1.0 - want, 0.02), Grapple.MIN_LENGTH, Grapple.MAX_RANGE)
	_main._player.velocity = Vector2.ZERO
	for _i: int in 8:
		await physics_frame
	return await _luma()


func _screen(world: Vector2) -> Vector2:
	var vp: Viewport = _main.get_viewport()
	return (vp.get_final_transform() * vp.get_canvas_transform()) * world


## The player's own footprint on screen, as a mask. Taken from the body's real half-extents rather than
## from a guessed box: a bound invented to be generous would quietly hand the miner the guide's pixels and
## the `GR-06` comparison would be measuring the rope against itself.
func _body_mask() -> PackedByteArray:
	var p: Player = _main._player
	var half := Vector2(Player.WIDTH, Player.HEIGHT) * 0.5
	var a: Vector2 = _screen(p.position - half)
	var b: Vector2 = _screen(p.position + half)
	var box := Rect2(a.min(b), (b - a).abs())
	var out := PackedByteArray()
	for y: int in _full.size.y:
		for x: int in _full.size.x:
			out.append(1 if box.has_point(Vector2(x, y)) else 0)
	return out


## Pixels the preview drew, and nothing else: the reference frame has the cursor in the same place with
## `AIM_GHOST_OFF`, so the head-lamp, the body pose and the world are identical in both. Only pixels that
## move on their own between two reference captures are dropped, plus the miner's own hand.
func _mask(shot: PackedFloat32Array, bg: PackedFloat32Array, hand: Vector2,
		moving: PackedByteArray) -> PackedByteArray:
	var skip: Vector2 = _screen(hand)
	var out := PackedByteArray()
	for i: int in shot.size():
		if moving[i] == 1:
			out.append(0)
			continue
		var x: int = i % _full.size.x
		var y: int = i / _full.size.x
		if Vector2(x, y).distance_to(skip) <= HAND_RADIUS:
			out.append(0)     # the hand itself: the throw starts inside the miner's own arm
			continue
		out.append(1 if absf(shot[i] - bg[i]) * 255.0 >= DRAW_LEVEL else 0)
	return out


## Pixels that differ between two captures of an untouched frame: the flicker, the glints, the dust.
func _moving(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	for i: int in a.size():
		out.append(1 if absf(a[i] - b[i]) * 255.0 >= DRAW_LEVEL else 0)
	return out


## How many screen pixels one world pixel is, so a world-space radius can be excluded in screen space.
func _screen_scale() -> float:
	return _screen(Vector2(100.0, 0.0)).distance_to(_screen(Vector2.ZERO)) / 100.0


## HOW FAR ALONG THE THROW THE PREVIEW DRAWS: measured IN THE CORRIDOR between the hand and the target,
## and the two versions before this one measured the whole frame instead.
##
## The frame is full of things that appear and vanish on their own: ore glints twinkle, dust falls, the
## Forge's off-screen marker bobs. None of them is the preview and all of them landed in a
## difference mask, so "the preview reaches 1.87 of its own throw" was five particles in the opposite
## corner. **No temporal control can remove a thing that was not there in either reference capture**, and
## chasing that was the wrong axis: the question `GR-05` asks is how far ALONG THE THROW the preview draws,
## which is a projection, not a radius. Off-corridor marks are counted and reported rather than silently
## dropped, because a preview that sprayed the frame would otherwise read as a tidy short one.
##
## HOW FAR FROM THE HAND THE PREVIEW REACHES: the farthest drawn pixel, not the diagonal of a bounding box
## and not a pixel count. A count cannot say it: eleven dots strung the whole way and eleven bunched at the
## hand cover the same area. A bounding box cannot either, because a single stray mark anywhere in the
## frame stretches it, which is exactly what the first version measured (3.11 of a throw, from a reticle in
## the opposite corner). `GR-05` asks how far the preview goes, so the measurement is a distance.
func _corridor_reach(mask: PackedByteArray, from: Vector2, to: Vector2) -> float:
	var axis: Vector2 = (to - from).normalized()
	var far: float = 0.0
	for i: int in mask.size():
		if mask[i] == 0:
			continue
		var d: Vector2 = Vector2(float(i % _full.size.x), float(i / _full.size.x)) - from
		if absf(d.cross(axis)) > CORRIDOR_HALF:
			continue
		far = maxf(far, d.dot(axis))
	return far


## HOW MUCH OF THE THROW HAS INK ON IT: the share of one-pixel bands along the axis that contain any
## drawn pixel at all. **`reach` was the wrong number and it took a change that plainly worked to show it:**
## shortening the lead from a full tether to a quarter-length stub moved `reach` by nothing, because the
## endpoint ring is at the far end of the throw and always will be. The ring is the payload; the lead is
## the part `GR-05` calls "most of the frame". A fill measures the lead and leaves the ring alone.
func _corridor_fill(mask: PackedByteArray, from: Vector2, to: Vector2) -> float:
	var axis: Vector2 = (to - from).normalized()
	var full: int = int(from.distance_to(to))
	if full <= 0:
		return FILL_NO_SPAN          # no throw to take a share OF — see the note on the constant
	var bins := PackedByteArray()
	bins.resize(full)
	for i: int in mask.size():
		if mask[i] == 0:
			continue
		var d: Vector2 = Vector2(float(i % _full.size.x), float(i / _full.size.x)) - from
		if absf(d.cross(axis)) > CORRIDOR_HALF:
			continue
		var along: int = int(d.dot(axis))
		if along >= 0 and along < full:
			bins[along] = 1
	var n: int = 0
	for v: int in bins:
		n += v
	return float(n) / float(full)


## Drawn pixels that are nowhere near the line being previewed. Reported, never dropped quietly.
func _outside_corridor(mask: PackedByteArray, from: Vector2, to: Vector2) -> int:
	var axis: Vector2 = (to - from).normalized()
	var n: int = 0
	for i: int in mask.size():
		if mask[i] == 0:
			continue
		var d: Vector2 = Vector2(float(i % _full.size.x), float(i / _full.size.x)) - from
		if absf(d.cross(axis)) > CORRIDOR_HALF:
			n += 1
	return n


## HOW HARD A THING'S EDGES HIT, at the 90th percentile rather than the peak. A single antialiased pixel
## somewhere on the rope should not decide whether the rope out-shouts the miner, and a mean should not
## either: most of a body's pixels are its flat interior, which has no edge in it at all.
## THE GRADIENT THE PREVIEW ADDS, not the gradient that happens to be under it.
##
## `_edge_p90` reads the local step at every masked pixel, which is correct for the MINER (an opaque body
## whose silhouette step is entirely its own) and wrong for a thin translucent line, because the step it
## reports belongs to whatever the line was drawn across. Underground that is flat dark rock and the
## distinction never showed. On the surface it is clouds and a lesson plate, and the preview measured
## **202 levels** against the miner's 87 while its own mask image was cloud outlines and the serifs of the
## word "ore". Subtracting the same gradient computed on the reference frame leaves the line's own
## contribution and nothing else.
func _edge_gain(shot: PackedFloat32Array, bg: PackedFloat32Array, mask: PackedByteArray) -> float:
	var w: int = _full.size.x
	var gains := PackedFloat32Array()
	for i: int in mask.size():
		if mask[i] == 0:
			continue
		var x: int = i % w
		var y: int = i / w
		var best_shot: float = 0.0
		var best_bg: float = 0.0
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= _full.size.y:
				continue
			var j: int = ny * w + nx
			best_shot = maxf(best_shot, absf(shot[i] - shot[j]))
			best_bg = maxf(best_bg, absf(bg[i] - bg[j]))
		gains.append(maxf(best_shot - best_bg, 0.0))
	if gains.is_empty():
		return 0.0
	var arr: Array = Array(gains)
	arr.sort()
	return float(arr[int(float(arr.size() - 1) * 0.90)]) * 255.0


func _edge_p90(luma: PackedFloat32Array, mask: PackedByteArray) -> float:
	var w: int = _full.size.x
	var edges := PackedFloat32Array()
	for i: int in mask.size():
		if mask[i] == 0:
			continue
		var x: int = i % w
		var y: int = i / w
		var best: float = 0.0
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= _full.size.y:
				continue
			best = maxf(best, absf(luma[i] - luma[ny * w + nx]))
		edges.append(best)
	if edges.is_empty():
		return 0.0
	var arr: Array = Array(edges)
	arr.sort()
	return float(arr[int(float(arr.size() - 1) * 0.90)]) * 255.0


func _shape_diff(a: PackedByteArray, b: PackedByteArray) -> float:
	if a.size() != b.size() or a.is_empty():
		return -1.0
	var diff: int = 0
	var union: int = 0
	for i: int in a.size():
		if a[i] == 1 or b[i] == 1:
			union += 1
		if a[i] != b[i]:
			diff += 1
	return float(diff) / maxf(float(union), 1.0)


## Every pixel within `CORRIDOR_HALF` of the segment from `a` to `b`, as a mask.
func _corridor(a: Vector2, b: Vector2, half: float = CORRIDOR_HALF) -> PackedByteArray:
	var axis: Vector2 = (b - a).normalized()
	var span: float = a.distance_to(b)
	var out := PackedByteArray()
	for y: int in _full.size.y:
		for x: int in _full.size.x:
			var d: Vector2 = Vector2(x, y) - a
			var along: float = d.dot(axis)
			out.append(1 if absf(d.cross(axis)) <= half and along >= -8.0 \
				and along <= span + 8.0 else 0)
	return out


## How many pixels inside a mask the two captures disagree about, at the same threshold everything else
## in this file uses.
## How far the drawn cord departs from the straight chord between its ends, as a share of that chord. The
## cord is whatever the capture has that a capture of the same pose WITHOUT a rope does not.
## Pose a slack and measure the cord's hang, from that one frame. The cord is masked by ITS OWN COLOUR:
## `ROPE_CORE` and its two derived tones are a specific pale warm fibre, and nothing else in a rock pocket
## is within this distance of them. Reported at the 99th percentile of perpendicular offsets rather than
## the maximum, because a hang is thousands of pixels wide at its lowest point and a stray mote is twenty.
##
## RETURNS `BOW_NO_CHORD` OR `BOW_NO_CORD` WHEN IT COULD NOT LOOK, and neither is a small bow. Put every
## result through `_bow_measured` before it is allowed to be arithmetic.
## DERIVED, NOT TYPED. This was `Color(0.78, 0.70, 0.52)` written out by hand, which is the same three
## floats as `RopeView.ROPE_CORE` and nothing relating them: a repaint of the rope would have left
## this mask hunting the old colour and reporting a rope that had vanished. The under-stroke is 0.888 away
## and `ROPE_TOL` is 0.20, so this mask sees the FIBRE and never the shade under it.
const ROPE_HUE := RopeView.ROPE_CORE
const ROPE_TOL: float = 0.20

func _bow_now(from: Vector2, to: Vector2, want: float) -> float:
	await _at_slack(want)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_root().get_texture().get_image()
	var a: Vector2 = _screen(from)
	var b: Vector2 = _screen(to)
	var axis: Vector2 = (b - a).normalized()
	var span: float = a.distance_to(b)
	if span < 1.0:
		return BOW_NO_CHORD
	_bow_span = span
	var half: float = span * WorldRenderer.SAG_CAP + 24.0
	# THE CEILING IS FLAT AND CARRIES A COSINE, and the shaped version that stood here was WRONG.
	#
	# It read `sin(along / span * PI) * SAG_CAP * span * |cos|`, treating `along` as the cord's parameter.
	# It is not. `_draw_cord` displaces each point by `sin(t * PI) * sag` in Y, and Y has a component along
	# a chord that is not horizontal:
	#
	#     along(t) = t * span + sin(t * PI) * sag * axis.y
	#
	# On this rig `axis.y` is -0.758, so the apex at t=0.50 lands at along/span = 0.22, and the profile's
	# stations are not the cord's parameter at all. Solving that mapping for the observed argmax gives
	# t = 0.585 and a predicted offset of 124 px against 122 measured. So the "contamination at t=0.19"
	# WAS THE CORD'S OWN APEX, and the shaped ceiling was cutting the middle out of the rope: it refused
	# every point from t=0.30 to t=0.585 and dropped `clean` from 0.2366 to 0.1866, away from the 0.2422
	# the renderer says it drew. A tighter bound that moves the answer away from the truth is not tighter.
	#
	# What survives is the part that was missing from the original flat band: the bow is applied in Y and
	# this mask measures PERPENDICULAR distance, so the largest the cord can ever sit from its chord is
	#
	#     SAG_CAP * span * |cos(chord angle)|   plus half a fibre
	#
	# which is 145 px here against the 221 the uncorrected band allowed. Flat, because the along-mapping
	# makes a per-station bound unsafe, and still entirely derived. It refuses the lavapipe contamination
	# at 221 and 223 px and keeps the cord's apex at 125.
	var axis_cos: float = absf(axis.x)
	var ceil_off: float = span * WorldRenderer.SAG_CAP * axis_cos + RopeView.CORD_CORE_W * 0.5
	# THE MINER IS NOT THE ROPE. `_body_mask` is applied at four other sites in this layer and never here,
	# and the miner stands at the HAND end of the chord wearing rope-coloured pixels. It discards 0 on this
	# rig, so it is not what the bow was reading, and it stays as a guard that reports only when it fires.
	var bhalf: Vector2 = Vector2(Player.WIDTH, Player.HEIGHT) * 0.5
	var b0: Vector2 = _screen(_main._player.position - bhalf)
	var b1: Vector2 = _screen(_main._player.position + bhalf)
	var body := Rect2(b0.min(b1), (b1 - b0).abs())
	var body_hits: int = 0
	var offs := PackedFloat32Array()
	_bow_best.resize(BOW_BINS); _bow_best.fill(-1.0)
	_bow_hits.resize(BOW_BINS); _bow_hits.fill(0)
	_bow_over.resize(BOW_BINS); _bow_over.fill(0)
	for y: int in img.get_height():
		for x: int in img.get_width():
			var d := Vector2(float(x), float(y)) - a
			var along: float = d.dot(axis)
			var off: float = absf(d.cross(axis))
			if along < 6.0 or along > span - 6.0 or off > half:
				continue                     # the ends are the hand and the piton, not the hang
			var c: Color = img.get_pixel(x, y)
			if Vector3(c.r, c.g, c.b).distance_to(Vector3(ROPE_HUE.r, ROPE_HUE.g, ROPE_HUE.b)) > ROPE_TOL:
				continue
			if body.has_point(Vector2(float(x), float(y))):
				body_hits += 1
				continue
			offs.append(off)
			var bi: int = clampi(int(along / span * float(BOW_BINS)), 0, BOW_BINS - 1)
			_bow_hits[bi] += 1
			# IN-BAND ONLY, and the band is the renderer's own clamp rather than the mask's. `half` above
			# is `span * SAG_CAP + 24.0`: the 24 exists so a rope pinned AT the cap can still be seen to
			# be pinned, and it is also the exact width of a strip the renderer will never draw a hang
			# into. A pixel out there is therefore not cord, whatever colour it is. Taking the best
			# IN-BAND offset per station rather than rejecting the whole station keeps a station that
			# holds both cord and contamination, which the far end of this chord does.
			if off > ceil_off:
				_bow_over[bi] += 1
			elif off > _bow_best[bi]:
				_bow_best[bi] = off
	if offs.size() < 40:
		return BOW_NO_CORD                   # too little cord found to say anything about its shape
	var arr: Array = Array(offs)
	arr.sort()
	var pct: float = float(arr[int(float(arr.size() - 1) * 0.99)]) / span
	print("    [bow-diag] pct99 %.4f  binned %.4f  occupied %d/%d  px %d  span %.0f  rim %.4f"
		% [pct, _bow_binned() / span, _bow_occupied(), BOW_BINS, offs.size(), span, _bow_rim()])
	print("    [bow-diag] profile %s   (each station's peak offset as a share of the rim, . = empty)"
		% _bow_sketch())
	# THE SAG ITSELF, recovered by undoing the projection rather than by dividing station by station.
	#
	# `_bow_sag_median` and `_bow_agree` are WITHDRAWN and their numbers should not be quoted: both divide
	# a station's offset by `sin(t * PI)` with `t` taken from `along`, and the paragraph above shows those
	# are not the same quantity. They agreed to four decimals across two renderers, which read as
	# robustness and was actually two runs making one systematic error identically.
	#
	# What the geometry does support needs no station at all. Wherever the apex lands in `along`, the
	# LARGEST perpendicular offset anywhere on the cord is `sag * |cos(chord angle)|`, so dividing the
	# largest offset by that cosine recovers the drawn sag as a share of the chord, which is exactly what
	# `rope_sag` reports and therefore checkable against it every run.
	var sag_est: float = _bow_clean(span) / maxf(axis_cos, 0.01)
	print("    [bow-diag] clean %s  ->  sag %.4f of the chord once the cosine is undone  in-band %d/%d  "
		% [_bow_clean_str(span), sag_est, _bow_occupied(), BOW_BINS]
		+ "over-band %d  (NOT yet what this layer asserts on)" % _bow_over_stations())
	# WHAT THE RENDERER SAYS IT DREW, beside what the mask read off it. `rope_sag` is scale-free once
	# divided by its own chord, so a world-space prediction is directly comparable to a screen-space
	# measurement -- and the gap between them is the point. The cord is bowed in Y (`p.y += sin(t * PI) *
	# sag`) while this mask measures distance PERPENDICULAR to the chord, so a chord at angle t to the
	# horizontal should read `cos(t)` of what was drawn. Printing the angle makes that checkable instead
	# of arguable: if measured/predicted tracks cos(angle), the instrument has a known scale error rather
	# than a mystery, and a floor can be derived from the renderer instead of calibrated against readings.
	var wspan: float = from.distance_to(to)
	# THE SLACK THE RENDERER USED, not the slack that was asked for. `_at_slack` clamps `g.length` to
	# [MIN_LENGTH, MAX_RANGE], so `want` is a request and `g.slack()` is the answer. Predicting from the
	# request would be predicting from a number the drawing never saw.
	var got: float = _main._player.grapple.slack(from)
	var pred: float = WorldRenderer.rope_sag(wspan, got) / maxf(wspan, 1.0)
	var ang: float = absf(rad_to_deg((to - from).angle()))
	# IS THE WHOLE CHORD EVEN IN THE PICTURE? `span` is computed from two projected points and neither has
	# to be on screen. If an end is outside the frame, the stations near it can hold no pixels at all and
	# the t-axis this profile is read against covers geometry the camera never saw.
	var iw2: int = img.get_width()
	var ih2: int = img.get_height()
	var a_in: bool = a.x >= 0.0 and a.y >= 0.0 and a.x < float(iw2) and a.y < float(ih2)
	var b_in: bool = b.x >= 0.0 and b.y >= 0.0 and b.x < float(iw2) and b.y < float(ih2)
	if not (a_in and b_in):
		print("    [bow-diag] CHORD LEAVES THE FRAME: hand %s in=%s, hitch %s in=%s, image %dx%d"
			% [str(a.round()), str(a_in), str(b.round()), str(b_in), iw2, ih2])
	else:
		print("    [bow-diag] chord fully inside the frame (hand %s, hitch %s, image %dx%d)"
			% [str(a.round()), str(b.round()), iw2, ih2])
	# WHERE THE LARGEST OFFSET SITS, which decides whether an agreement is the cord or a coincidence. The
	# hang is `sin(t * PI) * sag`, so its apex is at mid-chord by construction. A maximum found near
	# either end is not the hang, however well its VALUE matches the prediction.
	var arg: int = -1
	var argv: float = -1.0
	for i: int in _bow_best.size():
		if _bow_best[i] > argv:
			argv = _bow_best[i]
			arg = i
	# Both of the next two report only when they fire. Each was a CANDIDATE source of the contamination
	# and each was refused by its own count: the body discards 0 pixels here and the rope carries 0
	# pivots, so neither is what sits 125px off the chord. They stay as guards, silent while true.
	if body_hits > 0:
		print("    [bow-diag] %d rope-coloured pixel(s) discarded as the miner's own body" % body_hits)
	# THE OTHER ROPE IN THE PICTURE. `world_renderer.gd` draws `_draw_cord(at, pivot, 0.0)` for every
	# pivot before it draws the hanging span, so a WRAPPED rope puts extra straight, rope-coloured
	# segments in the frame that belong to no chord this scan knows about. `hitch()` is the LAST pivot, so
	# the chord measured here is only the final span; the earlier ones are loose in the corridor.
	var g2: Grapple = _main._player.grapple
	if not g2.pivots.is_empty():
		print("    [bow-diag] the rope has %d pivot(s), so the frame holds straight rope-coloured segments "
			% g2.pivots.size() + "belonging to no chord this scan measures")
	print("    [bow-diag] largest offset %.0f px at station %d of %d (t=%.2f); the hang's apex must be at "
		% [argv, arg, BOW_BINS, (float(arg) + 0.5) / float(BOW_BINS)]
		+ "t=0.50, and the renderer's apex here is %.0f px"
		% (WorldRenderer.rope_sag(from.distance_to(to), _main._player.grapple.slack(from))
			/ maxf(from.distance_to(to), 1.0) * span * cos((to - from).angle())))
	print("    [bow-diag] renderer drew %.4f of the chord at slack %.3f (asked %.2f); chord %.1f deg off "
		% [pred, got, want, ang] + "horizontal, cos %.3f, so a perpendicular mask should read %.4f"
		% [cos(deg_to_rad(ang)), pred * cos(deg_to_rad(ang))])
	# WHAT THIS FUNCTION RETURNS, and it is no longer the percentile.
	#
	# `pct99` is a 99th percentile over every rope-coloured pixel in the corridor and cannot tell a cord
	# from lamp-lit rock. On lavapipe that is fatal: it read 0.4624 and 0.4634, both pinned. The value
	# below is the peak of the per-station profile after the physical ceiling has removed what the
	# renderer could not have drawn, divided by `|cos(chord angle)|` to undo the projection.
	#
	# The division is what puts it on `SAG_CAP`'s own scale. `rope_sag` returns a VERTICAL hang and
	# `_draw_cord` applies it in Y, while this mask measures perpendicular departure, so the two differ by
	# exactly that cosine -- which the saturation guard below has described in prose since it was written
	# without anything acting on it. With the division the guard's `v >= SAG_CAP` is a true statement
	# about the same quantity, and `BOW_FLOOR`'s note ("the sag-by-length rope bows 0.42, its cap") is
	# about this scale too. No constant moves.
	#
	# Checked against the renderer's own `rope_sag` rather than against a calibration, on both renderers:
	#
	#                 recovered   rope_sag says
	#     slack        0.3631        0.3718        hardware AND lavapipe, identically
	#     taut         0.0809/15     0.0056
	#
	# The taut arm is still contaminated and that does NOT invalidate the comparison it feeds: junk can
	# only push a reading up, so an inflated taut makes the measured slack-to-taut ratio a LOWER bound on
	# the true one. 4.5x clearing a 3.0x margin is therefore conservative.
	var clean_share: float = _bow_clean(span)
	if is_equal_approx(clean_share, BOW_NO_CORD):
		return BOW_NO_CORD
	return clean_share / maxf(axis_cos, 0.01)


## The largest number `_bow_now`'s own mask can ever return, as a share of the chord. It discards every
## pixel further than `span * SAG_CAP + 24.0` from the chord, so `SAG_CAP + 24/span` is a ceiling built
## into the instrument and says nothing about a rope. DERIVED, NEVER TYPED: `SAG_CAP` is read off the
## renderer so this cannot drift away from the clamp it describes.
func _bow_rim() -> float:
	return WorldRenderer.SAG_CAP + 24.0 / maxf(_bow_span, 1.0)


## A `_bow_now` result for the run log. The sentinels get WORDS, because printing a failure to measure as
## `-101.000` on a line that reads "bow: ... of the chord" is the same mistake in a smaller font.
func _bow_str(v: float) -> String:
	if is_equal_approx(v, BOW_NO_CHORD):
		return "NO CHORD"
	if is_equal_approx(v, BOW_NO_CORD):
		return "NO CORD"
	return "%.3f" % v


## IS A `_bow_now` RESULT A MEASUREMENT? Three ways it is not, and all three used to reach the `GR-03`
## assertions in `_run` as ordinary floats that happened to satisfy them. Each asserts its own falseness
## here, so a rope this instrument never found is a red layer with a sentence in it rather than a green
## layer with a number in it.
func _bow_measured(which: String, v: float, rim: float) -> bool:
	if is_equal_approx(v, BOW_NO_CHORD):
		_check(false, ("the %s rope has a chord to measure a bow across — the hand and the piton "
			+ "projected to within a pixel of each other, so there is no line to depart from") % which)
		return false
	if is_equal_approx(v, BOW_NO_CORD):
		_check(false, ("the %s rope's cord is FOUND before its shape is judged — fewer than 40 pixels in "
			+ "the mask sat within ROPE_TOL of ROPE_HUE, which is a mask that missed and not a rope that "
			+ "is straight") % which)
		return false
	# THIS THRESHOLD WAS MOVED TO THE MASK RIM AND THAT WAS WRONG, so the reasoning is kept rather than
	# the change. The argument for moving it: `rope_sag` clamps at the posed slack (0.55 solves to
	# 0.6770 against a `SAG_CAP` of 0.42, and every slack above 0.3199 pins), so the drawn hang IS the
	# cap, and a 99th-percentile reading over a cord with thickness should therefore land at or just
	# above `SAG_CAP` whenever the mask works, making this guard fire on success.
	#
	# IT NEGLECTS THE UNITS. `rope_sag` returns a hang in pixels of Y: `_draw_cord` applies it as
	# `p.y += sin(t * PI) * sag`, so the maximum is VERTICAL. `_bow_now` measures the PERPENDICULAR
	# departure from the chord, `|d.cross(axis)|`. A vertical drop of `h` across a chord at angle theta
	# departs that chord by `h * cos(theta)`, and this shot is deliberately a long diagonal, measured
	# at 49.3 degrees, where the cap's 0.42 of vertical is **0.2736 of the chord**, printed above.
	#
	# So a real rope here cannot read much past 0.28, the observed 0.4634 was nowhere near the arc and
	# WAS the saturation this guard is named for, and `SAG_CAP` correctly sits between the two. The
	# rejection was right; only the reason written on it was incomplete.
	#
	# `SAG_CAP` is nonetheless an upper bound that works by geometry rather than by derivation: as the
	# chord flattens, `cos(theta)` approaches 1 and the legitimate reading climbs toward 0.42 until it
	# collides with the threshold. That is not reachable at the posed shot and it is one repose away, so
	# the condition is ASSERTED in `_run` beside the reading rather than left as a comment nobody re-checks.
	if v >= WorldRenderer.SAG_CAP:
		_check(false, ("the %s reading is a BOW and not a SATURATION of the mask — it reads %.4f with "
			+ "its own rim at %.4f, and the renderer clamps the drawn hang to %.2f of the chord in Y, "
			+ "which on this chord is less still, so there is nothing left for it to have measured")
			% [which, v, rim, WorldRenderer.SAG_CAP])
		return false
	return true


func _either(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	for i: int in a.size():
		out.append(1 if a[i] == 1 or b[i] == 1 else 0)
	return out


func _invert(a: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	for v: int in a:
		out.append(0 if v == 1 else 1)
	return out


func _without(keep: PackedByteArray, drop: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	for i: int in keep.size():
		out.append(1 if keep[i] == 1 and drop[i] == 0 else 0)
	return out


func _changed_in(a: PackedFloat32Array, b: PackedFloat32Array, mask: PackedByteArray) -> int:
	var n: int = 0
	for i: int in a.size():
		if mask[i] == 1 and absf(a[i] - b[i]) * 255.0 >= DRAW_LEVEL:
			n += 1
	return n


func _mean_abs_in(a: PackedFloat32Array, b: PackedFloat32Array, mask: PackedByteArray) -> float:
	if a.size() != b.size() or a.is_empty():
		return -1.0
	var sum: float = 0.0
	var n: int = 0
	for i: int in a.size():
		if mask[i] == 0:
			continue
		sum += absf(a[i] - b[i])
		n += 1
	if n == 0:
		return -1.0
	return sum / float(n) * 255.0


func _count(mask: PackedByteArray) -> int:
	var n: int = 0
	for v: int in mask:
		n += v
	return n


func _coverage(mask: PackedByteArray) -> float:
	return float(_count(mask)) / maxf(float(mask.size()), 1.0)


func _luma() -> PackedFloat32Array:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_root().get_texture().get_image()
	var out := PackedFloat32Array()
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c: Color = img.get_pixel(x, y)
			out.append(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)
	return out


func _max_abs(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	if a.size() != b.size() or a.is_empty():
		return -1.0
	var worst: float = 0.0
	for i: int in a.size():
		worst = maxf(worst, absf(a[i] - b[i]))
	return worst * 255.0


func _mean_abs(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	if a.size() != b.size() or a.is_empty():
		return -1.0
	var sum: float = 0.0
	for i: int in a.size():
		sum += absf(a[i] - b[i])
	return sum / float(a.size()) * 255.0


func _dump(tag: String) -> void:
	var dir: String = OS.get_environment("SF_GREADS_DUMP")
	if dir == "":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	get_root().get_texture().get_image().save_png("%s/%s.png" % [dir.trim_suffix("/"), tag])


func _dump_mask(tag: String, mask: PackedByteArray) -> void:
	var dir: String = OS.get_environment("SF_GREADS_DUMP")
	if dir == "":
		return
	var img: Image = Image.create(_full.size.x, _full.size.y, false, Image.FORMAT_RGBA8)
	for y: int in _full.size.y:
		for x: int in _full.size.x:
			img.set_pixel(x, y, Color.WHITE if mask[y * _full.size.x + x] == 1 else Color(0.05, 0.05, 0.08))
	img.save_png("%s/%s_mask.png" % [dir.trim_suffix("/"), tag])


## The MIDDLE of several draws of one quantity. Used instead of a single draw wherever a statistic is taken
## over a cue that animates: the median does not drift with the number of samples the way a max does, so a
## threshold set against it stays a statement about the picture rather than about how long the layer ran.
func _median(vals: Array[float]) -> float:
	if vals.is_empty():
		# NOT 0.0. Both callers feed a `_check` where zero is the maximally PASSING value, so an empty
		# sample set would turn a missing measurement into a green one. NAN loses every comparison, so the
		# layer goes red and says so instead.
		return NAN
	var s: Array[float] = vals.duplicate()
	s.sort()
	var n: int = s.size()
	return s[n / 2] if n % 2 == 1 else (s[n / 2 - 1] + s[n / 2]) * 0.5
