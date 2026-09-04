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
## than stubbed: no fog, no planner bound, no motor noise, no priors table. A field for each would be four
## lies in the type system (`docs/adr/0007-l2-interface.md`). They arrive when the mechanism does.
##
## NOT A COORDINATOR. This object owns no scene, draws nothing, and runs no loop. It is constructed
## around a grid, a body and a mining verb that its caller already owns, and it advances them only when
## handed a `Command`. `tests/body/reveal_scene.gd` and friends still drive `sim/` directly, on purpose.


## `Interface.Observation`, split into its own file at A' step 4 (D0356). A `const` rather than a
## `class_name` keeps the one name it is reached by (see that file's header).
const Observation = preload("res://interface/observation.gd")
## The hub's planes, filled by `interface/hub_planes.gd` (A' step 4, D0356).
const HubPlanes = preload("res://interface/hub_planes.gd")


## `apply()`'s answer. `reason` is empty exactly when `ok` is true, and §5 makes it telemetry rather than
## a debugging aid: "a command is submitted, validated, and either applied or rejected with a reason.
## Rejection reasons are part of the telemetry." So the reasons are a closed vocabulary of `StringName`s
## a counter can be keyed on, not free prose.
class Result:
	var ok: bool
	var reason: StringName
	var detail: StringName = &""   ## what an accepted verb did (`machine`, `picked_up`, `armed`, ...)

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
const REJECT_NO_LINE_OF_SIGHT: StringName = &"target_behind_rock"
const REJECT_NOTHING_HAPPENED: StringName = &"nothing_to_do"     # a verb that found nothing to do there
const REJECT_BAD_SELECTION: StringName = &"selection_out_of_range"

## THE SESSION'S SERVICES (A' step 4, D0356). The door owns the world with its planes, the item
## service, the machine registry, the body, the mining verb and its verb-layer siblings, the situated
## verbs and the production-rate window -- one owner, so a save captures everything and a load swaps
## every plane at once (ADR 0010 §4). `_grid` is `_world.grid`, read through the world each time because
## a load replaces the grid object.
var _world: World
var _items: Items
var _machines: Machines
var _body: Body
var _mining: Mining
var _plan: DigPlan = DigPlan.new()
var _lode: LodeWork = LodeWork.new()
var _verbs: Verbs
var _rates: ProductionRate = ProductionRate.new()
var _hold: MineHold = MineHold.new()
var _events: Array[Dictionary] = []   # flow events since the last observe: the consumed channel
var _tick: int = 0
## The derived window planes, refreshed on terrain or window change rather than per tick (D0340). Held
## per Interface, not per Observation, because an Observation is built and thrown away every frame and a
## cache that died with its consumer would never hit.
var _cache: WindowCache = WindowCache.new()


## Constructed around a grid, a body and a mining verb the caller owns, as before; a full session hands
## its world, items and registry too (`world.grid` must be `grid`), else fresh ones wrap the grid.
func _init(grid: TileGrid, body: Body, mining: Mining, world: World = null, items: Items = null, machines: Machines = null) -> void:
	_world = world if world != null else World.new(grid)
	_items = items if items != null else Items.new(_world)
	_machines = machines if machines != null else Machines.new()
	_machines.attach_to(_items)
	_body = body
	_body.surroundings = WorldSurroundings.new(_world, _machines)   # machines, ropes, water, drafts (5c)
	_mining = mining
	_verbs = Verbs.new(_world, _items, _machines, _body)


