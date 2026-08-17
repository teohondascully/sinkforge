extends "res://tools/check_base.gd"

## DOES A DUG ROOM READ AS A ROOM? — the lighting law behind the game's oldest complaint, pinned.
##
## The renderer had every depth cue you would want (a recessed back-wall plane, cast shadows on it,
## carved edges, a hue shift between the planes) sitting on top of a veil that gave BURIED ROCK AND OPEN
## SPACE THE SAME LIGHT, because the light level was a pure function of row. Measured on a 13x7 chamber
## with two torches in it, the back wall printed at luma 0.142 against 0.117 for the surrounding stone —
## a 1.2x separation, which no eye reads as space. Every cue above it was arguing with the lighting.
##
## MASS_SHADE fixed it upstream: light does not travel through stone, so a cell buried in rock is dimmer
## than one at an opening, smoothly, over MASS_REACH cells. That single change is what makes a carved
## chamber visible AS a chamber, so it is the thing most worth defending against a future re-grade.
##
## Asserted here, straight off the baked veil rather than off a screenshot:
##   1. an open chamber is decisively brighter than the mass around it (the whole point)
##   2. rock at the chamber's EDGE keeps most of its light — a face you are looking at is not a void
##   3. it is a GRADIENT, not a cliff: brightness falls monotonically from the opening into the mass
##   4. open cells are never dimmed — the deep's own ambient still describes them, unchanged
##   5. the surface still reads: ground under open sky is far brighter than ground a few rows down

const SCENE: String = "res://scenes/main.tscn"
const ROOM_W: int = 13
const ROOM_H: int = 7
## How much brighter open space must be than deep mass IN THE VEIL. Deep mass sits at `1 - MASS_SHADE`
## with the KEY contributing nothing (it brightens up-facing FACES, which is a different cell than this
## ratio is about), so the achievable contrast is `1/(1 - MASS_SHADE)` and nothing else.
##
## THIS COMMENT USED TO SAY THE KEY RAISED THAT CEILING AND THAT THE PAIR MEASURED 2.21x. Both were wrong,
## and the floor sat ABOVE the model's structural maximum of 1.85x for as long as it has existed. It went
## green regardless because the reading sampled a single cell, so the material's own tone rode along with
## the lighting — a dark stone read 39 where lighting alone predicts 46. The median (below) removes the
## tone lottery and reported the truth: 1.87x, against a floor of 2.0. MASS_SHADE moved 0.46 → 0.55 in
## response, because the floor was right about what the game needs and the renderer was not delivering it.
## Now 2.26x measured against a 2.22x construction cap.
##
## What the eye finally receives is larger again (3.5x, measured off a torch-lit capture) because the
## back-wall plane has its own paint over this. The guard is against the terms being weakened, not a claim
## about the finished picture.
const CONTRAST_FLOOR: float = 2.0
const MASS_STEPS: int = 4            ## how far into the rock the gradient is walked

var _main: MainView
var _frames: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	MainView.dev_start = true
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== does a dug room read as a room ==")
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frames += 1
	if _frames < 4:
		return
	process_frame.disconnect(_on_frame)
	_run()
	if _failures == 0:
		print("check_room_reads: PASS")
		quit(0)
	else:
		print("check_room_reads: FAIL (%d)" % _failures)
		quit(1)


