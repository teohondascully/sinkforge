extends "res://tests/test_base.gd"

## THE INSTRUMENT WG-4 NEEDED AND DID NOT HAVE (D0305). `docs/LEGACY_GAP.md` WG-4, Batch A.
##
## The conversion multiplies every vein SIZE by 16 and divides every seed DENSITY by 16, and those cancel
## **by construction**: total ore volume is `attempts x accept x mean_size`. The deliverable is the world
## going from *many tiny scattered specks* to *fewer, room-scale bodies* — so **total volume is precisely
## the quantity that cannot see it**, and neither can anything else the repo already measured.
##
## That was checked rather than assumed. Each of Batch A's eleven constants was reverted in memory and the
## existing carve ratchet re-run: the largest movement any of them produced in `carve_open` was **0.0048**
## against a ±0.0060 band, and eight of the eleven moved it by **0.0000**. The carve ratchet measures
## `_carve_caves`; these are ore constants; it was never going to see them. WG-4 was one commit away from
## shipping a world-shaping change with no assertion anywhere that could register it.
##
## What registers it is the CONNECTED-COMPONENT SIZE DISTRIBUTION: body count and body count alone falls,
## median size rises, and volume stays put. Three numbers that must move in three different directions,
## which no single one of them can fake.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_ore_bodies.gd

const SEEDS: Array[int] = [1, 20260826, 424242]
const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## Measured 2026-09-01 at WG-4 Batch A over the three seeds above, SHALLOW_CLAY. The bands are ±25% on
## the median and ±35% on volume — wide enough that ordinary seed variance and a threshold nudge do not
## trip them, tight enough that reverting any one of the six constants each material owns does. Both
## halves of that claim are mutation-checked, and the per-constant movements are in D0305.
##
## `bodies_max` is a CEILING, not a band: the whole point of the conversion is that this number came down
## (ore 477 -> 42), and a change that puts it back up is the regression this file exists to catch.
const EXPECTED: Dictionary = {
	&"ore_copper": {"median": 550.0, "cells": 26556, "bodies_max": 120},
	&"coal": {"median": 402.0, "cells": 17368, "bodies_max": 110},
	&"ore_iron": {"median": 429.0, "cells": 8447, "bodies_max": 60},
}

## What the world looked like BEFORE the conversion, kept as the other end of the comparison. A band
## around today's number says "it has not drifted"; these say "it actually moved, and which way".
const BEFORE: Dictionary = {
	&"ore_copper": {"median": 32.0, "bodies": 477},
	&"coal": {"median": 20.0, "bodies": 531},
	&"ore_iron": {"median": 24.0, "bodies": 263},
}

const MEDIAN_BAND: float = 0.25
const VOLUME_BAND: float = 0.35


func _initialize() -> void:
	_test_ore_arrives_as_room_scale_bodies_not_specks()
	_test_the_volume_survived_the_conversion_that_moved_the_sizes()
	_finish("ore_bodies")


## Connected components of `material` over the seeds, as {cells, bodies, median}.
func _measure(material: StringName) -> Dictionary:
	var sizes: Array[int] = []
	var cells: int = 0
	for seed_value: int in SEEDS:
		var grid: TileGrid = ShaftGenerator.generate(StrataData.SHALLOW_CLAY, seed_value)
		var seen: Dictionary = {}
		for col: int in grid.width:
			for row: int in grid.height:
				var start := Vector2i(col, row)
				if seen.has(start) or grid.get_material(start) != material:
					continue
				var size: int = 0
				var stack: Array[Vector2i] = [start]
				seen[start] = true
				while not stack.is_empty():
					var c: Vector2i = stack.pop_back()
					size += 1
					for d: Vector2i in NEIGHBOURS:
						var n: Vector2i = c + d
						if seen.has(n) or not grid.in_bounds(n) or grid.get_material(n) != material:
							continue
						seen[n] = true
						stack.append(n)
				sizes.append(size)
				cells += size
	sizes.sort()
	var median: float = 0.0 if sizes.is_empty() else float(sizes[sizes.size() / 2])
	return {"cells": cells, "bodies": sizes.size(), "median": median}


## THE ASSERTION THE CONVERSION EXISTS FOR. Two numbers, moving opposite ways: bodies down, median up.
## Either alone is fakeable — a generator that stopped placing ore has few bodies, and one that placed a
## single continent has a huge median. Together with the volume check below, they are not.
func _test_ore_arrives_as_room_scale_bodies_not_specks() -> void:
	for material: StringName in EXPECTED:
		var m: Dictionary = _measure(material)
		var want: Dictionary = EXPECTED[material]
		var was: Dictionary = BEFORE[material]
		print("  [OBSERVED] %-11s cells=%-6d bodies=%-4d median=%-6.0f (was %d bodies, median %.0f)"
			% [material, m["cells"], m["bodies"], m["median"], was["bodies"], was["median"]])

		# The control, first: a fraction or a median over an empty population is not a small number, it
		# is no number, and every assertion below would read as a pass.
		_check(int(m["bodies"]) > 0,
			"positive control: %s exists in the world at all (%d bodies)" % [material, m["bodies"]])
		if int(m["bodies"]) == 0:
			continue

		var median: float = float(m["median"])
		var target: float = float(want["median"])
		_check(absf(median - target) <= target * MEDIAN_BAND,
			"%s's median body is %.0f cells, near its measured %.0f (+/-%d%%). Reverting any of that "
			% [material, median, target, int(MEDIAN_BAND * 100.0)]
			+ "material's own size or density constants moves this by 30-72%%.")
		_check(median > float(was["median"]) * 4.0,
			"...and it is at least 4x the %.0f it was before WG-4 -- the conversion's whole deliverable "
			% float(was["median"]) + "is that a vein is a place you work rather than a speck you pass")
		_check(int(m["bodies"]) <= int(want["bodies_max"]),
			"%s arrives as %d bodies, at or under the %d ceiling (was %d) -- fewer and larger, not more "
			% [material, m["bodies"], want["bodies_max"], was["bodies"]] + "and smaller")


## THE CANCELLATION, asserted rather than assumed. Sizes went up 16x and densities down 16x, and the
## claim that they cancel is the whole reason the world is not now 16x ore or 1/16th of it. This is also
## the control that stops the two assertions above passing on a generator that simply makes more ore.
func _test_the_volume_survived_the_conversion_that_moved_the_sizes() -> void:
	for material: StringName in EXPECTED:
		var m: Dictionary = _measure(material)
		var target: float = float(int(EXPECTED[material]["cells"]))
		var cells: float = float(int(m["cells"]))
		_check(absf(cells - target) <= target * VOLUME_BAND,
			"%s's total volume is %d cells, near its measured %d (+/-%d%%) -- the x16 on sizes and the "
			% [material, int(cells), int(target), int(VOLUME_BAND * 100.0)]
			+ "/16 on densities cancel, and a world 16x either way means only one half landed")
