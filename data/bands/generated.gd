# GENERATED FILE -- do not edit by hand.
# Source: data/bands/*.yaml. Regenerate with:
#   python3 tools/data_codegen/generate.py
# tools/data_codegen/generate.py --check is a CI gate (docs/QUALITY.md gate 22) that fails if
# this file is stale relative to its source. docs/adr/0004-data-codegen.md has the full contract.
class_name BandsRecords
extends RefCounted

const RECORDS: Dictionary = {
	"open_sky": {
		"id": "open_sky",
		"display_name": "OPEN SKY",
		"from_m": -119,
		"color": [
			0.62,
			0.76,
			0.92,
		],
	},
	"shale_reach": {
		"id": "shale_reach",
		"display_name": "SHALE REACH",
		"from_m": 24,
		"color": [
			0.58,
			0.64,
			0.74,
		],
	},
	"stonereach": {
		"id": "stonereach",
		"display_name": "STONEREACH",
		"from_m": 66,
		"color": [
			0.44,
			0.62,
			0.96,
		],
	},
	"the_clayband": {
		"id": "the_clayband",
		"display_name": "THE CLAYBAND",
		"from_m": 10,
		"color": [
			0.86,
			0.58,
			0.3,
		],
	},
	"the_deepslate": {
		"id": "the_deepslate",
		"display_name": "THE DEEPSLATE",
		"from_m": 56,
		"color": [
			0.56,
			0.5,
			0.78,
		],
	},
	"the_long_dark": {
		"id": "the_long_dark",
		"display_name": "THE LONG DARK",
		"from_m": 40,
		"color": [
			0.52,
			0.52,
			0.6,
		],
	},
	"the_seal": {
		"id": "the_seal",
		"display_name": "THE SEAL",
		"from_m": 64,
		"color": [
			0.72,
			0.44,
			0.86,
		],
	},
	"topsoil": {
		"id": "topsoil",
		"display_name": "TOPSOIL",
		"from_m": 0,
		"color": [
			0.72,
			0.56,
			0.34,
		],
	},
}
