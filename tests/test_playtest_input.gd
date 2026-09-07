extends "res://tests/test_base.gd"

## Removing release edges or accepting invalid bursts must fail this test.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var path: String = "res://playtest/input_bridge.gd"
	_check(ResourceLoader.exists(path), "physical-input bridge exists")
	if not ResourceLoader.exists(path):
		_finish("playtest input")
		return
	var bridge: RefCounted = load(path).new()
	_check(bridge.validate({"ticks": 0}) != "", "reject zero-duration action")
	_check(bridge.validate({"ticks": 301}) != "", "bound unattended input duration")
	_check(bridge.validate({"ticks": 1, "keys": ["NOT_A_KEY"]}) != "", "reject unknown physical keys")
	_check(bridge.validate({"ticks": 1, "mouse": [-1, 20]}) != "", "reject off-viewport pointer")
	_check(bridge.validate({"ticks": 1, "buttons": [8]}) != "", "reject unsupported mouse buttons")
	_check(bridge.validate({"ticks": 1, "keys": ["D"], "mouse": [200, 300]}) == "", "ordinary input accepted")
	_check(bridge.validate(JSON.parse_string('{"ticks":60,"buttons":[1],"mouse":[602,415]}')) == "", "JSON numeric buttons accepted")
	bridge.apply({"keys": ["D", "Space"]}, root)
	_check(Input.is_physical_key_pressed(KEY_D), "physical D reaches Input singleton")
	_check(Input.is_physical_key_pressed(KEY_SPACE), "physical Space reaches Input singleton")
	bridge.apply({"keys": ["D"]}, root)
	_check(not Input.is_physical_key_pressed(KEY_SPACE), "omitted key is released")
	_check(Input.is_physical_key_pressed(KEY_D), "continued hold survives next burst")
	Controls.register()   # the seat's bindings, so the ACTION can be read, not just the button
	bridge.apply({"buttons": [1]}, root)
	_check(not Input.is_physical_key_pressed(KEY_D), "key released while mouse pressed")
	_check(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "mouse hold reaches input")
	_check(Input.is_action_pressed(Controls.MINE), "LMB held reads as the MINE action the hand polls (Controls.pressed)")
	bridge.apply({"keys": ["A"]}, root)
	_check(Input.is_action_pressed(Controls.LEFT), "physical A reads as the LEFT action")
	bridge.apply({}, root)
	_check(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "empty input releases mouse")
	_check(not Input.is_action_pressed(Controls.MINE) and not Input.is_action_pressed(Controls.LEFT), "and releases the actions")
	# THE POINTER MUST REACH THE SEAT'S AIM. `Controls.pointer_world` reads `Viewport.get_mouse_position()`,
	# and a motion pushed with `Viewport.push_input` leaves it where it was (the first screen-led attempt's
	# LMB bursts mined nothing for this reason); the event has to go through `Input.parse_input_event`.
	var before: Vector2 = root.get_mouse_position()
	bridge.apply({"mouse": [300, 200]}, root)
	await process_frame
	var moved: Vector2 = root.get_mouse_position()
	_check(moved != before, "a mouse burst moves the viewport's own mouse position (%s -> %s)" % [before, moved])
	bridge.apply({"mouse": [900, 500]}, root)
	await process_frame
	var again: Vector2 = root.get_mouse_position()
	_check(again != moved and (again - moved).x > 0.0 and (again - moved).y > 0.0, "and a second burst moves it the way the pointer went (%s -> %s)" % [moved, again])
	# IN A HEADED WINDOW THE VIEWPORT'S MOUSE POSITION IS THE OPERATING SYSTEM'S CURSOR: no injected motion
	# moves it (a headed probe read the real cursor back after parsing an event at (618,405)), so the seat's
	# aim followed the tester's own hand, not the burst. The bridge therefore POSES the pointer the way the
	# seat's own scripted hand does (`Controls.pose_pointer`, the `--act=mine` capture path): the named
	# viewport pixel through the canvas transform. The player still names a screen pixel and nothing else.
	var probe: Node2D = Node2D.new()
	root.add_child(probe)
	bridge.apply({"mouse": [300, 200]}, root)
	_check(Controls.pointer_posed(), "a mouse burst poses the seat's pointer")
	_check(Controls.pointer_world(probe).is_equal_approx(root.get_canvas_transform().affine_inverse() * Vector2(300, 200)), "...at the named pixel through the canvas transform (%s)" % Controls.pointer_world(probe))
	_check(Controls.pointer_viewport(probe).is_equal_approx(Vector2(300, 200)), "...and reads back as that pixel (%s)" % Controls.pointer_viewport(probe))
	bridge.apply({}, root)
	_check(Controls.pointer_posed(), "an empty burst keeps the last pointer: a still hand is not a released one")
	probe.queue_free()
	Controls.release_pointer()
	_finish("playtest input")