## Every owned state's signature, joined by `||` (the world's and the verbs' own signatures carry
## single `|`s): the replay-determinism contract for the whole session.
func state_signature() -> String:
	return "||".join([_body.state_signature(), _world.state_signature(), _items.state_signature(),
		_machines.state_signature(), _mining.state_signature(), _plan.state_signature(),
		_lode.state_signature(), _verbs.state_signature()])


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
	o.world_cells = Vector2i(_world.grid.width, _world.grid.height)
	o.map = _world.grid.coarse
	o.map_cells = Vector2i(_world.grid.coarse_width, _world.grid.coarse_height)
	o.map_version = _world.grid.coarse_version
	o.map_machines = _machines.machine_logic_cells() if _machines != null else []
	o.world_seed = _world.grid.seed
	o.cell_px = Heightfield.TERRAIN_CELL_PX
	_fill_window(o, envelope)
	_fill_mining(o)
	HubPlanes.fill(o, _world, _items, _machines)
	o.hub_tick = _tick / HubTick.HUB_TICK_DIVISOR
	o.pack_selected = _verbs.selected
	o.winch_armed = _verbs.pending_winch_head
	o.rates = _rates.rates(_items)
	o.dig_marks = Ordering.cells(_plan.marks)
	o.lode_target = _lode.target
	o.lode_progress = _lode.progress_per_mille()
	o.aim_cell = _hold.aim_cell
	o.aim_in_reach = _hold.aim_cell != Vector2i(-1, -1) and Mining.in_reach(_body.pos_x, _body.pos_y, _hold.aim_cell)
	o.aim_is_lode = _hold.aim_is_lode
	AimPlanes.fill(o, _verbs, _world, _machines)
	_fill_line(o)
	o.flow_events = _events.duplicate(true)
	_events.clear()   # the consumed channel: not sim state, and the one thing observe empties
	return o


## The mining verb's per-tick state, copied onto the observation. Split out of `observe` for the same
## reason `_fill_window` is: that function stays a flat list of field reads a reader can check against
## `Observation` by eye.
##
## `duplicate()` on the crack map and the broken-cell list, not a reference. Handing over the live
## containers would let a view clear the sim's crack bank by tidying up after itself, and the failure
## would surface as a determinism divergence hundreds of ticks later with nothing pointing back here.
## The rope and the medium, copied for the painter. The ghost is a pure trace from the hand toward the
## last aimed cell, only while the line is stowed: once you are on the rope the attention belongs on the arc.
func _fill_line(o: Observation) -> void:
	var g: Grapple = _body.grapple
	o.grapple_state = int(g.state)
	o.grapple_live = g.live()
	o.grapple_anchored = g.state == Grapple.State.ANCHORED
	o.grapple_throwing = g.throwing()
	o.grapple_tip = g.tip
	o.grapple_anchor = g.anchor
	o.grapple_hitch = g.hitch_fx()
	o.grapple_pivots = g.pivots.duplicate()
	o.grapple_length = g.length
	o.grapple_taut = g.taut
	o.hand = BodySwing.hand_fx(_body)
	o.grapple_slack = g.slack_permille(Vector2i(_body.pos_x, _body.pos_y))
	o.grapple_just_planted = g.just_planted
	o.grapple_just_cut = g.just_cut
	if not g.live() and _hold.aim_cell != Vector2i(-1, -1):
		var c: int = Body.CELL_PX * Fx.SCALE
		var toward := Vector2i(_hold.aim_cell.x * c + c / 2, _hold.aim_cell.y * c + c / 2)
		o.grapple_ghost = g.trace(_world.grid, o.hand, toward)
	o.climbing = _body.climbing
	o.wet = _body.wet


func _fill_mining(o: Observation) -> void:
	o.mining_charging_cell = _mining.charging_cell
	o.mining_is_charging = _mining.charging_cell != Mining.NO_CELL
	o.mining_cracks = {}
	for cell: Vector2i in _mining.cracked_cells():
		var cost: int = Mining.break_cost(_world.grid.get_material(cell))
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
	_cache.refresh(o.window, _world.grid.terrain_version, envelope.walls,
		_world.grid.get_material, _world.grid.get_wall, _surface_over)
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
		out[i] = Heightfield.column_surface_y(_world.grid, window.position.x + i, window.position.y,
			window.size.y)
	return out


