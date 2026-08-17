extends "res://tools/check_base.gd"

## OUTSIDE THE LAMP, SOLID ROCK AND EMPTY AIR HAVE TO BE TELLABLE APART.
##
## The blind tester's words, and the only complaint in the audit they asked to record loudly: *"I cannot
## reliably tell solid rock from empty air, and I want to say that loudly."* Nine harness layers judge the
## underground and every one of them passes on the frame that produced that sentence, because all nine ask
## whether the picture has CONTENT — dead space, contrast, texture, richness. Content is not the property
## that failed. Two regions can both be full of detail and still be the same two regions to a player. What
## failed is SEPARABILITY: whether the pixel you are looking at tells you which of the two things it is.
##
## So this layer asks the tester's question in the tester's form. Sample the frame at cells the sim KNOWS
## are solid and at cells the sim KNOWS are air, and measure how often you would be right if you had to
## guess from the pixels alone. That number has a name — it is the probability that a randomly drawn rock
## sample reads differently from a randomly drawn air sample, the Mann-Whitney statistic — and it lands on
## exactly the scale the complaint is phrased in. 0.50 is a coin flip, which is "I cannot reliably tell".
##
## THE ORACLE IS INDEPENDENT, which is the whole reason this can fail. The ground truth comes from
## `sim.is_solid`; the evidence comes from `get_texture().get_image()`. Nothing in the render path is
## consulted about whether the render path worked. A layer that asked the renderer what it drew would agree
## with itself forever.
##
## TWO CUES, because a player has two. The audit's prescription for 6a is an ambient floor that keeps unlit
## *rock* grainy while unlit *air* stays black — that is a texture cue, not only a brightness cue, and a
## gauge that measured brightness alone would call a correct fix a failure. So both are measured: the mean
## luminance of a cell's patch (VALUE) and the spread within it (GRAIN). A player can read the rock if
## EITHER works, so the verdict takes the better of the two and the report prints both, because which one
## carries the frame is the thing that tells you what to go and change.
##
##   godot --path . --script res://tools/check_rock_reads.gd     (NO --headless: it judges pixels)

const SCENE: String = "res://scenes/main.tscn"
const AGENT := preload("res://tools/play_agent.gd")
const SETTLE: int = 60

## The same shaft-and-chamber the dead-space layer cuts, and for the same reason: it is the only fixture
## that puts a large carved VOID and the solid rock around it in one frame, underground, at a depth past
## the daylight soak. Kept in step with check_underground deliberately — if the two layers judged different
## places, a fix that satisfied one could quietly ruin the other's subject.
const DELVE_ROWS: int = 16
const ROOM_W: int = 11
const ROOM_H: int = 6
const MIN_DELVE: int = 12

## The judged slab: the banner and the hotbar are chrome, and chrome is neither rock nor air.
const HUD_TOP: float = 0.16
const HUD_BOTTOM: float = 0.20

## WHAT "OUTSIDE THE LAMP" MEANS HERE — and it is not a distance.
##
## The complaint is specifically about the rock the lamp does NOT reach. Inside the pool everyone agrees it
## reads fine, and including lit cells would drown the failure in the region that already works.
##
## The first version of this cut samples further than 1.6 lamp-halo radii from the body, which was a guess
## dressed as a constant, and reading the renderer showed it wrong twice over. `LAMP_RADIUS` is the additive
## bloom SPRITE, not the veil cut; the veil's widest cut is 9.0 cells and it is centred on the aimed beam at
## `head + _lamp_offset`, not on the body. A cell can sit 9 cells from the body and 7 from the beam.
##
## So ask the veil instead of guessing at it. `_veil_scratch` is the per-frame lighting buffer with every
## source's hole already cut into it, and `_veil_base` is that same buffer before any source touched it. A
## cut only ever RAISES a channel. So a cell whose scratch bytes still equal its base bytes was reached by
## no light at all — not the lamp, not a torch, not a machine, not a crystal, not a seam. That is
## provable-zero rather than far-enough, and it cannot drift: a light source added tomorrow appears in the
## buffer and is excluded automatically, where a hand-kept radius list would have to be remembered.
##
## It also covers the bloom sprite the veil knows nothing about, by arithmetic: the halo reaches 5.6 cells
## from the head, the beam centre sits 1.9 cells from the head, so the furthest a bloom-touched cell can be
## from the beam centre is 7.5 — inside the 9.0 cut. Every cell the bloom brightens is already veil-lit.
##
## Still geometric in spirit, never photometric: nothing here excludes a cell for being BRIGHT. Doing that
## would define the dark region in terms of the quantity under test, throw out every sample that made rock
## legible for the crime of making rock legible, and report a coin flip on a perfect frame and a black one
## alike.

