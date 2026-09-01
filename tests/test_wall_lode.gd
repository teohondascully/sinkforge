extends "res://tests/test_base.gd"

## The mineral mark in the wall plane — legacy's `_draw_lode` ordering, re-expressed at 4px (D0299).
##
## Split out of `tests/test_wall_painter.gd` at the size cap, and at a real seam rather than an arbitrary
## line: that suite is about the CAST (does a hole read as a room), this one is about the MARK (does a
## vein read as ore). They share a painter and share nothing else — no fixture, no world, no observation.
## These assertions need only the palette and the two pure colour functions, which is why the split costs
## nothing (QUALITY §2: meet the cap by splitting, never by trimming the why).
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_wall_lode.gd

## The sweep runs from the surface datum DOWNWARD. An earlier version started at the wall suite's
## `FLOOR_ROW` of 20, which is fifteen metres of sky above the surface: `WallPainter.backs()` returns
## nothing there, so no wall is ever drawn at those rows and the binding case for two of the floors below
## was a colour no player can see. It cost nothing to fix and it was quietly measuring an unreachable row.
const FROM_ROW: int = MaterialLook.SURFACE_ROW
const ROW_SPAN: int = 400   ## ~100 m at CELLS_PER_METRE, past the deepest zone tint's own clamp
const ROW_STEP: int = 32

## Floors RATCHETED to measured behaviour, not guessed (memory: a ratchet is not a bound). Mark-vs-host
## runs 0.29 (coal, the deliberately dark one) to 0.82 (ore_iron) over 1-100 m; retained plane separation
## runs 0.48 (coal) to 0.77 (ore_copper). Both sit below the binding case with room, so a regression trips
## them and ordinary palette work does not.
const MIN_MARK_SEPARATION: float = 0.25
const MIN_PLANE_RETAINED: float = 0.40

## The strip each mean is taken over. Wide enough that a ~10% mark density lands many marks in it, so a
## patch mean is a patch rather than a sample of whichever branch one column fell in.
const STRIP: int = 256


func _initialize() -> void:
	_test_the_mineral_mark_survives_the_wall_plane()
	_test_the_mark_is_untoned_and_the_matrix_beside_it_is_not()
	_test_taking_the_mark_out_of_the_tone_costs_the_plane_a_bounded_amount()
	_finish("wall_lode")

## Materials the palette treats as ore (they carry `nugget_color`) and as country rock (they do not).
## Read from the generated records rather than typed, so a new ore file joins both populations by
## existing — the alternative is a hand list that goes stale exactly when a material is added.


func _ore_and_rock() -> Array:
	var ore: Array[StringName] = []
	var rock: Array[StringName] = []
	for name: StringName in MaterialsRecords.RECORDS:
		var rec: Dictionary = MaterialsRecords.RECORDS[name]
		if not rec.has("base_color"):
			continue
		if rec.has("nugget_color"):
			ore.append(name)
		else:
			rock.append(name)
	return [ore, rock]


## A column where `material` carries the mineral mark at `row`, and one where it carries the matrix.
## Returns -1 for either if the strip holds none, and the callers check that rather than looping over a
## population that may be empty — a "worst separation" over zero pairs is 999.0, which passes every floor.
func _speck_and_matrix_cols(look: MaterialLook, material: StringName, row: int) -> Vector2i:
	var speck: int = -1
	var matrix: int = -1
	for col: int in range(0, STRIP):
		if look.is_speck(material, col, row):
			if speck < 0:
				speck = col
		elif matrix < 0:
			matrix = col
		if speck >= 0 and matrix >= 0:
			break
	return Vector2i(speck, matrix)


func _rgb_dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _mean_over_strip(look: MaterialLook, material: StringName, row: int, wall: bool) -> Color:
	var acc := Vector3.ZERO
	for col: int in range(0, STRIP):
		var c: Color = WallPainter.wall_color(look, material, col, row) if wall \
			else look.cell_color(material, col, row)
		acc += Vector3(c.r, c.g, c.b)
	return Color(acc.x / float(STRIP), acc.y / float(STRIP), acc.z / float(STRIP))