## The only mutator. Every rejection is a named reason, and a rejected command changes nothing at all --
## no partial application, no tick advance.
func apply(command: Command) -> Result:
	match command.kind:
		Command.Kind.MOVE:
			_body.tick(command.input, _world.grid)
			_tick += 1
			_verbs.tick()
			var building: bool = _verbs.selected_machine_def() != null or _verbs.selected_build_material() != &""
			_hold.step(command.input, _world, _items, _mining, _plan, _lode, _body, building)
			HubTick.advance(_tick, _world, _items, _machines, _rates)   # every third body tick (D0345)
			_drain_events()
			return Result.accepted()
		Command.Kind.MINE:
			return _apply_mine(command.cell)
		Command.Kind.BUILD:
			return _outcome(_verbs.build(command.cell))
		Command.Kind.DROP:
			return _outcome(&"dropped" if _verbs.drop() > 0 else &"")
		Command.Kind.COLLECT:
			return _outcome(&"collected" if _verbs.collect() > 0 else &"")
		Command.Kind.CONFIGURE:
			return _outcome(StringName(_verbs.configure(command.cell)))
		Command.Kind.LINK_WINCH:
			return _outcome(_verbs.link_winch(command.cell))
		Command.Kind.SELECT:
			if command.index < 0 or command.index >= Pack.inventory_slots():
				return Result.rejected(REJECT_BAD_SELECTION)
			_verbs.selected = command.index
			return Result.accepted()
		Command.Kind.CLEAR_PLAN:
			_plan.clear()
			return Result.accepted()
	return Result.rejected(REJECT_UNKNOWN_KIND)


## A situated verb's outcome as a Result: what happened rides `detail`; nothing is a named rejection.
func _outcome(detail: StringName) -> Result:
	_drain_events()
	if detail == &"":
		return Result.rejected(REJECT_NOTHING_HAPPENED)
	var r: Result = Result.accepted()
	r.detail = detail
	return r


## THE SHELL'S HANDLE ON THE SESSION (A' step 4b, D0357): the owned services, for `shell/session.gd`'s
## save and boot only. The layer lint lets the shell reach `sim/`; nothing else above L2 may take these,
## and the view never does -- it reads observations. Not a second door: a save is the session's
## exterior, and the shell writing it is what the door exists to keep everything else from doing.
func services() -> Dictionary:
	return {"world": _world, "items": _items, "machines": _machines, "body": _body, "mining": _mining,
		"plan": _plan, "lode": _lode}


## After a load: the consumed channel and the hold start clean, as a fresh process would have them.
func reset_transients() -> void:
	_events.clear()
	_hold = MineHold.new()


## Validation lives HERE rather than in `sim/mining`, per `sim/commands/MODULE.md` ("validation and
## application happen in `interface` and in each target submodule"). `Mining.mine` has its own
## `_workable` check and would simply do nothing for each of these three cases; the difference is that a
## silent no-op is not telemetry. The reasons are what tell a discoverability run the difference between
## an agent that never tried and one that tried and could not reach.
func _apply_mine(cell: Vector2i) -> Result:
	var grid: TileGrid = _world.grid
	if not grid.in_bounds(cell):
		return Result.rejected(REJECT_OUT_OF_BOUNDS)
	if not grid.is_solid(cell):
		return Result.rejected(REJECT_NOT_SOLID)
	if not Mining.in_reach(_body.pos_x, _body.pos_y, cell):
		return Result.rejected(REJECT_OUT_OF_REACH)
	if not LineOfSight.clear(grid, Aim.cell_of(_body.pos_x, _body.pos_y), cell):
		return Result.rejected(REJECT_NO_LINE_OF_SIGHT)   # legacy's `_mineable` gate, integer DDA (D0354)
	_mining.mine(grid, _body.pos_x, _body.pos_y, cell, true)
	_items.yield_break(_mining.broke_cells, _mining.broke_materials)
	_drain_events()
	return Result.accepted()


## Move the item service's flow events onto the consumed channel, so a view observing once a frame
## sees every event of every tick between two observes exactly once.
func _drain_events() -> void:
	if _items.flow_events.is_empty():
		return
	_events.append_array(_items.flow_events)
	_items.flow_events.clear()
