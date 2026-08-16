extends SceneTree

## THE PLACE THE PLAYER SPENDS THE GAME HAS TO HAVE SOMETHING IN IT TOO.
##
## check_opening put a number on dead space in the first screen and the first screen got fixed. But the
## first screen is the EASY half and it is the half a player looks at for thirty seconds: the sky does most
## of the composition, daylight does most of the lighting, and the soil profile does the rest. Everything
## after that happens underground, lit by a lamp, under a veil that MULTIPLIES — and multiplying is exactly
## the operation that took the opening's bottom half down to five distinct levels while every terrain pass
## ran correctly. There is no reason to think the same arithmetic stops applying below the surface, and
## every reason to think it applies harder, because down there the multiplier is smaller.
##
## THE ONE THING THIS TEST MUST NOT DO is punish darkness. Down here the dark is the DESIGN — the veil is
## supposed to take the far rock away, that is what makes the lamp mean anything, and a guard that counted
## unlit tiles would only ever be measuring how much unlit rock is in frame. It would push the whole game
## toward flat and bright, which is the opposite of the goal.
##
## So it judges only what the player can actually SEE: tiles above a lit floor, which is the lamp pool, the
## torchlight and the near rock. Inside that, the same standard the surface is held to. A dead tile out in
## the black is correct. A dead tile under your own lamp is the picture failing where the player is looking.
##
## Dug by the real PlayAgent through the real verbs, so the shaft and the chamber in frame are ones a player
## could actually have cut.
##
##   godot --path . --script res://tools/check_underground.gd     (NO --headless: it judges pixels)

const SCENE: String = "res://scenes/main.tscn"
const AGENT := preload("res://tools/play_agent.gd")
const DEAD := preload("res://tools/dead_space.gd")
const SETTLE: int = 60

## How far below its column's surface the shaft is sunk, and how big a work chamber is cut at the bottom.
## Deep enough to be past the daylight soak entirely — the point is to judge lamp-lit rock, not dim soil —
## and wide enough that the frame contains a back wall rather than a slot.
const DELVE_ROWS: int = 16
const ROOM_W: int = 11
const ROOM_H: int = 6

## The judged slab: everything but the objective banner at the top and the hotbar at the bottom. There is
## no sky down here, so unlike the opening there is nothing to exclude in the middle.
const HUD_TOP: float = 0.16
const HUD_BOTTOM: float = 0.20

## Mean luminance a tile needs before it is judged at all — the line between "the player can see this" and
## "the player is looking into the dark on purpose".
const LIT_FLOOR: float = 26.0

## Fraction of LIT tiles allowed to be dead. Tighter than the opening's cap, deliberately: this region has
## already been filtered down to the part of the frame the lamp is pointing at, so there is no cave mouth
## or unlit overhang left in the sample to excuse.
const DEAD_CAP: float = 0.10


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("check_underground: SKIP — no display; a picture cannot be judged by the dummy renderer")
		quit(0)
		return
	MainView.dev_start = false
	await _run()


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	await _delve(main)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw          # the veil/light layers repaint a frame behind a move

	var img: Image = get_root().get_texture().get_image()
	var h: int = img.get_height()
	var j: Dictionary = DEAD.judge(img, int(float(h) * HUD_TOP), int(float(h) * (1.0 - HUD_BOTTOM)),
		LIT_FLOOR)
	print("== the rock you can actually see has to have something in it ==  (%dx%d, %d lit tiles judged)"
		% [img.get_width(), h, int(j["total"])])
	DEAD.report(j)
	var det: PackedFloat32Array = j["details"]
	var sorted: Array = Array(det)
	sorted.sort()
	print("    local contrast per lit tile: %s"
		% ", ".join(sorted.map(func(v: float) -> String: return "%.1f" % v)))
	var frac: float = float(j["frac"])

	if int(j["total"]) < 6:
		printerr("check_underground: FAIL — only %d lit tiles in frame; the lamp lights almost nothing"
			% int(j["total"]))
		quit(1)
		return
	if frac <= DEAD_CAP:
		print("check_underground: PASS — %d/%d lit tiles dead (%.0f%%, cap %.0f%%)"
			% [int(j["dead"]), int(j["total"]), frac * 100.0, DEAD_CAP * 100.0])
		quit(0)
	else:
		printerr("check_underground: FAIL — %d/%d lit tiles dead (%.0f%%, cap %.0f%%): the rock under the"
			% [int(j["dead"]), int(j["total"]), frac * 100.0, DEAD_CAP * 100.0]
			+ " player's own lamp has nothing in it")
		quit(1)


## Sink a shaft and cut a work chamber at the bottom of it — the pocket a player carves when they stop to
## set up a drill site, and the only view that shows the back wall as a plane rather than as a sliver.
func _delve(main: MainView) -> void:
	var agent: PlayAgent = AGENT.new(self, main)
	agent.give(&"stone_pickaxe", 1)
	var here: Vector2i = main._cell_at(agent.player.position)
	await agent.dig_down_to(Vector2i(here.x, main.sim.surface_row(here.x) + DELVE_ROWS))
	# Cut through sim.mine rather than main.try_mine: try_mine enforces the player's 3.2-cell REACH, and a
	# chamber wider than the miner's arms would silently come out as a blob around them. Reach is a
	# gameplay rule; the shot only needs the geometry that walking around would leave.
	var c: Vector2i = main._cell_at(agent.player.position)
	var left: int = c.x - ROOM_W / 2
	for dy: int in range(-ROOM_H + 1, 1):
		for dx: int in range(ROOM_W):
			main.sim.mine(Vector2i(left + dx, c.y + dy))
		await physics_frame
	main._renderer.repaint_world()
	for _i: int in 30:
		await physics_frame
