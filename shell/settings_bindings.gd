class_name SettingsBindings
extends RefCounted

## The key-binding half of `Settings`: rebinding, the load-time collision reconciliation, and the keycap
## labels all three of those compare by. Split out of `legacy/scenes/settings.gd` on the way over
## (`docs/DECISIONS_LEDGER.md` D0227) because the original is 455 lines against a 400-line blocking gate.
##
## The split is along the file's own seam rather than at a convenient line number: nothing in `Settings`
## now reads an InputEvent, and nothing here reads an audio level. The shared state stays in one place --
## `Settings.bindings` is still the single map of overrides, and this file reads and writes it through
## that name rather than keeping a second copy, which is the thing a split like this most easily gets
## wrong.
##
## `event_label` is the load-bearing function here and it is not only display: `rebind`, `reconcile` and
## any future conflict readout all decide whether two bindings collide by comparing these labels, so any
## two keycodes sharing a label become the same key to all of them.

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
			Settings.bindings[other] = kept
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
	Settings.bindings[action] = mine
	_apply_action(action, mine)
	Settings.save_settings()
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
	if Settings.bindings.has(action):
		return (Settings.bindings[action] as Array).duplicate()
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
static func apply() -> void:
	for action: StringName in Settings.bindings:
		_apply_action(action, Settings.bindings[action])


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
static func reconcile() -> void:
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
		var rescue: Dictionary = _rescue_emptied_devices(action, lost, kept, owner)
		var gave_back: bool = bool(rescue["gave_back"])
		kept = rescue["kept"] as Array
		if kept.is_empty():
			# Nothing survived and nothing was free. Leave the entry alone, neither rewritten with the
			# same contents nor erased, so the action keeps firing on the key it loaded with.
			kept_duplicate.append(action)
			continue
		if gave_back:
			restored.append(action)
		Settings.bindings[action] = kept
		moved.append(action)
	last_reconcile = {"moved": moved, "restored": restored, "kept_duplicate": kept_duplicate}
	# Persist the repair once and only when there was one, so a clean config comes out of a boot byte for
	# byte as it went in. `save_settings` early-returns while `persist` is false. The map above is already
	# correct in memory either way, so a scripted run gets the repaired InputMap and an untouched file. The
	# next interactive boot repairs the same file to the same shape, since none of this reads anything that
	# varies between boots.
	if not moved.is_empty():
		Settings.save_settings()


## A device that emptied (its last desk event or its last pad event was taken) gets back whichever of the
## action's own defaults for that device nobody is holding. Free keys only, so this can never manufacture
## a second duplicate; if none are free it does not fire, because an action that still answers a stick is
## not unreachable. Returns `{"kept": Array, "gave_back": bool}`.
##
## Extracted from `reconcile` on the way over (D0227) purely to bring that function under the 50-line
## gate -- it was 52. The body is unchanged, including the ORDER, which is load-bearing: desk first and
## pad after is the order every entry in `Controls.defaults()` is written in and the order
## `binding_label` reads, so the row's chip stays the key a desk player actually uses.
static func _rescue_emptied_devices(action: StringName, lost: Array, kept: Array,
		owner: Dictionary) -> Dictionary:
	var gave_back: bool = false
	for device: int in [DESK, PAD]:
		if not _has_device(lost, device) or _has_device(kept, device):
			continue
		var back: Array = _free_defaults(action, device, owner)
		if back.is_empty():
			continue
		for s: Variant in back:
			owner[event_label(Controls.event_from_spec(s as Dictionary))] = action
		kept = (back + kept) if device == DESK else (kept + back)
		gave_back = true
	return {"kept": kept, "gave_back": gave_back}


## The order actions are offered a contested label in. Computed once, up front, from the bindings as
## loaded: the pass writes into `bindings` as it goes, and precedence that re-read it would depend on how
## far through itself it had got.
static func _precedence() -> Array[StringName]:
	var chosen: Array[StringName] = []
	var untouched: Array[StringName] = []
	for action: StringName in Controls.defaults():
		if Settings.bindings.has(action):
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
	Settings.bindings = {}
	var specs: Dictionary = Controls.defaults()
	for action: StringName in specs:
		_apply_action(action, specs[action])
	Settings.save_settings()


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
## Every label here must be unique. This function is not only display: `rebind`, `reconcile` and
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
