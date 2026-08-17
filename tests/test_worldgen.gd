extends "res://tests/test_base.gd"

## Worldgen / terrain suite — the deterministic generators (heightmap + the layered caves / strata /
## depth-banded ore), the surface silhouette, horizontal + rich-ore richness, the many-seed fuzz sweep,
## and the dual-grid fine-terrain derivation. Asserts generation is deterministic in (cols, rows, seed)
## and that the emitted world honours the material registry + two-grid contract.


func _initialize() -> void:
	print("== worldgen tests ==")
	_test_terrain()
	_test_ground_survives_digging()
	_test_generated_lodes()
	_test_surface_silhouette()
	_test_surface_walkable()
	_test_worldgen()
	_test_layered_worldgen()
	_test_worldgen_fuzz()
	_test_horizontal_ore_pull()
	_test_rich_ore()
	_test_fine_terrain()
	_finish("worldgen tests")


## THE GROUND STAYS WHERE IT WAS WHEN YOU DIG — the property `FactorySim.surface_row` cannot have and
## `HeightmapWorldGen.ground_row` exists to provide.
##
## `surface_row` scans from row 0 for the first solid cell. On a generated, untouched world that IS the
## ground, which is why it reads as the surface authority and why consumers kept picking it up. Sink a
## shaft and it starts reporting the floor under your own boots, so every `body.y - surface_row(body.x)`
## in the codebase collapses to about -1 REGARDLESS OF DEPTH. Two shipped consumers computed exactly that:
## the ambience crossfade (full surface wind, no cave bed and no drips, at the bottom of a hole you dug)
## and the GRAPPLE hint, which fires at 10 "rows below the local surface that make the climb a real trip"
## and so could not be reached by climbing down.
##
## The depths here are the boundary case ON PURPOSE. A pad column's ground is FLAT_SURFACE_ROW (20) and
## SURFACE_ROW_MAX is 31, so an eleven-row shaft floors at exactly 31 — still inside the legal ground band.
## That is the case `FineTerrain.walked_surface` is blind to by construction (it can only reject answers
## that leave the band, so it catches the forty-row rift and not the shaft you dug this minute), and it is
## the same eleven rows that put the body one row past the hint threshold. One dig, both claims.
func _test_ground_survives_digging() -> void:
	print("- ground survives digging")
	var sim: FactorySim = FactorySim.new()
	sim.load_world(LayeredWorldGen.new().generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, 1337))
	var col: int = (HeightmapWorldGen.BASE_PAD_START + HeightmapWorldGen.BASE_PAD_END) / 2
	var ground: int = HeightmapWorldGen.ground_row(col)
	_check(ground == HeightmapWorldGen.FLAT_SURFACE_ROW, "a pad column's ground is the flat row (%d)" % ground)
	_check(sim.surface_row(col) == ground,
		"BEFORE digging the two authorities agree — which is how the wrong one got adopted")

	var shaft: int = 11
	for row: int in range(ground, ground + shaft):
		sim.mine(Vector2i(col, row))
	var body: int = ground + shaft - 1                  # standing on the floor of what we just dug

	_check(HeightmapWorldGen.ground_row(col) == ground, "ground_row is unmoved by the shaft")
	_check(sim.surface_row(col) == ground + shaft,
		"surface_row followed the body down to the shaft floor (%d)" % sim.surface_row(col))
	_check(body - HeightmapWorldGen.ground_row(col) == shaft - 1, "depth off the ground reads the real 10")
	_check(body - sim.surface_row(col) < 0,
		"depth off surface_row reads NEGATIVE eleven rows down — the defect, pinned so it cannot return")

	# The consumer thresholds, both sides. These are the two shipped bugs stated as assertions.
	_check(body - HeightmapWorldGen.ground_row(col) >= Hints.DEPTH_HINT_ROWS, "the GRAPPLE hint can fire")
	_check(body - sim.surface_row(col) < Hints.DEPTH_HINT_ROWS, "...and off surface_row it never could")
	_check(clampf(1.0 - float(body - HeightmapWorldGen.ground_row(col)) / 4.0, 0.0, 1.0) == 0.0,
		"the wind bed is silent at the bottom of the shaft")
	_check(clampf(1.0 - float(body - sim.surface_row(col)) / 4.0, 0.0, 1.0) == 1.0,
		"...and off surface_row it was at FULL surface wind down there")

	# And why the existing band guard was not already catching this: the shaft floor is legal ground.
	_check(sim.surface_row(col) <= HeightmapWorldGen.SURFACE_ROW_MAX,
		"the shaft floor is still inside the legal ground band")
	_check(FineTerrain.walked_surface(sim.surface_row(col)) != FineTerrain.NO_SURFACE,
		"walked_surface accepts the shaft floor as ground — it rejects rifts, not shafts")


## A GENERATED WORLD CONTAINS USABLE EXTRACTION SITES — and every assertion here runs on a world the
## GENERATOR built, never on a seeded fixture. That distinction is the entire point of this test.
##
## The sim has carried a complete lode system for two strikes: `take_lode`, the Drill Head, Spur chaining,
## the drain fraction, the through-rock stain. None of it could fire on a real world, because the only
## thing that ever wrote to `sim.lode` outside save/load was the mining branch — the blow that OPENS a
## vein. Lode was DERIVED from destroying an ore block and never generated. So a fresh world held exactly
## zero, the Borer and the Drift Rig cut rock with nothing behind it, and "generated deep pockets create
## usable extraction sites" was false by construction rather than by degree.
##
## It stayed invisible because every lode fixture in the suite INJECTS its lode through `world_seeder`.
## The seeded path was green for months while the generated path did not exist, and no assertion in the
## project could tell them apart — a controlled lode proves the extraction path GIVEN a lode, which is a
## different claim and fails differently. Hence the labelling, and hence a green here may never be cited
## for a seeded fixture nor a seeded green cited for this.
##
## The last four checks are the chain end to end: generator → WorldData → sim → the hand verb. Buried, it
## is not workable; clear the rock in front of it and it is; work it and it yields its ore. That sequence
## is the claim, and it is the one nothing in the suite could make before.
func _test_generated_lodes() -> void:
	print("- generated lodes (GENERATED WORLD — not a seeded fixture)")
	var gen := LayeredWorldGen.new()
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	var a: WorldData = gen.generate(cols, rows, 1337)

	_check(a.lodes.size() > 20, "a generated world contains lode at all (%d cells)" % a.lodes.size())
	_check(a.lodes == gen.generate(cols, rows, 1337).lodes, "same seed → identical lodes")
	_check(gen.generate(cols, rows, 99).lodes != a.lodes, "a different seed → different lodes")

	# THAT FLOOR IS WEAK AND I AM NOT PRETENDING OTHERWISE: 20 against an actual 378 would still pass with
	# the feature all but dead, and a floor I tuned to today's number would be a number I made up rather
	# than a property. So the load-bearing check is STRUCTURAL instead — the tier split. Lode follows the
	# division the world already means (ore above the seal, iron below it), and that cannot be satisfied by
	# accident: it fails if the pass stops running, if the depth banding breaks, or if everything piles into
	# one band. What density a player should actually MEET is a question for play, not for a constant
	# guessed here, and guessing it before playing has been wrong every time it has been tried.
	var above: int = 0
	var below: int = 0
	var kinds: Dictionary = {}
	for key: Variant in a.lodes:
		var c: Vector2i = key
		kinds[a.lodes[c]] = true
		if c.y >= LayeredWorldGen.SEAL_TOP + LayeredWorldGen.SEAL_ROWS:
			below += 1
		else:
			above += 1
	_check(above > 0 and below > 0,
		"lode is generated in BOTH tiers — %d above the seal, %d below it" % [above, below])
	_check(kinds.has(&"ore") and kinds.has(&"iron"),
		"and it carries each tier's own material rather than one everywhere (%s)" % [kinds.keys()])

	# --- the overlap guards, checked over EVERY lode cell rather than a sample ---
	var on_ore: int = 0
	var off_host: int = 0
	var wall_less: int = 0
	var too_shallow: int = 0
	var flooded: int = 0
	var empty: int = 0
	for key: Variant in a.lodes:
		var c: Vector2i = key
		var blk: StringName = a.blocks.get(c, &"")
		if blk == &"ore" or blk == &"rich_ore" or blk == &"iron" or blk == &"coal":
			on_ore += 1
		if blk != &"earth" and blk != &"stone" and blk != &"deepslate" and blk != &"shale":
			off_host += 1
		if not a.walls.has(c):
			wall_less += 1
		if c.y < HeightmapWorldGen.ground_row(c.x) + LayeredWorldGen.LODE_MIN_DEPTH:
			too_shallow += 1
		if a.water.has(c):
			flooded += 1
		if int(a.amounts.get(c, 0)) <= 0:
			empty += 1
	_check(on_ore == 0, "no lode shares a cell with a solid ore-like block — the double-source guard (%d)" % on_ore)
	_check(off_host == 0, "every lode sits behind host rock, never air/seal/foliage (%d bad)" % off_host)
	_check(wall_less == 0, "every lode has a wall behind it (%d without)" % wall_less)
	_check(too_shallow == 0, "no lode is in the near-surface shell (%d too shallow)" % too_shallow)
	_check(flooded == 0, "no lode was seeded inside an aquifer (%d flooded)" % flooded)
	_check(empty == 0, "every lode carries a positive deposit (%d empty)" % empty)

	# --- generator -> WorldData -> sim -> the hand verb ---
	var sim: FactorySim = FactorySim.new()
	sim.load_world(a)
	var in_grid: int = 0
	for key: Variant in a.lodes:
		if sim.in_bounds(key):
			in_grid += 1
	_check(sim.lode.size() == in_grid, "the sim ingested every in-bounds lode (%d)" % sim.lode.size())

	var probe: Vector2i = Vector2i(-1, -1)
	for key: Variant in a.lodes:
		if sim.is_solid(key):
			probe = key
			break
	_check(probe.x >= 0, "there is a lode behind solid rock to work (the case the whole design is about)")
	if probe.x >= 0:
		_check(not sim.lode_workable(probe), "a buried lode is NOT workable until the rock is cleared")
		sim.mine(probe)
		_check(sim.lode_workable(probe), "clearing the host rock EXPOSES a workable lode")
		_check(sim.take_lode(probe) == a.lodes[probe], "working the exposed lode yields its ore")


