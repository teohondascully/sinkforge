class_name Controls
extends RefCounted

## Lifted from `legacy/scenes/controls.gd` (Slice 1, `docs/DECISIONS_LEDGER.md` D0194). Two mechanisms
## come across whole, because both are load-bearing for measurement and neither can be re-derived cheaply
## once it has been got wrong: the DEAFNESS SWITCH and the POSABLE POINTER. The rest of legacy's file --
## twenty-six named actions covering craft, research, bazaar, tech and dashboard -- is deliberately NOT
## lifted: that vocabulary is the terminal economy, which stays dead (the execution brief's own standing
## constraint). Four actions exist here because four verbs exist in this build. More arrive with more verbs.
##
## WHY THIS IS IN `view/`. It is a client of L2 and touches no `sim` type, which is what `view/README.md`
## requires ("never call a sim mutator directly"). `pointer_world` needs a real `CanvasItem` to reach the
## viewport, so it could not live in `sim/` even if the layer rules allowed it. The scene that turns a
## pointer into a mined cell is the one place both sides meet, and at Slice 2 that becomes `interface/`.
##
## Nothing outside this file references a raw keycode, which is what makes every binding remappable by
## construction rather than by convention.

const LEFT := &"sf_left"
const RIGHT := &"sf_right"
const JUMP := &"sf_jump"
const MINE := &"sf_mine"
## THE SHELL'S VERBS (A' step 6q, D0380): the actions a real session binds beyond the four the settings page
## remaps. Same map, same spec kinds, so `SettingsBindings` can rebind them the day the page lists them.
const BUILD := &"sf_build"          ## RMB: place what is held, or pick up what is there
const DROP := &"sf_drop"            ## Q: drop the held stack -- into a mouth in reach, else at your feet
const CONFIGURE := &"sf_configure"  ## R: the aimed machine's toggle
const LINK := &"sf_link"            ## L: arm a winch head, then link its station
const CLEAR_PLAN := &"sf_clear_plan"
const GRAPPLE := &"sf_grapple"      ## Shift or MMB: throw or release the line
const CLIMB_UP := &"sf_climb_up"    ## W / S on a rope
const CLIMB_DOWN := &"sf_climb_down"
const MAP := &"sf_map"              ## M: the corner map grows and shrinks
const SETTINGS := &"sf_settings"    ## K: the settings page
const SAVE := &"sf_save"            ## F5: write the slot now (the close box writes it too)


## Deafness: the one switch that disconnects live hardware from the running game.
##
## Disabling a node's `_input` / `_unhandled_input` / `_unhandled_key_input` only closes the callback path.
## Polling is a separate mechanism: `Input.get_axis()` and `Input.is_action_pressed()` read the driver's
## current state and do not care whether a node processes input at all, so a hand resting on a key or a held
## mouse button still walks, jumps or mines through anything that only cleared the callbacks.
##
## Every gameplay poll goes through `axis()` and `pressed()` below, so one place decides whether hardware is
## connected to the game. A list of things to disable instead would require every future polling site to know
## it was supposed to add itself to that list. Scripted drivers feed `InputFrame` directly and are unaffected.
static var deaf: bool = false


## The remappable axis, or dead centre while the game is deafened.
static func axis(negative: StringName, positive: StringName) -> float:
	return 0.0 if deaf else Input.get_axis(negative, positive)


## Is this action being held? Always false while the game is deafened.
static func pressed(action: StringName) -> bool:
	return false if deaf else Input.is_action_pressed(action)


## action -> list of default event specs. See `event_from_spec` for the four spec kinds. Keyboard, mouse and
## pad defaults are all live at once; binding MINE to a trigger as well as LMB is legacy's own reasoning kept
## verbatim, because it is about the verb rather than the build: "a trigger is the only analogue control a
## finger can rest on for whole seconds without fatigue, and mining is measured in seconds."
static func defaults() -> Dictionary:
	return {
		LEFT: [{"key": KEY_A}, {"key": KEY_LEFT}, {"axis": JOY_AXIS_LEFT_X, "dir": -1}],
		RIGHT: [{"key": KEY_D}, {"key": KEY_RIGHT}, {"axis": JOY_AXIS_LEFT_X, "dir": 1}],
		JUMP: [{"key": KEY_SPACE}, {"pad": JOY_BUTTON_A}],
		# Mouse only, deliberately not KEY_E: E is still `body.gd`'s own horizontal column dig through
		# Slice 1, and one key driving two different mining verbs would make every recording ambiguous.
		MINE: [{"button": MOUSE_BUTTON_LEFT}, {"axis": JOY_AXIS_TRIGGER_RIGHT, "dir": 1}],
		BUILD: [{"button": MOUSE_BUTTON_RIGHT}, {"pad": JOY_BUTTON_X}],
		DROP: [{"key": KEY_Q}, {"pad": JOY_BUTTON_B}],
		CONFIGURE: [{"key": KEY_R}, {"pad": JOY_BUTTON_Y}],
		LINK: [{"key": KEY_L}],
		CLEAR_PLAN: [{"key": KEY_C}],
		GRAPPLE: [{"key": KEY_SHIFT}, {"button": MOUSE_BUTTON_MIDDLE}, {"pad": JOY_BUTTON_RIGHT_SHOULDER}],
		CLIMB_UP: [{"key": KEY_W}, {"key": KEY_UP}, {"axis": JOY_AXIS_LEFT_Y, "dir": -1}],
		CLIMB_DOWN: [{"key": KEY_S}, {"key": KEY_DOWN}, {"axis": JOY_AXIS_LEFT_Y, "dir": 1}],
		MAP: [{"key": KEY_M}],
		SETTINGS: [{"key": KEY_K}, {"key": KEY_ESCAPE}, {"pad": JOY_BUTTON_START}],
		SAVE: [{"key": KEY_F5}],
	}


