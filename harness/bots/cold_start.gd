class_name ColdStartBot
extends RefCounted

## The scripted T0 policy for `cold_start` scenarios (D0620). Deliberately dumb in the way a T0
## scripted bot should be (this dir's README): it walks toward a named column hopping so the pad's
## wells cannot hold it, aims the mine hold at the nearest solid cell of a named metre, feeds a
## machine by standing in reach and dropping the selected stack, and scoops with COLLECT. The world
## only ever advances inside a MOVE tick, exactly as it does under a player's input -- the mine hold
## rides the frame, so every swing costs real ticks.
##
## The route is C003's: mine the tutorial vein, feed the forge, mine coal, feed the forge, collect
## the ingots, deliver them to the rig. Its world reads are the authored fixture positions and the
## solidity of surface cells a standing player can see -- nothing hidden, so a constrained envelope
## would change the window, not the policy.
##
## DECIDE/APPLY (D0625). `decide()` produces one tick's intent as DATA -- the `InputFrame` the world
## should advance on plus the intra-tick `Command`s (select, drop, collect) that ride it -- and the
## caller applies them. The scenario driver's `execute()` loop applies to its own session door;
## `shell/seat_route.gd` applies them to the real seat's door, so the playthrough a headed capture
## records IS this policy rather than a parallel copy of it. Legs are per-tick steppers with their
## state in fields -- a policy that owns the clock cannot keep a while-loop's stack frame.

var world: World
var items: Items
var body: Body
var iface: Interface
var env: Interface.Envelope
var o: Interface.Observation
var budget: int = 30000
var ticks: int = 0

const ORE_WANT: int = 6    ## smelt_ingot needs 4; margin for the burst's randomness
const COAL_WANT: int = 4   ## needs 2, same reason

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


## Lay the route out against `anchor` and place the leg cursor. Idempotent: the seat calls it once on
## attach, the driver's `execute` calls it at the top of every run.
func begin(anchor: Vector2i, from_leg: int = 0, to_leg: int = -1) -> void:
	var vein: Array = [anchor + Vector2i(-1, 0), anchor + Vector2i(-2, 0)]
	var coal: Array = [anchor + Vector2i(5, 0), anchor + Vector2i(6, 0)]
	var forge_m: Vector2i = anchor + Vector2i(-3, 0)
	var rig_m: Vector2i = anchor + Vector2i(2, 0)
	_legs = [
		{"kind": &"mine", "metres": vein, "want": ORE_WANT, "item": &"ore"},
		{"kind": &"deliver", "at": forge_m, "item": &"ore"},
		{"kind": &"mine", "metres": coal, "want": COAL_WANT, "item": &"coal"},
		{"kind": &"deliver", "at": forge_m, "item": &"coal"},
		{"kind": &"await", "item": &"ingot", "want": 2, "at": forge_m},
		{"kind": &"deliver", "at": rig_m, "item": &"ingot"},
	]
	_leg_last = _legs.size() if to_leg < 0 else mini(to_leg, _legs.size())
	_leg_i = from_leg
	_leg_ok = []
	_leg_ok.resize(_legs.size())
	_leg_ok.fill(true)
	_any_fail = false
	_reset_leg()


## One tick's decision: {frame, commands, finished, legs_done}. `finished` is the index of a leg that
## completed or failed on this tick (for the seat's per-leg capture), `legs_done` is the route over.
## `ticks` counts decisions -- the world owes one tick per decision, which is what makes the count
## mean the same thing in the driver's loop and under the seat's `_physics_process`.
##
## `obs`, when given, is the observation to decide on INSTEAD of observing: `Interface.observe` owns a
## consumed channel (`_events` clears on every call), so the seat hands over the frame it already
## rendered -- the route reads exactly the picture the player was shown, one tick stale, and the
## view's own observe keeps its events. A driver with no view passes nothing and the bot observes.
func decide(obs: Interface.Observation = null) -> Dictionary:
	o = obs if obs != null else iface.observe(env)
	ticks += 1
	var out: Dictionary = {"frame": InputFrame.new(), "commands": [], "finished": -1,
		"legs_done": false}
	if _leg_i >= _leg_last:
		out["legs_done"] = true
		return out
	if ticks >= budget:
		while _leg_i < _leg_last:
			_fail_leg()
		out["legs_done"] = true
		return out
	var state: int = 0   ## 0 still working, 1 done, 2 failed
	var leg: Dictionary = _legs[_leg_i]
	match StringName(leg["kind"]):
		&"mine":
			state = _step_mine(out["frame"], leg)
		&"deliver":
			state = _step_deliver(out, leg)
		&"await":
			state = _step_await(out, leg)
	if state == 1:
		out["finished"] = _leg_i
		_leg_i += 1
		_reset_leg()
	elif state == 2:
		_fail_leg()
		out["finished"] = _leg_i - 1
	out["legs_done"] = _leg_i >= _leg_last
	return out


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


## One tick of a deliver leg: walk level with the machine's row (a drop from a ledge above is out of
## reach even one metre sideways), then select the stack, drop it, and on the following tick require
## the pack to have shrunk -- a drop that was issued but did not land fails the leg, as the old
## `r.ok or pack shrunk` did by refusing to count a refused drop as delivery.
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
