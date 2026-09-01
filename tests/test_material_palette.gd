extends "res://tests/test_base.gd"

## D0189 (Slice 0). `reveal_scene.gd`'s `COLOR_GLIMMER` constant carried a claim in its own comment:
## deliberately far from the terrain brown and the background near-black, so that "distinct from plain
## rock and from dug space" was "a color-distance claim the renderer actually backs, not just an
## assertion". Slice 0 replaced that constant with a data-driven colour from `data/materials/glimmer.yaml`.
##
## Retiring a constant does not retire its claim. This suite re-establishes it against the records that
## replaced it, and does so over the range where it could actually break rather than at one sample:
## every depth from the surface to the bottom of the world, and BOTH branches of the nugget mask, since
## a material now paints two different colours depending on a per-cell hash.
##
## It also pins the two things Slice 0 must not silently do: change what the sim generates, and let an
## unmapped material vanish.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_material_palette.gd

## The backdrop this palette's colours must stay distinct FROM. Taken from the painter that draws it
## rather than restated (D0276): a colour-distance claim measured against a stale copy of the
## background measures nothing, and it would go stale silently.
const COLOR_BG: Color = BackdropPainter.COLOR_BG
const HOSTS: Array[StringName] = [&"clay", &"hardrock", &"deepstone"]
## The claim's own floor. Legacy authored against WCAG-style ratios; this is a plain RGB euclidean
## distance in 0..1 space, which is what the original comment's "color-distance" meant and what the
## flat cyan actually satisfied. Set from the SUBJECT-REMOVED measurement, not from zero: the two
## host rocks nearest each other in this palette sit at ~0.10, so a glimmer that only cleared 0.10
## would be no more distinct than two rocks are from each other. 0.25 is comfortably above that
## floor and below what the shipped records measure -- printed by the suite so a future change can see
## its own margin rather than only a pass.
const MIN_DISTANCE: float = 0.25
const MAX_ROW: int = 1024  ## max_depth_m 256 * TERRAIN_CELLS_PER_METER 4, the deepest cell that exists


func _initialize() -> void:
	_test_glimmer_stays_distinct_from_every_host_rock_at_every_depth()
	_test_glimmer_stays_distinct_from_the_background_at_every_depth()
	_test_host_rocks_are_distinguishable_from_each_other()
	_test_an_unmapped_material_still_draws()
	_test_every_generated_material_has_an_appearance_record()
	_test_the_palette_is_deterministic_in_cell_coordinates()
	_test_the_band_ladder_is_ordered_and_total()
	_finish("material_palette")


## Both nugget branches at every depth. A single-sample check would pass on the host-coloured branch
## alone and never test the crystal, or vice versa -- the deterministic-fixture failure the ledger
## records (a green that holds fixed the axis the defect varies over).
func _both_branches(look: MaterialLook, material: StringName, row: int) -> Array[Color]:
	var seen: Dictionary = {}
	for col: int in range(0, 64):
		var c: Color = look.cell_color(material, col, row)
		seen[c.to_html(false)] = c
	var out: Array[Color] = []
	for k: String in seen:
		out.append(seen[k])
	return out


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _test_glimmer_stays_distinct_from_every_host_rock_at_every_depth() -> void:
	var look: MaterialLook = MaterialLook.new()
	var worst: float = 999.0
	var worst_at: String = ""
	for row: int in range(0, MAX_ROW, 16):
		for g: Color in _both_branches(look, &"glimmer", row):
			for host: StringName in HOSTS:
				for h: Color in _both_branches(look, host, row):
					var d: float = _dist(g, h)
					if d < worst:
						worst = d
						worst_at = "row %d, glimmer %s vs %s %s" % [row, g.to_html(false), host, h.to_html(false)]
	print("  [OBSERVED] glimmer-vs-rock worst separation over %d rows x both branches: %.3f (%s)"
		% [MAX_ROW / 16, worst, worst_at])
	_check(worst >= MIN_DISTANCE,
		"glimmer stays >= %.2f from every host rock at every depth (worst %.3f at %s)"
		% [MIN_DISTANCE, worst, worst_at])


func _test_glimmer_stays_distinct_from_the_background_at_every_depth() -> void:
	var look: MaterialLook = MaterialLook.new()
	var worst: float = 999.0
	var worst_row: int = -1
	for row: int in range(0, MAX_ROW, 16):
		for g: Color in _both_branches(look, &"glimmer", row):
			var d: float = _dist(g, COLOR_BG)
			if d < worst:
				worst = d
				worst_row = row
	print("  [OBSERVED] glimmer-vs-background worst separation: %.3f at row %d" % [worst, worst_row])
	_check(worst >= MIN_DISTANCE,
		"glimmer stays >= %.2f from the background (dug space) at every depth (worst %.3f at row %d)"
		% [MIN_DISTANCE, worst, worst_row])


