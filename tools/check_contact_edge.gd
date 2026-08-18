extends "res://tools/check_base.gd"

## WHERE ROCK MEETS AIR, THE MEETING ITSELF HAS TO BE VISIBLE.
##
## 6b, and it exists because 6a was retired on a contradiction rather than on a number. `check_rock_reads`
## asks whether a PATCH of unlit pixels is rock or air — a field question, answered by value. That question
## cannot be answered by any single constant, because air is legitimately two things: `check_room_reads`
## requires a carved room to read BRIGHTER than the mass it was cut from, and a natural void has to read as
## absence. Two layers assert opposite things about the same cells and no constant satisfies both.
##
## So this asks a different question, and the difference is the whole point. Not "what is this patch" but
## "is there an EDGE here, and which side of it is wall". A boundary cue can be present in a frame where
## every field cue has been argued into a contradiction, because it lives in the contact between two cells
## rather than in the value of either.
##
## TWO MEASURES, BECAUSE THEY FAIL INDEPENDENTLY, and a single score would hide which one is broken:
##
##   DETECTABILITY  does a real rock/air face produce a bigger luminance step than a rock/rock interior?
##                  (the tester scanning the dark: "is that an edge, or just more rock?")
##   POLARITY       across the faces that ARE edges, is the rock side reliably the same side?
##                  (having found an edge: "which side of it is wall?")
##
## A frame can pass one and fail the other, and the fixes differ — detectability wants contrast at the
## contact, polarity wants that contrast to point consistently. Reporting one number would average a
## legible frame with an illegible one and call it middling.
##
## MEASURED IDENTICALLY OR NOT AT ALL. The boundary and interior populations are sampled with the SAME
## geometry — two patches straddling a shared cell face, the same offset either side — so the only thing
## that differs between them is the ground truth. A comparison in which the two arms are measured
## differently is not a comparison, it is two measurements with a subtraction sign between them.
##
## THE ORACLE IS INDEPENDENT, inherited from 6a and non-negotiable: truth comes from `sim.is_solid`,
## evidence comes from `get_texture().get_image()`, and nothing in the render path is asked whether the
## render path worked.
##
##   godot --path . --script res://tools/check_contact_edge.gd     (NO --headless: it judges pixels)

## WHAT THIS LAYER CREDITS FOR THE CONTACT IS NOT WHAT DRAWS IT — measured 2026-08-18, and it supersedes
## every mention of `_draw_edge_ao` below.
##
## This file is written as though `TerrainPainter._draw_edge_ao` is the treatment under test: a warm lit lip
## on sky-facing tops, a rim on side walls, three 2px AO steps, concave scoops. That pass runs from
## `_paint_terrain_chunk`, the COARSE bake at z=-10, and `fine_terrain` writes alpha 255 over every solid
## cell at z=-9. Underground the fine layer covers it completely.
##
## Liveness control, because "the mutant changed nothing" and "the mutant never ran" are opposite
## conclusions that look identical: the coarse cell fill was forced to pure magenta and the pixels counted.
##
##     SURFACE (spawn view)              magenta = 7398
##     UNDERGROUND (a carved gallery)    magenta = 0
##
## The mutation is live and the coarse pass reaches the surface. It reaches NOTHING underground, which is
## where this layer judges. So `_draw_edge_ao` is baked on every dig and never seen here, and knocking it
## out leaves this layer's output byte-identical.
##
## WHAT THE STEP ACTUALLY IS, then: the rock-versus-back-wall MATERIAL difference, plus whatever
## `fine_terrain` itself draws at a face (`rim`, `rim_warm`, `_sky_form`, the "carved-edge AO" and "form
## sink" its own comment names). Measured against three independent knockouts, the subject is robust —
## `_draw_edge_ao` removed: 95%, unchanged. `_sky_form` zeroed: 96%. The tooth removed: 91%. Edge step
## median 10.4 against a flat-rock step of 1.5.
##
## MEASURED IN PIXELS BY c2, WITH A BASELINE, WHICH IS THE PART THAT MATTERS. My 7398/0 above mutated the
## coarse FILL -- a claim about the fill, not about the treatment. c2 mutated `_draw_edge_ao` ALONE and ran
## it BOTH WAYS, same seed, same standing, same detector, from a gallery fifty rows down so the surface
## cannot enter frame:
##
##                                        unpatched   patched   the treatment
##     SURFACE, at the opening, 1.00x           621      4741           +4120
##     UNDERGROUND, a deep gallery, 1.00x      7098      7082             -16
##
## UNDERGROUND THE PASS CONTRIBUTES NOTHING. Minus sixteen is zero with noise on it. An earlier figure of
## 247 is RETRACTED: it was the detector firing on the game's own dark chroma, which it does seven thousand
## times whether the pass draws or not. A magenta count without its unpatched column is not a measurement.
##
## In c2's words, and kept in them: **what the layer measures is the rock-versus-back-wall material step, and
## it does not depend on the contact pass at all -- `_draw_edge_ao` puts zero pixels on screen underground.**
##
## THE LAYER IS THEREFORE SOUND AND ITS STATED SUBJECT WAS WRONG, which is why the numbers are trustworthy
## and the prose was not.

