# GENERATED FILE -- do not edit by hand.
# Source: data/recipes/*.yaml. Regenerate with:
#   python3 tools/data_codegen/generate.py
# tools/data_codegen/generate.py --check is a CI gate (docs/QUALITY.md gate 22) that fails if
# this file is stale relative to its source. docs/adr/0004-data-codegen.md has the full contract.
class_name RecipesRecords
extends RefCounted

const RECORDS: Dictionary = {
	"mill_gear": {
		"id": "mill_gear",
		"inputs": {
			"iron_ingot": 1,
			"ingot": 1,
		},
		"outputs": {
			"gear": 2,
		},
		"time_ticks": 50,
	},
	"mine_ore": {
		"id": "mine_ore",
		"inputs": {},
		"outputs": {
			"ore": 1,
		},
		"time_ticks": 20,
	},
	"press_plate": {
		"id": "press_plate",
		"inputs": {
			"iron_ingot": 2,
		},
		"outputs": {
			"plate": 1,
		},
		"time_ticks": 60,
	},
	"smelt_ingot": {
		"id": "smelt_ingot",
		"inputs": {
			"ore": 2,
		},
		"outputs": {
			"ingot": 1,
		},
		"time_ticks": 40,
	},
	"smelt_iron": {
		"id": "smelt_iron",
		"inputs": {
			"iron": 2,
		},
		"outputs": {
			"iron_ingot": 1,
		},
		"time_ticks": 50,
	},
	"smelt_rich": {
		"id": "smelt_rich",
		"inputs": {
			"rich_ore": 1,
		},
		"outputs": {
			"ingot": 2,
		},
		"time_ticks": 44,
	},
}
