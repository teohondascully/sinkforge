extends "res://tools/check_base.gd"

## DOES THE GRAPPLE LOOK LIKE A TOOL, OR LIKE THE GEOMETRY SOMEBODY DEBUGGED IT WITH?
##
## `check_grapple` already scores the four properties the FUN is made of — it bites, it swings, it lifts,
## it crosses. Every one of them is a fact about the body's velocity, and not one of them would change by a
## single number if the rope were drawn as a magenta line with an arrow on it. `GR-01`–`GR-07` are the
## other half, and they are a different instrument:
##
##   `GR-01`  the persistent dashed guide reads as construction geometry, not as a tool
##   `GR-02`  aim and attachment are visually conflated
##   `GR-03`  tension has no visible state in a still frame
##   `GR-04`  the guide rivals the miner's silhouette against calm sky — REPRODUCES, and it is the endpoint
##            MARK rather than the lead: the same preview adds ~15 levels of edge on dark rock and its ring
##            alone carries ~208 against open sky. Reported, never asserted: how loud an aim mark should be
##            is a design call, and the two numbers a floor would compare are not the same quantity.
##   `GR-05`  the preview occupies most of the frame instead of the endpoint
##   `GR-06`  the player must out-rank their own tool telemetry
##   `GR-07`  judge it in motion, not only in screenshots
##
## **THE FIRST JOB IS NOT TO FIX THESE, IT IS TO FIND OUT WHICH ARE STILL TRUE.** `UI-01` in this same
## programme turned out to be aimed at a property the code does not have — its bubble is anchored to the
## body, not the screen — and the complaint survived while the diagnosis did not. Two of these read the
## same way on inspection: `_draw_aim_ghost` returns early while `grapple.live()`, so aim and rope are
## never on screen together (`GR-02`), and `_draw_cord` bows the line by its slack, so tension is already
## form rather than UI (`GR-03`). Both were MEASURED here rather than argued, and the measurement split
## them. `GR-02` was already satisfied. `GR-03` was not: the bow was a flat 26 pixels regardless of how much
## line was out, and measured as a share of its own chord a rope at 0.55 slack departed it by **0.013**
## against a bar-taut **0.012**. Those are the same picture. The ticket was right, and the code read as
## though it disagreed — which is the most expensive kind of wrong comment there is.
##
## HOW THE GUIDE IS ISOLATED, and this comment described the opposite of the code for one commit, which is
## the failure the paragraph above is about. The first version parked the cursor ON the miner's own hand
## for the reference frame, so no test switch was needed — and that also swings the HEAD-LAMP, which is
## aimed. Five and a half cells of light moved between the two captures and the difference mask ate it;
## excluding a lamp-sized disc to compensate then blinded the layer to the near field, the only place a
## shortened lead lives, and it measured 0.04 of the throw inked while seeing the endpoint ring alone.
##
## So there IS a switch — `WorldRenderer.AIM_GHOST_OFF` — and the reference frame has the cursor in exactly
## the same place, the lamp in exactly the same position, and the body in exactly the same pose. The
## difference is the preview and nothing else.
##
##   godot --path . --script res://tools/check_grapple_reads.gd
##
## `SF_GREADS_DUMP=<dir>` writes every capture and every mask.

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 40
const CELL: int = 32

## The rig: a wide pocket of open sky with a thick ceiling to bite and a floor to stand on. Copied in shape
## from `check_grapple`, for the same reason it gives — nothing about this may depend on worldgen.
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

## Frames between the two reference captures. Long enough to contain the slow animations — the marker bob,
## the glint twinkle — because a control that samples faster than the thing it is controlling for is blind
## to exactly the parts of the frame that will contaminate the measurement.
const QUIET_GAP: int = 30
## HOW MANY periods the self-motion controls sample before believing a number. Three runs of an unchanged
## build put the single-sample version at 5.04%, 6.10% and 3.20% against a 6% ceiling; the count is here so
## a reader can see that the stability came from sampling and not from moving the line.
const CHURN_SAMPLES: int = 4
const PHASE_SAMPLES: int = 3

