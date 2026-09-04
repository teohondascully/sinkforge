extends "res://tests/test_base.gd"
## D0374. `view/visuals/ore_painter.gd`: legacy's S4 seam. The claims: the spatial-hash flood draws the
## same picture as the obvious quadratic one (legacy's own `check_seam_flood`, its cases scaled to our
## cell); the link and the noise floor are in metres; a seam's radius grows with its span and is capped;
## the glow is the seam's own mineral hue pushed toward saturation; a seam in daylight is silent; the
## population is exactly the glint's exposed faces; a lode's speck drains monotonically with its per
## mille; the two passes run on a real view.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_ore_painter.gd
const CELL: int = Heightfield.TERRAIN_CELL_PX
const GRID_W: int = 40
const ROCK_TOP: int = MaterialLook.SURFACE_ROW + 60          ## 15 m down: past the gate's full-strength depth
const GRID_H: int = ROCK_TOP + 28
const S: int = Fx.SCALE
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_test_the_flood_matches_the_obvious_one()
	_test_the_link_and_the_floor()
	_test_the_radius_and_the_cap()
	_test_the_glow_colour_and_the_gate()
	_test_the_population_is_the_glints()
	_test_the_lode_drains_monotonically()
	await _test_both_passes_run_on_a_real_view()
	_finish("ore_painter")


## --- the flood ---------------------------------------------------------------------------------------

func _test_the_flood_matches_the_obvious_one() -> void:
	var total: int = 0
	for case: Dictionary in _cases():
		var cells: Array[Vector2i] = case["cells"]
		var fast: Array[Dictionary] = OrePainter.cluster(cells)
		var slow: Array[Dictionary] = _reference(cells)
		total += slow.size()
		_check(_same(fast, slow), "%s (%d cells -> %d seams)" % [case["name"], cells.size(), slow.size()])
	_check(total >= 8, "the cases produced %d seams between them -- enough for agreement to mean something" % total)
	var scatter: Array[Vector2i] = _scatter(1200, 400, 400)
	_check(_same(OrePainter.cluster(scatter), _reference(scatter)), "...and they still agree at n=1200")
	var shuffled: Array[Vector2i] = scatter.duplicate()
	shuffled.reverse()
	_check(_same(OrePainter.cluster(shuffled), OrePainter.cluster(scatter)), "the input order does not change the picture")
	_check(OrePainter.cluster(scatter).size() <= OrePainter.MAX_SEAMS, "never more than %d seams" % OrePainter.MAX_SEAMS)


func _test_the_link_and_the_floor() -> void:
	_check(OrePainter.LINK_CELLS == 12 and OrePainter.MIN_CELLS == 4, "the link is 3 m = %d cells and the floor one metre of face = %d cells" % [OrePainter.LINK_CELLS, OrePainter.MIN_CELLS])
	_check(OrePainter.BUCKET_CELLS >= OrePainter.LINK_CELLS, "the bucket is at least the link (%d >= %d)" % [OrePainter.BUCKET_CELLS, OrePainter.LINK_CELLS])
	var four: Array[Vector2i] = [Vector2i(10, 10), Vector2i(11, 10), Vector2i(12, 10), Vector2i(13, 10)]
	var linked: Array[Vector2i] = four.duplicate()
	linked.append(Vector2i(13 + OrePainter.LINK_CELLS, 10))
	var apart: Array[Vector2i] = four.duplicate()
	apart.append(Vector2i(13 + OrePainter.LINK_CELLS + 1, 10))
	var l: Array[Dictionary] = OrePainter.cluster(linked)
	var a: Array[Dictionary] = OrePainter.cluster(apart)
	_check(l.size() == 1 and (l[0]["cells"] as Array).size() == 5, "a cell exactly LINK away joins: one seam of five")
	_check(a.size() == 1 and (a[0]["cells"] as Array).size() == 4, "...one further it is a lone speck, dropped: one seam of four")
	_check(OrePainter.cluster([Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)] as Array[Vector2i]).is_empty(), "three cells of face are under the floor and glow not at all")


