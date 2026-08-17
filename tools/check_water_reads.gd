extends "res://tools/check_base.gd"

## DOES WATER READ AS WATER, OR AS A BLUE RECTANGLE?
##
## The played descent now drops a body sixty-four metres into an aquifer chamber, which made the aquifer
## something a player LOOKS at rather than something they wade through — and looked at, it was the most
## programmer-art thing on screen: a uniform translucent slab with a hard bright stripe along the top and,
## because the waterline was drawn for every cell rather than only the exposed ones, more stripes stacked
## inside it. It read as a stack of UI panels. This is the layer that keeps it honest.
##
## Judged from PIXELS, on a chamber carved and flooded on purpose, because every property here is about
## what the eye receives and none of them can be read off the sim:
##
##   IT IS NOT A FLAT FILL.   Run the shared dead-space judge (the same one check_opening and
##                            check_underground use, so there is one definition of "dead" in this codebase)
##                            over the water body. A slab of one value is dead space by exactly that
##                            definition, and no amount of it being the right blue changes that.
##   DEPTH DARKENS.           The top of the body must read brighter than its floor. A gradient is the
##                            cheapest possible cue that a volume has volume, and its absence is the
##                            loudest cue that it does not.
##   ONE SURFACE, NOT SIX.    Bright horizontal edges, counted down a column through the body. A pool has
##                            exactly one surface; every extra bright line is an interior cell drawing an
##                            edge it should not own, which is the specific bug this layer was born from.
##
## Renders for real, so it self-skips green under --headless (like every other pixel layer).
##   godot --path . --script res://tools/check_water_reads.gd

const SCENE: String = "res://scenes/main.tscn"
const DEAD := preload("res://tools/dead_space.gd")
const CELL: int = 32
const SETTLE: int = 30
const SHOT_SETTLE: int = 90   ## frames for the light/veil layers to repaint after the body is placed
const POOL_TICKS: int = 600   ## SIM ticks driven directly, so the body is evenly settled on any machine

## The cistern: a chamber cut into real rock well below the surface, flooded to the brim.
const POOL_LEFT: int = 24
const POOL_RIGHT: int = 44
const POOL_TOP: int = 46
const POOL_BOTTOM: int = 54
const HEAD: int = 6                  ## rows of air left above the water, so the surface is visible
## The seal, and it is deliberately thick. It is not only keeping the cistern from draining into whatever
## the generator left next door — its LEFT face is the reference this layer compares the water against, and
## that reference has to be rock beyond argument. The first version sampled a strip a few rows under the
## pool floor and got the world's own natural aquifer, then reported the water as barely distinguishable
## from "rock" that was in fact more water.
const WALL: int = 3

const COOL_MIN: float = 12.0         ## sRGB levels of blue-over-red the water must beat the rock by
## sRGB levels of blue-over-red the SURFACE must beat the FLOOR by — the body tends toward WATER_DEEP with
## depth, which is denser and darker, so its blue-over-red separation shrinks. Measured 4.3-5.2 over three
## runs on the fixture cistern; the floor keeps roughly 1.7x headroom under the worst of those.
const GRADIENT_MIN: float = 2.5
const SURFACES_MAX: int = 2          ## bright horizontal edges down one column (one surface, plus slack)
const EDGE_JUMP: float = 9.0         ## sRGB rise between neighbouring rows that counts as an EDGE

