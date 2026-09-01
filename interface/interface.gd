class_name Interface
extends RefCounted

## L2, `docs/ARCHITECTURE.md` §5's "only door". Two operations, `observe(envelope) -> Observation` and
## `apply(Command) -> Result`, and nothing else public. `interface/MODULE.md` states the pair of
## invariants this file exists to make true: nothing above L2 calls a sim mutator, and nothing above L2
## reads raw sim state either, "so the envelope's filtering is never bypassable by reaching around it."
##
## THE SECOND INVARIANT IS WHY `Observation` COPIES. It would be far cheaper to hand back a `TileGrid`
## reference and let the caller index it, and that would silently delete the envelope: a consumer holding
## the grid can read any cell it likes, fogged or not, and no filter in this file could stop it. So an
## `Observation` is a VALUE -- flat arrays over one window, plus their legends -- built fresh per call
## and holding no reference to anything in `sim/`. That is the whole design, and the cost (a few KB per
## call for a screen-sized window) is what buys a capability envelope that cannot be worked around.
##
## THREE PLANES NOW, NOT ONE (D0238): blocks, the background wall, and a per-column surface height. The
## second and third exist because `view/` needs them and cannot reach them -- `TileGrid.get_wall()` and
## `Heightfield.column_surface_y()` both take a `TileGrid`, and a `view/` file may not hold one. Each is
## derived HERE, per window, so it inherits the envelope rather than bypassing it; a wider scan would
## make either one a second unfiltered channel into the grid.
##
## SMALL BECAUSE THE GAME IS SMALL. §5 names four envelope dimensions (vision, planning, motor, priors)
## and three standard envelopes (Oracle, Constrained, Language). Exactly one of those has a mechanism in
## this build -- a window, which is vision's spatial half -- and the rest are DELIBERATELY ABSENT rather
## than stubbed. There is no fog to filter, no planner to bound, no motor noise model, and no priors
## table; a field for each would be four lies in the type system, and `docs/adr/0007-l2-interface.md`
## argues that choice out in full. They arrive when the mechanism does.
##
## NOT A COORDINATOR. This object owns no scene, draws nothing, and runs no loop. It is constructed
## around a grid, a body and a mining verb that its caller already owns, and it advances them only when
## handed a `Command`. `tests/body/reveal_scene.gd` and friends are unchanged by its arrival and continue
## to drive `sim/` directly; migrating them is separate work, deliberately not bundled here.


## What a consumer is allowed to see. Today: a rectangle of cells, in cell coordinates.
##
## `window` is REQUIRED and has no default, on purpose. An envelope that means "everything" is the one
## an agent measuring discoverability must never be handed by accident, and a defaulted whole-world
## window is exactly how that happens. `oracle_over()` exists to make the unfiltered case say its own
## name at the call site.
class Envelope:
	var window: Rect2i

	func _init(cell_window: Rect2i) -> void:
		window = cell_window

	## Perfect spatial information over a whole grid -- §5's Oracle envelope, as far as this build has a
	## mechanism for it. Named rather than written as a literal `Rect2i(0, 0, w, h)` at each call site so
	## a reader can see which runs are unfiltered.
	static func oracle_over(grid: TileGrid) -> Envelope:
		return Envelope.new(Rect2i(0, 0, grid.width, grid.height))

	## The window covering a world-PIXEL rectangle, grown by `margin_cells` on every side.
	##
	## THIS LIVES HERE BECAUSE THE CONVERSION NEEDS A `sim/` CONSTANT and its caller is `view/`, which may
	## depend on `{interface, core}` and not on `sim`. The alternative -- re-declaring the terrain cell
	## size in `view/` -- would put a second definition of a world-scale number in the tree, and the near
	## miss is worth recording: `view/visuals/material_look.gd` already carries `CELLS_PER_METRE = 4`,
	## which is a DIFFERENT quantity (cells per metre, not pixels per cell) that happens to share the
	## value at 16px/m. Reaching for it would have been right by coincidence and wrong by construction.
	##
	## `floor` on the near edge and `ceil` on the far one, never `int()`: truncation toward zero drops
	## the partially-visible row at the top and left of the screen, a one-cell strip of undrawn world
	## that appears only at some camera positions and reads as flicker rather than as a missing feature.
	static func covering(world_rect: Rect2, margin_cells: int) -> Envelope:
		var cell: float = float(Heightfield.TERRAIN_CELL_PX)
		var margin := Vector2i(margin_cells, margin_cells)
		var lo := Vector2i(int(floor(world_rect.position.x / cell)),
			int(floor(world_rect.position.y / cell))) - margin
		var hi := Vector2i(int(ceil(world_rect.end.x / cell)),
			int(ceil(world_rect.end.y / cell))) + margin
		return Envelope.new(Rect2i(lo, hi - lo))


