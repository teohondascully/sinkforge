class_name CameraRig
extends RefCounted

## SOFT FOLLOW, LOOK-AHEAD, AND PIXEL-SNAP. Ported from `legacy/scenes/main.gd:310-333` (rig setup),
## `683-706` (the per-frame follow) and `2355-2358` (`snap_to_pixel`). `docs/LEGACY_GAP.md` T1 #11 calls
## this "the single largest concentrated feel gap outside the resolver", and the build it describes is
## the one that was here: `reveal_scene._update_camera` assigned the body's position to the camera every
## tick — no smoothing, no lead, no snap, no limits.
##
## **SMOOTH THE FOLLOW, SNAP THE RENDER, and they are not the same step.** Godot's built-in
## `position_smoothing` renders the camera at a FRACTIONAL position, so every terrain texel samples
## between screen pixels each frame and the world shimmers whenever anything moves. Legacy's fix, ported
## here: smooth toward the body in continuous world space, then round the RESULT to a whole screen pixel.
## The eased position is kept internally at full precision — rounding it in place would compound the
## rounding error into the easing and the follow would ratchet.
##
## **THE LOOK-AHEAD IS THE HALF THAT IS ABOUT FEEL RATHER THAN CRISPNESS.** The camera leads along the
## body's own velocity, so at speed you see where you are going rather than where you have been. Legacy's
## own note: without it "a swing or a long fall spends its most interesting half off-screen and the
## player brakes to see." The lead is capped in world px, eased so a direction change does not lurch, and
## goes to zero at a standstill.
##
## **WHAT IS DELIBERATELY NOT PORTED.**
##
##   * **The stride multiplier.** Legacy's lead time is `CAMERA_LEAD_TIME * (1 + STRIDE_LEAD * stride)`,
##     leading further once the miner is running — "a camera that holds the body dead centre at full
##     stride cancels the stride: the ground scrolls faster and the frame looks identical." **This build
##     has no stride** (`docs/LEGACY_GAP.md` T1 #10, one flat top speed). `stride` would be a constant 0,
##     so the term is identically 1.0 and is omitted rather than written as a factor that can never move.
##     `STRIDE_LEAD` is recorded in the gap doc, not smuggled in here as dead arithmetic.
##   * **Screen shake.** Legacy decays `_shake` and offsets the camera by `randf_range` of it. It comes
##     back with its TRIGGER — `docs/LEGACY_GAP.md` T1 #9's landing telemetry — because a shake with
##     nothing to set it is `view/visuals/art.gd` again: lifted, correct, and referenced by nothing for
##     four sessions. It also needs a deterministic source rather than `randf_range`, since a renderer
##     whose output moves between runs cannot be screenshot-compared.
##   * **The camera limits.** Legacy clamps to the world rect. This build's `--wide-view` and
##     `--camera=col,row` debug modes deliberately frame outside the body's world, and clamping would
##     silently break the milestone captures those flags exist to produce.

## Legacy's own constants, unchanged. Each is a feel judgement made against a playable build, which is
## exactly the kind of number `docs/MASTER_PLAN_AUG30.md` §0 says to port rather than re-derive.
const LEAD_TIME: float = 0.34        ## seconds of travel the camera leads by
const LEAD_MAX: float = 170.0        ## px cap, so a terminal-velocity fall cannot shove the body off-frame
const LEAD_VERTICAL: float = 0.55    ## vertical space is scarcer on a 16:9 frame; lead into it gently
const LEAD_EASE: float = 5.0         ## per-second easing on the lead itself (a lurch reads as a bug)
const FOLLOW_SPEED: float = 8.0      ## soft follow, matching legacy's old position_smoothing_speed

## Past this fraction of a screen width from the target, the camera CUTS instead of panning. A spawn, a
## teleport or a load would otherwise sweep the camera across the whole world at follow speed, showing a
## long smear of terrain nobody asked for; and the frame is centred the instant anything repositions the
## body, which is what makes a cut read as a cut rather than as a bug.
const SNAP_SCREENS: float = 0.5

var _pos: Vector2 = Vector2.ZERO      ## the eased position, kept at FULL precision -- see the header
var _lead: Vector2 = Vector2.ZERO
var _started: bool = false


## Places the camera exactly, with no easing, and clears the accumulated lead. For a spawn, a debug
## `--camera=` pin, or any reposition that must not pan.
##
## Also what the FIRST `step()` does implicitly: an un-started rig eases from (0,0), which on a world
## whose spawn is thousands of pixels away means the opening frames pan in from the corner. That is a
## real defect and it is invisible in a still capture, which is why it is handled here rather than left
## to the caller to remember.
func warp_to(world_pos: Vector2) -> void:
	_pos = world_pos
	_lead = Vector2.ZERO
	_started = true


## One frame of follow. Returns the position to ASSIGN to the camera -- already pixel-snapped -- while
## the rig keeps its own un-snapped position internally.
##
## `body_vel` is in world px/s (the caller converts out of `Fx`), `zoom` is the camera's own scale, and
## `screen_width` is the viewport width in screen px, used only for the cut threshold.
##
## Pure in the sense that matters for testing: no node, no scene, no engine singleton. The whole rig is
## assertable by calling this in a loop, which is why the easing lives here and not in a `_process`.
func step(body_pos: Vector2, body_vel: Vector2, zoom: float, screen_width: float, delta: float) -> Vector2:
	if not _started:
		warp_to(body_pos)
	var lead: Vector2 = body_vel * LEAD_TIME
	lead.y *= LEAD_VERTICAL
	# Eased with `1 - exp(-k*dt)` rather than a raw `lerp(a, b, k*dt)`: the exponential form is
	# frame-rate independent, so a dropped frame does not make the camera lag differently than a smooth
	# one. Legacy used it for both the lead and the follow and the reason is the same in each.
	_lead = _lead.lerp(lead.limit_length(LEAD_MAX), 1.0 - exp(-LEAD_EASE * delta))
	var target: Vector2 = body_pos + _lead
	if _pos.distance_to(target) > cut_distance(zoom, screen_width):
		_pos = target
	else:
		_pos = _pos.lerp(target, 1.0 - exp(-FOLLOW_SPEED * delta))
	return snap_to_pixel(_pos, zoom)


## The distance past which `step` cuts rather than pans, in WORLD px. Separate and public because it is
## the one threshold in this file that depends on the viewport, and a test that hardcoded it would stop
## measuring the rig the moment the window changed.
static func cut_distance(zoom: float, screen_width: float) -> float:
	if zoom <= 0.0:
		return INF   ## a degenerate zoom must never CUT -- see snap_to_pixel's own guard
	return screen_width / zoom * SNAP_SCREENS


## Legacy `main.gd:2355`, verbatim including its guard. Rounds a world position to a whole SCREEN pixel:
## multiply into screen space, round, divide back. The `zoom <= 0` guard returns the input unchanged
## because dividing by it would produce `inf`/`nan` coordinates, and a camera at `nan` renders nothing at
## all while reporting no error.
static func snap_to_pixel(world_pos: Vector2, zoom: float) -> Vector2:
	if zoom <= 0.0:
		return world_pos
	return (world_pos * zoom).round() / zoom


## The un-snapped eased position, for tests and for anything that needs to reason about where the camera
## is converging rather than where it is being drawn.
func position_unsnapped() -> Vector2:
	return _pos


func lead_offset() -> Vector2:
	return _lead
