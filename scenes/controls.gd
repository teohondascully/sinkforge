class_name Controls
extends RefCounted

## The SINGLE SOURCE OF TRUTH for keybindings. Every in-game action is a named InputMap action whose
## default events are registered here, so handlers ask `event.is_action_pressed(Controls.DROP)` instead
## of hardcoding `KEY_Q`. This is the FOUNDATION for a future settings / remap page (NOT built yet): that
## page will just rebind these actions in InputMap and persist them to a config file, and because nothing
## else references raw keycodes, every binding below is remappable by construction. Add a binding once,
## here, and it is configurable forever.
##
## Defaults use PHYSICAL keycodes (layout-independent: WASD stays under the same fingers on AZERTY).
## The numeric hotbar row (1–8) stays a direct keycode at its call site — a fixed convention, not a
## per-slot remap — but everything a player would actually want to rebind lives here.

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
const DASHBOARD := &"sf_dashboard"
const GRAPPLE := &"sf_grapple"
const MUTE := &"sf_mute"


## DEAFNESS — the one switch that takes live hardware away from the running game.
##
## capture_moments' `_deafen()` clears `_input` / `_unhandled_input` / `_unhandled_key_input`, and that is
## the CALLBACK path only. POLLING is a different mechanism: `Input.get_axis()` and
## `Input.is_action_pressed()` read the driver's current state and do not care in the slightest whether a
## node is set to process input. So a capture — which takes seconds — could be walked, jumped, climbed or
## MINED through by a hand resting on W or a mouse button held down, and `_contamination()` could not
## notice, because it inspects modal state and a callback flag and polling touches neither of those.
##
## Every gameplay poll goes through `axis()` / `pressed()` below, so ONE place decides whether the hardware
## is connected to the game and a fixture can assert that it still holds at the shutter. The alternative —
## another list of things to disable — requires the next polling site anyone adds to know that it was
## supposed to add itself to a list, which is exactly the kind of guarantee that quietly decays.
##
## This is representation-side only: it silences live hardware. Scripted drivers set `Player.input_dir` and
## friends directly, so play-tests and fixtures are unaffected by it.
static var deaf: bool = false


## The remappable axis, or dead centre while the game is deafened.
static func axis(negative: StringName, positive: StringName) -> float:
	return 0.0 if deaf else Input.get_axis(negative, positive)


## Is this action being held? Never, while the game is deafened.
static func pressed(action: StringName) -> bool:
	return false if deaf else Input.is_action_pressed(action)


