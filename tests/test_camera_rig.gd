extends "res://tests/test_base.gd"

## `view/camera_rig.gd` — the ported soft follow, look-ahead and pixel-snap (D0273, LEGACY_GAP T1 #11).
##
## The rig is a plain `RefCounted` with no node and no `_process`, so every one of these drives it by
## calling `step()` in a loop. That is the point of where the easing lives: a camera whose smoothing sat
## in a `_process` could only be tested by running a scene and looking at it.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_camera_rig.gd

const DT: float = 1.0 / 60.0
const ZOOM: float = 4.0
const SCREEN_W: float = 1920.0


func _initialize() -> void:
	_test_the_first_step_warps_rather_than_panning_in_from_the_origin()
	_test_a_still_body_is_followed_exactly_with_no_lead()
	_test_the_follow_is_soft_and_converges_rather_than_teleporting()
	_test_the_camera_leads_the_direction_of_travel()
	_test_the_lead_is_capped_and_eases_instead_of_lurching()
	_test_a_big_reposition_cuts_instead_of_panning_across_the_world()
	_test_the_rendered_position_lands_on_whole_screen_pixels()
	_test_the_framing_shows_legacys_own_field_of_view()
	_test_the_default_zoom_never_frames_void()
	_test_the_camera_never_shows_past_the_world()
	_finish("camera_rig")


## A fresh rig eases from (0,0) unless the first step warps. On a world whose spawn is thousands of px
## from the origin that means the opening frames pan in from the corner -- a defect invisible in a still
## capture, which is why it is asserted rather than left to a caller to remember.
func _test_the_first_step_warps_rather_than_panning_in_from_the_origin() -> void:
	var rig := CameraRig.new()
	var spawn := Vector2(4000.0, 9000.0)
	var got: Vector2 = rig.step(spawn, Vector2.ZERO, ZOOM, SCREEN_W, DT)
	_check(got.distance_to(spawn) < 1.0,
		"the first step lands ON the body, not partway from the origin (%s vs %s)" % [got, spawn])


## No velocity means no lead, and the camera settles exactly on the body. Asserted after enough steps to
## converge, because one step of an exponential ease is never exact -- and asserting after a single step
## would have measured the ease rate rather than the resting position.
func _test_a_still_body_is_followed_exactly_with_no_lead() -> void:
	var rig := CameraRig.new()
	var at := Vector2(100.0, 200.0)
	for _i: int in 120:
		rig.step(at, Vector2.ZERO, ZOOM, SCREEN_W, DT)
	_check(rig.lead_offset().length() < 0.01,
		"a standstill produces no lead (%s)" % rig.lead_offset())
	_check(rig.position_unsnapped().distance_to(at) < 0.01,
		"and the camera rests on the body (%s vs %s)" % [rig.position_unsnapped(), at])


## THE ASSERTION THAT SEPARATES A SOFT FOLLOW FROM AN ASSIGNMENT, which is what this build had. A hard
## assign is on target after ONE step; a soft follow is behind after one and converging after many. Both
## halves are needed: "eventually correct" alone passes on the assignment this replaces.
func _test_the_follow_is_soft_and_converges_rather_than_teleporting() -> void:
	var rig := CameraRig.new()
	var start := Vector2(0.0, 0.0)
	rig.warp_to(start)
	var moved := Vector2(60.0, 0.0)   ## well inside the cut threshold, so this exercises the PAN path
	rig.step(moved, Vector2.ZERO, ZOOM, SCREEN_W, DT)
	var after_one: float = rig.position_unsnapped().distance_to(moved)
	_check(after_one > 1.0,
		"after ONE step the camera is still behind the body -- a hard assign would be at 0 (%.2f)" % after_one)
	for _i: int in 200:
		rig.step(moved, Vector2.ZERO, ZOOM, SCREEN_W, DT)
	_check(rig.position_unsnapped().distance_to(moved) < 0.01,
		"and it converges (%.4f)" % rig.position_unsnapped().distance_to(moved))