## The control that gives the two assertions above a scale. Without it, "glimmer is 0.4 from rock"
## means nothing -- it could be that everything in this palette is 0.4 from everything. Reported, not
## gated: rocks being similar to each other is correct, and is exactly why glimmer needs a higher bar.
func _test_host_rocks_are_distinguishable_from_each_other() -> void:
	var look: MaterialLook = MaterialLook.new()
	var closest: float = 999.0
	var pair: String = ""
	for i: int in HOSTS.size():
		for j: int in range(i + 1, HOSTS.size()):
			for a: Color in _both_branches(look, HOSTS[i], 400):
				for b: Color in _both_branches(look, HOSTS[j], 400):
					var d: float = _dist(a, b)
					if d < closest:
						closest = d
						pair = "%s vs %s" % [HOSTS[i], HOSTS[j]]
	print("  [OBSERVED] closest host-rock pair (the noise floor this palette actually has): %.3f (%s)"
		% [closest, pair])
	_check(closest > 0.0, "the host rocks are not all one colour (closest pair %.3f, %s)" % [closest, pair])


func _test_an_unmapped_material_still_draws() -> void:
	var look: MaterialLook = MaterialLook.new()
	var c: Color = look.cell_color(&"a_material_that_does_not_exist", 3, 3)
	_check(c.a > 0.0 and _dist(c, COLOR_BG) > 0.1,
		"a material with no appearance record falls back to a visible colour rather than vanishing (got %s)"
		% c.to_html(false))


## Slice 0 adds appearance to records the SIM already reads for hardness. If the generator ever emits an
## id with no appearance block, the world silently paints part of itself debug-brown -- a quiet green.
## The population here is the generator's own emitted set, read from source constants, not a list
## retyped here that could drift away from it.
func _test_every_generated_material_has_an_appearance_record() -> void:
	var emitted: Array[StringName] = [&"clay", &"hardrock", &"deepstone", &"ore_copper", &"coal",
		&"ore_iron", &"glimmer"]
	var missing: Array[String] = []
	for id: StringName in emitted:
		var rec: Dictionary = MaterialsRecords.RECORDS.get(id, {})
		if rec.is_empty() or not rec.has("base_color"):
			missing.append(String(id))
	_check(missing.is_empty(),
		"every material ShaftGenerator emits has an appearance record (missing: %s)" % str(missing))
	_check(emitted.size() == MaterialsRecords.RECORDS.size(),
		"the emitted list and data/materials/ hold the same number of records (%d vs %d) -- if these" %
		[emitted.size(), MaterialsRecords.RECORDS.size()] +
		" diverge, either a material was added without appearance or this list went stale")


## The scene redraws every frame; a palette that moved between draws would flicker, and would make the
## Slice 0 screenshot unreproducible.
func _test_the_palette_is_deterministic_in_cell_coordinates() -> void:
	var a: MaterialLook = MaterialLook.new()
	var b: MaterialLook = MaterialLook.new()
	var same: bool = true
	for row: int in range(0, 200, 7):
		for col: int in range(0, 200, 11):
			if a.cell_color(&"ore_copper", col, row) != b.cell_color(&"ore_copper", col, row):
				same = false
	_check(same, "two independent MaterialLook instances paint the same cell identically")


## The ladder must be sorted by depth and must cover every row, including below legacy's own deepest
## band (66 m) -- this world runs to 256 m, four times further than legacy ever authored.
func _test_the_band_ladder_is_ordered_and_total() -> void:
	var look: MaterialLook = MaterialLook.new()
	var last_from: int = -100000
	var ordered: bool = true
	for row: int in range(0, MAX_ROW, 4):
		var band: Dictionary = look.band_at(row)
		if int(band["from_m"]) < last_from:
			ordered = false
		last_from = int(band["from_m"])
	_check(ordered, "band_at() returns a monotonically deepening band as the row increases")
	_check(String(look.band_at(0)["display_name"]) == "TOPSOIL",
		"row 0 reads as TOPSOIL (got %s)" % look.band_at(0)["display_name"])
	_check(String(look.band_at(MAX_ROW)["display_name"]) == "STONEREACH",
		"the deepest row in the world still has a band, the last one (got %s)"
		% look.band_at(MAX_ROW)["display_name"])
	_check(String(look.band_at(-40)["display_name"]) == "OPEN SKY",
		"a row above the surface datum reads as OPEN SKY (got %s)" % look.band_at(-40)["display_name"])
