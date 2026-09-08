extends "res://tests/test_base.gd"
## D0499's caveat closed: the ring's word is DRAWN by the real draw pass, not only decided by the pure table.
## `TargetGuide.paint` runs through a `WorldView` host over the seeded tutorial world with a fresh ladder (rung
## MINE) and the body on the spawn; `RingWord.last_drawn` is the pass's own receipt. The control: a finished
## ladder draws nothing, and the receipt stays empty.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_ring_word.gd
const S: int = Fx.SCALE
const ROCK: StringName = &"clay"

var items: Items
var world: World
var machines: Machines


func _initialize() -> void:
	await _test_the_word_is_drawn_by_the_real_pass()
	_finish("ring_word")


func _seeded() -> Interface:
	items = _hub_items(64, 32)
	world = items.world
	machines = _hub_machines(items)
	for row_m: int in range(WorldSeeder.SURFACE_ROW_M, 32):
		for col_m: int in 64:
			world.set_solid(Vector2i(col_m, row_m), ROCK)
	_check(WorldSeeder.stamp(world, items, machines, &"tutorial"), "control: the tutorial record stamps (%s)" % WorldSeeder.last_refusal)
	var spawn: Vector2i = WorldSeeder.spawn_logic_cell(StartsRecords.RECORDS["tutorial"])
	var body: Body = Body.new(Fx.from_int(spawn.x * 16 + 8), Fx.from_int(spawn.y * 16) - Body.HEIGHT_PX / 2 * S)
	return Interface.new(world.grid, body, Mining.new(), world, items, machines)


func _run_frames(view: WorldView, n: int) -> void:
	for _i: int in n:
		await process_frame
		view.refresh()
		view.add_hud().refresh()


func _test_the_word_is_drawn_by_the_real_pass() -> void:
	var door: Interface = _seeded()
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	# The shell's rig puts the camera on the body at boot (shell/main.gd); the host here does the same by hand,
	# at play zoom, so the ring stands where a player sees it and not at the canvas's edge.
	var o0: Interface.Observation = door.observe(Interface.Envelope.oracle_over(world.grid))
	cam.position = Vector2(float(o0.pos_x), float(o0.pos_y)) / float(S)
	cam.zoom = Vector2(2.0, 2.0)
	var ladder: Objectives = Objectives.new()
	view.add_hud().add_stateful_chip(TargetGuide.new(ladder), &"paint")
	RingWord.last_drawn = {}
	await _run_frames(view, 6)
	var got: Dictionary = RingWord.last_drawn
	_check(not got.is_empty() and String(got.get("word", "")) == "ORE", "the real draw pass on the seeded world reached the word, and it is ORE on the first rung (%s)" % str(got.get("word", "<none>")))
	var rect: Rect2 = got.get("rect", Rect2())
	_check(rect.size.x > 0.0 and rect.size.y > 0.0 and Rect2(Vector2.ZERO, UiTheme.CANVAS).encloses(rect), "...with a label rect on the canvas (%s)" % str(rect))
	_check(float(got.get("alpha", 0.0)) > 0.99, "...at the ring's full alpha on a fresh rung (%.2f)" % float(got.get("alpha", 0.0)))
	var ids: Array = []
	for step: Dictionary in Objectives.STEPS:
		ids.append(String(step["id"]))
	ladder.restore_done(ids)
	_check(ladder.all_done(), "control: the ladder is finished")
	RingWord.last_drawn = {}
	await _run_frames(view, 4)
	_check(RingWord.last_drawn.is_empty(), "a finished ladder draws no ring and no word: the receipt stays empty (%s)" % str(RingWord.last_drawn))
	view.queue_free()