const SCENE: String = "res://scenes/main.tscn"
const AGENT := preload("res://tools/play_agent.gd")
const SETTLE: int = 60

## THE FIXTURE HAS TO REACH ITS OWN SUBJECT, AND THE FIRST VERSION DID NOT.
##
## Inherited from check_rock_reads (16 rows, 11x6 chamber) so the layers would judge the same frame. On the
## first run that fixture produced 29 rock|air faces against a floor of 40, and the reason is worse than the
## number: `floor_row` excludes everything at or above SURFACE_LINE + SURFACE_CLEAR = row 42, and a 16-row
## delve from a surface at row 20 carves its chamber at row ~36. **Every cell of the carved space this layer
## exists to judge was discarded by this layer's own depth filter before it was measured.** The 29 faces
## that survived were incidental geometry elsewhere in frame, not the subject.
##
## What is NOT being changed to fix that, because the temptation runs the other way and this is the exact
## move I have spent the day refusing: `MIN_SAMPLES` stays 40, `SURFACE_CLEAR` stays 20, `DARK_CEILING`
## stays 34, `READ_FLOOR` stays 0.75. No floor moves. The delve goes deeper so that the chamber lands BELOW
## the exclusion line rather than above it — the same class of fix as check_fastforward's runway needing to
## be machine-free and inside the surface band. A fixture that is not standing where the effect is cannot be
## repaired by lowering the bar for what counts as having found it.
##
## The chamber is also widened, and for an independent reason: the lamp's widest veil cut is 9 cells, so an
## 11-wide room centred on the body is lit end to end and every contact edge in it is excluded as lit. The
## carved space has to be wider than the light that stands in the middle of it.
##
## THE FRAME IS 45x28 CELLS AT 48.0 CAPTURED PIXELS PER CELL, and the layer PRINTS that every run rather
## than anyone asserting it. The old "65x39 at zoom 1.0" was the broken projection below measuring itself:
## 65 columns falls out of ~29.5px per cell, which is what the hand-rolled arithmetic believed.
##
## I THEN GOT IT WRONG A SECOND TIME IN THIS COMMENT, and it is left recorded because the error is the
## interesting part. Replacing 65x39 I wrote "26x15", derived from 48 world units x 1.5 composite = 72px
## and 1920/72 -- reasoning from constants instead of reading the number the fixture prints. The composite
## does not multiply out that way at this camera; the engine transform reports 48.0px per cell and the view
## is 45 wide. Both wrong figures came from computing a measurement I could have run.
##
## A 41-WIDE CHAMBER THEREFORE FITS, and the single-viewpoint shortfall was never about the room being too
## wide. With the lens repaired, one standing found 33 rock|air faces against a floor of 40 and correctly
## refused to report, and the exclusion tally says why: 667 lit, 331 off the judged slab. The LAMP is the
## dominant term. It rides the body and the camera centres on the body, so the faces nearest the light are
## excluded for being lit, from every standing, and they are different faces each time.
##
## So the camera moves and the faces are deduped by cell pair: 33 -> 116, more than the 3x three standings
## would give, because pooling de-excludes as well as adds.
##
## CONSEQUENCE, STATED RATHER THAN BURIED: 6b no longer judges the identical frame 6a does. It judges the
## same KIND of place — deep unlit rock against carved void — at a depth where the filter both layers share
## actually admits it. Comparing the two numbers is still meaningful; claiming they are one frame is not.
const DELVE_ROWS: int = 30
const ROOM_W: int = 41
const ROOM_H: int = 7
const MIN_DELVE: int = 24
## Column offsets from the delve column, pooled. Same device as check_rock_reads, and for a sharper reason
## here: the lamp rides the body and the camera centres on the body, so ONE standing always judges the
## faces nearest the light and excludes them for being lit. One viewpoint is not a small sample of the
## chamber, it is a biased one, and the bias points at the cells the layer is built to exclude.
const VIEWPOINTS: Array[int] = [-13, 0, 13]

const HUD_TOP: float = 0.16
const HUD_BOTTOM: float = 0.20
const SURFACE_CLEAR: int = 20
const DARK_CEILING: float = 34.0
const MIN_SAMPLES: int = 40

## THE FLOOR, UNCHANGED FROM 6a AT 0.75, and unchanged on purpose. Moving the bar at the same moment as
## changing the measure would make the two results incomparable, which is the one thing 6b is for.
const READ_FLOOR: float = 0.75

## Sampling geometry at a face. Each patch sits FACE_OFFSET of a cell to its own side of the shared face,
## with a radius of PATCH_FRAC — so a patch spans 0.10..0.46 of a cell from the face and cannot reach
## across it. A patch that straddled the boundary would contain the edge itself and both arms would measure
## the same pixels.
const FACE_OFFSET: float = 0.28
const PATCH_FRAC: float = 0.18
const MIN_PATCH: int = 1

