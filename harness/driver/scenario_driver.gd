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
## session}. The phases are public (`boot`, `bot_for`, `await_goal`) so a suite can compose them
## around a `Session.capture`/`from_save` pair -- the save lives in `shell/`, a layer harness may not
## reach, so a mid-run checkpoint is necessarily test-side (D0621). `run` is those pieces composed;
## the checkpoint leg drives the same machinery, not a parallel copy.
static func run(record: Dictionary) -> Dictionary:
	var out: Dictionary = {"ok": false, "reason": "", "ticks_used": 0, "goal_event": {},
		"legs_ok": false, "conservation_error": null, "envelope": &"oracle"}
	var booted: Dictionary = boot(record)
	if not bool(booted["ok"]):
		out["reason"] = booted["reason"]
		return out
	out["session"] = booted["iface"]

	var bot: ColdStartBot = bot_for(record)
	if bot == null:
		out["reason"] = "no bot registered for agent '%s'" % record.get("agent", "")
		return out
	bot.attach(booted["world"], booted["items"], booted["body"], booted["iface"], booted["env"])
	var rep: Dictionary = bot.execute(booted["anchor"])
	out["legs_ok"] = rep["legs_ok"]
	out["ticks_used"] = rep["ticks"]
	return await_goal(record, out, bot)


## The goal half of `run`: idle the world (through the bot's own tick, so a resumed bot drives the
## session it was re-attached to) until the record's event shows on `o.events`, or the budget ends.
static func await_goal(record: Dictionary, out: Dictionary, bot: ColdStartBot) -> Dictionary:
	var budget: int = int(record.get("budget_ticks", 30000))
	var goal: Dictionary = record.get("goal", {})
	var want_kind: StringName = StringName(goal.get("type", ""))
	var want_id: StringName = StringName(goal.get("id", ""))
	while bot.ticks < budget:
		var o: Interface.Observation = bot.iface.observe(bot.env)
		for ev: Dictionary in o.events:
			if ev.get("kind") == want_kind and (want_id == &"" or ev.get("id") == want_id):
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


## The `agent` field's bot, unattached; null when no bot is registered for it.
static func bot_for(record: Dictionary) -> ColdStartBot:
	match StringName(record.get("agent", "")):
		&"cold_start":
			return ColdStartBot.new(int(record.get("budget_ticks", 30000)))
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