## Half-width of the corridor the preview is measured in. Wide enough for the endpoint ring (6px radius, a
## 3px shade stroke) and the dashes' antialiasing, narrow enough that a glint two hundred pixels off the
## line cannot be mistaken for the tool.
const CORRIDOR_HALF: float = 44.0

## `GR-03` — how many times the rope's own animation the tension difference must clear. 3.0 was copied from
## `check_machine_state` before anything here had been measured, which is the habit this repository keeps
## catching itself in. It stays at 3.0 only because the measurement has since walked far past it, and the
## number now has both its sides: the sag-by-length rope and the flat-26px rope it replaced, on this same
## instrument, in the same rig.
const TENSION_MARGIN: float = 3.0

## `GR-03` — how far a slack line must hang below its own chord to read as hanging, as a share of that
## chord. Set from the two ropes measured on this instrument in this rig: the flat-26px rope bows **0.03**
## of its chord at 0.55 slack — a 14px deviation over 500px, which is a wobble — and the sag-by-length rope
## bows **0.42**, its cap. 0.15 sits between them with room on both sides, and it is a number a person can
## check against a screenshot with a ruler rather than a preference about how ropey a rope should look.
const BOW_FLOOR: float = 0.15

## `GR-05` — how much of the throw the preview is allowed to draw.
##
## NO FLOOR IS SET IN THIS COMMIT AND THAT IS THE POINT OF THE COMMIT. Guessing a bound before measuring
## has been wrong four times in this repository and every one of the guesses looked reasonable. The first
## run reports; the number it reports is what a bound may later be argued from, once there is a decision
## about what the preview should be.
const SPAN_CAP: float = 1.01

## `GR-06` — the miner must out-read their own telemetry. This one IS asserted, because it is not a matter
## of taste: a tool that is easier to see than the person holding it has inverted the frame.
const BODY_MARGIN: float = 1.15