## Distances from the face, in world px, at which the luminance profile is taken. Negative is INTO THE AIR,
## positive is INTO THE ROCK. Dense in the first six pixels because that is the entire span
## `_draw_edge_ao` paints into — 3 steps x 2px of strip, plus the lit lip in step 0.
const PROFILE_PX: Array[float] = [-9.0, -5.0, -2.0, 1.0, 3.0, 5.0, 7.0, 9.0, 13.0, 17.0]

## Face orientations, because the treatment under test is directional by design.
const ORIENT_TOP: int = 0      ## the rock's sky-facing face — `_draw_edge_ao` paints a warm LIT lip here
const ORIENT_UNDER: int = 1    ## the rock's underside/ceiling — the darkest thing in the world (AO 0.46)
const ORIENT_SIDE: int = 2     ## a vertical wall — dim rim, then the mid AO
const ORIENT_NAME: Array[String] = ["rock TOP (lit lip)", "rock UNDER (ceiling)", "rock SIDE (wall)"]

## PRE-REGISTERED, BEFORE ANY NUMBER EXISTS. All four of these were written down before the layer was first
## run, because every one of them is a place where a later choice could be made to flatter a result.
##
## 1. THE NON-EDGE POPULATION IS ROCK INTERIOR ONLY — rock|rock faces, never air|air.
##    Air is close to featureless, so air|air faces produce near-zero steps, and including them would pad
##    the non-edge arm with easy cases and inflate detectability. Rock interior is the CONFUSABLE case: it
##    is where a false edge would come from, and it is what the tester's eye actually has to reject.
##    Choosing the harder comparison is the conservative one and it is chosen here, not after seeing both.
##
## 2. LODE-STAINED ROCK IS SAMPLED IN, AND REPORTED AS ITS OWN ARM.
##    A generated world now carries 378 lode cells, and the renderer stains a BURIED lode through its host
##    rock (`world_renderer.gd:1338`). Excluding them would make this instrument answer a question about a
##    world the player does not see. Stained rock is still rock. If the stained and unstained arms disagree,
##    that is a finding about ore tell doing legibility work and it is reportable in its own right rather
##    than something to average away.
##
## 3. A GREEN HERE DOES NOT CLOSE 6a, AND DOES NOT BY ITSELF CLOSE T3.1.
##    6a's own pre-registration says a local green over a global red is a finding about boundaries versus
##    fields, not a close. That still binds. A green 6b against a red 6a means one specific thing — the
##    world is readable at boundaries and unreadable in the field — and whether that suffices for a
##    first-timer is the naive vision agent's call. This statistic is evidence for that judgement, not the
##    judgement.
##
## 4. THIS RUNS ON A GENERATED WORLD AND SAYS SO.
##    Controlled-fixture evidence and generated-world evidence are not interchangeable and every assertion
##    here names which it is. The fixture DIGS into a generated world; it does not inject its subject.
const WORLD_KIND: String = "GENERATED WORLD (the fixture digs into it; nothing is injected)"


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		_skip_layer("check_contact_edge",
			"no display; whether a rock/air contact is visible cannot be judged by the dummy renderer")
		return
	MainView.dev_start = false
	await _run()


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var reached: int = await _delve(main)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw          # the veil/light layers repaint a frame behind a move

	print("== where rock meets air, the meeting has to be visible (6b) ==")
	print("  world: %s" % WORLD_KIND)
	print("  the delve reached %d rows below the surface (asked for %d, floor %d)"
		% [reached, DELVE_ROWS, MIN_DELVE])
	if reached < MIN_DELVE:
		printerr("check_contact_edge: FAIL — the delve reached %d rows of %d, so the frame is not deep"
			% [reached, DELVE_ROWS] + " unlit rock and the standard written for it does not apply.")
		printerr("  This is the FIXTURE failing to reach its subject, not a verdict on the contact edge.")
		quit(1)
		return

	var home: Vector2i = main._cell_at(main._player.position)
	var seen: Dictionary = {}
	var s: Dictionary = {}
	for off: int in VIEWPOINTS:
		main._player.position = main._cell_center(Vector2i(home.x + off, home.y))
		main._player.velocity = Vector2.ZERO
		for _i: int in 16:
			await physics_frame
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		s = _merge(s, _sample(main, get_root().get_texture().get_image(), seen))
	var edge_step: Array[float] = s["edge_step"]
	var flat_step: Array[float] = s["flat_step"]
	var signed: Array[float] = s["edge_signed"]
	var signed_stained: Array[float] = s["edge_signed_stained"]
	var signed_plain: Array[float] = s["edge_signed_plain"]

	print("  sampled %d rock|air faces and %d rock|rock faces (%d skipped: %d near the surface, %d lit,"
		% [edge_step.size(), flat_step.size(), int(s["skipped"]), int(s["near_surface"]), int(s["lit"])]
		+ " %d off the judged slab, %d touching water, %d air|air by design)"
		% [int(s["offslab"]), int(s["wet"]), int(s["airair"])])

	# NON-VACUITY FIRST. Both statistics below are ratios over pairs, and a ratio over a handful of faces is
	# not a small result, it is no result — and it flatters.
	_check(edge_step.size() >= MIN_SAMPLES,
		"%d rock|air faces were found to judge (floor %d)" % [edge_step.size(), MIN_SAMPLES])
	_check(flat_step.size() >= MIN_SAMPLES,
		"%d rock|rock faces were found to judge (floor %d)" % [flat_step.size(), MIN_SAMPLES])
	if edge_step.size() < MIN_SAMPLES or flat_step.size() < MIN_SAMPLES:
		printerr("check_contact_edge: FAIL — too few faces to say anything; the numbers below would be"
			+ " arithmetic about a handful of pixels, so they are not printed as a verdict")
		quit(1)
		return

	var lum: Array[float] = s["luma"]
	var med: float = _median(lum)
	_check(med <= DARK_CEILING,
		"the sampled region is actually dark — median luminance %.1f, ceiling %.1f (a brighter region than"
			% [med, DARK_CEILING] + " this is not the place the complaint was about)")

	var detect: float = _readability(edge_step, flat_step)
	var polarity: float = _consistency(signed)
	print("  DETECTABILITY: rock|air step median %.1f, rock|rock step median %.1f -> a real edge outsteps an"
		% [_median(edge_step), _median(flat_step)]
		+ " interior %.0f%% of the time" % [detect * 100.0])
	print("  POLARITY:      the rock side is the %s one on %.0f%% of edges"
		% ["brighter" if _lean(signed) > 0.0 else "darker", polarity * 100.0])
	print("  (a coin flip is 50%% for both; the floor is %.0f%%)" % [READ_FLOOR * 100.0])

	print("  edge step spread: %s" % _shape(edge_step))
	print("  flat step spread: %s" % _shape(flat_step))

	# THE PROFILE ACROSS THE FACE. Negative is into the air, positive into the rock. It was sized against
	# `_draw_edge_ao` painting "the first 6px of a 32px cell" — both halves of which are false. The cell is
	# 48px captured, not 32 (the broken lens's figure), and that pass does not reach this frame at all. The
	# profile survives the correction because what it actually does is show WHERE the step lives, which is
	# worth printing whatever draws it: a flat profile means the verdict above is about where this layer
	# looked, and a stepped one means it is about the world.
	var prof: Array = s["profile"]
	var line: String = ""
	for k: int in PROFILE_PX.size():
		var arr: Array[float] = prof[k]
		line += "%+d:%s  " % [int(PROFILE_PX[k]), ("%.1f" % _median(arr)) if not arr.is_empty() else "--"]
	print("  luminance profile from the face (- air, + rock), median over %d faces:" % edge_step.size())
	print("    pooled:  %s" % line)
	# BY ORIENTATION, because pooled cancels a key light against itself. If the lip and the ceiling AO are
	# reaching the eye, TOP and UNDER must diverge here in opposite directions inside the first 6px.
	var por: Array = s["prof_or"]
	var sor: Array = s["signed_or"]
	var tor: Array = s["step_or"]
	for o: int in 3:
		var ln: String = ""
		for k: int in PROFILE_PX.size():
			var arr: Array[float] = por[o][k]
			ln += "%+d:%s  " % [int(PROFILE_PX[k]), ("%.1f" % _median(arr)) if not arr.is_empty() else "--"]
		print("    %-22s %s" % [ORIENT_NAME[o], ln])
	print("  by orientation — n, step median, polarity WITHIN that orientation:")
	for o: int in 3:
		var sg: Array[float] = sor[o]
		var st: Array[float] = tor[o]
		print("    %-22s n=%3d  step %5.2f  polarity %3.0f%%%s"
			% [ORIENT_NAME[o], sg.size(), _median(st), _consistency(sg) * 100.0,
				"" if sg.size() >= MIN_SAMPLES else "   [below the %d floor — no conclusion]" % MIN_SAMPLES])

	# THE STAINED ARM, REPORTED SEPARATELY AND NEVER FOLDED IN. Pre-registered above. If these two disagree
	# it means ore tell is carrying legibility that plain rock does not have, which is a finding about what
	# is doing the work — and a fix aimed at the pooled number would be aimed at the wrong half.
	print("  polarity by host: %d plain-rock edges at %.0f%%, %d lode-stained edges at %.0f%%"
		% [signed_plain.size(), _consistency(signed_plain) * 100.0,
			signed_stained.size(), _consistency(signed_stained) * 100.0])
	if signed_stained.size() < MIN_SAMPLES or signed_plain.size() < MIN_SAMPLES:
		print("    (one arm is below the %d-sample floor, so the split is DIAGNOSTIC ONLY and no"
			% MIN_SAMPLES + " conclusion is drawn from the difference between them)")

	_check(detect >= READ_FLOOR,
		"a rock/air contact is distinguishable from rock's own texture — %.0f%% (floor %.0f%%)"
			% [detect * 100.0, READ_FLOOR * 100.0])
	_check(polarity >= READ_FLOOR,
		"having found an edge, you can tell which side is wall — %.0f%% (floor %.0f%%)"
			% [polarity * 100.0, READ_FLOOR * 100.0])

	main.queue_free()
	await physics_frame
	_verdict("check_contact_edge", "%d edges / %d interiors, detect %.0f%%, polarity %.0f%% [%s]"
		% [edge_step.size(), flat_step.size(), detect * 100.0, polarity * 100.0, WORLD_KIND])


