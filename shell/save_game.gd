class_name SaveGame
extends RefCounted

## Save and load: ADR 0010. A save is one versioned Dictionary (the envelope) over the world's planes, the
## item service and the machine registry, written with Godot's binary Variant serializer (Vector2i keys
## and StringNames round-trip natively). Lifted in A' step 3g (D0352) from `legacy/src/core/save_game.gd`:
## the transactional stage/commit, the no-default keys, the migration chain that must arrive, the winch
## reconciliation, and the tmp/readback/bak/rename write are legacy's; the keys are this game's.
##
## Restore mutates the caller's `World`, `Items` and `Machines` IN PLACE at the service level: their planes
## are swapped for freshly staged ones, so a holder of the three services stays valid and nothing may
## cache a plane across a load. Derived state (power, flow events, the drop landing) is reset.
##
## Durability: opening the real path for writing truncates the previous save the instant `open` returns,
## so a write encodes to `.tmp`, reads it back and proves it decodes to an envelope, copies the good
## primary to `.bak`, then renames `.tmp` over the slot. The slot holds a complete game at every point.

const VERSION: int = 3
## v3 is this game's first version (ADR 0010 §2): a pre-pivot v2 envelope is refused by name.
const OLDEST_READABLE: int = 3
const SLOT: String = "user://sinkforge.save"
const TMP_SUFFIX: String = ".tmp"
const BAK_SUFFIX: String = ".bak"

const REQUIRED_KEYS: Array[String] = [
	"version", "world_seed", "width", "height", "blocks", "walls", "placed", "water", "deposits",
	"pack", "ground", "sink", "produced", "consumed", "machines",
]
## Fields whose absence would change the world's future and which therefore may not be defaulted: an
## error path that returned the passing value (legacy's own finding).
const NO_DEFAULT_KEYS: Array[String] = ["world_seed", "width", "height"]
const MACHINE_INT_FIELDS: Array[String] = ["progress_ticks", "route_toggle", "fuel", "fed", "mode"]

enum Read { NONE, OK, RECOVERED, CORRUPT }
static var last_read: Read = Read.NONE
static var last_invalid: String = ""


## The authoritative state as one plain Dictionary. Machine cells are not written into `placed`: the
## registry re-registers them on restore (ADR 0010 §5).
static func capture(world: World, items: Items, machines: Machines) -> Dictionary:
	var blocks: Dictionary = {}
	var walls: Dictionary = {}
	for terrain_cell: Vector2i in world.grid.occupied_terrain_cells():
		blocks[terrain_cell] = world.grid.get_material(terrain_cell)
	for terrain_cell: Vector2i in world.grid.wall_terrain_cells():
		walls[terrain_cell] = world.grid.get_wall(terrain_cell)
	var placed: Dictionary = {}
	for cell: Vector2i in world.logic.placed:
		if world.logic.placed[cell] != LogicGrid.KIND_MACHINE:
			placed[cell] = world.logic.placed[cell]
	var saved: Array = []
	for m: MachineState in machines.machines:
		saved.append({
			"def": String(m.def.id), "cell": m.logic_cell,
			"in": m.input_buffer.duplicate(), "out": m.output_buffer.duplicate(),
			"progress_ticks": m.progress_ticks, "route_toggle": m.route_toggle, "fuel": m.fuel,
			"power_permille": m.power_permille, "fed": m.fed, "facing": m.facing, "mode": m.mode,
			"filter": String(m.filter),
		})
	return {
		"version": VERSION,
		"world_seed": world.grid.seed, "width": world.grid.width, "height": world.grid.height,
		"blocks": blocks, "walls": walls, "dig_extent": world.grid.dig_extents(),
		"placed": placed, "conduit_tiers": world.logic.conduit_tiers.duplicate(),
		"sapling": world.logic.sapling.duplicate(),
		"water": world.water.levels.duplicate(),
		"deposits": world.deposits.deposits.duplicate(), "lode": world.deposits.lode.duplicate(),
		"lode_max": world.deposits.lode_max.duplicate(),
		"pack": items.pack.items.duplicate(), "ground": items.piles.ground.duplicate(true),
		"sink": items.piles.sink.duplicate(),
		"produced": items.total_produced.duplicate(), "consumed": items.total_consumed.duplicate(),
		"machines": saved,
		"winch_routes": machines.winch_routes.duplicate(),
		"winch_transit": machines.winch_transit.duplicate(true),
	}


