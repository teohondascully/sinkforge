extends "res://tests/test_base.gd"

## D0195/D0196 (Slice 1). `sim/mining` -- cursor-aim, reach radius, hold-to-charge, the per-cell crack bank,
## rhythm, and the hollow tell. Every one of these was re-derived from legacy float/`delta` code into integer
## fixed-tick arithmetic, so what this suite is really checking is that the re-derivation preserved the
## SEMANTICS and not merely that the code runs.
##
## Where legacy states a contract in its own test suite (`legacy/tools/check_tells.gd`), that contract is
## reproduced here verbatim in per-mille rather than restated loosely -- a port that passes a weaker test
## than the original has not been shown to be a port.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_mining.gd

const CELL: int = Heightfield.TERRAIN_CELL_PX
const GRID_W: int = 64
const GRID_H: int = 64
## Legacy `check_tells.gd`'s own contract constants, converted to this module's per-mille scale.
const TELL_LEAD: int = 3        ## tiles out from a void at which the floor below must already be cleared
const TELL_FLOOR: int = 300     ## legacy TELL_FLOOR 0.30
const QUIET_CEIL: int = 20      ## legacy QUIET_CEIL 0.02


func _initialize() -> void:
	_test_hardness_converts_exactly_and_the_table_matches_legacy_at_the_shallow_end()
	_test_reach_is_a_circle_of_the_stated_radius()
	_test_a_hold_breaks_a_cell_in_exactly_its_stated_tick_count()
	_test_charge_is_banked_per_cell_so_a_mis_aim_costs_travel_not_progress()
	_test_a_neglected_crack_heals_away_after_the_grace_window()
	_test_rhythm_makes_consecutive_breaks_faster()
	_test_mining_is_deterministic_across_instances()
	_test_the_tell_is_quiet_in_solid_rock_and_loud_before_a_void()
	_test_the_tell_is_directional()
	_test_the_tell_rises_monotonically_on_approach()
	_test_the_world_edge_does_not_read_as_a_cavity()
	_test_the_tell_normalisation_reproduces_legacys_own_constant()
	_test_the_hollow_magnitude_survives_the_tick_that_computes_it()
	_test_the_pick_lands_on_a_cadence()
	_test_rhythm_quickens_the_swing_cadence()
	_finish("mining")


## A `Mining` pinned to the single-cell blow, for the tests whose subject is the CHARGE mechanic -- the
## bank, the heal, the rhythm. Those work over cells one or two apart, so at the default bite radius the
## first break would clear the neighbours the test is about and the failure would read as a rhythm bug
## rather than a bite one. Pinning it here keeps each test measuring the thing it names (D0200).
func _charge_mechanic_mining() -> Mining:
	var mining: Mining = Mining.new()
	mining.bite_radius = Mining.CONTROL_BITE_RADIUS
	return mining


## The one dial relating two hardness scales that do not agree. Printed as a table in seconds, because the
## number that matters to a player is "how long does this take" and the constant alone hides it.
func _test_hardness_converts_exactly_and_the_table_matches_legacy_at_the_shallow_end() -> void:
	var inexact: Array[String] = []
	for id: StringName in MaterialsRecords.RECORDS:
		var h: float = WorldMaterials.hardness(id)
		if absf(h * 2.0 - float(Mining.hardness_halves(id))) > 0.0001:
			inexact.append("%s=%f" % [id, h])
		print("  [OBSERVED] %-12s hardness %.1f -> %3d ticks (%.3f s)"
			% [id, h, Mining.ticks_to_break(id), float(Mining.ticks_to_break(id)) / 60.0])
	_check(inexact.is_empty(),
		"every authored hardness is a whole number of halves, so the integer conversion is exact rather than truncating (%s)"
		% str(inexact))
	# The derivation's own two anchors, restated as assertions so a change to TICKS_PER_HARDNESS has to
	# face them: legacy earth 0.28s and legacy stone 0.85s.
	_check(Mining.ticks_to_break(&"clay") == 17,
		"clay breaks in 17 ticks (0.283s), against legacy earth's 0.28s (got %d)" % Mining.ticks_to_break(&"clay"))
	_check(Mining.ticks_to_break(&"hardrock") == 51,
		"hardrock breaks in 51 ticks (0.850s), exactly legacy stone's 0.85s (got %d)" % Mining.ticks_to_break(&"hardrock"))


