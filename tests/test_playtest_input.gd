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
	_test_composed_moves(bridge)
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


## COMPOSED MOVES (D0420): one command may carry a sequence of timed segments -- "Space and D for 10
## ticks, then D for 30, then A for 20" -- run inside the game loop with one screenshot at the end, so a
## move that needs mid-air steering does not depend on a screenshot round trip per key change. The whole
## sequence is bounded like a single burst; each segment is validated like one; the seat pulls segments
## with `next_segment` and the bridge applies each at its boundary.
func _test_composed_moves(bridge: RefCounted) -> void:
	var jump_right: Dictionary = {"moves": [{"ticks": 10, "keys": ["Space", "D"]}, {"ticks": 30, "keys": ["D"]}, {"ticks": 20, "keys": ["A"], "mouse": [400, 300]}]}
	_check(bridge.validate(jump_right) == "", "a composed move validates as a whole (%s)" % bridge.validate(jump_right))
	_check(bridge.validate({"moves": [{"ticks": 200}, {"ticks": 101}]}) != "", "the segments' total is bounded like one burst (301)")
	_check(bridge.validate({"moves": [{"ticks": 10, "keys": ["NOT_A_KEY"]}]}) != "", "a bad key inside a segment is refused")
	_check(bridge.validate({"moves": []}) != "", "an empty sequence is refused")
	_check(bridge.validate({"moves": "D"}) != "", "moves must be a list")
	_check(bridge.total_ticks(jump_right) == 60, "the sequence lasts the sum of its segments (%d)" % bridge.total_ticks(jump_right))
	_check(bridge.total_ticks({"ticks": 45, "keys": ["D"]}) == 45, "a flat burst is one segment (%d)" % bridge.total_ticks({"ticks": 45, "keys": ["D"]}))
	bridge.begin(jump_right)
	_check(bridge.next_segment(root) == 10 and Input.is_physical_key_pressed(KEY_SPACE) and Input.is_physical_key_pressed(KEY_D), "segment 1: Space and D down for 10 ticks")
	_check(bridge.next_segment(root) == 30 and not Input.is_physical_key_pressed(KEY_SPACE) and Input.is_physical_key_pressed(KEY_D), "segment 2: Space released at the boundary, D held on")
	_check(bridge.next_segment(root) == 20 and Input.is_physical_key_pressed(KEY_A) and not Input.is_physical_key_pressed(KEY_D) and bridge.pointer == Vector2(400, 300), "segment 3: A, and the pointer moved with it")
	_check(bridge.next_segment(root) == -1, "then nothing: the sequence is spent")
	bridge.begin({"ticks": 5, "keys": ["W"]})
	_check(bridge.next_segment(root) == 5 and Input.is_physical_key_pressed(KEY_W) and not Input.is_physical_key_pressed(KEY_A), "a flat burst still runs as one segment, releasing what the sequence left down")
	_check(bridge.next_segment(root) == -1, "...and is spent after it")
	bridge.apply({}, root)
