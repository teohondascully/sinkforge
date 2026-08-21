extends RefCounted

## Builds the tutorial world state onto a freshly-generated FactorySim: the hand-placed spawn fixtures
## (starter ore vein, tutorial coal and tree, the drill mineshaft), the starter tool kit, and the
## optional dev pack.
##
## Sim seeding only. No scene nodes, no drawing, and every edit goes through the sim's discrete API, so
## the seeded world stays deterministic and the conservation invariant holds: spawned items are counted
## as produced. MainView owns the canonical layout constants (SURFACE, MINESHAFT_*, STARTER_VEIN_CELL,
## TUTORIAL_*) that these procedures read; this module is only the procedure that realizes them.

## Overlay the tutorial fixtures and starter kit onto an already-loaded world, in spawn-cluster order,
## left to right. dev_start additionally stocks the pack so the build and automation loop can be
## exercised without hand-mining a stack of ore first.
static func seed_tutorial(sim: FactorySim, dev_start: bool) -> void:
	_seed_starter_vein(sim)
	_seed_tutorial_coal(sim)
	_seed_tutorial_tree(sim)
	_seed_starter_adit(sim)
	_seed_tutorial_mineshaft(sim)
	_seed_starter_kit(sim)
	if dev_start:
		_dev_seed_pack(sim)


## The surface ore vein beside spawn (MainView.STARTER_VEIN_CELL): the bootstrap ore you hand-mine for
## the first ingots. One row tall and two columns wide, so it reads as a vein but leaves only a shallow
## trench you can step straight out of.
static func _seed_starter_vein(sim: FactorySim) -> void:
	for cell: Vector2i in [Vector2i(47, MainView.SURFACE), Vector2i(48, MainView.SURFACE)]:   # left of spawn (49), right of the forge pocket (46)
		sim.set_solid(cell, &"ore")
		sim.deposits[cell] = 200                                       # richness for the hover readout


## The guaranteed surface coal (MainView.TUTORIAL_COAL_CELLS): the drill's fuel, and the target that
## closes the demand web once you cap the ore deposit with a drill.
static func _seed_tutorial_coal(sim: FactorySim) -> void:
	for cell: Vector2i in MainView.TUTORIAL_COAL_CELLS:
		sim.set_solid(cell, &"coal")
		sim.deposits[cell] = 200                                       # fuels the drill for a long time


## The starter adit (MainView.ADIT_COLS): the guaranteed first rock face. A stepped cut beside spawn, one
## cell per step so the body can walk in and out of it, with an ore lode exposed in its back wall and
## more of the same vein continuing down behind the rock below.
##
## The lodes are written straight into `sim.lode` rather than produced by mining an ore block, which is
## how the generator will build them itself (docs/LODE.md).
static func _seed_starter_adit(sim: FactorySim) -> void:
	var mouth: int = MainView.ADIT_COLS[0]
	var face: int = MainView.ADIT_COLS[1]
	var room: int = MainView.ADIT_CHAMBER_COL
	# The cut. Each column is two rows tall (the body's height) and opens a row deeper than the last
	# without closing the row above, so neighbours overlap and the body can walk through at whatever
	# height it arrives at. It starts ADIT_ROOF rows down, leaving the walking surface whole.
	var top: int = MainView.SURFACE + MainView.ADIT_ROOF
	var opened: Array[Vector2i] = [
		Vector2i(mouth, top), Vector2i(mouth, top + 1),                            # break in here
		Vector2i(face, top), Vector2i(face, top + 1), Vector2i(face, top + 2),      # it opens up, and drops
		Vector2i(room, top + 1), Vector2i(room, top + 2), Vector2i(room, top + 3),  # the deepest end
	]
	for c: Vector2i in opened:
		sim.set_solid(c, &"")
	# Never write a backing wall behind the opened cells. A walled cell draws as rock, so a backed hole
	# reads as ground. Darkness is this game's one word for "you can walk here": `FactorySim.mine` only
	# erases the solid and never writes a wall, so every player-dug tunnel is void and reads black. A
	# hand-authored opening has to speak the same dialect.
	#
	# The face: ore in the wall of cells you can stand in, at the back and the bottom of the pocket. The
	# cells under the break-in point are bare on purpose, so the vein starts a step in and a step down and
	# going deeper is rewarded rather than skippable.
	for c2: Vector2i in [
		Vector2i(face, top + 2), Vector2i(room, top + 1),
		Vector2i(room, top + 2), Vector2i(room, top + 3),
	]:
		sim.lode[c2] = &"ore"
		sim.deposits[c2] = MainView.ADIT_FACE_AMOUNT
		sim.lode_max[c2] = MainView.ADIT_FACE_AMOUNT      # untouched, so it draws full however small it is
	# The same vein continues behind solid rock, straight down off the bottom of the face, so a player
	# who thinks "the vein must go somewhere" and digs one block down is immediately right. A vein that
	# stopped at the exact edge of the opened cells would teach the opposite lesson. The lode stain runs
	# over these cells, so the renderer tints them through the rock.
	for dy: int in range(4, 7):                # from the first row below the chamber floor, which is exposed
		var deep := Vector2i(room, top + dy)
		sim.lode[deep] = &"ore"
		sim.deposits[deep] = MainView.ADIT_DEEP_AMOUNT
		sim.lode_max[deep] = MainView.ADIT_DEEP_AMOUNT


