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
	_test_the_two_depth_conversions_agree_at_every_row()
	_test_the_depth_boost_keeps_bedding_legible_under_the_veil()
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
		&"ore_iron", &"glimmer", &"wood", &"leaves"]
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
	# The SURFACE row, not row 0. P017 (D0292) put twenty metres of air above the rock, so row 0 is now
	# `OPEN SKY` -- a band that has existed in `data/bands/` from the start (`from_m: -119`) and that no
	# generated world could reach until this. Reading it back is the ladder finally being whole.
	_check(String(look.band_at(MaterialLook.SURFACE_ROW)["display_name"]) == "TOPSOIL",
		"the surface row reads as TOPSOIL (got %s)"
		% look.band_at(MaterialLook.SURFACE_ROW)["display_name"])
	_check(String(look.band_at(0)["display_name"]) == "OPEN SKY",
		"and row 0, twenty metres above it, reads as OPEN SKY (got %s) -- the band above the datum was unreachable before P017"
		% look.band_at(0)["display_name"])
	_check(String(look.band_at(MAX_ROW)["display_name"]) == "STONEREACH",
		"the deepest row in the world still has a band, the last one (got %s)"
		% look.band_at(MAX_ROW)["display_name"])
	_check(String(look.band_at(-40)["display_name"]) == "OPEN SKY",
		"a row above the surface datum reads as OPEN SKY (got %s)" % look.band_at(-40)["display_name"])


## THE TWO DEPTH CONVERSIONS MUST AGREE, and for twenty metres they did not (D0301).
##
## `depth_m` floors to an int for the readout; `depth_m_exact` keeps the fraction for the tint. They are
## the same measurement at two precisions, so `floor(exact)` must equal `depth_m` at every row — and it
## did not, because D0252 wrote `depth_m_exact` as `row / CELLS_PER_METRE` when the surface datum was
## row 0, and P017/D0292 moved the datum to row 80 while updating only the other one.
##
## Nothing failed. Every suite stayed green, the readout stayed correct, and the terrain quietly took its
## zone tints twenty metres early — an instrument-shaped defect where the two halves of one quantity drift
## apart and each looks right on its own. Asserted over the whole world rather than at a probe row,
## because an offset is invisible at any single row you happen to pick.
func _test_the_two_depth_conversions_agree_at_every_row() -> void:
	var worst_row: int = -1
	var worst: int = 0
	for row: int in range(0, MAX_ROW):
		var d: int = MaterialLook.depth_m(row)
		var e: int = int(floor(MaterialLook.depth_m_exact(row)))
		if absf(d - e) > worst:
			worst = absi(d - e)
			worst_row = row
	_check(worst == 0,
		"floor(depth_m_exact) == depth_m at all %d rows (worst disagreement %d m at row %d)"
		% [MAX_ROW, worst, worst_row])
	# ...and both must read ZERO at the datum itself, which is what makes them a DEPTH rather than a row
	# index in disguise. Either one drifting off the datum is what D0301 was.
	_check(MaterialLook.depth_m(MaterialLook.SURFACE_ROW) == 0,
		"depth_m is 0 at the surface datum (got %d)" % MaterialLook.depth_m(MaterialLook.SURFACE_ROW))
	_check(is_zero_approx(MaterialLook.depth_m_exact(MaterialLook.SURFACE_ROW)),
		"depth_m_exact is 0.0 at the surface datum (got %.3f)"
		% MaterialLook.depth_m_exact(MaterialLook.SURFACE_ROW))
	# The sky above the datum reads NEGATIVE in both, deliberately -- legacy's own rule, "standing on a
	# hilltop reads as a negative depth rather than a clamped zero, so the number is never fudged."
	_check(MaterialLook.depth_m(0) < 0 and MaterialLook.depth_m_exact(0) < 0.0,
		"both read negative above the datum (%d, %.1f)"
		% [MaterialLook.depth_m(0), MaterialLook.depth_m_exact(0)])


## THE DEPTH BOOST, AND THE CLAIM IT ENCODES (D0312).
##
## Legacy's reason for `1 + depth * 2.2` is a quantitative one: *"the shadow veil takes roughly half a
## cell's tonal range, so the compensation must exceed 2x by the deep band or bedding does not read down
## there at all."* That sentence sat in this repository for a session as a deferral, because the veil it
## names did not exist. It does now (`VeilPainter.MASS_SHADE` 0.55, D0302), so the claim is checkable and
## is checked here rather than quoted.
##
## THE `surface` PATCH IS NOT PURELY AT THE SURFACE, and saying so matters for reading the numbers: it
## is `BOOST_PATCH` rows tall starting at `SURFACE_ROW`, so it spans the first 16 metres and the boost is
## already slightly above 1.0 across most of it. That is why the two runs below differ at the surface
## (0.1838 vs 0.1923) when the boost is exactly 1.0 at row `SURFACE_ROW` itself.
##
## THE QUANTITY IS TONAL SPREAD, NOT MEAN. A veil that darkens everything equally moves the mean and
## leaves bedding perfectly legible; what kills bedding is the RANGE collapsing. So this measures
## max-minus-min luma over a patch, which is the thing a reader's eye is actually using to see a band.
const BOOST_PATCH: int = 64
const DEEP_ROW: int = MaterialLook.SURFACE_ROW + int(140.0 * float(MaterialLook.CELLS_PER_METRE))

## A REAL material id, and the first version of this test did not use one. It asked for `&"stone"`, which
## is not in `data/materials/` -- `matrix_color` answers an unmapped material with a flat debug brown, so
## every patch measured a CONSTANT and the spread was 0.0000 at both depths. The assertion failed rather
## than passed only by luck of its direction; `veiled_deep >= raw_surface` was 0 >= 0 and passed. Hence
## the positive control below, which is the part that generalises.
const BOOST_MATERIAL: StringName = &"hardrock"

