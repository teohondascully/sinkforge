extends "res://tools/check_base.gd"

## WHAT DOES THE INTERRUPT DO TO THE WORLD IT IS INTERRUPTING?
##
##   godot --path . --script res://tools/check_ceremony_reads.gd
##
## `check_hud_layout` already governs the HUD against itself: `panel_probe` collects every panel's
## rectangle, `HELPER_TAGS` says what kind of thing each surface is, and the `critical` rule caps how many
## interrupts may share the screen at once. It is a thorough instrument and it cannot see this at all.
##
## **T2.1's last open line is "stop zone ceremony colliding with map, rope and action."** The map half is
## covered: `_draw_arrival` registers its solid core and two layout states raise the plate with the
## minimap up. The rope half is not, and the reason is structural rather than an oversight: **every rope in
## this game is drawn in WORLD space** by `world_renderer.gd` (`_draw_ropes` for the placed ladders,
## `_draw_cord` for the grapple line). There is no `_draw_rope` in `scenes/hud.gd` and no rope rectangle in
## `panel_probe`. A plate printed across the rope is not a collision the layout layer declines to report;
## it is one the layer's population does not contain.
##
## **Not a missing state. A missing plane.** This layer is that plane.
##
## AND THE PLATE CANNOT BE MOVED OUT OF THE WAY, derivable before any capture. The camera centres the
## body, so the miner sits at canvas (320, 180); the plate is centred too and spans canvas y 61.6..111.6,
## the 4.3rd to the 7.4th cell above the body, in the body's own column. Its core reaches ~114 canvas px
## either side of centre and `SCRIM_FEATHER` adds 96 more: a ~420 px footprint on a 640 px canvas. There
## is nowhere to put it that is not over the miner. Placement is not a treatment here, so the layer does
## not measure position; it measures how much of the rope survives.
##
## ---
##
## WHAT IS ASSERTED AND WHAT IS ONLY REPORTED, because the difference is the whole design of this file.
##
## The occlusion figure is **REPORTED WITHOUT A FLOOR**, and that is deliberate in the way `GR-05`'s
## `SPAN_CAP` is deliberate: guessing a bound before there is a decision about what the ceremony should do
## to the world has been wrong four times in this repository, and every guess looked reasonable. How much
## of a rope an interrupt may eat is a design call nobody has made. The first run reports; a bound may be
## argued from it once the treatment lands.
##
## What IS asserted is that the instrument can register its subject, which is the failure this whole layer
## exists because of:
##
##   1. the rope is FOUND, in both bands, or there is nothing to measure;
##   2. the reference frame is genuinely uninterrupted;
##   3. the ceremony DREW, measured away from the rope so the control survives a fix that clears the rope;
##   4. the band below the plate stays quiet, so what is reported above it is the plate and not drift.
##
## Every one of those was a way an earlier version of this measurement returned a number that meant
## nothing. Assertion 2 in particular: standing the body in the rig crosses a stratum boundary and the game
## announces on its own, so the first "no ceremony" capture came back reading `25 METRES DOWN / SHALE
## REACH`. Both arms were ceremonies, the diff was two plates cancelling, and the probe reported a ratio of
## 1.0, which was the truth, read as an instrument failure.
##
## ---
##
## THE MECHANISM, printed every run because it is more useful than the headline number. The scrim is
## `Color(0.02, 0.025, 0.04)` at alpha 0.28, a multiply in all but name. (This line said 0.80 for as long as
## the file has existed; `ffeb1c8` dropped it to 0.28 twenty-eight minutes after the line was written, and
## the docstring further down has known the real number all along. The file contradicted itself.) Underground the rock behind it
## sits at a luma near ten, so eighty percent of it is nearly nothing: the scrim is almost invisible over
## the mass of the frame. The rope is HEMP at 0.76/0.63/0.42. **A multiplicative veil takes 80% from the
## bright thin things and almost nothing from the dark mass**: it erases the rope, the cord and the glints
## while leaving intact exactly the background it was drawn to suppress. So the layer reports what the
## ceremony did to the ROPE beside what it did to the ROCK behind the rope, in the same rows. If those two
## numbers ever converge, the veil has started doing its job.

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 40
const CELL: int = FactorySim.CELL

## A shaft with rock either side, deep enough that the rope crosses the whole plate and continues past it.
## The rows BELOW the plate are the drift control: the same rope, the same rock, the same lamp, no plate.
const SHAFT_COL: int = 30
const ROCK_L: int = 22
const ROCK_R: int = 38
const ROCK_TOP: int = 16
const ROCK_BOT: int = 62
const SHAFT_TOP: int = 20
const FLOOR_ROW: int = 45
const STAND_ROW: int = 44

## `_arrival_life` where `_draw_arrival`'s alpha has been pinned at 1.0 for a while. The plate is at full
## opacity for life in 1.42..2.83 (fast in, slow out), so the middle of that window is the honest place to
## photograph it, and the value is printed so a run that missed the window is visible rather than silent.
const PLATEAU: float = 2.20
const QUIET_MAX: int = 600
## A COLUMN FAR ENOUGH FROM SPAWN that the surface there is ordinary ground rather than the opening scene's
## dug pit; the same reason `check_grapple_reads` picks 96. The first version stood the body at the rig's
## own column and the arm stood down half the time: near spawn the game is still TEACHING, so a lesson
## bubble is up, and the plate suppresses it, so the two captures differ by a surface that is not the
## subject. Waiting longer is the wrong fix; the arm needs somewhere the teaching is finished.
const SURFACE_COL: int = 96
const SURFACE_QUIET_MAX: int = 1500

## HOW MANY TIMES MORE THE PLATE MUST PUT ON THE SCREEN THAN THE SKY PUTS THERE BY ITSELF.
## Nine boots: plate 6763..6929 ink px against a worst sky drift of 247, an observed margin of 27x. Four
## leaves that nearly seven times over, which is the room a duty-cycled cue with an unbounded tail needs.
const INK_OVER_DRIFT: int = 4

## THE ABSOLUTE INK COUNT THE ARM HAS ALWAYS DEMANDED, now named instead of typed twice. Unchanged at 400.
const SKY_INK_MIN: int = 400

