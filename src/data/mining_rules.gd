class_name MiningRules
extends RefCounted

## The MANUAL-MINING rules: how hard each material is to break by hand, and which TOOL is needed to break
## it at all. Plain static data, so the controller's hold loop, the verb gate in try_mine and the headless
## tests read one source of truth. can_mine() is the gate, mine_seconds() the duration. Provisional and
## eye-tuned; promote tools to ToolDef resources and hardness onto MaterialDef past wood.

## Material id -> the tool CLASS required to break it. Absent = hand-mineable. Rock, ore and foliage all
## want the pick; the axe class was deleted 2026-07-17, because tool gates read the whole PACK rather than
## a wielded item, so it added no verb.
const REQUIRED_TOOL: Dictionary = {
	&"stone": &"pick",
	&"ore": &"pick",
	&"coal": &"pick",
	&"deepslate": &"pick",
	&"iron": &"pick",
	&"rich_ore": &"pick",
	&"sealrock": &"pick",
	&"wood": &"pick",
	&"leaves": &"pick",
}

## Material id -> the minimum tool TIER of its required class; absent defaults to 1. The DEPTH GATE:
## deepslate (rows >= DEEPSLATE_ROW) needs a tier-2 pick, so the starter wood pick bounces off it.
const REQUIRED_TIER: Dictionary = {
	&"deepslate": 2,
	&"iron": 2,          # L2's ore lives in the deepslate zone — the same pick works both
	&"rich_ore": 2,      # the high-grade veins live in/below the deepslate band (#48) — same honest gate
	&"sealrock": 99,     # THE SEAL is un-hand-mineable by ANY pick, forever: the L1→L2 gate is a
	                     # THROUGHPUT wall: only a fed Descent Engine breaches it (docs/PROGRESSION.md 2)
}

## Material id -> base SECONDS to break with a tier-1 tool or by hand. Eye-tuned.
## THE ACHE LIVES DEEP (#B1). The SHALLOW band was retuned down hard: the grind that sells automation was
## landing in the first sixty seconds, before any payoff (4 ore = six seconds of holding). The DEEP numbers
## did not move, so deepslate went from ~2x surface rock to ~3x.
const HARDNESS: Dictionary = {
	&"earth": 0.28,
	&"stone": 0.85,
	&"ore": 0.90,
	&"coal": 0.90,
	&"deepslate": 2.80,      # the deep band is UNTOUCHED — this is where the drill-hunger belongs
	&"iron": 3.0,
	&"rich_ore": 2.4,
	&"wood": 0.50,
	&"leaves": 0.10,
}
const DEFAULT_HARDNESS: float = 0.50

## Tool item id -> {class, tier, speed}. Speed scales the break rate (2.0 = twice as fast); TIER gates which
## materials the tool may break at all (see REQUIRED_TIER). Starter kit is the wood tools at tier 1; the
## Stone Pickaxe at tier 2 is the first depth-unlocking upgrade.
##
## THE SPEED AXIS IS DELETED (#S32, `docs/BITS.md` 2). Every pick cuts at 1.0 and the ladder means only WHAT
## MAY BE BITTEN. The old values were 1.0 / 1.7 / 2.6 (deepslate 1.65s -> 1.08s). The BITS (`BitRules`)
## replace that relief: a Broad or Lance clears old rock four and five cells at a time.
const TOOLS: Dictionary = {
	&"wood_pickaxe": {&"class": &"pick", &"tier": 1, &"speed": 1.0},
	&"stone_pickaxe": {&"class": &"pick", &"tier": 2, &"speed": 1.0},
	&"iron_pickaxe": {&"class": &"pick", &"tier": 3, &"speed": 1.0},
	# The wood_axe entry stays ONLY so a pre-#38 save carrying one still renders; it is no longer seeded,
	# required by any material, or craftable.
	&"wood_axe": {&"class": &"axe", &"tier": 1, &"speed": 1.0},
	# The SCANNER is equipment, not a breaker: its own class so it never enters a pick/axe speed query, speed 0,
	# no material requires it. Listed so is_tool_item treats it as gear rather than a machine input.
	&"scanner": {&"class": &"scanner", &"tier": 1, &"speed": 0.0},
}

