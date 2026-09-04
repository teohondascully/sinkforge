extends "res://tests/test_base.gd"

## The real site with every content record on (A' step 8h, D0388): the records agree with each other and
## with the start record stamped onto them, and the generated world carries what each record promises.
## One world generated through the one door a new world comes through; a second through the boot's own
## `Session.new_game`, so the tutorial start is proven to stamp onto the shaped ground.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_shallow_clay_content.gd

const CPM: int = ShaftGenerator.TERRAIN_CELLS_PER_METER
const DATUM: int = ShaftGenerator.SKY_ROWS
const RECORDS: Array[String] = ["relief", "vertical", "studding", "aquifer", "lode", "richness", "tree"]

var _site: Dictionary = StrataData.SHALLOW_CLAY
var _world: World


func _initialize() -> void:
	_world = WorldSeeder.load_world(_site, 20260826)
	_test_the_site_carries_every_record()
	_test_the_pad_the_spawn_and_the_start_agree()
	_test_the_surface_is_flat_on_the_pad_and_shaped_beyond_it()
	_test_the_world_carries_what_the_records_promise()
	_test_no_column_runs_dry()
	_test_no_ore_body_is_a_speck()
	_test_the_tutorial_start_stamps_onto_it()
	_finish("shallow_clay_content")


func _test_the_site_carries_every_record() -> void:
	var missing: Array[String] = []
	for key: String in RECORDS:
		if not _site.has(key):
			missing.append(key)
	_check(missing.is_empty(), "shallow_clay carries every content record (missing: %s)" % str(missing))
	_check(_site.has("spawn_col_m"), "and names its spawn column")


## CONSTANT MUST DOMINATE CONSTANT: three records name the spawn column and the pad must cover the
## tutorial's footprint; asserted here rather than trusted to three comments.
func _test_the_pad_the_spawn_and_the_start_agree() -> void:
	var start: Dictionary = StartsRecords.RECORDS["tutorial"]
	var spawn: int = int(_site.get("spawn_col_m", -1))
	_check(spawn == int(_site["relief"]["pad_centre_m"]) and spawn == int(start["spawn_col_m"]),
		"the site's spawn column, the pad's centre and the tutorial's spawn are one number (%d, %d, %d)"
		% [spawn, int(_site["relief"]["pad_centre_m"]), int(start["spawn_col_m"])])
	var reach: int = 0
	for f: Dictionary in start.get("fixtures", []):
		if f.has("dx"):
			reach = maxi(reach, absi(int(f["dx"])))
		for cell: Array in f.get("cells", []):
			reach = maxi(reach, absi(int(cell[0])))
	_check(int(_site["relief"]["pad_half_m"]) >= reach + 1,
		"the pad's half-width (%d m) covers the tutorial's farthest fixture (%d m) with a metre to spare"
		% [int(_site["relief"]["pad_half_m"]), reach])
	_check(int(_site["tree"]["keepout_m"]) >= int(_site["relief"]["pad_half_m"]), "no tree roots on the pad")
	_check(int(_site["vertical"]["sinkhole"]["keepout_m"]) > int(_site["relief"]["pad_half_m"]), "no mouth opens in it")


func _test_the_surface_is_flat_on_the_pad_and_shaped_beyond_it() -> void:
	var rows: PackedInt32Array = Relief.surface_rows(_site, _world.grid.width, DATUM, CPM)
	var pad: Vector2i = Relief.terrain_pad(_site["relief"], CPM)
	var off_pad: int = 0
	for col: int in range(pad.x, pad.y + 1):
		if rows[col] != DATUM:
			off_pad += 1
	var shaped: int = 0
	for col: int in _world.grid.width:
		if rows[col] != DATUM:
			shaped += 1
	_check(off_pad == 0 and shaped > 100, "the pad is at the datum and %d columns beyond it are not (%d pad columns off)" % [shaped, off_pad])
	# The generated ground is the authored ground, except where a mouth opens it to the sky.
	var mouths: int = 0
	var wrong: int = 0
	for col: int in _world.grid.width:
		if not _world.grid.is_solid(Vector2i(col, rows[col])):
			mouths += 1
		elif rows[col] > 0 and _world.grid.is_solid(Vector2i(col, rows[col] - 1)) \
				and _world.grid.get_material(Vector2i(col, rows[col] - 1)) != &"wood" \
				and _world.grid.get_material(Vector2i(col, rows[col] - 1)) != &"leaves":
			wrong += 1
	_check(mouths > 0 and mouths <= 3 * 30, "%d columns open at the surface: the sinkhole mouths" % mouths)
	_check(wrong == 0, "and above every other column's surface there is sky or a tree (%d rock)" % wrong)


