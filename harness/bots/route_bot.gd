class_name RouteBot
extends RefCounted

## THE SCRIPTED T0 POLICY BASE (D0644): what `ColdStartBot` was before the conveyor and commute
## probes needed the same machinery for different routes. Deliberately dumb in the way a T0 scripted
## bot should be (this dir's README): it walks toward a named column hopping so the pad's wells cannot
## hold it, aims the mine hold at the nearest solid cell of a named metre, feeds a machine by standing
## in reach and dropping the selected stack, and scoops with COLLECT. The world only ever advances
## inside a MOVE tick, exactly as it does under a player's input -- the mine hold rides the frame, so
## every swing costs real ticks.
##
## A subclass supplies THE ROUTE and nothing else: `_route(anchor)` returns the leg array, and any
## leg kind the shared vocabulary does not know falls through `_step_custom` -- leg kinds are verbs
## shared by every probe, routes are policies and belong to the subclass.
##
## DECIDE/APPLY (D0625). `decide()` produces one tick's intent as DATA (the `InputFrame` plus the
## intra-tick `Command`s that ride it) and the caller applies them: `execute()` is the black-box
## loop, `step()` the same pair split open for drivers that want the payload itself (the meter,
## the goal watch). `notes` is the probe's evidence channel -- a `note` leg snapshots observed
## state at a named tick, a read off the bot's own observation, never privileged state.

var world: World
var items: Items
var body: Body
var iface: Interface
var env: Interface.Envelope
var o: Interface.Observation
var budget: int = 30000
var ticks: int = 0
## Evidence checkpoints written by `note` legs: [{tick, key, ...}], read into the run's report.
var notes: Array[Dictionary] = []

## Leg bookkeeping, all reset by `begin`. `_leg_ok[i]` is false only when the leg finished by failing
## (vein out, item missing, drop refused) -- an unfinished leg at budget-out is failed too, which is
## what the old while-loops did by returning false the moment `ticks` reached the budget.
var _legs: Array = []
var _leg_i: int = 0
var _leg_last: int = 0
var _leg_ok: Array = []
var _any_fail: bool = false
## Per-leg working state: the walk's stall detector, `deliver`'s sub-phase, `await`'s scoop timer,
## and the pack total the drop is verified against. `_reset_leg` clears the lot at each transition.
var _stall: int = 0
var _last_x: int = -1
var _phase: int = 0
var _since_scoop: int = 0
var _drop_before: int = 0
var _waited: int = 0
var _entry_y: int = -1                     ## the row a descend leg started on (-1: not taken yet)


func _init(p_budget: int) -> void:
	budget = p_budget


func attach(p_world: World, p_items: Items, p_body: Body, p_iface: Interface, p_env: Interface.Envelope) -> void:
	world = p_world
	items = p_items
	body = p_body
	iface = p_iface
	env = p_env


## The route, legs `from_leg..to_leg` (default: all of it). `anchor` is the fixture's dy-0 logic cell
## (one row under the spawn air metre). The leg range exists for C003's mid-run checkpoint: a fresh bot
## attached to a RESTORED session continues the same route from the leg the save interrupted --
## legs are not pack-idempotent (a delivered stack reads as un-mined), so the seam is the leg index,
## not the world state.
## Returns {legs_ok}: every leg completed inside the budget. Named `execute`, not `run` --
## check_claim_references reads `func run(` as a check-registering file and this is a policy.
func execute(anchor: Vector2i, from_leg: int = 0, to_leg: int = -1) -> Dictionary:
	begin(anchor, from_leg, to_leg)
	while _leg_i < _leg_last and ticks < budget:
		_apply(decide())
	return {"legs_ok": _leg_i >= _leg_last and not _any_fail, "ticks": ticks}


## One decide+apply pair, for drivers that want the emitted payload itself: the decision meter counts
## it, the goal watch reads the observation apply just produced. Exactly `execute`'s loop body.
func step() -> Dictionary:
	var d: Dictionary = decide()
	_apply(d)
	return d


## The route is over when every leg has finished -- the same condition `execute`'s loop exits on.
func legs_done() -> bool:
	return _leg_i >= _leg_last


## Whether every leg finished without a failure -- the `legs_ok` of `execute`'s report.
func legs_ok() -> bool:
	return _leg_i >= _leg_last and not _any_fail


