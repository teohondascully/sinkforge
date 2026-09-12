class_name DecisionMeter
extends RefCounted

## THE DECISION METER (D0643): counts what a scripted policy's `decide()` emits, binned per
## sim-minute -- the pacing instrument the vision brief's minute-25 question needs ("does the density
## of decisions stay roughly constant as the shaft deepens, or does it thin out?").
##
## A DECISION IS ONE EMITTED PAYLOAD. `decide()` returns `{frame, commands, ...}` once per call and
## the world owes one tick per emission, so a driver that loops `bot.step()` counts at the emission
## point and never has to infer. Every call is a decision -- including the ones that carry nothing:
## an empty frame with no commands is the policy deciding to idle, tagged `idle`, and the per-minute
## `active` count is the signal a flat `decisions` number would hide. This is the honest reading of
## "a bot action issued through the payload path": the count measures the POLICY's activity, never
## the game's pull -- a route that ends emits nothing after it ends, and that cliff is data.
##
## `leg_kind` attributes the tick to a phase so a report can split traversal from digging from
## processing where the payload's own buttons cannot: a body falling down its own hole emits empty
## frames -- zero buttons pressed -- and the ticks still belong to the descent.

const TICKS_PER_MINUTE: int = 3600   ## Body.TICK_HZ (60) * 60 s

## Every tag `classify` can emit, in report order. `hop` covers jump+mantle (the same press here);
## `walk`, `mine`, `dig`, `climb`, `grapple` read the frame's fields; the `cmd_*` tags read each
## Command's kind; `idle` is the tag a payload gets when nothing else applied.
const KIND_ORDER: Array[StringName] = [&"walk", &"hop", &"mine", &"dig", &"climb", &"grapple",
	&"cmd_mine", &"cmd_build", &"cmd_drop", &"cmd_collect", &"cmd_select", &"cmd_configure",
	&"cmd_link_winch", &"cmd_clear_plan", &"idle"]

## leg kind -> the work bucket a pacing report reads. Traversal is relocation (walk, the descent,
## the ascent, hop); digging is the pick (mine and the dedicated dig leg); processing is the line's
## business (feeding, tossing, scooping, waiting on the machine, watching a pile); `note` is
## telemetry, not work -- its ticks are attributed to `observe` so they never masquerade as either.
const BUCKETS: Dictionary = {
	&"": &"idle",
	&"walk_to": &"traversal",
	&"descend": &"traversal",
	&"ascend_rope": &"traversal",
	&"ascend_grapple": &"traversal",
	&"place_rope": &"traversal",
	&"mine": &"digging",
	&"dig": &"digging",
	&"deliver": &"processing",
	&"toss": &"processing",
	&"await": &"processing",
	&"await_pile": &"processing",
	&"collect": &"processing",
	&"note": &"observe",
}

var rows: Array[Dictionary] = []     ## {tick, kinds: Array[StringName], idle: bool, leg: StringName, leg_finished: int}
## World ticks the run spanned, set by the driver at the end (`bot.ticks` -- decisions plus the idle
## ticks a goal watch spends without deciding). The bins need it: a minute with zero decisions still
## exists while the clock ran.
var elapsed_ticks: int = 0


func record(tick: int, payload: Dictionary) -> void:
	var kinds: Array[StringName] = classify(payload)
	rows.append({"tick": tick, "kinds": kinds, "idle": kinds == [&"idle"],
		"leg": StringName(payload.get("leg_kind", "")), "leg_finished": int(payload.get("finished", -1))})


