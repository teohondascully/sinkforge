extends SceneTree

## THE INLINED PER-TEXEL TERMS STILL SAY WHAT THE OBVIOUS ONES SAID.
##
## `_air_weight` and `_sky_form` are the two most expensive things in the fine-terrain paint — together
## ~2ms of a 4.4ms dig region, and they run 262144 times on every load. Both were written as readable loops
## that allocated array literals and called a bounds-checking helper per neighbour, and both have been
## rewritten flat: no allocation, no calls, the index arithmetic done in place.
##
## THE ORACLE THAT ALREADY EXISTED DOES NOT COVER THAT CHANGE, and it is worth being exact about why.
## `check_dig_hitch` asserts a region bake is byte-identical to a FULL bake. That is a real and valuable
## property — it is what keeps REGION_MARGIN honest — but both sides of that comparison call these same two
## helpers. Break `_air_weight` uniformly and the region bake and the full bake go wrong together, agree
## perfectly, and the layer stays green. It pins the two PATHS to each other, not either one to the truth.
##
## So the truth has to be written down, and it is written down here the same way check_seam_flood does it:
## the ORIGINAL implementations live in this file as the specification, and the shipped ones are asserted
## equal to them over every cell of a grid built to be hostile —
##
##   BORDERS.   Every cell of the outer ring, where `_fine_air` counts off-grid as AIR. The flat rewrite
##              replaced eight bounds-checked calls with hoisted `lo_x/hi_x/lo_y/hi_y` booleans, and a
##              border cell is the only place that substitution can be wrong.
##   CORNERS.   Where two bounds are out at once, which is where an `or` that should be an `and` hides.
##   AIR/SOLID. A random interior, so the neighbour counting is exercised on every arrangement, not just
##              the all-solid case where every term returns the same number.
##
## Headless: both helpers are pure functions of the fine solid grid and touch no texture, sim or tree.
##
##   godot --headless --path . --script res://tools/check_paint_terms.gd

const W: int = 61                 ## deliberately not a multiple of anything — no lucky alignment
const H: int = 47

var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS: %s" % label)
	else:
		_fails += 1
		printerr("  FAIL: %s" % label)


func _initialize() -> void:
	print("== the inlined per-texel terms still say what the obvious ones said ==")
	_run()
	if _fails == 0:
		print("check_paint_terms: PASS — the flat rewrites agree with the loops they replaced, everywhere")
		quit(0)
	else:
		printerr("check_paint_terms: FAIL (%d)" % _fails)
		quit(1)