func _test_the_radius_and_the_cap() -> void:
	var four: Array[Vector2i] = [Vector2i(10, 10), Vector2i(11, 10), Vector2i(12, 10), Vector2i(13, 10)]
	var s: Dictionary = OrePainter.cluster(four)[0]
	var want: float = (OrePainter.RADIUS_BASE_M + OrePainter.RADIUS_PER_EXTENT * 0.75) * MaterialLook.CELLS_PER_METRE
	_check(is_equal_approx(float(s["radius"]), want), "four cells in a row: 2.2 m + 0.55 x 0.75 m = %.2f cells (%.2f)" % [want, float(s["radius"])])
	_check((s["pos"] as Vector2).is_equal_approx(Vector2(12.0, 10.5)), "the centroid at the cells' centre (%s)" % str(s["pos"]))
	var vein: Array[Vector2i] = []
	for x: int in range(60):
		vein.append(Vector2i(x, 30))
	var v: Dictionary = OrePainter.cluster(vein)[0]
	_check(is_equal_approx(float(v["radius"]), OrePainter.RADIUS_MAX_M * MaterialLook.CELLS_PER_METRE), "a 15 m vein is capped at %.1f m (%.2f cells)" % [OrePainter.RADIUS_MAX_M, float(v["radius"])])
	_check(OrePainter.RADIUS_MAX_M * MaterialLook.CELLS_PER_METRE < (OrePainter.RADIUS_BASE_M + OrePainter.RADIUS_PER_EXTENT * 14.75) * MaterialLook.CELLS_PER_METRE, "control: the cap was what bound it")


## --- the glow ----------------------------------------------------------------------------------------

func _test_the_glow_colour_and_the_gate() -> void:
	var w: Array = _world(&"ore_iron", [Vector2i(20, ROCK_TOP + 4)])
	var obs: Interface.Observation = w[0]
	var look: MaterialLook = w[1]
	var nug: Color = OrePainter.record_color(MaterialsRecords.RECORDS["ore_iron"]["nugget_color"])
	var glow: Color = OrePainter.glow_color(look, obs, [Vector2i(20, ROCK_TOP + 3)])
	_check(nug.a > 0.0 and absf(glow.h - nug.h) < 0.02, "iron's glow keeps iron's hue (%.3f vs %.3f)" % [glow.h, nug.h])
	_check(glow.s >= nug.s + OrePainter.SATURATE - 0.001 and glow.v >= 0.85, "...pushed toward saturation, kept bright (s %.2f -> %.2f, v %.2f)" % [nug.s, glow.s, glow.v])
	_check(OrePainter.glow_color(look, obs, []) == OrePainter.CRYSTAL_COLOR, "no cells: the cyan fallback")
	var clay: Array = _world(&"clay", [Vector2i(20, ROCK_TOP + 4)])
	_check(OrePainter.glow_color(clay[1], clay[0], [Vector2i(20, ROCK_TOP + 3)]) == OrePainter.CRYSTAL_COLOR, "a material without nuggets: the cyan fallback")
	_check(not (MaterialsRecords.RECORDS["clay"] as Dictionary).has("nugget_color"), "control: clay has no nugget colour")
	_check(OrePainter.seam_dark(look, MaterialLook.SURFACE_ROW) == 0.0, "a seam at the surface is silent")
	_check(is_equal_approx(OrePainter.seam_dark(look, ROCK_TOP), 1.0), "...and at 15 m it glows at full strength")
	_check(OrePainter.breath(0.0, 0.0) > 0.5 and OrePainter.breath(0.0, 0.0) <= 1.0, "the breath sits in 0.10..1.00 (%.2f)" % OrePainter.breath(0.0, 0.0))


func _test_the_population_is_the_glints() -> void:
	var dug: Array[Vector2i] = []
	for x: int in range(16, 24):
		for y: int in range(ROCK_TOP + 4, ROCK_TOP + 8):
			dug.append(Vector2i(x, y))
	var w: Array = _world(&"ore_iron", dug)
	var painter: OrePainter = OrePainter.new()
	var seams: Array[Dictionary] = painter.seams_for(w[1], w[0])
	_check(not seams.is_empty(), "a pocket dug into iron leaves exposed faces that cluster (%d seams)" % seams.size())
	var faces: int = 0
	var members: int = 0
	for s: Dictionary in seams:
		for c: Vector2i in (s["cells"] as Array[Vector2i]):
			members += 1
			if GlintPainter.is_exposed_face(w[0], c):
				faces += 1
	_check(members > 0 and faces == members, "every member is an exposed face (%d of %d)" % [faces, members])
	_check(painter.seams_for(w[1], w[0]) == seams, "the same observation answers from the cache")
	var coal: Array = _world(&"coal", dug)
	_check(OrePainter.new().seams_for(coal[1], coal[0]).is_empty(), "the same pocket in coal glows nowhere: coal has nuggets and does not glitter")
	var sealed: Array = _world(&"ore_iron", [] as Array[Vector2i])
	var top_only: bool = true
	var top_members: int = 0
	# The window is clipped to the world, and past the window `solid_at` answers false as it does for air
	# (D0238), so the world's own edge columns and bottom row read as faces; the glint's population has
	# always had that edge. Read the interior, where the only face is the one open to the air above.
	for s2: Dictionary in OrePainter.new().seams_for(sealed[1], sealed[0]):
		for c: Vector2i in (s2["cells"] as Array[Vector2i]):
			if c.x == 0 or c.x == GRID_W - 1 or c.y == GRID_H - 1:
				continue
			top_members += 1
			if c.y != ROCK_TOP:
				top_only = false
	_check(top_members > 0 and top_only, "undug iron's only interior faces are its top surface, open to the air above (%d members)" % top_members)


