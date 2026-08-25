class_name Controls
extends RefCounted

## The single source of truth for keybindings. Every in-game action is a named InputMap action whose
## default events are registered here, so handlers ask `event.is_action_pressed(Controls.DROP)` rather
## than hardcoding `KEY_Q`. Nothing outside this file references a raw keycode, which is what makes every
## binding remappable by construction: the remap page only has to rebind these actions in InputMap and
## persist them. Defaults use physical keycodes, so bindings follow key position and WASD stays under the
## same fingers on AZERTY. The numeric hotbar row (1 to 8) stays a direct keycode at its call site as a
## fixed convention; everything a player would want to rebind lives here.

const LEFT := &"sf_left"
const RIGHT := &"sf_right"
const UP := &"sf_up"
const DOWN := &"sf_down"
const JUMP := &"sf_jump"
const MINE := &"sf_mine"
const BUILD := &"sf_build"
const DROP := &"sf_drop"
const CRAFT := &"sf_craft"
const RESEARCH := &"sf_research"
const MAP := &"sf_map"
const HELP := &"sf_help"
const PAUSE := &"sf_pause"
const CLOSE := &"sf_close"
const SPEED := &"sf_speed"
const CYCLE_NEXT := &"sf_cycle_next"
const CYCLE_PREV := &"sf_cycle_prev"
const ZOOM := &"sf_zoom"
const SAVE := &"sf_save"
const LOAD := &"sf_load"
const CLEAR_MARKS := &"sf_clear_marks"
const TECH := &"sf_tech"
const BAZAAR := &"sf_bazaar"
const DASHBOARD := &"sf_dashboard"
const GRAPPLE := &"sf_grapple"
const MUTE := &"sf_mute"
const LINK := &"sf_link"    ## the Freight Winch's link verb (docs/handoff/FREIGHT_WINCH_GRAYBOX_PLAN.md)


## Deafness: the one switch that disconnects live hardware from the running game.
##
## Disabling a node's `_input` / `_unhandled_input` / `_unhandled_key_input` only closes the callback path.
## Polling is a separate mechanism: `Input.get_axis()` and `Input.is_action_pressed()` read the driver's
## current state and do not care whether a node processes input at all, so a hand resting on W or a held
## mouse button still walks, jumps, climbs or mines through anything that only cleared the callbacks.
##
## Every gameplay poll goes through `axis()` and `pressed()` below, so one place decides whether hardware
## is connected to the game. A list of things to disable instead would require every future polling site to
## know it was supposed to add itself to that list. Scripted drivers set `Player.input_dir` and friends
## directly and are unaffected.
static var deaf: bool = false


## The remappable axis, or dead centre while the game is deafened.
static func axis(negative: StringName, positive: StringName) -> float:
	return 0.0 if deaf else Input.get_axis(negative, positive)


## Is this action being held? Always false while the game is deafened.
static func pressed(action: StringName) -> bool:
	return false if deaf else Input.is_action_pressed(action)


## action -> list of default event specs. See `event_from_spec` for the four spec kinds.
##
## The pad bindings are additive: keyboard and mouse defaults are untouched and both sets are live at
## once, so a player can steer with a stick and still hit F5. The scheme assumes an Xbox-shaped pad,
## which is what Godot's JOY_BUTTON_* names describe.
##
##   LEFT STICK    move and climb, both axes, because up/down is the climb verb: a rope is ridden with
##                 the same thumb that walks, which is why climb and JUMP are separate actions.
##   TRIGGERS      MINE and BUILD, because both are held. A trigger is the only analogue control a finger
##                 can rest on for whole seconds without fatigue, and mining is measured in seconds.
##                 Right is mine, matching the mouse hand's LMB.
##   RIGHT BUMPER  the grapple, for the same reason F is: it wants to be flicked, and a bumper is the
##                 fastest thing on the pad to hit without moving a thumb off a stick.
##   D-PAD         left and right cycle the hotbar, up cycles zoom. The D-pad is free for this because
##                 movement lives on the stick, and it must not also mirror the stick: an input that both
##                 walks the body and changes tool is worse than one that does neither.
##   FACE BUTTONS  A jumps, X crafts, Y drops, B closes. B is the universal back button and CLOSE is what
##                 back means here.
##   START/BACK    pause and map.
##
## Deliberately unbound on the pad: SAVE, LOAD, TECH, BAZAAR, DASHBOARD, SPEED, MUTE, RESEARCH,
## CLEAR_MARKS and HELP. A pad has about fourteen inputs against this game's twenty-six actions, so binding
## everything would mean chords and long-presses; those ten are conveniences or reachable from menus.
static func defaults() -> Dictionary:
	return {
		LEFT: [{"key": KEY_A}, {"key": KEY_LEFT}, {"axis": JOY_AXIS_LEFT_X, "dir": -1}],
		RIGHT: [{"key": KEY_D}, {"key": KEY_RIGHT}, {"axis": JOY_AXIS_LEFT_X, "dir": 1}],
		# W/↑ and S/↓ are the climb axis, grabbing and riding a rope. JUMP is Space alone, so climbing a
		# rope and jumping off it stay distinct verbs on desk as well as on the pad.
		UP: [{"key": KEY_W}, {"key": KEY_UP}, {"axis": JOY_AXIS_LEFT_Y, "dir": -1}],
		DOWN: [{"key": KEY_S}, {"key": KEY_DOWN}, {"axis": JOY_AXIS_LEFT_Y, "dir": 1}],
		JUMP: [{"key": KEY_SPACE}, {"pad": JOY_BUTTON_A}],
		MINE: [{"button": MOUSE_BUTTON_LEFT}, {"axis": JOY_AXIS_TRIGGER_RIGHT, "dir": 1}],
		BUILD: [{"button": MOUSE_BUTTON_RIGHT}, {"axis": JOY_AXIS_TRIGGER_LEFT, "dir": 1}],
		DROP: [{"key": KEY_Q}, {"pad": JOY_BUTTON_Y}],
		CRAFT: [{"key": KEY_E}, {"pad": JOY_BUTTON_X}],
		RESEARCH: [{"key": KEY_R}],   # configures the machine being aimed at; research itself is on ENTER

		MAP: [{"key": KEY_M}, {"pad": JOY_BUTTON_BACK}],
		HELP: [{"key": KEY_H}, {"key": KEY_SLASH}],
		PAUSE: [{"key": KEY_P}, {"pad": JOY_BUTTON_START}],
		CLOSE: [{"key": KEY_ESCAPE}, {"pad": JOY_BUTTON_B}],
		SPEED: [{"key": KEY_PERIOD}],   # "." cycles the game clock: 1x, 2x, 4x, 8x
		CYCLE_NEXT: [{"button": MOUSE_BUTTON_WHEEL_DOWN}, {"pad": JOY_BUTTON_DPAD_RIGHT}],
		CYCLE_PREV: [{"button": MOUSE_BUTTON_WHEEL_UP}, {"pad": JOY_BUTTON_DPAD_LEFT}],
		ZOOM: [{"key": KEY_Z}, {"pad": JOY_BUTTON_DPAD_UP}],
		SAVE: [{"key": KEY_F5}],        # classic quicksave/quickload
		LOAD: [{"key": KEY_F9}],
		CLEAR_MARKS: [{"key": KEY_X}],  # wipe the painted dig plan
		TECH: [{"key": KEY_T}],         # the tech-tree overlay
		BAZAAR: [{"key": KEY_B}],       # WORKS + RACK: what you can build or buy right now
		DASHBOARD: [{"key": KEY_G}],    # the production dashboard: throughput and factory census
		# One input both fires and releases, so the line is flicked rather than managed, and all three
		# bindings are reachable without moving a hand off WASD and aim, or off a stick.
		GRAPPLE: [{"key": KEY_F}, {"button": MOUSE_BUTTON_MIDDLE}, {"pad": JOY_BUTTON_RIGHT_SHOULDER}],
		MUTE: [{"key": KEY_N}],       # sound on/off. M is the map, N is its free neighbour.
		# The Freight Winch: aim at an unlinked Head and press, then aim at an unlinked Station and press
		# again -- one key, two presses, the same "aim, confirm" shape GRAPPLE's own throw uses.
		LINK: [{"key": KEY_L}],
	}