## Legacy's `_draw_lode` (`world_renderer.gd:1194`) draws the ore's grains ON TOP of the finished wall
## plane, and that ordering is the whole point: "the matrix is baked into the wall plane; what is left for
## the live pass is the metal in it". A vein in a mined-out room keeps its mineral colour however far back
## the plane sits, because the recess lands on the rock around the grain and never on the grain.
##
## This grid has no room to draw a grain on a 4px cell, so `MaterialLook.speck_color` makes the CELL the
## mark instead — the argument is written out at `material_look.gd:133-148` and it is the same argument,
## one plane further out. But the mark used to be applied INSIDE `cell_color`, and `wall_color` darkened
## and cooled whatever came out, so the one thing legacy deliberately keeps out of the wall's tone went
## through it.
##
## **THE PAIR IS THE MARK AGAINST ITS OWN MATRIX, and two earlier versions of this test got that wrong.**
## Pooling both branches and asking "does ore differ from rock" compares an ore's own MATRIX against
## country rock — and the matrix IS country rock, deliberately; that version's worst case was coal's
## matrix against deepstone's, 0.006 apart, two dark rocks agreeing correctly. Narrowing to the mark and
## keeping the cross-material comparison then failed on coal's mark against hardrock at 0.116, which is
## also the wrong question: seeing a vein means seeing it against the rock it is IN, and coal's mineral is
## a dark blue-grey on purpose. Legibility is a pair property and the pair is the vein and its host.
## The cross-material figure is still measured, and reported rather than gated.
func _test_the_mineral_mark_survives_the_wall_plane() -> void:
	var look: MaterialLook = MaterialLook.new()
	var pops: Array = _ore_and_rock()
	var ore: Array[StringName] = pops[0]
	var rock: Array[StringName] = pops[1]
	var worst: float = 999.0
	var worst_at: String = ""
	var cross: float = 999.0
	var cross_at: String = ""
	var pairs: int = 0
	for row: int in range(FROM_ROW, FROM_ROW + ROW_SPAN, ROW_STEP):
		for o: StringName in ore:
			var cols: Vector2i = _speck_and_matrix_cols(look, o, row)
			if cols.x < 0 or cols.y < 0:
				continue
			pairs += 1
			var mark: Color = WallPainter.wall_color(look, o, cols.x, row)
			var d: float = _rgb_dist(mark, WallPainter.wall_color(look, o, cols.y, row))
			if d < worst:
				worst = d
				worst_at = "row %d, %s mark %s vs its own matrix" % [row, o, mark.to_html(false)]
			for r: StringName in rock:
				var rc: int = _speck_and_matrix_cols(look, r, row).y
				if rc < 0:
					continue
				var x: float = _rgb_dist(mark, WallPainter.wall_color(look, r, rc, row))
				if x < cross:
					cross = x
					cross_at = "row %d, %s mark vs %s wall" % [row, o, r]
	print("  [OBSERVED] worst MARK-vs-own-matrix separation in the wall plane over %d pairs: %.3f (%s)"
		% [pairs, worst, worst_at])
	print("  [OBSERVED] worst mark-vs-OTHER-rock, reported not gated: %.3f (%s)" % [cross, cross_at])
	_check(pairs >= ore.size(),
		"the comparison actually ran (%d pairs over %d ore materials) -- zero pairs would leave `worst` "
		% [pairs, ore.size()] + "at its 999.0 sentinel and clear this floor by measuring nothing")
	_check(worst >= MIN_MARK_SEPARATION,
		"a vein's mark stays >= %.2f from the rock it sits in, in the wall plane (worst %.3f at %s)"
		% [MIN_MARK_SEPARATION, worst, worst_at])


