# GENERATED FILE -- do not edit by hand.
# Source: data/materials/*.yaml. Regenerate with:
#   python3 tools/data_codegen/generate.py
# tools/data_codegen/generate.py --check is a CI gate (docs/QUALITY.md gate 22) that fails if
# this file is stale relative to its source. docs/adr/0004-data-codegen.md has the full contract.
class_name MaterialsRecords
extends RefCounted

const RECORDS: Dictionary = {
	"clay": {
		"id": "clay",
		"layer": "topsoil_shale",
		"kind": "rock",
		"hardness": 1.0,
		"display_name": "Clay",
	},
	"coal": {
		"id": "coal",
		"layer": "topsoil_shale",
		"kind": "fuel",
		"hardness": 1.5,
		"display_name": "Coal",
	},
	"deepstone": {
		"id": "deepstone",
		"layer": "deep_works",
		"kind": "rock",
		"hardness": 5.0,
		"display_name": "Deepstone",
	},
	"hardrock": {
		"id": "hardrock",
		"layer": "stonereach",
		"kind": "rock",
		"hardness": 3.0,
		"display_name": "Hardrock",
	},
	"ore_copper": {
		"id": "ore_copper",
		"layer": "topsoil_shale",
		"kind": "ore",
		"hardness": 2.0,
		"display_name": "Copper ore",
	},
	"ore_iron": {
		"id": "ore_iron",
		"layer": "stonereach",
		"kind": "ore",
		"hardness": 3.5,
		"display_name": "Iron ore",
	},
}
