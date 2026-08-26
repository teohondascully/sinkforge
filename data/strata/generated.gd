# GENERATED FILE -- do not edit by hand.
# Source: data/strata/*.yaml. Regenerate with:
#   python3 tools/data_codegen/generate.py
# tools/data_codegen/generate.py --check is a CI gate (docs/QUALITY.md gate 22) that fails if
# this file is stale relative to its source. docs/adr/0004-data-codegen.md has the full contract.
class_name StrataRecords
extends RefCounted

const RECORDS: Dictionary = {
	"shallow_clay": {
		"id": "shallow_clay",
		"width_cells": 48,
		"max_depth_m": 256,
		"layer_thresholds_m": {
			"topsoil_shale_end": 40,
			"stonereach_end": 140,
		},
		"cave": {
			"frequency": 0.11,
			"threshold_top": 0.47,
			"threshold_deep": 0.31,
			"min_depth_cells": 6,
			"x_stretch": 2.1,
		},
		"strata_shelf": {
			"band_height_cells": 4,
			"shelf_every": 3,
			"shelf_resist": 0.34,
		},
		"ore": {
			"material": "ore_copper",
			"attempts_per_col": 1.0,
			"chance_deep": 0.85,
			"shallow_floor": 0.34,
			"size_min": 8,
			"size_depth_bonus": 44,
			"pending_sim_economy": {
				"amount_base": 30,
				"amount_depth_bonus": 170,
				"rich_chance": 0.45,
				"rich_amount_mult": 1.5,
			},
		},
		"coal": {
			"material": "coal",
			"attempts_per_col": 0.8,
			"chance_deep": 0.95,
			"shallow_floor": 0.42,
			"size_min": 6,
			"size_depth_bonus": 30,
			"pending_sim_economy": {
				"amount_base": 30,
				"amount_depth_bonus": 170,
			},
		},
		"iron": {
			"material": "ore_iron",
			"attempts_per_col": 0.5,
			"size_min": 10,
			"size_depth_bonus": 30,
			"pending_sim_economy": {
				"amount": 220,
			},
		},
		"ruin": {
			"count": 1,
			"min_depth_m": 100,
			"radius_cells": 4,
		},
	},
}
