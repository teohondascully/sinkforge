# GENERATED FILE -- do not edit by hand.
# Source: scenarios/*.yaml. Regenerate with:
#   python3 tools/data_codegen/generate.py
# tools/data_codegen/generate.py --check is a CI gate (docs/QUALITY.md gate 22) that fails if
# this file is stale relative to its source. docs/adr/0004-data-codegen.md has the contract.
class_name ScenarioRecords
extends RefCounted

const RECORDS: Dictionary = {
	"cold_start_to_d1": {
		"name": "cold_start_to_d1",
		"claim": "C003",
		"seed": 20260825,
		"world": {
			"site": "shallow_clay",
			"start": "tutorial",
		},
		"agent": "cold_start",
		"rig": {
			"demands_satisfied": [],
			"stockpile": {},
		},
		"player": {
			"start_depth": 0,
			"pack": [],
		},
		"envelope": "constrained",
		"goal": {
			"type": "demand_satisfied",
			"id": "d1",
		},
		"budget_ticks": 30000,
		"assertions": [
			"invariants_hold",
		],
	},
	"conveyor_jam": {
		"name": "conveyor_jam",
		"claim": "C005",
		"seed": 20260825,
		"world": {
			"site": "shallow_clay",
			"start": "conveyor_probe",
		},
		"agent": "conveyor_probe",
		"rig": {
			"demands_satisfied": [],
			"stockpile": {},
		},
		"player": {
			"start_depth": 0,
			"pack": [
				{
					"item": "clay",
					"count": 1,
				},
			],
		},
		"envelope": "oracle",
		"goal": {
			"type": "machine_status",
			"cell": [
				35,
				27,
			],
			"status": "blocked",
		},
		"budget_ticks": 6000,
		"assertions": [
			"invariants_hold",
		],
	},
}