## THE WORDS' MEDIAN SEPARATION FROM THEIR GROUND, AGAINST OPEN SKY. A RATCHET, NOT A DESIGN BOUND.
##
## THIRTEEN boots of one commit, sorted: 57.2, 57.4, 57.6, 57.6, 58.4, 60.1, 60.6, 60.8, 61.0, 61.0, 61.0,
## 61.2, 61.2. The mean over the same thirteen spans 43.3 to 55.1 and is not usable as a bound, which is
## the whole reason this row could not be asserted before.
##
## THE MINIMUM MOVED WHILE THIS WAS BEING WRITTEN, and that is the reason for the size of the gap rather
## than an argument against it. Nine boots said 57.4; the tenth read 57.2. A duty-cycled cue's worst case
## falls as n grows, so a ratchet set just under the observed minimum would be re-broken by the next
## sample. This sits 12.6% under the worst of thirteen. It records what shipping produced after the scrim
## went 0.80 to 0.28; it does not claim to know what the words OUGHT to read.
##
## The distribution is in two clumps, five near 57.5 and eight near 61, which is the sky's own phase and
## not the words changing. Neither clump is anywhere near this floor.
##
## BOTH OF THIS ARM'S NEW ASSERTIONS WERE SHOWN TO FAIL BEFORE EITHER WAS BANKED. This ratchet raised to
## 62.0, just over the best of thirteen, fails at 61.2. The ink ratio raised to 2000x fails at 103 drift px
## against a bar of 206000. That second mutant had to be run four times to land on a boot where the sky
## moved at all, which is the same duty cycle the sky-drift-ratio row is stood down for.
const SKY_WORDS_MED: float = 50.0
## HOW WIDE THE SEARCH FOR THE FIBRE IS, and the first version searched five image px either side, which
## is wide enough to catch something else. The control band's dE distribution came back with a mean of 4.6
## and a 95th percentile of 34.5; a tail that heavy in a band where nothing is over the rope is not drift,
## it is the tracer locking onto a different object. It is: the shaft is full of ORE GLINTS, they twinkle
## on their own clock, and `_rope_x` takes the brightest pixel in its window.
##
## The window is now the rope's own drawn width and nothing else. `_draw_ropes` strokes the fibre 1.8 world
## px wide with a shade 1.2 px behind it, which at 1.5 image px per world px is a little over four image px
## across, and the sway displaces it by at most 0.8 world px. Two either side covers the rope and excludes
## anything that is not the rope.
const ROPE_HALF: int = 2
const MIN_ROWS: int = 100          ## rope rows a band must contain before its figure means anything

## THERE IS NO "FRACTION OF THE ROPE OCCLUDED" FIGURE HERE, AND TWO ATTEMPTS AT ONE ARE WHY.
##
## The first counted rows past a flat 3.0 dE, underneath the control band's own mean drift of 4.7, so it
## counted the world moving as the ceremony arriving and reported 86-89%.
##
## The second set the threshold from the data: the 95th percentile of the dE on rope rows BELOW the plate,
## measured that run. That is the right idea and it is still not a statistic. **Two runs of the identical
## build put the threshold at 34.4 and at 4.4**: an eightfold swing, because a p95 over 151 samples is the
## 143rd value and one twinkling row moves it. The headline moved with it, 25% against 84%, for a subject
## that had not changed at all.
##
## The mean dE over the same rows was 25.8 and 26.0. **So the fraction is discarded and the means are
## reported.** A statistic that swings eightfold between identical runs is not a strict measurement of a
## noisy thing; it is a measurement of the threshold.

## The drift the two captures may accumulate between them. Measured at 4.5 dE across 151 control rows over
## the ~220 frames the plate needs to reach plateau; the bound is set well above that because it is a
## VOIDING check rather than a quality one: it fires when the world moved enough to swamp the subject, not
## when the world moved.
const DRIFT_CAP: float = 12.0

## How much louder the ceremony must be than the drift, in a patch of the plate AWAY from the rope. Away,
## because a positive control that reads the rope's own column would fail the day the ceremony is fixed to
## clear the rope; a control must survive the treatment it exists to make measurable.
const DREW_RATIO: float = 4.0

var _skipped: bool = false
var _w: int = 0
var _h: int = 0
var _sc: float = 1.0