## 3.2 metres == 3.2 logic tiles == 51.2px here. A cell centre 48px away is in; 52px is out; and the circle
## is a circle, not a square -- the diagonal case is what separates Euclidean from Chebyshev, and getting
## that wrong would pass every axis-aligned test.
func _test_reach_is_a_circle_of_the_stated_radius() -> void:
	var body: Vector2i = _at_cell_centre(Vector2i(0, 0))
	_check(Mining.in_reach(body.x, body.y, Vector2i(12, 0)),
		"a cell centre 48px away (12 cells) is within the 51.2px reach")
	_check(not Mining.in_reach(body.x, body.y, Vector2i(13, 0)),
		"a cell centre 52px away (13 cells) is beyond the 51.2px reach")
	_check(Mining.in_reach(body.x, body.y, Vector2i(9, 9)),
		"a diagonal cell at (36,36)px, 50.9px away, is IN reach -- the test is Euclidean")
	_check(not Mining.in_reach(body.x, body.y, Vector2i(10, 10)),
		"a diagonal cell at (40,40)px, 56.6px away, is OUT of reach -- a Chebyshev test would wrongly admit it")
	_check(Mining.in_reach(body.x, body.y, Vector2i(0, -12)) and not Mining.in_reach(body.x, body.y, Vector2i(0, -13)),
		"reach is symmetric upward -- straight up is not a special case (this is what makes 'down' unremarkable too)")


func _test_a_hold_breaks_a_cell_in_exactly_its_stated_tick_count() -> void:
	for material: StringName in [&"clay", &"hardrock", &"deepstone"]:
		var grid: TileGrid = _solid_grid(material)
		var mining: Mining = Mining.new()
		var body: Vector2i = _at_cell_centre(Vector2i(8, 8))
		var target: Vector2i = Vector2i(8, 10)
		var took: int = _ticks_to_break(mining, grid, body, target, 400)
		_check(took == Mining.ticks_to_break(material),
			"%s breaks after exactly %d held ticks (took %d)" % [material, Mining.ticks_to_break(material), took])
		_check(not grid.is_solid(target), "%s: the cell is actually gone from the grid after the break" % material)


## The property the crack bank exists for, stated as legacy states it: a mis-aim costs travel time, never
## progress. Half-charge a cell, look away for a few ticks, come back -- it must resume, not restart.
func _test_charge_is_banked_per_cell_so_a_mis_aim_costs_travel_not_progress() -> void:
	var grid: TileGrid = _solid_grid(&"deepstone")
	var mining: Mining = _charge_mechanic_mining()
	var body: Vector2i = _at_cell_centre(Vector2i(8, 8))
	var target: Vector2i = Vector2i(8, 10)
	var elsewhere: Vector2i = Vector2i(9, 10)
	var full: int = Mining.ticks_to_break(&"deepstone")
	for _i: int in full - 5:
		mining.mine(grid, body.x, body.y, target, true)
	var banked_before: int = mining.banked(target)
	_check(banked_before > 0, "a partial hold leaves real banked charge (%d units)" % banked_before)
	for _i: int in 3:
		mining.mine(grid, body.x, body.y, elsewhere, true)
	_check(mining.banked(target) == banked_before,
		"three ticks aimed elsewhere, inside the grace window, cost the first cell NOTHING (%d -> %d)"
		% [banked_before, mining.banked(target)])
	var resumed: int = _ticks_to_break(mining, grid, body, target, 400)
	_check(resumed == 5, "returning to the cell finishes it in the 5 ticks that were left, not %d from scratch (took %d)"
		% [full, resumed])