## One tick's readable state, as a value. Holds no reference into `sim/`.
##
## The body's box edges travel as their own fields rather than being recomputed by the consumer from
## `pos` and `Body.WIDTH_PX`: those constants are `sim/body`'s, a `view/` file may not reach for them
## (`tools/layer_lint/layer_lint.py`'s own table gives `view` only `interface` and `core`), and two
## copies of the same half-width arithmetic is exactly the drift this layer exists to prevent.
class Observation:
	var tick: int
	var pos_x: int  ## Fx, all six of these
	var pos_y: int
	var left_x: int
	var right_x: int
	var top_y: int
	var bottom_y: int
	var vel_x: int
	var vel_y: int
	var on_floor: bool
	var facing: int
	var cell: Vector2i  ## the terrain cell the body's centre is in
	var window: Rect2i
	## Row-major over `window`, one byte per cell: an index into `legend`. 0 is always the empty
	## material, so `solid_at` is a byte comparison and not a string one.
	var materials: PackedByteArray
	var legend: PackedStringArray
	## THE BACKGROUND WALL PLANE, same shape and same encoding as `materials`/`legend` (D0238). This is
	## the layer `TileGrid.get_wall()` holds -- what `excavate()` REVEALS rather than erases, and where
	## the lode migration put ore. A renderer needs it to draw a mined-out room as a recessed back wall
	## instead of a hole in a sheet; without it there is no depth behind the player at all.
	var walls: PackedByteArray
	var wall_legend: PackedStringArray
	## One entry per COLUMN of `window`, left to right: the walkable surface height as an `Fx` world-y,
	## or `Heightfield.NO_FLOOR`. Derived here rather than by the consumer because `Heightfield` takes a
	## `TileGrid` and `view/` may not hold one.
	##
	## `_y`, never `_row`: this is a pixel height in `Fx`, not a cell index, and `heightfield.gd` names
	## it that way for the same reason -- "so a caller can't mistake one for the other."
	##
	## SCANNED WITHIN THE WINDOW ONLY. A column whose only solid cell sits above the window reads
	## `NO_FLOOR`, because the observer was not given those cells. That is the envelope working, not a
	## bug: an observation must never answer from data it did not hand over.
	var surface_y: PackedInt32Array

	## --- THE MINING VERB'S OWN STATE -----------------------------------------------------------------
	##
	## `docs/LEGACY_GAP.md` PRE-3, and the finding it records: `sim/mining/mining.gd` computed all of this
	## and `observe()` read `_grid` and `_body` **and never touched `_mining` at all**. Every mining
	## feedback capability in the backlog -- cracks, crumble, the hollow ring, the breach payoff, the
	## draught, payout ticks -- was blocked behind one door that had simply never been opened.
	##
	## Copied per observation rather than handed over as a reference to the `Mining` object, which is the
	## same rule the body's fields above follow: an `Observation` is a COPY, so a view cannot reach back
	## through it and mutate the sim (`docs/ARCHITECTURE.md` L2, `tests/test_interface.gd`).

	## The cell this tick's hold advanced, and whether there was one. **The boolean is not redundant.**
	## `Mining.NO_CELL` is the sentinel, and a view testing against it would have to name a `sim/` symbol
	## to ask an ordinary question -- which `tools/layer_lint` forbids and which would make the sentinel
	## part of the public contract. The door answers the question instead of handing over the key.
	var mining_charging_cell: Vector2i = Vector2i.ZERO
	var mining_is_charging: bool = false

	## Cell -> **progress toward breaking it, per mille**, for every cell currently holding a crack. A
	## crack overlay reads this instead of probing the whole visible grid every frame, which is what
	## `Mining.cracked_cells()` was written for and what nothing had yet called.
	##
	## THE FRACTION, NOT THE RAW BANKED CHARGE, and the difference is a layer boundary rather than a
	## convenience. What a renderer draws is how far gone the rock looks, which is `banked / break_cost`
	## — and `break_cost` is a function of the MATERIAL, so a view holding the raw charge would have to
	## call `Mining.break_cost()` to mean anything by it. That is a `sim/` symbol, and `view/` may not
	## name one. Per mille to match `mining_hollow`, and integer for the same reason everything else here
	## is: a float in the observation is a float in a replay.
	var mining_cracks: Dictionary = {}

	## What this tick's blow actually did. `broke_cells` is target-first in the deterministic scan order
	## `_clear_bite` walks, so a view spraying debris per cleared cell reads it rather than re-deriving
	## the disc -- a second copy of that shape would be free to drift from the one that ran.
	var mining_broke: bool = false
	var mining_broke_material: StringName = &""
	var mining_broke_cells: Array[Vector2i] = []

	## THE HOLLOW READING AS A MAGNITUDE (per mille), and `mining_breach` is one threshold sampled from
	## it. Legacy's own reason for carrying the number rather than the flag: "volume rides the reading, so
	## closing on a cavity is a crescendo you can act on rather than a flag that flips." A consumer given
	## only the boolean cannot reconstruct the crescendo; one given the magnitude can derive the boolean.
	var mining_hollow: int = 0
	var mining_breach: bool = false

	## The terrain cell's size in world pixels. **Not a mining field** — it belongs to whatever a painter
	## does with `window`, `materials` and `walls`, all of which are cell-denominated while every draw
	## call is in pixels. `view/` may not name `Heightfield.TERRAIN_CELL_PX`, and until now every painter
	## that needed it either lived outside `view/` or worked in fractions. The layer lint caught the first
	## one that did not (`view/visuals/crack_painter.gd`), which is the gate doing exactly its job.
	var cell_px: int = 0

	## The diameter, in world pixels, of what ONE blow destroys — `(2 * bite_radius + 1) * cell`. Carried
	## because a crack overlay has to size itself against the blow rather than against the cell (see
	## `view/visuals/crack_painter.gd`'s header on WG-4), and `Mining.bite_radius` is a `sim/` field a view
	## may not read. Derived here rather than in the painter for the same reason `mining_cracks` is a
	## fraction: the door converts, so no consumer has to name a sim symbol to interpret what it was given.
	var mining_blow_px: int = 0

	## True iff `c` holds solid material. Outside the window returns false -- NOT "unknown", and the
	## distinction matters as soon as fog exists: a consumer asking about a cell it was not given should
	## be reading `in_window` first. Deliberately not an error, because a renderer legitimately probes
	## the ring just past its own window when deciding edges.
	func solid_at(c: Vector2i) -> bool:
		return material_at(c) != &""

	func material_at(c: Vector2i) -> StringName:
		return _plane_at(legend, materials, c)

	## The BACKGROUND material at `c`, or `&""` -- both for "no wall here" and for "outside the window",
	## exactly as `material_at` conflates them. Same reasoning, and the same warning applies: a consumer
	## that needs to tell those apart asks `in_window` FIRST.
	func wall_at(c: Vector2i) -> StringName:
		return _plane_at(wall_legend, walls, c)

	## Shared body of the two plane readers. They are one function with two bindings, not two functions:
	## written out separately they were byte-identical under identifier normalization and the BLOCKING
	## duplication gate said so. Keeping the out-of-window `&""` in ONE place also means the two planes
	## cannot drift on the question that matters most about them.
	func _plane_at(plane_legend: PackedStringArray, bytes: PackedByteArray, c: Vector2i) -> StringName:
		if not in_window(c):
			return &""
		return plane_legend[bytes[_offset_of(c)]]

	func in_window(c: Vector2i) -> bool:
		return window.has_point(c)

	## The walkable surface height of one terrain column as an `Fx` world-y, or `Heightfield.NO_FLOOR`
	## for a column outside the window or with no floor inside it.
	##
	## Takes a bare `int` column rather than a `Vector2i` on purpose: a surface is a property of a
	## column, and passing a cell would invite a caller to believe the row mattered.
	func surface_y_at_terrain_col(terrain_col: int) -> int:
		if terrain_col < window.position.x or terrain_col >= window.end.x:
			return Heightfield.NO_FLOOR
		return surface_y[terrain_col - window.position.x]

	## Row-major offset of `c` within the window. Callers must have checked `in_window` first -- this
	## does no bounds checking and would happily index a neighbouring row for a cell one column outside.
	func _offset_of(c: Vector2i) -> int:
		return (c.y - window.position.y) * window.size.x + (c.x - window.position.x)