func _initialize() -> void:
	print("== the interrupt, and the world underneath it ==")
	await _run()
	if _skipped:
		return
	_verdict("check_ceremony_reads", "the plate's effect on the rope is measured against a live control")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_skipped = true
		_skip_layer("check_ceremony_reads", "no display; every pixel of both captures would be blank, "
			+ "and the difference between two blank frames reads as a ceremony that draws nothing")
		return
	MainView.dev_start = false
	MainView.boot_skip_title = true
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	# THE HUMAN AT THE KEYBOARD IS NOT PART OF THE EXPERIMENT, and until now this layer never said so. It
	# posed nothing and deafened nothing, so for the whole run the aim tracked the operator's physical
	# mouse, and `world_renderer` eases the head-lamp toward the aim, which in this rig (a hand-built dark
	# shaft, no torches, no machines) is the ONLY light on the band being measured. A hand moving during
	# the run swings a 9-cell reveal and a 5.6-cell bloom across the control band.
	#
	# It is not the cause of the failure this fixes: the rock channel, which is what illumination moves,
	# read 0.7 against a calibrated 0.9 on the failing run, so the light demonstrably did NOT move that
	# time. It is closed because it is a live hole that would eventually produce a red nobody could
	# reproduce, and because leaving it open means the next surprising number here has two explanations.
	Controls.deaf = true
	Controls.pose_pointer(Vector2(float(SHAFT_COL) * 32.0, float(SHAFT_TOP) * 32.0))
	for _i: int in SETTLE:
		await physics_frame
	main._player.auto_input = false        # a hand on WASD would walk the body and take the camera with it
	_silence_lessons(main)

	_rig(main.sim)
	main.sim.inventory[&"rope"] = 60
	var hung: int = main.sim.place_rope(Vector2i(SHAFT_COL, SHAFT_TOP))
	main._renderer.repaint_world()
	await _park(main)
	await _drain(main)
	_check(hung >= 20, "the rig hangs a rope long enough to cross the plate (%d segments)" % hung)
	if hung < 20:
		return

	# THE REFERENCE FRAME MUST BE UNINTERRUPTED. Two `critical` surfaces fire on their own here: the game's
	# arrival plate, because standing the body in the rig crosses a band, and the ROPE lesson bubble. The
	# bubble matters more than its faintness suggests: `_rope_x` takes the brightest pixel in the column,
	# so a ghost letter lying on the rope BECOMES the rope and every reading afterwards is of the wrong
	# pixel.
	var quiet: int = 0
	while _interrupted(main) and quiet < QUIET_MAX:
		await physics_frame
		quiet += 1
	_check(not _interrupted(main), "the reference frame carries no interrupt of its own "
		+ "(waited %d frames; arrival %.2f, lesson %s, %d queued, hint %.2f)"
			% [quiet, main._hud._arrival_life, _lesson_name(main), main._hints._queue.size(),
				main._hud.hint_alpha])
	if _interrupted(main):
		return

	_sc = _screen_scale(main)
	var cx: int = int(round(_screen(main, Vector2(float(SHAFT_COL * CELL) + float(CELL) * 0.5, 0.0)).x))
	var body_y: int = int(round(_screen(main, main._player.position).y))
	var p: Image = await _shot()
	_w = p.get_width()
	_h = p.get_height()

	main._hud.announce("THE DEEPSLATE", "120 METRES DOWN", Color(0.56, 0.50, 0.78))
	var waited: int = 0
	while main._hud._arrival_life > PLATEAU and waited < 400:
		await physics_frame
		waited += 1
	var q: Image = await _shot()
	print("  the plate: announced, %d frames to plateau, _arrival_life %.2f (full alpha holds 1.42..2.83)"
		% [waited, main._hud._arrival_life])
	# NO SECOND INTERRUPT MAY ARRIVE BETWEEN THE CAPTURES, and the knockout run is what found this. With the
	# ceremony removed but the same interval held, the CONTROL band came back at 73.6 dE against the 4.0 it
	# reads normally, because a lesson bubble fires in that band about seventy frames after the HUD goes
	# quiet, and `_draw_hint_bubble` YIELDS TO THE PLATE. So the control band is quiet in a real run partly
	# because the ceremony is suppressing the other `critical` surface that would otherwise be sitting in
	# it. That is correct behaviour and it makes the control conditional on the treatment, which is worth
	# saying out loud rather than discovering as an unexplained red: if the bubble's timing ever drifts into
	# this window, the run must void by name instead of blaming the world for moving.
	_check(not _lesson_up(main),
		"no lesson bubble arrived between the two captures (lesson %s, %d queued, hint alpha %.2f)"
			% [_lesson_name(main), main._hints._queue.size(), main._hud.hint_alpha])

	var dump: String = OS.get_environment("SF_CEREMONY_DUMP")
	if dump != "":
		p.save_png(dump + "/ceremony_reference.png")
		q.save_png(dump + "/ceremony_plate.png")

	# WHERE THE PLATE LANDS, derived, and the derivation checked rather than assumed. `CANVAS` is 640x360;
	# the body, which the camera centres, photographs at half the frame height. One canvas px is therefore
	# `_h / 360` image px, and the plate runs `CANVAS.y * 0.26` minus `SCRIM_ABOVE` through plus
	# `SCRIM_BELOW`.
	var scale: float = float(_h) / 360.0
	_check(absf(float(body_y) - float(_h) * 0.5) <= 4.0,
		"the camera has the body at the centre of the frame, which the band is derived from (y=%d of %d)"
			% [body_y, _h])
	var top: int = int(round((0.26 * 360.0 - 32.0) * scale))
	var bot: int = int(round((0.26 * 360.0 + 18.0) * scale))
	var gap: int = int(8.0 * _sc)
	var c_top: int = bot + gap
	var c_bot: int = mini(c_top + (bot - top), body_y - int(14.0 * _sc))

	var over: Dictionary = _band(p, q, cx, top, bot)
	var under: Dictionary = _band(p, q, cx, c_top, c_bot)
	_check(int(over["rows"]) >= MIN_ROWS and int(under["rows"]) >= MIN_ROWS,
		"the rope was found in both bands (%d across the plate, %d below it)"
			% [over["rows"], under["rows"]])

	# THE CEREMONY DREW: read in a patch of the plate's core to the LEFT of the rope, so this control
	# still fires the day the plate is changed to clear the rope's own column.
	# CANVAS px, converted once. The first version wrote 320 and 150 meaning canvas offsets and then
	# multiplied them by the canvas scale as well, which put the "inside the plate" patch at image column
	# zero: the far left edge of the frame, outside the plate entirely. It read 0.0049 against 0.0058 and
	# reported that the ceremony had not drawn, in a frame where the ceremony is plainly legible. A control
	# aimed at the wrong place fails in the direction that looks like a finding.
	var patch_l: int = cx - int(80.0 * scale)     # inside the words, left of the rope's column
	var patch_r: int = cx - int(20.0 * scale)
	var drew: float = _patch(p, q, patch_l, patch_r, top, bot)
	var quiet_patch: float = _patch(p, q, patch_l, patch_r, c_top, c_bot)
	_check(drew > quiet_patch * DREW_RATIO,
		"the ceremony reached the frame — %.4f mean channel change inside the plate against %.4f below it"
			% [drew, quiet_patch])
	# THE MEDIAN CARRIES THE VOIDING CHECK, AND THE MEAN NO LONGER DOES. Measured on the failing run:
	#
	#     rope median 1.3   rope MEAN 18.6   rock mean 0.7      (calibration: 1.3 / 4.5 / 0.9)
	#
	# The median is its calibration value to the decimal, and the rock channel (which is what illumination
	# moves) did not move either. **A mean fourteen times its own median is a handful of rows, not a band
	# that moved.** That is exactly the distinction `_band`'s own comment says only the median can make,
	# written directly above an assertion that used the mean. The layer was fooled in the way it documented.
	#
	# This is NOT a loosened threshold. `DRIFT_CAP` is unchanged at 12.0, and the quantity it now bounds is
	# the one the check was always about: "did the world move enough to swamp the subject". A band that
	# really moves lifts every row, so the median rises and this fires. The knockout that justified the
	# check in the first place (a lesson bubble at 73.6 dE across the whole band) lifts every row too.
	_check(float(under["med"]) < DRIFT_CAP,
		"the band below the plate stayed still enough to serve as a control (median %.1f dE, cap %.1f; mean %.1f over %d rows)"
			% [under["med"], DRIFT_CAP, under["rope_de"], under["rows"]])
	# THE LOUD ROWS ARE REPORTED AND NOT ASSERTED, because what they are is not yet known and a ceiling
	# nobody can derive is a number that measures a guess. Measured: 19 and 20 of 151 rows over two runs, while
	# the median sits at the noise floor.
	#
	# REJECTED HYPOTHESIS, recorded so it is not proposed again: that `_rope_x`'s brightest-pixel search is
	# picking ore glints, which `7aff097` moved above the darkness veil after `ROPE_HALF = 2` was sized to
	# exclude them. It is a good story and it is wrong here: `_rig` sets every cell in the region to
	# `&"stone"`, so there is no ore in this world at all and no glint can be in this band.
	#
	# The live candidate is the rope's own sway. `_rope_x` picks a column in frame `p` and the comparison
	# reads that same column in `q`; the rope oscillates ~0.8 world px, so on any row where it crossed a
	# pixel boundary between the two captures the sample goes from rope to backing and scores a full
	# separation. That would lift a MINORITY of rows and leave the rest at the floor, which is the shape
	# observed, but it has not been tested, so it stays a candidate and not a finding.
	print("    loud rows in the control band: %d of %d over DRIFT_CAP (mechanism UNDETERMINED, see above)"
		% [under["loud"], under["rows"]])

	# WHAT THE SCRIM IS FOR, measured, because the obvious treatment for everything above is to weaken it,
	# and weakening the sole guarantor of a property without an instrument on that property is how a
	# disqualified cue takes a defect with it. The words are the pixels the ceremony ADDS light to; their
	# ground is everything else inside the same strip. If a later commit shrinks the veil, this number says
	# what it cost.
	var ink: Dictionary = _ink(p, q, cx, top, bot, int(120.0 * scale))
	_check(int(ink["px"]) >= 400,
		"the ceremony's own words were found in the frame (%d ink pixels)" % ink["px"])
	print("  the words: %d ink px, reading %.1f dE against the ground they sit on"
		% [ink["px"], ink["de"]])

	print("")
	print("  %-26s %6s %10s %10s %10s" % ["band", "rows", "rope med", "rope mean", "rock mean"])
	print("  %-26s %6d %10.1f %10.1f %10.1f"
		% ["ACROSS the ceremony", over["rows"], over["med"], over["rope_de"], over["rock_de"]])
	print("  %-26s %6d %10.1f %10.1f %10.1f"
		% ["below it (control)", under["rows"], under["med"], under["rope_de"], under["rock_de"]])
	print("")
	print("  the rope's own separation from its backing, where nothing is over it: %.1f dE across the "
		% over["contrast"] + "plate, %.1f dE below it" % under["contrast"])
	# The asymmetry IS the mechanism. A veil drawn to suppress the background that takes several times more
	# from the foreground has its effect inverted relative to its purpose.
	print("  the ceremony takes %.1fx more from the rope than from the rock behind it"
		% (float(over["rope_de"]) / maxf(float(over["rock_de"]), 0.001)))
	await _on_the_surface(main, ink)

	_stand_down("ceremony.rope-share", "how much of the rope an interrupt may take",
		"no design decision has been made about what the ceremony owes the world it interrupts; a bound "
		+ "guessed before that decision has been wrong four times in this repository")


