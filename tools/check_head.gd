extends SceneTree

## STAND IT ON THE THING IT EATS.
##
## `docs/LODE_PLAN.md` phase 2a. The old drill is placed in the open cell ABOVE a vein and bores down
## through solid ore, carving its own shaft. That model has no referent once ore stops being a block, and it
## was never the legible one: "somewhere above it, in the same column, with a drain under the bottom" is
## three facts to get right before anything happens, and `docs/DRIFT.md` §6 already flags placement as the
## thing that will be got wrong every time if it is not excellent.
##
## A HEAD is placed ON the lode. One fact. The machine occupies the cell whose backing is the vein — which
## is only expressible at all because ore moved to the background plane, so "the machine is here" and "the
## vein is here" stopped competing for one cell.
##
##   IT DRAWS WHERE IT STANDS.  A drill in a lode cell drains THAT vein, at the same rate, off the same
##                              pool the hand pulls from. One pool, now three hands.
##   IT POURS DOWN ITS COLUMN.  The on-hook rule is untouched: extraction may be lateral, logistics stays
##                              gravity-vertical. Never sideways, not once.
##   IT IS NEVER BLOCKED.       With no shaft under it the ore piles at its feet, like every other item in
##                              this game when it lands. Refusing to run to prevent a pile invents a chore.
##   SPENT IS NOT STARVED.      A Head that finished its vein says so in its own word, because "starved"
##                              sends you hunting a feed problem that does not exist.
##   THE OLD MODEL STILL RUNS.  The bridge (`docs/LODE_PLAN.md` §3): solid ore still bores exactly as it
##                              did, so nothing in the game breaks before the phase-3 cutover.
##
##   ONE MORE MOUTH.           A Spur chained to a Head makes the Head take a unit out of the Spur's cell
##                              too, on the same cycle, down the HEAD's column. One Head, many Spurs, one
##                              column, one drain — and the fuel bill scales with the reach, so coverage
##                              buys throughput without buying another machine to manage.
##   IT MUST REACH SOMETHING.   A Spur is refused unless it stands on a lode AND touches a Head or a Spur
##                              that chains back to one. Placement is the thing that gets got wrong.
##   THE CHAIN OUTLIVES ITS LINKS.  A Head whose own cell is finished keeps working its Spurs, and does not
##                              say `spent` until nothing anywhere in its reach has ore left.
##
##   godot --headless --path . --script res://tools/check_head.gd

const DRILL: String = "res://src/data/machines/drill.tres"
const SPUR: String = "res://src/data/machines/spur.tres"

var _fails: int = 0


func _initialize() -> void:
	print("== stand it on the thing it eats ==")
	_it_draws_where_it_stands()
	_it_pours_down_its_column()
	_it_is_never_blocked()
	_spent_is_not_starved()
	_the_old_model_still_runs()
	_the_preview_says_one_thing()
	_a_spur_is_one_more_mouth()
	_a_spur_must_reach_something()
	_the_chain_outlives_its_links()
	if _fails == 0:
		print("check_head: PASS — a Head works the face it stands on")
		quit(0)
	else:
		printerr("check_head: FAIL (%d)" % _fails)
		quit(1)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_fails += 1
		printerr("  FAIL: %s" % label)


## A sim with a lode at `at`, holding `amount`, and a floor `drop` rows below it.
func _rig(at: Vector2i, amount: int, drop: int = 3) -> FactorySim:
	var sim := FactorySim.new()
	sim.lode[at] = &"ore"
	sim.deposits[at] = amount
	sim.set_solid(at + Vector2i(0, drop), &"stone")
	return sim


func _head(sim: FactorySim, at: Vector2i, coal: int = 400) -> MachineState:
	var m: MachineState = sim.place_machine(load(DRILL) as MachineDef, at)
	if m != null:
		m.input_buffer[&"coal"] = coal
	return m


func _run(sim: FactorySim, ticks: int) -> void:
	for _i: int in ticks:
		sim.tick()


