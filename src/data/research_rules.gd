class_name ResearchRules
extends RefCounted

## THE TECH TREE — the demand-side PULL (docs/PROGRESSION.md §5, "analyze-the-new"). Research happens at
## the Bazaar bench: each tech consumes a SAMPLE of a signature material (analyzing the new thing you
## found — binds research to descent) plus a volume of REFINED goods (the sink that makes the factory's
## output wanted). Researching a tech UNLOCKS crafting its machines. Plain static data like MiningRules:
## the sim's craft-gate, the controller's verb, the HUD's rows, and the headless tests all read this one
## source of truth.
##
## L1 slice: two rungs. `automation` is tutorial-priced (your first ingots become your first research —
## the drill you crave). `power` is the first real WALL (12 ingots) — priced so hand-feeding it aches and
## the just-unlocked drill line is the obvious way to pay. Deeper tiers (L2+ materials, the Descent
## Engine's throughput gate) extend this table — one entry each (docs/PROGRESSION.md §4).
##
## UNGATED on purpose: the forge/splitter (the core loop), the rope (the climb — gating it re-strands
## players), blocks, and tools (MiningRules gates those by material tier instead).
const TECHS: Dictionary = {
	&"automation": {
		"name": "Automation",
		"requires": &"",                       # no prereq — the first rung
		"sample": &"ore",                      # analyze the thing you've been digging
		"cost": {&"ingot": 2},
		"unlocks": [&"drill", &"hopper"],
	},
	&"power": {
		"name": "Power",
		"requires": &"automation",
		"sample": &"coal",                     # analyze the fuel — the L2 twist's key material
		"cost": {&"ingot": 12},
		"unlocks": [&"generator", &"conduit", &"lift"],
	},
	&"descent": {
		"name": "Descent",
		"requires": &"power",
		"sample": &"deepslate",                # mined off the SHELF above the seal (needs the stone pick)
		"cost": {&"ingot": 8},
		"unlocks": [&"descent_engine"],        # the gate-breacher — feed it DESCENT_QUOTA ingots on the seal
	},
	# --- the L2 (Stonereach) tier: iron, the medium chains (docs/PROGRESSION.md §5) ---
	&"ironworks": {
		"name": "Ironworks",
		"requires": &"descent",
		"sample": &"iron",                     # analyze L2's signature ore — you must breach to hold one
		"cost": {&"ingot": 10},
		"unlocks": [&"iron_forge"],            # smelts iron -> iron ingots (the L2 forge)
	},
	&"machining": {
		"name": "Machining",
		"requires": &"ironworks",
		"sample": &"iron_ingot",               # analyze your own first refined iron
		"cost": {&"iron_ingot": 6},            # the first NON-copper research price — iron pays for iron
		"unlocks": [&"plate_press", &"gear_mill", &"h_drill"],   # the crafter modules + the Borer
		                                       # (the Borer is machining's PAYOFF: priced in plates+gears)
	},
}

## Display/keybinding order for the bench rows (explicit, not dict-order-implicit).
const ORDER: Array[StringName] = [&"automation", &"power", &"descent", &"ironworks", &"machining"]


static func tech(id: StringName) -> Dictionary:
	return TECHS.get(id, {})


## The tech that gates crafting `item_id`, or &"" when it's freely craftable. Derived from the unlocks
## lists so the gate can never drift from the tree.
static func locking_tech(item_id: StringName) -> StringName:
	for tid: StringName in TECHS:
		if item_id in (TECHS[tid]["unlocks"] as Array):
			return tid
	return &""


## Is this tech's prerequisite satisfied by the given researched-set (FactorySim.research)?
static func prereq_met(id: StringName, research: Dictionary) -> bool:
	var req: StringName = TECHS.get(id, {}).get("requires", &"")
	return req == &"" or research.has(req)


## The NEXT researchable tech (first un-researched entry in ORDER with its prereq met), or &"" when the
## tree is exhausted. The tree is a linear ladder for now, so ONE bench key (R) is unambiguous; when it
## branches, the bench UI grows a chooser (demand-pull).
static func next_tech(research: Dictionary) -> StringName:
	for tid: StringName in ORDER:
		if not research.has(tid) and prereq_met(tid, research):
			return tid
	return &""