## Terrain is authoritative world state: solid cells block placement, mining clears them, and the
## avatar never touches this (it only reads is_solid). Groundwork for the embodied body (P2·S1a).
func _test_terrain() -> void:
	print("- terrain")
	var sim: FactorySim = FactorySim.new()
	var vent_def: MachineDef = load("res://src/data/machines/ore_vent.tres")
	sim.set_solid(Vector2i(3, 3))  # default &"earth"
	_check(sim.is_solid(Vector2i(3, 3)), "set_solid marks a cell solid")
	_check(sim.material_at(Vector2i(3, 3)) == &"earth", "default material is earth")
	_check(not sim.is_solid(Vector2i(4, 3)), "neighbouring cell stays open")
	_check(sim.place_machine(vent_def, Vector2i(3, 3)) == null, "cannot place a machine in solid earth")
	_check(sim.mine(Vector2i(3, 3)) == &"earth", "mining earth returns the earth material")
	_check(not sim.is_solid(Vector2i(3, 3)), "mined cell is now open")
	_check(sim.place_machine(vent_def, Vector2i(3, 3)) != null, "can place after mining out the earth")
	_check(sim.mine(Vector2i(5, 5)) == &"", "mining a non-solid cell yields nothing")
	_check(not sim.is_solid(Vector2i(-1, 0)), "out-of-bounds is never solid")


## The SHARED surface silhouette (sim.surface_row / sim.ramp_dir) the renderer draws and the avatar
## walks. Locks in: the slope is terrain-topology only, material-independent, ONE tile = a ramp, taller
## = a wall, and — the bug this whole slice fixes — a placed MACHINE never alters the silhouette (no
## phantom invisible diagonal). One authority → seen slope == walked slope, by construction.
func _test_surface_silhouette() -> void:
	print("- surface silhouette")
	var sim: FactorySim = FactorySim.new()
	# A flat run at row 10, with one column (5) raised a single tile, and column 8 raised TWO tiles.
	for col: int in range(3, 12):
		sim.set_solid(Vector2i(col, 10), &"earth")
	sim.set_solid(Vector2i(5, 9), &"earth")               # +1 step
	sim.set_solid(Vector2i(8, 9), &"stone")               # +2 tower (with the one below)
	sim.set_solid(Vector2i(8, 8), &"stone")
	_check(sim.surface_row(4) == 10, "surface_row finds the exposed top")
	_check(sim.surface_row(5) == 9, "surface_row tracks a raised column")
	_check(sim.surface_row(99) == FactorySim.GRID_ROWS, "an empty column has no surface")
	# Column 4 sits one tile below its right neighbour (col 5) → ramp rising to the RIGHT.
	_check(sim.ramp_dir(4) == 1, "a 1-tile step right reads as a rightward ramp")
	# Column 6 sits one tile below its left neighbour (col 5) → ramp rising to the LEFT.
	_check(sim.ramp_dir(6) == -1, "a 1-tile step left reads as a leftward ramp")
	_check(sim.ramp_dir(3) == 0, "flat ground has no ramp")
	# Stone slopes exactly like earth — geometry is material-independent (bug #1).
	_check(sim.surface_row(8) == 8 and sim.ramp_dir(7) == 0,
		"a 2-tile step is a WALL, not a ramp (only single steps slope)")
	# THE phantom-ramp killer: drop a machine onto FLAT ground (col 10, both neighbours level); the
	# silhouette must NOT move — no raised surface, no diagonal — so you bump the box, never glide it (bug #3).
	var proc_def: MachineDef = load("res://src/data/machines/processor.tres")
	_check(sim.ramp_dir(10) == 0, "flat ground reads flat before any machine")
	sim.place_machine(proc_def, Vector2i(10, 9))           # a machine standing on the flat row-10 ground
	_check(sim.surface_row(10) == 10, "a placed machine does NOT raise the surface silhouette")
	_check(sim.ramp_dir(10) == 0, "a placed machine casts NO phantom ramp (it's a box you bump, not a hill)")


## EVERY SURFACE IS WALKABLE. The body auto-steps up to 1.3 cells, so a 2-row rise between adjacent
## columns is a wall it has to jump — and a skyline built out of those is the "walking feels clunky"
## complaint in its purest form: you press right and the world says no, repeatedly, on ground that looks
## like a gentle hill. HeightmapWorldGen guarantees this arithmetically (its slope budget is documented at
## the constants), and this is the assertion that keeps the budget honest: a future amplitude bump that
## breaks it trips here rather than shipping a hillside nobody can climb.
##
## Checked across several seeds and both generators, because the surface function is shared and a
## subclass could reasonably decide to override it.
const MOUTH_GAP: int = 8         ## columns of walkable ground that separate one mouth from the next

