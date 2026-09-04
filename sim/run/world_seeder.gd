class_name WorldSeeder
extends RefCounted

## THE ONE DOOR A NEW WORLD COMES THROUGH: generate the shaft, wrap it, stamp the start record, hand
## back the spawn. Lifted in A' step 3h (D0353) from `legacy/scenes/world_seeder.gd` (the procedure)
## and `legacy/src/core/factory_sim.gd` `load_world` 735 (reduced to its one live line: the generator
## writes the `TileGrid` directly now). The fourteen layout constants legacy's procedure read off
## `MainView` are the record (`data/starts/*.yaml`, `StartsRecords`), stamped in file order through the
## sim's own verbs, so the seeded world is deterministic and conservation holds: spawned items are
## counted as produced.
##
## Lives in `sim/run` rather than the plan's `sim/terrain_gen`: stamping places machines and stocks the
## pack, which is above what `terrain_gen` may depend on; `run` sits above all three (D0353).
##
## Every cell in a record is `dx`/`dy` in METRES from (spawn column, the surface row), dy positive down.
## The surface row is the generator's datum, `ShaftGenerator.SKY_ROWS`, in metres.

const SURFACE_ROW_M: int = ShaftGenerator.SKY_ROWS / LogicGrid.TERRAIN_PER_LOGIC
const KINDS: Array[String] = ["solid", "open", "lode", "machine", "pack"]

static var last_refusal: String = ""


## A fresh world from a site record and a seed. Legacy's `load_world`, minus the ingestion the generator
## no longer needs a middleman for.
static func load_world(site: Dictionary, seed: int) -> World:
	var world: World = World.new(ShaftGenerator.generate(site, seed))
	ShaftGenerator.enrich(world, site, seed)   # the planes: aquifers and lodes (A' step 8e, D0385)
	return world


## Stamp the start record `start_id` onto a world. Refuses an unknown record, a record authored for a
## different site (when `site_id` is given), and any fixture that names an unknown kind, material or
## machine or a cell out of bounds -- checked BEFORE anything is stamped, so a bad record leaves the
## world untouched. Returns whether it happened; `last_refusal` says why not.
static func stamp(world: World, items: Items, machines: Machines, start_id: StringName, site_id: StringName = &"") -> bool:
	last_refusal = ""
	if not StartsRecords.RECORDS.has(String(start_id)):
		last_refusal = "unknown start: %s" % start_id
		return false
	var start: Dictionary = StartsRecords.RECORDS[String(start_id)]
	var authored_for: String = str(start.get("site", ""))
	if site_id != &"" and not authored_for.is_empty() and authored_for != String(site_id):
		last_refusal = "start %s is authored for site %s, not %s" % [start_id, authored_for, site_id]
		return false
	return stamp_record(world, items, machines, start)


static func stamp_record(world: World, items: Items, machines: Machines, start: Dictionary) -> bool:
	last_refusal = ""
	var anchor: Vector2i = Vector2i(int(start.get("spawn_col_m", 0)), SURFACE_ROW_M)
	var fixtures: Array = start.get("fixtures", [])
	if not _valid(world, fixtures, anchor):
		return false
	for f: Dictionary in fixtures:
		if not _stamp_one(world, items, machines, f, anchor):
			return false
	return true


## The air metre the body stands in at a new game: above the surface at the spawn column.
static func spawn_logic_cell(start: Dictionary) -> Vector2i:
	return Vector2i(int(start.get("spawn_col_m", 0)), SURFACE_ROW_M - 1)


static func _cells_of(f: Dictionary, anchor: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if str(f.get("kind", "")) == "open":
		for pair: Array in f.get("cells", []):
			out.append(anchor + Vector2i(int(pair[0]), int(pair[1])))
	elif f.has("dx"):
		out.append(anchor + Vector2i(int(f["dx"]), int(f["dy"])))
	return out


static func _valid(world: World, fixtures: Array, anchor: Vector2i) -> bool:
	for f: Variant in fixtures:
		if not (f is Dictionary):
			last_refusal = "a fixture is not a dictionary"
			return false
		var kind: String = str((f as Dictionary).get("kind", ""))
		if not KINDS.has(kind):
			last_refusal = "unknown fixture kind: %s" % kind
			return false
		if kind in ["solid", "lode"] and not WorldMaterials.exists(StringName(str(f.get("material", "")))):
			last_refusal = "unknown material: %s" % str(f.get("material", ""))
			return false
		if kind == "machine" and not MachineDef.exists(StringName(str(f.get("id", "")))):
			last_refusal = "unknown machine: %s" % str(f.get("id", ""))
			return false
		if kind == "pack" and int(f.get("count", 0)) <= 0:
			last_refusal = "pack fixture with no count: %s" % str(f.get("item", ""))
			return false
		for cell: Vector2i in _cells_of(f, anchor):
			if not world.logic_in_bounds(cell):
				last_refusal = "cell out of bounds: %s" % str(cell)
				return false
	return true


static func _stamp_one(world: World, items: Items, machines: Machines, f: Dictionary, anchor: Vector2i) -> bool:
	var cells: Array[Vector2i] = _cells_of(f, anchor)
	match str(f["kind"]):
		"solid":
			var material: StringName = StringName(str(f["material"]))
			world.set_solid(cells[0], material)
			var deposit: int = int(f.get("deposit", 0))
			if deposit > 0 and WorldMaterials.is_ore_like(material):
				for terrain_cell: Vector2i in world.terrain_cells_of(cells[0]):
					world.deposits.set_deposit(terrain_cell, deposit)
		"open":
			for cell: Vector2i in cells:
				world.set_solid(cell, &"")
		"lode":
			for terrain_cell: Vector2i in world.terrain_cells_of(cells[0]):
				world.deposits.seed_lode(terrain_cell, StringName(str(f["material"])), int(f.get("amount", 0)))
		"machine":
			if machines.place(world, MachineDef.of(StringName(str(f["id"]))), cells[0]) == null:
				last_refusal = "machine %s at %s: the cell is not open by then (a record error; the world is part-stamped)" % [str(f["id"]), str(cells[0])]
				return false
		"pack":
			var item: StringName = StringName(str(f["item"]))
			items.pack.add(item, int(f["count"]))
			items.produced(item, int(f["count"]))
	return true