## Direction, not magnitude: the lead must point the way the body is going. Checked on both axes and in
## both signs, because a sign error on one axis is exactly the kind of defect that looks fine in a
## screenshot of a body walking right.
func _test_the_camera_leads_the_direction_of_travel() -> void:
	var cases: Array = [
		{"vel": Vector2(200.0, 0.0), "want_x": 1, "want_y": 0},
		{"vel": Vector2(-200.0, 0.0), "want_x": -1, "want_y": 0},
		{"vel": Vector2(0.0, 300.0), "want_x": 0, "want_y": 1},
		{"vel": Vector2(0.0, -300.0), "want_x": 0, "want_y": -1},
	]
	for c: Dictionary in cases:
		var rig := CameraRig.new()
		rig.warp_to(Vector2.ZERO)
		for _i: int in 60:
			rig.step(Vector2.ZERO, c["vel"], ZOOM, SCREEN_W, DT)
		var lead: Vector2 = rig.lead_offset()
		_check(signf(lead.x) == float(c["want_x"]) or (c["want_x"] == 0 and absf(lead.x) < 0.01),
			"velocity %s leads x in sign %d (got %.2f)" % [c["vel"], c["want_x"], lead.x])
		_check(signf(lead.y) == float(c["want_y"]) or (c["want_y"] == 0 and absf(lead.y) < 0.01),
			"velocity %s leads y in sign %d (got %.2f)" % [c["vel"], c["want_y"], lead.y])
	# Vertical space is scarcer on a 16:9 frame, so the same speed must lead LESS vertically. Compared as
	# a pair rather than against a literal -- the literal is the constant under test.
	var h := CameraRig.new(); h.warp_to(Vector2.ZERO)
	var v := CameraRig.new(); v.warp_to(Vector2.ZERO)
	for _i: int in 60:
		h.step(Vector2.ZERO, Vector2(150.0, 0.0), ZOOM, SCREEN_W, DT)
		v.step(Vector2.ZERO, Vector2(0.0, 150.0), ZOOM, SCREEN_W, DT)
	_check(absf(v.lead_offset().y) < absf(h.lead_offset().x),
		"the same speed leads less vertically than horizontally (%.2f vs %.2f)"
		% [absf(v.lead_offset().y), absf(h.lead_offset().x)])


## The cap stops a terminal-velocity fall shoving the body off-frame; the ease stops a direction change
## lurching. The ease is asserted as "not there yet after one step" against a lead that IS reached later,
## so a rig that simply ignored its input would fail the second half.
func _test_the_lead_is_capped_and_eases_instead_of_lurching() -> void:
	var rig := CameraRig.new()
	rig.warp_to(Vector2.ZERO)
	var absurd := Vector2(0.0, 100000.0)
	for _i: int in 600:
		rig.step(Vector2.ZERO, absurd, ZOOM, SCREEN_W, DT)
	_check(rig.lead_offset().length() <= CameraRig.LEAD_MAX + 0.01,
		"a terminal-velocity fall's lead is capped at %.0f px (got %.2f)"
		% [CameraRig.LEAD_MAX, rig.lead_offset().length()])
	var eased := CameraRig.new()
	eased.warp_to(Vector2.ZERO)
	var v := Vector2(400.0, 0.0)
	eased.step(Vector2.ZERO, v, ZOOM, SCREEN_W, DT)
	var one_step: float = eased.lead_offset().length()
	for _i: int in 300:
		eased.step(Vector2.ZERO, v, ZOOM, SCREEN_W, DT)
	var settled: float = eased.lead_offset().length()
	_check(settled > 0.01, "sanity: the lead does settle somewhere non-zero (%.2f)" % settled)
	_check(one_step < settled * 0.5,
		"one step reaches well under half the settled lead -- it eases rather than lurching (%.2f of %.2f)"
		% [one_step, settled])


