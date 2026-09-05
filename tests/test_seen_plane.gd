extends "res://tests/test_base.gd"
## D0400. `interface/seen_plane.gd`, the map's memory: a disc about the body is marked on every hub tick,
## the version moves only when a cell turns, the save carries it, and the minimap paints ore only where it
## is set. Ore the player has not been near paints as rock (the director's T015 ruling).
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_seen_plane.gd


func _initialize() -> void:
	_test_the_disc_and_the_version()
	_test_the_save_round_trip()
	_test_the_interface_marks_at_the_hub_cadence()
	_test_the_map_paints_ore_only_where_seen()
	_finish("seen_plane")


func _test_the_disc_and_the_version() -> void:
	var plane: SeenPlane = SeenPlane.new(Vector2i(40, 60))
	_check(plane.count() == 0 and plane.version == 0 and not plane.is_seen(Vector2i(5, 5)), "a new plane has seen nothing")
	plane.mark(Vector2i(20, 30), 3)
	_check(plane.is_seen(Vector2i(20, 30)) and plane.is_seen(Vector2i(23, 30)) and not plane.is_seen(Vector2i(24, 30)) and not plane.is_seen(Vector2i(23, 32)), "the disc is a disc: radius 3 reaches (23,30) and not (24,30) or (23,32)")
	_check(plane.count() == 29 and plane.version == 1, "29 cells in a radius-3 disc, one version bump (%d, v%d)" % [plane.count(), plane.version])
	plane.mark(Vector2i(20, 30), 3)
	_check(plane.version == 1, "marking what is already seen moves no version")
	plane.mark(Vector2i(0, 0), 3)
	_check(plane.is_seen(Vector2i(0, 0)) and not plane.is_seen(Vector2i(-1, 0)) and plane.version == 2, "a disc at the corner is clipped, and out of bounds is never seen")
	_check(SeenPlane.RADIUS_M >= 6 and SeenPlane.RADIUS_M <= 12, "the default radius is a lamp's reach in metres (%d)" % SeenPlane.RADIUS_M)


func _test_the_save_round_trip() -> void:
	var plane: SeenPlane = SeenPlane.new(Vector2i(10, 12))
	plane.mark(Vector2i(4, 4), 2)
	var d: Dictionary = plane.capture()
	var back: SeenPlane = SeenPlane.new(Vector2i(10, 12))
	_check(back.restore(d) and back.seen == plane.seen and back.count() == plane.count(), "capture then restore is the same plane")
	var other: SeenPlane = SeenPlane.new(Vector2i(11, 12))
	_check(not other.restore(d) and other.count() == 0, "a plane of another size refuses the bytes and stays clean")
	_check(not back.restore({}) and back.count() == plane.count(), "an empty record is refused and changes nothing")


func _test_the_interface_marks_at_the_hub_cadence() -> void:
	var grid: TileGrid = TileGrid.new(128, 64, 3)   # 32 logic columns, so a radius-8 disc about column 16 fits
	for col: int in 128:
		for row: int in range(40, 64):
			grid.set_material(Vector2i(col, row), &"clay")
	var body: Body = Body.new(64 * 4 * Fx.SCALE, (40 * 4 - Body.HEIGHT_PX / 2) * Fx.SCALE)
	var door: Interface = Interface.new(grid, body, Mining.new())
	var seen: SeenPlane = door.services()["seen"]
	_check(seen.count() == 0, "nothing seen before the first tick")
	var quiet: InputFrame = InputFrame.new()
	door.apply(Command.move(quiet))
	door.apply(Command.move(quiet))
	var before_hub: int = seen.count()
	door.apply(Command.move(quiet))
	_check(before_hub == 0 and seen.count() > 0, "the mark lands on the hub tick, the third (%d before, %d after)" % [before_hub, seen.count()])
	var body_logic := WorldSurroundings.logic_of(Vector2i(Body._px_to_cell(body.pos_x), Body._px_to_cell(body.pos_y)))
	_check(seen.is_seen(body_logic) and seen.is_seen(body_logic + Vector2i(SeenPlane.RADIUS_M, 0)) and not seen.is_seen(body_logic + Vector2i(SeenPlane.RADIUS_M + 1, 0)), "...about the body's own logic cell, to the lamp's reach")
	var obs: Interface.Observation = door.observe(Interface.Envelope.oracle_over(grid))
	_check(obs.map_seen.size() == obs.map_cells.x * obs.map_cells.y and obs.map_seen_version == seen.version, "the observation carries the plane and its version")
	var sig: String = door.state_signature()
	seen.mark(Vector2i(0, 0), 8)
	_check(door.state_signature() == sig, "control: the memory is outside every signature")


func _test_the_map_paints_ore_only_where_seen() -> void:
	var look: MaterialLook = MaterialLook.new()
	var rock: Color = Minimap.class_color(Interface.Observation.MAP_ROCK, 100, look)
	var ore_unseen: Color = Minimap.class_color(Interface.Observation.MAP_ORE, 100, look, false)
	var ore_seen: Color = Minimap.class_color(Interface.Observation.MAP_ORE, 100, look, true)
	_check(ore_unseen == rock, "unseen ore is the rock it sits in")
	_check(ore_seen != rock and ore_seen.r > rock.r and ore_seen.g > rock.g, "seen ore is the ore family's colour, warmer and brighter than the rock")
	_check(Minimap.class_color(Interface.Observation.MAP_ROCK, 100, look, true) == rock, "control: seeing rock does not colour it")