## One band: how much of the rope the ceremony takes, how much it takes from the rock behind the rope, and
## how much separation the rope had there to begin with. The fibre's position is traced out of the
## REFERENCE frame, where nothing is over it; traced out of the ceremony frame the brightest pixel in the
## rope's column is a letter, and the plate would score as improving the rope's read.
func _band(p: Image, q: Image, cx: int, y0: int, y1: int) -> Dictionary:
	var rows: int = 0
	var rope_acc: float = 0.0
	var rock_acc: float = 0.0
	var sep_acc: float = 0.0
	var des := PackedFloat32Array()
	for y: int in range(maxi(0, y0), mini(_h, y1 + 1)):
		var x: int = _rope_x(p, cx, y)
		if x < 0:
			continue
		rows += 1
		var d: float = _de(_lab(p.get_pixel(x, y)), _lab(q.get_pixel(x, y)))
		rope_acc += d
		des.append(d)
		var bg_p := Color(0, 0, 0)
		var bg_q := Color(0, 0, 0)
		var m: int = 0
		for dx: int in range(int(7.0 * _sc), int(12.0 * _sc) + 1):
			for sgn: int in [-1, 1]:
				var bx: int = cx + sgn * dx
				if bx >= 0 and bx < _w:
					bg_p += p.get_pixel(bx, y)
					bg_q += q.get_pixel(bx, y)
					m += 1
		if m == 0:
			continue
		var mp := Color(bg_p.r / m, bg_p.g / m, bg_p.b / m)
		var mq := Color(bg_q.r / m, bg_q.g / m, bg_q.b / m)
		rock_acc += _de(_lab(mp), _lab(mq))
		sep_acc += _de(_lab(p.get_pixel(x, y)), _lab(mp))
	var n: float = maxf(float(rows), 1.0)
	var sorted: Array[float] = []
	for v: float in des:
		sorted.append(v)
	sorted.sort()
	# The MEDIAN beside the mean, because they answer different questions and this layer has been fooled by
	# the difference: a mean lifted by a handful of glyph rows and a mean lifted evenly by a veil are the
	# same number, and only the median tells them apart.
	var med: float = 0.0 if sorted.is_empty() else sorted[sorted.size() / 2]
	# HOW MANY ROWS ARE LOUD, beside how loud the average row is. The mean and the median disagreeing is the
	# signal that a handful of rows blew up; this says HOW MANY, which is what turns that from an inference
	# into a count. A band that genuinely moved lifts every row and `loud` approaches `rows`; a tracer that
	# wandered off the rope onto something bright lifts a few and leaves the rest at the noise floor.
	var loud: int = 0
	var loud_ys: Array[int] = []
	var y_at: int = maxi(0, y0)
	for v: float in des:
		if v > DRIFT_CAP:
			loud += 1
			loud_ys.append(y_at)
		y_at += 1
	# WHERE the loud rows are, not just how many. A mechanism that displaces a drawn line produces
	# CONTIGUOUS runs at the line's own periodicity; one that changes illumination scatters them flat. The
	# positions discriminate between those without another run.
	if OS.get_environment("SF_BAND_ROWS") == "1" and not loud_ys.is_empty():
		var runs: Array[String] = []
		var a: int = loud_ys[0]
		var b: int = loud_ys[0]
		for i: int in range(1, loud_ys.size()):
			if loud_ys[i] == b + 1:
				b = loud_ys[i]
			else:
				runs.append("%d-%d" % [a, b] if b > a else str(a))
				a = loud_ys[i]
				b = loud_ys[i]
		runs.append("%d-%d" % [a, b] if b > a else str(a))
		print("      loud runs (y0=%d): %s" % [y0, ", ".join(runs)])
	return {
		"rows": rows,
		"rope_de": rope_acc / n,
		"rock_de": rock_acc / n,
		"contrast": sep_acc / n,
		"med": med,
		"loud": loud,
	}


