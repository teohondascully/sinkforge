extends "res://tests/test_base.gd"
## D0499's caveat closed: the ring's word is DRAWN by the real draw pass, not only decided by the pure table.
## `TargetGuide.paint` runs through a `WorldView` host over the seeded tutorial world with a fresh ladder (rung
## MINE) and the body on the spawn; `RingWord.last_drawn` is the pass's own receipt. The control: a finished
## ladder draws nothing, and the receipt stays empty.
##
## D0521: the ring on a machine reads the DROP's own reach as a state. The body is posed at the strangers'
## own cells (the centre px the receipts count in, row 75 = centre y 300, feet on the surface at 320) and
## the drawn word is read back with and without the IN REACH suffix, beside the sim's own answer
## (`Aim.in_reach_logic`, what `Verbs.can_reach` calls) as the control that travels inside each pin.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_ring_word.gd
const S: int = Fx.SCALE
const ROCK: StringName = &"clay"
const FORGE: Vector2i = Vector2i(29, 20)    ## the tutorial's surface forge: spawn 32 - 3, the surface row
const RIG: Vector2i = Vector2i(34, 20)      ## the crew's rig: spawn + 2
const ROW_75_Y: int = 300                   ## the body's centre y with its feet on the surface (row 20 * 16 - 20)

var items: Items
var world: World
var machines: Machines


func _initialize() -> void:
	await _test_the_word_is_drawn_by_the_real_pass()
	_test_the_deliver_ring_goes_to_a_dropped_stack_first()
	await _test_the_ring_on_a_machine_reads_the_drops_own_reach()
	_finish("ring_word")


## D0521 (strangers 103-120): S119 stood at cell 128, the band's last, and pressed Q eleven times at TOO FAR
## with the forge ringed and nothing on screen saying which side of the drop's line the body was on. The
## ring on a machine now reads that line: at cell 123 the word is "FORGE · IN REACH", at 132 "FORGE"; the
## same for the rig on DELIVER; and the ore cell, the pointer's target, never carries the suffix. Each pin
## prints the sim's own `Aim.in_reach_logic` beside the drawn word: the two must never disagree.
func _test_the_ring_on_a_machine_reads_the_drops_own_reach() -> void:
	var at_123: Dictionary = await _drawn(Vector2i(123 * 4 + 2, ROW_75_Y), &"smelt", &"coal")
	_check(at_123["target"] == FORGE and at_123["sim"] == true, "control: at cell 123 the smelt ring is on the forge %s and the sim's reach says IN (%s, %s)" % [str(at_123["target"]), str(at_123["target"] == FORGE), str(at_123["sim"])])
	_check(at_123["word"] == "FORGE" + RingWord.IN_REACH, "at cell 123, row 75, the drawn word is FORGE · IN REACH (%s); NEAR_M's 2.2 m would say out at %.2f m" % [at_123["word"], at_123["dist_m"]])
	var at_132: Dictionary = await _drawn(Vector2i(132 * 4 + 2, ROW_75_Y), &"smelt", &"coal")
	_check(at_132["target"] == FORGE and at_132["sim"] == false, "control: at cell 132 the ring is still on the forge and the sim's reach says OUT (%s, %s)" % [str(at_132["target"] == FORGE), str(at_132["sim"])])
	_check(at_132["word"] == "FORGE", "at cell 132 the drawn word is FORGE, no suffix (%s), %.2f m off" % [at_132["word"], at_132["dist_m"]])
	var rig_143: Dictionary = await _drawn(Vector2i(143 * 4 + 2, ROW_75_Y), &"deliver", &"ingot")
	_check(rig_143["target"] == RIG and rig_143["sim"] == true and rig_143["word"] == "RIG" + RingWord.IN_REACH, "DELIVER at cell 143: the ring is on the rig %s, the sim says IN (%s), the word RIG · IN REACH (%s)" % [str(rig_143["target"]), str(rig_143["sim"]), rig_143["word"]])
	var rig_152: Dictionary = await _drawn(Vector2i(152 * 4 + 2, ROW_75_Y), &"deliver", &"ingot")
	_check(rig_152["target"] == RIG and rig_152["sim"] == false and rig_152["word"] == "RIG", "DELIVER at cell 152: on the rig, the sim says OUT (%s), the word RIG (%s)" % [str(rig_152["sim"]), rig_152["word"]])
	var ore: Dictionary = await _drawn(Vector2i(123 * 4 + 2, ROW_75_Y), &"mine", &"")
	_check(ore["dist_m"] < 2.0 and ore["word"] == "ORE" and not ore["word"].ends_with(RingWord.IN_REACH), "the ore cell %.2f m off, well inside the reach, is the pointer's target: the word is ORE with no suffix (%s)" % [ore["dist_m"], ore["word"]])


