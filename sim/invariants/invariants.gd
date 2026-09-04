class_name Invariants
extends RefCounted

## Continuous checking module (`sim/invariants/MODULE.md`): reads other submodules' state after
## they've acted, flags violations, produces no gameplay state itself. First real check: whether
## `sim/body`'s floor resolution picked between two competing standing surfaces without either of
## them knowing it. First measured at 0.85% of columns / 12% of shafts in real generated terrain
## (D0042) -- since superseded: that terrain shape was substantially an artifact of a `ValueNoise`
## calibration bug (D0045), and the corrected generator measures 0 of 4,800 columns (D0046,
## `docs/adr/0005-heightfield-local-window.md` has the full finding, including why 0/4,800 is a null
## result at this sample's resolution, not proof the case cannot occur). This check turns a silent
## "standing on the wrong floor, no error" bug report into a reproducible, position-and-seed-logged
## one; its purpose now is not measuring a known cost but watching for this case to reappear after a
## future noise, threshold, or site-config change. The window this check is called with must actually
## be wide enough to see the case it exists to catch -- `Body.FLOOR_SCAN_ROWS` (D0044) is sized from a
## real re-measurement of the row-gap distribution between genuinely-reachable stacked floors, not the
## original 6-row window, which could not see it by construction and reported zero regardless of real
## incidence.
##
## `report_floor_selection` itself logs unconditionally, every call, by design -- it stays exactly as
## cheap and stateless as `check_floor_selection`, which this module's own MODULE.md requires ("produces
## no gameplay state itself"). Left unratelimited, a body resting on one ambiguous floor logs the
## identical violation on nearly every call to this check (measured by mutation-testing the caller's own
## gate: 778 push_errors from one ~400-tick settle in `tests/test_cave_geometry.gd`, not merely once per
## tick -- `body.gd::_move_and_resolve_vertical` calls `_resolve_floor` twice on most resting ticks),
## burying the signal it exists to produce. That de-duplication happens
## at the CALLER instead (`sim/body/body.gd::_resolve_floor()`, D0052): it already tracks the body's own
## position every tick, so it is where the memory of "already reported this (column, floor) pair"
## belongs, not here.
##
## `docs/ARCHITECTURE.md` §9: "Panic in debug, log in release." This file logs via `push_error()`
## unconditionally rather than `assert()`-ing, in both build types -- `core/MODULE.md`'s own
## documented gotcha: an unguarded runtime error inside a bare `--headless --script` run does not
## crash the process, it HANGS the whole run with no further output and no exit code (verified
## empirically, the same finding that shaped `Fx.div`'s zero-guard). An `assert()` failure is a
## runtime error by the same mechanism, so it carries the same hang risk in exactly the harness
## context invariant checks need to run cleanly under. `push_error()` already prints loudly (visible
## in both the editor debugger and a release log) without that risk, so "panic in debug" is read
## here as "surface it loudly," not "halt the process" -- a real, deliberate reinterpretation of that
## line, recorded because a literal panic would reintroduce a hazard this codebase already paid to
## discover once.


class FloorSelectionViolation:
	var column: int
	var chosen_floor_row: int
	var competing_floor_row: int
	var seed: int
	var pos_x: int  ## Fx
	var pos_y: int  ## Fx

	func _to_string() -> String:
		return ("Invariants: body resolved to floor row %d in column %d, but a second standing " +
			"surface (row %d) is also visible inside the same local scan window -- ambiguous floor " +
			"selection. seed=%d pos=(%d,%d)") % [chosen_floor_row, column, competing_floor_row, seed, pos_x, pos_y]


## `body_height_cells`/`step_up_cells` etc. are passed in rather than read from `Body`'s own
## constants -- this checking module has no reason to depend on `sim/body` (it would be the callee,
## not the caller, in every real use), so the caller hands over the numbers it already has.
##
## Detects whether `column`'s scan window [scan_from_row, scan_from_row + max_rows) can see more
## than one real standing floor: the one `_resolve_floor` actually chose (`chosen_floor_row`), and a
## second, DISTINCT one whose own boundary also falls inside that window and which has genuine
## clearance (>= body_height_cells of open air) above it, wherever that clearance actually ends --
## the clearance check is not itself bounded by the window, only the second floor's boundary row is,
## matching what makes a shelf actually walkable rather than a random thin ledge glimpsed in passing.
## `solid` (A' step 5c, D0360): the body's own blocking predicate over a terrain cell, so the check reads
## the floor the way the resolver did (a machine's tile is ground, a trunk is not); invalid reads the grid.
static func check_floor_selection(grid: TileGrid, column: int, scan_from_row: int, max_rows: int,
		chosen_floor_row: int, body_height_cells: int, solid: Callable = Callable()) -> FloorSelectionViolation:
	var window_end: int = scan_from_row + max_rows
	var row: int = chosen_floor_row + 1
	while row < window_end:
		if _solid_at(grid, Vector2i(column, row), solid):
			var clearance: int = 0
			var probe: int = row - 1
			while probe >= 0 and not _solid_at(grid, Vector2i(column, probe), solid):
				clearance += 1
				probe -= 1
			if clearance >= body_height_cells:
				var v: FloorSelectionViolation = FloorSelectionViolation.new()
				v.column = column
				v.chosen_floor_row = chosen_floor_row
				v.competing_floor_row = row
				return v
		row += 1
	return null