## IT DRAWS WHERE IT STANDS — and off the same pool, so the ledger cannot be gamed by choosing a hand.
func _it_draws_where_it_stands() -> void:
	var at := Vector2i(8, 6)
	var sim: FactorySim = _rig(at, 40)
	var head: MachineState = _head(sim, at)
	_check(head != null, "a drill can be placed IN the cell whose backing is the vein")
	_check(sim.drill_lode_target(at) == at, "…and its target is the face it stands on, not a column below")
	var before: int = sim.ore_deposit_at(at)
	_run(sim, 400)
	var took: int = before - sim.ore_deposit_at(at)
	_check(took > 0, "it draws the vein down (%d of %d)" % [took, before])
	_check(int(sim.total_produced.get(&"ore", 0)) == took,
		"…and every unit it took is realised as production exactly once — the ledger still balances")
	_check(sim.lode_at(at) == &"ore" or sim.ore_deposit_at(at) == 0,
		"…and the vein is still a vein until it is actually empty")


## IT POURS DOWN ITS COLUMN. The one property `docs/DRIFT.md` §7 says must never regress.
func _it_pours_down_its_column() -> void:
	var at := Vector2i(8, 6)
	var sim: FactorySim = _rig(at, 40)
	_head(sim, at)
	_run(sim, 400)
	var strays: int = 0
	var down: int = 0
	for key: Variant in sim.ground:
		var c: Vector2i = key
		var n: int = 0
		for item: Variant in (sim.ground[c] as Dictionary):
			n += int((sim.ground[c] as Dictionary)[item])
		if n <= 0:
			continue
		if c.x != at.x:
			strays += n
		elif c.y >= at.y:
			down += n
	_check(strays == 0, "not one unit moved SIDEWAYS out of the Head's column")
	_check(down > 0, "…and the haul is below the Head, where gravity put it (%d)" % down)


## IT IS NEVER BLOCKED. Rock right under a Head is a pile, not a stall.
func _it_is_never_blocked() -> void:
	var at := Vector2i(8, 6)
	var sim: FactorySim = _rig(at, 20, 1)          # floor DIRECTLY below the Head — no shaft at all
	var head: MachineState = _head(sim, at)
	_run(sim, 300)
	_check(sim.ore_deposit_at(at) < 20, "a Head with no shaft under it still runs (%d left)"
		% sim.ore_deposit_at(at))
	_check(sim.machine_status(head) != &"blocked", "…and never reports itself blocked for want of a drain")
	var piled: int = 0
	for key: Variant in sim.ground:
		for item: Variant in (sim.ground[key] as Dictionary):
			piled += int((sim.ground[key] as Dictionary)[item])
	_check(piled > 0, "…the ore piles where it landed (%d), which is a state you can see and dig out of" % piled)


## SPENT IS NOT STARVED.
func _spent_is_not_starved() -> void:
	var at := Vector2i(8, 6)
	var sim: FactorySim = _rig(at, 6)
	var head: MachineState = _head(sim, at)
	_check(sim.machine_status(head) == &"working", "a fresh Head on a fresh vein is working")
	_run(sim, 600)
	_check(sim.ore_deposit_at(at) == 0 and sim.lode_at(at) == &"", "the vein is worked out")
	_check(sim.machine_status(head) == &"spent",
		"…and the Head says SPENT — its own word, because nothing is wrong with it")
	_check(int(sim.total_produced.get(&"ore", 0)) == 6, "…having produced exactly the vein, no more (6)")
	# A drill that was simply put somewhere useless must NOT claim to be spent — that would send a player
	# looking for a vein that was never there.
	var bare := FactorySim.new()
	bare.set_solid(Vector2i(4, 9), &"stone")
	var lost: MachineState = _head(bare, Vector2i(4, 6))
	_check(bare.machine_status(lost) == &"no_input",
		"…while a drill placed on nothing at all reads as STARVED, not spent")


