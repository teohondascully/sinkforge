extends RefCounted

## Builds the TUTORIAL WORLD STATE onto a freshly-generated FactorySim — the hand-placed spawn fixtures
## (starter ore vein, tutorial coal/tree, the drill mineshaft), the starter tool kit, and the optional
## dev pack. Extracted from MainView so the controller delegates world CONSTRUCTION to one focused place.
##
## Pure sim seeding: no scene nodes, no drawing, every edit through the sim's discrete API — so the
## seeded world is deterministic and the conservation invariant holds (spawned items are counted as
## produced). MainView still owns the canonical LAYOUT constants (MainView.SURFACE / MINESHAFT_* /
## STARTER_VEIN_CELL / TUTORIAL_* …) that these procedures read and that the play-tests assert against;
## this module is only the PROCEDURE that realizes them. MainView._seed_world generates + loads the base
## world, then hands the loaded sim here.

## Overlay the tutorial fixtures + starter kit onto an already-loaded world, spawn-cluster order
## (left→right; see MainView's layout banner). dev_start additionally stocks the pack so the
## build/automation loop can be exercised without first hand-mining a stack of ore.
static func seed_tutorial(sim: FactorySim, dev_start: bool) -> void:
	_seed_starter_vein(sim)
	_seed_tutorial_coal(sim)
	_seed_tutorial_tree(sim)
	_seed_starter_adit(sim)
	_seed_tutorial_mineshaft(sim)
	_seed_starter_kit(sim)
	if dev_start:
		_dev_seed_pack(sim)


## The surface ORE VEIN beside spawn (see MainView.STARTER_VEIN_CELL) — the bootstrap ore you HAND-mine
## for the first ingots. A 1-tall, 2-wide band: reads as a vein yet leaves only a shallow trench you
## step straight out of.
static func _seed_starter_vein(sim: FactorySim) -> void:
	for cell: Vector2i in [Vector2i(47, MainView.SURFACE), Vector2i(48, MainView.SURFACE)]:   # just left of spawn (49), right of the forge pocket (46)
		sim.set_solid(cell, &"ore")
		sim.deposits[cell] = 200                                       # richness for the hover readout; hand-mining grabs a loose burst


## The guaranteed surface COAL (MainView.TUTORIAL_COAL_CELLS) — the drill's FUEL, the "go mine coal"
## target that closes the demand-web once you cap the deposit with a drill.
static func _seed_tutorial_coal(sim: FactorySim) -> void:
	for cell: Vector2i in MainView.TUTORIAL_COAL_CELLS:
		sim.set_solid(cell, &"coal")
		sim.deposits[cell] = 200                                       # a hundreds-scale coal patch — fuels the drill for a long time