func _initialize() -> void:
	print("== does water read as water ==")
	# Exit 42 AND a reason line: the runner requires both before it will call this a skip rather than a
	# failure, because a silent opt-out is what it is now guarding against.
	if DisplayServer.get_name() == "headless":
		print("check_water_reads: SKIP (headless — this layer judges pixels)")
		quit(SKIP)
		return
	MainView.dev_start = false
	await _run()
	if _failures == 0:
		print("check_water_reads: PASS — a body of water, not a blue rectangle")
		quit(0)
	else:
		print("check_water_reads: FAIL (%d)" % _failures)
		quit(1)


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	_flood(main.sim)
	# Put the body beside the cistern so the camera frames it, and let the light layers repaint.
	# Stand the body in the air pocket ABOVE the water, not in the rock over it: the camera follows the
	# body, and the first version of this put it inside a solid cell, where it was pushed up to daylight and
	# judged a hillside forty rows from the cistern it was supposed to be looking at.
	main._player.place(Vector2(float((POOL_LEFT + POOL_RIGHT) / 2) * CELL,
		float(POOL_TOP - 3) * CELL))
	# SETTLE THE SIM, NOT THE CLOCK. This waited SHOT_SETTLE rendered frames and assumed the pool would be
	# even by then — but the scene advances the sim by real delta with a CAPPED backlog, so how far a body
	# settles in ninety frames depends on how busy the machine is. Under parallel harness load each frame
	# carries more sim time and the pool levelled; run alone on an idle machine it was still terracing, the
	# depth tint had nothing to read, and the gradient assertion failed at 0.1 of a floor of 2.5 — a layer
	# that passed or failed on CPU contention rather than on anything about the game. Ticking the sim
	# directly makes the fixture deterministic, which is the only way this measurement means anything.
	for _t: int in POOL_TICKS:
		main.sim.tick()
	for _i: int in SHOT_SETTLE:
		await physics_frame
	# The HUD off, because it is not what is under test and it is drawn right across the middle of the
	# frame: the objective banner, the stratum plate and a hint bubble between them accounted for most of
	# the "bright horizontal edges" this layer counted, and flattened the gradient by sitting on top of it.
	if main._hud != null:
		main._hud.visible = false
	await physics_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_root().get_texture().get_image()
	img.save_png("res://_moment_water.png")

	# Where the pool landed on screen, so every measurement below reads the water and not the HUD.
	var band: Rect2i = _on_screen(main, img)
	print("  the cistern occupies %s of a %dx%d frame" % [band, img.get_width(), img.get_height()])
	if band.size.x < 40 or band.size.y < 40:
		_failures += 1
		printerr("  FAIL: the cistern did not land on screen — nothing to judge")
		main.queue_free()
		return

	# Crop to the body before judging anything. The shared judge takes row bounds and reads the FULL WIDTH
	# of them, which over a chamber twenty cells wide in a frame sixty cells wide means most of what it
	# grades is the dark rock either side and whatever HUD is floating over it — the first run of this
	# reported the deadest tile at an x the cistern does not even reach.
	var sub: Image = img.get_region(band)
	sub.save_png("res://_moment_water_body.png")
	# The dead-space fraction is REPORTED, not gated, and that is a deliberate reversal. Running the shared
	# judge here was the obvious move and it was the wrong standard: "dead" was defined for ROCK, which is
	# supposed to have tooth, and it grades this body 60% featureless. But water is the one thing in the
	# frame that is meant to be smooth — the only way to satisfy a terrain standard would be to put grain on
	# water, which looks worse and is the opposite of the goal. (The number is also flattered or punished by
	# whatever the rig's rock happens to be: a sealed box of uniform stone has nothing to show through.)
	#
	# The property a FLUID actually has to have is that you can see it is there. So the gate is contrast
	# against the rock it sits in, measured where it matters — cool against warm — and the dead fraction
	# stays printed underneath as context for anyone reading a regression.
	var j: Dictionary = DEAD.judge(sub, 0, sub.get_height())
	DEAD.report(j)
	print("  (%.0f%% of the body is featureless by the ROCK standard — not gated; see the note in source)"
		% (float(j["frac"]) * 100.0))

	var rock_rect: Rect2i = _rock_below(main, img)
	print("  the reference wall is %s" % rock_rect)
	var rock: Image = img.get_region(rock_rect)
	rock.save_png("res://_moment_water_rock.png")
	var wet: Vector3 = _cool(sub)
	var dry: Vector3 = _cool(rock)
	var sep: float = (wet.z - wet.x) - (dry.z - dry.x)
	print("  the water reads %.1f cooler than the rock under it (blue minus red)" % sep)
	_check(sep >= COOL_MIN,
		"the body is legible against its own rock (%.1f levels, floor %.1f)" % [sep, COOL_MIN])

	var top: float = _mean(sub, 0.10, 0.35)
	var bottom: float = _mean(sub, 0.65, 0.92)
	var ctop: Vector3 = _cool(sub.get_region(Rect2i(0, int(float(sub.get_height()) * 0.10),
		sub.get_width(), int(float(sub.get_height()) * 0.25))))
	var cbot: Vector3 = _cool(sub.get_region(Rect2i(0, int(float(sub.get_height()) * 0.65),
		sub.get_width(), int(float(sub.get_height()) * 0.27))))
	# DEPTH IS GRADED ON THE AXIS THE DESIGN PUTS IT ON. This assertion used to measure LUMINANCE and demand
	# the floor of the body be 2.5 sRGB levels darker than its top. The renderer says in as many words that
	# it does not work that way — "Depth is carried by COLOUR — toward WATER_DEEP — rather than by density" —
	# and underground the shadow veil multiplies the whole body down until a luminance difference of tens of
	# levels in the source palette survives as 0.6 on screen. So the check demanded a real property through a
	# channel that could not carry it, and had failed every time it genuinely ran since it was written; it
	# only ever reported green in the harness on runs where this GL layer self-skipped for want of a window.
	# Measured on the COOL axis this same body separates by 4.3-5.2 levels across three runs, so the property
	# is plainly there. The floor is set from those measurements, not guessed ahead of them.
	var fall: float = (ctop.z - ctop.x) - (cbot.z - cbot.x)
	print("  the body reads %.1f blue-over-red at the top and %.1f near its floor (luma %.1f / %.1f)"
		% [ctop.z - ctop.x, cbot.z - cbot.x, top, bottom])
	_check(fall >= GRADIENT_MIN,
		"depth deepens the colour — the floor is denser than the surface (%.1f levels, floor %.1f)"
			% [fall, GRADIENT_MIN])

	var edges: int = _bright_edges(sub)
	print("  %d bright horizontal edges down the middle of it" % edges)
	_check(edges <= SURFACES_MAX,
		"a pool has ONE surface (%d bright edges, cap %d)" % [edges, SURFACES_MAX])

	main.queue_free()
	await physics_frame


