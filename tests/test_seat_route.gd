extends "res://tests/test_base.gd"

## `shell/seat_route.gd` (D0625) -- `--route=cold_start`'s policy half, driven headless against a real
## door. The seat wiring itself is three lines in `shell/main.gd`; what can be PROVEN here is that the
## same `ColdStartBot.decide()` that runs C003's scenario reaches d1 through the seat's own apply
## order -- the route's intra-tick commands land on the door first, then `Command.move(frame)` spends
## the tick -- and that the leg boundary log fires once per leg in order.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_seat_route.gd


func _initialize() -> void:
	_test_the_route_drives_the_seat_s_apply_order_to_d1()
	_test_an_unknown_route_name_is_refused_not_walked()
	_finish("seat_route")


## The loop below is `main.gd`'s own: route.tick, then the move. If a refactor ever reverts the bot
## to owning the clock (an `execute`-style loop that applies its own frames), the seat's copy of the
## order and this suite's copy would both silently stop meaning anything -- so the assertions are on
## OUTCOMES (the leg strip, the d1 event, the tick count), not on calls made.
func _test_the_route_drives_the_seat_s_apply_order_to_d1() -> void:
	var record: Dictionary = ScenarioRecords.RECORDS["cold_start_to_d1"]
	var booted: Dictionary = ScenarioDriver.boot(record)
	_check(bool(booted["ok"]), "control: the scenario's session booted (%s)" % booted["reason"])
	if not bool(booted["ok"]):
		return
	var door: Interface = booted["iface"]
	var route: SeatRoute = SeatRoute.build(&"cold_start")
	_check(route != null, "the cold_start route builds")
	if route == null:
		return
	var shots: Array[String] = []
	var shot: Callable = func(tag: String) -> void: shots.append(tag)
	var goal: Dictionary = record.get("goal", {})
	var want_kind: StringName = StringName(goal.get("type", ""))
	var want_id: StringName = StringName(goal.get("id", ""))
	var goal_seen: bool = false
	var env: Interface.Envelope = booted["env"]
	var sees := func(obs: Interface.Observation) -> bool:
		for ev: Dictionary in obs.events:
			if ev.get("kind") == want_kind and (want_id == &"" or ev.get("id") == want_id):
				return true
		return false
	var t: int = 0
	while t < SeatRoute.ROUTE_BUDGET and not goal_seen:
		# The seat's shape: the policy decides on the observation already taken, then the move spends
		# the tick. Events are a CONSUMED channel (`interface.gd` clears on observe), so the two reads
		# below are the two windows an event can land in -- the pre-tick one the policy saw, and the
		# post-move one that collects what this tick's applies emitted.
		var obs: Interface.Observation = door.observe(env)
		if not route.done():
			route.tick(door, shot, obs)
		goal_seen = goal_seen or sees.call(obs)
		door.apply(Command.move(route.frame()))
		goal_seen = goal_seen or sees.call(door.observe(env))
		t += 1
	_check(route.done(), "every leg of the route finished inside the budget (t=%d)" % t)
	_check(goal_seen, "the rig emitted demand_satisfied %s through the seat's own door" % want_id)
	_check(shots == ["leg0", "leg1", "leg2", "leg3", "leg4", "leg5", "done"],
		"the leg-boundary strip fired once per leg, in order (got %s)" % [shots])


## A mistyped route must not silently become a run: the flag is refused at parse (the same shape as
## `--perf-drive=`'s unknown-name refusal) and `build` returns null rather than a half-route.
func _test_an_unknown_route_name_is_refused_not_walked() -> void:
	_check(SeatRoute.build(&"no_such_route") == null, "an unregistered route builds nothing")
	var f: Dictionary = SeatFlags.parse(PackedStringArray(["--route=no_such_route"]))
	_check(f["route"] == &"", "and the flag stays unset -- the parse refuses it (%s)" % f["route"])
	f = SeatFlags.parse(PackedStringArray(["--route=cold_start", "--route-out=/tmp/r"]))
	_check(f["route"] == &"cold_start" and f["route_out"] == "/tmp/r",
		"while the real one parses with its capture prefix (%s, %s)" % [f["route"], f["route_out"]])