## action -> list of default event specs. See `event_from_spec` for the four spec kinds.
##
## THE PAD LAYOUT, and why each verb sits where it does. COMPREHENSIVE_AUDIT §198: the game had no gamepad
## bindings at all, which is not a missing convenience — it is a player who plugs in a controller, gets
## nothing, and has no way to discover the game is not broken. Every binding below is ADDITIONAL: the
## keyboard and mouse defaults are untouched, and both sets are live at once, so a player can steer with a
## stick and still hit F5.
##
## The scheme assumes an Xbox-shaped pad, which is what Godot's JOY_BUTTON_* names describe, and it is built
## around what the hands are doing in the moment rather than around alphabetical tidiness:
##
##   LEFT STICK    move and climb. Both axes, because UP/DOWN is the climb verb — a rope is ridden with the
##                 same thumb that walks, which is the whole reason they are separate from JUMP.
##   TRIGGERS      MINE and BUILD, because both are HELD. A trigger is the only analogue control on the pad
##                 that a finger can rest on for whole seconds without fatigue, and mining is measured in
##                 seconds. Right is mine, matching the right mouse hand's LMB.
##   RIGHT BUMPER  the grapple, for the same reason F is: it wants to be FLICKED, and a bumper is the
##                 fastest thing on the pad to hit without moving a thumb off a stick.
##   D-PAD         left/right cycle the hotbar; up cycles zoom. The D-pad is free for this precisely
##                 because movement lives on the stick, and it must NOT also mirror the stick — an input
##                 that both walks you and changes tool is worse than one that does neither.
##   FACE BUTTONS  A jumps. X crafts, Y drops, B closes — B is the universal back button and CLOSE is what
##                 back means here.
##   START/BACK    pause and map, which is where a decade of controllers has put them.
##
## What is deliberately NOT bound: SAVE, LOAD, TECH, DASHBOARD, SPEED, MUTE, RESEARCH, CLEAR_MARKS and HELP.
## A pad has about fourteen inputs and this game has twenty-four actions, so a scheme that binds everything
## binds them badly — chords, long-presses, and a layer nobody can remember. Those nine are all reachable
## from menus or are conveniences, and `check_gamepad` asserts the ESSENTIAL set is complete while printing
## the remainder, so the line between "chose not to" and "forgot" stays visible instead of being a guess.
static func defaults() -> Dictionary:
	return {
		# Movement is the STICK only, and the D-pad is deliberately not a second copy of it: the D-pad is
		# carrying the hotbar below, and an input cannot be both without walking the body every time you
		# change tool. The first draft of this bound both and check_gamepad caught it.
		LEFT: [{"key": KEY_A}, {"key": KEY_LEFT}, {"axis": JOY_AXIS_LEFT_X, "dir": -1}],
		RIGHT: [{"key": KEY_D}, {"key": KEY_RIGHT}, {"axis": JOY_AXIS_LEFT_X, "dir": 1}],
		# W/↑ and S/↓ are the CLIMB axis (grab + ride a rope); JUMP is Space alone now, so climbing
		# up a rope (W) and jumping off it (Space) stay distinct verbs. On the pad that separation is what
		# puts climb on the stick's Y and jump on A: one thumb rides, the other leaps.
		UP: [{"key": KEY_W}, {"key": KEY_UP}, {"axis": JOY_AXIS_LEFT_Y, "dir": -1}],
		DOWN: [{"key": KEY_S}, {"key": KEY_DOWN}, {"axis": JOY_AXIS_LEFT_Y, "dir": 1}],
		JUMP: [{"key": KEY_SPACE}, {"pad": JOY_BUTTON_A}],
		MINE: [{"button": MOUSE_BUTTON_LEFT}, {"axis": JOY_AXIS_TRIGGER_RIGHT, "dir": 1}],
		BUILD: [{"button": MOUSE_BUTTON_RIGHT}, {"axis": JOY_AXIS_TRIGGER_LEFT, "dir": 1}],
		DROP: [{"key": KEY_Q}, {"pad": JOY_BUTTON_Y}],
		CRAFT: [{"key": KEY_E}, {"pad": JOY_BUTTON_X}],
		RESEARCH: [{"key": KEY_R}],   # #S33: CONFIGURE the machine you are aiming at. Research moved to ENTER.

		MAP: [{"key": KEY_M}, {"pad": JOY_BUTTON_BACK}],
		HELP: [{"key": KEY_H}, {"key": KEY_SLASH}],
		PAUSE: [{"key": KEY_P}, {"pad": JOY_BUTTON_START}],
		CLOSE: [{"key": KEY_ESCAPE}, {"pad": JOY_BUTTON_B}],
		SPEED: [{"key": KEY_PERIOD}],   # "." — cycle the fast-forward game clock (1x -> 2x -> 4x -> 8x)
		CYCLE_NEXT: [{"button": MOUSE_BUTTON_WHEEL_DOWN}, {"pad": JOY_BUTTON_DPAD_RIGHT}],
		CYCLE_PREV: [{"button": MOUSE_BUTTON_WHEEL_UP}, {"pad": JOY_BUTTON_DPAD_LEFT}],
		ZOOM: [{"key": KEY_Z}, {"pad": JOY_BUTTON_DPAD_UP}],
		SAVE: [{"key": KEY_F5}],        # classic quicksave/quickload
		LOAD: [{"key": KEY_F9}],
		CLEAR_MARKS: [{"key": KEY_X}],  # wipe the painted dig plan
		TECH: [{"key": KEY_T}],         # the tech-tree overlay
		DASHBOARD: [{"key": KEY_G}],    # the production dashboard (throughput + factory census)
		# The grapple sits on F, the middle mouse button and the right bumper: one input that fires AND
		# releases, so the line is something you flick rather than something you manage. All three are
		# reachable without moving the hand off the thing it is already doing — WASD and aim, or a stick.
		GRAPPLE: [{"key": KEY_F}, {"button": MOUSE_BUTTON_MIDDLE}, {"pad": JOY_BUTTON_RIGHT_SHOULDER}],
		MUTE: [{"key": KEY_N}],       # sound on/off in one key. M is the map; N is its neighbour and free.
	}


