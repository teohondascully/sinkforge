extends SceneTree

## D0165 (queue #2 Part G): the REAL subject for `docs/QUALITY.md` gate 8 -- runs an actual
## `ShaftGenerator`-generated `TileGrid` and a real `Body` through `TICKS` ticks of seeded random input
## (jump/mantle/dig are all real input surface, driven by `tests/body/fuzz_driver_common.gd`'s own
## shared driver, same as the standing fuzzer), hashing combined body+grid state every `HASH_INTERVAL`
## ticks. `tests/test_shaft_replay_determinism.gd` runs THIS SCRIPT as two separate `OS.execute`d
## processes (not two in-process calls, unlike `test_replay_determinism.gd`'s own stub) and checks the
## checkpoint hashes are bit-identical, plus once more at seed+1 as a negative control that must diverge
## by checkpoint 0.
##
## `_carve_starting_complex` hand-excavates a small three-room start (a flat main room plus a 1-tile
## step-up ledge and a 2-tile mantle ledge, exactly `tests/body/hostile_chamber.gd`'s own step/mantle
## shape, just compressed into one small local cluster) -- ShaftGenerator's own base fill leaves EVERY
## cell solid outside noise-carved caves (no reachable open air at all above `cave.min_depth_cells`, and
## no natural HEIGHT variation anywhere except rare, scattered caves), so leaving jump/mantle/dig
## exercise to chance would risk a check that never actually fires the thing it claims to test -- the
## same "instrument cannot register its subject" class this project's own ledger keeps finding. This is
## world-data authoring (`grid.excavate`/`set_material`), the same convention `hostile_chamber.gd`
## already uses, never `sim/`'s own resolve logic. Which real cave/vein/ruin geometry exists everywhere
## ELSE in the grid is untouched, real `ShaftGenerator` output for this seed.

const TICKS: int = 20000
const HASH_INTERVAL: int = 100
const CELL: int = Heightfield.TERRAIN_CELL_PX
const MAIN_FLOOR_ROW: int = 200
const ROOM_HEIGHT: int = 16  ## rows of open air above each floor -- comfortably more than Body's own
                             ## 10-row height, enough for a real (if capped) jump arc
## MANTLE_LEDGE and STEP_LEDGE both sit DIRECTLY adjacent to MAIN_ROOM (not chained after each other) --
## a body walking from MAIN_ROOM straight into MANTLE_LEDGE's own wall sees the full 2-tile riser in one
## step; chaining them (MAIN -> STEP -> MANTLE in sequence) would only ever expose two separate 1-tile
## steps, since the second riser's own LOCAL lift from STEP_LEDGE's floor is 1 tile too -- confirmed by
## running the first version of this layout that way: `mantles=0` across the full 20,000-tick run.
## Centred within `StrataData.SHALLOW_CLAY`'s own 48-column width, not pinned near either edge -- an
## earlier placement 4 columns from the left wall let the body dig/walk to the world boundary almost
## immediately, spending much of the run straddling `Invariants`' own bounds check rather than a
## representative mix of jump/mantle/step/dig.
const MANTLE_LEDGE_COLS: Vector2i = Vector2i(14, 20)  ## Body.MANTLE_PX (2 tiles) higher than MAIN
const MAIN_ROOM_COLS: Vector2i = Vector2i(20, 32)     ## [from, to) -- spawn here
const STEP_LEDGE_COLS: Vector2i = Vector2i(32, 38)    ## Body.STEP_UP_PX (1 tile) higher than MAIN


func _carve_section(grid: TileGrid, cols: Vector2i, floor_row: int) -> void:
	for col: int in range(cols.x, cols.y):
		for row: int in range(floor_row - ROOM_HEIGHT, floor_row):
			grid.excavate(Vector2i(col, row))


func _carve_starting_complex(grid: TileGrid) -> void:
	_carve_section(grid, MAIN_ROOM_COLS, MAIN_FLOOR_ROW)
	_carve_section(grid, STEP_LEDGE_COLS, MAIN_FLOOR_ROW - Body.STEP_UP_PX / CELL)
	_carve_section(grid, MANTLE_LEDGE_COLS, MAIN_FLOOR_ROW - Body.MANTLE_PX / CELL)


func _spawn_body() -> Body:
	var col: int = (MAIN_ROOM_COLS.x + MAIN_ROOM_COLS.y) / 2
	return Body.new(
		col * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2,
		Fx.from_int(MAIN_FLOOR_ROW * CELL) - Body.HEIGHT_PX / 2 * Fx.SCALE)


func _initialize() -> void:
	var run_seed: int = 20260826
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			run_seed = int(arg.trim_prefix("--seed="))

	var grid: TileGrid = ShaftGenerator.generate(StrataData.SHALLOW_CLAY, run_seed)
	_carve_starting_complex(grid)
	var body: Body = _spawn_body()
	var input_rng: SplitRng = SplitRng.new(run_seed).split("shaft_replay_input")

	var jumps: int = 0
	var mantles: int = 0
	var stepups: int = 0
	var digs: int = 0
	var hashes: PackedStringArray = []
	for tick: int in range(TICKS):
		body.tick(FuzzDriverCommon.random_input(input_rng, false), grid)
		if body.vel_y == Body.JUMP_VELOCITY:
			jumps += 1
		if body.mantled_this_tick:
			mantles += 1
		if body.stepped_up_this_tick:
			stepups += 1
		if body.dig_event_this_tick:
			digs += 1
		if (tick + 1) % HASH_INTERVAL == 0:
			var combined: String = body.state_signature() + "||" + grid.state_signature()
			hashes.append(str(combined.hash()))

	print("SHAFT_REPLAY_HASHES seed=%d %s" % [run_seed, ",".join(hashes)])
	print("SHAFT_REPLAY_SUMMARY seed=%d ticks=%d checkpoints=%d jumps=%d mantles=%d stepups=%d digs=%d" %
		[run_seed, TICKS, hashes.size(), jumps, mantles, stepups, digs])
	quit(0)