## Past half a screen width the camera CUTS. Asserted against `cut_distance()` rather than a literal, and
## with a control just INSIDE the threshold that must still pan -- without which a rig that cut every
## frame (i.e. the plain assignment this replaces) would pass.
func _test_a_big_reposition_cuts_instead_of_panning_across_the_world() -> void:
	var threshold: float = CameraRig.cut_distance(ZOOM, SCREEN_W)
	_check(threshold > 1.0, "sanity: the cut threshold is a real distance (%.1f px)" % threshold)
	var far_rig := CameraRig.new()
	far_rig.warp_to(Vector2.ZERO)
	var far := Vector2(threshold * 2.0, 0.0)
	far_rig.step(far, Vector2.ZERO, ZOOM, SCREEN_W, DT)
	_check(far_rig.position_unsnapped().distance_to(far) < 0.01,
		"a jump past the threshold CUTS to the target in one step (%.3f off)"
		% far_rig.position_unsnapped().distance_to(far))
	var near_rig := CameraRig.new()
	near_rig.warp_to(Vector2.ZERO)
	var near := Vector2(threshold * 0.5, 0.0)
	near_rig.step(near, Vector2.ZERO, ZOOM, SCREEN_W, DT)
	_check(near_rig.position_unsnapped().distance_to(near) > 1.0,
		"CONTROL: a jump INSIDE the threshold still pans (%.3f off) -- a rig that always cut would pass "
		% near_rig.position_unsnapped().distance_to(near) + "the assertion above on its own")


## The whole point of snapping the render rather than the state: the returned position must land on a
## whole screen pixel while the internal position stays continuous. Both halves asserted -- a rig that
## rounded its own state would satisfy the first and ratchet its easing.
func _test_the_rendered_position_lands_on_whole_screen_pixels() -> void:
	var rig := CameraRig.new()
	rig.warp_to(Vector2.ZERO)
	var off_grid := false
	var fractional_state := false
	for i: int in 90:
		var target := Vector2(float(i) * 0.37, float(i) * 0.21)
		var drawn: Vector2 = rig.step(target, Vector2(30.0, 20.0), ZOOM, SCREEN_W, DT)
		var screen: Vector2 = drawn * ZOOM
		if absf(screen.x - roundf(screen.x)) > 0.001 or absf(screen.y - roundf(screen.y)) > 0.001:
			off_grid = true
		var raw: Vector2 = rig.position_unsnapped() * ZOOM
		if absf(raw.x - roundf(raw.x)) > 0.001:
			fractional_state = true
	_check_over(90, not off_grid, "every rendered position lands on a whole screen pixel at zoom %.1f" % ZOOM)
	_check(fractional_state,
		"but the INTERNAL position stays continuous -- if this is false the rig is rounding its own state "
		+ "and the easing will ratchet")
	# The degenerate guard: a zero or negative zoom must return the input rather than inf/nan. A camera at
	# nan renders nothing at all and reports no error, which is the quietest possible failure.
	var p := Vector2(1.5, -2.25)
	_check(CameraRig.snap_to_pixel(p, 0.0) == p, "zoom 0 returns the position unchanged (%s)" % CameraRig.snap_to_pixel(p, 0.0))
	_check(CameraRig.snap_to_pixel(p, -1.0) == p, "a negative zoom does too (%s)" % CameraRig.snap_to_pixel(p, -1.0))
	_check(CameraRig.cut_distance(0.0, SCREEN_W) == INF, "and a degenerate zoom never cuts")