## Walk every horizontally- and vertically-adjacent cell pair on the judged slab and record the luminance
## step across the shared face, split by what the sim says the pair actually is.
func _sample(main: MainView, img: Image, seen: Dictionary) -> Dictionary:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var top: int = int(float(h) * HUD_TOP)
	var bottom: int = int(float(h) * (1.0 - HUD_BOTTOM))
	# THE ENGINE'S OWN WORLD->PIXEL MAPPING, and its absence here is why every number this layer has ever
	# printed was taken through a broken lens. What stood here was `(world - cam) * zoom + image_size * 0.5`,
	# which assumes the captured image and the canvas share a coordinate space. They do not: project.godot
	# renders the canvas at 1280x720 and composites it 1.5x into the 1920x1080 framebuffer that
	# get_texture().get_image() returns, so a cell is 48 captured pixels where this arithmetic believed 32.
	#
	# THE ERROR IS BIASED, NOT NOISY, AND IT BIASES TOWARD THIS LAYER'S OWN NULL. A face at offset D from the
	# camera was sampled at the pixel belonging to the world point at 2/3 D -- always pulled inboard, toward
	# the centre of the view. An instrument asking whether an EDGE reads was handed the INTERIOR beside it,
	# so "the contact carries no information" was the answer it was built to give whether or not it was true.
	#
	# `c6f23b8` repaired exactly this in check_rock_reads and check_opening on 2026-08-17 and NEVER REACHED
	# THIS FILE -- it is absent from `git log -- tools/check_contact_edge.gd`. The 86%/95% reading in
	# run_harness.sh came from the peer's branch, where it had been applied; main has been running the
	# withdrawn lens ever since, and reproduces the withdrawn numbers (51%, steps 1.26-4.49) on demand.
	#
	# I THEN CLAIMED THIS EXPLAINED THE MAGENTA NULL, AND IT DOES NOT. Forcing `_draw_edge_ao`'s lip to pure
	# magenta once changed NOTHING here, and I wrote that off as the broken lens looking past the face it
	# painted. Then I knocked the whole pass out under the REPAIRED lens and the output was byte-identical
	# -- so the lens was never the reason. See the header: the coarse pass this layer credits is invisible
	# underground, measured at zero. Two independent faults stacked, and I attributed both to the one I had
	# just fixed, which is the more seductive error because the fix was real.
	var to_px: Transform2D = main.get_viewport().get_final_transform() \
		* main.get_viewport().get_canvas_transform()
	var cell_px: float = to_px.basis_xform(Vector2(float(WorldRenderer.CELL), 0.0)).length()
	var patch: int = maxi(MIN_PATCH, int(cell_px * PATCH_FRAC))
	# WORLD UNITS, because it is subtracted in world space and transformed afterwards. It was
	# `cell_px * FACE_OFFSET`, which is CELL * zoom * FACE_OFFSET — a SCREEN-space length applied before the
	# `* zoom`, so the real offset was CELL * FACE_OFFSET * zoom². Harmless at the zoom 1.0 every reading so
	# far was taken at, and silently wrong at any other, which is the kind of latent defect that surfaces as
	# an unexplained drift the day someone changes a camera default.
	var off: float = float(WorldRenderer.CELL) * FACE_OFFSET

	var scratch: PackedByteArray = main._renderer._veil_scratch
	var base: PackedByteArray = main._renderer._veil_base
	var want_bytes: int = FactorySim.GRID_COLS * FactorySim.GRID_ROWS * 4
	if scratch.size() != want_bytes or base.size() != want_bytes:
		# FALL TO THE FAILING SIDE, same as 6a. Without these buffers every cell tests as unlit, the sample
		# silently becomes "the whole frame including the lamp pool", and the layer reports on a different
		# question than the one it is named for — while looking GREENER, because a lit edge reads.
		printerr("check_contact_edge: FAIL — the veil buffers are %d/%d bytes, expected %d; the lit/unlit"
			% [scratch.size(), base.size(), want_bytes]
			+ " split cannot be computed and every cell would count as dark")
		quit(1)
		return {}

	var profile: Array[Array] = []
	for _k: int in PROFILE_PX.size():
		profile.append([] as Array[float])
	var prof_or: Array[Array] = []
	var signed_or: Array[Array] = []
	var step_or: Array[Array] = []
	for _o: int in 3:
		var per: Array[Array] = []
		for _k: int in PROFILE_PX.size():
			per.append([] as Array[float])
		prof_or.append(per)
		signed_or.append([] as Array[float])
		step_or.append([] as Array[float])
	var edge_step: Array[float] = []
	var flat_step: Array[float] = []
	var edge_signed: Array[float] = []
	var edge_signed_stained: Array[float] = []
	var edge_signed_plain: Array[float] = []
	var luma: Array[float] = []
	var near_surface: int = 0
	var lit: int = 0
	var offslab: int = 0
	var wet: int = 0
	var airair: int = 0

	# Inverted out of the same transform. `Vector2(w, h) / zoom * 0.5` read IMAGE pixels as world units and
	# swept a box half again wider than anything on screen.
	var inv: Transform2D = to_px.affine_inverse()
	var wa: Vector2 = inv * Vector2.ZERO
	var wb: Vector2 = inv * Vector2(float(w), float(h))
	var c0: Vector2i = main._cell_at(Vector2(minf(wa.x, wb.x), minf(wa.y, wb.y))) - Vector2i(2, 2)
	var c1: Vector2i = main._cell_at(Vector2(maxf(wa.x, wb.x), maxf(wa.y, wb.y))) + Vector2i(2, 2)
	c0 = Vector2i(maxi(c0.x, 0), maxi(c0.y, 0))
	c1 = Vector2i(mini(c1.x, FactorySim.GRID_COLS - 1), mini(c1.y, FactorySim.GRID_ROWS - 1))

	# Absolute, not per-column — `surface_row` has no memory of the original terrain, so on a dug column it
	# reports the bottom of the player's own shaft and would exclude exactly the carved space under test.
	# This is the bug that made 6a's fixture drift run to run; the same trap applies here verbatim.
	var floor_row: int = WorldRenderer.SURFACE_LINE + SURFACE_CLEAR
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]   # each unordered pair visited once
	# WHAT THE FIXTURE ACTUALLY HAS TO WORK WITH, printed every run. The first run found 29 rock|air faces
	# against a floor of 40, and the reason mattered more than the number: sizing the carved space is a
	# trade between "big enough that its edges fall outside the lamp" and "small enough to stay on screen",
	# and both bounds are measurements rather than preferences. Guessing at either is how a fixture ends up
	# not standing where the effect is.
	print("  view: %d x %d cells (cols %d..%d, rows %d..%d), cell %.1fpx, patch %dpx, face offset %.1fpx"
		% [c1.x - c0.x + 1, c1.y - c0.y + 1, c0.x, c1.x, c0.y, c1.y, cell_px, patch, off])

	for cx: int in range(c0.x, c1.x + 1):
		for cy: int in range(c0.y, c1.y + 1):
			var a := Vector2i(cx, cy)
			for d: Vector2i in dirs:
				var b: Vector2i = a + d
				if b.x > c1.x or b.y > c1.y:
					continue
				# DE-DUPLICATED HERE AND NOWHERE EARLIER, so a face rejected as LIT from one standing stays
				# eligible from the next — which is the entire point of moving the camera.
				var fkey: String = "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
				if seen.has(fkey):
					continue
				if a.y <= floor_row or b.y <= floor_row:
					near_surface += 1
					continue
				if _is_lit(scratch, base, a) or _is_lit(scratch, base, b):
					lit += 1
					continue
				# Water is neither wall nor hole and a player is never confused about which it is;
				# check_water_reads owns whether it reads. Counting it here would not make the measurement
				# harder, it would make it about something else. (6a found this the hard way: flooded cells
				# counted as air gave the air population two homes.)
				if main.sim.water_at(a) > 0 or main.sim.water_at(b) > 0:
					wet += 1
					continue
				var sa: bool = main.sim.is_solid(a)
				var sb: bool = main.sim.is_solid(b)
				if not sa and not sb:
					airair += 1                       # excluded by pre-registration, counted so it is visible
					continue
				var face: Vector2 = (main._cell_center(a) + main._cell_center(b)) * 0.5
				var n: Vector2 = Vector2(float(d.x), float(d.y))
				var pa: Vector2 = to_px * (face - n * off)
				var pb: Vector2 = to_px * (face + n * off)
				if not _on_slab(pa, patch, w, top, bottom) or not _on_slab(pb, patch, w, top, bottom):
					offslab += 1
					continue
				# MARKED SEEN ONLY HERE, past every rejection above. A face excluded for being lit or off
				# the slab from this standing must stay eligible from the next one, or pooling would lock
				# in the first viewpoint's exclusions and three standings would sample the same biased set.
				seen[fkey] = true
				# THE PROFILE ACROSS THE FACE, sampled at single pixels rather than in a patch, because the
				# thing it is looking for is only a few pixels wide and a patch would average it away.
				#
				# This exists because `TerrainPainter._draw_edge_ao` ALREADY draws a contact treatment — a
				# lit lip on sky-facing tops, a rim on side walls, three 2px AO steps and concave scoops —
				# and all of it lives in the first 6px of a 32px cell. The two-patch measure above centres
				# 9px from the face with a 5px radius, so it samples 4..14px and can capture at most the
				# outer sliver of a 6px treatment. Before "the contact carries no information" can be a
				# claim about the WORLD, it has to survive the possibility that it is a claim about where
				# this instrument happened to look.
				# ORIENTATION IS NOT A NUISANCE HERE, IT IS THE SUBJECT. `_draw_edge_ao` is a KEY LIGHT from
				# above, not uniform occlusion — its own comment says so: "occlusion alone can't make a
				# form". A sky-facing face gets a warm LIT lip (alpha 0.30), an underside falls into the
				# darkest thing in the world (0.46), and side walls take a dim rim then a mid AO (0.14 /
				# 0.26). So the rock side is deliberately BRIGHTER at a top face and DARKER at a ceiling.
				#
				# Pooling those into one median cancels them against each other, and pooling them into one
				# polarity statistic is worse than that: it tests "is the rock side always the same side",
				# a rule this renderer never claimed and deliberately breaks. **A perfectly executed key
				# light scores ~50% on a pooled polarity measure by construction.** That is my statistic
				# encoding an assumption its subject does not share — the same error as every population
				# mistake in this project, one level up, in the verdict rather than the sample.
				var orient: int = ORIENT_SIDE
				if d.y == 1:
					orient = ORIENT_UNDER if sa else ORIENT_TOP
				if sa != sb:
					var rock_dir: Vector2 = -n if sa else n
					for k: int in PROFILE_PX.size():
						var wp: Vector2 = face + rock_dir * PROFILE_PX[k]
						var sp: Vector2 = to_px * wp
						if sp.x < 1.0 or sp.y < float(top) or sp.x >= float(w - 1) or sp.y >= float(bottom):
							continue
						var v: float = _patch_luma(img, int(sp.x), int(sp.y), 0)
						profile[k].append(v)
						prof_or[orient][k].append(v)
				var la: float = _patch_luma(img, int(pa.x), int(pa.y), patch)
				var lb: float = _patch_luma(img, int(pb.x), int(pb.y), patch)
				luma.append(la)
				luma.append(lb)
				if sa and sb:
					flat_step.append(absf(la - lb))
				else:
					edge_step.append(absf(la - lb))
					# Signed toward ROCK: positive means the rock side was brighter. The sign is what
					# polarity is about, so it is kept rather than folded here.
					var rock_first: bool = sa
					var sgn: float = (la - lb) if rock_first else (lb - la)
					edge_signed.append(sgn)
					var rock_cell: Vector2i = a if rock_first else b
					if main.sim.lode.has(rock_cell):
						edge_signed_stained.append(sgn)
					else:
						edge_signed_plain.append(sgn)
					signed_or[orient].append(sgn)
					step_or[orient].append(absf(la - lb))

	return {"edge_step": edge_step, "flat_step": flat_step, "edge_signed": edge_signed,
		"edge_signed_stained": edge_signed_stained, "edge_signed_plain": edge_signed_plain,
		"luma": luma, "near_surface": near_surface, "lit": lit, "offslab": offslab, "wet": wet,
		"airair": airair, "profile": profile, "prof_or": prof_or, "signed_or": signed_or,
		"step_or": step_or,
		"skipped": near_surface + lit + offslab + wet + airair}


