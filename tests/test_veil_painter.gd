extends "res://tests/test_base.gd"

## `view/visuals/veil_painter.gd` — mass occlusion and the key light (D0302, LEGACY_GAP T1 #2).
##
## Three things have to hold, and they fail independently:
##
##   1. The fast blur is the SAME FIELD legacy's re-summing loop produces. The optimisation is checked
##      against a direct transcription rather than argued from the algebra.
##   2. Burial darkens: a cell deep in mass is dimmer than a cell at a face. That is the half a row
##      gradient can also fake, so it is necessary and not sufficient.
##   3. The KEY separates a floor from a ceiling at the SAME burial depth. That is the half a row gradient
##      cannot fake, and it is the reason this painter exists rather than a depth ramp.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_veil_painter.gd

const CELL: int = Heightfield.TERRAIN_CELL_PX
const GRID_W: int = 96
const GRID_H: int = 96
const ROCK_TOP: int = 24


func _initialize() -> void:
	_test_the_fast_blur_matches_legacys_own_loop()
	_test_the_observation_window_covers_the_veils_reach()
	_test_open_air_is_never_dimmed()
	_test_burial_darkens_and_a_face_barely_does()
	_test_the_key_separates_a_floor_from_a_ceiling_at_equal_burial()
	_test_the_cache_returns_the_same_field_and_misses_when_a_cell_changes()
	_test_the_lamp_opens_the_veil_around_the_miner_and_not_far_from_it()
	_test_the_lamp_is_dimmer_in_daylight_than_in_the_deep()
	_test_the_sky_runs_out_with_depth_and_the_deep_is_genuinely_dark()
	_test_an_incomplete_frame_paints_nothing()
	_finish("veil_painter")


## A world solid from `ROCK_TOP` down, with `dug` excavated.
func _world(dug: Array[Vector2i]) -> Interface.Observation:
	var grid: TileGrid = TileGrid.new(GRID_W, GRID_H, 5)
	for col: int in range(GRID_W):
		for row: int in range(ROCK_TOP, GRID_H):
			grid.set_material(Vector2i(col, row), &"clay")
			grid.set_wall(Vector2i(col, row), &"clay")
	for c: Vector2i in dug:
		grid.excavate(c)
	var body: Body = Body.new(Fx.from_int(GRID_W * CELL / 2), Fx.from_int(4 * CELL))
	var iface: Interface = Interface.new(grid, body, Mining.new())
	var view := Rect2(0.0, 0.0, float(GRID_W * CELL), float(GRID_H * CELL))
	return iface.observe(Interface.Envelope.covering(view, WorldView.WINDOW_MARGIN_CELLS))


