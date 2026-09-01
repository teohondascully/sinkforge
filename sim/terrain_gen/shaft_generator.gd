class_name ShaftGenerator
extends RefCounted

## Seeded strata generation for one shaft: base rock banded by depth into `docs/GDD.md` §11's three
## layers, caves, and ore/coal/iron veins. `sim/terrain_gen/MODULE.md`'s Must-not: does not read `run`
## state, only a site config (`StrataData`) and a seed -- callable in isolation, by tests or tooling,
## without a run.
##
## PORT SCOPE (`docs/DECISIONS_LEDGER.md` D0017): strata banding, cave carving, and ore/coal/iron vein
## scattering only. Big caverns, tunnels, rifts, sinkhole mouths, ledges, spires, rubble, lodes,
## aquifers, aquifer treasure, surface trees, the bazaar ruin, and the L1/L2 "seal" gate are legacy
## passes this port does not carry forward -- most are artifacts of the pre-pivot progression-gated
## structure this codebase no longer has. Iron, which legacy gated below the seal, is gated by the
## `stonereach_end` depth threshold alone.
##
## Per-cell richness/deposit amounts are not tracked -- `data/strata/*.yaml` nests amount_base et al.
## under each material's `pending_sim_economy` key specifically so "unconsumed" is structural, not just
## a comment. That's `sim/economy`/`sim/items` territory once they exist. A vein cell right now is just
## its material id, same as any other tile.
##
## Ruin placement (D0018): one empty carved chamber per shaft, no earlier than `ruin.min_depth_m`.
## "Marked but empty" -- what a ruin contains is sim/items territory, not yet built.

const TERRAIN_CELLS_PER_METER: int = 4  # docs/ARCHITECTURE.md §9: 16px/m world scale, 4px terrain grid

## Legacy's DENSITY_ROWS: the world height ore/coal/iron's *_per_col rates were calibrated to. Ported as
## a literal so a much taller shaft still gets a comparable density per unit volume, not a comparable
## density per column (`legacy/src/core/layered_world_gen.gd` _density_count's whole reason to exist).
const DENSITY_ROWS: int = 80

## `legacy/src/core/layered_world_gen.gd:31` `CAVE_SHELF_BIAS`. See `_carve_caves` for what it does and
## why it is the one constant of the three P021 passes that is dimensionless.
const SHELF_BIAS: float = 0.10

## THE AIR ABOVE THE SURFACE (P017, director-ruled). Row 0 used to be the surface datum, the top of the
## `TileGrid` and `SkyPainter.HORIZON_Y` all at once, so there was **nowhere to jump.** The director
## reported it from the chair: *"it wont let me jump up beyond the surface. like my head bumps at the
## surfaceline and i cant jump higher."* Correct, and measured: the jump apex is 74px, about 18 rows, and
## the world ended one row above the body's head.
##
## Legacy had `SURFACE_ROW = 20` — twenty rows of sky over a one-metre cell, so **twenty metres**. That
## converts to 80 rows here and is what is used: it is legacy's number at this build's scale, it is four
## times the jump apex so the ceiling is never the thing you notice, and it gives `SkyPainter`'s ridges,
## stars and moon somewhere to be that the player can rise INTO rather than only look at.
##
## The band costs nothing to store. `TileGrid` holds blocks in a dictionary, so a row with no material is
## not a row of empty entries — it is no entries. And it costs nothing to draw: `WallPainter.backs()`
## returns `&""` for a cell with no wall behind it, deliberately, which is exactly what lets the backdrop
## show through here (D0286).
##
## **EVERY DEPTH-KEYED ROW IN THIS FILE MOVES WITH IT.** The surface datum is row `SKY_ROWS`, not row 0,
## so `depth_m` subtracts it (`view/visuals/material_look.gd`), the layer thresholds add it, and no pass
## may seed or grow above it. That last one is why the passes take a `surface` argument rather than
## reading `0`: a scatter picking `cy` in `[1, height)` would have put ore in the sky.
const SKY_ROWS: int = 20 * TERRAIN_CELLS_PER_METER

const _HOST_ROCK: Array[StringName] = [&"clay", &"hardrock", &"deepstone"]