## Runs `check_floor_selection`, and if it fires, logs it (position/seed included) per this file's
## "log always, never assert" policy above. Returns the violation (or null) so a caller/test can
## also count occurrences without re-deriving them from log output.
static func _solid_at(grid: TileGrid, terrain_cell: Vector2i, solid: Callable) -> bool:
	return bool(solid.call(terrain_cell)) if solid.is_valid() else grid.is_solid(terrain_cell)


static func report_floor_selection(grid: TileGrid, column: int, scan_from_row: int, max_rows: int,
		chosen_floor_row: int, body_height_cells: int, seed: int, pos_x: int, pos_y: int,
		solid: Callable = Callable()) -> FloorSelectionViolation:
	var v: FloorSelectionViolation = check_floor_selection(
		grid, column, scan_from_row, max_rows, chosen_floor_row, body_height_cells, solid)
	if v != null:
		v.seed = seed
		v.pos_x = pos_x
		v.pos_y = pos_y
		push_error(v._to_string())
	return v


class BoundsViolation:
	var left: int  ## Fx, all six fields
	var top: int
	var right: int
	var bottom: int
	var grid_max_x: int
	var grid_max_y: int
	var seed: int
	var pos_x: int  ## Fx
	var pos_y: int  ## Fx

	func _to_string() -> String:
		return ("Invariants: body's own box [%d,%d)x[%d,%d) extends outside the grid's own [0,%d)x" +
			"[0,%d) -- left the world. seed=%d pos=(%d,%d)") % [left, right, top, bottom, grid_max_x,
			grid_max_y, seed, pos_x, pos_y]


## Second real check (D0055): whether the body's own AABB still fits inside the grid's declared
## extent. Bounds are handed over as plain Fx values (`grid_min_x`/`grid_min_y`/`grid_max_x`/
## `grid_max_y`), not a `TileGrid` plus a cell size, for the same reason `check_floor_selection`'s
## callers hand over their own constants: this module has no reason to know `sim/body`'s pixel
## scale or `Heightfield`'s cell size, only the box comparison itself. Found live, not by design
## review: a chained auto-step-up/mantle (`horizontal_resolve.gd::_try_step`, no bound of its own) launched a real
## `--play` session's body to y=-15.85px, well above row 0 -- `docs/DECISIONS_LEDGER.md` has the
## full root-cause trace. This is the diagnostic half of that fix: `body.gd` now also clamps the
## body back inside the grid every tick (the actual fix), and this check exists so a FUTURE
## regression that reopens some other path out of the world is still loud, not a silent clamp.
static func check_bounds(grid_min_x: int, grid_min_y: int, grid_max_x: int, grid_max_y: int,
		left: int, top: int, right: int, bottom: int) -> BoundsViolation:
	if left >= grid_min_x and top >= grid_min_y and right <= grid_max_x and bottom <= grid_max_y:
		return null
	var v: BoundsViolation = BoundsViolation.new()
	v.left = left
	v.top = top
	v.right = right
	v.bottom = bottom
	v.grid_max_x = grid_max_x
	v.grid_max_y = grid_max_y
	return v


## Runs `check_bounds`, and if it fires, logs it -- same "log always, never assert" policy as
## `report_floor_selection`.
static func report_bounds(grid_min_x: int, grid_min_y: int, grid_max_x: int, grid_max_y: int,
		left: int, top: int, right: int, bottom: int, seed: int, pos_x: int, pos_y: int) -> BoundsViolation:
	var v: BoundsViolation = check_bounds(grid_min_x, grid_min_y, grid_max_x, grid_max_y, left, top, right, bottom)
	if v != null:
		v.seed = seed
		v.pos_x = pos_x
		v.pos_y = pos_y
		push_error(v._to_string())
	return v


