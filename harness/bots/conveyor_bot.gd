class_name ConveyorBot
extends RouteBot

## The scripted T0 policy for `conveyor_probe` scenarios (D0645): the conveyor-discovery claim's
## route -- stand beside a capped bore, dig the cap out from under a resting pile, watch the pile
## ride the dug column down into the forge's intake, then descend and feed it the foreign item that
## jams it. The world does the teaching: `Items.resettle_pile_above` is the conveyor, `Runners.jammed`
## is the consequence, and both land on the observation's own channels (flow events, machine records).
##
## Two leg kinds are this probe's own and live in `_step_custom`, per the base's rule that the shared
## table is what every probe must agree on: `dig` (mine the named metres until nothing solid remains
## in them -- a mine leg whose goal is the HOLE, not the yield) and `toss` (select and drop a stack
## standing still -- a deliver leg with no walk, because the destination is the column underfoot).


func _route(anchor: Vector2i) -> Array:
	var bore: Vector2i = anchor + Vector2i(3, 0)     ## the capped column the pile rests over
	var forge: Vector2i = anchor + Vector2i(3, 7)  ## the jam-variant forge at the bore's foot
	return [
		{"kind": &"walk_to", "col": anchor.x + 4, "slack": 1, "max_row": anchor.y},
		{"kind": &"note", "key": "before", "machines": [forge], "piles": [bore + Vector2i(0, -1)]},
		{"kind": &"dig", "metres": [bore, bore + Vector2i(0, 1)]},
		{"kind": &"await_status", "at": forge, "status": &"working", "timeout_ticks": 120},
		{"kind": &"note", "key": "forge_working", "machines": [forge],
			"piles": [bore + Vector2i(0, -1), forge + Vector2i(0, 1)]},
		{"kind": &"descend", "col": bore.x, "row": forge.y - 1},
		{"kind": &"toss", "item": &"clay", "count": 1},
		{"kind": &"await_status", "at": forge, "status": &"blocked", "timeout_ticks": 120},
		{"kind": &"note", "key": "forge_jammed", "machines": [forge]},
	]


func _step_custom(leg: Dictionary, out: Dictionary) -> int:
	match StringName(leg["kind"]):
		&"dig":
			return _step_dig(out["frame"], leg)
		&"toss":
			return _step_toss(out, leg)
	return 2


## One tick of a dig leg: hold MINE on the named metres' nearest solid cell until none remains -- the
## mine stepper with the yield clause removed; what is left is the hole. Walks toward the aim only
## when it sits past the pick's reach, and NEVER hops: the cap is dug from beside, and a hop at the
## lip is how the walker falls in before the pile does.
func _step_dig(f: InputFrame, leg: Dictionary) -> int:
	var aim: Vector2i = nearest_solid(leg["metres"])
	if aim == Vector2i(-1, -1):
		return 1
	var d_px: int = absi(aim.x * 4 + 2 - body.pos_x / Fx.SCALE)
	_fill(f, signi(aim.x * 4 - body.pos_x / Fx.SCALE) if d_px > 40 else 0, aim, true)
	return 0


## One tick of a toss leg: the deliver stepper's back half -- select the stack, drop it, verify the
## pack shrank by `count`. The dropped units land by the column underfoot, which is the whole point:
## a toss over the dug bore IS feeding the machine at its foot.
func _step_toss(out: Dictionary, leg: Dictionary) -> int:
	match _phase:
		0:
			_drop_before = int(o.pack_total())
			var idx: int = _slot_of(StringName(leg["item"]))
			if idx < 0:
				return 2
			out["commands"].append(Command.select(idx))
			_phase = 1
		1:
			out["commands"].append(Command.drop())
			_phase = 2
		_:
			return 1 if int(o.pack_total()) <= _drop_before - int(leg.get("count", 1)) else 2
	return 0