## The real draw pass with the body's centre at `centre_px`, the ladder on `rung` and one `held` in the
## pack: the drawn word (the receipt), the ringed metre, the body's distance to it, and the sim's own reach.
func _drawn(centre_px: Vector2i, rung: StringName, held: StringName) -> Dictionary:
	var door: Interface = _seeded(centre_px)
	if held != &"":
		items.pack.add(held, 1)
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	cam.position = Vector2(centre_px)
	cam.zoom = Vector2(2.0, 2.0)
	var ladder: Objectives = Objectives.new()
	var before: Array = []
	for step: Dictionary in Objectives.STEPS:
		if step["id"] == rung:
			break
		before.append(String(step["id"]))
	ladder.restore_done(before)
	ladder.step_age = ObjectiveLine.ACK_HOLD   # past the finished rung's tick, so the ring is up (ring_alpha)
	view.add_hud().add_stateful_chip(TargetGuide.new(ladder), &"paint")
	RingWord.last_drawn = {}
	await _run_frames(view, 6)
	var o: Interface.Observation = door.observe(Interface.Envelope.oracle_over(world.grid))
	var at: Vector2 = TargetGuide.target(rung, o)
	var body: Body = door.services()["body"]
	view.queue_free()
	return {"word": String(RingWord.last_drawn.get("word", "<none>")), "target": RingWord.metre_of(at),
		"dist_m": Vector2(centre_px).distance_to(at) / 16.0,
		"sim": Aim.in_reach_logic(body.pos_x, body.pos_y, RingWord.metre_of(at))}


## D0505 (stranger 94): three ingots dropped 8 m past the rig, the pack empty, seventeen Q presses at a ring on
## the rig. With no ingot in the pack and a pile of them on the ground the ring goes to the pile, its word
## INGOTS; with an ingot in hand it goes to the rig, its word RIG.
func _test_the_deliver_ring_goes_to_a_dropped_stack_first() -> void:
	var door: Interface = _seeded()
	var spawn: Vector2i = WorldSeeder.spawn_logic_cell(StartsRecords.RECORDS["tutorial"])
	var o: Interface.Observation = door.observe(Interface.Envelope.oracle_over(world.grid))
	var rig: Vector2 = TargetGuide.target(&"deliver", o)
	_check(rig != TargetGuide.NONE and RingWord.word(&"deliver", o, rig) == "RIG", "control: nothing dropped, no ingot in hand: the ring is on the rig, the word RIG (%s)" % RingWord.word(&"deliver", o, rig))
	items.piles.pile(spawn + Vector2i(8, 0))[&"ingot"] = 3               # S94's stack, 8 m right on the surface
	var dropped: Interface.Observation = door.observe(Interface.Envelope.oracle_over(world.grid))
	var at: Vector2 = TargetGuide.target(&"deliver", dropped)
	var pile_px: Vector2 = (Vector2(spawn + Vector2i(8, 0)) + Vector2(0.5, 0.5)) * float(Interface.Observation.LOGIC_PX)
	_check(at == pile_px and RingWord.word(&"deliver", dropped, at) == "INGOTS", "the pack empty and ingots on the ground: the ring goes to the pile, the word INGOTS (%s at %s)" % [RingWord.word(&"deliver", dropped, at), str(at)])
	items.pack.add(&"ingot", 1)
	var holding: Interface.Observation = door.observe(Interface.Envelope.oracle_over(world.grid))
	_check(TargetGuide.target(&"deliver", holding) == rig and RingWord.word(&"deliver", holding, rig) == "RIG", "an ingot in hand again: the ring is back on the rig (%s)" % RingWord.word(&"deliver", holding, TargetGuide.target(&"deliver", holding)))


## The seeded tutorial world with the body's centre at `centre_px` (world px), or on the spawn.
func _seeded(centre_px: Vector2i = Vector2i(-1, -1)) -> Interface:
	items = _hub_items(64, 32)
	world = items.world
	machines = _hub_machines(items)
	for row_m: int in range(WorldSeeder.SURFACE_ROW_M, 32):
		for col_m: int in 64:
			world.set_solid(Vector2i(col_m, row_m), ROCK)
	_check(WorldSeeder.stamp(world, items, machines, &"tutorial"), "control: the tutorial record stamps (%s)" % WorldSeeder.last_refusal)
	var spawn: Vector2i = WorldSeeder.spawn_logic_cell(StartsRecords.RECORDS["tutorial"])
	var body: Body = Body.new(Fx.from_int(spawn.x * 16 + 8), Fx.from_int(spawn.y * 16) - Body.HEIGHT_PX / 2 * S)
	if centre_px != Vector2i(-1, -1):
		body = Body.new(Fx.from_int(centre_px.x), Fx.from_int(centre_px.y))
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