## A column where this fixture actually means something, searched outward from the middle so the shipping
## seed keeps the site it has always used when that site is valid. Requirements, all of them things the
## readings below silently depended on before:
##   - the whole chamber block is SOLID, so we carve a room out of mass rather than widening a cave;
##   - the column under it stays solid past the deepest sample (the face, the gradient walk, the mass ref),
##     so "buried mass" is buried mass;
##   - the comparison shaft 20 columns over is solid too, so its open cells are open for the same reason.
## Returns -1 when no such column exists — which is a finding to report, not a thing to paper over.
## Searches DEPTH as well as column. The layer's requirement is "deep enough that no skylight reaches it";
## row 44 was one fixture's way of spelling that, not part of the property, and pinning it threw away three
## corpus seeds that simply had their solid mass at another depth. Depth is searched from CY_MIN downward
## so the shipping seed keeps the site it has always had.
func _mass_site(sim: FactorySim, cy_start: int) -> Vector2i:
	var mid: int = FactorySim.GRID_COLS / 2
	for cy: int in range(cy_start, FactorySim.GRID_ROWS - ROOM_H - maxi(MASS_STEPS, 6)
			- WorldRenderer.MASS_REACH - 1):
		var deepest: int = cy + ROOM_H + maxi(MASS_STEPS, 6)
		for off: int in range(0, FactorySim.GRID_COLS):
			for dir: int in [1, -1]:
				var cx: int = mid + dir * off
				if cx - ROOM_W / 2 < 1 or cx + 21 >= FactorySim.GRID_COLS:
					continue
				if _buried(sim, cx, cy, deepest):
					return Vector2i(cx, cy)
				if off == 0:
					break   # +0 and -0 are the same column
	return Vector2i(-1, -1)


## Is a chamber at (cx, cy) genuinely buried, with solid mass under it and under its comparison shaft?
##
## "Buried" is not this layer's opinion — it is WorldRenderer.MASS_REACH's. Light bleeds MASS_REACH cells
## into the mass, so a sample with any pre-existing void within that radius is only partly shaded and reads
## far brighter than buried rock. The arithmetic is checkable rather than asserted: a fully-buried cell
## keeps MASS_SHADE (0.46) of open light, and on seed 1337 the mass reference reads 41 against an open 86
## — 0.48, a buried cell. On a seed where the reference sits beside a cave it read 67, 0.78, and the layer
## blamed the LIGHTING for correctly brightening rock next to a void. So the sampled column is required to
## be solid out to MASS_REACH either side, and MASS_REACH past the deepest sample.
##
## Note this deliberately does NOT require distance from the chamber we are about to carve: the chamber's
## own influence on the cells beneath it is the signal every reading here exists to measure.
func _buried(sim: FactorySim, cx: int, cy: int, deepest: int) -> bool:
	var reach: int = WorldRenderer.MASS_REACH
	# Every cell this layer SAMPLES, plus the radius light bleeds through, must be solid rock before we
	# carve. That is the whole precondition and it is deliberately no wider: demanding the full 13x7 block
	# be pre-solid as well rejected entire worlds (two corpus seeds had no such column anywhere), and "no
	# site" is not evidence about lighting — it is just a fixture that asked for too much.
	for y: int in range(cy, deepest + reach + 1):
		for dx: int in range(-reach, reach + 1):
			if not sim.is_solid(Vector2i(cx + dx, y)):
				return false
	# The comparison shaft is dug in the same way and must be open for the same reason, not because it
	# happened to be a cave already.
	for dy: int in range(ROOM_H):
		if not sim.is_solid(Vector2i(cx + 20, cy + dy)):
			return false
	return true


## Median light over the (2*MASS_REACH+1)² block centred on `cell`. Every cell in it is inside the region
## _buried() verified solid, so this is all genuinely buried mass and nothing here reaches into a void.
func _median_light(r: WorldRenderer, cell: Vector2i) -> float:
	var reach: int = WorldRenderer.MASS_REACH
	var vals: Array[float] = []
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			vals.append(_light(r, cell.x + dx, cell.y + dy))
	vals.sort()
	return vals[vals.size() / 2]


