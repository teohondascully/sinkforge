# GENERATED FILE -- do not edit by hand.
# Source: data/strata/*.yaml. Regenerate with:
#   python3 tools/data_codegen/generate.py
# tools/data_codegen/generate.py --check is a CI gate (docs/QUALITY.md gate 22) that fails if
# this file is stale relative to its source. docs/adr/0004-data-codegen.md has the full contract.
class_name StrataRecords
extends RefCounted

const RECORDS: Dictionary = {
	"reveal_test_dense": {
		"id": "reveal_test_dense",
		"width_cells": 48,
		"max_depth_m": 256,
		"layer_thresholds_m": {
			"topsoil_shale_end": 40,
			"stonereach_end": 140,
		},
		"cave": {
			"frequency": 0.0656,
			"threshold_top": 0.47,
			"threshold_deep": 0.31,
			"min_depth_cells": 24,
			"x_stretch": 2.1,
		},
		"strata_shelf": {
			"band_height_cells": 16,
			"shelf_every": 3,
			"shelf_resist": 0.34,
		},
		"ore": {
			"material": "ore_copper",
			"attempts_per_col": 0.25,
			"chance_deep": 0.85,
			"shallow_floor": 0.34,
			"size_min": 128,
			"size_depth_bonus": 704,
			"pending_sim_economy": {
				"amount_base": 30,
				"amount_depth_bonus": 170,
				"rich_chance": 0.45,
				"rich_amount_mult": 1.5,
			},
		},
		"coal": {
			"material": "coal",
			"attempts_per_col": 0.2,
			"chance_deep": 0.95,
			"shallow_floor": 0.42,
			"size_min": 96,
			"size_depth_bonus": 480,
			"pending_sim_economy": {
				"amount_base": 30,
				"amount_depth_bonus": 170,
			},
		},
		"iron": {
			"material": "ore_iron",
			"attempts_per_col": 0.125,
			"size_min": 160,
			"size_depth_bonus": 480,
			"pending_sim_economy": {
				"amount": 220,
			},
		},
		"ruin": {
			"count": 1,
			"min_depth_m": 100,
			"radius_cells": 4,
		},
		"reveal": {
			"material": "glimmer",
			"attempts_per_col": 0.6,
			"size_min": 6,
		},
	},
	"reveal_test_sparse": {
		"id": "reveal_test_sparse",
		"width_cells": 48,
		"max_depth_m": 256,
		"layer_thresholds_m": {
			"topsoil_shale_end": 40,
			"stonereach_end": 140,
		},
		"cave": {
			"frequency": 0.0656,
			"threshold_top": 0.47,
			"threshold_deep": 0.31,
			"min_depth_cells": 24,
			"x_stretch": 2.1,
		},
		"strata_shelf": {
			"band_height_cells": 16,
			"shelf_every": 3,
			"shelf_resist": 0.34,
		},
		"ore": {
			"material": "ore_copper",
			"attempts_per_col": 0.25,
			"chance_deep": 0.85,
			"shallow_floor": 0.34,
			"size_min": 128,
			"size_depth_bonus": 704,
			"pending_sim_economy": {
				"amount_base": 30,
				"amount_depth_bonus": 170,
				"rich_chance": 0.45,
				"rich_amount_mult": 1.5,
			},
		},
		"coal": {
			"material": "coal",
			"attempts_per_col": 0.2,
			"chance_deep": 0.95,
			"shallow_floor": 0.42,
			"size_min": 96,
			"size_depth_bonus": 480,
			"pending_sim_economy": {
				"amount_base": 30,
				"amount_depth_bonus": 170,
			},
		},
		"iron": {
			"material": "ore_iron",
			"attempts_per_col": 0.125,
			"size_min": 160,
			"size_depth_bonus": 480,
			"pending_sim_economy": {
				"amount": 220,
			},
		},
		"ruin": {
			"count": 1,
			"min_depth_m": 100,
			"radius_cells": 4,
		},
		"reveal": {
			"material": "glimmer",
			"attempts_per_col": 0.15,
			"size_min": 6,
		},
	},
	"shallow_clay": {
		"id": "shallow_clay",
		"width_cells": 48,
		"max_depth_m": 256,
		"layer_thresholds_m": {
			"topsoil_shale_end": 40,
			"stonereach_end": 140,
		},
		"cave": {
			"frequency": 0.0656,
			"threshold_top": 0.47,
			"threshold_deep": 0.31,
			"min_depth_cells": 24,
			"x_stretch": 2.1,
		},
		"strata_shelf": {
			"band_height_cells": 16,
			"shelf_every": 3,
			"shelf_resist": 0.34,
		},
		"ore": {
			"material": "ore_copper",
			"attempts_per_col": 0.25,
			"chance_deep": 0.85,
			"shallow_floor": 0.34,
			"size_min": 128,
			"size_depth_bonus": 704,
			"pending_sim_economy": {
				"amount_base": 30,
				"amount_depth_bonus": 170,
				"rich_chance": 0.45,
				"rich_amount_mult": 1.5,
			},
		},
		"coal": {
			"material": "coal",
			"attempts_per_col": 0.2,
			"chance_deep": 0.95,
			"shallow_floor": 0.42,
			"size_min": 96,
			"size_depth_bonus": 480,
			"pending_sim_economy": {
				"amount_base": 30,
				"amount_depth_bonus": 170,
			},
		},
		"iron": {
			"material": "ore_iron",
			"attempts_per_col": 0.125,
			"size_min": 160,
			"size_depth_bonus": 480,
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
