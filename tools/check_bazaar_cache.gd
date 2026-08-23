extends "res://tools/check_base.gd"

## THE BAZAAR CACHE MUST AGREE WITH THE WORLD AFTER EVERY WAY THE WORLD CAN CHANGE.
##
## `find_bazaars()` and `find_bazaar_ruins()` are served from a cache that a full-grid rescan refills when
## `_bazaars_dirty` is set. Every write to `solid` is therefore load-bearing twice: once for the world, and
## once for the flag. A write that forgets the flag does not fail, crash or slow anything down — it makes
## the game answer a question about a structure that is not there any more.
##
## THE DEFECT THIS WAS WRITTEN FOR WAS LIVE IN SHIPPING CODE, AND REACHABLE THROUGH AN ORDINARY VERB.
## `Flora.grow` stamps a tree trunk straight into `sim.solid` and set no flag. Plant a sapling in your
## bazaar's open interior — nothing stops you, `can_plant_sapling` asks only for empty ground on soil —
## and two minutes later the trunk closes the interior. `is_bazaar_at` answers false; `find_bazaars()` went
## on returning the origin. The stall stays drawn, the near-bazaar craft gate stays open, and the game
## corrects itself only when some unrelated dig happens to invalidate the cache. The mirror is worse: a
## trunk growing into a ruin's one missing cell COMPLETES a bazaar nobody has been told about.
##
## SO THE ASSERTION IS BEHAVIOURAL AND NOT A SOURCE SCAN. A gate that greps for `_bazaars_dirty` beside
## every `solid[` write would have missed this one anyway — the write is in another file, through a
## reference the grep would have to know to follow — and it would pass a write that sets the flag in a
## branch that is not taken. What is checked here is the only thing that matters: after each way the world
## changes, does the cached answer equal a scan of the world as it now is.
##
## THE CONTROL IS BRUTE FORCE AND IT TRAVELS INSIDE EVERY CASE. `_truth()` walks the whole grid calling
## `is_bazaar_at` and `bazaar_gap_at`, ignoring the cache entirely, and every case compares against it. If
## the two agreed because both were empty the case would prove nothing, so each one also asserts what it
## expects the world to hold — a case that measures nothing is the house defect, not a passing case.
##
##   godot --headless --script res://tools/check_bazaar_cache.gd

const Flora := preload("res://src/core/flora.gd")

## Somewhere with room around it, well away from the grid edges so a 4x4 window and a canopy both fit.
const AT := Vector2i(40, 40)


func _initialize() -> void:
	_grows_into_a_bazaar()
	_grows_inside_a_bazaar()
	_mined()
	_placed()
	_set_solid()
	_loaded()
	_verdict("check_bazaar_cache",
		"the cached answer matches a full scan after growth, mining, placing, set_solid and a world load")


## THE MIRROR OF THE SHIPPED DEFECT, AND THE MORE DANGEROUS DIRECTION. A ruin one wood short, with a
## sapling in the gap. The trunk fills it and the frame becomes a bazaar; before the fix the cache said
## there were none.
func _grows_into_a_bazaar() -> void:
	var sim: FactorySim = _ruin(AT, AT + Vector2i(FactorySim.BAZAAR_W - 1, FactorySim.BAZAAR_H - 1))
	# The gap's own floor, so the sapling has soil under it. Outside the interior, so the frame is
	# unaffected by it.
	sim.solid[AT + Vector2i(FactorySim.BAZAAR_W - 1, FactorySim.BAZAAR_H)] = &"earth"
	_check(_truth(sim)["bazaars"].is_empty(), "the fixture starts as a ruin and not as a bazaar")
	_check(sim.find_bazaars().is_empty(), "...and the cache agrees before anything grows")
	_plant_and_grow(sim, AT + Vector2i(FactorySim.BAZAAR_W - 1, FactorySim.BAZAAR_H - 1))
	_agrees(sim, "a tree grew into the ruin's missing cell")
	_check(not _truth(sim)["bazaars"].is_empty(),
		"...and the case is live: the frame really did complete (%d bazaar(s))" % _truth(sim)["bazaars"].size())


## THE SHIPPED DEFECT ITSELF. A whole bazaar, a sapling in its open interior, and the trunk that closes it.
func _grows_inside_a_bazaar() -> void:
	var sim: FactorySim = _bazaar(AT)
	_check(sim.find_bazaars().has(AT), "the fixture starts as a bazaar, and the cache is warm on it")
	_plant_and_grow(sim, AT + Vector2i(1, FactorySim.BAZAAR_H - 1))
	_agrees(sim, "a tree grew inside the frame and closed its interior")
	_check(_truth(sim)["bazaars"].is_empty(),
		"...and the case is live: the frame really did stop being a bazaar")


func _mined() -> void:
	var sim: FactorySim = _bazaar(AT)
	_check(sim.find_bazaars().has(AT), "the fixture starts as a bazaar (mining case)")
	sim.mine(AT, false)                                    # a top-beam corner: the frame breaks
	_agrees(sim, "a frame cell was mined out")
	_check(_truth(sim)["bazaars"].is_empty(), "...and the case is live: mining really did break it")