## --- the lode ----------------------------------------------------------------------------------------

func _test_the_lode_drains_monotonically() -> void:
	var cells: Array[Vector2i] = []
	for x: int in range(50):
		for y: int in range(40):
			cells.append(Vector2i(x, y))
	var full: int = 0
	var half: int = 0
	var monotone: bool = true
	for c: Vector2i in cells:
		if OrePainter.lode_shows(c, 1000):
			full += 1
		if OrePainter.lode_shows(c, 500):
			half += 1
		var was: bool = false
		for p: int in range(0, 1001, 50):
			var now: bool = OrePainter.lode_shows(c, p)
			if was and not now:
				monotone = false
			was = now
	_check(full == cells.size(), "a full lode shows every fleck (%d of %d)" % [full, cells.size()])
	_check(half > cells.size() * 2 / 5 and half < cells.size() * 3 / 5, "half a lode shows about half of them (%d of %d)" % [half, cells.size()])
	_check(monotone, "a fleck that is gone stays gone as the lode drains further")
	var none: int = 0
	for c: Vector2i in cells:
		if OrePainter.lode_shows(c, 0):
			none += 1
	_check(none == 0, "an empty lode shows nothing (%d)" % none)
	var look: MaterialLook = MaterialLook.new()
	var sock: Color = WallPainter.socket_color(look, &"ore_iron", 3, ROCK_TOP + 2)
	_check(sock == WallPainter.wall_color(look, &"ore_iron", 3, ROCK_TOP + 2) or look.is_speck(&"ore_iron", 3, ROCK_TOP + 2), "the socket is the wall's unmarked rock")
	var speck_at: Vector2i = Vector2i(-1, -1)
	for x: int in range(200):
		if look.is_speck(&"ore_iron", x, ROCK_TOP + 2):
			speck_at = Vector2i(x, ROCK_TOP + 2)
			break
	_check(speck_at.x >= 0 and WallPainter.socket_color(look, &"ore_iron", speck_at.x, speck_at.y) != WallPainter.wall_color(look, &"ore_iron", speck_at.x, speck_at.y), "...and on a speck cell it differs from the mark (found at %s)" % str(speck_at))


## --- the passes --------------------------------------------------------------------------------------

func _test_both_passes_run_on_a_real_view() -> void:
	var items: Items = _hub_items(20, 40)
	var machines: Machines = _hub_machines(items)
	var world: World = items.world
	for col: int in range(20):
		for row: int in range(25, 40):
			world.set_solid(Vector2i(col, row), &"ore_iron")
	for x: int in range(30, 38):
		for y: int in range(104, 110):
			world.grid.excavate(Vector2i(x, y))
	world.grid.set_wall(Vector2i(31, 105), &"ore_iron")
	world.deposits.seed_lode(Vector2i(31, 105), &"ore_iron", 10)
	var body: Body = Body.new(Fx.from_int(34 * 4), Fx.from_int(24 * 16 + 8) - Body.HEIGHT_PX / 2 * S)
	var door: Interface = Interface.new(world.grid, body, Mining.new(), world, items, machines)
	var probe: Interface.Observation = door.observe(Interface.Envelope.covering(Rect2(0.0, 380.0, 320.0, 200.0), WorldView.WINDOW_MARGIN_CELLS))
	_check(probe.lodes.has(Vector2i(31, 105)) and probe.lode_permille(Vector2i(31, 105)) == 1000, "the fixture poses an opened lode at full (%d permille)" % probe.lode_permille(Vector2i(31, 105)))
	_check(not GlintPainter.new().glint_cells(MaterialLook.new(), probe).is_empty(), "...and exposed iron faces around the pocket")
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	var glint: GlintPainter = GlintPainter.new()
	var painter: OrePainter = OrePainter.new(glint)
	var ran: Array = [0, 0]
	var layer: PaintLayer = view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		painter.paint_frame(f, ci)
		ran[0] = int(ran[0]) + 1)
	view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		OrePainter.paint_lode(f, ci)
		ran[1] = int(ran[1]) + 1)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	layer.material = mat
	await process_frame
	view.refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0 and int(ran[1]) > 0, "both passes ran on a real view (%d, %d)" % [int(ran[0]), int(ran[1])])
	_check(not painter.seams_for(MaterialLook.new(), probe).is_empty(), "...with at least one seam to glow")
	view.queue_free()


