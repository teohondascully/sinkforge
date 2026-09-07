extends RefCounted

## THE BURST ENDS WHEN SOMETHING HAPPENS (Astra's testing-loop items 3-4; D0448). A burst of 120 ticks that
## walks past a lesson, a pickup and a refusal comes back with one frame of the end; the agent reads a
## picture of the aftermath and guesses the middle. With `"until": "event"` the seat watches the player-
## visible state the HUD itself draws from -- the rung and its count, the pack, the active lesson, a refusal,
## a landing, a drop -- and cuts the burst at the first change, so the frame is the moment. The observation
## says `ended_by`. Nothing here is sim state the player cannot see; the boundary D0419 drew holds.

const AIRBORNE_TICKS: int = 12    ## a fall this long, then the floor, is a landing worth a frame


## What the player can see that a burst might change. `stack` is the ViewStack; `frame` the current Frame.
static func snapshot(stack: ViewStack, frame: Frame, airborne: int) -> Dictionary:
	var o: Interface.Observation = frame.obs if frame != null else null
	var rung: StringName = stack.objectives.current_id() if stack.objectives != null else &""
	return {
		"rung": rung,
		"progress": stack.objectives.progress(rung) if stack.objectives != null and rung != &"" else "",
		"pack": Payouts.pack_counts(o) if o != null else {},
		"lesson": stack.hints.active_id() if stack.hints != null else &"",
		"refusal": o.aim_refusal if o != null else &"",
		"on_floor": o.on_floor if o != null else true,
		"airborne": airborne,
		"drop": o.drop_went if o != null else &"",
	}


## The first event between two snapshots, in the order a player would name them, or "".
static func fired(prev: Dictionary, now: Dictionary) -> String:
	if now["rung"] != prev["rung"] or now["progress"] != prev["progress"]:
		return "objective"
	if now["pack"] != prev["pack"]:
		return "pack"
	if now["lesson"] != prev["lesson"] and now["lesson"] != &"":
		return "lesson"
	if now["refusal"] != &"" and prev["refusal"] == &"":
		return "refusal"
	if now["drop"] != &"":
		return "drop"
	if now["on_floor"] and not prev["on_floor"] and int(prev["airborne"]) >= AIRBORNE_TICKS:
		return "landing"
	return ""
