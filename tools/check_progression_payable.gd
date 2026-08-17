extends SceneTree

## Harness layer: THE TREE IS PAYABLE IN THE ORDER YOU CLIMB IT.
##
## A research rung priced in an item you cannot make yet is a SOFTLOCK, and it is the specific kind of
## softlock nothing else here would catch: every unit test passes, every play-test that injects its own
## resources passes, the sim is perfectly correct, and the player simply cannot continue. `check_score`
## and the play-tests drive the arc with equipment handed to them; they prove the verbs work, not that
## the economy pays for itself.
##
## The rule: for every rung, the items its cost names must be producible using ONLY machines reachable
## from that rung's own prerequisite chain. Same for the craft cost of every machine a rung unlocks —
## unlocking a machine you cannot afford to build is the same defect wearing a different hat.
##
## This is data, not behaviour: `ResearchRules.TECHS` plus the machine `.tres` files plus their recipes.
## No scene, no window, no tick. It costs milliseconds, which is the point — a structural guard nobody
## minds running.
##
## IT ALSO PINS THE ECONOMY'S SHAPE (docs/MATERIAL_SPINE.md §5, F1). `gear` and `plate` are TERMINAL:
## produced by recipes, consumed by nothing except one-off machine construction. That is the largest
## structural gap in the game — once you own one of each machine the factory has nothing left to make —
## and it is recorded here as a ratchet rather than as prose. The assertion is a SUBSET check, so
## removing a dead end (giving gear a consumer) passes happily and only ADDING one goes red. It ratchets
## against getting worse, never against getting better.
##
## Run: godot --headless --path . --script res://tools/check_progression_payable.gd

const MACHINE_DIR: String = "res://src/data/machines/"
const MATERIAL_DIR: String = "res://src/data/materials/"
## Read rather than listed, so it cannot drift from what the world actually builds for you.
const SEEDER_SRC: String = "res://scenes/world_seeder.gd"

## Items produced by a recipe and consumed by no recipe. See the header: subset, not equality.
const KNOWN_TERMINAL: Array[StringName] = [&"gear", &"plate"]

var _failures: int = 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)


func _initialize() -> void:
	print("== the tree is payable in order ==")
	var machines: Array[MachineDef] = _machines()
	var raw: Dictionary = _raw_items()
	_check(machines.size() >= 15, "the machine catalogue was read (%d defs)" % machines.size())
	_check(raw.size() >= 10, "the material catalogue was read (%d raw items)" % raw.size())
	var rungs: Array = ResearchRules.ORDER
	_check(rungs.size() >= 8, "the research tree was read (%d rungs)" % rungs.size())

	var free: Dictionary = _seeded()
	_bootstrap(machines, raw, free)
	_payable(machines, raw, rungs, free)
	_terminal(machines, raw)

	if _failures == 0:
		print("check_progression_payable: PASS — every rung can be paid for by the time you reach it")
		quit(0)
	else:
		printerr("check_progression_payable: %d FAILURE(S)" % _failures)
		quit(1)


func _machines() -> Array[MachineDef]:
	var out: Array[MachineDef] = []
	for f: String in DirAccess.get_files_at(MACHINE_DIR):
		if not f.ends_with(".tres"):
			continue
		var d: MachineDef = load(MACHINE_DIR + f) as MachineDef
		if d != null:
			out.append(d)
	return out


## Everything the WORLD can hand you directly. `mine()` returns the material id of whatever broke, so
## every authored material is obtainable by hand — which is exactly the base case a payability walk needs.
func _raw_items() -> Dictionary:
	var out: Dictionary = {}
	for f: String in DirAccess.get_files_at(MATERIAL_DIR):
		if not f.ends_with(".tres"):
			continue
		var d: MaterialDef = load(MATERIAL_DIR + f) as MaterialDef
		if d != null:
			out[d.id] = true
	return out


## Every tech on `id`'s prerequisite chain, including itself.
func _chain(id: StringName) -> Dictionary:
	var out: Dictionary = {}
	var at: StringName = id
	while at != &"" and not out.has(at):
		out[at] = true
		at = ResearchRules.tech(at).get("requires", &"")
	return out


