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
	bridge.apply({"buttons": [1]}, root)
	_check(not Input.is_physical_key_pressed(KEY_D), "key released while mouse pressed")
	_check(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "mouse hold reaches input")
	bridge.apply({}, root)
	_check(not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT), "empty input releases mouse")
	_finish("playtest input")