static func generate(site: Dictionary, seed: int) -> TileGrid:
	var width: int = int(site["width_cells"])
	var height: int = SKY_ROWS + int(site["max_depth_m"]) * TERRAIN_CELLS_PER_METER
	var grid: TileGrid = TileGrid.new(width, height, seed)
	var rng: SplitRng = SplitRng.new(seed).split("terrain_gen")

	var thresholds: Dictionary = site["layer_thresholds_m"]
	# Thresholds are metres BELOW THE SURFACE, and the surface is row `SKY_ROWS`.
	var topsoil_end: int = SKY_ROWS + int(thresholds["topsoil_shale_end"]) * TERRAIN_CELLS_PER_METER
	var stonereach_end: int = SKY_ROWS + int(thresholds["stonereach_end"]) * TERRAIN_CELLS_PER_METER

	_fill_base(grid, SKY_ROWS, topsoil_end, stonereach_end)
	# Cave noise is a pure function of the world seed, not the vein RNG stream -- order-independent of
	# how many vein draws happen before or after it, matching legacy's own separation of the two.
	_carve_caves(grid, site["cave"], site["strata_shelf"], seed, SKY_ROWS)
	# P021's two unported passes, in legacy's own order: halls first, then the worms that thread them and
	# the noise pockets into one system. Both draw from a SPLIT of the terrain stream rather than from it
	# directly, so adding them cannot shift a single vein or ruin draw -- the whole point of `SplitRng`,
	# and what keeps this from re-rolling every ore body in every world (`CavePasses`, D0291).
	var carve_rng: SplitRng = rng.split("carve_passes")
	var cave_floor: int = SKY_ROWS + int(site["cave"]["min_depth_cells"])
	CavePasses.carve_big_caverns(grid, carve_rng, stonereach_end, cave_floor, TERRAIN_CELLS_PER_METER)
	CavePasses.carve_tunnels(grid, carve_rng, cave_floor, TERRAIN_CELLS_PER_METER)
	# Caves carved first: vein growth only ever replaces solid host rock, so an already-open cave cell
	# is naturally skipped, same as legacy.
	_scatter_vein_material(grid, rng, site["ore"], &"ore_copper", SKY_ROWS)
	_scatter_vein_material(grid, rng, site["coal"], &"coal", SKY_ROWS)
	_scatter_iron(grid, rng, site["iron"], stonereach_end, SKY_ROWS)
	_place_ruins(grid, rng, site["ruin"], SKY_ROWS)
	# Optional (docs/GDD.md §12, claims/C004) -- absent from the real `shallow_clay` site on purpose, so
	# this stays a test-only addition, not a commitment the real economy has to honor yet.
	if site.has("reveal"):
		_scatter_reveal_material(grid, rng, site["reveal"], topsoil_end, SKY_ROWS)
	return grid


## Rows above `surface` are left with NO material and NO wall — that is the sky, and a cell with no wall
## behind it is what `WallPainter` leaves transparent so the backdrop shows through (P017, D0292).
static func _fill_base(grid: TileGrid, surface: int, topsoil_end: int, stonereach_end: int) -> void:
	for col: int in grid.width:
		for row: int in range(surface, grid.height):
			var material: StringName
			if row < topsoil_end:
				material = &"clay"
			elif row < stonereach_end:
				material = &"hardrock"
			else:
				material = &"deepstone"
			var cell: Vector2i = Vector2i(col, row)
			grid.set_material(cell, material)
			# Wall mirrors the block's own material. Legacy gave walls a distinct "_wall"-suffixed
			# material purely for render variety (a view-layer concern); nothing here needs that yet.
			grid.set_wall(cell, material)


## One in `strata_shelf.shelf_every` bands is cave-resistant, which of them fixed by a hash of the
## band-group index -- ported verbatim from legacy's `_band_hash`/`_is_shelf_band` (see that file's
## extensive comment for why a bare arithmetic pick instead of a hash put every shelf in one contiguous
## slab). Applies through the whole depth, unlike legacy, which stopped banding at STRATA_MAX_ROW because
## deepslate and the seal "owned the deep look" there -- neither concept exists in this port (D0017).
static func _band_hash(group: int) -> int:
	var h: int = (((group & 0xFFFF) + 1) * 2654435761) & 0xFFFFFFFF
	h = (h ^ (h >> 15)) & 0xFFFFFFFF
	h = (h * 0x2545F491) & 0xFFFFFFFF
	return h >> 16


static func _is_shelf_band(row: int, band_height: int, shelf_every: int) -> bool:
	var band: int = row / band_height
	return band % shelf_every == _band_hash(band / shelf_every) % shelf_every