## What you can HOLD once `researched` is done: raw materials, plus the output of every recipe whose
## machine is either ungated or gated behind a tech you already have. Fixed-point, because one recipe's
## output is the next one's input — iron_ingot is only producible once the Iron Forge is, and gear is only
## producible once iron_ingot is.
func _producible(machines: Array[MachineDef], raw: Dictionary, researched: Dictionary,
		free: Dictionary) -> Dictionary:
	var have: Dictionary = raw.duplicate()
	var grew: bool = true
	while grew:
		grew = false
		for m: MachineDef in machines:
			if m.recipe == null:
				continue
			var gate: StringName = ResearchRules.locking_tech(m.id)
			if gate != &"" and not researched.has(gate):
				continue
			# …and you must be able to BUILD it before it can make anything for you — UNLESS the world
			# already built it for you. That exception is not a convenience; see `_bootstrap`.
			if not free.has(m.id) and not _affordable(m.craft_cost, have):
				continue
			if not _affordable((m.recipe as RecipeDef).inputs, have):
				continue
			for item: Variant in (m.recipe as RecipeDef).outputs:
				if not have.has(item):
					have[StringName(item)] = true
					grew = true
	return have


## The machines the WORLD stands up for you, read out of the seeder's source so this can never drift from
## what actually gets placed. `place_machine(load("res://src/data/machines/X.tres"), …)`.
func _seeded() -> Dictionary:
	var out: Dictionary = {}
	var src: String = FileAccess.get_file_as_string(SEEDER_SRC)
	var re := RegEx.create_from_string("place_machine\\(load\\(\"res://src/data/machines/([a-z_]+)\\.tres\"")
	for m: RegExMatch in re.search_all(src):
		out[StringName(m.get_string(1))] = true
	return out


## THE BOOTSTRAP, which is the most interesting thing this layer found and the reason it exists in this
## shape. The economy has a chicken-and-egg at its very first step: `ingot` can only be made by the
## Processor, and the Processor costs 3 ingots. From raw materials alone the tree is UNREACHABLE — not
## slow, not grindy, impossible — and every rung above it falls with it.
##
## What breaks the loop is that `world_seeder` PLACES two Processors, already built, for free. That is the
## single load-bearing gift in the whole game, and nothing anywhere asserted it. Delete those two lines
## and a fresh save is unwinnable while every existing test stays green: the sim is correct, the recipes
## are correct, the play-tests inject their own resources and never notice.
##
## So both halves are asserted — that the gift exists, and that it is genuinely required.
func _bootstrap(machines: Array[MachineDef], raw: Dictionary, free: Dictionary) -> void:
	print("== the bootstrap ==")
	_check(not free.is_empty(), "the world stands up machines for you%s"
		% (": " + ", ".join(PackedStringArray(free.keys())) if not free.is_empty() else
			" — but it stands up NONE. world_seeder places no machine, so a fresh game starts with no way\n"
			+ "         to smelt and the tree below is unreachable from the first rung. If you moved the\n"
			+ "         bootstrap somewhere else, this layer reads it out of "
			+ SEEDER_SRC + " by regex; point it at the new home."))
	var without: Dictionary = _producible(machines, raw, {}, {})
	var with_gift: Dictionary = _producible(machines, raw, {}, free)
	_check(not without.has(&"ingot"),
		"WITHOUT that gift the first ingot is unreachable — the Processor that makes ingots costs ingots")
	_check(with_gift.has(&"ingot"),
		"…and WITH it the loop opens, which is the whole job the seeded forge is doing")


func _affordable(cost: Dictionary, have: Dictionary) -> bool:
	for item: Variant in cost:
		if not have.has(item):
			return false
	return true


func _missing(cost: Dictionary, have: Dictionary) -> String:
	var out: Array[String] = []
	for item: Variant in cost:
		if not have.has(item):
			out.append(String(item))
	return ", ".join(out)


