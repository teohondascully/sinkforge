extends "res://tools/check_base.gd"

## RECOVERY PRIORITY #2 (docs/PRIORITY.md), "reachability for piles landing under machines." A live
## playtest reported product piles the player could not pick up, "not sure why." Traced to a real,
## always-reproducible structural gap: `player.gd`'s `_blocked` walls the body off any cell a machine
## occupies, so a Drill placed above a vein and a Forge placed below it -- both dug into the SAME
## one-cell-wide shaft, the natural shape of hand-mining and exactly what the tutorial's own "build" step
## teaches -- together plug the only way back into that column. `FactorySim._column_landing` always finds
## SOME resting cell for a machine's spare output (a recipe machine passes through anything its recipe
## does not want, per `_run_recipe`'s own header), with no regard for whether the player can ever reach
## it. The world-seeder's own bootstrap forge (`scenes/world_seeder.gd`) hand-carves an open landing gap
## below itself for exactly this reason; nothing generalized that fix to a line the player builds.
##
## `FactorySim.pile_reachable`/`first_unreachable_pile` do not change where anything lands -- redirecting
## a landing needs pathfinding this cycle does not have room to get right, and picking the sealing
## machine back up (RMB, `pickup_machine`) already reopens the column, so the fix is DETECTION: give the
## HUD's new "STUCK PILE" chip (`hud.gd`) a true answer instead of the game staying silent while a real
## pile sits three inches away with no path to it.
##
## Run: godot --headless --path . --script res://tools/check_pile_reach.gd

func _initialize() -> void:
	print("== pile reachability check ==")
	_no_piles_no_witness()
	_open_pile_is_reachable()
	_sealed_by_own_machines()
	_picking_up_the_seal_reopens_it()
	_bounded_scan_finds_a_long_real_path()
	_verdict("check_pile_reach")


## The trivial population: no piles at all reads as no unreachable pile, not a false alarm.
func _no_piles_no_witness() -> void:
	var sim := FactorySim.new()
	_check(sim.ground.is_empty(), "fixture: a bare sim has no ground piles")
	_check(sim.first_unreachable_pile(Vector2i(10, 10), 2.5) == Vector2i(-1, -1),
		"an empty world reports no unreachable pile")


## A pile sitting in open air, one cell from the player, with nothing sealing anything: the baseline
## "yes" the sealed case below is contrasted against.
func _open_pile_is_reachable() -> void:
	var sim := FactorySim.new()
	sim.ground[Vector2i(20, 5)] = {&"ore": 3}
	_check(sim.pile_reachable(Vector2i(20, 5), Vector2i(21, 5), 2.5),
		"a pile one open cell from the player is reachable")
	_check(sim.first_unreachable_pile(Vector2i(21, 5), 2.5) == Vector2i(-1, -1),
		"…and first_unreachable_pile agrees: nothing flagged")


## THE REAL MECHANISM, reproduced through real placement and real ticks, not a hand-set ground entry.
## A 1-wide shaft (solid rock on both flanking columns, matching hand-mining): a Drill bores a short ore
## vein, a Forge two rows below it converts the ore to ingots. Nothing is below the Forge but two open
## rows and then virgin stone -- the ingots land there, sealed between the Forge above and stone below,
## with the Drill also plugging the column's only other entry point.
func _rig_sealed_shaft() -> Dictionary:
	var sim := FactorySim.new()
	var col := 30
	for y: int in range(0, 12):
		for x: int in [col - 2, col - 1, col + 1, col + 2]:
			sim.solid[Vector2i(x, y)] = &"stone"
	sim.solid[Vector2i(col, 6)] = &"ore"
	sim.deposits[Vector2i(col, 6)] = 4
	sim.solid[Vector2i(col, 9)] = &"stone"
	var drill_def: MachineDef = load("res://src/data/machines/drill.tres") as MachineDef
	var forge_def: MachineDef = load("res://src/data/machines/processor.tres") as MachineDef  # display "Forge"
	var drill: MachineState = sim.place_machine(drill_def, Vector2i(col, 5))
	var forge: MachineState = sim.place_machine(forge_def, Vector2i(col, 7))
	if drill != null:
		drill.input_buffer[&"coal"] = 400
	for _i: int in 400:
		sim.tick()
	return {"sim": sim, "col": col, "drill": drill, "forge": forge}


func _sealed_by_own_machines() -> void:
	var rig: Dictionary = _rig_sealed_shaft()
	var sim: FactorySim = rig["sim"]
	var col: int = rig["col"]
	var pile: Vector2i = Vector2i(col, 8)
	_check(sim.ground.has(pile) and int(sim.ground[pile].get(&"ingot", 0)) > 0,
		"fixture: the line really ran and really produced ingots (%s)" % sim.ground.get(pile, {}))
	var from_above: Vector2i = Vector2i(col, 2)   # where the player stands, back at the surface
	_check(not sim.pile_reachable(pile, from_above, 2.5),
		"…and with the Drill+Forge both dug into the shaft, the ingot pile is genuinely unreachable")
	_check(sim.first_unreachable_pile(from_above, 2.5) == pile,
		"…first_unreachable_pile names the exact cell, not just a bool")


## THE CONTRAST THAT PROVES THIS IS A LIVE COMPUTATION, NOT A HARDCODED VERDICT: pick both machines back
## up (the real recovery path this whole feature exists to point at -- RMB, the same verb that placed
## them) and the SAME cell, same pile, same player position now reads reachable, because the column it
## sits in is actually open again. Both, not one: the Drill and the Forge seal the column IN SERIES from
## the player's own vantage above it, so clearing only one still leaves the other blocking.
func _picking_up_the_seal_reopens_it() -> void:
	var rig: Dictionary = _rig_sealed_shaft()
	var sim: FactorySim = rig["sim"]
	var col: int = rig["col"]
	var pile: Vector2i = Vector2i(col, 8)
	var from_above: Vector2i = Vector2i(col, 2)
	_check(not sim.pile_reachable(pile, from_above, 2.5), "fixture: still sealed before either pickup")
	_check(sim.pickup_machine(Vector2i(col, 5)), "picked the Drill back up (RMB, the real player verb)")
	_check(not sim.pile_reachable(pile, from_above, 2.5),
		"…the Forge alone still seals it: removing just one link is not enough")
	_check(sim.pickup_machine(Vector2i(col, 7)), "picked the Forge back up too")
	_check(sim.pile_reachable(pile, from_above, 2.5),
		"…and the exact same pile, same player position, now reads reachable: the column reopened")


## The BFS must not give up on a real path just because it is long. A winding 60-cell corridor, well
## under PILE_REACH_SCAN_CAP, still has to resolve true.
func _bounded_scan_finds_a_long_real_path() -> void:
	var sim := FactorySim.new()
	var y := 40
	for x: int in range(0, 60):
		sim.solid[Vector2i(x, y - 1)] = &"stone"
		sim.solid[Vector2i(x, y + 1)] = &"stone"
	sim.ground[Vector2i(0, y)] = {&"ore": 1}
	_check(sim.pile_reachable(Vector2i(0, y), Vector2i(59, y), 2.5),
		"a real 59-cell-long open corridor still resolves reachable, not lost to the scan cap")
