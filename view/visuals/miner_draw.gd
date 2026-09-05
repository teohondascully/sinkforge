class_name MinerDraw
extends RefCounted

## How the miner is drawn — the sixth seam extracted from `reveal_scene.gd` (D0304), moved into the view
## for the shell's seat (A' step 6q, D0380) and made a reading of the OBSERVATION: the body's box, its
## velocity, whether it stands, which way it faces and the swing's phase all cross the L2 door already, so
## the painter needs neither the `Body` nor the `InputFrame` it used to be handed. The scene keeps the
## tick; this keeps the pose.
##
## The miner: sprite if one resolves, the primitive rectangle if not. See `MinerLook` for why the dig pose
## reads the swing rather than the dig event, and why the rectangle path stays.
##
## `frame` may be null (the coordinator has not built one yet), and then nothing is drawn: there is no
## truthful pose without an observation.
## The fallback rectangle's colours when no sprite resolves (a fixture without the art): red in the air,
## amber on the ground -- the shell's own debug colours, moved here with the draw (D0391).
const COLOR_BODY := Color(0.85, 0.25, 0.25)
const COLOR_BODY_GROUNDED := Color(0.95, 0.75, 0.15)


## The painter form on the `(frame, canvas)` contract, for `ViewStack._mount_body`: the clock is the
## frame's own deterministic one, in ticks.
static func paint(frame: Frame, canvas: CanvasItem) -> void:
	if frame == null:
		return
	draw(canvas, frame, int(round(frame.anim_time * 60.0)), COLOR_BODY, COLOR_BODY_GROUNDED)


static func draw(canvas: CanvasItem, frame: Frame, tick_count: int, color_body: Color, color_grounded: Color) -> void:
	if frame == null or frame.obs == null:
		return
	var o: Interface.Observation = frame.obs
	var scale: float = float(Fx.SCALE)
	var left: float = float(o.left_x) / scale
	var top: float = float(o.top_y) / scale
	var w: float = float(o.right_x - o.left_x) / scale
	var h: float = float(o.bottom_y - o.top_y) / scale
	# On a rope the body travels at the climb axis's speed (`BodyMedium`), so the axis is the velocity's sign.
	var line: Dictionary = {"climbing": o.climbing, "climb_dir": -signi(o.vel_y) if o.climbing else 0, "taut": o.grapple_taut, "anchored": o.grapple_anchored}
	var key: String = MinerLook.sprite_key(o.mining_is_charging or o.mining_swing, o.on_floor, o.vel_x, o.vel_y, tick_count, o.mining_swing_phase, line)
	var tex: Texture2D = MinerLook.resolve(key)
	if tex == null:
		canvas.draw_rect(Rect2(left, top, w, h), color_grounded if o.on_floor else color_body, true)
		return
	MinerLook.draw_sprite(canvas, tex, Vector2(left + w * 0.5, top + h * 0.5), int(round(h)), o.facing)