func _run() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260817

	# The constructor wants a coarse size and a seed and builds its noise fields; neither term under test
	# reads any of that. The fine dimensions are then overridden to W x H deliberately — they are prime-ish
	# and not multiples of SUBDIV, so no index arithmetic can be right by alignment alone.
	var ft := FineTerrain.new(16, 12, 20260817)
	ft._fcols = W
	ft._frows = H
	var grid := PackedByteArray()
	grid.resize(W * H)
	# A mixed field: mostly solid with scattered air, so both branches of every term are exercised. An
	# all-solid grid would make _air_weight return 0 everywhere and agree with anything.
	for i: int in W * H:
		grid[i] = 0 if rng.randf() < 0.35 else 1
	ft._fine_solid = grid

	var air_bad: int = 0
	var form_bad: int = 0
	var air_border_bad: int = 0
	var air_values: Dictionary = {}
	var form_values: Dictionary = {}
	for fy: int in H:
		for fx: int in W:
			var fast_a: float = ft._air_weight(grid, fx, fy)
			var slow_a: float = _ref_air_weight(ft, grid, fx, fy)
			air_values[fast_a] = true
			if not is_equal_approx(fast_a, slow_a):
				air_bad += 1
				if fx == 0 or fy == 0 or fx == W - 1 or fy == H - 1:
					air_border_bad += 1
			var fast_f: float = ft._sky_form(fx, fy)
			var slow_f: float = _ref_sky_form(ft, fx, fy)
			form_values[snappedf(fast_f, 0.0001)] = true
			if not is_equal_approx(fast_f, slow_f):
				form_bad += 1

	_check(air_bad == 0, "_air_weight agrees with the loop it replaced on all %d cells (%d differ, %d of "
		% [W * H, air_bad, air_border_bad] + "those on the border)")
	_check(form_bad == 0, "_sky_form agrees with the loop it replaced on all %d cells (%d differ)"
		% [W * H, form_bad])

	# NON-VACUITY. Both agreements above hold perfectly if every cell returns the same number — which is
	# exactly what happens on an all-solid grid, and would make this layer a decoration. The terms are
	# supposed to DISCRIMINATE between neighbourhoods, so the spread is asserted rather than assumed.
	_check(air_values.size() >= 8,
		"_air_weight returned %d distinct values, so the comparison had something to disagree about"
			% air_values.size())
	_check(form_values.size() >= 4,
		"_sky_form returned %d distinct values over the same grid" % form_values.size())

	# OFF-GRID COLUMNS, which the sweep above cannot reach. `_sky_form`'s hoisted `oob_x` is only true for
	# an fx outside the grid, and every call in the sweep — like every call in production, which comes from
	# `_paint_fine` — passes one inside it. A mutation deleting that guard therefore stayed GREEN, and the
	# right response was to cover the branch rather than delete it: the reference checks the column on every
	# neighbour read, so dropping it would quietly narrow what `_sky_form` promises to a future caller.
	var oob_bad: int = 0
	for fy: int in H:
		for fx: int in [-3, -1, W, W + 5]:
			if not is_equal_approx(ft._sky_form(fx, fy), _ref_sky_form(ft, fx, fy)):
				oob_bad += 1
	_check(oob_bad == 0,
		"_sky_form agrees off the grid too, where the hoisted column bound is the only thing acting (%d differ)"
			% oob_bad)

	# ...and the off-grid rule itself, stated rather than inferred: outside the grid counts as AIR, so a
	# corner cell of a fully SOLID field still reports its three missing neighbours as open.
	var solid := PackedByteArray()
	solid.resize(W * H)
	solid.fill(1)
	ft._fine_solid = solid
	var corner: float = ft._air_weight(solid, 0, 0)
	_check(is_equal_approx(corner, _ref_air_weight(ft, solid, 0, 0)) and corner > 0.0,
		"on an all-solid grid the (0,0) corner still reads %.1f — off-grid counts as air, as it always did"
			% corner)
	var middle: float = ft._air_weight(solid, W / 2, H / 2)
	_check(is_zero_approx(middle),
		"...while a cell in the middle of solid rock reads 0.0, which is what makes the corner meaningful")


## THE SPECIFICATION: `_air_weight` exactly as it was written before the flattening. Do not optimise this.
func _ref_air_weight(ft: FineTerrain, fine_solid: PackedByteArray, fx: int, fy: int) -> float:
	var w: float = 0.0
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		if _ref_fine_air(ft, fine_solid, fx + d.x, fy + d.y):
			w += 1.0
	for d: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		if _ref_fine_air(ft, fine_solid, fx + d.x, fy + d.y):
			w += 0.5
	return w


## THE SPECIFICATION: `_sky_form` exactly as it was. Do not optimise this.
func _ref_sky_form(ft: FineTerrain, fx: int, fy: int) -> float:
	var f: float = 0.0
	for d: int in range(FineTerrain.FORM_REACH):
		if _ref_fine_air(ft, ft._fine_solid, fx, fy - d - 1):
			f += FineTerrain.FORM_LIFT * (1.0 - float(d) / float(FineTerrain.FORM_REACH))
			break
	for d: int in range(FineTerrain.FORM_REACH):
		if _ref_fine_air(ft, ft._fine_solid, fx, fy + d + 1):
			f -= FineTerrain.FORM_SINK * (1.0 - float(d) / float(FineTerrain.FORM_REACH))
			break
	return f


func _ref_fine_air(ft: FineTerrain, fine_solid: PackedByteArray, fx: int, fy: int) -> bool:
	if fx < 0 or fy < 0 or fx >= ft._fcols or fy >= ft._frows:
		return true
	return fine_solid[fy * ft._fcols + fx] == 0