## THE SECOND STANDING, AND IT EXISTS BECAUSE OF WHAT WAS CHANGED TO GET THE FIRST ONE'S NUMBER DOWN.
##
## The plate's field veil dropped from alpha 0.80 to 0.28 and the words took their contrast locally
## instead, from a near-black shadow a pixel behind each glyph. That trade was measured **underground**,
## where the background is rock at a luma near ten, the case where the veil was doing least. **The surface
## is the case where it was doing most**, and a treatment validated only where the thing it replaced was
## useless has not been validated at all.
##
## Only the WORDS arm runs here. There is no rope on the surface to measure, and inventing one would be a
## rig answering the question it was built to ask.
##
## AND IT NOW READS AGAINST A DRIFT FLOOR TAKEN IN ITS OWN RUN. Everything this arm reports is a difference
## between two photographs of a background that moves whether or not the ceremony fires, so it takes a
## third frame (a second reference, one plate-wait after the first, with nothing announced) and runs the
## same comparison over the same band on that untreated pair. The plate's number is reported against it.
## The block inside says why the control is temporal rather than spatial, how the two intervals are
## matched, and what about them is not.
func _on_the_surface(main: MainView, deep: Dictionary) -> void:
	var col: int = SURFACE_COL
	var row: int = int(main.sim.surface_row(col)) - 2
	main._player.grapple.cut()
	main._player.position = main._cell_center(Vector2i(col, row))
	main._player.velocity = Vector2.ZERO
	for _i: int in 60:
		await physics_frame
	await _drain(main)
	var quiet: int = 0
	while _interrupted(main) and quiet < SURFACE_QUIET_MAX:
		await physics_frame
		quiet += 1
	if _interrupted(main):
		_stand_down("ceremony.words-vs-sky-arm", "the words against open sky",
			"the HUD would not go quiet at the surface, so there was no uninterrupted reference to read "
			+ "the words against")
		# AND THE READING ITSELF IS BELOW THIS RETURN, so on this path nothing ever decides about it. Said
		# out loud because the alternative is silence: `ceremony.words-vs-sky` is registered `always`, and
		# a run that returns here would have reported it as a debt the layer had quietly stopped owing,
		# which is the opposite of what happened. A branch cannot announce that it was not taken, so the
		# branch that DOES run announces it for its sibling.
		_not_reached("ceremony.words-vs-sky", "the surface arm returned before the reading: the HUD would"
			+ " not go quiet, so there was nothing to read the words against")
		return

	# The arm was measurable, which is the only thing its row is conditional on.
	_asserted("ceremony.words-vs-sky-arm")
	var cx: int = int(round(_screen(main, Vector2(float(col * CELL) + float(CELL) * 0.5, 0.0)).x))
	var p2: Image = await _shot()
	# THE SKY MOVES ON ITS OWN, AND NOTHING IN THIS ARM COULD TELL THAT APART FROM THE PLATE ARRIVING. The
	# underground standing has a spatial control (the band below the plate, same rope, same rock, same
	# lamp, no plate), and that band reading 1.3 median against the plate band's 21.2 is the whole reason
	# the deep arm's number is a measurement rather than a difference. Up here there is nowhere to put one,
	# and it is worth writing down that this was worked out rather than skipped: the plate's core reaches
	# ~114 canvas px either side of centre and `SCRIM_FEATHER` adds 96 more, some 420 px of a 640 px canvas,
	# and vertically the words sit at canvas y 61.6..111.6, so a band far enough ABOVE to clear the feather
	# is off the top of the frame, and one far enough BELOW is ground rather than sky. The control cannot be
	# placed in space here. It is placed in time instead.
	#
	# Two references with no announcement between them: `p2` at the moment the HUD went quiet, `p3` one
	# plate-wait later. `_ink` then runs over the identical band on that untreated pair (same statistic,
	# same pixels, same animation-phase separation, same run, same code path), and that is the floor the
	# plate's reading has to beat, in the plate's own units. The plate is measured against `p3` and not
	# `p2`, for two reasons: it keeps the treated interval exactly one plate-wait long, which is the
	# interval this arm has always used and the one its old numbers were taken over, and it makes the
	# control's second frame the treatment's first, so the two intervals abut with no gap between them.
	#
	# HOW THE INTERVALS ARE MATCHED, AND WHAT IS LEFT UNMATCHED. The plate wait is data-dependent: it spins
	# until `_arrival_life` has fallen from `Hud.ARRIVAL_HOLD` to `PLATEAU`, and `_process` takes a
	# real-time delta off that clock each rendered frame, so the wait is that many SECONDS of wall time
	# however many frames it costs. The control cannot watch the same clock, because starting it would mean
	# announcing, so it waits the frame count that interval comes to at the physics rate, with both terms
	# read from the things that actually govern the loop rather than typed in as a literal. What is NOT
	# matched is the box: physics frames only arrive at `physics_ticks_per_second` while the machine keeps
	# up, and the arrival clock is paced by RENDERED frames, so on a box that is dropping them the two
	# intervals come apart. Both counts print side by side below for exactly that reason. If they disagree
	# by more than a few frames the ratio underneath them is not a comparison, and the honest repair is to
	# re-derive the control interval from the measured `waited` rather than from the constants. The deep
	# arm prints its own frames-to-plateau earlier in the run, which is a second reading of the same wait on
	# the same machine to check this one against.
	#
	# AND ONE INTERVAL IS NOT A SAMPLE OF THIS BACKGROUND. What moves up here runs on several clocks and
	# none of them is anywhere near a plate-wait long: five clouds drift at 4 to 7 px/s on phases chosen to
	# be incommensurate, the bird crosses on `CYCLE = 47.0` and is only on screen for `CROSS_T = 16.0` of
	# that and only by day, and the whole sky breathes on `DAY_SECONDS = 480.0`. So this measures ONE PHASE
	# of each, not their envelope, and the bird is a duty-cycled cue, which is the exact shape that has
	# already produced a wrong statistic in this repository by being sampled over less than a period. No
	# period is going to be invented to divide by. The answer is repeats at different phases, pooled, which is
	# the same thing the surface reading itself needs before anything may be asserted about it.
	var drift_frames: int = ceili((Hud.ARRIVAL_HOLD - PLATEAU) * float(Engine.physics_ticks_per_second))
	for _i: int in drift_frames:
		await physics_frame
	var p3: Image = await _shot()
	# WHAT ELSE COULD HAVE ARRIVED IN THAT WINDOW, RECORDED RATHER THAN ASSERTED. Underground the equivalent
	# window carries a `_check` that no lesson bubble came between the captures, because one did once and
	# put that control band at 73.6 dE. The same hazard is here and it is worse in one specific way: the
	# plate SUPPRESSES the bubble across the treated interval (`_draw_hint_bubble` yields to it) and nothing
	# suppresses it across the control interval, so a bubble can only ever inflate the FLOOR and never the
	# reading above it, which is the direction that makes the ratio look worse than the truth rather than
	# better, but is still a void and not a result. The arrival life goes beside it because the other way to
	# ruin this pair is for the GAME to announce something into the control window, which is exactly how the
	# deep arm's first reference frame came back reading `25 METRES DOWN`. Both are sampled at the end of
	# the window, so a cue that rose and fell entirely inside it still hides, the same blind spot the deep
	# arm's check has. They are printed and not asserted because nothing has yet been agreed about what this
	# arm may demand, and a bound put here today would be a fifth guess ahead of its data.
	var hint_at_ref: float = main._hud.hint_alpha
	var arrival_at_ref: float = main._hud._arrival_life
	main._hud.announce("THE SURFACE", "", Color(0.82, 0.78, 0.60))
	var waited: int = 0
	while main._hud._arrival_life > PLATEAU and waited < 400:
		await physics_frame
		waited += 1
	var q2: Image = await _shot()
	var dump2: String = OS.get_environment("SF_CEREMONY_DUMP")
	if dump2 != "":
		# Both references, because which pair makes which number is not readable off the names: the drift
		# floor is (reference, reference_b) and the plate's reading is (reference_b, plate).
		p2.save_png(dump2 + "/ceremony_sky_reference.png")
		p3.save_png(dump2 + "/ceremony_sky_reference_b.png")
		q2.save_png(dump2 + "/ceremony_sky_plate.png")
	var scale: float = float(_h) / 360.0
	var top: int = int(round((0.26 * 360.0 - 32.0) * scale))
	var bot: int = int(round((0.26 * 360.0 + 18.0) * scale))
	var half: int = int(120.0 * scale)
	var ink: Dictionary = _ink(p3, q2, cx, top, bot, half)
	var drift: Dictionary = _ink(p2, p3, cx, top, bot, half)
	_check(int(ink["px"]) >= SKY_INK_MIN,
		"the words were found against open sky too (%d ink pixels at row %d)" % [ink["px"], row])
	# AND THE NUMBER THE BLOCK BELOW ASKED FOR NOW EXISTS, so the rewrite it called for is made here.
	#
	# Nine boots of this layer, drift px on the untreated pair: 0, 0, 1, 34, 125, 171, 200, 243, 247. The
	# worst is 62% of the 400 the control above demands. It has never failed and it was never SAFE: its
	# margin over the confound is 1.6x, on a cue that is duty-cycled and whose tail nine samples do not
	# bound. The comment below said that if the figure came back anywhere near 400 the assertion wants
	# rewriting rather than tightening, and 247 is near 400.
	#
	# The rewrite is a control that travels inside the measurement instead of a constant beside it. The
	# same statistic, the same band, the same interval length, in the same run: what the plate put on the
	# screen against what the sky put there by itself. Over those nine boots the plate read 6763 to 6929
	# ink px against a worst drift of 247, so the observed margin is 27x and the floor below leaves it
	# nearly seven times over. The 400 is KEPT rather than replaced, because the two fail differently: an
	# absolute count catches a run where nothing drew at all, and the ratio catches the case the absolute
	# count cannot see, which is words that vanished on a day the sky was moving.
	#
	# AND THE FIRST VERSION OF THIS WAS A GUARD THAT COULD NOT BE FALSE, which its own mutation control is
	# how I know. Written as a bare `ink >= drift * INK_OVER_DRIFT`, it reads `ink >= 0` on the three or
	# four boots in thirteen where the sky does not move at all, and a 100x mutant PASSED on such a run
	# while still counting toward this layer's asserted total. The bar is floored at the absolute count so
	# it is never weaker than the check above it and is strictly stronger whenever the sky moves.
	var sky_bar: int = maxi(int(drift["px"]) * INK_OVER_DRIFT, SKY_INK_MIN)
	_check(int(ink["px"]) >= sky_bar,
		"the words put more on the screen than the sky did by itself (%d ink px against a bar of %d: the "
			% [ink["px"], sky_bar]
			+ "sky's own %d px at %dx, floored at %d)" % [drift["px"], INK_OVER_DRIFT, SKY_INK_MIN])
	# WHAT THIS ARM COULD NOT SAY, AND WHAT THE LINE UNDER IT CHANGES. Three samples either side of a
	# treatment came back 49.5 / 61.9 / 62.0 and 49.0 / 52.2 / 68.4: bimodal in BOTH configurations, ranges
	# overlapping completely, and the highest of all six readings on the treated side. The background is a
	# live sky over vegetation at a surface row the rig does not pin, and it swings ~25% run to run, so the
	# number this arm printed was the plate arriving PLUS the sky moving with no way to separate them, and
	# all it could establish was that the words are drawn and separate from their ground at all.
	#
	# The drift line is the missing half of that: the same statistic over the same band on a pair of frames
	# the ceremony never touched, so the sky's own contribution is measured in the run rather than argued
	# about afterwards. It does not turn the reading into a claim (the ratio has to be watched across
	# several runs before anyone can say what it may demand), but it is the difference between a number
	# with a floor under it and a number floating on its own.
	#
	# THE PX COUNT IN THE DRIFT LINE IS THE ONE TO READ FIRST, and it is new evidence about an assertion
	# that has been passing here since the arm was written. `_ink` calls a pixel INK when it gained 0.05
	# luma between the two frames, and the `>= 400` above is that count. Nothing has ever established that
	# the sky alone cannot clear 400 over the same interval; the drift pair's own px count is the first
	# evidence either way. If it comes back anywhere near 400 then that assertion has been passing on drift
	# and wants rewriting rather than tightening. It is left exactly as it stands until the number exists.
	print("  the words, against open sky: %d ink px, %.1f dE mean, %.1f dE median (underground: %.1f mean)"
		% [ink["px"], ink["de"], ink["med"], deep["de"]])
	print("  the sky's own drift, same band, same length of interval, no plate: %d px, %.1f dE mean, "
		% [drift["px"], drift["de"]]
		+ "%.1f dE median over %d rows (at the second reference: hint alpha %.2f, arrival life %.2f)"
		% [drift["med"], drift["rows"], hint_at_ref, arrival_at_ref])
	print("  intervals: plate %d physics frames to plateau, drift control %d (derived, (%.2f - %.2f)s at "
		% [waited, drift_frames, Hud.ARRIVAL_HOLD, PLATEAU]
		+ "%d ticks/s) — a wide gap between those two means the pair is not a comparison"
		% Engine.physics_ticks_per_second)
	if int(drift["rows"]) == 0:
		print("  no ratio this run: no row of the untreated pair had four pixels brighten, so the floor is "
			+ "not a small number here, it is an empty one, and the ratio would be a division by nothing")
	else:
		print("  the plate reads %.1fx the drift on the means and %.1fx on the medians"
			% [float(ink["de"]) / maxf(float(drift["de"]), 0.001),
				float(ink["med"]) / maxf(float(drift["med"]), 0.001)])
	# THE DISTRIBUTION THIS ROW WAS WAITING FOR, AND WHY IT IS THE MEDIAN THAT CARRIES THE CLAIM.
	#
	# Nine boots, same commit, same rig. The MEAN is not a statistic here and never was:
	#
	#     mean dE      43.3 .. 55.1 over thirteen                              spread 11.8, 27% of the low
	#     median dE    57.2  57.4  57.6  57.6  58.4  60.1  60.6  60.8          spread  4.0, 7.0% of the low
	#                  61.0  61.0  61.0  61.2  61.2
	#
	# The old three-a-side table that this arm could not conclude anything from was built on the mean, and
	# the swing it recorded was the mean's. The median is the same thing the DEEP arm found: a handful of
	# rows where the sky moved lift a mean and leave a median alone. Four boots read a spread of 0.9, nine
	# read 3.8 and thirteen read 4.0, so the first figure was luck and is not quoted.
	#
	# THE FLOOR IS A RATCHET AND IS NOT A DESIGN BOUND. Nobody has decided what the words OUGHT to read
	# against open sky, and this does not decide it. It locks in what shipping already produced, 12.9%
	# under the worst of nine, so a collapse is caught and ordinary run-to-run motion is not. Lower it by
	# measurement if a deliberate change lowers the reading on purpose; never raise it to buy a green.
	#
	# It cannot be satisfied by a moving sky with the words gone, because the ratio control above fires
	# first: the median is taken over pixels the plate lit, and if the plate lit nothing there are no
	# pixels to take it over.
	_check(float(ink["med"]) >= SKY_WORDS_MED,
		"the ceremony's words read against open sky (%.1f dE median, ratchet %.1f, thirteen boots "
			% [ink["med"], SKY_WORDS_MED] + "spanned 57.2 to 61.2)")
	# WHAT IS STILL NOT ASSERTED, kept separate from what now is. The plate-over-drift RATIO on dE is the
	# other thing this arm could grow into, and it is not ready: over the boots where the drift had any
	# rows at all it ran 1.32x, 1.67x, 2.96x, 4.06x, 4.78x, 7.27x and 8.59x, and a bound near the worst of
	# those would convert a windy sky into a red about the words. The ink-px ratio above is asserted
	# instead because its margin is 27x rather than 1.32x. Printed, watched, not demanded.
	_stand_down("ceremony.sky-drift-ratio", "what the plate must beat the sky's own motion by, on dE",
		"nine boots put the dE ratio between 1.32x and 8.59x and left three of them with no drift rows at "
		+ "all, so the worst case is one sample of a duty-cycled cue; a bound there would fail on the "
		+ "weather rather than on the words, and the ink-px ratio is asserted in its place")


