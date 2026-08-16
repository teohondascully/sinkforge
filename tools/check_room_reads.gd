extends SceneTree

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
## How much brighter open space must be than deep mass IN THE VEIL. The mass term alone caps out at
## 1/(1 - MASS_SHADE) = 1.85x by construction; the KEY (#S8) raises the ceiling by brightening up-facing
## mass on top of that, and the pair measure 2.21x here. What the eye finally receives is larger again
## (3.5x, measured off a torch-lit capture) because the back-wall plane has its own paint over this. The
## guard is against the terms being weakened, not a claim about the finished picture.
const CONTRAST_FLOOR: float = 2.0
const MASS_STEPS: int = 4            ## how far into the rock the gradient is walked

var _main: MainView
var _frames: int = 0
var _fails: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	MainView.dev_start = true
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== does a dug room read as a room ==")
	process_frame.connect(_on_frame)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_fails += 1
		printerr("  FAIL: %s" % label)


func _on_frame() -> void:
	_frames += 1
	if _frames < 4:
		return
	process_frame.disconnect(_on_frame)
	_run()
	if _fails == 0:
		print("check_room_reads: PASS")
		quit(0)
	else:
		print("check_room_reads: FAIL (%d)" % _fails)
		quit(1)


func _run() -> void:
	var sim: FactorySim = _main.sim
	var r: WorldRenderer = _main._renderer
	# Cut a chamber deep enough that no skylight reaches it, in a column with plenty of rock either side,
	# then re-bake. sim.mine (not try_mine) — reach is a gameplay rule and this is a lighting fixture.
	var cx: int = FactorySim.GRID_COLS / 2
	var cy: int = 44
	for dy: int in range(ROOM_H):
		for dx: int in range(ROOM_W):
			sim.mine(Vector2i(cx - ROOM_W / 2 + dx, cy + dy))
	r._bake_veil_base()

	# 1. THE POINT. An open cell in the middle of the chamber against solid rock well away from it.
	var room: float = _light(r, cx, cy + ROOM_H / 2)
	var mass: float = _light(r, cx, cy + ROOM_H + 6)
	_check(room >= mass * CONTRAST_FLOOR,
		"open chamber reads %.2fx brighter than buried mass (%.0f vs %.0f)" % [room / mass, room, mass])

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