## --- fixtures ------------------------------------------------------------------------------------------

## A world solid from `ROCK_TOP` down in `material`, with `dug` excavated to pose faces (the glint suite's).
func _world(material: StringName, dug: Array[Vector2i]) -> Array:
	return _rock_world(material, dug, ROCK_TOP, GRID_W, GRID_H)


## Legacy's shaped cases, each coordinate scaled by four (a legacy cell is four of ours), so every case
## keeps the property it was built to attack: bucket seams, a contested cell in reach of two clumps,
## negative coordinates, a dense block, a scatter.
func _cases() -> Array[Dictionary]:
	var k: int = MaterialLook.CELLS_PER_METRE
	var cases: Array[Dictionary] = []
	cases.append({"name": "an empty world glows nowhere", "cells": ([] as Array[Vector2i])})
	cases.append({"name": "a single speck is noise, not a seam", "cells": ([Vector2i(5, 5)] as Array[Vector2i])})
	var vein: Array[Vector2i] = []
	for x: int in range(0, 40):
		vein.append(Vector2i(x * k, 17 * k))
	cases.append({"name": "a vein running straight across every bucket seam", "cells": vein})
	var contested: Array[Vector2i] = []
	for i: int in 9:
		contested.append(Vector2i((20 + i % 3) * k, (20 + i / 3) * k))
		contested.append(Vector2i((26 + i % 3) * k, (20 + i / 3) * k))
	contested.append(Vector2i(24 * k, 21 * k))
	cases.append({"name": "two clumps arguing over the cell between them", "cells": contested})
	var negative: Array[Vector2i] = []
	for i: int in 12:
		negative.append(Vector2i((-9 + i) * k, (-5 - (i % 4)) * k))
	cases.append({"name": "a seam straddling the origin into negative coordinates", "cells": negative})
	var dense: Array[Vector2i] = []
	for y: int in range(0, 12):
		for x: int in range(0, 12):
			dense.append(Vector2i(60 + x, 60 + y))
	cases.append({"name": "a dense block where one pop sees many candidates", "cells": dense})
	cases.append({"name": "a random scatter", "cells": _scatter(220, 360, 360)})
	return cases


func _scatter(n: int, w: int, h: int) -> Array[Vector2i]:
	_rng.seed = 99
	var seen: Dictionary = {}
	var out: Array[Vector2i] = []
	for _i: int in n:
		var c := Vector2i(_rng.randi_range(0, w), _rng.randi_range(0, h))
		if seen.has(c):
			continue
		seen[c] = true
		out.append(c)
	return out


## Byte-identical: same count, order, centroid, radius and member cells in the same order.
func _same(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if not (a[i]["pos"] as Vector2).is_equal_approx(b[i]["pos"] as Vector2):
			return false
		if not is_equal_approx(float(a[i]["radius"]), float(b[i]["radius"])):
			return false
		if (a[i]["cells"] as Array[Vector2i]) != (b[i]["cells"] as Array[Vector2i]):
			return false
	return true


## THE SPECIFICATION: the obvious quadratic flood, legacy's reference verbatim over our constants. The
## seam's shape is the painter's own `seam_of`, so this pins the GROUPING, which is the half a hash gets wrong.
func _reference(from_cells: Array[Vector2i]) -> Array[Dictionary]:
	var link: int = OrePainter.LINK_CELLS
	var cells: Array[Vector2i] = from_cells.duplicate()
	cells.sort()
	var seams: Array[Dictionary] = []
	var claimed: Dictionary = {}
	for start: Vector2i in cells:
		if claimed.has(start):
			continue
		var group: Array[Vector2i] = [start]
		claimed[start] = true
		var i: int = 0
		while i < group.size():
			var g: Vector2i = group[i]
			i += 1
			for other: Vector2i in cells:
				if claimed.has(other):
					continue
				if absi(other.x - g.x) <= link and absi(other.y - g.y) <= link:
					claimed[other] = true
					group.append(other)
		if group.size() < OrePainter.MIN_CELLS:
			continue
		seams.append(OrePainter.seam_of(group))
		if seams.size() >= OrePainter.MAX_SEAMS:
			break
	return seams