## Craftable tools -> ingredient cost, spent from the pack at the Bazaar. Mirrors MachineDef.craft_cost so
## the craft screen lists tools alongside machines. The Stone Pickaxe costs stone and wood, both
## hand-mineable with the starter pick.
const TOOL_RECIPES: Dictionary = {
	&"stone_pickaxe": {&"stone": 8, &"wood": 3},
	# The tier-3 pick is priced in the L2 chain's own product: iron ingots need the Iron Forge, which needs
	# Ironworks research, which needs the breach, so the MATERIALS gate it and no research lock is set. L3's
	# rock band will gate on tier 3; nothing below L2 bounces a stone pick.
	&"iron_pickaxe": {&"iron_ingot": 6, &"wood": 3},
	# The sonar: cheap in materials, gated by PROSPECTING research instead. craft_item refuses it until the
	# tech is in; ResearchRules.locking_tech drives the gate.
	&"scanner": {&"ingot": 2, &"coal": 1},
}

## What every new game begins with: one wooden pick, seeded by MainView into the pack.
const STARTER_TOOLS: Array[StringName] = [&"wood_pickaxe"]


## The tool class a material needs, or &"" when it's hand-mineable.
static func required_tool(material: StringName) -> StringName:
	return REQUIRED_TOOL.get(material, &"")


## Minimum tool TIER of the required class. 0 for a hand-mineable material, else REQUIRED_TIER, default 1.
static func required_tier(material: StringName) -> int:
	if required_tool(material) == &"":
		return 0
	return int(REQUIRED_TIER.get(material, 1))


## Highest TIER among owned tools of `tool_class`, or 0 if the pack holds none. Compared against required_tier.
static func best_tier(tool_class: StringName, inventory: Dictionary) -> int:
	var best: int = 0
	for tid: StringName in TOOLS:
		if TOOLS[tid][&"class"] == tool_class and int(inventory.get(tid, 0)) > 0:
			best = maxi(best, int(TOOLS[tid][&"tier"]))
	return best


## Display names for the drives, so the hover refusal line, the skid's tell and the craft screen agree.
const TOOL_NAMES: Dictionary = {
	&"wood_pickaxe": "Wood Pickaxe",
	&"stone_pickaxe": "Stone Pickaxe",
	&"iron_pickaxe": "Iron Pickaxe",
	&"wood_axe": "Wood Axe",
	&"scanner": "Scanner",
}


static func tool_name(id: StringName) -> String:
	return str(TOOL_NAMES.get(id, str(id).capitalize()))


## The lowest-tier tool of the required class that can bite this rock, or &"" when hand-mineable. A refusal
## must NAME the rung (`docs/BITS.md` 5) from the same table the gate reads. Deterministic: TOOLS is iterated
## in declaration order and the lowest sufficient tier wins.
static func drive_for(material: StringName) -> StringName:
	var cls: StringName = required_tool(material)
	if cls == &"":
		return &""
	var need: int = required_tier(material)
	var best: StringName = &""
	var best_tier_seen: int = 9999
	for tid: StringName in TOOLS:
		if TOOLS[tid][&"class"] != cls:
			continue
		var tier: int = int(TOOLS[tid][&"tier"])
		if tier >= need and tier < best_tier_seen:
			best = tid
			best_tier_seen = tier
	return best


static func hardness(material: StringName) -> float:
	return float(HARDNESS.get(material, DEFAULT_HARDNESS))


## Is this item equipment (a pick/axe) rather than a resource? Named is_tool_ITEM to avoid colliding with
## the built-in Script.is_tool().
static func is_tool_item(item: StringName) -> bool:
	return TOOLS.has(item) or BitRules.is_bit(item)


## Fastest speed among the pack's tools of `tool_class`, or 0.0 if none. For a class-gated material, 0.0
## means it cannot be broken yet.
static func best_speed(tool_class: StringName, inventory: Dictionary) -> float:
	var best: float = 0.0
	for tid: StringName in TOOLS:
		if TOOLS[tid][&"class"] == tool_class and int(inventory.get(tid, 0)) > 0:
			best = maxf(best, float(TOOLS[tid][&"speed"]))
	return best


## Can the pack break this material at all? Hand-mineable materials always; class-gated ones require a
## matching tool OF SUFFICIENT TIER. The gate try_mine enforces.
static func can_mine(material: StringName, inventory: Dictionary) -> bool:
	var cls: StringName = required_tool(material)
	if cls == &"":
		return true
	return best_tier(cls, inventory) >= required_tier(material)


## Seconds of HOLDING to break this material with the pack's best matching tool, INF when the tool is
## missing. Hand-mineable materials use the baseline speed of 1.0.
static func mine_seconds(material: StringName, inventory: Dictionary) -> float:
	var cls: StringName = required_tool(material)
	if cls == &"":
		return hardness(material)
	if not can_mine(material, inventory):
		return INF                                # lacking the tool OR the required tier → it won't yield
	var spd: float = best_speed(cls, inventory)
	if spd <= 0.0:
		return INF
	return hardness(material) / spd
