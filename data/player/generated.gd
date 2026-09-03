# GENERATED FILE -- do not edit by hand.
# Source: data/player/*.yaml. Regenerate with:
#   python3 tools/data_codegen/generate.py
# tools/data_codegen/generate.py --check is a CI gate (docs/QUALITY.md gate 22) that fails if
# this file is stale relative to its source. docs/adr/0004-data-codegen.md has the full contract.
class_name PlayerRecords
extends RefCounted

const RECORDS: Dictionary = {
	"pack": {
		"id": "pack",
		"inventory_slots": 10,
		"bulk_cap": 90,
	},
}
