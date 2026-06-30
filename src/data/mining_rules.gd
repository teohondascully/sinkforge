class_name MiningRules
extends RefCounted

## The MANUAL-MINING rules: how hard each material is to break by hand, and which TOOL you need to
## break it at all. This is the friction layer that makes early-game hand-mining a deliberate PAIN —
## the teacher that makes you crave automation (docs/MINING.md). It is plain static data (no node, no
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
## you can always dig out of a jam). Rock/ore want a pick; foliage wants an axe.
const REQUIRED_TOOL: Dictionary = {
	&"stone": &"pick",
	&"ore": &"pick",
	&"coal": &"pick",
	&"deepslate": &"pick",
	&"wood": &"axe",
	&"leaves": &"axe",
}

## Material id -> base SECONDS to break with a tier-1 tool (or by hand). Eye-tuned so shallow dirt is
## quick, stone/ore is a real grind, deepslate is brutal — the deeper you go the more you want a drill.
const HARDNESS: Dictionary = {
	&"earth": 0.40,
	&"stone": 1.30,
	&"ore": 1.50,
	&"coal": 1.50,
	&"deepslate": 2.80,
	&"wood": 0.70,
	&"leaves": 0.10,
}
const DEFAULT_HARDNESS: float = 0.50

## Tool item id -> {class, speed}. Speed scales the break rate (2.0 = twice as fast = half the seconds).
## The starter kit is the two wood tools at tier-1 speed; better picks/axes slot in here later.
const TOOLS: Dictionary = {
	&"wood_pickaxe": {&"class": &"pick", &"speed": 1.0},
	&"wood_axe": {&"class": &"axe", &"speed": 1.0},
}

## The two tools every new game begins with — a bad pick + a bad axe (seeded by MainView into the pack).
const STARTER_TOOLS: Array[StringName] = [&"wood_pickaxe", &"wood_axe"]


## The tool class a material needs, or &"" when it's hand-mineable.
static func required_tool(material: StringName) -> StringName:
	return REQUIRED_TOOL.get(material, &"")


static func hardness(material: StringName) -> float:
	return float(HARDNESS.get(material, DEFAULT_HARDNESS))


## Is this item one of the equipment TOOLS (a pick/axe), versus a resource? (Named is_tool_ITEM to avoid
## colliding with the built-in Script.is_tool() on the class object.)
static func is_tool_item(item: StringName) -> bool:
	return TOOLS.has(item)


## The best (fastest) speed among the tools of `tool_class` the pack currently holds, or 0.0 if it holds
## none — 0.0 means "you can't break this material yet" for a class-gated material.
static func best_speed(tool_class: StringName, inventory: Dictionary) -> float:
	var best: float = 0.0
	for tid: StringName in TOOLS:
		if TOOLS[tid][&"class"] == tool_class and int(inventory.get(tid, 0)) > 0:
			best = maxf(best, float(TOOLS[tid][&"speed"]))
	return best


## Can the pack break this material at all? Hand-mineable materials are always true; class-gated ones
## require owning a matching tool. This is the GATE try_mine enforces, so reach + tool are both real.
static func can_mine(material: StringName, inventory: Dictionary) -> bool:
	var cls: StringName = required_tool(material)
	if cls == &"":
		return true
	return best_speed(cls, inventory) > 0.0


## Seconds of HOLDING to break this material with the pack's best matching tool. INF when you lack the
## tool (the block won't yield). Hand-mineable materials use the baseline speed of 1.0.
static func mine_seconds(material: StringName, inventory: Dictionary) -> float:
	var cls: StringName = required_tool(material)
	if cls == &"":
		return hardness(material)
	var spd: float = best_speed(cls, inventory)
	if spd <= 0.0:
		return INF
	return hardness(material) / spd
