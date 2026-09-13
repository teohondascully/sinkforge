class_name ScenarioDriver
extends RefCounted

## Loads and runs a scenario record (harness/driver's contract). The record is a generated
## `ScenarioRecords` entry -- the yaml already validated by scenarios/SCHEMA.yaml -- so this file
## never sees a YAML parser; it sees typed fields. `run()` boots the world the record names, hands
## the run to the bot `record.agent` names, then runs idle ticks until the record's goal event shows
## on `o.events` or the budget ends.
##
## What it is not: a fog-filtered run. `envelope: constrained` has no implementation yet (Envelope
## is a spatial window only); the driver reports the envelope it actually used so a claim cannot
## silently read oracle as constrained.

## The report's shape: {ok, reason, ticks_used, goal_event, legs_ok, conservation_error, envelope,
## session} -- `run_metered` adds {decisions, notes}. The phases are public (`boot`, `bot_for`,
## `await_goal`, `match_goal`) so a suite can compose them around a `Session.capture`/`from_save`
## pair -- the save lives in `shell/`, a layer harness may not reach, so a mid-run checkpoint is
## necessarily test-side (D0621). `run` is those pieces composed; the checkpoint leg drives the same
## machinery, not a parallel copy.
static func run(record: Dictionary) -> Dictionary:
	var out: Dictionary = {"ok": false, "reason": "", "ticks_used": 0, "goal_event": {},
		"legs_ok": false, "conservation_error": null, "envelope": &"oracle"}
	var booted: Dictionary = boot(record)
	if not bool(booted["ok"]):
		out["reason"] = booted["reason"]
		return out
	out["session"] = booted["iface"]

	var bot: RouteBot = bot_for(record)
	if bot == null:
		out["reason"] = "no bot registered for agent '%s'" % record.get("agent", "")
		return out
	bot.attach(booted["world"], booted["items"], booted["body"], booted["iface"], booted["env"])
	var rep: Dictionary = bot.execute(booted["anchor"])
	out["legs_ok"] = rep["legs_ok"]
	out["ticks_used"] = rep["ticks"]
	return await_goal(record, out, bot)


## `run` with the decision meter attached (D0643): the same boot, the same bot, but the route loop is
## driven through `bot.step()` so every payload `decide()` emits is counted, and the goal is checked
## on the observation each apply just produced -- a `flow_landed` goal the route lands mid-leg is
## seen here, not lost to the channel `observe()` already drained. The route still runs to completion
## once its goal has been seen: the report wants the whole policy measured, not the first match.
## `observe_to_budget` keeps the clock running to the record's budget after the route ends -- the
## minute-25 question's honest tail: decisions stop, ticks do not.
## The report is `run`'s plus `decisions` (the meter's per-minute series), `notes` (the bot's
## evidence checkpoints), and `flow_events` (every item movement the run produced -- the routing
## claims' evidence channel).
static func run_metered(record: Dictionary, observe_to_budget: bool = false) -> Dictionary:
	var out: Dictionary = {"ok": false, "reason": "", "ticks_used": 0, "goal_event": {},
		"legs_ok": false, "conservation_error": null, "envelope": &"oracle",
		"decisions": {}, "notes": [], "flow_events": []}
	var booted: Dictionary = boot(record)
	if not bool(booted["ok"]):
		out["reason"] = booted["reason"]
		return out
	out["session"] = booted["iface"]
	var bot: RouteBot = bot_for(record)
	if bot == null:
		out["reason"] = "no bot registered for agent '%s'" % record.get("agent", "")
		return out
	bot.attach(booted["world"], booted["items"], booted["body"], booted["iface"], booted["env"])
	bot.begin(booted["anchor"])
	var budget: int = int(record.get("budget_ticks", 30000))
	var meter := DecisionMeter.new()
	var goal_ev: Dictionary = {}
	while not bot.legs_done() and bot.ticks < budget:
		var d: Dictionary = bot.step()
		meter.record(bot.ticks, d)
		var o: Interface.Observation = bot.iface.observe(bot.env)
		(out["flow_events"] as Array).append_array(o.flow_events)
		if goal_ev.is_empty():
			goal_ev = match_goal(record, o)
	while goal_ev.is_empty() and bot.ticks < budget:
		bot.tick(0)
		var o2: Interface.Observation = bot.iface.observe(bot.env)
		(out["flow_events"] as Array).append_array(o2.flow_events)
		goal_ev = match_goal(record, o2)
	if observe_to_budget:
		while bot.ticks < budget:
			bot.tick(0)
	meter.elapsed_ticks = bot.ticks
	out["ticks_used"] = bot.ticks
	out["legs_ok"] = bot.legs_ok()
	out["ok"] = not goal_ev.is_empty()
	out["goal_event"] = goal_ev
	out["decisions"] = meter.report()
	out["notes"] = bot.notes
	out["conservation_error"] = Invariants.check_item_conservation(bot.items, 5)
	out["reason"] = "goal met" if bool(out["ok"]) \
		else "goal event never fired inside %d ticks" % budget
	return out


