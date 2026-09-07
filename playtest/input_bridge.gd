extends RefCounted

## Viewport coordinates and physical input only. No simulation access.
var held_keys: Array = []
var held_buttons: Array = []
var pointer: Vector2 = Vector2(640, 360)


## The whole command: a flat burst, or `moves`, a sequence of timed segments run inside the game loop with
## one screenshot at the end (D0420) -- "Space and D for 10 ticks, then D for 30, then A for 20" -- so a
## move that needs mid-air steering does not wait on a screenshot per key change. The sequence is bounded
## like one burst (300 ticks in all) and each segment is validated like one.
func validate(command: Dictionary) -> String:
	if command.has("moves"):
		var moves: Variant = command["moves"]
		if not moves is Array or (moves as Array).is_empty():
			return "moves must be a non-empty list of segments"
		var total: int = 0
		for seg: Variant in moves:
			if not seg is Dictionary or (seg as Dictionary).has("moves"):
				return "each segment must be a flat burst"
			var error: String = _validate_segment(seg)
			if error != "":
				return error
			total += int((seg as Dictionary).get("ticks", 1))
		if total > MAX_TICKS:
			return "moves must total at most %d ticks" % MAX_TICKS
		return ""
	return _validate_segment(command)


## How long the command runs, in ticks: the sum of its segments.
func total_ticks(command: Dictionary) -> int:
	if command.has("moves"):
		var total: int = 0
		for seg: Variant in command["moves"]:
			total += int((seg as Dictionary).get("ticks", 1))
		return total
	return int(command.get("ticks", 1))


## Stage a validated command; the seat then pulls one segment per boundary with `next_segment`.
func begin(command: Dictionary) -> void:
	_queue = command["moves"].duplicate() if command.has("moves") else [command]


## Apply the next segment and return its length in ticks, or -1 when the sequence is spent.
func next_segment(viewport: Viewport) -> int:
	if _queue.is_empty():
		return -1
	var seg: Dictionary = _queue.pop_front()
	apply(seg, viewport)
	return int(seg.get("ticks", 1))


const MAX_TICKS: int = 300
var _queue: Array = []


func _validate_segment(command: Dictionary) -> String:
	var ticks: Variant = command.get("ticks", 1)
	if not (ticks is int or ticks is float) or float(ticks) != int(ticks) or int(ticks) < 1 or int(ticks) > MAX_TICKS:
		return "ticks must be an integer in 1..%d" % MAX_TICKS
	var keys: Variant = command.get("keys", [])
	if not keys is Array:
		return "keys must be an array"
	for key: Variant in keys:
		if not key is String or OS.find_keycode_from_string(key) == KEY_NONE:
			return "unknown physical key"
	var buttons: Variant = command.get("buttons", [])
	if not buttons is Array:
		return "buttons must be an array"
	for button: Variant in buttons:
		if not (button is int or button is float) or float(button) != int(button) or int(button) < 1 or int(button) > 3:
			return "buttons must be 1, 2, or 3"
	var mouse: Variant = command.get("mouse", [pointer.x, pointer.y])
	if not mouse is Array or mouse.size() != 2:
		return "mouse must be [x,y]"
	for value: Variant in mouse:
		if not (value is int or value is float) or not is_finite(float(value)):
			return "mouse coordinates must be finite numbers"
	if float(mouse[0]) < 0 or float(mouse[0]) >= 1280 or float(mouse[1]) < 0 or float(mouse[1]) >= 720:
		return "mouse must be inside 1280x720 viewport"
	return ""


func apply(command: Dictionary, _viewport: Viewport) -> void:
	var keys: Array = command.get("keys", [])
	var buttons: Array = command.get("buttons", [])
	for key: Variant in held_keys:
		if key not in keys:
			_key(String(key), false)
	for key: Variant in keys:
		if key not in held_keys:
			_key(String(key), true)
	held_keys = keys.duplicate()
	var mouse: Array = command.get("mouse", [pointer.x, pointer.y])
	var next: Vector2 = Vector2(float(mouse[0]), float(mouse[1]))
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = next
	motion.global_position = next
	motion.relative = next - pointer
	# The motion goes through the Input singleton (a pushed event never reached the viewport's mouse
	# position at all), AND the seat's pointer is POSED at the named pixel: in a headed window the
	# viewport's mouse position is the operating system's cursor, so no injected event can move the aim,
	# and the first screen-led attempt's LMB bursts followed the tester's own hand. `Controls.pose_pointer`
	# is the seat's own scripted-hand hook (the `--act=mine` capture path); the player still names a
	# viewport pixel and nothing else. `tests/test_playtest_input.gd` pins both.
	Input.parse_input_event(motion)
	Controls.pose_pointer(_viewport.get_canvas_transform().affine_inverse() * next)
	pointer = next
	for button: Variant in held_buttons:
		if button not in buttons:
			_button(int(button), false)
	for button: Variant in buttons:
		if button not in held_buttons:
			_button(int(button), true)
	held_buttons = buttons.duplicate()
	Input.flush_buffered_events()


func _key(label: String, down: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = OS.find_keycode_from_string(label)
	event.keycode = event.physical_keycode
	event.pressed = down
	Input.parse_input_event(event)


func _button(index: int, down: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = index as MouseButton
	event.pressed = down
	event.position = pointer
	event.global_position = pointer
	Input.parse_input_event(event)