## Cheap structural gate run on anything off disk before it goes near the sim.
static func _valid_envelope(data: Dictionary) -> bool:
	last_invalid = ""
	if data.is_empty():
		last_invalid = "empty"
		return false
	var v: int = int(data.get("version", -1))
	if v == 2:
		last_invalid = "pre-pivot save (v2): the world format changed (ADR 0010)"
		return false
	if v < OLDEST_READABLE or v > VERSION:
		last_invalid = "version %d outside [%d, %d]" % [v, OLDEST_READABLE, VERSION]
		return false
	for key: String in REQUIRED_KEYS:
		if not data.has(key):
			last_invalid = "missing key: %s" % key
			return false
	if not (data["machines"] is Array):
		last_invalid = "machines is not an Array"
		return false
	for key2: String in REQUIRED_KEYS:
		if key2 in ["version", "world_seed", "width", "height", "machines"]:
			if key2 != "machines" and not (data[key2] is int):
				last_invalid = "wrong type: %s" % key2
				return false
			continue
		if not (data[key2] is Dictionary):
			last_invalid = "wrong type: %s" % key2
			return false
	return true


## Carry an older envelope forward as a chain of single-step migrations. Empty today (v3 is the first);
## the next bump appends a branch here, and `_stage` refuses if the chain does not arrive.
static func _migrate(data: Dictionary) -> Dictionary:
	var out: Dictionary = data.duplicate(true)
	out["version"] = int(out.get("version", -1))
	return out


## Validate and build the whole envelope into fresh planes, or {} if anything is wrong, having touched
## nothing live. The half of `restore` that is allowed to fail.
static func _stage(data: Dictionary) -> Dictionary:
	if not _valid_envelope(data):
		return {}
	var env: Dictionary = _migrate(data)
	if int(env.get("version", -1)) != VERSION:
		last_invalid = "migration stopped at version %s -- no branch carries it to %d" % [str(env.get("version", "?")), VERSION]
		return {}
	for key: String in NO_DEFAULT_KEYS:
		if not env.has(key):
			last_invalid = "missing key: %s (no default: its absence would change the world's future)" % key
			return {}
	var world: World = _stage_world(env)
	if world == null:
		return {}
	var items: Items = Items.new(world)
	for item: Variant in (env["pack"] as Dictionary):
		items.pack.add(item, int((env["pack"] as Dictionary)[item]))   # envelope order: the hotbar's
	items.piles.ground = (env["ground"] as Dictionary).duplicate(true)
	items.piles.sink = (env["sink"] as Dictionary).duplicate()
	items.total_produced = (env["produced"] as Dictionary).duplicate()
	items.total_consumed = (env["consumed"] as Dictionary).duplicate()
	var machines: Machines = _stage_machines(env, world)
	if machines == null:
		return {}
	return {"world": world, "items": items, "machines": machines}