## POOL TWO SAMPLES. The payloads are three shapes and each needs its own rule: flat Array[float] arms
## concatenate, the per-index Array[Array] profiles (profile, prof_or, signed_or, step_or) concatenate
## INSIDE each index, and the exclusion counters add. A generic "append if Array" would flatten the nested
## ones into a single bucket and silently destroy the per-orientation split that this layer's whole
## argument rests on — the key light makes TOP and UNDER point opposite ways, and merging them is the
## error the layer already documents at the verdict level.
func _merge(dst: Dictionary, src: Dictionary) -> Dictionary:
	if src.is_empty():
		return dst
	if dst.is_empty():
		return src
	for k: String in src:
		if k == "prof_or":
			# NESTED TWICE: orientation, then profile index. A single-level merge here would append the
			# inner per-index ARRAYS as elements instead of concatenating their contents, turning three
			# 10-slot profiles into a 30-slot list of arrays and quietly destroying the per-orientation
			# split the layer's whole argument rests on.
			var doo: Array = dst[k]
			var soo: Array = src[k]
			for o: int in soo.size():
				var dk: Array = doo[o]
				var sk: Array = soo[o]
				for i: int in sk.size():
					var dii: Array = dk[i]
					dii.append_array(sk[i] as Array)
		elif k == "profile" or k == "signed_or" or k == "step_or":
			var da: Array = dst[k]
			var sa: Array = src[k]
			for i: int in sa.size():
				var di: Array = da[i]
				di.append_array(sa[i] as Array)
		elif dst[k] is Array:
			(dst[k] as Array).append_array(src[k] as Array)
		else:
			dst[k] = int(dst[k]) + int(src[k])
	return dst