## The direct statement of the ordering, and the assertion that would have caught this on the day the wall
## painter shipped: the mark is the same colour one plane back as one plane forward, because the wall tone
## is not applied to it. The matrix beside it, at the same row, must still be — that half is what stops
## this passing on a painter that has forgotten to recess anything at all.
func _test_the_mark_is_untoned_and_the_matrix_beside_it_is_not() -> void:
	var look: MaterialLook = MaterialLook.new()
	var ore: Array[StringName] = _ore_and_rock()[0]
	var checked: int = 0
	for row: int in range(FROM_ROW, FROM_ROW + ROW_SPAN, ROW_STEP):
		for o: StringName in ore:
			var cols: Vector2i = _speck_and_matrix_cols(look, o, row)
			if cols.x < 0 or cols.y < 0:
				continue
			checked += 1
			_check(WallPainter.wall_color(look, o, cols.x, row) == look.cell_color(o, cols.x, row),
				"%s's mark at row %d is identical in both planes -- legacy draws the grain over the wall, "
				% [o, row] + "not through it")
			var back: Color = WallPainter.wall_color(look, o, cols.y, row)
			var front: Color = look.cell_color(o, cols.y, row)
			_check(back.get_luminance() < front.get_luminance(),
				"%s's MATRIX at row %d is still recessed behind its own foreground (%s vs %s)"
				% [o, row, back.to_html(false), front.to_html(false)])
	_check(checked >= ore.size(),
		"at least one (mark, matrix) pair was found per ore material (%d over %d) -- a strip holding "
		% [checked, ore.size()] + "neither branch would make both assertions above run zero times")


## The control the separation assertion cannot pass without, and it travels INSIDE the measurement: the
## same strip is meaned twice, once through the painter and once through the formula the painter used
## before the mark was taken out of the tone, and the second is the baseline the first is scored against.
##
## Taking the mark out of the recess necessarily costs the patch some plane separation — that is the trade
## being made, not a side effect, so the assertion bounds the loss rather than denying it. What must NOT
## move is country rock, which has no mark at all: it retains the separation EXACTLY, and that exactness is
## what proves the change is scoped to ore rather than quietly lightening the whole plane. An absolute
## floor was tried first and is the wrong instrument — this palette darkens with depth by design, so a
## fixed RGB distance measures the depth rather than the plane (coal's patch separation is 0.026 at 81 m
## and deepstone, a country rock, is 0.040 at the same row).
func _test_taking_the_mark_out_of_the_tone_costs_the_plane_a_bounded_amount() -> void:
	var look: MaterialLook = MaterialLook.new()
	var pops: Array = _ore_and_rock()
	var worst: float = 9.0
	var worst_at: String = ""
	for row: int in range(FROM_ROW, FROM_ROW + ROW_SPAN, ROW_STEP):
		for o: StringName in pops[0]:
			var retained: float = _plane_separation_retained(look, o, row)
			if retained < worst:
				worst = retained
				worst_at = "row %d, %s" % [row, o]
		for r: StringName in pops[1]:
			_check(is_equal_approx(_plane_separation_retained(look, r, row), 1.0),
				"country rock (%s, row %d) keeps its plane separation EXACTLY -- it carries no mark, so "
				% [r, row] + "any movement here means the recess itself was changed rather than the mark")
	print("  [OBSERVED] worst ore plane-separation retained after the change: %.3f (%s)" % [worst, worst_at])
	_check(worst >= MIN_PLANE_RETAINED,
		"an ore patch keeps >= %.2f of its plane separation (worst %.3f at %s)"
		% [MIN_PLANE_RETAINED, worst, worst_at])


## The patch mean's distance from the foreground, as a fraction of what the pre-change formula gave.
func _plane_separation_retained(look: MaterialLook, material: StringName, row: int) -> float:
	var front := Vector3.ZERO
	var now := Vector3.ZERO
	var before := Vector3.ZERO
	for col: int in range(0, STRIP):
		var f: Color = look.cell_color(material, col, row)
		var n: Color = WallPainter.wall_color(look, material, col, row)
		var b: Color = f.darkened(WallPainter.RECESS).lerp(WallPainter.COOL, WallPainter.COOL_MIX)
		front += Vector3(f.r, f.g, f.b)
		now += Vector3(n.r, n.g, n.b)
		before += Vector3(b.r, b.g, b.b)
	var was: float = (front - before).length()
	if was <= 0.0:
		return 1.0   ## a material the recess never moved cannot have lost anything to this change
	return (front - now).length() / was
