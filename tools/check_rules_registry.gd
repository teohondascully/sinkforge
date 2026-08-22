extends "res://tools/check_base.gd"

## CONTRACT GUARD — the hand-kept rule tables agree with each other and with the materials on disk.
##
## `check_material_registry` and `check_craftable_registry` each guard ONE table against the world. This is
## the third of that family and it guards the tables against EACH OTHER, which is the failure the other two
## cannot see: every individual table can be internally fine while two of them disagree about the same id.
##
## The tables are `MiningRules` (HARDNESS, REQUIRED_TOOL, REQUIRED_TIER, TOOLS, TOOL_RECIPES, TOOL_NAMES,
## STARTER_TOOLS), `BitRules` (BITS, BIT_RECIPES) and `ResearchRules` (TECHS, ORDER). Nine dictionaries
## keyed by id, maintained by hand, with no compiler and no schema between them. A tool in TOOLS with no
## TOOL_NAMES entry renders as a capitalised id; a bit in BITS with no recipe is uncraftable and says
## nothing about why; a tech in TECHS missing from ORDER never appears on the research screen at all. None
## of those crash, and none of them are visible from inside the table that is wrong.
##
## WHAT THIS LAYER LEARNED BEFORE IT WAS WRITTEN, which is the reason it is shaped the way it is. A first
## pass over these tables reported THIRTEEN inconsistencies. Every one was a false positive, and the two
## causes are worth naming because both are easy to repeat:
##
##   * NINE were a namespace confusion in the checker, not in the data. `REQUIRED_TOOL` maps a material to
##     a tool CLASS (&"pick"); `TOOLS` is keyed by tool ID (&"stone_pickaxe") with the class in a field.
##     Asking whether &"pick" is in TOOLS is asking the wrong dictionary the wrong question.
##   * FOUR were deliberate absences already documented at the table: `wood_axe` is kept only so an older
##     save still renders, and the Point is the bit you have when the pack is empty, so neither wants a
##     recipe.
##
## So the exemptions below are NAMED WITH REASONS rather than silently skipped, and the checks are written
## against the real schema. A gate wrong about its own hits is worse than no gate: it trains a reader to
## dismiss it, and the one true hit arrives looking exactly like the twelve false ones.

const MATERIAL_DIR: String = "res://src/data/materials/"

## Materials that deliberately take `MiningRules.DEFAULT_HARDNESS` instead of a HARDNESS row, with the
## reason each one is allowed to. The point of listing them is that a NEW material which forgets its
## hardness fires this gate, while these seven do not: an exemption nobody prints is a licence.
##
## The wall family is the background plane behind the world. You never swing at it and it is never carried,
## so its break cost is not a quantity the game asks for. `gravel` is loose fill and the default IS what
## loose fill should cost. `sealrock` is the L1->L2 gate at REQUIRED_TIER 99, which no pick reaches, so its
## hardness is unreachable rather than unset -- the assertion below proves that rather than assuming it.
##
## `shale` is the one on this list that is a judgement rather than a fact, and it is recorded as such: it
## is a real band material, deeper than stone, and it takes 0.50 against stone's 0.85. Fissile rock being
## softer than the stone above it is defensible geology and it has never been decided in writing. Listed
## here so that the decision is visible; this layer does not have an opinion on what the number should be.
const DEFAULT_HARDNESS_OK: Dictionary = {
	&"deepslate_wall": "background wall plane, never a mining target",
	&"dirt_wall": "background wall plane, never a mining target",
	&"shale_wall": "background wall plane, never a mining target",
	&"stone_wall": "background wall plane, never a mining target",
	&"gravel": "loose fill; the default is what loose fill should cost",
	&"shale": "takes the default deliberately, recorded rather than decided -- see the note above",
	&"sealrock": "REQUIRED_TIER 99, so no pick reaches the hardness lookup at all",
}

## Tools that exist without a recipe, and why. Everything else in TOOLS must be craftable or seeded.
const NO_RECIPE_TOOLS: Dictionary = {
	&"wood_axe": "kept only so an older save carrying one still renders; not seeded, required or craftable",
}


func _initialize() -> void:
	print("== the hand-kept tables agree ==")
	_materials()
	_tool_classes()
	_tools()
	_bits()
	_techs()
	if _failures == 0:
		print("check_rules_registry: PASS — nine hand-kept tables, no id in one that another disowns")
		quit(0)
	else:
		printerr("check_rules_registry: FAIL — %d failure(s)" % _failures)
		quit(1)