## THE STARTER ADIT (MainView.ADIT_COLS) — the guaranteed first FACE. A stepped cut beside spawn, one cell
## per step so the body walks in and out of it, with an ore lode exposed in its back wall and more of the
## same vein continuing down behind the rock below. See MainView.ADIT_COLS for why this exists at all.
##
## The lodes are written straight into `sim.lode` rather than being made by mining an ore block, because
## that is what the world will do for itself after the cutover (`docs/LODE_PLAN.md` phase 3) — this fixture
## is the shape of the new opening, standing up before the generator learns to build it.
static func _seed_starter_adit(sim: FactorySim) -> void:
	var mouth: int = MainView.ADIT_COLS[0]
	var face: int = MainView.ADIT_COLS[1]
	var room: int = MainView.ADIT_CHAMBER_COL
	# The cut. Each column is two rows tall (the body's height) and each one opens a row deeper than the last
	# WITHOUT closing the row above, so neighbours overlap and the body can actually walk through at the height
	# it arrives at. It starts ADIT_ROOF rows down, leaving the walking surface whole — see MainView.ADIT_COLS
	# for the four harness layers that cost.
	var top: int = MainView.SURFACE + MainView.ADIT_ROOF
	var opened: Array[Vector2i] = [
		Vector2i(mouth, top), Vector2i(mouth, top + 1),                            # break in here
		Vector2i(face, top), Vector2i(face, top + 1), Vector2i(face, top + 2),      # it opens up, and drops
		Vector2i(room, top + 1), Vector2i(room, top + 2), Vector2i(room, top + 3),  # the deepest end
	]
	for c: Vector2i in opened:
		sim.set_solid(c, &"")
	# NO backing is written behind the bare cells, and that is the whole reason the cut reads as a cut. The
	# first version gave every opened cell a `dirt_wall`, reasoning that a carved room needs something behind
	# it — and the pocket vanished: a walled cell draws as rock, so a hole in the ground looked like ground.
	# This game already has one word for "you can walk here" and it is DARKNESS. Mining never writes a wall
	# (`FactorySim.mine` only erases the solid), so every tunnel a player digs is void and reads black; a
	# hand-authored opening that backs itself is speaking a dialect the world does not.
	#
	# THE FACE — ore in the wall of the cells you can stand in, at the BACK and the BOTTOM of the pocket. The
	# cells under the break-in point are left bare on purpose: the vein starts a step in and a step down, so
	# going deeper is rewarded rather than skippable, and what you see from up top is a dark room with
	# something catching the light at the far end of it.
	for c2: Vector2i in [
		Vector2i(face, top + 2), Vector2i(room, top + 1),
		Vector2i(room, top + 2), Vector2i(room, top + 3),
	]:
		sim.lode[c2] = &"ore"
		sim.deposits[c2] = MainView.ADIT_FACE_AMOUNT
		sim.lode_max[c2] = MainView.ADIT_FACE_AMOUNT      # untouched, so it draws FULL however small it is
	# …and the same vein CONTINUING, behind solid rock, straight down off the bottom of the face. Nothing
	# reveals it yet (the stain is phase 4) — it is there so that the first player who thinks "the vein must
	# go somewhere" and digs one block down is immediately right. Being rewarded for reading the world is the
	# lesson; a vein that simply stopped at the exact edge of the free part would teach the opposite.
	for dy: int in range(4, 7):                # from the first row BELOW the chamber floor, which is exposed
		var deep := Vector2i(room, top + dy)
		sim.lode[deep] = &"ore"
		sim.deposits[deep] = MainView.ADIT_DEEP_AMOUNT
		sim.lode_max[deep] = MainView.ADIT_DEEP_AMOUNT


## The guaranteed TUTORIAL TREE (MainView.TUTORIAL_TREE_COL) — the wood source the bazaar step needs.
## Trees are walk-through, so the trunk on the tutorial path is fine; crowned with leaves so it reads
## and fells as a real tree.
static func _seed_tutorial_tree(sim: FactorySim) -> void:
	var col: int = MainView.TUTORIAL_TREE_COL
	var g: int = sim.surface_row(col)                                  # ground top row (solid at g); trunk above it
	sim.set_solid(Vector2i(col, g - 1), &"wood")                      # trunk base
	sim.set_solid(Vector2i(col, g - 2), &"wood")                      # trunk top
	for leaf: Vector2i in [Vector2i(col, g - 3), Vector2i(col, g - 4), Vector2i(col + 1, g - 3)]:
		if not sim.is_solid(leaf):
			sim.set_solid(leaf, &"leaves")                            # crown — marks it a tree, fells to wood