static func _stage_world(env: Dictionary) -> World:
	var grid: TileGrid = TileGrid.new(int(env["width"]), int(env["height"]), int(env["world_seed"]))
	# Validated as a whole, then loaded as a whole (D0397): `TileGrid.load_cells` is the per-cell writers'
	# equal at a fifth of their cost, and it runs only over cells already known to be cells.
	var blocks: Dictionary = _cells_typed(env["blocks"], "blocks")
	if blocks.is_empty() and not (env["blocks"] as Dictionary).is_empty():
		return null
	var walls: Dictionary = _cells_typed(env["walls"], "walls")
	if walls.is_empty() and not (env["walls"] as Dictionary).is_empty():
		return null
	grid.load_cells(blocks, walls)
	for col: Variant in (env.get("dig_extent", {}) as Dictionary):
		var span: Vector2i = (env["dig_extent"] as Dictionary)[col]
		grid.extend_terrain_dig_extent(int(col), span.x, span.y)
	var world: World = World.new(grid)
	var tiers: Dictionary = env.get("conduit_tiers", {})
	for cell: Variant in (env["placed"] as Dictionary):
		var kind: StringName = StringName(str((env["placed"] as Dictionary)[cell]))
		if not (cell is Vector2i) or kind == LogicGrid.KIND_MACHINE or not world.logic.occupy(cell, kind, int(tiers.get(cell, 0))):
			last_invalid = "placed: %s at %s refused" % [kind, str(cell)]
			return null
	for cell: Variant in (env.get("sapling", {}) as Dictionary):
		world.logic.plant(cell)
		world.logic.set_sapling_age(cell, int((env["sapling"] as Dictionary)[cell]))
	for terrain_cell: Variant in (env["water"] as Dictionary):
		world.water.set_level(terrain_cell, int((env["water"] as Dictionary)[terrain_cell]))
	var lode: Dictionary = env.get("lode", {})
	var lode_max: Dictionary = env.get("lode_max", {})
	var deposits: Dictionary = env["deposits"]
	for terrain_cell: Variant in lode:
		world.deposits.seed_lode(terrain_cell, StringName(str(lode[terrain_cell])), int(lode_max.get(terrain_cell, deposits.get(terrain_cell, 0))))
	for terrain_cell: Variant in deposits:
		world.deposits.set_deposit(terrain_cell, int(deposits[terrain_cell]))
	return world


## One cell layer of the envelope with every key checked to be a cell and every value a `StringName`;
## {} (with `last_invalid` set) on the first key that is not. A layer that arrives already typed is
## returned as it is rather than copied.
static func _cells_typed(layer: Dictionary, name: String) -> Dictionary:
	var retype: bool = false
	for terrain_cell: Variant in layer:
		if not (terrain_cell is Vector2i):
			last_invalid = "%s: a key is not a cell" % name
			return {}
		if not (layer[terrain_cell] is StringName):
			retype = true
	if not retype:
		return layer
	var out: Dictionary = {}
	for terrain_cell: Vector2i in layer:
		out[terrain_cell] = StringName(str(layer[terrain_cell]))
	return out


static func _stage_machines(env: Dictionary, world: World) -> Machines:
	var machines: Machines = Machines.new()
	for md: Variant in (env["machines"] as Array):
		if not (md is Dictionary) or not ((md as Dictionary).get("cell") is Vector2i):
			last_invalid = "machines: a malformed entry"
			return null
		var entry: Dictionary = md
		var def: MachineDef = MachineDef.of(StringName(str(entry.get("def", ""))))
		if def == null:
			last_invalid = "machines: unknown def %s" % str(entry.get("def", ""))
			return null
		var m: MachineState = machines.place(world, def, entry["cell"], int(entry.get("facing", 1)))
		if m == null:
			last_invalid = "machines: %s at %s cannot be placed there" % [def.id, str(entry["cell"])]
			return null
		m.input_buffer = (entry.get("in", {}) as Dictionary).duplicate()
		m.output_buffer = (entry.get("out", {}) as Dictionary).duplicate()
		for field: String in MACHINE_INT_FIELDS:
			m.set(field, int(entry.get(field, 0)))
		m.power_permille = int(entry.get("power_permille", 1000))
		m.filter = StringName(str(entry.get("filter", "")))
	machines.winch_routes = (env.get("winch_routes", {}) as Dictionary).duplicate()
	machines.winch_transit = (env.get("winch_transit", {}) as Dictionary).duplicate(true)
	return machines


## Swap the staged planes into the live services. Cannot fail: everything is already validated.
static func _commit(world: World, items: Items, machines: Machines, s: Dictionary) -> void:
	var w: World = s["world"]
	world.grid = w.grid
	world.logic = w.logic
	world.water = w.water
	world.deposits = w.deposits
	var it: Items = s["items"]
	items.pack = it.pack
	items.piles = it.piles
	items.total_produced = it.total_produced
	items.total_consumed = it.total_consumed
	items.flow_events.clear()
	items.last_drop_landing = Vector2i(-1, -1)
	machines.adopt_from(s["machines"])
	machines.attach_to(items)


