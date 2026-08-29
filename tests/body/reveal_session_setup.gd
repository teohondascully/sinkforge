class_name RevealSessionSetup
extends RefCounted

## Shared by `tests/body/reveal_scene.gd` (the live/agent-mode debug scene) and
## `tests/body/reveal_replay_driver.gd` (the offline replay driver, D0129/claims/C004) -- both need to
## reconstruct the IDENTICAL grid and spawn body from the same `(site_id, seed_value)` pair. This is not
## a nice-to-have dedup: a replay reconstructing even a slightly different spawn column or entry-shaft
## carve than the session that produced the recording would silently diverge from what was actually
## played, defeating the whole point of a replay. Extracted here so there is exactly one place that
## defines "what a reveal session's own starting state is."

const CELL: int = Heightfield.TERRAIN_CELL_PX
const SHALLOW_ROW_LIMIT: int = 30  ## how far down the scan looks for a "near-surface" glimmer pocket
const APPROACH_OFFSET_COLS: int = 6  ## spawn this many columns left of the found pocket


## First shallow (row < SHALLOW_ROW_LIMIT) glimmer cell, scanning columns left to right -- deterministic
## given a deterministic grid, so the same (site, seed) always finds the same spawn column and the same
## target glimmer column. Returns `{"spawn_col": int, "target_glimmer_col": int}` -- the latter is -1 if
## this seed/site placed no shallow glimmer at all (parks the spawn in the middle instead of crashing).
static func find_spawn(grid: TileGrid) -> Dictionary:
	for col: int in grid.width:
		if col < APPROACH_OFFSET_COLS:
			continue
		for row: int in SHALLOW_ROW_LIMIT:
			if grid.get_material(Vector2i(col, row)) == &"glimmer":
				return {"spawn_col": col - APPROACH_OFFSET_COLS, "target_glimmer_col": col}
	return {"spawn_col": grid.width / 2, "target_glimmer_col": -1}


## `ShaftGenerator` output is solid rock/clay from row 0 down -- pure geology, no pre-existing opening.
## Carves a small, explicit entry pocket the width of the body, standing height only, matching
## `tests/body/hostile_chamber.gd`'s own SPAWN_START shape.
static func carve_entry_shaft(grid: TileGrid, col: int) -> void:
	var rows: int = Body.HEIGHT_PX / CELL + 2
	for dc: int in range(0, 4):  # Body.WIDTH_PX/CELL cells wide
		for row: int in rows:
			grid.excavate(Vector2i(col + dc, row))


## The full session start: generates the grid, finds the spawn/target columns, carves the entry shaft, and
## spawns a `Body` exactly the way `reveal_scene.gd::_ready()` does. Returns
## `{"grid": TileGrid, "body": Body, "spawn_col": int, "target_glimmer_col": int}`.
static func build(site_id: StringName, seed_value: int) -> Dictionary:
	var grid: TileGrid = ShaftGenerator.generate(StrataData.get_site(site_id), seed_value)
	var spawn: Dictionary = find_spawn(grid)
	var spawn_col: int = spawn["spawn_col"]
	carve_entry_shaft(grid, spawn_col)
	var spawn_row: int = Body.HEIGHT_PX / CELL / 2  # shallowest row whose top edge isn't already past row 0
	var body: Body = Body.new(
		spawn_col * CELL * Fx.SCALE + Body.WIDTH_PX / 2 * Fx.SCALE, Fx.from_int(spawn_row * CELL))
	return {"grid": grid, "body": body, "spawn_col": spawn_col, "target_glimmer_col": spawn["target_glimmer_col"]}
