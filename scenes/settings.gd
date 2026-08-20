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


## Rebind an action to one event spec, apply it live, persist. `reset_bindings()` restores every default.
##
## IT USED TO REPLACE THE WHOLE BINDING, and the docstring defended that: "the old binding is fully
## replaced (one gesture per action keeps the page honest)". That sentence was true when a binding WAS one
## gesture. It stopped being true when the gamepad layer landed. `Controls.defaults()` gives 14 of its 25
## actions two or three events, so `bindings[action] = [spec]` followed by `_apply_action`'s
## `action_erase_events` meant **every rebind silently destroyed that action's other events** — rebind
## grapple to a key and middle-mouse-grapple and right-bumper-grapple are gone. On EVERY rebind, not only
## a colliding one; with nothing announced, since `_announce_rebind` only reports displaced OTHER actions;
## persisted by `save_settings` and reapplied by `load_settings` on every boot afterwards. `check_gamepad`
## cannot see it, because it reads the static defaults TABLE and never asks `InputMap` what is live.
##
## Now a rebind moves ONE event: the new spec replaces the action's event of the same DEVICE — desk for
## desk, pad for pad — and everything else is left alone. A player remapping their keyboard has not asked
## to lose their controller.
##
## STEAL RATHER THAN REFUSE, deliberately. Refusing would make a used key unbindable until you first went
## and cleared its owner, which is a chore in a page whose whole job is rebinding. Stealing cannot leave a
## duplicate behind, the displaced action loses only the ONE event that collided rather than its whole
## binding, and `reset_bindings()` is one chip away.
##
## ONE PREDICATE, AND IT IS NOW AT THE RIGHT GRAIN. `Hud._binding_clashes()` marks a row as clashing with
## the same comparison this resolver uses, so the page cannot show a conflict the resolver declines to fix
## or fix one it never showed. That doctrine was already written here, and it was being applied to the
## WRONG QUANTITY: both sides compared `binding_label`, which is `events[0]`. Most actions have more than
## one event, so a collision on any of the others was invisible to the detector AND to the resolver. The
## live repro was three inputs from the shipped page — CONTROLS, `jump`, press the up arrow — after which
## the arrow climbs and jumps on every press and the page says nothing.
##
## **The original fix's own demonstration (`jump` -> `W`) passed only because `W` happens to be `sf_up`'s
## FIRST event.** It was run on the one input where the bug was visible to the instrument measuring it.
## Both sides now compare `event_labels()`, which is every event of every action. A fresh spec always
## yields a real event, so `label` here is never `"unbound"` and this cannot mass-unbind keyless actions.
static func rebind(action: StringName, spec: Dictionary) -> Array[StringName]:
	var label: String = event_label(Controls.event_from_spec(spec))
	var displaced: Array[StringName] = []
	for other: StringName in Controls.defaults():
		if other == action or not InputMap.has_action(other):
			continue
		var kept: Array = []
		var took: bool = false
		for s: Variant in specs_of(other):
			if event_label(Controls.event_from_spec(s as Dictionary)) == label:
				took = true          # this ONE event moves; the rest of the action stays where it was
			else:
				kept.append(s)
		if took:
			displaced.append(other)
			bindings[other] = kept
			_apply_action(other, kept)
	# The action being bound keeps everything that is not the same DEVICE and not the same key. Dropping the
	# same-label entry first is what stops an action colliding with itself: binding grapple to the middle
	# mouse button, which grapple already answers to, would otherwise leave it holding MMB twice.
	var mine: Array = []
	for s: Variant in specs_of(action):
		if event_label(Controls.event_from_spec(s as Dictionary)) != label:
			mine.append(s)
	var device: int = _device_of(spec)
	var placed: bool = false
	for i: int in mine.size():
		if _device_of(mine[i] as Dictionary) == device:
			mine[i] = spec
			placed = true
			break
	if not placed:
		mine.insert(0, spec)
	bindings[action] = mine
	_apply_action(action, mine)
	save_settings()
	return displaced


