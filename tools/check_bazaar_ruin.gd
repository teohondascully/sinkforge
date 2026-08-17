extends "res://tools/check_base.gd"

## THE FIRST THING THE WORLD ASKS YOU TO BUILD HAS TO LOOK LIKE A THING.
##
## Worldgen stamps an almost-complete bazaar beside spawn — the frame minus its bottom-right post — and
## finishing it is the game's first build lesson and its first piece of lore. But "bazaar" was defined
## only as COMPLETE (FactorySim.is_bazaar_at), the view drew only what the sim called a bazaar, and so the
## ruin drew NOTHING. The first landmark a player walks up to was four loose wood blocks on flat ground,
## with no indication that it was a structure, that it was unfinished, or that one block would finish it.
##
## This layer holds the two halves of the repair:
##
##   THE SIM CAN SEE AN UNFINISHED ONE.  find_bazaar_ruins reports frames that are exactly one wood block
##                                       short, and the claim it makes is strict — place one block HERE
##                                       and it activates. Anything weaker would put a "finish me" marker
##                                       on rubble, which is worse than drawing nothing.
##   THE VIEW IS LOOKING AT THEM.        Bazaars.update feeds its ruin list from the sim, so draw() can
##                                       dress them. The pixels themselves are a windowed concern; what is
##                                       checkable here is that the view holds the right set.
##
## The strictness cases are the point. A hole with stone in it is not one block short — you would have to
## dig first — and a frame missing two blocks is not one block short. Both are near-misses that a sloppy
## predicate reports, and both would light up a marker the player cannot act on.
##
##   godot --headless --path . --script res://tools/check_bazaar_ruin.gd

const W: int = FactorySim.BAZAAR_W
const H: int = FactorySim.BAZAAR_H


## Counts what draw() decides to dress, without painting anything.
##
## Holding the right list is not the same as drawing it, and the ORIGINAL bug was precisely a draw loop
## that ignored a collection sitting right there. Overriding the two paint helpers means draw() runs its
## real control flow while making no canvas calls at all, so this works headless and needs no window: if
## someone deletes the ruin loop from draw(), `ruins` stays 0 and this layer goes red.
class Spy extends Bazaars:
	var ruins: int = 0
	var stalls: int = 0

	func _draw_ruin(_canvas: CanvasItem, _origin: Vector2i, _gap: Vector2i) -> void:
		ruins += 1

	func _draw_bazaar(_canvas: CanvasItem, _origin: Vector2i, _age: float) -> void:
		stalls += 1

func _initialize() -> void:
	print("== the bazaar you have not finished yet ==")
	_shipping_world()
	_strictness()
	_view_wiring()
	if _failures == 0:
		print("check_bazaar_ruin: PASS — the unfinished stall is a thing the game can see and point at")
		quit(0)
	else:
		printerr("check_bazaar_ruin: FAIL (%d)" % _failures)
		quit(1)


# --- the world a player actually gets ----------------------------------------------------------------

func _shipping_world() -> void:
	var gen: WorldGen = LayeredWorldGen.new()
	var sim := FactorySim.new()
	sim.load_world(gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, MainView.WORLD_SEED))

	var ruins: Array[Dictionary] = sim.find_bazaar_ruins()
	# NON-VACUITY. Every assertion below this line is about a ruin; if the shipping world has none, they
	# all pass by having nothing to disagree with. This is the guard that makes the rest mean something.
	_check(ruins.size() == 1,
		"the shipping world stamps exactly ONE unfinished bazaar (found %d)" % ruins.size())
	if ruins.is_empty():
		return

	_check(sim.find_bazaars().is_empty(),
		"...and it is NOT yet a bazaar, so nothing but this layer could see it before now")

	var origin: Vector2i = ruins[0]["origin"]
	var gap: Vector2i = ruins[0]["gap"]
	_check(not sim.solid.has(gap),
		"the missing cell is genuinely EMPTY — a block goes straight in, nothing to dig first")
	var rel: Vector2i = gap - origin
	_check(rel.y == 0 or rel.x == 0 or rel.x == W - 1,
		"...and it is a FRAME cell (rel %s), not a hole in the interior you walk through" % rel)

	# The transition the whole feature exists for: one block, and the ruin becomes the stall.
	sim.inventory[&"wood"] = int(sim.inventory.get(&"wood", 0)) + 1
	var placed: bool = sim.place_block(gap, &"wood")
	_check(placed, "one wood block goes into the gap")
	_check(sim.find_bazaars().has(origin),
		"...and the frame is now a live bazaar at the same origin")
	# This also covers phantoms: a finished frame has near-miss windows all around it (shift the window one
	# column and most of the wood is still in the right places), and any of those reading as "one block
	# short" would float a finish-me marker beside a stall that is already done.
	_check(sim.find_bazaar_ruins().is_empty(),
		"...and nothing is left listed as unfinished — the marker goes away, and casts no phantom beside it")

	# ...and it survives being taken apart again: mine the post back out and the marker returns.
	sim.mine(gap)
	var again: Array[Dictionary] = sim.find_bazaar_ruins()
	_check(again.size() == 1 and again[0]["gap"] == gap,
		"break it again and it is once more one block short (the cache is not stale)")


