extends "res://tests/test_base.gd"
## D0380. `shell/main.gd`, `shell/play_input.gd`, `shell/hud_bridge.gd`: the game boots. The claims: the
## project names the shell's scene as its main scene and the scene instantiates as `Main`; a headless boot
## builds a door on the tutorial start and a view with its handles, ticks, and captures a session that
## carries the hints' lessons; the hands turn presses into a frame with edges that fire once per hold and
## an aim that is absent off the world; the verbs fire on their edges at the aimed metre and a held digit
## selects once; the HUD bridge's snapshot has what the page reads, and its payloads change the settings
## without touching disk when persistence is off; the GAME face's two doors act on the seat (D0396).
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_main_boot.gd


func _initialize() -> void:
	_test_the_project_boots_into_the_shell()
	_test_the_hands()
	_test_the_verbs()
	_test_the_hud_bridge()
	await _test_a_headless_boot_ticks_and_saves()
	_finish("main_boot")


func _test_the_project_boots_into_the_shell() -> void:
	var main_scene: String = String(ProjectSettings.get_setting("application/run/main_scene", ""))
	_check(main_scene == "res://shell/main.tscn", "project.godot names the shell's scene as the main scene (%s)" % main_scene)
	_check(ResourceLoader.exists("res://shell/main.tscn"), "...and the scene file exists")
	var packed: PackedScene = load("res://shell/main.tscn") as PackedScene
	var node: Node = packed.instantiate() if packed != null else null
	_check(node is Main, "it instantiates as Main")
	_check(node != null and bool(node.get("autoboot")), "...which boots itself when the engine runs it")
	if node != null:
		node.free()
	_check(Main.parse_quit_after(PackedStringArray(["--quit-after=12"])) == 12 and Main.parse_quit_after(PackedStringArray([])) == -1 and Main.parse_quit_after(PackedStringArray(["--quit-after=-3"])) == 0, "the smoke flag parses, is absent as -1, and never negative")


func _hand(down: Dictionary) -> Callable:
	return func(a: StringName) -> bool: return bool(down.get(a, false))


func _test_the_hands() -> void:
	var hands: PlayInput = PlayInput.new()
	var yes: Callable = func(_c: Vector2i) -> bool: return true
	var f: InputFrame = hands.read(_hand({Controls.RIGHT: true, Controls.JUMP: true}), Vector2(50.0, 30.0), 4, yes)
	_check(f.move_dir == 1 and f.jump_held and f.jump_pressed, "right and jump: moving right, jump held and pressed on its first tick")
	var f2: InputFrame = hands.read(_hand({Controls.RIGHT: true, Controls.JUMP: true}), Vector2(50.0, 30.0), 4, yes)
	_check(f2.jump_held and not f2.jump_pressed, "...held on: still held, no second press (the edge latch)")
	var f3: InputFrame = hands.read(_hand({Controls.LEFT: true, Controls.RIGHT: true}), Vector2(50.0, 30.0), 4, yes)
	_check(f3.move_dir == 0, "left and right together cancel")
	_check(f.has_aim and f.aim_col == 12 and f.aim_row == 7, "the aim is the terrain cell under the pointer (%d, %d)" % [f.aim_col, f.aim_row])
	var no: Callable = func(_c: Vector2i) -> bool: return false
	_check(not hands.read(_hand({}), Vector2(-10.0, 0.0), 4, no).has_aim, "off the world there is no aim, not a clamp to the rim")
	var g: InputFrame = hands.read(_hand({Controls.GRAPPLE: true, Controls.CLIMB_UP: true}), Vector2.ZERO, 4, yes)
	var g2: InputFrame = hands.read(_hand({Controls.GRAPPLE: true, Controls.CLIMB_UP: true}), Vector2.ZERO, 4, yes)
	_check(g.grapple_pressed and not g2.grapple_pressed, "the grapple presses once per hold")
	# THE SIGN IS THE CONSUMER'S, NOT THE HAND'S (D0396). This row used to pin `climb_dir == -1` and call it
	# "W climbs up": the driver checked against itself. `InputFrame` says +1 is up, and the two readers agree
	# -- so the pin goes through a reader: a line reeled with W's frame gets SHORTER.
	var line: Grapple = Grapple.new()
	line.restore({"state": Grapple.State.ANCHORED, "length": Grapple.MAX_RANGE, "anchor": [0, 0], "tip": [0, 0]})
	var before: int = line.length
	line.reel(g.climb_dir)
	_check(g.climb_dir == 1 and line.length < before, "W is +1, the contract's up: the anchored line reels in under it (%d -> %d)" % [before, line.length])
	var s_frame: InputFrame = hands.read(_hand({Controls.CLIMB_DOWN: true}), Vector2.ZERO, 4, yes)
	line.reel(s_frame.climb_dir)
	_check(s_frame.climb_dir == -1 and line.length > before - Grapple.REEL_PER_TICK, "S is -1, down: the same line pays out")
	_check(hands.read(_hand({Controls.MINE: true}), Vector2.ZERO, 4, yes).mine_held, "the pick is a hold, not an edge")
	_check(PlayInput.aim_logic_of(f) == Vector2i(3, 1) and PlayInput.aim_logic_of(hands.read(_hand({}), Vector2(-10.0, 0.0), 4, no)) == PlayInput.NONE, "the aimed metre, or NONE without an aim")


