class_name Settings
extends RefCounted

## Machine-local player preferences: audio levels, screen shake, zoom and the key bindings. All static, so
## any caller can read them without wiring, and persisted to a ConfigFile in `user://`. Kept out of
## SaveGame deliberately. A save is a world; settings belong to this machine and person, so they survive
## new games and never travel with a save.
##
## Representation only, no sim state. Audio applies as dB offsets the Sfx layer adds at play time, shake
## gates one camera line, zoom is a camera index, bindings rebind InputMap actions. `persist` is false by
## default and only an interactive boot turns it on and loads the file, so a scripted run works from pure
## defaults and can never read or clobber the real settings file.

## Sound ships on: roughly half of what this game tells the player it tells by ear, and a player who never
## opens the settings page would otherwise never learn the audio is there. Mute stays one switch over the
## whole mix rather than levels pinned to zero (see `apply_audio`) and is persisted, so turning it off is
## equally a one-time act. Scripted boots silence themselves in `main.gd::_ready()`, where they also
## decline to persist, so this default describes what a new player hears.
static var muted: bool = false
static var master: float = 1.0          ## 0..1, the Master bus (everything)
static var sound: float = 1.0           ## 0..1, effect voices: the positional pool and UI dings
static var ambience: float = 1.0        ## 0..1, the beds: hum, wind, cave-air, drips
static var music: float = 1.0           ## 0..1, the Score
static var screen_shake: bool = true
static var auto_pickup: bool = true    ## walk-over auto-collect of ground items
static var zoom_idx: int = 0            ## index into MainView.ZOOM_LEVELS
## action name -> Array of event specs ({"key": physical keycode} | {"button": mouse button index}),
## the same spec shape as Controls.defaults(). Only actions that diverge live here; absent means the
## action is still on its default binding.
static var bindings: Dictionary = {}

static var persist: bool = false                     ## gate: load/save only when a real boot opts in
static var path: String = "user://settings.cfg"      ## overridable so a test can isolate its file


## Load the config, keeping defaults when the file is missing, and apply everything live.
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
	# Reconciled before it is applied (see `_reconcile_bindings`), so InputMap never holds a duplicate that
	# came in on disk, not even for the two lines between here and there.
	_reconcile_bindings()
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


## The Master bus follows the master slider; sound and ambience apply lazily as offsets, below. Mute is
## applied at the bus rather than by zeroing the levels, so it cannot be half-on and the sliders keep the
## values the player chose, which makes unmuting restore them exactly.
static func apply_audio() -> void:
	AudioServer.set_bus_mute(0, muted)
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(master, 0.0001, 1.0)))


## Flip the sound on or off and remember it. Returns the new state, for the on-screen readout.
static func toggle_mute() -> bool:
	muted = not muted
	apply_audio()
	save_settings()
	return muted


## One audio level, by name: the id the settings page draws its rows from (`Hud.AUDIO_ROWS`), resolved
## once here rather than twice at the two call sites that need it.
##
## Named rather than fetched, for the reason `Hud._audio_level` already carried: `Settings` is a class of
## STATIC vars, and a dynamic `get()` against one is a lookup that fails at runtime rather than at parse
## time. What is new is that the match lives in ONE place. It used to be the page's private copy, and the
## keyboard nudge in `MainView` needs the same four names to read a level before it can move it, so the
## alternative was a second copy of the table beside the one that writes them (`MainView._set_volume`),
## which is one rename away from a page that shows `music` while the arrows move `ambience`.
static func level(id: String) -> float:
	match id:
		"master": return master
		"sound": return sound
		"ambience": return ambience
		_: return music


## dB offsets the Sfx layer adds to its own baselines at play/frame time: 0 dB at full, about -60 (gone)
## at the bottom of the slider. Lazy application means no player-node bookkeeping here.
static func sound_db() -> float:
	return linear_to_db(clampf(sound, 0.001, 1.0))


static func ambience_db() -> float:
	return linear_to_db(clampf(ambience, 0.001, 1.0))


static func music_db() -> float:
	return linear_to_db(clampf(music, 0.001, 1.0))


## Rebind an action to one event spec, apply it live, persist. `reset_bindings()` restores every default.
##
## A rebind moves one event. The new spec replaces the action's event of the same device, desk for desk and
## pad for pad, and every other event of that action is left alone. Never write `bindings[action] = [spec]`:
## `Controls.defaults()` gives most actions two or three events and `_apply_action` erases them before
## re-adding, so a whole-binding replacement destroys the action's other gestures, persists that, and
## reapplies it on every boot.
##
## A collision steals rather than refuses, because refusing would make a used key unbindable until its
## owner was cleared by hand. Stealing leaves no duplicate behind, the displaced action loses only the one
## event that collided, and `reset_bindings()` undoes it.
##
## Detection and resolution compare the same quantity, `event_labels()`, which is every event of every
## action. `Hud._binding_clashes()` marks a clashing row with the comparison this resolver uses, so the
## page cannot show a conflict the resolver declines to fix or fix one it never showed. `binding_label`
## would only see `events[0]`, hiding a collision on any later event from both. A fresh spec always yields
## a real event, so `label` here is never `"unbound"` and this cannot mass-unbind keyless actions.
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
				took = true          # only this event moves; the rest of the action stays put
			else:
				kept.append(s)
		if took:
			displaced.append(other)
			bindings[other] = kept
			_apply_action(other, kept)
	# The action being bound keeps every event that is neither the same device nor the same key. Dropping
	# the same-label entry first is what stops an action colliding with itself: binding grapple to the
	# middle mouse button it already answers to would otherwise leave it holding MMB twice.
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