func _test_surface_walkable() -> void:
	print("- surface walkability (no un-steppable rises)")
	for gen: WorldGen in [HeightmapWorldGen.new(), LayeredWorldGen.new()] as Array[WorldGen]:
		for seed_v: int in [1337, 4242, 20260807]:
			var world: WorldData = gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, seed_v)
			var worst: int = 0
			var worst_col: int = -1
			var stray: int = 0
			# A SINKHOLE is a hole in the ground, so of course the walked surface falls off a cliff at its
			# lip — that is the feature, not a broken heightmap. What must stay true is that the ground is a
			# walkable heightmap EVERYWHERE ELSE. Counted as PLACES rather than as column-steps: one mouth
			# is several rows of irregular throat and so several un-steppable boundaries, and a test that
			# counted those would be measuring how ragged a hole is instead of how many holes there are.
			var mouths: int = 0
			var last_cliff: int = -99
			# The SCARPS are the surface's other marked exception, and they are marked in the generator rather
			# than in the world, because a scarp is not a carve — it is where the heightmap itself changes
			# terrace. So they are recognised the same way a route is and counted separately: a face you climb
			# is not a hole you fall into, and letting them share a budget would mean adding one to the
			# skyline silently spent a sinkhole.
			var faces: int = 0
			var last_face: int = -99
			for col: int in range(world.cols - 1):
				var step: int = absi(_surface_of(world, col + 1) - _surface_of(world, col))
				if step <= 1:
					continue
				if step > worst:
					worst = step
					worst_col = col
				if HeightmapWorldGen.on_scarp(col) or HeightmapWorldGen.on_scarp(col + 1):
					if col - last_face > MOUTH_GAP:
						faces += 1
					last_face = col
					continue
				if not _route_column(world, col) and not _route_column(world, col + 1):
					stray += 1
				if col - last_cliff > MOUTH_GAP:
					mouths += 1
				last_cliff = col
			var name: String = gen.get_script().resource_path.get_file()
			_check(stray == 0,
				"%s seed %d: every un-steppable rise is the lip of a deliberate mouth or a scarp (%d stray, worst %d at col %d)"
				% [name, seed_v, stray, worst, worst_col])
			_check(mouths <= LayeredWorldGen.SINKHOLE_COUNT,
				"%s seed %d: and the ground falls away in only a few PLACES (%d, cap %d)"
				% [name, seed_v, mouths, LayeredWorldGen.SINKHOLE_COUNT])
			# Every designed face is PRESENT, which is the half of this a step budget cannot state: a scarp
			# quietly flattened by a clamp or eaten by a later pass would leave every assertion above green.
			_check(faces == HeightmapWorldGen.SCARP_COLS.size(),
				"%s seed %d: ...and every designed scarp actually stands (%d of %d)"
				% [name, seed_v, faces, HeightmapWorldGen.SCARP_COLS.size()])


## Topmost GROUND row of a generated column, read from the produced WorldData (so it measures what the
## world actually is after every pass, not what the height function intended before them). Flora and the
## bazaar ruin's timber are skipped: a tree trunk is a thing you chop, not a hill you climb, and counting
## a canopy as terrain reports a four-row "step" at the base of every tree.
const _NOT_GROUND: Array[StringName] = [&"wood", &"leaves"]


## Whether a deliberate route (a rift, or the sinkhole throat above it) passes through this column.
func _route_column(world: WorldData, col: int) -> bool:
	for row: int in world.rows:
		if world.routes.has(Vector2i(col, row)):
			return true
	return false


func _surface_of(world: WorldData, col: int) -> int:
	for row: int in world.rows:
		var m: StringName = world.blocks.get(Vector2i(col, row), &"")
		if m != &"" and not _NOT_GROUND.has(m):
			return row
	return world.rows


## The world-engine handshake: a generator produces a WorldData deterministically; the sim ingests
## it; mining carves a block but leaves its wall. Validates the gen↔sim contract independent of viz.
func _test_worldgen() -> void:
	print("- worldgen")
	var gen: WorldGen = HeightmapWorldGen.new()
	var a: WorldData = gen.generate(72, 40, 1337)
	var b: WorldData = gen.generate(72, 40, 1337)
	_check(a.blocks.size() > 0, "generated a non-empty world")
	_check(a.blocks == b.blocks, "same seed → identical blocks (deterministic)")
	var c: WorldData = gen.generate(72, 40, 99)
	_check(a.blocks != c.blocks, "a different seed → a different world (ore scatter varies)")
	# The stone smoke test: earth near the surface, stone deep down (richness via a new material id).
	var top: int = HeightmapWorldGen.FLAT_SURFACE_ROW
	_check(a.blocks.get(Vector2i(2, top)) == &"earth", "surface is earth")
	_check(a.blocks.get(Vector2i(2, top + HeightmapWorldGen.STONE_DEPTH + 2)) == &"stone",
		"deep cells are stone (a new material dropped into generation)")
	# The background WALL layer (Slice 3): walls behind every sub-surface cell, matching the rock zone.
	_check(a.walls.size() > 0 and a.walls == b.walls, "walls generated + deterministic")
	_check(a.walls.get(Vector2i(2, top)) == &"dirt_wall", "near-surface wall is dirt")
	_check(a.walls.get(Vector2i(2, top + HeightmapWorldGen.STONE_DEPTH + 2)) == &"stone_wall",
		"deep wall is stone")


	# Ingest + wall persistence (Slice 3): mining clears the block, keeps the wall.
	var sim: FactorySim = FactorySim.new()
	sim.load_world(a)
	_check(sim.is_solid(Vector2i(2, top)), "sim ingested the world (surface cell is solid)")
	sim.set_wall(Vector2i(2, top), &"stone_wall")
	sim.mine(Vector2i(2, top))
	_check(not sim.is_solid(Vector2i(2, top)), "mining cleared the block")
	_check(sim.wall_at(Vector2i(2, top)) == &"stone_wall", "the background wall survives mining the block")