static func _carve_caves(grid: TileGrid, cave_cfg: Dictionary, shelf_cfg: Dictionary, seed: int,
		surface: int) -> void:
	var frequency: float = cave_cfg["frequency"]
	var threshold_top: float = cave_cfg["threshold_top"]
	var threshold_deep: float = cave_cfg["threshold_deep"]
	var min_depth: int = surface + int(cave_cfg["min_depth_cells"])   ## cells below the SURFACE, not row 0
	var x_stretch: float = cave_cfg["x_stretch"]
	var band_height: int = int(shelf_cfg["band_height_cells"])
	var shelf_every: int = int(shelf_cfg["shelf_every"])
	var shelf_resist: float = shelf_cfg["shelf_resist"]
	var carve_span: int = maxi(1, grid.height - min_depth)

	for col: int in grid.width:
		for row: int in range(min_depth, grid.height):
			var cell: Vector2i = Vector2i(col, row)
			if not grid.is_solid(cell):
				continue
			var depth_frac: float = float(row - min_depth) / float(carve_span)
			var threshold: float = lerpf(threshold_top, threshold_deep, depth_frac)
			if _is_shelf_band(row, band_height, shelf_every):
				threshold += shelf_resist
			# THE OVERHANG BIAS (P021, `layered_world_gen.gd:360-364`), the third of the three passes
			# D0017 left behind and the only one that lands here rather than in `CavePasses`. Asymmetric
			# on purpose, and legacy says why in one line: "easier just under a shelf (undercut), harder
			# just above one (roof pools)". It is what turns a hard band from a stripe of resistant rock
			# into a LEDGE with space under it -- the shelf survives, and the cave hangs beneath it.
			#
			# Dimensionless, so it needs no conversion: it moves a noise threshold, not a distance.
			elif _is_shelf_band(row - 1, band_height, shelf_every):
				threshold -= SHELF_BIAS
			elif _is_shelf_band(row + 1, band_height, shelf_every):
				threshold += SHELF_BIAS
			var noise_x: float = float(col) / x_stretch * frequency
			var noise_y: float = float(row) * frequency
			# threshold_top/threshold_deep are ported directly from legacy's FastNoiseLite-tuned
			# constants (data/strata/*.yaml's own header) -- calibrated here, not left raw, or
			# ValueNoise's wider real distribution (D0045) carves at a different rate than the ported
			# thresholds were tuned to produce, silently, since both a raw and a mismatched-calibration
			# sample look equally plausible without measuring the actual carve density either way.
			var noise: float = ValueNoise.sample_fbm(noise_x, noise_y, seed) * ValueNoise.FASTNOISELITE_SD_CALIBRATION
			if noise > threshold:
				grid.excavate(cell)  # block erased, wall kept -- a carved room, not a void


static func _density_count(width: int, height: int, per_col: float) -> int:
	return int(round(float(width) * per_col * float(height) / float(DENSITY_ROWS)))


## Acceptance floor at the surface, rising to 1.0 (unfloored) at the world bottom.
static func _banded(depth_frac: float, floor_frac: float) -> float:
	return floor_frac + (1.0 - floor_frac) * clampf(depth_frac, 0.0, 1.0)


## Shared shape for ore and coal: depth-weighted acceptance roll, then a blob grown from an accepted
## seed, sized bigger with depth. Ported from legacy's `_scatter_veins`/`_scatter_coal`, which differ
## only in their constants -- one function, two configs, per `docs/DECISIONS_LEDGER.md`'s port-the-
## algorithm-not-the-structure instruction.
static func _scatter_vein_material(grid: TileGrid, rng: SplitRng, cfg: Dictionary, material: StringName,
		surface: int) -> void:
	# Against the ROCK, not the grid: the sky is not volume ore can be in, and counting it would raise
	# every density by the sky band's share of the world.
	var attempts: int = _density_count(grid.width, grid.height - surface, cfg["attempts_per_col"])
	for _i: int in attempts:
		var cx: int = rng.next_range(0, grid.width - 1)
		var cy: int = rng.next_range(surface + 1, grid.height - 1)
		var depth_frac: float = float(cy - surface) / float(maxi(1, grid.height - 1 - surface))
		var accept: float = _banded(depth_frac, cfg["shallow_floor"]) * float(cfg["chance_deep"])
		if rng.next_float() > accept:
			continue
		var size: int = int(cfg["size_min"]) + int(round(depth_frac * float(cfg["size_depth_bonus"])))
		_grow_vein(grid, rng, Vector2i(cx, cy), size, material)


## Iron: no acceptance roll and no shallow floor (it doesn't exist above `stonereach_end` at all), size
## scales with depth WITHIN Deep Works rather than across the whole shaft.
static func _scatter_iron(grid: TileGrid, rng: SplitRng, cfg: Dictionary, stonereach_end: int,
		surface: int) -> void:
	if stonereach_end >= grid.height - 1:
		return
	var attempts: int = _density_count(grid.width, grid.height - surface, cfg["attempts_per_col"])
	var span: int = maxi(1, grid.height - 1 - stonereach_end)
	for _i: int in attempts:
		var cx: int = rng.next_range(0, grid.width - 1)
		var cy: int = rng.next_range(stonereach_end, grid.height - 1)
		var depth_frac: float = float(cy - stonereach_end) / float(span)
		var size: int = int(cfg["size_min"]) + int(round(depth_frac * float(cfg["size_depth_bonus"])))
		_grow_vein(grid, rng, Vector2i(cx, cy), size, &"ore_iron", stonereach_end)