func _test_a_neglected_crack_heals_away_after_the_grace_window() -> void:
	var grid: TileGrid = _solid_grid(&"deepstone")
	var mining: Mining = Mining.new()
	var body: Vector2i = _at_cell_centre(Vector2i(8, 8))
	var target: Vector2i = Vector2i(8, 10)
	for _i: int in 40:
		mining.mine(grid, body.x, body.y, target, true)
	var banked_before: int = mining.banked(target)
	# Grace, then long enough for the bleed to clear whatever was banked, plus a margin.
	var bleed_ticks: int = banked_before / Mining.CRACK_HEAL_PER_TICK + 2
	for _i: int in Mining.CRACK_HOLD_TICKS + bleed_ticks:
		mining.mine(grid, body.x, body.y, Vector2i(20, 20), false)
	print("  [OBSERVED] banked %d units, healed to %d after %d idle ticks"
		% [banked_before, mining.banked(target), Mining.CRACK_HOLD_TICKS + bleed_ticks])
	_check(mining.banked(target) == 0, "a crack left alone past the grace window bleeds to nothing and evicts")


## Legacy's rhythm: each break makes the next one faster, up to +60%. Asserted as a DIRECTION plus a bound,
## not an exact tick count -- the exact count is an arithmetic consequence of three constants and asserting
## it would just restate them, while the direction is the mechanic.
func _test_rhythm_makes_consecutive_breaks_faster() -> void:
	var grid: TileGrid = _solid_grid(&"deepstone")
	var mining: Mining = _charge_mechanic_mining()
	var body: Vector2i = _at_cell_centre(Vector2i(8, 8))
	var first: int = _ticks_to_break(mining, grid, body, Vector2i(8, 10), 400)
	var second: int = _ticks_to_break(mining, grid, body, Vector2i(9, 10), 400)
	var third: int = _ticks_to_break(mining, grid, body, Vector2i(10, 10), 400)
	print("  [OBSERVED] consecutive deepstone breaks: %d, %d, %d ticks" % [first, second, third])
	_check(second < first and third < second,
		"each break carries rhythm into the next, so consecutive blocks come faster (%d, %d, %d)" % [first, second, third])
	var floor_ticks: int = (first * Mining.RHYTHM_SPEED_DEN) / (Mining.RHYTHM_SPEED_DEN + Mining.RHYTHM_FULL)
	_check(third >= floor_ticks,
		"rhythm never beats its own 1.6x ceiling (%d ticks against a floor of %d)" % [third, floor_ticks])


## Two independent instances, identical input, identical state -- including the crack bank, which is real
## sim state a replay must reproduce. Signature is compared, not just the break ticks: two runs could break
## the same cells on the same ticks while carrying different partial charge everywhere else.
func _test_mining_is_deterministic_across_instances() -> void:
	var sigs: Array[String] = []
	for _run: int in 2:
		var grid: TileGrid = _solid_grid(&"hardrock")
		var mining: Mining = Mining.new()
		var body: Vector2i = _at_cell_centre(Vector2i(8, 8))
		for t: int in 300:
			var target: Vector2i = Vector2i(8 + (t % 5), 10 + ((t / 7) % 3))
			mining.mine(grid, body.x, body.y, target, t % 11 != 0)
		sigs.append("%s|%s" % [mining.state_signature(), grid.state_signature()])
	_check(sigs[0] == sigs[1], "two independent runs of the same 300-tick input produce identical mining AND grid state")
	_check(sigs[0].length() > 20, "the signature is not trivially empty -- the run actually banked something")