## D0325 -- THE NUMBER NOBODY PORTED. The build shipped at zoom 6.0, showing 13.3 metres of world, while
## legacy's most zoomed-IN rung showed 40. Three times tighter than legacy ever got.
##
## ASSERTED IN METRES, because metres is the unit legacy's design comment is written in: "a 40x22-cell
## field", and legacy's cell WAS one metre. Asserting the zoom NUMBER instead would be asserting a value
## in a regime it does not belong to -- the same class of error as D0310's constants, and the reason
## `metres_across` exists at all. If either the terrain cell size or `TERRAIN_CELLS_PER_METER` moves, the
## right zoom moves with it and this test says so rather than passing on a stale literal.
func _test_the_framing_shows_legacys_own_field_of_view() -> void:
	# Legacy `main.gd:31`: index 0 "shows a 40x22-cell field". Its cell is one metre.
	var wide: float = CameraRig.metres_across(CameraRig.ZOOM_LEVELS[CameraRig.DEFAULT_ZOOM_IDX])
	_check(absf(wide - 40.0) < 0.5,
		"the play default frames legacy's own 40-cell field: %.1f metres across (legacy 40.0)" % wide)
	# ...and legacy's SECOND rung is its 57-cell field. Two rungs, so the ladder is a conversion of
	# legacy's and not one value that happens to land right.
	var next_out: float = CameraRig.metres_across(CameraRig.ZOOM_LEVELS[1])
	_check(absf(next_out - 57.0) < 1.0,
		"and the next rung out is legacy's 57-cell field: %.1f metres (legacy 57.0)" % next_out)
	# The ladder only goes OUTWARD. Smaller zoom is further out, so the metres must increase.
	var previous: float = 0.0
	for z: float in CameraRig.ZOOM_LEVELS:
		var m: float = CameraRig.metres_across(z)
		_check(m > previous, "rung at zoom %.2f shows %.1f m, wider than the %.1f m before it"
			% [z, m, previous])
		previous = m
	# CONTROL: the old value must FAIL the claim above. Without this the assertion could be satisfied by
	# a `metres_across` that returned 40.0 for anything, and the whole point is that 6.0 did not.
	_check(absf(CameraRig.metres_across(6.0) - 40.0) > 10.0,
		"CONTROL: the shipped-until-now zoom 6.0 shows %.1f metres, nothing like legacy's 40 -- so the "
		% CameraRig.metres_across(6.0) + "row above is a real comparison and not true of every input")
	# And the pixels-per-metre it all rests on is DERIVED, not written down.
	_check(CameraRig.PIXELS_PER_METRE == Heightfield.TERRAIN_CELL_PX * ShaftGenerator.TERRAIN_CELLS_PER_METER,
		"pixels-per-metre (%d) is the terrain grid's own product, not a literal" % CameraRig.PIXELS_PER_METRE)


## D0335 -- THE FRAMING COULD NOT BE FIXED BY A FRAMING CHANGE. D0325 ported legacy's zoom ladder, whose
## play rung frames 40 metres; the world was 48 terrain cells, which is 12. So the shipped default of 6.0
## ALREADY framed wider than the world existed, and the capture showed void bands at both screen edges.
## Widening the world (`docs/NEEDS_DIRECTOR.md` P031) is what made the ported rung reachable.
##
## `default_zoom_for` therefore DERIVES the default rather than writing it down: legacy's rung unless the
## world is too narrow for it, in which case zoom in far enough to fill the frame. **A larger zoom shows
## FEWER metres, so it is a `max`** -- and reading it as a `min` frames void, which is the whole defect.
## That inversion is what the control below poses, because the two differ on exactly one input class.
func _test_the_default_zoom_never_frames_void() -> void:
	# The invariant, over every width from a sliver to far wider than the ladder: the visible world px may
	# never exceed the world px that EXIST. Stated as the defect's own negation, not as a value.
	for world_px: float in [64.0, 192.0, 512.0, 1024.0, 4096.0, 16384.0]:
		var z: float = CameraRig.default_zoom_for(world_px, SCREEN_W)
		_check(SCREEN_W / z <= world_px + 0.5,
			"a %.0f-px world frames %.0f px at the derived zoom %.2f -- no void" % [world_px, SCREEN_W / z, z])
	# The ruled play width (256 terrain cells) is wide enough for legacy's own rung, so it must get it
	# EXACTLY -- a derivation that quietly zoomed past the ported ladder would defeat D0325.
	var play_px: float = 256.0 * float(Heightfield.TERRAIN_CELL_PX)
	_check(is_equal_approx(CameraRig.default_zoom_for(play_px, SCREEN_W),
		CameraRig.ZOOM_LEVELS[CameraRig.DEFAULT_ZOOM_IDX]),
		"the ruled 256-cell world gets legacy's rung unchanged (%.2f)"
		% CameraRig.default_zoom_for(play_px, SCREEN_W))
	# CONTROL, and it is the mutation that matters: for the 48-cell TEST sites the ported rung alone is
	# WRONG. Without this row the assertion above would be satisfied by a function that returned
	# ZOOM_LEVELS[0] for every input -- which is precisely the build that shipped void bands.
	var narrow_px: float = 48.0 * float(Heightfield.TERRAIN_CELL_PX)
	_check(SCREEN_W / CameraRig.ZOOM_LEVELS[CameraRig.DEFAULT_ZOOM_IDX] > narrow_px,
		"CONTROL: legacy's rung alone would frame %.0f px of a %.0f-px world -- void, so the max above "
		% [SCREEN_W / CameraRig.ZOOM_LEVELS[CameraRig.DEFAULT_ZOOM_IDX], narrow_px]
		+ "is load-bearing and not true of every input")
	# A degenerate width must not divide by zero into an infinite zoom; it falls back to the ladder.
	_check(CameraRig.default_zoom_for(0.0, SCREEN_W) == CameraRig.ZOOM_LEVELS[CameraRig.DEFAULT_ZOOM_IDX],
		"a zero-width world falls back to the ladder rather than dividing by it")