## Lay the route out against `anchor` and place the leg cursor. Idempotent: the seat calls it once on
## attach, the driver's `execute` calls it at the top of every run.
func begin(anchor: Vector2i, from_leg: int = 0, to_leg: int = -1) -> void:
	_legs = _route(anchor)
	_leg_last = _legs.size() if to_leg < 0 else mini(to_leg, _legs.size())
	_leg_i = from_leg
	_leg_ok = []
	_leg_ok.resize(_legs.size())
	_leg_ok.fill(true)
	_any_fail = false
	_reset_leg()


## The subclass's policy: the leg array `begin` lays out. The base has no route -- a bare RouteBot
## finishes immediately, which is the honest answer for "there is nothing to do".
func _route(_anchor: Vector2i) -> Array:
	return []


## One tick's decision: {frame, commands, finished, legs_done, leg_kind}. `finished` is the index
## of a leg that completed or failed on this tick (for the seat's per-leg capture), `legs_done`
## the route over, `leg_kind` the acting leg's kind for telemetry's phase attribution (a falling
## body emits an empty frame and the tick still belongs to the descent).
## `ticks` counts decisions -- the world owes one tick per decision, which is what makes the count
## mean the same thing in the driver's loop and under the seat's `_physics_process`.
##
## `obs`, when given, is decided on INSTEAD of observing: `Interface.observe` owns a consumed
## channel (`_events` clears on every call), so the seat hands over the frame it rendered -- the
## route reads the picture the player saw, one tick stale.
func decide(obs: Interface.Observation = null) -> Dictionary:
	o = obs if obs != null else iface.observe(env)
	ticks += 1
	var out: Dictionary = {"frame": InputFrame.new(), "commands": [], "finished": -1,
		"legs_done": false, "leg_kind": &""}
	if _leg_i >= _leg_last:
		out["legs_done"] = true
		return out
	if ticks >= budget:
		while _leg_i < _leg_last:
			_fail_leg()
		out["legs_done"] = true
		return out
	var leg: Dictionary = _legs[_leg_i]
	out["leg_kind"] = StringName(leg.get("kind", ""))
	var state: int = _step_leg(leg, out)   ## 0 still working, 1 done, 2 failed
	if state == 1:
		out["finished"] = _leg_i
		_leg_i += 1
		_reset_leg()
	elif state == 2:
		_fail_leg()
		out["finished"] = _leg_i - 1
	out["legs_done"] = _leg_i >= _leg_last
	return out


## The shared leg vocabulary. A kind this table does not know goes to `_step_custom` -- shared kinds
## live here so every probe agrees on what a `mine` or a `deliver` IS; probe-only kinds live with the
## probe.
func _step_leg(leg: Dictionary, out: Dictionary) -> int:
	match StringName(leg["kind"]):
		&"mine":
			return _step_mine(out["frame"], leg)
		&"deliver":
			return _step_deliver(out, leg)
		&"await":
			return _step_await(out, leg)
		&"walk_to":
			return 1 if _step_walk(out["frame"], int(leg["col"]), int(leg.get("slack", 1)),
				int(leg.get("max_row", 1 << 30))) else 0
		&"descend":
			return _step_descend(out["frame"], leg)
		&"await_status":
			return _step_await_status(leg)
		&"note":
			_note(leg)
			return 1
	return _step_custom(leg, out)


## The base's answer for an unknown kind: fail the leg. Probes override this to add kinds without
## touching the dispatch.
func _step_custom(_leg: Dictionary, _out: Dictionary) -> int:
	return 2


## An intra-tick command the way the old loop issued it -- select/drop/collect apply to the tick the
## frame then advances, never to a tick of their own.
func _apply(d: Dictionary) -> void:
	for c: Command in d["commands"]:
		iface.apply(c)
	iface.apply(Command.move(d["frame"]))


## One world tick: a MOVE frame walking `dir`, optionally holding MINE on `aim`. `hop` makes the tick
## jump+mantle. Kept for `ScenarioDriver.await_goal`'s idle -- the goal watch spends ticks without
## deciding anything.
func tick(dir: int, aim: Vector2i = Vector2i(-1, -1), mine: bool = false, hop: bool = false) -> void:
	var f: InputFrame = InputFrame.new()
	_fill(f, dir, aim, mine, hop)
	iface.apply(Command.move(f))
	ticks += 1


func _fail_leg() -> void:
	_leg_ok[_leg_i] = false
	_any_fail = true
	_leg_i += 1
	_reset_leg()