## WHICH DEVICE a spec speaks for. Rebinding a desk input replaces the action's desk input and leaves the
## pad alone, which is the entire point of the distinction: a player remapping the keyboard has not asked
## to lose their controller.
const DESK: int = 0
const PAD: int = 1


static func _device_of(spec: Dictionary) -> int:
	return PAD if (spec.has("pad") or spec.has("axis")) else DESK


## The action's CURRENT full spec list — its override if it has one, otherwise the defaults it is still
## running on. `bindings` holds only overrides, so reading it directly reports an empty list for every
## action nobody has touched, and writing that back is how the whole binding got erased.
static func specs_of(action: StringName) -> Array:
	if bindings.has(action):
		return (bindings[action] as Array).duplicate()
	var d: Dictionary = Controls.defaults()
	return (d[action] as Array).duplicate() if d.has(action) else []


## EVERY label the action answers to, not just the first. `binding_label` returns `events[0]` because a row
## has room for one chip; identity is a different question from display and needs all of them.
static func event_labels(action: StringName) -> Array[String]:
	var out: Array[String] = []
	if not InputMap.has_action(action):
		return out
	for ev: InputEvent in InputMap.action_get_events(action):
		out.append(event_label(ev))
	return out


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


## Engine keycode names are developer identifiers, not keycaps. `OS.get_keycode_string(KEY_PERIOD)` is
## `"Period"` — which shipped onto the CONTROLS page beside `M`, `T`, `Z` and `X`, in TitleCase, three
## times wider than every other cap in the column. A keycap shows what is PRINTED ON THE KEY, so
## punctuation resolves to its glyph and named keys to a short shout matching the existing `SPACE`/`ESC`.
##
## EVERY LABEL HERE MUST BE UNIQUE. This function is not only display: `_spec_conflict` decides whether
## two bindings collide by comparing their labels (:142-163), so any two keycodes that share a label
## become the same key to the conflict detector. That is why ENTER and the keypad's are `ENTER`/`NUM ENT`
## and not both `ENTER`, and why the fallback upper-cases rather than truncating.
const KEY_CAPS: Dictionary = {
	KEY_SPACE: "SPACE", KEY_ESCAPE: "ESC", KEY_ENTER: "ENTER", KEY_TAB: "TAB",
	KEY_BACKSPACE: "BKSP", KEY_DELETE: "DEL", KEY_INSERT: "INS",
	KEY_HOME: "HOME", KEY_END: "END", KEY_PAGEUP: "PGUP", KEY_PAGEDOWN: "PGDN",
	KEY_LEFT: "LEFT", KEY_RIGHT: "RIGHT", KEY_UP: "UP", KEY_DOWN: "DOWN",
	KEY_SHIFT: "SHIFT", KEY_CTRL: "CTRL", KEY_ALT: "ALT", KEY_META: "CMD",
	KEY_CAPSLOCK: "CAPS",
	# The glyph on the key, not the engine's word for it.
	KEY_PERIOD: ".", KEY_COMMA: ",", KEY_SLASH: "/", KEY_BACKSLASH: "\\",
	KEY_MINUS: "-", KEY_EQUAL: "=", KEY_SEMICOLON: ";", KEY_APOSTROPHE: "'",
	KEY_QUOTELEFT: "`", KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]",
	# Distinct from the main-block keys above — same glyph would merge them in the conflict check.
	KEY_KP_ENTER: "NUM ENT", KEY_KP_ADD: "NUM +", KEY_KP_SUBTRACT: "NUM -",
	KEY_KP_MULTIPLY: "NUM *", KEY_KP_DIVIDE: "NUM /", KEY_KP_PERIOD: "NUM .",
}


static func event_label(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		if KEY_CAPS.has(code):
			return String(KEY_CAPS[code])
		# Letters and digits already come back as bare caps. Upper-casing is the net for anything this
		# table has not learned yet: a leak still leaks, but it leaks as a keycap and not as source code.
		return OS.get_keycode_string(code).to_upper()
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
