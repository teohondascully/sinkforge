extends "res://tests/test_base.gd"
## D0371. `view/hud/minimap.gd`: the frame fits the world's aspect in a box, corner or centred; the
## image is one pixel per logic cell off the coarse plane and rebuilds only when the version moves (the
## plan's correction of legacy's count-keyed cache); you, the view and the machines land where the scale
## puts them; a real observation carries the plane and a redraw through the host runs.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_minimap.gd
const S: int = Fx.SCALE


func _initialize() -> void:
	_test_the_frame_fits_the_aspect()
	_test_the_texture_rebuilds_only_on_a_new_version()
	_test_the_overlays_land_by_the_scale()
	await _test_a_real_observation_carries_the_plane()
	_finish("minimap")


func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func _obs(cells: Vector2i = Vector2i(40, 30)) -> Interface.Observation:
	var o: Interface.Observation = Interface.Observation.new()
	o.map_cells = cells
	o.map = PackedByteArray()
	o.map.resize(cells.x * cells.y)
	o.map_version = 1
	return o


func _test_the_frame_fits_the_aspect() -> void:
	_check(Minimap.fit(Vector2(2.0, 1.0), Vector2(100.0, 100.0)).is_equal_approx(Vector2(100.0, 50.0)), "a wide world fits by width")
	_check(Minimap.fit(Vector2(1.0, 2.0), Vector2(100.0, 100.0)).is_equal_approx(Vector2(50.0, 100.0)), "a tall one by height")
	var small: Rect2 = Minimap.frame_rect(Vector2i(40, 30), false)
	_check(small.size.x <= UiTheme.px(Minimap.MINI_W) + 0.01 and small.size.y <= UiTheme.px(Minimap.MINI_H) + 0.01, "the corner form fits its box (%s)" % str(small))
	_check(is_equal_approx(small.end.x, UiTheme.CANVAS.x - UiTheme.px(Minimap.MARGIN_RIGHT)) and is_equal_approx(small.position.y, UiTheme.px(Minimap.MINI_TOP)), "top-right at legacy's margin")
	var tall: Rect2 = Minimap.frame_rect(Vector2i(20, 200), false)
	_check(is_equal_approx(tall.size.y, UiTheme.px(Minimap.MINI_H)) and tall.size.x < tall.size.y, "a deep shaft is height-bound in the corner, not a slab")
	var big: Rect2 = Minimap.frame_rect(Vector2i(40, 30), true)
	_check(big.get_center().is_equal_approx(UiTheme.CANVAS * 0.5) and big.size.x > small.size.x, "the large form is centred and larger")


func _test_the_texture_rebuilds_only_on_a_new_version() -> void:
	var m: Minimap = Minimap.new()
	var o: Interface.Observation = _obs()
	o.map[0] = TileGrid.COARSE_ROCK
	o.map[1] = TileGrid.COARSE_ORE
	var look: MaterialLook = MaterialLook.new()
	var t1: ImageTexture = m.ensure_texture(o, look)
	_check(t1 != null and m.rebuilds == 1 and t1.get_width() == 40 and t1.get_height() == 30, "the first call builds a 40x30 image (%d rebuilds)" % m.rebuilds)
	var t2: ImageTexture = m.ensure_texture(o, look)
	_check(t2 == t1 and m.rebuilds == 1, "the same version returns the same texture without a rebuild")
	o.map[2] = TileGrid.COARSE_ROCK
	_check(m.ensure_texture(o, look) == t1 and m.rebuilds == 1, "a changed byte under the SAME version is not seen: the version is the key, not the bytes")
	o.map_version = 2
	_check(m.ensure_texture(o, look) != t1 and m.rebuilds == 2, "a new version rebuilds")
	var img: Image = m.ensure_texture(o, look).get_image()
	# An 8-bit texture reads back quantised (0.95 is 242/255), so the comparison is within a step, not exact.
	_check(_close(img.get_pixel(1, 0), Minimap.ORE_COLOR) and _close(img.get_pixel(5, 5), Minimap.VOID_COLOR), "ore is the fleck, void the void (%s, %s)" % [str(img.get_pixel(1, 0)), str(img.get_pixel(5, 5))])
	_check(img.get_pixel(0, 0) != Minimap.VOID_COLOR and img.get_pixel(0, 0) != Minimap.ORE_COLOR, "rock is the band's colour, neither")
	var short: Interface.Observation = _obs()
	short.map = PackedByteArray([1, 2, 3])
	_check(m.ensure_texture(short, look) == null, "a plane shorter than its cells is refused")


