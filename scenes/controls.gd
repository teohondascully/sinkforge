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
		RESEARCH: [{"key": KEY_R}],   # in the pack screen at the Bazaar: research the next tech

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