## A cell the veil never brightened — scratch bytes still equal base bytes, so no source reached it. Any
## light source added later appears in the buffer and is excluded automatically, where a hand-kept radius
## list would have to be remembered.
func _is_lit(scratch: PackedByteArray, base: PackedByteArray, c: Vector2i) -> bool:
	var i: int = (c.y * FactorySim.GRID_COLS + c.x) * 4
	return scratch[i] != base[i] or scratch[i + 1] != base[i + 1] or scratch[i + 2] != base[i + 2]


func _on_slab(p: Vector2, r: int, w: int, top: int, bottom: int) -> bool:
	return p.x - float(r) >= 0.0 and p.x + float(r) < float(w) \
		and p.y - float(r) >= float(top) and p.y + float(r) < float(bottom)


func _patch_luma(img: Image, cx: int, cy: int, r: int) -> float:
	var n: int = 0
	var sum: float = 0.0
	for y: int in range(cy - r, cy + r + 1):
		for x: int in range(cx - r, cx + r + 1):
			var col: Color = img.get_pixel(x, y)
			sum += (col.r * 0.299 + col.g * 0.587 + col.b * 0.114) * 255.0
			n += 1
	return sum / float(n) if n > 0 else 0.0


## HOW OFTEN A REAL EDGE OUTSTEPS AN INTERIOR — the same Mann-Whitney statistic 6a uses, folded for the
## same reason: a frame where interiors consistently outstep real edges is perverse but readable once
## learned, and it is the OVERLAP that cannot be read at all.
func _readability(a: Array[float], b: Array[float]) -> float:
	if a.is_empty() or b.is_empty():
		return 0.0
	var wins: float = 0.0
	for x: float in a:
		for y: float in b:
			if x > y:
				wins += 1.0
			elif x == y:
				wins += 0.5
	var auc: float = wins / float(a.size() * b.size())
	return maxf(auc, 1.0 - auc)


