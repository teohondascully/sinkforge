extends "res://tests/test_base.gd"

## THE SCREEN-LED PLAYTEST BRIDGE (`playtest/input_bridge.gd`, 3a6d0d54; D0419). Removing a release edge,
## accepting an invalid burst, or delivering a key as a keycode without its ACTION must fail here; and the
## pointer must be the seat's own, posed at the named pixel, because in a headed window the viewport's
## mouse position is the operating system's cursor and no injected event moves it.

const PATH: String = "res://playtest/input_bridge.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(ResourceLoader.exists(PATH), "physical-input bridge exists")
	if not ResourceLoader.exists(PATH):
		_finish("playtest input")
		return
	var bridge: RefCounted = load(PATH).new()
	_test_bounds(bridge)
	_test_keys_and_buttons_as_actions(bridge)
	await _test_the_pointer_is_the_seats_own(bridge)
	_finish("playtest input")


func _test_bounds(bridge: RefCounted) -> void:
	_check(bridge.validate({"ticks": 0}) != "", "reject zero-duration action")
	_check(bridge.validate({"ticks": 301}) != "", "bound unattended input duration")
	_check(bridge.validate({"ticks": 1, "keys": ["NOT_A_KEY"]}) != "", "reject unknown physical keys")
	_check(bridge.validate({"ticks": 1, "mouse": [-1, 20]}) != "", "reject off-viewport pointer")
	_check(bridge.validate({"ticks": 1, "buttons": [8]}) != "", "reject unsupported mouse buttons")
	_check(bridge.validate({"ticks": 1, "keys": ["D"], "mouse": [200, 300]}) == "", "ordinary input accepted")
	_check(bridge.validate(JSON.parse_string('{"ticks":60,"buttons":[1],"mouse":[602,415]}')) == "", "JSON numeric buttons accepted")


func _test_keys_and_buttons_as_actions(bridge: RefCounted) -> void:
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


## A pushed event never moved `Viewport.get_mouse_position()` (the first screen-led attempt's LMB bursts
## mined nothing), and in a headed window that position is the OS cursor anyway. So the bridge parses the
## motion through the Input singleton AND poses the seat's pointer (`Controls.pose_pointer`, the `--act`
## captures' own hook) at the named pixel through the canvas transform. The player names a screen pixel.
func _test_the_pointer_is_the_seats_own(bridge: RefCounted) -> void:
	var before: Vector2 = root.get_mouse_position()
	bridge.apply({"mouse": [300, 200]}, root)
	await process_frame
	var moved: Vector2 = root.get_mouse_position()
	_check(moved != before, "a mouse burst moves the viewport's own mouse position (%s -> %s)" % [before, moved])
	bridge.apply({"mouse": [900, 500]}, root)
	await process_frame
	var again: Vector2 = root.get_mouse_position()
	_check(again != moved and (again - moved).x > 0.0 and (again - moved).y > 0.0, "and a second burst moves it the way the pointer went (%s -> %s)" % [moved, again])
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