func _reset_leg() -> void:
	_stall = 0
	_last_x = -1
	_phase = 0
	_since_scoop = 0
	_drop_before = 0
	_waited = 0
	_entry_y = -1


## The frame's fields, in one place so `tick` and the steppers cannot disagree about what a hop is:
## jump's press edge is held only while the body can leave the floor, and mantle rides the same flag.
func _fill(f: InputFrame, dir: int, aim: Vector2i = Vector2i(-1, -1), mine: bool = false,
		hop: bool = false) -> void:
	f.move_dir = dir
	f.jump_pressed = hop and body.on_floor
	f.jump_held = hop
	f.mantle_hold = hop
	if aim != Vector2i(-1, -1):
		f.has_aim = true
		f.aim_col = aim.x
		f.aim_row = aim.y
	f.mine_held = mine


## One tick of a walk: toward `target_col`, hopping only when the last tick made no forward progress.
## True on arrival -- within `slack` metres of the target, feet at or below `max_row`, on the floor.
func _step_walk(f: InputFrame, target_col: int, slack: int, max_row: int) -> bool:
	var p: Vector2i = pos()
	if absi(p.x - target_col) <= slack and p.y <= max_row and body.on_floor:
		return true
	var px: int = body.pos_x / Fx.SCALE
	_stall = 0 if px != _last_x else _stall + 1
	_last_x = px
	_fill(f, signi(target_col * 16 + 8 - px) if absi(target_col - p.x) > slack else 0,
		Vector2i(-1, -1), false, _stall > 20)
	return false


## One tick of a mine leg: hold MINE aimed at the named metres' nearest solid cell, walking toward it
## when it sits past the reach. Done when the pack holds `want`; failed when the vein is gone.
func _step_mine(f: InputFrame, leg: Dictionary) -> int:
	if carried(StringName(leg["item"])) >= int(leg["want"]):
		return 1
	var aim: Vector2i = nearest_solid(leg["metres"])
	if aim == Vector2i(-1, -1):
		return 2
	var d_px: int = absi(aim.x * 4 + 2 - body.pos_x / Fx.SCALE)
	_fill(f, signi(aim.x * 4 - body.pos_x / Fx.SCALE) if d_px > 40 else 0, aim, true)
	return 0


## One tick of a deliver leg: walk level with the machine's row (a ledge drop is out of reach one
## metre sideways), select the stack, drop it, then require the pack to have shrunk -- a refused
## drop fails the leg rather than counting as delivery.
func _step_deliver(out: Dictionary, leg: Dictionary) -> int:
	var m: Vector2i = leg["at"]
	match _phase:
		0:
			if _step_walk(out["frame"], m.x + 1, 1, m.y + 1):
				_phase = 1
		1:
			_drop_before = int(o.pack_total())
			var idx: int = _slot_of(StringName(leg["item"]))
			if idx < 0:
				return 2
			out["commands"].append(Command.select(idx))
			_phase = 2
		2:
			out["commands"].append(Command.drop())
			_phase = 3
		_:
			return 1 if int(o.pack_total()) < _drop_before else 2
	return 0


## One tick of an await leg: idle beside the source, scooping every ~30 ticks, until the pack holds
## `want`. The seat's own auto-pickup may beat the scoop; either path fills the pack.
func _step_await(out: Dictionary, leg: Dictionary) -> int:
	if carried(StringName(leg["item"])) >= int(leg["want"]):
		return 1
	_since_scoop += 1
	if _since_scoop >= 30:
		out["commands"].append(Command.collect())
		_since_scoop = 0
	var m: Vector2i = leg["at"]
	_fill(out["frame"], signi(m.x + 1 - pos().x))
	return 0


## One tick of a descend leg: steer for `col`'s CENTRE until the body stands at or below `row`.
## Centring by pixel, not cell, is what falls in rather than perching -- a body whose cell reads
## `col` can still straddle the lip, and `signi(col - p.x)` answering 0 there stood the first
## version on the edge forever (D0646). HANDS OFF WHILE FALLING: a pressed direction below the
## rim gives lip cells an edge to catch (the pressed body auto-stepped back OUT and circled), so
## a body airborne below `_entry_y` falls straighter alone; on a floor it steers again, and
## caught ON a lip it steps AWAY from the caught edge (`_lip_escape`). No hop-on-stall: the
## detector's job here would be to climb out of the hole.
func _step_descend(f: InputFrame, leg: Dictionary) -> int:
	var p: Vector2i = pos()
	if p.y >= int(leg["row"]) and p.x == int(leg["col"]) and body.on_floor:
		return 1
	if _entry_y < 0:
		_entry_y = p.y
	var dir: int = 0
	if body.on_floor:
		if p.y > _entry_y and p.y < int(leg["row"]):
			dir = _lip_escape()
		else:
			dir = signi(int(leg["col"]) * 16 + 7 - body.pos_x / Fx.SCALE)
	elif p.y <= _entry_y:
		dir = signi(int(leg["col"]) * 16 + 7 - body.pos_x / Fx.SCALE)
	_fill(f, dir)
	return 0