## `apply()`'s answer. `reason` is empty exactly when `ok` is true, and §5 makes it telemetry rather than
## a debugging aid: "a command is submitted, validated, and either applied or rejected with a reason.
## Rejection reasons are part of the telemetry." So the reasons are a closed vocabulary of `StringName`s
## a counter can be keyed on, not free prose.
class Result:
	var ok: bool
	var reason: StringName

	static func accepted() -> Result:
		var r: Result = Result.new()
		r.ok = true
		r.reason = &""
		return r

	static func rejected(why: StringName) -> Result:
		var r: Result = Result.new()
		r.ok = false
		r.reason = why
		return r


## The terrain grid's pixel size, RE-EXPORTED for `view/` (D0244). A painter sizes world-space drawing in
## these and may not reference `sim/`, where the constant lives. This is a re-export, not a second
## definition: it reads `Heightfield`'s, so there is still exactly one number. `view/` reaching for its
## own copy is the near miss D0240 already recorded -- `material_look.gd` carries `CELLS_PER_METRE = 4`,
## a different quantity that happens to share the value, and copying it would be right by coincidence.
const TERRAIN_CELL_PX: int = Heightfield.TERRAIN_CELL_PX

const REJECT_UNKNOWN_KIND: StringName = &"unknown_command_kind"
const REJECT_OUT_OF_BOUNDS: StringName = &"target_out_of_bounds"
const REJECT_NOT_SOLID: StringName = &"target_not_solid"
const REJECT_OUT_OF_REACH: StringName = &"target_out_of_reach"