## The RICHER generator: same WorldData contract, deterministic, but now with CAVES (carved cells
## that keep their wall, only below CAVE_MIN_DEPTH so the base stays solid) and DEPTH-BANDED ore
## (more ore deep than shallow — the "deeper = richer" pull). Still emits only known material ids, so
## the renderer is untouched.
func _test_layered_worldgen() -> void:
	print("- layered worldgen")
	var gen: WorldGen = LayeredWorldGen.new()
	# Measure on the REAL world size: solid≫cave is a full-world property, and a truncated 40-row slice is
	# disproportionately "deep" (its whole band sits in the low-threshold zone) so it over-reads cave.
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	var mid: int = rows / 2
	var a: WorldData = gen.generate(cols, rows, 1337)
	var b: WorldData = gen.generate(cols, rows, 1337)
	_check(a.blocks == b.blocks, "same seed → identical blocks (deterministic, caves + veins)")
	_check(gen.generate(cols, rows, 99).blocks != a.blocks, "a different seed → a different world")

	# CAVES: some sub-surface cells are carved OPEN (block gone) yet still have a wall behind them —
	# a Terraria carved room. And the near-surface base is untouched (caves only below CAVE_MIN_DEPTH).
	var carved: int = 0
	var carved_with_wall: int = 0
	var route_cells: int = 0
	var breached_base: int = 0
	var breached_off_route: int = 0
	var mouth_cols: Dictionary = {}
	var solid_below: int = 0
	var hm := HeightmapWorldGen.new()
	for col: int in cols:
		var top: int = hm.ground_row(col)
		for row: int in range(top, rows):
			var cell: Vector2i = Vector2i(col, row)
			if not a.blocks.has(cell) and a.walls.has(cell):
				carved += 1
				carved_with_wall += 1
				if a.routes.has(cell):
					route_cells += 1
				if row < top + LayeredWorldGen.CAVE_MIN_DEPTH:
					breached_base += 1
					if a.routes.has(cell):
						mouth_cols[col] = true
					else:
						breached_off_route += 1
			elif row > top and a.blocks.has(cell):
				solid_below += 1
	_check(carved > 50, "caves carved open cells in the rock (%d)" % carved)
	_check(carved_with_wall == carved, "every carved cell kept its wall (Terraria room, not void)")

	# THE LID, AND ITS DOORS. The near-surface band stays solid by construction — the open dark is
	# something you go DOWN to, never something that opens under your feet — with the deliberate exception
	# of the sinkhole mouths. Applied without exception the rule sealed the ENTIRE underground under an
	# unbroken lid (tools/check_descent measured the whole connected open space of a world reaching one row
	# below the surface, with forty rows of chasm in a bottle beneath it), so what is guarded now is the
	# rule as designed: no UNDIRECTED carve may touch the base, and the doors are few and deliberate.
	_check(breached_off_route == 0,
		"no undirected cave breached the near-surface base (%d cells)" % breached_off_route)
	_check(mouth_cols.size() > 0, "...but the lid does have doors in it (%d columns)" % mouth_cols.size())

	# DIG-YOUR-FACTORY (#107, PROGRESSION §10 / DESIGN_REVIEW F2): the underground must be SOLID-dominant —
	# you carve your factory INTO ore-rich rock; caves are the rarer opt-in punctuation, NOT the medium you
	# traverse (follow-the-cave). Guard the identity so a future gen change can't silently drift it back.
	#
	# Measured on UNDIRECTED cave, because that is what the identity is about. A rift cut on purpose to give
	# the world a vertical dimension, and the throat that connects it to daylight, are the opposite of the
	# thing this guard defends against while being indistinguishable from it in a raw open-cell count — so
	# counting them here does not protect the identity, it just makes deliberate structure unaffordable.
	# The generator marks its own route carves (WorldData.routes); a second, looser ceiling on the TOTAL
	# still catches a world that has simply become swiss cheese by any means.
	var total_below: int = maxi(1, solid_below + carved)
	var undirected: float = float(carved - route_cells) / float(total_below)
	var open_frac: float = float(carved) / float(total_below)
	_check(undirected < 0.25,
		"solid >> cave: UNDIRECTED cave stays opt-in punctuation (%.1f%% of below-surface)"
		% [undirected * 100.0])
	_check(open_frac < 0.32,
		"...and the underground is solid-dominant all in (%.1f%% open, routes included)"
		% [open_frac * 100.0])

	# DEPTH-BANDED ORE: count ore in the top half vs the bottom half of the sub-surface column band.
	var ore_shallow: int = 0
	var ore_deep: int = 0
	for cell: Vector2i in a.blocks:
		if a.blocks[cell] == &"ore":
			if cell.y < mid:
				ore_shallow += 1
			else:
				ore_deep += 1
	_check(ore_deep > ore_shallow, "ore is depth-banded: more deep than shallow (deep=%d, shallow=%d)"
		% [ore_deep, ore_shallow])

	# Still ingests cleanly through the same contract (carved cells load as not-solid, walls intact).
	var sim: FactorySim = FactorySim.new()
	sim.load_world(a)
	var probe: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in a.walls:
		if not a.blocks.has(cell):
			probe = cell
			break
	_check(probe.x >= 0, "found a carved cave cell to probe")
	_check(not sim.is_solid(probe), "a carved cave loads as open (not solid)")
	_check(sim.wall_at(probe) != &"", "the carved cave still shows its background wall")

	# --- AQUIFERS (L3, slice 3a): deep SEALED water pockets seeded into carved rock. ---
	_check(not a.water.is_empty(), "aquifers seeded some water (%d cells)" % a.water.size())
	var watered: int = 0
	var near_surface: int = 0
	var bad_level: int = 0
	var in_solid: int = 0
	var seal_lo: int = LayeredWorldGen.SEAL_TOP
	var seal_hi: int = LayeredWorldGen.SEAL_TOP + LayeredWorldGen.SEAL_ROWS - 1
	for wc: Vector2i in a.water:
		watered += 1
		var lvl: int = int(a.water[wc])
		if lvl < 1 or lvl > FactorySim.WATER_MAX:
			bad_level += 1
		# DEEP + BASE-SAFE: every watered cell sits below its column's base-safe band, never near the surface.
		if wc.y < hm.ground_row(wc.x) + LayeredWorldGen.CAVE_MIN_DEPTH:
			near_surface += 1
		# NO watered cell is also solid rock (water only lives in the cells the aquifer pass carved open).
		if a.blocks.has(wc):
			in_solid += 1
		# ...and never inside the inviolate seal band.
		if wc.y >= seal_lo and wc.y <= seal_hi:
			in_solid += 1
	_check(watered > 0, "aquifer water exists (%d watered cells)" % watered)
	_check(near_surface == 0, "no aquifer water in the base-safe band (all deep, base stays dry)")
	_check(bad_level == 0, "every water level is valid (1..WATER_MAX)")
	_check(in_solid == 0, "no watered cell is solid or in the seal band (water only in carved cells)")
	# DETERMINISM: same seed → identical water grid (seeded rng only, no time/global random).
	_check(a.water == b.water, "same seed → identical aquifer water (deterministic)")
	# INGEST: the sim loads the water and it survives the contract (matches the generated grid).
	_check(sim.total_water() > 0, "load_world ingested the aquifer water (total=%d)" % sim.total_water())
	var water_match: bool = sim.water.size() == a.water.size()
	if water_match:
		for wc2: Vector2i in a.water:
			if sim.water_at(wc2) != int(a.water[wc2]):
				water_match = false
				break
	_check(water_match, "sim.water matches the generated world's water grid exactly")

	# --- AQUIFER TREASURE (L3 risk/REWARD): the flood GUARDS a rich vein. Every watered cell adjacent to
	# solid rock must have &"rich_ore" reachable in its immediate solid surround — so a player who breaches +
	# drains + mines the drained pocket's walls is rewarded with high-grade ore. Deterministic on seed 1337.
	var rich_neighbours: int = 0            # water cells with rich_ore in a 4-neighbour solid wall
	var rich_deposits: int = 0             # those rich cells that carry a valid deposit amount
	var rich_seen: Dictionary = {}
	for wc3: Vector2i in a.water:
		for d3: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb3: Vector2i = wc3 + d3
			if a.blocks.get(nb3, &"") == &"rich_ore":
				rich_neighbours += 1
				if not rich_seen.has(nb3):
					rich_seen[nb3] = true
					if int(a.amounts.get(nb3, 0)) > 0:
						rich_deposits += 1
				break
	_check(rich_neighbours > 0,
		"aquifer walls are lined with rich_ore (the reward guarded by the flood; %d water cells touch it)"
		% rich_neighbours)
	_check(rich_deposits > 0 and rich_deposits == rich_seen.size(),
		"every aquifer-wall rich_ore cell carries a real deposit amount (%d cells, all valid)" % rich_deposits)
	# The rich ore lines the SOLID rock — it is never a watered/carved cell (grows into rock, not the pocket).
	var rich_in_water: int = 0
	for rc: Vector2i in rich_seen:
		if a.water.has(rc):
			rich_in_water += 1
	_check(rich_in_water == 0, "aquifer rich_ore is only in solid rock, never in the flooded cells")