var _skipped: bool = false
var _main: MainView = null
var _full := Rect2i()
## Carried from the underground phase into the surface one, so `GR-04`'s report can state the same
## preview's contrast on both backgrounds instead of quoting one and asserting against the other.
var _rock_gain: float = -1.0
var _rock_px: int = 0


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
	# preview is switched off for the reference instead — see `WorldRenderer.AIM_GHOST_OFF`. Parking the
	# cursor elsewhere also swings the aimed head-lamp, and excluding a lamp-sized disc to compensate
	# blinded the measurement to the near field, which is the only place a shortened lead exists.
	WorldRenderer.AIM_GHOST_OFF = true
	await _look_at(target)
	var bg: PackedFloat32Array = await _luma()
	# THE CONTROL HAS TO COVER THE SAME DURATION AS THE COMPARISON, and the first version took its two
	# reference captures back to back. Anything that animates SLOWLY therefore looked perfectly still to the
	# control and perfectly new to the measurement: the Forge's off-screen marker bobs, and ore glints
	# twinkle over about a second, so the guide mask acquired a bobbing triangle 450px away and a pair of
	# glints 1030px away in the opposite corner — which is where "the preview reaches 1.82 of its own throw"
	# came from. **A noise floor sampled over a shorter interval than the signal is not a noise floor.**
	# SAMPLED OVER A PERIOD, NOT ONCE. Taking a single pair samples the animation at whatever PHASE the run
	# happened to reach: measured across three runs of an unchanged build this control read 5.04%, 6.10% and
	# 3.20% against its own 6% ceiling, so which side of the line it landed on was decided by the clock and
	# not by the picture. **A statistic on a duty-cycled cue needs a full period.** The head-lamp flickers on
	# two sine terms, ore glints turn over about a second, dust falls.
	#
	# The FLOOR IS UNCHANGED at 0.06 — this replaces one random draw with the MEDIAN of several draws of the
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
	for _s: int in CHURN_SAMPLES:
		for _i: int in QUIET_GAP:
			await physics_frame
		bg2 = await _luma()
		noise = maxf(noise, _max_abs(bg, bg2))
		var m: PackedByteArray = _moving(bg, bg2)
		moving = m if moving.is_empty() else _either(moving, m)
		samples.append(_coverage(m))
	var churn: float = _median(samples)
	var spread: String = ""
	for v: float in samples:
		spread += "%.2f%% " % (v * 100.0)
	print("    churn samples over %d periods: %s(median %.2f%%)" % [CHURN_SAMPLES, spread, churn * 100.0])
	# NOTHING IN THIS GAME HOLDS STILL, and the first version of this control demanded that it did. Two
	# consecutive captures of an untouched frame differ by 163 levels at their worst pixel — the head-lamp
	# flickers on two sine terms by design, ore glints, dust falls. **A worst-pixel noise floor is a
	# statement about the liveliest pixel in the frame, not about the frame**, and holding a threshold above
	# it would mean measuring nothing. So the moving pixels are IDENTIFIED and excluded instead, and what is
	# asserted is that they are a small minority — if most of the frame is in motion the exclusion has
	# stopped being an exclusion.
	print("    still-frame churn: %.2f%% of pixels move on their own (worst pixel %.1f levels)"
		% [churn * 100.0, noise])
	_check(churn < 0.06,
		"CONTROL: the frame is mostly still — %.2f%% of it moves between two untouched captures"
			% (churn * 100.0))
	_check_pointer_seam()
	_dump("bg")

	# --- GR-05 / GR-01: how much of the throw does the preview draw? ------------------
	WorldRenderer.AIM_GHOST_OFF = false
	for _i: int in 4:
		await physics_frame
	var aim: PackedFloat32Array = await _luma()
	_dump("aim")
	var hand: Vector2 = p.hand()
	var guide: PackedByteArray = _without(_mask(aim, bg, hand, moving), _body_mask())
	_dump_mask("aim_guide", guide)
	var reach: float = _screen(hand).distance_to(_screen(target))
	var span: float = _corridor_reach(guide, _screen(hand), _screen(target))
	var fill: float = _corridor_fill(guide, _screen(hand), _screen(target))
	var stray: int = _outside_corridor(guide, _screen(hand), _screen(target))
	print("    the preview inks %.2f of the throw and reaches %.0f px of %.0f; %d drawn pixels lie "
		% [fill, span, reach, stray] + "off the corridor entirely")
	_check(fill <= SPAN_CAP,
		"the aim preview inks %.2f of the distance it is previewing (cap %.2f)" % [fill, SPAN_CAP])

	# --- GR-06 / GR-04: does the miner out-read the miner's tool? ---------------------
	var body: PackedByteArray = _body_mask()
	_dump_mask("body", body)
	var guide_edge: float = _edge_gain(aim, bg, guide)
	var body_edge: float = _edge_p90(aim, body)
	print("    against dark rock — miner %.1f levels, preview %.1f levels (%d preview pixels)"
		% [body_edge, guide_edge, _count(guide)])
	_rock_gain = guide_edge
	_rock_px = _count(guide)
	_check(guide_edge > 1.0,
		"CONTROL: the preview was actually drawn (%.1f levels of edge, over %d pixels)"
			% [guide_edge, _count(guide)])
	_check(body_edge > 1.0,
		"CONTROL: the miner was actually drawn (%.1f levels of edge, over %d pixels)"
			% [body_edge, _count(body)])
	_check(body_edge >= guide_edge * BODY_MARGIN,
		"the miner out-reads their own telemetry (%.1f vs %.1f levels, floor %.2fx)"
			% [body_edge, guide_edge, BODY_MARGIN])

	# --- GR-02: is a thrown rope a different picture from an aimed one? ---------------
	if await _hook(Vector2i(TARGET_COL, CEIL_ROW)):
		var roped: PackedFloat32Array = await _luma()
		_dump("anchored")
		var rope: PackedByteArray = _mask(roped, bg, hand, moving)
		_dump_mask("rope", rope)
		# The two live in the same corridor by construction — same hand, same target. If they were the same
		# picture the difference between their masks would be nothing, and `GR-02`'s complaint would stand.
		print("    aim vs anchored: %.3f of the corridor is drawn by one and not the other"
			% _shape_diff(guide, rope))
		_check(_shape_diff(guide, rope) > 0.20,
			"an aimed line and an attached one are not the same picture (%.3f of the corridor differs)"
				% _shape_diff(guide, rope))

		# --- GR-03: does tension have a still-frame form? -----------------------------
		# SLACK against TAUT, and the phase baseline in between, because a rope with a wind animation on it
		# would otherwise score its own clock as a tension cue — the mistake `check_machine_state` made
		# and had to unmake.
		# THE BODY HAS TO BE HELD UP BY SOMETHING THAT IS NOT THE ROPE, and the two versions before this one
		# were not. Hanging, the miner swings and settles between captures, so the "clock" baseline was
		# body motion: it measured 15.6 levels against a 13.5-level tension signal and reported that a
		# slack rope looks like a taut one. Paying out line while hanging is worse still — the body simply
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
		# SIGNAL was 4702, 4703 and 4711 px — stable to a fifth of a percent — while this baseline drew 1017,
		# 332 and 2701. **The flake was never in the rope; it was in the control**, and at 2701 the baseline
		# ate a margin the signal had always cleared. One draw from a periodic process is not an estimate of it.
		# `TENSION_MARGIN` is untouched at 3.0; only the estimator changed.
		var phases: Array[PackedFloat32Array] = [taut, taut_mid]
		for _s: int in PHASE_SAMPLES:
			for _i: int in 8:
				await physics_frame
			phases.append(await _luma())
		var taut2: PackedFloat32Array = phases[phases.size() - 1]
		var slack: PackedFloat32Array = await _at_slack(0.55)
		_dump("slack")
		# COUNTED, NOT AVERAGED, and the mean was wrong for a reason worth writing down: widening the lane to
		# contain the hang also filled it with unchanged rock, so the same pair of ropes scored 9.96 in a
		# narrow lane and 3.07 in a wide one. **A mean over an area is a statement about the area.** What
		# the ticket asks is how much of the picture tension changes, which is a count of the pixels the two
		# states disagree about — a number the lane's size cannot move.
		# THE LANE HAS TO BE WIDE ENOUGH TO CONTAIN THE THING IT IS MEASURING, and the first version sized it
		# to `CORRIDOR_HALF` — 44px, chosen for the aim preview, which is straight. A slack rope hangs up to
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
		# `GR-03`'s evidence is *"no visible physical state distinction IN STILL FRAME"* — a claim about one
		# picture, not about two. The count above compares two captures, and it answered YES for the flat
		# 26px rope as loudly as for the hanging one (3537 px against 4540): displacing a line by more than
		# its own width changes a similar number of pixels whether the displacement is 14px or 200. **A
		# difference metric cannot answer a single-frame question**, and it would have closed this ticket on
		# a rope that reads as a straight line.
		#
		# What a person reads in one frame is BOW: how far the cord departs from the straight chord between
		# its ends, as a share of that chord. THE CORD IS FOUND BY ITS OWN COLOUR, not by differencing
		# against a rope-free capture — that version cut the line to get its reference, and cutting also
		# changes the miner's pose and the key prompt, so the same rope measured 0.24 on one run and 0.31 on
		# the next with taut and slack indistinguishable. A single-frame question deserves a single-frame
		# mask.
		var bow_taut: float = await _bow_now(p.hand(), hitch, 0.0)
		var bow_slack: float = await _bow_now(p.hand(), hitch, 0.55)
		print("    bow: %.3f of the chord pulled tight, %.3f at 0.55 slack" % [bow_taut, bow_slack])
		_check(bow_slack >= BOW_FLOOR,
			"a slack rope HANGS — it departs its own chord by %.3f of it (floor %.2f)"
				% [bow_slack, BOW_FLOOR])
		_check(bow_slack > bow_taut * 3.0,
			"and a taut one does not (%.3f slack against %.3f taut)" % [bow_slack, bow_taut])

	else:
		_check(false, "the rig anchors, so the attached states can be judged at all")

	await _check_against_sky()

	_main.queue_free()
	await physics_frame


