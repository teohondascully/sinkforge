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
## `Observation` is a VALUE -- a flat byte array over one window, plus a legend -- built fresh per call
## and holding no reference to anything in `sim/`. That is the whole design, and the cost (a few KB per
## call for a screen-sized window) is what buys a capability envelope that cannot be worked around.
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

	## True iff `c` holds solid material. Outside the window returns false -- NOT "unknown", and the
	## distinction matters as soon as fog exists: a consumer asking about a cell it was not given should
	## be reading `in_window` first. Deliberately not an error, because a renderer legitimately probes
	## the ring just past its own window when deciding edges.
	func solid_at(c: Vector2i) -> bool:
		return material_at(c) != &""

	func material_at(c: Vector2i) -> StringName:
		if not in_window(c):
			return &""
		var i: int = (c.y - window.position.y) * window.size.x + (c.x - window.position.x)
		return legend[materials[i]]

	func in_window(c: Vector2i) -> bool:
		return window.has_point(c)


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
	_fill_window(o)
	return o


## Copies the window into `o.materials`/`o.legend`. Split out of `observe` so that function stays a flat
## list of field reads a reader can check against `Observation` by eye.
func _fill_window(o: Observation) -> void:
	var index_of: Dictionary = {&"": 0}
	o.legend = PackedStringArray([&""])
	o.materials = PackedByteArray()
	o.materials.resize(o.window.size.x * o.window.size.y)
	var i: int = 0
	for row: int in range(o.window.position.y, o.window.end.y):
		for col: int in range(o.window.position.x, o.window.end.x):
			var m: StringName = _grid.get_material(Vector2i(col, row))
			if not index_of.has(m):
				index_of[m] = o.legend.size()
				o.legend.append(m)
			o.materials[i] = index_of[m]
			i += 1


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