## Grow one vein as a compact accretion blob: repeatedly take a random frontier cell, keep it if it's
## still host rock, and queue its neighbours. `min_row` floors the body so an iron vein seeded just below
## `stonereach_end` can't accrete upward into hardrock, mirroring legacy's seal-floor reasoning
## retargeted to this port's actual layer boundary.
## `max_row` is EXCLUSIVE and defaults to unbounded, mirroring `min_row`'s inclusive floor. It exists
## because a seeding range is not a growth bound (D0254): `_scatter_reveal_material` picks
## `cy` in `[0, topsoil_end - 1]`, entirely inside topsoil, and then this function accretes in all four
## directions with nothing stopping it — so a vein seeded on the last topsoil row grows straight through
## the boundary its caller was written to respect. `hardrock` is in `_HOST_ROCK`, so the host-rock check
## waves it past.
##
## Found by changing the noise seed hash, not by reading the code: the old 16-bit seed mask happened to
## produce a field under which no glimmer vein was seeded close enough to the boundary to cross it, and
## `_test_glimmer_never_appears_at_or_below_topsoil_end` had been green on that coincidence. Two cells
## crossed on the first genuinely different field. The bug was always there; only one arrangement of the
## world made it visible, which is what makes a fixed-seed generation test a sample rather than a proof.
static func _grow_vein(grid: TileGrid, rng: SplitRng, seed_cell: Vector2i, size: int, material: StringName,
		min_row: int = 0, max_row: int = 0x7FFFFFFF) -> void:
	var filled: Dictionary = {}
	var frontier: Array[Vector2i] = [seed_cell]
	var placed: int = 0
	while placed < size and not frontier.is_empty():
		var idx: int = rng.next_range(0, frontier.size() - 1)
		var cell: Vector2i = frontier[idx]
		frontier.remove_at(idx)
		if filled.has(cell) or not grid.in_bounds(cell) or cell.y < min_row or cell.y >= max_row:
			continue
		if not _HOST_ROCK.has(grid.get_material(cell)):
			continue  # only replace host rock -- never a carved cave, never another vein's cell
		grid.set_material(cell, material)
		filled[cell] = true
		placed += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			frontier.append(cell + d)


## Reveal-layer placeholder feature (docs/GDD.md §12, claims/C004): confined to topsoil rows only, unlike
## `_scatter_vein_material`'s whole-grid depth-weighted acceptance curve -- mirrors `_scatter_iron`'s
## bounded-range shape instead, since the reveal hypothesis (docs/GDD.md §8) is explicitly lateral
## search, not a depth-gated one, so there is no acceptance-by-depth to model here. `attempts_per_col` is
## scaled against `topsoil_end` (the band's own height), not the whole grid, same reasoning `_scatter_iron`
## already uses for its own `span`. Density is the swept variable across the two reveal-test sites
## (`data/strata/reveal_test_sparse.yaml`/`reveal_test_dense.yaml`) -- deterministic per `(site, seed)`
## same as every other scatter here, but NOT stable across different `attempts_per_col` values: a density
## sweep compares different generations, never the same generation re-sampled (docs/DECISIONS_LEDGER.md
## D0109's density-sweep note).
static func _scatter_reveal_material(grid: TileGrid, rng: SplitRng, cfg: Dictionary, topsoil_end: int,
		surface: int) -> void:
	if topsoil_end <= surface:
		return
	var attempts: int = _density_count(grid.width, topsoil_end - surface, cfg["attempts_per_col"])
	for _i: int in attempts:
		var cx: int = rng.next_range(0, grid.width - 1)
		var cy: int = rng.next_range(surface, topsoil_end - 1)
		# `topsoil_end` bounds the GROWTH, not just the seed -- see `_grow_vein` (D0254).
		_grow_vein(grid, rng, Vector2i(cx, cy), int(cfg["size_min"]), &"glimmer", 0, topsoil_end)


## One guaranteed empty chamber per shaft (D0018): a carved disc, no earlier than `min_depth_m`. Nothing
## is placed inside it -- what a ruin contains is sim/items territory, not yet built.
static func _place_ruins(grid: TileGrid, rng: SplitRng, cfg: Dictionary, surface: int) -> void:
	var min_row: int = surface + int(cfg["min_depth_m"]) * TERRAIN_CELLS_PER_METER
	var radius: int = int(cfg["radius_cells"])
	if min_row + radius >= grid.height or radius >= grid.width:
		return
	for _i: int in int(cfg["count"]):
		var cx: int = rng.next_range(radius, grid.width - 1 - radius)
		var cy: int = rng.next_range(min_row, grid.height - 1 - radius)
		_carve_disc(grid, Vector2i(cx, cy), radius)


static func _carve_disc(grid: TileGrid, center: Vector2i, radius: int) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var cell: Vector2i = center + Vector2i(dx, dy)
			if grid.in_bounds(cell):
				grid.excavate(cell)