func _run() -> void:
	var sim: FactorySim = _main.sim
	var r: WorldRenderer = _main._renderer
	# Cut a chamber deep enough that no skylight reaches it, in a column with plenty of rock either side,
	# then re-bake. sim.mine (not try_mine) — reach is a gameplay rule and this is a lighting fixture.
	var cy: int = 44
	# THE FIXTURE HAS PRECONDITIONS AND THEY MUST BE CHECKED, NOT ASSUMED. Every reading below compares an
	# open cell against BURIED MASS in the column under the chamber. This layer used to carve at the middle
	# column and simply trust that the rock below it was rock. On seed 1337 it is. Across a seed corpus it
	# frequently is not: the "mass" sample lands in a cave and reads as lit open space, so the contrast
	# assertion compares 86 against 86 and reports the LIGHTING as broken when the fixture was never valid.
	# Measured 2026-08-17: 7 of 8 corpus seeds failed this way. Find a real site instead of hoping for one.
	var site: Vector2i = _mass_site(sim, cy)
	_check(site.x >= 0, "found a genuinely buried chamber site %s" % site)
	if site.x < 0:
		return   # nothing below can mean anything; do not print six readings taken from nowhere
	var cx: int = site.x
	cy = site.y
	for dy: int in range(ROOM_H):
		for dx: int in range(ROOM_W):
			sim.mine(Vector2i(cx - ROOM_W / 2 + dx, cy + dy))
	r._bake_veil_base()

	# 1. THE POINT. An open cell in the middle of the chamber against solid rock well away from it.
	var room: float = _light(r, cx, cy + ROOM_H / 2)
	var mass_cell: Vector2i = Vector2i(cx, cy + ROOM_H + 6)
	var one: float = _light(r, cx, mass_cell.y)
	# MEASURE THE MASS, NOT ONE TEXEL OF IT. Sampling a single cell made this reading a draw from the
	# per-cell tone noise: across a seed corpus the same material at the same row read 39, 44 and 46 — a
	# ~9% spread with the 2.0 floor sitting inside it, so the verdict depended on which cell the fixture
	# happened to land on. The median over the 5x5 block the site search already PROVED is buried is the
	# same claim ("how dark is buried mass") with the noise taken out; it is not a weaker one, and the
	# floor is deliberately unchanged. Both numbers are printed so the two can never be conflated again.
	var mass: float = _median_light(r, mass_cell)
	_check(room >= mass * CONTRAST_FLOOR,
		"open chamber reads %.2fx brighter than buried mass (%.0f vs %.0f median, %.0f at the single cell, "
			% [room / mass, room, mass, one] + "mass is %s)" % sim.material_at(mass_cell))

	# 2. THE FACE. The first rock cell under the chamber floor is the surface you are looking AT; if the
	#    occlusion crushed it, every wall in the game would be a silhouette instead of a lit rock face.
	var face: float = _light(r, cx, cy + ROOM_H)
	_check(face >= room * 0.70,
		"the chamber's own rock face keeps %.0f%% of the open light" % [face / room * 100.0])

	# 3. A GRADIENT, NOT A CLIFF. Walking the same column down from the floor into the mass, light must
	#    fall every step and never jump back up — a hard edge would print as a painted black band.
	var prev: float = face
	var monotone: bool = true
	var steps: Array[String] = []
	for d: int in range(1, MASS_STEPS + 1):
		var here: float = _light(r, cx, cy + ROOM_H + d)
		steps.append("%.0f" % here)
		if here > prev + 0.5:
			monotone = false
		prev = here
	_check(monotone, "light falls smoothly into the mass (%.0f -> %s)" % [face, " -> ".join(steps)])
	_check(prev < face, "...and is genuinely darker %d cells in (%.0f -> %.0f)"
		% [MASS_STEPS, face, prev])

	# 4. OPEN CELLS ARE UNTOUCHED. Two open cells at the same row — one in the chamber, one in a shaft
	#    dug beside it — must read identically: openness only ever dims ROCK.
	for dy: int in range(ROOM_H):
		sim.mine(Vector2i(cx + 20, cy + dy))
	r._bake_veil_base()
	var other: float = _light(r, cx + 20, cy + ROOM_H / 2)
	_check(absf(other - room) <= 1.0,
		"open cells are never dimmed by the mass term (%.0f vs %.0f)" % [other, room])

	# 5. THE SURFACE STILL READS. Ground right under open sky must stay far brighter than ground a few
	#    rows into the earth, or the opening frame turns into a black band under the grass.
	var surf: int = sim.surface_row(cx)
	var top: float = _light(r, cx, surf)
	var under: float = _light(r, cx, surf + 6)
	_check(top > under * 1.5, "the surface still reads as lit ground (%.0f vs %.0f six rows down)"
		% [top, under])


## The baked veil's red channel at a cell — the light level the multiply layer will apply there.
func _light(r: WorldRenderer, col: int, row: int) -> float:
	return float(r._veil_base[(row * FactorySim.GRID_COLS + col) * 4])