## Which way to step when a lip caught the body mid-shaft: AWAY from whichever box edge has a
## solid cell under it (measured, probe_conveyor.gd: a one-metre body in a one-metre throat rests
## an edge pixel on the lip -- `on_floor` over open air). Stepping away drops the whole
## underside onto air; stepping toward it is how the leg climbed back out of the bore.
func _lip_escape() -> int:
	var foot_row: int = (body.pos_y + (Body.HEIGHT_PX / 2 + 1) * Fx.SCALE) / Fx.SCALE / 4
	var right := Vector2i((body.pos_x + Body.WIDTH_PX / 2 * Fx.SCALE) / Fx.SCALE / 4, foot_row)
	var left := Vector2i((body.pos_x - Body.WIDTH_PX / 2 * Fx.SCALE) / Fx.SCALE / 4, foot_row)
	if world.grid.in_bounds(right) and world.grid.is_solid(right):
		return -1
	if world.grid.in_bounds(left) and world.grid.is_solid(left):
		return 1
	return -1   ## nothing solid under either edge but the flag still says floor: pick a side


## One tick of an await_status leg: poll the machine records the observation carries for the machine
## at `at`, until its `status` reads the wanted string or `timeout_ticks` (default 600) runs out.
func _step_await_status(leg: Dictionary) -> int:
	for rec: Dictionary in o.machines:
		if rec.get("cell") == leg["at"] and rec.get("status") == StringName(leg["status"]):
			return 1
	_waited += 1
	return 2 if _waited >= int(leg.get("timeout_ticks", 600)) else 0


## The `note` leg's whole job: snapshot the observation into `notes` under `key` -- machine records
## and pile contents at the named cells, with the tick, so a claim cites what the run SAW.
func _note(leg: Dictionary) -> void:
	var entry: Dictionary = {"tick": ticks, "key": String(leg.get("key", "")), "pos": pos(),
		"machines": {}, "piles": {}}
	for c: Vector2i in leg.get("machines", []):
		for rec: Dictionary in o.machines:
			if rec.get("cell") == c:
				(entry["machines"] as Dictionary)[c] = rec.duplicate(true)
	for c: Vector2i in leg.get("piles", []):
		var pile: Dictionary = o.pile_at(c)
		if not pile.is_empty():
			(entry["piles"] as Dictionary)[c] = pile.duplicate()
	notes.append(entry)


## The body's current logic cell.
func pos() -> Vector2i:
	return Vector2i(body.pos_x / Fx.SCALE / 16, (body.pos_y + Body.HEIGHT_PX / 2 * Fx.SCALE) / Fx.SCALE / 16)


## How much of `item` the pack holds, read off the last observation.
func carried(item: StringName) -> int:
	for slot: Dictionary in o.pack:
		if slot["item"] == item:
			return int(slot["count"])
	return 0


## The hotbar index holding `item` (o.pack's order IS the hotbar's), or -1.
func _slot_of(item: StringName) -> int:
	for i: int in o.pack.size():
		if o.pack[i]["item"] == item:
			return i
	return -1


## The solid terrain cell of `metres` nearest the body, or (-1,-1). Nearest-first IS the staircase
## order: it breaks the top/closest cells before the ones behind them.
func nearest_solid(metres: Array) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: int = -1
	for m: Vector2i in metres:
		for ty: int in range(m.y * 4, m.y * 4 + 4):
			for tx: int in range(m.x * 4, m.x * 4 + 4):
				var c := Vector2i(tx, ty)
				if not world.grid.in_bounds(c) or world.grid.get_material(c) == &"":
					continue
				var d: int = absi(tx * 4 + 2 - body.pos_x / Fx.SCALE) + absi(ty * 4 + 2 - body.pos_y / Fx.SCALE)
				if best_d < 0 or d < best_d:
					best_d = d
					best = c
	return best
