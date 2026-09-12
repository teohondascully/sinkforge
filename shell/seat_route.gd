class_name SeatRoute
extends RefCounted

## `--route=cold_start` -- THE PLAYTHROUGH AS AN INSTRUMENT (queue item 44, D0625). Drives the real
## seat through the C003 route one physics tick at a time by asking the same `ColdStartBot` the
## scenario driver runs: one `decide()` per tick, its commands applied to this seat's own door, its
## frame handed back for the seat's `Command.move`. What a headed run under `--route-out=` records is
## therefore the policy's own route through the shipped game -- mining, feeding, collecting,
## delivering -- not a hand-posed approximation of it.
##
## The seat speaks in ticks, the bot was built to own its loop; the decide/apply split is what lets
## one policy serve both. `tick()` takes the pieces it needs rather than `Main` so a suite can drive
## it against a bare `Interface` door and prove the whole translation headless.

const ROUTES: Array[StringName] = [&"cold_start"]
const ROUTE_BUDGET: int = 30000   ## the scenario record's own budget; the seat gets no longer rope

var _bot: ColdStartBot = null
var _frame: InputFrame = InputFrame.new()
var _done: bool = false
var _begun: bool = false


## The route `name` selects, or null (the caller warns). Kept behind a registry rather than
## constructing by string so a typo'd flag fails loudly instead of reaching for a class.
static func build(name: StringName) -> SeatRoute:
	match name:
		&"cold_start":
			var r := SeatRoute.new()
			r._bot = ColdStartBot.new(ROUTE_BUDGET)
			return r
	return null


## One physics tick of the route: attach on first call, then decide, apply the decision's intra-tick
## commands to `door`, and keep the frame for the seat to move on. `obs` should be the seat's OWN last
## rendered observation (`view.current_frame().obs`), not a fresh `observe()` -- the events channel
## clears on every observe, so a second one a tick would starve the view of the events it renders
## (hints, the arrival plate). The policy deciding one tick stale is the honest shape of "the bot
## acts on the picture the player saw". `shot` is invoked with a leg tag ("leg0".."done") whenever a
## leg boundary is crossed -- the seat turns those into the capture strip; a suite passes a recorder.
func tick(door: Interface, shot: Callable = Callable(), obs: Interface.Observation = null) -> void:
	if _done:
		return
	if not _begun:
		_begun = true
		var services: Dictionary = door.services()
		var w: World = services["world"]
		_bot.attach(w, services["items"], services["body"], door,
			Interface.Envelope.oracle_over(w.grid))
		# `pos()` at tick zero IS the dy-0 anchor -- the logic row the feet rest on, which is what
		# `ScenarioDriver.boot` computes as `spawn_air + (0,1)`. Adding the +1 again here aimed every
		# leg a metre too deep (the ore leg survived it because the vein dips below the surface; the
		# coal leg aimed under the seam and mined plain rock until the budget ran out).
		_bot.begin(_bot.pos())
	var d: Dictionary = _bot.decide(obs)
	for c: Command in d["commands"]:
		door.apply(c)
	_frame = d["frame"]
	var fin: int = int(d["finished"])
	if fin >= 0:
		print("seat_route: leg %d %s at tick %d" % [fin,
			"done" if _bot._leg_ok[fin] else "FAILED", _bot.ticks])
		if shot.is_valid():
			shot.call("leg%d" % fin)
	if bool(d["legs_done"]):
		_done = true
		var fails: PackedStringArray = []
		for i: int in _bot._leg_ok.size():
			if not _bot._leg_ok[i]:
				fails.append(str(i))
		print("seat_route: route finished, legs_ok=%s ticks=%d%s" % [fails.is_empty(), _bot.ticks,
			"" if fails.is_empty() else " (failed legs: %s)" % ",".join(fails)])
		if shot.is_valid():
			shot.call("done")


## This tick's frame for `Command.move`. An empty frame once the route is done -- the body idles
## while the seat keeps running, which is also what a finished playthrough looks like.
func frame() -> InputFrame:
	return _frame


func done() -> bool:
	return _done
