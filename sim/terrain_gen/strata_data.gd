class_name StrataData
extends RefCounted

## Site generation parameters: hand-mirrors `data/strata/*.yaml`. Same reason and same gap as
## `sim/world/materials.gd` mirroring `data/materials/*.yaml` -- Godot ships no runtime YAML parser
## (`docs/DECISIONS_LEDGER.md` D0021). If a value here and the `.yaml` file ever disagree, the `.yaml`
## is right and this is the one that's stale.
##
## One `const` dictionary per site, shaped exactly like its `.yaml` (nested dicts for `cave`,
## `strata_shelf`, `ore`, `coal`, `iron`, `ruin`) so `ShaftGenerator` can read it without a translation
## layer, and so a per-shaft modifier file (`docs/DECISIONS_LEDGER.md` D0016 -- "floods fast", "hard rock
## starts early") can override any leaf field later without touching this shape.

const SHALLOW_CLAY: Dictionary = {
	"id": &"shallow_clay",
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
		"material": &"ore_copper",
		"attempts_per_col": 1.0,
		"chance_deep": 0.85,
		"shallow_floor": 0.34,
		"size_min": 8,
		"size_depth_bonus": 44,
		# amount_base / amount_depth_bonus / rich_chance / rich_amount_mult are validated by
		# data/strata/SCHEMA.yaml and mirrored below for completeness, but ShaftGenerator does not
		# consume them yet -- richness/deposit accounting is sim/economy or sim/items territory, and
		# neither exists yet. Declared, not solved. See the commit message.
		"amount_base": 30,
		"amount_depth_bonus": 170,
		"rich_chance": 0.45,
		"rich_amount_mult": 1.5,
	},
	"coal": {
		"material": &"coal",
		"attempts_per_col": 0.8,
		"chance_deep": 0.95,
		"shallow_floor": 0.42,
		"size_min": 6,
		"size_depth_bonus": 30,
		"amount_base": 30,
		"amount_depth_bonus": 170,
	},
	"iron": {
		"material": &"ore_iron",
		"attempts_per_col": 0.5,
		"size_min": 10,
		"size_depth_bonus": 30,
		"amount": 220,
	},
	"ruin": {
		"count": 1,
		"min_depth_m": 100,
		"radius_cells": 4,
	},
}

const _SITES: Dictionary = {
	&"shallow_clay": SHALLOW_CLAY,
}


static func get_site(id: StringName) -> Dictionary:
	return _SITES.get(id, {})


static func exists(id: StringName) -> bool:
	return _SITES.has(id)