## The one place a binding spec becomes an event. Never duplicate this if/else elsewhere: a copy that
## predates a spec kind lets an unrecognised spec fall out of its `else` and become a mouse button, so a
## saved gamepad binding silently comes back as a click. Four kinds:
##
##   {"key": KEY_*}          a physical keycode, so the binding follows the key's position and a player
##                           on AZERTY gets the same shape of hand rather than the same letters.
##   {"button": MOUSE_*}     a mouse button.
##   {"pad": JOY_BUTTON_*}   a gamepad button.
##   {"axis": JOY_AXIS_*, "dir": -1|1}   half of a stick or a trigger. `dir` picks which half: left and
##                           right are the same axis with opposite signs, so an action bound to the axis
##                           alone would fire on both.
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


## How far a stick must lean, and a trigger must be pulled, before the action counts as pressed. The
## stick value is a deadzone: a worn thumbstick resting at 0.15 must not walk the body across the room.
## The trigger value is a rest threshold: a trigger is used as a button here, and MINE is held for whole
## seconds, so a finger resting on it must not start mining.
const STICK_POINT: float = 0.5
const TRIGGER_POINT: float = 0.5

static func _is_trigger(axis: int) -> bool:
	return axis == JOY_AXIS_TRIGGER_LEFT or axis == JOY_AXIS_TRIGGER_RIGHT


## Register the defaults into InputMap. Idempotent and non-destructive: an action that already exists is
## left alone, so saved bindings applied before this call win over these defaults. Safe to call from
## several _ready()s; MainView and Player both call it so each can stand alone.
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
## Every reader of "where is the player pointing" goes through the two accessors below rather than calling
## `get_global_mouse_position()` for itself. In play `_posed` is false and every reader resolves to the
## live cursor. `pose_pointer()` states a world point directly instead, and nothing touches the OS cursor:
## overriding the aim with `warp_mouse` would fight the physical pointer and read back whatever it did.
##
## `_posed` is a real bool rather than a `Vector2` compared against null. In GDScript a Vector2, like
## Array, Dictionary and Callable, compares `!= null` as true, so an "is an override set?" guard written
## that way can never be false.
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
## It asks the viewport, not the node. `CanvasItem.get_global_mouse_position()` divides by the node's
## canvas transform, which for anything under a `CanvasLayer` is the layer's transform rather than the
## viewport's, and the HUD lives under a `CanvasLayer` scaled by `HUD_SCALE`. Going through the node would
## make the unposed branch return layer coordinates while the posed branch returned world coordinates, so
## one accessor would mean two spaces. Both branches speak world space for every node.
static func pointer_world(node: CanvasItem) -> Vector2:
	if _posed:
		return _posed_world
	var vp: Viewport = node.get_viewport()
	return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()


## The pointer in viewport space: what the cursor is over, for the "is it on a panel?" tests. Derived
## from the posed world point through the engine's own canvas transform rather than a hand-rolled
## projection, so the two accessors cannot drift apart.
static func pointer_viewport(node: CanvasItem) -> Vector2:
	var vp: Viewport = node.get_viewport()
	if _posed:
		return vp.get_canvas_transform() * _posed_world
	return vp.get_mouse_position()