## Legacy `check_tells.gd`'s QUIET_CEIL: deep inside solid rock the reading must be near zero in every
## direction. This is the control for every other tell assertion -- without it, a tell stuck at a high
## constant would pass the "loud before a void" test.
func _test_the_tell_is_quiet_in_solid_rock_and_loud_before_a_void() -> void:
	var grid: TileGrid = _solid_grid(&"hardrock")
	var worst: int = 0
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		worst = maxi(worst, Mining.hollow_at(grid, Vector2i(32, 32), dir))
	print("  [OBSERVED] loudest reading deep in solid rock, over four directions: %d per mille" % worst)
	_check(worst <= QUIET_CEIL, "solid rock reads <= %d per mille in every direction (worst %d)" % [QUIET_CEIL, worst])

	# A void immediately behind the struck face, downward: carve out the logic tiles below.
	for col: int in range(24, 44):
		for row: int in range(40, 60):
			grid.excavate(Vector2i(col, row))
	var loud: int = Mining.hollow_at(grid, Vector2i(32, 36), Vector2i(0, 1))
	print("  [OBSERVED] reading with a void one tile behind the face: %d per mille" % loud)
	_check(loud >= TELL_FLOOR, "a void right behind the face reads >= %d per mille (got %d)" % [TELL_FLOOR, loud])
	_check(loud >= HollowTell.BREACH, "and clears BREACH (%d), so breaking it counts as opening a space (got %d)"
		% [HollowTell.BREACH, loud])


## Legacy `check_tells.gd`'s directionality assert: `away < into * 0.5`. A tell that ignored `dir` would
## return the same number both ways and pass every magnitude test above.
func _test_the_tell_is_directional() -> void:
	var grid: TileGrid = _solid_grid(&"hardrock")
	for col: int in range(24, 44):
		for row: int in range(40, 60):
			grid.excavate(Vector2i(col, row))
	var into: int = Mining.hollow_at(grid, Vector2i(32, 36), Vector2i(0, 1))
	var away: int = Mining.hollow_at(grid, Vector2i(32, 36), Vector2i(0, -1))
	print("  [OBSERVED] tell into the void %d, away from it %d per mille" % [into, away])
	_check(away * 2 < into, "reading away from the void is less than half the reading into it (%d vs %d)" % [away, into])


## Legacy's own no-false-peak assert. A reading that rose and fell on approach would tell a player the void
## was behind them just before they reached it, which is worse than no tell at all.
func _test_the_tell_rises_monotonically_on_approach() -> void:
	var grid: TileGrid = _solid_grid(&"hardrock")
	for col: int in range(24, 44):
		for row: int in range(48, 60):
			grid.excavate(Vector2i(col, row))
	var readings: Array[int] = []
	var dipped: bool = false
	for lead: int in range(TELL_LEAD + 2, 0, -1):
		var r: int = Mining.hollow_at(grid, Vector2i(32, 48 - lead * HollowTell.CELLS_PER_TILE), Vector2i(0, 1))
		if readings.size() > 0 and r < readings[-1]:
			dipped = true
		readings.append(r)
	print("  [OBSERVED] tell approaching a void, %d tiles out to 1: %s" % [TELL_LEAD + 2, str(readings)])
	_check(not dipped, "the reading never falls as the face gets closer to the void (%s)" % str(readings))
	_check(readings[-1] > readings[0], "and it genuinely rises overall rather than sitting flat (%s)" % str(readings))


## The deliberate divergence from legacy, asserted so it cannot be quietly reverted. Legacy counts an
## out-of-bounds probe as hollow; this world is 12 logic tiles wide against a 4-tile probe, so that
## convention would make a third of the map read as permanent cavity.
func _test_the_world_edge_does_not_read_as_a_cavity() -> void:
	var grid: TileGrid = TileGrid.new(12 * HollowTell.CELLS_PER_TILE, GRID_H, 1)
	for col: int in grid.width:
		for row: int in GRID_H:
			grid.set_material(Vector2i(col, row), &"hardrock")
	var at_edge: int = Mining.hollow_at(grid, Vector2i(1, 32), Vector2i(-1, 0))
	print("  [OBSERVED] tell aimed straight off the world's left edge: %d per mille" % at_edge)
	_check(at_edge <= QUIET_CEIL,
		"aiming the probe off the edge of a 12-tile-wide world reads as SOLID, not as a void (%d per mille)" % at_edge)