## HOW OFTEN THE ROCK SIDE IS THE SAME SIDE — polarity as the player would learn it.
##
## Not an AUC: polarity is not about two populations, it is about whether ONE population has a consistent
## sign. A player who notices "the wall side is the darker one" is right exactly as often as that rule
## holds, so the score is the share agreeing with the majority direction. A face with no step at all told
## you nothing and counts as half, exactly as a tie does in the AUC.
##
## The scale matches `_readability` deliberately: 0.50 is no information, 1.00 is a rule that always holds,
## and the same floor can be applied to both without one of them meaning something different.
func _consistency(signed: Array[float]) -> float:
	if signed.is_empty():
		return 0.0
	var pos: float = 0.0
	var neg: float = 0.0
	for v: float in signed:
		if v > 0.0:
			pos += 1.0
		elif v < 0.0:
			neg += 1.0
		else:
			pos += 0.5
			neg += 0.5
	return maxf(pos, neg) / float(signed.size())


## Which way the majority leans, for the report only — never for the verdict, which is direction-blind.
func _lean(signed: Array[float]) -> float:
	var sum: float = 0.0
	for v: float in signed:
		sum += v
	return sum


func _shape(a: Array[float]) -> String:
	if a.is_empty():
		return "none"
	var s: Array[float] = a.duplicate()
	s.sort()
	var q := func(f: float) -> float: return s[clampi(int(float(s.size()) * f), 0, s.size() - 1)]
	return "min %.1f  p25 %.1f  med %.1f  p75 %.1f  max %.1f  (IQR %.1f)" % [s[0], q.call(0.25),
		q.call(0.50), q.call(0.75), s[s.size() - 1], q.call(0.75) - q.call(0.25)]