## The RUNG-1 stage: a shallow BOOTSTRAP forge pocket (col 46) + the DRILL SHAFT (col 56). Split into two
## columns so the shaft stays a clean OPEN drop — you toss ore/coal straight down it and gravity delivers
## to whatever's at the bottom of that column (the forge, or the drill once you place it). Layout:
##   col 46 SURFACE   BOOTSTRAP FORGE  — toss surface ore in (from col 45); ingots fall to SURFACE+1 (collect)
##   col 46 SURFACE+1 open             — bootstrap ingots land here
##   col 46 SURFACE+2 floor
##   col 56 SURFACE   open        — the OPEN shaft mouth: toss ore/coal in here; gravity delivers it below
##   col 56 SURFACE+1 ORE block   — hand-mine it → cavity + a drillable deposit; then place the DRILL here
##                                  (SURFACE+1 so it's comfortably in reach from the col-55 surface edge)
##   col 56 SURFACE+2 AUTO FORGE  — catches the drill's pulled ore → ingots, hands-free
##   col 56 SURFACE+3 open        — auto ingots land
##   col 56 SURFACE+4 rock floor
## The drill needs COAL — you drop coal down the open shaft onto it to run it.
static func _seed_tutorial_mineshaft(sim: FactorySim) -> void:
	var c: int = MainView.MINESHAFT_COL
	# Bootstrap forge pocket (col 46) — a shallow 1-deep well, OFF the drill shaft.
	var bf: int = MainView.MINESHAFT_FORGE_CELL.x
	sim.set_solid(Vector2i(bf, MainView.SURFACE), &"")                # carve the forge cell
	sim.set_solid(Vector2i(bf, MainView.SURFACE + 1), &"")            # ingots land / collect
	sim.set_solid(Vector2i(bf, MainView.SURFACE + 2), &"earth")      # floor
	sim.place_machine(load("res://src/data/machines/processor.tres"), MainView.MINESHAFT_FORGE_CELL)   # bootstrap forge
	# Drill shaft (col 56) — OPEN mouth + drill cell so tossed coal drops straight down onto the drill, with a
	# VISIBLE solid ore vein just below the drill cell for the drill to bore into.
	sim.set_solid(Vector2i(c, MainView.SURFACE), &"")                 # open mouth (drop access)
	sim.set_solid(MainView.MINESHAFT_DRILL_CELL, &"")                 # SURFACE+1: OPEN — the player drops the Drill here
	sim.set_solid(MainView.MINESHAFT_ORE_CELL, &"ore")               # SURFACE+2: the visible ore vein the drill bores down into
	sim.deposits[MainView.MINESHAFT_ORE_CELL] = MainView.MINESHAFT_ORE_RICHNESS   # a hundreds-scale vein the drill runs on for a long time
	sim.set_solid(MainView.AUTO_FORGE_CELL, &"")                     # SURFACE+3: carve the cell the AUTO forge sits in
	sim.set_solid(Vector2i(c, MainView.SURFACE + 4), &"")             # gap under the auto forge (ingots land)
	sim.set_solid(Vector2i(c, MainView.SURFACE + 5), &"earth")      # rock floor
	sim.place_machine(load("res://src/data/machines/processor.tres"), MainView.AUTO_FORGE_CELL)        # auto-line forge


## The STARTER TOOL every new game begins with — one bad wooden pickaxe (MiningRules.STARTER_TOOLS).
## It's the ONLY thing in a fresh pack: it grinds rock AND chops trees, and its badness (tier-1 speed)
## is what makes the early grind ache for a drill. Spawned → counted as produced so conservation holds.
## Always seeded (independent of dev_start).
static func _seed_starter_kit(sim: FactorySim) -> void:
	for tool: StringName in MiningRules.STARTER_TOOLS:
		sim.inventory[tool] = int(sim.inventory.get(tool, 0)) + 1
		sim.total_produced[tool] = int(sim.total_produced.get(tool, 0)) + 1


## Dev-testing kit: start with a stocked pack so you can immediately exercise the build/automation loop
## (place machines, feed, smelt) without first hand-mining a stack of ore. Items are SPAWNED, so they
## count as produced to keep the conservation invariant true. Gated on dev_start (off for a clean run).
static func _dev_seed_pack(sim: FactorySim) -> void:
	var kit: Dictionary = {&"ore": 20, &"ingot": 20, &"wood": 10, &"coal": 20, &"processor": 2, &"splitter": 2, &"lift": 1, &"drill": 1, &"generator": 1, &"conduit": 10}
	for item: StringName in kit:
		sim.inventory[item] = int(sim.inventory.get(item, 0)) + int(kit[item])
		sim.total_produced[item] = int(sim.total_produced.get(item, 0)) + int(kit[item])