## HOW WELL THE CEREMONY'S OWN TYPE READS, row by row, inside the strip the words occupy.
##
## Ink is separated from ground by what the ceremony DID rather than by colour: the words add light, the
## veil takes it away, so `luma(with) - luma(without)` splits them without a palette assumption, which
## matters because a colour classifier keyed on the arrival tint would go blind under the very veil being
## measured, and because the tint changes per stratum.
func _ink(p: Image, q: Image, cx: int, y0: int, y1: int, half: int) -> Dictionary:
	var acc: float = 0.0
	var rows: int = 0
	var px: int = 0
	var des := PackedFloat32Array()
	for y: int in range(maxi(0, y0), mini(_h, y1 + 1)):
		var ink_c := Color(0, 0, 0)
		var gnd_c := Color(0, 0, 0)
		var ni: int = 0
		var ng: int = 0
		for x: int in range(maxi(0, cx - half), mini(_w, cx + half + 1)):
			var a: Color = p.get_pixel(x, y)
			var b: Color = q.get_pixel(x, y)
			var d: float = (0.2126 * b.r + 0.7152 * b.g + 0.0722 * b.b) \
				- (0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b)
			if d > 0.05:
				ink_c += b
				ni += 1
			else:
				gnd_c += b
				ng += 1
		px += ni
		if ni < 4 or ng < 4:
			continue
		var sep: float = _de(_lab(Color(ink_c.r / ni, ink_c.g / ni, ink_c.b / ni)),
			_lab(Color(gnd_c.r / ng, gnd_c.g / ng, gnd_c.b / ng)))
		acc += sep
		des.append(sep)
		rows += 1
	# THE MEDIAN AS WELL AS THE MEAN, for the reason `_band` already carries one: this file has twice been
	# fooled by a mean that a handful of rows lifted, and the surface arm is now comparing two of these
	# numbers against each other, where a few loud rows on either side would move the ratio without
	# anything having changed. A row here is a strip of the words, so a mean and a median that disagree say
	# the separation is coming from one or two lines of type rather than from the type. The mean stays the
	# headline because it is what every earlier reading of this arm was, and swapping the quantity under a
	# name is how a comparison to old numbers goes quietly wrong.
	var sorted: Array[float] = []
	for v: float in des:
		sorted.append(v)
	sorted.sort()
	var med: float = 0.0 if sorted.is_empty() else sorted[sorted.size() / 2]
	return {"px": px, "de": acc / maxf(float(rows), 1.0), "rows": rows, "med": med}