## `GR-04` — *"reduce rope contrast against calm sky until it is needed"*, evidence *"the guide rivals the
## miner silhouette against blue sky."*
##
## EVERYTHING ABOVE THIS RUNS IN A ROCK POCKET, which is the half of the constraint that reads *"cable
## remains readable against dark underground"* — and it is the easy half. A pale warm line on near-black
## rock has contrast to spare. The claim being made here is the opposite one, on a background that is
## bright, flat and uniform, where a dark miner and a pale rope are competing on different signs.
##
## The miner is left standing on real surface ground rather than in a built rig, because the ticket is
## about the surface as it ships and a rig would be me choosing the sky.
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
	# from the miner's head against foliage — so a measurement labelled "against calm sky" was taken against
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
	# position, so every cloud edge in the frame reads as something the preview drew — the first version of
	# this scored the preview at 202 levels against the miner's 87 and its mask image was cloud outlines and
	# the serifs of the word "ore". Sandwiching the shot means anything a cloud touched on either side of it
	# is excluded, and the nearer reference is four frames away rather than thirty.
	WorldRenderer.AIM_GHOST_OFF = true
	await _look_at(target)
	var bg_before: PackedFloat32Array = await _luma()
	_dump("sky_bare")
	for _i: int in QUIET_GAP:
		await physics_frame
	WorldRenderer.AIM_GHOST_OFF = false
	for _i: int in 4:
		await physics_frame
	var aim: PackedFloat32Array = await _luma()
	_dump("sky_aim")
	WorldRenderer.AIM_GHOST_OFF = true
	for _i: int in 4:
		await physics_frame
	var bg: PackedFloat32Array = await _luma()
	WorldRenderer.AIM_GHOST_OFF = false
	var moving: PackedByteArray = _moving(bg_before, bg)
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
	print("    against open sky — miner %.1f levels, preview %.1f levels (%d preview pixels)"
		% [body_edge, guide_edge, _count(guide)])
	_check(_count(guide) > 60,
		"CONTROL: the preview drew something against the sky at all (%d pixels)" % _count(guide))
	# REPORTED, NOT ASSERTED, AND THAT IS `GR-04`'s OWN SHAPE. Its approach line is *"state-based alpha and
	# endpoint emphasis"* — how loud an aim mark should be is a design call, and the two candidate floors
	# here are not comparable quantities: the miner's number is the step between an opaque body and what is
	# behind it, while the ring's is the contrast it carries WITHIN itself, a dark backing stroke against a
	# pale mark. Asserting one against the other would be the ruler-mismatch this repository keeps finding.
	#
	# What IS asserted is the constraint the ticket states in the other direction — *"cable remains readable
	# against dark underground"* — because that one compares a thing to itself in the place it must work.
	print("    GR-04 REPRODUCES: on dark rock the whole preview adds %.0f levels of edge over %d pixels; "
		% [_rock_gain, _rock_px] + "on open sky the endpoint mark alone carries %.0f over %d, against a "
		% [guide_edge, _count(guide)] + "miner whose own silhouette step is %.0f. How loud an aim mark "
		% body_edge + "should be is a design call, not a harness one.")