func _test_the_world_carries_what_the_records_promise() -> void:
	var water: int = _world.water.total_water()
	var lodes: int = _world.deposits.lode_terrain_cells().size()
	_check(water > 0, "aquifers: %d water" % water)
	var shallow_water: int = 0
	var floor_row: int = DATUM + int(_site["aquifer"]["min_depth_m"]) * CPM
	for c: Vector2i in _world.water.wet_terrain_cells():
		if c.y < floor_row:
			shallow_water += 1
	_check(shallow_water == 0, "every wet cell at or below the record's %d m (%d above)" % [int(_site["aquifer"]["min_depth_m"]), shallow_water])
	_check(lodes > 0, "lodes: %d cells behind the wall" % lodes)
	var wood: int = 0
	var leaves: int = 0
	for col: int in _world.grid.width:
		for row: int in DATUM + 9 * CPM:
			var m: StringName = _world.grid.get_material(Vector2i(col, row))
			wood += 1 if m == &"wood" else 0
			leaves += 1 if m == &"leaves" else 0
	_check(wood > 0 and leaves > wood, "trees: %d wood and %d leaves over the ground" % [wood, leaves])
	var mouths: int = 0
	var rows: PackedInt32Array = Relief.surface_rows(_site, _world.grid.width, DATUM, CPM)
	for col: int in _world.grid.width:
		if not _world.grid.is_solid(Vector2i(col, rows[col])) and VerticalPasses.drop_below(_world.grid, col, rows[col]) >= 14 * CPM:
			mouths += 1
	_check(mouths > 0, "a mouth falls 14 m or more from the surface (%d columns)" % mouths)


func _test_no_column_runs_dry() -> void:
	var rows: PackedInt32Array = Relief.surface_rows(_site, _world.grid.width, DATUM, CPM)
	var band: int = int(_site["cave"]["min_depth_cells"])
	var limit: int = int(_site["studding"]["drought"]["limit_m"]) * CPM
	var longest: int = 0
	for col: int in _world.grid.width:
		var run: int = 0
		for row: int in range(rows[col] + band, _world.grid.height):
			if StuddingPasses.is_plain(_world.grid, Vector2i(col, row)):
				run += 1
				longest = maxi(longest, run)
			else:
				run = 0
	_check(longest < limit, "no column runs %d m of plain rock (longest %d cells)" % [int(_site["studding"]["drought"]["limit_m"]), longest])


## WG-4's deliverable restated for the content world (D0305): a vein is a place you work, not a speck you
## pass. The rift walls grow metre-square nuggets and the droughts eighty-cell veins, so the median ore
## body stays at least a metre square.
func _test_no_ore_body_is_a_speck() -> void:
	var sizes: Array[int] = _body_sizes(&"ore_copper")
	sizes.sort()
	var median: int = sizes[sizes.size() / 2] if not sizes.is_empty() else 0
	_check(sizes.size() > 0 and median >= CPM * CPM, "the median copper body is at least a metre square (%d cells over %d bodies)" % [median, sizes.size()])


## Four-connected components of `material` in the world.
func _body_sizes(material: StringName) -> Array[int]:
	var sizes: Array[int] = []
	var seen: Dictionary = {}
	var grid: TileGrid = _world.grid
	for col: int in grid.width:
		for row: int in grid.height:
			var start := Vector2i(col, row)
			if seen.has(start) or grid.get_material(start) != material:
				continue
			var size: int = 0
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				size += 1
				for d: Vector2i in PlanePasses.ORTHO:
					var n: Vector2i = c + d
					if not seen.has(n) and grid.get_material(n) == material:
						seen[n] = true
						stack.append(n)
			sizes.append(size)
	return sizes


func _test_the_tutorial_start_stamps_onto_it() -> void:
	var door: Interface = Session.new_game(_site, 20260826, &"tutorial")
	_check(door != null and WorldSeeder.last_refusal.is_empty(), "the boot's own new game stamps the tutorial onto the shaped world (%s)" % WorldSeeder.last_refusal)
