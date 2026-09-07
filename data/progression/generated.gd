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
}