## Cells this close to their column's surface are thrown out. Above the surface is sky, and sky against rock
## separates trivially and for a reason that has nothing to do with the complaint — a layer that sampled it
## would report near-perfect legibility on the exact frame the tester could not read. Below the surface the
## renderer runs a scatter band that fades daylight out over SKY_FADE rows, so the top of the deep is a
## gradient rather than the flat ambient this is written about. Both are excluded and the count of what was
## thrown out is printed, because a silent exclusion is how a sample becomes a different sample.
const SURFACE_CLEAR: int = 20

## Sampling geometry. A patch is taken well inside each cell's screen box so it holds one material rather
## than a boundary, and a cell whose box is too small on screen to hold a patch is skipped rather than
## sampled at one pixel.
const PATCH_FRAC: float = 0.30
const MIN_PATCH: int = 2

## NON-VACUITY FLOORS. The statistic below is a ratio over pairs drawn from two populations, so it is
## defined — and flattering — for populations of one. Eleven rock samples against three air samples can
## report a perfect 1.00 and mean nothing. These are the sizes at which the number starts being about the
## frame rather than about the sample.
const MIN_SAMPLES: int = 40

## The premise: this is supposed to be the DARK part of the frame. If the sampled cells are not dark then
## whatever is being measured, it is not the thing the tester complained about, and the verdict below does
## not apply to it. Stated as an assertion rather than an assumption because check_underground's seed-99
## failure was exactly this shape — a layer that reached the wrong place and judged it confidently.
const DARK_CEILING: float = 34.0

## THE FLOOR — the probability of being right about a random rock/air pair. Set from measurement on this
## fixture, not from taste; see the audit notes. A coin flip is 0.50 and is the tester's
## sentence stated as a number.
const READ_FLOOR: float = 0.75


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		_skip_layer("check_rock_reads",
			"no display; whether rock reads as rock cannot be judged by the dummy renderer")
		return
	MainView.dev_start = false
	await _run()


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var reached: int = await _delve(main)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw          # the veil/light layers repaint a frame behind a move

	print("== outside the lamp, rock and air have to be tellable apart ==")
	print("  the delve reached %d rows below the surface (asked for %d, floor %d)"
		% [reached, DELVE_ROWS, MIN_DELVE])
	if reached < MIN_DELVE:
		printerr("check_rock_reads: FAIL — the delve reached %d rows of %d, so the frame is not deep unlit"
			% [reached, DELVE_ROWS]
			+ " rock and the separability standard written for it does not apply.")
		printerr("  This is the FIXTURE failing to reach its subject, not a verdict on the rock.")
		quit(1)
		return

	var img: Image = get_root().get_texture().get_image()
	var s: Dictionary = _sample(main, img)
	var rock_v: Array[float] = s["rock_value"]
	var air_v: Array[float] = s["air_value"]
	var rock_g: Array[float] = s["rock_grain"]
	var air_g: Array[float] = s["air_grain"]

	print("  sampled %d solid cells and %d air cells outside the lamp (%d skipped: %d near the surface,"
		% [rock_v.size(), air_v.size(), int(s["skipped"]), int(s["near_surface"])]
		+ " %d inside the lamp, %d off the judged slab)" % [int(s["lit"]), int(s["offslab"])])

	# NON-VACUITY FIRST, because everything below is a ratio and a ratio over nothing is not a small
	# result, it is no result. These run before the verdict so that a frame with nothing in it fails as a
	# frame with nothing in it rather than passing as a frame that read perfectly.
	_check(rock_v.size() >= MIN_SAMPLES,
		"%d solid cells were found to judge (floor %d)" % [rock_v.size(), MIN_SAMPLES])
	_check(air_v.size() >= MIN_SAMPLES,
		"%d air cells were found to judge (floor %d)" % [air_v.size(), MIN_SAMPLES])
	if rock_v.size() < MIN_SAMPLES or air_v.size() < MIN_SAMPLES:
		printerr("check_rock_reads: FAIL — too few samples to say anything; the numbers below would be"
			+ " arithmetic about a handful of pixels, so they are not printed as a verdict")
		quit(1)
		return

	var all_v: Array[float] = rock_v.duplicate()
	all_v.append_array(air_v)
	var lum: float = _median(all_v)
	_check(lum <= DARK_CEILING,
		"the sampled region is actually dark — median luminance %.1f, ceiling %.1f (a brighter region than"
			% [lum, DARK_CEILING] + " this is not the place the complaint was about)")

	var v_auc: float = _readability(rock_v, air_v)
	var g_auc: float = _readability(rock_g, air_g)
	var best: float = maxf(v_auc, g_auc)
	print("  VALUE: rock median %.1f, air median %.1f, gap %.1f -> you would be right %.0f%% of the time"
		% [_median(rock_v), _median(air_v), absf(_median(rock_v) - _median(air_v)), v_auc * 100.0])
	print("  GRAIN: rock median %.2f, air median %.2f, gap %.2f -> you would be right %.0f%% of the time"
		% [_median(rock_g), _median(air_g), absf(_median(rock_g) - _median(air_g)), g_auc * 100.0])
	print("  the better cue is %s at %.0f%% (a coin flip is 50%%, the floor is %.0f%%)"
		% ["VALUE" if v_auc >= g_auc else "GRAIN", best * 100.0, READ_FLOOR * 100.0])

	_check(best >= READ_FLOOR,
		"a player can tell rock from air out in the dark — %.0f%% on the better of the two cues (floor %.0f%%)"
			% [best * 100.0, READ_FLOOR * 100.0])

	main.queue_free()
	await physics_frame
	_verdict("check_rock_reads", "%d rock and %d air cells, best cue %.0f%%"
		% [rock_v.size(), air_v.size(), best * 100.0])