## THE ONE PLACE A BINDING SPEC BECOMES AN EVENT.
##
## There used to be two, byte-identical: this one, and `Settings._apply_action` doing the same if/else for
## the remap page. That was survivable while a spec could only be a key or a mouse button, because the else
## branch was always right. It stops being survivable the moment a THIRD kind exists — a spec the remap
## page did not understand would fall out of its `else` and become a mouse button, silently, and a player's
## saved gamepad binding would come back as a click.
##
## Four kinds now:
##
##   {"key": KEY_*}          a physical keycode, so the binding follows the key's POSITION and a player on
##                           AZERTY gets the same shape of hand rather than the same letters.
##   {"button": MOUSE_*}     a mouse button.
##   {"pad": JOY_BUTTON_*}   a gamepad button.
##   {"axis": JOY_AXIS_*, "dir": -1|1}   half of a stick or a trigger. `dir` picks WHICH half, because a
##                           stick axis is two bindings wearing one number: left and right are the same
##                           axis with opposite signs, and an action bound to "the axis" would fire on both.
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
		# The magnitude is the DEADZONE the action trips at, and its sign is the half of the axis that
		# counts. Sticks rest near zero and drift; triggers rest at zero and travel one way only.
		a.axis_value = float(spec["dir"]) * (TRIGGER_POINT if _is_trigger(int(spec["axis"])) else STICK_POINT)
		return a
	var m := InputEventMouseButton.new()
	m.button_index = int(spec["button"])
	return m


## How far a stick must lean, and a trigger must be pulled, before the action counts as pressed. The stick
## number is a deadzone: a worn thumbstick that rests at 0.15 must not walk the body across the room. The
## trigger number is higher because a trigger is being used as a BUTTON here — MINE is held down for whole
## seconds — and a light rest of the finger should not start mining.
const STICK_POINT: float = 0.5
const TRIGGER_POINT: float = 0.5

static func _is_trigger(axis: int) -> bool:
	return axis == JOY_AXIS_TRIGGER_LEFT or axis == JOY_AXIS_TRIGGER_RIGHT


## Register the defaults into InputMap. IDEMPOTENT and non-destructive: an action that already exists is
## left alone, so a remap page applying saved bindings FIRST wins over these defaults. Safe to call from
## multiple _ready()s (MainView and Player both call it, so each works standalone in the harness too).
static func register() -> void:
	var specs: Dictionary = defaults()
	for action: StringName in specs:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for spec: Dictionary in specs[action]:
			InputMap.action_add_event(action, event_from_spec(spec))


# --- INP-01: the pointer is ONE source, and a fixture may own it ------------------------------------
#
## Where the player is pointing had three readers (`_toggle_grapple`, `_update_mining`, `_draw_aim_ghost`)
## and each called `get_global_mouse_position()` for itself, plus three more asking the VIEWPORT for the
## same cursor to test whether it sits on a panel. Six independent reads of one physical thing.
##
## That was tolerable until it wasn't. Fixtures posed the aim by calling `warp_mouse` — which does not set
## a variable, it asks the WINDOWING SYSTEM to move the actual cursor on the actual desk. When a person is
## using the machine their hand moves it back, so the readback disagreed by however far they had travelled:
## measured at 11 moved samples in 40 over four seconds, a largest jump of 21154.6 px, and the window
## reporting `focused: false` while still tracking them. Every aim assertion in the suite was, in effect,
## asserting that nobody had touched the mouse recently. The other half of that bug is ruder: we were
## yanking their pointer across the screen while they worked.
##
## So the pointer gets a single source with a seam in it. In play `_posed` is false and every reader ends
## up at the same `get_global_mouse_position()` it used before — this is not a new behaviour, it is the old
## one with one name. Under a fixture, `pose_pointer()` states the world point directly and NOTHING touches
## the OS cursor, which makes aim telemetry independent of whoever else is using the box.
##
## `_posed` is a real bool rather than a `Vector2` compared against null on purpose: in GDScript a Vector2
## — like Array, Dictionary and Callable — compares `!= null` as TRUE, so a "is an override set?" guard
## written that way could never be false. This file has been bitten by that shape before.
static var _posed: bool = false
static var _posed_world: Vector2 = Vector2.ZERO


## Take the pointer. From here the game aims at `world` regardless of where the physical cursor is.
static func pose_pointer(world: Vector2) -> void:
	_posed = true
	_posed_world = world


## Give it back to the human.
static func release_pointer() -> void:
	_posed = false


## Whether a fixture currently owns the pointer. A layer that means to measure the REAL cursor path should
## assert this is false, so "I posed it and forgot" cannot masquerade as a passing hardware test.
static func pointer_posed() -> bool:
	return _posed


## The pointer in world space — what you are aiming AT.
static func pointer_world(node: CanvasItem) -> Vector2:
	if _posed:
		return _posed_world
	return node.get_global_mouse_position()


## The pointer in viewport space — what you are aiming OVER, for the "is the cursor on a panel?" tests.
## Derived from the posed world point through the engine's own canvas transform rather than a hand-rolled
## projection, so the two accessors cannot drift apart and neither can disagree with `warp_mouse`'s pair.
static func pointer_viewport(node: CanvasItem) -> Vector2:
	var vp: Viewport = node.get_viewport()
	if _posed:
		return vp.get_canvas_transform() * _posed_world
	return vp.get_mouse_position()