## Mean per-channel change across a rectangle: the positive control's statistic. Deliberately NOT a
## thresholded count: the scrim is multiplicative over rock at a luma near ten, so it moves a great many
## pixels a very short distance, and a count with a threshold on it is blind to exactly that.
func _patch(p: Image, q: Image, x0: int, x1: int, y0: int, y1: int) -> float:
	var acc: float = 0.0
	var n: int = 0
	for y: int in range(maxi(0, y0), mini(_h, y1 + 1)):
		for x: int in range(maxi(0, x0), mini(_w, x1 + 1)):
			var a: Color = p.get_pixel(x, y)
			var b: Color = q.get_pixel(x, y)
			acc += (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0
			n += 1
	return acc / maxf(float(n), 1.0)


func _rope_x(p: Image, cx: int, y: int) -> int:
	var best: int = -1
	var bl: float = -1.0
	for x: int in range(cx - ROPE_HALF, cx + ROPE_HALF + 1):
		if x < 0 or x >= _w:
			continue
		var c: Color = p.get_pixel(x, y)
		var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
		if l > bl:
			bl = l
			best = x
	return best


## A capture with the world stopped: frames keep being drawn so the progressive bake still drains, but the
## sway, the glints and the falling dust do not move. Unfrozen, two identical captures of this game differ
## by roughly 40% of the frame, which is forty thousand times the subject.
func _shot() -> Image:
	var was: float = Engine.time_scale
	Engine.time_scale = 0.0
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_root().get_texture().get_image()
	Engine.time_scale = was
	return img


func _rig(sim: FactorySim) -> void:
	for col: int in range(ROCK_L, ROCK_R + 1):
		for row: int in range(ROCK_TOP, ROCK_BOT + 1):
			sim.set_solid(Vector2i(col, row), &"stone")
	for col: int in range(SHAFT_COL - 1, SHAFT_COL + 2):
		for row: int in range(SHAFT_TOP, FLOOR_ROW):
			sim.set_solid(Vector2i(col, row), &"")


func _park(main: MainView) -> void:
	var pl: Player = main._player
	pl.grapple.cut()
	pl.position = main._cell_center(Vector2i(SHAFT_COL, STAND_ROW))
	pl.velocity = Vector2.ZERO
	pl.input_dir = 0.0
	pl.input_climb = 0.0
	pl.jump_held = false
	for _i: int in 50:
		await physics_frame


func _drain(main: MainView) -> void:
	var fine: Variant = main._renderer._fine
	if fine != null:
		fine.finish_pending()
	for _i: int in 8:
		await physics_frame


## Pose the lesson system the way a loaded save leaves it: every lesson already given, the queue empty,
## the edge snapshots re-armed against the world as it now stands. This is the game's own returning-player
## path, `restore_taught` then `resync`, and not a door cut for the test.
##
## It replaces a wait that could not have worked. When the rope lesson fires behind the arrival plate the
## frame needs `Hud.ARRIVAL_HOLD` plus `Hints.SHOW_SECONDS` to clear, which is 12.4 seconds, and QUIET_MAX
## is 600 physics frames, or 10.0. The budget was smaller than the requirement, so the red was structural
## and not weather. The green was the worse of the two outcomes: promotion sets `_life` to SHOW_SECONDS
## with nothing shown yet, so the first frame of the fade-IN reads alpha 0.00 exactly, the wait exited on
## it, and the layer went on to measure a rope with a letter arriving on top of it, which is the one thing
## the wait is there to prevent.
func _silence_lessons(main: MainView) -> void:
	var every: Array[String] = []
	for d: Dictionary in main._hints._defs:
		every.append(String(d["id"]))
	for m: Dictionary in main._hints._moments:
		every.append(String(m["id"]))
	main._hints.restore_taught(every)   # read off the tables, so a lesson added later is covered unasked
	main._hints.resync()


## A lesson is on screen, or one is waiting to be. The alpha alone cannot say this: it reads 0.00 both
## when a bubble has worn out and on the first frame of its fade-in, and only one of those is quiet.
func _lesson_up(main: MainView) -> bool:
	return main._hud.hint_alpha > 0.01 or main._hints._active != &"" or not main._hints._queue.is_empty()


## Nothing on the HUD is mid-announcement and no lesson is up or pending.
func _interrupted(main: MainView) -> bool:
	return main._hud._arrival_life > 0.0 or _lesson_up(main)


## The lesson holding the bubble, for a failure line that has to say which one.
func _lesson_name(main: MainView) -> String:
	return "none" if main._hints._active == &"" else String(main._hints._active)


func _screen(main: MainView, world: Vector2) -> Vector2:
	var vp: Viewport = main.get_viewport()
	return (vp.get_final_transform() * vp.get_canvas_transform()) * world


func _screen_scale(main: MainView) -> float:
	return _screen(main, Vector2(100.0, 0.0)).distance_to(_screen(main, Vector2.ZERO)) / 100.0


func _lab(c: Color) -> Vector3:
	var lr: float = _linear(c.r)
	var lg: float = _linear(c.g)
	var lb: float = _linear(c.b)
	var x: float = (lr * 0.4124 + lg * 0.3576 + lb * 0.1805) / 0.95047
	var y: float = lr * 0.2126 + lg * 0.7152 + lb * 0.0722
	var z: float = (lr * 0.0193 + lg * 0.1192 + lb * 0.9505) / 1.08883
	return Vector3(116.0 * _fl(y) - 16.0, 500.0 * (_fl(x) - _fl(y)), 200.0 * (_fl(y) - _fl(z)))


func _fl(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else (7.787 * t + 16.0 / 116.0)


func _linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


func _de(a: Vector3, b: Vector3) -> float:
	return (a - b).length()
