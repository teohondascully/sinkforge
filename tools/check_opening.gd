extends "res://tools/check_base.gd"

## NO LARGE REGION OF THE OPENING FRAME MAY BE DEAD SPACE.
##
## The first screen a player ever sees is the one piece of this game judged before anything is played, and
## the piece least protected by tests: every other harness layer measures the SIM, and a composition
## failure is invisible to all of them. The failure that prompted this was not subtle — the bottom
## forty-five percent of the opening frame printed as one smooth brown gradient with about five distinct
## levels in it. Every terrain pass was running correctly; the veil MULTIPLIES, which preserves relative
## contrast perfectly, but at a multiplier of 0.18 the whole of the rock has thirty-five levels to live in
## and its own texture spans two of them. Correct code, dead picture.
##
## What "dead" MEANS — and the two wrong instruments it took to get there — lives in tools/dead_space.gd,
## shared with check_underground so the surface and the deep are held to one standard.
##
## No reference image, nothing to re-bless when the art changes. It asserts that the picture has content,
## which is true of every good version of this frame and false of the one that prompted it.

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 60
const DEAD := preload("res://tools/dead_space.gd")

## WHAT IS JUDGED: the GROUND, from the horizon down to where the hotbar starts.
##
## Not the sky, which is a backdrop and is allowed — required, really — to be a smooth gradient; a test
## that counted empty sky as a failure would only ever be measuring how much sky is in frame, and would
## push every composition toward busy. Not the HUD either: vector chrome with hard edges over near-black
## panels flatters every tile it touches. The ground is the game's subject, it is where the player is
## going, and it is the region that was dead.
const HUD_BOTTOM: float = 0.20       ## fraction of the frame the hotbar + key strip occupy

## Fraction of judged ground tiles allowed to be dead. Not zero — a dark cave mouth or an unlit overhang
## in frame is legitimately empty and a zero cap would forbid darkness itself. Measured on this frame: the
## broken opening ran 13 of 32 tiles dead (41%), the fixed one runs 0. Twelve percent is four tiles, which
## is room for a genuinely dark feature and nowhere near room for a dead region.
const DEAD_CAP: float = 0.12


func _initialize() -> void:
	# The dummy renderer paints blank frames, so there is nothing here to judge and pretending otherwise
	# would be worse than not running: a green "no dead space" on an all-black image is a lie. Skip, say
	# so, and let the machines that can actually draw be the ones that answer. The runner is told with
	# exit 42 and the reason line below — both halves, or it counts this as a failure.
	if DisplayServer.get_name() == "headless":
		print("check_opening: SKIP — no display; a picture cannot be judged by the dummy renderer")
		quit(SKIP)
		return
	MainView.dev_start = false
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw          # the veil/light layers repaint a frame behind a move
	var img: Image = get_root().get_texture().get_image()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var y0: int = _horizon_y(main, h)
	var y1: int = int(float(h) * (1.0 - HUD_BOTTOM))

	var j: Dictionary = DEAD.judge(img, y0, y1)
	print("== the ground in the opening frame has to have something in it ==  (%dx%d, horizon at y=%d, %d tiles)"
		% [w, h, y0, int(j["total"])])
	DEAD.report(j)
	var frac: float = float(j["frac"])
	if frac <= DEAD_CAP:
		print("check_opening: PASS — %d/%d tiles dead (%.0f%%, cap %.0f%%)"
			% [int(j["dead"]), int(j["total"]), frac * 100.0, DEAD_CAP * 100.0])
		quit(0)
	else:
		printerr("check_opening: FAIL — %d/%d tiles dead (%.0f%%, cap %.0f%%): a region of the first screen"
			% [int(j["dead"]), int(j["total"]), frac * 100.0, DEAD_CAP * 100.0]
			+ " a player ever sees has nothing in it")
		quit(1)


## Screen row of the walked surface line, straight out of the sim and the live camera — so the judged
## region starts exactly where the ground starts, whatever the terrain and zoom happen to be.
func _horizon_y(main: MainView, h: int) -> int:
	var cam: Vector2 = main._camera.global_position
	var zoom: float = main._current_zoom()
	var col: int = main._cell_at(main._player.position).x
	var world_y: float = float(main.sim.surface_row(col) + 1) * float(WorldRenderer.CELL)
	return clampi(int((world_y - cam.y) * zoom + float(h) * 0.5), 0, h - 1)