class TranslationConsentViolation:
	var dx: int  ## Fx, the displacement nothing accounts for -- the discriminating quantity, printed first
	var seed: int
	var pos_x: int  ## Fx
	var pos_y: int  ## Fx

	func _to_string() -> String:
		return ("Invariants: body's x moved %d Fx on a tick with no horizontal input and no incoming " +
			"horizontal velocity, and with no depenetration or bounds correction to account for it -- " +
			"some resolver path translated the body sideways of its own accord. seed=%d pos=(%d,%d)") % [
			dx, seed, pos_x, pos_y]


## Third real check (D0213): the post-condition for the INSTANT-TRANSLATION class -- a resolver path
## that moves the body further in one tick than its own velocity could carry it, in a direction the
## player never asked for. Three instances shipped before this check existed, each found by a human
## playing rather than by anything automated: the auto step-up firing mid-air (D0209, the director's
## "it feels like I teleport on top of the high step"), the mantle doing the same at up to 32px
## (D0212), and the ceiling corner nudge taking its direction from the stale `facing` field when the
## body had no horizontal velocity at all (D0213). A fourth needs to be loud on its first tick.
##
## The condition is deliberately about CONSENT rather than about any particular path, so it does not
## have to be updated when a new path is added -- that is the whole point. `move_dir == 0` and
## `entry_vel_x == 0` together mean the tick's own horizontal integration cannot move the body: with no
## input, `_integrate_horizontal`'s decel branches leave a zero velocity at zero, and `pos_x += vel_x /
## TICK_HZ` adds nothing. So on such a tick ANY change in `pos_x` came from a correction, and the only
## corrections entitled to make one are the two RECOVERY paths -- horizontal depenetration out of an
## existing overlap, and the world-bounds clamp -- which the caller reports via `recovering`. Both
## already announce themselves with their own per-tick flag, and both are responses to a state the body
## should not have been in; a nudge, a step, or a snap is not.
##
## What this cannot see, stated so it is not mistaken for wider cover: a translation that fires while
## the body IS moving horizontally. That case is exempt on purpose -- moving the body along a
## trajectory it already has is the definition of the forgiveness set, and a bound on its SIZE is a
## different check with a different threshold, not this one.
static func check_translation_consent(move_dir: int, entry_vel_x: int, entry_pos_x: int, pos_x: int,
		recovering: bool) -> TranslationConsentViolation:
	if move_dir != 0 or entry_vel_x != 0 or pos_x == entry_pos_x or recovering:
		return null
	var v: TranslationConsentViolation = TranslationConsentViolation.new()
	v.dx = pos_x - entry_pos_x
	return v


## Runs `check_translation_consent`, and if it fires, logs it -- same "log always, never assert" policy
## as the two reports above. NOT rate-limited, and unlike `report_floor_selection` it needs no caller-side
## de-duplication either: this reports a should-never-happen transition, not a state a resting body can
## sit in and re-announce every tick.
static func report_translation_consent(move_dir: int, entry_vel_x: int, entry_pos_x: int, pos_x: int,
		recovering: bool, seed: int, pos_y: int) -> TranslationConsentViolation:
	var v: TranslationConsentViolation = check_translation_consent(
		move_dir, entry_vel_x, entry_pos_x, pos_x, recovering)
	if v != null:
		v.seed = seed
		v.pos_x = pos_x
		v.pos_y = pos_y
		push_error(v._to_string())
	return v


## THE FLUID CONTRACT (`sim/fluid/MODULE.md`): total water is conserved across a flow step. Water only
## MOVES inside `WaterFlow`; every unit that enters or leaves the world does so through `WaterPlane`'s
## `add_water`/`remove_water`/`displace`, each of which returns what it did so the caller can account for
## it. So between two such calls the total is a constant, and a caller holding that constant can ask this
## after every step. `tests/test_water_flow.gd` does, over 10,000 fuzzed ticks (A' step 2, D0344). The one
## deliberate violation the module allows -- seepage upkeep -- does not exist yet and, when it does, must
## be one named function outside the flow passes, which is exactly what makes this check stay true.
class WaterConservationViolation:
	var expected_total: int
	var observed_total: int
	var tick: int
	func _to_string() -> String:
		return ("Invariants: water total changed across a flow step -- expected %d, observed %d " +
			"(tick %d). Water only moves in WaterFlow; a source or drain has appeared where none is " +
			"allowed.") % [expected_total, observed_total, tick]


static func check_water_conservation(water: WaterPlane, expected_total: int, tick: int) -> WaterConservationViolation:
	var observed: int = water.total_water()
	if observed == expected_total:
		return null
	var v: WaterConservationViolation = WaterConservationViolation.new()
	v.expected_total = expected_total
	v.observed_total = observed
	v.tick = tick
	return v