## Which device a spec speaks for. Rebinding a desk input replaces the action's desk input and leaves its
## pad input alone, so remapping a keyboard cannot cost the player their controller.
const DESK: int = 0
const PAD: int = 1


static func _device_of(spec: Dictionary) -> int:
	return PAD if (spec.has("pad") or spec.has("axis")) else DESK


## The action's current full spec list: its override if it has one, otherwise the defaults it is still
## running on. `bindings` holds only overrides, so reading it directly reports an empty list for every
## untouched action, and writing that back erases the whole binding.
static func specs_of(action: StringName) -> Array:
	if bindings.has(action):
		return (bindings[action] as Array).duplicate()
	var d: Dictionary = Controls.defaults()
	return (d[action] as Array).duplicate() if d.has(action) else []


## Every label the action answers to. `binding_label` returns only `events[0]` because a row has room for
## one chip; identity is a different question from display and needs all of them.
static func event_labels(action: StringName) -> Array[String]:
	var out: Array[String] = []
	if not InputMap.has_action(action):
		return out
	for ev: InputEvent in InputMap.action_get_events(action):
		out.append(event_label(ev))
	return out


## Push every saved override into InputMap. Call after Controls.register() has created the actions.
static func apply_bindings() -> void:
	for action: StringName in bindings:
		_apply_action(action, bindings[action])


## What the last load-time reconciliation did. Two of its three outcomes leave an InputMap that is
## indistinguishable from a pass which looked and found nothing, `kept_duplicate` most of all: an action
## still holding a duplicate because every alternative was taken looks exactly like an action nobody
## examined. The decision has to leave a trace or it cannot be told apart from an oversight.
##   moved           actions whose live events this pass changed (the restored ones are in here too)
##   restored        actions that would have booted dead and were handed free defaults back
##   kept_duplicate  actions left holding a duplicate deliberately, because the alternative was silence
static var last_reconcile: Dictionary = {"moved": [], "restored": [], "kept_duplicate": []}


## Reconcile what was just loaded, before any of it reaches InputMap.
##
## `rebind` cannot create a duplicate, since it takes the colliding event off whoever held it, but a config
## read off disk was never vetted by it. A file hand-edited or carried in from another machine would
## otherwise reinstate its duplicate on every boot and both actions would fire on every press.
##
## The predicate here is `rebind`'s at the same grain: `event_label` over every event of every action,
## which is also what `Hud._binding_clashes` compares. A resolver disagreeing with the detector would fix
## a clash the page never showed, or leave one it did.
##
## Precedence (who keeps a contested key) may not be read off the file.
## `ConfigFile.get_section_keys` returns keys in write order and `save_settings` writes them in `bindings`
## insertion order, which a reset or a hand edit reorders freely. Two profiles holding identical bindings
## would then resolve the same duplicate differently, and one profile could differ between two boots.
## Precedence comes from source instead, in two tiers:
##
##   1. An override outranks a default. An action in `bindings` was deliberately bound; one absent from it
##      has never been chosen. That is what `rebind` already did when the key was pressed, and deciding
##      the other way would let the load path overturn it on every boot: bind MUTE to W and the next
##      launch hands W back to climb-up. The loser of a repair gets an override, so it counts as chosen.
##   2. Among equals, `Controls.defaults()` order. A literal in source: identical on every machine and
##      platform, and already the order `rebind` and `_binding_clashes` iterate. It also runs the core
##      verbs before the conveniences, which is how a tie ought to break.
##
## The loser drops the single colliding spec and keeps everything else. No device test is needed to keep a
## keyboard collision off a gamepad event, and that is structural: `event_label` prefixes every pad label
## (`PAD A`, `STICK UP`), so a keycap and a pad label can never be equal. A dropped event is always of the
## same device as the one that displaced it. `_device_of` earns its place in the rescue below instead.
##
## An action may not boot dead, and that outranks resolving the duplicate. Two rescues:
##   * A device that emptied (its last desk event or its last pad event is gone) gets back whichever of
##     the action's own defaults for that device nobody is holding. Free keys only, so this
##     can never manufacture a second duplicate. If none are free it does not fire, because an action that
##     still answers a stick is not unreachable.
##   * An action that emptied entirely keeps the duplicate, left exactly as loaded and recorded in
##     `kept_duplicate`: a duplicate is visible on the CONTROLS page and playable, a dead key is neither.
##
## It repairs nothing but collisions. An older `bindings[action] = [spec]` rebind destroyed that action's
## other events; those are gone, and inventing them back would be a second opinion about what was meant.
static func _reconcile_bindings() -> void:
	var owner: Dictionary = {}                     # label -> the action that already answers to it
	var moved: Array[StringName] = []
	var restored: Array[StringName] = []
	var kept_duplicate: Array[StringName] = []
	for action: StringName in _precedence():
		var loaded: Array = specs_of(action)
		var kept: Array = []
		var lost: Array = []
		for s: Variant in loaded:
			var spec: Dictionary = s as Dictionary
			var label: String = event_label(Controls.event_from_spec(spec))
			if owner.has(label):
				# One event moves. This also catches an action colliding with itself, a spec list
				# holding the same key twice, which is what `rebind` drops the same-label entry for
				# before it places the new one.
				lost.append(spec)
			else:
				owner[label] = action
				kept.append(spec)
		if lost.is_empty():
			continue
		var gave_back: bool = false
		for device: int in [DESK, PAD]:
			if not _has_device(lost, device) or _has_device(kept, device):
				continue
			var back: Array = _free_defaults(action, device, owner)
			if back.is_empty():
				continue
			for s: Variant in back:
				owner[event_label(Controls.event_from_spec(s as Dictionary))] = action
			# Desk first, pad after: the order every entry in `Controls.defaults()` is written in and the
			# order `binding_label` reads, so the CONTROLS row's chip stays the key a desk player uses.
			kept = (back + kept) if device == DESK else (kept + back)
			gave_back = true
		if kept.is_empty():
			# Nothing survived and nothing was free. Leave the entry alone, neither rewritten with the
			# same contents nor erased, so the action keeps firing on the key it loaded with.
			kept_duplicate.append(action)
			continue
		if gave_back:
			restored.append(action)
		bindings[action] = kept
		moved.append(action)
	last_reconcile = {"moved": moved, "restored": restored, "kept_duplicate": kept_duplicate}
	# Persist the repair once and only when there was one, so a clean config comes out of a boot byte for
	# byte as it went in. `save_settings` early-returns while `persist` is false. The map above is already
	# correct in memory either way, so a scripted run gets the repaired InputMap and an untouched file. The
	# next interactive boot repairs the same file to the same shape, since none of this reads anything that
	# varies between boots.
	if not moved.is_empty():
		save_settings()


