extends "res://tools/check_base.gd"

## THE ROCK HAS TO TELL YOU, AND IT HAS TO BE TELLING THE TRUTH.
##
## The generator fills this world with caverns, halls, rifts, veins and aquifers, and none of it existed
## until the player physically walked into it: every block was broken blind, so digging was a chore rather
## than a search. The hollow ring is the fix — a face with a cavity behind it answers the pick differently,
## which is the oldest skill in mining and the single best piece of information a game like this can give
## away for free.
##
## A tell is only worth having if it is HONEST, and honest has two halves that fail in opposite directions:
##
##   IT FIRES     — approach a void through solid rock and the reading must climb, well before the face
##                  breaks. A tell that only arrives at the last cell is not a tell, it is a result.
##   IT IS QUIET  — deep inside a solid mass, with nothing anywhere near, it must read ~0. A tell that
##                  fires everywhere is noise, and worse than none: the player learns to ignore it, and
##                  then it is dead weight the moment it would have mattered.
##
## Both are measured on a hand-built fixture rather than on generated terrain, because "how far from the
## void" has to be exact for the numbers to mean anything.

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 30

## Where the fixture lives — deep enough to be past the surface scatter and any generated relief.
const ROW: int = 70
const COL: int = 40
const VOID_W: int = 9
const VOID_H: int = 5

## The reading must climb to this within TELL_LEAD cells of the void — far enough out that a player has
## time to decide something, which is the whole point of a tell.
const TELL_LEAD: int = 3
const TELL_FLOOR: float = 0.30

## ...and this is the most a face may read with nothing but rock for a dozen cells in every direction.
const QUIET_CEIL: float = 0.02

## The break beat fires above this, and it must be reachable: a payoff you cannot actually trigger by
## digging at a real cave is a payoff that does not exist.
const BREACH_REACHABLE: float = 0.45

func _initialize() -> void:
	print("== the rock tells you what is behind it ==")
	MainView.dev_start = false
	await _run()
	if _failures == 0:
		print("check_tells: PASS — the tell rises on approach and stays silent in solid rock")
		quit(0)
	else:
		print("check_tells: FAIL (%d)" % _failures)
		quit(1)


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var sim: FactorySim = main.sim

	# Solid rock everywhere around the fixture, then one clean rectangular void inside it. Hand-built, so
	# "four cells from the wall" means exactly four cells.
	# The solid margin has to exceed the quiet scan's own reach, or the test measures the generated world
	# outside the fixture and reports honest caves as false positives — which it duly did.
	for c: int in range(COL - 24, COL + VOID_W + 24):
		for r: int in range(ROW - 20, ROW + VOID_H + 20):
			sim.set_solid(Vector2i(c, r), &"stone")
	for c: int in range(COL, COL + VOID_W):
		for r: int in range(ROW, ROW + VOID_H):
			sim.set_solid(Vector2i(c, r), &"")

	# 1. APPROACHING. Walk a face toward the void's left wall and read at each step. The pick swings
	#    rightward (+X), which is the direction the reading is biased along.
	var dir := Vector2i(1, 0)
	var mid: int = ROW + VOID_H / 2
	var readings: Array[float] = []
	for d: int in range(8, 0, -1):
		readings.append(main._hollow_at(Vector2i(COL - d, mid), dir))
	print("  approach (8 cells out → 1): %s"
		% ", ".join(readings.map(func(v: float) -> String: return "%.2f" % v)))

	var lead: float = readings[readings.size() - TELL_LEAD]        # TELL_LEAD cells from the wall
	_check(lead >= TELL_FLOOR,
		"the tell is up %d cells out (%.2f, floor %.2f)" % [TELL_LEAD, lead, TELL_FLOOR])

	var rising: bool = true
	for i: int in range(1, readings.size()):
		if readings[i] < readings[i - 1] - 0.001:
			rising = false
	_check(rising, "...and it only ever climbs on approach (no false peak to walk away from)")

	_check(readings[readings.size() - 1] >= BREACH_REACHABLE,
		"the last face before the void clears the breach beat (%.2f >= %.2f)"
		% [readings[readings.size() - 1], BREACH_REACHABLE])

	# 2. QUIET. The same reading in the middle of a solid mass, in all four swing directions — a tell that
	#    fires while you are digging plain rock is worse than no tell at all.
	var loud: float = 0.0
	var where: String = ""
	for c: int in range(COL - 14, COL - 8):
		for r: int in range(mid - 4, mid + 5):
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var v: float = main._hollow_at(Vector2i(c, r), d)
				if v > loud:
					loud = v
					where = "(%d,%d) dir %s" % [c, r, str(d)]
	_check(loud <= QUIET_CEIL,
		"solid rock says nothing (loudest %.2f at %s, ceiling %.2f)" % [loud, where, QUIET_CEIL])

	# 3. IT IS DIRECTIONAL. Standing beside the void but swinging AWAY from it must read far lower than
	#    swinging into it — otherwise the tell is about where you are, not about where you are digging,
	#    and it would ring while you cut the opposite wall of your own shaft.
	var into: float = main._hollow_at(Vector2i(COL - 2, mid), Vector2i(1, 0))
	var away: float = main._hollow_at(Vector2i(COL - 2, mid), Vector2i(-1, 0))
	_check(away < into * 0.5,
		"it answers the swing, not the standing spot (into %.2f vs away %.2f)" % [into, away])
