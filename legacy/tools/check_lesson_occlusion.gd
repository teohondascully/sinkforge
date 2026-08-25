extends "res://tools/check_base.gd"

## THE LESSON MUST NOT PRINT OVER THE THING IT IS TEACHING.
##
## `UI01-OCCLUSION` shipped as a rule at `5963bba` (the grapple lesson's keep-out list) and a measurement
## at `3b5d0dc`, both proven only inside `tools/capture_moments.gd -- teach`, a manual capture tool nothing
## runs automatically. Lesson PLACEMENT therefore had zero registered coverage: no row in
## `check_hud_layout` has ever armed the hint system, because `Hud._draw_hint_bubble` registers two probe
## rects (the shadow and the plate) that overlap each other by construction, so a naive row there would
## report the plate colliding with its own shadow. This is the standalone layer that gap asked for.
##
## NON-VACUITY. `covered == 0` is the passing value on every early exit this fixture can take — no pivot,
## no font, an empty lesson, a bubble still fading in — so it is asserted last, after four preconditions:
## a real pivot exists, the lesson has drawable text, the bubble is on screen above alpha 0.9, and — the
## load-bearing one — the SAME rect computed with an EMPTY keep-out list DOES cover the pivot. That last
## check is the CONTROL: it proves this fixture poses the occlusion question at all, so the real
## assertion's zero means the keep-out list worked rather than that nothing was measured. `Hud.pivot_cover`
## is called for both the live rect and the control, so the two cannot disagree over a second copy of the
## geometry — the same reason `hint_rect`/`pivot_cover` live on `Hud` and not here.
##
## The corner geometry and the catch/latch/calm sequence are a headless twin of `capture_moments.gd`'s
## `_bending_geometry`/`_teaching`: reused rather than re-invented, because that geometry is proven to
## reliably catch a pivot and a second, different corner would only be a second thing that could fail to.
## The lesson genuinely fires — `Hints.refresh` records `_done[&"wrapped"]` from the real swing, waited for
## below — and only WHICH queued lesson is on screen is arranged, the same distinction `_teaching` draws.
##
## MUTATION CONTROL: `SF_HINT_NO_AVOID=1` computes the live rect with the keep-out list emptied, the same
## way the built-in control already does, so the assertion is proven able to fail rather than merely able
## to pass:
##   SF_HINT_NO_AVOID=1 godot --headless --path . --script res://tools/check_lesson_occlusion.gd
##
##   godot --headless --path . --script res://tools/check_lesson_occlusion.gd

const SCENE: String = "res://scenes/main.tscn"
const CELL: int = FactorySim.CELL
const SETTLE: int = 30

## THE CORNER. `_bending_geometry`'s fixture, verbatim: an open chamber, a stone lintel over the hook, and
## a jutting shelf below it that the swing has to catch on.
const HOOK: Vector2 = Vector2(36.0 * 32.0 + 16.0, 26.0 * 32.0 + 16.0)
const BODY: Vector2 = Vector2(48.0 * 32.0 + 16.0, 29.0 * 32.0)

const CATCH_FRAMES: int = 420        ## swing frames given to acquire a pivot
const LATCH_FRAMES: int = 30         ## frames given for Hints.refresh to record the real "wrapped" fire
const READY_MAX: int = 600           ## frames given for the busy-gate to release
const CALM_FRAMES: int = 90          ## consecutive slow frames required before the gate releases