func _placed() -> void:
	var sim: FactorySim = _ruin(AT, AT + Vector2i(FactorySim.BAZAAR_W - 1, FactorySim.BAZAAR_H - 1))
	_check(sim.find_bazaars().is_empty(), "the fixture starts as a ruin (placing case)")
	sim.inventory[&"wood"] = 1
	var gap: Vector2i = AT + Vector2i(FactorySim.BAZAAR_W - 1, FactorySim.BAZAAR_H - 1)
	_check(sim.place_block(gap, &"wood"), "the missing post can be placed")
	_agrees(sim, "the missing post was placed")
	_check(not _truth(sim)["bazaars"].is_empty(), "...and the case is live: placing really did complete it")


func _set_solid() -> void:
	var sim: FactorySim = _bazaar(AT)
	_check(sim.find_bazaars().has(AT), "the fixture starts as a bazaar (set_solid case)")
	sim.set_solid(AT + Vector2i(1, 1), &"stone")           # rock in the interior: no longer open
	_agrees(sim, "set_solid filled the interior")
	_check(_truth(sim)["bazaars"].is_empty(), "...and the case is live: the interior really did close")


## A LOAD IS A BULK WRITE AND IT USED TO LEAVE THE FLAG TO ITS CALLER. `main.gd` got away with that by
## loading into a fresh sim, whose flag starts dirty, so the miss was invisible from the only path anybody
## exercised. This loads into a sim whose cache is ALREADY WARM on a different world, which is the case
## that separates "load_world invalidates" from "nobody has tried".
func _loaded() -> void:
	var sim: FactorySim = _bazaar(AT)
	_check(sim.find_bazaars().has(AT), "the fixture starts as a bazaar, cache warm (load case)")
	var world := WorldData.new()
	world.seed = 12345
	world.blocks = {}
	world.walls = {}
	world.amounts = {}
	sim.load_world(world)
	_agrees(sim, "an empty world was loaded over a warm cache")
	_check(_truth(sim)["bazaars"].is_empty(), "...and the case is live: the loaded world holds no bazaar")


## Plant a sapling one tick short of sprouting and run the growth pass. Not `plant_sapling`, which spends
## an inventory sapling and asks questions this fixture has already answered; the subject is the growth
## write, and `Flora.grow` is what the sim calls every tick.
func _plant_and_grow(sim: FactorySim, cell: Vector2i) -> void:
	sim.sapling[cell] = FactorySim.SAPLING_GROW_TICKS - 1
	_check(FactorySim.SAPLING_SOILS.has(sim.solid.get(cell + Vector2i(0, 1), &"")),
		"the sapling at %s has soil under it, so it will actually grow" % cell)
	Flora.grow(sim)
	_check(sim.solid.get(cell, &"") == &"wood", "...and it grew: %s is wood now" % cell)


## The whole grid, scanned without the cache. This is the control, and it travels inside every case.
func _truth(sim: FactorySim) -> Dictionary:
	var bazaars: Array[Vector2i] = []
	var ruins: Array[Vector2i] = []
	for y: int in range(0, FactorySim.GRID_ROWS - FactorySim.BAZAAR_H):
		for x: int in range(0, FactorySim.GRID_COLS - FactorySim.BAZAAR_W + 1):
			var o := Vector2i(x, y)
			if sim.is_bazaar_at(o):
				bazaars.append(o)
			elif sim.bazaar_gap_at(o).x >= 0:
				ruins.append(o)
	return {"bazaars": bazaars, "ruins": ruins}


## Both cached answers against both scanned ones, as SETS of origins rather than as counts. Two lists of
## the same length can name different cells, and a count would call that agreement.
func _agrees(sim: FactorySim, what: String) -> void:
	var truth: Dictionary = _truth(sim)
	var cached_b: Array[Vector2i] = sim.find_bazaars().duplicate()
	var cached_r: Array[Vector2i] = []
	for d: Dictionary in sim.find_bazaar_ruins():
		cached_r.append(d["origin"])
	cached_b.sort()
	cached_r.sort()
	var truth_b: Array[Vector2i] = truth["bazaars"]
	var truth_r: Array[Vector2i] = truth["ruins"]
	truth_b.sort()
	truth_r.sort()
	_check(cached_b == truth_b, "the bazaars the cache names are the bazaars in the world after %s"
		% what + " (cache %s, world %s)" % [cached_b, truth_b])
	_check(cached_r == truth_r, "...and so are the ruins after %s (cache %s, world %s)"
		% [what, cached_r, truth_r])


## A complete bazaar at `o`: wood top beam, wood posts, open interior, earth under the interior.
func _bazaar(o: Vector2i) -> FactorySim:
	var sim := FactorySim.new()
	for dx: int in FactorySim.BAZAAR_W:
		sim.solid[o + Vector2i(dx, 0)] = &"wood"
	for dy: int in range(1, FactorySim.BAZAAR_H):
		sim.solid[o + Vector2i(0, dy)] = &"wood"
		sim.solid[o + Vector2i(FactorySim.BAZAAR_W - 1, dy)] = &"wood"
	for ix: int in range(1, FactorySim.BAZAAR_W - 1):
		sim.solid[o + Vector2i(ix, FactorySim.BAZAAR_H)] = &"earth"
	sim.invalidate_bazaars()
	return sim


## The same frame with `missing` left out: one wood short, which is what `bazaar_gap_at` calls a ruin.
func _ruin(o: Vector2i, missing: Vector2i) -> FactorySim:
	var sim: FactorySim = _bazaar(o)
	sim.solid.erase(missing)
	sim.invalidate_bazaars()
	return sim