## The guaranteed tutorial tree (MainView.TUTORIAL_TREE_COL): the wood source the bazaar step needs.
## Trees are walk-through, so a trunk on the tutorial path is harmless.
static func _seed_tutorial_tree(sim: FactorySim) -> void:
	var col: int = MainView.TUTORIAL_TREE_COL
	var g: int = sim.surface_row(col)                                  # ground top row, solid at g; trunk above it
	sim.set_solid(Vector2i(col, g - 1), &"wood")                      # trunk base
	sim.set_solid(Vector2i(col, g - 2), &"wood")                      # trunk top
	for leaf: Vector2i in [Vector2i(col, g - 3), Vector2i(col, g - 4), Vector2i(col + 1, g - 3)]:
		if not sim.is_solid(leaf):
			sim.set_solid(leaf, &"leaves")                            # crown: marks it a tree, fells to wood


## The tutorial stage: a shallow bootstrap forge pocket (col 46) and the drill shaft (col 56). They are
## split across two columns so the shaft stays a clean open drop: ore or coal tossed in falls to whatever
## sits at the bottom of that column, the forge or the drill. Layout:
##   col 46 SURFACE    bootstrap forge: toss surface ore in from col 45; ingots fall to SURFACE+1
##   col 46 SURFACE+1  open: bootstrap ingots land here
##   col 46 SURFACE+2  floor
##   col 56 SURFACE    open: the shaft mouth, gravity delivers whatever is tossed in
##   col 56 SURFACE+1  ore block: hand-mine it for a cavity plus a drillable deposit, then place the
##                     drill here, in reach from the col-55 surface edge
##   col 56 SURFACE+2  auto forge: catches the drill's ore and smelts it hands-free
##   col 56 SURFACE+3  open: auto ingots land
##   col 56 SURFACE+4  rock floor
## The drill runs on coal dropped down the open shaft onto it.
static func _seed_tutorial_mineshaft(sim: FactorySim) -> void:
	var c: int = MainView.MINESHAFT_COL
	# Bootstrap forge pocket (col 46): a shallow one-deep well, off the drill shaft.
	var bf: int = MainView.MINESHAFT_FORGE_CELL.x
	sim.set_solid(Vector2i(bf, MainView.SURFACE), &"")                # carve the forge cell
	sim.set_solid(Vector2i(bf, MainView.SURFACE + 1), &"")            # ingots land / collect
	sim.set_solid(Vector2i(bf, MainView.SURFACE + 2), &"earth")      # floor
	sim.place_machine(load("res://src/data/machines/processor.tres"), MainView.MINESHAFT_FORGE_CELL)   # bootstrap forge
	# Drill shaft (col 56): an open mouth and drill cell so tossed coal drops straight onto the drill,
	# with a visible solid ore vein just below the drill cell for it to bore into.
	sim.set_solid(Vector2i(c, MainView.SURFACE), &"")                 # open mouth, for drop access
	sim.set_solid(MainView.MINESHAFT_DRILL_CELL, &"")                 # SURFACE+1: where the player drops the drill
	sim.set_solid(MainView.MINESHAFT_ORE_CELL, &"ore")               # SURFACE+2: the vein the drill bores down into
	sim.deposits[MainView.MINESHAFT_ORE_CELL] = MainView.MINESHAFT_ORE_RICHNESS
	sim.set_solid(MainView.AUTO_FORGE_CELL, &"")                     # SURFACE+3: the cell the auto forge sits in
	sim.set_solid(Vector2i(c, MainView.SURFACE + 4), &"")             # gap under the auto forge; ingots land
	sim.set_solid(Vector2i(c, MainView.SURFACE + 5), &"earth")      # rock floor
	sim.place_machine(load("res://src/data/machines/processor.tres"), MainView.AUTO_FORGE_CELL)        # auto-line forge


## The starter tool every new game begins with: one wooden pickaxe (MiningRules.STARTER_TOOLS), the only
## thing in a fresh pack. It grinds rock and chops trees, and its tier-1 speed is what makes the early
## grind ache for a drill. Spawned items are counted as produced so conservation holds. Always seeded,
## independent of dev_start.
static func _seed_starter_kit(sim: FactorySim) -> void:
	for tool: StringName in MiningRules.STARTER_TOOLS:
		sim.inventory[tool] = int(sim.inventory.get(tool, 0)) + 1
		sim.total_produced[tool] = int(sim.total_produced.get(tool, 0)) + 1


## Dev kit: a stocked pack so the build and automation loop can be exercised without hand-mining a stack
## of ore first. Items are spawned, so they count as produced to keep the conservation invariant true.
## Gated on dev_start, and off for a clean run.
static func _dev_seed_pack(sim: FactorySim) -> void:
	var kit: Dictionary = {&"ore": 20, &"ingot": 20, &"wood": 10, &"coal": 20, &"processor": 2, &"splitter": 2, &"lift": 1, &"drill": 1, &"generator": 1, &"conduit": 10}
	for item: StringName in kit:
		sim.inventory[item] = int(sim.inventory.get(item, 0)) + int(kit[item])
		sim.total_produced[item] = int(sim.total_produced.get(item, 0)) + int(kit[item])