func _test_the_overlays_land_by_the_scale() -> void:
	var m: Minimap = Minimap.new()
	var f: Frame = Frame.new()
	f.obs = _obs(Vector2i(40, 30))
	f.obs.pos_x = 20 * 16 * S      # logic cell 20 of 40: halfway
	f.obs.pos_y = 15 * 16 * S
	f.obs.map_machines = [Vector2i(0, 0), Vector2i(39, 29)]
	f.view_world_rect = Rect2(0.0, 0.0, 10.0 * 16.0, 5.0 * 16.0)
	var l: Dictionary = m.layout(f)
	var rect: Rect2 = l["rect"]
	_check(not l.is_empty() and (l["you"] as Vector2).is_equal_approx(rect.get_center()), "the body at the world's centre marks the map's centre")
	var dots: Array = l["dots"]
	_check(dots.size() == 2 and (dots[0] as Vector2).is_equal_approx(rect.position) and (dots[1] as Vector2).x < rect.end.x, "machine dots at their cells")
	var view: Rect2 = l["view"]
	_check(view.position.is_equal_approx(rect.position) and is_equal_approx(view.size.x, rect.size.x * 0.25), "the visible window is a quarter of the width from the origin")
	m.shown = false
	_check(m.layout(f).is_empty(), "hidden: nothing")
	m.shown = true
	m.large = true
	_check(bool(m.layout(f)["large"]) and (m.layout(f)["rect"] as Rect2).size.x > rect.size.x, "large: the big frame")
	_check(m.layout(null).is_empty(), "no frame, nothing")


func _test_a_real_observation_carries_the_plane() -> void:
	var items: Items = _hub_items(20, 20)
	var machines: Machines = _hub_machines(items)
	var world: World = items.world
	for col: int in range(20):
		for row: int in range(15, 20):
			world.set_solid(Vector2i(col, row), &"clay")
	machines.place(world, MachineDef.of(&"drill"), Vector2i(3, 14))
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(14 * 16 + 8) - Body.HEIGHT_PX / 2 * S)
	var door: Interface = Interface.new(world.grid, body, Mining.new(), world, items, machines)
	var o: Interface.Observation = door.observe(Interface.Envelope.new(Rect2i(0, 0, 80, 80)))
	_check(o.map_cells.x > 0 and o.map.size() == o.map_cells.x * o.map_cells.y, "the observation carries a whole-world plane of %s" % str(o.map_cells))
	_check(o.map_machines.size() == 1 and o.map_machines[0] == Vector2i(3, 14), "and every machine's cell (%s)" % str(o.map_machines))
	var rock: int = 0
	for b: int in o.map:
		if b == TileGrid.COARSE_ROCK:
			rock += 1
	_check(rock > 0, "the clay floor shows as rock (%d cells)" % rock)
	var v: int = o.map_version
	world.grid.set_material(Vector2i(2, 2), &"clay")
	_check(door.observe(Interface.Envelope.new(Rect2i(0, 0, 80, 80))).map_version == v + 1, "a write at a cell's centre moves the version the next observation carries")
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	var chip: Minimap = Minimap.new()
	var ran: Array = [0]
	view.add_hud().add_chip(func(f: Frame, ci: CanvasItem) -> void:
		chip.paint(f, ci)
		ran[0] = int(ran[0]) + 1)
	await process_frame
	view.refresh()
	view.add_hud().refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0 and chip.rebuilds >= 1, "paint() ran through the host and built the image once (%d runs, %d rebuilds)" % [int(ran[0]), chip.rebuilds])
	view.queue_free()