## The order actions are offered a contested label in. Computed once, up front, from the bindings as
## loaded: the pass writes into `bindings` as it goes, and precedence that re-read it would depend on how
## far through itself it had got.
static func _precedence() -> Array[StringName]:
	var chosen: Array[StringName] = []
	var untouched: Array[StringName] = []
	for action: StringName in Controls.defaults():
		if bindings.has(action):
			chosen.append(action)
		else:
			untouched.append(action)
	chosen.append_array(untouched)
	return chosen


static func _has_device(specs: Array, device: int) -> bool:
	for s: Variant in specs:
		if _device_of(s as Dictionary) == device:
			return true
	return false


## The action's own defaults for one device that nobody in this pass is holding. Empty when the action has
## no defaults for that device or every one of them is taken. Empty is the answer that makes the caller
## leave the duplicate standing rather than the answer that makes it look resolved.
static func _free_defaults(action: StringName, device: int, owner: Dictionary) -> Array:
	var d: Dictionary = Controls.defaults()
	if not d.has(action):
		return []
	var out: Array = []
	for s: Variant in (d[action] as Array):
		var spec: Dictionary = s as Dictionary
		if _device_of(spec) != device:
			continue
		if owner.has(event_label(Controls.event_from_spec(spec))):
			continue
		out.append(spec)
	return out


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
	# Events are built by Controls, never by a local if/else here. A hand-rolled branch that predates a spec
	# kind lets an unrecognised spec fall through its `else`, so a saved pad binding reloads as a mouse click.
	for spec_v: Variant in specs:
		InputMap.action_add_event(action, Controls.event_from_spec(spec_v as Dictionary))


## Human-readable label for an action's current binding, first event only, for the remap page.
static func binding_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return "unbound"
	return event_label(events[0])


## Engine keycode names are developer identifiers, not keycaps. `OS.get_keycode_string(KEY_PERIOD)` is
## `"Period"`, which reads as TitleCase source beside `M`, `T`, `Z` and `X` and is three times wider than
## every other cap in the column. A keycap shows what is printed on the key, so punctuation resolves to its
## glyph and named keys to a short shout matching the existing `SPACE` and `ESC`.
##
## Every label here must be unique. This function is not only display: `rebind`, `_reconcile_bindings` and
## `Hud._binding_clashes` all decide whether two bindings collide by comparing these labels, so any two
## keycodes that share one become the same key to all three. That is why ENTER and the keypad's are
## `ENTER` and `NUM ENT` rather than both `ENTER`, and why the fallback upper-cases rather than truncating.
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
	# Distinct from the main-block keys above: the same glyph would merge them in the conflict check.
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
	# Every gamepad label carries a "PAD" prefix. A bare "A" would collide with the keyboard's A on any
	# screen that lists bindings, and anything matching these labels against prose would read "press A"
	# as satisfied by a gamepad the player does not own.
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
