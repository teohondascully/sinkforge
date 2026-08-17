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
##   godot --headless --path . --script res://tools/check_head.gd

const DRILL: String = "res://src/data/machines/drill.tres"

var _fails: int = 0


func _initialize() -> void:
	print("== stand it on the thing it eats ==")
	_it_draws_where_it_stands()
	_it_pours_down_its_column()
	_it_is_never_blocked()
	_spent_is_not_starved()
	_the_old_model_still_runs()
	_the_preview_says_one_thing()
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