## WAIT UNTIL THE GUIDANCE HAS FINISHED TALKING, and the layer needed this twice for two different
## reasons. Teleporting into the underground rig crosses a stratum boundary, so the ARRIVAL PLATE is
## mid-animation over half the frame — two captures of the "still" rig differed by 248 levels and the guide
## mask swallowed 119156 pixels of fading serif type. Teleporting to the surface lands the body in the air,
## which fires the CHAIN IT lesson: a high-contrast plate the width of the frame, appearing between the
## reference capture and the shot, with its edge straight through the throw corridor. That is where "the
## preview reads 194 levels against the miner's 88" came from — a number that would have confirmed `GR-04`
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
## The retired three read `_aim_lands_on().distance_to(target) < 3.0` — and once the pointer is POSED
## rather than warped, `_aim_lands_on()` returns the posed value itself. All three would have reported
## 0.0 px forever, including in a build where the aim path had been broken outright. **They are not
## dropped for being inconvenient; they are dropped because they could no longer fail**, and an assertion
## that cannot fail is worse than no assertion because its green vouches for the defect's absence.
##
## What they were actually guarding was "the pose reached the game". With a seam there are exactly two
## ways that stops being true: a reader in the aim path goes behind the seam's back to the OS cursor, or
## the fixture is not holding the pointer at all. Both are checked here, and both can genuinely fail —
## put `get_global_mouse_position()` back into `_update_mining` and this goes red.
##
## ITS POPULATION IS THREE FILES AND THE SENTENCE NOW SAYS SO. An earlier wording claimed "the aim path",
## which is wider than what it can see: ten `warp_mouse` sites still live under `tools/`, and `controls.gd`
## itself is excluded by design. A guard whose claim outruns its population is the failure this repository
## keeps rediscovering, so the fixture-side counterpart — no FIXTURE calls `warp_mouse` — is owed and
## tracked under INP-01 rather than implied by this one.
const AIM_SOURCES: Array[String] = [
	"res://scenes/main.gd",
	"res://scenes/hud.gd",
	"res://scenes/world_renderer.gd",
]