func _test_the_verbs() -> void:
	var hands: PlayInput = PlayInput.new()
	var none_digit: Callable = func(_i: int) -> bool: return false
	var cmds: Array[Command] = hands.verbs(_hand({Controls.BUILD: true, Controls.DROP: true}), none_digit, Vector2i(4, 9), false)
	var kinds: Array = []
	for c: Command in cmds:
		kinds.append(c.kind)
	_check(kinds.has(Command.Kind.BUILD) and kinds.has(Command.Kind.DROP) and cmds.size() == 2, "build at the aimed metre and drop, on their press edges (%d commands)" % cmds.size())
	_check(hands.verbs(_hand({Controls.BUILD: true, Controls.DROP: true}), none_digit, Vector2i(4, 9), false).is_empty(), "...and nothing while they stay held")
	_check(hands.verbs(_hand({Controls.BUILD: true}), none_digit, PlayInput.NONE, false).is_empty(), "a build with no aim is nothing")
	var ten: Callable = func(i: int) -> bool: return i == 9
	var tenth: Array[Command] = hands.verbs(_hand({}), ten, PlayInput.NONE, false)
	_check(tenth.size() == 1 and tenth[0].kind == Command.Kind.SELECT and tenth[0].index == 9, "the tenth digit -- the 0 key -- selects slot 9 (D0412: it was labelled and unreachable)")
	_check(Main._digit_down(9) == false and Main._digit_down(0) == false, "no digit is down in a headless test (the poll runs; the 0 key is the tenth)")
	var two: Callable = func(i: int) -> bool: return i == 2
	var sel: Array[Command] = hands.verbs(_hand({}), two, PlayInput.NONE, false)
	_check(sel.size() == 1 and sel[0].kind == Command.Kind.SELECT and sel[0].index == 2, "the third digit selects slot 2")
	_check(hands.verbs(_hand({}), two, PlayInput.NONE, false).is_empty(), "...once per hold")
	# D0409: with auto-pickup on, the hand collects EVERY tick with no key -- legacy's frame-rate pickup;
	# with it off, never. The walk-over pickup is what makes "collect the ingots" a thing a player can do.
	var quiet: Array[Command] = hands.verbs(_hand({}), none_digit, PlayInput.NONE, true)
	_check(quiet.size() == 1 and quiet[0].kind == Command.Kind.COLLECT, "auto-pickup on: a collect every tick, even with no key down")
	var again: Array[Command] = hands.verbs(_hand({}), none_digit, PlayInput.NONE, true)
	_check(again.size() == 1 and again[0].kind == Command.Kind.COLLECT, "...and again the next tick: not an edge, a standing verb")
	_check(hands.verbs(_hand({}), none_digit, PlayInput.NONE, false).is_empty(), "auto-pickup off: nothing")
	var keys: Dictionary = hands.hud_keys(_hand({Controls.SETTINGS: true}))
	_check(bool(keys["settings"]) and not bool(keys["map"]) and not bool(keys["save"]), "the settings key on its edge, the others quiet")
	_check(not bool(hands.hud_keys(_hand({Controls.SETTINGS: true}))["settings"]), "...and not again while held")


