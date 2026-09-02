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
##   * ~~**The camera limits.**~~ **PORTED 2026-09-01 (D0333), and the reason for deferring them did not
##     survive checking.** This paragraph said clamping "would silently break the milestone captures"
##     that `--wide-view` and `--camera=col,row` exist to produce. It would not: both debug paths bypass
##     the rig entirely — `reveal_scene._update_camera` returns before calling it under `--wide-view`,
##     and assigns `_fixed_camera` directly under `--camera=`. Nothing that frames outside the world
##     goes through `step()`, so a clamp inside it cannot reach them.
##
##     What made the omission visible was a capture at the ported wide framing: the body spawns near the
##     world's left edge, the camera followed it past that edge, and **a third of the frame was flat
##     grey void**. At the 12-metre framing this build shipped with, the camera never got far enough
##     from the middle for it to show.

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

## HOW MUCH WORLD IS ON SCREEN — ported from `legacy/scenes/main.gd:28-37`, and the one legacy constant
## that could NOT be copied across unchanged. `docs/DECISIONS_LEDGER.md` D0325.
##
## **THE BUILD WAS PLAYING AT 13.3 METRES ACROSS. LEGACY'S MOST ZOOMED-*IN* LEVEL WAS 40.** Three times
## tighter than legacy ever got, nine times tighter than its widest — the miner filled the frame and the
## world barely appeared. The director's read of a live screenshot was "it kind of looks terrible", and
## the cause was one number nobody had ported.
##
## LEGACY'S OWN RATIONALE, which is why these four values and not a taste call:
##
##   > "Index 0 is 1.00x, which shows a 40x22-cell field: still a wide side-view field, comfortably wider
##   > than Terraria's in tile terms, while keeping the miner large enough to read as a character and a
##   > 32px cell large enough to show its rock texture rather than blooming into a smear. At 0.70x the
##   > field is 57x32 cells and the avatar is well under one percent of the frame's width, which is below
##   > the size at which any amount of rim light, head-lamp or guide ring can make him findable."
##
## So index 0 is the PLAY default and the wider steps are for surveying — legacy states that its own
## second rung already loses the avatar, which settles what the default should be without a taste call.
##
## **THE CONVERSION, AND WHY IT IS NOT ×1 OR ×4.** This is a WG-4 regime question (D0305) and getting it
## wrong is D0310's trap in the other direction. What is conserved is METRES ON SCREEN, not pixels:
##
##     metres_across = VIEWPORT_WIDTH / zoom / pixels_per_metre
##     legacy:  1280 / z / 32  =  40 / z          (CELL 32px, and legacy's cell WAS one metre)
##     here:    1280 / z / 16  =  80 / z          (4px terrain cell x TERRAIN_CELLS_PER_METER 4)
##
## Equal metres therefore needs `z_here = 2 * z_legacy`, and legacy's own "40x22-cell field" at index 0
## is the check: `metres_across(2.0)` must come back 40. Both viewports are 1280 wide, so the viewport
## cancels — but it is written out rather than cancelled by hand, because the two builds agreeing on
## 1280 is a coincidence of this moment and not a property either file guarantees.
const ZOOM_LEVELS: Array[float] = [2.00, 1.40, 1.00, 0.66]   ## legacy's [1.00, 0.70, 0.50, 0.33] x 2

## Index 0, by legacy's own argument above: its NEXT rung out already puts the avatar under one percent
## of the frame width, which legacy calls below findable. Wider rungs are for surveying, not for playing.
const DEFAULT_ZOOM_IDX: int = 0

## World pixels per metre in THIS build. Derived from the terrain grid rather than written as 16, so a
## change to either factor moves the framing with it instead of silently desynchronising from it.
##
## BOTH FACTORS ARRIVE THROUGH A VIEW-LEGAL ROUTE, and neither may be read from `sim/` directly.
## `Interface.TERRAIN_CELL_PX` is L2's own re-export of `Heightfield.TERRAIN_CELL_PX`, and
## `MaterialLook.CELLS_PER_METRE` is the copy of `ShaftGenerator.TERRAIN_CELLS_PER_METER` that
## `tests/test_material_palette.gd` already asserts equal to its `sim/` original. Naming either `sim/`
## class here is a `tools/layer_lint/layer_lint.py` failure, and the first draft of this file did
## exactly that.
const PIXELS_PER_METRE: int = Interface.TERRAIN_CELL_PX * MaterialLook.CELLS_PER_METRE

## Metres of world visible across a viewport of `viewport_width` at `zoom`. The quantity legacy's design
## comment is actually written in, so it is the quantity the test asserts.
static func metres_across(zoom: float, viewport_width: float = 1280.0) -> float:
	if zoom <= 0.0:
		return INF   ## same degenerate-zoom contract as `cut_distance` and `snap_to_pixel` above
	return viewport_width / zoom / float(PIXELS_PER_METRE)


## The world rect the camera may not show past, in world px. Empty means unlimited, which is the
## behaviour every caller had before D0333 and is what a test posing a rig in isolation still gets.
var _limits: Rect2 = Rect2()

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
	return snap_to_pixel(clamp_to_limits(_pos, zoom, screen_width), zoom)


## Sets the world rect the view may not leave. Call once with the world's pixel bounds; pass an empty
## `Rect2` to remove the limit.
func set_world_limits(world_px: Rect2) -> void:
	_limits = world_px


## Clamps a camera centre so the visible rect stays inside the world. D0333.
##
## **CLAMPS THE RENDERED POSITION, NOT THE EASED ONE**, and that ordering is the same reason
## `snap_to_pixel` is applied on the way out: the rig's internal `_pos` keeps converging on the body at
## full precision, so walking along a wall does not push the eased position into the limit and then make
## it crawl back out when the body turns around. The clamp is a view constraint, not a follow constraint.
##
## A WORLD NARROWER THAN THE VIEW IS CENTRED, not clamped to one edge. `min > max` on an axis means the
## world does not fill the frame there, and clamping between crossed bounds would pin the camera to
## whichever edge the expression happened to evaluate last — the world would sit against the left of the
## screen rather than in the middle of it.
func clamp_to_limits(pos: Vector2, zoom: float, screen_width: float) -> Vector2:
	if _limits.size.x <= 0.0 or _limits.size.y <= 0.0 or zoom <= 0.0:
		return pos
	# The visible half-extent in WORLD px. Height is derived from the width by the viewport's own aspect,
	# which this rig is not given -- so it uses the 16:9 the project renders at. A wrong aspect only ever
	# makes the vertical clamp slightly loose or tight, never inverted.
	var half_w: float = screen_width / zoom * 0.5
	var half_h: float = half_w * 9.0 / 16.0
	var out: Vector2 = pos
	var min_x: float = _limits.position.x + half_w
	var max_x: float = _limits.end.x - half_w
	out.x = (_limits.position.x + _limits.size.x * 0.5) if min_x > max_x else clampf(pos.x, min_x, max_x)
	var min_y: float = _limits.position.y + half_h
	var max_y: float = _limits.end.y - half_h
	out.y = (_limits.position.y + _limits.size.y * 0.5) if min_y > max_y else clampf(pos.y, min_y, max_y)
	return out


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