## Walk every cell whose screen box lands on the judged slab, keep the ones that are deep and unlit, and
## record what the frame put there. Returns the two populations twice over — once by value, once by grain —
## plus the tally of what was excluded and why.
func _sample(main: MainView, img: Image) -> Dictionary:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var top: int = int(float(h) * HUD_TOP)
	var bottom: int = int(float(h) * (1.0 - HUD_BOTTOM))
	var cam: Vector2 = main._camera.global_position
	var zoom: float = main._current_zoom()
	var half := Vector2(float(w), float(h)) * 0.5
	var cell_px: float = float(WorldRenderer.CELL) * zoom
	var patch: int = maxi(MIN_PATCH, int(cell_px * PATCH_FRAC))
	# The two lighting buffers, read straight off the renderer. Their difference IS the set of lit cells.
	var scratch: PackedByteArray = main._renderer._veil_scratch
	var base: PackedByteArray = main._renderer._veil_base
	var want_bytes: int = FactorySim.GRID_COLS * FactorySim.GRID_ROWS * 4
	if scratch.size() != want_bytes or base.size() != want_bytes:
		# FALL TO THE FAILING SIDE. Without these buffers every cell would test as unlit, the sample would
		# silently become "the whole frame including the lamp pool", and the layer would report on a
		# different question than the one it is named for — while looking greener, because lit rock reads.
		printerr("check_rock_reads: FAIL — the veil buffers are %d/%d bytes, expected %d; the lit/unlit"
			% [scratch.size(), base.size(), want_bytes]
			+ " split cannot be computed and every cell would count as dark")
		quit(1)
		return {}

	var rock_value: Array[float] = []
	var air_value: Array[float] = []
	var rock_grain: Array[float] = []
	var air_grain: Array[float] = []
	var near_surface: int = 0
	var lit: int = 0
	var offslab: int = 0

	# The cell rect the camera can see, widened by two so nothing on the edge is missed, then clamped to the
	# grid. Derived from the camera rather than from the player, because the two are not the same point.
	var span: Vector2 = Vector2(float(w), float(h)) / zoom * 0.5
	var c0: Vector2i = main._cell_at(cam - span) - Vector2i(2, 2)
	var c1: Vector2i = main._cell_at(cam + span) + Vector2i(2, 2)
	c0 = Vector2i(maxi(c0.x, 0), maxi(c0.y, 0))
	c1 = Vector2i(mini(c1.x, FactorySim.GRID_COLS - 1), mini(c1.y, FactorySim.GRID_ROWS - 1))

	for cx: int in range(c0.x, c1.x + 1):
		var surf: int = main.sim.surface_row(cx)
		for cy: int in range(c0.y, c1.y + 1):
			var c := Vector2i(cx, cy)
			if cy <= surf + SURFACE_CLEAR:
				near_surface += 1
				continue
			var vi: int = (cy * FactorySim.GRID_COLS + cx) * 4
			if scratch[vi] != base[vi] or scratch[vi + 1] != base[vi + 1] \
					or scratch[vi + 2] != base[vi + 2]:
				lit += 1
				continue
			var centre: Vector2 = main._cell_center(c)
			var p: Vector2 = (centre - cam) * zoom + half
			var px: int = int(p.x)
			var py: int = int(p.y)
			if px - patch < 0 or px + patch >= w or py - patch < top or py + patch >= bottom:
				offslab += 1
				continue
			var stat: Vector2 = _patch_stats(img, px, py, patch)
			if main.sim.is_solid(c):
				rock_value.append(stat.x)
				rock_grain.append(stat.y)
			else:
				air_value.append(stat.x)
				air_grain.append(stat.y)

	return {"rock_value": rock_value, "air_value": air_value, "rock_grain": rock_grain,
		"air_grain": air_grain, "near_surface": near_surface, "lit": lit, "offslab": offslab,
		"skipped": near_surface + lit + offslab}