## The one place a binding spec becomes an event. Never duplicate this if/else elsewhere: a copy that
## predates a spec kind lets an unrecognised spec fall out of its `else` and become a mouse button, so a
## saved gamepad binding silently comes back as a click. Four kinds:
##
##   {"key": KEY_*}          a physical keycode, so the binding follows the key's position and a player on
##                           AZERTY gets the same shape of hand rather than the same letters.
##   {"button": MOUSE_*}     a mouse button.
##   {"pad": JOY_BUTTON_*}   a gamepad button.
##   {"axis": JOY_AXIS_*, "dir": -1|1}   half of a stick or a trigger. `dir` picks which half: left and right
##                           are the same axis with opposite signs, so an action bound to the axis alone
##                           would fire on both.
static func event_from_spec(spec: Dictionary) -> InputEvent:
	if spec.has("key"):
		var k := InputEventKey.new()
		k.physical_keycode = int(spec["key"])
		return k
	if spec.has("pad"):
		var j := InputEventJoypadButton.new()
		j.button_index = int(spec["pad"]) as JoyButton
		return j
	if spec.has("axis"):
		var a := InputEventJoypadMotion.new()
		a.axis = int(spec["axis"]) as JoyAxis
		# The magnitude is the threshold the action trips at, and the sign is the half of the axis that
		# counts. Sticks rest near zero and drift; triggers rest at zero and travel one way only.
		a.axis_value = float(spec["dir"]) * (TRIGGER_POINT if _is_trigger(int(spec["axis"])) else STICK_POINT)
		return a
	var m := InputEventMouseButton.new()
	m.button_index = int(spec["button"])
	return m


## How far a stick must lean, and a trigger must be pulled, before the action counts as pressed. The stick
## value is a deadzone: a worn thumbstick resting at 0.15 must not walk the body across the room. The trigger
## value is a rest threshold: a trigger is used as a button here, and MINE is held for whole seconds, so a
## finger resting on it must not start mining.
const STICK_POINT: float = 0.5
const TRIGGER_POINT: float = 0.5

static func _is_trigger(axis: int) -> bool:
	return axis == JOY_AXIS_TRIGGER_LEFT or axis == JOY_AXIS_TRIGGER_RIGHT


## Register the defaults into InputMap. Idempotent and non-destructive: an action that already exists is left
## alone, so saved bindings applied before this call win over these defaults. Safe to call from several
## `_ready()`s.
static func register() -> void:
	var specs: Dictionary = defaults()
	for action: StringName in specs:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for spec: Dictionary in specs[action]:
			InputMap.action_add_event(action, event_from_spec(spec))


# --- the pointer is one source, and a script may own it ---------------------------------------------
#
## Every reader of "where is the player pointing" goes through the accessors below rather than calling
## `get_global_mouse_position()` for itself. In play `_posed` is false and every reader resolves to the live
## cursor. `pose_pointer()` states a world point directly instead, and nothing touches the OS cursor:
## overriding the aim with `warp_mouse` would fight the physical pointer and read back whatever it did.
##
## THIS IS WHAT MAKES CURSOR-AIM MEASURABLE. Aim is now a state-affecting input -- which cell a hold charges
## depends on it -- so an agent run, a fuzz run or a replay that could not state the aim would be
## nondeterministic by construction. A harness poses the pointer; `pointer_posed()` lets a measurement assert
## that no pose is set, so a reading taken with a pose left on is VOID rather than silently passing as a
## hardware reading (`docs/DECISIONS_LEDGER.md`'s own "the human is inside the measurement").
##
## `_posed` is a real bool rather than a `Vector2` compared against null. In GDScript a Vector2, like Array,
## Dictionary and Callable, compares `!= null` as true, so an "is an override set?" guard written that way
## can never be false.
static var _posed: bool = false
static var _posed_world: Vector2 = Vector2.ZERO


## Take the pointer. From here the game aims at `world`, wherever the physical cursor is.
static func pose_pointer(world: Vector2) -> void:
	_posed = true
	_posed_world = world


## Give the pointer back to the physical cursor.
static func release_pointer() -> void:
	_posed = false


## Whether the pointer is currently posed. Anything measuring the real cursor path should assert this is
## false, so a pose left set cannot pass as a hardware reading.
static func pointer_posed() -> bool:
	return _posed


## The pointer in world space: what the player is aiming at.
##
## It asks the viewport, not the node. `CanvasItem.get_global_mouse_position()` divides by the node's canvas
## transform, which for anything under a `CanvasLayer` is the layer's transform rather than the viewport's.
## Going through the node would make the unposed branch return layer coordinates while the posed branch
## returned world coordinates, so one accessor would mean two spaces. Both branches speak world space.
static func pointer_world(node: CanvasItem) -> Vector2:
	if _posed:
		return _posed_world
	var vp: Viewport = node.get_viewport()
	return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()


## The pointer in viewport space: what the cursor is over, for the "is it on a panel?" tests. Derived from the
## posed world point through the engine's own canvas transform rather than a hand-rolled projection, so the
## two accessors cannot drift apart.
static func pointer_viewport(node: CanvasItem) -> Vector2:
	var vp: Viewport = node.get_viewport()
	if _posed:
		return vp.get_canvas_transform() * _posed_world
	return vp.get_mouse_position()