## THE OLD MODEL STILL RUNS — the bridge that keeps the game playable until the cutover.
func _the_old_model_still_runs() -> void:
	var sim := FactorySim.new()
	var ore := Vector2i(8, 6)
	sim.set_solid(ore, &"ore")
	sim.deposits[ore] = 10
	sim.set_solid(Vector2i(8, 8), &"stone")
	var drill: MachineState = _head(sim, Vector2i(8, 5))       # the OLD placement: above the vein
	_check(drill != null and sim.drill_target(Vector2i(8, 5)) == ore,
		"a drill above a SOLID vein still targets it exactly as before")
	_check(sim.drill_lode_target(Vector2i(8, 5)).x < 0, "…and is not confused for a Head (no lode under it)")
	_run(sim, 500)
	_check(int(sim.total_produced.get(&"ore", 0)) == 10, "…and bores the whole body out (10)")
	_check(not sim.is_solid(ore), "…carving its shaft as it goes, exactly as it always did")


## THE PREVIEW SAYS ONE THING. Placement legibility is the reason this model is better; if the preview still
## drew a column the win would be thrown away at the moment it matters.
func _the_preview_says_one_thing() -> void:
	var at := Vector2i(8, 6)
	var sim: FactorySim = _rig(at, 40)
	var pv: Dictionary = sim.drill_preview(at)
	var cells: Array = pv["ore_cells"]
	_check(cells.size() == 1 and cells[0] == at, "the preview over a lode shows ONE cell — the face itself")
	_check(pv["drop_cell"] == at + Vector2i(0, 1), "…and pours from directly under it")
	_check(not bool(pv["blocked"]), "…and never previews as blocked")
	_check(sim.drill_column_remaining(at) == 40,
		"…and the supply it reports is the face it stands on (40), not a column sum")


## A sim with a horizontal run of `n` lode cells starting at `at`, each holding `each`, floor well below.
func _seam(at: Vector2i, n: int, each: int) -> FactorySim:
	var sim := FactorySim.new()
	for i: int in n:
		var c: Vector2i = at + Vector2i(i, 0)
		sim.lode[c] = &"ore"
		sim.deposits[c] = each
		sim.lode_max[c] = each
	sim.set_solid(at + Vector2i(0, 4), &"stone")
	return sim


func _spur(sim: FactorySim, at: Vector2i) -> MachineState:
	return sim.place_machine(load(SPUR) as MachineDef, at)


## ONE MORE MOUTH — and the drain stays in one place, which is the property that makes reach worth building.
func _a_spur_is_one_more_mouth() -> void:
	var at := Vector2i(8, 6)
	var sim: FactorySim = _seam(at, 3, 30)
	var head: MachineState = _head(sim, at, 4000)
	_check(_spur(sim, at + Vector2i(1, 0)) != null and _spur(sim, at + Vector2i(2, 0)) != null,
		"two Spurs chain off a Head along the seam")
	var cover: Array[Vector2i] = sim.head_coverage(at)
	_check(cover.size() == 3 and cover[0] == at,
		"…and the Head's reach is all three cells, its own first (%d)" % cover.size())
	_check(sim.spur_head(at + Vector2i(2, 0)) == at,
		"…the far Spur knows which Head it answers to, through the near one")
	_run(sim, 400)
	var took: int = 0
	for i: int in 3:
		took += 30 - sim.ore_deposit_at(at + Vector2i(i, 0))
	_check(sim.ore_deposit_at(at + Vector2i(2, 0)) < 30,
		"the Head draws the FAR cell too — reach is real, not a label (%d left)"
			% sim.ore_deposit_at(at + Vector2i(2, 0)))
	_check(int(sim.total_produced.get(&"ore", 0)) == took,
		"…and every unit off the whole chain is realised exactly once (%d)" % took)
	# ONE COLUMN, ONE DRAIN.
	var strays: int = 0
	for key: Variant in sim.ground:
		var c: Vector2i = key
		if c.x == at.x:
			continue
		for item: Variant in (sim.ground[c] as Dictionary):
			strays += int((sim.ground[c] as Dictionary)[item])
	_check(strays == 0, "…and the whole haul comes out of the HEAD's column, not each Spur's")
	# REACH IS A TRADE. Three mouths pull three times as much per cycle and burn three times the coal doing
	# it, so a Spur buys THROUGHPUT and never efficiency — the ore-per-coal is untouched, and what you have
	# actually bought is the same vein emptied sooner with no second machine to feed, watch or drain.
	var lone := _seam(Vector2i(40, 6), 1, 3000)
	var solo: MachineState = _head(lone, Vector2i(40, 6), 4000)
	_run(lone, 400)
	var wide := _seam(Vector2i(40, 6), 3, 3000)
	var many: MachineState = _head(wide, Vector2i(40, 6), 4000)
	_spur(wide, Vector2i(41, 6))
	_spur(wide, Vector2i(42, 6))
	_run(wide, 400)
	_check(many.fed > solo.fed,
		"in the same time a wide Head out-produces a lone one (%d vs %d)" % [many.fed, solo.fed])
	_check(int(wide.total_consumed.get(&"coal", 0)) > int(lone.total_consumed.get(&"coal", 0)),
		"…and burns more coal doing it (%d vs %d) — reach is a trade, not a free upgrade"
			% [int(wide.total_consumed.get(&"coal", 0)), int(lone.total_consumed.get(&"coal", 0))])