## Mean luminance and standard deviation over a square patch — x is VALUE, y is GRAIN.
func _patch_stats(img: Image, cx: int, cy: int, r: int) -> Vector2:
	var n: int = 0
	var sum: float = 0.0
	var sum2: float = 0.0
	for y: int in range(cy - r, cy + r + 1):
		for x: int in range(cx - r, cx + r + 1):
			var col: Color = img.get_pixel(x, y)
			var l: float = (col.r * 0.299 + col.g * 0.587 + col.b * 0.114) * 255.0
			sum += l
			sum2 += l * l
			n += 1
	if n == 0:
		return Vector2.ZERO
	var mean: float = sum / float(n)
	return Vector2(mean, sqrt(maxf(sum2 / float(n) - mean * mean, 0.0)))


## HOW OFTEN YOU WOULD BE RIGHT about a randomly drawn rock/air pair, given this one cue.
##
## The Mann-Whitney statistic: the share of all rock-air pairs in which the rock sample sits above the air
## one, ties counted as half a success because a tie is exactly the case where the pixel told you nothing.
## Distribution-free on purpose — it asks whether the two populations are in different places, not whether
## either has a shape, so a bimodal rock population (bedding against fissure) is not punished for it.
##
## FOLDED, because the player does not need to know which way round it goes. A frame where unlit air is
## consistently *brighter* than unlit rock is perfectly readable once you have looked at it for a second;
## it is the frame where the two overlap that cannot be read at all. So 0.20 and 0.80 are the same
## legibility and both fold to 0.80, and only 0.50 — no information in either direction — is the floor of
## the scale.
func _readability(a: Array[float], b: Array[float]) -> float:
	if a.is_empty() or b.is_empty():
		return 0.0                                  # nothing judged is not "perfectly separable"
	var wins: float = 0.0
	for x: float in a:
		for y: float in b:
			if x > y:
				wins += 1.0
			elif x == y:
				wins += 0.5
	var auc: float = wins / float(a.size() * b.size())
	return maxf(auc, 1.0 - auc)


func _median(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var s: Array[float] = a.duplicate()
	s.sort()
	return s[s.size() / 2]


## The shaft and the work chamber, cut by the real agent through the real verbs — lifted from
## check_underground so the two layers judge the same place. Returns rows below the PRE-DIG surface.
func _delve(main: MainView) -> int:
	var agent: PlayAgent = AGENT.new(self, main)
	agent.give(&"stone_pickaxe", 1)
	var here: Vector2i = main._cell_at(agent.player.position)
	var from_surface: int = main.sim.surface_row(here.x)
	await agent.dig_down_to(Vector2i(here.x, from_surface + DELVE_ROWS), 2400, true)
	var landed: Vector2i = main._cell_at(agent.player.position)
	var reached: int = landed.y - from_surface
	var c: Vector2i = main._cell_at(agent.player.position)
	var left: int = c.x - ROOM_W / 2
	for dy: int in range(-ROOM_H + 1, 1):
		for dx: int in range(ROOM_W):
			main.sim.mine(Vector2i(left + dx, c.y + dy))
		await physics_frame
	main._renderer.repaint_world()
	for _i: int in 30:
		await physics_frame
	return reached