# --- what must NOT be called one block short ---------------------------------------------------------

## Lay a frame at `o` in an empty sim, omitting every cell in `holes`, and answer what the sim makes of it.
func _frame(holes: Array[Vector2i], stone_holes: Array[Vector2i] = []) -> Dictionary:
	var sim := FactorySim.new()
	var o := Vector2i(20, 20)
	var cells: Array[Vector2i] = []
	for dx: int in W:
		cells.append(o + Vector2i(dx, 0))                        # top beam
	for dy: int in range(1, H):
		cells.append(o + Vector2i(0, dy))                        # posts
		cells.append(o + Vector2i(W - 1, dy))
	for c: Vector2i in cells:
		var rel: Vector2i = c - o
		if holes.has(rel) or stone_holes.has(rel):
			continue
		sim.solid[c] = &"wood"
	for rel2: Vector2i in stone_holes:
		sim.solid[o + rel2] = &"stone"                           # occupied, but not with wood
	for ix: int in range(1, W - 1):
		sim.solid[o + Vector2i(ix, H)] = &"earth"                # interior floor: real ground
	sim._bazaars_dirty = true
	return {"sim": sim, "origin": o}


func _strictness() -> void:
	var one: Dictionary = _frame([Vector2i(W - 1, H - 1)])
	var one_sim: FactorySim = one["sim"]
	_check(one_sim.find_bazaar_ruins().size() == 1,
		"a frame missing one post IS one block short (the control — without this the rest is vacuous)")

	var two: Dictionary = _frame([Vector2i(W - 1, H - 1), Vector2i(0, 1)])
	var two_sim: FactorySim = two["sim"]
	_check(two_sim.find_bazaar_ruins().is_empty(),
		"a frame missing TWO blocks is not one block short — no marker on something you cannot finish")

	var blocked: Dictionary = _frame([], [Vector2i(W - 1, H - 1)])
	var blocked_sim: FactorySim = blocked["sim"]
	_check(blocked_sim.find_bazaar_ruins().is_empty(),
		"a hole with STONE in it is not one block short — you would have to dig it out first")

	var whole: Dictionary = _frame([])
	var whole_sim: FactorySim = whole["sim"]
	_check(whole_sim.find_bazaars().size() == 1 and whole_sim.find_bazaar_ruins().is_empty(),
		"a COMPLETE frame is a bazaar and is not also a ruin")

	# The interior is the part you walk into; a frame with the doorway bricked up is not a stall that
	# needs one more block, it is a solid box.
	var stuffed: Dictionary = _frame([Vector2i(W - 1, H - 1)])
	var stuffed_sim: FactorySim = stuffed["sim"]
	stuffed_sim.solid[(stuffed["origin"] as Vector2i) + Vector2i(1, 1)] = &"stone"
	stuffed_sim._bazaars_dirty = true
	_check(stuffed_sim.find_bazaar_ruins().is_empty(),
		"...and a frame whose INTERIOR is filled in is not one block short either")


# --- the view is looking at the right set ------------------------------------------------------------

func _view_wiring() -> void:
	var gen: WorldGen = LayeredWorldGen.new()
	var sim := FactorySim.new()
	sim.load_world(gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, MainView.WORLD_SEED))
	var view := Bazaars.new()
	view.update(sim, 0.016)
	# draw() reads `_ruins`; update() is the only thing that fills it. The regression this catches is the
	# original bug exactly — a draw loop iterating a collection that only ever holds FINISHED frames.
	_check(view._ruins.size() == sim.find_bazaar_ruins().size() and not view._ruins.is_empty(),
		"one update and the view holds the unfinished frames it is meant to dress (%d)" % view._ruins.size())
	_check((view._ruins[0]["gap"] as Vector2i) == (sim.find_bazaar_ruins()[0]["gap"] as Vector2i),
		"...and the gap it will mark is the gap the sim reported")

	# ...and it DRAWS them. The two assertions above would both pass over the original bug, because the
	# view held the list correctly and the draw loop simply never looked at it.
	var spy := Spy.new()
	spy.update(sim, 0.016)
	spy.draw(null)
	_check(spy.ruins == 1,
		"draw() dresses the unfinished frame (%d) — the bug was a loop that had the list and ignored it"
			% spy.ruins)
	_check(spy.stalls == 0,
		"...and does not draw it as a finished stall, which is the thing it is not yet")