## WORLDGEN FUZZ (the invariant sweep): generate MANY worlds across a matrix of seeds × sizes and assert
## the generation invariants hold UNIVERSALLY, not just for _test_layered_worldgen's one happy-path
## size/seed. The happy path can pass while an edge seed holes the seal, an edge size breaks base-safety,
## or a stray cell lands OOB / water sits in rock. Each world is checked structurally (pure generation,
## no ticks) so the whole sweep stays fast. A single failing (seed,size) reports its exact offending numbers.
##
## Invariants asserted per world:
##   1. In-bounds     — every blocks/walls/amounts/water key is within (cols,rows).
##   2. Base-safe     — no carved cave AND no water within CAVE_MIN_DEPTH of the column's surface.
##   3. Seal intact   — rows SEAL_TOP..+SEAL_ROWS-1 are full-width sealrock (only when the world contains them).
##   4. No water in rock — no cell is both solid and watered; every water level is in 1..WATER_MAX.
##   5. Water deep    — every water cell is below the base-safe band (aquifers never near surface).
##   6. Determinism   — same (seed,size) twice → identical blocks/walls/amounts/water.
##   7. Load-clean    — load_world ingests without crash; sim.total_water() matches the generated grid
##                      (sizes are kept ≤ the sim's fixed GRID so nothing is clamped away).
##   8. Lode legal    — every generated vein is behind host rock, dry, outside the seal, walled, and rich;
##                      and the plane ingests whole (count, material, positive lode_max).
##   9. Lode usable   — on every PRODUCTION-size world: a buried vein in each tier, and the chain through
##                      the real contract — buried → not workable; clear the rock → workable; work it →
##                      yields its own ore. The arm's own coverage is asserted, not assumed.
##
## 8 and 9 exist because the lode plane's first evidence was a single seed. `_test_generated_lodes` runs
## seed 1337 at one size and proves the design; it cannot speak for the generator across seeds, and the
## sweep that was built for exactly that did not know the plane existed. Citing the one-seed guard as
## cross-seed evidence would have been the same error the plane itself was introduced to fix — a sound
## instrument reporting on a population it was never pointed at.
func _test_worldgen_fuzz() -> void:
	print("- worldgen fuzz (seeds × sizes)")
	var gen := LayeredWorldGen.new()
	# ground_row is seed/size-independent; a fresh heightmap gen gives us the same surface authority the
	# generator uses internally (base-safe band = ground_row(col) + CAVE_MIN_DEPTH).
	var hm := HeightmapWorldGen.new()

	var seeds: Array[int] = [0, 1, 7, 42, 1337, 99999, 20260807, 314159, 2, 123456789, 555, 88888]
	# Sizes: the REAL size plus small/edge dims. All kept ≤ the sim's fixed GRID_COLS×GRID_ROWS so
	# load_world (which clamps to that fixed grid via in_bounds) ingests every cell — a clean load check.
	var sizes: Array[Vector2i] = [
		Vector2i(FactorySim.GRID_COLS, FactorySim.GRID_ROWS),   # 96×80, the shipping size
		Vector2i(72, 40),                                        # the old happy-path dims
		Vector2i(48, 40),
		Vector2i(32, 24),
		Vector2i(20, 20),                                        # tiny — surface (17..25) crowds the floor
	]

	var seal_lo: int = LayeredWorldGen.SEAL_TOP
	var seal_hi: int = LayeredWorldGen.SEAL_TOP + LayeredWorldGen.SEAL_ROWS - 1
	var worlds: int = 0

	# Accumulated failure counts across the whole sweep — a single _check per invariant reports the FIRST
	# offending (seed,size)+numbers, so a red is precise instead of a wall of repeats.
	var oob_fail: String = ""
	var basesafe_fail: String = ""
	var seal_fail: String = ""
	var water_rock_fail: String = ""
	var water_level_fail: String = ""
	var water_deep_fail: String = ""
	var determinism_fail: String = ""
	var load_fail: String = ""
	var lode_legal_fail: String = ""
	var lode_amount_fail: String = ""
	var lode_tier_fail: String = ""
	var lode_load_fail: String = ""
	var tier_worlds: int = 0

	for seed: int in seeds:
		for dim: Vector2i in sizes:
			var cols: int = dim.x
			var rows: int = dim.y
			var world: WorldData = gen.generate(cols, rows, seed)
			worlds += 1
			var tag: String = "(seed=%d, %dx%d)" % [seed, cols, rows]

			# --- 1. IN-BOUNDS: every key of every grid sits inside (cols,rows). ---
			if oob_fail == "":
				for grid: Dictionary in [world.blocks, world.walls, world.amounts, world.water, world.lodes]:
					for cell: Vector2i in grid:
						if not world.in_bounds(cell):
							oob_fail = "%s cell %s out of bounds" % [tag, str(cell)]
							break
					if oob_fail != "":
						break

			# --- 2/5. BASE-SAFE + WATER-DEEP: nothing carved or watered in a column's base-safe band. ---
			# A carved cave = a cell with a wall but no block, below the surface. It (and any water) must
			# never sit within CAVE_MIN_DEPTH of the column surface — the spawn base stays solid + dry.
			if basesafe_fail == "":
				for col: int in cols:
					var top: int = hm.ground_row(col)
					var safe_bottom: int = top + LayeredWorldGen.CAVE_MIN_DEPTH   # first cave-eligible row
					for row: int in range(top, mini(safe_bottom, rows)):
						var cell := Vector2i(col, row)
						# Carved = wall present, block absent (a Terraria room). A never-filled sky cell has
						# neither, so require the wall to distinguish a carved cave from open air above ground.
						# ...except a sinkhole throat, which is the one carve allowed to reach daylight and
						# is the reason the underground is reachable at all (see WorldData.routes).
						if world.walls.has(cell) and not world.blocks.has(cell) and not world.routes.has(cell):
							basesafe_fail = "%s carved cave at %s within base-safe band (surface=%d)" \
								% [tag, str(cell), top]
							break
						if world.water.has(cell):
							basesafe_fail = "%s water at %s within base-safe band (surface=%d)" \
								% [tag, str(cell), top]
							break
					if basesafe_fail != "":
						break

			# --- 3. SEAL INTACT: rows SEAL_TOP..seal_hi are FULL-WIDTH sealrock, only when tall enough. ---
			if seal_fail == "" and rows > seal_hi:
				for row: int in range(seal_lo, seal_hi + 1):
					for col: int in cols:
						if world.blocks.get(Vector2i(col, row), &"") != &"sealrock":
							seal_fail = "%s seal HOLE at %s (blocks=%s)" \
								% [tag, str(Vector2i(col, row)), str(world.blocks.get(Vector2i(col, row), &"<air>"))]
							break
					if seal_fail != "":
						break

			# --- 4. NO WATER IN ROCK + valid levels. ---
			for wc: Vector2i in world.water:
				var lvl: int = int(world.water[wc])
				if world.blocks.has(wc) and water_rock_fail == "":
					water_rock_fail = "%s watered cell %s is ALSO solid (%s)" \
						% [tag, str(wc), str(world.blocks[wc])]
				if (lvl < 1 or lvl > FactorySim.WATER_MAX) and water_level_fail == "":
					water_level_fail = "%s water level %d at %s out of 1..%d" \
						% [tag, lvl, str(wc), FactorySim.WATER_MAX]
				# --- 5. WATER DEEP: below the base-safe band AND at/below the deep aquifer band. ---
				var wtop: int = hm.ground_row(wc.x)
				if wc.y < wtop + LayeredWorldGen.CAVE_MIN_DEPTH and water_deep_fail == "":
					water_deep_fail = "%s water at %s within base-safe band (surface=%d)" % [tag, str(wc), wtop]
				if wc.y < LayeredWorldGen.AQUIFER_MIN_ROW and water_deep_fail == "":
					water_deep_fail = "%s water at %s above AQUIFER_MIN_ROW=%d" \
						% [tag, str(wc), LayeredWorldGen.AQUIFER_MIN_ROW]

			# --- 8. LODE LEGALITY: every generated vein is behind host rock, dry, out of the seal, and rich. ---
			# The single-seed guard (_test_generated_lodes) proves this for seed 1337 at one size. That is one
			# world, and the lode plane is generated per-seed like everything else here — so the cross-seed
			# claim belongs in the population that already sweeps seeds, not beside it.
			for lc: Vector2i in world.lodes:
				var host: StringName = world.blocks.get(lc, &"")
				if lode_legal_fail == "":
					if host != &"earth" and host != &"stone" and host != &"deepslate" and host != &"shale":
						lode_legal_fail = "%s lode %s host is %s, not host rock" \
							% [tag, str(lc), str(host) if host != &"" else "<air>"]
					elif world.water.has(lc):
						lode_legal_fail = "%s lode %s is inside an aquifer" % [tag, str(lc)]
					elif lc.y >= seal_lo and lc.y <= seal_hi:
						lode_legal_fail = "%s lode %s is inside the seal band" % [tag, str(lc)]
					elif not world.walls.has(lc):
						lode_legal_fail = "%s lode %s has no wall behind it" % [tag, str(lc)]
				# Richness is the deposit — a lode with none is a vein that pays nothing, which is the
				# generated-world version of the defect this whole plane exists to fix.
				if int(world.amounts.get(lc, 0)) <= 0 and lode_amount_fail == "":
					lode_amount_fail = "%s lode %s carries deposit %d" \
						% [tag, str(lc), int(world.amounts.get(lc, 0))]

			# --- 9. USABLE BURIED LODE IN BOTH TIERS, production-size worlds only. ---
			# Guarded on `rows > seal_hi` because a 20- or 40-row world has no below-seal band at all, and an
			# arm that silently skips every world it cannot satisfy is the vacuity this suite keeps finding in
			# other people's fixtures. `tier_worlds` is asserted against the seed count below, so if the guard
			# ever stops admitting anything the sweep FAILS instead of quietly proving nothing.
			if rows > seal_hi:
				tier_worlds += 1
				var l2_top: int = LayeredWorldGen.SEAL_TOP + LayeredWorldGen.SEAL_ROWS
				var probe_above: Vector2i = Vector2i(-1, -1)
				var probe_below: Vector2i = Vector2i(-1, -1)
				for lc2: Vector2i in world.lodes:
					if not world.blocks.has(lc2):
						continue                                  # only a BURIED vein is the case in question
					if lc2.y >= l2_top:
						if probe_below.x < 0:
							probe_below = lc2
					elif probe_above.x < 0:
						probe_above = lc2
				if probe_above.x < 0 and lode_tier_fail == "":
					lode_tier_fail = "%s no buried lode above the seal" % tag
				elif probe_below.x < 0 and lode_tier_fail == "":
					lode_tier_fail = "%s no buried lode below the seal" % tag
				elif lode_tier_fail == "":
					# The chain, through the real contract: buried → not workable; clear the host rock →
					# workable; work it → yields its own ore. Both tiers, every seed.
					var tsim: FactorySim = FactorySim.new()
					tsim.load_world(world)
					for probe: Vector2i in [probe_above, probe_below]:
						if tsim.lode_workable(probe):
							lode_tier_fail = "%s buried lode %s was workable before the rock was cleared" \
								% [tag, str(probe)]
							break
						tsim.mine(probe)
						if not tsim.lode_workable(probe):
							lode_tier_fail = "%s clearing rock at %s exposed no workable lode" % [tag, str(probe)]
							break
						if tsim.take_lode(probe) != world.lodes[probe]:
							lode_tier_fail = "%s working the exposed lode at %s yielded the wrong ore" \
								% [tag, str(probe)]
							break

			# --- 6. DETERMINISM: regenerating the same (seed,size) yields identical grids. ---
			if determinism_fail == "":
				var again: WorldData = gen.generate(cols, rows, seed)
				if world.blocks != again.blocks:
					determinism_fail = "%s blocks differ on regen" % tag
				elif world.walls != again.walls:
					determinism_fail = "%s walls differ on regen" % tag
				elif world.amounts != again.amounts:
					determinism_fail = "%s amounts differ on regen" % tag
				elif world.water != again.water:
					determinism_fail = "%s water differs on regen" % tag
				elif world.lodes != again.lodes:
					determinism_fail = "%s lodes differ on regen" % tag

			# --- 7. LOAD-CLEAN: ingest through the real contract; total_water matches the grid. ---
			if load_fail == "" or lode_load_fail == "":
				var sim: FactorySim = FactorySim.new()
				sim.load_world(world)
				# Sizes are ≤ the fixed sim grid, so no cell is clamped away → the water totals must match.
				var grid_total: int = 0
				for v: Variant in world.water.values():
					grid_total += int(v)
				if load_fail != "":
					pass                                          # already reported; keep checking the lode plane
				elif sim.total_water() != grid_total:
					load_fail = "%s total_water mismatch: sim=%d grid=%d" \
						% [tag, sim.total_water(), grid_total]
				else:
					# Spot conservation/sanity: a freshly loaded (un-ticked) world invents no items.
					for it: StringName in [&"ore", &"ingot", &"iron"]:
						if _items_present(sim, it) != int(sim.total_produced.get(it, 0)):
							load_fail = "%s load invented %s (present=%d produced=%d)" \
								% [tag, it, _items_present(sim, it), int(sim.total_produced.get(it, 0))]
							break
				# LODE INGESTION, through the same contract and NOT gated on the water arm — the two failures
				# are independent and coupling them would let one mask the other. The plane must arrive whole:
				# same count, same material per cell, and a positive `lode_max`, which is the denominator the
				# fleck field thins against. A lode that loads with a zero denominator draws as a stripped vein
				# on an untouched one — the exact bug `lode_max` was introduced to fix.
				if lode_load_fail == "":
					if sim.lode.size() != world.lodes.size():
						lode_load_fail = "%s lode count mismatch: sim=%d grid=%d" \
							% [tag, sim.lode.size(), world.lodes.size()]
					else:
						for lc3: Vector2i in world.lodes:
							if sim.lode_at(lc3) != world.lodes[lc3]:
								lode_load_fail = "%s lode %s ingested as %s, generated as %s" \
									% [tag, str(lc3), str(sim.lode_at(lc3)), str(world.lodes[lc3])]
								break
							if int(sim.lode_max.get(lc3, 0)) <= 0:
								lode_load_fail = "%s lode %s ingested with lode_max=%d" \
									% [tag, str(lc3), int(sim.lode_max.get(lc3, 0))]
								break

	_check(worlds == seeds.size() * sizes.size(),
		"fuzzed the whole matrix (%d worlds = %d seeds × %d sizes)" % [worlds, seeds.size(), sizes.size()])
	_check(oob_fail == "", "in-bounds: every grid key is within (cols,rows) — %s"
		% ("OK" if oob_fail == "" else oob_fail))
	_check(basesafe_fail == "", "base-safe: no cave/water in any column's near-surface band — %s"
		% ("OK" if basesafe_fail == "" else basesafe_fail))
	_check(seal_fail == "", "seal intact: full-width sealrock where the world contains the seal — %s"
		% ("OK" if seal_fail == "" else seal_fail))
	_check(water_rock_fail == "", "no water in rock: no cell is both solid and watered — %s"
		% ("OK" if water_rock_fail == "" else water_rock_fail))
	_check(water_level_fail == "", "water levels valid: every level in 1..WATER_MAX — %s"
		% ("OK" if water_level_fail == "" else water_level_fail))
	_check(water_deep_fail == "", "water deep: every water cell below the base-safe + aquifer band — %s"
		% ("OK" if water_deep_fail == "" else water_deep_fail))
	_check(determinism_fail == "", "determinism: same (seed,size) → identical grids — %s"
		% ("OK" if determinism_fail == "" else determinism_fail))
	_check(load_fail == "", "load-clean: ingests without error, water/items conserved — %s"
		% ("OK" if load_fail == "" else load_fail))
	_check(lode_legal_fail == "",
		"lode legal: every generated vein is behind host rock, dry, out of the seal, walled — %s"
		% ("OK" if lode_legal_fail == "" else lode_legal_fail))
	_check(lode_amount_fail == "", "lode richness: every generated vein carries a positive deposit — %s"
		% ("OK" if lode_amount_fail == "" else lode_amount_fail))
	_check(lode_load_fail == "",
		"lode load-clean: the plane ingests whole — count, material and a positive lode_max — %s"
		% ("OK" if lode_load_fail == "" else lode_load_fail))
	# NON-VACUITY GUARD ON THE TIER ARM. It is skipped for any world too short to contain the seal band,
	# which is every size in this matrix except the production one. If that guard ever stops admitting
	# worlds — a shrunk production size, a moved seal — the arm would pass by testing nothing, so the count
	# is asserted rather than trusted. This is the assertion I would have omitted a week ago.
	_check(tier_worlds == seeds.size(),
		"the both-tier arm actually ran on every production-size world (%d of %d seeds)"
		% [tier_worlds, seeds.size()])
	_check(lode_tier_fail == "",
		"usable buried lode in BOTH tiers, every seed: buried → clear the rock → workable → yields ore — %s"
		% ("OK" if lode_tier_fail == "" else lode_tier_fail))


