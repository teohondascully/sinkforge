# GENERATED FILE -- do not edit by hand.
# Source: data/progression/*.yaml. Regenerate with:
#   python3 tools/data_codegen/generate.py
# tools/data_codegen/generate.py --check is a CI gate (docs/QUALITY.md gate 22) that fails if
# this file is stale relative to its source. docs/adr/0004-data-codegen.md has the full contract.
class_name ProgressionRecords
extends RefCounted

const RECORDS: Dictionary = {
	"d1": {
		"id": "d1",
		"order": 1,
		"wants": {
			"ingot": 2,
		},
		"grants": {
			"drill": 1,
		},
		"goal": "Deliver 2 ingots to the rig",
	},
	"d2": {
		"id": "d2",
		"order": 2,
		"wants": {
			"ingot": 6,
		},
		"grants": {
			"winch_head": 1,
			"winch_station": 1,
		},
		"goal": "Deliver 6 ingots to the rig",
	},
	"d3": {
		"id": "d3",
		"order": 3,
		"wants": {
			"ore_copper": 10,
		},
		"grants": {
			"rope": 8,
			"torch": 4,
			"sapling": 3,
		},
		"goal": "Deliver 10 copper ore to the rig",
	},
	"d4": {
		"id": "d4",
		"order": 4,
		"wants": {
			"ingot": 12,
		},
		"grants": {
			"iron_forge": 1,
			"conduit": 6,
		},
		"goal": "Deliver 12 ingots to the rig",
	},
	"d5": {
		"id": "d5",
		"order": 5,
		"wants": {
			"iron_ingot": 4,
		},
		"grants": {
			"gear_mill": 1,
			"plate_press": 1,
		},
		"goal": "Deliver 4 iron ingots to the rig",
	},
	"d6": {
		"id": "d6",
		"order": 6,
		"wants": {
			"gear": 2,
			"plate": 2,
		},
		"grants": {
			"blast_furnace": 1,
		},
		"goal": "Deliver 2 gears and 2 plates to the rig",
	},
	"d7": {
		"id": "d7",
		"order": 7,
		"wants": {
			"ingot": 16,
		},
		"grants": {
			"pump": 1,
			"lift": 1,
		},
		"goal": "Deliver 16 ingots to the rig",
	},
}