var _grid: TileGrid
var _body: Body
var _mining: Mining
var _tick: int = 0


func _init(grid: TileGrid, body: Body, mining: Mining) -> void:
	_grid = grid
	_body = body
	_mining = mining


## Pure read. Advances nothing, and a caller may make as many of these per tick as it likes without
## changing a single sim value -- `tests/test_interface.gd` asserts that against `state_signature()`
## rather than leaving it as a promise in this comment.
func observe(envelope: Envelope) -> Observation:
	var o: Observation = Observation.new()
	o.tick = _tick
	o.pos_x = _body.pos_x; o.pos_y = _body.pos_y
	o.left_x = _body._left_x(); o.right_x = _body._right_x()
	o.top_y = _body._top_y(); o.bottom_y = _body._bottom_y()
	o.vel_x = _body.vel_x; o.vel_y = _body.vel_y
	o.on_floor = _body.on_floor
	o.facing = _body.facing
	o.cell = Vector2i(Body._px_to_cell(_body.pos_x), Body._px_to_cell(_body.pos_y))
	o.window = envelope.window
	o.cell_px = Heightfield.TERRAIN_CELL_PX
	_fill_window(o)
	_fill_mining(o)
	return o


## The mining verb's per-tick state, copied onto the observation. Split out of `observe` for the same
## reason `_fill_window` is: that function stays a flat list of field reads a reader can check against
## `Observation` by eye.
##
## `duplicate()` on the crack map and the broken-cell list, not a reference. Handing over the live
## containers would let a view clear the sim's crack bank by tidying up after itself, and the failure
## would surface as a determinism divergence hundreds of ticks later with nothing pointing back here.
func _fill_mining(o: Observation) -> void:
	o.mining_charging_cell = _mining.charging_cell
	o.mining_is_charging = _mining.charging_cell != Mining.NO_CELL
	o.mining_cracks = {}
	for cell: Vector2i in _mining.cracked_cells():
		var cost: int = Mining.break_cost(_grid.get_material(cell))
		# A cell whose material has somehow no cost cannot be "part way broken", and dividing by it would
		# be a crash in the door rather than in whatever wrote the bad material.
		o.mining_cracks[cell] = (_mining.banked(cell) * 1000) / cost if cost > 0 else 0
	o.mining_broke = _mining.broke_this_tick
	o.mining_broke_material = _mining.broke_material
	o.mining_broke_cells = _mining.broke_cells.duplicate()
	o.mining_hollow = _mining.hollow_this_tick
	o.mining_breach = _mining.breach_this_tick
	o.mining_blow_px = (2 * _mining.bite_radius + 1) * Mining.CELL_PX