## HORIZONTAL ore pull (the frontier fix): ore richness varies across X at a fixed depth, with the richest
## bands AWAY from spawn — so the cheapest fresh vein isn't always straight down the spawn column. Asserts
## the distribution is NOT uniform across x (there exist frontier x-regions statistically richer than the
## spawn region), AND that the horizontal term is fully deterministic (same seed → identical world).
func _test_horizontal_ore_pull() -> void:
	print("- horizontal ore pull (frontier richness)")
	var gen := LayeredWorldGen.new()
	var cols: int = FactorySim.GRID_COLS
	var rows: int = FactorySim.GRID_ROWS
	var world: WorldData = gen.generate(cols, rows, 20260807)

	# DETERMINISM: the whole world (blocks + amounts) reproduces bit-for-bit, so the new horizontal field
	# introduced no time/global-random dependence.
	var again: WorldData = gen.generate(cols, rows, 20260807)
	_check(world.blocks == again.blocks, "same seed → identical blocks (horizontal field is deterministic)")
	_check(world.amounts == again.amounts, "same seed → identical per-cell deposits (deterministic richness)")

	# Sum ore MASS (deposit richness) per column over a FIXED depth band, so any variation is purely
	# horizontal (depth is held constant across the comparison). Above the seal so all cells are real ore rock.
	var band_top: int = 30
	var band_bot: int = mini(LayeredWorldGen.SEAL_TOP, rows)
	var col_mass: PackedInt32Array = PackedInt32Array()
	col_mass.resize(cols)
	for cell: Vector2i in world.blocks:
		var m: StringName = world.blocks[cell]
		if (m == &"ore" or m == &"rich_ore" or m == &"coal") and cell.y >= band_top and cell.y < band_bot:
			col_mass[cell.x] += int(world.amounts.get(cell, 1))

	# Region masses: a spawn-centred window vs the two frontier edges (away from spawn on either side).
	var spawn: int = LayeredWorldGen.SPAWN_COL
	var half: int = 8
	var spawn_mass: int = _region_mass(col_mass, spawn - half, spawn + half)
	var left_mass: int = _region_mass(col_mass, 0, 2 * half)                     # far-left frontier
	var right_mass: int = _region_mass(col_mass, cols - 2 * half, cols)          # far-right frontier
	var frontier_mass: int = maxi(left_mass, right_mass)

	# NOT uniform: at a fixed depth some x-regions carry more ore than the spawn region — the frontier is
	# meaningfully richer (the "you must leave spawn" pull). Guard against a degenerate all-empty band.
	_check(spawn_mass + frontier_mass > 0, "the fixed depth band actually contains ore (spawn=%d, frontier=%d)"
		% [spawn_mass, frontier_mass])
	_check(frontier_mass > spawn_mass, "a frontier x-region is richer than spawn at a fixed depth (frontier=%d > spawn=%d)"
		% [frontier_mass, spawn_mass])

	# And the variation is a real spread, not one lucky cell: the richest window clears the spawn window by a
	# clear margin (the field's design — bands differ by up to ~2×HORIZONTAL_STRENGTH).
	_check(frontier_mass >= int(round(float(maxi(1, spawn_mass)) * 1.15)),
		"the frontier richness edge is a meaningful margin, not noise (%.2fx spawn)"
		% (float(frontier_mass) / float(maxi(1, spawn_mass))))

	# The field respects its own bound (subtlety guarantee): every column multiplier is within
	# [1-STRENGTH, 1+STRENGTH], so near-spawn ore is thinned but never nuked.
	var hfield: PackedFloat32Array = gen._horizontal_field(cols, 20260807)
	var in_bound: bool = true
	for c: int in cols:
		if hfield[c] < 1.0 - LayeredWorldGen.HORIZONTAL_STRENGTH - 0.0001 \
				or hfield[c] > 1.0 + LayeredWorldGen.HORIZONTAL_STRENGTH + 0.0001:
			in_bound = false
	_check(in_bound, "the horizontal multiplier stays bounded by HORIZONTAL_STRENGTH (subtle, never nukes spawn)")