func _initialize() -> void:
	print("== the lesson must not print over the thing it is teaching ==")
	MainView.dev_start = false
	await _run()
	_verdict("check_lesson_occlusion", "the caught-line lesson clears its own pivot")


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var sim: FactorySim = main.sim
	var p: Player = main._player

	for x: int in range(30, 59):
		for y: int in range(20, 47):
			sim.mine(Vector2i(x, y))
	for y: int in range(24, 27):
		for x: int in range(34, 37):
			sim.set_solid(Vector2i(x, y), &"stone")
	for x: int in range(38, 45):
		sim.set_solid(Vector2i(x, 31), &"stone")

	p.auto_input = false
	p.place(BODY)
	for _i: int in 4:
		await physics_frame
	p.grapple.fire(p.hand(), HOOK)
	for _i: int in 40:
		await physics_frame
		if p.grapple.state == Grapple.State.ANCHORED:
			break
	if p.grapple.state != Grapple.State.ANCHORED:
		_check(false, "the hook never planted — nothing to test")
		main.queue_free()
		return

	for _i: int in CATCH_FRAMES:
		p.input_dir = -1.0
		await physics_frame
		if not p.grapple.pivots.is_empty():
			break
	p.input_dir = 0.0

	_check(not p.grapple.pivots.is_empty(), "the swing caught a pivot (%d)" % p.grapple.pivots.size())
	if p.grapple.pivots.is_empty():
		main.queue_free()
		return

	# THE LATCH. `Hints.refresh` writes `_done[&"wrapped"]` on a later `_process` than the physics step
	# that fills `grapple.pivots`, so the two are on different clocks — the race `_teaching`'s own comment
	# names. Waiting for it is what makes the lesson REAL rather than fabricated: the swing fired it.
	var hints: Hints = main._hints
	var latch: int = 0
	while latch < LATCH_FRAMES and (hints == null or not hints._done.has(&"wrapped")):
		await physics_frame
		latch += 1
	_check(hints != null and hints._done.has(&"wrapped"),
		"the caught-line lesson actually fired (Hints.refresh recorded it), not merely posed")
	if hints == null or not hints._done.has(&"wrapped"):
		main.queue_free()
		return

	# THE CALM WAIT. `Hints.active_alpha()`'s busy gate is hysteretic (arms at 1.25x run speed, releases
	# only below 0.9x) and the swing leaves the body well above it, so forcing `_active` alone would
	# measure a bubble the game is still declining to draw. `CALM_FRAMES` consecutive slow readings is the
	# difference between a body at rest and one merely passing under the threshold at an arc extreme, which
	# a pendulum does without ever settling on its own (grapple.gd:22 — a projection adds no energy, so
	# nothing here damps the swing either).
	hints._queue.clear()
	hints._active = &"wrapped"
	hints._life = Hints.SHOW_SECONDS - 1.0
	hints._lingered = 0.0
	var waited: int = 0
	var calm: int = 0
	while waited < READY_MAX:
		await physics_frame
		waited += 1
		if p.grapple.pivots.is_empty():
			break
		var slow: bool = p.velocity.length() < Player.RUN_SPEED * 0.9
		calm = (calm + 1) if (slow and not hints._ceremony) else 0
		if calm >= CALM_FRAMES:
			break
	for _i: int in 20:
		await physics_frame
	var hud: Hud = main._hud
	print("  ready after %d frame(s), %d calm, alpha=%.2f pivots=%d"
		% [waited, calm, hud.hint_alpha if hud != null else -1.0, p.grapple.pivots.size()])

	_check(not p.grapple.pivots.is_empty(), "the pivot is still caught at the shutter")
	_check(hud != null and hud._font != null and hud.hint_text != "",
		"the lesson has drawable text at the shutter (font=%s text='%s')"
			% ["ok" if hud != null and hud._font != null else "MISSING", hud.hint_text if hud != null else ""])
	_check(hud != null and hud.hint_alpha > 0.9,
		"the bubble is fully in, not fading (alpha=%.2f)" % (hud.hint_alpha if hud != null else -1.0))

	if hud == null or hud._font == null or hud.hint_text == "" or hud.hint_alpha <= 0.9 \
			or p.grapple.pivots.is_empty():
		_check(false, "a precondition above failed — the coverage measurement would be vacuous, skipped")
		main.queue_free()
		return

	var xf: Transform2D = main.get_viewport().get_canvas_transform()
	var none: Array[Vector2] = []
	var avoid: Array[Vector2] = none if OS.get_environment("SF_HINT_NO_AVOID") == "1" else hud.hint_avoid
	var bare: Rect2 = Hud.hint_rect(hud._font, hud.hint_text, hud.hint_anchor, none)
	var live_rect: Rect2 = Hud.hint_rect(hud._font, hud.hint_text, hud.hint_anchor, avoid)
	var ctl: Array = Hud.pivot_cover(bare, p.grapple.pivots, xf)
	var live: Array = Hud.pivot_cover(live_rect, p.grapple.pivots, xf)
	print("  bubble %s covers %d of %d pivot(s), deepest %.1f | CONTROL bare %s covers %d, deepest %.1f"
		% [str(live_rect), int(live[0]), p.grapple.pivots.size(), float(live[1]),
			str(bare), int(ctl[0]), float(ctl[1])])

	_check(int(ctl[0]) > 0,
		("CONTROL: with the keep-out list emptied, the bubble DOES cover the pivot (%d, deepest %.1f px) — "
			+ "this fixture poses the occlusion question, so the real assertion's zero is not vacuous")
			% [int(ctl[0]), float(ctl[1])])
	_check(int(live[0]) == 0,
		"UI01-OCCLUSION: the lesson clears every pivot it names (covered=%d of %d, live rect %s)"
			% [int(live[0]), p.grapple.pivots.size(), str(live_rect)])

	main.queue_free()