func _test_the_hud_bridge() -> void:
	Settings.persist = false
	Controls.register()
	var snap: Dictionary = HudBridge.snapshot()
	_check(snap.has("levels") and snap.has("bindings") and snap.has("muted") and snap.has("zoom_label") and snap.has("shake") and snap.has("auto_pickup"), "the snapshot carries everything the page reads")
	_check((snap["levels"] as Dictionary).has("sound") and (snap["bindings"] as Dictionary).has(Controls.MINE), "...the sound level and the mine binding among them")
	var page: SettingsPage = SettingsPage.new()
	var was_muted: bool = Settings.muted
	_check(HudBridge.apply({"toggle": "mute"}, page, 0.0) == &"toggle" and Settings.muted != was_muted, "the mute payload flips the mute")
	HudBridge.apply({"toggle": "mute"}, page, 0.0)
	var was_zoom: int = Settings.zoom_idx
	HudBridge.apply({"cycle": "zoom"}, page, 0.0)
	_check(Settings.zoom_idx == (was_zoom + 1) % CameraRig.ZOOM_LEVELS.size(), "the zoom cycles through the rig's levels")
	Settings.zoom_idx = was_zoom
	page.set_slider_rect("sound", Rect2(100.0, 0.0, 200.0, 10.0))
	var was_sound: float = Settings.sound
	HudBridge.apply({"slider": "sound"}, page, 150.0)
	_check(is_equal_approx(Settings.sound, 0.25), "a slider click a quarter along sets the level to 0.25 (%.2f)" % Settings.sound)
	Settings.sound = was_sound
	Settings.apply_audio()
	_check(HudBridge.apply({"bind": String(Controls.JUMP)}, page, 0.0) == &"capture" and page.capture == Controls.JUMP, "a bind payload arms the capture")
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_J
	_check(HudBridge.spec_of(ev) == {"key": KEY_J}, "a key press is a key spec")
	var rel := InputEventKey.new()
	rel.pressed = false
	_check(HudBridge.spec_of(rel).is_empty() and not HudBridge.finish_capture(page, rel), "a release binds nothing and leaves the capture armed")
	page.capture = &""
	_check(HudBridge.apply({}, page, 0.0) == &"", "an empty payload changes nothing")
	# The GAME face (D0396): the rail answers a click, a digit picks a slot, NEW GAME asks twice.
	_check(HudBridge.apply({"cat": SettingsPage.CAT_GAME}, page, 0.0) == &"cat" and page.cat == SettingsPage.CAT_GAME, "the rail's own payload turns the category")
	_check(HudBridge.key(page, KEY_1).is_empty() and page.cat == SettingsPage.RAIL_ORDER[0], "digit 1 is the first rail slot")
	_check(HudBridge.key(page, KEY_4).is_empty() and page.cat == SettingsPage.RAIL_ORDER[3], "digit 4 the fourth")
	_check(HudBridge.apply({"game": "new"}, page, 0.0) == &"armed" and page.armed == "new", "the first press of NEW GAME arms, nothing else")
	_check(HudBridge.apply({"game": "surface"}, page, 0.0) == &"surface" and page.armed == "", "RETURN TO SURFACE acts at once and disarms")
	HudBridge.apply({"game": "new"}, page, 0.0)
	_check(HudBridge.apply({"game": "new"}, page, 0.0) == &"new_game" and page.armed == "", "the second press is the one that acts")
	HudBridge.apply({"game": "new"}, page, 0.0)
	page.set_cat(SettingsPage.CAT_AUDIO)
	_check(page.armed == "", "turning the category disarms")
	_check(SettingsPage.row_payload(SettingsPage.CAT_GAME, 0) == {"game": "surface"} and SettingsPage.row_payload(SettingsPage.CAT_GAME, 1) == {"game": "new"} and SettingsPage.row_payload(SettingsPage.CAT_GAME, 9) == {"game": "new"}, "the GAME rows' payloads, clamped past the end")


