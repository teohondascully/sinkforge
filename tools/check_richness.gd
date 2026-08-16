extends SceneTree

## A SHAFT MUST NOT GO FORTY METRES WITHOUT MEETING ANYTHING.
##
## tools/check_pacing timed a real session and printed its shape, and the second act came out a METRONOME:
## depth ticking at dead-even intervals with nothing whatsoever between the ticks. One vertical shaft, forty
## metres of it, and it met no vein, no pocket, no cave, no water. Not a pacing bug — a WORLD bug, showing
## up in the pacing instrument because that is where an empty world eventually shows up.
##
## This game's stated identity is solid ORE-RICH earth you carve INTO, with caves recast as the rarer
## opt-in danger you choose to open. An earth that is 97% undifferentiated rock is the opposite of that
## claim however good the rock looks, and no amount of texture work fixes it: the player is not bored by
## the pixels, they are bored because the next hundred blocks are the same decision as the last hundred.
##
## So: sample honest vertical shafts through the REAL generated world and count ENCOUNTERS. An encounter is
## a contiguous RUN of something-other-than-plain-rock — a six-cell vein is ONE encounter, not six, because
## the player meets it once. Two numbers, and the second is the one that matters:
##
##   DENSITY     — encounters per hundred rows descended, averaged over many columns. The blunt "is there
##                 anything down there" number.
##   THE DROUGHT — the longest unbroken run of plain rock anywhere in any sampled shaft. This is the real
##                 measure of tedium, because a world can hit a fine average and still contain the stretch
##                 that made the player quit. Averages hide exactly the thing you are looking for; the
##                 dead-space guard in check_opening learned the same lesson about pictures.
##
## Reported per BAND as well as overall, because "sparse" is almost never uniform and the fix belongs in
## whichever strata are actually thin.
##
##   godot --headless --path . --script res://tools/check_richness.gd

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 30

## Where the shafts are sunk. Spread across the world, avoiding the outermost columns (the generator's
## edges are not where anyone plays) and stepping by a prime-ish stride so the sample never lands in step
## with any periodicity in the generator.
const SHAFT_FIRST: int = 6
const SHAFT_STRIDE: int = 7
const SHAFT_LAST: int = 122

## How deep the sampled shafts run, in rows below each column's own surface. Deep enough to cross several
## announced strata, stopping short of the seal (which is a designed wall, not terrain, and would flatter
## the numbers by counting as one enormous encounter).
const DEPTH_ROWS: int = 60

## Materials that are just "the rock here" — everything else counts as something met. Read as a set of what
## is BORING rather than a list of what is interesting, so a new ore or a new hazard is counted the day it
## is added instead of the day someone remembers to update this test.
const PLAIN: Array[StringName] = [&"earth", &"stone", &"shale", &"deepslate",
	&"dirt_wall", &"stone_wall", &"shale_wall", &"deepslate_wall"]

## THE FLOORS. Set from what the world measures today, with the drought cap set to what a player will
## tolerate rather than to what the generator happens to produce — twenty-five rows of identical rock is
## already a long time to hold a mouse button down for no new information.
const DENSITY_FLOOR: float = 6.0     ## encounters per 100 rows descended, averaged over the shafts
const DROUGHT_CAP: int = 25          ## rows of unbroken plain rock, anywhere, in any shaft

var _fails: int = 0


func _initialize() -> void:
	print("== is there anything down there ==")
	MainView.dev_start = false
	await _run()
	if _fails == 0:
		print("check_richness: PASS — the earth has things in it")
		quit(0)
	else:
		print("check_richness: FAIL (%d)" % _fails)
		quit(1)


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var sim: FactorySim = main.sim

	var shafts: int = 0
	var rows_total: int = 0
	var met_total: int = 0
	var drought: int = 0
	var drought_at: String = ""
	var kinds: Dictionary = {}
	# Per band: [rows descended, encounters met].
	var by_band: Dictionary = {}

	for col: int in range(SHAFT_FIRST, SHAFT_LAST, SHAFT_STRIDE):
		var top: int = sim.surface_row(col)
		if top >= FactorySim.GRID_ROWS:
			continue                                          # a column of open sky is not a shaft
		shafts += 1
		var run: int = 0                                      # current unbroken plain-rock run
		var inside: bool = false                              # currently inside an encounter
		for row: int in range(top, mini(top + DEPTH_ROWS, FactorySim.GRID_ROWS)):
			var cell := Vector2i(col, row)
			var band: int = Strata.band_at(row)
			if not by_band.has(band):
				by_band[band] = [0, 0]
			by_band[band][0] += 1
			rows_total += 1
			var what: StringName = _what(sim, cell)
			if what == &"":                                   # plain rock — the drought continues
				inside = false
				run += 1
				if run > drought:
					drought = run
					drought_at = "column %d, rows %d-%d (%s)" \
						% [col, row - run + 1, row, Strata.BANDS[band]["name"]]
				continue
			run = 0
			if inside:
				continue                                      # still the same vein / cave / pool
			inside = true
			met_total += 1
			by_band[band][1] += 1
			kinds[what] = int(kinds.get(what, 0)) + 1

	var density: float = float(met_total) * 100.0 / float(maxi(rows_total, 1))
	print("  %d shafts, %d rows descended, %d encounters" % [shafts, rows_total, met_total])
	var bands: Array = by_band.keys()
	bands.sort()
	for b: Variant in bands:
		var rows: int = by_band[b][0]
		var met: int = by_band[b][1]
		print("    %-16s %5d rows  %4d met  %5.1f per 100 rows"
			% [str(Strata.BANDS[int(b)]["name"]), rows, met, float(met) * 100.0 / float(maxi(rows, 1))])
	var klist: Array = kinds.keys()
	klist.sort()
	print("    what you meet: %s"
		% ", ".join(klist.map(func(k: Variant) -> String: return "%s x%d" % [k, kinds[k]])))
	print("  density %.1f per 100 rows  |  longest drought %d rows at %s" % [density, drought, drought_at])

	_check(shafts > 0, "there are shafts to sink at all")
	_check(density >= DENSITY_FLOOR,
		"the earth is worth digging through (%.1f per 100 rows, floor %.1f)" % [density, DENSITY_FLOOR])
	_check(drought <= DROUGHT_CAP,
		"...and nowhere in it is a dead stretch (%d rows, cap %d)" % [drought, DROUGHT_CAP])

	main.queue_free()
	await physics_frame


## What a shaft MEETS at this cell, or &"" for plain rock. Air below the surface is a real encounter — it
## is the cave/hall/rift the generator went to the trouble of carving — and so is water.
func _what(sim: FactorySim, cell: Vector2i) -> StringName:
	if sim.water.has(cell) and float(sim.water[cell]) > 0.05:
		return &"water"
	if not sim.is_solid(cell):
		return &"open space"
	var mat: StringName = sim.solid.get(cell, &"")
	return &"" if mat in PLAIN else mat


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		_fails += 1
		printerr("  FAIL: %s" % msg)
