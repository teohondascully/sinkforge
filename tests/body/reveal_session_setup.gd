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

## D0192. The spawn may never sit flush against the world's own left edge. DERIVED, not picked: the body
## is stopped by terrain, so what it needs is one SOLID cell between its left edge and x=0 -- `carve_entry_shaft`
## opens `[spawn_col, spawn_col+4)`, so `spawn_col = 1` leaves column 0 solid full-height and
## `HorizontalResolve` halts a leftward walk at x=4px instead of the world-edge clamp halting it at x=0.
## One cell is the whole kinematic requirement; more margin would only change how much digging removes it.
##
## What this was: `spawn_col = col - APPROACH_OFFSET_COLS` with a `col < APPROACH_OFFSET_COLS: continue`
## guard, which prevents a NEGATIVE spawn column but permits exactly 0 -- and 0 puts the body's left edge
## exactly ON x=0, one acceleration step (0.3125px) from a bounds violation, with the entry shaft having
## already excavated the column 0 rock that would otherwise have stopped it. The guard's `continue` also
## piles every pocket in columns 0..5 onto column 6, so this is the MODE of the distribution rather than a
## tail: measured over 400 seeds, `reveal_test_dense` spawns flush **213/400 (53.2%)** and
## `reveal_test_sparse` **56/400 (14.0%)**. The director's own seed 20260826 is one of them.
const MIN_SPAWN_COL: int = 1


## First shallow (row < SHALLOW_ROW_LIMIT) glimmer cell, scanning columns left to right -- deterministic
## given a deterministic grid, so the same (site, seed) always finds the same spawn column and the same
## target glimmer column. Returns `{"spawn_col": int, "target_glimmer_col": int}` -- the latter is -1 if
## this seed/site placed no shallow glimmer at all (parks the spawn in the middle instead of crashing).
##
## The `maxi` never pushes the spawn far enough right to swallow its own target: the pocket must stay
## outside the carved entry shaft `[spawn_col, spawn_col+4)`, and with the `col >= APPROACH_OFFSET_COLS`
## guard above, the tightest case is `col == 6 -> spawn_col == 1`, whose shaft ends at column 5.
static func find_spawn(grid: TileGrid) -> Dictionary:
	for col: int in grid.width:
		if col < APPROACH_OFFSET_COLS:
			continue
		for row: int in SHALLOW_ROW_LIMIT:
			if grid.get_material(Vector2i(col, row)) == &"glimmer":
				return {"spawn_col": maxi(MIN_SPAWN_COL, col - APPROACH_OFFSET_COLS), "target_glimmer_col": col}
	return {"spawn_col": grid.width / 2, "target_glimmer_col": -1}


## D0199. The vertical half of D0192, and the instance that repair did not reach. D0192 derived "one SOLID
## cell between the body's edge and 0" for the LEFT edge and stopped there; the entry shaft opened row 0
## across the body's full width, so the body spawned with its head exactly ON y=0 and the FIRST JUMP left
## the world through the ceiling. Measured in the director's own Slice 1 `--play` session, not predicted:
## `tools/scratch` replay of `reveal_play_2026-08-30T05-58-03.log` reports 1 bounds violation, box y from
## `-223914` (-3.4px), `report_bounds ← _enforce_grid_bounds ← tick` -- the same call path as D0192 on the
## other axis. Jump is 365px/s against 900px/s^2 gravity, so the apex is 74px above the ceiling: nothing
## but the clamp was ever going to stop it.
##
## The remedy is D0192's own rule applied here rather than a second mechanism: leave row 0 SOLID so the
## head is stopped by ROCK (`VerticalResolve`'s ceiling case) instead of by the world-edge clamp. It also
## reads better than the hole it replaces -- `docs/GDD.md`'s "solid earth you carve INTO" has no reason to
## open onto the sky at row 0.
const CEILING_ROWS: int = 1


## `ShaftGenerator` output is solid rock/clay from row 0 down -- pure geology, no pre-existing opening.
## Carves a small, explicit entry pocket the width of the body, standing height only, matching
## `tests/body/hostile_chamber.gd`'s own SPAWN_START shape -- but starting at `CEILING_ROWS`, never row 0.
static func carve_entry_shaft(grid: TileGrid, col: int) -> void:
	var rows: int = Body.HEIGHT_PX / CELL + 2
	for dc: int in range(0, 4):  # Body.WIDTH_PX/CELL cells wide
		for row: int in range(CEILING_ROWS, CEILING_ROWS + rows):
			grid.excavate(Vector2i(col + dc, row))


## The spawn row that puts the body's own top edge flush under `carve_entry_shaft`'s rock ceiling and no
## higher. DERIVED from the two of them together rather than written as a literal: the body is centred on
## its position, so its top sits `HEIGHT_PX/2` above `spawn_row`, and the shallowest legal centre is the
## one whose top lands on the first CARVED row. Public because `tests/test_reveal_spawn_bounds.gd` builds
## the pre-fix setup as a live control and has to be able to state both rows against the same derivation.
static func spawn_row_for_ceiling() -> int:
	return Body.HEIGHT_PX / CELL / 2 + CEILING_ROWS


## The full session start: generates the grid, finds the spawn/target columns, carves the entry shaft, and
## spawns a `Body` exactly the way `reveal_scene.gd::_ready()` does. Returns
## `{"grid": TileGrid, "body": Body, "spawn_col": int, "target_glimmer_col": int}`.
static func build(site_id: StringName, seed_value: int) -> Dictionary:
	return build_on(ShaftGenerator.generate(StrataData.get_site(site_id), seed_value))


## The whole of `build` EXCEPT generating the world, so a caller holding an already-generated grid can
## reuse it (D0267). Split rather than duplicated: `build` above is now one line, so there is exactly one
## definition of what a reveal session's starting state is, which is this file's stated reason to exist.
## The grid is MUTATED (`carve_entry_shaft`) -- pass a `clone()` if the original must survive.
static func build_on(grid: TileGrid) -> Dictionary:
	var spawn: Dictionary = find_spawn(grid)
	var spawn_col: int = spawn["spawn_col"]
	carve_entry_shaft(grid, spawn_col)
	var spawn_row: int = spawn_row_for_ceiling()
	var body: Body = Body.new(
		spawn_col * CELL * Fx.SCALE + Body.WIDTH_PX / 2 * Fx.SCALE, Fx.from_int(spawn_row * CELL))
	return {"grid": grid, "body": body, "spawn_col": spawn_col, "target_glimmer_col": spawn["target_glimmer_col"]}
