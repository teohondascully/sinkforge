extends "res://tools/check_base.gd"

## VEINS GROW INTO ROCK. THEY DO NOT FILL THE HOLES YOU ARE MEANT TO WALK THROUGH.
##
## `LayeredWorldGen._grow_vein` accretes a blob outward from a seed cell and skips any cell that is not
## `earth`, `stone`, `deepslate` or `shale` — *"only replace SOLID rock (never fill a carved cave)"*. That
## line is load-bearing and nothing in the suite held it: deleting it produced a green sweep. Which is the
## only reason it is worth a layer of its own — a guard whose removal changes nothing measurable is not
## protected by the harness, it is protected by nobody having touched it.
##
## AND IT IS LIVE, not defensive. The pass order settles that (`generate`, :317-322): caves, big caverns and
## tunnels are carved BEFORE `_scatter_veins` runs, so at the moment the blob accretes, the holes are
## already there and adjacent. The aquifer path is stronger still — `_seed_aquifer_ore` (:1104) seeds
## deliberately from *"the SOLID rim: cells adjacent to a flooded cell"*, which is to say it starts the blob
## one step from open water on purpose and relies entirely on this guard to stop it going in.
##
## TWO HALVES, because one of them cannot see the whole failure.
##
##   THE UNIT HALF   builds a world by hand — solid rock, one carved cave, a seed on its rim — and asserts
##                   no cell that was air came back a vein. It is the only half that can attribute a
##                   failure to this function rather than to something downstream of it.
##
##   THE WORLD HALF  generates the real shipping world and asserts the invariant `WorldData.water`
##                   documents and `FactorySim.load_world` DEPENDS on: water lives only in carved-open
##                   cells. That dependency is why this matters more than tidiness — `load_world` ingests
##                   water with `if in_bounds(cell) and not solid.has(cell)`, so a vein that grows into a
##                   flooded pocket does not raise anything. The water is silently dropped, the pocket is
##                   quietly dry, and the aquifer you were supposed to breach is just rock.
##
## Both halves carry their own positive control, because both are assertions of ABSENCE — "no air became
## ore", "no watered cell is solid" — and an absence is satisfied perfectly by a fixture that generated
## nothing. Each first proves the thing it is looking for exists.
##
##   godot --headless --path . --script res://tools/check_vein_guard.gd

## Big enough that the blob's frontier certainly reaches the cave: the cave is 6x4 and sits one cell from
## the seed, so any size past ~20 has walked the whole neighbourhood.
const VEIN_SIZE: int = 60


func _initialize() -> void:
	print("== veins grow into rock, not into the holes you walk through ==")
	_unit_half()
	_world_half()
	_verdict("check_vein_guard", "no carved cell was filled by a vein, and no watered cell is solid")


## A world small enough to reason about, with one cave in a known place.
func _unit_half() -> void:
	var world := WorldData.new()
	world.cols = 24
	world.rows = 24
	for x: int in world.cols:
		for y: int in world.rows:
			world.blocks[Vector2i(x, y)] = &"stone"
	# THE CAVE, and its cells recorded BEFORE anything runs. Asserting against a set captured after the
	# fact would be asking the result whether it liked itself.
	var cave: Dictionary = {}
	for x: int in range(10, 16):
		for y: int in range(8, 12):
			var c := Vector2i(x, y)
			world.blocks.erase(c)
			cave[c] = true

	var gen := LayeredWorldGen.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260817
	# Seeded on the cave's RIM — one cell outside it — which is exactly where `_seed_aquifer_ore` starts.
	gen._grow_vein(world, rng, Vector2i(9, 9), VEIN_SIZE, 5, &"ore")

	# POSITIVE CONTROL FIRST. "No air became ore" is true of a vein that placed nothing at all.
	var placed: int = 0
	for c: Vector2i in world.blocks:
		if world.blocks[c] == &"ore":
			placed += 1
	# `placed <= VEIN_SIZE` is NOT asserted, deliberately. The loop is `while placed < size`, so the bound
	# holds by construction and checking it would be checking the `while`.
	_check(placed > 0, "the vein placed %d cells, so there was accretion to judge" % placed)

	var invaded: Array[String] = []
	for c: Vector2i in cave:
		if world.blocks.has(c):
			invaded.append("%s -> %s" % [c, world.blocks[c]])
	_check(invaded.is_empty(), "the cave is still a cave — %d cells, %d filled%s"
		% [cave.size(), invaded.size(), "" if invaded.is_empty() else ": " + ", ".join(invaded.slice(0, 6))])

	# And the blob really did reach the cave's edge, or the assertion above never had the chance to fail.
	var touching: int = 0
	for c: Vector2i in cave:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if world.blocks.get(c + d, &"") == &"ore":
				touching += 1
				break
	_check(touching > 0,
		"...and the vein reached the cave wall (%d of %d cave cells have ore against them), so the guard was actually asked"
			% [touching, cave.size()])


## The shipping world, and the invariant the sim silently depends on.
func _world_half() -> void:
	var gen: WorldGen = LayeredWorldGen.new()
	var world: WorldData = gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, MainView.WORLD_SEED)

	# POSITIVE CONTROL. A dry world satisfies "no watered cell is solid" perfectly.
	_check(world.water.size() > 0,
		"the shipping world seeded %d watered cells, so there is an aquifer to judge" % world.water.size())

	var drowned: Array[String] = []
	for c: Vector2i in world.water:
		var here: StringName = world.blocks.get(c, &"")
		if here != &"":
			drowned.append("%s is %s under %d water" % [c, here, int(world.water[c])])
	_check(drowned.is_empty(),
		"every watered cell is open rock — %d watered, %d solid%s"
			% [world.water.size(), drowned.size(),
				"" if drowned.is_empty() else ": " + ", ".join(drowned.slice(0, 6))])

	# The same invariant read from the SIM's side. Mostly it restates the check above — `load_world` drops
	# on `solid.has(cell)`, which is what `drowned` scans — but not entirely: it also drops on
	# `not in_bounds(cell)`, which the generator-side scan cannot see. So this catches an out-of-bounds
	# watered cell, and otherwise it is the same fact counted where the game will actually feel it.
	var sim := FactorySim.new()
	sim.load_world(world)
	_check(sim.water.size() == world.water.size(),
		"...and the sim ingested all %d of them, dropping %d"
			% [world.water.size(), world.water.size() - sim.water.size()])
