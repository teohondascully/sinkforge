class_name RevealPan
extends RefCounted

## `--pan=c0,r0:c1,r1` -- the moving-camera strip queue item 49's fourth condition asks to be judged
## on. Owns the sweep's state and cadence so `reveal_scene.gd` keeps only two calls: `camera_position()`
## inside the camera step and `step()` after the world advances. Extracted under the same pressure
## `reveal_args.gd` records (D0244): the scene was at 441 lines against a 400 cap, and a sweep's state
## is not scene work.
##
## The camera position goes through `CameraRig.step`, not around it: a direct `position` lerp would
## test the painters but not the follow/snap/lead the condition is about. The sweep's segment is a
## synthetic body target; the rig smooths, snaps and clamps it exactly as it does the real one's --
## which is also how the strip MEASURED that a 12-metre test site clamps a horizontal sweep entirely
## (the world is narrower than the frame at play zoom), leaving the vertical axis to do the work.

const TICKS_PER_SHOT: int = 30  ## the sweep's pace: one capture per this many ticks

var from_pos: Vector2 = Vector2.ZERO
var to_pos: Vector2 = Vector2.ZERO
var shots: int = 8
var prefix: String = ""
var _shot: int = 0


## Builds the sweep from a parsed `RevealArgs` config, or returns null when no `--pan=` engaged --
## null is the scene's "no sweep" state, so an unengaged run allocates nothing.
static func build(cfg: Dictionary) -> RevealPan:
	if not bool(cfg["panning"]):
		return null
	var pan := RevealPan.new()
	pan.from_pos = cfg["pan_from"]
	pan.to_pos = cfg["pan_to"]
	pan.shots = int(cfg["pan_shots"])
	pan.prefix = String(cfg["pan_out"])
	return pan


## Where the camera sits this tick. The target lerps the segment by elapsed fraction; the VELOCITY
## handed to the rig is the segment's own rate, so lead and smoothing see the same numbers a real
## body moving along this line would produce.
func camera_position(tick: int, rig: CameraRig, zoom: float, viewport: Viewport, delta: float) -> Vector2:
	var span: int = (shots - 1) * TICKS_PER_SHOT
	var t: float = clampf(float(tick) / float(maxi(span, 1)), 0.0, 1.0)
	var w: float = float(viewport.get_visible_rect().size.x) if viewport != null else 1920.0
	return rig.step(from_pos.lerp(to_pos, t), (to_pos - from_pos) / maxf(float(span) * delta, 0.001),
		zoom, w, delta)


## One capture every TICKS_PER_SHOT ticks, `prefix`_i.png each; finishes the scene when the strip is
## full. The caller holds the world across this await (the same `_shutter_held` discipline the still
## path uses) so a strip frame is a frame, not a smear of two.
func step(scene: Node2D, tick: int, camera: Camera2D, zoom: float, body: Body,
		sky_view: WorldView) -> void:
	if _shot >= shots:
		scene._finish_and_quit()
		return
	if tick == _shot * TICKS_PER_SHOT + 1:
		await RevealShutter.capture(scene, "%s_%d.png" % [prefix, _shot], tick, camera, zoom, body,
			sky_view)
		_shot += 1
