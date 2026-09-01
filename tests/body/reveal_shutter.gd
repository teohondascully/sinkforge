class_name RevealShutter
extends RefCounted

## THE SHUTTER. Lifted out of `tests/body/reveal_scene.gd` (D0296) when that file passed its 400-line cap
## for the second time — the fifth seam taken out of it, after `RevealArgs`, `RevealRecording`,
## `RevealTerrainDraw` and `RevealViewSetup`, and taken for the same reason each time: the scene
## ORCHESTRATES, and this is one self-contained job it happened to be holding.
##
## `docs/QUALITY.md` §2 records what happens when a cap is met by trimming instead: `sim/body/body.gd`
## sat at exactly 400 for three commits running. Every line below is a comment earned by a bug.

## Saves one frame, says what was IN it, and refuses to call a blank capture a success.
##
## **THE CALLER MUST HOLD THE WORLD ACROSS THESE AWAITS** (D0304). Nothing here stops the scene ticking,
## and for as long as nothing did, the sim and `WorldView`'s cosmetic clock advanced by however many
## physics ticks happened to fall inside two rendered frames — a function of machine load, which made two
## captures of the SAME COMMIT at the SAME TICK differ by 38,900 pixels in the `aim` moment and 1,008 in
## `delve`. `reveal_scene` sets `_shutter_held` before calling this. Holding the tick does NOT hold the
## picture, which is the trap worth naming: the redraw these awaits exist to wait for was already queued
## before the hold, so freezing the process does not freeze the draw it is waiting on.
##
## That was one of two causes; the other was an unseeded global RNG in the particle path, and only both
## together take the difference to zero.
##
## **TWO `process_frame` AWAITS, NOT ONE** (D0189). It was a single await, which silently captured a
## BLACK image on every early tick — the agent-mode run is only ~15 ticks long, so every capture point IS
## early, and the tool reported "screenshot saved" over a frame the renderer had not drawn yet. A capture
## tool that cannot register its own subject and calls that success is this project's house failure class.
## Two frames is what actually clears it, and `warn_if_blank` is what makes a recurrence loud rather than
## a black PNG nobody opens.
##
## **IT PRINTS THE CAMERA AND THE BODY** (D0190). A tool that reports only "saved" cannot tell a
## badly-aimed camera from a correct one, which is the same blindness one layer up — and it is not
## hypothetical: P017 moved the world's surface down eighty rows and every absolute camera row in the
## repository ended up pointing at empty sky (D0292, D0295). This line is what says so.
static func capture(scene: Node2D, path: String, tick: int, camera: Camera2D, zoom: float,
		body: Body) -> void:
	await scene.get_tree().process_frame
	await scene.get_tree().process_frame
	var img: Image = scene.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("reveal_scene: screenshot saved to %s at tick %d" % [path, tick])
	print("reveal_scene: camera=%s zoom=%.1f body_cell=(%d,%d) body_px=(%.1f,%.1f)" %
		[camera.position, zoom, Body._px_to_cell(body.pos_x), Body._px_to_cell(body.pos_y),
		float(body.pos_x) / float(Fx.SCALE), float(body.pos_y) / float(Fx.SCALE)])
	DebugSceneCommon.warn_if_blank(img, path)
