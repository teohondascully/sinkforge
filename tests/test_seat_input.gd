extends "res://tests/test_base.gd"

## THE DISPATCH SEAM, DRIVEN WITH REAL EVENTS (D0654, queue C2). Every other suite that touches the
## settings page's input calls `HudBridge.key(page, KEY_*)` directly -- which is exactly where bug class
## D0446 lived: ESC was handled in `_unhandled_input` AND re-toggled by the HUD-key edge in the same
## tick, so the page could never be left by the key its own footer names. Nothing asserted the seam
## between a hardware event and that bridge. This suite constructs real `InputEventKey`s and pushes
## them through `Input.parse_input_event` -- the same pipeline a hardware key takes -- into the live
## booted seat, and asserts the page toggles ONCE per press: K opens and closes on the tick's edge,
## ESC closes and stays closed, a routed arrow moves the page cursor, and a held RIGHT under the open
## page is deaf to the body.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_seat_input.gd


func _initialize() -> void:
	await _test_a_real_key_event_toggles_the_page_once_per_press()
	await _test_escape_closes_once_and_a_routed_key_moves_the_page_cursor()
	_finish("seat_input")


## A synthetic key the way a hardware one arrives: both keycodes set (the InputMap binds on
## `physical_keycode`; `HudBridge.key` reads `keycode`), no echo, so one event is one press.
func _key(code: int, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = pressed
	ev.keycode = code
	ev.physical_keycode = code
	return ev


func _seat() -> Main:
	var main: Main = Main.new()
	main.autoboot = false
	root.add_child(main)
	return main


func _test_a_real_key_event_toggles_the_page_once_per_press() -> void:
	var main: Main = _seat()
	await process_frame
	if not main.boot(false):
		_check(false, "the seat boots headless")
		return
	var page: SettingsPage = main.stack.settings
	_check(not page.open, "the page starts closed")
	# K through the engine's own input pipeline -- the SETTINGS action's key (Controls.defaults).
	Input.parse_input_event(_key(KEY_K, true))
	await process_frame   # one tree iteration: the event is delivered, the action pressed, _unhandled_input ran
	_check(Input.is_action_pressed(Controls.SETTINGS), "the synthetic K press reached the InputMap action")
	for _i: int in 4:
		main._physics_process(1.0 / 60.0)
	_check(page.open, "one K press opens the page exactly once (the tick's edge, not the callback)")
	Input.parse_input_event(_key(KEY_K, false))
	await process_frame
	Input.parse_input_event(_key(KEY_K, true))
	await process_frame
	for _i: int in 4:
		main._physics_process(1.0 / 60.0)
	_check(not page.open, "the second press closes it -- exactly once")
	Input.parse_input_event(_key(KEY_K, false))
	await process_frame
	for _i: int in 4:
		main._physics_process(1.0 / 60.0)
	_check(not page.open, "...and it stays closed across further ticks (the D0446 double-toggle shape)")
	main.queue_free()
	await process_frame


func _test_escape_closes_once_and_a_routed_key_moves_the_page_cursor() -> void:
	var main: Main = _seat()
	await process_frame
	if not main.boot(false):
		_check(false, "the seat boots headless")
		return
	var page: SettingsPage = main.stack.settings
	Input.parse_input_event(_key(KEY_K, true))
	await process_frame
	for _i: int in 4:
		main._physics_process(1.0 / 60.0)
	_check(page.open, "K opened the page")
	Input.parse_input_event(_key(KEY_K, false))
	await process_frame
	# ESC is bound to the same SETTINGS action and was D0446's re-toggle: the callback must NOT close it
	# a second way. Under the defect the page ended this press OPEN again -- closed is the assertion.
	Input.parse_input_event(_key(KEY_ESCAPE, true))
	await process_frame
	for _i: int in 4:
		main._physics_process(1.0 / 60.0)
	_check(not page.open, "ESC closes the open page -- once, not twice in one tick (D0446)")
	Input.parse_input_event(_key(KEY_ESCAPE, false))
	await process_frame
	for _i: int in 4:
		main._physics_process(1.0 / 60.0)
	_check(not page.open, "...and it stays closed")
	# Re-open, then a routed key: a real DOWN event lands in _unhandled_input -> HudBridge.key -> the cursor.
	Input.parse_input_event(_key(KEY_K, true))
	await process_frame
	for _i: int in 4:
		main._physics_process(1.0 / 60.0)
	Input.parse_input_event(_key(KEY_K, false))
	await process_frame
	var row0: int = page.row
	Input.parse_input_event(_key(KEY_DOWN, true))
	await process_frame
	_check(page.row != row0, "a real DOWN event routed through _unhandled_input moved the page cursor (%d -> %d)" % [row0, page.row])
	Input.parse_input_event(_key(KEY_DOWN, false))
	await process_frame
	# The modal deafens the hands through the same real pipeline: a held RIGHT moves nothing.
	var body: Body = main.door.services()["body"]
	var x0: int = body.pos_x
	Input.parse_input_event(_key(KEY_D, true))
	await process_frame
	_check(Input.is_action_pressed(Controls.RIGHT), "the held RIGHT reached the InputMap action")
	for _i: int in 6:
		main._physics_process(1.0 / 60.0)
	_check(body.pos_x == x0, "...but the open page deafens it: the body does not move (%d Fx)" % (body.pos_x - x0))
	Input.parse_input_event(_key(KEY_D, false))
	await process_frame
	main.queue_free()
	await process_frame
