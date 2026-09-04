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
## THE WORLD WIDTH THE TABLE BELOW WAS MEASURED ON (D0339). Every absolute count in it -- `cells` and
## `bodies_max` -- is proportional to how much world there is, so the width is part of the measurement
## and not a detail. D0335 widened `shallow_clay` to 256 and two rows of this suite failed for that
## reason alone, with the median body size unmoved and the generator working correctly.
const MEASURED_WIDTH: int = 48

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


## The real site without its content records (A' step 8, D0388): these pins are on the SCATTER constants
## WG-4 converted; the content passes add ore bodies of their own -- a metre-square nugget in every rift
## wall, an eighty-cell vein wherever a column ran dry -- whose population is a different subject, measured
## in `tests/test_shallow_clay_content.gd`.
func _scatter_only_site() -> Dictionary:
	return _site_without_content(StrataData.SHALLOW_CLAY)


## Connected components of `material` over the seeds, as {cells, bodies, median}.
func _measure(material: StringName) -> Dictionary:
	var sizes: Array[int] = []
	var cells: int = 0
	var world_width: int = 0
	for seed_value: int in SEEDS:
		var grid: TileGrid = ShaftGenerator.generate(_scatter_only_site(), seed_value)
		world_width = grid.width   ## read from the site, never assumed -- see the volume check below
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
	return {"cells": cells, "world_width": world_width, "bodies": sizes.size(), "median": median}


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
		# THE CEILING IS A DENSITY, NOT A COUNT (D0339). It used to be the raw body count, which is a claim
		# about the WORLD IT WAS MEASURED ON and nothing else: D0335 widened `shallow_clay` from 48 cells to
		# 256, the ore cells went 26,556 -> 133,500, and the count rose with them from under 120 to 168
		# while the median body size did NOT move (514 against its recorded 550). A wider world holding
		# proportionally more ore bodies is the generator working, and a count ceiling called it a failure.
		#
		# So the recorded pair is read as the ratio it always implied -- bodies per ore CELL -- which is
		# scale-free and still fails for the reason the row exists: a generator that made more, smaller
		# bodies raises bodies-per-cell even at constant world size.
		var per_cell: float = float(m["bodies"]) / maxf(1.0, float(m["cells"]))
		var per_cell_max: float = float(want["bodies_max"]) / float(want["cells"])
		_check(per_cell <= per_cell_max,
			"%s arrives as %d bodies over %d ore cells -- %.5f per cell, at or under the %.5f ceiling "
			% [material, m["bodies"], m["cells"], per_cell, per_cell_max]
			+ "(%d/%d as measured) -- fewer and larger, not more and smaller"
			% [want["bodies_max"], want["cells"]])


## THE CANCELLATION, asserted rather than assumed. Sizes went up 16x and densities down 16x, and the
## claim that they cancel is the whole reason the world is not now 16x ore or 1/16th of it. This is also
## the control that stops the two assertions above passing on a generator that simply makes more ore.
func _test_the_volume_survived_the_conversion_that_moved_the_sizes() -> void:
	for material: StringName in EXPECTED:
		var m: Dictionary = _measure(material)
		# SCALED BY WORLD WIDTH (D0339), the same frame problem the body-count ceiling had one row up. A
		# total volume is proportional to how much world there is, so the recorded figure is a claim about
		# the 48-cell `shallow_clay` it was measured on. D0335 widened that site to 256 and the volume rose
		# with it -- the generator filling a bigger world, which this row read as "only one half landed".
		#
		# The band still does its job: it is the x16-sizes-against-/16-densities CANCELLATION being
		# asserted, and a generator that got either half wrong moves volume per column by 16x, which no
		# +/-35% band absorbs. Scaling removes only the world-size term, not the claim.
		var width_now: float = float(int(m["world_width"]))
		var target: float = float(int(EXPECTED[material]["cells"])) * width_now / float(MEASURED_WIDTH)
		var cells: float = float(int(m["cells"]))
		_check(absf(cells - target) <= target * VOLUME_BAND,
			"%s's total volume is %d cells over %d columns, near the %d its measured %d predicts at this "
			% [material, int(cells), int(width_now), int(target), int(EXPECTED[material]["cells"])]
			+ "width (+/-%d%%) -- the x16 on sizes and the /16 on densities cancel"
			% int(VOLUME_BAND * 100.0))
