class_name ColdStartBot
extends RouteBot

## The scripted T0 policy for `cold_start` scenarios (D0620) -- a `RouteBot` subclass since D0644,
## when the conveyor and commute probes needed the same decide/apply machinery for different routes.
## The machinery (legs, decide, apply, walk/mine/deliver/await steppers) is all `route_bot.gd`'s;
## this file is only the route.
##
## The route is C003's: mine the tutorial vein, feed the forge, mine coal, feed the forge, collect
## the ingots, deliver them to the rig. Its world reads are the authored fixture positions and the
## solidity of surface cells a standing player can see -- nothing hidden, so a constrained envelope
## would change the window, not the policy.

const ORE_WANT: int = 6    ## smelt_ingot needs 4; margin for the burst's randomness
const COAL_WANT: int = 4   ## needs 2, same reason


func _route(anchor: Vector2i) -> Array:
	var vein: Array = [anchor + Vector2i(-1, 0), anchor + Vector2i(-2, 0)]
	var coal: Array = [anchor + Vector2i(5, 0), anchor + Vector2i(6, 0)]
	var forge_m: Vector2i = anchor + Vector2i(-3, 0)
	var rig_m: Vector2i = anchor + Vector2i(2, 0)
	return [
		{"kind": &"mine", "metres": vein, "want": ORE_WANT, "item": &"ore"},
		{"kind": &"deliver", "at": forge_m, "item": &"ore"},
		{"kind": &"mine", "metres": coal, "want": COAL_WANT, "item": &"coal"},
		{"kind": &"deliver", "at": forge_m, "item": &"coal"},
		{"kind": &"await", "item": &"ingot", "want": 2, "at": forge_m},
		{"kind": &"deliver", "at": rig_m, "item": &"ingot"},
	]
