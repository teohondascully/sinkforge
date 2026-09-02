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
	## THE WORLD'S OWN SIZE IN CELLS, so a consumer can tell the EDGE OF THE WORLD from a hole in it
	## (D0302). `window` may extend past the world — the margin is added without clamping — and every
	## plane accessor answers `&""` outside the data it was given, so "outside the world" and "open air"
	## arrive as the same byte. That is fine for a painter drawing one cell at a time and wrong for any
	## consumer that AVERAGES over a neighbourhood: `VeilPainter` blurs openness over 8 cells, read the
	## out-of-world ring as air, and lit a false halo along the world's own left, right and bottom edges.
	##
	## A copy like every other field here, never a reference to the grid (ARCHITECTURE §3).
	var world_cells: Vector2i
	## THE WORLD SEED, and the whole of `docs/LEGACY_GAP.md` PRE-4 (D0308). `core/seams.gd` is fully
	## ported, integer-exact over all 196,608 inputs, and `Seams.at(cell, world_seed)` could not be called
	## by anything in `view/` because the seed was on `TileGrid` and `TileGrid` is `sim/`. One `int`.
	##
	## It is a SEED, not a handle: a painter may hash it and must never treat it as a key back into the
	## sim. `Seams` is a pure function of `(coordinate, world_seed)` and never saved, which is exactly why
	## this field is enough to draw the grain without the renderer reaching across the L2 boundary.
	var world_seed: int = 0
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
	## Whether the wall plane above was actually built (D0338). False means the envelope declined it and
	## `wall_at` will refuse rather than answer air. Defaults TRUE so an Observation built by hand in a
	## test behaves exactly as it did before this flag existed.
	var has_walls: bool = true
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

	## True on the tick the pick LANDS, false on the ticks between blows (D0279). An edge, not a level:
	## legacy's ring, draught and pick animation all fire per blow, and firing them per charging tick
	## would be sixty a second. The period shortens as `Mining`'s rhythm builds, which is that system's
	## first outward sign.
	var mining_swing: bool = false

	## THE SWING DIRECTION, as a unit cell step from the body toward what it is working. `Mining.swing_dir`
	## has been public "specifically for this" since it was written and **nothing has ever called it** —
	## `docs/LEGACY_GAP.md` T1 #6 names that directly. A draught puff has to be placed on the NEAR face and
	## drift along the swing, and deriving the direction a second time in the view would be a second copy
	## of a thing the sim already decided (D0293).
	var mining_swing_dir: Vector2i = Vector2i.ZERO

	## ...and how far through the CURRENT swing the pick is, per mille — 0 on the tick it lands, climbing
	## to 1000 as the next blow winds up. The edge above says a blow happened; this says where in the
	## stroke the arms are, which is what a two-frame pick animation needs to put its struck frame on the
	## tick the rock takes damage rather than on a free-running clock of its own (D0287).
	var mining_swing_phase: int = 0

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
	## FAILS LOUDLY WHEN THE PLANE WAS NOT REQUESTED (D0338), rather than answering `&""`. An absent plane
	## and a world of air are the same answer, which is D0238's trap exactly -- and the consumer that would
	## meet it, `WallPainter`, draws nothing for air, so the failure would arrive as a silently missing
	## background rather than as an error. `has_walls` is the envelope's own `walls` flag carried through.
	func wall_at(c: Vector2i) -> StringName:
		if not has_walls:
			push_error("Observation.wall_at: this observation was taken without the wall plane "
				+ "(Envelope.walls == false). Ask for it in the envelope rather than reading air.")
			return &""
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
## THE HOLLOW READING'S OWN SCALE, republished at the door. `mining_hollow`'s note says a consumer given
## the magnitude "can derive the boolean" — which is only true if it also has the thresholds, and those
## live on `HollowTell`, which is `sim/`. So they come through here with everything else the reading needs
## (D0293). `RING` is the level at which a blow starts to answer hollow; `FULL` is the per-mille scale.
const HOLLOW_RING: int = HollowTell.RING
const HOLLOW_FULL: int = HollowTell.FULL

## `Interface.Envelope`, split into its own file at D0294. A `const` rather than a `class_name` keeps
## the one name it is reached by (see that file's header).
const Envelope = preload("res://interface/envelope.gd")

const TERRAIN_CELL_PX: int = Heightfield.TERRAIN_CELL_PX

const REJECT_UNKNOWN_KIND: StringName = &"unknown_command_kind"
const REJECT_OUT_OF_BOUNDS: StringName = &"target_out_of_bounds"
const REJECT_NOT_SOLID: StringName = &"target_not_solid"
const REJECT_OUT_OF_REACH: StringName = &"target_out_of_reach"

var _grid: TileGrid
var _body: Body
var _mining: Mining
var _tick: int = 0
## The derived window planes, refreshed on terrain or window change rather than per tick (D0340). Held
## per Interface, not per Observation, because an Observation is built and thrown away every frame and a
## cache that died with its consumer would never hit.
var _cache: WindowCache = WindowCache.new()


func _init(grid: TileGrid, body: Body, mining: Mining) -> void:
	_grid = grid
	_body = body
	_mining = mining


## Pure read. Advances nothing, and a caller may make as many of these per tick as it likes without
## changing a single sim value -- `tests/test_interface.gd` asserts that against `state_signature()`
## rather than leaving it as a promise in this comment.
## How many times the window planes were actually rebuilt. For confirming the cache SKIPS work rather
## than merely returning right answers -- a cache that recomputed every time passes every correctness
## assertion and none of the reason it exists.
func plane_rebuilds() -> int:
	return _cache.builds


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
	o.world_cells = Vector2i(_grid.width, _grid.height)
	o.world_seed = _grid.seed
	o.cell_px = Heightfield.TERRAIN_CELL_PX
	_fill_window(o, envelope)
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
	o.mining_swing = _mining.swing_this_tick
	o.mining_swing_phase = _mining.swing_phase_per_mille()
	o.mining_swing_dir = _mining.swing_dir(_body.pos_x, _body.pos_y, _mining.charging_cell) \
		if _mining.charging_cell != Mining.NO_CELL else Vector2i.ZERO
	o.mining_blow_px = (2 * _mining.bite_radius + 1) * Mining.CELL_PX


## Copies the window into the three derived fields. Split out of `observe` so that function stays a flat
## list of field reads a reader can check against `Observation` by eye.
func _fill_window(o: Observation, envelope: Envelope) -> void:
	# REBUILT ONLY WHEN THE TERRAIN OR THE WINDOW CHANGED (D0340). This was 6.36 ms a tick against a
	# 120 Hz budget of 8.33 -- the largest cost left after D0336-D0338 -- spent re-deriving planes that
	# are a pure function of (window, terrain contents), neither of which moves on most frames.
	# `interface/window_cache.gd` has the full account and the reason the key is a version and not a hash.
	_cache.refresh(o.window, _grid.terrain_version, envelope.walls,
		_grid.get_material, _grid.get_wall, _surface_over)
	o.materials = _cache.materials
	o.legend = _cache.legend
	o.surface_y = _cache.surface_y
	o.has_walls = envelope.walls
	if envelope.walls:
		o.walls = _cache.walls
		o.wall_legend = _cache.wall_legend


## One `Fx` surface height per window column, as a value rather than written onto an Observation, so the
## cache can hold it beside the planes it is refreshed with.
func _surface_over(window: Rect2i) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(window.size.x)
	for i: int in range(window.size.x):
		out[i] = Heightfield.column_surface_y(_grid, window.position.x + i, window.position.y,
			window.size.y)
	return out


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
