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
## WHAT THIS LAYER ACTUALLY JUDGES, stated because the prose above describes the original FAILURE (the
## bottom forty-five percent of the frame) and a reader can easily take that for the layer's coverage. It is
## not: the judged band runs from the walked horizon to 1 - HUD_BOTTOM, which on the current opening is
## y 613..864 of 1080 -- about 23% of the frame, sixteen tiles wide and two deep.
##
## And HUD_BOTTOM is a hardcoded constant with nothing tying it to the actual HUD. If the hotbar moves, this
## keeps excluding the old rectangle and starts judging ground it should not, or excusing ground it should
## judge, with no assertion anywhere to notice. Not fixed here -- scenes/hud.gd is not this layer's to
## read -- but recorded so the next person does not assume the two are linked.
## SUPERSEDED by Hud.bottom_furniture_fraction() at the call site; kept only for the note above.
const HUD_BOTTOM: float = 0.20       ## fraction of the frame the hotbar + key strip occupy

## Fraction of judged ground tiles allowed to be dead. Not zero — a dark cave mouth or an unlit overhang
## in frame is legitimately empty and a zero cap would forbid darkness itself. Measured on this frame: the
## broken opening ran 13 of 32 tiles dead (41%), the fixed one runs 0.
##
## THE ALLOWANCE IS THREE TILES, NOT FOUR. This said "twelve percent is four tiles" and that is arithmetic
## nobody checked: the band is 32 tiles, 4/32 = 12.5%, and 12.5 > 12.0, so four tiles FAILS. Three (9.4%)
## passes. The cap is unchanged -- only the sentence describing it was wrong, and it was wrong in the
## direction that makes the gate sound looser than it is.
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
	# ASKED, NOT ASSUMED. This was int(h * (1.0 - HUD_BOTTOM)) with HUD_BOTTOM = 0.20 hardcoded and nothing
	# tying it to the HUD. The real geometry is readable now -- Hud.HOTBAR_BAND_TOP is the
	# canvas y where the bottom furniture starts, and _draw_inventory derives its own layout from it, so the
	# two cannot drift. The true edge is 0.8194, not 0.80: the old constant excluded about 1.9% of the frame
	# that is ground, and would have kept excluding the old rectangle if the hotbar ever moved.
	#
	# Judged band is unchanged in practice -- tiles are laid from y0 downward and 120px rows still give two
	# of them -- so this moves no verdict today. It stops the number being a guess, which is the point.
	var y1: int = int(float(h) * Hud.bottom_furniture_fraction())

	var j: Dictionary = DEAD.judge(img, y0, y1)
	print("== the ground in the opening frame has to have something in it ==  (%dx%d, horizon at y=%d, %d tiles)"
		% [w, h, y0, int(j["total"])])
	DEAD.report(j)

	# NON-VACUITY — THERE HAS TO HAVE BEEN A BAND TO JUDGE. `frac` is a fraction of the tiles that were
	# judged, so the gate below says nothing at all about a band that held none. And the band is not fixed:
	# it runs from the live horizon to the HUD, so any change to the opening camera framing moves it, while
	# a tile is a flat 120px. A framing tweak leaving under 120px between the horizon and the HUD reduces
	# this layer to a permanent pass, and the only trace is the "0 tiles" already printed one line above.
	#
	# `judge()` now returns frac 1.0 for a band it could not judge, so the run already fails without these —
	# a sentinel on the failing side beats a guard every caller has to remember, which is exactly how
	# check_underground came to have one and this file did not. What these add is a LEGIBLE failure: "the
	# band is 90px tall, under one 120px tile" is a five-second fix and "100% of the ground is dead" is an
	# afternoon of looking at the wrong thing.
	#
	# Two claims: the band must be big enough to tile at all, AND every tile in it must have been judged.
	# Equality alone is satisfied by 0 == 0, so the first is the load-bearing one HERE.
	#
	# THE SECOND CANNOT FAIL FOR THIS CALLER, and the comment used to claim it "catches something the
	# sentinel cannot". `want` re-derives judge()'s own loop bounds, and judge() drops a tile from `total`
	# only when `lit_floor` excuses it -- a parameter defaulting to 0.0 that this layer never passes. Same
	# formula on both sides of the comparison. It is load-bearing in check_underground, which DOES pass a
	# lit_floor, and it was copied here where it is inert. Kept rather than deleted: it costs nothing and it
	# becomes real the day this caller grows a lit_floor. Described honestly instead of credited falsely.
	var tile: int = int(DEAD.TILE)
	var rows_j: int = maxi(0, (y1 - y0) / tile)
	var cols_j: int = w / tile
	var want: int = rows_j * cols_j
	print("  the band from the horizon to the HUD is %d x %d tiles" % [cols_j, rows_j])
	if want <= 0:
		printerr("check_opening: FAIL — the judged band is %dpx tall, under one %dpx tile: there was nothing"
			% [y1 - y0, tile] + " to judge, and a dead fraction of a judged nothing is not a pass")
		quit(1)
		return
	if int(j["total"]) != want:
		printerr("check_opening: FAIL — %d tiles judged where the band holds %d; tiles were skipped"
			% [int(j["total"]), want])
		quit(1)
		return

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
## LATENT, AND CORRECT ONLY BY ACCIDENT OF TIMING: this calls sim.surface_row(col), the call 885c08d
## deliberately abandoned in main.gd because it returns the floor of your own shaft once you have dug. This
## fixture digs nothing in its settle frames, so the answer is the real terrain surface and the horizon is
## right. It carries the defect the game removed, and it would bite the moment this layer judged a frame
## after any digging.
func _horizon_y(main: MainView, h: int) -> int:
	# THE ENGINE'S TRANSFORM, NOT A RE-DERIVATION. This was `(world_y - cam.y) * zoom + h * 0.5`, which reads
	# the captured image and the canvas as one space. They are not: viewport 1280x720 under a 1920x1080 window
	# with stretch mode "canvas_items" composites the canvas 1.5x on the way to the framebuffer, so the form
	# was exact only on the camera's own row and pulled INBOARD everywhere else -- a horizon ten cells
	# off-centre landed about 3.3 cells toward the middle of the frame. Found by the same defect in
	# check_contact_edge, where correcting it moved the edge step from 1.38 to 11.7 with no renderer change.
	var to_px: Transform2D = main.get_viewport().get_final_transform() \
		* main.get_viewport().get_canvas_transform()
	var col: int = main._cell_at(main._player.position).x
	var world_y: float = float(main.sim.surface_row(col) + 1) * float(WorldRenderer.CELL)
	return clampi(int((to_px * Vector2(main._camera.global_position.x, world_y)).y), 0, h - 1)