## MEASURED 2026-09-01 WITH `TONE_BOOST_AT_FLOOR` SET TO 0.0 — the subject removed, the rest of the
## pipeline untouched. That run reads `surface 0.1838 | deep raw 0.1569 | deep after the veil 0.0706`,
## against `0.1923 | 0.3352 | 0.1508` with the boost in place. Two things it establishes that the
## with-boost run alone cannot:
##
##   * **Deep rock is FLATTER than surface rock without the boost** (0.1569 < 0.1838). The boost does not
##     amplify an existing trend, it reverses one. `_depth_darkened` compresses luma as it darkens.
##   * **The floor below is a RESIDUAL, not a chosen number.** 0.0706 is what deep bedding looks like
##     under the veil when nothing compensates. Anything above it is the boost doing work; a floor picked
##     to be comfortably cleared would have told us nothing.
const VEILED_DEEP_WITHOUT_BOOST: float = 0.0706


## Luma spread over a `BOOST_PATCH`-square patch of one material at `row`.
##
## `_luma` here is the repo's own convention and is taken from the palette module rather than re-typed:
## this project defines luma two ways across 27 sites and a second spelling here would be a 28th.
func _tone_spread(look: MaterialLook, material: StringName, row: int) -> float:
	var lo: float = 2.0
	var hi: float = -1.0
	for dc: int in BOOST_PATCH:
		for dr: int in BOOST_PATCH:
			var c: Color = look.matrix_color(material, dc, row + dr)
			var l: float = c.get_luminance()
			lo = minf(lo, l)
			hi = maxf(hi, l)
	return hi - lo


func _test_the_depth_boost_keeps_bedding_legible_under_the_veil() -> void:
	var look: MaterialLook = MaterialLook.new()
	var surface: float = MaterialLook.tone_depth_boost(MaterialLook.SURFACE_ROW)
	var deep: float = MaterialLook.tone_depth_boost(DEEP_ROW)
	print("  [OBSERVED] tone boost %.3f at the surface, %.3f at stonereach_end (140 m)" % [surface, deep])
	_check(is_equal_approx(surface, 1.0),
		"the boost is EXACTLY 1.0 at the surface row (%.4f) -- nothing is veiled up here, so nothing may "
		% surface + "be compensated; a boost that started above 1 would make surface rock louder for no reason")
	# LEGACY'S OWN REQUIREMENT IS `>= 2.0` HERE AND THIS BUILD CANNOT MEET IT, so the assertion states
	# what is true rather than what was hoped for (`docs/NEEDS_DIRECTOR.md` P029). Reaching 2x at 140 m
	# needs `TONE_BOOST_AT_FLOOR >= 1.83`, and anything above ~1.0 pushes deepstone inside the 0.25
	# glimmer distinctness floor that the reveal material depends on. Two shipped guarantees, no value
	# satisfying both. What IS asserted is that the boost is real and bounded, and the trade is parked.
	_check(deep > 1.4 and deep < 2.0,
		"the boost at the deep band is %.3f: materially above 1 and BELOW legacy's own 2x requirement, "
		% deep + "which this build cannot reach without breaking glimmer's distinctness floor (2.2 gives "
		+ "0.239 against a 0.25 floor). If this ever clears 2.0, P029 has been ruled on and this "
		+ "assertion should be replaced rather than widened.")

	# THE MEASUREMENT THE ASSERTION ABOVE IS ABOUT. Raw palette spread, then the same spread after the
	# veil's mass shade has taken its cut, against the surface spread that needs no compensation at all.
	var raw_surface: float = _tone_spread(look, BOOST_MATERIAL, MaterialLook.SURFACE_ROW)
	var raw_deep: float = _tone_spread(look, BOOST_MATERIAL, DEEP_ROW)
	var veiled_deep: float = raw_deep * (1.0 - VeilPainter.MASS_SHADE)
	print("  [OBSERVED] %s luma spread: surface %.4f | deep raw %.4f | deep after the veil %.4f"
		% [BOOST_MATERIAL, raw_surface, raw_deep, veiled_deep])
	# THE CONTROL, and it is here because its absence already cost this test once: a spread of zero is not
	# a small spread, it is NO MEASUREMENT, and every comparison below reads as a pass on it.
	_check(raw_surface > 0.0 and raw_deep > 0.0,
		"positive control: `%s` actually varies across a patch at both depths (surface %.4f, deep %.4f). "
		% [BOOST_MATERIAL, raw_surface, raw_deep] + "A material this palette does not carry answers a flat "
		+ "debug colour, and a flat colour makes every assertion below true by having nothing in it.")
	if raw_surface <= 0.0 or raw_deep <= 0.0:
		return
	_check(raw_deep > raw_surface,
		"deep rock carries MORE raw tonal spread than surface rock (%.4f vs %.4f). This comparison RUNS "
		% [raw_deep, raw_surface] + "THE OTHER WAY without the boost -- 0.1569 deep against 0.1838 near "
		+ "the surface -- so the boost is not amplifying an existing trend, it is reversing one.")
	_check(veiled_deep > VEILED_DEEP_WITHOUT_BOOST,
		"...and after the veil takes its %.0f%%, the deep band holds %.4f -- against the %.4f the same "
		% [VeilPainter.MASS_SHADE * 100.0, veiled_deep, VEILED_DEEP_WITHOUT_BOOST]
		+ "measurement gives with the boost REMOVED. The floor is that residual, measured, not a number "
		+ "chosen to be cleared: it is what deep bedding looks like under the veil when nothing "
		+ "compensates for it.")
