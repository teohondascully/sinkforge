class_name SaveGame
extends RefCounted

## SAVE / LOAD. The sim is PLAIN DATA (node-free dicts + an array of MachineState),
## so a save is a straight capture of its authoritative state into one versioned Dictionary, written
## with Godot's binary Variant serializer (Vector2i keys + StringNames round-trip natively — no JSON
## key-mangling). Machines serialize as def-ID + runtime fields; defs are flyweight .tres reloaded by
## the id↔filename convention. DERIVED/transient state (grid, power, flow_events, terrain_dirty, the
## rate ring buffer, the tick accumulator) is deliberately NOT saved — it's a pure function of the
## authoritative state and rebuilds on the next tick, which is what makes the save format this small.
## Determinism is the verifier: capture → restore → tick both N times → identical signatures
## (tests/_test_save_load). Restore mutates a sim IN PLACE so live references (Player, renderer,
## HUD) stay valid; the caller repaints the view (WorldRenderer.repaint_world).

const VERSION: int = 1
const DEF_DIR: String = "res://src/data/machines/"


## The sim's authoritative state as one plain Dictionary (the envelope). Callers may add their own
## representation keys (e.g. "player_pos") beside these; restore ignores keys it doesn't know.
static func capture(sim: FactorySim) -> Dictionary:
	var machines: Array = []
	for m: MachineState in sim.machines:
		machines.append({
			"def": String(m.def.id), "cell": m.cell,
			"in": m.input_buffer.duplicate(), "out": m.output_buffer.duplicate(),
			"spoil": m.spoil_buffer.duplicate(),
			"progress": m.progress, "route_toggle": m.route_toggle,
			"fuel": m.fuel, "power_factor": m.power_factor, "fed": m.fed,
			"facing": m.facing, "mode": m.mode, "filter": String(m.filter),
		})
	return {
		"version": VERSION,
		"world_seed": sim.world_seed,   # the fine terrain derives from this — restore rebuilds it (not stored)
		"solid": sim.solid.duplicate(),
		"wall": sim.wall.duplicate(),
		"deposits": sim.deposits.duplicate(),
		"lode": sim.lode.duplicate(),
		"inventory": sim.inventory.duplicate(),
		"ground": sim.ground.duplicate(true),
		"sink": sim.sink.duplicate(),
		"produced": sim.total_produced.duplicate(),
		"consumed": sim.total_consumed.duplicate(),
		"conduit": sim.conduit.duplicate(),
		"rope": sim.rope.duplicate(),
		"torch": sim.torch.duplicate(),
		"water": sim.water.duplicate(),
		"fill": sim.fill.duplicate(),
		"research": sim.research.duplicate(),
		"sapling": sim.sapling.duplicate(),
		"machines": machines,
	}


## Load a capture back into `sim` (in place). Refuses an unknown version or a machine whose def no
## longer exists (a save from a different data set) — on refusal the sim is left UNTOUCHED, so a bad
## file can never eat a running game. Returns whether the restore happened.
static func restore(sim: FactorySim, data: Dictionary) -> bool:
	if int(data.get("version", -1)) != VERSION:
		return false
	# Resolve every machine def BEFORE touching the sim (all-or-nothing).
	var rebuilt: Array[MachineState] = []
	for md: Variant in (data.get("machines", []) as Array):
		var entry: Dictionary = md
		var path: String = DEF_DIR + String(entry["def"]) + ".tres"
		if not ResourceLoader.exists(path):
			return false
		var m := MachineState.new(load(path) as MachineDef, entry["cell"])
		m.input_buffer = (entry["in"] as Dictionary).duplicate()
		m.output_buffer = (entry["out"] as Dictionary).duplicate()
		m.spoil_buffer = (entry.get("spoil", {}) as Dictionary).duplicate()   # additive: the rig's 2nd belly
		m.progress = float(entry["progress"])
		m.route_toggle = int(entry["route_toggle"])
		m.fuel = int(entry["fuel"])
		m.power_factor = float(entry["power_factor"])
		m.fed = int(entry["fed"])
		m.facing = int(entry.get("facing", 1))   # additive fields: absent in older v1 saves → defaults
		m.mode = int(entry.get("mode", 0))
		m.filter = StringName(str(entry.get("filter", "")))
		rebuilt.append(m)
	sim.world_seed = int(data.get("world_seed", 0))   # additive: absent in older v1 saves → 0 (default)
	sim.solid = (data["solid"] as Dictionary).duplicate()
	sim.wall = (data["wall"] as Dictionary).duplicate()
	sim.deposits = (data["deposits"] as Dictionary).duplicate()
	sim.lode = (data.get("lode", {}) as Dictionary).duplicate()     # additive: absent in older saves → empty
	sim.inventory = (data["inventory"] as Dictionary).duplicate()
	sim.ground = (data["ground"] as Dictionary).duplicate(true)
	sim.sink = (data["sink"] as Dictionary).duplicate()
	sim.total_produced = (data["produced"] as Dictionary).duplicate()
	sim.total_consumed = (data["consumed"] as Dictionary).duplicate()
	sim.conduit = (data["conduit"] as Dictionary).duplicate()
	sim.rope = (data["rope"] as Dictionary).duplicate()
	sim.torch = (data["torch"] as Dictionary).duplicate()
	sim.water = (data.get("water", {}) as Dictionary).duplicate()   # additive: absent in older saves → empty
	sim.fill = (data.get("fill", {}) as Dictionary).duplicate()     # additive: an older save has no packing
	sim.research = (data["research"] as Dictionary).duplicate()
	sim.sapling = (data.get("sapling", {}) as Dictionary).duplicate()   # additive: absent in older saves
	sim.machines = rebuilt
	sim.grid.clear()
	for m: MachineState in rebuilt:
		sim.grid[m.cell] = m
	# Transient/derived state resets — the next tick rebuilds power; the view drains fresh channels;
	# the bazaar cache rescans the restored terrain.
	sim.power.clear()
	sim.flow_events.clear()
	sim.terrain_dirty.clear()
	sim._bazaars_dirty = true
	# The FINE TERRAIN grid is DERIVED (not saved) — rebuild it deterministically from the restored
	# coarse terrain + seed, so a loaded game molds identically to when it was saved.
	sim.rebuild_fine_terrain()
	return true


## Write an envelope to disk (binary Variant format). Returns success.
static func write(path: String, data: Dictionary) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(data)
	return true


## Read an envelope from disk; {} when missing/unreadable (callers treat {} as "no save").
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var()
	return v if v is Dictionary else {}
