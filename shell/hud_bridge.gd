class_name HudBridge
extends RefCounted

## THE SHELL'S SIDE OF THE SETTINGS PAGE (A' step 6q, D0380). The view may not reach `shell/`, so the page
## paints a SNAPSHOT (`SettingsPage.state`) and answers a click with a PAYLOAD (`row_payload`); this is the
## one place that turns `Settings` into the snapshot and a payload back into a `Settings` change, so the
## page and the settings can only disagree here. Legacy's `Hud` did both inside its 2,189 lines.

const LEVEL_IDS: Array[String] = ["master", "sound", "ambience", "music"]


## What the page shows: the levels, the mute, the feel toggles, the zoom's label, every binding's label.
static func snapshot() -> Dictionary:
	var levels: Dictionary = {"master": Settings.master, "sound": Settings.sound, "ambience": Settings.ambience, "music": Settings.music}
	var bindings: Dictionary = {}
	for action: StringName in Controls.defaults():
		bindings[action] = SettingsBindings.binding_label(action)
	var zoom: float = CameraRig.ZOOM_LEVELS[clampi(Settings.zoom_idx, 0, CameraRig.ZOOM_LEVELS.size() - 1)]
	return {"levels": levels, "muted": Settings.muted, "shake": Settings.screen_shake, "auto_pickup": Settings.auto_pickup,
		"zoom_label": "%.2fx" % zoom, "bindings": bindings}


## Apply one payload the page answered a click or a key with. `canvas_x` is where the pointer was, for a
## slider. Returns what changed, for a test to read.
static func apply(payload: Dictionary, page: SettingsPage, canvas_x: float) -> StringName:
	if payload.has("toggle"):
		return toggle(String(payload["toggle"]))
	if payload.has("slider"):
		var id: String = String(payload["slider"])
		set_level(id, page.slider_frac(id, canvas_x))
		return &"level"
	if payload.has("cycle"):
		Settings.zoom_idx = (Settings.zoom_idx + 1) % CameraRig.ZOOM_LEVELS.size()
		Settings.save_settings()
		return &"zoom"
	if payload.has("bind"):
		page.capture = StringName(String(payload["bind"]))
		return &"capture"
	if payload.has("reset"):
		SettingsBindings.reset_bindings()
		return &"reset"
	if payload.has("game"):
		return game_verb(String(payload["game"]), page)
	if payload.has("cat"):   # the rail's own tabs: registered by the drawing since 6j, answered since D0396
		page.set_cat(int(payload["cat"]))
		return &"cat"
	return &""


## The GAME face's verdicts, for the seat to act on (D0396): `&"surface"` at once; `&"new_game"` only on
## the second press of an armed row, since it replaces the save. Any other press disarms.
static func game_verb(id: String, page: SettingsPage) -> StringName:
	if id == "surface":
		page.armed = ""
		return &"surface"
	if id == "new":
		if page.armed == "new":
			page.armed = ""
			return &"new_game"
		page.armed = "new"
		return &"armed"
	page.armed = ""
	return &""


static func toggle(id: String) -> StringName:
	match id:
		"mute":
			Settings.toggle_mute()
		"shake":
			Settings.screen_shake = not Settings.screen_shake
		"auto_pickup":
			Settings.auto_pickup = not Settings.auto_pickup
		_:
			return &""
	Settings.save_settings()
	return &"toggle"


static func set_level(id: String, frac: float) -> void:
	var v: float = clampf(frac, 0.0, 1.0)
	match id:
		"master": Settings.master = v
		"sound": Settings.sound = v
		"ambience": Settings.ambience = v
		"music": Settings.music = v
	Settings.apply_audio()
	Settings.save_settings()


## A key or mouse event as a binding spec, for the page's capture; {} for an event that cannot bind.
static func spec_of(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey and ev.pressed:
		return {"key": (ev as InputEventKey).physical_keycode}
	if ev is InputEventMouseButton and ev.pressed:
		return {"button": (ev as InputEventMouseButton).button_index}
	if ev is InputEventJoypadButton and ev.pressed:
		return {"pad": (ev as InputEventJoypadButton).button_index}
	return {}


## Finish a capture: rebind the awaited action to the event, clear the capture. False when the event
## cannot bind (a release, a motion).
static func finish_capture(page: SettingsPage, ev: InputEvent) -> bool:
	var spec: Dictionary = spec_of(ev)
	if spec.is_empty() or page.capture == &"":
		return false
	SettingsBindings.rebind(page.capture, spec)
	page.capture = &""
	return true


## A key on the open page: arrows move the focus, Enter or Space activates it, Tab turns the category,
## a digit picks the rail slot its label carries (D0396). Returns the payload activated, or {}.
static func key(page: SettingsPage, keycode: int) -> Dictionary:
	match keycode:
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
			page.move_row(keycode)
		KEY_TAB:
			page.set_cat(SettingsPage.clamp_cat((page.cat + 1) % SettingsPage.CAT_NAMES.size()))
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			return page.focus_payload()
	var slot: int = keycode - KEY_1
	if slot >= 0 and slot < SettingsPage.RAIL_ORDER.size():
		page.set_cat(SettingsPage.RAIL_ORDER[slot])
	return {}
