class_name ContentPasses
extends RefCounted
## The orchestration of legacy's content passes over a generated world, each gated on a site record and
## each on its own split of the terrain stream, so adding one moves no other pass's draws (`SplitRng.split`
## is keyed off the root seed, not the draw position). `ShaftGenerator.generate` runs the GRID passes here
## in legacy's order after the veins -- the vertical structure (8c), then the studding (8d) -- and
## `ShaftGenerator.enrich` runs the PLANE passes on the `World`: aquifers on the water plane, lodes on the
## deposit plane (8e). Moved out of the generator in A' step 8e (D0385) so its file stays under the cap
## and reads as the sequence it is; the passes themselves live in their own files.


## Rifts, their wall ore, then the mouths that make them reachable -- legacy's order, on the terrain
## stream's own `vertical` split so adding them moves no vein or ruin draw (`SplitRng.split` is keyed off
## the root seed, not the draw position).
static func vertical(grid: TileGrid, rng: SplitRng, site: Dictionary, surface: PackedInt32Array,
		deep_row: int) -> void:
	var v_rng: SplitRng = rng.split("vertical")
	var cfg: Dictionary = site["vertical"]
	var spawn: int = ShaftGenerator.spawn_col(site, grid.width)
	var cave_band: int = int(site["cave"]["min_depth_cells"])
	var rifts: Array[Vector2i] = VerticalPasses.carve_rifts(grid, v_rng, cfg["rift"], surface, cave_band,
		spawn, ShaftGenerator.TERRAIN_CELLS_PER_METER)
	VerticalPasses.ore_rift_walls(grid, v_rng, cfg["rift"], rifts, deep_row)
	VerticalPasses.open_sinkholes(grid, v_rng, cfg["sinkhole"], rifts, surface, spawn, ShaftGenerator.TERRAIN_CELLS_PER_METER)


## Ledges, spires, rubble, then the drought pass -- legacy's order, on the `studding` split. Each studding
## pass samples a fresh snapshot of the open set, so the teeth see the ledges and the rubble sees both.
static func studding(grid: TileGrid, rng: SplitRng, site: Dictionary, surface: PackedInt32Array,
		deep_row: int) -> void:
	var s_rng: SplitRng = rng.split("studding")
	var cfg: Dictionary = site["studding"]
	var band: int = int(site["cave"]["min_depth_cells"])
	var cpm: int = ShaftGenerator.TERRAIN_CELLS_PER_METER
	StuddingPasses.stud_ledges(grid, s_rng, cfg["ledge"], StuddingPasses.open_terrain_cells(grid, surface, band), cpm)
	StuddingPasses.stud_spires(grid, s_rng, cfg["spire"], StuddingPasses.open_terrain_cells(grid, surface, band), cpm)
	StuddingPasses.scatter_rubble(grid, s_rng, cfg["rubble"], StuddingPasses.open_terrain_cells(grid, surface, band), cpm)
	StuddingPasses.seed_droughts(grid, s_rng, cfg["drought"], surface, band, deep_row, cpm)


## Aquifers, then lodes -- legacy's order: the lodes run dead last because every lode guard tests the
## final world and the aquifers carve rock away and flood it.
static func planes(world: World, rng: SplitRng, site: Dictionary, surface: PackedInt32Array,
		deep_row: int, hfield: PackedInt32Array) -> void:
	var cpm: int = ShaftGenerator.TERRAIN_CELLS_PER_METER
	var band: int = int(site["cave"]["min_depth_cells"])
	if site.has("aquifer"):
		var min_row: int = ShaftGenerator.SKY_ROWS + int(site["aquifer"]["min_depth_m"]) * cpm
		PlanePasses.seed_aquifers(world, rng.split("aquifers"), site["aquifer"], surface, band, min_row, deep_row, cpm)
	if site.has("lode"):
		PlanePasses.seed_lodes(world, rng.split("lodes"), site["lode"], surface, ShaftGenerator.SKY_ROWS, deep_row, cpm, hfield)


## Surface trees on the `trees` split, kept off the start's pad by the record's own keepout about the spawn
## column (legacy started planting past its flat ground and its ruin).
static func trees(grid: TileGrid, rng: SplitRng, site: Dictionary, surface: PackedInt32Array) -> void:
	var cpm: int = ShaftGenerator.TERRAIN_CELLS_PER_METER
	var spawn: int = ShaftGenerator.spawn_col(site, grid.width)
	var keep: int = int(site["tree"]["keepout_m"]) * cpm
	TreePass.plant(grid, rng.split("trees"), site["tree"], surface, Vector2i(spawn - keep, spawn + keep), cpm)
