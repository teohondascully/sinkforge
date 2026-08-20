class_name Settings
extends RefCounted

## Player SETTINGS — the machine-local preferences: audio levels, screen-shake, zoom,
## and the key BINDINGS the Controls foundation was built for. All static (any layer reads without
## wiring), persisted to a ConfigFile in user:// — deliberately SEPARATE from SaveGame: a save is a
## world, settings are this machine/person (they survive new games and never travel with a save).
##
## REPRESENTATION-ONLY: nothing here is sim state. Audio applies as dB offsets the Sfx layer adds at
## play time, shake gates one camera line, zoom is the camera index, bindings rebind InputMap actions.
##
## HARNESS RULE: `persist` is FALSE by default and only a real (unscripted) boot turns it on + loads
## the file — so every fixture/test runs on pure defaults and can never read or clobber the dev's real
## settings. check_settings opts in explicitly on its own temp path.

## SOUND IS ON. A first boot has to be able to hear the machine it is standing in — the drill biting, the
## water finding a way down, the winch loading up — because roughly half of what this game tells you it
## tells you by ear, and a player who never opens the settings page never learns the audio is there at all.
## The mute itself is unchanged: still one switch over the whole mix rather than levels pinned to zero (see
## apply_audio), still persisted, so turning it OFF is equally a one-time act.
##
## This is the PLAYER's default, and fixtures do not inherit it: a scripted boot silences itself in
## main.gd::_ready(), the same way and in the same place it declines to persist. The harness stays quiet
## without the shipped default having to lie about what a new player hears.
static var muted: bool = false
static var master: float = 1.0          ## 0..1 — the Master bus (everything)
static var sound: float = 1.0           ## 0..1 — effect voices (positional pool + UI dings)
static var ambience: float = 1.0        ## 0..1 — the beds (hum, wind, cave-air, drips)
static var music: float = 1.0           ## 0..1 — the Score (the tonal beds that descend with you)
static var screen_shake: bool = true
static var auto_pickup: bool = true    ## walk-over auto-collect of ground items (playtest: make it optional)
static var zoom_idx: int = 0            ## index into MainView.ZOOM_LEVELS
## action name -> Array of event specs ({"key": physical keycode} | {"button": mouse button index}),
## same spec shape as Controls.defaults(). Only DIVERGENT actions live here; absent = default binding.
static var bindings: Dictionary = {}

static var persist: bool = false                     ## gate: load/save only when a real boot opts in
static var path: String = "user://settings.cfg"      ## overridable so the harness isolates its file


## Load the config (missing file = keep defaults) and apply everything live.
static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		muted = bool(cfg.get_value("audio", "muted", muted))
		master = clampf(float(cfg.get_value("audio", "master", master)), 0.0, 1.0)
		sound = clampf(float(cfg.get_value("audio", "sound", sound)), 0.0, 1.0)
		ambience = clampf(float(cfg.get_value("audio", "ambience", ambience)), 0.0, 1.0)
		music = clampf(float(cfg.get_value("audio", "music", music)), 0.0, 1.0)
		screen_shake = bool(cfg.get_value("feel", "screen_shake", screen_shake))
		auto_pickup = bool(cfg.get_value("feel", "auto_pickup", auto_pickup))
		zoom_idx = int(cfg.get_value("feel", "zoom_idx", zoom_idx))
		bindings = {}
		for key: String in cfg.get_section_keys("bindings") if cfg.has_section("bindings") else []:
			bindings[StringName(key)] = cfg.get_value("bindings", key)
	apply_audio()
	apply_bindings()


static func save_settings() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "sound", sound)
	cfg.set_value("audio", "ambience", ambience)
	cfg.set_value("audio", "music", music)
	cfg.set_value("feel", "screen_shake", screen_shake)
	cfg.set_value("feel", "auto_pickup", auto_pickup)
	cfg.set_value("feel", "zoom_idx", zoom_idx)
	for action: StringName in bindings:
		cfg.set_value("bindings", String(action), bindings[action])
	cfg.save(path)


## The Master bus follows the master slider; sound/ambience apply lazily as offsets (below).
##
## Mute is applied at the BUS, not by zeroing the levels: it is one switch over the whole mix, it cannot be
## half-on, and it leaves the sliders holding the values you chose so unmuting restores them exactly.
static func apply_audio() -> void:
	AudioServer.set_bus_mute(0, muted)
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(master, 0.0001, 1.0)))


## Flip the sound on or off and remember it. Returns the new state so a caller can say so on screen.
static func toggle_mute() -> bool:
	muted = not muted
	apply_audio()
	save_settings()
	return muted


## dB offsets the Sfx layer ADDS to its own baselines at play/frame time — 0 dB at full, ~-60 (gone)
## at the bottom of the slider. Lazy application means no player-node bookkeeping here.
static func sound_db() -> float:
	return linear_to_db(clampf(sound, 0.001, 1.0))


static func ambience_db() -> float:
	return linear_to_db(clampf(ambience, 0.001, 1.0))


static func music_db() -> float:
	return linear_to_db(clampf(music, 0.001, 1.0))