## Every id the mining tables key on is a material that exists, and every material either has a hardness
## or is a named exemption.
func _materials() -> void:
	var on_disk: Dictionary = {}
	for f: String in DirAccess.get_files_at(MATERIAL_DIR):
		if not f.ends_with(".tres"):
			continue
		var def: MaterialDef = load(MATERIAL_DIR + f)
		if def != null:
			on_disk[def.id] = true
	_check(on_disk.size() > 0, "there are authored materials on disk to check (%d)" % on_disk.size())

	# A KEY THAT NAMES NOTHING IS THE QUIET ONE. `hardness()` and `required_tool()` both fall through to a
	# default on a miss, so a typo'd key does not fail -- it stops applying, and the material it was meant
	# for silently becomes ordinary rock.
	var keyed: int = 0
	for pair: Array in [["HARDNESS", MiningRules.HARDNESS], ["REQUIRED_TOOL", MiningRules.REQUIRED_TOOL],
			["REQUIRED_TIER", MiningRules.REQUIRED_TIER]]:
		for id: Variant in (pair[1] as Dictionary):
			keyed += 1
			_check(on_disk.has(id),
				"%s keys on &\"%s\", which is a material that exists" % [pair[0], String(id)])
	_check(keyed > 0, "the guard actually walked the mining tables (%d keys)" % keyed)

	# ...AND THE MATERIALS WITH NO HARDNESS ROW ARE THE ONES WE SAID THEY WERE.
	var inv: Dictionary = {}
	for t: Variant in MiningRules.TOOLS:
		inv[t] = 1
	var defaulted: int = 0
	for id2: Variant in on_disk:
		if MiningRules.HARDNESS.has(id2):
			continue
		defaulted += 1
		_check(DEFAULT_HARDNESS_OK.has(id2),
			"&\"%s\" has no HARDNESS row, and is on the named list of materials allowed to take the"
				% String(id2) + " default (add a row, or add it to DEFAULT_HARDNESS_OK with a reason)")
	_check(defaulted == DEFAULT_HARDNESS_OK.size(),
		"the exemption list is exactly the materials that use it: %d listed, %d actually defaulting"
			% [DEFAULT_HARDNESS_OK.size(), defaulted])

	# The sealrock reason is a REACHABILITY claim, so it is asserted rather than believed. With every tool
	# in the pack at once, nothing may mine it -- which is what makes its missing hardness harmless.
	_check(not MiningRules.can_mine(&"sealrock", inv),
		"sealrock is unmineable with EVERY tool in the pack, so its absent hardness is unreachable rather"
			+ " than unset")


## Every tool class a material demands is a class some tool actually has, at a tier some tool reaches.
func _tool_classes() -> void:
	var by_class: Dictionary = {}
	for id: Variant in MiningRules.TOOLS:
		var t: Dictionary = MiningRules.TOOLS[id]
		var cls: StringName = t.get(&"class", &"")
		by_class[cls] = maxi(int(by_class.get(cls, 0)), int(t.get(&"tier", 0)))
	_check(by_class.size() > 0, "TOOLS declares at least one class (%d)" % by_class.size())

	# CLASS, NOT ID. REQUIRED_TOOL names a class; TOOLS is keyed by id and carries the class in a field.
	# Confusing the two is what made a first pass at this layer report nine failures that were not there.
	var walked: int = 0
	for mat: Variant in MiningRules.REQUIRED_TOOL:
		walked += 1
		var need: StringName = MiningRules.REQUIRED_TOOL[mat]
		_check(by_class.has(need),
			"&\"%s\" needs a &\"%s\" and some tool is one" % [String(mat), String(need)])
		# AND A TIER THAT EXISTS, except where being unreachable is the design. sealrock's 99 is the
		# L1->L2 gate: it is meant to bounce every pick, forever.
		if by_class.has(need) and mat != &"sealrock":
			_check(int(by_class[need]) >= MiningRules.required_tier(mat),
				"...and at tier %d, which some %s reaches (best is %d)"
					% [MiningRules.required_tier(mat), String(need), int(by_class[need])])
	_check(walked > 0, "the guard actually walked REQUIRED_TOOL (%d)" % walked)


## Names and recipes describe tools that exist, and every tool is nameable and obtainable.
func _tools() -> void:
	for pair: Array in [["TOOL_NAMES", MiningRules.TOOL_NAMES], ["TOOL_RECIPES", MiningRules.TOOL_RECIPES]]:
		for id: Variant in (pair[1] as Dictionary):
			_check(MiningRules.TOOLS.has(id),
				"%s names &\"%s\", which is a tool that exists" % [pair[0], String(id)])
	for id2: Variant in MiningRules.STARTER_TOOLS:
		_check(MiningRules.TOOLS.has(id2),
			"STARTER_TOOLS seeds &\"%s\", which is a tool that exists" % String(id2))

	var walked: int = 0
	for id3: Variant in MiningRules.TOOLS:
		walked += 1
		# A MISSING NAME DOES NOT CRASH, it renders as a capitalised id, which reads as a placeholder in
		# the one place a player is deciding what to buy.
		_check(MiningRules.TOOL_NAMES.has(id3),
			"&\"%s\" has a display name, so the craft screen does not print its id" % String(id3))
		var obtainable: bool = MiningRules.TOOL_RECIPES.has(id3) or MiningRules.STARTER_TOOLS.has(id3)
		_check(obtainable or NO_RECIPE_TOOLS.has(id3),
			"&\"%s\" is craftable, seeded, or a named exception" % String(id3))
	_check(walked > 0, "the guard actually walked TOOLS (%d)" % walked)


## Bits and their recipes name each other.
func _bits() -> void:
	var walked: int = 0
	for b: Variant in BitRules.BITS:
		walked += 1
		# The Point is what you are holding when the pack is empty, so it is the one bit that must NOT
		# need buying. Everything else is a purchase and wants a price.
		_check(BitRules.BIT_RECIPES.has(b) or b == BitRules.POINT,
			"bit &\"%s\" has a recipe, or is the Point you always have" % String(b))
	for r: Variant in BitRules.BIT_RECIPES:
		_check(BitRules.BITS.has(r), "BIT_RECIPES prices &\"%s\", which is a bit that exists" % String(r))
	_check(walked > 0, "the guard actually walked BITS (%d)" % walked)


## The tech table and the screen's display order are the same set, both directions.
func _techs() -> void:
	var walked: int = 0
	for t: Variant in ResearchRules.TECHS:
		walked += 1
		# A tech absent from ORDER is researched by the sim and invisible on the screen, which is the
		# worst of the two directions: the cost is charged and nothing says what for.
		_check(ResearchRules.ORDER.has(t),
			"tech &\"%s\" appears in ORDER, so the research screen can show it" % String(t))
	for o: Variant in ResearchRules.ORDER:
		_check(ResearchRules.TECHS.has(o),
			"ORDER lists &\"%s\", which is a tech that exists" % String(o))
	_check(walked > 0, "the guard actually walked TECHS (%d)" % walked)
