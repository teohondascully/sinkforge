# GENERATED FILE -- do not edit by hand.
# Source: data/machines/*.yaml. Regenerate with:
#   python3 tools/data_codegen/generate.py
# tools/data_codegen/generate.py --check is a CI gate (docs/QUALITY.md gate 22) that fails if
# this file is stale relative to its source. docs/adr/0004-data-codegen.md has the full contract.
class_name MachinesRecords
extends RefCounted

const RECORDS: Dictionary = {
	"blast_furnace": {
		"id": "blast_furnace",
		"display_name": "Blast Furnace",
		"behavior": "blast_furnace",
		"recipe": "smelt_rich",
	},
	"conduit": {
		"id": "conduit",
		"display_name": "Power Conduit",
		"behavior": "conduit",
		"capacity_milli": 12000,
		"v_keep_pct": 92,
		"h_keep_pct": 80,
		"bleed_pct": 60,
	},
	"drill": {
		"id": "drill",
		"display_name": "Drill",
		"behavior": "drill",
		"recipe": "mine_ore",
		"fuel_ticks": 60,
	},
	"gear_mill": {
		"id": "gear_mill",
		"display_name": "Gear Mill",
		"behavior": "gear_mill",
		"recipe": "mill_gear",
	},
	"generator": {
		"id": "generator",
		"display_name": "Generator",
		"behavior": "generator",
		"power_milli": 6000,
		"fuel_ticks": 100,
		"aura": 2,
	},
	"hopper": {
		"id": "hopper",
		"display_name": "Hopper",
		"behavior": "hopper",
		"release": 1,
		"feed_cap": 3,
	},
	"iron_forge": {
		"id": "iron_forge",
		"display_name": "Iron Forge",
		"behavior": "iron_forge",
		"recipe": "smelt_iron",
	},
	"lift": {
		"id": "lift",
		"display_name": "Lift",
		"behavior": "lift",
		"throughput": 2,
		"powered_throughput": 6,
		"power_demand_milli": 4000,
	},
	"plate_press": {
		"id": "plate_press",
		"display_name": "Plate Press",
		"behavior": "plate_press",
		"recipe": "press_plate",
	},
	"processor": {
		"id": "processor",
		"display_name": "Forge",
		"recipe": "smelt_ingot",
	},
	"pump": {
		"id": "pump",
		"display_name": "Pump",
		"behavior": "pump",
		"reach": 4,
		"rate": 3,
		"power_demand_milli": 4000,
	},
	"rope": {
		"id": "rope",
		"display_name": "Rope",
		"behavior": "rope",
	},
	"torch": {
		"id": "torch",
		"display_name": "Torch",
		"behavior": "torch",
	},
	"winch_head": {
		"id": "winch_head",
		"display_name": "Winch Head",
		"behavior": "winch_head",
		"trip_capacity": 8,
		"transit_ticks": 40,
		"power_demand_milli": 4000,
	},
	"winch_station": {
		"id": "winch_station",
		"display_name": "Winch Station",
		"behavior": "winch_station",
		"station_cap": 60,
	},
}
