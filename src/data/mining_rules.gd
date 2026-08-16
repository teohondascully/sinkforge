class_name MiningRules
extends RefCounted

## The MANUAL-MINING rules: how hard each material is to break by hand, and which TOOL you need to
## break it at all. This is the friction layer that makes early-game hand-mining a deliberate PAIN —
## the teacher that makes you crave automation. It is plain static data (no node, no
## sim, no renderer), so the controller's hold-loop, the verb-gate in try_mine, AND the headless tests
## all read the SAME source of truth.
##
## Two questions it answers:
##   1. can_mine(material, inventory) — do you OWN a tool that can break this? (the GATE, in try_mine —
##      so the scripted play-test exercises it: you can't crack stone bare-handed.)
##   2. mine_seconds(material, inventory) — how long HOLDING breaks it, scaled by your best tool's speed
##      (the felt friction, in the controller's charge loop). Better tools = less time = the upgrade pull.
##
## Provisional + eye-tuned (the numbers want play-feel, not a spec). Promote tools to ToolDef resources
## and hardness onto MaterialDef when the tier ladder grows past wood (demand-pull).

## Material id -> the tool CLASS required to break it. Absent = hand-mineable (no tool needed, e.g. dirt
## you can always dig out of a jam). Rock, ore AND foliage all want the pick — the axe was DELETED
## (2026-07-17): tool gates read the whole PACK, not a wielded item, so the axe
## was never a verb — just a phantom key rattling in the pack. One tool, one slot, same chopping.
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

## Material id -> the minimum tool TIER (of its required class) needed to break it. Absent class-gated
## material defaults to tier 1 (any tool of the class). This is the DEPTH GATE: deepslate (the deep band,
## rows ≥ DEEPSLATE_ROW) needs a tier-2 pick, so the starter wood pick (tier 1) bounces off it — you must
## craft a Stone Pickaxe before you can dig the deep third. Grows as the tier ladder deepens.
const REQUIRED_TIER: Dictionary = {
	&"deepslate": 2,
	&"iron": 2,          # L2's ore lives in the deepslate zone — the same pick works both
	&"rich_ore": 2,      # the high-grade veins live in/below the deepslate band (#48) — same honest gate
	&"sealrock": 99,     # THE SEAL is un-hand-mineable by ANY pick, forever: the L1→L2 gate is a
	                     # THROUGHPUT wall — only a fed Descent Engine breaches it (docs/PROGRESSION.md §2)
}

## Material id -> base SECONDS to break with a tier-1 tool (or by hand). Eye-tuned so shallow dirt is
## quick, stone/ore is a real grind, deepslate is brutal — the deeper you go the more you want a drill.
##
## THE ACHE LIVES DEEP (#B1). The SHALLOW band was retuned down hard: the grind that sells automation
## was landing in the first sixty seconds, BEFORE any of its payoff, so a first-timer met only tedium
## (4 ore = six seconds of holding, to open step one). The surface is now loose, weathered ground you
## chew through — and because the DEEP numbers didn't move, the same change SHARPENS the gradient that
## actually teaches: deepslate went from ~2x surface rock to ~3x. You feel the world get harder as you
## sink, instead of feeling it be hard from the first swing.
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

## Tool item id -> {class, tier, speed}. Speed scales the break rate (2.0 = twice as fast = half the
## seconds); TIER gates which materials the tool may break at all (see REQUIRED_TIER). The starter kit is
## the two wood tools (tier 1); the Stone Pickaxe (tier 2) is the first depth-unlocking upgrade, crafted at
## the Bazaar (TOOL_RECIPES) — it's both faster AND the key to the deepslate band. Ladder grows demand-pull.
## THE SPEED AXIS IS DELETED (#S32, `docs/BITS.md` §2). Every pick now cuts at 1.0 and the ladder means one
## thing only: WHAT YOU MAY BITE. A drive is a key, not a stat. It was 1.0 / 1.7 / 2.6, and the source was
## honest about what that bought — "its value today is SPEED (deepslate 1.65s -> 1.08s)" — which is to say
## every upgrade was mostly the old pick, faster. That is the treadmill.
##
## What replaces the retroactive relief a speed bump used to give is the BITS (`BitRules`): a Broad or a
## Lance trivialises old rock four and five cells at a time, and it is a choice you made rather than a
## number that went up. That replacement is load-bearing, and it is why this line could not be flattened
## until the bits existed — without them this change is nothing but "the game is now slower".
const TOOLS: Dictionary = {
	&"wood_pickaxe": {&"class": &"pick", &"tier": 1, &"speed": 1.0},
	&"stone_pickaxe": {&"class": &"pick", &"tier": 2, &"speed": 1.0},
	&"iron_pickaxe": {&"class": &"pick", &"tier": 3, &"speed": 1.0},
	# The wood_axe entry stays ONLY so a pre-#38 save carrying one still renders (glyph/tooltip);
	# it is no longer seeded, required by any material, or craftable.
	&"wood_axe": {&"class": &"axe", &"tier": 1, &"speed": 1.0},
	# The SCANNER is EQUIPMENT, not a breaker: its own class so it never enters a
	# pick/axe speed query, speed 0 (no material requires &"scanner"). Listed here so is_tool_item
	# treats it as gear — it can't be fed into a machine like a resource.
	&"scanner": {&"class": &"scanner", &"tier": 1, &"speed": 0.0},
}