## Copies the window into the three derived fields. Split out of `observe` so that function stays a flat
## list of field reads a reader can check against `Observation` by eye.
func _fill_window(o: Observation) -> void:
	var blocks: Array = _plane_over_window(o.window, _grid.get_material)
	o.materials = blocks[0]
	o.legend = blocks[1]
	var background: Array = _plane_over_window(o.window, _grid.get_wall)
	o.walls = background[0]
	o.wall_legend = background[1]
	_fill_surface(o)


## One plane of the window as `[PackedByteArray, PackedStringArray]`, where `read` maps a terrain cell
## to its material id.
##
## Shared by the block plane and the wall plane rather than written twice. The two loops would differ
## only in which `TileGrid` getter they call, and `tools/quality_check/duplication.py` is a BLOCKING
## gate that would reject the copy -- correctly, since the byte encoding, the legend-interning and the
## row-major order are one contract that `Observation._offset_of` decodes for both.
func _plane_over_window(window: Rect2i, read: Callable) -> Array:
	var index_of: Dictionary = {&"": 0}
	var legend: PackedStringArray = PackedStringArray([&""])
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(window.size.x * window.size.y)
	var i: int = 0
	for row: int in range(window.position.y, window.end.y):
		for col: int in range(window.position.x, window.end.x):
			var m: StringName = read.call(Vector2i(col, row))
			if not index_of.has(m):
				index_of[m] = legend.size()
				legend.append(m)
			bytes[i] = index_of[m]
			i += 1
	return [bytes, legend]


## One `Fx` surface height per window column, scanned WITHIN the window only.
##
## `scan_from_row` is the window's top and `max_rows` its height, so this can never report a floor the
## observation did not also hand over as cells. Widening the scan past the window would make
## `surface_y` a second, unfiltered channel into the grid -- which is precisely the reach-around
## `Observation` copies in order to prevent.
func _fill_surface(o: Observation) -> void:
	o.surface_y = PackedInt32Array()
	o.surface_y.resize(o.window.size.x)
	for i: int in range(o.window.size.x):
		o.surface_y[i] = Heightfield.column_surface_y(
			_grid, o.window.position.x + i, o.window.position.y, o.window.size.y)


## The only mutator. Every rejection is a named reason, and a rejected command changes nothing at all --
## no partial application, no tick advance.
func apply(command: Command) -> Result:
	match command.kind:
		Command.Kind.MOVE:
			_body.tick(command.input, _grid)
			_tick += 1
			return Result.accepted()
		Command.Kind.MINE:
			return _apply_mine(command.cell)
	return Result.rejected(REJECT_UNKNOWN_KIND)


## Validation lives HERE rather than in `sim/mining`, per `sim/commands/MODULE.md` ("validation and
## application happen in `interface` and in each target submodule"). `Mining.mine` has its own
## `_workable` check and would simply do nothing for each of these three cases; the difference is that a
## silent no-op is not telemetry. The reasons are what tell a discoverability run the difference between
## an agent that never tried and one that tried and could not reach.
func _apply_mine(cell: Vector2i) -> Result:
	if not _grid.in_bounds(cell):
		return Result.rejected(REJECT_OUT_OF_BOUNDS)
	if not _grid.is_solid(cell):
		return Result.rejected(REJECT_NOT_SOLID)
	if not Mining.in_reach(_body.pos_x, _body.pos_y, cell):
		return Result.rejected(REJECT_OUT_OF_REACH)
	_mining.mine(_grid, _body.pos_x, _body.pos_y, cell, true)
	return Result.accepted()
