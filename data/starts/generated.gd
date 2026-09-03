# GENERATED FILE -- do not edit by hand.
# Source: data/starts/*.yaml. Regenerate with:
#   python3 tools/data_codegen/generate.py
# tools/data_codegen/generate.py --check is a CI gate (docs/QUALITY.md gate 22) that fails if
# this file is stale relative to its source. docs/adr/0004-data-codegen.md has the full contract.
class_name StartsRecords
extends RefCounted

const RECORDS: Dictionary = {
	"dev_kit": {
		"id": "dev_kit",
		"fixtures": [
			{
				"kind": "pack",
				"item": "ore",
				"count": 20,
			},
			{
				"kind": "pack",
				"item": "ingot",
				"count": 20,
			},
			{
				"kind": "pack",
				"item": "coal",
				"count": 20,
			},
			{
				"kind": "pack",
				"item": "processor",
				"count": 2,
			},
			{
				"kind": "pack",
				"item": "lift",
				"count": 1,
			},
			{
				"kind": "pack",
				"item": "drill",
				"count": 1,
			},
			{
				"kind": "pack",
				"item": "generator",
				"count": 1,
			},
			{
				"kind": "pack",
				"item": "conduit",
				"count": 10,
			},
		],
	},
	"tutorial": {
		"id": "tutorial",
		"site": "shallow_clay",
		"spawn_col_m": 32,
		"fixtures": [
			{
				"kind": "solid",
				"dx": -2,
				"dy": 0,
				"material": "ore_iron",
				"deposit": 13,
			},
			{
				"kind": "solid",
				"dx": -1,
				"dy": 0,
				"material": "ore_iron",
				"deposit": 13,
			},
			{
				"kind": "solid",
				"dx": 5,
				"dy": 0,
				"material": "coal",
				"deposit": 13,
			},
			{
				"kind": "open",
				"cells": [
					[
						3,
						1,
					],
					[
						3,
						2,
					],
					[
						4,
						1,
					],
					[
						4,
						2,
					],
					[
						4,
						3,
					],
					[
						5,
						2,
					],
					[
						5,
						3,
					],
					[
						5,
						4,
					],
				],
			},
			{
				"kind": "lode",
				"dx": 4,
				"dy": 3,
				"material": "ore_iron",
				"amount": 3,
			},
			{
				"kind": "lode",
				"dx": 5,
				"dy": 2,
				"material": "ore_iron",
				"amount": 3,
			},
			{
				"kind": "lode",
				"dx": 5,
				"dy": 3,
				"material": "ore_iron",
				"amount": 3,
			},
			{
				"kind": "lode",
				"dx": 5,
				"dy": 4,
				"material": "ore_iron",
				"amount": 3,
			},
			{
				"kind": "lode",
				"dx": 5,
				"dy": 5,
				"material": "ore_iron",
				"amount": 8,
			},
			{
				"kind": "lode",
				"dx": 5,
				"dy": 6,
				"material": "ore_iron",
				"amount": 8,
			},
			{
				"kind": "lode",
				"dx": 5,
				"dy": 7,
				"material": "ore_iron",
				"amount": 8,
			},
			{
				"kind": "open",
				"cells": [
					[
						-3,
						0,
					],
					[
						-3,
						1,
					],
				],
			},
			{
				"kind": "solid",
				"dx": -3,
				"dy": 2,
				"material": "clay",
				"deposit": 0,
			},
			{
				"kind": "machine",
				"id": "processor",
				"dx": -3,
				"dy": 0,
			},
			{
				"kind": "open",
				"cells": [
					[
						7,
						0,
					],
					[
						7,
						1,
					],
				],
			},
			{
				"kind": "solid",
				"dx": 7,
				"dy": 2,
				"material": "ore_iron",
				"deposit": 25,
			},
			{
				"kind": "open",
				"cells": [
					[
						7,
						3,
					],
					[
						7,
						4,
					],
				],
			},
			{
				"kind": "solid",
				"dx": 7,
				"dy": 5,
				"material": "clay",
				"deposit": 0,
			},
			{
				"kind": "machine",
				"id": "processor",
				"dx": 7,
				"dy": 3,
			},
		],
	},
}