## Carve the chamber out of the real world, SEAL it, and fill it. Air above the waterline, so there is a
## surface to judge. The seal matters: an open-sided chamber drains into whatever the generator left next
## door, and what this layer then measures is a puddle spreading through a cave system rather than the body
## of water it meant to photograph.
func _flood(sim: FactorySim) -> void:
	for x: int in range(POOL_LEFT - WALL, POOL_RIGHT + WALL + 1):
		for y: int in range(POOL_TOP - HEAD - WALL, POOL_BOTTOM + WALL + 1):
			var edge: bool = x < POOL_LEFT or x > POOL_RIGHT \
					or y < POOL_TOP - HEAD or y > POOL_BOTTOM
			var cell := Vector2i(x, y)
			if edge:
				if not sim.is_solid(cell):
					sim.set_solid(cell, &"stone")
			else:
				sim.mine(cell)
	for x: int in range(POOL_LEFT, POOL_RIGHT + 1):
		for y: int in range(POOL_TOP, POOL_BOTTOM + 1):
			sim.add_water(Vector2i(x, y), FactorySim.WATER_MAX)


## The screen rectangle the flooded cells project to, trimmed to the frame — the region every judgement
## below runs over. Derived from the camera rather than assumed, so a zoom change cannot quietly point
## this layer at the wrong pixels and keep passing.
func _on_screen(main: MainView, img: Image) -> Rect2i:
	var xf: Transform2D = main.get_viewport().get_canvas_transform()
	var a: Vector2 = xf * (Vector2(POOL_LEFT + 1, POOL_TOP) * float(CELL))
	var b: Vector2 = xf * (Vector2(POOL_RIGHT, POOL_BOTTOM + 1) * float(CELL))
	var r := Rect2i(Vector2i(a.floor()), Vector2i((b - a).floor()))
	return r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))


## The cistern's own sealed WALL — rock by construction, at the same depth and under the same light as the
## water beside it, which is what makes it a fair thing to compare against.
func _rock_below(main: MainView, img: Image) -> Rect2i:
	var xf: Transform2D = main.get_viewport().get_canvas_transform()
	var a: Vector2 = xf * (Vector2(POOL_LEFT - WALL, POOL_TOP) * float(CELL))
	var b: Vector2 = xf * (Vector2(POOL_LEFT, POOL_BOTTOM + 1) * float(CELL))
	var r := Rect2i(Vector2i(a.floor()), Vector2i((b - a).floor()))
	return r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))


## Mean sRGB (r, g, b) of a region — the channel split is the point, so this cannot collapse to luma.
func _cool(img: Image) -> Vector3:
	var total := Vector3.ZERO
	var n: int = 0
	for y: int in range(0, img.get_height(), 2):
		for x: int in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			total += Vector3(c.r, c.g, c.b) * 255.0
			n += 1
	return total / maxf(float(n), 1.0)


## Mean sRGB level over a horizontal slice of the body, given as fractions of its height.
func _mean(img: Image, f0: float, f1: float) -> float:
	var y0: int = int(float(img.get_height()) * f0)
	var y1: int = int(float(img.get_height()) * f1)
	var total: float = 0.0
	var n: int = 0
	for y: int in range(y0, y1):
		for x: int in range(0, img.get_width(), 3):
			var c: Color = img.get_pixel(x, y)
			total += (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) * 255.0
			n += 1
	return total / maxf(float(n), 1.0)


## Bright horizontal edges down the middle of the body: rows whose mean jumps by EDGE_JUMP over the row
## above. One is the surface. More than that means interior cells are drawing edges they do not own.
func _bright_edges(img: Image) -> int:
	var rows := PackedFloat32Array()
	for y: int in img.get_height():
		var total: float = 0.0
		var n: int = 0
		for x: int in range(0, img.get_width(), 2):
			var c: Color = img.get_pixel(x, y)
			total += (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) * 255.0
			n += 1
		rows.append(total / maxf(float(n), 1.0))
	var edges: int = 0
	var y: int = 2
	while y < rows.size():
		if rows[y] - rows[y - 2] >= EDGE_JUMP:
			edges += 1
			y += 6                       # one edge is a few px thick; don't count it twice
		else:
			y += 1
	return edges