## Rebind an action to a single event spec, apply it live, persist. The old binding is fully replaced
## (one gesture per action keeps the page honest); reset_bindings() restores every default.
##
## THE NEW BINDING TAKES THE KEY. Any other action already holding it is UNBOUND and returned, so the
## caller can say so. `MNU-29a`: this function used to write the new key and return, with no conflict
## check of any kind — bind `jump` to `W` and `W` became `climb up` AND `jump`, both fired on every press,
## the config persisted it, and nothing anywhere said a word.
##
## STEAL RATHER THAN REFUSE, deliberately. Refusing would make a used key unbindable until you first went
## and cleared its owner, which is a chore in a page whose whole job is rebinding. Stealing cannot leave a
## duplicate behind, the displaced action is left VISIBLY `unbound` on its own row rather than quietly
## losing its key, and `reset_bindings()` is one chip away.
##
## THE PREDICATE IS `binding_label`, AND THAT IS NOT AN IMPLEMENTATION DETAIL. `Hud._binding_clashes()`
## marks a row as clashing by comparing the same labels. If the resolver compared something else —
## `InputMap.action_has_event`, or a hand-rolled spec equality — then the page could display a conflict
## the resolver did not resolve, or resolve one it never showed. **One predicate, or the display and the
## fix are about different things.** A fresh spec always yields a real event, so `label` here is never
## `"unbound"` and this cannot mass-unbind the actions that have no key.
static func rebind(action: StringName, spec: Dictionary) -> Array[StringName]:
	var label: String = event_label(Controls.event_from_spec(spec))
	var displaced: Array[StringName] = []
	for other: StringName in Controls.defaults():
		if other == action or not InputMap.has_action(other):
			continue
		if binding_label(other) == label:
			displaced.append(other)
			bindings[other] = []
			_apply_action(other, [])
	bindings[action] = [spec]
	_apply_action(action, [spec])
	save_settings()
	return displaced


## Push every saved override into InputMap (call AFTER Controls.register() has created the actions).
static func apply_bindings() -> void:
	for action: StringName in bindings:
		_apply_action(action, bindings[action])


static func reset_bindings() -> void:
	bindings = {}
	var specs: Dictionary = Controls.defaults()
	for action: StringName in specs:
		_apply_action(action, specs[action])
	save_settings()


static func _apply_action(action: StringName, specs: Array) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	# Built by Controls, not here. This function used to carry its own copy of the if/else, which was fine
	# while a spec could only be a key or a mouse button and stopped being fine the moment gamepad specs
	# existed: an unrecognised spec fell out of the `else` and came back as a mouse button, so a player's
	# saved pad binding would silently reload as a click.
	for spec_v: Variant in specs:
		InputMap.action_add_event(action, Controls.event_from_spec(spec_v as Dictionary))


## Human-readable label for an action's CURRENT binding (first event), for the remap page.
static func binding_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return "unbound"
	return event_label(events[0])


static func event_label(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		match code:
			KEY_SPACE: return "SPACE"
			KEY_ESCAPE: return "ESC"
			_: return OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_WHEEL_UP: return "WHEEL UP"
			MOUSE_BUTTON_WHEEL_DOWN: return "WHEEL DN"
			_: return "MB%d" % (ev as InputEventMouseButton).button_index
	# GAMEPAD LABELS ARE PREFIXED, every one of them, and that is not decoration. A bare "A" would collide
	# with the keyboard's A on any screen that lists bindings, and worse, `check_binding_text` reads these
	# labels to decide whether a key named in a tooltip is bound — an unprefixed pad face button would make
	# the prose "press A" look satisfied by a gamepad the player does not own.
	if ev is InputEventJoypadButton:
		match (ev as InputEventJoypadButton).button_index:
			JOY_BUTTON_A: return "PAD A"
			JOY_BUTTON_B: return "PAD B"
			JOY_BUTTON_X: return "PAD X"
			JOY_BUTTON_Y: return "PAD Y"
			JOY_BUTTON_LEFT_SHOULDER: return "PAD LB"
			JOY_BUTTON_RIGHT_SHOULDER: return "PAD RB"
			JOY_BUTTON_START: return "PAD START"
			JOY_BUTTON_BACK: return "PAD BACK"
			JOY_BUTTON_DPAD_UP: return "PAD UP"
			JOY_BUTTON_DPAD_DOWN: return "PAD DOWN"
			JOY_BUTTON_DPAD_LEFT: return "PAD LEFT"
			JOY_BUTTON_DPAD_RIGHT: return "PAD RIGHT"
			_: return "PAD %d" % (ev as InputEventJoypadButton).button_index
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		var back: bool = m.axis_value < 0.0
		match m.axis:
			JOY_AXIS_LEFT_X: return "STICK LEFT" if back else "STICK RIGHT"
			JOY_AXIS_LEFT_Y: return "STICK UP" if back else "STICK DOWN"
			JOY_AXIS_TRIGGER_LEFT: return "PAD LT"
			JOY_AXIS_TRIGGER_RIGHT: return "PAD RT"
			_: return "AXIS %d%s" % [m.axis, "-" if back else "+"]
	return "?"
