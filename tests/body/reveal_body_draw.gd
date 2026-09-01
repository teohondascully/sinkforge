class_name RevealBodyDraw
extends RefCounted

## How the miner is drawn in the debug scene — the sixth seam extracted from `reveal_scene.gd` (D0304).
##
## Split at the 400-line cap and at a real subject boundary rather than an arbitrary one: everything here
## answers "what does the body look like this frame", and nothing here decides what the body DOES. The
## scene keeps the tick; this keeps the pose. `QUALITY.md` §2 — a cap is met by splitting, never by
## trimming the reasoning.

## The miner: sprite if one resolves, the primitive rectangle if not. See `MinerLook` for why the dig
## pose reads the INPUT rather than the dig event, and why the rectangle path stays.
##
## `frame` may be null (the coordinator has not built one yet), which leaves `MinerLook.SWING_PHASE_NONE`
## and falls the animation back to legacy's clock — see below.
static func draw(canvas: CanvasItem, body: Body, input: InputFrame, tick_count: int, frame: Frame,
		color_body: Color, color_grounded: Color) -> void:
	var left: float = float(body._left_x()) / float(Fx.SCALE)
	var top: float = float(body._top_y()) / float(Fx.SCALE)
	# The swing phase comes through the L2 door rather than off `_mining` directly, even though the scene
	# holds both: D0287's whole claim is that the pick animation is a function of the SIM's swing, and
	# reading the sim object here would draw the identical picture while proving none of that. A frame the
	# coordinator has not built yet leaves the sentinel, and the animation falls back to legacy's clock.
	var swing_phase: int = MinerLook.SWING_PHASE_NONE
	if frame != null and frame.obs != null:
		swing_phase = frame.obs.mining_swing_phase
	var key: String = MinerLook.sprite_key(input.dig_pressed, body.on_floor,
		body.vel_x, body.vel_y, tick_count, swing_phase)
	var tex: Texture2D = MinerLook.resolve(key)
	if tex == null:
		canvas.draw_rect(Rect2(left, top, Body.WIDTH_PX, Body.HEIGHT_PX),
			color_grounded if body.on_floor else color_body, true)
		return
	# The body's local origin is its CENTRE, which is what `MinerLook.dest_rect` is expressed in.
	MinerLook.draw_sprite(canvas, tex,
		Vector2(left + float(Body.WIDTH_PX) * 0.5, top + float(Body.HEIGHT_PX) * 0.5),
		Body.HEIGHT_PX, body.facing)
