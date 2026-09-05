class_name Session
extends RefCounted

## THE SESSION, from the shell's side of the door (A' step 4b, D0357): the save's keys the shell adds
## over `SaveGame`'s (the body, the mining state, the plan, the lode work -- ADR 0010 §1's "the caller
## adds"), and the new-game builder. Here and not in `interface/`: the layer lint is right that the door
## may hold neither `SaveGame` (shell) nor the start records (data), and the shell is the one layer
## that may depend on everything (`shell/README.md`). The door hands the shell its services for exactly
## this (`Interface.services`), and nothing above L2 but the shell may take them.

const KEY_BODY: String = "body"
const KEY_MINING: String = "mining"
const KEY_PLAN: String = "plan"
const KEY_LODE: String = "lode_work"
const KEY_SEEN: String = "seen"        ## the map's memory (D0400); absent in a save from before it: nothing seen


## The whole session as one envelope: `SaveGame`'s keys plus the body's, the mining state's, the plan's
## and the lode work's.
static func capture(door: Interface) -> Dictionary:
	var s: Dictionary = door.services()
	var env: Dictionary = SaveGame.capture(s["world"], s["items"], s["machines"])
	env[KEY_BODY] = (s["body"] as Body).capture()
	env[KEY_MINING] = (s["mining"] as Mining).capture()
	env[KEY_PLAN] = (s["plan"] as DigPlan).capture()
	env[KEY_LODE] = (s["lode"] as LodeWork).capture()
	env[KEY_SEEN] = (s["seen"] as SeenPlane).capture()
	return env


## Restore the sim through `SaveGame` (staged, then committed in place), then the session's keys. The
## body is REQUIRED: a save without it is not this session's (there is no truthful default position),
## and it is checked before the sim is touched, so a refusal leaves everything as it was.
static func restore(door: Interface, data: Dictionary) -> bool:
	if not (data.get(KEY_BODY) is Dictionary) or not (data[KEY_BODY] as Dictionary).has("pos_x"):
		SaveGame.last_invalid = "missing key: %s (the session's body; no default position is truthful)" % KEY_BODY
		return false
	var s: Dictionary = door.services()
	if not SaveGame.restore(s["world"], s["items"], s["machines"], data):
		return false
	(s["body"] as Body).restore(data[KEY_BODY])
	(s["mining"] as Mining).restore(data.get(KEY_MINING, {}))
	(s["plan"] as DigPlan).restore(data.get(KEY_PLAN, []))
	(s["lode"] as LodeWork).restore(data.get(KEY_LODE, {}))
	if data.get(KEY_SEEN) is Dictionary:
		(s["seen"] as SeenPlane).restore(data[KEY_SEEN])
	door.reset_transients()
	return true


## A session from a saved envelope, WITHOUT generating the shaft first (D0397): the save carries every
## plane and the body, and `SaveGame.restore` stages a whole world from it and swaps that in -- so a
## generated world under it was 4.7 s of work thrown away on every load. The door is built over an empty
## grid of the save's own dimensions and seed, then restored over; null when the envelope is refused
## (`SaveGame.last_invalid` says why), and the caller falls back to `new_game`.
static func from_save(env: Dictionary) -> Interface:
	if not (env.get("width") is int or env.get("width") is float) or not env.has("height") or not env.has("world_seed"):
		SaveGame.last_invalid = "missing key: width/height/world_seed (no default: its absence would change the world's future)"
		return null
	var grid: TileGrid = TileGrid.new(int(env["width"]), int(env["height"]), int(env["world_seed"]))
	var body: Body = Body.new(0, 0)
	var door: Interface = Interface.new(grid, body, Mining.new())
	if not restore(door, env):
		return null
	return door


## A new game: the shaft generated, the start stamped, the body standing on the spawn. Null when the
## start refuses (`WorldSeeder.last_refusal` says why).
static func new_game(site: Dictionary, seed: int, start_id: StringName) -> Interface:
	var world: World = WorldSeeder.load_world(site, seed)
	var items: Items = Items.new(world)
	var machines: Machines = Machines.new()
	machines.attach_to(items)
	if not WorldSeeder.stamp(world, items, machines, start_id, StringName(str(site.get("id", "")))):
		return null
	var spawn: Vector2i = WorldSeeder.spawn_logic_cell(StartsRecords.RECORDS[String(start_id)])
	var body: Body = Body.new(
		spawn.x * Aim.LOGIC_FX + Aim.LOGIC_FX / 2,
		(spawn.y + 1) * Aim.LOGIC_FX - Body.HEIGHT_PX * Fx.SCALE / 2)
	return Interface.new(world.grid, body, Mining.new(), world, items, machines)