## Craftable tools -> their ingredient cost (spent from the pack, at the Bazaar). Mirrors MachineDef
## .craft_cost so the Bazaar craft screen lists tools alongside machines. The Stone Pickaxe is stone + wood
## — both hand-mineable with the starter pick, so the upgrade is a natural surface-tier craft that then
## unlocks the deep band (the Terraria wood→stone→… tool progression, expressed through our Bazaar hub).
const TOOL_RECIPES: Dictionary = {
	&"stone_pickaxe": {&"stone": 8, &"wood": 3},
	# The tier-3 pick is priced in the L2 chain's own product (iron ingots want the Iron Forge, which
	# wants Ironworks research, which wants the breach) — the MATERIALS gate it, research doesn't need
	# to. Since #S32 its value is purely the rung: tier 3 is what L3's rock band will gate on (no sub-L2
	# band exists yet, so nothing bounces a stone pick that this one opens; that arrives with L3
	# worldgen, demand-pull).
	&"iron_pickaxe": {&"iron_ingot": 6, &"wood": 3},
	# The sonar: cheap in materials, gated by PROSPECTING research instead (the sim's
	# craft_item refuses it until the tech is in — ResearchRules.locking_tech drives the gate).
	&"scanner": {&"ingot": 2, &"coal": 1},
}

## What every new game begins with — ONE bad wooden pick (seeded by MainView into the pack). It digs,
## it chops; its tier-1 slowness is what makes the early grind ache for a drill.
const STARTER_TOOLS: Array[StringName] = [&"wood_pickaxe"]


## The tool class a material needs, or &"" when it's hand-mineable.
static func required_tool(material: StringName) -> StringName:
	return REQUIRED_TOOL.get(material, &"")


## The minimum tool TIER (of the required class) needed to break this material — the depth gate. 0 for a
## hand-mineable material; otherwise REQUIRED_TIER (default 1, so ordinary rock takes any tool of its class).
static func required_tier(material: StringName) -> int:
	if required_tool(material) == &"":
		return 0
	return int(REQUIRED_TIER.get(material, 1))


## The best (highest) TIER among the owned tools of `tool_class`, or 0 if the pack holds none. Compared
## against required_tier to gate mining a material (a wood pick, tier 1, can't crack tier-2 deepslate).
static func best_tier(tool_class: StringName, inventory: Dictionary) -> int:
	var best: int = 0
	for tid: StringName in TOOLS:
		if TOOLS[tid][&"class"] == tool_class and int(inventory.get(tid, 0)) > 0:
			best = maxi(best, int(TOOLS[tid][&"tier"]))
	return best


static func hardness(material: StringName) -> float:
	return float(HARDNESS.get(material, DEFAULT_HARDNESS))


## Is this item one of the equipment TOOLS (a pick/axe), versus a resource? (Named is_tool_ITEM to avoid
## colliding with the built-in Script.is_tool() on the class object.)
static func is_tool_item(item: StringName) -> bool:
	return TOOLS.has(item) or BitRules.is_bit(item)


## The best (fastest) speed among the tools of `tool_class` the pack currently holds, or 0.0 if it holds
## none — 0.0 means "you can't break this material yet" for a class-gated material.
static func best_speed(tool_class: StringName, inventory: Dictionary) -> float:
	var best: float = 0.0
	for tid: StringName in TOOLS:
		if TOOLS[tid][&"class"] == tool_class and int(inventory.get(tid, 0)) > 0:
			best = maxf(best, float(TOOLS[tid][&"speed"]))
	return best


## Can the pack break this material at all? Hand-mineable materials are always true; class-gated ones
## require owning a matching tool OF SUFFICIENT TIER. This is the GATE try_mine enforces, so reach, tool,
## AND depth-tier are all real (a deep deepslate block bounces the starter pick until you upgrade).
static func can_mine(material: StringName, inventory: Dictionary) -> bool:
	var cls: StringName = required_tool(material)
	if cls == &"":
		return true
	return best_tier(cls, inventory) >= required_tier(material)


## Seconds of HOLDING to break this material with the pack's best matching tool. INF when you lack the
## tool (the block won't yield). Hand-mineable materials use the baseline speed of 1.0.
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