## Sum a slice [lo, hi) of a per-column mass array, clamped to bounds. (test helper)
func _region_mass(col_mass: PackedInt32Array, lo: int, hi: int) -> int:
	var total: int = 0
	for c: int in range(maxi(0, lo), mini(col_mass.size(), hi)):
		total += col_mass[c]
	return total


## ORE QUALITY: vein seeds landing in/below the deepslate band come up RICH — a distinct
## material (it READS in-world) whose chunk the Enrichment-gated BLAST FURNACE smelts 1 → 2 ingots.
## Deeper = richer gains its second axis: deep veins aren't just bigger, they're better.
func _test_rich_ore() -> void:
	print("- rich ore + the blast furnace (#48)")
	# Worldgen: rich veins exist, and only around/below the deepslate band (seeds are band-gated; a
	# grown blob may crest a few rows above its seed, never further).
	var gen := LayeredWorldGen.new()
	var world: WorldData = gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, 4242)
	var rich_cells: int = 0
	var too_shallow: int = 0
	for cell: Vector2i in world.blocks:
		if world.blocks[cell] == &"rich_ore":
			rich_cells += 1
			if cell.y < LayeredWorldGen.DEEPSLATE_ROW - 8:
				too_shallow += 1
	_check(rich_cells > 0, "worldgen seeded rich veins (%d cells)" % rich_cells)
	_check(too_shallow == 0, "rich ore stays a DEEP find (none far above the band; %d strays)" % too_shallow)
	_check(MiningRules.required_tier(&"rich_ore") == 2, "rich ore wants the tier-2 pick (the shelf's own gate)")
	# The research gate: the Blast Furnace crafts only once ENRICHMENT is in.
	var sim: FactorySim = FactorySim.new()
	var bf_def: MachineDef = load("res://src/data/machines/blast_furnace.tres")
	_check(ResearchRules.locking_tech(&"blast_furnace") == &"enrichment", "the Blast Furnace gates on Enrichment")
	sim.inventory[&"plate"] = 2; sim.total_produced[&"plate"] = 2
	sim.inventory[&"gear"] = 1; sim.total_produced[&"gear"] = 1
	_check(not sim.craft(bf_def), "the Blast Furnace refuses before Enrichment")
	for t: StringName in [&"automation", &"power", &"descent", &"ironworks", &"machining"]:
		sim.research[t] = true
	sim.inventory[&"rich_ore"] = 1; sim.total_produced[&"rich_ore"] = 1
	sim.inventory[&"iron_ingot"] = 4; sim.total_produced[&"iron_ingot"] = 4
	_check(sim.research_tech(&"enrichment"), "Enrichment researches (rich-ore sample + 4 iron ingots)")
	_check(sim.craft(bf_def), "…and the Blast Furnace crafts (2 plate + 1 gear)")
	# 1 rich ore → 2 ingots, gravity-fed, conserved (double the plain forge's 2-ore-per-ingot density).
	sim.set_solid(Vector2i(6, 6), &"stone")
	sim.place_machine(bf_def, Vector2i(6, 3))
	sim.inventory[&"rich_ore"] = int(sim.inventory.get(&"rich_ore", 0)) + 3
	sim.total_produced[&"rich_ore"] = int(sim.total_produced.get(&"rich_ore", 0)) + 3
	sim.drop_item(Vector2i(6, 1), &"rich_ore", 3)
	for _i: int in 400:
		sim.tick()
	var pile: Dictionary = sim.ground.get(Vector2i(6, 5), {})
	_check(int(pile.get(&"ingot", 0)) == 6, "3 rich ore poured in came out 6 ingots (%s)" % str(pile))
	for item: StringName in [&"rich_ore", &"ingot", &"plate", &"gear", &"iron_ingot"]:
		var present: int = _items_present(sim, item)
		var net: int = int(sim.total_produced.get(item, 0)) - int(sim.total_consumed.get(item, 0))
		_check(present == net, "%s conserved through enrichment (present=%d, net=%d)" % [item, present, net])