## THE WALK. Climb the tree in its own declared order and check that each rung, and everything it hands
## you, can be paid for with what the rungs below it made possible.
func _payable(machines: Array[MachineDef], raw: Dictionary, rungs: Array, free: Dictionary) -> void:
	print("== every rung, paid for by the rungs below it ==")
	var by_id: Dictionary = {}
	for m: MachineDef in machines:
		by_id[m.id] = m
	for r: Variant in rungs:
		var id: StringName = r
		var tech: Dictionary = ResearchRules.tech(id)
		# What you can make with everything BELOW this rung — the rung itself is not paid for by its own
		# unlocks, which is the circularity this catches.
		var below: Dictionary = _chain(id)
		below.erase(id)
		var have: Dictionary = _producible(machines, raw, below, free)

		var cost: Dictionary = tech.get("cost", {})
		_check(_affordable(cost, have),
			"\"%s\" costs %s and you can make all of it by the time you get there%s"
				% [id, _cost_str(cost), "" if _affordable(cost, have) else " — MISSING " + _missing(cost, have)])

		# The SAMPLE is a material you must be holding to analyze; it is a real gate too.
		var sample: StringName = tech.get("sample", &"")
		if sample != &"":
			_check(have.has(sample), "…and its sample (%s) is something you can be holding" % sample)

		# Everything the rung hands you must be buildable with what the rung itself makes possible.
		var after: Dictionary = _producible(machines, raw, _chain(id), free)
		for u: Variant in (tech.get("unlocks", []) as Array):
			var uid: StringName = u
			if not by_id.has(uid):
				continue          # a non-machine unlock (the scanner is a tool, not a placeable)
			var mdef: MachineDef = by_id[uid]
			_check(_affordable(mdef.craft_cost, after),
				"…and the %s it unlocks costs %s, which you can also make%s"
					% [uid, _cost_str(mdef.craft_cost),
						"" if _affordable(mdef.craft_cost, after) else " — MISSING " + _missing(mdef.craft_cost, after)])


func _cost_str(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for item: Variant in cost:
		parts.append("%dx %s" % [int(cost[item]), String(item)])
	return " + ".join(parts) if not parts.is_empty() else "nothing"


## THE DEAD ENDS. Produced by a recipe, consumed by no recipe. See the header — this is F1 of
## docs/MATERIAL_SPINE.md made executable, as a subset ratchet: a NEW dead end fails, and fixing an old
## one passes.
func _terminal(machines: Array[MachineDef], _raw: Dictionary) -> void:
	var produced: Dictionary = {}
	var consumed: Dictionary = {}
	for m: MachineDef in machines:
		if m.recipe == null:
			continue
		var rec: RecipeDef = m.recipe
		for o: Variant in rec.outputs:
			produced[StringName(o)] = true
		for i: Variant in rec.inputs:
			consumed[StringName(i)] = true
	_check(produced.size() >= 4, "the recipe graph produces something to analyse (%d items)" % produced.size())

	var terminal: Array[String] = []
	for p: Variant in produced:
		if not consumed.has(p):
			terminal.append(String(p))
	terminal.sort()
	print("  produced: %d · consumed by another recipe: %d · DEAD ENDS: %s"
		% [produced.size(), consumed.size(), ", ".join(terminal) if not terminal.is_empty() else "none"])

	var known: Array[String] = []
	for k: StringName in KNOWN_TERMINAL:
		known.append(String(k))
	var surprises: Array[String] = []
	for t: String in terminal:
		if not known.has(t):
			surprises.append(t)
	# THE FAILURE MESSAGE IS PART OF THE GUARD. Whoever trips this will have just added a recipe and will
	# want to know whether they broke a rule or merely widened a known problem — so it says which, and what
	# the sanctioned move is. A ratchet that reads as "you broke it" gets edited away by the next person.
	_check(surprises.is_empty(),
		"no NEW dead end entered the economy%s"
			% ("" if surprises.is_empty() else
				" — %s produced and consumed by nothing.\n"
				% ", ".join(surprises)
				+ "         This is a RATCHET on docs/MATERIAL_SPINE.md F1, not a ban on new items. gear and\n"
				+ "         plate are already dead ends and the game is poorer for it: once you own one of each\n"
				+ "         machine the factory has nothing left to make. Adding another widens that gap.\n"
				+ "         SANCTIONED MOVES, in order of preference:\n"
				+ "           1. give the item a consumer — some recipe takes it as an input. The ratchet then\n"
				+ "              passes on its own and you have made the spine deeper rather than wider.\n"
				+ "           2. if it is deliberately terminal and you can say why, add it to KNOWN_TERMINAL\n"
				+ "              in this file WITH that reason, and update MATERIAL_SPINE.md F1 to match.\n"
				+ "         Removing a dead end never trips this — the check is a subset, not an equality."))