## The action tags one payload carries: every pressed verb, not the one that "won" -- a walk that
## holds MINE is both. The `commands` array rides the same tick: each Command is a tag of its own.
static func classify(payload: Dictionary) -> Array[StringName]:
	var kinds: Array[StringName] = []
	var f: InputFrame = payload["frame"]
	if f.move_dir != 0:
		kinds.append(&"walk")
	if f.jump_held or f.jump_pressed or f.mantle_hold:
		kinds.append(&"hop")
	if f.mine_held:
		kinds.append(&"mine")
	if f.dig_pressed:
		kinds.append(&"dig")
	if f.climb_dir != 0:
		kinds.append(&"climb")
	if f.grapple_pressed:
		kinds.append(&"grapple")
	for c: Command in payload["commands"]:
		match c.kind:
			Command.Kind.MINE:
				kinds.append(&"cmd_mine")
			Command.Kind.BUILD:
				kinds.append(&"cmd_build")
			Command.Kind.DROP:
				kinds.append(&"cmd_drop")
			Command.Kind.COLLECT:
				kinds.append(&"cmd_collect")
			Command.Kind.SELECT:
				kinds.append(&"cmd_select")
			Command.Kind.CONFIGURE:
				kinds.append(&"cmd_configure")
			Command.Kind.LINK_WINCH:
				kinds.append(&"cmd_link_winch")
			Command.Kind.CLEAR_PLAN:
				kinds.append(&"cmd_clear_plan")
	if kinds.is_empty():
		kinds.append(&"idle")
	return kinds


## The bucket a leg kind belongs to (BUCKETS); unknown kinds read as `other` rather than silently
## counted as work.
static func bucket(leg_kind: StringName) -> StringName:
	return BUCKETS.get(leg_kind, &"other")


## The per-minute series plus totals: one bin per 3600-tick sim-minute the run spanned, each bin
## holding decisions (all emissions), active (non-idle), idle, the action-tag histogram, the
## leg-kind histogram, the work-bucket histogram, and the legs that finished inside it.
func report() -> Dictionary:
	var minutes: Array[Dictionary] = []
	var minute_count: int = maxi(1, (elapsed_ticks + TICKS_PER_MINUTE - 1) / TICKS_PER_MINUTE)
	for m: int in minute_count:
		minutes.append({"minute": m, "tick_from": m * TICKS_PER_MINUTE,
			"tick_to": mini((m + 1) * TICKS_PER_MINUTE, elapsed_ticks), "decisions": 0, "active": 0,
			"idle": 0, "kinds": {}, "legs": {}, "buckets": {}, "legs_finished": []})
	var totals: Dictionary = {"decisions": 0, "active": 0, "idle": 0, "kinds": {}, "legs": {}, "buckets": {}}
	for r: Dictionary in rows:
		var m: int = clampi(int(r["tick"]) / TICKS_PER_MINUTE, 0, minutes.size() - 1)
		var bin: Dictionary = minutes[m]
		var b: StringName = bucket(r["leg"])
		bin["decisions"] += 1
		totals["decisions"] += 1
		if bool(r["idle"]):
			bin["idle"] += 1
			totals["idle"] += 1
		else:
			bin["active"] += 1
			totals["active"] += 1
		for k: StringName in r["kinds"]:
			bin["kinds"][k] = int(bin["kinds"].get(k, 0)) + 1
			totals["kinds"][k] = int(totals["kinds"].get(k, 0)) + 1
		if r["leg"] != &"":
			bin["legs"][r["leg"]] = int(bin["legs"].get(r["leg"], 0)) + 1
			totals["legs"][r["leg"]] = int(totals["legs"].get(r["leg"], 0)) + 1
		bin["buckets"][b] = int(bin["buckets"].get(b, 0)) + 1
		totals["buckets"][b] = int(totals["buckets"].get(b, 0)) + 1
		if int(r["leg_finished"]) >= 0:
			(bin["legs_finished"] as Array).append(r["leg_finished"])
	var minutes_elapsed: float = float(maxi(elapsed_ticks, 1)) / float(TICKS_PER_MINUTE)
	totals["decisions_per_minute"] = snappedf(totals["decisions"] / minutes_elapsed, 0.01)
	totals["active_per_minute"] = snappedf(totals["active"] / minutes_elapsed, 0.01)
	return {"ticks": elapsed_ticks, "minutes": minutes, "totals": totals}