## FINE TERRAIN (P2 — the dual-grid overhaul). The fine grid is ADDITIVE + DERIVED:
## it must be (a) deterministic from seed, (b) NEVER change the coarse authority that ALL logistics read,
## (c) stay in sync when a coarse cell is edited, and (d) rebuild identically after a load. If any of these
## breaks, the locked hook or the save format is at risk — so this is a guardrail, not a feature test.
func _test_fine_terrain() -> void:
	print("[fine terrain]")
	var gen: WorldGen = LayeredWorldGen.new()
	var world: WorldData = gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, 1337)

	# (a) DETERMINISM — same seed → identical fine array across two independent loads.
	var s1: FactorySim = FactorySim.new()
	s1.load_world(world)
	var s2: FactorySim = FactorySim.new()
	s2.load_world(gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, 1337))
	_check(s1.fine_w() == FactorySim.GRID_COLS * FactorySim.SUBDIV
		and s1.fine_h() == FactorySim.GRID_ROWS * FactorySim.SUBDIV, "fine grid is SUBDIV× the coarse grid")
	_check(_fine_checksum(s1) == _fine_checksum(s2), "same seed → identical fine array (deterministic)")
	# The fine grid has REAL detail: some fine cells differ from a pure 4× upscale of the coarse grid
	# (the boundary molding erodes/accretes edges) — proving it's fine DATA, not just a stretched coarse mask.
	var molded: int = 0
	var solid_fine: int = 0
	for fy: int in s1.fine_h():
		for fx: int in s1.fine_w():
			var here: bool = s1.fine_is_solid(fx, fy)
			if here:
				solid_fine += 1
			if here != s1.is_solid(Vector2i(fx / FactorySim.SUBDIV, fy / FactorySim.SUBDIV)):
				molded += 1
	_check(solid_fine > 0, "the fine grid has solid rock in it (%d cells)" % solid_fine)
	_check(molded > 200, "fine molding bends the coarse boundary (%d fine cells differ from coarse)" % molded)

	# (b) COARSE UNCHANGED — the coarse solid/material for a fixed seed must be IDENTICAL to what it was
	# before the fine layer existed. We prove the fine layer is purely additive two ways: the coarse
	# checksum matches a second independent load, and known interior cells read exactly as the coarse
	# grid intends (a solid earth cell stays solid earth; a carved cave stays open).
	_check(_coarse_checksum(s1) == _coarse_checksum(s2), "coarse solid grid identical across loads (fine is additive)")
	# The world is generated at exactly GRID_COLS×GRID_ROWS, so every block is in bounds → solid == blocks.
	_check(s1.solid == world.blocks, "coarse solid == the ingested WorldData blocks (unchanged by fine)")
	var a_solid: Vector2i = _first_deep_solid(s1)
	_check(a_solid.x >= 0 and s1.is_solid(a_solid), "a known coarse-solid cell is still solid")
	_check(s1.material_at(a_solid) == world.blocks.get(a_solid, &""), "material_at unchanged by the fine layer")

	# (c) SYNC — mining a coarse cell re-molds its 4×4 fine block (+ the boundary band), and the O(local)
	# incremental sync must produce EXACTLY what a full rebuild would (the load-time path); if these ever
	# diverge, the fine grid silently rots after digging. We mine a solid cell that has OPEN AIR right below
	# it (a cavity/cave-edge cell) so the opening actually admits — its block drains toward air — then assert
	# the block cleared AND that the whole grid equals a full rebuild of the identical coarse state.
	var dug: Vector2i = _first_solid_over_air(s1)
	_check(dug.x >= 0, "found a solid cell with open air below to mine")
	var pre_solid: int = _fine_block_solid(s1, dug)
	s1.mine(dug)
	var post_solid: int = _fine_block_solid(s1, dug)
	_check(post_solid < pre_solid, "mining re-molds the 4×4 fine block toward air (was %d, now %d)"
		% [pre_solid, post_solid])
	_check(not s1.is_solid(dug), "…and the coarse cell is open (coarse still authoritative)")
	# The incremental dig-sync == a full rebuild from the same coarse grid (byte-for-byte, ANY cell).
	var rebuilt: FactorySim = FactorySim.new()
	rebuilt.load_world(gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, 1337))
	rebuilt.mine(dug)
	rebuilt.rebuild_fine_terrain()
	_check(_fine_bytes(s1) == _fine_bytes(rebuilt), "incremental dig-sync == a full rebuild (no drift)")

	# (d) LOAD REBUILDS IDENTICAL — a save/restore round-trip through disk must produce the SAME fine
	# terrain (it is derived, rebuilt by restore, never stored — so it can never desync or bloat the save).
	var s3: FactorySim = FactorySim.new()
	s3.load_world(gen.generate(FactorySim.GRID_COLS, FactorySim.GRID_ROWS, 1337))
	s3.mine(_first_solid_over_air(s3))             # scar it (a real dig) before saving
	var before: PackedByteArray = _fine_bytes(s3)
	var data: Dictionary = SaveGame.capture(s3)
	var path: String = "user://test_fine_terrain.save"
	SaveGame.write(path, data)
	var s4: FactorySim = FactorySim.new()
	_check(SaveGame.restore(s4, SaveGame.read(path)), "the scarred world restores")
	_check(_fine_bytes(s4) == before, "load rebuilds byte-identical fine terrain (derived, unsaved)")
	_check(s4.solid == s3.solid, "coarse terrain round-trips exactly")


## Count of solid fine cells in a coarse cell's SUBDIV×SUBDIV block.
func _fine_block_solid(sim: FactorySim, coarse: Vector2i) -> int:
	var n: int = 0
	for dy: int in FactorySim.SUBDIV:
		for dx: int in FactorySim.SUBDIV:
			if sim.fine_is_solid(coarse.x * FactorySim.SUBDIV + dx, coarse.y * FactorySim.SUBDIV + dy):
				n += 1
	return n


## A checksum of the fine solid grid — cheap byte fold, enough to catch any divergence.
func _fine_checksum(sim: FactorySim) -> int:
	var h: int = 1469598103
	for fy: int in sim.fine_h():
		for fx: int in sim.fine_w():
			h = (h * 33 + (1 if sim.fine_is_solid(fx, fy) else 0)) & 0x7fffffff
	return h


## The whole fine solid grid as bytes (for exact equality across a save/load round-trip).
func _fine_bytes(sim: FactorySim) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(sim.fine_w() * sim.fine_h())
	for fy: int in sim.fine_h():
		for fx: int in sim.fine_w():
			out[fy * sim.fine_w() + fx] = 1 if sim.fine_is_solid(fx, fy) else 0
	return out


## A checksum of the COARSE solid grid (material ids folded in) — proves the coarse authority is unchanged.
func _coarse_checksum(sim: FactorySim) -> int:
	var keys: Array = sim.solid.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a.y * FactorySim.GRID_COLS + a.x) < (b.y * FactorySim.GRID_COLS + b.x))
	var h: int = 2166136261
	for k: Vector2i in keys:
		h = (h * 33 + k.x * 31 + k.y * 17 + int(str(sim.solid[k]).hash())) & 0x7fffffff
	return h


## First solid cell scanning down a central column — a known-solid interior probe.
func _first_deep_solid(sim: FactorySim) -> Vector2i:
	var col: int = FactorySim.GRID_COLS / 2
	for row: int in range(0, FactorySim.GRID_ROWS):
		if sim.is_solid(Vector2i(col, row)):
			return Vector2i(col, row)
	return Vector2i(-1, -1)


## First mineable solid cell that sits directly OVER open air (a cavity/cave-edge cell) — mining it
## genuinely opens the fine block toward air (its bilinear solidness drops), the clean sync case.
func _first_solid_over_air(sim: FactorySim) -> Vector2i:
	for row: int in range(0, FactorySim.GRID_ROWS - 1):
		for col: int in range(0, FactorySim.GRID_COLS):
			var c := Vector2i(col, row)
			if not sim.is_solid(c) or sim.is_solid(c + Vector2i(0, 1)):
				continue
			if str(sim.solid[c]) == "sealrock":
				continue                                          # unmineable — skip
			return c
	return Vector2i(-1, -1)