## The normalisation is derived from REACH and SPREAD rather than written down, so this pins the derivation
## to the number legacy actually used. In legacy's own float units the total is 7.5; the integer weights
## here are scaled by REACH * (SPREAD+1) = 12, so 90/12 must come back to exactly that.
func _test_the_tell_normalisation_reproduces_legacys_own_constant() -> void:
	var scaled: float = float(HollowTell.TOTAL_WEIGHT) / float(HollowTell.REACH * (HollowTell.SPREAD + 1))
	print("  [OBSERVED] TOTAL_WEIGHT %d, unscaled %.3f (legacy's own 7.5)" % [HollowTell.TOTAL_WEIGHT, scaled])
	_check(absf(scaled - 7.5) < 0.0001,
		"the derived normalisation equals legacy's (REACH+1)(SPREAD+1)/2 == 7.5 (got %.4f)" % scaled)


## D0274 (`docs/LEGACY_GAP.md` PRE-3): the hollow reading was computed inside `_break` and thrown away,
## leaving only the boolean `breach_this_tick`. Legacy carries the MAGNITUDE because "volume rides the
## reading, so closing on a cavity is a crescendo you can act on rather than a flag that flips", and a
## consumer given only the threshold cannot reconstruct the ramp.
##
## POSED AGAINST A REAL CAVITY, which is the whole point. An earlier version of this assertion checked
## only that the reading was "in range 0..FULL" -- and 0 satisfies that, so it passed on a `Mining` that
## never set the field at all. The mutation run caught it. A magnitude test needs a fixture where the
## right answer is NOT zero, and a control where it is.
func _test_the_hollow_magnitude_survives_the_tick_that_computes_it() -> void:
	var body_x: int = Fx.from_int(32 * CELL)
	var body_y: int = Fx.from_int(30 * CELL)
	var face := Vector2i(32, 32)   ## directly below the body: `swing_dir` reads this as downward

	# CONTROL: solid to the horizon, so the correct reading here is genuinely 0 and a non-zero one would
	# mean the fixture, not the field, is wrong.
	var solid: TileGrid = _solid_grid(&"hardrock")
	var quiet: Mining = _charge_mechanic_mining()
	quiet.mine(solid, body_x, body_y, face, true)
	_check(quiet.hollow_this_tick <= QUIET_CEIL,
		"charging into solid rock reads quiet (%d <= %d)" % [quiet.hollow_this_tick, QUIET_CEIL])

	# TREATMENT: the same swing with a void opened just past the face.
	var hollow_grid: TileGrid = _solid_grid(&"hardrock")
	for col: int in range(28, 37):
		for row: int in range(34, 42):
			hollow_grid.excavate(Vector2i(col, row))
	var loud: Mining = _charge_mechanic_mining()
	loud.mine(hollow_grid, body_x, body_y, face, true)
	_check(loud.hollow_this_tick > QUIET_CEIL,
		"charging at a face with a cavity behind it reads loud (%d > %d)" % [loud.hollow_this_tick, QUIET_CEIL])
	_check(loud.hollow_this_tick == Mining.hollow_at(hollow_grid, face, Mining.swing_dir(body_x, body_y, face)),
		"and it is exactly what `hollow_at` reports for that cell and direction (%d)" % loud.hollow_this_tick)

	# And it CLEARS on a tick that works nothing -- a field that only ever accumulated would report a
	# crescendo the player is no longer causing.
	loud.mine(hollow_grid, body_x, body_y, face, false)
	_check(loud.hollow_this_tick == 0,
		"a tick that works nothing clears the reading (%d)" % loud.hollow_this_tick)