## IT MUST REACH SOMETHING. Both halves of the rule, refused at the moment of the attempt.
func _a_spur_must_reach_something() -> void:
	var at := Vector2i(8, 6)
	var sim: FactorySim = _seam(at, 4, 30)
	var main := MainView.new()
	main.sim = sim
	_head(sim, at)
	_check(main.spur_fits(at + Vector2i(1, 0)),
		"a Spur fits on a lode cell touching the Head")
	_check(not main.spur_fits(at + Vector2i(3, 0)),
		"…and is refused two cells out, where it would touch nothing — an orphan is not a build")
	_spur(sim, at + Vector2i(1, 0))
	_check(main.spur_fits(at + Vector2i(2, 0)),
		"…but fits once the gap is bridged: a chain reaches as far as you build it")
	sim.lode.erase(at + Vector2i(2, 0))
	_check(not main.spur_fits(at + Vector2i(2, 0)),
		"…and is refused where there is no vein, because a Spur eats what it stands on, same as a Head")
	main.free()


## THE CHAIN OUTLIVES ITS LINKS.
func _the_chain_outlives_its_links() -> void:
	var at := Vector2i(8, 6)
	var sim: FactorySim = _seam(at, 2, 30)
	sim.deposits[at] = 1                       # the Head's own cell is nearly done; the Spur's is not
	sim.lode_max[at] = 1
	var head: MachineState = _head(sim, at)
	_spur(sim, at + Vector2i(1, 0))
	_run(sim, 100)
	_check(sim.ore_deposit_at(at) == 0, "the Head's own cell is worked out")
	_check(sim.machine_status(head) != &"spent",
		"…and it does NOT say spent, because moving it would throw away a chain that is still paying")
	_check(sim.drill_lode_target(at) == at + Vector2i(1, 0),
		"…it draws from the nearest link that still has something in it")
	_run(sim, 900)
	_check(sim.ore_deposit_at(at + Vector2i(1, 0)) == 0 and sim.machine_status(head) == &"spent",
		"…and only when the WHOLE reach is dry does it ask to be moved")
	var orphan := FactorySim.new()
	orphan.lode[Vector2i(4, 4)] = &"ore"
	orphan.deposits[Vector2i(4, 4)] = 10
	var lone: MachineState = orphan.place_machine(load(SPUR) as MachineDef, Vector2i(4, 4))
	_check(orphan.machine_status(lone) == &"unlinked",
		"a Spur reaching no Head says UNLINKED — its own word, because nothing else is wrong with it")
