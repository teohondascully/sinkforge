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


## action -> list of default event specs. {"key": KEY_*} (physical) or {"button": MOUSE_BUTTON_*}.
static func defaults() -> Dictionary:
	return {
		LEFT: [{"key": KEY_A}, {"key": KEY_LEFT}],
		RIGHT: [{"key": KEY_D}, {"key": KEY_RIGHT}],
		# W/↑ and S/↓ are the CLIMB axis (grab + ride a rope); JUMP is Space alone now, so climbing
		# up a rope (W) and jumping off it (Space) stay distinct verbs.
		UP: [{"key": KEY_W}, {"key": KEY_UP}],
		DOWN: [{"key": KEY_S}, {"key": KEY_DOWN}],
		JUMP: [{"key": KEY_SPACE}],
		MINE: [{"button": MOUSE_BUTTON_LEFT}],
		BUILD: [{"button": MOUSE_BUTTON_RIGHT}],
		DROP: [{"key": KEY_Q}],
		CRAFT: [{"key": KEY_E}],
		RESEARCH: [{"key": KEY_R}],   # #S33: CONFIGURE the machine you are aiming at. Research moved to ENTER.

		MAP: [{"key": KEY_M}],
		HELP: [{"key": KEY_H}, {"key": KEY_SLASH}],
		PAUSE: [{"key": KEY_P}],
		CLOSE: [{"key": KEY_ESCAPE}],
		SPEED: [{"key": KEY_PERIOD}],   # "." — cycle the fast-forward game clock (1x -> 2x -> 4x -> 8x)
		CYCLE_NEXT: [{"button": MOUSE_BUTTON_WHEEL_DOWN}],
		CYCLE_PREV: [{"button": MOUSE_BUTTON_WHEEL_UP}],
		ZOOM: [{"key": KEY_Z}],
		SAVE: [{"key": KEY_F5}],        # classic quicksave/quickload
		LOAD: [{"key": KEY_F9}],
		CLEAR_MARKS: [{"key": KEY_X}],  # wipe the painted dig plan
		TECH: [{"key": KEY_T}],         # the tech-tree overlay
		DASHBOARD: [{"key": KEY_G}],    # the production dashboard (throughput + factory census)
		# The grapple sits on F and on the middle mouse button: one key that fires AND releases, so the
		# line is something you flick rather than something you manage. Both hands can reach it while the
		# left is on WASD and the right is aiming — the two things you are already doing when you want it.
		GRAPPLE: [{"key": KEY_F}, {"button": MOUSE_BUTTON_MIDDLE}],
		MUTE: [{"key": KEY_N}],       # sound on/off in one key. M is the map; N is its neighbour and free.
	}


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
			var ev: InputEvent
			if spec.has("key"):
				var k := InputEventKey.new()
				k.physical_keycode = int(spec["key"])
				ev = k
			else:
				var m := InputEventMouseButton.new()
				m.button_index = int(spec["button"])
				ev = m
			InputMap.action_add_event(action, ev)