static func report_water_conservation(water: WaterPlane, expected_total: int, tick: int) -> WaterConservationViolation:
	return _reported(check_water_conservation(water, expected_total, tick))


## The `report_*` twins of the two water checks share this: log the violation if there is one, hand it
## back either way. One helper rather than two identical bodies (`tools/quality_check/duplication.py`).
static func _reported(v: Variant) -> Variant:
	if v != null:
		push_error(v._to_string())
	return v


## The other half of the same contract: water and rock never share a cell. `WaterFlow` never flows into
## rock and `add_water` refuses it, so the only way this fires is a rock placed over a wet cell whose owner
## forgot to call `WaterPlane.displace` -- the coupling legacy kept inline in `set_solid` and A' moves to
## the `sim/world` verbs (plan step 3). Returns the first offending cell in scan order, or null.
class WaterInRockViolation:
	var terrain_cell: Vector2i
	var level: int
	var tick: int
	func _to_string() -> String:
		return ("Invariants: %d unit(s) of water inside solid terrain cell (%d,%d) at tick %d -- rock " +
			"was placed over water without displacing it.") % [level, terrain_cell.x, terrain_cell.y, tick]


static func check_water_not_in_rock(water: WaterPlane, grid: TileGrid, tick: int) -> WaterInRockViolation:
	for terrain_cell: Vector2i in water.wet_terrain_cells():
		if grid.is_solid(terrain_cell):
			var v: WaterInRockViolation = WaterInRockViolation.new()
			v.terrain_cell = terrain_cell
			v.level = water.water_at(terrain_cell)
			v.tick = tick
			return v
	return null


static func report_water_not_in_rock(water: WaterPlane, grid: TileGrid, tick: int) -> WaterInRockViolation:
	return _reported(check_water_not_in_rock(water, grid, tick))


## THE PLACED LAYERS NEVER SIT IN ROCK (ADR 0009 §2-3). `World.place_*` refuses any metre with rock in it,
## and `World.set_solid` is the only way rock arrives; so this fires only when something wrote terrain
## under a placed thing without vacating it first -- the mirror of `check_water_not_in_rock`. Returns
## the first offending cell in scan order, or null.
class PlacedInRockViolation:
	var logic_cell: Vector2i
	var kind: StringName
	var tick: int
	func _to_string() -> String:
		return ("Invariants: a placed %s at logic cell (%d,%d) has rock inside its metre at tick %d -- " +
			"terrain was written under a placed layer without vacating it.") % [kind, logic_cell.x, logic_cell.y, tick]


static func check_placed_not_in_rock(world: World, tick: int) -> PlacedInRockViolation:
	for kind: StringName in [LogicGrid.KIND_MACHINE, LogicGrid.KIND_CONDUIT, LogicGrid.KIND_ROPE, LogicGrid.KIND_TORCH]:
		for logic_cell: Vector2i in world.logic.placed_logic_cells(kind):
			if not world.logic_air(logic_cell):
				var v: PlacedInRockViolation = PlacedInRockViolation.new()
				v.logic_cell = logic_cell
				v.kind = kind
				v.tick = tick
				return v
	return null


static func report_placed_not_in_rock(world: World, tick: int) -> PlacedInRockViolation:
	return _reported(check_placed_not_in_rock(world, tick))


## CONSERVATION OF ITEMS (`sim/items`): for every item ever produced or consumed, what is present --
## pack, ground, sink, machine buffers -- equals produced minus consumed. Items are created and destroyed
## only by a recipe or a placement, both of which write the ledger. Returns the first item in text
## order whose books do not balance, or null.
class ItemConservationViolation:
	var item: StringName
	var present: int
	var net: int
	var tick: int
	func _to_string() -> String:
		return ("Invariants: %s is not conserved at tick %d -- present %d, produced minus consumed %d. " +
			"An item was created or destroyed outside a recipe or a placement.") % [item, tick, present, net]


static func check_item_conservation(items: Items, tick: int) -> ItemConservationViolation:
	var ids: Dictionary = {}
	for item: StringName in items.total_produced:
		ids[item] = true
	for item: StringName in items.total_consumed:
		ids[item] = true
	for item: StringName in items.pack.items:
		ids[item] = true
	for item: StringName in Ordering.ids(ids):
		var present: int = items.present(item)
		var net: int = int(items.total_produced.get(item, 0)) - int(items.total_consumed.get(item, 0))
		if present != net:
			var v: ItemConservationViolation = ItemConservationViolation.new()
			v.item = item
			v.present = present
			v.net = net
			v.tick = tick
			return v
	return null


static func report_item_conservation(items: Items, tick: int) -> ItemConservationViolation:
	return _reported(check_item_conservation(items, tick))