## Load a capture back into the three services, in place. Refuses an unknown version, a malformed
## envelope, or a machine whose def or cell is wrong, leaving everything untouched. Returns whether it
## happened; `last_invalid` says why not.
static func restore(world: World, items: Items, machines: Machines, data: Dictionary) -> bool:
	var staged: Dictionary = _stage(data)
	if staged.is_empty():
		return false
	_commit(world, items, machines, staged)
	_reconcile_winch_routes(items, machines)
	return true


## A well-typed but DANGLING route (an endpoint that no longer holds the expected machine) is a save that
## outlived its machines, not corruption: dropped, not refused. Its cargo in flight is never destroyed:
## it returns to a surviving Head's own input buffer, else spills to the floor at the Head's last cell.
static func _reconcile_winch_routes(items: Items, machines: Machines) -> void:
	for head_cell: Vector2i in Ordering.cells(machines.winch_routes):
		var station_cell: Vector2i = machines.winch_routes[head_cell]
		var head: MachineState = machines.machine_at(head_cell)
		var station: MachineState = machines.machine_at(station_cell)
		var head_ok: bool = head != null and head.def.behavior == &"winch_head"
		var station_ok: bool = station != null and station.def.behavior == &"winch_station"
		if head_ok and station_ok:
			continue
		var cargo: Dictionary = machines.purge_winch_route(head_cell)
		for item: StringName in Ordering.ids(cargo):
			if head_ok:
				head.input_buffer[item] = int(head.input_buffer.get(item, 0)) + int(cargo[item])
			else:
				items.eject(head_cell, item, int(cargo[item]))


## A `--script` fixture may not write the REAL slot: the harness has no isolated user directory, so the
## slot is the player's. Any other path is a scratch path. `SF_REAL_HOME=1` says you mean it.
static func _fixture_may_not_write(path: String) -> bool:
	if path != SLOT or OS.get_environment("SF_REAL_HOME") == "1":
		return false
	var args: PackedStringArray = OS.get_cmdline_args()
	return args.has("--script") or args.has("-s")


## Write an envelope to disk, keeping the previous good save as `<path>.bak`. On any failure the existing
## save is left exactly as it was; every early return removes the temp file.
static func write(path: String, data: Dictionary) -> bool:
	if _fixture_may_not_write(path):
		push_warning("save: REFUSING to write %s from a --script fixture; set SF_REAL_HOME=1 to mean it" % path)
		return false
	var tmp: String = path + TMP_SUFFIX
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("save: cannot open %s (err %d); the existing save is untouched" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_var(data)
	f.close()   # close before reading back: Godot flushes on free
	if not _valid_envelope(_read_file(tmp)):
		push_warning("save: %s did not read back as a valid envelope; the existing save is untouched" % tmp)
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path):
		if _valid_envelope(_read_file(path)):
			var backed: int = DirAccess.copy_absolute(path, path + BAK_SUFFIX)
			if backed != OK:
				push_warning("save: could not preserve %s as a backup (err %d); refusing to promote" % [path, backed])
				DirAccess.remove_absolute(tmp)
				return false
		else:
			push_warning("save: %s is damaged; keeping the existing backup rather than a corrupt primary" % path)
	if DirAccess.rename_absolute(tmp, path) != OK:
		push_warning("save: could not promote %s over %s; the existing save is untouched" % [tmp, path])
		DirAccess.remove_absolute(tmp)
		return false
	return true


## Decode one file, or {} if missing, unreadable or truncated. No validation, no fallback.
static func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var()
	return v if v is Dictionary else {}


## Read an envelope, falling back to the backup if the slot is missing or damaged. `{}` means no game
## to load; `last_read` says why.
static func read(path: String) -> Dictionary:
	var primary: Dictionary = _read_file(path)
	if _valid_envelope(primary):
		last_read = Read.OK
		return primary
	var backup: Dictionary = _read_file(path + BAK_SUFFIX)
	if _valid_envelope(backup):
		push_warning("save: %s is missing or damaged; recovered the previous save from the backup" % path)
		last_read = Read.RECOVERED
		return backup
	last_read = Read.CORRUPT if (FileAccess.file_exists(path) or FileAccess.file_exists(path + BAK_SUFFIX)) else Read.NONE
	return {}