func _median(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var s: Array[float] = a.duplicate()
	s.sort()
	return s[s.size() / 2]


## The shaft and the work chamber, cut by the real agent through the real verbs — lifted from
## check_rock_reads so the two layers judge the same frame. Returns rows below the PRE-DIG surface.
func _delve(main: MainView) -> int:
	var agent: PlayAgent = AGENT.new(self, main)
	agent.give(&"stone_pickaxe", 1)
	var here: Vector2i = main._cell_at(agent.player.position)
	var from_surface: int = main.sim.surface_row(here.x)
	var target := Vector2i(here.x, from_surface + DELVE_ROWS)
	# THE DELVE REPORTS ITS OWN INPUTS, every run. A 30-row delve came back having moved nowhere and with
	# no note from the agent, which meant `dig_down_to` had returned true on its FIRST iteration — it only
	# does that when the target cell is already open. "reached -1" cannot distinguish "the digger failed"
	# from "the target was a hole in the ground before we started", and those want opposite fixes.
	var solid_at_start: bool = main.sim.is_solid(target)   # sampled BEFORE the dig, or it is always false
	var body_at_start: int = here.y
	var ok: bool = await agent.dig_down_to(target, 2400, true)
	var landed: Vector2i = main._cell_at(agent.player.position)
	var reached: int = landed.y - from_surface
	print("  delve: col %d, surface row %d, body started row %d, target %s (solid before the dig: %s),"
		% [here.x, from_surface, body_at_start, target, solid_at_start]
		+ " dig_down_to returned %s, body landed row %d" % [ok, landed.y])
	var c: Vector2i = main._cell_at(agent.player.position)
	var left: int = c.x - ROOM_W / 2
	for dy: int in range(-ROOM_H + 1, 1):
		for dx: int in range(ROOM_W):
			main.sim.mine(Vector2i(left + dx, c.y + dy))
		await physics_frame
	main._renderer.repaint_world()
	for _i: int in 30:
		await physics_frame
	return reached