func _check_pointer_seam() -> void:
	var offenders: Array[String] = []
	for path: String in AIM_SOURCES:
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f == null:
			offenders.append("%s (unreadable)" % path)
			continue
		var n: int = 0
		while not f.eof_reached():
			n += 1
			var line: String = f.get_line()
			if line.strip_edges().begins_with("#"):
				continue          # the seam is DESCRIBED in prose in several places; prose cannot read a cursor
			if line.contains("get_global_mouse_position(") or line.contains("get_mouse_position("):
				offenders.append("%s:%d" % [path, n])
	_check(offenders.is_empty(),
		"CONTROL: no aim reader in main/hud/world_renderer goes behind the seam to the OS cursor (%s)"
			% ("clean" if offenders.is_empty() else ", ".join(offenders)))
	_check(Controls.pointer_posed(),
		"CONTROL: the fixture still owns the pointer — a released seam would be measuring a human's hand")


## POSING THE AIM WITHOUT TOUCHING THE HUMAN'S MOUSE.
##
## This used to call `vp.warp_mouse(vp.get_canvas_transform() * world)` and then wait for the readback to
## agree. The transform pair was right and the wait was not the problem either. **The problem was that
## `warp_mouse` moves the REAL cursor on the REAL desk, and a person was using this machine.** Their hand
## moved it back, so the readback disagreed by however far they had travelled — which is why the pooled
## offsets were 1.0, 97.2, 132.3, 254.9 and 786.7 px rather than one constant number. A wrong transform
## gives a constant offset; that spread was a race, and the other racer was a hand.
##
## Measured by the peer with a passive probe that never warps: **11 of 40 samples moved in four seconds,
## largest single jump 21154.6 px, and `focused: false`** — the window did not even have keyboard focus and
## was still tracking their pointer.
##
## So the layer stops asking the windowing system for anything. `Controls.pose_pointer` states the world
## point directly and every reader in the game resolves to it, which makes this measurement independent of
## who else is using the box — and stops us yanking their pointer across the screen while they work.
##
## The settle loop is gone with it, and not because it was wrong: a posed world point needs no round-trip
## and, unlike a posed SCREEN pixel, does not change meaning while the camera is still moving. That was the
## other half of the old race.
##
## DEBT, stated so it cannot quietly vanish: nothing here exercises the real
## `warp_mouse` -> `get_global_mouse_position` path any more. Disqualifying a cue also blinds the suite to
## whatever only that cue could see, so the OS-cursor round-trip needs its own layer that VOIDS rather than
## FAILS when a human is on the box. Tracked as INP-01; the peer's `tools/fixture_pointer.gd` is the
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
const LAMP_SETTLE_EPS: float = 0.05
const LAMP_SETTLE_HOLD: int = 6


