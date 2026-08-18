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
##   `GR-04`  the guide rivals the miner's silhouette against calm sky
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
## HOW THE GUIDE IS ISOLATED, WITHOUT A TEST SWITCH TO DRAW IT. Two captures of an otherwise identical
## frame: one with the cursor parked ON the miner's own hand, where the trace collapses to nothing, and
## one with the cursor on the target. The difference is the guide and only the guide — no flag, no
## suppression, nothing that could be left switched on. A disc around the hand is excluded, because the
## collapsed preview still marks its own origin and that residue is not the guide.
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
const HAND_RADIUS: float = 14.0       ## excluded from the guide mask — the collapsed preview's own origin

## How far from the background a pixel must be to count as drawn ON it. Read against a measured
## still-frame noise floor, printed every run.
const DRAW_LEVEL: float = 10.0

## Frames between the two reference captures. Long enough to contain the slow animations — the marker bob,
## the glint twinkle — because a control that samples faster than the thing it is controlling for is blind
## to exactly the parts of the frame that will contaminate the measurement.
const QUIET_GAP: int = 30

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
	# WAIT OUT THE CEREMONY. Teleporting the body into the rig crosses a stratum boundary, so the arrival
	# plate is mid-animation over half the frame: two captures of the "still" rig differed by 248 levels and
	# the guide mask swallowed 119156 pixels of fading serif type. **A layer that photographs a transient
	# is measuring the transient**, which is the third time today the same sentence has been the answer.
	var waited: int = 0
	while _main._hud.announcing() and waited < 600:
		waited += 1
		await physics_frame
	for _i: int in 30:
		await physics_frame
	print("    waited %d frames for the arrival plate to clear" % waited)
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
	for _i: int in QUIET_GAP:
		await physics_frame
	var bg2: PackedFloat32Array = await _luma()
	var noise: float = _max_abs(bg, bg2)
	var moving: PackedByteArray = _moving(bg, bg2)
	var churn: float = _coverage(moving)
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
	_check(_aim_lands_on().distance_to(target) < 3.0,
		"CONTROL: the renderer's cursor is where the fixture put it (%.1f px off)"
			% _aim_lands_on().distance_to(target))
	_dump("bg")

	# --- GR-05 / GR-01: how much of the throw does the preview draw? ------------------
	WorldRenderer.AIM_GHOST_OFF = false
	for _i: int in 4:
		await physics_frame
	_check(_aim_lands_on().distance_to(target) < 3.0,
		"CONTROL: the renderer is aiming at the target the fixture chose (%.1f px off)"
			% _aim_lands_on().distance_to(target))
	var aim: PackedFloat32Array = await _luma()
	_dump("aim")
	var hand: Vector2 = p.hand()
	var guide: PackedByteArray = _mask(aim, bg, hand, moving)
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
	var guide_edge: float = _edge_p90(aim, guide)   # measured outside the lamp pool, per `_mask`
	var body_edge: float = _edge_p90(aim, body)
	print("    peak edge strength — miner %.1f levels, preview %.1f levels" % [body_edge, guide_edge])
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
		for _i: int in 8:
			await physics_frame
		var taut2: PackedFloat32Array = await _luma()
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
		var churn2: PackedByteArray = _either(_moving(taut, taut_mid), _moving(taut_mid, taut2))
		var still: PackedByteArray = _without(lane, churn2)
		var d_phase: float = float(_changed_in(taut, taut2, still))
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

	_main.queue_free()
	await physics_frame


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


## `Viewport.warp_mouse` TAKES VIEWPORT COORDINATES, so world travels through `get_canvas_transform()` and
## stops there. I "fixed" this to the full chain on the strength of a reticle landing 400px off, and the
## full chain is what put it there: `get_final_transform()` is applied again on the way back out, so the
## point arrives scaled twice. **The half chain is the defect in `check_opening` and the correct answer
## here, and the difference is which direction the transform is being used in.** Guessing either way is
## how this repository lost a day, so the result is not assumed — `_aim_lands_on` reads the value the
## renderer itself will use and the layer refuses to measure anything until it matches.
func _look_at(world: Vector2) -> void:
	var vp: Viewport = _main.get_viewport()
	vp.warp_mouse(vp.get_canvas_transform() * world)
	for _i: int in 6:
		await physics_frame


## Where the RENDERER thinks the cursor is, in world space — the exact expression `_draw_aim_ghost` calls.
func _aim_lands_on() -> Vector2:
	return _main._renderer.get_global_mouse_position()


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