## A rectangular chamber, returned with the cells it dug.
func _chamber(x0: int, y0: int, x1: int, y1: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for col: int in range(x0, x1 + 1):
		for row: int in range(y0, y1 + 1):
			out.append(Vector2i(col, row))
	return out


## Legacy's blur, transcribed literally: for every cell, re-sum the whole `2R+1` window, clamped at the
## edges. Slow on purpose — it is the reference, not the shipping path.
func _legacy_openness(obs: Interface.Observation, rect: Rect2i) -> PackedFloat32Array:
	var w: int = rect.size.x
	var h: int = rect.size.y
	var r: int = VeilPainter.REACH_CELLS
	var span: float = float(r * 2 + 1)
	var raw := PackedFloat32Array()
	raw.resize(w * h)
	for row: int in range(h):
		for col: int in range(w):
			var wc: Vector2i = rect.position + Vector2i(col, row)
			wc = Vector2i(clampi(wc.x, 0, obs.world_cells.x - 1), clampi(wc.y, 0, obs.world_cells.y - 1))
			raw[row * w + col] = 0.0 if obs.solid_at(wc) else 1.0
	var blur := PackedFloat32Array()
	blur.resize(w * h)
	for row: int in range(h):
		for col: int in range(w):
			var acc: float = 0.0
			for d: int in range(-r, r + 1):
				acc += raw[row * w + clampi(col + d, 0, w - 1)]
			blur[row * w + col] = acc / span
	var field := PackedFloat32Array()
	field.resize(w * h)
	for col: int in range(w):
		for row: int in range(h):
			var acc: float = 0.0
			for d: int in range(-r, r + 1):
				acc += blur[clampi(row + d, 0, h - 1) * w + col]
			field[row * w + col] = acc / span
	return field


## THE CONTROL THAT MAKES THE OPTIMISATION SAFE. A running-sum box blur and a re-summing one are the same
## field or they are not, and "they are the same by algebra" is the kind of claim that is true right up
## until an edge clamp is off by one — which is exactly where a running sum goes wrong and exactly where
## it would be invisible, because the interior would still be perfect.
func _test_the_fast_blur_matches_legacys_own_loop() -> void:
	var obs: Interface.Observation = _world(_chamber(30, 40, 46, 52) + _chamber(20, 30, 24, 70))
	var rect: Rect2i = obs.window
	var fast: PackedFloat32Array = VeilPainter.openness(obs, rect)
	var slow: PackedFloat32Array = _legacy_openness(obs, rect)
	_check(fast.size() == slow.size() and fast.size() == rect.size.x * rect.size.y,
		"both fields cover the whole window (%d, %d, want %d)"
		% [fast.size(), slow.size(), rect.size.x * rect.size.y])
	var worst: float = 0.0
	var worst_at: int = -1
	var nonzero: int = 0
	for i: int in range(mini(fast.size(), slow.size())):
		if slow[i] > 0.0:
			nonzero += 1
		var d: float = absf(fast[i] - slow[i])
		if d > worst:
			worst = d
			worst_at = i
	print("  [OBSERVED] fast-vs-legacy worst |delta| over %d cells: %.9f (index %d)"
		% [fast.size(), worst, worst_at])
	# The witness: a field that is zero everywhere would match a broken fast path exactly. The fixture
	# digs two chambers precisely so most of the window carries a real, varying value.
	_check(nonzero > fast.size() / 4,
		"the reference field is actually populated (%d of %d cells non-zero) -- an all-zero field would "
		% [nonzero, fast.size()] + "make this comparison pass against any implementation at all")
	_check(worst < 1e-5, "the running-sum blur reproduces legacy's loop (worst delta %.9f)" % worst)


## The scope answer for T1 #2, derived rather than restated — the same discipline `test_wall_painter`
## applies to the AO ramp. If the margin is short, the outermost drawn cells blur against cells the
## observation never handed over, `solid_at` answers false for them, and every screen edge grows a false
## halo of openness that no screenshot settles.
func _test_the_observation_window_covers_the_veils_reach() -> void:
	_check(VeilPainter.REACH_CELLS == int(VeilPainter.MASS_REACH_M) * MaterialLook.CELLS_PER_METRE,
		"the reach is legacy's 2 m in this grid's cells (%d)" % VeilPainter.REACH_CELLS)
	_check(VeilPainter.MARGIN_CELLS == VeilPainter.REACH_CELLS + 1,
		"the dependency is the blur box PLUS the key's one row (%d)" % VeilPainter.MARGIN_CELLS)
	_check(WorldView.WINDOW_MARGIN_CELLS >= VeilPainter.MARGIN_CELLS,
		"the observation margin (%d) covers the veil's reach (%d) -- this is T1 #2's 'window-vs-world "
		% [WorldView.WINDOW_MARGIN_CELLS, VeilPainter.MARGIN_CELLS]
		+ "scope decision', and it is a measurement with a number, not a decision")


## `WallPainter` paints what the wall IS and this decides how lit it is; neither may take the other's job.
## Open air is the boundary between them: the veil must leave it entirely alone, or the two compound and
## legacy's own recorded regression — "a lit chamber came out as a black rectangle" — comes back.
func _test_open_air_is_never_dimmed() -> void:
	var dug: Array[Vector2i] = _chamber(30, 40, 46, 52)
	var obs: Interface.Observation = _world(dug)
	var rect: Rect2i = obs.window
	var field: PackedFloat32Array = VeilPainter.openness(obs, rect)
	var checked: int = 0
	for c: Vector2i in dug:
		var s: float = VeilPainter.shade_at(obs, rect, field,
			c.x - rect.position.x, c.y - rect.position.y)
		checked += 1
		if not is_equal_approx(s, 1.0):
			_check(false, "open cell %s was shaded %.4f -- the veil must not touch air" % [c, s])
			return
	_check(checked == dug.size(), "every one of the %d open cells is left at 1.0" % checked)


func _test_burial_darkens_and_a_face_barely_does() -> void:
	var obs: Interface.Observation = _world(_chamber(30, 40, 46, 52))
	var rect: Rect2i = obs.window
	var field: PackedFloat32Array = VeilPainter.openness(obs, rect)
	# The cell immediately left of the chamber's left wall is a face; one far out in the mass is buried.
	var face: float = VeilPainter.shade_at(obs, rect, field,
		29 - rect.position.x, 46 - rect.position.y)
	var buried: float = VeilPainter.shade_at(obs, rect, field,
		5 - rect.position.x, 46 - rect.position.y)
	print("  [OBSERVED] face %.4f vs buried %.4f (ratio %.2fx)" % [face, buried, face / buried])
	_check(face > buried, "a rock face at an opening is brighter than mass deep behind it (%.4f vs %.4f)"
		% [face, buried])
	# Legacy's own claim about the saturation term: "a cell touching air lands high enough in it that a
	# rock face, which is what you look at when you look at a wall, barely dims at all."
	_check(face > 0.80, "the face BARELY dims, as legacy says it should (%.4f)" % face)
	_check(buried < 1.0 - VeilPainter.MASS_SHADE + 0.05,
		"fully buried mass is at the floor the constant sets (%.4f, floor %.4f)"
		% [buried, 1.0 - VeilPainter.MASS_SHADE])


## THE ASSERTION A ROW GRADIENT CANNOT PASS, and the reason this painter is not a depth ramp. Legacy:
## "a floor and a ceiling at the same burial depth come out at the same brightness and a cavern reads as
## a dark patch rather than as a space with a lit floor and a shadowed roof."
##
## Both probes sit ONE cell into the mass from the same chamber, in the same column, so their burial is
## matched by construction and the only thing that differs is which way the air lies.
func _test_the_key_separates_a_floor_from_a_ceiling_at_equal_burial() -> void:
	var x0: int = 30
	var x1: int = 46
	var y0: int = 40
	var y1: int = 52
	var obs: Interface.Observation = _world(_chamber(x0, y0, x1, y1))
	var rect: Rect2i = obs.window
	var field: PackedFloat32Array = VeilPainter.openness(obs, rect)
	var mid: int = (x0 + x1) / 2
	# The chamber FLOOR: solid, air directly above it -> up-facing.
	var floor_row: int = y1 + 1
	# The chamber CEILING: solid, air directly below it -> an overhang.
	var ceil_row: int = y0 - 1
	var lit_floor: float = VeilPainter.shade_at(obs, rect, field,
		mid - rect.position.x, floor_row - rect.position.y)
	var dark_ceiling: float = VeilPainter.shade_at(obs, rect, field,
		mid - rect.position.x, ceil_row - rect.position.y)
	var f_open: float = field[(floor_row - rect.position.y) * rect.size.x + (mid - rect.position.x)]
	var c_open: float = field[(ceil_row - rect.position.y) * rect.size.x + (mid - rect.position.x)]
	print("  [OBSERVED] floor %.4f (openness %.4f) vs ceiling %.4f (openness %.4f)"
		% [lit_floor, f_open, dark_ceiling, c_open])
	# The control that makes the comparison mean what it says: matched burial. If the two openness values
	# differed, the brightness gap could be burial rather than facing and the key would be unmeasured.
	_check(absf(f_open - c_open) < 0.02,
		"the two probes are at MATCHED burial (openness %.4f vs %.4f) -- otherwise this measures depth, "
		% [f_open, c_open] + "which is the exact confound the key exists to separate from")
	_check(lit_floor > dark_ceiling,
		"the chamber FLOOR is lit and its CEILING is shadowed at equal burial (%.4f vs %.4f) -- light in "
		% [lit_floor, dark_ceiling] + "a mine comes down")
	_check(lit_floor / dark_ceiling > 1.10,
		"...and by a margin a viewer can see (%.2fx)" % (lit_floor / dark_ceiling))


## A cache is a claim that two things are equal, and the way a cache fails is by being WRONG rather than
## by being slow — so both halves are asserted: a hit returns exactly what a fresh bake returns, and a
## world that changed by ONE CELL misses. The second is the one that matters: a key that answered "same"
## after a dig would freeze the veil, and the picture would look entirely plausible, just stale.
func _test_the_cache_returns_the_same_field_and_misses_when_a_cell_changes() -> void:
	var painter: VeilPainter = VeilPainter.new()
	var obs: Interface.Observation = _world(_chamber(30, 40, 46, 52))
	var first: PackedFloat32Array = painter.field_for(obs)
	var second: PackedFloat32Array = painter.field_for(obs)
	var fresh: PackedFloat32Array = VeilPainter.openness(obs, obs.window)
	_check(second == fresh, "a cache HIT returns exactly what a fresh bake returns")
	_check(first == fresh, "...and so did the miss that filled it")

	# One more cell dug, everything else identical. The field must change and the cache must not serve
	# the old one. Compared against a fresh bake of the NEW world, so this cannot pass by returning
	# anything at all -- it has to return the right thing.
	var wider: Array[Vector2i] = _chamber(30, 40, 46, 52)
	wider.append(Vector2i(29, 46))
	var moved: Interface.Observation = _world(wider)
	var after: PackedFloat32Array = painter.field_for(moved)
	var fresh_after: PackedFloat32Array = VeilPainter.openness(moved, moved.window)
	_check(after == fresh_after, "after one cell is dug the cache MISSES and re-bakes correctly")
	_check(after != fresh, "...and the field genuinely differs, so the previous line is not vacuous")


## THE SKYLIGHT CEILING (D0332), and the gap it closes. `MASS_SHADE` is a purely LOCAL quantity — how
## buried a cell is relative to an opening — so before this a buried cell two metres down and one two
## hundred metres down came out at exactly the same brightness, and the underground read as evenly lit at
## every depth. A capture at 7 m showed it: legible everywhere, dark nowhere.
##
## Asserted as a MONOTONE FALL to a floor, not at picked depths, because the shape is the claim: a ceiling
## that dropped and then recovered, or that dropped in one step, would satisfy a two-point check.
func _test_the_sky_runs_out_with_depth_and_the_deep_is_genuinely_dark() -> void:
	var surface_row: int = MaterialLook.SURFACE_ROW
	var previous: float = 2.0
	var checked: int = 0
	var monotone: int = 0
	for m: int in range(0, 40):
		var row: int = surface_row + m * MaterialLook.CELLS_PER_METRE
		var c: float = VeilPainter.skylight_ceiling(row)
		checked += 1
		if c <= previous + 0.0001:
			monotone += 1
		previous = c
	_check_over(checked, monotone == checked,
		"the ceiling never rises as depth grows -- %d of %d samples" % [monotone, checked])
	# At the surface the sky is unobstructed, so the ceiling must be a true no-op: this term may not
	# darken the daylit band, which the sky painter and the surface cap already own.
	_check(is_equal_approx(VeilPainter.skylight_ceiling(surface_row), 1.0),
		"at the surface the ceiling is exactly 1.0 (%.4f) -- an unobstructed sky darkens nothing"
			% VeilPainter.skylight_ceiling(surface_row))
	# ...and in the deep it bottoms out at legacy's own AMBIENT_DARK, rather than at black. Rock in shadow
	# is dark rock, never a hole -- the same rule `RockTone.VALUE_FLOOR` carries.
	var deep: float = VeilPainter.skylight_ceiling(surface_row + 200 * MaterialLook.CELLS_PER_METRE)
	_check(is_equal_approx(deep, 1.0 - VeilPainter.AMBIENT_DARK),
		"the deep floors at 1 - AMBIENT_DARK = %.2f (got %.4f), not at black"
			% [1.0 - VeilPainter.AMBIENT_DARK, deep])
	# CONTROL, and it is the one that matters: the fall must actually HAPPEN over playable depths. A
	# ceiling that reached its floor only at 200 m would be monotone, would floor correctly, and would
	# leave the first thirty metres -- the whole early game -- exactly as evenly lit as before.
	var at_ten: float = VeilPainter.skylight_ceiling(surface_row + 10 * MaterialLook.CELLS_PER_METRE)
	_check(at_ten < 0.75,
		"CONTROL: by 10 m the ceiling is already down to %.2f, so the gradient is present where the game "
			% at_ten + "is actually played and not only in the abyss")


func _test_an_incomplete_frame_paints_nothing() -> void:
	var node := Node2D.new()
	VeilPainter.paint(null, node)
	VeilPainter.paint(Frame.new(), node)
	node.free()
	_check(true, "no frame, and a frame with no observation, each paint nothing rather than erroring")


## THE LAMP CUTS THE VEIL, which is the half that makes rock visible (D0306). Legacy is explicit that
## this is not a glow over the top: "Light reveals, it does not paint... it cuts a wide hole in the
## darkness veil, which is what actually makes rock visible", and that an additive term strong enough to
## swamp the reveal "repaints the rock the veil just uncovered".
func _test_the_lamp_opens_the_veil_around_the_miner_and_not_far_from_it() -> void:
	var obs: Interface.Observation = _world(_chamber(30, 40, 46, 52))
	var here: Vector2i = obs.cell
	var near_lift: float = VeilPainter.lamp_lift(obs, here)
	var far_lift: float = VeilPainter.lamp_lift(obs,
		here + Vector2i(VeilPainter.LAMP_BEAM_M * MaterialLook.CELLS_PER_METRE * 3, 0))
	print("  [OBSERVED] lamp lift at the miner %.4f, three beam-radii away %.4f" % [near_lift, far_lift])
	_check(near_lift > 0.3, "the miner's own cell is well lit (%.4f)" % near_lift)
	_check(is_zero_approx(far_lift),
		"and a cell three beam radii away gets nothing (%.4f) -- a lamp that lit the whole window would "
		% far_lift + "undo the veil rather than cut it")
	_check(VeilPainter.lamp_lift(null, here) == 0.0, "a null observation lights nothing")
	# FALLOFF, MEASURED AT THE RIGHT SCALE. A step-by-step monotonicity check was tried first and failed
	# at 24 of 36 steps -- correctly, because legacy's grain texture deliberately breaks the pool's outer
	# half so "light dissolves into the rock grain as it fades". A per-step check measures the grain, not
	# the falloff. The mean of the near half against the far half is the quantity the grain cannot flip.
	var near_sum: float = 0.0
	var far_sum: float = 0.0
	var half: int = int(VeilPainter.LAMP_BEAM_M) * MaterialLook.CELLS_PER_METRE / 2
	for k: int in range(0, half):
		near_sum += VeilPainter.lamp_lift(obs, here + Vector2i(0, k))
		far_sum += VeilPainter.lamp_lift(obs, here + Vector2i(0, k + half))
	print("  [OBSERVED] pool mean over the near half %.4f, over the far half %.4f"
		% [near_sum / float(half), far_sum / float(half)])
	_check(near_sum > far_sum * 1.5,
		"the pool is brighter near the lamp than far from it (%.4f vs %.4f over %d cells each)"
		% [near_sum / float(half), far_sum / float(half), half])


## Legacy's own regression, ported with it: "at spawn the full-strength lamp washed out both the avatar
## and the starter ore it sits on, so every warm thing read as a lamp." A full blaze in the deep, a dim
## glow in daylight — and a FLOOR, never off, or the surface has no lamp at all.
func _test_the_lamp_is_dimmer_in_daylight_than_in_the_deep() -> void:
	var surface: float = VeilPainter.lamp_scale(MaterialLook.SURFACE_ROW)
	var deep: float = VeilPainter.lamp_scale(MaterialLook.SURFACE_ROW
		+ int(VeilPainter.LAMP_FULL_M) * MaterialLook.CELLS_PER_METRE)
	print("  [OBSERVED] lamp scale at the surface %.2f, at %.0f m %.2f"
		% [surface, VeilPainter.LAMP_FULL_M, deep])
	_check(is_equal_approx(surface, VeilPainter.LAMP_SURFACE_SCALE),
		"at the surface the lamp sits at legacy's %.2f floor (%.2f)" % [VeilPainter.LAMP_SURFACE_SCALE, surface])
	_check(is_equal_approx(deep, 1.0), "in the deep it is at full strength (%.2f)" % deep)
	_check(surface > 0.0, "...and it is never switched OFF -- a floor, not a gate")