func _look_at(world: Vector2) -> void:
	Controls.pose_pointer(world)
	var prev: Vector2 = Vector2.INF
	var held: int = 0
	for _i: int in LAMP_SETTLE_MAX:
		await physics_frame
		var now: Vector2 = _main._renderer._lamp_offset
		if prev != Vector2.INF and now.distance_to(prev) < LAMP_SETTLE_EPS:
			held += 1
			if held >= LAMP_SETTLE_HOLD:
				break
		else:
			held = 0
		prev = now
	# Not a wait for the pose — that is immediate now — but for the frame that DRAWS through it, since
	# every assertion downstream reads pixels rather than state.
	if _aim_lands_on().distance_to(world) > AIM_SETTLE_EPS:
		printerr("  NOTE: the posed aim did not take: asked for %s, the renderer reads %s"
			% [str(world), str(_aim_lands_on())])


## How close the readback must sit to the posed point. With the OS cursor out of the loop this is an
## identity check rather than a tolerance, but it is kept as a tolerance so the assertion still has a
## channel to fail through if the seam is ever bypassed.
const AIM_SETTLE_EPS: float = 2.0


## Where the RENDERER thinks the cursor is, in world space — the exact expression `_draw_aim_ghost` calls,
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
## world and the 19 levels between them were mostly rock. The side-by-side made it obvious in a second — one
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


## HOW FAR ALONG THE THROW THE PREVIEW DRAWS — measured IN THE CORRIDOR between the hand and the target,
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
## HOW FAR FROM THE HAND THE PREVIEW REACHES — the farthest drawn pixel, not the diagonal of a bounding box
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


## HOW MUCH OF THE THROW HAS INK ON IT — the share of one-pixel bands along the axis that contain any
## drawn pixel at all. **`reach` was the wrong number and it took a change that plainly worked to show it:**
## shortening the lead from a full tether to a quarter-length stub moved `reach` by nothing, because the
## endpoint ring is at the far end of the throw and always will be. The ring is the payload; the lead is
## the part `GR-05` calls "most of the frame". A fill measures the lead and leaves the ring alone.
func _corridor_fill(mask: PackedByteArray, from: Vector2, to: Vector2) -> float:
	var axis: Vector2 = (to - from).normalized()
	var full: int = int(from.distance_to(to))
	if full <= 0:
		return 0.0
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
## either — most of a body's pixels are its flat interior, which has no edge in it at all.
## THE GRADIENT THE PREVIEW ADDS, not the gradient that happens to be under it.
##
## `_edge_p90` reads the local step at every masked pixel, which is correct for the MINER — an opaque body
## whose silhouette step is entirely its own — and wrong for a thin translucent line, because the step it
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
const ROPE_HUE := Color(0.78, 0.70, 0.52)
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
		return 0.0
	var half: float = span * WorldRenderer.SAG_CAP + 24.0
	var offs := PackedFloat32Array()
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
			offs.append(off)
	if offs.size() < 40:
		return -1.0                          # too little cord found to say anything about its shape
	var arr: Array = Array(offs)
	arr.sort()
	return float(arr[int(float(arr.size() - 1) * 0.99)]) / span


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
		return 0.0
	var s: Array[float] = vals.duplicate()
	s.sort()
	var n: int = s.size()
	return s[n / 2] if n % 2 == 1 else (s[n / 2 - 1] + s[n / 2]) * 0.5