func _test_a_headless_boot_ticks_and_saves() -> void:
	var main: Main = Main.new()
	main.autoboot = false
	root.add_child(main)
	await process_frame
	var ok: bool = main.boot(false)
	_check(ok and main.booted and main.door != null and main.view != null, "a headless boot builds the door and the view")
	_check(main.stack != null and main.stack.settings != null and main.stack.minimap != null and main.stack.hints != null, "...with the HUD handles the shell drives")
	var placed: int = (main.door.services()["machines"] as Machines).machines.size()
	_check(placed >= 2, "the tutorial start stamped its two processors (%d machines)" % placed)
	for _i: int in 4:
		await process_frame
	_check(main.tick > 0, "the seat ticks on its own (%d ticks)" % main.tick)
	var env: Dictionary = main.capture_session()
	_check(env.has(Session.KEY_BODY) and env.has(Main.KEY_HINTS), "a captured session carries the body and the hints' lessons")
	_check(main.restore(env), "...and restores over itself")
	_check(not main.restore({}), "an empty envelope is refused")
	# D0397: a session built from the envelope alone, no shaft generated under it, is the same session.
	var direct: Interface = Session.from_save(env)
	_check(direct != null and direct.state_signature() == main.door.state_signature(), "Session.from_save builds the restored session without generating: same signature")
	var no_dims: Dictionary = env.duplicate()
	no_dims.erase("width")
	_check(Session.from_save(no_dims) == null and SaveGame.last_invalid.begins_with("missing key"), "...and refuses an envelope without the world's dimensions, naming the key")
	# The two doors of the GAME face (D0396), on this booted seat.
	var body: Body = main.door.services()["body"]
	var home := Vector2i(body.pos_x, body.pos_y)
	body.place(body.pos_x, body.pos_y + 40 * Interface.Observation.CELL_PX * Fx.SCALE)   # forty cells down: in the rock, the way a stranded body might be
	body.grapple.restore({"state": Grapple.State.ANCHORED, "length": Grapple.MAX_RANGE, "anchor": [0, 0], "tip": [0, 0]})
	main.return_to_surface()
	var back := Vector2i(body.pos_x, body.pos_y)
	_check(absi(back.x - home.x) <= Interface.Observation.CELL_PX * Fx.SCALE * 4 and back.y <= home.y + Interface.Observation.CELL_PX * Fx.SCALE, "RETURN TO SURFACE stands the body at the spawn again (home %s, back %s)" % [home, back])
	_check(body.grapple.state == Grapple.State.IDLE and body.vel_y == 0, "...with the line stowed and no velocity carried")
	var scratch: String = "user://test_main_boot_slot.save"
	main.save_path = scratch
	Settings.persist = true
	_check(not main.retire_slot(), "no slot on disk: nothing to retire")
	var f: FileAccess = FileAccess.open(scratch, FileAccess.WRITE)
	f.store_string("x")
	f.close()
	_check(main.retire_slot() and not FileAccess.file_exists(scratch) and FileAccess.file_exists(scratch + SaveGame.BAK_SUFFIX), "NEW GAME moves the slot to .bak rather than deleting it")
	DirAccess.remove_absolute(scratch + SaveGame.BAK_SUFFIX)
	Settings.persist = false
	main.queue_free()