## D0279 (`docs/NEEDS_DIRECTOR.md` P024, director-ruled): the swing edge, ported from legacy's
## `SWING_PERIOD` / `RHYTHM_SWING` rather than invented. The properties that matter are all about WHEN it
## fires, so every one of them is measured by counting edges over a run of ticks rather than by reading
## the flag once.
func _test_the_pick_lands_on_a_cadence() -> void:
	var grid: TileGrid = _solid_grid(&"deepstone")
	var body_x: int = Fx.from_int(32 * CELL)
	var body_y: int = Fx.from_int(30 * CELL)
	var face := Vector2i(32, 32)
	var m: Mining = _charge_mechanic_mining()

	# THE FIRST BLOW LANDS INSTANTLY. Legacy primes `_swing_clock` on release for exactly this: a player
	# who taps mine should feel the pick hit, not wait a quarter second for the cadence to come round.
	m.mine(grid, body_x, body_y, face, true)
	_check(m.swing_this_tick, "the first tick of a fresh charge lands a blow immediately")

	# ...and then NOT on the very next tick, which is the half that separates an edge from a level. A
	# `swing_this_tick` wired to `charging_cell != NO_CELL` would pass the row above and fail this one.
	m.mine(grid, body_x, body_y, face, true)
	_check(not m.swing_this_tick, "and the tick straight after it does not -- this is an edge, not a level")

	# The cadence itself. On a FRESH `Mining`, so the count starts at the blow rather than partway through
	# a period -- the first version measured 15 against a period of 16 because the two assertions above had
	# already consumed a tick, which is a bug in the counting and not in the cadence.
	var cadence: Mining = _charge_mechanic_mining()
	var idle_period: int = cadence.swing_period_ticks()
	cadence.mine(grid, body_x, body_y, face, true)
	_check(cadence.swing_this_tick, "sanity: the fresh painter's first tick is the blow we count from")
	var gap: int = 0
	while gap < idle_period * 3:
		cadence.mine(grid, body_x, body_y, face, true)
		gap += 1
		if cadence.swing_this_tick:
			break
	# Compared against `swing_period_ticks()` rather than a literal: a literal would assert the test's own
	# arithmetic instead of legacy's 0.28s/60Hz conversion.
	_check(gap == idle_period,
		"the next blow lands exactly %d ticks later, the period at this rhythm (got %d)" % [idle_period, gap])



## The other half of D0279, split from the cadence test above when it hit QUALITY gate 4's 50-line limit.
## The seam is real: above is WHEN a blow lands at a fixed rhythm, this is what RHYTHM does to that.
##
## Posed by driving the rhythm up with real breaks rather than by writing to `_rhythm`, so it measures
## the mechanism legacy shipped rather than a field poke.
func _test_rhythm_quickens_the_swing_cadence() -> void:
	var body_y: int = Fx.from_int(30 * CELL)
	var idle_period: int = _charge_mechanic_mining().swing_period_ticks()
	var fast: Mining = Mining.new()
	var soft: TileGrid = _solid_grid(&"topsoil")
	var breaks: int = 0
	var ticks: int = 0
	# Columns spaced past the default bite's own diameter. At `DEFAULT_BITE_RADIUS` a blow clears a disc
	# of neighbours, so consecutive columns would already be air by the time the next one is aimed at --
	# the loop would then never charge again and the rhythm would sit at whatever one break gave it.
	# Found by measuring: the first version of this reached 1 break in 4000 ticks.
	var spacing: int = Mining.DEFAULT_BITE_RADIUS * 2 + 2
	while breaks < 6 and ticks < 4000:
		var col: int = 30 + breaks * spacing
		if fast.mine(soft, Fx.from_int(col * CELL), body_y, Vector2i(col, 32), true) != Mining.NO_CELL:
			breaks += 1
		ticks += 1
	_check(breaks == 6, "sanity: the rhythm was actually driven up by real breaks (%d of 6)" % breaks)
	var quick_period: int = fast.swing_period_ticks()
	_check(quick_period < idle_period,
		"a built-up rhythm shortens the swing period (%d ticks vs %d at rest)" % [quick_period, idle_period])
	_check(quick_period > 0,
		"and never to zero, which would fire a blow every single tick (%d)" % quick_period)