## The goal half of `run`: idle the world (through the bot's own tick, so a resumed bot drives the
## session it was re-attached to) until the record's event shows on `o.events`, or the budget ends.
static func await_goal(record: Dictionary, out: Dictionary, bot: RouteBot) -> Dictionary:
	var budget: int = int(record.get("budget_ticks", 30000))
	while bot.ticks < budget:
		var o: Interface.Observation = bot.iface.observe(bot.env)
		var ev: Dictionary = match_goal(record, o)
		if not ev.is_empty():
			out["goal_event"] = ev
			out["ok"] = true
			out["reason"] = "goal met"
			out["ticks_used"] = bot.ticks
			out["conservation_error"] = Invariants.check_item_conservation(bot.items, 5)
			return out
		bot.tick(0)
	out["reason"] = "goal event never fired inside %d ticks" % budget
	out["ticks_used"] = bot.ticks
	out["conservation_error"] = Invariants.check_item_conservation(bot.items, 5)
	return out


## Does this observation carry the record's goal? Three channels: `o.events` for the
## machine-lifecycle kinds (`demand_satisfied` with an optional `id`), `o.flow_events` for
## `flow_landed` -- an item routed to a named logic cell -- and `o.machines` for `machine_status`:
## the machine at `cell` reading the named `status`, the jam-claim's end state (D0645). `{}` when
## it does not.
static func match_goal(record: Dictionary, o: Interface.Observation) -> Dictionary:
	var goal: Dictionary = record.get("goal", {})
	var want_kind: StringName = StringName(goal.get("type", ""))
	if want_kind == &"machine_status":
		var mc: Variant = goal.get("cell", null)
		var want_cell: Vector2i = Vector2i(int(mc[0]), int(mc[1])) \
			if mc is Array and mc.size() >= 2 else Vector2i(-1, -1)
		var want_status: StringName = StringName(goal.get("status", ""))
		for rec: Dictionary in o.machines:
			if rec.get("cell") == want_cell and rec.get("status") == want_status:
				var ev: Dictionary = rec.duplicate(true)
				ev["kind"] = &"machine_status"
				return ev
		return {}
	if want_kind == &"flow_landed":
		var want_item: StringName = StringName(goal.get("item", ""))
		var to: Variant = goal.get("to", null)
		var cell: Vector2i = Vector2i(int(to[0]), int(to[1])) \
			if to is Array and to.size() >= 2 else Vector2i(-1, -1)
		for ev: Dictionary in o.flow_events:
			if ev.get("item") == want_item and (cell == Vector2i(-1, -1) or ev.get("to") == cell):
				return {"kind": &"flow_landed", "item": want_item, "from": ev.get("from"),
					"to": ev.get("to"), "count": ev.get("count")}
		return {}
	var want_id: StringName = StringName(goal.get("id", ""))
	for ev: Dictionary in o.events:
		if ev.get("kind") == want_kind and (want_id == &"" or ev.get("id") == want_id):
			return ev
	return {}


## The `agent` field's bot, unattached; null when no bot is registered for it.
static func bot_for(record: Dictionary) -> RouteBot:
	match StringName(record.get("agent", "")):
		&"cold_start":
			return ColdStartBot.new(int(record.get("budget_ticks", 30000)))
		&"conveyor_probe":
			return ConveyorBot.new(int(record.get("budget_ticks", 30000)))
		&"commute":
			return CommuteBot.new(int(record.get("budget_ticks", 30000)))
	return null


## Boot the world a record names. Returns {ok, reason, world, items, machines, iface, env, anchor}.
static func boot(record: Dictionary) -> Dictionary:
	var world_spec: Dictionary = record.get("world", {})
	var site_id: StringName = StringName(world_spec.get("site", ""))
	var site: Dictionary = StrataData.get_site(site_id)
	if site.is_empty():
		return {"ok": false, "reason": "unknown site '%s'" % site_id}
	var start_id: StringName = StringName(world_spec.get("start", ""))
	var start: Dictionary = WorldSeeder.start_record(start_id)
	if start.is_empty():
		return {"ok": false, "reason": "unknown start '%s'" % start_id}

	var world: World = WorldSeeder.load_world(site, int(record.get("seed", 0)))
	var items: Items = Items.new(world)
	var machines: Machines = Machines.new()
	machines.attach_to(items)
	if not WorldSeeder.stamp(world, items, machines, start_id, site_id):
		return {"ok": false, "reason": "start '%s' did not stamp on site '%s'" % [start_id, site_id]}

	var spawn: Vector2i = WorldSeeder.spawn_logic_cell(start)
	# spawn_logic_cell is the AIR metre the body stands in; the fixtures' dy-0 anchor is one logic
	# row under it, so feet rest on the anchor row's top.
	var anchor: Vector2i = spawn + Vector2i(0, 1)
	var body := Body.new(
		Fx.from_int(spawn.x * 16 + 8),
		Fx.from_int(anchor.y * 16) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	var iface := Interface.new(world.grid, body, Mining.new(), world, items, machines)
	return {"ok": true, "reason": "", "world": world, "items": items, "machines": machines,
		"body": body, "iface": iface, "env": Interface.Envelope.oracle_over(world.grid),
		"anchor": anchor}