## THE VOID AT THE EDGE OF THE WORLD (D0333). A capture at the ported wide framing showed a third of the
## frame as flat grey: the body spawns near the world's left edge, and the camera followed it straight
## past that edge. At the 12-metre framing this build shipped with, the camera never got far enough from
## the middle for it to show — which is why the omission survived until the framing was fixed.
func _test_the_camera_never_shows_past_the_world() -> void:
	var world := Rect2(0.0, 0.0, 2048.0, 4096.0)
	var rig := CameraRig.new()
	rig.set_world_limits(world)
	var half: float = SCREEN_W / ZOOM * 0.5
	# Drive the body hard into each edge and check the VIEW stays inside, not the camera position.
	var corners: Array[Vector2] = [
		Vector2(-500.0, 2000.0), Vector2(4000.0, 2000.0),
		Vector2(1000.0, -500.0), Vector2(1000.0, 9000.0),
	]
	var checked: int = 0
	var inside: int = 0
	for target: Vector2 in corners:
		var r := CameraRig.new()
		r.set_world_limits(world)
		r.warp_to(target)
		var got: Vector2 = r.step(target, Vector2.ZERO, ZOOM, SCREEN_W, DT)
		checked += 1
		if got.x - half >= world.position.x - 0.5 and got.x + half <= world.end.x + 0.5:
			inside += 1
		else:
			_check(false, "camera at %s shows x [%.1f, %.1f], outside the world's [0, %.1f]"
				% [target, got.x - half, got.x + half, world.end.x])
	_check_over(checked, inside == checked,
		"the view stays inside the world at all %d edges -- %d did" % [checked, inside])
	# CONTROL: with NO limits set the same drive DOES leave the world, so the rows above report the clamp
	# and not a rig that never travels far. Without this they pass on a `step` that ignores its argument.
	var free_rig := CameraRig.new()
	free_rig.warp_to(Vector2(-500.0, 2000.0))
	var loose: Vector2 = free_rig.step(Vector2(-500.0, 2000.0), Vector2.ZERO, ZOOM, SCREEN_W, DT)
	_check(loose.x - half < world.position.x,
		"CONTROL: an unlimited rig shows x from %.1f, outside the world -- so the clamp is doing the work"
			% (loose.x - half))
	# A WORLD NARROWER THAN THE VIEW IS CENTRED, not pinned to an edge: clamping between crossed bounds
	# would put the world against one side of the screen rather than in the middle of it.
	var narrow := Rect2(0.0, 0.0, 100.0, 4096.0)
	var n := CameraRig.new()
	n.set_world_limits(narrow)
	n.warp_to(Vector2(5000.0, 2000.0))
	var centred: Vector2 = n.step(Vector2(5000.0, 2000.0), Vector2.ZERO, ZOOM, SCREEN_W, DT)
	_check(absf(centred.x - 50.0) < 1.0,
		"a world narrower than the view is CENTRED at %.1f, not pinned to an edge" % centred.x)
